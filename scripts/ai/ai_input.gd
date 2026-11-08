class_name AIInput
extends InputSource
## Cerebro de un futbolista controlado por la maquina. Produce el mismo InputFrame que una persona (direccion en el
## mundo, sprint, botones con su temporizacion de carga), asi que usa exactamente la fisica y los limites del jugador.
##
## Formacion 1-2-1 (rombo) de fútbol 5: rol 0 = cierre, 1 = ala izquierda, 2 = ala derecha, 3 = pivote.
## Decide cada DECISION_PERIOD s (no cada fotograma); los botones se ejecutan fotograma a fotograma.

const DECISION_PERIOD := 0.12
## Fraccion del largo de la cancha (0 = su arco, 1 = el arco rival) donde se para cada rol.
const ROLE_DEPTH := [0.2, 0.5, 0.5, 0.78]
const ROLE_LATERAL := [0.0, -5.0, 5.0, 0.0]
const ROLE_SHIFT := [0.3, 0.55, 0.55, 0.5]
## Angulo minimo (grados) que debe formar el arco visto desde la pelota para intentar un disparo.
const MIN_SHOT_APERTURE_DEG := 16.0
## Pendiente del cono de tiro: ancho util = medio arco + SHOT_CONE_SLOPE * distancia a la linea de gol.
const SHOT_CONE_SLOPE := 0.55
## Distancia (m) por delante del rival marcado, hacia el arco propio, a la que se coloca el defensor.
const MARK_GOAL_SIDE := 2.6
## Distancia (m) al arco propio dentro de la cual un rival se marca; mas lejos se mantiene la posicion de zona.
const MARK_RANGE := 15.0
## Un rival a menos de este radio (m) de la pelota en KICK_SAFE_TIME s impide empezar una patada.
const KICK_SAFE_RADIUS := 0.75
const KICK_SAFE_TIME := 0.18
## Segundos casi parado con la pelota (barullo) a partir de los cuales se patea aunque haya un rival encima.
const DESPERATE_SECONDS := 0.9
## Distancia (m) de un rival a partir de la cual el portador busca pase inmediato.
const PASS_PRESSURE_DIST := 3.0
## Segundos conduciendo tras los que se suelta la pelota aunque no haya presion (futbol de toque, no de carreras): el bot
## de UCS golpea entre 0.5 y 2 s despues de tener la pelota (BotMinKickFrames / BotMaxKickFrames, UcsParams).
const CARRY_PATIENCE := UcsParams.BOT_MAX_KICK_S
## Segundos con la pelota muerta tras los que la jugada se considera atascada y todos van a por ella.
const BALL_STALL_SECONDS := 1.5

var role: int = 0
## 0..1: calidad de decision (rango de tiro, rapidez en soltar el pase).
var skill: float = 0.6
var rng := RandomNumberGenerator.new()

var _tick: int = 0
var _next_decision: float = 0.0
var _clock: float = 0.0
var _dir: Vector3 = Vector3.ZERO
var _mag: float = 0.0
var _sprint: bool = false
var _press: bool = false
# Boton en curso: tipo ("pass"/"shot"), segundos que se mantiene y direccion de apuntado.
var _btn: StringName = &""
var _btn_hold: float = 0.0
var _btn_age: float = 0.0
var _btn_dir: Vector3 = Vector3.ZERO
var _btn_lob: bool = false
## Efecto que la IA pide al soltar (gira el joystick como lo haria una persona): -1..1.
var _btn_curl: float = 0.0
var _btn_cooldown: float = 0.0
var _dribble_started: float = 0.0
## Segundos que lleva este jugador con la pelota: cuanto mas tiempo, mas probable que la suelte a un companero.
var _carry_time: float = 0.0
var _skill_next: bool = false
## Segundos seguidos que el portador lleva casi parado (barullo): si se prolonga rompe el bloqueo pateando.
var _slow_hold: float = 0.0

func _init(r: int = 0, s: float = 0.6) -> void:
	role = r
	skill = s
	rng.randomize()

func poll(f: Footballer) -> InputFrame:
	var out := InputFrame.new()
	_tick += 1
	out.tick = _tick
	out.use_world = true
	var ctx: MatchContext = f.ctx
	if ctx == null or ctx.ball == null or not ctx.input_enabled:
		return out
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	_clock += dt
	_btn_cooldown = maxf(_btn_cooldown - dt, 0.0)
	if _btn != &"":
		return _run_button(out, f, dt)
	if _clock >= _next_decision:
		_next_decision = _clock + DECISION_PERIOD * rng.randf_range(0.8, 1.2)
		_decide(f)
		if _btn != &"":
			return _run_button(out, f, dt)
	out.move_world = _around_goal(f, _dir) * _mag
	out.sprint = _sprint
	out.press_held = _press
	out.skill_pressed = _skill_next
	_skill_next = false
	return out

# --- Botones -------------------------------------------------------------------------------------------

## Orienta el cuerpo hacia donde va a patear antes de pulsar: devuelve true si ya esta alineado (<= 28 grados).
func _aligned(f: Footballer, dir: Vector3, max_deg: float = 28.0) -> bool:
	var ang: float = absf(wrapf(Locomotion.yaw_from_dir(dir.normalized()) - f.locomotion.yaw, -PI, PI))
	if ang <= deg_to_rad(max_deg):
		return true
	_dir = dir.normalized()
	_mag = 0.45
	_sprint = false
	return false

func _start_button(kind: StringName, hold: float, dir: Vector3, lob: bool = false, curl: float = 0.0) -> void:
	_btn_curl = curl
	_btn = kind
	_btn_hold = hold
	_btn_age = 0.0
	_btn_dir = dir
	_btn_lob = lob

