class_name JsonBallMove
extends RefCounted
## Modo 4 (Json): movimientos con pelota de los clips JSON. Giros con pelota (de 45 a 180 grados, desde parado o en carrera),
## la vuelta atras pisando la pelota (REGATE + atras), regates (REGATE) y frenadas con la pelota. Como en FIFA/PES el
## movimiento es un clip con sus toques: el clip mueve y gira al cuerpo (raiz y rumbo, PlayerActions/ActionMotion) y la
## pelota va de un toque del clip al siguiente. Cada toque (instante y pie medidos en los datos, meta ball_touches) le da a
## la pelota el impulso que la lleva hasta donde estara la punta del pie en el toque siguiente; el ultimo la deja delante del
## rumbo de salida y sigue la conduccion normal. La pelota solo cambia de velocidad con Ball.kick (nunca se la coloca) y el
## pie se lleva con TouchFootIK los centimetros que falten hasta la pelota real, asi el toque se ve.
## Solo empieza si la pelota llega al primer toque (prediccion de su rodadura, con un ajuste de paso acotado); si no, siguen
## los mecanismos de siempre (BallTurn, DragBack, toques de conduccion).
## Toque orientado (2026-11-05, como UCS): con el joystick a 14-50 grados del frente, la conduccion del jugador de la persona
## sigue con uno de los clips de conduccion de UCS (avance con giro de 2 a 40 grados, diagonales «45», arranques) que gira
## hacia alli: el clip da los toques con su pie y en su instante y se corta tras el segundo (el giro ya esta dado); la pelota
## sale hacia el joystick y la conduccion normal sigue. Con el joystick sostenido en diagonal se encadenan (curva progresiva).
## En UCS es igual: animdb.adb guarda por clip el fotograma del toque, el pie, el destino de la pelota, el giro y la ventana
## del joystick en la que se elige (docs/fases/E3_conduccion_ucs_animdb.csv).

## Angulo (grados) minimo entre el frente y el joystick para girar con un clip, y joystick minimo.
const TURN_MIN_ANGLE := 50.0
const MIN_STICK := 0.35
## Velocidad (m/s) maxima del cuerpo para empezar un movimiento con pelota.
const MAX_SPEED := 6.5
## Tolerancia (grados) entre el giro pedido y el del clip.
const TURN_TOL := 35.0
## Velocidad (m/s) minima y maxima para frenar con la pelota con un clip (joystick recien soltado, STOP_WINDOW s); a mas
## velocidad frena la conduccion de siempre (toque de parada).
const STOP_MIN_SPEED := 2.6
const STOP_MAX_SPEED := 4.6
const STOP_WINDOW := 0.15
## Diferencia maxima (m/s) entre la carrera de entrada del clip (v_in) y la del jugador: para los giros y frenadas que pide el
## joystick (a mas velocidad que la del clip el cuerpo frenaba en seco y perdia terreno; ahi manda el giro con toques,
## BallTurn) y para los que pide el boton REGATE (pedido explicito).
const MAX_DV_STICK := 1.5
const MAX_DV_BUTTON := 3.0
## Ajuste de paso: m/s extra del cuerpo para llegar a la pelota en el primer toque, y error (m) que cubre el pie (IK).
const CORR_SPEED := 1.4
const CORR_MAX := 0.4
const FOOT_SLACK := 0.16
## La pelota queda BALL_LEAD m por delante de la punta del pie en el sentido en que se mueve el pie (radio y holgura).
const BALL_LEAD := 0.12
## A mas de MISS_DIST m del pie en un toque, el toque se pierde; dos seguidos cancelan el movimiento.
const MISS_DIST := 0.5
## Espera maxima (s) hasta el primer toque del clip: con mas, en partido un rival tocaba o desviaba la pelota antes y el
## clip seguia hasta errar el toque (medido: primeros toques a 0.6-0.9 m tras 0.6 s de espera).
const MAX_LEAD := 0.4
## IK del pie: empieza IK_LEAD s antes del toque y se suelta IK_HOLD s despues; mas lejos de IK_MAX m no se fuerza.
const IK_LEAD := 0.16
const IK_HOLD := 0.06
const IK_MAX := 0.32
## La IA gira con un clip solo en los giros cerrados (AI_TURN_MIN grados) y como mucho uno cada AI_COOLDOWN s: mientras dura
## el clip no puede pasar (medido en un partido de IA: con giros de clip sin limite, 6-12 pases en 90 s frente a 14-17).
const AI_TURN_MIN := 110.0
const AI_COOLDOWN := 3.0
## Segundos entre movimientos y entre intentos de planificar (planificar recorre decenas de clips).
const COOLDOWN := 0.6
const PLAN_EVERY := 3

const ROLES_TURN: Array[StringName] = [&"ball_turn"]
const ROLES_DRAG: Array[StringName] = [&"ball_turn", &"ball_turn_stop", &"ball_skill"]
const ROLES_SKILL: Array[StringName] = [&"ball_skill"]
const ROLES_STOP: Array[StringName] = [&"ball_stop"]
## Toque orientado: angulo minimo del joystick (por debajo manda el toque de rumbo fisico), tolerancia entre el giro del clip
## y el pedido, diferencia de velocidad admitida, espera tras uno (para encadenarlos en curva), cola tras el toque que
## orienta y velocidad minima (parado o casi, los arranques y giros de siempre).
const STEER_MIN_ANGLE := 14.0
const STEER_TOL := 24.0
const STEER_MAX_DV := 1.6
const STEER_COOLDOWN := 0.15
const STEER_TAIL := 0.12
## Lo mas que se orienta la pelota respecto de la salida del clip en sprint (al trote 60 grados).
const STEER_SNAP_SPRINT := 22.0
const STEER_MIN_SPEED := 0.6
## En sprint (mas de STEER_MAX_SPEED) los cambios de rumbo los da el toque de rumbo fisico: con los clips de sprint de UCS el
## cuerpo seguia la raiz del clip y se apartaba 35 grados de su pelota (test_physical_dribble::test_diagonal_after_sprint,
## 2026-11-06); al trote y en carrera, el toque orientado.
const STEER_MAX_SPEED := 5.0
## Tras un pase o tiro propio la pelota va de viaje: el que golpeo y corre detras no la conduce con un toque orientado ni un
## arranque hasta pasado este tiempo (medido: tras un pase filtrado en carrera alcanzaba su propia pelota y empezaba un toque
## orientado; test_live_kicks::test_kick_battery_fifty_varied_actions lo daba por bloqueado).
const STEER_AFTER_KICK_S := 1.2
## Preferencia (puntos de error) por el interior del pie de afuera del giro: el izquierdo para doblar a la derecha y el
## derecho para doblar a la izquierda (lo que se ve en UCS con la pelota al centro).
const STEER_OUTER_FOOT_BONUS := 0.06
## Roles del banco donde estan los clips de conduccion de UCS (el overlay de roles paso los de avance a ball_skill).
const STEER_ROLES: Array[StringName] = [&"ball_turn", &"ball_dribble", &"ball_skill", &"ball_start", &"ball_turn_stop",
	&"ball_stop", &"control_stand"]
