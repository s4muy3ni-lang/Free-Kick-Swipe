class_name BallPredictor
extends RefCounted
## Prediccion de la trayectoria de la pelota con el mismo modelo que Ball: gravedad, arrastre cuadratico, rebote
## contra el piso y rodadura. Solo LEE (no mueve nada). Lo usan el arquero y la IA para anticiparse.

const GRAVITY := 9.81
const SUBSTEPS := 4
## Calibracion contra la pelota real (Jolt, rodando de 1.5 a 16 m/s): rodando, el arrastre efectivo es ~0.5 de la formula
## cuadratica (la rodadura es la de Ball: rolling_decel + rolling_viscous * v, Ball.roll_speed). En el aire Ball aplica la
## formula entera (Ball._integrate_forces): con 0.5 tambien en vuelo, un globo de 1.6 s llegaba 1.8 m mas lejos que el real.
const DRAG_SCALE := 0.5
const DRAG_SCALE_AIR := 1.0
## Friccion pelota-piso en el bote (medida contra Jolt: la horizontal pierde mu * (1 + e) * vy en un bote rasante).
const BOUNCE_FRICTION := 0.63
## Esfera hueca (Ball.inertia = 2/3 m r^2): una fuerza en el punto de contacto cambia la velocidad de deslizamiento de la
## superficie (1 + m r^2 / I) = 2,5 veces mas que la del centro, y el giro gana m r^2 / I = 1,5 veces esa velocidad.
const SLIP_K := 2.5
const SPIN_GAIN := 1.5

## Posiciones cada `step` segundos desde ahora (indice 0 = posicion actual) hasta `horizon` segundos.
## spin: giro de la pelota (rad/s, Ball.angular_velocity): curva el vuelo por efecto Magnus (Ball._integrate_forces) y fija
## cuanto desliza en el primer bote; sin el (cero) se supone una pelota sin giro.
## spin_is_state: el giro es el ESTADO real de la pelota (Ball.angular_velocity o el que va a dejar Ball.kick), tambien
## cero. Asi una pelota que sale por el piso sin giro DESLIZA primero (friccion mu*g, que la frena y la hace girar) hasta
## rodar, como en Jolt. Sin el (false, llamadas viejas del partido) una pelota por el piso se supone ya rodando.
static func trajectory(pos: Vector3, vel: Vector3, horizon: float, step: float = 1.0 / 30.0, spin: Vector3 = Vector3.ZERO,
		spin_is_state: bool = false) -> PackedVector3Array:
	var bt: BallTuning = Tuning.ball
	var out := PackedVector3Array()
	out.append(pos)
	var p: Vector3 = pos
	var v: Vector3 = vel
	var dt: float = step / float(SUBSTEPS)
	var area: float = PI * bt.radius * bt.radius
	var n: int = int(horizon / step)
	# Giro de la pelota expresado como velocidad de su superficie a lo largo del avance (m/s); sin dato del giro, cero (un
	# golpeo por el aire) o la de rodadura si ya rueda.
	var hdir: Vector3 = Vector3(vel.x, 0.0, vel.z).normalized() if Vector2(vel.x, vel.z).length() > 0.01 else Vector3.ZERO
	var on_floor: bool = pos.y <= bt.radius + 0.01 and absf(vel.y) < 0.5
	var spin_v: float = Vector2(vel.x, vel.z).length() if on_floor and not spin_is_state else bt.radius * spin.cross(Vector3.UP).dot(hdir)
	var w: Vector3 = spin
	var magnus: float = bt.magnus_k / bt.mass
	# Friccion de deslizamiento sobre el cesped (Jolt toma la menor de las dos).
	var mu_g: float = minf(bt.friction, Ball.FLOOR_FRICTION) * GRAVITY
	for i in n:
		for s in SUBSTEPS:
			v.y -= GRAVITY * dt
			var spd: float = v.length()
			# Efecto Magnus en el aire (como Ball: sin frenado del giro en vuelo).
			if p.y > bt.radius + 0.005 and spd > 1.0 and w != Vector3.ZERO:
				v += w.cross(v) * magnus * dt
			if spd > 0.01:
				var scale: float = DRAG_SCALE if p.y <= bt.radius + 0.005 else DRAG_SCALE_AIR
				# Mientras desliza, la friccion ya esta saturada: el aire frena el centro entero (como en el vuelo).
				if p.y <= bt.radius + 0.005 and absf(Vector2(v.x, v.z).length() - spin_v) > 0.05:
					scale = DRAG_SCALE_AIR
				var dv: float = minf(scale * 0.5 * bt.air_density * bt.drag_coefficient * area * spd * spd / bt.mass * dt, spd)
				v -= v / spd * dv
			p += v * dt
			if p.y <= bt.radius:
				p.y = bt.radius
				if v.y < -1.0:
					# Bote medido contra Jolt: la vertical conserva `bounce`; la horizontal pierde por friccion lo que desliza la
					# superficie de la pelota sobre el piso (v - giro * r), repartido entre frenar y hacerla girar (esfera hueca:
					# 1 + m r^2 / I = 2.5), limitado por mu * impulso normal en los botes rasantes. El giro ganado queda para el
					# bote siguiente (por eso el segundo frena menos que el primero).
					var vy_in: float = -v.y
					v.y = vy_in * bt.bounce
					var hs: float = Vector2(v.x, v.z).length()
					if hs > 0.001:
						var dv_h: float = clampf(minf(BOUNCE_FRICTION * (1.0 + bt.bounce) * vy_in, (hs - spin_v) / 2.5), 0.0, hs)
						v.x *= (hs - dv_h) / hs
						v.z *= (hs - dv_h) / hs
						spin_v += 1.5 * dv_h
						# Tras el bote el giro es el que dejo la friccion (efecto hacia delante a lo largo del avance).
						w = Vector3.UP.cross(Vector3(v.x, 0.0, v.z).normalized()) * (spin_v / bt.radius)
				else:
					v.y = 0.0
					w = Vector3.ZERO
					var hv := Vector3(v.x, 0.0, v.z)
					var hs: float = hv.length()
					var dir: Vector3 = hv / hs if hs > 0.0001 else hdir
					# Rodadura de Ball (rolling_decel + rolling_viscous * v): frena el centro y el giro en la misma proporcion.
					if hs > 0.0001:
						var k: float = Ball.roll_speed(hs, dt) / hs
						hs *= k
						spin_v *= k
					# Deslizamiento: la friccion (mu*g) frena el centro y acelera el giro hasta que la superficie deja de
					# deslizar (rodadura); con efecto atras puede frenarla del todo y hacerla volver.
					var slip: float = hs - spin_v
					if absf(slip) <= SLIP_K * mu_g * dt:
						hs -= slip / SLIP_K
						spin_v = hs
					else:
						var sgn: float = signf(slip)
						hs -= sgn * mu_g * dt
						spin_v += sgn * SPIN_GAIN * mu_g * dt
					if hs < 0.0:
						# Vuelve hacia atras (efecto atras): la velocidad cambia de sentido.
						dir = -dir
						hs = -hs
						spin_v = -spin_v
					v.x = dir.x * hs
					v.z = dir.z * hs
		out.append(p)
	return out

## Primer indice de la trayectoria donde la coordenada X cruza x_plane en el sentido de `dir_sign` (+1: X creciente). -1 si no.
static func crossing_x(traj: PackedVector3Array, x_plane: float, dir_sign: float) -> int:
	for i in range(1, traj.size()):
		if (traj[i - 1].x - x_plane) * dir_sign < 0.0 and (traj[i].x - x_plane) * dir_sign >= 0.0:
			return i
	return -1
