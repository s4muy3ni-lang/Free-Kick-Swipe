class_name Footballer
extends CharacterBody3D
## Futbolista de campo. Orquesta: entrada (InputFrame) -> intencion -> locomocion -> contacto con la
## pelota. No importa si lo controla una persona, la IA o la red: todos pasan por InputFrame.
##
## Estado replicable separado de la presentacion: la presentacion es FootballerVisual (hijo "Visual").

signal kicked(action: StringName, result: KickModel.KickResult)
signal tackled(won: bool)

@export var team: int = 0
@export var display_name: String = "Jugador"
@export var shirt_number: int = 10
@export var dominant_right: bool = true
## Las pruebas de logica desactivan el modelo 3D para ir mas rapido.
@export var build_visual: bool = true

var actor_id: int = 0
var attributes: PlayerAttributes = PlayerAttributes.new()
var ctx: MatchContext = null
var input_source: InputSource = null
var locomotion: Locomotion
var ball_handler: BallHandler
var press: PressController
var visual: FootballerVisual = null
var last_frame: InputFrame = InputFrame.new()
var is_pressing: bool = false
var press_info: PressController.PressOutput = null
## Acciones de cuerpo completo con clips (barrida, caidas, levantarse).
var actions: PlayerActions = null
## Autoridad unica sobre el cuerpo y la pose: decide que accion entra y cual sigue (ActionArbiter).
var arbiter: ActionArbiter = null
## Sobrescritura de asistencia por jugador (-1 = usar la configuracion global).
var assist_override_pass: float = -1.0
var assist_override_shot: float = -1.0
## Marcado por el gestor de partido: este futbolista es el que maneja la persona.
var is_human_controlled: bool = false
## Probabilidad de que la IA entre cuando puede disputar una pelota protegida por el portador (ver _ai_commits_tackle).
const AI_TACKLE_COMMIT := 0.45
## Angulo (grados) entre el joystick y la pelota suelta por debajo del cual el rumbo se ajusta al punto donde se alcanza.
const LOOSE_SNAP_DEG := 40.0
## Velocidad extra (m/s) de un ajuste de zancada para llegar a la pelota al patear. Mueve el cuerpo pero NO entra en
## Locomotion (no cambia la velocidad ni la inercia del jugador).
var nudge_velocity: Vector3 = Vector3.ZERO

## Reaccion pendiente a un evento de partido (situacion del AnimationCatalog) y segundos que faltan para empezarla.
## Solo presentacion: no bloquea la entrada ni cambia el movimiento.
## Distancia (m) al portador rival a la que el defensor pasa a marcar de frente (jockey).
const JOCKEY_RANGE := 4.5
const REACTION_MAX_SECONDS := 2.4
const REACTION_MAX_WAIT := 1.0
const REACTION_START_SPEED := 1.5
const RECEIVE_MAX_SPEED := 2.0
const RECEIVE_MAX_SECONDS := 0.9
var _reaction: StringName = &""
## Resultado de la ultima entrada pedida con el boton (stand, shoulder, slide, whiff): diagnostico y pruebas.
var last_tackle: StringName = &""
## Balon parado que ejecuta este jugador (saque de banda, corner, tiro libre, penal) o null.
var set_piece: SetPiece = null
## Pase que viene hacia este jugador: punto de llegada previsto, tipo y segundos de validez. La IA corre a ese punto
## (desmarque de recepcion / carrera al espacio del filtrado); la persona lo ve en el indicador.
var incoming_pass_point: Vector3 = Vector3.ZERO
var incoming_pass_kind: StringName = &""
var incoming_pass_time: float = 0.0
## Recepcion: true desde que se anuncia un pase hasta que el joystick se suelta una vez (el que se traia no cuenta).
var _recv_stick_lock: bool = false
## Quien hizo el pase que viene (en los primeros pasos tras patear sigue contando como poseedor: no corta el pase).
var incoming_pass_from: Node = null
## Carrera al espacio tras dar un pase (pared): direccion y segundos que quedan. La usa la IA del pasador.
var give_and_go_dir: Vector3 = Vector3.ZERO
var give_and_go_time: float = 0.0
var _reaction_cut: float = REACTION_MAX_SECONDS
var _reaction_wait: float = 0.0

func _ready() -> void:
	add_to_group("footballers")
	collision_layer = Ball.LAYER_PLAYERS
	collision_mask = Ball.LAYER_WORLD | Ball.LAYER_PLAYERS | Ball.LAYER_KEEPERS
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_snap_length = 0.4
	floor_stop_on_slope = true
	var t: PlayerTuning = Tuning.player
	if get_node_or_null("CollisionShape3D") == null:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var cap := CapsuleShape3D.new()
		cap.radius = t.capsule_radius
		cap.height = t.capsule_height
		cs.shape = cap
		cs.position = Vector3(0.0, t.capsule_height * 0.5, 0.0)
		add_child(cs)
	locomotion = Locomotion.new(t, attributes)
	ball_handler = BallHandler.new(self)
	ball_handler.kicked.connect(func(a: StringName, r: KickModel.KickResult) -> void: kicked.emit(a, r))
	press = PressController.new()
	arbiter = ActionArbiter.new(self)
	actions = PlayerActions.new(self)
	if build_visual:
		visual = get_node_or_null("Visual") as FootballerVisual
		if visual == null:
			visual = FootballerVisual.new()
			visual.name = "Visual"
			add_child(visual)
			visual.build(FootballerVisual.default_kit(team))
		visual.arbiter = arbiter

