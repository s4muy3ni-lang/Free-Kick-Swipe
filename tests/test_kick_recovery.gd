extends TestCase
## Fase 2 — Golpeos recuperados del filtro «contacto no limpio» (JsonCatalog.KICK_LATERAL_MAX). Cumplen todas las
## condiciones de golpeo limpio salvo el costado (contacto entre 0.50 y 0.75 m al lado del cuerpo). Se exige el consumidor
## real: para cada clip y su espejo, BallHandler.plan_clip_kick (con la variante pedida) lo planifica con la pelota quieta
## en su costado, el arbitro lo acepta, el contacto se valida en el instante del clip y la pelota recibe el impulso. Y que
## sigan fuera los que fallan cualquier otra condicion. Modo 4.

const ROLE_ACTION := {&"kick_pass_soft": [&"pass", 0.2, false], &"kick_pass": [&"pass", 0.5, false], &"kick_shot": [&"shot", 0.3, false],
	&"kick_shot_hard": [&"shot", 0.9, false], &"kick_lob": [&"pass", 0.5, true]}

## Clips (sin espejo) que el filtro admite ahora y antes no: contacto no limpio solo por el costado.
func _recovered() -> Array[StringName]:
	var out: Array[StringName] = []
	for role in ROLE_ACTION:
		for id in PackLibrary.by_role(role):
			if String(id).ends_with("_mirror"):
				continue
			var m: Dictionary = PackLibrary.meta(id)
			if m.has("contact") and not bool(m["contact"].get("clean", true)) and JsonCatalog.kick_clip_rejection(m, role) == "":
				out.append(id)
	return out

func test_recovered_set_is_exactly_the_lateral_only_kicks() -> void:
	PackLibrary.reload()
	var rec: Array[StringName] = _recovered()
	var bad: Array = []
	for id in rec:
		var ct: Dictionary = PackLibrary.meta(id)["contact"]
		if JsonCatalog.kick_clean_failures(ct) != ["costado"] or absf((ct["pos"] as Vector3).z) > JsonCatalog.KICK_LATERAL_MAX:
			bad.append(id)
	note("golpeos recuperados por el costado: %d" % rec.size())
	check(rec.size() == 54, "54 golpeos recuperados (diagnostico de la Fase 2): %d" % rec.size())
	check(bad.is_empty(), "todos fallaban solo por el costado y dentro de %.2f m: %s" % [JsonCatalog.KICK_LATERAL_MAX, str(bad)])
	var still: int = 0
	for role in ROLE_ACTION:
		for id in PackLibrary.by_role(role):
			var m: Dictionary = PackLibrary.meta(id)
			if m.has("contact") and JsonCatalog.kick_clip_rejection(m, role) != "":
				still += 1
				check(String(JsonCatalog.kick_clip_rejection(m, role)).contains("exige clean:"), "%s: el motivo detalla la condicion que falla" % id)
	note("golpeos (con espejos) que siguen fuera por otra condicion: %d" % still)

func test_each_recovered_kick_reaches_the_ball_through_the_real_planner() -> void:
	PackLibrary.reload()
	var ids: Array[StringName] = []
	for id in _recovered():
		ids.append(id)
		var mi := StringName(String(id) + "_mirror")
		if PackLibrary.has_clip(mi):
			ids.append(mi)
	var ok: int = 0
	var worst: float = 0.0
	var failed: Array = []
	for id in ids:
		var m: Dictionary = PackLibrary.meta(id)
		var act: Array = ROLE_ACTION[StringName(String(m["role"]))]
		var ct: Dictionary = m["contact"]
		var cp: Vector3 = ct["pos"]
		var ctx: MatchContext = await make_match(Vector3(5.0 + cp.x, 0.11, cp.z))
		var p: Footballer = add_player(ctx, 0, Vector3(5.0, 0.0, 0.0), 60, ScriptedInput.new(), true)
		add_player(ctx, 0, Vector3(13.0, 0.0, cp.z), 60, ScriptedInput.new(), true)
		p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
		p.set_physics_process(false)
		await physics_frames(3)
		var bh: BallHandler = p.ball_handler
		bh._pending_stick = Vector3(1, 0, 0)
		var plan: Dictionary = bh.plan_clip_kick(act[0], float(act[1]), bool(act[2]), id)
		var started: bool = not plan.is_empty() and bh._start_clip_kick(act[0], plan, Vector3(1, 0, 0), float(act[1]), bool(act[2]))
		p.set_physics_process(true)
		for i in 60:
			await tree.physics_frame
			if not bh.is_kick_in_progress():
				break
		var contact: bool = int(bh.kick_stats["contact"]) == 1
		var d: float = bh.last_foot_distance
		if started and contact and d <= 0.2 and ctx.ball.linear_velocity.length() > 2.0:
			ok += 1
			worst = maxf(worst, d)
		else:
			failed.append("%s plan=%s contacto=%s d=%.2f v=%.1f" % [id, not plan.is_empty(), contact, d, ctx.ball.linear_velocity.length()])
		cleanup()
	note("golpeos recuperados (con espejos) que llegan a la pelota: %d de %d; peor distancia pie-pelota %.3f m" % [ok, ids.size(), worst])
	if not failed.is_empty():
		note("fallan: %s" % str(failed.slice(0, 8)))
	check(ok == ids.size(), "cada golpeo recuperado se planifica, valida el contacto y mueve la pelota (%d de %d)" % [ok, ids.size()])