static var _steer_pool: Array[StringName] = []
static var _steer_built: bool = false
## Arranque con pelota desde parado (UCS: STAND_TO_JOGGING_DRIBBLE, STAND_TO_45_R…, CONTROL_DRIBBLE_00, CONTROL_STAND_17):
## con el jugador de la persona casi quieto (< STEER_MIN_SPEED) y el joystick firme a menos de 50 grados, el arranque es el
## clip entero (los de 50 grados o mas ya los usa el giro con pelota). Tolerancia del giro, joystick minimo y diferencia
## de velocidad admitida.
const START_TOL := 40.0
const START_MIN_STICK := 0.6
const START_MAX_DV := 1.2
const START_MAX_V_IN := 1.2
static var _start_pool: Array[StringName] = []

var handler: BallHandler
var active: bool = false
var intent: StringName = &""
var clip: StringName = &""
var _touches: Array = []
var _next: int = 0
var _misses: int = 0
var _origin: Vector3 = Vector3.ZERO
var _yaw0: float = 0.0
var _speed: float = 1.0
var _length: float = 0.0
var _root_end: Vector2 = Vector2.ZERO
var _turn_end: float = 0.0
var _v_out: float = 0.0
var _first_t: float = 0.0
var _corr: Vector3 = Vector3.ZERO
var _cooldown: float = 0.0
## Espera propia del toque orientado (ver finish).
var _steer_cd: float = 0.0
var _plan_tick: int = 0
## Pedidos con el boton REGATE: vuelta atras pisando la pelota o regate (segundos que quedan del pedido).
var _skill_req: float = 0.0
var _ik_foot: int = -1
var _released_t: float = 0.0
## Indice del toque que deja la pelota para la conduccion normal (el ultimo del clip; en el toque orientado, el segundo) e
## instante del clip en que termina el movimiento (la duracion, o el corte del toque orientado).
var _last: int = 0
var _end_t: float = 0.0
## Recepcion (intencion &"receive", JsonReceive): quien toco la pelota por ultimo al planificar (si otro la toca antes del
## primer toque la recepcion se corta) y si ya hubo toque.
var _recv_toucher: Node = null
## Direccion (en el suelo) por donde llega la pelota a recibir: el pie se pone delante de ella (JsonReceive.contact_offset).
var _recv_inc: Vector3 = Vector3.ZERO
## Parte del cuerpo e instante (s del clip) del primer contacto de la recepcion (perfil de JsonReceive), e instante en que se
## corta el clip antes de su pase o golpeo posterior (-1 = sin corte).
var _recv_part: StringName = &""
var _recv_t: float = 0.0
var _recv_cut: float = -1.0
## Perfil de contacto (trayectoria de la parte del cuerpo alrededor del contacto, JsonReceive.contact_point).
var _recv_cp: Dictionary = {}
## Distancia minima (m) entre la pelota y la parte del cuerpo antes del contacto (diagnostico).
var _recv_gap: float = INF
## Trayectoria prevista de la pelota al planificar y paso de fisica del plan.
var _recv_traj: PackedVector3Array = PackedVector3Array()
var _recv_frame0: int = 0
var stats := {"started": 0, "done": 0, "touches": 0, "missed": 0, "aborted": 0}
## Traza (AnimTrace, solo depuracion): decision en curso de consider / turn_for_kick (plan_ids agrega los candidatos).
var _trace_dec: Dictionary = {}

## Familia de traza del movimiento en curso: la recepcion se cuenta aparte de los movimientos con pelota.
func _trace_family() -> StringName:
	return &"receive" if intent == &"receive" else &"ball_move"
var last := {}
## Ultimos movimientos terminados o cortados (diagnostico y pruebas).
var history: Array = []

func _init(h: BallHandler) -> void:
	handler = h

## Clips de conduccion de UCS que sirven para el toque orientado (con su espejo): los de control con «dribble» en el nombre
## del archivo que siguen en carrera (v_out >= 1) y tienen toques de pelota.
static func steer_pool() -> Array[StringName]:
	if _steer_built:
		return _steer_pool
	_steer_built = true
	_steer_pool.clear()
	var seen := {}
	for role in STEER_ROLES:
		for id in PackLibrary.by_role(role):
			if seen.has(id):
				continue
			seen[id] = true
			var m: Dictionary = PackLibrary.meta(id)
			var src: String = String(m.get("source", "")).to_lower()
			if src.find("_control_") < 0 or src.find("dribble") < 0:
				continue
			if (m.get("ball_touches", []) as Array).is_empty() or float(m.get("v_out", 0.0)) < 1.0:
				continue
			if String(m.get("heading_mode", "")) != "turn":
				continue
			_steer_pool.append(id)
	return _steer_pool

## Clips de arranque con pelota: los de conduccion de UCS que entran casi quietos (v_in < START_MAX_V_IN) y todos los del rol
## ball_start (arranques de conduccion del banco) que siguen en carrera.
static func start_pool() -> Array[StringName]:
	if not _start_pool.is_empty():
		return _start_pool
	for id in steer_pool():
		if float(PackLibrary.meta(id).get("v_in", 9.0)) < START_MAX_V_IN:
			_start_pool.append(id)
	for id in PackLibrary.by_role(&"ball_start"):
		var m: Dictionary = PackLibrary.meta(id)
		if _start_pool.has(id) or (m.get("ball_touches", []) as Array).is_empty():
			continue
		if float(m.get("v_out", 0.0)) < 1.0 or String(m.get("heading_mode", "")) != "turn":
			continue
		_start_pool.append(id)
	return _start_pool

static func reset_caches() -> void:
	_steer_pool.clear()
	_steer_built = false
	_start_pool.clear()

func request_skill() -> void:
	_skill_req = 0.3

