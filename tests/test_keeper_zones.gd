extends TestCase
## Zonas seguras del arquero (pedido del usuario): el arco se divide en 6 zonas (3 columnas x 2 alturas); si el arquero
## se jugo a una zona y el tiro cruza la linea en esa zona, la atajada es segura (toca la pelota y no es gol). Se mide con
## el esqueleto animado (render): en cada zona, varios puntos (rincones y centro) a distintas velocidades de penal.

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

func test_zones_split_the_goal_in_six() -> void:
	var half: float = 3.66
	var h: float = 2.44
	var seen := {}
	for i in 6:
		var c: Vector3 = KeeperZones.center(i, 52.5, half, h)
		check(KeeperZones.zone_of(c, half, h) == i, "el centro de la zona %d es de la zona %d" % [i, i])
		var rc: Array = KeeperZones.rect(i, half, h)
		check(is_equal_approx(float(rc[2]) - float(rc[0]), 2.0 * half / 3.0) and is_equal_approx(float(rc[3]) - float(rc[1]), h / 2.0), "zona %d: 2,44 x 1,22 m" % i)
		seen[KeeperZones.name_of(i)] = true
	check(seen.size() == 6, "seis nombres distintos")
	check(KeeperZones.zone_of(Vector3(52.5, 0.5, 3.9), half, h) == -1, "afuera del palo no es zona")
	check(KeeperZones.zone_of(Vector3(52.5, 2.6, 0.0), half, h) == -1, "arriba del travesaño no es zona")
	check(KeeperZones.zone_of(Vector3.INF, half, h) == -1, "un tiro que no llega no es zona")
	# Rincones: abajo y arriba de cada palo son zonas distintas; el centro es otra.
	check(KeeperZones.zone_of(Vector3(52.5, 0.3, -3.0), half, h) != KeeperZones.zone_of(Vector3(52.5, 1.9, -3.0), half, h), "abajo y arriba son zonas distintas")
	check(KeeperZones.zone_of(Vector3(52.5, 0.3, -3.0), half, h) != KeeperZones.zone_of(Vector3(52.5, 0.3, 3.0), half, h), "un palo y el otro son zonas distintas")

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

func test_a_shot_to_the_chosen_zone_is_saved() -> void:
	if _needs_render():
		return
	var asked: int = 0
	var saved: int = 0
	var goals: Array = []
	for zone in 6:
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
				if cz == zone:
					asked += 1
					var ok: bool = game.outcome != "goal" and k.touch_kind != &""
					if ok:
						saved += 1
					else:
						goals.append("%s (%.2f, %.2f) a %.0f m/s: %s, toque «%s», clip %s" % [KeeperZones.name_of(zone), cross.z, cross.y, speed, game.outcome, k.touch_kind, str(k.plan.get("clip", "-"))])
					note("%s: cruza (%.2f, %.2f) a %.0f m/s -> %s, toque «%s» (%s), corrida %.2f m" % [KeeperZones.name_of(zone), cross.z, cross.y, speed,
						game.outcome, k.touch_kind, str(k.plan.get("clip", "-")), k._sure_drift.length()])
				cleanup()
	for g in goals:
		note("NO ATAJADA: " + g)
	note("tiros a la zona elegida: %d, atajados %d" % [asked, saved])
	check(asked >= 40, "se probaron suficientes tiros dentro de la zona (%d)" % asked)
	check(saved == asked, "todos los tiros a la zona elegida se atajan (%d de %d)" % [saved, asked])

func test_another_zone_is_not_a_sure_save() -> void:
	if _needs_render():
		return
	# Tiro abajo a un palo; el arquero se juega arriba del mismo palo, o al otro palo: no hay atajada segura (decide la
	# fisica de la estirada real, que no llega).
	for c in [[Vector3(0, 0.3, -2.9), 3], [Vector3(0, 0.3, -2.9), 2], [Vector3(0, 1.9, 2.9), 0]]:
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
		if cz >= 0 and cz == k.committed_zone:
			asked += 1
			if game.outcome != "goal":
				saved += 1
			note("IA adivino %s: %s" % [KeeperZones.name_of(cz), game.outcome])
		cleanup()
	note("la IA adivino la zona %d veces, atajo %d" % [asked, saved])
	check(saved == asked, "cuando la IA adivina la zona, ataja (%d de %d)" % [saved, asked])
