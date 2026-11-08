class_name PerfSession
extends Node
## Medicion de rendimiento POR MOMENTO de la jugada (penales y tiros libres), pensada para el telefono: la persona juega con
## «Diag.» > «Medir» encendido y despues copia el informe (texto) para compararlo con la PC. No promete nada: solo registra
## lo que mide el motor en ese dispositivo.
##
## Momentos: apuntando, carrera, vuelo, red (1 s despues de que la pelota toca la red), estirada (arquero tirandose),
## despeje (pelota suelta), festejo (resultado en pantalla) y el resto. Por momento: cuadros, tiempo de cuadro medio, p95 y
## pico, tiempo de proceso y de fisica, llamadas de dibujo, primitivas, y el costo de cada sistema en ms por paso de fisica
## (Prof). Una vez por informe: memoria, nodos, AnimationPlayer, perfil grafico y, si el motor lo mide, tiempo de GPU.
##
## Mientras mide es el dueño de Prof (lo enciende y lo vacia en cada paso); al terminar lo deja como estaba.

const MOMENTS: Array[StringName] = [&"apuntando", &"carrera", &"vuelo", &"red", &"estirada", &"despeje", &"festejo", &"otro"]
const NET_WINDOW := 1.0

## Quien dice en que momento esta la jugada (SetPieceGame.perf_moment()).
var moment_source: Callable = Callable()
var recording: bool = false
var _buckets: Dictionary = {}
var _net_t: float = 0.0
var _prof_was: bool = false
var _started_ms: int = 0
var _gpu_on: bool = false

func start() -> void:
	_buckets.clear()
	for m in MOMENTS:
		_buckets[m] = _empty()
	_prof_was = Prof.enabled
	Prof.enabled = true
	Prof.reset()
	_started_ms = Time.get_ticks_msec()
	recording = true
	var vp: RID = get_viewport().get_viewport_rid() if is_inside_tree() else RID()
	if vp.is_valid():
		RenderingServer.viewport_set_measure_render_time(vp, true)
		_gpu_on = true

func stop() -> void:
	recording = false
	Prof.enabled = _prof_was
	Prof.reset()

## La pelota toco la red: los proximos NET_WINDOW s cuentan como «red».
func on_net_hit(_speed: float = 0.0) -> void:
	_net_t = NET_WINDOW

static func _empty() -> Dictionary:
	return {"frames": 0, "sum_ms": 0.0, "times": PackedFloat32Array(), "proc_ms": 0.0, "phys_ms": 0.0, "draws": 0.0, "prims": 0.0,
		"steps": 0, "prof": {}, "gpu_ms": 0.0, "gpu_n": 0}

func _process(delta: float) -> void:
	if not recording:
		return
	var m: StringName = _current()
	var b: Dictionary = _buckets[m]
	var ms: float = delta * 1000.0
	b["frames"] = int(b["frames"]) + 1
	b["sum_ms"] = float(b["sum_ms"]) + ms
	var ts: PackedFloat32Array = b["times"]
	if ts.size() < 4000:
		ts.append(ms)
		b["times"] = ts
	b["proc_ms"] = float(b["proc_ms"]) + Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	b["phys_ms"] = float(b["phys_ms"]) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	b["draws"] = float(b["draws"]) + Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	b["prims"] = float(b["prims"]) + Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	if _gpu_on:
		var g: float = RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		if g > 0.0:
			b["gpu_ms"] = float(b["gpu_ms"]) + g
			b["gpu_n"] = int(b["gpu_n"]) + 1

func _physics_process(delta: float) -> void:
	if not recording:
		return
	_net_t = maxf(_net_t - delta, 0.0)
	var b: Dictionary = _buckets[_current()]
	b["steps"] = int(b["steps"]) + 1
	var pr: Dictionary = b["prof"]
	for k in Prof.acc.keys():
		pr[k] = float(pr.get(k, 0.0)) + float(Prof.acc[k])
	Prof.reset()

func _current() -> StringName:
	if _net_t > 0.0:
		return &"red"
	if moment_source.is_valid():
		var m: StringName = moment_source.call()
		if _buckets.has(m):
			return m
	return &"otro"

