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
	# (La cara mira al jugador: la pelota sale a 0,22 m de la placa para tocarla antes de caer.)
	g.ball.reset_at(rest - Vector3(0.22, 0, 0))
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

## Punto a apuntar para que la pelota pegue en el punto `face` (x a la derecha, y arriba) de la cara del blanco e: el
## centro de la pelota debe cruzar el plano que esta a th/2 + radio por delante de la cara.
func _face_target(g: Dianas, e: Dictionary, face: Vector2, xf: Transform3D) -> Vector3:
	return xf * Vector3(-float(e["th"]) * 0.5 - g.ball.radius, face.y, face.x)

func test_targets_face_the_shooter() -> void:
	for lv in range(1, MinigameCatalog.levels("dianas").size() + 1):
		var g: Dianas = await _dianas(lv)
		var worst: float = 0.0
		for e in g.plates:
			var xf: Transform3D = (e["body"] as Node3D).global_transform
			var normal: Vector3 = xf.basis * Vector3(-1, 0, 0)
			var to_tee: Vector3 = g._ball_spot(0) - xf.origin
			to_tee.y = 0.0
			worst = maxf(worst, rad_to_deg(Vector3(normal.x, 0, normal.z).angle_to(to_tee)))
		note("dianas %d: la cara de cada blanco se desvia como mucho %.1f grados del punto de tiro" % [lv, worst])
		check(worst < 3.0, "nivel %d: todos los blancos miran al jugador (no de costado)" % lv)
		cleanup()

func test_zone_points_come_from_the_real_impact_point() -> void:
	# Tablero (el ejemplo del pedido: esquinas de arriba 10, centro 5, abajo 1): un tiro a cada zona.
	var expect := [[Vector2(-1.25, 0.75), 10], [Vector2(1.25, 0.75), 10], [Vector2(0.0, 0.05), 5], [Vector2(0.4, -0.75), 1], [Vector2(-0.9, 0.0), 2]]
	var got: Array = []
	for c in expect:
		var g: Dianas = await _dianas(6)
		var e: Dictionary = g.plates[0]
		var it: Dictionary = g.cpu_shot(_face_target(g, e, c[0], (e["body"] as Node3D).global_transform), 17.0, 0.0, 0.0)
		await g.launch(it["v"], it["w"])
		await _fly(g)
		var hit: Vector2 = g.last_hit.get("point", Vector2.INF)
		got.append("%s->%d (impacto %.2f, %.2f)" % [str(c[0]), g.zone_points, hit.x, hit.y])
		check(g.zone_points == int(c[1]), "tablero: tiro a %s suma %d (sumo %d)" % [str(c[0]), int(c[1]), g.zone_points])
		check(hit != Vector2.INF and hit.distance_to(c[0]) < 0.12, "el punto de impacto medido es el apuntado (%.2f m)" % (hit.distance_to(c[0]) if hit != Vector2.INF else 99.0))
		cleanup()
	note("tablero: %s" % str(got))
	# Diana redonda: al centro dorado 10; al borde 1; un tiro que no la toca no suma nada.
	var g2: Dianas = await _dianas(7)
	var e2: Dictionary = g2.plates[0]
	var it2: Dictionary = g2.cpu_shot(_face_target(g2, e2, Vector2.ZERO, (e2["body"] as Node3D).global_transform), 17.0, 0.0, 0.0)
	await g2.launch(it2["v"], it2["w"])
	await _fly(g2)
	check(g2.zone_points == 10, "diana redonda: al centro suma 10 (sumo %d)" % g2.zone_points)
	var r: float = float(e2["r"])
	it2 = g2.cpu_shot(_face_target(g2, e2, Vector2(0, r * 0.9), (e2["body"] as Node3D).global_transform), 17.0, 0.0, 0.0)
	await g2.launch(it2["v"], it2["w"])
	await _fly(g2)
	check(g2.zone_points == 11, "al anillo de afuera suma 1 (total %d)" % g2.zone_points)
	it2 = g2.cpu_shot(_face_target(g2, e2, Vector2(0, r + 0.6), (e2["body"] as Node3D).global_transform), 17.0, 0.0, 0.0)
	await g2.launch(it2["v"], it2["w"])
	await _fly(g2)
	check(g2.zone_points == 11, "un tiro que pasa por arriba no suma (total %d)" % g2.zone_points)
	cleanup()

func test_every_dianas_level_is_beatable() -> void:
	for lv in range(1, MinigameCatalog.levels("dianas").size() + 1):
		var g: Dianas = await _dianas(lv)
		var n: int = 0
		while g.state != Minigame.State.OVER and n < 12:
			n += 1
			var aim := Vector3.INF
			if g.goal == "derribar":
				var tb: RigidBody3D = null
				for e in g.plates:
					if not bool(e["fallen"]) and not bool(e["detached"]):
						tb = e["body"]
						break
				if tb == null:
					break
				# Si la placa quedo hamacandose por un golpe anterior, espera a que se calme (como haria una persona).
				var calm: int = 0
				while g._carousel == null and tb.linear_velocity.length() > 0.5 and calm < 60 * 7:
					await tree.physics_frame
					calm += 1
				aim = tb.global_position
				if g._carousel != null:
					# Adelanta el giro: donde va a estar la placa cuando llegue la pelota.
					var post := Vector3(float((g.def["carousel"] as Dictionary).get("x", 12.0)), 0, 0)
					var spin: float = float((g.def["carousel"] as Dictionary).get("speed", 0.9))
					var tof: float = g.runup_time + aim.distance_to(g._ball_spot(0)) / 14.0
					var rel: Vector3 = Vector3(aim.x - post.x, 0, aim.z - post.z).rotated(Vector3.UP, spin * tof)
					aim = Vector3(post.x + rel.x, aim.y, rel.z)
			else:
				# Puntos: rota entre los blancos y apunta a la mejor zona (centro, o la esquina de 10 del tablero);
				# si se mueve, a donde va a estar cuando llegue la pelota.
				var e: Dictionary = g.plates[(n - 1) % g.plates.size()]
				var face: Vector2 = Vector2.ZERO
				if String(e["shape"]) == "panel":
					face = Vector2(-0.78, 0.75) * (e["size"] as Vector2) * 0.5
				var xf: Transform3D = (e["body"] as Node3D).global_transform
				for m in g.movers:
					if m["body"] == e["body"]:
						var tof2: float = xf.origin.distance_to(g._ball_spot(0)) / 15.0 + 2.0 / 60.0
						xf = g.mover_at(m, g.level_time + tof2)
				aim = _face_target(g, e, face, xf)
			# Tras el muro: tiro mas lento = arco mas alto (la fisica obliga a pasarla por arriba).
			var it: Dictionary = g.cpu_shot(aim, 11.5 if lv == 5 else (16.0 if g.goal == "derribar" else 15.0), 0.0, 0.0)
			await g.launch(it["v"], it["w"])
			await _fly(g)
		var medals: Array = g.def.get("medals", [1, 2, 3])
		var sc: int = g.final_score()
		note("dianas %d (%s): %d/%d caidas, %d puntos de zona, puntaje %d en %d tiros (medallas %s)" % [lv, g.def["title"], g.fallen_count(), g.hang_count(), g.zone_points, sc, g.shots[0], str(medals)])
		if g.goal == "derribar":
			check(g.hanging() == 0, "nivel %d: todas las dianas se pueden desprender" % lv)
		check(sc >= int(medals[0]), "nivel %d: se llega al bronce (%d >= %d)" % [lv, sc, int(medals[0])])
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
