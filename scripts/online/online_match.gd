class_name OnlineMatch
extends Node
## Partida online de penales o de tiros libres por turnos sobre SetPieceGame (misma fisica, mismo gesto, mismo arquero;
## en los tiros libres, con barrera, desde el punto de tiro que fija el servidor para cada ronda). El SERVIDOR manda:
##  - turnos (quien patea), plazo de 20 s por tiro (mas margen de red), resultado de cada tiro: el tirador informa donde
##    cruza su tiro (zona de KeeperZones, prevista con la trayectoria real del golpe) y el servidor aplica la regla de
##    zonas con la eleccion OCULTA del arquero (si coinciden, atajada);
##  - premios, estadisticas y ranking al final (una sola vez).
## Rival bot (generado por el servidor): decide con BotBrain (sin conocer el tiro), patea con el mismo modelo de tiro,
## tarda como el usuario (BehaviorMirror) y reacciona en el chat segun su personalidad. Rival humano: su eleccion de zona
## y su tiro llegan del servidor (se consulta cada POLL_S) y el tiro se reproduce con sus mismos parametros.
## Sin tirar a tiempo: tiro automatico de penalizacion (alto e impreciso) que el servidor cuenta como errado.

## Vista de la partida que dejo el lobby al emparejar (find_match / start_bot_match).
static var pending: Dictionary = {}

const TURN_S := 20.0
const WARN_S := 5.0
const POLL_S := 1.5

var game: SetPieceGame
var view: Dictionary
var my_side: int = 0
var opp: Dictionary = {}
var brain: BotBrain = null
var mirror := BehaviorMirror.new()
var rng := RandomNumberGenerator.new()
var clock: float = TURN_S
var clock_on: bool = false
var timed_out: bool = false
var _aim_started: float = 0.0
var _outcome: String = ""
var _bot_shot_in: float = -1.0
var _poll_t: float = 0.0
var _waiting_remote: bool = false
var _remote_seen: int = -1
var finished: bool = false
var coins_before: int = 0
var xp_before: int = 0
var _clock_label: Label
var _opp_label: Label
var _chat_box: VBoxContainer
var _quick: HFlowContainer

func setup(g: SetPieceGame, v: Dictionary) -> void:
	game = g
	view = v
	my_side = int(v.get("my_side", 0))
	opp = v.get("opponent", {}) if v.get("opponent") is Dictionary else {}
	if bool(opp.get("is_bot", false)):
		brain = BotBrain.new(opp)
	rng.seed = int(opp.get("seed", 1)) + 17
	coins_before = Online.coins()
	xp_before = int(Online.profile().get("xp", 0))

func is_bot() -> bool:
	return brain != null

func match_id() -> String:
	return String((view.get("match", {}) as Dictionary).get("id", ""))

func server_match() -> Dictionary:
	return view.get("match", {}) if view.get("match") is Dictionary else {}

## Le toca patear al usuario (segun el servidor).
func my_shot() -> bool:
	return int(server_match().get("shooter", 0)) == my_side

## Tiros libres: desplazamiento de los puntos de tiro de esta partida (lo sortea el servidor) y ronda actual (los dos
## patean desde el mismo punto: ronda = tiro / 2).
func spot_offset() -> int:
	return int(server_match().get("spot_offset", 0))

func fk_round() -> int:
	return int(server_match().get("shot_n", 0)) / 2

func _free_kick() -> bool:
	return game != null and game.mode == SetPieceGame.Mode.FREE_KICK

## Punto de tiro del turno (distancia, ancho) para que el servidor lo compare con el suyo.
func _spot_payload() -> Dictionary:
	if not _free_kick():
		return {}
	return {"spot": [snappedf(game.gx - game.ball_spot.x, 0.01), snappedf(game.ball_spot.z, 0.01)]}

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_clock_label = Label.new()
	_clock_label.position = Vector2(560, 92)
	_clock_label.add_theme_font_size_override("font_size", 40)
	_clock_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_clock_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_clock_label)
	_opp_label = Label.new()
	_opp_label.position = Vector2(24, 120)
	_opp_label.add_theme_font_size_override("font_size", 22)
	_opp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_opp_label.add_theme_constant_override("outline_size", 6)
	_opp_label.text = "Rival: %s · Nivel %d" % [opp.get("name", opp.get("display_name", "Rival")), int(opp.get("level", 1))]
	layer.add_child(_opp_label)
	_chat_box = VBoxContainer.new()
	_chat_box.position = Vector2(24, 160)
	_chat_box.custom_minimum_size = Vector2(420, 0)
	layer.add_child(_chat_box)
	_quick = HFlowContainer.new()
	_quick.position = Vector2(24, 560)
	_quick.custom_minimum_size = Vector2(560, 0)
	layer.add_child(_quick)
	for k in ["buen_tiro", "que_atajada", "casi", "vamos"]:
		_quick_btn(ChatFilter.QUICK[k], "quick", k)
	for e in [["JAJA", "😂"], ["WOW", "😮"], ["GG", "👏"], ["FUEGO", "🔥"]]:
		_quick_btn(e[0], "emote", e[1])

