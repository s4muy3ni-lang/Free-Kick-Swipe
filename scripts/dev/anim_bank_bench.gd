class_name AnimBankBench
extends Node3D
## Banco de pruebas de las animaciones del banco JSON original (el unico del juego desde 2026-11-08: Mixamo y Mocap se
## borraron por pedido del usuario, docs/reforma/MIXAMO_MOCAP_QUITADOS.md). Muestra cada clip por categoria de tirador,
## barrera y arquero sobre el cuerpo del juego (modelo de Tripo), con la pelota, el golpe en el contacto del clip y mediciones en vivo.
##
## - Golpeos: el jugador se coloca para que el contacto medido del clip caiga sobre la pelota y la pelota recibe un golpe
##   de referencia en el instante de contacto del clip; se mide la distancia real punta del pie - pelota en ese instante.
## - Atajadas: un marcador muestra donde quedan las manos en el extremo de la atajada (medido sobre el cuerpo mostrado).
## - Barrera y saltos: se mide la subida de la cadera. En todos: altura minima de los pies (hundidos o flotando).
## - Vista de diagnostico «cuerpo original»: cada banco sobre el cuerpo para el que se convirtio (Mixamo y Mocap: el
##   futbolista). Sirve para ver la deformacion documentada en docs/reforma/FASE1_INFORME.md; la comparacion es la del
##   cuerpo comun.

signal back_requested

const BALL_SCENE := preload("res://scenes/ball/ball.tscn")
const SHOOTER_KIT := {"jersey": Color(0.78, 0.05, 0.06), "shorts": Color(0.05, 0.12, 0.62), "socks": Color(0.92, 0.92, 0.92),
	"boots": Color(0.03, 0.03, 0.035), "skin": Color(0.62, 0.40, 0.29), "hair": Color(0.12, 0.07, 0.04)}
const KEEPER_KIT := {"jersey": Color(0.10, 0.55, 0.20), "shorts": Color(0.05, 0.05, 0.08), "socks": Color(0.10, 0.55, 0.20),
	"boots": Color(0.9, 0.9, 0.9), "skin": Color(0.62, 0.40, 0.29), "hair": Color(0.12, 0.07, 0.04)}
const WALL_KIT := {"jersey": Color(0.95, 0.80, 0.05), "shorts": Color(0.05, 0.05, 0.08), "socks": Color(0.95, 0.80, 0.05),
	"boots": Color(0.9, 0.9, 0.9), "skin": Color(0.62, 0.40, 0.29), "hair": Color(0.12, 0.07, 0.04)}
const BLEND := 0.2
const SPEEDS: Array[float] = [0.25, 0.5, 1.0]
enum View { BEHIND, SIDE, FRONT }
## Camaras fijas, iguales para los tres bancos: desde el lado del tirador (mirando al arco), lateral y opuesta (desde el arco).
const VIEW_NAMES := ["Desde el tirador", "Lateral", "Opuesta"]

## Banco ("json": el unico).
var bank: String = "json"
## false: cuerpo comun (el del juego, modelo de Tripo). true: cuerpo original del banco (diagnostico).
var original_body: bool = false
var category: String = "st_setpiece"
var clip_index: int = 0
var speed: float = 1.0
var repeat: bool = true
## Encadena reposo -> clip -> reposo del MISMO banco con mezcla (transiciones); sin reposo en el banco, sin transicion.
var sequence: bool = false
var view: int = View.BEHIND
var zoom: float = 1.0

var ctx: MatchContext
var pitch: Pitch
var ball: Ball
var camera: Camera3D
## Posicion y rumbo del jugador (sigue la raiz del clip); dentro, el modelo a escala de juego.
var body: Node3D
var model: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var body_path: String = ""
var marker: MeshInstance3D

## Ultima medicion en vivo del clip en curso (lo que se muestra y lo que leen las pruebas).
var metrics: Dictionary = {}
var current: Dictionary = {}
var _anim: Animation = null
var _meta: Dictionary = {}
var _anim_name: StringName = &""
var _origin := Vector3.ZERO
var _facing := Vector3(1, 0, 0)
var _ball_spot := Vector3.ZERO
var _kicked: bool = false
var _playing: bool = false
var _seq_stage: int = 0
var _idle_name: StringName = &""
var _restart_in: float = -1.0
var _lib_names: Dictionary = {}
## Cuadros a esperar tras arrancar el clip antes de medir: el reproductor aplica la pose despues de este nodo, y el primer
## cuadro todavia muestra la pose anterior (reposo), que falsearia el minimo de los pies.
var _skip_measure: int = 0

