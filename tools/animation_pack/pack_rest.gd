extends Node
## Compara las poses de reposo y proporciones de player_base.glb (Tripo) y personaje/ybot_tpose.fbx en un marco comun.
## Uso: godot --headless --path . res://tools/animation_pack/pack_rest.tscn
# Compara las poses de reposo de los dos esqueletos en un marco comun (Y Bot gira +90 grados en Y: +Z -> +X).

func _skel_of(root: Node) -> Skeleton3D:
	return root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

func _b(sk: Skeleton3D, n: String) -> int:
	return sk.find_bone("mixamorig_" + n)

func _rg(sk: Skeleton3D, b: int) -> Transform3D:
	var chain: Array[int] = []
	var x: int = b
	while x >= 0:
		chain.append(x)
		x = sk.get_bone_parent(x)
	var t := Transform3D.IDENTITY
	for i in range(chain.size() - 1, -1, -1):
		t = t * sk.get_bone_rest(chain[i])
	return t

func _ready() -> void:
	var tsk: Skeleton3D = _skel_of(load("res://assets/characters/player/player_base.glb").instantiate())
	var ysk: Skeleton3D = _skel_of(load("res://pack/personaje/ybot_tpose.fbx").instantiate())
	var A := Basis(Vector3.UP, deg_to_rad(90.0))
	var bones := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]
	var children := {"Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head", "LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand", "LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase", "RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase"}
	print("hueso            | giro del marco local (Tripo vs YBot, grados) | dir. del hueso (Tripo vs YBot, grados) | elev. Tripo / YBot")
	var sum_b := 0.0
	var sum_d := 0.0
	var n_b := 0
	var n_d := 0
	var worst: Array = []
	for nm in bones:
		var ti: int = _b(tsk, nm)
		var yi: int = _b(ysk, nm)
		var gt: Transform3D = _rg(tsk, ti)
		var gy: Transform3D = _rg(ysk, yi)
		var qa: Quaternion = gt.basis.orthonormalized().get_rotation_quaternion()
		var qb: Quaternion = (A * gy.basis).orthonormalized().get_rotation_quaternion()
		var ang: float = rad_to_deg(qa.angle_to(qb))
		var dirang := -1.0
		var el_t := 0.0
		var el_y := 0.0
		if children.has(nm):
			var ci_t: int = _b(tsk, children[nm])
			var ci_y: int = _b(ysk, children[nm])
			var dt: Vector3 = (_rg(tsk, ci_t).origin - gt.origin).normalized()
			var dy: Vector3 = (A * (_rg(ysk, ci_y).origin - gy.origin)).normalized()
			dirang = rad_to_deg(dt.angle_to(dy))
			el_t = rad_to_deg(asin(clampf(dt.y, -1.0, 1.0)))
			el_y = rad_to_deg(asin(clampf(dy.y, -1.0, 1.0)))
			sum_d += dirang
			n_d += 1
		sum_b += ang
		n_b += 1
		print("%-16s | %6.1f | %s | %s" % [nm, ang, ("%6.1f" % dirang) if dirang >= 0.0 else "     -", ("%6.1f / %6.1f" % [el_t, el_y]) if children.has(nm) else ""])
		worst.append([nm, ang])
	print("media giro del marco: %.1f grados; media diferencia de direccion de hueso: %.1f grados" % [sum_b / n_b, sum_d / n_d])
	# proporciones
	var ht: float = _rg(tsk, _b(tsk, "Head")).origin.y
	var hy: float = _rg(ysk, _b(ysk, "Head")).origin.y
	var kt: float = _rg(tsk, _b(tsk, "LeftLeg")).origin.y
	var ky: float = _rg(ysk, _b(ysk, "LeftLeg")).origin.y
	print("proporciones (cabeza/cadera/rodilla/tobillo sobre la altura del hueso Head): Tripo cadera=%.3f rodilla=%.3f tobillo=%.3f | YBot cadera=%.3f rodilla=%.3f tobillo=%.3f" % [
		_rg(tsk, _b(tsk, "Hips")).origin.y / ht, kt / ht, _rg(tsk, _b(tsk, "LeftFoot")).origin.y / ht,
		_rg(ysk, _b(ysk, "Hips")).origin.y / hy, ky / hy, _rg(ysk, _b(ysk, "LeftFoot")).origin.y / hy])
	var armt: float = (_rg(tsk, _b(tsk, "LeftHand")).origin - _rg(tsk, _b(tsk, "LeftShoulder")).origin).length() / ht
	var army: float = (_rg(ysk, _b(ysk, "LeftHand")).origin - _rg(ysk, _b(ysk, "LeftShoulder")).origin).length() / hy
	var legt: float = (_rg(tsk, _b(tsk, "LeftFoot")).origin - _rg(tsk, _b(tsk, "LeftUpLeg")).origin).length() / ht
	var legy: float = (_rg(ysk, _b(ysk, "LeftFoot")).origin - _rg(ysk, _b(ysk, "LeftUpLeg")).origin).length() / hy
	print("longitud brazo/altura(Head): Tripo=%.3f YBot=%.3f | pierna (cadera-tobillo)/altura(Head): Tripo=%.3f YBot=%.3f" % [armt, army, legt, legy])
	print("alturas absolutas: Tripo Head.y=%.3f hips.y=%.3f | YBot Head.y=%.3f hips.y=%.3f" % [ht, _rg(tsk, _b(tsk, "Hips")).origin.y, hy, _rg(ysk, _b(ysk, "Hips")).origin.y])
	get_tree().quit()
