class_name BotonCaida
extends Minigame
## «Botón de caída» (etapa 5): dos plataformas enfrentadas sobre un vacio; cada una tiene un boton fisico. Por turnos, cada
## jugador patea su pelota (fisica real: vuelo, efecto, rebotes en paredes, obstaculos y en el cuerpo del rival); si la
## pelota GOLPEA un boton con fuerza (impacto contra la cara del boton >= PRESS_SPEED: un roce o una pelota que llega
## rodando despacio no lo aprieta), se abre la trampilla de esa plataforma y su jugador cae. Gana el primero que hace caer
## al otro las veces del nivel. Contra la CPU, con las mismas reglas y la misma fisica (Minigame.cpu_shot); listo para dos
## personas en linea mas adelante (intenciones), sin implementarlo.
##
## Geometria por nivel (resources/minigames/minigames.json): ancho del vacio, boton (pared o piso; posicion, radio,
## movimiento), obstaculos fijos o moviles (en el marco de cada plataforma: se arman iguales en las dos, salvo "side"),
## altura y giro de cada plataforma, caidas para ganar. Marco de cada plataforma: +x local hacia el rival, el piso en
## y = 0 local, la pelota a 2 m del borde y el boton al fondo.

const SCENE := "res://scenes/minigames/boton_caida.tscn"
const DEPTH := 7.5
const WIDTH := 9.0
const HOLE := 2.0
const BALL_BACK := 2.2
## El jugador no pasa del borde (el seguimiento del golpeo lo llevaria al vacio): tope a EDGE_STOP m del borde.
const EDGE_STOP := 0.35
const BUTTON_X := -6.2
## Impacto minimo contra la cara del boton (m/s) para apretarlo.
const PRESS_SPEED := 2.5
const DOOR_OPEN_T := 0.35
const CAP_DEPTH := 0.14
## Error de la IA por dificultad (grados) y cuanto corrige de su ultimo fallo (aprende como una persona).
const CPU_ERROR := [1.8, 1.3, 1.0, 0.75, 0.55]
## (Con mas ganancia aprenderia del azar y empeoraria: medido.)
const CPU_LEARN := 0.3

var frames: Array[Transform3D] = []
## Por lado: {cap, board, kind, local (centro de la cara), normal_local, radius, move}
var buttons: Array = []
var doors: Array = []
var _door_t: Array = [-1.0, -1.0]
var _fall_v: Array = [0.0, 0.0]
var fallen: Array = [false, false]
var pressed: int = -1
var weak_touch: bool = false
## Obstaculos y botones que se mueven: {body, base (Transform3D en el mundo), axis, amp, speed, phase, spin_axis, spin}
var closest: Array = [INF, INF]
var _ai_bias := Vector3.ZERO
var _ai_aim := Vector3.INF
var _cross := Vector3.INF
var _hole_local: Array = [Vector3.ZERO, Vector3.ZERO]
## Mallas de los obstaculos y del tablero de cada plataforma: en el turno propio se ven translucidas (no tapan la pelota
## propia; la colision no cambia).
var _own_meshes: Array = [[], []]
## Pruebas y mediciones: error de la IA en grados (-1 = el de la dificultad).
var cpu_error_deg: float = -1.0

func game_id() -> String:
	return "boton_caida"

# --- Geometria -----------------------------------------------------------------------------------------------------------

func _foot(s: int) -> int:
	return SpSettings.foot if s == 0 else 1

