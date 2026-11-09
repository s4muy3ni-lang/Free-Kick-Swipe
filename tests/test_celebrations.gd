extends TestCase
## Festejos y lamentos (etapa 3) y opciones visuales (etapa 4): con gol la camara se queda en la vista de juego mientras
## los compañeros corren al autor (temblor suave) y recien despues llega el primer plano; se puede saltar sin trabarse ni
## contar dos veces; sin gol festeja el rival hacia donde termino la jugada y no hay cinematica; el temblor se puede
## apagar y la linea de destino se puede ocultar sin perder el rastro del dedo.

const Lifecycle := preload("res://tests/test_play_lifecycle.gd")

func _game(m: int) -> SetPieceGame:
	SetPieceGame.next_mode = m
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	spawn(game)
	await physics_frames(10)
	return game

func _free_kick(game: SetPieceGame, spot: Vector3) -> void:
	game.ball_spot = game.clamp_free_kick_spot(Vector3(game.gx, 0, 0) + spot)
	game._setup_free_kick()
	await physics_frames(10)

func _wait_result(game: SetPieceGame, limit: int = 600) -> void:
	var n: int = 0
	while game.phase != SetPieceGame.Phase.RESULT and n < limit:
		await tree.physics_frame
		n += 1

func test_free_kick_goal_mates_run_to_the_scorer_then_close_up() -> void:
	var keep_shake: int = GraphicsSettings.camera_shake
	GraphicsSettings.camera_shake = 1
	var game: SetPieceGame = await _game(SetPieceGame.Mode.FREE_KICK)
	game.rng.seed = 2026
	game.cpu_keeper.rng.seed = 11
	game.wall.rng.seed = 7
	game.field.rng.seed = 9
	await _free_kick(game, Vector3(-22, 0, 0))
	game.shoot(Vector3(game.gx, 2.0, -3.0), 0.8, 0.0)
	await _wait_result(game)
	check(game.outcome == "goal", "el tiro de prueba es gol (%s)" % game.outcome)
	var scorer: SpActor = game.cur_shooter.actor
	var start_d: Array = []
	for a in game.field.attackers:
		start_d.append(a.global_position.distance_to(scorer.global_position))
	var live_follow: bool = false
	var shook: bool = false
	var close_up: bool = false
	var n: int = 0
	while game.phase == SetPieceGame.Phase.RESULT and n < 60 * 8:
		await tree.physics_frame
		n += 1
		if game._result_t < SetPieceGame.GOAL_LIVE_T - 0.05:
			live_follow = live_follow or game.cam.follow != null
			shook = shook or game.cam.shaking()
		elif game.cam.follow == scorer:
			close_up = true
	var end_d: Array = []
	for a in game.field.attackers:
		end_d.append(a.global_position.distance_to(scorer.global_position))
	note("compañeros: de %s m a %s m del autor; llegaron %d, por tope %d; temblor %s; primer plano %s; %.1f s de festejo" % [
		str(start_d.map(func(x: float) -> String: return "%.1f" % x)), str(end_d.map(func(x: float) -> String: return "%.1f" % x)),
		game.celebration.arrived, game.celebration.timed_out, str(shook), str(close_up), n / 60.0])
	check(not live_follow, "durante el festejo inicial la camara sigue en la vista de juego (sin primer plano)")
	check(shook, "temblor suave mientras corren")
	check(close_up, "despues llega el primer plano del autor")
	check(game.celebration.arrived == game.field.attackers.size() and game.celebration.timed_out == 0, "todos los compañeros llegan al autor")
	for d in end_d:
		check(float(d) <= SpCelebration.RING + 1.6, "cada compañero termina junto al autor (%.1f m)" % d)
	check(game.phase == SetPieceGame.Phase.OVER and game.fk_goals == 1, "la jugada termina con un solo gol contado")
	check(not game.cam.shaking(), "el temblor se apaga")
	await physics_frames(60 * 3)
	check(Lifecycle.stuck_actors(game).is_empty(), "nadie queda trabado (%s)" % str(Lifecycle.stuck_actors(game)))
	GraphicsSettings.camera_shake = keep_shake
	cleanup()

func test_penalty_goal_can_be_skipped_once_and_mates_meet_the_scorer() -> void:
	var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
	game.rng.seed = 2026
	game.cpu_keeper.rng.seed = 11
	game.shoot(Vector3(game.gx, 0.6, 2.9), 0.8, 0.0)
	await _wait_result(game)
	check(game.outcome == "goal", "el penal de prueba es gol (%s)" % game.outcome)
	await physics_frames(30)
	game._on_action(&"skip")
	check(game.phase == SetPieceGame.Phase.KEEPER_PICK, "saltar el festejo pasa enseguida al turno siguiente")
	game._on_action(&"skip")
	check(game.shootout.results[0].size() == 1 and game.shootout.goals(0) == 1, "el gol se cuenta una sola vez")
	check(not game.celebration.active(), "no queda ningun festejo abierto")
	var home_ok: bool = true
	for i in game.bench.size():
		home_ok = home_ok and game.bench[i].global_position.distance_to(game._bench_home[i]) < 0.05
	check(home_ok, "los del circulo central vuelven a su lugar")
	cleanup()
	# Sin saltar: los compañeros salen del circulo central y el autor va hacia ellos; se encuentran.
	game = await _game(SetPieceGame.Mode.PENALTY)
	game.rng.seed = 2026
	game.cpu_keeper.rng.seed = 11
	game.shoot(Vector3(game.gx, 0.6, 2.9), 0.8, 0.0)
	await _wait_result(game)
	var scorer: SpActor = game.cur_shooter.actor
	var mates: Array = game.bench.filter(func(b: SpActor) -> bool: return b.team == 0)
	var best: float = INF
	var n: int = 0
	while game.phase == SetPieceGame.Phase.RESULT and n < 60 * 8:
		await tree.physics_frame
		n += 1
		for m in mates:
			best = minf(best, (m as SpActor).global_position.distance_to(scorer.global_position))
	note("penal: el compañero mas cercano llego a %.1f m del autor en %.1f s" % [best, n / 60.0])
	check(best <= SpCelebration.MEET_DIST + 1.5, "el autor y sus compañeros se encuentran")
	check(game.phase == SetPieceGame.Phase.KEEPER_PICK, "y el turno siguiente llega solo")
	cleanup()

