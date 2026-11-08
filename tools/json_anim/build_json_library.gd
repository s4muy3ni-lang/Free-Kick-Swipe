extends Node
## Conversor OFFLINE de las animaciones JSON (animaciones_futbol5_JSON_limpios: posiciones de 19 articulaciones) a las
## librerias de clips del modo Json sobre el esqueleto canonico JsonRig:
##   assets/animations/json_clips.res   clips de campo
##   assets/animations/json_keeper.res  clips de arquero
##   assets/animations/json_scenes.res  escenas: festejos, lamentos, gestos, esperas, barrera (se suman a los de campo)
## La seleccion (que clips, con que rol, espejo, bucle) esta en tools/json_anim/selection.json (la genera make_selection.py).
## Cada Animation lleva set_meta("pack", {...}) con los mismos campos que el pack de Mixamo (duration, loop, natural_speed,
## root_total, root_path, contact, paths...) mas los propios del JSON (role, touches, strides, kick...), medidos sobre las
## articulaciones del propio clip.
##
## Heading: las articulaciones de los datos giran con el cuerpo (el clip puede terminar a 40 grados). El juego mueve y gira
## al jugador, asi que se quita el rumbo: en bucles el medio; en el resto una media movil de 0.5 s (queda la torsion rapida
## de caderas y pecho). La trayectoria de la pelvis (raiz) y el giro quitado se guardan aparte (root_path, heading_path).
##
## Uso: JSON_SRC=<carpeta de los JSON> godot --headless --path . res://tools/json_anim/build_json_library.tscn

const SEL_PATH := "res://tools/json_anim/selection.json"
const OUT_FIELD := "res://assets/animations/json_clips.res"
const OUT_KEEPER := "res://assets/animations/json_keeper.res"
const OUT_SCENES := "res://assets/animations/json_scenes.res"
const DATA_FPS := 60.0
const REST_ANKLE_Y := 0.095
const CONTACT_FPS := 120.0
const PATH_BEFORE := 0.12
const PATH_AFTER := 0.05
const HEADING_SIGMA := 0.25
## Clips con rumbo «turn» (giros, giros con pelota, golpeos girando): el juego gira al jugador con este rumbo, asi que se
## suaviza poco (queda en las articulaciones solo la torsion rapida de caderas y hombros).
const HEADING_SIGMA_TURN := 0.1
const STEP_KEY := 30.0
const STEP_KEY_HI := 60.0

var _src_dir: String = ""
var _files: PackedStringArray = PackedStringArray()
var _rt: JsonRetarget

