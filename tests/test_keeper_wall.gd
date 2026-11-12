extends TestCase
## El arquero del tiro libre no se compromete con un tiro que va contra su barrera (fallo de CI 17fa625: la atajada
## segura «en el lugar» leia un tiro directo a la barrera como si fuera al arco y, segun el instante de la primera lectura,
## se tiraba igual). Por encima de las cabezas o lejos de la barrera, lee la pelota como siempre.

func test_wall_blocks_only_shots_into_the_bodies() -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(3)
	game.ball_spot = game.clamp_free_kick_spot(Vector3(game.gx - 22.0, 0.0, 0.0))
	game._setup_free_kick()
	await physics_frames(3)
	var k: SpKeeper = game.cpu_keeper
	check(k.wall == game.wall, "el arquero conoce su barrera")
	var bp: Vector3 = game.ball_spot + Vector3(0, 0.11, 0)
	var mid := Vector3.ZERO
	var n: int = 0
	for a in game.wall.players:
		if a.visible:
			mid += a.global_position
			n += 1
	mid /= float(maxi(n, 1))
	var dir: Vector3 = Vector3(mid.x - bp.x, 0.0, mid.z - bp.z).normalized()
	# A 25 m/s, a la altura del pecho al llegar a la barrera (9,15 m: ~0,37 s).
	var t: float = 9.15 / 25.0
	var vy_chest: float = (1.2 - bp.y + 4.9 * t * t) / t
	check(k.wall_blocks(bp, dir * 25.0 + Vector3.UP * vy_chest), "un tiro al pecho de la barrera: espera")
	var vy_over: float = (2.6 - bp.y + 4.9 * t * t) / t
	check(not k.wall_blocks(bp, dir * 25.0 + Vector3.UP * vy_over), "por encima de las cabezas: lo lee como siempre")
	var wide: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(18.0))
	check(not k.wall_blocks(bp, wide * 25.0 + Vector3.UP * vy_chest), "lejos de la barrera: lo lee como siempre")
	var past: Vector3 = mid + dir * 1.5 + Vector3.UP * 1.0
	check(not k.wall_blocks(past, dir * 20.0), "una vez que la paso, ya no la tapa")
	cleanup()
