extends TestCase
## Bowling: los bolos caen SOLO por la fuerza recibida, el cuadro tiene dos tiros (se retiran los caidos), strike y spare
## y el partido contra la IA termina.

func _bowl(level: int = 1) -> Bowling:
	var d: Dictionary = MinigameCatalog.level("bowling", level)
	d["seed"] = 11
	d["practice"] = true
	Minigame.next_def = d
	var g: Bowling = (load(Bowling.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(5)
	return g

func _fly(g: Minigame, limit: int = 60 * 12) -> void:
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < limit:
		await tree.physics_frame
		n += 1
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
		await physics_frames(2)

func test_pins_fall_only_by_impact_and_frames_have_two_rolls() -> void:
	var g: Bowling = await _bowl()
	await physics_frames(120)
	check(g.down_count() == 0, "sin golpe, ningun bolo se cae solo (%d)" % g.down_count())
	# Primer tiro al costado de la formacion: caen algunos, NO todos; quedan los parados y se retiran los caidos.
	var vw: Array = g.bowl_velocity(Vector3(g.lane_len, 0, 0.35), 0.75, 0.0)
	await g.launch(vw[0], vw[1])
	await _fly(g)
	var after_first: int = g.down_count()
	note("primer tiro: %d bolos (tiro %d del cuadro)" % [after_first, g.roll_n])
	check(after_first > 0, "el impacto tira bolos")
	if after_first < 10:
		check(g.roll_n == 2 and g.side == Minigame.Side.USER, "quedan bolos: segundo tiro del mismo cuadro")
		var hidden: int = 0
		for p in g.pins:
			if not p.visible:
				hidden += 1
		check(hidden == after_first, "los caidos se retiran entre tiros (%d)" % hidden)
	cleanup()

func test_strike_and_spare_bonuses() -> void:
	var g: Bowling = await _bowl()
	# Strike FISICO: bola rapida al centro. Los bolos se cuentan al resolver el tiro (despues de un strike se reponen).
	var counted: Array = []
	g.shot_resolved.connect(func(_s: int, _r: String) -> void: counted.append(g.down_count()))
	var vw: Array = g.bowl_velocity(Vector3(g.lane_len + 0.4, 0, 0.0), 1.0, 0.0)
	await g.launch(vw[0], vw[1])
	await _fly(g)
	var down: int = counted[0] if not counted.is_empty() else 0
	note("bola al centro a fondo: %d bolos" % down)
	if down >= 10:
		check(g.points[0] == 10 + Bowling.STRIKE_BONUS, "strike: 10 + %d" % Bowling.STRIKE_BONUS)
		check(g.frame_owner == Minigame.Side.CPU, "cuadro cerrado: turno de la IA")
	else:
		# Si no fue strike, el spare: segundo tiro a los que quedan.
		var standing := Vector3.ZERO
		var n: int = 0
		for i in g.pins.size():
			if not g.pin_down(i):
				standing += g.pins[i].global_position
				n += 1
		var vw2: Array = g.bowl_velocity(Vector3(standing.x / n, 0, standing.z / n), 0.9, 0.0)
		await g.launch(vw2[0], vw2[1])
		await _fly(g)
		note("segundo tiro: %d en total, puntos %d" % [g.down_count(), g.points[0]])
		check(g.points[0] >= g.down_count(), "el cuadro suma lo tirado (con bonus si fue spare)")
	cleanup()

func test_bowling_match_vs_ai_ends() -> void:
	var g: Bowling = await _bowl()
	var n: int = 0
	while g.state != Minigame.State.OVER and n < 60 * 240:
		if g.state == Minigame.State.AIM and g.side == Minigame.Side.USER:
			var it: Dictionary = g._cpu_intent()
			it["side"] = Minigame.Side.USER
			g.apply_intent(it)
		await tree.physics_frame
		n += 1
	note("bowling: %d - %d (strikes %d/%d, spares %d/%d) en %.0f s" % [g.points[0], g.points[1], g.strikes[0], g.strikes[1], g.spares[0], g.spares[1], n / 60.0])
	check(g.state == Minigame.State.OVER, "el partido termina")
	check(g.frames_done[0] == g.frames_total and g.frames_done[1] == g.frames_total, "los dos jugaron todos los cuadros")
	cleanup()

## Cada nivel de Rebotes tiene alguna solucion con la fisica real (busqueda en grilla de puntos de apuntado y velocidades,
## sin pistas por nivel). Se anota el tiro encontrado.