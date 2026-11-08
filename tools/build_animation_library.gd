extends SceneTree
## Construye res://assets/animations/footballer_clips.res a partir de los GLB de Tripo (assets/animations/source).
## Cada clip es un preset de Tripo retargeteado sobre nuestro rig; aqui se renombra por funcion, se centra la
## cadera sobre el reposo (los clips traen desfases de hasta ~0.9 m), se fijan bucles y se guarda la libreria.
## Uso: godot --headless --path . -s tools/build_animation_library.gd

const OUT_PATH := "res://assets/animations/footballer_clips.res"
const SOURCES := [
	{"glb": "res://assets/animations/source/v1_keeper.glb",
	 "clips": {"idle": "idle", "walk": "walk", "dive": "dive", "jump": "jump", "fall": "fall"}},
	{"glb": "res://assets/animations/source/v1_football.glb",
	 "clips": {"football_catch": "keeper_catch_high", "football_save": "keeper_scoop_low", "football_pass": "defensive_stance"}},
	{"glb": "res://assets/animations/source/v1_more.glb",
	 "clips": {"run": "run", "turn": "turn", "victory_celebration": "celebrate_goal", "defeat_02": "dejected", "frustrated_01": "frustrated"}},
]
const LOOPING := ["idle", "walk", "run", "defensive_stance"]
## En el esqueleto v1.0 el eje Z local de la cadera es "arriba"; X e Y son horizontales.
const HIPS_BONE := "mixamorig_Hips"
const HORIZONTAL_AXES := [0, 1]

func _initialize() -> void:
	var library := AnimationLibrary.new()
	var report: Array[String] = []
	for src in SOURCES:
		var scene: PackedScene = load(src["glb"])
		var root: Node = scene.instantiate()
		var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		var hips: int = sk.find_bone(HIPS_BONE)
		var rest: Vector3 = sk.get_bone_rest(hips).origin
		for source_name in src["clips"].keys():
			var out_name: String = src["clips"][source_name]
			var anim: Animation = (ap.get_animation(source_name) as Animation).duplicate(true)
			var shift: Vector2 = _center_hips(anim, rest)
			anim.loop_mode = Animation.LOOP_LINEAR if out_name in LOOPING else Animation.LOOP_NONE
			library.add_animation(out_name, anim)
			report.append("%-18s <- %-22s %6.2f s  %s  desfase corregido=(%.2f, %.2f)" % [out_name, source_name, anim.length, "bucle" if out_name in LOOPING else "unico", shift.x, shift.y])
		root.free()
	var err: int = ResourceSaver.save(library, OUT_PATH)
	for line in report:
		print(line)
	print("Guardado %s (error=%d), %d clips" % [OUT_PATH, err, library.get_animation_list().size()])
	quit(0 if err == OK else 1)

## Resta la media del desplazamiento horizontal de la cadera respecto al reposo. Devuelve el desfase corregido.
func _center_hips(anim: Animation, rest: Vector3) -> Vector2:
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D or not str(anim.track_get_path(t)).ends_with(HIPS_BONE):
			continue
		var n: int = anim.track_get_key_count(t)
		var mean := Vector3.ZERO
		for k in n:
			mean += anim.track_get_key_value(t, k)
		mean /= maxf(n, 1)
		var dx: float = rest[HORIZONTAL_AXES[0]] - mean[HORIZONTAL_AXES[0]]
		var dy: float = rest[HORIZONTAL_AXES[1]] - mean[HORIZONTAL_AXES[1]]
		for k in n:
			var v: Vector3 = anim.track_get_key_value(t, k)
			v[HORIZONTAL_AXES[0]] += dx
			v[HORIZONTAL_AXES[1]] += dy
			anim.track_set_key_value(t, k, v)
		return Vector2(-dx, -dy)
	return Vector2.ZERO
