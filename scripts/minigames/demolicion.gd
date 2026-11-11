class_name Demolicion
extends Minigame
## «Demolición» (primera colección, etapa 7: física y destrucción). Un jugador, tiros limitados: hay que derribar los
## bloques objetivo de una mesa con la pelota real. Cada bloque es un cuerpo rigido (Jolt) con masa: el golpe de la
## pelota y los choques entre bloques deciden todo (torres, piramides, fichas de domino en cadena, muros, blancos rojos
## entre bloques que no hay que tocar). Un bloque cuenta como derribado si salio de la mesa o quedo volcado (mas de 50
## grados); bajar un piso dentro de la torre no cuenta. Puntaje: objetivos derribados, tiros de sobra y penalizacion por bloques
## «prohibidos» (blancos); medallas por nivel. Sin premio por participar: con 0 objetivos no hay medalla.
##
## Niveles en resources/minigames/minigames.json ("demolicion"): distancia y tamaño de la mesa, tiros y la lista de
## bloques {pos (sobre la mesa), size, mass, kind: "target" (rojo) | "keep" (blanco: no tocar) | "block" (neutro)} o
## figuras armadas ("tower", "pyramid", "dominoes", "wall").

const SCENE := "res://scenes/minigames/demolicion.tscn"
const TILT_DOWN := 50.0
## Velocidad (m/s) bajo la que un bloque se considera quieto.
const SETTLED := 0.12
const TARGET_POINTS := 100
const KEEP_PENALTY := 60
const SPARE_SHOT := 60

var table_x: float = 16.0
var table_top: float = 0.8
var blocks: Array[RigidBody3D] = []
## Por bloque: {kind, start (Transform3D)}
var block_info: Array = []
var shots_max: int = 3
var _blocks_root: Node3D

func game_id() -> String:
	return "demolicion"

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 3))
	max_turns = shots_max
	table_x = float(def.get("distance", 16.0))
	table_top = float(def.get("table_h", 0.8))
	var tsize: Vector2 = Vector2(float(def.get("table_depth", 1.6)), float(def.get("table_width", 5.0)))
	# Piso de juego (y = 0: el mismo piso que supone la prediccion del tiro) y la mesa.
	static_box(Vector3(80, 1, 40), Vector3(table_x - 10.0, -0.5, 0), Color(0.16, 0.42, 0.2), Vector3.ZERO, 0.5)
	if table_top > 0.01:
		static_box(Vector3(tsize.x, table_top, tsize.y), Vector3(table_x, table_top * 0.5, 0), Color(0.45, 0.32, 0.2))
	# Fondo: una pared lejana para que la pelota no se pierda (rebota y vuelve).
	static_box(Vector3(0.6, 6, 40), Vector3(table_x + 12.0, 3, 0), Color(0.3, 0.33, 0.4))
	for w in def.get("walls", []):
		var wd: Dictionary = w
		static_box(BotonCaida._vec(wd.get("size", [3, 1.5, 0.3])), BotonCaida._vec(wd.get("pos", [8, 0.75, 0])), Color(0.85, 0.85, 0.9),
			Vector3(deg_to_rad(float(wd.get("pitch", 0.0))), deg_to_rad(float(wd.get("yaw", 0.0))), deg_to_rad(float(wd.get("roll", 0.0)))), float(wd.get("bounce", 0.6)))
	_blocks_root = Node3D.new()
	_blocks_root.name = "Blocks"
	add_child(_blocks_root)
	_spawn_blocks()

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0.0, ball.radius if ball != null else 0.11, float(def.get("ball_z", 0.0)))

