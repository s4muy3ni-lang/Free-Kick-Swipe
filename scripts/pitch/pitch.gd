class_name Pitch
extends Node3D
## Cancha de futsal / futbol 5. Se construye proceduralmente a partir de PitchConfig:
## superficie, lineas reglamentarias (una sola malla), paredes de contencion, arcos con redes,
## iluminacion deportiva y elementos ambientales opcionales.
##
## Ejes: X = largo (arcos en x = +-length/2), Z = ancho, Y = arriba.

signal goal_scored(goal: Goal, ball_position: Vector3)

const COURT_SHADER := preload("res://assets/pitch/court.gdshader")

var config: PitchConfig
var goals: Dictionary = {}   # side (+1/-1) -> Goal
var _lines_mesh: MeshInstance3D
var _sun: DirectionalLight3D
var _ambient_root: Node3D

func _ready() -> void:
	# Con una configuracion asignada antes de entrar al arbol (pruebas: futsal) se construye esa; si no, la del juego.
	build(config if config != null else Tuning.pitch)

func build(cfg: PitchConfig) -> void:
	config = cfg
	_clear()
	_build_floor()
	_build_lines()
	_build_walls()
	_build_goals()
	_build_lighting()
	_build_ambient()

func _clear() -> void:
	for c in get_children():
		c.queue_free()
	goals.clear()

func set_ball(ball: Ball) -> void:
	for g in goals.values():
		(g as Goal).set_ball(ball)

func get_goal(side: int) -> Goal:
	return goals[side]

func reset_goal_latches() -> void:
	for g in goals.values():
		(g as Goal).reset_latch()

## Devuelve true si un punto XZ esta dentro de la superficie de juego (con margen opcional).
func contains_xz(p: Vector3, margin: float = 0.0) -> bool:
	return absf(p.x) <= config.half_length() - margin and absf(p.z) <= config.half_width() - margin

func clamp_to_pitch(p: Vector3, margin: float = 0.3) -> Vector3:
	return Vector3(
		clampf(p.x, -config.half_length() + margin, config.half_length() - margin),
		p.y,
		clampf(p.z, -config.half_width() + margin, config.half_width() - margin))

# --- Superficie ------------------------------------------------------------

func _build_floor() -> void:
	var cfg := config
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
	var ext_x: float = cfg.length + cfg.run_off * 2.0 + 8.0
	var ext_z: float = cfg.width + cfg.run_off * 2.0 + 8.0
	shape.size = Vector3(ext_x, 1.0, ext_z)
	cs.shape = shape
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)
	add_child(body)

	# Superficie de juego.
	var court := MeshInstance3D.new()
	court.name = "CourtSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(cfg.length, cfg.width)
	court.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = COURT_SHADER
	court.material_override = mat
	court.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(court)

	# Zona exterior (mas oscura) hasta las gradas.
	var outer := MeshInstance3D.new()
	outer.name = "RunOff"
	var plane2 := PlaneMesh.new()
	plane2.size = Vector2(ext_x, ext_z)
	outer.mesh = plane2
	outer.position = Vector3(0, -0.02, 0)
	outer.material_override = MeshUtil.flat_material(Color(0.10, 0.17, 0.2), 1.0)
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outer)

# --- Lineas ----------------------------------------------------------------

