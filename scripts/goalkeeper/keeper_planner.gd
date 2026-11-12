class_name KeeperPlanner
extends RefCounted
## Planificador de atajadas (puro, sin nodos). Dada la trayectoria predicha de la pelota, elige entre los clips del
## arquero cual hace que las MANOS lleguen a la pelota: usa la trayectoria de manos medida de cada clip (con el
## desplazamiento de la raiz incluido), el instante de inicio y la velocidad de reproduccion.

## Clips de atajada y radio de contacto de las manos (m). Los espejos "_mirror" se agregan solos si existen.
const SAVE_CLIPS := {
	&"goalkeeper_catch": 0.40, &"goalkeeper_catch_2": 0.40, &"goalkeeper_catch_3": 0.42, &"goalkeeper_catch_4": 0.42,
	&"goalkeeper_body_block": 0.60, &"goalkeeper_body_block_2": 0.60, &"goalkeeper_body_block_3": 0.60,
	&"goalkeeper_diving_save": 0.50, &"goalkeeper_diving_save_2": 0.50,
	&"goalkeeper_scoop": 0.40, &"goalkeeper_sidestep": 0.45, &"goalkeeper_sidestep_2": 0.45,
}
## Recogida de pelota suelta y lenta: solo clips bajos (nada de estiradas ni bloqueos con el cuerpo).
const PICKUP_CLIPS := [&"goalkeeper_scoop", &"goalkeeper_catch", &"goalkeeper_catch_2", &"goalkeeper_catch_4"]
## Altura maxima (m) de las manos en el contacto de una recogida.
const PICKUP_MAX_HANDS_Y := 0.7
## Banco JSON: roles de los clips de recogida (los nombres de PICKUP_CLIPS son del banco viejo y no existen en el JSON: sin
## esto ningun clip contaba como recogida y el arquero nunca levantaba una pelota suelta).
const JSON_PICKUP_ROLES := [&"gk_scoop", &"gk_catch"]

## Modo 4: roles de los clips de atajada y su radio de contacto de las manos (m).
const JSON_ROLE_RADIUS := {&"gk_catch": 0.42, &"gk_dive": 0.50, &"gk_scoop": 0.40, &"gk_sidestep": 0.45, &"gk_block": 0.60}

## Manos del arquero en la posicion de espera, en el marco del cuerpo (adelante, arriba, derecha).
const READY_HANDS := Vector3(0.35, 1.0, 0.0)

static func _role(id: StringName) -> StringName:
	if _role_cache.has(id):
		return _role_cache[id]
	var role := StringName(String(PackLibrary.meta(id).get("role", "")))
	_role_cache[id] = role
	return role

static func candidates() -> Array[StringName]:
	var out: Array[StringName] = []
	if PackLibrary.json_mode():
		for r in JSON_ROLE_RADIUS:
			out.append_array(PackLibrary.by_role(r))
		return out
	for id in SAVE_CLIPS:
		if PackLibrary.has_clip(id):
			out.append(id)
		var m := StringName(String(id) + "_mirror")
		if PackLibrary.has_clip(m):
			out.append(m)
	return out

static func radius_of(id: StringName) -> float:
	var scale: float = Tuning.keeper.contact_scale if Tuning.keeper != null else 1.0
	if PackLibrary.json_mode():
		return float(JSON_ROLE_RADIUS.get(_role(id), 0.45)) * scale
	var base := StringName(String(id).trim_suffix("_mirror"))
	return float(SAVE_CLIPS.get(base, 0.45)) * scale

## Posicion MUNDIAL de un punto de interes ("hands", "toe_l", "toe_r", "head") del clip en la muestra k, con el cuerpo
## en `origin` mirando a `yaw` al INICIO del clip (la trayectoria ya incluye el desplazamiento de la raiz).
static func path_world(id: StringName, key: String, k: int, origin: Vector3, yaw: float) -> Vector3:
	var hp: PackedVector3Array = PackLibrary.meta(id).get("paths", {}).get(key, PackedVector3Array())
	if hp.is_empty():
		return origin
	var h: Vector3 = hp[clampi(k, 0, hp.size() - 1)]
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var r := Vector3(-f.z, 0.0, f.x)
	return Vector3(origin.x, 0.0, origin.z) + f * h.x + r * h.z + Vector3.UP * h.y

