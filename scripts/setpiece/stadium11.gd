class_name Stadium11
extends Node3D
## Estadio de futbol 11 para los modos de tiros libres y penales (no estira la cancha del partido: es una construccion
## propia con medidas reglamentarias). Cancha de 105 x 68 m con lineas, areas, puntos penales, semicirculos y arcos de
## esquina; arcos de 7,32 x 2,44 m (Goal, con la red de tela de fondo inclinado de GoalNet); carteles LED; tribunas con
## el MISMO publico 2D animado de los minijuegos arcade (ArcadeLook.crowd: hoja de sprites, calma, festejo y abucheo;
## pedido 2026-11-12); torres de luz e iluminacion nocturna. Ejes: X = largo (arcos en x = +-52,5), Z = ancho, Y = arriba.

signal goal_scored(goal: Goal, ball_position: Vector3)

const GRASS_SHADER := preload("res://assets/setpiece/grass.gdshader")
const CROWD_SHADER := preload("res://assets/setpiece/crowd.gdshader")
const BOARDS_SHADER := preload("res://assets/setpiece/boards.gdshader")

const PENALTY_AREA_DEPTH := 16.5
const PENALTY_AREA_WIDTH := 40.32
const GOAL_AREA_DEPTH := 5.5
const GOAL_AREA_WIDTH := 18.32
const PENALTY_MARK := 11.0
const ARC_RADIUS := 9.15
const BOARD_OFFSET := 5.0
const STAND_GAP := 9.0
## Tribunas: profundidad y subida de la pendiente, y alto del muro del frente (m).
const STAND_DEPTH := 26.0
const STAND_RISE := 16.0
const STAND_FRONT := 2.2
## Publico 2D en las tribunas: filas a lo largo de la pendiente y separacion entre hinchas (m).
const CROWD_ROW_STEP := 1.05
const CROWD_SEAT_GAP := 0.8

var config: PitchConfig
var goals: Dictionary = {}
var crowd_materials: Array[ShaderMaterial] = []
var sun: DirectionalLight3D
var environment: Environment

func build(cfg: PitchConfig = null) -> void:
	config = cfg if cfg != null else PitchConfig.football11()
	for c in get_children():
		c.queue_free()
	goals.clear()
	crowd_materials.clear()
	banners = null
	if has_meta("crowd_mats"):
		remove_meta("crowd_mats")
	_build_ground()
	_build_lines()
	_build_goals()
	_build_boards()
	_build_stands()
	_build_lights()

func half_length() -> float:
	return config.half_length()

func half_width() -> float:
	return config.half_width()

func get_goal(side: int) -> Goal:
	return goals[side]

func set_ball(ball: Ball) -> void:
	for g in goals.values():
		(g as Goal).set_ball(ball)

func reset_goal_latches() -> void:
	for g in goals.values():
		(g as Goal).reset_latch()

## Festejo del publico (0..1): con un gol se paran, saltan y agitan los brazos.
func set_cheer(v: float) -> void:
	_set_mood("cheer", v)

## Lamento del publico (0..1): manos a la cabeza y brazos cruzados.
func set_boo(v: float) -> void:
	_set_mood("boo", v)

## Tension (0..1): la carrera del penal, todos quietos mirando.
func set_tension(v: float) -> void:
	_set_mood("tension", v)

func _set_mood(param: String, v: float) -> void:
	for m in crowd_materials:
		m.set_shader_parameter(param, clampf(v, 0.0, 1.0))

## Pancartas de la hinchada (null hasta add_banners).
var banners: CrowdBanners = null

## Agrega las pancartas con aliento, festejo y cargadas para `player` (el nombre del jugador del usuario).
func add_banners(player: String) -> CrowdBanners:
	if banners != null:
		banners.queue_free()
	banners = CrowdBanners.new()
	banners.name = "Pancartas"
	add_child(banners)
	banners.build(self, player)
	return banners

## Hinchas en las tribunas (instancias del publico 2D).
func crowd_count() -> int:
	var c: int = 0
	for mm in find_children("Publico", "MultiMeshInstance3D", true, false):
		c += (mm as MultiMeshInstance3D).multimesh.instance_count
	return c

# --- Suelo -------------------------------------------------------------------------------------------------------------

