extends TestCase
## «Duelo del guante»: la carga solo llega por un golpe real de la pelota a un boton de la maquina propia; la barra
## persiste entre turnos y no pasa de 100 %; el guante se retrae con la carga y al 100 % se suelta, viaja con su resorte,
## choca con el cuerpo del rival y lo empuja hacia atras (impulso por masas y rozamiento); la IA elige el boton por valor
## esperado segun su error y lo que le falta; el partido termina y cada nivel se puede ganar.

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

## Tiro del usuario a un boton de su maquina, sin error (para medir).
func _shoot_button(g: GuanteDuel, i: int, speed: float = 18.0) -> String:
	var target: Vector3 = g.button_center(0, i) + g.button_normal(0) * (g.ball.radius + GuanteDuel.CAP_DEPTH * 0.5)
	var it: Dictionary = g.cpu_shot(target, speed, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	return await _wait(g)

func test_catalog_and_category() -> void:
	check(MinigameCatalog.levels("guante").size() == 4, "4 niveles")
	var found := false
	for c in MinigameCatalog.categories():
		if String(c["id"]) == "duelos":
			for it in c["items"]:
				if String((it as Dictionary).get("game", "")) == "guante":
					found = true
	check(found, "esta en DUELOS")

func test_charge_only_from_real_hits_and_persists() -> void:
	var g: GuanteDuel = await _game(1)
	# Un toque lento contra el boton grande: no carga.
	g.state = Minigame.State.FLIGHT
	var c0: Vector3 = g.button_center(0, 0)
	g.ball.reset_at(c0 + g.button_normal(0) * 0.4)
	await physics_frames(2)
	g.ball.kick(-g.button_normal(0) * 1.2, Vector3.ZERO, null)
	await physics_frames(40)
	check(is_zero_approx(float(g.charge[0])), "un toque lento no carga")
	cleanup()
	g = await _game(1)
	var r: String = await _shoot_button(g, 0)
	note("tiro al grande: %s, carga %.2f" % [r, g.charge[0]])
	check(r == "carga" and is_equal_approx(float(g.charge[0]), 0.2), "el grande suma 20 %")
	# Turno de la CPU (patea con su error); la carga del usuario sigue ahi.
	var n: int = 0
	while g.side != Minigame.Side.USER and n < 60 * 20:
		await tree.physics_frame
		n += 1
		if g.state == Minigame.State.RESOLVE:
			g._after_resolve()
	check(is_equal_approx(float(g.charge[0]), 0.2), "la carga persiste entre turnos")
	r = await _shoot_button(g, 2)
	check(is_equal_approx(float(g.charge[0]), 0.75), "chico suma 55 % (total 75 %)")
	cleanup()

func test_glove_retracts_fires_and_knocks_the_rival_back() -> void:
	var g: GuanteDuel = await _game(1)
	g.charge[0] = 0.8
	await physics_frames(60)
	var m: Dictionary = g.machines[0]
	note("con 80 %% el guante quedo en x = %.2f (retraccion maxima %.2f)" % [m["x"], GuanteDuel.RETRACT])
	check(absf(float(m["x"]) + 0.8 * GuanteDuel.RETRACT) < 0.03, "el guante se retrae con la carga (resorte comprimido)")
	var rival: SpActor = g.shooters[1].actor
	var before: Vector3 = rival.global_position
	var target: Vector3 = g.button_center(0, 0) + g.button_normal(0) * (g.ball.radius + GuanteDuel.CAP_DEPTH * 0.5)
	var it: Dictionary = g.cpu_shot(target, 18.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	# Se mide mientras dura la jugada (al turno siguiente cada uno vuelve a su lugar).
	var back: float = 0.0
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < 600:
		await tree.physics_frame
		n += 1
		back = maxf(back, (rival.global_position - before).dot(m["dir"]))
	var r: String = await _wait(g)
	note("golpe: %s, velocidad del guante al chocar %.1f m/s, rival empujado %.2f m hacia atras, golpes %d" % [r, float(m.get("hit_speed", 0.0)), back, g.points[0]])
	check(r == "golpe" and int(g.points[0]) == 1, "al 100 % el guante sale y conecta")
	check(float(m.get("hit_speed", 0.0)) > 6.0, "el piston llega con velocidad de resorte")
	check(back > 0.3, "el rival sale despedido hacia atras por el impulso")
	check(is_zero_approx(float(g.charge[0])), "la barra vuelve a 0")
	cleanup()

func test_ai_picks_buttons_by_expected_value() -> void:
	var g: GuanteDuel = await _game(1)
	var easy: int = g.choose_button(1, 1.8)
	var expert: int = g.choose_button(1, 0.55)
	g.charge[1] = 0.85
	var near_full: int = g.choose_button(1, 0.55)
	note("IA: facil elige %s, experta %s, con 85 %% elige %s" % [g.machines[1]["buttons"][easy]["size"], g.machines[1]["buttons"][expert]["size"], g.machines[1]["buttons"][near_full]["size"]])
	check(easy == 0, "con mucho error va al grande (seguro)")
	check(expert != 0, "con buena punteria va a uno que carga mas")
	check(near_full == 0, "si le falta poco, el grande ya completa: no arriesga")
	cleanup()

func test_every_level_can_be_won_and_the_match_ends() -> void:
	for lv in range(1, MinigameCatalog.levels("guante").size() + 1):
		var g: GuanteDuel = await _game(lv)
		g.cpu_error_deg = 1.3
		var presses: int = 0
		var n: int = 0
		while g.state != Minigame.State.OVER and n < 60 * 240:
			if g.state == Minigame.State.AIM and g.side == Minigame.Side.USER:
				# El usuario va al mediano (o al grande si le falta poco), sin error.
				var i: int = 0 if float(g.charge[0]) >= 0.8 else 1
				var r: String = await _shoot_button(g, i)
				if r == "carga" or r == "golpe":
					presses += 1
				continue
			if g.state == Minigame.State.RESOLVE:
				g._after_resolve()
			await tree.physics_frame
			n += 1
		note("nivel %d (%s): %s, golpes %d - %d, tiros %d, puntaje %d" % [lv, g.def["title"], "gano" if g.winner == Minigame.Side.USER else "perdio/sin fin", g.points[0], g.points[1], g.shots[0], g.final_score()])
		check(g.state == Minigame.State.OVER and g.winner == Minigame.Side.USER, "nivel %d: se puede ganar" % lv)
		check(g.final_score() >= int(g.def["medals"][0]), "nivel %d: llega al bronce" % lv)
		cleanup()
