extends TestCase
## Penales online contra un bot (sin servidor real: LocalBackend con las mismas reglas que el SQL), con el juego de verdad
## (SetPieceGame): el servidor decide quien patea, recibe la zona oculta del arquero y el cruce de cada tiro, aplica la
## regla de zonas y liquida la partida; el marcador local coincide con el del servidor; el reloj de 20 s dispara el tiro
## de penalizacion (que el servidor cuenta errado).

const DIR := "user://test_online_match"

func _setup_online() -> Node:
	var o: Node = tree.root.get_node("Online")
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/" + f))
	o.use_local(DIR)
	await o.sign_up("online@futbol.com", "golazo123")
	await o.call_state_fn("create_profile", {"p_username": "OnlineCrack", "p_display_name": "Online"})
	return o

func _bot_match(o: Node, fee: int) -> Dictionary:
	await o.call_fn("find_match", {"p_mode": "penales", "p_fee": fee})
	o.local.clock_offset += 10.0
	var r: Dictionary = await o.call_fn("start_bot_match", {"p_mode": "penales"})
	return r["data"]

func _game() -> SetPieceGame:
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var g: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(10)
	return g

func test_online_penalties_against_a_bot() -> void:
	var o: Node = await _setup_online()
	var coins0: int = o.coins()
	OnlineMatch.pending = await _bot_match(o, 50)
	var g: SetPieceGame = await _game()
	check(g.online_match != null and g.online_match.is_bot(), "la partida online arranca con el rival bot del servidor")
	var shots_user: int = 0
	var picks: int = 0
	var n: int = 0
	var shot_sent := false
	var mismatches: int = 0
	while g.phase != SetPieceGame.Phase.OVER and n < 60 * 240:
		if g.phase == SetPieceGame.Phase.AIM and g.user_shooting and not shot_sent:
			shot_sent = true
			shots_user += 1
			g.shoot(Vector3(g.gx, 0.6, 2.6 if shots_user % 2 == 0 else -2.6), 0.75, 0.0)
		elif g.phase == SetPieceGame.Phase.KEEPER_PICK and g._keeper_zone == Vector3.INF:
			picks += 1
			g._keeper_zone = KeeperZones.center(picks % 6, g.gx, g.half_goal, g.goal_h)
		elif g.phase == SetPieceGame.Phase.RESULT:
			shot_sent = false
		await tree.physics_frame
		n += 1
	var sm: Dictionary = o.local._db["match"]
	note("tanda local %d - %d · servidor %d - %d · estado %s · tiros del usuario %d · elecciones de arquero %d" % [
		g.shootout.goals(0), g.shootout.goals(1), int(sm["score_a"]), int(sm["score_b"]), sm["status"], shots_user, picks])
	check(g.phase == SetPieceGame.Phase.OVER, "la tanda online termina")
	check(String(sm["status"]) == "finished", "y el servidor la da por terminada")
	check(g.shootout.goals(0) == int(sm["score_a"]) and g.shootout.goals(1) == int(sm["score_b"]), "el marcador local es el del servidor")
	check(picks >= 3 and shots_user >= 3, "se alternan tirador y arquero")
	var kz_hidden: int = 0
	for t in sm["turns"]:
		if String(t["kind"]) == "shot":
			var pl: Dictionary = t["payload"]
			if pl.get("keeper_zone") != null and int(pl["keeper_zone"]) == int(pl.get("cross_zone", -9)) and String(pl["outcome"]) == "goal":
				mismatches += 1
	check(mismatches == 0, "ningun tiro a la zona elegida por el arquero fue gol (regla de zonas del servidor)")
	await physics_frames(5)
	note("monedas: %d -> %d" % [coins0, o.coins()])
	check(o.coins() != coins0 - 50 or int(sm["winner"]) != 0, "el servidor liquido la partida (premio al ganar)")
	OnlineMatch.pending = {}
	cleanup()

func test_turn_clock_fires_the_penalty_shot() -> void:
	var o: Node = await _setup_online()
	OnlineMatch.pending = await _bot_match(o, 0)
	var g: SetPieceGame = await _game()
	var n: int = 0
	while g.phase != SetPieceGame.Phase.AIM and n < 300:
		await tree.physics_frame
		n += 1
	check(g.user_shooting and g.online_match.clock_on, "el reloj corre en el turno del usuario")
	g.online_match.clock = 0.05
	n = 0
	while g.phase == SetPieceGame.Phase.AIM and n < 120:
		await tree.physics_frame
		n += 1
	check(g.phase != SetPieceGame.Phase.AIM and g.online_match.timed_out, "al vencer el tiempo sale el tiro de penalizacion")
	n = 0
	while (o.local._db["match"]["turns"] as Array).filter(func(t: Dictionary) -> bool: return String(t["kind"]) == "shot").is_empty() and n < 600:
		await tree.physics_frame
		n += 1
	var shot: Dictionary = (o.local._db["match"]["turns"] as Array).filter(func(t: Dictionary) -> bool: return String(t["kind"]) == "shot")[0]
	note("tiro por tiempo: %s" % str(shot["payload"]))
	check(String(shot["payload"]["outcome"]) == "miss", "el servidor lo cuenta errado (no beneficia al jugador)")
	OnlineMatch.pending = {}
	cleanup()
