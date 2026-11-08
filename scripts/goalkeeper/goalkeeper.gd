class_name Goalkeeper
extends CharacterBody3D
## Arquero. Se posiciona sobre el arco mirando la pelota, anticipa los disparos con la trayectoria predicha, planifica
## la atajada con la trayectoria de manos medida de sus clips (KeeperPlanner) y la ejecuta con el clip y el
## desplazamiento de raiz reales: el contacto cuenta solo si las manos llegan a la pelota. Despues sostiene la pelota
## y la saca con la mano o con el pie (lanzamiento, pase rodado o patada de despeje).
##
## La pelota solo cambia por impulsos (rechazo / saque) o sostenida en el ancla de las manos (Ball.hold).

signal saved(kind: StringName)

enum State { POSITION, PREPARE, ACTION, HOLD, DISTRIBUTE, GOAL_KICK, TURNING }

## Segundos con la pelota parada en el area tras los que el arquero la recoge aunque haya rivales cerca.
const SCRUM_SECONDS := 1.2
## Segundos maximos que el arquero adelanta su reaccion al ver armar el disparo.
const KICK_READ_MAX := 0.22
## Segundos con el joystick quieto tras los que el arquero controlado por la persona vuelve a atajar por su cuenta.
const MANUAL_AUTO_SAVE_IDLE := 0.3
## Distancia (m) a la que el arquero controla con el pie un pase de un companero.
const FOOT_TRAP_RANGE := 0.75
## Segundos que espera con la pelota en los pies antes de jugarla (arquero de la IA).
const FOOT_PLAY_DELAY := 0.6
## Segundos maximos que el arquero controlado por la persona retiene la pelota antes de sacar solo.
const MANUAL_HOLD_MAX := 8.0
## Reposo con la pelota en las manos (clip con trayectoria de manos: la pelota va en sus manos de verdad).
const HOLD_IDLE_CLIP := &"goalkeeper_idle_2"
## Indicaciones al equipo cuando la jugada esta lejos: hacia el ataque (pelota en campo rival) o la defensa.
const DIRECT_ATTACK_CLIP := &"goalkeeper_directing"
const DIRECT_DEFENSE_CLIP := &"goalkeeper_directing_2"
const DIRECT_SECONDS := 2.2
const DIRECT_COOLDOWN := 11.0
## Estirada desesperada que no llega (salta hacia su derecha; el espejo, a la izquierda): cuando ningun clip de atajada
## alcanza la pelota.
const MISS_CLIP := &"goalkeeper_miss"
## Saque de arco: coloca la pelota en el suelo (corto o largo) y la juega con el pie.
const PLACE_CLIPS := [&"goalkeeper_placing_ball", &"goalkeeper_placing_ball_2"]
const PLACE_LONG_CUT := 4.2
## Achique en el mano a mano: distancia (m) al arco dentro de la cual sale a cerrar el angulo y a la que se queda del
## portador.
const RUSH_RANGE := 11.0
const RUSH_GAP := 2.6
const RUSH_MAX_OUT := 6.0
## Salida a por un centro: el punto de atrapada debe quedar a esta distancia maxima (m) de la linea de gol.
const CLAIM_MAX_DEPTH := 4.5

@export var team: int = 0
var actor_id: int = 0
var display_name: String = "Arquero"
var attributes: PlayerAttributes = PlayerAttributes.new()
var ctx: MatchContext = null
var visual: FootballerVisual = null
var state: State = State.POSITION
var yaw: float = 0.0
var rng := RandomNumberGenerator.new()
## Contadores y registro (diagnostico y pruebas).
var stats := {"shots_seen": 0, "shots_faced": 0, "catches": 0, "parries": 0, "beaten": 0, "dives": 0, "pickups": 0, "distributions": 0}
var _last_shot_notice: Vector2i = Vector2i(-1, -1)
var save_log: Array[Dictionary] = []

var _tune: KeeperTuning = null
var _motion := ActionMotion.new()
var _plan: Dictionary = {}
var _state_time: float = 0.0
var _threat_since: float = -1.0
## Disparo que se esta leyendo: instante en que se vio salir (s de _clock) y error de percepcion (unidades normales: guinada,
## cabeceo) que se escala con lo que lleva mirandolo (_perceived).
var _shot_seen_at: float = -1.0
var _perc_noise: Vector2 = Vector2.ZERO
## Punto donde la pelota lenta cruzara la linea del arquero: con tiempo de sobra se desplaza hasta alli en vez de comprometerse
## con una estirada (INF = ninguno).
var _intercept: Vector3 = Vector3.INF
## Proximo instante (reloj del arquero) en que puede volver a planificar una atajada mientras lee el disparo: planificar
## cuesta (KeeperPlanner recorre cientos de clips) y reintentarlo en cada paso daba tirones de mas de 100 ms.
var _next_plan_at: float = -1.0
## Segundos entre intentos de planificacion mientras no hay plan (el mismo ritmo que la replanificacion: 0.08 s).
const PLAN_RETRY := 0.08
## Segundos hasta el cruce por encima de los cuales una estirada no se decide todavia: primero se coloca en la linea de la pelota.
const LATE_COMMIT := 0.7
## Solo los disparos lentos (m/s): a uno fuerte no se llega desplazandose, se ataja con lo que se tenga.
const SLOW_SHOT_SPEED := 14.0
## Distancia lateral (m) del cruce estimado a su cuerpo por debajo de la cual no se lanza mientras lee el disparo.
const CENTER_HOLD := 0.7
## Por encima de esta altura (m) la pelota pasa sobre el cuerpo: hay que saltar a tiempo, no esperar.
const CENTER_HOLD_MAX_Y := 1.3
## Segundos que deben quedar hasta que la pelota llegue, una vez terminada la lectura, para quedarse firme esperando.
const CENTER_HOLD_TIME := 0.4
var _evaluated: bool = false
## Contacto continuo de la atajada: manos y pelota del paso anterior y la menor distancia entre sus recorridos en la ventana.
var _prev_hands := Vector3.INF
var _prev_ball := Vector3.INF
var _eval_min: float = INF
## Medio ancho (s de clip) de la ventana alrededor del contacto planeado en la que se busca el contacto real: a 19 m/s la
## pelota avanza 0.32 m por paso, asi que medir en un solo instante fallaba por un paso de desfase.
const CONTACT_WINDOW := 0.05
var _anchor: Node3D = null
var _capsule: CollisionShape3D = null
var _hold_left: float = 0.0
var _dist: Dictionary = {}
var _released: bool = false
var _dropped: bool = false
var _kick_done: bool = false
var _clock: float = 0.0
var _rest_clip_played: bool = false
var _idle_time: float = 0.0
var _plan_clock: float = 0.0
var _replan_cd: float = 0.0
## Segundos seguidos que la pelota lleva casi parada (para resolver un barullo en el area).
var _ball_still: float = 0.0
var _kick_seen_since: float = -1.0
## Entrada de la persona (null = decide la IA). Un arquero controlado obedece el joystick: no se lanza por su cuenta
## mientras la persona lo esta moviendo, y usa los botones para atrapar, despejar y sacar.
var input_source: InputSource = null
var is_human_controlled: bool = false
var _stick: Vector3 = Vector3.ZERO
var _stick_mag: float = 0.0
var _stick_idle: float = 10.0
var _button_cd: float = 0.0
## Segundos que la pelota lleva controlada con el pie tras un pase del propio equipo (0 = no la tiene en los pies).
var _foot_ball: float = 0.0
## Saque de arco en curso: etapa ("place", "wait", "kick") y si ya se jugo la pelota (lo lee MatchManager).
var goal_kick_done: bool = false
var _gk_stage: StringName = &""
var _gk_clip: StringName = &""
var _gk_place_t: float = 0.0
var _gk_long: bool = false
var _direct_cd: float = 4.0
var _hold_clip_time: float = 0.0
## Mano a mano: true mientras sale a cerrar el angulo a un portador solo.
var rushing: bool = false

func _ready() -> void:
	add_to_group("keepers")
	rng.randomize()
	_tune = Tuning.keeper
	collision_layer = Ball.LAYER_KEEPERS
	collision_mask = Ball.LAYER_WORLD | Ball.LAYER_PLAYERS
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_capsule = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	_capsule.shape = cap
	_capsule.position = Vector3(0.0, 0.875, 0.0)
	add_child(_capsule)
	_anchor = Node3D.new()
	_anchor.name = "HandsAnchor"
	add_child(_anchor)
	_anchor.position = Vector3(0.0, _tune.carry_height, 0.0)
	visual = FootballerVisual.new()
	visual.name = "Visual"
	visual.keeper_mode = true
	add_child(visual)
	visual.build(FootballerVisual.keeper_kit())

## Configura el arquero dentro de un partido y lo coloca en su arco.
func setup(context: MatchContext, team_index: int, id: int, attrs: PlayerAttributes) -> void:
	ctx = context
	team = team_index
	actor_id = id
	attributes = attrs
	ctx.register_keeper(self)
	if not ctx.event_emitted.is_connected(_on_match_event):
		ctx.event_emitted.connect(_on_match_event)
	reset_position()

func _exit_tree() -> void:
	if ctx != null:
		ctx.unregister_keeper(self)
		if ctx.event_emitted.is_connected(_on_match_event):
			ctx.event_emitted.disconnect(_on_match_event)

# --- Geometria del arco ------------------------------------------------------------------------

func goal_side() -> int:
	return -1 if team == 0 else 1

func goal_x() -> float:
	return float(goal_side()) * ctx.pitch.config.half_length()

func inward() -> Vector3:
	return Vector3(-float(goal_side()), 0.0, 0.0)

func forward() -> Vector3:
	return Locomotion.dir_from_yaw(yaw)

func right_vec() -> Vector3:
	var f: Vector3 = forward()
	return Vector3(-f.z, 0.0, f.x)