## Paso de fisica (BallHandler.update, modo 4, antes de DragBack y BallTurn): decide si empieza un movimiento con pelota.
## Devuelve true si empezo (el resto del paso lo maneja la accion).
func consider(desired_dir: Vector3, stick_mag: float, dt: float) -> bool:
	_cooldown = maxf(_cooldown - dt, 0.0)
	_steer_cd = maxf(_steer_cd - dt, 0.0)
	_skill_req = maxf(_skill_req - dt, 0.0)
	_released_t = _released_t + dt if stick_mag < 0.15 else 0.0
	if active or (_cooldown > 0.0 and _steer_cd > 0.0):
		return false
	# Un giro con toques o una vuelta pisando la pelota ya en curso no se interrumpe (sumados, el giro tardaba el doble).
	if handler.ball_turn.active() or handler.drag_back.active():
		return false
	var owner: Footballer = handler.owner
	if owner.actions == null or owner.actions.active() or not owner.actions._can_play():
		return false
	if handler.is_kick_in_progress() or handler._pending_action != &"" or not handler.has_possession():
		return false
	# Cargando un pase o tiro no se gira con la pelota: si el destino queda atras, el golpeo mismo gira (plan_turn_kick).
	if handler._pass_active or handler._shoot_active or handler._through_active or handler._cross_active:
		return false
	var b: Ball = handler.ball()
	if b == null or b.is_held() or b.global_position.y > 0.3 or handler.ball_distance() > 1.4:
		return false
	var loco: Locomotion = owner.locomotion
	if loco.speed > MAX_SPEED:
		return false
	var fwd: Vector3 = loco.forward()
	var has_dir: bool = stick_mag >= MIN_STICK and desired_dir.length_squared() > 0.01
	var ang: float = 0.0
	if has_dir:
		var dir: Vector3 = KickModel.flat(desired_dir).normalized()
		ang = rad_to_deg(wrapf(Locomotion.yaw_from_dir(dir) - loco.yaw, -PI, PI))
	var roles: Array[StringName] = []
	var want: float = 0.0
	var tol: float = TURN_TOL
	var new_intent: StringName = &""
	if _skill_req > 0.0:
		if has_dir and absf(ang) >= DragBack.MIN_ANGLE - 15.0:
			roles = ROLES_DRAG
			want = 180.0 * (signf(ang) if absf(ang) < 178.0 else 1.0)
			tol = 55.0
			new_intent = &"drag"
		else:
			roles = ROLES_SKILL
			want = ang
			tol = 70.0 if has_dir else 200.0
			new_intent = &"skill"
	elif has_dir and absf(ang) >= (TURN_MIN_ANGLE if owner.is_human_controlled else AI_TURN_MIN):
		roles = ROLES_TURN
		want = ang
		new_intent = &"turn"
	elif not has_dir and _released_t > 0.0 and _released_t <= STOP_WINDOW and loco.speed >= STOP_MIN_SPEED and loco.speed <= STOP_MAX_SPEED and handler.is_dribbling():
		roles = ROLES_STOP
		want = 0.0
		tol = 60.0
		new_intent = &"stop"
	elif has_dir and absf(ang) >= STEER_MIN_ANGLE and _person(owner) and loco.speed >= STEER_MIN_SPEED and loco.speed <= STEER_MAX_SPEED \
			and handler.is_dribbling() \
			and handler.seconds_since_kick() > STEER_AFTER_KICK_S:
		want = ang
		tol = STEER_TOL
		new_intent = &"steer"
	elif has_dir and stick_mag >= START_MIN_STICK and _person(owner) and loco.speed < STEER_MIN_SPEED \
			and not (owner.last_frame != null and owner.last_frame.sprint) and handler.seconds_since_kick() > STEER_AFTER_KICK_S:
		# Con el boton de sprint apretado el arranque es el de siempre: los clips de arranque de UCS salen al trote (2-3.5 m/s)
		# y dejaban la pelota lejos para el giro siguiente en sprint (test_ball_turn::test_wide_turn_and_sprint).
		want = ang
		tol = START_TOL
		new_intent = &"start"
	else:
		return false
	# Esperas: el toque orientado tiene la suya (corta tras un arranque o tras otro toque orientado); el resto, la general.
	if (new_intent == &"steer" and _steer_cd > 0.0) or (new_intent != &"steer" and _cooldown > 0.0):
		return false
	# Planificar recorre decenas de clips: no en cada paso (salvo un pedido con el boton, que es puntual, y el toque orientado
	# del jugador de la persona: si espera, el toque de rumbo fisico se adelanta y el clip de UCS no llega a usarse).
	_plan_tick += 1
	if new_intent != &"drag" and new_intent != &"skill" and new_intent != &"steer" and new_intent != &"start" and _plan_tick % PLAN_EVERY != 0:
		return false
	var plan: Dictionary
	_trace_dec = AnimTrace.begin(owner, &"ball_move", &"JsonBallMove.consider", String(new_intent)) if AnimTrace.enabled else {}
	if new_intent == &"steer":
		plan = plan_ids(steer_pool(), want, tol, false, STEER_MAX_DV, true)
	elif new_intent == &"start":
		plan = plan_ids(start_pool(), want, tol, false, START_MAX_DV)
	else:
		plan = plan_move(roles, want, tol, new_intent == &"drag", MAX_DV_BUTTON if (new_intent == &"drag" or new_intent == &"skill") else MAX_DV_STICK)
	if plan.is_empty():
		if not _trace_dec.is_empty():
			AnimTrace.commit(_trace_dec, &"", {}, "rejected", "ningun clip llega a la pelota")
			_trace_dec = {}
		return false
	var started: bool = _start(plan, new_intent)
	if not _trace_dec.is_empty():
		AnimTrace.commit(_trace_dec, plan["clip"], {"orient_target": want}, "accepted" if started else "rejected", "" if started else "arbitro o clip no reproducible")
		_trace_dec = {}
	if not started:
		return false
	if not owner.is_human_controlled:
		_cooldown = AI_COOLDOWN
	return true

## Jugador que lleva la persona con su mando: el toque orientado y el arranque son solo suyos. Con el control puede pasar al
## receptor la entrada de la IA (partidos de IA de las pruebas): ahi decide la IA y sigue como antes.
static func _person(owner: Footballer) -> bool:
	return owner.is_human_controlled and not (owner.input_source is AIInput)

## Golpeo pedido hacia `dir` casi detras del jugador: giro con la pelota hacia alli (el golpeo espera a que termine).
func turn_for_kick(dir: Vector3) -> bool:
	var owner: Footballer = handler.owner
	if active or owner.actions == null or owner.actions.active() or not owner.actions._can_play():
		return false
	var ang: float = rad_to_deg(wrapf(Locomotion.yaw_from_dir(KickModel.flat(dir).normalized()) - owner.locomotion.yaw, -PI, PI))
	var roles: Array[StringName] = [&"ball_turn", &"ball_turn_stop"]
	_trace_dec = AnimTrace.begin(owner, &"ball_move", &"JsonBallMove.turn_for_kick", "kick_turn") if AnimTrace.enabled else {}
	var plan: Dictionary = plan_move(roles, ang, 50.0, absf(ang) > 165.0)
	if plan.is_empty():
		if not _trace_dec.is_empty():
			AnimTrace.commit(_trace_dec, &"", {}, "rejected", "ningun giro con pelota llega")
			_trace_dec = {}
		return false
	var started: bool = _start(plan, &"kick_turn")
	if not _trace_dec.is_empty():
		AnimTrace.commit(_trace_dec, plan["clip"], {"orient_target": ang}, "accepted" if started else "rejected", "" if started else "arbitro o clip no reproducible")
		_trace_dec = {}
	return started

