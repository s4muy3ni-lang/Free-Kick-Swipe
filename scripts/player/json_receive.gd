class_name JsonReceive
extends RefCounted
## Modo 4 (Json): recepcion y control de una pelota que llega (rasante, con bote, a media altura o bajando de un globo) con
## los clips de recepcion de los datos. No es un gesto despues del toque: el clip se elige ANTES de que llegue la pelota
## para que la parte del cuerpo de su PRIMER contacto real (pie, pie en el aire, muslo, rodilla, pecho) este en la pelota en
## el instante de ese contacto.
##
## - Perfiles (ReceiveProfiles, generados por tools/json_anim/make_receive_profiles.py con la auditoria de F3): parte del
##   cuerpo, instante del primer contacto (estimado por cinematica o verificado a ojo; NO el primer `ball_touches`, que puede
##   ser un toque de pie posterior, ni `key_frame`), estado (usable / conditional / pending / not_reception), condiciones,
##   pase o golpeo posterior y direccion de llegada del nombre (con el lado invertido: los datos estan en espejo respecto
##   de los nombres). Solo entran en la seleccion automatica los `usable` y los `conditional` cuyas condiciones se cumplen;
##   los 70 `pending` esperan su verificacion visual.
## - Punto de contacto: cinematica directa del clip sobre el esqueleto canonico (JsonRig) en el instante del contacto, mas
##   la raiz y el rumbo del clip (contact_point; reproduce `ball_touches` a ~3 mm).
## - Planificacion (plan): trayectoria 3D de la pelota (BallPredictor: gravedad, arrastre, bote y rodadura); para cada clip y
##   cada inicio (0-0.3 s), distancia entre el punto de contacto y la pelota prevista, en el suelo (corrige el paso hasta
##   0.4 m) y en altura (tolerancia por parte); carrera de entrada y de salida; direccion de llegada; orientacion de salida
##   (joystick); la pelota no choca con el cuerpo antes de tiempo. Mientras la pelota esta lejos o alta se vuelve a
##   planificar cada pocos pasos (el bote baja la pelota a otra parte del cuerpo); si ningun clip llega, el control fisico.
## - Ejecucion: movimiento con pelota de JsonBallMove (intencion &"receive", accion &"ball_move", nivel BALL_MOVE del
##   arbitro). La pelota no cambia hasta el contacto; entonces recibe UN impulso segun la parte (contact_velocity). Los toques
##   de pie posteriores del clip solo se aplican si la pelota esta ahi; si no llega, el clip se corta. Un pase o golpeo
##   posterior del clip no se reproduce como impulso: el clip se corta antes y golpea el sistema de pase/tiro real.

## Roles del catalogo con recepciones y controles (124 clips mas sus espejos).
const ROLES: Array[StringName] = [&"receive", &"receive_turn", &"control_stand", &"ball_start", &"jostle_ball", &"receive_foot"]
## Partes del cuerpo con respuesta fisica propia. La cabeza solo con un clip verificado (hoy ninguno).
const PARTS: Array[StringName] = [&"foot", &"foot_air", &"thigh", &"knee", &"chest"]
## Velocidad (m/s) horizontal minima con que la pelota se acerca, distancia (m) maxima y altura (m) maxima para planificar.
const MIN_CLOSING := 1.0
const MAX_DIST := 12.0
const MAX_BALL_Y := 2.6
## Espera (s) entre el inicio del clip y el contacto: minima (que se vea el gesto) y maxima.
const MIN_LEAD := 0.15
const MAX_LEAD := 1.0
## Inicios del clip que se prueban (s).
const START_OFFSETS: Array[float] = [0.0, 0.1, 0.2, 0.3]
## Horizonte (s) y paso de la trayectoria prevista.
const HORIZON := 1.4
const TRAJ_STEP := 1.0 / 30.0
## Diferencia maxima (m/s) entre la carrera de entrada del clip y la del jugador; con joystick, tambien la de salida.
const MAX_DV := 1.2
## Sin joystick nadie pidio ir a ninguna parte: sale casi parado (m/s) y gira poco (grados).
const STILL_OUT := 1.2
const STILL_TURN := 60.0
## Joystick minimo para orientar el control, y tolerancia (grados) entre el rumbo de salida del clip y el joystick.
const MIN_STICK := 0.35
const TURN_TOL := 50.0
## Tolerancia (grados) entre la direccion de llegada real y la del nombre del clip.
const DIR_TOL := 60.0
## Pie: el pie va hacia la pelota, no la espera de espaldas (grados). Pecho, muslo, rodilla: la pelota llega por delante.
const MAX_APPROACH := 110.0
const MAX_FRONT := 100.0
## Distancia (m) minima entre la pelota y el centro del cuerpo antes de la ventana de contacto (capsula 0.3 + pelota 0.11 +
## holgura); dentro de la ventana el cuerpo es fantasma (la capsula es mas ancha que las piernas).
const BODY_CLEAR := 0.44
## Error (m) maximo en el suelo (lo cubre el pie con TouchFootIK o el gesto) y en altura, por parte del cuerpo.
const PART_SLACK := {&"foot": 0.1, &"foot_air": 0.1, &"thigh": 0.12, &"knee": 0.12, &"chest": 0.14}
const PART_VTOL := {&"foot": 0.08, &"foot_air": 0.12, &"thigh": 0.12, &"knee": 0.12, &"chest": 0.15}
## Control protegiendo la pelota (forcejeo): solo con un rival a menos de JOSTLE_RIVAL m.
const JOSTLE_RIVAL := 2.5
## Fraccion de lo que el pie (a ras de piso) no amortigua que vuelve como rebote.
const REBOUND := 0.6
## Escala del modelo del modo Json (1.0 de alto = 1.75 m).
const MODEL_SCALE := 1.75
## Ventana de contacto (s antes y despues del instante estimado): el contacto se da cuando la pelota llega a la parte del
## cuerpo animada dentro de ella, a menos de su radio mas PART_REACH m (tamano de esa parte).
const CONTACT_EARLY := 0.12
const CONTACT_LATE := 0.25
const PART_REACH := {&"foot": 0.07, &"foot_air": 0.08, &"thigh": 0.1, &"knee": 0.08, &"chest": 0.14}
## Anticipacion: desplazamiento (m) maximo hasta donde un clip compatible encajaria mas adelante, instantes de inicio que se
## prueban (s desde ahora) y velocidad (m/s) con que se puede llegar.
const APPROACH_MAX := 2.5
const APPROACH_STARTS: Array[float] = [0.15, 0.3, 0.45, 0.6, 0.8]
const APPROACH_SPEED := 4.0
const APPROACH_EVERY := 4
## Desvio (m) maximo de la pelota real respecto de la trayectoria prevista antes del contacto: mas, la recepcion se corta y
## actua el control fisico (pelota desviada, frenada o que patina).
const TRAJ_DRIFT := 0.35
## Diferencia (m/s) maxima entre la velocidad real de la pelota y la prevista antes del contacto (una pelota que patina frena
## mucho mas que la rodadura prevista: se nota antes en la velocidad que en la posicion).
const TRAJ_DV := 1.0
## Penalizacion (en la misma escala que el error en metros) de un clip con el contacto solo estimado frente a uno verificado.
const UNVERIFIED_PENALTY := 0.04
## Pasos de fisica entre intentos de planificar y segundos sin planificar tras una recepcion.
const PLAN_EVERY := 2
const COOLDOWN := 0.4

