class_name AnimLab
extends Node3D
## LABORATORIO DE ANIMACIONES (herramienta de desarrollo, PC y Android; no aparece en la build publica, DevFlags).
## Pedido «Integracion y comparacion de animaciones actuales vs Mixamo» (2026-11-12). Muestra las dos bibliotecas, ACTUAL
## y MIXAMO, sobre el MISMO cuerpo del juego (humano JSON, esqueleto JsonRig), por categorias, con controles de
## reproduccion y la informacion de cada clip; COMPARAR pone una al lado de la otra con el mismo reloj, la misma
## velocidad, la misma camara y la misma pelota (todo lo demas identico). «Situaciones» elige la misma accion en las dos.
##
## Rendimiento: carga solo las bibliotecas de lo que se ve (ACTUAL, MIXAMO o las dos al comparar).
## Mediciones en vivo (las mismas para las dos): altura minima de los pies (hundidos < 0 / flotando), deslizamiento del pie
## apoyado (m/s con la punta a menos de 3 cm del piso) y, en los golpeos, distancia punta del pie - pelota en el contacto
## del clip (la pelota recibe un golpe de referencia en ese instante con Ball.kick; la fisica no cambia).

signal back_requested

const SCENE := "res://scenes/dev/anim_lab.tscn"
const MENU_SCENE := "res://scenes/setpiece/main_menu.tscn"
const BODY := "res://assets/characters/json/json_human.scn"
const BALL_SCENE := preload("res://scenes/ball/ball.tscn")
const BODY_SCALE := 1.75
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 1.5]

enum Mode { ACTUAL, MIXAMO, COMPARE }
const MODE_NAMES := ["ACTUAL", "MIXAMO", "COMPARAR"]
enum View { DIAGONAL, FRONT, BEHIND, SIDE }
const VIEW_NAMES := ["Diagonal", "Frente", "Atrás", "Lateral"]

## Categorias pedidas y los roles de cada una (los roles que no estan en ninguna van a «Jugador»).
const CATEGORIES := ["Jugador", "Arquero", "Locomoción", "Disparos", "Pases", "Conducción", "Defensa", "Caídas",
	"Recuperación", "Celebraciones", "Reacciones"]
const CATEGORY_ROLES := {
	"Locomoción": ["walk", "jog", "run", "sprint", "loco_jog", "loco_run", "loco_sprint", "loco_walk", "dir_back",
		"dir_back_diag", "dir_fwd_diag", "dir_side", "start", "stop", "turn_run", "turn"],
	"Disparos": ["setpiece_shot", "setpiece_lob", "setpiece_miss", "kick_shot", "kick_shot_hard", "kick_lob", "volley"],
	"Pases": ["setpiece_pass", "kick_pass", "kick_pass_soft"],
	"Conducción": ["ball_dribble", "ball_turn", "ball_skill", "ball_start", "receive_chest", "receive_foot", "header", "throw_in"],
	"Defensa": ["defend", "slide", "shove", "wall", "avoid", "throw_prep"],
	"Caídas": ["fall", "fall_hit", "trip", "stumble", "stumble_light", "lie"],
	"Recuperación": ["getup", "gk_getup"],
	"Celebraciones": ["celebrate", "celebrate_scorer", "celebrate_team", "clap", "thumbs_up"],
	"Reacciones": ["angry", "dejected", "defeat_end", "sad", "gesture", "gk_gesture", "nod", "referee"],
}
## Situaciones de la comparacion directa: roles preferidos, en orden (se toma el primer clip del primer rol con clips).
const SITUATIONS := {
	"Penal": ["setpiece_shot", "kick_shot"],
	"Tiro libre": ["setpiece_lob", "setpiece_shot"],
	"Atajada": ["gk_dive", "gk_catch"],
	"Disparo potente": ["kick_shot_hard", "setpiece_shot"],
	"Pase": ["kick_pass", "setpiece_pass"],
	"Conducción": ["ball_dribble", "ball_skill"],
	"Carrera": ["run", "loco_sprint", "sprint", "jog"],
	"Caída": ["fall", "trip", "stumble"],
	"Recuperación": ["getup", "gk_getup"],
	"Celebración": ["celebrate_scorer", "celebrate", "celebrate_team"],
}
const KIT := {"jersey": Color(0.10, 0.32, 0.86), "shorts": Color(0.95, 0.95, 0.97), "socks": Color(0.10, 0.32, 0.86),
	"boots": Color(0.95, 0.55, 0.08), "skin": Color(0.62, 0.40, 0.29), "hair": Color(0.12, 0.07, 0.04)}
