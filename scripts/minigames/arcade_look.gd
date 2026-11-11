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

## Estadio de noche alrededor de una zona (centro, largo en X, ancho en Z): cielo oscuro, tribunas estilo caja (todas en
## una sola malla), publico 2D animado (hoja de sprites PNG en una sola malla multiple), torres de luces (dos mallas para
## las cuatro), banderas y piso oscuro. Todo sin colision. Pensado para pocos draw calls y pocos triangulos (telefono y
## navegador). with_floor false (Boton de caida): sin piso, y las tribunas bajan hasta perderse en el vacio.
static func night_arena(scene: Node3D, center: Vector3, length: float, width: float, with_floor: bool = true) -> void:
	light(scene, Color(0.85, 0.88, 1.0), 0.95, ARENA_SKY_TOP, ARENA_HORIZON, 0.75, Vector3(-58, -25, 0))
	if with_floor:
		ground(scene, Vector2(length + 160.0, width + 160.0), Vector3(center.x, -0.02, center.z), Color(0.1, 0.11, 0.18), "stone", 50.0)
	stands(scene, center.x, length + 20.0, [center.z - (width * 0.5 + 6.0), center.z + (width * 0.5 + 6.0)], center.z, STAND_ROWS, 0.0 if with_floor else -16.0)
	# Torres de luces (reticulado + paneles que brillan) en las cuatro esquinas: dos mallas en total.
	var steel: Array = []
	var panels: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(center.x + sx * (length * 0.5 + 2.0), 0, center.z + sz * (width * 0.5 + 3.5))
			light_tower(p, 13.0, steel, panels)
	merged(scene, steel, vc_mat("metal", 1.0)).name = "TorresDeLuz"
	merged(scene, panels, glow(Color(0.85, 0.92, 1.0), 4.0)).name = "FarolesTorres"
	# Banderas violetas con la marca del juego.
	for sz in [-1.0, 1.0]:
		for k in 2:
			banner(scene, Vector3(center.x - length * 0.15 + float(k) * length * 0.45, 0, center.z + sz * (width * 0.5 + 2.2)), sz)

## Tribunas estilo caja con publico 2D: escalones, respaldos de color, cartel de luces al frente y muro con linea de luz
## al fondo, todo en dos mallas; el publico en una MultiMesh. fronts: z del primer escalon de cada tribuna; mid_z: z de la
## cancha (las tribunas suben alejandose de ella); base_y: hasta donde bajan (negativo en un vacio).
static func stands(scene: Node3D, cx: float, span: float, fronts: Array, mid_z: float, rows: int = STAND_ROWS, base_y: float = 0.0) -> void:
	var parts: Array = []
	var leds: Array = []
	var seats: Array = []
	for z0v in fronts:
		var z0: float = float(z0v)
		var sgn: float = 1.0 if z0 > mid_z else -1.0
		# Frente de la tribuna: cartel de luces a franjas (publicidad) sobre un muro.
		parts.append(["box", Vector3(span, 0.6 - base_y, 0.3), Transform3D(Basis(), Vector3(cx, (0.6 + base_y) * 0.5, z0 - sgn * 0.8)), Color(0.12, 0.12, 0.2)])
		var seg: int = maxi(1, int(span / 6.0))
		for k in seg:
			var c: Color = [Color(0.95, 0.3, 0.6), Color(0.35, 0.3, 0.95), Color(1.0, 0.75, 0.2)][k % 3]
			leds.append(["box", Vector3(span / float(seg) - 0.15, 0.42, 0.04), Transform3D(Basis(), Vector3(cx - span * 0.5 + (float(k) + 0.5) * span / float(seg), 0.32, z0 - sgn * 0.97)), c])
		for r in rows:
			var z: float = z0 + sgn * float(r) * STAND_STEP
			var top: float = 0.6 + float(r) * STAND_RISE
			var shade: Color = Color(0.2, 0.21, 0.31) if r % 2 == 0 else Color(0.16, 0.17, 0.26)
			parts.append(["box", Vector3(span, top - base_y, STAND_STEP), Transform3D(Basis(), Vector3(cx, (top + base_y) * 0.5, z)), shade])
			# Respaldos de las butacas: una tira de color al fondo de cada escalon.
			parts.append(["box", Vector3(span, 0.32, 0.1), Transform3D(Basis(), Vector3(cx, top + 0.16, z + sgn * STAND_STEP * 0.42)), Color(0.42, 0.18, 0.5) if r % 2 == 0 else Color(0.22, 0.28, 0.62)])
			var n: int = int(span / CROWD_GAP)
			for k in n:
				seats.append([Vector3(cx - span * 0.5 + (float(k) + 0.5) * CROWD_GAP, top, z - sgn * 0.05), sgn, r])
		# Muro del fondo con una linea de luz arriba.
		var back_top: float = 0.6 + float(rows) * STAND_RISE + 2.2
		var zb: float = z0 + sgn * (float(rows) - 0.4) * STAND_STEP
		parts.append(["box", Vector3(span, back_top - base_y, 0.4), Transform3D(Basis(), Vector3(cx, (back_top + base_y) * 0.5, zb)), Color(0.1, 0.1, 0.17)])
		leds.append(["box", Vector3(span, 0.12, 0.08), Transform3D(Basis(), Vector3(cx, back_top - 0.15, zb - sgn * 0.22)), Color(0.85, 0.9, 1.0)])
	merged(scene, parts, vc_mat("stone", 0.6)).name = "Tribunas"
	merged(scene, leds, led_mat()).name = "LucesTribunas"
	crowd(scene, seats)

