class_name SpKeeper
extends Node
## Arquero de los modos de tiros libres y penales (IA o manejado por el usuario) sobre un SpActor con los clips del banco
## JSON. Reutiliza el planificador del partido (KeeperPlanner: elige el clip cuyas MANOS medidas llegan a la pelota, con su
## instante de inicio y velocidad) y resuelve el contacto con la pelota de forma fisica:
##  - La IA no conoce el resultado: en un tiro libre lee la trayectoria DESPUES del golpe (tiempo de reaccion y error de
##    percepcion segun la dificultad); en un penal tiene que adivinar antes del contacto y se juega con lo que lee del
##    cuerpo del tirador (a veces acierta el lado, a veces no).
##  - El usuario elige la zona antes del tiro; el arquero se lanza hacia esa zona cuando el tirador golpea.
##  - Penal: la estirada nunca arranca mas de PENALTY_ANTICIPATION antes del golpe (como los arqueros reales, que salen
##    casi en el contacto); antes solo espera en su sitio.
##  - Contacto: esferas en manos, antebrazos, cabeza, pecho, cadera y piernas siguen a los huesos del clip. El choque se
##    resuelve con el movimiento RELATIVO pelota-esfera en el paso (el que paso y el que viene): instante de contacto y
##    normal real del choque (de la esfera al centro de la pelota en ese instante). Se ataja si llega a las dos manos y no
##    va demasiado rapida; si no, rebota con la velocidad relativa y un coeficiente de restitucion (desvio con las manos,
##    rebote en el cuerpo): un golpe de frente la devuelve, un roce la deja seguir. El impulso sale antes de que la pelota
##    atraviese la mano (no se «cuela» entre dos pasos). Si no la toca, es gol o fuera: la pelota nunca se mueve hacia las
##    manos.
##  - Pelota suelta (collect): va a buscarla y la recoge con un clip de recogida cuando la tiene cerca y lenta.
##  - Reacciones: si el resultado llega mientras se tira o se levanta, la reaccion queda pendiente y se juega al terminar
##    (no se queda en bucle esperando).

signal touched_ball(kind: StringName)

enum State { IDLE, WAIT_DIVE, DIVE, HOLD, GETUP, REACT, COLLECT }

const PARTS := [
	["mixamorig_LeftHand", 0.13, true], ["mixamorig_RightHand", 0.13, true],
	["mixamorig_LeftForeArm", 0.09, false], ["mixamorig_RightForeArm", 0.09, false],
	["mixamorig_Head", 0.12, false], ["mixamorig_Spine2", 0.19, false], ["mixamorig_Hips", 0.17, false],
	["mixamorig_LeftLeg", 0.10, false], ["mixamorig_RightLeg", 0.10, false],
	["mixamorig_LeftFoot", 0.09, false], ["mixamorig_RightFoot", 0.09, false],
]
## Las manos se extienden un poco mas alla de la muñeca (dedos y guantes).
const HAND_REACH := 0.09
## Rebote contra el arquero: restitucion normal (guante que amortigua / cuerpo) y velocidad tangencial que conserva (el
## latex del guante agarra mas que la ropa). PALM_BIAS: cuanto se orienta la palma hacia la pelota que llega de frente.
const HAND_RESTITUTION := 0.28
const BODY_RESTITUTION := 0.45
const GLOVE_GRIP := 0.6
const BODY_GRIP := 0.8
const PALM_BIAS := 0.8

var actor: SpActor
var ball: Ball
var goal_x: float = 52.5
var half_goal: float = 3.66
var goal_height: float = 2.44
var home := Vector3.ZERO
var facing := Vector3(-1, 0, 0)
var state: int = State.IDLE
## Arquero de la IA (false: lo maneja el usuario y respeta su eleccion de zona).
var ai: bool = true
## Tiro «flojo» (m/s): la IA no se juega antes del golpe y, si ya eligio lado pero todavia no se tiro, lee la pelota real.
const SLOW_SHOT := 17.0
## Penal: lo maximo (s) que la estirada arranca antes del golpe del tirador. Medido antes del arreglo: el plan la arrancaba
## 0,2-0,7 s antes (hasta 1,3 s) y se veia al arquero tirarse antes del golpe.
const PENALTY_ANTICIPATION := 0.12
## Radio de contacto que pide el plan de las estiradas respecto del partido: el contacto aqui es con esferas en los huesos
## (mano 0,13 m + 0,09 de dedos + pelota), mas chico que el radio del partido (0,42-0,60 m alrededor del centro de las
## manos). Con 1,0 el plan «llegaba» con las manos a 0,4 m de la pelota y no la tocaba (medido en las pruebas de render).
const PLAN_RADIUS_SCALE := 0.6
## Recogida de la pelota suelta: velocidad de carrera (m/s), distancia y velocidad de la pelota para intentar recogerla.
const COLLECT_RUN := 4.6
const COLLECT_REACH := 1.6
const COLLECT_BALL_SPEED := 5.0
## Distancia manos-pelota (m) a la que la recogida la deja en las manos (radio de contacto de los clips gk_scoop).
const PICKUP_HANDS := 0.4
## Festejo corto (s) cuando despues tiene que ir a buscar la pelota.
const SHORT_REACTION := 2.2
var rng := RandomNumberGenerator.new()
## Ultimo plan de atajada (diagnostico y pruebas).
var plan: Dictionary = {}
## Toco la pelota en esta jugada (y como).
var touch_kind: StringName = &""
## Ultimo choque con la pelota (diagnostico y pruebas): parte, normal, velocidad de la pelota antes y despues.
var last_contact: Dictionary = {}
var _dive_in: float = -1.0
var _prev_ball := Vector3.ZERO
var _prev_parts: Dictionary = {}
var _last_contact_ms: int = -100000
var _anchor: Node3D
var _idle_clip: StringName = &""
## Reaccion pendiente (-1 ninguna, 0 lamento, 1 festejo): se juega cuando termina la estirada o la levantada.
var _pending_react: int = -1
## Pelota suelta: quiere ir a buscarla (empieza cuando esta de pie), la esta recogiendo, tiempo en la busqueda.
var _collect_wanted: bool = false
var _collecting: bool = false
var _collect_t: float = 0.0
## De pie con la pelota en las manos, listo para festejar o sacar (lo lee el juego).
var ready_with_ball: bool = false
## Otro sistema maneja al actor (SpLooseBall: el arquero despeja con el pie): no decide ni choca la pelota mientras tanto.
var paused: bool = false:
	set(v):
		paused = v
		if not v:
			_prev_parts.clear()
			if ball != null:
				_prev_ball = ball.global_position

