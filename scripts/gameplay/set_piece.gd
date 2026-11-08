class_name SetPiece
extends RefCounted
## Ejecucion de un balon parado por un futbolista de campo: saque de banda, corner, tiro libre o penal (el saque de arco
## lo hace el arquero, ver Goalkeeper.start_goal_kick).
##
## Etapas: "setup" (el ejecutor espera quieto junto a la pelota y apunta; la persona elige con PASE / FILTRADO / CENTRO /
## TIRO, la IA decide sola tras una pausa) -> "run" (clip con desplazamiento de raiz: carrera y golpeo, o saque con
## las manos) -> "done". El golpe ocurre cuando el PIE del clip llega a la pelota (o cuando las manos la sueltan en el
## saque de banda); despues la pelota es pura fisica.
##
## Clips del pack que usa (todos con su raiz real, sin trucos):
##   throw_in (saque de banda), Chip (centro elevado / pase alto), strike_foward_jog (pase o centro raso con carrera),
##   soccer_penalty_kick (tiro con carrera: penal y tiro libre directo). Los espejos "_mirror" para la pierna izquierda.

enum Kind { THROW_IN, CORNER, FREE_KICK, PENALTY }

const KIND_NAMES := {Kind.THROW_IN: "throw_in", Kind.CORNER: "corner", Kind.FREE_KICK: "free_kick", Kind.PENALTY: "penalty"}
const THROW_CLIP := &"throw_in"
## Instante del clip throw_in (s) en que las manos lanzan: maxima velocidad hacia delante de las manos por encima de la
## cabeza, medido sobre el esqueleto del juego (manos a 0.6 m por delante y 1.45 m de altura).
const THROW_RELEASE := 1.57
const THROW_HANDS := Vector3(0.6, 1.45, 0.0)
## Metros de raiz del clip de saque que se reproducen antes de lanzar (el resto de la carrerilla se omite: el jugador
## saca desde la linea).
const THROW_RUNUP := 0.9
## Modo 2: saque de banda parado de la captura (mc_throw_in, 8 s con la preparacion). Las manos, por detras de la cabeza a
## los 6.4 s, lanzan hacia delante; a los 6.68 s estan a 0.45 m por delante y 1.52 m de altura. Se empieza a los 5.4 s,
## con la pelota ya arriba.
const MOCAP_THROW_CLIP := &"mc_throw_in"
const MOCAP_THROW_RELEASE := 6.68
const MOCAP_THROW_START := 5.4
const MOCAP_THROW_HANDS := Vector3(0.45, 1.52, 0.0)
const KICK_SPEED := 1.0
## Carrerilla maxima (m de raiz del clip) antes del golpe.
const RUNUP_MAX := 2.6
## Radio (m) alrededor de la pelota en el que no puede haber nadie mas que el ejecutor mientras dura el saque: carrerilla
## maxima (RUNUP_MAX) + contacto a un costado del cuerpo (hasta ~0.7 m) + medio cuerpo y margen. Los rivales, ademas,
## a la distancia reglamentaria (MatchScene.SET_PIECE_DISTANCE).
const CLEAR_RADIUS := 4.0
## Distancia maxima (m) entre la punta del pie del clip y la pelota en el instante de golpeo para que cuente.
const CONTACT_RADIUS := 0.45
## Segundos que espera la IA antes de sacar, y maximo que espera a la persona antes de sacar por ella.
const AI_WAIT := 1.1
const HUMAN_TIMEOUT := 9.0
## Estos clips fallaban por muestreo puntual o por espacio en el corner. Recuperados con barrido 3D y carrerilla libre.
const RECOVERED_FREE_KICKS := {
	&"pass": [&"jn_setpiece_pass_3330", &"jn_setpiece_pass_3342", &"jn_setpiece_pass_3346"],
	&"shot": [&"jn_setpiece_shot_3354", &"jn_setpiece_shot_3856"],
}