func _build_level() -> void:
	sides = 2
	max_turns = int(def.get("max_turns", 24))
	var gap: float = float(def.get("gap", 14.0))
	var plats: Array = def.get("platforms", [{}, {}])
	frames.clear()
	for s in 2:
		var p: Dictionary = plats[s] if s < plats.size() else {}
		var yaw: float = deg_to_rad(float(p.get("yaw", 0.0)))
		var o := Vector3((-1.0 if s == 0 else 1.0) * gap * 0.5, float(p.get("y", 0.0)), float(p.get("dz", 0.0)))
		frames.append(Transform3D(Basis(Vector3.UP, yaw + (0.0 if s == 0 else PI)), o))
	buttons = [_button_def(0), _button_def(1)]
	for s in 2:
		_hole_local[s] = frames[s].affine_inverse() * _stance_world(s)
		_build_platform(s)
		_build_button(s)
		for ob in def.get("obstacles", []):
			var od: Dictionary = ob
			if od.has("side") and int(od["side"]) != s:
				continue
			_build_obstacle(s, od)
	# Abismo: un piso oscuro muy abajo y columnas bajo las plataformas (se ve que flotan).
	var abyss := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	abyss.mesh = pm
	abyss.material_override = color_mat(Color(0.04, 0.05, 0.1))
	abyss.position = Vector3(0, -30, 0)
	add_child(abyss)
	for s in 2:
		var col := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 2.2
		cm.bottom_radius = 0.8
		cm.height = 28.0
		col.mesh = cm
		col.material_override = color_mat(Color(0.25, 0.27, 0.34))
		add_child(col)
		col.global_position = frames[s] * Vector3(-DEPTH * 0.5, -15.0, 0.0)
	ball.body_entered.connect(_on_ball_body)

func _button_def(s: int) -> Dictionary:
	var b: Dictionary = def.get("button", {})
	var kind: String = String(b.get("kind", "wall"))
	var r: float = float(b.get("radius", 0.5))
	var local: Vector3
	var n: Vector3
	if kind == "floor":
		local = Vector3(float(b.get("x", -4.8)), 0.02 + CAP_DEPTH * 0.5, float(b.get("z", 0.0)))
		n = Vector3.UP
	else:
		local = Vector3(BUTTON_X, float(b.get("y", 1.2)), float(b.get("z", 0.0)))
		n = Vector3(1, 0, 0)
	return {"kind": kind, "local": local, "normal_local": n, "radius": r, "move": b.get("move", {}), "side": s}

## Centro de la cara del boton del lado s en el mundo (con su movimiento actual).
func button_center(s: int) -> Vector3:
	var b: Dictionary = buttons[s]
	if b.has("cap") and is_instance_valid(b["cap"]):
		var cap: Node3D = b["cap"]
		return cap.global_position + button_normal(s) * CAP_DEPTH * 0.5
	return frames[s] * (b["local"] as Vector3) + button_normal(s) * CAP_DEPTH * 0.5

func button_normal(s: int) -> Vector3:
	return (frames[s].basis * (buttons[s]["normal_local"] as Vector3)).normalized()

func button_velocity(s: int) -> Vector3:
	var mv: Dictionary = buttons[s]["move"]
	if mv.is_empty():
		return Vector3.ZERO
	var axis: Vector3 = frames[s].basis * _vec(mv.get("axis", [0, 0, 1])).normalized()
	var w: float = float(mv.get("speed", 1.0))
	return axis * float(mv.get("amp", 1.5)) * w * cos(level_time * w + float(mv.get("phase", 0.0)))

static func _vec(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))

func _ball_spot(s: int) -> Vector3:
	return frames[s] * Vector3(-BALL_BACK, 0.0, 0.0) + Vector3.UP * (ball.radius if ball != null else 0.11)

func _aim_point(s: int) -> Vector3:
	return button_center(1 - s)

func _stance_world(s: int) -> Vector3:
	var spot: Vector3 = _ball_spot(s)
	var aim: Vector3 = frames[1 - s] * (buttons[1 - s]["local"] as Vector3)
	var a := Vector3(aim.x - spot.x, 0.0, aim.z - spot.z).normalized()
	return Vector3(spot.x, frames[s].origin.y, spot.z) - a * STANCE.x - SpClips.right_of(a) * STANCE.y * float(_foot(s))

## Camara recomendada de Boton de caida (la de antes del cambio, recuperada de Git: 6 m detras, 6,5 m sobre la plataforma,
## mira 6 m por delante y sube con el 40 % de la altura del boton rival, 50 grados).
func camera_defaults() -> Dictionary:
	return {"back": 6.0, "height": 6.5, "ahead": 6.0, "lift_aim": 0.4, "fov": 50.0, "follow": 0.45}

func camera_base_y() -> float:
	return frames[side].origin.y

## Puntos del turno que conviene ver (la prueba de camara informa si alguno queda fuera con la camara recomendada).
func frame_points() -> Array:
	var o: int = 1 - side
	return [button_center(o), stance_point(o) + Vector3.UP * 1.9]

