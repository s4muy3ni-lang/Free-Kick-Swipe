class_name SpLooseBall
extends Node
## Pelota suelta al terminar la jugada (rebote del arquero, del palo o de la barrera, o un tiro flojo que se frena dentro o
## cerca del area): alguien va a buscarla, como en un partido, y NUNCA queda muerta en el area. Va el que llega antes a
## donde va a estar la pelota (BallPredictor, con botes y rodadura medidos de Ball):
##  - el arquero, si la pelota queda dentro de su area: corre y la recoge con las manos (SpKeeper.collect);
##  - un defensor (tiro libre: sueltos y barrera): corre, se acomoda del lado del arco y la despeja «a cualquier lado» lejos
##    del arco con un golpeo del banco JSON elegido por ShotCatalog. Lo patea un SpShooter con require_touch: el impulso
##    sale solo si la punta del pie llega de verdad a la pelota en el contacto del clip; si no llega, se acomoda y vuelve a
##    intentar (hasta MAX_TRIES).
## Si el elegido no la consigue (no llega, se le escapa), va el siguiente que llegue antes; el arquero que no pudo
## recogerla con las manos la despeja con el pie. Mientras la pelota siga en el area, alguien va (hasta MAX_ROUNDS
## intentos). Fuera del area solo va un defensor que este cerca (MAX_DIST).
## El resultado de la jugada ya esta decidido (un despeje o un palo es tiro fallido): esto es lo que pasa despues.
## La pelota nunca se mueve sola: solo cambia por el impulso del golpeo o al quedar en las manos del arquero (Ball.hold).

enum State { IDLE, KEEPER, CHASE, KICK, DONE }

const AREA_DEPTH := 16.5
const AREA_HALF := 20.16
## Carrera del defensor (m/s), distancia maxima a la que sale a buscarla fuera del area y reintentos del despeje.
const RUN := 5.2
const MAX_DIST := 24.0
const MAX_TRIES := 3
## Cuantas veces se vuelve a elegir a alguien si el anterior no la consiguio.
const MAX_ROUNDS := 5
## Para patear: la pelota casi quieta y el jugador en su sitio.
const KICK_BALL_SPEED := 2.2
const KICK_ARRIVE := 0.9

var ball: Ball
var goal_x: float = 52.5
var state: int = State.IDLE
## Quien fue a buscarla (no reacciona al resultado: esta jugando).
var responder: SpActor = null
var keeper: SpKeeper = null
var rng := RandomNumberGenerator.new()
## Despeje hecho (el pie llego y la pelota salio) / el arquero la tiene.
var cleared: bool = false
## Registro de lo que paso (diagnostico y pruebas): ["arquero manos", "defensor pie", ...].
var log_steps: Array[String] = []
var _kicker: SpShooter = null
var _kicker_is_keeper: bool = false
var _clear_dir := Vector3(-1, 0, 0)
var _tries: int = 0
var _t: float = 0.0
var _old_role: StringName = &""
var _defs: Array = []
var _failed: Dictionary = {}
var _rounds: int = 0

func setup(b: Ball, gx: float) -> void:
	ball = b
	goal_x = gx

## Pone en marcha la busqueda. k: arquero; defenders: actores que pueden despejar (vacio en los penales). Devuelve el actor
## elegido o null (la pelota esta en manos del arquero, en el arco, fuera de la cancha o lejos).
func start(k: SpKeeper, defenders: Array) -> SpActor:
	stop()
	keeper = k
	_defs = defenders.duplicate()
	_failed.clear()
	_rounds = 0
	cleared = false
	log_steps.clear()
	return _assign()

func in_box(p: Vector3) -> bool:
	return p.x > goal_x - AREA_DEPTH and p.x < goal_x and absf(p.z) < AREA_HALF

