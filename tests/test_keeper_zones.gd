extends TestCase
## Sectores del arquero (pedido del usuario): el arco se divide en 9 sectores (3 columnas x 3 alturas); si el arquero se
## jugo a un sector, el tiro cruza la linea en ese sector y el punto esta a su alcance fisico (KeeperReach), la atajada es
## segura (toca la pelota y no es gol). Pegado al angulo, fuera del alcance, es gol aunque haya elegido bien. Lo que mueve
## el esqueleto se mide con render: en cada sector, los cuatro rincones a dos velocidades de penal.

func _needs_render() -> bool:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return true
	return false

func _game(mode: int) -> SetPieceGame:
	SetPieceGame.next_mode = mode
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	return game

func test_zones_split_the_goal_in_nine() -> void:
	var half: float = 3.66
	var h: float = 2.44
	var seen := {}
	check(KeeperZones.COUNT == 9, "nueve sectores")
	for i in KeeperZones.COUNT:
		var c: Vector3 = KeeperZones.center(i, 52.5, half, h)
		check(KeeperZones.zone_of(c, half, h) == i, "el centro del sector %d es del sector %d" % [i, i])
		var rc: Array = KeeperZones.rect(i, half, h)
		check(is_equal_approx(float(rc[2]) - float(rc[0]), 2.0 * half / 3.0) and is_equal_approx(float(rc[3]) - float(rc[1]), h / 3.0), "sector %d: 2,44 x 0,81 m" % i)
		seen[KeeperZones.name_of(i)] = true
	check(seen.size() == 9, "nueve nombres distintos")
	check(KeeperZones.zone_of(Vector3(52.5, 0.5, 3.9), half, h) == -1, "afuera del palo no es sector")
	check(KeeperZones.zone_of(Vector3(52.5, 2.6, 0.0), half, h) == -1, "arriba del travesaño no es sector")
	check(KeeperZones.zone_of(Vector3.INF, half, h) == -1, "un tiro que no llega no es sector")
	# Rincones: abajo, al medio y arriba de cada palo son sectores distintos; un palo y el otro tambien.
	var low: int = KeeperZones.zone_of(Vector3(52.5, 0.3, -3.0), half, h)
	var mid: int = KeeperZones.zone_of(Vector3(52.5, 1.2, -3.0), half, h)
	var high: int = KeeperZones.zone_of(Vector3(52.5, 2.1, -3.0), half, h)
	check(low != mid and mid != high and low != high, "abajo, al medio y arriba son sectores distintos")
	check(low == 0 and mid == 3 and high == 6, "filas de abajo hacia arriba (0, 3, 6)")
	check(KeeperZones.zone_of(Vector3(52.5, 0.3, -3.0), half, h) != KeeperZones.zone_of(Vector3(52.5, 0.3, 3.0), half, h), "un palo y el otro son sectores distintos")

