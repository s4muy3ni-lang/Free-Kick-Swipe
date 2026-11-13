class_name KeeperZones
extends RefCounted
## Sectores del arco para atajar (pedido del usuario: «nueve sectores»): el arco se divide en 3 columnas (palo, centro,
## palo) por 3 alturas (abajo, al medio, arriba) = 9 sectores. El arquero se juega a un sector (lo toca el usuario, lo
## elige la IA o el rival online sin conocer el tiro). Si el tiro cruza la linea en ese mismo sector Y esta al alcance
## fisico de la estirada (KeeperReach: altura, distancia lateral desde el arquero y tiempo que tarda la pelota), la
## atajada es segura (SpKeeper.sure_save_check). Si va al mismo sector pero tan pegado al angulo que supera el alcance,
## es gol: decide la fisica de la estirada real, sin atajadas imposibles.
##
## Ejes: z = ancho del arco, y = alto. Indice = fila * COLS + columna; columna 0 es z negativo, fila 0 es abajo.

const COLS := 3
const ROWS := 3
const COUNT := COLS * ROWS

## Sector (0..8) del punto p en el plano del arco, o -1 si queda fuera (afuera, por encima del travesaño o un tiro que no
## llega). half: medio ancho del arco; height: alto.
static func zone_of(p: Vector3, half: float, height: float) -> int:
	if p == Vector3.INF or absf(p.z) > half or p.y > height or p.y < -0.05:
		return -1
	var col: int = clampi(int(floor((p.z + half) / (2.0 * half / float(COLS)))), 0, COLS - 1)
	var row: int = clampi(int(floor(maxf(p.y, 0.0) / (height / float(ROWS)))), 0, ROWS - 1)
	return row * COLS + col

## Centro del sector i en el plano del arco (x = goal_x).
static func center(i: int, goal_x: float, half: float, height: float) -> Vector3:
	var col: int = i % COLS
	var row: int = i / COLS
	var w: float = 2.0 * half / float(COLS)
	var h: float = height / float(ROWS)
	return Vector3(goal_x, (float(row) + 0.5) * h, -half + (float(col) + 0.5) * w)

## Rectangulo del sector i en el plano del arco: [z0, y0, z1, y1].
static func rect(i: int, half: float, height: float) -> Array:
	var col: int = i % COLS
	var row: int = i / COLS
	var w: float = 2.0 * half / float(COLS)
	var h: float = height / float(ROWS)
	return [-half + float(col) * w, float(row) * h, -half + float(col + 1) * w, float(row + 1) * h]

## Fila (0 abajo, 1 al medio, 2 arriba) y columna (0 = z negativo) del sector i.
static func row_of(i: int) -> int:
	return i / COLS

static func col_of(i: int) -> int:
	return i % COLS

## Nombre del sector tal como lo ve el usuario desde atras del arco (mirando hacia el campo, la derecha de la pantalla es
## z negativo).
static func name_of(i: int) -> String:
	if i < 0 or i >= COUNT:
		return "fuera del arco"
	var h: String = ["abajo", "al medio", "arriba"][row_of(i)]
	var c: String = ["a la derecha", "al centro", "a la izquierda"][col_of(i)]
	if row_of(i) == 1 and col_of(i) == 1:
		return "al medio, al centro"
	return "%s %s" % [h, c]
