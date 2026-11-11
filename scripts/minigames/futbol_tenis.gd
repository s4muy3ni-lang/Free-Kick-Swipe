class_name FutbolTenis
extends RallyBase
## Futbol-tenis (etapa B2): dos campos separados por una RED fisica (la pelota puede pegarle y caerse). La pelota tiene
## que cruzar al campo rival; reglas de rebote: un pique permitido en cada campo (al segundo, punto rival), pique en el
## propio campo despues de tocarla = no cruzo (punto rival), afuera = punto para el otro. Hasta dos toques por lado
## (control + golpe); el tercero es falta. Mientras la pelota viaja se muestra DONDE VA A PICAR (prediccion fisica que se
## actualiza en vuelo; no cambia la fisica). Saque desde el piso con el gesto de siempre. 1 contra 1 contra la IA; las
## reglas (toques y piques por LADO) ya sirven para mas jugadores por equipo.

const SCENE := "res://scenes/minigames/futbol_tenis.tscn"

var half: float = 5.5
var width: float = 3.2
var net_h: float = 0.95
var bounces: Array = [0, 0]
var net: StaticBody3D

func game_id() -> String:
	return "futbol_tenis"

func _build_level() -> void:
	sides = 2
	max_turns = 99
	half = float(def.get("half", 5.5))
	width = float(def.get("width", 3.2))
	net_h = float(def.get("net_h", 0.95))
	# Cancha: dos campos pintados y la red fisica en el medio.
	for s in 2:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(half, width * 2.0)
		mi.mesh = pm
		mi.material_override = Minigame.color_mat(Color(0.16, 0.45, 0.6) if s == 0 else Color(0.6, 0.3, 0.16))
		add_child(mi)
		mi.global_position = Vector3((-half * 0.5) if s == 0 else (half * 0.5), 0.015, 0)
	static_box(Vector3(60, 1, 34), Vector3(0, -0.5, 0), Color(0.2, 0.42, 0.3), Vector3.ZERO, 0.5)
	net = static_box(Vector3(0.08, net_h, width * 2.0 + 0.6), Vector3(0, net_h * 0.5, 0), Color(0.92, 0.92, 0.96), Vector3.ZERO, 0.15)
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.06, width * 2.0 + 0.6)
	band.mesh = bm
	band.material_override = Minigame.color_mat(Color(0.1, 0.1, 0.12))
	add_child(band)
	band.global_position = Vector3(0, net_h - 0.03, 0)

func home(s: int) -> Vector3:
	return Vector3(-half * 0.6 if s == Side.USER else half * 0.6, 0, 0)

func _ball_spot(s: int) -> Vector3:
	# Adelante y un poco al costado del jugador: desde la camara de atras la pelota no queda tapada por el cuerpo.
	return home(s) + Vector3(0.55 * (1 if s == Side.USER else -1), ball.radius, 0.55 * (1 if s == Side.USER else -1))

func _aim_point(s: int) -> Vector3:
	return home(1 - s) + Vector3.UP * 1.0

func _serve_spot() -> Vector3:
	return _ball_spot(serve_side)

func side_of(p: Vector3) -> int:
	return Side.USER if p.x < 0.0 else Side.CPU

func _start_serve() -> void:
	bounces = [0, 0]
	super._start_serve()

func _after_ball_sent(toucher: int, v: Vector3) -> void:
	_expect_from_flight(toucher, v)

## Calcula el pique previsto, muestra la marca en el piso y manda al receptor del lado donde cae.
func _expect_from_flight(toucher: int, v: Vector3 = Vector3.INF) -> void:
	if v == Vector3.INF:
		v = ball.linear_velocity
	var l: Array = RallyBase.landing_of(ball.global_position, v, ball.angular_velocity)
	if l.is_empty():
		return
	var landing: Vector3 = l[0]
	_marker.visible = true
	_marker.global_position = Vector3(landing.x, 0.03, landing.z)
	var receiver: int = side_of(landing)
	if receiver == toucher:
		# Va a picar en su propio lado (red o globo corto): el rival no corre; las reglas resuelven al pique.
		return
	var rp: RallyPlayer = players[receiver]
	rp.expect(landing, float(l[1]))
	if receiver == Side.CPU:
		if touches[Side.CPU] >= 1 or rng.randf() < 0.55:
			var tz: float = rng.randf_range(-width * 0.7, width * 0.7)
			var tx: float = rng.randf_range(-half * 0.85, -half * 0.25)
			var err: float = [1.4, 1.0, 0.7, 0.5, 0.35][SpSettings.level()]
			rp.order = {"target": Vector3(tx + rng.randf_range(-err, err), 0.15, tz + rng.randf_range(-err, err)),
				"speed": rng.randf_range(8.5, 11.0)}
		else:
			rp.order = {}
	else:
		rp.order = user_intent
		if touches[Side.USER] >= 1 and user_intent.is_empty():
			hud.set_hint("¡Devolvela al otro campo! (el tercer toque es falta)")

func _on_touch(kind: StringName, s: int) -> void:
	super._on_touch(kind, s)
	if kind == &"miss":
		return
	bounces[s] = 0
	if touches[s] > 2:
		give_point(1 - s, "Tres toques del mismo lado: falta")

func _on_ground(pos: Vector3) -> void:
	# Afuera: si ya habia picado valida en el campo rival, el tanto es del que pego (pelota buena sin devolver);
	# si salio directa, el tanto es del rival.
	if absf(pos.z) > width + 0.25 or absf(pos.x) > half + 0.3:
		if bounces[1 - last_toucher] > 0:
			give_point(last_toucher, "Picó adentro y se fue")
		else:
			give_point(1 - last_toucher, "Afuera")
		return
	var s: int = side_of(pos)
	if last_toucher == s:
		# Pico en el campo del que la toco: no cruzo (incluye la que toca la red y vuelve).
		give_point(1 - s, "No cruzó la red")
		return
	bounces[s] += 1
	if bounces[s] >= 2:
		give_point(1 - s, "Dos piques en el mismo campo")
		return
	# Un pique vale: el receptor todavia puede jugarla (se recalcula la caida del segundo arco).
	call_deferred("_expect_from_flight", last_toucher)

func _rally_step(_delta: float) -> void:
	if rally_age > 0.5 and ball.is_grounded() and ball.linear_velocity.length() < 0.8:
		# Se quedo rodando: la pierde el lado donde quedo.
		var s: int = side_of(ball.global_position)
		give_point(1 - s, "La pelota murió en ese campo")

func _cpu_serve() -> Vector3:
	return pass_velocity(Vector3(-half * 0.55, 0, rng.randf_range(-width * 0.5, width * 0.5)), 0.42, 0.7)
