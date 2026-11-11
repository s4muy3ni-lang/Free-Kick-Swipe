class_name Demolicion
extends Minigame
## «Demolición» (DESTRUCCION Y MECANISMOS). Un jugador, tiros limitados: hay que derribar los bloques objetivo con la
## pelota real. Cada bloque es un cuerpo rigido (Jolt) con masa y material: el golpe de la pelota y los choques entre
## bloques deciden todo (torres, piramides, domino, muros, jenga, casitas, columnatas, vidrieras). Un bloque cuenta como
## derribado si salio de la mesa, quedo volcado (mas de 50 grados), se rompio (vidrio) o, si el nivel lo pide
## ("down_h"), quedo por debajo de esa altura sobre la mesa. Bajar un piso dentro de la torre no cuenta.
## Puntaje: objetivos derribados, tiros de sobra y penalizacion por bloques «prohibidos» (blancos); medallas por nivel.
## Sin premio por participar: con 0 objetivos no hay medalla.
##
## Materiales (MATERIALS): madera, cajon, ladrillo, piedra, metal y vidrio; cada uno con su densidad, rozamiento, rebote y
## aspecto (textura procedural). El vidrio se ROMPE con un impacto real fuerte (de la pelota, de otro bloque o del piso):
## el panel se reemplaza por esquirlas que heredan su velocidad. "material" cambia la fisica; "look" solo el aspecto (los
## niveles viejos conservan su fisica medida).
## Escenarios ("theme"): obra, castillo y almacen, con piso, mesa, fondo, decoracion y luz propios (lo decorativo no
## tiene colision y queda fuera del camino de la pelota).
##
## Niveles en resources/minigames/minigames.json ("demolicion"): distancia y tamaño de la mesa, tiros, tema y la lista
## de bloques {pos (sobre la mesa), size, mass?, material?, look?, shape?: "box" | "barrel", kind: "target" (rojo) |
## "keep" (blanco: no tocar) | "block" (neutro)} o figuras armadas ("tower", "pyramid", "dominoes", "wall", "jenga",
## "house", "colonnade").

const SCENE := "res://scenes/minigames/demolicion.tscn"
const TILT_DOWN := 50.0
## Velocidad (m/s) bajo la que un bloque se considera quieto.
const SETTLED := 0.12
const TARGET_POINTS := 100
const KEEP_PENALTY := 60
const SPARE_SHOT := 60
## Masa por m3 de los bloques sin "mass" (escala de juego: un cubo de 0,45 m de madera pesa 1 kg).
const BASE_DENSITY := 11.0
## Esquirlas vivas como maximo (Android): las mas viejas se quitan.
const MAX_SHARDS := 48

## density (relativa a la madera), friction, bounce, color, finish (ArcadeLook), break (m/s de impacto que lo rompe; 0 = no).
const MATERIALS := {
	"wood": {"density": 1.0, "friction": 0.7, "bounce": 0.1, "color": Color(0.74, 0.54, 0.32), "finish": "wood", "break": 0.0},
	"crate": {"density": 0.9, "friction": 0.7, "bounce": 0.1, "color": Color(0.66, 0.47, 0.26), "finish": "wood", "break": 0.0},
	"brick": {"density": 1.6, "friction": 0.85, "bounce": 0.05, "color": Color(0.68, 0.3, 0.22), "finish": "stone", "break": 0.0},
	"stone": {"density": 2.0, "friction": 0.9, "bounce": 0.05, "color": Color(0.64, 0.62, 0.57), "finish": "stone", "break": 0.0},
	"metal": {"density": 2.6, "friction": 0.45, "bounce": 0.08, "color": Color(0.58, 0.62, 0.68), "finish": "metal", "break": 0.0},
	"glass": {"density": 0.7, "friction": 0.4, "bounce": 0.05, "color": Color(0.62, 0.86, 1.0), "finish": "glass", "break": 3.0},
}
const KIND_TINT := {"target": Color(0.9, 0.16, 0.12), "keep": Color(0.96, 0.96, 0.98)}

var table_x: float = 16.0
var table_top: float = 0.8
var theme: String = "obra"
var blocks: Array[RigidBody3D] = []
## Por bloque: {kind, start (Transform3D), mat, broken, pv}
var block_info: Array = []
var shots_max: int = 3
var down_h: float = -1.0
var broken_count: int = 0
var _blocks_root: Node3D
var _shards: Array = []

