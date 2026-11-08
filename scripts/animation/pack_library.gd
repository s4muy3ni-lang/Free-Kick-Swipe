class_name PackLibrary
extends RefCounted
## Acceso a las librerias de animacion derivadas del pack de Mixamo (ver tools/animation_pack/build_pack_library.gd).
## Se generan con el conversor y SE VERSIONAN junto con el pack (uso personal dentro del juego); el juego funciona sin ellas
## (usa los clips de Tripo y la patada procedural). Cada Animation lleva set_meta("pack", {...}) medido al convertir.
##
## Modo 4 (Json, Tuning.gameplay_mode): las librerias son las de las animaciones JSON (json_clips.res y json_keeper.res,
## tools/json_anim/build_json_library.gd) sobre el esqueleto JsonRig. El resto del juego sigue pidiendo clips por los nombres
## del pack de Mixamo («Soccer_Pass», «goalkeeper_catch»...): cada clip JSON declara en su meta `alias` los nombres que
## sustituye, y has_clip / clip / meta / anim_path los resuelven (también las versiones «_mirror»). Los clips que no
## tienen sustituto simplemente no existen en este modo y el juego los omite (todo uso va tras has_clip).

const FIELD_PATH := "res://assets/animations/pack_clips.res"
const KEEPER_PATH := "res://assets/animations/pack_keeper.res"
## Toques de conduccion fusionados (tools/animation_pack/build_touch_clips.tscn): se suman a la libreria de campo.
const TOUCH_PATH := "res://assets/animations/touch_clips.res"
## Mocap Pack 05 Soccer (tools/animation_pack/build_mocap_library.tscn, ids "mc_*"): el modo 2 de jugabilidad. Tambien
## se suma a la libreria de campo.
const MOCAP_PATH := "res://assets/animations/mocap_clips.res"
## Modo 4 (Json).
const JSON_FIELD_PATH := "res://assets/animations/json_clips.res"
const JSON_KEEPER_PATH := "res://assets/animations/json_keeper.res"
## Escenas del modo 4 (festejos, lamentos, gestos, esperas, barrera...): se suman a la libreria de campo.
const JSON_SCENES_PATH := "res://assets/animations/json_scenes.res"

static var _field: AnimationLibrary = null
static var _keeper: AnimationLibrary = null
static var _loaded: bool = false
static var _loaded_json: bool = false
## Modo 4: nombre del pack de Mixamo -> id del clip JSON; rol -> ids.
static var _alias: Dictionary = {}
static var _roles: Dictionary = {}

static var _json_exists: int = -1

## true si el juego usa el modo 4 y sus librerias existen (se pregunta mucho: el resultado de exists() se guarda).
static func json_mode() -> bool:
	if Tuning.gameplay_mode != 4:
		return false
	if _json_exists < 0:
		_json_exists = 1 if ResourceLoader.exists(JSON_FIELD_PATH) else 0
	return _json_exists == 1

