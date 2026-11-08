class_name MatchScene
extends Node3D
## Raiz de composicion del partido: cancha, pelota, camara, equipos, reglas y HUD.
## Esta pensada para crecer (5 jugadores por equipo, IA, sustituciones) sin cambiar el resto.

signal quit_requested

## Duracion del partido (s). Negativo = la que eligio la persona (3, 5, 7 o 10 minutos, ver Tuning.match_minutes).
@export var duration_seconds: float = -1.0
## Cantidad de futbolistas de campo por equipo en esta etapa (1 = etapa inicial).
@export var home_field_players: int = 4
@export var away_field_players: int = 4
## Cambia solo al jugador del humano mas cercano a la pelota cuando el actual queda lejos.
@export var auto_switch: bool = true
## Calidad de decision de la IA (0..1).
@export var ai_skill: float = 0.6
## Presentacion antes del primer saque (s): calentamiento de los jugadores y arbitro contando. 0 = sin presentacion.
@export var intro_seconds: float = 4.5
@export var with_referee: bool = true
## Reglas de futbol con bandas: la pelota sale y se repone (saque de banda, corner, saque de arco). Con false, cancha
## cerrada con paredes (la pelota rebota y nunca sale).
@export var out_of_bounds: bool = true
var referee: Referee = null
## Repeticion de los goles (graba siempre; se muestra tras cada gol).
var replay: GoalReplay = null
@export var goal_replays: bool = true
## Entrenamiento: tu equipo (con su arquero) contra el arquero rival SOLO, sin rivales de campo ni reloj, para probar
## conduccion, pases y tiros al arco. Se elige en el menu de pausa y se mantiene al reiniciar la escena.
static var training_mode: bool = false

var ctx: MatchContext
var pitch: Pitch
var ball: Ball
var camera: MatchCamera
var manager: MatchManager
var presentation: MatchPresentation = null
var hud: Hud
var controlled: Footballer = null
var home: Array[Footballer] = []
var away: Array[Footballer] = []
var keepers: Array[Goalkeeper] = []
## Indicadores sobre el jugador controlado y sobre el que recibiria el control con CAMBIO.
var marker: PlayerMarker = null
var next_marker: PlayerMarker = null
## Aro de posesion (bajo el unico jugador con la pelota) y aro del companero que recibiria el pase ahora.
var possession_ring: GroundRing = null
var pass_ring: GroundRing = null
const RING_COLORS: Array[Color] = [Color(1.0, 0.35, 0.3, 0.9), Color(1.0, 0.86, 0.2, 0.9)]
## Arquero propio bajo control de la persona (null = lo lleva la IA). Mientras lo maneja, el jugador de campo
## `controlled` queda en manos de la IA pero se recuerda para devolverle el control.
var controlled_keeper: Goalkeeper = null
## Overlay de depuracion de animaciones (solo compilaciones de depuracion; null en la APK de produccion).
var debug_overlay: AnimDebugOverlay = null
## Con false no se crean arqueros (algunas pruebas y la practica los omiten).
@export var with_keepers: bool = true

const BALL_SCENE := preload("res://scenes/ball/ball.tscn")
const FOOTBALLER_SCENE := preload("res://scenes/player/footballer.tscn")

