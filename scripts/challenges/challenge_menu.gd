class_name ChallengeMenu
extends Control
## Las tres secciones del juego, cada una con su pantalla propia y SIN pestañas para saltar a las otras (para salir, «‹
## Volver», que sube un nivel y desde la raiz vuelve al menu principal):
##  - ACADEMIA: practica de tiros (penales contra la CPU y tiro libre) y los 8 niveles de ejercicios.
##  - DESAFÍOS: progresion: nivel y experiencia, desafios diarios y semanales, logros, historial y records.
##  - MINIJUEGOS ARCADE: categorias -> modalidades -> niveles -> dificultad (Facil, Normal, Dificil, Experto). Los
##    desafios de precision contra el arco (la antigua Arena) viven en la categoria DESAFÍOS DE ARCO.
## La practica libre (todo abierto, no cuenta para el progreso) se puede activar en Academia y en Arcade.

const SCENE := "res://scenes/challenges/challenge_menu.tscn"
const MEDAL_COLORS := [Color(0.55, 0.58, 0.65), Color(0.80, 0.52, 0.25), Color(0.80, 0.82, 0.88), Color(1.0, 0.82, 0.25)]
const SECTION_TITLES := {"academia": "ACADEMIA", "desafios": "DESAFÍOS", "arcade": "MINIJUEGOS ARCADE"}

## Seccion abierta: "academia", "desafios" o "arcade" (la elige el menu principal).
static var section: String = "academia"
static var practice: bool = false
## Arcade: categoria y modalidad abiertas (se recuerdan al volver de un nivel).
static var arcade_category: String = ""
static var arcade_item: String = ""

var _list: VBoxContainer
var _title: Label
var _practice_btn: Button
var _player: Label
## Pagina de dificultad abierta (arcade): el nivel elegido.
var _pending: Dictionary = {}

func _ready() -> void:
	SpSettings.load_settings()
	SpSettings.override_difficulty = -1
	PlayerProgress.load_progress()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.07, 0.10)
	add_child(bg)
	var stripes := TextureRect.new()
	stripes.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.set_color(0, _section_color().darkened(0.55))
	grad.set_color(1, Color(0.02, 0.06, 0.10, 0.9))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 1)
	gt.fill_to = Vector2(0, 0)
	stripes.texture = gt
	stripes.stretch_mode = TextureRect.STRETCH_SCALE
	stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stripes)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vb.add_child(top)
	top.add_child(_btn("‹ Volver", _back, 160))
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	top.add_child(_title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_practice_btn = _btn("", func() -> void:
		practice = not practice
		_refresh(), 260)
	top.add_child(_practice_btn)
	_player = Label.new()
	_player.add_theme_font_size_override("font_size", 20)
	_player.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	vb.add_child(_player)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_refresh()

func _section_color() -> Color:
	return {"academia": Color(0.10, 0.50, 0.22), "desafios": Color(0.48, 0.18, 0.62), "arcade": Color(0.85, 0.45, 0.05)}.get(section, Color(0.1, 0.3, 0.6))

## Volver: sube un nivel dentro de la seccion; desde la raiz, al menu principal.
func _back() -> void:
	if not _pending.is_empty():
		_pending = {}
	elif section == "arcade" and arcade_item != "":
		arcade_item = ""
	elif section == "arcade" and arcade_category != "":
		arcade_category = ""
	else:
		get_tree().change_scene_to_file(MainMenu.SCENE)
		return
	_refresh()

func _btn(t: String, cb: Callable, w: float = 200.0) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 56)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	_title.text = SECTION_TITLES.get(section, "")
	_practice_btn.visible = section != "desafios"
	_practice_btn.text = "Práctica libre: %s" % ("Sí" if practice else "No")
	var lv: int = PlayerProgress.level()
	_player.text = "Nivel de jugador %d · %d de experiencia%s" % [lv, PlayerProgress.xp,
		" · práctica libre: todo abierto, no cuenta para el progreso" if practice and section != "desafios" else ""]
	match section:
		"academia":
			_build_academia()
		"desafios":
			_build_desafios()
		_:
			_build_arcade()

