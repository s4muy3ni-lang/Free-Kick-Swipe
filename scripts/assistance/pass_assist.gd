class_name PassAssist
extends RefCounted
## Pase asistido. El jugador apunta con el joystick; el sistema elige el companero que mejor coincide
## con esa INTENCION (direccion, distancia, linea libre) y corrige de forma moderada direccion y fuerza.
## No garantiza que el pase llegue: el error depende de distancia, potencia, equilibrio,
## orientacion corporal, pierna de golpeo y atributos.

## Companero que recibiria el pase con esta intencion (direccion, distancia por la carga y linea libre); null si
## ninguno encaja en el cono (pase al espacio). Es la misma eleccion que hace compute: la usa tambien el indicador del
## objetivo del pase en pantalla, asi lo que se ve es lo que va a pasar.
static func pick_target(kicker: Footballer, ctx: MatchContext, intent: Vector3, has_stick: bool, charge: float, assist_level: float) -> Footballer:
	var cfg: AssistTuning = Tuning.assist
	if assist_level <= 0.0 or ctx.ball == null:
		return null
	var cone: float = cfg.pass_cone_deg * lerpf(0.65, 1.0, assist_level)
	if not has_stick:
		cone *= 0.75
	var best: Footballer = _pick_in_cone(kicker, ctx, intent, charge, cone)
	# Como en First Touch y Dream League: el boton de pase busca a un companero. Si ninguno cae en el cono, con asistencia
	# media o alta vale el mejor en un cono mas ancho (el pase al espacio queda para el filtrado).
	if best == null and has_stick and assist_level >= FULL_AIM_LEVEL:
		best = _pick_in_cone(kicker, ctx, intent, charge, cfg.pass_fallback_cone_deg)
	return best

## Nivel de asistencia desde el que el pase va derecho al companero elegido (Media y Alta).
const FULL_AIM_LEVEL := 0.6

static func _pick_in_cone(kicker: Footballer, ctx: MatchContext, intent: Vector3, charge: float, cone: float) -> Footballer:
	var cfg: AssistTuning = Tuning.assist
	var origin: Vector3 = ctx.ball.global_position
	var best: Footballer = null
	var best_score: float = -1.0
	var ideal: float = 4.5 + 13.0 * charge
	for tm in ctx.teammates_of(kicker):
		var to: Vector3 = KickModel.flat(tm.global_position - origin)
		var dist: float = to.length()
		if dist < 1.2 or dist > cfg.pass_max_distance:
			continue
		var ang: float = KickModel.angle_between_deg(intent, to)
		if ang > cone:
			continue
		var angle_score: float = 1.0 - ang / cone
		var dist_score: float = clampf(1.0 - absf(dist - ideal) / (ideal + 6.0), 0.0, 1.0)
		var lane_score: float = _lane_clearance(origin, tm.global_position, ctx.opponents_of(kicker), cfg.pass_lane_block_radius)
		var score: float = cfg.pass_weight_angle * angle_score + cfg.pass_weight_distance * dist_score + cfg.pass_weight_lane * lane_score
		if score > best_score:
			best_score = score
			best = tm
	return best

