class_name ShotGesture
extends RefCounted
## Captura y analisis del trazo del dedo (mecanica principal de tiro). Registra la secuencia de puntos con su tiempo,
## filtra el ruido tactil (zona muerta entre muestras y suavizado exponencial), normaliza las distancias a ALTURAS DE
## PANTALLA (independiente de la resolucion y de la densidad de pixeles) y calcula las propiedades del gesto:
## largo, duracion, velocidad instantanea, media y maxima, aceleracion, direccion inicial y final, desplazamiento vertical y
## horizontal, curvatura (con signo), giro total y suavidad. No reserva memoria mientras el dedo se mueve: los arreglos
## tienen capacidad fija (GestureTuning.max_samples) y al llenarse se diezman de a dos.

## Ventana (s) de la velocidad maxima.
const PEAK_WINDOW := 0.045

var tuning: GestureTuning
## Alto de la pantalla (px): unidad de normalizacion.
var screen_h: float = 720.0
var _pts := PackedVector2Array()
var _ts := PackedFloat64Array()
var _n: int = 0
var _raw_last := Vector2.ZERO
var _filtered := Vector2.ZERO

func _init(t: GestureTuning = null, height_px: float = 720.0) -> void:
	tuning = t if t != null else GestureTuning.current()
	screen_h = maxf(height_px, 1.0)
	_pts.resize(tuning.max_samples)
	_ts.resize(tuning.max_samples)

func begin(p_px: Vector2, t: float, height_px: float = -1.0) -> void:
	if height_px > 0.0:
		screen_h = height_px
	if _pts.size() != tuning.max_samples:
		_pts.resize(tuning.max_samples)
		_ts.resize(tuning.max_samples)
	_n = 0
	_filtered = p_px / screen_h
	_raw_last = _filtered
	_store(_filtered, t)

## Agrega una muestra (pixeles de pantalla, segundos). Devuelve true si se guardo.
func add(p_px: Vector2, t: float) -> bool:
	var raw: Vector2 = p_px / screen_h
	if _n == 0:
		begin(p_px, t)
		return true
	if raw.distance_to(_raw_last) < tuning.min_step:
		return false
	_raw_last = raw
	_filtered = _filtered.lerp(raw, 1.0 - tuning.smoothing)
	_store(_filtered, t)
	return true

## Ultima muestra: el punto final se toma sin la demora del filtro (donde levanto el dedo).
func finish(p_px: Vector2, t: float) -> void:
	var raw: Vector2 = p_px / screen_h
	if _n > 0 and raw.distance_to(_pts[_n - 1]) >= tuning.min_step * 0.5:
		_filtered = raw
		_store(raw, t)

func _store(p: Vector2, t: float) -> void:
	if _n >= _pts.size():
		# Diezmado: conserva una de cada dos (el primero y el ultimo siempre).
		var k: int = 0
		for i in range(0, _n, 2):
			_pts[k] = _pts[i]
			_ts[k] = _ts[i]
			k += 1
		_n = k
	_pts[_n] = p
	_ts[_n] = t
	_n += 1

func count() -> int:
	return _n

func point(i: int) -> Vector2:
	return _pts[i]

## Puntos en pixeles (para dibujar el trazo).
func points_px() -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(_n)
	for i in _n:
		out[i] = _pts[i] * screen_h
	return out

func last_px() -> Vector2:
	return _pts[maxi(_n - 1, 0)] * screen_h

func first_px() -> Vector2:
	return _pts[0] * screen_h

