extends Node
## Imagenes consecutivas de una accion con la pelota del jugador del pack, camara de costado que lo sigue, para revisar a
## ojo la suela sobre la pelota, el arrastre, el pivote, los toques del giro o el balanceo del tiro. Uso:
## DRAG_OUT=/tmp/vuelta DRAG_STICK=0.7 xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --resolution 640x400 \
##   --path . res://tools/drag_back_view.tscn
## DRAG_ACTION: reverse (joystick hacia atras, por defecto), skill (REGATE + joystick atras: pisada), shot (tiro con
## DRAG_CHARGE fotogramas de carga), pass. DRAG_FRAMES: imagenes (cada 3 fotogramas de fisica).

func _ready() -> void:
	# DRAG_MODE: modo de jugabilidad (2 = mocap con su modelo propio, 3 = Tripo).
	if OS.get_environment("DRAG_MODE") != "":
		Tuning.gameplay_mode = int(OS.get_environment("DRAG_MODE"))
	var out: String = OS.get_environment("DRAG_OUT")
	var stick: float = float(OS.get_environment("DRAG_STICK")) if OS.get_environment("DRAG_STICK") != "" else 0.7
	var pitch := Pitch.new()
	add_child(pitch)
	var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	add_child(ball)
	pitch.set_ball(ball)
	ball.global_position = Vector3(-9.4, 0.11, 0.0)
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
	f.global_position = Vector3(-10.0, 0.0, 0.0)
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	f.setup(ctx, 0, 1, attrs, src)
	f.is_human_controlled = true
	f.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var cam := Camera3D.new()
	cam.fov = float(OS.get_environment("DRAG_FOV")) if OS.get_environment("DRAG_FOV") != "" else 40.0
	add_child(cam)
	cam.current = true
	src.move = Vector2(stick, 0.0)
	for i in 90:
		await get_tree().physics_frame
	var action: String = OS.get_environment("DRAG_ACTION") if OS.get_environment("DRAG_ACTION") != "" else "reverse"
	var charge: int = int(OS.get_environment("DRAG_CHARGE")) if OS.get_environment("DRAG_CHARGE") != "" else 20
	var frames: int = int(OS.get_environment("DRAG_FRAMES")) * 3 if OS.get_environment("DRAG_FRAMES") != "" else 54
	match action:
		"shot":
			src.hold_shoot()
		"pass":
			src.hold_pass()
		"skill":
			src.skill()
			src.move = Vector2(-maxf(stick, 0.7), 0.0)
		_:
			src.move = Vector2(-maxf(stick, 0.7), 0.0)
	var dbk: DragBack = f.ball_handler.drag_back
	ball.impulse.connect(func(_a: Node, dv: float, sp: float) -> void: print("  impulso dv %.1f -> %.1f m/s" % [dv, sp]))
	for i in frames:
		if i == charge and action == "shot":
			src.release_shoot()
		elif i == charge and action == "pass":
			src.release_pass()
		await get_tree().physics_frame
		await get_tree().process_frame
		var c: Vector3 = f.global_position
		cam.global_position = Vector3(c.x + 0.3, 1.1, 3.6)
		cam.look_at(Vector3(c.x + 0.3, 0.45, 0.0), Vector3.UP)
		if i % 3 == 0 and i > 0:
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png("%s_%02d.png" % [out, i])
			var bt: BallTurn = f.ball_handler.ball_turn
			var ft: int = bt.foot if bt.active() else dbk.foot
			var toe: Vector3 = f.visual.touch_ik.abs_toe_world[ft]
			print("f%d pisada %d giro %d (toques %d) v %.2f pelota %.2f,%.2f,%.2f punta %.2f,%.2f,%.2f" % [i, dbk.phase, bt.phase, bt.touches, f.locomotion.speed, ball.global_position.x - c.x, ball.global_position.y, ball.global_position.z, toe.x - c.x, toe.y, toe.z])
	get_tree().quit()
