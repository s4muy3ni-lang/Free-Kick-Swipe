extends Node
## Paso 1 de la conversion de Mixamo: reproduce cada animacion de los GLB (assets/animations/source/mixamo/, copia
## intacta de animaciones_mixamo.zip) sobre SU esqueleto (el del futbolista de Tripo, 23 huesos mixamorig_*, pose T),
## con cinematica directa a 60 fps, y escribe las posiciones de las 19 articulaciones en el MISMO formato que los JSON del
## banco actual (espacio del juego: x derecha, y arriba, z atras; metros; centradas en la pelvis en horizontal, con la
## trayectoria de la pelvis en «root»). Asi el paso 2 es el convertidor ya probado (tools/json_anim/build_json_library),
## que retargetea al esqueleto canonico del juego (JsonRig, el del humano JSON) y mide raiz, rumbo, contacto del pie y
## trayectorias de manos y pies con el mismo codigo que el banco actual. Los GLB no se modifican.
##
## Uso: MIXAMO_JSON=<carpeta de salida> godot --headless --path . res://tools/mixamo/export_mixamo_joints.tscn
## Salida: <carpeta>/mxNNN_<nombre>.json (NNN = orden en tools/mixamo/selection_mixamo.json) y index.json.

const FILES := {"campo": "res://assets/animations/source/mixamo/mixamo_campo.glb",
	"arquero": "res://assets/animations/source/mixamo/mixamo_arquero.glb"}
const SEL := "res://tools/mixamo/selection_mixamo.json"
const FPS := 60.0
## El modelo mide 1.0 de alto = 1.75 m (LEEME del paquete y JsonRig.UNIT).
const METERS := 1.75
## Punto «head» de los datos: centro de la cabeza sobre el origen del hueso Head (JsonRig.HEAD_POINT_UP).
const HEAD_UP := 0.08
const JOINTS := {
	"pelvis": "mixamorig_Hips", "chest": "mixamorig_Spine2", "head": "mixamorig_Head",
	"l_clavicle": "mixamorig_LeftShoulder", "l_shoulder": "mixamorig_LeftArm", "l_elbow": "mixamorig_LeftForeArm", "l_wrist": "mixamorig_LeftHand",
	"r_clavicle": "mixamorig_RightShoulder", "r_shoulder": "mixamorig_RightArm", "r_elbow": "mixamorig_RightForeArm", "r_wrist": "mixamorig_RightHand",
	"l_hip": "mixamorig_LeftUpLeg", "l_knee": "mixamorig_LeftLeg", "l_ankle": "mixamorig_LeftFoot", "l_toe": "mixamorig_LeftToeBase",
	"r_hip": "mixamorig_RightUpLeg", "r_knee": "mixamorig_RightLeg", "r_ankle": "mixamorig_RightFoot", "r_toe": "mixamorig_RightToeBase",
}

var out_dir: String = ""