## Igual que path_world pero con el cuerpo YA movido por la raiz: `body` es la posicion actual del arquero. Resta el
## desplazamiento de raiz acumulado en la muestra k, asi que sigue valiendo si una colision desvio al arquero.
static func path_world_at_body(id: StringName, key: String, k: int, body: Vector3, yaw: float) -> Vector3:
	var meta: Dictionary = PackLibrary.meta(id)
	var hp: PackedVector3Array = meta.get("paths", {}).get(key, PackedVector3Array())
	var rp: PackedVector2Array = meta.get("root_path", PackedVector2Array())
	if hp.is_empty():
		return body
	var kk: int = clampi(k, 0, hp.size() - 1)
	var h: Vector3 = hp[kk]
	var ro: Vector2 = rp[mini(kk, rp.size() - 1)] if rp.size() > 0 else Vector2.ZERO
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var r := Vector3(-f.z, 0.0, f.x)
	return Vector3(body.x, 0.0, body.z) + f * (h.x - ro.x) + r * (h.z - ro.y) + Vector3.UP * h.y

## Instante (s del clip) de maxima velocidad de un punto de interes: lanzamiento de una mano o golpeo de un pie.
static func peak_speed_time(id: StringName, key: String) -> float:
	var hp: PackedVector3Array = PackLibrary.meta(id).get("paths", {}).get(key, PackedVector3Array())
	var best_i: int = 0
	var best_v: float = -1.0
	for i in range(1, hp.size() - 1):
		var v: float = (hp[i + 1] - hp[i - 1]).length()
		if v > best_v:
			best_v = v
			best_i = i
	return float(best_i) / 30.0

## Posicion MUNDIAL de las manos en el instante k (muestra a 30 Hz) del clip, con el cuerpo en `origin` mirando a `yaw`
## al inicio del clip (el desplazamiento de la raiz ya esta incluido en la trayectoria).
static func hands_world(id: StringName, k: int, origin: Vector3, yaw: float) -> Vector3:
	var hp: PackedVector3Array = PackLibrary.meta(id).get("paths", {}).get("hands", PackedVector3Array())
	if hp.is_empty():
		return origin
	var h: Vector3 = hp[clampi(k, 0, hp.size() - 1)]
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var r := Vector3(-f.z, 0.0, f.x)
	return Vector3(origin.x, 0.0, origin.z) + f * h.x + r * h.z + Vector3.UP * h.y

## Costo (por segundo de clip) que suma un clip largo entre los que llegan: a igual estilo, el que se recupera antes.
const DURATION_COST := 0.06

## Preferencia de estilo entre los clips que SI llegan (suma al puntaje; menor = mas natural): atrapar antes que
## estirarse, estirarse antes que dar un paso lateral, y bloquear con el cuerpo solo si no queda otra.
static func style_penalty(id: StringName) -> float:
	if PackLibrary.json_mode():
		match _role(id):
			&"gk_catch", &"gk_scoop":
				return 0.0
			&"gk_dive":
				return 0.12
			&"gk_sidestep":
				return 0.18
		return 0.30
	var n: String = String(id)
	if n.contains("scoop") or n.contains("catch"):
		return 0.0
	if n.contains("diving"):
		return 0.12
	if n.contains("sidestep"):
		return 0.18
	return 0.30

static var _bbox_cache: Dictionary = {}
## Rol de cada clip (se consulta en el bucle interno de plan_save).
static var _role_cache: Dictionary = {}
## Datos de cada candidato que no dependen de la jugada (plan_save): antes se buscaban meta, rol y radio y se comparaban
## nombres por clip en cada llamada.
static var _cand_cache: Array = []
static var _cand_cache_json: int = -1

## Vacia los datos calculados con la libreria de clips (cambian al cambiar de modo).
static func reset_caches() -> void:
	_bbox_cache = {}
	_role_cache = {}
	_cand_cache = []
	_cand_cache_json = -1

