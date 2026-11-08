class_name PressController
extends RefCounted
## Presion defensiva inteligente (boton de presion mantenido).
##
## - Busca la PELOTA (no la posicion del rival): calcula un punto de intercepcion a corto plazo.
## - Se acerca con velocidad controlada y se detiene a una distancia de contencion antes de disputar.
## - Si el usuario mueve el joystick, esa direccion ajusta el angulo de aproximacion y la posicion de
##   intercepcion, pero NO cancela la busqueda del balon.
## - Solo termina si se suelta el boton, la accion deja de ser valida o el juego lo requiere.
## - Produce una "intencion de movimiento" (direccion + magnitud) que pasa por Locomotion:
##   no hay teletransporte ni atajos de velocidad. Robar el balon no esta garantizado.

class PressOutput:
	extends RefCounted
	var active: bool = false
	var dir: Vector3 = Vector3.ZERO
	var magnitude: float = 0.0
	var sprint: bool = false
	var attempt_tackle: bool = false
	var carrier: Footballer = null
	var intercept_point: Vector3 = Vector3.ZERO
	var distance_to_ball: float = 0.0

var tackle_cooldown: float = 0.0
var _carrier: Footballer = null
## Segundos seguidos encima del portador sin llegar al alcance de robo (el cuerpo del portador tapa la pelota).
var _close_time: float = 0.0

func reset() -> void:
	_carrier = null

