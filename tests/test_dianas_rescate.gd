extends TestCase
## Dianas colgantes y Rescate (etapa A5): articulaciones y mecanismos con fisica real. Una placa colgada se balancea con
## el golpe (pendulo), un roce no la desprende, las resistentes aguantan 2 golpes y el carrusel las lleva girando. En el
## rescate nada se mueve sin un impacto real: el boton abre la traba, el empujon transfiere impulso y el domino encadena.

func _dianas(level: int) -> Dianas:
	var d: Dictionary = MinigameCatalog.level("dianas", level)
	d["seed"] = 3
	d["practice"] = true
	Minigame.next_def = d
	var g: Dianas = (load(Dianas.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(10)
	return g

func _rescate(level: int) -> Rescate:
	var d: Dictionary = MinigameCatalog.level("rescate", level)
	d["seed"] = 3
	d["practice"] = true
	Minigame.next_def = d
	var g: Rescate = (load(Rescate.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(10)
	return g

func _fly(g: Minigame, limit: int = 60 * 14) -> String:
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < limit:
		await tree.physics_frame
		n += 1
	var r: String = g.last_result
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
		await physics_frames(2)
	return r

func test_plates_swing_and_detach_only_with_strong_hits() -> void:
	var g: Dianas = await _dianas(1)
	var plate: RigidBody3D = g.plates[1]["body"]
	var rest: Vector3 = plate.global_position
	# Un roce (pelota lenta): se mueve apenas y NO se desprende.
	g.state = Minigame.State.FLIGHT
	g.ball.reset_at(rest - Vector3(0.5, 0, 0))
	await physics_frames(2)
	g.ball.kick(Vector3(1.2, 0, 0), Vector3.ZERO, null)
	await physics_frames(50)
	check(not bool(g.plates[1]["detached"]), "un roce no desprende la diana")
	var swung: float = 0.0
	for i in 40:
		await tree.physics_frame
		swung = maxf(swung, plate.global_position.distance_to(rest))
	note("roce: la placa se balanceo hasta %.2f m de su reposo" % swung)
	check(swung > 0.02, "pero la placa se balancea (pendulo fisico)")
	cleanup()
	# Golpe fuerte: se desprende y cae.
	g = await _dianas(1)
	var it: Dictionary = g.cpu_shot((g.plates[1]["body"] as RigidBody3D).global_position, 16.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	await _fly(g)
	check(bool(g.plates[1]["detached"]), "un golpe fuerte la desprende (se quita la articulacion)")
	await physics_frames(60)
	check((g.plates[1]["body"] as RigidBody3D).global_position.y < 0.6, "y cae por gravedad")
	cleanup()

func test_tough_plates_need_two_hits_and_carousel_moves() -> void:
	var g: Dianas = await _dianas(2)
	var tough: Dictionary = g.plates[0]
	var it: Dictionary = g.cpu_shot((tough["body"] as RigidBody3D).global_position, 16.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	await _fly(g)
	check(not bool(tough["detached"]) and int(tough["hits"]) == 1, "la resistente aguanta el primer golpe (le queda 1)")
	cleanup()
	g = await _dianas(3)
	var p0: Vector3 = (g.plates[0]["body"] as RigidBody3D).global_position
	await physics_frames(45)
	var p1: Vector3 = (g.plates[0]["body"] as RigidBody3D).global_position
	note("carrusel: la diana se movio %.2f m en 0,75 s" % p0.distance_to(p1))
	check(p0.distance_to(p1) > 0.3, "el carrusel lleva las dianas colgadas")
	check(not bool(g.plates[0]["detached"]), "sin que se caigan solas")
	cleanup()

func test_every_dianas_level_is_beatable() -> void:
	for lv in range(1, MinigameCatalog.levels("dianas").size() + 1):
		var g: Dianas = await _dianas(lv)
		while g.state != Minigame.State.OVER:
			var target := Vector3.INF
			for e in g.plates:
				if not bool(e["fallen"]) and not bool(e["detached"]):
					target = (e["body"] as RigidBody3D).global_position
					break
			if target == Vector3.INF:
				break
			# Si la placa quedo hamacandose por un golpe anterior, espera a que se calme (como haria una persona).
			if g._carousel == null:
				var calm: int = 0
				var tb: RigidBody3D = null
				for e in g.plates:
					if not bool(e["fallen"]) and not bool(e["detached"]):
						tb = e["body"]
						break
				while tb != null and tb.linear_velocity.length() > 0.5 and calm < 60 * 7:
					await tree.physics_frame
					calm += 1
				if tb != null:
					target = tb.global_position
			if g._carousel != null:
				# Adelanta el giro: donde va a estar la placa cuando llegue la pelota.
				var post := Vector3(float((g.def["carousel"] as Dictionary).get("x", 12.0)), 0, 0)
				var spin: float = float((g.def["carousel"] as Dictionary).get("speed", 0.9))
				var tof: float = g.runup_time + target.distance_to(g._ball_spot(0)) / 14.0
				var rel: Vector3 = Vector3(target.x - post.x, 0, target.z - post.z).rotated(Vector3.UP, spin * tof)
				target = Vector3(post.x + rel.x, target.y, rel.z)
			# Tras el muro: tiro mas lento = arco mas alto (la fisica obliga a pasarla por arriba).
			var it: Dictionary = g.cpu_shot(target, 11.5 if lv == 5 else 16.0, 0.0, 0.0)
			await g.launch(it["v"], it["w"])
			await _fly(g)
			if g.state == Minigame.State.OVER:
				break
		note("dianas %d (%s): %d/%d caidas en %d tiros" % [lv, g.def["title"], g.fallen_count(), g.plates.size(), g.shots[0]])
		check(g.hanging() == 0, "nivel %d: todas las dianas se pueden desprender" % lv)
		cleanup()

func test_rescue_mechanisms_are_physical() -> void:
	var g: Rescate = await _rescate(1)
	# Sin tocar nada, la prisionera se acomoda contra la traba y se queda (no se escapa sola).
	await physics_frames(280)
	var pp: Vector3 = g.prisoner.global_position
	note("en reposo: dorada en %s, v=%.2f" % [str(pp), g.prisoner.linear_velocity.length()])
	check(g.prisoner.linear_velocity.length() < 0.4 and pp.x > 10.3 and pp.y > 1.0, "sin impacto, la dorada queda retenida por la traba")
	# Un toque flojo al boton no lo aprieta.
	g.state = Minigame.State.FLIGHT
	var bpos: Vector3 = (g.buttons[0]["body"] as Node3D).global_position
	g.ball.reset_at(bpos + Vector3(-0.5, 0, 0))
	await physics_frames(2)
	g.ball.kick(Vector3(1.2, 0, 0), Vector3.ZERO, null)
	await physics_frames(50)
	check(g.pressed_count() == 0, "un toque flojo no abre la compuerta")
	cleanup()

func test_every_rescue_level_is_beatable() -> void:
	for lv in range(1, MinigameCatalog.levels("rescate").size() + 1):
		var g: Rescate = await _rescate(lv)
		var mind: float = INF
		for step in g.def.get("solution", []):
			if g.state == Minigame.State.OVER:
				break
			var sd: Dictionary = step
			var at: PackedStringArray = String(sd["at"]).split(":")
			var target: Vector3
			match at[0]:
				"button":
					target = (g.buttons[int(at[1])]["body"] as Node3D).global_position
				"prisoner":
					target = g.prisoner.global_position
				"domino":
					target = (g.dominoes[int(at[1])] as Node3D).global_position + Vector3.UP * 0.25
			var it: Dictionary = g.cpu_shot(target, float(sd.get("speed", 13.0)), 0.0, 0.0)
			await g.launch(it["v"], it["w"])
			var fn: int = 0
			while g.state == Minigame.State.FLIGHT and fn < 60 * 14:
				await tree.physics_frame
				fn += 1
				mind = minf(mind, g.ball.global_position.distance_to(g.prisoner.global_position))
			if g.state == Minigame.State.RESOLVE:
				g._after_resolve()
				await physics_frames(2)
		# La cadena puede seguir despues del tiro (domino lento): espera un poco mas.
		var n: int = 0
		while not g.rescued and g.state != Minigame.State.OVER and n < 60 * 8:
			await tree.physics_frame
			n += 1
		note("rescate %d (%s): %s en %d tiros (dorada en %s; pelota paso a %.2f m)" % [lv, g.def["title"],
			"rescatada" if g.rescued else "ATRAPADA", g.shots[0], str(g.prisoner.global_position), mind])
		check(g.rescued, "nivel %d: la dorada llega a la zona con fisica real" % lv)
		cleanup()
