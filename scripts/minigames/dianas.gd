class_name Dianas
extends Minigame
## Dianas (DESAFIOS DE ARCO, catalogo #43). Blancos 3D que MIRAN AL JUGADOR (la cara apunta al punto de tiro; antes las
## placas quedaban de canto). Cada blanco tiene zonas con puntaje configurable que se cuentan en el PUNTO DE IMPACTO REAL:
## se cruza la trayectoria de la pelota del paso anterior al choque con el plano de la cara del blanco (en el marco del
## blanco, que puede estar hamacandose o moviendose). Nada se cuenta sin un choque fisico.
##
## Tipos de blanco (minigames.json "dianas", lista "plates"):
##  - "hang" (por defecto): cuelga de una barra (fija, en X o en Z, o un carrusel que gira) con una articulacion
##    (PinJoint3D). Se balancea con el golpe; un impacto fuerte (o varios, segun "hits") la desprende y cae.
##  - "fixed": tablero fijo o sobre un riel que va y viene ("move": {axis, amp, speed, phase}); solo suma puntos.
## Forma: "round" (radio "r"; zonas = anillos [[fraccion del radio, puntos], ...] del centro hacia afuera) o "panel"
## (tamaño "size" [ancho, alto]; zonas = rectangulos [[x0, y0, x1, y1, puntos], ...] en coordenadas -1..1 vistas por quien
## patea: x a la derecha, y arriba; gana la primera que contiene el punto). Sin "zones" se usan las de DEFAULT_*.
## Objetivo del nivel ("goal"): "derribar" (todas abajo; termina antes si caen todas) o "puntos" (sumar con los tiros).
## Puntaje: puntos de zona + PLATE_POINTS por blanco caido + SPARE_SHOT por tiro de sobra al derribar todo.
## Dificultad (Facil..Experto): los blancos son un poco mas grandes o mas chicos y lo que se mueve va mas lento o mas
## rapido (SIZE_BY_DIFF, SPEED_BY_DIFF), ademas del tiro de mas/de menos comun del catalogo.

const SCENE := "res://scenes/minigames/dianas.tscn"
## Un toque mas lento que esto no hace daño (un roce no desmonta nada).
const MIN_HIT := 2.4
## Un impacto mas lento que esto no suma puntos de zona (la pelota que cae rodando sobre un tablero no cuenta).
const MIN_SCORE_HIT := 3.0
const PLATE_POINTS := 50
const SPARE_SHOT := 40
const SIZE_BY_DIFF := [1.15, 1.0, 0.92, 0.85]
const SPEED_BY_DIFF := [0.8, 1.0, 1.15, 1.3]
## Anillos por defecto (centro dorado 10, rojo 7, azul 5, negro 3, blanco 1) y colores de tiro con arco.
const DEFAULT_RINGS := [[0.2, 10], [0.4, 7], [0.6, 5], [0.8, 3], [1.0, 1]]
const RING_COLORS := [Color(1.0, 0.82, 0.12), Color(0.9, 0.16, 0.14), Color(0.16, 0.45, 0.9), Color(0.1, 0.1, 0.12), Color(0.95, 0.95, 0.93)]
## Tablero por defecto (el ejemplo del pedido): esquinas de arriba 10, centro 5, franja baja 1, el resto 2.
const DEFAULT_PANEL := [[-1.0, 0.5, -0.6, 1.0, 10], [0.6, 0.5, 1.0, 1.0, 10], [-0.3, -0.3, 0.3, 0.4, 5], [-1.0, -1.0, 1.0, -0.6, 1], [-1.0, -1.0, 1.0, 1.0, 2]]

## Blancos: {body, kind, shape, r, size (Vector2), th, zones, joint, rope, hits, hits0, detached, fallen, home, anchor,
## scored (tiro en que ya sumo), pv, px (transform antes del paso)}
var plates: Array = []
var shots_max: int = 3
var goal: String = "derribar"
## Puntos de zona sumados y ultimo impacto (para las pruebas y el cartel).
var zone_points: int = 0
var last_hit: Dictionary = {}
var hits_log: Array = []
var _carousel: Node3D = null
var _bar: Node3D = null
var _bp := Vector3.ZERO
var _bv := Vector3.ZERO
var _size_mul: float = 1.0
## Diana en el suelo ("floor": {x, z, r, rings}): cuenta donde PICA la pelota por primera vez (no donde queda).
var floor_t: Dictionary = {}
var floor_scored_shot: int = -1
var _speed_mul: float = 1.0

## Plataforma del jugador elevada (estilo arcade comun).
func default_deck() -> float:
	return 2.5

