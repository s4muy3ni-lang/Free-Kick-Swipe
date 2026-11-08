extends Node
## Imagenes consecutivas de un tiro a la red (camara fija detras de la linea, de lado) para revisar a ojo como se abomba
## la red de tela y como frena la pelota. Uso:
## NET_OUT=/tmp/red xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --resolution 480x320 --path . res://tools/net_view.tscn

func _ready() -> void:
	var out: String = OS.get_environment("NET_OUT")
	var cfg: PitchConfig = Tuning.pitch
	cfg.boundary_mode = PitchConfig.BoundaryMode.OUT_OF_BOUNDS
	var pitch := Pitch.new()
	add_child(pitch)
	var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	add_child(ball)
	pitch.set_ball(ball)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	var gl: float = cfg.half_length()
	# NET_CAM=lado: de costado, para ver cuanto se abomba la red hacia atras.
	if OS.get_environment("NET_CAM") == "lado":
		cam.global_position = Vector3(gl + 0.6, 1.5, 4.6)
		cam.look_at(Vector3(gl + 0.7, 0.9, 0.0), Vector3.UP)
	else:
		cam.global_position = Vector3(gl - 3.5, 1.6, 4.2)
		cam.look_at(Vector3(gl + 0.4, 0.9, 0.0), Vector3.UP)
	for i in 10:
		await get_tree().physics_frame
	ball.reset_at(Vector3(gl - 7.0, 0.7, 0.3))
	for i in 4:
		await get_tree().physics_frame
	ball.kick(Vector3(26.0, 2.2, 0.2), Vector3.ZERO, null)
	var goal: Goal = pitch.goals[1]
	for f in 60:
		await get_tree().physics_frame
		await get_tree().process_frame
		if f >= 12 and f % 2 == 0:
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png("%s_%02d.png" % [out, f])
			print("f%d pelota x %.2f v %.1f abombado %.2f" % [f, ball.global_position.x - gl, ball.linear_velocity.length(), goal.net.bulge])
	get_tree().quit()
