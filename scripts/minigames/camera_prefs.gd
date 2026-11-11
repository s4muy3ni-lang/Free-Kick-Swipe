class_name CameraPrefs
extends RefCounted
## Ajustes de camara POR MINIJUEGO (pedido del usuario): distancia, altura, encuadre (cuanto mira por delante de la
## pelota) y seguimiento (suavidad de la transicion). Cada minijuego tiene sus valores recomendados (los de antes del
## cambio que alejo la camara, recuperados de Git: ver Minigame.camera_defaults) y el usuario los ajusta por encima; lo que
## cambia en un minijuego no toca a los demas. Se guarda en user://camera.cfg (seccion = id del minijuego).

const PATH := "user://camera.cfg"
static var path: String = PATH
## Pasos de cada ajuste y limites (respecto del valor recomendado del minijuego).
const STEPS := {"back": 0.75, "height": 0.5, "ahead": 0.75, "follow": 0.1}
const LIMITS := {"back": Vector2(-6.0, 8.0), "height": Vector2(-3.0, 6.0), "ahead": Vector2(-4.0, 6.0), "follow": Vector2(-0.3, 0.6)}
const NAMES := {"back": "Distancia", "height": "Altura", "ahead": "Encuadre", "follow": "Seguimiento"}

## Desplazamientos guardados del usuario: {game_id: {back, height, ahead, follow}}.
static func offsets(game: String) -> Dictionary:
	var cfg := ConfigFile.new()
	var out := {"back": 0.0, "height": 0.0, "ahead": 0.0, "follow": 0.0}
	if cfg.load(path) == OK:
		for k in out:
			out[k] = float(cfg.get_value(game, k, 0.0))
	return out

static func save_offsets(game: String, o: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	for k in o:
		cfg.set_value(game, k, float(o[k]))
	cfg.save(path)

## Cambia un ajuste un paso (dir +1/-1) dentro de sus limites y lo guarda.
static func nudge(game: String, key: String, dir: int) -> Dictionary:
	var o: Dictionary = offsets(game)
	var lim: Vector2 = LIMITS[key]
	o[key] = clampf(float(o[key]) + float(STEPS[key]) * float(dir), lim.x, lim.y)
	save_offsets(game, o)
	return o

## Vuelve a los valores recomendados de ese minijuego (solo ese).
static func reset(game: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	if cfg.has_section(game):
		cfg.erase_section(game)
	cfg.save(path)

## Valores efectivos: recomendados del minijuego + ajustes del usuario.
static func effective(game: String, defaults: Dictionary) -> Dictionary:
	var o: Dictionary = offsets(game)
	var e: Dictionary = defaults.duplicate()
	e["back"] = maxf(float(defaults["back"]) + float(o["back"]), 2.5)
	e["height"] = maxf(float(defaults["height"]) + float(o["height"]), 1.5)
	e["ahead"] = float(defaults["ahead"]) + float(o["ahead"])
	e["follow"] = clampf(float(defaults["follow"]) + float(o["follow"]), 0.1, 1.2)
	return e

## Para las pruebas: otro archivo, vacio.
static func use_path(p: String) -> void:
	path = p
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
