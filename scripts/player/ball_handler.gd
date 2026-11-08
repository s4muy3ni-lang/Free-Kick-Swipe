class_name BallHandler
extends RefCounted
## Interaccion del futbolista con la pelota. Todo ocurre mediante IMPULSOS en el instante del contacto:
## nunca se fija la posicion de la pelota ni se anula su velocidad.
##  - Conduccion: toques periodicos cuya fuerza depende de la velocidad, el giro y los atributos.
##  - Control de primer toque: absorbe parte de la energia de un balon que llega (con error).
##  - Pase y tiro: se calculan con PassAssist / ShotAssist; se ejecutan al soltar el boton y
##    se guardan en buffer 0.3 s si la pelota aun no esta a alcance.
##  - Disputa: robo probabilistico dependiente de orientacion, atributos y velocidad relativa.

signal kicked(action: StringName, result: KickModel.KickResult)
signal touched_ball(kind: StringName)

## Interruptor global (pruebas): false fuerza siempre la patada procedural antigua.
static var clip_kicks_enabled: bool = true
## Interruptor global (pruebas): false ignora los pies animados y conduce con la cadencia de la marcha.
static var foot_sync_enabled: bool = true
## Maximo de entradas del registro de patadas.
const KICK_LOG_MAX := 64
## Segundos que espera un pase o tiro pulsado hasta que algun pie llegue a la pelota antes de descartarse.
const PENDING_KICK_MAX := 0.5
## Con la pelota propia por delante fuera del alcance del pie, la orden de golpeo espera hasta este tiempo (s) MIENTRAS
## el jugador corre hacia ella acercandose (ajuste de la carrera); si deja de acercarse, se cancela con aviso.
const PENDING_APPROACH_MAX := 1.4
## Distancia (m) maxima a la pelota propia para ir a buscarla con un golpeo pedido.
const APPROACH_MAX_DIST := 4.0
## Velocidad (m/s) minima de acercamiento a la pelota para seguir esperando la orden de golpeo.
const APPROACH_MIN_CLOSING := 0.3
## Ultimos segundos antes del contacto con el pie de apoyo plantado: sin ajuste de paso y con el cuerpo a la velocidad
## que pide el propio clip (la que deja quieto en el suelo el pie de apoyo: clip_plant_velocity), asi no patina.
## Sin datos del pie de apoyo (cabezazos, voleas) el cuerpo se frena a KICK_PLANT_SPEED de su velocidad.
const KICK_PLANT_TIME := 0.10
const KICK_PLANT_SPEED := 0.4
## Altura maxima (m) de la punta del pie de apoyo para considerarlo plantado.
const PLANT_FOOT_MAX_Y := 0.06
## m/s que la velocidad de apoyo de un clip puede superar a la del cuerpo al empezar la patada.
const PLANT_SPEED_GAIN_MAX := 1.5
## Modo 4: margen de puntaje (m de residuo equivalentes) dentro del cual se elige al azar entre los clips de patada.
const JSON_KICK_VARIETY := 0.05
## Modo 4: coste (m de residuo equivalentes por m/s) de elegir un clip cuyo pie de apoyo retrocede a una velocidad distinta de la del
## jugador: el pie plantado patinaria. Mas alto que en el modo 1 porque hay clips de todas las velocidades (parado a sprint).
const JSON_PLANT_MISMATCH_COST := 0.28
## Modo 4: coste (m de residuo por m de ajuste de zancada): con tantos clips se prefiere el que apenas obliga a mover el cuerpo
## (y el pie del lado de la pelota al del lado contrario).
const JSON_STEP_COST := 0.35
## Modo 4: golpeos evaluados a fondo por planificacion (los de contacto mas cercano a la pelota prevista).
const JSON_KICK_EVAL := 24
## Modo 4: con el destino a TURN_KICK_MIN grados o mas del frente, el golpeo es un clip que gira el cuerpo y patea (de 45 a
## 180 grados, de taco, de rabona): el jugador no patea de espaldas. TURN_KICK_TOL: diferencia admitida entre hacia donde
## sale la pelota en el clip y el destino; TURN_KICK_MAX_LATENCY: segundos maximos hasta el contacto (el giro se ve entero).
## Sin golpeo girando que llegue y con el destino a TURN_FIRST_MIN grados o mas, primero un giro con pelota (clip) y despues
## el golpeo (la orden espera).
const TURN_KICK_MIN := 50.0
const TURN_KICK_TOL := 40.0
const TURN_FIRST_MIN := 100.0
const TURN_KICK_MAX_LATENCY := 0.6
## Con un rival a menos de TURN_KICK_PRESS_DIST m no hay tiempo para un giro largo: TURN_KICK_PRESSED_LATENCY s como mucho.
const TURN_KICK_PRESS_DIST := 2.2
const TURN_KICK_PRESSED_LATENCY := 0.4
## Latencia extra (s) de los golpeos del mocap de futbol (modo 2), ver clip_timing.
const MOCAP_EXTRA_LATENCY := 0.08
## Coste (m de residuo equivalentes por m/s) de elegir un clip cuya velocidad de apoyo no encaja con la del jugador.
const PLANT_MISMATCH_COST := 0.06
## Velocidad maxima del ajuste de paso (m/s) durante el balanceo, parado; a la carrera la ultima zancada puede
## alargarse mas (KICK_NUDGE_PER_MS por cada m/s del cuerpo).
const KICK_NUDGE_MAX := 3.2
const KICK_NUDGE_PER_MS := 0.4
## Espera maxima de una orden de golpeo con la pelota viniendo hacia el jugador (pase o tiro de primera).
const PENDING_FIRST_TIME_MAX := 1.4
## Toque de arrancada: con SPRINT, la colocacion crece hasta ACCEL_TOUCH_MAX m segun la fraccion de la velocidad punta
## que falta (x ACCEL_TOUCH_PER_FRACTION, saturado en 1).
const ACCEL_TOUCH_PER_FRACTION := 2.5
const ACCEL_TOUCH_MAX := 0.3
## Fraccion de la velocidad punta que falta por encima de la cual, con SPRINT, manda el toque de arrancada (ni relevo a
## los toques de clip ni toques de clip).
const ACCEL_TOUCH_KEEP_FRACTION := 0.2
## Segundos minimos entre dos toques de media vuelta seguidos (el pie no puede tocar la pelota cada fotograma).
const REVERSAL_TOUCH_GAP := 0.12
## Pelota apoyada en el cuerpo: velocidad maxima (m/s) y segundos quieta antes de quitarsela con la cabeza / el hombro.
const RESTING_BALL_SPEED := 0.6
## Ritmo de giro del cuerpo (fraccion) mientras la pelota aun no va hacia el rumbo nuevo (ver carry_turn_scale).
const BALL_TURN_SCALE := 0.5
const RESTING_BALL_SECONDS := 0.4

var owner: Footballer
var rng := RandomNumberGenerator.new()

var _redirect_hold: float = 0.0
## Segundos que el cuerpo conserva su orientacion tras un control lateral (no gira hacia el joystick todavia).
var _lateral_hold: float = 0.0
## Orientacion congelada durante el control lateral y espera antes de poder encadenar otro.
var _lateral_face: Vector3 = Vector3.ZERO
var _lateral_cooldown: float = 0.0
## Direccion a la que mira el cuerpo mientras conduce (control lateral / proteccion). Cero = libre.
var _carry_face: Vector3 = Vector3.ZERO
## Modo del ultimo toque de conduccion (settle, lateral, redirect, carry): lo usa la animacion.
var last_touch_mode: StringName = &""
## Paso de fisica del ultimo pase o tiro ejecutado: el jugador no vuelve a tocar su propio envio enseguida. Se cuenta en
## tiempo de simulacion (con el reloj del sistema, una simulacion lenta o acelerada cambiaba la regla).
var _last_kick_frame: int = -100000
## Segundos tras su propio pase o tiro en que el envio no es suyo: ni lo toca ni lo persigue como conduccion.
const OWN_KICK_SECONDS := 0.7
## Segundos tras su propio toque en que el jugador no hace un control de primer toque sobre esa pelota. Antes eran
## 450 ms de reloj del sistema: las pruebas (que simulan mas rapido que el tiempo real) lo midieron como ~0.9 s de juego
## (54 pasos con render) y el movil como 0.45 s. Se fija el valor con el que se midio la conduccion.
const OWN_TOUCH_NO_CONTROL_SECONDS := 0.9
var _kick_start_touch: int = 0
var _kick_start_ball_v: Vector3 = Vector3.ZERO
## Velocidad del cuerpo y direccion deseada al empezar la patada con clip: durante el balanceo el jugador ya se
## comprometio (el joystick deja de girarlo/acelerarlo) y en los ultimos KICK_PLANT_TIME el pie de apoyo se planta.
var _kick_v0: Vector3 = Vector3.ZERO
var _resting_time: float = 0.0
## Segundos que la pelota de una media vuelta aun puede atravesar el cuerpo (ver toque redirect).
var _pass_ghost: float = 0.0
const REVERSAL_GHOST_SECONDS := 0.3
## Segundos que la pelota recien golpeada (pase, tiro, centro) atraviesa el cuerpo de quien la golpeo. Con el ajuste de
## zancada el cuerpo queda a veces encima de la pelota en el contacto: al volver a chocar con ella en el paso siguiente la
## frenaba y desviaba (medido: tiro cruzado de 18.5 m/s que salia a 4.5 m/s, 75 grados a un lado).
const KICK_GHOST_SECONDS := 0.15
## Distancia (m) hasta la que la pelota que se conduce atraviesa el cuerpo de quien la conduce.
const DRIBBLE_GHOST_RANGE := 1.2
var kick_desired_dir: Vector3 = Vector3.ZERO
var kick_desired_mag: float = 0.0
var touch_timer: float = 0.0
var lockout: float = 0.0
var control_cooldown: float = 0.0
var dribble_touch_count: int = 0
var last_result: KickModel.KickResult = null

var _pass_active: bool = false
var _pass_time: float = 0.0
var _shoot_active: bool = false
var _shoot_time: float = 0.0
var _through_active: bool = false
var _through_time: float = 0.0
var _cross_active: bool = false
var _cross_time: float = 0.0
var _pending_action: StringName = &""
var _pending_charge: float = 0.0
var _pending_lob: bool = false
var _pending_curl: float = 0.0
## Efecto (chanfle) del golpeo en curso: -1..1, positivo = la pelota se curva a la derecha del tiro. Lo marca el gesto
## del joystick entre pulsar y soltar el boton (ver _curl_from).
var _kick_curl: float = 0.0
var shot_curl: float = 0.0
var _aim_press: Vector3 = Vector3.ZERO
var _pending_stick: Vector3 = Vector3.ZERO
var _pending_age: float = 0.0
## Patada en curso: el impulso se aplica en el instante de contacto de la animacion.
var _kick_action: StringName = &""
## Testigo del arbitro del golpeo con clip en curso (0 = ninguno).
var _kick_token: int = 0
var _kick_timer: float = 0.0
var _kick_stick: Vector3 = Vector3.ZERO
var _kick_charge: float = 0.0
var _kick_lob: bool = false
## Patada con clip del pack en curso: {clip, speed, offset, latency, contact, distance (al iniciar)}. Vacio = patada procedural.
var _kick_clip: Dictionary = {}
## Golpeo girando en curso (modo 4): {clip, yaw0, start_at, speed, latency}. El cuerpo sigue la raiz y el rumbo del clip.
var _kick_turn: Dictionary = {}
## Direccion del golpeo pedido que necesita girar antes (modo 4, ver TURN_FIRST_MIN); cero si no.
var _kick_turn_dir: Vector3 = Vector3.ZERO

## Contadores y registro de patadas con animacion (diagnostico reproducible; ver kick_log).
## started: balanceos iniciados; contact: golpeos validos; missed: balanceos que no alcanzaron la pelota;
## out_of_reach: pulsaciones descartadas sin iniciar el balanceo por no haber pie que llegara.
var kick_stats := {"started": 0, "contact": 0, "missed": 0, "out_of_reach": 0}
var kick_log: Array[Dictionary] = []
var last_foot_distance: float = -1.0
## Distancia delante del jugador a la que se coloco la pelota en el ultimo toque de conduccion (m).
var _planned_gap: float = 0.0
var _kick_event_info: Dictionary = {}

## Ultima direccion deseada del jugador (mundo): sirve para predecir hacia donde girara durante el balanceo.
var _desired_dir: Vector3 = Vector3.ZERO

## Progreso de carga actual (0..1) para el HUD.
var pass_charge: float = 0.0
var shot_charge: float = 0.0
var through_charge: float = 0.0
var cross_charge: float = 0.0

## Modo 4 (Json): giros con pelota, vuelta atras, regates y frenadas con los clips JSON y sus toques (JsonBallMove).
var json_move: JsonBallMove = null
## Modo 4 (Json): recepcion de una pelota que llega con un clip cuyo pie la toca en su instante de toque (JsonReceive).
var receive: JsonReceive = null
## Vuelta atras pisando la pelota (DragBack): regate con el boton REGATE y el joystick hacia atras.
var drag_back: DragBack = null
## Giro con toques (joystick hacia atras conduciendo, estilo Dream League Soccer); ver BallTurn.
var ball_turn: BallTurn = null

func _init(o: Footballer) -> void:
	owner = o
	rng.randomize()
	drag_back = DragBack.new(self)
	ball_turn = BallTurn.new(self)
	json_move = JsonBallMove.new(self)
	receive = JsonReceive.new(self)

## Rompe el ciclo de referencias entre el BallHandler y sus submodulos (todos RefCounted y cada uno con `handler`
## apuntando de vuelta): sin esto ninguno se libera nunca y cada futbolista deja objetos vivos en ObjectDB al salir.
## Lo llama Footballer al liberarse (NOTIFICATION_PREDELETE); no cambia nada del juego mientras el jugador existe.
func dispose() -> void:
	for sub: RefCounted in [drag_back, ball_turn, json_move, receive]:
		if sub != null:
			sub.set(&"handler", null)
	drag_back = null
	ball_turn = null
	json_move = null
	receive = null
	# Lambdas conectadas a las senales del propio manejador (kicked, touched_ball...) que lo capturan forman otro ciclo.
	for sig in get_signal_list():
		for conn in get_signal_connection_list(sig["name"]):
			disconnect(sig["name"], conn["callable"])

func ball() -> Ball:
	return owner.ctx.ball if owner.ctx != null else null

func ball_offset() -> Vector3:
	var b: Ball = ball()
	return KickModel.flat(b.global_position - owner.global_position) if b != null else Vector3.ZERO

func ball_distance() -> float:
	return ball_offset().length()

## Radio (m) dentro del cual se considera que el jugador lleva la pelota. Crece con la velocidad: a sprint la pelota
## va mas adelantada y seguiria siendo suya.
func possession_radius() -> float:
	return maxf(Tuning.player.possession_radius, touch_reach() * 1.3)

func has_possession() -> bool:
	var b: Ball = ball()
	if b == null or b.is_held():
		return false
	# Pelota al pie Y no es de otro (MatchContext.possessor arbitra cuando dos estan cerca). No se exige ser ya el
	# poseedor arbitrado: eso exige un toque previo y cortaba la conduccion entre toques (zigzag: 8 de 16 toques con el
	# pie frente a 16 de 18).
	if ball_distance() > possession_radius() or b.global_position.y >= 0.6:
		return false
	if owner.ctx != null:
		owner.ctx.update_possession()
		return owner.ctx.possessor == null or owner.ctx.possessor == owner
	return true

## Conduce aunque el ultimo toque largo la haya alejado un poco: fue el ultimo en tocarla, no la pateo (pase/tiro) y
## sigue cerca. Sirve para no cambiar de marcha (ni de tope de velocidad) entre dos toques de una conduccion larga.
func is_dribbling() -> bool:
	if has_possession():
		return true
	var b: Ball = ball()
	return b != null and not b.is_held() and b.last_toucher == owner and ball_distance() < 2.3 \
		and seconds_since_kick() > OWN_KICK_SECONDS and b.global_position.y < 0.6

## Segundos de simulacion desde el ultimo pase o tiro de este jugador.
func seconds_since_kick() -> float:
	return float(Engine.get_physics_frames() - _last_kick_frame) / float(Engine.physics_ticks_per_second)

## Segundos hasta que una pelota que se ACERCA pase a menos de radius del jugador (INF si no viene hacia el, va alta o
## es de otro). Prediccion lineal en el plano: alcanza para decidir si una orden espera el golpeo de primera.
func incoming_ball_eta(radius: float = 2.5) -> float:
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 1.2 or ball_owned_by_other():
		return INF
	var rel := Vector2(b.global_position.x - owner.global_position.x, b.global_position.z - owner.global_position.z)
	var v := Vector2(b.linear_velocity.x, b.linear_velocity.z)
	var vv: float = v.length_squared()
	if vv < 1.0 or rel.dot(v) >= 0.0:
		return INF
	if not _ball_rolling(b):
		var t: float = -rel.dot(v) / vv
		if (rel + v * t).length() > radius:
			return INF
		return t
	# Rodando: recorre el camino recto frenando (Ball.roll_*); el punto mas cercano es donde pasa junto al jugador o
	# donde se detiene antes.
	var sp: float = sqrt(vv)
	var d_c: float = minf(-rel.dot(v) / sp, Ball.roll_distance(sp, Ball.roll_stop_time(sp)) - 0.01)
	if (rel + v / sp * d_c).length() > radius:
		return INF
	return Ball.roll_time(sp, maxf(d_c, 0.0))

## La pelota va rodando por el piso (no en el aire ni botando): su avance sigue el modelo de rodadura de Ball.
func _ball_rolling(b: Ball) -> bool:
	return b.global_position.y < b.radius + 0.06 and absf(b.linear_velocity.y) < 0.6

## Desplazamiento horizontal de la pelota en t segundos: rodando, con la rodadura de Ball; en el aire, recto.
func ball_travel(b: Ball, t: float) -> Vector3:
	var hv := Vector3(b.linear_velocity.x, 0.0, b.linear_velocity.z)
	var hs: float = hv.length()
	if hs < 0.01 or not _ball_rolling(b):
		return hv * t
	return hv / hs * Ball.roll_distance(hs, t)

## Punto (en el suelo) de la trayectoria de la pelota que viene mas cercano al jugador: donde preparar el golpeo de primera.
func incoming_ball_point() -> Vector3:
	var b: Ball = ball()
	var eta: float = incoming_ball_eta()
	if b == null or eta == INF:
		return owner.global_position
	var p: Vector3 = b.global_position + ball_travel(b, eta)
	return Vector3(p.x, 0.0, p.z)

## Pelota suelta que el jugador de la persona va a buscar solo (ver Footballer): distancia maxima (m) al punto donde la
## alcanza, velocidad maxima (m/s) de la pelota (un tiro o un pase fuerte no se persigue) y altura maxima (m).
const LOOSE_CHASE_RANGE := 9.0
const LOOSE_CHASE_MAX_BALL_SPEED := 9.0
const LOOSE_CHASE_MAX_Y := 1.6

## Punto (en el suelo) donde el jugador alcanza una pelota suelta: el primero de su recorrido (rodadura de Ball) al que
## llega corriendo. Vector3.INF si no hay pelota suelta que buscar: alguien la lleva, es un pase a un companero, va muy
## fuerte o alta, es balon parado, o es su propia conduccion (la sigue la conduccion).
func loose_ball_chase() -> Vector3:
	var b: Ball = ball()
	if b == null or b.is_held() or owner.ctx == null or owner.ctx.dead_ball or owner.ctx.ball_locked_for(owner):
		return Vector3.INF
	if b.global_position.y > LOOSE_CHASE_MAX_Y or KickModel.flat(b.linear_velocity).length() > LOOSE_CHASE_MAX_BALL_SPEED:
		return Vector3.INF
	if not owner.ctx.ball_is_loose() or (b.last_toucher == owner and is_dribbling()) or owner.has_incoming_pass():
		return Vector3.INF
	for m in owner.ctx.teammates_of(owner):
		if m != owner and m.has_incoming_pass():
			return Vector3.INF
	var run: float = owner.locomotion.max_sprint_speed()
	var me := Vector3(owner.global_position.x, 0.0, owner.global_position.z)
	var p := Vector3.ZERO
	for i in 51:
		var t: float = 0.05 * float(i)
		var bp: Vector3 = b.global_position + ball_travel(b, t)
		p = Vector3(bp.x, 0.0, bp.z)
		if me.distance_to(p) <= run * maxf(t - 0.2, 0.0) + 0.4:
			break
	return p if me.distance_to(p) <= LOOSE_CHASE_RANGE else Vector3.INF

## Hay una orden de pase/tiro esperando una pelota que llega (golpeo de primera, sin control previo).
func is_waiting_first_time() -> bool:
	return _pending_action != &"" and _pending_age <= PENDING_FIRST_TIME_MAX and incoming_ball_eta() < PENDING_FIRST_TIME_MAX

## La pelota es de otro jugador (la conduce o la acaba de controlar): no se la puede conducir ni controlar, solo disputar.
## Un companero que la esta conduciendo (aunque el ultimo toque la haya alejado un poco) tampoco se la quita: medido,
## el companero que iba a su puesto chocaba con el portador, tocaba la pelota y se la quedaba.
func ball_owned_by_other() -> bool:
	if owner.ctx == null:
		return false
	var b: Ball = ball()
	var lt: Footballer = b.last_toucher as Footballer if b != null else null
	if lt != null and lt != owner and lt.team == owner.team and is_instance_valid(lt) and lt.ball_handler.is_dribbling():
		return true
	owner.ctx.update_possession()
	var p: Footballer = owner.ctx.possessor
	if p == null or p == owner:
		return false
	# Un toque largo (la pelota lejos de su dueno) si se puede cortar.
	return Vector2(p.global_position.x - ball().global_position.x, p.global_position.z - ball().global_position.z).length() < 1.05

## El equipo del jugador controla la pelota: esta cerca Y fue tocada por ultima vez por su equipo.
## Una pelota suelta o ultimo tocada por el rival no cuenta (se puede seguir presionando).
func controls_ball() -> bool:
	var b: Ball = ball()
	return has_possession() and b != null and b.last_touch_team == owner.team

func can_reach(reach: float) -> bool:
	var b: Ball = ball()
	return b != null and not b.is_held() and ball_distance() <= reach and b.global_position.y < 0.65

## Alcance efectivo de un toque: el jugador estira mas la pierna a mayor velocidad.
## Velocidad (m/s) maxima con la pelota al pie: algo menos que el sprint, y menos con peor conduccion (Footballer la
## aplica mientras la pelota esta dentro del radio de posesion).
func dribble_speed_cap() -> float:
	return owner.locomotion.max_sprint_speed() * lerpf(0.86, 0.97, owner.attributes.norm("ball_carrying"))

func touch_reach() -> float:
	var t: PlayerTuning = Tuning.player
	return t.touch_reach + 0.22 * _sprint_ratio()

func _sprint_ratio() -> float:
	var t: PlayerTuning = Tuning.player
	return clampf((owner.locomotion.speed - t.jog_speed) / maxf(t.sprint_speed - t.jog_speed, 0.1), 0.0, 1.0)

func assist_pass_level() -> float:
	return owner.assist_override_pass if owner.assist_override_pass >= 0.0 else Tuning.assist.pass_assist

func assist_shot_level() -> float:
	return owner.assist_override_shot if owner.assist_override_shot >= 0.0 else Tuning.assist.shot_assist

## Paso de simulacion. stick_world: direccion del joystick en el mundo; desired_dir: direccion deseada final.
func update(frame: InputFrame, stick_world: Vector3, stick_mag: float, desired_dir: Vector3, dt: float) -> void:
	lockout = maxf(lockout - dt, 0.0)
	touch_timer = maxf(touch_timer - dt, 0.0)
	control_cooldown = maxf(control_cooldown - dt, 0.0)
	_redirect_hold = maxf(_redirect_hold - dt, 0.0)
	_pass_ghost = maxf(_pass_ghost - dt, 0.0)
	# El cuerpo de quien conduce no choca con su propia pelota: los toques los dan los pies. Con la pelota pegada (0.25 m
	# del centro, dentro del radio de la capsula + la pelota) el cuerpo la frenaba en cada curva y se iba quedando atras
	# hasta perderla (medido: curva de 10 s, pelota cerca solo el 73 % del tiempo). Los demas jugadores si la bloquean.
	owner.set_ball_ghost(_kick_action != &"" or _pass_ghost > 0.0 or (is_dribbling() and ball_distance() < DRIBBLE_GHOST_RANGE))
	_desired_dir = desired_dir
	_sample_feet(dt)
	_json_touch_ik_step(dt)
	_update_buttons(frame, stick_world, dt)
	if _kick_action != &"":
		drag_back.cancel("golpeo")
		ball_turn.cancel("golpeo")
		_kick_timer -= dt
		var toe_before: Vector3 = _contact_toe_now()
		if _kick_timer <= 0.0 and _ball_still_arriving(dt, toe_before):
			# Pelota que llega (golpeo de primera): el impulso espera a que llegue de verdad al pie (sin esto el pie la
			# golpeaba a 0.26 m, en el aire, con la pelota a 6-7 m/s: test_live_kicks).
			_steer_clip_kick()
			_json_kick_ik()
		elif _kick_timer <= 0.0:
			_finish_kick()
		elif not _kick_clip.is_empty():
			_steer_clip_kick()
			_json_kick_ik()
		if _kick_action != &"":
			_contact_prev_toe = toe_before
		return
	if _pending_action != &"":
		_pending_age += dt
		if _try_execute_pending():
			return
		# Pase o tiro de primera: con la pelota viniendo hacia el jugador, la orden espera a que llegue (hasta
		# PENDING_FIRST_TIME_MAX) en vez de caducar a los PENDING_KICK_MAX.
		var waiting_first_time: bool = is_waiting_first_time()
		# Corriendo hacia la pelota propia que quedo por delante (kick_approach_steer): la orden sigue en pie mientras
		# el jugador se acerca de verdad, hasta PENDING_APPROACH_MAX.
		var approaching: bool = _pending_age <= PENDING_APPROACH_MAX and is_approaching_for_kick()
		# Giro con la pelota para golpear (JsonBallMove.turn_for_kick, destino detras): la orden espera a que termine el giro
		# y cuenta su tiempo desde ahi (el clip dura mas que PENDING_KICK_MAX y la orden se perdia: medido, tiros a 135 y
		# 180 grados y pase a 180 al trote sin golpeo tras girar).
		var turning_for_kick: bool = json_move != null and json_move.active and json_move.intent == &"kick_turn"
		if turning_for_kick:
			_pending_age = 0.0
		if _pending_age > PENDING_KICK_MAX and not waiting_first_time and not approaching and not turning_for_kick:
			if uses_clip_kicks():
				_log_kick(_pending_action, &"out_of_reach", {"stage": "pending"})
				kick_stats["out_of_reach"] += 1
				owner.ctx.emit_event(GameEvent.make(GameEvent.Type.KICK_WHIFF, owner.actor_id, owner.team, {"action": String(_pending_action), "reason": "out_of_reach"}))
			_pending_action = &""
		elif waiting_first_time:
			return   # sin control previo: el golpeo sera de primera
	if _shrug_resting_ball():
		return
	if lockout > 0.0 or owner.ctx.ball_locked_for(owner) or ball_owned_by_other():
		drag_back.cancel("bloqueo")
		ball_turn.cancel("bloqueo")
		return
	if PackLibrary.json_mode() and json_move.consider(desired_dir, stick_mag, dt):
		return
	Prof.begin(&"recepcion (plan del clip)")
	var receiving: bool = PackLibrary.json_mode() and receive.consider(desired_dir, stick_mag, dt)
	Prof.end(&"recepcion (plan del clip)")
	if receiving:
		return
	if drag_back.update(desired_dir, stick_mag, dt):
		return
	if ball_turn.update(desired_dir, stick_mag, dt):
		return
	if _try_first_touch(desired_dir):
		return
	if _clip_touch_update(desired_dir, stick_mag):
		return
	_try_dribble_touch(desired_dir, stick_mag)

