class_name BehaviorMirror
extends RefCounted
## Comportamiento espejo (pedido del usuario): el bot imita el ritmo del jugador. Si el usuario tarda 4 s en preparar
## un tiro, el bot tarda entre 5 y 10; si el usuario tarda mas, el bot usa un tiempo parecido; si dispara rapido, el bot
## responde mas rapido. Siempre con variacion y dentro del tiempo de turno.

const TURN_LIMIT := 20.0

var samples: Array[float] = []
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 7) -> void:
	rng.seed = seed_value

## Registra cuanto tardo el usuario en preparar su tiro (s).
func observe(seconds: float) -> void:
	samples.append(clampf(seconds, 0.3, TURN_LIMIT))
	if samples.size() > 6:
		samples.remove_at(0)

func user_average() -> float:
	if samples.is_empty():
		return 5.0
	var s: float = 0.0
	for x in samples:
		s += x
	return s / samples.size()

## Cuanto espera el bot antes de patear (s).
func bot_delay() -> float:
	var u: float = user_average()
	var d: float
	if u <= 2.0:
		d = u * rng.randf_range(1.0, 1.8) + 0.8
	elif u <= 8.0:
		d = u * rng.randf_range(1.25, 2.5)
	else:
		d = u * rng.randf_range(0.8, 1.15)
	return clampf(d, 1.2, TURN_LIMIT - 3.0)
