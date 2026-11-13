class_name RescueMechs
extends Node3D
## Mecanismos del Rescate (pedido del usuario: «palancas, botones, interruptores, cerraduras con secuencia, plataformas
## moviles, contrapesos, poleas, engranajes, rampas, puentes… mecanismos que requieren activar dos elementos en orden,
## mantener un boton presionado, temporizados»). Dos clases de cosas, armadas desde el nivel (minigames.json):
##
## PIEZAS («parts»): cuerpos que se mueven y que la pelota toca de verdad (AnimatableBody3D sincronizado con la fisica:
## al moverse empujan, levantan o sueltan a la pelota; nada la teletransporta). Cada una tiene un valor 0..1 que va hacia
## su objetivo con su velocidad:
##  - "slide" (compuerta, plataforma, ascensor): se traslada de pos a pos + open;
##  - "hinge" (puente levadizo, rampa que se inclina, trampa): gira alrededor de una bisagra (hinge, axis) hasta angle;
##  - "rotor" (engranaje con jaula): barras en circulo con un hueco que gira de a pasos (steps por vuelta);
##  - con "osc" (periodo, s) la pieza va y viene sola mientras sus mandos esten activos (o siempre si no tiene mandos).
##
## MANDOS («mechs»): lo que el jugador toca en la pantalla (un toque sobre el mecanismo, con un area de toque generosa) o
## lo que activa la pelota. Cada uno tiene targets (indices de piezas):
##  - "lever": cada toque la cambia (activa / no);
##  - "button": "latch" queda apretado, "hold" solo mientras se mantiene el dedo, "timer" activo durante time segundos;
##  - "switch": interruptor de una secuencia (group, order); el mando "lock" del grupo se abre cuando se tocaron en el
##    orden que muestran sus luces de colores; un toque fuera de orden apaga todo (error);
##  - "crank": manivela; cada toque gira un paso los rotores (y activa compuertas en open_step);
##  - "weight": contrapeso colgado de una polea; un toque corta la cuerda, el peso cae (cuerpo fisico) y lo que cae mueve
##    las piezas (fall metros = recorrido completo);
##  - "kick": blanco que se aprieta solo con un pelotazo real (impacto >= PRESS_SPEED).
## Cuenta acciones (toques utiles) y errores (secuencia equivocada) para el puntaje y el online.

const PICK_LAYER := 1 << 9
const PRESS_SPEED := 2.5
const HANDLE := Color(1.0, 0.78, 0.15)
const METAL := Color(0.6, 0.64, 0.72)
const OFF := Color(0.95, 0.15, 0.12)
const ON := Color(0.2, 0.95, 0.35)

signal acted(kind: String)

var parts: Array = []
var mechs: Array = []
var groups: Dictionary = {}
var actions: int = 0
var errors: int = 0
var held: int = -1
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
	body.global_transform = base
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