## Elige al que llega antes entre los que todavia no fallaron (si todos fallaron, vuelven a ser candidatos).
func _assign() -> SpActor:
	_release()
	if ball == null or ball.is_held():
		state = State.DONE
		return null
	var rest: Vector3 = rest_point()
	if rest.x > goal_x - 0.15 or absf(rest.z) > 33.5:
		state = State.DONE
		return null
	var boxed: bool = in_box(rest) or in_box(ball.global_position)
	var cands: Array = []
	if keeper != null and keeper.actor.visible:
		var dk: float = _flat(rest - keeper.actor.global_position).length()
		var busy: float = 1.0 if keeper.is_busy() else 0.2
		if boxed:
			cands.append([keeper.actor, "manos", dk / SpKeeper.COLLECT_RUN + busy])
		if boxed or dk < 10.0:
			cands.append([keeper.actor, "pie", dk / RUN + busy + 0.4])
	for a in _defs:
		var d: SpActor = a
		if d == null or not d.visible:
			continue
		var dd: float = _flat(rest - d.global_position).length()
		if not boxed and dd > MAX_DIST:
			continue
		cands.append([d, "pie", dd / RUN + 0.3])
	var pool: Array = cands.filter(func(c: Array) -> bool: return not _failed.has(_key(c)))
	if pool.is_empty():
		pool = cands
		_failed.clear()
	if pool.is_empty():
		state = State.DONE
		return null
	pool.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) < float(b[2]))
	var pick: Array = pool[0]
	_t = 0.0
	responder = pick[0]
	log_steps.append(("arquero " if keeper != null and responder == keeper.actor else "defensor ") + String(pick[1]))
	if String(pick[1]) == "manos":
		keeper.collect()
		state = State.KEEPER
		return responder
	_start_kicker(responder, keeper != null and responder == keeper.actor, rest)
	return responder

func _key(c: Array) -> String:
	return "%d:%s" % [(c[0] as Object).get_instance_id(), c[1]]

func _start_kicker(a: SpActor, is_keeper: bool, rest: Vector3) -> void:
	_tries = 0
	_kicker_is_keeper = is_keeper
	if is_keeper:
		# El arquero deja de manejarse solo mientras despeja con el pie (no choca la pelota con su cuerpo a la vez).
		keeper.paused = true
	# Hacia donde la saca: lejos del arco y hacia el costado de la pelota, con azar (a cualquier lado).
	var side: float = signf(rest.z) if absf(rest.z) > 0.5 else (1.0 if rng.randf() < 0.5 else -1.0)
	_clear_dir = Vector3(-1.0, 0.0, side * rng.randf_range(0.3, 1.3) + rng.randf_range(-0.3, 0.3)).normalized()
	_old_role = a.role
	_kicker = SpShooter.new()
	_kicker.name = "LooseBallKicker"
	add_child(_kicker)
	_kicker.setup(a, ball)
	_kicker.foot = 1 if rng.randf() < 0.7 else -1
	_kicker.require_touch = 0.5
	_kicker.missed.connect(_on_missed)
	_kicker.contact.connect(_on_contact)
	state = State.CHASE

## Donde se va a frenar la pelota (o donde estara en 3 s).
func rest_point() -> Vector3:
	var traj: PackedVector3Array = BallPredictor.trajectory(ball.global_position, ball.linear_velocity, 3.0, 1.0 / 30.0, ball.angular_velocity)
	return traj[traj.size() - 1] if traj.size() > 0 else ball.global_position

func active() -> bool:
	return state in [State.KEEPER, State.CHASE, State.KICK]

## Suelta al jugador elegido (vuelve a su rol y, el arquero, a manejarse solo).
func _release() -> void:
	if _kicker != null:
		_kicker.queue_free()
		_kicker = null
	if responder != null and _old_role != &"":
		responder.role = _old_role
	if _kicker_is_keeper and keeper != null:
		keeper.paused = false
	_kicker_is_keeper = false
	_old_role = &""
	responder = null

func stop() -> void:
	_release()
	keeper = null
	_defs = []
	state = State.IDLE

func _physics_process(delta: float) -> void:
	if state == State.IDLE or state == State.DONE or ball == null:
		return
	_t += delta
	match state:
		State.KEEPER:
			if keeper == null:
				state = State.DONE
			elif ball.is_held():
				cleared = true
				state = State.DONE
			elif not keeper.is_collecting():
				# No pudo recogerla: va otro (o el mismo arquero, con el pie).
				_fail("manos")
		State.CHASE:
			Prof.begin(&"pelota suelta")
			_chase()
			Prof.end(&"pelota suelta")
		State.KICK:
			if _t > 9.0:
				_fail("pie")

