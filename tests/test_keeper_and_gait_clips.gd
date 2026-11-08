extends TestCase
## Arquero: achique en el mano a mano, salida a por un centro, estirada desesperada (goalkeeper_miss), pelota en las
## manos con su clip de reposo e indicaciones al equipo. Marcha: arranque explosivo, giro a la carrera y parada agotado.

func _keeper_world(ball_pos: Vector3) -> Dictionary:
	PackLibrary.reload()
	var ctx: MatchContext = await make_match(ball_pos)
	var k := Goalkeeper.new()
	spawn(k)
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	k.setup(ctx, 1, 99, attrs)   # defiende el arco +X
	await physics_frames(3)
	return {"ctx": ctx, "k": k}

func test_keeper_rushes_out_against_a_lone_attacker() -> void:
	var w: Dictionary = await _keeper_world(Vector3(11.0, 0.11, 1.0))
	var ctx: MatchContext = w["ctx"]
	var k: Goalkeeper = w["k"]
	var src := ScriptedInput.new()
	var att: Footballer = add_player(ctx, 0, Vector3(10.5, 0.0, 1.0), 60, src)
	att.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	ctx.ball.register_touch(att)   # la pelota es suya (posesion: la toco el)
	await wait_seconds(1.5)
	var hl: float = ctx.pitch.config.half_length()
	var depth_alone: float = hl - k.global_position.x
	check(k.rushing, "con el rival solo hacia el arco el arquero sale a achicar")
	# Con un defensor en medio no achica.
	var w2: Dictionary = await _keeper_world(Vector3(11.0, 0.11, 1.0))
	var att2: Footballer = add_player(w2["ctx"], 0, Vector3(10.5, 0.0, 1.0), 60)
	(w2["ctx"] as MatchContext).ball.register_touch(att2)
	add_player(w2["ctx"], 1, Vector3(14.5, 0.0, 1.0), 60)
	await wait_seconds(1.5)
	var depth_cov: float = hl - (w2["k"] as Goalkeeper).global_position.x
	note("mano a mano: arquero a %.2f m de su linea; con un defensor en medio, a %.2f m" % [depth_alone, depth_cov])
	check(depth_alone > depth_cov + 0.5, "sale mas lejos cuando el atacante esta solo")
	check(not (w2["k"] as Goalkeeper).rushing, "con cobertura no achica")

func test_keeper_claims_a_high_cross_into_his_area() -> void:
	var w: Dictionary = await _keeper_world(Vector3(13.0, 0.11, 8.0))
	var ctx: MatchContext = w["ctx"]
	var k: Goalkeeper = w["k"]
	if not k.visual.uses_pack:
		skip("sin libreria del pack el arquero no tiene clips de atrapada")
		return
	# El extremo que centro queda lejos de la pelota (si no, su propio toque de conduccion la volveria a frenar).
	var wing: Footballer = add_player(ctx, 0, Vector3(8.0, 0.0, 9.0), 60)
	await physics_frames(5)
	# Centro elevado al segundo palo, cerca de la linea: zona del arquero.
	var target := Vector3(ctx.pitch.config.half_length() - 1.5, 0.0, -0.5)
	var o: Vector3 = ctx.ball.global_position
	var dir: Vector3 = KickModel.flat(target - o).normalized()
	var sp: float = CrossAssist.launch_speed(o, dir, 34.0, KickModel.flat(target - o).length(), 1.8)
	var a: float = deg_to_rad(34.0)
	ctx.ball.kick((dir * cos(a) + Vector3.UP * sin(a)) * sp, Vector3.ZERO, wing)
	var got := false
	for i in 150:
		await tree.physics_frame
		if ctx.ball.holder == k or k.stats.get("cross_claims", 0) > 0:
			got = true
	note("centro al area: salidas %d, atrapadas %d, pelota en manos del arquero: %s" % [k.stats.get("cross_claims", 0), k.stats["catches"], str(ctx.ball.holder == k)])
	note("registro del arquero: %s" % str(k.save_log.slice(-2)))
	check(got, "el arquero sale a por el centro que cae en su zona")
	check(k.stats["catches"] + k.stats["parries"] >= 1, "y la atrapa o la despeja con las manos")

