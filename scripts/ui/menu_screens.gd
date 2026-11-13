class_name MenuScreens
extends Control
## Pantallas del menu principal (ecosistema online): JUGAR ONLINE (lobby, modalidades, buscar rival), JUGAR OFFLINE,
## PERSONALIZAR, TIENDA, TEMPORADA, EVENTOS y PERFIL. Todo lo que tiene valor (compras, temporada, atributos,
## identidad, apariencia) pasa por las funciones del servidor (Online.call_state_fn); la interfaz solo muestra y pide.

signal play_offline(mode: int)
signal customize_changed
signal customize_mode(on: bool)

const GOLD := Color(1.0, 0.84, 0.28)
const RARITY := {"comun": Color(0.75, 0.78, 0.85), "raro": Color(0.35, 0.65, 1.0), "epico": Color(0.75, 0.4, 1.0),
	"legendario": Color(1.0, 0.7, 0.2)}
## Modalidades online jugables: penales con el protocolo de turnos del servidor; las demas contra un bot dificil
## (OnlineDuel; las partidas entre humanos de esas modalidades siguen en preparacion).
const READY_ONLINE := ["penales", "tiros_libres", "a_la_vista", "guante", "dardos", "basket", "diana", "rescate"]
## Miniatura de cada modalidad online (assets/ui/thumbs).
const ONLINE_THUMBS := {"penales": "penales", "tiros_libres": "tiro_libre", "a_la_vista": "boton_caida", "guante": "guante",
	"dardos": "dardos", "basket": "enceste", "diana": "diana_gigante", "rescate": "rescate"}

var _panel: PanelContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _title: Label
var _coins: Label
var _toast: Label
var current: String = ""
var _catalog: Array = []
var _search_box: Control = null
var _searching: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	add_child(_panel)
	_full_panel()
	var sb := StyleBoxFlat.new()
	# Fondo casi opaco: los botones del menu de atras no se ven a traves (se veia todo mezclado).
	sb.bg_color = Color(0.02, 0.03, 0.08, 0.985)
	sb.set_content_margin_all(26)
	_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	vb.add_child(head)
	var back := _btn("‹ Volver", close)
	back.custom_minimum_size = Vector2(160, 56)
	head.add_child(back)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 38)
	_title.add_theme_color_override("font_color", GOLD)
	head.add_child(_title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(MenuIcon.new("coin", Color.WHITE, 40))
	_coins = Label.new()
	_coins.add_theme_font_size_override("font_size", 28)
	head.add_child(_coins)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	# Se arrastra tambien tocando las tarjetas y sus imagenes (antes solo los huecos entre ellas).
	ScrollTap.watch(scroll)
	_scroll = scroll
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	scroll.add_child(_content)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	vb.add_child(_toast)
	visible = false
	Online.state_changed.connect(_on_state)

func _full_panel() -> void:
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Personalizar: el panel a la derecha para ver al jugador girando a la izquierda.
func _side_panel() -> void:
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.anchor_left = 0.52
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0

func _on_state() -> void:
	_coins.text = "%d" % Online.coins()

func close() -> void:
	if current == "personalizar":
		customize_mode.emit(false)
		_send_appearance()
	if _searching:
		_searching = false
		Online.call_fn("cancel_search")
	visible = false
	current = ""

func _clear(title: String) -> void:
	for c in _content.get_children():
		c.queue_free()
	_title.text = title
	_toast.text = ""
	_coins.text = "%d" % Online.coins()
	visible = true
	_panel.visible = true
	_full_panel()

func _say(t: String, ok: bool = false) -> void:
	_toast.text = t
	_toast.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6) if ok else Color(1.0, 0.6, 0.5))

func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b

func _lbl(t: String, size: int = 22, col := Color(1, 1, 1), wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _card_box(col: Color, min_w: float = 0.0) -> Array:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.85)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(min_w, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return [p, v]

func _row() -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 14)
	r.add_theme_constant_override("v_separation", 14)
	_content.add_child(r)
	return r

# --- JUGAR OFFLINE --------------------------------------------------------------------------------------------------

func open_offline() -> void:
	current = "offline"
	_clear("JUGAR OFFLINE")
	_content.add_child(_lbl("Contra la CPU, sin conexión. Lo que ganes se sincroniza después con tu cuenta.", 22))
	var r := _row()
	# Cada modo con sus variantes (pedido del usuario): contra la CPU se alternan tiro y atajada; en el tiro libre sigue la
	# practica libre de siempre (elegís dónde patear, sin turnos).
	for m in [["PENALES", "Tanda contra la CPU: tirás y atajás eligiendo uno de los 9 sectores.", "penal", Color(0.08, 0.3, 0.75), SetPieceGame.Mode.PENALTY,
				[["PENALES CONTRA LA CPU", SetPieceGame.Vs.CPU], ["PENALES · 2 JUGADORES (MISMO TELÉFONO)", SetPieceGame.Vs.LOCAL]]],
			["TIROS LIBRES", "Duelo contra la CPU desde los mismos puntos: pateás vos, ataja la CPU, y al revés.", "tiro_libre", Color(0.1, 0.5, 0.25), SetPieceGame.Mode.FREE_KICK,
				[["TIRO LIBRE: DUELO CONTRA LA CPU", SetPieceGame.Vs.CPU], ["TIRO LIBRE · 2 JUGADORES (MISMO TELÉFONO)", SetPieceGame.Vs.LOCAL],
				["TIRO LIBRE: PRÁCTICA LIBRE", SetPieceGame.Vs.PRACTICE]]]]:
		var cb: Array = _card_box(m[3], 400)
		# Miniatura del modo (pedido del usuario: cada modo con su imagen).
		var th: String = ChallengeMenu.thumb_for("penales" if m[4] == SetPieceGame.Mode.PENALTY else "tiro_libre")
		if th != "":
			var tr := TextureRect.new()
			tr.texture = load(th) as Texture2D
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.custom_minimum_size = Vector2(368, 207)
			cb[1].add_child(tr)
		var h := HBoxContainer.new()
		h.add_child(MenuIcon.new(m[2], Color.WHITE, 72))
		h.add_child(_lbl(m[0], 32, GOLD, false))
		cb[1].add_child(h)
		cb[1].add_child(_lbl(m[1], 20))
		var mode: int = m[4]
		for v in m[5]:
			var vs_kind: int = v[1]
			var b := _btn(String(v[0]), func() -> void:
				SetPieceGame.next_vs = vs_kind
				play_offline.emit(mode))
			cb[1].add_child(b)
		r.add_child(cb[0])

