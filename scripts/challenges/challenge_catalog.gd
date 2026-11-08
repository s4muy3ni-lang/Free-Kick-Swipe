class_name ChallengeCatalog
extends RefCounted
## Catalogo de la Academia de tiros (8 niveles de ejercicios) y de la Arena de desafios (precision, objetos, distancia,
## especiales): resources/challenges/challenges.json. Todo es configuracion sobre los MISMOS sistemas del juego (disparo
## por trazo, fisica de la pelota, arquero, barrera, red, animaciones): no hay un sistema por desafio.
##
## Campos de cada definicion:
##   id, group ("academia" | "arena"), level/area (academia) o category (arena), title, explain (explicacion), spot
##   [metros desde la linea, z], attempts, needed (aciertos para completarlo), keeper (-1 sin arquero, 0-4 dificultad),
##   wall ("auto" o cantidad), min_speed (m/s, 0 = no pide), streak_needed (aciertos seguidos), rule ("targets" | "sequence"
##   | "objects"), targets (zone, hoop, post_left, post_right, crossbar, goal; con move/blink/bounce), objects (cones,
##   bottles, blocks, tower), obstacles (pole, mannequins), medals [bronce, plata, oro] (puntos en Facil), reward {xp,
##   cosmetic}.

const PATH := "res://resources/challenges/challenges.json"
const TARGET_TYPES := ["zone", "hoop", "post_left", "post_right", "crossbar", "goal"]
const OBJECT_TYPES := ["cones", "bottles", "blocks", "tower"]
const OBSTACLE_TYPES := ["pole", "mannequins"]
const RULES := ["targets", "sequence", "objects"]
## Arena: la dificultad cambia el tamaño de los blancos, los intentos, el arquero y la velocidad de lo que se mueve.
const ARENA_TARGET_SCALE := [1.3, 1.0, 0.82, 0.68, 0.55]
const ARENA_ATTEMPTS_DELTA := [2, 0, 0, -1, -2]
const ARENA_KEEPER := [-1, -1, 0, 1, 3]
const ARENA_MOVE_SPEED := [0.75, 1.0, 1.2, 1.4, 1.65]

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("ChallengeCatalog: no se pudo abrir %s" % PATH)
			return {"academia": [], "arena": []}
		_data = JSON.parse_string(f.get_as_text())
		for k in ["academia", "arena"]:
			for d in _data.get(k, []):
				_fill_defaults(d)
	return _data

static func _fill_defaults(d: Dictionary) -> void:
	if not d.has("rule"):
		d["rule"] = "targets"
	if not d.has("keeper"):
		d["keeper"] = -1
	if not d.has("wall"):
		d["wall"] = 0
	if not d.has("min_speed"):
		d["min_speed"] = 0.0
	if not d.has("streak_needed"):
		d["streak_needed"] = 0
	for k in ["targets", "objects", "obstacles"]:
		if not d.has(k):
			d[k] = []
	var n: int = int(d.get("needed", 1))
	if not d.has("medals"):
		# Bronce: los aciertos que pide; plata y oro: con precision, racha o aciertos de mas.
		d["medals"] = [n * 110, n * 165, n * 230]
	if not d.has("reward"):
		d["reward"] = {"xp": 40 + 10 * int(d.get("level", 2)), "cosmetic": ""}

static func academia() -> Array:
	return data().get("academia", [])

static func arena() -> Array:
	return data().get("arena", [])

static func by_id(id: String) -> Dictionary:
	for d in academia() + arena():
		if String(d["id"]) == id:
			return d
	return {}

static func level_defs(level: int) -> Array:
	return academia().filter(func(d: Dictionary) -> bool: return int(d.get("level", 0)) == level)

static func levels() -> Array:
	var out: Array = []
	for d in academia():
		if not out.has(int(d["level"])):
			out.append(int(d["level"]))
	return out

static func level_area(level: int) -> String:
	var l: Array = level_defs(level)
	return String(l[0].get("area", "")) if not l.is_empty() else ""

static func categories() -> Array:
	var out: Array = []
	for d in arena():
		if not out.has(String(d["category"])):
			out.append(String(d["category"]))
	return out

