extends TestCase
## Modos de tiros libres y penales con el esqueleto animado (necesitan render: en CI se ejecutan con xvfb):
##  - el pie del tirador llega a la pelota en el instante del impulso, en golpeos de distintas direcciones y tipos;
##  - el arquero que se lanza a la zona correcta toca la pelota con su cuerpo animado (la fisica decide atajada o desvio)
##    y el que se lanza al otro lado no la toca (nunca se mueve la pelota hacia las manos).

func _needs_render() -> bool:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return true
	return false

func _game(mode: int) -> SetPieceGame:
	SetPieceGame.next_mode = mode
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	return game

func _wait_phase_change(game: SetPieceGame, from: int, max_frames: int = 600) -> void:
	var n: int = 0
	while game.phase == from and n < max_frames:
		await tree.physics_frame
		n += 1

func test_the_foot_reaches_the_ball_at_the_impulse() -> void:
	if _needs_render():
		return
	var worst: float = 0.0
	for c in [[0.5, -2.8, 0.75, 0.0], [0.5, 2.8, 0.45, 0.0], [1.8, 0.0, 0.9, 0.0], [1.2, -1.5, 0.35, 0.15], [1.7, 1.0, 0.1, 0.0]]:
		var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
		game.shoot(Vector3(game.gx, c[0], c[1]), c[2], c[3])
		var e: Dictionary = game.last_shot.get("entry", {})
		await _wait_phase_change(game, SetPieceGame.Phase.RUNUP)
		var gap: float = game.user_shooter.contact_gap
		worst = maxf(worst, gap)
		note("objetivo (%.1f, %.1f) potencia %.2f: %s (%s) pie-pelota %.3f m, sale a %.1f m/s" % [c[1], c[0], c[2], e.get("id", "-"),
			ShotCatalog.Kind.keys()[int(game.last_shot.get("kind", 1))], gap, game.ball.linear_velocity.length()])
		check(game.phase == SetPieceGame.Phase.FLIGHT, "%s: hubo contacto" % e.get("id", "-"))
		check(gap >= 0.0 and gap < 0.4, "%s: la punta del pie esta en la pelota al golpear (%.3f m)" % [e.get("id", "-"), gap])
		cleanup()
	note("peor distancia pie-pelota en el impulso: %.3f m" % worst)

func test_the_keeper_touches_what_he_reaches_and_not_what_he_does_not() -> void:
	if _needs_render():
		return
	var touched_right: int = 0
	var touched_wrong: int = 0
	# Sin anticiparse mas de PENALTY_ANTICIPATION al golpe (como los arqueros reales) no llega a todo: a 18 m/s, de seis
	# tiros a la zona elegida, medido en esta maquina: toca 4. Antes del arreglo se tiraba hasta 0,7 s antes y llegaba a
	# casi todo (y el usuario lo veia tirarse antes del golpe).
	var cases := [Vector3(52.5, 0.6, -2.0), Vector3(52.5, 1.2, 1.6), Vector3(52.5, 0.4, 2.4), Vector3(52.5, 1.8, -2.6), Vector3(52.5, 0.3, 3.0), Vector3(52.5, 1.0, -1.0)]
	for target in cases:
		for correct in [true, false]:
			var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
			game.rng.seed = 4242
			game.user_keeper.rng.seed = 99
			game.shootout.record(0, true)
			game._start_penalty_turn()
			await physics_frames(5)
			var zone: Vector3 = target if correct else Vector3(target.x, target.y, -target.z)
			game._keeper_zone = zone
			game._pick_t = 1.0
			# La CPU patea a `target` (sin error de precision) a velocidad media.
			var p := ShotParams.new()
			p.target = target
			p.power = 0.45
			p.speed = 18.0
			p.kind = ShotCatalog.Kind.NORMAL
			p.direction = Vector3(target.x - game.ball_spot.x, 0, target.z - game.ball_spot.z).normalized()
			GestureShotModel.solve(p, game.ball_spot, game.shot_context(), false)
			game.phase = SetPieceGame.Phase.RUNUP
			game._take_shot(game.cpu_shooter, p, 0.0)
			var n: int = 0
			while game.phase in [SetPieceGame.Phase.RUNUP, SetPieceGame.Phase.FLIGHT] and n < 900:
				await tree.physics_frame
				n += 1
			var k: SpKeeper = game.user_keeper
			note("tiro a (%.1f, %.1f), arquero a %s: estirada %s, toque «%s», resultado %s" % [target.z, target.y, "la zona" if correct else "el otro lado",
				str(k.plan.get("clip", "-")), k.touch_kind, game.outcome])
			if correct and k.touch_kind != &"":
				touched_right += 1
			if not correct and k.touch_kind != &"":
				touched_wrong += 1
			cleanup()
	check(touched_right >= 2, "lanzandose a la zona del tiro la toca (%d de 6; medido 3-4)" % touched_right)
	check(touched_wrong == 0, "lanzandose al otro lado no la toca (%d)" % touched_wrong)

