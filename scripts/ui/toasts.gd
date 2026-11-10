extends CanvasLayer
## Autoload «Toasts»: carteles breves arriba al centro (logros y desafios completados). Cola: se muestran de a uno,
## TOAST_T segundos cada uno, con entrada y salida suaves. No bloquea nada; en headless solo acumula.

const TOAST_T := 2.8

var _queue: Array = []
var _panel: PanelContainer
var _title: Label
var _sub: Label
var _t: float = -1.0
## Para las pruebas: cuantos carteles se pidieron.
var shown: int = 0

func _ready() -> void:
	layer = 30
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.13, 0.94)
	sb.border_color = Color(1.0, 0.84, 0.28, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.position.y = 14
	var vb := VBoxContainer.new()
	_panel.add_child(vb)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 18)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_sub)
	_panel.visible = false
	add_child(_panel)

func push(title: String, sub: String) -> void:
	shown += 1
	_queue.append([title, sub])

func pending() -> int:
	return _queue.size() + (1 if _t >= 0.0 else 0)

func _process(delta: float) -> void:
	if _t >= 0.0:
		_t += delta
		var a: float = clampf(_t / 0.25, 0.0, 1.0) * clampf((TOAST_T - _t) / 0.35, 0.0, 1.0)
		_panel.modulate.a = a
		_panel.position.y = 14.0 - (1.0 - clampf(_t / 0.25, 0.0, 1.0)) * 30.0
		if _t >= TOAST_T:
			_t = -1.0
			_panel.visible = false
		return
	if not _queue.is_empty():
		var e: Array = _queue.pop_front()
		_title.text = e[0]
		_sub.text = e[1]
		_panel.visible = true
		_panel.modulate.a = 0.0
		_t = 0.0
