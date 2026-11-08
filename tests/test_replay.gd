extends TestCase
## Repeticion por estados: la jugada repetida pasa EXACTAMENTE por donde paso (pelota y jugadores), sin volver a simular,
## y al terminar el juego queda como estaba (fase, pelota, jugadores, controladores).

func test_a_free_kick_replays_exactly_and_restores_the_game() -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	game.ball_spot = game.clamp_free_kick_spot(Vector3(game.gx - 22.0, 0, 2.0))
	game._setup_free_kick()
	await physics_frames(10)
	game.shoot(Vector3(game.gx, 1.4, -2.4), 0.8, -0.1)
	var n: int = 0
	while game.phase != SetPieceGame.Phase.OVER and n < 900:
		await tree.physics_frame
		n += 1
	await physics_frames(20)
	var rec: PlayRecording = game.recording
	note("jugada: %d pasos registrados, marcas %s, %d jugadores" % [rec.frames(), str(rec.marks), rec.actors.size()])
	check(rec.frames() > 30 and rec.marks.has(&"contacto") and rec.marks.has(&"resultado"), "la jugada quedo registrada con el golpe y el resultado")
	var before_ball: Vector3 = game.ball.global_position
	var before_v: Vector3 = game.ball.linear_velocity
	var before_actor: Vector3 = game.user_shooter.actor.global_position
	game.replay_slowmo = false
	game.start_replay()
	check(game.phase == SetPieceGame.Phase.REPLAY, "empieza la repeticion")
	check(game.cpu_keeper.process_mode == Node.PROCESS_MODE_DISABLED, "el juego queda en pausa (controladores detenidos)")
	var worst_ball: float = 0.0
	var worst_actor: float = 0.0
	var k: int = 0
	while game.phase == SetPieceGame.Phase.REPLAY and k < 900:
		var f: int = int(game.replay_f)
		await tree.physics_frame
		k += 1
		if game.phase != SetPieceGame.Phase.REPLAY or f >= rec.frames():
			break
		worst_ball = maxf(worst_ball, game.ball.global_position.distance_to(rec.ball_pos[f]))
		worst_actor = maxf(worst_actor, game.user_shooter.actor.global_position.distance_to(rec.a_pos[rec.actors.find(game.user_shooter.actor)][f]))
	note("repeticion: %d pasos; diferencia maxima pelota %.4f m, tirador %.4f m" % [k, worst_ball, worst_actor])
	check(worst_ball < 0.001 and worst_actor < 0.001, "la pelota y el tirador pasan exactamente por donde pasaron")
	check(game.phase == SetPieceGame.Phase.OVER, "al terminar vuelve a donde estaba")
	note("pelota antes %s (v %s), despues %s" % [str(before_ball), str(before_v), str(game.ball.global_position)])
	check(game.ball.global_position.distance_to(before_ball) < 0.01 + before_v.length() * 2.0 / 60.0, "la pelota queda donde estaba")
	check(game.user_shooter.actor.global_position.distance_to(before_actor) < 0.01, "el tirador queda donde estaba")
	check(game.cpu_keeper.process_mode == Node.PROCESS_MODE_INHERIT, "los controladores vuelven a andar")
	# Camara lenta: alrededor del golpe avanza mas despacio.
	game.replay_slowmo = true
	game.start_replay()
	var steps: int = 0
	while game.phase == SetPieceGame.Phase.REPLAY and steps < 3000:
		await tree.physics_frame
		steps += 1
	note("con camara lenta: %d pasos para %d registrados" % [steps, rec.frames()])
	check(steps > rec.frames(), "la camara lenta dura mas que la jugada")
	cleanup()
