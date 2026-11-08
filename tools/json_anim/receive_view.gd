extends Node
## Revision a ojo y medida de la recepcion del modo 4 (F3, JsonReceive): una pelota rodando llega a un jugador y se guarda
## una tira de imagenes alrededor del toque, con la medida del pie VIVO (esqueleto animado) frente a la pelota:
##  - en el instante del toque, distancia de la punta del pie del toque a la superficie de la pelota;
##  - antes del toque, distancia minima de cualquier punta de pie a la pelota (si es casi cero, el pie la «toca» o la
##    atraviesa antes de tiempo) y de la pelota al centro del cuerpo (si baja del radio de la capsula, la cruza).
## Necesita render:
##   ANGLE=30 SPEED=9 OUT=/tmp/r.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/receive_view.tscn
## Env: ANGLE (grados de donde viene la pelota respecto al frente, + izquierda), SPEED (m/s), DIST (m), LAT (m de desvio
## lateral del pase), STICK_ANGLE (grados del joystick respecto al frente; vacio = suelto), RUN (joystick de marcha hacia el
## frente, 0..1), SEED, EVERY (pasos entre imagenes), COUNT, W/H, VIEW side|three|top|close, ARRIVE_Y (altura en m a la que
## llega la pelota al jugador: se lanza por el aire; vacio = rodando), PASS (1 = el jugador carga un pase mientras llega la
## pelota y lo suelta tras el contacto).
##
## Clip forzado (auditoria de los clips excluidos de la seleccion automatica, p. ej. los `pending`): CLIP=<id> (con o sin
## `_mirror`) reproduce ESE clip sin pasar por JsonReceive.plan y lanza la pelota para que llegue a la parte del cuerpo
## supuesta en el instante supuesto: asi se ve si el gesto del clip encaja con un contacto ahi. PART (foot, foot_air,
## thigh, knee, chest, head; por defecto la del perfil, y muslo si el perfil dice «leg»), T (s del clip; por defecto la del
## perfil), ANGLE (por defecto la direccion de llegada del perfil o, sin ella, de frente al cuerpo en el instante del
## contacto), SPEED (m/s horizontal, 8), DIST (m; por defecto lo que
## recorre en el instante del contacto mas 0.1 s, para que salga cuando empieza el clip; por el aire, al menos lo que
## tarda en llegar bajando), VIEW
## side|three|front|close|top, COLS (imagenes por fila). La pelota llega por el aire si la parte no es el pie a ras de piso
## y el contacto esta a mas de 0.2 m (velocidad vertical resuelta con BallPredictor y corregida con tiros de prueba reales,
## con el jugador apartado), rodando si no; antes de empezar el clip el jugador no se mueve ni gira. Imagen: tira de COUNT fotogramas cada EVERY pasos
## centrada en el contacto, con la trayectoria prevista (puntos amarillos), el punto de contacto supuesto (rojo) y un
## rotulo por fotograma (tiempo del clip, parte del esqueleto VIVO mas cercana a la pelota y su distancia, «CONTACTO» en el
## paso del primer contacto). Por consola: primer paso en que cada parte del esqueleto vivo queda a menos de 0.12 m de la
## superficie de la pelota, parte mas cercana en el contacto y geometria de la pierna en el instante supuesto; DEBUG=1
## imprime ademas en cada paso el desvio de la pelota real respecto de la trayectoria prevista al empezar el clip.

func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.get_environment(k) != "" else d