func _ready() -> void:
	out_dir = OS.get_environment("MIXAMO_JSON")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var sel: Array = JSON.parse_string(FileAccess.get_file_as_string(SEL))["clips"]
	var index := []
	for k in FILES:
		var scene: Node = (load(FILES[k]) as PackedScene).instantiate()
		add_child(scene)
		var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var frame: Array = _axes(sk)
		var refs: Dictionary = _rest_refs(sk, frame)
		for lib_name in ap.get_animation_library_list():
			var lib: AnimationLibrary = ap.get_animation_library(lib_name)
			for an in lib.get_animation_list():
				var num: int = -1
				for i in sel.size():
					if String(sel[i]["source"]) == an:
						num = i
				if num < 0:
					push_error("%s no esta en la seleccion" % an)
					continue
				var a: Animation = lib.get_animation(an)
				var d: Dictionary = _export(sk, a, frame, String(scene.get_path_to(sk)), refs)
				if bool(sel[num].get("reconstruct", false)):
					_reconstruct_root(d)
					d["meta"]["ground_speed"] = _travel(d) / maxf(a.length, 0.05)
				elif sel[num].has("inplace_of"):
					# Variante «en el sitio»: el mismo movimiento con la cadera fija. Su velocidad sobre el suelo (la que usa el
					# juego para que el bucle no patine) es la de su gemela; la raiz queda en cero.
					var root0: Array = d["root"]
					_reconstruct_root(d)
					d["meta"]["ground_speed"] = _travel(d) / maxf(a.length, 0.05)
					d["root"] = root0
					d["meta"]["root_reconstructed"] = false
				if bool(sel[num].get("kick", false)):
					_detect_kick(d, sel[num])
				var file: String = "mx%03d_%s.json" % [num, an]
				var f := FileAccess.open(out_dir.path_join(file), FileAccess.WRITE)
				f.store_string(JSON.stringify(d))
				f.close()
				var last: Array = d["root"][(d["root"] as Array).size() - 1]
				index.append({"source": an, "glb": k, "file": file, "frames": d["frames"], "length": a.length,
					"floor_min_cm": d["meta"]["floor_min_cm"], "travel_m": Vector2(float(last[0]), float(last[1])).length(),
					"reconstructed": bool(sel[num].get("reconstruct", false)), "support_ratio": d["meta"].get("support_ratio", 0.0)})
		scene.queue_free()
	var fi := FileAccess.open(out_dir.path_join("index.json"), FileAccess.WRITE)
	fi.store_string(JSON.stringify(index, "\t"))
	print("EXPORTADOS %d clips de Mixamo a %s" % [index.size(), out_dir])
	get_tree().quit()

static func _travel(d: Dictionary) -> float:
	var last: Array = d["root"][(d["root"] as Array).size() - 1]
	return Vector2(float(last[0]), float(last[1])).length()

## Ejes del modelo en la pose de reposo: derecha = de la cadera izquierda a la derecha, arriba = +Y, adelante = arriba x
## derecha (la misma convencion que el convertidor: fwd = UP.cross(lat)). Se verifica con las puntas de los pies.
func _axes(sk: Skeleton3D) -> Array:
	var g: Dictionary = _globals(sk, null, 0.0)
	var lat: Vector3 = (g[sk.find_bone("mixamorig_RightUpLeg")] as Transform3D).origin - (g[sk.find_bone("mixamorig_LeftUpLeg")] as Transform3D).origin
	lat.y = 0.0
	var right: Vector3 = lat.normalized()
	var up := Vector3.UP
	var fwd: Vector3 = up.cross(right).normalized()
	var toe: Vector3 = (g[sk.find_bone("mixamorig_RightToeBase")] as Transform3D).origin - (g[sk.find_bone("mixamorig_RightFoot")] as Transform3D).origin
	print("ejes del modelo: derecha %s adelante %s (punta del pie . adelante = %.2f)" % [right, fwd, toe.normalized().dot(fwd)])
	return [right, up, fwd]

## Transformadas globales (espacio del esqueleto) de todos los huesos en el instante t (sin animacion: reposo).
func _globals(sk: Skeleton3D, a: Animation, t: float, skel_path: String = "Armature/Skeleton3D") -> Dictionary:
	var g := {}
	for i in sk.get_bone_count():
		var rest: Transform3D = sk.get_bone_rest(i)
		var basis: Basis = rest.basis
		var origin: Vector3 = rest.origin
		if a != null:
			var bp := NodePath(skel_path + ":" + sk.get_bone_name(i))
			var tr: int = a.find_track(bp, Animation.TYPE_ROTATION_3D)
			if tr >= 0:
				basis = Basis(a.rotation_track_interpolate(tr, t)).scaled(rest.basis.get_scale())
			var tp: int = a.find_track(bp, Animation.TYPE_POSITION_3D)
			if tp >= 0:
				origin = a.position_track_interpolate(tp, t)
		var local := Transform3D(basis, origin)
		var p: int = sk.get_bone_parent(i)
		g[i] = (g[p] as Transform3D) * local if p >= 0 else local
	return g

## Espacio del esqueleto -> espacio del juego (x derecha, y arriba, z atras), sin escala.
static func _to_game(v: Vector3, frame: Array) -> Vector3:
	return Vector3(v.dot(frame[0]), v.dot(frame[1]), -v.dot(frame[2]))

