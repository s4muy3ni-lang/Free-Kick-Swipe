class_name Curling
extends Minigame
## «Curling» (HABILIDAD, contra la IA). Una pista de hielo de 30 m con la casa (anillos) al fondo. Cada jugador lanza
## sus pelotas por turnos a ras del hielo (el mismo gesto del Bowling: direccion al punto del piso, potencia y efecto).
## En el hielo la pelota casi no frena: dentro de la pista se le devuelve en cada paso la parte de la rodadura de cesped
## (Ball.roll_decel) que sobra, y queda ICE_DECEL (la fisica comun de la pelota no se toca).
## Cada pelota lanzada queda en la pista: al quedar quieta pasa a ser una «piedra» (cuerpo rigido esferico, misma masa y
## radio, con el aspecto de la pelota y un aro del color del equipo) que las siguientes pueden chocar y desplazar.
## Fuera de juego (se quita): la que no pasa la linea de lanzamiento («hog»), la que pasa la linea de fondo o toca las
## bandas. Al final gana el que tiene la piedra mas cerca del centro: suma 1 por cada piedra suya dentro de la casa mas
## cerca que la mejor del rival.
## IA: elige entre dejarla en el centro (velocidad para frenar ahi segun el hielo) o sacar la mejor piedra rival si esta
## ganando; patea con la misma fisica y su error de direccion y de velocidad.

const SCENE := "res://scenes/minigames/curling.tscn"
const ICE_DECEL := 0.18
## Lo que la pelota pierde ademas de la rodadura (aire), por m/s; medido: sin esto frenaba 0,27 m/s2 a 3 m/s.
const ICE_DRAG_COMP := 0.032
const SHEET_W := 4.4
const HOUSE_R := [1.83, 1.22, 0.61, 0.15]
const CPU_ERROR := [[2.2, 0.12], [1.5, 0.08], [1.0, 0.06], [0.7, 0.04], [0.5, 0.03]]

var house := Vector3(26.0, 0.0, 0.0)
var hog_x: float = 18.0
var back_x: float = 28.0
var shots_each: int = 4
## Piedras en juego: {body, team}
var stones: Array = []
var cpu_error: Vector2 = Vector2(-1, -1)
var last_choice: String = ""
var _visual_src: MeshInstance3D

func game_id() -> String:
	return "curling"

func _build_level() -> void:
	sides = 2
	shots_each = int(def.get("shots", 4))
	max_turns = shots_each * 2
	var length: float = float(def.get("length", 30.0))
	house = Vector3(length - 4.0, 0.0, 0.0)
	hog_x = house.x - 8.0
	back_x = house.x + HOUSE_R[0] + 0.2
	var ground := static_box(Vector3(length + 20.0, 1, 30), Vector3(length * 0.5, -0.5, 0), Color(0.85, 0.9, 0.95), Vector3.ZERO, 0.3)
	for c in ground.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	var pm: PhysicsMaterial = ground.physics_material_override
	pm.friction = 0.06
	# Bandas (las que tocan quedan fuera de juego).
	for z in [-SHEET_W * 0.5 - 0.1, SHEET_W * 0.5 + 0.1]:
		var b := static_box(Vector3(length + 4.0, 0.25, 0.2), Vector3(length * 0.5, 0.125, z), Color(0.9, 0.9, 0.9), Vector3.ZERO, 0.6)
		for c in b.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.15, 0.3, 0.75), "plastic")
	var endb := static_box(Vector3(0.2, 0.25, SHEET_W + 0.4), Vector3(length + 1.8, 0.125, 0), Color(0.9, 0.9, 0.9), Vector3.ZERO, 0.4)
	for c in endb.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.15, 0.3, 0.75), "plastic")
	_build_stage(length)
	_visual_src = ball.get_node_or_null("Visual") as MeshInstance3D
	for sd in def.get("stones", []):
		var p: Array = (sd as Dictionary)["pos"]
		_add_stone(Vector3(float(p[0]), ball.radius, float(p[1])), int((sd as Dictionary).get("team", 1)))