func setup(a: SpActor, b: Ball, gx: float, half: float, height: float) -> void:
	actor = a
	ball = b
	goal_x = gx
	half_goal = half
	goal_height = height
	actor.role = &"keeper"
	actor.clip_finished.connect(_on_clip_finished)
	_anchor = Node3D.new()
	_anchor.name = "KeeperHoldAnchor"
	add_child(_anchor)
	var idles: Array[StringName] = SpClips.by_role(&"gk_idle", false)
	_idle_clip = idles[0] if not idles.is_empty() else &""

## Coloca al arquero en su sitio, mirando al campo, en espera.
func reset(home_pos: Vector3) -> void:
	home = Vector3(home_pos.x, 0.0, home_pos.z)
	facing = Vector3(-1, 0, 0)
	state = State.IDLE
	plan = {}
	touch_kind = &""
	last_contact = {}
	_dive_in = -1.0
	_zone = Vector3.INF
	_commit_point = Vector3.INF
	committed_zone = -1
	sure = false
	_sure_drift = Vector3.ZERO
	_sure_extra = 0.0
	_watching = false
	_plan_v = Vector3.ZERO
	cancelled_dives = 0
	picked_up = 0
	_pending_react = -1
	_collect_wanted = false
	_collecting = false
	ready_with_ball = false
	paused = false
	_prev_parts.clear()
	actor.stop_moving()
	actor.ground_y = 0.0
	actor.global_position = home
	actor.set_facing(facing)
	var idles: Array[StringName] = SpClips.by_role(&"gk_idle", false)
	idles.append_array(SpClips.by_role(&"gk_idle_var", false))
	_idle_clip = idles[rng.randi() % idles.size()] if not idles.is_empty() else &""
	actor.rest_loop = _idle_clip
	actor.freeze_on_finish = false
	actor.play_loop(_idle_clip, 0.2)
	if ball != null:
		_prev_ball = ball.global_position

## Paso lateral hacia una posicion (antes del tiro): sigue a la pelota sin dejar el arco.
func shuffle_to(p: Vector3, speed: float = 1.4) -> void:
	if state != State.IDLE:
		return
	var side_loop: StringName = &"jn_gk_sidestep_0184" if SpClips.has(&"jn_gk_sidestep_0184") else &""
	if Vector3(p.x - actor.global_position.x, 0.0, p.z - actor.global_position.z).length() > 0.08:
		actor.move_to(p, speed, side_loop, facing)

# --- Decisiones ----------------------------------------------------------------------------------------------------------

func _yaw() -> float:
	return Locomotion.yaw_from_dir(facing)

## IA, despues del golpe (tiro libre): mira la pelota REAL. Pasado su tiempo de reaccion la vuelve a leer cada READ_EVERY s
## (posicion, velocidad y parte del giro) con un error de percepcion fijo para esta jugada que se achica a medida que la
## pelota se acerca, replanifica, y se tira en el ultimo instante que le permite llegar. Si la pelota se desvia (barrera,
## jugadores) lee la trayectoria nueva. No conoce el resultado: si lee mal o no llega, no la toca.
## Cada cuanto vuelve a leer la pelota (s): el plan cuesta varios ms en un telefono.
const READ_EVERY := 0.1
## Preferencia por las estiradas rapidas (costo por segundo entre el arranque y el contacto): arranca mas tarde y lee mas.
## Ultima lectura del tiro libre (diagnostico y pruebas): plan, tiempo de llegada y cruce que leyo.
var last_read: Dictionary = {}
const QUICK_DIVE_COST := 0.25
## Estirada desesperada: solo si el mejor plan deja las manos a menos de este multiplo del radio de contacto, y solo en el
## ultimo instante (la pelota llega al arquero en menos de LAST_CHANCE s). Mas lejos no se tira (no llega).
const DESPERATE_REACH := 1.3
const LAST_CHANCE := 0.55
## Radio de contacto que pide el plan del tiro libre (lectura de la pelota real) respecto del partido.
var watch_radius_scale: float = 1.0
var _watching: bool = false
var _watch_t: float = 0.0
var _read_t: float = 0.0
var _err_yaw: float = 0.0
var _err_pitch: float = 0.0
var _spin_seen: float = 0.85
## Velocidad de la pelota cuando se agendo la estirada (para notar un desvio) y estiradas canceladas (diagnostico).
var _plan_v := Vector3.ZERO
var cancelled_dives: int = 0
## Pelotas sueltas recogidas en esta jugada (diagnostico y pruebas).
var picked_up: int = 0

func read_shot(_ball_pos: Vector3, _velocity: Vector3, _spin: Vector3) -> void:
	if state != State.IDLE:
		return
	_watching = true
	_watch_t = SpSettings.keeper_reaction()
	_read_t = 0.0
	var err: float = SpSettings.keeper_perception_deg()
	_err_yaw = deg_to_rad(rng.randfn(0.0, err))
	_err_pitch = deg_to_rad(rng.randfn(0.0, err * 0.7))
	var sr: Vector2 = SpSettings.keeper_spin_read()
	_spin_seen = rng.randf_range(sr.x, sr.y)

