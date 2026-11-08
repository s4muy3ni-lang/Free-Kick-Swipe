class_name ClothNet
extends Node3D
## Red del arco como TELA de verdad (arcos de futbol 11): nodos con masa unidos por restricciones de distancia (integracion
## de Verlet), atados al marco y al piso por sus bordes, con gravedad (la red cuelga sola, con su caida natural), un poco de
## holgura, amortiguacion del aire y la pelota como cuerpo solido: la tela se aparta de la pelota en 3D (se envuelve a su
## alrededor, hace pliegues, la sostiene cuando queda dentro) y las oscilaciones se propagan por los hilos y se apagan.
##
## El frenado de la pelota lo sigue dando el modelo medido de la red (GoalNet, membrana con rigidez y amortiguacion
## calibradas: frena un tiro de 30 m/s sin devolverlo); esta tela es lo que se ve y reacciona a la pelota real. Hibrido
## pedido por la reforma (estable en Android): las dos usan la misma pelota.
##
## Marco local del arco: +X hacia atras, +Y arriba, Z a lo largo de la linea de gol. Solo simula mientras la pelota esta
## cerca o la tela se mueve.

## Separacion entre nodos (m): la trama fina de la red la dibuja el sombreador sobre esta malla.
const SPACING := 0.34
const ITERATIONS := 3
const GRAVITY := 9.81
## Velocidad que conserva cada paso (amortiguacion del aire y del hilo).
const DAMP := 0.975
## Holgura de los hilos (largo de reposo / distancia geometrica): con gravedad, la red cuelga.
const SLACK := 1.008
## Grosor de la tela para el contacto con la pelota (m).
const THICK := 0.025
## Velocidad (m/paso) por debajo de la cual la tela se da por quieta.
const REST_EPS := 0.0006

var ball: Ball = null
## true mientras simula (diagnostico y pruebas); desplazamiento maximo actual respecto del reposo (m).
var active: bool = false
var bulge: float = 0.0
var peak_bulge: float = 0.0

var pos := PackedVector3Array()
var prev := PackedVector3Array()
var rest := PackedVector3Array()
var free := PackedByteArray()
var _ca := PackedInt32Array()
var _cb := PackedInt32Array()
var _cl := PackedFloat32Array()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()
var _mesh: ArrayMesh
var _mi: MeshInstance3D
var _bbox_lo := Vector3.ZERO
var _bbox_hi := Vector3.ZERO
var _still_t: float = 0.0

## depth: profundidad en el piso; top_depth: profundidad del techo (<= 0 o igual a depth: red de caja).
func setup(depth: float, height: float, half_width: float, material: Material, top_depth: float = -1.0) -> void:
	var td: float = depth if top_depth <= 0.0 or top_depth >= depth else top_depth
	var hw: float = half_width
	# Paños: techo, fondo y los dos laterales (cada uno con sus cuatro esquinas: a(0,0) b(1,0) c(1,1) d(0,1)).
	_panel(Vector3(0, height, -hw), Vector3(0, height, hw), Vector3(td, height, hw), Vector3(td, height, -hw))
	_panel(Vector3(td, height, -hw), Vector3(td, height, hw), Vector3(depth, 0, hw), Vector3(depth, 0, -hw))
	_panel(Vector3(0, 0, -hw), Vector3(depth, 0, -hw), Vector3(td, height, -hw), Vector3(0, height, -hw))
	_panel(Vector3(0, 0, hw), Vector3(depth, 0, hw), Vector3(td, height, hw), Vector3(0, height, hw))
	prev = pos.duplicate()
	_bbox_lo = Vector3(-0.3, -0.1, -hw - 0.6)
	_bbox_hi = Vector3(depth + 0.8, height + 0.8, hw + 0.6)
	_mesh = ArrayMesh.new()
	_mi = MeshInstance3D.new()
	_mi.name = "ClothMesh"
	_mi.mesh = _mesh
	_mi.material_override = material
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	# La red se acomoda con su peso antes de empezar (caida de reposo real, no dibujada).
	for i in 90:
		_simulate(1.0 / 60.0, Vector3.INF, 0.0)
	rest = pos.duplicate()
	prev = pos.duplicate()
	_rebuild_mesh()

