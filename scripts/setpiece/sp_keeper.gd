class_name SpKeeper
extends Node
## Arquero de los modos de tiros libres y penales (IA o manejado por el usuario) sobre un SpActor con los clips del banco
## JSON. Reutiliza el planificador del partido (KeeperPlanner: elige el clip cuyas MANOS medidas llegan a la pelota, con su
## instante de inicio y velocidad) y resuelve el contacto con la pelota de forma fisica:
##  - La IA no conoce el resultado: en un tiro libre lee la trayectoria DESPUES del golpe (tiempo de reaccion y error de
##    percepcion segun la dificultad); en un penal tiene que adivinar antes del contacto y se juega con lo que lee del
##    cuerpo del tirador (a veces acierta el lado, a veces no).
##  - El usuario elige la zona antes del tiro; el arquero se lanza hacia esa zona cuando el tirador golpea.
##  - Contacto: esferas en manos, antebrazos, cabeza, pecho, cadera y piernas siguen a los huesos del clip; si la pelota
##    (barrido del paso) toca una, se ataja (si llega a las dos manos y no va demasiado rapida) o rebota con la velocidad
##    relativa y un coeficiente de restitucion (desvio con las manos, rebote en el cuerpo). Si no la toca, es gol o fuera:
##    la pelota nunca se mueve hacia las manos.

signal touched_ball(kind: StringName)

enum State { IDLE, WAIT_DIVE, DIVE, HOLD, GETUP, REACT }

const PARTS := [
	["mixamorig_LeftHand", 0.13, true], ["mixamorig_RightHand", 0.13, true],
	["mixamorig_LeftForeArm", 0.09, false], ["mixamorig_RightForeArm", 0.09, false],
	["mixamorig_Head", 0.12, false], ["mixamorig_Spine2", 0.19, false], ["mixamorig_Hips", 0.17, false],
	["mixamorig_LeftLeg", 0.10, false], ["mixamorig_RightLeg", 0.10, false],
	["mixamorig_LeftFoot", 0.09, false], ["mixamorig_RightFoot", 0.09, false],
]
## Las manos se extienden un poco mas alla de la muñeca (dedos y guantes).
const HAND_REACH := 0.09

var actor: SpActor
var ball: Ball
var goal_x: float = 52.5
var half_goal: float = 3.66
var goal_height: float = 2.44
var home := Vector3.ZERO
var facing := Vector3(-1, 0, 0)
var state: int = State.IDLE
## Arquero de la IA (false: lo maneja el usuario y respeta su eleccion de zona).
var ai: bool = true
## Tiro «flojo» (m/s): la IA no se juega antes del golpe y, si ya eligio lado pero todavia no se tiro, lee la pelota real.
const SLOW_SHOT := 17.0
var rng := RandomNumberGenerator.new()
## Ultimo plan de atajada (diagnostico y pruebas).
var plan: Dictionary = {}
## Toco la pelota en esta jugada (y como).
var touch_kind: StringName = &""
var _dive_in: float = -1.0
var _prev_ball := Vector3.ZERO
var _prev_parts: Dictionary = {}
var _last_contact_ms: int = -100000
var _anchor: Node3D
var _idle_clip: StringName = &""

func setup(a: SpActor, b: Ball, gx: float, half: float, height: float) -> void:
	actor = a
	ball = b
	goal_x = gx
	half_goal = half
	goal_height = height
	actor.role = &"keeper"
	actor.clip_finished.connect(_on_clip_finished)
	_anchor = Node3D.new()
	_anchor.name = "KeeperHoldAnchor"
	add_child(_anchor)
	var idles: Array[StringName] = SpClips.by_role(&"gk_idle", false)
	_idle_clip = idles[0] if not idles.is_empty() else &""