var kind: Kind = Kind.THROW_IN
var team: int = 0
var spot: Vector3 = Vector3.ZERO
var taker: Footballer = null
var ctx: MatchContext = null
var stage: StringName = &"setup"
var aim_dir: Vector3 = Vector3.ZERO
var action: StringName = &""
var charge: float = 0.5
var lob: bool = false
var clip: StringName = &""
var foot_key: String = "toe_r"
var contact_t: float = 0.0
var resolved: bool = false
## Golpeos fallidos (el pie no llego a la pelota): al segundo, el saque se hace sin carrera para no trabar el partido.
var misses: int = 0
var result: StringName = &""
## Ultima medicion del contacto, incluso si el saque se reintenta.
var last_contact: Dictionary = {}
var last_setup: Dictionary = {}
var _previous_toe := Vector3.INF
var _previous_ball := Vector3.INF
var _contact_min: float = INF
var orientation_clip: StringName = &""
var _queued_throw: Dictionary = {}
var _orientation_done: bool = false
var _t: float = 0.0
var _btn: StringName = &""
var _btn_time: float = 0.0
var _aim_press: Vector3 = Vector3.ZERO
## Efecto del saque (-1..1): gesto del joystick entre pulsar y soltar (persona) o eleccion de la IA.
var curl: float = 0.0
var _anchor: Node3D = null
var rng := RandomNumberGenerator.new()

static func kind_name(k: Kind) -> String:
	return KIND_NAMES.get(k, "set_piece")

func _init(k: Kind, team_index: int, at: Vector3, who: Footballer, context: MatchContext) -> void:
	# Modo 4: cada balon parado usa otro de los clips convertidos de su rol (saque de banda, tiro libre, centro...).
	PackLibrary.vary_aliases()
	kind = k
	team = team_index
	spot = Vector3(at.x, 0.0, at.z)
	taker = who
	ctx = context
	rng.randomize()
	aim_dir = default_aim()

## Direccion por defecto: hacia dentro de la cancha y hacia el arco rival.
func default_aim() -> Vector3:
	var gx: float = ctx.pitch.config.half_length() * (1.0 if team == 0 else -1.0)
	match kind:
		Kind.THROW_IN:
			return Vector3(signf(gx) * 0.5, 0.0, -signf(spot.z)).normalized()
		Kind.CORNER:
			return KickModel.flat(Vector3(gx - signf(gx) * 3.0, 0.0, 0.0) - spot).normalized()
		_:
			return KickModel.flat(Vector3(gx, 0.0, 0.0) - spot).normalized()

## Coloca al ejecutor para la etapa de preparacion: detras de la pelota mirando hacia `aim_dir`.
func place_taker() -> void:
	var yaw: float = Locomotion.yaw_from_dir(aim_dir)
	var pos: Vector3
	if kind == Kind.THROW_IN:
		# Fuera de la linea, de frente a la cancha, con la pelota en las manos.
		pos = spot + Vector3(0.0, 0.0, signf(spot.z) * 0.45)
	else:
		pos = spot - aim_dir * 1.6
	taker.place_at(pos, yaw)
	if kind == Kind.THROW_IN:
		_hold_ball()

func _hold_ball() -> void:
	if _anchor == null:
		_anchor = Node3D.new()
		_anchor.name = "ThrowAnchor"
		taker.add_child(_anchor)
	_update_anchor()
	ctx.ball.hold(_anchor, taker)

## Ancla de las manos del saque de banda: posicion REAL de las manos del esqueleto (si hay modelo) o la medida.
func _update_anchor() -> void:
	if _anchor == null:
		return
	var v: FootballerVisual = taker.visual
	if v != null and v.skeleton != null and not v.is_placeholder:
		var sk: Skeleton3D = v.skeleton
		var l: int = sk.find_bone("mixamorig_LeftHand")
		var r: int = sk.find_bone("mixamorig_RightHand")
		if l >= 0 and r >= 0:
			var p: Vector3 = (sk.global_transform * sk.get_bone_global_pose(l).origin + sk.global_transform * sk.get_bone_global_pose(r).origin) * 0.5
			_anchor.global_position = p + taker.locomotion.forward() * 0.12
			return
	var f: Vector3 = taker.locomotion.forward()
	_anchor.global_position = taker.global_position + f * 0.25 + Vector3.UP * 2.05