## Penal: el arquero (del usuario y de la IA) no arranca la estirada mas de PENALTY_ANTICIPATION (+ un margen de
## estimacion de la carrera) antes del golpe del tirador. Antes del arreglo arrancaba 0,2-0,7 s antes (hasta 1,3 s).
func test_the_penalty_keeper_does_not_dive_before_the_kick() -> void:
	if _needs_render():
		return
	var worst: float = 0.0
	var limit: float = SpKeeper.PENALTY_ANTICIPATION + 0.1
	# Arquero del usuario: zona correcta, distintas velocidades.
	for c in [[Vector3(52.5, 0.6, -2.0), 18.0], [Vector3(52.5, 1.2, 1.6), 21.0], [Vector3(52.5, 0.4, 2.4), 26.0]]:
		var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
		game.shootout.record(0, true)
		game._start_penalty_turn()
		await physics_frames(5)
		game._keeper_zone = c[0]
		game._pick_t = 1.0
		var p := ShotParams.new()
		p.target = c[0]
		p.power = 0.55
		p.speed = c[1]
		p.kind = ShotCatalog.Kind.NORMAL
		p.direction = Vector3(p.target.x - game.ball_spot.x, 0, p.target.z - game.ball_spot.z).normalized()
		GestureShotModel.solve(p, game.ball_spot, game.shot_context(), false)
		game.phase = SetPieceGame.Phase.RUNUP
		game._take_shot(game.cpu_shooter, p, 0.0)
		var lead: float = await _dive_lead(game, game.user_keeper)
		note("usuario, tiro a (%.1f, %.1f) a %.0f m/s: la estirada arranca %.2f s antes del golpe" % [p.target.z, p.target.y, c[1], lead])
		worst = maxf(worst, lead)
		check(game._zone_marker.visible == false, "el circulo de la zona elegida ya no se ve despues del golpe")
		cleanup()
	# Arquero de la IA.
	for c in [[0.6, -2.0, 0.6], [1.2, 1.6, 0.5], [0.4, 2.4, 0.8], [0.9, -1.2, 0.95]]:
		var game: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
		game.shoot(Vector3(game.gx, c[0], c[1]), c[2], 0.0)
		var lead: float = await _dive_lead(game, game.cpu_keeper)
		note("IA, tiro a (%.1f, %.1f) potencia %.2f: la estirada arranca %.2f s antes del golpe" % [c[1], c[0], c[2], lead])
		worst = maxf(worst, lead)
		cleanup()
	note("lo mas temprano: %.2f s antes del golpe (limite %.2f s)" % [worst, limit])
	check(worst <= limit, "ninguna estirada arranca mas de %.2f s antes del golpe (%.2f s)" % [limit, worst])

## Segundos que la estirada arranco ANTES del contacto del pie (negativo: despues). -99 si no se tiro.
func _dive_lead(game: SetPieceGame, k: SpKeeper) -> float:
	var n: int = 0
	var dive_f: int = -1
	var contact_f: int = -1
	while game.phase in [SetPieceGame.Phase.RUNUP, SetPieceGame.Phase.FLIGHT] and n < 900:
		await tree.physics_frame
		n += 1
		if dive_f < 0 and k.state == SpKeeper.State.DIVE:
			dive_f = n
		if contact_f < 0 and game.phase == SetPieceGame.Phase.FLIGHT:
			contact_f = n
	if dive_f < 0 or contact_f < 0:
		return -99.0
	return float(contact_f - dive_f) / 60.0

