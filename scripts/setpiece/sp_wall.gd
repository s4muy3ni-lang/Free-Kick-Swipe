class_name SpWall
extends Node
## Barrera de los tiros libres: jugadores reales (SpActor con capsula de colision: la pelota choca de verdad) a 9,15 m de
## la pelota, tapando el palo cercano. Cada uno con su postura de barrera (clips «wall» en el sitio), pequeñas variaciones
## de posicion, giro y ritmo; al golpe saltan con un clip de salto de barrera cuya altura maxima llega cuando la pelota
## cruza la barrera (con su propio retraso de reaccion); si saltan, la pelota puede pasar por debajo. Despues reaccionan.

const DISTANCE := 9.15
const SPACING := 0.56

var players: Array[SpActor] = []
var rng := RandomNumberGenerator.new()
var _stand: Array[StringName] = []
var _jumps: Array[StringName] = []
var _jump_at: Array[float] = []
var _apex_cache: Dictionary = {}
var _center := Vector3.ZERO
var _face := Vector3(-1, 0, 0)

func _ready() -> void:
	for id in SpClips.by_role(&"wall", false):
		if str(SpClips.meta(id).get("loop", false)) == "true":
			_stand.append(id)
		else:
			_jumps.append(id)

## Cantidad de jugadores segun la distancia y el angulo al arco (mas cerca y mas de frente, mas jugadores).
static func count_for(ball: Vector3, goal_x: float) -> int:
	var to := Vector2(goal_x - ball.x, -ball.z)
	var dist: float = to.length()
	var ang: float = absf(rad_to_deg(atan2(absf(to.y), to.x)))
	if dist > 34.0:
		return 2
	if ang > 55.0:
		return 2
	if ang > 35.0 or dist > 28.0:
		return 3
	if dist < 21.0:
		return 5
	return 4

## Punto que tapa la barrera: un poco por fuera del palo cercano (el arquero cubre el resto).
static func cover_point(ball: Vector3, goal_x: float, half_goal: float) -> Vector3:
	var near_z: float = half_goal * (1.0 if ball.z >= 0.0 else -1.0)
	if absf(ball.z) < 2.0:
		near_z = 0.0
	return Vector3(goal_x, 0.0, near_z * 0.75)

## Arma la barrera para una pelota en `ball` (actores ya creados por el juego).
func arrange(actors: Array[SpActor], ball: Vector3, goal_x: float, half_goal: float) -> void:
	players = actors
	var target: Vector3 = cover_point(ball, goal_x, half_goal)
	var dir: Vector3 = Vector3(target.x - ball.x, 0.0, target.z - ball.z).normalized()
	_center = Vector3(ball.x, 0.0, ball.z) + dir * DISTANCE
	_face = -dir
	var side := SpClips.right_of(dir)
	var n: int = actors.size()
	_jump_at.clear()
	for i in n:
		var a: SpActor = actors[i]
		a.role = &"wall"
		var off: float = (float(i) - float(n - 1) * 0.5) * SPACING
		var jitter := Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.04, 0.04))
		a.stop_moving()
		a.global_position = _center + side * off + jitter
		a.set_facing(_face.rotated(Vector3.UP, rng.randf_range(-0.12, 0.12)))
		var st: StringName = _stand[(i + rng.randi()) % _stand.size()] if not _stand.is_empty() else &""
		a.play_loop(st, 0.2, rng.randf_range(0.85, 1.15))
		_jump_at.append(-1.0)
		a.visible = true

## El tirador golpeo: cada uno decide su salto para que la cadera este arriba cuando llega la pelota.
func on_kick(ball_pos: Vector3, velocity: Vector3) -> void:
	var h := Vector2(velocity.x, velocity.z).length()
	var t_wall: float = DISTANCE / maxf(h, 5.0)
	for i in players.size():
		if _jumps.is_empty():
			break
		var id: StringName = _jumps[(i * 3 + rng.randi()) % _jumps.size()]
		var apex: float = _apex_time(id)
		var reaction: float = rng.randf_range(0.08, 0.16)
		var start: float = clampf(t_wall - apex, reaction, 0.45)
		_jump_at[i] = start
		players[i].set_meta("jump_clip", id)

func _physics_process(delta: float) -> void:
	for i in players.size():
		if i >= _jump_at.size() or _jump_at[i] < 0.0:
			continue
		_jump_at[i] -= delta
		if _jump_at[i] <= 0.0:
			_jump_at[i] = -1.0
			var a: SpActor = players[i]
			a.play_here(a.get_meta("jump_clip", &""), 0.1)
			a.clip_finished.connect(_after_jump.bind(a), CONNECT_ONE_SHOT)

func _after_jump(_id: StringName, a: SpActor) -> void:
	if not _stand.is_empty():
		a.play_loop(_stand[rng.randi() % _stand.size()], 0.25)

## Instante (s) del clip de salto en que la cadera esta mas alta (pista de posicion de la cadera).
func _apex_time(id: StringName) -> float:
	if _apex_cache.has(id):
		return _apex_cache[id]
	var a: Animation = SpClips.anim(id)
	var best_t: float = 0.3
	if a != null:
		var tr: int = -1
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).ends_with("Hips"):
				tr = t
				break
		if tr >= 0:
			var best_y: float = -INF
			var steps: int = int(a.length * 30.0)
			for s in steps + 1:
				var tt: float = a.length * float(s) / float(maxi(steps, 1))
				var y: float = a.position_track_interpolate(tr, tt).y
				if y > best_y:
					best_y = y
					best_t = tt
	_apex_cache[id] = best_t
	return best_t

## Reaccion de la barrera al final de la jugada (festejan si no fue gol).
func react(goal: bool) -> void:
	for a in players:
		var id: StringName = SpReactions.pick(SpReactions.SAD if goal else SpReactions.HAPPY_DEFENDER, rng, 1.2, 1.0)
		if id != &"":
			a.play_here(id, 0.3)