## true si ningun rival llegara a la pelota durante el balanceo de la patada (~0.25 s): con la pelota suelta entre dos
## jugadores el golpe se pierde. Con rival encima se conduce, se regatea o se protege la pelota en vez de patear.
func _kick_safe(f: Footballer) -> bool:
	var ball: Ball = f.ctx.ball
	var bp := Vector3(ball.global_position.x, 0.0, ball.global_position.z)
	for o in f.ctx.footballers:
		if o.team == f.team:
			continue
		var op := Vector3(o.global_position.x, 0.0, o.global_position.z) + Vector3(o.velocity.x, 0.0, o.velocity.z) * KICK_SAFE_TIME
		if op.distance_to(bp) < KICK_SAFE_RADIUS:
			return false
	return true

## true si, tal como esta la pelota ahora, el golpeo llegaria (con clip: algun pie alcanza; sin clip: alcance de toque).
func _can_kick(f: Footballer, kind: StringName, lob: bool) -> bool:
	var bh: BallHandler = f.ball_handler
	if bh.uses_clip_kicks():
		return not bh.plan_clip_kick(kind, 0.5, lob).is_empty()
	return bh.can_reach(Tuning.player.touch_reach + 0.3)

func _run_button(out: InputFrame, f: Footballer, dt: float) -> InputFrame:
	var first: bool = _btn_age == 0.0
	_btn_age += dt
	var releasing: bool = _btn_age >= _btn_hold
	# Mientras carga frena (la pelota no se aleja); suelta solo cuando el pie llega, con un maximo de espera.
	if releasing and _btn_age < _btn_hold + 0.45 and not _can_kick(f, _btn, _btn_lob):
		releasing = false
	# Un tiro se cancela si, durante la carga, la pelota quedo en un angulo sin arco (se corrio hacia la linea de fondo).
	var closed_angle: bool = false
	if _btn == &"shot" and not f.ball_handler.is_kick_in_progress():
		var gx: float = float(f.ctx.attacking_goal(f.team).position.x)
		var bp: Vector3 = _flat(f.ctx.ball.global_position)
		closed_angle = not _shot_cone_ok(bp, Vector3(gx, 0.0, 0.0), f.ctx.pitch.config.half_goal() + 0.6)
	# Si la pelota se fue (robo, rebote) o no llega a tiempo, se cancela la carga: no se patea al aire.
	if closed_angle or f.ball_handler.ball_distance() > 1.7 or (releasing == false and _btn_age >= _btn_hold + 0.45) or f.ball_handler.is_kick_in_progress():
		if not f.ball_handler.is_kick_in_progress():
			f.ball_handler.cancel_charge()
			_btn = &""
			_btn_cooldown = 0.5
			_next_decision = _clock
			return out
	# Al cargar casi se detiene (la pelota no se escapa hacia adelante ni hacia la linea de fondo antes del golpeo).
	out.move_world = _btn_dir * (0.18 if not releasing else 0.5)
	if releasing and _btn_curl != 0.0:
		# Chanfle: al soltar gira el joystick hacia el lado de la curva (derecha = angulo negativo).
		out.move_world = _btn_dir.rotated(Vector3.UP, deg_to_rad(-_btn_curl * 45.0)) * 0.5
	out.lob_held = _btn_lob
	var pressed: bool = first
	var held: bool = not releasing
	if _btn == &"pass":
		out.pass_pressed = pressed
		out.pass_held = held
		out.pass_released = releasing
	elif _btn == &"through":
		out.through_pressed = pressed
		out.through_held = held
		out.through_released = releasing
	elif _btn == &"cross":
		out.cross_pressed = pressed
		out.cross_held = held
		out.cross_released = releasing
	else:
		out.shoot_pressed = pressed
		out.shoot_held = held
		out.shoot_released = releasing
	if releasing:
		_btn = &""
		_btn_cooldown = 0.9
		_next_decision = _clock + 0.25
	return out

# --- Decision --------------------------------------------------------------------------------------------