## Camara: con diana en el suelo mira lejos y desde mas arriba (el blanco esta en el piso, a 34-42 m).
func camera_defaults() -> Dictionary:
	if def.has("floor"):
		return {"back": 9.5, "height": 4.6, "ahead": 13.0, "lift_aim": 0.0, "fov": 50.0, "follow": 0.45}
	return super.camera_defaults()

func uses_night_arena() -> bool:
	return true

func game_id() -> String:
	return "dianas"

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 3))
	max_turns = shots_max
	var dif: int = clampi(int(def.get("difficulty", 1)), 0, 3)
	_size_mul = float(SIZE_BY_DIFF[dif])
	_speed_mul = float(SPEED_BY_DIFF[dif])
	var has_hang := false
	for pd in def.get("plates", []):
		if String((pd as Dictionary).get("kind", "hang")) == "hang":
			has_hang = true
	goal = String(def.get("goal", "derribar" if has_hang else "puntos"))
	_build_stage()
	var bar_h: float = float(def.get("bar_h", 2.6))
	if has_hang:
		_build_bar(bar_h)
	for w in def.get("walls", []):
		var wd: Dictionary = w
		var wall := static_box(BotonCaida._vec(wd.get("size", [3, 1, 0.3])), BotonCaida._vec(wd.get("pos", [8, 0.5, 0])), Color(0.85, 0.85, 0.9), Vector3.ZERO, 0.5)
		_dress(wall, ArcadeLook.mat(Color(0.78, 0.36, 0.22), "stone", 2.0))
	for pd in def.get("plates", []):
		_spawn_target(pd, bar_h)
	_build_floor_target()
	ball.body_entered.connect(_on_ball_body)

## Escenario: cesped a franjas, campo de tiro con vallas, cartel y banderas (solo visual; el piso es el de siempre).
func _build_stage() -> void:
	var ground := static_box(Vector3(70, 1, 40), Vector3(8, -0.5, 0), Color(0.2, 0.42, 0.25), Vector3.ZERO, 0.45)
	_dress(ground, null)
	ArcadeLook.grass(self, Vector2(160, 120), Vector3(20, 0, 0), 32)
	# Linea de tiro y punto de pelota.
	ArcadeLook.deco(self, "box", Vector3(0.08, 0.01, 6.0), Vector3(-0.6, 0.006, 0), ArcadeLook.mat(Color(0.95, 0.95, 0.95), "paint"))
	ArcadeLook.deco(self, "cyl", Vector3(0.22, 0.01, 0.22), _ball_spot(0) - Vector3(0, _ball_spot(0).y - 0.007, 0), ArcadeLook.mat(Color(0.95, 0.95, 0.95), "paint"))
	# Fondo: tribuna baja de madera y un cartel; vallas a los costados del campo de tiro (fuera de la linea de tiro: lo
	# decorativo no tiene colision, asi que nada decorativo se cruza en el camino de la pelota).
	# (Con diana en el suelo la tribuna va detras de la diana.)
	var fl: Dictionary = def.get("floor", {})
	var back_x: float = maxf(26.0, float(fl.get("x", 0.0)) + float(fl.get("r", 0.0)) + 8.0)
	ArcadeLook.deco(self, "box", Vector3(1.2, 2.2, 30.0), Vector3(back_x, 1.1, 0), ArcadeLook.mat(Color(0.55, 0.38, 0.22), "wood", 3.0))
	ArcadeLook.deco(self, "box", Vector3(1.2, 1.4, 30.0), Vector3(back_x + 1.2, 2.2, 0), ArcadeLook.mat(Color(0.5, 0.34, 0.2), "wood", 3.0))
	ArcadeLook.billboard(self, "DIANAS", Vector3(back_x - 0.7, 4.2, 0), 7.0, 1.4)
	for z in [-12.5, 12.5]:
		for i in 7:
			var c: Color = [Color(0.85, 0.2, 0.15), Color(0.95, 0.95, 0.95), Color(0.15, 0.35, 0.85)][i % 3]
			ArcadeLook.deco(self, "box", Vector3(3.6, 0.8, 0.12), Vector3(2.0 + float(i) * 3.7, 0.4, z), ArcadeLook.mat(c, "paint"))
		for x in [6.0, 15.0, 24.0]:
			ArcadeLook.flag(self, Vector3(x, 0, z * 1.04), Color(1.0, 0.82, 0.12) if x == 15.0 else Color(0.95, 0.95, 0.95))

## Diana en el suelo (referencia del usuario: gigante, lejos; marca donde pica la pelota). Anillos [[fraccion, puntos]].
const FLOOR_RINGS := [[0.33, 100], [0.66, 50], [1.0, 25]]
const FLOOR_COLORS := [Color(0.9, 0.12, 0.12), Color(0.95, 0.95, 0.95), Color(0.15, 0.4, 0.95)]

