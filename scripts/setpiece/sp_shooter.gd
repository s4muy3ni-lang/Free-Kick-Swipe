class_name SpShooter
extends Node
## Tirador de los modos de tiros libres y penales: espera detras de la pelota con su carrera habitual, y al tirar ejecuta el
## golpeo elegido por ShotCatalog: trote (si hace falta) hasta el punto de la carrera del clip, golpeo con el pie MEDIDO en
## la pelota y salida del balon en el instante exacto de contacto del clip (Ball.kick), seguimiento de la pierna y
## recuperacion; mientras la pelota viaja la mira, y despues festeja o se lamenta (si el resultado llega mientras todavia
## termina el golpeo, la reaccion queda pendiente y sale al terminar: nunca se queda en bucle esperando).
##
## Tambien despeja pelotas sueltas (SpLooseBall): con require_touch > 0 el impulso solo sale si la punta del pie llega de
## verdad a la pelota en el contacto del clip (si no llega, emite `missed`).

signal contact(entry: Dictionary)
signal missed()

enum State { IDLE, APPROACH, KICK, AFTER, REACT }

var actor: SpActor
var ball: Ball
var foot: int = 1
var state: int = State.IDLE
var rng := RandomNumberGenerator.new()
## Golpeo en curso (entrada de ShotCatalog), su marco y desde donde arranca.
var entry: Dictionary = {}
var frame: Array = []
var start_at: float = 0.0
var kicked: bool = false
## Velocidad y giro con que sale la pelota en el contacto; flotado (tiro sin giro potente).
var shot_velocity := Vector3.ZERO
var shot_spin := Vector3.ZERO
var knuckle: bool = false
## Distancia entre el pie y la pelota en el contacto (m): medida en vivo (diagnostico y pruebas).
var contact_gap: float = -1.0
var _idle_clip: StringName = &""
## Velocidad del trote de aproximacion (m/s) y destino, para estimar cuanto falta para el contacto.
var _approach_speed: float = 3.0
var _approach_target := Vector3.ZERO
## Reaccion pendiente (-1 ninguna, 0 lamento, 1 festejo).
var _pending_react: int = -1
## Distancia maxima pie-pelota (m) para que el golpe salga (0 = siempre sale: tiros a pelota quieta).
var require_touch: float = 0.0

const IDLE_ROLES: Array = [&"idle_ready", &"idle"]

func setup(a: SpActor, b: Ball) -> void:
	actor = a
	ball = b
	actor.role = &"shooter"
	actor.clip_finished.connect(_on_clip_finished)

## Se para AL COSTADO de la pelota, del lado del pie que no patea (el diestro a la izquierda, el zurdo a la derecha) y un
## poco atras, como en los videos de referencia, mirando hacia la pelota y el arco. back/side: metros detras y al costado.
func stance(ball_pos: Vector3, aim: Vector3, back: float, side: float) -> void:
	state = State.IDLE
	kicked = false
	entry = {}
	contact_gap = -1.0
	_pending_react = -1
	var a := Vector3(aim.x, 0.0, aim.z).normalized()
	var b := Vector3(ball_pos.x, 0.0, ball_pos.z)
	actor.stop_moving()
	actor.global_position = b - a * back - SpClips.right_of(a) * side * float(foot)
	actor.set_facing((b + a * 3.0) - actor.global_position)
	var pool: Array[StringName] = []
	for r in IDLE_ROLES:
		for id in SpClips.by_role(r, false):
			if SpClips.root_travel(SpClips.meta(id)) < 0.3:
				pool.append(id)
	_idle_clip = pool[rng.randi() % pool.size()] if not pool.is_empty() else &""
	actor.play_loop(_idle_clip, 0.25)

## Ejecuta el tiro: e = golpeo elegido, shot_dir = direccion horizontal del tiro, v y w = salida de la pelota.
## La carrera sale desde donde espera: el clip entra en el punto de su carrera mas cercano al tirador (trota hasta ahi si
## hace falta, en curva desde el costado).
func execute(e: Dictionary, ball_pos: Vector3, shot_dir: Vector3, v: Vector3, w: Vector3, flotado: bool = false) -> void:
	entry = e
	shot_velocity = v
	shot_spin = w
	knuckle = flotado
	kicked = false
	_pending_react = -1
	frame = ShotCatalog.frame_for_shot(e, ball_pos, shot_dir)
	start_at = ShotCatalog.start_time_near(e, frame, actor.global_position)
	var start_body: Array = SpActor.body_at(StringName(e["id"]), start_at, frame[0], frame[1])
	var p: Vector3 = start_body[0]
	var gap: float = Vector3(p.x - actor.global_position.x, 0.0, p.z - actor.global_position.z).length()
	if gap > 0.35:
		state = State.APPROACH
		var spd: float = _root_speed(e, start_at)
		var loop: StringName = _loop_for(spd)
		_approach_speed = clampf(spd, 1.6, 5.0)
		_approach_target = p
		actor.move_to(p, _approach_speed, loop)
	else:
		_start_kick()

