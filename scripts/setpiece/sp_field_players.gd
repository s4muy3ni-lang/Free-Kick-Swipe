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
			_place(defenders[i], d, ball_pos, &"defend")

func _away_from(p: Vector3, avoid: Array, ball_pos: Vector3) -> Vector3:
	for q in avoid:
		if Vector3(p.x - q.x, 0, p.z - q.z).length() < 1.6:
			p.z += 2.0 * (1.0 if p.z >= q.z else -1.0)
	if Vector3(p.x - ball_pos.x, 0, p.z - ball_pos.z).length() < 9.5:
		p.x = maxf(p.x, ball_pos.x + 9.5)
	return p

## role: espera del jugador. Los defensores usan «defend» (marca; solo existe en la biblioteca MIXAMO, sin clips de ese
## rol queda la espera de siempre). Los clips de marca se desplazan (5-6 m de raiz): se reproducen con su raiz, enmarcados
## para TERMINAR en el puesto mirando a la pelota (el defensor llega marcando, sin patinar), y despues queda en reposo.
func _place(a: SpActor, p: Vector3, look: Vector3, role: StringName = &"idle_ready") -> void:
	a.stop_moving()
	a.global_position = p
	a.set_facing(look - p)
	var pool: Array[StringName] = SpClips.by_role(&"idle_ready", false)
	if role == &"defend":
		var marks: Array[StringName] = SpClips.by_role(&"defend", false)
		if not marks.is_empty():
			if not pool.is_empty():
				a.rest_loop = pool[rng.randi() % pool.size()]
			var id: StringName = marks[rng.randi() % marks.size()]
			var fr: Array = SpActor.frame_for(id, SpClips.length(id), p, look - p)
			a.play_clip(id, fr[0], fr[1], 0.2)
			a.visible = true
			return
	if not pool.is_empty():
		a.play_loop(pool[rng.randi() % pool.size()], 0.2, rng.randf_range(0.85, 1.1))
	a.visible = true

## Marchas direccionales (bucles con raiz hacia atras, en diagonal o de costado). Las usan los defensores con MIXAMO.
const DIR_ROLES: Array[StringName] = [&"dir_back", &"dir_back_diag", &"dir_fwd_diag", &"dir_side"]

static func _is_dir(id: StringName) -> bool:
	return DIR_ROLES.has(StringName(String(SpClips.meta(id).get("role", ""))))

## Bucle para desplazarse en `move` mirando hacia `face`: el bucle direccional cuya raiz (adelante, derecha) va mas
## parecida al movimiento relativo a la mirada (a menos de 45 grados); hacia adelante, o sin ninguno, el trote de siempre.
static func dir_loop(move: Vector3, face: Vector3, speed: float) -> StringName:
	var f := Vector3(face.x, 0.0, face.z).normalized()
	var m := Vector3(move.x, 0.0, move.z).normalized()
	if f.length_squared() < 0.5 or m.length_squared() < 0.5 or f.dot(m) > 0.75:
		return SpShooter._loop_for(speed)
	var want := Vector2(m.dot(f), m.dot(SpClips.right_of(f)))
	var best: StringName = &""
	var best_c: float = cos(deg_to_rad(45.0))
	for role in DIR_ROLES:
		for id in SpClips.by_role(role, false):
			var cm: Dictionary = SpClips.meta(id)
			# Direccion de la marcha: la de su raiz (Mixamo) o, en los bucles sin raiz, la del pie apoyado (natural_dir).
			var rt: Vector2 = cm.get("root_total", Vector2.ZERO)
			var dir: Vector2 = rt.normalized() if rt.length() > 0.3 else (cm.get("natural_dir", Vector2.ZERO) as Vector2)
			if dir.length() < 0.5 or float(cm.get("natural_speed_json", 0.0)) <= 0.2:
				continue
			var c: float = dir.normalized().dot(want)
			if c > best_c:
				best_c = c
				best = id
	return best if best != &"" else SpShooter._loop_for(speed)

## Al golpe: los compañeros van al rebote, los defensores los siguen; si un defensor llega a cabecear la pelota, se prepara.
func on_kick(traj: PackedVector3Array, step: float) -> void:
	var jog: StringName = SpShooter._loop_for(4.0)
	for i in attackers.size():
		var a: SpActor = attackers[i]
		var tgt := Vector3(goal_x - rng.randf_range(4.0, 7.0), 0.0, clampf(a.global_position.z * 0.6, -6.0, 6.0))
		a.move_to(tgt, rng.randf_range(3.5, 4.8), jog)
		if i < defenders.size():
			var d: SpActor = defenders[i]
			var dt: Vector3 = tgt + Vector3(0.8, 0.0, 0.4)
			var spd: float = rng.randf_range(3.3, 4.6)
			if AnimBank.is_mixamo():
				# MIXAMO: el defensor retrocede mirando la pelota con las marchas direccionales de Mixamo (hacia atras, en
				# diagonal o de costado segun hacia donde va). ACTUAL queda como estaba (trota de frente al destino).
				var look: Vector3 = ball.global_position - d.global_position
				var loop: StringName = dir_loop(dt - d.global_position, look, spd)
				d.move_to(dt, spd, loop, look if loop != jog and _is_dir(loop) else Vector3.ZERO)
			else:
				d.move_to(dt, spd, jog)
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

## Reaccion al resultado. skip: el que fue a despejar la pelota suelta (sigue jugando).
func react(goal: bool, skip: SpActor = null) -> void:
	for a in attackers:
		var id: StringName = SpReactions.pick(SpReactions.GOAL_TEAM if goal else SpReactions.SAD, rng, 1.5, 1.0)
		if id != &"":
			a.stop_moving()
			a.play_here(id, 0.3)
	for a in defenders:
		if a == skip:
			continue
		var id2: StringName = SpReactions.pick(SpReactions.SAD if goal else SpReactions.HAPPY_DEFENDER, rng, 1.5, 1.0)
		if id2 != &"":
			a.stop_moving()
			a.play_here(id2, 0.3)

func cleared() -> bool:
	return _cleared
