class_name SetPieceGame
extends Node3D
## Modos de juego de la reforma: PENALES (tanda: 1 tiro y 1 atajada por ronda, serie de 5 y muerte subita) y TIRO LIBRE
## (el usuario elige donde poner la pelota en el campo; barrera, arquero y jugadores sueltos). Cancha de futbol 11
## (Stadium11), pelota fisica (Ball), golpeos del banco JSON elegidos por la direccion del tiro (ShotCatalog + SpShooter),
## arquero con atajadas planificadas y contacto fisico (SpKeeper), barrera con colision y salto (SpWall), jugadores sueltos
## (SpFieldPlayers) y reacciones de todos al resultado. Horizontal 16:9 (otras proporciones sin deformar).

enum Mode { PENALTY, FREE_KICK, CHALLENGE }
enum Phase { PLACE, AIM, KEEPER_PICK, RUNUP, FLIGHT, RESULT, OVER, REPLAY }

const SCENE := "res://scenes/setpiece/setpiece_game.tscn"
const MENU_SCENE := "res://scenes/setpiece/main_menu.tscn"
const BALL_SCENE := preload("res://scenes/ball/ball.tscn")

## Donde espera el tirador (m detras y al costado de la pelota, del lado del pie que no patea), como en los videos.
const PEN_STANCE := Vector2(2.6, 2.9)
const FK_STANCE := Vector2(2.4, 2.3)
## Velocidad de salida (m/s) con potencia minima y maxima.
const PEN_SPEED := Vector2(15.0, 29.0)
const FK_SPEED := Vector2(17.0, 33.0)
## Zona valida para la pelota del tiro libre (distancia a la linea de gol).
const FK_MIN_X := 17.5
const FK_MAX_X := 40.0

## Modo que abre la escena (lo fija el menu antes de cambiar de escena).
static var next_mode: int = Mode.PENALTY
## Contra quien se juega (pedido del usuario): CPU = se alternan tiro y atajada contra la IA; PRACTICE = tiros libres sin
## turnos (como siempre: el usuario elige donde patear); LOCAL = dos jugadores en el mismo telefono (duelo local). -1 = lo
## de siempre del modo (penales contra la CPU, tiros libres de practica). Se lee una vez al abrir la escena.
enum Vs { CPU, PRACTICE, LOCAL }
static var next_vs: int = -1
## Modo CHALLENGE: ejercicio de la Academia o desafio de la Arena (definicion de ChallengeCatalog, ya en su dificultad) y si
## es practica libre (no registra el progreso).
static var next_challenge: Dictionary = {}
static var next_practice: bool = false
const CHALLENGE_MENU_SCENE := "res://scenes/challenges/challenge_menu.tscn"

var mode: int = Mode.PENALTY
var vs: int = Vs.CPU
var phase: int = Phase.AIM
var rng := RandomNumberGenerator.new()

var stadium: Stadium11
var ball: Ball
var cam: SpCamera
var hud: SpHud
var goal: Goal
var gx: float = 52.5
var half_goal: float = 3.66
var goal_h: float = 2.44

var user_shooter: SpShooter
var cpu_shooter: SpShooter
var user_keeper: SpKeeper
var cpu_keeper: SpKeeper
var wall: SpWall
var wall_actors: Array[SpActor] = []
var field: SpFieldPlayers
var bench: Array[SpActor] = []
## Pelota suelta despues de la jugada: el arquero la recoge o un defensor la despeja.
var loose: SpLooseBall
## Ejercicio o desafio en curso (modo CHALLENGE).
var runner: ChallengeRunner = null
## Repeticion de la ultima jugada (registro por estados) y su reproduccion.
var recording: PlayRecording
var replay_f: float = -1.0
## Camara lenta en la repeticion: apagada por defecto (pedido del usuario: la repeticion iba muy lenta); se prende con el
## boton «Lenta» de la repeticion.
var replay_slowmo: bool = false
var replay_angle: int = 0
const REPLAY_ANGLES := ["TV", "Detrás", "Arco"]
var _pre_replay: Dictionary = {}

var shootout := PenaltyShootout.new()
var fk_goals: int = 0
var fk_shots: int = 0
## Duelo de tiros libres: los puntos de tiro (FreeKickSpots) empiezan en este desplazamiento, sorteado al abrir la escena
## (online lo fija el servidor). Los dos patean desde el mismo punto en cada ronda.
var spot_offset: int = 0
## Duelo local de dos jugadores (Vs.LOCAL): marcador propio y cortinas de cambio de turno. Jugador 1 = equipo 0 (tirador y
## arquero del usuario), Jugador 2 = equipo 1 (los de la CPU, manejados por el segundo jugador).
var local: LocalDuel = null
## Paso del turno local: 0 nada, 1 cortina antes de atajar, 2 eligiendo sector, 3 cortina antes de patear, 4 pateando.
var local_step: int = 0
var _curtain: ColorRect = null
var _curtain_title: Label
var _curtain_text: Label
var _curtain_btn: Button
var _curtain_action: StringName = &""
## La barrera y los sueltos tienen la camiseta del equipo que defiende (cambia cuando patea la CPU).
var _kits_user_attack: bool = true

var ball_spot := Vector3.ZERO
var zoom: float = 1.0
var gesture: ShotGesture
var preview: TrajectoryPreview
var diag: GestureDiagnostics
var perf: DiagnosticsOverlay
var perf_session: PerfSession
## Ultimos parametros del tiro (diagnostico y pruebas) y velocidad real de salida medida despues del contacto.
var last_params: ShotParams = null
var last_features: Dictionary = {}
var last_launch_speed: float = -1.0
var _launch_measure: int = -1
var _preview_t: float = 0.0
## Frecuencia de la vista previa (veces por segundo).
const PREVIEW_HZ := 15.0
var _swiping: bool = false
var _touches: Dictionary = {}
var _pinch_d: float = -1.0

var cur_shooter: SpShooter
var cur_keeper: SpKeeper
var user_shooting: bool = true
## Ultimo tiro: {velocity, spin, traj, class, power, kind, entry, target}.
var last_shot: Dictionary = {}
## Resultado de la ultima jugada: "goal", "save", "post", "wall", "cleared", "miss".
var outcome: String = ""
var _goal_scored: bool = false
var _post_hit: bool = false
var _wall_hit: bool = false
var _keeper_touch: StringName = &""
## Quien fue a buscar la pelota suelta en esta jugada (no reacciona: esta jugando).
var chaser: SpActor = null
var _flight_t: float = 0.0
var _decide_t: float = 0.0
var _settle_t: float = -1.0
var _result_t: float = 0.0
## Penal: instante del resultado en que empezo la reaccion del arquero (-1: todavia no).
var _keeper_react_at: float = -1.0
## El arquero ya solto o saco la pelota que tenia en las manos en esta jugada.
var _keeper_ball_done: bool = false
## Festejos y lamentos de todos despues del tiro (SpCelebration).
var celebration: SpCelebration
## Penal: lugar de cada jugador del circulo central (vuelven ahi en cada turno: salen a festejar).
var _bench_home: Array = []
## Gol: la camara de juego se queda quieta GOAL_LIVE_T s (los compañeros corren al autor, con temblor suave) y despues,
## si nadie salta el festejo, el primer plano del autor durante GOAL_CINEMATIC_T s.
const GOAL_LIVE_T := 2.6
const GOAL_CINEMATIC_T := 2.8
const GOAL_SHAKE := 0.6
var _cinematic_on: bool = false
var _committed: bool = false
var _runup_t: float = 0.0
var _keeper_zone := Vector3.INF
## Partida online (OnlineMatch) que maneja turnos, reloj y servidor; null = partida offline.
var online_match: OnlineMatch = null
var _online_pick_sent: bool = false
var _pick_t: float = 0.0
var _zone_marker: MeshInstance3D
## Grilla de los 9 sectores del arco (KeeperZones) que se ve mientras el usuario elige donde tirarse.
var _zone_grid: Node3D
var _zone_cells: Array[MeshInstance3D] = []
## Sector elegido (-1 = ninguno).
var picked_zone: int = -1
var _place_marker: MeshInstance3D
## Animo del publico (0..1, la tribuna es la hinchada del usuario): festejo y abucheo, cada uno con un tiempo a pleno
## (_hold) antes de apagarse. Pedido 2026-11-12: el publico de los minijuegos arcade tambien aca, que festeje mas vivo y
## mas largo, que abuchee los fallos y que en calma se siga escuchando.
var _cheer: float = 0.0
var _boo: float = 0.0
var _cheer_hold: float = 0.0
var _boo_hold: float = 0.0
const CHEER_DECAY := 0.22
const BOO_DECAY := 0.3
## Pruebas: sin esperas de presentacion (el resultado pasa enseguida).
var fast: bool = false
## Atributos del jugador del usuario (perfil del servidor; AttributeEffects): escalan, con tope, los coeficientes del
## gesto de sus tiros y el alcance de su arquero. Vacio = neutros (el juego de siempre). El duelo local (dos personas en
## un telefono) y la CPU juegan siempre con atributos neutros.
var user_attrs: Dictionary = {}
## Atajadas del usuario en esta partida (van con el premio de la partida offline; el servidor las acota).
var user_saves: int = 0

func _ready() -> void:
	SpSettings.load_settings()
	PlayerCustom.load_custom()
	rng.randomize()
	mode = next_mode
	vs = next_vs if next_vs >= 0 else (Vs.PRACTICE if mode == Mode.FREE_KICK else Vs.CPU)
	if mode == Mode.CHALLENGE:
		vs = Vs.PRACTICE
	next_vs = -1
	if vs != Vs.LOCAL and user_attrs.is_empty():
		user_attrs = AttributeEffects.user_attrs()
	if vs == Vs.LOCAL:
		local = LocalDuel.new()
		shootout.first = local.first_shooter()
	stadium = Stadium11.new()
	stadium.name = "Stadium"
	add_child(stadium)
	stadium.build(PitchConfig.football11(SpSettings.goal_style))
	# Pancartas de la hinchada con el nombre del jugador del usuario (aliento, festejo y cargadas).
	stadium.add_banners(CrowdBanners.player_name())
	gx = stadium.half_length()
	half_goal = stadium.config.half_goal()
	goal_h = stadium.config.goal_height
	goal = stadium.get_goal(1)
	ball = BALL_SCENE.instantiate()
	# Balon con el diseño elegido por el usuario (solo se ve: la fisica no cambia).
	BallSkins.apply_user(ball)
	ball.name = "Ball"
	add_child(ball)
	stadium.set_ball(ball)
	stadium.goal_scored.connect(_on_goal_scored)
	ball.hit_goal_frame.connect(func(_p: Vector3, _s: float) -> void: _post_hit = true)
	ball.body_entered.connect(_on_ball_body)
	cam = SpCamera.new()
	cam.name = "Camera"
	add_child(cam)
	cam.current = true
	hud = SpHud.new()
	add_child(hud)
	# Camara de TV: solo tiene sentido en los tiros libres.
	if hud.tv_button != null:
		hud.tv_button.visible = _fk_like()
	hud.menu_pressed.connect(_go_menu)
	hud.action_pressed.connect(_on_action)
	hud.zoom_changed.connect(func(d: float) -> void: set_zoom(zoom * (1.15 if d > 0.0 else 1.0 / 1.15)))
	_build_markers()
	_build_people()
	loose = SpLooseBall.new()
	loose.name = "LooseBall"
	add_child(loose)
	loose.setup(ball, gx)
	celebration = SpCelebration.new()
	celebration.name = "Celebration"
	add_child(celebration)
	recording = PlayRecording.new()
	recording.name = "PlayRecording"
	add_child(recording)
	var everyone: Array[SpActor] = []
	for n in get_children():
		if n is SpActor:
			everyone.append(n)
	recording.setup(ball, everyone)
	# Precalculo al cargar (antes costaba ~0,65 s en PC la primera atajada, en el golpe: en el telefono se trababa el tiro).
	KeeperPlanner.warm_cache()
	ShotCatalog.clips()
	for roles in [SpReactions.GOAL_SCORER, SpReactions.MISS_SHOOTER, SpReactions.GOAL_TEAM, SpReactions.SAD, SpReactions.HAPPY_DEFENDER]:
		SpReactions.pick(roles, rng, 1.5, 1.0)
	gesture = ShotGesture.new(_user_tuning(), 720.0)
	preview = TrajectoryPreview.new()
	preview.name = "TrajectoryPreview"
	add_child(preview)
	diag = GestureDiagnostics.new()
	diag.visible = false
	hud.root.add_child(diag)
	diag.compare_requested.connect(_compare_gestures)
	# Rendimiento medido en el dispositivo (el mismo medidor del partido): FPS, tiempos de cuadro y de fisica, llamadas de
	# dibujo y el costo de cada sistema (Prof) mientras el diagnostico esta abierto. Es lo que hay que leer en el telefono.
	perf = DiagnosticsOverlay.new()
	perf.name = "PerfOverlay"
	perf.position = Vector2(16, 90)
	perf.visible = false
	hud.root.add_child(perf)
	hud.diag_pressed.connect(func() -> void:
		diag.visible = not diag.visible
		perf.visible = diag.visible)
	# Medicion por momento de la jugada (para el telefono): «Medir rendimiento» y «Copiar informe» en el panel.
	perf_session = PerfSession.new()
	perf_session.name = "PerfSession"
	add_child(perf_session)
	perf_session.moment_source = perf_moment
	ball.net_hit.connect(perf_session.on_net_hit)
	diag.perf_toggle_requested.connect(_toggle_perf_session)
	diag.perf_copy_requested.connect(_copy_perf_report)
	if is_inside_tree():
		Sfx.watch_ball(ball)
		Sfx.crowd(true)
	GraphicsSettings.apply()
	if vs == Vs.LOCAL:
		cpu_keeper.ai = false
		hud.shootout_tags = ["J1 ", "J2 "]
		_build_curtain()
	if mode == Mode.PENALTY:
		hud.set_title("PENALES · 2 JUGADORES" if vs == Vs.LOCAL else "PENALES")
		if vs == Vs.LOCAL:
			OnlineMatch.pending = {}
		if not OnlineMatch.pending.is_empty():
			# Partida online (la dejo el lobby): el servidor manda los turnos y los resultados.
			var om := OnlineMatch.new()
			om.name = "OnlineMatch"
			om.setup(self, OnlineMatch.pending)
			online_match = om
			add_child(om)
			hud.set_title("PENALES ONLINE")
		_start_penalty_turn()
	elif mode == Mode.CHALLENGE:
		var d: Dictionary = next_challenge if not next_challenge.is_empty() else ChallengeCatalog.academia()[0]
		runner = ChallengeRunner.new()
		runner.name = "ChallengeRunner"
		add_child(runner)
		runner.setup(d, next_practice, ball, gx, half_goal, goal_h)
		hud.set_title(String(d["title"]).to_upper())
		hud.hide_shootout()
		_setup_challenge_attempt()
	elif fk_duel():
		hud.set_title("TIROS LIBRES · 2 JUGADORES" if vs == Vs.LOCAL else "TIROS LIBRES · CONTRA LA CPU")
		spot_offset = rng.randi_range(0, FreeKickSpots.SPOTS.size() - 1)
		if vs != Vs.LOCAL and not OnlineMatch.pending.is_empty():
			# Tiros libres online: el servidor manda los turnos, los puntos de tiro y los resultados.
			var om := OnlineMatch.new()
			om.name = "OnlineMatch"
			om.setup(self, OnlineMatch.pending)
			online_match = om
			add_child(om)
			hud.set_title("TIROS LIBRES ONLINE")
			spot_offset = om.spot_offset()
		_start_fk_duel_turn()
	else:
		hud.set_title("TIRO LIBRE")
		hud.hide_shootout()
		ball_spot = Vector3(gx - 24.0, ball.radius, -6.0)
		_enter_place()

