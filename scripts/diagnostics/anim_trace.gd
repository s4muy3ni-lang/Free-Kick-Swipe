class_name AnimTrace
extends RefCounted
## Trazabilidad de la seleccion y la ejecucion de animaciones (Fase 1 de la guia del sistema de animaciones).
## Cada planificador registra los candidatos que examino (con su motivo de descarte o su coste), el elegido, la decision
## del arbitro, las cancelaciones y la validacion del contacto con la pelota, con un esquema FIJO de columnas para que las
## comparaciones entre fases sean automaticas (CSV/JSON).
## APAGADA por defecto y sin efecto en el juego: solo registra, nunca decide ni consume azar. Solo puede encenderse en
## compilaciones de depuracion (OS.is_debug_build): en la APK de produccion `enable` no hace nada.
## Encender: AnimTrace.enable(true) (pruebas), variable de entorno FUTBOL5_ANIM_TRACE=1 o argumento de usuario
## `--anim-trace` (configure_from_environment, lo llama MatchScene).

## Esquema fijo del CSV (seccion 3.3 de la guia). No cambiar el orden: las comparaciones entre fases dependen de el.
const COLUMNS: Array[String] = ["tick", "player_id", "action_family", "system_requester", "segment_id", "source_id", "variant",
	"is_mirror", "role_effective", "context", "frame_start", "frame_contact", "body_part", "foot", "v_in", "v_clip",
	"orient_start", "orient_target", "ball_pred_x", "ball_pred_y", "ball_pred_z", "contact_point_x", "contact_point_y",
	"contact_point_z", "spatial_error_m", "angular_error_deg", "root_correction_m", "tolerance_applied", "tolerance_reason",
	"cost_total", "cost_breakdown_json", "result", "rejection_reason", "contact_validated", "physics_applied"]
## Resultados posibles (columna result).
const RESULTS: Array[String] = ["accepted", "rejected", "interrupted", "cancelled", "expired", "contact_failed", "completed"]
## Fotogramas de las columnas frame_*: los metadatos de los clips estan muestreados a 30 Hz (root_path, paths).
const FRAME_RATE := 30.0
## Filas maximas guardadas (las mas viejas se descartan y se cuentan en `dropped`).
const MAX_ROWS := 200000
## Candidatos descartados que se escriben por decision (el elegido siempre; los demas, los de menor coste primero).
const MAX_CANDIDATES := 40
## Decisiones sin accion resultante (un planificador que espera): como mucho una cada SAMPLE_SECONDS por jugador y familia.
const SAMPLE_SECONDS := 0.25
## Candidatos que guarda el resumen por jugador (overlay).
const OVERLAY_CANDIDATES := 12

static var enabled: bool = false
static var rows: Array[Dictionary] = []
static var dropped: int = 0
## Ultima decision por jugador (actor_id): lo que muestra el overlay.
static var last: Dictionary = {}
static var _last_sample: Dictionary = {}

## Solo las compilaciones de depuracion pueden registrar (la APK de produccion queda siempre apagada).
static func allowed() -> bool:
	return OS.is_debug_build()

static func enable(on: bool) -> void:
	enabled = on and allowed()

static func clear() -> void:
	rows.clear()
	dropped = 0
	last.clear()
	_last_sample.clear()

## Enciende el registro si lo piden el entorno o los argumentos de usuario (solo en depuracion).
static func configure_from_environment() -> void:
	if OS.get_environment("FUTBOL5_ANIM_TRACE") == "1" or OS.get_cmdline_user_args().has("--anim-trace"):
		enable(true)

# --- Construccion de filas ---------------------------------------------------------------------------------------------

## Campos que salen del id de la variante: tramo, fuente (indice NNNN del JSON original), espejo y rol efectivo.
static func seg_fields(variant: StringName) -> Dictionary:
	var v: String = String(variant)
	if v == "":
		return {}
	var role: String = ""
	if PackLibrary.has_clip(variant):
		role = String(PackLibrary.meta(variant).get("role", ""))
	return {"segment_id": v.trim_suffix("_mirror"), "source_id": AnimDB.index_of(variant), "variant": v,
		"is_mirror": v.ends_with("_mirror"), "role_effective": role}

