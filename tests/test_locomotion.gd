extends TestCase
## Locomocion: aceleracion progresiva, frenada, giros dependientes de la velocidad y ausencia de "hielo".

const DT: float = 1.0 / 60.0

func _make() -> Locomotion:
	var loc := Locomotion.new(PlayerTuning.new(), PlayerAttributes.new())
	loc.attributes.reset_to(50)
	return loc

func _run_steps(loc: Locomotion, dir: Vector3, mag: float, sprint: bool, seconds: float) -> void:
	for i in int(seconds / DT):
		loc.step(dir, mag, sprint, DT)

func test_acceleration_is_progressive() -> void:
	var loc: Locomotion = _make()
	var dir := Vector3(1, 0, 0)
	loc.yaw = Locomotion.yaw_from_dir(dir)
	_run_steps(loc, dir, 1.0, false, 0.2)
	var v02: float = loc.speed
	note("v(0.2 s)=%.2f m/s de %.2f" % [v02, loc.max_run_speed()])
	var probe: Locomotion = _make()
	probe.yaw = Locomotion.yaw_from_dir(dir)
	var t90: float = 0.0
	while probe.speed < 0.9 * probe.max_run_speed() and t90 < 6.0:
		probe.step(dir, 1.0, false, DT)
		t90 += DT
	note("tiempo hasta el 90 %% de la velocidad de carrera: %.2f s" % t90)
	check_range(t90, 0.9, 2.2, "la aceleracion total toma entre 0.9 y 2.2 s")
	check(v02 < 0.5 * loc.max_run_speed(), "a los 0.2 s aun no alcanza la mitad de la velocidad maxima")
	check(v02 > 0.8, "pero ya se mueve (v=%.2f)" % v02)
	_run_steps(loc, dir, 1.0, false, 2.5)
	check_range(loc.speed, 0.93 * loc.max_run_speed(), loc.max_run_speed() + 0.01, "alcanza la velocidad de carrera")

func test_sprint_is_faster_and_drains_stamina() -> void:
	var loc: Locomotion = _make()
	var dir := Vector3(0, 0, -1)
	loc.yaw = Locomotion.yaw_from_dir(dir)
	_run_steps(loc, dir, 1.0, true, 3.0)
	check(loc.speed > loc.max_run_speed() + 0.5, "sprint supera la velocidad de carrera (v=%.2f)" % loc.speed)
	check(loc.stamina < 0.8, "el sprint consume resistencia (stamina=%.2f)" % loc.stamina)
	var drained: float = loc.stamina
	_run_steps(loc, dir, 0.4, false, 3.0)
	check(loc.stamina > drained, "la resistencia se recupera sin sprint")

func test_stops_without_sliding_like_ice() -> void:
	var loc: Locomotion = _make()
	var dir := Vector3(1, 0, 0)
	loc.yaw = Locomotion.yaw_from_dir(dir)
	_run_steps(loc, dir, 1.0, false, 3.0)
	var pos := Vector3.ZERO
	var t: float = 0.0
	while loc.speed > 0.05 and t < 3.0:
		loc.step(Vector3.ZERO, 0.0, false, DT)
		pos += loc.velocity * DT
		t += DT
	note("frenada desde carrera: %.2f s, %.2f m" % [t, pos.length()])
	check(t < 0.9, "se detiene en menos de 0.9 s (tardo %.2f)" % t)
	check(pos.length() < 2.0, "recorre menos de 2 m al soltar el joystick (%.2f)" % pos.length())

func test_turning_rate_depends_on_speed() -> void:
	var standing: Locomotion = _make()
	var fast: Locomotion = _make()
	var dir_x := Vector3(1, 0, 0)
	fast.yaw = Locomotion.yaw_from_dir(dir_x)
	_run_steps(fast, dir_x, 1.0, true, 3.0)
	# Giro de 90 grados desde parado vs. desde sprint.
	var dir_z := Vector3(0, 0, -1)
	standing.yaw = Locomotion.yaw_from_dir(dir_x)
	var t_stand: float = 0.0
	while absf(wrapf(Locomotion.yaw_from_dir(dir_z) - standing.yaw, -PI, PI)) > 0.05 and t_stand < 3.0:
		standing.step(dir_z, 1.0, false, DT)
		t_stand += DT
	var t_fast: float = 0.0
	while absf(wrapf(Locomotion.yaw_from_dir(dir_z) - fast.yaw, -PI, PI)) > 0.05 and t_fast < 3.0:
		fast.step(dir_z, 1.0, true, DT)
		t_fast += DT
	note("giro de 90 grados: parado %.2f s, sprint %.2f s" % [t_stand, t_fast])
	check_range(t_stand, 0.08, 0.30, "parado gira 90 grados rapido pero no instantaneo (%.2f s)" % t_stand)
	check(t_fast > t_stand * 1.5, "a sprint el giro es mas lento (parado %.2f s, sprint %.2f s)" % [t_stand, t_fast])
	check(t_fast >= 0.25, "a sprint no gira instantaneamente (%.2f s)" % t_fast)

func test_reversal_at_sprint_brakes_first_and_never_slides_sideways() -> void:
	var loc: Locomotion = _make()
	var dir := Vector3(1, 0, 0)
	loc.yaw = Locomotion.yaw_from_dir(dir)
	_run_steps(loc, dir, 1.0, true, 3.0)
	var v_before: float = loc.speed
	var lateral_travel: float = 0.0
	var min_speed: float = 99.0
	var t: float = 0.0
	var back := Vector3(-1, 0, 0)
	var speed_when_aligned: float = -1.0
	while t < 3.0:
		loc.step(back, 1.0, false, DT)
		t += DT
		lateral_travel += absf(loc.lateral_speed) * DT
		min_speed = minf(min_speed, loc.speed)
		if speed_when_aligned < 0.0 and absf(wrapf(Locomotion.yaw_from_dir(back) - loc.yaw, -PI, PI)) < 0.1:
			speed_when_aligned = loc.speed
	note("inversion a sprint: v_inicial=%.2f, v_min=%.2f, desplazamiento_lateral=%.2f m, v_al_alinear=%.2f" % [v_before, min_speed, lateral_travel, speed_when_aligned])
	check(min_speed < 2.2, "al invertir el sentido a sprint se frena antes de acelerar (v_min=%.2f)" % min_speed)
	check(lateral_travel < 2.0, "el desplazamiento lateral total al invertir esta acotado (%.2f m)" % lateral_travel)
	check(speed_when_aligned < v_before * 0.6, "alinea el cuerpo cuando ya perdio velocidad (v=%.2f)" % speed_when_aligned)
	check(loc.velocity.dot(back) > 0.0, "termina moviendose en el nuevo sentido")

func test_attributes_scale_speed_within_limits() -> void:
	var slow: Locomotion = _make()
	slow.attributes.reset_to(1)
	var fast: Locomotion = _make()
	fast.attributes.reset_to(100)
	check(fast.max_run_speed() > slow.max_run_speed(), "mas velocidad = mas rapido")
	check(fast.max_run_speed() < slow.max_run_speed() * 1.35, "la diferencia esta acotada (no sustituye la fisica)")