func _exit_tree() -> void:
	Sfx.crowd(false)
	SpSettings.override_difficulty = -1

## Desafio o ejercicio con la pelota en el punto del penal (contexto de penal: velocidades y lectura del arquero).
func _penalty_like() -> bool:
	return mode == Mode.PENALTY or (mode == Mode.CHALLENGE and runner != null and runner.spot_distance() <= 12.0)

## Como un tiro libre: camara detras de la pelota con zoom, barrera, arquero que lee la pelota.
## Tiros libres por turnos (contra la CPU o entre dos): se alternan tiro y atajada, con tanda como los penales.
func fk_duel() -> bool:
	return mode == Mode.FREE_KICK and vs != Vs.PRACTICE

## Modos con turnos alternados de tiro y atajada y marcador de tanda (PenaltyShootout).
func duel_like() -> bool:
	return mode == Mode.PENALTY or fk_duel()

func _fk_like() -> bool:
	return mode == Mode.FREE_KICK or (mode == Mode.CHALLENGE and not _penalty_like())

# --- Construccion ---------------------------------------------------------------------------------------------------------

func _actor(kit: Dictionary, team: int, name_: String) -> SpActor:
	var a := SpActor.new()
	a.name = name_
	add_child(a)
	a.build(kit)
	a.team = team
	return a

func _build_people() -> void:
	var foot: int = SpSettings.foot
	user_shooter = SpShooter.new()
	user_shooter.name = "UserShooter"
	add_child(user_shooter)
	user_shooter.setup(_actor(PlayerCustom.kit(), 0, "UserShooterBody"), ball)
	user_shooter.foot = foot
	user_shooter.actor.number_style = PlayerCustom.number_style
	user_shooter.actor.set_back_number(PlayerCustom.number)
	user_shooter.actor.set_accessories(PlayerCustom.accessories)
	user_shooter.celebration = PlayerCustom.celebration_clip()
	user_shooter.follow_run = PlayerCustom.follow_style == 1
	user_shooter.contact.connect(_on_contact)
	cpu_keeper = SpKeeper.new()
	cpu_keeper.name = "CpuKeeper"
	add_child(cpu_keeper)
	cpu_keeper.setup(_actor(SpSettings.CPU_KEEPER_KIT, 1, "CpuKeeperBody"), ball, gx, half_goal, goal_h)
	cpu_keeper.touched_ball.connect(_on_keeper_touch)
	if duel_like():
		cpu_shooter = SpShooter.new()
		cpu_shooter.name = "CpuShooter"
		add_child(cpu_shooter)
		cpu_shooter.setup(_actor(SpSettings.CPU_KIT, 1, "CpuShooterBody"), ball)
		cpu_shooter.contact.connect(_on_contact)
		user_keeper = SpKeeper.new()
		user_keeper.name = "UserKeeper"
		add_child(user_keeper)
		user_keeper.setup(_actor(PlayerCustom.keeper_kit(), 0, "UserKeeperBody"), ball, gx, half_goal, goal_h)
		user_keeper.actor.number_style = PlayerCustom.number_style
		user_keeper.actor.set_back_number(PlayerCustom.number)
		user_keeper.actor.set_accessories(PlayerCustom.accessories)
		user_keeper.ai = false
		user_keeper.touched_ball.connect(_on_keeper_touch)
		AttributeEffects.apply_keeper(user_keeper, _shooter_attrs())
		if fk_duel():
			cpu_shooter.actor.visible = false
			user_keeper.actor.visible = false
	if mode == Mode.PENALTY:
		# Los demas jugadores esperan en el circulo central (como en una tanda real) y reaccionan a cada penal.
		for i in 6:
			var team: int = 0 if i < 3 else 1
			var a: SpActor = _actor(SpSettings.USER_KIT if team == 0 else SpSettings.CPU_KIT, team, "Bench%d" % i)
			a.global_position = Vector3(-1.0 + 0.2 * float(i % 3), 0.0, (-3.5 if team == 0 else 1.2) + 1.0 * float(i % 3))
			a.set_facing(Vector3(1, 0, 0))
			_bench_home.append(a.global_position)
			var idles: Array[StringName] = SpClips.by_role(&"idle_ready", false)
			if not idles.is_empty():
				a.play_loop(idles[(i * 3) % idles.size()], 0.2, rng.randf_range(0.85, 1.1))
			bench.append(a)
	else:
		wall = SpWall.new()
		wall.name = "Wall"
		add_child(wall)
		# El arquero sabe donde esta su barrera: no se tira a un tiro que ella va a frenar.
		cpu_keeper.wall = wall
		if user_keeper != null:
			user_keeper.wall = wall
		for i in 5:
			var a: SpActor = _actor(SpSettings.CPU_KIT, 1, "Wall%d" % i)
			a.enable_collider()
			wall_actors.append(a)
		field = SpFieldPlayers.new()
		field.name = "FieldPlayers"
		add_child(field)
		var att: Array[SpActor] = []
		var dfn: Array[SpActor] = []
		for i in 3:
			var a1: SpActor = _actor(SpSettings.USER_KIT, 0, "Att%d" % i)
			a1.enable_collider()
			att.append(a1)
			var a2: SpActor = _actor(SpSettings.CPU_KIT, 1, "Def%d" % i)
			a2.enable_collider()
			dfn.append(a2)
		field.setup(att, dfn, ball, gx)

func _build_markers() -> void:
	_build_zone_grid()
	# Centro del sector elegido para tirarse.
	_zone_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.22
	tm.outer_radius = 0.32
	_zone_marker.mesh = tm
	_zone_marker.rotation.z = PI * 0.5
	var zm := StandardMaterial3D.new()
	zm.albedo_color = Color(1.0, 0.85, 0.2, 0.9)
	zm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_zone_marker.material_override = zm
	_zone_marker.visible = false
	add_child(_zone_marker)
	_place_marker = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 0.9
	cm.height = 0.02
	_place_marker.mesh = cm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(1.0, 0.85, 0.2, 0.55)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_place_marker.material_override = pm
	_place_marker.visible = false
	add_child(_place_marker)

func goal_center() -> Vector3:
	return Vector3(gx, 1.0, 0.0)

# --- Penales -------------------------------------------------------------------------------------------------------------

func _start_penalty_turn() -> void:
	hud.hide_banner()
	hud.hide_overlay()
	hud.set_actions([])
	hud.set_zoom_visible(false)
	hud.set_shootout(shootout.results[0], shootout.results[1], PenaltyShootout.REGULAR)
	hud.set_score_text("%d - %d" % [shootout.goals(0), shootout.goals(1)])
	# Online el final lo decide el servidor (mismas reglas; ademas corta en empate al tope de tiros).
	if (online_match.server_done() if online_match != null else shootout.finished()):
		_show_end()
		return
	user_shooting = shootout.next_team() == PenaltyShootout.USER
	if online_match != null:
		user_shooting = online_match.my_shot()
		_online_pick_sent = false
	_zone_marker.visible = false
	show_zone_grid(false)
	ball_spot = Vector3(gx - Stadium11.PENALTY_MARK, ball.radius, 0.0)
	_reset_play()
	ball.reset_at(ball_spot)
	cur_shooter = user_shooter if user_shooting else cpu_shooter
	cur_keeper = cpu_keeper if user_shooting else user_keeper
	for s in [user_shooter, cpu_shooter]:
		s.actor.visible = s == cur_shooter
	for k in [user_keeper, cpu_keeper]:
		k.actor.visible = k == cur_keeper
	if not user_shooting and vs == Vs.LOCAL:
		cpu_shooter.foot = 1
	elif not user_shooting:
		# La CPU tiene tiradores diestros y zurdos.
		cpu_shooter.foot = 1 if rng.randf() < 0.78 else -1
	else:
		user_shooter.foot = SpSettings.foot
	cur_shooter.stance(ball_spot, Vector3(1, 0, 0), PEN_STANCE.x, PEN_STANCE.y)
	cur_keeper.reset(Vector3(gx - 0.12, 0.0, 0.0))
	# Los del circulo central vuelven a su lugar (pudieron salir a festejar; la camara de juego no los ve ahi).
	celebration.clear()
	var idles: Array[StringName] = SpClips.by_role(&"idle_ready", false)
	for i in bench.size():
		var b: SpActor = bench[i]
		b.stop_moving()
		if i < _bench_home.size():
			b.global_position = _bench_home[i]
		b.set_facing(Vector3(1, 0, 0))
		b.play_loop(idles[rng.randi() % idles.size()], 0.3)
	var round_n: int = shootout.kicks(PenaltyShootout.USER if user_shooting else PenaltyShootout.CPU) + 1
	var round_txt: String = ("Muerte súbita" if shootout.in_sudden_death() else "Penal %d de %d" % [round_n, PenaltyShootout.REGULAR])
	if vs == Vs.LOCAL:
		_local_begin_turn(round_txt)
	elif user_shooting:
		var f: Array = SpCamera.behind_ball(ball_spot, goal_center(), 1.0, true)
		cam.frame(f[0], f[1], f[2], true, 0.45)
		phase = Phase.AIM
		_aim_actions()
		hud.set_hint("%s · Tirás vos: deslizá el dedo desde la pelota hacia donde querés que vaya" % round_txt)
	else:
		var g: Array = SpCamera.behind_goal(Vector3(gx, 0.0, 0.0), ball_spot)
		cam.frame(g[0], g[1], g[2], true, 0.45)
		phase = Phase.KEEPER_PICK
		_pick_t = 0.0
		_keeper_zone = Vector3.INF
		picked_zone = -1
		_zone_marker.visible = false
		show_zone_grid(true)
		hud.set_hint("%s · Atajás vos: tocá uno de los 9 sectores del arco para tirarte" % round_txt)
	if online_match != null:
		online_match.on_turn_start(user_shooting)

var _framed_once: bool = false
func _first_frame() -> bool:
	if _framed_once:
		return false
	_framed_once = true
	return true

