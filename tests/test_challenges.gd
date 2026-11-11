extends TestCase
## Academia de tiros y Arena de desafios: catalogo valido, puntuacion que premia la habilidad, progreso y desbloqueos,
## blancos detectados con la pelota real y un ejercicio jugado de punta a punta con el juego de siempre.

const TMP_PROGRESS := "user://progress_test.cfg"

func test_catalog_is_valid() -> void:
	var ids := {}
	var bad: int = 0
	for d in ChallengeCatalog.academia() + ChallengeCatalog.arena():
		check(not ids.has(d["id"]), "id unico %s" % d["id"])
		ids[d["id"]] = true
		var pr: PackedStringArray = ChallengeCatalog.problems(d)
		if not pr.is_empty():
			bad += 1
			note("%s: %s" % [d["id"], ", ".join(pr)])
		if String(d["group"]) == "arena":
			for dif in 5:
				var dd: Dictionary = ChallengeCatalog.at_difficulty(d, dif)
				var pr2: PackedStringArray = ChallengeCatalog.problems(dd)
				if not pr2.is_empty():
					bad += 1
					note("%s en dificultad %d: %s" % [d["id"], dif, ", ".join(pr2)])
	note("academia: %d ejercicios en %d niveles; arena: %d desafios en %s" % [ChallengeCatalog.academia().size(), ChallengeCatalog.levels().size(),
		ChallengeCatalog.arena().size(), str(ChallengeCatalog.categories())])
	check(bad == 0, "todas las definiciones son validas (%d con problemas)" % bad)
	check(ChallengeCatalog.levels() == [1, 2, 3, 4, 5, 6, 7, 8], "la academia tiene los 8 niveles")
	for c in ["Precisión", "Objetos", "Distancia", "Especiales"]:
		check(ChallengeCatalog.categories().has(c), "la arena tiene %s" % c)
	# Dificultad progresiva: blancos mas chicos y arquero en las dificultades altas.
	var w: Dictionary = ChallengeCatalog.by_id("r_pre_5")
	var easy: Dictionary = ChallengeCatalog.at_difficulty(w, 0)
	var hard: Dictionary = ChallengeCatalog.at_difficulty(w, 4)
	check(float(hard["targets"][0]["w"]) < float(easy["targets"][0]["w"]), "en Extremo el blanco es mas chico")
	check(int(hard["keeper"]) >= 0 and int(easy["keeper"]) < 0, "en Extremo hay arquero; en Facil no")

func test_score_rewards_skill_not_luck() -> void:
	check(ChallengeScore.attempt_points(0, 1.0, 30.0, 30.0, 0.0, 5, true, 4) == 0, "un fallo no suma nada")
	var center: int = ChallengeScore.attempt_points(1, 1.0, 18.0, 20.0, 0.0, 1, false, 0)
	var edge: int = ChallengeScore.attempt_points(1, 0.1, 18.0, 20.0, 0.0, 1, false, 0)
	check(center > edge, "mas cerca del centro del blanco = mas puntos (%d > %d)" % [center, edge])
	var far: int = ChallengeScore.attempt_points(1, 0.5, 30.0, 20.0, 0.0, 1, false, 0)
	var near: int = ChallengeScore.attempt_points(1, 0.5, 16.0, 20.0, 0.0, 1, false, 0)
	check(far > near, "desde mas lejos = mas puntos")
	var streak3: int = ChallengeScore.attempt_points(1, 0.5, 18.0, 20.0, 0.0, 3, false, 0)
	var streak1: int = ChallengeScore.attempt_points(1, 0.5, 18.0, 20.0, 0.0, 1, false, 0)
	check(streak3 > streak1, "la racha suma (consistencia)")
	var fast: int = ChallengeScore.attempt_points(1, 0.5, 18.0, 30.0, 24.0, 1, false, 0)
	var just: int = ChallengeScore.attempt_points(1, 0.5, 18.0, 24.0, 24.0, 1, false, 0)
	check(fast > just, "si el desafio pide potencia, mas potencia suma")
	check(ChallengeScore.attempt_points(1, 0.5, 18.0, 20.0, 0.0, 1, false, 4) == int(round(streak1 * 2.0)), "Extremo vale el doble")
	check(ChallengeScore.spare_bonus(2, 0) == 80 and ChallengeScore.spare_bonus(0, 0) == 0, "intentos de sobra suman")
	var med: Array = [300, 450, 650]
	check(ChallengeScore.medal_for(299, med) == 0 and ChallengeScore.medal_for(300, med) == 1 and ChallengeScore.medal_for(700, med) == 3, "medallas por umbral")
	check(ChallengeScore.medal_for(650, med, 4) < 3, "en Extremo los umbrales escalan con el multiplicador")