func _ready() -> void:
	if duration_seconds < 0.0:
		duration_seconds = float(Tuning.match_minutes) * 60.0
	if training_mode:
		away_field_players = 0
		duration_seconds = 0.0
		intro_seconds = 0.0
	ctx = MatchContext.new()
	pitch = Pitch.new()
	pitch.name = "Pitch"
	add_child(pitch)
	var cfg: PitchConfig = Tuning.pitch.duplicate() as PitchConfig
	cfg.boundary_mode = PitchConfig.BoundaryMode.OUT_OF_BOUNDS if out_of_bounds else PitchConfig.BoundaryMode.WALLS
	pitch.build(cfg)
	ball = BALL_SCENE.instantiate()
	ball.name = "Ball"
	add_child(ball)
	ball.position = Vector3(0.0, 0.2, 0.0)
	ctx.ball = ball
	ctx.pitch = pitch
	pitch.set_ball(ball)
	camera = MatchCamera.new()
	camera.name = "MatchCamera"
	add_child(camera)
	ctx.camera = camera
	camera.ctx = ctx
	_spawn_teams()
	if with_referee:
		referee = Referee.new()
		referee.name = "Referee"
		add_child(referee)
		# Con bandas el arbitro corre por fuera de la linea; con paredes, por dentro junto a la pared.
		referee.setup(ctx, Vector3(-2.0, 0.0, Tuning.pitch.width * 0.5 + (1.1 if out_of_bounds else -0.9)))
	manager = MatchManager.new()
	manager.name = "MatchManager"
	manager.duration_seconds = duration_seconds
	manager.training = training_mode
	manager.intro_seconds = intro_seconds
	add_child(manager)
	manager.setup(ctx)
	if PackLibrary.json_mode() and not training_mode:
		presentation = MatchPresentation.new()
		presentation.name = "MatchPresentation"
		add_child(presentation)
		presentation.setup(ctx)
	manager.kickoff_requested.connect(_on_kickoff_requested)
	manager.set_piece_requested.connect(_on_set_piece_requested)
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.bind(manager)
	# Depuracion de animaciones (Fase 1): registro de decisiones y overlay. Nunca en la APK de produccion.
	AnimTrace.configure_from_environment()
	if AnimTrace.allowed():
		debug_overlay = AnimDebugOverlay.new()
		debug_overlay.name = "AnimDebugOverlay"
		add_child(debug_overlay)
		debug_overlay.setup(self)
	hud.charge_provider = _charge_state
	hud.restart_play_requested.connect(func() -> void: manager.restart_play())
	hud.restart_match_requested.connect(func() -> void: manager.restart_match())
	hud.gameplay_mode_changed.connect(_on_gameplay_mode_changed)
	hud.quit_requested.connect(_on_quit_requested)
	hud.practice_requested.connect(_on_practice_requested)
	hud.training_toggle_requested.connect(_on_training_toggle)
	if training_mode:
		hud.show_message("ENTRENAMIENTO: sin rivales, solo su arquero", 3.0)
	marker = PlayerMarker.make(true)
	add_child(marker)
	next_marker = PlayerMarker.make(false)
	add_child(next_marker)
	possession_ring = GroundRing.make("PossessionRing", RING_COLORS[0], 0.62, 0.11)
	add_child(possession_ring)
	pass_ring = GroundRing.make("PassTargetRing", Color(1.0, 1.0, 1.0, 0.75), 0.55, 0.06)
	add_child(pass_ring)
	camera.setup(ball, controlled, Tuning.pitch)
	_setup_replay()
	ctx.event_emitted.connect(_on_match_event)
	# Sonido: golpes, botes, poste y red de la pelota; silbatos y publico del partido (Sfx).
	Sfx.watch_ball(ball)
	ctx.event_emitted.connect(Sfx.on_event)
	Sfx.crowd(true)
	camera.watch_shots(ball)
	GraphicsSettings.apply()
	# Datos fijos de los clips de recepcion (modo 4) y de atajada calculados ahora y no en la primera pelota que llega (tirones).
	if PackLibrary.json_mode():
		JsonReceive.warm_cache()
	KeeperPlanner.warm_cache()
	manager.start_match()

## Rol tactico (0 cierre, 1 ala izquierda, 2 ala derecha, 3 pivote) segun el puesto en la formacion de saque.
const ROLES_BY_SLOT := [3, 1, 2, 0]
## Distancia (m) al centro del ejecutor del saque y del rival mas adelantado (radio del circulo central).
const KICKOFF_TAKER_X := 0.62
const KICKOFF_WAIT_X := 3.4

func _spawn_teams() -> void:
	var next_id: int = 1
	for i in home_field_players:
		var role: int = ROLES_BY_SLOT[mini(i, ROLES_BY_SLOT.size() - 1)]
		var f: Footballer = _make_footballer(0, next_id, HumanInput.new() if i == 0 else AIInput.new(role, ai_skill))
		f.set_meta("ai_role", role)
		_seed_ai(f, next_id)
		home.append(f)
		next_id += 1
	for i in away_field_players:
		var role2: int = ROLES_BY_SLOT[mini(i, ROLES_BY_SLOT.size() - 1)]
		var f2: Footballer = _make_footballer(1, next_id, AIInput.new(role2, ai_skill))
		f2.set_meta("ai_role", role2)
		_seed_ai(f2, next_id)
		away.append(f2)
		next_id += 1
	if home.size() > 0:
		controlled = home[0]
		controlled.is_human_controlled = true
	if with_keepers:
		for team_index in 2:
			var k := Goalkeeper.new()
			k.name = "Goalkeeper_%d" % team_index
			add_child(k)
			var kattrs := PlayerAttributes.new()
			kattrs.reset_to(60)
			k.setup(ctx, team_index, next_id, kattrs)
			next_id += 1
			keepers.append(k)