var handler: BallHandler
## Traza (AnimTrace, solo depuracion): decision en curso de plan y candidato que se esta examinando.
var _trace_dec: Dictionary = {}
var _trace_id: StringName = &""
var _plan_tick: int = 0
var _cooldown: float = 0.0
var stats := {"planned": 0, "started": 0, "contact": 0, "missed": 0, "aborted": 0, "no_clip": 0}
## Ultimo plan elegido, ultimo contacto y motivos de descarte (diagnostico y pruebas).
var last_plan: Dictionary = {}
var last_contact: Dictionary = {}
var rejects: Dictionary = {}
## Donde deberia estar el cuerpo para que un clip compatible encaje con la pelota mas adelante (Vector3.INF = ninguno), y
## pasos de fisica que le quedan de validez. Lo usa Footballer para llevar al receptor (anticipacion).
var approach: Vector3 = Vector3.INF
## Frente del cuerpo con el que se calculo `approach`: el sitio solo vale si el receptor llega mirando igual (Footballer lo
## mantiene mientras se coloca).
var approach_face: Vector3 = Vector3.ZERO
var _approach_ttl: int = 0

func _init(h: BallHandler) -> void:
	handler = h

# --- Perfiles ---------------------------------------------------------------------------------------------------------

## Perfil de contacto del clip (el espejo usa el del original con la direccion de llegada y el giro cambiados de signo).
## {} si el clip no es de recepcion.
static func profile(id: StringName) -> Dictionary:
	var base: String = String(id)
	var mirror: bool = base.ends_with("_mirror")
	if mirror:
		base = base.trim_suffix("_mirror")
	var p: Dictionary = ReceiveProfiles.PROFILES.get(StringName(base), {})
	if p.is_empty() or not mirror:
		return p
	var q: Dictionary = p.duplicate()
	if q["from_deg"] != null:
		q["from_deg"] = -float(q["from_deg"])
	q["turn"] = -float(q["turn"])
	return q

## El perfil entra en la seleccion automatica: usable o con condiciones, con instante de contacto y parte con fisica propia.
static func selectable(p: Dictionary) -> bool:
	return (p.get("status", "") == "usable" or p.get("status", "") == "conditional") and float(p.get("t", -1.0)) > 0.0 \
		and PARTS.has(StringName(p.get("part", "")))

static var _rest: Array[Transform3D] = []
static var _point_cache: Dictionary = {}
static var _track_map: Dictionary = {}

## Huesos del clip en el instante t (transformaciones globales del esqueleto canonico, unidades del modelo).
static func _pose(a: Animation, t: float) -> Array[Transform3D]:
	if _rest.is_empty():
		var sk: Skeleton3D = JsonRig.build_skeleton()
		for i in sk.get_bone_count():
			_rest.append(sk.get_bone_rest(i))
		sk.free()
	var n: int = JsonRig.BONES.size()
	var local: Array[Transform3D] = _rest.duplicate()
	# Hueso de cada pista: se busca una vez por clip (antes, una busqueda de texto por pista en cada pose).
	var key: int = a.get_instance_id()
	var tm: PackedInt32Array = _track_map.get(key, PackedInt32Array())
	if tm.size() != a.get_track_count():
		tm = PackedInt32Array()
		tm.resize(a.get_track_count())
		for i in a.get_track_count():
			tm[i] = JsonRig.BONES.find(String(a.track_get_path(i)).get_slice(":", 1))
		_track_map[key] = tm
	for i in a.get_track_count():
		var bi: int = tm[i]
		if bi < 0:
			continue
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			local[bi] = Transform3D(Basis(a.rotation_track_interpolate(i, t)), local[bi].origin)
		elif a.track_get_type(i) == Animation.TYPE_POSITION_3D:
			local[bi] = Transform3D(local[bi].basis, a.position_track_interpolate(i, t))
	var glob: Array[Transform3D] = []
	glob.resize(n)
	for i in n:
		var par: int = JsonRig.PARENTS[i]
		glob[i] = local[i] if par < 0 else glob[par] * local[i]
	return glob

static func _bone(g: Array[Transform3D], name: String) -> Vector3:
	return g[JsonRig.BONES.find(name)].origin * MODEL_SCALE

