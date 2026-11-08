class_name ShotAssist
extends RefCounted
## Tiro asistido. El jugador apunta con el joystick; si esa intencion apunta al arco (o cerca),
## se corrige MODERADAMENTE la direccion hacia un punto razonable del arco y se ajusta la altura.
## La asistencia se desvanece cuando el usuario apunta claramente fuera del arco y nunca convierte
## un tiro en gol: hay error por potencia, equilibrio, orientacion, pierna y atributos; la pelota
## puede pegar en los postes, ser atajada o irse desviada.

## Asistencia a partir de la cual el tiro va del todo al punto de mira elegido (por debajo se mezcla con la direccion
## del joystick; 0 = tiro manual, exactamente hacia donde apunta).
const ASSIST_FULL := 0.4
## Fraccion del ancho util del arco a la que apunta el joystick hacia un palo: cerca del palo pero por dentro (como
## FIFA/PES con asistencia), de AIM_EDGE (tirador de 1) a 1.0 (de 99) segun precision y definicion: el buen tirador la
## pone mas cerca del palo. Al borde del ancho util (0.28 m del palo) la mitad de los tiros a 11 m de un tirador de 60
## se iban fuera con el error normal de la ejecucion (medido: 7 de 12); a 0.9 el de 85 apuntaba donde llega el arquero
## (2 goles de 40 al palo hacia el que su empeine la cierra, frente a 8 con el borde por calidad).
const AIM_EDGE := 0.85
## Aumento del error del tiro con un rival encima (presion 1 = a menos de 0.8 m): x1.8.
const SHOT_PRESSURE_ERROR := 0.8
## Potencia que pierde un tiro con un rival encima (presion 1): no se puede armar ni plantar bien el pie. Con el tiro mas
## fuerte (2026-10-29: 12-30 m/s) el apurado salia igual de fuerte y, mas abierto por el error, entraba mas que sin rival.
const SHOT_PRESSURE_POWER := 0.12
## La potencia crece con la carga elevada a este exponente: el tiro flojo y el de carga completa son mas fuertes que antes
## (12 y 30 m/s, antes 9 y 27) y el de media carga queda casi igual (~20 m/s a 0.6), asi el arquero sigue atajando lo que
## va a su cuerpo (medido: con la potencia lineal 12-30 atajaba el 63 % de los tiros al arquero desde 11 m; antes el 89 %).
const SHOT_POWER_CURVE := 1.5

## Giro maximo (rad/s) de un tiro con efecto (chanfle / comba): con el Magnus de la pelota curva 1.5-3 m en 15-20 m.
const CURL_SPIN_MIN := 38.0
const CURL_SPIN_MAX := 58.0
## Efecto natural del golpeo sin efecto pedido (rad/s). Con el empeine la pelota gira hacia el lado del pie que golpea
## (diestro: se cierra a la izquierda) y mas cuanto mas cruza el tiro por delante del cuerpo: curva 0.1-0.3 m en 11 m.
const NATURAL_CURL_MIN := 8.0
const NATURAL_CURL_MAX := 16.0
## Cruce (grados entre el frente del cuerpo y el tiro, hacia el lado contrario al pie) con el efecto natural maximo.
const NATURAL_CURL_ACROSS_DEG := 40.0
## Rosca del tiro colocado (interior del pie), hacia el lado del pie: curva ~0.5 m en 11 m.
const PLACED_CURL_SPIN := 26.0
## Contragiro de la vaselina (rad/s): la pelota flota algo mas y frena al botar.
const LOB_BACKSPIN := 20.0
## Contragiro del tiro de empeine a media altura (rad/s).
const DRIVE_BACKSPIN := 14.0
## Tiro potente con el empeine por el centro de la pelota: casi sin giro y con el "flotado" (knuckle) de las pelotas
## rapidas sin giro. Aceleracion lateral oscilante (m/s^2) a partir de TIRO_KNUCKLE_SPEED m/s y su frecuencia (Hz):
## desvia la pelota 0.1-0.3 m en 18 m, a un lado o al otro, sin que el arquero lo pueda prever.
const KNUCKLE_ACCEL := 5.0
const KNUCKLE_SPEED := 18.0
const KNUCKLE_FREQ_MIN := 1.4
const KNUCKLE_FREQ_MAX := 2.6
## Altura de salida (vy, m/s) a partir de la cual la pelota va por el aire lo bastante como para que el efecto la curve:
## solo entonces se abre la salida para que la curva cierre sobre el punto de mira.
const CURL_AIR_VY := 2.0