## Modelo de alcance (sin render): el angulo no se alcanza nunca, el centro alto si; pegado al palo abajo llega con un
## tiro lento y no con uno muy rapido; el tiempo y la altura cambian el alcance en el sentido correcto; los atributos lo
## escalan solo dentro de sus limites.
func test_the_reach_model() -> void:
	check(KeeperReach.reachable(Vector3(0, 2.3, 0.3), 0.0, 0.5), "centro alto: llega")
	for t in [0.4, 0.6, 1.0, 3.0]:
		check(not KeeperReach.reachable(Vector3(0, 2.3, 3.4), 0.0, t), "pegado al angulo no llega ni con %.1f s" % t)
		check(not KeeperReach.reachable(Vector3(0, 2.3, -3.4), 0.0, t), "tampoco del otro lado (%.1f s)" % t)
	check(KeeperReach.reachable(Vector3(0, 0.3, 3.4), 0.0, 0.8), "pegado al palo abajo, tiro lento: llega")
	check(not KeeperReach.reachable(Vector3(0, 0.3, 3.4), 0.0, 0.4), "pegado al palo abajo, tiro muy rapido: no llega")
	check(KeeperReach.reachable(Vector3(0, 0.3, 1.0), 0.0, 0.2), "cerca del cuerpo llega aunque casi no tenga tiempo")
	var prev: float = INF
	for i in 8:
		var y: float = 1.2 + float(i) * 0.18
		var r: float = KeeperReach.reach(y, 1.0)
		check(r <= prev, "el alcance baja con la altura (%.2f m a %.2f m)" % [r, y])
		prev = r
	check(KeeperReach.reach(0.5, 0.3) < KeeperReach.reach(0.5, 0.45) and KeeperReach.reach(0.5, 0.45) < KeeperReach.reach(0.5, 0.6), "mas tiempo, mas alcance")
	check(is_equal_approx(KeeperReach.reach(0.5, 0.0), KeeperReach.LOW * KeeperReach.F_MIN), "sin tiempo, solo lo que tiene a mano")
	check(is_equal_approx(KeeperReach.reach(0.5, 1.0, 5.0), KeeperReach.reach(0.5, 1.0, KeeperReach.SCALE_LIMITS.y)), "el atributo de alcance tiene tope")
	check(is_equal_approx(KeeperReach.time_factor(0.3, -1.0), KeeperReach.time_factor(0.3, KeeperReach.REACT_LIMITS.x)), "el de reflejos tambien")
	check(KeeperReach.reach(0.5, 1.0, KeeperReach.SCALE_LIMITS.y) - KeeperReach.reach(0.5, 1.0) < 0.25, "un atributo alto suma poco alcance (no asegura nada)")
	# Arquero corrido (tiro libre): mide desde donde esta parado.
	check(KeeperReach.reachable(Vector3(0, 1.0, 3.4), 1.0, 1.0) and not KeeperReach.reachable(Vector3(0, 1.0, -3.4), 1.0, 1.0), "mide desde donde esta parado")
	# Tiempo hasta la linea en una trayectoria recta a 20 m/s desde 11 m: 0,55 s.
	var traj := PackedVector3Array()
	for i in 60:
		traj.append(Vector3(41.5 + 20.0 * float(i) / 60.0, 0.5, 0.0))
	check(absf(KeeperReach.time_to_line(traj, 1.0 / 60.0, 52.5) - 0.55) < 0.01, "tiempo hasta la linea: %.3f s" % KeeperReach.time_to_line(traj, 1.0 / 60.0, 52.5))

## Grilla tactil (sin render): al atajar se ven los 9 sectores; un toque elige el sector que lo contiene, el arquero se
## juega a su centro, se resalta solo ese y al salir la pelota la grilla se esconde.
func test_the_touch_grid_picks_one_of_nine_sectors() -> void:
	var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
	game.shootout.record(0, true)
	game._start_penalty_turn()
	await physics_frames(3)
	check(game.phase == SetPieceGame.Phase.KEEPER_PICK, "turno de atajar")
	check(game._zone_grid.visible and game._zone_cells.size() == 9, "se ve la grilla de 9 sectores")
	for i in [0, 2, 4, 6, 8]:
		var c: Vector3 = KeeperZones.center(i, game.gx, game.half_goal, game.goal_h)
		# Un toque cerca del rincon del sector (no en el centro) elige ese sector.
		var rc: Array = KeeperZones.rect(i, game.half_goal, game.goal_h)
		var touch := Vector3(game.gx, lerpf(float(rc[1]), float(rc[3]), 0.8), lerpf(float(rc[0]), float(rc[2]), 0.2))
		game._pick_zone(game.cam.unproject_position(touch))
		check(game.picked_zone == i, "tocar dentro del sector %d lo elige (%d)" % [i, game.picked_zone])
		check(game._keeper_zone.distance_to(c) < 0.01, "el arquero se juega al centro del sector %d" % i)
		var lit: int = 0
		for cell in game._zone_cells:
			if (cell.material_override as StandardMaterial3D).albedo_color.a > 0.3:
				lit += 1
		check(lit == 1, "solo se resalta el sector elegido")
	check(game.hud.hint.text.contains(KeeperZones.name_of(8)), "el aviso dice a donde se tira: «%s»" % game.hud.hint.text)
	# Patea la CPU: al salir la pelota la grilla se esconde.
	var n: int = 0
	while game.phase == SetPieceGame.Phase.KEEPER_PICK or game.phase == SetPieceGame.Phase.RUNUP:
		await tree.physics_frame
		n += 1
		if n > 900:
			break
	check(game.phase != SetPieceGame.Phase.KEEPER_PICK and game.phase != SetPieceGame.Phase.RUNUP, "la CPU patea")
	check(not game._zone_grid.visible, "al salir la pelota la grilla ya no se ve")
	cleanup()

