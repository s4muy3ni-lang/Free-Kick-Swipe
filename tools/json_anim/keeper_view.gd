extends Node
## Revision a ojo de las atajadas del arquero en el modo 4 (Json): dispara a una esquina y guarda una tira de imagenes del
## arquero (camara detras del arco, mirando al tirador). Necesita render:
##   TARGET=0.8,1.4 SPEED=15 OUT=/tmp/k.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/keeper_view.tscn
## Env: TARGET "z,y" del tiro en la linea de gol, SPEED m/s, FROM_X (m), COUNT imagenes, EVERY pasos de fisica, MODE.

func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.get_environment(k) != "" else d

func _ready() -> void:
	Tuning.gameplay_mode = int(_env("MODE", "4"))
	PackLibrary.reload()
	var w: int = int(_env("W", "300"))
	var h: int = int(_env("H", "300"))
	get_window().size = Vector2i(w, h)
	get_viewport().size = Vector2i(w, h)
	var pitch := Pitch.new()
	add_child(pitch)
	var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	add_child(ball)
	pitch.set_ball(ball)
	var ctx := MatchContext.new()
	ctx.ball = ball
	ctx.pitch = pitch
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var k := Goalkeeper.new()
	add_child(k)
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	k.setup(ctx, 1, 90, attrs)
	var cam := Camera3D.new()
	cam.fov = float(_env("FOV", "40"))
	add_child(cam)
	cam.current = true
	for i in 30:
		await get_tree().physics_frame
	var tg: PackedStringArray = _env("TARGET", "1.0,0.6").split(",")
	var from := Vector3(float(_env("FROM_X", "9.0")), 0.11, float(_env("FROM_Z", "0.0")))
	var target := Vector3(20.0, float(tg[1]), float(tg[0]))
	ball.reset_at(from)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var v: Vector3 = (target - from).normalized() * float(_env("SPEED", "15"))
	ball.kick(v, ball.rolling_spin(v))
	var count: int = int(_env("COUNT", "10"))
	var every: int = int(_env("EVERY", "6"))
	var sheet := Image.create(w * mini(count, 10), h * ((count + 9) / 10), false, Image.FORMAT_RGB8)
	var shot_i := 0
	var start: int = int(float(_env("START", "0.3")) * 60.0)
	for i in 240:
		await get_tree().physics_frame
		await get_tree().process_frame
		var c: Vector3 = k.global_position
		cam.global_position = Vector3(c.x - 3.4, 1.3, c.z + 3.2 * signf(float(tg[0]) + 0.001) * 0.0 + 3.6)
		cam.look_at(Vector3(c.x, 0.9, c.z), Vector3.UP)
		if i >= start and (i - start) % every == 0 and shot_i < count:
			var img: Image = get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((shot_i % 10) * w, (shot_i / 10) * h))
			shot_i += 1
	sheet.save_png(_env("OUT", "/tmp/keeper.png"))
	print("KEEPER stats ", k.stats, " plan ", k._plan.get("clip", "-") if k.get("_plan") != null else "-")
	get_tree().quit()
