extends TestCase
## Selector y buscador de partidas online (pedido del usuario 2026-11-12: «es muy feo, hacelo mejor»): modalidades como
## tarjetas con imagen (la elegida con borde dorado), panel de la modalidad elegida con la entrada en botones y BUSCAR
## PARTIDA, y la pantalla de busqueda con el cara a cara al encontrar rival. Con el servidor local de pruebas.

const DIR := "user://test_online_lobby_ui"

func _setup_online() -> Node:
	var o: Node = tree.root.get_node("Online")
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/" + f))
	o.use_local(DIR)
	await o.sign_up("lobby@futbol.com", "golazo123")
	await o.call_state_fn("create_profile", {"p_username": "LobbyCrack", "p_display_name": "Lobby"})
	return o

func _border(b: Button) -> int:
	return (b.get_theme_stylebox("normal") as StyleBoxFlat).border_width_top

func test_lobby_tiles_detail_and_search_screen() -> void:
	await _setup_online()
	var screens := MenuScreens.new()
	spawn(screens)
	await physics_frames(2)
	screens.open_online()
	for i in 30:
		await tree.process_frame
		if not screens._mode_tiles.is_empty():
			break
	await physics_frames(2)
	var modes: Array = screens._online_modes
	note("modalidades: %d, tarjetas: %d, elegida: %s" % [modes.size(), screens._mode_tiles.size(), screens._sel_mode])
	check(not modes.is_empty() and screens._mode_tiles.size() == modes.size(), "una tarjeta por modalidad")
	var sel: Button = screens._mode_tiles.get(screens._sel_mode)
	check(sel != null and _border(sel) == 4, "la modalidad elegida tiene el borde dorado")
	check(sel != null and not sel.find_children("*", "TextureRect", true, false).is_empty(), "cada tarjeta lleva su imagen")
	var go: Button = screens._mode_detail.find_child("BuscarPartida", true, false)
	check(go != null and not go.disabled and go.text == "BUSCAR PARTIDA", "el panel de la derecha tiene el boton BUSCAR PARTIDA")
	screens.select_mode("tiros_libres")
	await physics_frames(2)
	var texts: Array = []
	for l in screens._mode_detail.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	check(texts.has("Tiros libres") or texts.any(func(t: String) -> bool: return t.contains("Tiros")), "al tocar otra tarjeta, el panel muestra esa modalidad")
	check(_border(screens._mode_tiles["tiros_libres"]) == 4 and _border(screens._mode_tiles["penales"]) == 2, "y el borde dorado pasa a esa tarjeta")
	# Entrada en botones: la elegida resaltada; tocar otra la cambia.
	var fee_btns: Array = screens._mode_detail.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.has_meta("fee"))
	check(fee_btns.size() >= 2, "la entrada se elige con botones (%d)" % fee_btns.size())
	(fee_btns[1] as Button).pressed.emit()
	check(screens._sel_fee == int((fee_btns[1] as Button).get_meta("fee")), "tocar una entrada la elige")
	# Pantalla de busqueda y el cara a cara.
	var ui: Dictionary = screens.search_screen(screens._mode_by_id("penales"))
	await physics_frames(2)
	check((ui["title"] as Label).text == "BUSCANDO RIVAL" and (ui["cancel"] as Button).visible, "busqueda: titulo, reloj y Cancelar")
	screens.show_found(ui, {"opponent": {"name": "ElTanque", "level": 7, "is_bot": true}})
	await physics_frames(2)
	var vs_texts: Array = []
	for l in (ui["vs"] as Control).find_children("*", "Label", true, false):
		vs_texts.append((l as Label).text)
	note("cara a cara: %s" % str(vs_texts))
	check((ui["title"] as Label).text == "¡RIVAL ENCONTRADO!" and vs_texts.has("ElTanque") and vs_texts.has("VS"), "al encontrar rival: el cara a cara con su nombre")
	check(not (ui["cancel"] as Button).visible, "y ya no se puede cancelar")
	(ui["overlay"] as Node).queue_free()
	cleanup()
