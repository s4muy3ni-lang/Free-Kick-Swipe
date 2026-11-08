class_name GestureShotModel
extends RefCounted
## Convierte las propiedades del gesto (ShotGesture.features) en los parametros del disparo (ShotParams) y los resuelve con
## la fisica de la pelota (ShotSolver -> BallPredictor, el mismo modelo que Ball): la vista previa mientras el dedo esta
## apoyado y el tiro real usan exactamente esta funcion, asi que la linea dibujada es la trayectoria que va a seguir la
## pelota (salvo el error de precision que se aplica al soltar y el flotado de los tiros sin giro).
##
## Influencia de cada propiedad (coeficientes en GestureTuning):
##  - velocidad del dedo (media y maxima) -> POTENCIA, con curva de respuesta saturada y limites;
##  - largo del trazo -> CONTROL: un trazo largo da la direccion con mas precision; NO suma potencia;
##  - desplazamiento vertical (hasta donde llega el dedo sobre el arco) -> ALTURA del punto de llegada; si el trazo termina
##    bajando, baja la llegada y agrega efecto hacia delante; si termina subiendo con fuerza, la sube un poco;
##  - curvatura -> EFECTO lateral (Magnus) en el sentido de la curva, con zona muerta y maximo;
##  - direccion general -> hacia donde va (el punto del arco bajo el final del trazo, o la prolongacion de su direccion);
##  - suavidad -> PRECISION (un trazo irregular suma un error pequeño).

## Contexto del tiro: plano del arco, velocidades de salida del modo, medidas del arco.
static func context(plane_x: float, speed_range: Vector2, penalty: bool, half_goal: float, goal_h: float, radius: float) -> Dictionary:
	return {"plane_x": plane_x, "speed_min": speed_range.x, "speed_max": speed_range.y, "penalty": penalty,
		"half_goal": half_goal, "goal_h": goal_h, "radius": radius}

static func power_from(f: Dictionary, t: GestureTuning) -> float:
	var s: float = lerpf(float(f["avg_speed"]), float(f["peak_speed"]), t.peak_weight)
	var x: float = clampf((s - t.speed_slow) / maxf(t.speed_fast - t.speed_slow, 0.01), 0.0, 1.0)
	var g: float = t.power_curve
	var shaped: float = (1.0 - exp(-g * x)) / (1.0 - exp(-g))
	return lerpf(t.power_min, t.power_max, shaped)

## Parametros del disparo a partir del gesto. end_px: final del trazo en pantalla.
static func build(f: Dictionary, end_px: Vector2, cam: Camera3D, ball: Vector3, ctx: Dictionary, t: GestureTuning) -> ShotParams:
	var p := ShotParams.new()
	p.gesture_length = float(f["length"])
	p.average_speed = float(f["avg_speed"])
	p.peak_speed = float(f["peak_speed"])
	p.smoothness = float(f["smoothness"])
	p.vertical = float(f["vertical"])
	p.power = power_from(f, t)
	var plane_x: float = ctx["plane_x"]
	p.target = target_on_goal(cam, end_px, ball, plane_x)
	# Final del trazo: bajando = tiro bajo con efecto hacia delante; subiendo con fuerza = un poco mas alto.
	var ed: Vector2 = f["end_dir"]
	var descending: float = clampf((ed.y - 0.2) / 0.8, 0.0, 1.0)
	if descending > 0.0:
		p.target.y -= t.descend_drop * descending
	elif ed.y < -0.85 and float(f["end_accel"]) > 0.0:
		p.target.y += t.ascend_lift * clampf(-ed.y, 0.0, 1.0)
	p.target.y = maxf(p.target.y, 0.12)
	# Efecto lateral por la curvatura (zona muerta, ganancia y maximo).
	var c: float = float(f["curvature"])
	var ca: float = maxf(absf(c) - t.curve_deadzone, 0.0)
	p.curve = signf(c) * ca
	p.lateral_spin = clampf(p.curve * t.spin_gain, -t.spin_max, t.spin_max)
	p.direction = Vector3(p.target.x - ball.x, 0.0, p.target.z - ball.z).normalized()
	# Precision: base + potencia + irregularidad + trazo corto (el largo da control, no potencia).
	var lf: float = clampf(p.gesture_length / t.length_full, 0.0, 1.0)
	p.error_deg = t.error_base + t.error_power * p.power * p.power + t.error_rough * (1.0 - p.smoothness) + t.error_short * (1.0 - lf)
	var worst: float = t.error_base + t.error_power + t.error_rough + t.error_short
	p.accuracy = clampf(1.0 - (p.error_deg - t.error_base) / maxf(worst - t.error_base, 0.01), 0.0, 1.0)
	p.gesture_type = classify(p, t, float(ctx.get("goal_h", 2.44)))
	_apply_type(p, ctx, t, descending)
	return p

