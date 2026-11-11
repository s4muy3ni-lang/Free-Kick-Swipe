class_name SaltoAlto
extends Minigame
## «Salto en alto» (HABILIDAD). Dos parantes con una varilla apoyada en tacos: la varilla es un CUERPO RIGIDO suelto que
## descansa sobre los tacos; si la pelota la toca con fuerza, se cae de verdad (o queda movida fuera de los tacos) y el
## salto es nulo. Vale si el centro de la pelota cruza el plano de los parantes por encima de la varilla, entre los
## parantes, y la varilla sigue en su lugar cuando todo se asienta. Como en el atletismo: tres intentos por altura;
## pasarla sube la varilla ("step"); tres nulos seguidos terminan la serie. Record = mejor altura pasada.

const SCENE := "res://scenes/minigames/salto_alto.tscn"
const BAR_R := 0.03
const PEG := 0.06
## Altura maxima de la varilla (los parantes miden 3,4 m): pasarla termina la serie con el maximo.
const MAX_H := 3.2

var bar_x: float = 9.0
var span: float = 4.0
var height: float = 1.2
var step: float = 0.2
var tries_left: int = 3
var best: float = 0.0
var cleared_now: bool = false
var bar: RigidBody3D
var _crossed: bool = false
var _prev_p := Vector3.ZERO
var _bar_home: Transform3D

func game_id() -> String:
	return "salto_alto"

func _build_level() -> void:
	sides = 1
	max_turns = int(def.get("max_shots", 40))
	bar_x = float(def.get("distance", 9.0))
	span = float(def.get("span", 4.0))
	height = float(def.get("start", 1.2))
	step = float(def.get("step", 0.2))
	var ground := static_box(Vector3(80, 1, 40), Vector3(bar_x * 0.5, -0.5, 0), Color(0.2, 0.5, 0.2), Vector3.ZERO, 0.45)
	for c in ground.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	ArcadeLook.light(self, Color(1.0, 0.95, 0.85), 1.1, Color(0.2, 0.42, 0.85), Color(0.75, 0.82, 0.92), 0.8)
	ArcadeLook.grass(self, Vector2(160, 120), Vector3(bar_x * 0.5, 0, 0), 22)
	# Pista de atletismo roja con andariveles y la colchoneta azul detras de los parantes.
	ArcadeLook.ground(self, Vector2(bar_x + 4.0, 7.0), Vector3(bar_x * 0.5 - 1.0, 0.002, 0), Color(0.72, 0.22, 0.16), "stone", 10.0)
	for k in 5:
		ArcadeLook.deco(self, "box", Vector3(bar_x + 4.0, 0.004, 0.05), Vector3(bar_x * 0.5 - 1.0, 0.006, -3.5 + float(k) * 1.75), ArcadeLook.mat(Color(0.97, 0.97, 0.97), "paint"))
	ArcadeLook.deco(self, "box", Vector3(3.0, 0.6, span + 1.0), Vector3(bar_x + 1.9, 0.3, 0), ArcadeLook.mat(Color(0.15, 0.35, 0.85), "rubber"))
	var mat_b := static_box(Vector3(3.0, 0.6, span + 1.0), Vector3(bar_x + 1.9, 0.3, 0), Color(0.15, 0.35, 0.85), Vector3.ZERO, 0.05)
	for c in mat_b.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	# Parantes (estaticos) con escala y tacos: la varilla apoya sobre los tacos (cajas chicas fisicas).
	for z in [-span * 0.5 - 0.06, span * 0.5 + 0.06]:
		var up := static_box(Vector3(0.08, 3.4, 0.08), Vector3(bar_x, 1.7, z), Color(0.9, 0.9, 0.92), Vector3.ZERO, 0.3)
		for c in up.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.88, 0.89, 0.92), "metal")
		for k in 17:
			ArcadeLook.deco(self, "box", Vector3(0.09, 0.012, 0.09), Vector3(bar_x - 0.001, 0.4 + float(k) * 0.2, z), ArcadeLook.mat(Color(0.1, 0.1, 0.1), "paint"))
	ArcadeLook.billboard(self, "SALTO EN ALTO", Vector3(bar_x + 6.0, 3.6, 0), 6.5, 1.0)
	_build_bar()
	_place_bar()

