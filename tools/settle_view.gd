extends Node
## Imagenes consecutivas con el joystick suelto y la pelota fuera del pie (al costado, detras o rodando): para revisar a ojo
## que el jugador va a la pelota (se gira, da los pasos, la para con el pie) y que la pelota no se mueve sola hacia el.
## Uso: SETTLE_OUT=/tmp/acomoda SETTLE_BALL=-0.3,0.15 SETTLE_V=-0.6,0 xvfb-run -a godot --rendering-driver opengl3 \
##   --fixed-fps 60 --resolution 480x360 --path . res://tools/settle_view.tscn
## SETTLE_BALL / SETTLE_V: posicion (m) y velocidad (m/s) de la pelota en el marco del jugador (adelante, derecha).
## SETTLE_FRAMES: imagenes (cada 3 fotogramas de fisica).

func _vec(name: String, def: Vector2) -> Vector2:
	var s: String = OS.get_environment(name)
	if s == "":
		return def
	var parts: PackedStringArray = s.split(",")
	return Vector2(float(parts[0]), float(parts[1])) if parts.size() == 2 else def

func _ready() -> void:
	Tuning.gameplay_mode = 4
	var out: String = OS.get_environment("SETTLE_OUT") if OS.get_environment("SETTLE_OUT") != "" else "/tmp/acomoda"
	var off: Vector2 = _vec("SETTLE_BALL", Vector2(-0.3, 0.15))
	var vel: Vector2 = _vec("SETTLE_V", Vector2(-0.6, 0.0))
	var frames: int = int(OS.get_environment("SETTLE_FRAMES")) * 3 if OS.get_environment("SETTLE_FRAMES") != "" else 72
	var pitch := Pitch.new()
	add_child(pitch)
	var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	add_child(ball)
	pitch.set_ball(ball)
	var p0 := Vector3(-10.0, 0.0, 0.0)
	var fwd := Vector3(1, 0, 0)
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	ball.global_position = p0 + fwd * 0.45 + Vector3(0, 0.11, 0)
	var ctx := MatchContext.new()
	ctx.ball = ball
	ctx.pitch = pitch
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var src := ScriptedInput.new()
	var f: Footballer = (load("res://scenes/player/footballer.tscn") as PackedScene).instantiate()
	f.build_visual = true
	add_child(f)
	f.global_position = p0
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	f.setup(ctx, 0, 1, attrs, src)
	f.is_human_controlled = true
	f.locomotion.yaw = Locomotion.yaw_from_dir(fwd)
	ball.register_touch(f)
	var cam := Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	cam.current = true
	for i in 30:
		await get_tree().physics_frame
	f.place_at(p0, Locomotion.yaw_from_dir(fwd))
	ball.reset_at(p0 + fwd * off.x + right * off.y + Vector3(0, 0.11, 0))
	await get_tree().physics_frame
	var v0: Vector3 = fwd * vel.x + right * vel.y
	ball.linear_velocity = v0
	ball.angular_velocity = ball.rolling_spin(v0)
	var bh: BallHandler = f.ball_handler
	bh.touched_ball.connect(func(kind: StringName) -> void: print("  toque %s pie %d a %.2f m" % [kind, bh.last_touch_foot, bh.last_touch_foot_distance]))
	for i in frames:
		await get_tree().physics_frame
		await get_tree().process_frame
		var c: Vector3 = f.global_position
		cam.global_position = Vector3(c.x - 1.6, 2.6, c.z + 2.4)
		cam.look_at(Vector3(c.x, 0.2, c.z), Vector3.UP)
		if i % 3 == 0:
			get_viewport().get_texture().get_image().save_png("%s_%02d.png" % [out, i])
			var o: Vector3 = KickModel.flat(ball.global_position - c)
			print("f%d jugador %.2f,%.2f mira %.0f v %.2f | pelota adelante %.2f lado %.2f v %.2f" % [i, c.x, c.z, rad_to_deg(f.locomotion.yaw), f.locomotion.speed, o.dot(f.locomotion.forward()), o.dot(f.locomotion.right()), KickModel.flat(ball.linear_velocity).length()])
	get_tree().quit()
