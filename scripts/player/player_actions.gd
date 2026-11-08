class_name PlayerActions
extends RefCounted
## Acciones de cuerpo completo de un futbolista de campo con clips del pack y movimiento de raiz: entrada deslizante,
## caidas y levantarse. Mientras dura una accion el jugador no controla su movimiento (la raiz del clip lo mueve) y,
## al terminar, encadena la siguiente (p. ej. barrida -> levantarse). La entrada, el balon y la fisica siguen siendo las
## del juego: el resultado de una barrida depende de donde esta realmente el pie del clip respecto a la pelota.

const SLIDE_CLIPS := [&"soccer_tackle", &"soccer_tackle_2", &"soccer_tackle_3"]
## Carrera para marcar que termina en barrida (sale de parado, gira y corre ~7 m hacia su izquierda). Solo se usa
## cuando el portador pasa por ese lado del defensor: la orientacion que pide el clip coincide con la que ya tiene.
const LONG_SLIDE_CLIP := &"Defender"
const LONG_SLIDE_MAX_YAW_FIX := 22.0
## Caida a toda velocidad (golpe fuerte en sprint): resbala varios metros con la raiz del clip.
const FALL_SPRINT := &"Sprint_To_Backslide"
const FALL_SPRINT_MIN_SPEED := 5.0
## Misma caida en el sitio: sin espacio por delante para resbalar (pared o fin del area exterior) el cuerpo se frena.
const FALL_SPRINT_INPLACE := &"Sprint_To_Backslide_inplace"
const FALL_SPRINT_ROOM := 7.5
## Tendido en el suelo un instante tras un golpe, antes de levantarse.
const FALLEN_IDLE := &"fallen_idle"
const FALLEN_SECONDS := 0.8
## Trastabillar con raiz (pierde un choque de hombros a la carrera).
const STUMBLE_ROOT := &"Jogging_Stumble"
const FALL_TRIP := &"soccer_trip"
const FALL_HIT := &"Shoulder_Hit_And_Fall"
const GET_UP := [&"Getting_Up_3", &"standing_up"]
## Empujon sin caida (contacto leve a poca velocidad) y dolor en el suelo tras una zancadilla.
const SHOVE_CLIPS := [&"Shove_Reaction", &"Shove_Reaction_2"]
const PAIN_CLIP := &"Writhing_In_Pain"
const PAIN_SECONDS := 1.6
## Velocidad minima (m/s) para lanzarse a una barrida y distancia al portador (m) a la que se decide.
const SLIDE_MIN_SPEED := 3.6
const SLIDE_MIN_DIST := 1.0
const SLIDE_MAX_DIST := 3.6
const SLIDE_COOLDOWN := 6.0
const SLIDE_SPEED := 1.7
const FALL_SPEED := 1.7
## La barrida se lanza solo si la punta del pie del clip llega a esta distancia (m) de la pelota prevista en el contacto.
const SLIDE_REACH := 0.55
## Radio (m) entre la punta del pie de la barrida y la pelota / el portador para que cuente el contacto.
const SLIDE_BALL_RADIUS := 0.65
const SLIDE_BODY_RADIUS := 0.9

var owner: Footballer
var motion := ActionMotion.new()
var kind: StringName = &""
var rng := RandomNumberGenerator.new()
var _chain: Array[Dictionary] = []
var _slide: Dictionary = {}
var _slide_cd: float = 0.0
## Testigo del arbitro de la accion en curso (0 = ninguna).
var _token: int = 0
var stats := {"slides": 0, "slide_wins": 0, "slide_fouls": 0, "falls": 0}
const LOCOMOTION_TRANSITIONS: Array[StringName] = [&"start", &"step_stand", &"run_change", &"turn_stop"]

func _init(o: Footballer) -> void:
	owner = o
	rng.randomize()

## Corta cualquier accion en curso (saque, reinicio, gol) y libera su lugar en el arbitro, pose incluida.
func reset() -> void:
	stop("reinicio")

## Corta la accion en curso por una razon del juego (pelota cerca, toque perdido, reinicio): raiz, encadenados, movimiento
## con pelota y pose. Nada de la accion cortada sigue moviendo al jugador.
func stop(why: String) -> void:
	var t: int = _token
	interrupt()
	if owner.arbiter != null:
		owner.arbiter.release(t, why)

## Corte interno (lo llama tambien el arbitro cuando otra accion de mas nivel la sustituye): sin tocar el arbitro.
func interrupt() -> void:
	if kind == &"ball_move":
		owner.ball_handler.json_move.cancel()
	motion.stop()
	_chain.clear()
	_slide = {}
	kind = &""
	_token = 0

## true mientras una accion (o su encadenado) controla el cuerpo.
func active() -> bool:
	return motion.active or not _chain.is_empty()

func _can_play() -> bool:
	return owner.visual != null and owner.visual.uses_pack and not owner.visual.is_placeholder

## true si una accion de este tipo podria empezar ahora: la decide el arbitro por nivel (sin arbitro, como antes: nada en
## curso). Las condiciones propias de cada accion (clips disponibles, enfriamientos) las sigue mirando quien llama.
func can_start(k: StringName) -> bool:
	if owner.arbiter == null:
		return not active()
	return owner.arbiter.can_start(ActionArbiter.level_for_action(k))

func react_to_ball_impact(ball: Ball) -> bool:
	if owner.ctx == null or owner.ctx.ball != ball or ball.linear_velocity.length() < 2.0 or owner.ball_handler.is_kick_in_progress():
		return false
	var offset: Vector3 = ball.global_position - owner.global_position
	if offset.y < 1.25 or offset.y > 1.95 or KickModel.flat(offset).length() > 0.65 or offset.dot(owner.locomotion.forward()) < -0.05:
		return false
	var id := &"jn_nis_misc_0450"
	if not start(&"stumble", id):
		return false
	stats["ball_face_reactions"] = int(stats.get("ball_face_reactions", 0)) + 1
	return true

