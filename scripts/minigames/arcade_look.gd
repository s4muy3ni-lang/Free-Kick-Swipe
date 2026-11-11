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
