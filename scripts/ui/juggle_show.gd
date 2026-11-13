class_name JuggleShow
extends Node
## Dominadas continuas en la personalizacion (pedido del usuario: «el jugador debe estar haciendo dominadas con el balon
## continuamente… el balon sincronizado con los movimientos… no reiniciar la animacion cada vez que se cambia una
## prenda»). El banco de animaciones no tiene clips de dominadas, asi que se arman asi:
##  - el cuerpo hace su bucle de espera (idle) y la pierna que toca sube a buscar la pelota con IK de dos huesos
##    (TouchFootIK.set_target, sobre la animacion): la punta del pie llega abajo de la pelota en el instante del contacto;
##  - la pelota es la pelota fisica del juego (Ball, con el diseño del usuario): cae con la gravedad y en el contacto
##    recibe un impulso (Ball.kick) que la sube y la manda al punto del proximo toque (se alterna de pie). Nunca se la
##    mueve fijando su posicion; si algo la saca de lugar (un toque perdido), se la vuelve a servir desde arriba.
## Cambiar la ropa o los botines solo cambia materiales (SpActor.set_kit): las dominadas siguen sin cortarse.

## Altura (m) del centro de la pelota en el toque, adelante del cuerpo, y separacion de cada pie.
const CONTACT_H := 0.36
const AHEAD := 0.3
const SIDE := 0.1
## Tiempo de vuelo entre toques (s) y anticipacion con la que sube el pie (s).
const FLIGHT := 0.86
const RAISE_T := 0.3
const LOWER_T := 0.22

var actor: SpActor
var ball: Ball
var ik: TouchFootIK
var foot: int = 1
var touches: int = 0
var serves: int = 0
var _since_touch: float = 10.0
var _last_foot: int = 1
var _pattern: Array[int] = [1, 1, 0, 1, 0, 0]

## Prepara las dominadas con el actor (ya construido) y crea la pelota fisica en el padre del actor.
func setup(a: SpActor, design: String = "") -> void:
	actor = a
	ik = null
	for c in actor.skeleton.get_children():
		if c is TouchFootIK:
			ik = c
	if ik == null:
		ik = TouchFootIK.new()
		ik.name = "JuggleIK"
		actor.skeleton.add_child(ik)
	ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	ball.name = "JuggleBall"
	actor.get_parent().add_child(ball)
	if design != "":
		ball.set_skin(design)
	_serve()

func stop() -> void:
	if is_instance_valid(ball):
		ball.queue_free()
	if is_instance_valid(ik) and ik.name == "JuggleIK":
		ik.queue_free()
	ball = null

## Punto del toque (centro de la pelota) para el pie f.
func contact_point(f: int) -> Vector3:
	var fwd: Vector3 = actor.facing()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var s: float = SIDE if f == 1 else -SIDE
	return actor.global_position + fwd * AHEAD + right * s + Vector3.UP * CONTACT_H

## Saca la pelota desde arriba del pie que toca (al empezar o si se perdio).
func _serve() -> void:
	serves += 1
	foot = _pattern[touches % _pattern.size()]
	ball.reset_at(contact_point(foot) + Vector3.UP * 0.9)
	# El traslado se aplica en el paso de fisica siguiente: hasta entonces no se juzga donde esta.
	_since_touch = 0.0

## Segundos hasta que la pelota baje a la altura del toque (sin contar el aire: alcanza para anticipar el pie).
func time_to_contact() -> float:
	var y: float = ball.global_position.y - CONTACT_H
	var vy: float = ball.linear_velocity.y
	var g: float = 9.81
	var disc: float = vy * vy + 2.0 * g * y
	if disc < 0.0:
		return 0.0
	return maxf((vy + sqrt(disc)) / g, 0.0)

func _physics_process(delta: float) -> void:
	if actor == null or not is_instance_valid(ball):
		return
	_since_touch += delta
	var p: Vector3 = ball.global_position
	var target: Vector3 = contact_point(foot)
	# Pelota perdida (lejos del pie o en el piso): se vuelve a servir.
	if _since_touch > 0.25 and (Vector2(p.x - target.x, p.z - target.z).length() > 0.7 or (p.y < 0.2 and _since_touch > 0.5)):
		_serve()
		_since_touch = 0.0
		return
	var t: float = time_to_contact()
	var w: float = 0.0
	if ball.linear_velocity.y < 0.0 and t < RAISE_T:
		# Sube el pie: la punta va a quedar abajo de la pelota en el instante del toque.
		w = smoothstep(0.0, 1.0, 1.0 - t / RAISE_T)
	if _since_touch < LOWER_T:
		w = maxf(w, 1.0 - _since_touch / LOWER_T)
	var at: Vector3 = Vector3(p.x, CONTACT_H, p.z) if ball.linear_velocity.y < 0.0 else contact_point(_last_foot)
	var lead: int = foot if ball.linear_velocity.y < 0.0 else _last_foot
	ik.set_target(lead, at + Vector3(0.0, -ball.radius - 0.035, 0.0) + actor.facing() * 0.02, 0.12, w)
	if ball.linear_velocity.y < 0.0 and p.y <= CONTACT_H:
		_touch()

## Toque: impulso hacia arriba que lleva la pelota al punto del proximo toque en FLIGHT segundos.
func _touch() -> void:
	touches += 1
	_last_foot = foot
	foot = _pattern[touches % _pattern.size()]
	var next: Vector3 = contact_point(foot)
	var p: Vector3 = ball.global_position
	var vy: float = 9.81 * FLIGHT * 0.5 * 1.02
	var vxz := Vector3(next.x - p.x, 0.0, next.z - p.z) / FLIGHT
	ball.kick(vxz + Vector3.UP * vy, actor.facing().cross(Vector3.UP).normalized() * -3.0, actor)
	_since_touch = 0.0
	if not Engine.is_editor_hint() and is_inside_tree():
		Sfx.play(&"touch", 0.35)