func _shot_ctx(s: int) -> Dictionary:
	var a: Vector3 = _aim_point(s)
	return GestureShotModel.context(a.x, Vector2(11.0, 30.0), false, WIDTH * 0.5, 5.0, ball.radius)

## Piso de la plataforma con el hueco de la trampilla bajo el lugar del jugador (cuatro bloques alrededor) y la trampilla
## de dos hojas con bisagra.
func _build_platform(s: int) -> void:
	var c: Color = Color(0.2, 0.45, 0.95) if s == 0 else Color(0.9, 0.25, 0.25)
	var h: Vector3 = _hole_local[s]
	var hx0: float = h.x - HOLE * 0.5
	var hx1: float = h.x + HOLE * 0.5
	var hz0: float = h.z - HOLE * 0.5
	var hz1: float = h.z + HOLE * 0.5
	var w2: float = WIDTH * 0.5
	var pieces := [
		[Vector3(-DEPTH, 0, -w2), Vector3(hx0, 0, w2)],
		[Vector3(hx1, 0, -w2), Vector3(0, 0, w2)],
		[Vector3(hx0, 0, -w2), Vector3(hx1, 0, hz0)],
		[Vector3(hx0, 0, hz1), Vector3(hx1, 0, w2)]]
	for pc in pieces:
		var a: Vector3 = pc[0]
		var b: Vector3 = pc[1]
		var size := Vector3(absf(b.x - a.x), 1.0, absf(b.z - a.z))
		if size.x < 0.01 or size.z < 0.01:
			continue
		var center := Vector3((a.x + b.x) * 0.5, -0.5, (a.z + b.z) * 0.5)
		static_box(size, frames[s] * center, c.darkened(0.15), frames[s].basis.get_euler(), 0.4)
	# Borde claro (se lee el limite contra el vacio).
	var edge := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(0.25, 0.04, WIDTH)
	edge.mesh = em
	edge.material_override = color_mat(Color(1, 0.85, 0.3), 0.4)
	add_child(edge)
	edge.global_transform = frames[s] * Transform3D(Basis(), Vector3(-0.12, 0.02, 0))
	# Trampilla: dos hojas (cada una la mitad del hueco a lo largo de z), giran hacia abajo sobre sus bordes.
	var leaves: Array = []
	for k in 2:
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.collision_layer = Ball.LAYER_WORLD
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(HOLE, 0.12, HOLE * 0.5)
		cs.shape = bs
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bs.size
		mi.mesh = bm
		mi.material_override = color_mat(Color(0.95, 0.75, 0.15))
		body.add_child(mi)
		add_child(body)
		leaves.append(body)
	doors.append(leaves)
	_set_door(s, 0.0)

## Pone la trampilla del lado s con un angulo de apertura u (0 cerrada .. 1 abierta, 90 grados).
func _set_door(s: int, u: float) -> void:
	var h: Vector3 = _hole_local[s]
	var ang: float = clampf(u, 0.0, 1.0) * PI * 0.5
	for k in 2:
		var sgn: float = -1.0 if k == 0 else 1.0
		var hinge := Vector3(h.x, -0.06, h.z + sgn * HOLE * 0.5)
		var rot := Basis(Vector3(1, 0, 0), -sgn * ang)
		var t := Transform3D(rot, hinge) * Transform3D(Basis(), Vector3(0, 0, -sgn * HOLE * 0.25))
		(doors[s][k] as AnimatableBody3D).global_transform = frames[s] * t

