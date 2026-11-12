extends TestCase
## Numero de la espalda (pedido del usuario 2026-11-12: «el numero de la camiseta esta separado de la camiseta»). Con el
## cuerpo de Tripo va IMPRESO en la tela: la malla trae la posicion de reposo (CUSTOM0) y el shader del uniforme proyecta
## las cifras sobre la espalda, asi que se mueve con ella. Con el humanoide sigue el Label3D, pero acompaña la inclinacion
## del torso pegado a la espalda medida en la malla.

func _actor(kit: Dictionary) -> SpActor:
	var a := SpActor.new()
	a.role = &"shooter"
	spawn(a)
	a.build(kit)
	return a

func test_tripo_mesh_carries_the_rest_position() -> void:
	var sc: Node3D = (load(AnimBankCatalog.PRINTED_NUMBER_BODY) as PackedScene).instantiate()
	spawn(sc)
	var mi: MeshInstance3D = sc.find_children("*", "MeshInstance3D", true, false)[0]
	var am: ArrayMesh = mi.mesh
	var fmt: int = am.surface_get_format(0)
	check(fmt & Mesh.ARRAY_FORMAT_CUSTOM0 != 0, "la malla del cuerpo de Tripo trae CUSTOM0")
	var arr: Array = am.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var c: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
	var worst: float = 0.0
	for k in range(0, v.size(), 37):
		worst = maxf(worst, v[k].distance_to(Vector3(c[k * 4], c[k * 4 + 1], c[k * 4 + 2])))
	note("vertices: %d, diferencia maxima reposo/CUSTOM0: %.6f" % [v.size(), worst])
	check(c.size() == v.size() * 4 and worst < 1e-4, "CUSTOM0 es la posicion de reposo de cada vertice")
	check(mi.skin != null, "y sigue con su piel (se anima igual)")
	cleanup()

func test_number_is_printed_on_the_tripo_shirt() -> void:
	if not AnimBank.is_tripo_body():
		skip("el cuerpo elegido no es el de Tripo")
		return
	var a := _actor({"jersey": Color(0.75, 0.05, 0.08)})
	a.set_back_number(10)
	await physics_frames(2)
	check(a.printed_number(), "con el cuerpo de Tripo el numero va impreso")
	var mat: ShaderMaterial = a.kit_material()
	check(int(mat.get_shader_parameter("back_number")) == 10, "el uniforme lleva el 10")
	check(bool(mat.get_shader_parameter("rest_space")) and mat.get_shader_parameter("number_atlas") != null, "con la hoja de cifras y la posicion de reposo")
	check(a.find_children("*", "Label3D", true, false).is_empty(), "sin cartel flotante")
	check((mat.get_shader_parameter("number_color") as Color).get_luminance() > 0.8, "cifras blancas sobre una camiseta oscura")
	# Cambiar el uniforme (Personalizar) no borra el numero; sobre una camiseta clara, cifras oscuras.
	a.set_kit({"jersey": Color(0.95, 0.95, 0.95)})
	mat = a.kit_material()
	check(int(mat.get_shader_parameter("back_number")) == 10, "el numero sigue al cambiar el uniforme")
	check((mat.get_shader_parameter("number_color") as Color).get_luminance() < 0.2, "cifras oscuras sobre una camiseta clara")
	a.set_back_number(0)
	check(int(a.kit_material().get_shader_parameter("back_number")) == 0, "0 lo quita")
	cleanup()

func test_humanoid_label_sticks_to_the_leaning_back() -> void:
	var prev: int = AnimBank.body()
	AnimBank.set_body(AnimBank.Body.HUMANO, false)
	var a := _actor({})
	a.set_back_number(7)
	await physics_frames(3)
	check(not a.printed_number(), "el humanoide usa el cartel")
	var labels: Array = a.find_children("*", "Label3D", true, false)
	check(labels.size() == 1, "un cartel con el numero")
	var runs: Array = SpClips.by_role(&"run", false)
	if not runs.is_empty():
		a.play_loop(runs[0], 0.0)
	var worst: float = 0.0
	for i in 40:
		await tree.physics_frame
		var l: Label3D = labels[0]
		var s1: Vector3 = a.bone_world("mixamorig_Spine1")
		var s2: Vector3 = a.bone_world("mixamorig_Spine2")
		var mid: Vector3 = (s1 + s2) * 0.5
		# El cartel queda detras del torso, a la distancia de la espalda medida (no flota).
		worst = maxf(worst, absf(l.global_position.distance_to(mid) - a._back_depth))
		# Y su vertical sigue la columna (se inclina con el torso).
		var up: Vector3 = (s2 - a.bone_world("mixamorig_Spine")).normalized()
		worst = maxf(worst, (1.0 - l.global_transform.basis.y.normalized().dot(up)) * 0.1)
	note("espalda medida: %.3f m; desvio maximo corriendo: %.4f" % [a._back_depth, worst])
	check(a._back_depth > 0.08 and a._back_depth < 0.25, "la espalda medida es razonable")
	check(worst < 0.01, "el numero acompaña la espalda al correr")
	AnimBank.set_body(prev, false)
	cleanup()