func floor_center() -> Vector3:
	return Vector3(float(floor_t.get("x", 32.0)), 0.0, float(floor_t.get("z", 0.0)))

func floor_radius() -> float:
	return float(floor_t.get("r", 7.0)) * _size_mul

func _build_floor_target() -> void:
	floor_t = def.get("floor", {})
	if floor_t.is_empty():
		return
	var c: Vector3 = floor_center()
	var r: float = floor_radius()
	var rings: Array = floor_t.get("rings", FLOOR_RINGS)
	# Anillos pintados de afuera hacia adentro (cada uno un poco mas arriba), borde de luces.
	for i in range(rings.size() - 1, -1, -1):
		var rr: float = r * float(rings[i][0])
		var col: Color = FLOOR_COLORS[i % FLOOR_COLORS.size()]
		ArcadeLook.deco(self, "cyl", Vector3(rr, 0.02, rr), c + Vector3(0, 0.01 + 0.003 * float(rings.size() - i), 0), ArcadeLook.mat(col, "plastic"))
	ArcadeLook.deco(self, "cyl", Vector3(r + 0.25, 0.03, r + 0.25), c + Vector3(0, 0.004, 0), ArcadeLook.mat(Color(0.12, 0.12, 0.16), "metal"))
	for k in 28:
		var a: float = TAU * float(k) / 28.0
		ArcadeLook.deco(self, "box", Vector3(0.35, 0.1, 0.18), c + Vector3(cos(a) * (r + 0.15), 0.06, sin(a) * (r + 0.15)), ArcadeLook.glow(Color(1.0, 0.7, 0.25), 2.6), Vector3(0, -a, 0))
	for i in rings.size():
		var l := Label3D.new()
		l.text = str(int(rings[i][1]))
		l.font_size = 128
		l.pixel_size = 0.012
		l.rotation_degrees = Vector3(-90, -90, 0)
		l.modulate = Color(0.1, 0.1, 0.12) if i == 1 else Color(1, 1, 1)
		add_child(l)
		var mid: float = r * (float(rings[i][0]) + (float(rings[i - 1][0]) if i > 0 else 0.0)) * 0.5
		l.global_position = c + Vector3(-mid if i > 0 else 0.0, 0.05, 0)
	ball.floor_bounce.connect(_on_floor_bounce)

## Primer pique del tiro: su punto decide los puntos (el anillo que contiene ese punto).
func _on_floor_bounce(pos: Vector3, _speed: float) -> void:
	if state != State.FLIGHT or floor_scored_shot == int(shots[0]) or pos.x < 3.0:
		return
	floor_scored_shot = int(shots[0])
	var d: float = Vector2(pos.x - floor_center().x, pos.z - floor_center().z).length() / floor_radius()
	var pts: int = 0
	for rg in floor_t.get("rings", FLOOR_RINGS):
		if d <= float(rg[0]):
			pts = int(rg[1])
			break
	last_hit = {"points": pts, "point": Vector2(pos.z, pos.x), "target": -1, "speed": 0.0, "shot": int(shots[0])}
	hits_log.append(last_hit)
	zone_points += pts
	if pts > 0:
		_popup(pts, pos + Vector3.UP * 0.5)
	_refresh_score()

## Pone un material propio a la malla de una caja de static_box (o la oculta si m es null).
func _dress(body: Node3D, m: Material) -> void:
	for c in body.get_children():
		if c is MeshInstance3D:
			if m == null:
				(c as MeshInstance3D).visible = false
			else:
				(c as MeshInstance3D).material_override = m