## Elige el clip, el instante de inicio y el ajuste de paso para que la pelota llegue al primer toque del clip.
## {} si ninguno llega. want: giro pedido (grados, + izquierda); tol: tolerancia; both_sides: vale girar por cualquier lado.
func plan_move(roles: Array[StringName], want: float, tol: float, both_sides: bool = false, max_dv: float = MAX_DV_BUTTON) -> Dictionary:
	var ids: Array[StringName] = []
	for role in roles:
		ids.append_array(PackLibrary.by_role(role))
	return plan_ids(ids, want, tol, both_sides, max_dv)

## Como plan_move, sobre una lista de clips. steer: toque orientado (se corta tras el segundo toque: ese es el que deja la
## pelota hacia el joystick; se prefiere el interior del pie de afuera del giro).
func plan_ids(ids: Array[StringName], want: float, tol: float, both_sides: bool = false, max_dv: float = MAX_DV_BUTTON, steer: bool = false) -> Dictionary:
	var owner: Footballer = handler.owner
	var loco: Locomotion = owner.locomotion
	var b: Ball = handler.ball()
	var best: Dictionary = {}
	var best_score: float = INF
	var pos: Vector3 = KickModel.flat(owner.global_position)
	for id in ids:
		var m: Dictionary = PackLibrary.meta(id)
		var bt: Array = m.get("ball_touches", [])
		if bt.is_empty():
			if not _trace_dec.is_empty():
				AnimTrace.cand(_trace_dec, id, "sin toques de pelota medidos")
			continue
		var hp: PackedFloat32Array = m.get("heading_path", PackedFloat32Array())
		var dur: float = float(m.get("duration", 1.0))
		# Toque orientado: cuenta lo que gira el cuerpo hasta el corte (tras el segundo toque), no el clip entero.
		var turn_t: float = minf(float(bt[1][0]) + STEER_TAIL, dur) if steer and bt.size() > 1 else dur
		var turn: float = rad_to_deg(ActionMotion.heading_rel(hp, turn_t))
		var dturn: float = absf(turn - want)
		# Toque orientado: el cuerpo no puede girar al lado contrario del pedido (con el joystick a la izquierda, un clip que
		# dobla a la derecha se veia al reves aunque la pelota saliera bien), y el joystick tiene que caer en la ventana en
		# la que UCS elige ese clip (animdb: 32 sectores de 11.25 grados).
		if steer and turn * want < 0.0 and absf(turn) > 3.0:
			if not _trace_dec.is_empty():
				AnimTrace.cand(_trace_dec, id, "gira al lado contrario del pedido")
			continue
		# Solo en el toque orientado (14-50 grados): en los giros grandes la ventana de UCS no esta centrada en el giro del clip
		# (en 839 clips el giro cae en su ventana en 444 y la mitad del giro en 629; con la ventana, los clips de 180 grados
		# no se elegirian nunca para un giro de 180): su referencia ahi no se pudo establecer y no se aplica.
		if steer:
			var win: Vector2 = AnimDB.joystick_window(id)
			if want < win.x - 1.0 or want > win.y + 1.0:
				if not _trace_dec.is_empty():
					AnimTrace.cand(_trace_dec, id, "joystick fuera de la ventana del clip (%.0f a %.0f grados)" % [win.x, win.y])
				continue
		if both_sides:
			dturn = minf(dturn, absf(turn + want))
		if dturn > tol:
			if not _trace_dec.is_empty():
				AnimTrace.cand(_trace_dec, id, "giro del clip %.0f grados frente a %.0f pedidos" % [turn, want], {"angular_error_deg": dturn})
			continue
		var v_in: float = float(m.get("v_in", 0.0))
		var dv: float = absf(v_in - loco.speed)
		if dv > max_dv:
			if not _trace_dec.is_empty():
				AnimTrace.cand(_trace_dec, id, "carrera de entrada %.1f m/s frente a %.1f m/s" % [v_in, loco.speed], {"v_in": loco.speed, "v_clip": v_in})
			continue
		var rp: PackedVector2Array = m.get("root_path", PackedVector2Array())
		for start_at in [0.0, 0.1, 0.2, 0.3]:
			var t1: float = float(bt[0][0])
			if t1 - start_at < 0.12:
				break
			var yaw0: float = loco.yaw - ActionMotion.heading_rel(hp, start_at)
			var f0: Vector3 = Locomotion.dir_from_yaw(yaw0)
			var r0 := Vector3(-f0.z, 0.0, f0.x)
			var rs: Vector2 = ActionMotion._at(rp, start_at) if rp.size() >= 2 else Vector2.ZERO
			var origin: Vector3 = pos - f0 * rs.x - r0 * rs.y
			var p1: Vector3 = bt[0][2]
			var vel1: Vector2 = bt[0][3]
			var lead: Vector3 = (f0 * vel1.x + r0 * vel1.y).normalized() * BALL_LEAD if vel1.length() > 0.3 else Vector3.ZERO
			var target: Vector3 = origin + f0 * p1.x + r0 * p1.z + lead
			var dt1: float = t1 - start_at
			if dt1 > MAX_LEAD:
				if not _trace_dec.is_empty():
					AnimTrace.cand(_trace_dec, id, "primer toque a %.2f s (maximo %.2f s)" % [dt1, MAX_LEAD])
				continue
			var bp: Vector3 = KickModel.flat(b.global_position + handler.ball_travel(b, dt1))
			var err: Vector3 = bp - target
			var corr: Vector3 = err.limit_length(minf(CORR_MAX, CORR_SPEED * dt1))
			var residual: float = (err - corr).length()
			if residual > FOOT_SLACK:
				if not _trace_dec.is_empty():
					AnimTrace.cand(_trace_dec, id, "pie a %.2f m de la pelota en el primer toque (limite %.2f m)" % [residual, FOOT_SLACK])
				continue
			var score: float = residual + 0.25 * corr.length() + 0.12 * dv + 0.004 * dturn + 0.03 * start_at + handler.rng.randf() * 0.04
			if not _trace_dec.is_empty():
				AnimTrace.cand(_trace_dec, id, "", {"frame_start": int(round(start_at * AnimTrace.FRAME_RATE)), "frame_contact": int(round(t1 * AnimTrace.FRAME_RATE)),
					"body_part": "foot", "foot": "R" if float(bt[0][1]) > 0.0 else "L", "v_in": loco.speed, "v_clip": v_in,
					"orient_start": rad_to_deg(loco.yaw), "orient_target": want, "ball_pred_x": bp.x, "ball_pred_y": b.global_position.y, "ball_pred_z": bp.z,
					"contact_point_x": target.x, "contact_point_y": 0.0, "contact_point_z": target.z, "spatial_error_m": err.length(),
					"angular_error_deg": dturn, "root_correction_m": corr.length(), "tolerance_applied": FOOT_SLACK, "tolerance_reason": "FOOT_SLACK",
					"cost_total": score, "cost_breakdown_json": {"residuo": residual, "correccion": 0.25 * corr.length(), "carrera": 0.12 * dv,
						"giro": 0.004 * dturn, "inicio": 0.03 * start_at}})
			if steer:
				# El toque que orienta es el segundo (o el unico): con su pie del lado de afuera del giro, interior.
				var lt: Array = bt[mini(1, bt.size() - 1)]
				if signf(float(lt[1])) == signf(want):
					score -= STEER_OUTER_FOOT_BONUS
			if score < best_score:
				best_score = score
				best = {"clip": id, "start_at": start_at, "yaw0": yaw0, "origin": origin, "corr": corr, "dt1": dt1, "residual": residual, "turn": turn}
	return best

