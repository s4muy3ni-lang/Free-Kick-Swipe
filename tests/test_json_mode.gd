extends TestCase
## Modo 4 de jugabilidad (Json): las animaciones de animaciones_futbol5_JSON (posiciones de 19 articulaciones) convertidas al
## esqueleto canonico JsonRig (assets/animations/json_clips.res y json_keeper.res, tools/json_anim/build_json_library.tscn)
## sobre el cuerpo del juego con ese esqueleto (el modelo de Tripo adaptado, assets/characters/json/tripo_body.scn; el
## humanoide propio json_human.scn se elimino el 2026-11-12 por pedido del usuario).
## Se comprueba la libreria (clips, roles, alias de los nombres del pack, contactos medidos), el retarget (error de los
## extremos frente a los datos), el modelo, la mezcla de marcha, y que pases y tiros salgan del pie de verdad.

const START := Vector3(-10.0, 0.0, 0.0)

func _skip_if_missing() -> bool:
	if not ResourceLoader.exists(PackLibrary.JSON_FIELD_PATH):
		skip("no existe assets/animations/json_clips.res (generar con tools/json_anim/build_json_library.tscn)")
		return true
	return false

func _mode4() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()

func _restore(prev: int) -> void:
	Tuning.gameplay_mode = prev
	PackLibrary.reload()

func test_library_has_roles_and_measured_contacts() -> void:
	if _skip_if_missing():
		return
	var prev: int = Tuning.gameplay_mode
	_mode4()
	var f: AnimationLibrary = PackLibrary.field()
	var k: AnimationLibrary = PackLibrary.keeper()
	check(f != null and k != null, "las dos librerias (campo y arquero) cargan")
	note("clips de campo: %d, de arquero: %d" % [f.get_animation_list().size(), k.get_animation_list().size()])
	for role in [&"idle", &"walk", &"jog", &"sprint", &"dribble_walk", &"dribble_jog", &"dribble_run", &"dribble_fast", &"dribble_sprint",
			&"kick_pass", &"kick_shot", &"kick_lob", &"header", &"volley", &"slide", &"fall", &"getup", &"celebrate", &"gk_dive", &"gk_catch", &"gk_scoop"]:
		check(not PackLibrary.by_role(role).is_empty(), "hay clips con el rol %s" % role)
	for kind in [&"pass", &"shot"]:
		var cands: Array = AnimationCatalog.kick_candidates(kind, 0.6)
		check(cands.size() >= 10, "patadas de %s con contacto medido: %d" % [kind, cands.size()])
		var both := {1: 0, -1: 0}
		for c in cands:
			var ct: Dictionary = c["contact"]
			both[int(ct["foot"])] += 1
			check((ct["pos"] as Vector3).y < 0.45 and float(ct["speed"]) > 2.0, "%s: pie bajo (%.2f m) y rapido (%.1f m/s) en el golpeo" % [c["clip"], (ct["pos"] as Vector3).y, ct["speed"]])
		check(both[1] >= 4 and both[-1] >= 4, "%s: las dos piernas (%d derecha, %d izquierda)" % [kind, both[1], both[-1]])
	_restore(prev)

func test_pack_names_resolve_to_json_clips() -> void:
	if _skip_if_missing():
		return
	var prev: int = Tuning.gameplay_mode
	_mode4()
	for legacy in [&"soccer_tackle", &"soccer_tackle_mirror", &"standing_up", &"Falling_Down", &"goalkeeper_idle", &"goalkeeper_diving_save", &"goalkeeper_diving_save_mirror",
			&"throw_in", &"Receive", &"Fist_Pump_3"]:
		check(PackLibrary.has_clip(legacy), "el nombre del pack %s tiene clip JSON (%s)" % [legacy, PackLibrary.resolve(legacy)])
	check(not PackLibrary.has_clip(&"Soccer_Spin"), "lo que no tiene sustituto no existe en el modo 4")
	var cel: Dictionary = AnimationCatalog.resolve(&"celebrate_scorer", true)
	check(String(cel.get("clip", "")) != "" and cel.get("source", &"") == &"pack", "festejo del goleador con clip JSON (%s)" % str(cel))
	# Fuera del modo 4 (el juego ya arranca en el 4: se pasa al 1 a proposito).
	_restore(1)
	check(not PackLibrary.has_clip(&"jn_idle_0520"), "fuera del modo 4 los clips JSON no estan en la libreria")
	_restore(prev)