## Tipo de disparo que resulta del gesto (sin botones: sale de la combinacion de propiedades).
static func classify(p: ShotParams, t: GestureTuning, goal_h: float) -> String:
	if p.gesture_length < t.min_length:
		return "invalido"
	if p.power <= t.lob_max_power and p.target.y >= t.high_height:
		return "globo"
	if absf(p.curve) + t.curve_deadzone >= t.curl_min:
		return "con_efecto"
	if p.gesture_length <= t.snap_max_length and p.power >= 0.55:
		return "rapido_corto"
	if p.power >= 0.7 and p.target.y < 0.9:
		return "potente_raso"
	if p.power >= 0.5 and p.target.y >= t.high_height and p.target.y <= goal_h + 1.0:
		return "elevado"
	if p.smoothness >= t.precision_smoothness and p.gesture_length >= t.length_full * 0.8 and p.power < 0.65:
		return "precision"
	if p.power < 0.55:
		return "colocado"
	return "normal"

static func _apply_type(p: ShotParams, ctx: Dictionary, t: GestureTuning, descending: float) -> void:
	var vmin: float = ctx["speed_min"]
	var vmax: float = ctx["speed_max"]
	p.speed = lerpf(vmin, vmax, p.power)
	p.prefer_short = false
	p.curled = false
	match p.gesture_type:
		"globo":
			p.kind = ShotCatalog.Kind.CHIP
			p.speed = lerpf(vmin * 0.55, vmin * 0.85, p.power / maxf(t.lob_max_power, 0.01))
			p.lateral_spin = 0.0
		"con_efecto":
			p.kind = ShotCatalog.Kind.PLACED if p.power < 0.55 else ShotCatalog.Kind.NORMAL
			p.curled = true
		"rapido_corto":
			p.kind = ShotCatalog.Kind.POWER
			p.prefer_short = true
		"potente_raso", "elevado":
			p.kind = ShotCatalog.Kind.POWER
		"precision", "colocado":
			p.kind = ShotCatalog.Kind.PLACED
		_:
			p.kind = ShotCatalog.Kind.NORMAL
	p.spin = Vector3(0.0, p.lateral_spin, 0.0)
	# Efecto hacia delante (la pelota cae): tiros potentes y altos o trazos que terminan bajando.
	var top: float = 0.0
	if p.gesture_type == "elevado":
		top = t.topspin * p.power
	top += t.topspin * 0.6 * descending
	if top > 0.0:
		var side := SpClips.right_of(p.direction)
		p.spin -= side * top

## Resuelve con la fisica (preview: menos iteraciones y paso mas grueso, el mismo modelo).
static func solve(p: ShotParams, ball: Vector3, ctx: Dictionary, preview: bool = false) -> void:
	var sol: Dictionary = ShotSolver.solve(ball, p.target, p.speed, p.spin, ctx["plane_x"], 6 if preview else ShotSolver.ITERATIONS,
		1.0 / 30.0 if preview else ShotSolver.STEP)
	if sol.is_empty():
		return
	p.velocity = sol["velocity"]
	p.trajectory = sol["trajectory"]
	p.crossing = sol["crossing"]
	var h: float = Vector2(p.velocity.x, p.velocity.z).length()
	p.launch_angle = rad_to_deg(atan2(p.velocity.y, h))
	p.predicted_class = ShotSolver.classify(p.crossing, ctx["half_goal"], ctx["goal_h"], ctx["radius"])

## Punto del plano del arco (x = plane_x) que queda bajo `screen_point`. Si el rayo toca el piso antes (trazo corto), se
## sigue la direccion del piso y la llegada es rasa.
static func target_on_goal(cam: Camera3D, screen_point: Vector2, ball: Vector3, plane_x: float) -> Vector3:
	var o: Vector3 = cam.project_ray_origin(screen_point)
	var d: Vector3 = cam.project_ray_normal(screen_point)
	if absf(d.x) < 1e-4:
		return Vector3(plane_x, 0.2, ball.z)
	var tt: float = (plane_x - o.x) / d.x
	var q: Vector3 = o + d * tt
	if tt > 0.0 and q.y >= 0.12:
		return q
	if d.y < -1e-4:
		var tg: float = -o.y / d.y
		var g: Vector3 = o + d * tg
		var hv := Vector3(g.x - ball.x, 0.0, g.z - ball.z)
		if hv.x > 0.05:
			return Vector3(plane_x, 0.12, ball.z + hv.z / hv.x * (plane_x - ball.x))
	return Vector3(plane_x, 0.12, q.z)