func _header(t: String, sub: String = "") -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	_list.add_child(l)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.add_theme_font_size_override("font_size", 17)
		s.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		_list.add_child(s)

func _row() -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 10)
	r.add_theme_constant_override("v_separation", 10)
	_list.add_child(r)
	return r

func _card(title: String, info: String, medal: int, enabled: bool, cb: Callable, color: Color = Color(0.08, 0.12, 0.18), w: float = 286.0) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [title, info]
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 86)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 18)
	b.disabled = not enabled
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.95) if enabled else Color(0.08, 0.08, 0.1, 0.8)
	sb.border_color = MEDAL_COLORS[medal]
	sb.set_border_width_all(3 if medal > 0 else 1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s2: StyleBoxFlat = sb.duplicate()
		if st == "hover":
			s2.bg_color = sb.bg_color.lightened(0.12)
		b.add_theme_stylebox_override(st, s2)
	b.pressed.connect(cb)
	return b

func _medal_text(m: int, best: int) -> String:
	return ("%s · récord %d" % [ChallengeScore.MEDAL_NAMES[m], best]) if best > 0 else "Sin jugar"

# --- ACADEMIA -----------------------------------------------------------------------------------------------------------

func _build_academia() -> void:
	_header("Práctica de tiros", "Patea con el trazo de siempre: tanda de penales contra la CPU o tiros libres desde donde quieras.")
	var pr: HFlowContainer = _row()
	pr.add_child(_card("Penales", "Tanda contra la CPU: tirás y atajás", 0, true, func() -> void: _play_set_piece(SetPieceGame.Mode.PENALTY),
		Color(0.08, 0.30, 0.75)))
	pr.add_child(_card("Tiro libre", "Elegí dónde: barrera y arquero", 0, true, func() -> void: _play_set_piece(SetPieceGame.Mode.FREE_KICK),
		Color(0.75, 0.16, 0.12)))
	for lv in ChallengeCatalog.levels():
		var defs: Array = ChallengeCatalog.level_defs(lv)
		var open: bool = PlayerProgress.is_unlocked(defs[0])
		var sub: String = "" if open else "Bloqueado: bronce en %d de los %d ejercicios del nivel %d" % [int(ceil(ChallengeCatalog.level_defs(lv - 1).size() / 2.0)), ChallengeCatalog.level_defs(lv - 1).size(), lv - 1]
		_header("Nivel %d · %s" % [lv, ChallengeCatalog.level_area(lv)], sub)
		var row: HFlowContainer = _row()
		for d in defs:
			var id: String = String(d["id"])
			var info: String = "%s · %d intentos" % [_medal_text(PlayerProgress.medal(id), PlayerProgress.best(id)), int(d["attempts"])]
			row.add_child(_card(String(d["title"]), info, PlayerProgress.medal(id), open or practice, _start_challenge.bind(d, 0)))

func _play_set_piece(m: int) -> void:
	SetPieceGame.next_mode = m
	get_tree().change_scene_to_file(SetPieceGame.SCENE)

# --- DESAFÍOS (progresion) ---------------------------------------------------------------------------------------------

## Diarios, semanales, logros, historial y records y medallas conseguidos.
func _build_desafios() -> void:
	Achievements.load_state()
	_header("Desafíos de hoy", "Se renuevan cada día")
	var row: HFlowContainer = _row()
	for d in Achievements.todays_daily():
		var key: String = "%s@%d" % [d[0], Achievements.day_index()]
		var p: int = Achievements.progress_of(d[2], int(d[3]), "dia")
		var dn: bool = Achievements.is_done(key)
		row.add_child(_card(String(d[1]), "✔ Completado · +%d XP" % Achievements.DAILY_XP if dn else "%d / %d · +%d XP" % [p, int(d[3]), Achievements.DAILY_XP],
			3 if dn else 0, true, func() -> void: pass))
	_header("Desafíos de la semana")
	var row2: HFlowContainer = _row()
	for d in Achievements.this_weeks():
		var key2: String = "%s@s%d" % [d[0], Achievements.week_index()]
		var p2: int = Achievements.progress_of(d[2], int(d[3]), "semana")
		var dn2: bool = Achievements.is_done(key2)
		row2.add_child(_card(String(d[1]), "✔ Completado · +%d XP" % Achievements.WEEKLY_XP if dn2 else "%d / %d · +%d XP" % [p2, int(d[3]), Achievements.WEEKLY_XP],
			3 if dn2 else 0, true, func() -> void: pass))
	_header("Logros")
	var row3: HFlowContainer = _row()
	for d in Achievements.PERMANENT:
		var dn3: bool = Achievements.is_done(String(d[0]))
		var p3: int = Achievements.progress_of(d[3], int(d[4]))
		var info: String = "✔ %s · +%d XP" % [Achievements.done_date(String(d[0])), int(d[5])] if dn3 else "%s · %d / %d" % [d[2], p3, int(d[4])]
		if String(d[6]) != "" and not dn3:
			info += " · abre un cosmético"
		row3.add_child(_card(String(d[1]), info, 3 if dn3 else 0, true, func() -> void: pass))
	_build_records()
	var hist: Array = Achievements.history()
	if not hist.is_empty():
		_header("Historial")
		var l := Label.new()
		var lines: PackedStringArray = []
		for h in hist.slice(0, 12):
			lines.append("%s — %s%s" % [h["date"], h["title"], " (desafío)" if bool(h["periodic"]) else ""])
		l.text = "\n".join(lines)
		l.add_theme_font_size_override("font_size", 18)
		_list.add_child(l)

## Records y medallas: cuantas de cada una y los mejores puntajes por minijuego.
func _build_records() -> void:
	PlayerProgress.load_progress()
	var counts := [0, 0, 0, 0]
	for id in PlayerProgress.records:
		counts[clampi(int((PlayerProgress.records[id] as Dictionary).get("medal", 0)), 0, 3)] += 1
	_header("Medallas y récords", "Oro %d · Plata %d · Bronce %d" % [counts[3], counts[2], counts[1]])
	var row: HFlowContainer = _row()
	for g in MinigameCatalog.games():
		var best: int = 0
		var medal: int = 0
		for d in MinigameCatalog.levels(String(g["id"])):
			for dif in [-1, 0, 1, 2, 3]:
				var k: String = String(d["id"]) if dif < 0 else "%s@%d" % [d["id"], dif]
				best = maxi(best, PlayerProgress.best(k))
				medal = maxi(medal, PlayerProgress.medal(k))
		row.add_child(_card(String(g["title"]), "Récord %d · %s" % [best, ChallengeScore.MEDAL_NAMES[medal]] if best > 0 else "Sin jugar",
			medal, true, func() -> void: pass, Color(0.08, 0.12, 0.18), 230))

# --- MINIJUEGOS ARCADE -------------------------------------------------------------------------------------------------

func _category(id: String) -> Dictionary:
	for c in MinigameCatalog.categories():
		if String(c["id"]) == id:
			return c
	return {}

func _item_id(it: Dictionary) -> String:
	return String(it.get("game", it.get("id", "")))

func _build_arcade() -> void:
	if not _pending.is_empty():
		_build_difficulty_page()
		return
	var cat: Dictionary = _category(arcade_category)
	if cat.is_empty():
		arcade_category = ""
		arcade_item = ""
		_header("Categorías", "Elegí una categoría: adentro están sus modalidades, niveles y dificultades.")
		var row: HFlowContainer = _row()
		for c in MinigameCatalog.categories():
			var col: Array = c.get("color", [0.1, 0.2, 0.3])
			row.add_child(_card(String(c["title"]), "%s\n%d modalidades" % [c.get("description", ""), (c["items"] as Array).size()], 0, true,
				func() -> void:
					arcade_category = String(c["id"])
					_refresh(), Color(float(col[0]), float(col[1]), float(col[2])).darkened(0.35), 420))
		return
	var item: Dictionary = {}
	for it in cat["items"]:
		if _item_id(it) == arcade_item:
			item = it
	if item.is_empty():
		arcade_item = ""
		_header(String(cat["title"]), String(cat.get("description", "")))
		var row2: HFlowContainer = _row()
		for it in cat["items"]:
			var t: String
			var desc: String
			if String(it["type"]) == "game":
				var g: Dictionary = MinigameCatalog.game(String(it["game"]))
				t = String(g.get("title", it["game"]))
				desc = "%s\n%d niveles" % [g.get("description", ""), (g.get("levels", []) as Array).size()]
			else:
				t = String(it["title"])
				desc = "%s\n%d niveles" % [it.get("description", ""), (it["ids"] as Array).size()]
			row2.add_child(_card(t, desc, 0, true, func() -> void:
				arcade_item = _item_id(it)
				_refresh(), Color(0.08, 0.12, 0.18), 420))
		return
	# Modalidad: sus niveles (cada uno abre la eleccion de dificultad).
	if String(item["type"]) == "game":
		var g2: Dictionary = MinigameCatalog.game(String(item["game"]))
		_header(String(g2.get("title", "")), String(g2.get("description", "")))
		var row3: HFlowContainer = _row()
		for d in MinigameCatalog.levels(String(item["game"])):
			var id: String = String(d["id"])
			var open: bool = practice or MinigameCatalog.is_unlocked(d)
			var m: int = MinigameCatalog.best_medal(id)
			var info: String = ChallengeScore.MEDAL_NAMES[m] if open else "Bloqueado: bronce en el nivel %d" % (int(d["level"]) - 1)
			row3.add_child(_card("%d · %s" % [int(d["level"]), d["title"]], info, m, open, func() -> void:
				_pending = {"kind": "game", "def": d}
				_refresh()))
	else:
		_header(String(item["title"]), String(item.get("description", "")))
		var row4: HFlowContainer = _row()
		var n: int = 0
		for aid in item["ids"]:
			var ad: Dictionary = ChallengeCatalog.by_id(String(aid))
			if ad.is_empty():
				continue
			n += 1
			var bm: int = 0
			for dif in MinigameCatalog.DIFFICULTIES.size():
				bm = maxi(bm, PlayerProgress.medal(PlayerProgress.key(ad, dif)))
			row4.add_child(_card("%d · %s" % [n, ad["title"]], String(ad.get("explain", "")), bm, true, func() -> void:
				_pending = {"kind": "arena", "def": ad}
				_refresh()))

## Eleccion de dificultad de un nivel: Facil, Normal, Dificil y Experto (cada una abre con bronce en la anterior).
func _build_difficulty_page() -> void:
	var d: Dictionary = _pending["def"]
	var arena: bool = String(_pending["kind"]) == "arena"
	_header(String(d["title"]), String(d.get("explain", d.get("objective", ""))))
	var row: HFlowContainer = _row()
	for dif in MinigameCatalog.DIFFICULTIES.size():
		var key: String = PlayerProgress.key(d, dif) if arena else "%s@%d" % [d["id"], dif]
		var prev_ok: bool = dif == 0 or PlayerProgress.medal(PlayerProgress.key(d, dif - 1) if arena else "%s@%d" % [d["id"], dif - 1]) >= 1
		var open: bool = practice or prev_ok
		var info: String = _medal_text(PlayerProgress.medal(key), PlayerProgress.best(key)) if open else "Bloqueado: bronce en %s" % MinigameCatalog.DIFFICULTIES[maxi(dif - 1, 0)]
		row.add_child(_card(MinigameCatalog.DIFFICULTIES[dif], info, PlayerProgress.medal(key), open, func() -> void:
			if arena:
				_start_challenge(d, dif)
			else:
				var dd: Dictionary = MinigameCatalog.at_difficulty(d, dif)
				dd["practice"] = practice
				MinigameCatalog.start(get_tree(), dd), Color(0.08, 0.12, 0.18), 230))

func _start_challenge(d: Dictionary, difficulty: int) -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.CHALLENGE
	SetPieceGame.next_challenge = ChallengeCatalog.at_difficulty(d, difficulty)
	SetPieceGame.next_practice = practice
	get_tree().change_scene_to_file(SetPieceGame.SCENE)
