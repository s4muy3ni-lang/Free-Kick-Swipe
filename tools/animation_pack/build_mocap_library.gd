extends "res://tools/animation_pack/build_pack_library.gd"
## Conversor OFFLINE del «Mocap Pack 05 Soccer» (21 tomas de captura de movimiento de futbol, version Rokoko_Default:
## esqueleto de 76 huesos Hips/Spine1-4/Thigh/Shin/Foot/Toe, +Z adelante, pose T) al esqueleto del futbolista, con los
## mismos metadatos medidos que el pack de Mixamo (ver build_pack_library.gd). Es el MODO 2 de jugabilidad
## (Tuning.gameplay_mode = 2, AnimationCatalog): la persona tiene autorizacion para usar estas animaciones.
##
## Las tomas de golpeo traen la carrera previa y la vuelta: se busca el contacto del pie, se gira la toma para que el pie
## salga hacia +X (adelante del jugador) y se recorta una ventana alrededor del golpeo; las trayectorias de los pies se
## guardan SIN la raiz (paths_root = false): durante el apoyo el cuerpo sigue al pie plantado y el pie no patina.
## El penal conserva la carrera con su raiz (lo reproduce SetPiece moviendo al ejecutor con la raiz del clip).
## Todos llevan role = "mocap": la sala de practica los agrupa en «Mocap fútbol (modo 2)».
##
## Entrada: res://pack/mocap05/rokoko/*.fbx (fuera del repositorio, /pack/ esta en .gitignore).
## Salida: assets/animations/mocap_clips.res (versionada: se suma a la libreria de campo en PackLibrary).
## Uso: godot --headless --path . res://tools/animation_pack/build_mocap_library.tscn

const SRC_DIR := "res://pack/mocap05/rokoko/"
const OUT_MOCAP := "res://assets/animations/mocap_clips.res"

## Hueso del esqueleto Rokoko para cada hueso del futbolista (la columna de 4 vertebras se reparte en 3).
const ROKOKO_MAP := {
	"mixamorig_Hips": "Hips", "mixamorig_Spine": "Spine1", "mixamorig_Spine1": "Spine3", "mixamorig_Spine2": "Spine4",
	"mixamorig_Neck": "Neck", "mixamorig_Head": "Head",
	"mixamorig_LeftShoulder": "LeftShoulder", "mixamorig_LeftArm": "LeftArm", "mixamorig_LeftForeArm": "LeftForeArm", "mixamorig_LeftHand": "LeftHand",
	"mixamorig_RightShoulder": "RightShoulder", "mixamorig_RightArm": "RightArm", "mixamorig_RightForeArm": "RightForeArm", "mixamorig_RightHand": "RightHand",
	"mixamorig_LeftUpLeg": "LeftThigh", "mixamorig_LeftLeg": "LeftShin", "mixamorig_LeftFoot": "LeftFoot", "mixamorig_LeftToeBase": "LeftToe",
	"mixamorig_RightUpLeg": "RightThigh", "mixamorig_RightLeg": "RightShin", "mixamorig_RightFoot": "RightFoot", "mixamorig_RightToeBase": "RightToe",
}

## Seleccion. window = [segundos antes, despues] del contacto (golpeos); face = girar la toma para que el golpeo vaya
## hacia adelante; paths_root = false en los golpeos que el juego hace en el sitio.
const CLIPS := [
	{"id": "mc_side_foot_pass", "source": "08_Side_Foot_Kick.fbx", "kick": true, "mirror": true, "window": [0.75, 0.6], "face": true, "paths_root": false, "paths": ["toe_l", "toe_r"], "calibrate": true, "role": "mocap"},
	{"id": "mc_power_kick", "source": "09_Power_Kick.fbx", "kick": true, "mirror": true, "window": [0.75, 0.7], "face": true, "paths_root": false, "paths": ["toe_l", "toe_r"], "role": "mocap"},
	{"id": "mc_penalty_kick", "source": "10_Penalty_Kick_01.fbx", "kick": true, "mirror": true, "window": [1.6, 0.8], "face": true, "paths": ["toe_l", "toe_r"], "role": "mocap"},
	{"id": "mc_penalty_kick_2", "source": "11_Penalty_Kick_02.fbx", "kick": true, "mirror": true, "window": [1.6, 0.8], "face": true, "paths": ["toe_l", "toe_r"], "role": "mocap"},
	{"id": "mc_dribble_1", "source": "01_Dribble_01.fbx", "paths": ["toe_l", "toe_r"], "calibrate": true, "role": "mocap"},
	{"id": "mc_dribble_2", "source": "02_Dribble_02.fbx", "paths": ["toe_l", "toe_r"], "role": "mocap"},
	{"id": "mc_dribble_3", "source": "03_Dribble_03.fbx", "paths": ["toe_l", "toe_r"], "role": "mocap"},
	{"id": "mc_juggling_1", "source": "04_Juggling_01.fbx", "paths": ["toe_l", "toe_r", "knee_l", "knee_r", "head"], "role": "mocap"},
	{"id": "mc_juggling_3", "source": "06_Juggling_03.fbx", "paths": ["toe_l", "toe_r", "knee_l", "knee_r", "head"], "role": "mocap"},
	{"id": "mc_throw_in", "source": "07_Throw_In.fbx", "paths": ["hands"], "role": "mocap"},
	{"id": "mc_celebration_1", "source": "12_Goal_Celebration_01.fbx", "role": "mocap"},
	{"id": "mc_celebration_2", "source": "13_Goal_Celebration_02.fbx", "role": "mocap"},
	{"id": "mc_celebration_3", "source": "14_Goal_Celebration_03.fbx", "role": "mocap"},
	{"id": "mc_keeper_save_1", "source": "15_Goalkeeper_Save_01.fbx", "paths": ["hands"], "role": "mocap"},
	{"id": "mc_keeper_save_2", "source": "16_Goalkeeper_Save_02.fbx", "paths": ["hands"], "role": "mocap"},
	{"id": "mc_keeper_save_3", "source": "17_Goalkeeper_Save_03.fbx", "paths": ["hands"], "role": "mocap"},
	{"id": "mc_defending_1", "source": "18_Defending_01.fbx", "role": "mocap"},
	{"id": "mc_defending_2", "source": "19_Defending_02.fbx", "role": "mocap"},
	{"id": "mc_yellow_card", "source": "20_Yellow_Card.fbx", "role": "mocap"},
	{"id": "mc_red_card", "source": "21_Yellow_And_Red_Card.fbx", "role": "mocap"},
]

