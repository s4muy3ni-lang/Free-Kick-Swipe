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

## Ningun jugador queda repitiendo una reaccion: los clips en bucle no se eligen como reaccion, y si un clip en bucle se
## reproduce una vez, termina al completar su ciclo (antes el jugador quedaba trabado esperando el final).
func test_reactions_never_loop_forever() -> void:
	var loops: int = 0
	for roles in [SpReactions.GOAL_SCORER, SpReactions.GOAL_TEAM, SpReactions.MISS_SHOOTER, SpReactions.SAD, SpReactions.HAPPY_DEFENDER, [&"gk_gesture", &"celebrate", &"clap"]]:
		for i in 40:
			var id: StringName = SpReactions.pick(roles, null, 2.5, 0.5)
			if id != &"" and SpClips.anim(id).loop_mode != Animation.LOOP_NONE:
				loops += 1
	check(loops == 0, "ninguna reaccion elegida es un clip en bucle (%d)" % loops)
	var a := SpActor.new()
	spawn(a)
	a.build(SpSettings.CPU_KEEPER_KIT)
	await physics_frames(2)
	var finished := [false]
	a.clip_finished.connect(func(_id: StringName) -> void: finished[0] = true)
	var looped: StringName = &"jn_gk_gesture_0064"
	check(SpClips.has(looped) and SpClips.anim(looped).loop_mode != Animation.LOOP_NONE, "el clip de prueba es un bucle")
	a.play_here(looped, 0.0)
	var n: int = 0
	while not finished[0] and n < 240:
		await tree.physics_frame
		n += 1
	note("clip en bucle de %.2f s reproducido una vez: termina a los %.2f s" % [SpClips.length(looped), n / 60.0])
	check(finished[0] and n <= int(SpClips.length(looped) * 60.0) + 12, "termina al completar su ciclo")
	cleanup()