func _build_bar() -> void:
	bar = RigidBody3D.new()
	bar.mass = 0.4
	bar.collision_layer = Ball.LAYER_WORLD
	bar.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.1
	bar.physics_material_override = pm
	bar.linear_damp = 0.5
	bar.angular_damp = 2.0
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = BAR_R
	cy.height = span + 0.08
	cs.shape = cy
	cs.rotation_degrees = Vector3(90, 0, 0)
	bar.add_child(cs)
	# Franjas blancas y rojas (se ve de lejos).
	for k in 8:
		ArcadeLook.part(bar, "cyl", Vector3(BAR_R, (span + 0.08) / 8.0, BAR_R), Vector3(0, 0, -(span + 0.08) * 0.5 + (float(k) + 0.5) * (span + 0.08) / 8.0),
			ArcadeLook.mat(Color(0.95, 0.95, 0.95) if k % 2 == 0 else Color(0.9, 0.15, 0.12), "plastic"), Vector3(PI * 0.5, 0, 0))
	add_child(bar)

var _pegs: Array = []

## Tacos a la altura actual y la varilla apoyada encima (entre tiros, como los jueces).
func _place_bar() -> void:
	for p in _pegs:
		(p as Node).queue_free()
	_pegs.clear()
	for z in [-span * 0.5 + 0.02, span * 0.5 - 0.02]:
		var peg := static_box(Vector3(PEG, 0.03, PEG), Vector3(bar_x + 0.0, height - BAR_R - 0.015, z), Color(0.2, 0.2, 0.2), Vector3.ZERO, 0.1)
		_pegs.append(peg)
	_bar_home = Transform3D(Basis(), Vector3(bar_x, height + 0.001, 0))
	bar.global_transform = _bar_home
	bar.linear_velocity = Vector3.ZERO
	bar.angular_velocity = Vector3.ZERO

## La varilla sigue en su lugar (no se cayo ni quedo movida).
func bar_in_place() -> bool:
	return bar.global_position.distance_to(_bar_home.origin) < 0.06

func _level_step(_delta: float) -> void:
	var p: Vector3 = ball.global_position
	if state == State.FLIGHT and not _crossed and _prev_p.x < bar_x and p.x >= bar_x:
		var t: float = (bar_x - _prev_p.x) / maxf(p.x - _prev_p.x, 0.0001)
		var q: Vector3 = _prev_p.lerp(p, t)
		_crossed = true
		cleared_now = q.y - ball.radius > height and absf(q.z) < span * 0.5
	_prev_p = p

func _on_contact(entry: Dictionary) -> void:
	super._on_contact(entry)
	_crossed = false
	cleared_now = false
	_prev_p = ball.global_position

func _settling() -> bool:
	# (Una varilla caida que sigue rodando sobre la colchoneta no traba el turno: a los 3 s se decide.)
	return _t < 3.0 and (bar.linear_velocity.length() > 0.05 or bar.angular_velocity.length() > 0.1)

func _flight_check(_delta: float) -> String:
	if _t > 0.6 and not _settling() and (ball.linear_velocity.length() < SLOW_SPEED or ball.global_position.x > bar_x + 4.0 or ball.global_position.x < -2.0 or absf(ball.global_position.z) > 10.0):
		return "valido" if _crossed and cleared_now and bar_in_place() else "nulo"
	if _crossed and _t > 0.4 and not _settling() and ball.global_position.x > bar_x + 0.8:
		return "valido" if cleared_now and bar_in_place() else "nulo"
	return ""

func _on_resolved(s: int, r: String) -> void:
	if r == "valido":
		best = maxf(best, height)
		height = minf(height + step, MAX_H)
		tries_left = 3
	else:
		tries_left -= 1
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if r == "valido" else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)
	_refresh_score()

func _start_turn() -> void:
	_place_bar()
	super._start_turn()

func _check_winner() -> int:
	return Side.USER if tries_left <= 0 or best >= MAX_H - 0.001 or int(shots[0]) >= max_turns else -1

func final_score() -> int:
	return int(round(best * 100.0))

func reset_level() -> void:
	height = float(def.get("start", 1.2))
	best = 0.0
	tries_left = 3
	super.reset_level()

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0, ball.radius if ball != null else 0.11, 0)

func _aim_point(_s: int) -> Vector3:
	return Vector3(bar_x, height + 0.4, 0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(bar_x, Vector2(8.0, 26.0), false, span * 0.5, 4.0, ball.radius)

func frame_points() -> Array:
	return [Vector3(bar_x, height + 0.5, span * 0.5), Vector3(bar_x, height + 0.5, -span * 0.5)]

func _result_text(r: String) -> Array:
	if r == "valido":
		return ["¡%.2f m!" % (height - step), Color(0.35, 1.0, 0.45), "La varilla sube a %.2f m" % height]
	return ["Nulo", Color(1.0, 0.5, 0.4), "Quedan %d intentos a %.2f m" % [tries_left, height]]

func _refresh_score() -> void:
	hud.set_score_text("Varilla %.2f m · intentos %d · récord %.2f m" % [height, tries_left, best])