## Puntos de prueba dentro de la zona i: los cuatro rincones (a 0,2 m de los bordes; lo mas dificil de alcanzar).
func _points(i: int, half: float, h: float) -> Array:
	var rc: Array = KeeperZones.rect(i, half, h)
	var z0: float = float(rc[0]) + 0.2
	var z1: float = float(rc[2]) - 0.2
	var y0: float = maxf(float(rc[1]) + 0.2, 0.2)
	var y1: float = float(rc[3]) - 0.2
	return [Vector3(0, y0, z0), Vector3(0, y0, z1), Vector3(0, y1, z0), Vector3(0, y1, z1)]

func _penalty(game: SetPieceGame, target: Vector3, speed: float, zone: int) -> void:
	game.rng.seed = 4242
	game.user_keeper.rng.seed = 99
	game.shootout.record(0, true)
	game._start_penalty_turn()
	await physics_frames(5)
	game._keeper_zone = KeeperZones.center(zone, game.gx, game.half_goal, game.goal_h)
	game._pick_t = 1.0
	var p := ShotParams.new()
	p.target = target
	p.power = clampf((speed - SetPieceGame.PEN_SPEED.x) / (SetPieceGame.PEN_SPEED.y - SetPieceGame.PEN_SPEED.x), 0.0, 1.0)
	p.speed = speed
	p.kind = ShotCatalog.Kind.POWER if p.power > 0.7 else ShotCatalog.Kind.NORMAL
	p.direction = Vector3(target.x - game.ball_spot.x, 0, target.z - game.ball_spot.z).normalized()
	GestureShotModel.solve(p, game.ball_spot, game.shot_context(), false)
	game.phase = SetPieceGame.Phase.RUNUP
	game._take_shot(game.cpu_shooter, p, 0.0)
	var n: int = 0
	while game.phase in [SetPieceGame.Phase.RUNUP, SetPieceGame.Phase.FLIGHT] and n < 900:
		await tree.physics_frame
		n += 1

func test_a_reachable_shot_to_the_chosen_sector_is_saved() -> void:
	if _needs_render():
		return
	var asked: int = 0
	var saved: int = 0
	var out_of_reach: int = 0
	var out_goals: int = 0
	var goals: Array = []
	for zone in KeeperZones.COUNT:
		for speed in [19.0, 27.0]:
			var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
			var pts: Array = _points(zone, game.half_goal, game.goal_h)
			cleanup()
			for q in pts:
				game = await _game(SetPieceGame.Mode.PENALTY)
				var target := Vector3(game.gx, (q as Vector3).y, (q as Vector3).z)
				await _penalty(game, target, speed, zone)
				var cross: Vector3 = game.last_shot.get("cross", Vector3.INF)
				var cz: int = KeeperZones.zone_of(cross, game.half_goal, game.goal_h)
				var k: SpKeeper = game.user_keeper
				var reach: Dictionary = k.last_reach
				if cz == zone and bool(reach.get("ok", false)):
					asked += 1
					var ok: bool = game.outcome != "goal" and k.touch_kind != &""
					if ok:
						saved += 1
					else:
						goals.append("%s (%.2f, %.2f) a %.0f m/s: %s, toque «%s», clip %s" % [KeeperZones.name_of(zone), cross.z, cross.y, speed, game.outcome, k.touch_kind, str(k.plan.get("clip", "-"))])
				elif cz == zone:
					out_of_reach += 1
					if game.outcome == "goal":
						out_goals += 1
				note("%s: cruza (%.2f, %.2f) a %.0f m/s, alcance %.2f de %.2f m (%.2f s) -> %s, toque «%s» (%s), corrida %.2f m" % [KeeperZones.name_of(zone), cross.z, cross.y, speed,
					float(reach.get("d", 0.0)), float(reach.get("reach", 0.0)), float(reach.get("time", 0.0)), game.outcome, k.touch_kind, str(k.plan.get("clip", "-")), k._sure_drift.length()])
				cleanup()
	for g in goals:
		note("NO ATAJADA: " + g)
	note("tiros al sector elegido y al alcance: %d, atajados %d · fuera del alcance: %d, goles %d" % [asked, saved, out_of_reach, out_goals])
	check(asked >= 40, "se probaron suficientes tiros al alcance dentro del sector (%d)" % asked)
	check(saved == asked, "todos los tiros al sector elegido y al alcance se atajan (%d de %d)" % [saved, asked])
	check(out_of_reach >= 10, "hubo tiros pegados al palo o al angulo fuera del alcance (%d)" % out_of_reach)
	check(out_goals == out_of_reach, "fuera del alcance no hay atajada imposible: gol (%d de %d)" % [out_goals, out_of_reach])