func _build_stage(length: float) -> void:
	ArcadeLook.light(self, Color(0.92, 0.96, 1.0), 1.0, Color(0.15, 0.2, 0.32), Color(0.6, 0.7, 0.82), 0.85, Vector3(-65, -15, 0))
	ArcadeLook.ground(self, Vector2(160, 120), Vector3(length * 0.5, -0.004, 0), Color(0.2, 0.22, 0.26), "stone", 40.0)
	# Hielo: blanco azulado con un leve ruido (pebble), lineas y la casa.
	var sheet := ArcadeLook.ground(self, Vector2(length + 4.0, SHEET_W), Vector3(length * 0.5, 0.0, 0), Color(0.86, 0.92, 0.98), "paint", 10.0)
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.88, 0.93, 0.99)
	ice.albedo_texture = ArcadeLook.noise_tex("fine")
	ice.uv1_scale = Vector3(10, 10, 10)
	ice.metallic_specular = 0.9
	ice.roughness = 0.12
	sheet.material_override = ice
	for r in HOUSE_R.size():
		var col: Color = [Color(0.15, 0.35, 0.85), Color(0.95, 0.95, 0.97), Color(0.85, 0.12, 0.12), Color(0.95, 0.95, 0.97)][r]
		ArcadeLook.deco(self, "cyl", Vector3(HOUSE_R[r], 0.004, HOUSE_R[r]), house + Vector3.UP * (0.004 + 0.001 * float(r)), ArcadeLook.mat(col, "plastic"))
	for x in [hog_x, house.x, back_x]:
		ArcadeLook.deco(self, "box", Vector3(0.06 if x != hog_x else 0.1, 0.004, SHEET_W), Vector3(x, 0.006, 0), ArcadeLook.mat(Color(0.85, 0.12, 0.12) if x == hog_x else Color(0.1, 0.1, 0.12), "paint"))
	ArcadeLook.deco(self, "box", Vector3(length, 0.004, 0.03), Vector3(length * 0.5, 0.005, 0), ArcadeLook.mat(Color(0.1, 0.1, 0.12), "paint"))
	# Estadio de hielo: tribunas, publicidad en las bandas exteriores, techo con luces.
	ArcadeLook.stands(self, length * 0.5, length + 6.0, [-9.0, 9.0], 0.0, 4)
	for z in [-9.0, 9.0]:
		for k in 8:
			ArcadeLook.deco(self, "box", Vector3((length + 4.0) / 8.0 - 0.1, 0.7, 0.1), Vector3(-2.0 + (float(k) + 0.5) * (length + 4.0) / 8.0, 0.35, signf(z) * 3.4), ArcadeLook.mat([Color(0.95, 0.95, 0.97), Color(0.15, 0.35, 0.85), Color(0.85, 0.12, 0.12)][k % 3], "paint"))
	for x in [0.0, length * 0.33, length * 0.66, length]:
		ArcadeLook.deco(self, "box", Vector3(0.5, 0.15, 6.0), Vector3(x, 9.0, 0), ArcadeLook.glow(Color(0.95, 0.97, 1.0), 2.0))
	ArcadeLook.billboard(self, "CURLING", Vector3(length + 4.0, 3.0, 0), 6.0, 1.2, Color(0.08, 0.15, 0.35), Color(0.95, 0.97, 1.0))

# --- Piedras ------------------------------------------------------------------------------------------------------------

func _add_stone(pos: Vector3, team: int) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.mass = ball.mass
	rb.collision_layer = Ball.LAYER_WORLD
	rb.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
	var pm := PhysicsMaterial.new()
	pm.friction = 0.06
	pm.bounce = 0.6
	rb.physics_material_override = pm
	rb.angular_damp = 1.0
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = ball.radius
	cs.shape = sp
	rb.add_child(cs)
	if _visual_src != null:
		var v: MeshInstance3D = _visual_src.duplicate() as MeshInstance3D
		rb.add_child(v)
	else:
		ArcadeLook.part(rb, "sphere", Vector3(ball.radius, 0, 0), Vector3.ZERO, ArcadeLook.mat(Color(0.95, 0.95, 0.95), "plastic"))
	# Aro del equipo (azul el usuario, rojo la CPU) y una vincha que se ve de lejos.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = ball.radius * 0.98
	tm.outer_radius = ball.radius * 1.18
	tm.rings = 20
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = ArcadeLook.glow(Color(0.2, 0.45, 1.0) if team == 0 else Color(1.0, 0.2, 0.2), 1.2)
	rb.add_child(ring)
	add_child(rb)
	rb.global_position = pos
	stones.append({"body": rb, "team": team})
	return rb

func _remove_stone(e: Dictionary) -> void:
	stones.erase(e)
	(e["body"] as Node).queue_free()

