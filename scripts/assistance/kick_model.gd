class_name KickModel
extends RefCounted
## Utilidades compartidas por pases y tiros: geometria en el plano XZ, error por atributos,
## equilibrio, pie de golpeo. La precision NUNCA es perfecta: depende de distancia, potencia,
## equilibrio, orientacion del cuerpo y atributos.

const G: float = 9.81

## Resultado de calcular un golpe. No toca la pelota: quien lo ejecuta decide.
class KickResult:
	extends RefCounted
	var velocity: Vector3 = Vector3.ZERO
	var spin: Vector3 = Vector3.ZERO
	var kind: StringName = &"pass"
	var target: Footballer = null
	var aim_point: Vector3 = Vector3.ZERO
	var intended_dir: Vector3 = Vector3.ZERO
	var final_dir: Vector3 = Vector3.ZERO
	var error_deg: float = 0.0
	var sigma_deg: float = 0.0
	var assisted_correction_deg: float = 0.0
	var weak_foot: bool = false
	var charge: float = 0.0
	var on_target: bool = false
	## Efecto aplicado (-1..1, positivo = curva a la derecha del golpeo).
	var curl: float = 0.0
	## Tiro sin giro que "flota" (knuckle): aceleracion lateral oscilante (m/s^2), frecuencia (Hz) y fase (rad). 0 = no.
	var knuckle_accel: float = 0.0
	var knuckle_freq: float = 0.0
	var knuckle_phase: float = 0.0

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

static func angle_between_deg(a: Vector3, b: Vector3) -> float:
	var fa: Vector3 = flat(a)
	var fb: Vector3 = flat(b)
	if fa.length_squared() < 0.0001 or fb.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(absf(fa.signed_angle_to(fb, Vector3.UP)))

static func signed_angle_deg(from_dir: Vector3, to_dir: Vector3) -> float:
	var fa: Vector3 = flat(from_dir)
	var fb: Vector3 = flat(to_dir)
	if fa.length_squared() < 0.0001 or fb.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(fa.signed_angle_to(fb, Vector3.UP))

## Gira "dir" hacia "target_dir" como maximo max_deg grados (plano XZ).
static func rotate_toward(dir: Vector3, target_dir: Vector3, max_deg: float) -> Vector3:
	var diff: float = signed_angle_deg(dir, target_dir)
	var applied: float = clampf(diff, -max_deg, max_deg)
	return flat(dir).normalized().rotated(Vector3.UP, deg_to_rad(applied))

static func gaussian_clipped(rng: RandomNumberGenerator, sigma: float, clip: float = 2.2) -> float:
	return clampf(rng.randfn(0.0, sigma), -sigma * clip, sigma * clip)

## Efecto lateral (chanfle): giro sobre el eje vertical que curva la pelota a la derecha (curl > 0) o a la izquierda del
## golpeo por el efecto Magnus REAL de la pelota (Ball._integrate_forces), y angulo (grados) a "abrir" la salida para que
## la curva la devuelva al objetivo. spin_rad: giro maximo (rad/s) del golpeo.
static func curl_spin(dir: Vector3, curl: float, spin_rad: float) -> Vector3:
	# w = (0, wy, 0): w x v = wy * (UP x v) = -wy * derecha * |v|. Para curvar a la derecha wy debe ser negativo.
	return Vector3.UP * (-curl * spin_rad)

## Desvio lateral (m) acumulado por el efecto al recorrer `dist` m a velocidad horizontal `vh` (con algo de arrastre).
static func curl_offset(dist: float, vh: float, curl: float, spin_rad: float) -> float:
	var bt: BallTuning = Tuning.ball
	var a_lat: float = bt.magnus_k / bt.mass * absf(curl) * spin_rad * vh
	var t: float = dist / maxf(vh * 0.92, 1.0)
	return 0.5 * a_lat * t * t * 0.9