func _seed_ai(f: Footballer, id: int) -> void:
	if f.input_source is AIInput:
		(f.input_source as AIInput).rng.seed = 9100 + id * 131

func _make_footballer(team: int, id: int, source: InputSource) -> Footballer:
	var f: Footballer = FOOTBALLER_SCENE.instantiate()
	f.name = "Footballer_%d" % id
	add_child(f)
	var attrs := PlayerAttributes.new()
	attrs.reset_to(55)
	f.setup(ctx, team, id, attrs, source)
	return f

func _exit_tree() -> void:
	Sfx.crowd(false)

## Con el partido como escena actual, «Salir» cierra el juego; si lo aloja otro nodo (pruebas) solo avisa.
func _on_quit_requested() -> void:
	quit_requested.emit()
	if get_tree().current_scene == self:
		get_tree().quit()

## Cambia entre partido normal y entrenamiento y vuelve a montar la escena.
func _on_training_toggle() -> void:
	training_mode = not training_mode
	if get_tree().current_scene == self:
		get_tree().paused = false
		get_tree().reload_current_scene()

## Otro modo de jugabilidad: se vuelve a montar la escena (modelos y clips del modo).
func _on_gameplay_mode_changed() -> void:
	if get_tree().current_scene == self:
		get_tree().paused = false
		get_tree().reload_current_scene()

## Abre la sala de practica (galeria de animaciones y malabares) y vuelve aqui con «Volver».
func _on_practice_requested() -> void:
	if get_tree().current_scene == self:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/practice/practice.tscn")

## Formacion de saque: 4 jugadores de campo por equipo (cierre, alas, pivote); los arqueros van a su arco.
## El equipo que saca coloca a su pivote JUNTO a la pelota, para poder jugarla de inmediato, y el rival respeta el
## circulo central: si no, el saque queda vacio y nadie toca el balon hasta que alguien llega corriendo.
func kickoff_positions(team: int, kicking: bool = true) -> Array[Vector3]:
	var sign_x: float = -1.0 if team == 0 else 1.0
	var out: Array[Vector3] = []
	out.append(Vector3(sign_x * (KICKOFF_TAKER_X if kicking else KICKOFF_WAIT_X), 0.0, 0.0))
	out.append(Vector3(sign_x * 6.0, 0.0, -4.5))
	out.append(Vector3(sign_x * 6.0, 0.0, 4.5))
	out.append(Vector3(sign_x * 11.0, 0.0, 0.0))
	return out

func _on_kickoff_requested(kicking_team: int) -> void:
	for f in home + away:
		f.set_piece = null
	ball.reset_at(Vector3(0.0, 0.11, 0.0))
	for team_list in [home, away]:
		var team_index: int = 0 if team_list == home else 1
		var positions: Array[Vector3] = kickoff_positions(team_index, team_index == kicking_team)
		var yaw: float = Locomotion.yaw_from_dir(Vector3(1.0 if team_index == 0 else -1.0, 0.0, 0.0))
		for i in team_list.size():
			(team_list[i] as Footballer).place_at(positions[mini(i, positions.size() - 1)], yaw)
	if camera != null:
		camera.snap_to_target()

# --- Repeticion de goles ------------------------------------------------------------------------------------

func _setup_replay() -> void:
	replay = GoalReplay.new()
	replay.name = "GoalReplay"
	add_child(replay)
	var tracked: Array[Node3D] = []
	for f in home + away:
		tracked.append(f)
	for k in keepers:
		tracked.append(k)
	if referee != null:
		tracked.append(referee)
	replay.setup(ctx, tracked, camera)
	replay.enabled = goal_replays
	if hud != null:
		hud.replay_skip = func() -> void: replay.skip()
	manager.goal_scored.connect(func(_t: int, _s: int, _a: int, _o: bool) -> void: replay.mark_goal())
	manager.replay_requested.connect(_on_replay_requested)
	replay.started.connect(func() -> void:
		manager.replay_active = true
		if hud != null:
			hud.show_replay(true))
	replay.finished.connect(func(_skipped: bool) -> void:
		manager.replay_active = false
		if hud != null:
			hud.show_replay(false))

## Comprobacion de coherencia (pruebas): el marcador suma los goles del partido.
func score_total_consistent() -> bool:
	return manager.score[0] >= 0 and manager.score[1] >= 0

