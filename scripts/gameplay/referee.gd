class_name Referee
extends Node3D
## Arbitro: figura de presentacion que sigue la jugada por la banda (no participa en el juego). Usa los clips de arbitro
## del pack (cuenta durante la presentacion, senala tras un gol y al reanudar, saluda al final) y se desplaza con los
## GEMELOS CON RAIZ de la marcha del pack: su velocidad en cada instante es la del desplazamiento de raiz MEDIDO del clip
## que suena (Walking_7, Jogging, Running, Sprint, Two_Cycle_Sprint de frente; jog_strafe_left/right, Strafe_3 y las
## diagonales/atras de lado), asi que los pies no patinan: el cuerpo avanza lo mismo que el clip original.

## Clips de marcha de frente por velocidad (gemelos con raiz) y de lado, con su direccion local (derecha, adelante).
const FORWARD_TWINS := [&"Walking_7", &"Jogging", &"Running", &"Sprint", &"Two_Cycle_Sprint"]
const SIDE_TWINS := {
	&"jog_strafe_right": Vector2(1.0, 0.0), &"jog_strafe_left": Vector2(-1.0, 0.0), &"Strafe_3": Vector2(1.36, 0.0),
	&"jog_forward": Vector2(0.0, 1.0), &"jog_backward": Vector2(0.0, -1.0),
	&"jog_forward_diagonal": Vector2(0.7, 0.7), &"jog_forward_diagonal_2": Vector2(-0.7, 0.7),
	&"jog_backward_diagonal": Vector2(0.7, -0.7), &"jog_backward_diagonal_2": Vector2(-0.7, -0.7),
}
## Distancia (m) a lo largo de la banda a partir de la cual se gira y corre de frente en vez de desplazarse de lado.
const RUN_DISTANCE := 7.0
const DEAD_ZONE := 0.9

var visual: FootballerVisual = null
var ctx: MatchContext = null
var _pending: StringName = &""
var _delay: float = 0.0
var _cut: float = 2.5
var _line_z: float = 10.9
var _yaw: float = 0.0
## Gemelo que mueve al arbitro ahora (vacio = parado) y fase (s) dentro de su ciclo.
var current_twin: StringName = &""
var _phase: float = 0.0
var _side_mode: bool = true
## Metros recorridos y gemelos usados (diagnostico y pruebas).
var travelled: float = 0.0
var twins_used := {}

func setup(context: MatchContext, at: Vector3) -> void:
	ctx = context
	visual = FootballerVisual.new()
	visual.name = "Visual"
	visual.twin_rig = true
	add_child(visual)
	visual.build(FootballerVisual.referee_kit())
	position = at
	_line_z = at.z
	rotation.y = 0.0   # yaw 0 mira a -Z: hacia el centro de la cancha desde la banda +Z
	ctx.event_emitted.connect(_on_event)

func _exit_tree() -> void:
	if ctx != null and ctx.event_emitted.is_connected(_on_event):
		ctx.event_emitted.disconnect(_on_event)

func _on_event(e: GameEvent) -> void:
	if visual == null or visual.is_placeholder:
		return
	match e.type:
		GameEvent.Type.KICKOFF:
			if bool(e.data.get("intro", false)):
				_queue(&"referee_count", 0.3, maxf(float(e.data.get("seconds", 3.0)) - 0.5, 1.0))
			else:
				_queue(&"referee_point", 0.1, 1.6)
		GameEvent.Type.FOUL:
			# Modo 2: muestra la tarjeta amarilla de la captura; si no, senala.
			_queue(&"referee_foul", 0.4, 2.8 if AnimationCatalog.mocap_mode() else 1.8)
		GameEvent.Type.GOAL, GameEvent.Type.OUT_OF_PLAY:
			_queue(&"referee_point", 0.4, 1.8)
		GameEvent.Type.MATCH_END:
			_queue(&"referee_wave", 0.5, 4.0)

func _queue(situation: StringName, delay: float, cut: float) -> void:
	_pending = situation
	_delay = delay
	_cut = cut
	visual.stop_current_action()

func _physics_process(delta: float) -> void:
	Prof.begin(&"arbitro")
	_referee_step(delta)
	Prof.end(&"arbitro")

func _referee_step(delta: float) -> void:
	if visual == null:
		return
	if _pending != &"":
		_delay -= delta
		if _delay <= 0.0:
			visual.play_situation(_pending, int(ctx.match_time) if ctx != null else 0, 1.0, _cut)
			_pending = &""
	# Mientras gesticula no se mueve.
	if visual.is_action_playing() or ctx == null or ctx.ball == null or not visual.uses_pack:
		_set_twin(&"")
		visual.directional = true
		visual.dir_scale_override = -1.0
		visual.dir_velocity = Vector2.ZERO
		visual.drive_motion(0.0, 0.0, delta)
		return
	_follow_play(delta)

## Modo 4 (Json): no hay gemelos con raiz; el arbitro corre de frente por la banda con la marcha JSON (la cadencia sigue a la
## velocidad real, asi que los pies no patinan) y se para mirando la cancha.
var _json_speed: float = 0.0