## Animaciones ya preparadas (giradas y recortadas) por clave "prep:<id>".
var _prepared := {}

func _ready() -> void:
	_vis = FootballerVisual.new()
	add_child(_vis)
	_vis.build(FootballerVisual.default_kit(0))
	_vis.anim_tree.active = false
	_tsk = _vis.skeleton
	var src_sk: Skeleton3D = ((load(SRC_DIR + "01_Dribble_01.fbx") as PackedScene).instantiate()).find_children("*", "Skeleton3D", true, false)[0]
	_toe = [_tsk.find_bone("mixamorig_LeftToeBase"), _tsk.find_bone("mixamorig_RightToeBase")]
	_ankle = [_tsk.find_bone("mixamorig_LeftFoot"), _tsk.find_bone("mixamorig_RightFoot")]
	_rest_ankle_y = minf(PoseSampler.bone_in_skeleton(_tsk, _ankle[0]).origin.y, PoseSampler.bone_in_skeleton(_tsk, _ankle[1]).origin.y)
	_rt = PackRetarget.new()
	_rt.bone_map = ROKOKO_MAP
	_rt.setup(src_sk, _tsk)
	var root_rest: Basis = _global_rest_basis(src_sk, src_sk.get_bone_parent(src_sk.find_bone("Hips")))
	var clips: Array = []
	for e in CLIPS:
		var entry: Dictionary = (e as Dictionary).duplicate(true)
		if not FileAccess.file_exists(SRC_DIR + String(entry["source"])) and not ResourceLoader.exists(SRC_DIR + String(entry["source"])):
			print("MOCAP falta %s: se omite" % entry["source"])
			continue
		var raw: Animation = _load_raw(entry["source"])
		# La primera imagen de cada toma es la pose de referencia de la captura (de pie, distinta del movimiento): se
		# descarta (medido: todos los clips saltaban 80-177 grados entre la imagen 0 y la 1).
		raw = _trim(raw, _first_motion_time(raw), raw.length)
		var prepared: Animation = _prepare_kick(raw, entry, root_rest) if entry.get("kick", false) else raw
		_prepared["prep:" + String(entry["id"])] = prepared
		entry["source"] = "prep:" + String(entry["id"])
		clips.append(entry)
	_rt.hips_lift = _calibrate_lift(clips)
	print("MOCAP hips_lift=%.4f (%.1f cm en juego)" % [_rt.hips_lift, _rt.hips_lift * GAME_SCALE * 100.0])
	var lib := AnimationLibrary.new()
	for entry in clips:
		var variants: Array = [false]
		if entry.get("mirror", false):
			variants.append(true)
		for mirrored in variants:
			var anim: Animation = _convert(entry, mirrored)
			var id: String = String(entry["id"]) + ("_mirror" if mirrored else "")
			var m: Dictionary = anim.get_meta("pack")
			m["mocap"] = true
			anim.set_meta("pack", m)
			lib.add_animation(id, anim)
			print(_line(id, m))
	var err: int = ResourceSaver.save(lib, OUT_MOCAP)
	print("MOCAP guardado: %s (error=%d, %d clips)" % [OUT_MOCAP, err, lib.get_animation_list().size()])
	get_tree().quit(0 if err == OK else 1)

func _load_anim(rel: String) -> Animation:
	if _prepared.has(rel):
		return _prepared[rel]
	return _load_raw(rel)