## Calcula un pase. stick_dir: direccion deseada en el mundo (o cero), charge: 0..1, lob: pase elevado.
## assist_level: 0 = sin ayuda ... 1 = maxima ayuda.
static func compute(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool,
		rng: RandomNumberGenerator, assist_level: float) -> KickModel.KickResult:
	var cfg: AssistTuning = Tuning.assist
	var ball_tuning: BallTuning = Tuning.ball
	var res := KickModel.KickResult.new()
	res.charge = charge
	var origin: Vector3 = ctx.ball.global_position
	var intent: Vector3 = KickModel.flat(stick_dir)
	var has_stick: bool = intent.length() > 0.2
	if not has_stick:
		intent = kicker.locomotion.forward()
	intent = intent.normalized()
	res.intended_dir = intent

	# --- 1. Elegir candidato ---
	var best: Footballer = pick_target(kicker, ctx, intent, has_stick, charge, assist_level)
	res.target = best

	# --- 2. Punto de mira y direccion ---
	var dist_to_aim: float
	var aim_dir: Vector3 = intent
	if best != null:
		var to_t: Vector3 = KickModel.flat(best.global_position - origin)
		var est_speed: float = clampf(KickModel.ground_speed_for_distance(to_t.length(), ball_tuning.pass_arrival_speed), 5.0, ball_tuning.pass_speed_max)
		var t_flight: float = clampf(Ball.roll_time(est_speed, to_t.length()), 0.1, 1.2)
		var lead: Vector3 = KickModel.flat(best.velocity) * t_flight * 0.85
		res.aim_point = best.global_position + lead
		var to_aim: Vector3 = KickModel.flat(res.aim_point - origin)
		dist_to_aim = to_aim.length()
		aim_dir = to_aim.normalized()
	else:
		# Pase al espacio: la distancia depende de la carga.
		dist_to_aim = lerpf(6.0, 20.0, charge)
		res.aim_point = origin + intent * dist_to_aim

	var final_dir: Vector3 = intent
	if best != null:
		# Con asistencia media o alta el pase va al companero elegido (el error de ejecucion se suma despues); con baja,
		# solo se acerca.
		var diff: float = KickModel.signed_angle_deg(intent, aim_dir)
		var share: float = clampf(assist_level / FULL_AIM_LEVEL, 0.0, 1.0)
		var max_corr: float = cfg.pass_max_correction_deg * assist_level if assist_level < FULL_AIM_LEVEL else 180.0
		var applied: float = clampf(diff * share, -max_corr, max_corr)
		res.assisted_correction_deg = applied
		final_dir = intent.rotated(Vector3.UP, deg_to_rad(applied))

	# --- 3. Fuerza ---
	var power_mult: float = kicker.attributes.factor("long_pass" if dist_to_aim > 11.0 else "short_pass", 0.12)
	var speed_h: float
	var vy: float = 0.0
	if lob:
		res.kind = &"lob"
		var angle: float = ball_tuning.lob_angle_deg
		var v: float = KickModel.lob_speed_for_distance(dist_to_aim, angle)
		v = clampf(v, 6.0, 20.0 * power_mult)
		speed_h = v * cos(deg_to_rad(angle))
		vy = v * sin(deg_to_rad(angle))
	else:
		res.kind = &"driven" if charge > 0.45 else (&"short" if best != null else &"space")
		# Hacia un companero se llega con velocidad de control; al espacio, la pelota debe casi detenerse alli.
		var arrival: float = ball_tuning.pass_arrival_speed if best != null else 1.5
		var v0: float = KickModel.ground_speed_for_distance(dist_to_aim, arrival)
		if best != null:
			v0 *= lerpf(1.0, ball_tuning.driven_pass_extra, charge)
		var v_min: float = ball_tuning.pass_speed_min if best != null else 4.0
		speed_h = clampf(v0, v_min, ball_tuning.pass_speed_max * power_mult)

	# --- 4. Error ---
	var acc: float = kicker.attributes.norm("pass_accuracy")
	var balance: float = KickModel.balance_state(kicker)
	var misalign: float = KickModel.misalignment(kicker, final_dir)
	var speed_ratio: float = clampf(kicker.locomotion.speed / maxf(kicker.locomotion.max_sprint_speed(), 0.1), 0.0, 1.0)
	var sigma: float = cfg.pass_error_deg * (1.45 - 0.9 * acc)
	sigma *= 0.6 + 0.4 * sqrt(maxf(dist_to_aim, 1.0) / 8.0)
	sigma *= 1.0 + 0.9 * (1.0 - balance)
	sigma *= 1.0 + 0.6 * misalign
	sigma *= 1.0 + 0.5 * speed_ratio * speed_ratio
	sigma *= 1.0 + 0.45 * charge * charge
	sigma *= lerpf(1.1, 0.88, kicker.attributes.norm("composure"))
	# Con un rival encima el pase sale peor (pase de emergencia bajo presion).
	sigma *= 1.0 + 0.5 * pressure(kicker)
	res.weak_foot = KickModel.is_weak_foot(kicker, origin)
	if res.weak_foot:
		sigma *= KickModel.weak_foot_error_mult(kicker)
		speed_h *= KickModel.weak_foot_power_mult(kicker)
	res.sigma_deg = sigma
	var err_deg: float = KickModel.gaussian_clipped(rng, sigma)
	res.error_deg = err_deg
	final_dir = final_dir.rotated(Vector3.UP, deg_to_rad(err_deg))
	speed_h *= clampf(rng.randfn(1.0, 0.025 + 0.025 * (1.0 - acc)), 0.9, 1.1)
	res.final_dir = final_dir

	res.velocity = Vector3(final_dir.x * speed_h, vy, final_dir.z * speed_h)
	if lob:
		# Efecto hacia atras (backspin) leve para que el balon frene al caer.
		var side_axis: Vector3 = Vector3.UP.cross(final_dir)
		res.spin = -side_axis * 18.0
	else:
		res.spin = Vector3.UP.cross(KickModel.flat(res.velocity)) / maxf(ball_tuning.radius, 0.01)
	return res