func test_progress_unlocks_and_records() -> void:
	PlayerProgress.use_path(TMP_PROGRESS)
	var l2: Dictionary = ChallengeCatalog.level_defs(2)[0]
	check(PlayerProgress.is_unlocked(ChallengeCatalog.level_defs(1)[0]), "el nivel 1 esta abierto")
	check(not PlayerProgress.is_unlocked(l2), "el nivel 2 empieza cerrado")
	var l1: Array = ChallengeCatalog.level_defs(1)
	var need: int = int(ceil(l1.size() / 2.0))
	for i in need:
		var r: Dictionary = PlayerProgress.record(l1[i], 400, 1)
		check(int(r["xp_gained"]) > 0, "un bronce da experiencia")
	check(PlayerProgress.is_unlocked(l2), "con bronce en %d de %d ejercicios del nivel 1 se abre el nivel 2" % [need, l1.size()])
	var again: Dictionary = PlayerProgress.record(l1[0], 300, 1)
	check(not bool(again["new_best"]) and int(again["xp_gained"]) == 0, "repetir sin mejorar no da experiencia (no obliga a repetir)")
	var better: Dictionary = PlayerProgress.record(l1[0], 700, 3)
	check(bool(better["new_best"]) and PlayerProgress.best(String(l1[0]["id"])) == 700, "un record nuevo se guarda")
	var a: Dictionary = ChallengeCatalog.arena()[0]
	check(PlayerProgress.difficulty_unlocked(a, 0) and not PlayerProgress.difficulty_unlocked(a, 1), "arena: Facil abierto, Normal cerrado")
	PlayerProgress.record(a, 300, 1, 0)
	check(PlayerProgress.difficulty_unlocked(a, 1), "arena: bronce en Facil abre Normal")
	PlayerProgress.load_progress(true)
	check(PlayerProgress.best(String(l1[0]["id"])) == 700, "el progreso se guarda en disco")
	check(PlayerProgress.level_for(0) == 1 and PlayerProgress.level_for(150) == 2 and PlayerProgress.level_for(449) == 2, "niveles de jugador")
	PlayerProgress.use_path(PlayerProgress.PATH)