func _ready() -> void:
	_src_dir = OS.get_environment("JSON_SRC")
	_files = DirAccess.get_files_at(_src_dir)
	_rt = JsonRetarget.new(JsonRig.Pose.A)
	var sel_path: String = OS.get_environment("SELECTION") if OS.get_environment("SELECTION") != "" else SEL_PATH
	var sel: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sel_path))
	var libs := {"field": AnimationLibrary.new(), "keeper": AnimationLibrary.new(), "scenes": AnimationLibrary.new()}
	var report: Array = []
	var only: String = OS.get_environment("ONLY")
	var bytes := 0
	for entry in sel["clips"]:
		if only != "" and not (String(entry["file"]) in only.split(",")):
			continue
		var path: String = _find(String(entry["file"]))
		if path == "":
			push_warning("no existe el clip " + String(entry["file"]))
			continue
		var variants: Array = [true] if entry.get("only_mirror", false) else [false]
		if entry.get("mirror", false):
			variants.append(true)
		for mirrored in variants:
			var c: JsonClipData = JsonClipData.load_file(path, mirrored)
			if c == null:
				push_warning("no se pudo leer " + path)
				continue
			var id: String = String(entry["id"]) + ("_mirror" if mirrored and not entry.get("only_mirror", false) else "")
			var anim: Animation = _convert(c, entry, mirrored)
			(libs[entry.get("library", "field")] as AnimationLibrary).add_animation(id, anim)
			var m: Dictionary = anim.get_meta("pack")
			print(_line(id, m))
			report.append({"id": id, "role": m["role"], "duration": m["duration"], "loop": m["loop"], "natural_speed": m["natural_speed"]})
	var out_field: String = OS.get_environment("OUT_FIELD") if OS.get_environment("OUT_FIELD") != "" else OUT_FIELD
	var out_keeper: String = OS.get_environment("OUT_KEEPER") if OS.get_environment("OUT_KEEPER") != "" else OUT_KEEPER
	var e1: int = ResourceSaver.save(libs["field"], out_field)
	var e2: int = ResourceSaver.save(libs["keeper"], out_keeper)
	var out_scenes: String = OS.get_environment("OUT_SCENES") if OS.get_environment("OUT_SCENES") != "" else OUT_SCENES
	var e3: int = ResourceSaver.save(libs["scenes"], out_scenes)
	print("CONVERSOR guardado: %s (error=%d, %d clips) | %s (error=%d, %d clips) | %s (error=%d, %d clips)" % [out_field, e1, (libs["field"] as AnimationLibrary).get_animation_list().size(), out_keeper, e2, (libs["keeper"] as AnimationLibrary).get_animation_list().size(), out_scenes, e3, (libs["scenes"] as AnimationLibrary).get_animation_list().size()])
	var out_dir: String = OS.get_environment("OUT")
	if out_dir != "":
		var f := FileAccess.open(out_dir + "/json_report.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	get_tree().quit(0 if e1 == OK and e2 == OK and e3 == OK else 1)

func _find(prefix: String) -> String:
	for f in _files:
		if f.begins_with(prefix + "_"):
			return _src_dir.path_join(f)
	return ""

func _line(id: String, m: Dictionary) -> String:
	var s: String = "CLIP %-44s %5.2fs %s %-14s nat=%.2f suelo=%+.1f cm raiz=(%.2f,%.2f)" % [id, m["duration"], "bucle" if m["loop"] else "unico", m["role"], m["natural_speed"], m["foot_floor_cm"], m["root_total"].x, m["root_total"].y]
	if m.has("contact"):
		var c: Dictionary = m["contact"]
		s += " | contacto t=%.2fs pie=%s pos=(%.2f,%.2f,%.2f) v=%.1f alcance=%.2f" % [c["time"], "D" if c["foot"] > 0 else "I", c["pos"].x, c["pos"].y, c["pos"].z, c["speed"], c["reach"]]
	return s

# --- Conversion de un clip --------------------------------------------------------------------------------------------------

func _convert(c: JsonClipData, entry: Dictionary, mirrored: bool) -> Animation:
	var loop: bool = bool(entry.get("loop", c.meta.get("loop", false)))
	var cycle: Array = entry.get("cycle", [])
	var src_loop: bool = bool(c.meta.get("loop", false))
	var f0 := 0.0
	var n60: int = c.frames    # en bucle el ultimo fotograma (n60) es igual al primero y no se guarda
	if cycle.size() == 2:
		# Ciclo recortado entre dos apoyos del mismo pie (fotogramas a 60 Hz): el clip pasa a ser un bucle.
		f0 = float(cycle[0])
		n60 = int(cycle[1]) - int(cycle[0])
		loop = true
	elif entry.has("phase"):
		# Bucle girado para que empiece en un apoyo (fase 0 = apoyo del pie izquierdo).
		f0 = float(entry.get("phase_mirror", entry["phase"])) if mirrored else float(entry["phase"])
	var samples: int = n60 + 1
	# 1) Articulaciones a 60 Hz y rumbo del cuerpo.
	var raw: Array = []
	var yaw := PackedFloat32Array()
	for k in samples:
		var fk: float = f0 + float(k)
		if cycle.size() != 2 and entry.has("phase") and src_loop:
			fk = fposmod(fk, float(c.frames))
		var j: Dictionary = c.sample(fk)
		raw.append(j)
		var lat: Vector3 = (j["r_hip"] as Vector3) - (j["l_hip"] as Vector3)
		var fwd: Vector3 = Vector3.UP.cross(lat)
		yaw.append(atan2(-fwd.z, fwd.x))
	# Desenvolver el angulo.
	for k in range(1, samples):
		while yaw[k] - yaw[k - 1] > PI:
			yaw[k] -= TAU
		while yaw[k] - yaw[k - 1] < -PI:
			yaw[k] += TAU
	var root_driven: bool = bool(entry.get("root_driven", false))
	var mode: String = String(entry.get("heading", "initial" if root_driven else ("mean" if loop else "smooth")))
	var heading := PackedFloat32Array()
	heading.resize(samples)
	match mode:
		"none":
			for k in samples:
				heading[k] = 0.0
		"initial":
			# Clips que mueven al cuerpo con su raiz: se conserva el giro propio del clip y solo se quita el rumbo inicial.
			var h0 := 0.0
			var n0: int = mini(6, samples)
			for k in n0:
				h0 += yaw[k]
			h0 /= float(n0)
			for k in samples:
				heading[k] = h0
		"mean":
			var mean := 0.0
			for k in samples:
				mean += yaw[k]
			mean /= float(samples)
			for k in samples:
				heading[k] = mean
		_:
			var sigma: float = (HEADING_SIGMA_TURN if mode == "turn" else HEADING_SIGMA) * DATA_FPS
			var rad: int = int(sigma * 3.0)
			for k in samples:
				var acc := 0.0
				var wsum := 0.0
				for d in range(-rad, rad + 1):
					var kk: int = clampi(k + d, 0, samples - 1)
					var w: float = exp(-0.5 * pow(float(d) / sigma, 2.0))
					acc += yaw[kk] * w
					wsum += w
				heading[k] = acc / wsum
	var joints_s: Array = []   # articulaciones sin rumbo, 60 Hz
	for k in samples:
		var rot := Basis(Vector3.UP, -heading[k])
		var j2 := {}
		for jn in raw[k]:
			j2[jn] = rot * (raw[k][jn] as Vector3)
		joints_s.append(j2)
	if cycle.size() == 2:
		# Costura del bucle: los ultimos fotogramas se funden hacia la primera pose.
		var kseam: int = mini(int(entry.get("seam", 8)), n60 / 2)
		for k in range(n60 - kseam, n60 + 1):
			var wgt: float = smoothstep(0.0, 1.0, float(k - (n60 - kseam)) / float(maxi(kseam, 1)))
			var jj: Dictionary = joints_s[k]
			for jn in jj:
				jj[jn] = (jj[jn] as Vector3).lerp(joints_s[0][jn], wgt)
	# 2) Animacion: rotaciones y cadera.
	var hi: bool = bool(entry.get("hi", entry.get("kick", false) or entry.get("dribble", false)))
	var fps_key: float = STEP_KEY_HI if hi else STEP_KEY
	var key_count: int = int(round(float(n60) / DATA_FPS * fps_key))
	var out := Animation.new()
	out.step = 1.0 / fps_key
	out.length = float(n60) / DATA_FPS
	out.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	for b in JsonRig.BONES:
		# Root, manos y puntas de los pies siguen a su padre (rotacion local de reposo = identidad): sin pista.
		if b == "Root" or b.ends_with("Hand") or b.ends_with("ToeBase"):
			continue
		var tr: int = out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, NodePath(JsonRig.SKELETON_PATH + ":" + b))
		tracks[b] = tr
	var hip_tr: int = out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hip_tr, NodePath(JsonRig.SKELETON_PATH + ":mixamorig_Hips"))
	var prev := {}
	var reach_err := 0.0
	var frames_total: int = key_count + (0 if loop else 1)
	for ki in frames_total:
		var t: float = float(ki) / fps_key
		var f: float = minf(t * DATA_FPS, float(samples - 1))
		var j: Dictionary = _sample_sm(joints_s, f)
		var res: Dictionary = _rt.solve(j)
		reach_err = maxf(reach_err, float(res["reach_err"]))
		var loc: Dictionary = JsonRetarget.local_rotations(res["frames"])
		for b in tracks:
			var q: Quaternion = loc[b]
			if prev.has(b) and (prev[b] as Quaternion).dot(q) < 0.0:
				q = -q
			prev[b] = q
			out.rotation_track_insert_key(tracks[b], t, q)
		out.position_track_insert_key(hip_tr, t, (res["hips"] as Vector3) * JsonRig.UNIT)
	# 3) Metadatos.
	var meta := _meta(c, entry, mirrored, joints_s, heading, loop, n60, f0, cycle.size() == 2, src_loop, mode == "initial" or mode == "turn")
	meta["heading_mode"] = mode
	meta["reach_err_cm"] = reach_err * 100.0
	out.set_meta("pack", meta)
	if bool(entry.get("compress", true)):
		out.compress(8192, int(fps_key), 4.0)
	return out