func reset_position() -> void:
	_cancel_action(true)
	_gk_stage = &""
	rushing = false
	state = State.POSITION
	yaw = Locomotion.yaw_from_dir(inward())
	rotation.y = yaw
	global_position = Vector3(goal_x(), 0.0, 0.0) + inward() * _tune.base_depth
	velocity = Vector3.ZERO

func _norm(key: String) -> float:
	return attributes.norm(key)

# --- Bucle ---------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	Prof.begin(&"arqueros")
	_keeper_step(delta)
	Prof.end(&"arqueros")

func _keeper_step(delta: float) -> void:
	if ctx == null or ctx.ball == null or ctx.pitch == null:
		return
	_clock += delta
	_state_time += delta
	_button_cd = maxf(_button_cd - delta, 0.0)
	_read_input(delta)
	_watch_kickers()
	if ctx.ball.linear_velocity.length() < 0.6 and not ctx.ball.is_held():
		_ball_still += delta
	else:
		_ball_still = 0.0
	if _foot_ball > 0.0:
		_foot_ball += delta
		if ctx.ball.is_held() or KickModel.flat(ctx.ball.global_position - global_position).length() > 1.6:
			_foot_ball = 0.0
	match state:
		State.POSITION:
			_tick_position(delta)
		State.PREPARE:
			_tick_prepare(delta)
		State.ACTION:
			_tick_action(delta)
		State.HOLD:
			_tick_hold(delta)
		State.DISTRIBUTE:
			_tick_distribute(delta)
		State.GOAL_KICK:
			_tick_goal_kick(delta)
		State.TURNING:
			_tick_turn(delta)
	_direct_cd = maxf(_direct_cd - delta, 0.0)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 9.81 * delta
	move_and_slide()
	rotation.y = yaw
	var f: Vector3 = forward()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	visual.directional = state == State.POSITION or state == State.PREPARE or state == State.HOLD or (state == State.GOAL_KICK and _gk_stage == &"wait")
	visual.dir_velocity = Vector2(flat.dot(f), flat.dot(right_vec()))
	visual.drive_motion(flat.length(), 0.0, delta)

# --- Posicionamiento y deteccion de disparos ------------------------------------------------------

func _tick_position(delta: float, preparing: bool = false) -> void:
	var ball: Ball = ctx.ball
	if not preparing:
		_assess_shot()
		if state != State.POSITION:
			return
		if is_human_controlled:
			_tick_manual(delta)
			return
		if _receive_backpass(delta):
			return
		if _try_pickup():
			return
		if _try_smother():
			return
		if _assess_cross():
			return
		if _try_turn():
			return
		_maybe_direct_team()
	# Objetivo: sobre el arco, en la linea arco-pelota, mas adelantado cuanto mas cerca esta el peligro.
	var g := Vector3(goal_x(), 0.0, 0.0)
	var b := Vector3(ball.global_position.x, 0.0, ball.global_position.z)
	var to_ball: Vector3 = b - g
	var d: float = to_ball.length()
	var dir: Vector3 = to_ball / d if d > 0.1 else inward()
	var pos_k: float = lerpf(0.85, 1.2, _norm("positioning"))
	var depth: float = lerpf(_tune.base_depth, _tune.max_depth, clampf((14.0 - d) / 14.0, 0.0, 1.0)) * pos_k
	depth = clampf(depth, 0.4, _tune.max_depth)
	# Achique: un rival se va solo hacia el arco -> sale a cerrarle el angulo, quedandose a RUSH_GAP de la pelota.
	rushing = false
	var lone: Footballer = _lone_attacker()
	if lone != null and not preparing:
		rushing = true
		depth = clampf(d - RUSH_GAP * lerpf(1.15, 0.85, _norm("positioning")), depth, RUSH_MAX_OUT)
	# Centro en el aire hacia su area: va al punto donde la pelota bajara a altura de manos (para poder atraparla).
	var landing: Vector3 = _cross_landing()
	if landing != Vector3.INF and not preparing:
		var to_land: Vector3 = landing - g
		dir = to_land.normalized() if to_land.length() > 0.1 else dir
		depth = clampf(to_land.length(), 0.4, CLAIM_MAX_DEPTH)
	# Penal: en la linea hasta el disparo.
	if ctx.dead_ball and ctx.restart_taker != null and ctx.restart_taker.get("team") != team and d < ctx.pitch.config.penalty_mark_distance + 0.5:
		depth = 0.15
	var target: Vector3 = g + dir * depth
	# Disparo lento leido: a la linea de la pelota (mientras dura la amenaza).
	if _intercept != Vector3.INF and _threat_since >= 0.0 and not preparing:
		target = Vector3(global_position.x, 0.0, _intercept.z)
	elif _threat_since < 0.0:
		_intercept = Vector3.INF
	var hz: float = ctx.pitch.config.half_goal() + 0.9
	target.z = clampf(target.z, -hz, hz)
	var to_t: Vector3 = target - global_position
	to_t.y = 0.0
	var speed_cap: float = _tune.move_speed * lerpf(0.9, 1.15, _norm("reflexes")) * (1.35 if rushing else 1.0)
	var want: Vector3 = to_t.normalized() * minf(to_t.length() * 5.0, speed_cap) if to_t.length() > 0.06 else Vector3.ZERO
	var cur := Vector3(velocity.x, 0.0, velocity.z)
	cur = cur.move_toward(want, _tune.accel * delta)
	velocity.x = cur.x
	velocity.z = cur.z
	# Mira la pelota (o hacia el campo si la tiene).
	var face: Vector3 = (b - global_position)
	face.y = 0.0
	if state == State.HOLD or face.length() < 0.3:
		face = inward()
	var dy: float = wrapf(Locomotion.yaw_from_dir(face.normalized()) - yaw, -PI, PI)
	yaw = wrapf(yaw + clampf(dy, -deg_to_rad(420.0) * delta, deg_to_rad(420.0) * delta), -PI, PI)

## Anota desde cuando un rival cercano a la pelota esta armando una patada hacia su arco (para adelantar la reaccion).
func _watch_kickers() -> void:
	var seen: bool = false
	var bp: Vector3 = ctx.ball.global_position
	if absf(bp.x - goal_x()) < 16.0:
		for f in ctx.footballers:
			if f.team != team and f.ball_handler.is_kick_in_progress() and Vector2(f.global_position.x - bp.x, f.global_position.z - bp.z).length() < 1.5:
				seen = true
				break
	if seen:
		if _kick_seen_since < 0.0:
			_kick_seen_since = _clock
	elif _kick_seen_since >= 0.0 and ctx.ball.linear_velocity.length() < _tune.shot_min_speed:
		_kick_seen_since = -1.0

## Revisa si hay un disparo a puerta; si lo hay, tras el tiempo de reaccion planifica y empieza la atajada.
func _assess_shot() -> void:
	var ball: Ball = ctx.ball
	if ball.is_held():
		_threat_since = -1.0
		return
	var v: Vector3 = ball.linear_velocity
	var side: float = float(goal_side())
	if v.length() < _tune.shot_min_speed or v.x * side < 1.0:
		_threat_since = -1.0
		return
	# Un pase de un companero NO es un disparo: se recibe, no se ataja. Solo si viene muy fuerte (rebote, despeje
	# desviado) se trata como peligro.
	if ball.last_touch_team == team and v.length() < _tune.backpass_speed_max:
		_threat_since = -1.0
		return
	# Con la persona moviendo el joystick el arquero no se lanza solo: manda el mando.
	if is_human_controlled and _stick_idle < MANUAL_AUTO_SAVE_IDLE:
		_threat_since = -1.0
		return
	var traj: PackedVector3Array = BallPredictor.trajectory(ball.global_position, v, _tune.plan_horizon, 1.0 / 30.0, _perceived_spin())
	var ci: int = BallPredictor.crossing_x(traj, goal_x(), side)
	if ci < 0:
		_threat_since = -1.0
		return
	var cp: Vector3 = traj[ci]
	var cfg: PitchConfig = ctx.pitch.config
	if absf(cp.z) > cfg.half_goal() + 0.35 or cp.y > cfg.goal_height + 0.35:
		_threat_since = -1.0
		return
	if _threat_since < 0.0:
		# Lee el cuerpo del rival: si ya estaba armando el disparo, la reaccion arranco antes de que saliera la pelota.
		var lead: float = 0.0
		if _kick_seen_since >= 0.0:
			lead = clampf(_clock - _kick_seen_since, 0.0, KICK_READ_MAX) * lerpf(0.5, 1.0, _norm("reflexes"))
		_threat_since = _clock - lead
		stats["shots_faced"] += 1
		_shot_seen_at = _clock
		_perc_noise = Vector2(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0))
	var dist_shot: float = absf(ball.global_position.x - goal_x())
	# Reaccion propia (calibrada con nuestro modelo de estirada). La de UCS (ResponseGKSave 15/4 cuadros, 0.25-0.07 s;
	# UcsParams.RESPONSE_GK_SAVE_S) sobre este modelo atajaba el 87-97 % de los tiros a 8-11 m y la prueba de tiros ya no
	# distinguia el tiro con un rival encima (test_shot_keeper, 2026-11-06): no se aplica.
	var react: float = maxf(0.05, _tune.reaction_time * lerpf(1.5, 0.65, _norm("reflexes")) - _tune.anticipation_gain * dist_shot / 10.0)
	if _clock - _threat_since < react:
		return
	# Planifica con lo que percibe del disparo (direccion con error que se reduce mientras lo mira), no con la exacta.
	traj = BallPredictor.trajectory(ball.global_position, _perceived(v), _tune.plan_horizon, 1.0 / 30.0, _perceived_spin())
	# Pelota que viene a su cuerpo y todavia no la termino de leer: se queda firme (lanzarse a un lado con una lectura
	# imprecisa le deja el hueco por donde entra).
	var kc: int = BallPredictor.crossing_x(traj, global_position.x, side)
	# Solo si al terminar de leerla le queda tiempo para bajar las manos (CENTER_HOLD_TIME s): si no, se juega ya.
	if _perception_uncertain() and kc >= 0 and absf(traj[kc].z - global_position.z) < CENTER_HOLD and traj[kc].y < CENTER_HOLD_MAX_Y \
			and float(kc) / 30.0 - (_tune.perception_time - (_clock - _shot_seen_at)) > CENTER_HOLD_TIME:
		return
	if _clock < _next_plan_at:
		return
	_next_plan_at = _clock + PLAN_RETRY
	var plan: Dictionary = _plan_after_reading(traj, v.length())
	if plan.is_empty() or float(plan["dist"]) > _tune.effort_radius:
		# Sin posibilidad de llegar con una atajada: si la pelota va a su derecha y hay tiempo, se estira igual
		# (estirada desesperada: el contacto se evalua con sus manos reales, casi nunca llega); si no, sigue mirando y el
		# cuerpo todavia puede tapar con la colision.
		var miss: Dictionary = _plan_miss(traj, ci)
		if not miss.is_empty():
			_plan = miss
			_plan["ball_speed"] = v.length()
			_plan["fixed"] = true
			_plan_clock = _clock
			_state_time = 0.0
			_threat_since = -1.0
			stats["desperate"] = int(stats.get("desperate", 0)) + 1
			state = State.PREPARE
			return
		# Todavia leyendo el disparo (su estimacion aun tiene error): sigue mirando y vuelve a intentarlo en el paso siguiente.
		if _perception_uncertain():
			return
		_log_save(&"no_chance", {"dist": plan.get("dist", -1.0), "speed": v.length()})
		_threat_since = _clock + 5.0
		return
	# Pelota lenta con tiempo de sobra y el plan seria estirarse: primero se desplaza a la linea de la pelota (desde ahi la
	# recogera de pie o con una atajada baja) y se vuelve a planificar en los pasos siguientes.
	var role: StringName = StringName(String(PackLibrary.meta(plan["clip"]).get("role", "")))
	var kx: int = BallPredictor.crossing_x(traj, global_position.x, side)
	if (role == &"gk_dive" or role == &"gk_sidestep") and kx >= 0 and float(plan["arrive"]) > LATE_COMMIT and v.length() < SLOW_SHOT_SPEED:
		_intercept = traj[kx]
		return
	_intercept = Vector3.INF
	_plan = plan
	_plan["ball_speed"] = v.length()
	_plan_clock = _clock
	_replan_cd = 0.1
	_state_time = 0.0
	state = State.PREPARE
	_threat_since = -1.0