func _on_replay_requested() -> void:
	if replay != null and goal_replays:
		replay.start()

# --- Balon parado -----------------------------------------------------------------------------------------

## Distancia (m) que deben respetar los rivales al balon parado (futsal: 5 m).
const SET_PIECE_DISTANCE := 5.0

## Prepara un balon parado: ejecutor (el mas cercano del equipo que saca; el arquero en el saque de arco), pelota en
## su sitio y rivales a distancia. En corner, tiro libre cercano y penal, los demas se ordenan como en una jugada
## ensayada (atacantes al area, defensores marcando). La pelota esta muerta: reubicar jugadores es legal.
func _on_set_piece_requested(kind: String, team: int, pos: Vector3) -> void:
	for f in home + away:
		f.set_piece = null
		f.incoming_pass_time = 0.0
		f.ball_handler.cancel_charge()
		f.ball_handler.abort_kick()
	var cfg: PitchConfig = pitch.config
	var gx: float = cfg.half_length() * (1.0 if team == 0 else -1.0)   # arco que ataca el equipo que saca
	if kind == "goal_kick":
		var k: Goalkeeper = null
		for kk in keepers:
			if kk.team == team:
				k = kk
		ball.reset_at(Vector3(pos.x, 0.12, pos.z))
		if k != null:
			k.start_goal_kick(Vector3(pos.x, 0.0, pos.z))
			manager.goal_kick_keeper = k
			ctx.restart_taker = k
		_clear_zone(pos, team, 6.0)
		_focus_after_set_piece(null)
		return
	var squad: Array[Footballer] = home if team == 0 else away
	var taker: Footballer = null
	var best: float = INF
	for f in squad:
		var d: float = Vector2(f.global_position.x - pos.x, f.global_position.z - pos.z).length()
		if d < best:
			best = d
			taker = f
	if taker == null:
		ball.reset_at(Vector3(pos.x, 0.12, pos.z))
		return
	var k_kind: SetPiece.Kind = SetPiece.Kind.THROW_IN
	match kind:
		"corner":
			k_kind = SetPiece.Kind.CORNER
		"free_kick":
			k_kind = SetPiece.Kind.FREE_KICK
		"penalty":
			k_kind = SetPiece.Kind.PENALTY
	ball.reset_at(Vector3(pos.x, 0.12, pos.z))
	# Pelota muerta: nadie sigue corriendo con la inercia de la jugada (ni con un giro de clip a medias). Si no, durante la
	# preparacion (entrada desactivada) un companero que venia a la carrera se metia en la carrerilla del ejecutor.
	for f in home + away:
		if f == taker:
			continue
		if f.actions != null and f.actions.kind == &"turn":
			f.actions.reset()
		f.locomotion.stop()
		f.velocity = Vector3.ZERO
	var sp := SetPiece.new(k_kind, team, pos, taker, ctx)
	taker.set_piece = sp
	sp.place_taker()
	manager.active_set_piece = sp
	ctx.restart_taker = taker
	if kind == "corner" or kind == "penalty" or (kind == "free_kick" and absf(pos.x - gx) < 16.0):
		_arrange_box(kind, team, pos, taker)
	_clear_zone(pos, team, SET_PIECE_DISTANCE if kind != "throw_in" else 2.0)
	if kind != "throw_in":
		# Tambien los companeros: nadie salvo el ejecutor dentro de la carrerilla (SetPiece.CLEAR_RADIUS).
		_clear_zone(pos, 1 - team, SetPiece.CLEAR_RADIUS, taker)
	# La persona saca con su equipo: toma al ejecutor.
	if team == 0 and taker.team == 0 and controlled != null and controlled_keeper == null and taker != controlled:
		_give_control(taker)
	_focus_after_set_piece(taker)

func _focus_after_set_piece(taker: Footballer) -> void:
	if camera != null:
		if taker != null and taker.team == 0:
			camera.set_focus_actor(taker)
		camera.snap_to_target()

