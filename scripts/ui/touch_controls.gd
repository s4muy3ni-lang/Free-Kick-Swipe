class_name TouchControls
extends Control
## Controles tactiles: joystick flotante (mitad izquierda) y botones que inyectan acciones REALES de
## InputMap (move_*, pass, shoot, sprint, press, lob, skill, switch_player). Multitoque: cada dedo se asigna
## al joystick o a un boton. El pause solo emite una senal.
## Todo se dibuja por codigo (sin texturas) para mantener el HUD ligero.

signal pause_pressed

const JOY_RADIUS: float = 95.0
const JOY_DEADZONE: float = 0.12
const FONT_SIZE: int = 22

class TouchButton:
	extends RefCounted
	var id: StringName
	var label: String
	var action: StringName          # accion de InputMap ("" para pausa)
	var anchor: Vector2             # posicion relativa a la esquina inferior derecha (px de lienzo)
	var radius: float
	var color: Color
	var pressed: bool = false
	var touch_index: int = -1
	var visible_when: Callable = Callable()
	var charge_key: StringName = &""
	## Situaciones en las que el boton existe (ver TouchControls.context). Vacio = siempre.
	var contexts: Array[StringName] = []

var buttons: Array[TouchButton] = []
## Devuelve {"pass": 0..1, "shoot": 0..1} para dibujar los anillos de carga.
var charge_source: Callable = Callable()
var show_switch: bool = false
## Situacion de juego del equipo de la persona: &"attack" (tiene la pelota o le llega un pase), &"defense" (la tiene
## el rival) o &"loose" (nadie). Cada boton se muestra solo donde su accion hace algo: en defensa los huecos de TIRO y
## PASE pasan a ENTRADA y PRESION (como el mando: un boton, dos usos), y la botonera ocupa menos pantalla.
var context: StringName = &"attack":
	set(v):
		if v != context:
			context = v
			queue_redraw()

var _joy_index: int = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_pos: Vector2 = Vector2.ZERO
var _joy_vec: Vector2 = Vector2.ZERO
var _default_joy_center: Vector2 = Vector2(190, 520)
var _held_move: Dictionary = {"move_left": 0.0, "move_right": 0.0, "move_up": 0.0, "move_down": 0.0}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_buttons()
	resized.connect(queue_redraw)

func _build_buttons() -> void:
	InputBindings.ensure()
	buttons.clear()
	# Arco compacto alrededor del pulgar derecho. En ataque: tiro, pase, filtrado y centro (+ sprint, alto, regate). En
	# defensa los mismos huecos son entrada y presion; con la pelota suelta, tiro/pase (golpeo de primera) y presion.
	var atk: Array[StringName] = [&"attack"]
	var atk_loose: Array[StringName] = [&"attack", &"loose"]
	var def: Array[StringName] = [&"defense"]
	_add(&"shoot", "TIRO", &"shoot", Vector2(-130, -130), 68.0, Color(0.95, 0.25, 0.2), &"shoot").contexts = atk_loose
	_add(&"pass", "PASE", &"pass", Vector2(-285, -85), 58.0, Color(0.2, 0.8, 0.35), &"pass").contexts = atk_loose
	_add(&"through", "FILTRADO", &"through_pass", Vector2(-275, -225), 48.0, Color(0.15, 0.65, 0.9), &"through").contexts = atk
	_add(&"cross", "CENTRO", &"cross", Vector2(-140, -285), 48.0, Color(0.95, 0.85, 0.2), &"cross").contexts = atk
	_add(&"tackle", "ENTRADA", &"tackle", Vector2(-130, -130), 62.0, Color(0.9, 0.35, 0.55)).contexts = def
	_add(&"press", "PRESIÓN", &"press", Vector2(-285, -85), 58.0, Color(0.95, 0.7, 0.15)).contexts = def
	_add(&"press_loose", "PRESIÓN", &"press", Vector2(-275, -225), 46.0, Color(0.95, 0.7, 0.15)).contexts = [&"loose"] as Array[StringName]
	_add(&"sprint", "SPRINT", &"sprint", Vector2(-425, -80), 48.0, Color(0.25, 0.55, 0.95))
	_add(&"lob", "ALTO", &"lob", Vector2(-410, -210), 40.0, Color(0.7, 0.45, 0.95)).contexts = atk
	_add(&"skill", "REGATE", &"skill", Vector2(-405, -340), 40.0, Color(0.95, 0.5, 0.15)).contexts = atk
	var sw := _add(&"switch", "CAMBIO", &"switch_player", Vector2(-545, -88), 40.0, Color(0.3, 0.85, 0.85))
	sw.visible_when = func() -> bool: return show_switch
	var pause := _add(&"pause", "II", &"", Vector2(-60, 0), 28.0, Color(0.85, 0.85, 0.85))
	pause.anchor = Vector2(-60, 0)   # arriba a la derecha (ver _button_center)

