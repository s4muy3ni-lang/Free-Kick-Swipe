extends Node
## Hoja de contacto de la patada procedural sobre una pose base (idle). Env: POWER, SIDE (1/-1), VIEW, OUT
const CELL := Vector2i(300, 440)
func _ready() -> void:
	var power: float = float(OS.get_environment("POWER")) if OS.get_environment("POWER") != "" else 0.8
	var side: int = int(OS.get_environment("SIDE")) if OS.get_environment("SIDE") != "" else 1
	var view: String = OS.get_environment("VIEW") if OS.get_environment("VIEW") != "" else "side"
	var out_path: String = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/kick.png"
	get_window().size = CELL
	get_viewport().size = CELL
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mi.mesh = plane
	floor_mi.material_override = MeshUtil.flat_material(Color(0.12, 0.3, 0.16), 1.0)
	add_child(floor_mi)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.2, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var vis := FootballerVisual.new()
	add_child(vis)
	vis.build(FootballerVisual.default_kit(0))
	vis.anim_tree.active = false
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	var target := Vector3(0, 0.9, 0)
	match view:
		"front": cam.look_at_from_position(Vector3(0, 1.1, -5.2), target, Vector3.UP)
		"three": cam.look_at_from_position(Vector3(3.4, 1.7, -3.8), target, Vector3.UP)
		_: cam.look_at_from_position(Vector3(-5.4, 1.0, 0.0), target, Vector3.UP)
	cam.current = true
	var base: Animation = vis.anim_player.get_animation("idle")
	var bm: Dictionary = PoseSampler.bind(base, vis.skeleton)
	var contact: float = 0.14
	vis.pose_modifier.active = false   # la herramienta posa a mano; el modificador no debe avanzar solo
	vis.pose_modifier.start_kick(contact, power, side)
	var times: Array[float] = [0.0, contact * 0.35, contact * 0.62, contact * 0.85, contact, contact + 0.08, contact + 0.16, contact + 0.35]
	var sheet := Image.create(CELL.x * times.size(), CELL.y, false, Image.FORMAT_RGBA8)
	for i in times.size():
		PoseSampler.apply(base, vis.skeleton, bm, 1.0)
		vis.pose_modifier.apply_at(times[i])
		for f in 4:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, CELL.x, CELL.y), Vector2i(CELL.x * i, 0))
	sheet.save_png(out_path)
	print("KICK saved ", out_path)
	get_tree().quit()
