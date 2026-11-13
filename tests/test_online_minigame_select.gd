extends TestCase
## Minijuegos online: elegir minijuego y nivel, o aleatorio (pedido del usuario: «no quiero que al terminar un nivel se
## cambie automaticamente a otro minijuego»). Los niveles de la seleccion son los del contenido real; el servidor
## (LocalBackend, mismas reglas que la migracion 20261113000007) valida y guarda la eleccion, solo acepta el resultado de
## ese nivel y la revancha vuelve a la seleccion; al terminar, acciones separadas y ningun «siguiente nivel».

const DIR := "user://test_online_minigame_select"

func _modes() -> Array:
	return (JSON.parse_string(FileAccess.get_file_as_string("res://resources/online/seed.json")) as Dictionary)["game_modes"]

func _online() -> Node:
	var o: Node = tree.root.get_node("Online")
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/" + f))
	o.use_local(DIR)
	await o.sign_up("mini@futbol.com", "golazo123")
	await o.call_state_fn("create_profile", {"p_username": "MiniCrack", "p_display_name": "Mini"})
	return o

func test_the_levels_come_from_the_real_content() -> void:
	var n: int = 0
	for gm in _modes():
		var sd: Dictionary = gm.get("scene_def", {})
		if String(gm["kind"]) != "minijuego":
			continue
		n += 1
		check(sd.has("levels"), "%s: el servidor tiene su lista de niveles" % gm["id"])
		var defs: Array = OnlineMinigameSelect.levels_of(gm)
		check(defs.size() == (sd["levels"] as Array).size(), "%s: todos sus niveles existen en el juego (%d)" % [gm["id"], defs.size()])
		check(String(sd.get("game", "")) == String(OnlineDuel.MODES[String(gm["id"])].get("game", "")), "%s: mismo minijuego que juega el cliente" % gm["id"])
		for d in defs:
			check(ResourceLoader.exists(String(d["scene"])), "%s nivel %d: escena real" % [gm["id"], int(d["level"])])
	check(n == 6, "seis minijuegos online (con Rescate)")
	var a: Array = OnlineMinigameSelect.levels_of({"scene_def": {"game": "boton_caida", "levels": [1, 2, 3, 4, 5, 6, 7, 8]}})
	check(a.size() == 8 and String(a[0]["title"]) == "A la vista", "Plataforma y vacío (A la vista): sus 8 niveles, en orden")

func test_the_selection_screen() -> void:
	var s := OnlineMinigameSelect.new()
	s.setup(_modes(), "a_la_vista", "ElTanque")
	spawn(s)
	await physics_frames(2)
	check(s._tab_buttons.size() == 6, "pestañas de los 6 minijuegos online")
	check(s._cards.size() == 8, "A la vista muestra sus 8 niveles")
	check(s._confirm.disabled, "sin nivel elegido no se puede confirmar")
	var got: Array = []
	s.confirmed.connect(func(m: String, lv: int) -> void: got.append([m, lv]))
	s.select_mode("guante")
	await physics_frames(2)
	check(s._cards.size() == 4 and s.mode == "guante", "Guante: 4 niveles")
	s.select_level(3)
	check(not s._confirm.disabled and s._summary.text.contains("Nivel 3"), "con nivel elegido se ve qué y se puede confirmar: «%s»" % s._summary.text)
	s._confirm.pressed.emit()
	check(got.size() == 1 and got[0][0] == "guante" and got[0][1] == 3, "confirma Guante, nivel 3")
	cleanup()
	var same := OnlineMinigameSelect.new()
	same.setup(_modes(), "basket", "ElTanque", true)
	spawn(same)
	await physics_frames(2)
	check(not same._tabs.visible and same._cards.size() == 9, "«Otro nivel»: solo los niveles del mismo minijuego")
	cleanup()