## Transiciones antes fuera de las franjas de giro de 90/180 grados: arranque, paso de parada y giro frenando.
## Se comparan por separado el desplazamiento pedido y la orientacion del cuerpo (incluye retroceder mirando al rival).
func transition_score(id: StringName, desired_dir: Vector3, magnitude: float) -> float:
	var m: Dictionary = PackLibrary.meta(id)
	var role := StringName(String(m.get("role", "")))
	if not LOCOMOTION_TRANSITIONS.has(role) or not can_start(&"turn") or owner.ball_handler.is_dribbling() \
			or owner.has_incoming_pass() or not is_inf(owner.ball_handler.incoming_ball_eta()) or owner.ball_handler.is_kick_in_progress() or owner.ball_handler._pending_action != &"":
		return _no(id, "rol o estado del jugador (pelota, pase entrante, golpeo u otra accion)")
	if owner.ctx.ball == null or KickModel.flat(owner.ctx.ball.global_position - owner.global_position).length() < 2.0:
		return _no(id, "pelota a menos de 2 m")
	if not _lands_inside(id):
		return _no(id, "la raiz termina fuera del area de juego")
	if not _keeps_set_piece_clear(id):
		return _no(id, "la raiz entra en la zona del balon parado")
	var loco: Locomotion = owner.locomotion
	var dv: float = absf(loco.speed - float(m.get("v_in", 0.0)))
	if dv > 1.0:
		return _no(id, "carrera de entrada %.1f m/s frente a %.1f m/s" % [float(m.get("v_in", 0.0)), loco.speed])
	var moving: bool = magnitude >= 0.2 and desired_dir.length_squared() > 0.01
	if (role == &"step_stand" and moving) or (role != &"step_stand" and not moving):
		return _no(id, "rol %s no corresponde a %s" % [role, "moverse" if moving else "pararse"])
	if role == &"start" and (loco.speed >= 1.3 or magnitude < 0.5):
		return _no(id, "arranque: ya en marcha o joystick debil")
	if role == &"run_change" and (loco.speed < 0.8 or magnitude < 0.5):
		return _no(id, "cambio de ritmo: parado o joystick debil")
	if role == &"turn_stop" and (magnitude > 0.5 or loco.speed < 1.0):
		return _no(id, "giro frenando: joystick firme o parado")
	var displacement: Vector2 = m.get("root_total", Vector2.ZERO)
	var world_displacement: Vector3 = loco.forward() * displacement.x + loco.right() * displacement.y
	var want: Vector3 = desired_dir if moving else loco.velocity
	if world_displacement.length() > 0.08 and want.length() > 0.05 and world_displacement.normalized().dot(want.normalized()) < 0.65:
		return _no(id, "la raiz va hacia otro lado que el pedido")
	var measured: float = ActionMotion.heading_rel(m.get("heading_path", PackedFloat32Array()), float(m.get("duration", 1.0)))
	var face: Vector3 = loco.face_override if loco.face_override.length_squared() > 0.01 else desired_dir
	var needed: float = wrapf(Locomotion.yaw_from_dir(face.normalized()) - loco.yaw, -PI, PI) if moving else 0.0
	var error: float = absf(wrapf(needed - measured, -PI, PI))
	if moving and error > deg_to_rad(25.0):
		return _no(id, "rumbo del clip a %.0f grados del pedido" % rad_to_deg(error))
	if not _trace_dec.is_empty():
		AnimTrace.cand(_trace_dec, id, "", {"v_in": loco.speed, "v_clip": float(m.get("v_in", 0.0)), "orient_start": rad_to_deg(loco.yaw),
			"orient_target": rad_to_deg(loco.yaw + needed), "angular_error_deg": rad_to_deg(error), "cost_total": dv + error,
			"cost_breakdown_json": {"carrera": dv, "rumbo_rad": error}})
	return dv + error

## Traza (AnimTrace, solo depuracion): decision de transicion en curso y descarte de un candidato (devuelve INF).
var _trace_dec: Dictionary = {}

func _no(id: StringName, why: String) -> float:
	if not _trace_dec.is_empty():
		AnimTrace.cand(_trace_dec, id, why)
	return INF



func request_locomotion_transition(id: StringName, desired_dir: Vector3, magnitude: float) -> bool:
	if is_inf(transition_score(id, desired_dir, magnitude)):
		return false
	return start(&"turn", id)

func try_locomotion_transition(desired_dir: Vector3, magnitude: float) -> bool:
	if owner.visual != null and owner.visual.current_action != &"":
		return false
	if owner.ctx != null and owner.ctx.ball != null:
		var rel: Vector3 = KickModel.flat(owner.ctx.ball.global_position - owner.global_position)
		var incoming: Vector3 = KickModel.flat(owner.ctx.ball.linear_velocity - owner.velocity)
		var eta: float = -rel.dot(incoming) / maxf(incoming.length_squared(), 0.001)
		if eta > 0.0 and eta < BallHandler.PENDING_FIRST_TIME_MAX and (rel + incoming * eta).length() < owner.ball_handler.possession_radius():
			return false
	if not can_start(&"turn") or owner.ball_handler.is_dribbling() or owner.has_incoming_pass() or not is_inf(owner.ball_handler.incoming_ball_eta()) \
			or owner.ball_handler.is_kick_in_progress() or owner.ball_handler._pending_action != &"":
		return false
	if magnitude < 0.2 and owner.locomotion.speed < 0.2:
		return false
	var pool: Array[StringName] = []
	var weights: Array[float] = []
	var total: float = 0.0
	_trace_dec = AnimTrace.begin(owner, &"transition", &"PlayerActions.try_locomotion_transition", "joystick %.2f" % magnitude) if AnimTrace.enabled else {}
	for role in LOCOMOTION_TRANSITIONS:
		for id in PackLibrary.by_role(role):
			var score: float = transition_score(id, desired_dir, magnitude)
			if is_inf(score):
				continue
			var weight: float = 1.0 / (0.1 + score)
			pool.append(id)
			weights.append(weight)
			total += weight
	if pool.is_empty():
		if not _trace_dec.is_empty():
			AnimTrace.commit(_trace_dec, &"", {}, "rejected", "ninguna transicion compatible")
			_trace_dec = {}
		return false
	var dec: Dictionary = _trace_dec
	_trace_dec = {}
	var pick: float = rng.randf() * total
	var chosen: StringName = pool.back()
	for i in pool.size():
		pick -= weights[i]
		if pick <= 0.0:
			chosen = pool[i]
			break
	var ok: bool = request_locomotion_transition(chosen, desired_dir, magnitude)
	if not dec.is_empty():
		AnimTrace.commit(dec, chosen, {}, "accepted" if ok else "rejected", "" if ok else "arbitro o clip no reproducible")
	return ok

