extends TestCase
## Cada transicion tiene una condicion geometrica realizable y pasa por el arbitro normal del jugador.

func test_all_previously_unrouted_transitions_can_start_in_their_own_state() -> void:
	var ctx: MatchContext = await make_match(Vector3(12, 0.11, 6))
	var p: Footballer = add_player(ctx, 0, Vector3.ZERO, 60, ScriptedInput.new(), true)
	p.set_physics_process(false)
	var count: int = 0
	for role in PlayerActions.LOCOMOTION_TRANSITIONS:
		for id in AnimDB.candidates(role, {"mirrors": false}):
			var m: Dictionary = PackLibrary.meta(id)
			p.actions.reset()
			p.global_position = Vector3.ZERO
			p.locomotion.yaw = 0.0
			var root: Vector2 = m.get("root_total", Vector2.ZERO)
			var direction: Vector3 = (p.locomotion.forward() * root.x + p.locomotion.right() * root.y).normalized()
			if direction.length() < 0.1:
				direction = p.locomotion.forward()
			var turn: float = ActionMotion.heading_rel(m["heading_path"], m["duration"])
			p.locomotion.face_override = Locomotion.dir_from_yaw(turn)
			p.locomotion.speed = float(m["v_in"])
			p.locomotion.velocity = direction * p.locomotion.speed
			var magnitude: float = 0.0 if role == &"step_stand" else (0.3 if role == &"turn_stop" else 1.0)
			check(p.actions.request_locomotion_transition(id, direction, magnitude), "%s entra en su estado de movimiento" % id)
			check(p.visual.current_action == id and p.arbiter.level == ActionArbiter.Level.BODY, "%s se invoca por el arbitro real" % id)
			p.actions.tick(1.0 / 60.0)
			check(p.global_position.is_finite(), "%s aplica su raiz sin valores invalidos" % id)
			count += 1
	check(count == 14, "14 transiciones del selector (13 pendientes historicas y una existente)")

func test_incoming_ball_keeps_the_body_available_for_a_first_time_kick() -> void:
	var ctx: MatchContext = await make_match(Vector3(4, 0.11, 0))
	var p: Footballer = add_player(ctx, 0, Vector3.ZERO, 60, ScriptedInput.new(), true)
	p.set_physics_process(false)
	ctx.ball.reset_at(Vector3(4, 0.11, 0), Vector3(-6, 0, 0))
	await physics_frames(2)
	check(not is_inf(p.ball_handler.incoming_ball_eta()), "la pelota se acerca fisicamente al jugador")
	check(not p.actions.try_locomotion_transition(Vector3.FORWARD, 1.0), "la transicion no cancela la preparacion de primera")
	check(not p.actions.active(), "el cuerpo queda disponible para la patada")

## Regresion (test_set_pieces, 4 de 30 repeticiones): con la pelota muerta un rival arrancaba con la raiz de una
## transicion (jn_start_0468, 4.35 m/s) y cruzaba la zona del tiro libre a 3.79 m. La raiz no puede meterlo en la zona
## del saque (MatchScene.SET_PIECE_DISTANCE para el rival); con la pelota en juego la misma transicion sigue disponible.
func test_dead_ball_transition_never_carries_a_player_into_the_set_piece_zone() -> void:
	var ctx: MatchContext = await make_match(Vector3(0, 100.0, 0))
	var p: Footballer = add_player(ctx, 1, Vector3.ZERO, 60, ScriptedInput.new(), true)
	var taker: Footballer = add_player(ctx, 0, Vector3(-12, 0, 8), 60, ScriptedInput.new(), true)
	p.set_physics_process(false)
	taker.set_physics_process(false)
	var tested: int = 0
	for id in AnimDB.candidates(&"start", {"mirrors": false}):
		var m: Dictionary = PackLibrary.meta(id)
		var root: Vector2 = m.get("root_total", Vector2.ZERO)
		if root.length() < 1.5:
			continue
		p.actions.reset()
		p.global_position = Vector3.ZERO
		p.locomotion.yaw = 0.0
		var direction: Vector3 = (p.locomotion.forward() * root.x + p.locomotion.right() * root.y).normalized()
		p.locomotion.face_override = Locomotion.dir_from_yaw(ActionMotion.heading_rel(m["heading_path"], m["duration"]))
		p.locomotion.speed = float(m["v_in"])
		p.locomotion.velocity = direction * p.locomotion.speed
		# Pelota fuera de la distancia al empezar (5.4 m) y a 3 m del final del recorrido del clip.
		var end: Vector3 = p.locomotion.forward() * root.x + p.locomotion.right() * root.y
		var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		var ball_at: Vector3 = end + side * 3.0
		if ball_at.length() < 5.4:
			ball_at = end + side * sqrt(maxf(5.4 * 5.4 - end.length_squared(), 9.0))
		ctx.ball.global_position = ball_at + Vector3(0, 0.11, 0)
		ctx.dead_ball = false
		ctx.restart_taker = null
		var live: float = p.actions.transition_score(id, direction, 1.0)
		if is_inf(live):
			continue
		ctx.dead_ball = true
		ctx.restart_taker = taker
		var dead: float = p.actions.transition_score(id, direction, 1.0)
		var min_d: float = INF
		for q: Vector2 in m.get("root_path", PackedVector2Array()):
			min_d = minf(min_d, (p.locomotion.forward() * q.x + p.locomotion.right() * q.y).distance_to(ball_at))
		if min_d < MatchScene.SET_PIECE_DISTANCE:
			check(is_inf(dead), "%s: con la pelota muerta no se elige (su raiz pasa a %.2f m de la pelota)" % [id, min_d])
			tested += 1
		ctx.dead_ball = false
		ctx.restart_taker = null
	note("transiciones de arranque comprobadas con pelota muerta: %d" % tested)
	check(tested > 0, "al menos una transicion de arranque disponible en juego cruza la zona del saque y se rechaza")
