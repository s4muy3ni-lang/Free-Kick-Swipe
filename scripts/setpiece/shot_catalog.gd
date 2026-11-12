class_name ShotCatalog
extends RefCounted
## Elige el golpeo (clip del banco JSON) que corresponde a un tiro, con los datos MEDIDOS de cada golpeo sobre el humano
## JSON (resources/setpiece/shot_clips.json, tools/setpiece/build_shot_catalog.gd): pie, instante de contacto, punto del
## pie en el contacto, direccion del pie al golpear respecto de la carrera, velocidad del pie y recorrido previo.
##
## La regla es la del futbol real: el tirador llega con su carrera (ángulo de aproximacion habitual para su pie) y la
## direccion del tiro respecto de esa carrera decide la tecnica. Un diestro que tira a SU DERECHA abre el cuerpo y coloca
## con el interior (o con el exterior si es potente); hacia su izquierda cruza el empeine; al centro, empeine potente. Para
## cada tiro se busca el golpeo cuyo pie sale con ese mismo angulo respecto de su carrera; despues el clip se gira para que
## el pie salga exactamente hacia el tiro y la carrera queda donde la pone el clip. Familias:
##   potente (kick_shot_hard / balon parado fuerte), normal (kick_shot / balon parado), colocado (pases de interior y
##   balon parado colocado), vaselina (kick_lob / setpiece_lob) y error (golpeos «desesperados» y fallados del banco
##   para cuando el tiro se va fuera: el pie no le da limpio).
## Entre los que encajan se reparte: cada pedido rota entre los mejores para que se vean TODOS los golpeos.

const PATH := "res://resources/setpiece/shot_clips.json"

enum Kind { POWER, NORMAL, PLACED, CHIP, MISS }

## Angulo (grados, + derecha) de la carrera habitual respecto del tiro al centro: el diestro llega desde su izquierda.
const APPROACH_DEG := 15.0

static var _clips: Array = []
## Desvio de angulo (grados) que admite la rotacion entre golpeos casi iguales respecto del mejor.
const POOL_ANGLE_SLACK := 8.0
static var _turn: int = 0

## Catalogo de la biblioteca activa (AnimBank): con MIXAMO, el medido sobre los golpeos de Mixamo (con los actuales de
## respaldo en los roles que Mixamo no tiene); si falta, el actual.
static func path() -> String:
	if AnimBank.is_mixamo() and FileAccess.file_exists(AnimBank.MIXAMO_SHOTS):
		return AnimBank.MIXAMO_SHOTS
	return PATH

## Fuerza una nueva lectura (cambio de biblioteca, pruebas).
static func reload() -> void:
	_clips = []
	_turn = 0

static func clips() -> Array:
	if _clips.is_empty():
		var f := FileAccess.open(path(), FileAccess.READ)
		if f == null:
			push_error("ShotCatalog: falta %s (generarlo con tools/setpiece/build_shot_catalog.tscn)" % path())
			return []
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_clips = (d as Dictionary).get("clips", [])
		if AnimBank.is_mixamo():
			_clips = mixamo_filter(_clips)
	return _clips

## MIXAMO: por TIPO de tiro (potente, normal, colocado, vaselina, error), si hay golpeos de Mixamo de ese tipo se usan solo
## esos; los actuales quedan para los tipos sin golpeo de Mixamo (hoy, los tiros errados: setpiece_miss). Sin esto, los 106
## pases suaves actuales taparian a los 4 pases de Mixamo en cada tiro colocado.
static func mixamo_filter(all: Array) -> Array:
	var covered := {}
	for c in all:
		if AnimBank.is_mixamo_id(StringName(String(c["id"]))):
			covered[kind_of(c)] = true
	return all.filter(func(c: Dictionary) -> bool:
		return AnimBank.is_mixamo_id(StringName(String(c["id"]))) or not covered.has(kind_of(c)))

static func entry(id: StringName) -> Dictionary:
	for c in clips():
		if String(c["id"]) == String(id):
			return c
	return {}

## Angulo (grados, + derecha) entre la carrera y el pie al golpear.
static func rel_angle(c: Dictionary) -> float:
	return wrapf(float(c["swing"]) - float(c["approach"]), -180.0, 180.0)

