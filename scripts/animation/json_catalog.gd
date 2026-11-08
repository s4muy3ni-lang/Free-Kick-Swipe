class_name JsonCatalog
extends RefCounted
## Tablas del modo 4 (Json): modelo, escalones de la marcha (sin y con pelota), mezcla direccional y candidatos de
## patada por rol. Los clips salen de la libreria json_clips.res (ver PackLibrary.json_mode); aqui solo se dice cual va
## en cada escalon. Cada clip de marcha es UN ciclo que empieza en un apoyo del pie izquierdo, asi que todos se reproducen
## con una linea de tiempo comun de un ciclo (AnimationNodeAnimation.use_custom_timeline) y sus fases coinciden al mezclar.

const HUMAN_SCENE := "res://assets/characters/json/json_human.scn"
const KIT_SHADER_PATH := "res://assets/characters/json/json_kit.gdshader"

## Escalones de la marcha sin pelota: [clip, velocidad (m/s) a la que se reproduce a su ritmo natural]. -1 = la velocidad
## natural medida del clip (meta natural_speed). El reposo va a velocidad 0.
const GAIT := [
	[&"jn_idle_0520", 0.0], [&"jn_walk_0460", -1.0], [&"jn_jog_1144", -1.0], [&"jn_jog_2390", -1.0], [&"jn_sprint_3022", -1.0],
]
## Marcha con la pelota (conduccion): reposo con balon y ciclos de conduccion cada vez mas rapidos.
const CARRY := [
	[&"jn_idle_ball_0524", 0.0], [&"jn_dribble_walk_0234", -1.0], [&"jn_dribble_jog_1574", -1.0], [&"jn_dribble_run_3186", -1.0],
	[&"jn_dribble_fast_0548", -1.0], [&"jn_dribble_sprint_1582", -1.0],
]
## Roles de la mezcla direccional (marcaje, arquero): la direccion de cada clip sale de su meta natural_dir.
const DIR_ROLES: Array[StringName] = [&"dir_back", &"dir_back_diag", &"dir_fwd_diag", &"dir_side", &"dir_back_walk", &"dir_fwd_diag_walk"]

## Mezcla direccional del modo 4 (marcaje y presion mirando al rival, arquero, arbitro): [clip, x, y] con x = derecha e
## y = adelante, todos a distancia 1 en la direccion medida del clip (meta natural_dir = adelante, derecha); al frente, el
## trote de la marcha. Sin esto la mezcla quedaba sin clips (buscaba los nombres del pack de Mixamo) y el jugador que
## presionaba se deslizaba con la pose fija («como estatuas»).
static var _direction_cache: Dictionary = {}
static var _gait_points_cache: Dictionary = {}

static func dir_points(keeper: bool = false) -> Array:
	if _direction_cache.has(keeper):
		return _direction_cache[keeper]
	var out: Array = []
	if PackLibrary.has_clip(DIR_FORWARD):
		out.append([DIR_FORWARD, 0.0, 1.0])
	for role in DIR_JOG_ROLES:
		for id in PackLibrary.by_role(role):
			var nd: Vector2 = PackLibrary.meta(id).get("natural_dir", Vector2.ZERO)
			if nd.length() < 0.5:
				continue
			var d: Vector2 = Vector2(nd.y, nd.x).normalized()
			out.append([id, d.x, d.y])
	# Variantes laterales y hacia atras: su direccion medida las conecta a la mezcla de marcaje, no a la carrera frontal.
	var extra_roles: Array[StringName] = [&"loco_walk", &"loco_jog", &"loco_side"]
	if keeper:
		extra_roles.append(&"gk_loco")
	for role in extra_roles:
		for id in AnimDB.candidates(role, {"mirrors": false}):
			var m: Dictionary = PackLibrary.meta(id)
			var nd: Vector2 = m.get("natural_dir", Vector2.ZERO)
			if not bool(m.get("loop", false)) or nd.length() < 0.5:
				continue
			if role != &"gk_loco" and nd.normalized().x > 0.95:
				continue
			var d: Vector2 = Vector2(nd.y, nd.x).normalized()
			out.append([id, d.x, d.y])
	_direction_cache[keeper] = out
	return out

