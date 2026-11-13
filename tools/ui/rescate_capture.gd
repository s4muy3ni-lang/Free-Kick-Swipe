extends Node
## Capturas de los niveles de mecanismos del Rescate (revision visual): el nivel armado y, despues de la solucion, la
## pelota en la zona. RESC_OUT=<prefijo> RESC_LEVELS="5 8 12" xvfb-run -a godot --display-driver x11
##   --rendering-driver opengl3 --resolution 1280x720 --path . res://tools/ui/rescate_capture.tscn

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [OS.get_environment("RESC_OUT"), name])
	print("captura: ", name)

func _ready() -> void:
	var lv: PackedStringArray = OS.get_environment("RESC_LEVELS").split(" ", false)
	if lv.is_empty():
		lv = PackedStringArray(["5", "8", "12"])
	for s in lv:
		var d: Dictionary = MinigameCatalog.level("rescate", int(s))
		d["practice"] = true
		Minigame.next_def = d
		var g: Rescate = (load(Rescate.SCENE) as PackedScene).instantiate()
		add_child(g)
		for i in 10:
			await get_tree().process_frame
		g.start_match()
		for i in 90:
			await get_tree().process_frame
		await _shot("nivel%s" % s)
		for st in d.get("solution", []):
			if (st as Dictionary).has("tap"):
				g.mechs.touch(int(st["tap"]), true)
				g.mechs.touch(int(st["tap"]), false)
			elif (st as Dictionary).has("hold"):
				g.mechs.touch(int(st["hold"]), true)
				await get_tree().create_timer(float(st["for"])).timeout
				g.mechs.touch(int(st["hold"]), false)
			else:
				await get_tree().create_timer(float(st.get("wait", 0.5))).timeout
		await get_tree().create_timer(4.0).timeout
		await _shot("nivel%s_resuelto" % s)
		g.queue_free()
		await get_tree().process_frame
	get_tree().quit()