## Superficie del pie con que golpea: "interior", "empeine" o "exterior".
static func surface_of(c: Dictionary) -> String:
	return String(c.get("surface", "empeine"))

## Superficie que corresponde a un tiro: colocar = interior; potente = empeine; normal = interior al lado abierto y empeine
## al cruzado; con efecto = interior si la pelota se cierra hacia el lado contrario al pie (comba natural) y exterior si se
## abre hacia el lado del pie (trivela). lateral_spin + = la pelota se cierra hacia la izquierda.
static func surface_for(kind: int, foot: int, open_side: bool, curled: bool, lateral_spin: float) -> String:
	if kind == Kind.CHIP or kind == Kind.MISS:
		return ""
	if curled and absf(lateral_spin) > 1.0:
		return "interior" if lateral_spin * float(foot) > 0.0 else "exterior"
	match kind:
		Kind.PLACED:
			return "interior"
		Kind.POWER:
			return "empeine"
	return "interior" if open_side else "empeine"

static func is_desperate(c: Dictionary) -> bool:
	return String(c.get("source", "")).contains("desperate") or (c.get("tags", []) as Array).has("KICKDESPERATE")

## Familia a la que pertenece un golpeo medido.
static func kind_of(c: Dictionary) -> int:
	var role: String = String(c["role"])
	if role == "setpiece_miss" or is_desperate(c):
		return Kind.MISS
	if role in ["kick_lob", "setpiece_lob"]:
		return Kind.CHIP
	if role in ["kick_pass", "kick_pass_soft", "setpiece_pass"]:
		return Kind.PLACED
	if role == "kick_shot_hard" or String(c.get("power", "")) == "hard":
		return Kind.POWER
	return Kind.NORMAL

## Familias aceptables para un tipo de tiro (la primera es la ideal) y su costo extra.
static func _kind_cost(want: int, have: int) -> float:
	if want == have:
		return 0.0
	match want:
		Kind.POWER:
			return 0.95 if have == Kind.NORMAL else INF
		Kind.NORMAL:
			return 0.5 if have in [Kind.POWER, Kind.PLACED] else INF
		Kind.PLACED:
			return 0.6 if have == Kind.NORMAL else INF
		Kind.CHIP:
			return 1.2 if have == Kind.PLACED else INF
		Kind.MISS:
			return 0.9 if have in [Kind.POWER, Kind.NORMAL] else INF
	return INF

