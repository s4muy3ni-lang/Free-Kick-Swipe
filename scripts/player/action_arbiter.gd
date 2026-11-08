class_name ActionArbiter
extends RefCounted
## Arbitro de acciones de un futbolista (modo 4): la UNICA autoridad que decide que accion controla el cuerpo y la pose
## en cada momento. Los sistemas que piden acciones (PlayerActions, BallHandler, Footballer) no se pisan entre si: piden
## aqui, con un nivel de prioridad, y reciben un testigo (token) con el que luego liberan; un testigo viejo ya no hace nada.
##
## Canales:
##  - Cuerpo: por defecto lo mueve Locomotion (sin pedir nada). Las acciones con raiz (PlayerActions: caidas, barridas,
##    giros, movimientos con pelota, balones parados) lo toman mientras duran; el golpeo comparte el cuerpo con Locomotion
##    (solo ajusta la zancada).
##  - Pose: la ranura unica de acciones de FootballerVisual (PackShot). Siempre la ocupa la accion vigente; la marcha va
##    por debajo y no se pide.
## Reglas:
##  - Solo un nivel ESTRICTAMENTE mayor interrumpe a la accion vigente; con igual o menor nivel la solicitud se rechaza
##    (la que ya corre se completa: el resultado no depende del orden en que se piden dentro de una misma imagen).
##  - La accion interrumpida se corta del todo (raiz, encadenados, movimiento con pelota, golpeo, pose): nada cancelado
##    sigue moviendo al jugador.
##  - Una accion terminada no bloquea: si su dueno ya no la sostiene (raiz acabada, golpeo resuelto y pose terminada), el
##    arbitro la da por caducada en la siguiente consulta.
##  - Las poses EN EL SITIO (gestos, reacciones) solo empiezan si el cuerpo no corre mas que el propio clip
##    (+ IN_PLACE_SLACK m/s): si no, el jugador se deslizaria con las piernas quietas.

enum Level { NONE = 0, GESTURE = 10, OVERLAY = 20, BALL_MOVE = 40, KICK = 50, BODY = 60, SET_PIECE = 70, FALL = 80 }

## Nivel de cada tipo de accion de PlayerActions (PlayerActions.kind).
const ACTION_LEVELS := {
	&"ball_move": Level.BALL_MOVE,
	&"turn": Level.BODY, &"slide": Level.BODY, &"skill": Level.BODY, &"stumble": Level.BODY, &"chain": Level.BODY,
	&"set_piece": Level.SET_PIECE,
	&"fall": Level.FALL, &"down": Level.FALL, &"pain": Level.FALL, &"getup": Level.FALL,
}
## Niveles cuyo dueno es PlayerActions (mueven el cuerpo con la raiz del clip).
const ROOT_LEVELS: Array[int] = [Level.BALL_MOVE, Level.BODY, Level.SET_PIECE, Level.FALL]
## Margen (m/s) entre la velocidad del cuerpo y la del propio clip para una pose en el sitio (= Footballer.SLIDE_CUT_SPEED).
const IN_PLACE_SLACK := 1.8
## Entradas del registro de decisiones que se guardan (diagnostico).
const LOG_MAX := 48

var owner: Footballer
## Accion vigente: tipo, nivel, quien la pidio, clip de la pose y testigo.
var kind: StringName = &""
var level: int = Level.NONE
var source: StringName = &""
var clip: StringName = &""
var token: int = 0
var _next_token: int = 1
## Ultimas decisiones («f<imagen> ACEPTADA/RECHAZADA ...») para diagnosticar por que una accion entro o no.
var log: Array[String] = []
var stats := {"aceptadas": 0, "rechazadas": 0, "interrumpidas": 0, "liberadas": 0, "caducadas": 0, "obsoletas": 0, "reinicios": 0}

func _init(o: Footballer) -> void:
	owner = o

static func level_for_action(k: StringName) -> int:
	return int(ACTION_LEVELS.get(k, Level.BODY))

## Nivel vigente. Si el dueno ya no sostiene la accion (termino o la corto otro sistema) se libera aqui.
func current_level() -> int:
	if level != Level.NONE and not _alive():
		_clear("caducada", "caducadas")
	return level

## true si se puede empezar ahora una accion de ese nivel (sin efectos). in_place_clip: pose en el sitio a comprobar.
func can_start(lv: int, in_place_clip: StringName = &"") -> bool:
	return _verdict(lv, in_place_clip) == ""

