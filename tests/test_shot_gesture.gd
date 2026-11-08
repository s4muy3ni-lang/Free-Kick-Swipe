extends TestCase
## Disparo por trazo (ShotGesture -> GestureShotModel -> ShotSolver): criterios de aceptacion del sistema de gestos con
## trazos sinteticos (cortos, largos, lentos, rapidos, rectos, curvos, irregulares, que terminan bajando), la
## normalizacion por alto de pantalla, el limite de muestras y que la trayectoria prevista coincida con el vuelo real.

const H := 720.0

var _cam: Camera3D
var _ball := Vector3(41.5, 0.1, 0.0)

func _ctx() -> Dictionary:
	return GestureShotModel.context(52.5, Vector2(15.0, 29.0), true, 3.66, 2.44, 0.1)

## Camara de penal (la del juego) para convertir el trazo en un punto del arco.
func _camera() -> Camera3D:
	if _cam == null or not is_instance_valid(_cam):
		_cam = Camera3D.new()
		spawn(_cam)
		var f: Array = SpCamera.behind_ball(_ball, Vector3(52.5, 1.0, 0.0), 1.0, true)
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_cam.fov = f[2]
		_cam.global_position = f[0]
		_cam.look_at(f[1], Vector3.UP)
		_cam.current = true
	return _cam

func _params(g: ShotGesture) -> ShotParams:
	var p: ShotParams = GestureShotModel.build(g.features(), g.last_px(), _camera(), _ball, _ctx(), g.tuning)
	GestureShotModel.solve(p, _ball, _ctx(), false)
	return p

func _from() -> Vector2:
	return _camera().unproject_position(_ball)

func _to(y: float, z: float = 0.0) -> Vector2:
	return _camera().unproject_position(Vector3(52.5, y, z))

func test_fast_swipe_gives_more_power_than_slow_and_stays_in_limits() -> void:
	await physics_frames(1)
	var t := GestureTuning.new()
	var slow: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(0.8), 0.55))
	var fast: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(0.8), 0.12))
	var very: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(0.8), 0.03))
	note("mismo trazo: lento %.2f (%.1f m/s), rapido %.2f (%.1f m/s), muy rapido %.2f (%.1f m/s)" % [slow.power, slow.speed, fast.power, fast.speed, very.power, very.speed])
	check(fast.power > slow.power + 0.25, "el trazo rapido da mas potencia que el lento")
	check_range(very.power, t.power_min, t.power_max, "la potencia queda dentro de sus limites")
	check(very.speed <= 29.0 + 0.01, "la velocidad de salida no supera el maximo del modo")

func test_length_is_control_not_power() -> void:
	await physics_frames(1)
	var t := GestureTuning.new()
	var a: Vector2 = _from()
	var b: Vector2 = _to(0.8)
	# Misma velocidad del dedo: el corto tarda la mitad.
	var short: ShotParams = _params(ShotGesture.synthetic(t, H, a, a + (b - a) * 0.5, 0.11))
	var long: ShotParams = _params(ShotGesture.synthetic(t, H, a, b, 0.22))
	note("misma velocidad: corto largo %.2f potencia %.2f error %.2f°; largo largo %.2f potencia %.2f error %.2f°" % [short.gesture_length, short.power, short.error_deg, long.gesture_length, long.power, long.error_deg])
	check(absf(short.power - long.power) < 0.1, "con la misma velocidad, el largo no cambia la potencia")
	check(long.error_deg < short.error_deg, "el trazo largo da mas control (menos error)")

func test_upward_swipe_raises_the_ball() -> void:
	await physics_frames(1)
	var t := GestureTuning.new()
	var low: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(0.3, 1.5), 0.25))
	var high: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(2.0, 1.5), 0.25))
	note("bajo: llega a %.2f m con %.1f°; alto: llega a %.2f m con %.1f°" % [low.target.y, low.launch_angle, high.target.y, high.launch_angle])
	check(high.target.y > low.target.y + 1.0, "un trazo que sube mas eleva el punto de llegada")
	check(high.launch_angle > low.launch_angle + 2.0, "y el angulo de salida")
	check(absf(high.crossing.y - high.target.y) < 0.15, "la fisica lleva la pelota a esa altura")

