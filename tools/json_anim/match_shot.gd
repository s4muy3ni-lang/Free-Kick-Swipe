extends Node
## Capturas del partido completo (camara de transmision) en el modo 4 para revisar a ojo como se ven los modelos a la escala de
## juego. Necesita render: SHOTS=6,12,20 OUT=/tmp/m xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path .
## res://tools/json_anim/match_shot.tscn (guarda /tmp/m_<segundo>.png). Env: MODE (4), SHOTS (segundos separados por coma), W/H.

func _ready() -> void:
	Tuning.gameplay_mode = int(OS.get_environment("MODE")) if OS.get_environment("MODE") != "" else 4
	PackLibrary.reload()
	var w: int = int(OS.get_environment("W")) if OS.get_environment("W") != "" else 1280
	var h: int = int(OS.get_environment("H")) if OS.get_environment("H") != "" else 720
	get_window().size = Vector2i(w, h)
	var m: MatchScene = (load("res://scenes/main/match.tscn") as PackedScene).instantiate()
	m.duration_seconds = 0.0
	m.auto_switch = false
	add_child(m)
	get_viewport().size = Vector2i(w, h)
	await get_tree().physics_frame
	m.home[0].input_source = AIInput.new(3, 0.6)
	m.home[0].is_human_controlled = false
	var shots: PackedStringArray = (OS.get_environment("SHOTS") if OS.get_environment("SHOTS") != "" else "8,16").split(",")
	var out: String = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/match"
	var t := 0
	for s in shots:
		var frames: int = int(float(s) * 60.0)
		while t < frames:
			await get_tree().physics_frame
			t += 1
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s_%s.png" % [out, s])
		print("MATCHSHOT %s_%s.png" % [out, s])
	get_tree().quit()
