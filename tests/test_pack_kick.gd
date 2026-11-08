extends TestCase
## Contacto pie-pelota con los clips del pack: el impulso se aplica cuando el PIE (posicion de contacto medida en el clip)
## llega a la pelota; si la pelota no esta al alcance de ninguna pierna NO hay pase ni tiro ni teletransporte.
## Requiere la libreria local del pack (recurso restringido): sin ella la prueba se omite, no se da por buena.

## Sistema del modo 1 (pack de Mixamo / Tripo), descartado como modo de juego pero todavia en el codigo: se prueba en su modo.
func gameplay_mode() -> int:
	return 1

const START := Vector3(-10.0, 0.0, 0.0)

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe assets/animations/pack_clips.res (generar con tools/animation_pack/build_pack_library.tscn)")
		return true
	return false

## Jugador mirando a +X con visual del pack, parado, y la pelota en reposo en ball_pos.
func _setup(ball_pos: Vector3) -> Dictionary:
	var ctx: MatchContext = await make_match(ball_pos)
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, START, 50, src, true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(10)
	# La pelota se vuelve a poner en su sitio al final de la espera, justo antes del pedido: con el joystick suelto el
	# jugador se acomoda a una pelota al alcance que no tiene delante (BallHandler.settle_steer, 2026-11-05) y la pelota de
	# la prueba (detras, algo lejos del pie) ya no estaba ahi al pedir el golpeo.
	p.place_at(START, Locomotion.yaw_from_dir(Vector3(1, 0, 0)))
	ctx.ball.reset_at(ball_pos)
	await physics_frames(1)
	var events: Array = []
	ctx.event_emitted.connect(func(e: GameEvent) -> void: events.append(e))
	return {"ctx": ctx, "src": src, "p": p, "events": events}

func _events_of(events: Array, type: int) -> Array:
	return events.filter(func(e: GameEvent) -> bool: return e.type == type)

func test_only_in_place_clips_are_connected_to_kicks() -> void:
	if _skip_if_missing():
		return
	var all_ids: Array = []
	for kind in [&"pass", &"shot", &"lob"]:
		var cands: Array = AnimationCatalog.kick_candidates(kind)
		check(cands.size() >= 2, "'%s': hay clip para ambas piernas (%d candidatos)" % [kind, cands.size()])
		for c in cands:
			all_ids.append(c["clip"])
			var m: Dictionary = PackLibrary.meta(c["clip"])
			check((m["root_total"] as Vector2).length() <= AnimationCatalog.ROOT_MAX, "'%s' para %s no desplaza la raiz (%.2f m)" % [c["clip"], kind, (m["root_total"] as Vector2).length()])
	check(not all_ids.has(&"soccer_penalty_kick") and not all_ids.has(&"Chip"), "los clips con carrera (penalti, Chip) quedan sin conectar")

