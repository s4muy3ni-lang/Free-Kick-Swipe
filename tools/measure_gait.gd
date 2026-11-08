extends SceneTree
## Mide la velocidad natural de un ciclo de marcha: velocidad del pie de apoyo respecto a la cadera
## (sentido de avance del modelo = +X en el GLB de Tripo). Resultado en metros/segundo reales.
## Uso: godot --headless --path . -s tools/measure_gait.gd -- res://ruta.glb 1.75

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = args[0]
	var height_scale: float = float(args[1]) if args.size() > 1 else 1.75
	var root: Node = (load(path) as PackedScene).instantiate()
	get_root().add_child(root)
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	var foot_l: int = sk.find_bone("mixamorig_LeftFoot")
	var foot_r: int = sk.find_bone("mixamorig_RightFoot")
	var hips: int = sk.find_bone("mixamorig_Hips")
	for an in ["walk", "run", "idle"]:
		if not ap.has_animation(an):
			continue
		var anim: Animation = ap.get_animation(an)
		var bind_map: Dictionary = PoseSampler.bind(anim, sk)
		var n: int = 120 if an != "idle" else 60
		var dt: float = anim.length / n
		var series_l: Array[float] = []
		var hip_y: Array[float] = []
		for i in n + 1:
			PoseSampler.apply(anim, sk, bind_map, dt * i)
			var hp: Transform3D = PoseSampler.bone_in_skeleton(sk, hips)
			var fl: Transform3D = PoseSampler.bone_in_skeleton(sk, foot_l)
			series_l.append((fl.origin - hp.origin).x)
			hip_y.append(hp.origin.y)
		# Fase de apoyo: tramo donde el pie retrocede respecto a la cadera (pendiente negativa maxima sostenida).
		var slopes: Array[float] = []
		for i in n:
			slopes.append((series_l[i + 1] - series_l[i]) / dt)
		var neg: Array[float] = []
		for s in slopes:
			if s < -0.05:
				neg.append(-s)
		var avg_stance: float = 0.0
		for v in neg:
			avg_stance += v
		avg_stance = avg_stance / maxf(neg.size(), 1)
		var rng_x: float = series_l.max() - series_l.min()
		print("%s: duracion=%.3f s, recorrido relativo del pie=%.3f m(modelo) -> velocidad natural ~ %.2f m/s reales (apoyo %.0f %% del ciclo); altura cadera %.3f..%.3f" % [an, anim.length, rng_x, avg_stance * height_scale, 100.0 * neg.size() / n, hip_y.min() * height_scale, hip_y.max() * height_scale])
	quit()
