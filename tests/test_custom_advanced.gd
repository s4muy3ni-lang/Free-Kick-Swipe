extends TestCase
## Personalizacion avanzada (pedido del usuario: «peinados, barbas, bigotes, altura y complexion dentro de limites… sin
## romper las animaciones… botines con color secundario, suela y cordones… numero y nombre aplicados en la camiseta y
## validados… desbloqueos por nivel, logros y monedas… progreso sin conexion y sincronizacion sin duplicar»).

const DIR := "user://test_custom_advanced"

func _online() -> Node:
	var o: Node = tree.root.get_node("Online")
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/" + f))
	o.use_local(DIR)
	await o.sign_up("estilo@futbol.com", "golazo123")
	await o.call_state_fn("create_profile", {"p_username": "Estilo", "p_display_name": "Estilo"})
	return o

func _actor() -> SpActor:
	var a := SpActor.new()
	spawn(a)
	a.build(PlayerCustom.kit())
	return a

func test_shirt_name_is_printed_and_validated() -> void:
	check(ShirtName.glyphs("Lío 10") == PackedInt32Array([11, 29, 14, -1, 34, 33]), "letras de la hoja (con acento y espacio)")
	var a := _actor()
	a.set_back_number(10)
	a.set_shirt_name("Messi")
	var m: ShaderMaterial = a.kit_material()
	check(int(m.get_shader_parameter("name_len")) == 5, "nombre de 5 letras en la camiseta")
	check((m.get_shader_parameter("name_glyphs") as PackedInt32Array).size() == ShirtName.MAX, "12 casillas para el shader")
	check(m.get_shader_parameter("name_atlas") is Texture2D, "con la hoja de letras")
	a.set_kit(PlayerCustom.kit())
	check(int(a.kit_material().get_shader_parameter("name_len")) == 5, "cambiar el uniforme no borra el nombre")
	a.set_shirt_name("idiota")
	check(a.shirt_name == "" and int(a.kit_material().get_shader_parameter("name_len")) == 0, "un nombre ofensivo no se imprime")
	a.set_shirt_name("Juan<script>")
	check(a.shirt_name == "", "caracteres raros tampoco")
	cleanup()

func test_haircuts_and_beards_follow_the_head_without_touching_the_skeleton() -> void:
	var a := _actor()
	var bones: int = a.skeleton.get_bone_count()
	var idles: Array[StringName] = SpClips.by_role(&"idle_ready", false)
	a.play_loop(idles[0], 0.0)
	var head: int = a.skeleton.find_bone("mixamorig_Head")
	for cut in HairCatalog.HAIRCUTS:
		for bd in ["beard_none", "beard_vikinga"]:
			a.set_look(cut, bd, PlayerCustom.HAIRS[1])
			await physics_frames(3)
			var want: int = (HairCatalog.haircut(cut)["parts"] as Array).size() + (HairCatalog.beard(bd)["parts"] as Array).size()
			var meshes: Array = a.skeleton.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool:
				return n.get_parent() is BoneAttachment3D and String((n.get_parent() as BoneAttachment3D).name).contains("Look") and not n.is_queued_for_deletion())
			check(meshes.size() == want, "%s + %s: %d piezas" % [cut, bd, want])
			var hp: Vector3 = (a.skeleton.global_transform * a.skeleton.get_bone_global_pose(head)).origin
			var far: float = 0.0
			for mi in meshes:
				far = maxf(far, (mi as Node3D).global_position.distance_to(hp))
			check(far < 0.4, "%s + %s: pegado a la cabeza (%.2f m)" % [cut, bd, far])
	check(a.skeleton.get_bone_count() == bones, "el esqueleto no cambia")
	a.set_look("hair_rapado", "beard_none", PlayerCustom.HAIRS[0])
	check(float(a.kit_material().get_shader_parameter("hair_buzz")) > 0.5, "rapado: el pelo de la textura se mezcla con la piel")
	a.set_look("hair_natural", "beard_none", PlayerCustom.HAIRS[0])
	await physics_frames(2)
	check(float(a.kit_material().get_shader_parameter("hair_buzz")) == 0.0, "natural: el pelo de siempre")
	check(String(a.anim_player.current_animation) != "", "la animacion sigue")
	cleanup()