## La IA patea el penal: elige rincon, altura y potencia (a veces vaselina) y patea con el mismo modelo que el usuario
## (ShotParams), con su error de precision segun la dificultad.
func _cpu_penalty() -> void:
	var p := ShotParams.new()
	var chip: bool = rng.randf() < 0.05
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	var z: float = 0.0 if rng.randf() < 0.12 else side * rng.randf_range(1.4, half_goal - 0.35)
	var y: float = rng.randf_range(0.25, 0.9) if rng.randf() < 0.55 else rng.randf_range(1.0, goal_h - 0.35)
	p.target = Vector3(gx, y, z)
	p.power = rng.randf_range(0.45, 0.95)
	p.speed = lerpf(PEN_SPEED.x, PEN_SPEED.y, p.power)
	p.lateral_spin = rng.randf_range(-8.0, 8.0)
	p.gesture_type = "potente_raso" if p.power > 0.7 and y < 0.9 else ("elevado" if y > 1.4 and p.power > 0.5 else "colocado")
	p.kind = ShotCatalog.Kind.POWER if p.power > 0.7 else ShotCatalog.Kind.NORMAL
	if chip:
		p.target = Vector3(gx, 1.6, rng.randf_range(-1.0, 1.0))
		p.speed = rng.randf_range(10.0, 12.5)
		p.power = 0.15
		p.lateral_spin = 0.0
		p.gesture_type = "globo"
		p.kind = ShotCatalog.Kind.CHIP
	p.spin = Vector3(0.0, p.lateral_spin, 0.0)
	p.direction = Vector3(p.target.x - ball_spot.x, 0.0, p.target.z - ball_spot.z).normalized()
	GestureShotModel.solve(p, ball_spot, shot_context(), false)
	_take_shot(cpu_shooter, p, SpSettings.cpu_shot_error_deg())

# --- Tiro libre ------------------------------------------------------------------------------------------------------------

func _enter_place() -> void:
	phase = Phase.PLACE
	hud.hide_banner()
	hud.hide_overlay()
	hud.set_zoom_visible(false)
	hud.set_score_text("Goles %d / %d" % [fk_goals, fk_shots])
	hud.set_hint("Tocá el campo para colocar la pelota (fuera del área)")
	hud.set_actions([[&"confirm", "Confirmar"]])
	_reset_play()
	for a in wall_actors:
		a.visible = false
	user_shooter.actor.visible = false
	cpu_keeper.reset(Vector3(gx - 0.4, 0.0, 0.0))
	ball.reset_at(ball_spot)
	_place_marker.visible = true
	_place_marker.global_position = Vector3(ball_spot.x, 0.02, ball_spot.z)
	var f: Array = SpCamera.placement(gx)
	cam.frame(f[0], f[1], f[2], _first_frame(), 0.5)
	for a in field.attackers + field.defenders:
		a.visible = false

## Pelota en una posicion valida del tiro libre (fuera del area, en el campo de ataque, dentro de la cancha).
func clamp_free_kick_spot(p: Vector3) -> Vector3:
	var x: float = clampf(p.x, gx - FK_MAX_X, gx - 1.0)
	var z: float = clampf(p.z, -stadium.half_width() + 1.5, stadium.half_width() - 1.5)
	var in_box: bool = x > gx - Stadium11.PENALTY_AREA_DEPTH - 0.6 and absf(z) < Stadium11.PENALTY_AREA_WIDTH * 0.5 + 0.6
	if in_box:
		x = gx - Stadium11.PENALTY_AREA_DEPTH - 0.6
	if Vector2(gx - x, z).length() < FK_MIN_X:
		x = gx - sqrt(maxf(FK_MIN_X * FK_MIN_X - z * z, 0.0))
	return Vector3(x, ball.radius, z)

func _setup_free_kick() -> void:
	_place_marker.visible = false
	_reset_play()
	ball.reset_at(ball_spot)
	var n: int = SpWall.count_for(ball_spot, gx)
	var use: Array[SpActor] = []
	for i in wall_actors.size():
		wall_actors[i].visible = i < n
		if i < n:
			use.append(wall_actors[i])
		else:
			wall_actors[i].global_position = Vector3(0, -50, 0)
	wall.arrange(use, ball_spot, gx, half_goal)
	var wall_pts: Array = []
	for a in use:
		wall_pts.append(a.global_position)
	field.arrange(ball_spot, wall_pts)
	# Arquero: en la bisectriz del angulo, corrido hacia el palo que no tapa la barrera.
	var kz: float = FreeKickSpots.keeper_z(ball_spot.z, half_goal)
	if not fk_duel():
		user_shooting = true
	elif _kits_user_attack != user_shooting:
		_fk_kits(user_shooting)
	cur_shooter = user_shooter if user_shooting else cpu_shooter
	cur_keeper = cpu_keeper if user_shooting else user_keeper
	cur_keeper.reset(Vector3(gx - 0.6, 0.0, kz))
	cur_keeper.actor.visible = true
	cur_shooter.actor.visible = true
	if fk_duel():
		var other_k: SpKeeper = user_keeper if user_shooting else cpu_keeper
		other_k.reset(Vector3(gx + 6.0, 0.0, 12.0))
		other_k.actor.visible = false
		var other_s: SpShooter = cpu_shooter if user_shooting else user_shooter
		other_s.actor.visible = false
	cur_shooter.foot = SpSettings.foot if user_shooting else (1 if vs == Vs.LOCAL or rng.randf() < 0.78 else -1)
	var aim: Vector3 = Vector3(gx - ball_spot.x, 0.0, -ball_spot.z).normalized()
	cur_shooter.stance(ball_spot, aim, FK_STANCE.x, FK_STANCE.y)
	if vs == Vs.LOCAL:
		_local_begin_turn(_duel_round_text())
		return
	if not user_shooting:
		# Duelo: patea la CPU y el usuario ataja (elige uno de los 9 sectores antes del golpe; la CPU no lo sabe).
		var g: Array = SpCamera.behind_goal(Vector3(gx, 0.0, 0.0), ball_spot)
		cam.frame(g[0], g[1], g[2], true, 0.45)
		phase = Phase.KEEPER_PICK
		_pick_t = 0.0
		_keeper_zone = Vector3.INF
		picked_zone = -1
		_zone_marker.visible = false
		show_zone_grid(true)
		hud.set_zoom_visible(false)
		hud.set_actions([])
		hud.set_hint("%s · Atajás vos: tocá uno de los 9 sectores del arco para tirarte" % _duel_round_text())
		return
	phase = Phase.AIM
	_aim_camera()
	hud.set_zoom_visible(true)
	_aim_actions()
	if fk_duel():
		hud.set_hint("%s · Tirás vos: dibujá el tiro con el dedo (el final marca a dónde va, la curva da efecto)" % _duel_round_text())
	else:
		hud.set_hint("Dibujá el tiro con el dedo: el final marca a dónde va, la curva da efecto, la rapidez es la potencia")

## Duelo de tiros libres: turno siguiente (patea quien toca, desde el punto de la ronda; los dos patean desde el mismo).
func _start_fk_duel_turn() -> void:
	hud.hide_banner()
	hud.hide_overlay()
	hud.set_shootout(shootout.results[0], shootout.results[1], PenaltyShootout.REGULAR)
	hud.set_score_text("%d - %d" % [shootout.goals(0), shootout.goals(1)])
	if (online_match.server_done() if online_match != null else shootout.finished()):
		_show_end()
		return
	var team: int = shootout.next_team()
	user_shooting = team == PenaltyShootout.USER
	var round_i: int = shootout.kicks(team)
	if online_match != null:
		user_shooting = online_match.my_shot()
		_online_pick_sent = false
		round_i = online_match.fk_round()
	var d: Vector2 = FreeKickSpots.at(round_i, spot_offset)
	ball_spot = clamp_free_kick_spot(Vector3(gx - d.x, ball.radius, d.y))
	_setup_free_kick()
	if online_match != null:
		online_match.on_turn_start(user_shooting)

## «Tiro libre 2 de 5» o «Muerte súbita» para el turno que empieza.
func _duel_round_text() -> String:
	if shootout.in_sudden_death():
		return "Muerte súbita"
	var team: int = PenaltyShootout.USER if user_shooting else PenaltyShootout.CPU
	return "%s %d de %d" % ["Penal" if mode == Mode.PENALTY else "Tiro libre", shootout.kicks(team) + 1, PenaltyShootout.REGULAR]

## Camisetas del tiro libre por turnos: la barrera y los defensores sueltos son del equipo que ataja; los atacantes, del que
## patea.
func _fk_kits(user_attacks: bool) -> void:
	_kits_user_attack = user_attacks
	var def_kit: Dictionary = SpSettings.CPU_KIT if user_attacks else SpSettings.USER_KIT
	var att_kit: Dictionary = SpSettings.USER_KIT if user_attacks else SpSettings.CPU_KIT
	for a in wall_actors:
		a.set_kit(def_kit)
	for a in field.defenders:
		a.set_kit(def_kit)
	for a in field.attackers:
		a.set_kit(att_kit)

## Tiro libre de la CPU (duelo): elige un destino sin saber a que sector se jugo el usuario. Casi siempre al lado que no
## tapa la barrera o por encima de ella al palo del arquero, con potencia y efecto variables; a veces fuerte al medio.
## El error de precision es el de la dificultad (SpSettings.cpu_shot_error_deg): puede pegar en la barrera o irse afuera.
func _cpu_free_kick() -> void:
	_take_shot(cpu_shooter, cpu_free_kick_params(), SpSettings.cpu_shot_error_deg())

## Destino, potencia y curva de un tiro libre de la CPU (o del bot online) sin conocer el sector del arquero: casi siempre
## al lado que no tapa la barrera o por encima de ella al palo del arquero; a veces fuerte al medio.
func cpu_free_kick_params() -> ShotParams:
	var cover: Vector3 = SpWall.cover_point(ball_spot, gx, half_goal)
	var near: float = signf(cover.z) if absf(cover.z) > 0.05 else (1.0 if rng.randf() < 0.5 else -1.0)
	var r: float = rng.randf()
	var z: float = 0.0
	var y: float = 0.0
	var pwr: float = 0.0
	if r < 0.5:
		z = -near * rng.randf_range(1.0, half_goal - 0.45)
		y = rng.randf_range(0.5, goal_h - 0.4)
		pwr = rng.randf_range(0.55, 0.85)
	elif r < 0.85:
		z = near * rng.randf_range(1.2, half_goal - 0.5)
		y = rng.randf_range(1.6, goal_h - 0.3)
		pwr = rng.randf_range(0.6, 0.9)
	else:
		z = rng.randf_range(-2.4, 2.4)
		y = rng.randf_range(0.8, 2.0)
		pwr = rng.randf_range(0.85, 1.0)
	return synthetic_params(Vector3(gx, y, z), pwr, rng.randf_range(-0.22, 0.22))

# --- Duelo local (dos jugadores en el mismo telefono) ---------------------------------------------------------------------

## Nombre del jugador del equipo t (0 o 1).
static func local_name(t: int) -> String:
	return String(LocalDuel.NAMES[clampi(t, 0, 1)])

## Cortina de pantalla completa para pasar el telefono: tapa la escena (y el sector elegido) hasta que el siguiente toca
## el boton. Bloquea los toques al campo mientras esta.
func _build_curtain() -> void:
	_curtain = ColorRect.new()
	_curtain.name = "HandoffCurtain"
	_curtain.color = Color(0.02, 0.04, 0.09, 0.97)
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	_curtain.visible = false
	hud.root.add_child(_curtain)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = -170
	box.offset_bottom = 170
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	_curtain.add_child(box)
	_curtain_title = Label.new()
	_curtain_title.add_theme_font_size_override("font_size", 46)
	_curtain_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	_curtain_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_curtain_title)
	_curtain_text = Label.new()
	_curtain_text.add_theme_font_size_override("font_size", 26)
	_curtain_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_curtain_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_curtain_text)
	_curtain_btn = Button.new()
	_curtain_btn.focus_mode = Control.FOCUS_NONE
	_curtain_btn.custom_minimum_size = Vector2(320, 84)
	_curtain_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_curtain_btn.add_theme_font_size_override("font_size", 30)
	_curtain_btn.pressed.connect(func() -> void: _on_action(_curtain_action))
	box.add_child(_curtain_btn)

func _show_curtain(title: String, text: String, action: StringName, button: String) -> void:
	_curtain_title.text = title
	_curtain_text.text = text
	_curtain_btn.text = button
	_curtain_action = action
	_curtain.visible = true

func curtain_visible() -> bool:
	return _curtain != null and _curtain.visible

## Turno local: primero ataja (elige el sector en secreto) y despues patea el otro. Empieza con la cortina del arquero.
func _local_begin_turn(round_txt: String) -> void:
	var t: int = 0 if user_shooting else 1
	var k: int = 1 - t
	local_step = 1
	phase = Phase.KEEPER_PICK
	_pick_t = 0.0
	_keeper_zone = Vector3.INF
	picked_zone = -1
	_zone_marker.visible = false
	show_zone_grid(false)
	hud.set_actions([])
	hud.set_zoom_visible(false)
	hud.set_hint("")
	var g: Array = SpCamera.behind_goal(Vector3(gx, 0.0, 0.0), ball_spot)
	cam.frame(g[0], g[1], g[2], true, 0.45)
	_show_curtain("%s · ATAJA %s" % [round_txt, local_name(k)], "%s: elegí en secreto el sector al que te vas a tirar.\n%s: no mires la pantalla." % [
		local_name(k), local_name(t)], &"local_keeper_ready", "ESTOY LISTO")

