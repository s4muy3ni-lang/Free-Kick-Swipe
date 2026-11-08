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
## Profundidad del techo de la red (m). < 0: red en forma de caja (fondo vertical a goal_depth). Entre 0 y goal_depth: red
## de futbol 11 (fondo inclinado desde el techo hasta el piso, con soportes detras del arco).
@export var goal_top_depth: float = -1.0
## Caida de reposo de la red (0 = tensa, la de siempre; 1 = cuelga como una red real de futbol 11).
@export var goal_net_sag: float = 0.0
## Estructura detras del arco: 0 ninguna, 1 soportes de la red inclinada (barra superior y tirantes), 2 caños en el piso
## (red de caja, como la de los estadios).
@export var goal_supports: int = 0
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

## Tipos de arco de futbol 11 (selector del menu): red de caja (techo largo y fondo vertical, caños en el piso, como en los
## estadios) o red de fondo inclinado (techo corto y fondo que baja hasta el piso, con soportes).
enum GoalStyle { BOX, SLANTED }

## Cancha de futbol 11 (105 x 68 m, arcos de 7,32 x 2,44 m): la de los modos de tiros libres y penales (Stadium11). Las
## marcas del area de futbol 11 las dibuja Stadium11, no Pitch.
static func football11(style: int = GoalStyle.BOX) -> PitchConfig:
	var c := PitchConfig.new()
	c.length = 105.0
	c.width = 68.0
	c.goal_width = 7.32
	c.goal_height = 2.44
	if style == GoalStyle.SLANTED:
		c.goal_depth = 2.0
		c.goal_top_depth = 0.9
		c.goal_supports = 1
	else:
		c.goal_depth = 2.0
		c.goal_top_depth = -1.0
		c.goal_supports = 2
	c.goal_net_sag = 1.0
	c.post_radius = 0.06
	c.line_width = 0.12
	c.center_circle_radius = 9.15
	c.penalty_mark_distance = 11.0
	c.boundary_mode = BoundaryMode.OUT_OF_BOUNDS
	c.run_off = 6.0
	return c

func half_length() -> float:
	return length * 0.5

func half_width() -> float:
	return width * 0.5

func half_goal() -> float:
	return goal_width * 0.5
