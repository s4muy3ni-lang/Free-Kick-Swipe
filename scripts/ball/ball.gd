class_name Ball
extends RigidBody3D
## Pelota independiente con fisica 3D (RigidBody3D / Jolt).
##
## Reglas del diseno:
##  - Nunca se teletransporta al pie del jugador ni se anula su velocidad para simular control.
##  - Los jugadores interactuan solo mediante impulsos (kick) en el instante del contacto.
##  - Resistencia del aire, efecto Magnus y rodadura se calculan en _integrate_forces.
##  - Excepcion explicita: el arquero puede sostenerla (hold/release) mientras la tiene en las manos.

signal touched(actor: Node)
signal hit_goal_frame(position: Vector3, speed: float)
signal floor_bounce(position: Vector3, speed: float)
signal released(by: Node)
## Cada golpe (Ball.kick): quien la toco (o null), cuanto cambio la velocidad (m/s) y la velocidad con la que sale. Lo
## usan los sonidos (Sfx) y la camara (sacudida del tiro).
signal impulse(actor: Node, dv: float, speed: float)
## La pelota entra en contacto con la red de tela (con su velocidad en ese momento).
signal net_hit(speed: float)

const LAYER_WORLD := 1
const LAYER_BALL := 2
const LAYER_PLAYERS := 4
const LAYER_KEEPERS := 8
const LAYER_GOAL_FRAME := 16
## Friccion del cesped (material del piso de Pitch y Stadium11). Jolt combina la de la pelota y la del piso tomando la
## menor (como Godot Physics): medido en la cancha, la pelota que desliza frena a mu*g con mu = 0,58-0,60 = min(0,6; 0,8).
const FLOOR_FRICTION := 0.8

var tuning: BallTuning
var radius: float = 0.1

## Ultimo actor que toco la pelota y el equipo al que pertenece (-1 si ninguno).
var last_toucher: Node = null
var last_touch_team: int = -1
var previous_toucher: Node = null
var previous_touch_team: int = -1
var last_touch_msec: int = 0
## Fotograma de fisica del ultimo toque (tiempo de simulacion, valido tambien en pruebas aceleradas).
var last_touch_frame: int = 0

## Quien la sostiene ahora mismo (solo arquero).
var holder: Node = null
var _hold_anchor: Node3D = null

## Aceleracion que le aplica la red del arco en el proximo paso de fisica (GoalNet la acumula en su _physics_process,
## que corre antes del paso) y si esta metida en la tela (frena tambien el giro).
var net_accel: Vector3 = Vector3.ZERO
var net_contact: bool = false
var _net_was: bool = false

var _grounded: bool = false
var _pending_teleport: bool = false
var _teleport_pos: Vector3 = Vector3.ZERO
var _teleport_vel: Vector3 = Vector3.ZERO
var _prev_vy: float = 0.0
var _visual: MeshInstance3D = null
## Diseño del balon (BallSkins): solo el material, la fisica no cambia.
var _skin: String = ""

func set_skin(design: String) -> void:
	_skin = design
	if _visual != null:
		BallSkins.apply_material(_visual.material_override as ShaderMaterial, design)

func skin() -> String:
	return _skin if _skin != "" else "clasico"
## Estela de los tiros fuertes o con efecto (solo presentacion): cinta con las ultimas posiciones de la pelota. La forma
## de la curva que dibuja es la de la trayectoria real (no se inventa nada).
const TRAIL_POINTS := 18
const TRAIL_MIN_SPEED := 15.0
const TRAIL_MIN_SPIN := 14.0
var _trail: MeshInstance3D = null
var _trail_mesh: ImmediateMesh = null
var _trail_pts: PackedVector3Array = PackedVector3Array()
var _trail_alpha: float = 0.0
## true mientras la estela esta activa (diagnostico y pruebas).
var trail_active: bool = false
## Tiro sin giro que "flota" (knuckle, lo pone el tiro potente con set_knuckle): aceleracion lateral oscilante (m/s^2)
## mientras la pelota va rapida por el aire con poco giro, como la de las pelotas reales sin giro (la estela de aire se
## desprende de forma irregular). Cualquier golpe, bote o choque la apaga.
const KNUCKLE_MIN_SPEED := 12.0
const KNUCKLE_MAX_SPIN := 12.0
const KNUCKLE_MAX_TIME := 1.5
var knuckle_accel: float = 0.0
var _knuckle_freq: float = 0.0
var _knuckle_phase: float = 0.0
var _knuckle_t: float = 0.0
var _knuckle_airborne: bool = false