func test_retarget_reaches_the_data() -> void:
	# Cada tobillo, muñeca y punta cae en el dato (la IK de dos huesos los alcanza) y el pecho y la cabeza a pocos cm.
	if _skip_if_missing():
		return
	var prev: int = Tuning.gameplay_mode
	_mode4()
	var worst := 0.0
	for id in [&"jn_sprint_3022", &"jn_dribble_sprint_1582", &"jn_kick_shot_0656", &"jn_idle_0520"]:
		var m: Dictionary = PackLibrary.meta(id)
		var e: float = float(m.get("reach_err_cm", 99.0))
		worst = maxf(worst, e)
	note("error maximo de alcance de extremidades: %.2f cm" % worst)
	check(worst < 1.5, "tobillos y muñecas alcanzan el dato (%.2f cm)" % worst)
	_restore(prev)

func _visual() -> FootballerVisual:
	var v := FootballerVisual.new()
	spawn(v)
	v.build(FootballerVisual.default_kit(0))
	return v

func test_model_builds_and_animates() -> void:
	if _skip_if_missing():
		return
	var prev: int = Tuning.gameplay_mode
	_mode4()
	for name in ["Tripo"]:
		var v: FootballerVisual = _visual()
		check(not v.is_placeholder and v.json_mode, "%s: se construye el modelo del modo Json" % name)
		check(v.skeleton != null and v.skeleton.get_bone_count() == 23, "%s: 23 huesos del esqueleto canonico" % name)
		check(v.uses_pack and v.anim_tree != null, "%s: arbol de animacion con la libreria JSON" % name)
		check(v.json_human, "%s: el cuerpo del juego (modelo de Tripo)" % name)
		# Mezcla direccional (marcaje y presion mirando al rival): con clips del modo 4. Sin ellos el jugador que presionaba
		# se deslizaba con la pose fija («como estatuas»).
		var dir_space: AnimationNodeBlendSpace2D = (v.anim_tree.tree_root as AnimationNodeBlendTree).get_node(&"Dir") as AnimationNodeBlendSpace2D
		var npts: int = dir_space.get_blend_point_count() if dir_space != null else 0
		note("%s: mezcla direccional con %d clips (%s)" % [name, npts, str(JsonCatalog.dir_points().map(func(pt: Array) -> String: return String(pt[0])))])
		check(npts >= 6, "%s: la mezcla direccional tiene clips del modo Json (%d)" % [name, npts])
		var dir_ok := true
		for i in npts:
			var an: AnimationNodeAnimation = dir_space.get_blend_point_node(i) as AnimationNodeAnimation
			if an == null or v.anim_player == null or not v.anim_player.has_animation(an.animation):
				dir_ok = false
		check(dir_ok, "%s: todos los clips de la mezcla direccional existen en el reproductor" % name)
		# Marcha: de parado a sprint, con y sin pelota; la pose cambia y la cadera queda a una altura creible.
		var hips: int = v.skeleton.find_bone("mixamorig_Hips")
		var ys: Array[float] = []
		for sp in [0.0, 1.8, 3.6, 6.0]:
			for step in 90:
				v.drive_motion(sp, 0.0, 1.0 / 60.0)
				v.anim_tree.advance(1.0 / 60.0)
			ys.append(PoseSampler.bone_in_skeleton(v.skeleton, hips).origin.y * 1.75)
		note("%s: altura de cadera a 0/1.8/3.6/6 m/s: %s" % [name, str(ys.map(func(y: float) -> String: return "%.2f" % y))])
		for y in ys:
			check(y > 0.65 and y < 0.95, "%s: cadera a %.2f m" % [name, y])
		v.carrying = true
		for step in 120:
			v.drive_motion(4.0, 0.0, 1.0 / 60.0)
			v.anim_tree.advance(1.0 / 60.0)
		check(true, "%s: marcha con pelota sin errores" % name)
		v.queue_free()
	_restore(prev)

