class_name UiTheme
extends RefCounted
## Tema visual minimo y coherente (sin texturas): paneles oscuros, botones grandes aptos para tactil.

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	var normal := _box(Color(0.12, 0.17, 0.26, 0.92), Color(0.35, 0.5, 0.8, 0.9), 2, 10)
	var hover := _box(Color(0.17, 0.25, 0.4, 0.95), Color(0.5, 0.7, 1.0, 1.0), 2, 10)
	var pressed := _box(Color(0.25, 0.4, 0.65, 1.0), Color(0.7, 0.85, 1.0, 1.0), 2, 10)
	for style_name in ["normal", "focus"]:
		t.set_stylebox(style_name, "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_color("font_color", "Button", Color(0.95, 0.97, 1.0))
	t.set_font_size("font_size", "Button", 26)
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.06, 0.09, 0.15, 0.94), Color(0.3, 0.45, 0.75, 0.9), 3, 16))
	t.set_color("font_color", "Label", Color(0.95, 0.97, 1.0))
	t.set_font_size("font_size", "Label", 24)
	return t

static func _box(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s
