class_name JsonRig
extends RefCounted
## Esqueleto canonico del modo Json: 23 huesos con los nombres del futbolista (mixamorig_*) y las MEDIDAS de las
## articulaciones de los JSON de animacion (pelvis, cadera, rodilla, tobillo, punta, pecho, cabeza, clavicula, hombro,
## codo, muñeca). Los dos modelos del modo (el GLB de Tripo adaptado y el humanoide propio) cuelgan de este esqueleto,
## asi una sola libreria de clips (json_clips.res) sirve para los dos.
##
## Unidades: el modelo mide 1.0 de alto = 1.75 m (igual que el futbolista de Tripo); aqui las posiciones de reposo estan en
## METROS y UNIT las pasa a unidades del modelo. Ejes del modelo: adelante = +X, arriba = +Y, derecha = +Z.
##
## Clave del retarget: la orientacion global de cada hueso es un MARCO que sale de la geometria (direccion del hueso +
## un vector secundario: eje de la bisagra de codo/rodilla, lateral de la cadera o de los hombros...). Los marcos del
## reposo de cada modelo se calculan con la misma funcion que los de cada instante de la animacion, y el hueso se deja
## en reposo con ESA orientacion: la pose absoluta de la animacion (marco de los datos) sirve entonces igual para un
## modelo en pose A (humanoide) y en pose T (Tripo) sin tener que guardar una libreria por modelo.

const UNIT := 1.0 / 1.75
const SKELETON_PATH := "Armature/Skeleton3D"

## Orden y nombres de los huesos (los mismos 23 del futbolista de Tripo).
const BONES: Array[String] = [
	"Root", "mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head",
	"mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
	"mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
	"mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot", "mixamorig_LeftToeBase",
	"mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot", "mixamorig_RightToeBase",
]
const PARENTS: Array[int] = [-1, 0, 1, 2, 3, 4, 5, 4, 7, 8, 9, 4, 11, 12, 13, 1, 15, 16, 17, 1, 19, 20, 21]

## Articulaciones de los JSON -> hueso (la posicion de la articulacion es el ORIGEN del hueso).
const JOINT_BONE := {
	"pelvis": "mixamorig_Hips", "chest": "mixamorig_Spine2", "head": "mixamorig_Head",
	"l_clavicle": "mixamorig_LeftShoulder", "l_shoulder": "mixamorig_LeftArm", "l_elbow": "mixamorig_LeftForeArm", "l_wrist": "mixamorig_LeftHand",
	"r_clavicle": "mixamorig_RightShoulder", "r_shoulder": "mixamorig_RightArm", "r_elbow": "mixamorig_RightForeArm", "r_wrist": "mixamorig_RightHand",
	"l_hip": "mixamorig_LeftUpLeg", "l_knee": "mixamorig_LeftLeg", "l_ankle": "mixamorig_LeftFoot", "l_toe": "mixamorig_LeftToeBase",
	"r_hip": "mixamorig_RightUpLeg", "r_knee": "mixamorig_RightLeg", "r_ankle": "mixamorig_RightFoot", "r_toe": "mixamorig_RightToeBase",
}

## Longitudes (m) de los segmentos del sujeto de los datos.
const THIGH := 0.339
const SHIN := 0.420
const FOOT := 0.180
const UPPER_ARM := 0.258
const FOREARM := 0.325
const CLAVICLE := 0.160
const HIP_HALF := 0.1075
const PELVIS_H := 0.853
## Punto «head» de los datos (centro de la cabeza) sobre el origen del hueso Head.
const HEAD_POINT_UP := 0.08

enum Pose { A, T }

## Posiciones de reposo (metros, espacio del modelo: X adelante, Y arriba, Z derecha) por hueso. Pose A: brazos caidos con
## 18 grados de abertura; pose T: brazos en cruz (el GLB de Tripo esta modelado asi).
static func rest_positions(pose: int = Pose.A) -> Dictionary:
	var p := {}
	p["Root"] = Vector3.ZERO
	p["mixamorig_Hips"] = Vector3(0.0, PELVIS_H, 0.0)
	p["mixamorig_Spine"] = Vector3(0.0, 1.000, 0.0)
	p["mixamorig_Spine1"] = Vector3(0.0, 1.170, 0.0)
	p["mixamorig_Spine2"] = Vector3(0.0, 1.380, 0.0)
	p["mixamorig_Neck"] = Vector3(0.0, 1.455, 0.0)
	p["mixamorig_Head"] = Vector3(0.0, 1.530, 0.0)
	for side in [-1, 1]:
		var n: String = "Right" if side > 0 else "Left"
		var s: float = float(side)
		# Pierna: rodilla 2.2 cm por delante de la linea cadera-tobillo (flexion de 6 grados: la bisagra queda definida).
		p["mixamorig_%sUpLeg" % n] = Vector3(0.0, PELVIS_H, s * HIP_HALF)
		p["mixamorig_%sLeg" % n] = Vector3(0.0222, PELVIS_H - 0.3383, s * HIP_HALF)
		p["mixamorig_%sFoot" % n] = Vector3(0.0, 0.095, s * HIP_HALF)
		p["mixamorig_%sToeBase" % n] = Vector3(0.158, 0.008, s * HIP_HALF)
		# Brazo.
		p["mixamorig_%sShoulder" % n] = Vector3(0.0, 1.443, s * 0.03)
		var sh := Vector3(0.0, 1.403, s * 0.185)
		p["mixamorig_%sArm" % n] = sh
		if pose == Pose.A:
			var e: Vector3 = sh + Vector3(0.0, -cos(deg_to_rad(18.0)), s * sin(deg_to_rad(18.0))) * UPPER_ARM
			p["mixamorig_%sForeArm" % n] = e
			p["mixamorig_%sHand" % n] = e + Vector3(0.30, -0.93, s * 0.20).normalized() * FOREARM
		else:
			var e2: Vector3 = sh + Vector3(0.0, 0.0, s) * UPPER_ARM
			p["mixamorig_%sForeArm" % n] = e2
			p["mixamorig_%sHand" % n] = e2 + Vector3(0.0, 0.0, s) * FOREARM
	return p

