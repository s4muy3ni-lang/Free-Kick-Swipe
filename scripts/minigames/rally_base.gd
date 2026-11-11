class_name RallyBase
extends Minigame
## Base de los modos de peloteo (etapa B): dos jugadores (usuario e IA) que se pasan la pelota por el aire. Reutiliza el
## gesto del juego (el trazo marca hacia DONDE va el pase: el final del trazo es un punto del piso; el largo/velocidad dan
## la potencia y un final ascendente lo eleva), los jugadores animados (RallyPlayer: recepciones por altura con contacto
## real) y la fisica de la pelota. La IA juega con las mismas reglas: corre a la caida prevista con error y retardo por
## dificultad y devuelve con error de punteria. Arquitectura por intenciones (igual que el resto de los minijuegos):
## lista para sumar mas jugadores por lado y, mas adelante, en linea (sin implementar).
##
## El flujo es propio (custom_flow): SERVE (saque del que corresponde) -> RALLY (toques) -> POINT (tanto) -> SERVE...

enum Rally { SERVE, RALLY, POINT }

const PASS_SPEED := Vector2(6.5, 13.5)
const PITCH_RANGE := Vector2(deg_to_rad(24.0), deg_to_rad(62.0))

var rally_state: int = Rally.SERVE
var serve_side: int = Side.USER
var players: Array[RallyPlayer] = []
## Intencion pendiente del usuario para su proximo toque: {target, speed} (la dibuja con el dedo en cualquier momento).
var user_intent: Dictionary = {}
var last_toucher: int = -1
var touches: Array = [0, 0]
var rally_hits: int = 0
## Segundos desde el ultimo toque (el impulso recien se integra al paso siguiente: la pelota «muerta» se juzga pasado esto).
var rally_age: float = 0.0
var point_t: float = 0.0
var _marker: MeshInstance3D
var points_to_win: int = 3

func _ready() -> void:
	custom_flow = true
	# La base arranca sola en modo rapido; aca primero hay que armar los jugadores de peloteo.
	var was_fast: bool = fast
	fast = false
	super._ready()
	fast = was_fast
	for s in 2:
		var rp := RallyPlayer.new()
		rp.name = "Rally%d" % s
		add_child(rp)
		rp.setup(shooters[s].actor, ball)
		rp.rng.seed = match_seed + 31 * s
		if s == Side.CPU:
			rp.move_err = [0.9, 0.6, 0.35, 0.25, 0.18][SpSettings.level()]
			rp.react_delay = [0.5, 0.35, 0.22, 0.16, 0.12][SpSettings.level()]
		rp.touched.connect(_on_touch.bind(s))
		players.append(rp)
	ball.floor_bounce.connect(_on_floor)
	_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.22
	tm.outer_radius = 0.34
	_marker.mesh = tm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.85, 0.2, 0.85)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = mm
	_marker.visible = false
	add_child(_marker)
	if fast:
		start_match()

## Lugar de cada jugador en la cancha (las subclases definen la geometria).
func home(_s: int) -> Vector3:
	return Vector3.ZERO

## Encuadre: los dos jugadores enteros y la pelota.
func frame_points() -> Array:
	return [home(0), home(0) + Vector3.UP * 1.9, home(1), home(1) + Vector3.UP * 1.9]

func points_text() -> String:
	return "Vos %d - %d CPU" % [points[0], points[1]]

func start_match() -> void:
	points_to_win = int(def.get("points_to_win", 3))
	super.start_match()

## El saque y el peloteo los maneja el flujo propio; _start_turn de la base no aplica.
func _start_turn() -> void:
	_start_serve()

