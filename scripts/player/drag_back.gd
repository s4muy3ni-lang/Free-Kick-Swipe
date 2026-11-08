class_name DragBack
extends RefCounted
## Vuelta atras pisando la pelota (arrastre con la suela, la media vuelta del futsal). Con la pelota delante y el
## joystick hacia atras, en vez de rodear la pelota el jugador:
##  1. llega: sigue un instante su carrera y apoya la SUELA encima de la pelota (IK del pie hasta lo alto de la pelota);
##  2. pisa: el cuerpo se planta y la suela frena la pelota con el (un impulso por paso de fisica igualando la
##     velocidad de la suela: es un contacto, no un teletransporte);
##  3. arrastra: la suela tira la pelota hacia atras (impulso hacia el rumbo nuevo, un poco del lado del pie) y la acompana;
##  4. gira: el cuerpo pivota 180 grados hacia el lado del pie que arrastro y sale detras de la pelota.
## Despues sigue la conduccion normal (la pelota queda delante, en el rumbo nuevo). Es un regate: lo pide el boton
## REGATE con el joystick hacia atras (request); el joystick hacia atras solo hace el giro con toques (BallTurn). Lo usan
## la persona y la IA con la misma mecanica. Como en First Touch Soccer (CPlayer::Turn), el giro cerrado es una accion
## del cuerpo con su propio punto de contacto con la pelota, no un toque de carrera mas.

## Angulo (grados) minimo entre el frente del cuerpo y el joystick para hacer la vuelta.
const MIN_ANGLE := 135.0
const MIN_STICK := 0.45
## Velocidad (m/s) maxima del cuerpo: mas rapido manda la media vuelta por el costado (BallHandler, toque redirect).
const MAX_SPEED := 5.6
## Pelota delante del centro del cuerpo (m) al empezar: ni debajo del cuerpo ni lejos del alcance.
const MIN_AHEAD := 0.12
const MAX_AHEAD := 1.05
const MAX_LATERAL := 0.38
## Delante del centro del cuerpo (m) a la que la suela llega a la pelota: parado SOLE_AHEAD y con la zancada mas larga
## hasta SOLE_AHEAD_MAX (SOLE_AHEAD_PER_MS por m/s); mas lejos la pierna no llega estirada a lo alto de la pelota.
const SOLE_AHEAD := 0.36
const SOLE_AHEAD_PER_MS := 0.03
const SOLE_AHEAD_MAX := 0.5
## Segundos maximos para llegar con la suela (el cuerpo sigue a su velocidad, derecho a la pelota); si la pelota se
## escapa antes, no hay vuelta.
const REACH_MAX := 0.3
## Frenada del cuerpo plantado (m/s2, por el factor de aceleracion) y tiempo (s) minimo y maximo pisando antes de tirar.
const PLANT_BRAKE := 20.0
const HOLD_MIN := 0.06
const HOLD_MAX := 0.26
## Velocidad (m/s) del cuerpo por debajo de la cual la suela ya puede tirar de la pelota.
const PULL_BODY_SPEED := 0.9
## La pelota arrastrada queda PULL_LEAD m por delante del cuerpo (en el rumbo nuevo) a los PULL_TIME s, con el cuerpo
## saliendo tras el pivote; y PULL_SIDE m hacia el lado del pie que arrastra (pasa junto al pie de apoyo).
const PULL_TIME := 0.6
const PULL_LEAD := 0.55
const PULL_SIDE := 0.1
## Segundos que la suela acompana a la pelota tras el tiron, y de suelta del IK.
const PULL_FOLLOW := 0.08
const IK_RELEASE := 0.16
## Ritmo del pivote (grados/s, por la agilidad) y velocidad con la que sale (m/s) cuando ya mira al rumbo nuevo.
const TURN_RATE := 780.0
const EXIT_SPEED := 1.6
const EXIT_ANGLE := 22.0
## Duracion maxima de toda la accion (s) y espera antes de poder repetirla.
const MAX_TIME := 1.2
const COOLDOWN := 0.5
## Metros mas alla de la distancia de la suela a los que la pelota ya no esta pisada (otro la toco, rebote).
const LOST_MARGIN := 0.12