func _quick_btn(text: String, kind: String, body: String) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(func() -> void: send_chat(kind, body, text))
	_quick.add_child(b)

## Mensaje del usuario (el servidor limita frecuencia y filtra). Las reacciones se ven como globos breves.
func send_chat(kind: String, body: String, shown: String) -> void:
	var r: Dictionary = await Online.call_fn("send_chat", {"p_match": match_id(), "p_kind": kind, "p_body": body})
	if r.get("ok", false):
		bubble("Vos: " + shown, Color(0.6, 0.85, 1.0))
	else:
		bubble(String(r.get("error", "")), Color(1.0, 0.6, 0.5))

func bubble(text: String, col: Color) -> void:
	if text == "":
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	_chat_box.add_child(l)
	while _chat_box.get_child_count() > 4:
		_chat_box.get_child(0).queue_free()
		_chat_box.remove_child(_chat_box.get_child(0))
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

func bot_says(context: String) -> void:
	if brain != null and rng.randf() < 0.7:
		bubble("%s: %s" % [opp.get("name", "Rival"), ChatFilter.bot_line(context, String(opp.get("personality", "")), rng)], Color(1.0, 0.85, 0.4))

# --- Turnos ---------------------------------------------------------------------------------------------------------

## Empieza un turno: el reloj de 20 s corre para el usuario (patea o elige donde tirarse).
func on_turn_start(user_shooting: bool) -> void:
	clock = TURN_S
	clock_on = true
	timed_out = false
	_aim_started = Time.get_ticks_msec() / 1000.0
	_outcome = ""
	_bot_shot_in = -1.0
	_waiting_remote = false

func _process(delta: float) -> void:
	if finished:
		return
	if clock_on:
		clock -= delta
		_clock_label.text = "%d" % int(ceil(maxf(clock, 0.0)))
		_clock_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if clock <= WARN_S else Color(1, 1, 1))
		if clock <= 0.0:
			clock_on = false
			_on_time_up()
	else:
		_clock_label.text = ""
	if _bot_shot_in >= 0.0:
		_bot_shot_in -= delta
		if _bot_shot_in < 0.0:
			_bot_shoot()
	if _waiting_remote:
		_poll_t -= delta
		if _poll_t <= 0.0:
			_poll_t = POLL_S
			_poll_remote()

func _on_time_up() -> void:
	if game.phase == SetPieceGame.Phase.AIM and game.user_shooting:
		timed_out = true
		game.hud.set_hint("¡Se terminó el tiempo! Tiro de penalización.")
		game.shoot_params(penalty_shot())
	elif game.phase == SetPieceGame.Phase.KEEPER_PICK and game._keeper_zone == Vector3.INF:
		# No eligio: se queda en el medio.
		game._keeper_zone = Vector3(game.gx, 1.0, 0.0)

## Tiro automatico por tiempo: alto y con poca precision (no beneficia al jugador).
func penalty_shot() -> ShotParams:
	var p := ShotParams.new()
	p.target = Vector3(game.gx, game.goal_h + rng.randf_range(0.6, 1.4), rng.randf_range(-3.0, 3.0))
	p.power = 0.5
	var sp: Vector2 = SetPieceGame.FK_SPEED if _free_kick() else SetPieceGame.PEN_SPEED
	p.speed = lerpf(sp.x, sp.y, 0.5)
	p.kind = ShotCatalog.Kind.NORMAL
	p.gesture_type = "normal"
	p.error_deg = 6.0
	p.direction = Vector3(p.target.x - game.ball_spot.x, 0, p.target.z - game.ball_spot.z).normalized()
	GestureShotModel.solve(p, game.ball_spot, game.shot_context(), false)
	return p

