class_name PenaltyShootout
extends RefCounted
## Reglas de la tanda de penales (estado puro, sin nodos; sirve tambien para el futuro 1 contra 1 en linea): turnos
## alternados (1 tiro y 1 atajada), serie inicial de 5 por equipo que termina antes si uno ya no puede alcanzar al otro, y
## muerte subita de a un tiro por equipo hasta que, con la misma cantidad de tiros, uno haga gol y el otro no.

const REGULAR := 5
const USER := 0
const CPU := 1

var results: Array = [[], []]
## Equipo que patea primero (el usuario; en el duelo local se alterna en cada revancha).
var first: int = USER

func reset() -> void:
	results = [[], []]

## Equipo al que le toca tirar.
func next_team() -> int:
	var other: int = 1 - first
	return first if (results[first] as Array).size() <= (results[other] as Array).size() else other

func record(team: int, goal: bool) -> void:
	(results[team] as Array).append(goal)

func kicks(team: int) -> int:
	return (results[team] as Array).size()

func goals(team: int) -> int:
	var n: int = 0
	for g in results[team]:
		if g:
			n += 1
	return n

func in_sudden_death() -> bool:
	return kicks(USER) >= REGULAR and kicks(CPU) >= REGULAR

func finished() -> bool:
	return winner() >= 0

## 0 usuario, 1 CPU, -1 todavia nadie.
func winner() -> int:
	var ku: int = kicks(USER)
	var kc: int = kicks(CPU)
	var gu: int = goals(USER)
	var gc: int = goals(CPU)
	if ku <= REGULAR and kc <= REGULAR and not (ku == REGULAR and kc == REGULAR):
		# Serie inicial: termina si uno no puede alcanzar al otro ni con todos sus tiros que faltan.
		if gu + (REGULAR - ku) < gc:
			return CPU
		if gc + (REGULAR - kc) < gu:
			return USER
		return -1
	if ku == kc and gu != gc:
		return USER if gu > gc else CPU
	return -1
