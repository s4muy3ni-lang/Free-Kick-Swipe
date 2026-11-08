extends TestCase
## F2 — Arbitro de acciones (ActionArbiter, modo 4): una sola autoridad sobre el cuerpo y la pose del futbolista.
## Prioridad por nivel, interrupcion completa, testigos obsoletos, clips inexistentes, liberacion al terminar y reinicio
## sin residuos. Headless: la pose se comprueba por FootballerVisual.current_action (el esqueleto no se anima).

const START := Vector3(-10.0, 0.0, 0.0)

func _skip_if_missing() -> bool:
	if not ResourceLoader.exists(PackLibrary.JSON_FIELD_PATH):
		skip("no existe assets/animations/json_clips.res")
		return true
	return false

func _player() -> Footballer:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()
	var ctx: MatchContext = await make_match(START + Vector3(0.6, 0.11, 0.0))
	var p: Footballer = add_player(ctx, 0, START, 60, ScriptedInput.new(), true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(2)
	return p

func _restore() -> void:
	Tuning.gameplay_mode = 1
	PackLibrary.reload()

## Un clip de gesto en el sitio (forcejeo) que el arbitro acepte con el jugador quieto.
func _gesture_clip() -> StringName:
	return JsonCatalog.situation_clip(&"tackle_stand", 3)

func test_higher_level_replaces_lower_and_lower_cannot_interrupt() -> void:
	if _skip_if_missing():
		return
	var p: Footballer = await _player()
	var arb: ActionArbiter = p.arbiter
	var g: StringName = _gesture_clip()
	var tg: int = arb.play(&"tackle_gesture", ActionArbiter.Level.GESTURE, &"prueba", g, 1.0, 0.0, 2.0, true)
	check(tg != 0 and p.visual.current_action == g, "el gesto entra con el jugador quieto (%s)" % g)
	p.actions.suffer_contact(&"hit", Vector3(1, 0, 0))
	await physics_frames(1)
	check(p.actions.kind == &"fall" and arb.kind == &"fall" and arb.level == ActionArbiter.Level.FALL, "una caida sustituye al gesto (accion %s, arbitro %s)" % [p.actions.kind, arb.kind])
	check(p.visual.current_action == p.actions.motion.clip, "la pose es la de la caida (%s)" % p.visual.current_action)
	# Un gesto y un festejo pedidos durante la caida se rechazan: la pose sigue siendo la de la caida.
	var fall_pose: StringName = p.visual.current_action
	p.actions.tackle_gesture(null)
	var tr: int = arb.play_situation(&"celebrate", ActionArbiter.Level.GESTURE, &"prueba", 1)
	await physics_frames(1)
	check(tr == 0 and p.visual.current_action == fall_pose, "un gesto no interrumpe la caida (pose %s)" % p.visual.current_action)
	check(arb.log.any(func(l: String) -> bool: return l.contains("RECHAZADA") and l.contains("ocupado por fall")), "el rechazo queda registrado con su motivo")
	cleanup()
	_restore()

func test_a_foul_knocks_down_a_player_in_a_ball_move() -> void:
	# Antes del arbitro: un jugador en un movimiento con pelota de clip (giro, regate) recibia la falta y NO caia (la falta
	# se pitaba y seguia regateando). La caida tiene mas nivel: corta el movimiento y el movimiento cortado no sigue.
	if _skip_if_missing():
		return
	var p: Footballer = await _player()
	# Movimiento con pelota real: giro con la pelota al pie hacia atras (JsonBallMove con su clip y sus toques).
	var bh: BallHandler = p.ball_handler
	check(bh.json_move.turn_for_kick(Vector3(-1, 0, 0)), "JsonBallMove arranca un giro con pelota de clip")
	var clip: StringName = p.actions.motion.clip
	check(p.actions.kind == &"ball_move" and bh.json_move.active and p.arbiter.level == ActionArbiter.Level.BALL_MOVE, "accion ball_move a nivel de movimiento con pelota (%s)" % clip)
	await physics_frames(2)
	p.actions.suffer_contact(&"trip", Vector3(1, 0, 0))
	await physics_frames(2)
	check(p.actions.kind == &"fall" or p.actions.kind == &"down" or p.actions.kind == &"pain", "la falta lo derriba (accion %s)" % p.actions.kind)
	check(int(p.actions.stats.get("falls", 0)) == 1, "cuenta una caida")
	check(not p.ball_handler.json_move.active, "el movimiento con pelota cortado ya no esta activo")
	check(p.actions.motion.clip != clip, "la raiz ya no es la del movimiento cortado")
	cleanup()
	_restore()

func test_one_root_controller_and_pose_follows_the_root_until_it_ends() -> void:
	if _skip_if_missing():
		return
	var p: Footballer = await _player()
	var arb: ActionArbiter = p.arbiter
	p.actions.suffer_contact(&"hit", Vector3(1, 0, 0))
	await physics_frames(1)
	var fall_clip: StringName = p.actions.motion.clip
	# Otra accion con raiz de menos nivel (un giro) no entra mientras cae.
	var turn_clip: StringName = PackLibrary.by_role(&"turn_start")[0]
	check(not p.actions.start_move(&"turn", turn_clip, 1.0), "un giro no entra durante la caida")
	check(p.actions.motion.clip == fall_clip, "la raiz sigue siendo la de la caida")
	# Hasta que termina la cadena (caer, tendido, levantarse) la pose es siempre la del clip que mueve el cuerpo: ni una
	# imagen sin pose (antes la pose se apagaba un paso antes que la raiz).
	var mismatch := 0
	var frames := 0
	while p.actions.active() and frames < 60 * 12:
		await tree.physics_frame
		frames += 1
		if p.actions.motion.active and p.visual.current_action != p.actions.motion.clip:
			mismatch += 1
	note("cadena de caida: %d imagenes, %d con la pose distinta de la raiz" % [frames, mismatch])
	check(frames < 60 * 12, "la cadena de caida termina")
	check(mismatch == 0, "la pose acompana a la raiz en todas las imagenes (%d distintas)" % mismatch)
	check(arb.current_level() == ActionArbiter.Level.NONE and arb.token == 0, "al terminar, el arbitro queda libre")
	check(p.visual.current_action == &"", "y no queda ninguna pose sonando (%s)" % p.visual.current_action)
	cleanup()
	_restore()

func test_finished_action_releases_locks_and_locomotion_resumes() -> void:
	if _skip_if_missing():
		return
	var p: Footballer = await _player()
	var src: ScriptedInput = p.input_source
	var clip: StringName = PackLibrary.by_role(&"turn_start")[0]
	check(p.actions.start_move(&"turn", clip, 1.5), "arranca un giro con clip")
	var frames := 0
	while p.actions.active() and frames < 300:
		await tree.physics_frame
		frames += 1
	check(not p.actions.active() and p.arbiter.current_level() == ActionArbiter.Level.NONE, "el giro termina y libera el arbitro (%d imagenes)" % frames)
	await physics_frames(40)
	check(p.ball_handler.lockout <= 0.0, "el bloqueo de pelota de la accion se libera (%.2f)" % p.ball_handler.lockout)
	# La locomocion vuelve: con el joystick a fondo el jugador acelera.
	src.move = Vector2(1.0, 0.0)
	await physics_frames(60)
	check(p.locomotion.speed > 2.0, "la locomocion vuelve a mandar (%.1f m/s)" % p.locomotion.speed)
	cleanup()
	_restore()

func test_stale_tokens_do_nothing() -> void:
	if _skip_if_missing():
		return
	var p: Footballer = await _player()
	var arb: ActionArbiter = p.arbiter
	var t1: int = arb.play(&"tackle_gesture", ActionArbiter.Level.GESTURE, &"prueba", _gesture_clip(), 1.0, 0.0, 2.0, true)
	check(t1 != 0, "el gesto entra")
	p.actions.suffer_contact(&"hit", Vector3(1, 0, 0))
	await physics_frames(1)
	var pose: StringName = p.visual.current_action
	check(not arb.release(t1, "el gesto termina tarde"), "liberar con el testigo viejo no hace nada")
	check(not arb.handover(t1, &"x", &"y"), "encadenar con el testigo viejo no hace nada")
	check(not arb.relevel(t1, ActionArbiter.Level.NONE), "cambiar el nivel con el testigo viejo no hace nada")
	check(arb.kind == &"fall" and p.visual.current_action == pose and p.actions.active(), "la caida sigue intacta")
	check(int(arb.stats["obsoletas"]) >= 2, "las solicitudes obsoletas se cuentan (%d)" % int(arb.stats["obsoletas"]))
	cleanup()
	_restore()

func test_missing_clip_fails_safely() -> void:
	if _skip_if_missing():
		return
	var p: Footballer = await _player()
	var arb: ActionArbiter = p.arbiter
	check(arb.play(&"gesto", ActionArbiter.Level.GESTURE, &"prueba", &"clip_que_no_existe") == 0, "un clip inexistente se rechaza")
	check(not p.actions.start(&"fall", &"clip_que_no_existe"), "una accion con clip inexistente no empieza")
	# Nombres del pack que el codigo pide y no tienen clip en el modo 4 (no hacen nada, sin dejar nada tomado). Idle_To_Sprint,
	# Running_Tired y Defender_2 ya tienen clip del banco (ClipRolesOverlay.ALIAS, test_bank_integration).
	for missing in [&"Sprint_Turn", &"Soccer_Spin"]:
		check(arb.play(&"capa", ActionArbiter.Level.OVERLAY, &"prueba", missing) == 0, "'%s' (sin clip JSON) se rechaza" % missing)
	await physics_frames(1)
	check(arb.level == ActionArbiter.Level.NONE and arb.token == 0 and p.visual.current_action == &"" and not p.actions.active(), "no queda nada tomado ni sonando")
	cleanup()
	_restore()

func test_in_place_pose_is_refused_while_running() -> void:
	if _skip_if_missing():
		return
	var p: Footballer = await _player()
	var src: ScriptedInput = p.input_source
	src.move = Vector2(1.0, 0.0)
	src.sprint = true
	await physics_frames(90)
	var g: StringName = _gesture_clip()
	note("velocidad %.1f m/s, clip %s a %.1f m/s" % [p.locomotion.speed, g, ActionArbiter.clip_speed(g)])
	check(p.arbiter.play(&"tackle_gesture", ActionArbiter.Level.GESTURE, &"prueba", g, 1.0, 0.0, 1.0, true) == 0, "un gesto en el sitio no empieza con el cuerpo corriendo")
	check(p.visual.current_action == &"", "no hay pose deslizandose")
	cleanup()
	_restore()

func test_simultaneous_requests_resolve_by_level_not_by_order() -> void:
	if _skip_if_missing():
		return
	var finals: Array = []
	for order in [0, 1]:
		var p: Footballer = await _player()
		var arb: ActionArbiter = p.arbiter
		var g: StringName = _gesture_clip()
		check(g != &"", "hay clip de gesto")
		# En la misma imagen: un gesto y una caida, en los dos ordenes.
		if order == 0:
			arb.play(&"tackle_gesture", ActionArbiter.Level.GESTURE, &"prueba", g, 1.0, 0.0, 2.0, true)
			p.actions.suffer_contact(&"hit", Vector3(1, 0, 0))
		else:
			p.actions.suffer_contact(&"hit", Vector3(1, 0, 0))
			arb.play(&"tackle_gesture", ActionArbiter.Level.GESTURE, &"prueba", g, 1.0, 0.0, 2.0, true)
		finals.append(arb.kind)
		cleanup()
	check(finals[0] == &"fall" and finals[1] == &"fall", "con niveles distintos gana el mayor en cualquier orden (%s)" % str(finals))
	# Con el mismo nivel la que ya corre se completa (regla fija): el segundo gesto se rechaza.
	var q: Footballer = await _player()
	var g: StringName = _gesture_clip()
	var first: int = q.arbiter.play(&"g1", ActionArbiter.Level.GESTURE, &"prueba", g, 1.0, 0.0, 2.0, true)
	var second: int = q.arbiter.play(&"g2", ActionArbiter.Level.GESTURE, &"prueba", g, 1.0, 0.0, 2.0, true)
	check(first != 0 and second == 0 and q.arbiter.kind == &"g1", "con igual nivel sigue la que ya corre (%d, %d, %s) %s" % [first, second, q.arbiter.kind, str(q.arbiter.log.slice(-3))])
	cleanup()
	_restore()

func test_reset_leaves_no_residue() -> void:
	if _skip_if_missing():
		return
	var p: Footballer = await _player()
	var arb: ActionArbiter = p.arbiter
	p.actions.suffer_contact(&"hit", Vector3(1, 0, 0))
	await physics_frames(5)
	# Antes del arbitro: tras PlayerActions.reset() la pose de la accion seguia sonando sin nadie que la moviera.
	p.actions.reset()
	await physics_frames(1)
	check(not p.actions.active() and p.actions.kind == &"" and arb.level == ActionArbiter.Level.NONE, "reset de las acciones: nada activo")
	check(p.visual.current_action == &"", "y sin pose huerfana (%s)" % p.visual.current_action)
	# Colocacion para un saque en medio de una caida: todo limpio.
	p.actions.suffer_contact(&"hit", Vector3(1, 0, 0))
	await physics_frames(3)
	p.place_at(START, 0.0)
	await physics_frames(1)
	check(not p.actions.active() and arb.token == 0 and p.visual.current_action == &"" and not p.ball_handler.json_move.active and not p.ball_handler.is_kick_in_progress(), "colocacion: sin acciones, testigos, poses ni golpeos pendientes")
	cleanup()
	_restore()
