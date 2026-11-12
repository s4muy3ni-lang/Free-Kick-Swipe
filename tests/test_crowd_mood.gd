extends TestCase
## Publico de penales y tiros libres (pedido del usuario 2026-11-12): el mismo publico 2D animado de los minijuegos
## arcade en las tribunas del estadio; festeja mas vivo y mas largo con un gol o una atajada del usuario (el mismo
## festejo), se lamenta (sin silbidos) con sus fallos y los goles de la CPU, se queda quieto mirando en la carrera del
## penal y en calma se sigue escuchando.

func _game(mode: int) -> SetPieceGame:
	SetPieceGame.next_mode = mode
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	return game

func _mat_param(game: SetPieceGame, param: String) -> float:
	var v: Variant = game.stadium.crowd_materials[0].get_shader_parameter(param)
	return float(v) if v != null else 0.0

func test_the_stadium_has_the_arcade_crowd() -> void:
	var game := _game(SetPieceGame.Mode.FREE_KICK)
	await physics_frames(3)
	var crowds: Array = game.stadium.find_children("Publico", "MultiMeshInstance3D", true, false)
	check(crowds.size() == 1, "el publico del estadio es una sola MultiMesh (un draw call)")
	var n: int = game.stadium.crowd_count()
	note("hinchas en las tribunas: %d (perfil %s)" % [n, GraphicsSettings.profile_name()])
	check(n > 3000, "tribunas llenas")
	var mmi: MultiMeshInstance3D = crowds[0]
	check((mmi.material_override as ShaderMaterial).shader == ArcadeLook.crowd_shader(), "con el mismo shader animado de los minijuegos arcade")
	check((mmi.multimesh.mesh is QuadMesh), "hinchas 2D (un cuadrado cada uno)")
	check(not game.stadium.crowd_materials.is_empty(), "el estadio controla su animo")
	cleanup()

func test_user_goal_long_lively_celebration() -> void:
	var game := _game(SetPieceGame.Mode.FREE_KICK)
	await physics_frames(3)
	var calm: float = game.crowd_target()
	game.crowd_react(true, "goal")
	await wait_seconds(5.0)
	var m: Vector2 = game.crowd_mood()
	note("a los 5 s del gol: festejo %.2f, abucheo %.2f; tribuna %.2f" % [m.x, m.y, _mat_param(game, "cheer")])
	check(m.x > 0.95 and m.y == 0.0, "a los 5 s sigue festejando a pleno (antes ya se apagaba)")
	check(_mat_param(game, "cheer") > 0.95, "y los hinchas siguen saltando")
	check(game.crowd_target() >= calm + 0.45, "el estadio suena a estallido (%.2f -> %.2f)" % [calm, game.crowd_target()])
	await wait_seconds(7.0)
	check(game.crowd_mood().x < 0.6, "despues baja de a poco")
	cleanup()

func test_user_miss_and_cpu_goal_are_booed() -> void:
	var game := _game(SetPieceGame.Mode.PENALTY)
	await physics_frames(3)
	game.crowd_react(false, "miss")
	await physics_frames(10)
	var m: Vector2 = game.crowd_mood()
	note("tras un fallo: festejo %.2f, abucheo %.2f, tribuna %.2f" % [m.x, m.y, _mat_param(game, "boo")])
	check(m.y > 0.8 and m.x == 0.0, "un fallo del usuario se abuchea")
	check(_mat_param(game, "boo") > 0.8, "los hinchas se agarran la cabeza")
	game.crowd_react(true, "save")
	await physics_frames(2)
	check(game.crowd_mood().x > 0.95 and game.crowd_mood().y == 0.0, "una atajada del usuario se festeja igual que un gol (y tapa el lamento)")
	check(game._cheer_hold > 6.0, "con el mismo festejo largo que el gol")
	cleanup()

