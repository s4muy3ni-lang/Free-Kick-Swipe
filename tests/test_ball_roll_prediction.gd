extends TestCase
## Prediccion de rodadura (BallPredictor) contra la pelota real (Jolt) en la cancha de futbol 11: pelotas por el piso
## sin giro (deslizan y despues ruedan), con efecto adelante, con efecto atras, ya rodando, y tiros bajos que botan.
## Tolerancia (definida y documentada en docs/AAA_ROADMAP.md): distancia final dentro de max(0,15 m; 3 %), tiempo hasta
## frenarse dentro de 0,12 s y posicion a 1 s dentro de max(0,12 m; 3 %).
## Antes del modelo de deslizamiento: a 10 m/s sin giro la prediccion daba 9,25 m y la pelota real rueda 6,10 m.

const DT := 1.0 / 60.0

var st: Stadium11
var ball: Ball

func _setup() -> void:
	st = Stadium11.new()
	spawn(st)
	st.build(PitchConfig.football11(PitchConfig.GoalStyle.BOX))
	ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	spawn(ball)
	st.set_ball(ball)

## Mide la pelota real: posicion cada paso hasta que se frena (o 9 s).
func _real(p0: Vector3, v: Vector3, w: Vector3) -> PackedVector3Array:
	ball.reset_at(p0)
	await physics_frames(4)
	ball.kick(v, w, null)
	var out := PackedVector3Array()
	out.append(p0)
	for i in 540:
		await tree.physics_frame
		out.append(ball.global_position)
		if i > 20 and ball.linear_velocity.length() < 0.01:
			break
	return out

static func _stop_time(traj: PackedVector3Array) -> float:
	var t: float = 0.0
	for k in range(1, traj.size()):
		if traj[k].distance_to(traj[k - 1]) > 0.0005:
			t = float(k) * DT
	return t

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func test_rolling_prediction_matches_the_real_ball() -> void:
	_setup()
	var r: float = ball.radius
	var p0 := Vector3(-35.0, r, 0.0)
	var worst_d: float = 0.0
	var worst_t: float = 0.0
	# [velocidad, fraccion del giro de rodadura (1 = ya rueda, -1 = efecto atras igual), velocidad vertical]
	var cases := [[3.0, 0.0, 0.0], [6.0, 0.0, 0.0], [10.0, 0.0, 0.0], [16.0, 0.0, 0.0], [6.0, 1.0, 0.0], [12.0, 1.0, 0.0],
		[10.0, 0.5, 0.0], [8.0, -0.5, 0.0], [6.0, -1.0, 0.0], [12.0, 0.0, 1.5], [14.0, 0.6, 3.0], [9.0, 0.0, 3.0]]
	for c in cases:
		var v := Vector3(c[0], c[2], 0.0)
		var w := Vector3(0.0, 0.0, -float(c[0]) / r * float(c[1]))
		var real: PackedVector3Array = await _real(p0, v, w)
		var pred: PackedVector3Array = BallPredictor.trajectory(p0, v, 9.0, DT, w, true)
		var d_real: float = _flat(real[real.size() - 1], p0)
		var d_pred: float = _flat(pred[pred.size() - 1], p0)
		var t_real: float = _stop_time(real)
		var t_pred: float = _stop_time(pred)
		var k1: int = mini(60, real.size() - 1)
		var e1: float = _flat(real[k1], pred[mini(k1, pred.size() - 1)])
		var tol_d: float = maxf(0.15, 0.03 * d_real)
		note("%.0f m/s, giro %.1f, vertical %.1f: real %.2f m en %.2f s, prevista %.2f m en %.2f s; a 1 s difieren %.2f m" % [c[0], c[1], c[2], d_real, t_real, d_pred, t_pred, e1])
		check(absf(d_pred - d_real) <= tol_d, "distancia final dentro de %.2f m (%.2f)" % [tol_d, absf(d_pred - d_real)])
		check(absf(t_pred - t_real) <= 0.12, "tiempo hasta frenarse dentro de 0,12 s (%.2f)" % absf(t_pred - t_real))
		check(e1 <= maxf(0.12, 0.03 * _flat(real[k1], p0)), "posicion a 1 s (%.2f m)" % e1)
		worst_d = maxf(worst_d, absf(d_pred - d_real))
		worst_t = maxf(worst_t, absf(t_pred - t_real))
	note("peor diferencia: %.2f m de distancia, %.2f s de tiempo" % [worst_d, worst_t])
	cleanup()

## Las llamadas viejas (sin el giro real) siguen suponiendo que la pelota por el piso ya rueda (compatibilidad del partido).
func test_old_callers_keep_the_rolling_assumption() -> void:
	var p0 := Vector3(0, 0.1, 0)
	var a: PackedVector3Array = BallPredictor.trajectory(p0, Vector3(6, 0, 0), 4.0, DT)
	var b: PackedVector3Array = BallPredictor.trajectory(p0, Vector3(6, 0, 0), 4.0, DT, Vector3(0, 0, -60.0), true)
	check(a[a.size() - 1].distance_to(b[b.size() - 1]) < 0.05, "sin giro conocido = pelota que ya rueda")
	var c: PackedVector3Array = BallPredictor.trajectory(p0, Vector3(6, 0, 0), 4.0, DT, Vector3.ZERO, true)
	check(c[c.size() - 1].x < a[a.size() - 1].x - 1.0, "con giro conocido cero desliza y llega bastante menos lejos")