# --- Botones ---------------------------------------------------------------

func _update_buttons(frame: InputFrame, stick_world: Vector3, dt: float) -> void:
	var bt: BallTuning = Tuning.ball
	# Un solo boton de golpeo a la vez: el primero que se pulsa manda hasta soltarse.
	var busy: bool = _pass_active or _shoot_active or _through_active or _cross_active
	if frame.pass_pressed and not busy:
		_pass_active = true
		_pass_time = 0.0
	if _pass_active:
		if frame.pass_held:
			_pass_time += dt
		pass_charge = clampf(_pass_time / 0.8, 0.0, 1.0)
		if frame.pass_released or not frame.pass_held:
			_queue(&"pass", pass_charge, frame.lob_held, stick_world)
			_pass_active = false
			pass_charge = 0.0
	if frame.shoot_pressed and not busy:
		_shoot_active = true
		_shoot_time = 0.0
		_aim_press = KickModel.flat(stick_world)
	if _shoot_active:
		if frame.shoot_held:
			_shoot_time += dt
		shot_charge = clampf(_shoot_time / bt.shot_charge_time, 0.0, 1.0)
		if frame.shoot_released or not frame.shoot_held:
			var curl: float = curl_from(_aim_press, stick_world)
			# Con chanfle, el tiro va hacia donde se apunto al pulsar; el giro posterior del joystick es el efecto.
			_queue(&"shot", shot_charge, frame.lob_held, _aim_press if curl != 0.0 else stick_world, curl)
			_shoot_active = false
			shot_charge = 0.0
	if frame.through_pressed and not busy:
		_through_active = true
		_through_time = 0.0
	if _through_active:
		if frame.through_held:
			_through_time += dt
		through_charge = clampf(_through_time / 0.8, 0.0, 1.0)
		if frame.through_released or not frame.through_held:
			_queue(&"through", through_charge, frame.lob_held, stick_world)
			_through_active = false
			through_charge = 0.0
	if frame.cross_pressed and not busy:
		_cross_active = true
		_cross_time = 0.0
		_aim_press = KickModel.flat(stick_world)
	if _cross_active:
		if frame.cross_held:
			_cross_time += dt
		cross_charge = clampf(_cross_time / 0.8, 0.0, 1.0)
		if frame.cross_released or not frame.cross_held:
			var ccurl: float = curl_from(_aim_press, stick_world)
			_queue(&"cross", cross_charge, frame.lob_held, _aim_press if ccurl != 0.0 else stick_world, ccurl)
			_cross_active = false
			cross_charge = 0.0

## Efecto pedido con el joystick: angulo (con signo) entre la direccion al pulsar y al soltar. Un giro de 15-60 grados
## a la derecha del tiro curva la pelota a la derecha (y a la izquierda al reves). Menos de 15 grados: sin efecto extra.
static func curl_from(at_press: Vector3, at_release: Vector3) -> float:
	if at_press.length() < 0.3 or at_release.length() < 0.3:
		return 0.0
	# signed_angle_deg es positivo hacia la izquierda (antihorario visto desde arriba): la derecha es negativa.
	var ang: float = -KickModel.signed_angle_deg(at_press, at_release)
	if absf(ang) < 15.0:
		return 0.0
	return clampf(ang / 60.0, -1.0, 1.0)

func _queue(action: StringName, charge: float, lob: bool, stick_world: Vector3, curl: float = 0.0) -> void:
	_pending_curl = curl
	_pending_action = action
	_pending_charge = charge
	_pending_lob = lob
	_pending_stick = stick_world
	_pending_age = 0.0

func _try_execute_pending() -> bool:
	if lockout > 0.0 or owner.ctx.ball_locked_for(owner) or ball_owned_by_other():
		return false
	if uses_clip_kicks():
		var plan: Dictionary = plan_clip_kick(_pending_action, _pending_charge, _pending_lob)
		if plan.is_empty() and not _trace_kick.is_empty():
			AnimTrace.commit(_trace_kick, &"", {}, "rejected", "ningun clip llega a la pelota")
		if plan.is_empty():
			# Modo 4, destino detras: giro con la pelota (clip) y la orden sigue pendiente para despues del giro.
			if _kick_turn_dir != Vector3.ZERO and json_move.turn_for_kick(_kick_turn_dir):
				_kick_turn_dir = Vector3.ZERO
				_pending_age = 0.0
				return true
			return false   # ningun pie llegaria a la pelota: se espera (buffer) o se descarta
		var act: StringName = _pending_action
		var started: bool = _start_clip_kick(act, plan, _pending_stick, _pending_charge, _pending_lob)
		if not _trace_kick.is_empty():
			var ct: Dictionary = plan["contact"]
			var tbp: Vector3 = foot_contact_world(ct, owner.global_position, owner.locomotion.yaw)
			AnimTrace.commit(_trace_kick, plan["clip"], {"frame_start": int(round(float(plan["offset"]) * AnimTrace.FRAME_RATE)),
				"frame_contact": int(round(float(ct["time"]) * AnimTrace.FRAME_RATE)), "spatial_error_m": float(plan["distance"]),
				"root_correction_m": (plan["adjust"] as Vector3).length()}, "accepted" if started else "rejected",
				"" if started else "arbitro: " + (owner.arbiter.log.back() if owner.arbiter != null and not owner.arbiter.log.is_empty() else ""))
			_trace_kick = {}
		if not started:
			return false   # el arbitro no da el control ahora: la orden sigue pendiente
		_pending_action = &""
		_kick_curl = _pending_curl
		return true
	if not can_reach(Tuning.player.touch_reach + 0.3):
		return false
	var action: StringName = _pending_action
	_pending_action = &""
	_kick_curl = _pending_curl
	request_kick(action, _pending_stick, _pending_charge, _pending_lob)
	return true

## Segundos entre el inicio de la patada y el golpeo (la animacion y el impulso comparten este instante).
func contact_delay(action: StringName, charge: float) -> float:
	return 0.12 + 0.06 * charge if action == &"shot" else 0.10

## Comienza una patada: arranca la animacion y programa el impulso para el instante de contacto.
func request_kick(action: StringName, stick_world: Vector3, charge: float, lob: bool) -> void:
	if _kick_action != &"":
		return
	_kick_action = action
	_kick_stick = stick_world
	_kick_charge = charge
	_kick_lob = lob
	_kick_timer = contact_delay(action, charge)
	lockout = _kick_timer + 0.4
	touch_timer = lockout
	var side: int = 1 if ball_offset().dot(owner.locomotion.right()) >= 0.0 else -1
	if owner.visual != null:
		var power: float = charge if action == &"shot" else 0.35 + 0.5 * charge
		if action == &"cross":
			power = 0.6 + 0.4 * charge
		owner.visual.start_kick(_kick_timer, power, side)

func is_kick_in_progress() -> bool:
	return _kick_action != &""

# --- Patada con clip del pack: el golpeo ocurre cuando el PIE llega a la pelota --------------------

## true si este futbolista patea con los clips del pack (visual con libreria y clips de patada en el sitio).
func uses_clip_kicks() -> bool:
	var v: FootballerVisual = owner.visual
	return clip_kicks_enabled and v != null and v.uses_pack and not v.is_placeholder and not AnimationCatalog.kick_candidates(&"pass").is_empty()

## Posicion MUNDIAL de la punta del pie en el golpeo de un clip, para un jugador en pos con orientacion yaw.
## contact.pos es (adelante, arriba, derecha) en metros, medido sobre el esqueleto retargeteado del propio clip.
static func foot_contact_world(contact: Dictionary, pos: Vector3, yaw: float) -> Vector3:
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var r := Vector3(-f.z, 0.0, f.x)
	var c: Vector3 = contact["pos"]
	return Vector3(pos.x, 0.0, pos.z) + f * c.x + r * c.z + Vector3.UP * c.y

## Velocidad de reproduccion, punto de inicio y latencia real para que el clip llegue a su contacto en kick_latency.
## La latencia se cuantiza a pasos de fisica (el impulso solo puede ocurrir en un paso): el clip llega a la pose de
## contacto exactamente en el paso del impulso. Como el AnimationTree avanza en _process (despues de la fisica), esa pose
## es la imagen que se dibuja justo ANTES de que la pelota salga, y en la siguiente el pie sigue de largo con la pelota
## ya en marcha (medido con el esqueleto: punta del pie a 0.02-0.07 m en la imagen del contacto; el pie avanza
## 0.25-0.3 m por fotograma en un golpeo).
## mocap: clip del «Mocap Pack 05 Soccer» (modo 2): su golpeo trae la carrera y el balanceo completos y se le da
## MOCAP_EXTRA_LATENCY s mas para que se vea (a 1.6x en 0.2 s solo quedaba un latigazo del pie).
static func clip_timing(contact_time: float, action: StringName, charge: float, mocap: bool = false) -> Dictionary:
	var t: PlayerTuning = Tuning.player
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var shot: bool = action == &"shot"
	var want: float = t.kick_latency + (t.shot_windup + t.shot_windup_charge * charge if shot else 0.0)
	if mocap:
		want += MOCAP_EXTRA_LATENCY
	var steps: int = maxi(int(round(want / dt)), 2)
	# El tiro se reproduce casi a velocidad natural desde antes del balanceo (se ve la pierna atras); el pase, acelerado.
	var speed: float = clampf(contact_time / (want + 0.08 if shot else 0.30), 1.0, t.kick_clip_speed_max)
	var offset: float = contact_time - speed * dt * float(steps)
	if offset < 0.0:
		offset = 0.0
		speed = contact_time / (dt * float(steps))
	# Un poco menos que steps * dt: el temporizador llega a cero exactamente en el paso `steps`.
	return {"speed": speed, "offset": offset, "latency": float(steps) * dt - 0.0005}

## Vector (pelota - pie) en el plano, en metros, al instante de contacto del clip, PREDICHO desde el estado actual
## (jugador y pelota siguen su velocidad; el giro sigue el ritmo actual reducido por kick_turn_scale). La altura va en y.
## Orientacion prevista del cuerpo al contacto: gira hacia la direccion deseada a la velocidad de giro actual, reducida
## por kick_turn_scale (durante el balanceo el pie de apoyo fija la direccion). Con la direccion ya apuntando al frente
## equivale a mantener el yaw; si el joystick acaba de girar, anticipa el giro que todavia no se ve en turn_rate.
func _predicted_yaw(latency: float) -> float:
	var loco: Locomotion = owner.locomotion
	var t: PlayerTuning = Tuning.player
	if _desired_dir.length_squared() < 0.01:
		return loco.yaw + loco.turn_rate * t.kick_turn_scale * latency
	var dy: float = wrapf(Locomotion.yaw_from_dir(_desired_dir.normalized()) - loco.yaw, -PI, PI)
	var ratio: float = clampf(loco.speed / maxf(loco.max_sprint_speed(), 0.1), 0.0, 1.0)
	var rate: float = deg_to_rad(lerpf(t.turn_rate_standing, t.turn_rate_sprint, ratio * ratio)) * owner.attributes.factor("agility", 0.14)
	var max_turn: float = rate * t.kick_turn_scale * latency
	return loco.yaw + clampf(dy, -max_turn, max_turn)

## Aborta una patada en curso y la accion pendiente (caida, barrida): no se aplica ningun impulso.
func abort_kick() -> void:
	if _kick_action != &"" and AnimTrace.enabled:
		AnimTrace.event(owner, &"kick", &"BallHandler.abort_kick", _kick_clip.get("clip", &""), "cancelled", "golpeo abortado antes del contacto",
			{"context": String(_kick_action), "contact_validated": false, "physics_applied": false})
	if _kick_action != &"":
		if owner.arbiter != null:
			owner.arbiter.relevel(_kick_token, ActionArbiter.Level.OVERLAY)
		_kick_token = 0
		_kick_action = &""
		_kick_clip = {}
		_kick_turn = {}
		owner.locomotion.turn_scale = 1.0
		owner.nudge_velocity = Vector3.ZERO
		owner.set_ball_ghost(false)
		lockout = 0.0
	_pending_action = &""

## Cancela la carga de pase/tiro en curso sin ejecutar nada (la IA lo usa cuando la pelota se le fue).
func cancel_charge() -> void:
	_pass_active = false
	_shoot_active = false
	_through_active = false
	_cross_active = false
	pass_charge = 0.0
	shot_charge = 0.0
	through_charge = 0.0
	cross_charge = 0.0

## Velocidad (adelante, derecha) en m/s del cuerpo que deja QUIETO el pie de apoyo de un clip en el sitio en los
## KICK_PLANT_TIME previos al contacto (los clips en el sitio mueven el pie apoyado hacia atras a la velocidad de
## carrera que representan). playback: velocidad de reproduccion. Si el pie no esta apoyado, cero (el cuerpo se para).
static func clip_plant_velocity(clip: StringName, contact_time: float, foot: int, playback: float) -> Vector2:
	var paths: Dictionary = PackLibrary.meta(clip).get("paths", {})
	var key: String = "toe_l" if foot == 1 else "toe_r"
	if not paths.has(key):
		return Vector2.ZERO
	var path: PackedVector3Array = paths[key]
	var k1: int = mini(int(round(contact_time * 30.0)), path.size() - 1)
	var k0: int = maxi(k1 - maxi(int(round(KICK_PLANT_TIME * playback * 30.0)), 1), 0)
	if k1 <= k0 or path[k1].y > PLANT_FOOT_MAX_Y:
		return Vector2.ZERO
	var d: Vector3 = path[k1] - path[k0]
	var secs: float = float(k1 - k0) / 30.0 / playback
	return Vector2(-d.x, -d.z) / secs

## Velocidad del cuerpo (mundo) con el pie de apoyo plantado para un contacto, con orientacion yaw y velocidad previa v.
## La velocidad del clip se acota a la que trae el cuerpo + PLANT_SPEED_GAIN_MAX: un jugador parado no sale disparado
## porque el clip elegido represente un golpeo al trote (el pie de apoyo desliza algo en ese caso; plan_clip_kick
## prefiere los clips cuya velocidad de apoyo encaja con la del jugador, ver PLANT_MISMATCH_COST).
static func plant_velocity(contact: Dictionary, yaw: float, v: Vector3) -> Vector3:
	if not contact.has("plant"):
		return Vector3(v.x, 0.0, v.z) * KICK_PLANT_SPEED
	var pl: Vector2 = contact["plant"]
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var pv: Vector3 = f * pl.x + Vector3(-f.z, 0.0, f.x) * pl.y
	return pv.limit_length(Vector2(v.x, v.z).length() + PLANT_SPEED_GAIN_MAX)

## Recorrido del cuerpo en las proximas latency s de una patada que empieza (o sigue) con velocidad v: a velocidad
## constante hasta plantar el pie y a la velocidad de apoyo (plant_v) en los ultimos KICK_PLANT_TIME.
static func kick_body_travel(v: Vector3, latency: float, plant_v: Vector3) -> Vector3:
	var plant: float = minf(latency, KICK_PLANT_TIME)
	return Vector3(v.x, 0.0, v.z) * (latency - plant) + plant_v * plant

## Ajuste de paso maximo (m/s) a la velocidad de cuerpo v.
static func kick_nudge_cap(v: Vector3) -> float:
	return KICK_NUDGE_MAX + KICK_NUDGE_PER_MS * Vector2(v.x, v.z).length()

## Metros de ajuste de paso que caben antes de plantar el pie en una patada de latencia `latency`.
static func kick_adjust_capacity(v: Vector3, latency: float) -> float:
	return kick_nudge_cap(v) * maxf(latency - KICK_PLANT_TIME, 0.0)

## true durante una patada con clip (balanceo hasta el contacto).
func is_clip_kick_in_progress() -> bool:
	return _kick_action != &"" and not _kick_clip.is_empty()

## Velocidad del cuerpo durante una patada con clip: la de partida, frenada con el pie de apoyo plantado.
func kick_body_velocity() -> Vector3:
	if not _kick_turn.is_empty():
		# Golpeo girando: el cuerpo va con la raiz del clip (marco del inicio del clip).
		var rp: PackedVector2Array = PackLibrary.meta(_kick_clip["clip"]).get("root_path", PackedVector2Array())
		if rp.size() < 2:
			return Vector3.ZERO
		var ct2: float = _turn_kick_clip_t()
		var fi: float = clampf(ct2 * 30.0, 0.0, float(rp.size() - 2))
		var rv: Vector2 = (rp[int(fi) + 1] - rp[int(fi)]) * 30.0 * float(_kick_turn["speed"])
		var f0: Vector3 = Locomotion.dir_from_yaw(float(_kick_turn["yaw0"]))
		return f0 * rv.x + Vector3(-f0.z, 0.0, f0.x) * rv.y
	if _kick_timer > KICK_PLANT_TIME:
		return _kick_v0
	return plant_velocity(_kick_clip["contact"], owner.locomotion.yaw, _kick_v0)

## Ajuste de paso en lazo cerrado: cada fotograma se vuelve a predecir donde estara el pie en el contacto y se corrige
## lo que falta con el cuerpo (acotado) hasta plantar el pie; con el pie plantado no hay ajuste.
func _steer_clip_kick() -> void:
	if _kick_timer <= KICK_PLANT_TIME:
		owner.nudge_velocity = Vector3.ZERO
		return
	var b: Ball = ball()
	if b == null or b.is_held():
		owner.nudge_velocity = Vector3.ZERO
		return
	var delta: Vector3 = _turn_kick_foot_to_ball() if not _kick_turn.is_empty() else predicted_foot_to_ball(_kick_clip["contact"], _kick_timer, _kick_v0)
	var flat_d := Vector3(delta.x, 0.0, delta.z)
	owner.nudge_velocity = (flat_d / maxf(_kick_timer - KICK_PLANT_TIME, 0.04)).limit_length(kick_nudge_cap(_kick_v0))

## Lo comun a todos los clips de una accion en predicted_foot_to_ball (misma latencia): giro previsto, pelota prevista y velocidad.
func _fast_prediction(latency: float) -> Dictionary:
	var b: Ball = ball()
	var loco: Locomotion = owner.locomotion
	var bp: Vector3 = b.global_position + ball_travel(b, latency)
	bp.y = b.global_position.y
	var plant: float = minf(latency, KICK_PLANT_TIME)
	var v: Vector3 = loco.velocity
	return {"yaw": _predicted_yaw(latency), "bp": bp, "v": v, "plant": plant, "cruise": Vector3(v.x, 0.0, v.z) * (latency - plant)}

## predicted_foot_to_ball con lo precalculado por _fast_prediction (mismas cuentas, sin repetir las comunes).
func _foot_to_ball_fast(contact: Dictionary, pre: Dictionary) -> Vector3:
	var yaw: float = pre["yaw"]
	var p: Vector3 = owner.global_position + (pre["cruise"] as Vector3) + plant_velocity(contact, yaw, pre["v"]) * float(pre["plant"])
	return (pre["bp"] as Vector3) - foot_contact_world(contact, p, yaw)

func predicted_foot_to_ball(contact: Dictionary, latency: float, body_v: Variant = null) -> Vector3:
	var b: Ball = ball()
	var loco: Locomotion = owner.locomotion
	var yaw: float = _predicted_yaw(latency)
	var v: Vector3 = body_v if body_v != null else loco.velocity
	var p: Vector3 = owner.global_position + kick_body_travel(v, latency, plant_velocity(contact, yaw, v))
	var bp: Vector3 = b.global_position + ball_travel(b, latency)
	bp.y = b.global_position.y
	return bp - foot_contact_world(contact, p, yaw)

## Puntos validos de golpeo de un clip: muestras de la trayectoria del pie (adelante, arriba, derecha) con la punta baja y
## lanzada hacia adelante. Devuelve [{time, pos}] (tiempo del clip en segundos).
static func contact_samples(contact: Dictionary) -> Array:
	var t: PlayerTuning = Tuning.player
	var path: PackedVector3Array = contact.get("path", PackedVector3Array())
	var out: Array = []
	if path.size() < 3:
		return [{"time": float(contact["time"]), "pos": contact["pos"]}]
	var dt: float = contact["path_dt"]
	for k in range(1, path.size() - 1):
		var vfwd: float = (path[k + 1].x - path[k - 1].x) / (2.0 * dt)
		if path[k].y <= t.kick_foot_max_height and vfwd >= t.kick_foot_min_speed:
			out.append({"time": float(contact["path_t0"]) + k * dt, "pos": path[k]})
	return out if not out.is_empty() else [{"time": float(contact["time"]), "pos": contact["pos"]}]

static var _samples_cache: Dictionary = {}

## contact_samples de un clip, con a lo sumo MAX_SAMPLES instantes repartidos por la trayectoria (modo 4), guardado por clip.
static func contact_samples_cached(clip: StringName, contact: Dictionary) -> Array:
	if _samples_cache.has(clip):
		return _samples_cache[clip]
	var all: Array = contact_samples(contact)
	var out: Array = all
	if all.size() > MAX_SAMPLES:
		out = []
		for i in MAX_SAMPLES:
			out.append(all[int(round(float(i) * float(all.size() - 1) / float(MAX_SAMPLES - 1)))])
	_samples_cache[clip] = out
	return out

## Instantes de contacto que se prueban por clip en el modo 4.
const MAX_SAMPLES := 3

## Clips de pelota en el aire: cabezazos (trayectoria de la cabeza) y voleas/acrobacias (punta del pie), con su espejo.
const AERIAL_SETS := [
	{"clips": [&"Header", &"Soccer_Header", &"header_soccerball", &"header_soccerball_2", &"Jumping_Up"], "keys": ["head"], "min_speed": 1.6, "kind": &"header"},
	{"clips": [&"kick_soccerball", &"kick_soccerball_2", &"scissor_kick", &"Flying_Bicycle_Kick"], "keys": ["toe_l", "toe_r"], "min_speed": 4.5, "kind": &"volley"},
]
## Altura de la pelota (m) a partir de la cual se juega en el aire (cabezazo / volea) en vez de a ras de piso.
const AERIAL_MIN_BALL_Y := 0.5

