class_name ArcadeLook
extends RefCounted
## Aspecto compartido de los escenarios arcade (pedido del usuario: escenarios 3D propios, materiales, texturas,
## iluminacion y decoracion; nada de bloques grises). Todo es procedural y liviano para Android de gama media: texturas de
## ruido chicas (128 px, una sola vez y compartidas), mallas simples, sin luces extra ni sombras propias. Lo visual NO
## tiene colision salvo que se diga: la fisica del juego no cambia por decorar.

static var _tex: Dictionary = {}
static var _mats: Dictionary = {}

## Textura de ruido gris (se multiplica por el color del material). kind: "grain" (vetas de madera), "fine" (pintura,
## metal cepillado), "rough" (piedra, hormigon).
static func noise_tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var n := FastNoiseLite.new()
	n.seed = 7
	var g := Gradient.new()
	match kind:
		"grain":
			n.noise_type = FastNoiseLite.TYPE_PERLIN
			n.frequency = 0.02
			n.fractal_octaves = 2
			g.set_color(0, Color(0.72, 0.72, 0.72))
			g.set_color(1, Color(1, 1, 1))
		"rough":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.06
			g.set_color(0, Color(0.78, 0.78, 0.78))
			g.set_color(1, Color(1, 1, 1))
		_:
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.09
			g.set_color(0, Color(0.86, 0.86, 0.86))
			g.set_color(1, Color(1, 1, 1))
	var t := NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.noise = n
	t.color_ramp = g
	if kind == "grain":
		# Vetas: la textura angosta se estira en un eje al mapearse.
		t.width = 32
	_tex[kind] = t
	return t

