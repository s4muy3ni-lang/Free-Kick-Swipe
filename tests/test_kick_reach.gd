extends TestCase
## Golpeo pedido con la pelota fuera del alcance del pie (video del usuario, 58.4 s: TIRO cargado a sprint con la
## pelota 1.2-1.5 m por delante rodando a la misma velocidad que el jugador; el pie nunca llega y el tiro se pierde sin
## aviso). El jugador debe ajustar la carrera hasta poder golpear con contacto real o, si no llega, cancelar con aviso.
## Nunca hay impulso sin contacto del pie.

const START := Vector3(-18.0, 0.0, 0.0)

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("faltan assets/animations/pack_clips.res")
		return true
	return false

## Jugador corriendo hacia +X (joystick `stick`) con la pelota `ahead` m por delante (y `lat` m al costado) rodando a la
## velocidad del jugador por `ball_speed_k`.
func _run_with_ball_ahead(ahead: float, ball_speed_k: float, sprint: bool, stick: float = 1.0, lat: float = 0.0) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(12.0, 0.11, 12.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, START, 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	src.move = Vector2(stick, 0.0)
	src.sprint = sprint
	await wait_seconds(1.6)
	var v: Vector3 = KickModel.flat(p.locomotion.velocity) * ball_speed_k
	ctx.ball.reset_at(p.global_position + p.locomotion.forward() * ahead + p.locomotion.right() * lat + Vector3(0, 0.11, 0))
	await physics_frames(1)
	ctx.ball.kick(v, ctx.ball.rolling_spin(v), p)
	var events: Array = []
	ctx.event_emitted.connect(func(e: GameEvent) -> void: events.append(e))
	# Toques de conduccion dados sin un pie del esqueleto en la pelota hasta el golpeo (impulsos sin contacto visible).
	var no_foot := [0]
	p.ball_handler.touched_ball.connect(func(_k: StringName) -> void:
		if p.ball_handler.last_touch_foot < 0 and p.ball_handler.kick_log.is_empty():
			no_foot[0] += 1)
	return {"ctx": ctx, "p": p, "src": src, "events": events, "speed": p.locomotion.speed, "no_foot": no_foot}

func _types(events: Array, type: int) -> Array:
	return events.filter(func(e: GameEvent) -> bool: return e.type == type)

func _press(src: ScriptedInput, action: StringName, hold_s: float) -> void:
	if action == &"shot":
		src.hold_shoot()
	else:
		src.hold_pass()
	await wait_seconds(hold_s)
	if action == &"shot":
		src.release_shoot()
	else:
		src.release_pass()

func _case(action: StringName, ahead: float, k: float, sprint: bool, hold_s: float, stick: float = 1.0, lat: float = 0.0) -> Dictionary:
	var s: Dictionary = await _run_with_ball_ahead(ahead, k, sprint, stick, lat)
	var p: Footballer = s["p"]
	var speed: float = s["speed"]
	await _press(s["src"], action, hold_s)
	await wait_seconds(1.6)
	var ev: Array = s["events"]
	var kicked: Array = _types(ev, GameEvent.Type.SHOT if action == &"shot" else GameEvent.Type.PASS)
	var whiffs: Array = _types(ev, GameEvent.Type.KICK_WHIFF)
	var log: Array = p.ball_handler.kick_log
	var contact: Array = log.filter(func(e): return e["result"] == &"contact")
	var fd: float = float(contact.back()["foot_distance"]) if not contact.is_empty() else -1.0
	var out := {"kicked": kicked.size(), "whiffs": whiffs.size(), "reason": String(whiffs.back().data.get("reason", "")) if not whiffs.is_empty() else "",
		"contact": contact.size(), "foot": fd, "speed": speed, "no_foot": int(s["no_foot"][0])}
	cleanup()
	return out

func test_kick_requested_with_the_ball_out_of_reach_ahead() -> void:
	if _skip_if_missing():
		return
	var live: bool = DisplayServer.get_name() != "headless"
	# [nombre, accion, delante (m), velocidad de la pelota / jugador, sprint, segundos pulsado, joystick, costado (m)]
	var cases := [
		["tiro a media velocidad, pelota 1.7 m delante y al costado (video 58.4 s)", &"shot", 1.7, 1.0, false, 0.4, 0.7, 0.3],
		["tiro a media velocidad, pelota 1.9 m delante", &"shot", 1.9, 1.0, false, 0.4, 0.8, 0.3],
		["tiro despacio, pelota 2.2 m delante", &"shot", 2.2, 1.0, false, 0.6, 0.5, 0.2],
		["tiro a media velocidad, pelota 2.6 m delante", &"shot", 2.6, 1.0, false, 0.4, 0.7, 0.0],
		["tiro a sprint, pelota 1.4 m delante a la velocidad del jugador", &"shot", 1.4, 1.0, true, 0.35, 1.0, 0.0],
		["pase a sprint, pelota 1.8 m delante", &"pass", 1.8, 1.0, true, 0.2, 1.0, 0.0],
		["pase a la carrera, pelota 1.0 m delante", &"pass", 1.0, 1.0, false, 0.15, 1.0, 0.0],
	]
	var ok := 0
	for c in cases:
		var r: Dictionary = await _case(c[1], float(c[2]), float(c[3]), bool(c[4]), float(c[5]), float(c[6]), float(c[7]))
		note("%s (%.1f m/s): golpeos %d (con contacto %d, pie a %.2f m), cancelaciones %d %s, toques sin pie antes del golpeo %s" % [c[0], r["speed"], r["kicked"], r["contact"], r["foot"], r["whiffs"], r["reason"], str(r["no_foot"]) if live else "n/d (headless)"])
		check(int(r["kicked"]) == int(r["contact"]), "%s: cada golpeo tiene contacto del pie (%d golpeos, %d contactos)" % [c[0], r["kicked"], r["contact"]])
		if int(r["kicked"]) == 1 and float(r["foot"]) <= Tuning.player.kick_contact_radius:
			ok += 1
		if live:
			check(int(r["no_foot"]) == 0, "%s: el jugador llega a la pelota corriendo, sin toques sin pie (%d)" % [c[0], r["no_foot"]])
	note("golpeos con contacto: %d de %d" % [ok, cases.size()])
	check(ok == cases.size(), "el jugador ajusta la carrera y golpea con contacto en todos los casos (%d de %d)" % [ok, cases.size()])

func test_kick_is_cancelled_with_a_warning_when_the_ball_cannot_be_reached() -> void:
	if _skip_if_missing():
		return
	# Pelota propia 2.5 m por delante y escapando a 3.5 veces la velocidad del jugador: no hay carrera que llegue. (Al
	# doble ya si se la alcanza: la rodadura proporcional la frena en ~1 s.)
	var r: Dictionary = await _case(&"shot", 2.5, 3.5, false, 0.3, 0.7, 0.0)
	note("pelota que se escapa a 3.5 veces la velocidad: golpeos %d, cancelaciones %d (%s)" % [r["kicked"], r["whiffs"], r["reason"]])
	check(int(r["kicked"]) == 0, "no hay golpeo sin pie en la pelota (%d)" % r["kicked"])
	check(int(r["whiffs"]) == 1 and String(r["reason"]) == "out_of_reach", "la orden se cancela con aviso out_of_reach (%d, %s)" % [r["whiffs"], r["reason"]])