## Fuera de juego: no paso la hog, paso el fondo o toco las bandas.
func out_of_play(p: Vector3) -> bool:
	return p.x < hog_x or p.x > back_x or absf(p.z) > SHEET_W * 0.5 - ball.radius * 0.5 or p.y < -0.5

func _level_step(delta: float) -> void:
	# Hielo: la pelota frena ICE_DECEL (se le devuelve lo que le saca la rodadura de cesped).
	if ball.is_grounded() and absf(ball.global_position.z) < SHEET_W * 0.5 and ball.global_position.x > -1.0:
		var hv := Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
		var hs: float = hv.length()
		if hs > 0.02:
			# (+ ICE_DRAG_COMP v: el arrastre del aire y el paso exacto de la rodadura; medido en test_curling.)
			var give: float = maxf(Ball.roll_decel(hs) + ICE_DRAG_COMP * hs - ICE_DECEL, 0.0) * delta
			ball.linear_velocity += hv / hs * give
			# El giro de rodadura acompaña (si no, el rozamiento con el piso igualaria giro y avance y la frenaria igual).
			var wy: float = ball.angular_velocity.y
			ball.angular_velocity = ball.rolling_spin(ball.linear_velocity) + Vector3(0, wy, 0)
	for e in stones:
		var rb: RigidBody3D = e["body"]
		var hv2 := Vector3(rb.linear_velocity.x, 0.0, rb.linear_velocity.z)
		var hs2: float = hv2.length()
		if hs2 > 0.0:
			var nv: float = maxf(hs2 - ICE_DECEL * delta, 0.0)
			rb.linear_velocity = Vector3(hv2.x / hs2 * nv, rb.linear_velocity.y, hv2.z / hs2 * nv)
			if nv == 0.0:
				rb.angular_velocity = Vector3.ZERO

func _settling() -> bool:
	for e in stones:
		if (e["body"] as RigidBody3D).linear_velocity.length() > 0.03:
			return true
	return false

func _flight_check(_delta: float) -> String:
	var p: Vector3 = ball.global_position
	if _t > 0.6 and ball.linear_velocity.length() < 0.05 and not _settling():
		return "listo"
	if p.x > back_x + 1.0 or absf(p.z) > SHEET_W * 0.5 + 0.5:
		if not _settling():
			return "afuera"
	return ""

## Vigilante propio: en el hielo una pelota puede deslizar 20 s; solo corta por caida o a los 40 s.
func _flight_watchdog(_delta: float) -> String:
	if ball.global_position.y < KILL_Y:
		return "afuera"
	if _t > 40.0:
		return "tiempo"
	return ""

func _on_resolved(s: int, r: String) -> void:
	# La pelota lanzada (quieta) queda como piedra si esta en juego; despues se quitan las que salieron.
	var p: Vector3 = ball.global_position
	if r == "listo" and not out_of_play(p):
		_add_stone(Vector3(p.x, ball.radius, p.z), s)
	for e in stones.duplicate():
		if out_of_play((e["body"] as Node3D).global_position):
			_remove_stone(e)
	var sc: Array = end_score()
	var good: bool = int(sc[0]) == s
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if good else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)
	_refresh_score()

## [equipo que suma (-1 nadie), puntos]: las piedras dentro de la casa mas cerca del centro que la mejor del rival.
func end_score() -> Array:
	var best: Array = [INF, INF]
	var ds: Array = [[], []]
	for e in stones:
		var p: Vector3 = (e["body"] as Node3D).global_position
		var d: float = Vector2(p.x - house.x, p.z - house.z).length()
		if d <= HOUSE_R[0] + ball.radius:
			(ds[int(e["team"])] as Array).append(d)
			best[int(e["team"])] = minf(float(best[int(e["team"])]), d)
	if best[0] == INF and best[1] == INF:
		return [-1, 0]
	var w: int = 0 if float(best[0]) < float(best[1]) else 1
	var n: int = 0
	for d in ds[w]:
		if float(d) < float(best[1 - w]):
			n += 1
	return [w, n]

func closest(team: int) -> float:
	var b: float = INF
	for e in stones:
		if int(e["team"]) == team:
			var p: Vector3 = (e["body"] as Node3D).global_position
			b = minf(b, Vector2(p.x - house.x, p.z - house.z).length())
	return b

func _check_winner() -> int:
	if int(shots[1]) < shots_each:
		return -1
	var sc: Array = end_score()
	return Side.USER if int(sc[0]) == 0 else Side.CPU

