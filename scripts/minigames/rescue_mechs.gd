class_name RescueMechs
extends Node3D
## Mecanismos del Rescate (pedido del usuario, 2026-11-14: «todo debe ser activado con el balón… palancas, botones,
## meter el balón en un hoyo, impactar… acertijos y mecanismos buenos»). Dos clases de cosas, armadas desde el nivel
## (minigames.json), en las coordenadas del ESCENARIO (Rescate.stage): el escenario gira y todo gira con el.
##
## PIEZAS («parts»): cuerpos que se mueven y que la pelota dorada toca de verdad (AnimatableBody3D sincronizado con la
## fisica: al moverse empujan, levantan o sueltan; nada se teletransporta). Cada una tiene un valor 0..1 que va hacia su
## objetivo con su velocidad:
##  - "slide" (compuerta, plataforma): se traslada de pos a pos + open;
##  - "hinge" (puente levadizo, rampa, piso que se inclina): gira alrededor de una bisagra (hinge, axis) hasta angle;
##  - "rotor" (jaula con engranaje): barras en circulo con un hueco que gira de a pasos (steps por vuelta);
##  - con "osc" (periodo, s) va y viene sola mientras sus mandos esten activos (o siempre si no tiene mandos).
##
## MANDOS («mechs»): se activan SOLO con la pelota del jugador (no hay toques en la pantalla). Cada uno tiene un blanco
## fisico, mira hacia -X de su «yaw» (hacia el jugador con el escenario sin girar) y targets (indices de piezas):
##  - "lever": palanca con una paleta grande; cada pelotazo la cambia (activa / no);
##  - "button": blanco rojo; un pelotazo lo deja apretado ("latch") o lo activa time segundos ("timer");
##  - "switch": blanco de color de una secuencia (group, order); el "lock" del grupo (panel de luces, no se golpea) se
##    abre cuando se les pego en el orden de sus luces; uno fuera de orden apaga todo (error);
##  - "wheel": rueda dentada con un blanco al centro; cada pelotazo la gira un paso y con ella las jaulas «rotor»;
##  - "weight": contrapeso colgado; un pelotazo lo suelta, cae (cuerpo fisico) y lo que cae mueve las piezas;
##  - "hole": buzon: una caja con una boca; hay que meter la pelota adentro;
##  - "plate": placa en el piso, activa mientras haya una caja (Rescate.crates) encima.
## Los blancos piden un impacto real (PRESS_SPEED). Cuenta acciones y errores para el puntaje y el online.

const PRESS_SPEED := 2.5
const HANDLE := Color(1.0, 0.78, 0.15)
const METAL := Color(0.6, 0.64, 0.72)
const OFF := Color(0.95, 0.15, 0.12)
const ON := Color(0.2, 0.95, 0.35)
const BOARD := Color(0.22, 0.24, 0.3)
## Tiempo minimo entre dos activaciones del mismo mando (un pelotazo que rebota no cuenta dos veces).
const DEBOUNCE := 0.45

signal acted(kind: String)

var parts: Array = []
var mechs: Array = []
var groups: Dictionary = {}
var actions: int = 0
var errors: int = 0
var time: float = 0.0
var fast: bool = false