func test_targets_detect_with_the_real_ball() -> void:
	var st := Stadium11.new()
	spawn(st)
	st.build(PitchConfig.football11(PitchConfig.GoalStyle.BOX))
	var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	spawn(ball)
	st.set_ball(ball)
	var gx: float = st.half_length()
	var d := {"id": "t", "rule": "targets", "targets": [{"type": "zone", "y": 1.0, "z": 1.5, "w": 1.4, "h": 1.2},
		{"type": "hoop", "at": [9.0, 1.2, -1.0], "r": 0.7}, {"type": "post_left"}, {"type": "crossbar"}],
		"objects": [{"type": "cones", "at": [6.0, 0.0], "n": 4, "spacing": 0.5}], "obstacles": []}
	var tg := ChallengeTargets.new()
	spawn(tg)
	tg.build(d, ball, gx, st.config.half_goal(), st.config.goal_height)
	await physics_frames(10)
	var from := Vector3(gx - 18.0, ball.radius, 0.0)
	# [blanco, punto al que se tira, indice esperado]
	for c in [[Vector3(gx, 1.0, 1.5), 0, "recuadro"], [Vector3(gx, 1.0, 1.5) + Vector3(0, 0, 1.2), -1, "al lado del recuadro"]]:
		tg.begin_attempt()
		ball.reset_at(from)
		await physics_frames(3)
		ball.kick(ShotSolver.solve(from, c[0], 22.0, Vector3.ZERO, gx)["velocity"], Vector3.ZERO, null)
		await physics_frames(80)
		var h: Dictionary = tg.attempt_hits()
		note("%s: aciertos %s" % [c[2], str(h)])
		if int(c[1]) >= 0:
			check(h.has(c[1]) and float(h[c[1]]) > 0.5, "%s: acierto cerca del centro" % c[2])
		else:
			check(not h.has(0), "%s: no cuenta" % c[2])
	# Aro: el recorrido tiene que pasar por adentro.
	tg.begin_attempt()
	ball.reset_at(from)
	await physics_frames(3)
	var hoop_pt := Vector3(gx - 9.0, 1.2, -1.0)
	var v: Vector3 = ShotSolver.solve(from, Vector3(gx, 1.2 + (hoop_pt.y - 1.2), -1.0 * 18.0 / 9.0), 22.0, Vector3.ZERO, gx)["velocity"]
	ball.kick((hoop_pt - from).normalized() * 22.0 + Vector3.UP * 1.6, Vector3.ZERO, null)
	await physics_frames(60)
	note("aro: aciertos %s" % str(tg.attempt_hits()))
	check(tg.attempt_hits().has(1), "pasa por el aro")
	# Palo izquierdo y travesaño (señal del marco de Ball).
	for c2 in [[Vector3(gx, 0.5, -3.71), 2, "palo izquierdo"], [Vector3(gx, 2.48, 0.5), 3, "travesaño"]]:
		tg.begin_attempt()
		ball.reset_at(Vector3(gx - 11.0, ball.radius, 0.0))
		await physics_frames(3)
		ball.kick(ShotSolver.solve(Vector3(gx - 11.0, ball.radius, 0.0), c2[0], 24.0, Vector3.ZERO, gx)["velocity"], Vector3.ZERO, null)
		await physics_frames(60)
		note("%s: aciertos %s" % [c2[2], str(tg.attempt_hits())])
		check(tg.attempt_hits().has(c2[1]), "%s: cuenta el golpe al marco" % c2[2])
	# Conos: la pelota rodando los voltea (la pelota nunca se mueve sola: solo el golpe).
	ball.reset_at(Vector3(gx - 14.0, ball.radius, 0.0))
	await physics_frames(3)
	ball.kick(Vector3(14.0, 0.0, 0.0), ball.rolling_spin(Vector3(14.0, 0.0, 0.0)), null)
	await physics_frames(120)
	note("conos voltados: %d de 4" % tg.knocked_count())
	check(tg.knocked_count() >= 1, "la pelota voltea conos")
	cleanup()

func test_an_exercise_plays_end_to_end() -> void:
	PlayerProgress.use_path(TMP_PROGRESS)
	var d: Dictionary = ChallengeCatalog.by_id("a1_1")
	for practice in [false, true]:
		SetPieceGame.next_mode = SetPieceGame.Mode.CHALLENGE
		SetPieceGame.next_challenge = d
		SetPieceGame.next_practice = practice
		var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
		game.fast = true
		spawn(game)
		await physics_frames(10)
		check(game.mode == SetPieceGame.Mode.CHALLENGE and game.phase == SetPieceGame.Phase.AIM, "empieza apuntando")
		check(not game.cpu_keeper.actor.visible, "sin arquero en este ejercicio")
		var n: int = 0
		while game.phase != SetPieceGame.Phase.OVER and n < 4000:
			if game.phase == SetPieceGame.Phase.AIM:
				game.shoot(Vector3(game.gx, 1.0, 0.3), 0.6, 0.0)
			await tree.physics_frame
			n += 1
		var r: Dictionary = game.runner.last_result
		note("practica %s: %s" % [str(practice), str(r)])
		check(game.phase == SetPieceGame.Phase.OVER, "termina")
		check(int(r.get("progress", 0)) >= 3 and int(r.get("medal", 0)) >= 1, "tres aciertos al recuadro grande: completa con medalla")
		check(int(r.get("attempts_used", 9)) <= 5, "no usa mas intentos de los que hay")
		if practice:
			check(int(r.get("xp_gained", -1)) == 0, "la practica libre no da experiencia ni registra")
		else:
			check(PlayerProgress.best("a1_1") == int(r["score"]), "el resultado queda registrado")
		cleanup()
	PlayerProgress.use_path(PlayerProgress.PATH)
	SetPieceGame.next_challenge = {}
	SetPieceGame.next_practice = false