static func compute(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool,
		rng: RandomNumberGenerator, assist_level: float, curl: float = 0.0) -> KickModel.KickResult:
	var cfg: AssistTuning = Tuning.assist
	var bt: BallTuning = Tuning.ball
	var pitch_cfg: PitchConfig = Tuning.pitch
	var res := KickModel.KickResult.new()
	res.kind = &"lob_shot" if lob else &"shot"
	res.charge = charge
	var origin: Vector3 = ctx.ball.global_position
	var intent: Vector3 = KickModel.flat(stick_dir)
	if intent.length() < 0.2:
		intent = kicker.locomotion.forward()
	intent = intent.normalized()
	res.intended_dir = intent

	var goal: Goal = ctx.attacking_goal(kicker.team)
	var goal_x: float = goal.global_position.x
	var to_goal_x: float = goal_x - origin.x
	var dist_goal: float = absf(to_goal_x)
	# Tipo de tiro por la carga: toque corto cerca del arco = tiro COLOCADO (con rosca al palo lejano, mas lento y
	# preciso); carga alta = tiro POTENTE (mas rapido y menos preciso). En medio, el tiro normal.
	var placed: bool = not lob and charge < 0.3 and dist_goal < 14.0
	var power: bool = not lob and charge > 0.8
	if placed:
		res.kind = &"placed_shot"
	elif power:
		res.kind = &"power_shot"
	var usable: float = maxf(pitch_cfg.half_goal() - cfg.shot_post_margin, 0.1)

	# --- Punto de mira: SIEMPRE dentro del arco (como PES y FIFA con asistencia) ---
	# El joystick elige el punto: donde su direccion cruza la linea de gol; apuntando fuera del arco, el palo de ese lado
	# (un tiro al palo con el error de la ejecucion puede irse fuera). Sin direccion clara hacia un lado (joystick hacia
	# el centro del arco o suelto) se elige el lado contrario al arquero. La precision la dan la ejecucion y la situacion
	# (error mas abajo), no lo bien que se apunta: apuntar no es acertar.
	var edge: float = aim_edge(kicker)
	var lateral: float = _stick_lateral(intent, origin, goal, usable) * edge
	var stick_set: bool = KickModel.flat(stick_dir).length() >= 0.2 and absf(lateral) >= 0.22 * edge
	var weight: float = clampf(assist_level / ASSIST_FULL, 0.0, 1.0)
	if placed and not stick_set:
		# Colocado sin lado pedido: al palo lejano respecto de la posicion de la pelota (cerrando hacia dentro).
		lateral = -signf(origin.z) * 0.8 if absf(origin.z) > 0.5 else (1.0 if rng.randf() < 0.5 else -1.0) * 0.8
	elif not stick_set:
		var keeper: Node = ctx.keeper_defending(1 - kicker.team)
		var side: float = 1.0
		if keeper != null:
			var kz: float = (keeper as Node3D).global_position.z
			side = -signf(kz) if absf(kz) > 0.15 else (1.0 if rng.randf() < 0.5 else -1.0)
		lateral = side * 0.62
	var height_ratio: float = 0.88 if lob else lerpf(0.08, 0.5, clampf(charge * 0.75, 0.0, 1.0))
	if dist_goal < 4.0 and not lob:
		height_ratio = minf(height_ratio, 0.3)
	res.aim_point = goal.aim_point(lateral, height_ratio, cfg.shot_post_margin)

	# --- Direccion final: hacia el punto de mira (asistencia completa) o la del joystick (manual) ---
	var final_dir: Vector3 = intent
	var aim_dir: Vector3 = KickModel.flat(res.aim_point - origin).normalized()
	if weight > 0.0 and aim_dir.length() > 0.5:
		var diff: float = KickModel.signed_angle_deg(intent, aim_dir)
		res.assisted_correction_deg = diff * weight
		final_dir = intent.rotated(Vector3.UP, deg_to_rad(diff * weight))

	# --- Potencia ---
	var power_mult: float = kicker.attributes.factor("shot_power", 0.14)
	var speed: float = lerpf(bt.shot_speed_min, bt.shot_speed_max, pow(clampf(charge, 0.0, 1.0), SHOT_POWER_CURVE)) * power_mult
	if placed:
		speed = maxf(speed, lerpf(bt.shot_speed_min, bt.shot_speed_max, 0.25) * power_mult)
	res.weak_foot = KickModel.is_weak_foot(kicker, origin)
	if res.weak_foot:
		speed *= KickModel.weak_foot_power_mult(kicker)
	speed *= 1.0 - SHOT_PRESSURE_POWER * PassAssist.pressure(kicker)
	speed = minf(speed, bt.shot_speed_max * 1.2)

	# --- Error ---
	var acc: float = kicker.attributes.norm("shot_accuracy")
	var fin: float = kicker.attributes.norm("finishing")
	var balance: float = KickModel.balance_state(kicker)
	var misalign: float = KickModel.misalignment(kicker, final_dir)
	var speed_ratio: float = clampf(kicker.locomotion.speed / maxf(kicker.locomotion.max_sprint_speed(), 0.1), 0.0, 1.0)
	var sigma: float = cfg.shot_error_deg * (1.5 - 0.9 * acc)
	sigma *= 1.0 + 0.9 * charge * charge
	sigma *= 1.0 + 0.8 * (1.0 - balance)
	sigma *= 1.0 + 0.7 * misalign
	sigma *= 1.0 + 0.5 * speed_ratio * speed_ratio
	if dist_goal < 10.0:
		sigma *= lerpf(1.15, 0.85, fin)
	sigma *= lerpf(1.1, 0.88, kicker.attributes.norm("composure"))
	# Presion rival encima: el tiro sale peor (como en FIFA/PES, tirar con un rival pegado es arriesgado).
	sigma *= 1.0 + SHOT_PRESSURE_ERROR * PassAssist.pressure(kicker)
	if placed:
		sigma *= 0.72
	if res.weak_foot:
		sigma *= KickModel.weak_foot_error_mult(kicker)
	res.sigma_deg = sigma
	var err_h: float = KickModel.gaussian_clipped(rng, sigma)
	var err_v: float = KickModel.gaussian_clipped(rng, sigma * 0.6)
	res.error_deg = err_h
	final_dir = final_dir.rotated(Vector3.UP, deg_to_rad(err_h))
	# --- Efecto (chanfle): la salida se abre hacia el lado contrario y la curva la devuelve al arco ---
	var curl_rad: float = 0.0
	if absf(curl) > 0.01 and not lob:
		res.curl = curl
		var tech: float = 0.5 * kicker.attributes.norm("shot_accuracy") + 0.5 * kicker.attributes.norm("finishing")
		curl_rad = lerpf(CURL_SPIN_MIN, CURL_SPIN_MAX, tech)
		var d_aim: float = KickModel.flat(res.aim_point - origin).length()
		var vh_est: float = speed * cos(deg_to_rad(bt.shot_loft_low_deg))
		final_dir = final_dir.rotated(Vector3.UP, deg_to_rad(KickModel.curl_preaim_deg(d_aim, vh_est, curl, curl_rad)))
		res.kind = &"curl_shot"

	# --- Altura / trayectoria ---
	var v_h: float = speed * cos(deg_to_rad(lerpf(bt.shot_loft_low_deg, bt.shot_loft_high_deg, 1.0 if lob else 0.0)))
	var default_vy: float = speed * sin(deg_to_rad(bt.shot_loft_high_deg if lob else bt.shot_loft_low_deg))
	var vy: float = default_vy
	if weight > 0.0:
		var d_h: float = KickModel.flat(res.aim_point - origin).length()
		if d_h > 1.2:
			var tf: float = d_h / maxf(v_h * 0.95, 1.0)
			var vy_needed: float = (res.aim_point.y - maxf(origin.y, 0.1) + 0.5 * KickModel.G * tf * tf) / tf
			vy = lerpf(default_vy, vy_needed, clampf(assist_level * weight * 0.9, 0.0, 1.0))
	vy = clampf(vy, -1.0, speed * sin(deg_to_rad(40.0)))
	vy += v_h * tan(deg_to_rad(err_v))
	vy = maxf(vy, 0.0)
	if curl_rad > 0.0:
		# El efecto solo actua en el aire: el tiro con chanfle sale algo levantado.
		vy = maxf(vy, 3.4)
	v_h = sqrt(maxf(speed * speed - vy * vy, 0.25 * speed * speed))

	# --- Giro de la pelota segun el golpeo (el efecto Magnus de la fisica de la pelota hace el resto) ---
	var line_dir: Vector3 = final_dir
	# Giro lateral del golpe imperfecto (no se le pega justo por el eje): rosca de vuelta hacia el punto de mira.
	var err_side_spin: float = -err_h * bt.shot_spin_factor * 0.25
	var backspin: Vector3 = -Vector3.UP.cross(final_dir)
	var knuckle: bool = power and curl_rad <= 0.0 and speed > KNUCKLE_SPEED
	if lob:
		# Vaselina: por debajo de la pelota, con contragiro.
		res.spin = backspin * LOB_BACKSPIN + Vector3.UP * err_side_spin
	elif curl_rad > 0.0:
		# Chanfle pedido: el giro lateral sustituye al de rodadura (la pelota va por el aire y el Magnus la curva).
		res.spin = KickModel.curl_spin(final_dir, curl, curl_rad) - Vector3.UP.cross(final_dir) * 6.0
	elif knuckle:
		# Potente con el empeine por el centro: casi sin giro (se ven los gajos) y la pelota "flota".
		res.spin = backspin * 3.0 + Vector3.UP * err_side_spin * 0.15
		res.knuckle_accel = KNUCKLE_ACCEL * clampf((speed - KNUCKLE_SPEED) / 7.0, 0.0, 1.0) * rng.randf_range(0.5, 1.0)
		res.knuckle_freq = rng.randf_range(KNUCKLE_FREQ_MIN, KNUCKLE_FREQ_MAX)
		res.knuckle_phase = rng.randf() * TAU
	else:
		# Empeine (o interior en el colocado): rosca natural hacia el lado del pie que golpea.
		var right_foot: bool = KickModel.kicks_with_right(kicker, origin)
		var nat_curl: float = -1.0 if right_foot else 1.0
		var nat_spin: float = PLACED_CURL_SPIN
		if not placed:
			var across_deg: float = KickModel.signed_angle_deg(kicker.locomotion.forward(), final_dir) * (1.0 if right_foot else -1.0)
			nat_spin = lerpf(NATURAL_CURL_MIN, NATURAL_CURL_MAX, clampf(across_deg / NATURAL_CURL_ACROSS_DEG, 0.0, 1.0))
		if vy >= CURL_AIR_VY:
			# Por el aire la curva se nota: la salida se abre lo justo para que cierre sobre el punto de mira.
			final_dir = final_dir.rotated(Vector3.UP, deg_to_rad(KickModel.curl_preaim_deg(
				KickModel.flat(res.aim_point - origin).length(), v_h, nat_curl, nat_spin)))
		if vy >= 1.5:
			res.spin = backspin * DRIVE_BACKSPIN
		else:
			# Raso: rueda (giro de rodadura algo menor por el deslizamiento del golpe); el efecto apenas actua en el suelo.
			res.spin = Vector3.UP.cross(KickModel.flat(final_dir) * v_h) / maxf(bt.radius, 0.01) * 0.7
		res.spin += KickModel.curl_spin(final_dir, nat_curl, nat_spin) + Vector3.UP * err_side_spin
		res.curl = nat_curl * nat_spin / CURL_SPIN_MAX
	res.final_dir = final_dir
	res.velocity = Vector3(final_dir.x * v_h, vy, final_dir.z * v_h)

	# Prediccion simple (sin resistencia) de si iria al arco, para estadisticas de intencion.
	# Con el efecto se usa la linea antes de abrir la salida (la curva la devuelve a ella).
	if curl_rad > 0.0:
		line_dir = final_dir.rotated(Vector3.UP, -deg_to_rad(KickModel.curl_preaim_deg(
			KickModel.flat(res.aim_point - origin).length(), speed * cos(deg_to_rad(bt.shot_loft_low_deg)), curl, curl_rad)))
	if line_dir.x * to_goal_x > 0.0:
		var t_goal: float = to_goal_x / (line_dir.x * v_h)
		var z_end: float = origin.z + line_dir.z * v_h * t_goal
		var y_end: float = origin.y + vy * t_goal - 0.5 * KickModel.G * t_goal * t_goal
		res.on_target = absf(z_end) <= pitch_cfg.half_goal() and y_end >= 0.0 and y_end <= pitch_cfg.goal_height
	return res