static func _basis_to_game(b: Basis, frame: Array) -> Basis:
	return Basis(_to_game(b.x, frame), _to_game(b.y, frame), _to_game(b.z, frame)).orthonormalized()

## Referencias del reposo para pasar a las PROPORCIONES del esqueleto del juego (JsonRig): el esqueleto de Tripo tiene
## las piernas mas largas (cadera-tobillo 0,84 m frente a 0,76 m), el tobillo mas bajo (5 cm frente a 9,5 cm) y la
## «punta» (origen de ToeBase) a 5 cm del tobillo (en el juego, 18 cm). Sin esto, los pies del juego quedaban hundidos
## unos 7 cm y las rodillas estiradas. Devuelve la escala de la pierna, la altura del tobillo en reposo y, por pie, el
## vector tobillo -> punta del juego expresado en el marco del hueso Foot de Tripo.
func _rest_refs(sk: Skeleton3D, frame: Array) -> Dictionary:
	var g: Dictionary = _globals(sk, null, 0.0)
	var pos := {}
	for jn in JOINTS:
		pos[jn] = _to_game((g[sk.find_bone(JOINTS[jn])] as Transform3D).origin, frame) * METERS
	var leg := 0.0
	for s in ["l_", "r_"]:
		leg += (pos[s + "hip"] as Vector3).distance_to(pos[s + "knee"]) + (pos[s + "knee"] as Vector3).distance_to(pos[s + "ankle"])
	leg *= 0.5
	var rp: Dictionary = JsonRig.rest_positions(JsonRig.Pose.A)
	# Tobillo -> punta del reposo del juego (modelo: X adelante, Y arriba, Z derecha) en el espacio del juego.
	var mt: Vector3 = (rp["mixamorig_RightToeBase"] as Vector3) - (rp["mixamorig_RightFoot"] as Vector3)
	var toe_game := Vector3(mt.z, mt.y, -mt.x)
	var refs := {"k_leg": (JsonRig.THIGH + JsonRig.SHIN) / leg,
		"ankle_y": 0.5 * ((pos["l_ankle"] as Vector3).y + (pos["r_ankle"] as Vector3).y),
		"chest_len": (rp["mixamorig_Spine2"] as Vector3).distance_to(rp["mixamorig_Hips"]),
		"head_len": JsonRig.head_point().distance_to(rp["mixamorig_Spine2"]),
		"clav_len": (rp["mixamorig_LeftShoulder"] as Vector3).distance_to(rp["mixamorig_Spine2"])}
	for side in [["l_", "mixamorig_LeftFoot"], ["r_", "mixamorig_RightFoot"]]:
		var bf: Basis = _basis_to_game((g[sk.find_bone(side[1])] as Transform3D).basis, frame)
		refs[side[0] + "toe_local"] = bf.transposed() * toe_game
	print("reposo de Tripo: pierna %.3f m (juego %.3f, escala %.3f), tobillo a %.3f m (juego %.3f)" % [leg,
		JsonRig.THIGH + JsonRig.SHIN, refs["k_leg"], refs["ankle_y"], REST_ANKLE_Y])
	return refs

const REST_ANKLE_Y := 0.095
## Peso del pie mas bajo al fijar la altura de la pelvis (m): el pie de apoyo manda.
const PIN_SOFT := 0.03