func _follow_play_json(delta: float) -> void:
	var half_l: float = ctx.pitch.config.half_length() - 3.0
	var target_x: float = clampf(ctx.ball.global_position.x * 0.85, -half_l, half_l)
	var near_side: bool = ctx.ball.global_position.z * signf(_line_z) > 4.0
	var target_z: float = _line_z - signf(_line_z) * (0.2 if near_side else -0.4)
	var to := Vector2(target_x - position.x, target_z - position.z)
	var want: float = clampf((to.length() - 0.6) * 0.9, 0.0, 5.0) if to.length() > DEAD_ZONE else 0.0
	_json_speed = move_toward(_json_speed, want, 3.5 * delta)
	if _json_speed > 0.3:
		_turn_towards(Locomotion.yaw_from_dir(Vector3(to.x, 0.0, to.y).normalized()), delta)
		var f: Vector3 = Locomotion.dir_from_yaw(_yaw)
		var step: Vector3 = f * _json_speed * delta
		position += step
		travelled += step.length()
		var hl: float = ctx.pitch.config.half_length() + 1.0
		position.x = clampf(position.x, -hl, hl)
	else:
		_turn_towards(0.0, delta)
	visual.directional = false
	visual.dir_scale_override = -1.0
	visual.drive_motion(_json_speed, 0.0, delta)

## Sigue la pelota por la banda: de lado si la distancia es corta (mirando la cancha), de frente si es larga.
func _follow_play(delta: float) -> void:
	if visual.json_mode:
		_follow_play_json(delta)
		return
	var half_l: float = ctx.pitch.config.half_length() - 3.0
	var target_x: float = clampf(ctx.ball.global_position.x * 0.85, -half_l, half_l)
	var dx: float = target_x - position.x
	# Se acerca a la linea si la jugada esta en su banda; si no, se aparta un poco (mejor vista).
	var near_side: bool = ctx.ball.global_position.z * signf(_line_z) > 4.0
	var target_z: float = _line_z - signf(_line_z) * (0.2 if near_side else -0.4)
	var dz: float = target_z - position.z
	if absf(dx) < DEAD_ZONE and absf(dz) < 0.35:
		_set_twin(&"")
		_turn_towards(0.0, delta)
		visual.directional = true
		visual.dir_scale_override = -1.0
		visual.dir_velocity = Vector2.ZERO
		visual.drive_motion(0.0, 0.0, delta)
		return
	if absf(dx) > RUN_DISTANCE:
		# De frente por la banda: el gemelo segun la urgencia.
		_side_mode = false
		var twin: StringName = &"Jogging"
		if absf(dx) > 18.0:
			twin = &"Two_Cycle_Sprint"
		elif absf(dx) > 13.0:
			twin = &"Sprint"
		elif absf(dx) > 9.5:
			twin = &"Running"
		elif ctx.ball.linear_velocity.length() < 2.0:
			twin = &"Walking_7"
		_set_twin(twin)
		var want_yaw: float = Locomotion.yaw_from_dir(Vector3(signf(dx), 0.0, clampf(dz * 0.3, -0.3, 0.3)).normalized())
		_turn_towards(want_yaw, delta)
		var v: Vector2 = _twin_velocity(twin, delta)
		_move_local(v, delta)
		visual.directional = false
		visual.dir_scale_override = -1.0
		visual.drive_motion(v.length(), 0.0, delta)
		return
	# De lado (mirando la cancha): la direccion local elige el gemelo lateral, diagonal o hacia atras.
	_side_mode = true
	_turn_towards(0.0, delta)
	# Mirando a -Z: derecha = +X, adelante = -Z (local (derecha, adelante)).
	var local := Vector2(dx, -dz)
	var best: StringName = &"jog_strafe_right"
	var best_dot: float = -INF
	for id in SIDE_TWINS:
		if id == &"Strafe_3" and (absf(dx) < 4.0 or dx < 0.0):
			continue
		var d: Vector2 = (SIDE_TWINS[id] as Vector2).normalized()
		var score: float = d.dot(local.normalized()) + (0.05 if id == &"Strafe_3" else 0.0)
		if score > best_dot:
			best_dot = score
			best = id
	_set_twin(best)
	var vr: Vector2 = _twin_velocity(best, delta)
	_move_local(vr, delta)
	visual.directional = true
	visual.dir_blend_override = SIDE_TWINS[best]
	visual.dir_scale_override = 1.0
	visual.dir_velocity = Vector2(vr.x, vr.y)
	visual.drive_motion(0.0, 0.0, delta)

func _set_twin(id: StringName) -> void:
	if id != current_twin:
		current_twin = id
		_phase = 0.0
		if id != &"":
			twins_used[id] = int(twins_used.get(id, 0)) + 1

## Velocidad (adelante, derecha) en m/s del desplazamiento de raiz MEDIDO del gemelo en la fase actual; avanza la fase.
func _twin_velocity(id: StringName, delta: float) -> Vector2:
	var a: Animation = PackLibrary.clip(id)
	if a == null:
		return Vector2.ZERO
	var v: Vector2 = AnimationCatalog.root_velocity(id, _phase)
	_phase = fmod(_phase + delta, maxf(a.length, 0.05))
	return v

## Mueve el cuerpo con una velocidad local (adelante, derecha) segun la orientacion actual.
func _move_local(v: Vector2, delta: float) -> void:
	var f: Vector3 = Locomotion.dir_from_yaw(_yaw)
	var r := Vector3(-f.z, 0.0, f.x)
	var step: Vector3 = (f * v.x + r * v.y) * delta
	position += step
	travelled += step.length()
	var hl: float = ctx.pitch.config.half_length() + 1.0
	position.x = clampf(position.x, -hl, hl)

func _turn_towards(want: float, delta: float) -> void:
	var d: float = wrapf(want - _yaw, -PI, PI)
	_yaw = wrapf(_yaw + clampf(d, -deg_to_rad(360.0) * delta, deg_to_rad(360.0) * delta), -PI, PI)
	rotation.y = _yaw
