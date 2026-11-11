class_name SpHud
extends CanvasLayer
## Interfaz de los modos de tiros libres y penales (horizontal; se adapta a cualquier proporcion sin deformar): marcador,
## mensajes de resultado, ayuda, trazo del dedo, botones contextuales y zoom. Pocos controles: la cancha y el tiro primero.

signal menu_pressed
signal action_pressed(id: StringName)
signal zoom_changed(delta: float)
signal diag_pressed

const GOLD := Color(1.0, 0.82, 0.25)
const BLUE := Color(0.25, 0.55, 1.0)
const RED := Color(1.0, 0.3, 0.3)

var root: Control
var title: Label
var score: Label
var dots_user: HBoxContainer
var dots_cpu: HBoxContainer
var banner: Label
var sub_banner: Label
var hint: Label
var actions: HBoxContainer
var zoom_box: VBoxContainer
var trail: Line2D
var overlay: PanelContainer
var overlay_title: Label
var overlay_text: Label
var overlay_actions: HBoxContainer
var _banner_t: float = 0.0
## Indicadores del trazo (abajo a la izquierda, solo mientras el dedo esta apoyado): potencia, altura, efecto y tipo.
var gesture_box: VBoxContainer
var _meters: Dictionary = {}
var gesture_type: Label

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)
	trail = Line2D.new()
	trail.width = 10.0
	trail.default_color = Color(1, 1, 1, 0.85)
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.1))
	grad.set_color(1, Color(1, 0.95, 0.6, 0.95))
	trail.gradient = grad
	root.add_child(trail)
	_build_top()
	_build_center()
	_build_bottom()
	_build_overlay()

func _label(size: int, color: Color = Color.WHITE, outline: int = 6) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _chip(bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _build_top() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 12
	top.add_theme_constant_override("separation", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var chip := _chip(Color(0.04, 0.07, 0.14, 0.82))
	top.add_child(chip)
	title = _label(24, GOLD, 4)
	chip.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	var board := _chip(Color(0.04, 0.07, 0.14, 0.82))
	top.add_child(board)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(vb)
	score = _label(26, Color.WHITE, 4)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(score)
	dots_user = HBoxContainer.new()
	dots_cpu = HBoxContainer.new()
	for d in [dots_user, dots_cpu]:
		d.add_theme_constant_override("separation", 6)
		d.alignment = BoxContainer.ALIGNMENT_CENTER
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(d)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer2)
	var diag := Button.new()
	diag.text = "Diag."
	diag.focus_mode = Control.FOCUS_NONE
	diag.custom_minimum_size = Vector2(90, 56)
	diag.add_theme_font_size_override("font_size", 18)
	diag.pressed.connect(func() -> void: diag_pressed.emit())
	# Solo en builds de desarrollo (DevFlags).
	diag.visible = DevFlags.tools_enabled()
	top.add_child(diag)
	var menu := Button.new()
	menu.text = "Menú"
	menu.focus_mode = Control.FOCUS_NONE
	menu.custom_minimum_size = Vector2(130, 56)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	top.add_child(menu)

func _build_center() -> void:
	var c := VBoxContainer.new()
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.anchor_top = 0.58
	c.anchor_bottom = 0.58
	c.offset_left = -500
	c.offset_right = 500
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	banner = _label(84, GOLD, 12)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.pivot_offset = Vector2(500, 50)
	c.add_child(banner)
	sub_banner = _label(28, Color.WHITE, 6)
	sub_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(sub_banner)
	banner.visible = false
	sub_banner.visible = false

func _build_bottom() -> void:
	# Abajo a la izquierda, sin pisar los botones de abajo a la derecha (texto largo: hasta dos renglones).
	hint = _label(22, Color(1, 1, 1, 0.95), 6)
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 22
	hint.offset_right = -450
	hint.offset_top = -100
	hint.offset_bottom = -18
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(hint)
	actions = HBoxContainer.new()
	actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.offset_left = -760
	actions.offset_right = -18
	actions.offset_top = -86
	actions.offset_bottom = -18
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)
	zoom_box = VBoxContainer.new()
	zoom_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	zoom_box.offset_left = -84
	zoom_box.offset_right = -16
	zoom_box.offset_top = -70
	zoom_box.offset_bottom = 70
	zoom_box.add_theme_constant_override("separation", 10)
	root.add_child(zoom_box)
	for z in [["+", 1.0], ["-", -1.0]]:
		var b := Button.new()
		b.text = z[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(64, 60)
		b.pressed.connect(func() -> void: zoom_changed.emit(float(z[1])))
		zoom_box.add_child(b)
	zoom_box.visible = false
	gesture_box = VBoxContainer.new()
	gesture_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	gesture_box.offset_left = 18
	gesture_box.offset_right = 300
	gesture_box.offset_top = -168
	gesture_box.offset_bottom = -76
	gesture_box.add_theme_constant_override("separation", 4)
	gesture_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gesture_box)
	gesture_type = _label(20, GOLD, 4)
	gesture_box.add_child(gesture_type)
	for m in [["Potencia", false], ["Altura", false], ["Efecto", true]]:
		gesture_box.add_child(_meter(m[0], m[1]))
	gesture_box.visible = false

