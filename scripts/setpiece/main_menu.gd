class_name MainMenu
extends Node3D
## Menu principal (horizontal): el estadio de fondo con la camara girando despacio alrededor del arco, el titulo y las
## juegos principales PENALES y TIRO LIBRE y tres secciones: ACADEMIA (practica y entrenamiento), DESAFIOS (progresion) y
## MINIJUEGOS ARCADE. Abajo, el pie habil, la dificultad, el
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
var _tv_button: Button
var _shake_button: Button
var _keeper: SpActor
var _player: SpActor
var screens: MenuScreens
var _profile_label: Label
var _xp_bar: ProgressBar
var _coins_label: Label
var _season_label: Label
var _server_label: Label
## Personalizar: la camara se acerca al jugador y arrastrar lo gira.
var _customizing: bool = false
var _spin: float = 0.0
## Personalizar (pedido del usuario: dominadas continuas, girar y acercar la vista): las dominadas (JuggleShow) y la
## camara que orbita al jugador. _view_yaw: angulo alrededor del jugador (0 = de frente); _view_dist: distancia;
## _view_h: altura que se mira (cara, cuerpo, botines).
var juggle: JuggleShow = null
var _view_yaw: float = 0.35
var _view_dist: float = 3.4
var _view_h: float = 1.0
const VIEWS := {"frente": [0.0, 3.0, 1.0], "perfil": [1.5708, 3.0, 1.0], "espalda": [3.1416, 3.0, 1.0],
	"botines": [0.6, 1.25, 0.22], "cara": [0.15, 1.05, 1.62], "completo": [0.35, 3.6, 1.0]}
var _pinch: Dictionary = {}
## Fondo cinematografico: un tiro libre en camara lenta que se repite (solo visual: la pelota del fondo no tiene fisica).
var _cine_t: float = 0.0
var _cine_ball: MeshInstance3D
var _cine_from := Vector3.ZERO
var _cine_to := Vector3.ZERO

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
	PlayerCustom.dress(_player)
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
	# Vuelta de un minijuego online: lo que eligio el usuario al terminar (repetir, otro nivel, otro minijuego, aleatorio).
	if OnlineDuel.after != "":
		screens.resume_online_after.call_deferred()
	GraphicsSettings.apply()
	# Ambiente de estadio de fondo, en calma (el juego lo sube y lo baja segun la jugada).
	Sfx.set_crowd_level(0.0)
	Sfx.crowd(true)

func _exit_tree() -> void:
	Sfx.crowd(false)