static func v3(a: Variant, d := Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return d

static func mat(c: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.45
	m.metallic = 0.35
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m

func _box(size: Vector3, c: Color, glow: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c, glow)
	return mi

## Arma piezas y mandos del nivel.
func build(part_defs: Array, mech_defs: Array) -> void:
	for p in part_defs:
		parts.append(_make_part(p as Dictionary))
	for i in mech_defs.size():
		mechs.append(_make_mech(mech_defs[i] as Dictionary, i))
	for m in mechs:
		if String(m["type"]) == "lock":
			groups[String(m["group"])] = {"progress": 0, "n": int(m["n"]), "lock": m}
	_apply(true)

# --- Piezas ----------------------------------------------------------------------------------------------------------

func _make_part(d: Dictionary) -> Dictionary:
	var type: String = String(d.get("type", "slide"))
	var body := AnimatableBody3D.new()
	body.sync_to_physics = true
	body.collision_layer = Ball.LAYER_WORLD
	body.collision_mask = 0
	var pmat := PhysicsMaterial.new()
	pmat.friction = float(d.get("friction", 0.5))
	pmat.bounce = float(d.get("bounce", 0.15))
	body.physics_material_override = pmat
	add_child(body)
	var col: Color = Color.from_string(String(d.get("color", "")), METAL) if d.has("color") else METAL
	var pos: Vector3 = v3(d.get("pos"))
	var rot: Vector3 = v3(d.get("rot"))
	var base := Transform3D(Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))), pos)
	if type == "rotor":
		_rotor_shape(body, d, col)
	else:
		var size: Vector3 = v3(d.get("size"), Vector3(1, 1, 1))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		body.add_child(_box(size, col))
		# Franjas amarillas y negras en lo que se mueve: se entiende que es parte de un mecanismo.
		var stripe := _box(Vector3(size.x * 1.002, minf(0.06, size.y * 0.2), size.z * 1.002), Color(0.95, 0.8, 0.1), 0.2)
		stripe.position.y = size.y * 0.5 - 0.04
		body.add_child(stripe)
	body.transform = base
	return {"type": type, "body": body, "base": base, "def": d, "value": float(d.get("start", 0.0)), "target": float(d.get("start", 0.0)),
		"speed": float(d.get("speed", 1.6)), "osc": float(d.get("osc", 0.0)), "phase": 0.0, "drivers": [], "moving": false}

## Jaula giratoria: barras alrededor del eje con un hueco (gap barras faltantes). El engranaje que se ve al costado gira
## con ella.
func _rotor_shape(body: AnimatableBody3D, d: Dictionary, col: Color) -> void:
	var n: int = int(d.get("bars", 12))
	var gap: int = int(d.get("gap", 2))
	var r: float = float(d.get("radius", 0.42))
	var depth: float = float(d.get("depth", 0.6))
	for i in n:
		if i < gap:
			continue
		var a: float = TAU * float(i) / float(n)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.07, 0.07, depth)
		cs.shape = bs
		cs.position = Vector3(cos(a) * r, sin(a) * r, 0.0)
		body.add_child(cs)
		var mi := _box(bs.size, col)
		mi.position = cs.position
		body.add_child(mi)
	# Tapas del engranaje (solo se ven) con dientes.
	for side in [-1.0, 1.0]:
		var gear := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r + 0.08
		cm.bottom_radius = r + 0.08
		cm.height = 0.03
		gear.mesh = cm
		gear.material_override = mat(Color(0.75, 0.55, 0.2))
		gear.rotation.x = PI * 0.5
		gear.position.z = side * (depth * 0.5 + 0.03)
		body.add_child(gear)
		for k in 16:
			var a2: float = TAU * float(k) / 16.0
			var tooth := _box(Vector3(0.07, 0.07, 0.03), Color(0.75, 0.55, 0.2))
			tooth.position = Vector3(cos(a2) * (r + 0.12), sin(a2) * (r + 0.12), side * (depth * 0.5 + 0.03))
			tooth.rotation.z = a2
			body.add_child(tooth)

## Transformacion de la pieza para su valor.
func part_transform(p: Dictionary) -> Transform3D:
	var d: Dictionary = p["def"]
	var v: float = float(p["value"])
	var base: Transform3D = p["base"]
	match String(p["type"]):
		"hinge":
			var hinge: Vector3 = v3(d.get("hinge"), base.origin)
			var axis: Vector3 = v3(d.get("axis"), Vector3(0, 0, 1)).normalized()
			var ang: float = deg_to_rad(float(d.get("angle", 90.0))) * v
			var r := Transform3D(Basis(axis, ang), Vector3.ZERO)
			return Transform3D(Basis(), hinge) * r * Transform3D(Basis(), -hinge) * base
		"rotor":
			var axis2: Vector3 = v3(d.get("axis"), Vector3(0, 0, 1)).normalized()
			var steps: int = maxi(int(d.get("steps", 4)), 1)
			var ang2: float = deg_to_rad(float(d.get("phase", 0.0))) + TAU * v / float(steps) * float(d.get("dir", 1.0))
			return Transform3D(base.basis * Basis(axis2, ang2), base.origin)
		_:
			return Transform3D(base.basis, base.origin + v3(d.get("open"), Vector3(0, 1.3, 0)) * v)

