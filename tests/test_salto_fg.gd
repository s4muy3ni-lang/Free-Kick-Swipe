extends TestCase
## «Salto en alto» y «Field Goal»: la varilla es un cuerpo suelto que se cae si la pelota la toca (nulo); pasar por
## arriba sube la varilla; tres nulos terminan. Field goal: vale solo por arriba del travesaño y entre los verticales;
## cada nivel llega al bronce con patadas del modelo.

func _game(id: String, level: int) -> Minigame:
	var d: Dictionary = MinigameCatalog.level(id, level)
	d["seed"] = 3
	d["practice"] = true
	Minigame.next_def = d
	var g: Minigame = (load(String(d["scene"])) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(10)
	return g

func _wait(g: Minigame, limit: int = 60 * 10) -> String:
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < limit:
		await tree.physics_frame
		n += 1
	var r: String = g.last_result
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
		await physics_frames(2)
	return r

func test_bar_falls_on_contact_and_rises_when_cleared() -> void:
	var g: SaltoAlto = await _game("salto_alto", 1)
	# Pelotazo directo a la varilla: se cae de los tacos (cuerpo suelto), y el intento es nulo.
	g.state = Minigame.State.FLIGHT
	g.ball.reset_at(Vector3(g.bar_x - 0.6, g.height, 0.3))
	await physics_frames(2)
	g.ball.kick(Vector3(8.0, 0, 0), Vector3.ZERO, null)
	await physics_frames(90)
	note("pelotazo a la varilla: en su lugar %s (%.2f m del taco)" % [str(g.bar_in_place()), g.bar.global_position.distance_to(g._bar_home.origin)])
	check(not g.bar_in_place(), "un golpe real tira la varilla")
	cleanup()
	g = await _game("salto_alto", 1)
	var it: Dictionary = g.cpu_shot(Vector3(g.bar_x, g.height - 0.4, 0.4), 13.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	var r: String = await _wait(g)
	check(r != "valido" and g.tries_left == 2, "por debajo de la varilla es nulo")
	# Por arriba: valido y sube.
	var h0: float = g.height
	it = g.cpu_shot(Vector3(g.bar_x, g.height + 0.45, 0.0), 13.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	r = await _wait(g)
	check(r == "valido" and is_equal_approx(g.height, h0 + g.step) and is_equal_approx(g.best, h0), "por arriba vale y la varilla sube")
	cleanup()

func test_every_salto_level_reaches_bronze_and_ends() -> void:
	for lv in range(1, MinigameCatalog.levels("salto_alto").size() + 1):
		var g: SaltoAlto = await _game("salto_alto", lv)
		var n: int = 0
		while g.state != Minigame.State.OVER and n < 60:
			n += 1
			var sp: float = 11.0 + g.height * 1.6
			var it: Dictionary = g.cpu_shot(Vector3(g.bar_x, g.height + 0.35, 0.0), sp, 0.0, 0.0)
			await g.launch(it["v"], it["w"])
			await _wait(g)
		note("salto %d (%s): record %.2f m en %d saltos, puntaje %d (medallas %s)" % [lv, g.def["title"], g.best, n, g.final_score(), str(g.def["medals"])])
		check(g.state == Minigame.State.OVER, "salto %d: termina con tres nulos" % lv)
		check(g.final_score() >= int(g.def["medals"][0]), "salto %d: llega al bronce" % lv)
		cleanup()

func test_field_goal_rules_and_levels() -> void:
	var g: FieldGoal = await _game("field_goal", 1)
	# Por debajo del travesaño: afuera.
	var it: Dictionary = g.cpu_shot(Vector3(g.post_x, 1.6, 0.0), 22.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	var r: String = await _wait(g)
	check(r == "afuera" and int(g.points[0]) == 0, "por debajo del travesaño no vale")
	cleanup()
	for lv in range(1, MinigameCatalog.levels("field_goal").size() + 1):
		g = await _game("field_goal", lv)
		var res: Array = []
		while g.state != Minigame.State.OVER and res.size() < 10:
			var spot: Vector3 = g._ball_spot(0)
			var dist: float = g.post_x - spot.x
			var sp: float = clampf(14.0 + dist * 0.42, 18.0, 33.0)
			# Contra el viento: apunta hacia el lado del que viene (un poco).
			var aim := Vector3(g.post_x, g.CROSSBAR + 1.5 + dist * 0.03, -g.wind * dist * 0.012)
			var it2: Dictionary = g.cpu_shot(aim, sp, 0.0, 0.0)
			await g.launch(it2["v"], it2["w"])
			res.append("%dm %s" % [int(dist), await _wait(g)])
		note("field goal %d (%s): %s -> %d puntos, puntaje %d (medallas %s)" % [lv, g.def["title"], ", ".join(res), int(g.points[0]), g.final_score(), str(g.def["medals"])])
		check(g.state == Minigame.State.OVER and g.final_score() >= int(g.def["medals"][0]), "field goal %d: llega al bronce" % lv)
		cleanup()
