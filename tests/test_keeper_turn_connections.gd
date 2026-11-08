extends TestCase
## Giros del arquero conectados a su orientacion, con balon lejano y sin amenaza inmediata.

func test_every_keeper_turn_is_invocable_with_its_measured_orientation() -> void:
	var ctx: MatchContext = await make_match(Vector3.ZERO)
	var keeper := Goalkeeper.new()
	spawn(keeper)
	keeper.setup(ctx, 1, 90, PlayerAttributes.new())
	keeper.set_physics_process(false)
	var ids: Array[StringName] = AnimDB.candidates(&"gk_turn", {"mirrors": false})
	check(ids.size() == 11, "11 giros de arquero investigados")
	for id in ids:
		keeper.state = Goalkeeper.State.POSITION
		keeper.global_position = Vector3(14, 0, 0)
		keeper.yaw = Locomotion.yaw_from_dir(Vector3(-1, 0, 0))
		var m: Dictionary = PackLibrary.meta(id)
		var angle: float = ActionMotion.heading_rel(m["heading_path"], m["duration"])
		var face: Vector3 = Locomotion.dir_from_yaw(keeper.yaw + angle)
		ctx.ball.reset_at(keeper.global_position + face * 6.1)
		await physics_frames(2)
		keeper.velocity = Vector3.ZERO
		check(keeper.start_orientation_turn(id), "%s inicia el estado de giro en su condicion geometrica" % id)
		check(keeper.visual.current_action == id, "%s ocupa la pose real del arquero" % id)
		keeper._tick_turn(1.0 / 60.0)
		check(keeper.velocity.is_finite() and is_finite(keeper.yaw), "%s aplica raiz y rumbo finitos" % id)
		keeper._motion.stop()
		keeper.visual.stop_current_action()

func test_orientation_turn_is_cancelled_when_the_ball_target_changes() -> void:
	var ctx: MatchContext = await make_match(Vector3.ZERO)
	var keeper := Goalkeeper.new()
	spawn(keeper)
	keeper.setup(ctx, 1, 90, PlayerAttributes.new())
	keeper.set_physics_process(false)
	keeper.global_position = Vector3(14, 0, 0)
	keeper.yaw = Locomotion.yaw_from_dir(Vector3(-1, 0, 0))
	var id: StringName = AnimDB.candidates(&"gk_turn", {"mirrors": false})[0]
	var meta: Dictionary = PackLibrary.meta(id)
	var turn: float = ActionMotion.heading_rel(meta["heading_path"], meta["duration"])
	ctx.ball.reset_at(keeper.global_position + Locomotion.dir_from_yaw(keeper.yaw + turn) * 6.1)
	await physics_frames(2)
	check(keeper.start_orientation_turn(id), "empieza un giro hacia la pelota real")
	ctx.ball.reset_at(keeper.global_position + keeper.forward() * 7.0)
	await physics_frames(2)
	keeper._tick_turn(1.0 / 60.0)
	check(keeper.state == Goalkeeper.State.POSITION and not keeper._motion.active, "la reposicion invalida el destino anterior y libera el giro")
	check(keeper.stats["dives"] == 0, "el cambio de destino no fabrica una atajada")
