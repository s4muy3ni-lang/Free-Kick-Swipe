extends Node
## Constructor OFFLINE del humanoide realista del modo Json. Genera la malla con piel (huesos del esqueleto canonico JsonRig,
## pose A) a partir de tubos elipticos que siguen cada miembro, con zona del kit (camiseta, short, medias, botines, piel, pelo,
## ojos, suela, ribete) horneada en COLOR.r (indice / 10) y sombreado de oclusion en COLOR.g.
## Salida: assets/characters/json/json_human.scn (versionada). Uso: godot --headless --path . res://tools/json_anim/build_json_human.tscn

const OUT := "res://assets/characters/json/json_human.scn"
const SEG := 16
const SEG_HEAD := 40
const SPACING := 0.026

enum Zone { JERSEY, SHORTS, SOCKS, BOOTS, SKIN, HAIR, EYE, SOLE, TRIM, LIPS }

var _v := PackedVector3Array()
var _col := PackedColorArray()
var _bn := PackedInt32Array()
var _wt := PackedFloat32Array()
var _idx := PackedInt32Array()
var _pos: Dictionary = {}
var _bix: Dictionary = {}

func _ready() -> void:
	_pos = JsonRig.rest_positions(JsonRig.Pose.A)
	for i in JsonRig.BONES.size():
		_bix[JsonRig.BONES[i]] = i
	_torso()
	_neck_and_head()
	for side in [-1, 1]:
		_leg(side)
		_boot(side)
		_arm(side)
	_save()

# --- Utilidades ------------------------------------------------------------------------------------------------------

func _b(name: String) -> int:
	return _bix["mixamorig_" + name]

static func _prof(p: Array, s: float) -> Vector2:
	## Perfil [[s, ra, rb], ...] interpolado con suavizado.
	if s <= p[0][0]:
		return Vector2(p[0][1], p[0][2])
	for i in range(p.size() - 1):
		if s <= p[i + 1][0]:
			var u: float = (s - p[i][0]) / maxf(p[i + 1][0] - p[i][0], 1e-6)
			u = u * u * (3.0 - 2.0 * u)
			return Vector2(lerpf(p[i][1], p[i + 1][1], u), lerpf(p[i][2], p[i + 1][2], u))
	var l: int = p.size() - 1
	return Vector2(p[l][1], p[l][2])

## Peso del hueso al cruzar una articulacion: 0 antes de `a`, 1 despues de `b` (suavizado).
static func _x(v: float, a: float, b: float) -> float:
	return smoothstep(a, b, v)

func _add_vertex(p: Vector3, zone: int, ao: float, w: Dictionary) -> int:
	var tot := 0.0
	var items: Array = []
	for k in w:
		if float(w[k]) > 0.001:
			items.append([int(k), float(w[k])])
	items.sort_custom(func(x: Array, y: Array) -> bool: return x[1] > y[1])
	items = items.slice(0, 4)
	for it in items:
		tot += it[1]
	for k in 4:
		if k < items.size():
			_bn.append(items[k][0])
			_wt.append(items[k][1] / tot)
		else:
			_bn.append(0)
			_wt.append(0.0)
	_v.append(p)
	_col.append(Color(float(zone) / 10.0, ao, 0.0, 1.0))
	return _v.size() - 1

