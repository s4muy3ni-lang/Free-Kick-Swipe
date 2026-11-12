extends Node
## Captura del numero de la espalda (revision visual): tres jugadores de espaldas, quieto, corriendo y pateando, con el
## cuerpo de AnimBank (ANIM_BODY=tripo|humano). NUM_OUT=<prefijo> [NUM_N=10] xvfb-run -a godot --display-driver x11
##   --rendering-driver opengl3 --resolution 900x600 --path . res://tools/ui/number_capture.tscn

func _ready() -> void:
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.5, 0.35)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 150, 0)
	world.add_child(sun)
	var cam := Camera3D.new()
	world.add_child(cam)
	var shots := [["idle", &"", 0.0], ["run", &"", 0.3], ["kick", &"", 0.5]]
	var kit: Dictionary = PlayerCustom.kit()
	var out: String = OS.get_environment("NUM_OUT")
	var n: int = int(OS.get_environment("NUM_N")) if OS.get_environment("NUM_N") != "" else 10
	var actors: Array = []
	for i in 3:
		var a := SpActor.new()
		a.role = &"shooter"
		world.add_child(a)
		a.build(kit)
		a.set_back_number(n)
		a.position = Vector3(i * 1.6 - 1.6, 0, 0)
		a.set_facing(Vector3(0, 0, -1))
		actors.append(a)
	var run: Array = SpClips.by_role(&"run", false)
	if run.is_empty():
		run = SpClips.by_role(&"jog", false)
	var kicks: Array = SpClips.by_role(&"kick_shot_hard", false)
	if kicks.is_empty():
		kicks = SpClips.by_role(&"kick", false)
	print("run ", run.slice(0, 2), " kicks ", kicks.slice(0, 2), " printed ", (actors[0] as SpActor).printed_number())
	if not run.is_empty():
		(actors[1] as SpActor).play_loop(run[0], 0.0)
	if not kicks.is_empty():
		(actors[2] as SpActor).play_clip(kicks[0], actors[2].position, Vector3(0, 0, -1), 0.0)
	cam.position = Vector3(0, 1.5, 3.4)
	cam.look_at(Vector3(0, 1.1, 0))
	cam.fov = 50
	for k in [12, 30]:
		for i in k:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, k])
	get_tree().quit()