## Coloca al arquero en su sitio, mirando al campo, en espera.
func reset(home_pos: Vector3) -> void:
	home = Vector3(home_pos.x, 0.0, home_pos.z)
	facing = Vector3(-1, 0, 0)
	state = State.IDLE
	plan = {}
	touch_kind = &""
	_dive_in = -1.0
	_zone = Vector3.INF
	_watching = false
	_prev_parts.clear()
	actor.stop_moving()
	actor.global_position = home
	actor.set_facing(facing)
	var idles: Array[StringName] = SpClips.by_role(&"gk_idle", false)
	idles.append_array(SpClips.by_role(&"gk_idle_var", false))
	_idle_clip = idles[rng.randi() % idles.size()] if not idles.is_empty() else &""
	actor.play_loop(_idle_clip, 0.2)
	if ball != null:
		_prev_ball = ball.global_position

## Paso lateral hacia una posicion (antes del tiro): sigue a la pelota sin dejar el arco.
func shuffle_to(p: Vector3, speed: float = 1.4) -> void:
	if state != State.IDLE:
		return
	var side_loop: StringName = &"jn_gk_sidestep_0184" if SpClips.has(&"jn_gk_sidestep_0184") else &""
	if Vector3(p.x - actor.global_position.x, 0.0, p.z - actor.global_position.z).length() > 0.08:
		actor.move_to(p, speed, side_loop, facing)

# --- Decisiones ----------------------------------------------------------------------------------------------------------

func _yaw() -> float:
	return Locomotion.yaw_from_dir(facing)

## IA, despues del golpe (tiro libre): mira la pelota REAL. Pasado su tiempo de reaccion la vuelve a leer cada READ_EVERY s
## (posicion, velocidad y parte del giro) con un error de percepcion fijo para esta jugada que se achica a medida que la
## pelota se acerca, replanifica, y se tira en el ultimo instante que le permite llegar. Si la pelota se desvia (barrera,
## jugadores) lee la trayectoria nueva. No conoce el resultado: si lee mal o no llega, no la toca.
## Cada cuanto vuelve a leer la pelota (s): el plan cuesta varios ms en un telefono.
const READ_EVERY := 0.1
var _watching: bool = false
var _watch_t: float = 0.0
var _read_t: float = 0.0
var _err_yaw: float = 0.0
var _err_pitch: float = 0.0
var _spin_seen: float = 0.85

func read_shot(_ball_pos: Vector3, _velocity: Vector3, _spin: Vector3) -> void:
	if state != State.IDLE:
		return
	_watching = true
	_watch_t = SpSettings.keeper_reaction()
	_read_t = 0.0
	var err: float = SpSettings.keeper_perception_deg()
	_err_yaw = deg_to_rad(rng.randfn(0.0, err))
	_err_pitch = deg_to_rad(rng.randfn(0.0, err * 0.7))
	_spin_seen = rng.randf_range(0.7, 1.0)