static func _player_id(player: Node) -> int:
	if player == null:
		return -1
	var id: Variant = player.get("actor_id")
	return int(id) if id != null else -1

## Fila con todas las columnas (vacias las que no aplican) a partir de `fields`.
static func make_row(player: Node, family: StringName, requester: StringName, variant: StringName, fields: Dictionary) -> Dictionary:
	var r: Dictionary = {}
	for c in COLUMNS:
		r[c] = ""
	r["tick"] = Engine.get_physics_frames()
	r["player_id"] = _player_id(player)
	r["action_family"] = String(family)
	r["system_requester"] = String(requester)
	r.merge(seg_fields(variant), true)
	for k in fields:
		if r.has(k):
			r[k] = fields[k]
	return r

static func _push(r: Dictionary) -> void:
	rows.append(r)
	if rows.size() > MAX_ROWS:
		rows.pop_front()
		dropped += 1

## Fila suelta (arbitro, contacto, cancelacion). Tambien actualiza el resumen del jugador.
static func event(player: Node, family: StringName, requester: StringName, variant: StringName, result: String, reason: String = "",
		fields: Dictionary = {}) -> void:
	if not enabled:
		return
	var f: Dictionary = fields.duplicate()
	f["result"] = result
	f["rejection_reason"] = reason
	var r: Dictionary = make_row(player, family, requester, variant, f)
	_push(r)
	var pid: int = int(r["player_id"])
	var s: Dictionary = last.get(pid, {})
	if String(requester) == "ActionArbiter":
		s["arbiter"] = r
	else:
		s["event"] = r
	last[pid] = s

# --- Decisiones de los planificadores ------------------------------------------------------------------------------------

## Empieza una decision: los candidatos se van agregando con `cand` y se escriben al cerrar con `commit`.
static func begin(player: Node, family: StringName, requester: StringName, context: String = "") -> Dictionary:
	return {"player": player, "family": family, "requester": requester, "context": context, "cands": [], "by_variant": {}}

## Candidato examinado. `reason` vacio = paso los filtros (compite por coste: cost_total). Si un mismo candidato se
## examina varias veces (instantes de inicio, velocidades), se queda con su mejor registro: el de menor coste si paso los
## filtros, o el primer motivo de descarte si nunca los paso.
static func cand(dec: Dictionary, variant: StringName, reason: String, fields: Dictionary = {}) -> void:
	if dec.is_empty():
		return
	var key: String = String(variant)
	var by: Dictionary = dec["by_variant"]
	var f: Dictionary = fields.duplicate()
	f["rejection_reason"] = reason
	if by.has(key):
		var prev: Dictionary = by[key]
		if reason != "":
			return
		if String(prev["rejection_reason"]) == "" and float(prev.get("cost_total", INF)) <= float(f.get("cost_total", INF)):
			return
	by[key] = f

