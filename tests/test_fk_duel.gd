extends TestCase
## Tiros libres por turnos contra la CPU (pedido del usuario: «se alternarán tiro y atajada… la IA no sabrá previamente la
## elección del jugador»): se alternan tirador y arquero, los dos patean desde el mismo punto en cada ronda, la barrera es
## del equipo que ataja, el usuario elige uno de los 9 sectores cuando patea la CPU y la CPU elige su tiro sin saberlo.
## La practica libre de siempre (sin turnos) sigue igual.

func _game(vs: int) -> SetPieceGame:
	SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK
	SetPieceGame.next_vs = vs
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	return game

func _jersey(a: SpActor) -> Color:
	var mi: MeshInstance3D = a.model.find_children("*", "MeshInstance3D", true, false)[0]
	return (mi.material_override as ShaderMaterial).get_shader_parameter("jersey_color")

func test_the_duel_alternates_shooter_and_keeper_from_the_same_spots() -> void:
	var g: SetPieceGame = await _game(SetPieceGame.Vs.CPU)
	check(g.fk_duel() and g.duel_like(), "tiro libre por turnos")
	check(g.phase == SetPieceGame.Phase.AIM and g.user_shooting, "empieza pateando el usuario")
	var turns: Array = []
	var spots := {}
	var wall_ok: int = 0
	var keeper_ok: int = 0
	var n: int = 0
	var started: bool = false
	while g.phase != SetPieceGame.Phase.OVER and n < 60 * 400:
		if not started and g.phase in [SetPieceGame.Phase.AIM, SetPieceGame.Phase.KEEPER_PICK]:
			started = true
			var team: int = 0 if g.user_shooting else 1
			var round_i: int = g.shootout.kicks(team)
			turns.append(team)
			spots["%d:%d" % [team, round_i]] = g.ball_spot
			# Camisetas: la barrera es del equipo que ataja.
			var want: Color = (SpSettings.CPU_KIT if g.user_shooting else SpSettings.USER_KIT)["jersey"]
			if g.wall.players.size() > 0 and _jersey(g.wall.players[0]).is_equal_approx(want):
				wall_ok += 1
			# Arqueros: ataja el del equipo que no patea (el otro no esta en la cancha).
			if g.user_shooting == (g.cpu_keeper.actor.visible and not g.user_keeper.actor.visible):
				keeper_ok += 1
			if g.user_shooting:
				g.shoot(Vector3(g.gx, 1.4, 2.4 if turns.size() % 4 == 1 else -2.4), 0.75, 0.0)
			else:
				g.pick_sector(turns.size() % KeeperZones.COUNT)
		elif g.phase == SetPieceGame.Phase.RESULT:
			started = false
		await tree.physics_frame
		n += 1
	note("turnos: %s · goles %d - %d" % [str(turns), g.shootout.goals(0), g.shootout.goals(1)])
	check(g.phase == SetPieceGame.Phase.OVER, "el duelo termina")
	check(turns.size() >= 6, "hubo varios turnos (%d)" % turns.size())
	var alternate: bool = true
	for i in range(1, turns.size()):
		if turns[i] == turns[i - 1]:
			alternate = false
	check(alternate, "se alternan tirador y arquero en cada turno")
	var same: int = 0
	var rounds: int = 0
	for k in spots.keys():
		if String(k).begins_with("0:"):
			var other: String = "1:" + String(k).substr(2)
			if spots.has(other):
				rounds += 1
				if (spots[k] as Vector3).distance_to(spots[other]) < 0.01:
					same += 1
	check(rounds >= 3 and same == rounds, "los dos patean desde el mismo punto en cada ronda (%d de %d)" % [same, rounds])
	check(wall_ok == turns.size(), "la barrera siempre es del equipo que ataja (%d de %d)" % [wall_ok, turns.size()])
	check(keeper_ok == turns.size(), "ataja el arquero del equipo que no patea (%d de %d)" % [keeper_ok, turns.size()])
	check(g.hud.overlay.visible and g.hud.overlay_text.text.contains("Duelo de tiros libres"), "pantalla final del duelo: «%s»" % g.hud.overlay_text.text)
	cleanup()

## La CPU elige su tiro libre sin saber a que sector se jugo el usuario: con la misma semilla, elegir otro sector no cambia
## el destino de la CPU.
func test_the_cpu_does_not_know_the_user_pick() -> void:
	var targets: Array = []
	for pick in [0, 8, 4]:
		var g: SetPieceGame = await _game(SetPieceGame.Vs.CPU)
		# Mismo punto de tiro en las tres partidas (el orden de los puntos se sortea al abrir la escena).
		g.spot_offset = 0
		g.shootout.record(0, true)
		g._start_fk_duel_turn()
		await physics_frames(3)
		check(g.phase == SetPieceGame.Phase.KEEPER_PICK and not g.user_shooting, "patea la CPU: el usuario elige el sector")
		check(g._zone_grid.visible, "se ve la grilla de 9 sectores")
		g.pick_sector(pick)
		g.rng.seed = 2024
		g._pick_t = 1.0
		await physics_frames(2)
		targets.append(g.last_params.target if g.last_params != null else Vector3.INF)
		check(g.user_keeper.committed_zone == pick or g.phase != SetPieceGame.Phase.RUNUP, "el arquero del usuario se juega al sector %d" % pick)
		cleanup()
	note("destinos de la CPU: %s" % str(targets))
	check(targets[0] != Vector3.INF and targets[0].is_equal_approx(targets[1]) and targets[1].is_equal_approx(targets[2]), "el destino de la CPU no depende del sector elegido")

## La practica libre de siempre (sin turnos): se coloca la pelota y patea solo el usuario.
func test_free_kick_practice_is_unchanged() -> void:
	var g: SetPieceGame = await _game(-1)
	check(not g.fk_duel(), "sin turnos")
	check(g.phase == SetPieceGame.Phase.PLACE, "se elige donde poner la pelota")
	check(g.cpu_shooter == null and g.user_keeper == null, "no hay tirador de la CPU ni arquero del usuario")
	g._on_action(&"confirm")
	await physics_frames(2)
	check(g.phase == SetPieceGame.Phase.AIM and g.user_shooting, "patea el usuario")
	check(g.cpu_keeper.actor.visible, "ataja la CPU")
	cleanup()