class LineBuilder:
	extends RefCounted
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var y: float = 0.025
	var lw: float = 0.08

	func _p(x: float, z: float) -> Vector3:
		return Vector3(x, y, z)

	func segment(x0: float, z0: float, x1: float, z1: float) -> void:
		var d := Vector2(x1 - x0, z1 - z0)
		var l: float = d.length()
		if l < 0.0001:
			return
		d /= l
		var n := Vector2(-d.y, d.x) * lw * 0.5
		var a := _p(x0 - n.x, z0 - n.y)
		var b := _p(x1 - n.x, z1 - n.y)
		var c := _p(x1 + n.x, z1 + n.y)
		var e := _p(x0 + n.x, z0 + n.y)
		_quad(a, b, c, e)

	func _quad(a: Vector3, b: Vector3, c: Vector3, e: Vector3) -> void:
		var base: int = verts.size()
		verts.append_array([a, b, c, e])
		for i in 4:
			normals.append(Vector3.UP)
			uvs.append(Vector2.ZERO)
		# Orientacion hacia arriba (+Y) independientemente del sentido del segmento.
		var nrm: Vector3 = (b - a).cross(e - a)
		if nrm.y >= 0.0:
			idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
		else:
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	## Arco de circunferencia (angulos en radianes, medidos desde +X hacia +Z).
	func arc(cx: float, cz: float, r: float, a0: float, a1: float, segments: int) -> void:
		var half: float = lw * 0.5
		for i in segments:
			var t0: float = lerpf(a0, a1, float(i) / segments)
			var t1: float = lerpf(a0, a1, float(i + 1) / segments)
			var o0 := _p(cx + cos(t0) * (r + half), cz + sin(t0) * (r + half))
			var i0 := _p(cx + cos(t0) * (r - half), cz + sin(t0) * (r - half))
			var o1 := _p(cx + cos(t1) * (r + half), cz + sin(t1) * (r + half))
			var i1 := _p(cx + cos(t1) * (r - half), cz + sin(t1) * (r - half))
			_quad(i0, o0, o1, i1)

	func disc(cx: float, cz: float, r: float, segments: int = 14) -> void:
		var center_idx: int = verts.size()
		verts.append(_p(cx, cz))
		normals.append(Vector3.UP)
		uvs.append(Vector2.ZERO)
		for i in segments + 1:
			var t: float = TAU * float(i) / segments
			verts.append(_p(cx + cos(t) * r, cz + sin(t) * r))
			normals.append(Vector3.UP)
			uvs.append(Vector2.ZERO)
		for i in segments:
			idx.append_array([center_idx, center_idx + 2 + i, center_idx + 1 + i])

func _build_lines() -> void:
	var cfg := config
	var lb := LineBuilder.new()
	lb.lw = cfg.line_width
	var hl: float = cfg.half_length() - cfg.line_width * 0.5
	var hw: float = cfg.half_width() - cfg.line_width * 0.5
	# Perimetro.
	lb.segment(-hl, -hw, hl, -hw)
	lb.segment(hl, -hw, hl, hw)
	lb.segment(hl, hw, -hl, hw)
	lb.segment(-hl, hw, -hl, -hw)
	# Linea central y circulo central.
	lb.segment(0.0, -hw, 0.0, hw)
	lb.arc(0.0, 0.0, cfg.center_circle_radius - cfg.line_width * 0.5, 0.0, TAU, 40)
	lb.disc(0.0, 0.0, 0.12)
	var gh: float = cfg.half_goal()
	var R: float = cfg.penalty_area_radius
	var full_hl: float = cfg.half_length()
	for s in [1.0, -1.0]:
		# Area: dos cuartos de circulo centrados en los postes unidos por un segmento recto.
		if s > 0.0:
			lb.arc(full_hl, gh, R - cfg.line_width * 0.5, PI * 0.5, PI, 20)
			lb.arc(full_hl, -gh, R - cfg.line_width * 0.5, PI, PI * 1.5, 20)
		else:
			lb.arc(-full_hl, gh, R - cfg.line_width * 0.5, 0.0, PI * 0.5, 20)
			lb.arc(-full_hl, -gh, R - cfg.line_width * 0.5, PI * 1.5, TAU, 20)
		var x_line: float = s * (full_hl - R + cfg.line_width * 0.5)
		lb.segment(x_line, -gh, x_line, gh)
		# Puntos de penal.
		lb.disc(s * (full_hl - cfg.penalty_mark_distance), 0.0, 0.1)
		lb.disc(s * (full_hl - cfg.second_penalty_mark_distance), 0.0, 0.1)
		# Marcas de zona de cambios (a 5 m del centro, sobre la linea de banda).
		for zz in [-hw, hw]:
			var zi: float = -1.0 if zz > 0.0 else 1.0
			lb.segment(s * cfg.substitution_zone_length, zz, s * cfg.substitution_zone_length, zz + zi * 0.8)
	# Arcos de esquina.
	var cr: float = cfg.corner_arc_radius
	lb.arc(full_hl, config.half_width(), cr, PI, PI * 1.5, 6)
	lb.arc(full_hl, -config.half_width(), cr, PI * 0.5, PI, 6)
	lb.arc(-full_hl, config.half_width(), cr, PI * 1.5, TAU, 6)
	lb.arc(-full_hl, -config.half_width(), cr, 0.0, PI * 0.5, 6)

	_lines_mesh = MeshInstance3D.new()
	_lines_mesh.name = "Lines"
	_lines_mesh.mesh = MeshUtil.build_mesh(lb.verts, lb.normals, lb.uvs, lb.idx)
	_lines_mesh.material_override = MeshUtil.unshaded_material(Color(0.96, 0.96, 0.93))
	_lines_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines_mesh)