func _watch_step(delta: float) -> void:
	if not _watching or not (state == State.IDLE or state == State.WAIT_DIVE):
		return
	_watch_t -= delta
	if _watch_t > 0.0:
		return
	# Esperando para tirarse: si la pelota cambia de golpe (la desvio la barrera o un jugador), la vuelve a leer ya.
	if state == State.WAIT_DIVE and _plan_v != Vector3.ZERO:
		var bv_now: Vector3 = ball.linear_velocity
		if bv_now.length() < _plan_v.length() * 0.75 or bv_now.normalized().dot(_plan_v.normalized()) < cos(deg_to_rad(15.0)):
			_read_t = 0.0
	_read_t -= delta
	if _read_t > 0.0:
		return
	_read_t = READ_EVERY
	if ball.is_held():
		_watching = false
		return
	var bp: Vector3 = ball.global_position
	var bv: Vector3 = ball.linear_velocity
	if bv.x < 0.5 or bp.x > goal_x:
		if state == State.WAIT_DIVE:
			# Ya no viene al arco (desviada hacia atras): no se tira a la nada.
			_cancel_dive()
		return
	# El error se achica con la distancia que le queda a la pelota.
	var k: float = clampf((goal_x - bp.x) / 25.0, 0.15, 1.0)
	var h := Vector3(bv.x, 0.0, bv.z)
	var side := Vector3(-h.z, 0.0, h.x).normalized() if h.length() > 0.01 else Vector3.RIGHT
	var v_seen: Vector3 = bv.rotated(Vector3.UP, _err_yaw * k).rotated(side, -_err_pitch * k)
	var traj: PackedVector3Array = BallPredictor.trajectory(bp, v_seen, 2.0, 1.0 / 30.0, ball.angular_velocity * _spin_seen, true)
	var cross: Vector3 = ShotSolver.crossing(traj, goal_x - 0.2)
	if cross == Vector3.INF or absf(cross.z) > half_goal + 1.0 or cross.y > goal_height + 0.6:
		if state == State.WAIT_DIVE:
			# La lectura nueva dice que ya no va al arco (desviada, se frena o se va): cancela la estirada.
			_cancel_dive()
		if cross != Vector3.INF:
			actor.face_towards(Vector3(bp.x, 0, bp.z) - actor.global_position)
			return
	var human := Vector2(Tuning.keeper.hand_latency, Tuning.keeper.hand_speed) if Tuning.keeper != null else Vector2.ZERO
	var pl: Dictionary = KeeperPlanner.plan_save(actor.global_position, _yaw(), traj, 1.0 / 30.0, 0.0, bv.length(), false, [1.0, 1.25], human,
		watch_radius_scale, QUICK_DIVE_COST)
	# Tiempo hasta que la pelota llega a la altura del arquero (segun lo que lee).
	var t_reach: float = INF
	var kx: float = actor.global_position.x - 0.3
	for i in traj.size():
		if traj[i].x >= kx:
			t_reach = float(i) / 30.0
			break
	last_read = {"plan": pl, "t_reach": t_reach, "cross": cross}
	if state == State.WAIT_DIVE:
		# Lectura mas cercana (menos error): si el plan nuevo llega, reemplaza al agendado.
		if not pl.is_empty() and float(pl["dist"]) <= float(pl["radius"]):
			plan = pl
			_plan_v = bv
			_dive_in = float(pl["delay"])
			if _dive_in <= 0.0:
				_start_dive()
		return
	if pl.is_empty() or float(pl.get("dist", 0.0)) > float(pl.get("radius", 0.5)):
		# Todavia no llega con ningun clip: NO se tira (antes arrancaba la estirada mas cercana apenas leia la pelota, con
		# la pelota a 20 m: se tiraba antes de tiempo y la pelota entraba). Se acomoda con pasos laterales hacia donde va la
		# pelota y sigue leyendo; solo en el ultimo instante, si casi llega, se tira desesperado.
		if cross != Vector3.INF:
			var z: float = clampf(cross.z, -half_goal + 0.4, half_goal - 0.4)
			shuffle_to(Vector3(actor.global_position.x, 0.0, z), SpSettings.keeper_step_speed())
		if pl.is_empty():
			return
		# Casi llega y su estirada tiene que arrancar YA (el plan lo dice: esperar solo la aleja, medido: 0,57 -> 0,73 ->
		# 0,96 m en tres lecturas) o la pelota ya esta encima: se tira. Si no casi llega, no se tira a la nada.
		var near: bool = float(pl["dist"]) <= float(pl["radius"]) * DESPERATE_REACH
		var now: bool = float(pl["delay"]) <= READ_EVERY * 1.5 or t_reach <= LAST_CHANCE
		if not (near and now):
			return
	elif cross != Vector3.INF and t_reach > LAST_CHANCE and float(pl["delay"]) > READ_EVERY * 3.0:
		# Llega, pero falta: se acomoda hacia el cruce mientras espera (pasos cortos; el plan se rehace en cada lectura).
		var dz: float = clampf(cross.z, -half_goal + 0.4, half_goal - 0.4) - actor.global_position.z
		if absf(dz) > 0.5:
			shuffle_to(Vector3(actor.global_position.x, 0.0, actor.global_position.z + signf(dz) * minf(absf(dz) * 0.5, 0.8)), SpSettings.keeper_step_speed())
	plan = pl
	# Espera mientras pueda: se tira cuando la estirada tiene que empezar ya (o si ya no llega de ninguna forma, al final).
	if float(pl["delay"]) <= READ_EVERY * 1.5:
		# El plan dice cuando arrancar: ni antes (las manos pasarian antes que la pelota) ni despues. Sigue mirando la
		# pelota hasta arrancar (si la desvian, cancela; si la lectura mas cercana cambia el plan, lo ajusta).
		state = State.WAIT_DIVE
		_plan_v = bv
		_dive_in = float(pl["delay"])
		if _dive_in <= 0.0:
			_start_dive()

## Estirada agendada que ya no tiene sentido (la pelota no viene): vuelve a la espera mirando la pelota.
func _cancel_dive() -> void:
	state = State.IDLE
	plan = {}
	_dive_in = -1.0
	_plan_v = Vector3.ZERO
	cancelled_dives += 1

