class_name FootPool
extends Minigame
## FootPool (etapa C, catalogo #13 traducido al futbol): cancha rectangular con paredes que rebotan, TU pelota de futbol
## y seis pelotas objetivo fisicas (3 azules tuyas, 3 rojas de la IA). Nada de taco: pateas tu pelota con el gesto de
## siempre (a ras, direccion + potencia) y las demas se mueven SOLO por colisiones reales (carambolas y bandas incluidas).
## Reglas: por turnos; meter una pelota PROPIA en cualquiera de las dos bocas suma 100 y repite turno; meter una del
## rival le regala 100; meter tu pelota de juego (la «blanca») pasa el turno y se repone al centro; tocar 2 o mas
## objetivos en un mismo tiro suma 20 de carambola. Gana el primero que embocó sus tres (el puntaje decide la medalla).
## La IA planifica con la geometria (punto fantasma detras de la pelota objetivo, hacia la boca) y erra por dificultad.

const SCENE := "res://scenes/minigames/footpool.tscn"
const POT_POINTS := 100
const CAROM_BONUS := 20
const CPU_ERROR := [5.0, 3.5, 2.2, 1.5, 1.0]

var court_l: float = 11.0
var court_w: float = 6.5
var mouth_w: float = 1.3
## Pelotas objetivo: {body, team (0 azul / 1 rojo), potted, home}
var balls: Array = []
var caroms_this_shot: int = 0
var potted_this_shot: Array = []
var cue_potted: bool = false
var extra_turn: bool = false

func game_id() -> String:
	return "footpool"

func _build_level() -> void:
	sides = 2
	max_turns = int(def.get("max_turns", 30))
	court_l = float(def.get("len", 11.0))
	court_w = float(def.get("width", 6.5))
	# Piso de la cancha y paredes con hueco (boca) en el centro de cada cabecera.
	static_box(Vector3(court_l + 8, 1, court_w + 8), Vector3(0, -0.5, 0), Color(0.13, 0.42, 0.25), Vector3.ZERO, 0.5)
	var h: float = 0.35
	for sz in [-1.0, 1.0]:
		static_box(Vector3(court_l, h, 0.25), Vector3(0, h * 0.5, sz * (court_w * 0.5 + 0.12)), Color(0.5, 0.35, 0.2), Vector3.ZERO, 0.75)
	for sx in [-1.0, 1.0]:
		var seg: float = (court_w - mouth_w) * 0.5
		for sz in [-1.0, 1.0]:
			static_box(Vector3(0.25, h, seg), Vector3(sx * (court_l * 0.5 + 0.12), h * 0.5, sz * (mouth_w * 0.5 + seg * 0.5)), Color(0.5, 0.35, 0.2), Vector3.ZERO, 0.75)
		# La boca: un marco que la señala y una fosa detras (la pelota que entra cae y queda embocada).
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.0, mouth_w)
		mi.mesh = pm
		mi.material_override = color_mat(Color(0.05, 0.05, 0.08))
		add_child(mi)
		mi.global_position = Vector3(sx * (court_l * 0.5 + 0.6), 0.02, 0)
	var spots: Array = def.get("balls", [[-1.5, -1.2, 0], [-1.5, 1.2, 0], [-3.0, 0, 0], [1.5, -1.2, 1], [1.5, 1.2, 1], [3.0, 0, 1]])
	for sp in spots:
		var team: int = int(sp[2])
		var b := RigidBody3D.new()
		b.mass = 0.43
		b.collision_layer = Ball.LAYER_WORLD
		b.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
		b.linear_damp = 0.55
		b.angular_damp = 0.4
		b.contact_monitor = true
		b.max_contacts_reported = 4
		var pm2 := PhysicsMaterial.new()
		pm2.bounce = 0.75
		pm2.friction = 0.4
		b.physics_material_override = pm2
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.11
		cs.shape = sph
		b.add_child(cs)
		var mi2 := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.22
		mi2.mesh = sm
		mi2.material_override = color_mat(Color(0.15, 0.35, 0.95) if team == 0 else Color(0.9, 0.12, 0.12), 0.15)
		b.add_child(mi2)
		add_child(b)
		b.global_position = Vector3(float(sp[0]), 0.112, float(sp[1]))
		balls.append({"body": b, "team": team, "potted": false, "home": b.global_transform})
	ball.body_entered.connect(_on_cue_hit)

func _on_cue_hit(body: Node) -> void:
	if state != State.FLIGHT:
		return
	for e in balls:
		if body == e["body"] and not bool(e["potted"]):
			if not potted_this_shot.has(body) and not _touched.has(body):
				_touched.append(body)
				if _touched.size() >= 2:
					caroms_this_shot += 1
			return

var _touched: Array = []

func reset_level() -> void:
	for e in balls:
		e["potted"] = false
		var b: RigidBody3D = e["body"]
		b.visible = true
		b.process_mode = Node.PROCESS_MODE_INHERIT
		b.global_transform = e["home"]
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO
	super.reset_level()

