extends TestCase
## Rescate rediseñado (pedido del usuario: «un minijuego de ingenio y habilidad, con mecanismos variados y acertijos
## reales… cada nivel debe tener una solucion valida y verificable»). Para cada nivel con mecanismos, con la fisica del
## juego: sin tocar nada la pelota no se libera; la solucion del nivel (toques, mantener apretado, esperas) la lleva a la
## zona sin teletransportarla; el camino equivocado falla (pozo, compuerta cerrada o secuencia apagada); cada mando se
## puede tocar en la pantalla y responde.

func _levels() -> Array:
	var out: Array = []
	var all: Array = MinigameCatalog.levels("rescate")
	for d in all:
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

## Ejecuta los pasos y despues espera hasta `settle` segundos. Devuelve el mayor salto de la pelota en un cuadro (m).
func _run(g: Rescate, steps: Array, settle: float) -> float:
	# Estado mutable en un diccionario: las lambdas de GDScript copian las variables locales.
	var w := {"jump": 0.0, "last": g.prisoner.global_position, "falls": g.falls}
	var watch := func() -> void:
		var p: Vector3 = g.prisoner.global_position
		# Una caida vuelve la pelota al principio (otro intento): ese cuadro no cuenta como salto.
		if g.falls == int(w["falls"]):
			w["jump"] = maxf(float(w["jump"]), p.distance_to(w["last"]))
		w["falls"] = g.falls
		w["last"] = p
	for st in steps:
		var sd: Dictionary = st
		if sd.has("tap"):
			g.mechs.touch(int(sd["tap"]), true)
			await tree.physics_frame
			watch.call()
			g.mechs.touch(int(sd["tap"]), false)
		elif sd.has("hold"):
			g.mechs.touch(int(sd["hold"]), true)
			for i in int(float(sd.get("for", 1.0)) * 60.0):
				await tree.physics_frame
				watch.call()
			g.mechs.touch(int(sd["hold"]), false)
		elif sd.has("wait"):
			for i in int(float(sd["wait"]) * 60.0):
				await tree.physics_frame
				watch.call()
	var n: int = 0
	while not g.rescued and g.state != Minigame.State.OVER and n < int(settle * 60.0):
		await tree.physics_frame
		watch.call()
		n += 1
	return float(w["jump"])

func test_there_are_new_mechanism_levels_from_easy_to_expert() -> void:
	var lv: Array = _levels()
	note("niveles con mecanismos: %s" % str(lv))
	check(lv.size() >= 8, "al menos 8 niveles nuevos con mecanismos (%d)" % lv.size())
	check(MinigameCatalog.levels("rescate").size() >= 12, "se conservan los 4 niveles de antes")
	var kinds := {}
	for n in lv:
		var d: Dictionary = MinigameCatalog.level("rescate", n)
		for m in d["mechs"]:
			kinds[String(m["type"]) + ("/" + String(m["mode"]) if (m as Dictionary).has("mode") else "")] = true
		for p in d.get("parts", []):
			kinds["pieza " + String(p["type"])] = true
		check(d.has("solution") and not (d["solution"] as Array).is_empty(), "nivel %d: trae su solucion" % n)
	note("mecanismos usados: %s" % str(kinds.keys()))
	for k in ["lever", "button/hold", "button/timer", "switch", "lock", "crank", "weight", "pieza slide", "pieza hinge", "pieza rotor"]:
		check(kinds.has(k), "hay %s" % k)

func test_nothing_happens_without_solving() -> void:
	for n in _levels():
		var g: Rescate = await _game(n)
		var home: Vector3 = g.prisoner.global_position
		await _run(g, [], 6.0)
		note("nivel %d sin tocar nada: dorada en %s (salio de %s)" % [n, str(g.prisoner.global_position), str(home)])
		check(not g.rescued and g.falls == 0, "nivel %d: sin tocar nada no se libera ni se cae" % n)
		cleanup()

