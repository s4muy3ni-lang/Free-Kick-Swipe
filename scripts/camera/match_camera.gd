class_name MatchCamera
extends Camera3D
## Camara de transmision deportiva (de costado, como PES). Sigue una mezcla entre el jugador controlado
## y la pelota con amortiguacion exponencial (independiente de los FPS), ajusta el encuadre
## segun la separacion entre ambos y nunca entra en el volumen de las paredes.
## Mantiene un yaw fijo: el joystick siempre es relativo a la pantalla.
## Con el contexto del partido (ctx) el encuadre es dinamico: mas cerca que una vista general, se adelanta hacia donde
## ataca el equipo con la pelota y se abre lo justo para que las opciones de pase del poseedor sigan en cuadro.

## Encuadre de transmision como el de PES (video `videoplayback`): camara de costado, baja (30 grados) y lejos con
## lente cerrada; se ve el largo de la cancha de lado y el ancho entero, y los jugadores siguen grandes en el movil.
## Antes: 52 grados, 16 m y 42 grados de lente (casi cenital).
@export var pitch_deg: float = 30.0
@export var view_fov: float = 28.0
@export var base_distance: float = 30.0
@export var max_distance: float = 38.0
## Metros que el foco se adelanta hacia el arco que ataca el equipo con la pelota (se ve el espacio por delante).
@export var attack_lead: float = 2.5
## Desplazamiento lateral de la imagen (m): la jugada queda algo a la izquierda, lejos de los botones de accion.
@export var button_bias: float = 1.0
## Companeros del poseedor (los mas cercanos a la pelota) que el encuadre mantiene visibles como opciones de pase.
@export var pass_options_in_frame: int = 2
## Mas alla de esta distancia a la pelota (m) un companero no fuerza a abrir el plano.
@export var pass_option_range: float = 15.0
## Semivida del suavizado de posicion (s). Mayor = camara mas lenta.
@export var follow_halflife: float = 0.22
@export var zoom_halflife: float = 0.55
@export var ball_lead_time: float = 0.28
@export var focus_weight_with_ball: float = 0.4
@export var focus_weight_without_ball: float = 0.72
## Factor extra de distancia (lo usan las pruebas y herramientas; el de la persona es Tuning.camera_zoom).
@export var zoom_scale: float = 1.0
## Golpe de camara en los tiros fuertes (punch): grados que se cierra la lente y metros de sacudida con punch = 1, y su
## semivida (s). Da peso al disparo en una pantalla de movil (prueba03: el tiro no se notaba).
@export var punch_fov_deg: float = 2.2
@export var punch_shake_m: float = 0.10
@export var punch_halflife: float = 0.09

var ball: Node3D = null
var focus_actor: Node3D = null
var pitch_config: PitchConfig = null
## Contexto del partido (opcional): da el poseedor y sus companeros para el encuadre dinamico.
var ctx: MatchContext = null

var _focus: Vector3 = Vector3.ZERO
var _distance: float = 20.0
var _initialized: bool = false
var _punch: float = 0.0

func _ready() -> void:
	fov = view_fov
	near = 0.5
	far = 140.0
	keep_aspect = Camera3D.KEEP_HEIGHT
	current = true
	if pitch_config == null:
		pitch_config = Tuning.pitch
	_distance = base_distance
	h_offset = button_bias

func setup(ball_node: Node3D, actor: Node3D, cfg: PitchConfig = null) -> void:
	ball = ball_node
	focus_actor = actor
	if cfg != null:
		pitch_config = cfg
	snap_to_target()

func set_focus_actor(actor: Node3D) -> void:
	focus_actor = actor

func snap_to_target() -> void:
	_focus = _target_focus()
	_distance = _target_distance()
	_apply_transform()
	_initialized = true

func _process(delta: float) -> void:
	Prof.begin(&"camara")
	_camera_step(delta)
	Prof.end(&"camara")

func _camera_step(delta: float) -> void:
	if ball == null:
		return
	if not _initialized:
		snap_to_target()
		return
	var target: Vector3 = _target_focus()
	_focus = _damp_vec3(_focus, target, follow_halflife, delta)
	_distance = _damp_float(_distance, _target_distance(), zoom_halflife, delta)
	_apply_transform()
	_apply_punch(delta)

## Golpe de camara (0..1): una sacudida breve y un cierre de lente que se desvanecen solos. Lo dispara un tiro fuerte.
func punch(strength: float) -> void:
	_punch = maxf(_punch, clampf(strength, 0.0, 1.0))

## Conecta el golpe de camara a los golpes de la pelota: solo los disparos de un jugador (no los rebotes ni el arquero).
func watch_shots(b: Ball) -> void:
	if b != null and not b.impulse.is_connected(_on_ball_impulse):
		b.impulse.connect(_on_ball_impulse)

func _on_ball_impulse(actor: Node, _dv: float, speed: float) -> void:
	if actor is Footballer and speed > 16.0:
		punch(clampf((speed - 16.0) / 14.0, 0.3, 1.0))