## Empieza una accion. chain: [{kind, clip, speed, cut}] que se encadenan al terminar. El arbitro decide si entra (por
## nivel: una caida corta un giro o un movimiento con pelota; un giro no corta una caida).
func start(k: StringName, clip: StringName, speed: float = 1.0, cut: float = -1.0, chain: Array = [], start_at: float = 0.0) -> bool:
	if not _can_play() or not PackLibrary.has_clip(clip):
		return false
	if not _begin(k, clip, speed, cut, start_at, false):
		return false
	owner.ball_handler.abort_kick()
	owner.ball_handler.cancel_charge()
	owner.ball_handler.drag_back.cancel("accion")
	owner.ball_handler.ball_turn.cancel("accion")
	for c in chain:
		_chain.append(c)
	return true

## Arranca un clip de la accion: el primero pide el control al arbitro (y puede ser rechazado); los encadenados siguen con
## el mismo testigo.
func _begin(k: StringName, clip: StringName, speed: float, cut: float, start_at: float = 0.0, chained: bool = false) -> bool:
	if chained:
		if owner.arbiter == null or not owner.arbiter.handover(_token, k, clip):
			return false
		owner.visual.play_pack_clip(clip, speed, start_at, cut)
	else:
		var t: int = owner.arbiter.play(k, ActionArbiter.level_for_action(k), &"PlayerActions", clip, speed, start_at, cut) if owner.arbiter != null else 0
		if t == 0:
			return false
		_token = t
		_chain.clear()
	kind = k
	motion.start(clip, speed, start_at, cut)
	# Clip con rumbo propio: la orientacion de su inicio es la de ahora menos lo que ya giro hasta start_at.
	motion.yaw0 = owner.locomotion.yaw - motion.heading_at(start_at)
	owner.ball_handler.lockout = maxf(owner.ball_handler.lockout, 0.3)
	return true

## Modo 4: movimiento de cuerpo entero con rumbo propio (giro, giro con pelota, regate) desde `start_at` s del clip. Igual
## que start pero sin cortar las acciones de pelota que lo piden (JsonBallMove maneja la pelota durante el clip).
## cut: segundos de clip tras los que se corta (toque orientado de JsonBallMove); -1 entero.
func start_move(k: StringName, clip: StringName, speed: float = 1.0, start_at: float = 0.0, cut: float = -1.0) -> bool:
	if not _can_play() or not PackLibrary.has_clip(clip):
		return false
	return _begin(k, clip, speed, cut, start_at, false)

## Avanza un paso de fisica moviendo el cuerpo con la raiz del clip. Devuelve true si la accion se ocupo del paso.
func tick(delta: float) -> bool:
	_slide_cd = maxf(_slide_cd - delta, 0.0)
	_tackle_cd = maxf(_tackle_cd - delta, 0.0)
	_skill_cd = maxf(_skill_cd - delta, 0.0)
	if not active():
		return false
	var rv: Vector2 = motion.step(delta)
	var loco: Locomotion = owner.locomotion
	var wv: Vector3 = loco.forward() * rv.x + loco.right() * rv.y
	if motion.heading_driven:
		# Raiz en el marco del inicio del clip y el cuerpo girando con el rumbo del clip (giros, giros con pelota).
		var f0: Vector3 = Locomotion.dir_from_yaw(motion.yaw0)
		wv = f0 * rv.x + Vector3(-f0.z, 0.0, f0.x) * rv.y + motion.extra_velocity
		var new_yaw: float = motion.yaw0 + motion.heading_at(motion.t)
		loco.turn_rate = wrapf(new_yaw - loco.yaw, -PI, PI) / maxf(delta, 0.001)
		loco.yaw = new_yaw
	# Modo 4: la raiz de una caida o barrida puede llevar varios metros; el cuerpo no se sale del area de juego (+0.8 m).
	if PackLibrary.json_mode() and owner.ctx != null and owner.ctx.pitch != null:
		var cfg: PitchConfig = owner.ctx.pitch.config
		var nxt: Vector3 = owner.global_position + wv * delta
		if absf(nxt.x) > cfg.half_length() + 0.8 and signf(wv.x) == signf(nxt.x):
			wv.x = 0.0
		if absf(nxt.z) > cfg.half_width() + 0.8 and signf(wv.z) == signf(nxt.z):
			wv.z = 0.0
	owner.velocity.x = wv.x
	owner.velocity.z = wv.z
	if owner.is_on_floor():
		owner.velocity.y = -0.5
	else:
		owner.velocity.y -= 9.81 * delta
	owner.move_and_slide()
	loco.velocity = Vector3(owner.velocity.x, 0.0, owner.velocity.z)
	loco.speed = loco.velocity.length()
	owner.rotation.y = loco.yaw
	owner.ball_handler.lockout = maxf(owner.ball_handler.lockout, 0.15)
	if not _slide.is_empty() and motion.elapsed >= float(_slide["t"]):
		_resolve_slide()
	if kind == &"skill":
		_skill_touches()
	if kind == &"ball_move":
		owner.ball_handler.json_move.step(motion.t, delta)
		if _token == 0:
			return true   # el movimiento con pelota se corto en este paso (toque perdido): ya libero su lugar
	if not motion.active:
		if not _chain.is_empty():
			var nxt: Dictionary = _chain.pop_front()
			if not _begin(nxt.get("kind", &"chain"), nxt["clip"], float(nxt.get("speed", 1.0)), float(nxt.get("cut", -1.0)), 0.0, true):
				_chain.clear()
		if not motion.active:
			var ended: StringName = kind
			var t: int = _token
			kind = &""
			_token = 0
			if motion.heading_driven or ended == &"turn":
				# Giros y movimientos con pelota terminan en marcha: el cuerpo sigue con la velocidad de salida del clip.
				loco.velocity = Vector3(wv.x, 0.0, wv.z)
				loco.speed = loco.velocity.length()
				loco.turn_rate = 0.0
			else:
				loco.stop()
				owner.velocity = Vector3.ZERO
			if ended == &"ball_move":
				owner.ball_handler.json_move.finish()
			if owner.arbiter != null:
				owner.arbiter.release(t, "fin")
	return true

# --- Barrida ------------------------------------------------------------------------------------------------

