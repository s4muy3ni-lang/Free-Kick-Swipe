extends TestCase
## Fisica de la pelota: rebote, rodadura, golpes, postes, paredes y deteccion de gol.

func test_bounce_height_matches_futsal_spec() -> void:
	# Un balon de futsal soltado desde 2 m rebota 50-65 cm (norma FIFA).
	var w: Dictionary = await make_world(Vector3(0, 2.0, 0))
	var ball: Ball = w["ball"]
	var max_after_bounce: float = 0.0
	var bounced: bool = false
	for i in 240:
		await tree.physics_frame
		var y: float = ball.global_position.y - ball.radius
		if not bounced and ball.linear_velocity.y > 0.5:
			bounced = true
		if bounced:
			max_after_bounce = maxf(max_after_bounce, y)
			if ball.linear_velocity.y < -0.1:
				break
	note("altura del primer rebote desde 2 m: %.3f m" % max_after_bounce)
	check(bounced, "la pelota debe rebotar contra el piso")
	check_range(max_after_bounce, 0.45, 0.70, "altura del primer rebote desde 2 m (m)")

func test_rolling_decelerates_and_stops() -> void:
	var w: Dictionary = await make_world(Vector3(-10, 0.1, 0))
	var ball: Ball = w["ball"]
	await physics_frames(30)
	var kick_v := Vector3(6.0, 0.0, 0.0)
	ball.kick(kick_v, ball.rolling_spin(kick_v), null)
	await physics_frames(3)
	var v0: float = ball.ground_speed()
	check_range(v0, 5.5, 6.2, "velocidad tras el golpe")
	await wait_seconds(2.0)
	var v2: float = ball.ground_speed()
	check(v2 < v0 - 1.0, "la pelota debe desacelerar al rodar (v0=%.2f, v2=%.2f)" % [v0, v2])
	# Rodadura proporcional a la velocidad (como First Touch Soccer: ~1/s): de 5.7 m/s queda ~0.5 m/s a los 2 s, y el
	# modelo compartido (Ball.roll_speed) que usan pases, conduccion y prediccion acierta la velocidad real.
	check_range(v2, 0.3, 0.8, "rodadura 0.3 + 1.0 v: velocidad a los 2 s (v2=%.2f)" % v2)
	check(absf(v2 - Ball.roll_speed(v0, 2.0)) < 0.1, "Ball.roll_speed predice la pelota real (%.2f vs %.2f)" % [Ball.roll_speed(v0, 2.0), v2])
	var x2: float = ball.global_position.x
	await wait_seconds(10.0)
	note("v0=%.2f m/s, v(2s)=%.2f m/s, recorrido hasta detenerse: %.1f m" % [v0, v2, ball.global_position.x - (-10.0)])
	check(ball.ground_speed() < 0.15, "debe detenerse por rodadura (v=%.3f)" % ball.ground_speed())
	check(ball.global_position.x > x2 - 0.01, "no retrocede al frenar")

func test_kick_applies_impulse_not_teleport() -> void:
	var w: Dictionary = await make_world(Vector3(0, 0.1, 0))
	var ball: Ball = w["ball"]
	await physics_frames(30)
	var p0: Vector3 = ball.global_position
	ball.kick(Vector3(10, 0, 0), Vector3.ZERO, null)
	await physics_frames(1)
	var moved: float = ball.global_position.distance_to(p0)
	check(moved < 0.25, "un golpe no teletransporta la pelota (se movio %.3f m en 1 paso)" % moved)
	await physics_frames(5)
	# 6 pasos de rodadura (0.3 + 1.0 v) y arrastre despues del golpe de 10 m/s.
	check_range(ball.linear_velocity.x, 7.9, 10.1, "velocidad x despues del golpe")

func test_ball_stays_inside_walls() -> void:
	var w: Dictionary = await make_world(Vector3(0, 0.3, 0))
	var ball: Ball = w["ball"]
	var cfg: PitchConfig = Tuning.pitch
	await physics_frames(20)
	ball.kick(Vector3(0, 6, 28), Vector3.ZERO, null)
	await wait_seconds(5.0)
	var p: Vector3 = ball.global_position
	check(absf(p.z) <= cfg.half_width() + 0.01, "no atraviesa la pared lateral (z=%.2f)" % p.z)
	check(absf(p.x) <= cfg.half_length() + 0.01, "no sale por el fondo (x=%.2f)" % p.x)