func _attack_dir(f: Footballer) -> Vector3:
	return Vector3(1.0 if f.team == 0 else -1.0, 0.0, 0.0)

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func _decide(f: Footballer) -> void:
	var ctx: MatchContext = f.ctx
	var ball: Ball = ctx.ball
	var atk: Vector3 = _attack_dir(f)
	var pos: Vector3 = _flat(f.global_position)
	var bpos: Vector3 = _flat(ball.global_position)
	_press = false
	_sprint = false
	if ctx.dead_ball:
		_decide_dead_ball(f, ctx, atk, pos, bpos)
		return
	if ball.is_held():
		_move_to(f, _anchor(f, false), 0.7)
		return
	var carrier: Footballer = _carrier(ctx)
	# Solo UN jugador lleva la pelota: el poseedor arbitrado (MatchContext.possessor); con la pelota suelta, el mas
	# cercano. Con dos 'portadores' se pisaban y se robaban el golpe.
	ctx.update_possession()
	if ctx.possessor != null:
		carrier = ctx.possessor
	var mine: bool = carrier == f
	var team_has: bool = carrier != null and carrier.team == f.team
	# Jugada muerta: la pelota lleva parada demasiado tiempo. Deja de contar como 'la tiene mi equipo' para que el
	# companero mas cercano vaya a buscarla y la jugada se reanude (si no, todos esperan un pase que no llega).
	if ctx.ball_stall_seconds > BALL_STALL_SECONDS and not mine:
		team_has = false
	if mine:
		if f.team == ctx.human_team:
			# Equipo de la persona: la IA no decide con la pelota (pase o tiro); la protege quieta hasta que el control
			# llega a este jugador (MatchScene lo da en el mismo paso).
			_dir = Vector3.ZERO
			_mag = 0.0
			return
		_decide_with_ball(f, ctx, atk)
		return
	_carry_time = 0.0
	# Pase en camino hacia mi: salgo a buscarlo al punto donde llego antes que la pelota.
	if f.has_incoming_pass():
		var meet: Vector3 = f.pass_meet_point()
		_move_to(f, meet, 1.0)
		_sprint = (meet - pos).length() > 3.0
		return
	# Un companero tiene un pase en camino: la jugada es de mi equipo aunque la pelota viaje suelta.
	if not team_has and ball.last_touch_team == f.team:
		for mate in ctx.teammates_of(f):
			if mate.has_incoming_pass():
				team_has = true
				carrier = mate
				break
	# Pared: tras dar el pase, sigo la jugada corriendo al espacio para recibir la devolucion.
	if f.give_and_go_time > 0.0 and team_has:
		var run_to: Vector3 = ctx.pitch.clamp_to_pitch(pos + f.give_and_go_dir * 6.0, 1.2)
		_move_to(f, run_to, 1.0)
		_sprint = true
		return
	# Organizacion colectiva: el equipo reparte puestos (apoyo, amplitud, profundidad, seguridad / presion, cobertura,
	# bloque) para que nunca vayan dos al mismo sitio ni todos a la pelota. Sin orden, la logica individual de abajo.
	if use_team_brain:
		var order: Dictionary = TeamBrain.for_team(ctx, f.team).order_for(f)
		if not order.is_empty() and _follow_order(f, ctx, order, carrier, team_has, atk, pos, bpos):
			return
	var chaser: Footballer = _chaser(f, ctx)
	if chaser == f and not team_has:
		# A por la pelota: la presion calcula el punto de intercepcion y el robo.
		var to_ball: Vector3 = bpos - pos
		_dir = to_ball.normalized() if to_ball.length() > 0.2 else Vector3.ZERO
		_mag = 1.0
		_sprint = to_ball.length() > 4.5
		_press = to_ball.length() < 14.0
		return
	if team_has:
		# Llegada al area: con el companero en zona de centro, cada uno ataca un punto (primer palo, segundo palo,
		# punto de penal); el cierre se queda en la frontal.
		var box: Vector3 = _box_run_spot(f, ctx, carrier, atk)
		if box.length_squared() > 0.01:
			_move_to(f, box, 1.0)
			_sprint = (box - pos).length() > 3.0
			return
		# Desmarque de ruptura: de vez en cuando un ala o el pivote ataca la espalda de la defensa (pase filtrado).
		_run_left = maxf(_run_left - DECISION_PERIOD, 0.0)
		_run_cd = maxf(_run_cd - DECISION_PERIOD, 0.0)
		if _run_left <= 0.0 and _run_cd <= 0.0 and role >= 1 and rng.randf() < 0.06 * (0.5 + skill):
			var behind: Vector3 = _run_behind_spot(f, ctx, carrier, atk)
			if behind.length_squared() > 0.01:
				_run_target = behind
				_run_left = 1.8
				_run_cd = 5.0
		if _run_left > 0.0:
			_move_to(f, _run_target, 1.0)
			_sprint = true
			return
		# Apoyo: ofrecerse en una linea de pase limpia, por delante o al costado del companero con pelota.
		var spot: Vector3 = _support_spot(f, carrier, atk)
		_move_to(f, spot, 0.85)
		_sprint = (spot - pos).length() > 6.0
		return
	_run_left = 0.0
	# Defensa sin ser el primer presionador: marcar al rival peligroso por el lado del propio arco; si no hay a quien
	# marcar, cerrar la linea de pase mas peligrosa del portador; el cierre cubre la espalda del que presiona.
	var mark: Vector3 = _mark_spot(f, ctx, atk)
	var target: Vector3 = mark if mark.length_squared() > 0.01 else _anchor(f, false)
	if carrier != null and carrier.team != f.team:
		var cover: Vector3 = _cover_spot(f, ctx, carrier, chaser, atk)
		if cover.length_squared() > 0.01:
			target = cover
		elif mark.length_squared() < 0.01:
			var lane: Vector3 = _lane_cut_spot(f, ctx, carrier, atk)
			if lane.length_squared() > 0.01:
				target = lane
	_move_to(f, target, 0.85)
	_sprint = (target - pos).length() > 7.0

# --- Movimientos sin pelota (ataque y defensa) ----------------------------------------------------------------

## Usa TeamBrain para los movimientos sin pelota (false: cada jugador decide por su cuenta, como antes).
static var use_team_brain: bool = true

## Ejecuta la orden del equipo. Devuelve false si la orden no aplica y debe decidir la logica individual.
func _follow_order(f: Footballer, ctx: MatchContext, order: Dictionary, carrier: Footballer, team_has: bool, atk: Vector3, pos: Vector3, bpos: Vector3) -> bool:
	var role: StringName = order["role"]
	var target: Vector3 = order["target"]
	match role:
		&"press", &"chase":
			# A por la pelota / al portador: la presion calcula el punto de intercepcion, la contencion y el robo. (El 95 % de
			# PressureSpeedRate de UCS como velocidad de carrera cambiaba los tiros con un defensor encima, test_shot_keeper;
			# su significado es inferido y no se aplica a la velocidad.)
			var to_ball: Vector3 = bpos - pos
			_dir = to_ball.normalized() if to_ball.length() > 0.2 else Vector3.ZERO
			_mag = 1.0
			_sprint = bool(order["sprint"])
			_press = to_ball.length() < 14.0
			return true
		&"support", &"width", &"depth", &"safety":
			if not team_has:
				return false
			# Llegada al area y desmarques de ruptura (individuales) siguen mandando sobre el puesto.
			var box: Vector3 = _box_run_spot(f, ctx, carrier, atk)
			if box.length_squared() > 0.01:
				return false
			_run_left = maxf(_run_left - DECISION_PERIOD, 0.0)
			_run_cd = maxf(_run_cd - DECISION_PERIOD, 0.0)
			if _run_left <= 0.0 and _run_cd <= 0.0 and (role == &"depth" or role == &"width") and rng.randf() < 0.08 * (0.5 + skill):
				var behind: Vector3 = _run_behind_spot(f, ctx, carrier, atk)
				if behind.length_squared() > 0.01:
					_run_target = behind
					_run_left = 1.8
					_run_cd = 5.0
			if _run_left > 0.0:
				_move_to(f, _run_target, 1.0)
				_sprint = true
				return true
			_move_to(f, target, 1.0)
			_sprint = bool(order["sprint"])
			_make_way(f, carrier)
			return true
		&"press2":
			# Segundo en presionar (UCS: hasta dos presionan, uno solo entra): cierra el camino al arco junto al portador,
			# sin entrar.
			_run_left = 0.0
			_move_to(f, target, 1.0)
			_sprint = bool(order["sprint"])
			return true
		&"cover", &"block", &"hold":
			_run_left = 0.0
			_move_to(f, target, 1.0)
			_sprint = bool(order["sprint"])
			return true
	return false

