class_name PlayerCustom
extends RefCounted
## Personalizacion del jugador del usuario (etapa A1 del plan de finalizacion): uniforme (camiseta, short, medias,
## botines), piel y pelo (parametros del shader del kit: no se tocan los recursos originales), numero en la espalda
## (Label3D que sigue la columna del esqueleto), estilo de golpeo, carrera de aproximacion, que hace despues del tiro y
## festejo elegido. Los estilos SOLO cambian la eleccion del clip de golpeo (pesos sobre ShotCatalog): la fisica del tiro
## (velocidad, efecto, destino) no cambia. Los cosmeticos bloqueados se abren con logros (PlayerProgress.cosmetics).
## Se guarda en user://custom.cfg y se aplica de verdad: en el menu, en penales y tiros libres (tirador y arquero del
## usuario) y en los minijuegos.

const PATH := "user://custom.cfg"
static var path: String = PATH
static var _loaded: bool = false

## Paletas (nombre -> color). Los dos ultimos botines y los dos ultimos festejos se abren con logros.
const JERSEY_NAMES := ["Azul", "Rojo", "Blanco", "Negro", "Celeste", "Amarillo", "Violeta", "Verde", "Naranja", "Rosa"]
const JERSEYS: Array[Color] = [Color(0.10, 0.32, 0.86), Color(0.82, 0.08, 0.10), Color(0.93, 0.93, 0.95), Color(0.07, 0.07, 0.09),
	Color(0.45, 0.75, 0.98), Color(0.95, 0.85, 0.12), Color(0.45, 0.16, 0.65), Color(0.10, 0.55, 0.22), Color(0.95, 0.45, 0.08), Color(0.95, 0.55, 0.75)]
const SHORT_NAMES := ["Blanco", "Negro", "Azul", "Rojo", "Amarillo", "Verde", "Gris", "Celeste"]
const SHORTS: Array[Color] = [Color(0.95, 0.95, 0.97), Color(0.06, 0.06, 0.08), Color(0.10, 0.32, 0.86), Color(0.82, 0.08, 0.10),
	Color(0.95, 0.85, 0.12), Color(0.10, 0.55, 0.22), Color(0.45, 0.47, 0.52), Color(0.45, 0.75, 0.98)]
const SOCK_NAMES := JERSEY_NAMES
const SOCKS: Array[Color] = JERSEYS
const BOOT_NAMES := ["Naranja", "Negro", "Blanco", "Azul", "Rojo", "Verde", "Dorados", "Cromados"]
const BOOTS: Array[Color] = [Color(0.95, 0.55, 0.08), Color(0.04, 0.04, 0.05), Color(0.93, 0.93, 0.95), Color(0.12, 0.35, 0.9),
	Color(0.85, 0.1, 0.1), Color(0.1, 0.7, 0.3), Color(1.0, 0.78, 0.12), Color(0.75, 0.85, 0.95)]
## Cosmetico que abre cada botin (vacio = siempre abierto).
const BOOT_LOCKS := ["", "", "", "", "", "", "botines_oro", "botines_cromo"]
const SKIN_NAMES := ["1", "2", "3", "4", "5", "6"]
const SKINS: Array[Color] = [Color(0.85, 0.66, 0.5), Color(0.78, 0.58, 0.45), Color(0.7, 0.5, 0.38), Color(0.62, 0.40, 0.29),
	Color(0.48, 0.3, 0.2), Color(0.35, 0.22, 0.15)]
const HAIR_NAMES := ["Negro", "Castaño", "Rubio", "Pelirrojo", "Gris", "Azul"]
const HAIRS: Array[Color] = [Color(0.06, 0.05, 0.05), Color(0.26, 0.15, 0.07), Color(0.78, 0.65, 0.3), Color(0.55, 0.2, 0.08),
	Color(0.6, 0.6, 0.62), Color(0.15, 0.3, 0.8)]

