extends TestCase
## «Botón de caída» (etapa 5): el boton solo se aprieta con un golpe real de la pelota, la trampilla se abre y el rival
## cae, los turnos alternan y el partido siempre termina (sin bucles), la IA juega con la misma fisica y cada uno de los
## 8 niveles tiene solucion (se busca con la fisica real, no con una formula).

func _game(level: int) -> BotonCaida:
	var d: Dictionary = MinigameCatalog.level("boton_caida", level)
	d["seed"] = 1234
	d["practice"] = true
	Minigame.next_def = d
	var g: BotonCaida = (load(BotonCaida.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	return g

## Intencion de la IA como en el partido: si espera su momento, pasan los pasos (con el mismo tope que el juego).
func _cpu_now(g: BotonCaida) -> Dictionary:
	g.cpu_force = false
	var n: int = 0
	var it: Dictionary = g._cpu_intent()
	while it.is_empty():
		await tree.physics_frame
		n += 1
		g.cpu_force = n >= int(Minigame.CPU_MAX_WAIT * 60.0)
		it = g._cpu_intent()
	return it

func _wait_flight(g: Minigame, limit: int = 600) -> String:
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < limit:
		await tree.physics_frame
		n += 1
	return g.last_result

func test_catalog_has_the_game_and_8_levels() -> void:
	var ls: Array = MinigameCatalog.levels("boton_caida")
	check(ls.size() == 8, "8 niveles (%d)" % ls.size())
	var ids := {}
	for l in ls:
		ids[l["id"]] = true
		check(String(l["objective"]) != "", "%s: objetivo breve antes de jugar" % l["id"])
		check((l["medals"] as Array).size() == 3, "%s: bronce, plata y oro" % l["id"])
	check(ids.size() == 8, "ids unicos")
	check(MinigameCatalog.is_unlocked(ls[0]), "el primer nivel esta abierto")

func test_button_needs_a_real_hit() -> void:
	var g: BotonCaida = await _game(1)
	# Con las pausas normales: se ve la caida antes del turno siguiente.
	g.fast = false
	var target: Vector3 = g.button_center(1)
	# Golpe fuerte y directo (resuelto con la fisica del juego, sin error).
	var it: Dictionary = g.cpu_shot(target, 20.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	var r: String = await _wait_flight(g)
	note("golpe directo a 20 m/s: %s (mas cerca %.2f m)" % [r, g.closest[0]])
	check(r == "boton" and g.pressed == 1, "un golpe fuerte aprieta el boton rival")
	check(g.fallen[1], "se abre su piso y cae")
	await physics_frames(70)
	check(g.shooters[1].actor.ground_y < -3.0, "el rival cae por la trampilla (%.1f m)" % g.shooters[1].actor.ground_y)
	check(g.points[0] == 1, "punto para el que pateo")
	# Pelota que llega despacio contra el boton: lo toca pero no lo aprieta.
	g.fast = true
	g._after_resolve()
	g.side = Minigame.Side.USER
	g._start_turn()
	await physics_frames(2)
	g.state = Minigame.State.RUNUP
	g.ball.reset_at(target + g.button_normal(1) * 0.6)
	await physics_frames(2)
	g.ball.kick(-g.button_normal(1) * 1.2, Vector3.ZERO, null)
	g._on_contact({})
	var r2: String = await _wait_flight(g)
	note("pelota lenta contra el boton: %s, toque flojo %s" % [r2, str(g.weak_touch)])
	check(g.pressed < 0 and not g.fallen[1], "un toque flojo no lo aprieta")
	check(g.weak_touch, "se registra el toque sin fuerza (para avisarlo)")
	cleanup()

## Partido completo en modo rapido: la IA juega contra un usuario que patea con la misma IA; los turnos alternan y el
## partido termina con ganador y sin trabas.
func test_turns_alternate_and_the_match_always_ends() -> void:
	var g: BotonCaida = await _game(1)
	g.start_match()
	var sides: Array = []
	g.turn_started.connect(func(s: int) -> void: sides.append(s))
	var n: int = 0
	while g.state != Minigame.State.OVER and n < 60 * 120:
		if g.state == Minigame.State.AIM and g.side == Minigame.Side.USER:
			var it: Dictionary = g.cpu_shot(g.button_center(1), 19.0, 0.0, 1.6)
			it["side"] = Minigame.Side.USER
			g.apply_intent(it)
		await tree.physics_frame
		n += 1
	note("partido: %d turnos, puntos %s, ganador %d, orden %s" % [g.turn_n, str(g.points), g.winner, str(sides.slice(0, 8))])
	check(g.state == Minigame.State.OVER, "el partido termina")
	check(g.winner >= 0 and maxi(g.points[0], g.points[1]) >= 2, "con ganador por caidas")
	var alternate: bool = true
	for i in range(1, sides.size()):
		alternate = alternate and sides[i] != sides[i - 1]
	check(alternate, "los turnos alternan")
	check(g.intents.size() == g.shots[0] + g.shots[1], "cada tiro es una intencion registrada (lista para repetir o jugar en linea)")
	cleanup()

## Cada nivel tiene al menos un tiro que aprieta el boton rival con la fisica real (busqueda en una grilla de puntos y
## velocidades, sin error). Anota el tiro encontrado.
func test_every_level_has_a_solution() -> void:
	for lv in range(1, 9):
		var g: BotonCaida = await _game(lv)
		var found: String = ""
		var tries: int = 0
		var b: Vector3 = g.button_center(1)
		var floor_b: bool = String(g.buttons[1]["kind"]) == "floor"
		var speeds: Array = [12.0, 14.0, 16.0, 18.0, 21.0, 24.0]
		var lifts: Array = [0.0, 0.6, 1.2, 2.0, 3.0, 4.0] if floor_b else [0.0, 0.3, 0.8, 1.5, 2.5]
		for sp in speeds:
			for up in lifts:
				for dz in [0.0, -0.3, 0.3]:
					if found != "":
						break
					tries += 1
					g._restore_mechanisms()
					g.side = Minigame.Side.USER
					g.state = Minigame.State.AIM
					var aim: Vector3 = b + Vector3(0.0, up, dz)
					if floor_b:
						aim = b + Vector3(1.2, up, dz)
					var it: Dictionary = g.cpu_shot(aim, sp, 0.0, 0.0)
					await g.launch(it["v"], it["w"])
					var r: String = await _wait_flight(g)
					if r == "boton" and g.pressed == 1:
						var loc: Vector3 = g.frames[1].affine_inverse() * aim
						found = "apuntando a (%.2f, %.2f, %.2f) local, %.0f m/s" % [loc.x, loc.y, loc.z, sp]
					g.state = Minigame.State.AIM
		note("nivel %d (%s): %s en %d intentos" % [lv, g.def["title"], found if found != "" else "SIN SOLUCION", tries])
		check(found != "", "nivel %d tiene solucion" % lv)
		cleanup()

## La IA (sin error, para medir su estrategia) aprieta el boton del usuario en cada nivel en pocos intentos: apunta al
## boton o al truco del nivel, adelanta el boton que se mueve y corrige con lo que ve de su fallo anterior.
func test_cpu_can_press_the_user_button_on_every_level() -> void:
	for lv in range(1, 9):
		var g: BotonCaida = await _game(lv)
		g.cpu_error_deg = 0.0
		var hit_at: int = -1
		for t in 6:
			g._restore_mechanisms()
			g.side = Minigame.Side.CPU
			g.state = Minigame.State.AIM
			g._cross = Vector3.INF
			var it: Dictionary = await _cpu_now(g)
			await g.launch(it["v"], it["w"])
			var r: String = await _wait_flight(g)
			g._on_resolved(Minigame.Side.CPU, r)
			if r == "boton" and g.pressed == 0:
				hit_at = t + 1
				break
		note("nivel %d (%s): la CPU aprieta el boton en el intento %d" % [lv, g.def["title"], hit_at])
		check(hit_at > 0 and hit_at <= 4, "nivel %d: la CPU puede ganar con las mismas reglas" % lv)
		cleanup()

## Balance de la IA (se anota, no se exige un numero): de 12 tiros en el nivel 1 y en el 5 (boton chico), cuantos aprieta
## en cada dificultad, aprendiendo de sus fallos como en un partido.
func test_cpu_balance_by_difficulty() -> void:
	var keep: int = SpSettings.override_difficulty
	for lv in [1, 4, 5, 7]:
		var rates: Array = []
		for dif in [0, 1, 2]:
			SpSettings.override_difficulty = dif
			var g: BotonCaida = await _game(lv)
			var hits: int = 0
			for t in 12:
				g._restore_mechanisms()
				g.side = Minigame.Side.CPU
				g.state = Minigame.State.AIM
				g._cross = Vector3.INF
				var it: Dictionary = await _cpu_now(g)
				await g.launch(it["v"], it["w"])
				var r: String = await _wait_flight(g)
				g._on_resolved(Minigame.Side.CPU, r)
				if r == "boton" and g.pressed == 0:
					hits += 1
			rates.append("%s %d/12" % [SpSettings.ALL_DIFFICULTY_NAMES[dif], hits])
			cleanup()
		note("nivel %d: la CPU aprieta el boton %s" % [lv, ", ".join(rates)])
	SpSettings.override_difficulty = keep
	check(true, "medicion anotada")