## Planifica un golpeo con la pelota en el aire: busca, entre los clips de cabezazo y volea, el instante en que la cabeza
## o la punta del pie (con velocidad suficiente) coincide con la pelota PREDICHA, con ajuste de zancada acotado.
func plan_aerial_kick(action: StringName, charge: float) -> Dictionary:
	var b: Ball = ball()
	if b == null or b.is_held():
		return {}
	var t: PlayerTuning = Tuning.player
	var traj: PackedVector3Array = BallPredictor.trajectory(b.global_position, b.linear_velocity, 1.3, 1.0 / 30.0, b.angular_velocity)
	var adjust_max: float = t.kick_adjust_max + t.kick_adjust_sprint * _sprint_ratio()
	var best: Dictionary = {}
	var best_score: float = INF
	var json: bool = PackLibrary.json_mode()
	# Modo 4 (cientos de cabezazos y voleas): ventana de la pelota en el marco del jugador entre 0.1 y 1.1 s, para descartar
	# con la caja de cada trayectoria los clips que no pueden llegar.
	var wlo := Vector3(INF, INF, INF)
	var whi := Vector3(-INF, -INF, -INF)
	if json:
		var lf: Vector3 = owner.locomotion.forward()
		var lr: Vector3 = owner.locomotion.right()
		for i in range(3, mini(traj.size(), 34)):
			var d: Vector3 = traj[i] - owner.global_position
			var lp := Vector3(d.dot(lf), traj[i].y, d.dot(lr))
			wlo = Vector3(minf(wlo.x, lp.x), minf(wlo.y, lp.y), minf(wlo.z, lp.z))
			whi = Vector3(maxf(whi.x, lp.x), maxf(whi.y, lp.y), maxf(whi.z, lp.z))
		var body_move: float = owner.locomotion.speed * 1.1 + adjust_max + t.kick_start_residual + 0.2
		wlo -= Vector3(body_move, t.kick_start_residual + 0.1, body_move)
		whi += Vector3(body_move, t.kick_start_residual + 0.1, body_move)
	for set in AERIAL_SETS:
		# Modo 4: los clips de cada conjunto son todos los del rol (cabezazo / volea), ya con sus espejos.
		var clip_list: Array = set["clips"]
		if json:
			clip_list = PackLibrary.by_role(&"header" if set["kind"] == &"header" else &"volley")
		for base in clip_list:
			for clip in ([base] if json else [base, StringName(String(base) + "_mirror")]):
				if not PackLibrary.has_clip(clip):
					continue
				var paths: Dictionary = PackLibrary.meta(clip).get("paths", {})
				for key in set["keys"]:
					if not paths.has(key):
						continue
					var path: PackedVector3Array = paths[key]
					if json:
						var bb: Array = _path_bbox(clip, key, path)
						var lo: Vector3 = bb[0]
						var hi: Vector3 = bb[1]
						if whi.x < lo.x or wlo.x > hi.x or whi.y < lo.y or wlo.y > hi.y or whi.z < lo.z or wlo.z > hi.z:
							if not _trace_kick.is_empty():
								AnimTrace.cand(_trace_kick, clip, "trayectoria de %s fuera del alcance de la pelota" % key)
							continue
					# Modo 4 (muchos clips): un instante de cada dos (a 30 Hz sobran).
					for k in range(4, path.size() - 1, 2 if PackLibrary.json_mode() else 1):
						var v: float = (path[k + 1] - path[k - 1]).length() * 15.0
						if v < float(set["min_speed"]):
							continue
						for sp in [1.0, 1.4]:
							var lat: float = float(k) / 30.0 / sp
							if lat < 0.1 or lat > 1.1:
								continue
							var c := {"time": float(k) / 30.0, "pos": path[k], "foot": 1}
							var ip: float = lat * 30.0
							var i0: int = mini(int(ip), traj.size() - 2)
							var bp: Vector3 = traj[i0].lerp(traj[i0 + 1], ip - float(i0))
							var yaw: float = _predicted_yaw(lat)
							var loco: Locomotion = owner.locomotion
							var pb: Vector3 = owner.global_position + kick_body_travel(loco.velocity, lat, plant_velocity(c, yaw, loco.velocity))
							var delta: Vector3 = bp - foot_contact_world(c, pb, yaw)
							var flat_d := Vector3(delta.x, 0.0, delta.z)
							var step: Vector3 = flat_d.limit_length(adjust_max)
							var residual: float = Vector3(flat_d.x - step.x, delta.y, flat_d.z - step.z).length()
							var score: float = residual + 0.12 * step.length() + (0.06 if sp > 1.0 else 0.0) + (0.0 if set["kind"] == &"volley" else 0.03)
							if not _trace_kick.is_empty():
								var tc: Dictionary = {"time": c["time"], "foot": 0 if key == "toe_l" else 1}
								AnimTrace.cand(_trace_kick, clip, "" if residual <= t.kick_start_residual else "residuo %.2f m > %.2f m" % [residual, t.kick_start_residual],
									_trace_kick_fields(clip, tc, lat, 0.0, bp, delta, step, score, {"residuo": residual, "ajuste": 0.12 * step.length()},
										"head" if set["kind"] == &"header" else "foot"))
							if score < best_score:
								best_score = score
								best = {"clip": clip, "speed": sp, "offset": 0.0, "latency": lat, "contact": c, "distance": delta.length(),
									"residual": residual, "adjust": step, "aerial": set["kind"]}
	return best if not best.is_empty() and best["residual"] <= t.kick_start_residual else {}

static var _bbox_cache: Dictionary = {}

## Caja (min, max) de la trayectoria `key` de un clip en el marco del cuerpo, entre 0.1 y 1.1 s (lo que prueba el planificador
## aereo), guardada por clip.
static func _path_bbox(clip: StringName, key: String, path: PackedVector3Array) -> Array:
	var ck: String = String(clip) + ":" + key
	if _bbox_cache.has(ck):
		return _bbox_cache[ck]
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for k in range(3, mini(path.size(), 34)):
		lo = Vector3(minf(lo.x, path[k].x), minf(lo.y, path[k].y), minf(lo.z, path[k].z))
		hi = Vector3(maxf(hi.x, path[k].x), maxf(hi.y, path[k].y), maxf(hi.z, path[k].z))
	_bbox_cache[ck] = [lo, hi]
	return [lo, hi]

## Traza (AnimTrace, solo depuracion): decision del golpeo en curso de planificacion. La abre plan_clip_kick, la completan
## plan_turn_kick y plan_aerial_kick, y la cierra _try_execute_pending con lo que decidio el arbitro.
var _trace_kick: Dictionary = {}

## Campos de traza de un instante de contacto evaluado (pelota prevista, punto del pie, errores y coste desglosado).
func _trace_kick_fields(clip: StringName, c: Dictionary, latency: float, offset: float, bp: Vector3, delta: Vector3, step: Vector3,
		score: float, breakdown: Dictionary, part: String = "foot") -> Dictionary:
	var cp: Vector3 = bp - delta
	var m: Dictionary = PackLibrary.meta(clip)
	var target: Vector3 = _pending_stick if _pending_stick.length_squared() > 0.01 else _desired_dir
	return {"frame_start": int(round(offset * AnimTrace.FRAME_RATE)), "frame_contact": int(round(float(c["time"]) * AnimTrace.FRAME_RATE)),
		"body_part": part, "foot": "R" if int(c.get("foot", 1)) > 0 else "L", "v_in": owner.locomotion.speed, "v_clip": float(m.get("v_in", 0.0)),
		"orient_start": rad_to_deg(owner.locomotion.yaw), "orient_target": rad_to_deg(Locomotion.yaw_from_dir(target.normalized())) if target.length_squared() > 0.01 else "",
		"ball_pred_x": bp.x, "ball_pred_y": bp.y, "ball_pred_z": bp.z, "contact_point_x": cp.x, "contact_point_y": cp.y, "contact_point_z": cp.z,
		"spatial_error_m": delta.length(), "root_correction_m": step.length(), "tolerance_applied": Tuning.player.kick_start_residual,
		"tolerance_reason": "kick_start_residual (residuo tras el ajuste de zancada)", "cost_total": score, "cost_breakdown_json": breakdown,
		"_latency": latency}

## Elige el mejor clip, pierna E INSTANTE DE CONTACTO para la accion. El instante sale de la trayectoria real del pie del
## clip (contact_samples), no es fijo: se busca el punto que mejor encaja con la pelota predicha. Cada opcion puede
## compensar hasta el ajuste de zancada maximo; se empieza solo si, tras el ajuste, el pie quedaria a menos de
## kick_start_residual de la pelota. Si ninguna llega, devuelve {} y NO hay patada.
func plan_clip_kick(action: StringName, charge: float, lob: bool, preferred_clip: StringName = &"") -> Dictionary:
	var b: Ball = ball()
	if b == null or b.is_held():
		return {}
	_trace_kick = AnimTrace.begin(owner, &"kick", &"BallHandler.plan_clip_kick", String(action)) if AnimTrace.enabled else {}
	if b.global_position.y > AERIAL_MIN_BALL_Y:
		if not _trace_kick.is_empty():
			_trace_kick["family"] = &"aerial"
		var aerial: Dictionary = plan_aerial_kick(action, charge)
		return aerial if preferred_clip == &"" or aerial.get("clip", &"") == PackLibrary.resolve(preferred_clip) else {}
	var t: PlayerTuning = Tuning.player
	var adjust_max: float = t.kick_adjust_max + t.kick_adjust_sprint * _sprint_ratio()
	var best: Dictionary = {}
	var best_score: float = INF
	var kind_key: StringName = action if action == &"cross" else (&"lob" if lob else action)
	var pool: Array = []
	var fast: Dictionary = {}
	var json: bool = PackLibrary.json_mode()
	# Modo 4 (decenas de clips): se descartan, con una cuenta barata, los clips cuyo contacto queda lejos de donde esta la pelota
	# ahora (mas el ajuste de zancada y lo que ella y el cuerpo pueden moverse en la latencia), y de los demas se prueban pocos
	# instantes de contacto. Sin esto, planificar costaba ~15 ms y se repite cada paso mientras la orden espera.
	var bo: Vector3 = ball_offset()
	var bfwd: float = bo.dot(owner.locomotion.forward())
	var bright: float = bo.dot(owner.locomotion.right())
	var margin: float = adjust_max + t.kick_start_residual + 0.2 + 0.35 * KickModel.flat(b.linear_velocity - owner.locomotion.velocity).length()
	_kick_turn_dir = Vector3.ZERO
	if json:
		# Destino lejos del frente: golpeo girando (si alguno llega a la pelota); si no, el golpeo de siempre.
		var kd: Vector3 = estimated_kick_dir(action, _pending_stick if _pending_stick.length_squared() > 0.01 else _desired_dir, charge, lob)
		if kd != Vector3.ZERO:
			var alpha: float = rad_to_deg(wrapf(Locomotion.yaw_from_dir(kd) - owner.locomotion.yaw, -PI, PI))
			last_plan_debug = "alpha %.0f" % alpha
			if absf(alpha) >= TURN_KICK_MIN:
				var tp: Dictionary = plan_turn_kick(action, alpha, adjust_max)
				last_plan_debug += " giro: %s" % ("sin plan" if tp.is_empty() else String(tp["clip"]))
				if not tp.is_empty():
					return tp if preferred_clip == &"" or tp["clip"] == PackLibrary.resolve(preferred_clip) else {}
				if absf(alpha) >= TURN_FIRST_MIN:
					# Ningun golpeo girando sirve (el destino queda casi detras): primero se gira con la pelota.
					_kick_turn_dir = kd
					return {}
	var cands: Array = AnimationCatalog.kick_candidates(kind_key, charge)
	# Una variante explicita sigue pasando TODAS las condiciones fisicas del planificador y debe pertenecer a la accion.
	if preferred_clip != &"":
		var requested: StringName = PackLibrary.resolve(preferred_clip)
		cands = cands.filter(func(candidate: Dictionary) -> bool: return candidate["clip"] == requested)
	if json and cands.size() > JSON_KICK_EVAL:
		# Cientos de golpeos: se evaluan a fondo solo los JSON_KICK_EVAL cuyo contacto queda mas cerca de donde estara la pelota
		# (cuenta barata: pelota relativa al cuerpo, con la velocidad relativa durante una latencia tipica).
		var rel_v: Vector3 = KickModel.flat(b.linear_velocity - owner.locomotion.velocity)
		var lat0: float = t.kick_latency
		var pf: float = bfwd + rel_v.dot(owner.locomotion.forward()) * lat0
		var pr: float = bright + rel_v.dot(owner.locomotion.right()) * lat0
		var scored: Array = []
		var spd: float = owner.locomotion.speed
		for cand in cands:
			var cp0: Vector3 = cand["contact"]["pos"]
			# Tambien la carrera de entrada del clip (v_in) frente a la del jugador: si no, a un jugador parado le tocaban
			# golpeos con carrera y el pie de apoyo patinaba (medido: 3 m/s).
			var v_in: float = float(cand["v_in"]) if cand.has("v_in") else spd
			scored.append([Vector2(cp0.x - pf, cp0.z - pr).length() + JSON_PLANT_MISMATCH_COST * absf(v_in - spd), cand])
		scored.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
		if not _trace_kick.is_empty():
			for e in scored.slice(JSON_KICK_EVAL):
				AnimTrace.cand(_trace_kick, (e[1] as Dictionary)["clip"], "fuera de los %d contactos mas cercanos" % JSON_KICK_EVAL, {"cost_total": float(e[0])})
		cands = scored.slice(0, JSON_KICK_EVAL).map(func(e: Array) -> Dictionary: return e[1])
	for cand in cands:
		var samples: Array = contact_samples_cached(cand["clip"], cand["contact"]) if json else contact_samples(cand["contact"])
		if json:
			var cp: Vector3 = cand["contact"]["pos"]
			if Vector2(cp.x - bfwd, cp.z - bright).length() > margin:
				if not _trace_kick.is_empty():
					AnimTrace.cand(_trace_kick, cand["clip"], "contacto del clip a mas de %.2f m de la pelota" % margin)
				continue
		for smp in samples:
			var c := {"time": smp["time"], "pos": smp["pos"], "foot": cand["foot"]}
			var timing: Dictionary = clip_timing(float(c["time"]), action, charge, bool(cand["mocap"]) if cand.has("mocap") else bool(PackLibrary.meta(cand["clip"]).get("mocap", false)))
			c["plant"] = clip_plant_velocity(cand["clip"], float(c["time"]), int(c["foot"]), float(timing["speed"]))
			var delta: Vector3
			if json:
				# La latencia es la misma para todos los clips de la accion: la pelota y el giro previstos se calculan una vez.
				if fast.is_empty():
					fast = _fast_prediction(float(timing["latency"]))
				delta = _foot_to_ball_fast(c, fast)
			else:
				delta = predicted_foot_to_ball(c, timing["latency"])
			var flat_d := Vector3(delta.x, 0.0, delta.z)
			# El ajuste solo cabe antes de plantar el pie: no se planifica uno que el cuerpo no puede dar.
			var step: Vector3 = flat_d.limit_length(minf(adjust_max, kick_adjust_capacity(owner.locomotion.velocity, float(timing["latency"]))))
			var residual: float = Vector3(flat_d.x - step.x, delta.y, flat_d.z - step.z).length()
			var mismatch: float = absf((c["plant"] as Vector2).length() - owner.locomotion.speed)
			var score: float = residual + (JSON_STEP_COST if json else 0.15) * step.length() + (JSON_PLANT_MISMATCH_COST if json else PLANT_MISMATCH_COST) * mismatch
			var plan: Dictionary = timing.merged({"clip": cand["clip"], "contact": c, "distance": delta.length(), "residual": residual, "adjust": step})
			if not _trace_kick.is_empty():
				var tbp: Vector3 = fast["bp"] if json else b.global_position + ball_travel(b, float(timing["latency"]))
				AnimTrace.cand(_trace_kick, cand["clip"], "" if residual <= t.kick_start_residual else "residuo %.2f m > %.2f m" % [residual, t.kick_start_residual],
					_trace_kick_fields(cand["clip"], c, float(timing["latency"]), float(timing["offset"]), tbp, delta, step, score,
						{"residuo": residual, "ajuste_zancada": (JSON_STEP_COST if json else 0.15) * step.length(),
						"carrera_pie_apoyo": (JSON_PLANT_MISMATCH_COST if json else PLANT_MISMATCH_COST) * mismatch}))
			if score < best_score:
				best_score = score
				best = plan
			pool.append([score, plan])
	# Modo 4 (hay muchos clips): entre los que encajan casi igual de bien se elige uno al azar, para que el jugador no repita
	# siempre el mismo gesto.
	if PackLibrary.json_mode() and not best.is_empty() and best["residual"] <= t.kick_start_residual:
		var ok: Array = pool.filter(func(e: Array) -> bool: return float(e[0]) <= best_score + JSON_KICK_VARIETY and float((e[1] as Dictionary)["residual"]) <= t.kick_start_residual)
		if ok.size() > 1:
			best = (ok[rng.randi() % ok.size()] as Array)[1]
	return best if not best.is_empty() and best["residual"] <= t.kick_start_residual else {}

## Direccion (plana) en la que saldria la pelota si se golpeara ahora: la misma asistencia que el golpeo real (receptor del
## pase, arco del tiro...), con un azar fijo. Cero si no se puede estimar.
func estimated_kick_dir(action: StringName, stick: Vector3, charge: float, lob: bool) -> Vector3:
	var ctx: MatchContext = owner.ctx
	if ctx == null or ball() == null:
		return Vector3.ZERO
	var tmp := RandomNumberGenerator.new()
	tmp.seed = 7
	var res: KickModel.KickResult = null
	match action:
		&"pass":
			res = PassAssist.compute(owner, ctx, stick, charge, lob, tmp, assist_pass_level())
		&"through":
			res = PassAssist.compute_through(owner, ctx, stick, charge, lob, tmp, assist_pass_level())
		&"cross":
			res = CrossAssist.compute(owner, ctx, stick, charge, lob, tmp, assist_pass_level(), 0.0)
		_:
			res = ShotAssist.compute(owner, ctx, stick, charge, lob, tmp, assist_shot_level(), 0.0)
	if res == null:
		return Vector3.ZERO
	var v: Vector3 = KickModel.flat(res.velocity)
	return v.normalized() if v.length() > 0.1 else Vector3.ZERO

## Modo 4: planifica un golpeo girando hacia un destino a `alpha` grados del frente (+ izquierda). El cuerpo sigue la raiz y
## el rumbo del clip (gira y patea); se busca el clip cuya pelota sale hacia el destino y cuyo pie llega a la pelota prevista
## con un ajuste de paso acotado. {} si ninguno llega.
func plan_turn_kick(action: StringName, alpha: float, adjust_max: float) -> Dictionary:
	var b: Ball = ball()
	var t: PlayerTuning = Tuning.player
	var loco: Locomotion = owner.locomotion
	var pos: Vector3 = KickModel.flat(owner.global_position)
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var best: Dictionary = {}
	var best_score: float = INF
	var max_lat: float = TURN_KICK_PRESSED_LATENCY if nearest_opponent(TURN_KICK_PRESS_DIST) != null else TURN_KICK_MAX_LATENCY
	for role in [&"kick_turn", &"kick_back"]:
		for id in PackLibrary.by_role(role):
			var m: Dictionary = PackLibrary.meta(id)
			if not m.has("contact"):
				continue
			var ct: Dictionary = m["contact"]
			var kt: float = float(ct.get("kick_turn", 0.0))
			var dk: float = absf(wrapf(kt - alpha, -180.0, 180.0))
			if dk > TURN_KICK_TOL or (ct["pos"] as Vector3).y > 0.35:
				if not _trace_kick.is_empty():
					AnimTrace.cand(_trace_kick, id, "giro del clip %.0f grados frente a %.0f pedidos" % [kt, alpha] if dk > TURN_KICK_TOL else "pie a mas de 0.35 m en el contacto")
				continue
			if action == &"shot" and float(ct["speed"]) < 7.0:
				if not _trace_kick.is_empty():
					AnimTrace.cand(_trace_kick, id, "pie a menos de 7 m/s para un tiro")
				continue
			var hp: PackedFloat32Array = m.get("heading_path", PackedFloat32Array())
			var rp: PackedVector2Array = m.get("root_path", PackedVector2Array())
			var tc: float = float(ct["time"])
			var rc: Vector2 = ct.get("root", Vector2.ZERO)
			var dv: float = absf(float(m.get("v_in", 0.0)) - loco.speed)
			for start_at in [0.0, 0.15, 0.3]:
				if tc - start_at < 0.22:
					break
				for sp in [1.0, 1.3]:
					var steps: int = maxi(int(round((tc - start_at) / sp / dt)), 2)
					var lat: float = float(steps) * dt
					if lat > max_lat:
						if not _trace_kick.is_empty():
							AnimTrace.cand(_trace_kick, id, "contacto a %.2f s (maximo %.2f s)" % [lat, max_lat])
						continue
					var speed: float = (tc - start_at) / lat
					var yaw0: float = loco.yaw - ActionMotion.heading_rel(hp, start_at)
					var f0: Vector3 = Locomotion.dir_from_yaw(yaw0)
					var r0 := Vector3(-f0.z, 0.0, f0.x)
					var rs: Vector2 = ActionMotion._at(rp, start_at) if rp.size() >= 2 else Vector2.ZERO
					var body_c: Vector3 = pos + f0 * (rc.x - rs.x) + r0 * (rc.y - rs.y)
					var yaw_c: float = yaw0 + ActionMotion.heading_rel(hp, tc)
					var bp: Vector3 = b.global_position + ball_travel(b, lat)
					bp.y = b.global_position.y
					var delta: Vector3 = bp - foot_contact_world(ct, body_c, yaw_c)
					var flat_d := Vector3(delta.x, 0.0, delta.z)
					var step: Vector3 = flat_d.limit_length(minf(adjust_max, KICK_NUDGE_MAX * maxf(lat - KICK_PLANT_TIME, 0.0)))
					var residual: float = Vector3(flat_d.x - step.x, delta.y, flat_d.z - step.z).length()
					var score: float = residual + 0.3 * step.length() + 0.006 * dk + 0.12 * dv + (0.04 if sp > 1.0 else 0.0) + rng.randf() * 0.03
					if not _trace_kick.is_empty():
						AnimTrace.cand(_trace_kick, id, "" if residual <= t.kick_start_residual else "residuo %.2f m > %.2f m" % [residual, t.kick_start_residual],
							_trace_kick_fields(id, ct, lat, start_at, bp, delta, step, score, {"residuo": residual, "ajuste_zancada": 0.3 * step.length(),
								"giro": 0.006 * dk, "carrera": 0.12 * dv}).merged({"angular_error_deg": dk}, true))
					if score < best_score:
						best_score = score
						best = {"clip": id, "speed": speed, "offset": start_at, "latency": lat - 0.0005, "contact": ct, "distance": delta.length(),
							"residual": residual, "adjust": step, "turn": {"yaw0": yaw0, "start_at": start_at, "speed": speed, "latency": lat - 0.0005, "kick_turn": kt, "alpha": alpha}}
	if not best.is_empty():
		last_plan_debug += " mejor %s resid %.2f ajuste %.2f" % [best["clip"], best["residual"], (best["adjust"] as Vector3).length()]
	return best if not best.is_empty() and best["residual"] <= t.kick_start_residual else {}

## Golpeo girando en curso: instante del clip ahora.
func _turn_kick_clip_t() -> float:
	var tk: Dictionary = _kick_turn
	return float(tk["start_at"]) + (float(tk["latency"]) - _kick_timer) * float(tk["speed"])

## Orientacion del cuerpo durante un golpeo girando (NAN si no hay): la del clip.
func kick_body_yaw() -> float:
	if _kick_turn.is_empty() or _kick_clip.is_empty():
		return NAN
	var hp: PackedFloat32Array = PackLibrary.meta(_kick_clip["clip"]).get("heading_path", PackedFloat32Array())
	return float(_kick_turn["yaw0"]) + ActionMotion.heading_rel(hp, _turn_kick_clip_t())

## Golpeo girando: donde quedara la punta del pie en el contacto respecto a la pelota prevista, con el cuerpo en su sitio de
## ahora siguiendo la raiz del clip.
func _turn_kick_foot_to_ball() -> Vector3:
	var b: Ball = ball()
	var m: Dictionary = PackLibrary.meta(_kick_clip["clip"])
	var ct: Dictionary = _kick_clip["contact"]
	var rp: PackedVector2Array = m.get("root_path", PackedVector2Array())
	var hp: PackedFloat32Array = m.get("heading_path", PackedFloat32Array())
	var yaw0: float = float(_kick_turn["yaw0"])
	var f0: Vector3 = Locomotion.dir_from_yaw(yaw0)
	var r0 := Vector3(-f0.z, 0.0, f0.x)
	var ct_t: float = float(ct["time"])
	var now_r: Vector2 = ActionMotion._at(rp, _turn_kick_clip_t()) if rp.size() >= 2 else Vector2.ZERO
	var rc: Vector2 = ct.get("root", Vector2.ZERO)
	var body_c: Vector3 = KickModel.flat(owner.global_position) + f0 * (rc.x - now_r.x) + r0 * (rc.y - now_r.y)
	var bp: Vector3 = b.global_position + ball_travel(b, maxf(_kick_timer, 0.0))
	bp.y = b.global_position.y
	return bp - foot_contact_world(ct, body_c, yaw0 + ActionMotion.heading_rel(hp, ct_t))

func _start_clip_kick(action: StringName, plan: Dictionary, stick_world: Vector3, charge: float, lob: bool) -> bool:
	var t: PlayerTuning = Tuning.player
	# El golpeo pide el control (pose del clip) al arbitro: una accion de mas nivel en curso lo deja pendiente.
	if owner.arbiter != null:
		var tok: int = owner.arbiter.play(&"kick", ActionArbiter.Level.KICK, &"BallHandler", plan["clip"], plan["speed"], plan["offset"], float(plan["latency"]) + t.kick_follow_through)
		if tok == 0:
			return false
		_kick_token = tok
	_kick_action = action
	_kick_stick = stick_world
	_kick_charge = charge
	_kick_lob = lob
	_kick_clip = plan
	var b0: Ball = ball()
	_kick_start_touch = b0.last_touch_msec if b0 != null else 0
	_kick_start_ball_v = KickModel.flat(b0.linear_velocity) if b0 != null else Vector3.ZERO
	_kick_v0 = KickModel.flat(owner.locomotion.velocity)
	kick_desired_dir = _desired_dir
	kick_desired_mag = clampf(owner.locomotion.speed / maxf(owner.locomotion.max_run_speed(), 0.1), 0.0, 1.0)
	_kick_timer = plan["latency"]
	lockout = _kick_timer + 0.4
	touch_timer = lockout
	owner.locomotion.turn_scale = t.kick_turn_scale
	owner.nudge_velocity = ((plan["adjust"] as Vector3) / maxf(_kick_timer - KICK_PLANT_TIME, 0.05)).limit_length(kick_nudge_cap(_kick_v0))
	_kick_turn = plan.get("turn", {})
	if not _kick_turn.is_empty():
		# El joystick no gira al cuerpo: lo gira el clip.
		owner.locomotion.turn_scale = 0.0
		kick_stats["turn"] = int(kick_stats.get("turn", 0)) + 1
	# Durante el balanceo el cuerpo (que se acerca a la pelota por el ajuste de zancada) no debe empujarla: el golpe lo da
	# el pie en el instante de contacto, con impulso.
	owner.set_ball_ghost(true)
	if owner.arbiter == null:
		owner.visual.play_pack_clip(plan["clip"], plan["speed"], plan["offset"], _kick_timer + t.kick_follow_through)
	kick_stats["started"] += 1
	return true

func _log_kick(action: StringName, result: StringName, extra: Dictionary = {}) -> void:
	var entry := {"action": action, "result": result, "time_ms": Time.get_ticks_msec()}
	entry.merge(extra)
	kick_log.append(entry)
	if kick_log.size() > KICK_LOG_MAX:
		kick_log.pop_front()