func _process(delta: float) -> void:
	_t += delta
	var gx: float = stadium.half_length()
	if _customizing:
		# Personalizar: el jugador hace dominadas mirando a la camara de frente; la camara orbita alrededor (arrastrar
		# gira, pellizcar o la rueda acercan) y queda corrida para que el jugador se vea a la izquierda del panel.
		_cine_ball.visible = false
		var fwd: Vector3 = _player.facing()
		var target: Vector3 = _player.global_position + Vector3(0, _view_h, 0)
		var dir: Vector3 = fwd.rotated(Vector3.UP, _view_yaw)
		var right: Vector3 = Vector3.UP.cross(dir).normalized()
		var want: Vector3 = target + dir * _view_dist + Vector3.UP * (0.12 * _view_dist)
		cam.global_position = want if cam.global_position.distance_to(want) > 8.0 else cam.global_position.lerp(want, minf(delta * 5.0, 1.0))
		cam.look_at(target + right * (0.42 * _view_dist), Vector3.UP)
		return
	_cinematic(delta, gx)

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
	# Barra de perfil: nombre, nivel con barra de XP, monedas, puntos de temporada y estado del servidor.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vb.add_child(top)
	top.add_child(MenuIcon.new("perfil", Color(1.0, 0.84, 0.28), 56))
	var pv := VBoxContainer.new()
	_profile_label = Label.new()
	_profile_label.add_theme_font_size_override("font_size", 24)
	pv.add_child(_profile_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(260, 14)
	_xp_bar.show_percentage = false
	pv.add_child(_xp_bar)
	top.add_child(pv)
	var tsp := Control.new()
	tsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tsp)
	var title := Label.new()
	title.text = "FREE KICK SWIPE"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	title.add_theme_constant_override("outline_size", 12)
	top.add_child(title)
	var tsp2 := Control.new()
	tsp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tsp2)
	top.add_child(MenuIcon.new("coin", Color.WHITE, 44))
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 28)
	top.add_child(_coins_label)
	top.add_child(MenuIcon.new("temporada", Color.WHITE, 40))
	_season_label = Label.new()
	_season_label.add_theme_font_size_override("font_size", 22)
	top.add_child(_season_label)
	_server_label = Label.new()
	_server_label.add_theme_font_size_override("font_size", 16)
	_server_label.add_theme_color_override("font_color", Color(0.75, 0.82, 1.0))
	vb.add_child(_server_label)
	# Las diez entradas del menu (pedido del usuario), cada una con su icono.
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vb.add_child(grid)
	screens = MenuScreens.new()
	var tiles := [
		["JUGAR ONLINE", "Rivales reales o IA", "online", Color(0.85, 0.2, 0.25), func() -> void: screens.open_online()],
		["JUGAR OFFLINE", "Penales y tiro libre", "offline", Color(0.08, 0.30, 0.75), func() -> void: screens.open_offline()],
		["ACADEMIA", "Práctica y entrenamiento", "academia", Color(0.10, 0.50, 0.22), func() -> void: _open_challenges("academia")],
		["DESAFÍOS", "Diarios, semanales, logros", "desafios", Color(0.48, 0.18, 0.62), func() -> void: _open_challenges("desafios")],
		["MINIJUEGOS ARCADE", "Categorías y niveles", "arcade", Color(0.85, 0.45, 0.05), func() -> void: _open_challenges("arcade")],
		["PERSONALIZAR", "Uniforme, botines, balón", "personalizar", Color(0.15, 0.55, 0.65), func() -> void: screens.open_customize()],
		["TIENDA", "Cosméticos y consumibles", "tienda", Color(0.70, 0.55, 0.10), func() -> void: screens.open_shop()],
		["TEMPORADA", "Pase y recompensas", "temporada", Color(0.40, 0.18, 0.70), func() -> void: screens.open_season()],
		["EVENTOS", "Copas y festivales", "eventos", Color(0.20, 0.42, 0.80), func() -> void: screens.open_events()],
		["MI JUGADOR", "Progresión, atributos, perfil", "perfil", Color(0.30, 0.32, 0.40), func() -> void: screens.open_progression()]]
	for t in tiles:
		grid.add_child(_tile(t[0], t[1], t[2], t[3], t[4]))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	# Fila de ajustes: se acomoda en dos renglones si no entra (telefonos angostos).
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 10)
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
	var bench: Button = _small("Banco de animaciones", func() -> void: get_tree().change_scene_to_file(BENCH_SCENE))
	# Herramienta de desarrollo: no aparece en la build publica (DevFlags).
	bench.visible = DevFlags.tools_enabled()
	row.add_child(bench)
	_build_visual_panel(root)
	_build_player_panel(root)
	root.add_child(screens)
	screens.play_offline.connect(_start)
	screens.customize_changed.connect(_apply_custom)
	screens.customize_mode.connect(func(on: bool) -> void:
		_customizing = on
		# Personalizar: se oculta el menu y el jugador posa quieto en un lugar fijo, de frente a la camara.
		margin.visible = not on
		if on:
			_spin = 0.0
			var gx2: float = stadium.half_length()
			_player.global_position = Vector3(gx2 - 14.0, 0, 0)
			_player.set_facing(Vector3(-1, 0, 0))
			var idl: Array[StringName] = SpClips.by_role(&"idle_ready", false)
			if not idl.is_empty():
				_player.play_loop(idl[0], 0.2)
			_cine_t = 0.0
			set_view("completo")
			start_juggling()
		else:
			stop_juggling())
	screens.customize_view.connect(set_view)
	screens.customize_zoom.connect(func(f: float) -> void: _view_dist = clampf(_view_dist * f, 0.8, 5.5))
	Online.state_changed.connect(_refresh_profile)
	_refresh_profile()
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
	PlayerCustom.dress(_player)
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
	# Camara de transmision de TV en los tiros libres (reemplaza a la opcion de la linea de destino, que se quito: solo
	# queda el rastro del dedo).
	_tv_button = _small("", func() -> void:
		GraphicsSettings.toggle_tv_camera()
		_refresh())
	_tv_button.custom_minimum_size = Vector2(520, 60)
	vb.add_child(_tv_button)
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
	b.custom_minimum_size = Vector2(240, 230)
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
	_tv_button.text = "Cámara de TV en tiros libres: %s" % ("Sí" if GraphicsSettings.tv_camera else "No")
	_shake_button.text = "Temblor de cámara: %s" % GraphicsSettings.SHAKE_NAMES[GraphicsSettings.camera_shake]