## Velocidad del disparo tal como la percibe el arquero: la real girada por su error de percepcion, que se reduce a cero
## mientras sigue la pelota (perception_time s; mejores reflejos, menos error). No conoce el resultado del disparo de antemano.
func _perceived(v: Vector3) -> Vector3:
	if _shot_seen_at < 0.0:
		return v
	var watch: float = _clock - _shot_seen_at
	var flat_v: Vector3 = Vector3(v.x, 0.0, v.z)
	var sigma: float = _tune.perception_error_ratio * flat_v.length() * lerpf(1.4, 0.6, _norm("reflexes")) * clampf(1.0 - watch / maxf(_tune.perception_time, 0.05), 0.0, 1.0)
	if sigma <= 0.0 or flat_v.length() < 0.5:
		return v
	var side: Vector3 = Vector3(-flat_v.z, 0.0, flat_v.x).normalized()
	var out: Vector3 = v + side * (_perc_noise.x * sigma)
	# Una pelota que rueda se ve rodar: solo la que va por el aire tiene error en la altura.
	if ctx.ball.global_position.y > 0.25 or absf(v.y) > 1.0:
		out.y += _perc_noise.y * sigma * 0.6
	return out

## Plan de atajada que no se lanza antes de terminar de leer el disparo si hay tiempo (como un arquero que espera a ver la
## pelota antes de comprometerse); si asi no llega, el mejor que se pueda lanzar ya (jugarsela).
func _plan_after_reading(traj: PackedVector3Array, speed: float) -> Dictionary:
	var wait: float = maxf(_tune.perception_time - (_clock - _shot_seen_at), 0.0) if _shot_seen_at >= 0.0 else 0.0
	if wait > 0.0:
		var patient: Dictionary = KeeperPlanner.plan_save(_origin_after_stop(), yaw, traj, 1.0 / 30.0, wait, speed, false, _clip_speeds(), _hand_limits())
		if not patient.is_empty() and float(patient["dist"]) <= float(patient["radius"]) * 0.85:
			return patient
	return KeeperPlanner.plan_save(_origin_after_stop(), yaw, traj, 1.0 / 30.0, 0.0, speed, false, _clip_speeds(), _hand_limits())

## Velocidades a las que puede reproducir sus clips de atajada: la natural de la captura y un margen de explosividad que
## crece con los reflejos (KeeperTuning.dive_speed_max con reflejos 50). Mas rapido que eso no lo hace un humano.
## Limite humano de las manos (KeeperPlanner.plan_save): latencia y velocidad media de las manos hacia el punto de la
## atajada (KeeperTuning.hand_latency / hand_speed con reflejos 50; mejores reflejos, mas rapido).
func _hand_limits() -> Vector2:
	return Vector2(_tune.hand_latency * lerpf(1.2, 0.8, _norm("reflexes")), _tune.hand_speed * lerpf(0.88, 1.12, _norm("reflexes")))

func _clip_speeds() -> Array:
	return [1.0, maxf(1.0, _tune.dive_speed_max * lerpf(0.94, 1.06, _norm("reflexes")))]

## Efecto de la pelota tal como lo percibe el arquero: la curva no se ve al salir el disparo, se lee mientras la pelota se
## desvia (spin_read_time s desde el ultimo toque; mejores reflejos, antes). Al principio preve una trayectoria casi recta
## y la corrige al replanificar (el tiro que se cierra o se abre le gana si la lectura llega tarde).
func _perceived_spin() -> Vector3:
	var ball: Ball = ctx.ball
	var watch: float = float(Engine.get_physics_frames() - ball.last_touch_frame) / float(Engine.physics_ticks_per_second)
	var read: float = _tune.spin_read_time * lerpf(1.4, 0.6, _norm("reflexes"))
	return ball.angular_velocity * clampf(watch / maxf(read, 0.05), 0.0, 1.0)

## El arquero todavia no termino de leer el disparo (su estimacion de la direccion aun tiene error).
func _perception_uncertain() -> bool:
	return _shot_seen_at >= 0.0 and _clock - _shot_seen_at < _tune.perception_time

## Donde quedara el arquero si frena desde ahora (los planes se hacen desde ese punto: en la preparacion se planta).
func _origin_after_stop() -> Vector3:
	var v := Vector3(velocity.x, 0.0, velocity.z)
	var a: float = _tune.accel * 1.5
	return global_position + v * (v.length() / (2.0 * a))

## Preparacion: sigue replanificando (posicion y trayectoria actuales) y se planta justo antes de lanzarse.
func _tick_prepare(delta: float) -> void:
	var remaining: float = float(_plan["delay"]) - (_clock - _plan_clock)
	# Se planta desde el primer instante: los planes asumen el punto donde queda parado.
	var cur := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, _tune.accel * 1.5 * delta)
	if _plan.get("claim", false) and remaining > 0.02:
		# Salida a un centro: pasos de ajuste para que las manos del clip lleguen a la pelota (como el ajuste de
		# zancada del golpeo): error entre las manos previstas y la pelota en el contacto, repartido en lo que falta.
		var ball: Ball = ctx.ball
		var ct: PackedVector3Array = BallPredictor.trajectory(ball.global_position, ball.linear_velocity, 1.4, 1.0 / 30.0, _perceived_spin())
		var ia: int = clampi(int(round((float(_plan["arrive"]) - (_clock - _plan_clock)) * 30.0)), 0, ct.size() - 1)
		var hands: Vector3 = KeeperPlanner.path_world(_plan["clip"], "hands", int(_plan["k"]), global_position, yaw)
		var err := Vector3(ct[ia].x - hands.x, 0.0, ct[ia].z - hands.z)
		cur = (err / maxf(remaining, 0.12)).limit_length(_tune.move_speed)
	velocity.x = cur.x
	velocity.z = cur.z
	if remaining > 0.08:
		_replan_cd -= delta
		if _replan_cd <= 0.0:
			_replan_cd = 0.08
			_replan()
		return
	if remaining <= 0.0:
		_begin_action()

func _replan() -> void:
	var ball: Ball = ctx.ball
	if ball.is_held():
		state = State.POSITION
		return
	if _plan.get("claim", false):
		# Salida a un centro: se ajusta el plan con la trayectoria actual (sin las condiciones de disparo a puerta).
		var ct: PackedVector3Array = BallPredictor.trajectory(ball.global_position, ball.linear_velocity, 1.4, 1.0 / 30.0, _perceived_spin())
		var cp: Dictionary = KeeperPlanner.plan_save(_origin_after_stop(), yaw, ct, 1.0 / 30.0, 0.0, ball.linear_velocity.length(), false, _clip_speeds(), _hand_limits())
		if not cp.is_empty() and float(cp["dist"]) <= float(_plan["dist"]) + 0.05:
			cp["claim"] = true
			cp["ball_speed"] = ball.linear_velocity.length()
			_plan = cp
			_plan_clock = _clock
		return
	if _plan.get("fixed", false):
		return
	var v: Vector3 = ball.linear_velocity
	# La amenaza cambio (desvio, bloqueo de un rival, pelota lenta): se cancela y vuelve a posicionarse.
	if v.length() < _tune.shot_min_speed * 0.6 or v.x * float(goal_side()) < 0.5:
		state = State.POSITION
		return
	var traj: PackedVector3Array = BallPredictor.trajectory(ball.global_position, _perceived(v), _tune.plan_horizon, 1.0 / 30.0, _perceived_spin())
	var plan: Dictionary = _plan_after_reading(traj, v.length())
	if plan.is_empty() or float(plan["dist"]) > _tune.effort_radius:
		# Con la estimacion todavia imprecisa mantiene el plan que tenia; ya asentada, si no llega, vuelve a colocarse.
		if not _perception_uncertain():
			state = State.POSITION
		return
	plan["ball_speed"] = v.length()
	_plan = plan
	_plan_clock = _clock