## Configura el jugador dentro de un partido.
func setup(context: MatchContext, team_index: int, id: int, attrs: PlayerAttributes, source: InputSource) -> void:
	ctx = context
	team = team_index
	actor_id = id
	set_attributes(attrs)
	input_source = source
	ctx.register_footballer(self)
	if not ctx.event_emitted.is_connected(_on_match_event):
		ctx.event_emitted.connect(_on_match_event)
	# El equipo 0 ataca +X; el equipo 1 ataca -X. Mirar hacia el arco rival al inicio.
	if locomotion != null:
		locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1.0 if team == 0 else -1.0, 0.0, 0.0))
		rotation.y = locomotion.yaw
	# El visual se construye en _ready con el equipo por defecto: al conocer el equipo real se aplican sus colores.
	if visual != null and not visual.is_placeholder and team != 0:
		visual.set_kit(FootballerVisual.default_kit(team))

## Un companero (`from`) acaba de pasarle la pelota: guarda el punto de llegada para ir a buscarla.
func expect_pass(point: Vector3, kind: StringName, from: Node = null) -> void:
	incoming_pass_from = from
	incoming_pass_point = Vector3(point.x, 0.0, point.z)
	incoming_pass_kind = kind
	incoming_pass_time = 2.5 if String(kind).begins_with("through") or String(kind).begins_with("cross") else 1.6
	_recv_stick_lock = true

## true mientras hay un pase en camino hacia este jugador (y la pelota no la tiene nadie todavia).
func has_incoming_pass() -> bool:
	return incoming_pass_time > 0.0

## Punto donde salir a buscar el pase que viene: el primero de la trayectoria PREDICHA de la pelota al que el jugador
## llega antes que ella (a ras de piso o a la altura de la cabeza). Si no llega a ninguno, el punto de destino del pase.
func pass_meet_point() -> Vector3:
	var b: Ball = ctx.ball if ctx != null else null
	if b == null:
		return incoming_pass_point
	var traj: PackedVector3Array = BallPredictor.trajectory(b.global_position, b.linear_velocity, 2.4, 0.1, b.angular_velocity)
	var run: float = maxf(locomotion.max_sprint_speed() * 0.9, 2.0)
	var me := Vector3(global_position.x, 0.0, global_position.z)
	for i in range(2, traj.size()):
		var p: Vector3 = traj[i]
		if p.y > 1.9:
			continue
		var flat := Vector3(p.x, 0.0, p.z)
		if me.distance_to(flat) / run <= float(i) * 0.1 - 0.12:
			return flat
	return incoming_pass_point

func set_attributes(attrs: PlayerAttributes) -> void:
	attributes = attrs
	if locomotion != null:
		locomotion.attributes = attrs

## Al liberarse el nodo se rompe el ciclo BallHandler <-> submodulos (RefCounted): si no, quedan vivos en ObjectDB.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and ball_handler != null:
		ball_handler.dispose()

func _exit_tree() -> void:
	if ctx != null:
		ctx.unregister_footballer(self)
		if ctx.event_emitted.is_connected(_on_match_event):
			ctx.event_emitted.disconnect(_on_match_event)

## Durante un golpeo en el aire (cabezazo, volea) la pelota atraviesa el cuerpo hasta el contacto del clip: si no, rebota
## contra la capsula antes de que la cabeza o el pie lleguen. Un golpeo fallido deja pasar la pelota.
func set_ball_ghost(on: bool) -> void:
	collision_layer = 0 if on else Ball.LAYER_PLAYERS

func has_ball() -> bool:
	return ball_handler != null and ball_handler.has_possession()

## Notificacion de una colision fisica real de Jolt; no se usa para fabricar un toque ni mover la pelota.
func on_ball_impact(ball: Ball) -> void:
	if actions != null:
		actions.react_to_ball_impact(ball)

func reset_motion() -> void:
	_cancel_reaction()
	set_piece = null
	if actions != null:
		actions.reset()
	if arbiter != null:
		arbiter.reset("reset_motion")
	velocity = Vector3.ZERO
	if locomotion != null:
		locomotion.stop()

func place_at(pos: Vector3, yaw: float) -> void:
	_cancel_reaction()
	if actions != null:
		actions.reset()
	if arbiter != null:
		arbiter.reset("colocacion")
	global_position = pos
	if locomotion != null:
		locomotion.yaw = yaw
		locomotion.stop()
	rotation.y = yaw
	velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	Prof.begin(&"jugadores (total)")
	_player_step(delta)
	Prof.end(&"jugadores (total)")

