extends Node
## Autoload "Tuning": punto unico de acceso a los parametros centralizados del juego.
## Carga los .tres de resources/tuning/ y, si faltan, usa los valores por defecto de cada clase.

const BALL_PATH := "res://resources/tuning/ball_tuning.tres"
const PLAYER_PATH := "res://resources/tuning/player_tuning.tres"
const ASSIST_PATH := "res://resources/tuning/assist_tuning.tres"
const KEEPER_PATH := "res://resources/tuning/keeper_tuning.tres"
const PITCH_PATH := "res://resources/tuning/pitch_config.tres"

var ball: BallTuning
var player: PlayerTuning
var assist: AssistTuning
var keeper: KeeperTuning
var pitch: PitchConfig

const USER_SETTINGS_PATH := "user://settings.cfg"
## Preferencias del usuario (persisten entre sesiones, no forman parte del balance del juego).
var show_diagnostics: bool = false
## Controles tactiles: escala de los botones (0.85 / 1 / 1.2) y sensibilidad del joystick (radio menor = mas sensible).
var touch_scale: float = 1.0
var joystick_sensitivity: float = 1.0
## Duracion del partido elegida (minutos): 3, 5, 7 o 10.
const MATCH_MINUTES := [3, 5, 7, 10]
var match_minutes: int = 5
## Zoom de la camara del partido: factor sobre la distancia de MatchCamera (menor = mas cerca). Niveles del menu:
## muy cerca, cerca (por defecto: la camara a 0.7 de la distancia de la transmision lejana), media y lejos (la
## transmision de antes).
const CAMERA_ZOOMS := [0.55, 0.7, 0.85, 1.0]
const CAMERA_ZOOM_NAMES := ["Muy cerca", "Cerca", "Media", "Lejos"]
var camera_zoom: float = 0.7
## Sonido del partido (Sfx) encendido.
var sound_on: bool = true
## Modo de jugabilidad: 1 = animaciones del pack actual; 2 = «Mocap Pack 05 Soccer» (capturas de movimiento de futbol:
## pase de interior, tiro potente, penal y festejos; ver AnimationCatalog.mocap_mode); 3 = solo Tripo3D (el modelo y sus
## animaciones prefijadas, patada procedural; FootballerVisual.build); 4 = Json (las animaciones de animaciones_futbol5_JSON
## sobre el esqueleto canonico JsonRig, con el humanoide propio json_human.scn). Solo el 4 se conserva en la version final:
## el juego arranca en el 4 y el menu de pausa no ofrece los descartados (1-3 siguen en el codigo para las pruebas y los
## sistemas compartidos hasta que se autorice quitarlos).
const GAMEPLAY_MODES := [1, 2, 3, 4]
const GAMEPLAY_MODE_NAMES := {1: "1 · Pack actual", 2: "2 · Mocap fútbol", 3: "3 · Tripo", 4: "4 · Json"}
## Modos que se ofrecen en el menu y que se aceptan de las preferencias guardadas, y el de una instalacion nueva.
const PLAYABLE_MODES := [4]
const DEFAULT_GAMEPLAY_MODE := 4
var gameplay_mode: int = DEFAULT_GAMEPLAY_MODE

func _init() -> void:
	reload()

func _ready() -> void:
	InputBindings.ensure()

## Recarga todos los parametros desde disco (util al ajustar valores en el laboratorio).
func reload() -> void:
	ball = _load_or_default(BALL_PATH, BallTuning) as BallTuning
	player = _load_or_default(PLAYER_PATH, PlayerTuning) as PlayerTuning
	assist = _load_or_default(ASSIST_PATH, AssistTuning) as AssistTuning
	keeper = _load_or_default(KEEPER_PATH, KeeperTuning) as KeeperTuning
	pitch = _load_or_default(PITCH_PATH, PitchConfig) as PitchConfig
	load_user_settings()

## Aplica las preferencias del usuario (niveles de asistencia, diagnostico) sobre los parametros. path: otro archivo (pruebas).
func load_user_settings(path: String = USER_SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	assist.pass_assist = clampf(float(cfg.get_value("assist", "pass", assist.pass_assist)), 0.0, 1.0)
	assist.shot_assist = clampf(float(cfg.get_value("assist", "shot", assist.shot_assist)), 0.0, 1.0)
	assist.press_assist = clampf(float(cfg.get_value("assist", "press", assist.press_assist)), 0.0, 1.0)
	show_diagnostics = bool(cfg.get_value("ui", "diagnostics", false))
	touch_scale = clampf(float(cfg.get_value("ui", "touch_scale", 1.0)), 0.7, 1.4)
	joystick_sensitivity = clampf(float(cfg.get_value("ui", "joystick_sensitivity", 1.0)), 0.6, 1.6)
	var mm: int = int(cfg.get_value("match", "minutes", 5))
	match_minutes = mm if MATCH_MINUTES.has(mm) else 5
	camera_zoom = clampf(float(cfg.get_value("ui", "camera_zoom", 0.7)), 0.4, 1.2)
	sound_on = bool(cfg.get_value("ui", "sound_on", true))
	var gm: int = int(cfg.get_value("match", "gameplay_mode", DEFAULT_GAMEPLAY_MODE))
	# Preferencias de versiones anteriores con un modo descartado (1-3; el 1 era el predeterminado y se guardaba con cualquier
	# ajuste): pasan al 4 y el resto de la configuracion se conserva.
	gameplay_mode = gm if PLAYABLE_MODES.has(gm) else DEFAULT_GAMEPLAY_MODE

func save_user_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("assist", "pass", assist.pass_assist)
	cfg.set_value("assist", "shot", assist.shot_assist)
	cfg.set_value("assist", "press", assist.press_assist)
	cfg.set_value("ui", "diagnostics", show_diagnostics)
	cfg.set_value("ui", "touch_scale", touch_scale)
	cfg.set_value("ui", "joystick_sensitivity", joystick_sensitivity)
	cfg.set_value("match", "minutes", match_minutes)
	cfg.set_value("ui", "camera_zoom", camera_zoom)
	cfg.set_value("ui", "sound_on", sound_on)
	cfg.set_value("match", "gameplay_mode", gameplay_mode)
	var err: int = cfg.save(USER_SETTINGS_PATH)
	if err != OK:
		push_warning("No se pudieron guardar las preferencias (error %d)" % err)

func _load_or_default(path: String, script: GDScript) -> Resource:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res != null and res.get_script() == script:
			return res
		push_warning("Tuning: %s no es del tipo esperado; se usan valores por defecto." % path)
	return script.new()