func game_id() -> String:
	return "demolicion"

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 3))
	max_turns = shots_max
	table_x = float(def.get("distance", 16.0))
	table_top = float(def.get("table_h", 0.8))
	theme = String(def.get("theme", "obra"))
	down_h = float(def.get("down_h", -1.0))
	var tsize: Vector2 = Vector2(float(def.get("table_depth", 1.6)), float(def.get("table_width", 5.0)))
	# Piso de juego (y = 0: el mismo piso que supone la prediccion del tiro) y la mesa.
	var ground := static_box(Vector3(80, 1, 40), Vector3(table_x - 10.0, -0.5, 0), Color(0.16, 0.42, 0.2), Vector3.ZERO, 0.5)
	_dress(ground, null)
	if table_top > 0.01:
		var table := static_box(Vector3(tsize.x, table_top, tsize.y), Vector3(table_x, table_top * 0.5, 0), Color(0.45, 0.32, 0.2))
		_dress_table(table, Vector3(tsize.x, table_top, tsize.y))
	# Fondo: una pared lejana para que la pelota no se pierda (rebota y vuelve).
	var back := static_box(Vector3(0.6, 6, 40), Vector3(table_x + 12.0, 3, 0), Color(0.3, 0.33, 0.4))
	_dress(back, null)
	for w in def.get("walls", []):
		var wd: Dictionary = w
		var wall := static_box(BotonCaida._vec(wd.get("size", [3, 1.5, 0.3])), BotonCaida._vec(wd.get("pos", [8, 0.75, 0])), Color(0.85, 0.85, 0.9),
			Vector3(deg_to_rad(float(wd.get("pitch", 0.0))), deg_to_rad(float(wd.get("yaw", 0.0))), deg_to_rad(float(wd.get("roll", 0.0)))), float(wd.get("bounce", 0.6)))
		_dress(wall, ArcadeLook.mat(Color(0.7, 0.7, 0.72), "stone", 2.0))
	_build_theme()
	_blocks_root = Node3D.new()
	_blocks_root.name = "Blocks"
	add_child(_blocks_root)
	_spawn_blocks()
	# La pelota usa deteccion continua: su choque con un panel liviano puede no llegar a la señal del panel, pero si a
	# la de la pelota.
	ball.body_entered.connect(_on_ball_body)

## Pone un material propio a la malla de una caja de static_box (o la oculta si m es null).
func _dress(body: Node3D, m: Material) -> void:
	for c in body.get_children():
		if c is MeshInstance3D:
			if m == null:
				(c as MeshInstance3D).visible = false
			else:
				(c as MeshInstance3D).material_override = m

# --- Escenarios ---------------------------------------------------------------------------------------------------------

func _dress_table(table: StaticBody3D, size: Vector3) -> void:
	match theme:
		"castillo":
			_dress(table, ArcadeLook.mat(Color(0.6, 0.58, 0.53), "stone", 1.5))
			# Cornisa de piedra.
			ArcadeLook.deco(self, "box", Vector3(size.x + 0.16, 0.1, size.z + 0.16), Vector3(table_x, table_top - 0.05, 0), ArcadeLook.mat(Color(0.5, 0.48, 0.44), "stone"))
		"almacen":
			# Tarima de madera sobre patas de acero.
			_dress(table, null)
			ArcadeLook.deco(self, "box", Vector3(size.x, 0.12, size.z), Vector3(table_x, table_top - 0.06, 0), ArcadeLook.mat(Color(0.7, 0.52, 0.3), "wood", 2.0))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					ArcadeLook.deco(self, "box", Vector3(0.1, table_top - 0.12, 0.1), Vector3(table_x + sx * (size.x * 0.5 - 0.1), (table_top - 0.12) * 0.5, sz * (size.z * 0.5 - 0.1)), ArcadeLook.mat(Color(0.25, 0.27, 0.3), "metal"))
			ArcadeLook.deco(self, "box", Vector3(size.x - 0.1, 0.06, size.z - 0.1), Vector3(table_x, 0.2, 0), ArcadeLook.mat(Color(0.25, 0.27, 0.3), "metal"))
		_:
			# Losa de hormigon con borde de franjas de peligro.
			_dress(table, ArcadeLook.mat(Color(0.66, 0.66, 0.64), "stone", 1.5))
			for i in 6:
				var c: Color = Color(0.95, 0.78, 0.1) if i % 2 == 0 else Color(0.1, 0.1, 0.1)
				var w: float = size.z / 6.0
				ArcadeLook.deco(self, "box", Vector3(0.02, 0.14, w), Vector3(table_x - size.x * 0.5 - 0.011, table_top - 0.1, -size.z * 0.5 + w * (float(i) + 0.5)), ArcadeLook.mat(c, "paint"))