func _player_step(delta: float) -> void:
	if ctx == null or locomotion == null:
		return
	Prof.begin(&"posesion (update_possession)")
	ctx.update_possession()
	Prof.end(&"posesion (update_possession)")
	incoming_pass_time = maxf(incoming_pass_time - delta, 0.0)
	give_and_go_time = maxf(give_and_go_time - delta, 0.0)
	if incoming_pass_time > 0.0 and ctx.ball != null and ctx.ball.last_toucher != null and ctx.ball.last_toucher.get("team") != team:
		incoming_pass_time = 0.0   # lo corto un rival: ya no viene
	# La pelota ya la tiene otro (por ejemplo un companero que se adelanto): el pase ya no es para mi. Sin esto el
	# receptor seguia corriendo al punto del pase y se metia encima del companero que conducia (video del usuario).
	if incoming_pass_time > 0.0 and ctx.possessor != null and ctx.possessor != self and ctx.possessor != incoming_pass_from:
		incoming_pass_time = 0.0
	Prof.begin(&"entrada (IA)")
	var frame: InputFrame = input_source.poll(self) if (input_source != null and ctx.input_enabled) else InputFrame.new()
	Prof.end(&"entrada (IA)")
	last_frame = frame
	if set_piece != null:
		if set_piece.tick(frame, delta):
			return
		if set_piece.stage == &"done":
			set_piece = null
	# Modo 4: un giro sin pelota (clip) se corta si la pelota llega cerca: primero esta la jugada.
	if actions.kind == &"turn" and ctx.ball != null and KickModel.flat(ctx.ball.global_position - global_position).length() < JSON_TURN_BALL_DIST * 0.5:
		actions.stop("pelota cerca")
	# Una accion de cuerpo completo (barrida, caida, levantarse) mueve al jugador con la raiz del clip.
	if actions.tick(delta):
		if visual != null:
			visual.update_motion(self, delta)
		return
	# REGATE con el joystick hacia atras y la pelota al pie: vuelta pisando la pelota (DragBack); si no, la ruleta.
	if frame.skill_pressed and _skill_is_drag_back(frame):
		ball_handler.drag_back.request()
		ball_handler.json_move.request_skill()
	elif frame.skill_pressed and PackLibrary.json_mode():
		# Modo 4: el regate es un clip JSON con sus toques (JsonBallMove), no la ruleta del pack.
		ball_handler.json_move.request_skill()
	elif frame.skill_pressed:
		actions.try_skill()
		if actions.tick(0.0):
			if visual != null:
				visual.update_motion(self, delta)
			return
	var stick_mag: float = clampf(frame.move_length(), 0.0, 1.0)
	var stick_world: Vector3 = frame.move_world if frame.use_world else ctx.screen_to_world(frame.move)
	if stick_world.length() > 1.0:
		stick_world = stick_world.normalized()
	var desired_dir: Vector3 = stick_world.normalized() if stick_mag > 0.05 else Vector3.ZERO
	var desired_mag: float = stick_mag
	var want_sprint: bool = frame.sprint
	# Recepcion asistida: con el joystick suelto, el jugador de la persona sale al encuentro del pase que le llega
	# (se orienta y ajusta los pasos a la trayectoria real de la pelota). Mover el joystick manda siempre.
	# Con una orden de golpeo de primera esperando la pelota, el joystick es la puntería y el jugador va a la trayectoria.
	var first_time: bool = is_human_controlled and ball_handler.is_waiting_first_time()
	# El joystick que se traia del pase (al cambiar al receptor sigue apretado) no aleja al receptor de la pelota: manda
	# de nuevo cuando se suelta una vez.
	if stick_mag < 0.2:
		_recv_stick_lock = false
	if is_human_controlled and (first_time or ((stick_mag < 0.2 or _recv_stick_lock) and has_incoming_pass())) and not ball_handler.has_possession():
		var meet: Vector3 = pass_meet_point() if has_incoming_pass() else ball_handler.incoming_ball_point()
		var to_meet: Vector3 = KickModel.flat(meet - global_position)
		if first_time and to_meet.length() <= 0.5:
			desired_dir = Vector3.ZERO   # ya esta en la trayectoria: se planta y espera la pelota
			desired_mag = 0.0
			want_sprint = false
		elif to_meet.length() > 0.5:
			desired_dir = to_meet.normalized()
			desired_mag = clampf(to_meet.length() / 2.5, 0.4, 1.0)
			want_sprint = to_meet.length() > 4.0
	# Pelota suelta cerca: el jugador de la persona va a buscarla (prueba03: «el jugador siempre va al balon, el que esta
	# siendo controlado»). Con el joystick suelto corre solo al punto donde la alcanza; con el joystick apuntando mas o
	# menos hacia ella, el rumbo se ajusta a ese punto (no se pasa ni se queda corto). Apuntando a otro lado manda el joystick.
	elif is_human_controlled and not ball_handler.has_possession() and not frame.press_held:
		var chase: Vector3 = ball_handler.loose_ball_chase()
		if chase != Vector3.INF:
			var to_ball: Vector3 = KickModel.flat(chase - global_position)
			if to_ball.length() > 0.3 and (stick_mag < 0.2 or KickModel.angle_between_deg(desired_dir, to_ball) < LOOSE_SNAP_DEG):
				desired_dir = to_ball.normalized()
				desired_mag = maxf(stick_mag, clampf(to_ball.length() / 2.0, 0.5, 1.0))
				want_sprint = want_sprint or to_ball.length() > 4.0

	# Recepcion con clip (modo 4): mientras llega la pelota, el receptor se coloca donde un clip de recepcion compatible
	# encajara con ella (JsonReceive.approach). La persona con el joystick suelto (el joystick manda); la IA siempre.
	var ap: Vector3 = ball_handler.receive.approach if ball_handler.receive != null else Vector3.INF
	var receive_face: Vector3 = Vector3.ZERO
	if ap != Vector3.INF and not frame.press_held and (not is_human_controlled or stick_mag < 0.2):
		receive_face = ball_handler.receive.approach_face
		var to_ap: Vector3 = KickModel.flat(ap - global_position)
		if to_ap.length() > 0.12:
			desired_dir = to_ap.normalized()
			desired_mag = clampf(to_ap.length() / 1.2, 0.25, 1.0)
			want_sprint = to_ap.length() > 1.8
		else:
			desired_dir = Vector3.ZERO
			desired_mag = 0.0

	# Presion defensiva: el boton fija la INTENCION de disputar; el joystick solo ajusta el angulo.
	is_pressing = false
	press_info = null
	if frame.press_held and ctx.ball != null and not ball_handler.controls_ball():
		press_info = press.update(self, ctx, stick_world, stick_mag, delta)
		if press_info.active:
			is_pressing = true
			desired_dir = press_info.dir
			desired_mag = press_info.magnitude
			want_sprint = want_sprint or press_info.sprint
			# La IA disputa sola al presionar (barrida de recuperacion, carga o robo). La persona NO roba por mantener
			# la presion: la presion solo cierra y contiene; la entrada se pide con el boton ENTRADA.
			if not is_human_controlled:
				if press_info.carrier != null and actions.try_slide_tackle(press_info.carrier):
					pass
				elif press_info.carrier != null and actions._alongside(press_info.carrier) and actions.rng.randf() < 0.04:
					actions.shoulder_charge(press_info.carrier)
				elif press_info.attempt_tackle and _ai_commits_tackle(press_info.carrier):
					actions.tackle_gesture(press_info.carrier)
					var won: bool = ball_handler.attempt_tackle(press_info.carrier)
					tackled.emit(won)
				elif press_info.attempt_tackle:
					actions.press_gesture(press_info.carrier)
			elif press_info.attempt_tackle and press_info.carrier != null:
				actions.press_gesture(press_info.carrier)
	else:
		press.reset()
	if frame.tackle_pressed and not ball_handler.controls_ball():
		var carrier: Footballer = press_info.carrier if press_info != null else PressController._find_carrier(ctx, ctx.ball, 1 - team, Tuning.player.possession_radius * 1.4)
		last_tackle = actions.tackle_request(carrier)
		if actions.tick(0.0):
			if visual != null:
				visual.update_motion(self, delta)
			return

	# La IA no sale de la cancha: reculando en jockey junto a la linea de fondo cruzaba la linea (1.1-1.3 m fuera).
	if not is_human_controlled and desired_dir.length_squared() > 0.0001:
		desired_dir = _keep_inside(desired_dir)

	# Pelota propia atras o al costado tras un giro: primero se va a por ella (BallHandler.carry_steer). Los toques
	# siguen usando el rumbo pedido (intent_dir): al llegar a la pelota, el toque la lleva hacia alli.
	var intent_dir: Vector3 = desired_dir
	# Joystick suelto con la pelota al alcance pero fuera del pie (al costado, detras, yendose): el jugador va a ella
	# (BallHandler.settle_steer); en ese caso no la sigue follow_steer ni se pone de costado (control lateral).
	var settling_close: bool = false
	var settle_face: Vector3 = Vector3.ZERO
	if not is_pressing and stick_mag < 0.18 and desired_dir.length_squared() < 0.01:
		# Con un boton de golpeo apretado en este paso no hay acomodo cercano (lo decide la preparacion del golpeo; los
		# estados de carga de BallHandler se actualizan despues, en ball_handler.update).
		ball_handler.kick_button_now = frame.pass_held or frame.shoot_held or frame.through_held or frame.cross_held \
			or frame.pass_pressed or frame.shoot_pressed or frame.through_pressed or frame.cross_pressed
		var settle: Array = ball_handler.settle_steer()
		if not settle.is_empty():
			desired_dir = settle[0]
			desired_mag = settle[1]
			settling_close = ball_handler.settle_close_now
			if settling_close and settle.size() > 2:
				settle_face = settle[2]
	# Conduccion fisica: el que conduce sigue a su pelota (BallHandler.follow_steer) y la acomoda al alcanzarla; el
	# joystick decide hacia donde la llevara el proximo toque.
	if not is_pressing and not settling_close:
		var follow: Array = ball_handler.follow_steer(desired_dir, desired_mag, want_sprint)
		if not follow.is_empty():
			desired_dir = follow[0]
			desired_mag = follow[1]
			want_sprint = follow[2]
		else:
			# Pelota propia que se adelanto en el rumbo pedido: se corre lo necesario para alcanzarla aunque el joystick pida
			# poca velocidad (al frenar con la pelota rodando o tras un toque largo); al llegar manda de nuevo el joystick.
			desired_mag = maxf(desired_mag, ball_handler.carry_catch_up_mag(desired_dir))

	# Golpeo pedido que espera a que se libere el bloqueo (tras un movimiento con pelota) con la pelota al pie: pasos cortos
	# sobre ella, sin dejarla atras.
	if not is_pressing and ball_handler.holding_for_kick():
		desired_mag = minf(desired_mag, 0.2)
		want_sprint = false

	# Golpeo pedido con la pelota propia por delante fuera del alcance del pie: se ajusta la carrera y se va a por ella
	# (la direccion del golpeo sigue siendo la del joystick; solo cambia hacia donde corre el cuerpo).
	var approach: Array = [] if is_pressing else ball_handler.kick_approach_steer()
	if not approach.is_empty():
		desired_dir = approach[0]
		desired_mag = approach[1]
		want_sprint = want_sprint or approach[2]

	# Patada con clip en curso: el jugador ya se comprometio con el golpeo. El joystick no lo gira ni lo acelera (el
	# giro sigue la direccion del inicio, reducido por kick_turn_scale) y la velocidad la fija el balanceo.
	var kicking: bool = ball_handler.is_clip_kick_in_progress()
	if kicking:
		desired_dir = ball_handler.kick_desired_dir
		desired_mag = ball_handler.kick_desired_mag
		want_sprint = false
	else:
		# Girar CON la pelota: el cuerpo no puede dejarla a la espalda antes de tocarla hacia el rumbo nuevo.
		locomotion.turn_scale = ball_handler.carry_turn_scale(desired_dir)

	# Marcaje en jockey: cerca del portador rival mira hacia el y se mueve en cualquier direccion.
	# Con la pelota, el mismo mecanismo sirve para el control lateral y para proteger el balon de espaldas al rival.
	locomotion.face_override = Vector3.ZERO
	if is_pressing and press_info.carrier != null:
		var to_c: Vector3 = KickModel.flat(press_info.carrier.global_position - global_position)
		if to_c.length() < JOCKEY_RANGE and to_c.length() > 0.5:
			locomotion.face_override = to_c.normalized()
	elif receive_face != Vector3.ZERO and not kicking:
		# Colocandose para una recepcion con clip: el cuerpo sigue mirando como cuando se calculo el sitio (se desplaza de lado
		# o hacia atras sin darse la vuelta); si se girara hacia donde camina, al llegar el clip ya no encajaria.
		locomotion.face_override = receive_face
	elif not kicking:
		var carry_face: Vector3 = ball_handler.plan_carry(desired_dir, stick_mag if settling_close else desired_mag, delta)
		if carry_face.length_squared() > 0.01:
			locomotion.face_override = carry_face
		elif settle_face.length_squared() > 0.01:
			# Acomodandose a la pelota (joystick suelto): de frente a ella, girando en el sitio si esta pegada.
			locomotion.face_override = settle_face

	# Conduciendo la pelota se corre algo mas lento (y menos con peor conduccion).
	var cap: float = -1.0
	# Tope de conduccion solo con la pelota al pie: si el toque se fue largo, el jugador acelera para alcanzarla.
	# Yendo a golpear la pelota propia que se adelanto (kick_approach_steer) no hay tope: si no, nunca la alcanza.
	if ball_handler.is_dribbling() and ball_handler.ball_distance() <= ball_handler.possession_radius() and approach.is_empty():
		cap = ball_handler.dribble_speed_cap()
	var speed_before: float = locomotion.speed
	var kick_input: bool = frame.pass_held or frame.shoot_held or frame.through_held or frame.cross_held \
		or frame.pass_pressed or frame.shoot_pressed or frame.through_pressed or frame.cross_pressed \
		or frame.pass_released or frame.shoot_released or frame.through_released or frame.cross_released
	if PackLibrary.json_mode() and not is_pressing and not kicking and not kick_input and not (want_sprint and speed_before < 0.6):
		_json_turn_move(desired_dir, desired_mag, delta, stick_mag)
	# Vuelta atras pisando la pelota o giro con toques en curso: el cuerpo lo mueve la accion (llegar, frenar, girar, salir).
	var scripted: Dictionary = ball_handler.drag_back.body_control()
	if scripted.is_empty():
		scripted = ball_handler.ball_turn.body_control()
	if not scripted.is_empty():
		locomotion.face_override = Vector3.ZERO
		locomotion.step_scripted(scripted["face"], scripted["rate"], scripted["sign"], scripted["vel"], scripted["accel"], delta)
	else:
		locomotion.step(desired_dir, desired_mag, want_sprint, delta, cap)
	if kicking:
		locomotion.velocity = ball_handler.kick_body_velocity()
		locomotion.speed = locomotion.velocity.length()
		# Golpeo girando (modo 4): el cuerpo gira con el clip hasta el contacto.
		var kyaw: float = ball_handler.kick_body_yaw()
		if not is_nan(kyaw):
			locomotion.turn_rate = wrapf(kyaw - locomotion.yaw, -PI, PI) / maxf(delta, 0.001)
			locomotion.yaw = kyaw
	_gait_overlays(desired_dir, want_sprint, stick_mag, speed_before, delta)

	velocity.x = locomotion.velocity.x + nudge_velocity.x
	velocity.z = locomotion.velocity.z + nudge_velocity.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 9.81 * delta
	Prof.begin(&"cuerpo (move_and_slide)")
	move_and_slide()
	Prof.end(&"cuerpo (move_and_slide)")
	Prof.begin(&"choques entre jugadores")
	_check_player_collisions()
	Prof.end(&"choques entre jugadores")
	# Las colisiones (paredes, otros jugadores) corrigen la velocidad real.
	locomotion.velocity = Vector3(velocity.x - nudge_velocity.x, 0.0, velocity.z - nudge_velocity.z)
	rotation.y = locomotion.yaw

	Prof.begin(&"pelota (BallHandler)")
	ball_handler.update(frame, stick_world, stick_mag, intent_dir, delta)
	Prof.end(&"pelota (BallHandler)")
	if incoming_pass_time > 0.0 and ball_handler.has_possession():
		incoming_pass_time = 0.0
	if visual != null:
		_update_reaction(delta)
		visual.directional = locomotion.jockeying
		visual.carrying = ball_handler.is_dribbling()
		visual.dir_velocity = Vector2(locomotion.forward_speed, locomotion.lateral_speed)
		Prof.begin(&"visual (update_motion)")
		visual.update_motion(self, delta)
		Prof.end(&"visual (update_motion)")