var _ui: CanvasLayer
var _bank_buttons: Dictionary = {}
var _cat_box: VBoxContainer
var _cat_buttons: Dictionary = {}
var _info: Label
var _empty: Label
var _play_button: Button
var _repeat_button: Button
var _seq_button: Button
var _speed_buttons: Array = []
var _view_buttons: Array = []

func _ready() -> void:
	ctx = MatchContext.new()
	pitch = Pitch.new()
	pitch.name = "Pitch"
	add_child(pitch)
	pitch.build(Tuning.pitch)
	ball = BALL_SCENE.instantiate()
	ball.name = "Ball"
	add_child(ball)
	ctx.ball = ball
	ctx.pitch = pitch
	pitch.set_ball(ball)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	marker = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	marker.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.2, 0.9, 1.0, 0.6)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mm
	marker.visible = false
	add_child(marker)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.current = true
	_build_ui()
	GraphicsSettings.apply()
	select_bank(bank)

# --- Seleccion ---------------------------------------------------------------------------------------------------------

## Cambia de banco: descarga el anterior y carga SOLO las bibliotecas del elegido.
func select_bank(b: String) -> void:
	bank = b
	clip_index = 0
	_build_body()
	_refresh_ui()
	play_current()

func set_original_body(on: bool) -> void:
	original_body = on
	_build_body()
	_refresh_ui()
	play_current()

func select_category(c: String) -> void:
	category = c
	clip_index = 0
	_refresh_ui()
	play_current()

func step_clip(d: int) -> void:
	var n: int = AnimBankCatalog.count(bank, category)
	if n > 0:
		clip_index = posmod(clip_index + d, n)
	play_current()

## Bibliotecas cargadas ahora en el reproductor (rutas): las del banco elegido y ninguna mas.
func loaded_libraries() -> Array:
	return _lib_names.keys()

func _build_body() -> void:
	var want: String = AnimBankCatalog.native_body(bank) if original_body else AnimBankCatalog.COMMON_BODY
	if model != null:
		model.queue_free()
		model = null
	_lib_names.clear()
	body_path = want
	var rig := Node3D.new()
	rig.name = "Rig"
	rig.scale = Vector3.ONE * AnimBankCatalog.BODY_SCALE
	body.add_child(rig)
	model = rig
	var inst: Node3D = (load(want) as PackedScene).instantiate()
	rig.add_child(inst)
	skeleton = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	inst.add_child(anim_player)
	anim_player.root_node = anim_player.get_path_to(inst)
	var i: int = 0
	for path in AnimBankCatalog.libraries(bank):
		var lib: AnimationLibrary = load(path)
		var lname := StringName("b%d" % i)
		anim_player.add_animation_library(lname, lib)
		_lib_names[path] = lname
		i += 1
	_apply_kit()

func _apply_kit() -> void:
	if model == null:
		return
	var kit: Dictionary = SHOOTER_KIT
	match AnimBankCatalog.group_of(category):
		"Arquero":
			kit = KEEPER_KIT
		"Barrera":
			kit = WALL_KIT
	var mat: ShaderMaterial = AnimBankCatalog.kit_material(body_path, kit)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat

# --- Reproduccion ------------------------------------------------------------------------------------------------------

## Clip elegido del banco y categoria actuales ({} si la categoria esta vacia en este banco).
func current_entry() -> Dictionary:
	var list: Array = AnimBankCatalog.clips(bank, category)
	if list.is_empty():
		return {}
	return list[clamp(clip_index, 0, list.size() - 1)]

func play_current() -> void:
	current = current_entry()
	metrics = {}
	_kicked = false
	_restart_in = -1.0
	_seq_stage = 0
	marker.visible = false
	_apply_kit()
	if current.is_empty() or anim_player == null:
		_playing = false
		if anim_player != null:
			anim_player.stop()
		_place_scene({})
		_refresh_ui()
		return
	_anim_name = StringName("%s/%s" % [_lib_names.get(current["biblioteca"], &"b0"), current["id"]])
	_anim = anim_player.get_animation(_anim_name)
	_meta = _anim.get_meta("pack", {}) if _anim != null and _anim.has_meta("pack") else {}
	_idle_name = _idle_clip()
	_place_scene(current)
	metrics = {"pies_min_m": INF, "salto_cadera_m": 0.0, "mano_lateral_m": 0.0, "_hips0": NAN}
	_measure_static()
	_playing = true
	if sequence and _idle_name != &"":
		_seq_stage = 0
		anim_player.play(_idle_name, 0.0, speed)
		_restart_in = 0.6
	else:
		_seq_stage = 1
		_skip_measure = 2
		anim_player.play(_anim_name, 0.0, speed)
	_refresh_ui()

