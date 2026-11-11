extends TestCase
## «Béisbol» con bate mecanico: el bate es un cuerpo rigido que gira sobre su pivote; el sensor lo suelta a tiempo; el
## choque real manda la pelota al jardin (velocidad de salida, distancia, jonron); una pelota fuera de la zona es strike;
## los niveles llegan al bronce.

func _game(level: int) -> Beisbol:
	var d: Dictionary = MinigameCatalog.level("beisbol", level)
	d["seed"] = 6
	d["practice"] = true
	Minigame.next_def = d
	var g: Beisbol = (load(Beisbol.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(10)
	return g

func _wait(g: Minigame, limit: int = 60 * 14) -> String:
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < limit:
		await tree.physics_frame
		n += 1
	var r: String = g.last_result
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
		await physics_frames(2)
	return r

func test_bat_hits_with_real_impulse() -> void:
	var g: Beisbol = await _game(1)
	var it: Dictionary = g.cpu_shot(g.ideal_target(), 19.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	var vin: float = (it["v"] as Vector3).length()
	var r: String = await _wait(g)
	var last: Dictionary = g.results[0].back()
	note("pelota a %.1f m/s -> %s, salio a %.1f m/s, %.1f m, jonron %s" % [vin, r, float(last["exit"]), float(last["distance"]), str(last["homer"])])
	check(r == "hit" or r == "jonron", "la pelota en la zona es golpeada y va al jardin")
	check(float(last["exit"]) > 18.0, "el bate (cuerpo rigido) le da una velocidad de salida real")
	check(float(last["distance"]) > 20.0, "y llega lejos")
	cleanup()

func test_ball_outside_the_zone_is_a_strike() -> void:
	var g: Beisbol = await _game(1)
	var it: Dictionary = g.cpu_shot(g.ideal_target() + Vector3(0, 1.4, 0), 19.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	var r: String = await _wait(g)
	check(r == "strike" and not g.hit, "una pelota alta no toca el bate: strike")
	cleanup()

func test_every_level_reaches_bronze() -> void:
	for lv in range(1, MinigameCatalog.levels("beisbol").size() + 1):
		var g: Beisbol = await _game(lv)
		g.cpu_error_deg = 1.0
		var n: int = 0
		while g.state != Minigame.State.OVER and n < 60 * 200:
			if g.state == Minigame.State.AIM and g.side == Minigame.Side.USER:
				var it: Dictionary = g.cpu_shot(g.ideal_target(), 19.0, 0.0, 0.0)
				await g.launch(it["v"], it["w"])
				await _wait(g)
				continue
			if g.state == Minigame.State.RESOLVE:
				g._after_resolve()
			await tree.physics_frame
			n += 1
		var ds: Array = []
		for x in g.results[0]:
			ds.append("%s %.0f" % [x["result"], float(x["distance"])])
		note("nivel %d (%s): %s; jonrones %d (CPU %d), puntaje %d, medallas %s" % [lv, g.def["title"], ", ".join(ds), g.homers(0), g.homers(1), g.final_score(), str(g.def["medals"])])
		check(g.state == Minigame.State.OVER, "nivel %d: termina" % lv)
		check(g.final_score() >= int(g.def["medals"][0]), "nivel %d: llega al bronce" % lv)
		cleanup()