func _start(plan: Dictionary, new_intent: StringName) -> bool:
	var owner: Footballer = handler.owner
	var id: StringName = plan["clip"]
	var m: Dictionary = PackLibrary.meta(id)
	var bts: Array = m.get("ball_touches", [])
	var dur: float = float(m.get("duration", 1.0))
	var start_at: float = float(plan["start_at"])
	var last_i: int = bts.size() - 1
	var end_t: float = dur
	var cut: float = -1.0
	if new_intent == &"steer" and bts.size() > 1:
		last_i = 1
		end_t = minf(float(bts[1][0]) + STEER_TAIL, dur)
		if end_t < dur - 0.05:
			cut = end_t - start_at
		else:
			end_t = dur
	if not owner.actions.start_move(&"ball_move", id, 1.0, start_at, cut):
		return false
	active = true
	intent = new_intent
	clip = id
	_touches = bts
	_last = last_i
	_end_t = end_t
	_next = 0
	_misses = 0
	_origin = plan["origin"]
	_yaw0 = float(plan["yaw0"])
	_speed = 1.0
	_length = float(m.get("duration", 1.0))
	_root_end = m.get("root_total", Vector2.ZERO)
	_turn_end = ActionMotion.heading_rel(m.get("heading_path", PackedFloat32Array()), _length)
	_v_out = float(m.get("v_out", 0.0))
	_first_t = float(plan["dt1"])
	var dt1: float = maxf(float(plan["dt1"]), 0.05)
	_corr = (plan["corr"] as Vector3) / dt1
	owner.actions.motion.extra_velocity = _corr
	_skill_req = 0.0
	handler.drag_back.cancel("movimiento")
	handler.ball_turn.cancel("movimiento")
	owner.set_ball_ghost(true)
	stats["started"] += 1
	last = {"clip": String(id), "intent": String(new_intent), "residual": plan["residual"], "turn": plan["turn"], "touches": [],
		"foot": int(bts[last_i][1]) if not bts.is_empty() else 0, "frame": Engine.get_physics_frames()}
	return true

## Recepcion planificada por JsonReceive: el mismo movimiento con pelota, pero la pelota llega al primer toque desde lejos
## y, hasta ese toque, el cuerpo no es fantasma (la pelota no lo atraviesa).
func start_receive(plan: Dictionary) -> bool:
	var b: Ball = handler.ball()
	var toucher: Node = b.last_toucher if b != null else null
	if not _start(plan, &"receive"):
		return false
	_recv_toucher = toucher
	_recv_inc = plan.get("inc", Vector3.ZERO)
	_recv_part = plan.get("part", &"foot")
	_recv_t = float(plan.get("t_contact", 0.0))
	var post_t: float = float(plan.get("post_t", -1.0))
	# Corte antes del pase o golpeo del clip (-2: el nombre dice pase pero no hay toque registrado: 0.25 s tras el contacto).
	_recv_cut = post_t - 0.05 if post_t > 0.0 else (_recv_t + 0.25 if post_t < -1.5 else -1.0)
	_recv_cp = plan.get("cp", {})
	if String(PackLibrary.meta(clip).get("heading_mode", "")) != "turn":
		_turn_end = 0.0   # el cuerpo no gira con este clip (ActionMotion): la salida es el frente
	_recv_gap = INF
	_recv_traj = plan.get("traj", PackedVector3Array())
	_recv_frame0 = int(plan.get("frame", Engine.get_physics_frames()))
	# Toques: el primer contacto real (la parte del cuerpo del perfil, no el primer `ball_touches`) y los toques de pie
	# registrados despues, sin el pase o golpeo posterior (lo da el sistema de pase/tiro si hay orden).
	var touches: Array = [[_recv_t, int(plan.get("foot", 0)), plan["contact_local"], Vector2.ZERO]]
	for bt in PackLibrary.meta(clip).get("ball_touches", []):
		var tt: float = float(bt[0])
		if tt > _recv_t + 0.05 and (_recv_cut < 0.0 or tt < _recv_cut):
			touches.append(bt)
	_touches = touches
	_last = _touches.size() - 1
	handler.owner.set_ball_ghost(false)
	return true

## Paso de fisica durante el clip (PlayerActions.tick). clip_t: tiempo del clip ya avanzado.
func step(clip_t: float, dt: float) -> void:
	if not active:
		return
	var owner: Footballer = handler.owner
	var b: Ball = handler.ball()
	handler._sample_feet(dt)
	var receiving: bool = intent == &"receive"
	# Recibiendo, el cuerpo no es fantasma hasta el contacto (la pelota no lo atraviesa); con pecho, muslo o rodilla el punto
	# de contacto esta dentro de la capsula y pasa a fantasma un instante antes.
	# Dentro de la ventana de contacto el cuerpo es fantasma: la capsula (0.3 m de radio) es mas ancha que las piernas y
	# frenaba la pelota que iba al pie a un costado; antes de la ventana la pelota no cruza el cuerpo (JsonReceive._path_clear).
	owner.set_ball_ghost(not receiving or _next > 0 or clip_t >= float(_recv_cp.get("path_t0", _recv_t)))
	if b == null or b.is_held() or handler.ball_owned_by_other() or (b.last_toucher != owner and b.last_toucher != null and _next > 0):
		_abort("pelota perdida")
		return
	if receiving and _receive_step(clip_t, dt, b):
		return
	if receiving and _next == 0:
		# Primer contacto: cuando la pelota y la parte del cuerpo animada (posicion y rumbo reales del cuerpo + su trayectoria
		# en el clip) se encuentran dentro de la ventana; pasada la ventana sin encontrarse, el toque se pierde.
		if clip_t <= float(_touches[0][0]):
			owner.actions.motion.extra_velocity = _corr
		else:
			owner.actions.motion.extra_velocity = Vector3.ZERO
		var lp: Vector3 = JsonReceive.path_point(_recv_cp, clip_t)
		if lp != Vector3.INF:
			var f: Vector3 = owner.locomotion.forward()
			var r := Vector3(-f.z, 0.0, f.x)
			var part_w: Vector3 = KickModel.flat(owner.global_position) + f * lp.x + r * lp.z + Vector3(0.0, lp.y, 0.0)
			var reach: float = b.radius + float(JsonReceive.PART_REACH.get(_recv_part, 0.08))
			var gap: float = b.global_position.distance_to(part_w)
			_recv_gap = minf(_recv_gap, gap)
			if gap <= reach:
				_touch(0, b, true)
				if not active:
					return
				_next = 1
		elif clip_t > float(_recv_cp.get("path_t0", 0.0)) + 0.1:
			last["contact_gap"] = snappedf(_recv_gap, 0.01)
			handler.receive.stats["missed"] += 1
			_abort("la pelota no llego a la parte del cuerpo")
			return
		if _next == 0:
			_update_ik(clip_t, b)
			return
	# El ajuste de paso solo hasta el primer toque.
	if _next > 0 or clip_t >= float(_touches[0][0]):
		owner.actions.motion.extra_velocity = Vector3.ZERO
	# Toques cuyo instante ya paso (hasta el que deja la pelota para la conduccion normal).
	while _next <= _last and _next < _touches.size() and clip_t >= float(_touches[_next][0]):
		_touch(_next, b)
		if not active:
			return
		_next += 1
	_update_ik(clip_t, b)