## Punto de contacto de la parte del cuerpo en el instante del contacto, en el marco del cuerpo en ese instante (metros;
## x adelante, y arriba, z derecha), y el pie (+1 derecho, -1 izquierdo, 0 sin pie): pie = entre tobillo y punta del pie que
## se mueve; muslo = encima de la mitad del muslo levantado; rodilla = delante de la rodilla levantada; pecho = delante del
## pecho. Se calcula una vez por clip.
static func contact_point(id: StringName, part: StringName, t: float) -> Dictionary:
	if _point_cache.has(id):
		return _point_cache[id]
	var a: Animation = PackLibrary.clip(id)
	if a == null:
		return {}
	var g: Array[Transform3D] = _pose(a, t)
	var out := {}
	match part:
		&"foot", &"foot_air":
			var tl: Vector3 = _bone(g, "mixamorig_LeftToeBase")
			var tr: Vector3 = _bone(g, "mixamorig_RightToeBase")
			var right: bool = tr.y > tl.y + 0.01 or (absf(tr.y - tl.y) <= 0.01 and tr.x > tl.x)
			var toe: Vector3 = tr if right else tl
			var ank: Vector3 = _bone(g, "mixamorig_RightFoot" if right else "mixamorig_LeftFoot")
			out = {"point": toe * 0.6 + ank * 0.4, "foot": 1 if right else -1, "t": t}
		&"thigh", &"knee":
			var kl: Vector3 = _bone(g, "mixamorig_LeftLeg")
			var kr: Vector3 = _bone(g, "mixamorig_RightLeg")
			var right2: bool = kr.y > kl.y
			var knee: Vector3 = kr if right2 else kl
			if part == &"thigh":
				var hip: Vector3 = _bone(g, "mixamorig_RightUpLeg" if right2 else "mixamorig_LeftUpLeg")
				out = {"point": (hip + knee) * 0.5 + Vector3(0.0, 0.07, 0.0), "foot": 0, "t": t}
			else:
				out = {"point": knee + Vector3(0.06, 0.03, 0.0), "foot": 0, "t": t}
		&"chest":
			out = {"point": _bone(g, "mixamorig_Spine2") + Vector3(0.14, 0.05, 0.0), "foot": 0, "t": t}
		&"head":
			out = {"point": _bone(g, "mixamorig_Head") + Vector3(0.08, 0.1, 0.0), "foot": 0, "t": t}
	# Trayectoria de esa misma parte del cuerpo alrededor del contacto (marco del cuerpo en cada instante): el contacto se
	# da cuando la pelota y la parte del cuerpo animada se encuentran de verdad (JsonBallMove), no en un instante fijo.
	if not out.is_empty():
		var t0: float = maxf(float(out["t"]) - CONTACT_EARLY, 0.0)
		var t_end: float = minf(float(out["t"]) + CONTACT_LATE, a.length)
		var path := PackedVector3Array()
		var tt2: float = t0
		while tt2 <= t_end:
			path.append(_part_point(_pose(a, tt2), part, int(out["foot"]), out["point"]))
			tt2 += 1.0 / 30.0
		out["path_t0"] = t0
		out["path"] = path
	_point_cache[id] = out
	return out

## Punto de la parte del cuerpo en una pose (mismo criterio que contact_point; el pie y la pierna ya elegidos).
static func _part_point(g: Array[Transform3D], part: StringName, foot: int, ref: Vector3) -> Vector3:
	match part:
		&"foot", &"foot_air":
			var right: bool = foot > 0
			return _bone(g, "mixamorig_RightToeBase" if right else "mixamorig_LeftToeBase") * 0.6 + _bone(g, "mixamorig_RightFoot" if right else "mixamorig_LeftFoot") * 0.4
		&"thigh", &"knee":
			var kl: Vector3 = _bone(g, "mixamorig_LeftLeg")
			var kr: Vector3 = _bone(g, "mixamorig_RightLeg")
			var right2: bool = ref.z > 0.0
			var knee: Vector3 = kr if right2 else kl
			if part == &"thigh":
				return (_bone(g, "mixamorig_RightUpLeg" if right2 else "mixamorig_LeftUpLeg") + knee) * 0.5 + Vector3(0.0, 0.07, 0.0)
			return knee + Vector3(0.06, 0.03, 0.0)
		&"chest":
			return _bone(g, "mixamorig_Spine2") + Vector3(0.14, 0.05, 0.0)
	return _bone(g, "mixamorig_Head") + Vector3(0.08, 0.1, 0.0)

## Punto de la parte del cuerpo a `clip_t` en el marco del cuerpo (interpolado en la trayectoria de contact_point), o
## Vector3.INF fuera de la ventana de contacto.
static func path_point(cp: Dictionary, clip_t: float) -> Vector3:
	var path: PackedVector3Array = cp.get("path", PackedVector3Array())
	if path.size() < 2:
		return Vector3.INF
	var x: float = (clip_t - float(cp["path_t0"])) * 30.0
	if x < 0.0 or x > float(path.size() - 1):
		return Vector3.INF
	var i: int = mini(int(x), path.size() - 2)
	return path[i].lerp(path[i + 1], x - float(i))

# --- Candidatos (cache) -----------------------------------------------------------------------------------------------