## Velocidad media (m/s) de los clips de dir_points a su ritmo natural (referencia de la cadencia de la mezcla).
static func dir_ref_speed() -> float:
	var sum := 0.0
	var n := 0
	for pt in dir_points():
		var v: float = float(PackLibrary.meta(pt[0]).get("natural_speed", 0.0))
		if v > 0.3:
			sum += v
			n += 1
	return sum / float(n) if n > 0 else 2.3

const DIR_FORWARD := &"jn_jog_1144"
## Roles de la mezcla direccional usados en la marcha (los de paso, *_walk, quedan para la galeria).
const DIR_JOG_ROLES: Array[StringName] = [&"dir_back", &"dir_back_diag", &"dir_fwd_diag", &"dir_side"]

static func active() -> bool:
	return PackLibrary.json_mode()

## Modelo del modo: el humanoide propio (el GLB de Tripo adaptado se descarto: se deformaba con estas animaciones).
static func model_path() -> String:
	return HUMAN_SCENE if ResourceLoader.exists(HUMAN_SCENE) else ""

static func is_human_model(path: String) -> bool:
	return path == HUMAN_SCENE

## Escalones [clip, posicion en el BlendSpace (m/s)] de la marcha (carry: con pelota) que existen en la libreria.
static func gait_points(carry: bool) -> Array:
	if _gait_points_cache.has(carry):
		return _gait_points_cache[carry]
	var out: Array = []
	for pt in (CARRY if carry else GAIT):
		var id: StringName = pt[0]
		if not PackLibrary.has_clip(id):
			continue
		var pos: float = float(pt[1])
		if pos < 0.0:
			pos = float(PackLibrary.meta(id).get("natural_speed", 0.0))
		out.append([id, pos])
	var extra_roles: Array = [&"dribble_jog", &"dribble_run", &"dribble_fast", &"dribble_sprint"] if carry else [&"loco_walk", &"loco_jog", &"loco_sprint"]
	var present: Dictionary = {}
	for point in out:
		present[point[0]] = true
	for role in extra_roles:
		for id in AnimDB.candidates(role, {"mirrors": false}):
			var m: Dictionary = PackLibrary.meta(id)
			var direction: Vector2 = m.get("natural_dir", Vector2.ZERO)
			if present.has(id) or not bool(m.get("loop", false)) or direction.normalized().x <= 0.95:
				continue
			out.append([id, float(m.get("natural_speed", 0.0))])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	_gait_points_cache[carry] = out
	return out

## Longitud de zancada (m por ciclo) de un escalon: velocidad natural por duracion del ciclo.
static func stride_of(id: StringName) -> float:
	var m: Dictionary = PackLibrary.meta(id)
	return float(m.get("natural_speed", 0.0)) * float(m.get("duration", 1.0))

## Ciclos por segundo de la marcha a una velocidad: la velocidad dividida por la zancada interpolada entre los escalones;
## parado, el ritmo del reposo.
static func cycles_per_second(speed: float, carry: bool) -> float:
	var pts: Array = gait_points(carry)
	if pts.size() < 2:
		return 1.0
	var idle_len: float = float(PackLibrary.meta(pts[0][0]).get("duration", 3.0))
	var idle_cps: float = 1.0 / maxf(idle_len, 0.3)
	if speed <= 0.1:
		return idle_cps
	var stride: float = stride_of(pts[pts.size() - 1][0])
	if speed < float(pts[pts.size() - 1][1]):
		for i in range(1, pts.size()):
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			if speed <= float(b[1]):
				var sa: float = stride_of(a[0]) if i > 1 else stride_of(b[0])
				var u: float = clampf((speed - float(a[1])) / maxf(float(b[1]) - float(a[1]), 0.001), 0.0, 1.0)
				stride = lerpf(sa, stride_of(b[0]), u)
				break
	return maxf(speed / maxf(stride, 0.2), idle_cps)