## Recepcion en curso: la pelota desviada antes del toque la corta; los botones se leen (PlayerActions no deja pasar el
## paso normal de BallHandler): una orden de golpeo antes del toque es de primera (se corta la recepcion y golpea el
## planificador de siempre) y despues del toque corta la cola del clip para golpear ya. true si la recepcion termino.
func _receive_step(clip_t: float, dt: float, b: Ball) -> bool:
	var owner: Footballer = handler.owner
	if _recv_cut > 0.0 and clip_t >= _recv_cut:
		_end_early("golpeo tras el control" if handler._pending_action != &"" else "corte antes del golpeo del clip")
		return true
	if _next == 0 and b.last_toucher != _recv_toucher:
		_abort("pelota desviada")
		return true
	if _next == 0 and _recv_traj.size() > 1:
		# La pelota no va por donde se previo (desviada, frenada, patinando): se corta ya, a tiempo para el control fisico.
		var tp: float = float(Engine.get_physics_frames() - _recv_frame0) / float(Engine.physics_ticks_per_second)
		var v_pred: Vector3 = (JsonReceive._at(_recv_traj, tp + JsonReceive.TRAJ_STEP) - JsonReceive._at(_recv_traj, tp)) / JsonReceive.TRAJ_STEP
		if b.global_position.distance_to(JsonReceive._at(_recv_traj, tp)) > JsonReceive.TRAJ_DRIFT \
				or (b.linear_velocity - v_pred).length() > JsonReceive.TRAJ_DV:
			_abort("la pelota no va por donde se previo")
			return true
	var fr: InputFrame = owner.last_frame
	if fr != null:
		var sw: Vector3 = fr.move_world if fr.use_world else owner.ctx.screen_to_world(fr.move)
		handler._update_buttons(fr, sw.limit_length(1.0), dt)
	var charging: bool = handler._pass_active or handler._shoot_active or handler._through_active or handler._cross_active
	# Antes del contacto, una orden de golpeo es de primera; cargandola, solo sigue un clip con accion posterior (recibir y
	# luego pasar o tirar: el golpeo lo da el sistema de pase/tiro al soltar tras el contacto o en el corte del clip).
	if _next == 0 and (handler._pending_action != &"" or (charging and _recv_cut < 0.0)):
		_abort("golpeo de primera")
		return true
	if _next > 0 and handler._pending_action != &"":
		_end_early("golpeo tras el control")
		return true
	return false

## Lo que se desvio el cuerpo de la trayectoria prevista (choques): se suma a los puntos de toque.
func _drift(clip_t: float) -> Vector3:
	var owner: Footballer = handler.owner
	var f0: Vector3 = Locomotion.dir_from_yaw(_yaw0)
	var r0 := Vector3(-f0.z, 0.0, f0.x)
	var rr: Vector2 = owner.actions.motion.root_at(clip_t)
	var planned: Vector3 = _origin + f0 * rr.x + r0 * rr.y
	return KickModel.flat(owner.global_position) - planned

## Punto del mundo donde debe estar el centro de la pelota en el toque i (punta del pie mas el radio, hacia donde va el pie).
func _touch_point(i: int, drift: Vector3) -> Vector3:
	var f0: Vector3 = Locomotion.dir_from_yaw(_yaw0)
	var r0 := Vector3(-f0.z, 0.0, f0.x)
	var p: Vector3 = _touches[i][2]
	var vel: Vector2 = _touches[i][3]
	var lead: Vector3 = (f0 * vel.x + r0 * vel.y).normalized() * BALL_LEAD if vel.length() > 0.3 else Vector3.ZERO
	if intent == &"receive" and i == 0 and _recv_inc != Vector3.ZERO:
		lead = JsonReceive.contact_offset(_recv_inc, handler.ball())
	return _origin + drift + f0 * p.x + r0 * p.z + lead

