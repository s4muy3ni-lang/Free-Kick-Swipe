class_name ChallengeTargets
extends Node3D
## Blancos, objetos y obstaculos de un ejercicio o desafio (ChallengeCatalog), en el estadio real. Todo se detecta con la
## pelota REAL (la misma fisica de siempre), nunca moviendola:
##  - zone: recuadro en la boca del arco; acierto si la pelota cruza ENTERA la linea dentro del recuadro (punto de cruce
##    interpolado entre dos pasos); precision = cercania al centro. Opcional: move (se desplaza), blink (aparece y
##    desaparece: solo vale visible), bounce (solo vale si la pelota pico antes).
##  - hoop: aro en cualquier lugar; acierto si el recorrido de la pelota atraviesa su plano dentro del radio.
##  - post_left / post_right / crossbar: la señal del marco de Ball (hit_goal_frame) con el punto del golpe.
##  - goal: gol (cruzo entera entre los palos); precision = cuanto se acerco a los angulos.
##  - objetos (conos, botellas, bloques, torre): cuerpos rigidos que la pelota voltea; cuenta los caidos (inclinados mas de
##    45 grados o corridos mas de 0,4 m).
##  - obstaculos (poste, maniquies): cuerpos estaticos que la pelota choca (obligan a curvar o a levantarla).

signal target_hit(index: int, precision: float)

const ZONE_COLOR := Color(1.0, 0.86, 0.25)
const HIT_COLOR := Color(0.35, 1.0, 0.45)
const OFF_COLOR := Color(0.6, 0.6, 0.65)

var def: Dictionary = {}
var ball: Ball
var gx: float = 52.5
var half_goal: float = 3.66
var goal_h: float = 2.44
var targets: Array = []          # {type, data, node, mat, base: Vector3, visible: bool}
var objects: Array = []          # {body, start, kind}
var _attempt_hits: Dictionary = {}   # indice -> precision
var _bounced: bool = false
var _prev := Vector3.INF
var _t: float = 0.0
## Objetivo activo de una secuencia (-1: todos activos).
var active_index: int = -1

func build(d: Dictionary, b: Ball, goal_x: float, goal_half: float, goal_height: float) -> void:
	def = d
	ball = b
	gx = goal_x
	half_goal = goal_half
	goal_h = goal_height
	for i in d["targets"].size():
		var t: Dictionary = d["targets"][i]
		targets.append(_make_target(t))
	for o in d["objects"]:
		_make_objects(o)
	for o in d["obstacles"]:
		_make_obstacle(o)
	ball.hit_goal_frame.connect(_on_frame_hit)
	ball.floor_bounce.connect(func(_p: Vector3, _s: float) -> void: _bounced = true)
	if String(d["rule"]) == "sequence":
		set_active(0)

## Empieza un intento: vacia los aciertos del intento (los objetos caidos siguen caidos).
func begin_attempt() -> void:
	_attempt_hits.clear()
	_bounced = false
	_prev = Vector3.INF
	for i in targets.size():
		_paint(i, false)

func attempt_hits() -> Dictionary:
	return _attempt_hits

func set_active(i: int) -> void:
	active_index = i
	for k in targets.size():
		_paint(k, false)

## Objetos voltados hasta ahora.
func knocked_count() -> int:
	var n: int = 0
	for o in objects:
		if is_knocked(o):
			n += 1
	return n

static func is_knocked(o: Dictionary) -> bool:
	var body: RigidBody3D = o["body"]
	var up: Vector3 = body.global_transform.basis.y.normalized()
	return up.dot(Vector3.UP) < cos(deg_to_rad(45.0)) or body.global_position.distance_to(o["start"]) > 0.4

# --- Construccion ---------------------------------------------------------------------------------------------------------

