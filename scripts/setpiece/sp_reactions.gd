class_name SpReactions
extends RefCounted
## Reacciones de los jugadores despues de cada tiro (festejo, lamento, enojo, aplauso) con los clips del banco JSON por
## rol. Cada pedido toma otro clip del grupo (se ven todos).

## Roles de cada situacion.
const GOAL_SCORER: Array = [&"celebrate_scorer", &"celebrate"]
const GOAL_TEAM: Array = [&"celebrate_team", &"celebrate", &"clap"]
const MISS_SHOOTER: Array = [&"angry", &"dejected"]
const SAD: Array = [&"dejected"]
const HAPPY_DEFENDER: Array = [&"clap", &"celebrate", &"thumbs_up", &"gesture"]

static var _pools: Dictionary = {}
static var _turn: int = 0

## Clip de alguno de los roles con recorrido de raiz <= max_root (m) y al menos min_len segundos; &"" si no hay.
static func pick(roles: Array, rng: RandomNumberGenerator = null, max_root: float = 1.5, min_len: float = 0.8) -> StringName:
	var key: String = "%s|%.2f|%.2f" % [str(roles), max_root, min_len]
	if not _pools.has(key):
		var pool: Array[StringName] = []
		for r in roles:
			for id in SpClips.by_role(StringName(r)):
				var m: Dictionary = SpClips.meta(id)
				if SpClips.root_travel(m) <= max_root and SpClips.length(id) >= min_len and String(m.get("heading_mode", "")) != "turn":
					pool.append(id)
		_pools[key] = pool
	var p: Array = _pools[key]
	if p.is_empty():
		return &""
	_turn += 1
	var i: int = (rng.randi() if rng != null else _turn * 7) % p.size()
	return p[i]
