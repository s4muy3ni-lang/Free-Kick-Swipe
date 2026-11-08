extends TestCase
## Efecto (chanfle / comba): el giro lateral curva la pelota por el efecto Magnus de la fisica real de la pelota. Un tiro
## con efecto sale "abierto" y la curva lo devuelve; el gesto del joystick (girar entre pulsar y soltar) lo pide.

func _fly(ball: Ball, v: Vector3, spin: Vector3, seconds: float) -> Array:
	ball.reset_at(Vector3(0.0, 0.3, 0.0))
	await physics_frames(2)
	ball.kick(v, spin, null)
	var pts: Array = []
	for i in int(seconds * 60.0):
		await tree.physics_frame
		pts.append(ball.global_position)
	return pts

func test_side_spin_curves_the_real_ball() -> void:
	var w: Dictionary = await make_world(Vector3(0.0, 0.3, 0.0))
	var ball: Ball = w["ball"]
	var v := Vector3(22.0, 4.0, 0.0)
	var straight: Array = await _fly(ball, v, Vector3.ZERO, 0.8)
	var curl_right: Array = await _fly(ball, v, KickModel.curl_spin(Vector3(1, 0, 0), 1.0, 50.0), 0.8)
	var curl_left: Array = await _fly(ball, v, KickModel.curl_spin(Vector3(1, 0, 0), -1.0, 50.0), 0.8)
	var zs: float = (straight[-1] as Vector3).z
	var zr: float = (curl_right[-1] as Vector3).z
	var zl: float = (curl_left[-1] as Vector3).z
	note("tras 0.8 s (~17 m): sin efecto z=%.2f, chanfle a la derecha z=%.2f, a la izquierda z=%.2f" % [zs, zr, zl])
	# Mirando a +X, la derecha es +Z.
	check(zr > zs + 0.6, "con efecto a la derecha la pelota se curva a la derecha (%.2f m)" % (zr - zs))
	check(zl < zs - 0.6, "y al reves (%.2f m)" % (zl - zs))
	# La curva crece con el tiempo (es una curva, no un angulo de salida): desvio a mitad < mitad del desvio final.
	var mid: float = (curl_right[curl_right.size() / 2] as Vector3).z - (straight[straight.size() / 2] as Vector3).z
	check(mid < 0.5 * (zr - zs), "la desviacion aumenta en el vuelo (mitad %.2f m de %.2f m)" % [mid, zr - zs])
	check(ball.trail_active or ball.linear_velocity.length() > 10.0, "estela activa en el tiro rapido")

func test_stick_gesture_asks_for_curl_and_shot_bends_back_on_goal() -> void:
	check_near(BallHandler.curl_from(Vector3(1, 0, 0), Vector3(1, 0, 0)), 0.0, 0.001, "sin giro, sin efecto")
	var right_turn: float = BallHandler.curl_from(Vector3(1, 0, 0), Vector3(1, 0, 0.8).normalized())
	check(right_turn > 0.4, "girar el joystick a la derecha (+Z mirando a +X) pide efecto a la derecha (%.2f)" % right_turn)
	check(BallHandler.curl_from(Vector3(1, 0, 0), Vector3(1, 0, -0.8).normalized()) < -0.4, "a la izquierda, efecto a la izquierda")
	# Tiro con chanfle real: la salida se abre y la pelota acaba en el arco.
	var ctx: MatchContext = await make_match(Vector3(5.0, 0.11, 4.0))
	var p: Footballer = add_player(ctx, 0, Vector3(4.5, 0.0, 4.0), 70)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, -0.2).normalized())
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var aim: Vector3 = (Vector3(20.0, 0.0, -1.0) - Vector3(5.0, 0.0, 4.0)).normalized()
	var res: KickModel.KickResult = ShotAssist.compute(p, ctx, aim, 0.7, false, rng, 0.5, -0.9)
	note("tiro con chanfle a la izquierda: tipo %s, efecto %.1f, sale %.1f grados abierto" % [res.kind, res.curl, KickModel.signed_angle_deg(aim, res.final_dir)])
	check(String(res.kind) == "curl_shot", "tipo de tiro con efecto")
	check(KickModel.signed_angle_deg(aim, res.final_dir) < -1.5, "sale abierto hacia la derecha para cerrarse a la izquierda")
	ctx.ball.kick(res.velocity, res.spin, p)
	p.ball_handler.lockout = 1.0   # el que patea no vuelve a tocarla (como tras cualquier golpeo)
	var goal := [false]
	ctx.pitch.goal_scored.connect(func(_g: Goal, _pos: Vector3) -> void: goal[0] = true)
	var min_z: float = INF
	for i in 120:
		await tree.physics_frame
		if ctx.ball.global_position.x > 18.0:
			min_z = minf(min_z, absf(ctx.ball.global_position.z))
	note("pelota en la linea de gol a |z|=%.2f m (medio arco %.2f), gol=%s" % [min_z, ctx.pitch.config.half_goal(), str(goal[0])])
	check(min_z < ctx.pitch.config.half_goal() + 0.6, "la curva la devuelve hacia el arco")

