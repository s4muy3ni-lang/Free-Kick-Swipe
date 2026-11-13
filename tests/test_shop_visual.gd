extends TestCase
## Tienda visual (pedido del usuario: «no quiero una tienda que parezca un listado de letras… cada producto con su
## representacion visual, estados disponible / comprado / equipado / bloqueado / premium, vista previa, sin compras
## duplicadas, sin descontar si falla»). Con el servidor local (las mismas reglas que el SQL).

const DIR := "user://test_shop_visual"

func _online() -> Node:
	var o: Node = tree.root.get_node("Online")
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/" + f))
	o.use_local(DIR)
	await o.sign_up("tienda@futbol.com", "golazo123")
	await o.call_state_fn("create_profile", {"p_username": "Comprador", "p_display_name": "Comprador"})
	return o

func _catalog() -> Array:
	return (JSON.parse_string(FileAccess.get_file_as_string("res://resources/online/seed.json")) as Dictionary)["catalog_items"]

func test_every_item_has_its_real_image() -> void:
	var missing: Array = []
	var n: int = 0
	for it in _catalog():
		n += 1
		if ShopLook.image(String(it["id"])) == null:
			missing.append(it["id"])
	note("%d objetos en el catalogo" % n)
	check(n >= 60, "catalogo ampliado (%d objetos)" % n)
	check(missing.is_empty(), "cada objeto tiene su imagen (%s)" % str(missing))
	var kinds := {}
	for it in _catalog():
		kinds[String(it["kind"])] = int(kinds.get(String(it["kind"]), 0)) + 1
	note("por tipo: %s" % str(kinds))
	for k in ["jersey", "shorts", "socks", "boots", "ball", "accessory"]:
		check(int(kinds.get(k, 0)) >= 5, "hay variedad de %s (%d)" % [k, int(kinds.get(k, 0))])

func test_items_change_the_real_model() -> void:
	# Botines: el par elegido cambia el modelo pintado en los pies (no solo el nombre).
	var a := SpActor.new()
	spawn(a)
	a.build(ShopLook.kit_for({"id": "boots_relampago", "kind": "boots", "data": {"model": "pro", "color": 5}}, ShopLook.showcase_kit()))
	var m: ShaderMaterial = a.kit_material()
	check(int(m.get_shader_parameter("boots_model")) == 2 and float(m.get_shader_parameter("boots_glow")) > 1.0, "botines Relámpago: modelo pro con brillo")
	a.set_kit(ShopLook.kit_for({"id": "boots_retro_cuero", "kind": "boots", "data": {}}, ShopLook.showcase_kit()))
	m = a.kit_material()
	check(int(m.get_shader_parameter("boots_model")) == 0 and (m.get_shader_parameter("boots_color") as Color).r < 0.3, "botines de cuero: otro modelo y otro color")
	# Camiseta: el diseño es el del objeto.
	a.set_kit(ShopLook.kit_for({"id": "jersey_cuadros", "kind": "jersey", "data": {"pattern": "cuadros"}}, ShopLook.showcase_kit()))
	check(int(a.kit_material().get_shader_parameter("jersey_pattern")) == PlayerCustom.JERSEY_PATTERNS["cuadros"], "camiseta a cuadros")
	# Accesorios: piezas colgadas de los huesos, que se ponen y se sacan.
	a.set_accessories(["acc_munequeras", "acc_cinta"])
	await physics_frames(2)
	check(a._acc_nodes.size() == 3, "muñequeras (2) y vincha (1) puestas")
	a.set_accessories([])
	await physics_frames(2)
	check(a.accessories.is_empty(), "y se sacan")
	cleanup()