func test_goal_detected_once_when_fully_across_line() -> void:
	var w: Dictionary = await make_world(Vector3(15, 0.15, 0))
	var pitch: Pitch = w["pitch"]
	var ball: Ball = w["ball"]
	var goals: Array = []
	pitch.goal_scored.connect(func(g: Goal, _p: Vector3) -> void: goals.append(g.side))
	await physics_frames(30)
	ball.kick(Vector3(18, 0.4, 0.0), Vector3.ZERO, null)
	await wait_seconds(3.0)
	check(goals.size() == 1, "debe haber exactamente 1 gol (hubo %d)" % goals.size())
	if goals.size() == 1:
		check(goals[0] == 1, "el gol debe ser en el arco +X")
	check(ball.global_position.x > Tuning.pitch.half_length(), "la pelota termina dentro de la red")
	check(ball.ground_speed() < 3.0, "la red debe frenar la pelota (v=%.2f)" % ball.ground_speed())

func test_ball_on_the_line_is_not_a_goal() -> void:
	# La pelota se detiene con el centro justo en la linea: aun no cruzo completamente.
	var cfg: PitchConfig = Tuning.pitch
	var w: Dictionary = await make_world(Vector3(cfg.half_length() + 0.04, 0.12, 0.2))
	var pitch: Pitch = w["pitch"]
	var ball: Ball = w["ball"]
	var goals: Array = []
	pitch.goal_scored.connect(func(_g: Goal, _p: Vector3) -> void: goals.append(1))
	ball.freeze = true
	await physics_frames(10)
	check(goals.size() == 0, "con el centro a menos de un radio de la linea no hay gol")

func test_post_deflects_ball_physically() -> void:
	var cfg: PitchConfig = Tuning.pitch
	var w: Dictionary = await make_world(Vector3(cfg.half_length() - 6.0, 0.3, cfg.half_goal() + cfg.post_radius))
	var pitch: Pitch = w["pitch"]
	var ball: Ball = w["ball"]
	var goals: Array = []
	pitch.goal_scored.connect(func(_g: Goal, _p: Vector3) -> void: goals.append(1))
	var hits: Array = []
	ball.hit_goal_frame.connect(func(_p: Vector3, s: float) -> void: hits.append(s))
	await physics_frames(20)
	# Disparo directo al centro del poste.
	ball.kick(Vector3(20, 0.0, 0.0), Vector3.ZERO, null)
	await wait_seconds(1.2)
	check(hits.size() >= 1, "la pelota debe golpear el poste (hits=%d)" % hits.size())
	check(ball.linear_velocity.x < 5.0, "el poste debe devolverla (vx=%.2f)" % ball.linear_velocity.x)
	check(goals.size() == 0, "un disparo al poste no es gol")

func test_crossbar_deflects_ball() -> void:
	var cfg: PitchConfig = Tuning.pitch
	var bar_y: float = cfg.goal_height + cfg.post_radius
	var w: Dictionary = await make_world(Vector3(cfg.half_length() - 6.0, bar_y, 0.0))
	var ball: Ball = w["ball"]
	var hits: Array = []
	ball.hit_goal_frame.connect(func(_p: Vector3, s: float) -> void: hits.append(s))
	# vy compensa la caida por gravedad durante el vuelo (6 m a 22 m/s = 0.27 s).
	var t_flight: float = 6.0 / 22.0
	ball.reset_at(Vector3(cfg.half_length() - 6.0, bar_y, 0.0))
	await physics_frames(2)
	ball.linear_velocity = Vector3.ZERO
	ball.kick(Vector3(22, 0.5 * 9.81 * t_flight + 0.1, 0.0), Vector3.ZERO, null)
	await wait_seconds(1.0)
	check(hits.size() >= 1, "debe golpear el travesano (hits=%d)" % hits.size())
	check(ball.linear_velocity.x < 8.0, "el travesano debe frenar/devolver la pelota (vx=%.2f)" % ball.linear_velocity.x)

func test_state_roundtrip() -> void:
	var w: Dictionary = await make_world(Vector3(3, 1.0, -2))
	var ball: Ball = w["ball"]
	ball.linear_velocity = Vector3(1, 2, 3)
	var s: BallState = ball.capture_state(42)
	var d: Dictionary = s.to_dict()
	var s2: BallState = BallState.from_dict(d)
	check(s2.tick == 42, "tick se conserva")
	check_near(s2.position.x, s.position.x, 0.0001, "posicion x se conserva")
	check_near(s2.linear_velocity.z, s.linear_velocity.z, 0.0001, "velocidad z se conserva")
