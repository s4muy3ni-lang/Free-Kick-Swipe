extends TestCase
## «Salto de esquí»: la pelota baja por la pista de nieve por gravedad, sale de la mesa y vuela; la distancia se mide
## del borde al primer apoyo; patear fuerte la despega y pierde velocidad; cada nivel llega al bronce.

func _game(level: int) -> SaltoEsqui:
	var d: Dictionary = MinigameCatalog.level("salto_esqui", level)
	d["seed"] = 2
	d["practice"] = true
	Minigame.next_def = d
	var g: SaltoEsqui = (load(SaltoEsqui.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(10)
	return g

func _jump(g: SaltoEsqui, speed: float) -> String:
	var v := Vector3(speed, 0, 0)
	await g.launch(v, g.ball.rolling_spin(v))
	var n: int = 0
	var vmax: float = 0.0
	while g.state == Minigame.State.FLIGHT and n < 60 * 30:
		await tree.physics_frame
		n += 1
		if g.ball.global_position.x <= g.takeoff.x:
			vmax = maxf(vmax, g.ball.linear_velocity.length())
	var r: String = g.last_result
	note("salida a %.0f m/s: %s, velocidad en la mesa %.1f m/s, %.1f m" % [speed, r, vmax, g.distance])
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
		await physics_frames(2)
	return r

func test_ramp_flight_and_distance() -> void:
	var g: SaltoEsqui = await _game(2)
	var r: String = await _jump(g, 2.0)
	var d1: float = float(g.jumps.back())
	check(r == "salto" and d1 > 15.0, "baja por la nieve, sale de la mesa y vuela (%.1f m)" % d1)
	r = await _jump(g, 7.0)
	var d2: float = float(g.jumps.back())
	# Patear fuerte la despega de la plataforma: rebota contra la pista y pierde velocidad (la habilidad es salir suave).
	check(d1 > d2, "una salida suave pegada a la nieve llega mas lejos que una patada que rebota (%.1f > %.1f)" % [d1, d2])
	cleanup()

func test_every_level_reaches_bronze() -> void:
	for lv in range(1, MinigameCatalog.levels("salto_esqui").size() + 1):
		var g: SaltoEsqui = await _game(lv)
		while g.state != Minigame.State.OVER:
			await _jump(g, 2.0)
		note("esqui %d (%s): mejor %.1f m (K %d), puntaje %d (medallas %s)" % [lv, g.def["title"], g.best(), int(g.k_point), g.final_score(), str(g.def["medals"])])
		check(g.final_score() >= int(g.def["medals"][0]), "nivel %d: llega al bronce" % lv)
		cleanup()