func _make_mech(d: Dictionary, i: int) -> Dictionary:
	var type: String = String(d.get("type", "lever"))
	var pos: Vector3 = v3(d.get("pos"))
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	root.rotation.y = deg_to_rad(float(d.get("yaw", 0.0)))
	var m := {"type": type, "def": d, "root": root, "i": i, "state": false, "held": false, "t_left": 0.0, "step": 0,
		"targets": d.get("targets", []), "group": String(d.get("group", "")), "order": int(d.get("order", 0)), "n": int(d.get("n", 0)),
		"parts_vis": {}}
	match type:
		"lever":
			root.add_child(_box(Vector3(0.5, 0.25, 0.5), Color(0.25, 0.27, 0.32)))
			var arm := Node3D.new()
			arm.position.y = 0.12
			root.add_child(arm)
			var stick := _box(Vector3(0.08, 0.9, 0.08), METAL)
			stick.position.y = 0.45
			arm.add_child(stick)
			var knob := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.14
			sm.height = 0.28
			knob.mesh = sm
			knob.material_override = mat(HANDLE, 0.6)
			knob.position.y = 0.92
			arm.add_child(knob)
			arm.rotation.z = deg_to_rad(35.0)
			m["parts_vis"] = {"arm": arm, "glow": knob}
		"button", "switch", "kick":
			var base := _box(Vector3(0.7, 0.18, 0.7), Color(0.25, 0.27, 0.32))
			root.add_child(base)
			var cap := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.26
			cm.bottom_radius = 0.28
			cm.height = 0.12
			cap.mesh = cm
			var c: Color = Color.from_string(String(d.get("color", "")), OFF) if d.has("color") else (Color(0.2, 0.5, 1.0) if String(d.get("mode", "")) == "hold" else (Color(1.0, 0.55, 0.1) if String(d.get("mode", "")) == "timer" else OFF))
			cap.material_override = mat(c, 0.5)
			cap.position.y = 0.15
			root.add_child(cap)
			m["color"] = c
			m["parts_vis"] = {"cap": cap, "glow": cap}
			if type == "kick":
				# Blanco fisico para la pelota del jugador (el de antes): se aprieta con un impacto real.
				var body := StaticBody3D.new()
				body.collision_layer = Ball.LAYER_WORLD
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(0.7, 0.6, 0.7)
				cs.shape = bs
				cs.position.y = 0.15
				body.add_child(cs)
				root.add_child(body)
				m["kick_body"] = body
			if String(d.get("mode", "")) == "timer":
				var lab := Label3D.new()
				lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lab.font_size = 46
				lab.outline_size = 10
				lab.modulate = Color(1.0, 0.75, 0.35)
				lab.position = Vector3(0.0, 0.45, 0.0)
				lab.text = "%d s" % int(float(d.get("time", 3.0)))
				root.add_child(lab)
				m["timer_label"] = lab
		"lock":
			root.add_child(_box(Vector3(0.24, 0.7, 1.2), Color(0.2, 0.22, 0.27)))
			var lamps: Array = []
			var cols: Array = d.get("colors", [])
			for k in int(d.get("n", 3)):
				var lamp := MeshInstance3D.new()
				var sm2 := SphereMesh.new()
				sm2.radius = 0.11
				sm2.height = 0.22
				lamp.mesh = sm2
				var lc: Color = Color.from_string(String(cols[k]) if k < cols.size() else "#ffffff", Color.WHITE)
				lamp.material_override = mat(lc * 0.45, 0.15)
				lamp.position = Vector3(-0.14, 0.12, -0.36 + 0.36 * float(k))
				root.add_child(lamp)
				lamps.append([lamp, lc])
			m["parts_vis"] = {"lamps": lamps}
		"crank":
			root.add_child(_box(Vector3(0.3, 0.9, 0.3), Color(0.25, 0.27, 0.32)))
			var wheel := Node3D.new()
			wheel.position = Vector3(0, 0.95, 0.2)
			root.add_child(wheel)
			var disc := MeshInstance3D.new()
			var dm := CylinderMesh.new()
			dm.top_radius = 0.38
			dm.bottom_radius = 0.38
			dm.height = 0.06
			disc.mesh = dm
			disc.material_override = mat(Color(0.75, 0.55, 0.2))
			disc.rotation.x = PI * 0.5
			wheel.add_child(disc)
			var handle := _box(Vector3(0.1, 0.1, 0.3), HANDLE, 0.6)
			handle.position = Vector3(0.3, 0, 0.12)
			wheel.add_child(handle)
			m["parts_vis"] = {"wheel": wheel, "glow": handle}
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
			pulley.position.y = 0.0
			root.add_child(pulley)
			var w := RigidBody3D.new()
			w.mass = float(d.get("mass", 8.0))
			w.collision_layer = Ball.LAYER_WORLD
			w.collision_mask = Ball.LAYER_WORLD
			w.freeze = true
			w.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			var cs2 := CollisionShape3D.new()
			var bs2 := BoxShape3D.new()
			bs2.size = Vector3(0.45, 0.45, 0.45)
			cs2.shape = bs2
			w.add_child(cs2)
			w.add_child(_box(bs2.size, Color(0.35, 0.36, 0.42)))
			var tag := _box(Vector3(0.47, 0.12, 0.47), HANDLE, 0.4)
			w.add_child(tag)
			add_child(w)
			var hang: Vector3 = pos + Vector3(0, -float(d.get("rope", 0.9)), 0)
			w.global_position = hang
			var rope := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.02
			rm.bottom_radius = 0.02
			rm.height = 1.0
			rope.mesh = rm
			rope.material_override = mat(Color(0.85, 0.75, 0.55))
			add_child(rope)
			m["weight"] = w
			m["hang"] = hang
			m["fall"] = fall
			m["rope"] = rope
			m["parts_vis"] = {"glow": tag}
	# Area de toque (generosa, en una capa propia: la pelota no la toca).
	if type != "lock" and type != "kick":
		var pick := StaticBody3D.new()
		pick.collision_layer = PICK_LAYER
		pick.collision_mask = 0
		var pcs := CollisionShape3D.new()
		var pbs := BoxShape3D.new()
		pbs.size = Vector3(0.9, 1.4, 0.9)
		pcs.shape = pbs
		pcs.position.y = 0.5
		pick.add_child(pcs)
		pick.set_meta("mech", i)
		if type == "weight":
			(m["weight"] as Node3D).add_child(pick)
			pcs.position = Vector3(0, 0.3, 0)
		else:
			root.add_child(pick)
		m["pick"] = pick
	if d.has("label"):
		var l := Label3D.new()
		l.text = String(d["label"])
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 56
		l.outline_size = 10
		l.position.y = 1.35 if type in ["lever", "crank"] else 0.85
		root.add_child(l)
	return m