## Vuela un tiro ya calculado y devuelve el desvio lateral maximo respecto a la salida (con signo: + = derecha del
## golpeo) y donde cruza la linea de gol (x = 19.9).
func _fly_shot(ctx: MatchContext, p: Footballer, ball_pos: Vector3, res: KickModel.KickResult, knuckle: bool) -> Dictionary:
	var b: Ball = ctx.ball
	b.reset_at(ball_pos)
	await physics_frames(4)
	b.kick(res.velocity, res.spin, p)
	if knuckle and res.knuckle_accel > 0.0:
		b.set_knuckle(res.knuckle_accel, res.knuckle_freq, res.knuckle_phase)
	var d0: Vector3 = KickModel.flat(res.velocity).normalized()
	var out := {"dev": 0.0, "z": NAN, "y_max": 0.0}
	for i in 100:
		await tree.physics_frame
		var dev: float = KickModel.flat(b.global_position - ball_pos).cross(d0).y
		if absf(dev) > absf(float(out["dev"])):
			out["dev"] = dev
		out["y_max"] = maxf(float(out["y_max"]), b.global_position.y)
		if b.global_position.x > 19.9:
			out["z"] = b.global_position.z
			break
	return out

## Tiro asistido hacia el centro del arco con la pelota a un lado del cuerpo (side > 0: a la derecha, pie derecho).
func _natural_shot(ctx: MatchContext, p: Footballer, ball_pos: Vector3, side: float, charge: float, lob: bool, seed: int = 5) -> KickModel.KickResult:
	p.place_at(ball_pos + Vector3(-0.5, 0.0, -side), Locomotion.yaw_from_dir(Vector3(1, 0, 0)))
	ctx.ball.reset_at(ball_pos)
	await physics_frames(4)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var to_goal: Vector3 = KickModel.flat(Vector3(20.0, 0.0, 0.0) - ball_pos).normalized()
	return ShotAssist.compute(p, ctx, to_goal, charge, lob, rng, 0.6)

