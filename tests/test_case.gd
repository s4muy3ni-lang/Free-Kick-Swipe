class_name TestCase
extends RefCounted
## Base minima para las pruebas headless. Cada metodo "test_*" de una subclase es una prueba.
## Se ejecutan con tests/run_tests.gd. Sin dependencias externas.

var tree: SceneTree
var failures: Array[String] = []
var checks: int = 0
var _spawned: Array[Node] = []
## Contextos creados por make_match: cleanup() desconecta sus senales (ver alli).
var _contexts: Array[MatchContext] = []
## Una prueba omitida (p. ej. falta un recurso restringido que no se versiona) no cuenta como fallo ni como comprobacion.
var skipped: bool = false
var skip_reason: String = ""

## Modo de juego en que corre la prueba: 0 = el del juego (Tuning.DEFAULT_GAMEPLAY_MODE, el 4, o TEST_GAMEPLAY_MODE). Las
## pruebas de un modo distinto (3 = solo Tripo, respaldo del codigo heredado) devuelven su modo. Los modos 1 (Mixamo) y 2
## (Mocap) se borraron con sus bancos.
func gameplay_mode() -> int:
	return 0

func skip(reason: String) -> void:
	skipped = true
	skip_reason = reason

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	checks += 1
	if absf(actual - expected) > tolerance:
		failures.append("%s (esperado %.4f +- %.4f, obtenido %.4f)" % [message, expected, tolerance, actual])

func check_range(actual: float, low: float, high: float, message: String) -> void:
	checks += 1
	if actual < low or actual > high:
		failures.append("%s (esperado en [%.4f, %.4f], obtenido %.4f)" % [message, low, high, actual])

## Imprime una medida real (aparece en el log de la ejecucion como evidencia).
func note(message: String) -> void:
	print("       · %s" % message)

func fail(message: String) -> void:
	checks += 1
	failures.append(message)

## Espera n pasos de fisica.
func physics_frames(n: int) -> void:
	for i in n:
		await tree.physics_frame

## Espera n segundos simulados (60 Hz).
func wait_seconds(seconds: float) -> void:
	await physics_frames(int(round(seconds * Engine.physics_ticks_per_second)))

func spawn(node: Node) -> Node:
	tree.root.add_child(node)
	_spawned.append(node)
	return node

func cleanup() -> void:
	# Una repeticion o una pausa a medias no puede contagiar a la prueba siguiente.
	tree.paused = false
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	# Las pruebas conectan lambdas a ctx.event_emitted que capturan el propio ctx (o la prueba): MatchContext es
	# RefCounted y ese ciclo lo dejaba vivo hasta el cierre («ObjectDB instances were leaked»). Se rompe aqui.
	for c in _contexts:
		for conn in c.event_emitted.get_connections():
			c.event_emitted.disconnect(conn["callable"])
	_contexts.clear()
	# Interruptores globales que algunas pruebas cambian: cada prueba empieza con los valores por defecto.
	FootballerVisual.prefer_pack = true
	BallHandler.clip_kicks_enabled = true
	BallHandler.foot_sync_enabled = true
	Input.flush_buffered_events()
	for action in InputMap.get_actions():
		Input.action_release(action)

## Las pruebas se escribieron para la cancha de futsal de 40 x 20 con arcos de 3 m (posiciones fijas en metros); el
## partido real usa la de futbol 7 de 50 x 30 (PitchConfig). El runner llama begin() antes de cada prueba: Tuning.pitch
## pasa a ser la de futsal hasta end(). Una prueba que quiere la cancha del juego llama use_game_pitch() al empezar.
var _game_pitch: PitchConfig = null

func begin() -> void:
	if _game_pitch == null:
		_game_pitch = Tuning.pitch
		Tuning.pitch = PitchConfig.futsal()

func use_game_pitch() -> void:
	if _game_pitch != null:
		Tuning.pitch = _game_pitch

## Lo llama el runner al terminar la prueba (despues de cleanup): devuelve la cancha del juego.
func end() -> void:
	if _game_pitch != null:
		Tuning.pitch = _game_pitch
		_game_pitch = null

## Crea cancha + pelota listas para simular.
func make_world(ball_pos: Vector3 = Vector3(0, 0.5, 0)) -> Dictionary:
	var pitch := Pitch.new()
	pitch.name = "TestPitch"
	spawn(pitch)
	var ball_scene: PackedScene = load("res://scenes/ball/ball.tscn")
	var ball: Ball = ball_scene.instantiate()
	spawn(ball)
	ball.global_position = ball_pos
	pitch.set_ball(ball)
	await physics_frames(2)
	return {"pitch": pitch, "ball": ball}

var _next_id: int = 1

## Cancha + pelota + contexto de partido.
func make_match(ball_pos: Vector3 = Vector3(0, 0.12, 0)) -> MatchContext:
	var w: Dictionary = await make_world(ball_pos)
	var ctx := MatchContext.new()
	ctx.ball = w["ball"]
	ctx.pitch = w["pitch"]
	_contexts.append(ctx)
	return ctx

## Agrega un futbolista con entrada programable. Por defecto atributos neutros (50).
func add_player(ctx: MatchContext, team: int, pos: Vector3, base_attr: int = 50, source: InputSource = null, with_visual: bool = false) -> Footballer:
	var scene: PackedScene = load("res://scenes/player/footballer.tscn")
	var f: Footballer = scene.instantiate()
	f.build_visual = with_visual
	spawn(f)
	f.global_position = pos
	var attrs := PlayerAttributes.new()
	attrs.reset_to(base_attr)
	var src: InputSource = source if source != null else ScriptedInput.new()
	f.setup(ctx, team, _next_id, attrs, src)
	_next_id += 1
	f.ball_handler.rng.seed = 12345 + _next_id
	return f