## Propiedades del gesto. Distancias en alturas de pantalla, velocidades en alturas/s, aceleraciones en alturas/s^2,
## direcciones como vectores unitarios de pantalla (y hacia abajo), angulos en grados.
func features() -> Dictionary:
	var f := {"samples": _n, "length": 0.0, "duration": 0.0, "avg_speed": 0.0, "peak_speed": 0.0, "peak_accel": 0.0,
		"end_accel": 0.0, "start_dir": Vector2.ZERO, "end_dir": Vector2.ZERO, "vertical": 0.0, "horizontal": 0.0,
		"curvature": 0.0, "turn_deg": 0.0, "smoothness": 1.0, "chord": 0.0}
	if _n < 2:
		return f
	var duration: float = maxf(float(_ts[_n - 1] - _ts[0]), 1.0 / 60.0)
	var length: float = 0.0
	var peak: float = 0.0
	var peak_a: float = 0.0
	var prev_v: float = -1.0
	var v_sum: float = 0.0
	var v2_sum: float = 0.0
	var v_n: int = 0
	var last_a: float = 0.0
	for i in range(1, _n):
		var d: float = _pts[i].distance_to(_pts[i - 1])
		length += d
		var dt: float = maxf(float(_ts[i] - _ts[i - 1]), 1.0 / 240.0)
		var v: float = d / dt
		# Velocidad instantanea suavizada (media de dos muestras) para que un salto de una muestra no sea el pico.
		var vs: float = v if prev_v < 0.0 else (v + prev_v) * 0.5
		if prev_v >= 0.0:
			var a: float = (vs - prev_v) / dt
			peak_a = maxf(peak_a, a)
			last_a = a
		peak = maxf(peak, vs)
		prev_v = vs
		v_sum += vs
		v2_sum += vs * vs
		v_n += 1
	f["length"] = length
	f["duration"] = duration
	f["avg_speed"] = length / duration
	# Velocidad maxima robusta: la mayor velocidad media en una ventana de al menos PEAK_WINDOW s (un salto de una sola
	# muestra por el ritmo irregular de los eventos tactiles no cuenta como latigazo).
	var cum := PackedFloat32Array()
	cum.resize(_n)
	cum[0] = 0.0
	for i in range(1, _n):
		cum[i] = cum[i - 1] + _pts[i].distance_to(_pts[i - 1])
	var robust: float = 0.0
	var j: int = 0
	for i in range(1, _n):
		while j < i - 1 and float(_ts[i] - _ts[j + 1]) >= PEAK_WINDOW:
			j += 1
		var dtw: float = float(_ts[i] - _ts[j])
		if dtw >= PEAK_WINDOW * 0.75:
			robust = maxf(robust, (cum[i] - cum[j]) / dtw)
	if robust <= 0.0:
		robust = length / duration
	f["peak_speed"] = minf(peak, robust)
	f["peak_accel"] = peak_a
	f["end_accel"] = last_a
	var a0: Vector2 = _pts[0]
	var b0: Vector2 = _pts[_n - 1]
	var chord: Vector2 = b0 - a0
	f["chord"] = chord.length()
	f["vertical"] = a0.y - b0.y
	f["horizontal"] = b0.x - a0.x
	f["start_dir"] = _dir_from_start(length * 0.18)
	f["end_dir"] = _dir_to_end(length * 0.18)
	var sd: Vector2 = f["start_dir"]
	var ed: Vector2 = f["end_dir"]
	if sd != Vector2.ZERO and ed != Vector2.ZERO:
		f["turn_deg"] = rad_to_deg(sd.angle_to(ed))
	# Curvatura: desvio maximo con signo respecto de la cuerda / largo de la cuerda (+ = el trazo se abomba a la derecha).
	var cl: float = chord.length()
	if cl > 1e-4 and _n >= 3:
		var nrm := Vector2(-chord.y, chord.x) / cl
		var best: float = 0.0
		for i in _n:
			var dd: float = (_pts[i] - a0).dot(nrm)
			if absf(dd) > absf(best):
				best = dd
		f["curvature"] = best / cl
	# Suavidad: irregularidad del rumbo (cambios de direccion entre segmentos alrededor de su media, RMS) y del ritmo
	# (coeficiente de variacion de la velocidad por encima de lo normal en un trazo).
	if _n >= 4:
		var prev_ang: float = NAN
		var dsum: float = 0.0
		var d2sum: float = 0.0
		var dn: int = 0
		for i in range(1, _n):
			var seg: Vector2 = _pts[i] - _pts[i - 1]
			if seg.length() < 1e-5:
				continue
			var ang: float = seg.angle()
			if not is_nan(prev_ang):
				var da: float = wrapf(ang - prev_ang, -PI, PI)
				dsum += da
				d2sum += da * da
				dn += 1
			prev_ang = ang
		var angle_rough: float = 0.0
		if dn > 1:
			var mean: float = dsum / float(dn)
			angle_rough = sqrt(maxf(d2sum / float(dn) - mean * mean, 0.0))
		var mean_v: float = v_sum / float(maxi(v_n, 1))
		var cv: float = sqrt(maxf(v2_sum / float(maxi(v_n, 1)) - mean_v * mean_v, 0.0)) / maxf(mean_v, 1e-4)
		var rough: float = angle_rough / tuning.rough_ref + maxf(cv - 0.8, 0.0) * 0.5
		f["smoothness"] = clampf(1.0 - rough, 0.0, 1.0)
	return f

func _dir_from_start(min_len: float) -> Vector2:
	var acc: float = 0.0
	for i in range(1, _n):
		acc += _pts[i].distance_to(_pts[i - 1])
		if acc >= min_len:
			return (_pts[i] - _pts[0]).normalized()
	return (_pts[_n - 1] - _pts[0]).normalized()

func _dir_to_end(min_len: float) -> Vector2:
	var acc: float = 0.0
	for i in range(_n - 2, -1, -1):
		acc += _pts[i + 1].distance_to(_pts[i])
		if acc >= min_len:
			return (_pts[_n - 1] - _pts[i]).normalized()
	return (_pts[_n - 1] - _pts[0]).normalized()

## Gesto sintetico para pruebas y para el comparador del panel de diagnostico: de `from` a `to` (pixeles) en `seconds`, con
## una curvatura `bulge` (fraccion de la cuerda, + derecha), `jitter` (px de temblor) y muestras cada 1/120 s.
static func synthetic(t: GestureTuning, height_px: float, from: Vector2, to: Vector2, seconds: float, bulge: float = 0.0,
		jitter: float = 0.0, seed_value: int = 1, end_hook: Vector2 = Vector2.ZERO) -> ShotGesture:
	var g := ShotGesture.new(t, height_px)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var steps: int = maxi(int(seconds * 120.0), 3)
	var chord: Vector2 = to - from
	var nrm := Vector2(-chord.y, chord.x).normalized()
	for i in steps + 1:
		var u: float = float(i) / float(steps)
		var p: Vector2 = from + chord * u + nrm * (sin(u * PI) * bulge * chord.length())
		if end_hook != Vector2.ZERO and u > 0.8:
			p += end_hook * ((u - 0.8) / 0.2)
		if jitter > 0.0 and i > 0 and i < steps:
			p += Vector2(rng.randfn(0.0, jitter), rng.randfn(0.0, jitter))
		if i == 0:
			g.begin(p, 0.0)
		elif i == steps:
			g.finish(p, seconds)
		else:
			g.add(p, seconds * u)
	return g
