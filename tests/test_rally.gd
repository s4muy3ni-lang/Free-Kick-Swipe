extends TestCase
## Modos de peloteo (etapa B): el receptor corre a la caida PREVISTA, elige la parte por la altura real (cabeza, pecho,
## pie), el toque solo sale si la pelota pasa de verdad por esa parte (nada se pega), y los partidos completos contra la
## IA terminan con las reglas de cada modo: «Que no caiga» (pierde el ultimo que la toco; tercer toque = falta) y
## futbol-tenis (red fisica, un pique por campo, afuera, marca de pique que sigue a la fisica).

func _qnc(level: int = 1) -> QueNoCaiga:
	var d: Dictionary = MinigameCatalog.level("que_no_caiga", level)
	d["seed"] = 7
	d["practice"] = true
	Minigame.next_def = d
	var g: QueNoCaiga = (load(QueNoCaiga.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(5)
	return g

func _tenis(level: int = 1) -> FutbolTenis:
	var d: Dictionary = MinigameCatalog.level("futbol_tenis", level)
	d["seed"] = 7
	d["practice"] = true
	Minigame.next_def = d
	var g: FutbolTenis = (load(FutbolTenis.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(5)
	return g

func test_receiver_runs_to_the_predicted_landing_and_part_matches_height() -> void:
	check(RallyPlayer.part_for(1.8, false) == "cabeza", "pelota alta: cabeza")
	check(RallyPlayer.part_for(1.1, false) == "pecho", "a la altura del pecho: pecho")
	check(RallyPlayer.part_for(0.7, false) == "muslo", "media altura: muslo")
	check(RallyPlayer.part_for(0.2, false) == "pie", "baja: pie")
	check(RallyPlayer.part_for(0.8, true) == "volea", "devolucion directa a media altura: volea")
	var g: QueNoCaiga = await _qnc()
	# Saque del usuario lejos del centro del rival: la IA tiene que CORRER a la caida.
	g.set_user_intent(g.home(1) + Vector3(0.0, 0, 2.2), 0.45, 0.8)
	await physics_frames(10)
	var rp: RallyPlayer = g.players[1]
	check(rp.busy(), "la IA espera la pelota")
	var start: Vector3 = rp.actor.global_position
	var kinds: Array = []
	rp.touched.connect(func(k: StringName) -> void: kinds.append(k))
	var n: int = 0
	var far: float = 0.0
	while kinds.is_empty() and n < 300:
		await tree.physics_frame
		n += 1
		far = maxf(far, start.distance_to(rp.actor.global_position))
	note("la IA corrio %.1f m y toco con «%s»" % [far, str(kinds)])
	check(far > 0.8, "corrio hacia la zona de caida")
	check(not kinds.is_empty() and kinds[0] != &"miss", "y la jugo con un contacto real")
	cleanup()

func test_no_touch_if_ball_lands_far() -> void:
	var g: QueNoCaiga = await _qnc()
	# Saque a 4 m del rival con la IA sin tiempo (retardo grande): no llega -> no hay toque magico y la pelota pica.
	g.players[1].react_delay = 2.0
	g.players[1].run_speed = 1.0
	var drops: Array = []
	g.ball.floor_bounce.connect(func(p: Vector3, _s: float) -> void: drops.append(p))
	g.set_user_intent(g.home(1) + Vector3(0, 0, 3.5), 0.5, 0.8)
	var n: int = 0
	while drops.is_empty() and n < 400:
		await tree.physics_frame
		n += 1
	check(not drops.is_empty(), "sin llegar, la pelota pica (nada la toca a distancia)")
	check(g.points[1] == 0 or g.points[0] == 0, "y el punto se resuelve por la regla")
	check(g.points[0] == 0 and g.points[1] == 1, "pierde el que la toco ultimo (el que saco)")
	cleanup()

func test_que_no_caiga_full_match_vs_ai_ends() -> void:
	var g: QueNoCaiga = await _qnc()
	var hits: Array = []
	for s2 in 2:
		g.players[s2].touched.connect(func(k: StringName) -> void:
			if k != &"miss":
				hits.append(k))
	var n: int = 0
	while g.state != Minigame.State.OVER and n < 60 * 240:
		# El usuario juega como la IA: cuando le toca, manda la intencion hacia el rival.
		if g.rally_state == RallyBase.Rally.SERVE and g.serve_side == 0 and n % 30 == 0:
			g.set_user_intent(g.home(1) + Vector3(g.rng.randf_range(-0.5, 0.5), 0, g.rng.randf_range(-0.5, 0.5)), 0.45, 0.8)
		elif g.players[0].busy() and g.user_intent.is_empty():
			g.set_user_intent(g.home(1), 0.42, 0.8)
		await tree.physics_frame
		n += 1
	note("que no caiga: %d - %d en %.0f s simulados, %d toques de peloteo (%s)" % [g.points[0], g.points[1], n / 60.0, hits.size(), str(hits.slice(0, 8))])
	check(g.state == Minigame.State.OVER, "el partido termina")
	check(maxi(g.points[0], g.points[1]) == g.points_to_win, "con el puntaje del nivel")
	check(hits.size() >= 2, "hubo peloteo de verdad (%d toques)" % hits.size())
	cleanup()

func test_tenis_rules_net_out_and_double_bounce() -> void:
	var g: FutbolTenis = await _tenis()
	# La red es fisica: un tiro bajo de frente la golpea y vuelve -> «no cruzo», punto rival.
	g.set_user_intent(Vector3(2.0, 0, 0), 0.42, 0.0)
	var n: int = 0
	while g.rally_state != RallyBase.Rally.POINT and n < 400:
		await tree.physics_frame
		n += 1
	check(g.points[1] == 1 and g.points[0] == 0, "tiro a la red que vuelve: punto rival (%d-%d)" % [g.points[0], g.points[1]])
	cleanup()
	# Afuera: punto para el otro.
	g = await _tenis()
	g.set_user_intent(Vector3(3.0, 0, 8.0), 0.8, 0.6)
	n = 0
	while g.rally_state != RallyBase.Rally.POINT and n < 500:
		await tree.physics_frame
		n += 1
	check(g.points[1] == 1, "afuera: punto rival")
	cleanup()
	# Dos piques en el campo rival sin que la IA llegue: punto del usuario.
	g = await _tenis()
	g.players[1].react_delay = 3.0
	g.players[1].run_speed = 0.5
	g.set_user_intent(Vector3(3.0, 0, 1.0), 0.33, 0.8)
	n = 0
	while g.rally_state != RallyBase.Rally.POINT and n < 600:
		await tree.physics_frame
		n += 1
	check(g.points[0] == 1, "picó allá sin devolución: punto tuyo (%d-%d)" % [g.points[0], g.points[1]])
	cleanup()

func test_tenis_landing_marker_tracks_physics() -> void:
	var g: FutbolTenis = await _tenis()
	# La IA no llega (retardo grande): el primer pique real se compara limpio con la marca prevista.
	g.players[1].react_delay = 3.0
	g.players[1].run_speed = 0.5
	g.set_user_intent(Vector3(g.half * 0.55, 0, 0.6), 0.5, 0.8)
	await physics_frames(8)
	check(g._marker.visible, "la marca de pique aparece mientras la pelota viaja")
	var predicted: Vector3 = g._marker.global_position
	var bounces: Array = []
	g.ball.floor_bounce.connect(func(p: Vector3, _s: float) -> void: bounces.append(p))
	var n: int = 0
	while bounces.is_empty() and n < 400:
		await tree.physics_frame
		n += 1
	var err: float = Vector2(predicted.x - (bounces[0] as Vector3).x, predicted.z - (bounces[0] as Vector3).z).length() if not bounces.is_empty() else INF
	note("pique previsto %s, real %s (error %.2f m)" % [str(predicted), str(bounces.slice(0, 1)), err])
	check(not bounces.is_empty() and err < 0.6, "la marca sigue la prediccion fisica (error %.2f m)" % err)
	cleanup()

func test_tenis_full_match_vs_ai_ends() -> void:
	var g: FutbolTenis = await _tenis()
	var n: int = 0
	while g.state != Minigame.State.OVER and n < 60 * 240:
		if g.rally_state == RallyBase.Rally.SERVE and g.serve_side == 0 and n % 30 == 0:
			g.set_user_intent(Vector3(g.half * 0.6, 0, g.rng.randf_range(-1.2, 1.2)), 0.45, 0.75)
		elif g.players[0].busy() and g.user_intent.is_empty():
			g.set_user_intent(Vector3(g.half * 0.6, 0, g.rng.randf_range(-1.0, 1.0)), 0.45, 0.75)
		await tree.physics_frame
		n += 1
	note("futbol-tenis: %d - %d en %.0f s simulados, %d toques" % [g.points[0], g.points[1], n / 60.0, g.rally_hits])
	check(g.state == Minigame.State.OVER, "el partido termina")
	check(maxi(g.points[0], g.points[1]) == g.points_to_win, "con el puntaje del nivel")
	cleanup()