func _ready() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()
	# La vista imprime los motivos de descarte del plan (en el juego no se guardan).
	JsonReceive.record_rejects = true
	var out: String = _env("OUT", "/tmp/receive.png")
	var ang: float = float(_env("ANGLE", "0"))
	var spd: float = float(_env("SPEED", "9"))
	var dist: float = float(_env("DIST", "6"))
	var lat: float = float(_env("LAT", "0"))
	var stick_ang: String = _env("STICK_ANGLE", "")
	var run: float = float(_env("RUN", "0"))
	var arrive_y: String = _env("ARRIVE_Y", "")
	var with_pass: bool = _env("PASS", "0") == "1"
	var every: int = int(_env("EVERY", "4"))
	var count: int = int(_env("COUNT", "12"))
	var w: int = int(_env("W", "320"))
	var h: int = int(_env("H", "240"))
	var view: String = _env("VIEW", "three")
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
	var src := ScriptedInput.new()
	var f: Footballer = (load("res://scenes/player/footballer.tscn") as PackedScene).instantiate()
	f.build_visual = true
	add_child(f)
	var me := Vector3(-8.0, 0.0, 0.0)
	f.global_position = me
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	f.setup(ctx, 0, 1, attrs, src)
	f.is_human_controlled = true
	var face := Vector3(1, 0, 0)
	f.locomotion.yaw = Locomotion.yaw_from_dir(face)
	f.ball_handler.rng.seed = int(_env("SEED", "7"))
	var cam := Camera3D.new()
	cam.fov = float(_env("FOV", "36"))
	add_child(cam)
	cam.current = true
	if _env("CLIP", "") != "":
		await _forced(StringName(_env("CLIP", "")), f, ball, cam, out, every, count, w, h, view)
		get_tree().quit()
		return
	var from: Vector3 = face.rotated(Vector3.UP, deg_to_rad(ang))
	var side := Vector3(-from.z, 0.0, from.x)
	var start: Vector3 = me + from * dist + side * lat
	ball.reset_at(start + Vector3(0, 0.11, 0))
	for i in 20:
		await get_tree().physics_frame
	if run > 0.0:
		src.move = Vector2(run, 0.0)
		for i in 40:
			await get_tree().physics_frame
	# El pase apunta a donde estara el jugador (a su marcha) cuando llegue.
	var aim: Vector3 = f.global_position + f.velocity * (dist / maxf(spd, 1.0)) + side * lat
	var dir: Vector3 = KickModel.flat(aim - start).normalized()
	if arrive_y != "":
		# Por el aire: velocidad vertical para llegar a ARRIVE_Y m al jugador (sin arrastre; el plan usa la trayectoria real).
		var tt: float = dist / maxf(spd, 1.0)
		var vy: float = (float(arrive_y) - 0.11 + 0.5 * 9.81 * tt * tt) / tt
		ball.kick(dir * spd + Vector3(0.0, vy, 0.0), Vector3.ZERO, null)
	else:
		ball.kick(dir * spd, ball.rolling_spin(dir * spd), null)
	if with_pass:
		src.hold_pass()
	if stick_ang != "":
		var sd: Vector3 = face.rotated(Vector3.UP, deg_to_rad(float(stick_ang)))
		src.move = Vector2(sd.x, sd.z)
	var frames: Array[Image] = []
	var contact_i: int = -1
	var clip: StringName = &""
	var toe_pre: Array[float] = []
	var min_body_pre: float = INF
	var toe_at: float = -1.0
	var rv: JsonReceive = f.ball_handler.receive
	for i in 200:
		await get_tree().physics_frame
		var c: Vector3 = f.global_position
		match view:
			"top":
				cam.global_position = Vector3(c.x + 0.3, 7.0, c.z + 0.01)
			"side":
				cam.global_position = Vector3(c.x + 0.6, 0.95, c.z + 4.0)
			"close":
				cam.global_position = Vector3(c.x + 2.0, 1.45, c.z + 2.7)
			_:
				cam.global_position = Vector3(c.x + 3.2, 1.6, c.z + 3.2)
		cam.look_at(Vector3(c.x + 0.3, 0.5 if view != "top" else 0.0, c.z), Vector3.UP)
		if clip == &"" and f.ball_handler.json_move.active and f.ball_handler.json_move.intent == &"receive":
			clip = f.ball_handler.json_move.clip
		var bh: BallHandler = f.ball_handler
		var bp: Vector3 = ball.global_position
		if contact_i < 0 and rv.stats["contact"] > 0:
			contact_i = i
			if with_pass:
				src.release_pass()
			var foot: int = bh.last_touch_foot
			toe_at = bh.toe_world(foot).distance_to(bp) - ball.radius if foot >= 0 else -1.0
		elif contact_i < 0 and clip != &"":
			toe_pre.append(minf(bh.toe_world(0).distance_to(bp), bh.toe_world(1).distance_to(bp)) - ball.radius)
			min_body_pre = minf(min_body_pre, KickModel.flat(bp - c).length())
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		frames.append(img)
		if contact_i >= 0 and i > contact_i + 40:
			break
	# Tira: COUNT imagenes cada EVERY pasos centradas en el toque (o las primeras si no hubo toque con clip).
	var center: int = contact_i if contact_i >= 0 else frames.size() / 2
	var first: int = maxi(center - every * (count / 2), 0)
	var sheet := Image.create(w * mini(count, 6), h * ((count + 5) / 6), false, Image.FORMAT_RGB8)
	for k in count:
		var idx: int = mini(first + k * every, frames.size() - 1)
		sheet.blit_rect(frames[idx], Rect2i(0, 0, w, h), Vector2i((k % 6) * w, (k / 6) * h))
	sheet.save_png(out)
	var d_end: float = KickModel.flat(ball.global_position - f.global_position).length()
	# Antes del toque, sin los 3 ultimos pasos (el pie llega a la pelota justo antes del toque).
	var min_toe_pre: float = INF
	for k in maxi(toe_pre.size() - 3, 0):
		min_toe_pre = minf(min_toe_pre, toe_pre[k])
	print("RECEPCION angulo %+d v %.1f lat %.1f run %.1f stick %s: clip %s, toque en paso %d, punta del pie a %.3f m de la pelota en el toque; antes del toque: punta minima %.3f m, pelota-cuerpo minima %.2f m; al final pelota a %.2f m (%.1f m/s) | %s | %s" % [int(ang), spd, lat, run, stick_ang, clip, contact_i, toe_at, min_toe_pre, min_body_pre, d_end, ball.linear_velocity.length(), str(rv.stats), str(rv.last_contact)])
	print("PARTE %s (confianza %s), pelota a %.2f m en el contacto | golpeos %s" % [str(rv.last_plan.get("part", "")), str(rv.last_plan.get("confidence", "")), float(rv.last_plan.get("ball_y", -1.0)), str(f.ball_handler.kick_stats)])
	print("MOVIMIENTO %s | plan %s | rechazos %s" % [str(f.ball_handler.json_move.last), str(rv.last_plan), str(rv.rejects)])
	print("RECEIVEVIEW guardado ", out)
	get_tree().quit()