func _local_keeper_ready() -> void:
	if local_step != 1:
		return
	_curtain.visible = false
	local_step = 2
	_pick_t = 0.0
	show_zone_grid(true)
	hud.set_hint("%s: tocá uno de los 9 sectores del arco para tirarte" % local_name(0 if not user_shooting else 1))

## El arquero ya eligio: la cortina tapa el sector (ni la grilla ni la marca quedan a la vista) y pasa el telefono.
func _local_handoff_shooter() -> void:
	local_step = 3
	show_zone_grid(false)
	_zone_marker.visible = false
	hud.set_hint("")
	var t: int = 0 if user_shooting else 1
	_show_curtain("PATEA %s" % local_name(t), "%s ya eligió dónde atajar.\nPasale el teléfono a %s." % [local_name(1 - t), local_name(t)],
		&"local_shooter_ready", "A PATEAR")

func _local_shooter_ready() -> void:
	if local_step != 3:
		return
	_curtain.visible = false
	local_step = 4
	phase = Phase.AIM
	var t: int = 0 if user_shooting else 1
	if mode == Mode.PENALTY:
		var f: Array = SpCamera.behind_ball(ball_spot, goal_center(), 1.0, true)
		cam.frame(f[0], f[1], f[2], true, 0.45)
	else:
		_aim_camera()
		hud.set_zoom_visible(true)
	_aim_actions()
	hud.set_hint("%s: deslizá el dedo desde la pelota hacia donde querés que vaya" % local_name(t))

## Tiro de la CPU cuando el usuario ya eligio donde tirarse (penal o tiro libre por turnos).
func _cpu_shot() -> void:
	if mode == Mode.FREE_KICK:
		_cpu_free_kick()
	else:
		_cpu_penalty()

## Botones mientras se apunta: cambiar de pie (diestro / zurdo) y, en el tiro libre, mover la pelota.
func _aim_actions() -> void:
	var list: Array = [[&"foot", "Pie: %s" % SpSettings.foot_name()]]
	if mode == Mode.FREE_KICK and not fk_duel():
		list.push_front([&"move", "Mover balón"])
	elif mode == Mode.CHALLENGE:
		list.push_front([&"quit", "Salir"])
	hud.set_actions(list)

## Cambia el pie habil del tirador del usuario y lo vuelve a parar del lado que corresponde.
func toggle_foot() -> void:
	if phase != Phase.AIM or not (user_shooting or vs == Vs.LOCAL):
		return
	if vs == Vs.LOCAL and not user_shooting:
		# Jugador 2: cambia su pie sin tocar el ajuste guardado del usuario.
		cur_shooter.foot = -cur_shooter.foot
		var aim2: Vector3 = Vector3(1, 0, 0) if mode == Mode.PENALTY else Vector3(gx - ball_spot.x, 0.0, -ball_spot.z).normalized()
		var st2: Vector2 = PEN_STANCE if mode == Mode.PENALTY else FK_STANCE
		cur_shooter.stance(ball_spot, aim2, st2.x, st2.y)
		hud.set_actions([[&"foot", "Pie: %s" % ("derecho" if cur_shooter.foot > 0 else "izquierdo")]])
		return
	SpSettings.foot = -SpSettings.foot
	SpSettings.save_settings()
	user_shooter.foot = SpSettings.foot
	var aim: Vector3 = Vector3(1, 0, 0) if mode == Mode.PENALTY else Vector3(gx - ball_spot.x, 0.0, -ball_spot.z).normalized()
	var st: Vector2 = PEN_STANCE if mode == Mode.PENALTY else FK_STANCE
	user_shooter.stance(ball_spot, aim, st.x, st.y)
	_aim_actions()

func set_zoom(z: float) -> void:
	zoom = clampf(z, 0.6, 1.7)
	if phase == Phase.AIM and _fk_like():
		_aim_camera()

func _aim_camera() -> void:
	var f: Array = SpCamera.behind_ball(ball_spot, goal_center(), zoom, false)
	cam.frame(f[0], f[1], f[2], false, 0.45)

# --- Tiro --------------------------------------------------------------------------------------------------------------

func _reset_play() -> void:
	outcome = ""
	_cinematic_on = false
	if celebration != null:
		celebration.clear()
	if cam != null:
		cam.stop_shake()
	_goal_scored = false
	_post_hit = false
	_wall_hit = false
	_keeper_touch = &""
	_flight_t = 0.0
	_decide_t = 0.0
	_settle_t = -1.0
	_committed = false
	chaser = null
	_keeper_ball_done = false
	if loose != null:
		loose.stop()
	last_shot = {}
	stadium.reset_goal_latches()
	if ball.is_held():
		ball.release(null)

## Contexto fisico del tiro para el modelo del gesto (attrs: atributos del tirador; la potencia sube la velocidad maxima).
func shot_context(attrs: Dictionary = {}) -> Dictionary:
	return GestureShotModel.context(gx, AttributeEffects.speed_range(PEN_SPEED if _penalty_like() else FK_SPEED, attrs),
		_penalty_like(), half_goal, goal_h, ball.radius)

## Atributos que valen para el tirador / arquero del usuario en esta partida (neutros en el duelo local).
func _shooter_attrs() -> Dictionary:
	return {} if vs == Vs.LOCAL else user_attrs

## Coeficientes del gesto del usuario: los del juego escalados por sus atributos (AttributeEffects.tuning_for).
func _user_tuning() -> GestureTuning:
	return AttributeEffects.tuning_for(GestureTuning.current(), _shooter_attrs())

## Lanza el tiro descrito por `p` (ya resuelto con la fisica): aplica el error de precision, clasifica el resultado previsto
## (un tiro que se va fuera usa un golpeo «de error»), elige el golpeo por pie, direccion, potencia y tipo, y ejecuta la
## carrera. El impulso a la pelota se da en el instante de contacto del pie del clip (SpShooter).
func _take_shot(shooter: SpShooter, p: ShotParams, error_deg: float) -> void:
	# Atributos del tirador (solo los del usuario; la CPU y el duelo local, neutros).
	var attrs: Dictionary = _shooter_attrs() if shooter == user_shooter else {}
	if p.velocity == Vector3.ZERO:
		GestureShotModel.solve(p, ball_spot, shot_context(attrs), false)
	if p.velocity == Vector3.ZERO:
		return
	# Estilo de golpeo del usuario: solo sesga la eleccion del clip (la salida de la pelota ya esta resuelta y no cambia).
	if shooter == user_shooter:
		PlayerCustom.bias(p)
	# Error de precision: la tecnica lo baja en los tiros tecnicos y la altura achica su parte vertical.
	var v: Vector3 = ShotSolver.perturb(p.velocity, error_deg * AttributeEffects.type_error_factor(attrs, p.gesture_type), rng,
		AttributeEffects.pitch_ratio(attrs))
	var traj: PackedVector3Array = BallPredictor.trajectory(ball_spot, v, 3.5, 1.0 / 60.0, p.spin, true)
	var cross: Vector3 = ShotSolver.crossing(traj, gx)
	var cls: String = ShotSolver.classify(cross, half_goal, goal_h, ball.radius)
	var dir := Vector3(v.x, 0.0, v.z).normalized()
	var center_dir := Vector3(gx - ball_spot.x, 0.0, -ball_spot.z).normalized()
	var app: Vector3 = ShotCatalog.approach_dir(center_dir, shooter.foot)
	var rel: float = ShotCatalog.signed_deg(app, dir)
	var side: float = ShotCatalog.signed_deg(center_dir, dir) * float(shooter.foot)
	var kind: int = p.kind
	if kind != ShotCatalog.Kind.CHIP and cls in ["wide", "high", "short"]:
		kind = ShotCatalog.Kind.MISS
	elif kind == ShotCatalog.Kind.NORMAL and side > 2.0 and p.power < 0.6:
		# Hacia su lado abierto (diestro a su derecha) sin mucha potencia: interior del pie, colocada.
		kind = ShotCatalog.Kind.PLACED
	var surface: String = ShotCatalog.surface_for(kind, shooter.foot, side > 2.0, p.curled, p.lateral_spin)
	var e: Dictionary = ShotCatalog.choose(shooter.foot, rel, kind, not _penalty_like(), rng, v.length(), p.prefer_short, p.curled, surface)
	if e.is_empty():
		e = ShotCatalog.choose(shooter.foot, rel, ShotCatalog.Kind.NORMAL, false, rng)
	var flotado: bool = p.power > 0.82 and absf(p.lateral_spin) < 6.0 and kind != ShotCatalog.Kind.CHIP
	last_shot = {"velocity": v, "spin": p.spin, "traj": traj, "class": cls, "power": p.power, "kind": kind, "entry": e,
		"target": p.target, "cross": cross, "dir": dir, "params": p, "surface": surface}
	last_params = p
	shooter.execute(e, ball_spot, dir, v, p.spin, flotado)
	recording.start()
	phase = Phase.RUNUP
	_runup_t = 0.0
	preview.hide_path()
	hud.hide_gesture()
	hud.set_hint("")
	hud.set_actions([])
	hud.set_zoom_visible(false)
	_committed = false
	_launch_measure = -1
	# Penal: el arquero se juega YA (lo pesado se calcula al soltar el trazo, no en el golpe), con el tiempo exacto que
	# falta para el contacto.
	if online_match != null and shooter == user_shooter:
		# Online: el arquero rival se juega a su zona cuando el servidor la revela (al recibir este tiro).
		_committed = true
		online_match.on_user_shot(cross, cls)
	elif (_penalty_like() or fk_duel()) and cur_keeper != null and cur_keeper.actor.visible:
		_commit_keeper(maxf(shooter.time_to_contact(), 0.0))

func _on_contact(_entry: Dictionary) -> void:
	phase = Phase.FLIGHT
	_flight_t = 0.0
	_launch_measure = 2
	# La zona elegida para atajar ya no se muestra: la pelota salio.
	_zone_marker.visible = false
	show_zone_grid(false)
	recording.mark(&"contacto")
	if mode == Mode.CHALLENGE:
		if cur_keeper.actor.visible:
			if _penalty_like():
				if not _committed:
					_commit_keeper(0.0)
				cur_keeper.on_kick(ball_spot, last_shot["velocity"])
				cur_keeper.sure_save_check(last_shot["traj"], 1.0 / 60.0)
			else:
				cur_keeper.read_shot(ball_spot, last_shot["velocity"], last_shot["spin"])
		if not wall.players.is_empty() and wall.players[0].visible:
			wall.on_kick(ball_spot, last_shot["velocity"])
	elif fk_duel():
		# Por turnos: los dos arqueros (usuario e IA) se juegan a un sector antes del golpe y ataja el sector correcto al
		# alcance (la misma regla que en los penales); la barrera y los sueltos juegan igual que en la practica.
		if not _committed:
			_commit_keeper(0.0)
		cur_keeper.on_kick(ball_spot, last_shot["velocity"])
		cur_keeper.sure_save_check(last_shot["traj"], 1.0 / 60.0)
		wall.on_kick(ball_spot, last_shot["velocity"])
		field.on_kick(last_shot["traj"], 1.0 / 60.0)
	elif mode == Mode.FREE_KICK:
		cur_keeper.read_shot(ball_spot, last_shot["velocity"], last_shot["spin"])
		wall.on_kick(ball_spot, last_shot["velocity"])
		field.on_kick(last_shot["traj"], 1.0 / 60.0)
	else:
		if not _committed:
			_commit_keeper(0.0)
		cur_keeper.on_kick(ball_spot, last_shot["velocity"])
		# Zona segura: si el tiro real va a la zona a la que se jugo el arquero, la ataja.
		cur_keeper.sure_save_check(last_shot["traj"], 1.0 / 60.0)

## Grilla tactil de los 9 sectores sobre el plano del arco (un poco hacia el campo, para que no la tape la red): celdas
## translucidas con una separacion que dibuja las lineas; la elegida se pinta. Se ve de los dos lados (camara detras del
## arco al atajar).
func _build_zone_grid() -> void:
	_zone_grid = Node3D.new()
	_zone_grid.name = "ZoneGrid"
	add_child(_zone_grid)
	_zone_cells.clear()
	for i in KeeperZones.COUNT:
		var rc: Array = KeeperZones.rect(i, half_goal, goal_h)
		var q := QuadMesh.new()
		q.size = Vector2(float(rc[2]) - float(rc[0]) - 0.07, float(rc[3]) - float(rc[1]) - 0.07)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.rotation.y = PI * 0.5
		var c: Vector3 = KeeperZones.center(i, gx, half_goal, goal_h)
		mi.position = Vector3(gx - 0.06, c.y, c.z)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_zone_grid.add_child(mi)
		_zone_cells.append(mi)
	_paint_zone_grid(-1)
	_zone_grid.visible = false

