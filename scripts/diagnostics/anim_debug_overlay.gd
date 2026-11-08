class_name AnimDebugOverlay
extends CanvasLayer
## Overlay de depuracion de animaciones en partido (Fase 1). Solo existe en compilaciones de depuracion (MatchScene no lo
## crea en la APK de produccion). F3: muestra / oculta (y enciende AnimTrace); F4: cambia de jugador (el controlado, luego
## cada futbolista y arquero). Tambien se activa con `--anim-debug` o FUTBOL5_ANIM_DEBUG=1.
## Muestra, para el jugador elegido: estado del ActionArbiter, ultima decision (familia, sistema, contexto), elegido con su
## tramo, fotogramas de inicio y contacto, coste desglosado y distancia prevista; los candidatos examinados con su motivo;
## y en el mundo, el punto del cuerpo previsto (circulo) y la pelota prevista en el contacto (cuadro) con la linea y la
## distancia entre ambos. Los datos salen de AnimTrace.last (no recalcula nada del juego).

const TOGGLE_KEY := KEY_F3
const CYCLE_KEY := KEY_F4
const COLOR_BODY := Color(0.2, 0.9, 1.0)
const COLOR_BALL := Color(1.0, 0.85, 0.1)
const COLOR_BAD := Color(1.0, 0.3, 0.3)

var scene: MatchScene = null
var active: bool = false
## Indice en la lista de actores seleccionables (0 = el jugador controlado).
var selected: int = 0
var _panel: Label = null
var _canvas: Control = null

func setup(s: MatchScene) -> void:
	scene = s
	layer = 50
	_panel = Label.new()
	_panel.position = Vector2(12, 60)
	_panel.add_theme_font_size_override("font_size", 13)
	_panel.add_theme_color_override("font_outline_color", Color.BLACK)
	_panel.add_theme_constant_override("outline_size", 4)
	add_child(_panel)
	_canvas = _Markers.new()
	(_canvas as _Markers).overlay = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	set_active(OS.get_environment("FUTBOL5_ANIM_DEBUG") == "1" or OS.get_cmdline_user_args().has("--anim-debug"))

