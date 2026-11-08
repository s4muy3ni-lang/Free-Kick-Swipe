extends TestCase
## El clip de pelotazo en la cara nace de una colision real, no de un evento de prueba fabricado.

func test_a_real_ball_collision_at_face_height_invokes_the_face_reaction() -> void:
	var ctx: MatchContext = await make_match(Vector3(1.4, 1.6, 0))
	var p: Footballer = add_player(ctx, 0, Vector3.ZERO, 60, ScriptedInput.new(), true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3.RIGHT)
	p.rotation.y = p.locomotion.yaw
	# Fixture inmovil: la recepcion automatica no esquiva el impacto que esta prueba necesita producir.
	p.set_physics_process(false)
	await physics_frames(3)
	ctx.ball.kick(Vector3(-8, 0, 0))
	for frame in 45:
		await tree.physics_frame
		if p.actions.stats.get("ball_face_reactions", 0) > 0:
			break
	check(p.actions.stats.get("ball_face_reactions", 0) == 1, "la colision produce la reaccion de cara una vez")
	check(p.visual.current_action == &"jn_nis_misc_0450", "se invoca el clip del pelotazo")
	check(p.arbiter.level == ActionArbiter.Level.BODY, "la reaccion usa el arbitro existente")
	p.actions.stop("fin de prueba")
	ctx.ball.reset_at(Vector3(0.3, 0.11, 0))
	await physics_frames(2)
	check(not p.actions.react_to_ball_impact(ctx.ball), "una pelota a ras del piso no genera una reaccion de cara")