## Anillos [{c, a, b, ra, rb, zone_fn, ao_fn, w}] -> tubo cerrado por anillos. caps: [inicio, fin].
func _loft(rings: Array, caps: Array, seg: int = SEG) -> void:
	var base: Array = []
	for r in rings:
		var ids: Array = []
		for i in seg:
			var th: float = TAU * float(i) / float(seg)
			var p: Vector3 = (r["c"] as Vector3) + (r["a"] as Vector3) * (cos(th) * float(r["ra"])) + (r["b"] as Vector3) * (sin(th) * float(r["rb"]))
			var z: int = (r["zone"] as Callable).call(p, th)
			var ao: float = (r["ao"] as Callable).call(p, z) if r.has("ao") else 1.0
			if r.has("move"):
				p = (r["move"] as Callable).call(p, z, r)
			ids.append(_add_vertex(p, z, ao, r["w"] as Dictionary if not (r["w"] is Callable) else (r["w"] as Callable).call(p)))
		base.append(ids)
	for k in range(rings.size() - 1):
		for i in seg:
			var i2: int = (i + 1) % seg
			var a0: int = base[k][i]
			var a1: int = base[k][i2]
			var b0: int = base[k + 1][i]
			var b1: int = base[k + 1][i2]
			# El vertice que manda el color plano (el ultimo del triangulo) es siempre el del anillo k: la frontera de zona queda en un anillo.
			_idx.append_array([a0, b0, a1, b0, b1, a1])
	for e in 2:
		if not caps[e]:
			continue
		var r: Dictionary = rings[0] if e == 0 else rings[rings.size() - 1]
		var ids2: Array = base[0] if e == 0 else base[base.size() - 1]
		var dirv: Vector3 = (r["a"] as Vector3).cross(r["b"] as Vector3)
		var cp: Vector3 = (r["c"] as Vector3) + dirv * (-0.004 if e == 0 else 0.004)
		var z: int = (r["zone"] as Callable).call(r["c"], 0.0)
		var cid: int = _add_vertex(cp, z, 1.0, r["w"] as Dictionary if not (r["w"] is Callable) else (r["w"] as Callable).call(cp))
		for i in seg:
			var i2: int = (i + 1) % seg
			if e == 0:
				_idx.append_array([cid, ids2[i], ids2[i2]])
			else:
				_idx.append_array([cid, ids2[i2], ids2[i]])

## Marco del anillo: direccion `d` del miembro y vector lateral de referencia.
static func _axes(d: Vector3, side_hint: Vector3) -> Array:
	var dn: Vector3 = d.normalized()
	var a: Vector3 = side_hint - dn * side_hint.dot(dn)
	a = a.normalized()
	return [a, dn.cross(a)]

## Polilinea con tangente suavizada en las articulaciones.
class Chain:
	var pts: Array = []
	var cum: Array = []
	var blend: float = 0.05
	func _init(points: Array, blend_len: float = 0.05) -> void:
		pts = points
		blend = blend_len
		cum = [0.0]
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + (pts[i] as Vector3).distance_to(pts[i - 1]))
	func length() -> float:
		return cum[cum.size() - 1]
	func at(s: float) -> Array:
		s = clampf(s, 0.0, length())
		var k := 0
		while k < pts.size() - 2 and s > cum[k + 1]:
			k += 1
		var d: Vector3 = ((pts[k + 1] as Vector3) - (pts[k] as Vector3)).normalized()
		var p: Vector3 = (pts[k] as Vector3) + d * (s - cum[k])
		var t: Vector3 = d
		var to_end: float = cum[k + 1] - s
		var from_start: float = s - cum[k]
		if k + 2 < pts.size() and to_end < blend:
			var d2: Vector3 = ((pts[k + 2] as Vector3) - (pts[k + 1] as Vector3)).normalized()
			t = d.lerp(d2, 0.5 * (1.0 - to_end / blend)).normalized()
		elif k > 0 and from_start < blend:
			var d0: Vector3 = ((pts[k] as Vector3) - (pts[k - 1] as Vector3)).normalized()
			t = d.lerp(d0, 0.5 * (1.0 - from_start / blend)).normalized()
		return [p, t]

# --- Torso -----------------------------------------------------------------------------------------------------------

func _torso_w(y: float) -> Dictionary:
	var w := {}
	var hips: float = 1.0 - _x(y, 0.88, 1.0)
	var sp: float = _x(y, 0.88, 1.0) * (1.0 - _x(y, 1.10, 1.20))
	var sp1: float = _x(y, 1.10, 1.20) * (1.0 - _x(y, 1.30, 1.40))
	var sp2: float = _x(y, 1.30, 1.40) * (1.0 - _x(y, 1.44, 1.50))
	var neck: float = _x(y, 1.44, 1.50)
	w[_b("Hips")] = hips
	w[_b("Spine")] = sp
	w[_b("Spine1")] = sp1
	w[_b("Spine2")] = sp2
	w[_b("Neck")] = neck
	return w

