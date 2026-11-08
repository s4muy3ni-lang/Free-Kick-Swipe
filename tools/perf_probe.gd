extends Node
## Mide el costo de CPU de un partido con IA en los dos equipos (sin dibujar: lo que pesa en un telefono con la grafica al
## minimo). Por imagen: tiempo total de fisica y de proceso (Performance) y el de cada sistema instrumentado con Prof.
## Uso: godot --headless --path . res://tools/perf_probe.tscn   (PERF_SECONDS, PERF_ABLATE=anim|ai|ik|net)

func _ready() -> void:
	var secs: float = float(OS.get_environment("PERF_SECONDS")) if OS.get_environment("PERF_SECONDS") != "" else 15.0
	var ablate: String = OS.get_environment("PERF_ABLATE")
	var m: MatchScene = (load("res://scenes/main/match.tscn") as PackedScene).instantiate()
	m.duration_seconds = 0.0
	m.intro_seconds = 0.0
	add_child(m)
	for i in 10:
		await get_tree().physics_frame
	m.home[0].input_source = AIInput.new(3, 0.6)
	m.home[0].is_human_controlled = false
	m.controlled = null
	print("PERF arranque listo")
	for i in 120:
		await get_tree().physics_frame
	print("PERF midiendo")
	if ablate == "anim":
		for f in m.home + m.away:
			if f.visual != null and f.visual.anim_tree != null:
				f.visual.anim_tree.active = false
	# PERF_ANIM_MANUAL=1: los AnimationTree se avanzan desde aqui (modo manual) para medir su costo con Prof.
	var manual_trees: Array[AnimationTree] = []
	if OS.get_environment("PERF_ANIM_MANUAL") == "1":
		for t in get_tree().root.find_children("*", "AnimationTree", true, false):
			var at: AnimationTree = t as AnimationTree
			if at.active:
				at.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				manual_trees.append(at)
		print("PERF AnimationTree en modo manual: %d" % manual_trees.size())
	# Sucesos del partido por imagen (para saber que paso en las imagenes lentas: gol, saque, repeticion...).
	var events: Dictionary = {}
	var counter := [0]
	m.ctx.event_emitted.connect(func(e: GameEvent) -> void:
		var k: int = counter[0]
		if not events.has(k):
			events[k] = []
		(events[k] as Array).append(GameEvent.Type.keys()[e.type]))
	Prof.enabled = true
	Prof.reset()
	# Performance.TIME_PHYSICS_PROCESS es el MAXIMO del ultimo segundo, no la media: se mide el tiempo real de cada imagen
	# (con --fixed-fps 60 hay exactamente un paso de fisica por imagen) y se resta lo instrumentado.
	var n := 0
	var frames: Array[float] = []
	var last: int = Time.get_ticks_usec()
	var t0: int = last
	var worst_ms := 0.0
	var worst_frame: Dictionary = {}
	var spikes: Array = []
	while n < int(secs * 60.0):
		await get_tree().physics_frame
		if not manual_trees.is_empty():
			Prof.begin(&"AnimationTree (todos)")
			for at in manual_trees:
				if is_instance_valid(at):
					at.advance(1.0 / 60.0)
			Prof.end(&"AnimationTree (todos)")
		var now: int = Time.get_ticks_usec()
		var ft: float = float(now - last) / 1000.0
		frames.append(ft)
		if ft > worst_ms:
			worst_ms = ft
			worst_frame = Prof.frame.duplicate()
		if ft > 12.0:
			var near: Array = []
			for dk in range(-2, 3):
				if events.has(n + dk):
					near.append_array(events[n + dk])
			near.append("estado %s%s%s" % [MatchManager.State.keys()[m.manager.state], " repeticion" if (m.replay != null and m.replay.playing) else "", " pausa" if get_tree().paused else ""])
			spikes.append([n, ft, Prof.frame.duplicate(), near])
		Prof.frame.clear()
		last = now
		n += 1
		counter[0] = n
	var wall: float = float(Time.get_ticks_usec() - t0) / 1e6
	frames.sort()
	var mean: float = wall * 1000.0 / n
	var p95: float = frames[int(n * 0.95)]
	var worst: float = frames[n - 1]
	print("PERF %s: %d imagenes en %.2f s | imagen media %.2f ms, p95 %.2f ms, peor %.1f ms" % [ablate if ablate != "" else "base", n, wall, mean, p95, worst])
	var keys: Array = Prof.acc.keys()
	keys.sort_custom(func(a, b) -> bool: return int(Prof.acc[a]) > int(Prof.acc[b]))
	var top := 0.0
	for k in keys:
		var ms: float = float(Prof.acc[k]) / n / 1000.0
		print("PERF   %-30s %.3f ms por imagen (%d llamadas, %.3f ms por llamada)" % [String(k), ms, int(Prof.calls.get(k, 0)), float(Prof.acc[k]) / maxf(float(Prof.calls.get(k, 1)), 1.0) / 1000.0])
	# Lo que no esta instrumentado: paso del motor de fisica (Jolt), AnimationTree y esqueletos, nodos sin etiqueta.
	for k in ["jugadores (total)", "arqueros", "arbitro", "camara", "red del arco", "partido (MatchManager)", "repeticion",
			"escena (marcadores, cambio)", "pelota (integrate_forces)", "pelota (visual)", "pelota (script fisica)", "arco (gol)",
			"pose procedural", "IK de pie", "AnimationTree (todos)"]:
		top += float(Prof.acc.get(StringName(k), 0)) / n / 1000.0
	print("PERF   %-30s %.3f ms por imagen" % ["(sin instrumentar)", mean - top])
	print("PERF dibujo: %d llamadas, %d objetos, %d primitivas por imagen; nodos %d; cuerpos fisicos activos %d" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))])
	_count_meshes()
	print("PERF imagen mas lenta (%.1f ms): %s" % [worst_ms, _fmt(worst_frame)])
	print("PERF imagenes de mas de 12 ms: %d" % spikes.size())
	spikes.sort_custom(func(a, b) -> bool: return float(a[1]) > float(b[1]))
	for sp in spikes.slice(0, 12):
		print("PERF   imagen %d (%.1f ms): %s%s" % [sp[0], sp[1], _fmt(sp[2]), (" | sucesos: %s" % str(sp[3])) if not (sp[3] as Array).is_empty() else ""])
	# Costo de apagar y volver a encender los AnimationTree (lo hace la repeticion de gol al empezar y al terminar).
	var trees: Array = get_tree().root.find_children("*", "AnimationTree", true, false)
	var t_off: int = Time.get_ticks_usec()
	for t in trees:
		(t as AnimationTree).active = false
	var t_on: int = Time.get_ticks_usec()
	for t in trees:
		(t as AnimationTree).active = true
	await get_tree().process_frame
	var t_end: int = Time.get_ticks_usec()
	print("PERF AnimationTree x%d: apagar %.1f ms, encender y primer proceso %.1f ms" % [trees.size(), float(t_on - t_off) / 1000.0, float(t_end - t_on) / 1000.0])
	get_tree().quit()

