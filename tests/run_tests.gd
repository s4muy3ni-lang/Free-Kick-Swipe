extends Node
## Ejecutor de pruebas headless (escena tests/run_tests.tscn, con autoloads disponibles).
##   godot --headless --fixed-fps 60 --path . res://tests/run_tests.tscn
##   godot --headless --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter ball
##   godot --headless --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter dribble_reference::test_gentle
## TEST_GAMEPLAY_MODE=4 las ejecuta con el modo de jugabilidad indicado (las pruebas de pelota y pies animados valen para el modo 4:
## xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter live_feet).
## (con "::", la parte de la derecha filtra tambien el nombre del metodo).
## Sale con codigo 1 si alguna prueba falla (apto para CI).
## Una prueba que no ejecuta ninguna comprobacion se considera FALLIDA (suele indicar un error de script).

func _ready() -> void:
	# Ventana con la resolucion base del juego: los controles tactiles se posicionan respecto a ella.
	get_window().size = Vector2i(1280, 720)
	_run.call_deferred()

func _run() -> void:
	var filter: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--filter" and i + 1 < args.size():
			filter = args[i + 1]
	var method_filter: String = ""
	if filter.contains("::"):
		method_filter = filter.get_slice("::", 1)
		filter = filter.get_slice("::", 0)
	var files: PackedStringArray = DirAccess.get_files_at("res://tests")
	files.sort()
	var total_tests: int = 0
	var failed_tests: int = 0
	var skipped_tests: int = 0
	var total_checks: int = 0
	var started: int = Time.get_ticks_msec()
	for f in files:
		if not f.begins_with("test_") or not f.ends_with(".gd") or f == "test_case.gd":
			continue
		if filter != "" and not f.contains(filter):
			continue
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			printerr("[ERROR] no se pudo compilar %s" % f)
			failed_tests += 1
			total_tests += 1
			continue
		var probe: RefCounted = script.new()
		var methods: Array[String] = []
		for m in probe.get_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_") and (method_filter == "" or mname.contains(method_filter)):
				methods.append(mname)
		methods.sort()
		for mname in methods:
			var t: TestCase = script.new()
			# Cada prueba empieza en su modo: el del juego (4) salvo que la prueba declare otro (sistemas de modos descartados)
			# o TEST_GAMEPLAY_MODE lo cambie.
			var mode: int = t.gameplay_mode()
			if mode == 0:
				mode = int(OS.get_environment("TEST_GAMEPLAY_MODE")) if OS.get_environment("TEST_GAMEPLAY_MODE") != "" else Tuning.DEFAULT_GAMEPLAY_MODE
			if Tuning.gameplay_mode != mode:
				Tuning.gameplay_mode = mode
				PackLibrary.reload()
			t.tree = get_tree()
			total_tests += 1
			var t0: int = Time.get_ticks_msec()
			t.begin()
			await t.call(mname)
			t.cleanup()
			t.end()
			await get_tree().physics_frame
			if t.skipped:
				skipped_tests += 1
				print("[SKIP] %s::%s (%s)" % [f.get_basename(), mname, t.skip_reason])
				continue
			total_checks += t.checks
			var dt: int = Time.get_ticks_msec() - t0
			if t.checks == 0:
				t.failures.append("la prueba no ejecuto ninguna comprobacion (error de script?)")
			if t.failures.is_empty():
				print("[ OK ] %s::%s (%d checks, %d ms)" % [f.get_basename(), mname, t.checks, dt])
			else:
				failed_tests += 1
				print("[FAIL] %s::%s" % [f.get_basename(), mname])
				for msg in t.failures:
					print("       - %s" % msg)
	var elapsed: float = (Time.get_ticks_msec() - started) / 1000.0
	print("")
	print("Resumen: %d pruebas, %d fallidas, %d omitidas, %d comprobaciones, %.1f s" % [total_tests, failed_tests, skipped_tests, total_checks, elapsed])
	get_tree().quit(1 if failed_tests > 0 else 0)
