class_name SpFieldPlayers
extends Node
## Jugadores sueltos de los tiros libres (requisito del usuario): compañeros del tirador y defensores en el area. Nadie mas
## remata: los compañeros se mueven como para un centro o esperan el rebote; los defensores los marcan y, si una pelota que
## va al arco les pasa a la altura de la cabeza y llegan, la despejan de cabeza (si no llegan, no la tocan). Todos tienen
## capsula de colision (la pelota rebota en el cuerpo) y reaccionan al resultado.

var attackers: Array[SpActor] = []
var defenders: Array[SpActor] = []
var rng := RandomNumberGenerator.new()
var ball: Ball
var goal_x: float = 52.5
var _header_at: Dictionary = {}
var _heading: Dictionary = {}
var _cleared: bool = false

const ATTACK_SPOTS := [Vector2(-9.0, -5.5), Vector2(-12.5, 2.5), Vector2(-7.0, 6.5)]

func setup(att: Array[SpActor], dfn: Array[SpActor], b: Ball, gx: float) -> void:
	attackers = att
	defenders = dfn
	ball = b
	goal_x = gx

## Coloca a los jugadores en el area (en espejo segun el lado de la pelota) mirando a la pelota.
func arrange(ball_pos: Vector3, wall_points: Array) -> void:
	_cleared = false
	_header_at.clear()
	_heading.clear()
	var side: float = -1.0 if ball_pos.z > 0.0 else 1.0
	for i in attackers.size():
		var s: Vector2 = ATTACK_SPOTS[i % ATTACK_SPOTS.size()]
		var p := Vector3(goal_x + s.x + rng.randf_range(-0.8, 0.8), 0.0, s.y * side + rng.randf_range(-0.8, 0.8))
		p = _away_from(p, wall_points, ball_pos)
		_place(attackers[i], p, ball_pos)
		if i < defenders.size():
			var d: Vector3 = p + Vector3(0.9, 0.0, 0.35 * side)
			_place(defenders[i], d, ball_pos)

func _away_from(p: Vector3, avoid: Array, ball_pos: Vector3) -> Vector3:
	for q in avoid:
		if Vector3(p.x - q.x, 0, p.z - q.z).length() < 1.6:
			p.z += 2.0 * (1.0 if p.z >= q.z else -1.0)
	if Vector3(p.x - ball_pos.x, 0, p.z - ball_pos.z).length() < 9.5:
		p.x = maxf(p.x, ball_pos.x + 9.5)
	return p

func _place(a: SpActor, p: Vector3, look: Vector3) -> void:
	a.stop_moving()
	a.global_position = p
	a.set_facing(look - p)
	var pool: Array[StringName] = SpClips.by_role(&"idle_ready", false)
	if not pool.is_empty():
		a.play_loop(pool[rng.randi() % pool.size()], 0.2, rng.randf_range(0.85, 1.1))
	a.visible = true

## Al golpe: los compañeros van al rebote, los defensores los siguen; si un defensor llega a cabecear la pelota, se prepara.
func on_kick(traj: PackedVector3Array, step: float) -> void:
	var jog: StringName = SpShooter._loop_for(4.0)
	for i in attackers.size():
		var a: SpActor = attackers[i]
		var tgt := Vector3(goal_x - rng.randf_range(4.0, 7.0), 0.0, clampf(a.global_position.z * 0.6, -6.0, 6.0))
		a.move_to(tgt, rng.randf_range(3.5, 4.8), jog)
		if i < defenders.size():
			defenders[i].move_to(tgt + Vector3(0.8, 0.0, 0.4), rng.randf_range(3.3, 4.6), jog)
	# Despeje de cabeza: el defensor que este a menos de 1,3 m de donde pasa la pelota a la altura de la cabeza.
	for d in defenders:
		var p0: Vector3 = d.global_position
		for k in traj.size():
			var t: float = float(k) * step
			if t < 0.35:
				continue
			var q: Vector3 = traj[k]
			if q.x > goal_x:
				break
			if q.y < 1.55 or q.y > 2.45:
				continue
			# Donde estara el defensor (se mueve a ~4 m/s hacia su destino).
			if Vector2(q.x - p0.x, q.z - p0.z).length() < 1.3 + 3.0 * t * 0.4:
				_header_at[d] = maxf(t - 0.3, 0.0)
				break

func _physics_process(delta: float) -> void:
	for d in _header_at.keys():
		_header_at[d] = float(_header_at[d]) - delta
		if float(_header_at[d]) <= 0.0:
			_header_at.erase(d)
			var a: SpActor = d
			var pool: Array[StringName] = SpClips.by_role(&"header", false)
			if not pool.is_empty():
				a.face_towards(ball.global_position - a.global_position)
				a.play_here(pool[rng.randi() % mini(pool.size(), 12)], 0.12)
			_heading[a] = 0.6
	for a in _heading.keys():
		_heading[a] = float(_heading[a]) - delta
		if float(_heading[a]) <= 0.0:
			_heading.erase(a)
			continue
		if _cleared or ball.is_held():
			continue
		var head: Vector3 = (a as SpActor).bone_world(SpActor.HEAD)
		if head.distance_to(ball.global_position) < 0.34:
			# Despeje: la pelota sale hacia fuera del area y arriba, con la velocidad de un cabezazo.
			var away := Vector3(-1.0, 0.0, signf(ball.global_position.z) * 0.6).normalized()
			ball.kick(away * 11.0 + Vector3.UP * 6.0, Vector3.ZERO, a)
			_cleared = true

func react(goal: bool) -> void:
	for a in attackers:
		var id: StringName = SpReactions.pick(SpReactions.GOAL_TEAM if goal else SpReactions.SAD, rng, 1.5, 1.0)
		if id != &"":
			a.stop_moving()
			a.play_here(id, 0.3)
	for a in defenders:
		var id2: StringName = SpReactions.pick(SpReactions.SAD if goal else SpReactions.HAPPY_DEFENDER, rng, 1.5, 1.0)
		if id2 != &"":
			a.stop_moving()
			a.play_here(id2, 0.3)

func cleared() -> bool:
	return _cleared