func _touch(i: int, b: Ball, met: bool = false) -> void:
	var owner: Footballer = handler.owner
	var clip_t: float = float(_touches[i][0])
	var drift: Vector3 = _drift(owner.actions.motion.t)
	var here: Vector3 = _touch_point(i, drift)
	var bp: Vector3 = KickModel.flat(b.global_position)
	var d: float = bp.distance_to(here)
	(last["touches"] as Array).append(snappedf(d, 0.01))
	var receiving: bool = intent == &"receive"
	# Recibiendo, tambien la altura: el primer contacto a la altura de su parte del cuerpo; los toques de pie posteriores,
	# con la pelota ya abajo.
	var high: bool = false
	if receiving:
		var want_y: float = float((_touches[i][2] as Vector3).y) if i == 0 else 0.0
		high = absf(b.global_position.y - want_y) > 0.35 if i == 0 else b.global_position.y > 0.45
	if AnimTrace.enabled:
		var bad: bool = (d > MISS_DIST or high) and not met
		AnimTrace.event(owner, _trace_family(), &"JsonBallMove._touch", clip, "contact_failed" if bad else "completed",
			("toque %d: pelota a %.2f m del pie (limite %.2f m)%s" % [i, d, MISS_DIST, ", altura distinta" if high else ""]) if bad else "",
			{"context": "toque %d de %s" % [i, String(intent)], "frame_contact": int(round(clip_t * AnimTrace.FRAME_RATE)), "body_part": "foot",
			"foot": "R" if float(_touches[i][1]) > 0.0 else "L", "ball_pred_x": b.global_position.x, "ball_pred_y": b.global_position.y,
			"ball_pred_z": b.global_position.z, "contact_point_x": here.x, "contact_point_y": 0.0, "contact_point_z": here.z, "spatial_error_m": d,
			"tolerance_applied": MISS_DIST, "tolerance_reason": "MISS_DIST", "contact_validated": not bad, "physics_applied": not bad})
	if (d > MISS_DIST or high) and not met:
		_misses += 1
		stats["missed"] += 1
		if receiving:
			handler.receive.stats["missed"] += 1
			if i > 0:
				# La pelota no llega al toque siguiente del clip: se corta y el jugador va a por ella.
				_end_early("segundo contacto no llega")
				return
		if _misses >= 2 or i == 0:
			_abort("toque perdido")
		return
	_misses = 0
	if receiving and i == 0 and _recv_part != &"foot":
		# Pie en el aire, muslo, rodilla o pecho: la respuesta de esa parte del cuerpo, no un toque de pie.
		var rel_air: float = (b.linear_velocity - owner.velocity).length()
		var va: Vector3 = handler.receive.contact_velocity(Vector3.ZERO, b, _recv_part).limit_length(9.0)
		b.kick(va, Vector3.ZERO, owner)
		# Toque con el cuerpo (como el de BallHandler._shrug_resting_ball): sin este aviso era el unico impulso del jugador sin
		# evento de su BallHandler (test_shared_ball_mechanics lo vio en GitHub Actions #46 con una recepcion de la IA).
		handler.touched_ball.emit(&"body")
		_received(b, rel_air)
		return
	var target: Vector3
	var travel: float
	var stop: bool = false
	if i < _last:
		target = _touch_point(i + 1, drift)
		travel = maxf((float(_touches[i + 1][0]) - clip_t) / _speed, 0.06)
	else:
		# Ultimo toque: la pelota queda delante del rumbo de salida, donde el jugador la encuentra al terminar el clip (en el
		# toque orientado, al cortarlo: raiz, rumbo y velocidad del clip en ese instante).
		var f0: Vector3 = Locomotion.dir_from_yaw(_yaw0)
		var r0 := Vector3(-f0.z, 0.0, f0.x)
		var m: Dictionary = PackLibrary.meta(clip)
		var cut: bool = _end_t < _length - 0.01
		var rp: PackedVector2Array = m.get("root_path", PackedVector2Array())
		var re: Vector2 = ActionMotion._at(rp, _end_t) if cut and rp.size() >= 2 else _root_end
		var end_pos: Vector3 = _origin + drift + f0 * re.x + r0 * re.y
		var turn_at_end: float = ActionMotion.heading_rel(m.get("heading_path", PackedFloat32Array()), _end_t) if cut else _turn_end
		var exit_dir: Vector3 = Locomotion.dir_from_yaw(_yaw0 + turn_at_end)
		var desired: Vector3 = handler._desired_dir
		var oriented: bool = false
		var snap: float = JsonReceive.TURN_TOL if intent == &"receive" else (60.0 if intent == &"steer" else 35.0)
		if intent == &"steer" and desired.length_squared() > 0.01:
			# Toque orientado: la pelota se orienta hacia el joystick, menos cuanto mas rapido (60 grados al trote, 22 en
			# sprint): en carrera la curva se cierra toque a toque, como en UCS, y el jugador no se aparta de su pelota
			# (test_physical_dribble::test_diagonal_after_sprint_follows_the_ball: 35 grados con 60 en sprint).
			var lim: float = clampf(lerpf(60.0, STEER_SNAP_SPRINT, (handler.owner.locomotion.speed - 3.0) / 3.0), STEER_SNAP_SPRINT, 60.0)
			var dd: Vector3 = KickModel.flat(desired).normalized()
			var a_exit: float = Locomotion.yaw_from_dir(exit_dir)
			var a_des: float = Locomotion.yaw_from_dir(dd)
			var delta: float = wrapf(a_des - a_exit, -PI, PI)
			exit_dir = Locomotion.dir_from_yaw(a_exit + clampf(delta, -deg_to_rad(lim), deg_to_rad(lim)))
		elif desired.length_squared() > 0.01 and KickModel.angle_between_deg(exit_dir, desired) < snap:
			exit_dir = KickModel.flat(desired).normalized()
			oriented = intent == &"receive"
		var remain: float = maxf((_end_t - clip_t) / _speed, 0.0)
		if intent == &"kick_turn" or handler._pending_action != &"":
			# Giro para golpear: la pelota queda quieta delante del pie, lista para el golpeo que espera.
			stop = true
			target = end_pos + exit_dir * 0.5
		elif oriented:
			# Control orientado: la pelota sale hacia el joystick, un paso por delante de donde termina el clip.
			stop = true
			target = end_pos + exit_dir * (Tuning.player.settle_gap + 0.6)
		elif _v_out < 0.8 and not cut:
			stop = true
			target = end_pos + exit_dir * Tuning.player.settle_gap
		else:
			# Velocidad de salida: la del clip al terminar (al cortarlo, la de su raiz en ese instante).
			var v_end: float = _v_out
			if cut and rp.size() >= 2:
				v_end = maxf((ActionMotion._at(rp, _end_t + 0.05) - ActionMotion._at(rp, _end_t - 0.05)).length() / 0.1, 1.0)
			# Tras el toque orientado la pelota queda a la distancia de la conduccion normal un poco antes (0.25 s) que tras un
			# giro entero (0.35 s): en UCS va 0.5-1.0 m por delante al trote.
			var lead_t: float = 0.25 if intent == &"steer" else 0.35
			travel = remain + lead_t
			target = end_pos + exit_dir * (v_end * lead_t + handler.carry_gap(v_end, handler._carry_skill()))
	var to_t: Vector3 = target - bp
	var v: Vector3
	if stop:
		v = to_t.normalized() * Ball.roll_speed_to_stop(to_t.length()) if to_t.length() > 0.02 else Vector3.ZERO
	else:
		v = to_t.normalized() * Ball.roll_speed_for(to_t.length(), travel) if to_t.length() > 0.01 else Vector3.ZERO
	var received: bool = intent == &"receive" and i == 0
	var rel_in: float = KickModel.flat(b.linear_velocity - owner.velocity).length()
	if received:
		v = handler.receive.contact_velocity(v, b, &"foot")
	v = v.limit_length(9.0)
	b.kick(v, b.rolling_spin(v), owner)
	if received:
		_received(b, rel_in)
	var foot: int = 1 if int(_touches[i][1]) > 0 else 0
	stats["touches"] += 1
	handler.dribble_touch_count += 1
	handler.foot_touches += 1
	handler.last_touch_foot = foot
	handler.last_touch_foot_distance = d
	handler.last_touch_toe_distance = d
	handler.last_touch_mode = &"move"
	handler.touched_ball.emit(&"move")