# --- Paredes ---------------------------------------------------------------

func _build_walls() -> void:
	var cfg := config
	var t: float = 0.5
	var h: float = cfg.wall_height
	# Con bandas (OUT_OF_BOUNDS) las paredes se retiran hasta el borde del area exterior (run_off): la pelota puede
	# salir por la linea y el partido la repone con saque de banda, corner o saque de arco; la pared solo la frena.
	var oob: bool = cfg.boundary_mode == PitchConfig.BoundaryMode.OUT_OF_BOUNDS
	var m: float = cfg.run_off if oob else 0.0
	var hl: float = cfg.half_length() + m
	var hw: float = cfg.half_width() + m
	var full_len: float = hl * 2.0
	var wall_pm := PhysicsMaterial.new()
	wall_pm.friction = 0.4
	wall_pm.bounce = 0.5 if not oob else 0.25
	var root := Node3D.new()
	root.name = "Walls"
	add_child(root)
	# Paredes laterales (bandas).
	for z in [-1.0, 1.0]:
		var b := MeshUtil.add_box_body(root, Vector3(full_len + t * 2.0, h, t),
			Vector3(0, h * 0.5, z * (hw + t * 0.5)), Ball.LAYER_WORLD)
		b.physics_material_override = wall_pm
	var gw: float = cfg.half_goal() + cfg.post_radius * 2.0
	var seg_len: float = hw - gw
	if oob:
		# Fondo completo detras de los arcos (el arco con su red queda por delante).
		for s in [-1.0, 1.0]:
			var bf := MeshUtil.add_box_body(root, Vector3(t, h, hw * 2.0), Vector3(s * (hl + t * 0.5), h * 0.5, 0.0), Ball.LAYER_WORLD)
			bf.physics_material_override = wall_pm
	else:
		# Paredes de fondo con hueco para el arco.
		for s in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var b2 := MeshUtil.add_box_body(root, Vector3(t, h, seg_len),
					Vector3(s * (hl + t * 0.5), h * 0.5, z * (gw + seg_len * 0.5)), Ball.LAYER_WORLD)
				b2.physics_material_override = wall_pm
			# Dintel sobre el arco.
			var top_h: float = h - cfg.goal_height - cfg.post_radius * 2.0
			if top_h > 0.0:
				var b3 := MeshUtil.add_box_body(root, Vector3(t + cfg.goal_depth, top_h, gw * 2.0),
					Vector3(s * (hl + (t + cfg.goal_depth) * 0.5), cfg.goal_height + cfg.post_radius * 2.0 + top_h * 0.5, 0),
					Ball.LAYER_WORLD)
				b3.physics_material_override = wall_pm
	# Baranda visible (baja) para dar contexto de cancha cerrada.
	var barrier_h: float = cfg.barrier_visible_height
	var barrier_mat := MeshUtil.flat_material(Color(0.12, 0.2, 0.38), 0.8)
	var rim_mat := MeshUtil.flat_material(Color(0.85, 0.85, 0.88), 0.6)
	for z in [-1.0, 1.0]:
		_add_visual_box(root, Vector3(full_len + t * 2.0, barrier_h, 0.12),
			Vector3(0, barrier_h * 0.5, z * (hw + 0.06)), barrier_mat)
		_add_visual_box(root, Vector3(full_len + t * 2.0, 0.06, 0.2),
			Vector3(0, barrier_h + 0.03, z * (hw + 0.1)), rim_mat)
	for s in [-1.0, 1.0]:
		if oob:
			_add_visual_box(root, Vector3(0.12, barrier_h, hw * 2.0), Vector3(s * (hl + 0.06), barrier_h * 0.5, 0.0), barrier_mat)
			continue
		for z in [-1.0, 1.0]:
			_add_visual_box(root, Vector3(0.12, barrier_h, seg_len),
				Vector3(s * (hl + 0.06), barrier_h * 0.5, z * (gw + seg_len * 0.5)), barrier_mat)