## Una pose (articulaciones del juego en metros, absolutas) con las DIRECCIONES de cada segmento de Tripo y las LONGITUDES
## del esqueleto del juego. La pelvis se escala en horizontal con la pierna (la zancada queda igual que el pie, sin
## patinar) y su altura sale de fijar el tobillo mas bajo a la altura del tobillo del juego (mismo despegue del suelo que
## en Tripo, escalado). Las puntas salen de la orientacion del hueso Foot (la direccion real del pie).
func _to_rig(p: Dictionary, foot_b: Dictionary, refs: Dictionary) -> Dictionary:
	var k: float = refs["k_leg"]
	var pel: Vector3 = p["pelvis"]
	var rel := {"pelvis": Vector3.ZERO}
	var u := func(a: String, b: String) -> Vector3:
		var v: Vector3 = (p[b] as Vector3) - (p[a] as Vector3)
		return v.normalized() if v.length_squared() > 1e-10 else Vector3.DOWN
	rel["chest"] = u.call("pelvis", "chest") * float(refs["chest_len"])
	rel["head"] = (rel["chest"] as Vector3) + u.call("chest", "head") * float(refs["head_len"])
	for s in ["l_", "r_"]:
		rel[s + "hip"] = u.call("pelvis", s + "hip") * JsonRig.HIP_HALF
		rel[s + "knee"] = (rel[s + "hip"] as Vector3) + u.call(s + "hip", s + "knee") * JsonRig.THIGH
		rel[s + "ankle"] = (rel[s + "knee"] as Vector3) + u.call(s + "knee", s + "ankle") * JsonRig.SHIN
		rel[s + "toe"] = (rel[s + "ankle"] as Vector3) + (foot_b[s.left(1)] as Basis) * (refs[s + "toe_local"] as Vector3)
		rel[s + "clavicle"] = (rel["chest"] as Vector3) + u.call("chest", s + "clavicle") * float(refs["clav_len"])
		rel[s + "shoulder"] = (rel[s + "clavicle"] as Vector3) + u.call(s + "clavicle", s + "shoulder") * JsonRig.CLAVICLE
		rel[s + "elbow"] = (rel[s + "shoulder"] as Vector3) + u.call(s + "shoulder", s + "elbow") * JsonRig.UPPER_ARM
		rel[s + "wrist"] = (rel[s + "elbow"] as Vector3) + u.call(s + "elbow", s + "wrist") * JsonRig.FOREARM
	# Altura de la pelvis: cada pie propone la que deja su tobillo a la altura escalada de Tripo; manda el mas bajo.
	var lo: float = minf((p["l_ankle"] as Vector3).y, (p["r_ankle"] as Vector3).y)
	var wsum := 0.0
	var ysum := 0.0
	for s in ["l_", "r_"]:
		var ay: float = (p[s + "ankle"] as Vector3).y
		var want: float = REST_ANKLE_Y + k * (ay - float(refs["ankle_y"]))
		var w: float = exp(-(ay - lo) / PIN_SOFT)
		ysum += w * (want - (rel[s + "ankle"] as Vector3).y)
		wsum += w
	var base := Vector3(pel.x * k, ysum / wsum, pel.z * k)
	var out := {}
	for jn in p:
		out[jn] = base + (rel[jn] as Vector3)
	return out

func _export(sk: Skeleton3D, a: Animation, frame: Array, skel_path: String, refs: Dictionary) -> Dictionary:
	var right: Vector3 = frame[0]
	var up: Vector3 = frame[1]
	var fwd: Vector3 = frame[2]
	var n: int = maxi(int(round(a.length * FPS)), 1)
	var names: Array = JOINTS.keys()
	var times := []
	var joints := []
	var root := []
	var p0 := Vector2.INF
	var floor_min := INF
	var head_idx: int = sk.find_bone("mixamorig_Head")
	for k in n + 1:
		var t: float = minf(float(k) / FPS, a.length)
		var g: Dictionary = _globals(sk, a, t, skel_path)
		var game := {}
		for jn in names:
			var tr: Transform3D = g[sk.find_bone(JOINTS[jn])]
			var p: Vector3 = tr.origin
			if jn == "head":
				p += (g[head_idx] as Transform3D).basis.y.normalized() * (HEAD_UP / METERS)
			# Espacio del juego: x = derecha, y = arriba, z = atras (adelante = -z), en metros.
			game[jn] = Vector3(p.dot(right), p.dot(up), -p.dot(fwd)) * METERS
		var foot_b := {"l": _basis_to_game((g[sk.find_bone("mixamorig_LeftFoot")] as Transform3D).basis, frame),
			"r": _basis_to_game((g[sk.find_bone("mixamorig_RightFoot")] as Transform3D).basis, frame)}
		game = _to_rig(game, foot_b, refs)
		var pel: Vector3 = game["pelvis"]
		if p0 == Vector2.INF:
			p0 = Vector2(pel.x, pel.z)
		var row := []
		for jn in names:
			var q: Vector3 = game[jn]
			floor_min = minf(floor_min, q.y)
			row.append([q.x - pel.x, q.y, q.z - pel.z])
		times.append(k)
		joints.append(row)
		root.append([pel.x - p0.x, pel.z - p0.y])
	var last: Array = root[root.size() - 1]
	return {"fps": FPS, "frames": n, "joint_names": names, "times": times, "joints": joints, "root": root,
		"meta": {"source": "mixamo", "floor_min_cm": floor_min * 100.0, "travel_m": Vector2(float(last[0]), float(last[1])).length()}}