func _mat(c: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _make_target(t: Dictionary) -> Dictionary:
	var e := {"type": String(t["type"]), "data": t, "node": null, "mat": null, "fill": null, "visible": true, "base": Vector3.ZERO}
	match e["type"]:
		"zone":
			var root := Node3D.new()
			add_child(root)
			var w: float = float(t["w"])
			var h: float = float(t["h"])
			var mat: StandardMaterial3D = _mat(ZONE_COLOR)
			var th: float = 0.05
			for seg in [[Vector3(0, h * 0.5, 0), Vector3(th, th, w + th)], [Vector3(0, -h * 0.5, 0), Vector3(th, th, w + th)],
					[Vector3(0, 0, w * 0.5), Vector3(th, h, th)], [Vector3(0, 0, -w * 0.5), Vector3(th, h, th)]]:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = seg[1]
				mi.mesh = bm
				mi.material_override = mat
				mi.position = seg[0]
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mi)
			var fill := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(w, h)
			fill.mesh = qm
			fill.rotation.y = PI * 0.5
			var fm: StandardMaterial3D = _mat(ZONE_COLOR, 0.16)
			fill.material_override = fm
			fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(fill)
			e["base"] = Vector3(gx - 0.03, float(t["y"]), float(t["z"]))
			root.global_position = e["base"]
			e["node"] = root
			e["mat"] = mat
			e["fill"] = fm
		"hoop":
			var at: Array = t["at"]
			var mi := MeshInstance3D.new()
			var tm := TorusMesh.new()
			var r: float = float(t["r"])
			tm.inner_radius = r
			tm.outer_radius = r + 0.08
			mi.mesh = tm
			mi.rotation.z = PI * 0.5
			var mat: StandardMaterial3D = _mat(ZONE_COLOR)
			mi.material_override = mat
			add_child(mi)
			e["base"] = Vector3(gx - float(at[0]), float(at[1]), float(at[2]))
			mi.global_position = e["base"]
			e["node"] = mi
			e["mat"] = mat
		"post_left", "post_right", "crossbar":
			var mi := MeshInstance3D.new()
			var mat: StandardMaterial3D = _mat(ZONE_COLOR, 0.55)
			if e["type"] == "crossbar":
				var bm := BoxMesh.new()
				bm.size = Vector3(0.16, 0.16, half_goal * 2.0)
				mi.mesh = bm
				mi.position = Vector3(gx + 0.02, goal_h + 0.06, 0.0)
			else:
				var cm := CylinderMesh.new()
				cm.top_radius = 0.085
				cm.bottom_radius = 0.085
				cm.height = goal_h
				mi.mesh = cm
				var z: float = -half_goal - 0.06 if e["type"] == "post_left" else half_goal + 0.06
				mi.position = Vector3(gx + 0.02, goal_h * 0.5, z)
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			e["node"] = mi
			e["mat"] = mat
	return e

func _make_objects(o: Dictionary) -> void:
	var at: Array = o["at"]
	var base := Vector3(gx - float(at[0]), 0.0, float(at[1]))
	var n: int = int(o.get("n", 1))
	var kind: String = String(o["type"])
	var sp: float = float(o.get("spacing", 0.7))
	match kind:
		"tower":
			# Pila de bloques: filas de 3, 2 y 1... (de a 3 por piso mientras alcance).
			var placed: int = 0
			var floor_i: int = 0
			while placed < n:
				var row: int = mini(3, n - placed)
				for k in row:
					var off: float = (float(k) - float(row - 1) * 0.5) * 0.52
					_object_body("block", base + Vector3(0.0, 0.15 + float(floor_i) * 0.3, off))
					placed += 1
				floor_i += 1
		_:
			for k in n:
				var off: float = (float(k) - float(n - 1) * 0.5) * sp
				var single: String = {"cones": "cone", "bottles": "bottle", "blocks": "block"}[kind]
				var y: float = {"cone": 0.225, "bottle": 0.16, "block": 0.15}[single]
				_object_body(single, base + Vector3(0.0, y, off))

