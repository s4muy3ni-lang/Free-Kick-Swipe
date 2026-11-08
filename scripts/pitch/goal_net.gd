class_name GoalNet
extends Node3D
## Red del arco con fisica de tela. Cuatro panos (fondo, techo y laterales) atados al marco por sus bordes, cada uno una
## membrana (rejilla de nodos con desplazamiento a lo largo de su normal, ondas y amortiguacion). La pelota que llega a
## un pano lo abomba con su forma y la tension de la tela la frena; al soltarla la red vuelve con ondas que se apagan.
## Funciona por los dos lados (un tiro a la red lateral por fuera la hunde hacia dentro).
##
## La pelota sigue siendo un cuerpo fisico: la red solo le suma aceleraciones (`Ball.net_accel`), que este nodo calcula
## en su _physics_process, antes del paso de fisica que las aplica. Sin pelota en la tela y con la red quieta no
## calcula nada.
##
## Marco local (el del arco): +X hacia atras del arco, +Y arriba, Z a lo largo de la linea de gol.

## Separacion (m) entre nodos de la rejilla de cada pano.
const SPACING := 0.2
## Velocidad de las ondas en la tela (m/s), vuelta al reposo (1/s^2) y amortiguacion de las ondas (1/s).
const WAVE_SPEED := 3.5
const ANCHOR := 30.0
const WAVE_DAMP := 3.2
## Forma del abombado alrededor de la pelota (m): la tela envuelve la pelota y tira de lo que la rodea.
const CONTACT_SIGMA := 0.28
## Distancia (m) al borde atado a partir de la cual la tela cede del todo (junto al marco es mas rigida).
const EDGE_SOFT := 0.45
## Frenado (1/s) de la pelota que ya toco la red y sigue dentro del arco: la tela que cuelga y la que esta en el piso la
## enredan (no sale rodando del arco tras un tiro a la red).
const INSIDE_DAMP := 3.0
## Velocidad (m/s) hacia la tela por encima de la cual la pelota la esta abombando, y hacia fuera por encima de la cual
## la tela la esta devolviendo; entre las dos la pelota esta apoyada en la tela.
const NET_ENTER_SPEED := 0.6
## Fraccion de la rigidez con la que la tela sostiene una pelota apoyada (techo: cede ~5 cm).
const NET_HOLD := 0.3
## Desplazamiento y velocidad por debajo de los que la red se da por quieta.
const REST_EPS := 0.002

class NetPanel:
	var origin: Vector3
	## Paño trapezoidal (laterales de la red de futbol 11): el largo de cada fila a lo largo de U se acorta `taper` metros
	## de abajo (v = 0) arriba (v = len_v). 0 = rectangulo.
	var taper: float = 0.0
	## Caida de reposo (m, a lo largo de la normal; negativa = hacia dentro del arco): la tela cuelga por su peso.
	var sag: float = 0.0
	var axis_u: Vector3
	var axis_v: Vector3
	## Normal hacia fuera del arco.
	var normal: Vector3
	var len_u: float
	var len_v: float
	var nu: int
	var nv: int
	var du: float
	var dv: float
	var disp: PackedFloat32Array
	var vel: PackedFloat32Array
	## Lado de la pelota respecto al pano (-1 dentro del arco, +1 fuera) mientras no lo toca.
	var ball_side: float = -1.0
	var touching: bool = false

	func node_index(i: int, j: int) -> int:
		return j * nu + i

	func rest_point(i: int, j: int) -> Vector3:
		var b: float = float(j) * dv
		return origin + axis_u * (float(i) * row_du(b)) + axis_v * b

	## Largo de la fila a la altura b (a lo largo de V) y separacion de sus nodos.
	func row_len(b: float) -> float:
		return len_u - taper * clampf(b / len_v, 0.0, 1.0)

	func row_du(b: float) -> float:
		return row_len(b) / float(nu - 1)

	## Coordenada U normalizada al largo del pano (para indexar filas acortadas).
	func u_norm(a: float, b: float) -> float:
		return a * len_u / maxf(row_len(b), 0.01)

	## Forma de la caida de reposo en el nodo (i, j): campana que vale 0 en los bordes atados.
	func sag_at(i: int, j: int) -> float:
		if sag == 0.0:
			return 0.0
		return sag * sin(PI * float(i) / float(nu - 1)) * sin(PI * float(j) / float(nv - 1))