func _start_serve() -> void:
	rally_state = Rally.SERVE
	user_intent = {}
	last_toucher = -1
	touches = [0, 0]
	rally_hits = 0
	for s in 2:
		players[s].cancel()
		_place_shooter(s)
	ball.reset_at(_serve_spot())
	_marker.visible = false
	_frame_camera(turn_n == 0)
	turn_started.emit(serve_side)
	hud.set_actions([[&"restart", "Reiniciar"]])
	if serve_side == Side.USER:
		hud.set_hint(String(def.get("hint", "Sacás vos: trazá hacia dónde mandás la pelota (el final del trazo es el punto del piso)")))
	else:
		hud.set_hint("Saca la CPU…")
	_t = 0.0

func _serve_spot() -> Vector3:
	return home(serve_side) + Vector3(0, ball.radius, 0)

func _place_shooter(s: int) -> void:
	var sh: SpShooter = shooters[s]
	var aim: Vector3 = home(1 - s) - home(s)
	sh.actor.visible = true
	sh.actor.stop_moving()
	sh.actor.global_position = home(s) - aim.normalized() * 0.6
	sh.actor.set_facing(aim)

## Pase con el gesto: el final del trazo marca el punto del piso; potencia y elevacion salen del trazo.
func pass_velocity(ground_target: Vector3, power: float, loft: float) -> Vector3:
	var from: Vector3 = ball.global_position
	var dir := Vector3(ground_target.x - from.x, 0, ground_target.z - from.z)
	if dir.length() < 0.1:
		dir = (home(1 - Side.USER) - from) * Vector3(1, 0, 1)
	dir = dir.normalized()
	var speed: float = lerpf(PASS_SPEED.x, PASS_SPEED.y, clampf(power, 0.0, 1.0))
	var pitch: float = lerpf(PITCH_RANGE.x, PITCH_RANGE.y, clampf(loft, 0.0, 1.0))
	return dir * cos(pitch) * speed + Vector3.UP * sin(pitch) * speed

func ground_point(px: Vector2) -> Vector3:
	var o: Vector3 = cam.project_ray_origin(px)
	var d: Vector3 = cam.project_ray_normal(px)
	if d.y > -1e-4:
		return ball.global_position + Vector3(d.x, 0, d.z).normalized() * 5.0
	var t: float = -o.y / d.y
	var q: Vector3 = o + d * t
	return Vector3(q.x, 0, q.z)

## Donde y cuando pica la pelota segun la fisica (primer punto descendente a ras del piso), o [] si no pica en 4 s.
static func landing_of(pos: Vector3, vel: Vector3, spin: Vector3) -> Array:
	var traj: PackedVector3Array = BallPredictor.trajectory(pos, vel, 4.0, 1.0 / 30.0, spin, true)
	for i in range(1, traj.size()):
		if traj[i].y <= 0.24 and traj[i].y < traj[i - 1].y:
			return [traj[i], float(i) / 30.0]
	return []

# --- Entrada del usuario: el trazo vale en cualquier momento de su jugada -------------------------------------------------

func _on_press(pos: Vector2, pressed: bool) -> void:
	if state == State.OVER or rally_state == Rally.POINT:
		return
	if pressed:
		_swiping = true
		gesture.tuning = GestureTuning.current()
		gesture.begin(pos, _now(), get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0)
	elif _swiping:
		_swiping = false
		gesture.finish(pos, _now())
		hud.set_trail(PackedVector2Array())
		var f: Dictionary = gesture.features()
		if float(f["length"]) < gesture.tuning.min_length * 0.6:
			return
		var power: float = GestureShotModel.power_from(f, gesture.tuning)
		var ed: Vector2 = f["end_dir"]
		var loft: float = clampf(-ed.y + 0.25, 0.0, 1.0)
		set_user_intent(ground_point(gesture.last_px()), power, loft)

func _on_drag(pos: Vector2) -> void:
	if _swiping and gesture.add(pos, _now()):
		hud.set_trail(gesture.points_px())

