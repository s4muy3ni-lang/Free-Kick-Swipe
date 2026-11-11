class_name Minigolf
extends Minigame
## Minigolf futbolistico (etapa A3): meter la pelota en el hoyo con la menor cantidad de golpes. Cada golpe usa la fisica
## real de la pelota (rodadura, rebotes, rampas); el gesto del dedo APUNTA A RAS DEL PISO: el final del trazo marca el
## punto del piso hacia donde sale, el largo/velocidad dan la potencia y un final del trazo hacia arriba levanta un poco
## la pelota (tope ~20 grados: nada de trayectoria vertical obligatoria). La vista previa usa el mismo calculo.
##
## El hoyo captura la pelota solo si pasa por encima DESPACIO (como en el golf real: rapida lo salta). Zonas de arena
## frenan la rodadura. Fuera de limites o al vacio: un golpe de penalizacion y se repone donde se jugo. Cada nivel tiene
## par, tope de golpes (3x par), puntos por resultado (aguila/birdie/par/bogey), record y medallas (PlayerProgress).
##
## Niveles en resources/minigames/minigames.json ("minigolf"): tee, hole, par, bounds [x0,z0,x1,z1], walls/ramps (cajas),
## tunnels (dos paredes y techo), sand (rectangulos que frenan), platforms, movers (obstaculos que van y vienen) y guide
## (puntos de paso que usan las pruebas de resolubilidad; no se muestran).

const SCENE := "res://scenes/minigames/minigolf.tscn"
const HOLE_R := 0.24
const CAPTURE_SPEED := 2.4
const SPEED_MIN := 3.0
const SPEED_MAX := 17.0
const LOFT_MAX := deg_to_rad(20.0)
## Puntos por golpes respecto del par: -2 o mejor, -1, 0, +1, peor.
const POINTS := [60, 45, 30, 15, 5]

var tee := Vector3.ZERO
var hole := Vector3.ZERO
var par: int = 3
var bounds := Rect2(-5, -10, 40, 20)
var sand: Array = []
var penalties: int = 0
var holed: bool = false
var _spot := Vector3.ZERO
var _flag: Node3D

func game_id() -> String:
	return "minigolf"

func strokes() -> int:
	return int(shots[0]) + penalties

func _build_level() -> void:
	sides = 1
	par = int(def.get("par", 3))
	max_turns = par * 3
	tee = BotonCaida._vec(def.get("tee", [0, 0, 0]))
	hole = BotonCaida._vec(def.get("hole", [14, 0, 0]))
	var b: Array = def.get("bounds", [-4, -8, 24, 8])
	bounds = Rect2(float(b[0]), float(b[1]), float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
	_spot = tee + Vector3.UP * 0.11
	# Cesped del recorrido: un piso por rectangulo (floors) o uno solo que cubre los limites.
	var floors: Array = def.get("floors", [[bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y]])
	for f in floors:
		var fr: Array = f
		var size := Vector3(float(fr[2]) - float(fr[0]), 1.0, float(fr[3]) - float(fr[1]))
		static_box(size, Vector3((float(fr[0]) + float(fr[2])) * 0.5, -0.5, (float(fr[1]) + float(fr[3])) * 0.5), Color(0.18, 0.52, 0.24), Vector3.ZERO, 0.3)
	for w in def.get("walls", []):
		_box_from(w, Color(0.72, 0.6, 0.45), 0.55)
	for r in def.get("ramps", []):
		_box_from(r, Color(0.3, 0.6, 0.35), 0.2)
	for pl in def.get("platforms", []):
		_box_from(pl, Color(0.22, 0.56, 0.3), 0.25)
	for t in def.get("tunnels", []):
		var td: Dictionary = t
		var c: Vector3 = BotonCaida._vec(td.get("pos", [8, 0, 0]))
		var L: float = float(td.get("len", 2.5))
		var w2: float = float(td.get("width", 1.0)) * 0.5
		var h: float = float(td.get("h", 0.9))
		var yaw: float = deg_to_rad(float(td.get("yaw", 0.0)))
		var rot := Vector3(0, yaw, 0)
		var right := Vector3(sin(yaw), 0, cos(yaw))
		static_box(Vector3(L, h, 0.18), c + right * (w2 + 0.09) + Vector3.UP * h * 0.5, Color(0.6, 0.6, 0.66), rot, 0.5)
		static_box(Vector3(L, h, 0.18), c - right * (w2 + 0.09) + Vector3.UP * h * 0.5, Color(0.6, 0.6, 0.66), rot, 0.5)
		static_box(Vector3(L, 0.15, w2 * 2.0 + 0.36), c + Vector3.UP * (h + 0.07), Color(0.6, 0.6, 0.66), rot, 0.5)
	for sd in def.get("sand", []):
		var sr: Array = sd
		sand.append(Rect2(float(sr[0]), float(sr[1]), float(sr[2]) - float(sr[0]), float(sr[3]) - float(sr[1])))
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(float(sr[2]) - float(sr[0]), float(sr[3]) - float(sr[1]))
		mi.mesh = pm
		mi.material_override = color_mat(Color(0.87, 0.78, 0.5))
		add_child(mi)
		mi.global_position = Vector3((float(sr[0]) + float(sr[2])) * 0.5, 0.012, (float(sr[1]) + float(sr[3])) * 0.5)
	for mv in def.get("movers", []):
		var md: Dictionary = mv
		var body: Node3D = _box_from(md, Color(0.95, 0.55, 0.15), 0.5, true)
		add_mover(body, BotonCaida._vec(md.get("axis", [0, 0, 1])), float(md.get("amp", 1.2)), float(md.get("speed", 1.2)))
	# Hoyo: un disco oscuro (el centro captura) y la bandera.
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = HOLE_R
	cm.bottom_radius = HOLE_R
	cm.height = 0.02
	cup.mesh = cm
	cup.material_override = color_mat(Color(0.03, 0.03, 0.04))
	add_child(cup)
	var hole_y: float = float(def.get("hole_y", 0.0))
	cup.global_position = Vector3(hole.x, hole_y + 0.011, hole.z)
	_flag = Node3D.new()
	add_child(_flag)
	var pole := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.025
	pc.bottom_radius = 0.025
	pc.height = 1.6
	pole.mesh = pc
	pole.material_override = color_mat(Color(0.9, 0.9, 0.92))
	pole.position = Vector3(0, 0.8, 0)
	_flag.add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.45, 0.28, 0.02)
	flag.mesh = fm
	flag.material_override = color_mat(Color(0.9, 0.15, 0.1), 0.3)
	flag.position = Vector3(0.24, 1.42, 0)
	_flag.add_child(flag)
	_flag.global_position = Vector3(hole.x, hole_y, hole.z)

