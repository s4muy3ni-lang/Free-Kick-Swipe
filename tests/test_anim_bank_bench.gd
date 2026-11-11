extends TestCase
## Banco de pruebas de animaciones: solo el banco JSON original (Mixamo y Mocap se borraron el 2026-11-08 por pedido del
## usuario). Comprueba: el catalogo tiene solo el banco JSON y sus clips vienen de sus bibliotecas, las bibliotecas de
## Mixamo y Mocap ya no existen, el banco carga solo las bibliotecas JSON, todos los clips del catalogo se reproducen sobre
## el humano JSON sin pistas huerfanas, el golpe de referencia sale en el instante de contacto del clip (con render: la
## punta del pie esta en la pelota) y el menu principal abre el banco (el modo de futbol 5 ya no existe).

func _bench() -> AnimBankBench:
	use_game_pitch()
	var b: AnimBankBench = (load("res://scenes/dev/anim_bank_bench.tscn") as PackedScene).instantiate()
	spawn(b)
	await physics_frames(2)
	return b

func test_catalog_is_separated_by_provenance() -> void:
	check(AnimBankCatalog.available(), "existe el catalogo (resources/animation/catalogo_bancos.json)")
	check(AnimBankCatalog.BANKS == ["json"], "solo el banco JSON original")
	check((AnimBankCatalog.data().get("bancos", {}) as Dictionary).keys() == ["json"], "el catalogo no tiene Mixamo ni Mocap")
	for gone in ["res://assets/animations/pack_clips.res", "res://assets/animations/pack_keeper.res", "res://assets/animations/mocap_clips.res",
			"res://assets/animations/touch_clips.res", "res://assets/characters/mocap/mocap_player.scn"]:
		check(not ResourceLoader.exists(gone), "borrado: %s" % gone)
	var seen: Dictionary = {}
	for bank in AnimBankCatalog.BANKS:
		var libs: Array = AnimBankCatalog.libraries(bank)
		var names: Dictionary = {}
		for path in libs:
			for n in (load(path) as AnimationLibrary).get_animation_list():
				names[String(n)] = true
		var foreign: Array = []
		var missing: Array = []
		for e in AnimBankCatalog.all_clips(bank):
			if not libs.has(e["biblioteca"]):
				foreign.append(e["id"])
			if not names.has(String(e["id"])):
				missing.append(e["id"])
			seen[String(e["id"])] = int(seen.get(String(e["id"]), 0)) + 1
		note("%s: %d clips catalogados de %d en sus bibliotecas" % [bank, AnimBankCatalog.all_clips(bank).size(), names.size()])
		check(not AnimBankCatalog.all_clips(bank).is_empty(), "%s: tiene clips catalogados" % bank)
		check(foreign.is_empty(), "%s: todos sus clips vienen de sus propias bibliotecas %s" % [bank, str(foreign.slice(0, 5))])
		check(missing.is_empty(), "%s: todos sus clips existen en sus bibliotecas %s" % [bank, str(missing.slice(0, 5))])
	var dup: Array = seen.keys().filter(func(k: String) -> bool: return int(seen[k]) > 1)
	check(dup.is_empty(), "ningun clip aparece en dos bancos %s" % str(dup.slice(0, 5)))
	check(AnimBankCatalog.count("json", "wa_jump") > 0, "JSON tiene salto de barrera")

func test_every_catalog_clip_binds_to_the_common_body() -> void:
	var inst: Node3D = (load(AnimBankCatalog.COMMON_BODY) as PackedScene).instantiate()
	spawn(inst)
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	for bank in AnimBankCatalog.BANKS:
		var bad: Array = []
		var libs: Dictionary = {}
		for e in AnimBankCatalog.all_clips(bank):
			if not libs.has(e["biblioteca"]):
				libs[e["biblioteca"]] = load(e["biblioteca"])
			var a: Animation = (libs[e["biblioteca"]] as AnimationLibrary).get_animation(StringName(e["id"]))
			var bound: Dictionary = PoseSampler.bind(a, sk)
			if bound.size() != a.get_track_count():
				bad.append(e["id"])
		check(bad.is_empty(), "%s: cada pista de cada clip encuentra su hueso en el cuerpo comun %s" % [bank, str(bad.slice(0, 5))])