var _run_left: float = 0.0
var _run_cd: float = 2.0
var _run_target: Vector3 = Vector3.ZERO

## true si el portador esta en zona de centro: cerca de la banda y en el ultimo tercio.
func _crossing_zone(ctx: MatchContext, p: Vector3, atk: Vector3) -> bool:
	var cfg: PitchConfig = ctx.pitch.config
	var gx: float = cfg.half_length() * atk.x
	return absf(p.z) > cfg.half_width() - 4.5 and (gx - p.x) * atk.x < 11.0 and (gx - p.x) * atk.x > 0.5

func _box_run_spot(f: Footballer, ctx: MatchContext, carrier: Footballer, atk: Vector3) -> Vector3:
	if carrier == null or carrier == f:
		return Vector3.ZERO
	var cp: Vector3 = _flat(carrier.global_position)
	if not _crossing_zone(ctx, cp, atk):
		return Vector3.ZERO
	var side: float = signf(cp.z)
	match role:
		3:
			return CrossAssist.zone_point(ctx, f.team, &"near_post", side)
		1, 2:
			# El ala del lado contrario va al segundo palo; la del mismo lado, al punto de penal.
			var far: bool = (role == 1 and side > 0.0) or (role == 2 and side < 0.0)
			return CrossAssist.zone_point(ctx, f.team, &"far_post" if far else &"penalty_spot", side)
		_:
			var cfg: PitchConfig = ctx.pitch.config
			return Vector3(cfg.half_length() * atk.x - atk.x * (cfg.penalty_area_radius + 2.5), 0.0, -side * 1.5)

## Punto a la espalda del ultimo defensor rival, en el carril de este jugador.
func _run_behind_spot(f: Footballer, ctx: MatchContext, carrier: Footballer, atk: Vector3) -> Vector3:
	var last_x: float = -INF
	for o in ctx.footballers:
		if o.team != f.team:
			last_x = maxf(last_x, o.global_position.x * atk.x)
	if last_x == -INF:
		return Vector3.ZERO
	var cfg: PitchConfig = ctx.pitch.config
	var x: float = minf(last_x + 3.0, cfg.half_length() - 2.5) * atk.x
	var lane_z: float = clampf(f.global_position.z * 0.6, -cfg.half_width() + 2.0, cfg.half_width() - 2.0)
	var spot := Vector3(x, 0.0, lane_z)
	# Solo si el portador puede jugarla (no esta ya en el area) y la carrera es hacia delante.
	if (spot - _flat(f.global_position)).dot(atk) < 2.0 or (carrier != null and absf(carrier.global_position.x - spot.x) < 2.0):
		return Vector3.ZERO
	return spot

## Cobertura: el cierre se coloca detras del companero que presiona al portador, entre ambos y el propio arco.
func _cover_spot(f: Footballer, ctx: MatchContext, carrier: Footballer, chaser: Footballer, atk: Vector3) -> Vector3:
	if role != 0 or chaser == null or chaser == f:
		return Vector3.ZERO
	var own_goal := Vector3(-atk.x * ctx.pitch.config.half_length(), 0.0, 0.0)
	var cp: Vector3 = _flat(carrier.global_position)
	if cp.distance_to(own_goal) > 22.0:
		return Vector3.ZERO
	var to_goal: Vector3 = (own_goal - cp).normalized()
	return ctx.pitch.clamp_to_pitch(_flat(chaser.global_position) + to_goal * 3.5, 1.0)

## Cerrar la linea de pase: en el segmento entre el portador y su receptor mas peligroso (el rival mas cercano a nuestro
## arco), al 45 %, si este defensor es el que mejor llega a ese punto.
func _lane_cut_spot(f: Footballer, ctx: MatchContext, carrier: Footballer, atk: Vector3) -> Vector3:
	var own_goal := Vector3(-atk.x * ctx.pitch.config.half_length(), 0.0, 0.0)
	var danger: Footballer = null
	var best: float = INF
	for o in ctx.footballers:
		if o.team == f.team or o == carrier:
			continue
		var d: float = _flat(o.global_position).distance_to(own_goal)
		if d < best:
			best = d
			danger = o
	if danger == null:
		return Vector3.ZERO
	var spot: Vector3 = _flat(carrier.global_position).lerp(_flat(danger.global_position), 0.45)
	for mate in ctx.footballers:
		if mate.team == f.team and mate != f and _flat(mate.global_position).distance_to(spot) < _flat(f.global_position).distance_to(spot) - 1.0:
			return Vector3.ZERO
	return spot

