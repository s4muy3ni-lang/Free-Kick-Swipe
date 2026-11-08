class_name PitchConfig
extends Resource
## Configuracion de la cancha. Por defecto, cancha de futbol 7 de 50 x 30 m con arcos de 5 x 2 m (desde 2026-11-05;
## antes futsal de 40 x 20 m con arcos de 3 x 2 m, que sigue disponible con futsal() y es la cancha de las pruebas de
## mecanica). Todas las medidas estan en metros.
## El eje X es el largo (los arcos estan en x = +-length/2) y el eje Z el ancho.

enum BoundaryMode { WALLS, OUT_OF_BOUNDS }

@export_group("Dimensiones")
@export var length: float = 50.0
@export var width: float = 30.0

@export_group("Arco")
@export var goal_width: float = 5.0
@export var goal_height: float = 2.0
@export var goal_depth: float = 1.0
@export var post_radius: float = 0.04

@export_group("Marcas")
@export var line_width: float = 0.08
@export var center_circle_radius: float = 6.0
## Radio de los cuartos de circulo del area de penal (desde cada poste).
@export var penalty_area_radius: float = 8.0
@export var penalty_mark_distance: float = 8.0
## Segundo punto penal (reglamento futsal, falta acumulada; en la cancha de futbol 7 solo se dibuja).
@export var second_penalty_mark_distance: float = 12.0
@export var corner_arc_radius: float = 0.25
@export var substitution_zone_length: float = 5.0

@export_group("Entorno")
@export var boundary_mode: BoundaryMode = BoundaryMode.WALLS
## Altura de las paredes que mantienen la pelota en juego.
@export var wall_height: float = 3.0
## Altura visible de la valla/baranda (el resto es colision invisible).
@export var barrier_visible_height: float = 1.0
@export var run_off: float = 2.5

## Cancha de futsal de 40 x 20 m con arcos de 3 x 2 m (la de antes): la usan las pruebas de mecanica (TestCase).
static func futsal() -> PitchConfig:
	var c := PitchConfig.new()
	c.length = 40.0
	c.width = 20.0
	c.goal_width = 3.0
	c.center_circle_radius = 3.0
	c.penalty_area_radius = 6.0
	c.penalty_mark_distance = 6.0
	c.second_penalty_mark_distance = 10.0
	return c

func half_length() -> float:
	return length * 0.5

func half_width() -> float:
	return width * 0.5

func half_goal() -> float:
	return goal_width * 0.5