## Cada golpeo tiene su efecto natural sin pedirlo: el empeine rosca hacia el lado del pie (diestro: se cierra a la
## izquierda), el colocado con el interior rosca mas, el potente sale casi sin giro y "flota", la vaselina lleva
## contragiro. Con la salida abierta lo justo, la curva acaba en el punto de mira.
func test_every_shot_has_its_natural_spin() -> void:
	var ctx: MatchContext = await make_match(Vector3(9.0, 0.11, 0.0))
	var p: Footballer = add_player(ctx, 0, Vector3(8.5, 0.0, 0.0), 60)
	p.set_physics_process(false)
	p.ball_handler.lockout = 10.0
	var spot := Vector3(9.0, 0.11, 0.0)
	# Por pie, 6 tiros (el golpe imperfecto tambien da algo de giro lateral, a un lado o al otro).
	var curve := {}
	for side in [0.15, -0.15]:
		var with_sign := 0
		var dev_sum := 0.0
		var miss_sum := 0.0
		for sd in 6:
			var r: KickModel.KickResult = await _natural_shot(ctx, p, spot, side, 0.6, false, 20 + sd)
			var f: Dictionary = await _fly_shot(ctx, p, spot, r, true)
			if r.spin.y * side > 0.0:
				with_sign += 1
			dev_sum += float(f["dev"])
			miss_sum += absf(float(f["z"]) - r.aim_point.z)
		curve[side] = dev_sum / 6.0
		note("empeine %s: %d de 6 roscan hacia el lado del pie, curva media %.2f m, a %.2f m del punto de mira" % ["derecho" if side > 0.0 else "izquierdo", with_sign, dev_sum / 6.0, miss_sum / 6.0])
		check(with_sign >= 5, "el empeine %s rosca hacia %s" % ["derecho" if side > 0.0 else "izquierdo", "la izquierda" if side > 0.0 else "la derecha"])
		check(miss_sum / 6.0 < 0.4, "y la curva acaba cerca del punto de mira")
	check(float(curve[0.15]) < -0.05 and float(curve[-0.15]) > 0.05, "en vuelo: diestro a la izquierda, zurdo a la derecha")
	var f_right := {"dev": curve[0.15]}

	var placed_spot := Vector3(9.0, 0.11, 1.5)
	var r_placed: KickModel.KickResult = await _natural_shot(ctx, p, placed_spot, 0.15, 0.15, false)
	var f_placed: Dictionary = await _fly_shot(ctx, p, placed_spot, r_placed, true)
	note("colocado: %s, giro vertical %.1f rad/s, curva %.2f m, mira z %.2f, llega z %.2f" % [r_placed.kind, r_placed.spin.y, f_placed["dev"], r_placed.aim_point.z, f_placed["z"]])
	check(String(r_placed.kind) == "placed_shot" and absf(r_placed.spin.y) > 20.0, "el colocado lleva mucha rosca")
	check(absf(float(f_placed["dev"])) > absf(float(f_right["dev"])) + 0.1, "y curva mas que el empeine (%.2f frente a %.2f m)" % [absf(float(f_placed["dev"])), absf(float(f_right["dev"]))])
	check(absf(float(f_placed["z"]) - r_placed.aim_point.z) < 0.4, "cerrandose sobre el punto de mira")

	var far := Vector3(2.0, 0.11, 0.0)
	var r_power: KickModel.KickResult = await _natural_shot(ctx, p, far, 0.15, 0.95, false)
	var f_float: Dictionary = await _fly_shot(ctx, p, far, r_power, true)
	var f_still: Dictionary = await _fly_shot(ctx, p, far, r_power, false)
	note("potente de 18 m: %s, giro %.1f rad/s, flotado %.1f m/s2 a %.1f Hz; en la linea z %.2f (sin flotado %.2f)" % [r_power.kind, r_power.spin.length(), r_power.knuckle_accel, r_power.knuckle_freq, f_float["z"], f_still["z"]])
	check(String(r_power.kind) == "power_shot" and r_power.spin.length() < 12.0 and r_power.knuckle_accel > 0.0, "el potente sale casi sin giro y flota")
	var drift: float = absf(float(f_float["z"]) - float(f_still["z"]))
	check(drift > 0.03 and drift < 0.6, "el flotado lo mueve sin desviarlo del todo (%.2f m)" % drift)

	var r_lob: KickModel.KickResult = await _natural_shot(ctx, p, spot, 0.15, 0.6, true)
	var back: float = r_lob.spin.dot(-Vector3.UP.cross(r_lob.final_dir))
	note("vaselina: contragiro %.1f rad/s" % back)
	check(back > 15.0, "la vaselina lleva contragiro")

## El balon dibujado gira con el eje y el sentido reales, pero nunca mas de 20 grados por imagen: el patron se repite
## cada ~63 grados y a mas giro por imagen se veria quieto o al reves (efecto rueda de carro). El desenfoque sigue el
## giro real del medio fotograma (obturador): despacio casi nitido, rapido en bandas.
func test_drawn_ball_spin_is_readable() -> void:
	var w: Dictionary = await make_world(Vector3(0.0, 0.11, 0.0))
	var ball: Ball = w["ball"]
	var visual: MeshInstance3D = ball.get_node("Visual")
	await physics_frames(3)
	for v in [2.0, 6.0, 12.0]:
		ball.reset_at(Vector3(0.0, 0.11, 0.0))
		await physics_frames(3)
		var vel := Vector3(v, 0.0, 0.0)
		ball.kick(vel, ball.rolling_spin(vel))
		await physics_frames(2)
		await tree.process_frame
		var before: Basis = visual.global_basis
		await tree.process_frame
		var delta: Quaternion = (visual.global_basis * before.inverse()).get_rotation_quaternion()
		var axis_dot: float = delta.get_axis().dot(ball.angular_velocity.normalized())
		var real_deg: float = rad_to_deg(ball.angular_velocity.length()) / 60.0
		note("pase a %.0f m/s: gira %.0f grados por imagen el real, %.1f el dibujado; desenfoque en %.0f grados" % [v, real_deg, rad_to_deg(delta.get_angle()), ball.visual_spin_blur_deg])
		check(rad_to_deg(delta.get_angle()) <= Ball.VISUAL_SPIN_DEG_PER_FRAME + 0.5, "dibujado a 20 grados por imagen o menos (%.0f m/s)" % v)
		check(axis_dot > 0.98, "con el eje y el sentido del giro real (%.0f m/s)" % v)
		check_near(ball.visual_spin_blur_deg, real_deg * Ball.VISUAL_SHUTTER, 2.0, "desenfoque a lo largo del giro real de medio fotograma (%.0f m/s)" % v)