## Intenta lanzarse a una barrida contra el portador. Planifica como el golpeo: para cada clip (y su espejo) calcula
## donde estara la punta del pie en su instante de contacto y donde estara la pelota; solo se lanza si llegan.
## Devuelve true si la inicio (entonces el robo normal no se hace).
func try_slide_tackle(carrier: Footballer, forced: bool = false) -> bool:
	if carrier == null or not can_start(&"slide") or _slide_cd > 0.0 or not _can_play():
		return false
	var loco: Locomotion = owner.locomotion
	var to_c: Vector3 = KickModel.flat(carrier.global_position - owner.global_position)
	var dist: float = to_c.length()
	if loco.stamina < 0.12 or dist < SLIDE_MIN_DIST:
		return false
	var ball: Ball = owner.ctx.ball
	var best: Dictionary = {}
	var best_d: float = INF
	var fast: bool = loco.speed >= SLIDE_MIN_SPEED and dist <= SLIDE_MAX_DIST and KickModel.angle_between_deg(loco.forward(), to_c) <= 55.0
	if fast:
		for base in SLIDE_CLIPS:
			for variant in [base, StringName(String(base) + "_mirror")]:
				var c: Dictionary = _slide_candidate(variant, loco.yaw, ball, 0.0)
				if not c.is_empty() and float(c["d"]) < best_d:
					best_d = float(c["d"])
					best = c
	# Carrera larga con barrida (Defender): el portador pasa por el costado del defensor, a 4-8 m.
	if best.is_empty() and not forced and dist > SLIDE_MAX_DIST and dist < 8.5 and PackLibrary.has_clip(LONG_SLIDE_CLIP):
		var c2: Dictionary = _slide_candidate(LONG_SLIDE_CLIP, loco.yaw, ball, LONG_SLIDE_MAX_YAW_FIX)
		if not c2.is_empty() and float(c2["d"]) <= SLIDE_REACH:
			best = c2
			best_d = float(c2["d"])
	if best.is_empty():
		return false
	# La persona decide cuando barrer (boton ENTRADA): se lanza aunque no llegue del todo (puede fallar o hacer falta).
	if forced:
		if best_d > SLIDE_REACH * 3.0:
			return false
	else:
		if best_d > SLIDE_REACH:
			return false
		# No siempre: la ventana util dura unos pasos de fisica y cada uno tiene ~8 % de lanzarse.
		if rng.randf() > 0.08:
			return false
	loco.yaw = float(best["yaw"])
	owner.rotation.y = loco.yaw
	var getup: StringName = &"standing_up"
	if not start(&"slide", best["clip"], SLIDE_SPEED, -1.0, [{"kind": &"getup", "clip": getup, "speed": FALL_SPEED}]):
		return false
	_slide_cd = SLIDE_COOLDOWN
	_slide = {"carrier": carrier, "t": best["t"], "key": best["key"], "clip": best["clip"]}
	stats["slides"] += 1
	if best["clip"] == LONG_SLIDE_CLIP:
		stats["long_slides"] = int(stats.get("long_slides", 0)) + 1
	return true

## Mejor pie de un clip de barrida para alcanzar la pelota prevista. yaw_fix: grados que se permite reorientar el cuerpo
## al empezar para que la trayectoria del clip apunte a la pelota (0 = con la orientacion actual).
## Devuelve {clip, key, t, d, yaw} o {}.
func _slide_candidate(variant: StringName, yaw: float, ball: Ball, yaw_fix: float) -> Dictionary:
	if not PackLibrary.has_clip(variant):
		return {}
	var toes: Dictionary = PackLibrary.meta(variant).get("paths", {})
	var best: Dictionary = {}
	for key in ["toe_r", "toe_l"]:
		if not toes.has(key):
			continue
		var tau: float = KeeperPlanner.peak_speed_time(variant, key)
		var t_c: float = tau / SLIDE_SPEED
		var bp: Vector3 = ball.global_position + Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z) * t_c
		var use_yaw: float = yaw
		if yaw_fix > 0.0:
			# Orientacion que pone el pie del clip sobre la pelota: yaw = rumbo a la pelota + angulo del pie en el clip.
			var h: Vector3 = (toes[key] as PackedVector3Array)[clampi(int(tau * 30.0), 0, (toes[key] as PackedVector3Array).size() - 1)]
			var need: float = Locomotion.yaw_from_dir(KickModel.flat(bp - owner.global_position).normalized()) + atan2(h.z, h.x)
			if absf(wrapf(need - yaw, -PI, PI)) > deg_to_rad(yaw_fix):
				continue
			use_yaw = need
		var foot: Vector3 = KeeperPlanner.path_world(variant, key, int(tau * 30.0), owner.global_position, use_yaw)
		var d: float = Vector2(foot.x - bp.x, foot.z - bp.z).length()
		if best.is_empty() or d < float(best["d"]):
			best = {"clip": variant, "key": key, "t": t_c, "d": d, "yaw": use_yaw}
	return best

# --- Entrada de pie y carga con el hombro (boton ENTRADA) ---------------------------------------------------------

## Entrada pedida por la persona. Segun la situacion: entrada de pie (pelota al alcance), carga con el hombro (corriendo
## a la par del portador) o barrida (a la carrera, con el portador a unos metros). Fuera de alcance es una entrada al
## aire: el defensor se compromete, pierde velocidad y queda un instante sin poder volver a intentarlo.
## Devuelve &"stand", &"shoulder", &"slide", &"whiff" o &"" (no hizo nada: ya estaba en una accion).
func tackle_request(carrier: Footballer) -> StringName:
	if not can_start(&"slide") or _tackle_cd > 0.0:
		return &""
	var ball: Ball = owner.ctx.ball
	if ball == null or ball.is_held():
		return &""
	_tackle_cd = 0.7
	var bh: BallHandler = owner.ball_handler
	var loco: Locomotion = owner.locomotion
	var to_ball: Vector3 = KickModel.flat(ball.global_position - owner.global_position)
	if carrier != null and _alongside(carrier):
		shoulder_charge(carrier)
		return &"shoulder"
	if to_ball.length() <= Tuning.assist.press_tackle_range * 1.2 and ball.global_position.y < 0.6 \
			and KickModel.angle_between_deg(loco.forward(), to_ball) < 100.0:
		if owner.visual != null:
			if PackLibrary.json_mode():
				tackle_gesture(carrier)
			else:
				owner.visual.start_kick(0.12, 0.45, 1 if to_ball.dot(loco.right()) >= 0.0 else -1)
		var won: bool = bh.attempt_tackle(carrier)
		# Entrar por detras derriba al portador: falta.
		if not won and carrier != null and _from_behind(carrier) and rng.randf() < 0.45:
			_commit_foul(carrier, false)
		owner.tackled.emit(won)
		return &"stand"
	if carrier != null and loco.speed >= SLIDE_MIN_SPEED * 0.8 and try_slide_tackle(carrier, true):
		return &"slide"
	# Entrada al aire.
	loco.velocity *= 0.45
	bh.lockout = maxf(bh.lockout, 0.45)
	owner.ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_FAILED, owner.actor_id, owner.team, {"victim": carrier.actor_id if carrier != null else -1, "whiff": true}))
	return &"whiff"

