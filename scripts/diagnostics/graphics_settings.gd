extends Node
## Autoload "GraphicsSettings": perfiles graficos (muy bajo, bajo, medio, alto) y persistencia.
## Los perfiles controlan resolucion 3D, MSAA, sombras y detalle de redes/ambiente.

signal profile_changed(profile: int)

enum Profile { VERY_LOW, LOW, MEDIUM, HIGH }

const SETTINGS_PATH := "user://graphics.cfg"

const PROFILE_NAMES: Dictionary = {
	Profile.VERY_LOW: "Muy bajo",
	Profile.LOW: "Bajo",
	Profile.MEDIUM: "Medio",
	Profile.HIGH: "Alto",
}

## Parametros por perfil.
const PROFILES: Dictionary = {
	Profile.VERY_LOW: {
		"scale_3d": 0.5, "msaa": Viewport.MSAA_DISABLED, "shadows": false,
		"shadow_size": 1024, "ambient_props": false, "target_fps": 60,
	},
	Profile.LOW: {
		"scale_3d": 0.6, "msaa": Viewport.MSAA_DISABLED, "shadows": false,
		"shadow_size": 1024, "ambient_props": true, "target_fps": 60,
	},
	Profile.MEDIUM: {
		"scale_3d": 0.72, "msaa": Viewport.MSAA_DISABLED, "shadows": true,
		"shadow_size": 1024, "ambient_props": true, "target_fps": 60,
	},
	Profile.HIGH: {
		"scale_3d": 0.9, "msaa": Viewport.MSAA_2X, "shadows": true,
		"shadow_size": 2048, "ambient_props": true, "target_fps": 60,
	},
}
## Escalones del boton «Resolucion» del menu de pausa (multiplican la escala 3D del perfil).
const RESOLUTION_STEPS: Array[float] = [1.0, 0.85, 0.7, 0.55]
var profile: int = Profile.MEDIUM
## Multiplicador manual de resolucion 3D (0.5 - 1.0) aplicado encima del perfil.
var resolution_override: float = 1.0
## Tope de imagenes por segundo en el telefono (boton «Imagenes por segundo»): 60, o 30 estables para un telefono que no llega
## a 60 (mejor 30 parejas que 40 a tirones; la fisica sigue a 60 Hz).
const FPS_CAPS: Array[int] = [60, 30]
var fps_cap: int = 60
## Sombras (boton «Sombras»): -1 = las del perfil, 0 = no, 1 = si.
var shadows_mode: int = -1
## Automatico: arranca con el perfil detectado y, solo en el telefono, baja un escalon si los cuadros no llegan
## (media de AUTO_WINDOW s por encima de AUTO_SLOW_MS), como mucho uno cada AUTO_COOLDOWN s. No sube solo (evita que
## oscile). Heuristica a validar con las mediciones del telefono (docs/ANDROID_MEDICION.md).
var auto_mode: bool = true
## Opciones visuales (se guardan con los graficos). Linea de destino: la trayectoria prevista y el aro de llegada mientras
## se apunta (TrajectoryPreview); apagarla NO cambia la fisica ni el tiro, y el rastro del dedo sigue. Temblor de camara:
## el sacudon suave del festejo (SpCamera.shake), con tres niveles.
## Linea de destino de la pelota: QUITADA por pedido del usuario (2026-11-12; solo el rastro del dedo). La variable queda
## para el codigo que la consulta y siempre vale false fuera de las pruebas.
var show_aim_line: bool = false
## Camara de transmision de TV en los tiros libres: tras el gesto, plano lateral alto que sigue la pelota hasta el arco
## (tambien en la repeticion). Se guarda.
var tv_camera: bool = false
const SHAKE_NAMES: Array[String] = ["No", "Suave", "Normal"]
const SHAKE_SCALE: Array[float] = [0.0, 0.55, 1.0]
var camera_shake: int = 1
const AUTO_WINDOW := 3.0
const AUTO_SLOW_MS := 22.0
const AUTO_COOLDOWN := 8.0
var _auto_acc: float = 0.0
var _auto_n: int = 0
var _auto_t: float = 0.0
var _auto_cool: float = 2.0

func _ready() -> void:
	load_settings()
	show_aim_line = false
	if not _has_saved_settings() or auto_mode:
		profile = detect_default_profile()
	apply()

func _process(delta: float) -> void:
	if not auto_mode or not OS.has_feature("mobile"):
		return
	_auto_cool -= delta
	if _auto_cool > 0.0:
		return
	_auto_acc += delta * 1000.0
	_auto_n += 1
	_auto_t += delta
	if _auto_t < AUTO_WINDOW:
		return
	var avg: float = _auto_acc / maxf(float(_auto_n), 1.0)
	_auto_acc = 0.0
	_auto_n = 0
	_auto_t = 0.0
	if avg > AUTO_SLOW_MS and profile > Profile.VERY_LOW:
		profile -= 1
		apply()
		profile_changed.emit(profile)
		_auto_cool = AUTO_COOLDOWN

## Opciones del boton «Graficos» del menu: automatico y los perfiles fijos.
func menu_choice_name() -> String:
	return "Auto (%s)" % profile_name() if auto_mode else profile_name()

## Automatico -> Muy bajo -> Bajo -> Medio -> Alto -> Automatico.
func cycle_menu_choice() -> void:
	if auto_mode:
		auto_mode = false
		profile = Profile.VERY_LOW
	elif profile >= Profile.HIGH:
		auto_mode = true
		profile = detect_default_profile()
	else:
		profile += 1
	apply()
	save_settings()
	profile_changed.emit(profile)

