extends Node
## Tiras de imagenes consecutivas de la pelota con una camara cercana que la sigue (pase raso lento y rapido, tiro con
## efecto y tiro sin giro) para revisar a ojo el giro dibujado. Imprime el giro real y el dibujado por imagen.
## Uso: SPIN_OUT=/tmp/giro xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --resolution 320x240 --path . res://tools/ball_spin_view.tscn

var ball: Ball
var cam: Camera3D
var out: String

func _ready() -> void:
	out = OS.get_environment("SPIN_OUT")
	var pitch := Pitch.new()
	add_child(pitch)
	ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	add_child(ball)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	cam = Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.current = true
	_run.call_deferred()

func _follow() -> void:
	var p: Vector3 = ball.global_position
	cam.global_position = p + Vector3(0.0, 0.5, 1.6)
	cam.look_at(p, Vector3.UP)

func _shoot(name: String, v: Vector3, spin: Vector3, start_frame: int, n: int) -> void:
	ball.reset_at(Vector3(-6.0, 0.11, 0.0))
	for i in 4:
		await get_tree().physics_frame
	ball.kick(v, spin, null)
	for f in start_frame + n:
		await get_tree().physics_frame
		_follow()
		await get_tree().process_frame
		if f >= start_frame:
			await get_tree().process_frame
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png("%s_%s_%02d.png" % [out, name, f - start_frame])
			print("%s f%d giro real %.0f grados/imagen, dibujado %.1f, desenfoque %.0f grados" % [name, f, rad_to_deg(ball.angular_velocity.length()) / 60.0, ball.visual_spin_step_deg, ball.visual_spin_blur_deg])

func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	var pass_v := Vector3(8.0, 0.0, 0.0)
	await _shoot("pase8", pass_v, ball.rolling_spin(pass_v), 6, 6)
	var slow := Vector3(2.5, 0.0, 0.0)
	await _shoot("pase2", slow, ball.rolling_spin(slow), 6, 6)
	await _shoot("chanfle", Vector3(18.0, 4.0, 0.0), KickModel.curl_spin(Vector3(1, 0, 0), 1.0, 26.0) - Vector3.UP.cross(Vector3(1, 0, 0)) * 14.0, 6, 6)
	await _shoot("flotado", Vector3(25.0, 3.5, 0.0), -Vector3.UP.cross(Vector3(1, 0, 0)) * 3.0, 6, 6)
	get_tree().quit()
