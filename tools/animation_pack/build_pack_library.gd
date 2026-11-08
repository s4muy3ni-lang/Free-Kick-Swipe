extends Node
## Conversor OFFLINE: pack de Mixamo (res://pack, esqueleto Y Bot de 65 huesos) -> librerias de animacion sobre el
## esqueleto de Tripo (23 huesos), con metadatos medidos del movimiento real de cada clip.
##
## Salidas (se generan en local y NO se versionan: licencia de Mixamo, ver .gitignore):
##   assets/animations/pack_clips.res   clips de campo
##   assets/animations/pack_keeper.res  clips de arquero (sin entidad todavia)
## Cada Animation lleva set_meta("pack", {...}) con: source, loop, mirrored, duration, natural_speed (m/s en juego),
## natural_dir (Vector2 adelante/derecha), root_total y root_path (desplazamiento raiz acumulado a 30 Hz, metros de
## juego: (adelante, derecha)), foot_floor_cm (altura del tobillo mas bajo frente al reposo) y, en patadas,
## contact = {time, foot (+1 derecha / -1 izquierda), pos (Vector3 adelante, arriba, derecha en metros de juego),
## speed (velocidad de avance del pie), reach (alcance maximo adelante), path (PackedVector3Array: punta del pie en la
## ventana del golpeo), path_t0 (s del primer punto), path_dt (s entre puntos)}.
## El desplazamiento raiz horizontal se QUITA de la cadera (la cadera queda centrada); el juego mueve al personaje.
##
## Uso: godot --headless --path . res://tools/animation_pack/build_pack_library.tscn
## Env opcional: OUT=<dir> escribe pack_report.json.

const SEL_PATH := "res://tools/animation_pack/selection.json"
const OUT_FIELD := "res://assets/animations/pack_clips.res"
const OUT_KEEPER := "res://assets/animations/pack_keeper.res"
const TRACK_PREFIX := "Armature/Skeleton3D:"
const GAME_SCALE := 1.75
const FPS := 30.0
const CONTACT_FPS := 120.0
## Altura maxima de la punta del pie para considerar un golpeo a pelota rasa (m de juego).
const CONTACT_MAX_HEIGHT := 0.40
## Ventana (s) de la trayectoria del pie que se guarda alrededor del contacto: antes / despues.
const PATH_BEFORE := 0.12
const PATH_AFTER := 0.05

var _vis: FootballerVisual
var _tsk: Skeleton3D
var _rt: PackRetarget
var _rest_ankle_y: float = 0.0
var _toe: Array[int] = []      # [izquierdo, derecho]
var _ankle: Array[int] = []