## Aleja a los rivales del equipo que saca a `radius` metros de la pelota (direccion radial, dentro de la cancha).
## `except`: jugador que no se mueve (el ejecutor, al despejar a sus companeros).
func _clear_zone(pos: Vector3, team: int, radius: float, except: Footballer = null) -> void:
	for f in (away if team == 0 else home):
		if f == except:
			continue
		var d := Vector3(f.global_position.x - pos.x, 0.0, f.global_position.z - pos.z)
		if d.length() >= radius:
			continue
		var dir: Vector3 = d.normalized() if d.length() > 0.1 else Vector3(-signf(pos.x) if absf(pos.x) > 0.1 else 1.0, 0.0, 0.0)
		var np: Vector3 = pitch.clamp_to_pitch(pos + dir * (radius + 0.3), 0.6)
		if Vector2(np.x - pos.x, np.z - pos.z).length() < radius:
			np = pitch.clamp_to_pitch(pos + Vector3(-signf(pos.x) * (radius + 0.3), 0.0, 0.0), 0.6)
		f.place_at(np, f.locomotion.yaw)

## Jugada ensayada en el area rival: atacantes a primer palo, segundo palo, punto de penal y borde del area; cada
## defensor marca a uno por el lado del arco. En el penal, todos fuera del area y detras de la pelota.
func _arrange_box(kind: String, team: int, pos: Vector3, taker: Footballer) -> void:
	var cfg: PitchConfig = pitch.config
	var gx: float = cfg.half_length() * (1.0 if team == 0 else -1.0)
	var inward: float = -signf(gx)
	var attackers: Array[Footballer] = []
	for f in (home if team == 0 else away):
		if f != taker:
			attackers.append(f)
	var defenders: Array[Footballer] = (away if team == 0 else home).duplicate()
	var att_yaw: float = Locomotion.yaw_from_dir(Vector3(-inward, 0.0, 0.0))
	var def_yaw: float = Locomotion.yaw_from_dir(Vector3(inward, 0.0, 0.0))
	if kind == "penalty":
		# Todos fuera del area, detras del punto y lejos de la carrera del ejecutor (si no, chocaria con ellos).
		var edge: float = gx + inward * (cfg.penalty_mark_distance + 4.0)
		var zs := [-3.5, 3.5, -2.4, 2.4, -5.0, 5.0, -6.0]
		var i: int = 0
		for f in attackers + defenders:
			f.place_at(Vector3(edge + inward * (0.8 if f.team != team else 0.0), 0.0, zs[i % zs.size()]), att_yaw)
			i += 1
		return
	var side: float = signf(pos.z) if absf(pos.z) > 0.5 else 1.0
	var spots := [
		CrossAssist.zone_point(ctx, team, &"near_post", side),
		CrossAssist.zone_point(ctx, team, &"far_post", side),
		CrossAssist.zone_point(ctx, team, &"penalty_spot", side),
		Vector3(gx + inward * (cfg.penalty_area_radius + 2.5), 0.0, -side * 2.0),
	]
	if kind == "free_kick":
		# Tiro libre cercano: atacantes repartidos por el area, uno de apoyo corto.
		# A SetPiece.CLEAR_RADIUS + 0.5 m de la pelota: fuera de la carrerilla del ejecutor.
		spots[3] = pos + Vector3(inward, 0.0, -side).normalized() * (SetPiece.CLEAR_RADIUS + 0.5)
	for i in attackers.size():
		var sp: Vector3 = spots[i % spots.size()]
		attackers[i].place_at(pitch.clamp_to_pitch(sp + Vector3(inward * 1.2, 0.0, 0.0), 0.5), att_yaw)
	for i in defenders.size():
		var mark: Vector3 = spots[i % spots.size()]
		# Marca por el lado del arco: entre el atacante y la porteria.
		defenders[i].place_at(pitch.clamp_to_pitch(mark + Vector3(-inward * 0.2 + signf(gx) * 0.6, 0.0, 0.3), 0.5), def_yaw)

## Nodo que maneja la persona ahora mismo: el arquero si lo ha tomado, si no el jugador de campo.
## Lo usan la camara y los indicadores.
func human_actor() -> Node3D:
	return controlled_keeper if controlled_keeper != null else controlled

## Arquero propio (el que defiende el arco de este equipo).
func own_keeper() -> Goalkeeper:
	for k in keepers:
		if k.team == 0:
			return k
	return null

func _charge_state() -> Dictionary:
	if controlled == null or controlled_keeper != null:
		return {}
	var bh: BallHandler = controlled.ball_handler
	return {"pass": bh.pass_charge, "shoot": bh.shot_charge, "through": bh.through_charge, "cross": bh.cross_charge}

