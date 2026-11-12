extends TestCase
## Online en todos los juegos contra bots dificiles (pedido del usuario, 2026-11-12): cada modalidad online tiene su
## juego, los bots online tienen habilidad alta, el duelo por puntos compara con el puntaje del bot y el resultado queda
## cerrado (premio por la cola de recompensas).

func test_every_online_mode_is_playable() -> void:
	for m in MenuScreens.READY_ONLINE:
		if m == "penales":
			continue
		check(OnlineDuel.MODES.has(m), "%s: tiene juego contra bot" % m)
		var cfg: Dictionary = OnlineDuel.MODES[m]
		if cfg.has("game"):
			var d: Dictionary = OnlineDuel._level(String(cfg["game"]), String(cfg.get("rule", "")))
			check(not d.is_empty() and ResourceLoader.exists(String(d["scene"])), "%s: nivel %s (%s)" % [m, d.get("title", "?"), d.get("scene", "?")])
	var seed: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/online/seed.json"))["game_modes"]
	for gm in seed:
		check(MenuScreens.READY_ONLINE.has(String(gm["id"])), "la modalidad %s se puede jugar (no queda «en preparación»)" % gm["id"])

func test_online_bots_are_hard() -> void:
	var easy := BotBrain.new({"name": "Facil", "skill": 0.1, "personality": "equilibrado", "seed": 3})
	check(easy.skill() >= OnlineDuel.HARD_SKILL, "un bot online nunca es facil (habilidad %.2f)" % easy.skill())
	var d: Dictionary = OnlineDuel._level("diana_gigante", "")
	var scores: Array = []
	for i in 20:
		scores.append(OnlineDuel.bot_score("diana", {"skill": 0.5, "seed": i}, d))
	var m: Array = d["medals"]
	scores.sort()
	note("puntajes del bot en la Diana gigante: %s (medallas %s)" % [str(scores), str(m)])
	check(int(scores[0]) >= int(m[1]) * 0.7, "el bot dificil suele andar cerca de la plata o mas")
	check(int(scores[scores.size() - 1]) <= int(round(float(m[2]) * 1.1)) + 1, "y no pasa el oro + 10 %")
	var goals: int = OnlineDuel.bot_score("tiros_libres", {"skill": 0.5, "seed": 7}, {})
	check(goals >= 0 and goals <= 5, "tiros libres: goles del bot de 0 a 5 (%d)" % goals)

func test_points_duel_compares_with_the_bot_and_closes() -> void:
	OnlineDuel.active = {"mode": "basket", "bot": {"name": "Tito"}, "kind": "puntos", "shots": 5, "bot_points": 120}
	var r: Array = OnlineDuel.finish(150)
	check(String(r[0]).begins_with("¡GANASTE"), "150 contra 120: gana el usuario")
	check(String(r[1]).contains("Tito") and String(r[1]).contains("150 - 120"), "muestra el marcador contra el bot (%s)" % r[1])
	check(not OnlineDuel.is_active(), "el duelo queda cerrado")
	OnlineDuel.active = {"mode": "guante", "bot": {"name": "Lola"}, "kind": "turnos", "shots": 5, "bot_points": -1}
	r = OnlineDuel.finish(0, 0)
	check(String(r[0]).begins_with("PERDISTE"), "por turnos manda el ganador de la partida")
	check(SpSettings.override_difficulty == -1, "la dificultad forzada vuelve a la normal")