## Espera del contacto con una pelota que llega (golpeo de primera): en el instante de contacto del clip la pelota todavia
## viene hacia el pie. El impulso sale en el paso en que la punta del pie ANIMADO (la del cuadro que se dibuja: la leida
## ahora mas su avance de un paso, porque el AnimationTree avanza despues de la fisica) y la pelota estan mas cerca: se
## espera mientras esa distancia baja y supera CONTACT_ARRIVE_TOL, como mucho CONTACT_WAIT_MAX s. Sin esqueleto vivo, con el
## punto de contacto del clip. La pelota nunca se mueve a mano: solo se elige el paso del impulso.
const CONTACT_ARRIVE_TOL := 0.10
const CONTACT_WAIT_MAX := 0.1
var _contact_wait: float = 0.0
var _contact_prev_d: float = INF
var _contact_prev_toe: Vector3 = Vector3.ZERO

## Punta del pie del golpeo en curso (esqueleto vivo), o ZERO.
func _contact_toe_now() -> Vector3:
	if _kick_clip.is_empty() or not feet_live:
		return Vector3.ZERO
	return toe_world(1 if int(_kick_clip["contact"]["foot"]) > 0 else 0)

func _ball_still_arriving(dt: float, toe: Vector3) -> bool:
	var b: Ball = ball()
	if _kick_clip.is_empty() or b == null or b.is_held() or _contact_wait >= CONTACT_WAIT_MAX:
		_contact_reset()
		return false
	var p: Vector3
	if toe != Vector3.ZERO and _contact_prev_toe != Vector3.ZERO:
		p = toe + (toe - _contact_prev_toe)
	else:
		p = foot_contact_world(_kick_clip["contact"], owner.global_position, owner.locomotion.yaw)
	var d: float = p.distance_to(b.global_position) - b.radius
	var to_p: Vector3 = KickModel.flat(p - b.global_position)
	# Solo con una pelota que llega de verdad: la PELOTA va hacia el pie a > 2 m/s (golpeo de primera). El jugador que
	# corre hacia una pelota quieta no espera (con la velocidad relativa esperaba y el pie pasaba de largo).
	var ball_closing: float = KickModel.flat(b.linear_velocity).dot(to_p.normalized()) if to_p.length() > 0.001 else 0.0
	if d > CONTACT_ARRIVE_TOL and ball_closing > 2.0 and d < _contact_prev_d:
		_contact_prev_d = d
		_contact_wait += dt
		return true
	_contact_reset()
	return false

func _contact_reset() -> void:
	_contact_wait = 0.0
	_contact_prev_d = INF
	_contact_prev_toe = Vector3.ZERO

## Resuelve el golpeo de una patada con clip: valido solo si la pelota esta a kick_contact_radius del pie REAL
## (posicion de contacto del clip, con el jugador donde esta ahora). Si no, patada en falso: sin impulso.
func _finish_clip_kick() -> void:
	var action: StringName = _kick_action
	var plan: Dictionary = _kick_clip
	_kick_action = &""
	_kick_clip = {}
	# Resuelto el golpeo, su continuacion queda como capa en el arbitro.
	if owner.arbiter != null:
		owner.arbiter.relevel(_kick_token, ActionArbiter.Level.OVERLAY)
	_kick_token = 0
	lockout = 0.0
	owner.locomotion.turn_scale = 1.0
	owner.nudge_velocity = Vector3.ZERO
	# El cuerpo sigue sin chocar con la pelota un instante (KICK_GHOST_SECONDS): la que sale golpeada no rebota en el.
	_pass_ghost = maxf(_pass_ghost, KICK_GHOST_SECONDS)
	# Tras el golpe el cuerpo sigue con la velocidad que traia (la del pie plantado era solo del balanceo). Girando, con la
	# del clip en el contacto (ya mira hacia otro lado).
	var after_v: Vector3 = _kick_v0
	if not _kick_turn.is_empty():
		_kick_clip = plan
		after_v = kick_body_velocity()
		_kick_clip = {}
		_kick_turn = {}
	owner.locomotion.velocity = after_v
	owner.locomotion.speed = after_v.length()
	var b: Ball = ball()
	var d: float = -1.0
	if b != null and not b.is_held():
		d = b.global_position.distance_to(foot_contact_world(plan["contact"], owner.global_position, owner.locomotion.yaw))
	last_foot_distance = d
	var interfered: bool = b != null and b.last_touch_msec != _kick_start_touch and b.last_toucher != owner
	var dv: float = (KickModel.flat(b.linear_velocity) - _kick_start_ball_v).length() if b != null else 0.0
	var info := {"clip": String(plan["clip"]), "foot_distance": d, "predicted": plan["residual"], "latency": plan["latency"], "adjust_m": (plan["adjust"] as Vector3).length(), "interfered": interfered, "ball_dv": dv, "by_team": int(b.last_touch_team) if b != null else -1, "own_team": owner.team, "ball_v0": _kick_start_ball_v.length(), "body_v0": _kick_v0.length(), "turn": plan.has("turn"), "ball_y": b.global_position.y if b != null else 0.0}
	if AnimTrace.enabled:
		var ok: bool = d >= 0.0 and d <= kick_reach()
		var fw: Vector3 = foot_contact_world(plan["contact"], owner.global_position, owner.locomotion.yaw)
		var bpos: Vector3 = b.global_position if b != null else Vector3.ZERO
		AnimTrace.event(owner, &"kick", &"BallHandler._finish_clip_kick", plan["clip"], "completed" if ok else "contact_failed",
			"" if ok else "pelota a %.2f m del punto de contacto (limite %.2f m)" % [d, kick_reach()],
			{"context": String(action), "frame_contact": int(round(float(plan["contact"]["time"]) * AnimTrace.FRAME_RATE)),
			"body_part": "head" if plan.get("aerial", &"") == &"header" else "foot", "foot": "R" if int(plan["contact"].get("foot", 1)) > 0 else "L",
			"ball_pred_x": bpos.x, "ball_pred_y": bpos.y, "ball_pred_z": bpos.z, "contact_point_x": fw.x, "contact_point_y": fw.y, "contact_point_z": fw.z,
			"spatial_error_m": d, "tolerance_applied": kick_reach(), "tolerance_reason": "json_kick_reach" if _json_kicks() else "kick_contact_radius",
			"contact_validated": ok, "physics_applied": ok})
	if d < 0.0 or d > kick_reach():
		lockout = 0.3
		touch_timer = lockout
		kick_stats["missed"] += 1
		_log_kick(action, &"missed", info)
		owner.ctx.emit_event(GameEvent.make(GameEvent.Type.KICK_WHIFF, owner.actor_id, owner.team, {"action": String(action), "reason": "missed"}.merged(info)))
		return
	kick_stats["contact"] += 1
	_log_kick(action, &"contact", info)
	_kick_event_info = info
	var res: KickModel.KickResult = perform_action(action, _kick_stick, _kick_charge, _kick_lob)
	_kick_event_info = {}
	if _json_kicks():
		# El pie acompana a la pelota un instante al salir (y luego vuelve al gesto del clip).
		_json_touch_ik_start(1 if int(plan["contact"]["foot"]) > 0 else 0, res.velocity if res != null else Vector3.ZERO, JSON_KICK_IK_MAX)

func _finish_kick() -> void:
	if not _kick_clip.is_empty():
		_finish_clip_kick()
		return
	var action: StringName = _kick_action
	_kick_action = &""
	lockout = 0.0
	if not can_reach(Tuning.player.touch_reach + 0.5):
		# La pelota se alejo durante el balanceo: la patada se pierde en el aire.
		lockout = 0.3
		owner.ctx.emit_event(GameEvent.make(GameEvent.Type.KICK_WHIFF, owner.actor_id, owner.team, {"action": String(action)}))
		return
	perform_action(action, _kick_stick, _kick_charge, _kick_lob)

## Ejecuta el golpeo de una accion (pase, filtrado, centro o tiro) en el instante de contacto.
func perform_action(action: StringName, stick_world: Vector3, charge: float, lob: bool) -> KickModel.KickResult:
	if shot_curl == 0.0:
		shot_curl = _kick_curl
	_kick_curl = 0.0
	match action:
		&"pass":
			return perform_pass(stick_world, charge, lob)
		&"through":
			return perform_through(stick_world, charge, lob)
		&"cross":
			return perform_cross(stick_world, charge, lob)
		_:
			return perform_shot(stick_world, charge, lob)

## Pase filtrado: al espacio por delante del desmarque del receptor.
func perform_through(stick_world: Vector3, charge: float, lob: bool) -> KickModel.KickResult:
	var ctx: MatchContext = owner.ctx
	var res: KickModel.KickResult = PassAssist.compute_through(owner, ctx, stick_world, charge, lob, rng, assist_pass_level())
	ball().kick(res.velocity, res.spin, owner)
	_after_kick(&"pass", res)
	var data: Dictionary = {"target": res.target.actor_id if res.target != null else -1, "kind": String(res.kind),
		"charge": charge, "error_deg": res.error_deg, "speed": res.velocity.length(), "through": true,
		"aim": [res.aim_point.x, res.aim_point.z]}
	data.merge(_kick_event_info)
	ctx.emit_event(GameEvent.make(GameEvent.Type.PASS, owner.actor_id, owner.team, data))
	return res

## Centro al area: con ALTO sale raso; con carga alta, tenso; si no, elevado.
func perform_cross(stick_world: Vector3, charge: float, low: bool) -> KickModel.KickResult:
	var ctx: MatchContext = owner.ctx
	var res: KickModel.KickResult = CrossAssist.compute(owner, ctx, stick_world, charge, low, rng, assist_pass_level(), shot_curl)
	shot_curl = 0.0
	ball().kick(res.velocity, res.spin, owner)
	_after_kick(&"pass", res)
	var data: Dictionary = {"target": res.target.actor_id if res.target != null else -1, "kind": String(res.kind),
		"charge": charge, "error_deg": res.error_deg, "speed": res.velocity.length(), "cross": true,
		"aim": [res.aim_point.x, res.aim_point.z]}
	data.merge(_kick_event_info)
	ctx.emit_event(GameEvent.make(GameEvent.Type.PASS, owner.actor_id, owner.team, data))
	return res

## Ejecuta un pase ahora mismo (la pelota debe estar a alcance). Devuelve el resultado.
func perform_pass(stick_world: Vector3, charge: float, lob: bool) -> KickModel.KickResult:
	var ctx: MatchContext = owner.ctx
	var res: KickModel.KickResult = PassAssist.compute(owner, ctx, stick_world, charge, lob, rng, assist_pass_level())
	var b: Ball = ball()
	b.kick(res.velocity, res.spin, owner)
	_after_kick(&"pass", res)
	var data: Dictionary = {
		"target": res.target.actor_id if res.target != null else -1,
		"kind": String(res.kind), "charge": charge, "error_deg": res.error_deg,
		"weak_foot": res.weak_foot, "speed": res.velocity.length(),
		"assisted_deg": res.assisted_correction_deg,
	}
	data.merge(_kick_event_info)
	ctx.emit_event(GameEvent.make(GameEvent.Type.PASS, owner.actor_id, owner.team, data))
	return res

func perform_shot(stick_world: Vector3, charge: float, lob: bool) -> KickModel.KickResult:
	var ctx: MatchContext = owner.ctx
	var res: KickModel.KickResult = ShotAssist.compute(owner, ctx, stick_world, charge, lob, rng, assist_shot_level(), shot_curl)
	shot_curl = 0.0
	var b: Ball = ball()
	b.kick(res.velocity, res.spin, owner)
	if res.knuckle_accel > 0.0:
		b.set_knuckle(res.knuckle_accel, res.knuckle_freq, res.knuckle_phase)
	_after_kick(&"shot", res)
	var data: Dictionary = {
		"kind": String(res.kind), "charge": charge, "error_deg": res.error_deg,
		"weak_foot": res.weak_foot, "speed": res.velocity.length(),
		"predicted_on_target": res.on_target, "assisted_deg": res.assisted_correction_deg,
		"dir": [res.final_dir.x, res.final_dir.z], "curl": res.curl,
	}
	data.merge(_kick_event_info)
	ctx.emit_event(GameEvent.make(GameEvent.Type.SHOT, owner.actor_id, owner.team, data))
	return res

func _after_kick(action: StringName, res: KickModel.KickResult) -> void:
	last_result = res
	# El receptor de un pase sabe a donde va la pelota: corre a ese punto (el pase no le cae del cielo).
	if action == &"pass" and res.target != null and is_instance_valid(res.target) and res.target != owner:
		res.target.expect_pass(res.aim_point, res.kind, owner)
	_last_kick_frame = Engine.get_physics_frames()
	lockout = Tuning.player.kick_lockout
	touch_timer = lockout
	# Patear desequilibra levemente: pierde algo de velocidad.
	owner.locomotion.velocity *= 0.9
	kicked.emit(action, res)

# --- Pies animados (esqueleto vivo) ------------------------------------------------

## Distancia (m) maxima entre la punta del pie animado y el centro de la pelota para que el pie la toque.
const FOOT_CONTACT := 0.28
## Altura (m) maxima de la punta del pie para contar como toque raso.
const FOOT_MAX_Y := 0.20
## La pelota se deja esta distancia (m) por delante del alcance de la punta del pie (radio de la pelota y holgura).
const FOOT_BALL_LEAD := 0.10
## Segundos maximos sin pie en la pelota antes de tocarla igual si se escapa junto al cuerpo.
const FOOT_WAIT_MAX := 0.30
## true cuando el esqueleto del jugador se esta animando de verdad (en partido, no en pruebas headless).
var feet_live: bool = false
var _toe_ids: Array[int] = []
var _leg_bone: int = -1
static var _headless: bool = DisplayServer.get_name() == "headless"
var _toe_sk_prev: Vector3 = Vector3.ZERO
var _toe_now: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Tobillos (hueso del pie) para medir el contacto con todo el pie, no solo con la punta (ver foot_distance).
var _ankle_ids: Array[int] = []
var _ankle_now: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _toe_prev: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _toe_vel: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_reach: float = 0.45
var _reach_peak: float = 0.45
var _foot_wait: float = 0.0
## Empieza como "quieto": los pies solo se consideran vivos cuando se ve moverse el esqueleto.
var _still_frames: int = 30
var _dt: float = 1.0 / 60.0
## Toques de conduccion dados con el pie animado y distancia pie-pelota del ultimo (diagnostico y pruebas).
var foot_touches: int = 0
var last_touch_foot_distance: float = -1.0
## Medida separada de la punta: un contacto con el interior no ocurre necesariamente en la punta del botin.
var last_touch_toe_distance: float = -1.0
## Pie del ultimo toque de conduccion: 0 izquierdo, 1 derecho, -1 toque sin pie del esqueleto cerca (rescate o sin
## esqueleto vivo). Solo diagnostico y pruebas.
var last_touch_foot: int = -1

func get_dt() -> float:
	return _dt

## Lee las puntas de los pies del esqueleto animado. Si no se mueven (headless, maniqui) feet_live queda en false y la
## conduccion usa la cadencia de la marcha.
func _sample_feet(dt: float) -> void:
	_dt = dt
	var v: FootballerVisual = owner.visual
	if v == null or v.is_placeholder or v.skeleton == null:
		feet_live = false
		return
	var sk: Skeleton3D = v.skeleton
	if _toe_ids.is_empty():
		_toe_ids = [sk.find_bone("mixamorig_LeftToeBase"), sk.find_bone("mixamorig_RightToeBase")]
		_ankle_ids = [sk.find_bone("mixamorig_LeftFoot"), sk.find_bone("mixamorig_RightFoot")]
		_leg_bone = sk.find_bone("mixamorig_LeftUpLeg")
		if _toe_ids[0] < 0 or _toe_ids[1] < 0:
			_toe_ids = []
			return
	# El esqueleto esta vivo si la punta del pie se mueve en el espacio del propio esqueleto (solo la animacion la mueve:
	# ni la inclinacion del cuerpo ni el desplazamiento del jugador). En headless la pose global no se recalcula.
	var toe_sk: Vector3 = sk.get_bone_global_pose(_toe_ids[0]).origin
	var moved: bool = _toe_sk_prev != Vector3.ZERO and toe_sk.distance_to(_toe_sk_prev) > 0.001
	_toe_sk_prev = toe_sk
	var body_v := Vector3(owner.locomotion.velocity.x, 0.0, owner.locomotion.velocity.z)
	var fwd: Vector3 = owner.locomotion.forward()
	var best_fwd: float = -INF
	for i in 2:
		_toe_prev[i] = _toe_now[i]
		_toe_now[i] = sk.global_transform * sk.get_bone_global_pose(_toe_ids[i]).origin
		_ankle_now[i] = sk.global_transform * sk.get_bone_global_pose(_ankle_ids[i]).origin if _ankle_ids.size() == 2 and _ankle_ids[i] >= 0 else _toe_now[i]
		_toe_vel[i] = (_toe_now[i] - _toe_prev[i]) / maxf(dt, 0.001) - body_v
		var rel: Vector3 = _toe_now[i] - owner.global_position
		if _toe_now[i].y < FOOT_MAX_Y:
			best_fwd = maxf(best_fwd, rel.dot(fwd))
	_still_frames = 0 if moved else _still_frames + 1
	# El esqueleto se considera vivo si las puntas se movieron respecto al cuerpo en el ultimo medio segundo.
	# En headless (servidor, pruebas sin render) la pose no es fiable: se usa la cadencia de la marcha.
	feet_live = foot_sync_enabled and _still_frames < 30 and not _headless

	# Alcance de la zancada: maximo reciente de la punta del pie apoyada/baja por delante del cuerpo.
	_reach_peak = maxf(_reach_peak - 0.5 * dt, best_fwd if best_fwd > -INF else 0.0)
	_foot_reach = clampf(_reach_peak, 0.2, 0.9)

## Distancia (m) del centro de la pelota al pie i (segmento del tobillo a la punta).
func foot_distance(i: int, ball_pos: Vector3) -> float:
	var a: Vector3 = _ankle_now[i]
	var bb: Vector3 = _toe_now[i]
	var ab: Vector3 = bb - a
	var l2: float = ab.length_squared()
	if l2 < 0.0001:
		return bb.distance_to(ball_pos)
	var u: float = clampf((ball_pos - a).dot(ab) / l2, 0.0, 1.0)
	return (a + ab * u).distance_to(ball_pos)

## Pie (0 izquierdo, 1 derecho) que puede tocar la pelota ahora: punta baja, a FOOT_CONTACT de la pelota, por detras de
## ella y yendo hacia delante (o casi quieta) respecto al cuerpo. -1 si ninguno.
func _foot_strike(b: Ball, mode: StringName, close_in: bool = false) -> int:
	var fwd: Vector3 = owner.locomotion.forward()
	var push_dir: Vector3 = fwd if (mode == &"carry" or mode == &"setup") else KickModel.flat(b.global_position - owner.global_position).normalized()
	# Parar la pelota (settle sin rival): el pie tiene que llegar de verdad (antes 1.4 veces: tocaba a 0.38 m del centro de la
	# pelota sin que el jugador se acercara). Llevarla de costado, girar o protegerla: un paso llega mas lejos.
	var settle_plain: bool = mode == &"settle" and owner.is_human_controlled and _shield_dir(KickModel.flat(b.global_position - owner.global_position).length()).length_squared() < 0.01
	var radius: float = FOOT_CONTACT * (SETTLE_STRIKE_SCALE if settle_plain else (1.4 if mode == &"settle" or mode == &"lateral" or mode == &"redirect" or close_in else 1.0))
	if close_in:
		# Pelota pegada al cuerpo: la toca el pie que este encima, sin exigir que vaya hacia delante (la empuja o la arrastra).
		mode = &"near"
	var best: int = -1
	var best_d: float = radius
	for i in 2:
		var toe: Vector3 = _toe_now[i]
		if toe.y > FOOT_MAX_Y:
			continue
		# Distancia al PIE (segmento tobillo-punta), no solo a la punta: un toque con el interior o el empeine tiene la
		# pelota junto al pie aunque lejos de la punta (en curva los toques se daban por "sin pie").
		var d: float = foot_distance(i, b.global_position)
		if d > best_d:
			continue
		if (mode == &"carry" or mode == &"setup") and ((b.global_position - toe).dot(push_dir) < -0.06 or _toe_vel[i].dot(fwd) < -0.6):
			continue
		best_d = d
		best = i
	return best

# --- Conduccion ------------------------------------------------------------
##
## Modelo de control cercano. Una sola ley define la sensacion: la pelota se coloca a `carry_gap()` metros del pie,
## y esa distancia crece con la velocidad (parado queda pegada, a sprint se empuja lejos). Cada toque es un IMPULSO
## calculado para que la pelota llegue a ese punto justo cuando el jugador llega alli.
##
## Modos de toque (los elige `_touch_mode`):
##  - settle: el joystick esta suelto -> para la pelota junto al pie (pisada). Si hay un rival cerca, la coloca del
##    lado contrario y el cuerpo se interpone (proteccion).
##  - lateral: el joystick apunta de costado a poca velocidad -> empuja la pelota al costado manteniendo el cuerpo
##    orientado (control lateral). El cuerpo mantiene su orientacion durante `lateral_hold_seconds`.
##  - redirect: cambio de rumbo amplio -> la pelota se lleva hacia el rumbo nuevo, mas pegada al pie.
##  - carry: conduccion normal (caminar, trotar, correr, sprint).

## Zona del pie: donde un pie llega a la pelota sin dar un paso (por delante del cuerpo, poco al costado). Para parar
## la pelota, llevarla de costado o girar con ella cuenta tambien el costado del cuerpo (interior / exterior / suela).
const FOOT_ZONE_FWD := 0.62
const FOOT_ZONE_BACK := -0.05
const FOOT_ZONE_LAT := 0.34
## Pelota a menos de esto por delante del centro del cuerpo: el cuerpo se le viene encima y el pie la toca igual.
const OVERRUN_FWD := 0.18
## Parar la pelota con el joystick suelto (settle): zona del pie (m, delante del cuerpo y al costado) donde el pie que llega
## la para, y zona comoda donde el jugador la deja quieta (settle_steer: fuera de ella el jugador se gira y da los pasos).
const SETTLE_ZONE_BACK := -0.05
const SETTLE_ZONE_LAT := 0.40
const SETTLE_COMFY_MIN := 0.12
const SETTLE_COMFY_MAX := 0.70
const SETTLE_COMFY_LAT := 0.30
## Velocidad (m/s) de la pelota por encima de la cual se va: el jugador la sigue.
const SETTLE_STILL_SPEED := 0.35
## Radio de contacto del pie al parar la pelota (multiplica FOOT_CONTACT).
const SETTLE_STRIKE_SCALE := 1.1
## Pelota quieta a menos de esto (m) del centro del cuerpo, delante: esta entre los pies (controlada).
const SETTLE_UNDER := 0.30
## Velocidad (m/s) minima de los pasos con que el jugador se acomoda a la pelota.
const SETTLE_STEP_SPEED := 0.35

func _ball_at_foot(off: Vector3, fwd: Vector3, mode: StringName) -> bool:
	var ahead: float = off.dot(fwd)
	var lat: float = absf(off.dot(Vector3(-fwd.z, 0.0, fwd.x)))
	var reach_fwd: float = FOOT_ZONE_FWD + 0.14 * _sprint_ratio()
	if mode == &"settle" and owner.is_human_controlled and _shield_dir(off.length()).length_squared() < 0.01:
		# Parar la pelota (joystick suelto, sin rival encima; jugador de la persona): solo la que esta delante del cuerpo, al alcance de un paso. Al
		# costado o detras no se la trae: el jugador va a ella (settle_steer) y la para el pie que llega. Antes esta zona
		# llegaba a 0.62 m al costado y 0.35 m detras y la pelota se movia sola hasta delante del cuerpo (video del usuario
		# 05-11 04:42:20, prueba physical_dribble::released_stick: jugador quieto 0.00 m, pelota llevada a 0.38 m delante).
		var slow_s: float = clampf(owner.locomotion.speed / maxf(Tuning.player.walk_speed, 0.1), 0.0, 1.0)
		var step_s: float = lerpf(touch_reach() * 0.95, reach_fwd, slow_s)
		return ahead > SETTLE_ZONE_BACK and ahead < maxf(reach_fwd, step_s) and lat < SETTLE_ZONE_LAT
	if mode == &"settle" or mode == &"lateral" or mode == &"redirect":
		# Parado o caminando, para llevarla de costado, girar con ella o protegerla el jugador da un paso: llega mas lejos.
		# (Proteger la pelota parado: el cuerpo se da vuelta y la pelota queda a medio metro del costado, al alcance de la
		# suela o el interior.)
		var slow: float = clampf(owner.locomotion.speed / maxf(Tuning.player.walk_speed, 0.1), 0.0, 1.0)
		var step_reach: float = lerpf(touch_reach() * 0.95, reach_fwd, slow)
		return ahead > lerpf(-0.35, -0.25, slow) and ahead < maxf(reach_fwd, step_reach) and lat < lerpf(0.62, 0.46, slow)
	return ahead > FOOT_ZONE_BACK and ahead < reach_fwd and lat < FOOT_ZONE_LAT

## Giro maximo (grados) que un toque puede dar a la pelota a esta velocidad: caminando casi cualquiera, a sprint poco
## (un cambio de rumbo mayor se hace en varios toques). Mejor conduccion gira algo mas.
func touch_turn_max_deg(speed: float) -> float:
	var t: PlayerTuning = Tuning.player
	var d: float
	if speed <= t.walk_speed:
		d = lerpf(170.0, t.touch_turn_walk_deg, clampf(speed / maxf(t.walk_speed, 0.1), 0.0, 1.0))
	elif speed <= t.jog_speed:
		d = lerpf(t.touch_turn_walk_deg, t.touch_turn_jog_deg, (speed - t.walk_speed) / maxf(t.jog_speed - t.walk_speed, 0.1))
	else:
		d = lerpf(t.touch_turn_jog_deg, t.touch_turn_sprint_deg, clampf((speed - t.jog_speed) / maxf(t.sprint_speed - t.jog_speed, 0.1), 0.0, 1.0))
	return d * lerpf(0.85, 1.15, _carry_skill())

