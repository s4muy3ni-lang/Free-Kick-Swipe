extends TestCase
## Fase 1 — Trazabilidad de la seleccion de animaciones (AnimTrace) y overlay de depuracion (AnimDebugOverlay).
## Comprueba: apagado por defecto, esquema fijo del CSV, exportacion CSV/JSON, que registrar no cambia ninguna decision,
## el diagnostico de un clip que no se reproduce (no encontrado, sin consumidor, filtro, coste, arbitro, cancelado, sin
## contacto, reproducido) y el modelo de datos del overlay. Modo 4 (el del juego).

## Esquema de la seccion 3.3 de la guia, copiado aqui para que un cambio accidental del orden haga fallar la prueba.
const EXPECTED := ["tick", "player_id", "action_family", "system_requester", "segment_id", "source_id", "variant", "is_mirror",
	"role_effective", "context", "frame_start", "frame_contact", "body_part", "foot", "v_in", "v_clip", "orient_start", "orient_target",
	"ball_pred_x", "ball_pred_y", "ball_pred_z", "contact_point_x", "contact_point_y", "contact_point_z", "spatial_error_m",
	"angular_error_deg", "root_correction_m", "tolerance_applied", "tolerance_reason", "cost_total", "cost_breakdown_json", "result",
	"rejection_reason", "contact_validated", "physics_applied"]

func _off() -> void:
	AnimTrace.enable(false)
	AnimTrace.clear()

