extends TestCase
## Regresion de las fugas de ObjectDB al cerrar: BallHandler y sus submodulos (DragBack, BallTurn, JsonBallMove,
## JsonReceive) son RefCounted y se apuntan mutuamente (`handler`). Antes de BallHandler.dispose(), liberar un
## futbolista dejaba vivos los cinco objetos (y su RandomNumberGenerator) hasta el cierre de Godot: «N ObjectDB instances
## were leaked» y «resources still in use at exit» (ball_handler.gd, ball_turn.gd, drag_back.gd, json_*.gd).

func test_freed_footballer_releases_its_ball_handler_and_submodules() -> void:
	var ctx: MatchContext = await make_match(Vector3(2.0, 0.11, 0.0))
	var p: Footballer = add_player(ctx, 0, Vector3.ZERO, 60, ScriptedInput.new())
	await physics_frames(5)
	var bh: BallHandler = p.ball_handler
	var refs: Array[WeakRef] = [weakref(bh), weakref(bh.drag_back), weakref(bh.ball_turn), weakref(bh.json_move), weakref(bh.receive), weakref(bh.rng)]
	bh = null
	p.queue_free()
	await physics_frames(3)
	var alive: Array[int] = []
	for i in refs.size():
		if refs[i].get_ref() != null:
			alive.append(i)
	check(alive.is_empty(), "al liberar el futbolista no queda vivo ningun objeto del manejo de pelota (vivos: %s)" % str(alive))
	cleanup()

func test_ball_handler_dispose_is_safe_to_call_twice() -> void:
	var ctx: MatchContext = await make_match(Vector3(2.0, 0.11, 0.0))
	var p: Footballer = add_player(ctx, 0, Vector3.ZERO, 60, ScriptedInput.new())
	await physics_frames(2)
	var bh: BallHandler = p.ball_handler
	bh.dispose()
	bh.dispose()
	check(bh.json_move == null and bh.receive == null and bh.drag_back == null and bh.ball_turn == null, "dispose deja los submodulos sin referencias")
	# Restituye un manejador nuevo para que el resto de la limpieza sea la normal del juego.
	p.ball_handler = BallHandler.new(p)
	cleanup()

## Segundo ciclo (test_physical_dribble con render): una lambda conectada a una senal del propio BallHandler
## (touched_ball) que captura el manejador lo mantenia vivo. dispose() desconecta sus senales.
func test_lambda_on_a_ball_handler_signal_does_not_keep_it_alive() -> void:
	var ctx: MatchContext = await make_match(Vector3(2.0, 0.11, 0.0))
	var p: Footballer = add_player(ctx, 0, Vector3.ZERO, 60, ScriptedInput.new())
	await physics_frames(2)
	var ref: WeakRef = _connect_capturing_lambda(p.ball_handler)
	p.queue_free()
	await physics_frames(3)
	check(ref.get_ref() == null, "la lambda que captura el manejador no lo deja vivo al liberar el futbolista")
	cleanup()

## En una funcion aparte: los temporales de la pila de una corrutina con await (la prueba) retendrian el manejador.
func _connect_capturing_lambda(bh: BallHandler) -> WeakRef:
	var touches := [0]
	bh.touched_ball.connect(func(_kind: StringName) -> void: touches[0] += bh.foot_touches)
	return weakref(bh)