static func _ensure() -> void:
	var want_json: bool = json_mode()
	if _loaded and _loaded_json == want_json:
		return
	_loaded = true
	_loaded_json = want_json
	_field = null
	_keeper = null
	_alias = {}
	_alias_base = {}
	_roles = {}
	_reset_caches()
	if want_json:
		_field = load(JSON_FIELD_PATH) as AnimationLibrary
		if _field != null and ResourceLoader.exists(JSON_SCENES_PATH):
			var sc: AnimationLibrary = load(JSON_SCENES_PATH) as AnimationLibrary
			if sc != null:
				for id in sc.get_animation_list():
					if not _field.has_animation(id):
						_field.add_animation(id, sc.get_animation(id))
		if ResourceLoader.exists(JSON_KEEPER_PATH):
			_keeper = load(JSON_KEEPER_PATH) as AnimationLibrary
		# Alias cuyo clip la auditoria saco de su rol (setpiece_miss): pasan a otro clip del rol original.
		var orphan_alias: Dictionary = {}
		for lib in [_field, _keeper]:
			if lib == null:
				continue
			for id in lib.get_animation_list():
				var m: Dictionary = lib.get_animation(id).get_meta("pack", {})
				# Reasignaciones de la auditoria del banco (ClipRolesOverlay, generado): el clip (y su espejo) entra en otro rol.
				var base_id: StringName = StringName(String(id).trim_suffix("_mirror"))
				# El meta es del recurso compartido: si la biblioteca sigue en memoria (otra escena la usa) ya trae el rol
				# reasignado de una carga anterior; el rol original se guarda la primera vez y se lee siempre de ahi.
				var role_before: StringName = StringName(String(m.get("role_orig", m.get("role", ""))))
				if ClipRolesOverlay.ROLE.has(base_id):
					if not m.has("role_orig"):
						m["role_orig"] = String(m.get("role", ""))
					m["role"] = String(ClipRolesOverlay.ROLE[base_id])
					if m["role"] == "setpiece_miss" and not String(id).ends_with("_mirror"):
						for a in m.get("alias", []):
							orphan_alias[StringName(a)] = role_before
				var role: StringName = StringName(String(m.get("role", "")))
				if not _roles.has(role):
					_roles[role] = []
				(_roles[role] as Array).append(id)
				# Los alias valen para el clip normal; su espejo se resuelve anadiendo «_mirror» (ver resolve).
				if not String(id).ends_with("_mirror"):
					for a in m.get("alias", []):
						if not _alias.has(StringName(a)):
							_alias[StringName(a)] = id
		for a in orphan_alias:
			for cand in _roles.get(orphan_alias[a], []):
				var cs: String = String(cand)
				if not cs.ends_with("_mirror") and _field != null and _field.has_animation(StringName(cs + "_mirror")):
					_alias[a] = cand
					break
		# Transiciones que el codigo pide por su nombre del pack y no tenian clip (ClipRolesOverlay.ALIAS).
		for a in ClipRolesOverlay.ALIAS:
			if not _alias.has(a) and _field != null and _field.has_animation(ClipRolesOverlay.ALIAS[a]):
				_alias[a] = ClipRolesOverlay.ALIAS[a]
		return
	if ResourceLoader.exists(FIELD_PATH):
		_field = load(FIELD_PATH) as AnimationLibrary
		for extra in [TOUCH_PATH, MOCAP_PATH]:
			if _field == null or not ResourceLoader.exists(extra):
				continue
			var lib: AnimationLibrary = load(extra) as AnimationLibrary
			if lib != null:
				for id in lib.get_animation_list():
					if not _field.has_animation(id):
						_field.add_animation(id, lib.get_animation(id))
	if ResourceLoader.exists(KEEPER_PATH):
		_keeper = load(KEEPER_PATH) as AnimationLibrary

## Los caches de otras clases que dependen de los clips cargados (cambian al cambiar de modo).
static func _reset_caches() -> void:
	FootballerVisual.reset_caches()
	BallHandler.reset_caches()
	KeeperPlanner.reset_caches()
	JsonCatalog.reset_caches()
	JsonReceive.reset_caches()
	JsonBallMove.reset_caches()

## Id real de un clip pedido por su nombre del pack de Mixamo (modo 4); fuera de ese modo, el mismo id.
static func resolve(id: StringName) -> StringName:
	_ensure()
	if not _loaded_json:
		return id
	if (_field != null and _field.has_animation(id)) or (_keeper != null and _keeper.has_animation(id)):
		return id
	var s: String = String(id)
	var mirrored: bool = s.ends_with("_mirror")
	var base: StringName = StringName(s.trim_suffix("_mirror")) if mirrored else id
	if (_field != null and _field.has_animation(base)) or (_keeper != null and _keeper.has_animation(base)):
		return &""   # clip real sin version espejo
	var target: StringName = _alias.get(base, &"")
	if target == &"":
		return &""
	if mirrored:
		var m: StringName = StringName(String(target) + "_mirror")
		return m if ((_field != null and _field.has_animation(m)) or (_keeper != null and _keeper.has_animation(m))) else &""
	return target

## Libreria de clips de campo, o null si no se ha generado.
static func field() -> AnimationLibrary:
	_ensure()
	return _field

## Libreria de clips de arquero (sin entidad todavia), o null. Se carga solo si alguien la pide.
static func keeper() -> AnimationLibrary:
	_ensure()
	return _keeper

static func available() -> bool:
	return field() != null

static func has_clip(id: StringName) -> bool:
	id = resolve(id)
	if id == &"":
		return false
	var lib: AnimationLibrary = field()
	if lib != null and lib.has_animation(id):
		return true
	var k: AnimationLibrary = keeper()
	return k != null and k.has_animation(id)