var _cue := Vector3(0, 0.11, 0)

## La pelota de juego sigue donde quedo (se repone al centro solo si entro en una boca).
func _ball_spot(_s: int) -> Vector3:
	return _cue

func _aim_point(s: int) -> Vector3:
	return Vector3(court_l * 0.5 * (1.0 if s == Side.USER else -1.0), 0.4, 0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(court_l * 0.5, Vector2(5.0, 16.0), false, court_w * 0.5, 2.0, ball.radius)

## La pelota de juego se patea a ras con el gesto (direccion + potencia).
func pool_velocity(ground_target: Vector3, power: float) -> Array:
	var from: Vector3 = ball.global_position
	var dir := Vector3(ground_target.x - from.x, 0, ground_target.z - from.z)
	dir = dir.normalized() if dir.length() > 0.05 else Vector3(1, 0, 0)
	var speed: float = lerpf(5.0, 16.0, clampf(power, 0.0, 1.0))
	return [dir * speed, ball.rolling_spin(dir * speed)]

func _on_press(pos: Vector2, pressed: bool) -> void:
	if state != State.AIM or side != Side.USER:
		return
	if pressed:
		_swiping = true
		gesture.tuning = GestureTuning.current()
		gesture.begin(pos, _now(), get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0)
		_preview_t = 0.0
	elif _swiping:
		_swiping = false
		gesture.finish(pos, _now())
		hud.set_trail(PackedVector2Array())
		preview.hide_path()
		hud.hide_gesture()
		var f: Dictionary = gesture.features()
		if float(f["length"]) < gesture.tuning.min_length * 0.6:
			return
		var o: Vector3 = cam.project_ray_origin(gesture.last_px())
		var dn: Vector3 = cam.project_ray_normal(gesture.last_px())
		var target: Vector3 = ball.global_position + Vector3(1, 0, 0)
		if dn.y < -1e-4:
			var tt: float = -o.y / dn.y
			target = o + dn * tt
		var vw: Array = pool_velocity(Vector3(target.x, 0, target.z), GestureShotModel.power_from(f, gesture.tuning))
		apply_intent({"side": Side.USER, "v": vw[0], "w": vw[1]})

func _update_preview(delta: float) -> void:
	_preview_t -= delta
	if _preview_t > 0.0 or gesture.count() < 3 or not GraphicsSettings.show_aim_line:
		if not GraphicsSettings.show_aim_line:
			preview.hide_path()
		return
	_preview_t = 1.0 / 15.0
	var f: Dictionary = gesture.features()
	var o: Vector3 = cam.project_ray_origin(gesture.last_px())
	var dn: Vector3 = cam.project_ray_normal(gesture.last_px())
	if dn.y > -1e-4 or float(f["length"]) < gesture.tuning.min_length * 0.6:
		return
	var tt: float = -o.y / dn.y
	var q: Vector3 = o + dn * tt
	var vw: Array = pool_velocity(Vector3(q.x, 0, q.z), GestureShotModel.power_from(f, gesture.tuning))
	var traj: PackedVector3Array = BallPredictor.trajectory(ball.global_position, vw[0], 2.0, 1.0 / 30.0, vw[1], true)
	preview.show_path(traj, court_l, (vw[0] as Vector3).length() / 16.0, cam.global_position, traj[traj.size() - 1] if not traj.is_empty() else Vector3.ZERO)

# --- Reglas ---------------------------------------------------------------------------------------------------------------

func _start_turn() -> void:
	caroms_this_shot = 0
	cue_potted = false
	potted_this_shot = []
	_touched = []
	super._start_turn()
	hud.set_hint("Tus pelotas son las AZULES: metelas en cualquiera de las dos bocas" if side == Side.USER else "Juega la CPU…")

func _in_mouth(p: Vector3) -> bool:
	return absf(p.x) > court_l * 0.5 + 0.05 and absf(p.z) < mouth_w * 0.5 + 0.05

func _settling() -> bool:
	for e in balls:
		var b: RigidBody3D = e["body"]
		if b.visible and not b.sleeping and b.linear_velocity.length() > 0.2:
			return true
	return false

func _level_step(_delta: float) -> void:
	if state != State.FLIGHT:
		return
	for e in balls:
		if bool(e["potted"]):
			continue
		var b: RigidBody3D = e["body"]
		if _in_mouth(b.global_position) or b.global_position.y < -0.5:
			e["potted"] = true
			potted_this_shot.append(b)
			b.visible = false
			b.process_mode = Node.PROCESS_MODE_DISABLED
			if not fast:
				Sfx.play(&"cheer", 0.4)
	if _in_mouth(ball.global_position):
		cue_potted = true

func _flight_check(_delta: float) -> String:
	if _t > 0.8 and not _settling() and (ball.linear_velocity.length() < SLOW_SPEED or cue_potted):
		return "mesa"
	return ""

func _on_resolved(s: int, _r: String) -> void:
	extra_turn = false
	var own: int = 0
	var wrong: int = 0
	for b in potted_this_shot:
		for e in balls:
			if e["body"] == b:
				if int(e["team"]) == s:
					own += 1
				else:
					wrong += 1
	points[s] += own * POT_POINTS + caroms_this_shot * CAROM_BONUS
	points[1 - s] += wrong * POT_POINTS
	var lines: PackedStringArray = []
	if own > 0:
		lines.append("%d propia(s): +%d" % [own, own * POT_POINTS])
	if wrong > 0:
		lines.append("¡Metiste una del rival! +%d para él" % (wrong * POT_POINTS))
	if caroms_this_shot > 0:
		lines.append("Carambola: +%d" % (caroms_this_shot * CAROM_BONUS))
	if cue_potted:
		lines.append("Tu pelota entró: se repone y pasa el turno")
		ball.reset_at(Vector3(0, ball.radius, 0))
		_cue = Vector3(0, ball.radius, 0)
	else:
		var p: Vector3 = ball.global_position
		_cue = Vector3(clampf(p.x, -court_l * 0.5 + 0.2, court_l * 0.5 - 0.2), ball.radius, clampf(p.z, -court_w * 0.5 + 0.2, court_w * 0.5 - 0.2))
	extra_turn = own > 0 and wrong == 0 and not cue_potted
	if extra_turn:
		lines.append("¡Turno extra!")
	if not lines.is_empty():
		hud.show_banner("" if lines.is_empty() else lines[0], Color(0.35, 1.0, 0.45) if own > 0 else Color(1.0, 0.85, 0.35), "\n".join(lines.slice(1)))
	_refresh_score()

func _next_side() -> int:
	return side if extra_turn else 1 - side

func remaining(team: int) -> int:
	var n: int = 0
	for e in balls:
		if int(e["team"]) == team and not bool(e["potted"]):
			n += 1
	return n

func _check_winner() -> int:
	if remaining(0) == 0:
		return Side.USER
	if remaining(1) == 0:
		return Side.CPU
	return -1

## IA: punto fantasma detras de su pelota objetivo mas comoda, hacia la boca mas cercana (pura geometria, sin ver el
## futuro), con error por dificultad.
func _cpu_intent() -> Dictionary:
	return _cpu_intent_for(Side.CPU)

## Planificacion geometrica para cualquier equipo (tambien la usan las pruebas para el lado del usuario).
func _cpu_intent_for(team: int) -> Dictionary:
	var best: Dictionary = {}
	var best_cost: float = INF
	for e in balls:
		if int(e["team"]) != team or bool(e["potted"]):
			continue
		var op: Vector3 = (e["body"] as RigidBody3D).global_position
		for sx in [-1.0, 1.0]:
			var mouth := Vector3(sx * (court_l * 0.5 + 0.3), 0, 0)
			var to_mouth: Vector3 = (mouth - op).normalized()
			var ghost: Vector3 = op - to_mouth * 0.22
			var cue: Vector3 = ball.global_position
			# El tiro tiene que empujarla HACIA la boca: la blanca debe venir desde el lado contrario.
			var align: float = (ghost - cue).normalized().dot(to_mouth)
			if align < 0.3:
				continue
			var cost: float = cue.distance_to(ghost) + op.distance_to(mouth) * 0.5 - align * 2.0
			if cost < best_cost:
				best_cost = cost
				best = {"ghost": ghost, "dist": cue.distance_to(ghost) + op.distance_to(mouth)}
	if best.is_empty():
		# Sin tiro comodo: golpe suave al centro de sus pelotas (reacomoda sin regalar).
		var c := Vector3.ZERO
		var n: int = 0
		for e in balls:
			if int(e["team"]) == team and not bool(e["potted"]):
				c += (e["body"] as RigidBody3D).global_position
				n += 1
		best = {"ghost": c / maxf(n, 1.0), "dist": 3.0}
	var speed: float = clampf(float(best["dist"]) * 1.1 + 2.0, 5.0, 14.0)
	var dir := Vector3((best["ghost"] as Vector3).x - ball.global_position.x, 0, (best["ghost"] as Vector3).z - ball.global_position.z).normalized()
	var err: float = deg_to_rad(CPU_ERROR[SpSettings.level()])
	dir = dir.rotated(Vector3.UP, rng.randf_range(-err, err))
	return {"v": dir * speed, "w": ball.rolling_spin(dir * speed)}

func final_score() -> int:
	return points[0] + (100 if winner == Side.USER else 0)

func _result_text(_r: String) -> Array:
	return ["", Color.WHITE]

func _refresh_score() -> void:
	hud.set_score_text("Vos %d (%d por meter) - CPU %d (%d)" % [points[0], remaining(0), points[1], remaining(1)])