## m/s que el cuerpo va mas rapido que la pelota para alcanzarla mientras llega (hasta 0.8 m/s mas que al empezar, sin
## pasar la velocidad de carrera).
const CATCH_REL := 1.2
## La vuelta solo empieza en los primeros REQUEST_WINDOW s de pedirla: despues ya manda la media vuelta por el costado
## (no se mezclan las dos). El boton REGATE la deja pedida REQUEST_HOLD s (para girar el joystick justo despues).
const REQUEST_WINDOW := 0.12
const REQUEST_HOLD := 0.6

enum Phase { NONE, REACH, HOLD, PULL }

var handler: BallHandler
var phase: Phase = Phase.NONE
var t: float = 0.0
var _phase_t: float = 0.0
var _cooldown: float = 0.0
## Pie que pisa (0 izquierdo, 1 derecho), frente al empezar y rumbo nuevo.
var foot: int = 1
var old_dir: Vector3 = Vector3.FORWARD
var new_dir: Vector3 = Vector3.BACK
## Sentido del pivote: +1 = el yaw crece (giro a la izquierda), -1 = a la derecha.
var turn_sign: float = 1.0
var _pulled: bool = false
var _ik_weight: float = 0.0
## Ultimo en tocar la pelota al empezar (si la toca otro, la vuelta se cancela).
var _start_toucher: Node = null
## Velocidad del cuerpo cuando el joystick empezo a pedir la vuelta (-1 = no la pide): una vuelta pedida a sprint no se
## hace aunque el cuerpo ya haya frenado (manda la media vuelta por el costado).
var _req_speed: float = -1.0
var _req_t: float = 0.0
## Segundos que quedan del pedido con el boton REGATE (0 = sin pedir: el joystick atras solo no pisa la pelota).
var _requested: float = 0.0
## Distancia de la suela para esta vuelta (segun la velocidad al empezar).
var _sole: float = SOLE_AHEAD
## Diagnostico: vueltas completas, abortadas, y medidas de la ultima (lo leen las pruebas).
var stats := {"started": 0, "done": 0, "aborted": 0}
var last := {}

func _init(h: BallHandler) -> void:
	handler = h

func active() -> bool:
	return phase != Phase.NONE

## Boton REGATE con el joystick hacia atras: la vuelta pisando la pelota queda pedida REQUEST_HOLD s.
func request() -> void:
	_requested = REQUEST_HOLD
	_req_speed = -1.0

func cancel(reason: String = "") -> void:
	if phase == Phase.NONE:
		return
	if not _pulled:
		stats["aborted"] += 1
		last["aborted"] = reason
	phase = Phase.NONE
	_cooldown = COOLDOWN
	_release_ik()