func _ready() -> void:
	add_to_group("ball")
	tuning = Tuning.ball
	_build()
	apply_tuning()

func _build() -> void:
	collision_layer = LAYER_BALL
	collision_mask = LAYER_WORLD | LAYER_PLAYERS | LAYER_KEEPERS | LAYER_GOAL_FRAME
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = true
	can_sleep = false
	custom_integrator = false
	if get_node_or_null("CollisionShape3D") == null:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		cs.shape = SphereShape3D.new()
		add_child(cs)
	if get_node_or_null("Visual") == null:
		_visual = MeshInstance3D.new()
		_visual.name = "Visual"
		var sphere := SphereMesh.new()
		sphere.radial_segments = 20
		sphere.rings = 10
		_visual.mesh = sphere
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/ball/ball.gdshader")
		_visual.material_override = mat
		_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(_visual)
	else:
		_visual = get_node("Visual")
	body_entered.connect(_on_body_entered)
	if _skin != "":
		set_skin(_skin)
	if _trail == null:
		_trail_mesh = ImmediateMesh.new()
		_trail = MeshInstance3D.new()
		_trail.name = "Trail"
		_trail.mesh = _trail_mesh
		_trail.top_level = true
		_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tm := StandardMaterial3D.new()
		tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tm.vertex_color_use_as_albedo = true
		tm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_trail.material_override = tm
		add_child(_trail)