func _build_theme() -> void:
	var bx: float = table_x + 12.0
	match theme:
		"castillo":
			ArcadeLook.light(self, Color(1.0, 0.82, 0.62), 1.15, Color(0.24, 0.32, 0.6), Color(0.95, 0.72, 0.5), 0.7, Vector3(-28, -55, 0))
			ArcadeLook.ground(self, Vector2(160, 120), Vector3(table_x, 0, 0), Color(0.5, 0.47, 0.42), "stone", 90.0)
			# Muralla con almenas, dos torres y estandartes.
			ArcadeLook.deco(self, "box", Vector3(1.2, 6.0, 40.0), Vector3(bx + 0.3, 3.0, 0), ArcadeLook.mat(Color(0.6, 0.57, 0.5), "stone", 6.0))
			for i in 14:
				ArcadeLook.deco(self, "box", Vector3(1.2, 0.8, 1.4), Vector3(bx + 0.3, 6.4, -19.0 + float(i) * 2.9), ArcadeLook.mat(Color(0.56, 0.53, 0.47), "stone"))
			for z in [-9.0, 9.0]:
				ArcadeLook.deco(self, "cyl", Vector3(2.2, 9.0, 2.4), Vector3(bx + 0.5, 4.5, z), ArcadeLook.mat(Color(0.58, 0.55, 0.49), "stone", 4.0))
				ArcadeLook.deco(self, "cyl", Vector3(0.01, 2.4, 2.6), Vector3(bx + 0.5, 10.2, z), ArcadeLook.mat(Color(0.5, 0.16, 0.14), "paint"))
				ArcadeLook.deco(self, "box", Vector3(0.05, 2.6, 1.2), Vector3(bx - 0.35, 3.8, z * 0.45), ArcadeLook.mat(Color(0.65, 0.1, 0.12), "paint"))
				ArcadeLook.deco(self, "box", Vector3(0.06, 0.5, 0.5), Vector3(bx - 0.38, 4.4, z * 0.45), ArcadeLook.glow(Color(1.0, 0.8, 0.2), 0.6))
			# Antorchas a los costados (llama que brilla, sin luz extra).
			for x in [4.0, 10.0, table_x + 4.0]:
				for z in [-7.0, 7.0]:
					ArcadeLook.deco(self, "cyl", Vector3(0.06, 1.6, 0.08), Vector3(x, 0.8, z), ArcadeLook.mat(Color(0.35, 0.24, 0.14), "wood"))
					ArcadeLook.deco(self, "sphere", Vector3(0.16, 0, 0), Vector3(x, 1.72, z), ArcadeLook.glow(Color(1.0, 0.55, 0.15), 2.5))
			ArcadeLook.billboard(self, "DEMOLICIÓN", Vector3(bx - 0.4, 3.0, 0), 5.6, 1.0, Color(0.3, 0.12, 0.08), Color(1.0, 0.85, 0.4))
		"almacen":
			ArcadeLook.light(self, Color(1.0, 0.96, 0.88), 0.95, Color(0.3, 0.34, 0.42), Color(0.55, 0.58, 0.62), 0.85, Vector3(-62, -20, 0))
			ArcadeLook.ground(self, Vector2(160, 120), Vector3(table_x, 0, 0), Color(0.46, 0.47, 0.48), "stone", 90.0)
			# Lineas amarillas de pasillo.
			for z in [-3.6, 3.6]:
				ArcadeLook.deco(self, "box", Vector3(table_x + 10.0, 0.01, 0.12), Vector3((table_x + 10.0) * 0.5 - 2.0, 0.006, z), ArcadeLook.mat(Color(0.95, 0.8, 0.1), "paint"))
			# Pared de ladrillo con portón y estanterias con cajones a los costados.
			ArcadeLook.deco(self, "box", Vector3(1.0, 8.0, 40.0), Vector3(bx + 0.3, 4.0, 0), ArcadeLook.mat(Color(0.6, 0.3, 0.22), "stone", 10.0))
			ArcadeLook.deco(self, "box", Vector3(0.1, 4.5, 6.0), Vector3(bx - 0.25, 2.25, 0), ArcadeLook.mat(Color(0.35, 0.42, 0.5), "metal", 3.0))
			for z in [-8.5, 8.5]:
				for x in [table_x - 4.0, table_x + 1.0, table_x + 6.0]:
					for lv in 3:
						ArcadeLook.deco(self, "box", Vector3(3.6, 0.08, 1.2), Vector3(x, 0.3 + float(lv) * 1.4, z), ArcadeLook.mat(Color(0.95, 0.5, 0.1), "metal"))
						ArcadeLook.deco(self, "box", Vector3(0.9, 0.8, 0.9), Vector3(x - 0.9, 0.74 + float(lv) * 1.4, z), ArcadeLook.mat(Color(0.66, 0.47, 0.26), "wood"))
						if lv != 1:
							ArcadeLook.deco(self, "box", Vector3(0.9, 0.8, 0.9), Vector3(x + 0.9, 0.74 + float(lv) * 1.4, z), ArcadeLook.mat(Color(0.62, 0.44, 0.24), "wood"))
					for sx in [-1.75, 1.75]:
						ArcadeLook.deco(self, "box", Vector3(0.08, 4.3, 0.08), Vector3(x + sx, 2.15, z), ArcadeLook.mat(Color(0.15, 0.3, 0.6), "metal"))
			# Lamparas colgantes (brillan; sin luces extra).
			for x in [4.0, 10.0, table_x]:
				ArcadeLook.deco(self, "cyl", Vector3(0.02, 2.0, 0.02), Vector3(x, 7.0, 0), ArcadeLook.mat(Color(0.2, 0.2, 0.2), "metal"))
				ArcadeLook.deco(self, "cyl", Vector3(0.12, 0.3, 0.45), Vector3(x, 5.9, 0), ArcadeLook.mat(Color(0.2, 0.22, 0.25), "metal"))
				ArcadeLook.deco(self, "sphere", Vector3(0.14, 0, 0), Vector3(x, 5.72, 0), ArcadeLook.glow(Color(1.0, 0.95, 0.75), 3.0))
			ArcadeLook.billboard(self, "DEMOLICIÓN", Vector3(bx - 0.3, 5.15, 0), 6.0, 1.0, Color(0.12, 0.12, 0.14), Color(0.95, 0.8, 0.1))
		_:
			ArcadeLook.light(self, Color(1.0, 0.94, 0.82), 1.1, Color(0.2, 0.4, 0.78), Color(0.72, 0.78, 0.86), 0.8)
			ArcadeLook.ground(self, Vector2(160, 120), Vector3(table_x, 0, 0), Color(0.5, 0.42, 0.32), "stone", 90.0)
			# Valla de chapa azul, grua, conos y vallas de obra.
			for i in 10:
				ArcadeLook.deco(self, "box", Vector3(0.12, 3.0, 3.9), Vector3(bx - 0.4, 1.5, -18.0 + float(i) * 4.0), ArcadeLook.mat(Color(0.12, 0.3, 0.62) if i % 2 == 0 else Color(0.14, 0.34, 0.68), "metal", 2.0))
			var crane_m := ArcadeLook.mat(Color(0.95, 0.75, 0.1), "metal")
			ArcadeLook.deco(self, "box", Vector3(0.9, 16.0, 0.9), Vector3(bx + 6.0, 8.0, 10.0), crane_m)
			ArcadeLook.deco(self, "box", Vector3(0.7, 0.7, 20.0), Vector3(bx + 6.0, 16.0, 3.0), crane_m)
			ArcadeLook.deco(self, "box", Vector3(1.6, 1.4, 1.6), Vector3(bx + 6.0, 16.0, 13.5), ArcadeLook.mat(Color(0.3, 0.3, 0.32), "metal"))
			ArcadeLook.deco(self, "cyl", Vector3(0.02, 7.0, 0.02), Vector3(bx + 6.0, 12.4, -5.0), ArcadeLook.mat(Color(0.15, 0.15, 0.15), "metal"))
			ArcadeLook.deco(self, "box", Vector3(0.8, 0.8, 0.8), Vector3(bx + 6.0, 8.6, -5.0), ArcadeLook.mat(Color(0.9, 0.2, 0.1), "metal"))
			for x in [3.0, 7.0, 11.0, table_x - 1.0]:
				for z in [-6.0, 6.0]:
					ArcadeLook.deco(self, "cyl", Vector3(0.03, 0.55, 0.2), Vector3(x, 0.28, z), ArcadeLook.mat(Color(1.0, 0.42, 0.08), "plastic"))
					ArcadeLook.deco(self, "cyl", Vector3(0.12, 0.08, 0.14), Vector3(x, 0.32, z), ArcadeLook.mat(Color(0.95, 0.95, 0.95), "paint"))
			for z in [-9.0, 9.0]:
				for i in 4:
					ArcadeLook.deco(self, "box", Vector3(2.2, 0.25, 0.06), Vector3(4.0 + float(i) * 4.0, 0.85, z), ArcadeLook.mat(Color(0.95, 0.2, 0.15) if i % 2 == 0 else Color(0.95, 0.95, 0.95), "paint"))
					ArcadeLook.deco(self, "box", Vector3(0.06, 1.0, 0.06), Vector3(3.0 + float(i) * 4.0, 0.5, z), ArcadeLook.mat(Color(0.3, 0.3, 0.3), "metal"))
			ArcadeLook.billboard(self, "DEMOLICIÓN", Vector3(bx - 0.6, 4.4, 0), 7.0, 1.2, Color(0.95, 0.75, 0.1), Color(0.1, 0.1, 0.1))