## Paso de fisica (lo llama BallHandler.update antes de los toques). Devuelve true mientras la vuelta manda (no hay
## otros toques de conduccion).
func update(desired_dir: Vector3, stick_mag: float, dt: float) -> bool:
	_cooldown = maxf(_cooldown - dt, 0.0)
	_requested = maxf(_requested - dt, 0.0)
	var loco0: Locomotion = handler.owner.locomotion
	var reversed: bool = stick_mag >= MIN_STICK and desired_dir.length_squared() > 0.01 \
		and KickModel.angle_between_deg(loco0.forward(), KickModel.flat(desired_dir).normalized()) >= MIN_ANGLE
	if phase == Phase.NONE:
		if not reversed or _requested <= 0.0:
			_req_speed = -1.0
			return false
		if _req_speed < 0.0:
			_req_speed = loco0.speed
			_req_t = 0.0
		_req_t += dt
		if _req_speed > MAX_SPEED or _req_t > REQUEST_WINDOW or not _try_start(desired_dir, stick_mag):
			return false
	var b: Ball = handler.ball()
	var owner: Footballer = handler.owner
	if b == null or b.is_held() or handler.ball_owned_by_other() or (b.last_toucher != owner and b.last_toucher != _start_toucher):
		cancel("pelota perdida")
		return false
	t += dt
	_phase_t += dt
	var loco: Locomotion = owner.locomotion
	var body_v := Vector3(loco.velocity.x, 0.0, loco.velocity.z)
	var off: Vector3 = handler.ball_offset()
	# Hasta pisarla el cuerpo va derecho a la pelota: el frente de referencia sigue la linea a la pelota.
	if phase == Phase.REACH and off.length() > 0.15 and off.dot(old_dir) > 0.0:
		old_dir = off.normalized()
	var ahead: float = off.dot(old_dir)
	match phase:
		Phase.REACH:
			# La vuelta solo sigue si el joystick sigue pidiendola (antes de pisar aun se puede desistir).
			if stick_mag < MIN_STICK * 0.6 or KickModel.angle_between_deg(old_dir, desired_dir) < 100.0:
				cancel("joystick")
				return false
			if ahead <= _sole + 0.03 or ahead < MIN_AHEAD:
				last["contact_ahead"] = ahead
				last["contact_speed"] = body_v.length()
				last["reach_time"] = _phase_t
				last["contact_t"] = t
				phase = Phase.HOLD
				_phase_t = 0.0
			elif _phase_t > REACH_MAX + 0.1 or off.length() > MAX_AHEAD + 0.3:
				cancel("no llego")
				return false
		Phase.HOLD:
			if off.length() > _sole + LOST_MARGIN:
				cancel("se escapo")
				return false
			# La suela frena la pelota con el cuerpo: cada paso la pelota toma la velocidad de la suela (que va con el
			# cuerpo plantado), sin moverla de donde esta. El primer contacto es el toque (con su evento); los siguientes
			# son el mismo apoyo de la suela.
			if _phase_t <= dt + 0.0001:
				b.kick(body_v, Vector3.ZERO, owner)
				handler.touched_ball.emit(&"sole")
				handler.dribble_touch_count += 1
				handler.last_touch_mode = &"sole"
			else:
				b.kick(body_v, Vector3.ZERO, null)
			if _phase_t >= HOLD_MIN and (body_v.length() < PULL_BODY_SPEED or _phase_t >= HOLD_MAX):
				_pull(b, body_v)
		Phase.PULL:
			var facing: float = KickModel.angle_between_deg(loco.forward(), new_dir)
			if (facing < EXIT_ANGLE and _phase_t > 0.18) or t > MAX_TIME:
				stats["done"] += 1
				last["turn_time"] = t
				phase = Phase.NONE
				_cooldown = COOLDOWN
				handler.touch_timer = 0.0
				_release_ik()
				return false
	_update_ik(b)
	return true

## Mando del cuerpo mientras dura la vuelta (Footballer lo aplica en lugar de la marcha normal):
## {face, rate, sign, vel, accel}. Vacio si no hay vuelta.
func body_control() -> Dictionary:
	if phase == Phase.NONE:
		return {}
	var loco: Locomotion = handler.owner.locomotion
	var accel_f: float = handler.owner.attributes.factor("acceleration", 0.16)
	var agility_f: float = handler.owner.attributes.factor("agility", 0.14)
	var body_v := Vector3(loco.velocity.x, 0.0, loco.velocity.z)
	match phase:
		Phase.REACH:
			# Llega a la pelota sin girar todavia, derecho a ella y algo mas rapido que ella si hace falta para pisarla ya.
			var b2: Ball = handler.ball()
			var vb2: float = KickModel.flat(b2.linear_velocity).dot(old_dir) if b2 != null else 0.0
			var want2: float = clampf(vb2 + CATCH_REL, loco.speed, minf(loco.speed + 0.8, maxf(loco.speed, loco.max_run_speed())))
			return {"face": old_dir, "rate": 360.0, "sign": 0.0, "vel": old_dir * want2, "accel": Tuning.player.accel * accel_f}
		Phase.HOLD:
			return {"face": old_dir, "rate": 0.0, "sign": 0.0, "vel": Vector3.ZERO, "accel": PLANT_BRAKE * accel_f}
		_:
			var facing: float = KickModel.angle_between_deg(loco.forward(), new_dir)
			var out: Vector3 = new_dir * EXIT_SPEED if facing < 60.0 else Vector3.ZERO
			return {"face": new_dir, "rate": TURN_RATE * agility_f, "sign": turn_sign, "vel": out, "accel": (Tuning.player.accel if facing < 60.0 else PLANT_BRAKE) * accel_f}

