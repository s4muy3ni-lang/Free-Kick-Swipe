class_name ActionMotion
extends RefCounted
## Movimiento de raiz de una accion con clip del pack. Los clips guardan el desplazamiento de la raiz APARTE de la
## cadera (metadato root_path: acumulado a 30 Hz, metros de juego, (adelante, derecha)); el juego mueve al
## personaje siguiendo esa curva mientras dura la accion, y solo entonces: la locomocion queda en pausa.
## Modo 4 (Json): los clips con rumbo «turn» (giros, giros con pelota, regates; meta heading_mode) traen ademas cuanto gira el
## cuerpo (heading_path): la raiz va en el marco del INICIO del clip y el juego gira al jugador con ese rumbo (heading_driven).

var clip: StringName = &""
var speed: float = 1.0
## Tiempo (s) de reproduccion del clip (ya incluye el desfase de inicio).
var t: float = 0.0
var length: float = 0.0
## Si es > 0 la accion se corta a esos segundos de reproduccion (mundo real, no del clip).
var cut_after: float = -1.0
var elapsed: float = 0.0
var active: bool = false
var _path: PackedVector2Array = PackedVector2Array()
## Clip con rumbo propio: la raiz esta en el marco del inicio del clip (yaw0 = orientacion del jugador que corresponde a ese
## inicio) y el cuerpo gira heading_at(t).
var heading_driven: bool = false
var yaw0: float = 0.0
var _heading: PackedFloat32Array = PackedFloat32Array()
## Velocidad extra (mundo, m/s) que suma quien maneja la accion (ajuste de paso para llegar a la pelota).
var extra_velocity: Vector3 = Vector3.ZERO

func start(id: StringName, play_speed: float = 1.0, start_at: float = 0.0, cut: float = -1.0) -> bool:
	var a: Animation = PackLibrary.clip(id)
	if a == null:
		return false
	clip = id
	speed = maxf(play_speed, 0.05)
	t = start_at
	length = a.length
	cut_after = cut
	elapsed = 0.0
	var m: Dictionary = PackLibrary.meta(id)
	_path = m.get("root_path", PackedVector2Array())
	heading_driven = String(m.get("heading_mode", "")) == "turn"
	_heading = m.get("heading_path", PackedFloat32Array()) if heading_driven else PackedFloat32Array()
	extra_velocity = Vector3.ZERO
	active = true
	return true

## Giro del cuerpo (rad, + izquierda) desde el inicio del clip hasta el instante `at` del clip (0 si el clip no lo trae).
func heading_at(at: float) -> float:
	return heading_rel(_heading, at)

static func heading_rel(h: PackedFloat32Array, at: float) -> float:
	if h.size() < 2:
		return 0.0
	var f: float = clampf(at * 30.0, 0.0, float(h.size() - 1))
	var i: int = mini(int(f), h.size() - 2)
	return deg_to_rad(lerpf(h[i], h[i + 1], f - float(i)) - h[0])

## Desplazamiento de raiz (adelante, derecha) desde el inicio del clip hasta `at`, en el marco del inicio.
func root_at(at: float) -> Vector2:
	if _path.size() < 2:
		return Vector2.ZERO
	return _at(_path, at)

## Avanza dt segundos y devuelve la velocidad de raiz (adelante, derecha) en m/s del mundo. Termina solo.
func step(dt: float) -> Vector2:
	if not active:
		return Vector2.ZERO
	var v: Vector2 = sample_velocity(t) * speed
	t += dt * speed
	elapsed += dt
	if t >= length or (cut_after > 0.0 and elapsed >= cut_after):
		active = false
	return v

## Velocidad de raiz (adelante, derecha) del clip en el instante t del clip (a velocidad 1).
func sample_velocity(at: float) -> Vector2:
	if _path.size() < 2:
		return Vector2.ZERO
	var f: float = clampf(at * 30.0, 0.0, float(_path.size() - 2))
	var i: int = int(f)
	return (_path[i + 1] - _path[i]) * 30.0

func stop() -> void:
	active = false

## Desplazamiento acumulado (adelante, derecha) entre dos instantes del clip.
static func offset_between(id: StringName, t0: float, t1: float) -> Vector2:
	var path: PackedVector2Array = PackLibrary.meta(id).get("root_path", PackedVector2Array())
	if path.size() < 2:
		return Vector2.ZERO
	return _at(path, t1) - _at(path, t0)

static func _at(path: PackedVector2Array, tt: float) -> Vector2:
	var f: float = clampf(tt * 30.0, 0.0, float(path.size() - 1))
	var i: int = mini(int(f), path.size() - 2)
	return path[i].lerp(path[i + 1], f - float(i))