## Penal: el arquero se juega ANTES del golpe a una zona del arco (la elige el usuario o la IA con lo que lee del tirador):
## lead = segundos que faltan para el contacto y speed_guess = la velocidad que espera por la carrera y el impulso del
## tirador (no el destino). Como los arqueros reales, puede arrancar la estirada un instante antes del golpe, pero nunca
## mas de PENALTY_ANTICIPATION: el plan solo elige clips que llegan saliendo desde ahi. Nunca usa el destino real del tiro:
## si eligio mal el lado, no llega. Sin lead (decide al ver salir la pelota), sincroniza con on_kick.
var _zone := Vector3.INF
## Zona a la que se jugo antes del golpe (para ajustar el momento de la estirada al ver salir la pelota).
var _commit_point := Vector3.INF

## Zona segura (pedido del usuario: «si me tiro abajo a la derecha y el tiro va ahi, es atajada»). El arco se divide en
## zonas (KeeperZones, 3 x 2); si el arquero se jugo a una zona y el tiro REAL cruza la linea en esa zona, al salir la
## pelota replanifica con la trayectoria real eligiendo entre todos sus clips (SURE_SPEEDS, sin latencia humana), y
## durante la estirada predice donde va a estar la pelota cuando lleguen las manos y corrige el marco del clip hacia ella
## (hasta SURE_MAX_DRIFT en el piso). Lo que falte (sobre todo en altura) lo cubre el guante con un alcance extra
## (hasta SURE_MAX_EXTRA). El manotazo saca la pelota hacia afuera (SURE_PARRY_*): la pelota solo cambia por el impulso
## del choque (Ball.kick), nunca se la mueve a las manos.
const SURE_SPEEDS := [1.0, 1.2, 1.4, 1.6]
const SURE_MAX_DRIFT := 1.3
const SURE_MAX_EXTRA := 0.7
## Cuanto puede elevarse el cuerpo en la estirada asegurada (m; vuelve al piso despues) y entre que ritmos puede ir el
## clip para que las manos lleguen justo.
const SURE_MAX_LIFT := 0.5
const SURE_RATE := Vector2(0.5, 2.2)
## Superficie entre las dos palmas (centro entre las manos, radio) que cuenta como mano en la atajada segura.
const SURE_PALMS := ["palms", 0.2, true]
const SURE_PARRY_RESTITUTION := 0.35
const SURE_PARRY_IN := 0.8
const SURE_PARRY_OUT := 0.45
const SURE_PARRY_UP := 0.15
## Zonas seguras activas (penales: arquero del usuario y de la IA).
var sure_zones: bool = true
## Zona a la que se jugo (KeeperZones; -1 = ninguna).
var committed_zone: int = -1
## Esta jugada la ataja seguro (el tiro va a su zona) hasta que la toca.
var sure: bool = false
var sure_saves: int = 0
var _sure_drift := Vector3.ZERO
var _sure_extra: float = 0.0
var _sure_k: int = 0
## Diagnostico de la ultima atajada asegurada: pasos de seguimiento y menor distancia prevista manos-pelota que quedo.
var sure_steps: int = 0
var sure_gap: float = INF

func commit_to(point: Vector3, ball_pos: Vector3, lead: float, speed_guess: float = 22.0) -> void:
	if state != State.IDLE:
		return
	actor.stop_moving()
	_commit_point = point
	committed_zone = KeeperZones.zone_of(point, half_goal, goal_height)
	if lead <= 0.01:
		_zone = point
		return
	_plan_with(_line_traj(ball_pos, point, speed_guess, lead), maxf(lead - PENALTY_ANTICIPATION, 0.0))
	if plan.is_empty():
		# Ningun clip sirve saliendo tan tarde: se tira hacia la zona al ver salir la pelota.
		_zone = point

## La pelota salio y ya habia elegido zona sin anticipar: planifica hacia esa zona con la velocidad que ve.
func on_kick(ball_pos: Vector3, velocity: Vector3) -> void:
	if ai and velocity.length() < SLOW_SHOT:
		# Tiro flojo: si todavia no se tiro, tiene tiempo de verlo y cambiar (no se queda mirando como entra).
		if state == State.WAIT_DIVE and _dive_in > SpSettings.keeper_reaction() * 0.5:
			state = State.IDLE
			plan = {}
			_dive_in = -1.0
		if state == State.IDLE:
			_zone = Vector3.INF
			read_shot(ball_pos, velocity, Vector3.ZERO)
			return
	var speed_seen: float = maxf(velocity.length() * rng.randf_range(0.92, 1.08), 8.0)
	if state == State.WAIT_DIVE and _commit_point != Vector3.INF:
		# Ya eligio el lado y todavia no arranco: al ver salir la pelota ajusta el MOMENTO de la estirada (no el lado) con la
		# velocidad que ve (con su error). Si el plan nuevo no llega, sigue con el que tenia.
		var pl: Dictionary = _make_plan(_line_traj(ball_pos, _commit_point, speed_seen, 0.0), 0.0)
		if not pl.is_empty() and float(pl["dist"]) <= float(pl["radius"]):
			_adopt(pl)
		return
	if _zone == Vector3.INF or state != State.IDLE:
		return
	var z: Vector3 = _zone
	_zone = Vector3.INF
	_plan_with(_line_traj(ball_pos, z, speed_seen, 0.0), 0.05)

## Al salir la pelota (penal): si el tiro REAL (traj, muestras cada `step` s desde el golpe) cruza la linea en la zona a
## la que se jugo, la atajada es segura: replanifica con esa trayectoria y la sigue en la estirada (ver «Zona segura»).
## Devuelve true si esta jugada queda asegurada.
func sure_save_check(traj: PackedVector3Array, step: float) -> bool:
	sure = false
	_sure_drift = Vector3.ZERO
	_sure_extra = 0.0
	if not sure_zones or committed_zone < 0 or traj.size() < 2:
		return false
	if state != State.IDLE and state != State.WAIT_DIVE and state != State.DIVE:
		return false
	var cross: Vector3 = ShotSolver.crossing(traj, goal_x)
	if KeeperZones.zone_of(cross, half_goal, goal_height) != committed_zone:
		return false
	var every: int = maxi(int(round((1.0 / 30.0) / step)), 1)
	var t30 := PackedVector3Array()
	for i in range(0, traj.size(), every):
		t30.append(traj[i])
	var pl: Dictionary = KeeperPlanner.plan_save(actor.global_position, _yaw(), t30, 1.0 / 30.0, 0.0, 20.0, false, SURE_SPEEDS, Vector2.ZERO, PLAN_RADIUS_SCALE)
	if pl.is_empty():
		return false
	# Si ya arranco la estirada hacia el centro de la zona (hasta PENALTY_ANTICIPATION antes del golpe), sigue desde donde
	# esta con el clip que mejor llega a la pelota real.
	state = State.IDLE
	_zone = Vector3.INF
	_sure_k = int(pl["k"])
	sure = true
	sure_steps = 0
	sure_gap = INF
	_adopt(pl)
	return true

