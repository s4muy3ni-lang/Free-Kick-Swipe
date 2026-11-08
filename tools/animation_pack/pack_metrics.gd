extends Node
## Metricas de solo lectura de cada clip del pack (res://pack/animaciones) y de la libreria de Tripo: pistas, huesos, duracion, movimiento raiz, cierre de ciclo.
## Env: ANA_OUT=/ruta/dir (escribe metrics.json). Uso: godot --headless --path . res://tools/animation_pack/pack_metrics.tscn

const FOOT_L := "LeftFoot"
const FOOT_R := "RightFoot"

func _skel_of(root: Node) -> Skeleton3D:
	var l: Array = root.find_children("*", "Skeleton3D", true, false)
	return l[0] as Skeleton3D if l.size() > 0 else null

func _bone(sk: Skeleton3D, short: String) -> int:
	for prefix in ["mixamorig_", "mixamorig:", ""]:
		var i: int = sk.find_bone(prefix + short)
		if i >= 0:
			return i
	return -1

func _rest_global(sk: Skeleton3D, b: int) -> Transform3D:
	var chain: Array[int] = []
	var x: int = b
	while x >= 0:
		chain.append(x)
		x = sk.get_bone_parent(x)
	var t := Transform3D.IDENTITY
	for i in range(chain.size() - 1, -1, -1):
		t = t * sk.get_bone_rest(chain[i])
	return t

func _pose_global(sk: Skeleton3D, b: int) -> Transform3D:
	return PoseSampler.bone_in_skeleton(sk, b)

func _skeleton_info(sk: Skeleton3D) -> Dictionary:
	var names: Array = []
	for i in sk.get_bone_count():
		names.append(sk.get_bone_name(i))
	var hips: int = _bone(sk, "Hips")
	var toe: int = _bone(sk, "LeftToeBase")
	var foot: int = _bone(sk, FOOT_L)
	var head: int = _bone(sk, "Head")
	var info := {"bones": sk.get_bone_count(), "names": names}
	if hips >= 0:
		var g: Transform3D = _rest_global(sk, hips)
		info["hips_rest_y"] = g.origin.y
		info["hips_parent"] = sk.get_bone_name(sk.get_bone_parent(hips)) if sk.get_bone_parent(hips) >= 0 else ""
	if toe >= 0 and foot >= 0:
		var d: Vector3 = _rest_global(sk, toe).origin - _rest_global(sk, foot).origin
		info["foot_to_toe"] = [d.x, d.y, d.z]
		info["ankle_rest_y"] = _rest_global(sk, foot).origin.y
	if head >= 0:
		info["head_rest_y"] = _rest_global(sk, head).origin.y
	return info

