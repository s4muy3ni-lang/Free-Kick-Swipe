class_name BallTurn
extends RefCounted
## Giro con la pelota dando toques (el giro hacia atras de Dream League Soccer / First Touch Soccer). Conduciendo, con el
## joystick hacia atras (o muy cruzado), el jugador no pivota en seco ni pisa la pelota: frena, se encorva sobre ella y
## la rodea dando toques cortos con el interior del pie de fuera del giro, cada uno llevandola un poco mas hacia el rumbo
## nuevo, hasta mirar hacia alli; el ultimo toque la empuja hacia el rumbo nuevo y sigue la conduccion normal.
##  1. llega: el pie sale hacia la pelota (FIRST_TOUCH_DELAY) y, si quedo algo adelantada, el cuerpo va derecho a ella;
##  2. gira: el cuerpo frena hasta la velocidad de giro y rota hacia el rumbo nuevo (mas despacio cuanto mas rapido va:
##     aceleracion lateral acotada); cada toque manda la pelota adonde estara el pie en el toque siguiente (el cuerpo se
##     predice con el mismo modelo que lo mueve), con el modelo de rodadura de la pelota;
##  3. sale: mirando al rumbo nuevo, un toque de salida la adelanta y el cuerpo acelera tras ella.
## La pelota solo cambia de velocidad con Ball.kick en cada toque (no se fija su posicion). Lo usan la persona y la IA
## (lo dispara el rumbo pedido). La vuelta pisando la pelota (DragBack) queda como regate: boton REGATE + atras.

## Angulo (grados) minimo entre el frente del cuerpo y el joystick para girar con toques.
const MIN_ANGLE := 115.0
const MIN_STICK := 0.35
## Velocidad (m/s) maxima del cuerpo al pedirlo (a sprint tambien; la frenada es mas larga).
const MAX_SPEED := 7.2
## Pelota respecto del cuerpo al empezar (m): delante hasta MAX_AHEAD y de costado hasta MAX_LATERAL.
const MIN_AHEAD := -0.05
const MAX_AHEAD := 1.4
const MAX_LATERAL := 0.6
## Distancia (m, delante del centro del cuerpo) a la que el pie alcanza la pelota para el primer toque: parado REACH_AHEAD
## y con la zancada mas larga REACH_AHEAD_PER_MS por m/s, hasta REACH_AHEAD_MAX. Segundos maximos para llegar.
const REACH_AHEAD := 0.5
const REACH_AHEAD_PER_MS := 0.08
const REACH_AHEAD_MAX := 0.95
const REACH_MAX := 0.4
## Segundos minimos antes del primer toque: el pie sale hacia la pelota (IK) y el cuerpo empieza a frenar.
const FIRST_TOUCH_DELAY := 0.1
## Velocidad (m/s) del cuerpo mientras rodea la pelota y frenada (m/s2) hasta ella (por el factor de aceleracion).
const TURN_SPEED := 1.35
const BRAKE := 16.0
## Ritmo maximo del giro (grados/s, por la agilidad) y aceleracion lateral maxima (m/s2): yendo rapido el cuerpo gira
## a LATERAL_ACCEL / velocidad (primero frena, despues rodea).
const TURN_RATE := 210.0
const LATERAL_ACCEL := 10.0
## Segundos entre toques del giro (y maximo esperando a que la pelota quede al alcance).
const TOUCH_INTERVAL := 0.28
const TOUCH_INTERVAL_MAX := 0.45
## La pelota de cada toque queda TOUCH_LEAD m por delante del cuerpo previsto en el toque siguiente.
const TOUCH_LEAD := 0.42
## Velocidad maxima (m/s) de un toque del giro.
const TOUCH_SPEED_MAX := 4.0
## Alcance del pie (m, desde el centro del cuerpo) para un toque del giro.
const TOUCH_REACH := 0.8
## Mirando a menos de EXIT_ANGLE grados del rumbo nuevo, toque de salida: la pelota queda EXIT_LEAD m delante del cuerpo a
## los EXIT_TIME s, con el cuerpo acelerando hacia la velocidad pedida.
const EXIT_ANGLE := 28.0
const EXIT_TIME := 0.42
const EXIT_LEAD := 0.62
## Duracion maxima (s), espera antes de repetir y distancia (m) a la que la pelota ya no esta al pie (se suelta el giro).
const MAX_TIME := 1.8
const COOLDOWN := 0.35
const LOST_DIST := 1.25
## m/s que el cuerpo va mas rapido que la pelota mientras llega a ella.
const CATCH_REL := 1.2
## El giro solo empieza en los primeros REQUEST_WINDOW s de pedirlo.
const REQUEST_WINDOW := 0.15
## Encorvado extra del tronco (rad) mientras rodea la pelota, y tiempos (s) de subida y bajada del pie que toca (IK).
const CROUCH := 0.1
const IK_RISE := 0.12
const IK_FALL := 0.12