# --- JUGAR ONLINE ---------------------------------------------------------------------------------------------------
## Pantalla rediseñada (pedido del usuario 2026-11-12: «el selector o buscador de partidas es muy feo, hacelo mejor»):
## arriba el estado del lobby en pastillas; a la izquierda las modalidades como tarjetas con su imagen (la elegida con
## borde dorado); a la derecha la modalidad elegida en grande con la entrada (botones), el premio, el rival y BUSCAR
## PARTIDA. La busqueda es una pantalla propia: radar animado, tiempo, estado y, al encontrar, el cara a cara.

const TILE := Vector2(250, 141)
const DETAIL_W := 470.0
var _online_modes: Array = []
var _sel_mode: String = ""
var _sel_fee: int = 0
var _mode_detail: VBoxContainer = null
var _mode_tiles: Dictionary = {}
static var _shade_tex: GradientTexture2D = null

func open_online() -> void:
	current = "online"
	_clear("JUGAR ONLINE")
	var status := HFlowContainer.new()
	status.add_theme_constant_override("h_separation", 10)
	status.add_theme_constant_override("v_separation", 8)
	_content.add_child(status)
	var loading := _pill("online", "Conectando al lobby…", Color(0.75, 0.85, 1.0))
	status.add_child(loading)
	var lv: Variant = (await Online.call_fn("get_lobby")).get("data", {})
	var lobby: Dictionary = lv if lv is Dictionary else {}
	if current != "online" or not is_instance_valid(status):
		return
	loading.queue_free()
	status.add_child(_pill("perfil", "%d jugando ahora" % int(lobby.get("humans_online", 0)), Color(0.5, 1.0, 0.6)))
	status.add_child(_pill("online", "%d partidas en curso" % int(lobby.get("matches_active", 0)), Color(0.75, 0.85, 1.0)))
	status.add_child(_pill("ball", "Actividad del mundo: %d" % int(lobby.get("world_activity", 0)), Color(0.85, 0.87, 0.95)))
	if not Online.has_server():
		status.add_child(_pill("vacio", Online.backend_label(), Color(1.0, 0.8, 0.5)))
	_online_modes = await Online.catalog("game_modes")
	if current != "online":
		return
	var main := HFlowContainer.new()
	main.add_theme_constant_override("h_separation", 20)
	main.add_theme_constant_override("v_separation", 16)
	_content.add_child(main)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	main.add_child(left)
	left.add_child(_lbl("ELEGÍ LA MODALIDAD", 20, Color(0.75, 0.85, 1.0), false))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	left.add_child(grid)
	_mode_tiles = {}
	var first: String = ""
	for gm in _online_modes:
		var id: String = String(gm["id"])
		if first == "" and id in READY_ONLINE:
			first = id
		var t: Button = _mode_tile(gm)
		_mode_tiles[id] = t
		grid.add_child(t)
	var box: Array = _card_box(Color(0.05, 0.07, 0.15), DETAIL_W)
	main.add_child(box[0])
	_mode_detail = box[1]
	_mode_detail.add_theme_constant_override("separation", 12)
	select_mode(_sel_mode if _mode_tiles.has(_sel_mode) else first)

func _mode_by_id(id: String) -> Dictionary:
	for gm in _online_modes:
		if String(gm["id"]) == id:
			return gm
	return {}

## Pastilla del estado del lobby: icono y texto sobre fondo oscuro redondeado.
func _pill(icon: String, text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.12, 0.85)
	sb.border_color = Color(col.r, col.g, col.b, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 10
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(MenuIcon.new(icon, col, 26))
	var l := _lbl(text, 18, col, false)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return p

static func _shade() -> GradientTexture2D:
	if _shade_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.15), Color(0, 0, 0, 0.85)])
		_shade_tex = GradientTexture2D.new()
		_shade_tex.gradient = g
		_shade_tex.fill_from = Vector2(0, 0)
		_shade_tex.fill_to = Vector2(0, 1)
		_shade_tex.width = 8
		_shade_tex.height = 64
	return _shade_tex

## Imagen de una modalidad que llena `parent` (con un degradé abajo para que se lea el nombre encima).
func _cover(parent: Control, id: String, width: int) -> void:
	var th: String = ChallengeMenu.thumb_for(String(ONLINE_THUMBS.get(id, "")))
	if th != "":
		var tr := TextureRect.new()
		tr.texture = ChallengeMenu.scaled_thumb(th, width)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		parent.add_child(tr)
	var sh := TextureRect.new()
	sh.texture = _shade()
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(sh)

## Etiqueta chica de color (VS BOT, 1 VS 1, PRÓXIMAMENTE).
func _tag(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _lbl(text, 14, Color(0.05, 0.05, 0.08), false)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

func _tile_style(selected: bool, col: Color, hover: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.5)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(4 if selected else 2)
	sb.border_color = GOLD if selected else Color(1, 1, 1, 0.45 if hover else 0.16)
	sb.shadow_color = Color(1.0, 0.8, 0.3, 0.35) if selected else Color(0, 0, 0, 0.35)
	sb.shadow_size = 8 if selected else 4
	return sb

## Tarjeta de una modalidad: su imagen de punta a punta, el nombre abajo y una etiqueta arriba.
func _mode_tile(gm: Dictionary) -> Button:
	var id: String = String(gm["id"])
	var ready: bool = id in READY_ONLINE
	var art: Dictionary = gm.get("art", {}) if gm.get("art") is Dictionary else {}
	var col: Color = Color.from_string(String(art.get("color", "#335")), Color(0.2, 0.2, 0.3))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = TILE
	b.clip_contents = true
	b.set_meta("mode_id", id)
	b.set_meta("mode_color", col)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, _tile_style(false, col, st == "hover"))
	_cover(b, id, int(TILE.x))
	var name := _lbl(String(gm["name"]), 22, Color.WHITE, false)
	name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	name.add_theme_constant_override("shadow_offset_x", 2)
	name.add_theme_constant_override("shadow_offset_y", 2)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.anchor_top = 1.0
	name.anchor_bottom = 1.0
	name.anchor_right = 1.0
	name.offset_left = 12
	name.offset_top = -38
	name.offset_bottom = -8
	b.add_child(name)
	var turns_mode: bool = id in ["penales", "tiros_libres"]
	var tag: PanelContainer = _tag("1 VS 1" if turns_mode else ("VS BOT" if ready else "PRÓXIMAMENTE"),
		Color(0.45, 1.0, 0.55) if turns_mode else (GOLD if ready else Color(0.6, 0.62, 0.7)))
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.offset_left = -8
	tag.offset_right = -8
	tag.offset_top = 8
	tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.add_child(tag)
	if not ready:
		b.modulate = Color(0.7, 0.7, 0.75)
	b.pressed.connect(func() -> void: select_mode(id))
	return b