## Esta activo el mando m.
func active(m: Dictionary) -> bool:
	match String(m["type"]):
		"lever":
			return bool(m["state"])
		"button", "kick":
			var mode: String = String((m["def"] as Dictionary).get("mode", "latch"))
			if mode == "hold":
				return bool(m["held"])
			if mode == "timer":
				return float(m["t_left"]) > 0.0
			return bool(m["state"])
		"lock":
			var g: Dictionary = groups.get(String(m["group"]), {})
			return int(g.get("progress", 0)) >= int(g.get("n", 1))
		"crank":
			return int(m["step"]) == int((m["def"] as Dictionary).get("open_step", -1))
		"weight":
			return bool(m["state"])
	return false

## Toque sobre el mando i (pressed) o fin del toque. Devuelve true si el toque era para un mecanismo.
func touch(i: int, pressed: bool) -> bool:
	if i < 0 or i >= mechs.size():
		return false
	var m: Dictionary = mechs[i]
	var d: Dictionary = m["def"]
	if not pressed:
		if held == i:
			m["held"] = false
			held = -1
		return true
	match String(m["type"]):
		"lever":
			m["state"] = not bool(m["state"])
			_count("click")
		"button":
			var mode: String = String(d.get("mode", "latch"))
			if mode == "hold":
				m["held"] = true
				held = i
				_count("click")
			elif mode == "timer":
				if float(m["t_left"]) <= 0.0:
					m["t_left"] = float(d.get("time", 3.0))
					_count("click")
			elif not bool(m["state"]):
				m["state"] = true
				_count("click")
		"switch":
			var g: Dictionary = groups.get(String(m["group"]), {})
			if g.is_empty() or int(g["progress"]) >= int(g["n"]) or bool(m["state"]):
				return true
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
		"crank":
			m["step"] = (int(m["step"]) + 1) % maxi(int(d.get("steps", 4)), 1)
			_count("click")
		"weight":
			if not bool(m["state"]):
				m["state"] = true
				var w: RigidBody3D = m["weight"]
				w.freeze = false
				w.sleeping = false
				_count("release")
	return true

func _count(kind: String) -> void:
	actions += 1
	acted.emit(kind)

## Pelotazo contra el cuerpo body (impacto: velocidad hacia el blanco). true si apreto un blanco «kick».
func kick_hit(body: Object, impact: float) -> bool:
	for m in mechs:
		if String(m["type"]) == "kick" and m.get("kick_body") == body and not bool(m["state"]) and impact >= PRESS_SPEED:
			m["state"] = true
			_count("click")
			return true
	return false