## Primer contacto de la recepcion hecho: no se vuelve a controlar enseguida, el cuerpo ya no choca con la pelota y se avisa
## al partido (FIRST_TOUCH con el clip y la parte del cuerpo).
func _received(b: Ball, rel_in: float) -> void:
	var owner: Footballer = handler.owner
	handler.control_cooldown = 0.5
	handler.receive.stats["contact"] += 1
	if AnimTrace.enabled:
		AnimTrace.event(owner, &"receive", &"JsonBallMove._received", clip, "completed", "", {"context": "primer contacto", "body_part": String(_recv_part),
			"foot": "R" if int(_touches[0][1]) > 0 else "L", "ball_pred_x": b.global_position.x, "ball_pred_y": b.global_position.y,
			"ball_pred_z": b.global_position.z, "spatial_error_m": _recv_gap if is_finite(_recv_gap) else "", "contact_validated": true, "physics_applied": true})
	owner.set_ball_ghost(true)
	owner.ctx.emit_event(GameEvent.make(GameEvent.Type.FIRST_TOUCH, owner.actor_id, owner.team,
		{"absorb": handler.receive.last_contact.get("absorb", 0.0), "incoming_speed": rel_in, "clip": String(clip), "planned": true, "part": String(_recv_part)}))
	var foot: int = int(_touches[0][1])
	handler.last_touch_foot = 1 if foot > 0 else (0 if foot < 0 else -1)

## Pie al toque: la punta va hasta la pelota real (unos centimetros) en el tramo del toque.
func _update_ik(clip_t: float, b: Ball) -> void:
	var v: FootballerVisual = handler.owner.visual
	if v == null or v.touch_ik == null:
		return
	var idx: int = -1
	for i in range(maxi(_next - 1, 0), mini(_next + 1, _last + 1)):
		var tt: float = float(_touches[i][0])
		if clip_t >= tt - IK_LEAD and clip_t <= tt + IK_HOLD:
			idx = i
			break
	if idx < 0:
		if _ik_foot >= 0:
			v.touch_ik.set_target(_ik_foot, Vector3.ZERO, 0.0, 0.0)
			_ik_foot = -1
		return
	var foot: int = 1 if int(_touches[idx][1]) > 0 else 0
	var tt2: float = float(_touches[idx][0])
	var w: float = clampf(1.0 - (tt2 - clip_t) / IK_LEAD, 0.0, 1.0) if clip_t < tt2 else clampf(1.0 - (clip_t - tt2) / IK_HOLD, 0.0, 1.0)
	var bp: Vector3 = b.global_position
	var toe: Vector3 = handler.toe_world(foot)
	var vel: Vector2 = _touches[idx][3]
	var f0: Vector3 = Locomotion.dir_from_yaw(_yaw0)
	var push: Vector3 = (f0 * vel.x + Vector3(-f0.z, 0.0, f0.x) * vel.y)
	push = push.normalized() if push.length() > 0.3 else KickModel.flat(bp - toe).normalized()
	var want: Vector3 = bp - push * (b.radius + 0.03)
	if intent == &"receive" and idx == 0 and _recv_part != &"foot" and _recv_part != &"foot_air":
		return   # pecho, muslo o rodilla: sin IK del pie
	if intent == &"receive" and idx == 0 and _recv_inc != Vector3.ZERO:
		# Recepcion: el pie va delante de la pelota que llega (la para), no detras empujandola.
		want = bp - JsonReceive.contact_offset(_recv_inc, b).normalized() * (b.radius + 0.03)
	want.y = maxf(toe.y, 0.04)
	if toe != Vector3.ZERO and KickModel.flat(want - toe).length() > IK_MAX:
		w = 0.0
	v.touch_ik.set_target(foot, want, 0.0, w)
	_ik_foot = foot

## Fin del clip (PlayerActions): la conduccion normal sigue desde aqui.
func finish() -> void:
	if not active:
		return
	active = false
	stats["done"] += 1
	if AnimTrace.enabled:
		AnimTrace.event(handler.owner, _trace_family(), &"JsonBallMove.finish", clip, "completed", "", {"context": String(intent)})
	if intent == &"receive":
		handler.receive.ended(_next > 0)
	_remember()
	# Tras un toque orientado o un arranque, el toque orientado puede seguir enseguida (con la espera de 0.6 s de los giros, el
	# cambio de rumbo que llegaba justo despues de arrancar lo daba siempre el toque fisico); los giros grandes y el resto
	# esperan lo de siempre tras un arranque (encadenado, un giro de 90 grados apartaba al jugador 42 grados de su pelota:
	# test_physical_dribble::test_jog_turn_90_in_touches).
	_cooldown = maxf(_cooldown, STEER_COOLDOWN if intent == &"steer" else COOLDOWN)
	_steer_cd = maxf(_steer_cd, STEER_COOLDOWN if (intent == &"steer" or intent == &"start") else COOLDOWN)
	handler.touch_timer = 0.12
	_release_ik()

func _abort(reason: String) -> void:
	if not active:
		return
	active = false
	stats["aborted"] += 1
	last["aborted"] = reason
	if AnimTrace.enabled:
		AnimTrace.event(handler.owner, _trace_family(), &"JsonBallMove._abort", clip, "cancelled", reason, {"context": String(intent)})
	if intent == &"receive":
		handler.receive.ended(_next > 0)
	_remember()
	_cooldown = COOLDOWN
	_steer_cd = COOLDOWN
	_release_ik()
	# Sin pelota que llevar el clip no sigue: se corta con un fundido y vuelve la marcha (el jugador puede ir a por ella).
	# PlayerActions.stop corta raiz y pose y libera el lugar en el arbitro.
	var owner: Footballer = handler.owner
	owner.actions.motion.extra_velocity = Vector3.ZERO
	owner.actions.stop(reason)

## Fin antes de tiempo sin error (golpeo pedido tras el control): se suelta el clip y sigue el paso normal.
func _end_early(reason: String) -> void:
	finish()
	last["ended"] = reason
	handler.owner.actions.motion.extra_velocity = Vector3.ZERO
	handler.owner.actions.stop(reason)

func _remember() -> void:
	history.append(last)
	if history.size() > 20:
		history.pop_front()

## La accion se corto desde fuera (saque, gol, caida).
func cancel() -> void:
	if active:
		if AnimTrace.enabled:
			AnimTrace.event(handler.owner, _trace_family(), &"JsonBallMove.cancel", clip, "cancelled", "cortado desde fuera (saque, gol, caida)", {"context": String(intent)})
		active = false
		if intent == &"receive":
			handler.receive.ended(_next > 0)
		_cooldown = COOLDOWN
		_steer_cd = COOLDOWN
		_release_ik()

func _release_ik() -> void:
	var v: FootballerVisual = handler.owner.visual if handler.owner != null else null
	if v != null and v.touch_ik != null and _ik_foot >= 0:
		v.touch_ik.set_target(_ik_foot, Vector3.ZERO, 0.0, 0.0)
	_ik_foot = -1