## Las tres secciones: ACADEMIA (practica + ejercicios, lo bloqueado deshabilitado, la practica libre abre todo), DESAFIOS
## (progresion, sin minijuegos) y MINIJUEGOS ARCADE (categorias; DESAFIOS DE ARCO contiene cada desafio de la antigua
## Arena exactamente una vez). Sin pestañas para saltar entre secciones.
func test_the_selection_screen_lists_everything() -> void:
	PlayerProgress.use_path(TMP_PROGRESS)
	ChallengeMenu.practice = false
	ChallengeMenu.section = "academia"
	ChallengeMenu.arcade_category = ""
	ChallengeMenu.arcade_item = ""
	var m: ChallengeMenu = (load(ChallengeMenu.SCENE) as PackedScene).instantiate()
	spawn(m)
	await physics_frames(2)
	var cards: Array = m.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.contains("\n"))
	var locked: int = cards.filter(func(b: Button) -> bool: return b.disabled).size()
	note("academia: %d tarjetas, %d bloqueadas" % [cards.size(), locked])
	check(cards.size() == ChallengeCatalog.academia().size() + 2, "una tarjeta por ejercicio + penales y tiro libre")
	check(str(cards.map(func(b: Button) -> String: return b.text)).contains("Penales"), "la practica de penales esta en Academia")
	check(locked == ChallengeCatalog.academia().size() - ChallengeCatalog.level_defs(1).size(), "solo el nivel 1 abierto al empezar")
	var texts: String = str(m.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text))
	check(not texts.contains("ARCADE") and not texts.contains("LOGROS"), "sin pestañas hacia las otras secciones")
	ChallengeMenu.practice = true
	m._refresh()
	await physics_frames(2)
	cards = m.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.contains("\n") and not b.is_queued_for_deletion())
	check(cards.filter(func(b: Button) -> bool: return b.disabled).is_empty(), "en practica libre todo esta abierto")
	ChallengeMenu.practice = false
	# Arena -> DESAFIOS DE ARCO: cada desafio una sola vez.
	var seen := {}
	for c in MinigameCatalog.categories():
		for it in c["items"]:
			if String(it["type"]) == "arena":
				for aid in it["ids"]:
					seen[aid] = int(seen.get(aid, 0)) + 1
	var dup: Array = seen.keys().filter(func(k: String) -> bool: return int(seen[k]) > 1)
	check(seen.size() == ChallengeCatalog.arena().size() and dup.is_empty(), "los %d desafios de arco estan una vez (%d, repetidos %s)" % [ChallengeCatalog.arena().size(), seen.size(), str(dup)])
	# Navegacion de arcade: categoria -> modalidad -> nivel -> dificultad (4) y «Volver» sube de a un nivel.
	ChallengeMenu.section = "arcade"
	m._refresh()
	await physics_frames(2)
	cards = m.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.contains("\n") and not b.is_queued_for_deletion())
	check(cards.size() == MinigameCatalog.categories().size(), "arcade muestra solo las categorias (%d)" % cards.size())
	ChallengeMenu.arcade_category = "arco"
	ChallengeMenu.arcade_item = "arco_postes"
	m._refresh()
	await physics_frames(2)
	cards = m.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.contains("\n") and not b.is_queued_for_deletion())
	check(cards.size() == 3, "la modalidad Postecitos tiene sus 3 niveles")
	cards[0].pressed.emit()
	await physics_frames(2)
	cards = m.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.contains("\n") and not b.is_queued_for_deletion())
	check(cards.size() == 4, "cuatro dificultades")
	m._back()
	m._back()
	m._back()
	await physics_frames(2)
	check(ChallengeMenu.arcade_category == "" and ChallengeMenu.arcade_item == "", "«Volver» sube de a un nivel hasta las categorias")
	ChallengeMenu.section = "academia"
	cleanup()
	PlayerProgress.use_path(PlayerProgress.PATH)
