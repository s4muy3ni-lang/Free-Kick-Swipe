class_name GoalReplay
extends Node
## Repeticion de los goles. Graba continuamente (30 Hz, buffer circular) el estado VISIBLE del partido: posicion y giro
## de la pelota, de cada futbolista, de los arqueros y del arbitro, y la pose de cada hueso de sus esqueletos (lo que la
## animacion produjo de verdad). Tras un gol reproduce los ultimos segundos de la jugada en camara lenta, con una camara
## de repeticion propia, y despues devuelve todo exactamente al estado del momento en que empezo la repeticion.
##
## Durante la repeticion el arbol se pausa (la simulacion no avanza: nadie se mueve ni la pelota) y solo este nodo, la
## camara de repeticion y el HUD siguen activos. Cualquier boton (o tocar la pantalla) la salta.

signal started
signal finished(skipped: bool)

## Muestras por segundo de la grabacion y segundos que se guardan.
const RATE := 30.0
const BUFFER_SECONDS := 7.0
## Segundos de jugada antes del gol que se repiten y segundos despues (pelota en la red).
const BEFORE_GOAL := 4.5
const AFTER_GOAL := 0.7
## Velocidad de reproduccion (camara lenta).
const PLAYBACK_SPEED := 0.6

var ctx: MatchContext = null
var actors: Array[Node3D] = []
var camera: Camera3D = null
var main_camera: Camera3D = null
## true mientras se reproduce (el partido esta congelado).
var playing: bool = false
## Muestras grabadas en total y reproducidas en la ultima repeticion (pruebas y diagnostico).
var recorded: int = 0
var last_played_frames: int = 0
var replays_shown: int = 0
var enabled: bool = true

var _frames: Array = []          # [{t, ball: [pos, quat], actors: [[pos, yaw, rig_rot, bones(PackedFloat32Array)], ...]}]
var _acc: float = 0.0
var _clock: float = 0.0
var _goal_clock: float = -1.0
var _clip: Array = []
var _play_t: float = 0.0
var _restore: Dictionary = {}
var _cam_pos: Vector3 = Vector3.ZERO
var _skip_armed: bool = false

func _exit_tree() -> void:
	if playing:
		playing = false
		get_tree().paused = false

func setup(context: MatchContext, tracked: Array[Node3D], match_camera: Camera3D) -> void:
	ctx = context
	actors = tracked
	main_camera = match_camera
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.name = "ReplayCamera"
	camera.fov = 38.0
	camera.current = false
	add_child(camera)

## Graba una muestra cada 1/RATE s de tiempo de juego.
func _physics_process(delta: float) -> void:
	Prof.begin(&"repeticion")
	_replay_step(delta)
	Prof.end(&"repeticion")

func _replay_step(delta: float) -> void:
	if ctx == null:
		return
	if playing:
		_tick_playback(delta)
		return
	if get_tree().paused:
		return
	_clock += delta
	_acc += delta
	if _acc < 1.0 / RATE:
		return
	_acc -= 1.0 / RATE
	_frames.append(_capture())
	recorded += 1
	while _frames.size() > int(BUFFER_SECONDS * RATE):
		_frames.pop_front()

func _capture() -> Dictionary:
	var b: Ball = ctx.ball
	var states: Array = []
	for a in actors:
		states.append(_capture_actor(a))
	return {"t": _clock, "ball": [b.global_position, b.global_transform.basis.get_rotation_quaternion()], "actors": states}

func _visual_of(a: Node3D) -> FootballerVisual:
	var v: Variant = a.get("visual")
	return v as FootballerVisual if v is FootballerVisual else null

func _capture_actor(a: Node3D) -> Array:
	var bones := PackedFloat32Array()
	var rig_rot := Vector3.ZERO
	var v: FootballerVisual = _visual_of(a)
	if v != null and v.skeleton != null and not v.is_placeholder:
		var sk: Skeleton3D = v.skeleton
		bones.resize(sk.get_bone_count() * 7)
		for i in sk.get_bone_count():
			var p: Vector3 = sk.get_bone_pose_position(i)
			var q: Quaternion = sk.get_bone_pose_rotation(i)
			bones[i * 7] = p.x
			bones[i * 7 + 1] = p.y
			bones[i * 7 + 2] = p.z
			bones[i * 7 + 3] = q.x
			bones[i * 7 + 4] = q.y
			bones[i * 7 + 5] = q.z
			bones[i * 7 + 6] = q.w
		if v.rig != null:
			rig_rot = v.rig.rotation
	return [a.global_position, a.rotation.y, rig_rot, bones]

## Marca el instante del gol: la repeticion se arma AFTER_GOAL s despues (la pelota ya dentro de la red).
func mark_goal() -> void:
	_goal_clock = _clock