func _start_kick() -> void:
	state = State.KICK
	actor.play_clip(StringName(entry["id"]), frame[0], frame[1], 0.18 if start_at > 0.0 else 0.25, 1.0, start_at)

## Velocidad de la raiz del clip en el instante t (m/s), para entrar al clip sin cambiar de ritmo.
static func _root_speed(e: Dictionary, t: float) -> float:
	var roots: Array = e.get("roots", [])
	for i in range(roots.size() - 1):
		if float(roots[i + 1][0]) >= t:
			var a: Array = roots[i]
			var b: Array = roots[i + 1]
			return Vector2(float(b[1]) - float(a[1]), float(b[2]) - float(a[2])).length() / maxf(float(b[0]) - float(a[0]), 0.01)
	return 3.0

static func _loop_for(speed: float) -> StringName:
	var best: StringName = &""
	var best_d: float = INF
	for role in [&"walk", &"jog", &"loco_jog"]:
		for id in SpClips.by_role(role, false):
			var ns: float = float(SpClips.meta(id).get("natural_speed_json", 0.0))
			if ns <= 0.2:
				continue
			var d: float = absf(ns - speed)
			if d < best_d:
				best_d = d
				best = id
	return best

func _physics_process(_delta: float) -> void:
	if actor == null:
		return
	match state:
		State.APPROACH:
			if not actor.is_moving():
				_start_kick()
		State.KICK:
			# Seguro: si el clip llego al contacto o ya termino (cuadros perdidos en un telefono lento), el golpe sale igual;
			# nunca queda el tiro esperando.
			if not kicked and (actor.clip_time() >= float(entry["tc"]) or not actor.is_playing_clip(StringName(entry["id"]))):
				_do_contact()
		State.AFTER:
			# Mira la pelota mientras viaja (gira en el sitio).
			if ball != null:
				actor.face_towards(ball.global_position - actor.global_position)

func _do_contact() -> void:
	kicked = true
	var toe: Vector3 = actor.bone_world(SpActor.TOE_R if int(entry["foot"]) > 0 else SpActor.TOE_L)
	contact_gap = Vector2(toe.x - ball.global_position.x, toe.z - ball.global_position.z).length()
	if require_touch > 0.0 and (contact_gap > require_touch or ball.global_position.y > 0.7 or ball.is_held()):
		missed.emit()
		return
	ball.kick(shot_velocity, shot_spin, actor)
	if knuckle:
		ball.set_knuckle(rng.randf_range(2.0, 4.0), rng.randf_range(1.2, 2.2), rng.randf_range(0.0, TAU))
	contact.emit(entry)

## Segundos que faltan para el contacto del pie (estimacion exacta: el trote es a velocidad fija y el clip a velocidad 1).
func time_to_contact() -> float:
	if entry.is_empty():
		return -1.0
	var tc: float = float(entry["tc"])
	match state:
		State.APPROACH:
			var d: float = Vector3(_approach_target.x - actor.global_position.x, 0.0, _approach_target.z - actor.global_position.z).length()
			return d / maxf(_approach_speed, 0.1) + (tc - start_at)
		State.KICK:
			return maxf(tc - actor.clip_time(), 0.0)
	return 0.0

## El golpe tiene que salir (seguro del juego si algo lo demoro demasiado).
func force_contact() -> void:
	if not kicked and not entry.is_empty():
		_do_contact()

func _on_clip_finished(_id: StringName) -> void:
	match state:
		State.KICK:
			if not kicked:
				_do_contact()
			state = State.AFTER
			if _pending_react >= 0:
				var g: bool = _pending_react == 1
				_pending_react = -1
				react(g)
				if state == State.REACT:
					return
			actor.play_loop(_idle_clip, 0.3)
		State.REACT:
			state = State.AFTER
			actor.play_loop(_idle_clip, 0.35)

## Festejo (gol) o lamento/enojo (atajada, palo, fuera). Con gol puede salir corriendo a festejar (clips con recorrido).
## Si todavia esta en la carrera o el golpeo, queda pendiente y sale al terminar el clip.
func react(goal: bool) -> void:
	# Con el seguimiento de la pierna ya hecho (0,4 s despues del contacto) reacciona enseguida, mezclando desde el golpeo.
	var follow_done: bool = state == State.KICK and kicked and actor.clip_time() > float(entry.get("tc", 0.0)) + 0.4
	if state == State.APPROACH or (state == State.KICK and not follow_done):
		_pending_react = 1 if goal else 0
		return
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER, rng, 2.5, 1.5) if goal else SpReactions.pick(SpReactions.MISS_SHOOTER, rng, 1.6, 1.2)
	if id == &"":
		return
	state = State.REACT
	actor.play_here(id, 0.3)