# --- Mandos ----------------------------------------------------------------------------------------------------------

## Blanco fisico (en la capa del mundo: la pelota del jugador lo choca) de tamaño size en la posicion local at.
func _target_body(root: Node3D, size: Vector3, at: Vector3, i: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Ball.LAYER_WORLD
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	body.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = at
	body.set_meta("mech", i)
	root.add_child(body)
	return body

## Disco (blanco) que mira hacia -X.
func _disc(r: float, c: Color, glow: float) -> MeshInstance3D:
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 1.05
	cm.height = 0.08
	cap.mesh = cm
	cap.material_override = mat(c, glow)
	cap.rotation.z = PI * 0.5
	return cap

func _make_mech(d: Dictionary, i: int) -> Dictionary:
	var type: String = String(d.get("type", "lever"))
	var pos: Vector3 = v3(d.get("pos"))
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.rotation.y = deg_to_rad(float(d.get("yaw", 0.0)))
	var m := {"type": type, "def": d, "root": root, "i": i, "state": false, "t_left": 0.0, "step": 0, "cool": 0.0,
		"targets": d.get("targets", []), "group": String(d.get("group", "")), "order": int(d.get("order", 0)), "n": int(d.get("n", 0)),
		"parts_vis": {}}
	match type:
		"lever":
			# Poste, brazo y una paleta amarilla grande: el pelotazo la empuja y la palanca cambia de lado.
			root.add_child(_box(Vector3(0.4, 0.3, 0.4), BOARD))
			var arm := Node3D.new()
			arm.position.y = 0.15
			root.add_child(arm)
			var stick := _box(Vector3(0.08, 1.0, 0.08), METAL)
			stick.position.y = 0.5
			arm.add_child(stick)
			var paddle := _box(Vector3(0.1, 0.7, 0.8), HANDLE, 0.5)
			paddle.position.y = 1.05
			arm.add_child(paddle)
			arm.rotation.z = deg_to_rad(-20.0)
			m["parts_vis"] = {"arm": arm, "glow": paddle}
			m["body"] = _target_body(root, Vector3(0.3, 0.8, 0.9), Vector3(0, 1.2, 0), i)
		"button", "switch":
			var board := _box(Vector3(0.14, 0.9, 0.9), BOARD)
			root.add_child(board)
			var c: Color = Color.from_string(String(d.get("color", "")), OFF) if d.has("color") else (Color(1.0, 0.55, 0.1) if String(d.get("mode", "")) == "timer" else OFF)
			var cap := _disc(0.34, c, 0.6)
			cap.position.x = -0.09
			root.add_child(cap)
			# Aro blanco alrededor: se lee como blanco de tiro.
			var ring := _disc(0.42, Color(0.95, 0.95, 0.97), 0.2)
			ring.position.x = -0.075
			root.add_child(ring)
			m["color"] = c
			m["parts_vis"] = {"cap": cap, "glow": cap}
			m["body"] = _target_body(root, Vector3(0.3, 0.9, 0.9), Vector3(-0.05, 0, 0), i)
			if bool(d.get("bodies", false)):
				# Tambien lo aprieta un domino o una caja que le cae encima (no solo la pelota).
				var ab := Area3D.new()
				ab.collision_layer = 0
				ab.collision_mask = Ball.LAYER_WORLD
				ab.monitoring = true
				var cab := CollisionShape3D.new()
				var bab := BoxShape3D.new()
				bab.size = Vector3(0.35, 0.95, 0.95)
				cab.shape = bab
				ab.add_child(cab)
				ab.position.x = -0.3
				root.add_child(ab)
				m["bodies_area"] = ab
			if String(d.get("mode", "")) == "timer":
				var lab := Label3D.new()
				lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lab.font_size = 46
				lab.outline_size = 10
				lab.modulate = Color(1.0, 0.75, 0.35)
				lab.position = Vector3(0.0, 0.7, 0.0)
				lab.text = "%d s" % int(float(d.get("time", 3.0)))
				root.add_child(lab)
				m["timer_label"] = lab
		"lock":
			root.add_child(_box(Vector3(0.24, 0.6, 1.3), Color(0.2, 0.22, 0.27)))
			var lamps: Array = []
			var cols: Array = d.get("colors", [])
			var nl: int = int(d.get("n", 3))
			for k in nl:
				var lamp := MeshInstance3D.new()
				var sm2 := SphereMesh.new()
				sm2.radius = 0.13
				sm2.height = 0.26
				lamp.mesh = sm2
				var lc: Color = Color.from_string(String(cols[k]) if k < cols.size() else "#ffffff", Color.WHITE)
				lamp.material_override = mat(lc * 0.45, 0.15)
				# De izquierda a derecha mirando el panel (de -Z a +Z del panel, que mira a -X).
				lamp.position = Vector3(-0.14, 0.0, -0.4 + 0.8 * float(k) / float(maxi(nl - 1, 1)))
				root.add_child(lamp)
				lamps.append([lamp, lc])
				var num := Label3D.new()
				num.text = str(k + 1)
				num.font_size = 40
				num.outline_size = 8
				num.position = lamp.position + Vector3(-0.05, 0.3, 0)
				num.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				root.add_child(num)
			m["parts_vis"] = {"lamps": lamps}
		"wheel":
			root.add_child(_box(Vector3(0.3, 0.3, 0.3), BOARD))
			var wheel := Node3D.new()
			wheel.position = Vector3(-0.1, 0.0, 0.0)
			root.add_child(wheel)
			var disc := _disc(0.48, Color(0.75, 0.55, 0.2), 0.0)
			wheel.add_child(disc)
			for k in 8:
				var a: float = TAU * float(k) / 8.0
				var tooth := _box(Vector3(0.1, 0.12, 0.12), Color(0.75, 0.55, 0.2))
				tooth.position = Vector3(0.0, cos(a) * 0.54, sin(a) * 0.54)
				tooth.rotation.x = -a
				wheel.add_child(tooth)
			var bull := _disc(0.2, HANDLE, 0.7)
			bull.position.x = -0.06
			wheel.add_child(bull)
			var arrow := _box(Vector3(0.04, 0.36, 0.07), Color(0.1, 0.1, 0.12))
			arrow.position = Vector3(-0.07, 0.25, 0)
			wheel.add_child(arrow)
			m["parts_vis"] = {"wheel": wheel, "glow": bull}
			m["body"] = _target_body(root, Vector3(0.3, 1.0, 1.0), Vector3(-0.08, 0, 0), i)
		"weight":
			var fall: float = float(d.get("fall", 1.5))
			var pulley := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.22
			pm.bottom_radius = 0.22
			pm.height = 0.1
			pulley.mesh = pm
			pulley.material_override = mat(METAL)
			pulley.rotation.x = PI * 0.5
			root.add_child(pulley)
			var w := RigidBody3D.new()
			w.mass = float(d.get("mass", 8.0))
			w.collision_layer = Ball.LAYER_WORLD
			w.collision_mask = Ball.LAYER_WORLD
			w.freeze = true
			w.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			var cs2 := CollisionShape3D.new()
			var bs2 := BoxShape3D.new()
			bs2.size = Vector3(0.6, 0.6, 0.6)
			cs2.shape = bs2
			w.add_child(cs2)
			w.add_child(_box(bs2.size, Color(0.35, 0.36, 0.42)))
			var tag := _disc(0.22, HANDLE, 0.6)
			tag.position.x = -0.31
			w.add_child(tag)
			add_child(w)
			var hang: Vector3 = pos + Vector3(0, -float(d.get("rope", 0.9)), 0)
			w.position = hang
			w.set_meta("mech", i)
			var rope := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.02
			rm.bottom_radius = 0.02
			rm.height = 1.0
			rope.mesh = rm
			rope.material_override = mat(Color(0.85, 0.75, 0.55))
			add_child(rope)
			m["weight"] = w
			m["body"] = w
			m["hang"] = hang
			m["fall"] = fall
			m["rope"] = rope
			m["parts_vis"] = {"glow": tag}
		"hole":
			# Buzon: caja hueca (fondo, techo, piso y costados) con la boca hacia -X; un area adentro ve la pelota.
			var inner := Vector3(0.8, float(d.get("mouth", 0.62)), float(d.get("mouth", 0.62)) + 0.1)
			var th: float = 0.08
			var c2 := Color(0.15, 0.45, 0.85)
			for wall in [[Vector3(th, inner.y + 2 * th, inner.z + 2 * th), Vector3(inner.x * 0.5 + th * 0.5, 0, 0)],
					[Vector3(inner.x, th, inner.z + 2 * th), Vector3(0, inner.y * 0.5 + th * 0.5, 0)],
					[Vector3(inner.x, th, inner.z + 2 * th), Vector3(0, -inner.y * 0.5 - th * 0.5, 0)],
					[Vector3(inner.x, inner.y, th), Vector3(0, 0, inner.z * 0.5 + th * 0.5)],
					[Vector3(inner.x, inner.y, th), Vector3(0, 0, -inner.z * 0.5 - th * 0.5)]]:
				var sb := StaticBody3D.new()
				sb.collision_layer = Ball.LAYER_WORLD
				var cs3 := CollisionShape3D.new()
				var bs3 := BoxShape3D.new()
				bs3.size = wall[0]
				cs3.shape = bs3
				sb.add_child(cs3)
				sb.add_child(_box(wall[0], c2))
				sb.position = wall[1]
				root.add_child(sb)
			# Marco amarillo en la boca.
			var frame := _box(Vector3(0.04, inner.y + 0.22, inner.z + 0.22), HANDLE, 0.5)
			frame.position.x = -inner.x * 0.5 - 0.03
			root.add_child(frame)
			var hole_dark := _box(Vector3(0.02, inner.y, inner.z), Color(0.02, 0.02, 0.04))
			hole_dark.position.x = -inner.x * 0.5 - 0.04
			root.add_child(hole_dark)
			var area := Area3D.new()
			area.collision_layer = 0
			area.collision_mask = Ball.LAYER_BALL
			area.monitoring = true
			var ca := CollisionShape3D.new()
			var ba := BoxShape3D.new()
			ba.size = inner * Vector3(0.5, 0.9, 0.9)
			ca.shape = ba
			area.add_child(ca)
			area.position = Vector3(inner.x * 0.15, 0, 0)
			root.add_child(area)
			area.body_entered.connect(func(b: Node3D) -> void:
				if b is Ball and not bool(m["state"]):
					activate(i))
			m["area"] = area
			m["parts_vis"] = {"glow": frame}
		"plate":
			var size: Vector3 = v3(d.get("size"), Vector3(1.3, 0.06, 1.3))
			var pad := _box(size, Color(0.25, 0.6, 0.95), 0.25)
			pad.position.y = size.y * 0.5
			root.add_child(pad)
			var area2 := Area3D.new()
			area2.collision_layer = 0
			area2.collision_mask = Ball.LAYER_WORLD
			area2.monitoring = true
			var ca2 := CollisionShape3D.new()
			var ba2 := BoxShape3D.new()
			ba2.size = Vector3(size.x, 0.5, size.z)
			ca2.shape = ba2
			area2.add_child(ca2)
			area2.position.y = 0.3
			root.add_child(area2)
			m["area"] = area2
			m["parts_vis"] = {"pad": pad, "glow": pad}
	if d.has("label"):
		var l := Label3D.new()
		l.text = String(d["label"])
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 52
		l.outline_size = 10
		l.position.y = {"lever": 1.85, "weight": 0.35, "plate": 0.7}.get(type, 0.85)
		root.add_child(l)
	return m

## Esta activo el mando m.
func active(m: Dictionary) -> bool:
	match String(m["type"]):
		"lever", "hole", "plate", "weight":
			return bool(m["state"])
		"button":
			if String((m["def"] as Dictionary).get("mode", "latch")) == "timer":
				return float(m["t_left"]) > 0.0
			return bool(m["state"])
		"lock":
			var g: Dictionary = groups.get(String(m["group"]), {})
			return int(g.get("progress", 0)) >= int(g.get("n", 1))
		"wheel":
			return int(m["step"]) == int((m["def"] as Dictionary).get("open_step", -1))
	return false

## La pelota del jugador choco el cuerpo body a speed m/s. true si era el blanco de un mando (y lo activo, si el golpe
## alcanzo y no acababa de activarse).
func ball_hit(body: Object, speed: float) -> bool:
	if body == null or not (body as Node).has_meta("mech"):
		return false
	var i: int = int((body as Node).get_meta("mech"))
	if i < 0 or i >= mechs.size():
		return false
	var m: Dictionary = mechs[i]
	if speed < PRESS_SPEED or float(m["cool"]) > 0.0:
		return true
	activate(i)
	return true

## Lo que hace el mando i al recibir el pelotazo (o al entrar la pelota en el buzon).
func activate(i: int) -> void:
	if i < 0 or i >= mechs.size():
		return
	var m: Dictionary = mechs[i]
	var d: Dictionary = m["def"]
	m["cool"] = DEBOUNCE
	match String(m["type"]):
		"lever":
			m["state"] = not bool(m["state"])
			_count("click")
		"button":
			if String(d.get("mode", "latch")) == "timer":
				m["t_left"] = float(d.get("time", 3.0))
				_count("click")
			elif not bool(m["state"]):
				m["state"] = true
				_count("click")
		"hole":
			if not bool(m["state"]):
				m["state"] = true
				_count("release")
		"switch":
			var g: Dictionary = groups.get(String(m["group"]), {})
			if g.is_empty() or int(g["progress"]) >= int(g["n"]) or bool(m["state"]):
				return
			if int(m["order"]) == int(g["progress"]) + 1:
				g["progress"] = int(g["progress"]) + 1
				m["state"] = true
				_count("click")
				if int(g["progress"]) >= int(g["n"]):
					acted.emit("release")
			else:
				# Fuera de orden: se apaga toda la secuencia.
				errors += 1
				actions += 1
				g["progress"] = 0
				for o in mechs:
					if String(o["type"]) == "switch" and String(o["group"]) == String(m["group"]):
						o["state"] = false
				acted.emit("error")
		"wheel":
			m["step"] = (int(m["step"]) + 1) % maxi(int(d.get("steps", 4)), 1)
			_count("click")
		"weight":
			if not bool(m["state"]):
				m["state"] = true
				var w: RigidBody3D = m["weight"]
				w.freeze = false
				w.sleeping = false
				_count("release")

func _count(kind: String) -> void:
	actions += 1
	acted.emit(kind)

## Indice del mando de un blanco (o -1).
static func mech_of(collider: Object) -> int:
	if collider != null and collider is Node and (collider as Node).has_meta("mech"):
		return int((collider as Node).get_meta("mech"))
	return -1

## Posicion (global) del blanco del mando i: a donde apuntar.
func aim_of(i: int) -> Vector3:
	var m: Dictionary = mechs[i]
	if m.has("body") and is_instance_valid(m["body"]):
		return (m["body"] as Node3D).global_position
	if m.has("area"):
		return (m["area"] as Node3D).global_position
	return (m["root"] as Node3D).global_position

# --- Paso --------------------------------------------------------------------------------------------------------------

func step(delta: float) -> void:
	time += delta
	for m in mechs:
		m["cool"] = maxf(float(m["cool"]) - delta, 0.0)
		if float(m["t_left"]) > 0.0:
			m["t_left"] = maxf(float(m["t_left"]) - delta, 0.0)
		if m.has("bodies_area") and float(m["cool"]) <= 0.0 and not bool(m["state"]):
			for b in (m["bodies_area"] as Area3D).get_overlapping_bodies():
				if (b.is_in_group("rescue_domino") or b.is_in_group("rescue_crate")) and (b as RigidBody3D).linear_velocity.length() > 0.3:
					activate(int(m["i"]))
					break
		if String(m["type"]) == "plate":
			# Activa mientras una caja este encima.
			var on: bool = false
			for b in (m["area"] as Area3D).get_overlapping_bodies():
				if b.is_in_group("rescue_crate"):
					on = true
			if on and not bool(m["state"]):
				_count("click")
			m["state"] = on
	_apply(false, delta)
	_visuals()

## Calcula el objetivo de cada pieza con sus mandos y la mueve (snap: sin animacion, al armar o reiniciar).
func _apply(snap: bool, delta: float = 0.0) -> void:
	for pi in parts.size():
		var p: Dictionary = parts[pi]
		var drivers: Array = []
		for m in mechs:
			if (m["targets"] as Array).map(func(x: Variant) -> int: return int(x)).has(pi):
				drivers.append(m)
		var d: Dictionary = p["def"]
		var any: bool = false
		var all: bool = not drivers.is_empty()
		var wheel_steps: int = 0
		var weight_v: float = -1.0
		for m in drivers:
			var a: bool = active(m)
			any = any or a
			all = all and a
			if String(m["type"]) == "wheel":
				wheel_steps += int(m["step"])
			if String(m["type"]) == "weight":
				var w: Node3D = m["weight"]
				weight_v = maxf(weight_v, clampf((float((m["hang"] as Vector3).y) - to_local(w.global_position).y) / maxf(float(m["fall"]), 0.01), 0.0, 1.0))
		var on: bool = all if String(d.get("need", "any")) == "all" else any
		if bool(d.get("invert", false)):
			on = not on
		var before: float = float(p["value"])
		if String(p["type"]) == "rotor":
			p["target"] = float(wheel_steps)
		elif weight_v >= 0.0:
			p["target"] = weight_v
		elif float(p["osc"]) > 0.0:
			if drivers.is_empty() or on:
				p["phase"] = float(p["phase"]) + delta / float(p["osc"])
			p["target"] = 0.5 - 0.5 * cos(TAU * float(p["phase"]))
		else:
			p["target"] = 1.0 if on else 0.0
		if snap or weight_v >= 0.0 or float(p["osc"]) > 0.0:
			p["value"] = float(p["target"])
		else:
			p["value"] = move_toward(before, float(p["target"]), float(p["speed"]) * delta)
		var moving: bool = absf(float(p["value"]) - before) > 1e-5
		if moving and not bool(p["moving"]) and not snap and float(p["osc"]) <= 0.0:
			acted.emit("gate")
		p["moving"] = moving
		(p["body"] as AnimatableBody3D).transform = part_transform(p)

## Mandos que se ven como estan: palanca de un lado o del otro, blanco verde, luces de la cerradura, rueda girada, cuerda.
func _visuals() -> void:
	var pulse: float = 0.45 + 0.35 * sin(time * 5.0)
	for m in mechs:
		var vis: Dictionary = m["parts_vis"]
		var on: bool = active(m)
		match String(m["type"]):
			"lever":
				var arm: Node3D = vis["arm"]
				arm.rotation.z = lerp_angle(arm.rotation.z, deg_to_rad(20.0 if bool(m["state"]) else -20.0), 0.3)
			"button", "switch":
				var cap: MeshInstance3D = vis["cap"]
				var down: bool = on or bool(m["state"])
				cap.position.x = -0.06 if down else -0.09
				var c: Color = ON if (down and String(m["type"]) != "switch") else (m["color"] as Color)
				if String(m["type"]) == "switch" and bool(m["state"]):
					c = (m["color"] as Color).lightened(0.35)
				(cap.material_override as StandardMaterial3D).albedo_color = c
				(cap.material_override as StandardMaterial3D).emission = c
				(cap.material_override as StandardMaterial3D).emission_energy_multiplier = 1.4 if down else pulse
				if m.has("timer_label"):
					(m["timer_label"] as Label3D).text = ("%.1f s" % float(m["t_left"])) if float(m["t_left"]) > 0.0 else "%d s" % int(float((m["def"] as Dictionary).get("time", 3.0)))
			"lock":
				var g: Dictionary = groups.get(String(m["group"]), {})
				var lamps: Array = vis["lamps"]
				for k in lamps.size():
					var lit: bool = k < int(g.get("progress", 0))
					var lm: StandardMaterial3D = (lamps[k][0] as MeshInstance3D).material_override
					var lc: Color = lamps[k][1]
					lm.albedo_color = lc if lit else lc * 0.55
					lm.emission = lc
					lm.emission_energy_multiplier = 2.2 if lit else 0.5
			"wheel":
				var wheel: Node3D = vis["wheel"]
				var want: float = -TAU * float(m["step"]) / float(maxi(int((m["def"] as Dictionary).get("steps", 4)), 1))
				wheel.rotation.x = lerp_angle(wheel.rotation.x, want, 0.25)
			"plate":
				var pm: StandardMaterial3D = (vis["pad"] as MeshInstance3D).material_override
				pm.albedo_color = ON if bool(m["state"]) else Color(0.25, 0.6, 0.95)
				pm.emission = pm.albedo_color
			"hole":
				var fm: StandardMaterial3D = (vis["glow"] as MeshInstance3D).material_override
				fm.albedo_color = ON if bool(m["state"]) else HANDLE
				fm.emission = fm.albedo_color
				fm.emission_energy_multiplier = 1.2 if bool(m["state"]) else pulse
			"weight":
				var w: Node3D = m["weight"]
				var top: Vector3 = (m["root"] as Node3D).position
				var rope: MeshInstance3D = m["rope"]
				if bool(m["state"]):
					rope.visible = false
				else:
					var wp: Vector3 = to_local(w.global_position)
					rope.position = (top + wp) * 0.5 + Vector3.UP * 0.15
					rope.scale = Vector3(1, maxf(top.y - wp.y - 0.3, 0.05), 1)
		if vis.has("glow") and String(m["type"]) in ["lever", "wheel", "weight"]:
			var gm: StandardMaterial3D = (vis["glow"] as MeshInstance3D).material_override
			gm.emission_energy_multiplier = pulse if not bool(m["state"]) else 0.2

## Vuelve todo al principio (otro intento).
func reset() -> void:
	for m in mechs:
		m["state"] = false
		m["t_left"] = 0.0
		m["step"] = 0
		m["cool"] = 0.0
		if m.has("weight"):
			var w: RigidBody3D = m["weight"]
			w.freeze = true
			w.linear_velocity = Vector3.ZERO
			w.angular_velocity = Vector3.ZERO
			w.transform = Transform3D(Basis(), m["hang"])
			(m["rope"] as Node3D).visible = true
	for g in groups.values():
		g["progress"] = 0
	for p in parts:
		p["phase"] = 0.0
		p["value"] = float((p["def"] as Dictionary).get("start", 0.0))
	_apply(true)