## Reposo del MISMO banco para la secuencia (arquero: espera de arquero; resto: reposo del tirador). "" si no hay.
func _idle_clip() -> StringName:
	var cat: String = "gk_idle" if AnimBankCatalog.group_of(category) == "Arquero" else "st_idle"
	var list: Array = AnimBankCatalog.clips(bank, cat)
	if list.is_empty():
		return &""
	var e: Dictionary = list[0]
	return StringName("%s/%s" % [_lib_names.get(e["biblioteca"], &"b0"), e["id"]])

## Coloca jugador, pelota y camara para la categoria (iguales en los tres bancos).
func _place_scene(e: Dictionary) -> void:
	var half: float = Tuning.pitch.half_length()
	var group: String = AnimBankCatalog.group_of(category)
	_ball_spot = Vector3(half - Tuning.pitch.penalty_mark_distance, ball.radius, 0.0)
	match group:
		"Arquero":
			_facing = Vector3(-1, 0, 0)
			_origin = Vector3(half - 0.5, 0.0, 0.0)
		"Barrera":
			_facing = Vector3(-1, 0, 0)
			_origin = Vector3(_ball_spot.x - 3.0, 0.0, 0.0)
			_ball_spot = Vector3(_origin.x - 9.15, ball.radius, 0.0)
		_:
			_facing = Vector3(1, 0, 0)
			_origin = _ball_spot - _facing * 1.0
			_origin.y = 0.0
			if not e.is_empty() and e.has("contacto"):
				# El contacto medido del clip (punta del pie, metros de juego, adelante/arriba/derecha) cae sobre la pelota.
				var ct: Dictionary = e["contacto"]
				var p: Array = ct["pos"]
				var rt: Vector2 = _root_at(float(ct["t"]))
				var right := _right(_facing)
				var toe_flat: Vector3 = _facing * (rt.x + float(p[0])) + right * (rt.y + float(p[2]))
				_origin = _ball_spot - _facing * ball.radius - toe_flat
				_origin.y = 0.0
	ball.reset_at(_ball_spot)
	body.position = _origin
	body.rotation = Vector3(0.0, atan2(-_facing.z, _facing.x), 0.0)
	_aim_camera()

static func _right(f: Vector3) -> Vector3:
	return Vector3(-f.z, 0.0, f.x)

func _root_at(t: float) -> Vector2:
	var rp: PackedVector2Array = _meta.get("root_path", PackedVector2Array())
	if rp.size() < 2:
		return Vector2.ZERO
	var f: float = clampf(t * 30.0, 0.0, float(rp.size() - 1))
	var i: int = mini(int(f), rp.size() - 2)
	return rp[i].lerp(rp[i + 1], f - float(i))

func _heading_at(t: float) -> float:
	if String(_meta.get("heading_mode", "")) != "turn":
		return 0.0
	return ActionMotion.heading_rel(_meta.get("heading_path", PackedFloat32Array()), t)

## Raiz del clip en el instante t: posicion y rumbo del cuerpo (la cadera del clip va en el sitio).
func _apply_root(t: float) -> void:
	var rt: Vector2 = _root_at(t)
	body.position = _origin + _facing * rt.x + _right(_facing) * rt.y
	var f: Vector3 = _facing.rotated(Vector3.UP, _heading_at(t))
	body.rotation = Vector3(0.0, atan2(-f.z, f.x), 0.0)

