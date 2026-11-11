class_name FieldGoal
extends Minigame
## «Field Goal» (DESAFIOS DE ARCO). Palos en Y del futbol americano: travesaño a 3,05 m y verticales separados 5,64 m,
## todos cuerpos estaticos redondos (la pelota puede pegar en el palo y rebotar adentro o afuera). Vale si el centro de
## la pelota cruza el plano de los palos por encima del travesaño y entre los verticales (por debajo del alto de los
## verticales, o por arriba si va derecha). Una serie de patadas desde distintas distancias y angulos ("kicks":
## [[distancia, desplazamiento lateral], ...]); cada una vale 3 puntos y las largas (>= 40 m) 5. Viento opcional ("wind":
## m/s^2 lateral mientras la pelota vuela).

const SCENE := "res://scenes/minigames/field_goal.tscn"
const CROSSBAR := 3.05
const WIDTH := 5.64
const UPRIGHT_H := 9.0
const POST_R := 0.06

var post_x: float = 30.0
var kicks: Array = []
var wind: float = 0.0
var made: int = 0
var made_long: int = 0
var good_now: bool = false
## Patada en curso (indice en kicks): fija durante todo el turno.
var kick_i: int = 0
var _crossed: bool = false
var _prev_p := Vector3.ZERO

func uses_night_arena() -> bool:
	return true

## Arma su propia plataforma (o la pelota cambia de lugar): sin la plataforma comun.
func has_player_deck() -> bool:
	return false

func game_id() -> String:
	return "field_goal"

func _build_level() -> void:
	sides = 1
	kicks = def.get("kicks", [[20, 0], [25, -4], [30, 4], [35, 0], [40, -3]])
	max_turns = kicks.size()
	wind = float(def.get("wind", 0.0))
	post_x = 0.0
	var ground := static_box(Vector3(200, 1, 80), Vector3(0, -0.5, 0), Color(0.2, 0.5, 0.2), Vector3.ZERO, 0.45)
	for c in ground.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	ArcadeLook.light(self, Color(1.0, 0.92, 0.8), 1.05, Color(0.15, 0.3, 0.7), Color(0.75, 0.75, 0.85), 0.8, Vector3(-40, 150, 0))
	ArcadeLook.grass(self, Vector2(220, 120), Vector3(0, 0, 0), 22)
	_build_posts()
	_build_stage()

func _post(size_r: float, h: float, pos: Vector3, rot := Vector3.ZERO) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = Ball.LAYER_WORLD
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.5
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = size_r
	cy.height = h
	cs.shape = cy
	b.add_child(cs)
	ArcadeLook.part(b, "cyl", Vector3(size_r, h, size_r), Vector3.ZERO, ArcadeLook.mat(Color(1.0, 0.85, 0.1), "paint"))
	add_child(b)
	b.global_position = pos
	b.rotation = rot

## Los palos en x = post_x (la pelota se ubica en cada patada a la distancia del nivel).
func _build_posts() -> void:
	_post(0.12, CROSSBAR - 0.4, Vector3(post_x + 1.0, (CROSSBAR - 0.4) * 0.5, 0))
	_post(0.08, 1.05, Vector3(post_x + 0.5, CROSSBAR - 0.4, 0), Vector3(0, 0, PI * 0.5))
	_post(POST_R, WIDTH + 0.12, Vector3(post_x, CROSSBAR, 0), Vector3(PI * 0.5, 0, 0))
	for z in [-WIDTH * 0.5, WIDTH * 0.5]:
		_post(POST_R, UPRIGHT_H - CROSSBAR, Vector3(post_x, CROSSBAR + (UPRIGHT_H - CROSSBAR) * 0.5, z))
		ArcadeLook.deco(self, "box", Vector3(0.02, 1.0, 0.15), Vector3(post_x, UPRIGHT_H + 0.5, z), ArcadeLook.mat(Color(0.9, 0.2, 0.15), "paint"))