func _build_bar(bar_h: float) -> void:
	var metal := ArcadeLook.mat(Color(0.8, 0.81, 0.86), "metal")
	var post_m := ArcadeLook.mat(Color(0.22, 0.24, 0.3), "metal")
	var car: Dictionary = def.get("carousel", {})
	if not car.is_empty():
		# Carrusel: un poste y una cruz que gira; las placas cuelgan de sus brazos (la articulacion acompaña el giro).
		var post := static_box(Vector3(0.18, bar_h, 0.18), Vector3(float(car.get("x", 12.0)), bar_h * 0.5, 0), Color(0.35, 0.37, 0.42))
		_dress(post, post_m)
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
		mi.material_override = metal
		bar.add_child(mi)
		add_child(bar)
		bar.global_position = Vector3(float(car.get("x", 12.0)), bar_h, 0)
		add_mover(bar, Vector3.ZERO, 0.0, 1.0, 0.0, Vector3.UP, float(car.get("speed", 0.9)) * _speed_mul)
		_carousel = bar
		post.name = "CarouselPost"
		return
	var blen: float = float(def.get("bar_len", 8.0))
	var bx: float = float(def.get("bar_x", 12.0))
	var along_x: bool = String(def.get("bar_axis", "z")) == "x"
	var size := Vector3(blen, 0.14, 0.14) if along_x else Vector3(0.3, 0.14, blen)
	_bar = static_box(size, Vector3(bx, bar_h, 0), Color(0.8, 0.8, 0.85))
	_dress(_bar, metal)
	if along_x:
		# Barra a lo largo del tiro: en cada punta un portico (travesaño en Z y dos postes a los costados) para que ningun
		# poste quede en la linea de tiro.
		for o in [-blen * 0.5, blen * 0.5]:
			var cross := static_box(Vector3(0.14, 0.14, 2.0), Vector3(bx + o, bar_h, 0), Color(0.8, 0.8, 0.85))
			_dress(cross, metal)
			for zs in [-0.95, 0.95]:
				var pp := static_box(Vector3(0.16, bar_h, 0.16), Vector3(bx + o, bar_h * 0.5, zs), Color(0.35, 0.37, 0.42))
				_dress(pp, post_m)
				ArcadeLook.deco(self, "cyl", Vector3(0.22, 0.08, 0.26), Vector3(bx + o, 0.04, zs), post_m)
		return
	for o in [-blen * 0.5 + 0.2, blen * 0.5 - 0.2]:
		var p := static_box(Vector3(0.16, bar_h, 0.16), Vector3(bx, bar_h * 0.5, o), Color(0.35, 0.37, 0.42))
		_dress(p, post_m)
		ArcadeLook.deco(self, "cyl", Vector3(0.22, 0.08, 0.26), Vector3(bx, 0.04, o), post_m)

## Giro (yaw) para que la cara del blanco (-X local) mire al punto de tiro.
func _facing_yaw(pos: Vector3) -> float:
	var d: Vector3 = _ball_spot(0) - pos
	d.y = 0.0
	if d.length() < 0.01:
		return 0.0
	d = d.normalized()
	return atan2(d.z, -d.x)

func _spawn_target(pd: Dictionary, bar_h: float) -> void:
	var kind: String = String(pd.get("kind", "hang"))
	var shape: String = String(pd.get("shape", "round"))
	var pos: Vector3 = BotonCaida._vec(pd.get("pos", [12, 0, 0]))
	var r: float = float(pd.get("r", 0.32)) * _size_mul
	var sz: Array = pd.get("size", [2.4, 1.6])
	var size := Vector2(float(sz[0]), float(sz[1])) * _size_mul
	var th: float = float(pd.get("th", 0.07))
	var zones: Array = pd.get("zones", DEFAULT_RINGS if shape == "round" else DEFAULT_PANEL)
	var body: PhysicsBody3D
	var move: Dictionary = pd.get("move", {})
	if kind == "hang":
		var rb := RigidBody3D.new()
		rb.mass = float(pd.get("mass", 0.5))
		rb.contact_monitor = true
		rb.max_contacts_reported = 4
		rb.linear_damp = 0.3
		rb.angular_damp = 0.5
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.4
		rb.physics_material_override = pm
		body = rb
	elif not move.is_empty():
		var ab := AnimatableBody3D.new()
		ab.sync_to_physics = false
		body = ab
	else:
		body = StaticBody3D.new()
	body.collision_layer = Ball.LAYER_WORLD
	body.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
	var cs := CollisionShape3D.new()
	if shape == "round":
		var cy := CylinderShape3D.new()
		cy.radius = r
		cy.height = th
		cs.shape = cy
		cs.rotation_degrees = Vector3(0, 0, 90)
	else:
		var bs := BoxShape3D.new()
		bs.size = Vector3(th, size.y, size.x)
		cs.shape = bs
	body.add_child(cs)
	var tough: int = int(pd.get("hits", 1))
	if shape == "round":
		_dress_round(body, r, th, zones, tough > 1)
	else:
		_dress_panel(body, size, th, zones)
	var hang: float = float(pd.get("hang", 0.55))
	var anchor := Vector3(pos.x, bar_h - 0.07, pos.z)
	var center: Vector3 = (anchor + Vector3.DOWN * (hang + r)) if kind == "hang" else pos
	add_child(body)
	body.global_position = center
	body.rotation = Vector3(0, _facing_yaw(center), 0)
	var e := {"body": body, "kind": kind, "shape": shape, "r": r, "size": size, "th": th, "zones": zones,
		"hits": tough, "hits0": tough, "detached": false, "fallen": false, "home": body.global_transform,
		"anchor": anchor, "scored": -1, "pv": Vector3.ZERO, "px": body.global_transform, "joint": null, "rope": null}
	if kind == "hang":
		e["joint"] = _pin(anchor, body)
		var rope := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.012
		rm.bottom_radius = 0.012
		rm.height = hang
		rm.radial_segments = 6
		rope.mesh = rm
		rope.material_override = ArcadeLook.mat(Color(0.3, 0.3, 0.32), "metal")
		add_child(rope)
		rope.global_position = anchor + Vector3.DOWN * hang * 0.5
		e["rope"] = rope
		# Gancho visual sobre la barra.
		ArcadeLook.deco(self, "sphere", Vector3(0.04, 0, 0), anchor, ArcadeLook.mat(Color(0.9, 0.75, 0.2), "metal"))
	elif not move.is_empty():
		var ax: Vector3 = BotonCaida._vec(move.get("axis", [0, 0, 1]))
		add_mover(body, ax, float(move.get("amp", 1.5)), float(move.get("speed", 1.0)) * _speed_mul, float(move.get("phase", 0.0)))
		# Riel visual por debajo del tablero.
		var half: float = float(move.get("amp", 1.5)) + (r if shape == "round" else size.x * 0.5)
		ArcadeLook.deco(self, "box", Vector3(0.12, 0.08, half * 2.0), Vector3(center.x, 0.04, center.z), ArcadeLook.mat(Color(0.3, 0.3, 0.34), "metal"))
	if kind != "hang":
		# Pie del tablero hasta el piso (visual, pegado al blanco: se mueve con el).
		var leg_h: float = center.y - (r if shape == "round" else size.y * 0.5)
		if leg_h > 0.05:
			var leg := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.05
			lm.bottom_radius = 0.07
			lm.height = leg_h
			lm.radial_segments = 8
			leg.mesh = lm
			leg.material_override = ArcadeLook.mat(Color(0.22, 0.24, 0.3), "metal")
			body.add_child(leg)
			leg.position = Vector3(0.12, -(r if shape == "round" else size.y * 0.5) - leg_h * 0.5, 0)
	plates.append(e)
	if body is RigidBody3D:
		(body as RigidBody3D).body_entered.connect(_on_plate_hit.bind(body))