## El diseño del balon no cambia la fisica: misma masa, radio, rozamiento y la misma trayectoria.
func test_ball_designs_do_not_change_physics() -> void:
	var paths: Array = []
	for design in ["clasico", "llamas", "noche"]:
		var b: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
		spawn(b)
		b.set_skin(design)
		b.reset_at(Vector3(0, 0.11, 0))
		await physics_frames(2)
		b.kick(Vector3(14, 6, 2), Vector3(0, 8, 0), null)
		await physics_frames(40)
		paths.append([b.mass, b.radius, b.global_position, b.skin()])
		cleanup()
	note("posiciones tras 40 pasos: %s" % str(paths.map(func(p: Array) -> String: return "%s %s" % [p[3], str(p[2])])))
	check(paths[0][0] == paths[1][0] and paths[1][0] == paths[2][0], "misma masa")
	check(paths[0][1] == paths[1][1] and paths[1][1] == paths[2][1], "mismo radio")
	check((paths[0][2] as Vector3).distance_to(paths[1][2]) < 0.01 and (paths[0][2] as Vector3).distance_to(paths[2][2]) < 0.01, "misma trayectoria con cualquier diseño")

func test_the_shop_screen_states_buying_and_equipping() -> void:
	var o: Node = await _online()
	var screens := MenuScreens.new()
	spawn(screens)
	await physics_frames(2)
	await screens.open_shop()
	await physics_frames(3)
	var cards: int = screens._shop_grid.get_child_count()
	check(cards == screens._shop_items().size() and cards >= 60, "una tarjeta con imagen por objeto (%d)" % cards)
	var by_id := {}
	for it in screens._catalog:
		by_id[String(it["id"])] = it
	check(screens.shop_state(by_id["boots_clasicos"]) == "equipado", "el primer gratuito está equipado")
	check(screens.shop_state(by_id["boots_modernos"]) == "tuyo", "otro gratuito es tuyo")
	check(screens.shop_state(by_id["jersey_premium_oro"]) == "premium", "premium marcado aparte")
	check(screens.shop_state(by_id["boots_retro_cuero"]) == "bloqueado", "uno de progresión sin el nivel: bloqueado")
	check(screens.shop_state(by_id["shorts_bajo"]) == "disponible", "uno de la tienda con nivel: disponible")
	# Compra que falla (sin monedas suficientes): no descuenta nada.
	var coins0: int = o.coins()
	var r: Dictionary = await o.call_state_fn("buy_item", {"p_item": "jersey_geometrica", "p_idem": "test-fail-1"})
	check(not r["ok"] or o.coins() == coins0 - 900, "sin monedas o con nivel bajo, la compra falla")
	if not r["ok"]:
		check(o.coins() == coins0, "y no se descuenta nada (%d)" % o.coins())
	# Compra que anda: 250 monedas, queda tuyo; la segunda no se cobra.
	var ficha := func() -> void: screens.open_item(by_id["shorts_bajo"])
	ficha.call()
	await physics_frames(2)
	check(is_instance_valid(screens._shop_modal) and screens._shop_modal.find_children("*", "ShopPreview", true, false).size() == 1, "la ficha trae la vista previa 3D")
	var buy: Button = screens._shop_modal.find_child("Comprar", true, false)
	check(buy != null and not buy.disabled, "botón COMPRAR habilitado")
	await screens._shop_buy(by_id["shorts_bajo"], Label.new())
	await physics_frames(2)
	check(o.coins() == coins0 - 250, "se cobró una sola vez (%d -> %d)" % [coins0, o.coins()])
	check(screens.shop_state(by_id["shorts_bajo"]) == "tuyo", "queda TUYO")
	var again: Dictionary = await o.call_state_fn("buy_item", {"p_item": "shorts_bajo", "p_idem": "test-dup-2"})
	check(not again["ok"] and o.coins() == coins0 - 250, "no se puede comprar dos veces")
	# Equipar: queda puesto en el perfil (validado por el servidor) y en el jugador.
	await screens._shop_equip(by_id["shorts_bajo"], true)
	await physics_frames(2)
	check(screens.shop_state(by_id["shorts_bajo"]) == "equipado", "equipado")
	check(String((o.profile().get("appearance", {}) as Dictionary).get("shorts", "")) == "shorts_bajo", "guardado en el perfil del servidor")
	await screens._shop_equip(by_id["acc_munequeras"], true)
	check(PlayerCustom.accessories.has("acc_munequeras"), "accesorio puesto en el jugador")
	await screens._shop_equip(by_id["acc_munequeras"], false)
	check(not PlayerCustom.accessories.has("acc_munequeras"), "y se puede quitar")
	PlayerCustom.restore_after_tests()
	cleanup()