## Estirada asegurada (cada paso, mientras se tira): toma donde estaran las manos en la muestra _sure_k del clip (con la
## diferencia medida entre la trayectoria del clip y los huesos reales), calcula cuando la pelota llega a esa profundidad
## y donde estara, y: ajusta el ritmo del clip para que las manos lleguen en ese instante (SURE_RATE), corre el marco del
## clip de costado hacia la pelota (SURE_MAX_DRIFT) y eleva el cuerpo si va alta (SURE_MAX_LIFT), todo de a poco. Lo que
## falte queda como alcance extra del guante (SURE_MAX_EXTRA).
func _sure_steer(delta: float) -> void:
	if plan.is_empty():
		return
	var clip: StringName = plan["clip"]
	var yaw: float = Locomotion.yaw_from_dir(actor.frame_facing)
	var ct: float = actor.clip_time()
	var tau: float = float(_sure_k) / 30.0
	var k_now: int = int(round(ct * 30.0))
	var fix: Vector3 = actor.hands_mid() - KeeperPlanner.hands_world(clip, k_now, actor.frame_origin, yaw) - Vector3.UP * actor.ground_y
	var hands: Vector3 = KeeperPlanner.hands_world(clip, _sure_k, actor.frame_origin, yaw) + fix + Vector3.UP * actor.ground_y
	var v: Vector3 = ball.linear_velocity
	var rate: float = actor.clip_rate()
	var t_clip: float = (tau - ct) / maxf(actor.clip_speed * rate, 0.05)
	var t_ball: float = t_clip
	if absf(v.x) > 0.5:
		t_ball = (hands.x - ball.global_position.x) / v.x
	if t_ball > 0.03 and tau > ct:
		var want: float = (tau - ct) / maxf(actor.clip_speed, 0.05) / t_ball
		rate = clampf(want, SURE_RATE.x, SURE_RATE.y)
		actor.set_clip_rate(rate)
	var tr: float = maxf(t_ball, 0.0)
	var pred: Vector3 = ball.global_position + v * tr + Vector3.DOWN * (4.905 * tr * tr)
	var off: Vector3 = pred - hands
	if t_ball > 0.0:
		var f: float = clampf(delta / maxf(t_ball, delta), 0.0, 1.0)
		var move := Vector3(0.0, 0.0, off.z) * f
		var total: Vector3 = _sure_drift + move
		if total.length() > SURE_MAX_DRIFT:
			total = total.normalized() * SURE_MAX_DRIFT
			move = total - _sure_drift
		actor.frame_origin += move
		_sure_drift = total
		off -= move
		var lift: float = clampf(actor.ground_y + off.y * f, 0.0, SURE_MAX_LIFT)
		off.y -= lift - actor.ground_y
		actor.ground_y = lift
	_sure_extra = clampf(off.length(), 0.0, SURE_MAX_EXTRA)
	sure_steps += 1
	sure_gap = off.length()

## Trayectoria supuesta: la pelota quieta `wait` segundos y despues en linea (con un poco de comba) hasta el punto.
static func _line_traj(ball_pos: Vector3, point: Vector3, speed: float, wait: float) -> PackedVector3Array:
	var step: float = 1.0 / 30.0
	var traj := PackedVector3Array()
	for i in maxi(int(round(wait / step)), 0):
		traj.append(ball_pos)
	var to: Vector3 = point - ball_pos
	var t_fly: float = to.length() / maxf(speed, 5.0)
	for i in int(ceil(t_fly / step)) + 9:
		var u: float = float(i) * step / t_fly
		var p: Vector3 = ball_pos + to * u
		p.y += sin(clampf(u, 0.0, 1.0) * PI) * 0.15
		traj.append(p)
	return traj

## IA en un penal: elige donde lanzarse con la lectura del cuerpo del tirador. cue_point: hacia donde apuntan la carrera y
## la cadera del tirador (no es el resultado: el tiro puede ir a otro lado si el tirador corrige o falla).
func guess_penalty(cue_point: Vector3, ball_pos: Vector3, lead: float, speed_guess: float = 22.0) -> Vector3:
	var p := Vector3(goal_x, 0.0, 0.0)
	if speed_guess < SLOW_SHOT:
		# La carrera y el impulso anuncian un tiro suave: espera y reacciona a la pelota (on_kick).
		return p
	var r: float = rng.randf()
	if r < SpSettings.keeper_read_probability():
		p.z = cue_point.z + rng.randfn(0.0, 0.6)
	elif r < 0.9:
		p.z = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(1.2, half_goal - 0.4)
	else:
		p.z = rng.randfn(0.0, 0.4)
	p.z = clampf(p.z, -half_goal + 0.3, half_goal - 0.3)
	var hr: float = rng.randf()
	p.y = 0.35 if hr < 0.45 else (1.1 if hr < 0.8 else 1.8)
	commit_to(p, ball_pos, lead, speed_guess)
	return p

func _plan_with(traj: PackedVector3Array, min_delay: float) -> void:
	var pl: Dictionary = _make_plan(traj, min_delay)
	plan = pl
	if not pl.is_empty():
		_adopt(pl)

func _make_plan(traj: PackedVector3Array, min_delay: float) -> Dictionary:
	var human := Vector2(Tuning.keeper.hand_latency, Tuning.keeper.hand_speed) if Tuning.keeper != null else Vector2.ZERO
	return KeeperPlanner.plan_save(actor.global_position, _yaw(), traj, 1.0 / 30.0, min_delay, 20.0, false, [1.0, 1.2, 1.4], human, PLAN_RADIUS_SCALE)