func _watch_step(delta: float) -> void:
	if not _watching or state != State.IDLE:
		return
	_watch_t -= delta
	if _watch_t > 0.0:
		return
	_read_t -= delta
	if _read_t > 0.0:
		return
	_read_t = READ_EVERY
	if ball.is_held():
		_watching = false
		return
	var bp: Vector3 = ball.global_position
	var bv: Vector3 = ball.linear_velocity
	if bv.x < 0.5 or bp.x > goal_x:
		return
	# El error se achica con la distancia que le queda a la pelota.
	var k: float = clampf((goal_x - bp.x) / 25.0, 0.15, 1.0)
	var h := Vector3(bv.x, 0.0, bv.z)
	var side := Vector3(-h.z, 0.0, h.x).normalized() if h.length() > 0.01 else Vector3.RIGHT
	var v_seen: Vector3 = bv.rotated(Vector3.UP, _err_yaw * k).rotated(side, -_err_pitch * k)
	var traj: PackedVector3Array = BallPredictor.trajectory(bp, v_seen, 2.0, 1.0 / 30.0, ball.angular_velocity * _spin_seen)
	var cross: Vector3 = ShotSolver.crossing(traj, goal_x - 0.2)
	if cross != Vector3.INF and (absf(cross.z) > half_goal + 1.0 or cross.y > goal_height + 0.6):
		actor.face_towards(Vector3(bp.x, 0, bp.z) - actor.global_position)
		return
	var human := Vector2(Tuning.keeper.hand_latency, Tuning.keeper.hand_speed) if Tuning.keeper != null else Vector2.ZERO
	var pl: Dictionary = KeeperPlanner.plan_save(actor.global_position, _yaw(), traj, 1.0 / 30.0, 0.0, bv.length(), false, [1.0, 1.25], human)
	if pl.is_empty() or float(pl.get("dist", 0.0)) > float(pl.get("radius", 0.5)):
		# Todavia no llega con ningun clip: se acomoda caminando de costado hacia donde va la pelota (pelotas lentas).
		if cross != Vector3.INF:
			var z: float = clampf(cross.z, -half_goal + 0.4, half_goal - 0.4)
			shuffle_to(Vector3(actor.global_position.x, 0.0, z), 2.6)
		if pl.is_empty():
			return
	plan = pl
	# Espera mientras pueda: se tira cuando la estirada tiene que empezar ya (o si ya no llega de ninguna forma, al final).
	if float(pl["delay"]) <= READ_EVERY * 1.5:
		# El plan dice cuando arrancar: ni antes (las manos pasarian antes que la pelota) ni despues.
		_watching = false
		state = State.WAIT_DIVE
		_dive_in = float(pl["delay"])
		if _dive_in <= 0.0:
			_start_dive()

## Penal: el arquero se juega ANTES del golpe a una zona del arco (la elige el usuario o la IA con lo que lee del tirador):
## lead = segundos que faltan para el contacto y speed_guess = la velocidad que espera por la carrera y el impulso del
## tirador (no el destino). Como los arqueros reales, puede arrancar la estirada un instante antes del golpe. Nunca usa el
## destino real del tiro: si eligio mal el lado, no llega. Sin lead (decide al ver salir la pelota), sincroniza con on_kick.
var _zone := Vector3.INF

func commit_to(point: Vector3, ball_pos: Vector3, lead: float, speed_guess: float = 22.0) -> void:
	if state != State.IDLE:
		return
	actor.stop_moving()
	if lead <= 0.01:
		_zone = point
		return
	_plan_with(_line_traj(ball_pos, point, speed_guess, lead), 0.0)

## La pelota salio y ya habia elegido zona sin anticipar: planifica hacia esa zona con la velocidad que ve.
func on_kick(ball_pos: Vector3, velocity: Vector3) -> void:
	if ai and velocity.length() < SLOW_SHOT:
		# Tiro flojo: si todavia no se tiro, tiene tiempo de verlo y cambiar (no se queda mirando como entra).
		if state == State.WAIT_DIVE and _dive_in > SpSettings.keeper_reaction() * 0.5:
			state = State.IDLE
			plan = {}
			_dive_in = -1.0
		if state == State.IDLE:
			_zone = Vector3.INF
			read_shot(ball_pos, velocity, Vector3.ZERO)
			return
	if _zone == Vector3.INF or state != State.IDLE:
		return
	var speed_seen: float = maxf(velocity.length() * rng.randf_range(0.92, 1.08), 8.0)
	var z: Vector3 = _zone
	_zone = Vector3.INF
	_plan_with(_line_traj(ball_pos, z, speed_seen, 0.0), 0.05)

## Trayectoria supuesta: la pelota quieta `wait` segundos y despues en linea (con un poco de comba) hasta el punto.
static func _line_traj(ball_pos: Vector3, point: Vector3, speed: float, wait: float) -> PackedVector3Array:
	var step: float = 1.0 / 30.0
	var traj := PackedVector3Array()
	for i in maxi(int(round(wait / step)), 0):
		traj.append(ball_pos)
	var to: Vector3 = point - ball_pos
	var t_fly: float = to.length() / maxf(speed, 5.0)
	for i in int(ceil(t_fly / step)) + 9:
		var u: float = float(i) * step / t_fly
		var p: Vector3 = ball_pos + to * u
		p.y += sin(clampf(u, 0.0, 1.0) * PI) * 0.15
		traj.append(p)
	return traj

