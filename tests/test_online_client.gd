extends TestCase
## Cliente online (sin servidor real: LocalBackend con la misma API que las funciones de Supabase): cuentas y sesion,
## perfil, premios con cola de sincronizacion idempotente (tambien sin conexion), tienda y consumibles, partida contra
## bot con turnos y regla de zonas, bots con personalidad y dificultad adaptativa, comportamiento espejo, chat.

const DIR := "user://test_online"

func _fresh() -> Node:
	var online: Node = tree.root.get_node("Online")
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/" + f))
	online.use_local(DIR)
	return online

func test_accounts_session_and_passwords() -> void:
	var o: Node = _fresh()
	var r: Dictionary = await o.sign_up("no-es-correo", "12345678")
	check(not r["ok"] and String(r["error"]).contains("correo"), "correo invalido rechazado")
	r = await o.sign_up("pibe@futbol.com", "corta")
	check(not r["ok"] and String(r["error"]).contains("8"), "contraseña corta rechazada")
	r = await o.sign_up("pibe@futbol.com", "golazo123")
	check(r["ok"] and o.signed_in() and not o.has_profile(), "cuenta creada y sesion iniciada, falta el perfil")
	r = await o.sign_up("pibe@futbol.com", "otra12345")
	check(not r["ok"] and String(r["error"]).contains("Ya existe"), "no hay dos cuentas con el mismo correo")
	var acc: String = FileAccess.get_file_as_string(DIR + "/accounts.json")
	check(not acc.contains("golazo123"), "la contraseña no se guarda en texto plano")
	var ses: PackedByteArray = FileAccess.get_file_as_bytes(DIR + "/session.dat")
	check(ses.size() > 0 and not ses.get_string_from_utf8().contains("access_token"), "la sesion recordada se guarda cifrada")
	await o.sign_out()
	check(not o.signed_in(), "cerrar sesion")
	r = await o.sign_in("pibe@futbol.com", "mala1234")
	check(not r["ok"] and String(r["error"]).contains("incorrectos"), "contraseña incorrecta")
	r = await o.sign_in("PIBE@futbol.com ", "golazo123")
	check(r["ok"], "iniciar sesion (el correo no distingue mayusculas)")
	check(await o.restore_session(), "recordar sesion: se renueva al abrir")
	check(not (await o.recover("pibe@futbol.com"))["ok"], "sin servidor, la recuperacion avisa que no puede mandar correos")
	check(not BackendConfig.is_configured({"url": "https://x.supabase.co", "anon_key": "sb_secret_abcdefghijklmnopqrstuvwxyz"}),
		"una clave de servicio en el cliente se rechaza")
	check(BackendConfig.is_configured({"url": "https://x.supabase.co", "anon_key": "sb_publishable_abcdefghijklmnopqrstu"}),
		"la clave publica si")
	cleanup()

func _player(o: Node) -> void:
	await o.sign_up("jugador@futbol.com", "golazo123")
	var r: Dictionary = await o.call_state_fn("create_profile", {"p_username": "Crack_10", "p_display_name": "Crack"})
	check(r["ok"] and o.coins() == 500, "perfil creado con 500 monedas de bienvenida")

func test_rewards_queue_is_idempotent_and_survives_offline() -> void:
	var o: Node = _fresh()
	await _player(o)
	o.local.simulate_offline = true
	o.queue_reward("arcade", {"medal": 3, "xp": 99999})
	await tree.process_frame
	check(o.queue.size() == 1, "sin conexion el premio queda en la cola")
	check(FileAccess.get_file_as_string(DIR + "/sync_queue.json").contains("arcade"), "y la cola se guarda en el dispositivo")
	o.local.simulate_offline = false
	await o.flush()
	check(o.queue.is_empty(), "con conexion la cola se vacia")
	check(o.coins() == 555 and int(o.profile()["xp"]) == 95, "premio calculado por el servidor, no por el cliente (%d monedas, %d XP)" % [o.coins(), int(o.profile()["xp"])])
	# La misma operacion enviada dos veces (reintento tras un corte): una sola vez.
	var op: Dictionary = {"fn": "claim_reward", "args": {"p_idem": "arcade-repetido-001", "p_source": "arcade", "p_payload": {"medal": 1}}}
	o.queue.append(op.duplicate(true))
	o.queue.append(op.duplicate(true))
	await o.flush()
	check(o.coins() == 555 + 25, "reintento con la misma clave: se cobra una sola vez")
	cleanup()

