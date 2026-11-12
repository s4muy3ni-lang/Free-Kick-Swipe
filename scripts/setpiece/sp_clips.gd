class_name SpClips
extends RefCounted
## Tiros libres y penales: acceso a los clips de la biblioteca activa (AnimBank: ACTUAL = banco JSON original, que cubre
## las 25 acciones de tirador, barrera y arquero sobre el humano JSON, ver docs/reforma/MODOS_TIROS_PENALES.md; MIXAMO =
## los clips de Mixamo por rol con las actuales de respaldo, docs/animaciones/). Carga las bibliotecas una sola vez
## (son recursos compartidos por todos los actores), resuelve id -> biblioteca, lee los metadatos de cada clip y evalua su
## movimiento de raiz y su rumbo. No modifica ninguna biblioteca.
##
## Marco de un clip: el del INICIO del clip, con el cuerpo en el origen mirando a +X (adelante) y la derecha en +Z. El
## movimiento de raiz (meta root_path, 30 Hz) va en (adelante, derecha) y el rumbo (heading_path, grados, + izquierda) solo
## gira el cuerpo en los clips con heading_mode "turn" (en los demas el giro ya esta en la cadera del clip).

## Bibliotecas ACTUALES (banco JSON). Con AnimBank en MIXAMO se cargan tambien las de Mixamo (MIXAMO_LIBS) y, por rol,
## mandan las de Mixamo; las actuales quedan como respaldo de los roles que Mixamo no tiene (fallback_roles()).
const LIBS := {
	&"f": "res://assets/animations/json_clips.res",
	&"k": "res://assets/animations/json_keeper.res",
	&"s": "res://assets/animations/json_scenes.res",
}
const MIXAMO_LIBS := {
	&"mf": AnimBank.MIXAMO_FIELD,
	&"mk": AnimBank.MIXAMO_KEEPER,
	&"ms": AnimBank.MIXAMO_SCENES,
}
const FPS := 30.0

static var _libs: Dictionary = {}
static var _where: Dictionary = {}
static var _roles: Dictionary = {}
static var _bank: int = -1
static var _fallback: Array[StringName] = []

static func _ensure() -> void:
	var want: int = AnimBank.current()
	if not _libs.is_empty() and _bank == want:
		return
	_libs = {}
	_where = {}
	_roles = {}
	_fallback = []
	_bank = want
	var mx_roles := {}
	if want == AnimBank.Bank.MIXAMO:
		for key in MIXAMO_LIBS:
			_load_lib(key, MIXAMO_LIBS[key], mx_roles)
	var act_roles := {}
	for key in LIBS:
		_load_lib(key, LIBS[key], act_roles)
	_roles = act_roles
	if want == AnimBank.Bank.MIXAMO:
		for role in act_roles:
			if not mx_roles.has(role):
				_fallback.append(role)
		for role in mx_roles:
			_roles[role] = mx_roles[role]
		_fallback.sort()

static func _load_lib(key: StringName, path_: String, into: Dictionary) -> void:
	var lib: AnimationLibrary = load(path_) as AnimationLibrary
	if lib == null:
		push_error("SpClips: falta %s" % path_)
		return
	_libs[key] = lib
	for id in lib.get_animation_list():
		if _where.has(id):
			continue
		_where[id] = key
		var m: Dictionary = lib.get_animation(id).get_meta("pack", {})
		var role := StringName(String(m.get("role", "")))
		if ClipRolesOverlay.ROLE.has(StringName(String(id).trim_suffix("_mirror"))):
			role = ClipRolesOverlay.ROLE[StringName(String(id).trim_suffix("_mirror"))]
		if not into.has(role):
			into[role] = []
		(into[role] as Array).append(id)

## Fuerza una nueva carga (cambio de biblioteca, pruebas).
static func reload() -> void:
	_libs = {}
	_where = {}
	_roles = {}
	_fallback = []
	_bank = -1

## Con MIXAMO: roles que Mixamo no tiene y siguen con los clips actuales (vacio con ACTUAL).
static func fallback_roles() -> Array[StringName]:
	_ensure()
	return _fallback.duplicate()

## Todos los roles con clips en la biblioteca activa.
static func roles() -> Array[StringName]:
	_ensure()
	var out: Array[StringName] = []
	for r in _roles:
		out.append(r)
	out.sort()
	return out

## Bibliotecas {nombre: AnimationLibrary} para un AnimationPlayer.
static func libraries() -> Dictionary:
	_ensure()
	return _libs

static func has(id: StringName) -> bool:
	_ensure()
	return _where.has(id)

## Ruta del clip dentro del AnimationPlayer ("f/jn_...").
static func path(id: StringName) -> StringName:
	_ensure()
	return StringName("%s/%s" % [_where.get(id, &"f"), id])

static func anim(id: StringName) -> Animation:
	_ensure()
	if not _where.has(id):
		return null
	return (_libs[_where[id]] as AnimationLibrary).get_animation(id)

static func meta(id: StringName) -> Dictionary:
	var a: Animation = anim(id)
	return a.get_meta("pack", {}) if a != null else {}

static func length(id: StringName) -> float:
	var a: Animation = anim(id)
	return a.length if a != null else 0.0

## Clips de un rol (con espejos), ordenados por id para que la seleccion sea reproducible.
static func by_role(role: StringName, mirrors: bool = true) -> Array[StringName]:
	_ensure()
	var out: Array[StringName] = []
	for id in _roles.get(role, []):
		if mirrors or not String(id).ends_with("_mirror"):
			out.append(id)
	out.sort()
	return out

## Desplazamiento de raiz (adelante, derecha) en el instante t del clip, en el marco del inicio.
static func root_at(m: Dictionary, t: float) -> Vector2:
	var rp: PackedVector2Array = m.get("root_path", PackedVector2Array())
	if rp.size() < 2:
		return Vector2.ZERO
	var f: float = clampf(t * FPS, 0.0, float(rp.size() - 1))
	var i: int = mini(int(f), rp.size() - 2)
	return rp[i].lerp(rp[i + 1], f - float(i))

## Giro del cuerpo (rad, + izquierda) desde el inicio hasta t (0 salvo heading_mode "turn").
static func heading_at(m: Dictionary, t: float) -> float:
	if String(m.get("heading_mode", "")) != "turn":
		return 0.0
	return ActionMotion.heading_rel(m.get("heading_path", PackedFloat32Array()), t)

## Recorrido total de la raiz (m).
static func root_travel(m: Dictionary) -> float:
	var rp: PackedVector2Array = m.get("root_path", PackedVector2Array())
	return rp[rp.size() - 1].length() if rp.size() > 0 else 0.0

## Vector derecho de una direccion horizontal (adelante x derecha = +Z para +X).
static func right_of(f: Vector3) -> Vector3:
	return Vector3(-f.z, 0.0, f.x)

## Rotacion Y (Godot) de un cuerpo cuyo «adelante» es +X local y debe mirar hacia f.
static func yaw_of(f: Vector3) -> float:
	return atan2(-f.z, f.x)

## Direccion horizontal desde la rotacion Y de un cuerpo (inversa de yaw_of).
static func dir_of(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))