## Elige la modalidad: su tarjeta con borde dorado y el panel de la derecha con sus datos.
func select_mode(id: String) -> void:
	if not _mode_tiles.has(id):
		return
	_sel_mode = id
	for k in _mode_tiles:
		var t: Button = _mode_tiles[k]
		var col: Color = t.get_meta("mode_color")
		for st in ["normal", "hover", "pressed", "focus"]:
			t.add_theme_stylebox_override(st, _tile_style(k == id, col, st == "hover"))
	_show_mode_detail(_mode_by_id(id))

func _show_mode_detail(gm: Dictionary) -> void:
	if _mode_detail == null or gm.is_empty():
		return
	for c in _mode_detail.get_children():
		c.queue_free()
	var id: String = String(gm["id"])
	var ready: bool = id in READY_ONLINE
	var art: Dictionary = gm.get("art", {}) if gm.get("art") is Dictionary else {}
	var hero := Control.new()
	hero.custom_minimum_size = Vector2(DETAIL_W - 28.0, 150)
	hero.clip_contents = true
	_mode_detail.add_child(hero)
	_cover(hero, id, int(DETAIL_W))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.anchor_top = 1.0
	hb.anchor_bottom = 1.0
	hb.anchor_right = 1.0
	hb.offset_left = 14
	hb.offset_top = -52
	hb.offset_bottom = -8
	hero.add_child(hb)
	hb.add_child(MenuIcon.new(String(art.get("icon", "ball")), Color.WHITE, 38))
	var nm := _lbl(String(gm["name"]), 30, GOLD, false)
	nm.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	nm.add_theme_constant_override("shadow_offset_x", 2)
	nm.add_theme_constant_override("shadow_offset_y", 2)
	hb.add_child(nm)
	_mode_detail.add_child(_lbl(String(gm["description"]), 18))
	_mode_detail.add_child(_lbl(String(gm["rules"]), 15, Color(0.72, 0.76, 0.86)))
	# Entrada: botones (la elegida en dorado); las que no alcanzan con tus monedas, apagadas.
	var fees: Array = (gm.get("entry_fees", [0]) as Array).map(func(x: Variant) -> int: return int(x))
	if not fees.has(_sel_fee):
		_sel_fee = int(fees[0]) if not fees.is_empty() else 0
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 8)
	frow.add_child(_lbl("Entrada", 18, Color(0.75, 0.85, 1.0), false))
	_mode_detail.add_child(frow)
	var fee_buttons: Array = []
	for f in fees:
		var fb := Button.new()
		fb.focus_mode = Control.FOCUS_NONE
		fb.text = "GRATIS" if f == 0 else "%d" % f
		if f > 0:
			fb.icon = _coin_icon()
		fb.custom_minimum_size = Vector2(92, 40)
		fb.add_theme_font_size_override("font_size", 18)
		fb.disabled = f > Online.coins()
		fb.set_meta("fee", f)
		fee_buttons.append(fb)
		frow.add_child(fb)
		fb.pressed.connect(func() -> void:
			_sel_fee = f
			_style_fees(fee_buttons))
	_style_fees(fee_buttons)
	var rw := HBoxContainer.new()
	rw.add_theme_constant_override("separation", 8)
	rw.add_child(MenuIcon.new("coin", GOLD, 24))
	rw.add_child(_lbl("Premio: experiencia, monedas y puntos de temporada", 16, Color(0.9, 0.92, 1.0), false))
	_mode_detail.add_child(rw)
	var rv := HBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rv.add_child(MenuIcon.new("perfil", Color(0.75, 0.85, 1.0), 24))
	var rival_txt: String = "Rival: un jugador; si nadie aparece enseguida, un bot." if id in ["penales", "tiros_libres"] else "Rival: un bot difícil (entre humanos, pronto)."
	var rl := _lbl(rival_txt if ready else "Todavía no se puede jugar online.", 16, Color(0.85, 0.88, 0.95))
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_child(rl)
	_mode_detail.add_child(rv)
	var go := Button.new()
	go.name = "BuscarPartida"
	go.focus_mode = Control.FOCUS_NONE
	go.text = "BUSCAR PARTIDA" if ready else "PRÓXIMAMENTE"
	go.disabled = not ready
	go.custom_minimum_size = Vector2(0, 66)
	go.add_theme_font_size_override("font_size", 30)
	go.add_theme_color_override("font_color", Color(0.08, 0.07, 0.04))
	go.add_theme_color_override("font_hover_color", Color(0.08, 0.07, 0.04))
	go.add_theme_color_override("font_pressed_color", Color(0.08, 0.07, 0.04))
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": GOLD, "hover": GOLD.lightened(0.15), "pressed": GOLD.darkened(0.15), "disabled": Color(0.3, 0.3, 0.34), "focus": GOLD}[st]
		sb.set_corner_radius_all(18)
		sb.shadow_color = Color(1.0, 0.75, 0.2, 0.35)
		sb.shadow_size = 0 if st == "disabled" else 10
		go.add_theme_stylebox_override(st, sb)
	go.pressed.connect(func() -> void: _search(id, _sel_fee))
	_mode_detail.add_child(go)

func _style_fees(buttons: Array) -> void:
	for fb in buttons:
		var on: bool = int((fb as Button).get_meta("fee")) == _sel_fee
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.32, 0.25, 0.06) if on else Color(0.1, 0.12, 0.2)
			sb.border_color = GOLD if on else Color(1, 1, 1, 0.2)
			sb.set_border_width_all(3 if on else 1)
			sb.set_corner_radius_all(12)
			if st == "disabled":
				sb.bg_color = Color(0.08, 0.08, 0.1)
			(fb as Button).add_theme_stylebox_override(st, sb)

static var _coin_tex: Texture2D = null

## Moneda para los botones (dibujada una vez).
static func _coin_icon() -> Texture2D:
	if _coin_tex == null:
		var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		for y in 24:
			for x in 24:
				var d: float = Vector2(x - 11.5, y - 11.5).length()
				if d <= 11.0:
					var rim: bool = d > 8.5
					img.set_pixel(x, y, Color(0.85, 0.6, 0.1) if rim else Color(1.0, 0.82, 0.25))
		_coin_tex = ImageTexture.create_from_image(img)
	return _coin_tex