var _loading: Label = null

func _open_challenges(t: String) -> void:
	ChallengeMenu.section = t
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

func _tile(t: String, sub: String, icon: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(226, 150)
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		var c: Color = color.lightened(0.12) if st == "hover" else (color.darkened(0.2) if st == "pressed" else color)
		sb.bg_color = Color(c.r, c.g, c.b, 0.88)
		sb.border_color = Color(1.0, 0.84, 0.28, 0.95) if st != "normal" else Color(1, 1, 1, 0.3)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(20)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 10
		b.add_theme_stylebox_override(st, sb)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_top = 10
	v.offset_right = -10
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(MenuIcon.new(icon, Color.WHITE, 56))
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	var s2 := Label.new()
	s2.text = sub
	s2.add_theme_font_size_override("font_size", 15)
	s2.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(s2)
	b.add_child(v)
	# El texto del boton (oculto por el contenido) identifica la entrada.
	b.text = t
	b.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	b.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	b.pressed.connect(cb)
	return b

func _refresh_profile() -> void:
	if _profile_label == null:
		return
	var p: Dictionary = Online.profile()
	var xp: int = int(p.get("xp", 0))
	var lv: int = PlayerProgress.level_for(xp)
	var acc: int = 0
	var need: int = 150
	for i in lv - 1:
		acc += need
		need += 150
	_profile_label.text = "%s · Nivel %d" % [p.get("display_name", "Jugador"), lv]
	_xp_bar.max_value = need
	_xp_bar.value = xp - acc
	_coins_label.text = "%d" % Online.coins()
	var st: Variant = Online.state.get("season")
	_season_label.text = "%d" % int((st as Dictionary).get("points", 0)) if st is Dictionary else "-"
	_server_label.text = Online.backend_label()
	var ap: Variant = p.get("appearance")
	if ap is Dictionary and not (ap as Dictionary).is_empty():
		PlayerCustom.apply_appearance(ap, BackendConfig.seed().get("catalog_items", []))
		_apply_custom()

## Dominadas en la personalizacion (no se reinician al cambiar la ropa: solo cambian los materiales).
func start_juggling() -> void:
	if juggle != null:
		return
	juggle = JuggleShow.new()
	juggle.name = "JuggleShow"
	add_child(juggle)
	PlayerCustom.load_custom()
	juggle.setup(_player, BallSkins.design_of(PlayerCustom.ball_item))

func stop_juggling() -> void:
	if juggle != null:
		juggle.stop()
		juggle.queue_free()
		juggle = null

## Vista de la personalizacion: frente, perfil, espalda, botines, cara o completo.
func set_view(v: String) -> void:
	var d: Array = VIEWS.get(v, VIEWS["completo"])
	_view_yaw = float(d[0])
	_view_dist = float(d[1])
	_view_h = float(d[2])

func _apply_custom() -> void:
	if _player != null:
		_player.set_kit(PlayerCustom.kit())
		if juggle != null and is_instance_valid(juggle.ball):
			juggle.ball.set_skin(BallSkins.design_of(PlayerCustom.ball_item))
		PlayerCustom.dress(_player)

func _unhandled_input(e: InputEvent) -> void:
	if not _customizing:
		return
	# Dos dedos: pellizcar acerca o aleja. Un dedo (o el mouse): girar alrededor del jugador. La rueda: zoom.
	if e is InputEventScreenTouch:
		if (e as InputEventScreenTouch).pressed:
			_pinch[(e as InputEventScreenTouch).index] = (e as InputEventScreenTouch).position
		else:
			_pinch.erase((e as InputEventScreenTouch).index)
	elif e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		if _pinch.size() >= 2:
			var pts: Array = _pinch.values()
			var before: float = (pts[0] as Vector2).distance_to(pts[1])
			_pinch[sd.index] = sd.position
			pts = _pinch.values()
			var after: float = (pts[0] as Vector2).distance_to(pts[1])
			if before > 1.0:
				_view_dist = clampf(_view_dist * before / maxf(after, 1.0), 0.8, 5.5)
		else:
			_pinch[sd.index] = sd.position
			_view_yaw -= sd.relative.x * 0.01
	elif e is InputEventMouseMotion and (e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		_view_yaw -= (e as InputEventMouseMotion).relative.x * 0.01
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_view_dist = clampf(_view_dist / 1.1, 0.8, 5.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_view_dist = clampf(_view_dist * 1.1, 0.8, 5.5)

## Fondo: tiro libre en camara lenta. El tirador hace su golpeo a 0,35 de velocidad, la pelota del fondo (solo visual,
## sin fisica) viaja en curva al angulo y la camara la acompaña; despues vuelve a empezar.
const CINE_LEN := 9.0
func _cinematic(delta: float, gx: float) -> void:
	if _cine_ball == null:
		_cine_ball = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.22
		_cine_ball.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.97, 0.97, 0.97)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.85, 0.5)
		m.emission_energy_multiplier = 0.4
		_cine_ball.material_override = m
		add_child(_cine_ball)
		ball.visible = false
		_cine_from = Vector3(gx - 20.0, 0.11, -6.0)
		_cine_to = Vector3(gx + 0.3, 2.1, 2.9)
		var sparks := CPUParticles3D.new()
		sparks.amount = 40
		sparks.lifetime = 4.0
		sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		sparks.emission_box_extents = Vector3(14, 5, 10)
		sparks.gravity = Vector3(0, 0.15, 0)
		sparks.initial_velocity_min = 0.0
		sparks.initial_velocity_max = 0.2
		sparks.scale_amount_min = 0.03
		sparks.scale_amount_max = 0.06
		var qm := QuadMesh.new()
		qm.size = Vector2(1, 1)
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		pm.billboard_keep_scale = true
		pm.albedo_color = Color(1.0, 0.9, 0.6, 0.7)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.material = pm
		sparks.mesh = qm
		sparks.position = Vector3(gx - 10.0, 4.0, 0.0)
		add_child(sparks)
	_cine_ball.visible = true
	_cine_t = fmod(_cine_t + delta, CINE_LEN)
	var kick_at: float = 2.2
	if _cine_t < delta * 1.5:
		_player.global_position = _cine_from + Vector3(-1.4, -0.11, -0.6)
		_player.set_facing((_cine_to - _cine_from).normalized())
		var kicks: Array[StringName] = SpClips.by_role(&"kick_shot", false)
		if not kicks.is_empty():
			_player.play_clip(kicks[0], _player.global_position, Vector3(_cine_to.x - _cine_from.x, 0, _cine_to.z - _cine_from.z).normalized(), 0.2, 0.35, 0.0)
	var u: float = clampf((_cine_t - kick_at) / 3.6, 0.0, 1.0)
	var mid: Vector3 = (_cine_from + _cine_to) * 0.5 + Vector3(0, 2.4, -3.0)
	var p: Vector3 = _cine_from.lerp(mid, u).lerp(mid.lerp(_cine_to, u), u)
	_cine_ball.global_position = p
	var focus: Vector3 = p if u > 0.0 else _player.global_position + Vector3(0, 1.0, 0)
	var side := Vector3(-3.5, 1.6, -4.2).rotated(Vector3.UP, sin(_t * 0.1) * 0.3)
	cam.global_position = cam.global_position.lerp(focus + side, minf(delta * 1.5, 1.0))
	cam.look_at(focus.lerp(Vector3(gx, 1.2, 0), 0.35), Vector3.UP)
