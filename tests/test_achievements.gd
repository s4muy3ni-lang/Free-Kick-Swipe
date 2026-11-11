extends TestCase
## Logros y desafios diarios/semanales (etapa A2): rotacion deterministica sin repetidos, progreso por periodo que se
## reinicia al cambiar el dia o la semana, premio UNA sola vez (anti-exploit), cosmeticos que se abren, historial y aviso
## visual (Toasts). Tambien el cableado real: un gol de penal del usuario suma al diario de goles.

func _fresh(day: int = 100, week: int = 14) -> void:
	Achievements.muted = true
	Achievements.fake_day = day
	Achievements.fake_week = week
	PlayerProgress.use_path("user://test_ach_prog.cfg")
	Achievements.use_path("user://test_ach.cfg")

func _restore() -> void:
	Achievements.fake_day = -1
	Achievements.fake_week = -1
	Achievements.muted = false

func test_rotation_is_deterministic_and_distinct() -> void:
	_fresh(100)
	var a: Array = Achievements.todays_daily()
	var ids := {}
	for d in a:
		ids[d[0]] = true
	check(a.size() == 3 and ids.size() == 3, "3 diarios distintos")
	check(str(Achievements.todays_daily()) == str(a), "la rotacion es estable en el mismo dia")
	Achievements.fake_day = 101
	check(str(Achievements.todays_daily()) != str(a), "al dia siguiente cambian")
	var w: Array = Achievements.this_weeks()
	check(w.size() == 2 and w[0][0] != w[1][0], "2 semanales distintos")
	_restore()

func test_daily_completes_once_and_resets_next_day() -> void:
	_fresh(100)
	# Busca un dia cuyo diario incluya los 3 goles.
	var day: int = 100
	while not str(Achievements.todays_daily()).contains("d_gol3"):
		day += 1
		Achievements.fake_day = day
	var xp0: int = PlayerProgress.xp
	Achievements.event(&"gol")
	Achievements.event(&"gol")
	check(Achievements.progress_of(&"gol", 3, "dia") == 2, "el progreso del dia se cuenta")
	var completed: Array = Achievements.event(&"gol")
	check(str(completed).contains("3 goles"), "al tercer gol se completa el diario")
	var xp1: int = PlayerProgress.xp
	check(xp1 == xp0 + Achievements.DAILY_XP, "paga %d XP" % Achievements.DAILY_XP)
	for i in 5:
		Achievements.event(&"gol")
	check(PlayerProgress.xp == xp1, "repetirlo el mismo dia NO vuelve a pagar (anti-exploit)")
	Achievements.fake_day = day + 1
	check(Achievements.progress_of(&"gol", 3, "dia") == 0, "al dia siguiente el progreso diario vuelve a cero")
	note("dia %d: %s" % [day, str(Achievements.todays_daily().map(func(d: Array) -> String: return String(d[1])))])
	_restore()

func test_permanent_grants_cosmetic_and_history() -> void:
	_fresh(200, 20)
	check(not PlayerProgress.cosmetics.has("botines_oro"), "el cosmetico empieza bloqueado")
	for i in 5:
		Achievements.event(&"tanda")
	check(Achievements.is_done("tanda_1") and Achievements.is_done("tanda_5"), "los dos logros de tandas se completan")
	check(PlayerProgress.cosmetics.has("botines_oro"), "el logro abre los botines dorados")
	var h: Array = Achievements.history()
	check(h.size() >= 2 and str(h).contains("Rey de los penales"), "quedan en el historial con fecha")
	# Persistencia.
	Achievements.load_state(true)
	check(Achievements.is_done("tanda_5") and int(Achievements.life.get(&"tanda", 0)) == 5, "el estado se guarda y se recupera")
	_restore()

func test_weekly_and_toasts() -> void:
	_fresh(300, 30)
	var w: Array = Achievements.this_weeks()
	note("semana 30: %s" % str(w.map(func(d: Array) -> String: return String(d[1]))))
	var d0: Array = w[0]
	Achievements.muted = false
	var toasts: Node = tree.root.get_node_or_null("Toasts")
	check(toasts != null, "el autoload Toasts existe")
	var shown0: int = toasts.shown
	Achievements.event(StringName(d0[2]), int(d0[3]))
	check(Achievements.is_done("%s@s30" % d0[0]), "el semanal se completa")
	check(toasts.shown > shown0, "y avisa con un cartel")
	Achievements.muted = true
	_restore()

## Cableado real: en un penal del usuario que termina en gol se suma la estadistica &"gol" (partida normal, no rapida).
func test_a_real_goal_feeds_the_daily() -> void:
	_fresh(400, 40)
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	spawn(game)
	await physics_frames(10)
	game.rng.seed = 2026
	game.cpu_keeper.rng.seed = 11
	# Esta prueba necesita un gol (cuenta logros/festejos, no mide al arquero): sin la zona segura, el arquero de la IA
	# queda como antes (la zona segura se mide en test_keeper_zones).
	game.cpu_keeper.sure_zones = false
	var before: int = int(Achievements.life.get(&"gol", 0))
	game.shoot(Vector3(game.gx, 0.6, 2.9), 0.8, 0.0)
	var n: int = 0
	while game.phase != SetPieceGame.Phase.RESULT and n < 600:
		await tree.physics_frame
		n += 1
	check(game.outcome == "goal", "el penal de prueba es gol (%s)" % game.outcome)
	check(int(Achievements.life.get(&"gol", 0)) == before + 1, "el gol suma al contador de logros")
	check(int(Achievements.life.get(&"gol_penal", 0)) >= 1, "y al de penales")
	cleanup()
	_restore()