## Busca rival: primero humanos (el servidor empareja); despues de la espera, un bot generado por el servidor. Pantalla
## de busqueda propia (radar, tiempo, estado) y, al encontrarlo, el cara a cara un momento antes de empezar.
func _search(mode: String, fee: int) -> void:
	if _searching:
		return
	_searching = true
	var ui: Dictionary = search_screen(_mode_by_id(mode))
	var t0: float = Time.get_ticks_msec() / 1000.0
	var view: Dictionary = {}
	while _searching:
		var r: Dictionary = await Online.call_fn("find_match", {"p_mode": mode, "p_fee": fee})
		if not r.get("ok", false):
			_say(String(r.get("error", "No se pudo buscar rival.")))
			break
		var d: Dictionary = r["data"]
		if String(d.get("status", "")) == "matched":
			view = d
			break
		var waited: float = Time.get_ticks_msec() / 1000.0 - t0
		(ui["clock"] as Label).text = "%d:%02d" % [int(waited) / 60, int(waited) % 60]
		var hs: int = int(d.get("humans_searching", 0))
		(ui["status"] as Label).text = "Buscando jugadores humanos" + (" (%d buscando)" % hs if hs > 0 else "…")
		if float(d.get("waited", 0.0)) >= float(d.get("bot_after", 8)):
			(ui["status"] as Label).text = "No hay humanos libres: preparando un rival…"
			var rb: Dictionary = await Online.call_fn("start_bot_match", {"p_mode": mode})
			if rb.get("ok", false):
				view = rb["data"]
				break
		await get_tree().create_timer(1.0).timeout
	if _searching and not view.is_empty() and is_instance_valid(_search_box):
		show_found(ui, view)
		await get_tree().create_timer(1.8).timeout
	if is_instance_valid(_search_box):
		_search_box.queue_free()
	if _searching and not view.is_empty():
		_searching = false
		# Penales y tiros libres: partida por turnos con autoridad del servidor (roles alternados, el arquero elige uno de
		# los 9 sectores oculto). Los minijuegos van por OnlineDuel.
		if mode not in ["penales", "tiros_libres"]:
			# Minijuegos: primero se elige minijuego y nivel (o aleatorio) en la pantalla de seleccion.
			if OnlineDuel.MODES.has(mode):
				open_minigame_select(view, mode)
				return
		OnlineMatch.pending = view
		SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK if mode == "tiros_libres" else SetPieceGame.Mode.PENALTY
		SetPieceGame.next_vs = SetPieceGame.Vs.CPU
		get_tree().change_scene_to_file(SetPieceGame.SCENE)
	_searching = false

## Seleccion de minijuego online (rival ya encontrado): pestañas de minijuegos, niveles reales, aleatorio y confirmar. El
## servidor valida y guarda la eleccion (choose_minigame) y recien entonces se arranca ese nivel. same_game: solo los
## niveles del mismo minijuego («Otro nivel»).
var _select: OnlineMinigameSelect = null

func open_minigame_select(view: Dictionary, mode: String, same_game: bool = false) -> OnlineMinigameSelect:
	if _online_modes.is_empty():
		_online_modes = await Online.catalog("game_modes")
	if is_instance_valid(_select):
		_select.queue_free()
	var op: Dictionary = view.get("opponent", {}) if view.get("opponent") is Dictionary else {}
	_select = OnlineMinigameSelect.new()
	_select.setup(_online_modes, mode, String(op.get("name", "Rival")), same_game)
	add_child(_select)
	var sel: OnlineMinigameSelect = _select
	_select.confirmed.connect(func(m: String, lv: int) -> void: _play_minigame(sel, view, m, lv, false))
	_select.random_requested.connect(func() -> void: _play_minigame(sel, view, "", 0, true))
	_select.cancelled.connect(func() -> void:
		sel.queue_free()
		open_online())
	return _select

## Pide al servidor la eleccion (o el sorteo) y arranca el nivel que quedo guardado en la partida.
func _play_minigame(sel: OnlineMinigameSelect, view: Dictionary, mode: String, level: int, random: bool) -> bool:
	var mid: String = String((view.get("match", {}) as Dictionary).get("id", ""))
	var r: Dictionary = await Online.call_fn("choose_minigame", {"p_match": mid, "p_mode": mode, "p_level": level, "p_random": random})
	if not r.get("ok", false):
		if is_instance_valid(sel):
			sel.say("No se pudo: %s" % String(r.get("error", "error del servidor")))
		return false
	var v: Dictionary = r["data"]
	var mg: Dictionary = (v.get("match", {}) as Dictionary).get("minigame", {})
	if mg.is_empty():
		return false
	return OnlineDuel.start_level(get_tree(), String(mg["mode"]), v, int(mg["level"]))

## Al volver de un minijuego online: «repeat» repite el nivel, «random» sortea otro, «level» y «game» muestran la
## seleccion (del mismo minijuego o de todos), «exit» vuelve al lobby. Siempre contra el mismo bot (rematch_bot).
func resume_online_after() -> void:
	var act: String = OnlineDuel.after
	OnlineDuel.after = ""
	var last: Dictionary = OnlineDuel.last
	open_online()
	if act == "exit" or last.is_empty():
		return
	var r: Dictionary = await Online.call_fn("rematch_bot", {"p_match": String(last.get("match", ""))})
	if not r.get("ok", false):
		_say("No se pudo armar la revancha: %s" % String(r.get("error", "")))
		return
	var view: Dictionary = r["data"]
	match act:
		"repeat":
			var s1: OnlineMinigameSelect = await open_minigame_select(view, String(last["mode"]), true)
			s1.select_level(int(last["level"]))
			await _play_minigame(s1, view, String(last["mode"]), int(last["level"]), false)
		"random":
			var s2: OnlineMinigameSelect = await open_minigame_select(view, String(last["mode"]))
			await _play_minigame(s2, view, "", 0, true)
		"level":
			await open_minigame_select(view, String(last["mode"]), true)
		_:
			await open_minigame_select(view, String(last["mode"]))

