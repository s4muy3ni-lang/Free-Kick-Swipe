extends TestCase
## Numero de la espalda (pedido del usuario 2026-11-12: «el numero de la camiseta esta separado de la camiseta»). Con el
## cuerpo de Tripo va IMPRESO en la tela: la malla trae la posicion de reposo (CUSTOM0) y el shader del uniforme proyecta
## las cifras sobre la espalda, asi que se mueve con ella. El humanoide JSON (que llevaba un Label3D) se elimino del juego
## y de los archivos el mismo dia (pedido del usuario: «el humanoide no va mas, queda el jugador 3D»).

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

func test_the_humanoid_is_gone() -> void:
	check(AnimBank.body_path() == AnimBankCatalog.PRINTED_NUMBER_BODY, "el cuerpo del juego es el modelo de Tripo")
	check(JsonCatalog.HUMAN_SCENE == AnimBank.BODY_PATH and AnimBankCatalog.COMMON_BODY == AnimBank.BODY_PATH, "el modo Json y la comparacion tambien")
	for f in ["res://assets/characters/json/json_human.scn", "res://assets/characters/json/json_kit.gdshader", "res://tools/json_anim/build_json_human.gd"]:
		check(not FileAccess.file_exists(f), "%s ya no esta en los archivos" % f)
	var a := _actor({})
	a.set_back_number(9)
	await physics_frames(2)
	check(a.find_children("*", "Label3D", true, false).is_empty(), "ningun numero flotante: va impreso")
	cleanup()
