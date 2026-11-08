class_name Goal
extends Node3D
## Arco: postes y travesano con colision fisica (rebotes reales), red de tela que frena la pelota (GoalNet), colisiones
## simples de la red para los jugadores y deteccion de gol cuando la pelota cruza COMPLETAMENTE la linea.
##
## Marco local: +X apunta hacia afuera del campo (detras del arco), +Y arriba, Z lateral.

signal goal_scored(goal: Goal, ball_position: Vector3)

const NET_SHADER := preload("res://assets/pitch/net.gdshader")

var config: PitchConfig
## +1: arco en x = +length/2; -1: arco en x = -length/2.
var side: int = 1
var ball: Ball = null
var _latched: bool = false
var _frame_material: StandardMaterial3D
## Red de tela del arco.
var net: GoalNet = null
var _net_bodies: Array = []

func setup(cfg: PitchConfig, goal_side: int) -> void:
	config = cfg
	side = goal_side
	name = "Goal_%s" % ("Pos" if side > 0 else "Neg")
	position = Vector3(side * cfg.half_length(), 0.0, 0.0)
	rotation.y = 0.0 if side > 0 else PI
	_frame_material = MeshUtil.flat_material(Color(0.97, 0.97, 0.97), 0.4)
	_build_frame()
	_build_net()

func set_ball(b: Ball) -> void:
	ball = b
	if net != null:
		net.ball = b
	if b != null:
		for body in _net_bodies:
			b.add_collision_exception_with(body)

func reset_latch() -> void:
	_latched = false
	entered_through_mouth = false
	_prev_local = Vector3(-10, 0, 0)

# --- Construccion ----------------------------------------------------------

func _build_frame() -> void:
	var r: float = config.post_radius
	var gh: float = config.goal_height
	var hz: float = config.half_goal() + r
	for z in [-hz, hz]:
		_add_frame_piece(Vector3(0, (gh + 2.0 * r) * 0.5, z), CylinderShape3D.new(), r, gh + 2.0 * r, false)
	# Travesano: cilindro horizontal a lo largo de Z.
	_add_frame_piece(Vector3(0, gh + r, 0), CylinderShape3D.new(), r, config.goal_width + 4.0 * r, true)