## Pantalla de busqueda (encima de todo): la modalidad, el radar que late, el tiempo, el estado y Cancelar. Devuelve sus
## partes para actualizarlas.
func search_screen(gm: Dictionary) -> Dictionary:
	var overlay := ColorRect.new()
	overlay.name = "Busqueda"
	overlay.color = Color(0.01, 0.02, 0.06, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_search_box = overlay
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var cb: Array = _card_box(Color(0.06, 0.09, 0.2), 560)
	center.add_child(cb[0])
	var v: VBoxContainer = cb[1]
	v.add_theme_constant_override("separation", 10)
	var mode_name := _lbl(String(gm.get("name", "Partida online")).to_upper(), 22, Color(0.75, 0.85, 1.0), false)
	mode_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(mode_name)
	var radar := SearchRadar.new()
	radar.custom_minimum_size = Vector2(230, 230)
	radar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(radar)
	var title := _lbl("BUSCANDO RIVAL", 34, GOLD, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var clock := _lbl("0:00", 26, Color.WHITE, false)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(clock)
	var status := _lbl("Buscando jugadores humanos…", 20, Color(0.8, 0.85, 0.95))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status)
	var vs := HBoxContainer.new()
	vs.alignment = BoxContainer.ALIGNMENT_CENTER
	vs.add_theme_constant_override("separation", 18)
	vs.visible = false
	v.add_child(vs)
	var cancel := _btn("Cancelar", func() -> void:
		_searching = false
		Online.call_fn("cancel_search"))
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.custom_minimum_size = Vector2(220, 52)
	v.add_child(cancel)
	return {"overlay": overlay, "radar": radar, "title": title, "clock": clock, "status": status, "vs": vs, "cancel": cancel}

## Rival encontrado: el radar se pone verde y aparece el cara a cara (vos contra el rival, con su nivel).
func show_found(ui: Dictionary, view: Dictionary) -> void:
	(ui["radar"] as SearchRadar).found = true
	(ui["title"] as Label).text = "¡RIVAL ENCONTRADO!"
	(ui["title"] as Label).add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	(ui["clock"] as Label).visible = false
	(ui["status"] as Label).visible = false
	(ui["cancel"] as Button).visible = false
	var vs: HBoxContainer = ui["vs"]
	vs.visible = true
	var me: Dictionary = Online.profile()
	var my_name: String = String(me.get("nickname", "")) if String(me.get("nickname", "")) != "" else String(me.get("display_name", me.get("username", "VOS")))
	var op: Dictionary = view.get("opponent", {}) if view.get("opponent") is Dictionary else {}
	vs.add_child(_vs_card(my_name if my_name != "" else "VOS", "Nivel %d" % Online.level(), Color(0.35, 0.65, 1.0)))
	var x := _lbl("VS", 40, GOLD, false)
	x.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs.add_child(x)
	vs.add_child(_vs_card(String(op.get("name", "Rival")), ("Nivel %d" % int(op.get("level", 1))) + ("  ·  bot" if bool(op.get("is_bot", false)) else ""), Color(1.0, 0.45, 0.4)))

func _vs_card(name: String, sub: String, col: Color) -> PanelContainer:
	var box: Array = _card_box(Color(col.r * 0.25, col.g * 0.25, col.b * 0.3), 190)
	var v: VBoxContainer = box[1]
	v.add_child(MenuIcon.new("perfil", col, 48))
	var n := _lbl(name, 22, Color.WHITE, false)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	v.add_child(n)
	var s2 := _lbl(sub, 16, Color(0.8, 0.85, 0.95), false)
	s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s2)
	return box[0]

## Radar de la busqueda: anillos que se abren desde el centro y una pelota que gira; verde al encontrar rival.
class SearchRadar extends Control:
	var found: bool = false
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.48
		var col: Color = Color(0.45, 1.0, 0.55) if found else Color(1.0, 0.84, 0.28)
		draw_circle(c, r, Color(col.r, col.g, col.b, 0.06))
		for k in 3:
			var ph: float = fmod(_t * 0.6 + float(k) / 3.0, 1.0)
			draw_arc(c, r * ph, 0.0, TAU, 64, Color(col.r, col.g, col.b, (1.0 - ph) * 0.7), 3.0, true)
		if not found:
			var a: float = _t * 2.4
			draw_line(c, c + Vector2(cos(a), sin(a)) * r, Color(col.r, col.g, col.b, 0.8), 3.0, true)
		draw_arc(c, r, 0.0, TAU, 64, Color(col.r, col.g, col.b, 0.5), 2.0, true)
		# La pelota: blanca con un pentagono oscuro que gira.
		var br: float = r * 0.28
		draw_circle(c, br, Color.WHITE)
		var pts := PackedVector2Array()
		for i in 5:
			var ang: float = _t * (0.8 if not found else 0.2) + TAU * float(i) / 5.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * br * 0.45)
		draw_colored_polygon(pts, Color(0.1, 0.1, 0.14))
		draw_arc(c, br, 0.0, TAU, 32, Color(0.1, 0.1, 0.14), 2.0, true)

# --- TIENDA ---------------------------------------------------------------------------------------------------------

const KIND_NAMES := {"jersey": "Camisetas", "boots": "Botines", "ball": "Balones", "consumable": "Consumibles",
	"shorts": "Shorts", "socks": "Medias", "emote": "Emojis", "number_style": "Números", "celebration": "Festejos"}

static func unlock_text(it: Dictionary) -> String:
	match String(it["unlock"]):
		"free": return "Gratis"
		"progression": return "Desbloqueable (nivel %d)" % int(it.get("min_level", 1))
		"season": return "De temporada"
		"event": return "De evento"
	return "Comprable · %d monedas" % int(it.get("price_coins", 0))

func open_shop() -> void:
	current = "tienda"
	_clear("TIENDA")
	_catalog = await Online.catalog("catalog_items")
	_content.add_child(_lbl("Todo se compra con monedas virtuales que ganás jugando. Los colores básicos son siempre gratis.", 20))
	for kind in ["jersey", "boots", "ball", "consumable", "shorts", "socks", "emote", "number_style"]:
		_content.add_child(_lbl(KIND_NAMES[kind] + (" · línea oficial del juego (diseños originales)" if kind == "jersey" else ""), 26, GOLD))
		var r := _row()
		for it in _catalog:
			if String(it["kind"]) != kind or not bool(it.get("active", true)):
				continue
			r.add_child(_item_card(it))
	_content.add_child(_lbl("Pase de temporada premium y monedas con dinero real: preparados, pero los pagos todavía no están activados.", 20, Color(1.0, 0.8, 0.5)))

func _item_card(it: Dictionary) -> Control:
	var col: Color = RARITY.get(String(it.get("rarity", "comun")), Color.GRAY)
	var cb: Array = _card_box(Color(0.08, 0.1, 0.18), 260)
	(cb[0].get_theme_stylebox("panel") as StyleBoxFlat).border_color = col
	cb[1].add_child(_lbl(String(it["name"]), 22, col))
	if String(it.get("description", "")) != "":
		cb[1].add_child(_lbl(String(it["description"]), 16, Color(0.85, 0.88, 0.95)))
	var owned: int = int(Online.inventory().get(String(it["id"]), 0))
	cb[1].add_child(_lbl(unlock_text(it), 18))
	var id: String = String(it["id"])
	if String(it["kind"]) == "consumable":
		if owned > 0:
			cb[1].add_child(_btn("Usar (%d)" % owned, func() -> void: _act("use_consumable", {"p_item": id}, "¡Activado!")))
		cb[1].add_child(_btn("Comprar · %d" % int(it.get("price_coins", 0)), func() -> void: _buy(id)))
	elif owned > 0 or String(it["unlock"]) == "free":
		cb[1].add_child(_lbl("Tuyo", 20, Color(0.5, 1.0, 0.6)))
	elif String(it["unlock"]) == "shop":
		cb[1].add_child(_btn("Comprar · %d" % int(it.get("price_coins", 0)), func() -> void: _buy(id)))
	return cb[0]

