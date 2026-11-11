extends TestCase
## «Duelo del guante» en relevo: los dos en la misma plataforma; la carga solo llega por un golpe real de la pelota a un
## boton del panel; la barra persiste entre turnos y no pasa de 100 %; el guante se retrae con la carga y al 100 % se
## suelta, choca con el que espera y lo despide lejos (sale de escena); la IA elige por valor esperado; los niveles se
## pueden ganar.

func _game(level: int) -> GuanteDuel:
	var d: Dictionary = MinigameCatalog.level("guante", level)
	d["seed"] = 11
	d["practice"] = true
	Minigame.next_def = d
	var g: GuanteDuel = (load(GuanteDuel.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(10)
	return g

func _wait(g: Minigame, limit: int = 60 * 8) -> String:
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < limit:
		await tree.physics_frame
		n += 1
	var r: String = g.last_result
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
		await physics_frames(2)
	return r

func _shoot_button(g: GuanteDuel, i: int, speed: float = 19.0) -> String:
	var it: Dictionary = g.cpu_shot(g.button_target(i, speed), speed, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	return await _wait(g)

func test_relay_on_one_platform() -> void:
	var g: GuanteDuel = await _game(1)
	var kicker: SpActor = g.shooters[0].actor
	var waiting: SpActor = g.shooters[1].actor
	check(kicker.visible and waiting.visible, "los dos estan en escena (duelo)")
	check(waiting.global_position.distance_to(GuanteDuel.WAIT_SPOT) < 0.05, "el que no patea espera frente al guante")
	check(absf(kicker.global_position.x - waiting.global_position.x) < 6.0, "en la misma plataforma")
	cleanup()

func test_charge_only_from_real_hits_and_persists() -> void:
	var g: GuanteDuel = await _game(1)
	g.state = Minigame.State.FLIGHT
	var c0: Vector3 = g.button_center(0)
	g.ball.reset_at(c0 + Vector3(-0.4, 0, 0))
	await physics_frames(2)
	g.ball.kick(Vector3(1.2, 0, 0), Vector3.ZERO, null)
	await physics_frames(40)
	check(is_zero_approx(float(g.charge[0])), "un toque lento no carga")
	cleanup()
	g = await _game(1)
	var r: String = await _shoot_button(g, 0)
	check(r == "carga" and is_equal_approx(float(g.charge[0]), 0.2), "el grande suma 20 %% (%s, %.2f)" % [r, g.charge[0]])
	var n: int = 0
	while g.side != Minigame.Side.USER and n < 60 * 20:
		await tree.physics_frame
		n += 1
		if g.state == Minigame.State.RESOLVE:
			g._after_resolve()
	check(is_equal_approx(float(g.charge[0]), 0.2), "la carga persiste entre turnos")
	r = await _shoot_button(g, 2)
	check(is_equal_approx(float(g.charge[0]), 0.75), "chico suma 55 %% (total 75 %%: %.2f)" % g.charge[0])
	cleanup()

func test_glove_launches_the_waiting_player_out_of_the_scene() -> void:
	var g: GuanteDuel = await _game(1)
	g.charge[0] = 0.8
	await physics_frames(60)
	note("con 80 %% el guante quedo en x = %.2f" % float(g.glove["x"]))
	check(absf(float(g.glove["x"]) + 0.8 * GuanteDuel.RETRACT) < 0.03, "el guante se retrae con la carga")
	var rival: SpActor = g.shooters[1].actor
	var before: Vector3 = rival.global_position
	var it: Dictionary = g.cpu_shot(g.button_target(0, 19.0), 19.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	var far: float = 0.0
	var vanished := false
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < 600:
		await tree.physics_frame
		n += 1
		far = maxf(far, rival.global_position.distance_to(before))
		if not rival.visible:
			vanished = true
	var r: String = await _wait(g)
	note("golpe: %s, guante a %.1f m/s, el rival volo %.1f m, salio de escena %s" % [r, float(g.glove["hit_speed"]), far, str(vanished)])
	check(r == "golpe" and int(g.points[0]) == 1, "al 100 % el guante sale y conecta")
	check(far > 6.0, "lo tira lejos (vuelo con el impulso del choque)")
	check(vanished, "y sale de escena")
	check(is_zero_approx(float(g.charge[0])), "la barra vuelve a 0")
	cleanup()

func test_ai_picks_buttons_by_expected_value() -> void:
	var g: GuanteDuel = await _game(1)
	var easy: int = g.choose_button(1, 1.8)
	var expert: int = g.choose_button(1, 0.55)
	g.charge[1] = 0.85
	var near_full: int = g.choose_button(1, 0.55)
	note("IA: facil %s, experta %s, con 85 %% %s" % [g.buttons[easy]["size"], g.buttons[expert]["size"], g.buttons[near_full]["size"]])
	check(easy == 0, "con mucho error va al grande")
	check(expert != 0, "con buena punteria va a uno que carga mas")
	check(near_full == 0, "si le falta poco, el grande ya completa")
	cleanup()

func test_every_level_can_be_won() -> void:
	for lv in range(1, MinigameCatalog.levels("guante").size() + 1):
		var g: GuanteDuel = await _game(lv)
		g.cpu_error_deg = 1.3
		var n: int = 0
		while g.state != Minigame.State.OVER and n < 60 * 300:
			if g.state == Minigame.State.AIM and g.side == Minigame.Side.USER:
				var i: int = 0 if float(g.charge[0]) >= 0.8 else 1
				await _shoot_button(g, i)
				continue
			if g.state == Minigame.State.RESOLVE:
				g._after_resolve()
			await tree.physics_frame
			n += 1
		note("nivel %d (%s): %s, golpes %d - %d, tiros %d, puntaje %d" % [lv, g.def["title"], "gano" if g.winner == Minigame.Side.USER else "perdio", g.points[0], g.points[1], g.shots[0], g.final_score()])
		check(g.state == Minigame.State.OVER and g.winner == Minigame.Side.USER, "nivel %d: se puede ganar" % lv)
		check(g.final_score() >= int(g.def["medals"][0]), "nivel %d: llega al bronce" % lv)
		cleanup()