## Pelota suelta y lenta dentro de su area sin rival cerca: sale a recogerla con una atajada baja o la recogida.
func _try_pickup() -> bool:
	var ball: Ball = ctx.ball
	if ctx.ball_locked_for(self):
		return false
	if ball.is_held() or ball.global_position.y > 0.5 or ball.linear_velocity.length() > _tune.pickup_ball_speed_max:
		return false
	if _foot_ball > 0.0:
		return false   # la cedida se juega con el pie, no se recoge con la mano
	var cfg: PitchConfig = ctx.pitch.config
	var bp: Vector3 = ball.global_position
	if (bp.x - goal_x()) * float(goal_side()) > -0.15:
		return false   # la pelota ya esta en la linea o dentro de la red
	if absf(bp.x - goal_x()) > cfg.penalty_area_radius + 1.0 or absf(bp.z) > cfg.half_goal() + cfg.penalty_area_radius:
		return false
	if Vector2(bp.x - global_position.x, bp.z - global_position.z).length() > _tune.pickup_distance:
		return false
	# Con rivales encima no sale a recoger... salvo que la pelota lleve un rato parada en el area (barullo): la saca el arquero.
	var scrum: bool = _ball_still >= SCRUM_SECONDS
	if not scrum:
		for f in ctx.footballers:
			if f.team != team and Vector2(f.global_position.x - bp.x, f.global_position.z - bp.z).length() < _tune.pickup_opponent_clearance:
				return false
	var traj := PackedVector3Array([bp, bp, bp, bp])
	var plan: Dictionary = KeeperPlanner.plan_save(global_position, yaw, traj, 0.5, 0.0, 0.0, true, [1.0])
	if plan.is_empty() or float(plan["dist"]) > 0.5:
		return false
	_plan = plan
	_plan["pickup"] = true
	_plan["delay"] = 0.0
	_state_time = 0.0
	_begin_action()
	return true

# --- Control de la persona y cedidas -------------------------------------------------------------

## Lee la entrada de la persona (si este arquero es el que maneja) y actualiza el tiempo con el joystick quieto.
func _read_input(delta: float) -> void:
	if not is_human_controlled or input_source == null or not ctx.input_enabled:
		_stick = Vector3.ZERO
		_stick_mag = 0.0
		_stick_idle = 10.0
		return
	var frame: InputFrame = input_source.poll(null)
	_stick_mag = clampf(frame.move_length(), 0.0, 1.0)
	var w: Vector3 = frame.move_world if frame.use_world else ctx.screen_to_world(frame.move)
	_stick = w.normalized() if _stick_mag > 0.05 else Vector3.ZERO
	_stick_idle = 0.0 if _stick_mag > 0.2 else _stick_idle + delta
	if _button_cd <= 0.0 and (frame.pass_pressed or frame.shoot_pressed):
		_button_cd = 0.2
		_manual_action(frame.shoot_pressed)

## Boton con el arquero controlado: con la pelota en las manos saca (PASE = corto, TIRO = largo); con la pelota
## suelta a su alcance la atrapa si viene suave y la despeja si no.
func _manual_action(long: bool) -> void:
	var ball: Ball = ctx.ball
	if state == State.GOAL_KICK:
		if _gk_stage == &"wait":
			_start_goal_kick_strike(long)
		return
	if ball.holder == self:
		_begin_distribution(&"throw" if not long else &"kick")
		return
	if state != State.POSITION:
		return
	var off: Vector3 = KickModel.flat(ball.global_position - global_position)
	if off.length() > _tune.reach + 0.35 or ball.global_position.y > 1.6:
		return
	if ball.linear_velocity.length() <= _tune.pickup_ball_speed_max * 1.6 and ball.global_position.y < 1.2:
		_catch_in_place()
	else:
		_clear_ball(off)

## Atrapa la pelota donde esta (boton del arquero controlado): pasa a sostenerla y esperar orden de saque.
func _catch_in_place() -> void:
	var ball: Ball = ctx.ball
	ball.hold(_anchor, self)
	stats["catches"] += 1
	_foot_ball = 0.0
	ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_CATCH, actor_id, team, {"manual": true}))
	_enter_hold()

## Despeje de emergencia con el pie hacia donde mira el arquero (o hacia el campo si no hay direccion).
func _clear_ball(off: Vector3) -> void:
	var ball: Ball = ctx.ball
	var dir: Vector3 = _stick if _stick.length_squared() > 0.01 else inward()
	var v: Vector3 = dir.normalized() * _tune.clearance_speed + Vector3.UP * 3.0
	ball.kick(v, Vector3.ZERO, self)
	_foot_ball = 0.0
	stats["distributions"] += 1
	ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_DISTRIBUTE, actor_id, team, {"mode": "clear", "manual": true}))

## Movimiento del arquero que maneja la persona: va a donde apunta el joystick, mirando siempre a la pelota.
func _tick_manual(delta: float) -> void:
	var ball: Ball = ctx.ball
	var want: Vector3 = _stick * (_tune.manual_speed * _stick_mag)
	var cur := Vector3(velocity.x, 0.0, velocity.z)
	cur = cur.move_toward(want, _tune.accel * delta)
	velocity.x = cur.x
	velocity.z = cur.z
	# Con la pelota suelta al alcance del pie, la controla (no se la queda bajo los pies sin tocarla).
	if _foot_ball <= 0.0 and not ball.is_held() and ball.global_position.y < 0.6:
		var off: Vector3 = KickModel.flat(ball.global_position - global_position)
		if off.length() < FOOT_TRAP_RANGE and ball.linear_velocity.length() < _tune.backpass_speed_max:
			_foot_trap(off)
	_face_ball(delta)

## Orienta el cuerpo hacia la pelota (o hacia el campo si la tiene encima).
func _face_ball(delta: float) -> void:
	var face: Vector3 = KickModel.flat(ctx.ball.global_position - global_position)
	if face.length() < 0.3:
		face = inward()
	var dy: float = wrapf(Locomotion.yaw_from_dir(face.normalized()) - yaw, -PI, PI)
	yaw = wrapf(yaw + clampf(dy, -deg_to_rad(420.0) * delta, deg_to_rad(420.0) * delta), -PI, PI)

## Cedida de un companero: el arquero sale a su encuentro y la para con el pie en vez de lanzarse. Devuelve true
## si esta ocupandose de ella (entonces no hace nada mas en este paso).
func _receive_backpass(delta: float) -> bool:
	var ball: Ball = ctx.ball
	if ctx.ball_locked_for(self):
		return false
	if ball.is_held() or ball.last_touch_team != team or ball.global_position.y > 0.6:
		return false
	var v: Vector3 = KickModel.flat(ball.linear_velocity)
	var off: Vector3 = KickModel.flat(ball.global_position - global_position)
	if _foot_ball > 0.0:
		# Ya la tiene en los pies: la juega con el pie tras una pausa corta.
		velocity.x = 0.0
		velocity.z = 0.0
		_face_ball(delta)
		if _foot_ball >= FOOT_PLAY_DELAY:
			_begin_distribution(&"foot")
		return true
	if v.length() > _tune.backpass_speed_max or off.length() > _tune.pickup_distance * 1.6:
		return false
	# Solo si viene hacia el (si no, es una jugada del equipo, no una cedida).
	if v.length() > 0.6 and v.normalized().dot(off.normalized() * -1.0) < 0.4:
		return false
	if off.length() <= FOOT_TRAP_RANGE:
		_foot_trap(off)
		return true
	var want: Vector3 = off.normalized() * minf(off.length() * 3.0, _tune.move_speed)
	var cur := Vector3(velocity.x, 0.0, velocity.z)
	cur = cur.move_toward(want, _tune.accel * delta)
	velocity.x = cur.x
	velocity.z = cur.z
	_face_ball(delta)
	return true

## Para la pelota con el pie: amortigua su velocidad y la deja junto al arquero.
func _foot_trap(off: Vector3) -> void:
	var ball: Ball = ctx.ball
	var place: Vector3 = global_position + (off.normalized() if off.length() > 0.1 else forward()) * 0.42
	var v: Vector3 = KickModel.flat(place - ball.global_position) * 1.6
	ball.kick(v, ball.rolling_spin(v), self)
	_foot_ball = 0.0001
	ctx.emit_event(GameEvent.make(GameEvent.Type.FIRST_TOUCH, actor_id, team, {"keeper": true}))

# --- Atajada ---------------------------------------------------------------------------------------

func _begin_action() -> void:
	state = State.ACTION
	_state_time = 0.0
	_evaluated = false
	_prev_hands = Vector3.INF
	_prev_ball = Vector3.INF
	_eval_min = INF
	var clip: StringName = _plan["clip"]
	if AnimTrace.enabled:
		var dec: Dictionary = AnimTrace.begin(self, &"keeper_save", &"KeeperPlanner.plan_save", "recogida" if _plan.get("pickup", false) else "atajada")
		for id in KeeperPlanner.trace_reasons:
			var why: String = String(KeeperPlanner.trace_reasons[id])
			AnimTrace.cand(dec, id, "" if why == "evaluado" else why)
		AnimTrace.commit(dec, clip, {"frame_contact": int(round(float(_plan.get("tau", 0.0)) * AnimTrace.FRAME_RATE)), "body_part": "hands",
			"spatial_error_m": float(_plan.get("dist", -1.0)), "tolerance_applied": float(_plan.get("radius", 0.0)),
			"tolerance_reason": "radio de manos del rol (KeeperPlanner.JSON_ROLE_RADIUS)"}, "accepted")
	visual.play_pack_clip(clip, float(_plan["speed"]))
	_motion.start(clip, float(_plan["speed"]))
	_set_lying(true)
	if not _plan.get("pickup", false):
		stats["dives"] += 1

