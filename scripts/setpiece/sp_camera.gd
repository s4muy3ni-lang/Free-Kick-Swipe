class_name SpCamera
extends Camera3D
## Camara de los modos de tiros libres y penales: transiciones suaves (amortiguadas, sin saltos) entre encuadres:
##  - detras del tirador (penal: fija durante toda la ejecucion; tiro libre: con zoom y siguiendo un poco la pelota),
##  - detras del arco (cuando el usuario ataja), vista cenital para colocar la pelota y primer plano del festejo.
## Mantiene la altura de la imagen (keep_height): en pantallas mas anchas se ve mas campo a los costados, sin deformar.

var target_pos := Vector3(0, 10, 10)
var target_look := Vector3.ZERO
var target_fov: float = 50.0
## Semivida (s) de la aproximacion al encuadre pedido.
var halflife: float = 0.35
var _look := Vector3.ZERO
## Seguimiento de un nodo (festejo): se recalcula el encuadre con su posicion.
var follow: Node3D = null
var follow_offset := Vector3(3.0, 1.6, 0.0)
var follow_look_height: float = 1.1

func _ready() -> void:
	keep_aspect = Camera3D.KEEP_HEIGHT
	near = 0.1
	far = 400.0

## Encuadre nuevo. instant: sin transicion.
func frame(pos: Vector3, look: Vector3, fov_deg: float = 50.0, instant: bool = false, hl: float = 0.35) -> void:
	follow = null
	target_pos = pos
	target_look = look
	target_fov = fov_deg
	halflife = hl
	if instant:
		global_position = pos
		_look = look
		fov = fov_deg
		look_at(_look, Vector3.UP)

## Sigue a un nodo con un desplazamiento en el marco del mundo (primer plano de festejos o reacciones).
func follow_node(n: Node3D, offset: Vector3, look_h: float = 1.1, hl: float = 0.5) -> void:
	follow = n
	follow_offset = offset
	follow_look_height = look_h
	halflife = hl

func _process(delta: float) -> void:
	if follow != null and is_instance_valid(follow):
		# Sigue la cadera (el nodo del cuerpo puede quedar atras si el clip lleva la cadera).
		var fp: Vector3 = follow.global_position
		if follow is SpActor:
			var hips: Vector3 = (follow as SpActor).bone_world(SpActor.HIPS)
			fp = Vector3(hips.x, 0.0, hips.z)
		target_look = fp + Vector3.UP * follow_look_height
		target_pos = fp + follow_offset
	var k: float = 1.0 - pow(0.5, delta / maxf(halflife, 0.01))
	global_position = global_position.lerp(target_pos, k)
	_look = _look.lerp(target_look, k)
	fov = lerpf(fov, target_fov, k)
	if global_position.distance_to(_look) > 0.01:
		look_at(_look, Vector3.UP)

# --- Encuadres -------------------------------------------------------------------------------------------------------------

## Detras del tirador, mirando al arco: la pelota abajo al centro y el arco con el arquero en el tercio superior.
static func behind_ball(ball: Vector3, goal_center: Vector3, zoom: float = 1.0, penalty: bool = false) -> Array:
	var to := Vector3(goal_center.x - ball.x, 0.0, goal_center.z - ball.z)
	var dist: float = to.length()
	var dir: Vector3 = to / maxf(dist, 0.01)
	# Alta y detras (como en las referencias): el tirador abajo, la pelota a dos tercios y el arco arriba.
	var back: float = (10.0 if penalty else 10.5) / zoom
	var height: float = (5.0 if penalty else 5.4) / sqrt(zoom)
	var pos: Vector3 = Vector3(ball.x, 0.0, ball.z) - dir * back + Vector3.UP * height
	var look: Vector3 = Vector3(ball.x, 0.0, ball.z) + dir * (4.5 if penalty else 5.5)
	var fov_deg: float = 42.0 if penalty else 44.0
	return [pos, look, fov_deg]

## Detras del arco (usuario arquero): se ve al arquero de espaldas, el arco y al tirador de frente.
static func behind_goal(goal_center: Vector3, ball: Vector3) -> Array:
	var dir := Vector3(ball.x - goal_center.x, 0.0, ball.z - goal_center.z).normalized()
	var pos: Vector3 = goal_center - dir * 6.5 + Vector3.UP * 3.0
	var look: Vector3 = goal_center + dir * 7.0 + Vector3.UP * 0.6
	return [pos, look, 50.0]

## Vista desde arriba del campo de ataque para colocar la pelota.
static func placement(goal_x: float) -> Array:
	var center := Vector3(goal_x - 24.0, 0.0, 0.0)
	return [center + Vector3(-22.0, 36.0, 0.0), center + Vector3(2.0, 0.0, 0.0), 50.0]