## Candidatos de patada de un tipo: [{clip, foot, contact, ks}] con el contacto medido del clip. charge (0..1) elige la clase de
## potencia: el pase suave con poca carga, el tiro fuerte con carga alta.
static func kick_candidates(kind: StringName, charge: float) -> Array:
	var roles: Array = []
	match kind:
		&"shot":
			roles = [&"kick_shot", &"kick_shot_hard"] if charge >= 0.45 else [&"kick_shot"]
		&"lob":
			roles = [&"kick_lob"]
		&"cross":
			# Los dos centros del banco (JOG_TO_L_45_CROSS y su version baja) tienen el contacto a 0.6 m al costado: no son
			# «limpios» pero el planificador solo los elige si el pie llega a la pelota (residuo del plan).
			roles = [&"kick_cross", &"kick_lob", &"kick_pass"]
		_:
			roles = [&"kick_pass_soft", &"kick_pass"] if charge < 0.35 else ([&"kick_pass", &"kick_shot"] if charge >= 0.8 else [&"kick_pass"])
	var key: String = String(kind) + ("+" if charge >= 0.45 else "-") + ("s" if charge < 0.35 else ("h" if charge >= 0.8 else "m"))
	if _kick_cache.has(key):
		return _kick_cache[key]
	var out: Array = []
	for r in roles:
		for id in PackLibrary.by_role(r):
			var m: Dictionary = PackLibrary.meta(id)
			# Solo golpeos con contacto medido y limpios (pie bajo delante del cuerpo, apoyo en el suelo, hacia delante).
			if kick_clip_rejection(m, r) != "":
				continue
			var c := {"clip": id, "foot": m["contact"]["foot"], "contact": m["contact"], "role": r, "mocap": bool(m.get("mocap", false))}
			# Carrera de entrada del clip (BallHandler.plan_clip_kick la compara con la del jugador en cada plan).
			if m.has("v_in"):
				c["v_in"] = float(m["v_in"])
			out.append(c)
	_kick_cache[key] = out
	return out

static var _kick_cache: Dictionary = {}

## Golpeo «limpio» (lo mide el conversor, tools/json_anim/build_json_library.gd, y lo guarda en contact.clean): punta del
## pie baja (y <= 0.3 m), delante del cuerpo (0 <= x <= 0.95 m) y a un costado razonable (|z| <= 0.5 m), pie rapido
## (>= 4 m/s), pie de apoyo apoyado (y <= 0.06 m durante los 0.1 s previos) y quieto (<= 1.2 m/s) y salida a menos de 45
## grados. Fase 2 (2026-11-07): 54 golpeos cumplen todo salvo el costado, con el contacto entre 0.50 y 0.72 m (los
## limpios llegan a 0.50). El limite lateral se amplia a KICK_LATERAL_MAX SOLO para ellos: el planificador sigue exigiendo
## que el pie llegue a la pelota (residuo tras el ajuste de zancada), asi que solo salen con la pelota a ese costado.
const KICK_LATERAL_MAX := 0.75