func update(defender: Footballer, ctx: MatchContext, stick_world: Vector3, stick_mag: float, dt: float) -> PressOutput:
	var cfg: AssistTuning = Tuning.assist
	var out := PressOutput.new()
	tackle_cooldown = maxf(tackle_cooldown - dt, 0.0)
	var ball: Ball = ctx.ball
	if ball == null or ball.is_held():
		return out
	var d_pos: Vector3 = KickModel.flat(defender.global_position)
	var ball_pos: Vector3 = KickModel.flat(ball.global_position)

	# Si el propio equipo controla el balon (cerca y ultimo en tocarlo), la presion no tiene sentido.
	if ball.last_touch_team == defender.team:
		var own_carrier: Footballer = _find_carrier(ctx, ball, defender.team, Tuning.player.possession_radius)
		if own_carrier != null:
			return out

	# Portador rival (con pegajosidad para no cambiar de objetivo de forma erratica).
	var carrier: Footballer = _find_carrier(ctx, ball, 1 - defender.team, Tuning.player.possession_radius)
	if carrier == null and _carrier != null and is_instance_valid(_carrier):
		if KickModel.flat(_carrier.global_position).distance_to(ball_pos) < Tuning.player.possession_radius * 1.5:
			carrier = _carrier
	_carrier = carrier
	out.carrier = carrier

	var target_vel: Vector3 = KickModel.flat(ball.linear_velocity)
	if carrier != null:
		target_vel = KickModel.flat(carrier.velocity)

	# --- Punto de intercepcion (iterativo, con desaceleracion de la pelota si esta suelta) ---
	var chase_speed: float = maxf(defender.locomotion.max_sprint_speed() * cfg.press_speed_factor, 2.5)
	var t: float = 0.0
	var p: Vector3 = ball_pos
	for i in 3:
		p = ball_pos + _project(target_vel, t, carrier == null)
		var dist_p: float = d_pos.distance_to(p)
		t = clampf(dist_p / chase_speed, 0.0, cfg.press_lookahead * 2.0)
	t = minf(t, cfg.press_lookahead * 2.0)
	var intercept: Vector3 = ball_pos + _project(target_vel, t, carrier == null)
	intercept = defender_pitch_clamp(ctx, intercept)

	# --- Punto de aproximacion ---
	var approach: Vector3 = intercept
	var dist_ball: float = d_pos.distance_to(ball_pos)
	out.distance_to_ball = dist_ball
	if carrier != null:
		var carrier_dir: Vector3 = target_vel.normalized() if target_vel.length() > 0.6 else (ball_pos - d_pos).normalized()
		# Se queda por delante de la trayectoria del portador (contencion), no detras.
		var standoff: float = cfg.press_standoff
		approach = intercept - carrier_dir * standoff * 0.6
		if dist_ball < standoff * 1.2:
			approach = intercept
			# Ya encima del portador: se ataca la pelota por el lado libre, rodeando el cuerpo que la protege.
			# Si no, el defensor choca contra la espalda del portador y nunca llega a disputarla.
			var ball_side: Vector3 = ball_pos - KickModel.flat(carrier.global_position)
			if ball_side.length() > 0.15:
				approach = ball_pos + ball_side.normalized() * cfg.press_around_offset
	var to_target: Vector3 = approach - d_pos
	var dist: float = to_target.length()
	var dir: Vector3 = to_target / maxf(dist, 0.001) if dist > 0.05 else (ball_pos - d_pos).normalized()

	# --- Influencia del joystick: ajusta el angulo, nunca invierte la busqueda ---
	if stick_mag > 0.2 and stick_world.length() > 0.2:
		var s: Vector3 = KickModel.flat(stick_world).normalized()
		var lateral: Vector3 = s - dir * s.dot(dir)
		var blended: Vector3 = (dir + lateral * cfg.press_stick_influence * 1.2).normalized()
		if blended.dot(dir) >= 0.35:
			dir = blended
		else:
			dir = (dir * 0.8 + blended * 0.2).normalized()

	# --- Velocidad controlada ---
	var mag: float
	if dist > 5.0:
		mag = 1.0
	else:
		mag = clampf(0.4 + dist / 6.0, 0.4, 1.0)
	if carrier != null and dist_ball < cfg.press_standoff * 1.2:
		# Encima del portador se va mas despacio, pero lo bastante rapido para rodearlo y llegar a la pelota.
		mag = minf(mag, 0.75)
	out.active = true
	out.dir = dir
	out.magnitude = mag * lerpf(0.9, 1.0, cfg.press_assist)
	out.sprint = dist > 6.0 and not defender.locomotion.exhausted
	out.intercept_point = Vector3(intercept.x, 0.0, intercept.z)

	# --- Disputa ---
	var facing_ball: float = KickModel.angle_between_deg(defender.locomotion.forward(), ball_pos - d_pos)
	# Encima del portador que protege la pelota con el cuerpo: tras un rato estira la pierna (alcance algo mayor). Si no,
	# un portador quieto y bien plantado podria retenerla para siempre.
	_close_time = _close_time + dt if (carrier != null and dist_ball < cfg.press_tackle_range + 0.45) else 0.0
	var reach: float = cfg.press_tackle_range + (0.3 if _close_time > 1.2 else 0.0)
	if dist_ball <= reach and tackle_cooldown <= 0.0 and ball.global_position.y < 0.6 and facing_ball < 85.0:
		out.attempt_tackle = true
		tackle_cooldown = cfg.press_tackle_cooldown
	return out

static func _project(vel: Vector3, t: float, decelerates: bool) -> Vector3:
	if not decelerates:
		return vel * t
	var speed: float = vel.length()
	if speed < 0.01:
		return Vector3.ZERO
	return vel.normalized() * Ball.roll_distance(speed, t)

static func defender_pitch_clamp(ctx: MatchContext, p: Vector3) -> Vector3:
	if ctx.pitch == null:
		return p
	return ctx.pitch.clamp_to_pitch(p, 0.4)

static func _find_carrier(ctx: MatchContext, ball: Ball, team: int, radius: float) -> Footballer:
	# Con dueno de la pelota, el portador es el (si es de ese equipo); sin dueno, el mas cercano dentro del radio.
	ctx.update_possession()
	if ctx.possessor != null and is_instance_valid(ctx.possessor):
		return ctx.possessor if ctx.possessor.team == team else null
	var best: Footballer = null
	var best_d: float = radius
	var bp := Vector2(ball.global_position.x, ball.global_position.z)
	if ball.global_position.y > 0.7:
		return null
	for f in ctx.footballers:
		if f.team != team:
			continue
		var d: float = Vector2(f.global_position.x, f.global_position.z).distance_to(bp)
		if d < best_d:
			best_d = d
			best = f
	return best