func test_pass_contact_is_synchronised_with_the_foot_arrival() -> void:
	if _skip_if_missing():
		return
	# La pelota esta justo donde el pie derecho de Soccer_Pass golpea.
	var ball_pos: Vector3 = BallHandler.foot_contact_world(PackLibrary.meta(&"Soccer_Pass")["contact"], START, Locomotion.yaw_from_dir(Vector3(1, 0, 0)))
	ball_pos.y = 0.11
	var s: Dictionary = await _setup(ball_pos)
	var p: Footballer = s["p"]
	var src: ScriptedInput = s["src"]
	var ctx: MatchContext = s["ctx"]
	check(p.ball_handler.uses_clip_kicks(), "el futbolista con visual del pack patea con clips")
	src.hold_pass()
	await physics_frames(4)
	src.release_pass()
	var frames := 0
	var started := false
	var moved_at := -1
	for i in 60:
		await tree.physics_frame
		frames += 1
		if p.ball_handler.is_kick_in_progress():
			started = true
		if ctx.ball.ground_speed() > 1.0:
			moved_at = frames
			break
	check(started, "al soltar el boton comienza el balanceo con clip")
	check(moved_at > 0, "la pelota sale tras el golpeo")
	var latency: float = moved_at / 60.0
	var clip_name: String = String(p.ball_handler.kick_log.back().get("clip", "")) if not p.ball_handler.kick_log.is_empty() else ""
	note("pase: latencia boton->salida de pelota %.3f s (objetivo %.2f s), distancia pie-pelota %.3f m, clip '%s'" % [latency, Tuning.player.kick_latency, p.ball_handler.last_foot_distance, clip_name])
	check_range(latency, Tuning.player.kick_latency - 0.04, Tuning.player.kick_latency + 0.08, "la salida de la pelota coincide con la latencia del clip")
	check(p.ball_handler.last_foot_distance >= 0.0 and p.ball_handler.last_foot_distance <= Tuning.player.kick_contact_radius, "el pie esta a %.3f m de la pelota al golpear (<= %.2f)" % [p.ball_handler.last_foot_distance, Tuning.player.kick_contact_radius])
	check(clip_name.begins_with("Soccer_Pass") or clip_name.begins_with("strike_foward"), "se reproduce un clip del pack ('%s'), no uno procedural" % clip_name)
	check(not p.visual.pose_modifier.is_kicking(), "la capa procedural de patada no se superpone al clip")
	var passes: Array = _events_of(s["events"], GameEvent.Type.PASS)
	check(passes.size() == 1, "un unico evento de pase")
	if passes.size() == 1:
		check(String(passes[0].data.get("clip", "")) != "", "el evento de pase registra el clip y la distancia del pie")
	check(p.ball_handler.kick_stats["contact"] == 1 and p.ball_handler.kick_stats["missed"] == 0, "contadores: 1 contacto valido, 0 fallos (%s)" % str(p.ball_handler.kick_stats))
	await wait_seconds(0.8)
	check(p.locomotion.turn_scale == 1.0, "el giro vuelve a ser normal tras la patada")
	check(not p.visual.is_action_playing(), "el clip termina y devuelve el cuerpo a la marcha")

func test_each_candidate_foot_hits_when_the_ball_is_on_it() -> void:
	if _skip_if_missing():
		return
	var yaw: float = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	for kind in [&"pass", &"shot"]:
		for cand in AnimationCatalog.kick_candidates(kind):
			var pos: Vector3 = BallHandler.foot_contact_world(cand["contact"], START, yaw)
			pos.y = 0.11
			var s: Dictionary = await _setup(pos)
			var p: Footballer = s["p"]
			var src: ScriptedInput = s["src"]
			if kind == &"pass":
				src.hold_pass()
				await physics_frames(2)
				src.release_pass()
			else:
				src.hold_shoot()
				await physics_frames(2)
				src.release_shoot()
			await wait_seconds(0.6)
			var hits: Array = _events_of(s["events"], GameEvent.Type.PASS if kind == &"pass" else GameEvent.Type.SHOT)
			check(hits.size() == 1, "%s: con la pelota en el pie de '%s' hay golpeo (eventos=%d, stats=%s)" % [kind, cand["clip"], hits.size(), str(p.ball_handler.kick_stats)])
			cleanup()

func test_ball_out_of_reach_gives_no_kick_and_no_teleport() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(START + Vector3(2.0, 0.11, 0.0))
	var p: Footballer = s["p"]
	var src: ScriptedInput = s["src"]
	var ctx: MatchContext = s["ctx"]
	# La pelota recien colocada se asienta (1 cm) en los primeros pasos.
	await physics_frames(3)
	var before: Vector3 = ctx.ball.global_position
	src.hold_pass()
	await physics_frames(3)
	src.release_pass()
	await wait_seconds(0.6)
	var whiffs: Array = _events_of(s["events"], GameEvent.Type.KICK_WHIFF)
	check(_events_of(s["events"], GameEvent.Type.PASS).is_empty(), "no hay pase automatico con la pelota a 2 m")
	check(whiffs.size() == 1 and whiffs[0].data.get("reason", "") == "out_of_reach", "se registra UNA pulsacion fuera de alcance (%d)" % whiffs.size())
	check(p.ball_handler.kick_stats["started"] == 0 and p.ball_handler.kick_stats["out_of_reach"] == 1, "contadores: %s" % str(p.ball_handler.kick_stats))
	check(not p.visual.is_action_playing(), "no se reproduce ninguna patada")
	check(ctx.ball.global_position.distance_to(before) < 0.01 and ctx.ball.ground_speed() < 0.05, "la pelota ni se mueve ni se coloca (desplazamiento %.3f m)" % ctx.ball.global_position.distance_to(before))

