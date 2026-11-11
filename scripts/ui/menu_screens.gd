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
## Modalidades online que ya tienen partida completa en esta version (las demas se muestran «en preparacion»).
const READY_ONLINE := ["penales"]

var _panel: PanelContainer
var _content: VBoxContainer
var _title: Label
var _coins: Label
var _toast: Label
var current: String = ""
var _catalog: Array = []
var _search_box: PanelContainer = null
var _searching: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	add_child(_panel)
	_full_panel()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.08, 0.93)
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
	for m in [["PENALES", "Tanda contra la CPU: tirás y atajás.", "penal", Color(0.08, 0.3, 0.75), SetPieceGame.Mode.PENALTY],
			["TIRO LIBRE", "Elegí dónde patear: barrera y arquero.", "tiro_libre", Color(0.1, 0.5, 0.25), SetPieceGame.Mode.FREE_KICK]]:
		var cb: Array = _card_box(m[3], 360)
		var h := HBoxContainer.new()
		h.add_child(MenuIcon.new(m[2], Color.WHITE, 72))
		h.add_child(_lbl(m[0], 32, GOLD, false))
		cb[1].add_child(h)
		cb[1].add_child(_lbl(m[1], 20))
		var mode: int = m[4]
		var b := _btn("JUGAR", func() -> void: play_offline.emit(mode))
		b.text = "JUGAR " + String(m[0])
		cb[1].add_child(b)
		r.add_child(cb[0])

# --- JUGAR ONLINE ---------------------------------------------------------------------------------------------------

func open_online() -> void:
	current = "online"
	_clear("JUGAR ONLINE")
	var info := _lbl("Cargando el lobby…", 20, Color(0.75, 0.85, 1.0))
	_content.add_child(info)
	var lobby: Dictionary = (await Online.call_fn("get_lobby")).get("data", {})
	if lobby == null:
		lobby = {}
	var srv: String = "" if Online.has_server() else "  ·  " + Online.backend_label()
	info.text = "Jugadores humanos conectados: %d  ·  Partidas en curso: %d  ·  Actividad del mundo (partidas de las últimas 2 h, con bots): %d%s" % [
		int(lobby.get("humans_online", 0)), int(lobby.get("matches_active", 0)), int(lobby.get("world_activity", 0)), srv]
	var modes: Array = await Online.catalog("game_modes")
	var r := _row()
	for gm in modes:
		var art: Dictionary = gm.get("art", {}) if gm.get("art") is Dictionary else {}
		var col: Color = Color.from_string(String(art.get("color", "#335")), Color(0.2, 0.2, 0.3))
		var cb: Array = _card_box(col.darkened(0.35), 380)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.add_child(MenuIcon.new(String(art.get("icon", "ball")), Color.WHITE, 64))
		var tv := VBoxContainer.new()
		tv.custom_minimum_size = Vector2(280, 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(_lbl(String(gm["name"]), 28, GOLD))
		tv.add_child(_lbl(String(gm["description"]), 18))
		h.add_child(tv)
		cb[1].add_child(h)
		cb[1].add_child(_lbl("Reglas: " + String(gm["rules"]), 16, Color(0.85, 0.88, 0.95)))
		var fees: Array = (gm.get("entry_fees", [0]) as Array).map(func(x: Variant) -> int: return int(x))
		cb[1].add_child(_lbl("Recompensas: XP, monedas y puntos de temporada. Entrada en monedas virtuales: %s (sin dinero real)." % ", ".join(fees.map(func(x: int) -> String: return "gratis" if x == 0 else str(x))), 16, Color(0.85, 0.88, 0.95)))
		if String(gm["id"]) in READY_ONLINE:
			var fee_opt := OptionButton.new()
			for f in fees:
				fee_opt.add_item("Entrada: gratis" if f == 0 else "Entrada: %d monedas" % f, f)
			fee_opt.add_theme_font_size_override("font_size", 20)
			cb[1].add_child(fee_opt)
			var mode_id: String = String(gm["id"])
			cb[1].add_child(_btn("BUSCAR RIVAL", func() -> void: _search(mode_id, fee_opt.get_selected_id())))
		else:
			cb[1].add_child(_lbl("Modalidad online en preparación: ya se juega offline en Minijuegos Arcade.", 18, Color(1.0, 0.8, 0.5)))
		r.add_child(cb[0])

## Busca rival: primero humanos (el servidor empareja); despues de la espera, un bot generado por el servidor.
func _search(mode: String, fee: int) -> void:
	if _searching:
		return
	_searching = true
	var cb: Array = _card_box(Color(0.1, 0.12, 0.25), 0)
	_search_box = cb[0]
	_search_box.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_search_box)
	var lab := _lbl("Buscando rival…", 30, GOLD)
	cb[1].add_child(lab)
	var sub := _lbl("Primero buscamos un rival humano.", 20)
	cb[1].add_child(sub)
	cb[1].add_child(_btn("Cancelar", func() -> void:
		_searching = false
		Online.call_fn("cancel_search")))
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
		lab.text = "Buscando rival… %d s" % int(waited)
		sub.text = "Humanos buscando esta modalidad: %d" % int(d.get("humans_searching", 0))
		if float(d.get("waited", 0.0)) >= float(d.get("bot_after", 8)):
			sub.text = "No hay humanos libres: preparando un rival…"
			var rb: Dictionary = await Online.call_fn("start_bot_match", {"p_mode": mode})
			if rb.get("ok", false):
				view = rb["data"]
				break
		await get_tree().create_timer(2.0).timeout
	if is_instance_valid(_search_box):
		_search_box.queue_free()
	if _searching and not view.is_empty():
		_searching = false
		OnlineMatch.pending = view
		get_tree().change_scene_to_file(SetPieceGame.SCENE)
	_searching = false

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

func open_customize() -> void:
	current = "personalizar"
	_clear("PERSONALIZAR")
	_side_panel()
	customize_mode.emit(true)
	_catalog = await Online.catalog("catalog_items")
	_content.add_child(_lbl("Arrastrá sobre el jugador para girarlo. Los colores son libres; los diseños especiales se desbloquean.", 18))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 8)
	_content.add_child(g)
	_option(g, "Camiseta", "jersey")
	_color(g, "Color camiseta", "jersey_color", PlayerCustom.JERSEY_NAMES, func() -> int: return PlayerCustom.jersey)
	_color(g, "Segundo color", "jersey_color2", PlayerCustom.JERSEY_NAMES, func() -> int: return PlayerCustom.jersey2)
	_option(g, "Short", "shorts")
	_color(g, "Color short", "shorts_color", PlayerCustom.SHORT_NAMES, func() -> int: return PlayerCustom.shorts)
	_option(g, "Medias", "socks")
	_color(g, "Color medias", "socks_color", PlayerCustom.SOCK_NAMES, func() -> int: return PlayerCustom.socks)
	_color(g, "Altura medias", "sock_height", PlayerCustom.SOCK_HEIGHT_NAMES, func() -> int: return PlayerCustom.sock_height)
	_option(g, "Botines", "boots")
	_color(g, "Piel", "skin", PlayerCustom.SKIN_NAMES, func() -> int: return PlayerCustom.skin)
	_color(g, "Pelo", "hair", PlayerCustom.HAIR_NAMES, func() -> int: return PlayerCustom.hair)
	_option(g, "Balón", "ball")
	_option(g, "Festejo", "celebration")
	_option(g, "Número", "number_style")

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