## Aplica los parametros de BallTuning (se puede llamar en caliente desde el laboratorio).
func apply_tuning() -> void:
	radius = tuning.radius
	mass = tuning.mass
	# REPLACE: ignora el amortiguamiento por defecto del proyecto (que se SUMARIA y frenaria de mas);
	# la resistencia del aire y la rodadura se modelan explicitamente en _integrate_forces.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = tuning.angular_damp
	linear_damp = 0.0
	var pm := PhysicsMaterial.new()
	pm.bounce = tuning.bounce
	pm.friction = tuning.friction
	physics_material_override = pm
	# Inercia de una esfera hueca (balon): 2/3 m r^2. Coherente con rolling_spin() y kick().
	inertia = Vector3.ONE * ((2.0 / 3.0) * mass * radius * radius)
	var shape := (get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D
	shape.radius = radius
	if _visual != null:
		var sphere := _visual.mesh as SphereMesh
		sphere.radius = radius * tuning.visual_scale
		sphere.height = radius * 2.0 * tuning.visual_scale

# --- API publica -----------------------------------------------------------

## Golpe: aplica el impulso necesario para que la pelota salga con la velocidad y el giro dados.
func kick(target_velocity: Vector3, spin: Vector3 = Vector3.ZERO, kicker: Node = null) -> void:
	if holder != null:
		release(kicker)
	var dv: Vector3 = target_velocity - linear_velocity
	apply_central_impulse(dv * mass)
	impulse.emit(kicker, dv.length(), target_velocity.length())
	var inertia: float = (2.0 / 3.0) * mass * radius * radius
	apply_torque_impulse((spin - angular_velocity) * inertia)
	knuckle_accel = 0.0
	register_touch(kicker)

## Activa el "flotado" del tiro sin giro recien pateado: amplitud (m/s^2), frecuencia (Hz) y fase (rad) de la fuerza
## lateral. Se llama justo despues de kick().
func set_knuckle(accel: float, freq: float, phase: float) -> void:
	knuckle_accel = maxf(accel, 0.0)
	_knuckle_freq = freq
	_knuckle_phase = phase
	_knuckle_t = 0.0
	_knuckle_airborne = false

## Giro de rodadura sin deslizamiento para una velocidad horizontal dada (w = up x v / r).
## Un golpe raso real transmite este giro; sin el, la pelota resbala y pierde ~30 % de velocidad.
func rolling_spin(velocity: Vector3) -> Vector3:
	return Vector3.UP.cross(Vector3(velocity.x, 0.0, velocity.z)) / radius

## Impulso arbitrario (desvios, choques) sin cambiar el ultimo toque salvo que se indique actor.
func push(impulse: Vector3, actor: Node = null) -> void:
	apply_central_impulse(impulse)
	if actor != null:
		register_touch(actor)

func register_touch(actor: Node) -> void:
	if actor == null:
		return
	if actor != last_toucher:
		previous_toucher = last_toucher
		previous_touch_team = last_touch_team
	last_toucher = actor
	var team_value: Variant = actor.get("team")
	last_touch_team = int(team_value) if team_value != null else -1
	last_touch_msec = Time.get_ticks_msec()
	last_touch_frame = Engine.get_physics_frames()
	touched.emit(actor)

## Teletransporte controlado (saques de centro, reinicios). No se usa durante el juego normal.
func reset_at(pos: Vector3, vel: Vector3 = Vector3.ZERO) -> void:
	if holder != null:
		release(null)
	_pending_teleport = true
	knuckle_accel = 0.0
	_teleport_pos = pos
	_teleport_vel = vel
	last_toucher = null
	last_touch_team = -1
	previous_toucher = null
	previous_touch_team = -1

func hold(anchor: Node3D, by: Node) -> void:
	holder = by
	_hold_anchor = anchor
	knuckle_accel = 0.0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	register_touch(by)

func release(by: Node, velocity: Vector3 = Vector3.ZERO) -> void:
	if holder == null:
		return
	holder = null
	_hold_anchor = null
	freeze = false
	linear_velocity = velocity
	released.emit(by)

func is_held() -> bool:
	return holder != null

func is_grounded() -> bool:
	return _grounded

func speed() -> float:
	return linear_velocity.length()

func ground_speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()

func capture_state(tick: int = 0) -> BallState:
	var s := BallState.new()
	s.tick = tick
	s.position = global_position
	s.linear_velocity = linear_velocity
	s.angular_velocity = angular_velocity
	s.orientation = global_transform.basis.get_rotation_quaternion()
	var holder_id_value: Variant = holder.get("actor_id") if holder != null else null
	s.holder_id = int(holder_id_value) if holder_id_value != null else -1
	var toucher_id_value: Variant = last_toucher.get("actor_id") if last_toucher != null else null
	s.last_toucher_id = int(toucher_id_value) if toucher_id_value != null else -1
	return s

func apply_state(s: BallState) -> void:
	reset_at(s.position, s.linear_velocity)
	angular_velocity = s.angular_velocity

# --- Giro que se dibuja -------------------------------------------------------

## Grados maximos que gira el balon DIBUJADO por imagen. El patron (parches sobre los 12 vertices de un icosaedro) se
## repite cada ~63 grados: un pase a 6 m/s rueda a ~57 rad/s = 55 grados por imagen a 60 fps y se ve QUIETO; a 10 m/s,
## 92 grados por imagen, y parece girar despacio o al reves (efecto rueda de carro). El dibujo sigue el eje y el sentido
## reales pero sin pasar de este giro por imagen (legible tambien a 30 fps). La fisica (giro real, Magnus) no cambia.
const VISUAL_SPIN_DEG_PER_FRAME := 20.0
## Fraccion de la imagen con el obturador abierto: el patron se desenfoca a lo largo del giro REAL de ese tiempo (el
## shader lo promedia alrededor del eje), como en la television: rapido quedan bandas y se ven los polos del eje.
const VISUAL_SHUTTER := 0.5
var _visual_basis := Basis.IDENTITY
## Giro (grados por imagen) dibujado y arco de desenfoque (grados) de la ultima imagen (diagnostico y pruebas).
var visual_spin_step_deg: float = 0.0
var visual_spin_blur_deg: float = 0.0

func _process(delta: float) -> void:
	Prof.begin(&"pelota (visual)")
	_visual_step(delta)
	Prof.end(&"pelota (visual)")

func _visual_step(delta: float) -> void:
	if _visual == null:
		return
	var w: Vector3 = angular_velocity
	var rate: float = w.length()
	var step: float = 0.0
	var arc: float = 0.0
	var axis: Vector3 = Vector3.UP
	if rate > 0.05 and delta > 0.0:
		step = minf(rate * delta, deg_to_rad(VISUAL_SPIN_DEG_PER_FRAME))
		_visual_basis = (Basis(w / rate, step) * _visual_basis).orthonormalized()
		arc = minf(rate * delta * VISUAL_SHUTTER, PI)
		# Eje del giro en el espacio del balon dibujado (la malla gira con _visual_basis).
		axis = (_visual_basis.transposed() * (w / rate)).normalized()
	visual_spin_step_deg = rad_to_deg(step)
	visual_spin_blur_deg = rad_to_deg(arc)
	_visual.global_basis = _visual_basis
	var mat := _visual.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("spin_axis", axis)
		mat.set_shader_parameter("spin_arc", arc)

# --- Fisica ----------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	Prof.begin(&"pelota (script fisica)")
	_ball_step(_delta)
	Prof.end(&"pelota (script fisica)")

func _ball_step(_delta: float) -> void:
	if holder != null and _hold_anchor != null and is_instance_valid(_hold_anchor):
		global_position = _hold_anchor.global_position
	_update_trail(_delta)

## Estela: se activa con un tiro rapido o con mucho efecto lateral en el aire y se desvanece al frenar o tocar el suelo.
func _update_trail(delta: float) -> void:
	if _trail_mesh == null:
		return
	var fast: bool = linear_velocity.length() > TRAIL_MIN_SPEED or (absf(angular_velocity.y) > TRAIL_MIN_SPIN and not _grounded and linear_velocity.length() > 8.0)
	trail_active = fast and holder == null
	_trail_alpha = move_toward(_trail_alpha, 1.0 if trail_active else 0.0, delta * (6.0 if trail_active else 2.5))
	if _trail_alpha <= 0.01:
		if not _trail_pts.is_empty():
			_trail_pts.clear()
			_trail_mesh.clear_surfaces()
		return
	_trail_pts.append(global_position)
	if _trail_pts.size() > TRAIL_POINTS:
		_trail_pts.remove_at(0)
	_trail_mesh.clear_surfaces()
	if _trail_pts.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n: int = _trail_pts.size()
	# Mas ancha cuanto mas fuerte va: un tiro a 30 m/s se lee en la pantalla del movil (antes 0.9 radios siempre).
	var width: float = 0.9 + 0.9 * clampf((linear_velocity.length() - TRAIL_MIN_SPEED) / 14.0, 0.0, 1.0)
	for i in n:
		var p: Vector3 = _trail_pts[i]
		var nxt: Vector3 = _trail_pts[mini(i + 1, n - 1)]
		var prv: Vector3 = _trail_pts[maxi(i - 1, 0)]
		var dir: Vector3 = (nxt - prv)
		dir.y = 0.0
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x).normalized() * radius * width * float(i) / float(n)
		var a: float = _trail_alpha * 0.65 * float(i) / float(n)
		var c := Color(1.0, 0.95, 0.75, a)
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(p + side)
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(p - side)
	_trail_mesh.surface_end()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	Prof.begin(&"pelota (integrate_forces)")
	_integrate_step(state)
	Prof.end(&"pelota (integrate_forces)")