func _ready() -> void:
	var sel: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SEL_PATH))
	_vis = FootballerVisual.new()
	add_child(_vis)
	_vis.build(FootballerVisual.default_kit(0))
	_vis.anim_tree.active = false
	_tsk = _vis.skeleton
	var ysk: Skeleton3D = ((load("res://pack/personaje/ybot_tpose.fbx") as PackedScene).instantiate()).find_children("*", "Skeleton3D", true, false)[0]
	_toe = [_tsk.find_bone("mixamorig_LeftToeBase"), _tsk.find_bone("mixamorig_RightToeBase")]
	_ankle = [_tsk.find_bone("mixamorig_LeftFoot"), _tsk.find_bone("mixamorig_RightFoot")]
	_rest_ankle_y = minf(PoseSampler.bone_in_skeleton(_tsk, _ankle[0]).origin.y, PoseSampler.bone_in_skeleton(_tsk, _ankle[1]).origin.y)
	_rt = PackRetarget.new()
	_rt.setup(ysk, _tsk)
	var clips: Array = sel["clips"]
	_rt.hips_lift = _calibrate_lift(clips)
	print("CONVERSOR hips_lift=%.4f (unidades de Tripo; %.1f cm en juego) tobillo en reposo y=%.4f" % [_rt.hips_lift, _rt.hips_lift * GAME_SCALE * 100.0, _rest_ankle_y])
	var libs := {"field": AnimationLibrary.new(), "keeper": AnimationLibrary.new()}
	var report: Array = []
	for entry in clips:
		var variants: Array = [false]
		if entry.get("mirror", false):
			variants.append(true)
		for mirrored in variants:
			var anim: Animation = _convert(entry, mirrored)
			var id: String = String(entry["id"]) + ("_mirror" if mirrored else "")
			(libs[entry["library"]] as AnimationLibrary).add_animation(id, anim)
			var m: Dictionary = anim.get_meta("pack")
			report.append(m.merged({"id": id, "library": entry["library"]}))
			print(_line(id, m))
	var e1: int = ResourceSaver.save(libs["field"], OUT_FIELD)
	var e2: int = ResourceSaver.save(libs["keeper"], OUT_KEEPER)
	print("CONVERSOR guardado: %s (error=%d, %d clips) | %s (error=%d, %d clips)" % [OUT_FIELD, e1, (libs["field"] as AnimationLibrary).get_animation_list().size(), OUT_KEEPER, e2, (libs["keeper"] as AnimationLibrary).get_animation_list().size()])
	var out_dir: String = OS.get_environment("OUT")
	if out_dir != "":
		var f := FileAccess.open(out_dir + "/pack_report.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	get_tree().quit(0 if e1 == OK and e2 == OK else 1)

func _line(id: String, m: Dictionary) -> String:
	var s: String = "CLIP %-34s %5.2fs %s nat=%.2f m/s suelo=%+.1f cm raiz=(%.2f,%.2f)" % [id, m["duration"], "bucle" if m["loop"] else "unico", m["natural_speed"], m["foot_floor_cm"], m["root_total"].x, m["root_total"].y]
	if m.has("contact"):
		var c: Dictionary = m["contact"]
		s += " | contacto t=%.2fs pie=%s pos=(%.2f,%.2f,%.2f) v=%.1f alcance=%.2f" % [c["time"], "D" if c["foot"] > 0 else "I", c["pos"].x, c["pos"].y, c["pos"].z, c["speed"], c["reach"]]
	return s

func _load_anim(rel: String) -> Animation:
	var inst: Node = (load("res://pack/animaciones/" + rel) as PackedScene).instantiate()
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var a: Animation = null
	for n in ap.get_animation_list():
		if n != "RESET":
			a = ap.get_animation(n).duplicate()
	inst.free()
	return a

func _ankle_min_y() -> float:
	return minf(PoseSampler.bone_in_skeleton(_tsk, _ankle[0]).origin.y, PoseSampler.bone_in_skeleton(_tsk, _ankle[1]).origin.y)

## Mediana, entre los clips de calibracion, del desfase entre el tobillo en reposo y el tobillo mas bajo (percentil 10).
func _calibrate_lift(clips: Array) -> float:
	var deltas: Array[float] = []
	_rt.hips_lift = 0.0
	_rt.mirror = false
	for entry in clips:
		if not entry.get("calibrate", false):
			continue
		var a: Animation = _load_anim(entry["source"])
		var b: Dictionary = _rt.bind(a)
		var lows: Array[float] = []
		for k in int(a.length * FPS):
			_rt.pose(b, k / FPS, true)
			lows.append(_ankle_min_y())
		lows.sort()
		deltas.append(_rest_ankle_y - lows[int(lows.size() * 0.1)])
	deltas.sort()
	return deltas[deltas.size() / 2] if deltas.size() > 0 else 0.0

func _convert(entry: Dictionary, mirrored: bool) -> Animation:
	var src: Animation = _load_anim(entry["source"])
	_rt.mirror = mirrored
	var b: Dictionary = _rt.bind(src)
	var loop: bool = entry.get("loop", false)
	var n: int = int(round(src.length * FPS))
	var frames: int = n if loop else n + 1   # en bucle se descarta el ultimo fotograma (igual al primero)
	var out := Animation.new()
	out.step = 1.0 / FPS
	out.length = n / FPS
	out.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var rot_tracks: Array[int] = []
	for i in _tsk.get_bone_count():
		var tr: int = out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, NodePath(TRACK_PREFIX + _tsk.get_bone_name(i)))
		rot_tracks.append(tr)
	var hip_track: int = out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hip_track, NodePath(TRACK_PREFIX + "mixamorig_Hips"))
	var root_path := PackedVector2Array()
	var lows: Array[float] = []
	var want: Array = entry.get("paths", [])
	# paths_root = false: trayectorias sin la raiz (clip de mocap con carrera recortado alrededor del golpeo: el cuerpo
	# sigue al pie de apoyo, ver BallHandler.clip_plant_velocity).
	var with_root: bool = entry.get("paths_root", true)
	var paths := {}
	for w in want:
		paths[w] = PackedVector3Array()
	for k in frames:
		var t: float = minf(k / FPS, src.length)
		_rt.pose(b, t, true)
		for i in _tsk.get_bone_count():
			out.rotation_track_insert_key(rot_tracks[i], k / FPS, _tsk.get_bone_pose_rotation(i))
		out.position_track_insert_key(hip_track, k / FPS, _tsk.get_bone_pose_position(_rt.t_hips))
		var ro: Vector2 = _rt.root_offset(b, t)
		root_path.append(ro)
		lows.append(_ankle_min_y())
		for w in want:
			var arr: PackedVector3Array = paths[w]   # los arrays empaquetados se copian al castear: se reasigna
			arr.append(_path_point(w) + (Vector3(ro.x, 0.0, ro.y) if with_root else Vector3.ZERO))
			paths[w] = arr
	lows.sort()
	var meta := {
		"source": entry["source"], "loop": loop, "mirrored": mirrored, "duration": out.length,
		"root_total": _rt.root_offset(b, src.length), "root_path": root_path,
		"foot_floor_cm": (lows[int(lows.size() * 0.1)] - _rest_ankle_y) * GAME_SCALE * 100.0,
	}
	# Velocidad natural: de la raiz del propio clip o del gemelo con raiz indicado en speed_from.
	var total: Vector2 = meta["root_total"]
	var dur: float = src.length
	if entry.get("speed_from", "") != "":
		var tw: Animation = _load_anim(entry["speed_from"])
		var tb: Dictionary = _rt.bind(tw)
		total = _rt.root_offset(tb, tw.length)
		dur = tw.length
	meta["natural_speed"] = total.length() / maxf(dur, 0.01) if loop else 0.0
	meta["natural_dir"] = total.normalized() if total.length() > 0.01 else Vector2(1.0, 0.0)
	if entry.get("kick", false):
		meta["contact"] = _detect_contact(src, b)
	meta["role"] = String(entry.get("role", ""))
	if not with_root:
		meta["paths_root"] = false
	if not paths.is_empty():
		meta["paths"] = paths   # (adelante, arriba, derecha) en metros de juego, 30 Hz, INCLUYE el desplazamiento de la raiz
	out.set_meta("pack", meta)
	return out

