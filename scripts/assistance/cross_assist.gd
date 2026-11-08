class_name CrossAssist
extends RefCounted
## Centro desde la banda al area rival. Tres trayectorias, todas por impulso y con la fisica real de la pelota:
##  - elevado (CENTRO): parabola alta que cae a la altura de la cabeza en la zona elegida;
##  - tenso (CENTRO con carga alta): mas rapido y plano, a media altura;
##  - raso (CENTRO + ALTO): por el suelo, al punto de penal / al pie.
## La zona se elige por la intencion del joystick y por donde llegan los companeros (primer palo, segundo palo o
## punto de penal). No es teledirigido: hay error por postura, presion, potencia, pierna y atributos, y la pelota
## nunca se ajusta a la cabeza de nadie (el rematador tiene que llegar y saltar a tiempo).

const ZONES := [&"near_post", &"far_post", &"penalty_spot"]
## Altura (m) a la que el centro debe pasar por la zona al bajar.
const HEAD_HEIGHT := 1.7
const DRIVEN_HEIGHT := 1.2
const LOFT_ANGLE_DEG := 34.0
const DRIVEN_ANGLE_DEG := 15.0

## Punto de una zona del area rival, visto desde el lado del centro (side = signo de z de la pelota).
static func zone_point(ctx: MatchContext, team: int, zone: StringName, side: float) -> Vector3:
	var cfg: PitchConfig = ctx.pitch.config if ctx.pitch != null else Tuning.pitch
	var gx: float = cfg.half_length() * (1.0 if team == 0 else -1.0)
	var inward: float = -signf(gx)
	var s: float = side if absf(side) > 0.01 else 1.0
	match zone:
		&"near_post":
			return Vector3(gx + inward * 2.2, 0.0, s * (cfg.half_goal() + 0.2))
		&"far_post":
			return Vector3(gx + inward * 2.6, 0.0, -s * (cfg.half_goal() + 0.3))
		_:
			return Vector3(gx + inward * cfg.penalty_mark_distance, 0.0, 0.0)

