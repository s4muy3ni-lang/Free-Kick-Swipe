extends Node
## Capturas de los niveles de mecanismos del Rescate (revision visual): el nivel armado, el escenario girado y, despues
## de patear la solucion (tiros reales), la dorada en la zona. RESC_OUT=<prefijo> RESC_LEVELS="5 8 12"
## xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --resolution 1280x720 --path . \
##   res://tools/ui/rescate_capture.tscn

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [OS.get_environment("RESC_OUT"), name])
	print("captura: ", name)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _ready() -> void:
	var lv: PackedStringArray = OS.get_environment("RESC_LEVELS").split(" ", false)
	if lv.is_empty():
		lv = PackedStringArray(["5", "10", "14"])
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
		var k: int = 0
		for st in d.get("solution", []):
			var sd: Dictionary = st
			if int(sd.get("rot", 0)) != k:
				k = int(sd.get("rot", 0))
				await g.rotate_to(k)
				await _wait(0.4)
				await _shot("nivel%s_giro%d" % [s, k])
			var target: Vector3
			if sd.has("hit"):
				target = g.mechs.aim_of(int(sd["hit"]))
			elif sd.has("push"):
				target = g.crates[int(sd["push"])].global_position
			else:
				target = g.dominoes[int(sd["domino"])].global_position
			var it: Dictionary = g.cpu_shot(target, float(sd.get("speed", 16.0)), 0.0, 0.0)
			g.apply_intent({"side": 0, "v": it["v"], "w": it["w"]})
			var n: int = 0
			while g.state != Minigame.State.AIM and g.state != Minigame.State.OVER and n < 900:
				await get_tree().process_frame
				n += 1
		await _wait(2.0)
		await _shot("nivel%s_resuelto" % s)
		g.queue_free()
		await get_tree().process_frame
	get_tree().quit()
