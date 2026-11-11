extends TestCase
## «Piedras saltarinas»: un tiro rasante y rapido pica en el agua varias veces (impulso del agua); uno empinado se clava
## y flota; cada nivel llega al bronce.

func _game(level: int) -> Piedras:
	var d: Dictionary = MinigameCatalog.level("piedras", level)
	d["seed"] = 2
	d["practice"] = true
	Minigame.next_def = d
	var g: Piedras = (load(Piedras.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(10)
	return g

func _wait(g: Minigame, limit: int = 60 * 18) -> String:
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < limit:
		await tree.physics_frame
		n += 1
	var r: String = g.last_result
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
		await physics_frames(2)
	return r

func test_flat_skips_and_steep_plunges() -> void:
	var g: Piedras = await _game(1)
	var v: Vector3 = Piedras.flat_kick(22.0, 8.0)
	await g.launch(v, Vector3.ZERO)
	var r: String = await _wait(g)
	var flat: Dictionary = g.throws.back()
	note("rasante 22 m/s a 8 grados: %s, %d piques, %.1f m" % [r, int(flat["skips"]), float(flat["distance"])])
	check(int(flat["skips"]) >= 3, "rasante y rapido: varios piques")
	v = Piedras.flat_kick(16.0, 40.0)
	await g.launch(v, Vector3.ZERO)
	r = await _wait(g)
	var steep: Dictionary = g.throws.back()
	note("empinado 40 grados: %s, %d piques; pelota flotando en y=%.2f" % [r, int(steep["skips"]), g.ball.global_position.y])
	check(int(steep["skips"]) == 0 and r == "clavada", "empinado: se clava sin picar")
	cleanup()

func test_every_level_reaches_bronze() -> void:
	for lv in range(1, MinigameCatalog.levels("piedras").size() + 1):
		var g: Piedras = await _game(lv)
		var k: int = 0
		while g.state != Minigame.State.OVER and k < 10:
			await g.launch(Piedras.flat_kick(21.0 + float(k % 3), 7.0 + float(k % 2) * 2.0), Vector3.ZERO)
			await _wait(g)
			k += 1
		note("piedras %d (%s): mejor %d piques, %.1f m, suma %d, puntaje %d (medallas %s)" % [lv, g.def["title"], g.best_skips(), g.best_distance(), g.total_skips(), g.final_score(), str(g.def["medals"])])
		check(g.final_score() >= int(g.def["medals"][0]), "nivel %d: llega al bronce" % lv)
		cleanup()
