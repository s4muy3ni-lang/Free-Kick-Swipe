extends Node
## Ejecuta una escena con entradas programadas y guarda capturas en instantes concretos.
## Variables de entorno:
##   SHOT_SCENE  escena a cargar (por defecto el partido)
##   SHOT_INPUT  "t:accion:fuerza:duracion;..."  ej. "0.5:move_right:1:6;2:sprint:1:4"  (tiempos en s de simulacion)
##   SHOT_TIMES  instantes de captura, ej. "2,4,6"
##   SHOT_OUT    prefijo de salida, ej. /tmp/shot  -> /tmp/shot_1.png ...
##   FUTBOL5_TOUCH=1 muestra los controles tactiles
## Uso: xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/shot_runner.tscn

func _ready() -> void:
	var scene_path: String = OS.get_environment("SHOT_SCENE") if OS.get_environment("SHOT_SCENE") != "" else "res://scenes/main/match.tscn"
	var out_prefix: String = OS.get_environment("SHOT_OUT") if OS.get_environment("SHOT_OUT") != "" else "/tmp/shot"
	var times: PackedStringArray = (OS.get_environment("SHOT_TIMES") if OS.get_environment("SHOT_TIMES") != "" else "3").split(",")
	var events: Array = []
	for item in (OS.get_environment("SHOT_INPUT")).split(";", false):
		var p: PackedStringArray = item.split(":")
		if p.size() >= 2:
			events.append({"t": float(p[0]), "action": p[1], "strength": float(p[2]) if p.size() > 2 else 1.0,
				"dur": float(p[3]) if p.size() > 3 else 0.1, "on": false, "off": false})
	var inst: Node = (load(scene_path) as PackedScene).instantiate()
	add_child(inst)
	var shots: Array[float] = []
	for t in times:
		shots.append(float(t))
	var frame: int = 0
	var shot_i: int = 0
	var last_t: float = shots.max() + 0.05
	while float(frame) / 60.0 <= last_t:
		await get_tree().physics_frame
		frame += 1
		var now: float = float(frame) / 60.0
		for e in events:
			if not e["on"] and now >= e["t"]:
				e["on"] = true
				Input.action_press(e["action"], e["strength"])
			if e["on"] and not e["off"] and now >= e["t"] + e["dur"]:
				e["off"] = true
				Input.action_release(e["action"])
		if shot_i < shots.size() and now >= shots[shot_i]:
			await get_tree().process_frame
			await get_tree().process_frame
			var img: Image = get_viewport().get_texture().get_image()
			var path: String = "%s_%d.png" % [out_prefix, shot_i + 1]
			img.save_png(path)
			print("SHOT t=%.2f -> %s" % [now, path])
			shot_i += 1
	get_tree().quit()