## Pide el control para una accion. Devuelve el testigo (0 = rechazada; el motivo queda en `log`). Si el nivel es mayor
## que el de la accion vigente, la interrumpe.
func request(k: StringName, lv: int, src: StringName, c: StringName = &"", in_place: bool = false) -> int:
	var why: String = _verdict(lv, c if in_place else &"")
	if why != "":
		stats["rechazadas"] += 1
		_note("RECHAZADA %s (%s, nivel %d) %s: %s" % [k, src, lv, c, why])
		if AnimTrace.enabled:
			AnimTrace.event(owner, k, &"ActionArbiter", c, "rejected", "arbitro: " + why, {"context": "%s nivel %d" % [src, lv]})
		return 0
	if level != Level.NONE:
		_interrupt(k)
	token = _next_token
	_next_token += 1
	kind = k
	level = lv
	source = src
	clip = c
	stats["aceptadas"] += 1
	_note("ACEPTADA %s (%s, nivel %d) %s" % [k, src, lv, c])
	if AnimTrace.enabled:
		AnimTrace.event(owner, k, &"ActionArbiter", c, "accepted", "", {"context": "%s nivel %d" % [src, lv]})
	return token

## request + reproducir el clip en la ranura de pose. Un clip inexistente o que no se reproduce falla sin dejar nada tomado.
func play(k: StringName, lv: int, src: StringName, c: StringName, speed: float = 1.0, start: float = 0.0, play_for: float = -1.0, in_place: bool = false) -> int:
	if owner.visual == null or c == &"" or not PackLibrary.has_clip(c):
		stats["rechazadas"] += 1
		_note("RECHAZADA %s (%s, nivel %d) %s: clip inexistente" % [k, src, lv, c])
		if AnimTrace.enabled:
			AnimTrace.event(owner, k, &"ActionArbiter", c, "rejected", "no_encontrado: clip inexistente", {"context": "%s nivel %d" % [src, lv]})
		return 0
	var t: int = request(k, lv, src, c, in_place)
	if t == 0:
		return 0
	if owner.visual.play_pack_clip(c, speed, start, play_for) <= 0.0:
		release(t, "sin reproduccion")
		return 0
	return t

## Situacion de presentacion (AnimationCatalog: festejos, lamentos, recepcion...) como pose en el sitio.
func play_situation(situation: StringName, lv: int, src: StringName, pick: int = 0, speed: float = 1.0, play_for: float = -1.0) -> int:
	if owner.visual == null:
		return 0
	var r: Dictionary = AnimationCatalog.resolve(situation, owner.visual.uses_pack, pick)
	if r.is_empty():
		stats["rechazadas"] += 1
		_note("RECHAZADA %s (%s, nivel %d): sin clip" % [situation, src, lv])
		return 0
	if r.get("source", &"") == &"pack":
		return play(situation, lv, src, r["clip"], speed, 0.0, play_for, true)
	# Clip de Tripo (solo fuera del modo 4: en el modo 4 AnimationCatalog.resolve no los devuelve): misma solicitud al
	# arbitro, reproducido en su ranura de Tripo (FootballerVisual.play_action).
	var c: StringName = r["clip"]
	var t: int = request(situation, lv, src, c, true)
	if t == 0:
		return 0
	if owner.visual.play_action(c, speed) <= 0.0:
		release(t, "sin reproduccion")
		return 0
	return t

## Encadenado de la misma accion (caer -> tendido -> levantarse): cambia tipo y clip sin volver a arbitrar.
func handover(t: int, k: StringName, c: StringName) -> bool:
	if t == 0 or t != token:
		stats["obsoletas"] += 1
		_note("OBSOLETA encadenado %s %s (testigo %d, vigente %d)" % [k, c, t, token])
		return false
	kind = k
	clip = c
	_note("ENCADENADO %s %s" % [k, c])
	return true

## El dueno termina su accion. Un testigo que ya no es el vigente no hace nada (la accion fue sustituida o cortada).
func release(t: int, why: String = "fin") -> bool:
	if t == 0 or t != token:
		if t != 0:
			stats["obsoletas"] += 1
			_note("OBSOLETA liberacion (testigo %d, vigente %d): %s" % [t, token, why])
		return false
	_stop_pose()
	_clear(why, "liberadas")
	return true

## Baja el nivel de la accion vigente sin cortarla: el golpeo, resuelto el contacto, queda como capa (su continuacion se
## sigue viendo, pero un giro con pelota o una caida ya pueden entrar, como antes del arbitro).
func relevel(t: int, lv: int) -> bool:
	if t == 0 or t != token:
		return false
	_note("NIVEL %s: %d -> %d" % [kind, level, lv])
	level = lv
	return true