func _object_body(kind: String, pos: Vector3) -> void:
	var body := RigidBody3D.new()
	body.collision_layer = Ball.LAYER_PLAYERS
	body.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_PLAYERS | Ball.LAYER_BALL
	var cs := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	var color := Color(1.0, 0.45, 0.1)
	match kind:
		"cone":
			body.mass = 0.35
			var sh := CylinderShape3D.new()
			sh.radius = 0.12
			sh.height = 0.45
			cs.shape = sh
			var m := CylinderMesh.new()
			m.top_radius = 0.025
			m.bottom_radius = 0.13
			m.height = 0.45
			mi.mesh = m
		"bottle":
			body.mass = 0.5
			color = Color(0.3, 0.75, 1.0)
			var sh2 := CylinderShape3D.new()
			sh2.radius = 0.06
			sh2.height = 0.32
			cs.shape = sh2
			var m2 := CylinderMesh.new()
			m2.top_radius = 0.035
			m2.bottom_radius = 0.06
			m2.height = 0.32
			mi.mesh = m2
		_:
			body.mass = 0.8
			color = Color(0.95, 0.95, 0.2)
			var sh3 := BoxShape3D.new()
			sh3.size = Vector3(0.3, 0.3, 0.5)
			cs.shape = sh3
			var m3 := BoxMesh.new()
			m3.size = Vector3(0.3, 0.3, 0.5)
			mi.mesh = m3
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.1
	body.physics_material_override = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	body.add_child(cs)
	body.add_child(mi)
	add_child(body)
	body.global_position = pos
	objects.append({"body": body, "start": pos, "kind": kind})

func _make_obstacle(o: Dictionary) -> void:
	var at: Array = o["at"]
	var base := Vector3(gx - float(at[0]), 0.0, float(at[1]))
	var h: float = float(o.get("h", 2.0))
	var kind: String = String(o["type"])
	var n: int = 1 if kind == "pole" else int(o.get("n", 4))
	for k in n:
		var body := StaticBody3D.new()
		body.collision_layer = Ball.LAYER_PLAYERS
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var mi := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		if kind == "pole":
			var sh := CylinderShape3D.new()
			sh.radius = 0.11
			sh.height = h
			cs.shape = sh
			var m := CylinderMesh.new()
			m.top_radius = 0.11
			m.bottom_radius = 0.11
			m.height = h
			mi.mesh = m
			mat.albedo_color = Color(0.95, 0.4, 0.1)
		else:
			# Maniqui de entrenamiento (silueta plana con base), como una barrera fija.
			var sh2 := BoxShape3D.new()
			sh2.size = Vector3(0.18, h, 0.48)
			cs.shape = sh2
			var m2 := BoxMesh.new()
			m2.size = Vector3(0.12, h, 0.46)
			mi.mesh = m2
			mat.albedo_color = Color(0.15, 0.25, 0.9)
		mi.material_override = mat
		body.add_child(cs)
		body.add_child(mi)
		add_child(body)
		var off: float = (float(k) - float(n - 1) * 0.5) * 0.52
		body.global_position = base + Vector3(0.0, h * 0.5, off)

# --- Deteccion ------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	for i in targets.size():
		_animate(i)
	flush()

## Revisa ya el ultimo tramo de la pelota (el juego lo llama antes de evaluar un intento: el arco puede detectar el gol en
## el mismo paso, antes de que este nodo procese ese tramo).
func flush() -> void:
	if ball == null:
		return
	var p: Vector3 = ball.global_position
	if _prev != Vector3.INF and _prev.distance_to(p) < 3.0:
		for i in targets.size():
			if _attempt_hits.has(i) or not _counts(i):
				continue
			var e: Dictionary = targets[i]
			match String(e["type"]):
				"zone":
					_check_zone(i, _prev, p)
				"hoop":
					_check_hoop(i, _prev, p)
	_prev = p

func _counts(i: int) -> bool:
	return active_index < 0 or active_index == i