## Fraccion del ancho util a la que apunta el joystick hacia un palo para este tirador (ver AIM_EDGE).
static func aim_edge(kicker: Footballer) -> float:
	var tech: float = 0.5 * kicker.attributes.norm("shot_accuracy") + 0.5 * kicker.attributes.norm("finishing")
	return lerpf(AIM_EDGE, 1.0, tech)

## Punto lateral del arco (-1..1 del ancho util) que elige el joystick: donde su direccion cruza la linea de gol; si no
## la cruza dentro del arco (apunta fuera, de lado o hacia atras) el palo del lado hacia el que gira respecto al centro.
static func _stick_lateral(intent: Vector3, origin: Vector3, goal: Goal, usable: float) -> float:
	var center: Vector3 = Vector3(goal.global_position.x, 0.0, 0.0)
	var to_center: Vector3 = KickModel.flat(center - origin)
	if to_center.length() < 0.3:
		return 0.0
	var dx: float = center.x - origin.x
	if intent.x * dx > 0.05:
		var z_hit: float = origin.z + intent.z * (dx / intent.x)
		if absf(z_hit) <= usable:
			return z_hit / usable
	# Fuera del arco: el palo del lado al que apunta el joystick respecto a la linea al centro del arco.
	var side: float = signf(to_center.normalized().cross(intent).y)
	# En el sistema del arco, +lateral es +Z: girar a la izquierda del eje al centro (cruz +Y) mira a +Z si se ataca -X
	# y a -Z si se ataca +X.
	return clampf(-side * signf(dx), -1.0, 1.0) if side != 0.0 else 0.0