var ball: Ball = null
var panels: Array[NetPanel] = []
## true mientras la red se mueve o tiene la pelota (diagnostico y pruebas).
var active: bool = false
## Abombado maximo actual (m) y el mayor desde el ultimo reposo (diagnostico y pruebas).
var bulge: float = 0.0
var peak_bulge: float = 0.0
## false: no dibuja su malla (la dibuja la red de tela, ClothNet) y solo frena la pelota.
var show_mesh: bool = true
## La pelota toco la red desde dentro y no salio del arco desde entonces.
var _caught: bool = false
var _depth: float = 1.0
## Profundidad del techo (red de futbol 11: el fondo baja inclinado desde el techo hasta el piso, a `_depth`).
var _top_depth: float = 1.0
var _height: float = 2.0
var _half_width: float = 1.5
var _mesh: ArrayMesh
var _mesh_instance: MeshInstance3D
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()

## top_depth < 0 (o igual a depth): red en forma de caja (la de siempre). Con 0 < top_depth < depth: red de futbol 11, con
## techo de top_depth, fondo inclinado desde el techo hasta el piso a `depth` y laterales trapezoidales, y una caida de
## reposo (la tela cuelga). Los paños se numeran igual: 0 fondo, 1 techo, 2 lateral -Z, 3 lateral +Z.
## sag: escala de la caida de reposo (0 = tensa).
func setup(depth: float, height: float, half_width: float, material: Material, top_depth: float = -1.0, sag: float = 0.0) -> void:
	_depth = depth
	_height = height
	_half_width = half_width
	_top_depth = depth if top_depth <= 0.0 or top_depth >= depth else top_depth
	panels.clear()
	var slant: float = depth - _top_depth
	if slant <= 0.0:
		panels.append(_panel(Vector3(depth, 0.0, -half_width), Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0), half_width * 2.0, height))
	else:
		var back_len: float = sqrt(slant * slant + height * height)
		var av := Vector3(-slant, height, 0.0) / back_len
		var an := Vector3(height, slant, 0.0) / back_len
		panels.append(_panel(Vector3(depth, 0.0, -half_width), Vector3(0, 0, 1), av, an, half_width * 2.0, back_len))
	panels.append(_panel(Vector3(0.0, height, -half_width), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), _top_depth, half_width * 2.0))
	panels.append(_panel(Vector3(0.0, 0.0, -half_width), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), depth, height))
	panels.append(_panel(Vector3(0.0, 0.0, half_width), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), depth, height))
	if slant > 0.0:
		panels[2].taper = slant
		panels[3].taper = slant
	if sag > 0.0:
		# La tela cuelga: el techo cae hacia dentro, el fondo se abomba un poco hacia fuera y los laterales ceden hacia dentro.
		panels[0].sag = 0.07 * sag
		panels[1].sag = (-0.10 if slant > 0.0 else -0.16) * sag
		panels[2].sag = -0.05 * sag
		panels[3].sag = -0.05 * sag
	_uvs.clear()
	_indices.clear()
	var base: int = 0
	for p in panels:
		for j in p.nv:
			for i in p.nu:
				_uvs.append(Vector2(float(i) * p.row_du(float(j) * p.dv), float(j) * p.dv))
		for j in p.nv - 1:
			for i in p.nu - 1:
				var a: int = base + p.node_index(i, j)
				_indices.append_array([a, a + 1, a + p.nu + 1, a, a + p.nu + 1, a + p.nu])
		base += p.nu * p.nv
	_mesh = ArrayMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "NetMesh"
	_mesh_instance.mesh = _mesh
	_mesh_instance.material_override = material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
	_mesh_instance.visible = show_mesh
	if show_mesh:
		_rebuild_mesh()

func _panel(origin: Vector3, au: Vector3, av: Vector3, n: Vector3, lu: float, lv: float) -> NetPanel:
	var p := NetPanel.new()
	p.origin = origin
	p.axis_u = au
	p.axis_v = av
	p.normal = n
	p.len_u = lu
	p.len_v = lv
	p.nu = maxi(int(round(lu / SPACING)) + 1, 3)
	p.nv = maxi(int(round(lv / SPACING)) + 1, 3)
	p.du = lu / float(p.nu - 1)
	p.dv = lv / float(p.nv - 1)
	p.disp.resize(p.nu * p.nv)
	p.vel.resize(p.nu * p.nv)
	return p