var _tackle_cd: float = 0.0

## Modo 4: el gesto de la entrada de pie (uno de los clips de entrada parada, del lado de la pelota). Solo presentacion: el
## robo lo decide attempt_tackle.
func tackle_gesture(carrier: Footballer) -> void:
	if not PackLibrary.json_mode() or owner.arbiter == null:
		return
	var c: StringName = JsonCatalog.situation_clip(&"tackle_stand", owner.actor_id)
	if c == &"":
		return
	var ball: Ball = owner.ctx.ball
	if ball != null and KickModel.flat(ball.global_position - owner.global_position).dot(owner.locomotion.right()) < 0.0 and PackLibrary.has_clip(StringName(String(c) + "_mirror")):
		c = StringName(String(c) + "_mirror")
	# Gesto en el sitio: el arbitro lo rechaza con otra accion en curso o con el cuerpo corriendo mas que el clip.
	owner.arbiter.play(&"tackle_gesture", ActionArbiter.Level.GESTURE, &"PlayerActions", c, 1.35, 0.0, 0.8, true)

## Modo 4: disputa de quien presiona pegado al portador sin llegar a entrar (forcejeo con el cuerpo y amago de pierna,
## clips «jostle» y entradas de pie del zip): la presion siempre se ve, como en First Touch. Solo presentacion.
func press_gesture(carrier: Footballer) -> void:
	if not PackLibrary.json_mode() or owner.arbiter == null or carrier == null:
		return
	var c: StringName = JsonCatalog.situation_clip(&"press_duel", owner.actor_id)
	if c == &"":
		return
	if KickModel.flat(carrier.global_position - owner.global_position).dot(owner.locomotion.right()) < 0.0 and PackLibrary.has_clip(StringName(String(c) + "_mirror")):
		c = StringName(String(c) + "_mirror")
	if owner.arbiter.play(&"press_gesture", ActionArbiter.Level.GESTURE, &"PlayerActions", c, 1.2, 0.0, 0.9, true) != 0:
		stats["press_gestures"] = int(stats.get("press_gestures", 0)) + 1

## true si el defensor corre a la par del portador (hombro con hombro): mismos sentidos, cerca y de costado.
func _alongside(carrier: Footballer) -> bool:
	var d: Vector3 = KickModel.flat(carrier.global_position - owner.global_position)
	if d.length() > 1.25 or d.length() < 0.35:
		return false
	if owner.locomotion.speed < 2.8 or carrier.locomotion.speed < 2.8:
		return false
	var cf: Vector3 = carrier.locomotion.forward()
	if owner.locomotion.forward().dot(cf) < 0.7:
		return false
	return absf(d.dot(Vector3(-cf.z, 0.0, cf.x))) > 0.3 and absf(d.dot(cf)) < 0.9

func _from_behind(carrier: Footballer) -> bool:
	var d: Vector3 = KickModel.flat(owner.global_position - carrier.global_position)
	return d.length() > 0.01 and d.normalized().dot(carrier.locomotion.forward()) < -0.5

## Carga legal con el hombro: gana el mas fuerte y equilibrado (con azar). El que pierde trastabilla (clip con raiz) y
## el defensor que gana se queda con la pelota con un toque. Nadie se teletransporta: el resto lo hace la fisica.
func shoulder_charge(carrier: Footballer) -> bool:
	var mine: float = owner.attributes.factor("strength", 0.5) * owner.attributes.factor("balance", 0.3) * lerpf(0.9, 1.1, owner.locomotion.speed / 7.0)
	var theirs: float = carrier.attributes.factor("strength", 0.5) * carrier.attributes.factor("balance", 0.3) * lerpf(0.9, 1.1, carrier.locomotion.speed / 7.0)
	# El portador conduce: protege mejor si la pelota esta pegada.
	if carrier.ball_handler.ball_distance() < 0.7:
		theirs *= 1.1
	var p_win: float = clampf(0.5 + (mine - theirs) * 1.4, 0.15, 0.8)
	var won: bool = rng.randf() < p_win
	stats["shoulder"] = int(stats.get("shoulder", 0)) + 1
	var away: Vector3 = KickModel.flat(carrier.global_position - owner.global_position)
	if won:
		stats["shoulder_wins"] = int(stats.get("shoulder_wins", 0)) + 1
		carrier.actions.stumble_root(away)
		carrier.ball_handler.lockout = maxf(carrier.ball_handler.lockout, 0.7)
		owner.ball_handler.touch_timer = 0.0
		owner.ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_WON, owner.actor_id, owner.team, {"victim": carrier.actor_id, "shoulder": true}))
	else:
		stumble_root(-away)
		owner.ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_FAILED, owner.actor_id, owner.team, {"victim": carrier.actor_id, "shoulder": true}))
	owner.tackled.emit(won)
	return won

## Trastabilla con el clip con raiz (pierde el equilibrio a la carrera y se recupera sin caer).
func stumble_root(from_dir: Vector3 = Vector3.ZERO) -> void:
	if not _can_play() or not can_start(&"stumble"):
		return
	var clip: StringName = STUMBLE_ROOT
	if PackLibrary.json_mode() and from_dir != Vector3.ZERO:
		# Modo 4: un trastabillon convertido que va hacia donde lo llevan la inercia y el empujon (sin caer).
		var pool: Array[StringName] = []
		for id in PackLibrary.by_role(&"stumble"):
			if not String(id).ends_with("_mirror"):
				pool.append(id)
		var js: StringName = _directed_pick(pool, from_dir)
		if js != &"":
			clip = js
	if start(&"stumble", clip, 1.15, 0.9):
		stats["stumbles"] = int(stats.get("stumbles", 0)) + 1