func _load_raw(rel: String) -> Animation:
	var inst: Node = (load(SRC_DIR + rel) as PackedScene).instantiate()
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var a: Animation = null
	for n in ap.get_animation_list():
		if n != "RESET":
			a = ap.get_animation(n).duplicate()
	inst.free()
	return a

static func _global_rest_basis(sk: Skeleton3D, b: int) -> Basis:
	var t := Transform3D.IDENTITY
	var chain: Array[int] = []
	var x: int = b
	while x >= 0:
		chain.append(x)
		x = sk.get_bone_parent(x)
	for i in range(chain.size() - 1, -1, -1):
		t = t * sk.get_bone_rest(chain[i])
	return t.basis

## Golpeo: contacto en la toma completa, giro para que el pie salga hacia adelante y recorte alrededor del contacto.
func _prepare_kick(raw: Animation, entry: Dictionary, root_rest: Basis) -> Animation:
	_rt.mirror = false
	_rt.hips_lift = 0.0
	var b: Dictionary = _rt.bind(raw)
	var c: Dictionary = _detect_contact(raw, b)
	var t_c: float = c["time"]
	var dir: Vector2 = _swing_dir(b, t_c, int(c["foot"]))
	var yaw: float = atan2(dir.y, dir.x) if entry.get("face", false) else 0.0
	var turned: Animation = _rotate_yaw(raw, yaw, root_rest)
	var win: Array = entry.get("window", [0.8, 0.6])
	var out: Animation = _trim(turned, maxf(t_c - float(win[0]), 0.0), minf(t_c + float(win[1]), raw.length))
	print("MOCAP %s: contacto en la toma a %.2f s (pie %s), giro %.0f grados, ventana %.2f s" % [entry["id"], t_c, "D" if int(c["foot"]) > 0 else "I", rad_to_deg(yaw), out.length])
	return out

## Instante de la segunda clave de la toma (la primera es la pose de referencia de la captura).
static func _first_motion_time(a: Animation) -> float:
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D and a.track_get_key_count(t) > 1:
			return a.track_get_key_time(t, 1)
	return 0.0

## Direccion (adelante, derecha) de la punta del pie que golpea en el contacto, en el esqueleto del futbolista.
func _swing_dir(b: Dictionary, t: float, foot: int) -> Vector2:
	var f: int = 1 if foot > 0 else 0
	var dt: float = 1.0 / 60.0
	_rt.pose(b, maxf(t - dt, 0.0), true)
	var p0: Vector3 = PoseSampler.bone_in_skeleton(_tsk, _toe[f]).origin
	_rt.pose(b, t + dt, true)
	var p1: Vector3 = PoseSampler.bone_in_skeleton(_tsk, _toe[f]).origin
	var d := Vector2(p1.x - p0.x, p1.z - p0.z)
	return d.normalized() if d.length() > 0.0001 else Vector2(1.0, 0.0)

## Gira la toma `yaw` rad alrededor del eje vertical (en el espacio del padre de la cadera): rotacion y posicion de la
## cadera. Girar alrededor de Y conmuta con el paso al esqueleto del futbolista (A = giro en Y), asi que la direccion del
## golpeo medida alli queda en +X.
func _rotate_yaw(a: Animation, yaw: float, root_rest: Basis) -> Animation:
	if absf(yaw) < 0.001:
		return a
	var out: Animation = a.duplicate()
	var r_world := Basis(Vector3.UP, yaw)
	var r_local: Basis = root_rest.inverse() * r_world * root_rest
	var q_local: Quaternion = r_local.get_rotation_quaternion()
	for t in out.get_track_count():
		var path: String = str(out.track_get_path(t))
		if not path.ends_with(":Hips"):
			continue
		match out.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				for k in out.track_get_key_count(t):
					out.track_set_key_value(t, k, (q_local * (out.track_get_key_value(t, k) as Quaternion)).normalized())
			Animation.TYPE_POSITION_3D:
				for k in out.track_get_key_count(t):
					out.track_set_key_value(t, k, r_local * (out.track_get_key_value(t, k) as Vector3))
	return out

## Recorta [t0, t1] y lo lleva a empezar en 0 (remuestreado a FPS).
func _trim(a: Animation, t0: float, t1: float) -> Animation:
	var out := Animation.new()
	out.length = t1 - t0
	out.step = 1.0 / FPS
	var n: int = int(round((t1 - t0) * FPS))
	for t in a.get_track_count():
		var ty: int = a.track_get_type(t)
		if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
			continue
		var nt: int = out.add_track(ty)
		out.track_set_path(nt, a.track_get_path(t))
		for k in n + 1:
			var tt: float = minf(t0 + k / FPS, t1)
			if ty == Animation.TYPE_ROTATION_3D:
				out.rotation_track_insert_key(nt, k / FPS, a.rotation_track_interpolate(t, tt))
			else:
				out.position_track_insert_key(nt, k / FPS, a.position_track_interpolate(t, tt))
	return out