func _build_ground() -> void:
	var hl: float = half_length()
	var hw: float = half_width()
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = Ball.LAYER_WORLD
	body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = Ball.FLOOR_FRICTION
	pm.bounce = 0.0
	body.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(config.length + 60.0, 1.0, config.width + 60.0)
	cs.shape = shape
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)
	add_child(body)
	var grass := MeshInstance3D.new()
	grass.name = "Grass"
	var plane := PlaneMesh.new()
	plane.size = Vector2(config.length + STAND_GAP * 2.0 + 2.0, config.width + STAND_GAP * 2.0 + 2.0)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	grass.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	mat.set_shader_parameter("half_size", Vector2(hl + 1.5, hw + 1.5))
	grass.material_override = mat
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)
	# Pared invisible detras de los carteles: la pelota que sale no se pierde.
	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	var t: float = 1.0
	var off: float = BOARD_OFFSET + 0.5
	for z in [-1.0, 1.0]:
		MeshUtil.add_box_body(walls, Vector3(config.length + off * 2.0 + 2.0, 6.0, t), Vector3(0, 3.0, z * (hw + off + t * 0.5)), Ball.LAYER_WORLD)
	for x in [-1.0, 1.0]:
		MeshUtil.add_box_body(walls, Vector3(t, 6.0, config.width + off * 2.0), Vector3(x * (hl + off + t * 0.5), 3.0, 0), Ball.LAYER_WORLD)

# --- Lineas ------------------------------------------------------------------------------------------------------------

func _build_lines() -> void:
	var lb := Pitch.LineBuilder.new()
	var lw: float = config.line_width
	lb.lw = lw
	var hl: float = half_length() - lw * 0.5
	var hw: float = half_width() - lw * 0.5
	lb.segment(-hl, -hw, hl, -hw)
	lb.segment(hl, -hw, hl, hw)
	lb.segment(hl, hw, -hl, hw)
	lb.segment(-hl, hw, -hl, -hw)
	lb.segment(0.0, -hw, 0.0, hw)
	lb.arc(0.0, 0.0, ARC_RADIUS - lw * 0.5, 0.0, TAU, 64)
	lb.disc(0.0, 0.0, 0.15)
	var full: float = half_length()
	for s in [1.0, -1.0]:
		var gl: float = s * hl
		# Area grande y area chica.
		var pa_x: float = s * (full - PENALTY_AREA_DEPTH)
		var pz: float = PENALTY_AREA_WIDTH * 0.5
		lb.segment(gl, -pz, pa_x, -pz)
		lb.segment(pa_x, -pz, pa_x, pz)
		lb.segment(pa_x, pz, gl, pz)
		var ga_x: float = s * (full - GOAL_AREA_DEPTH)
		var gz: float = GOAL_AREA_WIDTH * 0.5
		lb.segment(gl, -gz, ga_x, -gz)
		lb.segment(ga_x, -gz, ga_x, gz)
		lb.segment(ga_x, gz, gl, gz)
		# Punto penal y semicirculo (la parte del circulo de 9,15 m fuera del area).
		var px: float = s * (full - PENALTY_MARK)
		lb.disc(px, 0.0, 0.13)
		var dx: float = PENALTY_AREA_DEPTH - PENALTY_MARK
		var half_ang: float = acos(dx / ARC_RADIUS)
		var center: float = PI if s > 0.0 else 0.0
		lb.arc(px, 0.0, ARC_RADIUS - lw * 0.5, center - half_ang, center + half_ang, 24)
	# Arcos de esquina (1 m).
	for sx in [1.0, -1.0]:
		for sz in [1.0, -1.0]:
			var a0: float = atan2(-sz, -sx)
			lb.arc(sx * full, sz * half_width(), 1.0 - lw * 0.5, a0 - PI * 0.25, a0 + PI * 0.25, 8)
	var mi := MeshInstance3D.new()
	mi.name = "Lines"
	mi.mesh = MeshUtil.build_mesh(lb.verts, lb.normals, lb.uvs, lb.idx)
	mi.material_override = MeshUtil.unshaded_material(Color(0.93, 0.95, 0.92))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# --- Arcos -------------------------------------------------------------------------------------------------------------

func _build_goals() -> void:
	for s in [1, -1]:
		var g := Goal.new()
		add_child(g)
		g.setup(config, s)
		g.goal_scored.connect(func(goal: Goal, pos: Vector3) -> void: goal_scored.emit(goal, pos))
		goals[s] = g