func test_selector_loads_only_the_chosen_bank() -> void:
	var b: AnimBankBench = await _bench()
	for bank in AnimBankCatalog.BANKS:
		b.select_bank(bank)
		await physics_frames(2)
		var want: Array = AnimBankCatalog.libraries(bank)
		var got: Array = b.loaded_libraries()
		want.sort()
		got.sort()
		check(got == want, "%s: solo sus bibliotecas cargadas (%s)" % [bank, str(got)])
		check(b.anim_player.get_animation_library_list().size() == want.size(), "%s: el reproductor no tiene otras bibliotecas" % bank)
		check(b.info_text().begins_with("BANCO: %s" % AnimBankCatalog.label(bank)), "%s: el panel nombra el banco" % bank)
	cleanup()

## Las 25 acciones del catalogo tienen clip en el banco JSON (no queda ninguna «sin clip»).
func test_every_category_has_a_json_clip() -> void:
	var b: AnimBankBench = await _bench()
	b.select_bank("json")
	for c in AnimBankCatalog.categories():
		b.select_category(String(c["id"]))
		await physics_frames(1)
		check(not b.current.is_empty(), "%s: hay clip JSON" % c["id"])
	check(not b._empty.visible, "sin aviso de categoria vacia")
	cleanup()

func test_every_category_plays_in_every_bank_without_errors() -> void:
	var b: AnimBankBench = await _bench()
	var played: int = 0
	for bank in AnimBankCatalog.BANKS:
		b.select_bank(bank)
		for c in AnimBankCatalog.categories():
			b.select_category(String(c["id"]))
			await physics_frames(1)
			if not b.current.is_empty():
				check(b.anim_player.current_animation != "" or b.sequence, "%s/%s: reproduce %s" % [bank, c["id"], b.current["id"]])
				played += 1
	note("categorias con clip reproducidas: %d" % played)
	cleanup()

## Con render: en el instante de contacto del clip la pelota recibe el golpe y la punta del pie esta en la pelota.
func test_reference_kick_happens_at_the_clip_contact() -> void:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return
	var b: AnimBankBench = await _bench()
	b.repeat = false
	for body_original in [false]:
		for bank in AnimBankCatalog.BANKS:
			b.select_bank(bank)
			b.select_category("st_penalty")
			if b.current.is_empty():
				continue
			var t_contact: float = float(b.current["contacto"]["t"])
			var frames: int = 0
			while not b.metrics.has("pie_pelota_m") and frames < 600:
				await tree.process_frame
				frames += 1
			await physics_frames(3)
			var d: float = float(b.metrics.get("pie_pelota_m", INF))
			note("%s, cuerpo %s, %s: punta del pie - pelota en el golpe %.3f m (contacto del clip %.2f s); pelota a %.1f m/s" % [bank,
				"original" if body_original else "comun", b.current["id"], d, t_contact, b.ball.linear_velocity.length()])
			check(b.metrics.has("pie_pelota_m"), "%s: el golpe ocurre en el instante de contacto del clip" % bank)
			check(b.ball.linear_velocity.length() > 3.0, "%s: la pelota sale golpeada" % bank)
			check(d <= 0.25, "%s: punta del pie a %.3f m del centro de la pelota (<= 0,25)" % [bank, d])
	cleanup()

## Entrada del juego (decision del usuario 2026-11-08): el menu principal con los dos modos (penales y tiro libre) y un acceso
## al banco de pruebas de animaciones; el modo de futbol 5 sigue fuera.
func test_main_menu_is_the_entry_and_the_5_a_side_mode_is_gone() -> void:
	check(String(ProjectSettings.get_setting("application/run/main_scene")) == MainMenu.SCENE, "la entrada del juego es el menu principal")
	check(ResourceLoader.exists(MainMenu.BENCH_SCENE), "existe la escena del banco de pruebas")
	check(not ResourceLoader.exists("res://scenes/main/match.tscn"), "el modo de futbol 5 se quito (sin escena de partido)")
	var m: MainMenu = (load(MainMenu.SCENE) as PackedScene).instantiate()
	spawn(m)
	await physics_frames(1)
	var texts: Array = []
	for btn in m.find_children("*", "Button", true, false):
		texts.append((btn as Button).text)
	check(str(texts).contains("PENALES") and str(texts).contains("TIRO LIBRE") and str(texts).contains("ACADEMIA") and str(texts).contains("DESAFÍOS") and str(texts).contains("MINIJUEGOS") and str(texts).contains("ARCADE"), "penales y tiro libre como juegos principales, y las tres secciones (%s)" % str(texts))
	check(str(texts).contains("Banco de animaciones"), "acceso al banco de pruebas")
	check(str(texts).contains("Arco:"), "selector del tipo de arco")
	check(not str(texts).contains("fútbol 5"), "ningun acceso al futbol 5")
	cleanup()
