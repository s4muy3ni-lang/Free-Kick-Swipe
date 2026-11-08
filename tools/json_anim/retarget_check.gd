extends SceneTree
## Comprobacion del retarget JSON: para clips elegidos mide, en cada fotograma, cuanto se aleja del dato cada articulacion
## tras resolver los marcos y volver a calcular las posiciones por cinematica directa.
## Uso: JSON_SRC=<dir> godot --headless --path . --script res://tools/json_anim/retarget_check.gd -- <clip1> <clip2>...

const JOINTS := ["pelvis", "chest", "head", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist", "l_knee", "r_knee", "l_ankle", "r_ankle", "l_toe", "r_toe"]

func _init() -> void:
	var src: String = OS.get_environment("JSON_SRC")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var rt := JsonRetarget.new(JsonRig.Pose.A)
	var rt_t := JsonRetarget.new(JsonRig.Pose.T)
	print("Marcos de reposo A y T calculados: ", rt.rest_fr.size(), " / ", rt_t.rest_fr.size())
	for a in args:
		var files: PackedStringArray = DirAccess.get_files_at(src)
		var path := ""
		for f in files:
			if f.begins_with(a):
				path = src.path_join(f)
				break
		if path == "":
			print("no hay clip ", a)
			continue
		for mirror in [false, true]:
			var c: JsonClipData = JsonClipData.load_file(path, mirror)
			var err_sum := {}
			var err_max := {}
			var n := 0
			for k in range(0, c.frames + 1, 2):
				var j: Dictionary = c.sample(float(k))
				var res: Dictionary = rt.solve(j)
				var pos: Dictionary = res["pos"]
				n += 1
				for jn in JOINTS:
					var bone: String = JsonRig.bone_of(jn)
					var got: Vector3 = pos[bone]
					if jn == "head":
						got += (res["frames"]["mixamorig_Head"] as Basis).y * JsonRig.HEAD_POINT_UP
					var d: float = got.distance_to(j[jn])
					err_sum[jn] = float(err_sum.get(jn, 0.0)) + d
					err_max[jn] = maxf(float(err_max.get(jn, 0.0)), d)
			var line := "%s%s:" % [c.source.left(34), " (espejo)" if mirror else ""]
			for jn in ["head", "chest", "l_wrist", "r_wrist", "l_ankle", "r_ankle", "l_toe", "r_toe", "l_knee", "r_elbow"]:
				line += " %s=%.1f/%.1fcm" % [jn, float(err_sum[jn]) / n * 100.0, float(err_max[jn]) * 100.0]
			print(line)
	quit()