# --- Carteles ----------------------------------------------------------------------------------------------------------

func _build_boards() -> void:
	var root := Node3D.new()
	root.name = "Boards"
	add_child(root)
	var hl: float = half_length() + BOARD_OFFSET
	var hw: float = half_width() + BOARD_OFFSET
	var palettes: Array = [
		[Color(0.05, 0.35, 0.95), Color(0.95, 0.85, 0.10), Color(0.95, 0.20, 0.35)],
		[Color(0.10, 0.75, 0.45), Color(0.95, 0.95, 0.95), Color(0.10, 0.20, 0.60)],
		[Color(0.95, 0.45, 0.05), Color(0.15, 0.15, 0.18), Color(0.95, 0.95, 0.20)],
	]
	var k: int = 0
	for side in [[Vector3(0, 0.5, -hw), Vector3(config.length + BOARD_OFFSET * 2.0, 1.0, 0.15)],
			[Vector3(0, 0.5, hw), Vector3(config.length + BOARD_OFFSET * 2.0, 1.0, 0.15)],
			[Vector3(-hl, 0.5, 0), Vector3(0.15, 1.0, config.width + BOARD_OFFSET * 2.0)],
			[Vector3(hl, 0.5, 0), Vector3(0.15, 1.0, config.width + BOARD_OFFSET * 2.0)]]:
		var size: Vector3 = side[1]
		var long_x: bool = size.x > size.z
		var length: float = size.x if long_x else size.z
		var segs: int = int(ceil(length / 12.0))
		for i in segs:
			var seg_len: float = length / float(segs)
			var mi := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(seg_len - 0.08, 0.9)
			mi.mesh = qm
			var mat := ShaderMaterial.new()
			mat.shader = BOARDS_SHADER
			var pal: Array = palettes[k % palettes.size()]
			k += 1
			mat.set_shader_parameter("color_a", pal[0])
			mat.set_shader_parameter("color_b", pal[1])
			mat.set_shader_parameter("color_c", pal[2])
			mat.set_shader_parameter("speed", 0.25 + 0.1 * float(k % 3))
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var off: float = -length * 0.5 + seg_len * (float(i) + 0.5)
			var pos: Vector3 = side[0]
			if long_x:
				mi.position = Vector3(off, 0.55, pos.z)
				mi.rotation.y = 0.0 if pos.z < 0.0 else PI
			else:
				mi.position = Vector3(pos.x, 0.55, off)
				mi.rotation.y = -PI * 0.5 if pos.x < 0.0 else PI * 0.5
			root.add_child(mi)
		# Estructura de los carteles.
		var frame := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size.x, 1.0, size.z)
		frame.mesh = bm
		var p: Vector3 = side[0]
		frame.position = Vector3(p.x, 0.5, p.z) + (Vector3(0, 0, -0.1 if p.z < 0.0 else 0.1) if long_x else Vector3(-0.1 if p.x < 0.0 else 0.1, 0, 0))
		frame.material_override = MeshUtil.flat_material(Color(0.08, 0.08, 0.1), 0.6)
		frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(frame)

# --- Tribunas ----------------------------------------------------------------------------------------------------------

