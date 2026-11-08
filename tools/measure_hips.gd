extends SceneTree
## Mide el desplazamiento horizontal de la cadera de cada clip respecto a la pose de reposo
## y la velocidad natural de los ciclos de marcha. Uso:
##   godot --headless --path . -s tools/measure_hips.gd -- res://scratch/modelo.glb [escala=1.75]
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scale_h: float = float(args[1]) if args.size() > 1 else 1.75
	var root: Node = (load(args[0]) as PackedScene).instantiate()
	get_root().add_child(root)
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	var hips: int = sk.find_bone("mixamorig_Hips")
	var foot_l: int = sk.find_bone("mixamorig_LeftFoot")
	var rest: Vector3 = sk.get_bone_rest(hips).origin
	print("huesos=%d reposo cadera=%s" % [sk.get_bone_count(), rest])
	for an in ap.get_animation_list():
		var anim: Animation = ap.get_animation(an)
		var tr: int = -1
		var kinds: Dictionary = {}
		for t in anim.get_track_count():
			kinds[anim.track_get_type(t)] = kinds.get(anim.track_get_type(t), 0) + 1
			if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(t)).ends_with("mixamorig_Hips"):
				tr = t
		var line: String = "%s: %.2f s, pistas=%s" % [an, anim.length, kinds]
		if tr >= 0:
			var sum := Vector3.ZERO
			var n: int = 60
			for i in n:
				sum += anim.position_track_interpolate(tr, anim.length * i / n)
			var mean: Vector3 = sum / n
			line += " | cadera media-reposo=(%.3f, %.3f, %.3f)" % [mean.x - rest.x, mean.y - rest.y, mean.z - rest.z]
		if an in ["walk", "run"]:
			var bm: Dictionary = PoseSampler.bind(anim, sk)
			var n2: int = 120
			var dt: float = anim.length / n2
			var xs: Array[float] = []
			for i in n2 + 1:
				PoseSampler.apply(anim, sk, bm, dt * i)
				xs.append((PoseSampler.bone_in_skeleton(sk, foot_l).origin - PoseSampler.bone_in_skeleton(sk, hips).origin).x)
			var neg: Array[float] = []
			for i in n2:
				var sl: float = (xs[i + 1] - xs[i]) / dt
				if sl < -0.05:
					neg.append(-sl)
			var avg: float = 0.0
			for v in neg:
				avg += v
			avg /= maxf(neg.size(), 1)
			line += " | velocidad natural ~%.2f m/s" % (avg * scale_h)
		print(line)
	quit()
