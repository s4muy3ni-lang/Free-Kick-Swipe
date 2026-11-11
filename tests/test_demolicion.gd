extends TestCase
## «Demolición» (etapa 7, física y destrucción): los bloques quietos no se caen solos, se derriban solo con la pelota real
## (cuerpos rigidos), el tiro espera a que se asienten, los tiros son limitados, el puntaje no premia participar y cada
## nivel se puede limpiar (un jugador «prolijo» automatico, sin error, que apunta al objetivo que queda mas bajo).

func _game(level: int) -> Demolicion:
	var d: Dictionary = MinigameCatalog.level("demolicion", level)
	d["seed"] = 77
	d["practice"] = true
	Minigame.next_def = d
	var g: Demolicion = (load(Demolicion.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	return g

## Apunta a los objetivos que quedan: "bajo" (el mas bajo y centrado), "centro" (centro de los que quedan) o "alto".
func _shoot(g: Demolicion, how: String, speed: float) -> void:
	var pts: Array = []
	for i in g.blocks.size():
		if String(g.block_info[i]["kind"]) == "target" and not g.is_down(i):
			pts.append(g.blocks[i].global_position)
	var aim: Vector3 = pts[0]
	match how:
		"bajo":
			for p in pts:
				if p.y < aim.y - 0.05 or (absf(p.y - aim.y) <= 0.05 and absf(p.z) < absf(aim.z)):
					aim = p
		"alto":
			for p in pts:
				if p.y > aim.y + 0.05:
					aim = p
		_:
			aim = Vector3.ZERO
			for p in pts:
				aim += p
			aim /= float(pts.size())
	var it: Dictionary = g.cpu_shot(aim, speed, 0.0, 0.0)
	await g.launch(it["v"], it["w"])

func test_blocks_rest_until_hit() -> void:
	for lv in range(1, MinigameCatalog.levels("demolicion").size() + 1):
		var g: Demolicion = await _game(lv)
		await physics_frames(180)
		var down: int = g.count("target", true) + g.count("keep", true)
		check(down == 0 and not g._settling(), "nivel %d: sin tiro nada se cae ni se mueve (%d caidos)" % [lv, down])
		cleanup()

func test_every_level_can_be_cleared_and_scores_are_fair() -> void:
	for lv in range(1, MinigameCatalog.levels("demolicion").size() + 1):
		var cleared: String = ""
		var tried: Array = []
		for how in ["bajo", "centro", "alto"]:
			for speed in [24.0, 19.0, 15.0]:
				if cleared != "":
					break
				var g: Demolicion = await _game(lv)
				check(g.final_score() == 0 and g.medal_for(g.final_score()) == 0, "nivel %d: sin derribar nada no hay puntos ni medalla" % lv)
				var n: int = 0
				while g.state != Minigame.State.OVER and n < 60 * 40:
					if g.state == Minigame.State.AIM:
						await _shoot(g, how, speed)
					await tree.physics_frame
					n += 1
				check(g.state == Minigame.State.OVER and g.shots[0] <= g.shots_max, "nivel %d: termina sin pasarse de tiros" % lv)
				var score: int = g.final_score()
				tried.append("%s/%.0f: %d de %d" % [how, speed, g.count("target", true), g.total("target")])
				if g.count("target", false) == 0:
					cleared = "apuntando %s a %.0f m/s: %d tiros, %d blancos tirados, %d puntos, %s" % [how, speed, g.shots[0],
						g.count("keep", true), score, ChallengeScore.MEDAL_NAMES[g.medal_for(score)]]
					g.start_match()
					await physics_frames(30)
					check(g.count("target", true) == 0 and g.shots[0] == 0, "nivel %d: reiniciar deja todo como al principio" % lv)
				cleanup()
		note("nivel %d (%s): %s" % [lv, MinigameCatalog.level("demolicion", lv)["title"], cleared if cleared != "" else "NO SE LIMPIO " + str(tried)])
		check(cleared != "", "nivel %d: se puede limpiar con los tiros del nivel" % lv)

func test_a_miss_wastes_a_shot_and_ends_when_shots_run_out() -> void:
	var g: Demolicion = await _game(1)
	for k in g.shots_max:
		var it: Dictionary = g.cpu_shot(Vector3(g.table_x, 0.6, 6.0), 20.0, 0.0, 0.0)
		await g.launch(it["v"], it["w"])
		var n: int = 0
		while g.state != Minigame.State.AIM and g.state != Minigame.State.OVER and n < 900:
			await tree.physics_frame
			n += 1
	note("tres tiros afuera: estado %s, objetivos caidos %d, puntos %d" % [Minigame.State.keys()[g.state], g.count("target", true), g.final_score()])
	check(g.state == Minigame.State.OVER, "sin tiros, termina")
	check(g.final_score() == 0, "sin premio por participar")
	cleanup()

func test_glass_breaks_only_with_a_strong_real_impact() -> void:
	var g: Demolicion = await _game(9)
	await physics_frames(30)
	var pane: RigidBody3D = g.blocks[1]
	# Un toque lento: el panel se mueve apenas y no se rompe.
	g.state = Minigame.State.FLIGHT
	g.ball.reset_at(pane.global_position - Vector3(0.3, 0.2, 0))
	await physics_frames(2)
	g.ball.kick(Vector3(1.5, 0, 0), Vector3.ZERO, null)
	await physics_frames(40)
	check(not bool(g.block_info[1]["broken"]), "un toque lento no rompe el vidrio")
	cleanup()
	# Un tiro fuerte: se rompe en esquirlas que heredan su velocidad y el panel cuenta como derribado.
	g = await _game(9)
	await physics_frames(30)
	pane = g.blocks[1]
	var it: Dictionary = g.cpu_shot(pane.global_position, 20.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	# 15 m a 20 m/s: unos 45 fotogramas de vuelo; despues, que las esquirlas salgan.
	await physics_frames(60)
	var moving: int = 0
	for s in g._shards:
		if is_instance_valid(s) and (s as RigidBody3D).linear_velocity.length() > 0.3:
			moving += 1
	note("tiro fuerte al vidrio: rotos %d, esquirlas %d (%d en movimiento)" % [g.broken_count, g._shards.size(), moving])
	check(bool(g.block_info[1]["broken"]) and g.is_down(1), "un golpe fuerte lo rompe y cuenta como derribado")
	check(g._shards.size() >= 6 and not g.blocks[1].visible, "el panel se reemplaza por esquirlas")
	cleanup()

func test_materials_set_mass_friction_and_look() -> void:
	var g: Demolicion = await _game(10)
	var brick := -1
	for i in g.blocks.size():
		if String(g.block_info[i]["mat"]) == "brick":
			brick = i
			break
	check(brick >= 0, "la casita es de ladrillos")
	var b: RigidBody3D = g.blocks[brick]
	var sz: Vector3 = ((b.get_child(0) as CollisionShape3D).shape as BoxShape3D).size
	var expect: float = sz.x * sz.y * sz.z * Demolicion.BASE_DENSITY * 1.6
	check(absf(b.mass - expect) < 0.01, "masa del ladrillo por volumen y densidad (%.2f kg)" % b.mass)
	check(is_equal_approx(b.physics_material_override.friction, 0.85), "rozamiento del ladrillo")
	cleanup()
	# Los niveles viejos conservan su fisica medida (sin material: 1,2 kg y madera) aunque cambien de aspecto.
	g = await _game(4)
	check(is_equal_approx(g.blocks[0].mass, 1.2) and is_equal_approx(g.blocks[0].physics_material_override.friction, 0.7), "Precision: misma masa y rozamiento que antes")
	cleanup()
	for lv in range(1, MinigameCatalog.levels("demolicion").size() + 1):
		check(["obra", "castillo", "almacen"].has(String(MinigameCatalog.level("demolicion", lv).get("theme", ""))), "nivel %d con escenario propio" % lv)
