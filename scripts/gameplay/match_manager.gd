class_name MatchManager
extends Node
## Reglas y flujo del partido: saque, juego, gol (la pelota cruza COMPLETAMENTE la linea), celebracion,
## reinicio de jugada / partido, pausa y fin de tiempo. No crea ni mueve entidades por si mismo:
## pide a la escena que las reposicione mediante la senal kickoff_requested.
## Pensado para que un servidor autoritativo pueda ejecutar este mismo codigo.

signal state_changed(new_state: int)
signal score_changed(home: int, away: int)
signal goal_scored(team: int, scorer_id: int, assist_id: int, own_goal: bool)
signal kickoff_requested(kicking_team: int)
signal message(text: String, seconds: float)
signal clock_changed(seconds: float)
## Balon parado: la escena coloca al ejecutor y a los demas. kind: "throw_in", "corner", "goal_kick", "free_kick",
## "penalty"; team: equipo que saca; pos: punto del saque.
signal set_piece_requested(kind: String, team: int, pos: Vector3)
## La escena muestra la repeticion del gol (pausa la simulacion mientras dura).
signal replay_requested

enum State { PRE_KICKOFF, PLAYING, GOAL, PAUSED, FULL_TIME, SET_PIECE }

## Duracion en segundos (0 = sin limite, util en el laboratorio).
@export var duration_seconds: float = 300.0
@export var goal_celebration_seconds: float = 3.0
## Segundos de festejo en vivo antes de la repeticion del gol (0 o menos = sin repeticion).
@export var replay_after_seconds: float = 1.3
## true mientras se ve la repeticion (la pausa del juego no se puede abrir encima).
var replay_active: bool = false
var _replay_done: bool = false
@export var pre_kickoff_seconds: float = 1.2
## Presentacion antes del primer saque (calentamiento y arbitro). 0 = sin presentacion.
@export var intro_seconds: float = 0.0
## Ventana para considerar asistencia el pase previo al gol.
@export var assist_window_seconds: float = 6.0

var ctx: MatchContext
var state: State = State.PRE_KICKOFF
var score: Array[int] = [0, 0]
var kickoff_team: int = 0

var _state_timer: float = 0.0
## Balon parado en curso (lo crea la escena) o arquero que hace el saque de arco. El juego se reanuda cuando el saque
## se ejecuta de verdad (la pelota sale del pie o de las manos del ejecutor).
var active_set_piece: SetPiece = null
var goal_kick_keeper: Node = null
var set_piece_kind: String = ""
var set_piece_team: int = -1
## Entrenamiento (sin rivales de campo): los saques siempre los hace el equipo de la persona, salvo el saque de arco
## del arquero rival; tras un gol vuelve a sacar el equipo de la persona.
var training: bool = false
var set_piece_pos: Vector3 = Vector3.ZERO
## Segundos de pelota muerta antes de habilitar al ejecutor (la escena coloca a los jugadores).
@export var set_piece_setup_seconds: float = 0.9
## Saque que se ejecuta solo si nadie lo hace (s).
const SET_PIECE_MAX_SECONDS := 14.0
var stats := {"throw_in": 0, "corner": 0, "goal_kick": 0, "free_kick": 0, "penalty": 0}
var _state_before_pause: State = State.PLAYING
var _last_touch_time_by_actor: Dictionary = {}

func setup(context: MatchContext) -> void:
	ctx = context
	ctx.pitch.goal_scored.connect(_on_goal)
	ctx.ball.touched.connect(_on_ball_touched)
	ctx.event_emitted.connect(_on_event)
	process_mode = Node.PROCESS_MODE_PAUSABLE

func start_match() -> void:
	score = [0, 0]
	ctx.match_time = 0.0
	ctx.tick = 0
	kickoff_team = 0
	score_changed.emit(0, 0)
	clock_changed.emit(0.0)
	ctx.emit_event(GameEvent.make(GameEvent.Type.MATCH_START, -1, -1))
	_begin_kickoff(0, true)

## Reinicia la jugada actual (sin tocar el marcador): saque de centro del mismo equipo.
func restart_play() -> void:
	if state == State.PAUSED:
		_set_state(_state_before_pause)
	_begin_kickoff(kickoff_team)
	ctx.emit_event(GameEvent.make(GameEvent.Type.RESTART, -1, -1))

func restart_match() -> void:
	get_tree().paused = false
	start_match()

func toggle_pause() -> void:
	if replay_active:
		return
	if state == State.PAUSED:
		get_tree().paused = false
		_set_state(_state_before_pause)
	elif state != State.FULL_TIME:
		_state_before_pause = state
		get_tree().paused = true
		_set_state(State.PAUSED)

func is_playing() -> bool:
	return state == State.PLAYING