func _pin(anchor: Vector3, body: Node3D) -> PinJoint3D:
	var j := PinJoint3D.new()
	add_child(j)
	j.global_position = anchor
	# El pin une la placa con la barra (fija o carrusel): el anclaje acompaña a la barra.
	j.node_a = j.get_path_to(_carousel if _carousel != null else _bar)
	j.node_b = j.get_path_to(body)
	return j

## Diana redonda: respaldo de madera, anillos de colores en relieve (uno por zona, del de afuera al centro), aro de metal
## y el numero de cada zona. Todo mirando a -X local (la cara hacia quien patea).
func _dress_round(body: Node3D, r: float, th: float, zones: Array, tough: bool) -> void:
	var back := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = r
	bm.bottom_radius = r
	bm.height = th
	bm.radial_segments = 24
	bm.rings = 1
	back.mesh = bm
	back.material_override = ArcadeLook.mat(Color(0.5, 0.33, 0.18), "wood")
	back.rotation_degrees = Vector3(0, 0, 90)
	body.add_child(back)
	var n: int = zones.size()
	for i in range(n - 1, -1, -1):
		var z: Array = zones[i]
		var ring := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = r * float(z[0]) * 0.985
		rm.bottom_radius = rm.top_radius
		rm.height = 0.006
		rm.radial_segments = 24
		rm.rings = 1
		ring.mesh = rm
		var ci: int = clampi(i * RING_COLORS.size() / maxi(n, 1), 0, RING_COLORS.size() - 1)
		ring.material_override = ArcadeLook.mat(RING_COLORS[ci], "plastic")
		ring.rotation_degrees = Vector3(0, 0, 90)
		ring.position = Vector3(-th * 0.5 - 0.003 - 0.002 * float(n - 1 - i), 0, 0)
		body.add_child(ring)
		var inner: float = float(zones[i - 1][0]) if i > 0 else 0.0
		var lab := Label3D.new()
		lab.text = str(int(z[1]))
		lab.font_size = 64
		lab.pixel_size = r * 0.0028
		lab.modulate = Color(0.08, 0.08, 0.08) if ci == 0 or ci == RING_COLORS.size() - 1 else Color(1, 1, 1)
		lab.outline_size = 0
		lab.rotation_degrees = Vector3(0, -90, 0)
		lab.position = Vector3(-th * 0.5 - 0.02, (r * (inner + float(z[0])) * 0.5) if i > 0 else 0.0, 0)
		body.add_child(lab)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.98
	tm.outer_radius = r + 0.035
	tm.rings = 24
	tm.ring_segments = 6
	rim.mesh = tm
	rim.material_override = ArcadeLook.mat(Color(0.95, 0.75, 0.2) if tough else Color(0.82, 0.83, 0.88), "metal")
	rim.rotation_degrees = Vector3(0, 0, 90)
	body.add_child(rim)