## Barra discreta: etiqueta + fondo + relleno (centrada en 0 para el efecto).
func _meter(name_: String, centered: bool) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(16, Color.WHITE, 3)
	l.text = name_
	l.custom_minimum_size = Vector2(84, 0)
	hb.add_child(l)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.custom_minimum_size = Vector2(180, 12)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(bg)
	var fill := ColorRect.new()
	fill.color = Color(1.0, 0.85, 0.3)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	_meters[name_] = [bg, fill, centered]
	return hb

func _set_meter(name_: String, v: float, color: Color) -> void:
	var m: Array = _meters[name_]
	var bg: ColorRect = m[0]
	var fill: ColorRect = m[1]
	var w: float = bg.custom_minimum_size.x
	var h: float = bg.custom_minimum_size.y
	fill.color = color
	if bool(m[2]):
		var x: float = clampf(v, -1.0, 1.0)
		fill.position = Vector2(w * 0.5 + minf(x, 0.0) * w * 0.5, 0.0)
		fill.size = Vector2(absf(x) * w * 0.5 + 2.0, h)
	else:
		fill.position = Vector2.ZERO
		fill.size = Vector2(clampf(v, 0.0, 1.0) * w, h)

## Indicadores del trazo en curso. height01: altura de llegada / alto del arco; curl: -1..1 (+ se cierra a la izquierda).
func show_gesture(power: float, height01: float, curl: float, type_name: String) -> void:
	gesture_box.visible = true
	_set_meter("Potencia", power, TrajectoryPreview.power_color(power))
	_set_meter("Altura", height01, Color(0.45, 0.8, 1.0) if height01 <= 1.0 else Color(1.0, 0.4, 0.3))
	_set_meter("Efecto", curl, Color(0.9, 0.6, 1.0))
	gesture_type.text = type_name

func hide_gesture() -> void:
	gesture_box.visible = false

func _build_overlay() -> void:
	overlay = PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_CENTER)
	overlay.offset_left = -330
	overlay.offset_right = 330
	overlay.offset_top = -170
	overlay.offset_bottom = 170
	root.add_child(overlay)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vb)
	overlay_title = _label(52, GOLD, 8)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(overlay_title)
	overlay_text = _label(28, Color.WHITE, 4)
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(overlay_text)
	overlay_actions = HBoxContainer.new()
	overlay_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_actions.add_theme_constant_override("separation", 16)
	vb.add_child(overlay_actions)
	overlay.visible = false

func _process(delta: float) -> void:
	if banner.visible:
		_banner_t += delta
		var s: float = 1.0 + 0.25 * exp(-_banner_t * 6.0) * sin(_banner_t * 18.0)
		banner.scale = Vector2(s, s)

# --- API -----------------------------------------------------------------------------------------------------------------

func set_title(t: String) -> void:
	title.text = t

func set_hint(t: String) -> void:
	hint.text = t
	hint.visible = t != ""

func show_banner(text: String, color: Color, sub: String = "") -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	sub_banner.text = sub
	sub_banner.visible = sub != ""
	_banner_t = 0.0

func hide_banner() -> void:
	banner.visible = false
	sub_banner.visible = false

## Botones contextuales abajo a la derecha: [[id, texto], ...].
func set_actions(list: Array) -> void:
	for c in actions.get_children():
		c.queue_free()
	for a in list:
		var b := Button.new()
		b.text = String(a[1])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(200, 64)
		b.pressed.connect(func() -> void: action_pressed.emit(StringName(a[0])))
		actions.add_child(b)

func set_zoom_visible(v: bool) -> void:
	zoom_box.visible = v

func set_score_text(t: String) -> void:
	score.text = t

## Puntos de la tanda: true gol, false fallado; se completan hasta `slots` con circulos vacios.
func set_shootout(user: Array, cpu: Array, slots: int) -> void:
	for pair in [[dots_user, user, BLUE], [dots_cpu, cpu, RED]]:
		var box: HBoxContainer = pair[0]
		for c in box.get_children():
			c.queue_free()
		var tag := _label(18, pair[2], 3)
		tag.text = "TÚ " if box == dots_user else "CPU"
		tag.custom_minimum_size = Vector2(46, 0)
		box.add_child(tag)
		var res: Array = pair[1]
		for i in maxi(slots, res.size()):
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(20, 20)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(10)
			if i < res.size():
				sb.bg_color = Color(0.25, 0.95, 0.4) if res[i] else Color(1.0, 0.3, 0.3)
			else:
				sb.bg_color = Color(1, 1, 1, 0.08)
				sb.border_color = Color(1, 1, 1, 0.6)
				sb.set_border_width_all(2)
			dot.add_theme_stylebox_override("panel", sb)
			box.add_child(dot)
	dots_user.visible = true
	dots_cpu.visible = true

func hide_shootout() -> void:
	dots_user.visible = false
	dots_cpu.visible = false

func show_overlay(t: String, text: String, list: Array) -> void:
	overlay_title.text = t
	overlay_text.text = text
	for c in overlay_actions.get_children():
		c.queue_free()
	for a in list:
		var b := Button.new()
		b.text = String(a[1])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(220, 70)
		b.pressed.connect(func() -> void: action_pressed.emit(StringName(a[0])))
		overlay_actions.add_child(b)
	overlay.visible = true

func hide_overlay() -> void:
	overlay.visible = false

func set_trail(points: PackedVector2Array) -> void:
	trail.points = points