func final_score() -> int:
	var sc: Array = end_score()
	if int(sc[0]) != 0:
		return 0
	var d: float = closest(0)
	return 100 * int(sc[1]) + int(maxf(0.0, 60.0 - d * 60.0))

func reset_level() -> void:
	for e in stones.duplicate():
		_remove_stone(e)
	stones.clear()
	for sd in def.get("stones", []):
		var p: Array = (sd as Dictionary)["pos"]
		_add_stone(Vector3(float(p[0]), ball.radius, float(p[1])), int((sd as Dictionary).get("team", 1)))
	super.reset_level()

## Los dos lanzan desde el mismo lugar: el que espera se para al costado de la pista (no encima del que patea).
func _place_shooter(s: int) -> void:
	super._place_shooter(s)
	if s != side:
		var a: SpActor = shooters[s].actor
		a.global_position = Vector3(-1.2, a.global_position.y, SHEET_W * 0.5 + 1.2)
		a.set_facing(Vector3(1, 0, -0.3))

func _start_turn() -> void:
	for s in shooters.size():
		_place_shooter(s)
	super._start_turn()

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0, ball.radius if ball != null else 0.11, 0)

func _aim_point(_s: int) -> Vector3:
	return house + Vector3.UP * 0.3

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(house.x, Vector2(10.0, 30.0), false, SHEET_W, 3.0, ball.radius)

## Camara recomendada para la pista larga: un poco mas alta y mirando lejos (la casa esta a 26 m).
func camera_defaults() -> Dictionary:
	return {"back": 7.5, "height": 4.4, "ahead": 9.0, "lift_aim": 0.0, "fov": 48.0, "follow": 0.45}

func frame_points() -> Array:
	return [house + Vector3(HOUSE_R[0], 0, HOUSE_R[0]), house + Vector3(-HOUSE_R[0], 0, -HOUSE_R[0])]

func _result_text(r: String) -> Array:
	var sc: Array = end_score()
	var who: String = "Nadie en la casa" if int(sc[0]) < 0 else ("Ganás %d" % int(sc[1]) if int(sc[0]) == 0 else "La CPU gana %d" % int(sc[1]))
	if r == "afuera":
		return ["Afuera", Color(1.0, 0.6, 0.4), who]
	var d: float = closest(side) if side == 0 else closest(1)
	return ["%.2f m del centro" % d if d < INF else "Fuera de la casa", Color(1.0, 0.85, 0.35), who]

func _refresh_score() -> void:
	var sc: Array = end_score()
	var lead: String = "—" if int(sc[0]) < 0 else ("Vos %d" % int(sc[1]) if int(sc[0]) == 0 else "CPU %d" % int(sc[1]))
	hud.set_score_text("Gana: %s · tiros %d / %d" % [lead, int(shots[0]), shots_each])

# --- Gesto: a ras del hielo ----------------------------------------------------------------------------------------------

## Distancia (m) que desliza la pelota real segun su velocidad de salida (m/s), MEDIDA con la fisica del juego (el aire
## le suma un poco al frenado ICE_DECEL a mas velocidad: 0,176 m/s2 efectivos a 1,5 m/s, 0,219 a 4 m/s).
const SLIDE_TABLE := [[0.0, 0.0], [1.5, 6.39], [2.0, 11.13], [2.5, 16.85], [3.0, 23.19], [3.5, 29.96], [4.0, 36.47], [5.0, 50.0]]

## Velocidad para que la pelota frene a `dist` m sobre el hielo (interpolada de la tabla medida).
static func speed_to_stop(dist: float) -> float:
	var d: float = maxf(dist, 0.0)
	for i in range(1, SLIDE_TABLE.size()):
		var a: Array = SLIDE_TABLE[i - 1]
		var b: Array = SLIDE_TABLE[i]
		if d <= float(b[1]) or i == SLIDE_TABLE.size() - 1:
			var t: float = (d - float(a[1])) / maxf(float(b[1]) - float(a[1]), 0.001)
			# Entre puntos, en v^2 (la distancia crece como v^2).
			return sqrt(lerpf(float(a[0]) * float(a[0]), float(b[0]) * float(b[0]), clampf(t, 0.0, 1.5)))
	return 0.0

