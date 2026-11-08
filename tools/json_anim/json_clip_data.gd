class_name JsonClipData
extends RefCounted
## Un clip de los JSON de animacion (animaciones_futbol5_JSON): posiciones de 19 articulaciones en fotogramas clave
## irregulares (times), a 60 fps, ya centradas en la pelvis (la trayectoria de la pelvis va aparte en `root`).
## Datos en el espacio del juego (x derecha, y arriba, z atras; adelante = -z); aqui se pasan al espacio del modelo
## (X adelante, Y arriba, Z derecha), en metros. El espejo intercambia izquierda y derecha.

var id: String = ""
var source: String = ""
var fps: float = 60.0
var frames: int = 0
var times: PackedFloat32Array = PackedFloat32Array()
var key_pos: Array = []                  # por clave: Dictionary articulacion -> Vector3 (modelo, metros)
var root: PackedVector2Array = PackedVector2Array()   # por clave: (adelante, derecha) de la pelvis en el marco del inicio
var meta: Dictionary = {}
var mirrored: bool = false

static func load_file(path: String, mirror: bool = false) -> JsonClipData:
	var txt: String = FileAccess.get_file_as_string(path)
	if txt == "":
		return null
	var d: Variant = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY or not (d as Dictionary).has("joints"):
		return null
	var c := JsonClipData.new()
	c.source = path.get_file()
	c.mirrored = mirror
	c.fps = float(d.get("fps", 60.0))
	c.frames = int(d.get("frames", 0))
	c.meta = d.get("meta", {})
	var names: Array = d["joint_names"]
	for t in d["times"]:
		c.times.append(float(t))
	for k in (d["joints"] as Array).size():
		var row: Array = d["joints"][k]
		var p := {}
		for i in names.size():
			var v: Array = row[i]
			var game := Vector3(float(v[0]), float(v[1]), float(v[2]))
			var jn: String = names[i]
			if mirror:
				game.x = -game.x
				if jn.begins_with("l_"):
					jn = "r_" + jn.substr(2)
				elif jn.begins_with("r_"):
					jn = "l_" + jn.substr(2)
			p[jn] = JsonRig.data_to_model(game)
		c.key_pos.append(p)
		var r: Array = d["root"][k]
		var rx: float = float(r[0])
		c.root.append(Vector2(-float(r[1]), -rx if mirror else rx))
	return c

func length_seconds() -> float:
	return float(frames) / fps

## Articulaciones en el fotograma `f` (60 fps, fraccionario), interpoladas con una cubica de Hermite entre claves.
func sample(f: float) -> Dictionary:
	f = clampf(f, times[0], times[times.size() - 1])
	var n: int = times.size()
	var i: int = 0
	while i < n - 2 and f > times[i + 1]:
		i += 1
	var t0: float = times[i]
	var t1: float = times[i + 1]
	var u: float = 0.0 if t1 <= t0 else (f - t0) / (t1 - t0)
	var out := {}
	var a: Dictionary = key_pos[i]
	var b: Dictionary = key_pos[i + 1]
	var pa: Dictionary = key_pos[maxi(i - 1, 0)]
	var pb: Dictionary = key_pos[mini(i + 2, n - 1)]
	var tpa: float = times[maxi(i - 1, 0)]
	var tpb: float = times[mini(i + 2, n - 1)]
	var h: float = t1 - t0
	for jn in a:
		var p0: Vector3 = a[jn]
		var p1: Vector3 = b[jn]
		var m0: Vector3 = (p1 - (pa[jn] as Vector3)) / maxf(t1 - tpa, 1e-4) if i > 0 else (p1 - p0) / maxf(h, 1e-4)
		var m1: Vector3 = ((pb[jn] as Vector3) - p0) / maxf(tpb - t0, 1e-4) if i + 2 < n else (p1 - p0) / maxf(h, 1e-4)
		var u2: float = u * u
		var u3: float = u2 * u
		out[jn] = p0 * (2.0 * u3 - 3.0 * u2 + 1.0) + m0 * h * (u3 - 2.0 * u2 + u) + p1 * (-2.0 * u3 + 3.0 * u2) + m1 * h * (u3 - u2)
	return out

## Trayectoria de la pelvis (adelante, derecha) en el fotograma `f`, interpolada.
func sample_root(f: float) -> Vector2:
	f = clampf(f, times[0], times[times.size() - 1])
	var n: int = times.size()
	var i: int = 0
	while i < n - 2 and f > times[i + 1]:
		i += 1
	var u: float = 0.0 if times[i + 1] <= times[i] else (f - times[i]) / (times[i + 1] - times[i])
	return root[i].lerp(root[i + 1], u)
