class_name MinigameCatalog
extends RefCounted
## Catalogo de los minijuegos arcade jugables (datos en resources/minigames/minigames.json). Cada minijuego tiene id,
## titulo, escena, estado (los del roadmap: Idea, Diseñado, En desarrollo, Implementado, Probado, Pendiente de balance) y
## sus niveles; cada nivel es un diccionario con id unico ("mg_<juego>_<n>"), grupo "arcade", objetivo breve, medallas
## [bronce, plata, oro] y los datos de su geometria. Los records y medallas van a PlayerProgress (como la Academia).
## El catalogo completo de 43 ideas vive en docs/AAA_ROADMAP.md; aca solo estan los que se pueden jugar.

const PATH := "res://resources/minigames/minigames.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("No se pudo abrir %s" % PATH)
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		_data = parsed if parsed is Dictionary else {}
	return _data

static func games() -> Array:
	return data().get("games", [])

static func game(id: String) -> Dictionary:
	for g in games():
		if String(g["id"]) == id:
			return g
	return {}

## Niveles de un minijuego, con los datos comunes del juego (grupo, juego, escena) ya puestos.
static func levels(game_id: String) -> Array:
	var g: Dictionary = game(game_id)
	var out: Array = []
	var n: int = 0
	for l in g.get("levels", []):
		n += 1
		var d: Dictionary = (l as Dictionary).duplicate(true)
		d["group"] = "arcade"
		d["game"] = game_id
		d["scene"] = g["scene"]
		d["level"] = n
		if not d.has("id"):
			d["id"] = "mg_%s_%d" % [game_id, n]
		out.append(d)
	return out

static func level(game_id: String, n: int) -> Dictionary:
	var ls: Array = levels(game_id)
	return ls[n - 1] if n >= 1 and n <= ls.size() else {}

static func next_level(def: Dictionary) -> Dictionary:
	return level(String(def.get("game", "")), int(def.get("level", 0)) + 1)

## Un nivel se abre con bronce o mas en el anterior del mismo minijuego (el primero siempre).
static func is_unlocked(def: Dictionary) -> bool:
	var n: int = int(def.get("level", 1))
	if n <= 1:
		return true
	var prev: Dictionary = level(String(def["game"]), n - 1)
	return prev.is_empty() or PlayerProgress.medal(String(prev["id"])) >= 1

## Abre un nivel (cambia de escena).
static func start(tree: SceneTree, def: Dictionary) -> void:
	Minigame.next_def = def
	tree.change_scene_to_file(String(def["scene"]))
