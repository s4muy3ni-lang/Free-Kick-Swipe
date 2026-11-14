extends TestCase
## Rescate a pelotazos (pedido del usuario, 2026-11-14: «todo debe ser activado con el balón… la bola que liberó debe
## caer y desplazarse a la zona verde… girar el escenario: el jugador y el balón quedan fijos… palancas, botones, meter
## el balón en un hoyo, impactar»). Para cada nivel de mecanismos, con la fisica del juego:
##  - sin patear, la dorada no sale;
##  - la solucion del nivel (giro del escenario y tiro real con ShotSolver a cada blanco) la libera y la dorada RUEDA
##    sola hasta la zona verde, sin saltos (nunca se la teletransporta);
##  - el orden equivocado falla (pozo o secuencia apagada);
##  - los mandos no responden a toques en la pantalla, solo a la pelota;
##  - girar el escenario gira todo el nivel y deja quietos al jugador y a su pelota.

func _levels() -> Array:
	var out: Array = []
	for d in MinigameCatalog.levels("rescate"):
		if (d as Dictionary).has("mechs"):
			out.append(int(d["level"]))
	return out

func _game(n: int) -> Rescate:
	var d: Dictionary = MinigameCatalog.level("rescate", n)
	d["seed"] = 3
	d["practice"] = true
	Minigame.next_def = d
	var g: Rescate = (load(Rescate.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(20)
	return g

## Un tiro de la solucion: gira el escenario, apunta al blanco y patea con la fisica del juego; espera que se resuelva.
## Devuelve el mayor salto de la dorada en un cuadro mientras vuela la pelota (m).
func _shot(g: Rescate, st: Dictionary) -> float:
	await g.rotate_to(int(st.get("rot", 0)))
	await physics_frames(3)
	var target: Vector3
	if st.has("hit"):
		target = g.mechs.aim_of(int(st["hit"]))
	elif st.has("push"):
		target = g.crates[int(st["push"])].global_position + Vector3(0, -0.05, 0)
	elif st.has("domino"):
		target = g.dominoes[int(st["domino"])].global_position + Vector3(0, -0.1, 0)
	var it: Dictionary = g.cpu_shot(target, float(st.get("speed", 16.0)), 0.0, 0.0)
	var last: Vector3 = g.prisoner.global_position
	var falls: int = g.falls
	var jump: float = 0.0
	await g.launch(it["v"], it["w"])
	var n: int = 0
	while g.state in [Minigame.State.RUNUP, Minigame.State.FLIGHT] and n < 60 * 14:
		await tree.physics_frame
		n += 1
		if g.falls == falls:
			jump = maxf(jump, g.prisoner.global_position.distance_to(last))
		falls = g.falls
		last = g.prisoner.global_position
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
	await physics_frames(3)
	return jump

func _settle(g: Rescate, secs: float) -> float:
	var last: Vector3 = g.prisoner.global_position
	var jump: float = 0.0
	var n: int = 0
	while not g.rescued and n < int(secs * 60.0):
		await tree.physics_frame
		n += 1
		jump = maxf(jump, g.prisoner.global_position.distance_to(last))
		last = g.prisoner.global_position
	return jump

func test_levels_from_easy_to_expert_with_ball_mechanisms() -> void:
	var lv: Array = _levels()
	note("niveles de mecanismos: %s" % str(lv))
	check(lv.size() >= 10, "al menos 10 niveles de mecanismos (%d)" % lv.size())
	check(MinigameCatalog.levels("rescate").size() >= 14, "se conservan los 4 niveles de patear de antes")
	var kinds := {}
	var steps: Array = []
	for n in lv:
		var d: Dictionary = MinigameCatalog.level("rescate", n)
		for m in d["mechs"]:
			kinds[String(m["type"])] = true
		for p in d.get("parts", []):
			kinds["pieza " + String(p["type"])] = true
		if d.has("crates"):
			kinds["caja"] = true
		if d.has("dominoes"):
			kinds["domino"] = true
		var sol: Array = d.get("solution", [])
		check(not sol.is_empty() and int(d.get("shots", 0)) >= sol.size(), "nivel %d: solucion con tiros suficientes" % n)
		steps.append(sol.size())
		for s in sol:
			check((s as Dictionary).has("hit") or (s as Dictionary).has("push") or (s as Dictionary).has("domino"), "nivel %d: cada paso es un tiro" % n)
	note("tiros de cada solucion: %s · mandos: %s" % [str(steps), str(kinds.keys())])
	for k in ["lever", "button", "hole", "switch", "lock", "wheel", "weight", "plate", "caja", "domino", "pieza slide", "pieza hinge", "pieza rotor"]:
		check(kinds.has(k), "hay %s" % k)
	check(int(steps.max()) >= 4, "hay niveles de varios pasos (hasta %d tiros)" % int(steps.max()))

func test_nothing_happens_without_the_ball() -> void:
	for n in _levels():
		var g: Rescate = await _game(n)
		var home: Vector3 = g.prisoner.global_position
		# Toques sobre la pantalla en cada mando: ya no activan nada (solo la pelota).
		for m in g.mechs.mechs:
			var px: Vector2 = g.cam.unproject_position((m["root"] as Node3D).global_position + Vector3.UP * 0.5)
			g._on_press(px, true)
			g._on_press(px, false)
		await _settle(g, 5.0)
		var any: bool = false
		for m in g.mechs.mechs:
			any = any or g.mechs.active(m)
		check(not g.rescued and g.falls == 0 and g.prisoner.global_position.distance_to(home) < 0.6 and not any,
			"nivel %d: sin pelotazos la dorada no sale y ningun mando se activa con toques" % n)
		cleanup()

func test_every_level_is_solved_with_real_shots_and_the_ball_rolls_to_the_zone() -> void:
	var times := {}
	for n in _levels():
		var g: Rescate = await _game(n)
		var d: Dictionary = g.def
		var jump: float = 0.0
		for st in d["solution"]:
			jump = maxf(jump, await _shot(g, st))
			if g.rescued:
				break
		jump = maxf(jump, await _settle(g, 14.0))
		var st2: Dictionary = g.stats()
		var lp: Vector3 = g.prisoner_local()
		note("nivel %d (%s): %s · %d tiros · %.1f s · errores %d · caidas %d · puntaje %d · mayor salto %.2f m" % [n, d["title"],
			"RESCATADA" if g.rescued else "ATRAPADA en %s" % str(lp), int(st2["shots"]), float(st2["time"]), int(st2["errors"]),
			int(st2["falls"]), g.final_score(), jump])
		check(g.rescued, "nivel %d: los tiros de la solucion la liberan y llega rodando a la zona verde" % n)
		check(int(st2["falls"]) == 0 and int(st2["errors"]) == 0, "nivel %d: sin caidas ni errores" % n)
		check(jump < 0.4, "nivel %d: la dorada se mueve con la fisica, sin saltos (%.2f m por cuadro)" % [n, jump])
		check(g.final_score() >= int((d["medals"] as Array)[0]), "nivel %d: resolviendolo se llega al bronce (%d)" % [n, g.final_score()])
		times[n] = float(st2["time"])
		cleanup()
	note("tiempos de la solucion (para min_time): %s" % str(times))

func test_the_wrong_order_fails() -> void:
	for n in _levels():
		var d0: Dictionary = MinigameCatalog.level("rescate", n)
		if not d0.has("wrong"):
			continue
		var g: Rescate = await _game(n)
		for st in d0["wrong"]:
			await _shot(g, st)
		await _settle(g, 8.0)
		note("nivel %d mal resuelto: rescatada %s · caidas %d · errores %d" % [n, str(g.rescued), g.falls, g.mechs.errors])
		check(not g.rescued and (g.falls > 0 or g.mechs.errors > 0), "nivel %d: el orden equivocado falla (pozo o secuencia)" % n)
		cleanup()

func test_rotating_the_stage_turns_the_level_but_not_the_player() -> void:
	var n: int = _levels()[1]
	var g: Rescate = await _game(n)
	var spot: Vector3 = g.ball.global_position
	var p0: Vector3 = g.prisoner.global_position
	var m0: Vector3 = (g.mechs.mechs[0]["root"] as Node3D).global_position
	check(g.can_rotate(), "apuntando y con todo quieto se puede girar")
	check(g.rotate_stage(1), "«Girar» empieza el giro")
	check(not g.rotate_stage(1), "no se encadena otro giro mientras gira")
	await physics_frames(40)
	var p1: Vector3 = g.prisoner.global_position
	var m1: Vector3 = (g.mechs.mechs[0]["root"] as Node3D).global_position
	var piv: Vector3 = g.pivot
	var ang: float = rad_to_deg(Vector2(m0.x - piv.x, m0.z - piv.z).angle_to(Vector2(m1.x - piv.x, m1.z - piv.z)))
	note("giro de un paso: el mando paso de %s a %s (%.1f grados alrededor del centro)" % [str(m0), str(m1), ang])
	check(absf(absf(ang) - Rescate.ROT_STEP) < 2.0, "el escenario gira 45 grados alrededor de su centro")
	check(p1.distance_to(p0) < 1.5 and absf(Vector2(p1.x - piv.x, p1.z - piv.z).length() - Vector2(p0.x - piv.x, p0.z - piv.z).length()) < 0.05,
		"la dorada gira con su jaula (misma distancia al centro)")
	check(g.ball.global_position.distance_to(spot) < 0.01, "la pelota del jugador no se mueve")
	check(not g.prisoner.freeze, "terminado el giro, la dorada vuelve a la fisica")
	g._on_action(&"rot_r")
	await physics_frames(40)
	check(g.rot_k == 0 and (g.mechs.mechs[0]["root"] as Node3D).global_position.distance_to(m0) < 0.02, "y se vuelve al lugar")
	cleanup()

func test_sequence_errors_and_new_attempts_are_counted() -> void:
	var lv: int = -1
	for n in _levels():
		for m in MinigameCatalog.level("rescate", n)["mechs"]:
			if String(m["type"]) == "lock" and lv < 0:
				lv = n
	var g: Rescate = await _game(lv)
	var d: Dictionary = g.def
	await _shot(g, d["wrong"][0])
	check(g.mechs.errors == 1, "un blanco fuera de orden cuenta un error y apaga la secuencia")
	g._on_action(&"restart")
	check(g.attempts == 2, "«Reiniciar» en un nivel de mecanismos es otro intento (el reloj sigue)")
	cleanup()