## Falta del defensor sobre el portador: el portador cae y el partido la sanciona (tiro libre o penal).
func _commit_foul(carrier: Footballer, slide: bool) -> void:
	stats["fouls"] = int(stats.get("fouls", 0)) + 1
	carrier.actions.suffer_contact(&"trip", KickModel.flat(carrier.global_position - owner.global_position))
	owner.ctx.emit_event(GameEvent.make(GameEvent.Type.FOUL, owner.actor_id, owner.team, {"victim": carrier.actor_id,
		"slide": slide, "pos": [carrier.global_position.x, carrier.global_position.z]}))

func _resolve_slide() -> void:
	var s: Dictionary = _slide
	_slide = {}
	var ctx: MatchContext = owner.ctx
	var ball: Ball = ctx.ball
	var carrier: Footballer = s["carrier"]
	var toe: Vector3 = KeeperPlanner.path_world_at_body(s["clip"], s["key"], int(motion.t * 30.0), owner.global_position, owner.locomotion.yaw)
	var d_ball: float = toe.distance_to(ball.global_position)
	var d_body: float = Vector2(toe.x - carrier.global_position.x, toe.z - carrier.global_position.z).length() if is_instance_valid(carrier) else INF
	var won: bool = false
	if not ball.is_held() and d_ball <= SLIDE_BALL_RADIUS:
		won = owner.ball_handler.attempt_tackle(carrier)
	elif d_body <= SLIDE_BODY_RADIUS:
		# Llego al jugador y no a la pelota: falta; el portador cae.
		stats["slide_fouls"] += 1
		ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_FAILED, owner.actor_id, owner.team, {"victim": carrier.actor_id, "foul": true, "slide": true}))
		_commit_foul(carrier, true)
	else:
		ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_FAILED, owner.actor_id, owner.team, {"victim": carrier.actor_id if is_instance_valid(carrier) else -1, "slide": true, "miss": true}))
		# La barrida paso cerca sin tocarlo: el portador la salta (clip de esquivar, modo 4).
		if is_instance_valid(carrier) and d_body <= AVOID_RADIUS:
			carrier.actions.avoid_tackle(KickModel.flat(carrier.global_position - owner.global_position))
	if won:
		stats["slide_wins"] += 1
		# Un robo con barrida a veces derriba al portador.
		if rng.randf() < 0.35:
			carrier.actions.suffer_contact(&"hit", KickModel.flat(carrier.global_position - owner.global_position))
	owner.tackled.emit(won)

## Distancia (m) entre el pie de la barrida fallida y el portador por debajo de la cual el portador la salta.
const AVOID_RADIUS := 1.2

## Modo 4: esquivar una barrida que no llego (clips «avoid»: saltos por encima de una entrada o de la pelota). Nivel de cuerpo
## (corta un movimiento con pelota; la pelota sigue su camino y el jugador la retoma al caer). El clip con la carrera de
## entrada mas parecida; el espejo si la barrida viene por la izquierda. false si no hay clip o no puede.
func avoid_tackle(from_dir: Vector3) -> bool:
	if not PackLibrary.json_mode() or not _can_play() or not can_start(&"stumble"):
		return false
	var best: StringName = &""
	var best_dv: float = INF
	var mirror: bool = from_dir.dot(owner.locomotion.right()) < 0.0
	for id in PackLibrary.by_role(&"avoid"):
		if String(id).ends_with("_mirror"):
			continue
		var cid: StringName = StringName(String(id) + "_mirror") if mirror and PackLibrary.has_clip(StringName(String(id) + "_mirror")) else id
		if not _lands_inside(cid):
			continue
		var dv: float = absf(float(PackLibrary.meta(id).get("v_in", 0.0)) - owner.locomotion.speed) + rng.randf() * 0.2
		if dv < best_dv:
			best_dv = dv
			best = cid
	if best == &"":
		return false
	if not start(&"stumble", best, 1.0, -1.0):
		return false
	stats["avoids"] = int(stats.get("avoids", 0)) + 1
	return true

# --- Recibir un contacto (caidas) --------------------------------------------------------------------------

## El jugador cae por un contacto: "trip" (zancadilla), "hit" (golpe de hombro). Luego se levanta solo.
func suffer_contact(k: StringName, from_dir: Vector3) -> void:
	# La caida tiene el nivel mas alto: corta un giro, un movimiento con pelota o una barrida en curso (antes una falta
	# sobre un jugador en un giro con pelota no lo derribaba). No corta otra caida ni el levantarse.
	if not _can_play() or not can_start(&"fall"):
		return
	var clip: StringName = FALL_TRIP if k == &"trip" else FALL_HIT
	var shove: bool = false
	var sprint_fall: bool = false
	if k == &"hit" and owner.locomotion.speed >= FALL_SPRINT_MIN_SPEED and PackLibrary.has_clip(FALL_SPRINT):
		# A toda velocidad el golpe lo tira y resbala por el piso (raiz del clip: ~7 m a velocidad de sprint).
		clip = FALL_SPRINT
		sprint_fall = true
		# Sin sitio para resbalar ~7 m: version en el sitio (el cuerpo se queda donde cae).
		var room: float = _room_ahead()
		if room < FALL_SPRINT_ROOM and PackLibrary.has_clip(FALL_SPRINT_INPLACE):
			clip = FALL_SPRINT_INPLACE
	if owner.locomotion.speed < 3.0 and not sprint_fall:
		# Parado o caminando no hay carrera que arrastre la caida: caidas cortas (raiz de 0.7-1 m) o, si fue un golpe
		# leve, un simple empujon del que se recupera sin llegar al suelo.
		if k == &"hit" and rng.randf() < 0.4:
			clip = SHOVE_CLIPS[rng.randi() % SHOVE_CLIPS.size()]
			shove = true
		else:
			clip = [&"Falling_Down", &"Sweep_Fall"][rng.randi() % 2]
	var directed: bool = false
	if PackLibrary.json_mode() and not shove:
		# Modo 4: una caida convertida segun la carrera, el sitio por delante y hacia donde empujan la inercia y el contacto
		# (ya decide tambien el espejo).
		var jf: StringName = _json_fall(owner.locomotion.speed, from_dir)
		if jf != &"":
			clip = jf
			directed = true
	var side: float = from_dir.dot(owner.locomotion.right())
	if not directed and side < 0.0 and PackLibrary.has_clip(StringName(String(clip) + "_mirror")):
		clip = StringName(String(clip) + "_mirror")
	var getup: StringName = GET_UP[rng.randi() % GET_UP.size()]
	var lie_ok: bool = true
	if PackLibrary.json_mode():
		# Se levanta desde la misma postura en que quedo tendido (boca arriba, boca abajo o de costado).
		var lie: String = String(PackLibrary.meta(clip).get("lie", ""))
		var jg: StringName = _json_getup(lie)
		if jg != &"":
			getup = jg
		lie_ok = lie == "" or String(PackLibrary.meta(FALLEN_IDLE).get("lie", "")) == lie
	var chain: Array = [] if shove else [{"kind": &"getup", "clip": getup, "speed": FALL_SPEED}]
	if k == &"trip" and PackLibrary.has_clip(PAIN_CLIP):
		# Tras una zancadilla se queda un momento en el suelo con dolor antes de levantarse.
		chain.push_front({"kind": &"pain", "clip": PAIN_CLIP, "speed": 1.0, "cut": PAIN_SECONDS})
	elif not shove and PackLibrary.has_clip(FALLEN_IDLE) and lie_ok:
		# Tras un golpe queda tendido un instante (aturdido) antes de levantarse.
		chain.push_front({"kind": &"down", "clip": FALLEN_IDLE, "speed": 1.0, "cut": FALLEN_SECONDS})
	var fell: bool = start(&"fall", clip, FALL_SPEED, -1.0, chain)
	if not _trace_fall.is_empty():
		AnimTrace.commit(_trace_fall, PackLibrary.resolve(clip), {"context": String(k)}, "accepted" if fell else "rejected", "" if fell else "arbitro o clip no reproducible")
		_trace_fall = {}
	if fell:
		stats["falls"] += 1
		owner.ctx.emit_event(GameEvent.make(GameEvent.Type.TURNOVER, owner.actor_id, owner.team, {"reason": String(k)}))