## IA en un penal: elige donde lanzarse con la lectura del cuerpo del tirador. cue_point: hacia donde apuntan la carrera y
## la cadera del tirador (no es el resultado: el tiro puede ir a otro lado si el tirador corrige o falla).
func guess_penalty(cue_point: Vector3, ball_pos: Vector3, lead: float, speed_guess: float = 22.0) -> Vector3:
	var p := Vector3(goal_x, 0.0, 0.0)
	if speed_guess < SLOW_SHOT:
		# La carrera y el impulso anuncian un tiro suave: espera y reacciona a la pelota (on_kick).
		return p
	var r: float = rng.randf()
	if r < SpSettings.keeper_read_probability():
		p.z = cue_point.z + rng.randfn(0.0, 0.6)
	elif r < 0.9:
		p.z = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(1.2, half_goal - 0.4)
	else:
		p.z = rng.randfn(0.0, 0.4)
	p.z = clampf(p.z, -half_goal + 0.3, half_goal - 0.3)
	var hr: float = rng.randf()
	p.y = 0.35 if hr < 0.45 else (1.1 if hr < 0.8 else 1.8)
	commit_to(p, ball_pos, lead, speed_guess)
	return p

func _plan_with(traj: PackedVector3Array, min_delay: float) -> void:
	var human := Vector2(Tuning.keeper.hand_latency, Tuning.keeper.hand_speed) if Tuning.keeper != null else Vector2.ZERO
	plan = KeeperPlanner.plan_save(actor.global_position, _yaw(), traj, 1.0 / 30.0, min_delay, 20.0, false, [1.0, 1.2, 1.4], human)
	if plan.is_empty():
		return
	state = State.WAIT_DIVE
	_dive_in = float(plan["delay"])
	if _dive_in <= 0.0:
		_start_dive()

func _start_dive() -> void:
	_dive_in = -1.0
	state = State.DIVE
	actor.stop_moving()
	actor.play_clip(plan["clip"], actor.global_position, facing, 0.08, float(plan["speed"]), 0.0)

# --- Paso ----------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if actor == null or ball == null:
		return
	if state == State.WAIT_DIVE:
		_dive_in -= delta
		if _dive_in <= 0.0:
			_start_dive()
	_watch_step(delta)
	if state == State.HOLD:
		_anchor.global_position = actor.hands_mid() + facing * 0.08
	elif not ball.is_held():
		_check_contact(delta)
	_prev_ball = ball.global_position

func _check_contact(delta: float) -> void:
	var p1: Vector3 = ball.global_position
	var p0: Vector3 = _prev_ball
	var now: int = Time.get_ticks_msec()
	var parts_now: Dictionary = {}
	var best_d: float = INF
	var best: Array = []
	for part in PARTS:
		var c: Vector3 = actor.bone_world(part[0])
		if bool(part[2]):
			var fore: Vector3 = actor.bone_world("mixamorig_LeftForeArm" if String(part[0]).contains("Left") else "mixamorig_RightForeArm")
			var dir: Vector3 = c - fore
			if dir.length() > 0.01:
				c += dir.normalized() * HAND_REACH
		parts_now[part[0]] = c
		var r: float = float(part[1]) + ball.radius
		var q: Vector3 = Geometry3D.get_closest_point_to_segment(c, p0, p1)
		var d: float = q.distance_to(c)
		if d < r and d < best_d:
			best_d = d
			best = [part, c, q]
	if not best.is_empty() and now - _last_contact_ms > 150:
		_resolve(best[0], best[1], best[2], parts_now, delta)
		_last_contact_ms = now
	_prev_parts = parts_now

