class_name Bowling
extends Minigame
## Bowling futbolistico (etapa C): pista 3D con 10 bolos rigidos que caen SOLO por la fuerza del golpe (nada de animacion
## predeterminada: tumbado = inclinado mas de 40 grados o fuera de su lugar). El gesto de siempre apunta a ras del piso
## (direccion + potencia) y la curvatura del trazo le da efecto lateral. Cuadros de verdad: dos tiros por cuadro, entre
## tiros se retiran los bolos caidos y quedan los parados; STRIKE (10 al primer tiro, +5) y SPARE (10 entre los dos, +3,
## puntaje arcade documentado). Se alterna un cuadro cada uno contra la IA (misma fisica, error por dificultad); gana el
## que suma mas. Niveles con pista limpia, obstaculos fijos y guardia movil; canaletas a los costados (tiro perdido).

const SCENE := "res://scenes/minigames/bowling.tscn"
const PIN_R := 0.09
## Bolos a la escala de una pelota de futbol (0,43 kg): livianos y altos, vuelcan con un golpe a 6-8 m/s (medido:
## con 1,3 kg la pelota rebotaba y no caia ninguno).
const PIN_H := 0.5
const STRIKE_BONUS := 5
const SPARE_BONUS := 3
## Error de la IA por dificultad (grados sobre la direccion).
const CPU_ERROR := [4.0, 2.8, 1.8, 1.2, 0.9]

var lane_len: float = 12.0
var lane_w: float = 2.4
var frames_total: int = 3
var pins: Array[RigidBody3D] = []
var pin_home: Array = []
## Cuadro en curso: de quien es, que tiro va (1 o 2) y cuantos bolos tiro en el primer tiro.
var frame_owner: int = 0
var roll_n: int = 1
var first_roll_pins: int = 0
var frames_done: Array = [0, 0]
var strikes: Array = [0, 0]
var spares: Array = [0, 0]

func game_id() -> String:
	return "bowling"

func _build_level() -> void:
	sides = 2
	frames_total = int(def.get("frames", 3))
	max_turns = frames_total * 2 * 2 + 4
	lane_len = float(def.get("lane", 12.0))
	# Pista de madera con canaletas oscuras a los costados (zona perdida) y pasto alrededor.
	static_box(Vector3(60, 1, 30), Vector3(lane_len * 0.5, -0.52, 0), Color(0.16, 0.4, 0.2), Vector3.ZERO, 0.4)
	static_box(Vector3(lane_len + 6, 1, lane_w), Vector3(lane_len * 0.5, -0.49, 0), Color(0.78, 0.6, 0.38), Vector3.ZERO, 0.3)
	for sz in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(lane_len + 6, 0.02, 0.5)
		mi.mesh = pm
		mi.material_override = color_mat(Color(0.12, 0.12, 0.15))
		add_child(mi)
		mi.global_position = Vector3(lane_len * 0.5, 0.012, sz * (lane_w * 0.5 + 0.25))
	for ob in def.get("obstacles", []):
		var od: Dictionary = ob
		var moving: bool = od.has("move")
		var size: Vector3 = BotonCaida._vec(od.get("size", [0.4, 0.5, 0.4]))
		if moving:
			var ab := AnimatableBody3D.new()
			ab.sync_to_physics = false
			ab.collision_layer = Ball.LAYER_WORLD
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = size
			cs.shape = bs
			ab.add_child(cs)
			var m2 := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = size
			m2.mesh = bm
			m2.material_override = color_mat(Color(0.95, 0.55, 0.15))
			ab.add_child(m2)
			add_child(ab)
			ab.global_position = BotonCaida._vec(od.get("pos", [8, 0.25, 0]))
			var mv: Dictionary = od["move"]
			add_mover(ab, BotonCaida._vec(mv.get("axis", [0, 0, 1])), float(mv.get("amp", 0.8)), float(mv.get("speed", 1.2)))
		else:
			static_box(size, BotonCaida._vec(od.get("pos", [8, 0.25, 0])), Color(0.6, 0.6, 0.66), Vector3.ZERO, 0.5)
	_spawn_pins()