enum Style { NATURAL, POTENTE, COLOCADO, CON_EFECTO }
const STYLE_NAMES := ["Natural", "Potente", "Colocado", "Con efecto"]
const RUN_NAMES := ["Normal", "Corta"]
const FOLLOW_NAMES := ["Mira la pelota", "Acompaña el tiro"]
## Festejos: 0 = aleatorio; 1.. = clips fijos del banco (ver celebrations()). Los dos ultimos se abren con logros.
const CELEB_LOCKS := ["", "", "", "", "festejo_5", "festejo_6"]

static var jersey: int = 0
static var shorts: int = 0
static var socks: int = 0
static var boots: int = 0
static var skin: int = 3
static var hair: int = 0
static var number: int = 10
static var style: int = Style.NATURAL
static var run_style: int = 0
static var follow_style: int = 0
static var celebration: int = 0
## Diseños (ecosistema online): camiseta 0..6 y su segundo color, short 0..2, medias 0..2 y altura 0..2 (ver json_kit).
static var jersey_pattern: int = 0
static var jersey2: int = 2
static var shorts_pattern: int = 0
static var socks_pattern: int = 0
static var sock_height: int = 0
## Objetos equipados del catalogo del servidor (balon, festejo, estilo de numero).
static var ball_item: String = "ball_clasico"
static var number_style: String = "num_clasico"
const JERSEY_PATTERNS := {"liso": 0, "rayas": 1, "banda": 2, "aros": 3, "mitad": 4, "degradado": 5, "rayas_finas": 6}
const SHORTS_PATTERNS := {"liso": 0, "franja": 1, "ribete": 2}
const SOCKS_PATTERNS := {"liso": 0, "rayas": 1, "ribete": 2}
const SOCK_HEIGHT_NAMES := ["Altas", "Medias", "Bajas"]

static var _celebs: Array[StringName] = []

static func load_custom(force: bool = false) -> void:
	if _loaded and not force:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	jersey = clampi(int(cfg.get_value("custom", "jersey", jersey)), 0, JERSEYS.size() - 1)
	shorts = clampi(int(cfg.get_value("custom", "shorts", shorts)), 0, SHORTS.size() - 1)
	socks = clampi(int(cfg.get_value("custom", "socks", socks)), 0, SOCKS.size() - 1)
	boots = clampi(int(cfg.get_value("custom", "boots", boots)), 0, BOOTS.size() - 1)
	skin = clampi(int(cfg.get_value("custom", "skin", skin)), 0, SKINS.size() - 1)
	hair = clampi(int(cfg.get_value("custom", "hair", hair)), 0, HAIRS.size() - 1)
	number = clampi(int(cfg.get_value("custom", "number", number)), 1, 99)
	style = clampi(int(cfg.get_value("custom", "style", style)), 0, STYLE_NAMES.size() - 1)
	run_style = clampi(int(cfg.get_value("custom", "run_style", run_style)), 0, RUN_NAMES.size() - 1)
	follow_style = clampi(int(cfg.get_value("custom", "follow_style", follow_style)), 0, FOLLOW_NAMES.size() - 1)
	celebration = clampi(int(cfg.get_value("custom", "celebration", celebration)), 0, CELEB_LOCKS.size())
	jersey_pattern = clampi(int(cfg.get_value("custom", "jersey_pattern", jersey_pattern)), 0, 6)
	jersey2 = clampi(int(cfg.get_value("custom", "jersey2", jersey2)), 0, JERSEYS.size() - 1)
	shorts_pattern = clampi(int(cfg.get_value("custom", "shorts_pattern", shorts_pattern)), 0, 2)
	socks_pattern = clampi(int(cfg.get_value("custom", "socks_pattern", socks_pattern)), 0, 2)
	sock_height = clampi(int(cfg.get_value("custom", "sock_height", sock_height)), 0, 2)
	ball_item = String(cfg.get_value("custom", "ball_item", ball_item))
	number_style = String(cfg.get_value("custom", "number_style", number_style))