## Balon parado: el equipo que saca se ofrece para recibir; el rival marca y respeta la distancia a la pelota.
func _decide_dead_ball(f: Footballer, ctx: MatchContext, atk: Vector3, pos: Vector3, bpos: Vector3) -> void:
	var taker: Node = ctx.restart_taker
	var taker_team: int = int(taker.get("team")) if taker != null else -1
	var target: Vector3
	if taker_team == f.team:
		target = _support_spot(f, taker as Footballer, atk) if taker is Footballer else _anchor(f, true)
		# Nadie salvo el ejecutor dentro de la carrerilla: el apoyo corto se ofrece desde fuera de SetPiece.CLEAR_RADIUS
		# (antes el companero se acercaba a 1.9 m de la pelota y se metia en la carrera del ejecutor).
		var off: Vector3 = target - bpos
		var mine: Vector3 = pos - bpos
		if mine.length() < SetPiece.CLEAR_RADIUS + 1.0:
			# Ya esta cerca: sale en linea recta alejandose de la pelota (ir a un apoyo del otro lado cruzaria la carrerilla).
			target = bpos + (mine.normalized() if mine.length() > 0.1 else -atk) * (SetPiece.CLEAR_RADIUS + 1.0)
		elif off.length() < SetPiece.CLEAR_RADIUS + 0.3:
			target = bpos + (off.normalized() if off.length() > 0.1 else mine.normalized()) * (SetPiece.CLEAR_RADIUS + 0.3)
	else:
		var mark: Vector3 = _mark_spot(f, ctx, atk)
		target = mark if mark.length_squared() > 0.01 else _anchor(f, false)
		var away: Vector3 = target - bpos
		if away.length() < 5.2:
			target = bpos + (away.normalized() if away.length() > 0.1 else -atk) * 5.2
		var mine_r: Vector3 = pos - bpos
		if mine_r.length() < 5.0:
			# Dentro de la distancia: sale en linea recta alejandose de la pelota.
			target = bpos + (mine_r.normalized() if mine_r.length() > 0.1 else -atk) * 5.4
	# Con la pelota muerta nadie cruza la zona de la pelota para llegar a su sitio: la rodea (antes un rival atravesaba
	# la carrerilla a 2.7 m de la pelota camino de su marca).
	var keep: float = (SetPiece.CLEAR_RADIUS + 0.3) if taker_team == f.team else 5.2
	target = _around_ball(pos, target, bpos, keep)
	target = ctx.pitch.clamp_to_pitch(target, 0.6)
	_move_to(f, target, 0.7)

## Si el camino recto de pos a target pasa a menos de `radius` de la pelota, devuelve un punto intermedio sobre el
## circulo de ese radio, avanzando alrededor de la pelota hacia el lado del objetivo (como mucho ~50 grados por decision).
func _around_ball(pos: Vector3, target: Vector3, bpos: Vector3, radius: float) -> Vector3:
	var c: Vector3 = Geometry3D.get_closest_point_to_segment(bpos, pos, target)
	if KickModel.flat(c - bpos).length() >= radius - 0.05:
		return target
	var a0: float = atan2(pos.z - bpos.z, pos.x - bpos.x)
	var a1: float = atan2(target.z - bpos.z, target.x - bpos.x)
	var a: float = a0 + clampf(wrapf(a1 - a0, -PI, PI), -0.9, 0.9)
	return bpos + Vector3(cos(a), 0.0, sin(a)) * (radius + 0.2)