const KIT_MX := {"jersey": Color(0.82, 0.08, 0.10), "shorts": Color(0.06, 0.06, 0.08), "socks": Color(0.82, 0.08, 0.10),
	"boots": Color(0.05, 0.05, 0.05), "skin": Color(0.62, 0.40, 0.29), "hair": Color(0.12, 0.07, 0.04)}

## Catalogo por biblioteca (se arma de las bibliotecas, sin archivo generado): {bank: {categoria: [ids sin espejo]}}.
static var _catalog: Dictionary = {}

var mode: int = Mode.COMPARE
var category: String = "Disparos"
var speed: float = 1.0
var loop: bool = true
var playing: bool = true
var mirror: bool = false
var view: int = View.DIAGONAL
## Reloj comun (s de clip) de las dos estaciones.
var clock: float = 0.0
var pitch: Pitch
var camera: Camera3D
var stations: Array = []   # [Station ACTUAL, Station MIXAMO] (segun el modo, una sola visible)

var _ui: CanvasLayer
var _info: Array[Label] = []
var _mode_buttons: Array[Button] = []
var _cat_buttons: Dictionary = {}
var _speed_buttons: Array[Button] = []
var _play_button: Button
var _loop_button: Button
var _mirror_button: Button
var _view_button: Button
var _game_bank_button: Button
var _status: Label

## Una estacion: cuerpo del juego con un reproductor que solo tiene las bibliotecas de UNA biblioteca de animaciones.
class Station:
	extends RefCounted
	var bank: int
	var root: Node3D
	var body: Node3D
	var skeleton: Skeleton3D
	var player: AnimationPlayer
	var ball: Ball
	var label: Label3D
	var libs: Dictionary = {}      # clave -> AnimationLibrary
	var where: Dictionary = {}     # id -> clave
	var index: int = 0
	var id: StringName = &""
	var meta: Dictionary = {}
	var length: float = 0.0
	var base := Vector3.ZERO       # lugar de la estacion
	var origin := Vector3.ZERO     # marco del clip
	var facing := Vector3(1, 0, 0)
	var ball_spot := Vector3.ZERO
	var kicked: bool = false
	## Retraso del arranque (s del reloj comun): en la comparacion, los golpeos se alinean para que las dos pelotas se
	## golpeen en el mismo instante.
	var lead: float = 0.0
	var metrics: Dictionary = {}
	var _prev_toe := {}

func _ready() -> void:
	pitch = Pitch.new()
	pitch.name = "Pitch"
	add_child(pitch)
	pitch.build(Tuning.pitch)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.current = true
	_build_ui()
	GraphicsSettings.apply()
	set_mode(Mode.COMPARE if AnimBank.mixamo_available() else Mode.ACTUAL)

# --- Catalogo ----------------------------------------------------------------------------------------------------------

static func bank_libraries(bank: int) -> Dictionary:
	return SpClips.MIXAMO_LIBS if bank == AnimBank.Bank.MIXAMO else SpClips.LIBS

static func category_of(role: String) -> String:
	if role.begins_with("gk_") and role != "gk_getup" and role != "gk_gesture":
		return "Arquero"
	for c in CATEGORY_ROLES:
		if (CATEGORY_ROLES[c] as Array).has(role):
			return c
	return "Jugador"

