class_name ChallengeScore
extends RefCounted
## Puntuacion de la Academia y de la Arena (fase 5 del plan): premia la habilidad, no el azar.
##  - Acierto: BASE puntos por blanco, mas precision (que tan cerca del centro del blanco, medido donde cruzo la pelota),
##    distancia del tiro, potencia (solo si el desafio la pide) y blancos especiales (palo, travesaño, rebote).
##  - Racha: los aciertos seguidos suman (consistencia, no suerte).
##  - Dificultad: multiplica todo (Facil x1 ... Extremo x2).
##  - Eficiencia: si se completa el desafio antes, los intentos que sobran suman.
##  - Un fallo suma 0 (no resta: se puede practicar sin miedo).
## Todo es puro (sin escena): se prueba sin render.

const BASE := 100
const PRECISION_MAX := 60
## Por metro de distancia por encima de DISTANCE_FREE (los tiros cortos no suman por distancia).
const DISTANCE_FREE := 16.0
const DISTANCE_PER_M := 3.0
const DISTANCE_MAX := 60
## Potencia: por cada m/s por encima del minimo pedido, hasta POWER_MAX.
const POWER_PER_MS := 6.0
const POWER_MAX := 60
const STREAK_STEP := 25
const STREAK_MAX := 100
const SPECIAL := 50
const SPARE_ATTEMPT := 40
const DIFFICULTY_MULT := [1.0, 1.25, 1.5, 1.75, 2.0]

## Puntos de un intento. hits: blancos acertados en el intento; precision 0..1 (1 = centro); distance_m: del punto del tiro
## a la linea; speed: velocidad de salida medida; min_speed: la que pide el desafio (0: no pide); streak: aciertos seguidos
## contando este; special: palo/travesaño/rebote si el desafio lo premia; difficulty 0..4.
static func attempt_points(hits: int, precision: float, distance_m: float, speed: float, min_speed: float, streak: int,
		special: bool, difficulty: int) -> int:
	if hits <= 0:
		return 0
	var p: float = float(BASE * hits)
	p += PRECISION_MAX * clampf(precision, 0.0, 1.0)
	p += clampf((distance_m - DISTANCE_FREE) * DISTANCE_PER_M, 0.0, DISTANCE_MAX)
	if min_speed > 0.0:
		p += clampf((speed - min_speed) * POWER_PER_MS, 0.0, POWER_MAX)
	p += clampf(float(STREAK_STEP * (streak - 1)), 0.0, STREAK_MAX)
	if special:
		p += SPECIAL
	return int(round(p * mult(difficulty)))

static func mult(difficulty: int) -> float:
	return DIFFICULTY_MULT[clampi(difficulty, 0, DIFFICULTY_MULT.size() - 1)]

## Bonificacion por terminar con intentos de sobra.
static func spare_bonus(spare_attempts: int, difficulty: int) -> int:
	return int(round(float(SPARE_ATTEMPT * maxi(spare_attempts, 0)) * mult(difficulty)))

## Medalla: 0 ninguna, 1 bronce, 2 plata, 3 oro. thresholds = [bronce, plata, oro] (puntos sin multiplicar por dificultad:
## se escalan con la dificultad).
static func medal_for(score: int, thresholds: Array, difficulty: int = 0) -> int:
	var m: int = 0
	for i in thresholds.size():
		if float(score) >= float(thresholds[i]) * mult(difficulty):
			m = i + 1
	return m

const MEDAL_NAMES := ["Sin medalla", "Bronce", "Plata", "Oro"]