func _build_button(s: int) -> void:
	var b: Dictionary = buttons[s]
	var r: float = b["radius"]
	var floor_button: bool = String(b["kind"]) == "floor"
	var local: Vector3 = b["local"]
	var moving: bool = not (b["move"] as Dictionary).is_empty()
	# Tablero detras del boton de pared (no cuenta como boton).
	var board: Node3D = null
	if not floor_button:
		board = _body(moving, Vector3(0.3, 2.2, 2.4), Color(0.95, 0.95, 0.98), false)
		_track_meshes(s, board)
		board.global_transform = frames[s] * Transform3D(Basis(), Vector3(local.x - 0.15 - CAP_DEPTH * 0.5, 1.1, local.z))
		_add_mover_if(moving, board, b["move"], s)
	var cap := AnimatableBody3D.new()
	cap.sync_to_physics = false
	cap.collision_layer = Ball.LAYER_WORLD
	var pmat := PhysicsMaterial.new()
	pmat.bounce = 0.35
	cap.physics_material_override = pmat
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = CAP_DEPTH
	cs.shape = cyl
	cap.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = CAP_DEPTH
	mi.mesh = cm
	mi.material_override = color_mat(Color(0.95, 0.12, 0.1), 0.6)
	cap.add_child(mi)
	# Aro alrededor (se ve de lejos).
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r
	tm.outer_radius = r + 0.12
	ring.mesh = tm
	ring.material_override = color_mat(Color(1, 0.9, 0.3), 0.5)
	cap.add_child(ring)
	add_child(cap)
	var basis_local: Basis = Basis() if floor_button else Basis(Vector3(0, 0, 1), PI * 0.5)
	cap.global_transform = frames[s] * Transform3D(basis_local, local)
	b["cap"] = cap
	b["cap_mesh"] = mi
	# Señal sobre el boton (se ve por encima de muros y techos: dice donde esta el objetivo, no ayuda a apuntar).
	var beacon := MeshInstance3D.new()
	var bt := TorusMesh.new()
	bt.inner_radius = 0.28
	bt.outer_radius = 0.4
	beacon.mesh = bt
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.no_depth_test = true
	bmat.albedo_color = Color(1.0, 0.25, 0.2, 0.9)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.render_priority = 1
	beacon.material_override = bmat
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beacon)
	b["beacon"] = beacon
	b["base"] = cap.global_transform
	_add_mover_if(moving, cap, b["move"], s)

func _body(animated: bool, size: Vector3, color: Color, round_post: bool) -> PhysicsBody3D:
	var body: PhysicsBody3D
	if animated:
		var ab := AnimatableBody3D.new()
		ab.sync_to_physics = false
		body = ab
	else:
		body = StaticBody3D.new()
	body.collision_layer = Ball.LAYER_WORLD
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.5
	pm.friction = 0.6
	body.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	if round_post:
		var cy := CylinderShape3D.new()
		cy.radius = size.x * 0.5
		cy.height = size.y
		cs.shape = cy
		var cm := CylinderMesh.new()
		cm.top_radius = size.x * 0.5
		cm.bottom_radius = size.x * 0.5
		cm.height = size.y
		mi.mesh = cm
	else:
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
	body.add_child(cs)
	mi.material_override = color_mat(color)
	body.add_child(mi)
	add_child(body)
	return body

func _track_meshes(s: int, body: Node) -> void:
	for c in body.get_children():
		if c is MeshInstance3D:
			(_own_meshes[s] as Array).append(c)

## Obstaculos propios translucidos para el que patea (los del rival, opacos).
func _fade_own(shooter_side: int) -> void:
	for s in 2:
		for mi in _own_meshes[s]:
			var m: StandardMaterial3D = (mi as MeshInstance3D).material_override
			var faded: bool = s == shooter_side
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if faded else BaseMaterial3D.TRANSPARENCY_DISABLED
			m.albedo_color.a = 0.28 if faded else 1.0
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if faded else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _add_mover_if(moving: bool, body: Node3D, mv: Dictionary, s: int) -> void:
	if not moving:
		return
	add_mover(body, frames[s].basis * _vec(mv.get("axis", [0, 0, 1])), float(mv.get("amp", 1.5)), float(mv.get("speed", 1.0)),
		float(mv.get("phase", 0.0)), frames[s].basis * _vec(mv.get("spin_axis", [1, 0, 0])), float(mv.get("spin", 0.0)))

## Obstaculo en el marco de la plataforma s: "box", "post" (cilindro), "wall"; con "move" (va y viene) o "spin" (gira).
func _build_obstacle(s: int, od: Dictionary) -> void:
	var t: String = String(od.get("type", "box"))
	var size: Vector3 = _vec(od.get("size", [0.4, 2.0, 0.4]))
	var pos: Vector3 = _vec(od.get("pos", [-3.0, 1.0, 0.0]))
	var mv: Dictionary = od.get("move", {})
	var moving: bool = not mv.is_empty()
	var color: Color = Color(0.55, 0.6, 0.7) if t != "wall" else Color(0.85, 0.85, 0.9)
	if moving:
		color = Color(0.95, 0.55, 0.15)
	var body: Node3D = _body(moving, size, color, t == "post")
	var rot := Basis()
	if od.has("yaw"):
		rot = Basis(Vector3.UP, deg_to_rad(float(od["yaw"])))
	body.global_transform = frames[s] * Transform3D(rot, pos)
	_track_meshes(s, body)
	_add_mover_if(moving, body, mv, s)
	if moving:
		movers.back()["obstacle"] = true
		movers.back()["half"] = size * 0.5