## {categoria: [ids]} de una biblioteca (sin espejos), ordenados por rol y por id.
static func catalog(bank: int) -> Dictionary:
	if _catalog.has(bank):
		return _catalog[bank]
	var out := {}
	for c in CATEGORIES:
		out[c] = []
	for key in bank_libraries(bank):
		var path: String = bank_libraries(bank)[key]
		if not ResourceLoader.exists(path):
			continue
		var lib: AnimationLibrary = load(path) as AnimationLibrary
		for id in lib.get_animation_list():
			if String(id).ends_with("_mirror"):
				continue
			var role: String = String(lib.get_animation(id).get_meta("pack", {}).get("role", ""))
			(out[category_of(role)] as Array).append([role, String(id)])
	for c in out:
		var arr: Array = out[c]
		arr.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var ids: Array[StringName] = []
		for e in arr:
			ids.append(StringName(e[1]))
		out[c] = ids
	_catalog[bank] = out
	return out

static func clip_count(bank: int) -> int:
	var n: int = 0
	for c in catalog(bank):
		n += (catalog(bank)[c] as Array).size()
	return n

# --- Estaciones --------------------------------------------------------------------------------------------------------

func _station(bank: int) -> Station:
	for s in stations:
		if (s as Station).bank == bank:
			return s
	var st := Station.new()
	st.bank = bank
	st.root = Node3D.new()
	st.root.name = "Station_%s" % AnimBank.NAMES[bank]
	add_child(st.root)
	st.body = Node3D.new()
	st.root.add_child(st.body)
	var rig := Node3D.new()
	rig.scale = Vector3.ONE * BODY_SCALE
	st.body.add_child(rig)
	var inst: Node3D = (load(BODY) as PackedScene).instantiate()
	rig.add_child(inst)
	st.skeleton = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	st.player = AnimationPlayer.new()
	inst.add_child(st.player)
	st.player.root_node = st.player.get_path_to(inst)
	for key in bank_libraries(bank):
		var path: String = bank_libraries(bank)[key]
		if not ResourceLoader.exists(path):
			continue
		var lib: AnimationLibrary = load(path) as AnimationLibrary
		st.libs[key] = lib
		st.player.add_animation_library(key, lib)
		for id in lib.get_animation_list():
			if not st.where.has(id):
				st.where[id] = key
	var mat: ShaderMaterial = AnimBankCatalog.kit_material(BODY, KIT_MX if bank == AnimBank.Bank.MIXAMO else KIT)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	st.ball = BALL_SCENE.instantiate()
	st.root.add_child(st.ball)
	st.label = Label3D.new()
	st.label.text = AnimBank.NAMES[bank]
	st.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	st.label.font_size = 36
	st.label.outline_size = 10
	st.label.modulate = Color(1.0, 0.84, 0.28) if bank == AnimBank.Bank.MIXAMO else Color(0.6, 0.85, 1.0)
	st.root.add_child(st.label)
	stations.append(st)
	return st

func _visible_stations() -> Array:
	var out: Array = []
	for s in stations:
		if (s as Station).root.visible:
			out.append(s)
	return out

func set_mode(m: int) -> void:
	if m != Mode.ACTUAL and not AnimBank.mixamo_available():
		m = Mode.ACTUAL
	mode = m
	var want: Array = []
	if m == Mode.ACTUAL or m == Mode.COMPARE:
		want.append(AnimBank.Bank.ACTUAL)
	if m == Mode.MIXAMO or m == Mode.COMPARE:
		want.append(AnimBank.Bank.MIXAMO)
	# Solo se cargan las bibliotecas de lo que se ve: la estacion que no se usa se libera.
	for s in stations.duplicate():
		if not want.has((s as Station).bank):
			(s as Station).root.queue_free()
			stations.erase(s)
	for b in want:
		_station(b)
	_layout()
	restart()

