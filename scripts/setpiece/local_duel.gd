class_name LocalDuel
extends RefCounted
## Duelo local de dos jugadores en el mismo telefono (pedido del usuario: «DOS JUGADORES — DUELO LOCAL»): penales o tiros
## libres alternando tirador y arquero, con un marcador propio separado de los modos contra la CPU y del online (no da
## premios ni logros: dos jugadores en un telefono no deben poder sumar recompensas jugando contra si mismos).
##
## Por jugador: goles, goles recibidos, atajadas, tiros errados (afuera, palo, barrera o despeje sin gol ni atajada),
## puntos (POINTS) y victorias. Las victorias y partidas jugadas se guardan en el telefono (SAVE_PATH). Igualdad de
## oportunidades: los dos patean la misma cantidad de veces, desde los mismos puntos, y en cada revancha empieza el otro.

const SAVE_PATH := "user://local_duel.json"
const NAMES := ["JUGADOR 1", "JUGADOR 2"]
## Puntos por jugada: gol del que patea, atajada del que ataja.
const POINTS := {"goal": 3, "save": 2}

var stats: Array = [{}, {}]
## Totales guardados: victorias de cada jugador y partidas jugadas.
var wins: Array = [0, 0]
var matches: int = 0
var draws: int = 0

func _init() -> void:
	reset_match()
	load_totals()

## Marcador de la partida en curso en cero (las victorias guardadas no se tocan).
func reset_match() -> void:
	for i in 2:
		stats[i] = {"goals": 0, "conceded": 0, "saves": 0, "missed": 0, "shots": 0, "points": 0}

## Quien empieza pateando esta partida: se alterna en cada revancha.
func first_shooter() -> int:
	return matches % 2

## Un tiro de `shooter` (0 o 1) con su resultado (goal, save, miss, post, wall, cleared).
func record_shot(shooter: int, outcome: String) -> void:
	var keeper: int = 1 - shooter
	var s: Dictionary = stats[shooter]
	var k: Dictionary = stats[keeper]
	s["shots"] = int(s["shots"]) + 1
	if outcome == "goal":
		s["goals"] = int(s["goals"]) + 1
		s["points"] = int(s["points"]) + int(POINTS["goal"])
		k["conceded"] = int(k["conceded"]) + 1
	elif outcome == "save":
		k["saves"] = int(k["saves"]) + 1
		k["points"] = int(k["points"]) + int(POINTS["save"])
	else:
		s["missed"] = int(s["missed"]) + 1

## Termina la partida con ganador w (0, 1 o -1 empate) y guarda los totales.
func record_match(w: int) -> void:
	matches += 1
	if w == 0 or w == 1:
		wins[w] = int(wins[w]) + 1
	else:
		draws += 1
	save_totals()

func load_totals() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		var w: Array = (d as Dictionary).get("wins", [0, 0])
		wins = [int(w[0]) if w.size() > 0 else 0, int(w[1]) if w.size() > 1 else 0]
		matches = int((d as Dictionary).get("matches", 0))
		draws = int((d as Dictionary).get("draws", 0))

func save_totals() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"wins": wins, "matches": matches, "draws": draws}))

## Borra las victorias guardadas (boton «Reiniciar marcador»).
func reset_totals() -> void:
	wins = [0, 0]
	matches = 0
	draws = 0
	save_totals()

## Una linea por jugador para la pantalla final.
func summary() -> String:
	var lines: PackedStringArray = []
	for i in 2:
		var s: Dictionary = stats[i]
		lines.append("%s · goles %d · recibidos %d · atajadas %d · errados %d · puntos %d · victorias %d" % [NAMES[i],
			int(s["goals"]), int(s["conceded"]), int(s["saves"]), int(s["missed"]), int(s["points"]), int(wins[i])])
	return "\n".join(lines)