## Indice del mando que tiene el area de toque collider (o -1).
static func mech_of(collider: Object) -> int:
	if collider != null and collider is Node and (collider as Node).has_meta("mech"):
		return int((collider as Node).get_meta("mech"))
	return -1

# --- Paso --------------------------------------------------------------------------------------------------------------

func step(delta: float) -> void:
	time += delta
	for m in mechs:
		if float(m["t_left"]) > 0.0:
			m["t_left"] = maxf(float(m["t_left"]) - delta, 0.0)
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
		var crank_steps: int = 0
		var weight_v: float = -1.0
		for m in drivers:
			var a: bool = active(m)
			any = any or a
			all = all and a
			if String(m["type"]) == "crank":
				crank_steps += int(m["step"])
			if String(m["type"]) == "weight":
				var w: Node3D = m["weight"]
				weight_v = maxf(weight_v, clampf((float((m["hang"] as Vector3).y) - w.global_position.y) / maxf(float(m["fall"]), 0.01), 0.0, 1.0))
		var on: bool = all if String(d.get("need", "any")) == "all" else any
		if bool(d.get("invert", false)):
			on = not on
		var before: float = float(p["value"])
		if String(p["type"]) == "rotor":
			p["target"] = float(crank_steps)
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
		(p["body"] as AnimatableBody3D).global_transform = part_transform(p)

## Mandos que se ven como estan: palanca inclinada, boton hundido y verde, luces de la cerradura, manivela girada, cuerda.
func _visuals() -> void:
	var pulse: float = 0.45 + 0.35 * sin(time * 5.0)
	for m in mechs:
		var vis: Dictionary = m["parts_vis"]
		var on: bool = active(m)
		match String(m["type"]):
			"lever":
				(vis["arm"] as Node3D).rotation.z = deg_to_rad(-35.0 if bool(m["state"]) else 35.0)
			"button", "switch", "kick":
				var cap: MeshInstance3D = vis["cap"]
				var down: bool = on or bool(m["state"]) or bool(m["held"])
				cap.position.y = 0.09 if down else 0.15
				var c: Color = ON if (down and String(m["type"]) != "switch") else (m["color"] as Color)
				if String(m["type"]) == "switch" and bool(m["state"]):
					c = (m["color"] as Color).lightened(0.3)
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
					lm.albedo_color = lc if lit else lc * 0.45
					lm.emission = lc
					lm.emission_energy_multiplier = 2.0 if lit else 0.25
			"crank":
				var wheel: Node3D = vis["wheel"]
				var want: float = -TAU * float(m["step"]) / float(maxi(int((m["def"] as Dictionary).get("steps", 4)), 1))
				wheel.rotation.z = lerp_angle(wheel.rotation.z, want, 0.25)
			"weight":
				var w: Node3D = m["weight"]
				var top: Vector3 = (m["root"] as Node3D).global_position
				var rope: MeshInstance3D = m["rope"]
				if bool(m["state"]):
					rope.visible = false
				else:
					var mid: Vector3 = (top + w.global_position) * 0.5 + Vector3.UP * 0.12
					rope.global_position = mid
					rope.scale = Vector3(1, maxf(top.y - w.global_position.y - 0.22, 0.05), 1)
		if vis.has("glow") and String(m["type"]) in ["lever", "crank", "weight"]:
			var gm: StandardMaterial3D = (vis["glow"] as MeshInstance3D).material_override
			gm.emission_energy_multiplier = pulse if not bool(m["state"]) else 0.2

## Vuelve todo al principio (otro intento).
func reset() -> void:
	for m in mechs:
		m["state"] = false
		m["held"] = false
		m["t_left"] = 0.0
		m["step"] = 0
		if m.has("weight"):
			var w: RigidBody3D = m["weight"]
			w.freeze = true
			w.linear_velocity = Vector3.ZERO
			w.angular_velocity = Vector3.ZERO
			w.global_transform = Transform3D(Basis(), m["hang"])
			(m["rope"] as Node3D).visible = true
	held = -1
	for g in groups.values():
		g["progress"] = 0
	for p in parts:
		p["phase"] = 0.0
		p["value"] = float((p["def"] as Dictionary).get("start", 0.0))
	_apply(true)