## Elige el golpeo. foot: 1 derecho, -1 izquierdo. shot_rel_deg: angulo (+ derecha) del tiro respecto de la carrera
## habitual del pie (ver approach_dir). set_piece: preferir golpeos de balon parado (carrera desde parado).
## Devuelve la entrada del catalogo o {}.
## surface: superficie del pie pedida ("interior", "empeine", "exterior" o "" sin preferencia), medida en cada golpeo con
## la orientacion del pie en el contacto (tools/setpiece/build_shot_catalog.gd).
static func choose(foot: int, shot_rel_deg: float, kind: int, set_piece: bool, rng: RandomNumberGenerator = null,
		ball_speed: float = -1.0, prefer_short: bool = false, curled: bool = false, surface: String = "") -> Dictionary:
	var scored: Array = []
	for c in clips():
		if int(c["foot"]) != foot:
			continue
		var kc: float = _kind_cost(kind, kind_of(c))
		if kc == INF:
			continue
		var rel: float = rel_angle(c)
		var cost: float = absf(rel - shot_rel_deg) / 12.0 + kc
		var role: String = String(c["role"])
		var sp: bool = role.begins_with("setpiece")
		if set_piece and not sp:
			cost += 0.35
		if not bool(c.get("clean", true)):
			cost += 0.25 if kind != Kind.MISS else 0.0
		# Golpeos con poca carrera previa obligan a trotar mas antes de llegar: un poco menos naturales en balon parado.
		if set_piece and float(c["run"]) < 0.6 and not prefer_short:
			cost += 0.3
		# El pie tiene que ir a la velocidad que pide el tiro (la pelota sale a ~1,25-1,6 veces la velocidad del pie).
		if ball_speed > 0.0:
			var fs: float = float(c["foot_speed"])
			var ratio: float = 1.2 if kind == Kind.PLACED else 1.5
			cost += absf(fs * ratio - ball_speed) / 7.0
		# Tiro rapido de corta distancia: golpeo seco, casi sin carrera.
		if prefer_short:
			cost += clampf((float(c["run"]) - 0.8) * 0.35, 0.0, 1.0)
		# Con efecto: los golpeos de tiro libre «curled».
		if curled and not (c.get("tags", []) as Array).has("CURLED"):
			cost += 0.2
		# Superficie del pie: la que pide el tiro (interior para colocar, empeine para pegarle fuerte, exterior para la comba
		# hacia fuera); si no hay golpeo de esa superficie con ese angulo, otro (no bloquea el tiro).
		if surface != "" and surface_of(c) != surface:
			cost += 0.9
		scored.append([cost, c, absf(rel - shot_rel_deg)])
	if scored.is_empty():
		return {}
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var best: float = float(scored[0][0])
	# Rotacion entre los casi mejores, pero sin alejarse del angulo del mejor: antes, con un tiro potente muy cruzado, entraba
	# un golpeo potente 19 grados desviado (el pie salia hacia otro lado que la pelota).
	var best_err: float = float(scored[0][2])
	var pool: Array = []
	for s in scored:
		if float(s[0]) <= best + 0.45 and float(s[2]) <= maxf(best_err + POOL_ANGLE_SLACK, POOL_ANGLE_SLACK) and pool.size() < 6:
			pool.append(s[1])
	_turn += 1
	var pick: int = (rng.randi() if rng != null else _turn) % pool.size()
	return pool[pick]

## Direccion de la carrera habitual del pie para tirar hacia `aim` (unit. horizontal): el diestro llega desde su izquierda.
static func approach_dir(aim: Vector3, foot: int) -> Vector3:
	# rotated() gira hacia la izquierda con angulo positivo; la derecha del tirador es +Z cuando mira a +X.
	return aim.rotated(Vector3.UP, -deg_to_rad(APPROACH_DEG) * float(foot))

## Angulo (grados, + derecha) de `shot` respecto de `approach` (direcciones horizontales).
static func signed_deg(approach: Vector3, shot: Vector3) -> float:
	var a: float = atan2(approach.z, approach.x)
	var b: float = atan2(shot.z, shot.x)
	return rad_to_deg(wrapf(b - a, -PI, PI))

## Marco del clip (origen, mirada) para que el pie llegue a la pelota en `ball` y salga hacia `shot` (horizontal).
static func frame_for_shot(c: Dictionary, ball: Vector3, shot: Vector3) -> Array:
	var swing: float = deg_to_rad(float(c["swing"]))
	var sa: float = atan2(shot.z, shot.x)
	var fa: float = sa - swing
	var f := Vector3(cos(fa), 0.0, sin(fa))
	var r := SpClips.right_of(f)
	var o: Vector3 = Vector3(ball.x, 0.0, ball.z) - f * float(c["cx"]) - r * float(c["cz"])
	return [o, f]

## Instante del clip (antes del contacto, con al menos min_lead s de carrera) en que la raiz pasa mas cerca de `pos` (donde
## espera el tirador): el tirador trota desde su lugar hasta ese punto y entra al clip ahi. frame = frame_for_shot.
static func start_time_near(c: Dictionary, frame: Array, pos: Vector3, min_lead: float = 0.55) -> float:
	var tc: float = float(c["tc"])
	var o: Vector3 = frame[0]
	var f: Vector3 = frame[1]
	var r: Vector3 = SpClips.right_of(f)
	var best_t: float = 0.0
	var best_d: float = INF
	for row in c.get("roots", []):
		var t: float = float(row[0])
		if t > tc - min_lead:
			break
		var w: Vector3 = o + f * float(row[1]) + r * float(row[2])
		var d: float = Vector2(w.x - pos.x, w.z - pos.z).length()
		if d < best_d:
			best_d = d
			best_t = t
	return best_t