# --- Transiciones de marcha con clips del pack ----------------------------------------------------------------

## Clips de transicion sobre la marcha (todos se cortan en cuanto el movimiento real deja de corresponderles):
##  - Idle_To_Sprint: arranque explosivo desde parado con sprint pedido.
##  - Sprint_Turn: cambio de rumbo a la carrera hacia la derecha (el clip gira a ese lado).
##  - Running_Tired (tramo final): se para agotado a recuperar el aliento.
const IDLE_TO_SPRINT := &"Idle_To_Sprint"
const SPRINT_TURN := &"Sprint_Turn"
const TIRED_STOP := &"Running_Tired"
const TIRED_STOP_FROM := 2.0
var _overlay_cd: float = 0.0

## Modo 4: gestos de espera (clips de pie y escenas de espera) tras IDLE_FIDGET_AFTER s quieto sin la pelota cerca.
const IDLE_FIDGET_AFTER := 3.5
const IDLE_FIDGET_BALL_DIST := 7.0
var _idle_t: float = 0.0
var _fidget: StringName = &""

func _json_idle(stick_mag: float, delta: float) -> void:
	var ball_near: bool = ctx.ball != null and KickModel.flat(ctx.ball.global_position - global_position).length() < IDLE_FIDGET_BALL_DIST
	if locomotion.speed > 0.25 or stick_mag > 0.2 or ball_near:
		_idle_t = 0.0
		return
	_idle_t += delta
	if _idle_t > IDLE_FIDGET_AFTER + float(actor_id % 4):
		_idle_t = -2.0
		var c: StringName = JsonCatalog.situation_clip(&"idle_fidget", actor_id)
		if c != &"" and arbiter.play(&"idle_fidget", ActionArbiter.Level.GESTURE, &"Footballer", c, 1.0, 0.0, 4.5, true) != 0:
			_fidget = c

