extends TestCase
## «Dardos»: el puntaje sale del punto de impacto real (sector, doble, triple, bull y centro); las reglas de cada nivel
## (sector, 301 con «reventar», duelo contra la IA) y cada nivel llega al bronce con tiros del modelo.

func _game(level: int) -> Dardos:
	var d: Dictionary = MinigameCatalog.level("dardos", level)
	d["seed"] = 4
	d["practice"] = true
	Minigame.next_def = d
	var g: Dardos = (load(Dardos.SCENE) as PackedScene).instantiate()
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

func _throw(g: Dardos, sector: int, mult: int) -> Dictionary:
	var it: Dictionary = g.cpu_shot(g.face_world(g.aim_face(sector, mult)), 21.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	await _wait(g)
	return g.last_hit

func test_board_geometry_and_scores() -> void:
	var g: Dardos = await _game(1)
	check(int(g.score_at(Vector2.ZERO)["score"]) == 50, "centro 50")
	check(int(g.score_at(Vector2(0, 0.2))["score"]) == 25, "bull 25")
	check(int(g.score_at(g.aim_face(20, 3))["score"]) == 60, "triple 20 = 60")
	check(int(g.score_at(g.aim_face(6, 2))["score"]) == 12, "doble 6 = 12 (a la derecha)")
	check(int(g.score_at(g.aim_face(11, 1))["score"]) == 11, "11 a la izquierda")
	check(int(g.score_at(Vector2(0, g.radius + 0.5))["score"]) == 0, "afuera 0")
	cleanup()

func test_score_comes_from_the_real_impact() -> void:
	var g: Dardos = await _game(1)
	var got: Array = []
	for t in [[20, 3], [25, 1], [6, 2], [3, 1]]:
		var h: Dictionary = await _throw(g, int(t[0]), int(t[1]))
		got.append("%s -> %s (%.2f, %.2f)" % [str(t), String(h.get("label", "-")), (h.get("point", Vector2.INF) as Vector2).x, (h.get("point", Vector2.INF) as Vector2).y])
		var want: int = 50 if int(t[0]) == 25 else int(t[0]) * int(t[1])
		check(int(h.get("score", -1)) == want, "tiro a %s suma %d" % [str(t), want])
	note(", ".join(got))
	cleanup()

func test_301_bust_and_sector_rule() -> void:
	var g: Dardos = await _game(3)
	g.remaining[0] = 30
	var h: Dictionary = await _throw(g, 20, 3)
	check(bool(h.get("bust", false)) and int(g.remaining[0]) == 30, "con 30 restantes, un triple 20 revienta y no cuenta")
	h = await _throw(g, 10, 3)
	check(int(g.remaining[0]) == 0 and g.state == Minigame.State.OVER and g.winner == Minigame.Side.USER, "triple 10 cierra exacto y gana")
	cleanup()
	g = await _game(2)
	await _throw(g, 1, 1)
	check(int(g.points[0]) == 0, "en «Solo el 20», el 1 no suma")
	await _throw(g, 20, 2)
	check(int(g.points[0]) == 40, "el doble 20 suma 40")
	cleanup()

func test_every_level_reaches_bronze() -> void:
	for lv in range(1, MinigameCatalog.levels("dardos").size() + 1):
		var g: Dardos = await _game(lv)
		g.cpu_error_deg = 1.15
		var n: int = 0
		while g.state != Minigame.State.OVER and n < 60 * 120:
			if g.state == Minigame.State.AIM and g.side == Minigame.Side.USER:
				var target: Vector2 = g.aim_face(20, 3)
				if g.rule == "301":
					var left: int = int(g.remaining[0])
					# Cierre: busca el numero exacto (simple, doble o triple), si no, triple 20.
					target = g.aim_face(20, 3)
					for m in [1, 2, 3]:
						for sec in Dardos.ORDER:
							if int(sec) * m == left:
								target = g.aim_face(int(sec), m)
					if left == 50:
						target = Vector2.ZERO
					elif left < 60 and left > 40:
						target = g.aim_face(left - 40, 1) if Dardos.ORDER.has(left - 40) else target
				var it: Dictionary = g.cpu_shot(g.face_world(target), 21.0, 0.0, 0.0)
				await g.launch(it["v"], it["w"])
				await _wait(g)
				continue
			if g.state == Minigame.State.RESOLVE:
				g._after_resolve()
			await tree.physics_frame
			n += 1
		note("nivel %d (%s): %d puntos (CPU %d), quedan %d, puntaje %d, medallas %s" % [lv, g.def["title"], g.points[0], g.points[1], g.remaining[0], g.final_score(), str(g.def["medals"])])
		check(g.state == Minigame.State.OVER, "nivel %d: termina" % lv)
		check(g.final_score() >= int(g.def["medals"][0]), "nivel %d: llega al bronce" % lv)
		cleanup()
