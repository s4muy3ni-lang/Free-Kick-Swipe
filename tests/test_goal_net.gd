extends TestCase
## Red de tela del arco (GoalNet): la pelota que entra la abomba, la tela la frena y casi no la devuelve; la red vuelve
## al reposo con ondas; por fuera (red lateral, techo) la hunde y no la deja entrar.

## Tira la pelota desde `from` con velocidad `v` y sigue el vuelo: velocidad maxima de vuelta, punto mas profundo detras
## de la linea, abombado maximo de la red y si hubo gol.
func _shot(from: Vector3, v: Vector3, seconds: float = 3.0, out_of_bounds: bool = false) -> Dictionary:
	var mode: PitchConfig.BoundaryMode = Tuning.pitch.boundary_mode
	if out_of_bounds:
		# Con bandas (el partido): las paredes se retiran y la red lateral y el techo quedan al alcance por fuera.
		Tuning.pitch.boundary_mode = PitchConfig.BoundaryMode.OUT_OF_BOUNDS
	var w: Dictionary = await make_world(from)
	Tuning.pitch.boundary_mode = mode
	var pitch: Pitch = w["pitch"]
	var ball: Ball = w["ball"]
	var goal: Goal = pitch.goals[1]
	var goals := [0]
	pitch.goal_scored.connect(func(_g: Goal, _p: Vector3) -> void: goals[0] += 1)
	await physics_frames(10)
	ball.kick(v, Vector3.ZERO, null)
	var out := {"max_x": -INF, "return_speed": 0.0, "peak": 0.0, "goal": 0, "end_speed": 0.0, "end": Vector3.ZERO, "rest": false, "ms": 0.0}
	var hit := false
	var max_us: int = 0
	for i in int(seconds * 60.0):
		var t0: int = Time.get_ticks_usec()
		await tree.physics_frame
		max_us = maxi(max_us, Time.get_ticks_usec() - t0)
		var p: Vector3 = ball.global_position
		out["max_x"] = maxf(float(out["max_x"]), p.x)
		out["peak"] = maxf(float(out["peak"]), goal.net.bulge)
		if goal.net.active:
			hit = true
		if hit:
			out["return_speed"] = maxf(float(out["return_speed"]), -ball.linear_velocity.x)
	out["goal"] = goals[0]
	out["end_speed"] = ball.linear_velocity.length()
	out["end"] = ball.global_position
	await wait_seconds(3.0)
	out["rest"] = not goal.net.active or ball.linear_velocity.length() < 0.05
	cleanup()
	return out

func test_a_shot_bulges_the_net_and_the_net_stops_it() -> void:
	var gl: float = Tuning.pitch.half_length()
	var depth: float = Tuning.pitch.goal_depth
	for c in [["raso a 15 m/s", Vector3(gl - 5.0, 0.11, 0.0), Vector3(15.0, 0.0, 0.0)],
			["a media altura a 25 m/s", Vector3(gl - 6.0, 0.6, 0.4), Vector3(25.0, 2.0, 0.0)],
			["potente al angulo a 30 m/s", Vector3(gl - 8.0, 0.8, 0.0), Vector3(30.0, 2.6, 2.2)]]:
		var r: Dictionary = await _shot(c[1], c[2])
		var v_in: float = (c[2] as Vector3).length()
		note("%s: gol %d, llega hasta %.2f m detras de la linea (fondo a %.2f), red abombada %.2f m, vuelve a %.1f m/s (%d %%), al final %.2f m/s en %s" % [
			c[0], r["goal"], float(r["max_x"]) - gl, depth, r["peak"], r["return_speed"], int(100.0 * float(r["return_speed"]) / v_in), r["end_speed"], str((r["end"] as Vector3).snapped(Vector3.ONE * 0.01))])
		check(int(r["goal"]) == 1, "%s: gol (uno solo)" % c[0])
		check(float(r["peak"]) > 0.1, "%s: la red se abomba (%.2f m)" % [c[0], r["peak"]])
		check(float(r["max_x"]) - gl < depth + Tuning.ball.net_max_bulge + 0.15, "%s: la tela la para (no la atraviesa)" % c[0])
		check(float(r["return_speed"]) < 0.2 * v_in, "%s: la red casi no la devuelve (%.1f m/s)" % [c[0], r["return_speed"]])
		check((r["end"] as Vector3).x > gl, "%s: la pelota queda dentro del arco" % c[0])
		check(bool(r["rest"]), "%s: la red vuelve al reposo" % c[0])

func test_side_netting_from_outside_keeps_the_ball_out() -> void:
	var gl: float = Tuning.pitch.half_length()
	var hw: float = Tuning.pitch.half_goal()
	# Tiro cruzado que se va fuera y pega en la red lateral por fuera.
	var r: Dictionary = await _shot(Vector3(gl - 1.6, 0.5, hw + 0.9), Vector3(12.0, 1.0, -4.5), 3.0, true)
	note("red lateral por fuera: gol %d, red abombada %.2f m, final en %s" % [r["goal"], r["peak"], str((r["end"] as Vector3).snapped(Vector3.ONE * 0.01))])
	check(int(r["goal"]) == 0, "no es gol")
	check(float(r["peak"]) > 0.03, "la red lateral se hunde (%.2f m)" % r["peak"])
	check(absf((r["end"] as Vector3).z) > hw - 0.05 or (r["end"] as Vector3).x < gl, "la pelota queda fuera del arco")

func test_a_ball_falling_on_the_roof_stays_out() -> void:
	var gl: float = Tuning.pitch.half_length()
	# Pelota que cae sobre el techo de la red (una vaselina pasada): el techo cede y la sostiene, no es gol.
	var r: Dictionary = await _shot(Vector3(gl + 0.5, 3.5, 0.3), Vector3(0.0, -3.0, 0.0), 3.0, true)
	note("pelota sobre el techo: gol %d, red abombada %.2f m, final en %s" % [r["goal"], r["peak"], str((r["end"] as Vector3).snapped(Vector3.ONE * 0.01))])
	check(int(r["goal"]) == 0, "no es gol")
	check(float(r["peak"]) > 0.05, "el techo cede (%.2f m)" % r["peak"])
	check((r["end"] as Vector3).y > Tuning.pitch.goal_height - 0.3, "y la sostiene encima (y %.2f)" % (r["end"] as Vector3).y)
