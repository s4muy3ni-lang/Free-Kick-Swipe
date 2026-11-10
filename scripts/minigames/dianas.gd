class_name Dianas
extends Minigame
## Dianas colgantes y desmontables (etapa A5, catalogo #43): placas rigidas colgadas con una articulacion (PinJoint3D) de
## una barra fija o de un carrusel que gira. Se balancean con el golpe REAL de la pelota (pendulo fisico); un impacto
## suficientemente fuerte (o varios, segun la resistencia de cada placa) la desprende: se quita la articulacion y cae por
## gravedad. Tambien cuentan los golpes de otra placa en cadena (todo por colisiones reales: nada se anima «como si»).
## Gana el que desprende todas las placas con los tiros del nivel; puntos por placa caida y por tiros de sobra.
##
## Niveles en minigames.json ("dianas"): plates [{pos (anclaje), hits, size?}], bar_h, carousel {speed}, walls (tapan el
## tiro directo), shots.

const SCENE := "res://scenes/minigames/dianas.tscn"
## Un toque mas lento que esto no hace daño (un roce no desmonta nada).
const MIN_HIT := 2.4
const PLATE_POINTS := 100
const SPARE_SHOT := 40

## {body, joint, anchor (Node3D al que cuelga), hits (restantes), detached, fallen}
var plates: Array = []
var shots_max: int = 3
var _carousel: Node3D = null
var _bar: Node3D = null

func game_id() -> String:
	return "dianas"

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 3))
	max_turns = shots_max
	static_box(Vector3(70, 1, 40), Vector3(8, -0.5, 0), Color(0.2, 0.42, 0.5), Vector3.ZERO, 0.45)
	var bar_h: float = float(def.get("bar_h", 2.6))
	var car: Dictionary = def.get("carousel", {})
	if not car.is_empty():
		# Carrusel: un poste y una cruz que gira; las placas cuelgan de sus brazos (la articulacion acompaña el giro).
		var post := static_box(Vector3(0.18, bar_h, 0.18), Vector3(float(car.get("x", 12.0)), bar_h * 0.5, 0), Color(0.35, 0.37, 0.42))
		var bar := AnimatableBody3D.new()
		bar.sync_to_physics = false
		bar.collision_layer = Ball.LAYER_WORLD
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.3, 0.12, float(car.get("len", 4.0)))
		cs.shape = bs
		bar.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bs.size
		mi.mesh = bm
		mi.material_override = color_mat(Color(0.8, 0.8, 0.85))
		bar.add_child(mi)
		add_child(bar)
		bar.global_position = Vector3(float(car.get("x", 12.0)), bar_h, 0)
		add_mover(bar, Vector3.ZERO, 0.0, 1.0, 0.0, Vector3.UP, float(car.get("speed", 0.9)))
		_carousel = bar
		post.name = "CarouselPost"
	else:
		_bar = static_box(Vector3(0.3, 0.14, float(def.get("bar_len", 8.0))), Vector3(float(def.get("bar_x", 12.0)), bar_h, 0), Color(0.8, 0.8, 0.85))
		for zo in [-float(def.get("bar_len", 8.0)) * 0.5 + 0.2, float(def.get("bar_len", 8.0)) * 0.5 - 0.2]:
			static_box(Vector3(0.16, bar_h, 0.16), Vector3(float(def.get("bar_x", 12.0)), bar_h * 0.5, zo), Color(0.35, 0.37, 0.42))
	for w in def.get("walls", []):
		var wd: Dictionary = w
		static_box(BotonCaida._vec(wd.get("size", [3, 1, 0.3])), BotonCaida._vec(wd.get("pos", [8, 0.5, 0])), Color(0.85, 0.85, 0.9), Vector3.ZERO, 0.5)
	for pd in def.get("plates", []):
		_spawn_plate(pd, bar_h)
	ball.body_entered.connect(_on_ball_hit)

func _spawn_plate(pd: Dictionary, bar_h: float) -> void:
	var anchor_local: Vector3 = BotonCaida._vec(pd.get("pos", [12, 0, 0]))
	var size: Vector3 = BotonCaida._vec(pd.get("size", [0.55, 0.55, 0.06]))
	var plate := RigidBody3D.new()
	plate.mass = float(pd.get("mass", 0.5))
	plate.collision_layer = Ball.LAYER_WORLD
	plate.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
	plate.contact_monitor = true
	plate.max_contacts_reported = 4
	plate.linear_damp = 0.3
	plate.angular_damp = 0.5
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.4
	plate.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	plate.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var tough: bool = int(pd.get("hits", 1)) > 1
	mi.material_override = color_mat(Color(0.95, 0.75, 0.15) if tough else Color(0.92, 0.2, 0.15), 0.25)
	plate.add_child(mi)
	# Aro del anclaje (visual) y la articulacion: el pin une la barra con el borde superior de la placa.
	var hang: float = float(pd.get("hang", 0.55))
	var anchor := Vector3(anchor_local.x, bar_h - 0.07, anchor_local.z)
	add_child(plate)
	plate.global_position = anchor + Vector3.DOWN * (hang + size.y * 0.5)
	var joint := PinJoint3D.new()
	add_child(joint)
	joint.global_position = anchor
	# El pin une la placa con la barra (fija o carrusel): el anclaje acompaña a la barra.
	joint.node_a = joint.get_path_to(_carousel if _carousel != null else _bar)
	joint.node_b = joint.get_path_to(plate)
	var rope := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.015
	rm.bottom_radius = 0.015
	rm.height = hang
	rope.mesh = rm
	rope.material_override = color_mat(Color(0.2, 0.2, 0.22))
	add_child(rope)
	rope.global_position = anchor + Vector3.DOWN * hang * 0.5
	plates.append({"body": plate, "joint": joint, "rope": rope, "hits": int(pd.get("hits", 1)), "hits0": int(pd.get("hits", 1)),
		"detached": false, "fallen": false, "home": plate.global_transform, "anchor": anchor})
	plate.body_entered.connect(_on_plate_hit.bind(plate))