func _box_from(d: Dictionary, color: Color, bounce: float, animated: bool = false) -> Node3D:
	var size: Vector3 = BotonCaida._vec(d.get("size", [2, 0.4, 0.3]))
	var pos: Vector3 = BotonCaida._vec(d.get("pos", [0, 0.2, 0]))
	var rot := Vector3(deg_to_rad(float(d.get("pitch", 0.0))), deg_to_rad(float(d.get("yaw", 0.0))), deg_to_rad(float(d.get("roll", 0.0))))
	if animated:
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.collision_layer = Ball.LAYER_WORLD
		var pm := PhysicsMaterial.new()
		pm.bounce = bounce
		body.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = color_mat(color)
		body.add_child(mi)
		add_child(body)
		body.global_transform = Transform3D(Basis.from_euler(rot), pos)
		return body
	return static_box(size, pos, color, rot, bounce)

## Encuadre: el hoyo con la bandera.
func frame_points() -> Array:
	var hy: float = float(def.get("hole_y", 0.0))
	return [Vector3(hole.x, hy, hole.z), Vector3(hole.x, hy + 1.6, hole.z)]

func _ball_spot(_s: int) -> Vector3:
	return _spot

func _aim_point(_s: int) -> Vector3:
	return Vector3(hole.x, float(def.get("hole_y", 0.0)) + 0.6, hole.z)

# --- Gesto a ras del piso -----------------------------------------------------------------------------------------------

## Punto del piso (y = 0) bajo un punto de la pantalla.
func ground_point(px: Vector2) -> Vector3:
	var o: Vector3 = cam.project_ray_origin(px)
	var d: Vector3 = cam.project_ray_normal(px)
	if d.y > -1e-4:
		return _spot + Vector3(d.x, 0, d.z).normalized() * 6.0
	var t: float = -o.y / d.y
	var q: Vector3 = o + d * t
	return Vector3(q.x, 0.0, q.z)

## Golpe de golf: direccion hacia el punto del piso, potencia 0..1 y loft 0..1 (poca elevacion). Rasante sale rodando
## (giro de rodadura real); con loft pierde giro de piso.
func golf_velocity(ground_target: Vector3, power: float, loft: float) -> Array:
	var dir := Vector3(ground_target.x - _spot.x, 0.0, ground_target.z - _spot.z)
	if dir.length() < 0.05:
		dir = Vector3(1, 0, 0)
	dir = dir.normalized()
	var speed: float = lerpf(SPEED_MIN, SPEED_MAX, clampf(power, 0.0, 1.0))
	var pitch: float = clampf(loft, 0.0, 1.0) * LOFT_MAX
	var v: Vector3 = dir * cos(pitch) * speed + Vector3.UP * sin(pitch) * speed
	var w: Vector3 = ball.rolling_spin(v) * (1.0 - clampf(loft, 0.0, 1.0))
	return [v, w]

