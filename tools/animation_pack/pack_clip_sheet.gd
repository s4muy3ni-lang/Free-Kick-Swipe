extends Node
## Hoja de contacto de un clip YA CONVERTIDO del pack (pack_clips.res) sobre el futbolista del juego, con la trayectoria
## medida de las puntas de los pies (FootTrajectory) dibujada como puntos: rojo = pie derecho, azul = izquierdo; un aro
## blanco marca los fotogramas de empuje. Requiere render.
## Env: CLIP=Dribble_2 FRAMES=12 VIEW=side|three|top OUT=/ruta.png
## Uso: xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/animation_pack/pack_clip_sheet.tscn

const CELL := Vector2i(260, 360)

func _ready() -> void:
	var clip: StringName = StringName(OS.get_environment("CLIP"))
	var n: int = int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 12
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
	# Lineas cada 0.25 m hacia delante (escala de referencia)
	for k in range(-4, 9):
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 0.002, 0.01)
		line.mesh = bm
		line.material_override = MeshUtil.flat_material(Color(0.9, 0.9, 0.9) if k % 4 == 0 else Color(0.35, 0.5, 0.38), 1.0)
		line.position = Vector3(0.0, 0.001, -0.25 * k)
		add_child(line)
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
	if vis.anim_tree != null:
		vis.anim_tree.active = false
	var anim: Animation = PackLibrary.clip(clip)
	if anim == null:
		push_error("no existe el clip %s" % clip)
		get_tree().quit(1)
		return
	var s: Dictionary = FootTrajectory.sample(anim, vis)
	var a: Dictionary = FootTrajectory.analyze(s, FootTrajectory.body_speed(PackLibrary.meta(clip)))
	var push_frames := {}
	for e in a["pushes"]:
		var i0: int = int(round(float(e["t0"]) / float(s["dt"])))
		var i1: int = int(round(float(e["t1"]) / float(s["dt"])))
		for i in range(i0, i1 + 1):
			push_frames[i] = true
	var cam := Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	var target := Vector3(0, 0.55, -0.15)
	match view:
		"three": cam.look_at_from_position(Vector3(2.6, 1.5, -2.4), target, Vector3.UP)
		"top": cam.look_at_from_position(Vector3(0.0, 4.2, -0.35), Vector3(0, 0, -0.35), Vector3(0, 0, -1))
		_: cam.look_at_from_position(Vector3(-4.2, 0.7, -0.15), target, Vector3.UP)
	cam.current = true
	var dots := Node3D.new()
	add_child(dots)
	var bind: Dictionary = PoseSampler.bind(anim, vis.skeleton)
	var sheet := Image.create(CELL.x * n, CELL.y, false, Image.FORMAT_RGBA8)
	for i in n:
		var t: float = anim.length * float(i) / float(n)
		for c in dots.get_children():
			c.queue_free()
		var fi: int = int(round(t / float(s["dt"])))
		# rastro de las puntas en los ultimos 0.25 s
		for f in 2:
			for k in range(maxi(fi - 15, 0), fi + 1):
				var p: Vector3 = s["toe"][f][k]
				var dot := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.018 if k < fi else 0.03
				sm.height = sm.radius * 2.0
				dot.mesh = sm
				dot.material_override = MeshUtil.flat_material(Color(0.95, 0.2, 0.2) if f == 1 else Color(0.2, 0.5, 1.0), 1.0)
				dot.position = Vector3(p.z, p.y, -p.x)
				dots.add_child(dot)
		if push_frames.has(fi):
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.42
			tm.outer_radius = 0.46
			ring.mesh = tm
			ring.material_override = MeshUtil.flat_material(Color(1, 1, 1), 1.0)
			ring.position = Vector3(0, 0.01, 0)
			dots.add_child(ring)
		PoseSampler.apply(anim, vis.skeleton, bind, t)
		for k in 4:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, 0))
	sheet.save_png(out_path)
	print("hoja guardada en ", out_path, " (", n, " fotogramas de ", clip, ")")
	get_tree().quit()
