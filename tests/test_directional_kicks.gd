extends TestCase
## Golpeos hacia cualquier direccion con los clips del banco (modo 4): para un companero (pase) o el arco (tiro) a 0, 45,
## 90, 135 y 180 grados del frente, parado y al trote, que clip se usa (rol `kick_pass*` / `kick_shot*` de frente,
## `kick_turn` / `kick_back` girando o de taco, o giro con pelota `ball_turn` y despues golpeo), si el pie llega a la pelota y
## si la pelota sale hacia el destino. Con render (el pie animado decide el contacto).

func _needs_render() -> bool:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return true
	return false

## Juega un golpeo hacia `ang` grados (+ izquierda) del frente del jugador y devuelve que paso.
func _kick_to(action: StringName, ang: float, jog: bool) -> Dictionary:
	var start := Vector3(-6.0, 0.0, 0.0)
	var fwd := Vector3(1, 0, 0)
	var ctx: MatchContext = await make_match(start + fwd * 0.55 + Vector3(0, 0.11, 0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, start, 65, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(fwd)
	# yaw 0 mira a -Z: "izquierda" del jugador que mira a +X es -Z.
	var dir: Vector3 = fwd.rotated(Vector3.UP, deg_to_rad(ang))
	var target: Vector3
	if action == &"pass":
		var mate: Footballer = add_player(ctx, 0, start + dir * 9.0, 60, null, false)
		target = mate.global_position
	else:
		# Tiro: el jugador a 12 m del arco, orientado de modo que el arco quede a `ang` grados de su frente.
		var hl: float = ctx.pitch.config.half_length()
		var goal_c := Vector3(hl, 0.0, 0.0)
		var spot := Vector3(hl - 12.0, 0.0, 0.0)
		var facing: Vector3 = Vector3(1, 0, 0).rotated(Vector3.UP, -deg_to_rad(ang))
		p.place_at(spot, Locomotion.yaw_from_dir(facing))
		ctx.ball.reset_at(spot + facing * 0.55 + Vector3(0, 0.11, 0))
		fwd = facing
		target = goal_c
	ctx.ball.register_touch(p)
	if jog:
		src.move = Vector2(fwd.x, fwd.z) * 0.55
		await wait_seconds(1.0)
	else:
		await physics_frames(20)
	var st := {"t": -1.0, "clip": "", "fwd": Vector3.ZERO, "moves": [], "frames": 0}
	ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if (e.type == GameEvent.Type.PASS or e.type == GameEvent.Type.SHOT) and float(st["t"]) < 0.0:
			st["t"] = int(st["frames"]) / 60.0
			st["clip"] = String(e.data.get("clip", ""))
			st["fwd"] = p.locomotion.forward()
			st["shot_dir"] = e.data.get("dir", []))
	# El joystick apunta al destino al soltar (como haria la persona).
	var to_t: Vector3 = KickModel.flat(target - p.global_position).normalized()
	var stick := Vector2(to_t.x, to_t.z)
	if action == &"pass":
		src.hold_pass()
	else:
		src.hold_shoot()
	src.move = stick
	await physics_frames(8)
	if action == &"pass":
		src.release_pass()
	else:
		src.release_shoot()
	var ball_dir := Vector3.ZERO
	for i in 240:
		await tree.physics_frame
		st["frames"] = int(st["frames"]) + 1
		if p.ball_handler.json_move != null and p.ball_handler.json_move.active and not (st["moves"] as Array).has(String(p.ball_handler.json_move.clip)):
			(st["moves"] as Array).append(String(p.ball_handler.json_move.clip))
		if float(st["t"]) >= 0.0 and ball_dir == Vector3.ZERO and int(st["frames"]) > int(float(st["t"]) * 60.0) + 3:
			ball_dir = KickModel.flat(ctx.ball.linear_velocity).normalized()
		if ball_dir != Vector3.ZERO and int(st["frames"]) > int(float(st["t"]) * 60.0) + 6:
			break
	src.move = Vector2.ZERO
	var role: String = String(PackLibrary.meta(StringName(st["clip"])).get("role", "")) if String(st["clip"]) != "" else ""
	var out := {"kicked": float(st["t"]) >= 0.0, "t": st["t"], "clip": st["clip"], "role": role, "moves": st["moves"],
		"err": KickModel.angle_between_deg(ball_dir, KickModel.flat(target - ctx.ball.global_position)) if ball_dir != Vector3.ZERO else 999.0,
		"body_vs_ball": KickModel.angle_between_deg(st["fwd"], ball_dir) if ball_dir != Vector3.ZERO else 999.0,
		"stats": p.ball_handler.kick_stats.duplicate(), "shot_dir": st.get("shot_dir", [])}
	cleanup()
	return out

func _run(action: StringName, jog: bool) -> Dictionary:
	var ok := 0
	var clip_based := 0
	var total := 0
	var rows: Array = []
	for ang in [0.0, 45.0, -90.0, 135.0, 180.0]:
		var r: Dictionary = await _kick_to(action, ang, jog)
		total += 1
		var good: bool = r["kicked"] and float(r["err"]) < 30.0 and int(r["stats"].get("missed", 0)) == 0
		if good:
			ok += 1
		var turned: bool = not (r["moves"] as Array).is_empty()
		# Hasta 90 grados vale un pase de interior de frente o un golpeo girando; desde 135, golpeo girando / taco o giro con
		# pelota y despues golpeo (nunca un balanceo de frente que mande la pelota atras).
		if String(r["role"]).begins_with("kick_turn") or String(r["role"]).begins_with("kick_back") or turned or absf(ang) <= 90.0:
			clip_based += 1
		rows.append("%s %s a %4.0f grados: %s a los %.2f s, clip %s (%s)%s, error %.0f grados, cuerpo-pelota %.0f grados, %s %s" % [
			action, "trote" if jog else "parado", ang, "golpea" if r["kicked"] else "SIN golpeo", r["t"], r["clip"], r["role"],
			(" tras giro con pelota %s" % str(r["moves"])) if turned else "", r["err"], r["body_vs_ball"], str(r["stats"]), str(r["shot_dir"])])
	for l in rows:
		note(l)
	return {"ok": ok, "total": total, "clip_based": clip_based}

func test_passes_in_every_direction() -> void:
	if _needs_render():
		return
	for jog in [false, true]:
		var r: Dictionary = await _run(&"pass", jog)
		check(int(r["ok"]) >= int(r["total"]) - 1, "pase %s: sale hacia el companero con el pie en la pelota (%d de %d)" % ["al trote" if jog else "parado", r["ok"], r["total"]])
		check(int(r["clip_based"]) == int(r["total"]), "pase %s: hacia atras con un clip girando / taco o tras un giro con pelota (%d de %d)" % ["al trote" if jog else "parado", r["clip_based"], r["total"]])

func test_shots_in_every_direction() -> void:
	if _needs_render():
		return
	for jog in [false, true]:
		var r: Dictionary = await _run(&"shot", jog)
		check(int(r["ok"]) >= int(r["total"]) - 1, "tiro %s: sale hacia el arco con el pie en la pelota (%d de %d)" % ["al trote" if jog else "parado", r["ok"], r["total"]])

## Centro desde la banda: el jugador corre hacia la linea de fondo por la derecha y centra al area (a ~90 grados de su
## frente); clip usado (centro del banco, vaselina, pase o golpeo girando) y si la pelota cae en la zona del area.
func test_crosses_from_the_wing() -> void:
	if _needs_render():
		return
	var hits := 0
	var rows: Array = []
	for cfg in [[0.0, false], [0.55, true], [0.85, true]]:
		var hl: float = 20.0
		var hw: float = 10.0
		var start := Vector3(hl - 7.0, 0.0, hw - 2.0)
		var fwd := Vector3(1, 0, 0)
		var ctx: MatchContext = await make_match(start + fwd * 0.55 + Vector3(0, 0.11, 0))
		var src := ScriptedInput.new()
		var p: Footballer = add_player(ctx, 0, start, 65, src, true)
		p.is_human_controlled = true
		p.locomotion.yaw = Locomotion.yaw_from_dir(fwd)
		var mate: Footballer = add_player(ctx, 0, Vector3(hl - 5.0, 0.0, 0.0), 60, null, false)
		ctx.ball.register_touch(p)
		if bool(cfg[1]):
			src.move = Vector2(float(cfg[0]), 0.0)
			await wait_seconds(0.8)
		else:
			await physics_frames(20)
		var st := {"clip": "", "t": -1.0}
		ctx.event_emitted.connect(func(e: GameEvent) -> void:
			if e.type == GameEvent.Type.PASS and String(st["clip"]) == "":
				st["clip"] = String(e.data.get("clip", "-")))
		src.move = Vector2(0.0, -1.0)
		src.hold_cross()
		await physics_frames(20)
		src.release_cross()
		var land := Vector3.INF
		var kicked_at := -1
		for i in 240:
			await tree.physics_frame
			if String(st["clip"]) != "" and kicked_at < 0:
				kicked_at = i
			if kicked_at >= 0 and i > kicked_at + 5 and ctx.ball.global_position.y < 0.3 and land == Vector3.INF:
				land = ctx.ball.global_position
		var role: String = String(PackLibrary.meta(StringName(st["clip"])).get("role", "")) if String(st["clip"]) not in ["", "-"] else ""
		var near_box: bool = land != Vector3.INF and land.distance_to(mate.global_position) < 6.0
		if near_box:
			hits += 1
		rows.append("centro (%s): clip %s (%s), cae en %s, %s" % ["parado" if not bool(cfg[1]) else "carrera %.2f" % float(cfg[0]), st["clip"], role, str(land), str(p.ball_handler.kick_stats)])
		cleanup()
	for l in rows:
		note(l)
	check(hits >= 2, "los centros caen en el area (%d de 3)" % hits)