## Pinta la grilla: el sector elegido resaltado, los demas apenas marcados.
func _paint_zone_grid(chosen: int) -> void:
	for i in _zone_cells.size():
		var m: StandardMaterial3D = _zone_cells[i].material_override
		m.albedo_color = Color(1.0, 0.82, 0.18, 0.5) if i == chosen else Color(1.0, 1.0, 1.0, 0.13)

## Muestra u oculta la grilla de sectores (oculta: tambien se olvida el resaltado).
func show_zone_grid(on: bool) -> void:
	if _zone_grid == null:
		return
	_zone_grid.visible = on
	if not on:
		_paint_zone_grid(-1)

## Elige el sector i para atajar: el arquero se juega al centro del sector (KeeperZones.center).
func pick_sector(i: int) -> void:
	if i < 0 or i >= KeeperZones.COUNT:
		return
	picked_zone = i
	var c: Vector3 = KeeperZones.center(i, gx, half_goal, goal_h)
	_keeper_zone = c
	_pick_t = 0.0
	_paint_zone_grid(i)
	_zone_marker.visible = true
	_zone_marker.global_position = c + Vector3(-0.08, 0, 0)
	hud.set_hint("Te tirás %s · ¡Listo! Esperá el tiro" % KeeperZones.name_of(i))

## Penal: el arquero se juega antes del contacto (lead = segundos que faltan).
func _commit_keeper(lead: float) -> void:
	_committed = true
	# Velocidad que se espera por la carrera y el impulso del tirador (aproximada, no el destino del tiro).
	var v: Vector3 = last_shot.get("velocity", Vector3(20, 0, 0))
	var speed_guess: float = v.length() * rng.randf_range(0.88, 1.12)
	if user_shooting and vs != Vs.LOCAL:
		# La IA lee el cuerpo del tirador: la direccion de su carrera y cadera (la del golpeo elegido), no el resultado.
		var dir: Vector3 = last_shot.get("dir", Vector3(1, 0, 0))
		var cue: Vector3 = ball_spot + dir * ((gx - ball_spot.x) / maxf(dir.x, 0.2))
		cur_keeper.guess_penalty(cue, ball_spot, lead, speed_guess)
	elif _keeper_zone != Vector3.INF:
		cur_keeper.commit_to(_keeper_zone, ball_spot, lead, speed_guess)

# --- Paso ----------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_crowd(delta)
	if _launch_measure > 0:
		_launch_measure -= 1
		if _launch_measure == 0:
			last_launch_speed = ball.linear_velocity.length()
			if diag.visible:
				diag.show_shot(last_features, last_params, String(last_shot.get("entry", {}).get("id", "")), last_launch_speed)
	if phase == Phase.AIM and _swiping:
		_update_preview(delta)
	match phase:
		Phase.KEEPER_PICK:
			_pick_t += delta
			if vs == Vs.LOCAL:
				# Duelo local: sin tiempo limite; con el sector elegido, la cortina pasa el telefono al que patea.
				if local_step == 2 and _keeper_zone != Vector3.INF and _pick_t > 0.6:
					_local_handoff_shooter()
			elif online_match != null:
				# Online: la eleccion va al servidor (oculta para el rival) y despues patea el rival (bot o humano).
				if _keeper_zone != Vector3.INF and _pick_t > 0.5 and not _online_pick_sent:
					_online_pick_sent = true
					online_match.on_user_keeper_pick(_keeper_zone)
			elif (_keeper_zone != Vector3.INF and _pick_t > 0.5) or _pick_t > 6.0:
				if _keeper_zone == Vector3.INF:
					_keeper_zone = Vector3(gx, 1.0, 0.0)
				_cpu_shot()
		Phase.RUNUP:
			# Camara de TV: al soltar el trazo el plano pasa a la transmision lateral.
			if _tv_on():
				_tv_frame(0.35)
			# Seguro: ningun tiro puede quedar trabado en la carrera.
			_runup_t += delta
			if _runup_t > 6.0:
				cur_shooter.force_contact()
		Phase.FLIGHT:
			_flight_tick(delta)
		Phase.RESULT, Phase.OVER:
			_keeper_with_ball()
		Phase.REPLAY:
			_replay_step()
			return
	match phase:
		Phase.RESULT:
			_result_t += delta
			var wait: float = 0.2 if fast else (2.4 if mode == Mode.CHALLENGE else 3.6)
			# Gol: festejo en la camara de juego y despues el primer plano del autor (si nadie lo salta).
			if not fast and mode != Mode.CHALLENGE and outcome == "goal":
				wait = GOAL_LIVE_T + GOAL_CINEMATIC_T
				# Si los compañeros todavia corren al autor (el circulo central esta lejos en el penal), el festejo no se
				# corta a mitad de camino: se espera a que se encuentren (tope 8,5 s; «Saltar» sigue disponible).
				if celebration.active():
					wait = maxf(wait, 8.5)
				if _result_t >= GOAL_LIVE_T and not _cinematic_on:
					_goal_cinematic()
			# Penal: si el arquero esta yendo a recoger la pelota suelta o todavia se levanta para reaccionar, se le deja
			# terminar (hasta 6 s): antes el turno siguiente cortaba la reaccion de un arquero que tardaba en levantarse.
			# Cuando su reaccion empieza, se ve al menos 1,2 s.
			if not fast and duel_like():
				if _keeper_react_at < 0.0 and cur_keeper.state == SpKeeper.State.REACT:
					_keeper_react_at = _result_t
				if loose.active() or cur_keeper.reaction_pending():
					wait = 6.0
				elif _keeper_react_at >= 0.0:
					wait = clampf(_keeper_react_at + 1.2, wait, 6.0)
			if _result_t >= wait:
				_after_result()

func _flight_tick(delta: float) -> void:
	_flight_t += delta
	if _tv_on() and not ball.is_held():
		_tv_frame(0.15)
	elif _fk_like() and not ball.is_held():
		# Tiro libre: la camara acompaña un poco la pelota (sin moverse de detras del tirador).
		var f: Array = SpCamera.behind_ball(ball_spot, goal_center(), zoom, false)
		var look: Vector3 = (f[1] as Vector3).lerp(ball.global_position, 0.35)
		cam.frame(f[0], look, f[2], false, 0.6)
	var p: Vector3 = ball.global_position
	if _goal_scored or goal.is_goal_now():
		_finish("goal")
		return
	var done: bool = false
	if ball.is_held():
		done = true
	elif p.x > gx + 0.3:
		done = true
	elif _flight_t > 0.8 and ball.linear_velocity.length() < 0.8:
		done = true
	elif _flight_t > 5.5:
		done = true
	elif p.x < ball_spot.x - 3.0 and _flight_t > 0.6:
		done = true
	elif _flight_t > 0.25 and _goal_impossible(delta):
		done = true
	if done:
		if _settle_t < 0.0:
			_settle_t = 0.1 if fast else 0.45
		_settle_t -= delta
		if _settle_t <= 0.0 and not _goal_scored:
			var why: String = "miss"
			if _keeper_touch != &"":
				why = "save"
			elif field != null and field.cleared():
				why = "cleared"
			elif _wall_hit:
				why = "wall"
			elif _post_hit:
				why = "post"
			_finish(why)

## Ya no puede ser gol: la pelota se aleja del arco (o va lenta) y su trayectoria prevista (BallPredictor: aire, botes y
## rodadura medidos de Ball) no vuelve a la boca del arco en 3 s. Asi el resultado sale enseguida tras un rebote del
## arquero, del palo o de la barrera, sin esperar a que la pelota se frene. Un tiro que todavia va hacia el arco NO se
## decide aqui (cruza la linea, lo atrapan o se va: condiciones de siempre). Se mira cada 0,1 s.
func _goal_impossible(delta: float) -> bool:
	_decide_t -= delta
	if _decide_t > 0.0:
		return false
	_decide_t = 0.1
	if ball.is_held():
		return false
	var v: Vector3 = ball.linear_velocity
	if v.x > 0.5 and v.length() > 4.0:
		return false
	Prof.begin(&"resultado (prediccion)")
	var traj: PackedVector3Array = BallPredictor.trajectory(ball.global_position, v, 3.0, 1.0 / 30.0, ball.angular_velocity, true)
	var impossible: bool = not traj.is_empty() and not _path_reaches_goal(traj)
	Prof.end(&"resultado (prediccion)")
	return impossible

func _path_reaches_goal(traj: PackedVector3Array) -> bool:
	for q in traj:
		if q.x >= gx - 0.3 and absf(q.z) <= half_goal + 0.3 and q.y <= goal_h + 0.3:
			return true
	if traj.size() >= 2 and traj[traj.size() - 1].x - traj[traj.size() - 2].x > 0.01:
		# Al final del horizonte todavia rueda hacia el arco: no se sabe.
		return true
	return false

func _finish(why: String) -> void:
	if phase != Phase.FLIGHT:
		return
	if online_match != null:
		why = online_match.outcome_for(why)
		online_match.after_result(why, user_shooting)
	outcome = why
	phase = Phase.RESULT
	_result_t = 0.0
	_keeper_react_at = -1.0
	recording.mark(&"resultado")
	if mode == Mode.CHALLENGE:
		_finish_challenge(why)
		return
	var goal_ok: bool = why == "goal"
	var texts := {"goal": ["¡GOOOL!", Color(0.35, 1.0, 0.45)], "save": ["¡ATAJADA!", Color(0.4, 0.75, 1.0)],
		"post": ["¡AL PALO!", Color(1.0, 0.8, 0.3)], "wall": ["¡BARRERA!", Color(1.0, 0.6, 0.3)],
		"cleared": ["¡DESPEJE!", Color(1.0, 0.6, 0.3)], "miss": ["¡AFUERA!", Color(1.0, 0.4, 0.4)]}
	var sub: String = ""
	if why == "goal" and _post_hit:
		sub = "Entró tras pegar en el palo"
	elif why == "goal" and _keeper_touch != &"":
		sub = "El arquero la tocó pero no alcanzó"
	elif why == "save":
		sub = "La atrapó" if _keeper_touch == &"catch" else "La desvió"
	elif why == "miss" and String(last_shot.get("class", "")) == "high":
		sub = "Por encima del travesaño"
	if vs == Vs.LOCAL:
		var st: int = 0 if user_shooting else 1
		texts["goal"] = ["¡GOL DE %s!" % local_name(st), Color(0.35, 1.0, 0.45)]
		texts["save"] = ["¡ATAJÓ %s!" % local_name(1 - st), Color(0.4, 0.75, 1.0)]
	elif not user_shooting and duel_like():
		texts["save"] = ["¡LA ATAJASTE!", Color(0.35, 1.0, 0.45)]
		texts["goal"] = ["GOL DE LA CPU", Color(1.0, 0.45, 0.45)]
	hud.show_banner(texts[why][0], texts[why][1], sub)
	# Logros y desafios diarios (no en partidas rapidas de prueba ni en el duelo local: dos jugadores en un telefono no
	# suman premios jugando entre ellos).
	if why == "save" and duel_like() and not user_shooting and vs != Vs.LOCAL:
		user_saves += 1
	if not fast and vs != Vs.LOCAL:
		if goal_ok and user_shooting:
			Achievements.event(&"gol")
			Achievements.event(&"gol_tl" if mode == Mode.FREE_KICK else &"gol_penal")
		elif why == "save" and duel_like() and not user_shooting:
			Achievements.event(&"atajada")
	# El publico festeja igual goles y atajadas (en el duelo local los dos son del usuario: festeja ambos).
	crowd_react((why == "goal" or why == "save") if vs == Vs.LOCAL else goal_ok == user_shooting, why)
	_keeper_ball_done = false
	# Pelota suelta en el area o cerca: el arquero va a recogerla o un defensor la despeja (ese no reacciona: juega).
	chaser = null
	if not goal_ok and not ball.is_held():
		var defs: Array = []
		if mode == Mode.FREE_KICK:
			defs.append_array(field.defenders)
			defs.append_array(wall.players)
		chaser = loose.start(cur_keeper, defs, mode == Mode.PENALTY)
	# Penal: el arquero festeja la atajada (o lamenta el gol) siempre; si la pelota quedo suelta en su area va a buscarla
	# DESPUES de festejar (festejo corto: ya sabe que tiene que ir).
	if mode == Mode.PENALTY:
		cur_keeper.react(not goal_ok)
	# Reacciones: el tirador festeja o se enoja; el arquero al reves; barrera, sueltos y banco tambien. Si alguno todavia
	# termina su golpeo o su estirada, la reaccion sale al terminar.
	cur_shooter.react(goal_ok)
	if mode == Mode.FREE_KICK and chaser != cur_keeper.actor:
		cur_keeper.react(not goal_ok)
	_start_celebration(why)
	# La camara se queda en la vista de juego (sin cinematica automatica). Gol: temblor suave mientras corren al autor y,
	# pasado GOAL_LIVE_T, el primer plano (si no se salta).
	cam.follow = null
	if goal_ok and not fast:
		cam.shake(GOAL_SHAKE, 1.8)
	var acts: Array = [[&"replay", "Repetición"]]
	if not fast:
		acts.push_front([&"skip", "Saltar"])
	hud.set_actions(acts)
	if local != null:
		local.record_shot(0 if user_shooting else 1, why)
	if duel_like():
		shootout.record(PenaltyShootout.USER if user_shooting else PenaltyShootout.CPU, goal_ok)
		hud.set_shootout(shootout.results[0], shootout.results[1], PenaltyShootout.REGULAR)
		hud.set_score_text("%d - %d" % [shootout.goals(0), shootout.goals(1)])
	else:
		fk_shots += 1
		if goal_ok:
			fk_goals += 1
		hud.set_score_text("Goles %d / %d" % [fk_goals, fk_shots])

