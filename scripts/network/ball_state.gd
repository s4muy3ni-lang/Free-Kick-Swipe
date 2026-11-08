class_name BallState
extends RefCounted
## Estado replicable de la pelota. Es un dato puro: no depende de nodos ni de la presentacion.
## En el futuro online, el servidor autoritativo produce estos snapshots y los clientes los aplican.

var tick: int = 0
var position: Vector3 = Vector3.ZERO
var linear_velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var orientation: Quaternion = Quaternion.IDENTITY
## Identificador del actor que la sostiene (arquero) o -1.
var holder_id: int = -1
var last_toucher_id: int = -1

func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"pos": [position.x, position.y, position.z],
		"lv": [linear_velocity.x, linear_velocity.y, linear_velocity.z],
		"av": [angular_velocity.x, angular_velocity.y, angular_velocity.z],
		"rot": [orientation.x, orientation.y, orientation.z, orientation.w],
		"holder": holder_id,
		"toucher": last_toucher_id,
	}

static func from_dict(d: Dictionary) -> BallState:
	var s := BallState.new()
	s.tick = int(d.get("tick", 0))
	s.position = _v3(d.get("pos", [0, 0, 0]))
	s.linear_velocity = _v3(d.get("lv", [0, 0, 0]))
	s.angular_velocity = _v3(d.get("av", [0, 0, 0]))
	var r: Array = d.get("rot", [0, 0, 0, 1])
	s.orientation = Quaternion(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	s.holder_id = int(d.get("holder", -1))
	s.last_toucher_id = int(d.get("toucher", -1))
	return s

static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
