class_name OnlineDuel
extends RefCounted
## Modalidades online contra BOT en todos los juegos (pedido del usuario, 2026-11-12: «déjame habilitado el online en
## todos los juegos; mientras tanto juego contra bots, y bots muy difíciles de ganar»).
##
## - Penales: la partida online de siempre (OnlineMatch, turnos del servidor).
## - A la vista (Botón de caída), Guante y Dardos (duelo): el minijuego por turnos contra la CPU, que ES el bot (su nombre
##   en el marcador), en dificultad Extremo.
## - Basket (Enceste), Diana (Diana gigante) y Tiros libres: duelo por puntaje. El usuario juega sus tiros y el bot tiene
##   su puntaje (lo «juega» BotBrain con su habilidad: los bots online son difíciles, habilidad >= HARD_SKILL).
## El premio pasa por la cola de recompensas (Online.queue_reward): el servidor recalcula montos y topes como siempre.
## Las partidas entre humanos de estas modalidades siguen en preparacion (el protocolo del servidor ya las admite).

## Habilidad minima de los bots online (0..1).
const HARD_SKILL := 0.88
## Dificultad de la IA en los minijuegos (la mas alta del arcade: Experto) y del arquero rival en el tiro libre online
## (SpSettings: 4 = Extremo).
const HARD_LEVEL := 3
const HARD_KEEPER := 4

## {mode, bot: {...}, kind: "turnos"|"puntos", shots, bot_points, user_points, game, level, match}
static var active: Dictionary = {}
## Ultimo minijuego online jugado (modalidad, juego, nivel, partida) y lo que eligio el usuario al terminar: «repeat»
## (repetir nivel), «level» (otro nivel del mismo minijuego), «game» (otro minijuego), «random» o «exit». El menu lo lee
## al volver (MenuScreens.resume_online_after). Nunca se salta solo a otro minijuego.
static var last: Dictionary = {}
static var after: String = ""

## Juego y nivel de cada modalidad online (las de penales no pasan por aca).
const MODES := {
	"tiros_libres": {"kind": "puntos", "shots": 5},
	"a_la_vista": {"kind": "turnos", "game": "boton_caida"},
	"guante": {"kind": "turnos", "game": "guante"},
	"dardos": {"kind": "turnos", "game": "dardos", "rule": "duelo"},
	"basket": {"kind": "puntos", "game": "enceste", "shots": 5},
	"diana": {"kind": "puntos", "game": "diana_gigante", "shots": 5},
}

static func is_active() -> bool:
	return not active.is_empty()

static func bot_name() -> String:
	return String((active.get("bot", {}) as Dictionary).get("name", "Bot"))

static func hard_skill(bot: Dictionary) -> Dictionary:
	var b: Dictionary = bot.duplicate()
	b["skill"] = maxf(float(b.get("skill", 0.5)), HARD_SKILL)
	return b

## Arranca una modalidad contra el bot de `view` (resultado de start_bot_match). Devuelve false si no hay juego.
static func start(tree: SceneTree, mode: String, view: Dictionary) -> bool:
	if not MODES.has(mode):
		return false
	var cfg: Dictionary = MODES[mode]
	var bot: Dictionary = hard_skill(view.get("opponent", {}) if view.get("opponent") is Dictionary else {})
	active = {"mode": mode, "bot": bot, "kind": String(cfg["kind"]), "shots": int(cfg.get("shots", 5)), "bot_points": -1,
		"user_points": 0, "view": view}
	if mode == "tiros_libres":
		active["bot_points"] = bot_score(mode, bot, {})
		SpSettings.override_difficulty = HARD_KEEPER
		SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK
		tree.change_scene_to_file(SetPieceGame.SCENE)
		return true
	var d: Dictionary = _level(String(cfg["game"]), String(cfg.get("rule", "")))
	if d.is_empty():
		active = {}
		return false
	d = MinigameCatalog.at_difficulty(d, HARD_LEVEL)
	d["online_bot"] = bot_name()
	if String(cfg["kind"]) == "puntos":
		active["bot_points"] = bot_score(mode, bot, d)
	MinigameCatalog.start(tree, d)
	return true