func _add_frame_piece(pos: Vector3, shape: CylinderShape3D, r: float, h: float, horizontal: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Ball.LAYER_GOAL_FRAME
	body.collision_mask = 0
	body.add_to_group("goal_frame")
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.45
	pm.friction = 0.3
	body.physics_material_override = pm
	shape.radius = r
	shape.height = h
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _frame_material
	body.add_child(mi)
	body.position = pos
	if horizontal:
		body.rotation.x = PI * 0.5
	add_child(body)

func _build_net() -> void:
	var d: float = config.goal_depth
	var h: float = config.goal_height
	var hw: float = config.half_goal()
	# Red de tela (GoalNet): se abomba con la pelota, la frena y vuelve con ondas.
	var mat := ShaderMaterial.new()
	mat.shader = NET_SHADER
	net = GoalNet.new()
	net.name = "Net"
	add_child(net)
	net.setup(d, h, hw, mat, config.goal_top_depth, config.goal_net_sag)
	if config.goal_supports == 1 and config.goal_top_depth > 0.0 and config.goal_top_depth < d:
		_build_net_supports(d, config.goal_top_depth, h, hw)
	elif config.goal_supports == 2:
		_build_ground_frame(d, hw)

	# Colisiones simples de la red para los jugadores y el arquero (la pelota no las ve: la frena la tela).
	var t: float = 0.06
	_net_bodies = [
		MeshUtil.add_box_body(self, Vector3(t, h, config.goal_width), Vector3(d + t * 0.5, h * 0.5, 0), Ball.LAYER_WORLD, &"net_surface"),
		MeshUtil.add_box_body(self, Vector3(d, h, t), Vector3(d * 0.5, h * 0.5, -hw - t * 0.5), Ball.LAYER_WORLD, &"net_surface"),
		MeshUtil.add_box_body(self, Vector3(d, h, t), Vector3(d * 0.5, h * 0.5, hw + t * 0.5), Ball.LAYER_WORLD, &"net_surface"),
		MeshUtil.add_box_body(self, Vector3(d, t, config.goal_width + 2.0 * t), Vector3(d * 0.5, h + t * 0.5, 0), Ball.LAYER_WORLD, &"net_surface"),
	]

## Soportes de la red de futbol 11 (solo visuales): barra superior trasera, brazos desde el travesano y tirantes inclinados
## hasta el piso, en gris para no confundirse con el marco.
func _build_net_supports(d: float, top: float, h: float, hw: float) -> void:
	var mat := MeshUtil.flat_material(Color(0.62, 0.64, 0.66), 0.5)
	var r: float = 0.022
	_support_bar(Vector3(top, h, -hw), Vector3(top, h, hw), r, mat)
	for z in [-hw, hw]:
		_support_bar(Vector3(0.0, h, z), Vector3(top, h, z), r, mat)
		_support_bar(Vector3(top, h, z), Vector3(d, 0.0, z), r, mat)
		_support_bar(Vector3(0.0, 0.01, z), Vector3(d, 0.01, z), r, mat)
	_support_bar(Vector3(d, 0.01, -hw), Vector3(d, 0.01, hw), r, mat)

## Arco de caja (como los de estadio): caños blancos en el piso a los costados y al fondo, donde se ata la red.
func _build_ground_frame(d: float, hw: float) -> void:
	var r: float = config.post_radius * 0.6
	for z in [-hw, hw]:
		_support_bar(Vector3(0.0, r, z), Vector3(d, r, z), r, _frame_material)
	_support_bar(Vector3(d, r, -hw), Vector3(d, r, hw), r, _frame_material)

func _support_bar(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var dir: Vector3 = (b - a).normalized()
	var axis: Vector3 = Vector3.UP.cross(dir)
	var basis := Basis.IDENTITY
	if axis.length() > 1e-5:
		basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	elif dir.y < 0.0:
		basis = Basis(Vector3.RIGHT, PI)
	mi.transform = Transform3D(basis, (a + b) * 0.5)

# --- Deteccion de gol ------------------------------------------------------

func _physics_process(_delta: float) -> void:
	Prof.begin(&"arco (gol)")
	_goal_step(_delta)
	Prof.end(&"arco (gol)")

func _goal_step(_delta: float) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	var lp: Vector3 = to_local(ball.global_position)
	_track_mouth(lp)
	if _latched:
		if lp.x < -0.5:
			_latched = false
		return
	if is_ball_in_goal(lp) and entered_through_mouth:
		_latched = true
		goal_scored.emit(self, ball.global_position)

## Como entro la pelota al arco: al cruzar el plano de la linea de gol (desde la cancha) se mira por DONDE cruzo (punto
## interpolado entre dos pasos: a 30 m/s avanza 0,5 m por paso). Solo es gol si cruzo entre los palos y debajo del
## travesano; una pelota que hunde la red lateral o el techo desde afuera y queda «dentro» no es gol.
var entered_through_mouth: bool = false
var _prev_local := Vector3(-10, 0, 0)

func _track_mouth(lp: Vector3) -> void:
	var r: float = ball.radius if ball != null else 0.1
	if _prev_local.x < 0.0 and lp.x >= 0.0:
		var u: float = (0.0 - _prev_local.x) / maxf(lp.x - _prev_local.x, 1e-5)
		var c: Vector3 = _prev_local.lerp(lp, clampf(u, 0.0, 1.0))
		entered_through_mouth = absf(c.z) <= config.half_goal() and c.y <= config.goal_height - r * 0.5
	elif lp.x < -0.3:
		entered_through_mouth = false
	_prev_local = lp

## Gol ahora mismo: la pelota esta dentro del arco y entro por la boca del arco.
func is_goal_now() -> bool:
	if ball == null:
		return false
	return entered_through_mouth and is_ball_in_goal(to_local(ball.global_position))

## La pelota cuenta como gol cuando su centro esta al menos un radio detras de la linea
## (cruzo completamente) y dentro del marco (entre postes y entera bajo el travesano: una pelota sobre el techo de la
## red, que cede con su peso, no es gol).
func is_ball_in_goal(local_ball_pos: Vector3) -> bool:
	var r: float = ball.radius if ball != null else 0.1
	return local_ball_pos.x >= r \
		and absf(local_ball_pos.z) <= config.half_goal() \
		and local_ball_pos.y <= config.goal_height - r

# --- Datos para la IA y las asistencias ------------------------------------

func goal_center_world() -> Vector3:
	return global_position

## Punto objetivo dentro del arco. lateral: -1..1 (a lo largo de la linea, en el eje mundial Z),
## height: 0..1 de la altura util.
func aim_point(lateral: float, height_ratio: float, margin: float) -> Vector3:
	var usable: float = maxf(config.half_goal() - margin, 0.05)
	var z: float = clampf(lateral, -1.0, 1.0) * usable
	var y: float = lerpf(0.18, config.goal_height - margin, clampf(height_ratio, 0.0, 1.0))
	return Vector3(global_position.x, y, z)