func _torso() -> void:
	var rows := [
		[0.78, 0.150, 0.105, 0.000], [0.84, 0.172, 0.112, 0.000], [0.90, 0.177, 0.113, 0.000], [0.95, 0.166, 0.107, 0.002],
		[1.02, 0.153, 0.099, 0.004], [1.10, 0.152, 0.097, 0.006], [1.18, 0.160, 0.103, 0.008], [1.26, 0.172, 0.109, 0.010],
		[1.33, 0.184, 0.115, 0.010], [1.39, 0.192, 0.108, 0.004], [1.43, 0.165, 0.090, 0.000], [1.46, 0.100, 0.072, 0.000], [1.49, 0.058, 0.058, 0.000],
	]
	var rings: Array = []
	var zone := func(p: Vector3, _th: float) -> int:
		if p.y < 0.935:
			return Zone.SHORTS
		if p.y > 1.455:
			return Zone.SKIN
		if p.y > 1.425 and p.y <= 1.455:
			return Zone.TRIM
		return Zone.JERSEY
	var ao := func(p: Vector3, _z: int) -> float:
		# Mas oscuro en la cintura y abajo, bajo la axila (laterales altos) y bajo el cuello.
		return clampf(0.84 + 0.16 * smoothstep(0.80, 1.30, p.y) - 0.10 * smoothstep(1.44, 1.48, p.y), 0.55, 1.0)
	for r in rows:
		rings.append({"c": Vector3(r[3], r[0], 0.0), "a": Vector3(0, 0, 1), "b": Vector3(1, 0, 0), "ra": r[1], "rb": r[2],
			"zone": zone, "ao": ao, "w": _torso_w(r[0])})
	_loft(rings, [true, true])

# --- Cuello y cabeza --------------------------------------------------------------------------------------------------

func _neck_and_head() -> void:
	var skin := func(_p: Vector3, _t: float) -> int: return Zone.SKIN
	var rings: Array = []
	for y in [1.43, 1.47, 1.51, 1.55, 1.58]:
		var w := {}
		w[_b("Spine2")] = 1.0 - _x(y, 1.43, 1.47)
		w[_b("Neck")] = _x(y, 1.43, 1.47) * (1.0 - _x(y, 1.50, 1.56))
		w[_b("Head")] = _x(y, 1.50, 1.56)
		rings.append({"c": Vector3(0.006, y, 0.0), "a": Vector3(0, 0, 1), "b": Vector3(1, 0, 0), "ra": 0.054, "rb": 0.057, "zone": skin,
			"ao": func(p: Vector3, _z: int) -> float: return 0.80 + 0.2 * smoothstep(1.43, 1.56, p.y), "w": w})
	_loft(rings, [false, false])
	# Cabeza: anillos desde la barbilla a la coronilla.
	var rows := _dense([
		[1.528, 0.046, 0.056, 0.026], [1.552, 0.061, 0.073, 0.022], [1.580, 0.073, 0.089, 0.017], [1.610, 0.080, 0.097, 0.013],
		[1.640, 0.083, 0.101, 0.011], [1.670, 0.082, 0.100, 0.009], [1.700, 0.076, 0.093, 0.006], [1.730, 0.063, 0.079, 0.003],
		[1.755, 0.041, 0.056, 0.0], [1.768, 0.017, 0.026, 0.0], [1.775, 0.006, 0.010, 0.0],
	], 0.0125)
	var hrings: Array = []
	var hzone := func(p: Vector3, th: float) -> int:
		# th = 0 apunta a +Z (lateral); el frente de la cara es +X. Altura de la linea del pelo segun lo de frente que este el punto.
		var front: float = sin(th)   # b = +X
		var hairline: float = lerpf(1.595, 1.708, smoothstep(-0.1, 0.7, front))
		hairline = minf(hairline, lerpf(hairline, 1.655, smoothstep(0.5, 0.95, absf(cos(th)))))   # patillas
		return Zone.HAIR if p.y > hairline else Zone.SKIN
	var hmove := func(p: Vector3, z: int, r: Dictionary) -> Vector3:
		if z != Zone.HAIR:
			return p
		var c: Vector3 = r["c"]
		var out := Vector3(p.x - c.x, 0.0, p.z - c.z)
		return p + out.normalized() * 0.007 + Vector3(0, 0.003, 0)
	for r in rows:
		var w := {}
		w[_b("Neck")] = 1.0 - _x(r[0], 1.545, 1.60)
		w[_b("Head")] = _x(r[0], 1.545, 1.60)
		hrings.append({"c": Vector3(r[3], r[0], 0.0), "a": Vector3(0, 0, 1), "b": Vector3(1, 0, 0), "ra": r[1], "rb": r[2], "zone": hzone, "move": hmove,
			"ao": func(p: Vector3, _z: int) -> float: return 0.75 + 0.25 * smoothstep(1.54, 1.62, p.y), "w": w})
	_loft(hrings, [true, true], SEG_HEAD)
	var head_w := {_b("Head"): 1.0}
	# Orejas, nariz y ojos.
	for s in [-1, 1]:
		_ellipsoid(Vector3(0.0, 1.645, float(s) * 0.081), Basis.IDENTITY, Vector3(0.016, 0.026, 0.009), Zone.SKIN, head_w)
		_ellipsoid(Vector3(0.099, 1.664, float(s) * 0.031), Basis.IDENTITY, Vector3(0.008, 0.008, 0.011), Zone.EYE, head_w)
		_ellipsoid(Vector3(0.094, 1.683, float(s) * 0.033), Basis.IDENTITY, Vector3(0.007, 0.0035, 0.017), Zone.HAIR, head_w)
	_ellipsoid(Vector3(0.108, 1.632, 0.0), Basis(Vector3(0, 0, 1), deg_to_rad(-12.0)), Vector3(0.021, 0.026, 0.014), Zone.SKIN, head_w)
	_ellipsoid(Vector3(0.098, 1.596, 0.0), Basis.IDENTITY, Vector3(0.010, 0.0065, 0.024), Zone.LIPS, head_w)