func _integrate_step(state: PhysicsDirectBodyState3D) -> void:
	if _pending_teleport:
		_pending_teleport = false
		state.transform = Transform3D(Basis.IDENTITY, _teleport_pos)
		state.linear_velocity = _teleport_vel
		state.angular_velocity = Vector3.ZERO
		net_accel = Vector3.ZERO
		return
	var dt: float = state.step
	var v: Vector3 = state.linear_velocity
	var w: Vector3 = state.angular_velocity

	_grounded = false
	var floor_contact: bool = false
	for i in state.get_contact_count():
		if state.get_contact_local_normal(i).y > 0.6:
			floor_contact = true
			break
	_grounded = floor_contact

	# Rebote contra el piso: se detecta por inversion del signo de la velocidad vertical.
	if floor_contact and _prev_vy < -1.0 and v.y > 0.0:
		floor_bounce.emit(state.transform.origin, absf(_prev_vy))
	_prev_vy = v.y

	# Resistencia aerodinamica cuadratica.
	var spd: float = v.length()
	if spd > 0.01:
		var area: float = PI * radius * radius
		var drag_force: float = 0.5 * tuning.air_density * tuning.drag_coefficient * area * spd * spd
		var dv: float = minf(drag_force / mass * dt, spd)
		v -= v / spd * dv

	# Efecto Magnus (solo en el aire).
	if not floor_contact and spd > 1.0:
		v += w.cross(v) * (tuning.magnus_k / mass) * dt

	# Tiro sin giro: oscila a los lados (y algo arriba y abajo) mientras va rapido por el aire.
	if knuckle_accel > 0.0:
		_knuckle_t += dt
		if (floor_contact and _knuckle_airborne) or spd < KNUCKLE_MIN_SPEED or w.length() > KNUCKLE_MAX_SPIN or _knuckle_t > KNUCKLE_MAX_TIME:
			knuckle_accel = 0.0
		elif not floor_contact:
			_knuckle_airborne = true
			var side: Vector3 = Vector3.UP.cross(Vector3(v.x, 0.0, v.z)).normalized()
			var ph: float = TAU * _knuckle_freq * _knuckle_t + _knuckle_phase
			v += (side * sin(ph) + Vector3.UP * (0.4 * cos(1.3 * ph))) * knuckle_accel * dt

	# Rodadura sobre el piso: desaceleracion rolling_decel + rolling_viscous * v (paso exacto) y arrastra el giro para
	# no pelear con la friccion.
	if floor_contact and absf(v.y) < 0.6:
		var hv := Vector3(v.x, 0.0, v.z)
		var hs: float = hv.length()
		if hs > 0.0001:
			var new_hs: float = _roll_step(hs, dt)
			var ratio: float = new_hs / hs
			hv *= ratio
			v.x = hv.x
			v.z = hv.z
			w.x *= ratio
			w.z *= ratio
		w.y = move_toward(w.y, 0.0, tuning.spin_decel_ground * dt)
		if hs < 0.05:
			w = w.move_toward(Vector3.ZERO, tuning.spin_decel_ground * dt)

	# Red del arco: la tela empuja y frena la pelota (GoalNet).
	if net_accel != Vector3.ZERO:
		v += net_accel * dt
		net_accel = Vector3.ZERO
	if net_contact and not _net_was:
		net_hit.emit(v.length())
	_net_was = net_contact
	if net_contact:
		w *= exp(-tuning.net_grip * dt)
		net_contact = false

	if v.length() > tuning.max_speed:
		v = v.normalized() * tuning.max_speed
	if w.length() > tuning.max_spin:
		w = w.normalized() * tuning.max_spin

	state.linear_velocity = v
	state.angular_velocity = w