func _begin_kickoff(team: int, intro: bool = false) -> void:
	kickoff_team = team
	ctx.dead_ball = false
	ctx.restart_taker = null
	active_set_piece = null
	goal_kick_keeper = null
	ctx.input_enabled = false
	ctx.pitch.reset_goal_latches()
	var with_intro: bool = intro and intro_seconds > 0.0
	_state_timer = intro_seconds if with_intro else pre_kickoff_seconds
	_set_state(State.PRE_KICKOFF)
	kickoff_requested.emit(team)
	message.emit("¡Saque!", _state_timer)
	PackLibrary.vary_aliases()
	ctx.emit_event(GameEvent.make(GameEvent.Type.KICKOFF, -1, team, {"intro": with_intro, "seconds": _state_timer}))

func _physics_process(delta: float) -> void:
	Prof.begin(&"partido (MatchManager)")
	_manager_step(delta)
	Prof.end(&"partido (MatchManager)")

func _manager_step(delta: float) -> void:
	if state == State.PAUSED:
		return
	ctx.tick += 1
	# Solo con la pelota en juego: tras un gol (la pelota quieta en la red) o esperando un saque no es una jugada muerta.
	if state == State.PLAYING:
		ctx.update_ball_stall(delta)
	else:
		ctx.ball_stall_seconds = 0.0
	match state:
		State.PRE_KICKOFF:
			_state_timer -= delta
			if _state_timer <= 0.0:
				ctx.input_enabled = true
				_set_state(State.PLAYING)
		State.SET_PIECE:
			ctx.match_time += delta
			clock_changed.emit(ctx.match_time)
			_state_timer -= delta
			if _state_timer <= 0.0 and not ctx.input_enabled:
				ctx.input_enabled = true
			if _set_piece_taken():
				_end_set_piece()
			elif _state_timer < -SET_PIECE_MAX_SECONDS and active_set_piece != null and active_set_piece.stage == &"setup":
				active_set_piece.ai_execute()
			elif _state_timer < -SET_PIECE_MAX_SECONDS - 6.0:
				# Salvaguarda: un saque que no se completa nunca (ejecutor bloqueado) se fuerza y el juego sigue.
				stats["forced"] = int(stats.get("forced", 0)) + 1
				if active_set_piece != null:
					active_set_piece.force()
				if not _set_piece_taken():
					_end_set_piece()
		State.PLAYING:
			ctx.match_time += delta
			clock_changed.emit(ctx.match_time)
			_check_out_of_play()
			if state != State.PLAYING:
				return
			if duration_seconds > 0.0 and ctx.match_time >= duration_seconds:
				ctx.input_enabled = false
				_set_state(State.FULL_TIME)
				message.emit("Fin del partido  %d - %d" % [score[0], score[1]], 6.0)
				ctx.emit_event(GameEvent.make(GameEvent.Type.MATCH_END, -1, -1, {"score": score.duplicate()}))
		State.GOAL:
			_state_timer -= delta
			if not _replay_done and replay_after_seconds > 0.0 and goal_celebration_seconds - _state_timer >= replay_after_seconds:
				_replay_done = true
				replay_requested.emit()
			if _state_timer <= 0.0:
				_begin_kickoff(0 if training else 1 - _last_scoring_team)
		State.FULL_TIME:
			pass

var _last_scoring_team: int = 0

# --- Pelota fuera y balon parado ------------------------------------------------------------------------

## Con bandas (OUT_OF_BOUNDS): la pelota que cruza COMPLETAMENTE una linea queda fuera. Banda -> saque de banda para el
## rival del ultimo que la toco; linea de fondo -> corner si la toco el defensor, saque de arco si la toco el atacante.
## Un gol (pelota dentro del arco) nunca cuenta como fuera.
func _check_out_of_play() -> void:
	var cfg: PitchConfig = ctx.pitch.config
	if cfg.boundary_mode != PitchConfig.BoundaryMode.OUT_OF_BOUNDS:
		return
	var ball: Ball = ctx.ball
	if ball.is_held():
		return
	var p: Vector3 = ball.global_position
	var r: float = ball.radius
	var last: int = ball.last_touch_team
	if absf(p.z) > cfg.half_width() + r:
		var team: int = 1 - last if last >= 0 else (0 if p.x > 0.0 else 1)
		var x: float = clampf(p.x, -cfg.half_length() + 0.5, cfg.half_length() - 0.5)
		_begin_set_piece("throw_in", team, Vector3(x, 0.0, signf(p.z) * cfg.half_width()))
		return
	if absf(p.x) > cfg.half_length() + r:
		# Dentro del arco (entre postes y bajo el travesano) decide Goal: es gol, no fuera.
		if absf(p.z) <= cfg.half_goal() + cfg.post_radius and p.y <= cfg.goal_height + cfg.post_radius:
			return
		var side: float = signf(p.x)
		var defending: int = 0 if side < 0.0 else 1   # el equipo 0 defiende el arco -X
		if last == defending:
			_begin_set_piece("corner", 1 - defending, Vector3(side * (cfg.half_length() - 0.3), 0.0, signf(p.z) * (cfg.half_width() - 0.3)))
		else:
			_begin_set_piece("goal_kick", defending, Vector3(side * (cfg.half_length() - 1.6), 0.0, clampf(p.z, -2.5, 2.5)))