func _add(id: StringName, text: String, action: StringName, anchor: Vector2, radius: float, color: Color, charge_key: StringName = &"") -> TouchButton:
	var b := TouchButton.new()
	b.id = id
	b.label = text
	b.action = action
	b.anchor = anchor
	b.radius = radius
	b.color = color
	b.charge_key = charge_key
	buttons.append(b)
	return b

func _button_center(b: TouchButton) -> Vector2:
	if b.id == &"pause":
		return Vector2(size.x + b.anchor.x, 52.0)
	return Vector2(size.x + b.anchor.x * _scale(), size.y + b.anchor.y * _scale())

## Escala de la botonera (preferencia del usuario: botones pequenos, normales o grandes).
func _scale() -> float:
	return Tuning.touch_scale if Tuning != null else 1.0

func _radius(b: TouchButton) -> float:
	return b.radius * (_scale() if b.id != &"pause" else 1.0)

## Radio del joystick: con mas sensibilidad basta un recorrido menor del pulgar para llegar al maximo.
func joy_radius() -> float:
	return JOY_RADIUS / (Tuning.joystick_sensitivity if Tuning != null else 1.0)

## Centro (en coordenadas del control) de un boton por id. Util para pruebas.
func get_button_center(id: StringName) -> Vector2:
	for b in buttons:
		if b.id == id:
			return _button_center(b)
	return Vector2.ZERO

func is_button_pressed(id: StringName) -> bool:
	for b in buttons:
		if b.id == id:
			return b.pressed
	return false

func _button_visible(b: TouchButton) -> bool:
	if not b.contexts.is_empty() and not b.contexts.has(context) and not b.pressed:
		return false   # un boton mantenido sigue vivo hasta soltarlo aunque cambie la situacion
	return not b.visible_when.is_valid() or b.visible_when.call()

# --- Entrada ---------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = _local_pos((event as InputEventScreenTouch).position)
		if event.pressed:
			_touch_down(event.index, pos)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, _local_pos((event as InputEventScreenDrag).position))