## Pase filtrado: la pelota va al ESPACIO por delante del desmarque del receptor (hacia el arco rival), buscando el
## hueco entre defensores. El receptor no recibe al pie: tiene que llegar corriendo. Con `lob` es un filtrado por alto
## (por encima de la defensa). La precision depende de lo mismo que el pase normal y algo mas (pase arriesgado).
static func compute_through(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool,
		rng: RandomNumberGenerator, assist_level: float) -> KickModel.KickResult:
	var cfg: AssistTuning = Tuning.assist
	var bt: BallTuning = Tuning.ball
	var res := KickModel.KickResult.new()
	res.charge = charge
	var origin: Vector3 = ctx.ball.global_position
	var atk := Vector3(1.0 if kicker.team == 0 else -1.0, 0.0, 0.0)
	var intent: Vector3 = KickModel.flat(stick_dir)
	var has_stick: bool = intent.length() > 0.2
	intent = intent.normalized() if has_stick else (kicker.locomotion.forward() * 0.5 + atk * 0.5).normalized()
	res.intended_dir = intent
	var opponents: Array[Footballer] = ctx.opponents_of(kicker)
	# --- Receptor: companero en el cono de la intencion, mejor cuanto mas adelantado y con espacio por delante ---
	var best: Footballer = null
	var best_score: float = -INF
	var cone: float = cfg.pass_cone_deg * lerpf(0.75, 1.15, assist_level)
	for tm in ctx.teammates_of(kicker):
		var to: Vector3 = KickModel.flat(tm.global_position - origin)
		var dist: float = to.length()
		if dist < 2.5 or dist > cfg.pass_max_distance:
			continue
		var ang: float = KickModel.angle_between_deg(intent, to)
		if ang > cone:
			continue
		var progress: float = to.dot(atk)
		var space: float = _space_ahead(tm, atk, opponents)
		var score: float = (1.0 - ang / cone) * 1.2 + clampf(progress / 12.0, -0.5, 1.0) + clampf(space / 6.0, 0.0, 1.0)
		if score > best_score:
			best_score = score
			best = tm
	res.target = best
	# --- Punto al espacio: delante del receptor en la direccion de su carrera (o hacia el arco) ---
	var lead: float = lerpf(3.0, 8.5, charge)
	var aim: Vector3
	if best != null:
		var run: Vector3 = KickModel.flat(best.velocity)
		var run_dir: Vector3 = run.normalized() if run.length() > 1.5 and run.normalized().dot(atk) > -0.2 else atk
		# El joystick inclina la direccion del desmarque (diagonal hacia dentro o hacia la banda).
		if has_stick:
			run_dir = (run_dir + intent * 0.6).normalized()
		aim = best.global_position + run_dir * lead
		# Hueco entre defensores: se prueban desplazamientos laterales y se queda el de linea mas limpia.
		var side := Vector3(-run_dir.z, 0.0, run_dir.x)
		var best_aim: Vector3 = aim
		var best_clear: float = -1.0
		for off in [0.0, 1.2, -1.2, 2.4, -2.4]:
			var cand: Vector3 = aim + side * off
			var clear: float = _lane_clearance(origin, cand, opponents, cfg.pass_lane_block_radius) - absf(off) * 0.04
			if clear > best_clear + 0.05:
				best_clear = clear
				best_aim = cand
		aim = best_aim
	else:
		aim = origin + intent * lerpf(8.0, 18.0, charge)
	if ctx.pitch != null:
		aim = ctx.pitch.clamp_to_pitch(aim, 1.0)
	aim.y = 0.0
	res.aim_point = aim
	var to_aim: Vector3 = KickModel.flat(aim - origin)
	var dist_to_aim: float = to_aim.length()
	var final_dir: Vector3 = intent
	var aim_dir: Vector3 = to_aim.normalized() if dist_to_aim > 0.1 else intent
	var diff: float = KickModel.signed_angle_deg(intent, aim_dir)
	var max_corr: float = (cfg.pass_max_correction_deg + 8.0) * assist_level
	var applied: float = clampf(diff * maxf(assist_level, 0.35 if best != null else 0.0), -max_corr, max_corr)
	if not has_stick:
		applied = diff
	res.assisted_correction_deg = applied
	final_dir = intent.rotated(Vector3.UP, deg_to_rad(applied))
	# --- Fuerza: llegar al punto con velocidad de carrera (el receptor la recoge en movimiento) ---
	var power_mult: float = kicker.attributes.factor("long_pass" if dist_to_aim > 11.0 else "short_pass", 0.12)
	var speed_h: float
	var vy: float = 0.0
	if lob:
		res.kind = &"through_lob"
		var angle: float = 30.0
		var v: float = clampf(KickModel.lob_speed_for_distance(dist_to_aim * 0.92, angle), 6.0, 20.0 * power_mult)
		speed_h = v * cos(deg_to_rad(angle))
		vy = v * sin(deg_to_rad(angle))
	else:
		res.kind = &"through"
		speed_h = clampf(KickModel.ground_speed_for_distance(dist_to_aim, 2.6), bt.pass_speed_min, bt.pass_speed_max * power_mult)
	# --- Error: como un pase, algo mayor por ser un envio arriesgado ---
	var sigma: float = _pass_sigma(kicker, final_dir, dist_to_aim, charge) * 1.12
	res.weak_foot = KickModel.is_weak_foot(kicker, origin)
	if res.weak_foot:
		sigma *= KickModel.weak_foot_error_mult(kicker)
		speed_h *= KickModel.weak_foot_power_mult(kicker)
	res.sigma_deg = sigma
	res.error_deg = KickModel.gaussian_clipped(rng, sigma)
	final_dir = final_dir.rotated(Vector3.UP, deg_to_rad(res.error_deg))
	speed_h *= clampf(rng.randfn(1.0, 0.035), 0.9, 1.1)
	res.final_dir = final_dir
	res.velocity = Vector3(final_dir.x * speed_h, vy, final_dir.z * speed_h)
	if lob:
		res.spin = -Vector3.UP.cross(final_dir) * 16.0
	else:
		res.spin = Vector3.UP.cross(KickModel.flat(res.velocity)) / maxf(bt.radius, 0.01)
	return res

