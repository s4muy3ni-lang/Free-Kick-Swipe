extends Node3D
## Hojas visuales de clips sin nombre funcional suficiente. Solo lee recursos; no cambia el banco.
## IDS=/ruta/ids.json OUT_DIR=/ruta xvfb-run -a godot ... res://tools/integration/inspect_pending.tscn
const CELL := Vector2i(230, 260)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()
	get_window().size = CELL
	get_viewport().size = CELL
	var model: Node3D = (load(JsonCatalog.HUMAN_SCENE) as PackedScene).instantiate()
	model.scale = Vector3.ONE * 1.75
	add_child(model)
	var skeleton: Skeleton3D = model.get_node(JsonRig.SKELETON_PATH)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = MeshUtil.flat_material(Color(0.3, 0.65, 0.95), 0.8)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.12, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(3, 1.6, 3), Vector3(0, 0.85, 0))
	camera.fov = 35
	camera.current = true
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 15)
	add_child(label)
	var ids: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("IDS")))
	var out_dir: String = OS.get_environment("OUT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var page: Image = null
	for row in ids.size():
		if row % 8 == 0:
			page = Image.create(CELL.x * 4, CELL.y * 8, false, Image.FORMAT_RGB8)
		var id := StringName(ids[row])
		var animation: Animation = PackLibrary.clip(id)
		var binding: Dictionary = PoseSampler.bind(animation, skeleton)
		for col in 4:
			skeleton.reset_bone_poses()
			var time: float = animation.length * (float(col) / 3.0) * 0.999
			PoseSampler.apply(animation, skeleton, binding, time)
			label.text = "%s\n%.2f s" % [id, time]
			await get_tree().process_frame
			await get_tree().process_frame
			var frame: Image = get_viewport().get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			page.blit_rect(frame, Rect2i(Vector2i.ZERO, CELL), Vector2i(col * CELL.x, (row % 8) * CELL.y))
		if row % 8 == 7 or row == ids.size() - 1:
			page.save_png(out_dir.path_join("page_%02d.png" % (row / 8)))
	print("Hojas guardadas: ", ids.size(), " clips -> ", out_dir)
	get_tree().quit()
