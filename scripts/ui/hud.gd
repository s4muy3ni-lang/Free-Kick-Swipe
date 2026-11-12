class_name Hud
extends CanvasLayer
## HUD del partido: marcador, reloj, mensajes, controles tactiles, menu de pausa y diagnostico.
## Esta separado de la camara 3D (CanvasLayer). Todos los botones ejecutan acciones reales.

signal restart_play_requested
signal restart_match_requested
signal quit_requested
signal practice_requested
## Cambiar entre partido normal y entrenamiento (tu equipo contra el arquero rival solo).
signal training_toggle_requested
## Se eligio otro modo de jugabilidad: el partido se vuelve a montar con los modelos y clips del modo.
signal gameplay_mode_changed

const LEVEL_NAMES: Array[String] = ["Desactivada", "Baja", "Media", "Alta"]

var touch: TouchControls
var diagnostics: DiagnosticsOverlay
var manager: MatchManager
var charge_provider: Callable = Callable()

var _score_label: Label
var _clock_label: Label
var _message_label: Label
var _hint_label: Label
var _pause_panel: PanelContainer
var _pause_buttons: Dictionary = {}
var _message_tween: Tween
var _theme: Theme
var _replay_label: Label = null
## Repeticion en curso (la muestra la escena): tocar la pantalla la salta.
var replay_skip: Callable = Callable()

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_theme = UiTheme.make()
	var root := Control.new()
	root.name = "Root"
	root.theme = _theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_scoreboard(root)
	_build_message(root)
	touch = TouchControls.new()
	touch.name = "TouchControls"
	touch.charge_source = _charges
	touch.pause_pressed.connect(_on_pause_pressed)
	root.add_child(touch)
	touch.visible = should_show_touch_controls()
	diagnostics = DiagnosticsOverlay.new()
	diagnostics.name = "Diagnostics"
	diagnostics.position = Vector2(16, 70)
	diagnostics.visible = Tuning.show_diagnostics
	root.add_child(diagnostics)
	_build_pause_menu(root)
	_replay_label = Label.new()
	_replay_label.text = "REPETICIÓN  ·  toca para saltar"
	_replay_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_replay_label.position = Vector2(-260, 70)
	_replay_label.size = Vector2(520, 40)
	_replay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_replay_label.add_theme_font_size_override("font_size", 26)
	_replay_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_replay_label.visible = false
	root.add_child(_replay_label)

static func should_show_touch_controls() -> bool:
	if OS.get_environment("FUTBOL5_TOUCH") == "1":
		return true
	return OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()

func bind(match_manager: MatchManager) -> void:
	manager = match_manager
	manager.score_changed.connect(_on_score)
	manager.clock_changed.connect(func(t: float) -> void: _clock_label.text = MatchManager.format_clock(t))
	manager.message.connect(show_message)
	manager.state_changed.connect(_on_state_changed)
	_on_score(manager.score[0], manager.score[1])

func _charges() -> Dictionary:
	return charge_provider.call() if charge_provider.is_valid() else {}

func _build_scoreboard(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-150, 12)
	root.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	panel.add_child(hb)
	_score_label = Label.new()
	_score_label.text = "LOC 0 - 0 VIS"
	_score_label.add_theme_font_size_override("font_size", 30)
	hb.add_child(_score_label)
	_clock_label = Label.new()
	_clock_label.text = "00:00"
	_clock_label.add_theme_font_size_override("font_size", 30)
	hb.add_child(_clock_label)

func _build_message(root: Control) -> void:
	_message_label = Label.new()
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_message_label.position = Vector2(-300, -120)
	_message_label.size = Vector2(600, 100)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 68)
	_message_label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	_message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_message_label.add_theme_constant_override("outline_size", 10)
	_message_label.modulate.a = 0.0
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_message_label)
	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.position = Vector2(-300, -48)
	_hint_label.size = Vector2(600, 30)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_label)

