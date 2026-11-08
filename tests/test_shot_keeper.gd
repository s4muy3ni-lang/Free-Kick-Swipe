extends TestCase
## Tiros dirigidos al arco (como PES y FIFA con asistencia) frente a un arquero. El joystick elige el punto dentro del
## arco; la ejecucion y la situacion (distancia, potencia, presion, pierna, atributos) deciden si va dentro, y el
## arquero ataja lo que le llega a su alcance. Tiros fisicos completos: golpe, vuelo con efecto, arquero con sus clips.
## Por escenario: al arco (gol o atajada), goles, atajadas (blocaje, despeje o con el cuerpo), palos y fuera. El efecto
## natural cuenta: el empeine rosca hacia el lado del pie y al palo del que la aleja del arquero le gana mas.

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available() or PackLibrary.keeper() == null:
		skip("faltan assets/animations/pack_clips.res y pack_keeper.res")
		return true
	return false

func _world(keeper_attr: int) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(0.0, 0.11, 0.0))
	var k := Goalkeeper.new()
	spawn(k)
	var attrs := PlayerAttributes.new()
	attrs.reset_to(keeper_attr)
	k.setup(ctx, 1, 90, attrs)
	await physics_frames(6)
	return {"ctx": ctx, "k": k}

## Serie de n tiros desde `ball_pos` con el joystick girado `stick_deg` grados (positivo hacia +Z) respecto a la linea
## al centro del arco. pressure: un rival pegado al tirador.
func _series(w: Dictionary, ball_pos: Vector3, stick_deg: float, charge: float, n: int, attr: int, pressure: bool, seed0: int) -> Dictionary:
	var ctx: MatchContext = w["ctx"]
	var k: Goalkeeper = w["k"]
	var p: Footballer = add_player(ctx, 0, ball_pos - Vector3(0.5, 0.0, 0.0), attr)
	p.set_physics_process(false)
	var d: Footballer = null
	if pressure:
		d = add_player(ctx, 1, ball_pos + Vector3(0.2, 0.0, 0.7), 50)
		d.set_physics_process(false)
	var goals := [0]
	ctx.pitch.goal_scored.connect(func(_g: Goal, _pos: Vector3) -> void: goals[0] += 1)
	var posts := [0]
	ctx.ball.hit_goal_frame.connect(func(_p: Vector3, _s: float) -> void: posts[0] += 1)
	var out := {"n": n, "goal": 0, "save": 0, "post": 0, "miss": 0, "catch": 0, "parry": 0, "block": 0}
	var to_goal: Vector3 = KickModel.flat(Vector3(20.0, 0.0, 0.0) - ball_pos).normalized()
	for i in n:
		p.place_at(ball_pos - to_goal * 0.5, Locomotion.yaw_from_dir(to_goal))
		if d != null:
			d.place_at(ball_pos + Vector3(0.2, 0.0, 0.7), Locomotion.yaw_from_dir(-to_goal))
		ctx.pitch.reset_goal_latches()
		ctx.ball.reset_at(ball_pos)
		k.reset_position()
		await physics_frames(20)
		# Los contadores se toman con la pelota ya recolocada: Ball.reset_at se aplica en el paso fisico siguiente y, con el
		# cerrojo del arco ya reiniciado, la pelota del gol anterior aun en la red contaba un gol fantasma para este tiro.
		var g0: int = goals[0]
		var p0: int = posts[0]
		var c0: int = int(k.stats["catches"])
		var r0: int = int(k.stats["parries"])
		p.ball_handler.rng.seed = seed0 + i
		# El arquero tambien con semilla fija: Goalkeeper.setup() la aleatoriza y la serie cambiaba en cada ejecucion
		# (medido 2026-11-07, 18 m potente: 1-5 goles por serie de 80 con 10 semillas, 35 de 800; con semilla libre a veces
		# salian 0 y la comprobacion «a veces entra» fallaba por azar, no por el juego).
		k.rng.seed = seed0 + 1000 + i
		p.ball_handler.lockout = 0.0
		p.ball_handler.perform_shot(to_goal.rotated(Vector3.UP, deg_to_rad(-stick_deg)), charge, false)
		# Bloqueo con el cuerpo (sin atajada registrada): la pelota llega al arquero y sale rebotada hacia el campo.
		var blocked := false
		var crossed := false
		for fi in 108:
			await tree.physics_frame
			var bp: Vector3 = ctx.ball.global_position
			crossed = crossed or bp.x > 19.9
			if not crossed and KickModel.flat(bp - k.global_position).length() < 0.9 and ctx.ball.linear_velocity.x < -1.0:
				blocked = true
		var caught: int = int(k.stats["catches"]) - c0
		var parried: int = int(k.stats["parries"]) - r0
		if goals[0] > g0:
			out["goal"] += 1
		elif caught + parried > 0 or blocked:
			out["save"] += 1
			out["catch"] += caught
			out["parry"] += parried
			out["block"] += 0 if caught + parried > 0 else 1
		elif posts[0] > p0:
			out["post"] += 1
		else:
			out["miss"] += 1
	cleanup()
	return out

