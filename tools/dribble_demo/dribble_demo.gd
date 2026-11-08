extends Node3D
## Demostracion GRABABLE de la prueba controlada de conduccion y golpeos con el jugador actual (pack de animaciones,
## esqueleto vivo, misma mecanica que el partido): recta al trote, carrera y sprint, giro a la izquierda y a la derecha,
## parada soltando el joystick, pase corto, pase largo y tiro al arco. La entrada la da un ScriptedInput (como un
## mando), nunca se mueve la pelota a mano salvo en los reinicios marcados en pantalla («reinicio»).
## En pantalla: fase, distancia pelota-cuerpo, pie del ultimo toque y velocidad.
## Uso (video): xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 1280x720 \
##   --write-movie /ruta/demo.avi res://tools/dribble_demo/dribble_demo.tscn

const PHASES := [
	# [segundos, nombre, joystick (x, z), sprint, accion]
	[0.6, "", Vector2.ZERO, false, "start"],
	[2.5, "Recta al trote", Vector2(0.55, 0.0), false, ""],
	[1.8, "Recta a la carrera (acelerar)", Vector2(1.0, 0.0), false, ""],
	[1.5, "Sprint", Vector2(1.0, 0.0), true, ""],
	[2.2, "Soltar el joystick: frenar y parar con la pelota", Vector2.ZERO, false, ""],
	[0.8, "reinicio", Vector2.ZERO, false, "reset_turns"],
	[1.0, "Carrera", Vector2(1.0, 0.0), false, ""],
	[1.3, "Giro a la izquierda (90 grados)", Vector2(0.0, -1.0), false, ""],
	[1.2, "Giro a la derecha (vuelta al frente)", Vector2(1.0, 0.0), false, ""],
	[1.3, "Giro a la derecha (90 grados)", Vector2(0.0, 1.0), false, ""],
	[1.6, "Soltar el joystick: parar", Vector2.ZERO, false, ""],
	[0.8, "reinicio", Vector2.ZERO, false, "reset_short"],
	[1.8, "Pase corto al companero", Vector2(1.0, 0.25), false, "pass_short"],
	[0.8, "reinicio", Vector2.ZERO, false, "reset_long"],
	[2.2, "Pase largo", Vector2(1.0, -0.6), false, "pass_long"],
	[0.8, "reinicio", Vector2.ZERO, false, "reset_goal"],
	[2.8, "Conducir hacia el arco y tirar", Vector2(1.0, 0.0), false, "shot"],
	[1.5, "", Vector2.ZERO, false, ""],
]

var ctx: MatchContext
var p: Footballer
var src := ScriptedInput.new()
var cam: Camera3D
var label: Label
var _phase: int = -1
var _t: float = 0.0
var _pressed: bool = false
var _cam_pos := Vector3.ZERO

func _ready() -> void:
	var pitch := Pitch.new()
	add_child(pitch)
	var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	add_child(ball)
	ball.global_position = Vector3(-17.4, 0.11, 0.0)
	pitch.set_ball(ball)
	ctx = MatchContext.new()
	ctx.ball = ball
	ctx.pitch = pitch
	p = _player(0, Vector3(-18.0, 0.0, -4.0), src, 1)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	ball.global_position = Vector3(-17.4, 0.11, -4.0)
	# Companeros quietos para los pases (reciben con la misma mecanica de control).
	_player(0, Vector3(1.5, 0.0, 1.0), ScriptedInput.new(), 2)
	_player(0, Vector3(16.0, 0.0, -6.5), ScriptedInput.new(), 3)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	_cam_pos = _cam_want()
	# Registro de toques por la salida estandar (instante, fase, tipo, pie y pelota respecto al cuerpo), para localizar
	# los toques en el video.
	p.ball_handler.touched_ball.connect(func(k: StringName) -> void:
		var o: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
		print("TOQUE t=%.2f s fase=%s tipo=%s/%s pie=%d pelota %.2f m delante %.2f al costado v=%.1f" % [
			Engine.get_physics_frames() / 60.0, PHASES[maxi(_phase, 0)][1], k, p.ball_handler.last_touch_mode, p.ball_handler.last_touch_foot,
			o.dot(p.locomotion.forward()), o.dot(p.locomotion.right()), p.locomotion.speed]))