## Modo 4: una caida convertida con un recorrido acorde a la carrera (a sprint resbala; parado, cae en el sitio), que entra
## en el sitio libre por delante y que va hacia donde la llevan la inercia y el contacto (`from_dir`: del rival al jugador).
## Devuelve el clip ya con el espejo que corresponda; &"" si no hay.
func _json_fall(speed: float, from_dir: Vector3 = Vector3.ZERO) -> StringName:
	var room: float = _room_ahead()
	var lo: float = 1.5 if speed >= FALL_SPRINT_MIN_SPEED else (DIRECTED_IN_PLACE if speed >= 3.0 else 0.0)
	var hi: float = minf(1.3 if speed < 3.0 else 4.0, room - 0.5) if speed < FALL_SPRINT_MIN_SPEED else minf(8.0, room - 0.5)
	var pool: Array[StringName] = []
	_trace_fall = AnimTrace.begin(owner, &"fall", &"PlayerActions._json_fall", "%.1f m/s, sitio %.1f m" % [speed, room]) if AnimTrace.enabled else {}
	for role in [&"fall", &"fall_hit", &"trip"]:
		for id in PackLibrary.by_role(role):
			if String(id).ends_with("_mirror"):
				continue
			var m: Dictionary = PackLibrary.meta(id)
			var travel: float = (m.get("root_total", Vector2.ZERO) as Vector2).length()
			if travel >= lo and travel <= maxf(hi, 0.4) and m.has("lie"):
				pool.append(id)
			elif not _trace_fall.is_empty():
				AnimTrace.cand(_trace_fall, id, "sin postura final medida (lie)" if not m.has("lie") else "recorrido %.1f m fuera de %.1f-%.1f m" % [travel, lo, maxf(hi, 0.4)])
	return _directed_pick(pool, from_dir)

## Traza (AnimTrace, solo depuracion): decision de caida en curso (la cierra suffer_contact).
var _trace_fall: Dictionary = {}

## Peso (m/s equivalentes) del empujon del contacto frente a la inercia del cuerpo al decidir hacia donde cae o trastabilla.
const PUSH_WEIGHT := 3.0
## Coseno minimo entre el recorrido del clip y el sentido esperado para que el clip valga (~60 grados).
const DIRECTED_MIN_COS := 0.5
## Recorrido (m) por debajo del cual el clip se considera en el sitio (vale para cualquier sentido).
const DIRECTED_IN_PLACE := 0.35
## Fraccion lateral del sentido esperado a partir de la cual el lado de la caida tiene que coincidir con el del empujon.
const LATERAL_CLEAR := 0.25

## Sentido esperado de una caida o un trastabillon en el marco del jugador (x = adelante, y = derecha, como root_total):
## la velocidad del cuerpo mas el empujon del contacto (PUSH_WEIGHT).
func push_dir_local(from_dir: Vector3) -> Vector2:
	var f: Vector3 = owner.locomotion.forward()
	var r: Vector3 = owner.locomotion.right()
	var v: Vector3 = owner.locomotion.velocity
	var push: Vector3 = KickModel.flat(from_dir).normalized() * PUSH_WEIGHT
	var d: Vector3 = v + push
	return Vector2(d.dot(f), d.dot(r))

## Elige del pool (clips sin espejo) uno cuyo recorrido (o el de su espejo) vaya en el sentido esperado; los clips en el
## sitio valen para cualquier sentido (su espejo se decide por el lado del contacto). Si ninguno va en ese sentido, el mas
## alineado. Devuelve el clip con el espejo resuelto.
func _directed_pick(pool: Array[StringName], from_dir: Vector3) -> StringName:
	if pool.is_empty():
		return &""
	var want: Vector2 = push_dir_local(from_dir)
	var side: float = KickModel.flat(from_dir).dot(owner.locomotion.right())
	var ok: Array[StringName] = []
	var best: StringName = &""
	var best_cos: float = -2.0
	for id in pool:
		var rt: Vector2 = PackLibrary.meta(id).get("root_total", Vector2.ZERO)
		var mid: StringName = StringName(String(id) + "_mirror")
		var has_mirror: bool = PackLibrary.has_clip(mid)
		if rt.length() < DIRECTED_IN_PLACE or want.length() < 0.3:
			ok.append(mid if side < 0.0 and has_mirror else id)
			continue
		var options: Array = [[id, rt]]
		if has_mirror:
			options.append([mid, Vector2(rt.x, -rt.y)])
		for o in options:
			if not _lands_inside(o[0]):
				continue
			var ov: Vector2 = o[1]
			var c: float = ov.normalized().dot(want.normalized())
			# Con un empujon lateral claro, el clip no puede irse hacia el lado del rival (aunque vaya casi recto).
			var wrong_side: bool = absf(want.y) > LATERAL_CLEAR * want.length() and ov.y * want.y < 0.0 and absf(ov.y) > DIRECTED_IN_PLACE
			if c >= DIRECTED_MIN_COS and not wrong_side:
				ok.append(o[0])
			if c > best_cos:
				best_cos = c
				best = o[0]
	if not ok.is_empty():
		return ok[rng.randi() % ok.size()]
	return best

