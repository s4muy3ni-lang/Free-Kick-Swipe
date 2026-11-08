extends Node3D
## Vista previa de un modelo del modo Json (y de sus clips) en imagenes. Necesita render (xvfb-run -a godot --rendering-driver
## opengl3 --path . res://tools/json_anim/model_preview.tscn).
## Env: MODEL (res://...scn|glb), MATERIAL (kit|none), OUT (png), VIEWS (front,side,back,three), CLIP + TIMES (s separados por coma)
## para posar con un clip de la libreria json (JSON_LIB), W/H (tamano de cada vista).

func _ready() -> void:
	var model_path: String = OS.get_environment("MODEL")
	if model_path == "":
		model_path = "res://assets/characters/json/json_human.scn"
	var out: String = OS.get_environment("OUT")
	if out == "":
		out = "/tmp/preview.png"
	var w: int = int(OS.get_environment("W")) if OS.get_environment("W") != "" else 360
	var h: int = int(OS.get_environment("H")) if OS.get_environment("H") != "" else 560
	var views: PackedStringArray = (OS.get_environment("VIEWS") if OS.get_environment("VIEWS") != "" else "front,side,back,three").split(",")
	var times: PackedStringArray = (OS.get_environment("TIMES") if OS.get_environment("TIMES") != "" else "0").split(",")
	var scene: PackedScene = load(model_path) as PackedScene
	get_window().size = Vector2i(w, h)
	get_viewport().size = Vector2i(w, h)
	var vp: Node = self
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.78)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.20, 0.45, 0.22)
	floor_mesh.material_override = fm
	vp.add_child(floor_mesh)
	var rig := Node3D.new()
	rig.rotation.y = PI * 0.5       # el modelo mira a +X; el juego usa -Z
	rig.scale = Vector3.ONE * 1.75
	vp.add_child(rig)
	var model: Node3D = scene.instantiate()
	rig.add_child(model)
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	if OS.get_environment("MATERIAL") != "none" and model_path.contains("json_human"):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/characters/json/json_kit.gdshader")
		mat.set_shader_parameter("trim_color", Color(0.05, 0.12, 0.62))
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.current = true
	var clip_id: String = OS.get_environment("CLIP")
	var lib: AnimationLibrary = null
	var lp: String = OS.get_environment("JSON_LIB")
	if clip_id != "":
		lib = load(lp if lp != "" else "res://assets/animations/json_clips.res") as AnimationLibrary
	var sheet := Image.create(w * times.size(), h * views.size(), false, Image.FORMAT_RGB8)
	for ti in times.size():
		if lib != null and lib.has_animation(clip_id):
			var anim: Animation = lib.get_animation(clip_id)
			var bm: Dictionary = PoseSampler.bind(anim, sk)
			PoseSampler.apply(anim, sk, bm, float(times[ti]))
		for vi in views.size():
			var center := Vector3(0.0, float(OS.get_environment("CY")) if OS.get_environment("CY") != "" else 0.9, 0.0)
			var ang: float = {"front": 0.0, "side": 90.0, "back": 180.0, "three": 40.0}.get(views[vi], 0.0)
			if OS.get_environment("CAM_YAW") != "":
				ang = float(OS.get_environment("CAM_YAW"))
			var dist: float = float(OS.get_environment("DIST")) if OS.get_environment("DIST") != "" else 5.6
			cam.position = center + Vector3(sin(deg_to_rad(ang)), 0.1, -cos(deg_to_rad(ang))) * dist
			cam.look_at(center)
			# Frente del modelo en el juego = -Z (rig girado): "front" mira al modelo de cara.
			for f in 4:
				await get_tree().process_frame
			var img: Image = get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(ti * w, vi * h))
	sheet.save_png(out)
	print("PREVIEW guardado ", out)
	get_tree().quit()