## Filas [y, a, b, c] interpoladas con suavizado cada `step` metros de altura (cabeza con mas anillos: linea del pelo limpia).
static func _dense(rows: Array, step: float) -> Array:
	var out: Array = []
	for i in range(rows.size() - 1):
		var y0: float = rows[i][0]
		var y1: float = rows[i + 1][0]
		var n: int = maxi(int(round((y1 - y0) / step)), 1)
		for k in n:
			var u: float = float(k) / float(n)
			u = u * u * (3.0 - 2.0 * u)
			var row: Array = [lerpf(y0, y1, float(k) / float(n))]
			for j in range(1, 4):
				row.append(lerpf(rows[i][j], rows[i + 1][j], u))
			out.append(row)
	out.append(rows[rows.size() - 1])
	return out

func _ellipsoid(c: Vector3, basis: Basis, radii: Vector3, zone: int, w: Dictionary, rings_n: int = 6, seg: int = 10) -> void:
	var rings: Array = []
	for k in range(1, rings_n):
		var ph: float = PI * float(k) / float(rings_n)
		var local := Vector3(0.0, cos(ph) * radii.y, 0.0)
		rings.append({"c": c + basis * local, "a": basis * Vector3(0, 0, 1), "b": basis * Vector3(1, 0, 0), "ra": sin(ph) * radii.z, "rb": sin(ph) * radii.x,
			"zone": func(_p: Vector3, _t: float) -> int: return zone, "w": w})
	_loft(rings, [true, true], seg)

# --- Piernas y botines ----------------------------------------------------------------------------------------------------

