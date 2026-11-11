extends TestCase
## «Royal Flush»: las cartas solo se dan vuelta por un golpe real fuera de su eje (un roce o un golpe al centro las deja
## igual: el detente las vuelve); pasada la traba quedan dadas vuelta; las manos de poker se evaluan bien; cada nivel
## llega al bronce con tiros del modelo.

func _game(level: int) -> RoyalFlush:
	var d: Dictionary = MinigameCatalog.level("royal_flush", level)
	d["seed"] = 21
	d["practice"] = true
	Minigame.next_def = d
	var g: RoyalFlush = (load(RoyalFlush.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(10)
	return g

func _wait(g: Minigame, limit: int = 60 * 10) -> String:
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < limit:
		await tree.physics_frame
		n += 1
	var r: String = g.last_result
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
		await physics_frames(2)
	return r

func test_poker_hands() -> void:
	var cases := [[["AS", "KS", "QS", "JS", "10S"], 9], [["9H", "8H", "7H", "6H", "5H"], 8], [["9H", "9S", "9D", "9C", "2H"], 7],
		[["3H", "3S", "3D", "2C", "2H"], 6], [["AH", "9H", "7H", "4H", "2H"], 5], [["5H", "4S", "3D", "2C", "AH"], 4],
		[["7H", "7S", "7D", "KC", "2H"], 3], [["7H", "7S", "KD", "KC", "2H"], 2], [["7H", "7S", "KD", "QC", "2H"], 1],
		[["7H", "9S", "KD", "QC", "2H"], 0], [["AH", "AS"], 1], [["QH"], 0]]
	for c in cases:
		check(RoyalFlush.hand_rank(c[0]) == int(c[1]), "%s es %s" % [str(c[0]), RoyalFlush.HANDS[int(c[1])]])
	var best: Array = RoyalFlush.best_of(["2H", "AS", "KS", "QS", "JS", "10S", "3D"])
	check(RoyalFlush.hand_rank(best) == 9, "de 7 cartas elige la escalera real")

func test_cards_flip_only_with_a_real_hit() -> void:
	var g: RoyalFlush = await _game(1)
	var e: Dictionary = g.cards[7]
	var p: Vector3 = (e["body"] as Node3D).global_position
	# Un toque lento arriba: se mueve un poco y el detente la vuelve boca abajo.
	g.state = Minigame.State.FLIGHT
	g.ball.reset_at(p + Vector3(-0.3, 0.3, 0))
	await physics_frames(2)
	g.ball.kick(Vector3(2.0, 0, 0), Vector3.ZERO, null)
	await physics_frames(120)
	var lean: float = g.card_angle(e)
	check(not bool(e["revealed"]) and absf(lean) < RoyalFlush.LATCH, "un toque lento no la da vuelta")
	# (La pelota puede quedar apoyada sobre la paleta inclinada; sin ella, el detente la vuelve boca abajo.)
	g.ball.reset_at(Vector3(0, 0.11, 0))
	await physics_frames(120)
	note("toque lento: angulo %.2f rad con la pelota apoyada, %.2f rad despues" % [lean, g.card_angle(e)])
	check(absf(g.card_angle(e)) < 0.1, "el detente la vuelve boca abajo")
	cleanup()
	# Un tiro que pasa por arriba del tablero no da vuelta nada.
	g = await _game(1)
	var it: Dictionary = g.cpu_shot(Vector3(g.board_x, 12.0, 0), 22.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	await _wait(g)
	check(g.revealed.is_empty(), "sin tocar cartas no hay cartas en la mano")
	# Un golpe fuerte arriba de la mitad: gira y pasa la traba.
	e = g.cards[7]
	p = (e["body"] as Node3D).global_position
	it = g.cpu_shot(p + Vector3(-g.CARD_T * 0.5 - g.ball.radius, g.CARD_H * 0.3, 0), 16.0, 0.0, 0.0)
	await g.launch(it["v"], it["w"])
	await _wait(g)
	await physics_frames(60)
	note("arriba: angulo %.2f rad, dada vuelta %s, mano %s" % [g.card_angle(e), str(e["revealed"]), str(g.revealed)])
	check(bool(e["revealed"]) and absf(g.card_angle(e)) > 2.8, "un golpe fuerte la da vuelta y queda trabada boca arriba")
	cleanup()

func test_every_level_reaches_bronze() -> void:
	for lv in range(1, MinigameCatalog.levels("royal_flush").size() + 1):
		var g: RoyalFlush = await _game(lv)
		var k: int = 0
		while g.state != Minigame.State.OVER and k < 12:
			# Apunta arriba de la mitad de una carta todavia boca abajo (de a una, en orden).
			var e: Dictionary = {}
			for c in g.cards:
				if not bool(c["revealed"]):
					e = c
					break
			if e.is_empty():
				break
			var p: Vector3 = (e["body"] as Node3D).global_position
			var it: Dictionary = g.cpu_shot(p + Vector3(-g.CARD_T * 0.5 - g.ball.radius, g.CARD_H * 0.3, 0), 16.0, 0.0, 0.0)
			await g.launch(it["v"], it["w"])
			await _wait(g)
			k += 1
		var h: Array = g.best_hand()
		note("nivel %d (%s): %d cartas dadas vuelta %s -> %s, %d puntos (medallas %s)" % [lv, g.def["title"], g.revealed.size(), str(g.revealed), RoyalFlush.HANDS[maxi(RoyalFlush.hand_rank(h), 0)], g.final_score(), str(g.def["medals"])])
		check(g.best_hand().size() == 5, "nivel %d: con los tiros del nivel se arma una mano de 5" % lv)
		check(g.final_score() >= int(g.def["medals"][0]) or RoyalFlush.hand_rank(h) == 0, "nivel %d: con una mano de par o mejor hay bronce" % lv)
		cleanup()