## Tablero rectangular: cada zona pintada (la primera que contiene un punto es la que cuenta, asi que se pintan de la
## ultima a la primera, cada una un poco mas adelante) con su numero; marco de metal.
func _dress_panel(body: Node3D, size: Vector2, th: float, zones: Array) -> void:
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(th, size.y, size.x)
	back.mesh = bm
	back.material_override = ArcadeLook.mat(Color(0.12, 0.16, 0.3), "paint")
	body.add_child(back)
	var palette := {10: Color(1.0, 0.82, 0.12), 7: Color(0.9, 0.16, 0.14), 5: Color(0.9, 0.16, 0.14), 3: Color(0.16, 0.45, 0.9), 2: Color(0.16, 0.45, 0.9), 1: Color(0.95, 0.95, 0.93)}
	var n: int = zones.size()
	for i in range(n - 1, -1, -1):
		var z: Array = zones[i]
		var x0: float = float(z[0]) * size.x * 0.5
		var x1: float = float(z[2]) * size.x * 0.5
		var y0: float = float(z[1]) * size.y * 0.5
		var y1: float = float(z[3]) * size.y * 0.5
		var pts: int = int(z[4])
		var c: Color = palette.get(pts, Color(0.3, 0.75, 0.4))
		var q := MeshInstance3D.new()
		var qm := BoxMesh.new()
		qm.size = Vector3(0.006, (y1 - y0) * 0.97, (x1 - x0) * 0.97)
		q.mesh = qm
		q.material_override = ArcadeLook.mat(c, "plastic")
		q.position = Vector3(-th * 0.5 - 0.003 - 0.002 * float(n - 1 - i), (y0 + y1) * 0.5, (x0 + x1) * 0.5)
		body.add_child(q)
		var lab := Label3D.new()
		lab.text = str(pts)
		lab.font_size = 96
		lab.pixel_size = minf(size.x, size.y) * 0.0024
		lab.modulate = Color(0.08, 0.08, 0.1) if pts == 1 or pts == 10 else Color(1, 1, 1)
		lab.rotation_degrees = Vector3(0, -90, 0)
		lab.position = Vector3(-th * 0.5 - 0.03, (y0 + y1) * 0.5 if i < n - 1 else size.y * 0.3, (x0 + x1) * 0.5)
		body.add_child(lab)
	var frame_m := ArcadeLook.mat(Color(0.82, 0.83, 0.88), "metal")
	for s in [[Vector3(th + 0.02, 0.06, size.x + 0.12), Vector3(0, size.y * 0.5 + 0.03, 0)], [Vector3(th + 0.02, 0.06, size.x + 0.12), Vector3(0, -size.y * 0.5 - 0.03, 0)],
			[Vector3(th + 0.02, size.y, 0.06), Vector3(0, 0, size.x * 0.5 + 0.03)], [Vector3(th + 0.02, size.y, 0.06), Vector3(0, 0, -size.x * 0.5 - 0.03)]]:
		var f := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = s[0]
		f.mesh = fm
		f.material_override = frame_m
		f.position = s[1]
		body.add_child(f)

# --- Impactos ----------------------------------------------------------------------------------------------------------

## Golpe sobre una placa colgada (de la pelota o de otra placa en cadena): si el impacto es fuerte, resta resistencia; sin
## resistencia, se desprende (se quita la articulacion y cae). Los puntos de zona solo los da la pelota.
func _on_plate_hit(body: Node, plate: RigidBody3D) -> void:
	var e: Dictionary = _entry_of(plate)
	if e.is_empty():
		return
	if body == ball:
		_score_impact(e)
	if bool(e["detached"]):
		return
	var other_v := Vector3.ZERO
	if body == ball:
		other_v = _bv
	elif body is RigidBody3D:
		var oe: Dictionary = _entry_of(body as RigidBody3D)
		other_v = (oe.get("pv", (body as RigidBody3D).linear_velocity) as Vector3) if not oe.is_empty() else (body as RigidBody3D).linear_velocity
	else:
		return
	# Velocidades de ANTES del choque (la respuesta ya empujo a la placa cuando llega la señal).
	var rel: float = (other_v - (e.get("pv", Vector3.ZERO) as Vector3)).length()
	if rel < MIN_HIT:
		return
	# La pelota daña una vez por tiro a cada placa: al pegar de frente puede volver a tocarla en el mismo rebote
	# (la placa se hamaca hacia atras y la pelota la alcanza); eso no es un segundo golpe.
	if body == ball:
		if int(e.get("hurt", -1)) == int(shots[0]):
			return
		e["hurt"] = int(shots[0])
	e["hits"] = int(e["hits"]) - 1
	if int(e["hits"]) <= 0:
		e["detached"] = true
		(e["joint"] as PinJoint3D).queue_free()
		e["joint"] = null
		(e["rope"] as MeshInstance3D).visible = false

