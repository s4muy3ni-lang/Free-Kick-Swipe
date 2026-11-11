extends TestCase
## «Fútbol de precisión»: el puntaje sale del sector por donde la pelota CRUZA la linea; el arquero de carton la frena
## por choque real; cada nivel llega al bronce apuntando a las esquinas y esquivando al carton.

func _game(level: int) -> Precision:
	var d: Dictionary = MinigameCatalog.level("precision", level)
	d["seed"] = 5
	d["practice"] = true
	Minigame.next_def = d
	var g: Precision = (load(Precision.SCENE) as PackedScene).instantiate()
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

func test_sector_scores_by_real_crossing() -> void:
	var g: Precision = await _game(1)
	var got: Array = []
	for rc in [[0, 0], [0, 2], [1, 1], [2, 4]]:
		var target: Vector3 = g.sector_center(int(rc[0]), int(rc[1]))
		var it: Dictionary = g.cpu_shot(target, 20.0, 0.0, 0.0)
		var before: int = int(g.points[0])
		await g.launch(it["v"], it["w"])
		var r: String = await _wait(g)
		var want: int = int(g.grid[int(rc[0])][int(rc[1])])
		got.append("%s -> %s +%d" % [str(rc), r, int(g.points[0]) - before])
		check(r == "gol" and int(g.points[0]) - before == want, "sector %s suma %d" % [str(rc), want])
	note(", ".join(got))
	cleanup()

func test_cardboard_keeper_blocks_physically() -> void:
	var g: Precision = await _game(2)
	# Tiro al lugar donde va a estar el carton cuando llegue la pelota (a la altura de su pecho).
	var tof: float = 20.0 / 18.0 + 2.0 / 60.0
	var kp: Vector3 = g.mover_at(g.keeper_mover, g.level_time + tof).origin
	var it: Dictionary = g.cpu_shot(Vector3(g.goal_x, 1.3, kp.z), 20.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	var r: String = await _wait(g)
	note("tiro al carton: %s, puntos %d" % [r, int(g.points[0])])
	check(r != "gol" and int(g.points[0]) == 0, "el carton la ataja: no suma")
	cleanup()

func test_every_level_reaches_bronze() -> void:
	for lv in range(1, MinigameCatalog.levels("precision").size() + 1):
		var g: Precision = await _game(lv)
		var k: int = 0
		while g.state != Minigame.State.OVER and k < 12:
			k += 1
			# La esquina de 10 mas lejos de donde va a estar el carton.
			var best: Vector3 = g.sector_center(0, 0)
			if g.keeper != null:
				var kp: Vector3 = g.mover_at(g.keeper_mover, g.level_time + 1.2).origin
				var other: Vector3 = g.sector_center(0, (g.grid[0] as Array).size() - 1)
				best = other if absf(other.z - kp.z) > absf(best.z - kp.z) else best
			# Un poco hacia adentro de la esquina (los palos estan al borde).
			best.z *= 0.92
			best.y -= 0.1
			var it: Dictionary = g.cpu_shot(best, 20.0, 0.0, 0.0)
			await g.launch(it["v"], it["w"])
			await _wait(g)
		note("nivel %d (%s): %d puntos (medallas %s)" % [lv, g.def["title"], int(g.points[0]), str(g.def["medals"])])
		check(g.state == Minigame.State.OVER and g.final_score() >= int(g.def["medals"][0]), "nivel %d: llega al bronce" % lv)
		cleanup()