func _fmt(d: Dictionary) -> String:
	var ks: Array = d.keys()
	ks.sort_custom(func(a, b) -> bool: return int(d[a]) > int(d[b]))
	var parts: PackedStringArray = []
	for k in ks.slice(0, 6):
		parts.append("%s %.1f" % [String(k), float(d[k]) / 1000.0])
	return ", ".join(parts)

## Que hay en la escena: mallas por grupo de primer nivel (cancha, jugadores, publico...), con sombra o sin ella.
func _count_meshes() -> void:
	var groups: Dictionary = {}
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var path: String = str(g.get_path())
		var parts: PackedStringArray = path.split("/")
		var key: String = "/".join(parts.slice(3, 5)) if parts.size() > 4 else path
		if not groups.has(key):
			groups[key] = [0, 0, 0]
		groups[key][0] += 1
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			groups[key][1] += 1
		if g is MultiMeshInstance3D:
			groups[key][2] += (g as MultiMeshInstance3D).multimesh.instance_count if (g as MultiMeshInstance3D).multimesh != null else 0
	var ks: Array = groups.keys()
	ks.sort_custom(func(a, b) -> bool: return int(groups[a][0]) > int(groups[b][0]))
	for k in ks.slice(0, 25):
		print("PERF   mallas %-50s %4d (con sombra %d, instancias multimesh %d)" % [k, groups[k][0], groups[k][1], groups[k][2]])