## Desplazamiento (m, a lo largo de la normal hacia fuera) del nodo mas cercano a un punto local del pano `index`
## (0 fondo, 1 techo, 2 lateral -Z, 3 lateral +Z). Para pruebas y diagnostico.
func displacement_at(index: int, local_point: Vector3) -> float:
	var p: NetPanel = panels[index]
	var rel: Vector3 = local_point - p.origin
	var b: float = rel.dot(p.axis_v)
	var i: int = clampi(int(round(p.u_norm(rel.dot(p.axis_u), b) / p.du)), 0, p.nu - 1)
	var j: int = clampi(int(round(b / p.dv)), 0, p.nv - 1)
	return p.disp[p.node_index(i, j)]

func _physics_process(delta: float) -> void:
	Prof.begin(&"red del arco")
	_net_step(delta)
	Prof.end(&"red del arco")

func _net_step(delta: float) -> void:
	var touching: bool = _ball_contact(delta)
	if not active and not touching:
		return
	active = true
	var moving: bool = _step(delta)
	if show_mesh:
		_rebuild_mesh()
	if not touching and not moving:
		for p in panels:
			var zero := PackedFloat32Array()
			zero.resize(p.nu * p.nv)
			p.disp = zero
			p.vel = zero.duplicate()
		active = false
		bulge = 0.0
		peak_bulge = 0.0
		if show_mesh:
			_rebuild_mesh()

# --- Pelota contra la tela ---------------------------------------------------

## Calcula el contacto de la pelota con cada pano: abomba la tela con la forma de la pelota y deja en la pelota la
## aceleracion de la tela (empuje, amortiguacion y agarre). Devuelve si toca algun pano.
func _ball_contact(delta: float) -> bool:
	if ball == null or not is_instance_valid(ball) or ball.is_held():
		return false
	var bt: BallTuning = ball.tuning
	var r: float = ball.radius
	var to_local_basis: Basis = global_basis.inverse()
	var lp: Vector3 = to_local(ball.global_position)
	var lv: Vector3 = to_local_basis * ball.linear_velocity
	var accel := Vector3.ZERO
	var any: bool = false
	for p in panels:
		var rel: Vector3 = lp - p.origin
		var a: float = rel.dot(p.axis_u)
		var b: float = rel.dot(p.axis_v)
		var s: float = rel.dot(p.normal)
		var row: float = p.row_len(b)
		var over: bool = a > -r and a < row + r and b > -r and b < p.len_v + r
		if not p.touching and (absf(s) > r + absf(lv.dot(p.normal)) * delta or not over):
			p.ball_side = -1.0 if s < 0.0 else 1.0
		var push_dir: Vector3 = p.normal * p.ball_side
		var v_into: float = -lv.dot(push_dir)
		# Abombado: lo que la superficie de la pelota pasa del plano de reposo, desde su lado. Se mira tambien al final
		# del paso (a 27 m/s la pelota avanza 0.45 m por paso): si llega a la tela durante el paso, ya la frena.
		var e: float = r - p.ball_side * s
		var dt: float = maxf(delta, 0.001)
		if not over or e + maxf(v_into, 0.0) * dt <= 0.0:
			p.touching = false
			continue
		p.touching = true
		any = true
		# Junto al marco la tela casi no cede: mas rigida cuanto mas cerca del borde atado.
		var edge: float = minf(minf(a, row - a), minf(b, p.len_v - b))
		var soft: float = clampf(edge / EDGE_SOFT, 0.0, 1.0)
		var stiff: float = bt.net_stiffness * (1.0 + 2.0 * (1.0 - soft))
		# La tela no es un muelle: al devolver la pelota casi no empuja (se queda la energia y la pelota cae dentro). Con
		# la pelota casi quieta en la tela (apoyada en el techo o empujada solo por su giro contra el piso) la sostiene.
		var entering: bool = v_into > NET_ENTER_SPEED
		if v_into < -NET_ENTER_SPEED:
			stiff *= bt.net_return
		elif not entering:
			stiff *= NET_HOLD
		var damp: float = 2.0 * sqrt(stiff) * (bt.net_damp_in if entering else bt.net_damp_out)
		# Muelle amortiguado integrado de forma implicita sobre el abombado al final del paso (estable con la tela rigida
		# junto al marco y sin meter energia por llegar tarde al contacto): velocidad hacia la tela al final del paso.
		var v_next: float = (v_into - dt * stiff * e) / (1.0 + dt * damp + dt * dt * stiff)
		if entering:
			# Mientras la pelota entra, la tela como mucho la para: la devuelve despues, con su empuje de vuelta.
			v_next = maxf(v_next, 0.0)
		if e > bt.net_max_bulge:
			# Tope: la tela ya no cede mas.
			v_next = minf(v_next, 0.0)
		# La tela solo empuja (nunca tira de la pelota hacia ella).
		var a_n: float = maxf((v_into - v_next) / dt, 0.0)
		e = maxf(e, 0.0)
		var v_t: Vector3 = lv + push_dir * v_into
		accel += push_dir * a_n - v_t * bt.net_grip * clampf(e / 0.1, 0.0, 1.0)
		_press(p, p.u_norm(a, b), b, minf(e, bt.net_max_bulge), -p.ball_side, delta)
	# Dentro del arco tras tocar la red: la tela la enreda y la frena.
	var inside: bool = lp.x > 0.0 and lp.x < _depth + bt.net_max_bulge and absf(lp.z) < _half_width + 0.05 and lp.y < _height + 0.2
	if not inside:
		_caught = false
	elif any:
		for p in panels:
			if p.touching and p.ball_side < 0.0:
				_caught = true
	if _caught:
		accel += -Vector3(lv.x, 0.0, lv.z) * INSIDE_DAMP
	if any or _caught:
		ball.net_accel += global_basis * accel
		ball.net_contact = true
	return any

