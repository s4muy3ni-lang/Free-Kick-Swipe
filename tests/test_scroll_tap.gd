extends TestCase
## Listas con scroll (pedido del usuario 2026-11-12: «no me deja hacer scroll sobre los iconos de los minijuegos»): las
## tarjetas con imagen dejan pasar el arrastre a la lista y un toque que arrastro la lista no aprieta el boton.

func test_cards_let_the_list_scroll_and_drags_do_not_press() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 300)
	spawn(scroll)
	ScrollTap.watch(scroll)
	var vb := VBoxContainer.new()
	scroll.add_child(vb)
	var presses: Array = [0]
	var b := Button.new()
	b.text = "Minijuego"
	b.icon = PlaceholderTexture2D.new()
	b.pressed.connect(func() -> void: presses[0] += 1)
	var panel := PanelContainer.new()
	var inner := Button.new()
	inner.pressed.connect(func() -> void: presses[0] += 10)
	panel.add_child(inner)
	var edit := LineEdit.new()
	vb.add_child(b)
	vb.add_child(panel)
	vb.add_child(edit)
	await physics_frames(2)
	check(b.mouse_filter == Control.MOUSE_FILTER_PASS, "la tarjeta deja pasar el arrastre a la lista")
	check(panel.mouse_filter == Control.MOUSE_FILTER_PASS and inner.mouse_filter == Control.MOUSE_FILTER_PASS, "tambien los paneles y sus botones")
	check(edit.mouse_filter == Control.MOUSE_FILTER_STOP, "un campo de texto conserva el toque")
	b.pressed.emit()
	check(presses[0] == 1, "un toque sin arrastrar aprieta el boton")
	scroll.scroll_started.emit()
	b.pressed.emit()
	inner.pressed.emit()
	check(presses[0] == 1, "mientras se arrastra la lista, soltar el dedo no aprieta nada")
	scroll.scroll_ended.emit()
	b.pressed.emit()
	check(presses[0] == 1, "ni justo al terminar de arrastrar")
	# La gracia se mide en tiempo real (la suite corre a cuadros fijos, mas rapido que el reloj).
	var until: int = Time.get_ticks_msec() + ScrollTap.TAP_GRACE_MS + 60
	while Time.get_ticks_msec() < until:
		await tree.process_frame
	inner.pressed.emit()
	check(presses[0] == 11, "despues, un toque vuelve a apretar")
	cleanup()

func test_the_menus_use_it() -> void:
	ChallengeMenu.section = "arcade"
	ChallengeMenu.arcade_category = ""
	ChallengeMenu.arcade_item = ""
	var cm: Node = (load(ChallengeMenu.SCENE) as PackedScene).instantiate()
	spawn(cm)
	await physics_frames(3)
	var stop: int = 0
	var buttons: int = 0
	for n in cm.find_children("*", "BaseButton", true, false):
		var p: Node = n.get_parent()
		var in_list: bool = false
		while p != null:
			if p is ScrollContainer:
				in_list = true
				break
			p = p.get_parent()
		if in_list:
			buttons += 1
			if (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
				stop += 1
	note("arcade: %d botones en la lista, %d frenan el arrastre" % [buttons, stop])
	check(buttons > 0 and stop == 0, "las tarjetas del arcade (con su imagen) dejan arrastrar la lista")
	cleanup()
