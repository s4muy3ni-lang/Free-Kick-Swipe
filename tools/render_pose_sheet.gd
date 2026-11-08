extends Node
## Hoja de contacto de poses del futbolista (para verificar deformaciones y animaciones).
## Variables de entorno: POSES="walk:0.0,run:0.3" SHEET_OUT=/ruta.png VIEW=side|front|back|three
## Uso: xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/render_pose_sheet.tscn

const CELL := Vector2i(420, 520)

func _ready() -> void:
	var specs: PackedStringArray = (OS.get_environment("POSES") if OS.get_environment("POSES") != "" else "idle:0.0,walk:0.0,walk:0.6,run:0.0,run:0.3,run:0.6").split(",")
	var view: String = OS.get_environment("VIEW") if OS.get_environment("VIEW") != "" else "side"
	var out_path: String = OS.get_environment("SHEET_OUT") if OS.get_environment("SHEET_OUT") != "" else "/tmp/pose_sheet.png"
	var kit_team: int = int(OS.get_environment("KIT_TEAM")) if OS.get_environment("KIT_TEAM") != "" else 0
	get_window().size = Vector2i(CELL.x, CELL.y)
	get_viewport().size = Vector2i(CELL.x, CELL.y)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mi.mesh = plane
	floor_mi.material_override = MeshUtil.flat_material(Color(0.12, 0.3, 0.16), 1.0)
	add_child(floor_mi)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.0
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.2, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var vis := FootballerVisual.new()
	add_child(vis)
	vis.build(FootballerVisual.default_kit(kit_team))
	var cam := Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	var target := Vector3(0, 0.9, 0)
	match view:
		"front": cam.look_at_from_position(Vector3(0, 1.1, -5.0), target, Vector3.UP)
		"back": cam.look_at_from_position(Vector3(0, 1.1, 5.0), target, Vector3.UP)
		"three": cam.look_at_from_position(Vector3(3.2, 1.6, -3.6), target, Vector3.UP)
		_: cam.look_at_from_position(Vector3(-5.6, 1.0, 0.0), target, Vector3.UP)
	cam.current = true
	if vis.anim_tree != null:
		vis.anim_tree.active = false
	var sheet := Image.create(CELL.x * specs.size(), CELL.y, false, Image.FORMAT_RGBA8)
	for i in specs.size():
		var parts: PackedStringArray = specs[i].split(":")
		var anim_name: String = parts[0]
		var t: float = float(parts[1]) if parts.size() > 1 else 0.0
		if vis.anim_player != null and vis.anim_player.has_animation(anim_name):
			var anim: Animation = vis.anim_player.get_animation(anim_name)
			var bm: Dictionary = PoseSampler.bind(anim, vis.skeleton)
			PoseSampler.apply(anim, vis.skeleton, bm, fposmod(t, anim.length))
		for f in 4:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, CELL.x, CELL.y), Vector2i(CELL.x * i, 0))
	sheet.save_png(out_path)
	print("SHEET saved ", out_path, " ", sheet.get_size(), " tris(visual)=", _count_tris(vis))
	get_tree().quit()

func _count_tris(n: Node) -> int:
	var t: int = 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			t += idx.size() / 3
	return t
