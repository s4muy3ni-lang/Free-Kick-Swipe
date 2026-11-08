extends Node
## Genera (en OUT) librerias retargeteadas de prueba para medir su tamano; NO escribe en assets/.
## Env: OUT=dir CORE=clip1,clip2 (nombres sin extension)
func _collect(dir: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + d, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".fbx"):
			out.append(dir + "/" + f)

func _convert(rt: PackRetarget, src: Animation, tsk: Skeleton3D, optimize: bool) -> Animation:
	var out := Animation.new()
	out.length = src.length
	out.step = 1.0 / 30.0
	var bind: Dictionary = rt.bind(src)
	var tracks := {}
	for i in tsk.get_bone_count():
		var tr: int = out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, NodePath("Skeleton3D:" + tsk.get_bone_name(i)))
		tracks[i] = tr
	var hp: int = out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hp, NodePath("Skeleton3D:mixamorig_Hips"))
	var n: int = maxi(int(round(src.length * 30.0)), 1)
	for k in n + 1:
		var t: float = minf(src.length * float(k) / n, src.length)
		rt.pose(bind, t, true)
		for i in tsk.get_bone_count():
			out.rotation_track_insert_key(tracks[i], t, tsk.get_bone_pose_rotation(i))
		out.position_track_insert_key(hp, t, tsk.get_bone_pose_position(rt.t_hips))
	if optimize:
		out.optimize(0.02, 0.01, 3)
	return out

func _ready() -> void:
	var vis := FootballerVisual.new()
	add_child(vis)
	vis.build(FootballerVisual.default_kit(0))
	var tsk: Skeleton3D = vis.skeleton
	var ysk: Skeleton3D = ((load("res://pack/personaje/ybot_tpose.fbx") as PackedScene).instantiate()).find_children("*", "Skeleton3D", true, false)[0]
	var rt := PackRetarget.new()
	rt.setup(ysk, tsk)
	var files: Array[String] = []
	_collect("res://pack/animaciones", files)
	files.sort()
	var core_names: PackedStringArray = OS.get_environment("CORE").split(",")
	var all_lib := AnimationLibrary.new()
	var all_opt := AnimationLibrary.new()
	var core_lib := AnimationLibrary.new()
	var core_opt := AnimationLibrary.new()
	var total_len := 0.0
	var core_len := 0.0
	var n_core := 0
	for f in files:
		var inst: Node = (load(f) as PackedScene).instantiate()
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var anim: Animation
		for nm in ap.get_animation_list():
			if nm != "RESET":
				anim = ap.get_animation(nm)
		var id: String = f.get_file().get_basename()
		var a1: Animation = _convert(rt, anim, tsk, false)
		var a2: Animation = _convert(rt, anim, tsk, true)
		all_lib.add_animation(id, a1)
		all_opt.add_animation(id, a2)
		total_len += anim.length
		if core_names.has(id):
			core_lib.add_animation(id, a1.duplicate())
			core_opt.add_animation(id, a2.duplicate())
			core_len += anim.length
			n_core += 1
		inst.free()
	var dir: String = OS.get_environment("OUT")
	ResourceSaver.save(all_lib, dir + "/all_raw.res")
	ResourceSaver.save(all_opt, dir + "/all_opt.res")
	ResourceSaver.save(core_lib, dir + "/core_raw.res")
	ResourceSaver.save(core_opt, dir + "/core_opt.res")
	print("LIB todos=%d clips (%.0f s de animacion) | nucleo=%d clips (%.0f s)" % [files.size(), total_len, n_core, core_len])
	get_tree().quit()
