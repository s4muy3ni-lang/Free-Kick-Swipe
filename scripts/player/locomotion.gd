class_name Locomotion
extends RefCounted
## Modelo de movimiento del futbolista (puro, sin nodos: facil de probar y de replicar).
##
## Principios:
##  - La direccion del joystick expresa la INTENCION; el cuerpo gira hacia ella a una velocidad
##    que depende de la velocidad actual (a sprint el radio de giro es amplio).
##  - La velocidad se descompone en componente hacia adelante y lateral respecto al cuerpo.
##    El agarre elimina la componente lateral (no se desliza como sobre hielo).
##  - Giros bruscos a alta velocidad obligan a frenar antes de acelerar en la nueva direccion.
##  - Aceleracion progresiva, frenada y deceleracion con valores distintos.

var tuning: PlayerTuning
var attributes: PlayerAttributes

## Estado
var velocity: Vector3 = Vector3.ZERO   # horizontal (y = 0)
var yaw: float = 0.0                   # radianes; ver dir_from_yaw
var stamina: float = 1.0
var exhausted: bool = false

## Salidas para animacion / diagnostico
var speed: float = 0.0
var forward_speed: float = 0.0
var lateral_speed: float = 0.0
var turn_rate: float = 0.0             # rad/s con signo (positivo = giro a la izquierda)
var sprinting: bool = false
var braking: bool = false
var sharp_turning: bool = false
## Marcaje en "jockey": si no es cero el cuerpo mira SIEMPRE hacia esa direccion y se desplaza hacia donde indica el
## joystick (de frente, de lado o de espaldas), sin el agarre lateral de la carrera. Lo fija el futbolista al presionar
## a un portador cercano.
var face_override: Vector3 = Vector3.ZERO
var jockeying: bool = false
## Factor externo de la velocidad de giro (1 = normal). Lo baja un balanceo de patada con animacion.
var turn_scale: float = 1.0

func _init(t: PlayerTuning = null, a: PlayerAttributes = null) -> void:
	tuning = t if t != null else PlayerTuning.new()
	attributes = a if a != null else PlayerAttributes.new()

## Vector de direccion (unitario) para un yaw. yaw = 0 mira hacia -Z.
static func dir_from_yaw(y: float) -> Vector3:
	return Vector3(-sin(y), 0.0, -cos(y))

static func yaw_from_dir(d: Vector3) -> float:
	return atan2(-d.x, -d.z)

func forward() -> Vector3:
	return dir_from_yaw(yaw)

func right() -> Vector3:
	var f: Vector3 = forward()
	return Vector3(-f.z, 0.0, f.x)

func max_run_speed() -> float:
	return tuning.run_speed * attributes.factor("speed", 0.12)

func max_sprint_speed() -> float:
	var s: float = tuning.sprint_speed * attributes.factor("speed", 0.12)
	if exhausted:
		s = lerpf(max_run_speed(), s, tuning.exhausted_speed_factor)
	return s