func _buy(id: String) -> void:
	var key: String = "buy-%s-%d-%08x" % [id, Time.get_ticks_msec(), randi()]
	await _act("buy_item", {"p_item": id, "p_idem": key}, "¡Comprado!")
	if current == "tienda":
		open_shop()

func _act(fn: String, args: Dictionary, ok_text: String) -> bool:
	var r: Dictionary = await Online.call_state_fn(fn, args)
	if r.get("ok", false):
		_say(ok_text, true)
		_coins.text = "%d" % Online.coins()
		return true
	_say(String(r.get("error", "No se pudo.")))
	return false

# --- TEMPORADA ------------------------------------------------------------------------------------------------------

func open_season() -> void:
	current = "temporada"
	_clear("TEMPORADA")
	var seasons: Array = await Online.catalog("seasons")
	var tiers: Array = await Online.catalog("season_tiers")
	var st: Dictionary = Online.state.get("season", {}) if Online.state.get("season") is Dictionary else {}
	if seasons.is_empty():
		_content.add_child(_lbl("No hay temporada activa.", 24))
		return
	var s: Dictionary = seasons[0]
	var pts: int = int(st.get("points", 0))
	_content.add_child(_lbl(String(s["name"]), 34, GOLD))
	_content.add_child(_lbl("Del %s al %s · Tus puntos: %d · Ganás puntos jugando online, offline, en el arcade y en los desafíos." % [
		String(s["starts_at"]).substr(0, 10), String(s["ends_at"]).substr(0, 10), pts], 20))
	var bar := ProgressBar.new()
	bar.max_value = 3000
	bar.value = pts
	bar.custom_minimum_size = Vector2(0, 26)
	_content.add_child(bar)
	var claimed: Array = st.get("claimed_free", []) if st.get("claimed_free") is Array else []
	var r := _row()
	for t in tiers:
		var tier: int = int(t["tier"])
		var reach: bool = pts >= int(t["points_required"])
		var cb: Array = _card_box(Color(0.25, 0.12, 0.45) if reach else Color(0.1, 0.1, 0.16), 200)
		cb[1].add_child(_lbl("Nivel %d · %d pts" % [tier, int(t["points_required"])], 20, GOLD))
		cb[1].add_child(_lbl("Gratis: " + _reward_text(t["free_reward"]), 16))
		cb[1].add_child(_lbl("Premium: " + _reward_text(t["premium_reward"]), 16, Color(1.0, 0.8, 0.5)))
		if claimed.has(float(tier)) or claimed.has(tier):
			cb[1].add_child(_lbl("Cobrado", 18, Color(0.5, 1.0, 0.6)))
		elif reach:
			cb[1].add_child(_btn("Cobrar", func() -> void:
				await _act("claim_season_tier", {"p_tier": tier, "p_premium": false}, "¡Recompensa cobrada!")
				open_season()))
		r.add_child(cb[0])

func _reward_text(rw: Variant) -> String:
	if not rw is Dictionary:
		return "-"
	var d: Dictionary = rw
	var parts: Array = []
	if d.has("item"):
		parts.append(_item_name(String(d["item"])))
	if d.has("coins"):
		parts.append("%d monedas" % int(d["coins"]))
	if d.has("xp"):
		parts.append("%d XP" % int(d["xp"]))
	return ", ".join(parts) if not parts.is_empty() else "-"

func _item_name(id: String) -> String:
	for it in BackendConfig.seed().get("catalog_items", []):
		if String(it["id"]) == id:
			return String(it["name"])
	return id

# --- EVENTOS --------------------------------------------------------------------------------------------------------

func open_events() -> void:
	current = "eventos"
	_clear("EVENTOS")
	var evs: Variant = (await Online.call_fn("get_events")).get("data", [])
	if not evs is Array or (evs as Array).is_empty():
		_content.add_child(_lbl("No hay eventos activos ahora. ¡Volvé pronto!", 24))
		return
	for e in evs:
		var art: Dictionary = e.get("art", {}) if e.get("art") is Dictionary else {}
		var col: Color = Color.from_string(String(art.get("color", "#446")), Color(0.3, 0.3, 0.5))
		var cb: Array = _card_box(col.darkened(0.25), 0)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		h.add_child(MenuIcon.new(String(art.get("icon", "temporada")), Color.WHITE, 110))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_lbl(String(e["title"]), 36, GOLD))
		v.add_child(_lbl(String(e.get("subtitle", "")), 22))
		var live: bool = bool(e.get("live", true))
		v.add_child(_lbl(("EN CURSO · termina el %s" if live else "PRÓXIMAMENTE · empieza el %s") % String(e["ends_at" if live else "starts_at"]).substr(0, 10), 18, Color(0.9, 0.95, 1.0)))
		v.add_child(_lbl("Reglas: " + String(e.get("rules", "")), 18))
		var rw: Dictionary = e.get("rewards", {}) if e.get("rewards") is Dictionary else {}
		var tiers_txt: Array = []
		for tt in rw.get("tiers", []):
			tiers_txt.append("%d pts: %s" % [int(tt[0]), _reward_text(tt[1])])
		v.add_child(_lbl("Recompensas: " + ", ".join(tiers_txt), 18, Color(1.0, 0.85, 0.5)))
		v.add_child(_lbl("Tu progreso: %d puntos en %d partidas" % [int(e.get("progress", 0)), int(e.get("matches", 0))], 18))
		h.add_child(v)
		cb[1].add_child(h)
		if live:
			cb[1].add_child(_btn("JUGAR", open_online))
		_content.add_child(cb[0])

# --- PERFIL ---------------------------------------------------------------------------------------------------------

const ATTR := {"power": ["Potencia", "Velocidad máxima de tus tiros (moderado)."],
	"accuracy": ["Precisión", "Menos error al apuntar."], "curve": ["Efecto", "Más comba disponible."],
	"height": ["Altura", "Control de la elevación del tiro."], "technique": ["Técnica de disparo", "Golpeos más limpios."],
	"control": ["Control", "Recepción y pases en minijuegos."]}