func _try_start(desired_dir: Vector3, stick_mag: float) -> bool:
	if _cooldown > 0.0 or stick_mag < MIN_STICK or desired_dir.length_squared() < 0.01:
		return false
	if handler._kick_action != &"" or handler._pending_action != &"" or handler.is_kick_in_progress():
		return false
	var owner: Footballer = handler.owner
	var loco: Locomotion = owner.locomotion
	if loco.speed > MAX_SPEED or not handler.has_possession():
		return false
	var fwd: Vector3 = loco.forward()
	var dir: Vector3 = KickModel.flat(desired_dir).normalized()
	var ang: float = KickModel.angle_between_deg(fwd, dir)
	if ang < MIN_ANGLE:
		return false
	var b: Ball = handler.ball()
	if b == null or b.is_held() or b.global_position.y > 0.3:
		return false
	# Pedida con el boton, la pisada manda sobre un giro con toques que aun no toco la pelota; despues ya no se mezclan.
	if handler.ball_turn.active() and handler.ball_turn.touches > 0:
		return false
	var off: Vector3 = handler.ball_offset()
	var ahead: float = off.dot(fwd)
	var side: float = off.dot(loco.right())
	if ahead < MIN_AHEAD or ahead > MAX_AHEAD or absf(side) > MAX_LATERAL:
		return false
	# Frente de referencia: hacia donde corre el cuerpo (el primer paso del giro ya pudo rotarlo unos grados).
	if loco.speed > 0.8:
		fwd = KickModel.flat(loco.velocity).normalized()
	# La suela tiene que llegar a la pelota en REACH_MAX (cuerpo derecho a ella, algo mas rapido si hace falta; pelota
	# rodando). Si se escapa (el ultimo toque la lanzo) no hay vuelta: manda la media vuelta por el costado, que no espera
	# (a la carrera, ir tras la pelota recien lanzada para pisarla costaba ~0.9 s y ~4 m de mas).
	_sole = clampf(SOLE_AHEAD + SOLE_AHEAD_PER_MS * loco.speed, SOLE_AHEAD, SOLE_AHEAD_MAX)
	if not reachable(ahead, KickModel.flat(b.linear_velocity).dot(fwd), loco.velocity.dot(fwd), loco.max_run_speed(), _sole, REACH_MAX):
		return false
	# Lado del giro: hacia donde apunta el joystick (el camino corto); de frente hacia atras, hacia el lado del pie que
	# esta junto a la pelota (o el bueno). Pisa el pie de ese lado: girando a la derecha arrastra la derecha.
	var cross_y: float = fwd.cross(dir).y
	if absf(cross_y) > sin(deg_to_rad(10.0)):
		turn_sign = signf(cross_y)
	elif absf(side) > 0.04:
		turn_sign = -signf(side)
	else:
		turn_sign = -1.0 if owner.dominant_right else 1.0
	foot = 1 if turn_sign < 0.0 else 0
	old_dir = fwd
	new_dir = dir
	handler.ball_turn.cancel("regate")
	phase = Phase.REACH
	t = 0.0
	_phase_t = 0.0
	_pulled = false
	_ik_weight = 0.0
	_start_toucher = b.last_toucher
	stats["started"] += 1
	last = {"start_speed": loco.speed, "start_ahead": ahead, "foot": foot}
	_requested = 0.0
	return true