## Desviacion tipica (grados) del error de un pase: precision, distancia, equilibrio, orientacion, velocidad, potencia y
## compostura. La comparten el pase normal, el filtrado y el centro.
static func _pass_sigma(kicker: Footballer, dir: Vector3, dist: float, charge: float) -> float:
	var cfg: AssistTuning = Tuning.assist
	var acc: float = kicker.attributes.norm("pass_accuracy")
	var speed_ratio: float = clampf(kicker.locomotion.speed / maxf(kicker.locomotion.max_sprint_speed(), 0.1), 0.0, 1.0)
	var sigma: float = cfg.pass_error_deg * (1.45 - 0.9 * acc)
	sigma *= 0.6 + 0.4 * sqrt(maxf(dist, 1.0) / 8.0)
	sigma *= 1.0 + 0.9 * (1.0 - KickModel.balance_state(kicker))
	sigma *= 1.0 + 0.6 * KickModel.misalignment(kicker, dir)
	sigma *= 1.0 + 0.5 * speed_ratio * speed_ratio
	sigma *= 1.0 + 0.45 * charge * charge
	sigma *= lerpf(1.1, 0.88, kicker.attributes.norm("composure"))
	sigma *= 1.0 + 0.5 * pressure(kicker)
	return sigma

## Presion rival sobre un jugador (0 = nadie cerca, 1 = rival encima): sube el error de pases, centros y tiros.
static func pressure(kicker: Footballer) -> float:
	if kicker.ctx == null:
		return 0.0
	var best: float = INF
	for o in kicker.ctx.footballers:
		if o.team != kicker.team:
			best = minf(best, KickModel.flat(o.global_position - kicker.global_position).length())
	return clampf((2.6 - best) / 1.8, 0.0, 1.0)

## Metros libres por delante de un jugador (hacia el arco rival) antes del rival mas cercano a su carril.
static func _space_ahead(p: Footballer, atk: Vector3, opponents: Array[Footballer]) -> float:
	var best: float = 12.0
	for o in opponents:
		var d: Vector3 = KickModel.flat(o.global_position - p.global_position)
		var ahead: float = d.dot(atk)
		if ahead > -0.5 and absf(d.z * atk.x - d.x * atk.z) < 3.0:
			best = minf(best, maxf(ahead, 0.0))
	return best

## 1.0 = linea totalmente libre; baja cuanto mas cerca de la linea de pase este un rival.
static func _lane_clearance(from_pos: Vector3, to_pos: Vector3, opponents: Array[Footballer], block_radius: float) -> float:
	var a := Vector2(from_pos.x, from_pos.z)
	var b := Vector2(to_pos.x, to_pos.z)
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	var clearance: float = 1.0
	for o in opponents:
		var p := Vector2(o.global_position.x, o.global_position.z)
		var t: float = clampf((p - a).dot(ab) / maxf(len2, 0.0001), 0.0, 1.0)
		# Ignorar rivales casi sobre el receptor o sobre quien patea.
		if t < 0.08 or t > 0.98:
			continue
		var d: float = (a + ab * t).distance_to(p)
		if d < block_radius * 2.0:
			clearance = minf(clearance, clampf(d / (block_radius * 2.0), 0.0, 1.0))
	return clearance
