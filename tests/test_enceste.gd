extends TestCase
## «Enceste» (etapa 7, desafios de habilidad): el enceste cuenta solo si la pelota cruza el aro bajando y por dentro, el
## aro es fisico (la pelota rebota en el), cada nivel tiene solucion hallada con la fisica real y sin encestes no hay
## puntos ni medalla.

func _game(level: int) -> Enceste:
	var d: Dictionary = MinigameCatalog.level("enceste", level)
	d["seed"] = 31
	d["practice"] = true
	Minigame.next_def = d
	var g: Enceste = (load(Enceste.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	return g

func _fly(g: Minigame) -> String:
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < 600:
		await tree.physics_frame
		n += 1
	return g.last_result

func test_basket_counts_only_downward_through_the_ring() -> void:
	var g: Enceste = await _game(1)
	var c: Vector3 = g.hoops[0]["center"]
	# De abajo hacia arriba por el aro (y cae al costado): no cuenta.
	g.state = Minigame.State.RUNUP
	g.ball.reset_at(c + Vector3(0, -1.2, 0))
	await physics_frames(2)
	g._prev_p = g.ball.global_position
	g.ball.kick(Vector3(0, 5.5, 2.2), Vector3.ZERO, null)
	g._on_contact({})
	var r: String = await _fly(g)
	note("de abajo hacia arriba: %s, encestes %d" % [r, g.baskets])
	check(g.baskets == 0, "subir por el aro no es enceste")
	cleanup()
	# Dejarla caer por el centro: cuenta y limpia.
	g = await _game(1)
	c = g.hoops[0]["center"]
	g.state = Minigame.State.RUNUP
	g.ball.reset_at(c + Vector3(0, 1.0, 0))
	await physics_frames(2)
	g._prev_p = g.ball.global_position
	g._on_contact({})
	r = await _fly(g)
	note("cae por el centro: %s, encestes %d, limpias %d" % [r, g.baskets, g.swishes])
	check(r == "canasta" and g.baskets == 1 and g.swishes == 1, "cae por el centro: enceste limpio")
	cleanup()
	# Cae sobre el aro: rebota en el (fisico) y no entra por fuera.
	g = await _game(1)
	c = g.hoops[0]["center"]
	g.state = Minigame.State.RUNUP
	g.ball.reset_at(c + Vector3(0, 1.0, float(g.hoops[0]["radius"]) + 0.02))
	await physics_frames(2)
	g._prev_p = g.ball.global_position
	g._on_contact({})
	r = await _fly(g)
	note("cae sobre el aro: %s, toco el aro %s, encestes %d" % [r, str(g._rim_touched), g.baskets])
	check(g._rim_touched, "el aro es fisico: la pelota lo toca")
	cleanup()

func test_every_level_has_a_solution_and_scores_are_fair() -> void:
	for lv in range(1, MinigameCatalog.levels("enceste").size() + 1):
		var g: Enceste = await _game(lv)
		check(g.final_score() == 0 and g.medal_for(0) == 0, "nivel %d: sin encestes no hay puntos ni medalla" % lv)
		var found: Array = []
		var tries: int = 0
		for hi in g.hoops.size():
			var done: bool = false
			var lid: bool = (g.def.get("hoops")[hi] as Dictionary).has("lid")
			for sp_i in 15:
				var sp: float = 10.0 + float(sp_i)
				for dy in ([0.05, 0.35, 0.8, 1.0, 1.4, 1.8] if lid else [0.05, 0.35, 0.8, 1.4]):
					for dx in [0.0, -0.2, 0.25]:
						if done:
							break
						tries += 1
						g.reset_level()
						g.state = Minigame.State.AIM
						g._start_turn()
						await physics_frames(1)
						var c: Vector3 = g.hoops[hi]["center"]
						var aim: Vector3 = c + Vector3(dx + (float(g.hoops[hi]["radius"]) + 0.15 if lid else 0.0), dy, 0.0)
						var mv: Dictionary = g.hoops[hi]["move"]
						if not mv.is_empty():
							# Aro movil: donde va a estar cuando llegue la pelota (tiempo de vuelo del tiro previsto).
							var first: Dictionary = g.cpu_shot(aim, sp, 0.0, 0.0)
							var tc: float = ShotSolver.crossing_time(first["trajectory"], aim.x)
							var axis: Vector3 = BotonCaida._vec(mv.get("axis", [0, 0, 1])).normalized()
							var w: float = float(mv.get("speed", 1.0))
							var amp: float = float(mv.get("amp", 1.5))
							var t0: float = g.level_time + 2.0 / 60.0
							aim += axis * amp * (sin((t0 + maxf(tc, 0.0)) * w) - sin(g.level_time * w))
						var it: Dictionary = g.cpu_shot(aim, sp, 0.0, 0.0)
						await g.launch(it["v"], it["w"])
						var r: String = await _fly(g)
						if r == "canasta" and bool(g.hoops[hi]["scored"]):
							done = true
							found.append("aro %d: apuntando +(%.2f, %.2f) a %.0f m/s%s" % [hi + 1, dx, dy, sp, " (limpia)" if g.swishes > 0 else ""])
			check(done, "nivel %d, aro %d: tiene solucion" % [lv, hi + 1])
		note("nivel %d (%s): %s en %d intentos" % [lv, g.def["title"], str(found), tries])
		cleanup()

## Básquet: los aros mas altos valen mas y en la ronda de tiros se puede volver a encestar en el mismo aro.
func test_hoop_values_and_repeat_round() -> void:
	var lv: int = MinigameCatalog.levels("enceste").size()
	var g: Enceste = await _game(lv)
	check(g.repeat and g.hoops.size() == 3, "ronda de tiros: tres aros que se repiten")
	var heights: Array = []
	for h in g.hoops:
		heights.append((h["center"] as Vector3).y)
	check(heights[0] < heights[1] and heights[1] < heights[2] and int(g.hoops[2]["value"]) == 3, "tres alturas distintas; el mas alto vale x3")
	# Suma directa: un enceste en el aro x3 vale 300 (+50 si es limpio), dos veces seguidas en tiros distintos.
	for k in 2:
		g._start_turn()
		check(not bool(g.hoops[2]["scored"]), "en cada tiro el aro vuelve a estar disponible")
		g.hoops[2]["scored"] = true
		g.baskets += 1
		g.basket_pts += Enceste.BASKET_POINTS * int(g.hoops[2]["value"])
	check(g.basket_pts == 600, "dos encestes en el x3 suman 600")
	cleanup()