## Los 10 bolos en triangulo (o la formacion del nivel), cada uno un cuerpo rigido.
func _spawn_pins() -> void:
	for p in pins:
		if is_instance_valid(p):
			p.queue_free()
	pins.clear()
	pin_home.clear()
	var base_x: float = lane_len
	# Separacion corta: un bolo que cae alcanza al vecino (la reaccion en cadena es la del bowling).
	var gap: float = 0.24
	var spots: Array = []
	match String(def.get("layout", "triangle")):
		"line":
			for i in 10:
				spots.append(Vector3(base_x + (i % 2) * gap, 0, (float(i) - 4.5) * gap))
		"diamond":
			spots = [Vector3(base_x, 0, 0), Vector3(base_x + gap, 0, -gap * 0.5), Vector3(base_x + gap, 0, gap * 0.5),
				Vector3(base_x + gap * 2, 0, -gap), Vector3(base_x + gap * 2, 0, 0), Vector3(base_x + gap * 2, 0, gap),
				Vector3(base_x + gap * 3, 0, -gap * 0.5), Vector3(base_x + gap * 3, 0, gap * 0.5), Vector3(base_x + gap * 4, 0, 0),
				Vector3(base_x + gap * 2, PIN_H + 0.01, 0)]
		_:
			for r in 4:
				for k in r + 1:
					spots.append(Vector3(base_x + float(r) * gap, 0, (float(k) - float(r) * 0.5) * gap))
	for i in mini(spots.size(), 10):
		var pin := RigidBody3D.new()
		pin.mass = 0.3
		pin.collision_layer = Ball.LAYER_WORLD
		pin.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.2
		pm.friction = 0.6
		pin.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = PIN_R
		cyl.height = PIN_H
		cs.shape = cyl
		pin.add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = PIN_R * 0.7
		cm.bottom_radius = PIN_R
		cm.height = PIN_H
		mi.mesh = cm
		mi.material_override = color_mat(Color(0.95, 0.95, 0.97))
		pin.add_child(mi)
		var band := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = PIN_R * 0.86
		bm.bottom_radius = PIN_R * 0.92
		bm.height = 0.06
		band.mesh = bm
		band.position.y = 0.08
		band.material_override = color_mat(Color(0.85, 0.1, 0.1))
		pin.add_child(band)
		add_child(pin)
		pin.global_position = (spots[i] as Vector3) + Vector3(0, PIN_H * 0.5 + 0.002, 0)
		pins.append(pin)
		pin_home.append(pin.global_transform)

## Bolo tumbado: inclinado mas de 40 grados o lejos de su lugar (lo decide la fisica, nunca una animacion).
func pin_down(i: int) -> bool:
	var p: RigidBody3D = pins[i]
	if not p.visible:
		return true
	var up: Vector3 = p.global_transform.basis.y.normalized()
	if up.dot(Vector3.UP) < cos(deg_to_rad(40.0)):
		return true
	return p.global_position.distance_to((pin_home[i] as Transform3D).origin) > 0.4

func down_count() -> int:
	var n: int = 0
	for i in pins.size():
		if pin_down(i):
			n += 1
	return n

func reset_level() -> void:
	frame_owner = Side.USER
	roll_n = 1
	first_roll_pins = 0
	frames_done = [0, 0]
	strikes = [0, 0]
	spares = [0, 0]
	_reset_pins()
	super.reset_level()

func _reset_pins() -> void:
	for i in pins.size():
		var p: RigidBody3D = pins[i]
		p.visible = true
		p.process_mode = Node.PROCESS_MODE_INHERIT
		p.global_transform = pin_home[i]
		p.linear_velocity = Vector3.ZERO
		p.angular_velocity = Vector3.ZERO

## Entre el primer y el segundo tiro: los caidos se retiran, los parados quedan DONDE QUEDARON.
func _clear_fallen() -> void:
	for i in pins.size():
		if pin_down(i):
			var p: RigidBody3D = pins[i]
			p.visible = false
			p.process_mode = Node.PROCESS_MODE_DISABLED

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0, ball.radius if ball != null else 0.11, 0)