func _panel(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var lu: float = maxf(a.distance_to(b), d.distance_to(c))
	var lv: float = maxf(a.distance_to(d), b.distance_to(c))
	var nu: int = maxi(int(round(lu / SPACING)) + 1, 3)
	var nv: int = maxi(int(round(lv / SPACING)) + 1, 3)
	var base: int = pos.size()
	for j in nv:
		var v: float = float(j) / float(nv - 1)
		for i in nu:
			var u: float = float(i) / float(nu - 1)
			var p: Vector3 = a.lerp(b, u).lerp(d.lerp(c, u), v)
			pos.append(p)
			free.append(0 if (i == 0 or j == 0 or i == nu - 1 or j == nv - 1) else 1)
			_uvs.append(Vector2(u * lu, v * lv))
	for j in nv:
		for i in nu:
			var k: int = base + j * nu + i
			if i + 1 < nu:
				_link(k, k + 1)
			if j + 1 < nv:
				_link(k, k + nu)
	for j in nv - 1:
		for i in nu - 1:
			var k0: int = base + j * nu + i
			_indices.append_array([k0, k0 + 1, k0 + nu + 1, k0, k0 + nu + 1, k0 + nu])

func _link(a: int, b: int) -> void:
	if free[a] == 0 and free[b] == 0:
		return
	_ca.append(a)
	_cb.append(b)
	_cl.append(pos[a].distance_to(pos[b]) * SLACK)

func _physics_process(delta: float) -> void:
	Prof.begin(&"red de tela")
	_tick(delta)
	Prof.end(&"red de tela")

func _tick(delta: float) -> void:
	var bl := Vector3.INF
	var r: float = 0.0
	if ball != null and is_instance_valid(ball):
		var lp: Vector3 = to_local(ball.global_position)
		var near: bool = lp.x > _bbox_lo.x and lp.x < _bbox_hi.x and lp.y < _bbox_hi.y and lp.z > _bbox_lo.z and lp.z < _bbox_hi.z
		if near:
			bl = lp
			r = ball.radius * (ball.tuning.visual_scale if ball.tuning != null else 1.0)
			active = true
			_still_t = 0.0
	if not active:
		return
	var moved: float = _simulate(delta, bl, r)
	_rebuild_mesh()
	if bl == Vector3.INF and moved < REST_EPS:
		_still_t += delta
		if _still_t > 0.8:
			active = false
			bulge = 0.0
			peak_bulge = 0.0

## Un paso de la tela. Devuelve el mayor desplazamiento de un nodo en el paso (m).
func _simulate(dt: float, ball_local: Vector3, radius: float) -> float:
	var g: Vector3 = Vector3.DOWN * GRAVITY * dt * dt
	var n: int = pos.size()
	var moved: float = 0.0
	for i in n:
		if free[i] == 0:
			continue
		var p: Vector3 = pos[i]
		var v: Vector3 = (p - prev[i]) * DAMP
		prev[i] = p
		pos[i] = p + v + g
		moved = maxf(moved, v.length())
	var m: int = _ca.size()
	for it in ITERATIONS:
		for c in m:
			var ia: int = _ca[c]
			var ib: int = _cb[c]
			var pa: Vector3 = pos[ia]
			var pb: Vector3 = pos[ib]
			var dvec: Vector3 = pb - pa
			var d: float = dvec.length()
			if d <= _cl[c] or d < 1e-6:
				# Un hilo no empuja: solo tira cuando esta tenso.
				continue
			var corr: Vector3 = dvec * ((d - _cl[c]) / d)
			var fa: int = free[ia]
			var fb: int = free[ib]
			if fa == 1 and fb == 1:
				pos[ia] = pa + corr * 0.5
				pos[ib] = pb - corr * 0.5
			elif fa == 1:
				pos[ia] = pa + corr
			elif fb == 1:
				pos[ib] = pb - corr
		if ball_local != Vector3.INF:
			_push_out(ball_local, radius + THICK)
	# Piso: la red no lo atraviesa.
	for i in n:
		if free[i] == 1 and pos[i].y < 0.01:
			pos[i].y = 0.01
	return moved

## La pelota es solida: la tela no la atraviesa. Contra cada cara (triangulo) cercana de la malla: si la pelota la toca,
## la cara se aparta a lo largo de su normal (sus tres nodos, segun donde toca), y los nodos que quedan dentro de la
## pelota se llevan a su superficie: la tela la envuelve aunque la pelota sea mas chica que la separacion entre nodos.
func _push_out(c: Vector3, rr: float) -> void:
	var reach2: float = (rr + SPACING * 1.5) * (rr + SPACING * 1.5)
	var nt: int = _indices.size() / 3
	for t in nt:
		var i0: int = _indices[t * 3]
		var i1: int = _indices[t * 3 + 1]
		var i2: int = _indices[t * 3 + 2]
		var a: Vector3 = pos[i0]
		if a.distance_squared_to(c) > reach2:
			continue
		var b: Vector3 = pos[i1]
		var d: Vector3 = pos[i2]
		var nrm: Vector3 = (b - a).cross(d - a)
		var nl: float = nrm.length()
		if nl < 1e-6:
			continue
		nrm /= nl
		var dist: float = (c - a).dot(nrm)
		if absf(dist) >= rr:
			continue
		var proj: Vector3 = c - nrm * dist
		var w: Vector3 = Geometry3D.get_triangle_barycentric_coords(proj, a, b, d)
		if w.x < -0.05 or w.y < -0.05 or w.z < -0.05:
			continue
		# La cara se aparta hasta quedar a rr del centro, del lado contrario a la pelota.
		var side: float = -1.0 if dist > 0.0 else 1.0
		var push: Vector3 = nrm * side * (rr - absf(dist))
		var ws: float = maxf(w.x * w.x + w.y * w.y + w.z * w.z, 1e-4)
		if free[i0] == 1:
			pos[i0] += push * (w.x / ws)
		if free[i1] == 1:
			pos[i1] += push * (w.y / ws)
		if free[i2] == 1:
			pos[i2] += push * (w.z / ws)
	var r2: float = rr * rr
	for i in pos.size():
		if free[i] == 0:
			continue
		var p: Vector3 = pos[i]
		var dv: Vector3 = p - c
		var l2: float = dv.length_squared()
		if l2 < r2:
			var l: float = sqrt(maxf(l2, 1e-8))
			pos[i] = c + (dv / l if l > 1e-4 else Vector3(1, 0, 0)) * rr
	bulge = 0.0
	if rest.size() == pos.size():
		for i in pos.size():
			if free[i] == 1:
				bulge = maxf(bulge, pos[i].distance_to(rest[i]))
	peak_bulge = maxf(peak_bulge, bulge)

func _rebuild_mesh() -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

## Desplazamiento (m) del nodo de la tela mas cercano a un punto local respecto de su reposo (pruebas).
func displacement_near(local_point: Vector3) -> float:
	var best: float = INF
	var k: int = -1
	for i in pos.size():
		var dd: float = rest[i].distance_squared_to(local_point)
		if dd < best:
			best = dd
			k = i
	return pos[k].distance_to(rest[k]) if k >= 0 else 0.0