## Direccion (horizontal) desde el centro de las estaciones hacia la camara, segun la vista.
func _cam_dir() -> Vector3:
	match view:
		View.FRONT:
			return Vector3(1, 0, 0)
		View.BEHIND:
			return Vector3(-1, 0, 0)
		View.SIDE:
			return Vector3(0, 0, 1)
	return Vector3(0.55, 0, 0.8).normalized()

func _layout() -> void:
	var vis: Array = []
	for b in [AnimBank.Bank.ACTUAL, AnimBank.Bank.MIXAMO]:
		for s in stations:
			if (s as Station).bank == b:
				vis.append(s)
	var half: float = Tuning.pitch.half_length()
	var spot_x: float = half - Tuning.pitch.penalty_mark_distance - 5.0
	# Lado a lado PERPENDICULAR a la camara: ACTUAL a la izquierda y MIXAMO a la derecha en pantalla.
	var right: Vector3 = Vector3.UP.cross(_cam_dir()).normalized()
	for i in vis.size():
		var st: Station = vis[i]
		var off: float = 0.0 if vis.size() == 1 else (-1.9 if i == 0 else 1.9)
		st.base = Vector3(spot_x, 0.0, 0.0) + right * off
		st.root.visible = true

# --- Reproduccion ------------------------------------------------------------------------------------------------------

func select_category(c: String) -> void:
	category = c
	for s in stations:
		(s as Station).index = 0
	restart()

## Cambia de clip en una estacion (d = +1 / -1); con una sola visible, en esa.
func step(bank: int, d: int) -> void:
	for s in stations:
		var st: Station = s
		if st.bank == bank:
			var n: int = (catalog(bank).get(category, []) as Array).size()
			if n > 0:
				st.index = posmod(st.index + d, n)
	restart()

## La misma accion en las dos bibliotecas.
func select_situation(name_: String) -> void:
	var roles_: Array = SITUATIONS.get(name_, [])
	for s in stations:
		var st: Station = s
		for r in roles_:
			var cat: String = category_of(String(r))
			var ids: Array = catalog(st.bank).get(cat, [])
			var found: int = -1
			for i in ids.size():
				var m: Dictionary = (st.libs[st.where[ids[i]]] as AnimationLibrary).get_animation(ids[i]).get_meta("pack", {})
				if String(m.get("role", "")) == String(r):
					found = i
					break
			if found >= 0:
				category = cat
				st.index = found
				break
	restart()

func restart() -> void:
	clock = 0.0
	for s in stations:
		_start(s)
	# Comparacion: si los dos clips tienen contacto con la pelota, el que golpea antes arranca despues.
	var cts: Array = []
	for s in stations:
		var ct: Dictionary = (s as Station).meta.get("contact", {})
		cts.append(float(ct.get("time", -1.0)) if not ct.is_empty() else -1.0)
	var latest: float = -1.0
	for c in cts:
		latest = maxf(latest, float(c))
	for i in stations.size():
		(stations[i] as Station).lead = (latest - float(cts[i])) if (stations.size() > 1 and float(cts[i]) >= 0.0 and not cts.has(-1.0)) else 0.0
	for s in stations:
		_pose(s, -(s as Station).lead)
	_aim_camera()
	_refresh_ui()