static func save_custom() -> void:
	var cfg := ConfigFile.new()
	for k in ["jersey", "shorts", "socks", "boots", "skin", "hair", "number", "style", "run_style", "follow_style", "celebration",
			"jersey_pattern", "jersey2", "shorts_pattern", "socks_pattern", "sock_height", "ball_item", "number_style"]:
		cfg.set_value("custom", k, get_value(k))
	cfg.save(path)

static func get_value(k: String) -> Variant:
	return {"jersey": jersey, "shorts": shorts, "socks": socks, "boots": boots, "skin": skin, "hair": hair, "number": number,
		"style": style, "run_style": run_style, "follow_style": follow_style, "celebration": celebration,
		"jersey_pattern": jersey_pattern, "jersey2": jersey2, "shorts_pattern": shorts_pattern, "socks_pattern": socks_pattern,
		"sock_height": sock_height, "ball_item": ball_item, "number_style": number_style}[k]

## Para las pruebas: otra ruta, estado limpio.
static func use_path(p: String) -> void:
	path = p
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	jersey = 0
	shorts = 0
	socks = 0
	boots = 0
	skin = 3
	hair = 0
	number = 10
	style = Style.NATURAL
	run_style = 0
	follow_style = 0
	celebration = 0
	jersey_pattern = 0
	jersey2 = 2
	shorts_pattern = 0
	socks_pattern = 0
	sock_height = 0
	ball_item = "ball_clasico"
	number_style = "num_clasico"
	load_custom(true)

## Para las pruebas: vuelve a la ruta real y a los valores por defecto (no borra el archivo del jugador).
static func restore_after_tests() -> void:
	use_path("user://test_custom_reset.cfg")
	path = PATH
	_loaded = false

static func unlocked(cosmetic: String) -> bool:
	if cosmetic == "":
		return true
	PlayerProgress.load_progress()
	return PlayerProgress.cosmetics.has(cosmetic)

## Indice de botines efectivo (uno bloqueado y no ganado vuelve al primero).
static func boots_index() -> int:
	return boots if unlocked(BOOT_LOCKS[boots]) else 0

## Uniforme del tirador del usuario, con la personalizacion aplicada.
static func kit() -> Dictionary:
	load_custom()
	return {"jersey": JERSEYS[jersey], "shorts": SHORTS[shorts], "socks": SOCKS[socks], "boots": BOOTS[boots_index()],
		"skin": SKINS[skin], "hair": HAIRS[hair], "jersey2": JERSEYS[jersey2], "jersey_pattern": jersey_pattern,
		"shorts_pattern": shorts_pattern, "socks_pattern": socks_pattern, "sock_height": sock_height}

