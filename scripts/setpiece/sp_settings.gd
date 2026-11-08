class_name SpSettings
extends RefCounted
## Preferencias de los modos de tiros libres y penales (pie habil, dificultad) y uniformes de los dos equipos. Se guardan en
## user://setpiece.cfg.

const PATH := "user://setpiece.cfg"

enum Difficulty { EASY, NORMAL, HARD }
const DIFFICULTY_NAMES := ["Fácil", "Normal", "Difícil"]

## 1 = diestro, -1 = zurdo.
static var foot: int = 1
static var difficulty: int = Difficulty.NORMAL
## Tipo de arco (PitchConfig.GoalStyle): red de caja o de fondo inclinado.
static var goal_style: int = PitchConfig.GoalStyle.BOX
const GOAL_STYLE_NAMES := ["Caja", "Inclinado"]
static var _loaded: bool = false

const USER_KIT := {"jersey": Color(0.10, 0.32, 0.86), "shorts": Color(0.95, 0.95, 0.97), "socks": Color(0.10, 0.32, 0.86),
	"boots": Color(0.95, 0.55, 0.08), "skin": Color(0.62, 0.40, 0.29), "hair": Color(0.12, 0.07, 0.04)}
const CPU_KIT := {"jersey": Color(0.82, 0.08, 0.10), "shorts": Color(0.06, 0.06, 0.08), "socks": Color(0.82, 0.08, 0.10),
	"boots": Color(0.05, 0.05, 0.05), "skin": Color(0.78, 0.58, 0.45), "hair": Color(0.35, 0.22, 0.10)}
const USER_KEEPER_KIT := {"jersey": Color(0.12, 0.70, 0.30), "shorts": Color(0.05, 0.05, 0.08), "socks": Color(0.12, 0.70, 0.30),
	"boots": Color(0.95, 0.95, 0.95), "skin": Color(0.55, 0.36, 0.25), "hair": Color(0.08, 0.05, 0.03)}
const CPU_KEEPER_KIT := {"jersey": Color(0.98, 0.82, 0.10), "shorts": Color(0.05, 0.05, 0.08), "socks": Color(0.98, 0.82, 0.10),
	"boots": Color(0.95, 0.95, 0.95), "skin": Color(0.70, 0.50, 0.38), "hair": Color(0.10, 0.07, 0.05)}

static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		foot = 1 if int(cfg.get_value("setpiece", "foot", 1)) >= 0 else -1
		difficulty = clampi(int(cfg.get_value("setpiece", "difficulty", Difficulty.NORMAL)), 0, 2)
		goal_style = clampi(int(cfg.get_value("setpiece", "goal_style", PitchConfig.GoalStyle.BOX)), 0, 1)

static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("setpiece", "foot", foot)
	cfg.set_value("setpiece", "difficulty", difficulty)
	cfg.set_value("setpiece", "goal_style", goal_style)
	cfg.save(PATH)

static func foot_name() -> String:
	return "Diestro" if foot > 0 else "Zurdo"

## Dificultad que imponen los desafios mientras se juegan (-1: la del menu). Los desafios usan cinco niveles: los tres del
## menu mas Profesional y Extremo (solo desafios).
static var override_difficulty: int = -1
const ALL_DIFFICULTY_NAMES := ["Fácil", "Normal", "Difícil", "Profesional", "Extremo"]

static func level() -> int:
	return override_difficulty if override_difficulty >= 0 else difficulty

## Parametros de la IA segun la dificultad (lo que cambia: tiempo de reaccion del arquero, error de percepcion, lectura del
## cuerpo del tirador en penales, alcance; precision del tirador de la IA). Profesional y Extremo siguen la misma
## progresion (solo en los desafios).
static func keeper_reaction() -> float:
	return [0.34, 0.24, 0.17, 0.14, 0.12][level()]

static func keeper_perception_deg() -> float:
	return [4.5, 2.6, 1.4, 1.0, 0.7][level()]

static func keeper_read_probability() -> float:
	return [0.38, 0.52, 0.66, 0.70, 0.74][level()]

static func keeper_catch_speed() -> float:
	return [15.0, 18.0, 21.0, 22.5, 24.0][level()]

static func cpu_shot_error_deg() -> float:
	return [2.6, 1.8, 1.1, 0.9, 0.7][level()]