func set_active(on: bool) -> void:
	active = on
	visible = on
	set_process(on)
	if on:
		AnimTrace.enable(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == TOGGLE_KEY:
			set_active(not active)
		elif event.keycode == CYCLE_KEY and active:
			selected += 1

## Actores seleccionables: el controlado primero, despues los futbolistas y los arqueros.
func actors() -> Array:
	var out: Array = []
	if scene == null or scene.ctx == null:
		return out
	if scene.controlled != null:
		out.append(scene.controlled)
	for f in scene.ctx.footballers:
		if not out.has(f):
			out.append(f)
	for k in scene.ctx.keepers:
		if not out.has(k):
			out.append(k)
	return out

func target() -> Node:
	var a: Array = actors()
	return a[selected % a.size()] if not a.is_empty() else null

## Modelo de datos del overlay para un actor (lo que se dibuja; tambien lo usan las pruebas).
func snapshot(actor: Node) -> Dictionary:
	if actor == null:
		return {}
	var pid: int = int(actor.get("actor_id"))
	var s: Dictionary = AnimTrace.last.get(pid, {})
	var arb: Dictionary = {}
	var a: ActionArbiter = actor.get("arbiter") as ActionArbiter
	if a != null:
		arb = {"level": a.current_level(), "kind": String(a.kind), "clip": String(a.clip), "last": a.log.back() if not a.log.is_empty() else ""}
	var dec: Dictionary = s.get("decision", {})
	var row: Dictionary = dec.get("chosen_row", {})
	if row.is_empty():
		row = s.get("event", {})
	var markers: Dictionary = {}
	if not row.is_empty() and str(row.get("ball_pred_x", "")) != "" and str(row.get("contact_point_x", "")) != "":
		var bp := Vector3(float(row["ball_pred_x"]), float(row["ball_pred_y"]), float(row["ball_pred_z"]))
		var cp := Vector3(float(row["contact_point_x"]), float(row["contact_point_y"]), float(row["contact_point_z"]))
		markers = {"ball": bp, "body": cp, "distance": bp.distance_to(cp)}
	return {"player_id": pid, "name": String(actor.name), "arbiter": arb, "decision": dec, "row": row, "event": s.get("event", {}),
		"arbiter_row": s.get("arbiter", {}), "markers": markers}

func snapshot_text(actor: Node) -> String:
	var sn: Dictionary = snapshot(actor)
	if sn.is_empty():
		return "Overlay de animaciones: sin jugador"
	var lines: PackedStringArray = []
	lines.append("ANIMACIONES  [F3 ocultar · F4 jugador]  %s (id %d)" % [sn["name"], sn["player_id"]])
	var arb: Dictionary = sn["arbiter"]
	if not arb.is_empty():
		lines.append("Arbitro: nivel %d %s %s" % [arb["level"], arb["kind"], arb["clip"]])
		lines.append("  ultimo: %s" % arb["last"])
	var dec: Dictionary = sn["decision"]
	if dec.is_empty():
		lines.append("Sin decisiones registradas todavia")
	else:
		lines.append("Decision t%d: %s · %s · %s" % [dec["tick"], dec["family"], dec["requester"], dec["context"]])
		var row: Dictionary = dec.get("chosen_row", {})
		if row.is_empty():
			lines.append("  ninguno elegido: %s" % dec.get("reason", ""))
		else:
			lines.append("  ELEGIDO %s (%s) -> %s %s" % [row["segment_id"], row["variant"], row["result"], row["rejection_reason"]])
			lines.append("  fotogramas inicio %s · contacto %s · %s %s" % [row["frame_start"], row["frame_contact"], row["body_part"], row["foot"]])
			lines.append("  coste %s %s" % [_num(row["cost_total"]), JSON.stringify(row["cost_breakdown_json"]) if typeof(row["cost_breakdown_json"]) == TYPE_DICTIONARY else ""])
			lines.append("  error previsto %s m · correccion %s m · tolerancia %s (%s)" % [_num(row["spatial_error_m"]), _num(row["root_correction_m"]),
				_num(row["tolerance_applied"]), row["tolerance_reason"]])
		lines.append("  candidatos examinados %d · descartes %s" % [dec["examined"], JSON.stringify(dec["reasons"])])
		for c in dec["candidates"]:
			lines.append("   - %s: %s %s" % [c["variant"], c["rejection_reason"], _num(c["cost_total"])])
	var ev: Dictionary = sn["event"]
	if not ev.is_empty():
		lines.append("Ultimo evento t%s: %s %s -> %s %s (error %s m, tolerancia %s)" % [ev["tick"], ev["system_requester"], ev["variant"], ev["result"],
			ev["rejection_reason"], _num(ev["spatial_error_m"]), _num(ev["tolerance_applied"])])
	var mk: Dictionary = sn["markers"]
	if not mk.is_empty():
		lines.append("Distancia cuerpo-pelota prevista: %.3f m" % float(mk["distance"]))
	return "\n".join(lines)

static func _num(v: Variant) -> String:
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return "%.3f" % float(v)
	return str(v)

func _process(_delta: float) -> void:
	if not active:
		return
	_panel.text = snapshot_text(target())
	_canvas.queue_redraw()

## Marcadores en pantalla: punto del cuerpo, pelota prevista y la linea entre ambos con la distancia.
class _Markers:
	extends Control
	var overlay: AnimDebugOverlay = null

	func _draw() -> void:
		if overlay == null or not overlay.active or overlay.scene == null or overlay.scene.camera == null:
			return
		var cam: Camera3D = overlay.scene.camera
		var actor: Node = overlay.target()
		if actor is Node3D and not cam.is_position_behind((actor as Node3D).global_position):
			var p: Vector2 = cam.unproject_position((actor as Node3D).global_position + Vector3(0.0, 2.1, 0.0))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-7, -10), p + Vector2(7, -10), p]), COLOR_BODY)
		var mk: Dictionary = overlay.snapshot(actor).get("markers", {})
		if mk.is_empty():
			return
		var bp: Vector3 = mk["ball"]
		var cp: Vector3 = mk["body"]
		if cam.is_position_behind(bp) or cam.is_position_behind(cp):
			return
		var sb: Vector2 = cam.unproject_position(bp)
		var sc: Vector2 = cam.unproject_position(cp)
		var d: float = float(mk["distance"])
		var col: Color = COLOR_BAD if d > 0.30 else Color.WHITE
		draw_line(sc, sb, col, 2.0)
		draw_circle(sc, 6.0, COLOR_BODY)
		draw_rect(Rect2(sb - Vector2(6, 6), Vector2(12, 12)), COLOR_BALL)
		draw_string(ThemeDB.fallback_font, (sb + sc) * 0.5 + Vector2(8, -6), "%.2f m" % d, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