## Paso del ejecutor. Devuelve true si el balon parado se ocupa del cuerpo en este paso (el futbolista no hace nada mas).
func tick(frame: InputFrame, delta: float) -> bool:
	_t += delta
	if stage == &"done":
		return false
	if not ctx.input_enabled:
		_hold_still()
		return true
	if stage == &"setup":
		_tick_setup(frame, delta)
		return true
	if stage == &"orient":
		_update_anchor()
		if not taker.actions.active():
			var queued: Dictionary = _queued_throw
			_queued_throw = {}
			stage = &"setup"
			execute(queued["action"], queued["charge"], queued["lob"], queued["dir"], queued["curl"])
		return false
	# Etapa "run": el clip mueve el cuerpo (PlayerActions); aqui solo se resuelve el contacto.
	if kind == Kind.THROW_IN:
		_update_anchor()
	var mt: float = taker.actions.motion.t
	if kind != Kind.THROW_IN and not resolved:
		_track_contact(mt)
	if not resolved and mt >= contact_t:
		_resolve()
	if not taker.actions.active():
		stage = &"done"
		taker.set_ball_ghost(false)
	return false

func _hold_still() -> void:
	taker.velocity = Vector3.ZERO
	taker.locomotion.stop()
	if kind == Kind.THROW_IN:
		_update_anchor()
	if taker.visual != null:
		taker.visual.update_motion(taker, 1.0 / 60.0)

func _tick_setup(frame: InputFrame, delta: float) -> void:
	_hold_still()
	if taker.is_human_controlled:
		# El joystick apunta; el boton elige el saque y su potencia (mantener = mas fuerte).
		var stick: Vector3 = frame.move_world if frame.use_world else ctx.screen_to_world(frame.move)
		if stick.length() > 0.3:
			aim_dir = KickModel.flat(stick).normalized()
			if kind == Kind.THROW_IN and aim_dir.dot(Vector3(0.0, 0.0, -signf(spot.z))) < 0.1:
				aim_dir = KickModel.rotate_toward(aim_dir, Vector3(0.0, 0.0, -signf(spot.z)), 90.0)
			taker.locomotion.face_towards(aim_dir, delta)
			taker.rotation.y = taker.locomotion.yaw
		for pair in [[&"pass", frame.pass_pressed, frame.pass_held], [&"through", frame.through_pressed, frame.through_held],
				[&"cross", frame.cross_pressed, frame.cross_held], [&"shot", frame.shoot_pressed, frame.shoot_held]]:
			if pair[1] and _btn == &"":
				_btn = pair[0]
				_btn_time = 0.0
				_aim_press = aim_dir
		if _btn != &"":
			var held: bool = (_btn == &"pass" and frame.pass_held) or (_btn == &"through" and frame.through_held) \
				or (_btn == &"cross" and frame.cross_held) or (_btn == &"shot" and frame.shoot_held)
			if held:
				_btn_time += delta
			else:
				# Si al soltar el joystick giro respecto a donde se apunto al pulsar, es efecto (chanfle), no otra direccion.
				var c: float = BallHandler.curl_from(_aim_press, aim_dir) if kind != Kind.THROW_IN else 0.0
				execute(_btn, clampf(_btn_time / 0.8, 0.0, 1.0), frame.lob_held, _aim_press if c != 0.0 else aim_dir, c)
		elif _t > HUMAN_TIMEOUT:
			ai_execute()
	elif _t > AI_WAIT:
		ai_execute()