func _add_visual_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

# --- Arcos -----------------------------------------------------------------

func _build_goals() -> void:
	for s in [1, -1]:
		var g := Goal.new()
		add_child(g)
		g.setup(config, s)
		g.goal_scored.connect(func(goal: Goal, pos: Vector3) -> void: goal_scored.emit(goal, pos))
		goals[s] = g

# --- Iluminacion -----------------------------------------------------------

func _build_lighting() -> void:
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
	_sun.light_energy = 0.85
	_sun.light_color = Color(1.0, 0.97, 0.9)
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.06
	_sun.shadow_normal_bias = 1.0
	_sun.directional_shadow_max_distance = 60.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.add_to_group("sun_light")
	add_child(_sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.10, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.78)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	if is_inside_tree():
		GraphicsSettings.apply()

# --- Elementos ambientales (opcionales segun perfil grafico) ----------------

func _build_ambient() -> void:
	_ambient_root = Node3D.new()
	_ambient_root.name = "Ambient"
	add_child(_ambient_root)
	var cfg := config
	var hl: float = cfg.half_length()
	var hw: float = cfg.half_width()
	# Bancos de suplentes detras de la banda (+Z) y gradas bajas en los fondos.
	var bench_mat := MeshUtil.flat_material(Color(0.2, 0.22, 0.28), 0.8)
	var seat_mat := MeshUtil.flat_material(Color(0.85, 0.35, 0.15), 0.8)
	for x in [-hl * 0.5, hl * 0.5]:
		_add_visual_box(_ambient_root, Vector3(5.0, 0.12, 0.5), Vector3(x, 0.45, hw + 1.6), seat_mat)
		_add_visual_box(_ambient_root, Vector3(5.0, 0.7, 0.1), Vector3(x, 0.8, hw + 1.9), bench_mat)
	# Gradas simples (escalones) detras de las bandas y fondos.
	var stand_mats: Array = [
		MeshUtil.flat_material(Color(0.20, 0.23, 0.30), 1.0),
		MeshUtil.flat_material(Color(0.26, 0.30, 0.38), 1.0),
	]
	for step in 4:
		var h: float = 0.7 + step * 0.7
		var off: float = 3.4 + step * 1.0
		var m: Material = stand_mats[step % 2]
		_add_visual_box(_ambient_root, Vector3(cfg.length + 8.0 + step * 2.0, h, 1.0),
			Vector3(0, h * 0.5, -(hw + off)), m)
		_add_visual_box(_ambient_root, Vector3(1.0, h, cfg.width + 6.0 + step * 2.0),
			Vector3(-(hl + off + 1.0), h * 0.5, 0), m)
		_add_visual_box(_ambient_root, Vector3(1.0, h, cfg.width + 6.0 + step * 2.0),
			Vector3((hl + off + 1.0), h * 0.5, 0), m)
	# Torres de luz (solo visuales, la luz real es la direccional).
	var pole_mat := MeshUtil.flat_material(Color(0.55, 0.57, 0.6), 0.5)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1, 1, 0.85)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1, 0.97, 0.8)
	lamp_mat.emission_energy_multiplier = 2.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var px: float = sx * (hl + 2.0)
			var pz: float = sz * (hw + 2.4)
			_add_visual_box(_ambient_root, Vector3(0.25, 11.0, 0.25), Vector3(px, 5.5, pz), pole_mat)
			_add_visual_box(_ambient_root, Vector3(1.6, 0.6, 0.3), Vector3(px, 11.2, pz), lamp_mat)
	# Modo 4 (Json): cancha sin gradas, bancos ni torres (por ahora se prioriza la jugabilidad).
	_ambient_root.visible = (GraphicsSettings.ambient_props_enabled() if is_inside_tree() else true) and not PackLibrary.json_mode()