## Arranca el nivel `level_n` que eligio el usuario (o sorteo el servidor) en la partida `view` (choose_minigame ya lo
## valido y lo guardo). Devuelve false si el nivel no existe en el catalogo.
static func start_level(tree: SceneTree, mode: String, view: Dictionary, level_n: int) -> bool:
	if not MODES.has(mode):
		return false
	var cfg: Dictionary = MODES[mode]
	var game: String = String(cfg.get("game", ""))
	var d: Dictionary = MinigameCatalog.level(game, level_n)
	if d.is_empty():
		return false
	var bot: Dictionary = hard_skill(view.get("opponent", {}) if view.get("opponent") is Dictionary else {})
	active = {"mode": mode, "bot": bot, "kind": String(cfg["kind"]), "shots": int(cfg.get("shots", 5)), "bot_points": -1,
		"user_points": 0, "view": view, "game": game, "level": level_n,
		"match": String((view.get("match", {}) as Dictionary).get("id", ""))}
	last = {"mode": mode, "game": game, "level": level_n, "match": active["match"]}
	d = MinigameCatalog.at_difficulty(d, HARD_LEVEL)
	d["online_bot"] = bot_name()
	if String(cfg["kind"]) == "puntos":
		active["bot_points"] = bot_score(mode, bot, d)
	MinigameCatalog.start(tree, d)
	return true

## Primer nivel del juego (con la regla pedida, p. ej. el duelo de los dardos).
static func _level(game: String, rule: String) -> Dictionary:
	for d in MinigameCatalog.levels(game):
		if rule == "" or String((d as Dictionary).get("rule", "")) == rule:
			return d
	return {}

## Puntaje del bot en un duelo por puntos. Tiros libres: goles en 5 tiros con su habilidad. Minijuegos: en la escala del
## nivel (sus umbrales de medalla): un bot dificil queda entre la plata y algo mas que el oro.
static func bot_score(mode: String, bot: Dictionary, level_def: Dictionary) -> int:
	var brain := BotBrain.new(bot)
	if mode == "tiros_libres":
		var goals: int = 0
		for i in int(MODES[mode].get("shots", 5)):
			goals += 1 if brain.rng.randf() < lerpf(0.35, 0.75, brain.skill()) else 0
		return goals
	var m: Array = level_def.get("medals", [100, 200, 300])
	var silver: float = float(m[1])
	var top: float = float(m[2]) * 1.1
	return int(round(lerpf(silver, top, clampf(brain.skill() * brain.rng.randf_range(0.75, 1.1), 0.0, 1.0))))

## Fin de la partida: compara (o toma el ganador de la partida por turnos), entrega el premio por la cola de recompensas
## y devuelve [titulo, detalle]. Deja el duelo cerrado.
static func finish(user_points: int, user_won_turns: int = -1) -> Array:
	var won: bool
	var detail: String
	if String(active.get("kind", "")) == "turnos":
		won = user_won_turns == 1
		detail = "Contra %s (bot online)" % bot_name()
	else:
		var bp: int = int(active.get("bot_points", 0))
		won = user_points > bp
		detail = "Vos %d - %d %s (bot online)" % [user_points, bp, bot_name()]
	# El resultado va al servidor, que solo lo acepta del minijuego y nivel elegidos (finish_minigame).
	if String(active.get("match", "")) != "":
		var bot_pts: int = int(active.get("bot_points", 0)) if String(active.get("kind", "")) == "puntos" else (0 if won else 1)
		var my_pts: int = user_points if String(active.get("kind", "")) == "puntos" else (1 if won else 0)
		Online.call_fn("finish_minigame", {"p_match": active["match"], "p_game": active.get("game", ""),
			"p_level": int(active.get("level", 0)), "p_points": my_pts, "p_bot_points": bot_pts})
	# Contra bot: el premio de una partida offline (el servidor lo recalcula con sus topes; no da ranking).
	Online.queue_reward("offline_match", {"won": won, "vs_bot": true, "mode": String(active.get("mode", "")),
		"game": String(active.get("game", "")), "level": int(active.get("level", 0))})
	active = {}
	SpSettings.override_difficulty = -1
	return ["¡GANASTE ONLINE!" if won else "PERDISTE ONLINE", detail]