func _chase() -> void:
	if ball.is_held():
		state = State.DONE
		_release()
		return
	if _t > 9.0:
		_fail("pie")
		return
	# Despues de un golpe que no llego, termina el clip antes de volver a acomodarse.
	if _kicker != null and _kicker.state == SpShooter.State.KICK and responder.is_playing_clip():
		return
	var bp: Vector3 = ball.global_position
	var bv: Vector3 = ball.linear_velocity
	var me: Vector3 = responder.global_position
	var dist: float = _flat(bp - me).length()
	var traj: PackedVector3Array = BallPredictor.trajectory(bp, bv, 1.6, 1.0 / 30.0, ball.angular_velocity)
	var k: int = clampi(int(dist / RUN * 30.0), 0, traj.size() - 1)
	var aim: Vector3 = traj[k] if traj.size() > 0 else bp
	aim.y = 0.0
	# Se acomoda detras de la pelota respecto de hacia donde la va a sacar; si esta del lado equivocado, la rodea.
	var spot: Vector3 = aim - _clear_dir * 1.3
	var rel: Vector3 = _flat(me - aim)
	if rel.dot(_clear_dir) > 0.2:
		var perp := Vector3(-_clear_dir.z, 0.0, _clear_dir.x)
		var s: float = 1.0 if rel.dot(perp) >= 0.0 else -1.0
		spot = aim + perp * s * 1.6 - _clear_dir * 0.4
	var to_spot: float = _flat(spot - me).length()
	if bv.length() < KICK_BALL_SPEED and to_spot < KICK_ARRIVE:
		_begin_kick(bp)
		return
	var spd: float = RUN if to_spot > 2.5 else maxf(1.5, RUN * to_spot / 2.5)
	responder.move_to(spot, spd, SpShooter._loop_for(spd), _flat(aim - me))

func _begin_kick(bp: Vector3) -> void:
	var me: Vector3 = responder.global_position
	var app: Vector3 = _flat(bp - me).normalized()
	if app == Vector3.ZERO:
		app = _clear_dir
	# El despeje sale cerca de la direccion de la carrera (los golpeos del banco abren hasta ~40 grados).
	var ang: float = clampf(ShotCatalog.signed_deg(app, _clear_dir), -35.0, 35.0)
	var dir: Vector3 = app.rotated(Vector3.UP, deg_to_rad(-ang))
	if ShotCatalog.signed_deg(app, dir) * ang < 0.0:
		dir = app.rotated(Vector3.UP, deg_to_rad(ang))
	if dir.x > 0.35:
		# Mirando a su arco: la saca al costado.
		dir = Vector3(0.0, 0.0, signf(_clear_dir.z) if _clear_dir.z != 0.0 else 1.0)
	var v: Vector3 = dir * rng.randf_range(17.0, 24.0) + Vector3.UP * rng.randf_range(4.0, 8.5)
	var rel_deg: float = ShotCatalog.signed_deg(app, dir)
	var e: Dictionary = ShotCatalog.choose(_kicker.foot, rel_deg, ShotCatalog.Kind.POWER, false, rng, v.length())
	if e.is_empty():
		e = ShotCatalog.choose(_kicker.foot, rel_deg, ShotCatalog.Kind.NORMAL, false, rng)
	if e.is_empty():
		_fail("pie")
		return
	_kicker.execute(e, bp, dir, v, Vector3.ZERO)
	# La pelota casi quieta todavia rueda: se apunta a donde estara en el contacto.
	var tc: float = _kicker.time_to_contact()
	var traj: PackedVector3Array = BallPredictor.trajectory(bp, ball.linear_velocity, maxf(tc, 0.05) + 0.1, 1.0 / 30.0, ball.angular_velocity)
	var at: Vector3 = traj[clampi(int(tc * 30.0), 0, traj.size() - 1)] if traj.size() > 0 else bp
	if _flat(at - bp).length() > 0.05:
		_kicker.execute(e, at, dir, v, Vector3.ZERO)
	state = State.KICK

func _on_contact(_entry: Dictionary) -> void:
	cleared = true
	state = State.DONE
	log_steps.append("despejada")
	var a: SpActor = responder
	a.clip_finished.connect(_after_clear.bind(a), CONNECT_ONE_SHOT)

func _after_clear(_id: StringName, a: SpActor) -> void:
	var was_keeper: bool = _kicker_is_keeper
	_release()
	if was_keeper and keeper != null and a == keeper.actor:
		keeper.idle()
		return
	var id: StringName = SpReactions.pick(SpReactions.HAPPY_DEFENDER, rng, 1.2, 1.0)
	if id != &"" and a.visible:
		a.play_here(id, 0.3)

func _on_missed() -> void:
	_tries += 1
	log_steps.append("no llego al pie")
	if _tries >= MAX_TRIES:
		_fail("pie")
		return
	state = State.CHASE

## El elegido no la consiguio: si la pelota sigue suelta en el area (o cerca), va el siguiente.
func _fail(kind: String) -> void:
	if responder != null:
		_failed["%d:%s" % [responder.get_instance_id(), kind]] = true
		responder.stop_moving()
	_rounds += 1
	if _rounds >= MAX_ROUNDS or ball.is_held():
		_release()
		state = State.DONE
		return
	_assign()

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
