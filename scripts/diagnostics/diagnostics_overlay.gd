class_name DiagnosticsOverlay
extends Label
## Superposicion de diagnostico: FPS, tiempo de fotograma (media y peor reciente), tiempos de proceso y
## fisica, llamadas de dibujo, triangulos, nodos, memoria y errores/avisos capturados con un Logger.
## No promete rendimiento: muestra lo que realmente se mide en el dispositivo.

## Logger propio: cuenta errores y avisos del motor y guarda los ultimos mensajes.
class CaptureLogger:
	extends Logger
	var errors: int = 0
	var warnings: int = 0
	var last_errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings += 1
		else:
			errors += 1
			var msg: String = "%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line]
			last_errors.append(msg)
			if last_errors.size() > 3:
				last_errors.pop_front()
		_mutex.unlock()

	func snapshot() -> Dictionary:
		_mutex.lock()
		var d: Dictionary = {"errors": errors, "warnings": warnings, "last": last_errors.duplicate()}
		_mutex.unlock()
		return d

static var _logger: CaptureLogger = null

var _frame_times: Array[float] = []
var _acc: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
	if _logger == null:
		_logger = CaptureLogger.new()
		OS.add_logger(_logger)

## Costo por sistema (Prof): visible el diagnostico, se mide y se muestran los que mas tardan por paso de fisica (en el
## telefono de la persona, que es donde importa). Oculto, Prof vuelve a apagarse (si lo encendio el diagnostico).
var _prof_owned: bool = false
var _prof_frame0: int = 0
var _prof_lines: PackedStringArray = []

func _process(delta: float) -> void:
	_frame_times.append(delta * 1000.0)
	if _frame_times.size() > 120:
		_frame_times.pop_front()
	if visible and not Prof.enabled:
		Prof.enabled = true
		Prof.reset()
		_prof_owned = true
		_prof_frame0 = Engine.get_physics_frames()
	elif not visible and _prof_owned:
		Prof.enabled = false
		_prof_owned = false
	_acc += delta
	if _acc < 0.4 or not visible:
		return
	_acc = 0.0
	if _prof_owned:
		_prof_lines = _prof_report()
	text = build_report()

## Los sistemas que mas tardaron desde el ultimo informe (ms por paso de fisica) y se empieza de nuevo.
func _prof_report() -> PackedStringArray:
	var steps: int = maxi(Engine.get_physics_frames() - _prof_frame0, 1)
	_prof_frame0 = Engine.get_physics_frames()
	var keys: Array = Prof.acc.keys()
	keys.sort_custom(func(a, b) -> bool: return int(Prof.acc[a]) > int(Prof.acc[b]))
	var out: PackedStringArray = []
	for k in keys.slice(0, 7):
		out.append("  %s %.2f ms" % [String(k), float(Prof.acc[k]) / steps / 1000.0])
	Prof.reset()
	return out

func build_report() -> String:
	var avg: float = 0.0
	var worst: float = 0.0
	for t in _frame_times:
		avg += t
		worst = maxf(worst, t)
	avg /= maxf(_frame_times.size(), 1)
	var log_info: Dictionary = _logger.snapshot() if _logger != null else {"errors": 0, "warnings": 0, "last": []}
	var lines: PackedStringArray = []
	lines.append("FPS %d | frame %.1f ms (pico %.1f)" % [Engine.get_frames_per_second(), avg, worst])
	lines.append("proceso %.1f ms | fisica %.1f ms" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	lines.append("dibujo: %d llamadas, %d primitivas" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	lines.append("nodos %d | memoria %.0f MB" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	lines.append("perfil: %s | res3D %.0f %% | tope %d img/s | sombras %s" % [GraphicsSettings.profile_name(), get_tree().root.scaling_3d_scale * 100.0, Engine.max_fps, "si" if GraphicsSettings.shadows_enabled() else "no"])
	if not _prof_lines.is_empty():
		lines.append("sistemas (ms por paso de fisica):")
		lines.append_array(_prof_lines)
	lines.append("errores %d | avisos %d" % [log_info["errors"], log_info["warnings"]])
	for m in log_info["last"]:
		lines.append("  ! " + str(m))
	return "\n".join(lines)

## Estadisticas de fotograma para informes de rendimiento (usado por la herramienta de benchmark).
func frame_stats() -> Dictionary:
	var sorted: Array[float] = _frame_times.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return {}
	var avg: float = 0.0
	for t in sorted:
		avg += t
	avg /= sorted.size()
	return {"avg_ms": avg, "p95_ms": sorted[int(sorted.size() * 0.95)], "max_ms": sorted[sorted.size() - 1], "samples": sorted.size()}
