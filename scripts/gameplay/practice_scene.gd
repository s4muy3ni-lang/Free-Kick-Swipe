class_name PracticeScene
extends Node3D
## Sala de practica: un jugador (con las animaciones de campo Y de arquero) sobre la cancha, una galeria con TODOS los
## clips del pack agrupados por funcion y los malabares con la pelota. Sirve para ver cada animacion, comprobar el
## movimiento de raiz y el contacto con la pelota; no interviene en el partido.

signal back_requested

const BALL_SCENE := preload("res://scenes/ball/ball.tscn")
const ROLE_NAMES := {
	"marcha": "Marcha", "marcha_con_balon": "Marcha con balón", "direccional": "Desplazamientos", "gemelo_raiz": "Giros y arranques",
	"pase_tiro": "Pases y tiros", "volea": "Voleas", "cabezazo": "Cabezazos", "recepcion": "Recepciones", "habilidad": "Habilidad",
	"entrada": "Entradas", "contacto_caida": "Contactos y caídas", "suelo": "Suelo y levantarse", "cansancio": "Cansancio",
	"salto": "Saltos", "festejo": "Festejos", "felicitar": "Felicitar", "lamento": "Lamentos", "calentamiento": "Calentamiento",
	"arbitro": "Árbitro", "malabares": "Malabares", "practica": "Práctica", "arquero": "Arquero", "toque": "Toques de conducción",
	"mocap": "Mocap fútbol (modo 2)",
	# Modo 4 (Json): roles de las animaciones JSON.
	"idle": "Reposo", "idle_ball": "Reposo con balón", "walk": "Caminar", "jog": "Trotar", "run": "Correr", "sprint": "Sprint",
	"dribble_walk": "Conducción al paso", "dribble_jog": "Conducción al trote", "dribble_run": "Conducción a la carrera",
	"dribble_fast": "Conducción rápida", "dribble_sprint": "Conducción a sprint", "ball_turn": "Giros con balón",
	"ball_turn_stop": "Giros con balón y parada", "ball_skill": "Regates", "ball_sole": "Pisar la pelota", "ball_stop": "Frenar con balón",
	"ball_start": "Arrancar con balón", "ball_dribble": "Conducción (variantes)", "control_stand": "Control parado",
	"receive": "Recepciones", "receive_turn": "Recepción orientada", "kick_pass_soft": "Pase suave", "kick_pass": "Pase",
	"kick_shot": "Tiro", "kick_shot_hard": "Tiro fuerte", "kick_lob": "Vaselina", "kick_cross": "Centro", "kick_turn": "Golpeo girando",
	"kick_back": "Golpeo hacia atrás / taco", "kick_flick": "Toque sutil", "header": "Cabezazos", "volley": "Voleas",
	"turn_stand": "Giro parado", "turn_start": "Giro y arranque", "turn_run": "Giro en carrera", "turn_stop": "Giro y parada",
	"start": "Arranque", "stop": "Frenada", "step_stand": "Paso en el sitio", "run_change": "Cambio en carrera", "sidestep": "Paso lateral",
	"slide": "Barridas", "tackle_stand": "Entrada de pie", "fall": "Caídas", "getup": "Levantarse", "stumble": "Tropiezos",
	"avoid": "Esquivar", "celebrate": "Festejos", "celebrate_scorer": "Festejo del goleador", "celebrate_team": "Festejo en grupo",
	"clap": "Aplausos", "dejected": "Lamentos", "angry": "Enojo", "warmup": "Calentamiento", "gesture": "Gestos",
	"idle_fidget": "Espera (gestos)", "idle_ready": "Listo para el saque", "wall": "Barrera", "jostle": "Forcejeo",
	"nis_walk": "Escenas: caminar", "nis_idle": "Escenas: espera", "nis_sit": "Escenas: sentado", "nis_misc": "Escenas: varias",
	"manager": "Técnico", "mascot": "Mascota", "crowd": "Público", "referee": "Árbitro", "throw_in": "Saque de banda",
	"setpiece_pass": "Balón parado: pase", "setpiece_shot": "Balón parado: tiro", "setpiece_lob": "Balón parado: vaselina", "setpiece_miss": "Balón parado descartado (no llega a la pelota)",
	"gk_dive": "Arquero: estiradas", "gk_catch": "Arquero: atajadas", "gk_scoop": "Arquero: recoger", "gk_block": "Arquero: bloqueos",
	"gk_getup": "Arquero: levantarse", "gk_turn": "Arquero: giros", "gk_loco": "Arquero: desplazamientos", "gk_gesture": "Arquero: gestos",
	"gk_kick": "Arquero: saque con el pie", "gk_throw": "Arquero: saque con la mano", "gk_roll": "Arquero: saque rodando",
	"defeat_end": "Lamento final", "dir_back": "Marcha atrás", "dir_back_diag": "Marcha atrás en diagonal", "dir_back_walk": "Caminar hacia atrás",
	"dir_fwd_diag": "Marcha en diagonal", "dir_fwd_diag_walk": "Caminar en diagonal", "dir_side": "Marcha lateral", "fall_hit": "Caída por golpe",
	"gk_direct": "Arquero: dirige", "gk_idle": "Arquero: reposo", "gk_idle_ball": "Arquero: con la pelota", "gk_idle_var": "Arquero: espera",
	"gk_miss": "Arquero: no llega", "gk_place": "Arquero: deja la pelota", "gk_sidestep": "Arquero: paso lateral", "idle_ball_var": "Gesto sin fútbol",
	"jostle_ball": "Control protegiendo", "jump": "Salto", "lie": "Tendido", "loco_jog": "Trote (variante)", "loco_side": "Lateral (variante)",
	"loco_sprint": "Sprint (variante)", "loco_walk": "Caminar (variante)", "receive_chest": "Recepción de pecho (gesto)", "receive_foot": "Recepción con el pie",
	"shove": "Carga", "stumble_light": "Trastabillar leve", "throw_prep": "Giro para sacar de banda", "thumbs_up": "Pulgar arriba", "trip": "Zancadilla sufrida",
}