## Sin gol: no hay cinematica (la camara no sigue a nadie), el que pateo se lamenta y los rivales corren a festejar hacia
## donde termino la jugada.
func test_misses_keep_the_camera_and_rivals_celebrate_where_it_ended() -> void:
	var cases := [[Vector3(-22, 0, 0), Vector3(0, 1.0, 0.0), 0.9, "wall"], [Vector3(-22, 0, 0), Vector3(0, 0.5, 6.0), 0.7, "miss"],
		[Vector3(-28, 0, 6), Vector3(0, 3.3, 0.0), 0.85, "miss"]]
	for c in cases:
		var game: SetPieceGame = await _game(SetPieceGame.Mode.FREE_KICK)
		game.rng.seed = 714
		game.cpu_keeper.rng.seed = 314
		game.wall.rng.seed = 64
		game.field.rng.seed = 104
		await _free_kick(game, c[0])
		game.shoot(Vector3(game.gx, 0, 0) + c[1], c[2], 0.0)
		await _wait_result(game)
		var why: String = game.outcome
		var center: Vector3 = game._celebration_center(why)
		var before: Dictionary = {}
		for d in game.field.defenders:
			before[d] = Vector2(d.global_position.x - center.x, d.global_position.z - center.z).length()
		var followed: bool = false
		var n: int = 0
		while game.phase == SetPieceGame.Phase.RESULT and n < 60 * 8:
			await tree.physics_frame
			n += 1
			followed = followed or game.cam.follow != null
		var closer: int = 0
		var runners: int = 0
		for d in game.field.defenders:
			if d == game.chaser:
				continue
			runners += 1
			var after: float = Vector2(d.global_position.x - center.x, d.global_position.z - center.z).length()
			if after < float(before[d]) - 0.5 or after <= SpCelebration.RING + 1.0:
				closer += 1
		note("tiro libre %s: festejan hacia (%.1f, %.1f); %d de %d defensores se acercaron; reacciones %d; camara siguio %s" % [
			why, center.x, center.z, closer, runners, game.celebration.reacted, str(followed)])
		if c[3] != "":
			check(why == c[3], "resultado esperado %s (%s)" % [c[3], why])
		check(why != "goal", "sin gol")
		check(not followed, "%s: sin cinematica automatica" % why)
		check(closer == runners, "%s: los rivales corren a festejar hacia donde termino la jugada" % why)
		check(game.celebration.reacted >= game.field.attackers.size(), "%s: el equipo que pateo se lamenta" % why)
		check(game.phase == SetPieceGame.Phase.OVER, "%s: la jugada termina" % why)
		cleanup()

func test_camera_shake_is_subtle_and_can_be_turned_off() -> void:
	var keep: int = GraphicsSettings.camera_shake
	var cam := SpCamera.new()
	spawn(cam)
	cam.frame(Vector3(0, 2, 5), Vector3.ZERO, 50.0, true)
	GraphicsSettings.camera_shake = 0
	cam.shake(1.0, 1.0)
	check(not cam.shaking(), "apagado: no tiembla")
	GraphicsSettings.camera_shake = 2
	cam.shake(1.0, 0.6)
	var peak: float = 0.0
	var n: int = 0
	while cam.shaking() and n < 120:
		await tree.process_frame
		n += 1
		peak = maxf(peak, Vector2(cam.h_offset, cam.v_offset).length())
	note("temblor normal: pico %.3f m, %d cuadros" % [peak, n])
	check(peak > 0.01 and peak <= SpCamera.SHAKE_MAX, "se nota pero es suave (<= %.2f m)" % SpCamera.SHAKE_MAX)
	check(not cam.shaking() and cam.h_offset == 0.0 and cam.v_offset == 0.0, "termina solo y la imagen vuelve a su lugar")
	check(cam.global_position.distance_to(Vector3(0, 2, 5)) < 0.001, "no mueve la camara (solo corre la imagen)")
	GraphicsSettings.camera_shake = keep
	cleanup()

func test_aim_line_option_hides_only_the_destination_line() -> void:
	var keep: bool = GraphicsSettings.show_aim_line
	for show in [true, false]:
		GraphicsSettings.show_aim_line = show
		var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
		var from: Vector2 = game.cam.unproject_position(game.ball_spot)
		game._on_press(from, true)
		var seen: bool = false
		for i in 24:
			game._on_drag(from + Vector2(6.0 * float(i), -12.0 * float(i)))
			await physics_frames(2)
			seen = seen or game.preview.visible
		var trail: int = game.hud.trail.points.size()
		note("linea de destino %s: la linea se vio %s, rastro del dedo %d puntos" % [str(show), str(seen), trail])
		check(seen == show, "la linea de destino se ve solo si la opcion esta activa")
		check(trail > 3, "el rastro del dedo se ve igual")
		cleanup()
	# Se guarda.
	GraphicsSettings.show_aim_line = false
	GraphicsSettings.save_settings()
	GraphicsSettings.show_aim_line = true
	GraphicsSettings.load_settings()
	check(not GraphicsSettings.show_aim_line, "la opcion se guarda")
	GraphicsSettings.show_aim_line = keep
	GraphicsSettings.save_settings()
