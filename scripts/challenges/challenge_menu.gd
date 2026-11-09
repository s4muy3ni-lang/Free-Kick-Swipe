class_name ChallengeMenu
extends Control
## Seleccion de la Academia de tiros (niveles y ejercicios) y de la Arena de desafios (categorias y dificultades), con la
## medalla y el record de cada uno, lo que esta bloqueado (y que pide para abrirse), el nivel y la experiencia del jugador
## y la PRACTICA LIBRE (cualquier ejercicio o desafio, sin tocar el progreso).

const SCENE := "res://scenes/challenges/challenge_menu.tscn"
const MEDAL_COLORS := [Color(0.55, 0.58, 0.65), Color(0.80, 0.52, 0.25), Color(0.80, 0.82, 0.88), Color(1.0, 0.82, 0.25)]

## Pestaña abierta (se recuerda al volver): "academia", "arena" o "arcade" (minijuegos, MinigameCatalog).
static var tab: String = "academia"
static var practice: bool = false

var _list: VBoxContainer
var _tab_a: Button
var _tab_r: Button
var _tab_m: Button
var _practice_btn: Button
var _player: Label

func _ready() -> void:
	SpSettings.load_settings()
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
	grad.set_color(0, Color(0.05, 0.30, 0.12, 0.9))
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
	top.add_theme_constant_override("separation", 12)
	vb.add_child(top)
	top.add_child(_btn("‹ Menú", func() -> void: get_tree().change_scene_to_file(MainMenu.SCENE), 140))
	_tab_a = _btn("ACADEMIA DE TIROS", func() -> void: _set_tab("academia"), 300)
	top.add_child(_tab_a)
	_tab_r = _btn("ARENA DE DESAFÍOS", func() -> void: _set_tab("arena"), 300)
	top.add_child(_tab_r)
	_tab_m = _btn("ARCADE", func() -> void: _set_tab("arcade"), 170)
	top.add_child(_tab_m)
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

func _set_tab(t: String) -> void:
	tab = t
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
	_tab_a.disabled = tab == "academia"
	_tab_r.disabled = tab == "arena"
	_tab_m.disabled = tab == "arcade"
	_practice_btn.text = "Práctica libre: %s" % ("Sí" if practice else "No")
	var lv: int = PlayerProgress.level()
	_player.text = "Nivel de jugador %d · %d de experiencia%s" % [lv, PlayerProgress.xp,
		" · práctica libre: todo abierto, no cuenta para el progreso" if practice else ""]
	if tab == "academia":
		_build_academia()
	elif tab == "arcade":
		_build_arcade()
	else:
		_build_arena()

func _header(t: String, sub: String = "") -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	_list.add_child(l)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.add_theme_font_size_override("font_size", 17)
		s.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		_list.add_child(s)

func _row() -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 10)
	r.add_theme_constant_override("v_separation", 10)
	_list.add_child(r)
	return r

func _card(title: String, info: String, medal: int, enabled: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [title, info]
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(286, 86)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 18)
	b.disabled = not enabled
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.12, 0.18, 0.95) if enabled else Color(0.08, 0.08, 0.1, 0.8)
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

func _build_academia() -> void:
	for lv in ChallengeCatalog.levels():
		var defs: Array = ChallengeCatalog.level_defs(lv)
		var open: bool = PlayerProgress.is_unlocked(defs[0])
		var sub: String = "" if open else "Bloqueado: bronce en %d de los %d ejercicios del nivel %d" % [int(ceil(ChallengeCatalog.level_defs(lv - 1).size() / 2.0)), ChallengeCatalog.level_defs(lv - 1).size(), lv - 1]
		_header("Nivel %d · %s" % [lv, ChallengeCatalog.level_area(lv)], sub)
		var row: HFlowContainer = _row()
		for d in defs:
			var id: String = String(d["id"])
			var info: String = "%s · %d intentos" % [_medal_text(PlayerProgress.medal(id), PlayerProgress.best(id)), int(d["attempts"])]
			row.add_child(_card(String(d["title"]), info, PlayerProgress.medal(id), open or practice, _start.bind(d, 0)))

func _build_arena() -> void:
	for cat in ChallengeCatalog.categories():
		_header(String(cat))
		var row: HFlowContainer = _row()
		for d in ChallengeCatalog.category_defs(cat):
			var best_medal: int = 0
			for dif in 5:
				best_medal = maxi(best_medal, PlayerProgress.medal(PlayerProgress.key(d, dif)))
			var info := ""
			var opened: int = 0
			for dif in 5:
				if PlayerProgress.difficulty_unlocked(d, dif):
					opened = dif
			info = "Hasta %s · %s" % [SpSettings.ALL_DIFFICULTY_NAMES[opened], ChallengeScore.MEDAL_NAMES[best_medal]]
			row.add_child(_card(String(d["title"]), info, best_medal, true, _pick_difficulty.bind(d)))

## Arcade: cada minijuego con sus niveles (el siguiente se abre con bronce en el anterior; en practica libre, todos).
func _build_arcade() -> void:
	for g in MinigameCatalog.games():
		_header(String(g["title"]), String(g.get("description", "")))
		var row: HFlowContainer = _row()
		for d in MinigameCatalog.levels(String(g["id"])):
			var id: String = String(d["id"])
			var open: bool = practice or MinigameCatalog.is_unlocked(d)
			var info: String = _medal_text(PlayerProgress.medal(id), PlayerProgress.best(id)) if open else "Bloqueado: bronce en el nivel %d" % (int(d["level"]) - 1)
			row.add_child(_card("%d · %s" % [int(d["level"]), d["title"]], info, PlayerProgress.medal(id), open, _start_minigame.bind(d)))

func _start_minigame(d: Dictionary) -> void:
	var dd: Dictionary = d.duplicate(true)
	dd["practice"] = practice
	MinigameCatalog.start(get_tree(), dd)

## Arena: elegir la dificultad (las abiertas; en practica libre, todas).
func _pick_difficulty(d: Dictionary) -> void:
	for c in _list.get_children():
		c.queue_free()
	_header(String(d["title"]), String(d["explain"]))
	var row: HFlowContainer = _row()
	for dif in 5:
		var key: String = PlayerProgress.key(d, dif)
		var open: bool = practice or PlayerProgress.difficulty_unlocked(d, dif)
		var info: String = _medal_text(PlayerProgress.medal(key), PlayerProgress.best(key)) if open else "Bloqueado: bronce en %s" % SpSettings.ALL_DIFFICULTY_NAMES[maxi(dif - 1, 0)]
		row.add_child(_card(SpSettings.ALL_DIFFICULTY_NAMES[dif], info, PlayerProgress.medal(key), open, _start.bind(d, dif)))
	var back := _btn("‹ Desafíos", func() -> void: _refresh(), 220)
	_list.add_child(back)

func _start(d: Dictionary, difficulty: int) -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.CHALLENGE
	SetPieceGame.next_challenge = ChallengeCatalog.at_difficulty(d, difficulty)
	SetPieceGame.next_practice = practice
	get_tree().change_scene_to_file(SetPieceGame.SCENE)