## La pelota choco con un tablero fijo o movil (la señal la da la pelota: los cuerpos estaticos no la emiten).
func _on_ball_body(body: Node) -> void:
	if state != State.FLIGHT:
		return
	for e in plates:
		if e["body"] == body and String(e["kind"]) != "hang":
			_score_impact(e)

## Punto de impacto en la cara del blanco (coordenadas de la cara: x a la derecha de quien patea, y arriba), cruzando la
## trayectoria del paso anterior con el plano de la cara en el marco que tenia el blanco antes del paso. INF si la pelota
## llego de atras o de canto.
func impact_point(e: Dictionary, from: Vector3, vel: Vector3) -> Vector2:
	var xf: Transform3D = e["px"]
	var inv: Transform3D = xf.affine_inverse()
	var p: Vector3 = inv * from
	var d: Vector3 = inv.basis * vel
	if d.x < 0.5:
		return Vector2.INF
	var face_x: float = -float(e["th"]) * 0.5 - ball.radius
	var t: float = (face_x - p.x) / d.x
	if t < -0.05 or t > 0.1:
		# Contacto de canto: el punto mas cercano de la pelota sobre el plano.
		return Vector2(p.z, p.y)
	var h: Vector3 = p + d * t
	return Vector2(h.z, h.y)

## Puntos de la zona que contiene el punto (0 si cae fuera del blanco).
func zone_points_at(e: Dictionary, pt: Vector2) -> int:
	if pt == Vector2.INF:
		return 0
	var zones: Array = e["zones"]
	if String(e["shape"]) == "round":
		var d: float = pt.length() / float(e["r"])
		for z in zones:
			if d <= float(z[0]):
				return int(z[1])
		# Rozo el aro con el costado de la pelota: la zona de afuera.
		return int(zones.back()[1]) if d <= 1.0 + ball.radius / float(e["r"]) else 0
	var sz: Vector2 = e["size"]
	var nx: float = clampf(pt.x / (sz.x * 0.5), -1.0, 1.0)
	var ny: float = clampf(pt.y / (sz.y * 0.5), -1.0, 1.0)
	for z in zones:
		if nx >= float(z[0]) and nx <= float(z[2]) and ny >= float(z[1]) and ny <= float(z[3]):
			return int(z[4])
	return 0

func _score_impact(e: Dictionary) -> void:
	if state != State.FLIGHT or int(e["scored"]) == int(shots[0]):
		return
	var rel: float = (_bv - (e.get("pv", Vector3.ZERO) as Vector3)).length()
	if rel < MIN_SCORE_HIT:
		return
	var pt: Vector2 = impact_point(e, _bp, _bv)
	var pts: int = zone_points_at(e, pt)
	if pts <= 0:
		return
	e["scored"] = int(shots[0])
	zone_points += pts
	last_hit = {"points": pts, "point": pt, "target": plates.find(e), "speed": rel, "shot": int(shots[0])}
	hits_log.append(last_hit)
	_popup(pts, (e["px"] as Transform3D) * Vector3(-float(e["th"]) * 0.5 - 0.1, pt.y, pt.x))
	_refresh_score()

