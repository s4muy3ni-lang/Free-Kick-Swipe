extends TestCase
## «Aros de fuego»: pasar = cruzar el plano del aro por adentro; el aro es fisico (el borde rebota); la secuencia vale
## solo completa en un tiro; cada nivel llega al bronce.

func _game(level: int) -> ArosFuego:
	var d: Dictionary = MinigameCatalog.level("aros_fuego", level)
	d["seed"] = 2
	d["practice"] = true
	Minigame.next_def = d
	var g: ArosFuego = (load(ArosFuego.SCENE) as PackedScene).instantiate()
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

func test_pass_through_and_rim_bounce() -> void:
	var g: ArosFuego = await _game(1)
	var e: Dictionary = g.rings[0]
	var it: Dictionary = g.cpu_shot(g.ring_center(e), 16.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	await _wait(g)
	check(g.total_pts == 100, "por el centro suma 100 (%d)" % g.total_pts)
	# Al borde de arriba: rebota en el aro (no pasa).
	it = g.cpu_shot(g.ring_center(e) + Vector3(0, float(e["r"]), 0), 16.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	var vx_min: float = INF
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < 300:
		await tree.physics_frame
		n += 1
		vx_min = minf(vx_min, g.ball.linear_velocity.x)
	await _wait(g)
	note("al borde: puntos %d, velocidad x minima %.1f" % [g.total_pts, vx_min])
	check(g.total_pts == 100, "al borde no suma")
	cleanup()

func test_every_level_reaches_bronze() -> void:
	for lv in range(1, MinigameCatalog.levels("aros_fuego").size() + 1):
		var g: ArosFuego = await _game(lv)
		var k: int = 0
		while g.state != Minigame.State.OVER and k < 12:
			# El aro de mas valor (o el ultimo de la secuencia, apuntando a su centro); el que se mueve, adelantado.
			var best: Dictionary = g.rings[0]
			for e in g.rings:
				if int(e["value"]) > int(best["value"]) or (int(e["seq"]) >= 0 and int(e["order"]) > int(best["order"])):
					best = e
			if lv == 2:
				best = g.rings[k % g.rings.size()]
			var target: Vector3 = g.ring_center(best)
			if best.has("mover"):
				target = g.mover_at(best["mover"], g.level_time + target.x / 15.0 + 2.0 / 60.0).origin
			var it: Dictionary = g.cpu_shot(target, 16.0, 0.0, 0.0)
			await g.launch(it["v"], it["w"])
			await _wait(g)
			k += 1
		note("aros %d (%s): %d puntos, secuencias %d (medallas %s)" % [lv, g.def["title"], g.total_pts, g.seq_done, str(g.def["medals"])])
		check(g.final_score() >= int(g.def["medals"][0]), "nivel %d: llega al bronce" % lv)
		cleanup()
