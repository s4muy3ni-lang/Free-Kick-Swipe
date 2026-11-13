extends TestCase
## Duelo local de dos jugadores (pedido del usuario: «DOS JUGADORES — DUELO LOCAL»): penales y tiros libres alternando
## tirador y arquero; antes de cada tiro ataja el otro en secreto y una cortina tapa su eleccion hasta que patea el
## primero; marcador propio por jugador (goles, recibidos, atajadas, errados, puntos, victorias); en la revancha empieza
## el otro; no suma premios ni logros.

func before_each() -> void:
	if FileAccess.file_exists(LocalDuel.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LocalDuel.SAVE_PATH))

func _game(mode: int) -> SetPieceGame:
	SetPieceGame.next_mode = mode
	SetPieceGame.next_vs = SetPieceGame.Vs.LOCAL
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	return game

func test_the_stats_follow_each_shot() -> void:
	before_each()
	var d := LocalDuel.new()
	d.record_shot(0, "goal")
	d.record_shot(1, "save")
	d.record_shot(0, "save")
	d.record_shot(1, "miss")
	d.record_shot(0, "post")
	var a: Dictionary = d.stats[0]
	var b: Dictionary = d.stats[1]
	check(int(a["goals"]) == 1 and int(b["conceded"]) == 1, "gol de J1: lo recibe J2")
	check(int(b["saves"]) == 1 and int(a["saves"]) == 1, "una atajada de cada uno")
	check(int(b["missed"]) == 1 and int(a["missed"]) == 1, "afuera y palo cuentan como errados")
	check(int(a["points"]) == LocalDuel.POINTS["goal"] + LocalDuel.POINTS["save"] and int(b["points"]) == LocalDuel.POINTS["save"], "puntos: gol y atajada")
	check(d.first_shooter() == 0, "la primera partida empieza J1")
	d.record_match(0)
	check(int(d.wins[0]) == 1 and d.first_shooter() == 1, "gana J1 y en la revancha empieza J2")
	var again := LocalDuel.new()
	check(int(again.wins[0]) == 1 and again.matches == 1, "las victorias quedan guardadas")
	again.reset_totals()

## Juega una partida entera: en cada turno, cortina del arquero, elige un sector, cortina del tirador (el sector no se ve)
## y patea. Devuelve los turnos jugados.
func _play(g: SetPieceGame, hidden: Array) -> Array:
	var turns: Array = []
	var n: int = 0
	while g.phase != SetPieceGame.Phase.OVER and n < 60 * 600:
		if g.local_step == 1 and g.curtain_visible():
			turns.append(0 if g.user_shooting else 1)
			g._on_action(&"local_keeper_ready")
		elif g.local_step == 2 and g.picked_zone < 0:
			g.pick_sector(turns.size() % KeeperZones.COUNT)
		elif g.local_step == 3 and g.curtain_visible():
			# Con la cortina del tirador, el sector elegido no se ve.
			hidden.append(not g._zone_grid.visible and not g._zone_marker.visible)
			g._on_action(&"local_shooter_ready")
		elif g.local_step == 4 and g.phase == SetPieceGame.Phase.AIM:
			g.local_step = 5
			var z: float = [2.5, -2.5, 0.6, -1.5][turns.size() % 4]
			g.shoot(Vector3(g.gx, [0.5, 1.6][turns.size() % 2], z), 0.8, 0.0)
		await tree.physics_frame
		n += 1
	return turns

func test_a_local_penalty_shootout() -> void:
	before_each()
	var g: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
	check(g.vs == SetPieceGame.Vs.LOCAL and g.local != null, "duelo local")
	check(not g.cpu_keeper.ai and not g.user_keeper.ai, "los dos arqueros los maneja un jugador")
	check(g.curtain_visible() and g.local_step == 1, "empieza con la cortina del arquero")
	# Durante la cortina un toque al campo no elige sector.
	g._on_press(Vector2(400, 300), true)
	check(g.picked_zone == -1, "la cortina bloquea la eleccion")
	var hidden: Array = []
	var turns: Array = await _play(g, hidden)
	note("turnos: %s · %d - %d\n%s" % [str(turns), g.shootout.goals(0), g.shootout.goals(1), g.local.summary()])
	check(g.phase == SetPieceGame.Phase.OVER, "la tanda termina")
	var alt: bool = turns.size() >= 6
	for i in range(1, turns.size()):
		if turns[i] == turns[i - 1]:
			alt = false
	check(alt, "se alternan los dos jugadores (%d turnos)" % turns.size())
	check(not hidden.has(false) and hidden.size() == turns.size(), "la cortina del tirador nunca deja ver el sector elegido")
	var a: Dictionary = g.local.stats[0]
	var b: Dictionary = g.local.stats[1]
	check(int(a["goals"]) == g.shootout.goals(0) and int(b["goals"]) == g.shootout.goals(1), "goles del marcador local = tanda")
	check(int(a["conceded"]) == int(b["goals"]) and int(b["conceded"]) == int(a["goals"]), "recibidos = goles del otro")
	check(int(a["shots"]) == g.shootout.kicks(0) and int(b["shots"]) == g.shootout.kicks(1), "tiros de cada uno")
	check(int(a["goals"]) + int(b["saves"]) + int(a["missed"]) == int(a["shots"]), "cada tiro de J1 es gol, atajada o errado")
	check(g.hud.overlay.visible and g.hud.overlay_title.text.contains("GANÓ") or g.hud.overlay_title.text == "EMPATE", "pantalla final: «%s»" % g.hud.overlay_title.text)
	check(g.local.matches == 1, "la partida queda guardada")
	# Revancha: empieza el otro.
	g._on_action(&"rematch")
	await physics_frames(3)
	check(g.shootout.first == 1 and not g.user_shooting, "en la revancha empieza pateando J2")
	check(int(g.local.stats[0]["shots"]) == 0, "marcador de la revancha en cero")
	g.local.reset_totals()
	cleanup()

func test_a_local_free_kick_duel() -> void:
	before_each()
	var g: SetPieceGame = await _game(SetPieceGame.Mode.FREE_KICK)
	check(g.fk_duel() and g.local != null, "tiros libres de a dos")
	var hidden: Array = []
	var turns: Array = await _play(g, hidden)
	note("turnos: %s · %d - %d\n%s" % [str(turns), g.shootout.goals(0), g.shootout.goals(1), g.local.summary()])
	check(g.phase == SetPieceGame.Phase.OVER and turns.size() >= 6, "el duelo termina (%d turnos)" % turns.size())
	check(not hidden.has(false), "el sector elegido no se ve al pasar el telefono")
	check(g.hud.overlay_text.text.contains("Duelo de tiros libres"), "pantalla final del duelo")
	g.local.reset_totals()
	cleanup()