## Modo 4: giros sin pelota con los clips de giro (de parado o en carrera, 90 a 180 grados): el cuerpo gira y arranca con el
## clip (raiz y rumbo) en vez de rotar en el sitio. Solo lejos de la pelota (JSON_TURN_BALL_DIST): cerca manda la jugada.
const JSON_TURN_MIN := 100.0
const JSON_TURN_TOL := 35.0
const JSON_TURN_BALL_DIST := 6.0
const JSON_TURN_COOLDOWN := 2.5
const JSON_TURN_COOLDOWN_AI := 4.0
const JSON_TURN_SPEED_AI := 1.3
var _turn_cd: float = 0.0
var _transition_input_started: bool = false

func _json_turn_move(desired_dir: Vector3, desired_mag: float, delta: float, input_mag: float) -> void:
	_turn_cd = maxf(_turn_cd - delta, 0.0)
	if input_mag >= 0.2:
		_transition_input_started = true
	elif locomotion.speed < 0.2:
		_transition_input_started = false
	# Los pasos automaticos de recepcion/acomodo no son una orden de locomocion nueva.
	var transition_intent: bool = input_mag >= 0.2 or (_transition_input_started and desired_mag < 0.2)
	if transition_intent and _turn_cd <= 0.0 and actions.try_locomotion_transition(desired_dir, input_mag):
		_turn_cd = JSON_TURN_COOLDOWN if is_human_controlled else JSON_TURN_COOLDOWN_AI
		return
	if _turn_cd > 0.0 or desired_mag < 0.5 or desired_dir.length_squared() < 0.01 or not actions.can_start(&"turn") or ball_handler.has_possession():
		return
	if ctx.ball == null or KickModel.flat(ctx.ball.global_position - global_position).length() < JSON_TURN_BALL_DIST or has_incoming_pass():
		return
	var spd: float = locomotion.speed
	var role: StringName = &"turn_start" if spd < 1.3 else (&"turn_run" if spd >= 2.2 and spd <= 5.6 else &"")
	# La IA: solo los giros desde parado (los de carrera la frenaban: en un partido de IA, 41 giros de clip en 90 s).
	if role == &"" or (role == &"turn_run" and not is_human_controlled):
		return
	var ang: float = rad_to_deg(wrapf(Locomotion.yaw_from_dir(desired_dir.normalized()) - locomotion.yaw, -PI, PI))
	if absf(ang) < JSON_TURN_MIN:
		return
	_turn_cd = JSON_TURN_COOLDOWN if is_human_controlled else JSON_TURN_COOLDOWN_AI
	var best: StringName = &""
	var best_s: float = INF
	var dec: Dictionary = AnimTrace.begin(self, &"turn", &"Footballer._json_turn_move", "%s %.0f grados" % [role, ang]) if AnimTrace.enabled else {}
	for id in PackLibrary.by_role(role):
		var m: Dictionary = PackLibrary.meta(id)
		var turn: float = rad_to_deg(ActionMotion.heading_rel(m.get("heading_path", PackedFloat32Array()), float(m.get("duration", 1.0))))
		var dturn: float = absf(turn - ang)
		var dv: float = absf(float(m.get("v_in", 0.0)) - spd)
		if dturn > JSON_TURN_TOL or dv > 1.6:
			if not dec.is_empty():
				AnimTrace.cand(dec, id, ("giro del clip %.0f grados frente a %.0f" % [turn, ang]) if dturn > JSON_TURN_TOL else ("carrera de entrada %.1f m/s frente a %.1f m/s" % [float(m.get("v_in", 0.0)), spd]),
					{"angular_error_deg": dturn, "v_in": spd, "v_clip": float(m.get("v_in", 0.0))})
			continue
		var s: float = dturn / JSON_TURN_TOL + 0.3 * dv + actions.rng.randf() * 0.3
		if not dec.is_empty():
			AnimTrace.cand(dec, id, "", {"angular_error_deg": dturn, "v_in": spd, "v_clip": float(m.get("v_in", 0.0)), "orient_start": rad_to_deg(locomotion.yaw),
				"orient_target": rad_to_deg(locomotion.yaw) + ang, "cost_total": s, "cost_breakdown_json": {"giro": dturn / JSON_TURN_TOL, "carrera": 0.3 * dv}})
		if s < best_s:
			best_s = s
			best = id
	var turned: bool = best != &"" and actions.start_move(&"turn", best, 1.15 if is_human_controlled else JSON_TURN_SPEED_AI)
	if not dec.is_empty():
		AnimTrace.commit(dec, best, {}, "accepted" if turned else "rejected", "" if turned else ("ningun giro compatible" if best == &"" else "arbitro o clip no reproducible"))
	if turned:
		actions.stats["turns"] = int(actions.stats.get("turns", 0)) + 1
