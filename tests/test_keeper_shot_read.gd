extends TestCase
## Lectura de tiros reales y reaccion a una trayectoria a puerta, sin depender de que una IA aleatoria acierte.

func test_real_shot_is_read_and_an_on_target_ball_triggers_a_save_plan() -> void:
	var ctx: MatchContext = await make_match(Vector3(11.0, 0.11, 0.5))
	var keeper := Goalkeeper.new()
	spawn(keeper)
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	keeper.setup(ctx, 1, 90, attrs)
	keeper.rng.seed = 84
	var shooter: Footballer = add_player(ctx, 0, Vector3(10.5, 0, 0.5), 60)
	shooter.set_physics_process(false)
	await physics_frames(6)
	var v := Vector3(18.0, 0.0, 0.0)
	ctx.ball.kick(v, ctx.ball.rolling_spin(v), shooter)
	var windup_before: float = keeper._kick_seen_since
	var event := GameEvent.make(GameEvent.Type.SHOT, shooter.actor_id, 0, {"dir": [1.0, 0.0], "speed": 18.0})
	ctx.emit_event(event)
	ctx.emit_event(event)
	check(keeper._kick_seen_since == windup_before, "el aviso no inventa ni borra anticipacion anterior al golpe")
	check(keeper.stats["shots_seen"] == 1, "el tiro real se lee una vez, incluso con notificacion duplicada")
	var planned: bool = false
	for i in 90:
		await tree.physics_frame
		planned = planned or keeper.state == Goalkeeper.State.PREPARE or keeper.state == Goalkeeper.State.ACTION
	check(keeper.stats["shots_faced"] > 0, "la trayectoria fisica amenaza el arco")
	check(planned, "el arquero prepara o ejecuta una atajada real")
	check(keeper.stats["catches"] + keeper.stats["parries"] > 0, "sus manos atajan o despejan la pelota")
	var before: int = keeper.stats["shots_seen"]
	ctx.emit_event(GameEvent.make(GameEvent.Type.SHOT, -500, 0, {"dir": [1.0, 0.0], "speed": 18.0}))
	check(keeper.stats["shots_seen"] == before, "un evento sin golpeador real no fabrica una reaccion")