## Cierra una decision. chosen: variante elegida (&"" si ninguna). result: del elegido ("accepted", "rejected"...).
## Una decision sin elegido se muestrea (SAMPLE_SECONDS por jugador y familia) para no escribir una por paso de fisica.
static func commit(dec: Dictionary, chosen: StringName, chosen_fields: Dictionary = {}, result: String = "accepted", reason: String = "") -> void:
	if dec.is_empty():
		return
	var player: Node = dec["player"]
	var pid: int = _player_id(player)
	var by: Dictionary = dec["by_variant"]
	var ctx_s: String = String(dec["context"])
	var cands: Array = []
	for v in by:
		if StringName(v) == chosen:
			continue
		var f: Dictionary = by[v]
		if String(f["rejection_reason"]) == "":
			f["rejection_reason"] = "coste" if chosen != &"" else "sin elegido"
		cands.append([StringName(v), f])
	cands.sort_custom(func(a: Array, b: Array) -> bool:
		var ar: bool = String(a[1]["rejection_reason"]) in ["coste", "sin elegido"]
		var br: bool = String(b[1]["rejection_reason"]) in ["coste", "sin elegido"]
		if ar != br:
			return ar
		return float(a[1].get("cost_total", INF)) < float(b[1].get("cost_total", INF)))
	var reasons: Dictionary = {}
	for c in cands:
		var why: String = String(c[1]["rejection_reason"])
		reasons[why] = int(reasons.get(why, 0)) + 1
	var summary: Dictionary = {"tick": Engine.get_physics_frames(), "family": String(dec["family"]), "requester": String(dec["requester"]),
		"context": ctx_s, "chosen": String(chosen), "result": result if chosen != &"" else "rejected", "reason": reason,
		"examined": by.size(), "reasons": reasons, "candidates": [], "chosen_row": {}}
	var write: bool = true
	if chosen == &"":
		var key: String = "%d:%s" % [pid, String(dec["family"])]
		var now: int = Engine.get_physics_frames()
		var prev: int = int(_last_sample.get(key, -1000000))
		write = float(now - prev) / float(Engine.physics_ticks_per_second) >= SAMPLE_SECONDS
		if write:
			_last_sample[key] = now
	if chosen != &"":
		var cf: Dictionary = by.get(String(chosen), {}).duplicate()
		cf.merge(chosen_fields, true)
		cf["result"] = result
		cf["rejection_reason"] = reason
		cf["context"] = ctx_s
		var r: Dictionary = make_row(player, dec["family"], dec["requester"], chosen, cf)
		summary["chosen_row"] = r
		if write:
			_push(r)
	var n: int = 0
	for c in cands:
		var f2: Dictionary = c[1]
		f2["result"] = "rejected"
		f2["context"] = ctx_s
		var r2: Dictionary = make_row(player, dec["family"], dec["requester"], c[0], f2)
		if n < OVERLAY_CANDIDATES:
			(summary["candidates"] as Array).append(r2)
		if write and n < MAX_CANDIDATES:
			_push(r2)
		n += 1
	var s: Dictionary = last.get(pid, {})
	s["decision"] = summary
	last[pid] = s

# --- Exportacion -------------------------------------------------------------------------------------------------------

static func _cell(v: Variant) -> String:
	match typeof(v):
		TYPE_FLOAT:
			return "" if is_inf(v) or is_nan(v) else String.num(v, 4)
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_DICTIONARY, TYPE_ARRAY:
			return JSON.stringify(v)
	var s: String = str(v)
	if s.contains(",") or s.contains("\"") or s.contains("\n"):
		return "\"" + s.replace("\"", "\"\"") + "\""
	return s

static func to_csv() -> String:
	var lines: PackedStringArray = [",".join(COLUMNS)]
	for r in rows:
		var cells: PackedStringArray = []
		for c in COLUMNS:
			cells.append(_cell(r.get(c, "")))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"

static func export_csv(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_csv())
	f.close()
	return OK