func test_every_mechanism_level_is_solvable() -> void:
	for n in _levels():
		var g: Rescate = await _game(n)
		var d: Dictionary = g.def
		var jump: float = await _run(g, d["solution"], 20.0)
		var st: Dictionary = g.stats()
		note("nivel %d (%s): %s · %.1f s · acciones %d · errores %d · caidas %d · puntaje %d · mayor salto %.2f m" % [n, d["title"],
			"RESCATADA" if g.rescued else "ATRAPADA en " + str(g.prisoner.global_position), float(st["time"]), int(st["actions"]),
			int(st["errors"]), int(st["falls"]), g.final_score(), jump])
		check(g.rescued, "nivel %d: la solucion la rescata" % n)
		check(int(st["falls"]) == 0 and int(st["errors"]) == 0, "nivel %d: sin caidas ni errores" % n)
		check(jump < 0.4, "nivel %d: la pelota se mueve con la fisica, sin saltos (%.2f m por cuadro)" % [n, jump])
		check(g.final_score() >= int((d["medals"] as Array)[0]), "nivel %d: resolviendolo se llega al bronce (%d)" % [n, g.final_score()])
		check(float(st["time"]) < float(d.get("time", 999.0)), "nivel %d: a tiempo" % n)
		cleanup()

func test_the_wrong_way_fails() -> void:
	for n in _levels():
		var d0: Dictionary = MinigameCatalog.level("rescate", n)
		if not d0.has("wrong"):
			continue
		var g: Rescate = await _game(n)
		await _run(g, d0["wrong"], 14.0)
		note("nivel %d mal resuelto: rescatada %s · caidas %d · errores %d · intentos %d · dorada en %s" % [n, str(g.rescued), g.falls, g.mechs.errors, g.attempts, str(g.prisoner.global_position)])
		check(not g.rescued, "nivel %d: el camino equivocado no la rescata" % n)
		cleanup()

func test_every_mechanism_can_be_touched_on_screen() -> void:
	for n in _levels():
		var g: Rescate = await _game(n)
		var miss: Array = []
		for m in g.mechs.mechs:
			if String(m["type"]) in ["lock", "kick"]:
				continue
			var at: Vector3 = (m["weight"] as Node3D).global_position if m.has("weight") else (m["root"] as Node3D).global_position + Vector3.UP * 0.5
			var px: Vector2 = g.cam.unproject_position(at)
			if g.pick_mech(px) != int(m["i"]):
				miss.append("%s %d" % [m["type"], int(m["i"])])
		check(miss.is_empty(), "nivel %d: cada mando se toca en la pantalla (%s)" % [n, str(miss)])
		cleanup()

func test_sequence_errors_and_new_attempts_are_counted() -> void:
	var lv: int = -1
	for n in _levels():
		for m in MinigameCatalog.level("rescate", n)["mechs"]:
			if String(m["type"]) == "lock":
				lv = n
		if lv > 0:
			break
	var g: Rescate = await _game(lv)
	var d: Dictionary = g.def
	var first: int = int((d["solution"] as Array)[0]["tap"])
	var other: int = -1
	for m in g.mechs.mechs:
		if String(m["type"]) == "switch" and int(m["i"]) != first:
			other = int(m["i"])
			break
	g.mechs.touch(other, true)
	check(g.mechs.errors == 1, "un interruptor fuera de orden cuenta un error")
	g._on_action(&"restart")
	check(g.attempts == 2, "«Reiniciar» en un nivel de mecanismos es otro intento (el reloj sigue)")
	await _run(g, d["solution"], 20.0)
	var st: Dictionary = g.stats()
	check(g.rescued and int(st["errors"]) == 1 and int(st["attempts"]) == 2, "se resuelve igual y quedan el error y los intentos")
	check(g.final_score() < Rescate.score_for(st.merged({"errors": 0}, true)), "el error resta puntos")
	cleanup()