func _start(st: Station) -> void:
	var ids: Array = catalog(st.bank).get(category, [])
	st.kicked = false
	st.metrics = {"pies_min_cm": INF, "desliz_sum": 0.0, "desliz_n": 0}
	st._prev_toe = {}
	if ids.is_empty():
		st.id = &""
		st.meta = {}
		st.length = 0.0
		st.player.stop()
		st.body.visible = false
		st.ball.reset_at(st.base + Vector3(1.0, 0.11, 0.0))
		st.label.position = st.base + Vector3.UP * 2.3
		return
	st.body.visible = true
	st.index = clampi(st.index, 0, ids.size() - 1)
	var id: StringName = ids[st.index]
	if mirror and st.where.has(StringName(String(id) + "_mirror")):
		id = StringName(String(id) + "_mirror")
	st.id = id
	var a: Animation = (st.libs[st.where[id]] as AnimationLibrary).get_animation(id)
	st.meta = a.get_meta("pack", {})
	st.length = a.length
	st.facing = Vector3(1, 0, 0)
	st.ball_spot = st.base + Vector3(1.0, 0.11, 0.0)
	st.origin = st.base
	var ct: Dictionary = st.meta.get("contact", {})
	if not ct.is_empty():
		# El contacto medido del clip (punta del pie, adelante/arriba/derecha respecto de la raiz) cae sobre la pelota.
		var p: Vector3 = ct.get("pos", Vector3.ZERO)
		var rt: Vector2 = SpClips.root_at(st.meta, float(ct.get("time", 0.0)))
		var toe_flat: Vector3 = st.facing * (rt.x + p.x) + SpClips.right_of(st.facing) * (rt.y + p.z)
		st.origin = st.ball_spot - st.facing * 0.11 - toe_flat
		st.origin.y = 0.0
	st.ball.reset_at(st.ball_spot)
	st.player.play("%s/%s" % [st.where[id], id], 0.0, 1.0)
	st.player.speed_scale = 0.0
	_pose(st, 0.0)

## Instante t del clip en una estacion: pose (seek), raiz, rumbo, golpe de referencia en el contacto y mediciones.
func _pose(st: Station, t: float) -> void:
	if st.id == &"":
		return
	var tt: float = clampf(t, 0.0, st.length)
	st.player.seek(tt, true)
	var rt: Vector2 = SpClips.root_at(st.meta, tt)
	st.body.position = st.origin + st.facing * rt.x + SpClips.right_of(st.facing) * rt.y
	var f: Vector3 = st.facing.rotated(Vector3.UP, SpClips.heading_at(st.meta, tt))
	st.body.rotation = Vector3(0.0, SpClips.yaw_of(f), 0.0)
	st.label.position = st.body.position + Vector3.UP * 2.15
	var ct: Dictionary = st.meta.get("contact", {})
	if not ct.is_empty() and not st.kicked and tt >= float(ct.get("time", 0.0)):
		st.kicked = true
		var toe: String = "mixamorig_RightToeBase" if int(ct.get("foot", 1)) > 0 else "mixamorig_LeftToeBase"
		st.metrics["pie_pelota_m"] = _bone(st, toe).distance_to(st.ball.global_position)
		var power: float = clampf(float(ct.get("speed", 8.0)) * 2.2, 8.0, 30.0)
		st.ball.kick((st.facing + Vector3.UP * 0.15).normalized() * power)

func _bone(st: Station, b: String) -> Vector3:
	return (st.skeleton.global_transform * st.skeleton.get_bone_global_pose(st.skeleton.find_bone(b))).origin

func _measure(st: Station, delta: float) -> void:
	if st.id == &"" or clock - st.lead > st.length or clock < st.lead:
		return
	for b in ["mixamorig_LeftToeBase", "mixamorig_RightToeBase"]:
		var p: Vector3 = _bone(st, b)
		st.metrics["pies_min_cm"] = minf(float(st.metrics["pies_min_cm"]), p.y * 100.0)
		if st._prev_toe.has(b) and p.y < 0.03 and delta > 0.0:
			var q: Vector3 = st._prev_toe[b]
			st.metrics["desliz_sum"] = float(st.metrics["desliz_sum"]) + Vector2(p.x - q.x, p.z - q.z).length() / delta
			st.metrics["desliz_n"] = int(st.metrics["desliz_n"]) + 1
		st._prev_toe[b] = p