## Avanza un paso de simulacion.
## desired_dir: direccion deseada en el mundo (unitaria o cero). magnitude: 0..1 (intensidad del joystick).
## speed_cap: tope externo de velocidad (por ejemplo, conduciendo) o <= 0 para no limitar.
func step(desired_dir: Vector3, magnitude: float, want_sprint: bool, delta: float, speed_cap: float = -1.0) -> void:
	jockeying = false
	if face_override.length_squared() > 0.01:
		_step_jockey(desired_dir, magnitude, delta, speed_cap)
		return
	var accel_f: float = attributes.factor("acceleration", 0.16)
	var agility_f: float = attributes.factor("agility", 0.14)
	var has_input: bool = magnitude > 0.05 and desired_dir.length_squared() > 0.0001

	# Resistencia: el sprint la consume; sin ella la velocidad punta cae.
	sprinting = want_sprint and has_input and magnitude > 0.6 and not (exhausted and stamina < 0.12)
	var stamina_f: float = attributes.factor("stamina", 0.5)
	if sprinting:
		stamina = maxf(stamina - tuning.stamina_drain_sprint / stamina_f * delta, 0.0)
		if stamina <= 0.01:
			exhausted = true
	else:
		var regen: float = tuning.stamina_regen_standing if speed < 0.5 else tuning.stamina_regen
		stamina = minf(stamina + regen * stamina_f * delta, 1.0)
		if exhausted and stamina > 0.35:
			exhausted = false

	# Velocidad objetivo segun la intensidad del joystick.
	var target_speed: float = 0.0
	if has_input:
		if sprinting:
			target_speed = max_sprint_speed()
		else:
			target_speed = speed_for_magnitude(magnitude)
	if speed_cap > 0.0:
		target_speed = minf(target_speed, speed_cap)

	# Giro del cuerpo.
	var angle_diff: float = 0.0
	if has_input:
		var target_yaw: float = yaw_from_dir(desired_dir.normalized())
		angle_diff = wrapf(target_yaw - yaw, -PI, PI)
		var speed_ratio: float = clampf(speed / maxf(max_sprint_speed(), 0.1), 0.0, 1.0)
		var rate_deg: float = lerpf(tuning.turn_rate_standing, tuning.turn_rate_sprint, speed_ratio * speed_ratio)
		rate_deg *= agility_f * turn_scale
		var max_step: float = deg_to_rad(rate_deg) * delta
		var applied: float = clampf(angle_diff, -max_step, max_step)
		yaw = wrapf(yaw + applied, -PI, PI)
		turn_rate = applied / maxf(delta, 0.0001)
		sharp_turning = absf(angle_diff) > deg_to_rad(tuning.sharp_turn_angle_deg) and speed > 0.7 * max_run_speed()
	else:
		turn_rate = 0.0
		sharp_turning = false

	# Giros muy cerrados a alta velocidad: hay que frenar antes de acelerar hacia el nuevo rumbo.
	if has_input:
		var turn_penalty: float = clampf((absf(angle_diff) - deg_to_rad(55.0)) / deg_to_rad(95.0), 0.0, 1.0)
		var min_turn_speed: float = tuning.walk_speed
		target_speed = lerpf(target_speed, minf(target_speed, min_turn_speed), turn_penalty)

	# Descomposicion respecto al cuerpo (con el yaw ya actualizado).
	var f: Vector3 = forward()
	var r: Vector3 = right()
	var vf: float = velocity.dot(f)
	var vl: float = velocity.dot(r)

	braking = false
	if vf > target_speed:
		var d: float = tuning.decel * accel_f
		if has_input and (target_speed < vf - 0.5):
			d = tuning.brake * accel_f if (sharp_turning or turn_rate_blocks_speed(angle_diff)) else d
			braking = d > tuning.decel * accel_f + 0.01
		if not has_input:
			d = tuning.decel * accel_f
		vf = maxf(vf - d * delta, target_speed)
	elif vf < target_speed:
		var a: float = tuning.accel * accel_f
		# La aceleracion cae al acercarse a la velocidad maxima (curva suave).
		var headroom: float = clampf(1.0 - maxf(vf, 0.0) / maxf(target_speed, 0.1), 0.0, 1.0)
		a *= lerpf(0.45, 1.0, headroom)
		if vf < 0.0:
			a = tuning.brake * accel_f
		vf = minf(vf + a * delta, target_speed)

	# Agarre lateral: elimina el deslizamiento. A mas velocidad el agarre es algo menor (radio de giro).
	var grip: float = tuning.lateral_grip * lerpf(1.25, 0.8, clampf(speed / 7.0, 0.0, 1.0)) * agility_f
	vl *= exp(-grip * delta)

	velocity = f * vf + r * vl
	velocity.y = 0.0
	forward_speed = vf
	lateral_speed = vl
	speed = velocity.length()