## Gira `from` hacia `to` como mucho `max_rad` (en el plano).
static func turn_toward(from: Vector3, to: Vector3, max_rad: float) -> Vector3:
	var a: Vector3 = KickModel.flat(from).normalized()
	var b: Vector3 = KickModel.flat(to).normalized()
	if a.length_squared() < 0.5 or b.length_squared() < 0.5:
		return b if b.length_squared() > 0.5 else a
	var ang: float = a.signed_angle_to(b, Vector3.UP)
	if absf(ang) <= max_rad:
		return b
	return a.rotated(Vector3.UP, signf(ang) * max_rad)

## Distancia (m) a la que el jugador quiere la pelota respecto al pie a una velocidad dada. Ley de tres tramos
## (parado / trote / sprint) con los valores de PlayerTuning; la habilidad de conduccion la acerca.
func carry_gap(speed: float, skill: float) -> float:
	var t: PlayerTuning = Tuning.player
	var g: float
	if speed <= t.jog_speed:
		g = lerpf(t.carry_gap_stand, t.touch_lead_jog, clampf(speed / maxf(t.jog_speed, 0.1), 0.0, 1.0))
	else:
		g = lerpf(t.touch_lead_jog, t.touch_lead_sprint, clampf((speed - t.jog_speed) / maxf(t.sprint_speed - t.jog_speed, 0.1), 0.0, 1.0))
	return g * lerpf(1.12, 0.9, clampf(skill, 0.0, 1.0))

func _carry_skill() -> float:
	return 0.5 * owner.attributes.norm("ball_control") + 0.5 * owner.attributes.norm("ball_carrying")

## Segundos entre toques. Con el pack, la cadencia sigue a la de los pasos de la animacion (uno por apoyo a trote,
## uno cada dos apoyos a carrera/sprint); sin el, los valores fijos de PlayerTuning.
func _touch_interval(ratio: float) -> float:
	var t: PlayerTuning = Tuning.player
	var fixed: float = lerpf(t.touch_interval_jog, t.touch_interval_sprint, ratio)
	var v: FootballerVisual = owner.visual
	if v == null or not v.uses_pack or v.is_placeholder:
		return fixed
	var step: float = FootballerVisual.step_interval_for(owner.locomotion.speed, true)
	if step <= 0.0:
		return fixed
	# Con pies vivos se toca en cada apoyo hasta la carrera (el pie que llega a la pelota) y cada dos a sprint.
	var every: float = (1.0 if ratio < 0.6 else 2.0) if feet_live else (1.0 if ratio < 0.2 else 2.0)
	return clampf(step * every, 0.18 if feet_live else 0.2, 0.6)

## Rival mas cercano a este jugador dentro de `radius` (o null). Lo usan la proteccion y el calculo de presion.
func nearest_opponent(radius: float) -> Footballer:
	var ctx: MatchContext = owner.ctx
	if ctx == null:
		return null
	var best: Footballer = null
	var best_d: float = radius
	for o in ctx.footballers:
		if o.team == owner.team or o == owner:
			continue
		var d: float = KickModel.flat(o.global_position - owner.global_position).length()
		if d < best_d:
			best_d = d
			best = o
	return best

## Modo del proximo toque segun la intencion del joystick y el estado del cuerpo.
func _touch_mode(desired_dir: Vector3, stick_mag: float, turn_angle: float) -> StringName:
	var t: PlayerTuning = Tuning.player
	var loco: Locomotion = owner.locomotion
	# Con un golpeo pedido, o cargandose en carrera, el toque PREPARA el golpeo (pelota cerca del pie) y no la manda
	# lejos. Parado y cargando no se toca la pelota (se golpea donde esta).
	if _pending_action != &"" or ((_pass_active or _shoot_active or _through_active or _cross_active) and stick_mag >= 0.18):
		return &"setup"
	if stick_mag < 0.18:
		return &"settle"
	if _lateral_hold > 0.0:
		return &"lateral"
	if turn_angle > 55.0:
		return &"redirect"
	if loco.speed > t.jog_speed and stick_mag > 0.9:
		return &"carry"
	return &"carry"

## Pelota quieta apoyada sobre el cuerpo (encajada entre las cabezas u hombros de dos jugadores pegados, o a la altura
## de la cadera entre dos rivales que empujan): nadie puede tocarla con el pie y el partido se trababa (medido: 436 s en
## un partido de 10 min con la pelota en los hombros; 169 s en uno de 5 min con la pelota a 0.73 m). El jugador sobre el
## que descansa se la quita con la cabeza, el hombro o el muslo: un toque real, hacia fuera y algo hacia arriba.
## RESTING_BALL_MIN_Y: altura minima (m) del centro de la pelota sobre los pies (en el suelo esta a 0.1).
const RESTING_BALL_MIN_Y := 0.45
func _shrug_resting_ball() -> bool:
	var b: Ball = ball()
	if b == null or b.is_held() or owner.ctx.ball_locked_for(owner):
		return false
	var t: PlayerTuning = Tuning.player
	var y: float = b.global_position.y - owner.global_position.y
	var off: Vector3 = ball_offset()
	if y < RESTING_BALL_MIN_Y or y > t.capsule_height + 0.35 or b.linear_velocity.length() > RESTING_BALL_SPEED or off.length() > t.capsule_radius + 0.3:
		_resting_time = 0.0
		return false
	_resting_time += get_dt()
	if _resting_time < RESTING_BALL_SECONDS:
		return false
	_resting_time = 0.0
	var out: Vector3 = off.normalized() if off.length() > 0.05 else owner.locomotion.forward()
	# Encajada entre dos cuerpos: hacia fuera del hueco (de lado respecto a la linea entre los dos), no contra el otro
	# (rebotaba y volvia: 7 s en un partido de 5 min).
	var other: Footballer = _body_partner(b, t.capsule_radius + 0.35)
	if other != null:
		var line: Vector3 = KickModel.flat(other.global_position - owner.global_position)
		if line.length() > 0.05:
			line = line.normalized()
			var perp: Vector3 = off - line * off.dot(line)
			out = perp.normalized() if perp.length() > 0.03 else Vector3(-line.z, 0.0, line.x)
	var v: Vector3 = out * 2.2 + Vector3.UP * 1.2
	b.kick(v, Vector3.ZERO, owner)
	touch_timer = 0.3
	last_touch_foot = -1
	last_touch_foot_distance = -1.0
	last_touch_toe_distance = -1.0
	touched_ball.emit(&"body")
	return true

## Otro jugador (de cualquier equipo) con la pelota apoyada tambien en su cuerpo (a menos de radius en el plano), o null.
func _body_partner(b: Ball, radius: float) -> Footballer:
	var ctx: MatchContext = owner.ctx
	if ctx == null:
		return null
	var best: Footballer = null
	var best_d: float = radius
	for o in ctx.footballers:
		if o == owner:
			continue
		var d: float = KickModel.flat(o.global_position - b.global_position).length()
		if d < best_d:
			best_d = d
			best = o
	return best

# --- Toques con clip (animacion de toque: el pie sale a buscar la pelota) ------------------------------------------
##
## Con el esqueleto vivo y una libreria de toques (la de Mixamo se borro el 2026-11-08) la conduccion en
## carrera se hace con TOQUES DE CLIP, un clip por balanceo de cada pie del ciclo de marcha con pelota:
## 1. Disparo EN FASE: cuando la fase del ciclo base que se esta reproduciendo (FootballerVisual.carry_phase) llega al
##    inicio del clip, el toque se reproduce en la capa de esa pierna; asi coincide con el balanceo para el que se hizo
##    (misma cadera) y la pierna no salta.
## 2. Plan: solo se dispara si, siguiendo el recorrido medido de la punta del clip y la pelota prevista (velocidad y
##    frenado), la punta alcanza la pelota baja, centrada con ese pie y dentro de la ventana del toque.
## 3. Contacto por evento: en cada paso se mira la punta VIVA (prevista para la imagen que se va a dibujar: el
##    esqueleto se lee un proceso tarde); el impulso se aplica en el paso en que llega a la parte de atras de la pelota.
##    Si la ventana acaba o la punta pasa sin tocarla, no hay impulso (toque fallado, sin teletransporte).
## 4. El impulso deja la pelota donde ese mismo pie la tocara en su siguiente balanceo (el cuerpo sigue a su velocidad).
## Mientras la conduccion va sincronizada no hay toques de pisada (la pelota no pasa de un pie al otro). Giros grandes,
## parada, golpeos pedidos y la pelota que se escapa siguen con la conduccion de siempre.

## Interruptor global (pruebas comparativas).
static var clip_touches_enabled: bool = true
## Distancia lateral (m) maxima entre la punta del clip y el centro de la pelota prevista para disparar un toque (con
## la pelota algo de lado la toca el interior o el exterior del pie: medio ancho del pie + parte del radio).
const TOUCH_LAT_TOL := 0.13
## Altura (m) maxima de la punta del clip al alcanzar la pelota (mas alta la pincharia por arriba).
const TOUCH_MAX_TOE_Y := 0.15
## Metros que la punta del clip puede seguir avanzando (respecto al cuerpo) despues del contacto planeado: la pelota
## tocada sale casi a la velocidad del cuerpo, asi que un pie que sigue mas alla de eso la atravesaria.
const TOUCH_MAX_FOLLOW := 0.07
## Ventana del contacto (s de clip): desde TOUCH_EARLY antes del contacto de diseno del clip hasta TOUCH_LATE despues de
## su maxima extension.
const TOUCH_EARLY := 0.10
const TOUCH_LATE := 0.04
## Contacto vivo: la punta llega a la parte de atras de la pelota (hueco <= radio + TOUCH_GAP en la direccion del toque),
## a menos de TOUCH_LIVE_LAT de lado y a menos de TOUCH_LIVE_Y de altura.
const TOUCH_GAP := 0.03
const TOUCH_LIVE_LAT := 0.15
const TOUCH_LIVE_Y := 0.18
## Correccion maxima (m) del pie con el IK del toque (TouchFootIK), hacia delante (la pierna ya va casi estirada) y de
## lado (tocar con el interior o el exterior del pie en curva; en recta solo un ajuste, para que el pie no cruce a la
## linea del otro): el plan acepta la pelota hasta esa distancia del recorrido del clip y en el toque el pie se lleva a
## la pelota real.
const TOUCH_IK_FWD := 0.06
const TOUCH_IK_LAT := 0.15
const TOUCH_IK_LAT_STRAIGHT := 0.05
## Lateral (m) que queda entre la punta corregida y el centro de la pelota como mucho (el resto lo pone el IK).
const TOUCH_IK_RESIDUAL := 0.08
## Entrada (s de clip, antes del contacto planeado) y salida (s, despues del contacto) del peso de la correccion.
const TOUCH_IK_IN := 0.12
const TOUCH_IK_OUT := 0.12
## Velocidad (m/s) minima del cuerpo para conducir con toques de clip (mas despacio: control de pisadas).
const TOUCH_MIN_SPEED := 1.6
## Giro (grados) del joystick respecto al cuerpo por encima del cual manda la conduccion de giro.
const TOUCH_MAX_TURN := 50.0
## Periodos de balanceo sin toque de clip tras los que se vuelve a la conduccion por pisadas.
const TOUCH_SYNC_KEEP := 1.6
## Toques de clip por ciclo base (cache): base -> [{clip, foot, contact, aim, t0, base_len, touch_time, peak_time, path,
## path_dt, gaps}].
static var _touch_cache: Dictionary = {}

## Vacia los datos calculados con la libreria de clips (cambian al cambiar de modo).
static func reset_caches() -> void:
	_bbox_cache = {}
	_touch_cache = {}
	_samples_cache = {}

var _touch_active: Dictionary = {}
var _touch_sync: float = 0.0
## Salida de la correccion del pie tras el toque: {foot, shift (mundo), weight}.
var _ik_fade: Dictionary = {}
## Velocidad (m/s) que pide el joystick con la pelota al pie (hacia ella acelera el cuerpo mientras dura el toque).
var _touch_target_speed: float = 0.0
## Velocidad (rad/s, suavizada) a la que gira el joystick: en un eslalon el rumbo pedido sigue girando y la prediccion
## del cuerpo lo extrapola un poco (0.3 s).
var _desired_yaw_rate: float = 0.0
var _desired_yaw_prev: float = INF
## Giro del joystick (rad/s) que se cuenta como mucho al extrapolar (un eslalon rapido gira ~1 rad/s).
const TOUCH_STICK_RATE_MAX := 1.0
## Rumbo pedido respecto al cuerpo (grados) o giro del cuerpo (rad/s) a partir de los que la conduccion va en curva:
## la pelota se deja centrada entre los pies y la toca el siguiente balanceo de cualquiera de los dos.
const TOUCH_CURVE_DEG := 8.0
const TOUCH_CURVE_RATE := 0.25
const TOUCH_SHARP_DEG := 25.0

## Segundos que la conduccion sigue en modo curva despues de acabar el giro (la pelota todavia va de lado).
const TOUCH_CURVE_HOLD := 0.5
## Control cercano (como First Touch Soccer y el video de referencia): por debajo de esta velocidad (m/s, el ciclo de
## conduccion al trote) la pelota va pegada al pie, centrada entre los pies, y la toca el siguiente balanceo de
## cualquiera de los dos (un toque por paso); por encima, un toque por zancada con el mismo pie.
const CLOSE_CONTROL_SPEED := 3.2
var _curving: bool = false
## true en control cercano (ver CLOSE_CONTROL_SPEED).
var _close_control: bool = false
var _curve_hold: float = 0.0
## Diagnostico: toques de clip con contacto y toques de clip sin pie en la pelota (sin impulso).
var clip_touch_count: int = 0
var clip_touch_misses: int = 0
## Diagnostico del ultimo toque de clip al resolverse: clip, pie, ok, hueco y lateral punta-pelota, punta viva y pelota
## respecto al cuerpo, instante de clip del contacto y el previsto.
var last_clip_touch: Dictionary = {}
## Diagnostico: balanceos en fase descartados por el plan, por motivo (lejos, cerca, lado, alto, atraviesa).
var clip_plan_rejects: Dictionary = {}
var _plan_reject: String = ""
## Diagnostico: resultado del plan para cada variante del ultimo balanceo en fase.
var last_plan_debug: String = ""

static func touch_candidates(base: StringName) -> Array:
	if _touch_cache.has(base):
		return _touch_cache[base]
	var out: Array = []
	var lib: AnimationLibrary = PackLibrary.field()
	var base_anim: Animation = PackLibrary.clip(base)
	if lib != null and base_anim != null:
		for id in lib.get_animation_list():
			var m: Dictionary = PackLibrary.meta(id)
			if String(m.get("role", "")) != "toque" or StringName(String(m.get("base", ""))) != base:
				continue
			var con: Dictionary = m["contact"]
			out.append({"clip": id, "foot": int(m["foot"]), "contact": con["pos"], "t0": float(m["base_time0"]),
				"base_len": base_anim.length, "touch_time": float(con["time"]), "peak_time": float(m["peak_time"]),
				"path": con["path"], "path_dt": float(con["path_dt"])})
		# El impulso apunta al contacto de la variante _Near de cada balanceo: es el centro del rango de distancias que
		# recogen las variantes (de _Close a la central o _Far); apuntando a la central, que esta en el extremo lejano, un
		# pequeno exceso dejaba la pelota fuera del alcance del siguiente balanceo.
		# En curva se apunta al de la variante _Close: girando, la pelota va mas pegada al pie.
		var central: Dictionary = {}
		var near: Dictionary = {}
		var close: Dictionary = {}
		for c in out:
			var name: String = String(c["clip"])
			if name.ends_with("_Near"):
				near[name.trim_suffix("_Near")] = c["contact"]
			elif name.ends_with("_Close"):
				close[name.trim_suffix("_Close")] = c["contact"]
			elif not name.ends_with("_Far"):
				central[name] = c["contact"]
		for c in out:
			var key: String = String(c["clip"]).trim_suffix("_Near").trim_suffix("_Far").trim_suffix("_Close")
			c["aim"] = near.get(key, central.get(key, c["contact"]))
			c["aim_curve"] = close.get(key, c["aim"])
		# Segundos de ciclo base hasta los siguientes balanceos del mismo pie (1, 2, 3...): el toque puede dejar la pelota
		# para cualquiera de ellos.
		for c in out:
			var gaps: Array[float] = [float(c["base_len"])]
			for o in out:
				if int(o["foot"]) == int(c["foot"]) and central.has(String(o["clip"])):
					var g: float = fposmod(float(o["t0"]) - float(c["t0"]), float(c["base_len"]))
					if g > 0.05 and g < float(c["base_len"]) - 0.05:
						gaps.append(g)
			gaps.sort()
			var n: int = gaps.size()
			for cyc in [1.0, 2.0]:
				for k in n:
					gaps.append(gaps[k] + cyc * float(c["base_len"]))
			c["gaps"] = gaps
			# En curva tambien vale el siguiente balanceo del otro pie (la pelota se deja centrada entre los dos).
			var any: Array[float] = gaps.duplicate()
			for o in out:
				if int(o["foot"]) != int(c["foot"]) and central.has(String(o["clip"])):
					var g2: float = fposmod(float(o["t0"]) - float(c["t0"]), float(c["base_len"]))
					any.append(g2)
					any.append(g2 + float(c["base_len"]))
			any.sort()
			c["gaps_any"] = any
	_touch_cache[base] = out
	return out

func uses_clip_touches() -> bool:
	var v: FootballerVisual = owner.visual
	return clip_touches_enabled and feet_live and v != null and v.uses_pack and not v.is_placeholder

## true si hay un toque de clip en curso (entre el disparo y el contacto).
func is_clip_touch_in_progress() -> bool:
	return not _touch_active.is_empty()

## Punto p respecto al cuerpo: (adelante, altura, derecha) en metros.
func _body_coords(p: Vector3) -> Vector3:
	var rel: Vector3 = p - owner.global_position
	return Vector3(rel.dot(owner.locomotion.forward()), p.y, rel.dot(owner.locomotion.right()))

## Punta del pie i respecto al cuerpo: (adelante, altura, derecha) en metros.
func _toe_body(i: int) -> Vector3:
	return _body_coords(_toe_now[i])

## Conduccion por toques de clip en marcha: con esqueleto vivo y fuera de la arrancada. Fuera de esto la conduccion por
## pisadas funciona exactamente como antes (sin relevo, sin distancia de clip y sin el freno de curva).
func _clip_driving() -> bool:
	return uses_clip_touches() and not _launching()

## Arrancada: SPRINT pedido lejos de la velocidad punta. Mandan los toques largos de arrancada de siempre (la pelota al
## espacio y el jugador acelerando detras), sin toques de clip ni relevo hacia ellos.
func _launching() -> bool:
	var loco: Locomotion = owner.locomotion
	return loco.sprinting and 1.0 - loco.speed / maxf(loco.max_sprint_speed(), 0.1) > ACCEL_TOUCH_KEEP_FRACTION

## Distancia (m) por delante del cuerpo a la que los toques de clip dejan la pelota a esta velocidad (centro de la
## pelota en el punto al que apuntan los clips del ciclo dominante); -1 si no hay toques de clip para ese ciclo.
static func clip_touch_gap(speed: float) -> float:
	var cands: Array = touch_candidates(FootballerVisual.carry_clip_for(speed))
	if cands.is_empty():
		return -1.0
	var sum := 0.0
	for c in cands:
		sum += (c["aim"] as Vector3).x
	return sum / cands.size() + Tuning.ball.radius + TOUCH_GAP

## Conduccion con la pelota pegada y toques de cualquier pie: en curva o en control cercano.
func _tight() -> bool:
	return _curving or _close_control

func _clip_touch_update(desired_dir: Vector3, stick_mag: float) -> bool:
	_touch_sync = maxf(_touch_sync - get_dt(), 0.0)
	_fade_touch_ik()
	var lo: Locomotion = owner.locomotion
	_touch_target_speed = minf(lo.max_sprint_speed() if lo.sprinting else lo.speed_for_magnitude(stick_mag), dribble_speed_cap())
	if absf(lo.turn_rate) > TOUCH_CURVE_RATE or (desired_dir.length_squared() > 0.01 and KickModel.angle_between_deg(lo.forward(), desired_dir) > TOUCH_CURVE_DEG):
		_curve_hold = TOUCH_CURVE_HOLD
	else:
		_curve_hold = maxf(_curve_hold - get_dt(), 0.0)
	_curving = _curve_hold > 0.0
	_close_control = _touch_target_speed < CLOSE_CONTROL_SPEED and not lo.sprinting
	if desired_dir.length_squared() > 0.01:
		var dy: float = Locomotion.yaw_from_dir(desired_dir.normalized())
		if _desired_yaw_prev < INF:
			# Filtro lento y tope bajo: un salto del joystick (cambio de carril) no es un giro continuo y no se extrapola.
			var rate_now: float = clampf(wrapf(dy - _desired_yaw_prev, -PI, PI) / maxf(get_dt(), 0.001), -TOUCH_STICK_RATE_MAX, TOUCH_STICK_RATE_MAX)
			_desired_yaw_rate = lerpf(_desired_yaw_rate, rate_now, 0.1)
		_desired_yaw_prev = dy
	else:
		_desired_yaw_prev = INF
		_desired_yaw_rate = 0.0
	if not _touch_active.is_empty():
		# Un giro brusco pedido a mitad del toque lo cancela (sin impulso): manda el toque de giro de siempre.
		if desired_dir.length_squared() > 0.01 and KickModel.angle_between_deg(lo.forward(), desired_dir) > TOUCH_MAX_TURN:
			_release_touch_ik(_touch_active)
			_touch_active = {}
			_touch_sync = 0.0
			return false
		_clip_touch_step()
		return true
	if not uses_clip_touches():
		return false
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 0.45 or b.last_toucher != owner or not is_dribbling():
		_touch_sync = 0.0
		return false
	if _pending_action != &"" or _pass_active or _shoot_active or _through_active or _cross_active or stick_mag < 0.18 or owner.visual.current_action != &"":
		_touch_sync = 0.0
		return false
	var loco: Locomotion = owner.locomotion
	var fwd: Vector3 = loco.forward()
	var has_dir: bool = desired_dir.length_squared() > 0.01
	if not _clip_driving() or loco.speed < TOUCH_MIN_SPEED or (has_dir and KickModel.angle_between_deg(fwd, desired_dir) > TOUCH_MAX_TURN):
		_touch_sync = 0.0
		return false
	var base: StringName = FootballerVisual.carry_clip_for(loco.speed)
	var cands: Array = touch_candidates(base)
	var phase: float = owner.visual.carry_phase(base)
	if cands.is_empty() or phase < 0.0:
		return false
	var scale: float = FootballerVisual.carry_scale_for(loco.speed)
	# El OneShot del toque arranca en 0 en el proximo proceso, en el que la marcha avanza `step`: se dispara en el paso
	# cuya fase siguiente queda a menos de medio proceso del inicio del clip.
	var step: float = get_dt() * scale
	# Entre las variantes de alcance del balanceo que empieza ahora, la que encuentra la pelota mas cerca de su contacto
	# de diseno (la punta a ras y en su punto de toque).
	var best: Dictionary = {}
	var best_plan: Dictionary = {}
	var why: String = ""
	var dbg: PackedStringArray = []
	var track := PackedVector3Array()
	# En recta, mientras la conduccion va sincronizada toca siempre el mismo pie (un toque por zancada); en curva y en
	# control cercano, cualquiera.
	var only_foot: int = last_touch_foot if (not _tight() and _touch_sync > 0.0 and last_touch_mode == &"clip") else -1
	for c in cands:
		var blen: float = float(c["base_len"])
		var to_start: float = fposmod(float(c["t0"]) - (phase + step), blen)
		if to_start > step * 0.5 and to_start < blen - step * 0.5:
			continue
		if only_foot >= 0 and int(c["foot"]) != only_foot:
			continue
		if track.is_empty():
			track = _predict_body(INF, 0.6, true, true)["track"]
		var plan: Dictionary = _plan_clip_touch(c, scale, b, track)
		dbg.append("%s:%s" % [c["clip"], _plan_reject if plan.is_empty() else "ok"])
		if plan.is_empty():
			why = _plan_reject
			continue
		if best.is_empty() or absf(float(plan["time"]) - float(c["touch_time"])) < absf(float(best_plan["time"]) - float(best["touch_time"])):
			best = c
			best_plan = plan
	if not dbg.is_empty():
		last_plan_debug = " ".join(dbg)
	if not best.is_empty():
		var f: int = int(best["foot"])
		if owner.visual.play_touch(best["clip"], f, scale):
			_touch_active = {"clip": best["clip"], "foot": f, "tau": 0.0, "contact": best["aim"], "contact_curve": best["aim_curve"], "gaps": best["gaps"], "gaps_any": best["gaps_any"],
				"t_lo": float(best["touch_time"]) - TOUCH_EARLY,
				"t_hi": float(best["peak_time"]) + TOUCH_LATE, "plan": best_plan, "curving": _tight()}
			return true
	elif why != "":
		clip_plan_rejects[why] = int(clip_plan_rejects.get(why, 0)) + 1
	# Conduccion sincronizada con los toques de clip: sin toques de pisada mientras la pelota siga delante y cerca.
	if _touch_sync > 0.0:
		var off: Vector3 = ball_offset()
		if off.length() < touch_reach() * 1.9 and off.dot(fwd) > 0.2:
			return true
		_touch_sync = 0.0
	return false