## Clips de recepcion seleccionables con todo lo que no depende de la jugada (perfil, meta, punto y trayectoria del
## contacto, raiz y rumbo del clip), en el orden de ROLES y de la libreria: el mismo en que los recorria plan, porque el
## desempate aleatorio del puntaje consume el generador en ese orden (la eleccion no cambia). Antes plan buscaba perfil y
## meta y copiaba el perfil de cada espejo en CADA paso para ~190 clips y para cada jugador que veia venir la pelota, y el
## primer uso de cada clip calculaba su pose: 10-60 ms en una sola imagen en un pase disputado (tools/perf_probe,
## 2026-11-05). Se calcula una vez por libreria (warm_cache al cargar el partido; reset_caches al cambiar de modo).
static var _cands: Array = []
static var _cands_built: bool = false
## Distancia horizontal maxima (m) del cuerpo al empezar el clip al punto de contacto, entre todos los candidatos y los
## inicios START_OFFSETS (plan), y del cuerpo al contacto sin el inicio (anticipacion): si la pelota prevista no pasa a esa
## distancia (mas la correccion del paso y la holgura) en la ventana de contacto, ningun clip llega y no se recorre ninguno.
static var _reach_bound: float = 0.0
static var _approach_bound: float = 0.0
## Guardar los motivos de descarte (rejects) solo para la vista de depuracion (tools/json_anim/receive_view).
static var record_rejects: bool = false

static func reset_caches() -> void:
	_cands = []
	_cands_built = false
	_reach_bound = 0.0
	_approach_bound = 0.0
	_point_cache = {}
	_track_map = {}

## Calcula los candidatos (y la pose del contacto de cada clip) si aun no estan. MatchScene la llama al cargar el partido.
static func warm_cache() -> void:
	if _cands_built:
		return
	_cands_built = true
	_cands = []
	_reach_bound = 0.0
	_approach_bound = 0.0
	for role in ROLES:
		for id in PackLibrary.by_role(role):
			var p: Dictionary = profile(id)
			if p.is_empty() or not selectable(p):
				continue
			var part: StringName = StringName(p["part"])
			var cp: Dictionary = contact_point(id, part, float(p["t"]))
			if cp.is_empty():
				continue
			var m: Dictionary = PackLibrary.meta(id)
			var conds: Array = p["conds"]
			var t1: float = float(cp["t"])
			var lp: Vector3 = cp["point"]
			# El cuerpo solo gira con el rumbo del clip si el juego se lo aplica (ActionMotion: heading_mode «turn»).
			var hp: PackedFloat32Array = m.get("heading_path", PackedFloat32Array()) if String(m.get("heading_mode", "")) == "turn" else PackedFloat32Array()
			var rp: PackedVector2Array = m.get("root_path", PackedVector2Array())
			var rc: Vector2 = ActionMotion._at(rp, t1) if rp.size() >= 2 else Vector2.ZERO
			var hd: float = ActionMotion.heading_rel(hp, t1)
			var hs := PackedFloat32Array()
			var rs := PackedVector2Array()
			var lp_h: float = Vector2(lp.x, lp.z).length()
			var reach: float = 0.0
			for start_at in START_OFFSETS:
				hs.append(ActionMotion.heading_rel(hp, start_at))
				var r_s: Vector2 = ActionMotion._at(rp, start_at) if rp.size() >= 2 else Vector2.ZERO
				rs.append(r_s)
				reach = maxf(reach, (rc - r_s).length())
			_reach_bound = maxf(_reach_bound, reach + lp_h)
			_approach_bound = maxf(_approach_bound, rc.length() + lp_h)
			_cands.append({"id": id, "role": role, "p": p, "part": part, "cp": cp, "t1": t1, "lp": lp, "hp": hp, "rp": rp,
				"rc": rc, "hd": hd, "hs": hs, "rs": rs,
				"rival": conds.has("rival"), "post_action": conds.has("post_action"),
				"stick": conds.has("stick_turn") or conds.has("stick_out"),
				"v_in": float(m.get("v_in", 0.0)), "v_out": float(m.get("v_out", 0.0)),
				"turn_end": ActionMotion.heading_rel(hp, float(m.get("duration", 1.0))),
				"slack": float(PART_SLACK[part]), "vtol": float(PART_VTOL[part]),
				"contact_local": _local_point(rc, hd, lp)})

## true si el clip esta entre los candidatos de recepcion (perfil seleccionable y punto de contacto calculable): el mismo
## conjunto que recorre plan. Lo usa el diagnostico (AnimTrace.explain).
static func is_candidate(id: StringName) -> bool:
	warm_cache()
	for c in _cands:
		if c["id"] == id:
			return true
	return false

## Distancia horizontal minima (m) de `pos` a la trayectoria prevista entre `t_from` y `t_to` s (tramos interpolados como _at).
static func _min_dist(traj: PackedVector3Array, pos: Vector3, t_from: float, t_to: float) -> float:
	var last: int = traj.size() - 1
	var i0: int = clampi(int(floor(t_from / TRAJ_STEP)), 0, last)
	var i1: int = clampi(int(ceil(t_to / TRAJ_STEP)), 0, last)
	var p := Vector2(pos.x, pos.z)
	var best: float = INF
	for i in range(i0, maxi(i1, i0 + 1)):
		var a := Vector2(traj[i].x, traj[i].z)
		var bb := Vector2(traj[mini(i + 1, last)].x, traj[mini(i + 1, last)].z)
		var ab: Vector2 = bb - a
		var k: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0) if ab.length_squared() > 1e-8 else 0.0
		best = minf(best, p.distance_to(a + ab * k))
	return best

# --- Decision ---------------------------------------------------------------------------------------------------------