## Festejos y lamentos por resultado (SpCelebration). Gol: los compañeros del autor corren hacia el (en el penal salen del
## circulo central y el autor va hacia ellos); los rivales se lamentan en el sitio. Sin gol: el equipo que defendio corre
## a festejar hacia donde termino la jugada (el arquero si atajo, la barrera si la paro, el punto por donde salio la pelota
## si fue al palo o afuera, el que despejo) y el que pateo se lamenta. El que fue por la pelota suelta no festeja: juega.
func _start_celebration(why: String) -> void:
	var goal_ok: bool = why == "goal"
	var shoot_team: int = 0 if user_shooting else 1
	var mates: Array[SpActor] = []
	var rivals: Array[SpActor] = []
	if mode == Mode.FREE_KICK:
		mates.append_array(field.attackers)
		rivals.append_array(field.defenders)
		rivals.append_array(wall.players)
	else:
		for b in bench:
			if b.team == shoot_team:
				mates.append(b)
			else:
				rivals.append(b)
	celebration.rng.seed = rng.randi()
	if goal_ok:
		celebration.goal(cur_shooter.actor, mates, mode == Mode.PENALTY)
		for a in rivals:
			celebration.react_here(a, SpReactions.SAD)
		return
	for a in mates:
		celebration.react_here(a, SpReactions.SAD)
	var center: Vector3 = _celebration_center(why)
	var runners: Array[SpActor] = []
	for a in rivals:
		if a == chaser:
			continue
		# La barrera que paro el tiro festeja ahi mismo; en el penal el circulo central esta a ~40 m: salen unos metros.
		if why == "wall" and wall != null and wall.players.has(a):
			celebration.react_here(a, SpReactions.HAPPY_DEFENDER)
		else:
			runners.append(a)
	for i in runners.size():
		var c: Vector3 = center
		if mode == Mode.PENALTY:
			var home: Vector3 = runners[i].global_position
			c = home + (Vector3(center.x, 0.0, center.z) - home).normalized() * 7.0
		celebration.gather(runners[i], c, SpReactions.HAPPY_DEFENDER, i, runners.size())

## Donde festeja el equipo que defendio: el arquero que atajo, la barrera, el que despejo o el punto (dentro de la cancha,
## frente al arco) por donde salio o pego la pelota. Sin acercarse a la pelota suelta: el que va por ella la juega.
func _celebration_center(why: String) -> Vector3:
	var b: Vector3 = ball.global_position
	match why:
		"save":
			var k: Vector3 = cur_keeper.actor.global_position
			return Vector3(k.x - 2.2, 0.0, k.z)
		"wall":
			var c := Vector3.ZERO
			for a in wall.players:
				c += a.global_position
			c /= float(maxi(wall.players.size(), 1))
			return Vector3(c.x + 1.5, 0.0, c.z)
		"cleared":
			if chaser != null:
				return Vector3(chaser.global_position.x - 3.0, 0.0, chaser.global_position.z)
	var p := Vector3(minf(b.x, gx - 2.5), 0.0, clampf(b.z, -half_goal - 6.0, half_goal + 6.0))
	if chaser != null and p.distance_to(Vector3(chaser.global_position.x, 0.0, chaser.global_position.z)) < 3.0:
		p.x -= 3.0
	return p

## Primer plano del autor del gol (despues de la vista de juego).
func _goal_cinematic() -> void:
	_cinematic_on = true
	var f: Vector3 = cur_shooter.actor.facing()
	cam.follow_node(cur_shooter.actor, f * 4.2 + SpClips.right_of(f) * 1.6 + Vector3.UP * 1.7, 1.1, 0.6)

## Saltar el festejo: la jugada siguiente enseguida (una sola vez; el gol ya esta contado).
func skip_celebration() -> void:
	if phase != Phase.RESULT:
		return
	cam.stop_shake()
	cam.follow = null
	_after_result()

## Con la jugada terminada y el arquero de pie con la pelota en las manos: en el penal la suelta a un costado y festeja;
## en el tiro libre la suelta y la saca lejos con el pie (SpLooseBall: golpeo del banco, impulso solo si el pie llega).
func _keeper_with_ball() -> void:
	if _keeper_ball_done or cur_keeper == null or not cur_keeper.ready_with_ball:
		return
	if not (ball.is_held() and ball.holder == cur_keeper.actor):
		return
	_keeper_ball_done = true
	var f: Vector3 = cur_keeper.actor.facing()
	if mode == Mode.PENALTY:
		cur_keeper.drop_ball(f * 1.2 + SpClips.right_of(f) * 0.9 + Vector3.UP * 1.2)
		cur_keeper.react(true)
	else:
		cur_keeper.drop_ball(f * 0.9 + Vector3.UP * 1.6)
		loose.keeper_kick(cur_keeper)

## Intensidad del publico segun la jugada (0..1): calma al apuntar (un poco mas baja en la carrera del penal), tension
## con la pelota en el aire, estallido con el gol y abucheo con un fallo (suben con _cheer y _boo). Sfx.crowd_db la pasa a
## volumen: aun en 0 el ambiente (murmullo y aliento) se escucha.
func crowd_target() -> float:
	var base: float = 0.45
	match phase:
		Phase.AIM, Phase.KEEPER_PICK:
			base = 0.12 if _penalty_like() else 0.35
		Phase.PLACE:
			base = 0.4
		Phase.RUNUP:
			base = 0.08 if _penalty_like() else 0.3
		Phase.FLIGHT:
			base = 0.35 + clampf(_flight_t * 0.6, 0.0, 0.3)
		Phase.RESULT, Phase.OVER:
			base = 0.5
	return clampf(base + _cheer * 0.5 + _boo * 0.35, 0.0, 1.0)

## Tension de la tribuna (0..1): en la carrera del penal todos quietos mirando.
func crowd_tension() -> float:
	if _penalty_like() and (phase == Phase.RUNUP or (phase == Phase.FLIGHT and _flight_t < 0.4)):
		return 1.0
	return 0.0

## Fija el animo del publico: festejo y abucheo (0..1) y cuanto tiempo quedan a pleno antes de apagarse.
func set_crowd_mood(cheer: float, boo: float, hold: float) -> void:
	_cheer = cheer
	_boo = boo
	_cheer_hold = hold if cheer > 0.0 else 0.0
	_boo_hold = hold if boo > 0.0 else 0.0

## Animo del publico actual: (festejo, abucheo).
func crowd_mood() -> Vector2:
	return Vector2(_cheer, _boo)

## Reaccion del publico a un resultado. good: bueno para el usuario (su gol, su atajada, un acierto del desafio): el
## MISMO festejo largo para goles y atajadas (pedido 2026-11-12). Si no (su fallo, un gol de la CPU), la tribuna se
## lamenta (manos a la cabeza, «uuuh»), sin silbidos.
func crowd_react(good: bool, _why: String, scale: float = 1.0) -> void:
	if good:
		set_crowd_mood(1.0 * scale, 0.0, 6.5 * scale)
		Sfx.play(&"cheer", 1.0 * scale)
	else:
		set_crowd_mood(0.0, 0.9 * scale, 3.5 * scale)
		Sfx.play(&"ooh", 0.8 * scale)

func _update_crowd(delta: float) -> void:
	if _cheer_hold > 0.0:
		_cheer_hold -= delta
	else:
		_cheer = maxf(_cheer - delta * CHEER_DECAY, 0.0)
	if _boo_hold > 0.0:
		_boo_hold -= delta
	else:
		_boo = maxf(_boo - delta * BOO_DECAY, 0.0)
	stadium.set_cheer(_cheer)
	stadium.set_boo(_boo)
	stadium.set_tension(crowd_tension())
	if stadium.banners != null:
		stadium.banners.set_mood(CrowdBanners.Mood.BOO if _boo > 0.25 else (CrowdBanners.Mood.GOAL if _cheer > 0.5 else CrowdBanners.Mood.CALM))
	Sfx.set_crowd_level(crowd_target())

# --- Repeticion -------------------------------------------------------------------------------------------------------------

## Controladores del juego que se pausan durante la repeticion (los jugadores los mueve el registro).
func _controllers() -> Array:
	var out: Array = []
	for n in [user_shooter, cpu_shooter, user_keeper, cpu_keeper, wall, field, loose, runner]:
		if n != null:
			out.append(n)
	return out

## Repite la ultima jugada: todo vuelve a estar donde estuvo, paso por paso (camara lenta alrededor del golpe y del
## resultado). Pausa el juego; al terminar lo deja como estaba.
func start_replay() -> void:
	if recording.frames() < 10 or phase == Phase.REPLAY or phase in [Phase.RUNUP, Phase.FLIGHT]:
		return
	recording.stop()
	_pre_replay = {"phase": phase, "result_t": _result_t, "xform": ball.global_transform, "freeze": ball.freeze,
		"freeze_mode": ball.freeze_mode, "v": ball.linear_velocity, "w": ball.angular_velocity, "held": ball.is_held(),
		"actors": recording.actors.map(func(a: SpActor) -> Array: return [a.global_position, a.rotation.y, a.visible, a.anim_player.current_animation, a.anim_player.current_animation_position])}
	for c in _controllers():
		c.process_mode = Node.PROCESS_MODE_DISABLED
	for a in recording.actors:
		a.set_physics_process(false)
	ball.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	ball.freeze = true
	phase = Phase.REPLAY
	replay_f = 0.0
	cam.follow = null
	hud.show_banner("REPETICIÓN", Color(1.0, 0.84, 0.28), "")
	_replay_actions()

func _replay_actions() -> void:
	hud.set_actions([[&"replay_cam", "Cámara: %s" % REPLAY_ANGLES[replay_angle]],
		[&"replay_slow", "Lenta: %s" % ("Sí" if replay_slowmo else "No")], [&"replay_skip", "Saltar"]])

## Camara de TV activa en esta jugada (opcion «Camara de TV», tiros libres).
func _tv_on() -> bool:
	return GraphicsSettings.tv_camera and _fk_like()

## Plano de transmision de TV: desde la tribuna lateral, alto, encuadrando la pelota y el arco y siguiendo la pelota.
func _tv_frame(hl: float) -> void:
	var b: Vector3 = ball.global_position
	var g: Vector3 = goal_center()
	var mid: Vector3 = b.lerp(g, 0.45)
	var span: float = Vector2(b.x - g.x, b.z - g.z).length()
	var dist: float = clampf(span * 0.75 + 10.0, 16.0, 30.0)
	var pos: Vector3 = Vector3(mid.x - 3.0, 7.0 + dist * 0.12, mid.z - dist)
	var fov: float = clampf(rad_to_deg(2.0 * atan((span * 0.5 + 4.0) / dist)), 30.0, 62.0)
	cam.frame(pos, mid + Vector3.UP * 0.6, fov, false, hl)

func _replay_step() -> void:
	var n: int = recording.frames()
	var c: int = int(recording.marks.get(&"contacto", 0))
	var r: int = int(recording.marks.get(&"resultado", n - 1))
	# Camara lenta desde un poco antes del golpe hasta un poco despues del resultado.
	var slow: bool = replay_slowmo and replay_f >= float(c - 12) and replay_f <= float(r + 30)
	recording.apply(replay_f)
	_replay_camera()
	replay_f += 0.4 if slow else 1.0
	if replay_f > float(n - 1):
		end_replay()

func _replay_camera() -> void:
	var b: Vector3 = ball.global_position
	match replay_angle:
		0:
			# Television: el mismo plano de transmision que la camara de TV del juego.
			_tv_frame(0.12)
		1:
			var f: Array = SpCamera.behind_ball(ball_spot, goal_center(), 1.0, _penalty_like())
			cam.frame(f[0], b.lerp(goal_center(), 0.3), f[2], false, 0.12)
		_:
			cam.frame(Vector3(gx + 7.0, 2.6, -2.0), b, 44.0, false, 0.12)