# --- Mecanismos ----------------------------------------------------------------------------------------------------------

func _ready() -> void:
	# Despues de los jugadores (su raiz se mueve en su paso de fisica): el tope del borde se aplica sobre lo que hicieron.
	process_physics_priority = 10
	super._ready()

func _level_step(delta: float) -> void:
	for s in shooters.size():
		var a: SpActor = shooters[s].actor
		if fallen[s] or not a.visible:
			continue
		var loc: Vector3 = frames[s].affine_inverse() * a.global_position
		if loc.x > -EDGE_STOP:
			loc.x = -EDGE_STOP
			a.global_position = frames[s] * loc
	for s in 2:
		var bc: MeshInstance3D = buttons[s].get("beacon")
		if bc != null:
			var top: float = 1.1 if String(buttons[s]["kind"]) == "floor" else 1.5
			bc.global_position = button_center(s) + Vector3.UP * (top + 0.15 * sin(level_time * 3.0))
			# Solo el objetivo del que patea.
			bc.visible = not fallen[s] and s != side
		if float(_door_t[s]) >= 0.0:
			_door_t[s] = float(_door_t[s]) + delta
			_set_door(s, float(_door_t[s]) / DOOR_OPEN_T)
		if fallen[s] and s < shooters.size():
			var a: SpActor = shooters[s].actor
			if a.visible:
				_fall_v[s] = float(_fall_v[s]) + 9.8 * delta
				a.ground_y -= float(_fall_v[s]) * delta
				a.global_position.y = a.ground_y
				if a.ground_y < frames[s].origin.y - 14.0:
					a.visible = false

func _on_ball_body(body: Node) -> void:
	if state != State.FLIGHT or pressed >= 0:
		return
	for s in 2:
		if body == buttons[s].get("cap"):
			var n: Vector3 = button_normal(s)
			var rel: Vector3 = prev_velocity() - button_velocity(s)
			var impact: float = -rel.dot(n)
			if impact >= PRESS_SPEED and not fallen[s]:
				press(s)
			else:
				weak_touch = true

## Aprieta el boton del lado s: se hunde y se pone verde, se abre la trampilla y su jugador cae.
func press(s: int) -> void:
	pressed = s
	var b: Dictionary = buttons[s]
	var cap: Node3D = b["cap"]
	cap.global_position -= button_normal(s) * CAP_DEPTH * 0.6
	(b["cap_mesh"] as MeshInstance3D).material_override = color_mat(Color(0.2, 0.95, 0.3), 0.8)
	# Un boton que se movia queda quieto apretado.
	for m in movers:
		if m["body"] == cap:
			m["base"] = cap.global_transform
			m["amp"] = 0.0
	_door_t[s] = 0.0
	fallen[s] = true
	_fall_v[s] = 0.0
	if s < shooters.size():
		var a: SpActor = shooters[s].actor
		a.stop_moving()
		var falls: Array[StringName] = SpClips.by_role(&"fall", false)
		if not falls.is_empty():
			a.freeze_on_finish = true
			a.play_here(falls[rng.randi() % falls.size()], 0.1)
	if not fast:
		cam.shake(0.45, 0.8)
		Sfx.play(&"cheer", 0.6)

## Respawn: trampillas cerradas, botones sin apretar, jugadores de pie en su lugar.
func _restore_mechanisms() -> void:
	pressed = -1
	weak_touch = false
	for s in 2:
		_door_t[s] = -1.0
		_set_door(s, 0.0)
		var b: Dictionary = buttons[s]
		if b.has("cap"):
			var cap: Node3D = b["cap"]
			(b["cap_mesh"] as MeshInstance3D).material_override = color_mat(Color(0.95, 0.12, 0.1), 0.6)
			var base: Transform3D = b["base"]
			var moving: bool = false
			for m in movers:
				if m["body"] == cap:
					moving = true
					m["amp"] = float((b["move"] as Dictionary).get("amp", 1.5))
					m["base"] = base
			if not moving:
				cap.global_transform = base
		if fallen[s] and s < shooters.size():
			fallen[s] = false
			var a: SpActor = shooters[s].actor
			a.freeze_on_finish = false
			a.visible = true
			_place_shooter(s)