func test_curved_swipe_gives_lateral_spin_on_its_side() -> void:
	await physics_frames(1)
	var t := GestureTuning.new()
	var straight: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(1.0), 0.25, 0.0))
	var right: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(1.0), 0.25, 0.18))
	var left: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(1.0), 0.25, -0.18))
	note("efecto: recto %.1f, curva a la derecha %.1f, a la izquierda %.1f rad/s" % [straight.lateral_spin, right.lateral_spin, left.lateral_spin])
	check(absf(straight.lateral_spin) < 1.0, "un trazo recto no da efecto")
	check(right.lateral_spin > 5.0 and left.lateral_spin < -5.0, "la curva da efecto hacia su lado")
	check(right.gesture_type == "con_efecto", "el trazo curvo es un tiro con efecto (%s)" % right.gesture_type)
	# Con efecto, la pelota sale hacia el lado de la curva y se cierra hacia el objetivo (Magnus real).
	# Punto a mitad de camino (antes del arco): la trayectoria sigue mas alla de la linea.
	var mid: Vector3 = right.trajectory[0]
	for q in right.trajectory:
		if q.x >= _ball.x + (52.5 - _ball.x) * 0.5:
			mid = q
			break
	var start_z: float = _ball.z + (right.target.z - _ball.z) * (mid.x - _ball.x) / (52.5 - _ball.x)
	check(mid.z > start_z, "con la curva a la derecha la pelota sale abierta a la derecha (%.2f > %.2f)" % [mid.z, start_z])
	check(absf(right.crossing.z - right.target.z) < 0.2, "y se cierra hasta el objetivo")

func test_stable_gesture_is_more_precise() -> void:
	await physics_frames(1)
	var t := GestureTuning.new()
	var clean: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(1.0), 0.3, 0.0, 0.0))
	var shaky: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(1.0), 0.3, 0.0, 5.0, 3))
	note("suavidad limpio %.2f (error %.2f°), tembloroso %.2f (error %.2f°)" % [clean.smoothness, clean.error_deg, shaky.smoothness, shaky.error_deg])
	check(clean.smoothness > shaky.smoothness, "el trazo limpio es mas suave")
	check(clean.error_deg < shaky.error_deg, "y mas preciso")
	check(shaky.error_deg < 5.0, "el temblor no castiga de mas")

func test_descending_end_keeps_it_low_with_topspin() -> void:
	await physics_frames(1)
	var t := GestureTuning.new()
	var plain: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(1.4), 0.25))
	var hook: ShotParams = _params(ShotGesture.synthetic(t, H, _from(), _to(1.4), 0.25, 0.0, 0.0, 1, Vector2(0, 150)))
	note("final recto llega a %.2f m; final hacia abajo llega a %.2f m con efecto hacia delante %.1f" % [plain.target.y, hook.target.y, -hook.spin.dot(SpClips.right_of(hook.direction))])
	check(hook.target.y < plain.target.y - 0.2, "un trazo que termina bajando baja la llegada")
	check(-hook.spin.dot(SpClips.right_of(hook.direction)) > 1.0, "y agrega efecto hacia delante (cae)")

func test_gestures_produce_the_shot_types_naturally() -> void:
	await physics_frames(1)
	var t := GestureTuning.new()
	var a: Vector2 = _from()
	var cases := [
		["globo", ShotGesture.synthetic(t, H, a, _to(2.2), 0.9)],
		["potente_raso", ShotGesture.synthetic(t, H, a, _to(0.3, 2.0), 0.1)],
		["con_efecto", ShotGesture.synthetic(t, H, a, _to(1.2, -1.5), 0.3, 0.2)],
		["rapido_corto", ShotGesture.synthetic(t, H, a, a + (_to(0.6) - a) * 0.4, 0.05)],
		["elevado", ShotGesture.synthetic(t, H, a, _to(2.0, 2.5), 0.14)],
		["colocado", ShotGesture.synthetic(t, H, a, a + (_to(0.6, 2.8) - a) * 0.75, 0.45)],
	]
	for c in cases:
		var p: ShotParams = _params(c[1])
		note("%s: potencia %.2f, llegada %.2f m, efecto %.1f, largo %.2f, suavidad %.2f -> %s (golpeo %s)" % [c[0], p.power, p.target.y, p.lateral_spin, p.gesture_length, p.smoothness, p.gesture_type, ShotCatalog.Kind.keys()[p.kind]])
		check(p.gesture_type == c[0], "el gesto da un tiro %s (dio %s)" % [c[0], p.gesture_type])

