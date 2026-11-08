class_name MatchMetrics
extends RefCounted
## Medidas objetivas del juego colectivo en un partido en marcha (pruebas y diagnostico): amontonamiento alrededor de la
## pelota, separacion entre companeros, ocupacion del ancho, pases completados, duracion de la posesion, faltas.

var samples: int = 0
var near3: float = 0.0          # jugadores de campo a menos de 3 m de la pelota (media)
var near5: float = 0.0
var scrum_samples: int = 0      # muestras con 4 o mas jugadores a menos de 4 m de la pelota
var mate_gap: float = 0.0       # distancia media al companero mas cercano
var width_used: float = 0.0     # ancho (z) que ocupa el equipo con la pelota
var depth_used: float = 0.0
var passes: int = 0
var completed: int = 0
var fouls: int = 0
var tackles: int = 0
var shots: int = 0
var possession_changes: int = 0
var _last_team: int = -1
var _pending_pass: Dictionary = {}

func attach(ctx: MatchContext) -> void:
	ctx.event_emitted.connect(_on_event)

func _on_event(e: GameEvent) -> void:
	match e.type:
		GameEvent.Type.PASS:
			if not e.data.has("set_piece"):
				passes += 1
				_pending_pass = {"team": e.team, "target": int(e.data.get("target", -1))}
		GameEvent.Type.FIRST_TOUCH:
			if not _pending_pass.is_empty():
				if e.team == int(_pending_pass["team"]):
					completed += 1
				_pending_pass = {}
		GameEvent.Type.FOUL:
			fouls += 1
		GameEvent.Type.TACKLE_WON, GameEvent.Type.TACKLE_FAILED:
			tackles += 1
		GameEvent.Type.SHOT:
			shots += 1

func sample(ctx: MatchContext) -> void:
	var b: Vector3 = ctx.ball.global_position
	var n3 := 0
	var n4 := 0
	var n5 := 0
	for f in ctx.footballers:
		var d: float = Vector2(f.global_position.x - b.x, f.global_position.z - b.z).length()
		if d < 3.0: n3 += 1
		if d < 4.0: n4 += 1
		if d < 5.0: n5 += 1
	samples += 1
	near3 += n3
	near5 += n5
	if n4 >= 4:
		scrum_samples += 1
	var gap := 0.0
	var cnt := 0
	for f in ctx.footballers:
		var best: float = INF
		for g in ctx.footballers:
			if g != f and g.team == f.team:
				best = minf(best, Vector2(f.global_position.x - g.global_position.x, f.global_position.z - g.global_position.z).length())
		if best < INF:
			gap += best
			cnt += 1
	mate_gap += gap / maxf(cnt, 1)
	var t: int = ctx.ball.last_touch_team
	if t >= 0:
		if _last_team >= 0 and t != _last_team:
			possession_changes += 1
		_last_team = t
		var zmin: float = INF
		var zmax: float = -INF
		var xmin: float = INF
		var xmax: float = -INF
		for f in ctx.footballers:
			if f.team == t:
				zmin = minf(zmin, f.global_position.z)
				zmax = maxf(zmax, f.global_position.z)
				xmin = minf(xmin, f.global_position.x)
				xmax = maxf(xmax, f.global_position.x)
		width_used += zmax - zmin
		depth_used += xmax - xmin

func report(seconds: float) -> Dictionary:
	var s: float = maxf(samples, 1)
	return {"near3": near3 / s, "near5": near5 / s, "scrum_pct": 100.0 * scrum_samples / s, "mate_gap": mate_gap / s,
		"width": width_used / s, "depth": depth_used / s, "passes_min": passes / (seconds / 60.0),
		"pass_pct": 100.0 * completed / maxf(passes, 1), "fouls_min": fouls / (seconds / 60.0),
		"tackles_min": tackles / (seconds / 60.0), "shots_min": shots / (seconds / 60.0),
		"turnovers_min": possession_changes / (seconds / 60.0)}

static func fmt(r: Dictionary) -> String:
	return "a<3m %.2f | a<5m %.2f | amontonado(>=4 a<4m) %.1f %% | hueco al companero %.1f m | ancho %.1f m | profundidad %.1f m | pases/min %.1f (%.0f %% completos) | faltas/min %.2f | disputas/min %.1f | tiros/min %.1f | cambios de posesion/min %.1f" % [
		r["near3"], r["near5"], r["scrum_pct"], r["mate_gap"], r["width"], r["depth"], r["passes_min"], r["pass_pct"], r["fouls_min"], r["tackles_min"], r["shots_min"], r["turnovers_min"]]
