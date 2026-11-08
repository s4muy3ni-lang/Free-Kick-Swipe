extends TestCase
## Modos de tiros libres y penales con el esqueleto animado (necesitan render: en CI se ejecutan con xvfb):
##  - el pie del tirador llega a la pelota en el instante del impulso, en golpeos de distintas direcciones y tipos;
##  - el arquero que se lanza a la zona correcta toca la pelota con su cuerpo animado (la fisica decide atajada o desvio)
##    y el que se lanza al otro lado no la toca (nunca se mueve la pelota hacia las manos).

func _needs_render() -> bool:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return true
	return false

func _game(mode: int) -> SetPieceGame:
	SetPieceGame.next_mode = mode
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	return game

func _wait_phase_change(game: SetPieceGame, from: int, max_frames: int = 600) -> void:
	var n: int = 0
	while game.phase == from and n < max_frames:
		await tree.physics_frame
		n += 1

func test_the_foot_reaches_the_ball_at_the_impulse() -> void:
	if _needs_render():
		return
	var worst: float = 0.0
	for c in [[0.5, -2.8, 0.75, 0.0], [0.5, 2.8, 0.45, 0.0], [1.8, 0.0, 0.9, 0.0], [1.2, -1.5, 0.35, 0.15], [1.7, 1.0, 0.1, 0.0]]:
		var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
		game.shoot(Vector3(game.gx, c[0], c[1]), c[2], c[3])
		var e: Dictionary = game.last_shot.get("entry", {})
		await _wait_phase_change(game, SetPieceGame.Phase.RUNUP)
		var gap: float = game.user_shooter.contact_gap
		worst = maxf(worst, gap)
		note("objetivo (%.1f, %.1f) potencia %.2f: %s (%s) pie-pelota %.3f m, sale a %.1f m/s" % [c[1], c[0], c[2], e.get("id", "-"),
			ShotCatalog.Kind.keys()[int(game.last_shot.get("kind", 1))], gap, game.ball.linear_velocity.length()])
		check(game.phase == SetPieceGame.Phase.FLIGHT, "%s: hubo contacto" % e.get("id", "-"))
		check(gap >= 0.0 and gap < 0.4, "%s: la punta del pie esta en la pelota al golpear (%.3f m)" % [e.get("id", "-"), gap])
		cleanup()
	note("peor distancia pie-pelota en el impulso: %.3f m" % worst)

func test_the_keeper_touches_what_he_reaches_and_not_what_he_does_not() -> void:
	if _needs_render():
		return
	var touched_right: int = 0
	var touched_wrong: int = 0
	var cases := [Vector3(52.5, 0.6, -2.0), Vector3(52.5, 1.2, 1.6), Vector3(52.5, 0.4, 2.4)]
	for target in cases:
		for correct in [true, false]:
			var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
			game.shootout.record(0, true)
			game._start_penalty_turn()
			await physics_frames(5)
			var zone: Vector3 = target if correct else Vector3(target.x, target.y, -target.z)
			game._keeper_zone = zone
			game._pick_t = 1.0
			# La CPU patea a `target` (sin error de precision) a velocidad media.
			var p := ShotParams.new()
			p.target = target
			p.power = 0.55
			p.speed = 21.0
			p.kind = ShotCatalog.Kind.NORMAL
			p.direction = Vector3(target.x - game.ball_spot.x, 0, target.z - game.ball_spot.z).normalized()
			GestureShotModel.solve(p, game.ball_spot, game.shot_context(), false)
			game.phase = SetPieceGame.Phase.RUNUP
			game._take_shot(game.cpu_shooter, p, 0.0)
			var n: int = 0
			while game.phase in [SetPieceGame.Phase.RUNUP, SetPieceGame.Phase.FLIGHT] and n < 900:
				await tree.physics_frame
				n += 1
			var k: SpKeeper = game.user_keeper
			note("tiro a (%.1f, %.1f), arquero a %s: estirada %s, toque «%s», resultado %s" % [target.z, target.y, "la zona" if correct else "el otro lado",
				str(k.plan.get("clip", "-")), k.touch_kind, game.outcome])
			if correct and k.touch_kind != &"":
				touched_right += 1
			if not correct and k.touch_kind != &"":
				touched_wrong += 1
			cleanup()
	check(touched_right >= 2, "lanzandose a la zona del tiro la toca (%d de 3)" % touched_right)
	check(touched_wrong == 0, "lanzandose al otro lado no la toca (%d)" % touched_wrong)