func _resolve(part: Array, c: Vector3, q: Vector3, parts_now: Dictionary, delta: float) -> void:
	var v: Vector3 = ball.linear_velocity
	var prev_c: Vector3 = _prev_parts.get(part[0], c)
	var part_v: Vector3 = (c - prev_c) / maxf(delta, 1e-3)
	var n: Vector3 = (q - c)
	n = n.normalized() if n.length() > 1e-4 else -v.normalized()
	var vr: Vector3 = v - part_v
	var vn: float = vr.dot(n)
	if vn >= 0.0:
		return
	var is_hand: bool = bool(part[2])
	if is_hand and _can_catch(q, vr, parts_now):
		ball.hold(_anchor, actor)
		_anchor.global_position = q
		state = State.HOLD
		touch_kind = &"catch"
		touched_ball.emit(touch_kind)
		return
	var e: float = 0.28 if is_hand else 0.45
	var vt: Vector3 = vr - n * vn
	var v_new: Vector3 = part_v + vt * 0.8 - n * vn * e
	ball.kick(v_new, ball.angular_velocity * 0.3, actor)
	touch_kind = &"parry" if is_hand else &"body"
	touched_ball.emit(touch_kind)

## Atrapa si la pelota llega a las dos manos, no va demasiado rapida y viene de frente a una altura atrapable.
func _can_catch(q: Vector3, vr: Vector3, parts_now: Dictionary) -> bool:
	if vr.length() > SpSettings.keeper_catch_speed():
		return false
	if q.y < 0.12 or q.y > 2.5:
		return false
	var hl: Vector3 = parts_now.get("mixamorig_LeftHand", Vector3.INF)
	var hr: Vector3 = parts_now.get("mixamorig_RightHand", Vector3.INF)
	if hl.distance_to(q) > 0.42 or hr.distance_to(q) > 0.42:
		return false
	return vr.normalized().dot(facing) < -0.2

func _on_clip_finished(_id: StringName) -> void:
	match state:
		State.DIVE:
			if actor.bone_world(SpActor.HIPS).y < 0.55:
				_getup()
			else:
				state = State.IDLE
				actor.play_loop(_idle_clip, 0.25)
		State.HOLD:
			if actor.bone_world(SpActor.HIPS).y < 0.55:
				_getup()
		State.GETUP:
			state = State.IDLE if not ball.is_held() or ball.holder != actor else State.HOLD
			actor.play_loop(_idle_clip, 0.3)
		State.REACT:
			actor.play_loop(_idle_clip, 0.3)

func _getup() -> void:
	var lie: String = String(SpClips.meta(actor.clip_id).get("lie", ""))
	var pool: Array[StringName] = []
	for id in SpClips.by_role(&"gk_getup"):
		if lie == "" or String(SpClips.meta(id).get("lie", "")) == lie:
			pool.append(id)
	if pool.is_empty():
		pool = SpClips.by_role(&"gk_getup")
	if pool.is_empty():
		return
	var keep_hold: bool = state == State.HOLD
	actor.play_here(pool[rng.randi() % pool.size()], 0.3)
	state = State.HOLD if keep_hold else State.GETUP

## Festejo (atajo) o lamento (le hicieron gol) en el sitio, cuando ya esta de pie.
func react(happy: bool) -> void:
	if state in [State.DIVE, State.WAIT_DIVE]:
		return
	var roles: Array = [&"gk_gesture", &"celebrate", &"clap"] if happy else [&"dejected", &"angry"]
	var id: StringName = SpReactions.pick(roles, rng, 1.5)
	if id == &"":
		return
	if state == State.HOLD:
		return
	state = State.REACT
	actor.play_here(id, 0.3)

func is_busy() -> bool:
	return state in [State.WAIT_DIVE, State.DIVE, State.GETUP]