func _player(team: int, pos: Vector3, source: InputSource, id: int) -> Footballer:
	var f: Footballer = (load("res://scenes/player/footballer.tscn") as PackedScene).instantiate()
	f.build_visual = true
	add_child(f)
	f.global_position = pos
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	f.setup(ctx, team, id, attrs, source)
	f.ball_handler.rng.seed = 777 + id
	return f

func _physics_process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_phase += 1
		if _phase >= PHASES.size():
			get_tree().quit()
			return
		var ph: Array = PHASES[_phase]
		_t = float(ph[0])
		_pressed = false
		match String(ph[4]):
			"reset_turns":
				_reset_ball(Vector3(-12.0, 0.0, 4.0), Vector3(1, 0, 0))
			"reset_short":
				_reset_ball(Vector3(-7.0, 0.0, -1.0), Vector3(1, 0, 0))
			"reset_long":
				_reset_ball(Vector3(-2.0, 0.0, 6.0), Vector3(1, 0, 0))
			"reset_goal":
				_reset_ball(Vector3(4.0, 0.0, 0.0), Vector3(1, 0, 0))
	var ph2: Array = PHASES[_phase]
	src.move = ph2[2]
	src.sprint = bool(ph2[3])
	var action: String = ph2[4]
	var elapsed: float = float(ph2[0]) - _t
	if not _pressed and elapsed > 0.5:
		if action == "pass_short" or action == "pass_long":
			src.hold_pass()
			_pressed = true
			_release_after(0.12 if action == "pass_short" else 0.55, &"pass")
		elif action == "shot" and p.global_position.x > 11.0:
			src.hold_shoot()
			_pressed = true
			_release_after(0.45, &"shot")
	var off: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
	var bh: BallHandler = p.ball_handler
	var foot: String = ["izquierdo", "derecho"][bh.last_touch_foot] if bh.last_touch_foot >= 0 else "sin pie"
	label.text = "%s\npelota: %.2f m delante, %.2f m al costado | ultimo toque: %s%s | %.1f m/s\ntoques %d (con el pie %d; animacion de toque %d, sin pie en la pelota %d) | golpeos %s" % [
		ph2[1], off.dot(p.locomotion.forward()), off.dot(p.locomotion.right()), foot, " (animacion de toque)" if bh.last_touch_mode == &"clip" else "",
		p.locomotion.speed, bh.dribble_touch_count, bh.foot_touches, bh.clip_touch_count, bh.clip_touch_misses, str(bh.kick_stats.get("contact", 0))]

func _release_after(seconds: float, action: StringName) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
	if action == &"shot":
		src.release_shoot()
	else:
		src.release_pass()

func _reset_ball(at: Vector3, dir: Vector3) -> void:
	p.reset_motion()
	p.global_position = at
	p.locomotion.yaw = Locomotion.yaw_from_dir(dir)
	ctx.ball.reset_at(at + dir * 0.6 + Vector3(0, 0.11, 0))
	_cam_pos = _cam_want()

func _process(delta: float) -> void:
	if p == null:
		return
	var target: Vector3 = p.global_position.lerp(ctx.ball.global_position, 0.3) + Vector3(0, 0.3 if _side_cam else 0.6, 0)
	_heading = _heading.slerp(p.locomotion.forward(), clampf(delta * 1.5, 0.0, 1.0)).normalized()
	_cam_pos = _cam_pos.lerp(_cam_want(), clampf(delta * 3.0, 0.0, 1.0))
	cam.look_at_from_position(_cam_pos, target, Vector3.UP)

## Camara detras y a un costado del jugador (como las repeticiones del video de referencia), siguiendo su rumbo.
var _heading := Vector3(1, 0, 0)

## Con DRIBBLE_DEMO_CAM=lateral la camara va de perfil, baja y cerca (para ver el contacto del pie con la pelota).
static var _side_cam: bool = OS.get_environment("DRIBBLE_DEMO_CAM") == "lateral"

func _cam_want() -> Vector3:
	var right := Vector3(-_heading.z, 0.0, _heading.x)
	if _side_cam:
		return p.global_position + _heading * 0.4 - right * 3.2 + Vector3(0, 0.7, 0)
	return p.global_position - _heading * 4.6 + right * 2.2 + Vector3(0, 2.6, 0)