## Posicion (adelante, arriba, derecha) en metros de juego de un punto de interes del esqueleto ya posado (sin raiz).
func _path_point(kind: String) -> Vector3:
	match kind:
		"toe_l":
			return PoseSampler.bone_in_skeleton(_tsk, _toe[0]).origin * GAME_SCALE
		"toe_r":
			return PoseSampler.bone_in_skeleton(_tsk, _toe[1]).origin * GAME_SCALE
		"knee_l":
			return PoseSampler.bone_in_skeleton(_tsk, _tsk.find_bone("mixamorig_LeftLeg")).origin * GAME_SCALE
		"knee_r":
			return PoseSampler.bone_in_skeleton(_tsk, _tsk.find_bone("mixamorig_RightLeg")).origin * GAME_SCALE
		"head":
			return PoseSampler.bone_in_skeleton(_tsk, _tsk.find_bone("mixamorig_Head")).origin * GAME_SCALE
		"hands":
			var l: Vector3 = PoseSampler.bone_in_skeleton(_tsk, _tsk.find_bone("mixamorig_LeftHand")).origin
			var r: Vector3 = PoseSampler.bone_in_skeleton(_tsk, _tsk.find_bone("mixamorig_RightHand")).origin
			return (l + r) * 0.5 * GAME_SCALE
	return Vector3.ZERO

## Contacto = instante de maxima velocidad de AVANCE de la punta del pie mientras esta cerca del suelo.
## Se mide sobre el esqueleto realmente retargeteado (ya reflejado si es la version izquierda).
func _detect_contact(src: Animation, b: Dictionary) -> Dictionary:
	var steps: int = int(src.length * CONTACT_FPS)
	var dt: float = 1.0 / CONTACT_FPS
	var pos: Array = [[], []]
	for i in steps + 1:
		_rt.pose(b, minf(i * dt, src.length), true)
		for f in 2:
			pos[f].append(PoseSampler.bone_in_skeleton(_tsk, _toe[f]).origin * GAME_SCALE)
	# 1) maxima velocidad de avance de cada pie con la punta cerca del suelo; 2) el contacto es la ULTIMA muestra de ese
	# pie con al menos el 90 % de ese maximo (meseta de aceleracion: justo antes de que el pie suba y frene).
	var vxs: Array = [[], []]
	var vmax := {0: 0.0, 1: 0.0}
	var reach := {0: -9.0, 1: -9.0}
	for f in 2:
		for i in range(steps + 1):
			var vx := 0.0
			if i >= 1 and i <= steps - 1:
				vx = (pos[f][i + 1].x - pos[f][i - 1].x) / (2.0 * dt)
			vxs[f].append(vx)
			reach[f] = maxf(reach[f], pos[f][i].x)
			if pos[f][i].y <= CONTACT_MAX_HEIGHT:
				vmax[f] = maxf(vmax[f], vx)
	var f_best: int = 1 if vmax[1] >= vmax[0] else 0
	var best := {"vx": vmax[f_best], "foot": f_best, "i": 0}
	for i in range(steps + 1):
		if pos[f_best][i].y <= CONTACT_MAX_HEIGHT and vxs[f_best][i] >= 0.9 * vmax[f_best]:
			best["i"] = i
	var i2: int = best["i"]
	var f2: int = best["foot"]
	var p: Vector3 = pos[f2][i2]
	# Trayectoria de la punta del pie alrededor del contacto (CONTACT_FPS): el juego elige dentro de ella el instante
	# que mejor encaja con la pelota, en vez de usar siempre el mismo.
	var path := PackedVector3Array()
	var i0: int = maxi(i2 - int(PATH_BEFORE * CONTACT_FPS), 0)
	for i in range(i0, mini(i2 + int(PATH_AFTER * CONTACT_FPS), steps) + 1):
		path.append(pos[f2][i])
	return {"time": i2 * dt, "foot": 1 if f2 == 1 else -1, "pos": Vector3(p.x, p.y, p.z), "speed": best["vx"], "reach": reach[f2],
		"path": path, "path_t0": i0 * dt, "path_dt": dt}