## Calcula ya los datos fijos de los candidatos (MatchScene al cargar el partido).
static func warm_cache() -> void:
	_candidate_data()

## Candidatos con sus datos fijos: [id, manos, raiz, radio sin escala, caja de manos (min, max), estilo, duracion, es de
## recogida, es scoop del pack].
static func _candidate_data() -> Array:
	var js: int = 1 if PackLibrary.json_mode() else 0
	if _cand_cache_json == js:
		return _cand_cache
	_cand_cache_json = js
	_cand_cache = _build_candidate_data()
	return _cand_cache

static func _build_candidate_data() -> Array:
	var out: Array = []
	var scale: float = Tuning.keeper.contact_scale if Tuning.keeper != null else 1.0
	for id in candidates():
		var meta: Dictionary = PackLibrary.meta(id)
		var hp: PackedVector3Array = meta.get("paths", {}).get("hands", PackedVector3Array())
		var bb: Array = _bbox(id, hp) if not hp.is_empty() else [Vector3.ZERO, Vector3.ZERO]
		# Cajas de las manos por grupos de K_BLOCK muestras (k = 6, 8, ...): se salta un grupo entero si ninguna mano suya puede
		# servir (mismo criterio que mano a mano).
		var klo := PackedVector3Array()
		var khi := PackedVector3Array()
		var kk: int = 6
		while kk < hp.size():
			var lo_k: Vector3 = hp[kk]
			var hi_k: Vector3 = hp[kk]
			var j: int = kk + 2
			while j < mini(kk + 2 * K_BLOCK, hp.size()):
				lo_k = Vector3(minf(lo_k.x, hp[j].x), minf(lo_k.y, hp[j].y), minf(lo_k.z, hp[j].z))
				hi_k = Vector3(maxf(hi_k.x, hp[j].x), maxf(hi_k.y, hp[j].y), maxf(hi_k.z, hp[j].z))
				j += 2
			klo.append(lo_k)
			khi.append(hi_k)
			kk += 2 * K_BLOCK
		# Por muestra: recorrido de la raiz y distancia de las manos a la posicion de espera (limite humano).
		var rp: PackedVector2Array = meta.get("root_path", PackedVector2Array())
		var trav := PackedFloat32Array()
		var ready_d := PackedFloat32Array()
		trav.resize(hp.size())
		ready_d.resize(hp.size())
		for k in hp.size():
			trav[k] = rp[mini(k, rp.size() - 1)].length() if rp.size() > 0 else 0.0
			ready_d[k] = (hp[k] - READY_HANDS).length()
		out.append([id, hp, rp, radius_of(id) / maxf(scale, 1e-6), bb[0], bb[1],
			style_penalty(id), float(meta.get("duration", 1.0)), PICKUP_CLIPS.has(StringName(String(id).trim_suffix("_mirror"))) \
				or (PackLibrary.json_mode() and JSON_PICKUP_ROLES.has(_role(id))),
			String(id).begins_with("goalkeeper_scoop"), klo, khi, trav, ready_d])
	return out

## Tramos de la trayectoria agrupados de a SEG_BLOCK con su caja: plan_save descarta un grupo entero cuando ni su caja
## queda dentro del radio ni puede mejorar la mejor distancia (mismo resultado que mirando tramo a tramo).
const SEG_BLOCK := 8
## Muestras de manos por grupo (de a dos imagenes: k = 6, 8, ...).
const K_BLOCK := 6

## Caja (min, max) de la trayectoria de manos de un clip en el marco del cuerpo (adelante, arriba, derecha).
static func _bbox(id: StringName, hp: PackedVector3Array) -> Array:
	if _bbox_cache.has(id):
		return _bbox_cache[id]
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for h in hp:
		lo = Vector3(minf(lo.x, h.x), minf(lo.y, h.y), minf(lo.z, h.z))
		hi = Vector3(maxf(hi.x, h.x), maxf(hi.y, h.y), maxf(hi.z, h.z))
	_bbox_cache[id] = [lo, hi]
	return [lo, hi]