## Recorre la punta del clip c (en el cuerpo) frente a la pelota prevista y devuelve el primer punto de la ventana en que
## la alcanza: {time (s de clip), toe, ball}; vacio si no la alcanza baja y centrada sin atravesarla despues (motivo en
## _plan_reject: lejos, cerca, lado, alto o atraviesa).
func _plan_clip_touch(c: Dictionary, scale: float, b: Ball, track: PackedVector3Array) -> Dictionary:
	var bv: Vector3 = KickModel.flat(b.linear_velocity)
	# El cuerpo ya se movio en este paso (move_and_slide va antes de update) y la pelota aun no: se compara con la pelota
	# al final del paso.
	var b0: Vector3 = KickModel.flat(b.global_position + bv * get_dt())
	var brake: Vector3 = bv.normalized() if bv.length() > 0.05 else Vector3.ZERO
	var path: PackedVector3Array = c["path"]
	var pdt: float = float(c["path_dt"])
	var r: float = Tuning.ball.radius
	var i0: int = maxi(int(ceil((float(c["touch_time"]) - TOUCH_EARLY) / pdt)), 0)
	var i1: int = mini(int(floor((float(c["peak_time"]) + TOUCH_LATE) / pdt)), path.size() - 1)
	for i in range(i0, i1 + 1):
		var t: float = i * pdt / scale
		# Pelota y cuerpo previstos en ese instante (el cuerpo sobre su arco): pelota en los ejes del cuerpo de entonces.
		var bp: Vector3 = b0 + brake * Ball.roll_distance(bv.length(), t)
		var st: Vector3 = track[mini(int(round(t * 60.0)), track.size() - 1)]
		var f: Vector3 = Locomotion.dir_from_yaw(st.z)
		var rel: Vector3 = bp - Vector3(st.x, 0.0, st.y)
		var ball_f: float = rel.dot(f)
		var ball_r: float = rel.dot(Vector3(-f.z, 0.0, f.x))
		var toe: Vector3 = path[i]
		if toe.x + _ik_fwd() < ball_f - r - TOUCH_GAP:
			continue
		# La punta ya estaba pasada al empezar la ventana: la pelota esta demasiado cerca para este balanceo.
		var follow := 0.0
		for j in range(i, path.size()):
			follow = maxf(follow, path[j].x - toe.x)
		_plan_reject = "cerca" if i == i0 and toe.x > ball_f else ("lado" if absf(toe.z - ball_r) > _plan_lat_tol() else ("alto" if toe.y > TOUCH_MAX_TOE_Y else ("atraviesa" if follow > TOUCH_MAX_FOLLOW else "")))
		if _plan_reject != "":
			return {}
		return {"time": i * pdt, "index": i, "toe": toe, "ball": Vector3(ball_f, Tuning.ball.radius, ball_r)}
	_plan_reject = "lejos"
	return {}

## Cuerpo previsto con la misma ley que Locomotion: la velocidad va hacia la pedida (_touch_target_speed) con su
## aceleracion y el rumbo gira hacia el joystick con su velocidad de giro (en una curva el cuerpo recorre un arco, no la
## tangente); si el joystick esta girando, se extrapola ese giro durante 0.3 s. Integra hasta que el ciclo de marcha avanza base_period s de clip o pasan
## max_time s. Devuelve {time, pos (plano), yaw}; con keep_track, ademas "track": [(x, z, yaw)] por paso de 1/60 s
## desde el instante actual (indice 0). braked_turn: con el freno de giro con pelota actual.
func _predict_body(base_period: float, max_time: float, keep_track: bool = false, braked_turn: bool = false) -> Dictionary:
	var loco: Locomotion = owner.locomotion
	var t: PlayerTuning = loco.tuning
	var accel: float = t.accel * loco.attributes.factor("acceleration", 0.16)
	var decel: float = t.decel * loco.attributes.factor("acceleration", 0.16)
	# El freno de giro con pelota (carry_turn_scale) dura hasta el toque que lleva la pelota al rumbo nuevo: cuenta para
	# planear ese toque (braked_turn) pero no para decidir donde dejar la pelota despues de el.
	var agility: float = loco.attributes.factor("agility", 0.14) * (loco.turn_scale if braked_turn else 1.0)
	var v: float = loco.speed
	var target: float = _touch_target_speed
	var yaw: float = loco.yaw
	var want_yaw: float = Locomotion.yaw_from_dir(_desired_dir.normalized()) if _desired_dir.length_squared() > 0.01 else yaw
	var pos: Vector3 = KickModel.flat(owner.global_position)
	var h: float = 1.0 / 60.0
	var phase := 0.0
	var time := 0.0
	var track := PackedVector3Array()
	if keep_track:
		track.append(Vector3(pos.x, pos.z, yaw))
	while phase < base_period and time < max_time - 0.0001:
		if v < target:
			var headroom: float = clampf(1.0 - v / maxf(target, 0.1), 0.0, 1.0)
			v = minf(v + accel * lerpf(0.45, 1.0, headroom) * h, target)
		elif v > target:
			v = maxf(v - decel * h, target)
		var ratio: float = clampf(v / maxf(loco.max_sprint_speed(), 0.1), 0.0, 1.0)
		var rate: float = deg_to_rad(lerpf(t.turn_rate_standing, t.turn_rate_sprint, ratio * ratio)) * agility
		if time < 0.3:
			want_yaw += _desired_yaw_rate * h
		yaw += clampf(wrapf(want_yaw - yaw, -PI, PI), -rate * h, rate * h)
		pos += Locomotion.dir_from_yaw(yaw) * v * h
		phase += FootballerVisual.carry_scale_for(v) * h
		time += h
		if keep_track:
			track.append(Vector3(pos.x, pos.z, yaw))
	var out := {"time": time, "pos": pos, "yaw": yaw}
	if keep_track:
		out["track"] = track
	return out

## Punto del plano a `fwd` metros por delante y `side` a la derecha de un cuerpo en pos con rumbo yaw.
static func _body_point(pos: Vector3, yaw: float, fwd: float, side: float) -> Vector3:
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	return pos + f * fwd + Vector3(-f.z, 0.0, f.x) * side

func _foot_ik() -> TouchFootIK:
	var v: FootballerVisual = owner.visual
	return v.touch_ik if v != null else null

func _ik_fwd() -> float:
	return TOUCH_IK_FWD if _foot_ik() != null else 0.0

## En recta la pelota va en el carril del pie que la toca (un toque por zancada con el mismo pie, como en el video de
## referencia); en curva el IK la alcanza tambien de lado, con el interior o el exterior del pie.
func _plan_lat_tol() -> float:
	return TOUCH_IK_RESIDUAL + TOUCH_IK_LAT if _foot_ik() != null and _tight() else TOUCH_LAT_TOL

## Punta del pie i en el mundo tal como se dibuja (con la correccion del IK del toque).
func toe_world(i: int) -> Vector3:
	var ik: TouchFootIK = _foot_ik()
	return _toe_now[i] + (ik.applied_shift(i) if ik != null else Vector3.ZERO)

## Correccion del pie del toque en curso: del punto de contacto planeado del clip (sobre el cuerpo previsto en ese
## instante) al punto real de la pelota prevista entonces (detras de ella y en su linea), limitada y con un peso que
## sube hasta el contacto planeado.
func _update_touch_ik(a: Dictionary, b: Ball) -> void:
	var ik: TouchFootIK = _foot_ik()
	if ik == null:
		return
	var loco: Locomotion = owner.locomotion
	var plan: Dictionary = a["plan"]
	var tau: float = float(a["tau"])
	var plan_t: float = float(plan["time"])
	var t_rem: float = maxf(plan_t - tau, 0.0) / maxf(FootballerVisual.carry_scale_for(loco.speed), 0.05)
	var bv: Vector3 = KickModel.flat(b.linear_velocity)
	var brake: Vector3 = bv.normalized() if bv.length() > 0.05 else Vector3.ZERO
	var ball_c: Vector3 = KickModel.flat(b.global_position + bv * get_dt()) + brake * Ball.roll_distance(bv.length(), t_rem)
	var st: Dictionary = _predict_body(INF, t_rem, false, true)
	var f_c: Vector3 = Locomotion.dir_from_yaw(float(st["yaw"]))
	var r_c := Vector3(-f_c.z, 0.0, f_c.x)
	var toe_c: Vector3 = plan["toe"]
	var toe_w: Vector3 = _body_point(st["pos"], float(st["yaw"]), toe_c.x, toe_c.z)
	var d: Vector3 = ball_c - toe_w
	var fs: float = clampf(d.dot(f_c) - Tuning.ball.radius, -TOUCH_IK_FWD, TOUCH_IK_FWD)
	var lat_max: float = TOUCH_IK_LAT if bool(a.get("curving", false)) else TOUCH_IK_LAT_STRAIGHT
	var ls: float = clampf(d.dot(r_c), -lat_max, lat_max)
	var w: float = smoothstep(0.0, 1.0, (tau - (plan_t - TOUCH_IK_IN)) / TOUCH_IK_IN)
	ik.set_correction(int(a["foot"]), f_c * fs + r_c * ls, w)
	a["ik_shift"] = f_c * fs + r_c * ls
	a["ik_w"] = w

## Tras el toque la correccion se suelta en TOUCH_IK_OUT s (el pie vuelve al gesto del clip sin saltos).
func _fade_touch_ik() -> void:
	if _ik_fade.is_empty():
		return
	var ik: TouchFootIK = _foot_ik()
	var w: float = float(_ik_fade["weight"]) - get_dt() / TOUCH_IK_OUT
	if ik == null or w <= 0.0:
		if ik != null:
			ik.set_correction(int(_ik_fade["foot"]), Vector3.ZERO, 0.0)
		_ik_fade = {}
		return
	_ik_fade["weight"] = w
	ik.set_correction(int(_ik_fade["foot"]), _ik_fade["shift"], w)

func _release_touch_ik(a: Dictionary) -> void:
	if a.has("ik_shift"):
		_ik_fade = {"foot": int(a["foot"]), "shift": a["ik_shift"], "weight": float(a.get("ik_w", 0.0))}

## Un paso del toque de clip en curso: contacto cuando la punta viva llega a la pelota dentro de la ventana.
func _clip_touch_step() -> void:
	var a: Dictionary = _touch_active
	var loco: Locomotion = owner.locomotion
	a["tau"] = float(a["tau"]) + get_dt() * FootballerVisual.carry_scale_for(loco.speed)
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 0.45 or ball_owned_by_other():
		_release_touch_ik(a)
		_touch_active = {}
		return
	_update_touch_ik(a, b)
	var tau: float = float(a["tau"])
	if tau < float(a["t_lo"]):
		return
	var f: int = int(a["foot"])
	# Punta y pelota previstas para la imagen que se dibuja tras este paso (el esqueleto va un proceso por detras y se
	# lee sin la correccion del IK: se le suma la que se va a dibujar).
	var toe_p: Vector3 = _toe_now[f] + (_toe_now[f] - _toe_prev[f]) + (a.get("ik_shift", Vector3.ZERO) as Vector3) * float(a.get("ik_w", 0.0))
	var ball_p: Vector3 = b.global_position + b.linear_velocity * get_dt()
	# El pie avanza en el rumbo del cuerpo.
	var dir: Vector3 = loco.forward()
	var right: Vector3 = loco.right()
	var gap: float = KickModel.flat(ball_p - toe_p).dot(dir)
	var lat: float = KickModel.flat(ball_p - toe_p).dot(right)
	var r: float = Tuning.ball.radius
	# A sprint la punta avanza ~0.17 m por imagen: se toca en la imagen que deja la punta mas cerca de la parte de atras
	# de la pelota (esta, aunque aun le falte un poco, si en la siguiente ya estaria mas metida en la pelota).
	var closing: float = KickModel.flat((_toe_now[f] - _toe_prev[f]) - b.linear_velocity * get_dt()).dot(dir)
	var gap_next: float = gap - closing
	var reach_now: bool = gap <= r + TOUCH_GAP or (gap_next < r and r - gap_next > gap - r)
	var hit: bool = reach_now and absf(lat) <= TOUCH_LIVE_LAT and toe_p.y <= TOUCH_LIVE_Y and gap > -r
	var over: bool = tau > float(a["t_hi"]) or gap <= -r
	if not hit and not over:
		return
	last_clip_touch = {"clip": a["clip"], "foot": f, "ok": hit, "gap": gap - r, "lat": lat, "toe": _body_coords(toe_p),
		"ball": _body_coords(ball_p), "time": tau, "plan_time": float(a["plan"]["time"]), "d": foot_distance(f, b.global_position),
		"ik": a.get("ik_shift", Vector3.ZERO)}
	_release_touch_ik(a)
	_touch_active = {}
	if not hit:
		clip_touch_misses += 1
		return
	var con: Vector3 = a["contact"]
	# La pelota queda donde la tocara este mismo pie en uno de sus siguientes balanceos: delante del cuerpo previsto
	# entonces (a su velocidad y aceleracion y, en curva, sobre su arco y con su rumbo de entonces). Respecto al cuerpo
	# la pelota solo frena por la rodadura (a): para que llegue a su sitio sin pasarse (con velocidad relativa ~0)
	# necesita unos T* = raiz(2 * avance / a) segundos; se elige el balanceo mas cercano a T*. Con la pelota ya en su
	# sitio es el siguiente; si el cuerpo la alcanzo, uno o dos despues (un toque suave que la deja rodar, sin empujarla
	# de golpe por delante del siguiente balanceo).
	# En curva la pelota se deja centrada entre los pies y vale el siguiente balanceo de cualquiera de los dos (mas
	# toques, como un jugador que gira con la pelota); en recta, en el carril del pie que toca.
	var curving: bool = _tight()
	# Giro marcado (joystick a mas de TOUCH_SHARP_DEG del rumbo de la pelota) o control cercano: la pelota se deja mas
	# pegada (_Close); en curva suave, en el centro del rango (_Near).
	var bvn: Vector3 = KickModel.flat(b.linear_velocity)
	if _close_control or (curving and _desired_dir.length_squared() > 0.01 and bvn.length() > 1.0 and KickModel.angle_between_deg(bvn, _desired_dir) > TOUCH_SHARP_DEG):
		con = a["contact_curve"]
	var aim_x: float = con.x + r + TOUCH_GAP
	var aim_z: float = 0.0 if curving else con.z
	var advance: float = aim_x - KickModel.flat(b.global_position + b.linear_velocity * get_dt() - owner.global_position).dot(dir)
	var vp_now: float = loco.velocity.length()
	var t_star: float = Ball.roll_catch_time(advance, vp_now)
	# A sprint el toque puede pasarse (toque largo, como en la conduccion por pisadas: mismo termino, a la mitad como alli
	# y sin pasar de 1.2 alcances; entero perdia la pelota en los giros a sprint); con mejor control se pasa menos.
	if loco.sprinting and not curving:
		var ratio: float = _sprint_ratio()
		var overshoot: float = absf(rng.randfn(0.0, Tuning.player.touch_overshoot_sprint * (1.2 - _carry_skill()))) * ratio * ratio * 0.5
		overshoot = clampf(overshoot, 0.0, maxf(touch_reach() * 1.2 - aim_x, 0.0))
		aim_x += overshoot
		advance += overshoot
		t_star = Ball.roll_catch_time(advance, vp_now)
	# En curva, el siguiente balanceo de cualquier pie: mas lejos en el tiempo, el joystick ya habra cambiado (en un
	# eslalon se invierte) y la pelota quedaria fuera del arco real.
	var gaps: Array[float] = a["gaps_any"] if curving else a["gaps"]
	var next: Dictionary = _predict_body(gaps[0], 2.0)
	for k in range(1, 1 if curving else gaps.size()):
		var cand: Dictionary = _predict_body(gaps[k], 2.0)
		if absf(float(cand["time"]) - t_star) < absf(float(next["time"]) - t_star):
			next = cand
	var period: float = maxf(float(next["time"]), 0.25)
	var target: Vector3 = _body_point(next["pos"], float(next["yaw"]), aim_x, aim_z)
	# La pelota sale desde su posicion del paso anterior y se integra en este paso: recorre un paso mas que el cuerpo
	# (que ya se movio). Sin esto el toque se pasaba v*dt (0.11 m a sprint) del siguiente balanceo.
	var span: float = period + get_dt()
	var to_target: Vector3 = target - KickModel.flat(b.global_position)
	# Con la rodadura de la pelota (Ball: constante + proporcional a la velocidad) sale mas rapida que el cuerpo, se
	# adelanta y frena hasta que el pie la alcanza en ese balanceo: el empuje y la espera de cada toque.
	var v: Vector3 = to_target.normalized() * Ball.roll_speed_for(to_target.length(), span) if to_target.length() > 0.001 else Vector3.ZERO
	# Error del empuje del pie (menor con mejor control), aplicado a la velocidad relativa al cuerpo.
	var body_v: Vector3 = KickModel.flat(loco.velocity)
	var sigma: float = Tuning.player.touch_error_deg * (1.5 - 0.9 * _carry_skill()) * 0.6
	var rel: Vector3 = (v - body_v).rotated(Vector3.UP, deg_to_rad(KickModel.gaussian_clipped(rng, sigma)))
	v = body_v + rel
	b.kick(v, b.rolling_spin(v), owner)
	last_clip_touch["v"] = v.length()
	last_clip_touch["T"] = period
	clip_touch_count += 1
	foot_touches += 1
	dribble_touch_count += 1
	last_touch_foot = f
	last_touch_foot_distance = float(last_clip_touch["d"])
	last_touch_toe_distance = _toe_now[f].distance_to(b.global_position)
	last_touch_mode = &"clip"
	touch_timer = period * 0.7
	_touch_sync = period * TOUCH_SYNC_KEEP
	touched_ball.emit(&"carry")

## Un toque de conduccion en la direccion dada (lo usa una accion con raiz, que no pasa por update()).
func force_dribble_touch(dir: Vector3) -> void:
	_try_dribble_touch(dir, 0.8)

## Segundos de margen con los que se adelanta el toque cuando el cuerpo alcanza a la pelota (CATCH_CLOSING m/s o mas).
const CATCH_LEAD := 0.12
const CATCH_CLOSING := 0.6

## El cuerpo se acerca a la pelota que va delante (mas rapido que ella) y en CATCH_LEAD s la tendra al alcance del pie.
func _catching_ball(off: Vector3, fwd: Vector3, body_v: Vector3, ball_v: Vector3) -> bool:
	var ahead: float = off.dot(fwd)
	var closing: float = (body_v - ball_v).dot(fwd)
	return ahead > 0.0 and absf(off.dot(Vector3(-fwd.z, 0.0, fwd.x))) < 0.45 and closing > CATCH_CLOSING and ahead < _foot_reach * 0.9 + closing * CATCH_LEAD