func _sample_sm(joints_s: Array, f: float) -> Dictionary:
	var i: int = clampi(int(floor(f)), 0, joints_s.size() - 1)
	var i2: int = mini(i + 1, joints_s.size() - 1)
	var u: float = f - float(i)
	if u < 1e-4 or i2 == i:
		return joints_s[i]
	var out := {}
	for jn in joints_s[i]:
		out[jn] = (joints_s[i][jn] as Vector3).lerp(joints_s[i2][jn], u)
	return out

# --- Metadatos medidos ---------------------------------------------------------------------------------------------------

func _meta(c: JsonClipData, entry: Dictionary, mirrored: bool, js: Array, heading: PackedFloat32Array, loop: bool, n60: int, f0: float, cropped: bool, src_loop: bool, rotate_root: bool) -> Dictionary:
	var m := {}
	m["source"] = c.source
	m["json"] = true
	m["loop"] = loop
	m["mirrored"] = mirrored
	m["duration"] = float(n60) / DATA_FPS
	m["role"] = String(entry.get("role", ""))
	var with_root: bool = bool(entry.get("root_driven", false))
	m["paths_root"] = with_root
	m["alias"] = entry.get("alias", [])
	m["library"] = String(entry.get("library", "field"))
	var root := PackedVector2Array()
	var heading_path := PackedFloat32Array()
	var k := 0
	var r0: Vector2 = c.sample_root(f0)
	var hroot := Basis(Vector3.UP, -heading[0]) if rotate_root else Basis.IDENTITY
	while k <= n60:
		var rp: Vector2 = c.sample_root(minf(f0 + float(k), float(c.frames))) - r0
		var rr: Vector3 = hroot * Vector3(rp.x, 0.0, rp.y)
		root.append(Vector2(rr.x, rr.z))
		heading_path.append(rad_to_deg(heading[mini(k, heading.size() - 1)]))
		k += 2
	var rt0: Vector2 = c.sample_root(minf(f0 + float(n60), float(c.frames))) - r0
	var rt3: Vector3 = hroot * Vector3(rt0.x, 0.0, rt0.y)
	m["root_total"] = Vector2(rt3.x, rt3.z)
	m["root_path"] = root
	m["heading_path"] = heading_path
	# Alturas del tobillo y apoyos (por pie).
	var lows: Array[float] = []
	for jj in js:
		lows.append(minf((jj["l_ankle"] as Vector3).y, (jj["r_ankle"] as Vector3).y))
	lows.sort()
	m["foot_floor_cm"] = (lows[int(lows.size() * 0.1)] - REST_ANKLE_Y) * 100.0
	# Velocidad natural: la del pie apoyado (tobillo bajo) que retrocede respecto a la pelvis.
	var st: Dictionary = _stance(js)
	var ns: float = st["speed"]
	var nat_json: float = float(c.meta.get("ground_speed", 0.0))
	m["natural_speed_stance"] = ns
	m["natural_speed_json"] = nat_json
	m["natural_speed"] = (float(entry["speed"]) if entry.has("speed") else (ns if loop else 0.0))
	m["natural_dir"] = st["dir"]
	if cropped:
		# Ciclo recortado con raiz: la velocidad sin patinar es la de la pelvis en el propio ciclo.
		var rt_tot: Vector2 = m["root_total"]
		m["natural_speed"] = rt_tot.length() / maxf(m["duration"], 0.05)
		m["natural_dir"] = rt_tot.normalized() if rt_tot.length() > 0.05 else Vector2(1.0, 0.0)
	m["state"] = String(c.meta.get("state", ""))
	m["kind"] = String(c.meta.get("kind", ""))
	m["power"] = String(c.meta.get("power", ""))
	m["v_in"] = float(c.meta.get("v_in", 0.0))
	m["v_out"] = float(c.meta.get("v_out", 0.0))
	m["dir_in"] = float(c.meta.get("dir_in", 0.0)) * (-1.0 if mirrored else 1.0)
	m["dir_out"] = float(c.meta.get("dir_out", 0.0)) * (-1.0 if mirrored else 1.0)
	m["pelvis_h"] = float(c.meta.get("pelvis_h", 0.85))
	m["tags"] = c.meta.get("tags", [])
	# Toques y apoyos del JSON: [tiempo s, pie (+1 derecho, -1 izquierdo), angulo, velocidad].
	var touches: Array = []
	for t in c.meta.get("touches", []):
		var tf: float = _rel_frame(float(t[0]), f0, n60, cropped, src_loop, c.frames)
		if tf >= 0.0:
			touches.append([tf / DATA_FPS, _foot_sign(String(t[1]), mirrored), float(t[2]) * (-1.0 if mirrored else 1.0), float(t[3])])
	touches.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	m["touches"] = touches
	var strides: Array = []
	for s2 in c.meta.get("strides", []):
		var sf: float = _rel_frame(float(s2[0]), f0, n60, cropped, src_loop, c.frames)
		if sf >= 0.0:
			strides.append([sf / DATA_FPS, _foot_sign(String(s2[1]), mirrored)])
	strides.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	m["strides"] = strides
	# Trayectorias (adelante, arriba, derecha) a 30 Hz, SIN la raiz (el cuerpo sigue al pie de apoyo).
	# Los arrays empaquetados se copian al sacarlos de un Dictionary: se llenan como variables locales y se asignan al final.
	var p_toe_l := PackedVector3Array()
	var p_toe_r := PackedVector3Array()
	var p_knee_l := PackedVector3Array()
	var p_knee_r := PackedVector3Array()
	var p_head := PackedVector3Array()
	var p_hands := PackedVector3Array()
	k = 0
	var rp_all: PackedVector2Array = m["root_path"]
	while k <= n60:
		var jj: Dictionary = js[mini(k, js.size() - 1)]
		var off := Vector3.ZERO
		if with_root:
			var rq: Vector2 = rp_all[mini(k / 2, rp_all.size() - 1)]
			off = Vector3(rq.x, 0.0, rq.y)
		p_toe_l.append((jj["l_toe"] as Vector3) + off)
		p_toe_r.append((jj["r_toe"] as Vector3) + off)
		p_knee_l.append((jj["l_knee"] as Vector3) + off)
		p_knee_r.append((jj["r_knee"] as Vector3) + off)
		p_head.append((jj["head"] as Vector3) + off)
		p_hands.append(((jj["l_wrist"] as Vector3) + (jj["r_wrist"] as Vector3)) * 0.5 + off)
		k += 2
	if bool(entry.get("paths", true)):
		var paths := {"toe_l": p_toe_l, "toe_r": p_toe_r, "knee_l": p_knee_l, "knee_r": p_knee_r, "head": p_head, "hands": p_hands}
		m["paths"] = paths
	# Accion con raiz y rumbo: el juego mueve al cuerpo con root_path y lo gira con heading_path (ActionMotion).
	m["move"] = bool(entry.get("move", false))
	if entry.has("lie"):
		m["lie"] = String(entry["lie"])
	if entry.get("ball", false):
		m["ball_touches"] = _ball_touches(c, js, heading, f0, n60, cropped, src_loop, mirrored, rotate_root)
	if entry.get("kick", false):
		var ct: Dictionary = _contact(c, js, mirrored, n60)
		if not ct.is_empty():
			# Hacia donde sale la pelota respecto al frente del INICIO del clip (grados, + izquierda) y cuanto giro el cuerpo
			# hasta el contacto: con eso el juego elige el golpeo girando cuando el destino no esta delante.
			var kturn: float = -float(c.meta.get("kick_dir", 0.0))
			ct["kick_turn"] = -kturn if mirrored else kturn
			var kc: int = clampi(int(round(float(ct["time"]) * DATA_FPS)), 0, heading.size() - 1)
			ct["body_turn"] = rad_to_deg(heading[kc] - heading[0])
			var rp_c: PackedVector2Array = m["root_path"]
			ct["root"] = rp_c[clampi(int(round(float(ct["time"]) * 30.0)), 0, rp_c.size() - 1)] if rp_c.size() > 0 else Vector2.ZERO
			# Golpeo «limpio» para el planificador de pases y tiros a ras: punta baja, por delante del cuerpo, a un costado
			# razonable, rapida, con el pie de apoyo en el suelo y la pelota saliendo hacia delante.
			var cp: Vector3 = ct["pos"]
			var plant_key: String = "l_toe" if int(ct["foot"]) > 0 else "r_toe"
			var plant_y: float = (_sample_sm(js, float(kc))[plant_key] as Vector3).y
			ct["plant_y"] = plant_y
			# Pie de apoyo quieto sobre el suelo (raiz + punta, en el mundo del clip) en los 0.1 s previos al contacto: si aun
			# esta aterrizando, el pie patina al jugarlo con el cuerpo plantado.
			# Maximo por fotograma (60 Hz) en los 5 fotogramas previos: un pie que aterriza justo antes del contacto patina en
			# ese fotograma aunque la media salga baja.
			var r0c: Vector2 = c.sample_root(f0)
			var plant_slide: float = 0.0
			var prev_w := Vector3.INF
			# Y apoyado (punta baja) desde KICK_PLANT_TIME antes del contacto: el juego planta el cuerpo en ese tramo.
			var planted: bool = true
			for kk2 in range(maxi(kc - 6, 0), kc + 1):
				if (js[kk2][plant_key] as Vector3).y > 0.06:
					planted = false
			ct["planted"] = planted
			for kk in range(maxi(kc - 5, 0), kc + 1):
				var pk: Vector2 = c.sample_root(f0 + float(kk)) - r0c
				var wk: Vector3 = Vector3(pk.x, 0.0, pk.y) + Basis(Vector3.UP, heading[kk]) * (js[kk][plant_key] as Vector3)
				if prev_w != Vector3.INF:
					plant_slide = maxf(plant_slide, Vector2(wk.x - prev_w.x, wk.z - prev_w.z).length() * DATA_FPS)
				prev_w = wk
			ct["plant_slide"] = plant_slide
			ct["clean"] = cp.y <= 0.3 and cp.x >= 0.0 and cp.x <= 0.95 and absf(cp.z) <= 0.5 and float(ct["speed"]) >= 4.0 and plant_y <= 0.06 and absf(kturn) < 45.0 and plant_slide <= 1.2 and planted
			m["contact"] = ct
	if entry.get("throw", false):
		m["release"] = _release(js, m["root_path"] as PackedVector2Array)
	m["kick_kind"] = String(entry.get("kick_kind", ""))
	return m

