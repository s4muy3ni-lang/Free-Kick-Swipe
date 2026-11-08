extends TestCase
## Prediccion de la trayectoria (BallPredictor, la usan el arquero, la recepcion y la IA) frente a la pelota real (Jolt):
## globos largos, disparos con bote, pases rasos y tiros tensos. El error en el instante de cruce y a lo largo del vuelo no
## debe crecer de forma inaceptable en los vuelos largos.

func _case(from: Vector3, v: Vector3, spin: Vector3, seconds: float) -> Dictionary:
	var ctx: MatchContext = await make_match(from)
	var b: Ball = ctx.ball
	b.reset_at(from)
	await physics_frames(3)
	b.kick(v, spin, null)
	await tree.physics_frame
	var traj: PackedVector3Array = BallPredictor.trajectory(b.global_position, b.linear_velocity, seconds, 1.0 / 30.0, b.angular_velocity)
	var worst: float = 0.0
	var at_end: float = 0.0
	var n: int = int(seconds * 60.0)
	for i in n:
		await tree.physics_frame
		var t: float = float(i + 1) / 60.0
		var k: float = clampf(t * 30.0, 0.0, float(traj.size() - 1))
		var j: int = mini(int(k), traj.size() - 2)
		var pred: Vector3 = traj[j].lerp(traj[j + 1], k - float(j))
		var e: float = pred.distance_to(b.global_position)
		worst = maxf(worst, e)
		at_end = e
	cleanup()
	return {"worst": worst, "end": at_end}

func test_prediction_matches_the_real_ball_in_long_flights() -> void:
	var cases := [
		["globo largo (1.6 s de vuelo)", Vector3(-15, 0.11, 0), Vector3(14, 8.0, 0), Vector3.ZERO, 1.8],
		["pase largo con bote", Vector3(-15, 0.11, 0), Vector3(16, 4.5, 2.0), Vector3.ZERO, 2.0],
		["tiro tenso a media altura", Vector3(0, 0.11, 0), Vector3(24, 2.2, 1.0), Vector3.ZERO, 0.9],
		["disparo que bota antes del arco", Vector3(8, 0.5, 0), Vector3(15, 1.0, 0.5), Vector3.ZERO, 1.0],
		["tiro con efecto (curva)", Vector3(0, 0.11, 0), Vector3(22, 3.0, -2.0), Vector3(0, 30, 0), 1.0],
		["centro con efecto y bote", Vector3(-10, 0.11, -8), Vector3(10, 7.0, 9.0), Vector3(0, -25, 10), 1.8],
	]
	for c in cases:
		var r: Dictionary = await _case(c[1], c[2], c[3], c[4])
		# Limite: 0.2 m mas 0.15 m por segundo de vuelo (antes de corregir el arrastre en el aire y el bote: 1.4-5.3 m).
		var lim: float = 0.2 + 0.15 * float(c[4])
		note("%s: error maximo %.2f m, al final %.2f m (limite %.2f m)" % [c[0], r["worst"], r["end"], lim])
		check(float(r["worst"]) < lim, "%s: la prediccion sigue a la pelota real (%.2f m)" % [c[0], r["worst"]])

func test_rolling_pass_prediction() -> void:
	var ctx: MatchContext = await make_match(Vector3(-10, 0.11, 0))
	var b: Ball = ctx.ball
	await physics_frames(3)
	var v := Vector3(10, 0, 0)
	b.kick(v, b.rolling_spin(v), null)
	await tree.physics_frame
	var traj: PackedVector3Array = BallPredictor.trajectory(b.global_position, b.linear_velocity, 2.0, 1.0 / 30.0)
	await physics_frames(120)
	var e: float = traj[traj.size() - 1].distance_to(b.global_position)
	note("pase raso 10 m/s, a los 2 s: error %.2f m" % e)
	check(e < 0.3, "pase raso: error %.2f m a los 2 s" % e)
	cleanup()