## Paso de fisica (BallHandler.update, modo 4): si llega una pelota y algun clip la recibe, empieza la recepcion.
func consider(desired_dir: Vector3, stick_mag: float, dt: float) -> bool:
	_cooldown = maxf(_cooldown - dt, 0.0)
	_approach_ttl -= 1
	if _approach_ttl <= 0:
		approach = Vector3.INF
	if not PackLibrary.json_mode() or handler.json_move.active or _cooldown > 0.0:
		return false
	if not _ball_incoming():
		approach = Vector3.INF
		return false
	_plan_tick += 1
	if _plan_tick % PLAN_EVERY != 0:
		return false
	_trace_dec = AnimTrace.begin(handler.owner, &"receive", &"JsonReceive.plan", "pelota que llega") if AnimTrace.enabled else {}
	var plan: Dictionary = plan(desired_dir, stick_mag)
	if not _trace_dec.is_empty() and plan.is_empty():
		AnimTrace.commit(_trace_dec, &"", {}, "rejected", String(_trace_dec.get("reason", "ningun clip de recepcion llega")))
		_trace_dec = {}
	if plan.is_empty():
		stats["no_clip"] += 1
		if _plan_tick % APPROACH_EVERY == 0:
			_update_approach(desired_dir, stick_mag)
		return false
	approach = Vector3.INF
	stats["planned"] += 1
	var started: bool = handler.json_move.start_receive(plan)
	if not _trace_dec.is_empty():
		AnimTrace.commit(_trace_dec, plan["clip"], {}, "accepted" if started else "rejected", "" if started else "arbitro o clip no reproducible")
		_trace_dec = {}
	if not started:
		return false
	stats["started"] += 1
	last_plan = plan
	return true

## La pelota viene hacia el jugador, suelta (rodando o por el aire), y el jugador puede recibirla ahora (sin golpeo pedido ni
## accion de igual o mas nivel en el arbitro).
func _ball_incoming() -> bool:
	var owner: Footballer = handler.owner
	if owner.actions == null or not owner.actions.can_start(&"ball_move") or not owner.actions._can_play():
		return false
	# (No se mira has_possession: es solo cercania y ya es cierta para una pelota que esta llegando.)
	if handler.is_kick_in_progress() or handler._pending_action != &"" or handler.control_cooldown > 0.0:
		return false
	var b: Ball = handler.ball()
	if b == null or b.is_held() or owner.ctx == null or owner.ctx.ball_locked_for(owner) or b.global_position.y > MAX_BALL_Y:
		return false
	if handler.ball_owned_by_other():
		return false
	if b.last_toucher == owner and float(Engine.get_physics_frames() - b.last_touch_frame) / float(Engine.physics_ticks_per_second) < BallHandler.OWN_TOUCH_NO_CONTROL_SECONDS:
		return false
	var last: Footballer = b.last_toucher as Footballer
	if last != null and last != owner and KickModel.flat(last.global_position - b.global_position).length() < 1.5:
		return false
	var off: Vector3 = KickModel.flat(b.global_position - owner.global_position)
	var dist: float = off.length()
	if dist > MAX_DIST or dist < 0.2:
		return false
	var rel_v: Vector3 = KickModel.flat(b.linear_velocity - owner.velocity)
	return -rel_v.dot(off / dist) >= MIN_CLOSING

## Posicion de la pelota prevista a `t` s (interpolada en la trayectoria).
static func _at(traj: PackedVector3Array, t: float) -> Vector3:
	var x: float = clampf(t / TRAJ_STEP, 0.0, float(traj.size() - 1))
	var i: int = mini(int(x), traj.size() - 2)
	return traj[i].lerp(traj[i + 1], x - float(i))