# --- Clip forzado (CLIP=<id>) ----------------------------------------------------------------------------------------

## Puntos del esqueleto vivo que se miden contra la pelota (nombre -> huesos; dos huesos = punto medio; pecho y cabeza,
## desde su superficie).
const LIVE_PARTS := {
	"punta_izq": ["mixamorig_LeftToeBase"], "punta_der": ["mixamorig_RightToeBase"],
	"tobillo_izq": ["mixamorig_LeftFoot"], "tobillo_der": ["mixamorig_RightFoot"],
	"tibia_izq": ["mixamorig_LeftLeg", "mixamorig_LeftFoot"], "tibia_der": ["mixamorig_RightLeg", "mixamorig_RightFoot"],
	"rodilla_izq": ["mixamorig_LeftLeg"], "rodilla_der": ["mixamorig_RightLeg"],
	"muslo_izq": ["mixamorig_LeftUpLeg", "mixamorig_LeftLeg"], "muslo_der": ["mixamorig_RightUpLeg", "mixamorig_RightLeg"],
	"pecho": ["mixamorig_Spine2"], "cabeza": ["mixamorig_Head"],
}
## Distancia (m) de la superficie de la pelota a un punto del esqueleto por debajo de la cual se cuenta como «cerca».
const LIVE_NEAR := 0.12