## Origen del punto «head» de los datos (centro de la cabeza) para el reposo.
static func head_point() -> Vector3:
	return Vector3(0.0, 1.530 + HEAD_POINT_UP, 0.0)

# --- Marcos --------------------------------------------------------------------------------------------------------

## Marco con el lateral (columna 0) y el «arriba» (columna 1): la convencion de pelvis, columna, cuello y cabeza.
## trust_lat: el lateral es exacto y el arriba se corrige; si no, al reves.
static func frame_lu(lat: Vector3, up: Vector3, trust_lat: bool) -> Basis:
	var e1: Vector3
	var e2: Vector3
	if trust_lat:
		e1 = lat.normalized()
		e2 = up - e1 * up.dot(e1)
		if e2.length_squared() < 1e-9:
			e2 = Vector3.UP - e1 * Vector3.UP.dot(e1)
		e2 = e2.normalized()
	else:
		e2 = up.normalized()
		e1 = lat - e2 * lat.dot(e2)
		if e1.length_squared() < 1e-9:
			e1 = Vector3.BACK - e2 * Vector3.BACK.dot(e2)
		e1 = e1.normalized()
	return Basis(e1, e2, e1.cross(e2))

## Marco con la direccion del hueso (columna 0) y un vector secundario (columna 1): brazos, piernas, clavicula, pie.
static func frame_ds(dir: Vector3, sec: Vector3) -> Basis:
	var e1: Vector3 = dir.normalized()
	var e2: Vector3 = sec - e1 * sec.dot(e1)
	if e2.length_squared() < 1e-9:
		e2 = Vector3.UP - e1 * Vector3.UP.dot(e1)
		if e2.length_squared() < 1e-9:
			e2 = Vector3.BACK - e1 * Vector3.BACK.dot(e1)
	e2 = e2.normalized()
	return Basis(e1, e2, e1.cross(e2))

## Mezcla de dos marcos (slerp de sus rotaciones).
static func blend(a: Basis, b: Basis, t: float) -> Basis:
	return Basis(a.get_rotation_quaternion().slerp(b.get_rotation_quaternion(), t))

## Marcos de reposo de los 23 huesos: {hueso: Basis}, calculados con la misma funcion que usa JsonRetarget por cada
## instante (por eso la pose absoluta de un clip vale para cualquier modelo construido con estas posiciones).
static func rest_frames(pose: int = Pose.A) -> Dictionary:
	return JsonRetarget.rest_frames_for(rest_positions(pose))

## Posicion de reposo de cada hueso respecto a su padre, en el marco de reposo del padre (la «traslacion local»).
static func rest_offsets(pose: int = Pose.A) -> Dictionary:
	var pos: Dictionary = rest_positions(pose)
	var fr: Dictionary = rest_frames(pose)
	var out := {}
	for i in BONES.size():
		var b: String = BONES[i]
		var par: int = PARENTS[i]
		if par < 0:
			out[b] = pos[b] * UNIT
		else:
			var pf: Basis = fr[BONES[par]]
			out[b] = pf.inverse() * ((pos[b] as Vector3) - (pos[BONES[par]] as Vector3)) * UNIT
	return out

## Esqueleto del modelo en reposo (sin malla): cada hueso con la rotacion local de reposo que deja su marco global igual
## al marco de reposo y la traslacion local en unidades del modelo.
static func build_skeleton(pose: int = Pose.A) -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	var fr: Dictionary = rest_frames(pose)
	var off: Dictionary = rest_offsets(pose)
	for i in BONES.size():
		sk.add_bone(BONES[i])
	for i in BONES.size():
		var par: int = PARENTS[i]
		sk.set_bone_parent(i, par)
		var rot: Quaternion
		if par < 0:
			rot = (fr[BONES[i]] as Basis).get_rotation_quaternion()
		else:
			rot = ((fr[BONES[par]] as Basis).inverse() * (fr[BONES[i]] as Basis)).get_rotation_quaternion()
		var t := Transform3D(Basis(rot), off[BONES[i]])
		sk.set_bone_rest(i, t)
		sk.set_bone_pose_position(i, t.origin)
		sk.set_bone_pose_rotation(i, rot)
	return sk

## Hueso (nombre) de la articulacion `joint` de los JSON, o "" si no hay.
static func bone_of(joint: String) -> String:
	return JOINT_BONE.get(joint, "")

## Datos (espacio del juego: x derecha, y arriba, z atras) -> espacio del modelo (X adelante, Y arriba, Z derecha), metros.
static func data_to_model(p: Vector3) -> Vector3:
	return Vector3(-p.z, p.y, p.x)