enum Phase { NONE, REACH, TURN }

var handler: BallHandler
var phase: Phase = Phase.NONE
var t: float = 0.0
var _phase_t: float = 0.0
var _cooldown: float = 0.0
## Frente al empezar, rumbo nuevo y sentido del giro (+1 = el yaw crece, a la izquierda; -1 = a la derecha).
var old_dir: Vector3 = Vector3.FORWARD
var new_dir: Vector3 = Vector3.BACK
var turn_sign: float = 1.0
## Pie que toca (0 izquierdo, 1 derecho): el de fuera del giro, con el interior.
var foot: int = 1
## Toques dados y segundos desde el ultimo.
var touches: int = 0
var _since_touch: float = 0.0
var _last_push: Vector3 = Vector3.ZERO
var _reach: float = REACH_AHEAD
var _start_toucher: Node = null
var _req_t: float = -1.0
## Velocidad pedida a la salida (m/s, la del joystick).
var _exit_speed: float = 3.0
var _ik_weight: float = 0.0
## Diagnostico: giros empezados, completos, abortados y medidas del ultimo (lo leen las pruebas).
var stats := {"started": 0, "done": 0, "aborted": 0}
var last := {}

func _init(h: BallHandler) -> void:
	handler = h

func active() -> bool:
	return phase != Phase.NONE

func cancel(reason: String = "") -> void:
	if phase == Phase.NONE:
		return
	stats["aborted"] += 1
	last["aborted"] = reason
	_end()

## release: suelta el pie ya; sin soltarlo (toque de salida) el IK sigue unos fotogramas en el contacto y se desvanece solo.
func _end(release: bool = true) -> void:
	phase = Phase.NONE
	_cooldown = COOLDOWN
	if release:
		_release_ik()
	var v: FootballerVisual = handler.owner.visual if handler.owner != null else null
	if v != null:
		v.turn_crouch = 0.0

## Paso de fisica (lo llama BallHandler.update antes de los toques de conduccion). true mientras el giro manda.
func update(desired_dir: Vector3, stick_mag: float, dt: float) -> bool:
	_cooldown = maxf(_cooldown - dt, 0.0)
	var owner: Footballer = handler.owner
	var loco: Locomotion = owner.locomotion
	if phase == Phase.NONE:
		var back: bool = stick_mag >= MIN_STICK and desired_dir.length_squared() > 0.01 \
			and KickModel.angle_between_deg(loco.forward(), KickModel.flat(desired_dir).normalized()) >= MIN_ANGLE
		if not back:
			_req_t = -1.0
			return false
		_req_t = 0.0 if _req_t < 0.0 else _req_t + dt
		if _req_t > REQUEST_WINDOW or not _try_start(desired_dir, stick_mag):
			return false
	var b: Ball = handler.ball()
	if b == null or b.is_held() or b.global_position.y > 0.6 or handler.ball_owned_by_other() \
			or (b.last_toucher != owner and b.last_toucher != _start_toucher):
		cancel("pelota perdida")
		return false
	t += dt
	_phase_t += dt
	_since_touch += dt
	# El joystick manda el rumbo: se puede corregir durante el giro (hacia el mismo lado) o soltar (sale despacio).
	if stick_mag >= MIN_STICK * 0.6 and desired_dir.length_squared() > 0.01:
		var d: Vector3 = KickModel.flat(desired_dir).normalized()
		if KickModel.angle_between_deg(d, new_dir) < 70.0:
			new_dir = d
		_exit_speed = loco.speed_for_magnitude(stick_mag)
	var off: Vector3 = handler.ball_offset()
	match phase:
		Phase.REACH:
			if off.length() > 0.15 and off.dot(old_dir) > 0.0:
				old_dir = off.normalized()
			var ahead: float = off.dot(old_dir)
			if ahead <= _reach and _phase_t >= FIRST_TOUCH_DELAY:
				last["reach_time"] = _phase_t
				last["contact_speed"] = loco.speed
				phase = Phase.TURN
				_phase_t = 0.0
				_touch(b)
			elif _phase_t > REACH_MAX + 0.1 or off.length() > MAX_AHEAD + 0.4:
				cancel("no llego")
				return false
		Phase.TURN:
			if off.length() > LOST_DIST:
				cancel("se escapo")
				return false
			var facing: float = KickModel.angle_between_deg(loco.forward(), new_dir)
			var reach_ok: bool = off.length() <= TOUCH_REACH and off.dot(loco.forward()) > -0.05
			if facing < EXIT_ANGLE and reach_ok and _since_touch >= TOUCH_INTERVAL * 0.6:
				_exit_touch(b)
				return false
			if reach_ok and (_since_touch >= TOUCH_INTERVAL or (_since_touch >= TOUCH_INTERVAL_MAX and off.length() <= TOUCH_REACH + 0.15)):
				_touch(b)
			if t > MAX_TIME:
				cancel("tiempo")
				return false
	_update_ik(b, dt)
	return true