func _live_points(sk: Skeleton3D, fwd: Vector3) -> Dictionary:
	var out := {}
	for k in LIVE_PARTS:
		var acc := Vector3.ZERO
		for bn in LIVE_PARTS[k]:
			acc += sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bn)).origin
		out[k] = acc / float((LIVE_PARTS[k] as Array).size())
	# El hueso del pecho y el de la cabeza estan dentro del cuerpo: se mide desde su superficie (como JsonReceive).
	out["pecho"] = (out["pecho"] as Vector3) + fwd * 0.13
	out["cabeza"] = (out["cabeza"] as Vector3) + fwd * 0.08 + Vector3(0.0, 0.1, 0.0)
	return out

func _marker(pos: Vector3, col: Color, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	sm.material = mat
	mi.mesh = sm
	add_child(mi)
	mi.global_position = pos
	return mi

## Trayectoria prevista desde `start` con velocidad v: tiempo (s) en que recorre `dist` m en horizontal hacia `dir` (INF si
## no llega en el horizonte) y la posicion y velocidad entonces.
func _arrival(start: Vector3, v: Vector3, dir: Vector3, dist: float) -> Dictionary:
	var traj: PackedVector3Array = BallPredictor.trajectory(start, v, 4.0, 1.0 / 120.0)
	for i in range(1, traj.size()):
		var d1: float = KickModel.flat(traj[i] - start).dot(dir)
		if d1 >= dist:
			var d0: float = KickModel.flat(traj[i - 1] - start).dot(dir)
			var u: float = clampf((dist - d0) / maxf(d1 - d0, 1e-6), 0.0, 1.0)
			return {"t": (float(i - 1) + u) / 120.0, "pos": traj[i - 1].lerp(traj[i], u), "vel": (traj[i] - traj[i - 1]) * 120.0, "traj": traj}
	return {"t": INF, "traj": traj}

func _reaches(start: Vector3, v: Vector3, dir: Vector3, dist: float, y: float) -> bool:
	var r: Dictionary = _arrival(start, v, dir, dist)
	return r["t"] != INF and float((r["pos"] as Vector3).y) >= y and float((r["vel"] as Vector3).y) < 0.0

## Antes de empezar el clip el jugador no se mueve ni gira (si no, se vuelve hacia la pelota y el contacto se mide con
## otro cuerpo que el previsto).
func _hold(f: Footballer, pos: Vector3, yaw: float) -> void:
	f.global_position = pos
	f.velocity = Vector3.ZERO
	f.locomotion.yaw = yaw
	f.locomotion.velocity = Vector3.ZERO
	f.locomotion.speed = 0.0
	f.rotation.y = yaw

## Lanza la pelota de verdad y devuelve cuando (s) y a que altura cruza `dist` m en horizontal hacia `dir`.
func _real_arrival(ball: Ball, start: Vector3, v: Vector3, dir: Vector3, dist: float, aerial: bool) -> Dictionary:
	ball.reset_at(start)
	for i in 6:
		await get_tree().physics_frame
	ball.kick(v, Vector3.ZERO if aerial else ball.rolling_spin(v), null)
	var prev: Vector3 = ball.global_position
	var p0: Vector3 = start
	for i in 180:
		await get_tree().physics_frame
		var bp: Vector3 = ball.global_position
		var d1: float = KickModel.flat(bp - p0).dot(dir)
		if d1 >= dist:
			var d0: float = KickModel.flat(prev - p0).dot(dir)
			var u: float = clampf((dist - d0) / maxf(d1 - d0, 1e-6), 0.0, 1.0)
			return {"t": (float(i) + u) / 60.0, "y": lerpf(prev.y, bp.y, u)}
		prev = bp
	return {"t": INF}

func _forced(id: StringName, f: Footballer, ball: Ball, cam: Camera3D, out: String, every: int, count: int, w: int, h: int, view: String) -> void:
	var a: Animation = PackLibrary.clip(id)
	if a == null:
		print("RECEIVEVIEW clip desconocido ", id)
		return
	var prof: Dictionary = JsonReceive.profile(id)
	var part := StringName(_env("PART", String(prof.get("part", "thigh"))))
	if part == &"leg":
		part = &"thigh"
	var t1: float = float(_env("T", str(prof.get("t", -1.0))))
	if t1 <= 0.0:
		print("RECEIVEVIEW sin instante de contacto: pasar T=<s>")
		return
	var spd: float = float(_env("SPEED", "8"))
	# Por defecto la pelota sale cuando empieza el clip (vuelo ~ instante del contacto + 0.1 s): la trayectoria prevista con
	# que se juzga el contacto es la de ese momento, como en el juego (con vuelos largos BallPredictor se desvia unos cm).
	var cp: Dictionary = JsonReceive.contact_point(id, part, t1)
	# Vuelo: hasta el instante del contacto mas 0.1 s (la pelota sale cuando empieza el clip); por el aire, al menos lo que
	# tarda en subir y bajar hasta esa altura (llega bajando) mas 0.2 s.
	var fly: float = t1 + 0.1
	# Por el aire si la parte del cuerpo no es el pie a ras de piso y el contacto esta a mas de 0.2 m; si no, rodando.
	var aerial: bool = part != &"foot" and float((cp["point"] as Vector3).y) > 0.2
	if aerial:
		fly = maxf(fly, sqrt(2.0 * maxf(float((cp["point"] as Vector3).y) - ball.radius, 0.0) / 9.81) + 0.2)
	var dist_def: float = maxf(spd * fly, 2.5)
	if not aerial:
		# Rodando frena: lo que recorre de verdad (BallPredictor) en ese tiempo.
		var roll: PackedVector3Array = BallPredictor.trajectory(Vector3(0.0, ball.radius, 0.0), Vector3(spd, 0.0, 0.0), fly, 1.0 / 120.0)
		dist_def = maxf(roll[roll.size() - 1].x, 2.5)
	var dist: float = float(_env("DIST", str(dist_def)))
	var m: Dictionary = PackLibrary.meta(id)
	var loco: Locomotion = f.locomotion
	# Cuerpo en el instante del contacto (igual que JsonReceive.plan con el clip empezando ahora).
	var hp: PackedFloat32Array = m.get("heading_path", PackedFloat32Array()) if String(m.get("heading_mode", "")) == "turn" else PackedFloat32Array()
	var rp: PackedVector2Array = m.get("root_path", PackedVector2Array())
	var dur: float = float(m.get("duration", a.length))
	var yaw0: float = loco.yaw - ActionMotion.heading_rel(hp, 0.0)
	var f0: Vector3 = Locomotion.dir_from_yaw(yaw0)
	var r0 := Vector3(-f0.z, 0.0, f0.x)
	var rc: Vector2 = ActionMotion._at(rp, t1) if rp.size() >= 2 else Vector2.ZERO
	var hd: float = ActionMotion.heading_rel(hp, t1)
	var fc: Vector3 = Locomotion.dir_from_yaw(yaw0 + hd)
	var rcv := Vector3(-fc.z, 0.0, fc.x)
	# Direccion de llegada: la del perfil (nombre del clip) o, sin ella, de frente al cuerpo en el instante del contacto
	# (en los clips con giro el cuerpo ya giro hd).
	var from_def: String = str(prof.get("from_deg")) if prof.get("from_deg") != null else str(rad_to_deg(hd))
	var ang: float = float(_env("ANGLE", from_def))
	var origin: Vector3 = KickModel.flat(f.global_position)
	var lp: Vector3 = cp["point"]
	var contact: Vector3 = origin + f0 * rc.x + r0 * rc.y + fc * lp.x + rcv * lp.z + Vector3(0.0, lp.y, 0.0)
	# Pelota: llega desde ANGLE (+ izquierda respecto al frente inicial) al centro que deja la parte del cuerpo delante.
	var from: Vector3 = f0.rotated(Vector3.UP, deg_to_rad(ang))
	var dir: Vector3 = -from
	var target: Vector3 = contact + JsonReceive.contact_offset(dir, ball)
	var start: Vector3 = KickModel.flat(target) + from * dist + Vector3(0.0, ball.radius, 0.0)
	var vel: Vector3 = dir * spd
	if aerial:
		# Por el aire: la menor velocidad vertical que deja la pelota a la altura del contacto bajando (barrido + biseccion).
		var lo: float = -1.0
		var hi: float = -1.0
		var vy: float = 0.0
		while vy < 16.0:
			if _reaches(start, dir * spd + Vector3(0.0, vy, 0.0), dir, dist, target.y):
				hi = vy
				break
			lo = vy
			vy += 0.1
		if hi < 0.0:
			print("RECEIVEVIEW la pelota no llega a %.2f m con SPEED %.1f y DIST %.1f" % [target.y, spd, dist])
			return
		for k in 30:
			var mid: float = (lo + hi) * 0.5
			if _reaches(start, dir * spd + Vector3(0.0, mid, 0.0), dir, dist, target.y):
				hi = mid
			else:
				lo = mid
		vel = dir * spd + Vector3(0.0, hi, 0.0)
	var arr: Dictionary = _arrival(start, vel, dir, dist)
	if arr["t"] == INF:
		print("RECEIVEVIEW la pelota no llega (SPEED %.1f, DIST %.1f)" % [spd, dist])
		return
	var t_arr: float = float(arr["t"])
	# Calibracion con la fisica real (BallPredictor se desvia unos cm en vuelos largos): tiros de prueba con el jugador
	# apartado; se corrige la velocidad vertical hasta que la pelota real pase a la altura del contacto y se toma el
	# instante real de llegada.
	var home: Vector3 = f.global_position
	var yaw_hold: float = loco.yaw
	f.global_position = home + Vector3(0.0, 0.0, 30.0)
	for k in 4:
		var shot: Dictionary = await _real_arrival(ball, start, vel, dir, dist, aerial)
		loco.yaw = yaw_hold
		if shot["t"] == INF:
			break
		t_arr = float(shot["t"])
		var dy: float = target.y - float(shot["y"])
		if not aerial or absf(dy) < 0.01:
			break
		vel.y += dy / maxf(t_arr, 0.2)
	f.global_position = home
	f.velocity = Vector3.ZERO
	for k in 5:
		await get_tree().physics_frame
		_hold(f, home, yaw_hold)
	var wait_frames: int = maxi(int(round((t_arr - t1) * 60.0)), 0)
	if t_arr < t1:
		print("RECEIVEVIEW aviso: la pelota llega en %.2f s, antes del contacto del clip (%.2f s): subir DIST" % [t_arr, t1])
	# Marcas: trayectoria prevista (amarillo) y punto de contacto supuesto (rojo).
	var traj: PackedVector3Array = arr["traj"]
	for i in range(0, traj.size(), 12):
		if float(i) / 120.0 > t_arr + 0.05:
			break
		_marker(traj[i], Color(1.0, 0.85, 0.1), 0.025)
	_marker(contact, Color(1.0, 0.1, 0.1), 0.035)
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(4, 2)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	layer.add_child(label)
	var rv: JsonReceive = f.ball_handler.receive
	rv._cooldown = 999.0   # sin seleccion automatica: solo el clip forzado (se renueva en cada paso)
	# Ni la recepcion asistida ni la persecucion de la pelota suelta mueven al jugador: el clip empieza donde esta.
	f.is_human_controlled = false
	ball.reset_at(start)
	for i in 10:
		await get_tree().physics_frame
		_hold(f, home, yaw_hold)
	ball.kick(vel, Vector3.ZERO if aerial else ball.rolling_spin(vel), null)
	var frames: Array[Image] = []
	var started: int = -1
	var contact_i: int = -1
	var first_near := {}
	var nearest_at_contact: String = ""
	var leg_geo: String = ""
	var body_err: String = ""
	var body_plan: Vector3 = origin + f0 * rc.x + r0 * rc.y
	var sk: Skeleton3D = f.visual.skeleton if f.visual != null else null
	var bh: BallHandler = f.ball_handler
	for i in 260:
		rv._cooldown = 999.0
		if i < wait_frames:
			_hold(f, home, yaw_hold)
		if i == wait_frames:
			var traj_now: PackedVector3Array = BallPredictor.trajectory(ball.global_position, ball.linear_velocity, JsonReceive.HORIZON, JsonReceive.TRAJ_STEP, ball.angular_velocity)
			var plan := {"clip": id, "start_at": 0.0, "inc": KickModel.flat(dir).normalized(), "yaw0": yaw0, "origin": origin,
				"corr": Vector3.ZERO, "dt1": t1, "residual": 0.0, "dy": 0.0, "turn": rad_to_deg(ActionMotion.heading_rel(hp, dur)),
				"dv": 0.0, "role": &"", "part": part, "t_contact": t1, "foot": int(cp["foot"]), "cp": cp,
				"confidence": prof.get("confidence", ""), "post_t": float(prof.get("post_t", -1.0)),
				"from_deg": ang, "touches_after": prof.get("touches_after", []), "contact_local": JsonReceive._local_point(rc, hd, lp),
				"incoming_speed": ball.linear_velocity.length(), "ball_y": target.y, "pred_ball": target, "pred_contact": contact,
				"traj": traj_now, "frame": Engine.get_physics_frames()}
			if bh.json_move.start_receive(plan):
				started = i
				rv.last_plan = plan
			else:
				print("RECEIVEVIEW el arbitro no dejo empezar el clip")
		await get_tree().physics_frame
		var c: Vector3 = f.global_position
		match view:
			"top":
				cam.global_position = Vector3(c.x + 0.3, 7.0, c.z + 0.01)
			"three":
				cam.global_position = Vector3(c.x + 3.2, 1.6, c.z + 3.2)
			"front":
				cam.global_position = Vector3(c.x + 4.0, 1.2, c.z + 0.6)
			"close":
				cam.global_position = Vector3(c.x + 2.0, 1.45, c.z + 2.7)
			_:
				cam.global_position = Vector3(c.x + 0.4, 0.95, c.z + 3.6)
		cam.look_at(Vector3(c.x + 0.3, 0.6 if view != "top" else 0.0, c.z), Vector3.UP)
		var bp: Vector3 = ball.global_position
		var clip_t: float = f.actions.motion.t if started >= 0 and bh.json_move.active else -1.0
		if _env("DEBUG", "") != "" and started >= 0 and bh.json_move.active:
			# Desvio de la pelota real respecto de la trayectoria prevista al empezar (JsonBallMove corta a > 0.35 m / 1 m/s).
			var tp: float = float(Engine.get_physics_frames() - int(rv.last_plan["frame"])) / float(Engine.physics_ticks_per_second)
			var pp: Vector3 = JsonReceive._at(rv.last_plan["traj"], tp)
			var vp: Vector3 = (JsonReceive._at(rv.last_plan["traj"], tp + JsonReceive.TRAJ_STEP) - pp) / JsonReceive.TRAJ_STEP
			print("DESVIO paso %d: %.3f m, %.2f m/s (pelota %s, %s), rumbo %+.1f grados" % [i - started, bp.distance_to(pp), (ball.linear_velocity - vp).length(), str(bp), str(ball.linear_velocity), rad_to_deg(wrapf(loco.yaw - yaw0, -PI, PI))])
		var near_name: String = ""
		var near_d: float = INF
		if sk != null:
			var pts: Dictionary = _live_points(sk, loco.forward())
			for k in pts:
				var d: float = (pts[k] as Vector3).distance_to(bp) - ball.radius
				if d < near_d:
					near_d = d
					near_name = k
				if d < LIVE_NEAR and not first_near.has(k) and started >= 0:
					first_near[k] = {"paso": i - started, "clip_t": clip_t, "d": d}
			if started >= 0 and leg_geo == "" and clip_t >= t1:
				leg_geo = _leg_geometry(pts)
				var be: Vector3 = KickModel.flat(c) - body_plan
				body_err = "%.2f m (adelante %+.2f, derecha %+.2f); rumbo real-previsto %+.0f grados" % [be.length(), be.dot(f0), be.dot(r0), rad_to_deg(wrapf(loco.yaw - (yaw0 + hd), -PI, PI))]
		if contact_i < 0 and rv.stats["contact"] > 0 and bh.json_move.clip == id:
			contact_i = i
			nearest_at_contact = "%s a %.3f m (pelota a %.2f m de altura)" % [near_name, near_d, bp.y]
		label.text = "%s  t=%s  %s %.2f m%s" % [String(id), ("%.2f s" % clip_t) if clip_t >= 0.0 else "-", near_name, near_d, "  CONTACTO" if i == contact_i else ""]
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if i == contact_i else Color.WHITE)
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		frames.append(img)
		if started >= 0 and not bh.json_move.active and i > maxi(contact_i, started + int(round(t1 * 60.0))) + every * (count / 2) + 6:
			break
	var center: int = contact_i if contact_i >= 0 else (started + int(round(t1 * 60.0)) if started >= 0 else frames.size() / 2)
	var cols: int = int(_env("COLS", "6"))
	var first: int = clampi(center - every * (count / 2), 0, maxi(frames.size() - 1, 0))
	var sheet := Image.create(w * mini(count, cols), h * ((count + cols - 1) / cols), false, Image.FORMAT_RGB8)
	for k in count:
		var idx: int = mini(first + k * every, frames.size() - 1)
		sheet.blit_rect(frames[idx], Rect2i(0, 0, w, h), Vector2i((k % cols) * w, (k / cols) * h))
	sheet.save_png(out)
	var mv: Dictionary = bh.json_move.last
	var d_end: float = KickModel.flat(ball.global_position - f.global_position).length()
	print("CLIP %s parte supuesta %s t %.3f s | perfil %s | pelota desde %+.0f grados a %.1f m/s, llega a %.2f m de altura en %.2f s" % [String(id), part, t1, str(prof.get("status", "-")), ang, spd, target.y, t_arr])
	var miss: String = "NO (%s, hueco %s)" % [str(mv.get("aborted", mv.get("ended", ""))), str(mv.get("contact_gap", "-"))]
	print("CONTACTO sistema: %s | paso %d del clip (previsto %d) | parte viva mas cercana %s | al final pelota a %.2f m del jugador (%.1f m/s, altura %.2f)" % ["si" if contact_i >= 0 else miss, contact_i - started if contact_i >= 0 else -1, int(round(t1 * 60.0)), nearest_at_contact, d_end, ball.linear_velocity.length(), ball.global_position.y])
	var order: Array = first_near.keys()
	order.sort_custom(func(x, y): return int(first_near[x]["paso"]) < int(first_near[y]["paso"]))
	var near_txt: Array[String] = []
	for k in order:
		near_txt.append("%s@%d(%.2fs,%.3fm)" % [k, int(first_near[k]["paso"]), float(first_near[k]["clip_t"]), float(first_near[k]["d"])])
	print("CERCA (primer paso a < %.2f m de la superficie): %s" % [LIVE_NEAR, ", ".join(near_txt)])
	print("PIERNA en t: %s" % leg_geo)
	print("CUERPO en t: real frente al previsto %s" % body_err)
	print("MOVIMIENTO %s | contacto %s" % [str(mv), str(rv.last_contact)])
	print("RECEIVEVIEW guardado ", out)

## Geometria de la pierna mas levantada: elevacion (grados respecto de la vertical hacia abajo) del muslo y de la tibia,
## alturas de la rodilla y de la punta del pie, y la del pecho.
func _leg_geometry(pts: Dictionary) -> String:
	var side: String = "izq" if (pts["rodilla_izq"] as Vector3).y > (pts["rodilla_der"] as Vector3).y else "der"
	var knee: Vector3 = pts["rodilla_" + side]
	var hip: Vector3 = (pts["muslo_" + side] as Vector3) * 2.0 - knee
	var ank: Vector3 = pts["tobillo_" + side]
	var toe: Vector3 = pts["punta_" + side]
	var thigh_el: float = rad_to_deg((knee - hip).angle_to(Vector3.DOWN))
	var shin_el: float = rad_to_deg((ank - knee).angle_to(Vector3.DOWN))
	return "pierna %s: muslo %.0f grados, tibia %.0f grados, rodilla %.2f m, punta %.2f m, pecho %.2f m" % [side, thigh_el, shin_el, knee.y, toe.y, (pts["pecho"] as Vector3).y]