## Decision de la IA (o de la persona que no saca a tiempo).
func ai_execute() -> void:
	var gx: float = ctx.pitch.config.half_length() * (1.0 if team == 0 else -1.0)
	var goal := Vector3(gx, 0.0, 0.0)
	match kind:
		Kind.PENALTY:
			var side: float = 1.0 if rng.randf() < 0.5 else -1.0
			var aim := Vector3(gx, 0.0, side * ctx.pitch.config.half_goal() * rng.randf_range(0.45, 0.85))
			execute(&"shot", rng.randf_range(0.55, 0.85), false, KickModel.flat(aim - spot).normalized())
		Kind.CORNER:
			execute(&"cross", rng.randf_range(0.2, 0.6), rng.randf() < 0.25, aim_dir)
		Kind.FREE_KICK:
			var d: float = spot.distance_to(goal)
			if d < 13.0 and absf(spot.z) < 6.0:
				# Tiro libre directo con chanfle: a un palo, curvando hacia dentro por encima de la defensa.
				var post_side: float = 1.0 if rng.randf() < 0.5 else -1.0
				var aim2 := Vector3(gx, 0.0, post_side * ctx.pitch.config.half_goal() * rng.randf_range(0.55, 0.8))
				var to_aim: Vector3 = KickModel.flat(aim2 - spot).normalized()
				# Curva hacia el centro del arco: a la derecha del tiro si el palo elegido esta a su izquierda.
				var right := Vector3(-to_aim.z, 0.0, to_aim.x)
				var c2: float = signf(KickModel.flat(Vector3(gx, 0.0, 0.0) - aim2).dot(right)) * rng.randf_range(0.5, 0.9)
				execute(&"shot", rng.randf_range(0.55, 0.8), false, to_aim, c2)
			else:
				var mate: Footballer = _open_mate()
				var dir: Vector3 = KickModel.flat(mate.global_position - spot).normalized() if mate != null else default_aim()
				execute(&"pass", clampf(spot.distance_to(mate.global_position) / 25.0, 0.15, 0.7) if mate != null else 0.4, false, dir)
		_:
			var m: Footballer = _open_mate()
			var tdir: Vector3 = KickModel.flat(m.global_position - spot).normalized() if m != null else default_aim()
			execute(&"pass", 0.4, false, tdir)

## Companero mas libre para recibir (cerca, con espacio, preferiblemente hacia delante).
func _open_mate() -> Footballer:
	var best: Footballer = null
	var best_s: float = -INF
	var atk := Vector3(1.0 if team == 0 else -1.0, 0.0, 0.0)
	for f in ctx.footballers:
		if f.team != team or f == taker:
			continue
		var fp: Vector3 = KickModel.flat(f.global_position)
		var d: float = fp.distance_to(spot)
		if d < 3.0 or d > 20.0:
			continue
		var open: float = 6.0
		for o in ctx.footballers:
			if o.team != team:
				open = minf(open, KickModel.flat(o.global_position).distance_to(fp))
		var s: float = open * 1.5 + (fp - spot).dot(atk) * 0.25 - d * 0.15
		if s > best_s:
			best_s = s
			best = f
	return best

## Ejecuta el saque: elige el clip, coloca la carrera para que el pie llegue a la pelota y arranca la accion.
func execute(act: StringName, ch: float, lb: bool, dir: Vector3, cu: float = 0.0) -> void:
	if stage != &"setup":
		return
	curl = cu
	action = act
	charge = ch
	lob = lb
	if dir.length_squared() > 0.01:
		aim_dir = KickModel.flat(dir).normalized()
	if kind == Kind.THROW_IN and not _orientation_done and _orient_throw():
		_queued_throw = {"action": act, "charge": ch, "lob": lb, "dir": dir, "curl": cu}
		return
	var yaw: float = Locomotion.yaw_from_dir(aim_dir)
	stage = &"run"
	if kind == Kind.THROW_IN:
		var mocap: bool = AnimationCatalog.mocap_mode() and PackLibrary.has_clip(MOCAP_THROW_CLIP)
		clip = MOCAP_THROW_CLIP if mocap else THROW_CLIP
		contact_t = MOCAP_THROW_RELEASE if mocap else THROW_RELEASE
		if _json_throw():
			# Modo 4: el instante y la posicion de las manos al lanzar se midieron en el propio clip (meta release).
			contact_t = float(PackLibrary.meta(THROW_CLIP)["release"]["time"])
		# Se empieza tarde en el clip: solo los ultimos THROW_RUNUP m de carrerilla, para lanzar desde la linea.
		var start_at: float = MOCAP_THROW_START if mocap else _start_for_runup(clip, contact_t, THROW_RUNUP)
		var root_left: Vector2 = ActionMotion.offset_between(clip, start_at, contact_t)
		var f: Vector3 = Locomotion.dir_from_yaw(yaw)
		var r := Vector3(-f.z, 0.0, f.x)
		var line := Vector3(spot.x, 0.0, signf(spot.z) * ctx.pitch.config.half_width())
		var start: Vector3 = line - f * (root_left.x + _throw_hands().x - 0.2) - r * root_left.y
		taker.place_at(start, yaw)
		_hold_ball()
		if not taker.actions.start(&"set_piece", clip, 1.0, contact_t - start_at + 0.6, [], start_at):
			_resolve_without_clip()
		return
	clip = _kick_clip(act, lb)
	_previous_toe = Vector3.INF
	_previous_ball = Vector3.INF
	_contact_min = INF
	var m: Dictionary = PackLibrary.meta(clip)
	var c: Dictionary = m.get("contact", {})
	foot_key = "toe_r" if int(c.get("foot", 1)) > 0 else "toe_l"
	contact_t = float(c.get("time", 0.4))
	# Inicio del clip: la carrera completa si cabe, o recortada para no empezar a mas de 3 m de la pelota.
	var start_t: float = _start_for_runup(clip, contact_t, RUNUP_MAX)
	var toe: Vector3 = _toe_at(clip, foot_key, contact_t)
	var root0: Vector2 = ActionMotion.offset_between(clip, 0.0, start_t)
	var f2: Vector3 = Locomotion.dir_from_yaw(yaw)
	var r2 := Vector3(-f2.z, 0.0, f2.x)
	# Posicion de salida tal que el pie (trayectoria con raiz desde start_t) quede sobre la pelota en el golpeo.
	var start2: Vector3 = spot - f2 * (toe.x - root0.x) - r2 * (toe.z - root0.y)
	last_setup = {"start": start2, "start_t": start_t, "toe": toe, "root0": root0}
	taker.place_at(start2, yaw)
	taker.set_ball_ghost(true)
	if not taker.actions.start(&"set_piece", clip, KICK_SPEED, contact_t - start_t + 0.45, [], start_t):
		_resolve_without_clip()

