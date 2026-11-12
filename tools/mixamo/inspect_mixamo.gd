extends Node
## Inventario de los GLB de Mixamo (assets/animations/source/mixamo/, copia de animaciones_mixamo.zip): por animacion,
## nombre, duracion, pistas (huesos y tipos), si la raiz se desplaza; y el esqueleto (huesos, padres, reposo, transformada
## del Armature). Salida: MIXAMO_OUT (json) + resumen por consola.
## Uso: MIXAMO_OUT=/tmp/mixamo_inv.json godot --headless --path . res://tools/mixamo/inspect_mixamo.tscn

const FILES := {"campo": "res://assets/animations/source/mixamo/mixamo_campo.glb", "arquero": "res://assets/animations/source/mixamo/mixamo_arquero.glb"}

func _ready() -> void:
	var out := {}
	for k in FILES:
		var scene: Node = (load(FILES[k]) as PackedScene).instantiate()
		add_child(scene)
		var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var bones := []
		for i in sk.get_bone_count():
			var r: Transform3D = sk.get_bone_rest(i)
			bones.append({"name": sk.get_bone_name(i), "parent": sk.get_bone_parent(i), "rest_origin": [r.origin.x, r.origin.y, r.origin.z]})
		var chain: Transform3D = Transform3D.IDENTITY
		var n: Node = sk
		while n != scene and n is Node3D:
			chain = (n as Node3D).transform * chain
			n = n.get_parent()
		var anims := []
		for lib_name in ap.get_animation_library_list():
			var lib: AnimationLibrary = ap.get_animation_library(lib_name)
			for an in lib.get_animation_list():
				var a: Animation = lib.get_animation(an)
				var tracks := {}
				var root_move := 0.0
				for t in a.get_track_count():
					var p: String = String(a.track_get_path(t))
					tracks[p.get_slice(":", 1) + "/" + str(a.track_get_type(t))] = a.track_get_key_count(t)
					if p.ends_with(":Root") and a.track_get_type(t) == Animation.TYPE_POSITION_3D and a.track_get_key_count(t) > 1:
						root_move = (a.track_get_key_value(t, a.track_get_key_count(t) - 1) - a.track_get_key_value(t, 0)).length()
				anims.append({"name": an, "length": a.length, "loop": a.loop_mode, "tracks": tracks.size(), "root_move": root_move,
					"track_names": tracks.keys()})
		out[k] = {"skeleton_path": String(scene.get_path_to(sk)), "anim_player": String(scene.get_path_to(ap)), "skeleton_to_scene": [chain.basis.x, chain.basis.y, chain.basis.z, chain.origin].map(func(v: Vector3) -> Array: return [v.x, v.y, v.z]), "bones": bones, "animations": anims}
		print("%s: %d huesos, %d animaciones, esqueleto %s" % [k, bones.size(), anims.size(), out[k]["skeleton_path"]])
		scene.queue_free()
	var f := FileAccess.open(OS.get_environment("MIXAMO_OUT") if OS.get_environment("MIXAMO_OUT") != "" else "/tmp/mixamo_inv.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	get_tree().quit()