func test_desperate_dive_uses_goalkeeper_miss_and_hands_decide() -> void:
	var w: Dictionary = await _keeper_world(Vector3(12.0, 0.11, 0.0))
	var k: Goalkeeper = w["k"]
	if not k.visual.uses_pack:
		skip("sin libreria del pack")
		return
	# Trayectoria que cruza la linea a 2.2 m a la derecha del arquero dentro de 0.6 s.
	var traj := PackedVector3Array()
	var start: Vector3 = k.global_position + k.forward() * 6.0 + k.right_vec() * 2.2 + Vector3.UP * 0.6
	for i in 40:
		traj.append(start - k.forward() * (float(i) / 30.0) * 10.0)
	var ci: int = 18
	var plan_r: Dictionary = k._plan_miss(traj, ci)
	var traj_l := PackedVector3Array()
	for p in traj:
		traj_l.append(p - k.right_vec() * 4.4)
	var plan_l: Dictionary = k._plan_miss(traj_l, ci)
	note("estirada desesperada: derecha %s, izquierda %s" % [plan_r.get("clip", "-"), plan_l.get("clip", "-")])
	check(plan_r.get("clip", &"") == &"goalkeeper_miss", "a su derecha: goalkeeper_miss")
	check(plan_l.get("clip", &"") == &"goalkeeper_miss_mirror", "a su izquierda: el espejo")

func test_keeper_holds_the_ball_in_the_hands_of_his_idle_clip() -> void:
	var w: Dictionary = await _keeper_world(Vector3(0.0, 0.11, 0.0))
	var ctx: MatchContext = w["ctx"]
	var k: Goalkeeper = w["k"]
	if not k.visual.uses_pack:
		skip("sin libreria del pack")
		return
	ctx.ball.hold(k._anchor, k)
	k._enter_hold()
	await physics_frames(10)
	var hands: Vector3 = KeeperPlanner.path_world_at_body(Goalkeeper.HOLD_IDLE_CLIP, "hands", int(k._hold_clip_time * 30.0), k.global_position, k.yaw)
	note("con la pelota: clip %s, pelota a %.2f m de las manos del clip" % [k.visual.current_action, ctx.ball.global_position.distance_to(hands)])
	check(k.visual.current_action == Goalkeeper.HOLD_IDLE_CLIP, "reposo con la pelota: goalkeeper_idle_2")
	check(ctx.ball.global_position.distance_to(hands) < 0.15, "la pelota va en las manos del clip")

func test_gait_transition_clips_follow_the_real_movement() -> void:
	# Transiciones de la marcha del pack (modo 1); las del modo 4 estan en test_bank_integration.
	Tuning.gameplay_mode = 1
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("sin libreria del pack")
		return
	var ctx: MatchContext = await make_match(Vector3(15.0, 0.11, 9.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-10.0, 0.0, 0.0), 60, src, true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(10)
	var seen := {}
	src.move = Vector2(1, 0)
	src.sprint = true
	for i in 90:
		await tree.physics_frame
		if p.visual.current_action != &"":
			seen[p.visual.current_action] = true
	# Giro a la derecha a toda velocidad (en pantalla sin camara: z+ es "abajo"; a la derecha del rumbo +X es +Z).
	src.move = Vector2(0.6, 0.8)
	for i in 40:
		await tree.physics_frame
		if p.visual.current_action != &"":
			seen[p.visual.current_action] = true
	# Agotado y parado: recupera el aliento.
	src.move = Vector2.ZERO
	src.sprint = false
	p.locomotion.exhausted = true
	p.locomotion.stamina = 0.05
	for i in 90:
		await tree.physics_frame
		if p.visual.current_action != &"":
			seen[p.visual.current_action] = true
		p.locomotion.exhausted = true
	note("clips de transicion vistos: %s" % str(seen.keys()))
	check(seen.has(&"Idle_To_Sprint"), "arranque explosivo desde parado con sprint")
	check(seen.has(&"Sprint_Turn"), "giro a la carrera")
	check(seen.has(&"Running_Tired"), "parada agotado")
	var space: AnimationNodeBlendSpace1D = (p.visual.anim_tree.tree_root as AnimationNodeBlendTree).get_node(&"Locomotion")
	var names: Array = []
	for i in space.get_blend_point_count():
		names.append(String((space.get_blend_point_node(i) as AnimationNodeAnimation).animation))
	check(names.has("pack/Jogging_inplace"), "el trote lento esta en la marcha: %s" % str(names))
