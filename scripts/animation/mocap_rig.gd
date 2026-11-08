class_name MocapRig
extends Node3D
## Modelo propio del modo 2 (Newton del «Mocap Pack 05 Soccer» en baja poligonizacion, assets/characters/mocap/
## mocap_player.scn, con su esqueleto Rokoko de 76 huesos). El juego sigue moviendo el esqueleto del futbolista (golpeos,
## toques, IK del pie); cada vez que ese esqueleto termina su pose (señal skeleton_updated, ya con los modificadores) se
## copia a este con la misma transferencia del retarget (PackRetarget) al reves:
##   Global_R(j) = A^-1 * (Global_T(i) * Reposo_T(i)^-1) * A * Reposo_R(j)
## (A = giro de 90 grados en Y: +Z de Rokoko -> +X del futbolista). La cadera sigue a la del futbolista, escalada por la
## altura de cadera. Los dedos y huesos sin equivalente conservan su pose de reposo respecto de su padre. Como las
## proporciones no son iguales, piernas y brazos se cierran con IK de dos huesos hasta los pies y las manos del futbolista.

const SCENE_PATH := "res://assets/characters/mocap/mocap_player.scn"
const KIT_SHADER: Shader = preload("res://assets/characters/mocap/mocap_kit.gdshader")
## Hueso del futbolista -> hueso Rokoko (el mismo mapa que el conversor de animaciones).
const MAP := {
	"mixamorig_Hips": "Hips", "mixamorig_Spine": "Spine1", "mixamorig_Spine1": "Spine3", "mixamorig_Spine2": "Spine4",
	"mixamorig_Neck": "Neck", "mixamorig_Head": "Head",
	"mixamorig_LeftShoulder": "LeftShoulder", "mixamorig_LeftArm": "LeftArm", "mixamorig_LeftForeArm": "LeftForeArm", "mixamorig_LeftHand": "LeftHand",
	"mixamorig_RightShoulder": "RightShoulder", "mixamorig_RightArm": "RightArm", "mixamorig_RightForeArm": "RightForeArm", "mixamorig_RightHand": "RightHand",
	"mixamorig_LeftUpLeg": "LeftThigh", "mixamorig_LeftLeg": "LeftShin", "mixamorig_LeftFoot": "LeftFoot", "mixamorig_LeftToeBase": "LeftToe",
	"mixamorig_RightUpLeg": "RightThigh", "mixamorig_RightLeg": "RightShin", "mixamorig_RightFoot": "RightFoot", "mixamorig_RightToeBase": "RightToe",
}

var src: Skeleton3D
var dst: Skeleton3D
var material: ShaderMaterial
var _a := Quaternion(Vector3.UP, deg_to_rad(90.0))
## Huesos Rokoko que se recalculan (los del mapa y sus ancestros), en orden padre -> hijo.
var _order: Array[int] = []
var _src_of: Dictionary = {}          # hueso Rokoko -> hueso del futbolista
var _src_rest_inv: Dictionary = {}    # hueso del futbolista -> inversa de su rotacion global de reposo
var _dst_rest_g: Dictionary = {}      # hueso Rokoko -> rotacion global de reposo
var _src_hips: int = -1
var _dst_hips: int = -1
var _scale: float = 1.0
## Cadenas con IK: [hueso a, hueso b, hueso c de Newton, hueso del futbolista que marca el objetivo].
var _limbs: Array = []
const LIMBS := [
	["LeftThigh", "LeftShin", "LeftFoot", "mixamorig_LeftFoot"], ["RightThigh", "RightShin", "RightFoot", "mixamorig_RightFoot"],
	["LeftArm", "LeftForeArm", "LeftHand", "mixamorig_LeftHand"], ["RightArm", "RightForeArm", "RightHand", "mixamorig_RightHand"],
]

static func available() -> bool:
	return ResourceLoader.exists(SCENE_PATH)

## Monta el modelo junto al esqueleto del futbolista `skel` (que queda invisible: lo esconde FootballerVisual).
func setup(skel: Skeleton3D) -> bool:
	src = skel
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		return false
	var inst: Node3D = scene.instantiate()
	add_child(inst)
	dst = inst.find_children("*", "Skeleton3D", true, false)[0]
	material = ShaderMaterial.new()
	material.shader = KIT_SHADER
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = material
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_src_hips = src.find_bone("mixamorig_Hips")
	_dst_hips = dst.find_bone("Hips")
	# Escala: la cadera de reposo de Newton a la altura de la del futbolista.
	var src_hip_y: float = _global_rest(src, _src_hips).origin.y
	var dst_hip_y: float = (_global_rest(dst, _dst_hips).origin - _global_rest(dst, dst.get_bone_parent(_dst_hips)).origin).y if dst.get_bone_parent(_dst_hips) >= 0 else _global_rest(dst, _dst_hips).origin.y
	_scale = src_hip_y / maxf(dst_hip_y, 0.001)
	transform = src.transform * Transform3D(Basis(_a) * _scale, Vector3.ZERO)
	var needed := {}
	for t_name in MAP:
		var i: int = src.find_bone(t_name)
		var j: int = dst.find_bone(MAP[t_name])
		if i < 0 or j < 0:
			continue
		_src_of[j] = i
		_src_rest_inv[i] = _global_rest(src, i).basis.get_rotation_quaternion().inverse()
		var x: int = j
		while x >= 0:
			needed[x] = true
			x = dst.get_bone_parent(x)
	for j in dst.get_bone_count():
		_dst_rest_g[j] = _global_rest(dst, j).basis.get_rotation_quaternion()
	# Orden padre -> hijo (los indices de Rokoko ya vienen asi, pero se asegura).
	var done := {}
	while _order.size() < needed.size():
		for j in needed:
			if done.has(j):
				continue
			var p: int = dst.get_bone_parent(j)
			if p < 0 or done.has(p) or not needed.has(p):
				_order.append(j)
				done[j] = true
	for l in LIMBS:
		var ids: Array = [dst.find_bone(l[0]), dst.find_bone(l[1]), dst.find_bone(l[2]), src.find_bone(l[3])]
		if ids.all(func(x: int) -> bool: return x >= 0) and needed.has(ids[0]) and needed.has(ids[1]) and needed.has(ids[2]):
			_limbs.append(ids)
	src.skeleton_updated.connect(_copy_pose)
	return true