func _animate(i: int) -> void:
	var e: Dictionary = targets[i]
	var t: Dictionary = e["data"]
	if e["node"] == null:
		return
	if t.has("move"):
		var mv: Dictionary = t["move"]
		var off: float = float(mv["amp"]) * sin(TAU * _t / maxf(float(mv["period"]), 0.5))
		var pos: Vector3 = e["base"]
		if String(mv.get("axis", "z")) == "z":
			var lim: float = half_goal - float(t.get("w", 1.0)) * 0.5
			pos.z = clampf(pos.z + off, -lim, lim)
		else:
			var lo: float = float(t.get("h", 1.0)) * 0.5
			pos.y = clampf(pos.y + off, lo, goal_h - lo)
		(e["node"] as Node3D).global_position = pos
	if t.has("blink"):
		var bl: Dictionary = t["blink"]
		var cyc: float = float(bl["on"]) + float(bl["off"])
		e["visible"] = fmod(_t, cyc) < float(bl["on"])
		(e["node"] as Node3D).visible = e["visible"]

func _check_zone(i: int, a: Vector3, b: Vector3) -> void:
	var e: Dictionary = targets[i]
	var t: Dictionary = e["data"]
	if not bool(e["visible"]):
		return
	if bool(t.get("bounce", false)) and not _bounced:
		return
	# Cruza ENTERA la linea: el centro pasa un radio detras.
	var plane: float = gx + ball.radius
	if not (a.x < plane and b.x >= plane):
		return
	var u: float = (plane - a.x) / maxf(b.x - a.x, 1e-5)
	var c: Vector3 = a.lerp(b, clampf(u, 0.0, 1.0))
	var center: Vector3 = (e["node"] as Node3D).global_position
	var dz: float = absf(c.z - center.z) / (float(t["w"]) * 0.5)
	var dy: float = absf(c.y - center.y) / (float(t["h"]) * 0.5)
	if dz <= 1.0 and dy <= 1.0:
		_hit(i, 1.0 - maxf(dz, dy))

func _check_hoop(i: int, a: Vector3, b: Vector3) -> void:
	var e: Dictionary = targets[i]
	var center: Vector3 = (e["node"] as Node3D).global_position
	var n := Vector3(1, 0, 0)
	var da: float = (a - center).dot(n)
	var db: float = (b - center).dot(n)
	if da > 0.0 or db < 0.0:
		return
	var u: float = -da / maxf(db - da, 1e-5)
	var c: Vector3 = a.lerp(b, clampf(u, 0.0, 1.0))
	var r: float = float(e["data"]["r"])
	var d: float = c.distance_to(center)
	if d <= r - ball.radius * 0.5:
		_hit(i, 1.0 - d / r)

func _on_frame_hit(pos: Vector3, _speed: float) -> void:
	for i in targets.size():
		if _attempt_hits.has(i) or not _counts(i):
			continue
		var tp: String = String(targets[i]["type"])
		var on_bar: bool = pos.y > goal_h - 0.15 and absf(pos.z) < half_goal - 0.05
		var near_left: bool = pos.z < -half_goal + 0.3
		var near_right: bool = pos.z > half_goal - 0.3
		if (tp == "crossbar" and on_bar) or (tp == "post_left" and near_left and not on_bar) or (tp == "post_right" and near_right and not on_bar):
			_hit(i, 1.0)

## Gol (lo llama el juego con el punto donde entro la pelota).
func on_goal(pos: Vector3) -> void:
	for i in targets.size():
		if String(targets[i]["type"]) == "goal" and not _attempt_hits.has(i) and _counts(i):
			var corner: float = maxf(absf(pos.z) / half_goal, clampf(pos.y / goal_h, 0.0, 1.0))
			_hit(i, clampf(corner, 0.0, 1.0))

func _hit(i: int, precision: float) -> void:
	_attempt_hits[i] = precision
	_paint(i, true)
	target_hit.emit(i, precision)

func _paint(i: int, hit: bool) -> void:
	var e: Dictionary = targets[i]
	if e["mat"] == null:
		return
	var c: Color = HIT_COLOR if hit else (ZONE_COLOR if _counts(i) else OFF_COLOR)
	var m: StandardMaterial3D = e["mat"]
	m.albedo_color = Color(c.r, c.g, c.b, m.albedo_color.a)
	m.emission = c
	if e["fill"] != null:
		var f: StandardMaterial3D = e["fill"]
		f.albedo_color = Color(c.r, c.g, c.b, f.albedo_color.a)
		f.emission = c
