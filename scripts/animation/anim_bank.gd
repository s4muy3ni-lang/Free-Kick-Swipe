class_name AnimBank
extends RefCounted
## Biblioteca de animaciones activa del juego: ACTUAL (el banco JSON de siempre) o MIXAMO (los 133 clips del paquete
## animaciones_mixamo.zip convertidos al mismo esqueleto, tools/mixamo/). Pedido «Integración y comparación de animaciones
## actuales vs Mixamo» (2026-11-12): las dos conviven, se eligen sin recompilar y nada de lo actual se borra.
##
## - ACTUAL: solo se cargan las bibliotecas actuales (como antes de este cambio). Las de Mixamo no se tocan.
## - MIXAMO: se cargan las de Mixamo y, ademas, las actuales, porque son el RESPALDO de los roles que Mixamo no tiene
##   (barrera, levantarse del arquero, giros del arquero, gestos...). Por cada rol: si Mixamo tiene clips de ese rol, el
##   juego usa SOLO los de Mixamo; si no, usa los actuales (fallback_roles() los lista; docs/animaciones/).
##   Los ids no chocan: los de Mixamo empiezan con «mx_».
##
## Se guarda en user://anim_bank.cfg. Si las bibliotecas de Mixamo no estan en la build (por ejemplo, una APK de CI sin
## el secret que las descifra), MIXAMO no esta disponible y el juego queda en ACTUAL.

enum Bank { ACTUAL, MIXAMO }
const NAMES := ["ACTUAL", "MIXAMO"]
const PATH := "user://anim_bank.cfg"

const MIXAMO_FIELD := "res://assets/animations/mixamo_clips.res"
const MIXAMO_KEEPER := "res://assets/animations/mixamo_keeper.res"
const MIXAMO_SCENES := "res://assets/animations/mixamo_scenes.res"
## Catalogo de golpeos medido sobre los clips de Mixamo (tools/setpiece/build_shot_catalog con ANIM_BANK=mixamo).
const MIXAMO_SHOTS := "res://resources/setpiece/shot_clips_mixamo.json"
const ID_PREFIX := "mx_"

## Se emite al cambiar de biblioteca (despues de vaciar los caches).
signal changed(bank: int)

static var _bank: int = Bank.ACTUAL
static var _loaded: bool = false
static var _available: int = -1
static var _notifier: AnimBank = null

static func notifier() -> AnimBank:
	if _notifier == null:
		_notifier = AnimBank.new()
	return _notifier

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	# Herramientas y pruebas: ANIM_BANK=mixamo|actual fuerza la biblioteca sin tocar la preferencia guardada.
	var env: String = OS.get_environment("ANIM_BANK").to_lower()
	if env == "mixamo":
		_bank = Bank.MIXAMO
		return
	if env == "actual":
		_bank = Bank.ACTUAL
		return
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		_bank = clampi(int(cfg.get_value("anim", "bank", Bank.ACTUAL)), 0, Bank.size() - 1)

## true si la build trae las bibliotecas de Mixamo.
static func mixamo_available() -> bool:
	if _available < 0:
		_available = 1 if (ResourceLoader.exists(MIXAMO_FIELD) and ResourceLoader.exists(MIXAMO_KEEPER)) else 0
	return _available == 1

## Biblioteca en uso (MIXAMO solo si esta disponible).
static func current() -> int:
	_load()
	if _bank == Bank.MIXAMO and not mixamo_available():
		return Bank.ACTUAL
	return _bank

static func is_mixamo() -> bool:
	return current() == Bank.MIXAMO

static func current_name() -> String:
	return NAMES[current()]

## Cambia la biblioteca: guarda la preferencia (save = true), vacia los caches de clips de SpClips, PackLibrary y
## ShotCatalog y avisa. Los actores ya creados conservan sus bibliotecas hasta que se vuelvan a crear (al entrar a un modo).
static func set_bank(b: int, save: bool = true) -> void:
	_load()
	b = clampi(b, 0, Bank.size() - 1)
	var before: int = current()
	_bank = b
	if save:
		var cfg := ConfigFile.new()
		cfg.load(PATH)
		cfg.set_value("anim", "bank", _bank)
		cfg.save(PATH)
	if current() != before:
		SpClips.reload()
		PackLibrary.reload()
		ShotCatalog.reload()
	notifier().changed.emit(current())

## Pruebas: vuelve a leer la preferencia y la disponibilidad.
static func reset_for_tests() -> void:
	_loaded = false
	_available = -1

static func is_mixamo_id(id: StringName) -> bool:
	return String(id).begins_with(ID_PREFIX)