## Pase parado con la pelota al pie: devuelve {ctx, p, ball_v (tras el golpeo), clip}.
func _pass_scene(seed: int) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(-9.45, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-10.0, 0.0, 0.0), 60, src, true)
	add_player(ctx, 0, Vector3(-2.0, 0.0, 2.0), 60, ScriptedInput.new(), true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	p.ball_handler.rng.seed = seed
	await physics_frames(10)
	src.hold_pass()
	await physics_frames(6)
	src.release_pass()
	var clip: String = ""
	var v := Vector3.ZERO
	for i in 90:
		await tree.physics_frame
		if clip == "" and not p.ball_handler.kick_log.is_empty():
			clip = String(p.ball_handler.kick_log.back().get("clip", ""))
		if ctx.ball.ground_speed() > 1.0 and v == Vector3.ZERO:
			v = ctx.ball.linear_velocity
	return {"ctx": ctx, "p": p, "ball_v": v, "clip": clip}

func test_trace_is_off_by_default_and_never_on_in_release() -> void:
	_off()
	check(not AnimTrace.enabled, "el registro empieza apagado")
	var s: Dictionary = await _pass_scene(7)
	check(s["clip"] != "", "hubo golpeo con clip (%s)" % s["clip"])
	check(AnimTrace.rows.is_empty(), "apagado no registra nada (%d filas)" % AnimTrace.rows.size())
	check(AnimTrace.allowed() == OS.is_debug_build(), "solo una compilacion de depuracion puede encenderlo")
	cleanup()

func test_csv_schema_is_the_fixed_one() -> void:
	check(AnimTrace.COLUMNS.size() == 35 and Array(AnimTrace.COLUMNS) == EXPECTED, "las 35 columnas en el orden de la guia")
	_off()
	AnimTrace.enable(true)
	AnimTrace.event(null, &"kick", &"prueba", &"", "rejected", "motivo, con coma")
	var lines: PackedStringArray = AnimTrace.to_csv().strip_edges().split("\n")
	check(lines[0] == ",".join(EXPECTED), "la cabecera del CSV es el esquema fijo")
	check(lines.size() == 2 and lines[1].contains("\"motivo, con coma\""), "los campos con coma van entre comillas")
	_off()

func test_tracing_does_not_change_any_decision() -> void:
	_off()
	var a: Dictionary = await _pass_scene(11)
	cleanup()
	AnimTrace.enable(true)
	var b: Dictionary = await _pass_scene(11)
	note("sin registro: %s %s · con registro: %s %s" % [a["clip"], str(a["ball_v"]), b["clip"], str(b["ball_v"])])
	check(a["clip"] != "" and a["clip"] == b["clip"], "mismo clip elegido con y sin registro")
	check((a["ball_v"] as Vector3).distance_to(b["ball_v"]) < 1e-4, "misma velocidad de la pelota tras el golpeo")
	cleanup()
	_off()

func test_kick_decision_contact_and_export() -> void:
	_off()
	AnimTrace.enable(true)
	var s: Dictionary = await _pass_scene(5)
	var p: Footballer = s["p"]
	var seg: String = String(s["clip"]).trim_suffix("_mirror")
	var chosen: Array = AnimTrace.rows.filter(func(r: Dictionary) -> bool:
		return r["system_requester"] == "BallHandler.plan_clip_kick" and r["result"] == "accepted")
	var finish: Array = AnimTrace.rows.filter(func(r: Dictionary) -> bool: return r["system_requester"] == "BallHandler._finish_clip_kick")
	var arb: Array = AnimTrace.rows.filter(func(r: Dictionary) -> bool: return r["system_requester"] == "ActionArbiter" and r["action_family"] == "kick")
	var losers: Array = AnimTrace.rows.filter(func(r: Dictionary) -> bool:
		return r["system_requester"] == "BallHandler.plan_clip_kick" and r["result"] == "rejected")
	check(chosen.size() == 1, "una decision de golpeo aceptada (%d)" % chosen.size())
	if chosen.size() == 1:
		var r: Dictionary = chosen[0]
		note("elegido: %s fuente %s rol %s contacto f%s error %.3f m coste %.3f %s" % [r["variant"], r["source_id"], r["role_effective"],
			r["frame_contact"], float(r["spatial_error_m"]), float(r["cost_total"]), JSON.stringify(r["cost_breakdown_json"])])
		check(r["segment_id"] == seg and String(r["source_id"]).length() == 4, "tramo y fuente original identificados")
		check(r["player_id"] == p.actor_id and r["role_effective"] != "" and typeof(r["cost_breakdown_json"]) == TYPE_DICTIONARY, "jugador, rol y coste desglosado")
		check(str(r["ball_pred_x"]) != "" and str(r["contact_point_x"]) != "", "pelota prevista y punto del pie previsto")
	check(not losers.is_empty() and losers.all(func(r: Dictionary) -> bool: return String(r["rejection_reason"]) != ""), "cada candidato descartado lleva su motivo (%d)" % losers.size())
	check(arb.any(func(r: Dictionary) -> bool: return r["result"] == "accepted"), "el arbitro registra la aceptacion")
	check(finish.size() == 1 and finish[0]["result"] == "completed" and finish[0]["contact_validated"] and finish[0]["physics_applied"],
		"el contacto se valida y el impulso se aplica")
	check(AnimTrace.explain(StringName(s["clip"]))["categoria"] == "reproducido", "explain lo da por reproducido")
	var csv_path: String = "user://anim_trace_prueba.csv"
	var json_path: String = "user://anim_trace_prueba.json"
	check(AnimTrace.export_csv(csv_path) == OK and AnimTrace.export_json(json_path) == OK, "exporta CSV y JSON")
	var csv: PackedStringArray = FileAccess.get_file_as_string(csv_path).strip_edges().split("\n")
	var js: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	check(csv.size() == AnimTrace.rows.size() + 1 and (js["rows"] as Array).size() == AnimTrace.rows.size(), "mismas filas en CSV y JSON")
	check(Array(js["columns"]) == EXPECTED, "el JSON declara el mismo esquema")
	cleanup()
	_off()

func test_explain_gives_a_data_reason_for_each_case() -> void:
	_off()
	AnimTrace.enable(true)
	PackLibrary.reload()
	check(AnimTrace.explain(&"jn_no_existe_9999")["categoria"] == "no_encontrado", "clip inexistente: no_encontrado")
	var nis: Dictionary = AnimTrace.explain(&"jn_nis_misc_0168")
	check(nis["categoria"] == "sin_consumidor", "tramo pendiente sin sistema: sin_consumidor (%s)" % nis["detalle"])
	var unclean: StringName = &""
	for id in PackLibrary.by_role(&"kick_shot_hard"):
		if JsonCatalog.kick_clip_rejection(PackLibrary.meta(id), &"kick_shot_hard") != "":
			unclean = id
			break
	var ex: Dictionary = AnimTrace.explain(unclean)
	note("%s: %s" % [unclean, ex["detalle"]])
	check(unclean != &"" and ex["categoria"] == "filtro" and String(ex["detalle"]).contains("no limpio"), "tiro potente con contacto no limpio: filtro")
	var far: StringName = &""
	for id in PackLibrary.by_role(&"celebrate"):
		if (PackLibrary.meta(id).get("root_total", Vector2.ZERO) as Vector2).length() > JsonCatalog.SITUATION_ROOT_MAX:
			far = id
			break
	check(far != &"" and AnimTrace.explain(far)["categoria"] == "filtro", "festejo con recorrido de raiz > 1 m: filtro")
	# Arbitro y cancelacion: un gesto aceptado y despues interrumpido por una accion de mas nivel (un golpeo, que el arbitro
	# sostiene mientras dura su pose), y otro gesto rechazado porque ese golpeo ocupa el cuerpo.
	var ctx: MatchContext = await make_match(Vector3(5.0, 0.11, 0.0))
	var p: Footballer = add_player(ctx, 0, Vector3.ZERO, 60, ScriptedInput.new(), true)
	p.set_physics_process(false)
	await physics_frames(2)
	var gestures: Array[StringName] = AnimDB.candidates(&"celebrate", {"mirrors": false, "max_root": 0.3, "min_duration": 0.6})
	var g_cancel: StringName = gestures[0]
	var g_arbiter: StringName = gestures[1]
	var kicks: Array[StringName] = PackLibrary.by_role(&"kick_pass")
	check(p.arbiter.play(&"gesto", ActionArbiter.Level.GESTURE, &"prueba", g_cancel) != 0, "el gesto entra")
	check(p.arbiter.play(&"golpeo", ActionArbiter.Level.KICK, &"prueba", kicks[0]) != 0, "una accion de mas nivel lo interrumpe")
	check(p.arbiter.play(&"gesto", ActionArbiter.Level.GESTURE, &"prueba", g_arbiter) == 0, "otro gesto queda rechazado")
	check(AnimTrace.explain(g_cancel)["categoria"] == "cancelado", "gesto interrumpido: cancelado")
	check(AnimTrace.explain(g_arbiter)["categoria"] == "arbitro", "gesto rechazado por nivel: arbitro")
	cleanup()
	# Sin contacto: la pelota se va durante el balanceo.
	AnimTrace.clear()
	var ctx2: MatchContext = await make_match(Vector3(-9.45, 0.11, 0.0))
	var src := ScriptedInput.new()
	var k: Footballer = add_player(ctx2, 0, Vector3(-10.0, 0.0, 0.0), 60, src, true)
	k.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(10)
	src.hold_shoot()
	await physics_frames(3)
	src.release_shoot()
	var kicked: StringName = &""
	for i in 30:
		await tree.physics_frame
		if k.ball_handler.is_kick_in_progress():
			kicked = k.ball_handler._kick_clip.get("clip", &"")
			break
	ctx2.ball.reset_at(Vector3(-4.0, 0.11, 3.0))
	await wait_seconds(0.8)
	var miss: Dictionary = AnimTrace.explain(kicked)
	note("golpeo sin pelota %s: %s %s" % [kicked, miss["categoria"], JSON.stringify(miss["conteos"])])
	check(kicked != &"" and miss["categoria"] == "sin_contacto", "golpeo con la pelota lejos: sin_contacto")
	# Coste: un candidato que paso los filtros y perdio frente al elegido.
	var lost: Array = AnimTrace.rows.filter(func(r: Dictionary) -> bool: return r["rejection_reason"] == "coste")
	var by_cost: StringName = &""
	for r in lost:
		var v := StringName(r["variant"])
		if AnimTrace.explain(v)["categoria"] == "coste":
			by_cost = v
			break
	check(by_cost != &"", "un candidato que perdio por coste: coste")
	cleanup()
	_off()

func test_overlay_shows_the_decision_markers_and_candidates() -> void:
	_off()
	AnimTrace.enable(true)
	var s: Dictionary = await _pass_scene(5)
	var ov := AnimDebugOverlay.new()
	var sn: Dictionary = ov.snapshot(s["p"])
	var text: String = ov.snapshot_text(s["p"])
	note(" | ".join(text.split("\n").slice(0, 6)))
	check(not (sn["decision"] as Dictionary).is_empty() and not (sn["markers"] as Dictionary).is_empty(), "decision y marcadores del jugador")
	check(is_finite(float(sn["markers"]["distance"])), "distancia cuerpo-pelota en metros")
	check(text.contains("Arbitro: nivel") and text.contains("candidatos examinados"), "texto con arbitro y candidatos")
	ov.free()
	cleanup()
	_off()
