extends Node3D
## Vista previa de los diseños del uniforme (personalizacion): varios jugadores de frente, cada uno con un diseño.
## Uso: KIT_OUT=/tmp/kits.png xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --resolution 1600x720 \
##   --path . res://tools/online/kit_preview.tscn

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.14, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -20, 0)
	add_child(sun)
	var designs := [[0, 0, 0, 0], [1, 1, 1, 0], [2, 2, 2, 1], [3, 0, 1, 2], [4, 1, 0, 0], [5, 2, 2, 1], [6, 0, 1, 0]]
	for i in designs.size():
		var a := SpActor.new()
		add_child(a)
		var d: Array = designs[i]
		a.build({"jersey": PlayerCustom.JERSEYS[i % 10], "jersey2": Color(0.95, 0.95, 0.95), "shorts": Color(0.06, 0.06, 0.08),
			"socks": PlayerCustom.JERSEYS[i % 10], "boots": Color(0.9, 0.5, 0.1), "skin": PlayerCustom.SKINS[2],
			"hair": PlayerCustom.HAIRS[0], "jersey_pattern": d[0], "shorts_pattern": d[1], "socks_pattern": d[2], "sock_height": d[3]})
		a.global_position = Vector3(0, 0, -6.3 + i * 2.1)
		a.set_facing(Vector3(1, 0, 0))
		var idles: Array[StringName] = SpClips.by_role(&"idle_ready", false)
		if not idles.is_empty():
			a.play_loop(idles[0])
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(9.0, 1.2, 0)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	cam.fov = 50
	cam.current = true
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out: String = OS.get_environment("KIT_OUT") if OS.get_environment("KIT_OUT") != "" else "/tmp/kits.png"
	get_viewport().get_texture().get_image().save_png(out)
	print("captura: ", out)
	get_tree().quit()