## Toma el plan: espera su demora y se tira (o se tira ya).
func _adopt(pl: Dictionary) -> void:
	plan = pl
	state = State.WAIT_DIVE
	_dive_in = float(plan["delay"])
	if _dive_in <= 0.0:
		_start_dive()

func _start_dive() -> void:
	_dive_in = -1.0
	_watching = false
	state = State.DIVE
	actor.stop_moving()
	actor.play_clip(plan["clip"], actor.global_position, facing, 0.08, float(plan["speed"]), 0.0)

# --- Paso ----------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if actor == null or ball == null or paused:
		return
	if state == State.WAIT_DIVE:
		_dive_in -= delta
		if _dive_in <= 0.0:
			_start_dive()
	if sure and state == State.DIVE and not _collecting:
		_sure_steer(delta)
	elif actor.ground_y > 0.0:
		# Despues de la estirada elevada, el cuerpo vuelve al piso (cae).
		actor.ground_y = move_toward(actor.ground_y, 0.0, 3.0 * delta)
	_watch_step(delta)
	if _collect_wanted and state == State.IDLE:
		_collect_wanted = false
		state = State.COLLECT
		_collect_t = 0.0
	if state == State.COLLECT:
		_collect_step(delta)
	elif state == State.DIVE and _collecting and not ball.is_held():
		# Recogida: cuando las manos llegan a la pelota (radio de contacto de los clips de recogida), queda en las manos.
		if actor.hands_mid().distance_to(ball.global_position) < PICKUP_HANDS and ball.linear_velocity.length() < 6.0:
			_pick_up()
	if state == State.HOLD:
		_anchor.global_position = actor.hands_mid() + facing * 0.08
	elif not ball.is_held():
		Prof.begin(&"arquero (contacto)")
		_check_contact(delta)
		Prof.end(&"arquero (contacto)")
	_prev_ball = ball.global_position

func _check_contact(delta: float) -> void:
	var p1: Vector3 = ball.global_position
	var p0: Vector3 = _prev_ball
	if p0.distance_to(p1) > 3.0:
		# La pelota se recoloco (nuevo turno): ningun tiro recorre 3 m en un paso. No es un choque.
		_prev_parts.clear()
		return
	# Proximo paso de la pelota (sin la gravedad ni el aire de un paso: centimetros).
	var p2: Vector3 = p1 + ball.linear_velocity * delta
	var now: int = Time.get_ticks_msec()
	var parts_now: Dictionary = {}
	var best_s: float = INF
	var best: Array = []
	var parts: Array = PARTS
	if sure:
		# Atajada segura: las dos manos juntas tapan el hueco entre los guantes (una pelota de 22 cm no pasa entre las
		# palmas abiertas de un arquero).
		parts = PARTS + [SURE_PALMS]
	for part in parts:
		var c: Vector3 = actor.hands_mid() if part[0] == SURE_PALMS[0] else actor.bone_world(part[0])
		if bool(part[2]) and part[0] != SURE_PALMS[0]:
			var fore: Vector3 = actor.bone_world("mixamorig_LeftForeArm" if String(part[0]).contains("Left") else "mixamorig_RightForeArm")
			var dir: Vector3 = c - fore
			if dir.length() > 0.01:
				c += dir.normalized() * HAND_REACH
		parts_now[part[0]] = c
		var c0: Vector3 = _prev_parts.get(part[0], c)
		var r: float = float(part[1]) + ball.radius + (_sure_extra if sure and bool(part[2]) else 0.0)
		# Paso que paso (contacto que ya ocurrio) y paso que viene (se resuelve antes de que la pelota atraviese la mano):
		# s en [0, 2] a lo largo de los dos.
		var hit: Array = contact_along(p0, p1, c0, c, r)
		var s_hit: float = -1.0
		if not hit.is_empty():
			s_hit = float(hit[0])
		else:
			hit = contact_along(p1, p2, c, c + (c - c0), r)
			if not hit.is_empty():
				s_hit = 1.0 + float(hit[0])
		if s_hit >= 0.0 and s_hit < best_s:
			best_s = s_hit
			best = [part, hit[1], hit[2]]
	if not best.is_empty() and now - _last_contact_ms > 150:
		_resolve(best[0], best[1], best[2], parts_now, delta)
		_last_contact_ms = now
	_prev_parts = parts_now

## Primer contacto entre la pelota (de b0 a b1) y una esfera que se mueve (de c0 a c1) en un paso, con radio sumado r.
## Devuelve [s en 0..1, centro de la esfera en el contacto, centro de la pelota en el contacto] o vacio. Si ya se tocan al
## empezar el paso, s = 0.
static func contact_along(b0: Vector3, b1: Vector3, c0: Vector3, c1: Vector3, r: float) -> Array:
	var d0: Vector3 = b0 - c0
	var dd: Vector3 = (b1 - b0) - (c1 - c0)
	var a: float = dd.length_squared()
	var c: float = d0.length_squared() - r * r
	if c <= 0.0:
		return [0.0, c0, b0]
	if a < 1e-10:
		return []
	var b: float = d0.dot(dd)
	if b >= 0.0:
		return []
	var disc: float = b * b - a * c
	if disc < 0.0:
		return []
	var s: float = (-b - sqrt(disc)) / a
	if s < 0.0 or s > 1.0:
		return []
	return [s, c0.lerp(c1, s), b0.lerp(b1, s)]

