extends TestCase
## Sincronia cuerpo-pelota: el impulso se aplica en el instante de contacto de la patada.
## Estas pruebas cubren el camino PROCEDURAL (Tripo): fuerzan la ruta sin pack. La patada con clips esta en test_pack_kick.gd.

func _legacy(on: bool) -> void:
	FootballerVisual.prefer_pack = not on
	BallHandler.clip_kicks_enabled = not on

func test_ball_impulse_happens_at_contact_not_at_button_release() -> void:
	_legacy(true)
	var ctx: MatchContext = await make_match(Vector3(-9.45, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-10.0, 0.0, 0.0), 50, src, true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(10)
	var events: Array = []
	ctx.event_emitted.connect(func(e: GameEvent) -> void: events.append(e))
	src.move = Vector2(1, 0) * 0.0
	src.hold_pass()
	await physics_frames(6)
	src.release_pass()
	await physics_frames(1)   # el boton se libera: comienza la patada
	var started_frame: int = 0
	var v_start: float = ctx.ball.ground_speed()
	check(p.ball_handler.is_kick_in_progress(), "al soltar se inicia la patada (animacion en curso)")
	check(p.visual.pose_modifier.is_kicking(), "el modificador procedural esta pateando")
	check(v_start < 0.5, "la pelota aun no se movio al inicio de la patada (v=%.2f)" % v_start)
	var frames_to_contact: int = 0
	for i in 40:
		await tree.physics_frame
		frames_to_contact += 1
		if ctx.ball.ground_speed() > 1.0:
			break
	var contact_s: float = frames_to_contact / 60.0
	note("tiempo entre el inicio de la patada y el movimiento de la pelota: %.3f s (contacto programado: %.3f s)" % [contact_s, p.ball_handler.contact_delay(&"pass", 0.1)])
	check_range(contact_s, 0.05, 0.2, "el impulso llega en la ventana de contacto")
	var pass_events: int = 0
	for e in events:
		if e.type == GameEvent.Type.PASS:
			pass_events += 1
	check(pass_events == 1, "un unico evento de pase")
	check(p.visual.pose_modifier.is_kicking(), "la continuacion del movimiento sigue tras el contacto")
	await wait_seconds(0.8)
	check(not p.visual.pose_modifier.is_kicking(), "la patada termina y se recupera la postura")

func test_kick_whiffs_if_the_ball_moves_away_during_the_swing() -> void:
	_legacy(true)
	var ctx: MatchContext = await make_match(Vector3(-9.45, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-10.0, 0.0, 0.0), 50, src, true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(10)
	var events: Array = []
	ctx.event_emitted.connect(func(e: GameEvent) -> void: events.append(e))
	src.hold_pass()
	await physics_frames(3)
	src.release_pass()
	await physics_frames(2)
	ctx.ball.reset_at(Vector3(-4.0, 0.11, 3.0))   # alguien se la lleva durante el balanceo
	await wait_seconds(0.6)
	var whiffs: int = 0
	var passes: int = 0
	for e in events:
		if e.type == GameEvent.Type.KICK_WHIFF:
			whiffs += 1
		elif e.type == GameEvent.Type.PASS:
			passes += 1
	check(whiffs == 1 and passes == 0, "patada en falso: whiff=%d pases=%d" % [whiffs, passes])
	check(ctx.ball.ground_speed() < 0.5, "la pelota no recibe impulso")

func test_pose_curves_are_continuous_and_peak_at_contact() -> void:
	var contact: float = 0.12
	var prev: Dictionary = ProceduralPose.kick_angles(0.0, contact, 0.8)
	var steps: int = 600
	var total: float = contact + ProceduralPose.FOLLOW_THROUGH + ProceduralPose.RECOVERY
	var dt: float = total / steps
	var max_speed: float = 0.0
	var max_jump: float = 0.0
	var min_hip: float = 0.0
	var t_min: float = 0.0
	for i in range(1, steps + 1):
		var t: float = total * float(i) / steps
		var a: Dictionary = ProceduralPose.kick_angles(t, contact, 0.8)
		var step: float = absf(a["hip"] - prev["hip"])
		max_jump = maxf(max_jump, step)
		max_speed = maxf(max_speed, step / dt)
		if a["hip"] < min_hip:
			min_hip = a["hip"]
			t_min = t
		prev = a
	note("balanceo maximo hacia atras: %.2f rad en t=%.3f s; velocidad angular maxima de cadera: %.1f rad/s; salto maximo por muestra (%.1f ms): %.3f rad" % [min_hip, t_min, max_speed, dt * 1000.0, max_jump])
	check(max_jump < 0.06, "la curva de la cadera es continua (salto max %.3f rad por muestra)" % max_jump)
	# Cota anti-salto (no un objetivo de calidad). El valor medido (~50 rad/s, fase de golpeo de ~46 ms,
	# unos 3 fotogramas a 60 Hz) queda documentado como limitacion en docs/technical-index/SYSTEMS/ANIMATIONS.md.
	check(max_speed < 60.0, "la velocidad angular de cadera no es un salto (%.1f rad/s)" % max_speed)
	check(t_min < contact, "el balanceo hacia atras ocurre antes del contacto")
	var at_contact: Dictionary = ProceduralPose.kick_angles(contact, contact, 0.8)
	check(at_contact["hip"] > 0.1, "en el contacto la pierna va hacia adelante (%.2f rad)" % at_contact["hip"])
	check_near(ProceduralPose.envelope(0.0, contact), 0.0, 0.001, "empieza sin afectar la animacion base")
	check_near(ProceduralPose.envelope(total, contact), 0.0, 0.001, "termina devolviendo el control a la animacion base")