func _tick_action(delta: float) -> void:
	var rv: Vector2 = _motion.step(delta)
	var f: Vector3 = forward()
	var r: Vector3 = right_vec()
	var wv: Vector3 = f * rv.x + r * rv.y
	velocity.x = wv.x
	velocity.z = wv.z
	var k: int = int(_motion.t * 30.0)
	if ctx.ball.holder == self:
		_anchor.global_position = KeeperPlanner.path_world_at_body(_plan["clip"], "hands", k, global_position, yaw)
	if not _evaluated:
		var hands_now: Vector3 = KeeperPlanner.path_world_at_body(_plan["clip"], "hands", k, global_position, yaw)
		var ball_now: Vector3 = ctx.ball.global_position
		var tau: float = float(_plan["tau"])
		if _motion.t >= tau - CONTACT_WINDOW:
			# Distancia minima entre el recorrido de las manos y el de la pelota en este paso (contacto continuo).
			var d: float = hands_now.distance_to(ball_now)
			if _prev_hands.x < INF:
				var cp: PackedVector3Array = Geometry3D.get_closest_points_between_segments(_prev_hands, hands_now, _prev_ball, ball_now)
				d = minf(d, cp[0].distance_to(cp[1]))
			_eval_min = minf(_eval_min, d)
			if _eval_min <= _contact_radius() or _motion.t >= tau + CONTACT_WINDOW or not _motion.active:
				_evaluated = true
				_evaluate_contact(k, _eval_min)
		_prev_hands = hands_now
		_prev_ball = ball_now
	if not _motion.active:
		# Modo 4: si la estirada lo dejo en el suelo, se levanta con un clip que empieza en esa postura (con la pelota en
		# las manos si la atrapo).
		if PackLibrary.json_mode() and not _plan.get("getup", false) and _json_getup():
			return
		_set_lying(false)
		if ctx.ball.holder == self:
			_enter_hold()
		else:
			state = State.POSITION
			_state_time = 0.0
			velocity = Vector3.ZERO

## Radio de contacto de las manos del plan vigente (segun la habilidad de atrapar).
func _contact_radius() -> float:
	return float(_plan["radius"]) * lerpf(0.8, 1.25, _norm("catching"))

## Resuelve la atajada con la distancia d (la menor entre los recorridos de manos y pelota en la ventana del contacto).
func _evaluate_contact(k: int, d: float) -> void:
	var ball: Ball = ctx.ball
	var clip: StringName = _plan["clip"]
	var hands: Vector3 = KeeperPlanner.path_world_at_body(clip, "hands", k, global_position, yaw)
	var speed: float = ball.linear_velocity.length()
	var radius: float = _contact_radius()
	var info := {"clip": String(clip), "dist": d, "speed": speed, "radius": radius, "pickup": _plan.get("pickup", false),
		"plan_dist": float(_plan.get("dist", -1.0)), "clip_speed": float(_plan.get("speed", 1.0)), "late": (_clock - _plan_clock) - float(_plan.get("arrive", 0.0)),
		"off": ball.global_position - hands}
	if AnimTrace.enabled:
		var ok: bool = not ball.is_held() and d <= radius
		AnimTrace.event(self, &"keeper_save", &"Goalkeeper._evaluate_contact", clip, "completed" if ok else "contact_failed",
			"" if ok else "manos a %.2f m de la pelota (radio %.2f m)" % [d, radius],
			{"frame_contact": k, "body_part": "hands", "ball_pred_x": ball.global_position.x, "ball_pred_y": ball.global_position.y,
			"ball_pred_z": ball.global_position.z, "contact_point_x": hands.x, "contact_point_y": hands.y, "contact_point_z": hands.z,
			"spatial_error_m": d, "tolerance_applied": radius, "tolerance_reason": "radio de manos (_contact_radius)",
			"contact_validated": ok, "physics_applied": ok})
	if ball.is_held() or d > radius:
		stats["beaten"] += 1
		_log_save(&"beaten", info)
		return
	var is_dive: bool = String(clip).contains("diving") or String(clip).contains("sidestep") or String(clip).contains("gk_dive")
	var catch_limit: float = _tune.catch_speed_max * attributes.factor("catching", 0.4) * (_tune.dive_catch_factor if is_dive else 1.0)
	if _plan.get("pickup", false) or speed <= catch_limit:
		ball.hold(_anchor, self)
		_anchor.global_position = hands
		stats["catches"] += 1
		if _plan.get("pickup", false):
			stats["pickups"] += 1
		_log_save(&"catch", info)
		saved.emit(&"catch")
		ctx.emit_event(GameEvent.make(GameEvent.Type.SAVE, actor_id, team, {"kind": "catch", "speed": speed, "clip": String(clip)}))
		ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_CATCH, actor_id, team, {"speed": speed}))
	elif speed <= _tune.parry_speed_max * attributes.factor("diving", 0.25):
		var lat: float = signf(ball.global_position.z - global_position.z)
		if lat == 0.0:
			lat = 1.0 if rng.randf() < 0.5 else -1.0
		var out_dir: Vector3 = (inward() * 0.6 + Vector3(0.0, 0.0, lat) * 0.8 + Vector3.UP * 0.25).normalized()
		var damp: float = _tune.deflect_damping * lerpf(1.3, 0.8, _norm("rebound_control"))
		var nv: Vector3 = out_dir * maxf(speed * damp, 3.5)
		ball.kick(nv, ball.rolling_spin(nv) * 0.3, self)
		stats["parries"] += 1
		_log_save(&"parry", info)
		saved.emit(&"parry")
		ctx.emit_event(GameEvent.make(GameEvent.Type.SAVE, actor_id, team, {"kind": "parry", "speed": speed, "clip": String(clip)}))
	else:
		stats["beaten"] += 1
		_log_save(&"too_hard", info)

func _log_save(result: StringName, info: Dictionary) -> void:
	var e := {"result": result, "time": _clock}
	e.merge(info)
	save_log.append(e)
	if save_log.size() > 64:
		save_log.pop_front()

func _set_lying(on: bool) -> void:
	var cap: CapsuleShape3D = _capsule.shape as CapsuleShape3D
	cap.height = 0.6 if on else 1.75
	_capsule.position.y = 0.3 if on else 0.875

func _cancel_action(release_ball: bool) -> void:
	_motion.stop()
	if visual != null:
		visual.stop_current_action()
	if _capsule != null:
		_set_lying(false)
	if release_ball and ctx != null and ctx.ball != null and ctx.ball.holder == self:
		ctx.ball.release(self, Vector3.ZERO)

# --- Sostener y sacar ----------------------------------------------------------------------------------

func _enter_hold() -> void:
	state = State.HOLD
	_state_time = 0.0
	_hold_clip_time = 0.0
	if visual != null and visual.uses_pack and PackLibrary.has_clip(HOLD_IDLE_CLIP):
		visual.play_pack_clip(HOLD_IDLE_CLIP, 1.0, 0.0, 30.0)
	_hold_left = lerpf(_tune.hold_time_max, _tune.hold_time_min, _norm("reflexes") * 0.5 + _norm("throwing") * 0.5) * rng.randf_range(0.9, 1.1)
	_anchor.position = Vector3(0.0, _tune.carry_height, -_tune.carry_forward)
	_anchor.position = Vector3(0.0, _tune.carry_height, 0.0)
	velocity = Vector3.ZERO

func _tick_hold(delta: float) -> void:
	var ball: Ball = ctx.ball
	if ball.holder != self:
		state = State.POSITION
		return
	# El ancla va en las manos del clip de reposo con pelota (si esta sonando) o delante del pecho.
	_hold_clip_time += delta
	if visual != null and visual.current_action == HOLD_IDLE_CLIP:
		var n: int = (PackLibrary.meta(HOLD_IDLE_CLIP).get("paths", {}).get("hands", PackedVector3Array()) as PackedVector3Array).size()
		var kk: int = int(_hold_clip_time * 30.0) % maxi(n, 1)
		_anchor.global_position = KeeperPlanner.path_world_at_body(HOLD_IDLE_CLIP, "hands", kk, global_position, yaw)
	else:
		_anchor.global_position = global_position + forward() * _tune.carry_forward + Vector3.UP * _tune.carry_height
	_tick_position(delta, true)
	if is_human_controlled:
		# Con el arquero en las manos de la persona, el saque lo ordena ella (hay un limite largo para que la
		# jugada no quede congelada si suelta el mando).
		if _state_time >= MANUAL_HOLD_MAX:
			_begin_distribution()
		return
	if _state_time >= _hold_left:
		_begin_distribution()