func _try_dribble_touch(desired_dir: Vector3, stick_mag: float) -> void:
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 0.45:
		return
	# Nadie vuelve a tocar su propio pase o tiro recien ejecutado (si no, el jugador se "robaria" su propio envio).
	if b.last_toucher == owner and seconds_since_kick() < OWN_KICK_SECONDS:
		return
	var loco: Locomotion = owner.locomotion
	var t: PlayerTuning = Tuning.player
	var off: Vector3 = ball_offset()
	var dist: float = off.length()
	var reach: float = touch_reach()
	if dist > reach * 1.55:
		return
	var fwd: Vector3 = loco.forward()
	var body_v := Vector3(loco.velocity.x, 0.0, loco.velocity.z)
	var ball_v: Vector3 = KickModel.flat(b.linear_velocity)
	var rel_v: Vector3 = ball_v - body_v
	# Un balon que LLEGA rapido no se conduce: se controla (primer toque). Si no, el toque de parada lo frenaria
	# desde lejos y el control orientado no llegaria a ocurrir nunca.
	if dist > 0.5:
		var closing: float = -rel_v.dot(off / maxf(dist, 0.01))
		if closing > 2.0:
			return
	var has_dir: bool = desired_dir.length_squared() > 0.01
	var turn_angle: float = KickModel.angle_between_deg(fwd, desired_dir) if has_dir else 0.0
	var mode: StringName = _touch_mode(desired_dir, stick_mag, turn_angle)

	# Parado y con la pelota quieta no hay nada que hacer: no se la empuja sin motivo.
	if mode == &"settle" and loco.speed < 0.5 and rel_v.length() < 0.55 and _shield_dir(dist).length_squared() < 0.01:
		return

	var ratio: float = _sprint_ratio()
	var interval: float = _touch_interval(ratio)
	if mode == &"settle":
		interval = 0.26
	elif mode == &"lateral":
		interval = maxf(interval * 0.8, 0.2)

	# --- Cuando tocar: SOLO con el pie en la pelota -----------------------------------------------------------
	# Conduccion fisica (estilo FTS / Ultimate Clash): la pelota cambia de rumbo unicamente cuando un pie la alcanza. No
	# hay toques a distancia que la «traigan» al rumbo nuevo del jugador (el efecto «hilo» medido con la sonda: a sprint,
	# redirecciones a 1.3 m del cuerpo sin pie). Si la pelota va por delante, el jugador la sigue (follow_steer) y la
	# acomoda al llegar.
	var at_foot: bool = _ball_at_foot(off, fwd, mode)
	var strike: int = -1
	# El primer apoyo lateral es una accion nueva, como el de cambio de rumbo: puede entrar
	# tras la separacion minima entre toques, sin esperar todo el ciclo anterior de carrera.
	var lateral_entry: bool = mode == &"lateral" and last_touch_mode != &"lateral" and at_foot and touch_timer < interval - REVERSAL_TOUCH_GAP
	if feet_live:
		# Con el esqueleto animado el toque lo da un PIE: cuando una punta de pie baja llega a la pelota. Media vuelta (giro
		# de mas de 100 grados) con la pelota al pie: el toque de giro no espera a la cadencia de la carrera.
		var reversal: bool = mode == &"redirect" and turn_angle > 100.0 and at_foot and touch_timer < interval * 0.9 - REVERSAL_TOUCH_GAP
		# Modo 4: cambio de rumbo en carrera (diagonal, zigzag) con la pelota al pie: toque de rumbo ya, con el pie que esta
		# junto a la pelota, en vez de esperar al siguiente paso (la pelota seguia derecho y quedaba al costado).
		var steer_now: bool = PackLibrary.json_mode() and mode == &"carry" and at_foot and _steer_touch_ready(b, desired_dir, stick_mag, interval)
		# El cuerpo acelera y alcanza a la pelota del toque anterior (lanzada para la velocidad de entonces): el toque no
		# espera a la cadencia, si no el jugador la pisaba (medido: de caminar a correr, cuerpo a 0.07 m de la pelota).
		# Solo conduciendo: con un golpeo pedido (setup) el toque de preparacion tiene sus reglas (kick_approach_steer).
		var catching: bool = mode == &"carry" and _catching_ball(off, fwd, body_v, ball_v)
		if touch_timer > interval * 0.45 and not reversal and not steer_now and not catching and not lateral_entry:
			return
		var close_in: bool = off.dot(fwd) < _foot_reach * 0.9 and (mode == &"carry" or mode == &"setup")
		strike = _foot_strike(b, mode, close_in)
		if strike < 0:
			# Con un golpeo pedido y el jugador corriendo a por la pelota (kick_approach_steer) no hay toque sin pie: el
			# contacto sera el del golpeo.
			if mode == &"setup" and not kick_approach_steer().is_empty():
				return
			_foot_wait += get_dt()
			# Sin pie medido solo si la pelota esta en la zona del pie (la punta no llega por centimetros en este paso) o el
			# cuerpo se le viene encima (la pisaria); nunca a distancia.
			var overrun: bool = (off.dot(fwd) < OVERRUN_FWD and dist < 0.45) or (catching and at_foot)
			var wait_max: float = 0.06 if (overrun or steer_now or mode == &"settle" or mode == &"redirect" or mode == &"lateral") else FOOT_WAIT_MAX
			# Conduciendo, con la pelota bien colocada se sigue esperando al pie (el toque llega en la zancada); sin pie solo si
			# se esta yendo de la zona del pie o el cuerpo se le viene encima.
			var leaving: bool = at_foot and off.dot(fwd) > (FOOT_ZONE_FWD + 0.14 * _sprint_ratio()) * 0.8 and rel_v.dot(off / maxf(dist, 0.01)) > 0.3
			var no_foot_ok: bool = overrun or ((mode != &"carry" or leaving) and at_foot)
			# Parando la pelota (joystick suelto, sin rival) el toque lo da un pie que llega: sin pie solo si el cuerpo se le
			# viene encima. Si no, la pelota iba sola al pie (prueba physical_dribble::released_stick).
			if mode == &"settle" and owner.is_human_controlled and not overrun and _shield_dir(dist).length_squared() < 0.01:
				no_foot_ok = false
			if not no_foot_ok or _foot_wait <= wait_max:
				return
	else:
		if touch_timer > 0.0 and not lateral_entry and not (mode == &"redirect" and turn_angle > 100.0 and touch_timer < interval * 0.9 - REVERSAL_TOUCH_GAP):
			return
		if not at_foot:
			return
	var lateral_off: float = absf(off.dot(loco.right()))
	# La pelota quedo detras: hay que girar o recuperarla (carry_steer lleva al jugador a ella), salvo que el toque sea
	# justo para traerla de vuelta. "Detras" respecto a hacia donde se quiere ir: con el joystick hacia atras, una pelota
	# a la espalda esta delante del nuevo rumbo y se puede arrastrar hacia alli.
	var ref_dir: Vector3 = desired_dir.normalized() if has_dir else fwd
	if off.dot(ref_dir) < -0.3 and off.dot(fwd) < -0.3 and (mode == &"carry" or mode == &"setup") and lateral_off < 0.45:
		return

	var skill: float = _carry_skill()
	# Punto donde debe quedar quieta la pelota amortiguada al frenar (toque settle desde carrera).
	var settle_stop: Vector3 = Vector3.ZERO
	var settle_to_stop: bool = false

	# --- A donde va la pelota -------------------------------------------------------------------------------
	var touch_dir: Vector3 = fwd
	var gap: float = 0.0
	var travel: float = interval          # segundos hasta el proximo toque
	var carry_speed: float = 0.0
	match mode:
		&"settle":
			var shield: Vector3 = _shield_dir(dist)
			touch_dir = shield if shield.length_squared() > 0.01 else fwd
			gap = t.settle_gap
			carry_speed = 0.0
			travel = 0.3
			# Frenando desde carrera la pelota no se para en seco: se amortigua para que se DETENGA junto a donde se va a
			# detener el cuerpo (con la rodadura proporcional una pelota que llega ahi rodando se pasaba: quedaba a 0.9 m).
			# Parado o caminando, igual: el pie la deja quieta (pisada) donde la para, no la manda hacia delante del cuerpo
			# (con una velocidad de llegada seguia rodando y el jugador la perseguia toque tras toque).
			if shield.length_squared() < 0.01 and (owner.is_human_controlled or loco.speed > t.walk_speed):
				var stop_dist: float = loco.speed * loco.speed / (2.0 * maxf(t.decel * owner.attributes.factor("acceleration", 0.16), 1.0))
				settle_stop = KickModel.flat(owner.global_position) + KickModel.flat(body_v).normalized() * stop_dist + touch_dir * t.settle_gap
				settle_to_stop = true
				travel = clampf(loco.speed / maxf(t.decel, 1.0) * 1.1, 0.3, 0.9)
		&"setup":
			# Con un pase o tiro pulsado el siguiente toque PREPARA el golpeo: acerca la pelota al pie en vez de
			# empujarla lejos, asi el jugador puede ejecutar sin frenar la carrera.
			carry_speed = _carry_speed_after_turn(stick_mag, turn_angle) if has_dir else loco.speed
			touch_dir = (desired_dir.normalized() if has_dir else fwd)
			gap = carry_gap(carry_speed, skill) * 0.6
		&"lateral":
			touch_dir = desired_dir.normalized()
			gap = t.carry_gap_stand + 0.12
			carry_speed = minf(loco.speed_for_magnitude(stick_mag), t.jog_speed)
		&"redirect":
			touch_dir = desired_dir.normalized()
			# En un giro cerrado la pelota se lleva pegada al pie: cuanto mas cerrado, mas corta la colocacion.
			var tight: float = clampf((turn_angle - 55.0) / 125.0, 0.0, 1.0)
			carry_speed = _carry_speed_after_turn(stick_mag, turn_angle)
			gap = lerpf(carry_gap(carry_speed, skill), t.carry_gap_stand, tight * 0.75)
			_redirect_hold = 0.22 if turn_angle > 90.0 else 0.0
			if turn_angle > 100.0:
				# Media vuelta: la pelota se arrastra por el COSTADO del cuerpo (del lado donde ya esta), no a traves de el;
				# mientras pasa, el cuerpo no la bloquea (a la carrera rebotaba contra el jugador y salia hacia el rumbo
				# viejo: medido, media vuelta a sprint perdida a 6.5 m).
				var side_sign: float = signf(off.dot(loco.right())) if absf(off.dot(loco.right())) > 0.05 else 1.0
				var side_v: Vector3 = Vector3(-touch_dir.z, 0.0, touch_dir.x) * -side_sign
				touch_dir = (touch_dir + side_v * 0.35).normalized()
				_pass_ghost = REVERSAL_GHOST_SECONDS
				owner.set_ball_ghost(true)
		_:
			carry_speed = _carry_speed_after_turn(stick_mag, turn_angle)
			gap = carry_gap(carry_speed, skill)
			var w: float = 0.75 if turn_angle < 25.0 else 1.0
			if PackLibrary.json_mode() and _steer_angle(b, desired_dir) > STEER_TOUCH_DEG:
				w = 1.0
			touch_dir = (fwd * (1.0 - w) + desired_dir.normalized() * w).normalized() if has_dir else fwd
			# A sprint el toque puede pasarse (toque largo); con mejor control se pasa menos.
			gap += absf(rng.randfn(0.0, t.touch_overshoot_sprint * (1.2 - skill))) * ratio * ratio

	# Un toque solo puede girar la pelota lo que el pie alcanza a esa velocidad (touch_turn_max_deg): un cambio de rumbo
	# mayor se hace en varios toques (o con el giro con toques / la pisada). La media vuelta de arrastre despacio, aparte.
	if has_dir and (mode == &"carry" or mode == &"setup" or (mode == &"redirect" and not (turn_angle > 100.0 and loco.speed < t.jog_speed))):
		touch_dir = turn_toward(fwd, touch_dir, deg_to_rad(touch_turn_max_deg(loco.speed)))
	# Con pies vivos la pelota se deja donde llega la punta del pie en su zancada (mas un radio): asi el siguiente toque
	# lo da el pie de verdad. Sin esqueleto animado, la ley de distancias de PlayerTuning.
	if feet_live and (mode == &"carry" or mode == &"setup" or mode == &"redirect"):
		var foot_gap: float = _foot_reach + FOOT_BALL_LEAD
		if mode == &"setup":
			foot_gap = _foot_reach * 0.8 + FOOT_BALL_LEAD
		# Con toques de clip a esta velocidad la pelota se deja donde la encuentra el balanceo del clip (si no, queda
		# donde la punta todavia va alta y el clip no puede recogerla). En la arrancada, como siempre.
		elif mode == &"carry" and _clip_driving() and loco.speed >= TOUCH_MIN_SPEED and turn_angle < 25.0:
			foot_gap = maxf(foot_gap, clip_touch_gap(loco.speed))
		var long_touch: float = gap - carry_gap(carry_speed, skill)
		gap = clampf(foot_gap + maxf(long_touch, 0.0) * 0.5, t.carry_gap_stand, reach * 1.2)
	# Arrancada: con SPRINT pedido y lejos de la velocidad punta, el toque se alarga (se empuja la pelota al espacio para
	# acelerar detras de ella, como un toque de arrancada); al llegar a la punta vuelve el control cercano.
	# Solo en linea recta (en un giro la velocidad cae y alargar el toque perdia la pelota: 6 de 20 giros a sprint) y menos
	# con mejor control.
	var launch: bool = false
	if mode == &"carry" and loco.sprinting and turn_angle < 15.0 and absf(loco.turn_rate) < 0.6:
		# Por FRACCION de la punta que falta (un jugador mas rapido no recibe toques mas largos por tardar mas en llegar a
		# ella) y mucho menos con buen control.
		var missing: float = 1.0 - loco.speed / maxf(loco.max_sprint_speed(), 0.1)
		gap += clampf(missing * ACCEL_TOUCH_PER_FRACTION, 0.0, 1.0) * ACCEL_TOUCH_MAX * (1.0 - skill)
		launch = missing > ACCEL_TOUCH_KEEP_FRACTION
	gap = minf(gap, reach * 1.35 - 0.05)
	_planned_gap = gap
	_foot_wait = 0.0
	if strike < 0 and feet_live and PackLibrary.json_mode():
		# Modo 4: sin pie justo en la pelota, el pie bajo mas cercano se estira hasta ella (IK, JSON_TOUCH_IK_MAX): el toque
		# tambien se ve dado con el pie (en los cambios de rumbo la pelota queda a un costado del paso).
		var best_d: float = FOOT_CONTACT + 0.2
		for fi in 2:
			if _toe_now[fi].y <= FOOT_MAX_Y and foot_distance(fi, b.global_position) < best_d:
				best_d = foot_distance(fi, b.global_position)
				strike = fi
	last_touch_foot = strike
	if strike >= 0:
		foot_touches += 1
		last_touch_foot_distance = foot_distance(strike, b.global_position)
		last_touch_toe_distance = _toe_now[strike].distance_to(b.global_position)
	else:
		last_touch_foot_distance = -1.0
		last_touch_toe_distance = -1.0

	# Posicion del jugador cuando la pelota llegue a destino: promedio entre su velocidad actual y la que tendra.
	var p_pos: Vector3 = KickModel.flat(owner.global_position)
	var b_pos: Vector3 = KickModel.flat(b.global_position)
	var future_player: Vector3
	if turn_angle > 100.0 and mode == &"redirect":
		# Media vuelta (arrastre): el cuerpo frena hasta pararse y sale hacia el rumbo nuevo; la pelota se lleva desde
		# donde se detiene el cuerpo, hacia el rumbo pedido (no solo se frena).
		var brake_a: float = maxf(t.brake * owner.attributes.factor("acceleration", 0.16), 1.0)
		var t_stop: float = loco.speed / brake_a
		travel = clampf(t_stop + 0.25, 0.3, 0.8)
		future_player = p_pos + body_v * (t_stop * 0.5) + touch_dir * carry_speed * maxf(travel - t_stop, 0.0) * 0.5
	elif turn_angle > 55.0 and mode != &"settle":
		# Giro cerrado: el cuerpo frena (sigue un instante su rumbo) y despues acelera hacia el nuevo.
		var t_align: float = minf(0.25 * turn_angle / 90.0, travel)
		future_player = p_pos + body_v * (t_align * 0.5) + touch_dir * carry_speed * maxf(travel - t_align, 0.0) * 0.5
	else:
		# La pelota sale RECTA en el rumbo del toque (no se la coloca sobre la curva que va a hacer el jugador): el cuerpo
		# la sigue (follow_steer) y el proximo toque la vuelve a orientar.
		future_player = p_pos + (body_v + touch_dir * carry_speed) * 0.5 * travel
	var target: Vector3 = future_player + touch_dir * gap
	# Velocidad para llegar alli en `travel` segundos con la rodadura de la pelota (Ball). La pelota que se amortigua al
	# frenar va a detenerse en su punto (Ball.roll_speed_to_stop), no a pasar por el.
	var to_tg: Vector3 = target - b_pos
	var v: Vector3 = to_tg.normalized() * Ball.roll_speed_for(to_tg.length(), maxf(travel, 0.05)) if to_tg.length() > 0.001 else Vector3.ZERO
	if settle_to_stop:
		# Si la pelota ya paso ese punto, se la frena.
		var to_s: Vector3 = settle_stop - b_pos
		v = to_s.normalized() * Ball.roll_speed_to_stop(to_s.length()) if to_s.length() > 0.02 and to_s.dot(body_v) > 0.0 else Vector3.ZERO
	# Conduccion recta que va a seguir con toques de clip (BallHandler, toques de clip): la pelota se deja en el punto de
	# contacto de esos clips y llega con velocidad relativa ~0 (tiempo natural de la rodadura, como _clip_touch_step).
	# Si llegara con velocidad de mas se pasaria del alcance de los balanceos y no habria toque de clip en segundos.
	# El toque de arrancada (sprint lejos de la punta) y los rescates sin pie se respetan: son de la conduccion por pisadas.
	if mode == &"carry" and _clip_driving() and loco.speed >= TOUCH_MIN_SPEED and turn_angle < 25.0 and not launch and strike >= 0:
		var cg: float = clip_touch_gap(loco.speed)
		if cg > 0.0:
			var advance: float = cg - (b_pos - p_pos).dot(touch_dir)
			var t_arr: float = clampf(Ball.roll_catch_time(advance, loco.speed), 0.3, 0.45 if _tight() else 1.2)
			var st: Dictionary = _predict_body(INF, t_arr)
			target = _body_point(st["pos"], float(st["yaw"]), cg, 0.0)
			# La pelota se integra un paso mas que el cuerpo (que ya se movio en este paso).
			var span: float = t_arr + get_dt()
			var to_t: Vector3 = target - b_pos
			v = to_t.normalized() * Ball.roll_speed_for(to_t.length(), span) if to_t.length() > 0.001 else Vector3.ZERO
			travel = t_arr
	v = v.limit_length(maxf(carry_speed, 0.5) + 4.5)

	# --- Error del toque: crece con sprint y giros bruscos; baja con control y conduccion --------------------
	var sigma: float = t.touch_error_deg * (1.5 - 0.9 * skill)
	sigma *= 1.0 + (t.touch_error_sprint - 1.0) * ratio
	sigma *= 1.0 + (t.touch_error_turn - 1.0) * clampf(absf(loco.turn_rate) / 6.0, 0.0, 1.0)
	if mode == &"settle" or mode == &"lateral" or mode == &"setup":
		sigma *= 0.5
	elif mode == &"redirect":
		sigma *= 0.7
	sigma = minf(sigma, t.touch_error_max_deg)
	var err: float = KickModel.gaussian_clipped(rng, sigma)
	# El error es del empuje del pie: se aplica a la velocidad RELATIVA al jugador. Aplicado a la velocidad absoluta,
	# un error de unos grados a 6-7 m/s mandaba la pelota >2 m al costado (se perdia el balon a carrera y sprint).
	var rel: Vector3 = (v - body_v).rotated(Vector3.UP, deg_to_rad(err))
	rel *= clampf(rng.randfn(1.0, 0.03 + 0.05 * ratio), 0.85, 1.15)
	v = body_v + rel
	b.kick(v, b.rolling_spin(v), owner)
	if strike >= 0 and PackLibrary.json_mode():
		_json_touch_ik_start(strike, v - body_v)
	touch_timer = interval * rng.randf_range(0.9, 1.1)
	dribble_touch_count += 1
	last_touch_mode = mode
	touched_ball.emit(mode)

## Modo 4: el pie que da el toque de conduccion se lleva hasta la pelota (TouchFootIK) un instante, y la acompana mientras
## sale: el toque se ve dado con el pie (sin esto la punta quedaba a 0.1-0.17 m de la superficie de la pelota).
## JSON_TOUCH_IK_MAX: lo maximo (m) que se estira el pie desde el gesto de la marcha.
const JSON_TOUCH_IK_MAX := 0.34
const JSON_TOUCH_IK_HOLD := 0.05
const JSON_TOUCH_IK_FADE := 0.07
var _jik_foot: int = -1
var _jik_t: float = 0.0
var _jik_dir: Vector3 = Vector3.ZERO
var _jik_max: float = JSON_TOUCH_IK_MAX

## Modo 4: en los ultimos JSON_KICK_IK_IN s del balanceo de un golpeo el pie que patea va hasta la pelota real (IK), hasta
## JSON_KICK_IK_MAX m desde el gesto del clip: el golpe se ve dado con el pie aunque la pelota se haya corrido un poco.
const JSON_KICK_IK_IN := 0.12
const JSON_KICK_IK_MAX := 0.55

## true si este jugador patea con los clips del modo 4 (Json).
func _json_kicks() -> bool:
	return owner.visual != null and owner.visual.json_mode

## Distancia (m) maxima entre el pie del clip y la pelota para que el golpeo cuente.
func kick_reach() -> float:
	return Tuning.player.json_kick_reach if _json_kicks() else Tuning.player.kick_contact_radius

func _json_kick_ik() -> void:
	if _kick_timer > JSON_KICK_IK_IN or not _json_kicks() or _foot_ik() == null:
		return
	var b: Ball = ball()
	if b == null or b.is_held():
		return
	var foot: int = 1 if int(_kick_clip["contact"]["foot"]) > 0 else 0
	var toe: Vector3 = _toe_now[foot]
	var bp: Vector3 = b.global_position
	var app: Vector3 = KickModel.flat(bp - toe)
	var dir: Vector3 = app.normalized() if app.length() > 0.02 else owner.locomotion.forward()
	var want: Vector3 = bp - dir * (b.radius + 0.02)
	want.y = clampf(bp.y, 0.05, 0.3)
	var w: float = smoothstep(0.0, 1.0, 1.0 - _kick_timer / JSON_KICK_IK_IN)
	if app.length() > JSON_KICK_IK_MAX + b.radius:
		w = 0.0
	_foot_ik().set_target(foot, want, 0.0, w)

func _json_touch_ik_start(foot: int, push: Vector3, max_reach: float = JSON_TOUCH_IK_MAX) -> void:
	if _foot_ik() == null:
		return
	_jik_max = max_reach
	if _jik_foot >= 0 and _jik_foot != foot:
		_foot_ik().set_target(_jik_foot, Vector3.ZERO, 0.0, 0.0)
	_jik_foot = foot
	_jik_t = 0.0
	var p: Vector3 = KickModel.flat(push)
	_jik_dir = p.normalized() if p.length() > 0.05 else owner.locomotion.forward()
	_json_touch_ik_step(0.0)

func _json_touch_ik_step(dt: float) -> void:
	if _jik_foot < 0:
		return
	var ik: TouchFootIK = _foot_ik()
	var b: Ball = ball()
	if ik == null or b == null:
		_jik_foot = -1
		return
	_jik_t += dt
	var w: float = 1.0 if _jik_t <= JSON_TOUCH_IK_HOLD else clampf(1.0 - (_jik_t - JSON_TOUCH_IK_HOLD) / JSON_TOUCH_IK_FADE, 0.0, 1.0)
	var toe: Vector3 = _toe_now[_jik_foot]
	var want: Vector3 = b.global_position - _jik_dir * (b.radius + 0.025)
	want.y = clampf(toe.y, 0.03, 0.12)
	if KickModel.flat(want - toe).length() > _jik_max:
		w = 0.0
	ik.set_target(_jik_foot, want, 0.0, w)
	if w <= 0.0:
		_jik_foot = -1

## Modo 4: angulo (grados) entre hacia donde va la pelota respecto al cuerpo y el rumbo pedido a partir del cual se da un
## toque de rumbo, y alcance extra (m) del pie para darlo.
const STEER_TOUCH_DEG := 18.0
const STEER_TOUCH_REACH := 0.1

## Angulo (grados) entre el camino de la pelota (su velocidad, o hacia donde esta si va quieta) y el rumbo pedido.
func _steer_angle(b: Ball, desired_dir: Vector3) -> float:
	if desired_dir.length_squared() < 0.01:
		return 0.0
	var bv: Vector3 = KickModel.flat(b.linear_velocity)
	var path: Vector3 = bv if bv.length() > 0.8 else ball_offset()
	if path.length() < 0.05:
		return 0.0
	return KickModel.angle_between_deg(path.normalized(), KickModel.flat(desired_dir).normalized())

func _steer_touch_ready(b: Ball, desired_dir: Vector3, stick_mag: float, interval: float) -> bool:
	if stick_mag < 0.3 or touch_timer > interval * 0.8 or _steer_angle(b, desired_dir) < STEER_TOUCH_DEG:
		return false
	for i in 2:
		if _toe_now[i].y <= FOOT_MAX_Y and foot_distance(i, b.global_position) <= FOOT_CONTACT + STEER_TOUCH_REACH:
			return true
	return false

## Velocidad a la que el jugador podra llevar la pelota tras el giro (en un giro cerrado el cuerpo frena antes de
## acelerar hacia el rumbo nuevo: empujar la pelota al ritmo de la carrera actual la perderia).
func _carry_speed_after_turn(stick_mag: float, turn_angle: float) -> float:
	var t: PlayerTuning = Tuning.player
	var loco: Locomotion = owner.locomotion
	var desired: float = loco.max_sprint_speed() if loco.sprinting else loco.speed_for_magnitude(stick_mag)
	var turn_pen: float = clampf((turn_angle - 55.0) / 95.0, 0.0, 1.0)
	desired = lerpf(desired, minf(desired, t.walk_speed + 0.8), turn_pen)
	var carry: float = minf(desired * 0.95, loco.speed + t.accel * 0.2)
	return maxf(carry, loco.speed * 0.9)

## Direccion en la que conviene colocar la pelota al pararla: lejos del rival mas cercano (proteccion). Cero si no
## hay rival a quien proteger la pelota.
func _shield_dir(dist: float) -> Vector3:
	var opp: Footballer = nearest_opponent(Tuning.player.shield_radius)
	if opp == null:
		return Vector3.ZERO
	var away: Vector3 = KickModel.flat(owner.global_position - opp.global_position)
	if away.length() < 0.2:
		return Vector3.ZERO
	away = away.normalized()
	# Si la pelota ya esta del lado protegido no hace falta moverla.
	if dist < Tuning.player.settle_gap + 0.2 and ball_offset().normalized().dot(away) > 0.55:
		return Vector3.ZERO
	return away

## Decide, ANTES de que el cuerpo gire, hacia donde mira el jugador mientras lleva la pelota. Lo llama el futbolista
## al principio del paso de fisica, porque la decision depende de la orientacion que el cuerpo tiene todavia:
##  - Proteccion: casi parado con un rival cerca -> le da la espalda y deja la pelota del lado contrario.
##  - Control lateral: el joystick apunta de costado a poca velocidad -> el cuerpo conserva su orientacion durante
##    `lateral_hold_seconds` y el jugador se desplaza de lado (mezcla direccional de la animacion). Despues gira
##    normalmente: el control lateral es un recurso puntual, no un bloqueo del giro.
## Devuelve la direccion a la que mirar, o cero para que el cuerpo gire libremente hacia el joystick.
func plan_carry(desired_dir: Vector3, stick_mag: float, dt: float) -> Vector3:
	_lateral_hold = maxf(_lateral_hold - dt, 0.0)
	_lateral_cooldown = maxf(_lateral_cooldown - dt, 0.0)
	_carry_face = Vector3.ZERO
	var loco: Locomotion = owner.locomotion
	if loco == null or not has_possession():
		_lateral_hold = 0.0
		return _carry_face
	var t: PlayerTuning = Tuning.player
	if _lateral_hold > 0.0:
		if stick_mag < 0.15:
			_lateral_hold = 0.0
		else:
			_carry_face = _lateral_face
			return _carry_face
	if stick_mag < 0.35 and loco.speed < t.walk_speed:
		var opp: Footballer = nearest_opponent(t.shield_radius)
		if opp != null:
			var away: Vector3 = KickModel.flat(owner.global_position - opp.global_position)
			if away.length() > 0.3:
				_carry_face = away.normalized()
				return _carry_face
	if _lateral_cooldown <= 0.0 and desired_dir.length_squared() > 0.01 and stick_mag > 0.18 \
			and stick_mag <= t.lateral_max_stick and loco.speed < t.jog_speed:
		var ang: float = KickModel.angle_between_deg(loco.forward(), desired_dir)
		if ang > 55.0 and ang < 125.0:
			_lateral_hold = t.lateral_hold_seconds
			_lateral_cooldown = t.lateral_hold_seconds + 0.5
			_lateral_face = loco.forward()
			_carry_face = _lateral_face
	return _carry_face

## Frenar con la pelota: con el joystick suelto, si la pelota propia sigue rodando lejos del pie, el jugador la
## acompana hasta tenerla al alcance para pararla (toque de parada / pisada), en vez de quedarse quieto mientras se va
## (fallo visto en el video del usuario: soltar el joystick y la pelota seguia rodando sola). Devuelve [direccion,
## intensidad] o [] si no hace falta.
func settle_steer() -> Array:
	settle_close_now = false
	if _kick_action != &"" or not is_dribbling() or seconds_since_kick() < OWN_KICK_SECONDS:
		_settle_adjust = false
		return []
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 0.6:
		return []
	var t: PlayerTuning = Tuning.player
	var off: Vector3 = ball_offset()
	var dist: float = off.length()
	var bv: Vector3 = KickModel.flat(b.linear_velocity)
	if dist > 3.0:
		return []
	if drag_back.active() or ball_turn.active() or (json_move != null and json_move.active):
		return []
	# Al alcance del pie: si la pelota esta quieta delante (zona comoda) no hay nada que hacer; al costado, detras o
	# yendose, el jugador va a ella (se gira y da los pasos) y la para el pie que llega. La pelota no viene al jugador.
	if dist < touch_reach() * 0.95:
		# Con un golpeo pedido o cargandose manda su propia preparacion (ajuste de zancada, ir a por la pelota, giro para
		# golpear): el jugador no se acomoda a la pelota mientras tanto.
		if _pending_action != &"" or _pass_active or _shoot_active or _through_active or _cross_active or kick_button_now:
			_settle_adjust = false
			return []
		# Solo el jugador de la persona (como las reglas nuevas del toque de parada: zona del pie delante, pie que llega de
		# verdad, pelota quieta): la IA siempre decide hacia donde ir y su joystick queda suelto solo un instante (al llegar a su
		# sitio, tras recibir). Con las reglas nuevas tambien para la IA el partido cambiaba (seguia la pelota fuera de la
		# cancha sin _keep_inside; tras recibir, la pelota se le escapaba hasta su siguiente decision: menos tiros, companeros
		# encima del portador): fallos de pruebas de partidos de IA en GitHub Actions #46-#48 que con el codigo anterior no
		# aparecian. La IA conserva el toque de parada de antes; pendiente darle una orden en ese instante.
		if not owner.is_human_controlled:
			_settle_adjust = false
			return []
		var close: Array = _settle_close(b, off, bv)
		settle_close_now = not close.is_empty()
		return close
	_settle_adjust = false
	# Donde estara la pelota en un momento y un punto un poco por detras de ella (desde el jugador).
	var lead: float = clampf(dist / 4.0, 0.1, 0.5)
	var target: Vector3 = KickModel.flat(owner.global_position) + off + bv * lead
	var to_t: Vector3 = target - KickModel.flat(owner.global_position)
	var d: float = to_t.length()
	if d < t.settle_gap:
		return []
	var need: float = maxf(bv.length(), (d - t.settle_gap) * 2.5)
	var mag: float = clampf(need / maxf(owner.locomotion.max_run_speed(), 0.1), 0.25, 1.0)
	return [to_t / d, mag]

var _settle_adjust: bool = false
## true si en este paso settle_steer acomoda al jugador con la pelota al alcance (Footballer: no la sigue follow_steer ni
## se pone de costado).
var settle_close_now: bool = false
## Boton de golpeo apretado en este paso (lo pone Footballer antes de settle_steer).
var kick_button_now: bool = false