## Antes de lanzar, el ejecutor puede orientarse con su clip propio sin soltar la pelota ni fabricar un lanzamiento.
func _orient_throw() -> bool:
	if not PackLibrary.json_mode():
		return false
	var needed: float = wrapf(Locomotion.yaw_from_dir(aim_dir) - taker.locomotion.yaw, -PI, PI)
	for id in PackLibrary.by_role(&"throw_prep"):
		var m: Dictionary = PackLibrary.meta(id)
		var turn: float = ActionMotion.heading_rel(m.get("heading_path", PackedFloat32Array()), float(m.get("duration", 1.0)))
		if absf(needed) < deg_to_rad(15.0) or absf(wrapf(needed - turn, -PI, PI)) > deg_to_rad(12.0):
			continue
		if taker.actions.start(&"set_piece", id):
			orientation_clip = id
			_orientation_done = true
			stage = &"orient"
			return true
	return false

## Fuerza el saque ya (lo pide el partido si el balon parado se alarga demasiado).
func force() -> void:
	if result == &"contact" or result == &"thrown":
		return
	if stage == &"setup":
		ai_execute()
		if result == &"contact" or result == &"thrown":
			return
	taker.actions.reset()
	if kind == Kind.THROW_IN and not ctx.ball.is_held():
		_hold_ball()
	_resolve_without_clip()

## Sin libreria del pack (o sin modelo) no hay clip que mueva el cuerpo: el saque se hace en el sitio, junto a la pelota.
func _resolve_without_clip() -> void:
	resolved = true
	stage = &"done"
	taker.set_ball_ghost(false)
	if kind == Kind.THROW_IN:
		var from: Vector3 = taker.global_position + taker.locomotion.forward() * _throw_hands().x + Vector3.UP * _throw_hands().y
		var v: Vector3 = _throw_velocity(from)
		ctx.ball.release(taker, v)
		ctx.ball.global_position = from
		ctx.ball.register_touch(taker)
		result = &"thrown"
		ctx.emit_event(GameEvent.make(GameEvent.Type.PASS, taker.actor_id, team, {"set_piece": "throw_in", "speed": v.length(), "kind": "throw_in"}))
		return
	taker.place_at(spot - aim_dir * 0.35, Locomotion.yaw_from_dir(aim_dir))
	result = &"contact"
	taker.ball_handler.shot_curl = curl
	taker.ball_handler.perform_action(action, aim_dir, charge, lob)

## Manos al lanzar respecto del jugador, segun el clip de saque.
func _throw_hands() -> Vector3:
	if _json_throw():
		return PackLibrary.meta(THROW_CLIP)["release"]["hands"]
	return MOCAP_THROW_HANDS if clip == MOCAP_THROW_CLIP else THROW_HANDS

