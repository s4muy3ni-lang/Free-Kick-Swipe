class_name OnlineMinigameSelect
extends ColorRect
## Pantalla de seleccion de los minijuegos online (pedido del usuario: «antes de entrar a una competicion de minijuegos
## online, mostrar una pantalla donde los jugadores puedan elegir que quieren jugar»): arriba el rival, despues las
## pestañas de los minijuegos online, la grilla de niveles del minijuego elegido (del contenido real: MinigameCatalog,
## solo los que admite el servidor en scene_def.levels) y abajo JUGAR ALEATORIO, CONFIRMAR y SALIR. La eleccion la valida
## y la guarda el servidor (choose_minigame): esta pantalla solo la arma.
##
## same_game = true: «Otro nivel» del mismo minijuego (sin pestañas de otros minijuegos).

signal confirmed(mode: String, level: int)
signal random_requested
signal cancelled

const GOLD := Color(1.0, 0.84, 0.28)
const CARD := Vector2(230, 190)

## Modalidades online de minijuego: [{id, name, scene_def: {game, levels}}].
var modes: Array = []
var mode: String = ""
var level: int = 0
var same_game: bool = false
var rival: String = "Rival"
var _tabs: HBoxContainer
var _grid: GridContainer
var _summary: Label
var _confirm: Button
var _cards: Dictionary = {}
var _tab_buttons: Dictionary = {}

func setup(p_modes: Array, p_mode: String, p_rival: String, p_same_game: bool = false) -> void:
	modes = []
	for m in p_modes:
		var sd: Dictionary = (m as Dictionary).get("scene_def", {})
		if String((m as Dictionary).get("kind", "")) == "minijuego" and sd.has("levels") and not levels_of(m).is_empty():
			modes.append(m)
	mode = p_mode if _find(p_mode) != {} else (String(modes[0]["id"]) if not modes.is_empty() else "")
	rival = p_rival
	same_game = p_same_game
	level = 0

func _find(id: String) -> Dictionary:
	for m in modes:
		if String(m["id"]) == id:
			return m
	return {}

## Niveles jugables online de la modalidad m: los del catalogo real cuyo numero esta en scene_def.levels.
static func levels_of(m: Dictionary) -> Array:
	var sd: Dictionary = m.get("scene_def", {})
	var game: String = String(sd.get("game", ""))
	var out: Array = []
	for n in sd.get("levels", []):
		var d: Dictionary = MinigameCatalog.level(game, int(n))
		if not d.is_empty():
			out.append(d)
	return out

func _ready() -> void:
	name = "SeleccionMinijuego"
	color = Color(0.01, 0.02, 0.06, 0.94)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	var title := _label("ELEGÍ QUÉ JUGAR", 36, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_label("Rival: %s" % rival, 22, Color(1.0, 0.6, 0.55)))
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 10)
	_tabs.visible = not same_game
	v.add_child(_tabs)
	for m in modes:
		var id: String = String(m["id"])
		var b := Button.new()
		b.text = String(m.get("name", id))
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 54)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func() -> void: select_mode(id))
		_tabs.add_child(b)
		_tab_buttons[id] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	ScrollTap.watch(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)
	_summary = _label("", 24, Color.WHITE)
	v.add_child(_summary)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(actions)
	var rnd := _button("JUGAR ALEATORIO", func() -> void: random_requested.emit())
	rnd.visible = not same_game
	actions.add_child(rnd)
	_confirm = _button("CONFIRMAR", func() -> void:
		if level > 0:
			confirmed.emit(mode, level))
	actions.add_child(_confirm)
	actions.add_child(_button("SALIR", func() -> void: cancelled.emit()))
	select_mode(mode)

## Muestra los niveles de la modalidad id (sin nivel elegido todavia).
func select_mode(id: String) -> void:
	mode = id
	level = 0
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).add_theme_color_override("font_color", GOLD if k == id else Color(0.85, 0.88, 0.95))
		(_tab_buttons[k] as Button).add_theme_stylebox_override("normal", _style(k == id, Color(0.1, 0.14, 0.28)))
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()
	var m: Dictionary = _find(id)
	var thumb: String = ChallengeMenu.thumb_for(String((m.get("scene_def", {}) as Dictionary).get("game", "")))
	for d in levels_of(m):
		var n: int = int(d["level"])
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = CARD
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.add_theme_stylebox_override("normal", _style(false, Color(0.07, 0.1, 0.2)))
		b.add_theme_stylebox_override("hover", _style(false, Color(0.1, 0.14, 0.28)))
		b.add_theme_stylebox_override("pressed", _style(true, Color(0.1, 0.14, 0.28)))
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 10
		box.offset_right = -10
		box.offset_top = 8
		box.offset_bottom = -8
		b.add_child(box)
		if thumb != "":
			var tr := TextureRect.new()
			tr.texture = load(thumb) as Texture2D
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.custom_minimum_size = Vector2(0, 88)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(tr)
		box.add_child(_label("NIVEL %d" % n, 20, GOLD))
		var t := _label(String(d.get("title", "")), 18, Color.WHITE)
		t.clip_text = true
		box.add_child(t)
		var o := _label(String(d.get("objective", "")), 14, Color(0.75, 0.8, 0.9))
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o.max_lines_visible = 2
		box.add_child(o)
		b.pressed.connect(func() -> void:
			if not ScrollTap.blocked(b):
				select_level(n))
		_grid.add_child(b)
		_cards[n] = b
	_refresh()

func select_level(n: int) -> void:
	level = n
	for k in _cards:
		(_cards[k] as Button).add_theme_stylebox_override("normal", _style(int(k) == n, Color(0.07, 0.1, 0.2)))
	_refresh()

func _refresh() -> void:
	var m: Dictionary = _find(mode)
	if level <= 0:
		_summary.text = "%s: elegí un nivel, o jugá uno aleatorio." % String(m.get("name", mode))
	else:
		var d: Dictionary = MinigameCatalog.level(String((m.get("scene_def", {}) as Dictionary).get("game", "")), level)
		_summary.text = "Elegiste: %s · Nivel %d — %s" % [String(m.get("name", mode)), level, String(d.get("title", ""))]
	_confirm.disabled = level <= 0

func say(t: String) -> void:
	_summary.text = t

func _style(on: bool, bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = GOLD if on else Color(1, 1, 1, 0.18)
	sb.set_border_width_all(4 if on else 2)
	sb.set_corner_radius_all(14)
	return sb

func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(240, 64)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b