func open_profile() -> void:
	current = "perfil"
	_clear("PERFIL")
	var p: Dictionary = Online.profile()
	var lv: int = Online.level()
	_content.add_child(_lbl("%s  (@%s)" % [p.get("display_name", ""), p.get("username", "")], 32, GOLD))
	_content.add_child(_lbl("Nivel %d · %d XP · %d monedas · %s" % [lv, int(p.get("xp", 0)), Online.coins(), Online.backend_label()], 20))
	var id_box: Array = _card_box(Color(0.08, 0.1, 0.18), 0)
	_content.add_child(id_box[0])
	id_box[1].add_child(_lbl("Identidad", 24, GOLD))
	var g := GridContainer.new()
	g.columns = 2
	id_box[1].add_child(g)
	var fields := {}
	for f in [["display_name", "Nombre visible"], ["nickname", "Apodo"], ["shirt_number", "Número (1-99)"], ["country", "País (2 letras)"]]:
		g.add_child(_lbl(f[1], 20, Color(1, 1, 1), false))
		var e := LineEdit.new()
		e.text = str(p.get(f[0], ""))
		e.custom_minimum_size = Vector2(320, 48)
		g.add_child(e)
		fields[f[0]] = e
	id_box[1].add_child(_btn("Guardar identidad", func() -> void:
		var n: int = int((fields["shirt_number"] as LineEdit).text)
		if await _act("update_identity", {"p_display_name": (fields["display_name"] as LineEdit).text,
				"p_nickname": (fields["nickname"] as LineEdit).text, "p_country": (fields["country"] as LineEdit).text,
				"p_number": n}, "Identidad guardada"):
			PlayerCustom.number = clampi(n, 1, 99)
			PlayerCustom.save_custom()
			customize_changed.emit()))
	var un := LineEdit.new()
	un.placeholder_text = "Nuevo nombre de usuario (el primer cambio es gratis; después, uno cada 30 días)"
	un.custom_minimum_size = Vector2(0, 48)
	id_box[1].add_child(un)
	id_box[1].add_child(_btn("Cambiar nombre de usuario", func() -> void: _act("change_username", {"p_new": un.text}, "Nombre cambiado")))
	var at_box: Array = _card_box(Color(0.08, 0.1, 0.18), 0)
	_content.add_child(at_box[0])
	var attrs: Dictionary = p.get("attributes", {}) if p.get("attributes") is Dictionary else {}
	var spent: int = 0
	for k in attrs:
		spent += int(attrs[k]) - 1
	at_box[1].add_child(_lbl("Atributos de disparo · puntos libres: %d (2 por nivel; efecto moderado y con límites)" % maxi((lv - 1) * 2 - spent, 0), 24, GOLD))
	for k in ATTR:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var l := _lbl("%s %d/10 · %s" % [ATTR[k][0], int(attrs.get(k, 1)), ATTR[k][1]], 20)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var key: String = k
		var b := _btn("+", func() -> void:
			await _act("spend_attribute_point", {"p_attribute": key}, "Atributo mejorado")
			open_profile())
		b.custom_minimum_size = Vector2(64, 48)
		h.add_child(b)
		at_box[1].add_child(h)
	var rk: Array = _card_box(Color(0.08, 0.1, 0.18), 0)
	_content.add_child(rk[0])
	rk[1].add_child(_lbl("Rankings (solo partidas entre humanos; los bots no participan)", 24, GOLD))
	var lb: Variant = (await Online.call_fn("get_leaderboard", {"p_mode": "todos", "p_metric": "wins", "p_limit": 20})).get("data", [])
	if lb is Array and not (lb as Array).is_empty():
		for i in (lb as Array).size():
			var row: Dictionary = lb[i]
			rk[1].add_child(_lbl("%d. %s — %d victorias (%d partidas)" % [i + 1, row["username"], int(row["value"]), int(row["played"])], 20))
	else:
		rk[1].add_child(_lbl("Todavía no hay partidas entre humanos esta temporada." if Online.has_server() else "Los rankings necesitan el servidor (sin servidor configurado).", 20))
	_content.add_child(_btn("Cerrar sesión", func() -> void:
		await Online.sign_out()
		get_tree().change_scene_to_file(WelcomeScreen.SCENE)))

# --- PERSONALIZAR ---------------------------------------------------------------------------------------------------

var _pending_appearance: Dictionary = {}

## Pestañas de Personalizar (pedido del usuario: el menu de listas desplegables era feo). Cada una muestra los diseños
## como tarjetas (con rareza y candado) y los colores como muestras redondas del color real.
const CUSTOM_TABS := [["Camiseta", "jersey"], ["Short", "shorts"], ["Medias", "socks"], ["Botines", "boots"],
	["Cuerpo", "body"], ["Balón", "ball"], ["Festejo", "celebration"], ["Número", "number_style"]]
var _custom_tab: String = "jersey"
var _custom_box: VBoxContainer
var _custom_tab_buttons: Dictionary = {}

func open_customize() -> void:
	current = "personalizar"
	_clear("PERSONALIZAR")
	_side_panel()
	customize_mode.emit(true)
	_catalog = await Online.catalog("catalog_items")
	_content.add_child(_lbl("Arrastrá sobre el jugador para girarlo. Los colores son libres; los diseños especiales se desbloquean.", 17, Color(0.8, 0.86, 1.0)))
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	_content.add_child(tabs)
	_custom_tab_buttons = {}
	for t in CUSTOM_TABS:
		var b := Button.new()
		b.text = String(t[0])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(118, 50)
		b.add_theme_font_size_override("font_size", 19)
		var key: String = String(t[1])
		b.pressed.connect(func() -> void: _show_custom_tab(key))
		_custom_tab_buttons[key] = b
		tabs.add_child(b)
	_custom_box = VBoxContainer.new()
	_custom_box.add_theme_constant_override("separation", 12)
	_content.add_child(_custom_box)
	_show_custom_tab(_custom_tab)

func _current_appearance() -> Dictionary:
	return (Online.profile().get("appearance", {}) as Dictionary).merged(_pending_appearance, true)