func test_a_real_miss_is_booed() -> void:
	var game := _game(SetPieceGame.Mode.PENALTY)
	await physics_frames(10)
	check(game.user_shooting, "patea el usuario")
	# Bien afuera: el arco mide 7,32 m (z en +-3,66).
	game.shoot(Vector3(game.gx, 0.6, 7.5), 0.8, 0.0)
	var n: int = 0
	var boo_max: float = 0.0
	var cheer_max: float = 0.0
	var outcome: String = ""
	while n < 900 and game.phase != SetPieceGame.Phase.KEEPER_PICK:
		await tree.physics_frame
		n += 1
		if game.phase == SetPieceGame.Phase.RESULT:
			outcome = game.outcome
		boo_max = maxf(boo_max, game.crowd_mood().y)
		cheer_max = maxf(cheer_max, game.crowd_mood().x)
	note("resultado %s: abucheo hasta %.2f, festejo hasta %.2f" % [outcome, boo_max, cheer_max])
	check(outcome != "" and outcome != "goal", "el tiro va afuera")
	check(boo_max > 0.8 and cheer_max == 0.0, "la tribuna abuchea el fallo")
	cleanup()

func test_quiet_runup_but_never_silent() -> void:
	var game := _game(SetPieceGame.Mode.PENALTY)
	await physics_frames(5)
	check(game.crowd_tension() == 0.0, "apuntando: tribuna en calma (aplausos, aliento)")
	game.shoot(Vector3(game.gx, 0.6, 2.9), 0.8, 0.0)
	var tension: float = 0.0
	for i in 30:
		await tree.physics_frame
		tension = maxf(tension, _mat_param(game, "tension"))
	check(tension > 0.9, "en la carrera del penal todos quietos mirando")
	note("volumen del ambiente: calma %.1f dB, estallido %.1f dB" % [Sfx.crowd_db(0.0), Sfx.crowd_db(1.0)])
	check(Sfx.crowd_db(0.0) >= -14.0, "en calma el publico se sigue escuchando (antes -38 dB)")
	check(Sfx.crowd_db(0.0) < Sfx.crowd_db(1.0), "y el estallido suena mas fuerte")
	cleanup()

func test_arcade_crowd_boos_and_cheer_cancels_it() -> void:
	var root := Node3D.new()
	spawn(root)
	ArcadeLook.night_arena(root, Vector3.ZERO, 30.0, 18.0, true)
	check(is_zero_approx(ArcadeLook.boo_level(root)), "en calma al empezar")
	ArcadeLook.boo(root, 0.8, 0.5)
	await wait_seconds(0.5)
	check(ArcadeLook.boo_level(root) > 0.75, "abuchea")
	ArcadeLook.cheer(root, 1.0, 0.5)
	await physics_frames(2)
	check(is_zero_approx(ArcadeLook.boo_level(root)), "el festejo tapa el abucheo")
	await wait_seconds(2.0)
	check(ArcadeLook.cheer_level(root) < 0.01 and ArcadeLook.boo_level(root) < 0.01, "y vuelve a la calma")
	cleanup()

func test_minigame_user_error_is_booed() -> void:
	var d: Dictionary = MinigameCatalog.level("dianas", 1)
	d["practice"] = true
	Minigame.next_def = d
	var g: Minigame = (load(String(d["scene"])) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.side = Minigame.Side.USER
	check(g.crowd_boo("x", ["Afuera", Color(1.0, 0.4, 0.4)]) > 0.0, "un error del usuario se abuchea")
	check(is_zero_approx(g.crowd_boo("x", ["0 de 3 dianas", Color(1.0, 0.85, 0.35)])), "un tiro que no suma, no")
	g.side = Minigame.Side.CPU
	check(is_zero_approx(g.crowd_boo("x", ["Afuera", Color(1.0, 0.4, 0.4)])), "un error de la CPU, tampoco")
	cleanup()

func test_crowd_sounds_exist() -> void:
	check(not Sfx.SOUNDS.has(&"boo") and not FileAccess.file_exists("res://assets/audio/boo.wav"), "sin abucheo con silbidos (al usuario no le gustaron)")
	for n in [&"cheer", &"ooh", &"post", &"post2", &"post3"]:
		check(Sfx._streams.has(n), "Sfx cargo %s" % n)
	var cheer: AudioStreamWAV = Sfx._streams[&"cheer"]
	note("festejo: %.1f s" % cheer.get_length())
	check(cheer.get_length() >= 8.0, "el festejo del gol es largo (antes 4 s)")