func _decide_with_ball(f: Footballer, ctx: MatchContext, atk: Vector3) -> void:
	var pos: Vector3 = _flat(f.global_position)
	var goal := Vector3(float(ctx.attacking_goal(f.team).position.x), 0.0, 0.0)
	var to_goal: Vector3 = goal - pos
	var dist_goal: float = to_goal.length()
	var opp_near: float = _nearest_opponent_dist(f, ctx, pos, atk)
	var keeper: Node = ctx.keeper_defending(1 - f.team)
	var kz: float = (keeper as Node3D).global_position.z if keeper != null else 0.0
	_slow_hold = _slow_hold + DECISION_PERIOD if f.locomotion.speed < 0.8 else 0.0
	var desperate: bool = _slow_hold > DESPERATE_SECONDS
	var shoot_range: float = lerpf(10.0, 15.0, skill)
	var lane_clear: bool = _lane_clear(f, ctx, pos, goal, 0.9)
	# Solo se dispara desde un angulo util: el cono de tiro se abre con la distancia al arco, asi que desde la linea
	# de fondo o un costado muy cerrado no se dispara, pero un tiro lejano y centrado si es legitimo.
	var good_angle: bool = _shot_cone_ok(pos, goal, ctx.pitch.config.half_goal())
	if _btn_cooldown <= 0.0 and good_angle and (desperate or _kick_safe(f) or dist_goal < 6.0) and dist_goal < shoot_range and (lane_clear or opp_near < 1.8 or dist_goal < 5.5) and _can_kick(f, &"shot", false):
		var side: float = -signf(kz) if absf(kz) > 0.15 else (1.0 if rng.randf() < 0.5 else -1.0)
		var aim := Vector3(goal.x, 0.0, side * rng.randf_range(0.7, 1.2))
		var d: Vector3 = (aim - pos).normalized()
		var charge: float = clampf(0.45 + dist_goal / shoot_range * 0.4, 0.4, 0.9)
		if not _aligned(f, d):
			return
		# Desde fuera del area y escorado, a veces con chanfle: abre la salida y la curva la cierra al palo lejano.
		var curl: float = 0.0
		if dist_goal > 8.0 and absf(pos.z) > 1.5 and rng.randf() < 0.35 * (0.5 + skill):
			# Cerrar hacia el centro: con el arco hacia +X y la pelota en z>0, la curva va a la derecha (hacia -z).
			curl = -signf(pos.z) * atk.x * rng.randf_range(0.5, 0.9)
		_start_button(&"shot", charge * Tuning.ball.shot_charge_time * 0.6, d, dist_goal > 9.0 and rng.randf() < 0.15 and curl == 0.0, curl)
		return
	# --- Centro: desde la banda en el ultimo tercio, con companeros llegando al area.
	if _btn_cooldown <= 0.0 and _crossing_zone(ctx, pos, atk) and (desperate or _kick_safe(f)) and _box_has_mates(f, ctx, atk) and _can_kick(f, &"cross", false):
		var gx2: float = ctx.pitch.config.half_length() * atk.x
		var cdir: Vector3 = (Vector3(gx2 - atk.x * 3.0, 0.0, -signf(pos.z) * 1.5) - pos).normalized()
		if not _aligned(f, cdir):
			return
		var low_cross: bool = rng.randf() < 0.3
		_start_button(&"cross", rng.randf_range(0.1, 0.55) if rng.randf() < 0.75 else 0.75, cdir, low_cross)
		return
	# --- Pase filtrado: un companero ataca la espalda de la defensa con espacio por delante.
	if _btn_cooldown <= 0.0 and (desperate or _kick_safe(f)) and rng.randf() < 0.35 * (0.4 + skill):
		var runner: Footballer = _through_target(f, ctx, pos, atk)
		if runner != null and _can_kick(f, &"through", false):
			var tdir: Vector3 = (_flat(runner.global_position) + atk * 4.0 - pos).normalized()
			if not _aligned(f, tdir):
				return
			_start_button(&"through", clampf(0.2 + (_flat(runner.global_position) - pos).length() * 0.02, 0.2, 0.6), tdir, false)
			return
	# --- Pase: la jugada se construye pasando. Se evalua SIEMPRE un receptor y se decide por presion, progreso
	# y tiempo con la pelota; conducir indefinidamente no es una opcion.
	_carry_time += DECISION_PERIOD
	if _btn_cooldown <= 0.0 and (desperate or _kick_safe(f)) and _can_kick(f, &"pass", false):
		var tgt: Footballer = _best_pass_target(f, ctx, pos, atk)
		if tgt != null:
			var gain: float = (_flat(tgt.global_position) - pos).dot(atk)
			var want: bool = false
			if desperate or opp_near < PASS_PRESSURE_DIST:
				want = true                                   # con un rival encima, la pelota circula
			elif gain > 2.0 and _carry_time > UcsParams.BOT_MIN_KICK_S:
				want = rng.randf() < 0.45 * (0.6 + skill)     # el companero progresa la jugada
			elif _carry_time > CARRY_PATIENCE:
				want = true                                   # lleva demasiado con la pelota
			if want:
				var tp: Vector3 = _flat(tgt.global_position)
				var d2: Vector3 = tp - pos
				var dist: float = d2.length()
				# Con un rival encima no hay tiempo para girar del todo: se pasa con el cuerpo a medio orientar (el pase
				# pierde precision por la postura, ver PassAssist), en vez de girar despacio y perder la pelota.
				if not _aligned(f, d2, 75.0 if opp_near < PASS_PRESSURE_DIST else 28.0):
					return
				_start_button(&"pass", clampf(0.12 + dist * 0.022, 0.15, 0.62), d2.normalized(), dist > 15.0 and rng.randf() < 0.3)
				return
		elif desperate:
			# Sin companero libre y atascado: despeje largo hacia el campo rival.
			var clear_dir: Vector3 = (atk + Vector3(0.0, 0.0, -signf(pos.z) * 0.35)).normalized()
			if _aligned(f, clear_dir):
				_start_button(&"pass", 0.55, clear_dir, false)
			return
	# Regate: con un rival encima y algo de velocidad, a veces hace la ruleta.
	if opp_near < 1.9 and f.locomotion.speed > 2.0 and rng.randf() < 0.12 * (0.5 + skill):
		_skill_next = true
	# Conduccion hacia el arco esquivando rivales. Sin angulo de tiro se busca el punto frontal del area, no el fondo.
	# Se conduce hasta el borde del area chica, no hasta dentro de la red: desde ahi se dispara.
	var run_to: Vector3 = Vector3(goal.x - atk.x * 1.5, 0.0, goal.z)
	if not good_angle and dist_goal < shoot_range + 4.0:
		run_to = Vector3(goal.x - atk.x * 4.5, 0.0, clampf(pos.z * 0.3, -1.2, 1.2))
	var dir: Vector3 = (run_to - pos).normalized()
	dir = _avoid_opponents(f, ctx, pos, dir, atk)
	dir = _avoid_walls(pos, dir, ctx)
	_dir = dir
	_mag = 1.0
	_sprint = opp_near > 4.0 and dist_goal > 6.0

## Hay companeros llegando al area rival (para que un centro tenga destinatario).
func _box_has_mates(f: Footballer, ctx: MatchContext, atk: Vector3) -> bool:
	var gx: float = ctx.pitch.config.half_length() * atk.x
	for mate in ctx.teammates_of(f):
		var mp: Vector3 = _flat(mate.global_position + mate.velocity * 0.6)
		if absf(mp.x - gx) < 8.0 and absf(mp.z) < 5.0:
			return true
	return false

## Companero que corre hacia delante con espacio a su espalda (destinatario de un pase filtrado).
func _through_target(f: Footballer, ctx: MatchContext, pos: Vector3, atk: Vector3) -> Footballer:
	var best: Footballer = null
	var best_s: float = 0.0
	for mate in ctx.teammates_of(f):
		var mp: Vector3 = _flat(mate.global_position)
		var ahead: float = (mp - pos).dot(atk)
		if ahead < 1.5 or mp.distance_to(pos) > 20.0:
			continue
		var run: float = mate.velocity.dot(atk)
		var space: float = PassAssist._space_ahead(mate, atk, ctx.opponents_of(mate))
		if run < 2.0 or space < 4.0:
			continue
		var s2: float = space + run * 0.5
		if s2 > best_s:
			best_s = s2
			best = mate
	return best

# --- Utilidades tacticas -------------------------------------------------------------------------------------

## true si desde `pos` hay angulo util para disparar: el cono crece con la distancia a la linea de gol, asi que
## un tiro lejano y centrado vale y uno desde el costado del area, no. Evita disparar contra el lateral del arco.
func _shot_cone_ok(pos: Vector3, goal: Vector3, half_goal: float) -> bool:
	var depth: float = absf(goal.x - pos.x)
	if depth < 0.8:
		return false
	return absf(pos.z - goal.z) <= half_goal + SHOT_CONE_SLOPE * depth

## Angulo (grados) bajo el que se ven los dos postes desde `pos`; 0 si la pelota esta en la linea de fondo o detras.
func _goal_aperture_deg(pos: Vector3, goal: Vector3, half_goal: float) -> float:
	var a: Vector3 = Vector3(goal.x, 0.0, half_goal) - pos
	var b: Vector3 = Vector3(goal.x, 0.0, -half_goal) - pos
	var ahead: Vector3 = Vector3(signf(goal.x), 0.0, 0.0)
	if a.dot(ahead) < 0.6:
		return 0.0
	return rad_to_deg(absf(a.angle_to(b)))