## El paquete no trae desplazamiento de raiz (la cadera queda fija en horizontal en todos los clips, incluso los que no son
## «inplace»). Se reconstruye con el pie de apoyo: mientras una articulacion del pie (punta o tobillo) esta en el suelo y
## casi quieta en vertical, el cuerpo avanza lo que ese apoyo retrocede respecto de la pelvis (el apoyo queda fijo en el
## suelo); en el aire se conserva la ultima velocidad horizontal. Solo para clips que deben desplazarse (reconstruct en la
## seleccion). Resultado en «root» (metros, espacio del juego, relativo al inicio), como en el banco actual.
## Pies: el apoyo es el pie (punta o tobillo, el mas bajo) que esta en el suelo; se mantiene el mismo pie hasta que el
## otro queda claramente mas abajo (histeresis), para no tomar como apoyo al pie que vuelve hacia adelante rozando el piso.
const FEET := {"l": ["l_toe", "l_ankle"], "r": ["r_toe", "r_ankle"]}
const SUPPORT_ABOVE := 0.06
const SWITCH_MARGIN := 0.02
const SUPPORT_VY := 0.5
## Con la pelvis por debajo de esta altura (m) el cuerpo esta en el suelo: la velocidad se frena (sin deslizarse metros).
const LYING_PELVIS := 0.45
const LYING_DAMP := 0.85

func _foot_low(row: Array, ix: Dictionary, side: String) -> Array:
	var best: Array = []
	for jn in FEET[side]:
		var q: Array = row[ix[jn]]
		if best.is_empty() or float(q[1]) < float(best[1]):
			best = [jn, float(q[1])]
	return best

## Cambio de apoyo: el pie nuevo solo pasa a ser apoyo si la velocidad del cuerpo que implica va hacia el mismo lado que
## la que trae el cuerpo (menos de STEADY_ANGLE grados). El pie que vuelve hacia adelante rozando el piso implica la
## velocidad contraria y queda descartado. Al empezar, el apoyo es el pie que sigue apoyado mas tiempo.
const STEADY_ANGLE := 75.0
const STEADY_MIN_SPEED := 0.3

func _implied(rows: Array, j: int, k: int) -> Vector2:
	var a: Array = rows[k - 1][j]
	var b: Array = rows[k][j]
	return -Vector2(float(b[0]) - float(a[0]), float(b[2]) - float(a[2]))