## Empieza la repeticion de la jugada del ultimo gol. Devuelve false si no hay grabacion suficiente.
func start() -> bool:
	if not enabled or playing or _frames.size() < 10 or _goal_clock < 0.0:
		return false
	_clip = []
	for f in _frames:
		var t: float = float(f["t"])
		if t >= _goal_clock - BEFORE_GOAL and t <= _goal_clock + AFTER_GOAL:
			_clip.append(f)
	if _clip.size() < 10:
		return false
	_restore = _capture()
	playing = true
	_play_t = float(_clip[0]["t"])
	_skip_armed = false
	last_played_frames = 0
	replays_shown += 1
	get_tree().paused = true
	for a in actors:
		var v: FootballerVisual = _visual_of(a)
		if v != null and v.anim_tree != null:
			v.anim_tree.active = false
	if main_camera != null:
		main_camera.current = false
	camera.current = true
	var b0: Vector3 = (_clip[0]["ball"] as Array)[0]
	_cam_pos = _camera_target(b0)
	_apply(_clip[0])
	started.emit()
	return true

## Salta la repeticion (boton o toque).
func skip() -> void:
	if playing:
		_finish(true)

func _tick_playback(delta: float) -> void:
	# Cualquier boton salta la repeticion (se arma al soltar todo, para no saltarla con el mismo toque del gol).
	var any: bool = Input.is_action_pressed("pass") or Input.is_action_pressed("shoot") or Input.is_action_pressed("switch_player") or Input.is_action_pressed("pause_game")
	if not any:
		_skip_armed = true
	elif _skip_armed:
		_finish(true)
		return
	_play_t += delta * PLAYBACK_SPEED
	var last: float = float(_clip[_clip.size() - 1]["t"])
	if _play_t >= last:
		_finish(false)
		return
	# Interpolacion entre las dos muestras que rodean el instante.
	var i: int = 0
	while i < _clip.size() - 2 and float(_clip[i + 1]["t"]) < _play_t:
		i += 1
	var a: Dictionary = _clip[i]
	var b: Dictionary = _clip[i + 1]
	var u: float = clampf((_play_t - float(a["t"])) / maxf(float(b["t"]) - float(a["t"]), 0.0001), 0.0, 1.0)
	_apply(a if u < 0.5 else b, a, b, u)
	last_played_frames += 1
	_follow_camera(delta)

func _apply(f: Dictionary, a: Dictionary = {}, b: Dictionary = {}, u: float = 0.0) -> void:
	var ball: Ball = ctx.ball
	var bp: Vector3 = (f["ball"] as Array)[0]
	var bq: Quaternion = (f["ball"] as Array)[1]
	if not a.is_empty():
		bp = ((a["ball"] as Array)[0] as Vector3).lerp((b["ball"] as Array)[0], u)
		bq = ((a["ball"] as Array)[1] as Quaternion).slerp((b["ball"] as Array)[1], u)
	ball.global_transform = Transform3D(Basis(bq), bp)
	var states: Array = f["actors"]
	for k in mini(actors.size(), states.size()):
		var s: Array = states[k]
		var pos: Vector3 = s[0]
		var yaw: float = s[1]
		if not a.is_empty():
			var sa: Array = (a["actors"] as Array)[k]
			var sb: Array = (b["actors"] as Array)[k]
			pos = (sa[0] as Vector3).lerp(sb[0], u)
			yaw = lerp_angle(float(sa[1]), float(sb[1]), u)
		_apply_actor(actors[k], pos, yaw, s[2], s[3])

func _apply_actor(a: Node3D, pos: Vector3, yaw: float, rig_rot: Vector3, bones: PackedFloat32Array) -> void:
	a.global_position = pos
	a.rotation.y = yaw
	var v: FootballerVisual = _visual_of(a)
	if v == null or v.skeleton == null or bones.is_empty():
		return
	if v.rig != null:
		v.rig.rotation = rig_rot
	var sk: Skeleton3D = v.skeleton
	for i in mini(sk.get_bone_count(), bones.size() / 7):
		sk.set_bone_pose_position(i, Vector3(bones[i * 7], bones[i * 7 + 1], bones[i * 7 + 2]))
		sk.set_bone_pose_rotation(i, Quaternion(bones[i * 7 + 3], bones[i * 7 + 4], bones[i * 7 + 5], bones[i * 7 + 6]))

## Camara de repeticion: mas baja y cercana que la de juego, desde la banda opuesta, siguiendo la pelota con suavidad.
func _camera_target(ball_pos: Vector3) -> Vector3:
	return Vector3(ball_pos.x * 0.85, 6.5, ball_pos.z - 11.0)

func _follow_camera(delta: float) -> void:
	var bp: Vector3 = ctx.ball.global_position
	var k: float = 1.0 - pow(0.5, delta / 0.35)
	_cam_pos = _cam_pos.lerp(_camera_target(bp), k)
	camera.look_at_from_position(_cam_pos, Vector3(bp.x, 0.6, bp.z * 0.7), Vector3.UP)

func _finish(skipped: bool) -> void:
	playing = false
	if not _restore.is_empty():
		_apply(_restore)
	for a in actors:
		var v: FootballerVisual = _visual_of(a)
		if v != null and v.anim_tree != null:
			v.anim_tree.active = true
	camera.current = false
	if main_camera != null:
		main_camera.current = true
	get_tree().paused = false
	_goal_clock = -1.0
	finished.emit(skipped)