func _apply_punch(delta: float) -> void:
	if _punch <= 0.002:
		_punch = 0.0
		fov = view_fov
		return
	fov = view_fov - _punch * punch_fov_deg
	var s: float = _punch * punch_shake_m
	global_position += global_transform.basis.x * randf_range(-s, s) + global_transform.basis.y * randf_range(-s, s) * 0.6
	_punch *= pow(0.5, delta / maxf(punch_halflife, 0.001))

func _target_focus() -> Vector3:
	var ball_pos: Vector3 = Vector3.ZERO
	var ball_vel: Vector3 = Vector3.ZERO
	if ball != null:
		ball_pos = ball.global_position
		if ball is RigidBody3D:
			ball_vel = (ball as RigidBody3D).linear_velocity
	var lead_ball: Vector3 = ball_pos + Vector3(ball_vel.x, 0.0, ball_vel.z) * ball_lead_time
	var f: Vector3 = lead_ball
	if focus_actor != null and is_instance_valid(focus_actor):
		var a: Vector3 = focus_actor.global_position
		var near_ball: bool = a.distance_to(ball_pos) < 3.0
		var w: float = focus_weight_with_ball if near_ball else focus_weight_without_ball
		f = a.lerp(lead_ball, w)
	var owner: Footballer = _possessor()
	if owner != null:
		f.x += (1.0 if owner.team == 0 else -1.0) * attack_lead
	f.y = 0.0
	# Limites: que los arcos sigan visibles y la camara no persiga hasta los extremos.
	var hl: float = pitch_config.half_length()
	var hw: float = pitch_config.half_width()
	f.x = clampf(f.x, -(hl - 8.0), hl - 8.0)
	f.z = clampf(f.z, -hw * 0.55, hw * 0.55)
	return f

func _possessor() -> Footballer:
	if ctx == null or not is_instance_valid(ctx):
		return null
	var p: Footballer = ctx.possessor
	return p if p != null and is_instance_valid(p) else null

## Puntos que deben quedar en cuadro: pelota, jugador enfocado y las opciones de pase mas cercanas del poseedor.
func frame_points() -> Array[Vector3]:
	var pts: Array[Vector3] = []
	if ball == null:
		return pts
	var bp: Vector3 = ball.global_position
	pts.append(Vector3(bp.x, 0.0, bp.z))
	if focus_actor != null and is_instance_valid(focus_actor):
		pts.append(Vector3(focus_actor.global_position.x, 0.0, focus_actor.global_position.z))
	var owner: Footballer = _possessor()
	if owner != null:
		var mates: Array = []
		for m in ctx.footballers:
			if m != owner and m.team == owner.team:
				var d: float = Vector2(m.global_position.x - bp.x, m.global_position.z - bp.z).length()
				if d <= pass_option_range:
					mates.append([d, m])
		mates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for i in mini(pass_options_in_frame, mates.size()):
			var mp: Vector3 = (mates[i][1] as Node3D).global_position
			pts.append(Vector3(mp.x, 0.0, mp.z))
	return pts

func _target_distance() -> float:
	# Se abre segun lo lejos que queden del foco los puntos que hay que ver. El ancho visible de la pantalla (eje X del
	# mundo) es mayor que el alto (eje Z, acortado por la inclinacion): la separacion en Z cuenta casi el doble.
	var f: Vector3 = _target_focus()
	var need: float = 0.0
	for p in frame_points():
		var dx: float = absf(p.x - f.x) - button_bias
		var dz: float = absf(p.z - f.z)
		need = maxf(need, maxf(dx, dz * 1.8))
	# Zoom elegido por la persona (Tuning.camera_zoom, menu de pausa): escala la distancia de todo el encuadre.
	var z: float = Tuning.camera_zoom * zoom_scale
	return clampf(base_distance + maxf(need - 6.0, 0.0) * 0.9, base_distance, max_distance) * z

func _apply_transform() -> void:
	var p: float = deg_to_rad(pitch_deg)
	var offset := Vector3(0.0, sin(p), cos(p)) * _distance
	var pos: Vector3 = _focus + offset
	# Evitar atravesar paredes y luces: siempre por encima de la altura de las paredes.
	var min_y: float = pitch_config.wall_height + 2.0
	pos.y = maxf(pos.y, min_y)
	look_at_from_position(pos, _focus, Vector3.UP)

static func _damp_float(current_value: float, target: float, halflife: float, delta: float) -> float:
	var a: float = 1.0 - pow(0.5, delta / maxf(halflife, 0.0001))
	return lerpf(current_value, target, a)

static func _damp_vec3(current_value: Vector3, target: Vector3, halflife: float, delta: float) -> Vector3:
	var a: float = 1.0 - pow(0.5, delta / maxf(halflife, 0.0001))
	return current_value.lerp(target, a)

## Convierte un vector 2D de pantalla (x derecha, y abajo) en direccion de mundo sobre el plano XZ.
func screen_to_world_dir(v: Vector2) -> Vector3:
	var basis_x: Vector3 = global_transform.basis.x
	var basis_z: Vector3 = global_transform.basis.z
	var right := Vector3(basis_x.x, 0.0, basis_x.z).normalized()
	var back := Vector3(basis_z.x, 0.0, basis_z.z).normalized()
	return (right * v.x + back * v.y)
