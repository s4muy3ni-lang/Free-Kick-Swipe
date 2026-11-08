extends Node
## Reforma, Fase 1: capturas del banco de pruebas (requiere render: xvfb-run ... --rendering-driver opengl3).
## Para cada caso (banco, categoria, cuerpo) reproduce el primer clip, espera al instante pedido y guarda una captura y las
## mediciones en vivo. Uso:
##   xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --resolution 1280x720 --path . \
##     res://tools/reforma/bench_captures.tscn -- --out <directorio>
## (Es una escena y no un --script: los scripts del juego usan el autoload Tuning, que con --script no existe al compilar.)
const CASES := [
	["json", "st_setpiece", false], ["json", "st_penalty", false], ["json", "gk_dive_left", false], ["json", "wa_jump", false],
]
var out_dir: String = "user://capturas"
## Cantidad maxima de casos (--max N): para revisar rapido otras resoluciones.
var max_cases: int = 1000
var bench: AnimBankBench
var results: Array = []

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
		if args[i] == "--max" and i + 1 < args.size():
			max_cases = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	bench = (load("res://scenes/dev/anim_bank_bench.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(bench)
	_run()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run() -> void:
	await _frames(5)
	for c in CASES.slice(0, max_cases):
		bench.repeat = false
		bench.original_body = c[2]
		bench.select_bank(c[0])
		bench.select_category(c[1])
		var e: Dictionary = bench.current
		var t_cap: float = 0.0
		if e.is_empty():
			await _frames(3)
		else:
			t_cap = float(e["contacto"]["t"]) if e.has("contacto") else float(e["duracion"]) * 0.55
			var waited: float = 0.0
			while waited < float(e["duracion"]) + 0.2:
				await get_tree().process_frame
				waited += 1.0 / 60.0
				if bench.anim_player.current_animation != "" and bench.anim_player.current_animation_position >= t_cap:
					break
			await _frames(1)
		var img: Image = get_viewport().get_texture().get_image()
		var name: String = "%s_%s_%s.png" % [c[0], c[1], "original" if c[2] else "comun"]
		print("caso ", name, " ms=", Time.get_ticks_msec())
		img.save_png(out_dir + "/" + name)
		var m: Dictionary = bench.metrics.duplicate()
		m.erase("_hips0")
		m.erase("marcador_manos")
		results.append({"banco": c[0], "categoria": c[1], "cuerpo": "original" if c[2] else "comun", "clip": e.get("id", "sin clip"),
			"captura": name, "t": t_cap, "medido": m})
		# Termina el clip para tener las mediciones completas.
		if not e.is_empty():
			var w: float = 0.0
			while bench.anim_player.current_animation != "" and w < float(e["duracion"]) + 0.5:
				await get_tree().process_frame
				w += 1.0 / 60.0
			var m2: Dictionary = bench.metrics.duplicate()
			m2.erase("_hips0")
			m2.erase("marcador_manos")
			results[-1]["medido_clip_completo"] = m2
	var f := FileAccess.open(out_dir + "/mediciones.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, " "))
	f.close()
	print("CAPTURAS listas: ", out_dir)
	get_tree().quit()