## Modo 4: un levantarse convertido que empieza en la postura `lie` (cualquiera si no hay de esa postura).
func _json_getup(lie: String) -> StringName:
	var same: Array[StringName] = []
	var all: Array[StringName] = []
	for id in PackLibrary.by_role(&"getup"):
		var m: Dictionary = PackLibrary.meta(id)
		all.append(id)
		if String(m.get("lie", "")) == lie:
			same.append(id)
	var pool: Array[StringName] = same if not same.is_empty() else all
	return pool[rng.randi() % pool.size()] if not pool.is_empty() else &""

## Margen (m) mas alla de las lineas en el que todavia puede terminar el recorrido de una caida o un esquive.
const LAND_MARGIN := 0.5

## El recorrido de la raiz del clip (x = adelante, y = derecha) termina dentro de la cancha (+ LAND_MARGIN): una caida de
## costado junto a la banda no saca al jugador del campo (_room_ahead solo mira hacia adelante).
func _lands_inside(id: StringName) -> bool:
	var ctx: MatchContext = owner.ctx
	if ctx == null or ctx.pitch == null:
		return true
	var base: StringName = StringName(String(id).trim_suffix("_mirror"))
	var rt: Vector2 = PackLibrary.meta(base).get("root_total", Vector2.ZERO)
	if String(id).ends_with("_mirror"):
		rt.y = -rt.y
	var end: Vector3 = owner.global_position + owner.locomotion.forward() * rt.x + owner.locomotion.right() * rt.y
	return ctx.pitch.contains_xz(end, -LAND_MARGIN)

## Con la pelota muerta, la raiz de una transicion no puede meter al jugador en la zona del saque. La IA rodea esa zona
## (AIInput._around_ball), pero el clip va recto: medido, un rival arrancando con jn_start_0468 a 4.35 m/s cruzaba a
## 3.79 m de un tiro libre (4 de 30 repeticiones de test_set_pieces). Radio: SetPiece.CLEAR_RADIUS para el equipo que
## saca (sin limite en el saque de banda) y MatchScene.SET_PIECE_DISTANCE para el rival (2 m en el saque de banda).
## Se recorre toda la raiz del clip; si el jugador ya esta dentro, solo se permite lo que no lo acerque mas.
func _keeps_set_piece_clear(id: StringName) -> bool:
	var ctx: MatchContext = owner.ctx
	if ctx == null or not ctx.dead_ball or ctx.ball == null:
		return true
	var taker: Node = ctx.restart_taker
	if taker == null or taker == owner:
		return true
	var same_team: bool = int(taker.get("team")) == owner.team
	var sp: SetPiece = taker.get("set_piece") as SetPiece
	var throw_in: bool = sp != null and sp.kind == SetPiece.Kind.THROW_IN
	var radius: float = (0.0 if throw_in else SetPiece.CLEAR_RADIUS) if same_team else (2.0 if throw_in else MatchScene.SET_PIECE_DISTANCE)
	if radius <= 0.0:
		return true
	var base: StringName = StringName(String(id).trim_suffix("_mirror"))
	var path: PackedVector2Array = PackLibrary.meta(base).get("root_path", PackedVector2Array())
	var mirror: float = -1.0 if String(id).ends_with("_mirror") else 1.0
	var bp: Vector3 = KickModel.flat(ctx.ball.global_position)
	var origin: Vector3 = KickModel.flat(owner.global_position)
	var now_d: float = origin.distance_to(bp)
	var fwd: Vector3 = owner.locomotion.forward()
	var right: Vector3 = owner.locomotion.right()
	for q in path:
		var at: Vector3 = origin + fwd * q.x + right * (q.y * mirror)
		var d: float = KickModel.flat(at).distance_to(bp)
		if d < radius and d < now_d - 0.05:
			return false
	return true

## Metros libres por delante del jugador hasta el borde del area de juego (lineas + area exterior).
func _room_ahead() -> float:
	var ctx: MatchContext = owner.ctx
	if ctx == null or ctx.pitch == null:
		return 99.0
	var cfg: PitchConfig = ctx.pitch.config
	var m: float = cfg.run_off if cfg.boundary_mode == PitchConfig.BoundaryMode.OUT_OF_BOUNDS else 0.0
	var f: Vector3 = owner.locomotion.forward()
	var p: Vector3 = owner.global_position
	var best: float = 99.0
	if absf(f.x) > 0.01:
		best = minf(best, ((cfg.half_length() + m) * signf(f.x) - p.x) / f.x)
	if absf(f.z) > 0.01:
		best = minf(best, ((cfg.half_width() + m) * signf(f.z) - p.z) / f.z)
	return maxf(best, 0.0)

# --- Regate (ruleta) -----------------------------------------------------------------------------------------

const SKILL_COOLDOWN := 2.5
const SKILL_MIN_SPEED := 1.8
var _skill_cd: float = 0.0

## Ruleta de 360 grados con la pelota (Soccer_Spin): mientras dura, el portador esta protegido de las entradas y la
## pelota sigue con el (toques de conduccion durante la accion). Requiere llevar la pelota y cierta velocidad.
func try_skill() -> bool:
	if not can_start(&"skill") or _skill_cd > 0.0 or not _can_play() or not owner.ball_handler.has_possession():
		return false
	if owner.locomotion.speed < SKILL_MIN_SPEED:
		return false
	if not start(&"skill", &"Soccer_Spin", 1.3):
		return false
	_skill_cd = SKILL_COOLDOWN
	stats["skills"] = int(stats.get("skills", 0)) + 1
	return true

## Mientras gira, la pelota no se queda atras: toques de conduccion en la direccion del avance.
func _skill_touches() -> void:
	owner.ball_handler.force_dribble_touch(owner.locomotion.forward())

## Tropiezo leve (solo presentacion): el cuerpo sigue su movimiento y el clip actua sobre el tronco.
func stumble() -> void:
	if _can_play() and owner.arbiter != null:
		owner.arbiter.play(&"stumble_light", ActionArbiter.Level.OVERLAY, &"PlayerActions", &"Jogging_Stumble_inplace", 1.0, 0.0, 0.9, true)