func _gesture_stroke() -> Array:
	var f: Dictionary = gesture.features()
	if float(f["length"]) < gesture.tuning.min_length * 0.6:
		return []
	var power: float = GestureShotModel.power_from(f, gesture.tuning)
	var ed: Vector2 = f["end_dir"]
	var loft: float = clampf(-ed.y - 0.35, 0.0, 1.0)
	return golf_velocity(ground_point(gesture.last_px()), power, loft)

func _on_press(pos: Vector2, pressed: bool) -> void:
	if state != State.AIM:
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
		var vw: Array = _gesture_stroke()
		if not vw.is_empty():
			apply_intent({"side": Side.USER, "v": vw[0], "w": vw[1]})

func _update_preview(delta: float) -> void:
	_preview_t -= delta
	if _preview_t > 0.0 or gesture.count() < 3:
		return
	_preview_t = 1.0 / 15.0
	var vw: Array = _gesture_stroke()
	if vw.is_empty():
		preview.hide_path()
		return
	if GraphicsSettings.show_aim_line:
		var traj: PackedVector3Array = BallPredictor.trajectory(_spot, vw[0], 4.0, 1.0 / 30.0, vw[1], true)
		var endp: Vector3 = traj[traj.size() - 1] if not traj.is_empty() else _spot
		preview.show_path(traj, hole.x + 50.0, (vw[0] as Vector3).length() / SPEED_MAX, cam.global_position, endp)
	else:
		preview.hide_path()
	hud.show_gesture((vw[0] as Vector3).length() / SPEED_MAX, clampf((vw[0] as Vector3).y / 6.0, 0.0, 1.2), 0.0, "Golpe de golf")

# --- Reglas ---------------------------------------------------------------------------------------------------------------

func _level_step(_delta: float) -> void:
	if state != State.FLIGHT or sand.is_empty() or not ball.is_grounded():
		return
	var p := Vector2(ball.global_position.x, ball.global_position.z)
	for r in sand:
		if (r as Rect2).has_point(p):
			# Arena: frena la rodadura (resistencia fuerte, fisica aparte intacta).
			ball.linear_velocity *= 1.0 - clampf(3.2 * _delta, 0.0, 0.5)
			ball.angular_velocity *= 1.0 - clampf(3.2 * _delta, 0.0, 0.5)
			break

func _flight_check(_delta: float) -> String:
	var p: Vector3 = ball.global_position
	var hole_y: float = float(def.get("hole_y", 0.0))
	if Vector2(p.x - hole.x, p.z - hole.z).length() < HOLE_R - 0.04 and p.y < hole_y + 0.2 and p.y > hole_y - 0.2 \
			and ball.linear_velocity.length() < CAPTURE_SPEED:
		holed = true
		ball.reset_at(Vector3(hole.x, hole_y - 0.25, hole.z))
		return "hoyo"
	if p.y < -2.5 or not bounds.has_point(Vector2(p.x, p.z)):
		return "fuera"
	return ""

func _on_resolved(_s: int, result: String) -> void:
	match result:
		"hoyo":
			points[0] = final_score()
			if not fast:
				cam.shake(0.35, 0.6)
			var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER, rng, 2.0, 1.2)
			if id != &"":
				shooters[0].actor.play_here(id, 0.3)
		"fuera":
			# Un golpe de penalizacion; se vuelve a jugar desde donde se jugo (_spot no cambio durante el vuelo).
			penalties += 1
		_:
			# La pelota quedo quieta: el proximo golpe sale de ahi.
			var p: Vector3 = ball.global_position
			_spot = Vector3(p.x, p.y, p.z)

func _start_turn() -> void:
	super._start_turn()
	hud.set_hint("Hoyo: par %d · trazá hacia el hoyo; el final del trazo marca el punto del piso" % par)

func _check_winner() -> int:
	if holed:
		return Side.USER
	return Side.USER if strokes() >= max_turns else -1

func final_score() -> int:
	if not holed:
		return 0
	var diff: int = strokes() - par
	return POINTS[clampi(diff + 2, 0, POINTS.size() - 1)]

func _report_achievements(w: int, medal: int) -> void:
	super._report_achievements(w, medal)
	if holed and strokes() < par:
		Achievements.event(&"golf_bajo_par")

func _result_text(r: String) -> Array:
	var names := {-2: "¡ÁGUILA!", -1: "¡BIRDIE!", 0: "PAR", 1: "Bogey", 2: "Doble bogey"}
	match r:
		"hoyo":
			var d: int = clampi(strokes() - par, -2, 2)
			return [names[d], Color(0.35, 1.0, 0.45) if d <= 0 else Color(1.0, 0.85, 0.35), "%d golpes (par %d)" % [strokes(), par]]
		"fuera":
			return ["Fuera de la cancha", Color(1.0, 0.5, 0.4), "+1 golpe de penalización; se juega desde donde estaba"]
	return ["", Color.WHITE]

func _refresh_score() -> void:
	hud.set_score_text("Par %d · Golpes %d" % [par, strokes()])