func test_ball_leaving_during_the_swing_is_a_real_whiff() -> void:
	if _skip_if_missing():
		return
	var pos: Vector3 = BallHandler.foot_contact_world(PackLibrary.meta(&"Soccer_Pass")["contact"], START, Locomotion.yaw_from_dir(Vector3(1, 0, 0)))
	pos.y = 0.11
	var s: Dictionary = await _setup(pos)
	var p: Footballer = s["p"]
	var src: ScriptedInput = s["src"]
	var ctx: MatchContext = s["ctx"]
	src.hold_pass()
	await physics_frames(2)
	src.release_pass()
	await physics_frames(3)
	check(p.ball_handler.is_kick_in_progress(), "el balanceo esta en curso")
	var far := Vector3(-6.0, 0.11, 3.0)
	ctx.ball.reset_at(far)   # alguien se la lleva
	await wait_seconds(0.6)
	var whiffs: Array = _events_of(s["events"], GameEvent.Type.KICK_WHIFF)
	check(whiffs.size() == 1 and whiffs[0].data.get("reason", "") == "missed", "patada en falso registrada (%d)" % whiffs.size())
	check(_events_of(s["events"], GameEvent.Type.PASS).is_empty(), "no se emite un pase")
	check(ctx.ball.global_position.distance_to(far) < 0.05 and ctx.ball.ground_speed() < 0.05, "la pelota no recibe impulso ni se mueve")
	check(p.ball_handler.kick_stats["missed"] == 1 and p.ball_handler.kick_stats["contact"] == 0, "contadores: %s" % str(p.ball_handler.kick_stats))

func test_reach_is_limited_by_the_leg_not_a_fixed_radius() -> void:
	if _skip_if_missing():
		return
	# Detras del jugador ninguna pierna llega (el alcance antiguo, 1.25 m a la redonda, si aceptaba esta pelota).
	var s: Dictionary = await _setup(START + Vector3(-0.9, 0.11, 0.0))
	var p: Footballer = s["p"]
	var src: ScriptedInput = s["src"]
	src.hold_pass()
	await physics_frames(2)
	src.release_pass()
	await wait_seconds(0.8)
	check(_events_of(s["events"], GameEvent.Type.PASS).is_empty() and p.ball_handler.kick_stats["out_of_reach"] == 1, "pelota a 0.9 m por detras: sin pase (%s)" % str(p.ball_handler.kick_stats))
	cleanup()
	# Y mas lejos de lo que alcanza ni el pie ni un toque de preparacion: tampoco.
	var s2: Dictionary = await _setup(START + Vector3(2.2, 0.11, 0.0))
	s2["src"].hold_shoot()
	await physics_frames(2)
	s2["src"].release_shoot()
	await wait_seconds(0.8)
	check(_events_of(s2["events"], GameEvent.Type.SHOT).is_empty(), "pelota a 2.2 m delante: sin tiro")
	cleanup()
	# A media distancia SI se adapta: el jugador va hasta la pelota (no hay toque a distancia que la traiga, conduccion
	# fisica desde 2026-11-05) y tira con el pie en la pelota.
	var s3: Dictionary = await _setup(START + Vector3(1.3, 0.11, 0.0))
	var p3: Footballer = s3["p"]
	var x0: float = p3.global_position.x
	s3["src"].hold_shoot()
	await physics_frames(2)
	s3["src"].release_shoot()
	await wait_seconds(1.2)
	note("pelota a 1.3 m: el jugador avanzo %.2f m, toques=%d, golpeos %s, pie-pelota %.3f m" % [p3.global_position.x - x0, p3.ball_handler.dribble_touch_count, str(p3.ball_handler.kick_stats), p3.ball_handler.last_foot_distance])
	check(p3.global_position.x - x0 > 0.3, "la pelota a 1.3 m: el jugador va hasta ella")
	check(not _events_of(s3["events"], GameEvent.Type.SHOT).is_empty(), "y despues el tiro se ejecuta")
	check(int(p3.ball_handler.kick_stats["missed"]) == 0, "con el pie en la pelota (sin patada en falso)")

