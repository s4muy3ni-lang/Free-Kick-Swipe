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

func _render(outline: int) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL.x * 10, CELL.y)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 1.1
	# Un poco mas angosta: las cifras de una camiseta son altas.
	font.variation_transform = Transform2D(Vector2(0.86, 0), Vector2(0, 1), Vector2.ZERO)
	for d in 10:
		var l := Label.new()
		l.text = str(d)
		l.position = Vector2(d * CELL.x, 0)
		l.size = Vector2(CELL)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", FONT_SIZE)
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

func _ready() -> void:
	var fill: Image = await _render(0)
	var edge: Image = await _render(OUTLINE)
	var out := Image.create(CELL.x * 10, CELL.y, false, Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			var f: float = fill.get_pixel(x, y).a
			var e: float = maxf(edge.get_pixel(x, y).a, f)
			out.set_pixel(x, y, Color(f, e, 0.0, e))
	out.save_png(ProjectSettings.globalize_path(OUT))
	print("hoja de cifras: ", OUT, " ", out.get_size())
	get_tree().quit()