func _build_pause_menu(root: Control) -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause_panel.custom_minimum_size = Vector2(760, 0)
	_pause_panel.position = Vector2(-380, -320)
	_pause_panel.visible = false
	root.add_child(_pause_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_pause_panel.add_child(vb)
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	vb.add_child(title)
	# Con las opciones de rendimiento los botones ya no caben en 720 de alto: la grilla se desplaza con el dedo.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	ScrollTap.watch(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	_add_menu_button(grid, "resume", "Continuar", func() -> void: manager.toggle_pause())
	_add_menu_button(grid, "restart_play", "Reiniciar jugada", func() -> void: _close_pause(); restart_play_requested.emit())
	_add_menu_button(grid, "restart_match", "Reiniciar partido", func() -> void: _close_pause(); restart_match_requested.emit())
	_add_menu_button(grid, "training", "", func() -> void: _close_pause(); training_toggle_requested.emit())
	_add_menu_button(grid, "practice", "Práctica de animaciones", func() -> void: _close_pause(); practice_requested.emit())
	_add_menu_button(grid, "graphics", "", func() -> void: _cycle_graphics())
	_add_menu_button(grid, "resolution", "", func() -> void: GraphicsSettings.cycle_resolution(); _refresh_menu_labels())
	_add_menu_button(grid, "fps_cap", "", func() -> void: GraphicsSettings.cycle_fps_cap(); _refresh_menu_labels())
	_add_menu_button(grid, "shadows", "", func() -> void: GraphicsSettings.cycle_shadows(); _refresh_menu_labels())
	_add_menu_button(grid, "diagnostics", "", func() -> void: _toggle_diagnostics())
	_add_menu_button(grid, "assist_pass", "", func() -> void: _cycle_assist("pass"))
	_add_menu_button(grid, "assist_shot", "", func() -> void: _cycle_assist("shot"))
	_add_menu_button(grid, "assist_press", "", func() -> void: _cycle_assist("press"))
	_add_menu_button(grid, "minutes", "", func() -> void: _cycle_minutes())
	_add_menu_button(grid, "touch_scale", "", func() -> void: _cycle_touch(&"scale"))
	_add_menu_button(grid, "joy_sens", "", func() -> void: _cycle_touch(&"sens"))
	_add_menu_button(grid, "camera_zoom", "", func() -> void: _cycle_camera_zoom())
	_add_menu_button(grid, "sound", "", func() -> void: _toggle_sound())
	_add_menu_button(grid, "gameplay_mode", "", func() -> void: _cycle_gameplay_mode())
	# Reforma (tiros libres y penales): vuelta al menu de desarrollo, desde donde se abre el banco de pruebas.
	_add_menu_button(grid, "dev_menu", "Menú de desarrollo", func() -> void: _close_pause(); get_tree().paused = false; get_tree().change_scene_to_file(DevMenu.SCENE))
	_add_menu_button(grid, "quit", "Salir", func() -> void: _close_pause(); quit_requested.emit())
	_refresh_menu_labels()

func _add_menu_button(parent: Container, key: String, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	parent.add_child(b)
	_pause_buttons[key] = b

func _level_index(v: float) -> int:
	var best: int = 0
	var best_d: float = 9.0
	for k in AssistTuning.LEVEL_VALUES.keys():
		var d: float = absf(AssistTuning.LEVEL_VALUES[k] - v)
		if d < best_d:
			best_d = d
			best = k
	return best

func _refresh_menu_labels() -> void:
	(_pause_buttons["graphics"] as Button).text = "Gráficos: %s (res. 3D %d %%)" % [GraphicsSettings.profile_name(), int(round(get_tree().root.scaling_3d_scale * 100.0))]
	(_pause_buttons["resolution"] as Button).text = "Resolución: %d %%" % int(round(GraphicsSettings.resolution_override * 100.0))
	(_pause_buttons["fps_cap"] as Button).text = "Imágenes por segundo: %d%s" % [GraphicsSettings.fps_cap, " (estables)" if GraphicsSettings.fps_cap < 60 else ""]
	(_pause_buttons["shadows"] as Button).text = "Sombras: %s" % ["No", "Sí", "según gráficos (%s)" % ("sí" if GraphicsSettings.shadows_enabled() else "no")][GraphicsSettings.shadows_mode if GraphicsSettings.shadows_mode >= 0 else 2]
	(_pause_buttons["assist_pass"] as Button).text = "Asistencia de pase: %s" % LEVEL_NAMES[_level_index(Tuning.assist.pass_assist)]
	(_pause_buttons["assist_shot"] as Button).text = "Asistencia de tiro: %s" % LEVEL_NAMES[_level_index(Tuning.assist.shot_assist)]
	(_pause_buttons["assist_press"] as Button).text = "Asistencia de presión: %s" % LEVEL_NAMES[_level_index(Tuning.assist.press_assist)]
	(_pause_buttons["minutes"] as Button).text = "Duración del partido: %d min" % Tuning.match_minutes
	(_pause_buttons["touch_scale"] as Button).text = "Tamaño de botones: %s" % ["Pequeño", "Normal", "Grande"][_nearest_index(TOUCH_SCALES, Tuning.touch_scale)]
	(_pause_buttons["joy_sens"] as Button).text = "Sensibilidad del joystick: %s" % THREE_NAMES[_nearest_index(JOY_SENS, Tuning.joystick_sensitivity)]
	(_pause_buttons["camera_zoom"] as Button).text = "Zoom de cámara: %s" % Tuning.CAMERA_ZOOM_NAMES[_nearest_index(Tuning.CAMERA_ZOOMS, Tuning.camera_zoom)]
	(_pause_buttons["sound"] as Button).text = "Sonido: %s" % ("Sí" if Tuning.sound_on else "No")
	(_pause_buttons["gameplay_mode"] as Button).text = "Modo de juego: %s" % Tuning.GAMEPLAY_MODE_NAMES.get(Tuning.gameplay_mode, str(Tuning.gameplay_mode))
	# Con un solo modo jugable no hay nada que elegir: el boton no se muestra (no ofrece los modos descartados).
	(_pause_buttons["gameplay_mode"] as Button).visible = Tuning.PLAYABLE_MODES.size() > 1
	(_pause_buttons["training"] as Button).text = "Volver al partido" if MatchScene.training_mode else "Entrenamiento sin rivales"
	(_pause_buttons["diagnostics"] as Button).text = "Diagnóstico: %s" % ("ACTIVADO" if Tuning.show_diagnostics else "desactivado")

## Tamano de la botonera y sensibilidad del joystick (preferencias tactiles; se guardan con las demas).
const TOUCH_SCALES := [0.85, 1.0, 1.2]
const JOY_SENS := [0.8, 1.0, 1.3]
const THREE_NAMES := ["Bajo", "Normal", "Alto"]

func _nearest_index(values: Array, v: float) -> int:
	var best: int = 0
	for i in values.size():
		if absf(float(values[i]) - v) < absf(float(values[best]) - v):
			best = i
	return best

func _cycle_touch(kind: StringName) -> void:
	if kind == &"scale":
		Tuning.touch_scale = TOUCH_SCALES[(_nearest_index(TOUCH_SCALES, Tuning.touch_scale) + 1) % TOUCH_SCALES.size()]
	else:
		Tuning.joystick_sensitivity = JOY_SENS[(_nearest_index(JOY_SENS, Tuning.joystick_sensitivity) + 1) % JOY_SENS.size()]
	Tuning.save_user_settings()
	if touch != null:
		touch.queue_redraw()
	_refresh_menu_labels()

## Zoom de la camara (se aplica en el acto, con el suavizado de la camara, y se guarda).
func _cycle_camera_zoom() -> void:
	var opts: Array = Tuning.CAMERA_ZOOMS
	Tuning.camera_zoom = opts[(_nearest_index(opts, Tuning.camera_zoom) + 1) % opts.size()]
	Tuning.save_user_settings()
	_refresh_menu_labels()

## Modo de jugabilidad entre los jugables (Tuning.PLAYABLE_MODES; hoy solo el 4, y el boton no se muestra): se guarda y el
## partido se vuelve a montar (cada modo tiene sus modelos y clips).
func _cycle_gameplay_mode() -> void:
	var opts: Array = Tuning.PLAYABLE_MODES
	Tuning.gameplay_mode = opts[(opts.find(Tuning.gameplay_mode) + 1) % opts.size()]
	Tuning.save_user_settings()
	_refresh_menu_labels()
	gameplay_mode_changed.emit()

## Sonido del partido: se apaga o enciende en el acto (publico incluido) y se guarda.
func _toggle_sound() -> void:
	Tuning.sound_on = not Tuning.sound_on
	Tuning.save_user_settings()
	Sfx.set_enabled(Tuning.sound_on)
	_refresh_menu_labels()

## Duracion del partido: se guarda y se aplica al reiniciar el partido (el reloj del partido en curso no cambia).
func _cycle_minutes() -> void:
	var opts: Array = Tuning.MATCH_MINUTES
	Tuning.match_minutes = opts[(opts.find(Tuning.match_minutes) + 1) % opts.size()]
	Tuning.save_user_settings()
	if manager != null:
		manager.duration_seconds = float(Tuning.match_minutes) * 60.0
	_refresh_menu_labels()

func _cycle_graphics() -> void:
	GraphicsSettings.set_profile((GraphicsSettings.profile + 1) % 4)
	_refresh_menu_labels()

func _cycle_assist(kind: String) -> void:
	var cfg: AssistTuning = Tuning.assist
	var current: float = cfg.get("%s_assist" % kind)
	var idx: int = (_level_index(current) + 1) % 4
	cfg.set("%s_assist" % kind, AssistTuning.LEVEL_VALUES[idx])
	Tuning.save_user_settings()
	_refresh_menu_labels()

func _toggle_diagnostics() -> void:
	Tuning.show_diagnostics = not Tuning.show_diagnostics
	diagnostics.visible = Tuning.show_diagnostics
	Tuning.save_user_settings()
	_refresh_menu_labels()

func _close_pause() -> void:
	if manager != null and manager.state == MatchManager.State.PAUSED:
		manager.toggle_pause()

func _on_pause_pressed() -> void:
	if manager != null:
		manager.toggle_pause()

func show_replay(on: bool) -> void:
	if _replay_label != null:
		_replay_label.visible = on
	if touch != null:
		touch.visible = (not on) and should_show_touch_controls()
		if on:
			touch.release_all()

func _input(event: InputEvent) -> void:
	if _replay_label != null and _replay_label.visible and event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		if replay_skip.is_valid():
			replay_skip.call()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and manager != null:
		manager.toggle_pause()
		get_viewport().set_input_as_handled()

func _on_state_changed(s: int) -> void:
	_pause_panel.visible = (s == MatchManager.State.PAUSED)
	if s == MatchManager.State.PAUSED:
		touch.release_all()
		_refresh_menu_labels()

func _on_score(home: int, away: int) -> void:
	_score_label.text = "LOC %d - %d VIS" % [home, away]

func show_message(text: String, seconds: float) -> void:
	_message_label.text = text
	if _message_tween != null:
		_message_tween.kill()
	_message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(maxf(seconds - 0.4, 0.2))
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.4)

func set_hint(text: String) -> void:
	_hint_label.text = text