# --- Bloques ------------------------------------------------------------------------------------------------------------

## Encuadre: todos los objetivos y bloques que hay que cuidar.
func frame_points() -> Array:
	var out: Array = []
	for i in blocks.size():
		out.append((block_info[i]["start"] as Transform3D).origin + Vector3.UP * 0.3)
	return out

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0.0, ball.radius if ball != null else 0.11, float(def.get("ball_z", 0.0)))

func _aim_point(_s: int) -> Vector3:
	return Vector3(table_x, table_top + 0.8, 0.0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(table_x - 1.0, Vector2(10.0, 30.0), false, 4.0, 4.0, ball.radius)

## Lista de bloques del nivel: los sueltos y las figuras armadas, en coordenadas sobre la mesa (x hacia el fondo, y desde
## la tapa de la mesa, z al costado). Cada figura pasa "material" y "look" a sus bloques.
func layout() -> Array:
	var out: Array = []
	for b in def.get("blocks", []):
		out.append(b)
	for f in def.get("figures", []):
		var fd: Dictionary = f
		var size: Vector3 = BotonCaida._vec(fd.get("size", [0.45, 0.45, 0.45]))
		var at: Vector3 = BotonCaida._vec(fd.get("at", [0, 0, 0]))
		var kind: String = String(fd.get("kind", "target"))
		var extra := {}
		for k in ["material", "look", "mass"]:
			if fd.has(k):
				extra[k] = fd[k]
		if not extra.has("mass") and not extra.has("material"):
			extra["mass"] = 1.2
		var add := func(pos: Vector3, sz: Vector3, kd: String) -> void:
			var e := {"pos": [pos.x, pos.y, pos.z], "size": [sz.x, sz.y, sz.z], "kind": kd}
			e.merge(extra)
			out.append(e)
		match String(fd.get("type", "tower")):
			"tower":
				for i in int(fd.get("n", 5)):
					add.call(Vector3(at.x, size.y * (float(i) + 0.5), at.z), size, kind)
			"pyramid":
				var rows: int = int(fd.get("n", 3))
				for r in rows:
					for k in rows - r:
						var z: float = at.z + (float(k) - float(rows - r - 1) * 0.5) * (size.z + 0.02)
						add.call(Vector3(at.x, size.y * (float(r) + 0.5), z), size, kind)
			"wall":
				var cols: int = int(fd.get("cols", 4))
				for r in int(fd.get("rows", 3)):
					for k in cols:
						var z2: float = at.z + (float(k) - float(cols - 1) * 0.5) * (size.z + 0.02)
						add.call(Vector3(at.x, size.y * (float(r) + 0.5), z2), size, kind)
			"dominoes":
				var n: int = int(fd.get("n", 6))
				var step: Vector3 = BotonCaida._vec(fd.get("step", [0.0, 0.0, 0.55]))
				for i in n:
					var p: Vector3 = at + step * float(i)
					add.call(Vector3(p.x, size.y * 0.5, p.z), size, kind)
			"jenga":
				# Pisos de 3 tablones (size = largo, alto, ancho), cruzados piso por medio. "top" pisos de arriba son de
				# "top_kind" (los objetivos sobre la torre).
				var floors: int = int(fd.get("n", 8))
				var top: int = int(fd.get("top", 2))
				for fl in floors:
					var kd: String = String(fd.get("top_kind", kind)) if fl >= floors - top else kind
					var y: float = size.y * (float(fl) + 0.5)
					for k in 3:
						var off: float = (float(k) - 1.0) * (size.z + 0.01)
						if fl % 2 == 0:
							add.call(Vector3(at.x + off, y, at.z), Vector3(size.z, size.y, size.x), kd)
						else:
							add.call(Vector3(at.x, y, at.z + off), Vector3(size.x, size.y, size.z), kd)
			"house":
				# Casita: paredes de ladrillos (frente con puerta, fondo y costados entre los dos, sin encimarse), losa de
				# techo y cajas arriba ("roof_kind").
				var dpt: float = float(fd.get("depth", 1.1))
				var rows2: int = int(fd.get("rows", 3))
				var bs: Vector3 = size
				var nz: int = int(fd.get("bricks", 4))
				var zext: float = (float(nz) * (bs.z + 0.02) - 0.02) * 0.5
				var nx: int = maxi(int(floor((dpt - bs.x - 0.04) / (bs.z + 0.02))), 1)
				for r in rows2:
					var y2: float = bs.y * (float(r) + 0.5)
					for k in nz:
						var z3: float = at.z + (float(k) - float(nz - 1) * 0.5) * (bs.z + 0.02)
						if r > 0 or absf(z3 - at.z) > bs.z * 0.6:
							add.call(Vector3(at.x - dpt * 0.5, y2, z3), bs, kind)
						add.call(Vector3(at.x + dpt * 0.5, y2, z3), bs, kind)
					for k in nx:
						var x3: float = at.x + (float(k) - float(nx - 1) * 0.5) * (bs.z + 0.02)
						for sz in [-1.0, 1.0]:
							add.call(Vector3(x3, y2, at.z + sz * (zext - bs.x * 0.5)), Vector3(bs.z, bs.y, bs.x), kind)
				var roof_y: float = bs.y * float(rows2) + 0.052
				add.call(Vector3(at.x, roof_y, at.z), Vector3(dpt + bs.x + 0.1, 0.1, zext * 2.0 + 0.1), kind)
				var rk: String = String(fd.get("roof_kind", "target"))
				for z4 in [-zext * 0.5, zext * 0.5]:
					out.append({"pos": [at.x, roof_y + 0.252, at.z + z4], "size": [0.35, 0.4, 0.35], "kind": rk, "mass": float(fd.get("roof_mass", 0.5)), "look": "crate"})
			"colonnade":
				# Columnas con dinteles encima; "top_kind" son las piezas sobre los dinteles.
				var cols2: int = int(fd.get("cols", 3))
				var gap: float = float(fd.get("gap", 1.0))
				var ch: float = size.y
				for k in cols2:
					var z5: float = at.z + (float(k) - float(cols2 - 1) * 0.5) * gap
					add.call(Vector3(at.x, ch * 0.5, z5), size, kind)
				for k in cols2 - 1:
					var zm: float = at.z + (float(k) - float(cols2 - 2) * 0.5) * gap
					# Cada dintel apoya en media tapa de cada columna (de centro a centro, sin encimarse con el vecino).
					add.call(Vector3(at.x, ch + 0.062, zm), Vector3(size.x + 0.05, 0.12, gap - 0.02), kind)
					var e3 := {"pos": [at.x, ch + 0.124 + 0.2, zm], "size": [0.3, 0.4, 0.3], "kind": String(fd.get("top_kind", "target")), "mass": float(fd.get("top_mass", 0.5))}
					if fd.has("top_look"):
						e3["look"] = fd["top_look"]
					out.append(e3)
	return out

func _spawn_blocks() -> void:
	for b in blocks:
		if is_instance_valid(b):
			_blocks_root.remove_child(b)
			b.queue_free()
	for s in _shards:
		if is_instance_valid(s):
			(s as Node).queue_free()
	_shards.clear()
	blocks.clear()
	block_info.clear()
	broken_count = 0
	for e in layout():
		var ed: Dictionary = e
		var size: Vector3 = BotonCaida._vec(ed.get("size", [0.45, 0.45, 0.45]))
		var local: Vector3 = BotonCaida._vec(ed.get("pos", [0, 0.25, 0]))
		var kind: String = String(ed.get("kind", "target"))
		var mat_id: String = String(ed.get("material", "wood"))
		var md: Dictionary = MATERIALS.get(mat_id, MATERIALS["wood"])
		var look_id: String = String(ed.get("look", mat_id))
		var barrel: bool = String(ed.get("shape", "box")) == "barrel"
		var rb := RigidBody3D.new()
		var vol: float = (PI * size.x * size.x * 0.25 * size.y) if barrel else (size.x * size.y * size.z)
		# Sin "mass": por volumen y material; los bloques viejos sin material conservan su 1,2 kg medido.
		rb.mass = float(ed["mass"]) if ed.has("mass") else (maxf(vol * BASE_DENSITY * float(md["density"]), 0.12) if ed.has("material") else 1.2)
		rb.collision_layer = Ball.LAYER_WORLD
		rb.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
		rb.can_sleep = true
		var pm := PhysicsMaterial.new()
		pm.friction = float(md["friction"])
		pm.bounce = float(md["bounce"])
		rb.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var mi := MeshInstance3D.new()
		if barrel:
			# Barril: cilindro acostado o parado (rueda y se desparrama distinto que una caja).
			var cyl := CylinderShape3D.new()
			cyl.radius = size.x * 0.5
			cyl.height = size.y
			cs.shape = cyl
			var cm := CylinderMesh.new()
			cm.top_radius = cyl.radius
			cm.bottom_radius = cyl.radius
			cm.height = size.y
			cm.radial_segments = 16
			mi.mesh = cm
		else:
			var bs := BoxShape3D.new()
			bs.size = size
			cs.shape = bs
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
		rb.add_child(cs)
		mi.material_override = block_material(look_id, kind)
		rb.add_child(mi)
		_trim(rb, look_id, size, barrel, kind)
		if float(md["break"]) > 0.0:
			rb.contact_monitor = true
			rb.max_contacts_reported = 4
		_blocks_root.add_child(rb)
		# Apoyados (con 2 mm de aire: se asientan sin saltar).
		var world := Vector3(table_x + local.x, table_top + local.y + 0.002, local.z)
		rb.global_position = world
		var idx: int = blocks.size()
		blocks.append(rb)
		block_info.append({"kind": kind, "start": rb.global_transform, "mat": mat_id, "broken": false, "pv": Vector3.ZERO})
		if float(md["break"]) > 0.0:
			rb.body_entered.connect(_on_block_hit.bind(idx))

## Material de un bloque: el del material (textura y terminacion) teñido segun su papel: los objetivos en rojo, los que
## no hay que tocar en blanco, los neutros con su color natural. El vidrio es translucido.
static func block_material(look_id: String, kind: String) -> StandardMaterial3D:
	var md: Dictionary = MATERIALS.get(look_id, MATERIALS["wood"])
	var base: Color = md["color"]
	if KIND_TINT.has(kind):
		base = base.lerp(KIND_TINT[kind], 0.7 if look_id != "glass" else 0.45)
	if String(md["finish"]) == "glass":
		var g := StandardMaterial3D.new()
		g.albedo_color = Color(base.r, base.g, base.b, 0.42)
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.roughness = 0.05
		g.metallic_specular = 1.0
		g.rim_enabled = true
		g.rim = 0.6
		return g
	return ArcadeLook.mat(base, String(md["finish"]))

## Detalles visuales por material: tablones del cajon, aros del barril, junta del ladrillo, marco del vidrio.
func _trim(rb: RigidBody3D, look_id: String, size: Vector3, barrel: bool, kind: String) -> void:
	var dark := ArcadeLook.mat(Color(0.3, 0.2, 0.12), "wood")
	if barrel:
		for y in [-size.y * 0.32, size.y * 0.32]:
			var ring := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = size.x * 0.5 + 0.01
			cm.bottom_radius = cm.top_radius
			cm.height = 0.05
			cm.radial_segments = 16
			ring.mesh = cm
			ring.material_override = ArcadeLook.mat(Color(0.3, 0.3, 0.32), "metal")
			ring.position = Vector3(0, y, 0)
			rb.add_child(ring)
		return
	match look_id:
		"crate":
			# Listones cruzados en las dos caras grandes (a la vista desde el tiro: la cara -X).
			for sgn in [-1.0, 1.0]:
				var a := MeshInstance3D.new()
				var am := BoxMesh.new()
				am.size = Vector3(0.012, size.y * 0.16, size.z * 1.0)
				a.mesh = am
				a.material_override = dark
				a.position = Vector3(sgn * (size.x * 0.5 + 0.006), 0, 0)
				a.rotation = Vector3(atan2(size.y, size.z) * sgn, 0, 0)
				rb.add_child(a)
		"glass":
			var fr := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(size.x + 0.01, 0.04, size.z + 0.01)
			fr.mesh = fm
			fr.material_override = ArcadeLook.mat(Color(0.8, 0.82, 0.86) if kind != "target" else Color(0.85, 0.2, 0.15), "metal")
			fr.position = Vector3(0, size.y * 0.5 - 0.02, 0)
			rb.add_child(fr)
			var fr2 := fr.duplicate() as MeshInstance3D
			fr2.position = Vector3(0, -size.y * 0.5 + 0.02, 0)
			rb.add_child(fr2)
		"brick":
			if size.y >= 0.3:
				var j := MeshInstance3D.new()
				var jm := BoxMesh.new()
				jm.size = Vector3(size.x + 0.006, 0.02, size.z + 0.006)
				j.mesh = jm
				j.material_override = ArcadeLook.mat(Color(0.8, 0.78, 0.72), "stone")
				rb.add_child(j)

## Choque sobre un bloque rompible (vidrio): con la velocidad relativa de ANTES del choque por encima de su umbral, se
## rompe en esquirlas.
func _on_block_hit(body: Node, i: int) -> void:
	if i >= block_info.size() or bool(block_info[i]["broken"]):
		return
	var e: Dictionary = block_info[i]
	var other_v := Vector3.ZERO
	if body == ball:
		other_v = prev_velocity()
	elif body is RigidBody3D:
		var j: int = blocks.find(body as RigidBody3D)
		other_v = (block_info[j]["pv"] as Vector3) if j >= 0 else (body as RigidBody3D).linear_velocity
	var rel: float = (other_v - (e["pv"] as Vector3)).length()
	if rel >= float(MATERIALS[String(e["mat"])]["break"]):
		shatter(i)

func _on_ball_body(body: Node) -> void:
	if body is RigidBody3D:
		var i: int = blocks.find(body as RigidBody3D)
		if i >= 0 and blocks[i].contact_monitor:
			_on_block_hit(ball, i)

## Rompe el bloque i: el cuerpo deja de existir para la fisica (sin colision, congelado e invisible) y en su lugar
## quedan esquirlas (cuerpos rigidos chicos) que heredan su velocidad, con un poco de dispersion.
func shatter(i: int) -> void:
	var b: RigidBody3D = blocks[i]
	var e: Dictionary = block_info[i]
	if bool(e["broken"]):
		return
	e["broken"] = true
	broken_count += 1
	var xf: Transform3D = b.global_transform
	var v: Vector3 = b.linear_velocity
	var size: Vector3 = ((b.get_child(0) as CollisionShape3D).shape as BoxShape3D).size if (b.get_child(0) as CollisionShape3D).shape is BoxShape3D else Vector3(0.3, 0.3, 0.3)
	b.set_deferred("freeze", true)
	(b.get_child(0) as CollisionShape3D).set_deferred("disabled", true)
	b.visible = false
	var m: StandardMaterial3D = block_material(String(e["mat"]), String(e["kind"]))
	var nz: int = 3
	var ny: int = 2
	var piece := Vector3(size.x, size.y / float(ny), size.z / float(nz)) * 0.9
	for a in ny:
		for c in nz:
			var s := RigidBody3D.new()
			s.mass = 0.06
			s.collision_layer = Ball.LAYER_WORLD
			s.collision_mask = Ball.LAYER_WORLD
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = piece
			cs.shape = bs
			s.add_child(cs)
			var mi := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(piece.z, piece.y, piece.x)
			mi.mesh = pm
			mi.rotation_degrees = Vector3(0, 90, 0)
			mi.material_override = m
			s.add_child(mi)
			_blocks_root.call_deferred("add_child", s)
			var lp := Vector3(0, (float(a) - 0.5) * size.y / float(ny), (float(c) - 1.0) * size.z / float(nz))
			s.set_deferred("global_transform", Transform3D(xf.basis, xf * lp))
			var spread := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.0, 1.0), rng.randf_range(-0.8, 0.8))
			s.set_deferred("linear_velocity", v + spread)
			s.set_deferred("angular_velocity", Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6)))
			_shards.append(s)
	while _shards.size() > MAX_SHARDS:
		var old: Node = _shards.pop_front()
		if is_instance_valid(old):
			old.queue_free()