## Simula la llegada paso a paso (el cuerpo acelera como en REACH, hasta 0.8 m/s mas sin pasar run_max): true si la
## pelota queda a `sole` m del cuerpo antes de `horizon` s.
static func reachable(ahead: float, ball_v: float, body_v: float, run_max: float, sole: float, horizon: float) -> bool:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var x: float = ahead
	var vb: float = ball_v
	var vp: float = body_v
	var cap: float = minf(body_v + 0.8, maxf(body_v, run_max))
	var accel: float = Tuning.player.accel
	var steps: int = int(horizon / dt)
	for i in steps:
		if x <= sole + 0.03:
			return true
		vb = Ball._roll_step(vb, dt) if vb > 0.0 else vb
		vp = move_toward(vp, clampf(vb + CATCH_REL, body_v, cap), accel * dt)
		x += (vb - vp) * dt
	return x <= sole + 0.03

func _pull(b: Ball, body_v: Vector3) -> void:
	var owner: Footballer = handler.owner
	var agility_f: float = owner.attributes.factor("agility", 0.14)
	var accel: float = Tuning.player.accel * owner.attributes.factor("acceleration", 0.16)
	# Donde estara el cuerpo a los PULL_TIME s: pivota (180 grados al ritmo del giro) y despues acelera hacia el rumbo nuevo.
	var t_turn: float = 180.0 / (TURN_RATE * agility_f)
	var run: float = maxf(PULL_TIME - t_turn, 0.0)
	var body_ahead: float = 0.5 * minf(accel, EXIT_SPEED / maxf(run, 0.05)) * run * run + body_v.dot(new_dir) * PULL_TIME * 0.5
	var side_v: Vector3 = handler.owner.locomotion.right() * (1.0 if foot == 1 else -1.0)
	var target: Vector3 = KickModel.flat(owner.global_position) + new_dir * (body_ahead + PULL_LEAD) + side_v * PULL_SIDE
	var to_t: Vector3 = target - KickModel.flat(b.global_position)
	var v: Vector3 = to_t.normalized() * Ball.roll_speed_for(to_t.length(), PULL_TIME)
	b.kick(v, b.rolling_spin(v), owner)
	handler.touched_ball.emit(&"drag_back")
	handler.dribble_touch_count += 1
	handler.last_touch_mode = &"drag_back"
	_pulled = true
	phase = Phase.PULL
	_phase_t = 0.0
	last["pull_speed"] = v.length()
	last["hold_time"] = t - float(last.get("contact_t", 0.0))

## Suela sobre la pelota: la punta del pie va a lo alto de la pelota (algo por delante de su centro) con el peso de la
## fase: sube mientras llega, pisa, acompana el tiron y se suelta.
func _update_ik(b: Ball) -> void:
	var v: FootballerVisual = handler.owner.visual
	if v == null or v.touch_ik == null:
		return
	var w: float = 0.0
	match phase:
		Phase.REACH:
			var ahead: float = handler.ball_offset().dot(old_dir)
			var left: float = clampf((ahead - _sole) / maxf(handler.owner.locomotion.speed, 1.0), 0.0, 0.3)
			w = clampf(1.0 - left / 0.3, 0.2, 1.0)
		Phase.HOLD:
			w = 1.0
		Phase.PULL:
			w = 1.0 if _phase_t < PULL_FOLLOW else clampf(1.0 - (_phase_t - PULL_FOLLOW) / IK_RELEASE, 0.0, 1.0)
	_ik_weight = maxf(w, _ik_weight * 0.6) if phase == Phase.REACH else w
	var top: Vector3 = b.global_position + Vector3.UP * (b.radius + 0.035) + old_dir * 0.03
	v.touch_ik.set_target(foot, top, -0.12, _ik_weight)

func _release_ik() -> void:
	var v: FootballerVisual = handler.owner.visual if handler.owner != null else null
	if v != null and v.touch_ik != null:
		v.touch_ik.set_target(foot, Vector3.ZERO, 0.0, 0.0)
	_ik_weight = 0.0