func test_shop_appearance_and_consumables() -> void:
	var o: Node = _fresh()
	await _player(o)
	var r: Dictionary = await o.call_state_fn("buy_item", {"p_item": "jersey_liso", "p_idem": "buy-test-0001"})
	check(not r["ok"], "lo gratuito no se compra")
	r = await o.call_state_fn("buy_item", {"p_item": "energizante_monedas", "p_idem": "buy-test-0002"})
	check(r["ok"] and o.coins() == 200 and o.owns("energizante_monedas"), "compra con monedas virtuales")
	r = await o.call_state_fn("buy_item", {"p_item": "jersey_degradado", "p_idem": "buy-test-0003"})
	check(not r["ok"] and String(r["error"]).contains("insuficientes"), "sin saldo no se compra")
	r = await o.call_state_fn("update_appearance", {"p_appearance": {"ball": "ball_llamas"}})
	check(not r["ok"], "no se equipa un balon que no se tiene")
	r = await o.call_state_fn("update_appearance", {"p_appearance": {"ball": "ball_moderno", "jersey_color": 4}})
	check(r["ok"] and String(o.profile()["appearance"]["ball"]) == "ball_moderno", "balon gratuito y color libre equipados")
	r = await o.call_state_fn("use_consumable", {"p_item": "energizante_monedas"})
	check(r["ok"] and (o.state["boosts"] as Array).size() == 1, "energizante activo")
	cleanup()

func test_bot_match_turns_zone_rule_and_rewards() -> void:
	var o: Node = _fresh()
	await _player(o)
	var r: Dictionary = await o.call_fn("find_match", {"p_mode": "penales", "p_fee": 50})
	check(r["ok"] and r["data"]["status"] == "searching", "primero se busca un humano")
	r = await o.call_fn("start_bot_match", {"p_mode": "penales"})
	check(not r["ok"], "el bot no aparece antes de la espera")
	o.local.clock_offset += 10.0
	r = await o.call_fn("start_bot_match", {"p_mode": "penales"})
	check(r["ok"] and bool(r["data"]["opponent"]["is_bot"]), "sin humanos: rival bot")
	var bot: Dictionary = r["data"]["opponent"]
	note("bot: %s, %s, habilidad %.2f, nivel %d" % [bot["name"], bot["personality"], float(bot["skill"]), int(bot["level"])])
	check(String(bot["personality"]) in BotFactory.PERSONALITIES and String(bot["name"]) != "", "el bot tiene nombre y personalidad")
	await o.refresh_state()
	check(o.coins() == 450, "entrada cobrada")
	# Tiro 0: patea el usuario; el bot (lado 1) eligio la zona 2. Un tiro a la zona 2 informado como gol es atajada.
	r = await o.call_fn("submit_turn", {"p_match": "", "p_kind": "keeper_pick", "p_payload": {"zone": 2}, "p_side": 1})
	r = await o.call_fn("submit_turn", {"p_match": "", "p_kind": "shot", "p_payload": {"cross_zone": 2, "outcome": "goal"}})
	check(int(r["data"]["match"]["score_a"]) == 0, "tiro a la zona del arquero: atajada aunque el cliente diga gol")
	var twice: Dictionary = await o.call_fn("submit_turn", {"p_match": "", "p_kind": "shot", "p_payload": {"cross_zone": 0, "outcome": "goal"}})
	check(not twice["ok"], "no se patea dos veces seguidas")
	# Se juega el resto: el usuario mete todo, el bot erra todo.
	var n: int = 0
	while String(r["data"]["match"]["status"]) == "active" and n < 30:
		var shooter: int = int(r["data"]["match"]["shooter"])
		var pl: Dictionary = {"cross_zone": 4, "outcome": "goal"} if shooter == 0 else {"cross_zone": -1, "outcome": "miss"}
		r = await o.call_fn("submit_turn", {"p_match": "", "p_kind": "shot", "p_payload": pl, "p_side": shooter})
		n += 1
	check(String(r["data"]["match"]["status"]) == "finished" and int(r["data"]["match"]["winner"]) == 0, "la partida termina y gana el usuario")
	await o.refresh_state()
	note("monedas tras ganar al bot con entrada 50: %d" % o.coins())
	check(o.coins() == 450 + 5 + 50 + 25 + 20, "premio contra bot: entrada devuelta y un extra moderado")
	cleanup()

