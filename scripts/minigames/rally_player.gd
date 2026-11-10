class_name RallyPlayer
extends Node
## Jugador de los modos de peloteo (etapa B: «Que no caiga» y futbol-tenis). Corre hacia la zona de caida prevista
## (BallPredictor), elige el clip de control por la ALTURA real a la que llega la pelota (cabeza, pecho, muslo, pie o
## volea) y el toque solo sale si la pelota pasa de verdad dentro del alcance de esa parte del cuerpo (huesos del
## esqueleto): nada se pega ni se teletransporta. Si llega mal parado (lejos de la caida), el toque sale desviado y
## flojo; si no llega, la pelota pica. El control amortigua (la pelota sube cerca del cuerpo); la devolucion sale hacia
## el objetivo pedido con ShotSolver desde el punto real del contacto.

signal touched(kind: StringName)

enum State { IDLE, MOVE, PLAY }

## Alcance de cada parte (m) y ventana del clip antes de la llegada (s).
const REACH := {"cabeza": 0.5, "pecho": 0.5, "muslo": 0.55, "pie": 0.65, "volea": 0.7}
const CLIP_LEAD := 0.45
## Si el jugador quedo a mas de esto de la pelota en el contacto, el toque sale desviado.
const CLEAN_DIST := 0.8

var actor: SpActor
var ball: Ball
var rng := RandomNumberGenerator.new()
var run_speed: float = 4.6
var state: int = State.IDLE
## Error de posicionamiento (m, IA por dificultad; 0 = perfecto) y retardo de reaccion (s).
var move_err: float = 0.0
var react_delay: float = 0.0

## Pedido pendiente: donde caera la pelota y cuando; y que hacer al tocarla.
var _landing := Vector3.INF
var _arrive_t: float = INF
var _wait: float = 0.0
## Orden de devolucion: {target (Vector3), speed (float)}; vacia = control (amortiguar hacia arriba).
var order: Dictionary = {}
var _armed: bool = false
var _part: String = ""
## Ultimo toque que hizo (para las reglas del juego) y la velocidad con la que salio la pelota (el impulso recien se
## integra en el paso siguiente: el juego necesita la salida YA para predecir la caida).
var last_touch: StringName = &""
var last_out := Vector3.ZERO

static var _pools: Dictionary = {}

func setup(a: SpActor, b: Ball) -> void:
	actor = a
	ball = b
	a.role = &"rally"

## Clips de control por rol, sin bucles y casi sin recorrido de raiz (los originales no se tocan).
static func pool(roles: Array) -> Array[StringName]:
	var key: String = str(roles)
	if not _pools.has(key):
		var out: Array[StringName] = []
		for r in roles:
			for id in SpClips.by_role(StringName(r)):
				var anim: Animation = SpClips.anim(id)
				if anim != null and anim.loop_mode == Animation.LOOP_NONE and SpClips.root_travel(SpClips.meta(id)) <= 0.9 \
						and SpClips.length(id) >= 0.5 and SpClips.length(id) <= 2.6:
					out.append(id)
		_pools[key] = out
	return _pools[key]

## La pelota viene: correr a la zona de caida (con el error propio) y esperar su llegada.
func expect(landing: Vector3, arrive_t: float) -> void:
	_landing = landing
	if move_err > 0.0:
		_landing += Vector3(rng.randf_range(-move_err, move_err), 0, rng.randf_range(-move_err, move_err))
	_arrive_t = arrive_t
	_wait = react_delay
	_armed = true
	last_touch = &""
	state = State.MOVE

func cancel() -> void:
	_armed = false
	state = State.IDLE
	order = {}
	if actor.is_moving():
		actor.stop_moving()

func busy() -> bool:
	return _armed or state == State.PLAY

## Parte del cuerpo para una pelota que llega a la altura h (m), y su hueso.
static func part_for(h: float, returning: bool) -> String:
	if returning and h > 0.25 and h < 1.25:
		return "volea"
	if h >= 1.45:
		return "cabeza"
	if h >= 0.95:
		return "pecho"
	if h >= 0.5:
		return "muslo"
	return "pie"