func _leg(side: int) -> void:
	var n: String = "Right" if side > 0 else "Left"
	var hip: Vector3 = _pos["mixamorig_%sUpLeg" % n]
	var knee: Vector3 = _pos["mixamorig_%sLeg" % n]
	var ankle: Vector3 = _pos["mixamorig_%sFoot" % n]
	var top: Vector3 = hip + Vector3(0.0, 0.07, 0.0)
	var chain := Chain.new([top, hip, knee, ankle], 0.06)
	var l_top: float = 0.07
	var l_knee: float = l_top + hip.distance_to(knee)
	var l_end: float = chain.length()
	var prof := [
		[0.0, 0.086, 0.092], [0.07, 0.090, 0.098], [0.15, 0.089, 0.097], [0.23, 0.082, 0.090], [0.31, 0.070, 0.077], [0.39, 0.061, 0.065],
		[l_knee, 0.056, 0.060], [l_knee + 0.06, 0.058, 0.062], [l_knee + 0.13, 0.060, 0.068], [l_knee + 0.21, 0.052, 0.057],
		[l_knee + 0.31, 0.041, 0.043], [l_knee + 0.38, 0.036, 0.038], [l_end, 0.035, 0.037],
	]
	var h_hip := l_top
	var rings: Array = []
	var s := 0.0
	while s < l_end + 0.001:
		var pt: Array = chain.at(s)
		var ax: Array = _axes(pt[1], Vector3(0, 0, 1))
		var rr: Vector2 = _prof(prof, s)
		var w := {}
		var wh: float = 1.0 - _x(s, h_hip - 0.04, h_hip + 0.05)
		var wk: float = _x(s, l_knee - 0.05, l_knee + 0.05)
		var wf: float = _x(s, l_end - 0.05, l_end)
		w[_b("Hips")] = wh
		w[_b("%sUpLeg" % n)] = (1.0 - wh) * (1.0 - wk)
		w[_b("%sLeg" % n)] = (1.0 - wh) * wk * (1.0 - wf * 0.6)
		w[_b("%sFoot" % n)] = wf * 0.6
		var shift := Vector3.ZERO
		# Pantorrilla hacia atras y cuadriceps hacia delante.
		shift.x = -0.012 * exp(-pow((s - (l_knee + 0.13)) / 0.07, 2.0)) + 0.006 * exp(-pow((s - 0.17) / 0.09, 2.0))
		var inner: float = float(-side)
		rings.append({"c": (pt[0] as Vector3) + shift, "a": ax[0], "b": ax[1], "ra": rr.x, "rb": rr.y,
			"zone": func(p: Vector3, _th: float) -> int:
				if p.y > 0.655:
					return Zone.SHORTS
				if p.y > 0.505:
					return Zone.SKIN
				if p.y > 0.488:
					return Zone.TRIM
				return Zone.SOCKS,
			"ao": func(p: Vector3, _z: int) -> float:
				var inside: float = clampf(((p.z * float(side)) - 0.03) / 0.07, 0.0, 1.0)   # 1 = lado de afuera
				return 0.78 + 0.22 * inside - 0.0 * inner, "w": w})
		s += SPACING
	_loft(rings, [false, false])