## Elige companero libre y el tipo de saque; si no hay companero, despeja hacia el campo.
func _choose_distribution(force_mode: StringName = &"") -> Dictionary:
	var mine: Vector3 = global_position
	var best: Footballer = null
	var best_score: float = -INF
	for f in ctx.footballers:
		if f.team != team:
			continue
		var fp: Vector3 = f.global_position
		var progress: float = (fp.x - mine.x) * float(-goal_side())
		var open: float = 6.0
		for o in ctx.footballers:
			if o.team != team:
				open = minf(open, Vector2(o.global_position.x - fp.x, o.global_position.z - fp.z).length())
		var score: float = progress * 0.5 + open * 2.0 - Vector2(fp.x - mine.x, fp.z - mine.z).length() * 0.2
		if open < 2.0:
			score -= 20.0
		if score > best_score:
			best_score = score
			best = f
	var target: Vector3 = best.global_position if best != null else Vector3(goal_x() + inward().x * 16.0, 0.0, rng.randf_range(-4.0, 4.0))
	var dist: float = Vector2(target.x - mine.x, target.z - mine.z).length()
	var mode: StringName = &"roll" if dist < 8.0 else (&"throw" if dist < 18.0 else &"kick")
	if force_mode != &"":
		mode = force_mode
	# Pase con el pie (cedida): se juega con un clip de campo, la pelota no pasa por las manos.
	if mode == &"foot":
		var fclip: StringName = &"Soccer_Pass" if PackLibrary.has_clip(&"Soccer_Pass") else &""
		return {"clip": fclip, "mode": mode, "target": target, "dist": dist}
	var clip: StringName = &"goalkeeper_pass" if mode == &"roll" else (&"goalkeeper_overhand_throw" if mode == &"throw" else &"goalkeeper_drop_kick")
	if mode == &"throw" and rng.randf() < 0.4:
		clip = &"Goalie_Throw"
	if not PackLibrary.has_clip(clip):
		clip = &""
	# Espejo para sacar con el lado que mira al companero.
	if clip != &"" and (target.z - mine.z) * float(goal_side()) * -1.0 < 0.0 and PackLibrary.has_clip(StringName(String(clip) + "_mirror")):
		clip = StringName(String(clip) + "_mirror")
	return {"clip": clip, "mode": mode, "target": target, "dist": dist}

## Empieza el saque. `force_mode` lo fija la persona (o la cedida con el pie); vacio = lo elige el arquero.
func _begin_distribution(force_mode: StringName = &"") -> void:
	_dist = _choose_distribution(force_mode)
	var clip: StringName = _dist["clip"]
	_released = false
	_dropped = false
	_kick_done = false
	state = State.DISTRIBUTE
	_state_time = 0.0
	if clip == &"" or not visual.uses_pack:
		_dist["tau"] = 0.4
		_dist["clip"] = &""
		return
	visual.play_pack_clip(clip, 1.15)
	_motion.start(clip, 1.15)
	var key: String = "hands"
	if _dist["mode"] == &"foot":
		var fp: Dictionary = PackLibrary.meta(clip).get("paths", {})
		key = "toe_r" if fp.has("toe_r") else ("toe_l" if fp.has("toe_l") else "hands")
	elif _dist["mode"] == &"kick":
		var toes: Dictionary = PackLibrary.meta(clip).get("paths", {})
		key = "toe_r" if toes.has("toe_r") and _toe_speed(clip, "toe_r") >= _toe_speed(clip, "toe_l") else "toe_l"
	_dist["key"] = key
	_dist["tau"] = KeeperPlanner.peak_speed_time(clip, key)
	_dist["start_pos"] = global_position

func _toe_speed(clip: StringName, key: String) -> float:
	var hp: PackedVector3Array = PackLibrary.meta(clip).get("paths", {}).get(key, PackedVector3Array())
	var best: float = 0.0
	for i in range(1, hp.size() - 1):
		best = maxf(best, (hp[i + 1] - hp[i - 1]).length())
	return best

func _tick_distribute(delta: float) -> void:
	var ball: Ball = ctx.ball
	var clip: StringName = _dist["clip"]
	var rv: Vector2 = _motion.step(delta) if clip != &"" else Vector2.ZERO
	var wv: Vector3 = forward() * rv.x + right_vec() * rv.y
	velocity.x = wv.x
	velocity.z = wv.z
	var tgt: Vector3 = _dist["target"]
	# Mira hacia donde saca.
	var face: Vector3 = tgt - global_position
	face.y = 0.0
	if face.length() > 0.5:
		var dy: float = wrapf(Locomotion.yaw_from_dir(face.normalized()) - yaw, -PI, PI)
		yaw = wrapf(yaw + clampf(dy, -deg_to_rad(300.0) * delta, deg_to_rad(300.0) * delta), -PI, PI)
	var k: int = int(_motion.t * 30.0)
	var tau: float = float(_dist["tau"])
	var mode: StringName = _dist["mode"]
	if clip == &"":
		_anchor.global_position = global_position + forward() * _tune.carry_forward + Vector3.UP * _tune.carry_height
		if _state_time >= tau and ball.holder == self:
			_release_ball(mode, global_position + Vector3.UP * 1.1)
		if _state_time >= 0.9:
			_finish_distribution()
		return
	if mode == &"foot":
		if not _released and _motion.t >= tau:
			_released = true
			_foot_ball = 0.0
			var ftoe: Vector3 = KeeperPlanner.path_world_at_body(clip, String(_dist.get("key", "toe_r")), k, global_position, yaw)
			if ftoe.distance_to(ball.global_position) <= 0.8:
				ball.kick(_throw_velocity(&"kick" if _gk_long else &"roll", ball.global_position, tgt), Vector3.ZERO, self)
				stats["distributions"] += 1
				ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_DISTRIBUTE, actor_id, team, {"mode": "foot", "dist": _dist["dist"]}))
		if not _motion.active or (clip == &"" and _state_time > 0.5):
			_finish_distribution()
		return
	if ball.holder == self and not _released:
		var key: String = "hands"
		if mode == &"kick":
			# Patada de despeje: suelta la pelota un instante antes del golpeo y la golpea con el pie.
			if not _dropped and _motion.t >= tau - 0.38:
				_dropped = true
				var hp: Vector3 = KeeperPlanner.path_world_at_body(clip, "hands", k, global_position, yaw)
				ball.release(self, Vector3.ZERO)
				ball.global_position = hp
			else:
				_anchor.global_position = KeeperPlanner.path_world_at_body(clip, key, k, global_position, yaw)
		else:
			_anchor.global_position = KeeperPlanner.path_world_at_body(clip, key, k, global_position, yaw)
			if _motion.t >= tau:
				_release_ball(mode, _anchor.global_position)
	if mode == &"kick" and _dropped and not _kick_done and _motion.t >= tau:
		_kick_done = true
		var toe: Vector3 = KeeperPlanner.path_world_at_body(clip, String(_dist["key"]), k, global_position, yaw)
		if toe.distance_to(ball.global_position) <= 0.55:
			ball.kick(_throw_velocity(&"kick", toe, tgt), Vector3.ZERO, self)
			_released = true
			stats["distributions"] += 1
			ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_DISTRIBUTE, actor_id, team, {"mode": "kick", "dist": _dist["dist"]}))
		else:
			_released = true
	if not _motion.active:
		_finish_distribution()

func _release_ball(mode: StringName, from: Vector3) -> void:
	var ball: Ball = ctx.ball
	var v: Vector3 = _throw_velocity(mode, from, _dist["target"])
	ball.release(self, v)
	ball.global_position = from
	ball.register_touch(self)
	_released = true
	stats["distributions"] += 1
	ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_DISTRIBUTE, actor_id, team, {"mode": String(mode), "dist": _dist["dist"]}))

## Velocidad de salida para que la pelota llegue a `target` (con error segun el atributo de saque).
func _throw_velocity(mode: StringName, from: Vector3, target: Vector3) -> Vector3:
	var d := Vector3(target.x - from.x, 0.0, target.z - from.z)
	var dist: float = d.length()
	var dir: Vector3 = d / dist if dist > 0.01 else inward()
	var key: String = "kicking" if mode == &"kick" else "throwing"
	var err: float = deg_to_rad(rng.randfn(0.0, lerpf(9.0, 2.5, _norm(key))))
	dir = dir.rotated(Vector3.UP, err)
	if mode == &"roll":
		return dir * clampf(dist * 0.9 + 2.0, 4.0, 11.0)
	var vmax: float = _tune.kick_speed if mode == &"kick" else _tune.throw_speed
	if mode == &"kick":
		vmax = lerpf(_tune.kick_speed, _tune.clearance_speed, 0.5)
	var g: float = BallPredictor.GRAVITY
	var v: float = minf(vmax, maxf(sqrt(g * dist) * 1.08, 7.0))
	var s: float = clampf(g * dist / (v * v), 0.0, 1.0)
	var theta: float = 0.5 * asin(s)
	return Vector3(dir.x * cos(theta), sin(theta), dir.z * cos(theta)) * v

func _finish_distribution() -> void:
	if ctx.ball.holder == self:
		ctx.ball.release(self, Vector3.ZERO)
	if _gk_stage == &"kick":
		# Saque de arco: si el pie no llego a la pelota (pelota movida por un choque), se juega igual desde donde esta
		# para que el partido no quede detenido.
		if ctx.ball.last_toucher != self or ctx.ball.linear_velocity.length() < 1.0:
			var tgt: Vector3 = _dist.get("target", global_position + inward() * 10.0)
			ctx.ball.kick(_throw_velocity(&"kick" if _gk_long else &"roll", ctx.ball.global_position, tgt), Vector3.ZERO, self)
		_gk_stage = &""
		goal_kick_done = true
	state = State.POSITION
	_state_time = 0.0
	_motion.stop()
	velocity = Vector3.ZERO
	_threat_since = -1.0

# --- Saque de arco ---------------------------------------------------------------------------------------