## Termina la repeticion: jugadores, pelota y fase como estaban antes.
func end_replay() -> void:
	if phase != Phase.REPLAY:
		return
	var st: Dictionary = _pre_replay
	for i in recording.actors.size():
		var a: SpActor = recording.actors[i]
		var s: Array = st["actors"][i]
		a.global_position = s[0]
		a.rotation.y = s[1]
		a.visible = s[2]
		if String(s[3]) != "":
			a.anim_player.play(StringName(s[3]), 0.0)
			a.anim_player.seek(float(s[4]), true)
		a.set_physics_process(true)
	ball.global_transform = st["xform"]
	ball.freeze_mode = st["freeze_mode"]
	ball.freeze = st["freeze"]
	if not bool(st["held"]):
		ball.linear_velocity = st["v"]
		ball.angular_velocity = st["w"]
	for c in _controllers():
		c.process_mode = Node.PROCESS_MODE_INHERIT
	phase = st["phase"]
	_result_t = float(st["result_t"])
	replay_f = -1.0
	hud.hide_banner()
	if phase == Phase.OVER and mode == Mode.FREE_KICK:
		hud.set_actions([[&"again", "Otra vez"], [&"move", "Mover balón"], [&"replay", "Repetición"]])
	elif phase == Phase.RESULT:
		hud.set_actions([[&"skip", "Saltar"], [&"replay", "Repetición"]])
		# Vuelve la camara del momento: el primer plano si ya habia empezado, si no la vista de juego.
		_cinematic_on = false
		if not (outcome == "goal" and _result_t >= GOAL_LIVE_T):
			var f: Array = SpCamera.behind_ball(ball_spot, goal_center(), zoom if _fk_like() else 1.0, _penalty_like())
			if mode == Mode.PENALTY and not user_shooting:
				f = SpCamera.behind_goal(Vector3(gx, 0.0, 0.0), ball_spot)
			cam.frame(f[0], f[1], f[2], false, 0.4)
	else:
		hud.set_actions([])

## Momento de la jugada para la medicion de rendimiento (PerfSession.MOMENTS).
func perf_moment() -> StringName:
	match phase:
		Phase.PLACE, Phase.AIM, Phase.KEEPER_PICK:
			return &"apuntando"
		Phase.RUNUP:
			return &"carrera"
		Phase.FLIGHT:
			if cur_keeper != null and cur_keeper.state in [SpKeeper.State.WAIT_DIVE, SpKeeper.State.DIVE]:
				return &"estirada"
			return &"vuelo"
		Phase.RESULT, Phase.OVER:
			if loose != null and loose.active():
				return &"despeje"
			if cur_keeper != null and cur_keeper.state == SpKeeper.State.DIVE:
				return &"estirada"
			return &"festejo" if phase == Phase.RESULT else &"otro"
	return &"otro"

func _toggle_perf_session() -> void:
	if perf_session.recording:
		perf_session.stop()
		perf.prof_external = false
		var path: String = perf_session.save_report()
		diag.perf_button.text = "Medir rendimiento"
		diag.show_text(perf_session.report() + ("\n\nGuardado en %s. Tocá «Copiar informe» y pegalo en el chat." % path))
	else:
		perf.prof_external = true
		perf_session.start()
		diag.perf_button.text = "Terminar medición"
		diag.show_text("Midiendo… jugá normalmente (apuntar, patear, gol o atajada, festejo) y después tocá «Terminar medición».")

func _copy_perf_report() -> void:
	DisplayServer.clipboard_set(perf_session.report())
	diag.show_text("Informe copiado al portapapeles.\n\n" + perf_session.report())

func _after_result() -> void:
	if phase != Phase.RESULT:
		return
	recording.stop()
	if mode == Mode.PENALTY:
		_start_penalty_turn()
	elif fk_duel():
		cam.follow = null
		cam.stop_shake()
		_start_fk_duel_turn()
	elif mode == Mode.CHALLENGE:
		if runner.finished:
			_show_challenge_end()
		else:
			cam.follow = null
			_setup_challenge_attempt()
	else:
		phase = Phase.OVER
		cam.follow = null
		cam.stop_shake()
		hud.set_actions([[&"again", "Otra vez"], [&"move", "Mover balón"], [&"replay", "Repetición"]])
		hud.set_hint("")
		if OnlineDuel.is_active() and mode == Mode.FREE_KICK:
			_online_duel_step()

## Tiros libres online contra bot (OnlineDuel): 5 tiros; despues del ultimo, el resultado contra el puntaje del bot.
var duel_shots: int = 0
var duel_goals: int = 0

func _online_duel_step() -> void:
	duel_shots += 1
	if outcome == "goal":
		duel_goals += 1
	var total: int = int(OnlineDuel.active.get("shots", 5))
	if duel_shots < total:
		hud.set_hint("Online contra %s: tiro %d de %d · goles %d (el bot hizo %d)" % [OnlineDuel.bot_name(), duel_shots, total,
			duel_goals, int(OnlineDuel.active.get("bot_points", 0))])
		return
	var od: Array = OnlineDuel.finish(duel_goals)
	hud.show_banner(String(od[0]), Color(1.0, 0.84, 0.28), String(od[1]))
	hud.set_actions([[&"menu", "Menú"], [&"replay", "Repetición"]])

# --- Academia y Arena (modo CHALLENGE) ----------------------------------------------------------------------------------

## Prepara un intento del ejercicio o desafio: pelota en su punto, barrera (o no), sin jugadores sueltos, arquero con la
## dificultad del desafio (o sin arquero), tirador al costado de la pelota.
func _setup_challenge_attempt() -> void:
	var d: Dictionary = runner.def
	hud.hide_banner()
	hud.hide_overlay()
	_place_marker.visible = false
	_reset_play()
	var sp: Array = d["spot"]
	ball_spot = Vector3(gx - float(sp[0]), ball.radius, float(sp[1]))
	ball.reset_at(ball_spot)
	var wl = d.get("wall", 0)
	var n: int = SpWall.count_for(ball_spot, gx) if typeof(wl) == TYPE_STRING and String(wl) == "auto" else int(wl)
	n = clampi(n, 0, wall_actors.size())
	var use: Array[SpActor] = []
	for i in wall_actors.size():
		wall_actors[i].visible = i < n
		if i < n:
			use.append(wall_actors[i])
		else:
			wall_actors[i].global_position = Vector3(0, -50, 0)
	wall.arrange(use, ball_spot, gx, half_goal)
	for a in field.attackers + field.defenders:
		a.visible = false
		a.stop_moving()
		a.global_position = Vector3(0, -50, 0)
	cur_shooter = user_shooter
	cur_keeper = cpu_keeper
	if int(d.get("keeper", -1)) >= 0:
		SpSettings.override_difficulty = int(d["keeper"])
		cpu_keeper.actor.visible = true
		if _penalty_like():
			cpu_keeper.reset(Vector3(gx - 0.12, 0.0, 0.0))
		else:
			var cover: Vector3 = SpWall.cover_point(ball_spot, gx, half_goal)
			var kz: float = clampf((-cover.z * 0.35 if n > 0 else 0.0) + ball_spot.z * 0.06, -1.2, 1.2)
			cpu_keeper.reset(Vector3(gx - 0.6, 0.0, kz))
	else:
		# Sin arquero: fuera de la cancha y quieto (no choca la pelota).
		SpSettings.override_difficulty = -1
		cpu_keeper.reset(Vector3(gx + 30.0, 0.0, 30.0))
		cpu_keeper.actor.visible = false
		cpu_keeper.paused = true
	user_shooter.actor.visible = true
	user_shooter.foot = SpSettings.foot
	var aim: Vector3 = Vector3(gx - ball_spot.x, 0.0, -ball_spot.z).normalized()
	var st: Vector2 = PEN_STANCE if _penalty_like() else FK_STANCE
	user_shooter.stance(ball_spot, aim, st.x, st.y)
	user_shooting = true
	phase = Phase.AIM
	if _penalty_like():
		var f: Array = SpCamera.behind_ball(ball_spot, goal_center(), 1.0, true)
		cam.frame(f[0], f[1], f[2], _first_frame(), 0.45)
	else:
		_aim_camera()
	hud.set_zoom_visible(_fk_like())
	_aim_actions()
	hud.set_hint(String(d["explain"]))
	hud.set_score_text(runner.status_text())
	runner.begin_attempt()

## Resultado de un intento del desafio: lo evalua el ChallengeRunner con los blancos; reacciones de siempre.
func _finish_challenge(why: String) -> void:
	runner.targets.flush()
	var ev: Dictionary = runner.evaluate(why, last_launch_speed)
	hud.show_banner(String(ev["text"]), ev["color"], String(ev["sub"]))
	crowd_react(bool(ev["hit"]), why, 0.7)
	cur_shooter.react(bool(ev["hit"]))
	if cur_keeper.actor.visible:
		cur_keeper.react(why != "goal")
	if wall != null and not wall.players.is_empty():
		wall.react(why == "goal")
	hud.set_score_text(runner.status_text())

## Fin del ejercicio o desafio: puntos, medalla, record, experiencia, recompensa y que hacer despues.
func _show_challenge_end() -> void:
	phase = Phase.OVER
	var r: Dictionary = runner.finish()
	var medal: int = int(r["medal"])
	var title: String = ["SIN MEDALLA", "¡BRONCE!", "¡PLATA!", "¡ORO!"][medal]
	var lines: PackedStringArray = []
	lines.append("%d puntos · %s %d/%d en %d intentos" % [int(r["score"]), "caídos" if String(runner.def["rule"]) == "objects" else "aciertos",
		int(r["progress"]), int(r["needed"]), int(r["attempts_used"])])
	if int(r["spare_bonus"]) > 0:
		lines.append("Intentos de sobra: +%d" % int(r["spare_bonus"]))
	if bool(r["practice"]):
		lines.append("Práctica libre: no cuenta para el progreso (récord %d)" % int(r["prev_best"]))
	elif bool(r["new_best"]):
		lines.append("¡Nuevo récord! (antes %d)" % int(r["prev_best"]))
	else:
		lines.append("Récord: %d" % int(r["best"]))
	if int(r["xp_gained"]) > 0:
		lines.append("+%d de experiencia · nivel %d" % [int(r["xp_gained"]), int(r["level"])])
	if String(r["cosmetic"]) != "":
		lines.append("Recompensa: %s" % String(r["cosmetic"]))
	var acts: Array = [[&"retry", "Reintentar"]]
	if not next_challenge_def().is_empty():
		acts.append([&"next", "Siguiente"])
	acts.append([&"challenges", "Elegir otro"])
	acts.append([&"menu", "Menú"])
	hud.set_actions([])
	hud.show_overlay(title, "\n".join(lines), acts)
	if not bool(r["practice"]) and not fast and medal >= 1:
		Achievements.event(&"desafio")
		if medal >= 3:
			Achievements.event(&"oro")
	if medal >= 1:
		set_crowd_mood(1.0, 0.0, 5.0)

## El siguiente: Academia = el ejercicio que sigue (si esta abierto); Arena = la dificultad siguiente si se abrio, si no
## el desafio que sigue en Facil.
func next_challenge_def() -> Dictionary:
	if runner == null:
		return {}
	var d: Dictionary = runner.def
	if String(d.get("group", "")) == "academia":
		var all: Array = ChallengeCatalog.academia()
		for i in all.size():
			if String(all[i]["id"]) == String(d["id"]) and i + 1 < all.size():
				return all[i + 1] if (runner.practice or PlayerProgress.is_unlocked(all[i + 1])) else {}
		return {}
	var base: Dictionary = ChallengeCatalog.by_id(String(d["id"]))
	var dif: int = int(d.get("difficulty", 0))
	if dif < 4 and PlayerProgress.difficulty_unlocked(base, dif + 1):
		return ChallengeCatalog.at_difficulty(base, dif + 1)
	var all2: Array = ChallengeCatalog.arena()
	for i in all2.size():
		if String(all2[i]["id"]) == String(d["id"]) and i + 1 < all2.size():
			return ChallengeCatalog.at_difficulty(all2[i + 1], 0)
	return {}

func _show_end() -> void:
	phase = Phase.OVER
	var w: int = shootout.winner()
	if online_match != null:
		var uw: Variant = online_match.server_user_won()
		w = -1 if uw == null else (PenaltyShootout.USER if bool(uw) else PenaltyShootout.CPU)
	var t: String = "¡GANASTE!" if w == PenaltyShootout.USER else ("EMPATE" if w == -1 else "PERDISTE")
	hud.set_hint("")
	show_zone_grid(false)
	if local != null:
		local.record_match(w)
		set_crowd_mood(1.0, 0.0, 8.0)
		hud.show_overlay("¡GANÓ %s!" % local_name(w) if w >= 0 else "EMPATE", "%s  %d - %d\n%s" % [
			"Tanda de penales" if mode == Mode.PENALTY else "Duelo de tiros libres", shootout.goals(0), shootout.goals(1),
			local.summary()], [[&"rematch", "Revancha"], [&"menu", "Menú"]])
		return
	hud.show_overlay(t, "%s  %d - %d" % ["Tanda de penales" if mode == Mode.PENALTY else "Duelo de tiros libres", shootout.goals(0), shootout.goals(1)],
		[[&"menu", "Menú"]] if online_match != null else [[&"rematch", "Revancha"], [&"menu", "Menú"]])
	if online_match != null:
		online_match.on_end(w == PenaltyShootout.USER)
	if w == PenaltyShootout.USER:
		set_crowd_mood(1.0, 0.0, 8.0)
		Sfx.play(&"cheer", 1.0)
		if not fast:
			Achievements.event(&"tanda")
	if not fast and online_match == null:
		# Partida offline: al servidor solo va si gano (el premio lo calcula el servidor).
		OnlineHooks.reward("offline_match", {"mode": "penales" if mode == Mode.PENALTY else "tiros_libres", "won": w == PenaltyShootout.USER,
			"goals": shootout.goals(0), "saves": user_saves})