## El usuario solto el tiro: el bot (si es arquero) elige zona sin conocer el tiro, y se informa al servidor donde cruza
## el tiro real; el servidor devuelve el resultado con la regla de zonas. El arquero visible se juega a esa zona.
func on_user_shot(cross: Vector3, cls: String) -> void:
	clock_on = false
	mirror.observe(Time.get_ticks_msec() / 1000.0 - _aim_started)
	var kz: int = -1
	if is_bot():
		var dir: Vector3 = game.last_shot.get("dir", Vector3(1, 0, 0))
		var cue: Vector3 = game.ball_spot + dir * ((game.gx - game.ball_spot.x) / maxf(dir.x, 0.2))
		# Altura que «lee»: abajo, al medio o arriba (los tres niveles de sectores).
		var hr: float = rng.randf()
		cue.y = 0.4 if hr < 0.45 else (1.2 if hr < 0.75 else 2.0)
		kz = brain.keeper_zone(KeeperZones.zone_of(Vector3(game.gx, cue.y, clampf(cue.z, -3.5, 3.5)), game.half_goal, game.goal_h))
		await Online.call_fn("submit_turn", {"p_match": match_id(), "p_kind": "keeper_pick", "p_payload": {"zone": kz}, "p_side": 1 - my_side})
	var cz: int = KeeperZones.zone_of(cross, game.half_goal, game.goal_h)
	var pl: Dictionary = {"cross_zone": cz, "outcome": predicted(cls), "timed_out": timed_out,
		"speed": (game.last_shot.get("velocity", Vector3.ZERO) as Vector3).length(),
		"target": [game.last_params.target.x, game.last_params.target.y, game.last_params.target.z],
		"power": game.last_params.power, "spin": game.last_params.lateral_spin}
	pl.merge(reach_payload(cross))
	pl.merge(_spot_payload())
	var r: Dictionary = await Online.call_fn("submit_turn", {"p_match": match_id(), "p_kind": "shot", "p_payload": pl})
	_take_view(r)
	var shot: Dictionary = _last_turn("shot")
	_outcome = String((shot.get("payload", {}) as Dictionary).get("outcome", ""))
	var z: Variant = (shot.get("payload", {}) as Dictionary).get("keeper_zone", null)
	if z == null and kz >= 0:
		z = kz
	if z != null and int(z) >= 0:
		game.cur_keeper.commit_to(KeeperZones.center(int(z), game.gx, game.half_goal, game.goal_h), game.ball_spot,
			maxf(game.cur_shooter.time_to_contact(), 0.0), (game.last_shot.get("velocity", Vector3.ZERO) as Vector3).length())

## Datos del cruce para la regla de alcance del servidor (KeeperReach con las mismas constantes): donde cruza la linea
## (alto y ancho) y cuanto tarda la pelota desde el golpe (trayectoria real, con su efecto).
func reach_payload(cross: Vector3) -> Dictionary:
	if cross == Vector3.INF:
		return {}
	var traj: PackedVector3Array = game.last_shot.get("traj", PackedVector3Array())
	var t: float = KeeperReach.time_to_line(traj, 1.0 / 60.0, game.gx)
	var out := {"cross_y": snappedf(cross.y, 0.001), "cross_z": snappedf(cross.z, 0.001)}
	if t != INF:
		out["flight"] = snappedf(t, 0.001)
	return out

## El usuario eligio donde tirarse: se manda (queda oculta para el rival) y despues patea el rival.
func on_user_keeper_pick(zone_point: Vector3) -> void:
	clock_on = false
	var kz: int = KeeperZones.zone_of(zone_point, game.half_goal, game.goal_h)
	await Online.call_fn("submit_turn", {"p_match": match_id(), "p_kind": "keeper_pick", "p_payload": {"zone": kz}})
	if is_bot():
		_bot_shot_in = mirror.bot_delay() * 0.35
	else:
		_waiting_remote = true
		_poll_t = 0.0
		game.hud.set_hint("Esperando el tiro del rival…")

func _bot_shoot() -> void:
	if _free_kick():
		# Tiro libre del bot: el mismo tirador de la CPU (sin saber el sector del usuario), con el error de su habilidad.
		game._take_shot(game.cpu_shooter, game.cpu_free_kick_params(), brain.aim_error_deg())
		await _send_bot_shot()
		return
	var p := ShotParams.new()
	p.target = brain.penalty_target(game.gx, game.half_goal, game.goal_h)
	p.power = brain.shot_power()
	p.speed = lerpf(SetPieceGame.PEN_SPEED.x, SetPieceGame.PEN_SPEED.y, p.power)
	p.lateral_spin = rng.randf_range(-6.0, 6.0)
	p.spin = Vector3(0.0, p.lateral_spin, 0.0)
	p.kind = ShotCatalog.Kind.POWER if p.power > 0.7 else ShotCatalog.Kind.NORMAL
	p.gesture_type = "potente_raso" if p.power > 0.7 and p.target.y < 0.9 else "colocado"
	p.direction = Vector3(p.target.x - game.ball_spot.x, 0.0, p.target.z - game.ball_spot.z).normalized()
	GestureShotModel.solve(p, game.ball_spot, game.shot_context(), false)
	game._take_shot(game.cpu_shooter, p, brain.aim_error_deg())
	await _send_bot_shot()