var _tired_cd: float = 0.0

## Quita la componente que saca al jugador mas alla de las lineas (con medio metro de margen).
func _keep_inside(dir: Vector3) -> Vector3:
	var cfg: PitchConfig = ctx.pitch.config
	var p: Vector3 = global_position
	var out: Vector3 = dir
	if absf(p.x) > cfg.half_length() - 0.2 and signf(dir.x) == signf(p.x):
		out.x = 0.0
	if absf(p.z) > cfg.half_width() - 0.2 and signf(dir.z) == signf(p.z):
		out.z = 0.0
	return out.normalized() if out.length_squared() > 0.0001 else Vector3.ZERO

## La IA no disputa en cada ocasion: contiene (jockey) y entra cuando la pelota queda expuesta (toque largo del
## portador, pelota suelta) o, con el portador protegiendola, solo de vez en cuando. Asi el portador tiene tiempo de
## jugar y la posesion no cambia a cada segundo.
func _ai_commits_tackle(carrier: Footballer) -> bool:
	if carrier == null:
		return true
	if carrier.ball_handler.ball_distance() > 0.75:
		return true
	return actions.rng.randf() < AI_TACKLE_COMMIT

## El boton REGATE pide la vuelta pisando la pelota cuando el joystick apunta hacia atras (>= DragBack.MIN_ANGLE grados
## del frente) con la pelota al pie.
func _skill_is_drag_back(frame: InputFrame) -> bool:
	if frame.move_length() < DragBack.MIN_STICK or not ball_handler.has_possession():
		return false
	var w: Vector3 = frame.move_world if frame.use_world else ctx.screen_to_world(frame.move)
	return KickModel.angle_between_deg(locomotion.forward(), KickModel.flat(w).normalized()) >= DragBack.MIN_ANGLE - 15.0

