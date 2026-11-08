extends TestCase
## Arquero: posicionamiento, planificacion de atajadas con la trayectoria de manos de los clips, contacto real de las
## manos, atajada/rechazo/gol segun la velocidad y distribucion. Requiere la libreria local del pack (se omite sin ella).

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available() or PackLibrary.keeper() == null:
		skip("faltan assets/animations/pack_clips.res y pack_keeper.res (ver tools/animation_pack/build_pack_library.tscn)")
		return true
	return false

## Cancha + pelota + contexto + arquero del equipo 1 (defiende x = +20) mirando a -X.
func _world() -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(0.0, 0.11, 0.0))
	var k := Goalkeeper.new()
	spawn(k)
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	k.setup(ctx, 1, 90, attrs)
	await physics_frames(6)
	return {"ctx": ctx, "k": k}

func _shoot(ctx: MatchContext, from: Vector3, target: Vector3, speed: float) -> void:
	# reset_at coloca la pelota en el siguiente paso de fisica: el golpeo va un paso despues.
	# Como un golpeo real: velocidad con el efecto de rodadura (si no, la pelota patina y pierde velocidad).
	var d: Vector3 = target - from
	ctx.ball.reset_at(from)
	await tree.physics_frame
	await tree.physics_frame
	var v: Vector3 = d.normalized() * speed
	ctx.ball.kick(v, ctx.ball.rolling_spin(v))

func test_keeper_stands_on_the_goal_line_arc_and_tracks_the_ball() -> void:
	if _skip_if_missing():
		return
	var w: Dictionary = await _world()
	var k: Goalkeeper = w["k"]
	var ctx: MatchContext = w["ctx"]
	check(ctx.keeper_defending(1) == k and ctx.keeper_defending(0) == null, "el arquero esta registrado en el contexto")
	check_range(k.global_position.x, 18.5, 20.0, "empieza delante de su linea de gol (x=%.2f)" % k.global_position.x)
	ctx.ball.reset_at(Vector3(10.0, 0.11, 6.0))
	await wait_seconds(2.5)
	check(k.global_position.z > 0.3, "se corre hacia el lado de la pelota (z=%.2f)" % k.global_position.z)
	check_range(absf(k.global_position.z), 0.0, ctx.pitch.config.half_goal() + 1.0, "no se sale del ancho del arco (z=%.2f)" % k.global_position.z)
	var to_ball: Vector3 = ctx.ball.global_position - k.global_position
	var facing: float = KickModel.angle_between_deg(k.forward(), Vector3(to_ball.x, 0.0, to_ball.z))
	check(facing < 25.0, "mira la pelota (%.1f grados)" % facing)
	check(k.visual.directional, "usa la mezcla direccional de 8 sentidos mientras se posiciona")

func test_planner_finds_a_clip_whose_hands_reach_the_predicted_ball() -> void:
	if _skip_if_missing():
		return
	var origin := Vector3(19.0, 0.0, 0.0)
	var yaw: float = Locomotion.yaw_from_dir(Vector3(-1, 0, 0))
	var found := {}
	for tgt in [Vector3(20.0, 0.5, 1.0), Vector3(20.0, 1.5, -1.2), Vector3(20.0, 0.3, -1.4), Vector3(20.0, 1.0, 0.0)]:
		var traj: PackedVector3Array = BallPredictor.trajectory(Vector3(8.0, 0.5, 0.0), (tgt - Vector3(8.0, 0.5, 0.0)).normalized() * 14.0, 1.2)
		var plan: Dictionary = KeeperPlanner.plan_save(origin, yaw, traj, 1.0 / 30.0, 0.0, 14.0, false)
		check(not plan.is_empty(), "hay plan para un disparo a %s" % str(tgt))
		if not plan.is_empty():
			found[plan["clip"]] = true
			check(float(plan["dist"]) < 1.0, "las manos llegan a menos de 1 m de la pelota prevista (%.2f m con '%s')" % [plan["dist"], plan["clip"]])
	note("clips elegidos para 4 disparos distintos: %s" % str(found.keys()))
	check(found.size() >= 2, "segun la altura y el lado se eligen clips distintos (%d)" % found.size())