func test_height_and_build_stay_within_limits_and_never_touch_the_keeper() -> void:
	var a := _actor()
	for h in HairCatalog.HEIGHTS.size():
		for b in HairCatalog.BUILDS.size():
			a.set_body_shape(h, b)
			var sc: Vector3 = a.model.scale / SpActor.BODY_SCALE
			check(sc.y >= 0.97 - 1e-4 and sc.y <= 1.03 + 1e-4 and sc.x >= 0.94 - 1e-4 and sc.x <= 1.08 + 1e-4 and is_equal_approx(sc.x, sc.z),
				"altura %d, complexion %d: escala %s dentro de los limites" % [h, b, str(sc)])
	a.set_body_shape(99, -5)
	check(is_equal_approx(a.model.scale.y / SpActor.BODY_SCALE, 1.03) and is_equal_approx(a.model.scale.x / SpActor.BODY_SCALE, 0.94), "valores fuera de rango se acotan")
	PlayerCustom.use_path("user://test_custom_advanced.cfg")
	PlayerCustom.body_height = 4
	PlayerCustom.body_build = 3
	var k := _actor()
	PlayerCustom.dress(k, true)
	check(k.model.scale.is_equal_approx(Vector3.ONE * SpActor.BODY_SCALE), "el arquero no lleva la altura ni la complexion")
	var s := _actor()
	PlayerCustom.dress(s)
	check(s.model.scale.y > SpActor.BODY_SCALE, "el tirador si")
	PlayerCustom.restore_after_tests()
	cleanup()

func test_boot_details_and_saved_patterns() -> void:
	PlayerCustom.use_path("user://test_custom_advanced.cfg")
	PlayerCustom.boots_item = "boots_relampago"
	PlayerCustom.boots_sole = 3
	PlayerCustom.boots_laces = 5
	var k: Dictionary = PlayerCustom.kit()
	check(k["boots_sole"] == HairCatalog.BOOT_DETAILS[3] and k["boots_laces"] == HairCatalog.BOOT_DETAILS[5], "suela y cordones elegidos")
	var a := _actor()
	a.set_kit(k)
	check((a.kit_material().get_shader_parameter("boots_sole") as Color).is_equal_approx(HairCatalog.BOOT_DETAILS[3]), "pintados en el botin")
	PlayerCustom.boots_sole = -1
	check(PlayerCustom.kit()["boots_sole"] == BootsCatalog.style("boots_relampago", Color.BLACK)["boots_sole"], "-1: la suela del par")
	# Los diseños nuevos (7 a 11) sobreviven a guardar y volver a cargar (antes se recortaban).
	PlayerCustom.jersey_pattern = PlayerCustom.JERSEY_PATTERNS["cuadros"]
	PlayerCustom.shorts_pattern = PlayerCustom.SHORTS_PATTERNS["bajo"]
	PlayerCustom.haircut = "hair_afro"
	PlayerCustom.body_height = 0
	PlayerCustom.save_custom()
	PlayerCustom.load_custom(true)
	check(PlayerCustom.jersey_pattern == PlayerCustom.JERSEY_PATTERNS["cuadros"] and PlayerCustom.shorts_pattern == 4, "diseños guardados completos")
	check(PlayerCustom.haircut == "hair_afro" and PlayerCustom.body_height == 0, "peinado y altura guardados")
	PlayerCustom.restore_after_tests()
	cleanup()

func test_server_validates_unlocks() -> void:
	var o: Node = await _online()
	var r: Dictionary = await o.call_state_fn("update_appearance", {"p_appearance": {"haircut": "hair_rulos", "beard": "beard_bigote",
		"height": 4, "build": 3, "boots_sole": -1, "boots_laces": 5}})
	check(r["ok"], "lo gratuito se equipa (peinado, barba, cuerpo y detalles)")
	r = await o.call_state_fn("update_appearance", {"p_appearance": {"haircut": "hair_afro"}})
	check(not r["ok"], "el afro de la tienda no se equipa sin comprarlo")
	r = await o.call_state_fn("update_appearance", {"p_appearance": {"beard": 3}})
	check(not r["ok"], "la barba es un objeto, no un numero")
	r = await o.call_state_fn("update_appearance", {"p_appearance": {"haircut": "beard_bigote"}})
	check(not r["ok"], "una barba no va como peinado")
	r = await o.call_state_fn("update_appearance", {"p_appearance": {"boots_sole": -2}})
	check(not r["ok"], "color de suela fuera de rango")
	r = await o.call_state_fn("update_appearance", {"p_appearance": {"haircut": "hair_jopo"}})
	check(not r["ok"], "el jopo pide nivel 3")
	o.local._db["profile"]["xp"] = 450
	r = await o.call_state_fn("update_appearance", {"p_appearance": {"haircut": "hair_jopo", "jersey": "jersey_aros"}})
	check(r["ok"], "con nivel 3, lo de progresion se equipa sin comprarlo (antes nunca llegaba al inventario)")
	r = await o.call_state_fn("update_appearance", {"p_appearance": {"haircut": "hair_cresta"}})
	check(not r["ok"], "la cresta pide el logro")
	await o.call_fn("claim_reward", {"p_idem": "logro-goles10-test", "p_source": "logro", "p_payload": {"id": "goles_10"}})
	await o.call_fn("claim_reward", {"p_idem": "logro-goles10-test", "p_source": "logro", "p_payload": {"id": "goles_10"}})
	await o.refresh_state()
	check(int(o.inventory().get("hair_cresta", 0)) == 1, "el logro Goleador entrega la cresta una sola vez")
	r = await o.call_state_fn("update_appearance", {"p_appearance": {"haircut": "hair_cresta"}})
	check(r["ok"], "y se equipa")
	var b: Dictionary = await o.call_state_fn("buy_item", {"p_item": "hair_estrella", "p_idem": "buy-estrella-01"})
	check(not b["ok"], "lo premium no se vende (pagos no activados)")
	await o.sign_out()