## Con un pase de la persona el control pasa al RECEPTOR en el momento del pase (como en los juegos de futbol de
## consola): la persona maneja a quien va a recibir. Vale para todo pase propio (raso, elevado, filtrado, centro, saque
## de banda), tenga o no destinatario: sin destinatario recibe el companero que llega antes a la trayectoria predicha.
## El pasador queda en manos de la IA y, si hay espacio por delante, sigue la jugada (pared): corre al espacio para
## ofrecer la devolucion.
func _on_match_event(e: GameEvent) -> void:
	if e.type == GameEvent.Type.PASS or e.type == GameEvent.Type.SHOT:
		_last_kick_actor = e.actor_id
		_last_kick_frame = Engine.get_physics_frames()
	if e.type != GameEvent.Type.PASS or controlled == null or controlled_keeper != null:
		return
	if e.actor_id != controlled.actor_id or e.team != 0:
		return
	var target_id: int = int(e.data.get("target", -1))
	var target: Footballer = null
	for f in home:
		if f.actor_id == target_id:
			target = f
	if target == null or target == controlled:
		var pick: Array = pass_receiver(controlled)
		if pick.is_empty():
			return
		target = pick[0]
		target.expect_pass(pick[1], StringName(e.data.get("kind", "pass")), controlled)
	var passer: Footballer = controlled
	_give_control(target)
	_switch_cooldown = 0.6
	var atk := Vector3(1.0, 0.0, 0.0)
	var space: float = PassAssist._space_ahead(passer, atk, ctx.opponents_of(passer))
	if not bool(e.data.get("cross", false)) and space > 4.0 and passer.global_position.x > -pitch.config.half_length() * 0.5:
		# Hacia delante y algo hacia el centro (la devolucion llega por dentro).
		passer.give_and_go_dir = (atk + Vector3(0.0, 0.0, -signf(passer.global_position.z) * 0.3)).normalized()
		passer.give_and_go_time = 1.8

## Horizonte (s) y paso (s) de la trayectoria con la que se busca al receptor de un pase sin destinatario.
const RECEIVER_HORIZON := 3.0
const RECEIVER_STEP := 0.1

## Receptor de un pase propio sin destinatario: el companero (no el pasador) que llega antes a algun punto de la
## trayectoria predicha de la pelota a ras de piso o a la altura de la cabeza. Si nadie llega a tiempo, el mas cercano a
## donde se detiene la pelota. Devuelve [Footballer, punto de encuentro] o [] si no hay companeros.
func pass_receiver(passer: Footballer) -> Array:
	var traj: PackedVector3Array = BallPredictor.trajectory(ball.global_position, ball.linear_velocity, RECEIVER_HORIZON, RECEIVER_STEP, ball.angular_velocity)
	var best: Footballer = null
	var best_t: float = INF
	var best_p := Vector3.ZERO
	for f in home:
		if f == passer:
			continue
		var run: float = maxf(f.locomotion.max_sprint_speed() * 0.9, 2.0)
		var me := Vector3(f.global_position.x, 0.0, f.global_position.z)
		for i in range(1, traj.size()):
			var t_ball: float = float(i) * RECEIVER_STEP
			if t_ball >= best_t:
				break
			var p: Vector3 = traj[i]
			if p.y > 1.9:
				continue
			var flat := Vector3(p.x, 0.0, p.z)
			if me.distance_to(flat) / run <= t_ball:
				best = f
				best_t = t_ball
				best_p = flat
				break
	if best != null:
		return [best, best_p]
	var end: Vector3 = traj[traj.size() - 1]
	end.y = 0.0
	var best_d: float = INF
	for f in home:
		if f == passer:
			continue
		var d: float = Vector3(f.global_position.x, 0.0, f.global_position.z).distance_to(end)
		if d < best_d:
			best_d = d
			best = f
	return [best, end] if best != null else []

## Con la pelota en los pies de un companero de la persona (control, rebote, intercepcion, pase del arquero) el control
## pasa a el en el acto: la IA del equipo de la persona nunca decide con la pelota. Se exige que la pelota vaya con el
## (velocidad relativa baja) para no devolver el control al pasador en los pasos en que la pelota aun sale de su pie.
const HANDOVER_MAX_REL_SPEED := 4.0
## Pasos de fisica tras su propio pase o tiro en que la pelota aun no vuelve a ser del que la pateo.
const HANDOVER_AFTER_KICK_FRAMES := 45
var _last_kick_actor: int = -1
var _last_kick_frame: int = -1000