func _process(delta: float) -> void:
	if playing:
		var dt: float = delta * speed
		clock += dt
		var longest: float = 0.0
		for s in stations:
			longest = maxf(longest, (s as Station).length + (s as Station).lead)
		# Las dos empiezan juntas: al terminar la mas larga (y una pausa corta) vuelven a empezar a la vez.
		if clock > longest + 0.8:
			if loop:
				restart()
				return
			clock = longest + 0.8
			playing = false
		for s in stations:
			_pose(s, clock - (s as Station).lead)
			_measure(s, dt)
	_refresh_info()

func toggle_play() -> void:
	playing = not playing
	_refresh_ui()

func set_speed(v: float) -> void:
	speed = v
	_refresh_ui()

# --- Camara ------------------------------------------------------------------------------------------------------------

func set_view(v: int) -> void:
	view = v
	_layout()
	restart()

func _aim_camera() -> void:
	var vis: Array = _visible_stations()
	var c := Vector3.ZERO
	for s in vis:
		c += (s as Station).base
	c = c / maxf(vis.size(), 1) + Vector3(0.6, 0.9, 0.0)
	var dist: float = 8.0 if vis.size() > 1 else 5.5
	var pos: Vector3 = c + _cam_dir() * dist + Vector3.UP * (1.6 if view == View.DIAGONAL else 0.9)
	camera.fov = 50.0
	camera.global_position = pos
	camera.look_at(c, Vector3.UP)

# --- Informacion --------------------------------------------------------------------------------------------------------

## Texto de informacion de una estacion (lo leen las pruebas).
func info_text(st: Station) -> String:
	var bank_name: String = AnimBank.NAMES[st.bank]
	if st.id == &"":
		return "%s · %s\nSin clip en esta categoría.\n%s" % [bank_name, category,
			"Se usa el ACTUAL como respaldo." if st.bank == AnimBank.Bank.MIXAMO else ""]
	var role: String = String(st.meta.get("role", ""))
	var n: int = (catalog(st.bank).get(category, []) as Array).size()
	var a: Animation = (st.libs[st.where[st.id]] as AnimationLibrary).get_animation(st.id)
	var ok_tracks: int = 0
	var tracks: int = 0
	for i in a.get_track_count():
		var path: NodePath = a.track_get_path(i)
		if path.get_subname_count() > 0:
			tracks += 1
			if st.skeleton.find_bone(String(path.get_subname(0))) >= 0:
				ok_tracks += 1
	var lines: Array[String] = []
	lines.append("%s · %s  (%d/%d)" % [bank_name, category, st.index + 1, n])
	lines.append("Clip: %s" % st.id)
	lines.append("Original: %s" % String(st.meta.get("source", "")).get_basename())
	lines.append("Rol: %s · %.2f s · %s" % [role, st.length, "bucle" if bool(st.meta.get("loop", false)) else "una vez"])
	lines.append("Esqueleto: JsonRig, 23 huesos · pistas válidas %d/%d" % [ok_tracks, tracks])
	if st.bank == AnimBank.Bank.MIXAMO:
		lines.append("Retargeting: sí (Tripo/Mixamo -> proporciones del juego -> JsonRetarget)")
		lines.append("Raíz: %s" % ("reconstruida desde el pie de apoyo" if SpClips.root_travel(st.meta) > 0.05 else "en el sitio"))
	else:
		lines.append("Retargeting: sí (JSON de 19 articulaciones -> JsonRetarget)")
	lines.append("Estado: %s" % _status_of(st, role))
	var ct: Dictionary = st.meta.get("contact", {})
	if not ct.is_empty():
		lines.append("Contacto: t=%.2f s, pie %s%s" % [float(ct.get("time", 0.0)), "D" if int(ct.get("foot", 1)) > 0 else "I",
			(", punta-pelota %.2f m" % float(st.metrics["pie_pelota_m"])) if st.metrics.has("pie_pelota_m") else ""])
	var pm: float = float(st.metrics.get("pies_min_cm", INF))
	var dn: int = int(st.metrics.get("desliz_n", 0))
	lines.append("Pies: mín %s · deslizamiento %s" % ["%+.1f cm" % pm if pm < INF else "-",
		"%.2f m/s" % (float(st.metrics["desliz_sum"]) / dn) if dn > 0 else "-"])
	return "\n".join(lines)