## Mediciones que no dependen de la reproduccion: punto de las manos en el extremo de la atajada (para el marcador).
func _measure_static() -> void:
	if _anim == null or AnimBankCatalog.group_of(category) != "Arquero" or skeleton == null:
		return
	var bind: Dictionary = PoseSampler.bind(_anim, skeleton)
	var hl: int = skeleton.find_bone("mixamorig_LeftHand")
	var hr: int = skeleton.find_bone("mixamorig_RightHand")
	var best: float = -1.0
	var best_p := Vector3.ZERO
	var steps: int = clampi(int(_anim.length * 30.0), 1, 300)
	for s in steps + 1:
		var t: float = _anim.length * float(s) / float(steps)
		PoseSampler.apply(_anim, skeleton, bind, t)
		var mid: Vector3 = (PoseSampler.bone_in_skeleton(skeleton, hl).origin + PoseSampler.bone_in_skeleton(skeleton, hr).origin) * 0.5 * AnimBankCatalog.BODY_SCALE
		var rt: Vector2 = _root_at(t)
		var local := Vector3(mid.x + rt.x, mid.y, mid.z + rt.y)
		var lat: float = absf(local.z)
		if lat > best:
			best = lat
			best_p = local
	skeleton.reset_bone_poses()
	marker.position = _origin + _facing * best_p.x + Vector3.UP * best_p.y + _right(_facing) * best_p.z
	marker.visible = true
	metrics["marcador_manos"] = marker.position

## Etapas: 0 reposo previo (solo en secuencia), 1 clip, 2 reposo posterior (secuencia), 3 terminado.
func _process(delta: float) -> void:
	if not _playing or anim_player == null:
		return
	match _seq_stage:
		0:
			_restart_in -= delta
			if _restart_in <= 0.0:
				_seq_stage = 1
				_restart_in = -1.0
				# Con mezcla desde el reposo, la pose del clip tarda BLEND s en quedar sola: se mide despues.
				_skip_measure = 2 + int(ceil(BLEND * 60.0))
				anim_player.play(_anim_name, BLEND, speed)
		1:
			var running: bool = anim_player.current_animation == String(_anim_name)
			var pos: float = anim_player.current_animation_position if running else (_anim.length if _anim != null else 0.0)
			_apply_root(pos)
			if _skip_measure > 0:
				_skip_measure -= 1
			else:
				_live_metrics(pos)
			if not _kicked and current.has("contacto") and pos >= float(current["contacto"]["t"]):
				_kick()
			if not running or pos >= _anim.length - 0.001:
				if sequence and _idle_name != &"":
					_seq_stage = 2
					anim_player.play(_idle_name, BLEND, speed)
				else:
					_seq_stage = 3
				if repeat:
					_restart_in = 1.5
		_:
			if repeat and _restart_in >= 0.0:
				_restart_in -= delta
				if _restart_in <= 0.0:
					play_current()