## Mando del cuerpo (Footballer lo aplica con Locomotion.step_scripted): {face, rate, sign, vel, accel}. Vacio sin giro.
func body_control() -> Dictionary:
	if phase == Phase.NONE:
		return {}
	var owner: Footballer = handler.owner
	var loco: Locomotion = owner.locomotion
	var accel_f: float = owner.attributes.factor("acceleration", 0.16)
	if phase == Phase.REACH:
		var b: Ball = handler.ball()
		var vb: float = KickModel.flat(b.linear_velocity).dot(old_dir) if b != null else 0.0
		# Con la pelota ya al alcance el cuerpo empieza a frenar a su ritmo; si quedo adelantada, va a buscarla.
		if handler.ball_offset().dot(old_dir) <= _reach + 0.05:
			return {"face": old_dir, "rate": 360.0, "sign": 0.0, "vel": old_dir * clampf(vb, TURN_SPEED, loco.speed), "accel": BRAKE * accel_f}
		var want: float = clampf(vb + CATCH_REL, loco.speed, minf(loco.speed + 0.8, maxf(loco.speed, loco.max_sprint_speed())))
		return {"face": old_dir, "rate": 360.0, "sign": 0.0, "vel": old_dir * want, "accel": Tuning.player.accel * accel_f}
	var c: Vector3 = turn_control(loco.speed, owner.attributes.factor("agility", 0.14))
	var b: Ball = handler.ball()
	var target: Vector3 = _avoid_ball(loco.forward() * c.y, owner.global_position, b.global_position, b.linear_velocity, c.z * accel_f)
	return {"face": new_dir, "rate": c.x, "sign": turn_sign, "vel": target, "accel": c.z * accel_f}

## El cuerpo rodea la pelota en vez de cruzar su centro. Limita la velocidad radial por la distancia de frenado;
## conserva la componente tangencial. No mueve ni frena artificialmente el balon.
static func _avoid_ball(want: Vector3, body: Vector3, ball_pos: Vector3, ball_velocity: Vector3, brake: float) -> Vector3:
	var gap: Vector3 = KickModel.flat(ball_pos - body)
	var distance: float = gap.length()
	if distance < 0.001:
		return want
	var radial: Vector3 = gap / distance
	var allowed: float = sqrt(2.0 * brake * maxf(distance - 0.38, 0.0))
	var closing: float = (want - KickModel.flat(ball_velocity)).dot(radial)
	return want - radial * maxf(closing - allowed, 0.0)

## Ritmo de giro (grados/s), velocidad objetivo (m/s) y aceleracion (m/s2, sin el factor) del cuerpo girando a `speed`.
static func turn_control(speed: float, agility_f: float) -> Vector3:
	var rate: float = minf(TURN_RATE * agility_f, rad_to_deg(LATERAL_ACCEL / maxf(speed, 0.1)))
	return Vector3(rate, TURN_SPEED, BRAKE)