## Modo 4: el saque de banda usa el clip JSON con su suelta medida.
func _json_throw() -> bool:
	return PackLibrary.json_mode() and PackLibrary.has_clip(THROW_CLIP) and PackLibrary.meta(THROW_CLIP).has("release")

## Instante de inicio del clip para que, hasta `until`, la raiz recorra como mucho `max_m` metros.
func _start_for_runup(id: StringName, until: float, max_m: float) -> float:
	var t0: float = 0.0
	while t0 < until - 0.2 and ActionMotion.offset_between(id, t0, until).length() > max_m:
		t0 += 1.0 / 30.0
	return t0

func _toe_at(id: StringName, key: String, t: float) -> Vector3:
	var hp: PackedVector3Array = PackLibrary.meta(id).get("paths", {}).get(key, PackedVector3Array())
	if hp.is_empty():
		return Vector3(0.3, 0.1, 0.25)
	return hp[clampi(int(round(t * 30.0)), 0, hp.size() - 1)]

## Clip de golpeo con carrera segun el saque. Pierna habil: el espejo si el jugador es zurdo.
func _kick_clip(act: StringName, lb: bool) -> StringName:
	var base: StringName = &"strike_foward_jog"
	if act == &"shot":
		# Modo 2: el penal (y el tiro libre directo) de la captura de movimiento de futbol, con su carrera.
		base = &"mc_penalty_kick" if AnimationCatalog.mocap_mode() else &"soccer_penalty_kick"
	elif (act == &"cross" and not lb) or (act == &"pass" and lb):
		base = &"Chip"
	var id: StringName = base if taker.dominant_right else StringName(String(base) + "_mirror")
	if not PackLibrary.has_clip(id):
		id = base
	if kind == Kind.FREE_KICK and not lb:
		var pool: Array[StringName] = recovered_free_kicks(act)
		if not pool.is_empty():
			if PackLibrary.has_clip(id):
				pool.append(id)
			return pool[rng.randi_range(0, pool.size() - 1)]
	return id if PackLibrary.has_clip(id) else &"Soccer_Pass"

