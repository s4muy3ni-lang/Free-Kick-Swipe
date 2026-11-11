extends TestCase
## «Curling»: en el hielo la pelota frena ICE_DECEL (llega a donde dice v^2/2a); la pelota lanzada queda como piedra que
## otra puede desplazar; las que salen de juego se quitan; el puntaje cuenta las piedras mas cerca del centro que la
## mejor del rival; la IA juega con la misma fisica; cada nivel se puede ganar.

func _game(level: int) -> Curling:
	var d: Dictionary = MinigameCatalog.level("curling", level)
	d["seed"] = 8
	d["practice"] = true
	Minigame.next_def = d
	var g: Curling = (load(Curling.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(10)
	return g

func _wait(g: Minigame, limit: int = 60 * 40) -> String:
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < limit:
		await tree.physics_frame
		n += 1
	var r: String = g.last_result
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
		await physics_frames(2)
	return r

## Desliza la pelota del usuario hasta un punto (velocidad para frenar ahi).
func _slide_to(g: Curling, target: Vector3, extra: float = 0.0) -> String:
	var spot: Vector3 = g._ball_spot(0)
	var dir: Vector3 = Vector3(target.x - spot.x, 0, target.z - spot.z)
	var v: Vector3 = dir.normalized() * (Curling.speed_to_stop(dir.length()) + extra)
	await g.launch(v, g.ball.rolling_spin(v))
	return await _wait(g)

func test_ice_slide_matches_the_model() -> void:
	var g: Curling = await _game(1)
	var r: String = await _slide_to(g, g.house)
	var d: float = Vector2(g.ball.global_position.x - g.house.x, g.ball.global_position.z).length()
	var stone: float = g.closest(0)
	note("deslizada al centro (%.2f m/s): %s, piedra a %.2f m del centro" % [Curling.speed_to_stop(g.house.x - 0.0), r, stone])
	check(stone < 0.4, "con la velocidad de la tabla medida frena cerca del centro (%.2f m)" % stone)
	check(g.stones.size() == 1 and int(g.stones[0]["team"]) == 0, "la pelota quedo como piedra azul")
	cleanup()

func test_stones_can_be_knocked_out_and_out_of_play_removed() -> void:
	var g: Curling = await _game(2)
	var red: RigidBody3D = g.stones[0]["body"]
	var before: Vector3 = red.global_position
	# Tiro fuerte directo a la roja del centro.
	var spot: Vector3 = g._ball_spot(0)
	var v: Vector3 = Vector3(before.x - spot.x, 0, before.z - spot.z).normalized() * 4.8
	await g.launch(v, g.ball.rolling_spin(v))
	var moved: float = 0.0
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < 60 * 40:
		await tree.physics_frame
		n += 1
		if is_instance_valid(red):
			moved = maxf(moved, red.global_position.distance_to(before))
	await _wait(g)
	note("la roja se desplazo %.2f m; piedras en juego %d" % [moved, g.stones.size()])
	check(moved > 1.0, "un choque real desplaza la piedra rival")
	var ok: bool = true
	for e in g.stones:
		if g.out_of_play((e["body"] as Node3D).global_position):
			ok = false
	check(ok, "las que salieron de juego se quitaron")
	cleanup()

func test_end_score_counts_closer_stones() -> void:
	var g: Curling = await _game(1)
	g._add_stone(g.house + Vector3(0.2, 0.11, 0), 0)
	g._add_stone(g.house + Vector3(-0.5, 0.11, 0.3), 0)
	g._add_stone(g.house + Vector3(0.0, 0.11, 0.8), 1)
	g._add_stone(g.house + Vector3(0.0, 0.11, 1.5), 0)
	var sc: Array = g.end_score()
	check(int(sc[0]) == 0 and int(sc[1]) == 2, "azul suma 2 (las dos mas cerca que la mejor roja)")
	cleanup()

func test_every_level_can_be_won() -> void:
	for lv in range(1, MinigameCatalog.levels("curling").size() + 1):
		var g: Curling = await _game(lv)
		g.cpu_error = Vector2(1.5, 0.08)
		var n: int = 0
		while g.state != Minigame.State.OVER and n < 60 * 600:
			if g.state == Minigame.State.AIM and g.side == Minigame.Side.USER:
				# Estrategia simple: si la CPU gana la mano, sacar su mejor piedra; si no, al centro (por el costado si hay
				# guardias en la linea).
				var best_red: Vector3 = Vector3.INF
				var bd: float = INF
				for e in g.stones:
					if int(e["team"]) == 1:
						var p: Vector3 = (e["body"] as Node3D).global_position
						var d: float = Vector2(p.x - g.house.x, p.z).length()
						if d < bd:
							bd = d
							best_red = p
				if bd < Curling.HOUSE_R[0] and bd < g.closest(0):
					var spot: Vector3 = g._ball_spot(0)
					var v: Vector3 = Vector3(best_red.x - spot.x, 0, best_red.z - spot.z).normalized() * 4.6
					await g.launch(v, g.ball.rolling_spin(v))
					await _wait(g)
				else:
					var blocked := false
					for e in g.stones:
						var p2: Vector3 = (e["body"] as Node3D).global_position
						if p2.x < g.house.x - 1.0 and absf(p2.z) < 0.35:
							blocked = true
					await _slide_to(g, g.house + (Vector3(0, 0, -0.9) if blocked else Vector3.ZERO))
				continue
			if g.state == Minigame.State.RESOLVE:
				g._after_resolve()
			await tree.physics_frame
			n += 1
		var sc: Array = g.end_score()
		note("nivel %d (%s): gana %s con %d, mejor azul a %.2f m, puntaje %d" % [lv, g.def["title"], "usuario" if int(sc[0]) == 0 else ("CPU" if int(sc[0]) == 1 else "nadie"), int(sc[1]), g.closest(0), g.final_score()])
		check(g.state == Minigame.State.OVER and g.winner == Minigame.Side.USER, "nivel %d: se puede ganar" % lv)
		check(g.final_score() >= int(g.def["medals"][0]), "nivel %d: llega al bronce" % lv)
		cleanup()