func reset_level() -> void:
	level_time = 0.0
	_ai_bias = Vector3.ZERO
	closest = [INF, INF]
	_restore_mechanisms()
	super.reset_level()

func _start_turn() -> void:
	_restore_mechanisms()
	_cross = Vector3.INF
	_fade_own(side)
	# El que no patea espera parado en su lugar (sobre su trampilla).
	for s in shooters.size():
		if s != side and shooters[s].actor.visible:
			_place_shooter(s)
	super._start_turn()

# --- Reglas ----------------------------------------------------------------------------------------------------------------

func _flight_check(_delta: float) -> String:
	var target: Vector3 = button_center(1 - side)
	closest[side] = minf(float(closest[side]), ball.global_position.distance_to(target))
	# Donde cruza el plano del boton rival (para que la IA corrija su proximo tiro).
	if _cross == Vector3.INF:
		var n: Vector3 = button_normal(1 - side)
		if (ball.global_position - target).dot(n) <= 0.0:
			_cross = ball.global_position
	if pressed >= 0:
		return "boton"
	var p: Vector3 = ball.global_position
	if absf(p.z) > 40.0 or absf(p.x) > 60.0:
		return "afuera"
	return ""

func _on_resolved(s: int, result: String) -> void:
	if result == "boton" and pressed >= 0:
		points[1 - pressed] += 1
		var shooter_won: bool = pressed != s
		var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if shooter_won else SpReactions.MISS_SHOOTER, rng, 1.5, 1.0)
		if id != &"" and shooters[s].actor.visible:
			shooters[s].actor.play_here(id, 0.3)
	elif s < shooters.size():
		var id2: StringName = SpReactions.pick(SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
		if id2 != &"":
			shooters[s].actor.play_here(id2, 0.3)
	# IA: aprende de su fallo (corrige parte de la diferencia entre donde cruzo y el boton), como una persona.
	if s == Side.CPU and result != "boton" and _cross != Vector3.INF and _ai_aim != Vector3.INF:
		var miss: Vector3 = _cross - button_center(Side.USER)
		miss.x = 0.0
		# Un boton que se mueve: el error a lo largo de su vaiven es de tiempo, no de punteria (no se aprende).
		var mv: Dictionary = buttons[Side.USER]["move"]
		if not mv.is_empty():
			var axis: Vector3 = (frames[Side.USER].basis * _vec(mv.get("axis", [0, 0, 1]))).normalized()
			miss -= axis * miss.dot(axis)
		_ai_bias -= miss * CPU_LEARN
		_ai_bias = _ai_bias.limit_length(2.5)

func _check_winner() -> int:
	var need: int = int(def.get("points_to_win", 2))
	if points[0] >= need:
		return Side.USER
	if points[1] >= need:
		return Side.CPU
	return -1

func final_score() -> int:
	var misses: int = maxi(int(shots[0]) - int(points[0]), 0)
	var s: int = 100 * int(points[0]) + maxi(150 - 25 * misses, 0)
	if int(points[1]) == 0:
		s += 50
	return s if winner == Side.USER else mini(s, 100 * int(points[0]))

func _report_achievements(w: int, medal: int) -> void:
	super._report_achievements(w, medal)
	if int(points[0]) > 0:
		Achievements.event(&"boton", int(points[0]))

func _result_text(r: String) -> Array:
	match r:
		"boton":
			if pressed == 1 - side:
				return ["¡CAYÓ!" if side == Side.USER else "¡TE TIRÓ!", Color(0.35, 1.0, 0.45) if side == Side.USER else Color(1.0, 0.4, 0.4),
					"Le diste al botón"]
			return ["¡AL PROPIO BOTÓN!", Color(1.0, 0.6, 0.3), "Se abrió tu piso"]
		"vacio":
			return ["Al vacío", Color(1.0, 0.75, 0.4), "Sin premio" if not weak_touch else "Tocó el botón sin fuerza"]
		"quieta", "tiempo":
			return ["Sin fuerza" if weak_touch else "Se quedó", Color(1.0, 0.75, 0.4), "El botón necesita un golpe fuerte" if weak_touch else ""]
	return ["Afuera", Color(1.0, 0.4, 0.4), ""]

## IA: apunta al centro del boton del usuario (o al punto del truco del nivel: ai_aim, en el marco de la plataforma del
## usuario), adelanta un boton que se mueve segun el tiempo de vuelo, corrige con lo aprendido, espera su momento si hay
## obstaculos que se mueven (mira por donde van a estar, como una persona) y patea con su error.
func _cpu_intent() -> Dictionary:
	var ai: Dictionary = def.get("ai", {})
	var target: Vector3 = button_center(Side.USER)
	if ai.has("aim"):
		target = frames[Side.USER] * _vec(ai["aim"])
	var spot: Vector3 = _ball_spot(Side.CPU)
	var dist: float = spot.distance_to(target)
	var speed: float = float(ai.get("speed", clampf(dist * 0.85 + 6.0, 14.0, 27.0)))
	var spin: float = float(ai.get("spin", 0.0))
	var bv: Vector3 = button_velocity(Side.USER)
	if not (buttons[Side.USER]["move"] as Dictionary).is_empty():
		# Tiempo de vuelo del tiro previsto (mismo modelo que el usuario) mas la carrera hasta el contacto.
		var first: Dictionary = cpu_shot(target, speed, spin, 0.0)
		var tc: float = ShotSolver.crossing_time(first["trajectory"], target.x)
		var t_fly: float = runup_time + (tc if tc > 0.0 else dist / maxf(speed * 0.9, 1.0))
		# Posicion del boton cuando llegue la pelota (lo ve moverse: no adivina, extrapola su vaiven).
		var mv: Dictionary = buttons[Side.USER]["move"]
		var w: float = float(mv.get("speed", 1.0))
		var axis: Vector3 = frames[Side.USER].basis * _vec(mv.get("axis", [0, 0, 1])).normalized()
		var amp: float = float(mv.get("amp", 1.5))
		var now_off: float = amp * sin(level_time * w + float(mv.get("phase", 0.0)))
		var then_off: float = amp * sin((level_time + t_fly) * w + float(mv.get("phase", 0.0)))
		target += axis * (then_off - now_off)
	target += _ai_bias
	var err: float = cpu_error_deg if cpu_error_deg >= 0.0 else float(CPU_ERROR[SpSettings.level()])
	if not _has_moving_obstacles():
		_ai_aim = target
		return cpu_shot(target, speed, spin, err)
	# Obstaculos en movimiento: prueba el centro y puntos del boton corridos; patea cuando el camino previsto queda libre.
	var r: float = float(buttons[Side.USER]["radius"]) * 0.6
	var right: Vector3 = (frames[Side.USER].basis * Vector3(0, 0, 1)).normalized()
	for off in [Vector3.ZERO, right * r, -right * r, Vector3.UP * r, Vector3.DOWN * r]:
		var it: Dictionary = cpu_shot(target + off, speed, spin, 0.0)
		if _path_clear(it["trajectory"], runup_time):
			_ai_aim = target + off
			return cpu_shot(target + off, speed, spin, err)
	if cpu_force:
		_ai_aim = target
		return cpu_shot(target, speed, spin, err)
	return {}

func _has_moving_obstacles() -> bool:
	for m in movers:
		if bool(m.get("obstacle", false)):
			return true
	return false

## El camino previsto (puntos cada ShotSolver.STEP, saliendo dentro de `delay` s) no toca ningun obstaculo que se mueve,
## con cada obstaculo donde va a estar en ese instante.
func _path_clear(traj: PackedVector3Array, delay: float) -> bool:
	var r: float = ball.radius + 0.05
	for m in movers:
		if not bool(m.get("obstacle", false)):
			continue
		var half: Vector3 = m["half"]
		for i in traj.size():
			var t: float = level_time + delay + float(i) * ShotSolver.STEP
			var x: Transform3D = mover_at(m, t)
			var q: Vector3 = x.affine_inverse() * traj[i]
			if absf(q.x) <= half.x + r and absf(q.y) <= half.y + r and absf(q.z) <= half.z + r:
				return false
	return true