## Toques de pelota del clip (los del JSON): para cada uno, el instante, el pie y DONDE esta la punta de ese pie respecto al
## cuerpo al INICIO del clip (adelante, arriba, derecha; con la raiz y el giro del cuerpo hasta ese instante), y hacia donde
## va la punta (adelante, derecha). Con eso el juego manda la pelota de un toque al siguiente: llega al pie justo cuando el
## pie la toca.
func _ball_touches(c: JsonClipData, js: Array, heading: PackedFloat32Array, f0: float, n60: int, cropped: bool, src_loop: bool, mirrored: bool, rotate_root: bool) -> Array:
	var out: Array = []
	var r0: Vector2 = c.sample_root(f0)
	var h0: float = heading[0]
	var hroot := Basis(Vector3.UP, -h0) if rotate_root else Basis.IDENTITY
	for t in c.meta.get("touches", []):
		var tf: float = _rel_frame(float(t[0]), f0, n60, cropped, src_loop, c.frames)
		if tf < 0.0:
			continue
		var foot: int = _foot_sign(String(t[1]), mirrored)
		var key: String = "r_toe" if foot > 0 else "l_toe"
		var pts: Array[Vector3] = []
		for d in [-2.0, 0.0, 2.0]:
			var ff: float = clampf(tf + d, 0.0, float(js.size() - 1))
			var k: int = clampi(int(round(ff)), 0, js.size() - 1)
			var rp: Vector2 = c.sample_root(minf(f0 + ff, float(c.frames))) - r0
			var rr: Vector3 = hroot * Vector3(rp.x, 0.0, rp.y)
			var toe: Vector3 = Basis(Vector3.UP, heading[k] - h0) * (_sample_sm(js, ff)[key] as Vector3)
			pts.append(rr + toe)
		var vel: Vector3 = (pts[2] - pts[0]) * (DATA_FPS / 4.0)
		out.append([tf / DATA_FPS, foot, pts[1], Vector2(vel.x, vel.z)])
	return out