## Regla de atajada del servidor con 9 sectores y alcance (igual que la funcion SQL de la migracion 20261113000006):
## sector correcto pero pegado al angulo = gol; sector correcto y al alcance = atajada; el sector informado no manda.
func test_the_server_rule_uses_nine_sectors_and_reach() -> void:
	var o: Node = _fresh()
	await _player(o)
	await o.call_fn("find_match", {"p_mode": "penales", "p_fee": 0})
	o.local.clock_offset += 10.0
	var r: Dictionary = await o.call_fn("start_bot_match", {"p_mode": "penales"})
	check(r["ok"], "partida contra el bot")
	var bad: Dictionary = await o.call_fn("submit_turn", {"p_match": "", "p_kind": "keeper_pick", "p_payload": {"zone": 9}, "p_side": 1})
	check(not bad["ok"], "no hay sector 9")
	# Tiro 0: patea el usuario. El bot se juega al angulo (8) y el tiro va ahi, fuera del alcance: gol.
	await o.call_fn("submit_turn", {"p_match": "", "p_kind": "keeper_pick", "p_payload": {"zone": 8}, "p_side": 1})
	r = await o.call_fn("submit_turn", {"p_match": "", "p_kind": "shot", "p_payload": {"cross_zone": 8, "outcome": "goal",
		"cross_y": 2.3, "cross_z": 3.4, "flight": 0.5}})
	check(int(r["data"]["match"]["score_a"]) == 1, "sector correcto pero pegado al angulo: gol")
	# Tiro 1: patea el bot; el usuario se juega arriba a la derecha (6) y el tiro va ahi, a su alcance: atajada.
	await o.call_fn("submit_turn", {"p_match": "", "p_kind": "keeper_pick", "p_payload": {"zone": 6}})
	r = await o.call_fn("submit_turn", {"p_match": "", "p_kind": "shot", "p_payload": {"cross_zone": 6, "outcome": "goal",
		"cross_y": 2.0, "cross_z": -2.0, "flight": 0.6}, "p_side": 1})
	check(int(r["data"]["match"]["score_b"]) == 0, "sector correcto y al alcance: atajada")
	# Tiro 2: el bot elige el centro; el usuario informa sector 4 pero el cruce es abajo a un palo: gol.
	await o.call_fn("submit_turn", {"p_match": "", "p_kind": "keeper_pick", "p_payload": {"zone": 4}, "p_side": 1})
	r = await o.call_fn("submit_turn", {"p_match": "", "p_kind": "shot", "p_payload": {"cross_zone": 4, "outcome": "goal",
		"cross_y": 0.4, "cross_z": -3.0, "flight": 0.6}})
	check(int(r["data"]["match"]["score_a"]) == 2, "el sector informado no manda: vale el cruce")
	# La regla del servidor y la del juego coinciden en todo el arco.
	var diff: int = 0
	for iy in 13:
		for iz in 19:
			var y: float = 0.1 + float(iy) * 0.19
			var z: float = -3.6 + float(iz) * 0.4
			for t in [0.3, 0.45, 0.7]:
				var rule: Dictionary = LocalBackend.keeper_rule({"cross_y": y, "cross_z": z, "flight": t})
				var pt := Vector3(0, y, z)
				if bool(rule["reachable"]) != KeeperReach.reachable(pt, 0.0, t + SpKeeper.PENALTY_ANTICIPATION) or int(rule["zone"]) != KeeperZones.zone_of(pt, 3.66, 2.44):
					diff += 1
	check(diff == 0, "servidor local y juego usan la misma regla (%d diferencias)" % diff)
	cleanup()