## settle_steer con la pelota al alcance: [direccion, magnitud, hacia donde mirar] para que el cuerpo quede de frente a la
## pelota con ella a settle_gap delante, o [] si ya esta asi (quieta en la zona comoda) o la protege de un rival (manda la proteccion). Con
## histeresis: una vez que se acomoda, sigue hasta dejarla bien delante (sin temblar en el borde de la zona).
func _settle_close(b: Ball, off: Vector3, bv: Vector3) -> Array:
	var t: PlayerTuning = Tuning.player
	if _shield_dir(off.length()).length_squared() > 0.01:
		_settle_adjust = false
		return []
	var loco: Locomotion = owner.locomotion
	var ahead: float = off.dot(loco.forward())
	var lat: float = absf(off.dot(loco.right()))
	var margin: float = 0.06 if _settle_adjust else 0.0
	var still: bool = bv.length() < SETTLE_STILL_SPEED
	var comfy: bool = ahead > SETTLE_COMFY_MIN + margin and ahead < SETTLE_COMFY_MAX - margin and lat < SETTLE_COMFY_LAT - margin
	# Pelota parada entre los pies, delante: ya esta controlada (pisada); no se camina encima de ella.
	var under: bool = off.length() < SETTLE_UNDER and ahead > SETTLE_ZONE_BACK and lat < SETTLE_COMFY_LAT - margin
	if (comfy or under) and still:
		_settle_adjust = false
		return []
	_settle_adjust = true
	# Hacia donde estara la pelota en un instante (si rueda, se la sigue) y lo que falta para dejarla a settle_gap delante.
	var target: Vector3 = KickModel.flat(b.global_position) + bv * 0.25
	var to_t: Vector3 = target - KickModel.flat(owner.global_position)
	var d: float = to_t.length()
	if d < 0.05:
		return []
	# El cuerpo mira a la pelota mientras se acomoda (Footballer: face_override).
	var face: Vector3 = KickModel.flat(off).normalized() if KickModel.flat(off).length() > 0.05 else loco.forward()
	if d < t.settle_gap + 0.05:
		# Pelota pegada al cuerpo (a la espalda o al costado): se gira en el sitio hasta encararla, sin caminar encima de ella
		# (si no, la pisaba y la volvia a tocar una y otra vez: prueba physical_dribble::released_stick, pelota detras).
		return [face, 0.0, face]
	var need: float = d - t.settle_gap
	# Pasos cortos (velocidad de un paso de ajuste, no de una caminata) y la de la pelota si rueda.
	var speed: float = clampf(maxf(need * 2.5, bv.length()), SETTLE_STEP_SPEED, loco.max_run_speed())
	return [to_t / d, clampf(_magnitude_for_speed(speed), 0.06, 0.6), face]

## Inversa de Locomotion.speed_for_magnitude (magnitud del joystick para ir a `speed` m/s).
func _magnitude_for_speed(speed: float) -> float:
	var t: PlayerTuning = Tuning.player
	if speed <= t.walk_speed:
		return 0.35 * speed / maxf(t.walk_speed, 0.01)
	if speed <= t.jog_speed:
		return 0.35 + 0.35 * (speed - t.walk_speed) / maxf(t.jog_speed - t.walk_speed, 0.01)
	return 0.7 + 0.3 * (speed - t.jog_speed) / maxf(owner.locomotion.max_run_speed() - t.jog_speed, 0.01)

## Golpeo pedido (cargando o en espera) con la pelota PROPIA por delante (o suelta, para el jugador de la persona), fuera
## del alcance del pie y a menos de APPROACH_MAX_DIST: el jugador ajusta la carrera y va a por ella para poder golpearla
## con el pie (en el video del usuario, 58.4 s, el tiro cargado a media velocidad con la pelota 1.3-1.5 m por delante
## nunca llegaba y se perdia). Devuelve [direccion, magnitud, sprint] o [] si no hace falta. Lo usan la persona y la IA.
func kick_approach_steer() -> Array:
	if _kick_action != &"":
		return []
	if _pending_action == &"" and not (_pass_active or _shoot_active or _through_active or _cross_active):
		return []
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 0.6:
		return []
	# Tambien la pelota suelta que el jugador de la persona va a buscar (rebote, despeje): el pase pedido no se pierde
	# por llegar un poco tarde. No la que viene hacia el (eso es un golpeo de primera, que espera en la trayectoria).
	# Con la conduccion fisica no hay toque de preparacion a distancia: a la pelota suelta que esta justo por delante (a
	# menos de 1.5 alcances, donde antes la traia ese toque) tambien se va caminando a golpearla.
	var off0: Vector3 = ball_offset()
	var near_front: bool = off0.length() < touch_reach() * 1.5 and off0.dot(owner.locomotion.forward()) > 0.3
	if b.last_toucher != owner and not near_front and not (owner.is_human_controlled and incoming_ball_eta() == INF and loose_ball_chase() != Vector3.INF):
		return []
	if b.last_toucher != owner and (ball_owned_by_other() or incoming_ball_eta() != INF):
		return []
	var off: Vector3 = ball_offset()
	var dist: float = off.length()
	if dist < touch_reach() * 0.9 or dist > APPROACH_MAX_DIST:
		return []
	var bv: Vector3 = KickModel.flat(b.linear_velocity)
	# Donde estara la pelota cuando el jugador llegue (aprox.): un poco por delante de donde esta ahora.
	var target: Vector3 = off + bv * clampf(dist / 6.0, 0.1, 0.4)
	if target.length() < 0.05:
		return []
	var gap_speed: float = bv.dot(target.normalized())
	return [target.normalized(), 1.0, dist > 1.6 or gap_speed > owner.locomotion.max_run_speed() * 0.8]

## Golpeo pedido que todavia no puede salir (bloqueo tras un movimiento con pelota o una recepcion) con la pelota propia al
## pie: el jugador se queda sobre ella a pasos cortos en vez de seguir hacia el joystick y dejarla atras (medido: tras
## recibir, en los 0.3 s de bloqueo el cuerpo llegaba a 2 m/s y la pelota quedaba 0.5 m detras: pase perdido).
func holding_for_kick() -> bool:
	if _pending_action == &"" or _kick_action != &"" or lockout <= 0.0 or is_waiting_first_time():
		return false
	var b: Ball = ball()
	return b != null and not b.is_held() and b.last_toucher == owner and ball_distance() < 0.8

## true si hay un golpeo en espera y el jugador se esta acercando de verdad a su pelota (ver kick_approach_steer).
func is_approaching_for_kick() -> bool:
	if kick_approach_steer().is_empty():
		return false
	var b: Ball = ball()
	var dir: Vector3 = ball_offset().normalized()
	var closing: float = (KickModel.flat(owner.locomotion.velocity) - KickModel.flat(b.linear_velocity)).dot(dir)
	# Recien empezada la carrera todavia no se acerca: se le da el tiempo de PENDING_KICK_MAX para acelerar.
	return closing > APPROACH_MIN_CLOSING or _pending_age <= PENDING_KICK_MAX

## Escala del giro del cuerpo mientras conduce. Con la pelota al alcance pero NO hacia el rumbo pedido (un cambio de
## direccion grande), el cuerpo gira a BALL_TURN_SCALE de su ritmo hasta que el toque de giro la lleva hacia alli. Sin
## esto, a poca velocidad el cuerpo giraba 180 grados en menos de 0.3 s, la pelota quedaba a la espalda y el jugador
## corria primero 2.5 m hacia el lado contrario a buscarla (visto en el video del usuario: gira sin avanzar).
func carry_turn_scale(desired_dir: Vector3) -> float:
	if desired_dir.length_squared() < 0.01 or not is_dribbling():
		return 1.0
	var off: Vector3 = ball_offset()
	var dist: float = off.length()
	if dist < 0.12 or dist > touch_reach() * 1.3:
		return 1.0
	var want: Vector3 = desired_dir.normalized()
	var turn: float = KickModel.angle_between_deg(owner.locomotion.forward(), want)
	if turn < 50.0:
		return _curve_turn_scale(want, off)
	if off.normalized().dot(want) > 0.25:
		return 1.0   # la pelota ya va hacia el rumbo nuevo: el cuerpo la sigue
	# Solo despacio: a la carrera el giro ya esta limitado por la velocidad y frenarlo mas hacia pasar al cuerpo por
	# encima de la pelota en la media vuelta.
	var slow: float = clampf(owner.locomotion.speed / maxf(Tuning.player.jog_speed, 0.1), 0.0, 1.0)
	return lerpf(BALL_TURN_SCALE, 1.0, slow * slow)

## Curva a velocidad con toques de clip (apuntar un poco a un lado corriendo): entre toque y toque la pelota rueda
## recta, asi que el cuerpo no se adelanta al rumbo de la pelota mas de CURVE_LEAD_DEG grados hacia el lado del giro
## (ni deja la pelota mas de CURVE_BALL_BEARING grados hacia el exterior); el siguiente toque la lleva al rumbo nuevo y
## el cuerpo sigue girando. Un cambio de 30 grados a la carrera se hace en 2-3 toques con la pelota al pie (sin esto el
## cuerpo giraba hasta 360 grados/s, completaba el giro en 0.2 s y la pelota quedaba a 0.8 m al costado).
const CURVE_LEAD_DEG := 8.0
const CURVE_BALL_BEARING := 12.0
const CURVE_TURN_SCALE := 0.06
const CURVE_GENTLE_MAX_DEG := 40.0
const CURVE_CARRY_MAX_DEG := 30.0

func _curve_turn_scale(want: Vector3, off: Vector3) -> float:
	var loco: Locomotion = owner.locomotion
	var b: Ball = ball()
	# Solo tras un toque de clip: los toques de la conduccion por pisadas colocan la pelota contando con que el cuerpo
	# siga girando libre (frenarlo despues de uno de rescate en un zigzag dejaba la pelota por delante y se perdia).
	if b == null or not _clip_driving() or last_touch_mode != &"clip" or loco.speed < TOUCH_MIN_SPEED or off.dot(loco.forward()) < 0.1:
		return 1.0
	var fwd: Vector3 = loco.forward()
	# Solo al dirigir suave: lo pedido a menos de CURVE_GENTLE_MAX_DEG del rumbo de la pelota. Un giro brusco (zigzag,
	# 74 grados) lo resuelve el toque de giro de siempre con el cuerpo girando libre.
	# Y solo conduciendo: la pelota rueda con el cuerpo (tras controlar un pase cruzado rueda de lado y el cuerpo tiene
	# que poder girar libre hacia ella).
	var bv0: Vector3 = KickModel.flat(b.linear_velocity)
	var ball_dir: Vector3 = bv0.normalized() if bv0.length() > 1.0 else fwd
	if KickModel.angle_between_deg(ball_dir, want) > CURVE_GENTLE_MAX_DEG or KickModel.angle_between_deg(ball_dir, fwd) > CURVE_CARRY_MAX_DEG:
		return 1.0
	# Lado del giro (+1 derecha): el que pide el joystick o, si el cuerpo ya va con el (eslalon: lo sigue de cerca), el
	# del giro del cuerpo. Angulos positivos hacia ese lado (adelanto del cuerpo) o hacia el exterior (pelota).
	var side: float = signf(want.dot(loco.right()))
	if absf(want.dot(loco.right())) < 0.02:
		side = -signf(loco.turn_rate) if absf(loco.turn_rate) > 0.05 else 0.0
	if side == 0.0:
		return 1.0
	var lead := 0.0
	var bv: Vector3 = KickModel.flat(b.linear_velocity)
	if bv.length() > 1.0:
		lead = rad_to_deg(atan2(side * bv.normalized().cross(fwd).y * -1.0, bv.normalized().dot(fwd)))
	var bearing: float = rad_to_deg(atan2(-side * off.dot(loco.right()), off.dot(fwd)))
	var excess: float = maxf((lead - CURVE_LEAD_DEG * 0.5) / (CURVE_LEAD_DEG * 0.5), (bearing - CURVE_BALL_BEARING * 0.5) / (CURVE_BALL_BEARING * 0.5))
	return lerpf(1.0, CURVE_TURN_SCALE, clampf(excess, 0.0, 1.0))

## Recuperar la pelota propia que se queda atras o al costado en un giro: en vez de correr hacia donde apunta el
## joystick dejando la pelota (fallo visto en las pruebas y en el video: giro brusco hacia el arco y la pelota sigue
## sola hasta la banda), el jugador va a un punto JUSTO DETRAS de la pelota respecto al rumbo pedido y desde ahi la
## toca hacia alli. Devuelve la direccion de carrera a usar (cero = seguir el joystick).
## Velocidad (m/s) relativa con la que la pelota se aleja del cuerpo a partir de la cual se la persigue aunque este al
## alcance (ver carry_steer).
const ESCAPE_STEER_SPEED := 0.8

func carry_steer(desired_dir: Vector3) -> Vector3:
	if desired_dir.length_squared() < 0.01 or _kick_action != &"":
		return Vector3.ZERO
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 0.6 or not is_dribbling():
		return Vector3.ZERO
	var off: Vector3 = ball_offset()
	var dist: float = off.length()
	# Al alcance del toque no hace falta ir: el toque de giro (redirect) la lleva al rumbo nuevo. Salvo si se esta
	# escapando (el ultimo toque la lanzo, como en FTS: sale disparada y frena): girando ahi el cuerpo frena y la pelota
	# se va (giro de 135 grados a la carrera: 0.8 s persiguiendola); se sigue derecho tras ella hasta poder tocarla.
	var rel_v: Vector3 = KickModel.flat(b.linear_velocity - owner.locomotion.velocity)
	var escaping: bool = dist > 0.35 and rel_v.dot(off / maxf(dist, 0.01)) > ESCAPE_STEER_SPEED
	if dist > 2.5 or (dist < touch_reach() * 1.1 and not escaping):
		return Vector3.ZERO
	var want: Vector3 = desired_dir.normalized()
	# Pelota por delante en el rumbo pedido y algo centrada: conduccion normal.
	var ahead: float = off.dot(want)
	var side: float = absf(off.dot(Vector3(-want.z, 0.0, want.x)))
	if ahead > 0.15 and side < 0.55:
		return Vector3.ZERO
	var approach: Vector3 = owner.global_position + off - want * 0.35 * Tuning.player.touch_reach
	var to_a: Vector3 = KickModel.flat(approach - owner.global_position)
	if to_a.length() < 0.15:
		return Vector3.ZERO
	return to_a.normalized()

## Tiempo (s) en que el jugador quiere cerrar la distancia de mas con una pelota propia que se adelanto, y margen (m) sobre
## la distancia de conduccion antes de apurarse.
const CATCH_UP_TIME := 0.6
const CATCH_UP_MARGIN := 0.25

## Pelota propia por delante en el rumbo pedido pero mas lejos que la distancia de conduccion (un toque largo, frenar con la
## pelota rodando): intensidad de carrera (0..1) que hace falta para alcanzarla en CATCH_UP_TIME s; 0 si esta a distancia de
## conduccion, detras o al costado (de eso se ocupa carry_steer). La pelota no se toca: el jugador se adapta a ella.
func carry_catch_up_mag(desired_dir: Vector3) -> float:
	if desired_dir.length_squared() < 0.01 or _kick_action != &"" or not is_dribbling():
		return 0.0
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 0.6:
		return 0.0
	var want: Vector3 = KickModel.flat(desired_dir).normalized()
	var off: Vector3 = ball_offset()
	var ahead: float = off.dot(want)
	if ahead <= 0.0 or absf(off.dot(Vector3(-want.z, 0.0, want.x))) > 0.55:
		return 0.0
	var loco: Locomotion = owner.locomotion
	var excess: float = ahead - carry_gap(loco.speed, _carry_skill()) - CATCH_UP_MARGIN
	if excess <= 0.0:
		return 0.0
	var need: float = maxf(KickModel.flat(b.linear_velocity).dot(want), 0.0) + excess / CATCH_UP_TIME
	var m: float = 0.1
	while m < 1.0 and loco.speed_for_magnitude(m) < need:
		m += 0.05
	return minf(m, 1.0)

## Conduccion fisica: entre toques la pelota rueda libre y solo un toque del pie la desvia, asi que quien conduce SIGUE a
## la pelota. Corre al punto desde el que la alcanzara por detras respecto del rumbo del proximo toque (el pedido con el
## joystick, limitado por touch_turn_max_deg a esa velocidad), donde estara la pelota cuando llegue. Una diagonal tras un
## toque largo se hace como en FTS / Ultimate Clash: primero se alcanza la pelota y despues se la acomoda; el cuerpo no
## gira dejandola atras para que despues lo «siga». Devuelve [direccion, magnitud, sprint] o [] (joystick suelto: lo
## resuelve settle_steer; giro con toques, pisada y golpeos tienen su propio control del cuerpo).
const FOLLOW_MAX_DIST := 4.0
## Distancia (m) por detras de la pelota (en el rumbo del proximo toque) a la que llega el cuerpo: el pie la alcanza ahi.
const FOLLOW_BACK := 0.40

func follow_steer(desired_dir: Vector3, stick_mag: float, sprint: bool) -> Array:
	if desired_dir.length_squared() < 0.01 or _kick_action != &"" or drag_back.active() or ball_turn.active():
		return []
	# Con un golpeo pedido mandan sus propios movimientos (giro con pelota para golpear, golpeo girando, ir a por la pelota):
	# seguir a la pelota volvia a girar al jugador hacia ella tras el giro para tirar (medido: tiros a 135-180 grados sin
	# golpeo).
	if _pending_action != &"" or (json_move != null and json_move.active):
		return []
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 0.6 or b.last_toucher != owner or not is_dribbling():
		return []
	if seconds_since_kick() < OWN_KICK_SECONDS:
		return []
	var loco: Locomotion = owner.locomotion
	var off: Vector3 = ball_offset()
	var dist: float = off.length()
	if dist > FOLLOW_MAX_DIST:
		return []
	var fwd: Vector3 = loco.forward()
	var want: Vector3 = KickModel.flat(desired_dir).normalized()
	var max_turn: float = deg_to_rad(touch_turn_max_deg(loco.speed))
	if _ball_at_foot(off, fwd, &"carry"):
		# Al pie: el cuerpo puede encarar el rumbo del proximo toque, sin girar mas de lo que el toque llevara a la pelota.
		return [turn_toward(fwd, want, max_turn), stick_mag, sprint]
	var bv: Vector3 = KickModel.flat(b.linear_velocity)
	var ref: Vector3 = bv.normalized() if bv.length() > 0.8 else (off / maxf(dist, 0.01))
	var push: Vector3 = turn_toward(ref, want, max_turn)
	var p: Vector3 = KickModel.flat(owner.global_position)
	var bp: Vector3 = KickModel.flat(b.global_position)
	var chase: float = maxf(loco.speed, loco.speed_for_magnitude(maxf(stick_mag, 0.7)))
	var tau := 0.0
	var target: Vector3 = bp - push * FOLLOW_BACK
	for k in 3:
		target = bp + KickModel.flat(ball_travel(b, tau)) - push * FOLLOW_BACK
		tau = clampf(p.distance_to(target) / maxf(chase, 1.0), 0.0, 1.5)
	var to_t: Vector3 = target - p
	if to_t.length() < 0.12:
		return [turn_toward(fwd, want, max_turn), stick_mag, sprint]
	var dir: Vector3 = to_t.normalized()
	# Intensidad: la del joystick, salvo que haga falta apurarse para no perder la pelota (la misma ley que
	# carry_catch_up_mag: alcanzar en CATCH_UP_TIME s lo que pasa de la distancia de conduccion). Asi frenar con el joystick
	# sigue frenando (la persecucion a fondo no dejaba bajar de 3.5 m/s con el joystick al 25 %).
	var excess: float = to_t.length() - carry_gap(loco.speed, _carry_skill()) - CATCH_UP_MARGIN
	var need: float = maxf(bv.dot(dir), 0.0) + maxf(excess, 0.0) / CATCH_UP_TIME
	var mag: float = stick_mag
	if excess > 0.0 and need > loco.speed_for_magnitude(stick_mag):
		mag = 0.1
		while mag < 1.0 and loco.speed_for_magnitude(mag) < need:
			mag += 0.05
		mag = clampf(maxf(mag, stick_mag), 0.0, 1.0)
	return [dir, mag, sprint]

## Direccion a la que debe mirar el cuerpo mientras conduce (control lateral o proteccion). Cero = libre.
func carry_face() -> Vector3:
	return _carry_face


# --- Control de primer toque -----------------------------------------------

func _try_first_touch(desired_dir: Vector3) -> bool:
	if control_cooldown > 0.0:
		return false
	var b: Ball = ball()
	if b == null or b.is_held():
		return false
	var t: PlayerTuning = Tuning.player
	var off: Vector3 = ball_offset()
	var dist: float = off.length()
	if dist > t.possession_radius or b.global_position.y > 0.7 or dist < 0.01:
		return false
	# Un balon que acaba de golpear este mismo jugador no se "controla".
	if b.last_toucher == owner and float(Engine.get_physics_frames() - b.last_touch_frame) / float(Engine.physics_ticks_per_second) < OWN_TOUCH_NO_CONTROL_SECONDS:
		return false
	# Un balon disputado (otro jugador lo acaba de tocar y sigue junto a el) no se controla gratis:
	# hay que disputarlo (entrada / presion).
	var last: Footballer = b.last_toucher as Footballer
	if last != null and last != owner and KickModel.flat(last.global_position - b.global_position).length() < 1.5:
		return false
	var rel_v: Vector3 = KickModel.flat(b.linear_velocity - owner.velocity)
	var closing: float = -rel_v.dot(off / dist)
	if closing < 2.2:
		return false
	if feet_live:
		# Con pies vivos el control lo hace el pie (o el cuerpo) cuando la pelota LLEGA a el, no a un metro: se espera a
		# que una punta de pie este en la pelota o a que la pelota vaya a alcanzar el cuerpo en el proximo paso.
		var toe_d: float = minf(_toe_now[0].distance_to(b.global_position), _toe_now[1].distance_to(b.global_position))
		var next_d: float = dist - closing * _dt * 1.1
		if toe_d > FOOT_CONTACT + 0.06 and next_d > 0.48:
			return false
	var ratio: float = _sprint_ratio()
	var absorb: float = first_touch_absorb(off)
	var leftover: Vector3 = rel_v * (1.0 - absorb)
	# Ruido: peor control = rebote menos predecible.
	var sigma: float = 20.0 * (1.35 - owner.attributes.norm("ball_control")) * (1.0 + 0.4 * ratio)
	leftover = leftover.rotated(Vector3.UP, deg_to_rad(KickModel.gaussian_clipped(rng, sigma)))
	# Control orientado: empuja el sobrante hacia donde quiere ir el jugador.
	if desired_dir.length_squared() > 0.01:
		leftover += desired_dir.normalized() * (rel_v.length() * (1.0 - absorb) * 0.25 * owner.attributes.norm("ball_control"))
	var new_v: Vector3 = owner.velocity + leftover
	new_v.y = minf(b.linear_velocity.y, 1.2) * 0.3
	b.kick(new_v, b.rolling_spin(new_v) * 0.8, owner)
	control_cooldown = 0.5
	touch_timer = 0.12
	owner.ctx.emit_event(GameEvent.make(GameEvent.Type.FIRST_TOUCH, owner.actor_id, owner.team,
		{"absorb": absorb, "incoming_speed": rel_v.length()}))
	touched_ball.emit(&"first_touch")
	return true

## Fraccion (0.15-0.93) de la velocidad de la pelota que amortigua el primer toque: control del jugador, pelota por detras
## (off: pelota respecto al jugador), carrera y equilibrio. La usan el control fisico y la recepcion con clip (JsonReceive).
func first_touch_absorb(off: Vector3) -> float:
	var absorb: float = Tuning.player.first_touch_absorb * owner.attributes.factor("ball_control", 0.35)
	if off.dot(owner.locomotion.forward()) < -0.25:
		absorb *= 0.5
	absorb *= 1.0 - 0.25 * _sprint_ratio()
	absorb *= lerpf(0.85, 1.0, KickModel.balance_state(owner))
	return clampf(absorb, 0.15, 0.93)

# --- Disputa ----------------------------------------------------------------

## Intenta quitar la pelota. No esta garantizado: depende de distancia, orientacion, equilibrio,
## velocidad relativa y atributos de ambos jugadores. Devuelve true si la recupera.
func attempt_tackle(carrier: Footballer) -> bool:
	var b: Ball = ball()
	if b == null or owner.ctx.ball_locked_for(owner):
		return false
	var d_off: Vector3 = ball_offset()
	var dist: float = d_off.length()
	var facing: float = KickModel.angle_between_deg(owner.locomotion.forward(), d_off)
	var chance: float = 0.32 * owner.attributes.factor("marking", 0.9)
	chance *= clampf(1.0 - facing / 140.0, 0.35, 1.0)
	chance *= lerpf(0.85, 1.0, KickModel.balance_state(owner))
	chance *= clampf(1.15 - dist * 0.25, 0.55, 1.1)
	var rel_speed: float = KickModel.flat(owner.velocity - (carrier.velocity if carrier != null else Vector3.ZERO)).length()
	if rel_speed > 6.0:
		chance *= 0.75
	if carrier != null:
		var shield: float = carrier.attributes.factor("strength", 0.4) * carrier.attributes.factor("balance", 0.3)
		# Proteger la pelota parado no aguanta: sin movimiento el cuerpo no puede seguir tapando al rival.
		shield *= lerpf(0.55, 1.0, clampf(carrier.locomotion.speed / 2.0, 0.0, 1.0))
		shield *= lerpf(1.0, 1.25, 1.0 - clampf(KickModel.angle_between_deg(carrier.locomotion.forward(), owner.global_position - carrier.global_position) / 180.0, 0.0, 1.0))
		chance /= maxf(shield, 0.5)
		# Si el balon esta lejos de su portador (toque largo) es mas facil.
		if carrier.ball_handler.ball_distance() > 0.9:
			chance *= 1.5
	else:
		chance *= 1.6
	if carrier != null and carrier.actions != null and carrier.actions.kind == &"skill":
		chance *= 0.3   # la ruleta protege al portador
	chance = clampf(chance, 0.04, 0.88)
	var won: bool = rng.randf() < chance
	var ctx: MatchContext = owner.ctx
	if won:
		var away: Vector3 = owner.locomotion.forward()
		var v: Vector3 = owner.velocity * 0.6 + away * rng.randf_range(2.2, 3.6)
		b.kick(v, b.rolling_spin(v), owner)
		touch_timer = 0.25
		if carrier != null:
			carrier.ball_handler.lockout = maxf(carrier.ball_handler.lockout, 0.6)
			carrier.ball_handler.touch_timer = 0.6
		ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_WON, owner.actor_id, owner.team,
			{"victim": carrier.actor_id if carrier != null else -1, "chance": chance}))
	else:
		# Fallar la disputa te deja fuera de posicion un instante.
		owner.locomotion.velocity *= 0.55
		ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_FAILED, owner.actor_id, owner.team,
			{"victim": carrier.actor_id if carrier != null else -1, "chance": chance}))
	return won
