class_name Rescate
extends Minigame
## Rescate de la pelota (etapa A5): una pelota dorada esta atrapada (en una jaula con compuerta, sobre una plataforma,
## detras de un domino...) y hay que llevarla a la ZONA LIBRE con tiros limitados. Todo es fisico: los botones se aprietan
## solo con un impacto real (como en Boton de caida), la compuerta es una traba que se quita y deja rodar, el empujon es
## transferencia de impulso real y el domino es una cadena de losas rigidas. Nada se mueve si la pelota no lo toco.
##
## Niveles ("rescate" en minigames.json): prisoner {pos}, zone [x0,z0,x1,z1], shots, buttons [{pos, latch: idx}],
## latches [{pos, size}], slopes (cajas inclinadas), walls, platforms, dominoes [{pos, n, step}].

const SCENE := "res://scenes/minigames/rescate.tscn"
const PRESS_SPEED := 2.5
const RESCUE_POINTS := 150
const SPARE_SHOT := 50

var prisoner: RigidBody3D
var zone := Rect2()
var shots_max: int = 3
var rescued: bool = false
## Botones: {body, mesh, latch (indice), pressed}; trabas: StaticBody3D que se quitan al apretar su boton.
var buttons: Array = []
var latches: Array = []
var dominoes: Array[RigidBody3D] = []
var _prisoner_home := Transform3D()

func game_id() -> String:
	return "rescate"

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 3))
	max_turns = shots_max
	static_box(Vector3(70, 1, 40), Vector3(8, -0.5, 0), Color(0.45, 0.4, 0.5), Vector3.ZERO, 0.4)
	var z: Array = def.get("zone", [2, -2, 6, 2])
	zone = Rect2(float(z[0]), float(z[1]), float(z[2]) - float(z[0]), float(z[3]) - float(z[1]))
	var zm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(zone.size.x, zone.size.y)
	zm.mesh = pm
	zm.material_override = color_mat(Color(0.2, 0.95, 0.4), 0.4)
	add_child(zm)
	zm.global_position = Vector3(zone.get_center().x, 0.015, zone.get_center().y)
	for w in def.get("walls", []):
		var wd: Dictionary = w
		static_box(BotonCaida._vec(wd.get("size", [3, 1, 0.3])), BotonCaida._vec(wd.get("pos", [8, 0.5, 0])), Color(0.85, 0.85, 0.9),
			Vector3(0, deg_to_rad(float(wd.get("yaw", 0.0))), 0), 0.5)
	for pl in def.get("platforms", []):
		var pd: Dictionary = pl
		static_box(BotonCaida._vec(pd.get("size", [3, 1, 3])), BotonCaida._vec(pd.get("pos", [12, 0.5, 0])), Color(0.5, 0.45, 0.6), Vector3.ZERO, 0.3)
	for sl in def.get("slopes", []):
		var sd: Dictionary = sl
		static_box(BotonCaida._vec(sd.get("size", [3, 0.2, 2])), BotonCaida._vec(sd.get("pos", [12, 1.0, 0])), Color(0.55, 0.5, 0.65),
			Vector3(deg_to_rad(float(sd.get("pitch", 0.0))), deg_to_rad(float(sd.get("yaw", 0.0))), deg_to_rad(float(sd.get("roll", 0.0)))), 0.15)
	for ld in def.get("latches", []):
		var l: Dictionary = ld
		var latch := static_box(BotonCaida._vec(l.get("size", [0.1, 0.5, 1.2])), BotonCaida._vec(l.get("pos", [11, 1.2, 0])), Color(0.9, 0.3, 0.2), Vector3(0, deg_to_rad(float(l.get("yaw", 0.0))), 0), 0.2)
		latches.append(latch)
	for bd in def.get("buttons", []):
		_spawn_button(bd)
	for dd in def.get("dominoes", []):
		var d: Dictionary = dd
		var at: Vector3 = BotonCaida._vec(d.get("pos", [10, 1.0, 0]))
		var step: Vector3 = BotonCaida._vec(d.get("step", [0.5, 0, 0]))
		var size: Vector3 = BotonCaida._vec(d.get("size", [0.12, 0.9, 0.5]))
		for i in int(d.get("n", 5)):
			var slab := RigidBody3D.new()
			slab.mass = 0.8
			slab.collision_layer = Ball.LAYER_WORLD
			slab.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = size
			cs.shape = bs
			slab.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
			mi.material_override = color_mat(Color(0.95, 0.75, 0.2))
			slab.add_child(mi)
			add_child(slab)
			slab.global_position = at + step * float(i) + Vector3.UP * size.y * 0.5
			dominoes.append(slab)
	# La prisionera: pelota dorada, fisica real.
	prisoner = RigidBody3D.new()
	prisoner.mass = 0.42
	# Resistencia a la rodadura en el pasto (la pelota del juego la modela Ball; esta es una esfera comun).
	prisoner.linear_damp = 0.8
	prisoner.angular_damp = 0.5
	# Abrir una traba no es un contacto: no despierta a un cuerpo dormido. La dorada nunca duerme.
	prisoner.can_sleep = false
	prisoner.collision_layer = Ball.LAYER_WORLD
	prisoner.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
	var pcs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.12
	pcs.shape = sph
	prisoner.add_child(pcs)
	var pmat := PhysicsMaterial.new()
	pmat.bounce = 0.4
	pmat.friction = 0.6
	prisoner.physics_material_override = pmat
	var pmi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	pmi.mesh = sm
	pmi.material_override = color_mat(Color(1.0, 0.82, 0.15), 0.5)
	prisoner.add_child(pmi)
	add_child(prisoner)
	prisoner.global_position = BotonCaida._vec(def.get("prisoner", [12, 1.3, 0]))
	_prisoner_home = prisoner.global_transform
	ball.body_entered.connect(_on_ball_body)