func _level_step(_delta: float) -> void:
	for i in blocks.size():
		if blocks[i].contact_monitor:
			block_info[i]["pv"] = blocks[i].linear_velocity

func reset_level() -> void:
	_spawn_blocks()
	super.reset_level()

## El bloque i ya cayo de la mesa (su centro bajo la tapa), quedo volcado (su eje vertical a mas de TILT_DOWN grados), se
## rompio o (con "down_h") quedo por debajo de esa altura sobre la mesa. Bajar un piso dentro de la torre NO cuenta
## (medido: al sacar el de abajo, los de arriba bajan 0,45 m y siguen en pie).
func is_down(i: int) -> bool:
	if bool(block_info[i]["broken"]):
		return true
	var b: RigidBody3D = blocks[i]
	if b.global_position.y < table_top - 0.05:
		return true
	if down_h > 0.0 and b.global_position.y < table_top + down_h:
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
	for i in blocks.size():
		var b: RigidBody3D = blocks[i]
		if not bool(block_info[i]["broken"]) and not b.sleeping and b.linear_velocity.length() > SETTLED:
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
	if broken_count > 0:
		sub += " · %d vidrio(s) roto(s)" % broken_count
	if keep_down > 0:
		sub += " · tiraste %d blanco(s)" % keep_down
	if left == 0:
		return ["¡TODO ABAJO!", Color(0.35, 1.0, 0.45), sub]
	return ["%d derribados" % count("target", true), Color(1.0, 0.85, 0.35), sub]

func _refresh_score() -> void:
	hud.set_score_text("Objetivos %d / %d · tiros %d / %d" % [count("target", true), total("target"), int(shots[0]), shots_max])