## Movimiento guiado por una accion del cuerpo con la pelota (DragBack): gira hacia face_dir a rate_deg grados/s por el
## lado turn_sign (+1 = yaw creciente, -1 = decreciente, 0 = el camino corto; rate_deg <= 0 conserva la orientacion) y la
## velocidad va hacia target_vel con accel m/s2.
func step_scripted(face_dir: Vector3, rate_deg: float, turn_sign: float, target_vel: Vector3, accel: float, delta: float) -> void:
	jockeying = false
	sprinting = false
	sharp_turning = false
	var regen: float = tuning.stamina_regen_standing if speed < 0.5 else tuning.stamina_regen
	stamina = minf(stamina + regen * attributes.factor("stamina", 0.5) * delta, 1.0)
	turn_rate = 0.0
	if rate_deg > 0.0 and face_dir.length_squared() > 0.0001:
		var diff: float = wrapf(yaw_from_dir(face_dir.normalized()) - yaw, -PI, PI)
		# Media vuelta: el pivote va por el lado pedido aunque el otro sea igual de corto.
		if turn_sign != 0.0 and absf(diff) > 0.35 and signf(diff) != signf(turn_sign):
			diff += signf(turn_sign) * TAU
		var m: float = deg_to_rad(rate_deg) * delta
		var applied: float = clampf(diff, -m, m)
		yaw = wrapf(yaw + applied, -PI, PI)
		turn_rate = applied / maxf(delta, 0.0001)
	var before: float = velocity.length()
	velocity = velocity.move_toward(Vector3(target_vel.x, 0.0, target_vel.z), accel * delta)
	velocity.y = 0.0
	braking = velocity.length() < before - 0.01
	forward_speed = velocity.dot(forward())
	lateral_speed = velocity.dot(right())
	speed = velocity.length()

func _step_jockey(desired_dir: Vector3, magnitude: float, delta: float, speed_cap: float) -> void:
	jockeying = true
	sprinting = false
	braking = false
	sharp_turning = false
	var accel_f: float = attributes.factor("acceleration", 0.16)
	var agility_f: float = attributes.factor("agility", 0.14)
	var regen: float = tuning.stamina_regen_standing if speed < 0.5 else tuning.stamina_regen
	stamina = minf(stamina + regen * attributes.factor("stamina", 0.5) * delta, 1.0)
	var diff: float = wrapf(yaw_from_dir(face_override.normalized()) - yaw, -PI, PI)
	var max_step: float = deg_to_rad(tuning.turn_rate_standing) * 0.8 * agility_f * delta
	var applied: float = clampf(diff, -max_step, max_step)
	yaw = wrapf(yaw + applied, -PI, PI)
	turn_rate = applied / maxf(delta, 0.0001)
	var has_input: bool = magnitude > 0.05 and desired_dir.length_squared() > 0.0001
	var cap: float = minf(speed_for_magnitude(magnitude), tuning.run_speed * 0.8)
	if speed_cap > 0.0:
		cap = minf(cap, speed_cap)
	var want: Vector3 = desired_dir.normalized() * cap if has_input else Vector3.ZERO
	var a: float = (tuning.accel if want.length() > velocity.length() else tuning.decel) * accel_f
	velocity = velocity.move_toward(want, a * delta)
	velocity.y = 0.0
	forward_speed = velocity.dot(forward())
	lateral_speed = velocity.dot(right())
	speed = velocity.length()

## Velocidad objetivo (m/s) para una intensidad de joystick 0..1 (sin sprint).
func speed_for_magnitude(m: float) -> float:
	var walk: float = tuning.walk_speed
	var jog: float = tuning.jog_speed
	var run: float = max_run_speed()
	if m < 0.35:
		return lerpf(0.0, walk, m / 0.35)
	if m < 0.7:
		return lerpf(walk, jog, (m - 0.35) / 0.35)
	return lerpf(jog, run, (m - 0.7) / 0.3)

func turn_rate_blocks_speed(angle_diff: float) -> bool:
	return absf(angle_diff) > deg_to_rad(80.0) and speed > tuning.jog_speed

## Orienta el cuerpo sin moverlo (por ejemplo, al encarar la pelota estando parado).
func face_towards(dir: Vector3, delta: float, rate_deg: float = 540.0) -> void:
	if dir.length_squared() < 0.0001:
		return
	var diff: float = wrapf(yaw_from_dir(dir.normalized()) - yaw, -PI, PI)
	var m: float = deg_to_rad(rate_deg) * delta
	yaw = wrapf(yaw + clampf(diff, -m, m), -PI, PI)

func stop() -> void:
	velocity = Vector3.ZERO
	speed = 0.0
	forward_speed = 0.0
	lateral_speed = 0.0
	turn_rate = 0.0