## Planifica una atajada. traj: posiciones de la pelota cada `step` s (0 = ahora). min_delay: segundos hasta que el
## arquero puede empezar a moverse. Usa la aproximacion CONTINUA entre cada manos(k) y la poligonal de la pelota.
## human: (latencia s, velocidad m/s) del limite humano de las manos: desde ahora, las manos no llegan a un punto antes de
## latencia + distancia desde la posicion de espera (READY_HANDS) / velocidad, aunque el clip lo haga mas rapido (varios
## clips empiezan con la estirada ya lanzada). Vector2.ZERO = sin limite.
## Devuelve {} o {clip, speed, k, tau, delay, arrive, dist, radius, travel}.
## radius_scale: escala extra del radio de contacto de las manos (1 = el del partido). Los modos de tiros libres y penales
## resuelven el contacto con esferas en los huesos (mas chicas que el radio del partido) y piden planes mas justos.
## tau_cost: costo por segundo entre el arranque del clip y el contacto (0 = el del partido): con mas, entre los clips que
## llegan prefiere las estiradas rapidas, que arrancan mas tarde (el arquero del tiro libre lee la pelota mas tiempo).
static func plan_save(origin: Vector3, yaw: float, traj: PackedVector3Array, step: float, min_delay: float,
		_ball_speed: float, pickup: bool, speeds: Array = [1.0, 1.4], human: Vector2 = Vector2.ZERO, radius_scale: float = 1.0,
		tau_cost: float = 0.0) -> Dictionary:
	Prof.begin(&"arquero (plan de atajada)")
	var plan: Dictionary = _plan_save(origin, yaw, traj, step, min_delay, pickup, speeds, human, radius_scale, tau_cost)
	Prof.end(&"arquero (plan de atajada)")
	return plan

## Traza (AnimTrace, solo depuracion): motivo por candidato del ultimo plan_save (id -> motivo; "evaluado" = sus manos se
## compararon con la pelota y perdio por distancia o estilo). La lee Goalkeeper al empezar la atajada.
static var trace_reasons: Dictionary = {}