func test_appearance_changed_offline_syncs_once() -> void:
	var o: Node = await _online()
	o.local.simulate_offline = true
	o.queue_appearance({"haircut": "hair_rapado"})
	o.queue_appearance({"beard": "beard_corta", "haircut": "hair_rulos"})
	var ops: Array = (o.queue as Array).filter(func(op: Dictionary) -> bool: return String(op["fn"]) == "update_appearance")
	check(ops.size() == 1, "una sola operacion en la cola, con la ultima eleccion de cada campo")
	check(String(ops[0]["args"]["p_appearance"]["haircut"]) == "hair_rulos", "gana la ultima eleccion")
	o.local.simulate_offline = false
	await o.flush()
	var ap: Dictionary = o.profile().get("appearance", {})
	check(String(ap.get("haircut", "")) == "hair_rulos" and String(ap.get("beard", "")) == "beard_corta", "al volver la conexion se guarda en el servidor")
	check((o.queue as Array).is_empty(), "y la cola queda vacia")
	await o.sign_out()

func test_customize_screen_body_boots_and_name() -> void:
	var o: Node = await _online()
	PlayerCustom.use_path("user://test_custom_advanced.cfg")
	var menu: Node = (load("res://scenes/setpiece/main_menu.tscn") as PackedScene).instantiate()
	spawn(menu)
	await physics_frames(5)
	var screens: MenuScreens = menu.get("screens")
	await screens.open_customize()
	screens._show_custom_tab("body")
	await physics_frames(2)
	var txt: String = ""
	for l in screens._custom_box.find_children("*", "Label", true, false):
		txt += (l as Label).text + "|"
	check(txt.contains("Peinado") and txt.contains("Barba") and txt.contains("Altura") and txt.contains("Complexión"), "pestaña Cuerpo: peinado, barba, altura y complexion")
	screens._set_appearance("haircut", "hair_rulos")
	screens._set_appearance("height", 4)
	await physics_frames(2)
	var player: SpActor = menu.get("_player")
	check(player.haircut == "hair_rulos" and player.model.scale.y > SpActor.BODY_SCALE, "el cambio se ve en el jugador al instante")
	screens._show_custom_tab("boots")
	await physics_frames(2)
	check(screens._custom_box.find_child("ColoresDelPar", true, false) != null, "pestaña Botines: colores de detalle")
	screens._set_appearance("boots_sole", 3)
	check((player.kit_material().get_shader_parameter("boots_sole") as Color).is_equal_approx(HairCatalog.BOOT_DETAILS[3]), "suela pintada en el jugador")
	screens._show_custom_tab("number_style")
	await physics_frames(2)
	var le: LineEdit = screens._custom_box.find_child("NombreCamiseta", true, false)
	check(le != null and screens._custom_box.find_child("Numero_7", true, false) != null and screens._custom_box.find_child("Numero_10", true, false) != null,
		"pestaña Número: nombre y los números destacados 7 y 10")
	le.text = "Pibe"
	(screens._custom_box.find_child("AplicarNombre", true, false) as Button).pressed.emit()
	await physics_frames(2)
	check(PlayerCustom.shirt_name == "Pibe" and int(player.kit_material().get_shader_parameter("name_len")) == 4, "el nombre se imprime en la camiseta")
	await screens.set_shirt_number(7)
	check(PlayerCustom.number == 7 and int(o.profile().get("shirt_number", 0)) == 7, "número 7 en el jugador y en el perfil")
	screens.close()
	await physics_frames(3)
	var ap: Dictionary = o.profile().get("appearance", {})
	check(String(ap.get("haircut", "")) == "hair_rulos" and int(ap.get("height", 0)) == 4 and String(ap.get("shirt_name", "")) == "Pibe",
		"al salir queda guardado en el servidor")
	await o.sign_out()
	PlayerCustom.restore_after_tests()
	cleanup()
