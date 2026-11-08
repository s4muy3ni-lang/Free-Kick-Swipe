extends TestCase
## Deteccion de gol con la pelota y el arco reales (Jolt, cancha de futbol 11, arco de caja): solo es gol si la pelota
## CRUZA ENTERA la linea entre los palos y debajo del travesano, habiendo entrado por la boca del arco. Cada caso compara el
## aviso de gol con la verdad geometrica medida paso a paso (centro un radio detras de la linea, dentro del marco).
##  - entera sobre la linea si / a medias (detenida sobre la linea) no;
##  - palo y adentro / palo y afuera; travesano y adentro / travesano y afuera;
##  - desde atras o por encima del arco (por fuera de la red) no;
##  - desviada por el arquero (golpe de frente: vuelve) y el arquero que no llega;
##  - la que entra, pica en la red y vuelve a salir sigue siendo un gol (uno solo).

const GX := 52.5

var st: Stadium11
var ball: Ball
var g: Goal
var goals: int = 0
var frame_hits: int = 0

func _setup() -> void:
	st = Stadium11.new()
	spawn(st)
	st.build(PitchConfig.football11(PitchConfig.GoalStyle.BOX))
	ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	spawn(ball)
	st.set_ball(ball)
	g = st.get_goal(1)
	goals = 0
	frame_hits = 0
	st.goal_scored.connect(func(gg: Goal, _p: Vector3) -> void:
		if gg == g:
			goals += 1)
	ball.hit_goal_frame.connect(func(_p: Vector3, _s: float) -> void: frame_hits += 1)

## Recoloca la pelota (la recolocacion es diferida: se espera a que ocurra) y vacia el estado del arco.
func _place(p: Vector3) -> void:
	ball.reset_at(p)
	await physics_frames(3)
	st.reset_goal_latches()
	await physics_frames(1)
	goals = 0
	frame_hits = 0

## Patea y sigue la pelota `frames` pasos. Devuelve {gol: avisos, dentro: la verdad geometrica, marco: toques al marco,
## max_x: lo mas lejos detras de la linea (local)}.
func _run(v: Vector3, frames: int = 150) -> Dictionary:
	ball.kick(v, Vector3.ZERO, null)
	return await _follow(frames)

func _follow(frames: int) -> Dictionary:
	var r: float = ball.radius
	var hg: float = st.config.half_goal()
	var h: float = st.config.goal_height
	var inside: bool = false
	var through_mouth: bool = false
	var prev: Vector3 = g.to_local(ball.global_position)
	var max_x: float = -INF
	for i in frames:
		await tree.physics_frame
		var lp: Vector3 = g.to_local(ball.global_position)
		if prev.x < 0.0 and lp.x >= 0.0:
			var u: float = -prev.x / maxf(lp.x - prev.x, 1e-5)
			var c: Vector3 = prev.lerp(lp, u)
			through_mouth = absf(c.z) <= hg and c.y <= h
		elif lp.x < -0.3:
			through_mouth = false
		if through_mouth and lp.x >= r and absf(lp.z) <= hg and lp.y <= h - r:
			inside = true
		max_x = maxf(max_x, lp.x)
		prev = lp
	return {"gol": goals, "dentro": inside, "marco": frame_hits, "max_x": max_x}

func _shot_to(from: Vector3, target: Vector3, speed: float) -> Vector3:
	return ShotSolver.solve(from, target, speed, Vector3.ZERO, GX)["velocity"]

func test_the_whole_ball_must_cross_the_line() -> void:
	_setup()
	var from := Vector3(GX - 6.0, ball.radius, 0.4)
	# Velocidad de una pelota rodando para que se frene a medias sobre la linea y entera detras: se busca con la fisica
	# real (biseccion). Nota: BallPredictor sobrestima la rodadura de una pelota pateada sin efecto (no modela el
	# deslizamiento inicial): ver docs/AAA_ROADMAP.md.
	var seen_half: bool = false
	var seen_full: bool = false
	for want in [0.04, 0.4]:
		var lo: float = 1.0
		var hi: float = 12.0
		var best: Dictionary = {}
		var best_rest: float = INF
		for it in 12:
			var mid: float = (lo + hi) * 0.5
			await _place(from)
			var res: Dictionary = await _run(Vector3(mid, 0, 0), 480)
			var rest: float = g.to_local(ball.global_position).x
			check(res["gol"] == (1 if res["dentro"] else 0), "el aviso coincide con la verdad (frena a %.2f m)" % rest)
			if absf(rest - want) < absf(best_rest - want):
				best_rest = rest
				best = res
			if rest < want:
				lo = mid
			else:
				hi = mid
		note("rodando para frenar a %.2f m de la linea: queda a %.2f m (radio %.2f), avisos de gol %d" % [want, best_rest, ball.radius, best["gol"]])
		if best_rest > 0.0 and best_rest < ball.radius - 0.01:
			seen_half = true
			check(best["gol"] == 0, "a medias sobre la linea no es gol")
		elif best_rest > ball.radius + 0.01:
			seen_full = true
			check(best["gol"] == 1, "entera detras de la linea es gol")
	check(seen_half, "se probo una pelota detenida a medias sobre la linea")
	check(seen_full, "se probo una pelota detenida entera detras de la linea")
	cleanup()