func _boot(side: int) -> void:
	var n: String = "Right" if side > 0 else "Left"
	var ankle: Vector3 = _pos["mixamorig_%sFoot" % n]
	var z0: float = ankle.z
	# Largo del botin (2026-11-05): talon a 6 cm detras del tobillo y punta a 18 cm delante (2.5 cm por delante de la punta
	# del pie del esqueleto, 15.8 cm): ~0.26 m con las tapas, el pie de una persona de 1.74 m (15 % de la talla), como los
	# jugadores de UCS. Antes iba de -0.088 a 0.248 (~0.40 m con las tapas: 1.8 veces la pelota; se veia enorme).
	var rows := [
		[-0.060, 0.055, 0.034, 0.045], [-0.046, 0.060, 0.040, 0.055], [-0.020, 0.082, 0.043, 0.072], [0.015, 0.078, 0.044, 0.066],
		[0.055, 0.056, 0.045, 0.048], [0.095, 0.040, 0.046, 0.037], [0.130, 0.033, 0.045, 0.031], [0.160, 0.029, 0.040, 0.026], [0.183, 0.027, 0.028, 0.021],
	]
	var rings: Array = []
	for r in rows:
		var x: float = ankle.x + r[0]
		var w := {}
		var wt: float = _x(x - ankle.x, 0.085, 0.15)
		var wl: float = (1.0 - _x(r[2] * 0.0 + r[1], 0.07, 0.11)) * (1.0 - _x(x, -0.10, 0.0)) * 0.0
		w[_b("%sFoot" % n)] = 1.0 - wt
		w[_b("%sToeBase" % n)] = wt
		var top_collar: float = _x(r[1] + r[3], 0.12, 0.17)
		if top_collar > 0.0:
			w[_b("%sLeg" % n)] = top_collar * 0.35
			w[_b("%sFoot" % n)] = (1.0 - wt) * (1.0 - top_collar * 0.35)
		rings.append({"c": Vector3(x, r[1], z0), "a": Vector3(0, 0, 1), "b": Vector3(0, -1, 0), "ra": r[2], "rb": r[3],
			"zone": func(p: Vector3, _th: float) -> int:
				if p.y < 0.011:
					return Zone.SOLE
				if p.y > 0.130 and p.x < ankle.x + 0.0:
					return Zone.TRIM
				return Zone.BOOTS,
			"ao": func(p: Vector3, _z: int) -> float: return 0.80 + 0.2 * smoothstep(0.0, 0.08, p.y), "w": w})
	_loft(rings, [true, true], 14)

# --- Brazos y manos -----------------------------------------------------------------------------------------------------------

func _arm(side: int) -> void:
	var n: String = "Right" if side > 0 else "Left"
	var sh: Vector3 = _pos["mixamorig_%sArm" % n]
	var el: Vector3 = _pos["mixamorig_%sForeArm" % n]
	var wr: Vector3 = _pos["mixamorig_%sHand" % n]
	var l_up: float = sh.distance_to(el)
	var l_fore: float = el.distance_to(wr)
	var d_up: Vector3 = (el - sh).normalized()
	var chain := Chain.new([sh - d_up * 0.03, sh, el, wr], 0.05)
	var l_sh: float = 0.03
	var l_el: float = l_sh + l_up
	var l_end: float = chain.length()
	var prof := [
		[0.0, 0.030, 0.032], [0.016, 0.046, 0.048], [l_sh + 0.01, 0.052, 0.054], [l_sh + 0.06, 0.050, 0.052], [l_sh + 0.12, 0.047, 0.049], [l_sh + 0.20, 0.042, 0.044], [l_el, 0.038, 0.040],
		[l_el + 0.06, 0.042, 0.044], [l_el + 0.15, 0.036, 0.037], [l_el + 0.25, 0.030, 0.031], [l_end, 0.026, 0.026],
	]
	var rings: Array = []
	var s := 0.0
	var sleeve_end: float = l_sh + 0.13
	while s < l_end + 0.001:
		var pt: Array = chain.at(s)
		var ax: Array = _axes(pt[1], Vector3(1, 0, 0))
		var rr: Vector2 = _prof(prof, s)
		var w := {}
		var wsh: float = 1.0 - _x(s, l_sh - 0.03, l_sh + 0.04)
		var wel: float = _x(s, l_el - 0.04, l_el + 0.04)
		var whd: float = _x(s, l_end - 0.05, l_end)
		w[_b("Spine2")] = wsh * 0.25
		w[_b("%sShoulder" % n)] = wsh * 0.25
		w[_b("%sArm" % n)] = (1.0 - wsh * 0.5) * (1.0 - wel)
		w[_b("%sForeArm" % n)] = wel * (1.0 - whd * 0.5)
		w[_b("%sHand" % n)] = whd * 0.5
		rings.append({"c": pt[0], "a": ax[0], "b": ax[1], "ra": rr.x, "rb": rr.y,
			"zone": func(_p: Vector3, _th: float) -> int:
				if s < sleeve_end - 0.012:
					return Zone.JERSEY
				if s < sleeve_end + 0.004:
					return Zone.TRIM
				return Zone.SKIN,
			"ao": func(p: Vector3, _z: int) -> float: return 0.80 + 0.20 * smoothstep(0.0, 0.25, absf(p.z) - 0.19), "w": w})
		s += SPACING
	_loft(rings, [true, false])
	# Mano: palma plana mirando al cuerpo, con el pulgar hacia delante.
	var d_f: Vector3 = (wr - el).normalized()
	var palm_n: Vector3 = Vector3(0, 0, float(-side))   # normal de la palma hacia el cuerpo
	var width: Vector3 = (palm_n.cross(d_f)).normalized()   # eje ancho de la mano
	var hax: Array = [width, d_f.cross(width)]
	var hrows := [[-0.012, 0.026, 0.026], [0.02, 0.034, 0.021], [0.05, 0.043, 0.019], [0.08, 0.040, 0.016], [0.100, 0.030, 0.013], [0.110, 0.012, 0.008]]
	var hrings: Array = []
	for r in hrows:
		var wd := {}
		wd[_b("%sHand" % n)] = 1.0 - _x(r[0], -0.012, 0.02) * 0.0
		if r[0] < 0.02:
			wd[_b("%sForeArm" % n)] = 1.0 - _x(r[0], -0.012, 0.03)
			wd[_b("%sHand" % n)] = _x(r[0], -0.012, 0.03)
		hrings.append({"c": wr + d_f * (r[0] + 0.0), "a": hax[0], "b": hax[1], "ra": r[1], "rb": r[2],
			"zone": func(_p: Vector3, _t: float) -> int: return Zone.SKIN, "ao": func(_p: Vector3, _z: int) -> float: return 0.9, "w": wd})
	_loft(hrings, [false, true], 12)
	var thumb_w := {_b("%sHand" % n): 1.0}
	var tc: Vector3 = wr + d_f * 0.045 + width * 0.040 + palm_n * 0.004
	_ellipsoid(tc, Basis(Vector3(0, 0, 1), 0.0), Vector3(0.012, 0.030, 0.012), Zone.SKIN, thumb_w, 5, 8)

