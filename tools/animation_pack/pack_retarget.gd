class_name PackRetarget
extends RefCounted
## EXPERIMENTO (no lo usa el juego): aplica un clip del pack (esqueleto Y Bot de 65 huesos, Z adelante) sobre
## el esqueleto de Tripo (23 huesos, +X adelante) comparando poses de reposo en el espacio del modelo:
##   D(hueso) = Pose_global_Y * Reposo_global_Y^-1   (rotacion que lleva el reposo a la pose)
##   Pose_global_T = A * D * A^-1 * Reposo_global_T   (A = giro de +90 grados en Y: +Z -> +X)
##   local_T = Pose_global_T(padre)^-1 * Pose_global_T(hueso)
## La cadera se traslada con el factor de altura de cadera (Tripo / Y Bot).

var ysk: Skeleton3D
var tsk: Skeleton3D
var a_q := Quaternion(Vector3.UP, deg_to_rad(90.0))
var k_pos: float = 1.0
var y_rest_g: Array[Quaternion] = []
var t_rest_g: Array[Quaternion] = []
var t_root_inv: Transform3D = Transform3D.IDENTITY
var t_hips: int = -1
var y_hips: int = -1
var shared: Array[int] = []     # indices Tripo con equivalente Y Bot
var y_of_t: Dictionary = {}     # indice Tripo -> indice Y Bot
## Espejo: el clip se aplica con izquierda/derecha intercambiadas y reflejado respecto al plano sagital
## (sirve para obtener la version de pierna izquierda de un golpeo hecho con la derecha).
var mirror: bool = false
## Elevacion de la cadera (unidades del esqueleto de Tripo) para compensar el desfase medido del tobillo.
var hips_lift: float = 0.0
var y_mirror_of_t: Dictionary = {}   # indice Tripo -> indice Y Bot del hueso opuesto
var t_order: Array[int] = []
var y_order: Array[int] = []
## Nombre del hueso de ORIGEN para cada hueso de Tripo (vacio = mismos nombres: el pack de Mixamo). Lo usa el pack de
## mocap de futbol (esqueleto Rokoko: Hips, Spine1-4, Thigh/Shin/Foot/Toe...; ver build_mocap_library.gd).
var bone_map: Dictionary = {}

func _src(t_name: String) -> String:
	return String(bone_map.get(t_name, t_name))

func _global_rest(sk: Skeleton3D, b: int) -> Transform3D:
	var chain: Array[int] = []
	var x: int = b
	while x >= 0:
		chain.append(x)
		x = sk.get_bone_parent(x)
	var t := Transform3D.IDENTITY
	for i in range(chain.size() - 1, -1, -1):
		t = t * sk.get_bone_rest(chain[i])
	return t

func _order(sk: Skeleton3D) -> Array[int]:
	var out: Array[int] = []
	var seen := {}
	var pending: Array[int] = []
	for i in sk.get_bone_count():
		pending.append(i)
	while out.size() < sk.get_bone_count():
		for i in pending:
			if seen.has(i):
				continue
			var p: int = sk.get_bone_parent(i)
			if p < 0 or seen.has(p):
				out.append(i)
				seen[i] = true
	return out

func setup(y_skel: Skeleton3D, t_skel: Skeleton3D) -> void:
	ysk = y_skel
	tsk = t_skel
	for i in ysk.get_bone_count():
		y_rest_g.append(_global_rest(ysk, i).basis.get_rotation_quaternion())
	for i in tsk.get_bone_count():
		t_rest_g.append(_global_rest(tsk, i).basis.get_rotation_quaternion())
	y_hips = ysk.find_bone(_src("mixamorig_Hips"))
	t_hips = tsk.find_bone("mixamorig_Hips")
	var troot: int = tsk.get_bone_parent(t_hips)
	t_root_inv = (_global_rest(tsk, troot) if troot >= 0 else Transform3D.IDENTITY).affine_inverse()
	k_pos = _global_rest(tsk, t_hips).origin.y / _global_rest(ysk, y_hips).origin.y
	for i in tsk.get_bone_count():
		var j: int = ysk.find_bone(_src(tsk.get_bone_name(i)))
		if j >= 0:
			y_of_t[i] = j
	for i in tsk.get_bone_count():
		var n: String = tsk.get_bone_name(i)
		var m: String = n.replace("Left", "\u0001").replace("Right", "Left").replace("\u0001", "Right")
		var j2: int = ysk.find_bone(_src(m))
		if j2 >= 0:
			y_mirror_of_t[i] = j2
	t_order = _order(tsk)
	y_order = _order(ysk)