## Resumen por momento (para el informe y las pruebas): {momento: {frames, avg_ms, p95_ms, max_ms, proc_ms, phys_ms,
## draws, prims, gpu_ms, systems: {sistema: ms por paso}}}.
func summary() -> Dictionary:
	var out := {}
	for m in MOMENTS:
		var b: Dictionary = _buckets.get(m, _empty())
		var n: int = int(b["frames"])
		if n == 0:
			continue
		var ts: PackedFloat32Array = (b["times"] as PackedFloat32Array).duplicate()
		ts.sort()
		var steps: int = maxi(int(b["steps"]), 1)
		var systems := {}
		var pr: Dictionary = b["prof"]
		for k in pr.keys():
			systems[String(k)] = float(pr[k]) / float(steps) / 1000.0
		out[String(m)] = {"frames": n, "avg_ms": float(b["sum_ms"]) / n, "p95_ms": ts[int((ts.size() - 1) * 0.95)] if ts.size() > 0 else 0.0,
			"max_ms": ts[ts.size() - 1] if ts.size() > 0 else 0.0, "proc_ms": float(b["proc_ms"]) / n, "phys_ms": float(b["phys_ms"]) / n,
			"draws": float(b["draws"]) / n, "prims": float(b["prims"]) / n,
			"gpu_ms": float(b["gpu_ms"]) / int(b["gpu_n"]) if int(b["gpu_n"]) > 0 else -1.0, "systems": systems}
	return out

## Informe en texto (lo que la persona copia y pega).
func report() -> String:
	var lines: PackedStringArray = []
	lines.append("FREE KICK SWIPE - informe de rendimiento")
	lines.append("dispositivo: %s | %s | %d nucleos | %s" % [OS.get_name(), OS.get_model_name(), OS.get_processor_count(), RenderingServer.get_video_adapter_name()])
	lines.append("motor: %s | render %s | pantalla %s | escala 3D %.0f %% | perfil %s | tope %d img/s" % [Engine.get_version_info().get("string", "?"),
		RenderingServer.get_current_rendering_method(), str(DisplayServer.window_get_size()), get_tree().root.scaling_3d_scale * 100.0 if is_inside_tree() else 0.0,
		GraphicsSettings.profile_name(), Engine.max_fps])
	lines.append("memoria estatica %.0f MB | video %.0f MB | nodos %d | AnimationPlayer %d | duracion %.0f s" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), count_animation_players(), (Time.get_ticks_msec() - _started_ms) / 1000.0])
	var s: Dictionary = summary()
	for m in s.keys():
		var d: Dictionary = s[m]
		var gpu: String = "%.1f" % float(d["gpu_ms"]) if float(d["gpu_ms"]) >= 0.0 else "no medido"
		lines.append("[%s] %d cuadros: medio %.1f ms (%.0f img/s), p95 %.1f, pico %.1f | proceso %.1f, fisica %.1f | dibujo %.0f llamadas, %.0f primitivas | GPU %s ms" % [
			m, int(d["frames"]), float(d["avg_ms"]), 1000.0 / maxf(float(d["avg_ms"]), 0.01), float(d["p95_ms"]), float(d["max_ms"]),
			float(d["proc_ms"]), float(d["phys_ms"]), float(d["draws"]), float(d["prims"]), gpu])
		var sys: Dictionary = d["systems"]
		var keys: Array = sys.keys()
		keys.sort_custom(func(a, b) -> bool: return float(sys[a]) > float(sys[b]))
		var parts: PackedStringArray = []
		for k in keys.slice(0, 8):
			parts.append("%s %.2f" % [k, float(sys[k])])
		if not parts.is_empty():
			lines.append("    sistemas (ms por paso de fisica): " + ", ".join(parts))
	return "\n".join(lines)

func count_animation_players() -> int:
	if not is_inside_tree():
		return 0
	return get_tree().root.find_children("*", "AnimationPlayer", true, false).size()

## Guarda el informe en user:// y devuelve la ruta.
func save_report() -> String:
	var path: String = "user://perf_%s.txt" % Time.get_datetime_string_from_system().replace(":", "-")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(report())
	f.close()
	return path