## Pegado al angulo (pedido del usuario): el arquero elige bien el sector de arriba y el tiro va pegado al angulo; supera
## el alcance de la estirada: gol, sin atajada segura.
func test_a_shot_into_the_angle_beats_the_right_guess() -> void:
	if _needs_render():
		return
	for c in [[Vector3(0, 2.25, 3.42), 8, 21.0], [Vector3(0, 2.25, -3.42), 6, 25.0], [Vector3(0, 0.3, 3.42), 2, 29.0]]:
		var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
		var target := Vector3(game.gx, (c[0] as Vector3).y, (c[0] as Vector3).z)
		await _penalty(game, target, float(c[2]), int(c[1]))
		var k: SpKeeper = game.user_keeper
		var cross: Vector3 = game.last_shot.get("cross", Vector3.INF)
		note("tiro a (%.2f, %.2f) a %.0f m/s, arquero %s: cruza sector %s, alcance %.2f de %.2f m -> %s, toque «%s»" % [cross.z, cross.y, float(c[2]),
			KeeperZones.name_of(int(c[1])), KeeperZones.name_of(int(k.last_reach.get("zone", -1))), float(k.last_reach.get("d", 0.0)),
			float(k.last_reach.get("reach", 0.0)), game.outcome, k.touch_kind])
		check(int(k.last_reach.get("zone", -1)) == int(c[1]), "el tiro cruza en el sector elegido")
		check(not bool(k.last_reach.get("ok", true)), "pero fuera del alcance")
		check(k.sure_saves == 0 and not k.sure, "no hay atajada segura")
		check(game.outcome == "goal", "es gol")
		cleanup()

func test_another_zone_is_not_a_sure_save() -> void:
	if _needs_render():
		return
	# Tiro abajo a un palo; el arquero se juega arriba del mismo palo, o al otro palo: no hay atajada segura (decide la
	# fisica de la estirada real, que no llega).
	for c in [[Vector3(0, 0.3, -2.9), 6], [Vector3(0, 0.3, -2.9), 2], [Vector3(0, 1.9, 2.9), 0]]:
		var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
		var target := Vector3(game.gx, (c[0] as Vector3).y, (c[0] as Vector3).z)
		await _penalty(game, target, 24.0, int(c[1]))
		var k: SpKeeper = game.user_keeper
		note("tiro a (%.1f, %.1f), arquero %s: %s, toque «%s»" % [target.z, target.y, KeeperZones.name_of(int(c[1])), game.outcome, k.touch_kind])
		check(k.sure_saves == 0, "zona distinta: no es atajada segura")
		check(game.outcome == "goal", "a la otra zona, gol")
		cleanup()

func test_the_cpu_keeper_also_saves_when_it_guesses_the_zone() -> void:
	if _needs_render():
		return
	var asked: int = 0
	var saved: int = 0
	for i in 16:
		var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
		game.rng.seed = 100 + i
		game.cpu_keeper.rng.seed = 500 + i
		var z: float = [-2.6, 2.6, -2.2, 2.2][i % 4]
		var y: float = [0.35, 1.8][(i / 4) % 2]
		game.shoot(Vector3(game.gx, y, z), 0.8, 0.0)
		var n: int = 0
		while game.phase in [SetPieceGame.Phase.RUNUP, SetPieceGame.Phase.FLIGHT] and n < 900:
			await tree.physics_frame
			n += 1
		var k: SpKeeper = game.cpu_keeper
		var cz: int = KeeperZones.zone_of(game.last_shot.get("cross", Vector3.INF), game.half_goal, game.goal_h)
		if cz >= 0 and cz == k.committed_zone and bool(k.last_reach.get("ok", false)):
			asked += 1
			if game.outcome != "goal":
				saved += 1
			note("IA adivino %s: %s" % [KeeperZones.name_of(cz), game.outcome])
		cleanup()
	note("la IA adivino el sector (al alcance) %d veces, atajo %d" % [asked, saved])
	check(saved == asked, "cuando la IA adivina el sector y llega, ataja (%d de %d)" % [saved, asked])