func _teammate_with_ball() -> Footballer:
	if ctx.dead_ball or ball == null or ball.is_held():
		return null
	if controlled_keeper == null and controlled.ball_handler.has_possession():
		return null
	var best: Footballer = null
	var best_d: float = INF
	for f in home:
		if f == controlled or not f.ball_handler.has_possession():
			continue
		if f.actor_id == _last_kick_actor and ball.last_toucher == f and Engine.get_physics_frames() - _last_kick_frame < HANDOVER_AFTER_KICK_FRAMES:
			continue
		var rel := Vector2(ball.linear_velocity.x - f.velocity.x, ball.linear_velocity.z - f.velocity.z)
		if rel.length() >= HANDOVER_MAX_REL_SPEED:
			continue
		var d: float = f.ball_handler.ball_distance()
		if d < best_d:
			best_d = d
			best = f
	return best

var _switch_cooldown: float = 0.0

## Situacion para la botonera tactil: ataque (la pelota es del equipo de la persona o le llega un pase propio),
## defensa (la tiene el rival) o suelta.
func touch_context() -> StringName:
	var owner: Footballer = ctx.possessor
	if owner != null:
		return &"attack" if owner.team == 0 else &"defense"
	for f in home:
		if f.has_incoming_pass():
			return &"attack"
	return &"loose"

## Aro de posesion bajo el poseedor (color de su equipo; sin aro = pelota suelta) y, con la pelota en los pies de la
## persona, aro bajo el companero que eligiria el pase con el joystick y la carga actuales.
func _update_rings() -> void:
	if possession_ring == null:
		return
	ctx.update_possession()
	var owner: Footballer = ctx.possessor if not ctx.dead_ball else null
	possession_ring.follow(owner)
	if owner != null:
		possession_ring.set_color(RING_COLORS[clampi(owner.team, 0, 1)])
	var target: Footballer = null
	if controlled != null and owner == controlled and controlled.ball_handler != null:
		var frame: InputFrame = controlled.last_frame
		var stick := Vector3.ZERO
		if frame != null:
			stick = KickModel.flat(frame.move_world if frame.use_world else ctx.screen_to_world(frame.move))
		var has_stick: bool = stick.length() > 0.2
		var intent: Vector3 = stick.normalized() if has_stick else controlled.locomotion.forward()
		target = PassAssist.pick_target(controlled, ctx, intent, has_stick, controlled.ball_handler.pass_charge, controlled.ball_handler.assist_pass_level())
	pass_ring.follow(target)

func _physics_process(delta: float) -> void:
	Prof.begin(&"escena (marcadores, cambio)")
	_scene_step(delta)
	Prof.end(&"escena (marcadores, cambio)")

func _scene_step(delta: float) -> void:
	if marker != null:
		marker.follow(human_actor(), delta)
		next_marker.follow(switch_candidate() if (controlled != null and home.size() > 1) else null, delta)
	_update_rings()
	if hud != null and controlled != null:
		hud.touch.show_switch = home.size() > 1
		hud.touch.context = touch_context()
	_switch_cooldown = maxf(_switch_cooldown - delta, 0.0)
	ctx.human_team = 0 if _person_plays() else -1
	if controlled == null or not ctx.input_enabled:
		return
	if ctx.human_team == 0:
		var mate: Footballer = _teammate_with_ball()
		if mate != null:
			if controlled_keeper != null:
				release_keeper_control()
			_give_control(mate)
			return
	# Con el arquero en las manos de la persona, el cambio lo devuelve al campo; el regreso tambien es automatico
	# cuando la jugada se aleja del area propia.
	if controlled_keeper != null:
		if controlled_keeper.input_source != null and controlled_keeper.input_source.poll(null).switch_pressed:
			release_keeper_control()
		elif not _ball_in_own_third():
			release_keeper_control()
		return
	if home.size() < 2:
		return
	if controlled.last_frame.switch_pressed:
		if _keeper_is_best_candidate():
			take_keeper_control()
		else:
			switch_to_nearest_to_ball()
	elif auto_switch and _switch_cooldown <= 0.0:
		_auto_switch()

## true si una persona maneja al equipo 0 (jugador de campo o arquero). Las pruebas que dejan al equipo 0 en manos de la
## IA le ponen un AIInput al controlado; ese control (que el cambio y los saques pasan de jugador en jugador) no cuenta.
func _person_plays() -> bool:
	if controlled_keeper != null:
		return controlled_keeper.input_source != null and not (controlled_keeper.input_source is AIInput)
	return controlled != null and controlled.input_source != null and not (controlled.input_source is AIInput)