const STAND_ROWS := 6
const STAND_STEP := 1.3
const STAND_RISE := 0.75
const CROWD_GAP := 0.72
const CROWD_SIZE := Vector2(0.8, 1.2)
const CROWD_ATLAS := "res://assets/arcade/crowd_atlas.png"
const CROWD_GRID := Vector2i(4, 12)
const CROWD_EMPTY := 0.12

## Publico 2D: cada hincha es un cuadrado con un sprite de la hoja (assets/arcade/crowd_atlas.png, generada por
## tools/gen_crowd_sprites.py). Una sola MultiMesh (un draw call, 2 triangulos por hincha). Datos por instancia
## (INSTANCE_CUSTOM): fila del atlas, fase, animo (quien se para primero al festejar) y brillo. seats: [pos, lado, fila].
static func crowd(scene: Node3D, seats: Array) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var keep: Array = []
	for st in seats:
		if rng.randf() >= CROWD_EMPTY:
			keep.append(st)
	var q := QuadMesh.new()
	q.size = CROWD_SIZE
	q.center_offset = Vector3(0, CROWD_SIZE.y * 0.5, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = keep.size()
	for i in keep.size():
		var st: Array = keep[i]
		var sgn: float = float(st[1])
		# El cuadrado mira a +Z: el lado de +Z gira 180 grados para mirar hacia la cancha.
		var b := Basis(Vector3.UP, PI if sgn > 0.0 else 0.0)
		var p: Vector3 = st[0] + Vector3(rng.randf_range(-0.08, 0.08), 0, 0)
		mm.set_instance_transform(i, Transform3D(b, p))
		var row: int = rng.randi_range(0, CROWD_GRID.y - 1)
		mm.set_instance_custom_data(i, Color(float(row) / float(CROWD_GRID.y), rng.randf(), rng.randf(), rng.randf_range(0.82, 1.0)))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Publico"
	mi.multimesh = mm
	var sm := ShaderMaterial.new()
	sm.shader = crowd_shader()
	sm.set_shader_parameter("atlas", load(CROWD_ATLAS))
	sm.set_shader_parameter("grid", Vector2(CROWD_GRID))
	sm.set_shader_parameter("cheer", 0.0)
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(mi)
	var mats: Array = scene.get_meta("crowd_mats", [])
	mats.append(sm)
	scene.set_meta("crowd_mats", mats)
	return mi

static var _crowd_shader: Shader

## Shader del publico: elige la fila del atlas por instancia y el cuadro por tiempo. Quieto: la mayoria mira, algunos
## aplauden de a ratos y todos se balancean apenas. Con «cheer» (0..1) se paran los mas animados primero: brazos
## arriba y saltos.
static func crowd_shader() -> Shader:
	if _crowd_shader != null:
		return _crowd_shader
	_crowd_shader = Shader.new()
	_crowd_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec2 grid = vec2(4.0, 12.0);
uniform float cheer = 0.0;
uniform float brightness = 0.9;
varying vec2 cell_uv;
varying float shade;
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float phase = c.g * 6.2831;
	float frame = 0.0;
	if (cheer > c.b * 0.9 + 0.05) {
		frame = 2.0 + mod(floor(TIME * 5.0 + c.g * 7.0), 2.0);
		VERTEX.y += abs(sin(TIME * 8.0 + phase)) * 0.14 * cheer;
	} else {
		float clap = step(0.7, c.b) * step(0.55, fract(TIME * 0.35 + c.g));
		frame = clap * mod(floor(TIME * 4.0 + c.g * 5.0), 2.0);
		VERTEX.x += sin(TIME * 1.3 + phase) * 0.02;
	}
	// Cartel que gira sobre el eje vertical hacia la camara: siempre se ve de frente, aun desde el costado.
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - origin;
	vec2 f = normalize(to_cam.xz + vec2(0.0001, 0.0));
	vec3 right = vec3(f.y, 0.0, -f.x);
	vec3 world = origin + right * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(f.x, 0.0, f.y, 0.0)).xyz);
	vec2 uv = UV;
	if (fract(c.g * 13.0) > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	float row = floor(c.r * grid.y + 0.5);
	cell_uv = (uv + vec2(frame, row)) / grid;
	shade = c.a;
}
void fragment() {
	vec4 t = texture(atlas, cell_uv);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = t.rgb * brightness * shade;
}
"""
	return _crowd_shader

## El publico festeja (amount 0..1) durante secs segundos y vuelve a la calma. Sin publico en la escena, no hace nada.
static func cheer(scene: Node, amount: float, secs: float = 2.5) -> void:
	if not scene.has_meta("crowd_mats") or not scene.is_inside_tree():
		return
	if scene.has_meta("crowd_tween"):
		var old: Tween = scene.get_meta("crowd_tween")
		if old != null and old.is_valid():
			old.kill()
	var tw: Tween = scene.create_tween()
	tw.set_parallel(true)
	for sm in scene.get_meta("crowd_mats"):
		tw.tween_property(sm, "shader_parameter/cheer", clampf(amount, 0.0, 1.0), 0.25)
	tw.chain()
	tw.tween_interval(secs)
	var first := true
	for sm in scene.get_meta("crowd_mats"):
		if first:
			tw.chain()
			first = false
		tw.tween_property(sm, "shader_parameter/cheer", 0.0, 1.2)
	scene.set_meta("crowd_tween", tw)

## Nivel de festejo actual del publico de la escena (0 .. 1; -1 si no hay publico).
static func cheer_level(scene: Node) -> float:
	if not scene.has_meta("crowd_mats"):
		return -1.0
	var mats: Array = scene.get_meta("crowd_mats")
	if mats.is_empty():
		return -1.0
	var v: Variant = (mats[0] as ShaderMaterial).get_shader_parameter("cheer")
	return float(v) if v != null else 0.0

## Une muchas piezas simples en una sola malla (un draw call). parts: [forma, tamano, Transform3D, Color]; forma "box",
## "cyl" (size.x radio, size.y alto) o "sphere" (size.x radio). El color va por vertice (el material lo usa como albedo).
static func merged(parent: Node3D, parts: Array, m: Material) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for p in parts:
		var a: Array = _prim(String(p[0]), p[1]).get_mesh_arrays()
		var xf: Transform3D = p[2]
		var col: Color = p[3] if p.size() > 3 else Color.WHITE
		var nb: Basis = xf.basis.inverse().transposed()
		var base: int = verts.size()
		for v in a[Mesh.ARRAY_VERTEX]:
			verts.append(xf * v)
			cols.append(col)
		for n in a[Mesh.ARRAY_NORMAL]:
			norms.append((nb * n).normalized())
		uvs.append_array(a[Mesh.ARRAY_TEX_UV])
		for i in a[Mesh.ARRAY_INDEX]:
			idx.append(base + i)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	if not verts.is_empty():
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## Pieza recta de a hasta b (viga), de seccion t x t, para merged().
static func beam(a: Vector3, b: Vector3, t: float, c: Color) -> Array:
	var d: Vector3 = b - a
	var y: Vector3 = d.normalized()
	var ref: Vector3 = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x: Vector3 = ref.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	return ["box", Vector3(t, d.length(), t), Transform3D(Basis(x, y, z), (a + b) * 0.5), c]

static func _prim(shape: String, size: Vector3) -> PrimitiveMesh:
	match shape:
		"cyl":
			var cm := CylinderMesh.new()
			cm.top_radius = size.x
			cm.bottom_radius = size.z if size.z > 0.0 else size.x
			cm.height = size.y
			cm.radial_segments = 8
			cm.rings = 1
			return cm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = size.x
			sm.height = size.x * 2.0
			sm.radial_segments = 8
			sm.rings = 4
			return sm
	var bm := BoxMesh.new()
	bm.size = size
	return bm

## Material con textura proyectada (triplanar: no se estira en piezas largas) cuyo color sale del vertice (merged).
static func vc_mat(finish: String, uv: float) -> StandardMaterial3D:
	var key := "vc|%s|%.2f" % [finish, uv]
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = mat(Color.WHITE, finish, uv).duplicate()
	m.vertex_color_use_as_albedo = true
	m.uv1_triplanar = true
	_mats[key] = m
	return m

## Luces planas (carteles LED, lineas de luz): sin sombreado, color por vertice.
static func led_mat() -> StandardMaterial3D:
	if _mats.has("led"):
		return _mats["led"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	_mats["led"] = m
	return m

## Agrega a las listas de piezas una torre de luces (reticulado de acero y faroles) con base en p.
static func light_tower(p: Vector3, h: float, steel: Array, panels: Array) -> void:
	var c := Color(0.55, 0.57, 0.62)
	for ox in [-0.35, 0.35]:
		for oz in [-0.35, 0.35]:
			steel.append(["box", Vector3(0.08, h, 0.08), Transform3D(Basis(), p + Vector3(ox, h * 0.5, oz)), c])
	for k in int(h / 1.5):
		for oz in [-0.35, 0.35]:
			steel.append(["box", Vector3(0.78, 0.05, 0.05), Transform3D(Basis(), p + Vector3(0, 1.0 + float(k) * 1.5, oz)), c])
	steel.append(["box", Vector3(1.6, 1.0, 0.2), Transform3D(Basis(), p + Vector3(0, h + 0.4, 0)), Color(0.15, 0.15, 0.18)])
	for i in 3:
		for j in 2:
			panels.append(["box", Vector3(0.42, 0.36, 0.06), Transform3D(Basis(), p + Vector3(-0.5 + float(i) * 0.5, h + 0.18 + float(j) * 0.42, -0.12))])

## Niebla de altura para un vacio: por debajo de top todo se oscurece hacia color (densidad por metro), sin tocar lo que
## esta arriba. Copia el Environment de la escena para no cambiar el de los otros modos.
static func void_fog(scene: Node, top: float, density: float, color: Color) -> void:
	for c in scene.get_children():
		if c is WorldEnvironment:
			var we := c as WorldEnvironment
			var e: Environment = we.environment.duplicate()
			e.fog_enabled = true
			e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
			e.fog_density = 0.0
			e.fog_light_color = color
			e.fog_light_energy = 1.0
			e.fog_sun_scatter = 0.0
			e.fog_sky_affect = 0.0
			e.fog_height = top
			e.fog_height_density = density
			we.environment = e

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