func _aim_point(_s: int) -> Vector3:
	return Vector3(table_x, table_top + 0.8, 0.0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(table_x - 1.0, Vector2(10.0, 30.0), false, 4.0, 4.0, ball.radius)

## Lista de bloques del nivel: los sueltos y las figuras armadas, en coordenadas sobre la mesa (x hacia el fondo, y desde
## la tapa de la mesa, z al costado).
func layout() -> Array:
	var out: Array = []
	for b in def.get("blocks", []):
		out.append(b)
	for f in def.get("figures", []):
		var fd: Dictionary = f
		var size: Vector3 = BotonCaida._vec(fd.get("size", [0.45, 0.45, 0.45]))
		var at: Vector3 = BotonCaida._vec(fd.get("at", [0, 0, 0]))
		var kind: String = String(fd.get("kind", "target"))
		var mass: float = float(fd.get("mass", 1.2))
		match String(fd.get("type", "tower")):
			"tower":
				for i in int(fd.get("n", 5)):
					out.append({"pos": [at.x, size.y * (float(i) + 0.5), at.z], "size": [size.x, size.y, size.z], "kind": kind, "mass": mass})
			"pyramid":
				var rows: int = int(fd.get("n", 3))
				for r in rows:
					for k in rows - r:
						var z: float = at.z + (float(k) - float(rows - r - 1) * 0.5) * (size.z + 0.02)
						out.append({"pos": [at.x, size.y * (float(r) + 0.5), z], "size": [size.x, size.y, size.z], "kind": kind, "mass": mass})
			"wall":
				var cols: int = int(fd.get("cols", 4))
				for r in int(fd.get("rows", 3)):
					for k in cols:
						var z2: float = at.z + (float(k) - float(cols - 1) * 0.5) * (size.z + 0.02)
						out.append({"pos": [at.x, size.y * (float(r) + 0.5), z2], "size": [size.x, size.y, size.z], "kind": kind, "mass": mass})
			"dominoes":
				var n: int = int(fd.get("n", 6))
				var step: Vector3 = BotonCaida._vec(fd.get("step", [0.0, 0.0, 0.55]))
				for i in n:
					var p: Vector3 = at + step * float(i)
					out.append({"pos": [p.x, size.y * 0.5, p.z], "size": [size.x, size.y, size.z], "kind": kind, "mass": mass})
	return out

func _spawn_blocks() -> void:
	for b in blocks:
		if is_instance_valid(b):
			_blocks_root.remove_child(b)
			b.queue_free()
	blocks.clear()
	block_info.clear()
	for e in layout():
		var ed: Dictionary = e
		var size: Vector3 = BotonCaida._vec(ed.get("size", [0.45, 0.45, 0.45]))
		var local: Vector3 = BotonCaida._vec(ed.get("pos", [0, 0.25, 0]))
		var kind: String = String(ed.get("kind", "target"))
		var rb := RigidBody3D.new()
		rb.mass = float(ed.get("mass", 1.2))
		rb.collision_layer = Ball.LAYER_WORLD
		rb.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
		rb.can_sleep = true
		var pm := PhysicsMaterial.new()
		pm.friction = 0.7
		pm.bounce = 0.1
		rb.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var mi := MeshInstance3D.new()
		if String(ed.get("shape", "box")) == "barrel":
			# Barril: cilindro acostado o parado (rueda y se desparrama distinto que una caja).
			var cyl := CylinderShape3D.new()
			cyl.radius = size.x * 0.5
			cyl.height = size.y
			cs.shape = cyl
			var cm := CylinderMesh.new()
			cm.top_radius = cyl.radius
			cm.bottom_radius = cyl.radius
			cm.height = size.y
			mi.mesh = cm
		else:
			var bs := BoxShape3D.new()
			bs.size = size
			cs.shape = bs
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
		rb.add_child(cs)
		var c: Color = {"target": Color(0.92, 0.2, 0.15), "keep": Color(0.95, 0.95, 0.97)}.get(kind, Color(0.95, 0.75, 0.2))
		mi.material_override = color_mat(c)
		rb.add_child(mi)
		_blocks_root.add_child(rb)
		# Apoyados (con 2 mm de aire: se asientan sin saltar).
		var world := Vector3(table_x + local.x, table_top + local.y + 0.002, local.z)
		rb.global_position = world
		blocks.append(rb)
		block_info.append({"kind": kind, "start": rb.global_transform})

func reset_level() -> void:
	_spawn_blocks()
	super.reset_level()

## El bloque i ya cayo de la mesa (su centro bajo la tapa) o quedo volcado (su eje vertical a mas de TILT_DOWN grados).
## Bajar un piso dentro de la torre NO cuenta (medido: al sacar el de abajo, los de arriba bajan 0,45 m y siguen en pie).
func is_down(i: int) -> bool:
	var b: RigidBody3D = blocks[i]
	if b.global_position.y < table_top - 0.05:
		return true
	var up: Vector3 = b.global_transform.basis.y.normalized()
	return up.dot(Vector3.UP) < cos(deg_to_rad(TILT_DOWN))

func count(kind: String, down: bool) -> int:
	var n: int = 0
	for i in blocks.size():
		if String(block_info[i]["kind"]) == kind and is_down(i) == down:
			n += 1
	return n

func total(kind: String) -> int:
	var n: int = 0
	for e in block_info:
		if String(e["kind"]) == kind:
			n += 1
	return n

func _settling() -> bool:
	for b in blocks:
		if not b.sleeping and b.linear_velocity.length() > SETTLED:
			return true
	return false

func _flight_check(_delta: float) -> String:
	# La pelota se fue lejos o quedo quieta y los bloques ya se asentaron.
	if _t > 0.6 and not _settling() and (ball.linear_velocity.length() < SLOW_SPEED or ball.global_position.x > table_x + 10.0):
		return "listo"
	return ""

func _on_resolved(s: int, _result: String) -> void:
	points[0] = count("target", true)
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if count("target", false) == 0 else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)

func _check_winner() -> int:
	if count("target", false) == 0 or int(shots[0]) >= shots_max:
		return Side.USER
	return -1

func final_score() -> int:
	var down: int = count("target", true)
	if down == 0:
		return 0
	var s: int = down * TARGET_POINTS - count("keep", true) * KEEP_PENALTY
	if count("target", false) == 0:
		s += maxi(shots_max - int(shots[0]), 0) * SPARE_SHOT
	return maxi(s, 0)

func _report_achievements(w: int, medal: int) -> void:
	super._report_achievements(w, medal)
	Achievements.event(&"derribo", count("target", true) + count("keep", true))
	if count("target", false) == 0:
		Achievements.event(&"demolicion_limpia")
		if int(shots[0]) == 1:
			Achievements.event(&"demolicion_un_tiro")

func _result_text(_r: String) -> Array:
	var left: int = count("target", false)
	var keep_down: int = count("keep", true)
	var sub: String = "Quedan %d · tiros %d de %d" % [left, int(shots[0]), shots_max]
	if keep_down > 0:
		sub += " · tiraste %d blanco(s)" % keep_down
	if left == 0:
		return ["¡TODO ABAJO!", Color(0.35, 1.0, 0.45), sub]
	return ["%d derribados" % count("target", true), Color(1.0, 0.85, 0.35), sub]

func _refresh_score() -> void:
	hud.set_score_text("Objetivos %d / %d · tiros %d / %d" % [count("target", true), total("target"), int(shots[0]), shots_max])