func _carrier(ctx: MatchContext) -> Footballer:
	var ball: Ball = ctx.ball
	var best: Footballer = null
	var best_d: float = INF
	for p in ctx.footballers:
		var d: float = Vector2(p.global_position.x - ball.global_position.x, p.global_position.z - ball.global_position.z).length()
		if d < best_d and d <= Tuning.player.possession_radius and ball.global_position.y < 0.6:
			best_d = d
			best = p
	return best

## Companero (no arquero) que llega primero a la pelota.
func _chaser(f: Footballer, ctx: MatchContext) -> Footballer:
	var ball: Ball = ctx.ball
	var target: Vector3 = _flat(ball.global_position + ball.linear_velocity * 0.3)
	var best: Footballer = null
	var best_t: float = INF
	for p in ctx.footballers:
		if p.team != f.team:
			continue
		# El jugador que maneja la persona decide por si mismo: la IA nunca cuenta con el para ir a buscar la pelota
		# (si no, el equipo se queda parado esperando a un companero que quiza no se mueve).
		if TeamBrain.person_drives(p):
			continue
		var t: float = Vector2(p.global_position.x - target.x, p.global_position.z - target.z).length() / maxf(p.locomotion.max_run_speed(), 1.0)
		# El cierre solo sale si la pelota esta en su mitad o muy cerca.
		var role_bias: float = 0.0
		if p.input_source is AIInput:
			role_bias = float((p.input_source as AIInput).role == 3) * 0.4
		t += role_bias
		if t < best_t:
			best_t = t
			best = p
	return best

func _anchor(f: Footballer, attacking: bool) -> Vector3:
	var ctx: MatchContext = f.ctx
	var cfg: PitchConfig = ctx.pitch.config
	var half: float = cfg.half_length()
	var atk: Vector3 = _attack_dir(f)
	var own_goal_x: float = -atk.x * half
	var ball: Vector3 = _flat(ctx.ball.global_position)
	var ball_u: float = clampf((ball.x - own_goal_x) * atk.x / cfg.length, 0.0, 1.0)
	var depth: float = float(ROLE_DEPTH[role]) + (ball_u - 0.5) * float(ROLE_SHIFT[role]) + (0.08 if attacking else 0.0)
	depth = clampf(depth, 0.1, 0.9)
	var x: float = own_goal_x + atk.x * depth * cfg.length
	var z: float = float(ROLE_LATERAL[role]) + clampf(ball.z * 0.3, -3.0, 3.0)
	z = clampf(z, -cfg.width * 0.5 + 1.5, cfg.width * 0.5 - 1.5)
	return Vector3(x, 0.0, z)

## Punto de marca: entre el rival asignado y el propio arco, sin que dos companeros marquen al mismo. Cero si no
## hay rival al que marcar en esta zona.
func _mark_spot(f: Footballer, ctx: MatchContext, atk: Vector3) -> Vector3:
	var pos: Vector3 = _flat(f.global_position)
	var cfg: PitchConfig = ctx.pitch.config
	var own_goal := Vector3(-atk.x * cfg.half_length(), 0.0, 0.0)
	var best: Footballer = null
	var best_s: float = -INF
	for o in ctx.footballers:
		if o.team == f.team:
			continue
		var op: Vector3 = _flat(o.global_position)
		if op.distance_to(own_goal) > MARK_RANGE:
			continue   # lejos del area propia se defiende la zona, no al hombre
		# Cuanto mas cerca del arco propio y de este defensor, mas urgente es marcarlo.
		var s: float = -op.distance_to(own_goal) * 0.6 - op.distance_to(pos) * 0.8
		# No doblar marcas: si otro companero esta mas cerca de ese rival, no es mio.
		for mate in ctx.footballers:
			if mate.team != f.team or mate == f:
				continue
			if _flat(mate.global_position).distance_to(op) < pos.distance_to(op) - 0.5:
				s -= 25.0
				break
		if s > best_s:
			best_s = s
			best = o
	if best == null:
		return Vector3.ZERO
	var bp: Vector3 = _flat(best.global_position)
	var to_goal: Vector3 = own_goal - bp
	if to_goal.length() < 0.5:
		return bp
	return bp + to_goal.normalized() * MARK_GOAL_SIDE

func _support_spot(f: Footballer, carrier: Footballer, atk: Vector3) -> Vector3:
	var a: Vector3 = _anchor(f, true)
	var cp: Vector3 = _flat(carrier.global_position)
	# Se ofrece por delante del portador, manteniendo su carril.
	var half: float = f.ctx.pitch.config.half_length() - 2.5
	var x: float = a.x
	if role >= 1:
		x = clampf(maxf(a.x * atk.x, cp.x * atk.x + 4.0) * atk.x, -half, half)
	var spot := Vector3(x, 0.0, a.z)
	# Separacion de companeros.
	for p in f.ctx.footballers:
		if p == f or p.team != f.team:
			continue
		var d: Vector3 = spot - _flat(p.global_position)
		if d.length() < 3.0 and d.length() > 0.01:
			spot += d.normalized() * (3.0 - d.length())
	# Linea de pase: si un rival tapa la linea desde el portador, el apoyo se desplaza de lado hasta abrirla.
	var side: Vector3 = Vector3(-atk.z, 0.0, atk.x)
	for attempt in 3:
		if _lane_clear(f, f.ctx, cp, spot, 0.9):
			break
		spot += side * (2.2 if (attempt % 2 == 0) else -4.4)
		spot.z = clampf(spot.z, -f.ctx.pitch.config.width * 0.5 + 1.2, f.ctx.pitch.config.width * 0.5 - 1.2)
	var half_w: float = f.ctx.pitch.config.width * 0.5 - 1.2
	spot.z = clampf(spot.z, -half_w, half_w)
	return spot

