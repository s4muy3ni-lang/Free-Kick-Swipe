extends TestCase
## Patadas con el esqueleto ANIMADO (render): en cada golpeo se mide, sobre los huesos reales, que
##  1) la punta del pie esta en la pelota en el instante del impulso (no antes ni despues),
##  2) la pelota no sale antes del contacto (su velocidad no cambia hasta el fotograma del impulso),
##  3) la pelota sale hacia donde mira el cuerpo / el objetivo (sin cambios de direccion sin causa),
##  4) el pie de apoyo esta plantado y no patina durante el golpeo.
## Casos: pase parado (pelota a la derecha y a la izquierda: cada pie), pase en carrera, pase largo, tiros de varias
## potencias y angulos, pase de primera. Necesita render (xvfb-run --rendering-driver opengl3); en headless se omite.

const START := Vector3(-10.0, 0.0, 0.0)

func _needs_render() -> bool:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return true
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe la libreria del pack")
		return true
	return false

## Ejecuta un golpeo y devuelve las medidas. setup: Callable(ctx, player, src) que coloca pelota y jugador;
## action: &"pass" / &"shot"; charge_frames: fotogramas con el boton pulsado; stick: Vector2 de la persona.
func _kick(setup: Callable, action: StringName, charge_frames: int, stick: Vector2, move_frames: int = 0) -> Dictionary:
	# LIVE_KICKS_MODE=2 mide los mismos golpeos con el modo 2 de jugabilidad (clips del mocap de futbol).
	if OS.get_environment("LIVE_KICKS_MODE") != "":
		Tuning.gameplay_mode = int(OS.get_environment("LIVE_KICKS_MODE"))
	var ctx: MatchContext = await make_match(START + Vector3(0.5, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, START, 60, src, true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	p.is_human_controlled = true
	await physics_frames(10)
	await setup.call(ctx, p, src)
	var sk: Skeleton3D = p.visual.skeleton
	var toes: Array[int] = [sk.find_bone("mixamorig_LeftToeBase"), sk.find_bone("mixamorig_RightToeBase")]
	var ev := {"frame": -1, "ball": Vector3.ZERO, "data": {}}
	ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if (e.type == GameEvent.Type.PASS or e.type == GameEvent.Type.SHOT) and ev["frame"] < 0:
			ev["frame"] = Engine.get_physics_frames()
			ev["ball"] = ctx.ball.global_position
			ev["data"] = e.data)
	src.move = stick
	if action == &"pass":
		src.hold_pass()
	else:
		src.hold_shoot()
	await physics_frames(maxi(charge_frames, 1))
	if action == &"pass":
		src.release_pass()
	else:
		src.release_shoot()
	var hist: Array = []
	for i in 80:
		await tree.physics_frame
		hist.append({"f": Engine.get_physics_frames(), "toe": [sk.global_transform * sk.get_bone_global_pose(toes[0]).origin, sk.global_transform * sk.get_bone_global_pose(toes[1]).origin],
			"ball": ctx.ball.global_position, "bv": ctx.ball.linear_velocity, "fwd": p.locomotion.forward(), "speed": p.locomotion.speed})
	var out := {"kicked": ev["frame"] >= 0}
	if ev["frame"] < 0:
		cleanup()
		return out
	var ef: int = ev["frame"]
	var best: float = INF
	var foot: int = -1
	for h in hist:
		if absi(int(h["f"]) - ef) <= 2:
			for k in 2:
				var d: float = (h["toe"][k] as Vector3).distance_to(ev["ball"])
				if d < best:
					best = d
					foot = k
	# Velocidad de la pelota antes del impulso (no debe haber salido antes) y direccion de salida.
	var before_speed: float = 0.0
	var out_dir := Vector3.ZERO
	var fwd := Vector3.ZERO
	var support_slide: float = 0.0
	var slides: Array = []
	for i in hist.size():
		var h: Dictionary = hist[i]
		var fr: int = h["f"]
		if fr <= ef:
			before_speed = maxf(before_speed, Vector2(h["bv"].x, h["bv"].z).length())
		if fr == ef:
			fwd = h["fwd"]
		if fr == ef + 3:
			out_dir = KickModel.flat(h["bv"]).normalized()
		# Pie de apoyo (el otro): cuanto se desliza en el suelo en los 3 fotogramas (50 ms) antes del contacto, cuando el
		# clip lo tiene plantado (BallHandler.KICK_PLANT_TIME). La muestra f se toma al empezar el fotograma f (estado tras
		# el f-1): las de ef-2..ef son los fotogramas ef-3..ef-1.
		if foot >= 0 and fr >= ef - 2 and fr <= ef and i > 0:
			var s: Vector3 = h["toe"][1 - foot]
			var s0: Vector3 = hist[i - 1]["toe"][1 - foot]
			slides.append("%.1f" % (Vector2(s.x - s0.x, s.z - s0.z).length() * 60.0))
			if s.y < 0.12:
				support_slide = maxf(support_slide, Vector2(s.x - s0.x, s.z - s0.z).length() * 60.0)
	out["toe_dist"] = best
	out["foot"] = "izq" if foot == 0 else "der"
	out["before_speed"] = before_speed
	out["dir_vs_body"] = KickModel.angle_between_deg(fwd, out_dir)
	out["support_slide"] = support_slide
	out["slides"] = slides
	out["clip"] = String(ev["data"].get("clip", "procedural"))
	cleanup()
	return out

func _report(name: String, r: Dictionary) -> void:
	if not r["kicked"]:
		note("%s: SIN golpeo" % name)
		return
	note("%s: clip %s, pie %s, punta del pie a %.3f m de la pelota en el impulso, pelota antes %.2f m/s, sale a %.0f grados del cuerpo, pie de apoyo desliza %.2f m/s (por fotograma: %s)" % [
		name, r["clip"], r["foot"], r["toe_dist"], r["before_speed"], r["dir_vs_body"], r["support_slide"], str(r["slides"])])

func _check_kick(name: String, r: Dictionary, max_angle: float = 40.0) -> void:
	check(r["kicked"], "%s: hay golpeo" % name)
	if not r["kicked"]:
		return
	check(r["toe_dist"] <= Tuning.player.kick_contact_radius, "%s: la punta del pie toca la pelota en el impulso (%.3f m)" % [name, r["toe_dist"]])
	check(r["dir_vs_body"] <= max_angle, "%s: sale hacia donde mira el cuerpo (%.0f grados)" % [name, r["dir_vs_body"]])
	check(r["support_slide"] <= 1.6, "%s: el pie de apoyo no patina en el golpeo (%.2f m/s)" % [name, r["support_slide"]])

func test_passes_standing_with_each_foot_long_and_running() -> void:
	if _needs_render():
		return
	var right := func(ctx: MatchContext, p: Footballer, _s: ScriptedInput) -> void:
		ctx.ball.reset_at(START + Vector3(0.45, 0.11, 0.18))
		await physics_frames(5)
	var left := func(ctx: MatchContext, p: Footballer, _s: ScriptedInput) -> void:
		ctx.ball.reset_at(START + Vector3(0.45, 0.11, -0.18))
		await physics_frames(5)
	var running := func(ctx: MatchContext, p: Footballer, s: ScriptedInput) -> void:
		ctx.ball.reset_at(START + Vector3(0.5, 0.11, 0.0))
		s.move = Vector2(0.8, 0.0)
		await wait_seconds(1.5)
	var r1: Dictionary = await _kick(right, &"pass", 8, Vector2(1, 0))
	_report("pase parado, pelota a la derecha", r1)
	_check_kick("pase parado derecha", r1)
	var r2: Dictionary = await _kick(left, &"pass", 8, Vector2(1, 0))
	_report("pase parado, pelota a la izquierda", r2)
	_check_kick("pase parado izquierda", r2)
	var r3: Dictionary = await _kick(right, &"pass", 45, Vector2(1, 0))
	_report("pase largo", r3)
	_check_kick("pase largo", r3)
	var r4: Dictionary = await _kick(running, &"pass", 8, Vector2(0.8, 0))
	_report("pase en carrera", r4)
	_check_kick("pase en carrera", r4)
	check(r1["kicked"] and r2["kicked"] and r1["foot"] != r2["foot"], "se patea con el pie del lado de la pelota (der: %s, izq: %s)" % [r1.get("foot", "-"), r2.get("foot", "-")])

func test_shots_of_different_power_and_angle() -> void:
	if _needs_render():
		return
	var setup := func(ctx: MatchContext, p: Footballer, _s: ScriptedInput) -> void:
		ctx.ball.reset_at(START + Vector3(0.45, 0.11, 0.1))
		await physics_frames(5)
	for cfg in [["tiro suave", 4, Vector2(1, 0)], ["tiro medio", 30, Vector2(1, 0)], ["tiro potente", 55, Vector2(1, 0)],
			["tiro cruzado izquierda", 30, Vector2(1, -0.5).normalized()], ["tiro cruzado derecha", 30, Vector2(1, 0.5).normalized()]]:
		var r: Dictionary = await _kick(setup, &"shot", cfg[1], cfg[2])
		_report(cfg[0], r)
		_check_kick(cfg[0], r, 45.0)

func test_first_time_pass_from_an_incoming_ball() -> void:
	if _needs_render():
		return
	var incoming := func(ctx: MatchContext, p: Footballer, _s: ScriptedInput) -> void:
		# Llega a 5 m/s: con la rodadura de la pelota (Ball.roll_*) sale mas rapido para recorrer los ~3.5 m.
		ctx.ball.reset_at(START + Vector3(4.0, 0.11, 0.2), Vector3(-KickModel.ground_speed_for_distance(3.5, 5.0), 0.0, 0.0))
		await physics_frames(2)
	var r: Dictionary = await _kick(incoming, &"pass", 4, Vector2(0, -1))
	_report("pase de primera (pelota que llega a 5 m/s)", r)
	_check_kick("pase de primera", r, 120.0)

# --- Bateria de golpeos: 50 acciones variadas ---------------------------------------------------------------------

## Ejecuta UNA accion de la bateria y devuelve lo medido sobre el esqueleto animado. cfg:
##  ball: offset de la pelota respecto al jugador (x adelante, z derecha), vel: velocidad de la pelota (mundo),
##  y: altura, run: segundos conduciendo antes, turn: joystick al pulsar (Vector2), action, charge (fotogramas),
##  defender: true = un rival presiona, weak: true = pie habil izquierdo (la pelota a su derecha obliga al otro pie).
func _battery_case(cfg: Dictionary) -> Dictionary:
	var ctx: MatchContext = await make_match(START + Vector3(5.0, 0.11, 6.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, START, 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	if cfg.get("weak", false):
		p.dominant_right = true   # pelota a la izquierda: golpea con el pie no dominante
	var mate: Footballer = add_player(ctx, 0, START + Vector3(10.0, 0.0, -3.0), 60, ScriptedInput.new(), false)
	if cfg.get("defender", false):
		var d: Footballer = add_player(ctx, 1, START + Vector3(3.0, 0.0, 1.0), 60, AIInput.new(1, 0.7), false)
		d.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(-1, 0, 0))
	await physics_frames(5)
	var run: float = cfg.get("run", 0.0)
	var off: Vector2 = cfg.get("ball", Vector2(0.45, 0.0))
	ctx.ball.reset_at(p.global_position + Vector3(off.x, float(cfg.get("y", 0.11)), off.y), cfg.get("vel", Vector3.ZERO))
	if run > 0.0:
		src.move = Vector2(1, 0)
		await wait_seconds(run)
	else:
		await physics_frames(3)
	src.move = cfg.get("turn", Vector2(1, 0))
	var sk: Skeleton3D = p.visual.skeleton
	var toes: Array[int] = [sk.find_bone("mixamorig_LeftToeBase"), sk.find_bone("mixamorig_RightToeBase")]
	var ev := {"frame": -1, "ball": Vector3.ZERO, "toe": INF, "toe_raw": INF, "toe_before": INF, "whiff": "", "count": 0, "rival_first": false}
	var on_ev := func(e: GameEvent) -> void:
		if e.actor_id != p.actor_id:
			return
		if e.type == GameEvent.Type.PASS or e.type == GameEvent.Type.SHOT:
			ev["count"] += 1
			if ev["frame"] < 0:
				ev["frame"] = Engine.get_physics_frames()
				ev["ball"] = ctx.ball.global_position
				for k in 2:
					var tw: Vector3 = sk.global_transform * sk.get_bone_global_pose(toes[k]).origin
					ev["toe_before"] = minf(ev["toe_before"], tw.distance_to(ctx.ball.global_position))
		elif e.type == GameEvent.Type.KICK_WHIFF and ev["whiff"] == "":
			ev["whiff"] = String(e.data.get("reason", "missed"))
	ctx.event_emitted.connect(on_ev)
	# Un rival que toca la pelota antes del golpe: la orden se cancela (resultado legitimo, no una patada al aire).
	ctx.ball.touched.connect(func(who: Node) -> void:
		if ev["frame"] < 0 and who != p and who.get("team") == 1:
			ev["rival_first"] = true)
	var action: StringName = cfg["action"]
	match action:
		&"pass": src.hold_pass()
		&"shot": src.hold_shoot()
		&"through": src.hold_through()
		&"cross": src.hold_cross()
	await physics_frames(int(cfg.get("charge", 8)))
	match action:
		&"pass": src.release_pass()
		&"shot": src.release_shoot()
		&"through": src.release_through()
		&"cross": src.release_cross()
	# Punta del pie REAL en la imagen del golpe: el AnimationTree avanza en _process, DESPUES de la fisica, asi que la pose
	# que se dibuja junto al impulso del paso N es la que se lee al empezar la fisica del N+1 (medido paso a paso: 0.05 m
	# en esa imagen, 0.28 m en la anterior, con el pie aun en el armado). La leida dentro del paso N (imagen anterior)
	# se anota como referencia.
	# Una preparacion con giro puede consumir las ventanas de aproximacion y espera antes del swing.
	# Se conserva la observacion minima y se exige finalizar dentro de las ventanas configuradas.
	var default_frames := int(ceil((BallHandler.PENDING_APPROACH_MAX + BallHandler.PENDING_FIRST_TIME_MAX + BallHandler.TURN_KICK_MAX_LATENCY + Tuning.player.kick_lockout) * 60.0))
	for i in int(cfg.get("observe_frames", default_frames)):
		await tree.physics_frame
		var fr: int = Engine.get_physics_frames()
		if ev["frame"] >= 0 and fr == int(ev["frame"]) + 1:
			var key: String = "toe"
			for k in 2:
				var tw: Vector3 = sk.global_transform * sk.get_bone_global_pose(toes[k]).origin
				ev["toe_raw"] = minf(ev["toe_raw"], tw.distance_to(ev["ball"]))
				var ik: TouchFootIK = p.visual.touch_ik
				if ik != null and ik.rendered_frame[k] > 0 and ik.rendered_frame[k] >= Engine.get_process_frames() - 1:
					tw = ik.rendered_toe_world[k]
				ev[key] = minf(ev[key], tw.distance_to(ev["ball"]))
		if i >= 99 and p.ball_handler._pending_action == &"" and p.ball_handler._kick_action == &"" and p.ball_handler.lockout <= 0.0:
			break
	var bh: BallHandler = p.ball_handler
	var out := {"kicked": ev["frame"] >= 0, "toe": ev["toe"], "toe_raw": ev["toe_raw"], "toe_before": ev["toe_before"], "whiff": ev["whiff"], "count": ev["count"], "rival_first": ev["rival_first"],
		# Libre: sin golpeo ni orden colgados y sin una accion que lo retenga. Un movimiento con pelota (toque orientado,
		# arranque) EMPEZADO DESPUES del golpe no es un bloqueo: el que paso alcanzo su pelota (pase filtrado sin
		# companero) y sigue jugandola (2026-11-06; antes de esos movimientos cualquier accion contaba como bloqueo).
		"free": bh._kick_action == &"" and bh._pending_action == &"" and (not p.actions.active() and bh.lockout <= 0.0 \
			or (p.actions.kind == &"ball_move" and bh.json_move.active and int(bh.json_move.last.get("frame", -1)) > int(ev["frame"]))),
		"busy": "golpeo %s, orden %s, bloqueo %.2f s, accion %s %s" % [bh._kick_action, bh._pending_action, bh.lockout, p.actions.kind, str(bh.json_move.last.get("intent", "")) if bh.json_move.active else ""],
		"clip": bh.kick_log.back().get("clip", "-") if not bh.kick_log.is_empty() else "-"}
	cleanup()
	return out

func test_kick_battery_fifty_varied_actions() -> void:
	if _needs_render():
		return
	var cases: Array = []
	var actions: Array[StringName] = [&"pass", &"shot"]
	# 1) Posicion de la pelota con el jugador parado (delante, izquierda, derecha, lejos, al costado, detras).
	for pos in [["delante", Vector2(0.45, 0.0)], ["izquierda", Vector2(0.45, -0.22)], ["derecha", Vector2(0.45, 0.22)],
			["lejos (1.3 m)", Vector2(1.3, 0.0)], ["al costado", Vector2(0.05, 0.55)], ["detras", Vector2(-0.45, 0.1)]]:
		for a in actions:
			for ch in [6, 40]:
				cases.append({"name": "parado, pelota %s, %s carga %d" % [pos[0], a, ch], "ball": pos[1], "action": a, "charge": ch})
	# 2) En carrera (conduciendo 1.2 s) y conduccion rapida con cambio de direccion al pulsar.
	for a in [&"pass", &"shot", &"through", &"cross"]:
		cases.append({"name": "en carrera, %s" % a, "ball": Vector2(0.5, 0.0), "run": 1.2, "action": a, "charge": 10})
		cases.append({"name": "en carrera girando 60 grados, %s" % a, "ball": Vector2(0.5, 0.0), "run": 1.2, "turn": Vector2(0.5, 0.87), "action": a, "charge": 10})
		cases.append({"name": "en carrera girando 120 grados, %s" % a, "ball": Vector2(0.5, 0.0), "run": 1.2, "turn": Vector2(-0.5, 0.87), "action": a, "charge": 10})
	# 3) Pelota que se aleja, que llega y que bota.
	for a in actions:
		cases.append({"name": "pelota que se aleja a 2.5 m/s, %s" % a, "ball": Vector2(0.6, 0.0), "vel": Vector3(2.5, 0, 0), "action": a, "charge": 6})
		# Las pelotas que llegan salen a la velocidad que, con la rodadura, las trae a la nominal junto al jugador.
		cases.append({"name": "pelota que llega a 6 m/s, %s de primera" % a, "ball": Vector2(5.0, 0.3), "vel": Vector3(-KickModel.ground_speed_for_distance(4.5, 6.0), 0, 0), "action": a, "charge": 4})
		cases.append({"name": "pelota que llega cruzada, %s de primera" % a, "ball": Vector2(3.0, 3.0), "vel": Vector3(-3.0, 0, -3.2).normalized() * KickModel.ground_speed_for_distance(3.7, 4.4), "action": a, "charge": 4})
		cases.append({"name": "pelota botando delante, %s" % a, "ball": Vector2(0.8, 0.0), "y": 0.7, "vel": Vector3(-0.5, 1.0, 0), "action": a, "charge": 6})
	# 4) Pie no dominante y bajo presion.
	for a in actions:
		cases.append({"name": "pie no dominante (pelota a la izquierda), %s" % a, "ball": Vector2(0.45, -0.22), "weak": true, "action": a, "charge": 10})
		cases.append({"name": "bajo presion parado, %s" % a, "ball": Vector2(0.45, 0.0), "defender": true, "action": a, "charge": 8})
		cases.append({"name": "bajo presion en carrera, %s" % a, "ball": Vector2(0.5, 0.0), "run": 0.8, "defender": true, "action": a, "charge": 8})
	# BATTERY_MAX limita la bateria al depurar (por defecto, todas).
	if OS.get_environment("BATTERY_MAX") != "":
		cases = cases.slice(0, int(OS.get_environment("BATTERY_MAX")))
	var kicked: int = 0
	var bad_contact: Array = []
	var stuck: Array = []
	var double: Array = []
	var whiffs: Dictionary = {}
	for c in cases:
		var r: Dictionary = await _battery_case(c)
		var line: String
		if r["kicked"]:
			kicked += 1
			line = "%s: GOLPEO con %s, punta visible %.3f m, pose base %.3f m (%.3f en la anterior)" % [c["name"], r["clip"], r["toe"], r["toe_raw"], r["toe_before"]]
			if r["toe"] > Tuning.player.kick_contact_radius + 0.05:
				bad_contact.append(c["name"])
			if r["count"] > 1:
				double.append(c["name"])
		else:
			var why: String = r["whiff"] if r["whiff"] != "" else "sin orden ejecutada"
			if r["rival_first"]:
				why += ", el rival toco la pelota antes"
			whiffs[why] = whiffs.get(why, 0) + 1
			line = "%s: SIN golpeo (%s)" % [c["name"], why]
		if not r["free"]:
			stuck.append(c["name"])
			line += " [BLOQUEADO: %s]" % r["busy"]
		note(line)
	note("TOTAL %d acciones: %d golpeos con contacto, sin golpeo %s, contacto invalido %d, bloqueos %d" % [cases.size(), kicked, str(whiffs), bad_contact.size(), stuck.size()])
	check(cases.size() >= 50, "al menos 50 acciones (%d)" % cases.size())
	check(bad_contact.is_empty(), "ningun pase/tiro sin el pie en la pelota: %s" % str(bad_contact))
	check(double.is_empty(), "una sola salida por golpeo: %s" % str(double))
	check(stuck.is_empty(), "ningun jugador queda bloqueado tras la accion: %s" % str(stuck))
	check(kicked >= int(cases.size() * 0.8), "la gran mayoria conecta (%d de %d)" % [kicked, cases.size()])

func test_behind_ball_shot_finishes_after_its_measured_turn_and_pending_window() -> void:
	if _needs_render():
		return
	var frames := int(ceil((BallHandler.PENDING_APPROACH_MAX + BallHandler.PENDING_FIRST_TIME_MAX + BallHandler.TURN_KICK_MAX_LATENCY + Tuning.player.kick_lockout) * 60.0))
	var r: Dictionary = await _battery_case({"name": "pelota detras", "ball": Vector2(-0.45, 0.1), "action": &"shot", "charge": 40, "observe_frames": frames})
	note("recuperacion tras giro y ventana de orden: %s" % str(r))
	check(r["free"], "la orden termina dentro de las ventanas fisicas configuradas: %s" % r["busy"])
	check(r["count"] <= 1, "el giro no duplica el tiro")

func test_running_shot_under_pressure_has_a_visible_foot_contact() -> void:
	if _needs_render():
		return
	var r: Dictionary = await _battery_case({"name": "bajo presion en carrera", "ball": Vector2(0.5, 0), "action": &"shot", "charge": 10, "run": 1.2, "defender": true})
	note("contacto bajo presion: %s" % str(r))
	check(r["free"], "el tirador queda libre")
	if r["kicked"]:
		check(r["toe"] <= Tuning.player.kick_contact_radius + 0.05, "el pie visible contacta: %.3f m (base %.3f)" % [r["toe"], r["toe_raw"]])