static func _global_rest(sk: Skeleton3D, b: int) -> Transform3D:
	var chain: Array[int] = []
	var x: int = b
	while x >= 0:
		chain.append(x)
		x = sk.get_bone_parent(x)
	var t := Transform3D.IDENTITY
	for k in range(chain.size() - 1, -1, -1):
		t = t * sk.get_bone_rest(chain[k])
	return t

func _copy_pose() -> void:
	if not is_inside_tree() or not visible:
		return
	# El esqueleto del futbolista puede desplazarse dentro del visual (agacharse, retoques): se lo sigue cada vez.
	transform = src.transform * Transform3D(Basis(_a) * _scale, Vector3.ZERO)
	# Espacio del esqueleto del futbolista -> espacio del esqueleto de Newton.
	var m: Transform3D = dst.global_transform.affine_inverse() * src.global_transform
	var g := {}
	for j in _order:
		var p: int = dst.get_bone_parent(j)
		var pg: Quaternion = g[p] if g.has(p) else (dst.get_bone_global_pose(p).basis.get_rotation_quaternion() if p >= 0 else Quaternion.IDENTITY)
		if _src_of.has(j):
			var i: int = _src_of[j]
			var d: Quaternion = src.get_bone_global_pose(i).basis.get_rotation_quaternion() * _src_rest_inv[i]
			g[j] = _a.inverse() * d * _a * _dst_rest_g[j]
		else:
			g[j] = pg * dst.get_bone_rest(j).basis.get_rotation_quaternion()
	# Cadera: la posicion del futbolista llevada al espacio de Newton.
	var hips_pos: Vector3 = m * src.get_bone_global_pose(_src_hips).origin
	# Newton no tiene las mismas proporciones: las piernas y los brazos se cierran con IK de dos huesos para que pies y
	# manos queden donde estan los del futbolista (el contacto con la pelota se mide con esos).
	var pos: Dictionary = _positions(g, hips_pos)
	for chain in _limbs:
		var target: Vector3 = m * src.get_bone_global_pose(chain[3]).origin
		_two_bone(g, pos, chain[0], chain[1], chain[2], target)
	for j in _order:
		var p: int = dst.get_bone_parent(j)
		var pg: Quaternion = g[p] if g.has(p) else (dst.get_bone_global_pose(p).basis.get_rotation_quaternion() if p >= 0 else Quaternion.IDENTITY)
		dst.set_bone_pose_rotation(j, (pg.inverse() * g[j]).normalized())
	var parent: int = dst.get_bone_parent(_dst_hips)
	dst.set_bone_pose_position(_dst_hips, dst.get_bone_global_pose(parent).affine_inverse() * hips_pos if parent >= 0 else hips_pos)

## Posiciones globales (espacio del esqueleto de Newton) de los huesos recalculados, con las rotaciones `g`.
func _positions(g: Dictionary, hips_pos: Vector3) -> Dictionary:
	var pos := {}
	for j in _order:
		if j == _dst_hips:
			pos[j] = hips_pos
			continue
		var p: int = dst.get_bone_parent(j)
		if p < 0:
			pos[j] = dst.get_bone_global_pose(j).origin
		elif pos.has(p):
			pos[j] = (pos[p] as Vector3) + (g[p] as Quaternion) * dst.get_bone_rest(j).origin
		else:
			pos[j] = dst.get_bone_global_pose(p) * dst.get_bone_rest(j).origin
	return pos

## IK analitica de dos huesos: dobla `b` (rodilla / codo) hasta la distancia justa y gira `a` para que `c` llegue a
## `target`; `c` conserva su rotacion global copiada.
static func _two_bone(g: Dictionary, pos: Dictionary, a: int, b: int, c: int, target: Vector3) -> void:
	var pa: Vector3 = pos[a]
	var pb: Vector3 = pos[b]
	var pc: Vector3 = pos[c]
	var lab: float = pa.distance_to(pb)
	var lbc: float = pb.distance_to(pc)
	var lat: float = clampf(pa.distance_to(target), absf(lab - lbc) + 0.001, lab + lbc - 0.001)
	var n: Vector3 = (pa - pb).cross(pc - pb)
	if n.length_squared() > 1e-8:
		n = n.normalized()
		var cur: float = (pa - pb).angle_to(pc - pb)
		var want: float = acos(clampf((lab * lab + lbc * lbc - lat * lat) / (2.0 * lab * lbc), -1.0, 1.0))
		var bend := Quaternion(n, want - cur)
		g[b] = bend * (g[b] as Quaternion)
		pc = pb + bend * (pc - pb)
	var from: Vector3 = pc - pa
	var to: Vector3 = target - pa
	if from.length_squared() > 1e-8 and to.length_squared() > 1e-8:
		var swing := Quaternion(from.normalized(), to.normalized())
		g[a] = swing * (g[a] as Quaternion)
		g[b] = swing * (g[b] as Quaternion)

func set_kit(kit: Dictionary) -> void:
	for key in ["jersey", "shorts", "socks", "boots", "skin", "hair"]:
		if kit.has(key):
			material.set_shader_parameter("%s_color" % key, kit[key])
