class_name Rebotes
extends Demolicion
## Rebotes e ingenio (etapa C): los objetivos estan ESCONDIDOS detras de paredes y techos; el tiro directo no existe y hay
## que calcular rebotes reales (paredes laterales, techo, rampas) para llegar. Reutiliza el motor de Demolicion (bloques
## rigidos derribables, mesa, tiros limitados) con niveles cuya geometria obliga al rebote; cada rebote de la pelota
## contra una pared antes de derribar suma un pequeño bonus de ingenio. La prediccion del trazo ayuda (muestra el primer
## tramo) pero los niveles no se resuelven solos: el objetivo no esta a la vista.

const RSCENE := "res://scenes/minigames/rebotes.tscn"
const BOUNCE_BONUS := 25

var wall_bounces: int = 0

func game_id() -> String:
	return "rebotes"

func _ready() -> void:
	super._ready()
	ball.body_entered.connect(_count_bounce)

func _count_bounce(body: Node) -> void:
	if state == State.FLIGHT and body is StaticBody3D:
		wall_bounces += 1

func _start_turn() -> void:
	super._start_turn()
	wall_bounces = 0

func final_score() -> int:
	var s: int = super.final_score()
	return s + (mini(wall_bounces, 4) * BOUNCE_BONUS if s > 0 else 0)