func test_bots_adapt_gradually_and_mirror_the_user() -> void:
	var s1: float = BotFactory.next_skill(5, 0.5, [1.0, 1.0, 1.0, 1.0, 1.0])
	var s2: float = BotFactory.next_skill(5, 0.5, [0.0, 0.0, 0.0, 0.0])
	note("habilidad tras 5 victorias: %.2f; tras 4 derrotas: %.2f" % [s1, s2])
	check(s1 > 0.5 and s1 <= 0.6 + 0.0001, "si el jugador gana, el bot sube de a poco (max +0,1)")
	check(s2 < 0.5 and s2 >= 0.4 - 0.0001, "si pierde, baja de a poco")
	var rng := RandomNumberGenerator.new()
	check(BotFactory.personality_for(0.1, rng) == "principiante" and BotFactory.personality_for(0.95, rng) == "experto", "personalidad acorde a la habilidad")
	var brain := BotBrain.new({"skill": 0.95, "personality": "experto", "seed": 3})
	var weak := BotBrain.new({"skill": 0.1, "personality": "principiante", "seed": 3})
	check(brain.aim_error_deg() > 0.3 and brain.aim_error_deg() < weak.aim_error_deg(), "el experto se equivoca menos pero nunca tira perfecto")
	var targets := {}
	for i in 12:
		targets[str(brain.penalty_target(52.5, 3.66, 2.44).snapped(Vector3.ONE * 0.5))] = true
	check(targets.size() >= 5, "no repite el mismo tiro (%d destinos distintos en 12)" % targets.size())
	var m := BehaviorMirror.new(5)
	for t in [4.0, 4.2, 3.8]:
		m.observe(t)
	var ds: Array = []
	for i in 20:
		ds.append(m.bot_delay())
	note("usuario ~4 s -> bot entre %.1f y %.1f s" % [ds.min(), ds.max()])
	check(ds.min() >= 4.5 and ds.max() <= 10.5, "si el usuario tarda 4 s, el bot tarda entre 5 y 10")
	var fast := BehaviorMirror.new(5)
	for t in [1.0, 1.2]:
		fast.observe(t)
	check(fast.bot_delay() < 3.5, "si el usuario patea rapido, el bot tambien")
	check(m.bot_delay() <= BehaviorMirror.TURN_LIMIT - 3.0, "siempre dentro del tiempo de turno")

func test_chat_filter_and_bot_reactions() -> void:
	check(not ChatFilter.clean("sos un pelotudo").contains("pelotudo"), "insultos filtrados")
	check(ChatFilter.clean("x".repeat(100)).length() == 60, "mensajes cortos (60)")
	var rng := RandomNumberGenerator.new()
	for ctx in ["user_miss", "user_near_miss", "user_goal", "user_great", "user_saved", "bot_goal", "bot_saved", "user_lost", "user_won"]:
		var line: String = ChatFilter.bot_line(ctx, "agresivo", rng)
		check(line != "" and ChatFilter.clean(line) == line, "reaccion del bot para %s sin insultos" % ctx)

func _press(root: Node, text: String) -> bool:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			(b as Button).pressed.emit()
			return true
	return false

func _fields(root: Node) -> Array:
	return root.find_children("*", "LineEdit", true, false).filter(func(e: LineEdit) -> bool: return not e.is_queued_for_deletion())

## La pantalla de bienvenida de verdad: crear cuenta, crear perfil y entrar (sin cambiar de escena en la prueba).
func test_welcome_screen_sign_up_and_profile() -> void:
	var o: Node = _fresh()
	var w: WelcomeScreen = (load(WelcomeScreen.SCENE) as PackedScene).instantiate()
	w.go_to_menu = false
	spawn(w)
	await physics_frames(5)
	check(_press(w, "Crear cuenta"), "hay boton para crear cuenta")
	await physics_frames(2)
	var f: Array = _fields(w)
	check(f.size() == 2, "pide correo y contraseña")
	(f[0] as LineEdit).text = "nuevo@futbol.com"
	(f[1] as LineEdit).text = "golazo123"
	var done := [false]
	w.finished.connect(func() -> void: done[0] = true)
	_press(w, "CREAR CUENTA")
	await physics_frames(5)
	f = _fields(w)
	check(o.signed_in() and f.size() == 2, "cuenta creada: ahora pide el perfil")
	(f[0] as LineEdit).text = "a"
	(f[1] as LineEdit).text = "Nuevo"
	_press(w, "EMPEZAR")
	await physics_frames(3)
	check(not done[0] and w._error.text != "", "nombre de usuario invalido: avisa el error (%s)" % w._error.text)
	(f[0] as LineEdit).text = "Nuevo_9"
	_press(w, "EMPEZAR")
	await physics_frames(3)
	check(done[0] and o.has_profile() and String(o.profile()["username"]) == "Nuevo_9", "perfil creado y entra al juego")
	cleanup()
	# Al volver a abrir con la sesion recordada entra directo.
	var w2: WelcomeScreen = (load(WelcomeScreen.SCENE) as PackedScene).instantiate()
	w2.go_to_menu = false
	var done2 := [false]
	w2.finished.connect(func() -> void: done2[0] = true)
	spawn(w2)
	await physics_frames(8)
	check(done2[0], "con la sesion recordada entra sin pedir datos")
	cleanup()