func _on_goal_scored(g: Goal, pos: Vector3) -> void:
	if g == goal and phase == Phase.FLIGHT:
		_goal_scored = true
		if runner != null:
			runner.targets.on_goal(pos)

func _on_keeper_touch(kind: StringName) -> void:
	_keeper_touch = kind

func _on_ball_body(body: Node) -> void:
	var p: Node = body.get_parent()
	if p is SpActor and (p as SpActor).role == &"wall":
		_wall_hit = true

# --- Entrada -----------------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
			_pinch_d = -1.0
		if _touches.size() >= 2:
			_swiping = false
			hud.set_trail(PackedVector2Array())
			return
		_on_press(st.position, st.pressed)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2 and _fk_like() and phase == Phase.AIM:
			var pts: Array = _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_d > 0.0:
				set_zoom(zoom * d / _pinch_d)
			_pinch_d = d
			return
		_on_drag(sd.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			set_zoom(zoom * 1.08)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			set_zoom(zoom / 1.08)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _screen_h() -> float:
	return get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0

func _on_press(pos: Vector2, pressed: bool) -> void:
	match phase:
		Phase.PLACE:
			if pressed:
				_place_at(pos)
		Phase.KEEPER_PICK:
			if pressed and (vs != Vs.LOCAL or local_step == 2):
				_pick_zone(pos)
		Phase.AIM:
			if pressed:
				_swiping = true
				gesture.tuning = _user_tuning()
				gesture.begin(pos, _now(), _screen_h())
				_preview_t = 0.0
			elif _swiping:
				_swiping = false
				gesture.finish(pos, _now())
				hud.set_trail(PackedVector2Array())
				preview.hide_path()
				hud.hide_gesture()
				_user_shot_from_gesture()

func _on_drag(pos: Vector2) -> void:
	if phase == Phase.PLACE:
		_place_at(pos)
	elif phase == Phase.AIM and _swiping:
		if gesture.add(pos, _now()):
			hud.set_trail(gesture.points_px())

## Vista previa en tiempo real (limitada a PREVIEW_HZ): mismo modelo y misma fisica que el tiro.
func _update_preview(delta: float) -> void:
	_preview_t -= delta
	if _preview_t > 0.0 or gesture.count() < 3:
		return
	_preview_t = 1.0 / PREVIEW_HZ
	var f: Dictionary = gesture.features()
	if float(f["length"]) < gesture.tuning.min_length * 0.6:
		preview.hide_path()
		hud.hide_gesture()
		return
	var p: ShotParams = GestureShotModel.build(f, gesture.last_px(), cam, ball_spot, shot_context(_shooter_attrs()), gesture.tuning)
	GestureShotModel.solve(p, ball_spot, shot_context(_shooter_attrs()), true)
	# «Mostrar linea de destino» apagada: no se dibuja la trayectoria ni el aro (la fisica y el tiro son los mismos; el
	# rastro del dedo y los medidores siguen).
	if GraphicsSettings.show_aim_line:
		preview.show_path(p.trajectory, gx, p.power, cam.global_position, p.crossing)
	else:
		preview.hide_path()
	hud.show_gesture(p.power, p.target.y / goal_h, clampf(p.lateral_spin / gesture.tuning.spin_max, -1.0, 1.0), _type_label(p.gesture_type))

static func _type_label(t: String) -> String:
	return {"potente_raso": "Potente y raso", "colocado": "Colocado", "globo": "Globo / vaselina", "con_efecto": "Con efecto",
		"rapido_corto": "Rápido y corto", "elevado": "Elevado", "precision": "De precisión", "normal": "Normal",
		"invalido": "Trazo muy corto"}.get(t, t)

func _place_at(screen: Vector2) -> void:
	var o: Vector3 = cam.project_ray_origin(screen)
	var d: Vector3 = cam.project_ray_normal(screen)
	if d.y > -1e-3:
		return
	var p: Vector3 = o + d * (-o.y / d.y)
	ball_spot = clamp_free_kick_spot(p)
	ball.reset_at(ball_spot)
	_place_marker.global_position = Vector3(ball_spot.x, 0.02, ball_spot.z)
	var dist: float = Vector2(gx - ball_spot.x, ball_spot.z).length()
	hud.set_hint("Distancia al arco: %.0f m · Confirmá para patear" % dist)

func _pick_zone(screen: Vector2) -> void:
	var o: Vector3 = cam.project_ray_origin(screen)
	var d: Vector3 = cam.project_ray_normal(screen)
	if absf(d.x) < 1e-4:
		return
	var t: float = (gx - o.x) / d.x
	var p: Vector3 = o + d * t
	p.x = gx
	p.y = clampf(p.y, 0.05, goal_h - 0.05)
	p.z = clampf(p.z, -half_goal + 0.05, half_goal - 0.05)
	# Toque sobre la grilla: el sector que lo contiene (KeeperZones, 3 x 3). La atajada segura depende de ese sector y del
	# alcance fisico (KeeperReach).
	pick_sector(KeeperZones.zone_of(p, half_goal, goal_h))

## Tiro del usuario desde el gesto: propiedades -> parametros -> fisica -> golpeo.
func _user_shot_from_gesture() -> void:
	var f: Dictionary = gesture.features()
	last_features = f
	var p: ShotParams = GestureShotModel.build(f, gesture.last_px(), cam, ball_spot, shot_context(_shooter_attrs()), gesture.tuning)
	if p.gesture_type == "invalido" or not (float(f["vertical"]) > 0.0 or absf(float(f["horizontal"])) > float(f["length"]) * 0.5):
		hud.set_hint("Trazo muy corto: deslizá desde la pelota hacia el arco")
		return
	shoot_params(p)

## Tiro con parametros ya armados (gesto, IA o pruebas).
func shoot_params(p: ShotParams) -> void:
	if phase != Phase.AIM:
		return
	GestureShotModel.solve(p, ball_spot, shot_context(_shooter_attrs()), false)
	# Duelo local: patea el jugador al que le toca (el tirador del equipo 1 es el del segundo jugador).
	_take_shot(cur_shooter if vs == Vs.LOCAL else user_shooter, p, p.error_deg)
	if diag.visible:
		diag.show_shot(last_features, p, String(last_shot.get("entry", {}).get("id", "")), -1.0)

## Tiro sin trazo (pruebas y capturas): objetivo en el arco, potencia 0..1 y curvatura del trazo (+ derecha). Arma los
## parametros con el mismo modelo que un gesto largo y limpio.
func shoot(target: Vector3, pwr: float, curve: float) -> void:
	var t: GestureTuning = GestureTuning.current()
	var f := {"length": t.length_full, "avg_speed": lerpf(t.speed_slow, t.speed_fast, pwr), "peak_speed": lerpf(t.speed_slow, t.speed_fast, pwr),
		"smoothness": 1.0, "vertical": 0.3, "end_dir": Vector2(0, -1), "end_accel": 0.0, "curvature": curve}
	last_features = f
	shoot_params(synthetic_params(target, pwr, curve, _shooter_attrs()))

## Parametros de un trazo largo y limpio hacia target (potencia 0..1, curvatura + derecha), con el mismo modelo del gesto:
## los usan las pruebas y el tirador de la CPU en los tiros libres por turnos. attrs: atributos del tirador (CPU: neutros).
func synthetic_params(target: Vector3, pwr: float, curve: float, attrs: Dictionary = {}) -> ShotParams:
	var t: GestureTuning = AttributeEffects.tuning_for(GestureTuning.current(), attrs)
	var p := ShotParams.new()
	p.gesture_length = t.length_full
	p.smoothness = 1.0
	p.power = pwr
	p.target = target
	var ca: float = maxf(absf(curve) - t.curve_deadzone, 0.0)
	p.curve = signf(curve) * ca
	p.lateral_spin = clampf(p.curve * t.spin_gain, -t.spin_max, t.spin_max)
	p.direction = Vector3(target.x - ball_spot.x, 0.0, target.z - ball_spot.z).normalized()
	p.error_deg = t.error_base + t.error_power * pwr * pwr
	p.accuracy = 1.0
	p.gesture_type = GestureShotModel.classify(p, t, goal_h)
	GestureShotModel._apply_type(p, shot_context(attrs), t, 0.0)
	GestureShotModel.solve(p, ball_spot, shot_context(attrs), false)
	return p

## Comparador del panel de diagnostico: trazos sinteticos desde la pelota hacia el arco (no patea).
func _compare_gestures() -> void:
	var h: float = _screen_h()
	var from: Vector2 = cam.unproject_position(ball_spot)
	var goal_px: Vector2 = cam.unproject_position(Vector3(gx, 1.2, 0.0))
	var chord: Vector2 = goal_px - from
	var t: GestureTuning = GestureTuning.current()
	var cases := [["corto lento", 0.45, 0.6, 0.0, 0.0], ["corto rápido", 0.45, 0.12, 0.0, 0.0], ["largo lento", 1.0, 0.9, 0.0, 0.0],
		["largo rápido", 1.0, 0.18, 0.0, 0.0], ["recto medio", 0.9, 0.3, 0.0, 0.0], ["curvo a la izq.", 0.9, 0.3, -0.15, 0.0],
		["curvo a la der.", 0.9, 0.3, 0.15, 0.0], ["irregular", 0.9, 0.3, 0.0, 6.0]]
	var lines: PackedStringArray = ["COMPARACIÓN DE TRAZOS (no patea)"]
	for c in cases:
		var g: ShotGesture = ShotGesture.synthetic(t, h, from, from + chord * float(c[1]), float(c[2]), float(c[3]), float(c[4]), 7)
		var f: Dictionary = g.features()
		var p: ShotParams = GestureShotModel.build(f, g.last_px(), cam, ball_spot, shot_context(), t)
		GestureShotModel.solve(p, ball_spot, shot_context(), true)
		lines.append("%s: pot %.2f (%.0f m/s) · alt %.2f m · ef %.0f · prec %.2f · %s · %s" % [c[0], p.power, p.speed, p.target.y,
			p.lateral_spin, p.accuracy, p.gesture_type, p.predicted_class])
	diag.show_text("\n".join(lines))

func _on_action(id: StringName) -> void:
	match id:
		&"confirm":
			if phase == Phase.PLACE:
				_setup_free_kick()
		&"foot":
			toggle_foot()
		&"move":
			if mode == Mode.FREE_KICK and not fk_duel() and phase in [Phase.AIM, Phase.OVER]:
				_enter_place()
		&"again":
			if mode == Mode.FREE_KICK and not fk_duel() and phase == Phase.OVER:
				hud.hide_banner()
				cam.follow = null
				_setup_free_kick()
		&"local_keeper_ready":
			_local_keeper_ready()
		&"local_shooter_ready":
			_local_shooter_ready()
		&"rematch":
			shootout.reset()
			if local != null:
				local.reset_match()
				# Igualdad de oportunidades: en la revancha empieza pateando el otro.
				shootout.first = local.first_shooter()
			if fk_duel():
				_start_fk_duel_turn()
			else:
				_start_penalty_turn()
		&"replay":
			start_replay()
		&"skip":
			skip_celebration()
		&"replay_cam":
			replay_angle = (replay_angle + 1) % REPLAY_ANGLES.size()
			_replay_actions()
		&"replay_skip":
			end_replay()
		&"replay_slow":
			replay_slowmo = not replay_slowmo
			_replay_actions()
		&"retry":
			if mode == Mode.CHALLENGE:
				next_challenge = runner.def
				get_tree().reload_current_scene()
		&"next":
			var nd: Dictionary = next_challenge_def()
			if not nd.is_empty():
				next_challenge = nd
				get_tree().reload_current_scene()
		&"quit", &"challenges":
			# Vuelve a la seccion de donde vino: Academia (ejercicios) o Minijuegos Arcade (desafios de arco).
			if runner != null:
				ChallengeMenu.section = "academia" if String(runner.def.get("group", "")) == "academia" else "arcade"
			if ResourceLoader.exists(CHALLENGE_MENU_SCENE):
				get_tree().change_scene_to_file(CHALLENGE_MENU_SCENE)
		&"menu":
			_go_menu()

func _go_menu() -> void:
	if get_tree() != null and ResourceLoader.exists(MENU_SCENE):
		get_tree().change_scene_to_file(MENU_SCENE)
