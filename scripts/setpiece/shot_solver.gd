class_name ShotSolver
extends RefCounted
## Convierte la intencion del tiro (punto del arco al que apunta el trazo, velocidad de salida y giro) en la velocidad
## inicial de la pelota, usando el MISMO modelo de vuelo que la pelota (BallPredictor: gravedad, arrastre y Magnus). No
## garantiza el resultado: si con esa velocidad no se puede llegar (muy lejos, demasiado alto) devuelve el mejor intento y
## la fisica decide. La pelota sale con Ball.kick en el instante de contacto del pie (nunca se teletransporta).

const STEP := 1.0 / 60.0
const HORIZON := 3.5
const ITERATIONS := 12

## Resultado: {velocity, crossing (punto donde cruza el plano del arco o Vector3.INF), error (m), trajectory}.
## iterations/step: la vista previa usa menos iteraciones y un paso mas grueso (mismo modelo).
static func solve(ball: Vector3, target: Vector3, speed: float, spin: Vector3, plane_x: float, iterations: int = ITERATIONS,
		step: float = STEP) -> Dictionary:
	var to: Vector3 = target - ball
	var dist_h: float = Vector2(to.x, to.z).length()
	var yaw: float = atan2(to.z, to.x)
	var pitch: float = _ballistic_pitch(dist_h, to.y, speed)
	var best: Dictionary = {}
	var best_err: float = INF
	for it in iterations:
		var v: Vector3 = _vel(yaw, pitch, speed)
		var traj: PackedVector3Array = BallPredictor.trajectory(ball, v, HORIZON, step, spin, true)
		var cross: Vector3 = crossing(traj, plane_x)
		var err: float
		if cross == Vector3.INF:
			# No llega al plano del arco (se queda corta): mas alto.
			pitch = minf(pitch + 0.06, 0.9)
			err = 1e6
		else:
			var ez: float = target.z - cross.z
			var ey: float = target.y - cross.y
			err = Vector2(ez, ey).length()
			# Correccion proporcional (la distancia convierte metros en radianes).
			var d: float = maxf(absf(plane_x - ball.x), 3.0)
			yaw += clampf(ez / d, -0.2, 0.2) * signf(plane_x - ball.x)
			pitch += clampf(ey / d, -0.2, 0.2) * 0.9
			pitch = clampf(pitch, -0.15, 0.9)
		if err < best_err:
			best_err = err
			best = {"velocity": v, "crossing": cross, "error": err, "trajectory": traj}
		if err < 0.03:
			break
	return best

## Punto donde la trayectoria cruza el plano x = plane_x (interpolado) o Vector3.INF.
static func crossing(traj: PackedVector3Array, plane_x: float) -> Vector3:
	for i in range(1, traj.size()):
		var a: Vector3 = traj[i - 1]
		var b: Vector3 = traj[i]
		if (a.x - plane_x) * (b.x - plane_x) <= 0.0 and a.x != b.x:
			var u: float = (plane_x - a.x) / (b.x - a.x)
			return a.lerp(b, u)
	return Vector3.INF

## Tiempo (s) hasta que la trayectoria cruza el plano (o -1).
static func crossing_time(traj: PackedVector3Array, plane_x: float, step: float = STEP) -> float:
	for i in range(1, traj.size()):
		var a: Vector3 = traj[i - 1]
		var b: Vector3 = traj[i]
		if (a.x - plane_x) * (b.x - plane_x) <= 0.0 and a.x != b.x:
			return (float(i - 1) + (plane_x - a.x) / (b.x - a.x)) * step
	return -1.0

static func _vel(yaw: float, pitch: float, speed: float) -> Vector3:
	return Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch)) * speed

## Angulo de elevacion (rad) del tiro raso de un proyectil sin aire que sube dy en dist metros a `speed` (primera
## aproximacion; el bucle corrige el arrastre y el efecto).
static func _ballistic_pitch(dist: float, dy: float, speed: float) -> float:
	var g: float = 9.81
	var v2: float = speed * speed
	var disc: float = v2 * v2 - g * (g * dist * dist + 2.0 * dy * v2)
	if disc < 0.0 or dist < 0.01:
		return 0.6
	return atan((v2 - sqrt(disc)) / (g * dist))

## Desvio aleatorio del tiro (precision del tirador): gira la direccion `sigma_deg` grados (normal) en horizontal y algo
## menos en vertical.
static func perturb(v: Vector3, sigma_deg: float, rng: RandomNumberGenerator) -> Vector3:
	if sigma_deg <= 0.0:
		return v
	var yaw_e: float = deg_to_rad(rng.randfn(0.0, sigma_deg))
	var pitch_e: float = deg_to_rad(rng.randfn(0.0, sigma_deg * 0.7))
	var h := Vector3(v.x, 0.0, v.z)
	var side := Vector3(-h.z, 0.0, h.x).normalized() if h.length() > 0.01 else Vector3.RIGHT
	return v.rotated(Vector3.UP, yaw_e).rotated(side, -pitch_e)

## Clasifica el cruce de la trayectoria con el arco (marco local: z lateral, y altura): "in", "post" (rozando el marco),
## "wide", "high" o "short".
static func classify(cross: Vector3, half_goal: float, height: float, radius: float) -> String:
	if cross == Vector3.INF:
		return "short"
	if cross.y > height + radius:
		return "high"
	if absf(cross.z) > half_goal + radius:
		return "wide"
	if absf(cross.z) > half_goal - radius or cross.y > height - radius:
		return "post"
	return "in"
