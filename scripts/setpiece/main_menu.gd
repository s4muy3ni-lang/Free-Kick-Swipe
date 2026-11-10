class_name MainMenu
extends Node3D
## Menu principal (horizontal): el estadio de fondo con la camara girando despacio alrededor del arco, el titulo y las
## modalidades: PENALES, TIRO LIBRE, ACADEMIA, DESAFIOS y ARCADE (minijuegos). Abajo, el pie habil, la dificultad, el
## arco, los graficos y los ajustes visuales (se guardan) y el acceso al banco de pruebas de animaciones (desarrollo).

const SCENE := "res://scenes/setpiece/main_menu.tscn"
const BENCH_SCENE := "res://scenes/dev/anim_bank_bench.tscn"

var stadium: Stadium11
var cam: Camera3D
var ball: Ball
var _t: float = 0.0
var _foot_button: Button
var _diff_button: Button
var _goal_button: Button
var _gfx_button: Button
var _visual_panel: PanelContainer
var _player_panel: PanelContainer
var _custom_buttons: Dictionary = {}
var _aim_line_button: Button
var _shake_button: Button
var _keeper: SpActor
var _player: SpActor

func _ready() -> void:
	SpSettings.load_settings()
	PlayerCustom.load_custom()
	stadium = Stadium11.new()
	add_child(stadium)
	stadium.build(PitchConfig.football11(SpSettings.goal_style))
	ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	add_child(ball)
	stadium.set_ball(ball)
	var gx: float = stadium.half_length()
	ball.reset_at(Vector3(gx - 11.0, ball.radius, 0.0))
	# Un arquero esperando y un tirador acomodando la pelota: el estadio con vida.
	_keeper = SpActor.new()
	add_child(_keeper)
	_keeper.build(SpSettings.CPU_KEEPER_KIT)
	_keeper.global_position = Vector3(gx - 0.2, 0, 0)
	_keeper.set_facing(Vector3(-1, 0, 0))
	var gk: Array[StringName] = SpClips.by_role(&"gk_idle", false)
	if not gk.is_empty():
		_keeper.play_loop(gk[0])
	_player = SpActor.new()
	add_child(_player)
	_player.build(PlayerCustom.kit())
	_player.set_back_number(PlayerCustom.number)
	_player.global_position = Vector3(gx - 14.0, 0, -1.6)
	_player.set_facing(Vector3(1, 0, 0.45))
	var idles: Array[StringName] = SpClips.by_role(&"idle_ready", false)
	if not idles.is_empty():
		_player.play_loop(idles[0])
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 48.0
	add_child(cam)
	cam.current = true
	_build_ui()
	GraphicsSettings.apply()
	Sfx.crowd(true)

func _exit_tree() -> void:
	Sfx.crowd(false)

func _process(delta: float) -> void:
	_t += delta
	var gx: float = stadium.half_length()
	var center := Vector3(gx - 8.0, 0.0, 0.0)
	var ang: float = 2.6 + sin(_t * 0.12) * 0.55
	cam.global_position = center + Vector3(cos(ang) * 15.0, 4.2 + sin(_t * 0.2) * 0.6, sin(ang) * 15.0)
	cam.look_at(Vector3(gx - 3.0, 1.0, 0.0), Vector3.UP)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.make()
	layer.add_child(root)
	# Velo oscuro con degradado a la izquierda (legibilidad del titulo sin tapar el estadio).
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.02, 0.06, 0.88))
	grad.set_color(1, Color(0.0, 0.02, 0.06, 0.15))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	root.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)
	var title := Label.new()
	title.text = "FREE KICK SWIPE"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	title.add_theme_constant_override("outline_size", 14)
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "Penales y tiros libres · deslizá el dedo para patear"
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vb.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	vb.add_child(gap)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	vb.add_child(cards)
	cards.add_child(_card("PENALES", "Tanda contra\nla CPU: tirás\ny atajás.",
		Color(0.08, 0.30, 0.75), func() -> void: _start(SetPieceGame.Mode.PENALTY)))
	cards.add_child(_card("TIRO LIBRE", "Elegí dónde\npatear: barrera\ny arquero.",
		Color(0.75, 0.16, 0.12), func() -> void: _start(SetPieceGame.Mode.FREE_KICK)))
	cards.add_child(_card("ACADEMIA", "8 niveles:\nprecisión,\npotencia, efecto.",
		Color(0.10, 0.50, 0.22), func() -> void: _open_challenges("academia")))
	cards.add_child(_card("DESAFÍOS", "Postes, aros,\nconos, torres\ny distancia.",
		Color(0.48, 0.18, 0.62), func() -> void: _open_challenges("arena")))
	cards.add_child(_card("ARCADE", "Minijuegos:\nbotón de caída\ny más.",
		Color(0.85, 0.45, 0.05), func() -> void: _open_challenges("arcade")))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	_foot_button = _small("", func() -> void:
		SpSettings.foot = -SpSettings.foot
		SpSettings.save_settings()
		_refresh())
	row.add_child(_foot_button)
	_diff_button = _small("", func() -> void:
		SpSettings.difficulty = (SpSettings.difficulty + 1) % 3
		SpSettings.save_settings()
		_refresh())
	row.add_child(_diff_button)
	_goal_button = _small("", func() -> void:
		SpSettings.goal_style = (SpSettings.goal_style + 1) % 2
		SpSettings.save_settings()
		stadium.build(PitchConfig.football11(SpSettings.goal_style))
		stadium.set_ball(ball)
		_refresh())
	row.add_child(_goal_button)
	_gfx_button = _small("", func() -> void:
		GraphicsSettings.cycle_menu_choice()
		_refresh())
	row.add_child(_gfx_button)
	var vis: Button = _small("Visual", func() -> void: _visual_panel.visible = not _visual_panel.visible)
	vis.custom_minimum_size = Vector2(130, 60)
	row.add_child(vis)
	var pl: Button = _small("Jugador", func() -> void:
		_player_panel.visible = not _player_panel.visible
		if _player_panel.visible:
			_refresh_custom())
	pl.custom_minimum_size = Vector2(150, 60)
	row.add_child(pl)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp2)
	row.add_child(_small("Banco de animaciones", func() -> void: get_tree().change_scene_to_file(BENCH_SCENE)))
	_build_visual_panel(root)
	_build_player_panel(root)
	_refresh()