func test_the_server_validates_the_choice_and_the_result() -> void:
	var o: Node = await _online()
	await o.call_fn("find_match", {"p_mode": "a_la_vista", "p_fee": 0})
	o.local.clock_offset += 10.0
	var r: Dictionary = await o.call_fn("start_bot_match", {"p_mode": "a_la_vista"})
	var mid: String = String(r["data"]["match"]["id"])
	r = await o.call_fn("choose_minigame", {"p_match": mid, "p_mode": "a_la_vista", "p_level": 9})
	check(not r["ok"], "A la vista no tiene nivel 9")
	r = await o.call_fn("choose_minigame", {"p_match": mid, "p_mode": "penales", "p_level": 1})
	check(not r["ok"], "los penales no son un minijuego")
	r = await o.call_fn("finish_minigame", {"p_match": mid, "p_game": "boton_caida", "p_level": 2, "p_points": 3, "p_bot_points": 1})
	check(not r["ok"], "sin elegir no hay resultado")
	r = await o.call_fn("choose_minigame", {"p_match": mid, "p_mode": "a_la_vista", "p_level": 2})
	check(r["ok"] and int(r["data"]["match"]["minigame"]["level"]) == 2, "elige A la vista, nivel 2")
	r = await o.call_fn("finish_minigame", {"p_match": mid, "p_game": "guante", "p_level": 2, "p_points": 3, "p_bot_points": 1})
	check(not r["ok"], "un resultado de otro minijuego se rechaza")
	r = await o.call_fn("finish_minigame", {"p_match": mid, "p_game": "boton_caida", "p_level": 2, "p_points": 3, "p_bot_points": 1})
	check(r["ok"] and String(r["data"]["match"]["status"]) == "finished" and int(r["data"]["match"]["winner"]) == 0, "resultado del nivel elegido: partida cerrada y gana el usuario")
	r = await o.call_fn("rematch_bot", {"p_match": mid})
	check(r["ok"] and String(r["data"]["match"]["status"]) == "active", "revancha con el mismo bot sin esperar")
	var seen := {}
	for i in 12:
		if i > 0:
			o.local._db["match"]["status"] = "finished"
			r = await o.call_fn("rematch_bot", {"p_match": ""})
		r = await o.call_fn("choose_minigame", {"p_match": "", "p_mode": "", "p_level": 0, "p_random": true})
		var mg: Dictionary = r["data"]["match"]["minigame"]
		var gm: Dictionary = {}
		for x in _modes():
			if String(x["id"]) == String(mg["mode"]):
				gm = x
		check((gm["scene_def"]["levels"] as Array).map(func(x: Variant) -> int: return int(x)).has(int(mg["level"])), "aleatorio %d: %s nivel %d es valido" % [i, mg["mode"], int(mg["level"])])
		seen[String(mg["mode"])] = true
	note("aleatorio eligio: %s" % str(seen.keys()))
	check(seen.size() >= 2, "el aleatorio reparte entre minijuegos")