## Saque de arco: el arquero toma la pelota en el punto del saque, la coloca en el suelo con el clip de colocar
## (corto o, a veces, el largo) y la juega con el pie hacia un companero libre (corto) o en largo.
func start_goal_kick(spot: Vector3) -> void:
	_cancel_action(true)
	goal_kick_done = false
	_gk_long = rng.randf() < 0.35
	var face: Vector3 = inward()
	global_position = Vector3(spot.x, 0.0, spot.z) - face * 0.55
	yaw = Locomotion.yaw_from_dir(face)
	rotation.y = yaw
	velocity = Vector3.ZERO
	ctx.ball.hold(_anchor, self)
	_anchor.global_position = global_position + forward() * _tune.carry_forward + Vector3.UP * _tune.carry_height
	state = State.GOAL_KICK
	_state_time = 0.0
	_gk_stage = &"place"
	_gk_clip = PLACE_CLIPS[1] if (rng.randf() < 0.3 and PackLibrary.has_clip(PLACE_CLIPS[1])) else PLACE_CLIPS[0]
	if visual == null or not visual.uses_pack or not PackLibrary.has_clip(_gk_clip):
		_gk_clip = &""
		_gk_place_t = 0.4
		return
	var cut: float = PLACE_LONG_CUT if _gk_clip == PLACE_CLIPS[1] else -1.0
	visual.play_pack_clip(_gk_clip, 1.2, 0.0, cut / 1.2 if cut > 0.0 else -1.0)
	_motion.start(_gk_clip, 1.2, 0.0, cut / 1.2 if cut > 0.0 else -1.0)
	_gk_place_t = _lowest_hands_time(_gk_clip, cut)

## Instante (s del clip) en que las manos estan mas bajas (dejan la pelota en el suelo) dentro del tramo util.
static func _lowest_hands_time(id: StringName, cut: float) -> float:
	var hp: PackedVector3Array = PackLibrary.meta(id).get("paths", {}).get("hands", PackedVector3Array())
	if hp.is_empty():
		return 0.5
	var last: int = hp.size() - 1 if cut <= 0.0 else mini(hp.size() - 1, int(cut * 30.0) - 3)
	var best_k: int = int(last * 0.25)
	for k in range(int(last * 0.25), last):
		if hp[k].y < hp[best_k].y:
			best_k = k
	return float(best_k) / 30.0

func _tick_goal_kick(delta: float) -> void:
	var ball: Ball = ctx.ball
	match _gk_stage:
		&"place":
			var rv: Vector2 = _motion.step(delta) if _gk_clip != &"" else Vector2.ZERO
			var wv: Vector3 = forward() * rv.x + right_vec() * rv.y
			velocity.x = wv.x
			velocity.z = wv.z
			var t: float = _motion.t if _gk_clip != &"" else _state_time
			if ball.holder == self:
				if _gk_clip != &"":
					_anchor.global_position = KeeperPlanner.path_world_at_body(_gk_clip, "hands", int(t * 30.0), global_position, yaw)
				if t >= _gk_place_t:
					# Deja la pelota en el suelo, quieta, donde la tienen las manos.
					var at: Vector3 = _anchor.global_position
					ball.release(self, Vector3.ZERO)
					ball.global_position = Vector3(at.x, Tuning.ball.radius + 0.01, at.z)
					ball.register_touch(self)
			if ball.holder != self and (_gk_clip == &"" or not _motion.active or t >= _gk_place_t + 0.5):
				_motion.stop()
				if visual != null:
					visual.stop_current_action()
				velocity = Vector3.ZERO
				_gk_stage = &"wait"
				_state_time = 0.0
		&"wait":
			velocity = Vector3.ZERO
			_face_ball(delta)
			var go: bool = _state_time > 0.5
			if is_human_controlled and ctx.input_enabled:
				go = _state_time > MANUAL_HOLD_MAX
			if go:
				_start_goal_kick_strike(_gk_long)
		_:
			pass

## Golpeo del saque de arco (pase con el pie): corto o largo. La persona lo pide con PASE (corto) o TIRO (largo).
func _start_goal_kick_strike(long: bool) -> void:
	_gk_long = long
	_gk_stage = &"kick"
	_begin_distribution(&"foot")

# --- Mano a mano, centros y estirada desesperada ------------------------------------------------------------