static func _plan_save(origin: Vector3, yaw: float, traj: PackedVector3Array, step: float, min_delay: float, pickup: bool,
		speeds: Array, human: Vector2, radius_scale: float = 1.0, tau_cost: float = 0.0) -> Dictionary:
	if AnimTrace.enabled:
		trace_reasons = {}
	var best: Dictionary = {}
	var best_score: float = INF
	var best_dist: float = INF
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var r := Vector3(-f.z, 0.0, f.x)
	var o := Vector3(origin.x, 0.0, origin.z)
	# Pelota en el marco local del arquero (adelante, arriba, derecha) y ventana donde esta al alcance (< 4.5 m).
	var local := PackedVector3Array()
	var first: int = -1
	var last: int = -1
	var wlo := Vector3(INF, INF, INF)
	var whi := Vector3(-INF, -INF, -INF)
	for i in traj.size():
		var d: Vector3 = traj[i] - o
		var lp := Vector3(d.dot(f), traj[i].y, d.dot(r))
		local.append(lp)
		if float(i) * step >= min_delay and Vector2(lp.x, lp.z).length() <= 4.5:
			if first < 0:
				first = i
			last = i
			wlo = Vector3(minf(wlo.x, lp.x), minf(wlo.y, lp.y), minf(wlo.z, lp.z))
			whi = Vector3(maxf(whi.x, lp.x), maxf(whi.y, lp.y), maxf(whi.z, lp.z))
	if first < 0:
		return {}
	var seg_hi: int = mini(last, local.size() - 2)
	# La caja incluye el final del ultimo segmento que se recorre (puede quedar fuera de la ventana de 4.5 m).
	var tail: Vector3 = local[seg_hi + 1]
	wlo = Vector3(minf(wlo.x, tail.x), minf(wlo.y, tail.y), minf(wlo.z, tail.z))
	whi = Vector3(maxf(whi.x, tail.x), maxf(whi.y, tail.y), maxf(whi.z, tail.z))
	# Caja de cada segmento de la pelota: descarta sin proyectar los segmentos que no pueden mejorar el resultado.
	var seg_lo := PackedVector3Array()
	var seg_hi_box := PackedVector3Array()
	seg_lo.resize(local.size())
	seg_hi_box.resize(local.size())
	for i in range(first, seg_hi + 1):
		var a0: Vector3 = local[i]
		var a1: Vector3 = local[i + 1]
		seg_lo[i] = Vector3(minf(a0.x, a1.x), minf(a0.y, a1.y), minf(a0.z, a1.z))
		seg_hi_box[i] = Vector3(maxf(a0.x, a1.x), maxf(a0.y, a1.y), maxf(a0.z, a1.z))
	var nblk: int = (seg_hi - first) / SEG_BLOCK + 1 if seg_hi >= first else 0
	var blk_lo := PackedVector3Array()
	var blk_hi := PackedVector3Array()
	blk_lo.resize(nblk)
	blk_hi.resize(nblk)
	for bi in nblk:
		var i0: int = first + bi * SEG_BLOCK
		var lo_b: Vector3 = seg_lo[i0]
		var hi_b: Vector3 = seg_hi_box[i0]
		for i in range(i0 + 1, mini(i0 + SEG_BLOCK, seg_hi + 1)):
			lo_b = Vector3(minf(lo_b.x, seg_lo[i].x), minf(lo_b.y, seg_lo[i].y), minf(lo_b.z, seg_lo[i].z))
			hi_b = Vector3(maxf(hi_b.x, seg_hi_box[i].x), maxf(hi_b.y, seg_hi_box[i].y), maxf(hi_b.z, seg_hi_box[i].z))
		blk_lo[bi] = lo_b
		blk_hi[bi] = hi_b
	var scale: float = (Tuning.keeper.contact_scale if Tuning.keeper != null else 1.0) * radius_scale
	for cd in _candidate_data():
		var id: StringName = cd[0]
		var is_pickup_clip: bool = cd[8]
		if pickup != is_pickup_clip and (pickup or bool(cd[9])):
			if AnimTrace.enabled:
				trace_reasons[id] = "recogida" if is_pickup_clip else "no es de recogida"
			continue
		var hp: PackedVector3Array = cd[1]
		if hp.is_empty():
			if AnimTrace.enabled:
				trace_reasons[id] = "sin trayectoria de manos medida"
			continue
		var rad: float = float(cd[3]) * scale
		var lo: Vector3 = (cd[4] as Vector3) - Vector3.ONE * (rad + 0.9)
		var hi: Vector3 = (cd[5] as Vector3) + Vector3.ONE * (rad + 0.9)
		if whi.x < lo.x or wlo.x > hi.x or whi.y < lo.y or wlo.y > hi.y or whi.z < lo.z or wlo.z > hi.z:
			if AnimTrace.enabled:
				trace_reasons[id] = "manos del clip fuera del alcance de la trayectoria"
			continue
		if AnimTrace.enabled:
			trace_reasons[id] = "evaluado"
		var rp: PackedVector2Array = cd[2]
		var style: float = cd[6]
		var duration: float = cd[7]
		var klo: PackedVector3Array = cd[10]
		var khi: PackedVector3Array = cd[11]
		var trav: PackedFloat32Array = cd[12]
		var ready_d: PackedFloat32Array = cd[13]
		var n_hp: int = hp.size()
		for sp in speeds:
			# Cota inferior del puntaje de este clip a esta velocidad (distancia y recorrido 0). Con un plan valido ya elegido
			# (puntaje < 5: los validos nunca llegan a 5) que no se puede mejorar, no se mira: mismo resultado.
			var base_score: float = style + (0.05 if sp > 1.0 else 0.0) + DURATION_COST * duration / sp
			if best_score < 5.0 and base_score >= best_score:
				continue
			var k: int = 6
			while k < n_hp:
				# Al empezar un grupo de muestras: si la caja de sus manos esta fuera de la que barre la pelota (+ radio) y no
				# puede mejorar best_dist, ninguna de sus manos sirve.
				if (k - 6) % (2 * K_BLOCK) == 0:
					var ci: int = (k - 6) / (2 * K_BLOCK)
					var cl: Vector3 = klo[ci]
					var ch: Vector3 = khi[ci]
					var rc: float = maxf(rad, best_dist)
					if wlo.x - ch.x > rc or cl.x - whi.x > rc or wlo.y - ch.y > rc or cl.y - whi.y > rc or wlo.z - ch.z > rc or cl.z - whi.z > rc:
						k += 2 * K_BLOCK
						continue
				var h: Vector3 = hp[k]
				if pickup and h.y > PICKUP_MAX_HANDS_Y:
					k += 2
					continue
				# Manos fuera de la caja que barre la pelota (+ radio): ningun segmento puede quedar mas cerca que
				# best_dist ni dentro del radio (mismo resultado, sin recorrer la trayectoria).
				var rk: float = maxf(rad, best_dist)
				if wlo.x - h.x > rk or h.x - whi.x > rk or wlo.y - h.y > rk or h.y - whi.y > rk or wlo.z - h.z > rk or h.z - whi.z > rk:
					k += 2
					continue
				var travel_k: float = trav[k]
				if best_score < 5.0 and base_score + 0.03 * travel_k >= best_score:
					k += 2
					continue
				var tau: float = float(k) / 30.0
				var earliest: float = min_delay + tau / sp
				if human.y > 0.0:
					earliest = maxf(earliest, min_delay + human.x + ready_d[k] / human.y)
				var i: int = maxi(first, int(floor(earliest / step)))
				while i <= seg_hi:
					# Al empezar un grupo de tramos: si su caja no puede dar nada, se salta el grupo entero.
					if (i - first) % SEG_BLOCK == 0 or i == maxi(first, int(floor(earliest / step))):
						var bi: int = (i - first) / SEG_BLOCK
						var bl: Vector3 = blk_lo[bi]
						var bh: Vector3 = blk_hi[bi]
						var rb: float = maxf(rad, best_dist)
						if bl.x - h.x > rb or h.x - bh.x > rb or bl.y - h.y > rb or h.y - bh.y > rb or bl.z - h.z > rb or h.z - bh.z > rb:
							i = first + (bi + 1) * SEG_BLOCK
							continue
					var sl: Vector3 = seg_lo[i]
					var sh: Vector3 = seg_hi_box[i]
					var rs: float = maxf(rad, best_dist)
					if sl.x - h.x > rs or h.x - sh.x > rs or sl.y - h.y > rs or h.y - sh.y > rs or sl.z - h.z > rs or h.z - sh.z > rs:
						i += 1
						continue
					var a: Vector3 = local[i]
					var ab: Vector3 = local[i + 1] - a
					var len2: float = ab.length_squared()
					var u: float = clampf((h - a).dot(ab) / len2, 0.0, 1.0) if len2 > 1e-8 else 0.0
					var t_arr: float = (float(i) + u) * step
					if t_arr >= earliest:
						var dist: float = (a + ab * u - h).length()
						if dist < rad * 0.85 or dist < best_dist:
							best_dist = minf(best_dist, dist)
							var travel: float = travel_k
							# Valido = las manos llegan con holgura (85 % del radio): se elige el estilo mas natural.
							# Si ninguno llega con holgura, gana el que queda mas cerca (puntaje alto = intento forzado).
							var score: float
							if dist <= rad * 0.85:
								# Entre los que llegan, los cortos (se recupera antes: no se tira al suelo por una pelota mansa).
								score = style + 0.03 * travel + (0.05 if sp > 1.0 else 0.0) + 0.2 * dist / rad \
									+ DURATION_COST * duration / sp + tau_cost * tau / sp
							else:
								score = 5.0 + dist
							if score < best_score:
								best_score = score
								best = {"clip": id, "speed": sp, "k": k, "tau": tau, "arrive": t_arr, "dist": dist,
									"radius": rad, "delay": maxf(t_arr - tau / sp, min_delay), "travel": travel}
					i += 1
				k += 2
	return best