static func compute(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, low: bool,
		rng: RandomNumberGenerator, assist_level: float, curl: float = 0.0) -> KickModel.KickResult:
	var bt: BallTuning = Tuning.ball
	var res := KickModel.KickResult.new()
	res.charge = charge
	var origin: Vector3 = ctx.ball.global_position
	var side: float = signf(origin.z)
	var intent: Vector3 = KickModel.flat(stick_dir)
	var has_stick: bool = intent.length() > 0.2
	# --- Zona: la que mejor coincide con el joystick y a la que llega un companero ---
	var best_zone: StringName = &"far_post"
	var best_score: float = -INF
	var best_mate: Footballer = null
	for z in ZONES:
		var zp: Vector3 = zone_point(ctx, kicker.team, z, side)
		var to: Vector3 = KickModel.flat(zp - origin)
		var score: float = 0.0
		if has_stick:
			score += (1.0 - KickModel.angle_between_deg(intent, to) / 90.0) * 1.5
		var mate_score: float = 0.0
		var mate: Footballer = null
		for tm in ctx.teammates_of(kicker):
			var arrive: Vector3 = KickModel.flat(tm.global_position + tm.velocity * 0.8)
			var d: float = arrive.distance_to(zp)
			var s: float = clampf(1.0 - d / 6.0, 0.0, 1.0)
			if s > mate_score:
				mate_score = s
				mate = tm
		score += mate_score * (0.6 + assist_level)
		if z == &"far_post":
			score += 0.15   # sin otra referencia, el segundo palo es el centro natural
		if low and z == &"penalty_spot":
			score += 0.4    # el raso busca el punto de penal (pase atras)
		if score > best_score:
			best_score = score
			best_zone = z
			best_mate = mate
	var target: Vector3 = zone_point(ctx, kicker.team, best_zone, side)
	res.target = best_mate
	res.aim_point = target
	var to_t: Vector3 = KickModel.flat(target - origin)
	var dist: float = to_t.length()
	var dir: Vector3 = to_t / maxf(dist, 0.01)
	if has_stick and assist_level < 1.0:
		# Con poca asistencia manda mas el joystick que la zona.
		dir = KickModel.rotate_toward(dir, intent, KickModel.angle_between_deg(dir, intent) * (1.0 - assist_level) * 0.6)
	res.intended_dir = dir
	# --- Velocidad de salida para que la trayectoria REAL pase por la zona a la altura pedida ---
	var vel: Vector3
	if low:
		res.kind = &"cross_low"
		var sp: float = clampf(KickModel.ground_speed_for_distance(dist, 5.5), bt.pass_speed_min, bt.pass_speed_max)
		vel = dir * sp
	else:
		var driven: bool = charge > 0.7
		res.kind = &"cross_driven" if driven else &"cross_high"
		var ang: float = DRIVEN_ANGLE_DEG if driven else LOFT_ANGLE_DEG
		var h: float = DRIVEN_HEIGHT if driven else HEAD_HEIGHT
		var sp2: float = launch_speed(origin, dir, ang, dist, h)
		vel = (dir * cos(deg_to_rad(ang)) + Vector3.UP * sin(deg_to_rad(ang))) * sp2
	# --- Error: el centro sale peor con presion, mala postura o a la carrera ---
	var power_mult: float = kicker.attributes.factor("long_pass", 0.12)
	var sigma: float = PassAssist._pass_sigma(kicker, dir, dist, charge) * 1.15
	res.weak_foot = KickModel.is_weak_foot(kicker, origin)
	if res.weak_foot:
		sigma *= KickModel.weak_foot_error_mult(kicker)
		vel *= KickModel.weak_foot_power_mult(kicker)
	res.sigma_deg = sigma
	res.error_deg = KickModel.gaussian_clipped(rng, sigma)
	var flat_v: Vector3 = KickModel.flat(vel).rotated(Vector3.UP, deg_to_rad(res.error_deg))
	# Error de potencia (la distancia ya esta resuelta con la fisica): mejor pase largo = menos centros pasados o cortos.
	var k: float = clampf(rng.randfn(1.0, 0.015 + 0.025 * (1.0 - kicker.attributes.norm("long_pass"))), 0.92, 1.08)
	if power_mult < 0.95:
		k *= lerpf(0.94, 1.0, clampf((power_mult - 0.85) / 0.1, 0.0, 1.0))
	vel = Vector3(flat_v.x * k, vel.y * k, flat_v.z * k)
	res.final_dir = KickModel.flat(vel).normalized()
	res.velocity = vel
	# Efecto: rosca hacia el arco (el centro se cierra) y algo de retroceso en el elevado.
	var natural: float = -signf(side) * (1.0 if kicker.team == 0 else -1.0)
	res.spin = Vector3.UP * natural * 10.0 + (-Vector3.UP.cross(res.final_dir) * 8.0 if not low else Vector3.ZERO)
	if absf(curl) > 0.01 and not low:
		# Centro con rosca pedida con el joystick: mas giro lateral (se cierra o se abre mas).
		res.curl = curl
		res.spin += KickModel.curl_spin(res.final_dir, curl, 22.0)
	return res

## Velocidad de lanzamiento (m/s) con el angulo dado para que la pelota, con arrastre, llegue a `dist` metros en el plano
## cuando baja por la altura `h`. Busqueda binaria sobre la trayectoria predicha (mismo modelo que la pelota).
static func launch_speed(origin: Vector3, dir: Vector3, angle_deg: float, dist: float, h: float) -> float:
	var lo: float = 5.0
	var hi: float = 32.0
	var a: float = deg_to_rad(angle_deg)
	var start := Vector3(origin.x, maxf(origin.y, 0.11), origin.z)
	for it in 14:
		var mid: float = (lo + hi) * 0.5
		var v: Vector3 = (dir * cos(a) + Vector3.UP * sin(a)) * mid
		var reach: float = _reach_at_height(start, v, h)
		if reach < dist:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5

## Distancia horizontal recorrida cuando la pelota, ya bajando, cruza la altura h (o donde toca el piso).
static func _reach_at_height(start: Vector3, v: Vector3, h: float) -> float:
	var traj: PackedVector3Array = BallPredictor.trajectory(start, v, 3.5, 1.0 / 60.0)
	var apex: bool = false
	for i in range(1, traj.size()):
		if traj[i].y < traj[i - 1].y:
			apex = true
		if apex and (traj[i].y <= h or traj[i].y <= 0.12):
			return Vector2(traj[i].x - start.x, traj[i].z - start.z).length()
	return Vector2(traj[traj.size() - 1].x - start.x, traj[traj.size() - 1].z - start.z).length()