func test_post_in_and_post_out() -> void:
	_setup()
	var from := Vector3(GX - 11.0, ball.radius, 0.0)
	var seen_in: bool = false
	var seen_out: bool = false
	for z in [3.58, 3.61, 3.64, 3.71, 3.76, 3.81]:
		await _place(from)
		var res: Dictionary = await _run(_shot_to(from, Vector3(GX, 0.4, z), 24.0))
		note("al palo (z = %.2f): marco %d, gol %d, cruzo entera %s, hasta %.2f m" % [z, res["marco"], res["gol"], str(res["dentro"]), res["max_x"]])
		check(res["gol"] == (1 if res["dentro"] else 0), "z = %.2f: el aviso coincide con la verdad" % z)
		if res["marco"] > 0:
			seen_in = seen_in or res["gol"] == 1
			seen_out = seen_out or res["gol"] == 0
	check(seen_in, "hay un tiro que pega en el palo y entra (gol)")
	check(seen_out, "hay un tiro que pega en el palo y sale (no es gol)")
	cleanup()

func test_crossbar_in_and_out() -> void:
	_setup()
	var from := Vector3(GX - 11.0, ball.radius, 0.0)
	var seen_in: bool = false
	var seen_out: bool = false
	for y in [2.39, 2.40, 2.41, 2.42, 2.48, 2.53]:
		await _place(from)
		var res: Dictionary = await _run(_shot_to(from, Vector3(GX, y, 0.5), 24.0))
		note("al travesano (y = %.2f): marco %d, gol %d, cruzo entera %s, hasta %.2f m" % [y, res["marco"], res["gol"], str(res["dentro"]), res["max_x"]])
		check(res["gol"] == (1 if res["dentro"] else 0), "y = %.2f: el aviso coincide con la verdad" % y)
		if res["marco"] > 0:
			seen_in = seen_in or res["gol"] == 1
			seen_out = seen_out or res["gol"] == 0
	check(seen_in, "hay un tiro que pega en el travesano y pica adentro (gol)")
	check(seen_out, "hay un tiro que pega en el travesano y vuelve (no es gol)")
	cleanup()

func test_from_behind_or_over_the_goal_is_not_a_goal() -> void:
	_setup()
	# Por detras: contra el fondo de la red desde afuera.
	await _place(Vector3(GX + 5.0, 0.6, 0.5))
	var res: Dictionary = await _run(Vector3(-16.0, 1.5, 0.0))
	note("desde atras: gol %d, la pelota llego hasta x local %.2f" % [res["gol"], g.to_local(ball.global_position).x])
	check(res["gol"] == 0, "desde atras del arco (por fuera de la red) no es gol")
	# Por encima: cae sobre el techo de la red.
	await _place(Vector3(GX + 1.0, 5.0, 0.0))
	res = await _follow(150)
	note("cae sobre el techo: gol %d, queda en %s" % [res["gol"], str(g.to_local(ball.global_position).snapped(Vector3.ONE * 0.01))])
	check(res["gol"] == 0, "la que cae sobre el techo de la red no es gol")
	cleanup()

func test_ball_that_goes_in_and_comes_back_out_is_one_goal() -> void:
	_setup()
	await _place(Vector3(GX - 3.0, ball.radius, 0.0))
	var res: Dictionary = await _run(Vector3(9.0, 0.0, 0.0), 70)
	check(res["gol"] == 1 and res["dentro"], "entra: gol")
	# Desde adentro la sacan (como si picara en la red y volviera): sigue siendo un gol y no se cuenta otro.
	ball.kick(Vector3(-14.0, 2.0, 1.0), Vector3.ZERO, null)
	await physics_frames(90)
	note("sale del arco hasta x local %.2f: avisos de gol %d" % [g.to_local(ball.global_position).x, goals])
	check(goals == 1, "un solo gol aunque la pelota vuelva a salir")
	check(not g.is_goal_now(), "fuera del arco ya no esta «dentro»")
	cleanup()

## El arquero quieto en la linea (cuerpo con las esferas de contacto de SpKeeper sobre los huesos): un tiro a su pecho
## rebota hacia la cancha (no es gol); uno al otro palo pasa sin tocarlo (gol).
func test_keeper_deflection_decides_by_physics() -> void:
	_setup()
	var actor := SpActor.new()
	spawn(actor)
	actor.build(SpSettings.CPU_KEEPER_KIT)
	var k := SpKeeper.new()
	spawn(k)
	k.setup(actor, ball, GX, st.config.half_goal(), st.config.goal_height)
	k.reset(Vector3(GX - 0.3, 0.0, 0.0))
	await physics_frames(5)
	var chest: Vector3 = actor.bone_world("mixamorig_Spine2")
	var from := Vector3(GX - 11.0, ball.radius, 0.0)
	await _place(from)
	k.touch_kind = &""
	var res: Dictionary = await _run(_shot_to(from, Vector3(GX, chest.y, chest.z), 22.0), 120)
	var lc: Dictionary = k.last_contact
	note("al pecho (%.2f m): toque «%s» en %s, sale a %s, gol %d" % [chest.y, k.touch_kind, lc.get("part", "-"), str((lc.get("v_out", Vector3.ZERO) as Vector3).snapped(Vector3.ONE * 0.1)), res["gol"]])
	check(k.touch_kind != &"", "el arquero la toca")
	check(res["gol"] == 0 and not res["dentro"], "de frente al cuerpo: no es gol")
	check((lc.get("v_out", Vector3.ZERO) as Vector3).x < 0.0 or k.touch_kind == &"catch", "rebota hacia la cancha (o la atrapa)")
	await _place(from)
	k.reset(Vector3(GX - 0.3, 0.0, 0.0))
	await physics_frames(2)
	res = await _run(_shot_to(from, Vector3(GX, 0.5, 3.2), 24.0), 120)
	note("al palo lejano: toque «%s», gol %d" % [k.touch_kind, res["gol"]])
	check(k.touch_kind == &"" and res["gol"] == 1, "lejos del arquero: no la toca y es gol")
	cleanup()