## Informa el tiro del bot (con el cruce y el punto de tiro, como el de un jugador) y toma el resultado del servidor.
func _send_bot_shot() -> void:
	var bc: Vector3 = game.last_shot.get("cross", Vector3.INF)
	var cz: int = KeeperZones.zone_of(bc, game.half_goal, game.goal_h)
	var cls: String = String(game.last_shot.get("class", ""))
	var bpl: Dictionary = {"cross_zone": cz, "outcome": predicted(cls)}
	bpl.merge(reach_payload(bc))
	bpl.merge(_spot_payload())
	var r: Dictionary = await Online.call_fn("submit_turn", {"p_match": match_id(), "p_kind": "shot",
		"p_payload": bpl, "p_side": 1 - my_side})
	_take_view(r)
	_outcome = String((_last_turn("shot").get("payload", {}) as Dictionary).get("outcome", ""))

## Rival humano: cuando llega su tiro, se reproduce con sus mismos parametros (destino, potencia, efecto).
func _poll_remote() -> void:
	var r: Dictionary = await Online.call_fn("get_match", {"p_match": match_id()})
	if not r.get("ok", false):
		return
	_take_view(r)
	for c in r["data"].get("chat", []):
		if int(c.get("id", 0)) > _remote_seen and String(c.get("who", "")) == "rival":
			_remote_seen = int(c["id"])
			bubble("%s: %s" % [opp.get("display_name", "Rival"), ChatFilter.QUICK.get(String(c["body"]), String(c["body"]))], Color(1.0, 0.85, 0.4))
	var shot: Dictionary = _last_turn("shot")
	if shot.is_empty() or int(shot["side"]) == my_side or int(shot["shot_n"]) != int(server_match().get("shot_n", 0)) - 1:
		return
	_waiting_remote = false
	var pl: Dictionary = shot["payload"]
	_outcome = String(pl.get("outcome", ""))
	var p := ShotParams.new()
	var t: Array = pl.get("target", [game.gx, 1.0, 0.0])
	p.target = Vector3(float(t[0]), float(t[1]), float(t[2]))
	p.power = float(pl.get("power", 0.6))
	p.speed = float(pl.get("speed", 22.0))
	p.lateral_spin = float(pl.get("spin", 0.0))
	p.spin = Vector3(0.0, p.lateral_spin, 0.0)
	p.direction = Vector3(p.target.x - game.ball_spot.x, 0.0, p.target.z - game.ball_spot.z).normalized()
	GestureShotModel.solve(p, game.ball_spot, game.shot_context(), false)
	game._take_shot(game.cpu_shooter, p, 0.0)

## Resultado previsto por la trayectoria real del golpe (ShotSolver.classify): adentro = gol (el servidor aplica la
## regla de zonas), al palo, o afuera.
static func predicted(cls: String) -> String:
	return {"in": "goal", "post": "post"}.get(cls, "miss")

## El servidor ya dio la partida por terminada (gano alguien o se llego al tope de tiros).
func server_done() -> bool:
	return String(server_match().get("status", "active")) != "active"

## Ganador segun el servidor: true si gano el usuario, false si perdio, null si fue empate.
func server_user_won() -> Variant:
	var w: Variant = server_match().get("winner", null)
	return null if w == null else int(w) == my_side

func _take_view(r: Dictionary) -> void:
	if r.get("ok", false) and r.get("data") is Dictionary and (r["data"] as Dictionary).has("match"):
		view = r["data"]

func _last_turn(kind: String) -> Dictionary:
	var out: Dictionary = {}
	for t in view.get("turns", []):
		if String(t.get("kind", "")) == kind:
			out = t
	return out

## Resultado del tiro segun el servidor (manda sobre lo que vio la fisica local, que deberia coincidir).
func outcome_for(local_why: String) -> String:
	if _outcome == "":
		return local_why
	var o: String = _outcome
	_outcome = ""
	if o == "miss" and local_why in ["post", "wall"]:
		return local_why
	return o

func after_result(why: String, user_was_shooting: bool) -> void:
	if user_was_shooting:
		bot_says({"goal": "user_goal", "save": "bot_saved", "post": "user_near_miss"}.get(why, "user_miss"))
	else:
		bot_says({"goal": "bot_goal", "save": "user_saved"}.get(why, "user_miss"))

## Fin: el servidor ya liquido (premios una sola vez). Se muestra lo ganado.
func on_end(user_won: bool) -> void:
	finished = true
	clock_on = false
	bot_says("user_won" if user_won else "user_lost")
	await Online.refresh_state()
	var dc: int = Online.coins() - coins_before
	var dx: int = int(Online.profile().get("xp", 0)) - xp_before
	game.hud.set_hint("Partida online terminada: %+d monedas · %+d XP" % [dc, dx])
	pending = {}