## Abomba la tela alrededor del punto (a, b) del pano: la pelota se lleva los nodos que alcanza (forma de campana).
func _press(p: NetPanel, a: float, b: float, depth: float, sign_out: float, delta: float) -> void:
	var reach: float = CONTACT_SIGMA * 3.0
	var i0: int = maxi(int(floor((a - reach) / p.du)), 1)
	var i1: int = mini(int(ceil((a + reach) / p.du)), p.nu - 2)
	var j0: int = maxi(int(floor((b - reach) / p.dv)), 1)
	var j1: int = mini(int(ceil((b + reach) / p.dv)), p.nv - 2)
	var inv: float = 1.0 / (2.0 * CONTACT_SIGMA * CONTACT_SIGMA)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var da: float = float(i) * p.du - a
			var db: float = float(j) * p.dv - b
			var target: float = depth * exp(-(da * da + db * db) * inv) * sign_out
			var k: int = p.node_index(i, j)
			var cur: float = p.disp[k]
			if (sign_out > 0.0 and target > cur) or (sign_out < 0.0 and target < cur):
				p.vel[k] = clampf((target - cur) / maxf(delta, 0.001), -20.0, 20.0)
				p.disp[k] = target

# --- Tela -----------------------------------------------------------------------

## Un paso de las membranas (ondas, vuelta al reposo y amortiguacion; bordes atados). Devuelve si algo se mueve.
func _step(delta: float) -> bool:
	var moving: bool = false
	bulge = 0.0
	for p in panels:
		var nu: int = p.nu
		var cu: float = WAVE_SPEED * WAVE_SPEED / (p.du * p.du)
		var cv: float = WAVE_SPEED * WAVE_SPEED / (p.dv * p.dv)
		var d: PackedFloat32Array = p.disp
		var v: PackedFloat32Array = p.vel
		for j in range(1, p.nv - 1):
			for i in range(1, nu - 1):
				var k: int = j * nu + i
				var u: float = d[k]
				var acc: float = cu * (d[k - 1] + d[k + 1] - 2.0 * u) + cv * (d[k - nu] + d[k + nu] - 2.0 * u) \
					- ANCHOR * u - WAVE_DAMP * v[k]
				v[k] += acc * delta
		for k in d.size():
			d[k] += v[k] * delta
			var ad: float = absf(d[k])
			if ad > bulge:
				bulge = ad
			if ad > REST_EPS or absf(v[k]) > REST_EPS * 10.0:
				moving = true
		p.disp = d
		p.vel = v
	peak_bulge = maxf(peak_bulge, bulge)
	return moving

func _rebuild_mesh() -> void:
	var verts := PackedVector3Array()
	for p in panels:
		for j in p.nv:
			for i in p.nu:
				verts.append(p.rest_point(i, j) + p.normal * (p.disp[p.node_index(i, j)] + p.sag_at(i, j)))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
