class_name KeeperZones
extends RefCounted
## Zonas del arco para atajar (pedido del usuario): el arco se divide en 3 columnas (palo, centro, palo) por 2 alturas
## (abajo, arriba) = 6 zonas. Si el arquero se juega a una zona y el tiro cruza la linea en esa misma zona, la atajada es
## segura (SpKeeper.sure_save_check). Seis y no nueve: las estiradas del banco son bajas o altas (no hay una familia de
## media altura), cada zona queda grande para tocarla en el telefono, y los costados (donde se patea casi siempre) quedan
## enteros en una zona de 2,44 m de ancho.
##
## Ejes: z = ancho del arco, y = alto. Indice = fila * COLS + columna; columna 0 es z negativo, fila 0 es abajo.

const COLS := 3
const ROWS := 2

## Zona (0..5) del punto p en el plano del arco, o -1 si queda fuera (afuera, por encima del travesaño o un tiro que no
## llega). half: medio ancho del arco; height: alto.
static func zone_of(p: Vector3, half: float, height: float) -> int:
	if p == Vector3.INF or absf(p.z) > half or p.y > height or p.y < -0.05:
		return -1
	var col: int = clampi(int(floor((p.z + half) / (2.0 * half / float(COLS)))), 0, COLS - 1)
	var row: int = 0 if p.y < height / float(ROWS) else 1
	return row * COLS + col

## Centro de la zona i en el plano del arco (x = goal_x).
static func center(i: int, goal_x: float, half: float, height: float) -> Vector3:
	var col: int = i % COLS
	var row: int = i / COLS
	var w: float = 2.0 * half / float(COLS)
	var h: float = height / float(ROWS)
	return Vector3(goal_x, (float(row) + 0.5) * h, -half + (float(col) + 0.5) * w)

## Rectangulo de la zona i en el plano del arco: [z0, y0, z1, y1].
static func rect(i: int, half: float, height: float) -> Array:
	var col: int = i % COLS
	var row: int = i / COLS
	var w: float = 2.0 * half / float(COLS)
	var h: float = height / float(ROWS)
	return [-half + float(col) * w, float(row) * h, -half + float(col + 1) * w, float(row + 1) * h]

## Nombre de la zona tal como la ve el usuario desde atras del arco (mirando hacia el campo, la derecha de la pantalla es
## z negativo).
static func name_of(i: int) -> String:
	if i < 0:
		return "fuera del arco"
	var col: int = i % COLS
	var row: int = i / COLS
	var h: String = "abajo" if row == 0 else "arriba"
	var c: String = ["a la derecha", "al centro", "a la izquierda"][col]
	return "%s %s" % [h, c]