## Posicion, frente y velocidad del cuerpo dentro de `horizon` s con el mismo mando que body_control (paso de fisica).
func predict_body(horizon: float) -> Dictionary:
	var owner: Footballer = handler.owner
	var loco: Locomotion = owner.locomotion
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var agility_f: float = owner.attributes.factor("agility", 0.14)
	var accel_f: float = owner.attributes.factor("acceleration", 0.16)
	var p: Vector3 = KickModel.flat(owner.global_position)
	var v: Vector3 = KickModel.flat(loco.velocity)
	var yaw: float = loco.yaw
	var goal: float = Locomotion.yaw_from_dir(new_dir)
	var b: Ball = handler.ball()
	var trajectory: PackedVector3Array = BallPredictor.trajectory(b.global_position, b.linear_velocity, horizon + dt, dt, b.angular_velocity)
	for i in int(round(horizon / dt)):
		var c: Vector3 = turn_control(v.length(), agility_f)
		var diff: float = wrapf(goal - yaw, -PI, PI)
		if absf(diff) > 0.35 and signf(diff) != signf(turn_sign):
			diff += signf(turn_sign) * TAU
		var m: float = deg_to_rad(c.x) * dt
		yaw = wrapf(yaw + clampf(diff, -m, m), -PI, PI)
		var bp: Vector3 = trajectory[mini(i, trajectory.size() - 1)]
		var bv: Vector3 = (trajectory[mini(i + 1, trajectory.size() - 1)] - bp) / dt
		var target: Vector3 = _avoid_ball(Locomotion.dir_from_yaw(yaw) * c.y, p, bp, bv, c.z * accel_f)
		v = v.move_toward(target, c.z * accel_f * dt)
		p += v * dt
	return {"pos": p, "fwd": Locomotion.dir_from_yaw(yaw), "vel": v}

func _try_start(desired_dir: Vector3, stick_mag: float) -> bool:
	if _cooldown > 0.0 or handler.drag_back.active():
		return false
	if handler._kick_action != &"" or handler._pending_action != &"" or handler.is_kick_in_progress():
		return false
	var owner: Footballer = handler.owner
	var loco: Locomotion = owner.locomotion
	if loco.speed > MAX_SPEED or not handler.has_possession():
		return false
	var b: Ball = handler.ball()
	if b == null or b.is_held() or b.global_position.y > 0.3 or b.last_toucher != owner:
		return false
	var fwd: Vector3 = loco.forward()
	if loco.speed > 0.8:
		fwd = KickModel.flat(loco.velocity).normalized()
	var dir: Vector3 = KickModel.flat(desired_dir).normalized()
	var off: Vector3 = handler.ball_offset()
	var ahead: float = off.dot(fwd)
	var side: float = off.dot(Vector3(-fwd.z, 0.0, fwd.x))
	if ahead < MIN_AHEAD or ahead > MAX_AHEAD or absf(side) > MAX_LATERAL:
		return false
	_reach = clampf(REACH_AHEAD + REACH_AHEAD_PER_MS * loco.speed, REACH_AHEAD, REACH_AHEAD_MAX)
	if ahead > _reach and not DragBack.reachable(ahead, KickModel.flat(b.linear_velocity).dot(fwd), loco.velocity.dot(fwd), loco.max_run_speed(), _reach, REACH_MAX):
		return false
	# Lado del giro: el camino corto hacia el joystick; de frente hacia atras, hacia el lado donde esta la pelota (o el del
	# pie bueno por fuera: diestro, gira a la izquierda tocando con el interior del derecho).
	var cross_y: float = fwd.cross(dir).y
	if absf(cross_y) > sin(deg_to_rad(12.0)):
		turn_sign = signf(cross_y)
	elif absf(side) > 0.06:
		turn_sign = -signf(side)
	else:
		turn_sign = 1.0 if owner.dominant_right else -1.0
	foot = 1 if turn_sign > 0.0 else 0
	old_dir = fwd
	new_dir = dir
	_exit_speed = loco.speed_for_magnitude(stick_mag)
	phase = Phase.REACH
	t = 0.0
	_phase_t = 0.0
	touches = 0
	_since_touch = 0.0
	_ik_weight = 0.0
	_start_toucher = b.last_toucher
	stats["started"] += 1
	last = {"start_speed": loco.speed, "start_ahead": ahead, "foot": foot, "angle": KickModel.angle_between_deg(fwd, dir)}
	if owner.visual != null:
		owner.visual.turn_crouch = CROUCH
	return true

## Toque del giro: la pelota va adonde estara el pie en el toque siguiente (cuerpo previsto + TOUCH_LEAD por delante).
func _touch(b: Ball) -> void:
	var pred: Dictionary = predict_body(TOUCH_INTERVAL)
	var target: Vector3 = (pred["pos"] as Vector3) + (pred["fwd"] as Vector3) * TOUCH_LEAD
	_kick_to(b, target, TOUCH_INTERVAL, &"turn")
	touches += 1

