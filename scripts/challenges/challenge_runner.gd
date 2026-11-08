class_name ChallengeRunner
extends Node
## Juega un ejercicio de la Academia o un desafio de la Arena dentro del juego de siempre (SetPieceGame en modo CHALLENGE):
## mismo disparo, misma fisica, mismo arquero y barrera. Lleva los intentos, evalua cada uno con los blancos
## (ChallengeTargets), suma la puntuacion (ChallengeScore), decide cuando termina y registra el resultado (PlayerProgress;
## la practica libre no registra).

var def: Dictionary = {}
var practice: bool = false
var difficulty: int = 0
var targets: ChallengeTargets
var used: int = 0
var score: int = 0
var successes: int = 0
var streak: int = 0
var best_streak: int = 0
var knocked: int = 0
var finished: bool = false
var history: Array = []
var last_result: Dictionary = {}
var _seq: int = 0

func setup(d: Dictionary, is_practice: bool, b: Ball, gx: float, half_goal: float, goal_h: float) -> void:
	def = d
	practice = is_practice
	difficulty = int(d.get("difficulty", 0))
	targets = ChallengeTargets.new()
	targets.name = "ChallengeTargets"
	add_child(targets)
	targets.build(d, b, gx, half_goal, goal_h)

func spot_distance() -> float:
	return float(def["spot"][0])

func attempts() -> int:
	return int(def["attempts"])

func remaining() -> int:
	return attempts() - used

func begin_attempt() -> void:
	targets.begin_attempt()

## Evalua el intento que termino. why: resultado de la jugada (goal, save, post, wall, miss...). speed: velocidad real de
## salida. Devuelve {points, hit, text, sub, color}.
func evaluate(why: String, speed: float) -> Dictionary:
	used += 1
	var hits: Dictionary = targets.attempt_hits()
	var rule: String = String(def["rule"])
	var n_hits: int = 0
	var precision: float = 0.0
	var special: bool = false
	var too_slow: bool = float(def["min_speed"]) > 0.0 and speed < float(def["min_speed"])
	match rule:
		"sequence":
			if hits.has(_seq):
				n_hits = 1
				precision = float(hits[_seq])
		"objects":
			var now: int = targets.knocked_count()
			n_hits = now - knocked
			knocked = now
		_:
			n_hits = hits.size()
			for k in hits:
				precision = maxf(precision, float(hits[k]))
	for k in hits:
		var tp: String = String(targets.targets[k]["type"])
		if tp in ["post_left", "post_right", "crossbar"] or bool(targets.targets[k]["data"].get("bounce", false)):
			special = true
	if too_slow:
		n_hits = 0
	var hit: bool = n_hits > 0
	if hit:
		successes += 1 if rule != "objects" else 0
		streak += 1
		best_streak = maxi(best_streak, streak)
		if rule == "sequence":
			_seq += 1
			if _seq < targets.targets.size():
				targets.set_active(_seq)
	else:
		streak = 0
	var pts: int = ChallengeScore.attempt_points(n_hits, precision, spot_distance(), speed, float(def["min_speed"]), streak, special, difficulty)
	score += pts
	history.append(pts)
	var text: String = "¡BLANCO!" if hit else ("MUY LENTO" if too_slow and hits.size() > 0 else "¡FALLASTE!")
	if rule == "objects":
		text = ("¡%d ABAJO!" % n_hits) if hit else "NINGUNO"
	var sub: String = "+%d puntos" % pts if hit else ("Necesitás %.0f m/s (saliste a %.1f)" % [float(def["min_speed"]), speed] if too_slow else _miss_reason(why))
	if hit and streak >= 2:
		sub += " · racha %d" % streak
	if _completed() or remaining() <= 0:
		finished = true
	return {"points": pts, "hit": hit, "text": text, "sub": sub, "color": Color(0.35, 1.0, 0.45) if hit else Color(1.0, 0.45, 0.4)}

static func _miss_reason(why: String) -> String:
	return {"save": "La atajó", "wall": "Pegó en la barrera", "post": "Pegó en el palo", "miss": "Afuera",
		"cleared": "La despejaron", "goal": "Gol, pero no en el blanco"}.get(why, "")

func progress_value() -> int:
	return knocked if String(def["rule"]) == "objects" else successes

func _completed() -> bool:
	var need: int = int(def["needed"])
	if int(def["streak_needed"]) > 0:
		return best_streak >= int(def["streak_needed"])
	return progress_value() >= need

## Termina: bonificacion por intentos de sobra (solo si lo completo), medalla y registro. Devuelve el resumen.
func finish() -> Dictionary:
	var spare: int = 0
	if _completed():
		spare = ChallengeScore.spare_bonus(remaining(), difficulty)
		score += spare
	var medal: int = ChallengeScore.medal_for(score, def["medals"], difficulty)
	var rec: Dictionary = {}
	var key: String = PlayerProgress.key(def, difficulty if String(def.get("group", "")) == "arena" else -1)
	var prev_best: int = PlayerProgress.best(key)
	if not practice:
		rec = PlayerProgress.record(def, score, medal, difficulty if String(def.get("group", "")) == "arena" else -1)
	last_result = {"score": score, "medal": medal, "completed": _completed(), "spare_bonus": spare, "prev_best": prev_best,
		"best": maxi(prev_best, score) if not practice else prev_best, "new_best": score > prev_best and not practice, "practice": practice,
		"xp_gained": int(rec.get("xp_gained", 0)), "cosmetic": String(rec.get("cosmetic", "")), "progress": progress_value(),
		"needed": int(def["needed"]), "attempts_used": used, "best_streak": best_streak, "level": PlayerProgress.level()}
	return last_result

func status_text() -> String:
	var need: int = int(def["needed"])
	var what: String = "caídos" if String(def["rule"]) == "objects" else "aciertos"
	return "Intento %d/%d · %s %d/%d · %d pts" % [mini(used + 1, attempts()), attempts(), what, progress_value(), need, score]