## Suelta de un lanzamiento con las manos: el primer instante en que las dos manos se separan (> 12 cm) tras haber ido juntas.
## hands = (adelante, arriba, derecha) respecto a la pelvis en ese instante (medio de las dos muñecas, un fotograma antes).
func _release(js: Array, _root: PackedVector2Array) -> Dictionary:
	var rel_i: int = js.size() - 2
	for i in range(1, js.size() - 1):
		var sep: float = ((js[i]["l_wrist"] as Vector3) - (js[i]["r_wrist"] as Vector3)).length()
		if sep > 0.12:
			rel_i = maxi(i - 1, 0)
			break
	var h: Vector3 = ((js[rel_i]["l_wrist"] as Vector3) + (js[rel_i]["r_wrist"] as Vector3)) * 0.5
	var a: Vector3 = ((js[maxi(rel_i - 2, 0)]["l_wrist"] as Vector3) + (js[maxi(rel_i - 2, 0)]["r_wrist"] as Vector3)) * 0.5
	var b: Vector3 = ((js[mini(rel_i + 2, js.size() - 1)]["l_wrist"] as Vector3) + (js[mini(rel_i + 2, js.size() - 1)]["r_wrist"] as Vector3)) * 0.5
	return {"time": float(rel_i) / DATA_FPS, "hands": h, "speed": (b.x - a.x) * DATA_FPS / 4.0}

