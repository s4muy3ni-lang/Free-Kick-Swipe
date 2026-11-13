class_name FreeKickSpots
extends RefCounted
## Puntos de tiro de los tiros libres por turnos (contra la CPU, de a dos y online): en cada ronda los dos patean desde
## el mismo punto (igualdad de oportunidades). Online los fija el servidor: el orden lo da el desplazamiento de la partida
## (spot_offset, sorteado al crearla) y la ronda es shot_n / 2; el tirador informa el punto y el servidor lo compara con
## el que corresponde (funcion SQL fk_spot y LocalBackend con esta misma lista).
##
## Cada punto: distancia a la linea del arco (m) y ancho z (m). Todos fuera del area y a mas de SetPieceGame.FK_MIN_X.

const SPOTS := [Vector2(22.0, -7.0), Vector2(25.0, 5.0), Vector2(20.5, 10.0), Vector2(27.0, -1.0), Vector2(23.0, 12.0),
	Vector2(21.0, -11.0), Vector2(26.0, 8.0)]

## Punto de la ronda round_i con el desplazamiento offset.
static func at(round_i: int, offset: int) -> Vector2:
	return SPOTS[posmod(round_i + offset, SPOTS.size())]

## Donde se para el arquero para un tiro libre desde el ancho spot_z: en la bisectriz del angulo, corrido hacia el palo
## que no tapa la barrera (la misma cuenta que SetPieceGame._setup_free_kick con SpWall.cover_point).
static func keeper_z(spot_z: float, half_goal: float) -> float:
	var cover_z: float = 0.0 if absf(spot_z) < 2.0 else half_goal * (1.0 if spot_z >= 0.0 else -1.0) * 0.75
	return clampf(-cover_z * 0.35 + spot_z * 0.06, -1.2, 1.2)
