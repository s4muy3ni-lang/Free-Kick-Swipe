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
		check(g.rolls[0] == [10] and g.total_score(0) == 0, "strike: el cuadro espera sus dos bolas de bonus (sin puntos todavia)")
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
		note("segundo tiro: %d en total, bolas %s, puntos %d" % [g.down_count(), str(g.rolls[0]), g.total_score(0)])
		check((g.rolls[0] as Array).size() == 2 and int(g.rolls[0][0]) + int(g.rolls[0][1]) == g.down_count(), "las dos bolas registran lo que tiraron")
	cleanup()

func test_official_ten_frame_scoring() -> void:
	var perfect: Array = []
	for k in 12:
		perfect.append(10)
	check(Bowling.frame_scores(perfect)[9] == 300, "partida perfecta: 300")
	var spares: Array = []
	for k in 21:
		spares.append(5)
	check(Bowling.frame_scores(spares)[9] == 150, "todo 5 y spare (y 5 extra): 150")
	var zeros: Array = []
	for k in 20:
		zeros.append(0)
	check(Bowling.frame_scores(zeros)[9] == 0, "todo canaleta: 0")
	# Ejemplo clasico: X, 7/, 9-, X, -8, 8/, -6, X, X, X81 = 167.
	var game: Array = [10, 7, 3, 9, 0, 10, 0, 8, 8, 2, 0, 6, 10, 10, 10, 8, 1]
	var sc: Array = Bowling.frame_scores(game)
	note("ejemplo: %s" % str(sc))
	check(sc == [20, 39, 48, 66, 74, 84, 90, 120, 148, 167], "ejemplo clasico: 167 cuadro a cuadro")
	check(Bowling.frame_scores([10, 10])[0] == -1, "un strike sin sus dos bolas queda pendiente")
	check(Bowling.frame_marks([10, 10, 10], true) == "X X X" and Bowling.frame_marks([7, 3], false) == "7 /" and Bowling.frame_marks([9, 0], false) == "9 -", "marcas X, / y -")

func test_bowling_match_vs_ai_ends() -> void:
	var g: Bowling = await _bowl()
	var n: int = 0
	while g.state != Minigame.State.OVER and n < 60 * 900:
		if g.state == Minigame.State.AIM and g.side == Minigame.Side.USER:
			var it: Dictionary = g._cpu_intent()
			it["side"] = Minigame.Side.USER
			g.apply_intent(it)
		await tree.physics_frame
		n += 1
	note("bowling 10 cuadros: %d - %d (strikes %d/%d, spares %d/%d) en %.0f s; bolas %s" % [g.total_score(0), g.total_score(1), g.strikes[0], g.strikes[1], g.spares[0], g.spares[1], n / 60.0, str(g.rolls[0])])
	check(Bowling.frame_scores(g.rolls[0])[9] == g.total_score(0) and g.total_score(0) >= 0, "el total sale de los 10 cuadros")
	check(g.state == Minigame.State.OVER, "el partido termina")
	check(g.frames_done[0] == g.frames_total and g.frames_done[1] == g.frames_total, "los dos jugaron todos los cuadros")
	cleanup()

## Cada nivel de Rebotes tiene alguna solucion con la fisica real (busqueda en grilla de puntos de apuntado y velocidades,
## sin pistas por nivel). Se anota el tiro encontrado.
## Por turnos, en escena solo el que patea (relevo): el que espera sale y su cuerpo no choca con la pelota.
func test_only_the_shooter_is_on_stage() -> void:
	var g: Bowling = await _bowl()
	check(g.shooters[0].actor.visible and not g.shooters[1].actor.visible, "turno del usuario: la CPU no esta en escena")
	g.side = Minigame.Side.CPU
	g.frame_owner = Minigame.Side.CPU
	g._start_turn()
	await physics_frames(2)
	check(g.shooters[1].actor.visible and not g.shooters[0].actor.visible, "turno de la CPU: el usuario sale de escena")
	var col: AnimatableBody3D = g.shooters[0].actor.collider
	check(col == null or col.collision_layer == 0, "y su cuerpo no choca con la pelota")
	cleanup()
