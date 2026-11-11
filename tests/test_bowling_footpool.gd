extends TestCase
## Bowling y FootPool (etapa C): los bolos caen SOLO por la fuerza recibida, el cuadro tiene dos tiros (se retiran los
## caidos), strike y spare pagan bonus y el partido contra la IA termina. En FootPool las pelotas solo se mueven por
## colisiones, meter la propia da turno extra, la del rival regala puntos, la blanca se repone y la IA emboca con
## geometria (punto fantasma).

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

func _pool(level: int = 1) -> FootPool:
	var d: Dictionary = MinigameCatalog.level("footpool", level)
	d["seed"] = 11
	d["practice"] = true
	Minigame.next_def = d
	var g: FootPool = (load(FootPool.SCENE) as PackedScene).instantiate()
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

func test_footpool_rules_and_ai_geometry() -> void:
	var g: FootPool = await _pool()
	await physics_frames(100)
	var moved: float = 0.0
	for e in g.balls:
		moved = maxf(moved, (e["body"] as RigidBody3D).global_position.distance_to((e["home"] as Transform3D).origin))
	check(moved < 0.05, "ninguna pelota se mueve sin recibir un impulso (%.3f m)" % moved)
	# Tiro directo del usuario a su azul mas cercana a la boca derecha (geometria de punto fantasma, como la IA).
	var own: Vector3 = Vector3.ZERO
	for e in g.balls:
		if int(e["team"]) == 0 and (e["body"] as RigidBody3D).global_position.x < 0:
			own = (e["body"] as RigidBody3D).global_position
			break
	var mouth := Vector3(-(g.court_l * 0.5 + 0.3), 0, 0)
	var ghost: Vector3 = own - (mouth - own).normalized() * 0.22
	var vw: Array = g.pool_velocity(Vector3(ghost.x, 0, ghost.z), 0.55)
	await g.launch(vw[0], vw[1])
	await _fly(g)
	note("tiro fantasma: metidas %d, carambolas %d, turno extra %s, puntos %d" % [g.potted_this_shot.size(), g.caroms_this_shot, str(g.extra_turn), g.points[0]])
	if g.remaining(0) < 3:
		check(g.points[0] >= FootPool.POT_POINTS, "propia embocada: +100")
		check(g.extra_turn and g.side == Minigame.Side.USER, "y turno extra")
	cleanup()

func test_footpool_match_vs_ai_ends_with_potted_balls() -> void:
	var g: FootPool = await _pool()
	var n: int = 0
	while g.state != Minigame.State.OVER and n < 60 * 400:
		if g.state == Minigame.State.AIM and g.side == Minigame.Side.USER:
			# El usuario juega con la misma planificacion geometrica de la IA (sobre SUS azules).
			var it: Dictionary = g._cpu_intent_for(0)
			it["side"] = Minigame.Side.USER
			g.apply_intent(it)
		await tree.physics_frame
		n += 1
	note("footpool: %d - %d; quedan %d azules y %d rojas; %.0f s" % [g.points[0], g.points[1], g.remaining(0), g.remaining(1), n / 60.0])
	check(g.state == Minigame.State.OVER, "la partida termina")
	check(g.remaining(0) == 0 or g.remaining(1) == 0 or g.turn_n >= g.max_turns, "alguien embocó todas (o se agotaron los turnos)")
	check(g.points[0] + g.points[1] > 0, "hubo pelotas embocadas de verdad")
	cleanup()

func test_rebotes_levels_cannot_be_hit_head_on_but_have_a_bounce_solution() -> void:
	for lv in [1, 3]:
		var d: Dictionary = MinigameCatalog.level("rebotes", lv)
		d["seed"] = 11
		d["practice"] = true
		Minigame.next_def = d
		var g: Rebotes = (load(Rebotes.RSCENE) as PackedScene).instantiate()
		g.fast = true
		spawn(g)
		await physics_frames(5)
		g.start_match()
		await physics_frames(5)
		# Tiro directo al objetivo: la pared lo tapa.
		var target: Vector3 = (g.blocks[0] as RigidBody3D).global_position
		var it: Dictionary = g.cpu_shot(target, 18.0, 0.0, 0.0)
		await g.launch(it["v"], it["w"])
		await _fly(g)
		note("nivel %d directo: caidos %d (rebotes %d)" % [lv, g.count("target", true), g.wall_bounces])
		check(g.count("target", true) == 0, "nivel %d: el tiro directo no llega (esta escondido)" % lv)
		# Solucion con rebote (buscada con la fisica real).
		var found: bool = false
		var tries: int = 0
		for dz in [-8.0, -7.4, -8.6, -6.8]:
			for sp in [14.0, 17.0, 20.0, 23.0]:
				if found:
					break
				tries += 1
				g.start_match()
				await physics_frames(5)
				var v: Vector3
				var w := Vector3.ZERO
				if lv == 1:
					# Banda: apunta al punto ESPEJO del objetivo detras de la pared lateral (z = -4).
					v = g.cpu_shot(Vector3(target.x, 0.35, dz), sp, 0.0, 0.0)["v"]
				else:
					# Ranura: raso y derecho (casi sin elevacion), con giro de rodadura.
					v = Vector3(sp, 0.6, 0.0)
					w = g.ball.rolling_spin(v)
				await g.launch(v, w)
				await _fly(g)
				found = g.count("target", true) > 0
		note("nivel %d: %s en %d intentos" % [lv, "resuelto con rebote" if found else "SIN SOLUCION", tries])
		check(found, "nivel %d tiene solucion indirecta" % lv)
		cleanup()

## Cada nivel de Rebotes tiene alguna solucion con la fisica real (busqueda en grilla de puntos de apuntado y velocidades,
## sin pistas por nivel). Se anota el tiro encontrado.
func test_every_rebotes_level_is_solvable() -> void:
	for lv in range(1, MinigameCatalog.levels("rebotes").size() + 1):
		var d: Dictionary = MinigameCatalog.level("rebotes", lv)
		d["seed"] = 11
		d["practice"] = true
		Minigame.next_def = d
		var g: Rebotes = (load(Rebotes.RSCENE) as PackedScene).instantiate()
		g.fast = true
		spawn(g)
		await physics_frames(5)
		var target: Vector3 = (g.blocks[0] as RigidBody3D).global_position
		var found: String = ""
		var tries: int = 0
		for ax in [target.x, target.x - 4.0, target.x + 3.0, target.x * 0.6]:
			for az in [target.z, -8.0, -5.0, -3.0, 3.0, 5.0, 8.0]:
				for ay in [0.35, 1.5, 3.5]:
					for sp in [13.0, 17.0, 21.0]:
						if found != "":
							break
						tries += 1
						g.start_match()
						await physics_frames(3)
						var it: Dictionary = g.cpu_shot(Vector3(ax, ay, az), sp, 0.0, 0.0)
						await g.launch(it["v"], it["w"])
						await _fly(g)
						if g.count("target", true) > 0:
							found = "apuntando (%.1f, %.1f, %.1f) a %.0f m/s, %d rebotes" % [ax, ay, az, sp, g.wall_bounces]
		note("rebotes %d (%s): %s en %d intentos" % [lv, g.def["title"], found if found != "" else "SIN SOLUCION", tries])
		check(found != "", "rebotes %d tiene solucion" % lv)
		cleanup()
