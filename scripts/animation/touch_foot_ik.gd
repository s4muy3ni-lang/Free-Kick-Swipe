class_name TouchFootIK
extends SkeletonModifier3D
## Correccion del pie en los toques de conduccion: IK de dos huesos (cadera-rodilla-tobillo) en tiempo real, encima de
## la animacion. El clip de toque (TouchClipBuilder) da el gesto y este modificador lleva la punta del pie unos
## centimetros hasta el punto real de la pelota (algo mas adelante o atras, por dentro o por fuera), con la correccion
## y el peso que le da BallHandler en cada paso. Con peso 0 no toca la pose.
## Tambien lo usa TouchClipBuilder (herramienta) para construir los clips: ik_toe es el mismo calculo.

## Correccion maxima (m) de la punta del pie.
const MAX_SHIFT := 0.16
const LEG := {
	0: [&"mixamorig_LeftUpLeg", &"mixamorig_LeftLeg", &"mixamorig_LeftFoot", &"mixamorig_LeftToeBase"],
	1: [&"mixamorig_RightUpLeg", &"mixamorig_RightLeg", &"mixamorig_RightFoot", &"mixamorig_RightToeBase"],
}

var _shift: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _weight: Array[float] = [0.0, 0.0]
## Imagenes desde la ultima correccion recibida: si nadie la refresca (accion a mitad de toque) se suelta sola.
var _age: Array[int] = [0, 0]
var _bones: Array = []
## Pie llevado a un punto del mundo (pisar la pelota con la suela, DragBack): punta, giro del pie y peso por pie.
var _abs_target: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _abs_pitch: Array[float] = [0.0, 0.0]
var _abs_weight: Array[float] = [0.0, 0.0]
var _abs_age: Array[int] = [0, 0]
## Punta del pie (mundo) tal como quedo tras el IK de set_target en la ultima imagen (las pruebas miden la suela).
var abs_toe_world: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Pose realmente enviada al renderizador. Skeleton3D restaura la pose base tras ejecutar sus modificadores;
## get_bone_global_pose fuera de este callback no sirve para verificar el resultado del IK.
var rendered_toe_world: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var rendered_ankle_world: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var rendered_frame: Array[int] = [-1, -1]

## Correccion de la punta del pie `foot` (0 izquierdo, 1 derecho): desplazamiento en el mundo (se limita a MAX_SHIFT) y
## peso 0-1. Se mantiene hasta la siguiente llamada.
func set_correction(foot: int, shift_world: Vector3, weight: float) -> void:
	if foot < 0 or foot > 1:
		return
	_shift[foot] = shift_world.limit_length(MAX_SHIFT)
	_weight[foot] = clampf(weight, 0.0, 1.0)
	_age[foot] = 0

## Lleva la punta del pie `foot` a world_toe (mundo, sin el limite de MAX_SHIFT) con el pie girado pitch rad (negativo =
## punta abajo), con el peso dado (0 la suelta). Manda sobre la correccion de set_correction. Sin refresco se suelta sola.
func set_target(foot: int, world_toe: Vector3, pitch: float, weight: float) -> void:
	if foot < 0 or foot > 1:
		return
	_abs_target[foot] = world_toe
	_abs_pitch[foot] = pitch
	_abs_weight[foot] = clampf(weight, 0.0, 1.0)
	_abs_age[foot] = 0

func weight(foot: int) -> float:
	return _weight[foot] if foot >= 0 and foot <= 1 else 0.0

## Desplazamiento (mundo) que se aplica ahora a la punta del pie. Las lecturas de huesos fuera del modificador
## (Skeleton3D.get_bone_global_pose) devuelven la pose ANTES de los modificadores: hay que sumarselo.
func applied_shift(foot: int) -> Vector3:
	return _shift[foot] * _weight[foot] if foot >= 0 and foot <= 1 else Vector3.ZERO

func _process_modification_with_delta(_delta: float) -> void:
	Prof.begin(&"IK de pie")
	_ik_step(_delta)
	Prof.end(&"IK de pie")