# --- Rodadura (modelo compartido con la prediccion, los pases y la conduccion) ------------------------------------
## Desaceleracion sobre el piso: a + c * min(v, vk) (BallTuning rolling_decel, rolling_viscous, rolling_viscous_knee).
## Por debajo de vk la parte proporcional manda (cada toque de conduccion sale, se frena y espera al jugador, como en
## First Touch Soccer); por encima es constante (a + c vk), asi un pase o tiro fuerte no se apaga a mitad de cancha.
## Medido con la pelota real rodando de 1.5 a 16 m/s: hasta 8 m/s el mejor ajuste es 0.28 + 1.02 v (error < 2 cm a 2 s),
## igual a BallTuning; las formulas no incluyen el arrastre del aire (k efectivo ~0.5 de la formula, BallPredictor).

## (a, c, vk) de la rodadura.
static func _roll_params() -> Vector3:
	var bt: BallTuning = Tuning.ball
	return Vector3(bt.rolling_decel, maxf(bt.rolling_viscous, 0.0001), maxf(bt.rolling_viscous_knee, 0.0))

## Desaceleracion (m/s2) de la rodadura a la velocidad v.
static func roll_decel(v: float) -> float:
	var p: Vector3 = _roll_params()
	return p.x + p.y * minf(maxf(v, 0.0), p.z)

## Tramo proporcional (v <= vk): velocidad y distancia exactas a los t s, hasta pararse.
static func _visc_speed(v0: float, t: float, p: Vector3) -> float:
	var q: float = p.x / p.y
	return maxf((v0 + q) * exp(-p.y * t) - q, 0.0)

static func _visc_stop_time(v0: float, p: Vector3) -> float:
	var q: float = p.x / p.y
	return log((v0 + q) / q) / p.y if v0 > 0.0 else 0.0

static func _visc_distance(v0: float, t: float, p: Vector3) -> float:
	var q: float = p.x / p.y
	var tt: float = clampf(t, 0.0, _visc_stop_time(v0, p))
	return (v0 + q) * (1.0 - exp(-p.y * tt)) / p.y - q * tt

## Velocidad tras rodar dt segundos sobre el piso partiendo de v (modelo exacto de _integrate_forces, sin el aire).
static func _roll_step(v: float, dt: float) -> float:
	return roll_speed(v, dt)

## Velocidad (m/s) de una pelota que rueda t segundos partiendo de v0.
static func roll_speed(v0: float, t: float) -> float:
	var p: Vector3 = _roll_params()
	if v0 > p.z:
		var dk: float = p.x + p.y * p.z
		var t1: float = (v0 - p.z) / dk
		if t <= t1:
			return v0 - dk * t
		return _visc_speed(p.z, t - t1, p)
	return _visc_speed(v0, t, p)