func test_features_do_not_depend_on_screen_resolution_and_samples_are_bounded() -> void:
	var t := GestureTuning.new()
	var g1: ShotGesture = ShotGesture.synthetic(t, 720.0, Vector2(640, 600), Vector2(700, 200), 0.3, 0.1)
	var g2: ShotGesture = ShotGesture.synthetic(t, 1440.0, Vector2(1280, 1200), Vector2(1400, 400), 0.3, 0.1)
	var f1: Dictionary = g1.features()
	var f2: Dictionary = g2.features()
	note("720p: largo %.3f vel %.2f curva %.3f; 1440p: largo %.3f vel %.2f curva %.3f" % [f1["length"], f1["avg_speed"], f1["curvature"], f2["length"], f2["avg_speed"], f2["curvature"]])
	check_near(float(f2["length"]), float(f1["length"]), 0.01, "mismo largo en alturas de pantalla")
	check_near(float(f2["avg_speed"]), float(f1["avg_speed"]), 0.05, "misma velocidad")
	check_near(float(f2["curvature"]), float(f1["curvature"]), 0.01, "misma curvatura")
	var g := ShotGesture.new(t, 720.0)
	g.begin(Vector2(0, 700), 0.0)
	for i in 2000:
		g.add(Vector2(float(i) * 0.5, 700.0 - float(i) * 0.3), float(i) / 120.0)
	check(g.count() <= t.max_samples, "las muestras quedan limitadas (%d <= %d)" % [g.count(), t.max_samples])
	var g3 := ShotGesture.new(t, 720.0)
	g3.begin(Vector2(100, 100), 0.0)
	var stored: int = 0
	for i in 20:
		if g3.add(Vector2(100.0 + 0.3 * float(i % 2), 100.0), float(i) / 120.0):
			stored += 1
	check(stored == 0, "los micro movimientos del dedo no se registran (zona muerta)")

func test_prediction_matches_the_real_ball() -> void:
	var stadium := Stadium11.new()
	spawn(stadium)
	stadium.build(PitchConfig.football11())
	var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	spawn(ball)
	ball.reset_at(_ball)
	await physics_frames(5)
	var t := GestureTuning.new()
	for c in [["recto raso", _to(0.4, 2.0), 0.0, 0.12], ["curvo alto", _to(1.8, -2.0), 0.18, 0.3], ["globo", _to(2.0), 0.0, 0.9]]:
		ball.reset_at(_ball)
		await physics_frames(3)
		var g: ShotGesture = ShotGesture.synthetic(t, H, _from(), c[1], float(c[3]), float(c[2]))
		var prev: ShotParams = GestureShotModel.build(g.features(), g.last_px(), _camera(), _ball, _ctx(), t)
		GestureShotModel.solve(prev, _ball, _ctx(), true)
		var real: ShotParams = GestureShotModel.build(g.features(), g.last_px(), _camera(), _ball, _ctx(), t)
		GestureShotModel.solve(real, _ball, _ctx(), false)
		ball.kick(real.velocity, real.spin, null)
		var cross := Vector3.INF
		var last: Vector3 = ball.global_position
		for i in 240:
			await tree.physics_frame
			var p: Vector3 = ball.global_position
			if last.x < 52.4 and p.x >= 52.4:
				cross = last.lerp(p, (52.4 - last.x) / (p.x - last.x))
				break
			last = p
		var pc: Vector3 = ShotSolver.crossing(prev.trajectory, 52.4)
		note("%s: previsto (%.2f, %.2f), real (%.2f, %.2f)" % [c[0], pc.z, pc.y, cross.z, cross.y])
		check(cross != Vector3.INF, "%s: la pelota real llega al arco" % c[0])
		if cross != Vector3.INF:
			check(Vector2(cross.z - pc.z, cross.y - pc.y).length() < 0.45, "%s: la prevision coincide con el vuelo real (< 0,45 m)" % c[0])
	cleanup()
