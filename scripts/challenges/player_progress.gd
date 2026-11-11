class_name PlayerProgress
extends RefCounted
## Progreso del jugador (fases 3, 5 y 8 del plan): record y medalla de cada ejercicio y desafio, experiencia y nivel,
## desbloqueos y recompensas cosmeticas (sin ventajas de juego). Se guarda en user://progress.cfg. La practica libre no
## lo toca. Sin tienda ni pagos.

const PATH := "user://progress.cfg"

static var path: String = PATH
static var _loaded: bool = false
static var xp: int = 0
## id -> {"best": puntos, "medal": 0..3, "plays": veces}
static var records: Dictionary = {}
static var cosmetics: Array = []

static func load_progress(force: bool = false) -> void:
	if _loaded and not force:
		return
	_loaded = true
	xp = 0
	records = {}
	cosmetics = []
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	xp = int(cfg.get_value("player", "xp", 0))
	records = cfg.get_value("player", "records", {})
	cosmetics = cfg.get_value("player", "cosmetics", [])

static func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "xp", xp)
	cfg.set_value("player", "records", records)
	cfg.set_value("player", "cosmetics", cosmetics)
	cfg.save(path)

## Para las pruebas: progreso en otro archivo, vacio.
static func use_path(p: String) -> void:
	path = p
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	load_progress(true)

static func best(id: String) -> int:
	load_progress()
	return int((records.get(id, {}) as Dictionary).get("best", 0))

static func medal(id: String) -> int:
	load_progress()
	return int((records.get(id, {}) as Dictionary).get("medal", 0))

## Nivel del jugador: cada nivel pide 150 XP mas que el anterior (1: 0, 2: 150, 3: 450, 4: 900...).
static func level_for(total_xp: int) -> int:
	var lv: int = 1
	var need: int = 150
	var acc: int = 0
	while total_xp >= acc + need:
		acc += need
		lv += 1
		need += 150
	return lv

static func level() -> int:
	load_progress()
	return level_for(xp)

## Clave del record: ejercicio de la Academia (id) o desafio de la Arena en una dificultad (id@d).
static func key(def: Dictionary, difficulty: int = -1) -> String:
	return String(def["id"]) if String(def.get("group", "")) == "academia" or difficulty < 0 else "%s@%d" % [def["id"], difficulty]

## Academia: el nivel 1 esta abierto; el nivel N se abre con bronce o mas en la mitad (redondeando arriba) de los
## ejercicios del nivel N-1 (no obliga a repetir uno hasta sacarlo). Arena: siempre abierta (ver difficulty_unlocked).
static func is_unlocked(def: Dictionary) -> bool:
	load_progress()
	if String(def.get("group", "")) != "academia":
		return true
	var lv: int = int(def.get("level", 1))
	if lv <= 1:
		return true
	var prev: Array = ChallengeCatalog.level_defs(lv - 1)
	var bronzes: int = 0
	for e in prev:
		if medal(String(e["id"])) >= 1:
			bronzes += 1
	return bronzes >= int(ceil(prev.size() / 2.0))

## Arena: Facil siempre; cada dificultad se abre con bronce en la anterior de ese desafio.
static func difficulty_unlocked(def: Dictionary, difficulty: int) -> bool:
	load_progress()
	return difficulty <= 0 or medal(key(def, difficulty - 1)) >= 1

## Registra un resultado (no en practica libre). Devuelve {new_best, prev_best, prev_medal, xp_gained, cosmetic}.
## Experiencia: la mejora sobre el record (puntos / 10) y un premio la primera vez que se gana cada medalla.
static func record(def: Dictionary, score: int, medal_won: int, difficulty: int = -1) -> Dictionary:
	load_progress()
	var id: String = key(def, difficulty)
	var r: Dictionary = records.get(id, {"best": 0, "medal": 0, "plays": 0})
	var prev_best: int = int(r["best"])
	var prev_medal: int = int(r["medal"])
	var gained: int = 0
	if score > prev_best:
		gained += int((score - prev_best) / 10)
	var reward: Dictionary = def.get("reward", {})
	for m in range(prev_medal + 1, medal_won + 1):
		gained += int(reward.get("xp", 50)) * m
	var cosmetic: String = ""
	if medal_won >= 3 and prev_medal < 3 and String(reward.get("cosmetic", "")) != "":
		cosmetic = String(reward["cosmetic"])
		if not cosmetics.has(cosmetic):
			cosmetics.append(cosmetic)
	r["best"] = maxi(prev_best, score)
	r["medal"] = maxi(prev_medal, medal_won)
	r["plays"] = int(r["plays"]) + 1
	records[id] = r
	xp += gained
	save_progress()
	# Al servidor: que se jugo y con que medalla (el monto lo decide el servidor, con topes diarios).
	OnlineHooks.reward("academia" if String(def.get("group", "")) == "academia" else "arcade",
		{"id": id, "medal": medal_won, "score": score})
	return {"new_best": score > prev_best, "prev_best": prev_best, "prev_medal": prev_medal, "xp_gained": gained, "cosmetic": cosmetic}