## Elige clip, inicio y correccion de paso para que la parte del cuerpo del primer contacto este en la pelota cuando llega.
## {} si ninguno llega.
func plan(desired_dir: Vector3, stick_mag: float) -> Dictionary:
	var owner: Footballer = handler.owner
	var loco: Locomotion = owner.locomotion
	var b: Ball = handler.ball()
	var pos: Vector3 = KickModel.flat(owner.global_position)
	var traj: PackedVector3Array = BallPredictor.trajectory(b.global_position, b.linear_velocity, HORIZON, TRAJ_STEP, b.angular_velocity)
	if traj.size() < 3:
		return {}
	var has_dir: bool = stick_mag >= MIN_STICK and desired_dir.length_squared() > 0.01
	var want: Vector3 = KickModel.flat(desired_dir).normalized() if has_dir else Vector3.ZERO
	var charging: bool = handler._pass_active or handler._shoot_active or handler._through_active or handler._cross_active
	var rival_near: bool = _rival_within(JOSTLE_RIVAL)
	var best: Dictionary = {}
	var best_score: float = INF
	warm_cache()
	# Ningun clip llega si la pelota no pasa cerca en la ventana de contacto (cota de warm_cache): mismo resultado, sin recorrido.
	if _min_dist(traj, pos, MIN_LEAD, MAX_LEAD) > _reach_bound + b.radius + 0.02 + JsonBallMove.CORR_MAX + 0.15:
		_reject("pelota lejos en la ventana de contacto")
		return {}
	for c in _cands:
		var p: Dictionary = c["p"]
		var id: StringName = c["id"]
		var role: StringName = c["role"]
		_trace_id = id
		if c["rival"] and not rival_near:
			_reject("sin rival para el control protegiendo")
			continue
		if c["post_action"] and not charging:
			_reject("accion posterior sin orden de golpeo")
			continue
		if charging and not c["post_action"]:
			_reject("cargando un golpeo: de primera o recepcion con accion posterior")
			continue
		if c["stick"] and not has_dir:
			_reject("giro o salida sin joystick")
			continue
		var dv: float = absf(float(c["v_in"]) - loco.speed)
		if dv > MAX_DV:
			_reject("carrera de entrada")
			continue
		var v_out: float = float(c["v_out"])
		var dv_out: float = absf(v_out - loco.speed) if has_dir else 0.0
		if has_dir and loco.speed > 1.0 and v_out < loco.speed - MAX_DV:
			_reject("carrera de salida")
			continue
		if not has_dir and v_out > STILL_OUT:
			_reject("sale andando sin joystick")
			continue
		var part: StringName = c["part"]
		var cp: Dictionary = c["cp"]
		var t1: float = float(c["t1"])
		var lp: Vector3 = c["lp"]
		var rp: PackedVector2Array = c["rp"]
		var turn_end: float = float(c["turn_end"])
		var rc: Vector2 = c["rc"]
		var hd: float = float(c["hd"])
		var hs: PackedFloat32Array = c["hs"]
		var rss: PackedVector2Array = c["rs"]
		for si in START_OFFSETS.size():
			var start_at: float = START_OFFSETS[si]
			var dt1: float = t1 - start_at
			if dt1 < MIN_LEAD:
				break
			if dt1 > MAX_LEAD:
				_reject("contacto lejano")
				continue
			var yaw0: float = loco.yaw - hs[si]
			var exit_dir: Vector3 = Locomotion.dir_from_yaw(yaw0 + turn_end)
			var dturn: float = KickModel.angle_between_deg(exit_dir, want) if has_dir else absf(rad_to_deg(turn_end))
			if (has_dir and dturn > TURN_TOL) or (not has_dir and dturn > STILL_TURN):
				_reject("orientacion")
				continue
			var f0: Vector3 = Locomotion.dir_from_yaw(yaw0)
			var r0 := Vector3(-f0.z, 0.0, f0.x)
			var rs: Vector2 = rss[si]
			var origin: Vector3 = pos - f0 * rs.x - r0 * rs.y
			var fc: Vector3 = Locomotion.dir_from_yaw(yaw0 + hd)
			var rcv := Vector3(-fc.z, 0.0, fc.x)
			var body_c: Vector3 = origin + f0 * rc.x + r0 * rc.y
			var contact: Vector3 = body_c + fc * lp.x + rcv * lp.z + Vector3(0.0, lp.y, 0.0)
			var bp: Vector3 = _at(traj, dt1)
			var bv: Vector3 = (bp - _at(traj, maxf(dt1 - TRAJ_STEP, 0.0))) / TRAJ_STEP
			if bv.length() < 0.3:
				_reject("pelota casi quieta en el contacto")
				continue
			var inc: Vector3 = bv.normalized()
			var center: Vector3 = contact + contact_offset(inc, b)
			var err: Vector3 = bp - center
			var err_h := Vector3(err.x, 0.0, err.z)
			var corr: Vector3 = err_h.limit_length(minf(JsonBallMove.CORR_MAX, JsonBallMove.CORR_SPEED * dt1))
			var residual: float = (err_h - corr).length()
			if residual > float(c["slack"]):
				_reject("parte del cuerpo lejos de la pelota")
				continue
			if absf(err.y) > float(c["vtol"]):
				_reject("altura de la pelota distinta de la del contacto")
				continue
			# Direccion de llegada (+ izquierda) respecto al frente al empezar, frente a la del nombre del clip.
			var inc_h: Vector3 = KickModel.flat(inc).normalized()
			var from_deg: float = rad_to_deg(f0.signed_angle_to(-inc_h, Vector3.UP)) if inc_h != Vector3.ZERO else 0.0
			var ddir: float = 0.0
			if p["from_deg"] != null:
				ddir = absf(rad_to_deg(wrapf(deg_to_rad(from_deg - float(p["from_deg"])), -PI, PI)))
				if ddir > DIR_TOL:
					_reject("direccion de llegada distinta de la del clip")
					continue
			var to_contact: Vector3 = KickModel.flat(contact - body_c)
			if part == &"foot" or part == &"foot_air":
				if inc_h != Vector3.ZERO and to_contact.length() > 0.05 and KickModel.angle_between_deg(-inc_h, to_contact) > MAX_APPROACH:
					_reject("pie de espaldas a la pelota")
					continue
			elif absf(from_deg) > MAX_FRONT:
				_reject("pelota por detras para pecho, muslo o rodilla")
				continue
			if not _path_clear(traj, origin, f0, r0, rp, start_at, dt1, corr, part):
				_reject("pelota cruza el cuerpo")
				continue
			var score: float = residual + 0.6 * absf(err.y) + 0.25 * corr.length() + 0.12 * (dv + dv_out) + 0.006 * dturn \
				+ 0.003 * ddir + 0.03 * start_at + handler.rng.randf() * 0.03
			# Con geometria equivalente, mejor un clip con el contacto visto con la pelota (verificado) que uno estimado.
			if p["confidence"] != "verified":
				score += UNVERIFIED_PENALTY
			if not _trace_dec.is_empty():
				AnimTrace.cand(_trace_dec, id, "", {"frame_start": int(round(start_at * AnimTrace.FRAME_RATE)), "frame_contact": int(round(t1 * AnimTrace.FRAME_RATE)),
					"body_part": String(part), "foot": "R" if int(cp["foot"]) > 0 else "L", "v_in": loco.speed, "v_clip": float(c["v_in"]),
					"orient_start": rad_to_deg(loco.yaw), "orient_target": rad_to_deg(Locomotion.yaw_from_dir(want)) if has_dir else "",
					"ball_pred_x": bp.x, "ball_pred_y": bp.y, "ball_pred_z": bp.z, "contact_point_x": center.x, "contact_point_y": center.y,
					"contact_point_z": center.z, "spatial_error_m": err.length(), "angular_error_deg": dturn, "root_correction_m": corr.length(),
					"tolerance_applied": float(c["slack"]), "tolerance_reason": "PART_SLACK[%s]" % part, "cost_total": score,
					"cost_breakdown_json": {"residuo": residual, "altura": 0.6 * absf(err.y), "correccion": 0.25 * corr.length(),
						"carrera": 0.12 * (dv + dv_out), "giro": 0.006 * dturn, "direccion": 0.003 * ddir, "inicio": 0.03 * start_at,
						"sin_verificar": UNVERIFIED_PENALTY if p["confidence"] != "verified" else 0.0}})
			if score < best_score:
				best_score = score
				var post_t: float = float(p["post_t"])
				best = {"clip": id, "start_at": start_at, "inc": inc_h, "yaw0": yaw0, "origin": origin, "corr": corr, "dt1": dt1,
					"residual": residual, "dy": err.y, "turn": rad_to_deg(turn_end), "dv": dv, "role": role, "part": part,
					"t_contact": t1, "foot": int(cp["foot"]), "cp": cp, "confidence": p["confidence"], "post_t": post_t,
					"from_deg": from_deg, "touches_after": p["touches_after"],
					"contact_local": c["contact_local"],
					"incoming_speed": (bv - owner.velocity).length(), "ball_y": bp.y, "pred_ball": bp, "pred_contact": contact + corr,
					"traj": traj, "frame": Engine.get_physics_frames()}
	_trace_id = &""
	return best