## Rival que se va solo hacia el arco con la pelota: a menos de RUSH_RANGE m y sin defensor propio entre el y el arco.
func _lone_attacker() -> Footballer:
	var ball: Ball = ctx.ball
	if ball.is_held() or ctx.dead_ball or ball.global_position.y > 0.6:
		return null
	var g := Vector3(goal_x(), 0.0, 0.0)
	var carrier: Footballer = null
	for f in ctx.footballers:
		if f.team != team and f.ball_handler.has_possession():
			carrier = f
	if carrier == null:
		return null
	var cp := Vector3(carrier.global_position.x, 0.0, carrier.global_position.z)
	if cp.distance_to(g) > RUSH_RANGE or (cp.x - g.x) * -float(goal_side()) < 1.0:
		return null
	for f in ctx.footballers:
		if f.team != team:
			continue
		var fp := Vector3(f.global_position.x, 0.0, f.global_position.z)
		var ab: Vector3 = g - cp
		var u: float = clampf((fp - cp).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if u > 0.05 and (cp + ab * u).distance_to(fp) < 1.6:
			return null
	return carrier

## Mano a mano: si el portador se adelanta la pelota (toque largo) y el arquero llega antes, se lanza a sus pies
## (bloqueo con el cuerpo o atajada baja) con el plan de manos real.
func _try_smother() -> bool:
	if not rushing:
		return false
	var lone: Footballer = _lone_attacker()
	if lone == null:
		return false
	var ball: Ball = ctx.ball
	var bp: Vector3 = ball.global_position
	var my_d: float = Vector2(bp.x - global_position.x, bp.z - global_position.z).length()
	var his_d: float = lone.ball_handler.ball_distance()
	if my_d > 2.4 or his_d < 0.75 or my_d > his_d + 1.2:
		return false
	var traj: PackedVector3Array = BallPredictor.trajectory(bp, ball.linear_velocity, 1.0, 1.0 / 30.0, _perceived_spin())
	var plan: Dictionary = KeeperPlanner.plan_save(global_position, yaw, traj, 1.0 / 30.0, 0.0, ball.linear_velocity.length(), false, _clip_speeds(), _hand_limits())
	if plan.is_empty() or float(plan["dist"]) > float(plan["radius"]) * 0.85:
		return false
	_plan = plan
	_plan["smother"] = true
	_plan_clock = _clock
	_state_time = 0.0
	stats["smothers"] = int(stats.get("smothers", 0)) + 1
	_begin_action()
	return true

## Centro al area: si la pelota llega por alto (no a puerta) y el arquero la alcanza con las manos cerca de su linea antes
## que nadie, sale a atraparla (el plan usa la trayectoria de manos real; si no llega, no sale).
## Punto (en el suelo) donde un centro en el aire baja a 2.2 m de altura dentro de la zona del arquero, o Vector3.INF.
func _cross_landing() -> Vector3:
	var ball: Ball = ctx.ball
	if ball.is_held() or ctx.dead_ball or ball.last_touch_team == team or ball.global_position.y < 0.5:
		return Vector3.INF
	var v: Vector3 = ball.linear_velocity
	if v.length() < 4.0 or (v.y < 0.0 and ball.global_position.y < 1.2):
		return Vector3.INF
	var traj: PackedVector3Array = BallPredictor.trajectory(ball.global_position, v, 1.6, 1.0 / 15.0, _perceived_spin())
	var apex := false
	for i in range(1, traj.size()):
		if traj[i].y < traj[i - 1].y:
			apex = true
		if apex and traj[i].y <= 2.2:
			var p: Vector3 = traj[i]
			if absf(p.x - goal_x()) <= CLAIM_MAX_DEPTH and absf(p.z) <= ctx.pitch.config.half_goal() + 3.0 and (p.x - goal_x()) * -float(goal_side()) > 0.2:
				return Vector3(p.x, 0.0, p.z)
			return Vector3.INF
	return Vector3.INF

func _assess_cross() -> bool:
	var ball: Ball = ctx.ball
	if ball.is_held() or ctx.dead_ball or ball.last_touch_team == team:
		return false
	var v: Vector3 = ball.linear_velocity
	if v.length() < 4.0 or _cross_landing() == Vector3.INF:
		return false
	if absf(ball.global_position.x - goal_x()) > 16.0:
		return false
	var traj: PackedVector3Array = BallPredictor.trajectory(ball.global_position, v, 1.4, 1.0 / 30.0, _perceived_spin())
	# Se planta y salta desde donde queda al frenar (mismo criterio que en los disparos).
	var plan: Dictionary = KeeperPlanner.plan_save(_origin_after_stop(), yaw, traj, 1.0 / 30.0, 0.15, v.length(), false, _clip_speeds(), _hand_limits())
	if plan.is_empty() or float(plan["dist"]) > float(plan["radius"]) * 0.95:
		return false
	var i: int = clampi(int(float(plan["arrive"]) * 30.0), 0, traj.size() - 1)
	var catch_p: Vector3 = traj[i]
	if absf(catch_p.x - goal_x()) > CLAIM_MAX_DEPTH or absf(catch_p.z) > ctx.pitch.config.half_goal() + 3.0 or catch_p.y < 0.9:
		return false
	# Si un rival llega antes al punto, no sale (seria una salida en falso).
	for f in ctx.footballers:
		if f.team != team and Vector2(f.global_position.x - catch_p.x, f.global_position.z - catch_p.z).length() / 6.0 < float(plan["arrive"]) - 0.25:
			return false
	_plan = plan
	_plan["ball_speed"] = v.length()
	_plan["claim"] = true
	_plan_clock = _clock
	_replan_cd = 0.1
	_state_time = 0.0
	stats["cross_claims"] = int(stats.get("cross_claims", 0)) + 1
	state = State.PREPARE
	return true

## Estirada sin opciones: goalkeeper_miss se lanza a la derecha del arquero. Solo si la pelota cruza por ese lado, a
## 1-3.2 m, y hay tiempo de empezar el salto. El contacto se juzga igual que en cualquier atajada.
func _plan_miss(traj: PackedVector3Array, ci: int) -> Dictionary:
	if visual == null or not visual.uses_pack:
		return {}
	var cp: Vector3 = traj[ci]
	var lateral: float = (cp - global_position).dot(right_vec())
	var t_arrive: float = float(ci) / 30.0
	if absf(lateral) < 1.0 or absf(lateral) > 3.2 or t_arrive < 0.3 or cp.y > ctx.pitch.config.goal_height:
		return {}
	# El clip salta hacia la derecha; su espejo, hacia la izquierda.
	var id: StringName = MISS_CLIP if lateral > 0.0 else StringName(String(MISS_CLIP) + "_mirror")
	if not PackLibrary.has_clip(id):
		return {}
	var tau: float = KeeperPlanner.peak_speed_time(id, "hands")
	return {"clip": id, "speed": 1.0, "k": int(tau * 30.0), "tau": tau, "delay": maxf(t_arrive - tau, 0.0),
		"arrive": t_arrive, "dist": 9.0, "radius": 0.45, "travel": 0.65}

## Modo 4: levantarse tras una estirada que termina tendido (meta lie): un clip de levantarse del arquero (o de campo) que
## empieza en la misma postura; con la pelota en las manos, uno «con pelota». Devuelve true si empezo.
func _json_getup() -> bool:
	var lie: String = String(PackLibrary.meta(_plan["clip"]).get("lie", ""))
	if lie == "" or lie == "up":
		return false
	var holding: bool = ctx.ball.holder == self
	var best: Array[StringName] = []
	var any: Array[StringName] = []
	for role in [&"gk_getup", &"getup"]:
		for id in PackLibrary.by_role(role):
			var m: Dictionary = PackLibrary.meta(id)
			var with_ball: bool = String(m.get("source", "")).to_lower().contains("with_ball")
			if with_ball != holding:
				continue
			any.append(id)
			if String(m.get("lie", "")) == lie:
				best.append(id)
	var pool: Array[StringName] = best if not best.is_empty() else any
	if pool.is_empty():
		return false
	var clip: StringName = pool[rng.randi() % pool.size()]
	_plan = {"clip": clip, "speed": 1.15, "tau": INF, "getup": true}
	visual.play_pack_clip(clip, 1.15)
	_motion.start(clip, 1.15)
	_state_time = 0.0
	stats["getups"] = int(stats.get("getups", 0)) + 1
	return true

## Indicaciones al equipo (presentacion): con la jugada lejos y sin peligro, de vez en cuando el arquero ordena.
func _maybe_direct_team() -> void:
	if _direct_cd > 0.0 or visual == null or not visual.uses_pack or visual.is_action_playing() or is_human_controlled:
		return
	var ball: Ball = ctx.ball
	var far: float = absf(ball.global_position.x - goal_x())
	if far < 16.0:
		return
	_direct_cd = DIRECT_COOLDOWN * rng.randf_range(0.8, 1.3)
	var own_ball: bool = ball.last_touch_team == team
	var id: StringName = DIRECT_ATTACK_CLIP if own_ball else DIRECT_DEFENSE_CLIP
	if PackLibrary.json_mode() and rng.randf() < 0.6:
		# Modo 4: tambien los gestos y esperas del arquero convertidos (escenas de arquero, variantes de espera).
		var pool: Array[StringName] = []
		for role in [&"gk_gesture", &"gk_idle_var", &"gk_direct"]:
			for c in PackLibrary.by_role(role):
				if not String(c).ends_with("_mirror") and (PackLibrary.meta(c).get("root_total", Vector2.ZERO) as Vector2).length() < 1.0:
					pool.append(c)
		if not pool.is_empty():
			id = pool[rng.randi() % pool.size()]
	if PackLibrary.has_clip(id):
		visual.play_pack_clip(id, 1.0, 0.0, DIRECT_SECONDS)
		stats["directing"] = int(stats.get("directing", 0)) + 1

# --- Eventos del partido ------------------------------------------------------------------------------

func _on_match_event(e: GameEvent) -> void:
	match e.type:
		GameEvent.Type.SHOT:
			_notice_real_shot(e)
		GameEvent.Type.KICKOFF, GameEvent.Type.RESTART, GameEvent.Type.MATCH_START:
			reset_position()
		GameEvent.Type.OUT_OF_PLAY, GameEvent.Type.SET_PIECE:
			# Pelota muerta: cualquier atajada o salida en curso se corta y vuelve a su arco (el saque de arco lo
			# inicia la escena con start_goal_kick).
			if state != State.GOAL_KICK and state != State.HOLD:
				_cancel_action(true)
				_gk_stage = &""
				state = State.POSITION
				if String(e.data.get("kind", "")) == "penalty" and e.team != team:
					global_position = Vector3(goal_x(), 0.0, 0.0) + inward() * 0.15
					velocity = Vector3.ZERO
		GameEvent.Type.GOAL:
			if visual != null and not visual.is_placeholder:
				visual.stop_current_action()
				var conceded: bool = e.team != team
				_cancel_action(true)
				state = State.POSITION
				visual.play_situation(&"dejected" if conceded else &"celebrate", actor_id, 1.0, 2.4)

## Lee la salida real del tiro aunque luego vaya afuera o lo bloquee un defensor. Verlo no obliga a estirarse:
## la trayectoria fisica de _assess_shot sigue decidiendo si amenaza el arco y si las manos llegan.
func _notice_real_shot(event: GameEvent) -> void:
	if event.team == team or event.team < 0 or ctx.ball.is_held():
		return
	var shooter: Node = ctx.ball.last_toucher
	if shooter == null or shooter.get("actor_id") != event.actor_id:
		return
	var direction: Array = event.data.get("dir", [])
	if direction.size() < 2 or float(direction[0]) * float(goal_side()) <= 0.0 or float(event.data.get("speed", 0.0)) < _tune.shot_min_speed:
		return
	var key := Vector2i(ctx.ball.last_touch_frame, event.actor_id)
	if key == _last_shot_notice:
		return
	_last_shot_notice = key
	stats["shots_seen"] += 1
	# El aviso confirma el disparo; no es una anticipacion del armado anterior al golpe.
	# Se conserva el tiempo observado por _watch_kickers, si existio.
	_next_plan_at = -1.0
	if state == State.TURNING:
		_motion.stop()
		state = State.POSITION
	if state == State.POSITION and visual != null:
		# Una indicacion al equipo no debe tapar la preparacion de un tiro que acaba de salir.
		visual.stop_current_action()

## Giro sin amenaza inmediata: usa la raiz y el rumbo medidos. Un disparo interrumpe este estado.
func _try_turn() -> bool:
	if is_human_controlled or state != State.POSITION or ctx.dead_ball or ctx.ball.ground_speed() >= _tune.shot_min_speed:
		return false
	if global_position.distance_to(ctx.ball.global_position) < 6.0:
		return false
	var best: StringName = &""
	var best_error: float = INF
	for id in PackLibrary.by_role(&"gk_turn"):
		var error: float = _turn_error(id)
		if error < best_error:
			best = id
			best_error = error
	return best != &"" and start_orientation_turn(best)

func _turn_error(id: StringName) -> float:
	var meta: Dictionary = PackLibrary.meta(id)
	if meta.get("role", "") != "gk_turn" or not bool(meta.get("json", false)):
		return INF
	var needed: float = wrapf(Locomotion.yaw_from_dir(KickModel.flat(ctx.ball.global_position - global_position).normalized()) - yaw, -PI, PI)
	var measured: float = ActionMotion.heading_rel(meta.get("heading_path", PackedFloat32Array()), float(meta.get("duration", 1.0)))
	var error: float = absf(wrapf(needed - measured, -PI, PI))
	if absf(needed) < deg_to_rad(2.0) or error > deg_to_rad(12.0) or absf(velocity.length() - float(meta.get("v_in", 0.0))) > 1.3:
		return INF
	var offset: Vector2 = meta.get("root_total", Vector2.ZERO)
	var end: Vector3 = global_position + forward() * offset.x + right_vec() * offset.y
	if absf(end.x) > ctx.pitch.config.half_length() - 0.3 or absf(end.z) > ctx.pitch.config.half_width() - 0.3:
		return INF
	return error

func start_orientation_turn(id: StringName) -> bool:
	if state != State.POSITION or is_human_controlled or ctx.dead_ball or ctx.ball.ground_speed() >= _tune.shot_min_speed \
			or global_position.distance_to(ctx.ball.global_position) < 6.0 or is_inf(_turn_error(id)):
		return false
	if visual.play_pack_clip(id) <= 0.0 or not _motion.start(id):
		return false
	_motion.yaw0 = yaw
	state = State.TURNING
	return true

func _tick_turn(delta: float) -> void:
	# Una reposicion o un cambio de trayectoria invalida el destino del giro en curso.
	# Se compara el rumbo final planificado, no todo el giro con el rumbo ya avanzado.
	var target_yaw: float = Locomotion.yaw_from_dir(KickModel.flat(ctx.ball.global_position - global_position).normalized())
	var planned_yaw: float = _motion.yaw0 + _motion.heading_at(_motion.length)
	var target_changed: bool = absf(wrapf(target_yaw - planned_yaw, -PI, PI)) > deg_to_rad(12.0)
	if target_changed or ctx.ball.ground_speed() >= _tune.shot_min_speed or global_position.distance_to(ctx.ball.global_position) < 4.0:
		_motion.stop()
		visual.stop_current_action()
		state = State.POSITION
		_tick_position(delta)
		return
	var root_velocity: Vector2 = _motion.step(delta)
	var base: Vector3 = Locomotion.dir_from_yaw(_motion.yaw0)
	var right: Vector3 = Vector3(-base.z, 0.0, base.x)
	var world_velocity: Vector3 = base * root_velocity.x + right * root_velocity.y
	velocity.x = world_velocity.x
	velocity.z = world_velocity.z
	yaw = _motion.yaw0 + _motion.heading_at(_motion.t)
	if not _motion.active:
		state = State.POSITION