## Toque de salida: la pelota queda por delante del cuerpo que acelera hacia el rumbo nuevo, y vuelve la conduccion.
func _exit_touch(b: Ball) -> void:
	var owner: Footballer = handler.owner
	var loco: Locomotion = owner.locomotion
	var accel: float = Tuning.player.accel * owner.attributes.factor("acceleration", 0.16)
	var v0: float = maxf(KickModel.flat(loco.velocity).dot(new_dir), 0.0)
	var ve: float = maxf(_exit_speed, v0)
	var t_acc: float = minf((ve - v0) / maxf(accel, 0.1), EXIT_TIME)
	var travel: float = v0 * t_acc + 0.5 * accel * t_acc * t_acc + (v0 + accel * t_acc) * (EXIT_TIME - t_acc)
	var target: Vector3 = KickModel.flat(owner.global_position) + new_dir * (travel + EXIT_LEAD)
	_kick_to(b, target, EXIT_TIME, &"turn_exit")
	touches += 1
	stats["done"] += 1
	last["turn_time"] = t
	last["touches"] = touches
	handler.touch_timer = TOUCH_INTERVAL
	var v: FootballerVisual = owner.visual
	if v != null and v.touch_ik != null:
		v.touch_ik.set_target(foot, _toe_target(b, _last_push), 0.0, 1.0)
	_end(false)

func _kick_to(b: Ball, target: Vector3, time: float, mode: StringName) -> void:
	var owner: Footballer = handler.owner
	var to_t: Vector3 = target - KickModel.flat(b.global_position)
	var speed: float = minf(Ball.roll_speed_for(to_t.length(), time), TOUCH_SPEED_MAX if mode == &"turn" else 7.0)
	var v: Vector3 = to_t.normalized() * speed if to_t.length() > 0.01 else Vector3.ZERO
	b.kick(v, b.rolling_spin(v), owner)
	_last_push = v.normalized() if v.length() > 0.1 else KickModel.flat(owner.locomotion.forward())
	_since_touch = 0.0
	handler.dribble_touch_count += 1
	handler.last_touch_mode = mode
	var gap: float = handler.foot_distance(foot, b.global_position) if handler.feet_live else INF
	handler.last_touch_foot = foot if gap <= BallHandler.FOOT_CONTACT else -1
	handler.last_touch_foot_distance = gap if gap <= BallHandler.FOOT_CONTACT else -1.0
	handler.last_touch_toe_distance = handler._toe_now[foot].distance_to(b.global_position) if gap <= BallHandler.FOOT_CONTACT else -1.0
	if handler.last_touch_foot >= 0:
		handler.foot_touches += 1
	handler.touched_ball.emit(mode)
	var speeds: Array = last.get("touch_speeds", [])
	speeds.append(snappedf(v.length(), 0.01))
	last["touch_speeds"] = speeds

## Pie que toca: sube hacia el lado de atras de la pelota (respecto del empuje) antes de cada toque y baja despues.
func _update_ik(b: Ball, dt: float) -> void:
	var v: FootballerVisual = handler.owner.visual
	if v == null or v.touch_ik == null:
		return
	var w: float
	if phase == Phase.REACH:
		# El pie sale hacia la pelota para el primer toque (con la pelota ya cerca).
		w = clampf(_phase_t / FIRST_TOUCH_DELAY, 0.0, 1.0) if handler.ball_offset().dot(old_dir) <= _reach + 0.25 else 0.3
	else:
		var to_next: float = TOUCH_INTERVAL - _since_touch
		var rise: float = clampf(1.0 - to_next / IK_RISE, 0.0, 1.0)
		var fall: float = clampf(1.0 - _since_touch / IK_FALL, 0.0, 1.0)
		w = maxf(rise, fall)
	_ik_weight = move_toward(_ik_weight, w, dt * 12.0)
	var loco: Locomotion = handler.owner.locomotion
	var push: Vector3 = _last_push if _since_touch < IK_FALL else loco.forward().rotated(Vector3.UP, turn_sign * deg_to_rad(35.0))
	v.touch_ik.set_target(foot, _toe_target(b, push), 0.0, _ik_weight)

## Punta del pie que toca: detras de la pelota respecto del empuje, algo hacia fuera (el interior del pie) y a media altura.
func _toe_target(b: Ball, push: Vector3) -> Vector3:
	var outer: Vector3 = handler.owner.locomotion.right() * (1.0 if foot == 1 else -1.0)
	return b.global_position - push * (b.radius + 0.03) + outer * 0.05 + Vector3.UP * 0.05

func _release_ik() -> void:
	var v: FootballerVisual = handler.owner.visual if handler.owner != null else null
	if v != null and v.touch_ik != null:
		v.touch_ik.set_target(foot, Vector3.ZERO, 0.0, 0.0)
	_ik_weight = 0.0