## Modo 4: un clip de accion que el cuerpo deja atras (gesto de entrada, forcejeo, recepcion, tropiezo en el sitio) mientras
## el jugador corre a mas de SLIDE_CUT_SPEED m/s por encima de la carrera del propio clip durante SLIDE_CUT_TIME s se corta:
## si no, el jugador se desliza con las piernas quietas. Los clips que mueven al cuerpo (PlayerActions) y los golpeos no.
const SLIDE_CUT_SPEED := 1.8
const SLIDE_CUT_TIME := 0.15
var _slide_t: float = 0.0

func _json_clip_slides(cur: StringName, delta: float) -> bool:
	# Solo gestos y capas: las acciones con raiz y el golpeo mueven el cuerpo con su clip.
	if cur == &"" or not visual.json_mode or arbiter.current_level() > ActionArbiter.Level.OVERLAY:
		_slide_t = 0.0
		return false
	_slide_t = _slide_t + delta if locomotion.speed - ActionArbiter.clip_speed(cur) > SLIDE_CUT_SPEED else 0.0
	if _slide_t >= SLIDE_CUT_TIME:
		_slide_t = 0.0
		return true
	return false

func _gait_overlays(desired_dir: Vector3, want_sprint: bool, stick_mag: float, speed_before: float, delta: float) -> void:
	_overlay_cd = maxf(_overlay_cd - delta, 0.0)
	_tired_cd = maxf(_tired_cd - delta, 0.0)
	if visual == null or not visual.uses_pack or visual.is_placeholder:
		return
	var cur: StringName = visual.current_action
	# Cortes: el clip deja de valer si el cuerpo ya no hace lo que muestra.
	if cur == TIRED_STOP and locomotion.speed > 1.0:
		arbiter.cut_pose("cansado y en marcha")
	elif cur == SPRINT_TURN and locomotion.speed < 2.5:
		arbiter.cut_pose("giro en sprint sin sprint")
	elif cur == IDLE_TO_SPRINT and stick_mag < 0.3:
		arbiter.cut_pose("arranque sin joystick")
	elif cur != &"" and cur == _fidget and (locomotion.speed > 0.5 or stick_mag > 0.3):
		arbiter.cut_pose("espera interrumpida")
	elif _json_clip_slides(cur, delta):
		arbiter.cut_pose("pose en el sitio con el cuerpo corriendo")
	if arbiter.current_level() != ActionArbiter.Level.NONE or ball_handler.has_possession():
		_idle_t = 0.0
		return
	if PackLibrary.json_mode():
		_json_idle(stick_mag, delta)
	if _tired_cd <= 0.0 and locomotion.exhausted and locomotion.speed < 0.4 and speed_before < 0.6 and PackLibrary.has_clip(TIRED_STOP):
		# Modo 4: el clip JSON (manos en la cintura) empieza en su principio; el del pack, en su tramo de recuperar el aliento.
		var tired_from: float = 0.0 if PackLibrary.json_mode() else TIRED_STOP_FROM
		if arbiter.play(&"tired_stop", ActionArbiter.Level.OVERLAY, &"Footballer", TIRED_STOP, 1.0, tired_from, 2.6, true) != 0:
			_tired_cd = 7.0
		return
	if _overlay_cd > 0.0:
		return
	if want_sprint and stick_mag > 0.8 and speed_before < 0.6 and locomotion.speed < 1.5:
		if arbiter.play(&"idle_to_sprint", ActionArbiter.Level.OVERLAY, &"Footballer", IDLE_TO_SPRINT, 1.0, 0.0, 0.55) != 0:
			_overlay_cd = 1.5
		return
	if locomotion.sprinting and locomotion.speed > 4.5 and desired_dir.length_squared() > 0.01:
		var turn: float = rad_to_deg(wrapf(Locomotion.yaw_from_dir(desired_dir.normalized()) - locomotion.yaw, -PI, PI))
		# yaw decreciente = giro a la derecha.
		if turn < -35.0 and turn > -110.0:
			if arbiter.play(&"sprint_turn", ActionArbiter.Level.OVERLAY, &"Footballer", SPRINT_TURN, 1.2, 0.0, 0.6) != 0:
				_overlay_cd = 3.0
			return

# --- Reacciones de presentacion a eventos del partido --------------------------------------------

func _cancel_reaction() -> void:
	_reaction = &""
	# Solo gestos y capas: una caida o un golpeo en curso no se cortan por un evento del partido.
	if arbiter != null:
		arbiter.cut_pose("reaccion cancelada")