## Toma la apariencia guardada en el servidor (Online: profile.appearance) y la aplica al uniforme local. Los objetos
## se traducen con los datos del catalogo (diseño de camiseta, short, medias; modelo y color de botines; balon).
static func apply_appearance(ap: Dictionary, catalog: Array) -> void:
	load_custom()
	var by_id := {}
	for it in catalog:
		by_id[String(it["id"])] = it
	var data := func(key: String) -> Dictionary:
		var it: Dictionary = by_id.get(String(ap.get(key, "")), {})
		return it.get("data", {}) if it.get("data") is Dictionary else {}
	if ap.has("jersey"):
		var d: Dictionary = data.call("jersey")
		jersey_pattern = int(JERSEY_PATTERNS.get(String(d.get("pattern", "liso")), 0))
		if d.get("colors") is Array and (d["colors"] as Array).size() == 2 and not ap.has("jersey_color"):
			jersey = int(d["colors"][0]) % JERSEYS.size()
			jersey2 = int(d["colors"][1]) % JERSEYS.size()
	if ap.has("shorts"):
		shorts_pattern = int(SHORTS_PATTERNS.get(String((data.call("shorts") as Dictionary).get("pattern", "liso")), 0))
	if ap.has("socks"):
		socks_pattern = int(SOCKS_PATTERNS.get(String((data.call("socks") as Dictionary).get("pattern", "liso")), 0))
	if ap.has("boots"):
		boots = clampi(int((data.call("boots") as Dictionary).get("color", boots)), 0, BOOTS.size() - 1)
	if ap.has("ball"):
		ball_item = String(ap["ball"])
	if ap.has("number_style"):
		number_style = String(ap["number_style"])
	if ap.has("celebration"):
		celebration = clampi(int((data.call("celebration") as Dictionary).get("index", celebration)), 0, CELEB_LOCKS.size())
	for k in ["jersey_color", "jersey_color2", "shorts_color", "socks_color", "skin", "hair", "sock_height"]:
		if ap.has(k):
			var v: int = int(ap[k])
			match k:
				"jersey_color": jersey = v % JERSEYS.size()
				"jersey_color2": jersey2 = v % JERSEYS.size()
				"shorts_color": shorts = v % SHORTS.size()
				"socks_color": socks = v % SOCKS.size()
				"skin": skin = v % SKINS.size()
				"hair": hair = v % HAIRS.size()
				"sock_height": sock_height = clampi(v, 0, 2)
	save_custom()

## Uniforme del arquero del usuario: la camiseta verde de arquero, pero con sus botines, piel y pelo.
static func keeper_kit() -> Dictionary:
	load_custom()
	var k: Dictionary = SpSettings.USER_KEEPER_KIT.duplicate()
	k["boots"] = BOOTS[boots_index()]
	k["skin"] = SKINS[skin]
	k["hair"] = HAIRS[hair]
	return k

## Festejos elegibles: clips de autor de gol del banco, sin bucles, con poco recorrido y duracion razonable (los
## originales no se modifican).
static func celebrations() -> Array[StringName]:
	if _celebs.is_empty():
		for id in SpClips.by_role(&"celebrate_scorer", false):
			var a: Animation = SpClips.anim(id)
			if a == null or a.loop_mode != Animation.LOOP_NONE:
				continue
			if SpClips.root_travel(SpClips.meta(id)) <= 2.5 and SpClips.length(id) >= 1.2 and SpClips.length(id) <= 5.0:
				_celebs.append(id)
			if _celebs.size() >= CELEB_LOCKS.size():
				break
	return _celebs

static func celebration_name(i: int) -> String:
	return "Aleatorio" if i == 0 else "Festejo %d" % i

## Clip del festejo elegido (&"" = aleatorio, tambien si el elegido esta bloqueado o no existe).
static func celebration_clip() -> StringName:
	load_custom()
	var list: Array[StringName] = celebrations()
	if celebration <= 0 or celebration > list.size() or not unlocked(CELEB_LOCKS[celebration - 1]):
		return &""
	return list[celebration - 1]

## Estilo de golpeo y carrera: pesos sobre la ELECCION del clip (ShotCatalog.choose). No toca velocidad, efecto ni
## destino del tiro: con el mismo gesto la pelota sale igual.
static func bias(p: ShotParams) -> void:
	load_custom()
	match style:
		Style.POTENTE:
			if p.kind == ShotCatalog.Kind.NORMAL and p.power >= 0.5:
				p.kind = ShotCatalog.Kind.POWER
		Style.COLOCADO:
			if p.kind in [ShotCatalog.Kind.NORMAL, ShotCatalog.Kind.POWER] and p.power <= 0.8:
				p.kind = ShotCatalog.Kind.PLACED
		Style.CON_EFECTO:
			if p.kind in [ShotCatalog.Kind.NORMAL, ShotCatalog.Kind.PLACED]:
				p.curled = true
	if run_style == 1:
		p.prefer_short = true