var ctx: MatchContext
var pitch: Pitch
var ball: Ball
var camera: Camera3D
var stage: Node3D
var visual: FootballerVisual
var motion := ActionMotion.new()
var juggler: JuggleController = null
var repeat: bool = false
var root_motion: bool = true
var mirror: bool = false
var speed: float = 1.0
var current_clip: StringName = &""
var plays: int = 0
var status_label: Label
var _groups: Dictionary = {}
var _cam_angle: int = 0
var _origin := Vector3(0.0, 0.0, 6.0)
var _restart_in: float = -1.0
var _list_root: VBoxContainer

func _ready() -> void:
	ctx = MatchContext.new()
	pitch = Pitch.new()
	pitch.name = "Pitch"
	add_child(pitch)
	pitch.build(Tuning.pitch)
	ball = BALL_SCENE.instantiate()
	ball.name = "Ball"
	add_child(ball)
	ball.position = Vector3(_origin.x + 2.0, 0.2, _origin.z)
	ctx.ball = ball
	ctx.pitch = pitch
	pitch.set_ball(ball)
	stage = Node3D.new()
	stage.name = "Stage"
	add_child(stage)
	stage.position = _origin
	visual = FootballerVisual.new()
	visual.name = "Visual"
	visual.keeper_mode = true
	stage.add_child(visual)
	visual.build(FootballerVisual.default_kit(0))
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 42.0
	add_child(camera)
	camera.current = true
	juggler = JuggleController.new(stage, visual, ball)
	_groups = grouped()
	_build_ui()
	GraphicsSettings.apply()
	_aim_camera(true)

## Ids de todos los clips (campo + arquero), sin las variantes espejo (se activan con el interruptor «Espejo»).
static func clip_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for lib in [PackLibrary.field(), PackLibrary.keeper()]:
		if lib == null:
			continue
		for n in lib.get_animation_list():
			if not String(n).ends_with("_mirror"):
				out.append(n)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
	return out

