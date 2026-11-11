class_name WelcomeScreen
extends Node3D
## Entrada del juego (pedido del usuario: para jugar, online u offline, hay que iniciar sesion). Estadio de noche de
## fondo con la camara girando y una tarjeta: iniciar sesion, crear cuenta, recuperar contraseña, recordar sesion. La
## primera vez pide el nombre de usuario y el nombre visible (crea el perfil en el servidor). Con una sesion guardada
## entra directo; sin conexion entra igual con la sesion y el ultimo estado (modo offline).

const SCENE := "res://scenes/online/welcome.tscn"

var stadium: Stadium11
var cam: Camera3D
var _t: float = 0.0
var _card: PanelContainer
var _box: VBoxContainer
var _status: Label
var _error: Label
var _email: LineEdit
var _pass: LineEdit
var _remember: CheckBox
var _user: LineEdit
var _display: LineEdit
var _busy: bool = false
## Las pruebas no cambian de escena al terminar.
var go_to_menu: bool = true
signal finished

func _ready() -> void:
	stadium = Stadium11.new()
	add_child(stadium)
	stadium.build(PitchConfig.football11(SpSettings.goal_style))
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	_build_ui()
	GraphicsSettings.apply()
	_start.call_deferred()

func _process(delta: float) -> void:
	_t += delta
	var gx: float = stadium.half_length()
	var a: float = 2.4 + _t * 0.05
	cam.global_position = Vector3(gx - 10.0, 0, 0) + Vector3(cos(a) * 20.0, 6.0, sin(a) * 20.0)
	cam.look_at(Vector3(gx - 4.0, 1.0, 0.0), Vector3.UP)

func _start() -> void:
	if Online.signed_in():
		_show_message("Entrando...")
		if await Online.restore_session():
			await _after_login()
			return
	_show_login()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.make()
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.02, 0.08, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var title := Label.new()
	title.text = "FREE KICK SWIPE"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	title.add_theme_constant_override("outline_size", 14)
	title.position = Vector2(48, 36)
	root.add_child(title)
	var sub := Label.new()
	sub.text = "Penales, tiros libres y minijuegos · online y offline"
	sub.add_theme_font_size_override("font_size", 24)
	sub.position = Vector2(52, 120)
	root.add_child(sub)
	_status = Label.new()
	_status.position = Vector2(52, 660)
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.75, 0.82, 1.0))
	root.add_child(_status)
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.position.x -= 60
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.12, 0.93)
	sb.border_color = Color(1.0, 0.84, 0.28, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(26)
	_card.add_theme_stylebox_override("panel", sb)
	root.add_child(_card)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_box.custom_minimum_size = Vector2(440, 0)
	_card.add_child(_box)
	_status.text = Online.backend_label()

func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()
	_error = null

func _label(text: String, size: int = 22, color := Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)
	return l

func _field(placeholder: String, secret: bool = false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 56)
	e.add_theme_font_size_override("font_size", 24)
	_box.add_child(e)
	return e

func _button(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58 if primary else 46)
	b.add_theme_font_size_override("font_size", 26 if primary else 20)
	b.pressed.connect(cb)
	_box.add_child(b)
	return b

func _error_label() -> void:
	_error = _label("", 20, Color(1.0, 0.5, 0.45))

func _show_message(text: String) -> void:
	_clear()
	_label(text, 26)

func _show_login() -> void:
	_clear()
	_label("Iniciá sesión", 32, Color(1.0, 0.84, 0.28))
	_email = _field("Correo")
	_pass = _field("Contraseña", true)
	_remember = CheckBox.new()
	_remember.text = "Recordar sesión"
	_remember.button_pressed = true
	_box.add_child(_remember)
	_error_label()
	_button("ENTRAR", _on_sign_in, true)
	_button("Crear cuenta", _show_sign_up)
	_button("Olvidé mi contraseña", _on_recover)

func _show_sign_up() -> void:
	_clear()
	_label("Crear cuenta", 32, Color(1.0, 0.84, 0.28))
	_email = _field("Correo")
	_pass = _field("Contraseña (mínimo 8 caracteres)", true)
	_remember = CheckBox.new()
	_remember.text = "Recordar sesión"
	_remember.button_pressed = true
	_box.add_child(_remember)
	_error_label()
	_button("CREAR CUENTA", _on_sign_up, true)
	_button("Ya tengo cuenta", _show_login)

func _show_profile() -> void:
	_clear()
	_label("Tu perfil", 32, Color(1.0, 0.84, 0.28))
	_label("Elegí tu nombre de usuario (3 a 16 letras, números o _) y cómo querés que te vean.", 18)
	_user = _field("Nombre de usuario")
	_display = _field("Nombre visible")
	_error_label()
	_button("EMPEZAR", _on_create_profile, true)

func _set_error(t: String) -> void:
	if _error != null:
		_error.text = t

func _on_sign_in() -> void:
	if _busy:
		return
	_busy = true
	_set_error("")
	var r: Dictionary = await Online.sign_in(_email.text, _pass.text, _remember.button_pressed)
	_busy = false
	if not r.get("ok", false):
		_set_error(String(r.get("error", "No se pudo iniciar sesión.")))
		return
	await _after_login()

func _on_sign_up() -> void:
	if _busy:
		return
	_busy = true
	_set_error("")
	var r: Dictionary = await Online.sign_up(_email.text, _pass.text, _remember.button_pressed)
	_busy = false
	if not r.get("ok", false):
		_set_error(String(r.get("error", "No se pudo crear la cuenta.")))
		return
	if r.get("needs_verification", false):
		_show_login()
		_set_error("Te mandamos un correo para verificar la cuenta. Confirmalo y después iniciá sesión.")
		return
	await _after_login()

func _on_recover() -> void:
	if _email == null or _email.text.strip_edges() == "":
		_set_error("Escribí tu correo y tocá de nuevo «Olvidé mi contraseña».")
		return
	var r: Dictionary = await Online.recover(_email.text)
	_set_error("Si el correo existe, te llega un enlace para cambiar la contraseña." if r.get("ok", false)
		else String(r.get("error", "No se pudo enviar el correo.")))

func _on_create_profile() -> void:
	if _busy:
		return
	_busy = true
	var r: Dictionary = await Online.call_state_fn("create_profile", {"p_username": _user.text.strip_edges(),
		"p_display_name": _display.text.strip_edges()})
	_busy = false
	if not r.get("ok", false):
		_set_error(String(r.get("error", "No se pudo crear el perfil.")))
		return
	_enter()

func _after_login() -> void:
	_status.text = Online.backend_label()
	if not Online.has_profile():
		if Online.offline:
			_show_message("Sin conexión y sin perfil guardado: conectate una vez para crear tu perfil.")
			return
		_show_profile()
		return
	_enter()

func _enter() -> void:
	finished.emit()
	if go_to_menu:
		get_tree().change_scene_to_file(MainMenu.SCENE)