func _aim_point(_s: int) -> Vector3:
	return Vector3(lane_len + 0.3, 0.5, 0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(lane_len, Vector2(8.0, 20.0), false, lane_w, 3.0, ball.radius)

# --- Gesto: a ras del piso con efecto ------------------------------------------------------------------------------------

func bowl_velocity(ground_target: Vector3, power: float, curve: float) -> Array:
	var dir := Vector3(ground_target.x - _ball_spot(0).x, 0, ground_target.z - _ball_spot(0).z)
	dir = dir.normalized() if dir.length() > 0.05 else Vector3(1, 0, 0)
	var speed: float = lerpf(8.0, 20.0, clampf(power, 0.0, 1.0))
	var v: Vector3 = dir * speed + Vector3.UP * 0.4
	# Efecto: giro vertical (curva el recorrido por Magnus mientras la pelota no rueda pegada).
	var w: Vector3 = ball.rolling_spin(v) * 0.8 + Vector3.UP * clampf(curve, -1.0, 1.0) * 14.0
	return [v, w]

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
		var vw: Array = bowl_velocity(_ground(gesture.last_px()), GestureShotModel.power_from(f, gesture.tuning),
			clampf(float(f["curvature"]) * 2.0, -1.0, 1.0))
		apply_intent({"side": Side.USER, "v": vw[0], "w": vw[1]})

func _ground(px: Vector2) -> Vector3:
	var o: Vector3 = cam.project_ray_origin(px)
	var dd: Vector3 = cam.project_ray_normal(px)
	if dd.y > -1e-4:
		return Vector3(lane_len, 0, 0)
	var t: float = -o.y / dd.y
	var q: Vector3 = o + dd * t
	return Vector3(q.x, 0, q.z)

func _update_preview(delta: float) -> void:
	_preview_t -= delta
	if _preview_t > 0.0 or gesture.count() < 3:
		return
	_preview_t = 1.0 / 15.0
	var f: Dictionary = gesture.features()
	if float(f["length"]) < gesture.tuning.min_length * 0.6:
		preview.hide_path()
		return
	var vw: Array = bowl_velocity(_ground(gesture.last_px()), GestureShotModel.power_from(f, gesture.tuning), clampf(float(f["curvature"]) * 2.0, -1.0, 1.0))
	if GraphicsSettings.show_aim_line:
		var traj: PackedVector3Array = BallPredictor.trajectory(_ball_spot(0), vw[0], 3.0, 1.0 / 30.0, vw[1], true)
		preview.show_path(traj, lane_len + 2.0, (vw[0] as Vector3).length() / 20.0, cam.global_position, traj[traj.size() - 1] if not traj.is_empty() else Vector3.ZERO)
	else:
		preview.hide_path()
	hud.show_gesture((vw[0] as Vector3).length() / 20.0, 0.1, clampf(float(f["curvature"]) * 2.0, -1.0, 1.0), "Bola")

# --- Reglas ---------------------------------------------------------------------------------------------------------------

func _start_turn() -> void:
	side = frame_owner
	if roll_n == 1:
		_reset_pins()
	else:
		_clear_fallen()
	super._start_turn()
	hud.set_hint("Cuadro %d de %d · tiro %d%s" % [frames_done[frame_owner] + 1, frames_total, roll_n,
		" · tuyo" if frame_owner == Side.USER else " · de la CPU"])

func _settling() -> bool:
	for i in pins.size():
		var p: RigidBody3D = pins[i]
		if p.visible and not p.sleeping and p.linear_velocity.length() > 0.25:
			return true
	return false

func _flight_check(_delta: float) -> String:
	var p: Vector3 = ball.global_position
	if p.x > lane_len + 4.0 and not _settling():
		return "paso"
	if absf(p.z) > lane_w * 0.5 + 0.1 and p.x < lane_len - 1.0:
		# Canaleta: el tiro sigue hasta que todo se asiente, pero ya no vuelve a la pista.
		if not _settling() and ball.linear_velocity.length() < 2.0:
			return "canaleta"
	if _t > 0.8 and not _settling() and ball.linear_velocity.length() < SLOW_SPEED:
		return "quieta"
	return ""

func _on_resolved(s: int, _r: String) -> void:
	var down: int = down_count()
	if roll_n == 1:
		first_roll_pins = down
		if down >= pins.size():
			# STRIKE: cuadro cerrado al primer tiro.
			strikes[s] += 1
			points[s] += down + STRIKE_BONUS
			if s == Side.USER and not fast and not bool(def.get("practice", false)):
				Achievements.event(&"strike")
			_finish_frame(s, "¡STRIKE! +%d" % STRIKE_BONUS)
		else:
			roll_n = 2
			hud.show_banner("%d bolos" % down, Color(1.0, 0.85, 0.35), "Segundo tiro")
	else:
		var bonus: int = SPARE_BONUS if down >= pins.size() else 0
		if bonus > 0:
			spares[s] += 1
		points[s] += down + bonus
		var txt: String = ("¡SPARE! +%d" % bonus) if bonus > 0 else ("%d bolos" % down)
		_finish_frame(s, txt)
	_refresh_score()

func _finish_frame(s: int, txt: String) -> void:
	frames_done[s] += 1
	roll_n = 1
	frame_owner = 1 - s
	hud.show_banner(txt, Color(0.35, 1.0, 0.45) if txt.begins_with("¡") else Color(1.0, 0.85, 0.35), "")
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if txt.begins_with("¡") else SpReactions.HAPPY_DEFENDER, rng, 1.5, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)

func _next_side() -> int:
	return frame_owner

func _check_winner() -> int:
	if frames_done[0] >= frames_total and frames_done[1] >= frames_total:
		if points[0] == points[1]:
			return Side.CPU
		return Side.USER if points[0] > points[1] else Side.CPU
	return -1

func _cpu_intent() -> Dictionary:
	# Apunta al primer bolo parado (o al centro de los parados en el segundo tiro), a ras y fuerte, con su error.
	var target := Vector3(lane_len, 0, 0)
	var standing: Array = []
	for i in pins.size():
		if not pin_down(i):
			standing.append(pins[i].global_position)
	if not standing.is_empty():
		target = Vector3.ZERO
		for q in standing:
			target += q
		target /= float(standing.size())
		target.y = 0.0
	var vw: Array = bowl_velocity(target, 0.75, 0.0)
	var err: float = deg_to_rad(CPU_ERROR[SpSettings.level()])
	return {"v": (vw[0] as Vector3).rotated(Vector3.UP, rng.randf_range(-err, err)), "w": vw[1]}

func final_score() -> int:
	return points[0] * 10 + strikes[0] * 20 + spares[0] * 10

func _result_text(r: String) -> Array:
	if r == "canaleta":
		return ["Canaleta", Color(1.0, 0.5, 0.4), "Tiro perdido"]
	return ["", Color.WHITE]

func _refresh_score() -> void:
	hud.set_score_text("Vos %d - %d CPU · cuadro %d/%d" % [points[0], points[1], mini(frames_done[0] + 1, frames_total), frames_total])