func _ik_step(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or (_weight[0] < 0.001 and _weight[1] < 0.001 and _abs_weight[0] < 0.001 and _abs_weight[1] < 0.001):
		return
	if _bones.is_empty():
		for f in 2:
			var ids: Array = []
			for n in LEG[f]:
				ids.append(sk.find_bone(n))
			_bones.append(ids)
	var to_skel: Basis = sk.global_transform.basis.inverse()
	var up: Vector3 = (to_skel * Vector3.UP).normalized()
	var to_local: Transform3D = sk.global_transform.affine_inverse()
	for f in 2:
		_age[f] += 1
		if _age[f] > 4:
			_weight[f] *= 0.7
		_abs_age[f] += 1
		if _abs_age[f] > 4:
			_abs_weight[f] *= 0.7
		if (_bones[f] as Array).has(-1):
			continue
		if _abs_weight[f] >= 0.001:
			var toe_pose: Vector3 = PoseSampler.bone_in_skeleton(sk, _bones[f][3]).origin
			var w: float = _abs_weight[f]
			ik_toe(sk, _bones[f], toe_pose.lerp(to_local * _abs_target[f], w), up, _abs_pitch[f] * w, _body_forward(sk, up))
			abs_toe_world[f] = sk.global_transform * PoseSampler.bone_in_skeleton(sk, _bones[f][3]).origin
			_capture_rendered_foot(sk, f)
			continue
		if _weight[f] < 0.001:
			continue
		var toe: Vector3 = PoseSampler.bone_in_skeleton(sk, _bones[f][3]).origin
		ik_toe(sk, _bones[f], toe + to_skel * (_shift[f] * _weight[f]), up, 0.0)
		_capture_rendered_foot(sk, f)

func _capture_rendered_foot(sk: Skeleton3D, foot: int) -> void:
	rendered_toe_world[foot] = sk.global_transform * PoseSampler.bone_in_skeleton(sk, _bones[foot][3]).origin
	rendered_ankle_world[foot] = sk.global_transform * PoseSampler.bone_in_skeleton(sk, _bones[foot][2]).origin
	rendered_frame[foot] = Engine.get_process_frames()

## Frente del cuerpo en el espacio del esqueleto (de cadera izquierda a derecha, girado sobre la vertical).
func _body_forward(sk: Skeleton3D, up: Vector3) -> Vector3:
	var l: Vector3 = PoseSampler.bone_in_skeleton(sk, _bones[0][0]).origin
	var r: Vector3 = PoseSampler.bone_in_skeleton(sk, _bones[1][0]).origin
	var fwd: Vector3 = (l - r).cross(up)
	return fwd.normalized() if fwd.length() > 1e-5 else Vector3.ZERO

static func _set_global_basis(sk: Skeleton3D, bone: int, global_basis: Basis) -> void:
	var parent: int = sk.get_bone_parent(bone)
	var pb: Basis = PoseSampler.bone_in_skeleton(sk, parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone, (pb.inverse() * global_basis.orthonormalized()).get_rotation_quaternion())

## Lleva la punta del pie de la pierna `bones` [muslo, pierna, pie, punta] a want_toe (espacio del esqueleto) y gira el
## pie `pitch` radianes alrededor de su eje lateral (negativo = punta hacia abajo). up: arriba del mundo en el espacio
## del esqueleto. IK analitico de dos huesos con el polo de la rodilla actual (la rodilla sigue mirando adonde miraba).
## knee_fwd (frente del cuerpo, opcional): la rodilla se inclina hacia adelante. Con la pierna casi estirada el polo actual
## es inestable: al pisar la pelota la rodilla se doblaba hacia dentro o hacia atras (la pierna se veia deformada).
static func ik_toe(sk: Skeleton3D, bones: Array, want_toe: Vector3, up: Vector3, pitch: float, knee_fwd: Vector3 = Vector3.ZERO) -> void:
	var u: int = bones[0]
	var l: int = bones[1]
	var f: int = bones[2]
	var t: int = bones[3]
	var g_u: Transform3D = PoseSampler.bone_in_skeleton(sk, u)
	var g_l: Transform3D = PoseSampler.bone_in_skeleton(sk, l)
	var g_f: Transform3D = PoseSampler.bone_in_skeleton(sk, f)
	var g_t: Transform3D = PoseSampler.bone_in_skeleton(sk, t)
	var foot_vec: Vector3 = g_t.origin - g_f.origin
	var axis: Vector3 = foot_vec.cross(up)
	var extra := Basis.IDENTITY
	if axis.length() > 1e-5 and absf(pitch) > 1e-5:
		extra = Basis(axis.normalized(), pitch)
	var want_ankle: Vector3 = want_toe - extra * foot_vec
	var h: Vector3 = g_u.origin
	var k: Vector3 = g_l.origin
	var l1: float = (k - h).length()
	var l2: float = (g_f.origin - k).length()
	var dv: Vector3 = want_ankle - h
	var d: float = clampf(dv.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir: Vector3 = dv.normalized()
	var ax: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var hh: float = sqrt(maxf(l1 * l1 - ax * ax, 0.0))
	var pole: Vector3 = (k - h) - dir * (k - h).dot(dir)
	if pole.length() < 1e-5:
		pole = up.cross(dir)
	pole = pole.normalized()
	if knee_fwd != Vector3.ZERO:
		var pf: Vector3 = knee_fwd - dir * knee_fwd.dot(dir)
		if pf.length() > 1e-4:
			pole = (pole * maxf(pole.dot(pf.normalized()), 0.0) + pf.normalized() * 2.0).normalized()
	var k2: Vector3 = h + dir * ax + pole * hh
	_set_global_basis(sk, u, Basis(Quaternion((k - h).normalized(), (k2 - h).normalized())) * g_u.basis.orthonormalized())
	var g_l2: Transform3D = PoseSampler.bone_in_skeleton(sk, l)
	var g_f2: Transform3D = PoseSampler.bone_in_skeleton(sk, f)
	var a2: Vector3 = h + dir * d
	_set_global_basis(sk, l, Basis(Quaternion((g_f2.origin - g_l2.origin).normalized(), (a2 - g_l2.origin).normalized())) * g_l2.basis.orthonormalized())
	_set_global_basis(sk, f, extra * g_f.basis.orthonormalized())