func _show_custom_tab(key: String) -> void:
	_custom_tab = key
	for k in _custom_tab_buttons:
		(_custom_tab_buttons[k] as Button).set_pressed_no_signal(k == key)
	for c in _custom_box.get_children():
		c.queue_free()
	match key:
		"jersey":
			_designs("Diseño", "jersey")
			_swatches("Color principal", "jersey_color", PlayerCustom.JERSEYS, PlayerCustom.JERSEY_NAMES, PlayerCustom.jersey)
			_swatches("Segundo color", "jersey_color2", PlayerCustom.JERSEYS, PlayerCustom.JERSEY_NAMES, PlayerCustom.jersey2)
		"shorts":
			_designs("Diseño", "shorts")
			_swatches("Color", "shorts_color", PlayerCustom.SHORTS, PlayerCustom.SHORT_NAMES, PlayerCustom.shorts)
		"socks":
			_designs("Diseño", "socks")
			_swatches("Color", "socks_color", PlayerCustom.SOCKS, PlayerCustom.SOCK_NAMES, PlayerCustom.socks)
			_chips("Altura", "sock_height", PlayerCustom.SOCK_HEIGHT_NAMES, PlayerCustom.sock_height)
		"boots":
			_designs("Botines", "boots")
		"body":
			_swatches("Piel", "skin", PlayerCustom.SKINS, PlayerCustom.SKIN_NAMES, PlayerCustom.skin)
			_swatches("Pelo", "hair", PlayerCustom.HAIRS, PlayerCustom.HAIR_NAMES, PlayerCustom.hair)
		_:
			_designs({"ball": "Balón", "celebration": "Festejo", "number_style": "Estilo del número"}.get(key, key), key)

func _section(title: String) -> HFlowContainer:
	_custom_box.add_child(_lbl(title, 22, GOLD, false))
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 10)
	r.add_theme_constant_override("v_separation", 10)
	_custom_box.add_child(r)
	return r

## Diseños del catalogo como tarjetas: borde del color de la rareza, dorado y grueso el elegido, candado si no es tuyo.
func _designs(title: String, kind: String) -> void:
	var items: Array = _items_of(kind)
	if items.is_empty():
		return
	var r: HFlowContainer = _section(title)
	var cur: String = String(_current_appearance().get(kind, ""))
	# Sin eleccion guardada: el primer diseño gratuito es el que tiene puesto.
	if cur == "":
		for it0 in items:
			if String(it0["unlock"]) == "free":
				cur = String(it0["id"])
				break
	for it in items:
		var id: String = String(it["id"])
		var ok: bool = _available(it)
		var sel: bool = id == cur
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 92)
		b.text = String(it["name"]) + ("" if ok else "\n" + unlock_text(it))
		b.add_theme_font_size_override("font_size", 17)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var rc: Color = RARITY.get(String(it.get("rarity", "comun")), Color.GRAY)
		for st in ["normal", "hover", "pressed", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.07, 0.1, 0.18, 0.95) if st != "hover" else Color(0.12, 0.17, 0.3, 0.95)
			if not ok:
				sb.bg_color = Color(0.05, 0.05, 0.08, 0.9)
			sb.border_color = GOLD if sel else rc
			sb.set_border_width_all(5 if sel else 2)
			sb.set_corner_radius_all(14)
			sb.set_content_margin_all(8)
			b.add_theme_stylebox_override(st, sb)
		b.disabled = not ok
		b.pressed.connect(func() -> void:
			_set_appearance(kind, id)
			_show_custom_tab(_custom_tab))
		r.add_child(b)

## Colores como muestras redondas del color real; la elegida con aro blanco grueso.
func _swatches(title: String, key: String, colors: Array, names: Array, cur: int) -> void:
	var r: HFlowContainer = _section(title)
	for i in colors.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(62, 62)
		b.tooltip_text = String(names[i]) if i < names.size() else ""
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = colors[i]
			sb.set_corner_radius_all(31)
			sb.border_color = Color.WHITE if i == cur else Color(1, 1, 1, 0.25)
			sb.set_border_width_all(5 if i == cur else (3 if st == "hover" else 2))
			b.add_theme_stylebox_override(st, sb)
		var idx: int = i
		b.pressed.connect(func() -> void:
			_set_appearance(key, idx)
			_show_custom_tab(_custom_tab))
		r.add_child(b)

## Opciones cortas (p. ej. altura de las medias) como botones de seleccion.
func _chips(title: String, key: String, names: Array, cur: int) -> void:
	var r: HFlowContainer = _section(title)
	for i in names.size():
		var b := Button.new()
		b.text = String(names[i])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(130, 48)
		b.add_theme_font_size_override("font_size", 18)
		b.set_pressed_no_signal(i == cur)
		var idx: int = i
		b.pressed.connect(func() -> void:
			_set_appearance(key, idx)
			_show_custom_tab(_custom_tab))
		r.add_child(b)

func _items_of(kind: String) -> Array:
	return _catalog.filter(func(it: Dictionary) -> bool: return String(it["kind"]) == kind and bool(it.get("active", true)))

func _available(it: Dictionary) -> bool:
	return String(it["unlock"]) == "free" or Online.owns(String(it["id"]))

func _option(g: GridContainer, label: String, key: String) -> void:
	g.add_child(_lbl(label, 20, Color(1, 1, 1), false))
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(300, 46)
	ob.add_theme_font_size_override("font_size", 20)
	var items: Array = _items_of(key)
	var cur: String = String((Online.profile().get("appearance", {}) as Dictionary).get(key, ""))
	for i in items.size():
		var it: Dictionary = items[i]
		ob.add_item(String(it["name"]) + ("" if _available(it) else "  [bloqueado: %s]" % unlock_text(it)), i)
		ob.set_item_disabled(i, not _available(it))
		if String(it["id"]) == cur:
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void: _set_appearance(key, String(items[i]["id"])))
	g.add_child(ob)

func _color(g: GridContainer, label: String, key: String, names: Array, cur: Callable) -> void:
	g.add_child(_lbl(label, 20, Color(1, 1, 1), false))
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(300, 46)
	ob.add_theme_font_size_override("font_size", 20)
	for i in names.size():
		ob.add_item(String(names[i]), i)
	ob.select(clampi(int(cur.call()), 0, names.size() - 1))
	ob.item_selected.connect(func(i: int) -> void: _set_appearance(key, i))
	g.add_child(ob)

func _set_appearance(key: String, value: Variant) -> void:
	_pending_appearance[key] = value
	PlayerCustom.apply_appearance(_pending_appearance.merged((Online.profile().get("appearance", {}) as Dictionary).merged(_pending_appearance, true), true), _catalog)
	customize_changed.emit()

## Al salir de Personalizar se guarda en el servidor (que valida que cada objeto equipado sea tuyo o gratuito).
func _send_appearance() -> void:
	if _pending_appearance.is_empty():
		return
	var ap: Dictionary = _pending_appearance.duplicate()
	_pending_appearance = {}
	var r: Dictionary = await Online.call_state_fn("update_appearance", {"p_appearance": ap})
	if not r.get("ok", false):
		_say(String(r.get("error", "No se pudo guardar la apariencia.")))