## Clip de campo o del arquero por su id (los ids no se repiten entre librerias).
static func clip(id: StringName) -> Animation:
	id = resolve(id)
	if id == &"":
		return null
	var lib: AnimationLibrary = field()
	if lib != null and lib.has_animation(id):
		return lib.get_animation(id)
	var k: AnimationLibrary = keeper()
	return k.get_animation(id) if k != null and k.has_animation(id) else null

## true si el clip es de la libreria del arquero (se reproduce desde "keeper/<id>").
static func is_keeper_clip(id: StringName) -> bool:
	id = resolve(id)
	if id == &"":
		return false
	var lib: AnimationLibrary = field()
	if lib != null and lib.has_animation(id):
		return false
	var k: AnimationLibrary = keeper()
	return k != null and k.has_animation(id)

## Nombre con el que el AnimationPlayer del visual conoce el clip ("pack/<id>" o "keeper/<id>").
static func anim_path(id: StringName) -> StringName:
	id = resolve(id)
	return StringName(("keeper/" if is_keeper_clip(id) else "pack/") + String(id))

## Metadatos medidos del clip (diccionario vacio si no existe).
static func meta(id: StringName) -> Dictionary:
	var a: Animation = clip(id)
	return a.get_meta("pack", {}) if a != null else {}

## Modo 4: ids de los clips con ese rol (incluye las versiones espejo), en el orden de la libreria.
static func by_role(role: StringName) -> Array[StringName]:
	_ensure()
	var out: Array[StringName] = []
	if _roles.has(role):
		out.assign(_roles[role])
	return out

## Roles cuyos nombres del pack se reparten entre TODOS los clips del rol (modo 4): en cada saque inicial y en cada balon
## parado (vary_aliases) cada nombre pasa a otro clip del mismo rol, asi a lo largo del partido se ven todas las barridas,
## saques de banda, balones parados, tropiezos y empujones convertidos (y no siempre el mismo).
const VARY_ROLES: Array[StringName] = [&"slide", &"throw_in", &"setpiece_pass", &"setpiece_shot", &"setpiece_lob", &"stumble", &"shove",
	&"gk_throw", &"gk_roll", &"gk_kick", &"gk_place", &"gk_direct", &"gk_block", &"gk_miss"]
static var _alias_base: Dictionary = {}
static var _vary_rng := RandomNumberGenerator.new()

## Reparte de nuevo los nombres del pack de los roles VARY_ROLES entre los clips de su rol (modo 4). Lo llaman el saque
## inicial y el comienzo de cada balon parado: nunca a mitad de una accion que vuelve a pedir el clip por su nombre.
static func vary_aliases() -> void:
	_ensure()
	if not _loaded_json:
		return
	if _alias_base.is_empty():
		_alias_base = _alias.duplicate()
		_vary_rng.randomize()
	for a in _alias_base:
		var orig: StringName = _alias_base[a]
		var lib: AnimationLibrary = _field if (_field != null and _field.has_animation(orig)) else _keeper
		if lib == null or not lib.has_animation(orig):
			continue
		var om: Dictionary = lib.get_animation(orig).get_meta("pack", {})
		var role: StringName = StringName(String(om.get("role", "")))
		if not VARY_ROLES.has(role) or not _roles.has(role):
			continue
		var need_mirror: bool = lib.has_animation(StringName(String(orig) + "_mirror"))
		var pool: Array = []
		for id in _roles[role]:
			var s: String = String(id)
			if s.ends_with("_mirror") or not lib.has_animation(id):
				continue
			if need_mirror and not lib.has_animation(StringName(s + "_mirror")):
				continue
			var m: Dictionary = lib.get_animation(id).get_meta("pack", {})
			# Saques y golpeos: solo los que traen la suelta / el contacto medidos (el juego los usa).
			if om.has("release") != m.has("release") or om.has("contact") != m.has("contact"):
				continue
			pool.append(id)
		if not pool.is_empty():
			_alias[a] = pool[_vary_rng.randi() % pool.size()]

## Fuerza una nueva lectura de disco (pruebas).
static func reload() -> void:
	_loaded = false
	_alias_base = {}
	_field = null
	_keeper = null
	_alias = {}
	_roles = {}
	_reset_caches()
