extends TestCase
## Presentacion: el publico calla antes del penal, sube con la tension y estalla con el gol; las atajadas del arquero de
## penales y tiros libres suenan a guante (antes sonaban como una patada).

func test_the_crowd_follows_the_play() -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	var aim: float = game.crowd_target()
	game.shoot(Vector3(game.gx, 0.6, 2.9), 0.8, 0.0)
	var runup: float = game.crowd_target()
	var flight_max: float = 0.0
	var result_max: float = 0.0
	var outcome: String = ""
	var n: int = 0
	while n < 600 and game.phase != SetPieceGame.Phase.KEEPER_PICK:
		await tree.physics_frame
		n += 1
		if game.phase == SetPieceGame.Phase.FLIGHT:
			flight_max = maxf(flight_max, game.crowd_target())
		if game.phase == SetPieceGame.Phase.RESULT:
			result_max = maxf(result_max, game.crowd_target())
			outcome = game.outcome
	note("publico: apuntando %.2f, carrera %.2f, vuelo hasta %.2f, resultado (%s) hasta %.2f" % [aim, runup, flight_max, outcome, result_max])
	check(aim < 0.2 and runup < 0.2, "silencio antes del penal")
	check(flight_max > runup, "la tension sube con la pelota en el aire")
	if outcome == "goal":
		check(result_max > 0.9, "estalla con el gol")
	else:
		check(result_max >= 0.5, "murmullo despues de la atajada o el fallo")
	check(Sfx.crowd_db(0.0) < Sfx.crowd_db(1.0), "mas intensidad = mas volumen")
	cleanup()

func test_set_piece_keeper_touches_sound_like_gloves() -> void:
	var a := SpActor.new()
	a.role = &"keeper"
	check(Sfx.is_keeper(a), "el arquero de penales y tiros libres es arquero para el sonido")
	check(Sfx.impulse_sound(true, 10.0, 12.0)[0] == &"glove", "su toque suena a guante")
	var b := SpActor.new()
	b.role = &"shooter"
	check(not Sfx.is_keeper(b), "el tirador no")
	a.free()
	b.free()
