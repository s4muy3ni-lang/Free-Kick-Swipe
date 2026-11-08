extends Node
## Hoja de contacto de un clip de cualquier GLB riggeado (material plano; no requiere kit).
## Env: MODEL=res://x.glb CLIP=nombre FRAMES=8 T0=0 T1=fin VIEW=side|front|three OUT=/ruta.png
## Uso: xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/render_clip_sheet.tscn

const CELL := Vector2i(300, 440)

func _ready() -> void:
	var model_path: String = OS.get_environment("MODEL")
	var clip: String = OS.get_environment("CLIP")
	var n: int = int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 8
	var view: String = OS.get_environment("VIEW") if OS.get_environment("VIEW") != "" else "side"
	var out_path: String = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/clip.png"
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
	var rig := Node3D.new()
	rig.rotation.y = PI * 0.5
	rig.scale = Vector3.ONE * 1.75
	add_child(rig)
	var model: Node3D = (load(model_path) as PackedScene).instantiate()
	rig.add_child(model)
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var mat := MeshUtil.flat_material(Color(0.85, 0.35, 0.25), 0.7)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	var target := Vector3(0, 0.9, 0)
	match view:
		"front": cam.look_at_from_position(Vector3(0, 1.1, -5.2), target, Vector3.UP)
		"three": cam.look_at_from_position(Vector3(3.4, 1.7, -3.8), target, Vector3.UP)
		_: cam.look_at_from_position(Vector3(-5.4, 1.0, 0.0), target, Vector3.UP)
	cam.current = true
	var anim: Animation = ap.get_animation(clip)
	var t0: float = float(OS.get_environment("T0")) if OS.get_environment("T0") != "" else 0.0
	var t1: float = float(OS.get_environment("T1")) if OS.get_environment("T1") != "" else anim.length
	var bm: Dictionary = PoseSampler.bind(anim, sk)
	var sheet := Image.create(CELL.x * n, CELL.y, false, Image.FORMAT_RGBA8)
	for i in n:
		var t: float = lerpf(t0, t1, float(i) / maxf(n - 1, 1))
		PoseSampler.apply(anim, sk, bm, t)
		for f in 4:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, CELL.x, CELL.y), Vector2i(CELL.x * i, 0))
	sheet.save_png(out_path)
	print("CLIP '%s' len=%.2f s, %d bones, saved %s" % [clip, anim.length, sk.get_bone_count(), out_path])
	get_tree().quit()
