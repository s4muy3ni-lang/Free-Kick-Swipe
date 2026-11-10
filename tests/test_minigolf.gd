extends TestCase
## Minigolf (etapa A3): el hoyo captura solo a la pelota LENTA (la rapida lo salta), la arena frena de verdad, salir de la
## cancha penaliza un golpe y repone, el puntaje premia menos golpes (sin hoyo no hay puntos) y cada hoyo se puede
## completar con la fisica real siguiendo los puntos de guia del nivel.

func _game(level: int) -> Minigolf:
	var d: Dictionary = MinigameCatalog.level("minigolf", level)
	d["seed"] = 5
	d["practice"] = true
	Minigame.next_def = d
	var g: Minigolf = (load(Minigolf.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	return g

func _stroke(g: Minigolf, target: Vector3, speed: float, loft: float = 0.0) -> String:
	var power: float = clampf((speed - Minigolf.SPEED_MIN) / (Minigolf.SPEED_MAX - Minigolf.SPEED_MIN), 0.0, 1.0)
	var vw: Array = g.golf_velocity(target, power, loft)
	await g.launch(vw[0], vw[1])
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < 60 * 12:
		await tree.physics_frame
		n += 1
	var r: String = g.last_result
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
		await physics_frames(2)
	return r

func test_hole_captures_only_slow_balls() -> void:
	var g: Minigolf = await _game(1)
	g.start_match()
	await physics_frames(5)
	var r: String = await _stroke(g, g.hole, 14.0)
	note("tiro fuerte al hoyo: %s (pelota en x=%.1f, hoyo en x=%.1f)" % [r, g.ball.global_position.x, g.hole.x])
	check(not g.holed, "a 14 m/s la pelota salta el hoyo (no se captura)")
	cleanup()
	g = await _game(1)
	g.start_match()
	await physics_frames(5)
	g._spot = Vector3(g.hole.x - 3.0, 0.11, g.hole.z)
	g._start_turn()
	await physics_frames(3)
	r = await _stroke(g, g.hole, 4.4)
	note("tiro suave desde 3 m: %s" % r)
	check(r == "hoyo" and g.holed, "despacio, entra")
	cleanup()

func test_out_of_bounds_penalizes_and_replaces() -> void:
	var g: Minigolf = await _game(1)
	g.start_match()
	await physics_frames(5)
	var spot0: Vector3 = g._spot
	var r: String = await _stroke(g, g.tee + Vector3(0, 0, 10.0), 15.0)
	check(r == "fuera" and g.penalties == 1, "salir de la cancha: un golpe de penalización (%s)" % r)
	check(g._spot.distance_to(spot0) < 0.05, "se repone donde se jugó")
	check(g.strokes() == 2, "golpes = tiros + penalizaciones (%d)" % g.strokes())
	cleanup()

func test_sand_really_slows_the_ball() -> void:
	# El mismo golpe en el nivel 1 (sin arena) y en el 6 (con arena en el camino): con arena recorre menos.
	var clean: float = 0.0
	for lv in [1, 6]:
		var g: Minigolf = await _game(lv)
		g.start_match()
		await physics_frames(5)
		g._spot = Vector3(2.0, 0.11, -2.5)
		g._start_turn()
		await physics_frames(3)
		await _stroke(g, Vector3(12.0, 0, -2.5), 9.0)
		var dist: float = g.ball.global_position.x - 2.0
		note("nivel %d: la pelota recorrio %.1f m" % [lv, dist])
		if lv == 1:
			clean = dist
		else:
			check(dist < clean - 1.0, "la arena frena (%.1f m vs %.1f m)" % [dist, clean])
		cleanup()

func test_scoring_rewards_fewer_strokes() -> void:
	var g: Minigolf = await _game(1)
	g.holed = true
	g.shots[0] = 1
	check(g.final_score() == 45, "birdie en par 2: 45 puntos (%d)" % g.final_score())
	g.shots[0] = 2
	check(g.final_score() == 30, "par: 30")
	g.shots[0] = 4
	check(g.final_score() == 5, "muy pasado: casi nada")
	g.holed = false
	check(g.final_score() == 0, "sin embocar no hay puntos")
	cleanup()

func test_every_hole_is_solvable_following_the_guide() -> void:
	for lv in range(1, MinigameCatalog.levels("minigolf").size() + 1):
		var g: Minigolf = await _game(lv)
		g.start_match()
		await physics_frames(5)
		var guide: Array = g.def.get("guide", [])
		var wp: int = 0
		var used: int = 0
		while not g.holed and g.state != Minigame.State.OVER and used < g.par * 3:
			# Apunta al proximo punto de guia (o al hoyo) con una velocidad proporcional a la distancia.
			while wp < guide.size() and Vector2(g._spot.x - float(guide[wp][0]), g._spot.z - float(guide[wp][2])).length() < 1.6:
				wp += 1
			var target: Vector3 = BotonCaida._vec(guide[wp]) if wp < guide.size() else Vector3(g.hole.x, 0, g.hole.z)
			var last: bool = wp >= guide.size() or (wp == guide.size() - 1 and Vector2(target.x - g.hole.x, target.z - g.hole.z).length() < 0.5)
			var dist: float = Vector2(g._spot.x - target.x, g._spot.z - target.z).length()
			var speed: float = clampf(dist * (0.78 if last else 1.0) + 1.5, 3.2, 17.0)
			# Rampa: desde abajo prueba potencias distintas hasta quedar arriba; arriba, toque corto.
			if lv == 3:
				speed = [13.0, 14.5, 16.0][used % 3] if g._spot.y < 0.5 else clampf(dist * 0.85 + 1.2, 3.2, 8.0)
			used += 1
			await _stroke(g, target, speed)
		note("hoyo %d (%s): %s en %d golpes (par %d)" % [lv, g.def["title"], "embocado" if g.holed else "NO EMBOCADO", g.strokes(), g.par])
		check(g.holed, "hoyo %d: se puede completar siguiendo la guía" % lv)
		check(g.strokes() <= g.par * 3, "hoyo %d: dentro del tope de golpes" % lv)
		cleanup()
