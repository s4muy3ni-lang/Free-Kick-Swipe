extends TestCase
## Personalizacion con dominadas (pedido del usuario: «el jugador debe estar haciendo dominadas con el balon
## continuamente… no reiniciar la animacion cada vez que se cambia una prenda… girar y acercar la vista»). La pelota es
## la fisica del juego: solo cambia de velocidad por los impulsos de cada toque.

func _menu() -> Node:
	var menu: Node = (load("res://scenes/setpiece/main_menu.tscn") as PackedScene).instantiate()
	spawn(menu)
	await physics_frames(5)
	return menu

func test_juggling_keeps_going_and_survives_outfit_changes() -> void:
	var menu: Node = await _menu()
	var screens: MenuScreens = menu.get("screens")
	screens.open_customize()
	await physics_frames(10)
	var j: JuggleShow = menu.get("juggle")
	check(j != null and is_instance_valid(j.ball), "al entrar a Personalizar empiezan las dominadas con una pelota física")
	var max_off: float = 0.0
	var min_y: float = INF
	var anim0: String = String(menu.get("_player").anim_player.current_animation)
	for i in 60 * 12:
		await tree.physics_frame
		var p: Vector3 = j.ball.global_position
		var c: Vector3 = j.contact_point(j.foot)
		max_off = maxf(max_off, Vector2(p.x - c.x, p.z - c.z).length())
		min_y = minf(min_y, p.y)
		if i == 60 * 5:
			# Cambio de ropa y de botines en el medio: las dominadas siguen.
			PlayerCustom.jersey = (PlayerCustom.jersey + 1) % PlayerCustom.JERSEYS.size()
			PlayerCustom.boots_item = "boots_relampago"
			screens.customize_changed.emit()
	note("12 s: %d toques, %d saques, mayor corrimiento %.2f m, altura minima %.2f m" % [j.touches, j.serves, max_off, min_y])
	check(j.touches >= 10, "toques continuos (%d en 12 s)" % j.touches)
	check(j.serves == 1, "la pelota nunca se perdió (un solo saque al empezar)")
	check(min_y > 0.25, "la pelota no toca el piso")
	check(String(menu.get("_player").anim_player.current_animation) == anim0, "cambiar la ropa no reinicia la animación")
	var feet := {}
	for f in j._pattern:
		feet[f] = true
	check(feet.size() == 2, "toca con los dos pies")
	# Vistas y zoom.
	menu.call("set_view", "botines")
	check(float(menu.get("_view_h")) < 0.4 and float(menu.get("_view_dist")) < 1.6, "vista de los botines: abajo y cerca")
	menu.call("set_view", "espalda")
	check(absf(float(menu.get("_view_yaw")) - PI) < 0.01, "vista de espalda")
	screens.customize_zoom.emit(0.8)
	check(float(menu.get("_view_dist")) < 3.0, "acercar")
	screens.close()
	await physics_frames(3)
	check(menu.get("juggle") == null, "al salir se terminan las dominadas")
	PlayerCustom.restore_after_tests()
	cleanup()

## Con el esqueleto animado (render): en cada toque, la punta del pie esta abajo de la pelota.
func test_the_foot_meets_the_ball() -> void:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return
	var menu: Node = await _menu()
	var screens: MenuScreens = menu.get("screens")
	screens.open_customize()
	await physics_frames(10)
	var j: JuggleShow = menu.get("juggle")
	var gaps: Array = []
	var last: int = j.touches
	for i in 60 * 10:
		await tree.physics_frame
		if j.touches != last:
			last = j.touches
			var toe: Vector3 = j.ik.rendered_toe_world[j._last_foot]
			gaps.append(toe.distance_to(j.ball.global_position))
	gaps.sort()
	note("distancia punta del pie - centro de la pelota en %d toques: mediana %.2f m, peor %.2f m" % [gaps.size(), float(gaps[gaps.size() / 2]) if not gaps.is_empty() else -1.0, float(gaps.back()) if not gaps.is_empty() else -1.0])
	check(gaps.size() >= 8, "hubo toques")
	check(not gaps.is_empty() and float(gaps[gaps.size() / 2]) < 0.3, "el pie llega a la pelota (mediana < 0,3 m)")
	PlayerCustom.restore_after_tests()
	cleanup()