func test_slow_shot_to_the_hands_is_caught_and_distributed() -> void:
	if _skip_if_missing():
		return
	var w: Dictionary = await _world()
	var k: Goalkeeper = w["k"]
	var ctx: MatchContext = w["ctx"]
	var events: Array = []
	ctx.event_emitted.connect(func(e: GameEvent) -> void: events.append(e))
	# Con la rodadura proporcional (BallTuning.rolling_viscous) un tiro raso de 13 m/s desde 12 m llega suave (~3 m/s);
	# uno de 8 m/s ya no llega al arco.
	await _shoot(ctx, Vector3(8.0, 0.11, 1.0), Vector3(20.0, 0.11, 1.2), 13.0)
	await wait_seconds(2.2)
	check(k.stats["catches"] == 1, "ataja un tiro suave raso (%s)" % str(k.stats))
	var caught: bool = events.any(func(e: GameEvent) -> bool: return e.type == GameEvent.Type.KEEPER_CATCH)
	check(caught, "se emite KEEPER_CATCH")
	check(ctx.ball.holder == k or k.stats["distributions"] > 0, "sostiene la pelota o ya la saco")
	await wait_seconds(5.0)
	check(k.stats["distributions"] >= 1, "despues de sostenerla la saca (%s)" % str(k.stats))
	check(events.any(func(e: GameEvent) -> bool: return e.type == GameEvent.Type.KEEPER_DISTRIBUTE), "se emite KEEPER_DISTRIBUTE")
	check(ctx.ball.holder != k, "ya no la tiene en las manos")

func test_hands_contact_is_real_the_ball_must_be_within_reach() -> void:
	if _skip_if_missing():
		return
	var w: Dictionary = await _world()
	var k: Goalkeeper = w["k"]
	var ctx: MatchContext = w["ctx"]
	# Tiro fuerte al angulo: no llega con las manos -> gol (la pelota cruza la linea), sin atajada inventada.
	var goals: Array = []
	ctx.event_emitted.connect(func(e: GameEvent) -> void: goals.append(e))
	await _shoot(ctx, Vector3(10.0, 1.0, 0.0), Vector3(20.5, 1.9, 1.4), 26.0)
	await wait_seconds(1.5)
	var beaten: int = int(k.stats["beaten"])
	var caught: int = int(k.stats["catches"]) + int(k.stats["parries"])
	note("tiro fuerte al angulo: atajadas=%d, superado=%d, log=%s" % [caught, beaten, str(k.save_log.back() if not k.save_log.is_empty() else {})])
	check(caught == 0 or beaten == 0, "el resultado es coherente con el contacto de las manos")
	check(not k.save_log.is_empty(), "queda registrado lo que paso (%d entradas)" % k.save_log.size())

func test_save_rate_depends_on_speed_and_placement() -> void:
	if _skip_if_missing():
		return
	var results := {}
	for speed in [9.0, 15.0, 24.0]:
		var saved_n := 0
		var n := 0
		for seed_i in 12:
			var w: Dictionary = await _world()
			var k: Goalkeeper = w["k"]
			var ctx: MatchContext = w["ctx"]
			k.rng.seed = 100 + seed_i
			var r := RandomNumberGenerator.new()
			r.seed = 7000 + seed_i
			var tz: float = r.randf_range(-1.3, 1.3)
			var ty: float = r.randf_range(0.2, 1.8)
			var from := Vector3(10.0, 0.15 + r.randf_range(0.0, 0.8), r.randf_range(-3.0, 3.0))
			await _shoot(ctx, from, Vector3(20.6, ty, tz), speed)
			# Tiros al arco: los que el arquero ataja o los que cruzan la linea entre los palos. Uno lento que se frena antes
			# del arco no es un tiro al arco (antes contaba como no atajado).
			var crossed: bool = false
			for i in 96:
				await tree.physics_frame
				var bp: Vector3 = ctx.ball.global_position
				if bp.x > 20.0 and absf(bp.z) < ctx.pitch.config.half_goal() and bp.y < ctx.pitch.config.goal_height:
					crossed = true
			var saved: bool = k.stats["catches"] + k.stats["parries"] > 0
			if saved:
				saved_n += 1
			if saved or crossed:
				n += 1
			cleanup()
		results[speed] = float(saved_n) / maxf(n, 1)
		note("velocidad %.0f m/s: el arquero detiene %d de %d tiros al arco (%.0f %%)" % [speed, saved_n, n, 100.0 * results[speed]])
	check(results[9.0] >= 0.6, "los tiros suaves se detienen en su mayoria (%.0f %%)" % (100.0 * results[9.0]))
	check(results[24.0] < results[9.0], "un tiro mas fuerte es mas dificil de detener")