func _spawn_button(bd: Dictionary) -> void:
	var cap := AnimatableBody3D.new()
	cap.sync_to_physics = false
	cap.collision_layer = Ball.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = float(bd.get("radius", 0.4))
	cyl.height = 0.14
	cs.shape = cyl
	cap.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = cyl.radius
	cm.bottom_radius = cyl.radius
	cm.height = 0.14
	mi.mesh = cm
	mi.material_override = color_mat(Color(0.95, 0.12, 0.1), 0.6)
	cap.add_child(mi)
	add_child(cap)
	var facing_up: bool = bool(bd.get("up", false))
	cap.global_transform = Transform3D(Basis() if facing_up else Basis(Vector3(0, 0, 1), PI * 0.5), BotonCaida._vec(bd.get("pos", [10, 1.0, 0])))
	buttons.append({"body": cap, "mesh": mi, "latch": int(bd.get("latch", 0)), "pressed": false,
		"normal": Vector3.UP if facing_up else Vector3(-1, 0, 0), "home": cap.global_transform})

func _on_ball_body(body: Node) -> void:
	if state != State.FLIGHT:
		return
	for b in buttons:
		if body == b["body"] and not bool(b["pressed"]):
			var impact: float = -prev_velocity().dot(b["normal"])
			if impact >= PRESS_SPEED:
				_press(b)