func _line(name: String, r: Dictionary) -> String:
	var on: int = int(r["goal"]) + int(r["save"])
	return "%s: al arco %d/%d, goles %d, atajadas %d (blocajes %d, despejes %d, con el cuerpo %d), palo %d, fuera %d; ataja %d %% de los que van al arco" % [
		name, on, r["n"], r["goal"], r["save"], r["catch"], r["parry"], r["block"], r["post"], r["miss"], int(100.0 * float(r["save"]) / maxf(on, 1.0))]

func test_shots_go_at_goal_and_the_keeper_saves_what_he_reaches() -> void:
	if _skip_if_missing():
		return
	# 80 tiros por caso: con 40 la diferencia entre dos casos parecidos (un par de goles) quedaba dentro del ruido de la
	# serie y la comparacion salia a cara o cruz.
	var n: int = maxi(int(OS.get_environment("SHOTS_N")), 80)
	var cases := [
		["11 m centrado, joystick al palo", Vector3(9.0, 0.11, 0.0), 14.0, 0.6, 60, false],
		["11 m centrado, joystick al arquero", Vector3(9.0, 0.11, 0.0), 0.0, 0.6, 60, false],
		["11 m centrado, joystick de lado (90 grados)", Vector3(9.0, 0.11, 0.0), 90.0, 0.6, 60, false],
		["11 m, rival encima", Vector3(9.0, 0.11, 0.0), 14.0, 0.6, 60, true],
		["18 m, potente", Vector3(2.0, 0.11, 1.0), 6.0, 0.95, 60, false],
		["8 m de angulo cerrado", Vector3(13.0, 0.11, 5.5), -20.0, 0.5, 60, false],
		["11 m, tirador de 85", Vector3(9.0, 0.11, 0.0), 14.0, 0.6, 85, false],
		["11 m centrado, joystick al otro palo", Vector3(9.0, 0.11, 0.0), -14.0, 0.6, 60, false],
		["11 m, al otro palo, tirador de 85", Vector3(9.0, 0.11, 0.0), -14.0, 0.6, 85, false],
	]
	var r: Array = []
	for c in cases:
		var w: Dictionary = await _world(60)
		var res: Dictionary = await _series(w, c[1], float(c[2]), float(c[3]), n, int(c[4]), bool(c[5]), 400)
		note(_line(String(c[0]), res))
		r.append(res)
	var on := func(x: Dictionary) -> float: return float(int(x["goal"]) + int(x["save"])) / float(x["n"])
	var save_rate := func(x: Dictionary) -> float: return float(x["save"]) / maxf(float(int(x["goal"]) + int(x["save"])), 1.0)
	# Medido (40 tiros, arquero de 60, tirador diestro de 60 salvo el de 85; las paradas con el cuerpo cuentan como
	# atajadas): al palo derecho, hacia el que el empeine derecho la cierra sobre el arquero, 72 % al arco y 15 % de goles
	# (ataja 79 %; el de 85, 20 % de goles); al palo izquierdo, del que la aleja, 90 % al arco y 52 % de goles (ataja
	# 41 %); al arquero 95 % al arco y 10 % de goles (ataja 89 %); con rival encima ningun gol; potente de 18 m 22 % de
	# goles por el flotado (ataja 70 %).
	# 2026-10-29, tiro mas fuerte (12-30 m/s con la carga^1.5) y 80 tiros: al palo derecho ataja 80 %, al izquierdo 54 %,
	# al arquero 79 %; con rival encima 4 goles (frente a 12); el de 85 marca 20 al palo derecho (frente a 12).
	# 2026-10-31, sin goles fantasma (contadores tomados con la pelota ya recolocada), contacto continuo de las manos, clips
	# del arquero a velocidad humana (dive_speed_max 1.15) y limite humano de las manos (hand_latency + distancia /
	# hand_speed): al palo derecho ataja 69 %, al izquierdo 76 %, al arquero 84 %; con rival encima 0 goles; el de 85 marca
	# 40 y 44 de 80 (ataja 32-36 %); 18 m potente ataja 96 %.
	check(on.call(r[0]) >= 0.6, "apuntando al palo la mayoria va al arco (%d %%)" % int(on.call(r[0]) * 100.0))
	check(on.call(r[2]) >= 0.6, "con el joystick de lado tambien va al arco (%d %%)" % int(on.call(r[2]) * 100.0))
	check(on.call(r[1]) >= 0.85, "sin lado pedido casi todo va al arco (%d %%)" % int(on.call(r[1]) * 100.0))
	# Al palo hacia el que el empeine la cierra sobre el arquero, colocarla no le gana (la curva la acerca a sus manos);
	# al palo del que la aleja, si.
	check(save_rate.call(r[0]) <= save_rate.call(r[1]) + 0.05 and save_rate.call(r[7]) < save_rate.call(r[1]),
		"colocarla junto a un palo no le facilita la atajada y al palo del que la aleja le gana (ataja %d y %d %% frente a %d %%)" % [int(save_rate.call(r[0]) * 100.0), int(save_rate.call(r[7]) * 100.0), int(save_rate.call(r[1]) * 100.0)])
	# 2026-10-31: el «-15 puntos» al palo del que el empeine la aleja salia de que BallPredictor no tenia efecto Magnus (el
	# arquero preveia mal toda pelota con efecto: errores de 1.4-5 m en vuelo). Con la prediccion fisica y el efecto leido a
	# medida que la pelota se desvia (KeeperTuning.spin_read_time), la curva medida de estos tiros es de 0.05-0.17 m en 11 m:
	# los dos palos quedan dentro del ruido de la serie (69-76 %). Se exige que el palo del que la aleja no sea mas facil
	# que el otro mas alla del ruido (10 puntos con 80 tiros).
	check(save_rate.call(r[7]) <= save_rate.call(r[0]) + 0.10, "al palo del que el empeine la aleja no se ataja mas que al otro (ataja %d %% frente a %d %%)" % [int(save_rate.call(r[7]) * 100.0), int(save_rate.call(r[0]) * 100.0)])
	# Al palo del que la aleja, el de 85 y el de 60 marcan casi la mitad (18 y 21 de 40: ruido de la serie): la curva le
	# gana al arquero a los dos. Al palo dificil se nota el tirador (apunta mas cerca del palo, con menos error).
	check(int(r[6]["goal"]) >= int(r[0]["goal"]), "al palo dificil el buen tirador marca mas (%d frente a %d)" % [r[6]["goal"], r[0]["goal"]])
	check(int(r[3]["goal"]) < int(r[0]["goal"]), "con un rival encima entran menos (%d frente a %d)" % [r[3]["goal"], r[0]["goal"]])
	check(int(r[4]["goal"]) > 0 and save_rate.call(r[4]) >= 0.6, "el potente de lejos a veces entra por el flotado, pero casi siempre se ataja (%d goles, ataja %d %%)" % [r[4]["goal"], int(save_rate.call(r[4]) * 100.0)])
	var goals := 0
	var saves := 0
	for x in r:
		goals += int(x["goal"])
		saves += int(x["save"])
	check(float(saves) / float(goals + saves) >= 0.6, "el arquero ataja la mayoria de lo que va al arco (%d de %d)" % [saves, goals + saves])
	check(goals > 0, "pero hay goles (%d)" % goals)