## c: centro de la esfera en el contacto; q: centro de la pelota en el contacto. La normal del choque va de c a q.
func _resolve(part: Array, c: Vector3, q: Vector3, parts_now: Dictionary, delta: float) -> void:
	var v: Vector3 = ball.linear_velocity
	var cur_c: Vector3 = parts_now.get(part[0], c)
	var prev_c: Vector3 = _prev_parts.get(part[0], cur_c)
	var part_v: Vector3 = (cur_c - prev_c) / maxf(delta, 1e-3)
	var n: Vector3 = (q - c)
	n = n.normalized() if n.length() > 1e-4 else -v.normalized()
	last_contact = {"part": String(part[0]), "normal": n, "v_in": v, "part_v": part_v}
	var vr: Vector3 = v - part_v
	var vn: float = vr.dot(n)
	if vn >= 0.0:
		return
	var is_hand: bool = bool(part[2])
	var was_sure: bool = sure and not _collecting
	if was_sure:
		sure = false
		_sure_extra = 0.0
		sure_saves += 1
	if is_hand and (_can_catch(q, vr, parts_now) or (_collecting and vr.length() < 9.0)):
		actor.freeze_on_finish = true
		ball.hold(_anchor, actor)
		_anchor.global_position = q
		state = State.HOLD
		# Recogida de una pelota suelta: no cambia como termino la jugada (la desvio, o nadie la toco).
		if not _collecting:
			touch_kind = &"catch"
		_collecting = false
		last_contact["v_out"] = Vector3.ZERO
		touched_ball.emit(&"catch")
		return
	var e: float = HAND_RESTITUTION if is_hand else BODY_RESTITUTION
	if was_sure:
		# Atajada segura: manotazo con la palma contra la pelota que llega, hacia afuera (al palo de su lado) y un poco
		# arriba: la saca del arco aunque la toque con la punta de los dedos.
		n = sure_parry_normal(vr, q.z - home.z)
		e = SURE_PARRY_RESTITUTION
		last_contact["normal"] = n
		last_contact["sure"] = true
	elif is_hand:
		n = glove_normal(n, vr, facing)
		last_contact["normal"] = n
	var v_new: Vector3 = rebound(v, part_v, n, e, GLOVE_GRIP if is_hand else BODY_GRIP)
	if was_sure:
		# El manotazo la despide por la normal (afuera del arco), con lo que trae amortiguado por el guante.
		v_new = n * maxf(vr.length() * SURE_PARRY_RESTITUTION, 5.0)
	ball.kick(v_new, ball.angular_velocity * 0.3, actor)
	last_contact["v_out"] = v_new
	touch_kind = &"parry" if is_hand else &"body"
	touched_ball.emit(touch_kind)

## Velocidad de la pelota despues del choque con una parte del cuerpo que se mueve a part_v, con normal n (de la parte a
## la pelota) y restitucion e: la componente normal relativa se invierte y se achica (e), la tangencial pierde un 20 %
## (roce del guante o la ropa). Golpe de frente: la pelota vuelve; roce: sigue casi igual.
static func rebound(v: Vector3, part_v: Vector3, n: Vector3, e: float, grip: float = BODY_GRIP) -> Vector3:
	var vr: Vector3 = v - part_v
	var vn: float = vr.dot(n)
	if vn >= 0.0:
		return v
	var vt: Vector3 = vr - n * vn
	return part_v + vt * grip - n * vn * e

## Guante: no es una esfera sino una superficie ancha que el arquero pone con la palma hacia la pelota. Si la pelota llega
## de frente (desde el campo), la normal del choque se inclina hacia la direccion de llegada (PALM_BIAS): un toque de
## costado con la mano abierta la frena y la abre mucho mas que un roce contra una esfera. Por detras o de costado puro
## (la pelota ya paso) queda la normal de la esfera.
static func glove_normal(n: Vector3, vr: Vector3, keeper_facing: Vector3) -> Vector3:
	if vr.length() < 0.5:
		return n
	var incoming: Vector3 = -vr.normalized()
	if incoming.dot(keeper_facing) < 0.3:
		return n
	return (n + incoming * PALM_BIAS).normalized()

## Normal del manotazo de una atajada segura: contra la pelota que llega (vr: velocidad relativa), hacia el costado de la
## pelota (side: z de la pelota respecto del arquero) y algo hacia arriba.
static func sure_parry_normal(vr: Vector3, side: float) -> Vector3:
	var incoming: Vector3 = -vr.normalized() if vr.length() > 0.1 else Vector3(-1, 0, 0)
	var out := Vector3(0, 0, signf(side) if absf(side) > 0.05 else 1.0)
	return (incoming * SURE_PARRY_IN + out * SURE_PARRY_OUT + Vector3.UP * SURE_PARRY_UP).normalized()

func _pick_up() -> void:
	actor.freeze_on_finish = true
	ball.hold(_anchor, actor)
	_anchor.global_position = actor.hands_mid() + facing * 0.08
	state = State.HOLD
	picked_up += 1
	_collecting = false
	last_contact = {"part": "hands", "pickup": true}
	touched_ball.emit(&"catch")

## Atrapa si la pelota llega a las dos manos, no va demasiado rapida y viene de frente a una altura atrapable.
func _can_catch(q: Vector3, vr: Vector3, parts_now: Dictionary) -> bool:
	if vr.length() > SpSettings.keeper_catch_speed():
		return false
	if q.y < 0.12 or q.y > 2.5:
		return false
	var hl: Vector3 = parts_now.get("mixamorig_LeftHand", Vector3.INF)
	var hr: Vector3 = parts_now.get("mixamorig_RightHand", Vector3.INF)
	if hl.distance_to(q) > 0.42 or hr.distance_to(q) > 0.42:
		return false
	return vr.normalized().dot(facing) < -0.2

func _on_clip_finished(_id: StringName) -> void:
	match state:
		State.DIVE:
			if actor.bone_world(SpActor.HIPS).y < 0.55:
				_getup()
			else:
				# Si la recogida no llego a las manos, sigue buscandola (_back_to_idle).
				_back_to_idle(0.25)
		State.HOLD:
			if actor.bone_world(SpActor.HIPS).y < 0.55:
				_getup()
			else:
				ready_with_ball = true
		State.GETUP:
			if ball.is_held() and ball.holder == actor:
				state = State.HOLD
				actor.play_loop(_idle_clip, 0.3)
				ready_with_ball = true
			else:
				_back_to_idle(0.3)
		State.REACT:
			state = State.IDLE
			actor.play_loop(_idle_clip, 0.3)

## Vuelve a la espera en su sitio actual (despues de que otro sistema lo manejo).
func idle() -> void:
	actor.stop_moving()
	_back_to_idle(0.3)