## Distancia (m) que recorre en t segundos una pelota que rueda partiendo de v0 (hasta detenerse).
static func roll_distance(v0: float, t: float) -> float:
	var p: Vector3 = _roll_params()
	if v0 > p.z:
		var dk: float = p.x + p.y * p.z
		var t1: float = (v0 - p.z) / dk
		if t <= t1:
			return v0 * t - 0.5 * dk * t * t
		return (v0 + p.z) * 0.5 * t1 + _visc_distance(p.z, t - t1, p)
	return _visc_distance(v0, t, p)

## Tiempo (s) hasta que la pelota que sale a v0 se detiene.
static func roll_stop_time(v0: float) -> float:
	var p: Vector3 = _roll_params()
	if v0 > p.z:
		return (v0 - p.z) / (p.x + p.y * p.z) + _visc_stop_time(p.z, p)
	return _visc_stop_time(v0, p)

## Velocidad inicial (m/s) para recorrer dist metros en t segundos rodando (la mas baja que llega, hasta 60 m/s).
static func roll_speed_for(dist: float, t: float) -> float:
	var p: Vector3 = _roll_params()
	var tt: float = maxf(t, 0.01)
	var d: float = maxf(dist, 0.0)
	# Todo el recorrido en el tramo proporcional: formula cerrada.
	var q: float = p.x / p.y
	var v: float = maxf((d + q * tt) * p.y / (1.0 - exp(-p.y * tt)) - q, 0.0)
	if v <= p.z and roll_stop_time(v) >= tt - 0.0001:
		return v
	var lo: float = 0.0
	var hi: float = 60.0
	if roll_distance(hi, tt) < d:
		return hi
	for i in 32:
		var mid: float = 0.5 * (lo + hi)
		if roll_distance(mid, tt) < d:
			lo = mid
		else:
			hi = mid
	return 0.5 * (lo + hi)

## Velocidad inicial (m/s) con la que la pelota rueda dist metros y se detiene ahi.
static func roll_speed_to_stop(dist: float) -> float:
	if dist <= 0.0:
		return 0.0
	var lo: float = 0.0
	var hi: float = 40.0
	for i in 32:
		var mid: float = 0.5 * (lo + hi)
		if roll_distance(mid, roll_stop_time(mid)) < dist:
			lo = mid
		else:
			hi = mid
	return 0.5 * (lo + hi)

## Tiempo (s) que tarda en recorrer dist metros una pelota que rueda partiendo de v0 (INF si se detiene antes).
static func roll_time(v0: float, dist: float) -> float:
	if dist <= 0.0:
		return 0.0
	var t_stop: float = roll_stop_time(v0)
	if roll_distance(v0, t_stop) < dist:
		return INF
	var lo: float = 0.0
	var hi: float = t_stop
	for i in 30:
		var mid: float = 0.5 * (lo + hi)
		if roll_distance(v0, mid) < dist:
			lo = mid
		else:
			hi = mid
	return 0.5 * (lo + hi)

## Velocidad (m/s) con la que tiene que salir la pelota para rodar a v_end dentro de t segundos.
static func roll_start_speed(v_end: float, t: float) -> float:
	var p: Vector3 = _roll_params()
	var q: float = p.x / p.y
	var ve: float = maxf(v_end, 0.0)
	if ve >= p.z:
		return ve + (p.x + p.y * p.z) * t
	var v: float = (ve + q) * exp(p.y * t) - q
	if v <= p.z:
		return v
	var tv: float = log((p.z + q) / (ve + q)) / p.y
	return p.z + (p.x + p.y * p.z) * maxf(t - tv, 0.0)

## Tiempo (s) en que una pelota tocada desde un cuerpo que va a vp m/s queda `advance` metros mas adelantada que el y
## con su misma velocidad (el cuerpo la alcanza sin que se escape ni se frene de golpe). 0 si advance <= 0.
static func roll_catch_time(advance: float, vp: float) -> float:
	if advance <= 0.0:
		return 0.0
	var lo: float = 0.0
	var hi: float = 3.0
	for i in 30:
		var mid: float = 0.5 * (lo + hi)
		var f: float = roll_distance(roll_start_speed(vp, mid), mid) - vp * mid
		if f < advance:
			lo = mid
		else:
			hi = mid
	return 0.5 * (lo + hi)

func _on_body_entered(body: Node) -> void:
	if body != last_toucher:
		knuckle_accel = 0.0
	if body.is_in_group("goal_frame"):
		hit_goal_frame.emit(global_position, linear_velocity.length())
	if body.has_method("on_ball_impact"):
		body.call("on_ball_impact", self)
