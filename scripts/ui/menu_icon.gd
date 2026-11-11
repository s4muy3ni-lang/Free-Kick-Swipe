class_name MenuIcon
extends Control
## Iconos del menu dibujados con primitivas (sin imagenes ni emojis: la fuente del juego no tiene emojis y asi pesan
## nada). Cada seccion y cada modalidad tiene el suyo.

var kind: String = "ball"
var tint: Color = Color(1, 1, 1)

func _init(k: String = "ball", c: Color = Color(1, 1, 1), sz: float = 64.0) -> void:
	kind = k
	tint = c
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	var r: float = s * 0.42
	var w: float = maxf(s * 0.06, 2.0)
	var dark := Color(0.05, 0.06, 0.1)
	match kind:
		"ball", "offline":
			draw_circle(c, r, Color(0.97, 0.97, 0.97))
			_poly_reg(c, r * 0.36, 5, dark, -PI / 2)
			for i in 5:
				var a: float = -PI / 2 + i * TAU / 5
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.36, c + Vector2(cos(a), sin(a)) * r * 0.95, dark, w * 0.6)
			draw_arc(c, r, 0, TAU, 40, dark, w * 0.5)
		"online":
			draw_arc(c, r, 0, TAU, 48, tint, w)
			draw_line(c - Vector2(r, 0), c + Vector2(r, 0), tint, w * 0.7)
			draw_line(c - Vector2(0, r), c + Vector2(0, r), tint, w * 0.7)
			_ellipse(c, Vector2(r * 0.45, r), tint, w * 0.7)
			_ellipse(c, Vector2(r, r * 0.45), tint, w * 0.5)
		"academia", "dardos":
			for i in 4:
				draw_circle(c, r * (1.0 - i * 0.24), [tint, Color(1, 1, 1), tint, Color(1, 0.85, 0.2)][i])
		"diana":
			for i in 4:
				_ellipse_fill(c + Vector2(0, r * 0.2), Vector2(r * (1.0 - i * 0.22), r * 0.5 * (1.0 - i * 0.22)),
					[tint, Color(1, 1, 1), tint, Color(1, 0.85, 0.2)][i])
		"desafios":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(r * 0.7, -r * 0.8),
				c + Vector2(r * 0.45, r * 0.05), c + Vector2(-r * 0.45, r * 0.05)]), Color(1.0, 0.8, 0.2))
			draw_rect(Rect2(c + Vector2(-r * 0.12, r * 0.05), Vector2(r * 0.24, r * 0.45)), Color(1.0, 0.8, 0.2))
			draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.5), Vector2(r, r * 0.25)), Color(0.85, 0.65, 0.15))
			draw_arc(c + Vector2(-r * 0.7, -r * 0.45), r * 0.3, PI / 2, PI * 1.5, 12, Color(1.0, 0.8, 0.2), w)
			draw_arc(c + Vector2(r * 0.7, -r * 0.45), r * 0.3, -PI / 2, PI / 2, 12, Color(1.0, 0.8, 0.2), w)
		"arcade", "temporada":
			_star(c, r, r * 0.45, Color(1.0, 0.84, 0.25) if kind == "temporada" else tint)
		"personalizar":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, -r * 0.8), c + Vector2(-r, -r * 0.45),
				c + Vector2(-r * 0.75, -r * 0.05), c + Vector2(-r * 0.5, -r * 0.2), c + Vector2(-r * 0.5, r * 0.85),
				c + Vector2(r * 0.5, r * 0.85), c + Vector2(r * 0.5, -r * 0.2), c + Vector2(r * 0.75, -r * 0.05),
				c + Vector2(r, -r * 0.45), c + Vector2(r * 0.35, -r * 0.8)]), tint)
			draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.4), Vector2(r * 0.24, r * 1.25)), Color(1, 1, 1, 0.85))
		"tienda":
			draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.35), Vector2(r * 1.5, r * 1.2)), tint)
			draw_arc(c + Vector2(0, -r * 0.35), r * 0.4, PI, TAU, 16, tint, w)
			draw_circle(c + Vector2(0, r * 0.25), r * 0.22, Color(1.0, 0.84, 0.25))
		"eventos":
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.6), Vector2(r * 1.6, r * 1.45)), Color(0.97, 0.97, 0.97))
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.6), Vector2(r * 1.6, r * 0.4)), tint)
			for i in 3:
				for j in 2:
					draw_rect(Rect2(c + Vector2(-r * 0.6 + i * r * 0.45, -r * 0.05 + j * r * 0.42), Vector2(r * 0.3, r * 0.28)), tint.darkened(0.2))
		"perfil":
			draw_circle(c + Vector2(0, -r * 0.35), r * 0.38, tint)
			draw_colored_polygon(_arc_poly(c + Vector2(0, r * 0.75), r * 0.8, PI, TAU), tint)
		"coin":
			draw_circle(c, r, Color(1.0, 0.78, 0.18))
			draw_arc(c, r * 0.72, 0, TAU, 32, Color(0.85, 0.6, 0.1), w)
			draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.45), Vector2(r * 0.24, r * 0.9)), Color(0.85, 0.6, 0.1))
		"penal":
			draw_rect(Rect2(c + Vector2(-r, -r * 0.55), Vector2(r * 2.0, r * 1.1)), tint, false, w)
			for i in 5:
				draw_line(c + Vector2(-r + i * r * 0.5, -r * 0.55), c + Vector2(-r + i * r * 0.5, r * 0.55), Color(1, 1, 1, 0.35), w * 0.4)
			draw_circle(c + Vector2(r * 0.35, r * 0.75), r * 0.16, Color(1, 1, 1))
		"tiro_libre":
			for i in 4:
				draw_rect(Rect2(c + Vector2(-r * 0.75 + i * r * 0.4, -r * 0.55), Vector2(r * 0.3, r * 1.1)), tint)
			draw_circle(c + Vector2(r * 0.8, -r * 0.75), r * 0.16, Color(1, 1, 1))
		"vacio":
			draw_rect(Rect2(c + Vector2(-r, -r * 0.1), Vector2(r * 0.8, r * 0.25)), tint)
			draw_rect(Rect2(c + Vector2(r * 0.2, -r * 0.1), Vector2(r * 0.8, r * 0.25)), tint)
			for i in 3:
				draw_line(c + Vector2(-r * 0.6, r * 0.15), c + Vector2(-r * 0.8 + i * 0.2 * r, r), Color(0.6, 0.62, 0.7), w * 0.6)
				draw_line(c + Vector2(r * 0.6, r * 0.15), c + Vector2(r * 0.4 + i * 0.2 * r, r), Color(0.6, 0.62, 0.7), w * 0.6)
			draw_circle(c + Vector2(r * 0.6, -r * 0.4), r * 0.2, Color(1, 0.2, 0.2))
		"guante":
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.6), Vector2(r * 1.1, r * 1.1)), tint)
			draw_circle(c + Vector2(-r * 0.05, -r * 0.6), r * 0.55, tint)
			draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.2), Vector2(r * 0.4, r * 0.5)), tint.darkened(0.15))
			draw_rect(Rect2(c + Vector2(-r * 0.6, r * 0.5), Vector2(r * 1.1, r * 0.3)), Color(1, 1, 1))
		"basket":
			_ellipse(c + Vector2(0, -r * 0.3), Vector2(r * 0.8, r * 0.25), Color(1.0, 0.45, 0.1), w * 1.2)
			for i in 5:
				var x: float = -r * 0.7 + i * r * 0.35
				draw_line(c + Vector2(x, -r * 0.25), c + Vector2(x * 0.6, r * 0.6), Color(1, 1, 1), w * 0.5)
			draw_circle(c + Vector2(r * 0.6, -r * 0.8), r * 0.2, Color(1, 1, 1))
		_:
			draw_circle(c, r, tint)

func _poly_reg(c: Vector2, r: float, n: int, col: Color, rot: float) -> void:
	var p := PackedVector2Array()
	for i in n:
		var a: float = rot + i * TAU / n
		p.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(p, col)

func _star(c: Vector2, ro: float, ri: float, col: Color) -> void:
	var p := PackedVector2Array()
	for i in 10:
		var a: float = -PI / 2 + i * PI / 5
		p.append(c + Vector2(cos(a), sin(a)) * (ro if i % 2 == 0 else ri))
	draw_colored_polygon(p, col)

func _ellipse(c: Vector2, rr: Vector2, col: Color, w: float) -> void:
	var p := PackedVector2Array()
	for i in 41:
		var a: float = i * TAU / 40
		p.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y))
	draw_polyline(p, col, w)

func _ellipse_fill(c: Vector2, rr: Vector2, col: Color) -> void:
	var p := PackedVector2Array()
	for i in 40:
		var a: float = i * TAU / 40
		p.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y))
	draw_colored_polygon(p, col)

func _arc_poly(c: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 21:
		var a: float = lerpf(a0, a1, i / 20.0)
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p
