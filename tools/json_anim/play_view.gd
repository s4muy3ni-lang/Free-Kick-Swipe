extends Node
## Revision a ojo y medida de la jugabilidad del modo 4 (Json): un jugador con la pelota que conduce, pasa o tira, con camara de
## costado que lo sigue. Guarda una tira de imagenes (cada EVERY pasos de fisica) y escribe por la salida la distancia de la
## pelota al cuerpo en cada paso (resumen al final). Necesita render:
##   SCENARIO=dribble OUT=/tmp/x.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/play_view.tscn
## Env: SCENARIO dribble|pass|shot|turn|zigzag|diag|curve|steps|dragback|backshot|turn90|turnshot|turnpass, STICK (0..1), SPRINT (0|1), SECONDS, EVERY,
## COUNT (imagenes), START (s sin imagen), W/H (tamano de cada imagen), VIEW side|three|top|close, CHARGE (pasos de carga del tiro/pase).

func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.get_environment(k) != "" else d

func _ready() -> void:
	Tuning.gameplay_mode = int(_env("MODE", "4"))
	PackLibrary.reload()
	var scenario: String = _env("SCENARIO", "dribble")
	var out: String = _env("OUT", "/tmp/play.png")
	var stick: float = float(_env("STICK", "0.8"))
	var sprint: bool = _env("SPRINT", "0") == "1"
	var seconds: float = float(_env("SECONDS", "6.0"))
	var every: int = int(_env("EVERY", "6"))
	var count: int = int(_env("COUNT", "10"))
	var t_start: float = float(_env("START", "1.5"))
	var w: int = int(_env("W", "320"))
	var h: int = int(_env("H", "240"))
	var view: String = _env("VIEW", "side")
	get_window().size = Vector2i(w, h)
	get_viewport().size = Vector2i(w, h)
	var pitch := Pitch.new()
	add_child(pitch)
	var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	add_child(ball)
	pitch.set_ball(ball)
	ball.global_position = Vector3(-14.4, 0.11, 0.0)
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
	var src := ScriptedInput.new()
	var f: Footballer = (load("res://scenes/player/footballer.tscn") as PackedScene).instantiate()
	f.build_visual = true
	add_child(f)
	f.global_position = Vector3(-15.0, 0.0, 0.0)
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	f.setup(ctx, 0, 1, attrs, src)
	f.is_human_controlled = true
	f.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	if scenario == "sideshot":
		# De costado al arco (+X): el tiro sale a 90 grados del frente.
		f.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(0, 0, -1))
		ball.global_position = Vector3(-15.0, 0.11, -0.45)
		stick = 0.0
	if scenario == "turnshot" or scenario == "turnpass":
		# De espaldas al arco rival (+X) con la pelota al pie y parado: el tiro / pase tiene que girar el cuerpo.
		f.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(-1, 0, 0))
		ball.global_position = Vector3(-15.45, 0.11, 0.05)
		stick = 0.0
	var cam := Camera3D.new()
	cam.fov = float(_env("FOV", "36"))
	add_child(cam)
	cam.current = true
	src.move = Vector2(stick, 0.0)
	src.sprint = sprint
	var total: int = int(seconds * 60.0)
	var sheet := Image.create(w * mini(count, 12), h * ((count + 11) / 12), false, Image.FORMAT_RGB8)
	var shot_i := 0
	var dists: Array[float] = []
	var gaps: Array[float] = []
	var touches_prev: int = 0
	var charge: int = int(_env("CHARGE", "14"))
	var act_at: int = int(float(_env("ACT_AT", "3.0")) * 60.0)
	var log_every: int = 6
	var t_ref: Array[float] = [0.0]
	# ON_TOUCH=1: solo se guardan las imagenes del instante de cada toque (para ver si el pie toca la pelota).
	var on_touch: bool = _env("ON_TOUCH", "0") == "1"
	var touch_flag: Array[int] = [0]
	f.ball_handler.touched_ball.connect(func(mode: StringName) -> void:
		touch_flag[0] = 1
		var bh: BallHandler = f.ball_handler
		var rel2: Vector3 = ball.global_position - f.global_position
		print("TOQUE t=%.2f modo %s pie %d dist_pie %.3f bola adelante %.2f lateral %.2f v_bola %.1f" % [t_ref[0], mode, bh.last_touch_foot, bh.last_touch_foot_distance if bh.last_touch_foot >= 0 else -1.0, rel2.dot(f.locomotion.forward()), rel2.dot(f.locomotion.right()), ball.linear_velocity.length()]))
	for i in total:
		if scenario == "pass" and i == act_at:
			src.hold_pass()
		elif scenario == "pass" and i == act_at + charge:
			src.release_pass()
		elif scenario == "shot" and i == act_at:
			src.hold_shoot()
		elif scenario == "shot" and i == act_at + charge:
			src.release_shoot()
		elif scenario == "zigzag":
			var ph: float = float(i) / 60.0
			src.move = Vector2(stick, 0.9 * sin(ph * 2.2))
		elif scenario == "turn" and i == act_at:
			src.move = Vector2(-stick, 0.0)
		elif scenario == "turn90" and i == act_at:
			src.move = Vector2(0.0, stick)
		elif scenario == "curve":
			# Curva progresiva (como en UCS: diagonal cada vez mas cerrada): el joystick gira 30 grados por segundo hacia la
			# izquierda desde 1.5 s hasta 90 grados y despues hacia la derecha hasta -90 (CURVE_SIGN=-1 empieza a la derecha).
			var cs: float = float(_env("CURVE_SIGN", "1"))
			var tt: float = float(i) / 60.0
			var a: float = 0.0
			if tt > 1.5:
				a = minf((tt - 1.5) * 30.0, 90.0)
			if tt > 5.0:
				a = maxf(90.0 - (tt - 5.0) * 30.0, -90.0)
			src.move = Vector2(cos(deg_to_rad(a * cs)), sin(deg_to_rad(a * cs))) * stick
		elif scenario == "steps":
			# Cambios bruscos de 35 grados (lo que mas hace la persona con el joystick): 0, +35, 0, -35, 0 cada 1.5 s.
			var seq: Array = [0.0, 35.0, 0.0, -35.0, 0.0, 35.0]
			var k: int = clampi(int(float(i) / 90.0), 0, seq.size() - 1)
			var a2: float = deg_to_rad(float(seq[k]) * float(_env("CURVE_SIGN", "1")))
			src.move = Vector2(cos(a2), sin(a2)) * stick
		elif scenario == "diag":
			# Cambios de rumbo suaves: 25 grados a un lado y al otro cada 1.5 s.
			var ang: float = 0.0 if i < 120 else deg_to_rad(25.0) * (1.0 if ((i - 120) / 90) % 2 == 0 else -1.0)
			src.move = Vector2(cos(ang), sin(ang)) * stick
		elif scenario == "dragback" and i == act_at:
			src.skill()
			src.move = Vector2(-stick, 0.0)
		elif scenario == "sideshot" and i == act_at:
			src.hold_shoot()
		elif scenario == "sideshot" and i == act_at + charge:
			src.release_shoot()
		elif scenario == "turnshot" and i == act_at:
			src.hold_shoot()
		elif scenario == "turnshot" and i == act_at + charge:
			src.release_shoot()
		elif scenario == "turnpass" and i == act_at:
			src.move = Vector2(0.0, 0.6)
			src.hold_pass()
		elif scenario == "turnpass" and i == act_at + charge:
			src.release_pass()
			src.move = Vector2.ZERO
		elif scenario == "backshot" and i == act_at:
			src.move = Vector2(-stick, 0.3)
			src.hold_shoot()
		elif scenario == "backshot" and i == act_at + charge:
			src.release_shoot()
		await get_tree().physics_frame
		await get_tree().process_frame
		t_ref[0] = float(i) / 60.0
		var c: Vector3 = f.global_position
		match view:
			"three":
				cam.global_position = Vector3(c.x + 1.0 + 2.2, 1.5, c.z + 3.4)
			"top":
				cam.global_position = Vector3(c.x + 0.5, 9.0, c.z + 0.01)
			"close":
				cam.global_position = Vector3(c.x + 2.0, 1.45, c.z + 2.7)
			_:
				cam.global_position = Vector3(c.x + 0.6, 0.95, c.z + 4.0)
		cam.look_at(Vector3(c.x + 0.6, 0.8 if view != "top" else 0.0, c.z) if view != "close" else Vector3(c.x + 0.3, 0.65, c.z), Vector3.UP)
		var rel: Vector3 = ball.global_position - c
		var fwd: Vector3 = f.locomotion.forward()
		var ahead: float = rel.dot(fwd)
		dists.append(Vector2(rel.x, rel.z).length())
		gaps.append(ahead)
		if i % log_every == 0:
			print("t=%.2f pos (%.1f, %.1f) v=%.2f bola adelante %.2f lateral %.2f y %.2f vel %.1f | dist pie-pelota (ult. toque) %.3f | toques %d" % [float(i) / 60.0, f.global_position.x, f.global_position.z, f.locomotion.speed, ahead, rel.dot(f.locomotion.right()), ball.global_position.y, ball.linear_velocity.length(), f.ball_handler.last_touch_foot_distance, f.ball_handler.dribble_touch_count])
		var want_shot: bool = (touch_flag[0] == 1) if on_touch else (i % every == 0)
		touch_flag[0] = 0
		if float(i) / 60.0 >= t_start and want_shot and shot_i < count:
			var img: Image = get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((shot_i % 12) * w, (shot_i / 12) * h))
			shot_i += 1
	sheet.save_png(out)
	dists.sort()
	var far := 0
	for d in dists:
		if d > 1.8:
			far += 1
	print("RESUMEN %s: pelota-cuerpo mediana %.2f m, p90 %.2f m, max %.2f m, >1.8 m: %d de %d pasos; toques %d, de pie vivo %d; kick_stats %s" % [scenario, dists[dists.size() / 2], dists[int(dists.size() * 0.9)], dists[dists.size() - 1], far, dists.size(), f.ball_handler.dribble_touch_count, f.ball_handler.foot_touches, str(f.ball_handler.kick_stats)])
	print("GOLPEOS %s | plan %s" % [str(f.ball_handler.kick_log), f.ball_handler.last_plan_debug])
	print("MOVIMIENTOS %s | ultimo %s" % [str(f.ball_handler.json_move.stats), str(f.ball_handler.json_move.last)])
	for hm in f.ball_handler.json_move.history:
		print("MOV %s %s giro %.0f pie %s toques %s %s cuadro %d" % [hm.get("intent", ""), hm.get("clip", ""), float(hm.get("turn", 0.0)), "der" if int(hm.get("foot", 0)) > 0 else "izq", str(hm.get("touches", [])), str(hm.get("aborted", hm.get("ended", ""))), int(hm.get("frame", 0))])
	print("PLAYVIEW guardado ", out)
	get_tree().quit()