func _part_pos(part: String) -> Vector3:
	match part:
		"cabeza":
			return actor.bone_world(SpActor.HEAD)
		"pecho":
			return actor.bone_world(SpActor.HIPS).lerp(actor.bone_world(SpActor.HEAD), 0.55)
		"muslo":
			var hips: Vector3 = actor.bone_world(SpActor.HIPS)
			return hips + actor.facing() * 0.18 + Vector3.DOWN * 0.22
		_:
			var l: Vector3 = actor.bone_world(SpActor.TOE_L)
			var r: Vector3 = actor.bone_world(SpActor.TOE_R)
			return l if l.distance_to(ball.global_position) < r.distance_to(ball.global_position) else r

func _clip_for(part: String) -> StringName:
	var roles: Array = {"cabeza": [&"header"], "pecho": [&"receive_chest", &"receive"], "muslo": [&"receive", &"ball_stop"],
		"pie": [&"receive_foot", &"ball_stop", &"receive"], "volea": [&"volley"]}[part]
	var p: Array[StringName] = pool(roles)
	return p[rng.randi() % p.size()] if not p.is_empty() else &""

func _physics_process(delta: float) -> void:
	if actor == null or not _armed:
		return
	_arrive_t -= delta
	if _wait > 0.0:
		_wait -= delta
		return
	if state == State.MOVE:
		var here := Vector3(actor.global_position.x, 0, actor.global_position.z)
		var flat := Vector3(_landing.x, 0, _landing.z)
		if here.distance_to(flat) > 0.35:
			actor.move_to(flat, run_speed, SpShooter._loop_for(run_speed))
		elif actor.is_moving():
			actor.stop_moving()
		# Cuando falta poco, arma el clip de la parte que corresponde a la altura de llegada.
		if _arrive_t <= CLIP_LEAD:
			var h: float = clampf(ball.global_position.y + ball.linear_velocity.y * _arrive_t * 0.5, 0.1, 2.2)
			_part = part_for(h, not order.is_empty())
			actor.face_towards(ball.global_position - actor.global_position)
			var id: StringName = _clip_for(_part)
			if id != &"":
				actor.play_here(id, 0.15)
			state = State.PLAY
		return
	# PLAY: el toque sale SOLO si la pelota entra de verdad en el alcance de la parte.
	var part_pos: Vector3 = _part_pos(_part)
	var d: float = part_pos.distance_to(ball.global_position)
	if d <= float(REACH[_part]):
		_touch(part_pos)
		return
	# La pelota ya paso (pico o quedo atras) o el clip termino sin toque: fallo.
	if _arrive_t < -0.7 or (actor.clip_done() and _arrive_t < -0.2):
		_armed = false
		state = State.IDLE
		touched.emit(&"miss")

func _touch(part_pos: Vector3) -> void:
	_armed = false
	state = State.IDLE
	var here := Vector3(actor.global_position.x, 0, actor.global_position.z)
	var clean: bool = here.distance_to(Vector3(_landing.x, 0, _landing.z)) <= CLEAN_DIST
	var out := Vector3.ZERO
	if order.is_empty():
		# Control: amortigua, la pelota sube cerca del cuerpo (lista para el proximo toque).
		out = Vector3.UP * rng.randf_range(4.0, 4.8) + (Vector3(here.x, 0, here.z) + actor.facing() * 0.35 - Vector3(ball.global_position.x, 0, ball.global_position.z)) * 1.6
		last_touch = &"control"
	else:
		var sol: Dictionary = ShotSolver.solve(ball.global_position, order["target"], float(order["speed"]), Vector3.ZERO, (order["target"] as Vector3).x)
		out = sol.get("velocity", ((order["target"] as Vector3) - ball.global_position).normalized() * float(order["speed"]))
		last_touch = &"devolucion"
	if not clean:
		# Llego mal parado: el toque sale flojo y desviado (puede caerse).
		out = out * 0.45 + Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(0.0, 1.5), rng.randf_range(-2.0, 2.0))
		last_touch = &"desviado"
	last_out = out
	ball.kick(out, Vector3.ZERO, actor)
	order = {}
	touched.emit(last_touch)