func _build_stage() -> void:
	# Lineas de yardas (cada 5 m) hacia el pateador, zona de anotacion y tribunas.
	var white := ArcadeLook.mat(Color(0.97, 0.97, 0.97), "paint")
	for k in 13:
		ArcadeLook.deco(self, "box", Vector3(0.12, 0.004, 40.0), Vector3(post_x - float(k) * 5.0, 0.006, 0), white)
		if k > 0 and k % 2 == 0:
			var l := Label3D.new()
			l.text = str(k * 5)
			l.font_size = 96
			l.pixel_size = 0.012
			l.rotation_degrees = Vector3(-90, -90, 0)
			add_child(l)
			l.global_position = Vector3(post_x - float(k) * 5.0 - 0.8, 0.01, -12.0)
	ArcadeLook.deco(self, "box", Vector3(10.0, 0.005, 40.0), Vector3(post_x + 5.0, 0.004, 0), ArcadeLook.mat(Color(0.12, 0.25, 0.6), "paint"))
	# Tribunas y publico: los del estadio de noche comun (ArcadeLook.night_arena).
	ArcadeLook.billboard(self, "FIELD GOAL", Vector3(post_x + 12.0, 6.0, 0), 8.0, 1.4, Color(0.1, 0.1, 0.3), Color(1.0, 0.85, 0.2))

func _kick() -> Array:
	return kicks[clampi(kick_i, 0, kicks.size() - 1)] if not kicks.is_empty() else [25, 0]

## Cada patada desde su lugar: el pateador se ubica de nuevo.
func _start_turn() -> void:
	kick_i = int(shots[0])
	for s in shooters.size():
		_place_shooter(s)
	super._start_turn()
	_refresh_score()

func _ball_spot(_s: int) -> Vector3:
	var k: Array = _kick()
	return Vector3(post_x - float(k[0]), ball.radius if ball != null else 0.11, float(k[1]))

func _aim_point(_s: int) -> Vector3:
	return Vector3(post_x, CROSSBAR + 2.0, 0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(post_x, Vector2(16.0, 34.0), false, WIDTH * 0.5, 6.0, ball.radius)

## Camara recomendada: un poco mas baja y mirando hacia arriba (los palos miden 9 m).
func camera_defaults() -> Dictionary:
	return {"back": 9.0, "height": 4.2, "ahead": 7.0, "lift_aim": 0.45, "fov": 50.0, "follow": 0.45}

func frame_points() -> Array:
	return [Vector3(post_x, UPRIGHT_H, WIDTH * 0.5), Vector3(post_x, UPRIGHT_H, -WIDTH * 0.5)]

func _level_step(delta: float) -> void:
	var p: Vector3 = ball.global_position
	if state == State.FLIGHT:
		if wind != 0.0 and not ball.is_grounded():
			# Viento: aceleracion lateral sobre la pelota en el aire (impulso por paso).
			ball.apply_central_impulse(Vector3(0, 0, wind * ball.mass * delta))
		if not _crossed and _prev_p.x < post_x and p.x >= post_x:
			var t: float = (post_x - _prev_p.x) / maxf(p.x - _prev_p.x, 0.0001)
			var q: Vector3 = _prev_p.lerp(p, t)
			_crossed = true
			good_now = q.y > CROSSBAR and absf(q.z) < WIDTH * 0.5 - POST_R
	_prev_p = p

func _on_contact(entry: Dictionary) -> void:
	super._on_contact(entry)
	_crossed = false
	good_now = false
	_prev_p = ball.global_position

func _flight_check(_delta: float) -> String:
	if _crossed and _t > 0.3:
		return "adentro" if good_now else "afuera"
	if _t > 0.8 and (ball.linear_velocity.length() < SLOW_SPEED or ball.linear_velocity.x < 0.0):
		return "afuera"
	return ""

func _on_resolved(s: int, r: String) -> void:
	if r == "adentro":
		made += 1
		var dist: float = float(_kick()[0])
		points[0] += 5 if dist >= 40.0 else 3
		if dist >= 40.0:
			made_long += 1
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if r == "adentro" else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)
	_refresh_score()

func _check_winner() -> int:
	return Side.USER if int(shots[0]) >= kicks.size() else -1

func final_score() -> int:
	return int(points[0]) * 10

func reset_level() -> void:
	made = 0
	made_long = 0
	kick_i = 0
	super.reset_level()

func _result_text(r: String) -> Array:
	var d: float = float(_kick()[0])
	if r == "adentro":
		return ["¡ADENTRO!", Color(0.35, 1.0, 0.45), "Desde %d m · +%d" % [int(d), 5 if d >= 40.0 else 3]]
	return ["Afuera", Color(1.0, 0.5, 0.4), "Tiene que pasar por arriba del travesaño y entre los palos"]

func _refresh_score() -> void:
	var n: int = kick_i + 1
	hud.set_score_text("Puntos %d · patada %d de %d (%d m)%s" % [int(points[0]), n, kicks.size(), int(float(_kick()[0])), (" · viento %+.1f" % wind) if wind != 0.0 else ""])