## Corta la pose vigente si es un gesto o una capa (nivel <= max_level); las acciones de mas nivel no se tocan.
func cut_pose(why: String, max_level: int = Level.OVERLAY) -> bool:
	var lv: int = current_level()
	if lv == Level.NONE or lv > max_level:
		return false
	_stop_pose()
	_clear(why, "liberadas")
	return true

## Reinicio del jugador (colocacion para un saque, reinicio de partido): corta lo que haya, sin residuos.
func reset(why: String = "reinicio") -> void:
	stats["reinicios"] += 1
	if level != Level.NONE:
		_interrupt(&"reinicio")
	elif owner.visual != null and owner.visual.is_action_playing():
		# Pose sin dueno (por ejemplo, la de una accion ya liberada): tampoco sobrevive al reinicio.
		owner.visual.stop_current_action()
	_note("REINICIO: %s" % why)

## La pose `c` la sostiene una accion con raiz que sigue en curso (FootballerVisual no la da por terminada aunque su
## temporizador llegue a cero un paso antes que la raiz).
func holds_pose(c: StringName) -> bool:
	return ROOT_LEVELS.has(level) and c == clip and owner.actions != null and owner.actions.active()

## Una pose en el sitio vale si el cuerpo no corre mas que el propio clip (+ IN_PLACE_SLACK).
func fits_in_place(c: StringName) -> bool:
	return owner.locomotion == null or owner.locomotion.speed - clip_speed(c) <= IN_PLACE_SLACK

## Velocidad (m/s) que lleva el propio clip: recorrido de la raiz por segundo o su carrera de entrada / salida.
static func clip_speed(c: StringName) -> float:
	var m: Dictionary = PackLibrary.meta(c)
	var dur: float = maxf(float(m.get("duration", 1.0)), 0.1)
	return maxf((m.get("root_total", Vector2.ZERO) as Vector2).length() / dur, maxf(float(m.get("v_in", 0.0)), float(m.get("v_out", 0.0))))

func _verdict(lv: int, in_place_clip: StringName) -> String:
	var cur: int = current_level()
	if cur != Level.NONE and lv <= cur:
		return "ocupado por %s (%s, nivel %d)" % [kind, source, cur]
	if in_place_clip != &"" and not fits_in_place(in_place_clip):
		return "pose en el sitio con el cuerpo a %.1f m/s (clip %.1f m/s)" % [owner.locomotion.speed, clip_speed(in_place_clip)]
	return ""

func _alive() -> bool:
	if ROOT_LEVELS.has(level):
		return owner.actions != null and owner.actions.active()
	if level == Level.KICK:
		return owner.ball_handler.is_kick_in_progress() or _pose_is(clip)
	return _pose_is(clip)

func _pose_is(c: StringName) -> bool:
	return owner.visual != null and c != &"" and owner.visual.current_action == c

## Corta del todo a la accion vigente (la sustituye otra o un reinicio).
func _interrupt(by: StringName) -> void:
	stats["interrumpidas"] += 1
	_note("INTERRUMPIDA %s (nivel %d) por %s" % [kind, level, by])
	if AnimTrace.enabled:
		AnimTrace.event(owner, kind, &"ActionArbiter", clip, "interrupted", "por " + String(by), {"context": "%s nivel %d" % [source, level]})
	if ROOT_LEVELS.has(level) and owner.actions != null:
		owner.actions.interrupt()
	elif level == Level.KICK and owner.ball_handler != null:
		owner.ball_handler.abort_kick()
	_stop_pose()
	_clear("interrumpida", "")

func _stop_pose() -> void:
	if owner.visual != null and clip != &"" and owner.visual.current_action == clip:
		owner.visual.stop_current_action()

func _clear(why: String, stat: String) -> void:
	if stat != "":
		stats[stat] += 1
		_note("FIN %s (nivel %d): %s" % [kind, level, why])
		if AnimTrace.enabled:
			var res: String = "expired" if stat == "caducadas" else ("completed" if why == "fin" else "cancelled")
			AnimTrace.event(owner, kind, &"ActionArbiter", clip, res, "" if res == "completed" else why, {"context": "%s nivel %d" % [source, level]})
	kind = &""
	level = Level.NONE
	source = &""
	clip = &""
	token = 0

func _note(s: String) -> void:
	log.append("f%d %s" % [Engine.get_physics_frames(), s])
	if log.size() > LOG_MAX:
		log.pop_front()