static func export_json(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var out: Array = []
	for r in rows:
		var o: Dictionary = {}
		for c in COLUMNS:
			var v: Variant = r.get(c, "")
			o[c] = null if (typeof(v) == TYPE_FLOAT and (is_inf(v) or is_nan(v))) else v
		out.append(o)
	f.store_string(JSON.stringify({"columns": COLUMNS, "dropped": dropped, "rows": out}))
	f.close()
	return OK

# --- Diagnostico de un clip que no se reproduce ------------------------------------------------------------------------

## Roles que solo eligen las situaciones de presentacion (JsonCatalog.situation_clip, con su filtro de raiz y duracion).
const _SITUATION_FILTER := {"mirrors": false, "max_root": JsonCatalog.SITUATION_ROOT_MAX, "min_duration": 0.6}
const _KICK_ROLES: Array[StringName] = [&"kick_pass_soft", &"kick_pass", &"kick_shot", &"kick_shot_hard", &"kick_lob", &"kick_cross"]

## Motivo estatico (no depende de la jugada) por el que el selector de su rol nunca ofrece este clip; "" si lo ofrece.
static func static_filter(variant: StringName) -> String:
	if not PackLibrary.has_clip(variant):
		return ""
	var m: Dictionary = PackLibrary.meta(variant)
	var role := StringName(String(m.get("role", "")))
	if _KICK_ROLES.has(role):
		return JsonCatalog.kick_clip_rejection(m, role)
	if role == &"kick_turn" or role == &"kick_back":
		if not m.has("contact"):
			return "sin contacto medido (BallHandler.plan_turn_kick)"
		if (m["contact"]["pos"] as Vector3).y > 0.35:
			return "pie a mas de 0.35 m en el contacto (BallHandler.plan_turn_kick)"
		return ""
	for sit in JsonCatalog.SITUATION_ROLES:
		if (JsonCatalog.SITUATION_ROLES[sit] as Array).has(role):
			var base := StringName(String(variant).trim_suffix("_mirror"))
			if not AnimDB.candidates(role, _SITUATION_FILTER).has(base):
				return "recorrido de raiz > %.1f m o duracion < 0.6 s (JsonCatalog.situation_clip)" % JsonCatalog.SITUATION_ROOT_MAX
			return ""
	if JsonBallMove.STEER_ROLES.has(role) and (m.get("ball_touches", []) as Array).is_empty() and not JsonReceive.ROLES.has(role):
		return "sin toques de pelota medidos (JsonBallMove.plan_ids)"
	if JsonReceive.ROLES.has(role) and not JsonReceive.is_candidate(variant):
		return "perfil de recepcion no seleccionable (ReceiveProfiles: pending / not_reception / sin perfil)"
	return ""

## Por que un clip no se reproduce (o si se reproduce). Categorias: no_encontrado, sin_rol, sin_consumidor, filtro,
## filtro_dinamico, coste, arbitro, cancelado, sin_contacto, reproducido, sin_evaluar. `conteos` resume las filas
## registradas de ese tramo (requiere el registro encendido durante la jugada).
static func explain(variant: StringName) -> Dictionary:
	var out := {"variant": String(variant), "categoria": "", "detalle": "", "conteos": {}}
	if not PackLibrary.has_clip(variant):
		out["categoria"] = "no_encontrado"
		out["detalle"] = "no existe en las librerias cargadas (ni por alias)"
		return out
	var role: String = String(PackLibrary.meta(variant).get("role", ""))
	if role == "":
		out["categoria"] = "sin_rol"
		out["detalle"] = "el clip no tiene rol efectivo"
		return out
	var seg: String = String(PackLibrary.resolve(variant)).trim_suffix("_mirror")
	var conn: Dictionary = AnimDB.connection(StringName(seg))
	var hist: String = ""
	for t in AnimDB.record(StringName(seg)).get("tramos", []):
		if String(t.get("id", "")) == seg:
			hist = String(t.get("conectada", ""))
	if hist != "si" and String(conn.get("status", "")) != "connected_invocation_verified":
		out["categoria"] = "sin_consumidor"
		out["detalle"] = "rol %s sin sistema que lo pida (inventario: %s)" % [role, hist if hist != "" else "sin registro"]
		return out
	var sf: String = static_filter(variant)
	if sf != "":
		out["categoria"] = "filtro"
		out["detalle"] = sf
		return out
	var counts: Dictionary = {}
	for r in rows:
		if String(r["segment_id"]) != seg:
			continue
		var key: String = String(r["result"]) + ("" if String(r["rejection_reason"]) == "" else ":" + String(r["rejection_reason"]))
		counts[key] = int(counts.get(key, 0)) + 1
	out["conteos"] = counts
	var has := func(prefix: String) -> bool:
		for k in counts:
			if String(k).begins_with(prefix):
				return true
		return false
	# «completed» = contacto validado, movimiento con pelota terminado o accion liberada al terminar; «expired» = el arbitro la
	# dio por terminada porque su dueno ya no la sostenia (fin natural de una pose), que no prueba un contacto.
	if has.call("completed"):
		out["categoria"] = "reproducido"
	elif has.call("contact_failed"):
		out["categoria"] = "sin_contacto"
	elif has.call("interrupted") or has.call("cancelled"):
		out["categoria"] = "cancelado"
	elif has.call("accepted") or has.call("expired"):
		out["categoria"] = "reproducido"
		out["detalle"] = "aceptado; sin validacion de contacto registrada (pose o accion sin pelota)"
	elif has.call("rejected:arbitro"):
		out["categoria"] = "arbitro"
	elif has.call("rejected:coste"):
		out["categoria"] = "coste"
	elif not counts.is_empty():
		out["categoria"] = "filtro_dinamico"
	else:
		out["categoria"] = "sin_evaluar"
		out["detalle"] = "ningun planificador lo examino mientras el registro estaba encendido"
	return out