## Angulo (grados, con signo para KickModel: positivo = izquierda) para abrir la salida y que la curva cierre sobre el objetivo.
static func curl_preaim_deg(dist: float, vh: float, curl: float, spin_rad: float) -> float:
	var off: float = curl_offset(dist, vh, curl, spin_rad)
	return clampf(rad_to_deg(atan2(off, maxf(dist, 1.0))) * signf(curl), -22.0, 22.0)

## 1.0 = totalmente equilibrado. Baja con giros bruscos, frenadas y cansancio.
static func balance_state(f: Footballer) -> float:
	var loc: Locomotion = f.locomotion
	var unstable: float = clampf(absf(loc.turn_rate) / 7.0, 0.0, 0.45)
	if loc.braking:
		unstable += 0.15
	if loc.exhausted:
		unstable += 0.1
	unstable *= 1.0 - f.attributes.norm("balance") * 0.5
	return clampf(1.0 - unstable, 0.35, 1.0)

## Proporcion de desalineacion entre el cuerpo y la direccion del golpe (0..1).
static func misalignment(f: Footballer, dir: Vector3) -> float:
	return clampf(angle_between_deg(f.locomotion.forward(), dir) / 180.0, 0.0, 1.0)

## True si golpea con el pie derecho: el del lado del cuerpo en el que esta la pelota. Con la pelota por delante del
## centro del cuerpo (a menos de 5 cm de su eje) golpea con el bueno.
static func kicks_with_right(f: Footballer, ball_pos: Vector3) -> bool:
	var side: float = flat(ball_pos - f.global_position).dot(f.locomotion.right())
	if absf(side) < 0.05:
		return f.dominant_right
	return side > 0.0

## True si el balon queda del lado del pie no dominante.
static func is_weak_foot(f: Footballer, ball_pos: Vector3) -> bool:
	return kicks_with_right(f, ball_pos) != f.dominant_right

## Penalizacion de la pierna debil segun el atributo (1.0 = sin penalizacion).
static func weak_foot_error_mult(f: Footballer) -> float:
	return lerpf(1.9, 1.08, f.attributes.norm("weak_foot"))

static func weak_foot_power_mult(f: Footballer) -> float:
	return lerpf(0.84, 0.98, f.attributes.norm("weak_foot"))

## Velocidad inicial (m/s) para recorrer d metros por el suelo y llegar con "arrival" m/s.
## Modelo de la pelota: desaceleracion = rodadura (Ball.roll_decel: constante + proporcional a v hasta un tope) + k v^2
## (arrastre del aire, con k = 0.5 rho Cd A / m y la escala efectiva medida de BallPredictor). Se integra
## v dv/dx = -(rodadura + k v^2) hacia atras desde la llegada (RK4).
static func ground_speed_for_distance(d: float, arrival: float) -> float:
	var bt: BallTuning = Tuning.ball
	var k: float = BallPredictor.DRAG_SCALE * 0.5 * bt.air_density * bt.drag_coefficient * PI * bt.radius * bt.radius / bt.mass
	var v: float = maxf(arrival, 0.3)
	var n: int = 40
	var h: float = maxf(d, 0.0) / float(n)
	for i in n:
		var k1: float = (Ball.roll_decel(v) + k * v * v) / v
		var v2: float = v + 0.5 * h * k1
		var k2: float = (Ball.roll_decel(v2) + k * v2 * v2) / v2
		var v3: float = v + 0.5 * h * k2
		var k3: float = (Ball.roll_decel(v3) + k * v3 * v3) / v3
		var v4: float = v + h * k3
		var k4: float = (Ball.roll_decel(v4) + k * v4 * v4) / v4
		v += h * (k1 + 2.0 * k2 + 2.0 * k3 + k4) / 6.0
	return maxf(v, arrival)

## Velocidad de lanzamiento para un pase elevado que cubre d metros con el angulo dado (grados).
static func lob_speed_for_distance(d: float, angle_deg: float) -> float:
	var s2: float = sin(deg_to_rad(angle_deg * 2.0))
	return sqrt(maxf(d, 0.5) * G / maxf(s2, 0.05)) * 1.1
