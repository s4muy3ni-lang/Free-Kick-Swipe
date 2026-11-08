class_name GameEvent
extends RefCounted
## Evento de gameplay inmutable y serializable (pase, tiro, gol, parada...).
## Es el contrato entre las reglas, las estadisticas y la futura replicacion de red:
## el servidor autoritativo emitira estos eventos y los clientes solo los reflejaran.

enum Type {
	KICKOFF, PASS, SHOT, GOAL, SAVE, TACKLE_WON, TACKLE_FAILED, INTERCEPTION, TURNOVER,
	FIRST_TOUCH, DRIBBLE_ATTEMPT, DRIBBLE_COMPLETED, FRAME_HIT, KEEPER_CATCH, KEEPER_DISTRIBUTE,
	MATCH_START, MATCH_END, RESTART, KICK_WHIFF,
	FOUL, OUT_OF_PLAY, SET_PIECE,
}

var type: Type = Type.PASS
var tick: int = 0
## Tiempo de partido en segundos.
var match_time: float = 0.0
var actor_id: int = -1
var team: int = -1
var data: Dictionary = {}

static func make(t: Type, actor: int, team_index: int, payload: Dictionary = {}) -> GameEvent:
	var e := GameEvent.new()
	e.type = t
	e.actor_id = actor
	e.team = team_index
	e.data = payload
	return e

func type_name() -> String:
	return Type.keys()[type]

func to_dict() -> Dictionary:
	return {"type": type_name(), "tick": tick, "time": match_time, "actor": actor_id, "team": team, "data": data}

static func from_dict(d: Dictionary) -> GameEvent:
	var e := GameEvent.new()
	var idx: int = Type.keys().find(str(d.get("type", "PASS")))
	e.type = (idx if idx >= 0 else 0) as Type
	e.tick = int(d.get("tick", 0))
	e.match_time = float(d.get("time", 0.0))
	e.actor_id = int(d.get("actor", -1))
	e.team = int(d.get("team", -1))
	e.data = d.get("data", {})
	return e