## Distancia que desliza a la velocidad v (inversa de la tabla).
static func slide_distance(v: float) -> float:
	for i in range(1, SLIDE_TABLE.size()):
		var a: Array = SLIDE_TABLE[i - 1]
		var b: Array = SLIDE_TABLE[i]
		if v <= float(b[0]) or i == SLIDE_TABLE.size() - 1:
			var t: float = (v * v - float(a[0]) * float(a[0])) / maxf(float(b[0]) * float(b[0]) - float(a[0]) * float(a[0]), 0.001)
			return lerpf(float(a[1]), float(b[1]), clampf(t, 0.0, 1.5))
	return 0.0

func slide_velocity(ground_target: Vector3, power: float, curve: float) -> Array:
	var dir := Vector3(ground_target.x - _ball_spot(0).x, 0, ground_target.z - _ball_spot(0).z)
	dir = dir.normalized() if dir.length() > 0.05 else Vector3(1, 0, 0)
	var speed: float = lerpf(1.5, 5.0, clampf(power, 0.0, 1.0))
	var v: Vector3 = dir * speed
	var w: Vector3 = ball.rolling_spin(v) + Vector3.UP * clampf(curve, -1.0, 1.0) * 4.0
	return [v, w]

func _ground(px: Vector2) -> Vector3:
	var o: Vector3 = cam.project_ray_origin(px)
	var dd: Vector3 = cam.project_ray_normal(px)
	if dd.y > -1e-4:
		return house
	var t: float = -o.y / dd.y
	var q: Vector3 = o + dd * t
	return Vector3(q.x, 0, q.z)

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
		var vw: Array = slide_velocity(_ground(gesture.last_px()), GestureShotModel.power_from(f, gesture.tuning), clampf(float(f["curvature"]) * 2.0, -1.0, 1.0))
		apply_intent({"side": Side.USER, "v": vw[0], "w": vw[1]})

func _update_preview(delta: float) -> void:
	_preview_t -= delta
	if _preview_t > 0.0 or gesture.count() < 3:
		return
	_preview_t = 1.0 / 15.0
	var f: Dictionary = gesture.features()
	if float(f["length"]) < gesture.tuning.min_length * 0.6:
		preview.hide_path()
		return
	var vw: Array = slide_velocity(_ground(gesture.last_px()), GestureShotModel.power_from(f, gesture.tuning), 0.0)
	var v: Vector3 = vw[0]
	if GraphicsSettings.show_aim_line:
		# Recorrido sobre el hielo: recto hasta donde frena (v^2 / 2a).
		var stop: float = slide_distance(v.length())
		var pts := PackedVector3Array()
		for k in 21:
			pts.append(_ball_spot(0) + v.normalized() * stop * float(k) / 20.0 + Vector3.UP * 0.05)
		preview.show_path(pts, house.x + 4.0, v.length() / 5.0, cam.global_position, pts[pts.size() - 1])
	else:
		preview.hide_path()
	hud.show_gesture(v.length() / 5.0, 0.0, 0.0, "Hielo")

# --- IA -----------------------------------------------------------------------------------------------------------------

func _cpu_err() -> Vector2:
	if cpu_error.x >= 0.0:
		return cpu_error
	var e: Array = CPU_ERROR[clampi(SpSettings.level(), 0, CPU_ERROR.size() - 1)]
	return Vector2(float(e[0]), float(e[1]))

func _cpu_intent() -> Dictionary:
	var err: Vector2 = _cpu_err()
	var spot: Vector3 = _ball_spot(Side.CPU)
	var target: Vector3 = house
	var speed: float
	var mine: float = closest(1)
	var theirs: float = closest(0)
	# Si el usuario gana la mano con una piedra en la casa, la saca (tiro fuerte a esa piedra); si no, a dejarla en el
	# centro (o al lado de la suya para no taparse).
	if theirs < HOUSE_R[0] and theirs < mine:
		for e in stones:
			if int(e["team"]) == 0:
				var p: Vector3 = (e["body"] as Node3D).global_position
				if absf(Vector2(p.x - house.x, p.z - house.z).length() - theirs) < 0.001:
					target = Vector3(p.x, 0, p.z)
		speed = 4.6
		last_choice = "sacar"
	else:
		speed = speed_to_stop(target.x - spot.x)
		last_choice = "centro"
	var dir: Vector3 = Vector3(target.x - spot.x, 0, target.z - spot.z).normalized()
	dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randfn(0.0, err.x)))
	speed *= 1.0 + rng.randfn(0.0, err.y)
	var v: Vector3 = dir * speed
	return {"v": v, "w": ball.rolling_spin(v), "aim": target}
