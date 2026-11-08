class_name PlayRecording
extends Node
## Repeticiones por ESTADOS (fase 9 del plan): no guarda video ni vuelve a simular. Durante una jugada registra, en cada
## paso de fisica, la posicion y la rotacion de la pelota y, de cada jugador (SpActor), su posicion, su rumbo, el clip que
## reproduce, el instante del clip y si se ve. La repeticion pone todo exactamente donde estuvo (a velocidad normal o en
## camara lenta, interpolando entre pasos) con el juego en pausa, y al terminar deja el juego como estaba.
##
## Tamaño: ~28 bytes de pelota + ~25 por jugador por paso: una jugada de 6 s con 12 jugadores ronda los 120 KB.

const MAX_FRAMES := 720

var ball: Ball
var actors: Array[SpActor] = []
var recording: bool = false
## Pelota: posicion y rotacion (cuaternion como Vector4) por paso.
var ball_pos := PackedVector3Array()
var ball_rot := PackedVector4Array()
## Jugadores: por jugador, sus pistas (Array comunes: los Packed*Array son valores y un append dentro de otro Array
## modificaria una copia).
var a_pos: Array = []
var a_yaw: Array = []
var a_anim: Array = []
var a_time: Array = []
var a_vis: Array = []
## Marcas (paso del contacto del golpe, del gol...) para la camara lenta y los mejores momentos.
var marks: Dictionary = {}

func setup(b: Ball, list: Array[SpActor]) -> void:
	ball = b
	actors = list

func frames() -> int:
	return ball_pos.size()

func start() -> void:
	ball_pos = PackedVector3Array()
	ball_rot = PackedVector4Array()
	a_pos = []
	a_yaw = []
	a_anim = []
	a_time = []
	a_vis = []
	for i in actors.size():
		a_pos.append([])
		a_yaw.append([])
		a_anim.append([])
		a_time.append([])
		a_vis.append([])
	marks = {}
	recording = true

func stop() -> void:
	recording = false

## Marca el paso actual (p. ej. &"contacto", &"gol").
func mark(name: StringName) -> void:
	if recording:
		marks[name] = frames()

func _physics_process(_delta: float) -> void:
	if not recording or ball == null:
		return
	if frames() >= MAX_FRAMES:
		recording = false
		return
	Prof.begin(&"repeticion (registro)")
	ball_pos.append(ball.global_position)
	var q: Quaternion = ball.global_transform.basis.get_rotation_quaternion()
	ball_rot.append(Vector4(q.x, q.y, q.z, q.w))
	for i in actors.size():
		var a: SpActor = actors[i]
		(a_pos[i] as Array).append(a.global_position)
		(a_yaw[i] as Array).append(a.rotation.y)
		var ap: AnimationPlayer = a.anim_player
		var playing: bool = ap != null and ap.current_animation != ""
		(a_anim[i] as Array).append(StringName(ap.current_animation) if playing else &"")
		(a_time[i] as Array).append(ap.current_animation_position if playing else 0.0)
		(a_vis[i] as Array).append(a.visible)
	Prof.end(&"repeticion (registro)")

## Pone la escena en el instante f (0..frames-1, con decimales: interpola entre pasos).
func apply(f: float) -> void:
	var n: int = frames()
	if n == 0:
		return
	var f0: int = clampi(int(floor(f)), 0, n - 1)
	var f1: int = mini(f0 + 1, n - 1)
	var u: float = clampf(f - float(f0), 0.0, 1.0)
	var r0: Vector4 = ball_rot[f0]
	var r1: Vector4 = ball_rot[f1]
	var q: Quaternion = Quaternion(r0.x, r0.y, r0.z, r0.w).slerp(Quaternion(r1.x, r1.y, r1.z, r1.w), u)
	ball.global_transform = Transform3D(Basis(q), ball_pos[f0].lerp(ball_pos[f1], u))
	for i in actors.size():
		var a: SpActor = actors[i]
		a.visible = bool(a_vis[i][f0])
		if not a.visible:
			continue
		a.global_position = (a_pos[i][f0] as Vector3).lerp(a_pos[i][f1], u)
		a.rotation.y = lerp_angle(float(a_yaw[i][f0]), float(a_yaw[i][f1]), u)
		var anim: StringName = (a_anim[i] as Array)[f0]
		if anim == &"" or a.anim_player == null or not a.anim_player.has_animation(anim):
			continue
		var t0: float = float(a_time[i][f0])
		var t1: float = float(a_time[i][f1])
		# Mismo clip en los dos pasos: se interpola el instante; si cambio, se usa el del paso.
		var t: float = lerpf(t0, t1, u) if (a_anim[i] as Array)[f1] == anim and t1 >= t0 else t0
		if a.anim_player.current_animation != String(anim):
			a.anim_player.play(anim, 0.0)
		a.anim_player.seek(t, true)
		a.anim_player.pause()