func _clip_metrics(anim: Animation, sk: Skeleton3D) -> Dictionary:
	var pos_tracks := 0
	var rot_tracks := 0
	var other := 0
	var bones_with_tracks := {}
	var hips_track := -1
	for t in anim.get_track_count():
		var p: String = str(anim.track_get_path(t))
		var bname: String = p.substr(p.find(":") + 1) if p.contains(":") else p
		bones_with_tracks[bname] = true
		match anim.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				pos_tracks += 1
				if bname.ends_with("Hips"):
					hips_track = t
			Animation.TYPE_ROTATION_3D:
				rot_tracks += 1
			_:
				other += 1
	var m := {"length": anim.length, "tracks": anim.get_track_count(), "pos_tracks": pos_tracks, "rot_tracks": rot_tracks, "other_tracks": other,
		"bones_animated": bones_with_tracks.size(), "loop_mode": anim.loop_mode, "step": anim.step}
	if hips_track >= 0:
		var n: int = anim.track_get_key_count(hips_track)
		m["hips_keys"] = n
		var v0: Vector3 = anim.track_get_key_value(hips_track, 0)
		var v1: Vector3 = anim.track_get_key_value(hips_track, n - 1)
		var miny := 1e9
		var maxy := -1e9
		var mean := Vector3.ZERO
		for k in n:
			var v: Vector3 = anim.track_get_key_value(hips_track, k)
			mean += v
			miny = minf(miny, v.y)
			maxy = maxf(maxy, v.y)
		mean /= n
		m["hips_first"] = [v0.x, v0.y, v0.z]
		m["hips_last"] = [v1.x, v1.y, v1.z]
		m["hips_mean"] = [mean.x, mean.y, mean.z]
		m["hips_min_y"] = miny
		m["hips_max_y"] = maxy
	# Cierre de ciclo: diferencia angular total entre primer y ultimo fotograma de las rotaciones.
	var ang_sum := 0.0
	var ang_max := 0.0
	var cnt := 0
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			var n2: int = anim.track_get_key_count(t)
			if n2 >= 2:
				var q0: Quaternion = anim.track_get_key_value(t, 0)
				var q1: Quaternion = anim.track_get_key_value(t, n2 - 1)
				var a: float = q0.angle_to(q1)
				ang_sum += a
				ang_max = maxf(ang_max, a)
				cnt += 1
	m["loop_gap_mean_deg"] = rad_to_deg(ang_sum / maxf(cnt, 1))
	m["loop_gap_max_deg"] = rad_to_deg(ang_max)
	# Velocidad natural: pie de apoyo (el mas bajo) respecto a la cadera, en el eje de avance del esqueleto.
	if sk != null:
		var bm: Dictionary = PoseSampler.bind(anim, sk)
		var hips: int = _bone(sk, "Hips")
		var fl: int = _bone(sk, FOOT_L)
		var fr: int = _bone(sk, FOOT_R)
		var fwd_info: Array = []
		if hips >= 0 and fl >= 0 and fr >= 0 and anim.length > 0.05:
			var steps: int = int(clampf(anim.length * 30.0, 8.0, 240.0))
			var prev_fwd := 0.0
			var have_prev := false
			var speeds: Array[float] = []
			var min_foot := 1e9
			var series: Array = []
			for i in steps + 1:
				var t: float = anim.length * float(i) / steps
				PoseSampler.apply(anim, sk, bm, t)
				var hg: Transform3D = _pose_global(sk, hips)
				var lf: Vector3 = _pose_global(sk, fl).origin
				var rf: Vector3 = _pose_global(sk, fr).origin
				series.append([hg.origin, lf, rf])
				min_foot = minf(min_foot, minf(lf.y, rf.y))
			m["series_steps"] = steps
			m["foot_min_y"] = min_foot
			m["_series"] = series
	return m

func _ready() -> void:
	var out_dir: String = OS.get_environment("ANA_OUT")
	var result := {"pack": {}, "tripo": {}, "skeletons": {}}
	# 1) Esqueletos de referencia
	var tripo_scene: PackedScene = load("res://assets/characters/player/player_base.glb")
	var tr: Node = tripo_scene.instantiate()
	var tsk: Skeleton3D = _skel_of(tr)
	result["skeletons"]["tripo_player_base"] = _skeleton_info(tsk)
	var yb: PackedScene = load("res://pack/personaje/ybot_tpose.fbx")
	var yr: Node = yb.instantiate()
	var ysk: Skeleton3D = _skel_of(yr)
	result["skeletons"]["ybot_tpose"] = _skeleton_info(ysk) if ysk != null else {"error": "sin Skeleton3D"}
	# 2) Clips de Tripo (libreria compartida) sobre el esqueleto de Tripo
	var lib: AnimationLibrary = load("res://assets/animations/footballer_clips.res")
	for nm in lib.get_animation_list():
		var m: Dictionary = _clip_metrics(lib.get_animation(nm), tsk)
		result["tripo"][String(nm)] = m
	# 3) Clips del pack
	var files: Array[String] = []
	_collect("res://pack/animaciones", files)
	files.sort()
	for f in files:
		var ps: PackedScene = load(f)
		if ps == null:
			result["pack"][f] = {"error": "no se pudo cargar"}
			continue
		var inst: Node = ps.instantiate()
		var sk: Skeleton3D = _skel_of(inst)
		var ap: Array = inst.find_children("*", "AnimationPlayer", true, false)
		var entry := {"skeleton_bones": sk.get_bone_count() if sk else -1, "players": ap.size()}
		if ap.size() > 0:
			var player: AnimationPlayer = ap[0]
			var names: PackedStringArray = player.get_animation_list()
			entry["animation_names"] = Array(names)
			var anim_name: String = names[0] if names.size() > 0 else ""
			for cand in names:
				if cand != "RESET":
					anim_name = cand
					break
			if anim_name != "":
				entry["metrics"] = _clip_metrics(player.get_animation(anim_name), sk)
		result["pack"][f.replace("res://pack/animaciones/", "")] = entry
		inst.free()
	var fa := FileAccess.open(out_dir + "/metrics.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(result))
	fa.close()
	print("ANALISIS OK: pack=%d clips, tripo=%d clips" % [result["pack"].size(), result["tripo"].size()])
	get_tree().quit()

func _collect(dir: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + d, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".fbx"):
			out.append(dir + "/" + f)
