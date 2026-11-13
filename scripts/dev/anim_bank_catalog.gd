class_name AnimBankCatalog
extends RefCounted
## Reforma, Fase 1 (comparacion de bancos): acceso al catalogo de los tres bancos de animacion SEPARADO POR PROCEDENCIA
## (JSON original, Mixamo, Mocap). El catalogo lo genera tools/reforma/build_bank_catalog.gd a partir de las bibliotecas
## (sin modificarlas) y se guarda en resources/animation/catalogo_bancos.json. Aqui no se mezclan bancos: cada consulta es
## de un solo banco y una categoria vacia en ese banco devuelve una lista vacia («sin clip en este banco»).

const PATH := "res://resources/animation/catalogo_bancos.json"
## Solo el banco JSON original: Mixamo y Mocap se borraron (2026-11-08, pedido del usuario).
const BANKS: Array[String] = ["json"]
## Cuerpo comun de la comparacion: el cuerpo del juego (modelo de Tripo; el humanoide JSON se elimino el 2026-11-12).
const COMMON_BODY := "res://assets/characters/json/tripo_body.scn"
const PLAYER_KIT_SHADER := "res://assets/characters/player/player_kit.gdshader"
const PLAYER_ALBEDO := "res://assets/characters/player/player_albedo.jpg"
const PLAYER_MASK_A := "res://assets/characters/player/player_mask_a.png"
const PLAYER_MASK_B := "res://assets/characters/player/player_mask_b.png"
## Cifras del numero impreso en la espalda (tools/ui/make_number_atlas) y cuerpo que lo admite (posicion de reposo en
## CUSTOM0: tools/json_anim/build_tripo_body).
const NUMBER_ATLAS := "res://assets/characters/player/number_atlas.png"
## Letras del nombre de la espalda (ShirtName.GLYPHS; tools/ui/make_number_atlas).
const NAME_ATLAS := "res://assets/characters/player/name_atlas.png"
const PRINTED_NUMBER_BODY := "res://assets/characters/json/tripo_body.scn"
## Escala del cuerpo en el juego (FootballerVisual.MODEL_HEIGHT_SCALE): los metadatos de los clips estan en metros de juego.
const BODY_SCALE := 1.75

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("AnimBankCatalog: falta %s (generarlo con tools/reforma/build_bank_catalog.gd)" % PATH)
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		_data = parsed if parsed is Dictionary else {}
	return _data

static func available() -> bool:
	return not data().is_empty()

## [{id, grupo, etiqueta}] en el orden en que se muestran.
static func categories() -> Array:
	return data().get("categorias", [])

static func label(bank: String) -> String:
	return String(data().get("bancos", {}).get(bank, {}).get("etiqueta", bank))

static func libraries(bank: String) -> Array:
	return data().get("bancos", {}).get(bank, {}).get("bibliotecas", [])

## Cuerpo para el que se convirtio el banco (vista de diagnostico «cuerpo original»).
static func native_body(bank: String) -> String:
	return String(data().get("bancos", {}).get(bank, {}).get("cuerpo_original", COMMON_BODY))

static func all_clips(bank: String) -> Array:
	return data().get("bancos", {}).get(bank, {}).get("clips", [])

## Clips de UN banco en una categoria (vacio si el banco no tiene ninguno).
static func clips(bank: String, category: String) -> Array:
	return all_clips(bank).filter(func(e: Dictionary) -> bool: return (e.get("categorias", []) as Array).has(category))

static func count(bank: String, category: String) -> int:
	return clips(bank, category).size()

static func entry(bank: String, clip_id: String) -> Dictionary:
	for e in all_clips(bank):
		if String(e["id"]) == clip_id:
			return e
	return {}

## Grupo de una categoria ("Tirador", "Barrera" o "Arquero").
static func group_of(category: String) -> String:
	for c in categories():
		if String(c["id"]) == category:
			return String(c["grupo"])
	return ""

## Material del uniforme para un cuerpo (el mismo que usa FootballerVisual), con los colores de `kit`.
static func kit_material(body_path: String, kit: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(PLAYER_KIT_SHADER) as Shader
	mat.set_shader_parameter("albedo_tex", load(PLAYER_ALBEDO))
	mat.set_shader_parameter("mask_a", load(PLAYER_MASK_A))
	mat.set_shader_parameter("mask_b", load(PLAYER_MASK_B))
	if body_path == PRINTED_NUMBER_BODY:
		mat.set_shader_parameter("rest_space", true)
		mat.set_shader_parameter("number_atlas", load(NUMBER_ATLAS))
		mat.set_shader_parameter("name_atlas", load(NAME_ATLAS))
		mat.set_shader_parameter("name_glyph_count", float(ShirtName.GLYPHS.length()))
	for key in ["jersey", "shorts", "socks", "boots", "skin", "hair"]:
		if kit.has(key):
			mat.set_shader_parameter("%s_color" % key, kit[key])
	# Diseños de la personalizacion (ribetes blancos).
	if kit.has("shorts"):
		mat.set_shader_parameter("trim_color", Color(0.95, 0.95, 0.97))
	# Botines: modelo (diseño), segundo color, suela, cordones, metal y brillo (BootsCatalog / PlayerCustom).
	for key in ["boots_model", "boots_metal", "boots_glow"]:
		if kit.has(key):
			mat.set_shader_parameter(key, kit[key])
	for key in ["boots_color2", "boots_sole", "boots_laces"]:
		if kit.has(key):
			mat.set_shader_parameter(key, kit[key])
	for key in ["jersey_pattern", "shorts_pattern", "socks_pattern", "sock_height"]:
		if kit.has(key):
			mat.set_shader_parameter(key, int(kit[key]))
	if kit.has("jersey2"):
		mat.set_shader_parameter("jersey_color2", kit["jersey2"])
	return mat