## Condiciones de golpeo limpio que el contacto no cumple (nombres de la tabla de la Fase 2); vacio si las cumple todas.
static func kick_clean_failures(ct: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var p: Vector3 = ct.get("pos", Vector3.ZERO)
	if p.y > 0.3:
		out.append("pie_alto")
	if p.x < 0.0:
		out.append("detras")
	if p.x > 0.95:
		out.append("lejos_delante")
	if absf(p.z) > 0.5:
		out.append("costado")
	if float(ct.get("speed", 0.0)) < 4.0:
		out.append("pie_lento")
	if float(ct.get("plant_y", 0.0)) > 0.06:
		out.append("apoyo_alto")
	if absf(float(ct.get("kick_turn", 0.0))) >= 45.0:
		out.append("giro")
	if float(ct.get("plant_slide", 0.0)) > 1.2:
		out.append("apoyo_patina")
	if not bool(ct.get("planted", true)):
		out.append("apoyo_no_plantado")
	return out

## Motivo por el que kick_candidates no ofrece un clip de golpeo de ese rol ("" si lo ofrece). Los dos centros del banco
## (kick_cross) se admiten aunque su contacto no sea limpio: el planificador exige igualmente que el pie llegue.
static func kick_clip_rejection(m: Dictionary, role: StringName) -> String:
	if not m.has("contact"):
		return "sin contacto medido (JsonCatalog.kick_candidates)"
	var ct: Dictionary = m["contact"]
	if bool(ct.get("clean", true)) or role == &"kick_cross":
		return ""
	var fails: Array[String] = kick_clean_failures(ct)
	if fails == ["costado"] and absf((ct["pos"] as Vector3).z) <= KICK_LATERAL_MAX:
		return ""
	return "contacto no limpio (JsonCatalog.kick_candidates exige clean: %s)" % (", ".join(fails) if not fails.is_empty() else "sin detalle")

## Situaciones de presentacion (AnimationCatalog.FIELD) -> roles de los clips JSON. Se elige entre TODOS los clips de esos
## roles que se pueden reproducir en el sitio (poco recorrido de raiz): festejos, lamentos, enojo, aplausos, gestos,
## calentamiento. Cada pedido toma otro clip.
const SITUATION_ROLES := {
	&"celebrate": [&"celebrate", &"clap"],
	&"celebrate_scorer": [&"celebrate_scorer", &"celebrate"],
	&"celebrate_team": [&"celebrate_team", &"clap", &"celebrate"],
	&"thumbs_up": [&"thumbs_up", &"clap", &"gesture"],
	&"dejected": [&"dejected"],
	&"angry": [&"angry", &"dejected"],
	&"frustrated": [&"angry", &"dejected"],
	&"victory_end": [&"celebrate", &"celebrate_scorer", &"celebrate_team"],
	&"defeat_end": [&"defeat_end", &"dejected"],
	&"draw_end": [&"clap", &"gesture", &"nis_idle"],
	&"warmup": [&"warmup"],
	&"idle_fidget": [&"idle_fidget", &"nis_idle", &"idle_ready"],
	&"tackle_stand": [&"tackle_stand"],
	&"press_duel": [&"jostle", &"tackle_stand"],
	&"wall": [&"wall"],
}
## Recorrido de raiz maximo (m) de un clip de presentacion (se reproduce en el sitio).
const SITUATION_ROOT_MAX := 1.0
static var _situation_cache: Dictionary = {}
static var _situation_turn: int = 0

## Clip para una situacion de presentacion (modo 4), o &"" si no hay. pick: preferencia del que lo pide (su id).
static func situation_clip(situation: StringName, pick: int) -> StringName:
	if not SITUATION_ROLES.has(situation):
		return &""
	if not _situation_cache.has(situation):
		var pool: Array[StringName] = []
		for role in SITUATION_ROLES[situation]:
			for id in AnimDB.candidates(role, {"mirrors": false, "max_root": SITUATION_ROOT_MAX, "min_duration": 0.6}):
				if not pool.has(id):
					pool.append(id)
		_situation_cache[situation] = pool
	var p: Array = _situation_cache[situation]
	if p.is_empty():
		return &""
	_situation_turn += 1
	return p[(absi(pick) * 7 + _situation_turn * 13) % p.size()]

## Vacia las listas calculadas (cambian al recargar la libreria).
static func reset_caches() -> void:
	_kick_cache = {}
	_situation_cache = {}
	_direction_cache = {}
	_gait_points_cache = {}
