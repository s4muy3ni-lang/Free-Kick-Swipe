extends Node
## Cuerpo del JUGADOR con el modelo de Tripo (assets/characters/player/player_base.glb, hecho por el usuario con Tripo3D):
## pedido del usuario 2026-11-12 («el GLB del jugador debería estar en el juego»). Antes se habia descartado porque se
## deformaba con las animaciones: sus piernas y brazos estan RECTOS en reposo (pose T), asi que el eje de la rodilla y del
## codo quedaba indefinido y los miembros se torcian al animar.
##
## Que hace (sin tocar el GLB): toma su esqueleto (los mismos 23 huesos mixamorig_*), calcula para cada hueso el MARCO de
## reposo con la misma funcion que usan las animaciones (JsonRetarget.frames_from_geometry, como el humano JSON) pero con
## los polos bien definidos (rodilla hacia adelante; codo como el del brazo en pose A girado hasta la cruz), deja cada hueso
## en reposo con ese marco y recalcula el «bind» de la piel para que la malla quede igual en reposo. Asi las mismas
## bibliotecas (ACTUAL y MIXAMO) mueven este cuerpo. Raiz en el origen y sin giro: la pista de la cadera es la del modelo.
## La malla lleva ademas la posicion de reposo en CUSTOM0 (numero impreso en la espalda y diseños pegados a la tela).
## Salida: assets/characters/json/tripo_body.scn. Uso: godot --headless --path . res://tools/json_anim/build_tripo_body.tscn

const SRC := "res://assets/characters/player/player_base.glb"
const OUT := "res://assets/characters/json/tripo_body.scn"

func _ready() -> void:
	var scene: Node3D = (load(SRC) as PackedScene).instantiate()
	add_child(scene)
	var sk: Skeleton3D = scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi: MeshInstance3D = sk.find_children("*", "MeshInstance3D", false, false)[0]
	var n: int = sk.get_bone_count()
	var old_g := {}
	var pos_m := {}
	for i in n:
		old_g[i] = sk.get_bone_global_rest(i)
		pos_m[sk.get_bone_name(i)] = (old_g[i] as Transform3D).origin / JsonRig.UNIT
	# Polos de los brazos en cruz: el del brazo en pose A del esqueleto del juego, girado hasta la direccion del brazo.
	var poles := {}
	var pa: Dictionary = JsonRig.rest_positions(JsonRig.Pose.A)
	for side in ["Left", "Right"]:
		var s: Vector3 = pa["mixamorig_%sArm" % side]
		var e: Vector3 = pa["mixamorig_%sForeArm" % side]
		var w: Vector3 = pa["mixamorig_%sHand" % side]
		var u_a: Vector3 = (w - s).normalized()
		var p_a: Vector3 = (e - s) - u_a * (e - s).dot(u_a)
		var t_dir: Vector3 = ((pos_m["mixamorig_%sForeArm" % side] as Vector3) - (pos_m["mixamorig_%sArm" % side] as Vector3)).normalized()
		poles["arm_" + side] = (Quaternion((e - s).normalized(), t_dir) * p_a).normalized()
	var g: Dictionary = JsonRetarget._geometry_from_positions(pos_m, poles)
	g["head_dir"] = ((pos_m["mixamorig_Head"] as Vector3) + Vector3.UP * JsonRig.HEAD_POINT_UP) - (pos_m["mixamorig_Spine2"] as Vector3)
	# Rodillas: con la pierna recta el polo no existe; adelante del cuerpo (la misma convencion que el reposo del juego).
	var fwd: Vector3 = Vector3.UP.cross((g["pelvis_lat"] as Vector3).normalized()).normalized()
	for side in ["Left", "Right"]:
		var limb: Dictionary = g["limbs"]["leg_" + side]
		var u: Vector3 = limb["u"]
		var p: Vector3 = limb["p"]
		if p.length() < 0.5 or p.dot(fwd) < 0.3:
			p = (fwd - u * fwd.dot(u)).normalized()
			limb["p"] = p
		g["leg_h_" + side] = u.cross(p).normalized()
	var fr: Dictionary = JsonRetarget.frames_from_geometry(g)
	# Reposo nuevo (global): el marco de cada hueso en su mismo lugar; la raiz en el origen sin giro.
	var new_g := {}
	for i in n:
		var name: String = sk.get_bone_name(i)
		if name == "Root":
			new_g[i] = Transform3D.IDENTITY
		else:
			new_g[i] = Transform3D(fr[name] as Basis, (old_g[i] as Transform3D).origin)
	for i in n:
		var par: int = sk.get_bone_parent(i)
		var local: Transform3D = new_g[i] if par < 0 else (new_g[par] as Transform3D).affine_inverse() * (new_g[i] as Transform3D)
		sk.set_bone_rest(i, local)
	sk.reset_bone_poses()
	# Piel: el bind nuevo deja la malla exactamente donde estaba en reposo.
	var skin: Skin = mi.skin.duplicate(true) as Skin
	for b in skin.get_bind_count():
		var bi: int = skin.get_bind_bone(b)
		if bi < 0:
			bi = sk.find_bone(String(skin.get_bind_name(b)))
		skin.set_bind_pose(b, (new_g[bi] as Transform3D).affine_inverse() * (old_g[bi] as Transform3D) * skin.get_bind_pose(b))
	mi.skin = skin
	# Posicion de REPOSO de cada vertice en CUSTOM0 (xyz) y la X de su normal (w): el shader del uniforme imprime ahi el
	# numero de la espalda y apoya los diseños, asi quedan pegados a la tela cuando el cuerpo se mueve (pedido 2026-11-12:
	# «el numero de la camiseta esta separado de la camiseta»). La malla se rearma igual, con ese canal de mas.
	var am: ArrayMesh = mi.mesh as ArrayMesh
	var nm := ArrayMesh.new()
	for si in am.get_surface_count():
		var arr: Array = am.surface_get_arrays(si)
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var rest := PackedFloat32Array()
		rest.resize(vv.size() * 4)
		for k in vv.size():
			rest[k * 4] = vv[k].x
			rest[k * 4 + 1] = vv[k].y
			rest[k * 4 + 2] = vv[k].z
			rest[k * 4 + 3] = nn[k].x if k < nn.size() else 0.0
		arr[Mesh.ARRAY_CUSTOM0] = rest
		nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		nm.surface_set_material(si, am.surface_get_material(si))
		nm.surface_set_name(si, am.surface_get_name(si))
	mi.mesh = nm
	mi.name = "TripoBodyMesh"
	scene.name = "TripoBody"
	for c in scene.find_children("*", "", true, false):
		c.owner = scene
	var ps := PackedScene.new()
	var err: int = ps.pack(scene)
	err = maxi(err, ResourceSaver.save(ps, OUT))
	print("CUERPO TRIPO guardado: %s (error=%d), %d huesos, pierna izq. polo %s" % [OUT, err, n, str(g["limbs"]["leg_Left"]["p"])])
	get_tree().quit()