## Falta: tiro libre para el equipo del jugador derribado, o penal si fue dentro del area del equipo infractor.
func _on_event(e: GameEvent) -> void:
	if e.type != GameEvent.Type.FOUL or state != State.PLAYING:
		return
	var pos_arr: Array = e.data.get("pos", [0.0, 0.0])
	var pos := Vector3(float(pos_arr[0]), 0.0, float(pos_arr[1]))
	var fouled_team: int = 1 - e.team
	var cfg: PitchConfig = ctx.pitch.config
	var gx: float = cfg.half_length() * (-1.0 if e.team == 0 else 1.0)   # arco que defiende el infractor
	if in_penalty_area(pos, gx, cfg):
		_begin_set_piece("penalty", fouled_team, Vector3(gx - signf(gx) * cfg.penalty_mark_distance, 0.0, 0.0))
	else:
		_begin_set_piece("free_kick", fouled_team, ctx.pitch.clamp_to_pitch(pos, 0.5))

## Area de penal de futsal: a menos de penalty_area_radius de la linea entre postes, del lado de la cancha.
static func in_penalty_area(p: Vector3, goal_x: float, cfg: PitchConfig) -> bool:
	if (p.x - goal_x) * -signf(goal_x) < 0.0:
		return false
	var dz: float = maxf(absf(p.z) - cfg.half_goal(), 0.0)
	return Vector2(p.x - goal_x, dz).length() <= cfg.penalty_area_radius

func _begin_set_piece(kind: String, team: int, pos: Vector3) -> void:
	if training and team == 1 and kind != "goal_kick":
		team = 0
	set_piece_kind = kind
	set_piece_team = team
	set_piece_pos = pos
	active_set_piece = null
	goal_kick_keeper = null
	stats[kind] = int(stats.get(kind, 0)) + 1
	ctx.dead_ball = true
	ctx.restart_taker = null
	ctx.input_enabled = false
	_state_timer = set_piece_setup_seconds
	_set_state(State.SET_PIECE)
	var names := {"throw_in": "Saque de banda", "corner": "Córner", "goal_kick": "Saque de arco", "free_kick": "Tiro libre", "penalty": "¡Penal!"}
	message.emit(names.get(kind, kind), 1.4)
	ctx.emit_event(GameEvent.make(GameEvent.Type.OUT_OF_PLAY if kind in ["throw_in", "corner", "goal_kick"] else GameEvent.Type.SET_PIECE,
		-1, team, {"kind": kind, "pos": [pos.x, pos.z]}))
	set_piece_requested.emit(kind, team, pos)

func _set_piece_taken() -> bool:
	if active_set_piece != null:
		return active_set_piece.result == &"contact" or active_set_piece.result == &"thrown"
	if goal_kick_keeper != null and is_instance_valid(goal_kick_keeper):
		return bool(goal_kick_keeper.get("goal_kick_done"))
	# Sin ejecutor (escena sin jugadores): se reanuda solo.
	return _state_timer <= 0.0

func _end_set_piece() -> void:
	ctx.dead_ball = false
	ctx.restart_taker = null
	active_set_piece = null
	goal_kick_keeper = null
	set_piece_kind = ""
	ctx.input_enabled = true
	_set_state(State.PLAYING)

func is_set_piece() -> bool:
	return state == State.SET_PIECE

func _on_ball_touched(actor: Node) -> void:
	var id_value: Variant = actor.get("actor_id")
	if id_value != null:
		_last_touch_time_by_actor[int(id_value)] = ctx.match_time

func _on_goal(goal: Goal, _ball_pos: Vector3) -> void:
	if state != State.PLAYING and state != State.SET_PIECE:
		return
	# El arco +X recibe el gol de quien ataca +X: el equipo 0.
	var scoring_team: int = 0 if goal.side > 0 else 1
	var ball: Ball = ctx.ball
	var scorer_id: int = -1
	var assist_id: int = -1
	var own_goal: bool = false
	if ball.last_toucher != null:
		var sid: Variant = ball.last_toucher.get("actor_id")
		scorer_id = int(sid) if sid != null else -1
		if ball.last_touch_team != scoring_team and ball.last_touch_team != -1:
			own_goal = true
		elif ball.previous_toucher != null and ball.previous_touch_team == scoring_team and ball.previous_toucher != ball.last_toucher:
			var aid: Variant = ball.previous_toucher.get("actor_id")
			if aid != null and ctx.match_time - float(_last_touch_time_by_actor.get(int(aid), -999.0)) <= assist_window_seconds:
				assist_id = int(aid)
	score[scoring_team] += 1
	_last_scoring_team = scoring_team
	_replay_done = false
	ctx.input_enabled = false
	_state_timer = goal_celebration_seconds
	_set_state(State.GOAL)
	score_changed.emit(score[0], score[1])
	goal_scored.emit(scoring_team, scorer_id, assist_id, own_goal)
	message.emit("¡GOL!" + (" (en contra)" if own_goal else ""), goal_celebration_seconds)
	ctx.emit_event(GameEvent.make(GameEvent.Type.GOAL, scorer_id, scoring_team,
		{"assist": assist_id, "own_goal": own_goal, "score": score.duplicate()}))

func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)

static func format_clock(seconds: float) -> String:
	var total: int = int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]
