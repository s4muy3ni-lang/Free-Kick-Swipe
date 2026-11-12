extends TestCase
## Pedido del usuario (2026-11-12): en un tiro libre lejano el arquero llegaba al lugar por donde iba la pelota, quedaba
## parado y la pelota le pasaba por arriba (o al lado, «goles en el palo del arquero»). Si ya esta en el lugar, la debe
## atajar o despejar afuera. Se mide con el esqueleto animado (render): tiros altos y a media altura al lugar donde esta
## parado el arquero, desde lejos, en las dos bibliotecas de animaciones.

func _needs_render() -> bool:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return true
	return false

func _game() -> SetPieceGame:
	SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	return game

func test_a_ball_to_where_the_keeper_stands_is_saved() -> void:
	if _needs_render():
		return
	# [punto de la pelota (respecto del arco), altura del cruce, corrimiento lateral respecto del arquero, potencia]
	var cases := [[Vector3(-30, 0, 4), 2.15, 0.0, 0.55], [Vector3(-28, 0, -6), 2.0, 0.6, 0.6], [Vector3(-32, 0, 0), 1.7, -0.7, 0.5],
		[Vector3(-26, 0, 8), 2.2, 0.3, 0.65]]
	var saved: int = 0
	var i: int = 0
	for c in cases:
		var game: SetPieceGame = await _game()
		game.rng.seed = 900 + i
		game.cpu_keeper.rng.seed = 400 + i
		game.wall.rng.seed = 60 + i
		game.field.rng.seed = 95 + i
		game.ball_spot = game.clamp_free_kick_spot(Vector3(game.gx, 0, 0) + c[0])
		game._setup_free_kick()
		await physics_frames(10)
		var k: SpKeeper = game.cpu_keeper
		var z: float = clampf(k.actor.global_position.z + float(c[2]), -3.0, 3.0)
		game.shoot(Vector3(game.gx, float(c[1]), z), float(c[3]), 0.0)
		var n: int = 0
		while game.phase in [SetPieceGame.Phase.RUNUP, SetPieceGame.Phase.FLIGHT] and n < 900:
			await tree.physics_frame
			n += 1
		note("tiro %d desde %s al lugar del arquero (z %.2f, alto %.2f): resultado %s, toque «%s», en el lugar %d" % [i + 1,
			str(c[0]), z, float(c[1]), game.outcome, k.touch_kind, k.in_position_count])
		if game.outcome != "goal":
			saved += 1
		check(game.outcome != "goal", "tiro %d: no le pasa por arriba ni al lado (resultado %s)" % [i + 1, game.outcome])
		cleanup()
		i += 1
	note("atajados o despejados: %d de %d" % [saved, cases.size()])