## En el juego: si este clip se usa con la biblioteca que este elegida.
func _status_of(st: Station, role: String) -> String:
	var game_mx: bool = AnimBank.is_mixamo()
	var mx_has: bool = (catalog(AnimBank.Bank.MIXAMO).get(category_of(role), []) as Array).any(
		func(i: StringName) -> bool: return _role_of(AnimBank.Bank.MIXAMO, i) == role) if AnimBank.mixamo_available() else false
	if st.bank == AnimBank.Bank.MIXAMO:
		return "en uso en el juego" if game_mx else "disponible (el juego usa ACTUAL)"
	if not game_mx:
		return "en uso en el juego"
	return "reemplazado por Mixamo en el juego" if mx_has else "respaldo: Mixamo no tiene «%s»" % role

func _role_of(bank: int, id: StringName) -> String:
	for key in bank_libraries(bank):
		var path: String = bank_libraries(bank)[key]
		if not ResourceLoader.exists(path):
			continue
		var lib: AnimationLibrary = load(path) as AnimationLibrary
		if lib.has_animation(id):
			return String(lib.get_animation(id).get_meta("pack", {}).get("role", ""))
	return ""

func station_info(bank: int) -> String:
	for s in stations:
		if (s as Station).bank == bank:
			return info_text(s)
	return ""