## Personalizacion del jugador: cada opcion es un boton que pasa a la siguiente; el jugador del menu la muestra en vivo.
func _build_player_panel(root: Control) -> void:
	_player_panel = PanelContainer.new()
	_player_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_player_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_player_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.94)
	sb.border_color = Color(1.0, 0.84, 0.28, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(18)
	_player_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_player_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_player_panel.add_child(vb)
	var t := Label.new()
	t.text = "Tu jugador"
	t.add_theme_font_size_override("font_size", 26)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for k in ["jersey", "shorts", "socks", "boots", "skin", "hair", "number", "style", "run_style", "follow_style", "celebration"]:
		var b: Button = _small("", _cycle_custom.bind(k, 1))
		b.custom_minimum_size = Vector2(255, 50)
		b.add_theme_font_size_override("font_size", 17)
		grid.add_child(b)
		_custom_buttons[k] = b
	var done: Button = _small("Listo", func() -> void: _player_panel.visible = false)
	done.custom_minimum_size = Vector2(200, 50)
	vb.add_child(done)
	_player_panel.visible = false

func _cycle_custom(k: String, dir: int) -> void:
	var sizes := {"jersey": PlayerCustom.JERSEYS.size(), "shorts": PlayerCustom.SHORTS.size(), "socks": PlayerCustom.SOCKS.size(),
		"boots": PlayerCustom.BOOTS.size(), "skin": PlayerCustom.SKINS.size(), "hair": PlayerCustom.HAIRS.size(),
		"style": PlayerCustom.STYLE_NAMES.size(), "run_style": PlayerCustom.RUN_NAMES.size(),
		"follow_style": PlayerCustom.FOLLOW_NAMES.size(), "celebration": PlayerCustom.CELEB_LOCKS.size() + 1}
	match k:
		"number":
			PlayerCustom.number = PlayerCustom.number % 99 + 1
		"jersey":
			PlayerCustom.jersey = (PlayerCustom.jersey + dir) % sizes[k]
		"shorts":
			PlayerCustom.shorts = (PlayerCustom.shorts + dir) % sizes[k]
		"socks":
			PlayerCustom.socks = (PlayerCustom.socks + dir) % sizes[k]
		"boots":
			PlayerCustom.boots = (PlayerCustom.boots + dir) % sizes[k]
		"skin":
			PlayerCustom.skin = (PlayerCustom.skin + dir) % sizes[k]
		"hair":
			PlayerCustom.hair = (PlayerCustom.hair + dir) % sizes[k]
		"style":
			PlayerCustom.style = (PlayerCustom.style + dir) % sizes[k]
		"run_style":
			PlayerCustom.run_style = (PlayerCustom.run_style + dir) % sizes[k]
		"follow_style":
			PlayerCustom.follow_style = (PlayerCustom.follow_style + dir) % sizes[k]
		"celebration":
			PlayerCustom.celebration = (PlayerCustom.celebration + dir) % sizes[k]
			var clip: StringName = PlayerCustom.celebration_clip()
			if clip != &"":
				_player.play_here(clip, 0.2)
	PlayerCustom.save_custom()
	_player.set_kit(PlayerCustom.kit())
	_player.set_back_number(PlayerCustom.number)
	_refresh_custom()

func _refresh_custom() -> void:
	var locked_boot: bool = not PlayerCustom.unlocked(PlayerCustom.BOOT_LOCKS[PlayerCustom.boots])
	var cel: int = PlayerCustom.celebration
	var locked_cel: bool = cel > 0 and not PlayerCustom.unlocked(PlayerCustom.CELEB_LOCKS[cel - 1])
	var texts := {"jersey": "Camiseta: %s" % PlayerCustom.JERSEY_NAMES[PlayerCustom.jersey],
		"shorts": "Short: %s" % PlayerCustom.SHORT_NAMES[PlayerCustom.shorts],
		"socks": "Medias: %s" % PlayerCustom.SOCK_NAMES[PlayerCustom.socks],
		"boots": "Botines: %s%s" % [PlayerCustom.BOOT_NAMES[PlayerCustom.boots], " 🔒 (logro)" if locked_boot else ""],
		"skin": "Piel: %s" % PlayerCustom.SKIN_NAMES[PlayerCustom.skin],
		"hair": "Pelo: %s" % PlayerCustom.HAIR_NAMES[PlayerCustom.hair],
		"number": "Número: %d" % PlayerCustom.number,
		"style": "Golpeo: %s" % PlayerCustom.STYLE_NAMES[PlayerCustom.style],
		"run_style": "Carrera: %s" % PlayerCustom.RUN_NAMES[PlayerCustom.run_style],
		"follow_style": "Tras el tiro: %s" % PlayerCustom.FOLLOW_NAMES[PlayerCustom.follow_style],
		"celebration": "Festejo: %s%s" % [PlayerCustom.celebration_name(cel), " 🔒 (logro)" if locked_cel else ""]}
	for k in _custom_buttons:
		(_custom_buttons[k] as Button).text = texts[k]

## Ajustes visuales: linea de destino de la pelota y temblor de camara (se guardan con los graficos).
func _build_visual_panel(root: Control) -> void:
	_visual_panel = PanelContainer.new()
	_visual_panel.set_anchors_preset(Control.PRESET_CENTER)
	_visual_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_visual_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.94)
	sb.border_color = Color(1.0, 0.84, 0.28, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(24)
	_visual_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_visual_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_visual_panel.add_child(vb)
	var t := Label.new()
	t.text = "Ajustes visuales"
	t.add_theme_font_size_override("font_size", 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	_aim_line_button = _small("", func() -> void:
		GraphicsSettings.toggle_aim_line()
		_refresh())
	_aim_line_button.custom_minimum_size = Vector2(520, 60)
	vb.add_child(_aim_line_button)
	_shake_button = _small("", func() -> void:
		GraphicsSettings.cycle_camera_shake()
		_refresh())
	_shake_button.custom_minimum_size = Vector2(520, 60)
	vb.add_child(_shake_button)
	var note := Label.new()
	note.text = "La línea de destino solo es una ayuda: apagarla no cambia el tiro.\nEl rastro del dedo se sigue viendo."
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	vb.add_child(note)
	vb.add_child(_small("Listo", func() -> void: _visual_panel.visible = false))
	_visual_panel.visible = false

func _card(t: String, desc: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(205, 230)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s\n\n%s" % [t, desc]
	b.add_theme_font_size_override("font_size", 20)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		var c: Color = color
		if st == "hover":
			c = color.lightened(0.15)
		elif st == "pressed":
			c = color.darkened(0.2)
		sb.bg_color = Color(c.r, c.g, c.b, 0.9)
		sb.border_color = Color(1.0, 0.84, 0.28, 0.95) if st != "normal" else Color(1, 1, 1, 0.35)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(22)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 12
		sb.content_margin_left = 20
		sb.content_margin_right = 16
		sb.content_margin_top = 22
		sb.content_margin_bottom = 22
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	return b

func _small(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(200, 60)
	b.add_theme_font_size_override("font_size", 21)
	b.pressed.connect(cb)
	return b

func _refresh() -> void:
	_foot_button.text = "Pie: %s" % SpSettings.foot_name()
	_diff_button.text = "Dificultad: %s" % SpSettings.DIFFICULTY_NAMES[SpSettings.difficulty]
	_goal_button.text = "Arco: %s" % SpSettings.GOAL_STYLE_NAMES[SpSettings.goal_style]
	_gfx_button.text = "Gráficos: %s" % GraphicsSettings.menu_choice_name()
	_aim_line_button.text = "Mostrar línea de destino de la pelota: %s" % ("Sí" if GraphicsSettings.show_aim_line else "No")
	_shake_button.text = "Temblor de cámara: %s" % GraphicsSettings.SHAKE_NAMES[GraphicsSettings.camera_shake]

var _loading: Label = null

func _open_challenges(t: String) -> void:
	ChallengeMenu.tab = t
	get_tree().change_scene_to_file(ChallengeMenu.SCENE)

func _start(m: int) -> void:
	if _loading != null:
		return
	SetPieceGame.next_mode = m
	# Aviso inmediato y cambio de escena en el cuadro siguiente (el toque se ve atendido aunque la carga demore).
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0.02, 0.06, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	_loading = Label.new()
	_loading.text = "Cargando…"
	_loading.add_theme_font_size_override("font_size", 48)
	_loading.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	_loading.set_anchors_preset(Control.PRESET_CENTER)
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.offset_left = -300
	_loading.offset_right = 300
	layer.add_child(_loading)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(SetPieceGame.SCENE)