static func category_defs(cat: String) -> Array:
	return arena().filter(func(d: Dictionary) -> bool: return String(d.get("category", "")) == cat)

## Desafio de la Arena en una dificultad (0 Facil .. 4 Extremo): copia con blancos mas chicos o mas grandes, intentos,
## arquero y movimiento segun la dificultad. La Academia no cambia (sus ejercicios ya estan graduados por nivel).
static func at_difficulty(def: Dictionary, difficulty: int) -> Dictionary:
	var d: Dictionary = def.duplicate(true)
	if String(d.get("group", "")) != "arena":
		return d
	var i: int = clampi(difficulty, 0, 4)
	var s: float = ARENA_TARGET_SCALE[i]
	for t in d["targets"]:
		for k in ["w", "h", "r"]:
			if t.has(k):
				t[k] = float(t[k]) * s
		if String(t["type"]) == "zone":
			# Agrandado (Facil): sin salirse de la boca del arco.
			t["w"] = minf(float(t["w"]), 2.0 * (3.66 - absf(float(t["z"]))))
			t["h"] = minf(float(t["h"]), 2.0 * minf(float(t["y"]), 2.44 - float(t["y"])))
		if t.has("move"):
			t["move"]["period"] = float(t["move"]["period"]) / ARENA_MOVE_SPEED[i]
	d["attempts"] = maxi(int(d["attempts"]) + ARENA_ATTEMPTS_DELTA[i], int(d.get("needed", 1)))
	if int(d.get("keeper", -1)) < 0 and ARENA_KEEPER[i] >= 0 and d["rule"] != "objects" and _has_goal_like(d):
		d["keeper"] = ARENA_KEEPER[i]
	d["difficulty"] = i
	return d

static func _has_goal_like(d: Dictionary) -> bool:
	for t in d["targets"]:
		if String(t["type"]) in ["goal", "zone"]:
			return true
	return false

## Problemas de una definicion (vacio = valida). Lo usan las pruebas para todo el catalogo.
static func problems(d: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in ["id", "title", "explain", "spot", "attempts", "needed"]:
		if not d.has(k):
			out.append("falta %s" % k)
	if not out.is_empty():
		return out
	var spot: Array = d["spot"]
	if float(spot[0]) < 9.0 or float(spot[0]) > 45.0 or absf(float(spot[1])) > 30.0:
		out.append("punto fuera de rango %s" % str(spot))
	if int(d["needed"]) > int(d["attempts"]) and String(d["rule"]) != "objects":
		out.append("pide mas aciertos que intentos")
	if not String(d["rule"]) in RULES:
		out.append("regla desconocida %s" % d["rule"])
	var m: Array = d["medals"]
	if m.size() != 3 or not (float(m[0]) < float(m[1]) and float(m[1]) < float(m[2])):
		out.append("medallas no crecientes %s" % str(m))
	if d["targets"].is_empty() and d["objects"].is_empty():
		out.append("sin blancos ni objetos")
	for t in d["targets"]:
		if not String(t.get("type", "")) in TARGET_TYPES:
			out.append("blanco desconocido %s" % str(t))
		if String(t.get("type", "")) == "zone":
			if float(t["w"]) <= 0.2 or float(t["h"]) <= 0.2 or absf(float(t["z"])) + float(t["w"]) * 0.5 > 3.66 + 0.05 \
					or float(t["y"]) + float(t["h"]) * 0.5 > 2.44 + 0.05 or float(t["y"]) - float(t["h"]) * 0.5 < -0.05:
				out.append("recuadro fuera del arco %s" % str(t))
	for o in d["objects"]:
		if not String(o.get("type", "")) in OBJECT_TYPES:
			out.append("objeto desconocido %s" % str(o))
	for o in d["obstacles"]:
		if not String(o.get("type", "")) in OBSTACLE_TYPES:
			out.append("obstaculo desconocido %s" % str(o))
	if String(d["rule"]) == "objects" and d["objects"].is_empty():
		out.append("regla de objetos sin objetos")
	return out