## Boton apretado: se hunde, se pone verde y su traba desaparece (la compuerta queda libre; lo que siga es gravedad).
func _press(b: Dictionary) -> void:
	b["pressed"] = true
	var cap: Node3D = b["body"]
	cap.global_position += (b["normal"] as Vector3) * -0.08
	(b["mesh"] as MeshInstance3D).material_override = color_mat(Color(0.2, 0.95, 0.3), 0.8)
	var li: int = int(b["latch"])
	if li >= 0 and li < latches.size() and is_instance_valid(latches[li]):
		(latches[li] as Node3D).visible = false
		(latches[li] as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED
		for c in (latches[li] as Node).get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true
	if not fast:
		Sfx.play(&"cheer", 0.4)

func pressed_count() -> int:
	var n: int = 0
	for b in buttons:
		if bool(b["pressed"]):
			n += 1
	return n

func reset_level() -> void:
	rescued = false
	prisoner.global_transform = _prisoner_home
	prisoner.linear_velocity = Vector3.ZERO
	prisoner.angular_velocity = Vector3.ZERO
	for b in buttons:
		b["pressed"] = false
		(b["body"] as Node3D).global_transform = b["home"]
		(b["mesh"] as MeshInstance3D).material_override = color_mat(Color(0.95, 0.12, 0.1), 0.6)
	for l in latches:
		if is_instance_valid(l):
			(l as Node3D).visible = true
			(l as StaticBody3D).process_mode = Node.PROCESS_MODE_INHERIT
			for c in (l as Node).get_children():
				if c is CollisionShape3D:
					(c as CollisionShape3D).disabled = false
	super.reset_level()

## Encuadre: la prisionera, la zona libre y los botones.
func frame_points() -> Array:
	var out: Array = [_prisoner_home.origin + Vector3.UP * 0.4, Vector3(zone.position.x, 0, zone.position.y), Vector3(zone.end.x, 0, zone.end.y)]
	for b in buttons:
		out.append((b["home"] as Transform3D).origin)
	return out

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0, ball.radius if ball != null else 0.11, 0) + BotonCaida._vec(def.get("tee", [0, 0, 0]))

func _aim_point(_s: int) -> Vector3:
	return prisoner.global_position if prisoner != null else Vector3(12, 1, 0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(_aim_point(0).x, Vector2(9.0, 27.0), false, 5.0, 4.5, ball.radius)

func _settling() -> bool:
	if prisoner.linear_velocity.length() > 0.25:
		return true
	for d in dominoes:
		if not d.sleeping and d.linear_velocity.length() > 0.2:
			return true
	return false

func _in_zone() -> bool:
	var p: Vector3 = prisoner.global_position
	return zone.has_point(Vector2(p.x, p.z)) and p.y < 0.5 and prisoner.linear_velocity.length() < 0.6

func _level_step(_delta: float) -> void:
	if rescued or state == State.OVER:
		return
	if _in_zone():
		rescued = true
		if state == State.AIM:
			# La prisionera llego rodando mientras se apuntaba (una cadena lenta): la jugada se resuelve igual.
			state = State.FLIGHT
			_resolve("rescatada")

func _flight_check(_delta: float) -> String:
	if rescued or _in_zone():
		rescued = true
		return "rescatada"
	if _t > 0.8 and not _settling() and ball.linear_velocity.length() < SLOW_SPEED:
		return "listo"
	return ""

func _on_resolved(s: int, r: String) -> void:
	points[0] = 1 if rescued else 0
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if r == "rescatada" else SpReactions.MISS_SHOOTER, rng, 1.5, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)
	if r == "rescatada" and not fast:
		cam.shake(0.4, 0.7)

func _check_winner() -> int:
	if rescued or int(shots[0]) >= shots_max:
		return Side.USER
	return -1

func final_score() -> int:
	if not rescued:
		return 0
	return RESCUE_POINTS + maxi(shots_max - int(shots[0]), 0) * SPARE_SHOT

func _report_achievements(w: int, medal: int) -> void:
	super._report_achievements(w, medal)
	if rescued:
		Achievements.event(&"rescate")

func _result_text(r: String) -> Array:
	if r == "rescatada":
		return ["¡RESCATADA!", Color(0.35, 1.0, 0.45), "En %d tiros" % int(shots[0])]
	return ["Sigue atrapada", Color(1.0, 0.75, 0.4), "Tiros %d de %d" % [int(shots[0]), shots_max]]

func _refresh_score() -> void:
	hud.set_score_text("Rescate · tiros %d / %d" % [int(shots[0]), shots_max])