func _build_stands() -> void:
	var root := Node3D.new()
	root.name = "Stands"
	add_child(root)
	var hl: float = half_length() + STAND_GAP
	var hw: float = half_width() + STAND_GAP
	var rise: float = STAND_RISE
	var depth: float = STAND_DEPTH
	var concrete := MeshUtil.flat_material(Color(0.20, 0.21, 0.24), 0.9)
	var seats_mat := ShaderMaterial.new()
	seats_mat.shader = CROWD_SHADER
	seats_mat.set_shader_parameter("row", CROWD_ROW_STEP)
	var seats: Array = []
	var density: float = GraphicsSettings.crowd_density() if is_inside_tree() else 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# Cuatro tribunas inclinadas (butacas + publico 2D) con su muro frontal y techo.
	for spec in [[Vector3(0, 0, -hw), Vector3(0, 0, -1), config.length + STAND_GAP * 2.0],
			[Vector3(0, 0, hw), Vector3(0, 0, 1), config.length + STAND_GAP * 2.0],
			[Vector3(-hl, 0, 0), Vector3(-1, 0, 0), config.width + STAND_GAP * 2.0],
			[Vector3(hl, 0, 0), Vector3(1, 0, 0), config.width + STAND_GAP * 2.0]]:
		var base: Vector3 = spec[0]
		var out: Vector3 = spec[1]
		var length: float = spec[2]
		var along := Vector3(-out.z, 0, out.x)
		var front_h: float = STAND_FRONT
		var a: Vector3 = base - along * length * 0.5 + Vector3.UP * front_h
		var b: Vector3 = base + along * length * 0.5 + Vector3.UP * front_h
		var c: Vector3 = b + out * depth + Vector3.UP * rise
		var d: Vector3 = a + out * depth + Vector3.UP * rise
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		MeshUtil.add_quad(verts, normals, uvs, idx, a, b, c, d)
		var mi := MeshInstance3D.new()
		mi.mesh = MeshUtil.build_mesh(verts, normals, uvs, idx)
		mi.material_override = seats_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		# Butacas del publico: filas por la pendiente (un poco hundidas en el escalon: se ven de la cintura para arriba).
		var slope: Vector3 = (d - a)
		var rows: int = int(slope.length() / CROWD_ROW_STEP)
		var per_row: int = int((length - 2.0) / CROWD_SEAT_GAP)
		var sgn: float = 1.0 if (out.z > 0.5 or out.x > 0.5) else -1.0
		for r in rows:
			var t: float = (float(r) + 0.35) / float(rows)
			for k in per_row:
				if rng.randf() > density:
					continue
				var u: float = (float(k) + 0.5) / float(per_row) - 0.5
				var p: Vector3 = base + Vector3.UP * front_h + along * u * (length - 2.0) + slope * t - Vector3.UP * 0.35
				seats.append([p, sgn, r])
		# Muro frontal.
		var wall := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(absf(along.x) * length + absf(out.x) * 0.6, front_h, absf(along.z) * length + absf(out.z) * 0.6)
		wall.mesh = wb
		wall.position = base + Vector3.UP * front_h * 0.5 - out * 0.3
		wall.material_override = concrete
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wall)
		# Techo.
		var roof := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(absf(along.x) * length + absf(out.x) * 12.0, 0.5, absf(along.z) * length + absf(out.z) * 12.0)
		roof.mesh = rb
		roof.position = base + out * (depth - 4.0) + Vector3.UP * (rise + front_h + 7.0)
		roof.material_override = MeshUtil.flat_material(Color(0.75, 0.77, 0.8), 0.5)
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(roof)
	# El publico de los minijuegos arcade (una sola MultiMesh): festeja, abuchea y alienta.
	ArcadeLook.crowd(self, seats)
	for m in get_meta("crowd_mats", []):
		crowd_materials.append(m as ShaderMaterial)

# --- Luces -------------------------------------------------------------------------------------------------------------

func _build_lights() -> void:
	var root := Node3D.new()
	root.name = "Lights"
	add_child(root)
	var hl: float = half_length() + STAND_GAP + 8.0
	var hw: float = half_width() + STAND_GAP + 8.0
	var pole_mat := MeshUtil.flat_material(Color(0.5, 0.52, 0.56), 0.5)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1, 1, 0.92)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1, 0.98, 0.88)
	lamp_mat.emission_energy_multiplier = 3.0
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * hl, 0.0, sz * hw)
			var pole := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.5
			cm.bottom_radius = 0.9
			cm.height = 40.0
			pole.mesh = cm
			pole.position = p + Vector3.UP * 20.0
			pole.material_override = pole_mat
			pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(pole)
			var lamp := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(7.0, 4.0, 0.6)
			lamp.mesh = bm
			lamp.position = p + Vector3.UP * 41.0
			lamp.material_override = lamp_mat
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(lamp)
			lamp.look_at(Vector3(0, 0, 0), Vector3.UP)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-58.0, 32.0, 0.0)
	sun.light_energy = 1.05
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.add_to_group("sun_light")
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-40.0, -150.0, 0.0)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	add_child(fill)
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.02, 0.04, 0.10)
	sm.sky_horizon_color = Color(0.12, 0.16, 0.26)
	sm.ground_horizon_color = Color(0.10, 0.12, 0.16)
	sm.ground_bottom_color = Color(0.03, 0.04, 0.06)
	sm.sun_angle_max = 1.0
	sky.sky_material = sm
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.68, 0.78)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment
	add_child(we)
	if is_inside_tree():
		GraphicsSettings.apply()