## Material con textura y terminacion. finish: "wood", "metal", "paint", "stone", "rubber", "plastic".
static func mat(c: Color, finish: String = "paint", uv: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%.2f" % [c.to_html(), finish, uv]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	match finish:
		"wood":
			m.albedo_texture = noise_tex("grain")
			m.roughness = 0.8
		"metal":
			m.albedo_texture = noise_tex("fine")
			m.metallic = 0.85
			m.roughness = 0.32
		"stone":
			m.albedo_texture = noise_tex("rough")
			m.roughness = 0.95
		"rubber":
			m.roughness = 0.95
		"plastic":
			m.roughness = 0.35
			m.metallic_specular = 0.7
		_:
			m.albedo_texture = noise_tex("fine")
			m.roughness = 0.55
	m.uv1_scale = Vector3(uv, uv, uv)
	_mats[key] = m
	return m

## Material que brilla (carteles, numeros, luces de borde).
static func glow(c: Color, energy: float = 1.2) -> StandardMaterial3D:
	var key := "glow|%s|%.2f" % [c.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	_mats[key] = m
	return m

## Cesped a franjas (solo visual, apenas sobre el piso de colision).
static func grass(parent: Node3D, size: Vector2, center: Vector3, stripes: int = 10,
		a: Color = Color(0.11, 0.3, 0.12), b: Color = Color(0.14, 0.36, 0.15)) -> MeshInstance3D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.set_color(0, a)
	g.set_offset(1, 0.5)
	g.set_color(1, b)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 16
	gt.height = 4
	var m := StandardMaterial3D.new()
	m.albedo_texture = gt
	m.roughness = 0.95
	m.uv1_scale = Vector3(float(stripes) * 0.5, 1, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = center + Vector3.UP * 0.003
	return mi

## Malla visual (sin colision). shape: "box" (size), "cyl" (size.x = radio, size.y = alto), "sphere" (size.x = radio).
static func deco(parent: Node3D, shape: String, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	match shape:
		"cyl":
			var cm := CylinderMesh.new()
			cm.top_radius = size.x
			cm.bottom_radius = size.z if size.z > 0.0 else size.x
			cm.height = size.y
			cm.radial_segments = 16
			cm.rings = 1
			mi.mesh = cm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = size.x
			sm.height = size.x * 2.0
			sm.radial_segments = 16
			sm.rings = 8
			mi.mesh = sm
		_:
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.rotation = rot
	return mi

## Cartel con texto (tabla con marco y letras), mirando hacia -X (hacia quien patea desde el origen); yaw_deg lo gira.
static func billboard(parent: Node3D, text: String, pos: Vector3, width: float, height: float,
		board: Color = Color(0.1, 0.16, 0.32), letters: Color = Color(1.0, 0.85, 0.3), yaw_deg: float = 0.0) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, height, width)
	b.mesh = bm
	b.material_override = mat(board, "paint")
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(b)
	var fr := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.06, height + 0.12, width + 0.12)
	fr.mesh = fm
	fr.material_override = mat(Color(0.75, 0.76, 0.8), "metal")
	fr.position = Vector3(0.03, 0, 0)
	root.add_child(fr)
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = height * 0.0062
	l.modulate = letters
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.position = Vector3(-0.05, 0, 0)
	l.rotation_degrees = Vector3(0, -90, 0)
	l.double_sided = false
	root.add_child(l)
	return root

## Mastil con bandera (decoracion de borde de escenario).
static func flag(parent: Node3D, pos: Vector3, c: Color, h: float = 3.2) -> void:
	deco(parent, "cyl", Vector3(0.04, h, 0.04), pos + Vector3.UP * h * 0.5, mat(Color(0.85, 0.86, 0.9), "metal"))
	deco(parent, "box", Vector3(0.02, 0.5, 0.8), pos + Vector3(0, h - 0.3, 0.42), mat(c, "paint"))

## Valla publicitaria baja (tablones de colores alternados) a lo largo de Z, en x dado.
static func fence(parent: Node3D, x: float, z0: float, z1: float, colors: Array, h: float = 0.8) -> void:
	var n: int = maxi(int((z1 - z0) / 3.0), 1)
	var w: float = (z1 - z0) / float(n)
	for i in n:
		var c: Color = colors[i % colors.size()]
		deco(parent, "box", Vector3(0.12, h, w - 0.06), Vector3(x, h * 0.5, z0 + w * (float(i) + 0.5)), mat(c, "paint"))

## Piso visual (plano con textura) apenas sobre el piso de colision.
static func ground(parent: Node3D, size: Vector2, center: Vector3, c: Color, finish: String = "stone", uv: float = 8.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat(c, finish, uv)
	parent.add_child(mi)
	mi.global_position = center + Vector3.UP * 0.003
	return mi

## Luz del escenario: tiñe el sol y el cielo del entorno comun del minijuego (sin agregar luces: una sola direccional).
static func light(scene: Node, sun_color: Color, energy: float, sky_top: Color, horizon: Color, ambient: float = 0.8, sun_rot := Vector3(-52, -35, 0)) -> void:
	for c in scene.get_children():
		if c is DirectionalLight3D:
			var l := c as DirectionalLight3D
			l.light_color = sun_color
			l.light_energy = energy
			l.rotation_degrees = sun_rot
		elif c is WorldEnvironment:
			var e: Environment = (c as WorldEnvironment).environment
			e.ambient_light_energy = ambient
			var sm: ProceduralSkyMaterial = null
			if e.sky != null:
				sm = e.sky.sky_material as ProceduralSkyMaterial
			if sm != null:
				sm.sky_top_color = sky_top
				sm.sky_horizon_color = horizon
				sm.ground_horizon_color = horizon.darkened(0.3)
				sm.ground_bottom_color = horizon.darkened(0.6)

## Como deco, pero en coordenadas LOCALES del padre (piezas de un cuerpo que se mueve: cartas, guantes, carteles).
static func part(parent: Node3D, shape: String, size: Vector3, local_pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	match shape:
		"cyl":
			var cm := CylinderMesh.new()
			cm.top_radius = size.x
			cm.bottom_radius = size.z if size.z > 0.0 else size.x
			cm.height = size.y
			cm.radial_segments = 16
			cm.rings = 1
			mi.mesh = cm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = size.x
			sm.height = size.x * 2.0
			sm.radial_segments = 16
			sm.rings = 8
			mi.mesh = sm
		_:
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = local_pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

# --- Estilo arcade comun (referencias del usuario: plataforma elevada, estadio de noche, objetivos grandes) -------------

const ARENA_SKY_TOP := Color(0.05, 0.07, 0.22)
const ARENA_HORIZON := Color(0.32, 0.2, 0.45)
const DECK_PINK := Color(0.62, 0.24, 0.44)
const RAIL_GOLD := Color(1.0, 0.72, 0.18)

## Estadio de noche alrededor de una zona (centro, largo en X, ancho en Z): cielo oscuro, tribunas con publico (una sola
## malla multiple: un draw call), torres de luces con paneles que brillan, banderas y piso oscuro. Todo sin colision.
static func night_arena(scene: Node3D, center: Vector3, length: float, width: float, with_floor: bool = true) -> void:
	light(scene, Color(0.85, 0.88, 1.0), 0.95, ARENA_SKY_TOP, ARENA_HORIZON, 0.75, Vector3(-58, -25, 0))
	if with_floor:
		ground(scene, Vector2(length + 160.0, width + 160.0), Vector3(center.x, -0.02, center.z), Color(0.1, 0.11, 0.18), "stone", 50.0)
	# Tribunas: escalones oscuros y publico de colores en una MultiMesh.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.6, 0.4)
	mm.mesh = bm
	var seats: Array = []
	var rows: int = 6
	for sgn in [-1.0, 1.0]:
		var z0: float = center.z + sgn * (width * 0.5 + 6.0)
		for r in rows:
			var z: float = z0 + sgn * float(r) * 1.3
			var y: float = 0.6 + float(r) * 0.75
			deco(scene, "box", Vector3(length + 20.0, 0.7, 1.3), Vector3(center.x, y - 0.35, z), mat(Color(0.14, 0.15, 0.24), "stone", 6.0))
			var n: int = int((length + 18.0) / 1.1)
			for k in n:
				if (k * 7 + r * 3) % 11 == 0:
					continue
				seats.append(Transform3D(Basis(), Vector3(center.x - (length + 18.0) * 0.5 + float(k) * 1.1 + float(r % 2) * 0.5, y + 0.3, z)))
	mm.instance_count = seats.size()
	var palette: Array = [Color(0.9, 0.2, 0.25), Color(0.2, 0.45, 0.95), Color(0.95, 0.85, 0.2), Color(0.92, 0.92, 0.95), Color(0.55, 0.25, 0.75)]
	for i in seats.size():
		mm.set_instance_transform(i, seats[i])
		mm.set_instance_color(i, palette[(i * 13) % palette.size()])
	var crowd := MultiMeshInstance3D.new()
	crowd.multimesh = mm
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.roughness = 0.8
	crowd.material_override = cm
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(crowd)
	# Torres de luces (reticulado + paneles que brillan) en las cuatro esquinas.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(center.x + sx * (length * 0.5 + 2.0), 0, center.z + sz * (width * 0.5 + 3.5))
			light_tower(scene, p, 13.0)
	# Banderas violetas con la marca del juego.
	for sz in [-1.0, 1.0]:
		for k in 2:
			banner(scene, Vector3(center.x - length * 0.15 + float(k) * length * 0.45, 0, center.z + sz * (width * 0.5 + 2.2)), sz)

static func light_tower(scene: Node3D, p: Vector3, h: float) -> void:
	var steel := mat(Color(0.55, 0.57, 0.62), "metal")
	for ox in [-0.35, 0.35]:
		for oz in [-0.35, 0.35]:
			deco(scene, "box", Vector3(0.08, h, 0.08), p + Vector3(ox, h * 0.5, oz), steel)
	for k in int(h / 1.5):
		deco(scene, "box", Vector3(0.78, 0.05, 0.05), p + Vector3(0, 1.0 + float(k) * 1.5, -0.35), steel)
		deco(scene, "box", Vector3(0.78, 0.05, 0.05), p + Vector3(0, 1.0 + float(k) * 1.5, 0.35), steel)
	deco(scene, "box", Vector3(1.6, 1.0, 0.2), p + Vector3(0, h + 0.4, 0), mat(Color(0.15, 0.15, 0.18), "metal"))
	for i in 3:
		for j in 2:
			deco(scene, "box", Vector3(0.42, 0.36, 0.06), p + Vector3(-0.5 + float(i) * 0.5, h + 0.18 + float(j) * 0.42, -0.12), glow(Color(0.85, 0.92, 1.0), 4.0))

## Bandera violeta con marco dorado y el nombre del juego, en un mastil.
static func banner(scene: Node3D, p: Vector3, side: float) -> void:
	deco(scene, "cyl", Vector3(0.06, 4.8, 0.06), p + Vector3(0, 2.4, 0), mat(Color(0.75, 0.6, 0.25), "metal"))
	var face := Node3D.new()
	scene.add_child(face)
	face.global_position = p + Vector3(0.0, 3.2, 0)
	face.rotation_degrees = Vector3(0, -90.0 + (20.0 if side < 0 else -20.0), 0)
	part(face, "box", Vector3(1.3, 2.2, 0.05), Vector3.ZERO, mat(Color(0.32, 0.12, 0.5), "paint"))
	part(face, "box", Vector3(1.42, 0.08, 0.06), Vector3(0, 1.12, 0), mat(RAIL_GOLD, "metal"))
	part(face, "box", Vector3(1.42, 0.08, 0.06), Vector3(0, -1.12, 0), mat(RAIL_GOLD, "metal"))
	var l := Label3D.new()
	l.text = "FREE\nKICK\nSWIPE"
	l.font_size = 80
	l.pixel_size = 0.0065
	l.modulate = Color(1.0, 0.86, 0.28)
	l.outline_size = 10
	l.position = Vector3(0, -0.25, 0.04)
	face.add_child(l)
	part(face, "sphere", Vector3(0.2, 0, 0), Vector3(0, 0.75, 0.06), mat(Color(0.97, 0.97, 0.97), "plastic"))

## Plataforma del jugador (estilo de las referencias): cubierta rosa/violeta con borde de luces, barandas doradas a los
## costados, flechas amarillas, aro de luz en la pelota y placa con emblema al frente. top_y: altura de la cubierta; si es
## > 0.05 lleva un pilar y una caja fisica (el jugador y la pelota estan arriba de verdad). Mira hacia +X.
static func player_deck(scene: Node3D, ball_spot: Vector3, top_y: float, ball_r: float, deck_color: Color = DECK_PINK) -> StaticBody3D:
	var back: float = 5.0
	var front: float = 1.6
	var w: float = 7.4
	var cx: float = ball_spot.x + (front - back) * 0.5
	var body: StaticBody3D = null
	var th: float = maxf(top_y, 0.04)
	if top_y > 0.05:
		body = StaticBody3D.new()
		body.collision_layer = Ball.LAYER_WORLD
		var pm := PhysicsMaterial.new()
		pm.friction = 0.7
		pm.bounce = 0.45
		body.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(back + front, 0.6, w)
		cs.shape = bs
		body.add_child(cs)
		scene.add_child(body)
		body.global_position = Vector3(cx, top_y - 0.3, ball_spot.z)
		deco(scene, "box", Vector3(2.4, top_y - 0.6, 2.4), Vector3(cx - 0.8, (top_y - 0.6) * 0.5, ball_spot.z), mat(Color(0.32, 0.33, 0.38), "stone", 2.0))
	deco(scene, "box", Vector3(back + front, minf(th, 0.6), w), Vector3(cx, top_y - minf(th, 0.6) * 0.5 + 0.002, ball_spot.z), mat(deck_color, "paint", 3.0))
	# Borde de luces y franjas doradas.
	deco(scene, "box", Vector3(0.12, 0.06, w + 0.1), Vector3(ball_spot.x + front, top_y + 0.01, ball_spot.z), glow(RAIL_GOLD, 1.6))
	deco(scene, "box", Vector3(back + front, 0.06, 0.12), Vector3(cx, top_y + 0.01, ball_spot.z - w * 0.5), glow(RAIL_GOLD, 1.2))
	deco(scene, "box", Vector3(back + front, 0.06, 0.12), Vector3(cx, top_y + 0.01, ball_spot.z + w * 0.5), glow(RAIL_GOLD, 1.2))
	# Barandas doradas a los costados (bajas: no tapan) con postes de luz.
	for sz in [-1.0, 1.0]:
		var z: float = ball_spot.z + sz * (w * 0.5 - 0.15)
		deco(scene, "box", Vector3(back - 0.6, 0.08, 0.08), Vector3(ball_spot.x - back * 0.5 + 0.3, top_y + 0.9, z), mat(RAIL_GOLD, "metal"))
		for k in 3:
			var x: float = ball_spot.x - back + 0.6 + float(k) * (back - 1.2) * 0.5
			deco(scene, "box", Vector3(0.1, 0.9, 0.1), Vector3(x, top_y + 0.45, z), mat(RAIL_GOLD, "metal"))
			deco(scene, "sphere", Vector3(0.08, 0, 0), Vector3(x, top_y + 0.98, z), glow(Color(1.0, 0.85, 0.45), 2.5))
	# Flechas amarillas en el piso (a los dos lados del lugar de la pelota).
	for sz in [-1.0, 1.0]:
		for k in 2:
			var px: float = ball_spot.x - 0.6 + float(k) * 0.5
			for sgn in [-1.0, 1.0]:
				deco(scene, "box", Vector3(0.12, 0.012, 0.55), Vector3(px, top_y + 0.008, ball_spot.z + sz * 2.4 + sgn * 0.2), mat(Color(1.0, 0.8, 0.1), "paint"), Vector3(0, sgn * 0.7, 0))
	# Aro de luz donde va la pelota.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = ball_r * 2.2
	tm.outer_radius = ball_r * 2.6
	tm.rings = 24
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = glow(Color(0.35, 0.8, 1.0), 2.5)
	ring.scale = Vector3(1, 0.2, 1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(ring)
	ring.global_position = Vector3(ball_spot.x, top_y + 0.01, ball_spot.z)
	# Placa con emblema al frente (si la plataforma esta alta).
	if top_y > 0.6:
		deco(scene, "box", Vector3(0.08, minf(top_y * 0.6, 1.1), 2.2), Vector3(ball_spot.x + front + 0.05, top_y - minf(top_y * 0.6, 1.1) * 0.5 - 0.05, ball_spot.z), mat(Color(0.2, 0.2, 0.26), "metal"))
		deco(scene, "sphere", Vector3(0.3, 0, 0), Vector3(ball_spot.x + front + 0.15, top_y - 0.45, ball_spot.z), mat(Color(0.97, 0.97, 0.97), "plastic"))
		for sz in [-1.0, 1.0]:
			for k in 4:
				deco(scene, "box", Vector3(0.04, 0.16, 0.07), Vector3(ball_spot.x + front + 0.12, top_y - 0.75 + float(k) * 0.14, ball_spot.z + sz * (0.42 + float(k) * 0.05)), mat(RAIL_GOLD, "metal"), Vector3(sz * 0.4, 0, 0))
	return body

## Pasarela roja con franjas amarillas, flechas y cajas con estrellas a los costados (referencias de Dardos y Poker).
static func runway(scene: Node3D, x0: float, x1: float, w: float) -> void:
	var len: float = x1 - x0
	ground(scene, Vector2(len, w), Vector3((x0 + x1) * 0.5, 0.002, 0), Color(0.62, 0.16, 0.14), "stone", 12.0)
	for k in 6:
		var x: float = x0 + len * (0.15 + float(k) * 0.14)
		deco(scene, "box", Vector3(0.5, 0.008, w * (0.9 - float(k) * 0.08)), Vector3(x, 0.006, 0), mat(Color(1.0, 0.85, 0.1), "paint"))
	for sz in [-1.0, 1.0]:
		deco(scene, "box", Vector3(len, 0.01, 0.12), Vector3((x0 + x1) * 0.5, 0.007, sz * w * 0.5), mat(Color(0.97, 0.97, 0.97), "paint"))
		for k in 5:
			var x2: float = x0 + len * (0.12 + float(k) * 0.2)
			var bx := Vector3(x2, 0.45, sz * (w * 0.5 + 1.2))
			deco(scene, "box", Vector3(0.9, 0.9, 0.9), bx, mat(Color(0.35, 0.2, 0.12), "wood"))
			var star := Label3D.new()
			star.text = "★"
			star.font_size = 128
			star.pixel_size = 0.005
			star.modulate = Color(1.0, 0.8, 0.2)
			star.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			scene.add_child(star)
			star.global_position = bx + Vector3(0, 0.2, 0)
			deco(scene, "box", Vector3(0.3, 0.12, 0.2), Vector3(x2 + 0.9, 0.06, sz * (w * 0.5 + 0.35)), glow(Color(1.0, 0.75, 0.3), 2.5))