static func _foot_sign(s: String, mirrored: bool) -> int:
	var right: bool = (s == "R")
	if mirrored:
		right = not right
	return 1 if right else -1

## Fotograma del evento relativo al inicio del clip (f0), o -1 si cae fuera del recorte. En bucles girados se envuelve.
static func _rel_frame(ev: float, f0: float, n60: int, cropped: bool, src_loop: bool, total: int) -> float:
	var r: float = ev - f0
	if cropped:
		return r if r >= 0.0 and r < float(n60) else -1.0
	if src_loop and f0 > 0.0:
		r = fposmod(r, float(total))
	return r if r >= 0.0 and r <= float(n60) else -1.0

## Pie apoyado (tobillo bajo y punta en el suelo): velocidad a la que retrocede respecto a la pelvis (la velocidad a la que
## el clip no patina) y direccion (adelante, derecha) en la que avanza el cuerpo.
func _stance(js: Array) -> Dictionary:
	var vf: Array[float] = []
	var vr: Array[float] = []
	for k in range(1, js.size() - 1):
		for s in ["l_", "r_"]:
			var a0: Vector3 = js[k - 1][s + "ankle"]
			var a1: Vector3 = js[k + 1][s + "ankle"]
			var a: Vector3 = js[k][s + "ankle"]
			if a.y < REST_ANKLE_Y + 0.045 and (js[k][s + "toe"] as Vector3).y < 0.05:
				vf.append(-(a1.x - a0.x) * DATA_FPS * 0.5)
				vr.append(-(a1.z - a0.z) * DATA_FPS * 0.5)
	if vf.size() < 3:
		return {"speed": 0.0, "dir": Vector2(1.0, 0.0)}
	vf.sort()
	vr.sort()
	var v := Vector2(vf[vf.size() / 2], vr[vr.size() / 2])
	return {"speed": v.length(), "dir": v.normalized() if v.length() > 0.2 else Vector2(1.0, 0.0)}

