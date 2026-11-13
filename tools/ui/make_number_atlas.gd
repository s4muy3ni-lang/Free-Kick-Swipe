extends Node
## Hoja de cifras del numero de la espalda (pedido del usuario 2026-11-12: «el numero de la camiseta esta separado de la
## camiseta»). El shader del uniforme del modelo de Tripo (player_kit.gdshader) lo imprime EN la tela con esta hoja, asi
## que se dobla y se mueve con la espalda. Diez celdas en fila (0..9) de CELL pixeles con la fuente por defecto de Godot
## (la misma del numero anterior), engrosada: canal R = relleno, canal G = relleno + borde (A = G).
## Salida: assets/characters/player/number_atlas.png. Uso: xvfb-run -a godot --display-driver x11 --rendering-driver
##   opengl3 --path . res://tools/ui/make_number_atlas.tscn

const OUT := "res://assets/characters/player/number_atlas.png"
const CELL := Vector2i(96, 160)
const FONT_SIZE := 122
const OUTLINE := 18
## Hoja de letras del nombre de la camiseta (2026-11-13, «elegir nombre… verlos aplicados en la camiseta»): una fila con
## ShirtName.GLYPHS, celdas mas bajas y la misma fuente.
const NAME_OUT := "res://assets/characters/player/name_atlas.png"
const NAME_CELL := Vector2i(76, 100)
const NAME_FONT := 70
const NAME_OUTLINE := 10

func _render(outline: int, chars: String = "0123456789", cell: Vector2i = CELL, font_size: int = FONT_SIZE) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(cell.x * chars.length(), cell.y)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 1.1
	# Un poco mas angosta: las cifras de una camiseta son altas.
	font.variation_transform = Transform2D(Vector2(0.86, 0), Vector2(0, 1), Vector2.ZERO)
	for d in chars.length():
		var l := Label.new()
		l.text = chars[d]
		l.position = Vector2(d * cell.x, 0)
		l.size = Vector2(cell)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", font_size)
		l.add_theme_color_override("font_color", Color.WHITE)
		if outline > 0:
			l.add_theme_constant_override("outline_size", outline)
			l.add_theme_color_override("font_outline_color", Color.WHITE)
		vp.add_child(l)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img

func _sheet(chars: String, cell: Vector2i, font_size: int, outline: int, path: String) -> void:
	var fill: Image = await _render(0, chars, cell, font_size)
	var edge: Image = await _render(outline, chars, cell, font_size)
	var out := Image.create(cell.x * chars.length(), cell.y, false, Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			var f: float = fill.get_pixel(x, y).a
			var e: float = maxf(edge.get_pixel(x, y).a, f)
			out.set_pixel(x, y, Color(f, e, 0.0, e))
	out.save_png(ProjectSettings.globalize_path(path))
	print("hoja: ", path, " ", out.get_size())

func _ready() -> void:
	if OS.get_environment("ATLAS_ONLY") != "nombre":
		await _sheet("0123456789", CELL, FONT_SIZE, OUTLINE, OUT)
	await _sheet(ShirtName.GLYPHS, NAME_CELL, NAME_FONT, NAME_OUTLINE, NAME_OUT)
	get_tree().quit()