## De pie y libre: juega la reaccion pendiente o vuelve a la espera (o sigue buscando la pelota suelta).
func _back_to_idle(blend: float) -> void:
	state = State.IDLE
	if _collecting:
		_collecting = false
		if _collect_t < 4.5 and not ball.is_held():
			state = State.COLLECT
			return
	if _pending_react >= 0:
		# Primero la reaccion (festejo de la atajada); si despues tiene que ir por la pelota, va al terminar.
		var happy: bool = _pending_react == 1
		_pending_react = -1
		react(happy)
		if state == State.REACT:
			return
	actor.play_loop(_idle_clip, blend)

func _getup() -> void:
	var lie: String = String(SpClips.meta(actor.clip_id).get("lie", ""))
	var pool: Array[StringName] = []
	for id in SpClips.by_role(&"gk_getup"):
		if lie == "" or String(SpClips.meta(id).get("lie", "")) == lie:
			pool.append(id)
	if pool.is_empty():
		pool = SpClips.by_role(&"gk_getup")
	if pool.is_empty():
		return
	var keep_hold: bool = state == State.HOLD
	actor.play_here(pool[rng.randi() % pool.size()], 0.3)
	state = State.HOLD if keep_hold else State.GETUP

## Festejo (atajo) o lamento (le hicieron gol) en el sitio, cuando ya esta de pie. Si todavia se esta tirando o
## levantando, queda pendiente y se juega al terminar.
func react(happy: bool) -> void:
	if state in [State.DIVE, State.WAIT_DIVE, State.GETUP]:
		_pending_react = 1 if happy else 0
		return
	if state in [State.HOLD, State.COLLECT]:
		return
	var roles: Array = [&"gk_gesture", &"celebrate", &"clap"] if happy else [&"dejected", &"angry"]
	# Si despues tiene que ir por la pelota suelta, un festejo corto (el turno siguiente no espera para siempre).
	var max_len: float = SHORT_REACTION if _collect_wanted else INF
	var id: StringName = SpReactions.pick(roles, rng, 1.5, 0.8, max_len)
	if id == &"" and max_len < INF:
		id = SpReactions.pick(roles, rng, 1.5, 0.5, max_len + 1.0)
	if id == &"":
		return
	state = State.REACT
	actor.play_here(id, 0.3)

# --- Pelota suelta ---------------------------------------------------------------------------------------------------------

## Va a buscar la pelota suelta (rebote, tiro flojo que se frena) y la recoge con las manos: arranca en cuanto esta de pie
## (despues de la estirada y la levantada). Con la pelota en las manos se queda con ella (no festeja).
## keep_reaction: festeja primero (penal: la atajada se festeja y despues va por la pelota); sin el, va enseguida (tiro
## libre: la jugada sigue).
func collect(keep_reaction: bool = false) -> void:
	if not keep_reaction:
		_pending_react = -1
	if ball.is_held():
		return
	if keep_reaction and (state in [State.REACT, State.IDLE] or _pending_react >= 0):
		# Primero la reaccion (la pide el juego enseguida); si no hay reaccion, arranca en el paso siguiente.
		_collect_wanted = true
		return
	if state == State.IDLE:
		state = State.COLLECT
		_collect_t = 0.0
	elif state != State.COLLECT:
		_collect_wanted = true

## De pie con la pelota en las manos (despues de atraparla o recogerla): la suelta delante con velocidad v (cae de las
## manos) y vuelve a la espera. Lo usa el juego para el festejo (penal) o el saque (tiro libre).
func drop_ball(v: Vector3) -> void:
	if not (ball.is_held() and ball.holder == actor):
		return
	ready_with_ball = false
	actor.freeze_on_finish = false
	ball.release(actor, v)
	_prev_ball = ball.global_position
	_last_contact_ms = Time.get_ticks_msec()
	state = State.IDLE
	actor.play_loop(_idle_clip, 0.3)

func is_collecting() -> bool:
	return state == State.COLLECT or _collect_wanted or _collecting

func _collect_step(delta: float) -> void:
	_collect_t += delta
	if ball.is_held() or _collect_t > 6.0:
		state = State.IDLE
		_collecting = false
		actor.stop_moving()
		actor.play_loop(_idle_clip, 0.3)
		return
	var bp: Vector3 = ball.global_position
	var bv: Vector3 = ball.linear_velocity
	var me: Vector3 = actor.global_position
	var flat := Vector3(bp.x - me.x, 0.0, bp.z - me.z)
	var dist: float = flat.length()
	# Donde estara la pelota cuando llegue (rodadura y botes medidos de Ball).
	var traj: PackedVector3Array = BallPredictor.trajectory(bp, bv, 1.6, 1.0 / 30.0, ball.angular_velocity, true)
	var k: int = clampi(int(dist / COLLECT_RUN * 30.0), 0, traj.size() - 1)
	var aim: Vector3 = traj[k] if traj.size() > 0 else bp
	var to := Vector3(aim.x - me.x, 0.0, aim.z - me.z)
	if to.length() > 0.05:
		facing = to.normalized()
	if dist < COLLECT_REACH and bv.length() < COLLECT_BALL_SPEED:
		var pl: Dictionary = KeeperPlanner.plan_save(me, _yaw(), traj, 1.0 / 30.0, 0.0, bv.length(), true, [1.0, 1.2])
		if not pl.is_empty() and float(pl.get("dist", 9.0)) <= float(pl.get("radius", 0.5)) and float(pl["delay"]) <= 0.05:
			plan = pl
			_collecting = true
			_start_dive()
			return
	# Corre hacia donde va a estar la pelota y frena al llegar (se agacha a recogerla en el paso siguiente).
	var stop_at: Vector3 = aim - facing * 0.6
	var spd: float = COLLECT_RUN if dist > 3.0 else maxf(1.4, COLLECT_RUN * dist / 3.0)
	actor.move_to(stop_at, spd, SpShooter._loop_for(spd), facing)

## Tiene una reaccion pendiente: todavia se tira o se levanta y la juega al terminar.
func reaction_pending() -> bool:
	return _pending_react >= 0

func is_busy() -> bool:
	return state in [State.WAIT_DIVE, State.DIVE, State.GETUP, State.COLLECT]