func recovered_free_kicks(act: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if kind != Kind.FREE_KICK:
		return out
	var yaw: float = Locomotion.yaw_from_dir(aim_dir)
	var forward: Vector3 = Locomotion.dir_from_yaw(yaw)
	var right := Vector3(-forward.z, 0.0, forward.x)
	for base in RECOVERED_FREE_KICKS.get(act, []):
		var id: StringName = base if taker.dominant_right else StringName(String(base) + "_mirror")
		if not PackLibrary.has_clip(id):
			continue
		var contact: Dictionary = PackLibrary.meta(id).get("contact", {})
		var time: float = float(contact.get("time", -1.0))
		if time <= 0.0:
			continue
		var start: float = _start_for_runup(id, time, RUNUP_MAX)
		var toe: Vector3 = _toe_at(id, "toe_r" if int(contact.get("foot", 1)) > 0 else "toe_l", time)
		var root0: Vector2 = ActionMotion.offset_between(id, 0.0, start)
		var origin: Vector3 = spot - forward * (toe.x - root0.x) - right * (toe.z - root0.y)
		var fits: bool = true
		for frame in range(int(start * 30.0), int(time * 30.0) + 2):
			var root: Vector2 = ActionMotion.offset_between(id, start, float(frame) / 30.0)
			var point: Vector3 = origin + forward * root.x + right * root.y
			if absf(point.x) > ctx.pitch.config.half_length() + 0.7 or absf(point.z) > ctx.pitch.config.half_width() + 0.7:
				fits = false
				break
		if fits:
			out.append(id)
	return out

## Instante del golpe / lanzamiento: el impulso sale del contacto real del pie (o de las manos).
func _resolve() -> void:
	resolved = true
	var ball: Ball = ctx.ball
	if kind == Kind.THROW_IN:
		_update_anchor()
		var from: Vector3 = _anchor.global_position if _anchor != null else ball.global_position
		var v: Vector3 = _throw_velocity(from)
		ball.release(taker, v)
		ball.global_position = from
		ball.register_touch(taker)
		result = &"thrown"
		ctx.emit_event(GameEvent.make(GameEvent.Type.PASS, taker.actor_id, team, {"set_piece": "throw_in", "speed": v.length(), "kind": "throw_in"}))
		return
	var k: int = int(round(taker.actions.motion.t * 30.0))
	var toe: Vector3 = KeeperPlanner.path_world_at_body(clip, foot_key, k, taker.global_position, taker.locomotion.yaw)
	var d: float = Vector2(toe.x - ball.global_position.x, toe.z - ball.global_position.z).length()
	var swept: float = _contact_min if is_finite(_contact_min) else (toe - ball.global_position).length()
	last_contact = {"clip": clip, "distance": d, "swept_distance": swept, "toe": toe, "ball": ball.global_position, "body": taker.global_position, "time": taker.actions.motion.t}
	taker.set_ball_ghost(false)
	if swept > CONTACT_RADIUS:
		result = &"missed"
		ctx.emit_event(GameEvent.make(GameEvent.Type.KICK_WHIFF, taker.actor_id, team, {"set_piece": kind_name(kind), "foot_distance": d}))
		misses += 1
		if misses >= 2:
			taker.actions.reset()
			_resolve_without_clip()
			return
		# El saque no se pierde: se repite desde la preparacion.
		stage = &"setup"
		resolved = false
		_t = 0.0
		taker.actions.reset()
		place_taker()
		return
	result = &"contact"
	var stick: Vector3 = aim_dir
	taker.ball_handler.shot_curl = curl
	taker.ball_handler.perform_action(action, stick, charge, lob)

## El pie puede recorrer 20 cm entre pasos: un unico fotograma despues del evento perdia contactos reales.
## Mide la menor distancia 3D relativa barrida, como las manos del arquero, en la ventana del contacto.
func _track_contact(time: float) -> void:
	var toe: Vector3 = KeeperPlanner.path_world_at_body(clip, foot_key, int(round(time * 30.0)), taker.global_position, taker.locomotion.yaw)
	var ball_pos: Vector3 = ctx.ball.global_position
	if absf(time - contact_t) <= Goalkeeper.CONTACT_WINDOW:
		var relative: Vector3 = toe - ball_pos
		_contact_min = minf(_contact_min, relative.length())
		if _previous_toe != Vector3.INF:
			var before: Vector3 = _previous_toe - _previous_ball
			var segment: Vector3 = relative - before
			var fraction: float = clampf(-before.dot(segment) / maxf(segment.length_squared(), 0.000001), 0.0, 1.0)
			_contact_min = minf(_contact_min, (before + segment * fraction).length())
	_previous_toe = toe
	_previous_ball = ball_pos

## Velocidad del saque de banda con las manos hacia el companero (o hacia donde apunta).
func _throw_velocity(from: Vector3) -> Vector3:
	var target: Vector3 = spot + aim_dir * 8.0
	var best: Footballer = null
	var best_a: float = 35.0
	for f in ctx.footballers:
		if f.team != team or f == taker:
			continue
		var to: Vector3 = KickModel.flat(f.global_position - from)
		var a: float = KickModel.angle_between_deg(aim_dir, to)
		if a < best_a and to.length() < 18.0:
			best_a = a
			best = f
	if best != null:
		target = best.global_position + best.velocity * 0.4
		best.expect_pass(target, &"throw_in", taker)
	var d: Vector3 = KickModel.flat(target - from)
	var dist: float = d.length()
	var dir: Vector3 = d / maxf(dist, 0.01)
	var err: float = deg_to_rad(rng.randfn(0.0, lerpf(7.0, 2.5, taker.attributes.norm("pass_accuracy"))))
	dir = dir.rotated(Vector3.UP, err)
	# Parabola corta: sale de las manos (1.4-2 m) y cae al pie del companero.
	var speed_h: float = clampf(dist * 0.95 + 2.0, 5.0, 12.5) * lerpf(0.9, 1.0 + 0.25 * charge, 0.5)
	var t_f: float = dist / maxf(speed_h, 1.0)
	var vy: float = clampf((0.3 - from.y + 0.5 * KickModel.G * t_f * t_f) / maxf(t_f, 0.1), 0.5, 6.0)
	return Vector3(dir.x * speed_h, vy, dir.z * speed_h)