func _reconstruct_root(d: Dictionary) -> void:
	var names: Array = d["joint_names"]
	var rows: Array = d["joints"]
	var n: int = rows.size()
	var ix := {}
	for side in FEET:
		for jn in FEET[side]:
			ix[jn] = names.find(jn)
	var pel: int = names.find("pelvis")
	var floor_y := INF
	for row in rows:
		for side in FEET:
			floor_y = minf(floor_y, float(_foot_low(row, ix, side)[1]))
	# Candidatos a apoyo por cuadro (pie bajo y casi quieto en vertical) y cuanto siguen siendolo.
	var cands: Array = [{}]
	for k in range(1, n):
		var cand := {}
		for side in FEET:
			var lo: Array = _foot_low(rows[k], ix, side)
			var jn: String = lo[0]
			var vy: float = absf(float(rows[k][ix[jn]][1]) - float(rows[k - 1][ix[jn]][1])) * FPS
			if float(lo[1]) < floor_y + SUPPORT_ABOVE and vy < SUPPORT_VY:
				cand[side] = lo
		cands.append(cand)
	var run := {}
	for side in FEET:
		var r := PackedInt32Array()
		r.resize(n + 1)
		for k in range(n - 1, 0, -1):
			r[k] = r[k + 1] + 1 if (cands[k] as Dictionary).has(side) else 0
		run[side] = r
	var root := [[0.0, 0.0]]
	var vel := Vector2.ZERO
	var support := ""
	var prev_support := ""
	var stance: Array[Vector2] = []
	var supported := 0
	var cos_max: float = cos(deg_to_rad(STEADY_ANGLE))
	for k in range(1, n):
		var cand: Dictionary = cands[k]
		if supported == 0 and support == "" and not cand.is_empty():
			for side in cand:
				if support == "" or int(run[side][k]) > int(run[support][k]):
					support = side
		if support != "" and not cand.has(support):
			support = ""
			# En el aire: la velocidad media del ultimo apoyo (el final del apoyo, al despegar, la subestima).
			if stance.size() >= 3:
				var sum := Vector2.ZERO
				for v in stance:
					sum += v
				vel = sum / float(stance.size())
			stance.clear()
		for side in cand:
			if side == support:
				continue
			if support != "" and float(cand[side][1]) + SWITCH_MARGIN >= float(cand[support][1]):
				continue
			var vi: Vector2 = _implied(rows, ix[cand[side][0]], k) * FPS
			if supported == 0 or vel.length() < STEADY_MIN_SPEED or vi.dot(vel) > cos_max * vel.length() * vi.length():
				support = side
		if float(rows[k][pel][1]) < LYING_PELVIS:
			vel *= LYING_DAMP
		elif support != "":
			if support != prev_support:
				stance.clear()
			vel = _implied(rows, ix[cand[support][0]], k) * FPS
			stance.append(vel)
			supported += 1
		prev_support = support
		var prev: Array = root[k - 1]
		root.append([float(prev[0]) + vel.x / FPS, float(prev[1]) + vel.y / FPS])
	d["root"] = root
	d["meta"]["support_ratio"] = float(supported) / float(maxi(n - 1, 1))
	d["meta"]["root_reconstructed"] = true

## Golpeos: el paquete no dice cuando toca la pelota. Como en los JSON del banco actual (meta contact / kick_foot): el
## pie que patea es el de mayor velocidad de avance de la punta; el contacto, el fotograma de esa velocidad maxima con la
## punta baja (<= 0,45 m). El convertidor lo refina igual que con el banco actual.
const KICK_TOE_MAX_Y := 0.45

func _detect_kick(d: Dictionary, entry: Dictionary) -> void:
	var names: Array = d["joint_names"]
	var rows: Array = d["joints"]
	# contact_any (chilena): la pelota va por arriba y hacia atras; el contacto es la maxima rapidez de la punta, a
	# cualquier altura y en cualquier direccion.
	var any_dir: bool = bool(entry.get("contact_any", false))
	var best := {"speed": -1.0e9, "frame": 0, "foot": "R"}
	for foot in [["R", "r_toe"], ["L", "l_toe"]]:
		var j: int = names.find(foot[1])
		for k in range(1, rows.size() - 1):
			var y: float = float(rows[k][j][1])
			var a: Array = rows[k - 1][j]
			var b: Array = rows[k + 1][j]
			var v: float
			if any_dir:
				v = Vector3(float(b[0]) - float(a[0]), float(b[1]) - float(a[1]), float(b[2]) - float(a[2])).length() * FPS * 0.5
			else:
				# Adelante = -z (espacio del juego), relativo a la pelvis.
				v = -(float(b[2]) - float(a[2])) * FPS * 0.5
			if (any_dir or y <= KICK_TOE_MAX_Y) and v > float(best["speed"]):
				best = {"speed": v, "frame": k, "foot": foot[0]}
	if float(best["speed"]) < -1.0e8:
		push_warning("sin contacto detectado")
		best["speed"] = 0.0
	d["meta"]["contact"] = int(best["frame"])
	d["meta"]["kick_foot"] = String(best["foot"])
	d["meta"]["kick_speed"] = float(best["speed"])