func test_stride_adjustment_reaches_a_ball_slightly_off_the_foot() -> void:
	if _skip_if_missing():
		return
	# La pelota queda 0.25 m por delante del punto mas adelantado que alcanza algun pie en un golpeo valido.
	var far_pos := Vector3(-9.0, 0.0, 0.0)
	var far_x := -INF
	var yaw: float = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	for cand in AnimationCatalog.kick_candidates(&"pass"):
		for smp in BallHandler.contact_samples(cand["contact"]):
			if (smp["pos"] as Vector3).x > far_x:
				far_x = (smp["pos"] as Vector3).x
				far_pos = BallHandler.foot_contact_world({"pos": smp["pos"]}, START, yaw)
	var pos: Vector3 = far_pos + Vector3(0.25, 0.0, 0.0)
	pos.y = 0.11
	var s: Dictionary = await _setup(pos)
	var p: Footballer = s["p"]
	var src: ScriptedInput = s["src"]
	var body_before: Vector3 = p.global_position
	src.hold_pass()
	await physics_frames(2)
	src.release_pass()
	await wait_seconds(0.5)
	var log_entry: Dictionary = p.ball_handler.kick_log.back() if not p.ball_handler.kick_log.is_empty() else {}
	note("ajuste de zancada: %.2f m (maximo parado %.2f m), pie-pelota al golpear %.3f m, desplazamiento del cuerpo %.2f m, clip '%s'" % [log_entry.get("adjust_m", -1.0), Tuning.player.kick_adjust_max, log_entry.get("foot_distance", -1.0), p.global_position.distance_to(body_before), log_entry.get("clip", "")])
	check(log_entry.get("result", &"") == &"contact", "con el ajuste el pie llega y hay golpeo (%s)" % str(p.ball_handler.kick_stats))
	check(float(log_entry.get("adjust_m", 0.0)) > 0.1 and float(log_entry.get("adjust_m", 0.0)) <= Tuning.player.kick_adjust_max + 0.001, "el ajuste esta dentro de kick_adjust_max")
	check(p.global_position.distance_to(body_before) < 0.45, "el cuerpo no se desliza mas de lo que dice el ajuste")
	check(p.nudge_velocity == Vector3.ZERO and p.locomotion.speed < 0.3, "el ajuste no contamina la velocidad de la locomocion (v=%.2f)" % p.locomotion.speed)

func test_contact_instant_comes_from_the_foot_trajectory() -> void:
	if _skip_if_missing():
		return
	for cand in AnimationCatalog.kick_candidates(&"pass"):
		var c: Dictionary = cand["contact"]
		var samples: Array = BallHandler.contact_samples(c)
		check(samples.size() >= 3, "'%s': la ventana de golpeo tiene varios puntos validos (%d)" % [cand["clip"], samples.size()])
		var lo := INF
		var hi := -INF
		for smp in samples:
			check((smp["pos"] as Vector3).y <= Tuning.player.kick_foot_max_height + 0.001, "'%s' t=%.3f: punta baja (%.2f m)" % [cand["clip"], smp["time"], (smp["pos"] as Vector3).y])
			lo = minf(lo, float(smp["time"]))
			hi = maxf(hi, float(smp["time"]))
		check(lo <= float(c["time"]) + 0.001 and hi >= float(c["time"]) - 0.04, "'%s': la ventana [%.3f, %.3f] rodea el contacto medido %.3f" % [cand["clip"], lo, hi, c["time"]])
	# Dos pelotas en sitios distintos dan instantes de contacto distintos para el mismo clip.
	var yaw: float = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var times: Array[float] = []
	for fwd in [0.05, 0.5]:
		var s: Dictionary = await _setup(START + Vector3(fwd, 0.11, 0.0) + Locomotion.dir_from_yaw(yaw + PI * 0.5).normalized() * 0.0)
		var plan: Dictionary = s["p"].ball_handler.plan_clip_kick(&"shot", 0.0, false)
		if not plan.is_empty():
			times.append(float(plan["contact"]["time"]))
		cleanup()
	note("instantes de contacto elegidos para pelota a 0.05 m y 0.5 m delante: %s" % str(times))
	check(times.size() == 2 and not is_equal_approx(times[0], times[1]), "el instante de contacto depende de donde esta la pelota")
