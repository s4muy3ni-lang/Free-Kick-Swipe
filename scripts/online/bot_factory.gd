class_name BotFactory
extends RefCounted
## Rivales IA bajo demanda (pedido del usuario): nombre natural, avatar, numero, personalidad, habilidad y un historial
## propio. En el servidor los genera _make_bot (supabase/migrations/..._match_functions.sql) con las mismas listas; esta
## version la usa el backend local. Un bot siempre lleva is_bot = true: no tiene cuenta, no entra en rankings humanos ni
## recibe recompensas.
##
## Dificultad adaptativa: la habilidad sale de la anterior y de los ultimos resultados del jugador en ese modo (si gana
## mucho sube, si pierde baja), con cambios de a lo sumo 0,1 por partida (nada de saltos bruscos).

const FIRSTS := ["Lucas", "Mateo", "Thiago", "Benja", "Santi", "Joaco", "Nico", "Fede", "Tomi", "Lauti", "Bruno", "Facu",
	"Agus", "Gonza", "Valen", "Juanma", "Rami", "Leo", "Dani", "Pablo", "Ezequiel", "Franco", "Mauro", "Ignacio", "Sofi",
	"Cami", "Mica", "Lu", "Juli", "Vicky", "Martina", "Delfi", "Ale", "Seba", "Iván", "Emi", "Kevin", "Brian", "Lean", "Cristian"]
const TAILS := ["", "", "", "10", "_9", "Gol", "FC", "_crack", "22", "Tiki", "_7", "Pibe", "Zurdo", "99"]
const PERSONALITIES := ["principiante", "tranquilo", "agresivo", "tecnico", "impredecible", "competitivo", "experto"]

## Habilidad siguiente: prev (o la del nivel si es la primera), recent = resultados 1/0,5/0 de las ultimas partidas.
static func next_skill(level: int, prev: float, recent: Array) -> float:
	var base: float = prev if prev >= 0.0 else minf(0.3 + level * 0.02, 0.6)
	var w: float = 0.5
	if not recent.is_empty():
		var s: float = 0.0
		for r in recent:
			s += float(r)
		w = s / recent.size()
	var target: float = base + (w - 0.5) * 0.3
	return clampf(clampf(target, base - 0.1, base + 0.1), 0.1, 0.95)

static func personality_for(skill: float, rng: RandomNumberGenerator) -> String:
	if skill < 0.25:
		return "principiante"
	if skill > 0.85:
		return "experto"
	return PERSONALITIES[1 + rng.randi_range(0, 4)]

static func make(rng: RandomNumberGenerator, level: int, prev_skill: float, recent: Array) -> Dictionary:
	var sk: float = snappedf(next_skill(level, prev_skill, recent), 0.001)
	return {"name": FIRSTS[rng.randi() % FIRSTS.size()] + TAILS[rng.randi() % TAILS.size()],
		"personality": personality_for(sk, rng), "skill": sk, "level": maxi(1, level + rng.randi_range(-2, 2)),
		"seed": rng.randi() % 2147483647,
		"avatar": {"jersey": rng.randi() % 10, "shorts": rng.randi() % 8, "skin": rng.randi() % 6, "hair": rng.randi() % 6,
			"number": rng.randi_range(1, 99)},
		"record": {"played": rng.randi_range(20, 320), "win_rate": snappedf(0.3 + sk * 0.5, 0.01)}, "is_bot": true}