## track_of: nombre de hueso (sin prefijo) -> indice de pista de rotacion; hips_track: pista de posicion de la cadera.
func bind(anim: Animation) -> Dictionary:
	var rot := {}
	var pos := -1
	for t in anim.get_track_count():
		var path: String = str(anim.track_get_path(t))
		var bname: String = path.substr(path.find(":") + 1)
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot[bname] = t
		elif anim.track_get_type(t) == Animation.TYPE_POSITION_3D and bname.ends_with("Hips"):
			pos = t
	var mean := Vector3.ZERO
	if pos >= 0:
		var n: int = anim.track_get_key_count(pos)
		for k in n:
			mean += anim.track_get_key_value(pos, k)
		mean /= maxf(n, 1)
	return {"rot": rot, "pos": pos, "mean": mean, "anim": anim}

## Aplica el instante t del clip al esqueleto de Tripo. strip_xz: elimina el movimiento raiz horizontal.
func pose(b: Dictionary, t: float, strip_xz: bool = true) -> void:
	var anim: Animation = b["anim"]
	var rot: Dictionary = b["rot"]
	var pg_y: Array[Quaternion] = []
	pg_y.resize(ysk.get_bone_count())
	for i in y_order:
		var name: String = ysk.get_bone_name(i)
		var q: Quaternion
		if rot.has(name):
			q = anim.rotation_track_interpolate(rot[name], t)
		else:
			q = ysk.get_bone_rest(i).basis.get_rotation_quaternion()
		var p: int = ysk.get_bone_parent(i)
		pg_y[i] = (pg_y[p] * q) if p >= 0 else q
	var pg_t: Array[Quaternion] = []
	pg_t.resize(tsk.get_bone_count())
	for i in t_order:
		var g: Quaternion
		if y_of_t.has(i):
			var j: int = y_mirror_of_t[i] if (mirror and y_mirror_of_t.has(i)) else y_of_t[i]
			var d: Quaternion = a_q * (pg_y[j] * y_rest_g[j].inverse()) * a_q.inverse()
			if mirror:
				d = Quaternion(-d.x, -d.y, d.z, d.w)   # reflexion respecto al plano XY del esqueleto de Tripo (lateral = Z)
			g = d * t_rest_g[i]
		else:
			g = t_rest_g[i]
		pg_t[i] = g
		var p: int = tsk.get_bone_parent(i)
		var local: Quaternion = (pg_t[p].inverse() * g) if p >= 0 else g
		tsk.set_bone_pose_rotation(i, local.normalized())
	if b["pos"] >= 0:
		var v: Vector3 = anim.position_track_interpolate(b["pos"], t)
		if strip_xz:
			var rest: Vector3 = ysk.get_bone_rest(y_hips).origin
			v.x = rest.x
			v.z = rest.z
		var model: Vector3 = (a_q * v) * k_pos
		if mirror:
			model.z = -model.z
		model.y += hips_lift
		tsk.set_bone_pose_position(t_hips, t_root_inv * model)
	tsk.force_update_all_bone_transforms()

func ankle_min_height() -> float:
	var best := 1e9
	for n in ["mixamorig_LeftFoot", "mixamorig_RightFoot"]:
		var i: int = tsk.find_bone(n)
		best = minf(best, PoseSampler.bone_in_skeleton(tsk, i).origin.y)
	return best

## Desplazamiento raiz acumulado (adelante, derecha) en metros de juego en el instante t, respecto al primer fotograma.
func root_offset(b: Dictionary, t: float) -> Vector2:
	if b["pos"] < 0:
		return Vector2.ZERO
	var anim: Animation = b["anim"]
	var v0: Vector3 = anim.position_track_interpolate(b["pos"], 0.0)
	var v: Vector3 = anim.position_track_interpolate(b["pos"], t)
	var d: Vector3 = (a_q * (v - v0)) * k_pos * 1.75
	return Vector2(d.x, -d.z if mirror else d.z)
