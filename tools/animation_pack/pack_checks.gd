extends Node
## Comprobaciones de compatibilidad del pack con nuestro esqueleto (solo lectura):
##  1) cada FBX de animacion tiene el MISMO reposo que personaje/ybot_tpose.fbx;
##  2) cada clip trae pista de rotacion para los 22 huesos de Tripo que tienen equivalente;
##  3) las versiones _inplace coinciden con las versiones con movimiento raiz (mismas rotaciones).
## Uso: godot --headless --path . res://tools/animation_pack/pack_checks.tscn

func _collect(dir: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + d, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".fbx"):
			out.append(dir + "/" + f)

func _skel_of(root: Node) -> Skeleton3D:
	return root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

func _anim(path: String) -> Animation:
	var inst: Node = (load(path) as PackedScene).instantiate()
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var a: Animation
	for n in ap.get_animation_list():
		if n != "RESET":
			a = ap.get_animation(n)
	return a

func _ready() -> void:
	var files: Array[String] = []
	_collect("res://pack/animaciones", files)
	files.sort()
	_check_rest(files)
	_check_coverage(files)
	_check_twins(files)
	get_tree().quit()

func _check_rest(files: Array[String]) -> void:
	var ysk: Skeleton3D = _skel_of((load("res://pack/personaje/ybot_tpose.fbx") as PackedScene).instantiate())
	var worst_rot := 0.0
	var worst_pos := 0.0
	var same := 0
	for f in files:
		var sk: Skeleton3D = _skel_of((load(f) as PackedScene).instantiate())
		var ok: bool = sk.get_bone_count() == ysk.get_bone_count()
		for i in ysk.get_bone_count():
			var j: int = sk.find_bone(ysk.get_bone_name(i))
			if j < 0:
				ok = false
				break
			var a: Transform3D = ysk.get_bone_rest(i)
			var b: Transform3D = sk.get_bone_rest(j)
			worst_rot = maxf(worst_rot, rad_to_deg(a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion())))
			worst_pos = maxf(worst_pos, (a.origin - b.origin).length())
		if ok:
			same += 1
	print("CHECK reposo: clips=%d mismos huesos que ybot_tpose=%d | peor giro=%.3f grados, peor desplazamiento=%.4f m" % [files.size(), same, worst_rot, worst_pos])

func _check_coverage(files: Array[String]) -> void:
	var tsk: Skeleton3D = _skel_of((load("res://assets/characters/player/player_base.glb") as PackedScene).instantiate())
	var need: Array[String] = []
	for i in tsk.get_bone_count():
		if tsk.get_bone_name(i) != "Root":
			need.append(tsk.get_bone_name(i))
	var incomplete := 0
	for f in files:
		var a: Animation = _anim(f)
		var have := {}
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				var p: String = str(a.track_get_path(t))
				have[p.substr(p.find(":") + 1)] = true
		var miss: Array[String] = []
		for n in need:
			if not have.has(n):
				miss.append(n.replace("mixamorig_", ""))
		if miss.size() > 0:
			incomplete += 1
			print("CHECK cobertura: %s sin pista de rotacion para: %s" % [f.get_file(), ", ".join(miss)])
	print("CHECK cobertura: clips=%d, huesos de Tripo con equivalente=%d, clips incompletos=%d" % [files.size(), need.size(), incomplete])

func _check_twins(files: Array[String]) -> void:
	var pairs := 0
	var worst := 0.0
	for f in files:
		if f.ends_with("_inplace.fbx"):
			continue
		var twin: String = f.replace(".fbx", "_inplace.fbx")
		if not FileAccess.file_exists(twin):
			continue
		pairs += 1
		var a: Animation = _anim(f)
		var b: Animation = _anim(twin)
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var j: int = b.find_track(a.track_get_path(t), Animation.TYPE_ROTATION_3D)
			if j < 0:
				worst = 999.0
				continue
			for k in range(0, a.track_get_key_count(t), 3):
				var time: float = a.track_get_key_time(t, k)
				worst = maxf(worst, rad_to_deg((a.rotation_track_interpolate(t, time) as Quaternion).angle_to(b.rotation_track_interpolate(j, time))))
	print("CHECK gemelos in place: pares=%d, peor diferencia de rotacion=%.3f grados" % [pairs, worst])
