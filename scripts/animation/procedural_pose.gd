class_name ProceduralPose
extends SkeletonModifier3D
## Capa de animacion PROCEDURAL aplicada despues del AnimationTree (los clips de Tripo no incluyen patadas).
## Hoy implementa la patada (pase / tiro) con fases: balanceo hacia atras -> golpeo en el instante de contacto
## -> continuacion -> recuperacion. El contacto ocurre exactamente en contact_time desde start_kick(), y es el
## momento en el que BallHandler aplica el impulso a la pelota (sincronia cuerpo-pelota).
##
## Convencion del esqueleto (espacio del Skeleton3D, sin rotacion en el GLB): adelante = +X, arriba = +Y,
## lateral = Z. Una rotacion POSITIVA alrededor de +Z balancea una pierna hacia ADELANTE.

const LATERAL := Vector3(0, 0, 1)
const FOLLOW_THROUGH := 0.16
const RECOVERY := 0.32

var skeleton: Skeleton3D = null

var _bones: Dictionary = {}
var _kicking: bool = false
var _t: float = 0.0
var _contact_time: float = 0.12
var _power: float = 0.5
var _side: int = 1                 # +1 pierna derecha, -1 izquierda
var _weight: float = 1.0
## Inclinacion del tronco (rad) que pide la marcha: hacia delante (+) / atras y hacia la izquierda (+) / derecha. Se
## reparte por la columna (Spine, Spine1, Spine2); caderas y piernas no se tocan (los pies siguen donde los pone la
## animacion para tocar la pelota).
var lean_pitch: float = 0.0
var lean_roll: float = 0.0
const LEAN_SHARE := [0.4, 0.3, 0.3]
const FORWARD := Vector3(1, 0, 0)

func setup(skel: Skeleton3D) -> void:
	skeleton = skel
	for key in ["RightUpLeg", "RightLeg", "RightFoot", "LeftUpLeg", "LeftLeg", "LeftFoot", "Spine", "Spine1", "Spine2", "Hips"]:
		_bones[key] = skel.find_bone("mixamorig_%s" % key)

## Inicia una patada. contact_time = segundos hasta el golpeo; power 0..1; side +1 derecha / -1 izquierda.
func start_kick(contact_time: float, power: float, side: int) -> void:
	_contact_time = maxf(contact_time, 0.05)
	_power = clampf(power, 0.0, 1.0)
	_side = 1 if side >= 0 else -1
	_t = 0.0
	_kicking = true

func is_kicking() -> bool:
	return _kicking

func kick_time() -> float:
	return _t

func cancel() -> void:
	_kicking = false

func total_duration() -> float:
	return _contact_time + FOLLOW_THROUGH + RECOVERY

func _process_modification_with_delta(delta: float) -> void:
	Prof.begin(&"pose procedural")
	_pose_step(delta)
	Prof.end(&"pose procedural")

func _pose_step(delta: float) -> void:
	if skeleton == null:
		return
	_apply_lean()
	if not _kicking:
		return
	_t += delta
	if _t >= total_duration():
		_kicking = false
		return
	apply_at(_t)

## Aplica la pose de patada correspondiente al instante t (sin avanzar el tiempo). Util para herramientas.
func apply_at(t: float) -> void:
	var angles: Dictionary = kick_angles(t, _contact_time, _power)
	var w: float = envelope(t, _contact_time)
	var thigh: int = _bones["RightUpLeg"] if _side > 0 else _bones["LeftUpLeg"]
	var knee: int = _bones["RightLeg"] if _side > 0 else _bones["LeftLeg"]
	var support_knee: int = _bones["LeftLeg"] if _side > 0 else _bones["RightLeg"]
	var spine: int = _bones["Spine1"]
	_rotate(thigh, LATERAL, angles["hip"] * w)
	_rotate(knee, LATERAL, angles["knee"] * w)
	_rotate(support_knee, LATERAL, angles["support_knee"] * w)
	_rotate(spine, LATERAL, angles["torso"] * w)

## Inclinacion del tronco: en el espacio del esqueleto adelante = +X, derecha = +Z; girar la columna sobre +Z en
## negativo la lleva hacia delante y sobre +X en negativo, hacia la izquierda.
func _apply_lean() -> void:
	if absf(lean_pitch) < 0.002 and absf(lean_roll) < 0.002:
		return
	var names := ["Spine", "Spine1", "Spine2"]
	for i in 3:
		var b: int = _bones.get(names[i], -1)
		_rotate(b, LATERAL, -lean_pitch * LEAN_SHARE[i])
		_rotate(b, FORWARD, -lean_roll * LEAN_SHARE[i])

func _rotate(bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.0001:
		return
	var g: Transform3D = skeleton.get_bone_global_pose(bone)
	skeleton.set_bone_global_pose(bone, Transform3D(Basis(axis, angle) * g.basis, g.origin))

## Curvas de la patada (radianes) en funcion del tiempo. Pura: se puede probar sin esqueleto.
static func kick_angles(t: float, contact: float, power: float) -> Dictionary:
	var back: float = 0.55 + 0.45 * power             # amplitud del balanceo hacia atras
	var knee_bend: float = 0.95 + 0.6 * power
	var follow: float = 0.42 + 0.3 * power           # amplitud de la continuacion (pie ~ a la altura de la rodilla)
	var hip: float = 0.0
	var knee: float = 0.0
	var torso: float = 0.0
	var support: float = 0.0
	var wind_end: float = contact * 0.62
	if t < wind_end:
		var u: float = _ease_out(t / wind_end)
		hip = -back * u
		knee = -knee_bend * u
		torso = 0.14 * u
		support = -0.25 * u
	elif t < contact:
		var u2: float = _ease_in((t - wind_end) / (contact - wind_end))
		hip = lerpf(-back, 0.24, u2)
		knee = lerpf(-knee_bend, -0.25, u2)
		torso = lerpf(0.14, -0.14, u2)
		support = -0.25
	elif t < contact + FOLLOW_THROUGH:
		var u3: float = _ease_out((t - contact) / FOLLOW_THROUGH)
		hip = lerpf(0.24, follow, u3)
		knee = lerpf(-0.25, -0.08, u3)
		torso = lerpf(-0.14, -0.2, u3)
		support = -0.25
	else:
		var u4: float = clampf((t - contact - FOLLOW_THROUGH) / RECOVERY, 0.0, 1.0)
		var s: float = _smooth(u4)
		hip = lerpf(follow, 0.0, s)
		knee = lerpf(-0.05, 0.0, s)
		torso = lerpf(-0.2, 0.0, s)
		support = lerpf(-0.25, 0.0, s)
	return {"hip": hip, "knee": knee, "torso": torso, "support_knee": support}

## Peso de mezcla con la animacion base: entra rapido, sale al final de la recuperacion.
static func envelope(t: float, contact: float) -> float:
	var enter: float = clampf(t / maxf(contact * 0.35, 0.02), 0.0, 1.0)
	var end_t: float = contact + FOLLOW_THROUGH + RECOVERY
	var leave: float = clampf((end_t - t) / (RECOVERY * 0.6), 0.0, 1.0)
	return _smooth(enter) * _smooth(leave)

static func _ease_out(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c)

static func _ease_in(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c

static func _smooth(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)
