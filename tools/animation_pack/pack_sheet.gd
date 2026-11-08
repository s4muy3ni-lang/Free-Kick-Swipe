extends Node
## Hojas de contacto de clips sobre NUESTRO futbolista (pack retargeteado con PackRetarget, o clips de Tripo). Requiere render (xvfb-run --rendering-driver opengl3).
## Env: SRC=pack|tripo CLIPS=ruta1,ruta2 FRAMES=6 FOV=44 OUT=dir VIEW=side|front|three
const CELL := Vector2i(260, 400)

func _ready() -> void:
	var src: String = OS.get_environment("SRC")
	var clips: PackedStringArray = OS.get_environment("CLIPS").split(",")
	var frames: int = int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 6
	var out_dir: String = OS.get_environment("OUT")
	var view: String = OS.get_environment("VIEW") if OS.get_environment("VIEW") != "" else "side"
	get_window().size = CELL
	get_viewport().size = CELL
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
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
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var vis := FootballerVisual.new()
	add_child(vis)
	vis.build(FootballerVisual.default_kit(0))
	vis.anim_tree.active = false
	var cam := Camera3D.new()
	cam.fov = float(OS.get_environment("FOV")) if OS.get_environment("FOV") != "" else 38.0
	add_child(cam)
	var target := Vector3(0, 0.9, 0)
	match view:
		"front": cam.look_at_from_position(Vector3(0, 1.1, -5.4), target, Vector3.UP)
		"three": cam.look_at_from_position(Vector3(3.4, 1.6, -3.8), target, Vector3.UP)
		_: cam.look_at_from_position(Vector3(-5.8, 1.0, 0.0), target, Vector3.UP)
	cam.current = true
	var rt: PackRetarget = null
	if src == "pack":
		var ysk: Skeleton3D = ((load("res://pack/personaje/ybot_tpose.fbx") as PackedScene).instantiate()).find_children("*", "Skeleton3D", true, false)[0]
		rt = PackRetarget.new()
		rt.setup(ysk, vis.skeleton)
		print("RETARGET: k_pos=%.3f huesos compartidos=%d/%d" % [rt.k_pos, rt.y_of_t.size(), vis.skeleton.get_bone_count()])
	var report: Array[String] = []
	for clip in clips:
		var anim: Animation = null
		var bind: Dictionary = {}
		if src == "pack":
			var inst: Node = (load("res://pack/animaciones/" + clip) as PackedScene).instantiate()
			var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
			for n in ap.get_animation_list():
				if n != "RESET":
					anim = ap.get_animation(n)
					break
			bind = rt.bind(anim)
		else:
			anim = vis.anim_player.get_animation(clip)
		var strip := Image.create(CELL.x * frames, CELL.y, false, Image.FORMAT_RGBA8)
		var min_ankle := 1e9
		for i in frames:
			var t: float = anim.length * float(i) / float(frames)
			if src == "pack":
				rt.pose(bind, t, true)
				min_ankle = minf(min_ankle, rt.ankle_min_height())
			else:
				PoseSampler.apply(anim, vis.skeleton, PoseSampler.bind(anim, vis.skeleton), t)
			for f in 4:
				await get_tree().process_frame
			var img: Image = get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			strip.blit_rect(img, Rect2i(0, 0, CELL.x, CELL.y), Vector2i(CELL.x * i, 0))
		var base: String = clip.get_file().get_basename()
		strip.save_png("%s/%s.png" % [out_dir, base])
		if src == "pack":
			var rest_ankle: float = 0.0227
			report.append("%s: dur=%.2fs, tobillo mas bajo=%.3f (reposo %.3f) => diferencia=%+.1f cm en juego" % [base, anim.length, min_ankle, rest_ankle, (min_ankle - rest_ankle) * 1.75 * 100.0])
		print("STRIP ", base)
	for r in report:
		print("REPORT ", r)
	get_tree().quit()