## Mediciones en vivo sobre el cuerpo mostrado: pies (hundidos/flotando), salto de la cadera, alcance de las manos.
func _live_metrics(_pos: float) -> void:
	if skeleton == null:
		return
	var xf: Transform3D = skeleton.global_transform
	for b in ["mixamorig_LeftToeBase", "mixamorig_RightToeBase", "mixamorig_LeftFoot", "mixamorig_RightFoot"]:
		var y: float = (xf * skeleton.get_bone_global_pose(skeleton.find_bone(b))).origin.y
		metrics["pies_min_m"] = minf(float(metrics.get("pies_min_m", INF)), y)
	var hy: float = (xf * skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_Hips"))).origin.y
	if is_nan(float(metrics.get("_hips0", NAN))):
		metrics["_hips0"] = hy
	metrics["salto_cadera_m"] = maxf(float(metrics.get("salto_cadera_m", 0.0)), hy - float(metrics["_hips0"]))
	var hl: Vector3 = (xf * skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_LeftHand"))).origin
	var hr: Vector3 = (xf * skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_RightHand"))).origin
	var lat: float = absf((((hl + hr) * 0.5) - _origin).dot(_right(_facing)))
	metrics["mano_lateral_m"] = maxf(float(metrics.get("mano_lateral_m", 0.0)), lat)

## Golpe de referencia en el instante de contacto del clip: se mide donde esta la punta del pie respecto de la pelota y la
## pelota sale hacia adelante (no es el disparo del juego: solo muestra la sincronizacion del contacto).
func _kick() -> void:
	_kicked = true
	var ct: Dictionary = current["contacto"]
	if skeleton != null:
		var toe: String = "mixamorig_RightToeBase" if String(ct["pie"]) == "D" else "mixamorig_LeftToeBase"
		var tw: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(toe))).origin
		metrics["pie_pelota_m"] = tw.distance_to(ball.global_position)
	var foot_v: float = float(ct.get("vel", 8.0))
	var loft: float = 0.12
	var power: float = clampf(foot_v * 2.2, 8.0, 30.0)
	if category in ["st_lob"]:
		loft = 0.55
	elif category in ["st_pass"]:
		power = clampf(foot_v * 1.6, 6.0, 18.0)
		loft = 0.03
	var dir: Vector3 = (_facing + Vector3.UP * loft).normalized()
	ball.kick(dir * power)

# --- Camara ------------------------------------------------------------------------------------------------------------

func set_view(v: int) -> void:
	view = v
	_aim_camera()
	_refresh_ui()

func set_zoom(z: float) -> void:
	zoom = clampf(z, 0.5, 2.0)
	_aim_camera()

func _aim_camera() -> void:
	var group: String = AnimBankCatalog.group_of(category)
	# Punto de interes: la pelota en los golpeos, el jugador en lo demas (el mismo para los tres bancos). El tirador siempre
	# ataca hacia +X (el arco de ese lado).
	var focus: Vector3 = _ball_spot if group == "Tirador" else _origin + Vector3.UP * 0.9
	var dist: float = 6.5 / zoom
	var look: Vector3 = focus
	var pos: Vector3
	match view:
		View.BEHIND:
			pos = focus + Vector3(-dist, 2.6, 0.0)
			if group == "Tirador":
				look = focus + Vector3(3.0, 0.0, 0.0)
		View.SIDE:
			pos = focus + Vector3(0.0, 1.4, dist)
		_:
			pos = focus + Vector3(dist, 1.6, 0.0)
	camera.fov = 50.0
	camera.global_position = pos
	camera.look_at(look, Vector3.UP)

# --- Interfaz ----------------------------------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)
	# Arriba: menu, bancos y cuerpo.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 6
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	top.add_child(_button("Menú", func() -> void: back_requested.emit(); _go_menu()))
	var lab := Label.new()
	lab.text = "Banco:"
	_style_label(lab, 18)
	top.add_child(lab)
	for b in AnimBankCatalog.BANKS:
		var btn := _button("%s (%d clips)" % [AnimBankCatalog.label(b), AnimBankCatalog.all_clips(b).size()], select_bank.bind(b))
		btn.toggle_mode = true
		_bank_buttons[b] = btn
		top.add_child(btn)
	# Izquierda: categorias.
	var left := PanelContainer.new()
	left.anchor_top = 0.0
	left.anchor_bottom = 1.0
	left.offset_left = 8
	left.offset_top = 70
	left.offset_right = 300
	left.offset_bottom = -80
	root.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_cat_box = VBoxContainer.new()
	_cat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cat_box)
	var last_group: String = ""
	for c in AnimBankCatalog.categories():
		if String(c["grupo"]) != last_group:
			last_group = String(c["grupo"])
			var h := Label.new()
			h.text = last_group.to_upper()
			_style_label(h, 16)
			_cat_box.add_child(h)
		var cb := _button(String(c["etiqueta"]), select_category.bind(String(c["id"])))
		cb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cb.toggle_mode = true
		cb.custom_minimum_size = Vector2(270, 40)
		_cat_buttons[String(c["id"])] = cb
		_cat_box.add_child(cb)
	# Derecha: datos y mediciones.
	var right := PanelContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -390
	right.offset_right = -8
	right.offset_top = 70
	right.offset_bottom = -80
	root.add_child(right)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_info, 15)
	right.add_child(_info)
	# Centro: aviso de categoria vacia.
	_empty = Label.new()
	_empty.text = "Sin clip en este banco"
	_empty.set_anchors_preset(Control.PRESET_CENTER)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_empty, 34)
	_empty.visible = false
	root.add_child(_empty)
	# Abajo: reproduccion, velocidad, secuencia y camara.
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 8
	bottom.offset_right = -8
	bottom.offset_top = -70
	bottom.offset_bottom = -8
	bottom.add_theme_constant_override("separation", 6)
	root.add_child(bottom)
	bottom.add_child(_button("◀", step_clip.bind(-1)))
	bottom.add_child(_button("▶", step_clip.bind(1)))
	_play_button = _button("Repetir clip", play_current)
	bottom.add_child(_play_button)
	_repeat_button = _button("", func() -> void: repeat = not repeat; _refresh_ui())
	bottom.add_child(_repeat_button)
	for s in SPEEDS:
		var sb := _button("%s×" % str(s), func() -> void: speed = s; play_current())
		sb.toggle_mode = true
		_speed_buttons.append([s, sb])
		bottom.add_child(sb)
	_seq_button = _button("", func() -> void: sequence = not sequence; play_current())
	bottom.add_child(_seq_button)
	for v in VIEW_NAMES.size():
		var vb := _button(VIEW_NAMES[v], set_view.bind(v))
		vb.toggle_mode = true
		_view_buttons.append(vb)
		bottom.add_child(vb)
	bottom.add_child(_button("−", func() -> void: set_zoom(zoom / 1.2)))
	bottom.add_child(_button("+", func() -> void: set_zoom(zoom * 1.2)))

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(56, 52)
	b.add_theme_font_size_override("font_size", 17)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _style_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)