## La intencion del usuario (tambien la usan las pruebas): hacia donde y con que fuerza va su proximo toque. En el saque
## patea ya; durante el peloteo queda armada para el contacto real.
func set_user_intent(ground_target: Vector3, power: float, loft: float) -> void:
	var v: Vector3 = pass_velocity(ground_target, power, loft)
	if rally_state == Rally.SERVE and serve_side == Side.USER:
		_do_serve(Side.USER, v)
		return
	user_intent = {"target": Vector3(ground_target.x, 0.15, ground_target.z), "speed": v.length()}
	if players[Side.USER].busy():
		players[Side.USER].order = user_intent

func _do_serve(s: int, v: Vector3) -> void:
	rally_state = Rally.RALLY
	rally_age = 0.0
	last_toucher = s
	touches[s] = 1
	ball.kick(v, Vector3.ZERO, players[s].actor)
	intents.append({"side": s, "v": v, "turn": turn_n})
	_after_ball_sent(s, v)
	hud.set_hint("")

## Con la pelota recien tocada: calcula la caida con la velocidad de salida v y le avisa al que la juega (reglas de cada
## modo). v se pasa explicita porque el impulso del toque recien se integra en el paso siguiente.
func _after_ball_sent(_toucher: int, _v: Vector3) -> void:
	pass

func _on_touch(kind: StringName, s: int) -> void:
	if kind == &"miss":
		return
	last_toucher = s
	touches[s] += 1
	touches[1 - s] = 0
	rally_hits += 1
	rally_age = 0.0
	if s == Side.USER:
		user_intent = {}
	# El toque ya salio: la caida se calcula con la velocidad de salida real del toque.
	_after_ball_sent(s, players[s].last_out)

func _on_floor(pos: Vector3, _speed: float) -> void:
	if state == State.OVER or rally_state != Rally.RALLY or rally_age < 0.15:
		return
	_on_ground(pos)

## Pica el piso: cada modo decide el tanto.
func _on_ground(_pos: Vector3) -> void:
	pass

func give_point(to: int, why: String) -> void:
	if rally_state == Rally.POINT or state == State.OVER:
		return
	rally_state = Rally.POINT
	point_t = 0.0
	points[to] += 1
	_marker.visible = false
	for s in 2:
		players[s].cancel()
	_refresh_score()
	var mine: bool = to == Side.USER
	hud.show_banner("¡PUNTO!" if mine else "PUNTO RIVAL", Color(0.35, 1.0, 0.45) if mine else Color(1.0, 0.45, 0.4), why)
	var cel: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if mine else SpReactions.MISS_SHOOTER, rng, 1.5, 1.0)
	if cel != &"":
		players[Side.USER].actor.play_here(cel, 0.3)
	var cel2: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if not mine else SpReactions.MISS_SHOOTER, rng, 1.5, 1.0)
	if cel2 != &"":
		players[Side.CPU].actor.play_here(cel2, 0.3)
	# Saca el que perdio el punto.
	serve_side = 1 - to

func _custom_step(delta: float) -> void:
	match rally_state:
		Rally.SERVE:
			if serve_side == Side.CPU and _t > (0.1 if fast else 1.0):
				_do_serve(Side.CPU, _cpu_serve())
		Rally.RALLY:
			rally_age += delta
			_rally_step(delta)
		Rally.POINT:
			point_t += delta
			if point_t >= (0.25 if fast else 2.2):
				hud.hide_banner()
				if points[0] >= points_to_win or points[1] >= points_to_win:
					_end_match(Side.USER if points[0] > points[1] else Side.CPU)
				else:
					turn_n += 1
					_start_serve()

func _cpu_serve() -> Vector3:
	return pass_velocity(home(Side.USER) + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)), 0.4, 0.75)

func _rally_step(_delta: float) -> void:
	pass

func _result_text(_r: String) -> Array:
	return ["", Color.WHITE]

func final_score() -> int:
	return points[0] * 100 + (50 if winner == Side.USER and points[1] == 0 else 0)

func _refresh_score() -> void:
	hud.set_score_text(points_text())