## Interruptor de la linea de destino (se guarda).
func toggle_aim_line() -> void:
	show_aim_line = false
	save_settings()

## Interruptor de la camara de TV de los tiros libres (se guarda).
func toggle_tv_camera() -> void:
	tv_camera = not tv_camera
	save_settings()

## No -> Suave -> Normal -> No (se guarda).
func cycle_camera_shake() -> void:
	camera_shake = (camera_shake + 1) % SHAKE_NAMES.size()
	save_settings()

## Multiplicador del temblor de camara (0 = apagado).
func shake_scale() -> float:
	return SHAKE_SCALE[clampi(camera_shake, 0, SHAKE_SCALE.size() - 1)]

## Heuristica de perfil inicial segun la plataforma y el hardware. No sustituye a medir.
func detect_default_profile() -> int:
	if OS.has_feature("android") or OS.has_feature("ios"):
		var cores: int = OS.get_processor_count()
		if cores <= 4:
			return Profile.VERY_LOW
		# En el telefono se empieza en Bajo (escala 3D 0.6): prioridad a las 60 imagenes por segundo.
		return Profile.LOW
	return Profile.HIGH

func set_profile(new_profile: int) -> void:
	auto_mode = false
	profile = clampi(new_profile, Profile.VERY_LOW, Profile.HIGH)
	apply()
	save_settings()
	profile_changed.emit(profile)

## Pasa al siguiente escalon de RESOLUTION_STEPS (boton «Resolucion» del menu de pausa).
func cycle_resolution() -> void:
	var best := 0
	for i in RESOLUTION_STEPS.size():
		if absf(RESOLUTION_STEPS[i] - resolution_override) < absf(RESOLUTION_STEPS[best] - resolution_override):
			best = i
	set_resolution_override(RESOLUTION_STEPS[(best + 1) % RESOLUTION_STEPS.size()])

func set_resolution_override(value: float) -> void:
	resolution_override = clampf(value, 0.5, 1.0)
	apply()
	save_settings()

func get_params() -> Dictionary:
	return PROFILES[profile]

func profile_name() -> String:
	return PROFILE_NAMES[profile]

func shadows_enabled() -> bool:
	return bool(get_params()["shadows"]) if shadows_mode < 0 else shadows_mode == 1

## Pasa al siguiente tope de FPS_CAPS.
func cycle_fps_cap() -> void:
	fps_cap = FPS_CAPS[(FPS_CAPS.find(fps_cap) + 1) % FPS_CAPS.size()]
	apply()
	save_settings()

## Sombras: las del perfil -> no -> si -> las del perfil.
func cycle_shadows() -> void:
	shadows_mode = [0, 1, -1][shadows_mode + 1]
	apply()
	save_settings()

func ambient_props_enabled() -> bool:
	return get_params()["ambient_props"]

## Aplica el perfil al viewport principal y a las luces registradas en el grupo "sun_light".
func apply() -> void:
	var params: Dictionary = get_params()
	var root: Window = get_tree().root if is_inside_tree() else null
	if root != null:
		root.scaling_3d_scale = clampf(params["scale_3d"] * resolution_override, 0.4, 1.0)
		root.msaa_3d = params["msaa"]
		RenderingServer.directional_shadow_atlas_set_size(params["shadow_size"], false)
		# Tope de 60 imagenes por segundo en el telefono: sin el, en pantallas de 90/120 Hz el juego calcula imagenes de mas
		# (y se calienta) sin que la fisica, que va a 60 Hz, se vea mas fluida. En PC (y en las pruebas) sin tope.
		Engine.max_fps = mini(int(params["target_fps"]), fps_cap) if OS.has_feature("mobile") else 0
		for light in get_tree().get_nodes_in_group("sun_light"):
			if light is Light3D:
				light.shadow_enabled = shadows_enabled()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "profile", profile)
	cfg.set_value("graphics", "resolution_override", resolution_override)
	cfg.set_value("graphics", "fps_cap", fps_cap)
	cfg.set_value("graphics", "shadows_mode", shadows_mode)
	cfg.set_value("graphics", "auto", auto_mode)
	cfg.set_value("visual", "show_aim_line", show_aim_line)
	cfg.set_value("visual", "tv_camera", tv_camera)
	cfg.set_value("visual", "camera_shake", camera_shake)
	var err: int = cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("No se pudo guardar %s (error %d)" % [SETTINGS_PATH, err])

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	profile = clampi(int(cfg.get_value("graphics", "profile", profile)), Profile.VERY_LOW, Profile.HIGH)
	resolution_override = clampf(float(cfg.get_value("graphics", "resolution_override", 1.0)), 0.5, 1.0)
	fps_cap = int(cfg.get_value("graphics", "fps_cap", 60))
	if not FPS_CAPS.has(fps_cap):
		fps_cap = 60
	shadows_mode = clampi(int(cfg.get_value("graphics", "shadows_mode", -1)), -1, 1)
	# Configuraciones guardadas antes del modo automatico: el perfil que eligio la persona se respeta.
	auto_mode = bool(cfg.get_value("graphics", "auto", false))
	# Sin linea de destino en ninguna build (pedido del usuario): solo el rastro del dedo.
	show_aim_line = false
	tv_camera = bool(cfg.get_value("visual", "tv_camera", false))
	camera_shake = clampi(int(cfg.get_value("visual", "camera_shake", 1)), 0, SHAKE_NAMES.size() - 1)

func _has_saved_settings() -> bool:
	return FileAccess.file_exists(SETTINGS_PATH)