func _local_pos(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p

func _touch_down(index: int, pos: Vector2) -> void:
	for b in buttons:
		if not _button_visible(b) or b.touch_index != -1:
			continue
		if pos.distance_to(_button_center(b)) <= _radius(b) * 1.2:
			b.touch_index = index
			b.pressed = true
			if b.action != &"":
				Input.action_press(b.action)
			else:
				pause_pressed.emit()
			queue_redraw()
			return
	if _joy_index == -1 and pos.x < size.x * 0.55 and pos.y > size.y * 0.18:
		_joy_index = index
		_joy_origin = pos
		_joy_pos = pos
		_update_joystick()
		queue_redraw()

func _touch_drag(index: int, pos: Vector2) -> void:
	if index == _joy_index:
		_joy_pos = pos
		_update_joystick()
		queue_redraw()

func _touch_up(index: int) -> void:
	for b in buttons:
		if b.touch_index == index:
			b.touch_index = -1
			b.pressed = false
			if b.action != &"":
				Input.action_release(b.action)
			queue_redraw()
	if index == _joy_index:
		_joy_index = -1
		_joy_vec = Vector2.ZERO
		_apply_move(Vector2.ZERO)
		queue_redraw()

func _update_joystick() -> void:
	var d: Vector2 = _joy_pos - _joy_origin
	var len: float = d.length()
	# El origen sigue al dedo si se aleja demasiado (joystick flotante comodo con el pulgar).
	var jr: float = joy_radius()
	if len > jr * 1.6:
		_joy_origin += d.normalized() * (len - jr * 1.6)
		d = _joy_pos - _joy_origin
		len = d.length()
	var m: float = clampf(len / jr, 0.0, 1.0)
	if m < JOY_DEADZONE:
		_joy_vec = Vector2.ZERO
	else:
		m = (m - JOY_DEADZONE) / (1.0 - JOY_DEADZONE)
		_joy_vec = d.normalized() * m
	_apply_move(_joy_vec)

## Traduce el vector analogico a las cuatro acciones de movimiento con su intensidad.
func _apply_move(v: Vector2) -> void:
	_set_axis("move_right", maxf(v.x, 0.0))
	_set_axis("move_left", maxf(-v.x, 0.0))
	_set_axis("move_down", maxf(v.y, 0.0))
	_set_axis("move_up", maxf(-v.y, 0.0))

func _set_axis(action: String, strength: float) -> void:
	if strength > 0.001:
		Input.action_press(action, strength)
	elif _held_move[action] > 0.0:
		Input.action_release(action)
	_held_move[action] = strength

func release_all() -> void:
	_joy_index = -1
	_joy_vec = Vector2.ZERO
	_apply_move(Vector2.ZERO)
	for b in buttons:
		if b.pressed and b.action != &"":
			Input.action_release(b.action)
		b.pressed = false
		b.touch_index = -1
	queue_redraw()

## Vector del joystick actual (para pruebas y diagnostico).
func joystick_vector() -> Vector2:
	return _joy_vec

# --- Dibujo ----------------------------------------------------------------

func _process(_delta: float) -> void:
	# Los anillos de carga cambian cada fotograma mientras se mantiene un boton.
	for b in buttons:
		if b.pressed and b.charge_key != &"":
			queue_redraw()
			return

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var charges: Dictionary = charge_source.call() if charge_source.is_valid() else {}
	# Joystick: base tenue siempre visible para indicar donde tocar.
	var base_center: Vector2 = _joy_origin if _joy_index != -1 else _default_joy_center_for_size()
	var jr: float = joy_radius()
	draw_circle(base_center, jr, Color(1, 1, 1, 0.08))
	draw_arc(base_center, jr, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	var knob: Vector2 = base_center + _joy_vec * jr
	draw_circle(knob, 38.0, Color(1, 1, 1, 0.35 if _joy_index != -1 else 0.15))
	for b in buttons:
		if not _button_visible(b):
			continue
		var c: Vector2 = _button_center(b)
		var rad: float = _radius(b)
		var a: float = 0.55 if b.pressed else 0.28
		draw_circle(c, rad, Color(b.color.r, b.color.g, b.color.b, a))
		draw_arc(c, rad, 0.0, TAU, 40, Color(b.color.r, b.color.g, b.color.b, 0.9), 3.0, true)
		if b.charge_key != &"" and charges.has(String(b.charge_key)):
			var ch: float = float(charges[String(b.charge_key)])
			if ch > 0.01:
				draw_arc(c, rad + 8.0, -PI * 0.5, -PI * 0.5 + TAU * ch, 48, Color(1, 1, 1, 0.95), 6.0, true)
		var fs: int = FONT_SIZE if rad > 50.0 else (17 if rad > 42.0 else 14)
		var ts: Vector2 = font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, c + Vector2(-ts.x * 0.5, ts.y * 0.3), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))

func _default_joy_center_for_size() -> Vector2:
	return Vector2(190.0, size.y - 200.0)