## Anticipacion: entre los clips que se podrian usar ahora (mismas condiciones que plan), donde tendria que estar el cuerpo
## para que la parte del cuerpo del contacto coincida con la pelota si el clip empezara dentro de APPROACH_STARTS s; se
## elige el mas cercano que se alcanza a tiempo. No mueve a nadie: Footballer lleva al receptor hacia `approach`.
func _update_approach(desired_dir: Vector3, stick_mag: float) -> void:
	var owner: Footballer = handler.owner
	var loco: Locomotion = owner.locomotion
	var b: Ball = handler.ball()
	var pos: Vector3 = KickModel.flat(owner.global_position)
	var traj: PackedVector3Array = BallPredictor.trajectory(b.global_position, b.linear_velocity, HORIZON + 1.0, TRAJ_STEP, b.angular_velocity)
	var has_dir: bool = stick_mag >= MIN_STICK and desired_dir.length_squared() > 0.01
	var want: Vector3 = KickModel.flat(desired_dir).normalized() if has_dir else Vector3.ZERO
	var charging: bool = handler._pass_active or handler._shoot_active or handler._through_active or handler._cross_active
	var rival_near: bool = _rival_within(JOSTLE_RIVAL)
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	warm_cache()
	# Cota de warm_cache: el sitio buscado esta a menos de APPROACH_MAX del jugador, asi que la pelota tiene que pasar a menos
	# de eso mas el alcance del clip; si no, ningun clip da sitio (mismo resultado, sin recorrido).
	var far: bool = _min_dist(traj, pos, 0.0, HORIZON + 1.0) > APPROACH_MAX + _approach_bound + b.radius + 0.05
	for c in ([] if far else _cands):
		if (c["rival"] and not rival_near) or (c["post_action"] and not charging) or (c["stick"] and not has_dir):
			continue
		# Sin frenar a nadie para recibir: la carrera de entrada del clip es la del jugador.
		if absf(float(c["v_in"]) - loco.speed) > MAX_DV or (not has_dir and float(c["v_out"]) > STILL_OUT):
			continue
		var part: StringName = c["part"]
		var t1: float = float(c["t1"])
		var lp: Vector3 = c["lp"]
		var turn_end: float = float(c["turn_end"])
		var exit_dir: Vector3 = Locomotion.dir_from_yaw(loco.yaw + turn_end)
		if (has_dir and KickModel.angle_between_deg(exit_dir, want) > TURN_TOL) or (not has_dir and absf(rad_to_deg(turn_end)) > STILL_TURN):
			continue
		var rc: Vector2 = c["rc"]
		var hd: float = float(c["hd"])
		var f0: Vector3 = Locomotion.dir_from_yaw(loco.yaw)
		var r0 := Vector3(-f0.z, 0.0, f0.x)
		var fc: Vector3 = Locomotion.dir_from_yaw(loco.yaw + hd)
		var rcv := Vector3(-fc.z, 0.0, fc.x)
		# Del cuerpo al empezar hasta el punto de contacto (en el suelo) y su altura.
		var rel: Vector3 = f0 * rc.x + r0 * rc.y + fc * lp.x + rcv * lp.z
		var vtol: float = float(c["vtol"])
		for t0 in APPROACH_STARTS:
			var tc: float = t0 + t1
			var bp: Vector3 = _at(traj, tc)
			var bv: Vector3 = (bp - _at(traj, maxf(tc - TRAJ_STEP, 0.0))) / TRAJ_STEP
			if bv.length() < 0.3:
				continue
			if absf(bp.y - lp.y) > vtol:
				continue
			var need: Vector3 = KickModel.flat(bp - contact_offset(bv.normalized(), b)) - rel
			var d: float = need.distance_to(pos)
			if d > APPROACH_MAX or d > APPROACH_SPEED * t0 + JsonBallMove.CORR_MAX:
				continue
			if d < best_d:
				best_d = d
				best = need
	approach = best
	approach_face = Locomotion.dir_from_yaw(loco.yaw)
	_approach_ttl = APPROACH_EVERY * PLAN_EVERY + 2

## Punto del cuerpo en el marco del inicio del clip (x adelante, y arriba, z derecha), como `ball_touches`: raiz del clip mas
## el punto del cuerpo girado con el rumbo del clip en ese instante.
static func _local_point(rc: Vector2, hd: float, lp: Vector3) -> Vector3:
	var f := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, hd)
	var r := Vector3(-f.z, 0.0, f.x)
	return Vector3(rc.x, 0.0, rc.y) + f * lp.x + r * lp.z + Vector3(0.0, lp.y, 0.0)

## La pelota no choca con el cuerpo (capsula) ni lo cruza antes del contacto (a mas de 1.9 m de altura pasa por encima).
func _path_clear(traj: PackedVector3Array, origin: Vector3, f0: Vector3, r0: Vector3, rp: PackedVector2Array, start_at: float, dt1: float, corr: Vector3, part: StringName) -> bool:
	var n: int = maxi(int(ceil(dt1 * 30.0)), 1)
	for k in n + 1:
		var s: float = dt1 * float(k) / float(n)
		# Dentro de la ventana de contacto el cuerpo ya es fantasma (JsonBallMove.step).
		if s > dt1 - CONTACT_EARLY:
			break
		var bp: Vector3 = _at(traj, s)
		if bp.y > 1.9:
			continue
		var rr: Vector2 = ActionMotion._at(rp, start_at + s) if rp.size() >= 2 else Vector2.ZERO
		var body: Vector3 = origin + f0 * rr.x + r0 * rr.y + corr * (s / dt1)
		if KickModel.flat(bp).distance_to(body) < BODY_CLEAR:
			return false
	return true