## true si la pelota esta en el tercio defensivo propio (zona donde tiene sentido manejar al arquero).
func _ball_in_own_third() -> bool:
	return ball != null and ball.global_position.x < -pitch.config.half_length() / 3.0

## true si al pulsar CAMBIO conviene pasar al arquero: la jugada esta en el area propia y el arquero es quien mejor
## puede intervenir (mas cerca de la pelota que cualquier companero de campo).
func _keeper_is_best_candidate() -> bool:
	var k: Goalkeeper = own_keeper()
	if k == null or not _ball_in_own_third():
		return false
	var kd: float = Vector2(k.global_position.x - ball.global_position.x, k.global_position.z - ball.global_position.z).length()
	var best: Footballer = switch_candidate()
	if best == null:
		return true
	var fd: float = Vector2(best.global_position.x - ball.global_position.x, best.global_position.z - ball.global_position.z).length()
	return kd < fd

## Pasa el control de la persona al arquero propio: el jugador de campo que llevaba vuelve a la IA.
func take_keeper_control() -> bool:
	var k: Goalkeeper = own_keeper()
	if k == null or controlled == null or controlled_keeper != null:
		return false
	var human: InputSource = controlled.input_source
	controlled.input_source = AIInput.new(int(controlled.get_meta("ai_role", 0)), ai_skill)
	controlled.is_human_controlled = false
	k.input_source = human
	k.is_human_controlled = true
	controlled_keeper = k
	_switch_cooldown = 1.0
	if camera != null:
		camera.set_focus_actor(k)
	return true

## Devuelve el control a un jugador de campo (el mas cercano a la pelota) y el arquero vuelve a la IA.
func release_keeper_control() -> void:
	if controlled_keeper == null:
		return
	var human: InputSource = controlled_keeper.input_source
	controlled_keeper.input_source = null
	controlled_keeper.is_human_controlled = false
	controlled_keeper = null
	var target: Footballer = switch_candidate()
	if target == null:
		target = controlled
	if target != controlled:
		controlled.input_source = AIInput.new(int(controlled.get_meta("ai_role", 0)), ai_skill)
		controlled.is_human_controlled = false
	target.input_source = human
	target.is_human_controlled = true
	controlled = target
	_switch_cooldown = 1.0
	if camera != null:
		camera.set_focus_actor(controlled)

## Companero que recibiria el control al pulsar CAMBIO: el mas cercano a la pelota, sin contar al actual.
## Lo usan tanto el cambio como el indicador del siguiente jugador, para que senalen siempre al mismo.
func switch_candidate() -> Footballer:
	var best: Footballer = null
	var best_d: float = INF
	for f in home:
		if f == controlled:
			continue
		var d: float = Vector2(f.global_position.x - ball.global_position.x, f.global_position.z - ball.global_position.z).length()
		if d < best_d:
			best_d = d
			best = f
	return best

## Pasa el control humano al companero mas cercano a la pelota (distinto del actual).
func switch_to_nearest_to_ball() -> void:
	var best: Footballer = switch_candidate()
	if best != null:
		_give_control(best)

func _auto_switch() -> void:
	var cd: float = Vector2(controlled.global_position.x - ball.global_position.x, controlled.global_position.z - ball.global_position.z).length()
	# Con un pase en camino hacia el jugador de la persona no se cambia: en un pase largo el pasador y otros companeros
	# quedan mas cerca de la pelota que el receptor durante el vuelo y el control volvia a ellos.
	if cd < 7.0 or controlled.ball_handler.is_kick_in_progress() or controlled.has_ball() or controlled.has_incoming_pass():
		return
	var best: Footballer = null
	var best_d: float = cd - 3.0
	for f in home:
		if f == controlled:
			continue
		var d: float = Vector2(f.global_position.x - ball.global_position.x, f.global_position.z - ball.global_position.z).length()
		if d < best_d:
			best_d = d
			best = f
	if best != null:
		_give_control(best)

func _give_control(target: Footballer) -> void:
	if target == controlled:
		return
	var human: InputSource = controlled.input_source
	controlled.input_source = AIInput.new(int(controlled.get_meta("ai_role", 0)), ai_skill)
	controlled.is_human_controlled = false
	# Una carga que la IA hubiera empezado en el receptor no se suelta en manos de la persona (eso seria un pase o un
	# tiro decidido por la IA).
	target.ball_handler.cancel_charge()
	target.input_source = human
	target.is_human_controlled = true
	controlled = target
	_switch_cooldown = 1.0
	if camera != null:
		camera.set_focus_actor(controlled)