## Reacciones de presentacion a eventos del partido:
##  - Gol: el goleador, el asistente, el resto del equipo y el rival reaccionan distinto (un autor de gol en contra
##    es del equipo que recibe: se lamenta). Cada uno elige un clip distinto del catalogo segun su id.
##  - Primer toque lento: gesto de recepcion. Saque: corta reacciones; el primero de la presentacion, calentamiento.
##  - Fin del partido: ganadores, perdedores o empate.
func _on_match_event(e: GameEvent) -> void:
	if visual == null or visual.is_placeholder:
		return
	match e.type:
		GameEvent.Type.GOAL:
			var own: bool = bool(e.data.get("own_goal", false))
			if e.team != team:
				_set_reaction(&"dejected", 0.4, REACTION_MAX_SECONDS)
			elif e.actor_id == actor_id and not own:
				_set_reaction(&"celebrate_scorer", 0.3, REACTION_MAX_SECONDS)
			elif int(e.data.get("assist", -1)) == actor_id:
				_set_reaction(&"thumbs_up", 0.5, REACTION_MAX_SECONDS)
			else:
				_set_reaction(&"celebrate_team", 0.4, REACTION_MAX_SECONDS)
		GameEvent.Type.MATCH_END:
			var sc: Array = e.data.get("score", [0, 0])
			var mine: int = int(sc[team]) if sc.size() == 2 else 0
			var theirs: int = int(sc[1 - team]) if sc.size() == 2 else 0
			_set_reaction(&"victory_end" if mine > theirs else (&"defeat_end" if mine < theirs else &"draw_end"), 0.4, 6.0)
		GameEvent.Type.KICKOFF:
			_cancel_reaction()
			if bool(e.data.get("intro", false)):
				_set_reaction(&"warmup", rng_delay(), maxf(float(e.data.get("seconds", 3.0)) - 0.6, 1.0))
		GameEvent.Type.RESTART, GameEvent.Type.MATCH_START:
			_cancel_reaction()
		GameEvent.Type.SET_PIECE:
			# Modo 4: tiro libre en contra cerca de este jugador: se planta como barrera (clips de barrera del JSON).
			if PackLibrary.json_mode() and e.team != team and String(e.data.get("kind", "")) == "free_kick":
				var sp: Array = e.data.get("pos", [0.0, 0.0])
				if Vector2(global_position.x - float(sp[0]), global_position.z - float(sp[1])).length() < 12.0:
					_set_reaction(&"wall", 1.2 + rng_delay(), 5.0)
		GameEvent.Type.FIRST_TOUCH:
			if e.actor_id == actor_id and locomotion.speed <= RECEIVE_MAX_SPEED:
				# Pelota que llega rapida: control con el cuerpo (Receive); suave: control con el pie (receive_soccerball).
				var soft: bool = float(e.data.get("incoming_speed", 9.0)) < 6.0
				arbiter.play_situation(&"receive", ActionArbiter.Level.GESTURE, &"Footballer", 1 if soft else 0, 1.0, RECEIVE_MAX_SECONDS)
		GameEvent.Type.SHOT:
			_try_block_jump(e)

## Bloqueo: un defensor en la linea del disparo, cerca del que patea, salta para tapar (Defender_2). El bloqueo real lo
## hace su cuerpo (la capsula) si la pelota le pega; el salto es la reaccion visible a un tiro que le viene encima.
const BLOCK_CLIP := &"Defender_2"
func _try_block_jump(e: GameEvent) -> void:
	if e.team == team or not arbiter.can_start(ActionArbiter.Level.OVERLAY) or ctx.ball == null or not PackLibrary.has_clip(BLOCK_CLIP):
		return
	var b: Ball = ctx.ball
	var d: Array = e.data.get("dir", [0.0, 0.0])
	var v := Vector3(float(d[0]), 0.0, float(d[1])) * float(e.data.get("speed", 0.0))
	if v.length() < 4.0:
		return
	var to_me: Vector3 = KickModel.flat(global_position - b.global_position)
	var along: float = to_me.dot(v.normalized())
	var off_line: float = (to_me - v.normalized() * along).length()
	if along > 0.6 and along < 6.0 and off_line < 1.4:
		if arbiter.play(&"block_jump", ActionArbiter.Level.OVERLAY, &"Footballer", BLOCK_CLIP, 1.4, 0.0, 0.85) != 0:
			locomotion.face_towards(-v, 1.0, 360.0)

func rng_delay() -> float:
	return float(actor_id % 5) * 0.12

func _set_reaction(situation: StringName, wait: float, cut: float) -> void:
	_reaction = situation
	_reaction_wait = wait
	_reaction_cut = cut

## La reaccion a un gol arranca cuando el jugador casi se ha detenido (o tras REACTION_MAX_WAIT) para no animar un
## clip en el sitio sobre un cuerpo que aun corre.
func _update_reaction(delta: float) -> void:
	if _reaction == &"":
		return
	_reaction_wait -= delta
	if _reaction_wait > 0.0 or (locomotion.speed > REACTION_START_SPEED and _reaction_wait > -REACTION_MAX_WAIT) or not arbiter.can_start(ActionArbiter.Level.GESTURE):
		return
	var sit: StringName = _reaction
	_reaction = &""
	# Pose en el sitio: si el jugador sigue corriendo (paso REACTION_MAX_WAIT) el arbitro la rechaza en vez de deslizarlo.
	arbiter.play_situation(sit, ActionArbiter.Level.GESTURE, &"Footballer", actor_id + int(ctx.match_time), 1.0, _reaction_cut)

var _collision_cd: float = 0.0

## Un choque a velocidad con otro jugador provoca un tropiezo (presentacion) o, si es fuerte, un golpe de hombro y caida.
func _check_player_collisions() -> void:
	_collision_cd = maxf(_collision_cd - get_physics_process_delta_time(), 0.0)
	if _collision_cd > 0.0 or actions.active():
		return
	for i in get_slide_collision_count():
		var other: Footballer = get_slide_collision(i).get_collider() as Footballer
		if other == null:
			continue
		var rel: float = (velocity - other.velocity).length()
		if rel < 3.2:
			continue
		_collision_cd = 3.0
		# Solo reacciona el mas lento (el que recibe el golpe).
		if locomotion.speed > other.locomotion.speed + 0.3:
			return
		if rel > 5.5 and actions.rng.randf() < 0.3:
			actions.suffer_contact(&"hit", KickModel.flat(global_position - other.global_position))
		else:
			actions.stumble()
		return

## Datos replicables del jugador (para snapshots de red / pruebas).
func capture_state() -> Dictionary:
	return {
		"id": actor_id, "team": team,
		"pos": [global_position.x, global_position.y, global_position.z],
		"vel": [velocity.x, velocity.y, velocity.z],
		"yaw": locomotion.yaw if locomotion != null else 0.0,
		"stamina": locomotion.stamina if locomotion != null else 1.0,
	}