## Al terminar un minijuego online: acciones separadas (repetir, otro nivel, otro minijuego, aleatorio, salir) y nunca
## «Siguiente nivel».
func test_the_online_end_never_jumps_to_another_game() -> void:
	var d: Dictionary = MinigameCatalog.at_difficulty(MinigameCatalog.level("boton_caida", 2), OnlineDuel.HARD_LEVEL)
	d["online_bot"] = "ElTanque"
	OnlineDuel.active = {"mode": "a_la_vista", "bot": {"name": "ElTanque"}, "kind": "turnos", "shots": 5, "bot_points": -1,
		"game": "boton_caida", "level": 2, "match": ""}
	Minigame.next_def = d
	var g: Minigame = (load(String(d["scene"])) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g._end_match(0)
	var labels: Array = []
	for b in g.hud.overlay_actions.get_children():
		labels.append((b as Button).text)
	note("acciones: %s" % str(labels))
	for want in ["Repetir nivel", "Otro nivel", "Otro minijuego", "Aleatorio", "Salir"]:
		check(labels.has(want), "ofrece «%s»" % want)
	check(not labels.has("Siguiente nivel"), "sin «Siguiente nivel» que lleve a otro lado")
	check(not OnlineDuel.is_active(), "el duelo quedo cerrado")
	check(OnlineDuel.last.is_empty() or String(OnlineDuel.last.get("game", "")) != "", "queda anotado el ultimo minijuego")
	cleanup()

## En el menu: con el rival encontrado aparece la seleccion; «Otro nivel» al volver muestra solo los niveles del mismo
## minijuego contra el mismo bot (revancha del servidor).
func test_the_menu_shows_the_selection_and_resumes_after_a_game() -> void:
	var o: Node = await _online()
	await o.call_fn("find_match", {"p_mode": "guante", "p_fee": 0})
	o.local.clock_offset += 10.0
	var r: Dictionary = await o.call_fn("start_bot_match", {"p_mode": "guante"})
	var screens := MenuScreens.new()
	spawn(screens)
	await physics_frames(2)
	var sel: OnlineMinigameSelect = await screens.open_minigame_select(r["data"], "guante")
	await physics_frames(2)
	check(sel != null and sel.mode == "guante" and sel._cards.size() == 4, "seleccion abierta en Guante con sus 4 niveles")
	# Termino un Guante nivel 2 y el usuario eligio «Otro nivel».
	o.local._db["match"]["minigame"] = {"mode": "guante", "game": "guante", "level": 2, "confirmed_b": true}
	await o.call_fn("finish_minigame", {"p_match": "", "p_game": "guante", "p_level": 2, "p_points": 1, "p_bot_points": 0})
	OnlineDuel.last = {"mode": "guante", "game": "guante", "level": 2, "match": String(r["data"]["match"]["id"])}
	OnlineDuel.after = "level"
	await screens.resume_online_after()
	await physics_frames(3)
	var again: OnlineMinigameSelect = screens._select
	check(OnlineDuel.after == "", "la accion se consume una sola vez")
	check(is_instance_valid(again) and again.same_game and again.mode == "guante" and not again._tabs.visible, "«Otro nivel»: niveles del mismo minijuego, sin cambiar de juego")
	check(String(o.local._db["match"]["status"]) == "active" and o.local._db["match"]["bot"]["name"] == r["data"]["opponent"]["name"], "revancha con el mismo bot")
	cleanup()

## Rescate online: los dos el mismo nivel; el servidor recalcula el puntaje con tiempo, errores y caidas, y rechaza un
## tiempo imposible (menos que lo que permite la fisica del nivel) o fuera del limite.
func test_online_rescue_is_validated_by_the_server() -> void:
	var o: Node = await _online()
	await o.call_fn("find_match", {"p_mode": "rescate", "p_fee": 0})
	o.local.clock_offset += 10.0
	var r: Dictionary = await o.call_fn("start_bot_match", {"p_mode": "rescate"})
	check(r["ok"], "partida de Rescate contra el bot")
	r = await o.call_fn("choose_minigame", {"p_match": "", "p_mode": "rescate", "p_level": 3})
	check(not r["ok"], "solo los niveles de mecanismos (el 3 es de patear)")
	r = await o.call_fn("choose_minigame", {"p_match": "", "p_mode": "rescate", "p_level": 8})
	check(r["ok"], "Rescate nivel 8 (Secuencia de colores)")
	var d: Dictionary = MinigameCatalog.level("rescate", 8)
	var fast_st := {"rescued": true, "time": float(d["min_time"]) * 0.5, "actions": 3, "errors": 0, "falls": 0, "attempts": 1}
	r = await o.call_fn("finish_minigame", {"p_match": "", "p_game": "rescate", "p_level": 8, "p_points": 9999, "p_bot_points": 100, "p_stats": fast_st})
	check(not r["ok"], "un tiempo menor que el que permite la fisica se rechaza")
	var st := {"rescued": true, "time": 12.4, "actions": 4, "errors": 1, "falls": 0, "attempts": 1}
	r = await o.call_fn("finish_minigame", {"p_match": "", "p_game": "rescate", "p_level": 8, "p_points": 9999, "p_bot_points": 100, "p_stats": st})
	var want: int = Rescate.score_for(st.merged({"time_limit": float(d["time"]), "shots": 0, "shots_max": 0}))
	note("puntaje del servidor: %d (el cliente dijo 9999; formula %d)" % [int(r["data"]["match"]["score_a"]), want])
	check(r["ok"] and int(r["data"]["match"]["score_a"]) == want, "el puntaje lo recalcula el servidor (no el que manda el cliente)")
	var res: Dictionary = r["data"]["match"]["minigame"]["result"]
	check(int(res["errors"]) == 1 and int(res["actions"]) == 4 and is_equal_approx(float(res["time"]), 12.4), "quedan registrados tiempo, acciones y errores")
	# El bot del Rescate se puntua con la misma formula y queda entre lo posible.
	var bp: int = OnlineDuel.bot_score("rescate", {"skill": 0.9, "seed": 4}, d)
	check(bp >= 50 and bp <= Rescate.score_for({"rescued": true, "time": float(d["min_time"]), "time_limit": float(d["time"])}), "puntaje del bot posible (%d)" % bp)