## Cartel «+N» que sube y se apaga donde pego la pelota.
func _popup(pts: int, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = "+%d" % pts
	l.font_size = 96
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1.0, 0.85, 0.2) if pts >= 10 else Color(1, 1, 1)
	l.outline_size = 12
	l.no_depth_test = true
	add_child(l)
	l.global_position = at
	var tw := create_tween()
	tw.tween_property(l, "global_position", at + Vector3.UP * 0.9, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.tween_callback(l.queue_free)

func _level_step(_delta: float) -> void:
	_bp = ball.global_position
	_bv = ball.linear_velocity
	for e in plates:
		var b: Node3D = e["body"]
		e["px"] = b.global_transform
		if b is RigidBody3D:
			e["pv"] = (b as RigidBody3D).linear_velocity
		else:
			e["pv"] = Vector3.ZERO

func _entry_of(plate: Node) -> Dictionary:
	for e in plates:
		if e["body"] == plate:
			return e
	return {}

## Placas colgadas que hay (los tableros fijos no se derriban).
func hang_count() -> int:
	var n: int = 0
	for e in plates:
		if String(e["kind"]) == "hang":
			n += 1
	return n

func fallen_count() -> int:
	var n: int = 0
	for e in plates:
		if bool(e["detached"]) and (e["body"] as Node3D).global_position.y < 0.6:
			e["fallen"] = true
		if bool(e["fallen"]):
			n += 1
	return n

func hanging() -> int:
	return hang_count() - fallen_count()

func reset_level() -> void:
	for e in plates:
		var body: Node3D = e["body"]
		if String(e["kind"]) == "hang":
			var rb: RigidBody3D = body as RigidBody3D
			if bool(e["detached"]):
				# Vuelve a colgar: placa a su lugar y una articulacion nueva (la vieja se libero).
				e["joint"] = _pin(e["anchor"], rb)
				(e["rope"] as MeshInstance3D).visible = true
			rb.global_transform = e["home"]
			rb.linear_velocity = Vector3.ZERO
			rb.angular_velocity = Vector3.ZERO
		e["detached"] = false
		e["fallen"] = false
		e["hits"] = e["hits0"]
		e["scored"] = -1
		e["hurt"] = -1
	zone_points = 0
	hits_log.clear()
	last_hit = {}
	super.reset_level()

## Encuadre: los blancos y su barra.
func frame_points() -> Array:
	var out: Array = []
	for e in plates:
		var o: Vector3 = (e["home"] as Transform3D).origin
		if String(e["kind"]) == "hang":
			out.append(e["anchor"])
			out.append(o + Vector3.DOWN * float(e["r"]))
		else:
			var hy: float = float(e["r"]) if String(e["shape"]) == "round" else (e["size"] as Vector2).y * 0.5
			out.append(o + Vector3.UP * hy)
			out.append(o + Vector3.DOWN * hy)
	return out

func _ball_spot(_s: int) -> Vector3:
	return (Vector3(0, ball.radius if ball != null else 0.11, 0) + BotonCaida._vec(def.get("tee", [0, 0, 0]))) + Vector3.UP * deck_y()

func _aim_point(_s: int) -> Vector3:
	if not floor_t.is_empty():
		return floor_center()
	var c := Vector3.ZERO
	for e in plates:
		c += (e["home"] as Transform3D).origin
	c /= float(maxi(plates.size(), 1))
	return c

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(_aim_point(0).x, Vector2(9.0, 27.0), false, 5.0, 4.5, ball.radius)

func _settling() -> bool:
	for e in plates:
		if bool(e["detached"]) and not bool(e["fallen"]) and (e["body"] as RigidBody3D).linear_velocity.length() > 0.3:
			return true
	return false

func _flight_check(_delta: float) -> String:
	if not floor_t.is_empty():
		# Diana en el suelo: el tiro se decide en el primer pique.
		if floor_scored_shot == int(shots[0]) and _t > 0.3:
			return "listo"
		if _t > 0.8 and ball.linear_velocity.length() < SLOW_SPEED:
			return "listo"
		return ""
	if goal == "derribar" and _t > 0.6 and hang_count() > 0 and hanging() == 0:
		return "todas"
	if _t > 0.8 and not _settling() and (ball.linear_velocity.length() < SLOW_SPEED or ball.global_position.x > _aim_point(0).x + 10.0):
		return "listo"
	return ""

func _on_resolved(s: int, _r: String) -> void:
	points[0] = final_score()
	var good: bool = (goal == "derribar" and hanging() == 0) or (goal == "puntos" and int(last_hit.get("points", 0)) >= 5 and int(last_hit.get("shot", -2)) == int(shots[0]))
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if good else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)

func _check_winner() -> int:
	if (goal == "derribar" and hanging() == 0) or int(shots[0]) >= shots_max:
		return Side.USER
	return -1

func final_score() -> int:
	var n: int = fallen_count()
	var s: int = zone_points + n * PLATE_POINTS
	if goal == "derribar" and hang_count() > 0 and hanging() == 0:
		s += maxi(shots_max - int(shots[0]), 0) * SPARE_SHOT
	return s

func _result_text(r: String) -> Array:
	var hit: String = ("+%d en el impacto" % int(last_hit["points"])) if not last_hit.is_empty() and int(last_hit.get("shot", -2)) == int(shots[0]) else "sin puntos de zona"
	if r == "todas":
		return ["¡TODAS ABAJO!", Color(0.35, 1.0, 0.45), "En %d tiros · %s" % [int(shots[0]), hit]]
	if goal == "puntos":
		return ["%d puntos" % zone_points, Color(1.0, 0.85, 0.35), "%s · tiros %d de %d" % [hit, int(shots[0]), shots_max]]
	return ["%d de %d dianas" % [fallen_count(), hang_count()], Color(1.0, 0.85, 0.35), "%s · tiros %d de %d" % [hit, int(shots[0]), shots_max]]

func _refresh_score() -> void:
	if goal == "puntos":
		hud.set_score_text("Puntos %d · tiros %d / %d" % [zone_points, int(shots[0]), shots_max])
	else:
		hud.set_score_text("Dianas %d / %d · puntos %d · tiros %d / %d" % [fallen_count(), hang_count(), zone_points, int(shots[0]), shots_max])