# --- Interfaz ----------------------------------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var top := HBoxContainer.new()
	top.position = Vector2(12, 8)
	top.add_theme_constant_override("separation", 6)
	_ui.add_child(top)
	for i in MODE_NAMES.size():
		var b: Button = _button(MODE_NAMES[i], set_mode.bind(i))
		_mode_buttons.append(b)
		top.add_child(b)
	_game_bank_button = _button("", _toggle_game_bank)
	top.add_child(_game_bank_button)
	top.add_child(_button("Penal en el juego", _play_in_game.bind(SetPieceGame.Mode.PENALTY)))
	top.add_child(_button("Tiro libre en el juego", _play_in_game.bind(SetPieceGame.Mode.FREE_KICK)))
	top.add_child(_button("Volver", _go_back))
	var left := VBoxContainer.new()
	left.position = Vector2(12, 74)
	left.add_theme_constant_override("separation", 4)
	_ui.add_child(left)
	var lc := Label.new()
	lc.text = "Categorías"
	_style(lc, 20)
	left.add_child(lc)
	for c in CATEGORIES:
		var b: Button = _button(c, select_category.bind(c))
		b.custom_minimum_size = Vector2(190, 40)
		_cat_buttons[c] = b
		left.add_child(b)
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -200
	right.offset_top = 74
	right.add_theme_constant_override("separation", 4)
	_ui.add_child(right)
	var ls := Label.new()
	ls.text = "Situaciones"
	_style(ls, 20)
	right.add_child(ls)
	for sname in SITUATIONS:
		var b: Button = _button(sname, select_situation.bind(sname))
		b.custom_minimum_size = Vector2(190, 40)
		right.add_child(b)
	var bottom := HBoxContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -64
	bottom.offset_left = 12
	bottom.add_theme_constant_override("separation", 6)
	_ui.add_child(bottom)
	bottom.add_child(_button("◀ ACT", step.bind(AnimBank.Bank.ACTUAL, -1)))
	bottom.add_child(_button("ACT ▶", step.bind(AnimBank.Bank.ACTUAL, 1)))
	bottom.add_child(_button("◀ MIX", step.bind(AnimBank.Bank.MIXAMO, -1)))
	bottom.add_child(_button("MIX ▶", step.bind(AnimBank.Bank.MIXAMO, 1)))
	_play_button = _button("Pausa", toggle_play)
	bottom.add_child(_play_button)
	bottom.add_child(_button("Reiniciar", restart))
	_loop_button = _button("Bucle", func() -> void:
		loop = not loop
		_refresh_ui())
	bottom.add_child(_loop_button)
	for v in SPEEDS:
		var b: Button = _button("x%s" % str(v), set_speed.bind(v))
		_speed_buttons.append(b)
		bottom.add_child(b)
	_mirror_button = _button("Espejo", func() -> void:
		mirror = not mirror
		restart())
	bottom.add_child(_mirror_button)
	_view_button = _button("Vista", func() -> void: set_view((view + 1) % VIEW_NAMES.size()))
	bottom.add_child(_view_button)
	for i in 2:
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.0, 0.03, 0.08, 0.55)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", sb)
		panel.position = Vector2(215 + i * 445, 74)
		panel.custom_minimum_size = Vector2(435, 0)
		_ui.add_child(panel)
		var l := Label.new()
		_style(l, 14)
		l.custom_minimum_size = Vector2(420, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(l)
		_info.append(l)
	_status = Label.new()
	_style(_status, 16)
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_top = -96
	_status.offset_left = 12
	_ui.add_child(_status)

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _style(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)

func _refresh_ui() -> void:
	if _play_button == null:
		return
	for i in _mode_buttons.size():
		_mode_buttons[i].button_pressed = i == mode
		_mode_buttons[i].toggle_mode = true
		_mode_buttons[i].disabled = i != Mode.ACTUAL and not AnimBank.mixamo_available()
		_mode_buttons[i].set_pressed_no_signal(i == mode)
	for c in _cat_buttons:
		(_cat_buttons[c] as Button).toggle_mode = true
		(_cat_buttons[c] as Button).set_pressed_no_signal(c == category)
	for i in _speed_buttons.size():
		_speed_buttons[i].toggle_mode = true
		_speed_buttons[i].set_pressed_no_signal(is_equal_approx(SPEEDS[i], speed))
	_play_button.text = "Pausa" if playing else "Reproducir"
	_loop_button.text = "Bucle: %s" % ("sí" if loop else "no")
	_mirror_button.text = "Espejo: %s" % ("sí" if mirror else "no")
	_view_button.text = "Vista: %s" % VIEW_NAMES[view]
	_game_bank_button.text = "Juego: %s" % AnimBank.current_name()
	_game_bank_button.disabled = not AnimBank.mixamo_available()
	var fb: Array = SpClips.fallback_roles() if AnimBank.is_mixamo() else []
	_status.text = "Clips: ACTUAL %d · MIXAMO %s%s" % [clip_count(AnimBank.Bank.ACTUAL),
		str(clip_count(AnimBank.Bank.MIXAMO)) if AnimBank.mixamo_available() else "no incluido en esta build",
		("  ·  respaldo ACTUAL en %d roles" % fb.size()) if not fb.is_empty() else ""]

func _refresh_info() -> void:
	var vis: Array = []
	for b in [AnimBank.Bank.ACTUAL, AnimBank.Bank.MIXAMO]:
		for s in stations:
			if (s as Station).bank == b:
				vis.append(s)
	for i in _info.size():
		_info[i].text = info_text(vis[i]) if i < vis.size() else ""

## Biblioteca que usa el JUEGO (penales, tiros libres, arquero, festejos...). Se guarda y vale al entrar a un modo.
func _toggle_game_bank() -> void:
	AnimBank.set_bank(AnimBank.Bank.ACTUAL if AnimBank.is_mixamo() else AnimBank.Bank.MIXAMO)
	_refresh_ui()

## Situacion real: el modo del juego con la biblioteca elegida en «Juego».
func _play_in_game(m: int) -> void:
	SetPieceGame.next_mode = m
	get_tree().change_scene_to_file(SetPieceGame.SCENE)

func _go_back() -> void:
	back_requested.emit()
	get_tree().change_scene_to_file(MENU_SCENE)