func _move_to(f: Footballer, target: Vector3, magnitude: float) -> void:
	var d: Vector3 = target - _flat(f.global_position)
	if d.length() < 0.6:
		_dir = Vector3.ZERO
		_mag = 0.0
		return
	_dir = d.normalized()
	_mag = clampf(d.length() / 3.0, 0.35, 1.0) * magnitude

func _nearest_opponent_dist(f: Footballer, ctx: MatchContext, pos: Vector3, atk: Vector3) -> float:
	var best: float = INF
	for o in ctx.footballers:
		if o.team == f.team:
			continue
		var d: Vector3 = _flat(o.global_position) - pos
		# Solo cuentan los que estan delante o a los lados (los de atras presionan menos).
		if d.dot(atk) > -1.0:
			best = minf(best, d.length())
	return best

func _lane_clear(f: Footballer, ctx: MatchContext, a: Vector3, b: Vector3, width: float) -> bool:
	var ab: Vector3 = b - a
	var len2: float = ab.length_squared()
	if len2 < 0.01:
		return true
	var blockers: Array = []
	for o in ctx.footballers:
		if o.team != f.team:
			blockers.append(o)
	for k in ctx.keepers:
		if int(k.get("team")) != f.team:
			blockers.append(k)
	for o in blockers:
		var p: Vector3 = _flat((o as Node3D).global_position)
		var u: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		if u > 0.05 and (a + ab * u - p).length() < width:
			return false
	return true

func _best_pass_target(f: Footballer, ctx: MatchContext, pos: Vector3, atk: Vector3) -> Footballer:
	var best: Footballer = null
	var best_s: float = -INF
	for t in ctx.footballers:
		if t == f or t.team != f.team:
			continue
		var tp: Vector3 = _flat(t.global_position)
		var d: float = (tp - pos).length()
		if d < 2.5 or d > 22.0:
			continue
		var open: float = 6.0
		for o in ctx.footballers:
			if o.team != f.team:
				open = minf(open, (_flat(o.global_position) - tp).length())
		# Bajo presion vale un pase mas arriesgado: la linea puede estar menos limpia y el receptor menos solo.
		var tight: bool = _nearest_opponent_dist(f, ctx, pos, atk) < PASS_PRESSURE_DIST
		if open < (1.4 if tight else 1.9) or not _lane_clear(f, ctx, pos, tp, 0.65 if tight else 0.8):
			continue
		var progress: float = (tp - pos).dot(atk)
		var s: float = progress * 0.7 + open * 1.4 - d * 0.25
		if s > best_s:
			best_s = s
			best = t
	return best

func _avoid_opponents(f: Footballer, ctx: MatchContext, pos: Vector3, dir: Vector3, atk: Vector3) -> Vector3:
	var steer: Vector3 = dir
	for o in ctx.footballers:
		if o.team == f.team:
			continue
		var d: Vector3 = _flat(o.global_position) - pos
		var dist: float = d.length()
		if dist > 4.0 or dist < 0.01:
			continue
		if d.normalized().dot(dir) < 0.2:
			continue
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var s: float = -signf(d.dot(side)) if absf(d.dot(side)) > 0.05 else 1.0
		steer += side * s * (4.0 - dist) * 0.35
	for k in ctx.keepers:
		if int(k.get("team")) == f.team:
			continue
		var kd: Vector3 = _flat((k as Node3D).global_position) - pos
		if kd.length() < 3.0 and kd.normalized().dot(dir) > 0.5:
			steer += Vector3(-dir.z, 0.0, dir.x) * signf(-kd.z if absf(kd.z) > 0.05 else 1.0) * 0.8
	return steer.normalized()

## Un companero a menos de MAKE_WAY_DIST del portador se aparta de su trayectoria (de lado, hacia donde ya esta) antes
## de seguir a su puesto: el portador corre mas y si no se le echaba encima (medido en el modo entrenamiento).
const MAKE_WAY_DIST := 3.0

func _make_way(f: Footballer, carrier: Footballer) -> void:
	if carrier == null or carrier == f or carrier.team != f.team:
		return
	var rel: Vector3 = _flat(f.global_position - carrier.global_position)
	if rel.length() > MAKE_WAY_DIST:
		return
	var v: Vector3 = _flat(carrier.velocity)
	var dir: Vector3 = v.normalized() if v.length() > 0.8 else _attack_dir(f)
	var side := Vector3(-dir.z, 0.0, dir.x)
	var lat: float = rel.dot(side)
	var away: Vector3 = side * (signf(lat) if absf(lat) > 0.1 else 1.0)
	# Si delante del portador, ademas no frena su carrera: se aparta en diagonal hacia adelante.
	if rel.dot(dir) > 0.0:
		away = (away + dir * 0.5).normalized()
	_dir = away
	_mag = 1.0
	_sprint = true

## Detras de la linea de fondo y a la altura del arco (por perseguir una pelota que salio), el camino recto de vuelta
## choca con la red: primero se rodea el poste por el lado mas cercano (hallado en un partido: un jugador quedo
## detras del arco empujando la red).
func _around_goal(f: Footballer, dir: Vector3) -> Vector3:
	if dir.length_squared() < 0.0001:
		return dir
	var cfg: PitchConfig = f.ctx.pitch.config
	var p: Vector3 = f.global_position
	var hl: float = cfg.half_length()
	var post: float = cfg.half_goal() + 0.6
	if absf(p.x) < hl - 0.1 or absf(p.z) > post or signf(dir.x) == signf(p.x):
		return dir
	var side: float = signf(p.z) if absf(p.z) > 0.05 else 1.0
	return Vector3(0.0, 0.0, side)

func _avoid_walls(pos: Vector3, dir: Vector3, ctx: MatchContext) -> Vector3:
	var half_w: float = ctx.pitch.config.width * 0.5 - 1.0
	var out: Vector3 = dir
	if pos.z > half_w and dir.z > 0.0:
		out.z = -0.3
	elif pos.z < -half_w and dir.z < 0.0:
		out.z = 0.3
	return out.normalized()