## Golpe sobre una placa (de la pelota o de otra placa en cadena): si el impacto es fuerte, resta resistencia; sin
## resistencia, se desprende (se quita la articulacion y cae).
func _on_plate_hit(body: Node, plate: RigidBody3D) -> void:
	var e: Dictionary = _entry_of(plate)
	if e.is_empty() or bool(e["detached"]):
		return
	var other_v := Vector3.ZERO
	if body == ball:
		other_v = prev_velocity()
	elif body is RigidBody3D:
		var oe: Dictionary = _entry_of(body as RigidBody3D)
		other_v = (oe.get("pv", (body as RigidBody3D).linear_velocity) as Vector3) if not oe.is_empty() else (body as RigidBody3D).linear_velocity
	else:
		return
	# Velocidades de ANTES del choque (la respuesta ya empujo a la placa cuando llega la señal).
	var rel: float = (other_v - (e.get("pv", Vector3.ZERO) as Vector3)).length()
	if rel < MIN_HIT:
		return
	e["hits"] = int(e["hits"]) - 1
	if int(e["hits"]) <= 0:
		e["detached"] = true
		(e["joint"] as PinJoint3D).queue_free()
		(e["rope"] as MeshInstance3D).visible = false

func _on_ball_hit(_body: Node) -> void:
	pass

func _level_step(_delta: float) -> void:
	for e in plates:
		e["pv"] = (e["body"] as RigidBody3D).linear_velocity

func _entry_of(plate: RigidBody3D) -> Dictionary:
	for e in plates:
		if e["body"] == plate:
			return e
	return {}

func fallen_count() -> int:
	var n: int = 0
	for e in plates:
		if bool(e["detached"]) and (e["body"] as RigidBody3D).global_position.y < 0.6:
			e["fallen"] = true
		if bool(e["fallen"]):
			n += 1
	return n

func hanging() -> int:
	return plates.size() - fallen_count()

func reset_level() -> void:
	for e in plates:
		var body: RigidBody3D = e["body"]
		if bool(e["detached"]):
			# Vuelve a colgar: placa a su lugar y una articulacion nueva (la vieja se libero).
			var j := PinJoint3D.new()
			add_child(j)
			j.global_position = e["anchor"]
			j.node_a = j.get_path_to(_carousel if _carousel != null else _bar)
			j.node_b = j.get_path_to(body)
			e["joint"] = j
			(e["rope"] as MeshInstance3D).visible = true
		body.global_transform = e["home"]
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		e["detached"] = false
		e["fallen"] = false
		e["hits"] = e["hits0"]
	super.reset_level()

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0, ball.radius if ball != null else 0.11, 0) + BotonCaida._vec(def.get("tee", [0, 0, 0]))

func _aim_point(_s: int) -> Vector3:
	var c := Vector3.ZERO
	for e in plates:
		c += (e["anchor"] as Vector3)
	c /= float(maxi(plates.size(), 1))
	return Vector3(c.x, c.y - 0.6, c.z)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(_aim_point(0).x, Vector2(9.0, 27.0), false, 5.0, 4.5, ball.radius)

func _settling() -> bool:
	for e in plates:
		if bool(e["detached"]) and not bool(e["fallen"]) and (e["body"] as RigidBody3D).linear_velocity.length() > 0.3:
			return true
	return false

func _flight_check(_delta: float) -> String:
	if _t > 0.6 and fallen_count() == plates.size():
		return "todas"
	if _t > 0.8 and not _settling() and (ball.linear_velocity.length() < SLOW_SPEED or ball.global_position.x > _aim_point(0).x + 10.0):
		return "listo"
	return ""

func _on_resolved(s: int, _r: String) -> void:
	points[0] = fallen_count()
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if hanging() == 0 else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)

func _check_winner() -> int:
	if hanging() == 0 or int(shots[0]) >= shots_max:
		return Side.USER
	return -1

func final_score() -> int:
	var n: int = fallen_count()
	if n == 0:
		return 0
	var s: int = n * PLATE_POINTS
	if hanging() == 0:
		s += maxi(shots_max - int(shots[0]), 0) * SPARE_SHOT
	return s

func _result_text(r: String) -> Array:
	if r == "todas":
		return ["¡TODAS ABAJO!", Color(0.35, 1.0, 0.45), "En %d tiros" % int(shots[0])]
	return ["%d de %d dianas" % [fallen_count(), plates.size()], Color(1.0, 0.85, 0.35), "Tiros %d de %d" % [int(shots[0]), shots_max]]

func _refresh_score() -> void:
	hud.set_score_text("Dianas %d / %d · tiros %d / %d" % [fallen_count(), plates.size(), int(shots[0]), shots_max])