## Contacto del golpeo: el del JSON (fotograma `contact`, pie kick_foot) comprobado sobre la punta de las articulaciones.
## Trayectoria de la punta del pie a 120 Hz alrededor del contacto. pos = (adelante, arriba, derecha) respecto a la pelvis.
func _contact(c: JsonClipData, js: Array, mirrored: bool, n60: int) -> Dictionary:
	var foot: int = _foot_sign(String(c.meta.get("kick_foot", "R")), mirrored)
	var key: String = "r_toe" if foot > 0 else "l_toe"
	var steps: int = int(float(n60) / DATA_FPS * CONTACT_FPS)
	var dt: float = 1.0 / CONTACT_FPS
	var pos := PackedVector3Array()
	for i in steps + 1:
		var f: float = minf(float(i) * dt * DATA_FPS, float(js.size() - 1))
		pos.append(_sample_sm(js, f)[key])
	var jc: float = float(c.meta.get("contact", 0)) / DATA_FPS
	var i_json: int = clampi(int(round(jc * CONTACT_FPS)), 0, steps)
	# Contacto = muestra de maxima velocidad de avance cerca del fotograma del JSON (+-0.12 s) con la punta baja.
	var best_i: int = i_json
	var best_v: float = -INF
	var lo: int = maxi(i_json - int(0.12 * CONTACT_FPS), 1)
	var hi: int = mini(i_json + int(0.12 * CONTACT_FPS), steps - 1)
	for i in range(lo, hi + 1):
		var vx: float = (pos[i + 1].x - pos[i - 1].x) / (2.0 * dt)
		if pos[i].y <= 0.45 and vx > best_v:
			best_v = vx
			best_i = i
	# Ultima muestra de esa meseta (>= 90 % del maximo): justo antes de que el pie suba y frene.
	if best_v > 0.0:
		for i in range(best_i, hi + 1):
			var vx2: float = (pos[i + 1].x - pos[i - 1].x) / (2.0 * dt)
			if pos[i].y <= 0.45 and vx2 >= 0.9 * best_v:
				best_i = i
	var reach: float = -9.0
	for p in pos:
		reach = maxf(reach, p.x)
	var path := PackedVector3Array()
	var i0: int = maxi(best_i - int(PATH_BEFORE * CONTACT_FPS), 0)
	for i in range(i0, mini(best_i + int(PATH_AFTER * CONTACT_FPS), steps) + 1):
		path.append(pos[i])
	return {"time": float(best_i) * dt, "foot": foot, "pos": pos[best_i], "speed": maxf(best_v, 0.0), "reach": reach,
		"path": path, "path_t0": float(i0) * dt, "path_dt": dt, "json_time": jc, "json_speed": float(c.meta.get("kick_speed", 0.0))}
