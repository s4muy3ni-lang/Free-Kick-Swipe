extends SceneTree
## Inspecciona un modelo importado: arbol de nodos, huesos, animaciones y triangulos reales.
## Uso: godot --headless --path . -s tools/inspect_model.gd -- res://ruta/modelo.glb

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://assets/characters/player/player_base.glb"
	var scene: PackedScene = load(path)
	if scene == null:
		printerr("No se pudo cargar ", path)
		quit(1)
		return
	var root: Node = scene.instantiate()
	print("== ", path)
	_dump(root, 0)
	var tris: int = 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arrays: Array = m.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	print("TRIANGULOS (Godot): ", tris)
	for sk in root.find_children("*", "Skeleton3D", true, false):
		var s3: Skeleton3D = sk
		print("Skeleton3D '", s3.name, "' huesos=", s3.get_bone_count())
		var names: PackedStringArray = []
		for i in min(s3.get_bone_count(), 12):
			names.append(s3.get_bone_name(i))
		print("  primeros huesos: ", names)
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		var a: AnimationPlayer = ap
		print("AnimationPlayer '", a.name, "' root_node=", a.root_node)
		for lib in a.get_animation_library_list():
			for an in a.get_animation_library(lib).get_animation_list():
				var anim: Animation = a.get_animation_library(lib).get_animation(an)
				print("  anim '", lib, "/", an, "' len=%.3f s tracks=%d loop=%d" % [anim.length, anim.get_track_count(), anim.loop_mode])
				if anim.get_track_count() > 0:
					print("     ejemplo de pista: ", anim.track_get_path(0), " tipo=", anim.track_get_type(0))
	root.free()
	quit()

func _dump(n: Node, depth: int) -> void:
	var extra: String = ""
	if n is Node3D:
		extra = " pos=%s rot=%s scale=%s" % [(n as Node3D).position, (n as Node3D).rotation_degrees, (n as Node3D).scale]
	print("  ".repeat(depth), n.name, " [", n.get_class(), "]", extra)
	if n is Skeleton3D:
		return
	for c in n.get_children():
		_dump(c, depth + 1)