func _rival_within(r: float) -> bool:
	var owner: Footballer = handler.owner
	if owner.ctx == null:
		return false
	for o in owner.ctx.opponents_of(owner):
		if KickModel.flat(o.global_position - owner.global_position).length() < r:
			return true
	return false

func _reject(why: String) -> void:
	if record_rejects:
		rejects[why] = int(rejects.get(why, 0)) + 1
	if not _trace_dec.is_empty():
		if _trace_id != &"":
			AnimTrace.cand(_trace_dec, _trace_id, why)
		else:
			_trace_dec["reason"] = why

## Del punto de contacto al centro de la pelota: la pelota viene por `inc` y la parte del cuerpo se pone delante de ella,
## asi que su centro queda un radio (y una holgura) antes, del lado por donde llega.
static func contact_offset(inc: Vector3, b: Ball) -> Vector3:
	return -inc.normalized() * (b.radius + 0.02)

# --- Respuesta fisica -------------------------------------------------------------------------------------------------

## Velocidad de la pelota tras el contacto de recepcion. Amortiguar depende del control del jugador, del equilibrio y de la
## carrera (BallHandler.first_touch_absorb), y una pelota fuerte deja mas velocidad:
##  - pie a ras de piso: la del clip (nominal: al siguiente toque o a la salida) mas el rebote de lo que el pie no amortigua,
##    reflejado por la cara del pie (entre la llegada y la salida): de frente vuelve hacia donde vino; orientado, sigue la salida;
##  - pie en el aire, muslo, rodilla, pecho: choque con la normal de esa parte (PlayerTuning.receive_contact: restitucion,
##    cuanto conserva de la velocidad a lo largo de la superficie y empuje hacia delante): la pelota pierde casi toda la
##    velocidad hacia el cuerpo, rebota poco (el muslo y la rodilla algo hacia arriba) y cae delante del jugador.
## Mas el error de control (angulo aleatorio segun el control y la carrera).
func contact_velocity(nominal: Vector3, b: Ball, part: StringName = &"foot") -> Vector3:
	var owner: Footballer = handler.owner
	var absorb: float = handler.first_touch_absorb(handler.ball_offset())
	var sigma: float = 20.0 * (1.35 - owner.attributes.norm("ball_control")) * (1.0 + 0.4 * handler._sprint_ratio())
	var noise: float = deg_to_rad(KickModel.gaussian_clipped(handler.rng, sigma))
	var v: Vector3
	var rel: Vector3 = b.linear_velocity - owner.velocity
	if part == &"foot":
		var rel_h: Vector3 = KickModel.flat(rel)
		# Lo que el pie no amortigua sale reflejado por la cara del pie, que mira entre la llegada y la salida (nominal): de
		# frente rebota hacia donde vino; en un control orientado sigue hacia la salida en vez de anularla.
		var back: Vector3 = -rel_h
		var out_dir: Vector3 = KickModel.flat(nominal)
		if out_dir.length() > 0.3 and rel_h.length() > 0.1:
			var n: Vector3 = out_dir.normalized() - rel_h.normalized()
			if n.length() > 0.2:
				n = n.normalized()
				back = rel_h - 2.0 * rel_h.dot(n) * n
			else:
				back = rel_h   # la salida sigue a la llegada: la pelota no vuelve hacia atras
		var leftover: Vector3 = (back * (1.0 - absorb) * REBOUND).rotated(Vector3.UP, noise)
		v = nominal + leftover
	else:
		var c: Vector3 = Tuning.player.receive_contact.get(String(part), Vector3(0.2, 0.3, 0.6))
		var fwd: Vector3 = owner.locomotion.forward()
		var n: Vector3 = _part_normal(part, fwd)
		var vn: float = rel.dot(n)
		var e: float = clampf(c.x * (1.0 - absorb) * 2.0, 0.0, 0.8)
		var out: Vector3 = rel - (1.0 + e) * minf(vn, 0.0) * n
		var tang: Vector3 = out - out.dot(n) * n
		out = out.dot(n) * n + tang * clampf(c.y * (1.0 - absorb) * 2.0, 0.0, 1.0)
		v = owner.velocity + out + (fwd * c.z).rotated(Vector3.UP, noise)
		if part == &"foot_air":
			# El pie en el aire mata la pelota hacia abajo: casi sin velocidad vertical hacia arriba.
			v.y = minf(v.y, 0.4)
	last_contact = {"incoming_speed": rel.length(), "absorb": absorb, "nominal": nominal, "out": v, "part": part}
	return v

## Normal (hacia fuera) de la superficie que toca la pelota: pie en el aire (empeine o planta), muslo (encima), rodilla
## (delante y arriba), pecho (delante, algo hacia arriba).
static func _part_normal(part: StringName, fwd: Vector3) -> Vector3:
	match part:
		&"foot_air":
			return (fwd * 0.5 + Vector3.UP * 0.87).normalized()
		&"thigh":
			return (fwd * 0.4 + Vector3.UP * 0.92).normalized()
		&"knee":
			return (fwd * 0.75 + Vector3.UP * 0.66).normalized()
		&"chest":
			return (fwd * 0.95 + Vector3.UP * 0.3).normalized()
	return (fwd * 0.4 + Vector3.UP * 0.9).normalized()

## Fin de una recepcion (la llama JsonBallMove): un tiempo sin volver a planificar.
func ended(contacted: bool) -> void:
	_cooldown = COOLDOWN
	if not contacted:
		stats["aborted"] += 1