func _go_menu() -> void:
	if get_tree() != null and ResourceLoader.exists(MainMenu.SCENE):
		get_tree().change_scene_to_file(MainMenu.SCENE)

func _refresh_ui() -> void:
	if _info == null:
		return
	for b in _bank_buttons:
		(_bank_buttons[b] as Button).button_pressed = b == bank
	for c in _cat_buttons:
		var n: int = AnimBankCatalog.count(bank, c)
		var cb: Button = _cat_buttons[c]
		var lab: String = ""
		for cc in AnimBankCatalog.categories():
			if String(cc["id"]) == c:
				lab = String(cc["etiqueta"])
		cb.text = "%s  (%d)" % [lab, n] if n > 0 else "%s  — sin clip" % lab
		cb.button_pressed = c == category
		cb.modulate = Color.WHITE if n > 0 else Color(1, 1, 1, 0.55)
	_repeat_button.text = "Repetir: sí" if repeat else "Repetir: no"
	_seq_button.text = "Secuencia: sí" if sequence else "Secuencia: no"
	for e in _speed_buttons:
		(e[1] as Button).button_pressed = is_equal_approx(float(e[0]), speed)
	for v in _view_buttons.size():
		(_view_buttons[v] as Button).button_pressed = v == view
	_empty.visible = current.is_empty()
	_info.text = info_text()

## Texto del panel de datos (tambien lo leen las pruebas).
func info_text() -> String:
	var lines: PackedStringArray = []
	lines.append("BANCO: %s" % AnimBankCatalog.label(bank))
	lines.append("Cuerpo: %s" % ("modelo de Tripo (el del juego)" if body_path == AnimBankCatalog.COMMON_BODY else "futbolista (cuerpo original de Mixamo y Mocap)"))
	if current.is_empty():
		lines.append("")
		lines.append("Sin clip en este banco para esta acción.")
		return "\n".join(lines)
	var n: int = AnimBankCatalog.count(bank, category)
	lines.append("")
	lines.append("Clip %d de %d: %s" % [clip_index + 1, n, current["id"]])
	lines.append("Toma original: %s" % current["toma"])
	lines.append("Espejo: %s · Rol: %s · %.2f s · raíz %.2f m" % ["sí" if current["espejo"] else "no", current["rol"] if String(current["rol"]) != "" else "—",
		float(current["duracion"]), float(current["raiz_m"])])
	if current.has("contacto"):
		var ct: Dictionary = current["contacto"]
		lines.append("Contacto medido: %.2f s · pie %s · %.1f m/s" % [float(ct["t"]), "derecho" if String(ct["pie"]) == "D" else "izquierdo", float(ct["vel"])])
	lines.append("Medido en su cuerpo original: pies mín. %.3f m · salto %.2f m · manos al costado %.2f m" % [float(current["pies_min_m"]),
		float(current["salto_cadera_m"]), absf(float(current["mano_lateral_m"]))])
	if not metrics.is_empty() and is_finite(float(metrics.get("pies_min_m", INF))):
		lines.append("")
		lines.append("Medido ahora en este cuerpo:")
		lines.append("  pies mín. %.3f m (negativo: hundidos; > 0,08: flotando)" % float(metrics["pies_min_m"]))
		lines.append("  salto de la cadera %.2f m · manos al costado %.2f m" % [float(metrics["salto_cadera_m"]), float(metrics["mano_lateral_m"])])
		if metrics.has("pie_pelota_m"):
			lines.append("  punta del pie – centro de la pelota en el golpe: %.2f m" % float(metrics["pie_pelota_m"]))
	return "\n".join(lines)