# --- Guardado -------------------------------------------------------------------------------------------------------------------

func _save() -> void:
	var pose := JsonRig.Pose.A
	var root := Node3D.new()
	root.name = "JsonHuman"
	var arm := Node3D.new()
	arm.name = "Armature"
	root.add_child(arm)
	var sk: Skeleton3D = JsonRig.build_skeleton(pose)
	arm.add_child(sk)
	# Malla en unidades del modelo (1.0 = 1.75 m).
	var verts := PackedVector3Array()
	for p in _v:
		verts.append(p * JsonRig.UNIT)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in verts.size():
		st.set_color(_col[i])
		st.set_bones(PackedInt32Array([_bn[i * 4], _bn[i * 4 + 1], _bn[i * 4 + 2], _bn[i * 4 + 3]]))
		st.set_weights(PackedFloat32Array([_wt[i * 4], _wt[i * 4 + 1], _wt[i * 4 + 2], _wt[i * 4 + 3]]))
		st.add_vertex(verts[i])
	for k in _idx:
		st.add_index(k)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var skin := Skin.new()
	for i in JsonRig.BONES.size():
		skin.add_named_bind(JsonRig.BONES[i], PoseSamplerLite.bone_global(sk, i).affine_inverse())
	var mi := MeshInstance3D.new()
	mi.name = "JsonHumanMesh"
	mi.mesh = mesh
	mi.skin = skin
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	_own(root, root)
	var ps := PackedScene.new()
	var err: int = ps.pack(root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
		err = ResourceSaver.save(ps, OUT)
	print("JSON_HUMAN guardado %s (error=%d): %d vertices, %d triangulos" % [OUT, err, verts.size(), _idx.size() / 3])
	get_tree().quit(0 if err == OK else 1)

func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)

class PoseSamplerLite:
	static func bone_global(sk: Skeleton3D, bone: int) -> Transform3D:
		var chain: Array[int] = []
		var b: int = bone
		while b >= 0:
			chain.append(b)
			b = sk.get_bone_parent(b)
		var t := Transform3D.IDENTITY
		for i in range(chain.size() - 1, -1, -1):
			t = t * sk.get_bone_rest(chain[i])
		return t
