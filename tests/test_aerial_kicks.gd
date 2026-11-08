extends TestCase
## Cabezazos y voleas con los clips del pack: el contacto es el de la cabeza / la punta del pie del clip contra la
## pelota PREDICHA en el aire. Se omite sin la libreria local del pack.

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe assets/animations/pack_clips.res (ver tools/animation_pack/build_pack_library.tscn)")
		return true
	return false

func _lob_to(p_pos: Vector3, ball_target: Vector3, t_arrive: float) -> Vector3:
	# Velocidad que lleva la pelota a ball_target en t_arrive segundos (sin arrastre: aproximacion de la prueba).
	var d: Vector3 = ball_target - Vector3(p_pos.x - 3.0, 0.5, p_pos.z)
	return Vector3(d.x / t_arrive, d.y / t_arrive + 0.5 * 9.81 * t_arrive, d.z / t_arrive)

func test_header_and_volley_contact_happen_when_head_or_foot_reaches_the_flying_ball() -> void:
	if _skip_if_missing():
		return
	var hits := {}
	var tries := 0
	var made := 0
	for target_h in [0.9, 1.2, 1.6, 1.9]:
		var ctx: MatchContext = await make_match(Vector3(0.0, 5.0, 12.0))
		var src := ScriptedInput.new()
		var p: Footballer = add_player(ctx, 0, Vector3(0.0, 0.0, 0.0), 50, src, true)
		p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
		await physics_frames(5)
		var events: Array = []
		ctx.event_emitted.connect(func(e: GameEvent) -> void: events.append(e))
		# La pelota llega en el aire a la altura target_h, justo delante del jugador, en 0.9 s.
		var start := Vector3(-3.5, 0.5, 0.0)
		var goal := Vector3(0.55, target_h, 0.1)
		var t_arr: float = 0.9
		var v := Vector3((goal.x - start.x) / t_arr, (goal.y - start.y) / t_arr + 0.5 * 9.81 * t_arr, (goal.z - start.z) / t_arr)
		ctx.ball.reset_at(start)
		await physics_frames(3)
		ctx.ball.kick(v)
		await wait_seconds(0.25)
		src.hold_shoot()
		await physics_frames(2)
		src.release_shoot()
		await wait_seconds(1.6)
		tries += 1
		var log_entry: Dictionary = p.ball_handler.kick_log.back() if not p.ball_handler.kick_log.is_empty() else {}
		var shot_events: int = events.filter(func(e: GameEvent) -> bool: return e.type == GameEvent.Type.SHOT).size()
		note("pelota a %.1f m: resultado=%s clip=%s pie/cabeza-pelota=%.2f m" % [target_h, log_entry.get("result", "-"), log_entry.get("clip", "-"), log_entry.get("foot_distance", -1.0)])
		if shot_events == 1:
			made += 1
			hits[log_entry.get("clip", "")] = true
		cleanup()
	check(made >= 3, "se conecta la pelota en el aire en al menos 3 de 4 alturas (%d)" % made)
	check(hits.size() >= 2, "segun la altura se eligen clips distintos: %s" % str(hits.keys()))