## {rol: [ids]} agrupado por el metadato `role` medido al convertir.
static func grouped() -> Dictionary:
	var g: Dictionary = {}
	for id in clip_ids():
		var role: String = String(PackLibrary.meta(id).get("role", "practica"))
		if not g.has(role):
			g[role] = []
		g[role].append(id)
	return g

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	layer.add_child(root)
	# Lista de clips (izquierda).
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	panel.size = Vector2(380, 704)
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "PRÁCTICA · %d animaciones" % clip_ids().size()
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list_root = VBoxContainer.new()
	_list_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_root.add_theme_constant_override("separation", 4)
	scroll.add_child(_list_root)
	var roles: Array = _groups.keys()
	roles.sort()
	for role in roles:
		var head := Label.new()
		head.text = "%s (%d)" % [ROLE_NAMES.get(role, role), _groups[role].size()]
		head.add_theme_font_size_override("font_size", 20)
		head.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		_list_root.add_child(head)
		for id in _groups[role]:
			var b := Button.new()
			b.text = String(id)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(0, 40)
			b.add_theme_font_size_override("font_size", 18)
			b.pressed.connect(play.bind(id))
			_list_root.add_child(b)
	# Controles (derecha arriba).
	var bar := HBoxContainer.new()
	bar.position = Vector2(400, 8)
	bar.size = Vector2(870, 52)
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	_add_toggle(bar, "Repetir", func(on: bool) -> void: repeat = on)
	_add_toggle(bar, "Raíz", func(on: bool) -> void: root_motion = on, true)
	_add_toggle(bar, "Espejo", func(on: bool) -> void: mirror = on)
	var slider := HSlider.new()
	slider.min_value = 0.25
	slider.max_value = 2.0
	slider.step = 0.05
	slider.value = 1.0
	slider.custom_minimum_size = Vector2(110, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v: float) -> void: speed = v)
	bar.add_child(slider)
	var cam := Button.new()
	cam.text = "Cámara"
	cam.pressed.connect(func() -> void: _cam_angle = (_cam_angle + 1) % 3; _aim_camera(true))
	bar.add_child(cam)
	var jug := Button.new()
	jug.text = "Malabares"
	jug.pressed.connect(toggle_juggle)
	# Sin clips de malabares (el banco JSON del modo 4 no tiene) el boton no se muestra.
	jug.visible = JuggleController.available()
	bar.add_child(jug)
	var back := Button.new()
	back.text = "Volver"
	back.position = Vector2(1130, 664)
	back.size = Vector2(142, 48)
	back.pressed.connect(func() -> void: back_requested.emit())
	root.add_child(back)
	status_label = Label.new()
	status_label.position = Vector2(400, 668)
	status_label.size = Vector2(720, 40)
	status_label.add_theme_font_size_override("font_size", 20)
	root.add_child(status_label)

func _add_toggle(parent: Container, text: String, cb: Callable, on: bool = false) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_size_override("font_size", 20)
	c.toggled.connect(cb)
	parent.add_child(c)

# --- Reproduccion -----------------------------------------------------------

## Reproduce un clip de la galeria desde la posicion inicial. Devuelve su duracion efectiva (0 si no existe).
func play(id: StringName) -> float:
	if juggler != null and juggler.running:
		juggler.stop()
	var clip: StringName = id
	if mirror and PackLibrary.has_clip(StringName(String(id) + "_mirror")):
		clip = StringName(String(id) + "_mirror")
	if not PackLibrary.has_clip(clip):
		return 0.0
	stage.position = _origin
	stage.rotation.y = 0.0
	motion.stop()
	var d: float = visual.play_pack_clip(clip, speed)
	if d <= 0.0:
		return 0.0
	motion.start(clip, speed)
	current_clip = clip
	plays += 1
	_restart_in = -1.0
	_update_status()
	return d

func toggle_juggle() -> void:
	if juggler.running:
		juggler.stop()
		current_clip = &""
	else:
		motion.stop()
		stage.position = _origin
		stage.rotation.y = 0.0
		ball.reset_at(Vector3(_origin.x, 0.11, _origin.z - 0.6))
		juggler.start()
		current_clip = &"malabares" if juggler.running else &""
	_update_status()

func _update_status() -> void:
	if status_label == null:
		return
	if juggler != null and juggler.running:
		status_label.text = "Malabares: %d toques" % juggler.count
	elif current_clip != &"":
		var m: Dictionary = PackLibrary.meta(current_clip)
		status_label.text = "%s · %.2f s · raíz %.1f m" % [current_clip, PackLibrary.clip(current_clip).length / speed, (m.get("root_total", Vector2.ZERO) as Vector2).length()]

func _physics_process(delta: float) -> void:
	if juggler != null and juggler.running:
		juggler.tick(delta)
		_update_status()
	elif motion.active:
		var rv: Vector2 = motion.step(delta)
		if not root_motion:
			rv = Vector2.ZERO
		var f: Vector3 = Locomotion.dir_from_yaw(stage.rotation.y)
		var r := Vector3(-f.z, 0.0, f.x)
		stage.position += (f * rv.x + r * rv.y) * delta
		if not motion.active and repeat and current_clip != &"":
			_restart_in = 0.35
	elif _restart_in >= 0.0:
		_restart_in -= delta
		if _restart_in < 0.0 and current_clip != &"":
			var id: StringName = StringName(String(current_clip).trim_suffix("_mirror"))
			play(id)
	visual.drive_motion(0.0, 0.0, delta)
	_aim_camera(false)

func _aim_camera(snap: bool) -> void:
	var focus: Vector3 = stage.global_position + Vector3(0.0, 1.0, 0.0)
	var offsets := [Vector3(0.0, 1.6, 5.2), Vector3(5.2, 1.6, 0.0), Vector3(-3.0, 4.5, 3.5)]
	var target: Vector3 = focus + offsets[_cam_angle]
	camera.global_position = target if snap else camera.global_position.lerp(target, 0.1)
	camera.look_at(focus, Vector3.UP)