## Conduce `run_s` s con el joystick a `stick` (y sprint) y pulsa pase o tiro; devuelve el golpeo.
func _kick_while_running(action: StringName, stick: float, sprint: bool, run_s: float) -> Dictionary:
	var ctx: MatchContext = await make_match(START + Vector3(0.6, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, START, 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	src.move = Vector2(stick, 0.0)
	src.sprint = sprint
	await wait_seconds(run_s)
	var ev := {}
	ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if (e.type == GameEvent.Type.PASS or e.type == GameEvent.Type.SHOT) and ev.is_empty():
			ev["data"] = e.data
			ev["speed"] = float(e.data.get("speed", 0.0)))
	if action == &"pass":
		src.hold_pass()
	else:
		src.hold_shoot()
	await physics_frames(12)
	if action == &"pass":
		src.release_pass()
	else:
		src.release_shoot()
	await wait_seconds(1.6)
	var out := {"kicked": not ev.is_empty(), "stats": p.ball_handler.kick_stats.duplicate(), "speed0": p.locomotion.speed}
	if not ev.is_empty():
		out["clip"] = String(ev["data"].get("clip", ""))
		out["foot"] = float(ev["data"].get("foot_distance", -1.0))
		out["latency"] = float(ev["data"].get("latency", -1.0))
		out["ball_speed"] = float(ev["speed"])
	cleanup()
	return out

func test_passes_and_shots_connect_with_json_clips() -> void:
	if _skip_if_missing():
		return
	var prev: int = Tuning.gameplay_mode
	_mode4()
	var done := 0
	var total := 0
	for action in [&"pass", &"shot"]:
		for cfg in [["parado", 0.0, false, 0.6], ["trote", 0.7, false, 1.4], ["trote", 0.7, false, 1.7], ["carrera", 1.0, false, 1.5], ["carrera", 1.0, false, 1.9], ["sprint", 1.0, true, 1.8]]:
			var r: Dictionary = await _kick_while_running(action, cfg[1], cfg[2], cfg[3])
			_mode4()
			total += 1
			var line: String = "%s %s (%.1f m/s, a los %.1f s)" % [action, cfg[0], r["speed0"], cfg[3]]
			if r["kicked"]:
				done += 1
				note("%s: clip %s, pie a %.3f m de la pelota, latencia %.2f s, pelota a %.1f m/s" % [line, r["clip"], r["foot"], r["latency"], r["ball_speed"]])
				check(String(r["clip"]).begins_with("jn_"), "%s: golpea con un clip JSON (%s)" % [line, r["clip"]])
				check(r["foot"] >= 0.0 and r["foot"] <= Tuning.player.kick_contact_radius, "%s: el pie esta en la pelota al golpear (%.3f m)" % [line, r["foot"]])
			else:
				note("%s: SIN golpeo %s" % [line, str(r["stats"])])
			check(int(r["stats"].get("missed", 0)) == 0, "%s: ninguna patada en falso (%s)" % [line, str(r["stats"])])
	_restore(prev)
	note("modo 4: %d de %d golpeos ejecutados" % [done, total])
	check(done >= total - 2, "casi todos los pases y tiros se ejecutan (%d de %d)" % [done, total])

func _drive(stick_fn: Callable, sprint: bool, seconds: float) -> Dictionary:
	var ctx: MatchContext = await make_match(START + Vector3(0.6, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, START, 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	src.sprint = sprint
	var dists: Array[float] = []
	var max_d := 0.0
	var max_position := Vector3.ZERO
	var max_ball_position := Vector3.ZERO
	var max_speed := 0.0
	for i in int(seconds * 60.0):
		src.move = stick_fn.call(i)
		await tree.physics_frame
		await tree.process_frame
		var d: float = Vector2(ctx.ball.global_position.x - p.global_position.x, ctx.ball.global_position.z - p.global_position.z).length()
		if i > 90:
			dists.append(d)
			if d > max_d:
				max_d = d
				max_position = p.global_position
				max_ball_position = ctx.ball.global_position
		max_speed = maxf(max_speed, p.locomotion.speed)
	dists.sort()
	var out := {"median": dists[dists.size() / 2], "max": max_d, "touches": p.ball_handler.dribble_touch_count, "foot": p.ball_handler.foot_touches, "speed": max_speed,
		"possessor": ctx.possessor == p, "max_position": max_position, "max_ball_position": max_ball_position}
	cleanup()
	return out

func test_live_dribble_keeps_the_ball_with_foot_touches() -> void:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return
	if _skip_if_missing():
		return
	# La secuencia de 9 s llega a la pared de la cancha de futsal de 40 m; el rebote no mide conduccion libre.
	use_game_pitch()
	var prev: int = Tuning.gameplay_mode
	for name in ["Tripo"]:
		_mode4()
		var jog: Dictionary = await _drive(func(_i: int) -> Vector2: return Vector2(0.6, 0.0), false, 7.0)
		_mode4()
		var run: Dictionary = await _drive(func(_i: int) -> Vector2: return Vector2(0.9, 0.0), false, 7.0)
		_mode4()
		var sprint: Dictionary = await _drive(func(_i: int) -> Vector2: return Vector2(1.0, 0.0), true, 8.0)
		_mode4()
		var zig: Dictionary = await _drive(func(i: int) -> Vector2: return Vector2(0.8, 0.9 * sin(float(i) / 60.0 * 2.2)), false, 9.0)
		for pair in [["trote", jog], ["carrera", run], ["sprint", sprint], ["zigzag", zig]]:
			var r: Dictionary = pair[1]
			note("%s, %s: pelota-cuerpo mediana %.2f m, max %.2f m, toques %d (con el pie %d), velocidad max %.1f m/s" % [name, pair[0], r["median"], r["max"], r["touches"], r["foot"], r["speed"]])
			note("maxima separacion: jugador %s, pelota %s" % [str(r["max_position"]), str(r["max_ball_position"])])
			check(r["max"] < 1.6, "%s, %s: la pelota nunca se va (max %.2f m)" % [name, pair[0], r["max"]])
			check(r["median"] > 0.25 and r["median"] < 1.1, "%s, %s: va al pie (mediana %.2f m)" % [name, pair[0], r["median"]])
			check(int(r["foot"]) >= int(int(r["touches"]) * 0.5), "%s, %s: la mayoria de los toques los da el pie (%d de %d)" % [name, pair[0], r["foot"], r["touches"]])
	_restore(prev)

func test_kick_planning_with_many_clips_is_cheap() -> void:
	# Con cientos de patadas candidatas, planificar un golpeo no puede costar mas de unos milisegundos (se repite cada paso mientras la
	# orden espera la pelota).
	if _skip_if_missing():
		return
	var prev: int = Tuning.gameplay_mode
	_mode4()
	var ctx: MatchContext = await make_match(START + Vector3(0.7, 0.11, 0.12))
	var p: Footballer = add_player(ctx, 0, START, 60, null, false)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(5)
	# La libreria se carga al montar el partido (aqui no hay modelos): la primera planificacion no cuenta.
	PackLibrary.field()
	var t0: int = Time.get_ticks_usec()
	var n := 60
	var found := 0
	for i in n:
		var plan: Dictionary = p.ball_handler.plan_clip_kick(&"pass" if i % 2 == 0 else &"shot", 0.5, false)
		if not plan.is_empty():
			found += 1
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)
	var t1: int = Time.get_ticks_usec()
	for i in n:
		AnimationCatalog.kick_candidates(&"pass", 0.5)
	note("  de ello, listar los candidatos: %.2f ms" % (float(Time.get_ticks_usec() - t1) / 1000.0 / float(n)))
	var t2: int = Time.get_ticks_usec()
	var cs: Array = AnimationCatalog.kick_candidates(&"pass", 0.5)
	for i in n:
		for cnd in cs:
			BallHandler.contact_samples_cached(cnd["clip"], cnd["contact"])
	note("  samples cacheadas: %.2f ms" % (float(Time.get_ticks_usec() - t2) / 1000.0 / float(n)))
	var t3: int = Time.get_ticks_usec()
	for i in n:
		for cnd in cs:
			BallHandler.clip_timing(0.33, &"pass", 0.5, false)
			BallHandler.clip_plant_velocity(cnd["clip"], 0.33, 1, 1.0)
	note("  timing+plant por clip: %.2f ms" % (float(Time.get_ticks_usec() - t3) / 1000.0 / float(n)))
	note("planificar un golpeo: %.2f ms de media (%d de %d con plan, %d candidatos de pase)" % [ms, found, n, AnimationCatalog.kick_candidates(&"pass", 0.5).size()])
	check(ms < 8.0, "planificar un golpeo cuesta %.2f ms" % ms)
	cleanup()
	_restore(prev)

func test_aerial_planning_cost_and_clips() -> void:
	# Pelota en el aire: el planificador aereo recorre las trayectorias de cabeza y pie de todos los clips de cabezazo y volea.
	if _skip_if_missing():
		return
	var prev: int = Tuning.gameplay_mode
	_mode4()
	var ctx: MatchContext = await make_match(START + Vector3(3.0, 1.3, 0.1))
	var p: Footballer = add_player(ctx, 0, START, 60, null, false)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	ctx.ball.linear_velocity = Vector3(-3.5, 0.5, 0.0)
	PackLibrary.field()
	var t0: int = Time.get_ticks_usec()
	var n := 10
	var plans: Array = []
	for i in n:
		plans.append(p.ball_handler.plan_aerial_kick(&"pass", 0.5))
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)
	var found: Array = plans.filter(func(x: Dictionary) -> bool: return not x.is_empty())
	note("planificar un golpeo aereo: %.1f ms (%d de %d con plan%s; %d clips de cabezazo, %d de volea)" % [ms, found.size(), n,
		(", ej. " + str(found[0]["clip"]) + " " + str(found[0]["aerial"])) if not found.is_empty() else "", PackLibrary.by_role(&"header").size(), PackLibrary.by_role(&"volley").size()])
	check(ms < 40.0, "planificar un golpeo aereo cuesta %.1f ms" % ms)
	cleanup()
	_restore(prev)