## Pelota suelta en el area despues de la jugada: nunca queda muerta. En el tiro libre la despeja un defensor (el impulso
## sale solo si su pie llega a la pelota) o la recoge el arquero; en el penal la recoge el arquero.
func test_a_loose_ball_never_stays_dead_in_the_box() -> void:
	if _needs_render():
		return
	for c in [[Vector3(-8, 0, 3), Vector3.ZERO], [Vector3(-12, 0, -6), Vector3(0.5, 0, 0.3)], [Vector3(-4, 0, 0.5), Vector3.ZERO], [Vector3(-10, 0, 9), Vector3(-2.0, 0, 1.0)]]:
		var game: SetPieceGame = await _game(SetPieceGame.Mode.FREE_KICK)
		game.ball_spot = game.clamp_free_kick_spot(Vector3(30.0, 0, 0.0))
		game._setup_free_kick()
		await physics_frames(10)
		game.ball.reset_at(Vector3(game.gx, game.ball.radius, 0) + c[0], c[1])
		await physics_frames(2)
		game.phase = SetPieceGame.Phase.FLIGHT
		game._finish("wall")
		check(game.outcome == "wall", "el tiro libre ya fue fallido (barrera) antes del despeje")
		var n: int = 0
		while n < 720 and game.loose.active():
			await tree.physics_frame
			n += 1
		var bp: Vector3 = game.ball.global_position
		note("pelota suelta en %s: %s en %.1f s" % [str(c[0]), str(game.loose.log_steps), n / 60.0])
		check(game.chaser != null, "alguien va a buscarla (%s)" % str(c[0]))
		check(game.ball.is_held() or (game.loose.cleared and game.ball.linear_velocity.length() > 8.0), "la despejan o la recoge el arquero (%s)" % str(c[0]))
		check(game.outcome == "wall", "el resultado no cambia con el despeje")
		cleanup()
	# Penal sin el modo rapido de las pruebas (el turno siguiente espera a que el arquero termine, hasta 6 s).
	var g2: SetPieceGame = await _game(SetPieceGame.Mode.PENALTY)
	g2.fast = false
	g2.ball.reset_at(Vector3(g2.gx - 5.0, g2.ball.radius, 2.0))
	await physics_frames(2)
	g2.phase = SetPieceGame.Phase.FLIGHT
	g2._finish("save")
	var went: bool = g2.chaser == g2.cur_keeper.actor
	var got: bool = false
	var m: int = 0
	while m < 600 and g2.loose.active():
		await tree.physics_frame
		m += 1
		got = got or g2.ball.is_held() or g2.loose.cleared
	note("penal, pelota suelta a 5 m del arco: %s en %.1f s" % [str(g2.loose.log_steps), m / 60.0])
	check(went, "en el penal va el arquero")
	check(got, "el arquero la recoge (o la despeja)")
	cleanup()

## Los jugadores no se quedan en bucle esperando: el tirador y el arquero reaccionan al resultado aunque llegue mientras
## todavia terminan el golpeo o la estirada (la reaccion queda pendiente y sale al terminar).
func test_shooter_and_keeper_react_after_finishing_their_move() -> void:
	if _needs_render():
		return
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	spawn(game)
	await physics_frames(10)
	game.shoot(Vector3(game.gx, 0.5, 3.0), 0.85, 0.0)
	var shooter_reacted: bool = false
	var keeper_reacted: bool = false
	var n: int = 0
	var t_result: int = -1
	while n < 60 * 7 and game.phase != SetPieceGame.Phase.KEEPER_PICK:
		await tree.physics_frame
		n += 1
		if game.phase == SetPieceGame.Phase.RESULT and t_result < 0:
			t_result = n
		if t_result >= 0:
			shooter_reacted = shooter_reacted or game.user_shooter.state == SpShooter.State.REACT
			keeper_reacted = keeper_reacted or game.cpu_keeper.state == SpKeeper.State.REACT or game.cpu_keeper.is_collecting() \
				or game.cpu_keeper.state == SpKeeper.State.HOLD
	note("resultado %s; el tirador reacciono %s, el arquero reacciono %s" % [game.outcome, str(shooter_reacted), str(keeper_reacted)])
	check(t_result > 0, "hay resultado")
	check(shooter_reacted, "el tirador festeja o se lamenta")
	check(keeper_reacted, "el arquero reacciona (o va por la pelota / la tiene)")
	cleanup()
