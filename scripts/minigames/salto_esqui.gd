class_name SaltoEsqui
extends Minigame
## «Salto de esquí» (HABILIDAD). Trampolin de nieve real: plataforma de salida arriba, pista de bajada, mesa de despegue
## y colina de caida, todo de segmentos fisicos con bandas a los costados. La pelota se patea desde arriba (el gesto da
## fuerza, direccion y efecto) y baja por gravedad; en la nieve desliza como un trineo (sin girar) y frena SNOW_DECEL
## (se le devuelve la rodadura de cesped que sobra, como el hielo del Curling: la fisica comun de la pelota no se toca).
## Sale de la mesa y vuela con el arrastre del aire. Distancia = horizontal desde el borde de despegue hasta el primer
## apoyo en la colina. Lineas de la colina: K (verde) y HS (roja). Viento opcional ("wind": m/s^2 a favor (+) o en
## contra (-) mientras vuela).

const SCENE := "res://scenes/minigames/salto_esqui.tscn"
const WIDTH := 3.0
const SNOW_DECEL := 0.12

var top_h: float = 20.0
var k_point: float = 40.0
var hs: float = 50.0
var wind: float = 0.0
var shots_max: int = 3
var takeoff := Vector2.ZERO
var landing_start := Vector2.ZERO
var distance: float = 0.0
var landed: bool = false
var _airborne: bool = false
var _air_t: float = 0.0
var jumps: Array = []
var _land_segs: Array = []

func game_id() -> String:
	return "salto_esqui"

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 3))
	max_turns = shots_max
	top_h = float(def.get("height", 20.0))
	k_point = float(def.get("k", 40.0))
	hs = float(def.get("hs", k_point + 10.0))
	wind = float(def.get("wind", 0.0))
	ArcadeLook.light(self, Color(1.0, 0.97, 0.92), 1.1, Color(0.3, 0.5, 0.85), Color(0.85, 0.9, 0.97), 0.9, Vector3(-40, -30, 0))
	_build_hill()
	_build_stage()

## Segmento de pista: caja de 1 m de espesor cuyo borde de arriba va de a, bajando ang grados, len metros. Devuelve el fin.
func _seg(a: Vector2, ang_deg: float, length: float, snow := true, rails := true) -> Vector2:
	var ang: float = deg_to_rad(ang_deg)
	var d := Vector2(cos(ang), -sin(ang))
	var b: Vector2 = a + d * length
	var mid: Vector2 = (a + b) * 0.5
	var n := Vector2(sin(ang), cos(ang))
	var c: Vector2 = mid - n * 0.5
	var box := static_box(Vector3(length + 0.04, 1.0, WIDTH), Vector3(c.x, c.y, 0), Color(0.95, 0.97, 1.0), Vector3(0, 0, -ang), 0.0)
	(box.physics_material_override as PhysicsMaterial).friction = 0.08
	for ch in box.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.95, 0.97, 1.0), "paint", 3.0) if snow else ArcadeLook.mat(Color(0.5, 0.4, 0.3), "wood")
	if rails:
		for z in [-WIDTH * 0.5 - 0.06, WIDTH * 0.5 + 0.06]:
			var rail := static_box(Vector3(length + 0.04, 0.5, 0.12), Vector3(mid.x + n.x * 0.25, mid.y + n.y * 0.25, z), Color(0.2, 0.3, 0.6), Vector3(0, 0, -ang), 0.3)
			for ch in rail.get_children():
				if ch is MeshInstance3D:
					(ch as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.15, 0.3, 0.7), "plastic")
	return b

func _build_hill() -> void:
	# Plataforma de salida (ancha: el jugador se para al costado de la pelota) con baranda de madera atras.
	var deck := static_box(Vector3(7.0, 0.5, 8.0), Vector3(-3.6, top_h - 0.262, 0), Color(0.55, 0.4, 0.26), Vector3.ZERO, 0.2)
	for ch in deck.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.58, 0.42, 0.27), "wood", 3.0)
	ArcadeLook.deco(self, "box", Vector3(0.1, 1.0, 8.0), Vector3(-7.0, top_h + 0.5, 0), ArcadeLook.mat(Color(0.45, 0.3, 0.18), "wood"))
	var p := Vector2(-6.0, top_h)
	# (Sin bandas sobre la plataforma: el jugador llega a la pelota desde el costado.)
	p = _seg(p, 0.0, 6.0, true, false)
	# Pista de bajada y transicion hacia la mesa.
	var inrun: float = top_h * 1.35
	# Arranque redondeado (de 0 a 32 grados) para que no salte al empezar a bajar.
	for k in 4:
		p = _seg(p, 8.0 * float(k + 1), 0.8)
	p = _seg(p, 32.0, inrun)
	# Transicion CURVA hacia la mesa (32 -> 9 grados en 10 tramos): un quiebre de 10 grados hacia la pelota rebotar y
	# salir volando antes de la mesa (medido).
	for k in 10:
		p = _seg(p, 32.0 - 23.0 * float(k + 1) / 10.0, 1.2)
	# Mesa de despegue (un poco hacia abajo, como los trampolines reales).
	p = _seg(p, 9.0, 4.0)
	takeoff = p
	# Colina de caida: arranca 3 m por debajo del borde y baja 33 grados; despues la curva a la zona plana.
	var l := Vector2(p.x + 1.0, p.y - 3.0)
	landing_start = l
	_land_segs.clear()
	var q: Vector2 = _seg(Vector2(l.x - 1.0, l.y + 0.6), 20.0, 1.8, true, false)
	_land_segs.append([Vector2(l.x - 1.0, l.y + 0.6), q])
	var q2: Vector2 = _seg(q, 34.0, hs * 1.25)
	_land_segs.append([q, q2])
	var q3: Vector2 = _seg(q2, 20.0, 8.0, true, false)
	var q4: Vector2 = _seg(q3, 8.0, 8.0, true, false)
	var q5: Vector2 = _seg(q4, 0.0, 40.0, true, false)
	# Base de nieve bajo todo (piso de seguridad).
	static_box(Vector3(300, 1, 120), Vector3(takeoff.x + 60.0, q5.y - 0.5 - 0.02, 0), Color(0.95, 0.97, 1.0), Vector3.ZERO, 0.1)
	# Lineas K y HS sobre la colina (a esa distancia horizontal del borde).
	for dk in [[k_point, Color(0.1, 0.8, 0.3)], [hs, Color(0.9, 0.15, 0.15)]]:
		var x: float = takeoff.x + float(dk[0])
		var y: float = hill_y(x)
		ArcadeLook.deco(self, "box", Vector3(0.25, 0.02, WIDTH), Vector3(x, y + 0.02, 0), ArcadeLook.glow(dk[1], 0.8), Vector3(0, 0, -deg_to_rad(34.0)))
		var lb := Label3D.new()
		lb.text = ("K %d" if dk[0] == k_point else "HS %d") % int(dk[0])
		lb.font_size = 96
		lb.pixel_size = 0.01
		lb.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		lb.modulate = dk[1]
		add_child(lb)
		lb.global_position = Vector3(x, y + 1.5, WIDTH * 0.5 + 1.0)

## Altura de la colina de caida en x (para medir y dibujar).
func hill_y(x: float) -> float:
	for s in _land_segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return (_land_segs.back()[1] as Vector2).y if not _land_segs.is_empty() else 0.0

func _build_stage() -> void:
	ArcadeLook.ground(self, Vector2(400, 200), Vector3(takeoff.x + 40.0, -40.0, 0), Color(0.93, 0.95, 1.0), "paint", 40.0)
	# Pinos a los costados de la colina y montañas al fondo.
	for k in 14:
		var x: float = takeoff.x + float(k) * 6.0 - 10.0
		for z in [-7.0, 7.0]:
			var y: float = hill_y(x) if x > landing_start.x else (top_h - (x + 0.0) * tan(deg_to_rad(32.0)) if x > 0.0 else top_h)
			ArcadeLook.deco(self, "cyl", Vector3(0.12, 1.0, 0.15), Vector3(x, y - 0.5 + 0.5, z + float(k % 2)), ArcadeLook.mat(Color(0.4, 0.27, 0.15), "wood"))
			ArcadeLook.deco(self, "cyl", Vector3(0.0, 2.4, 0.9), Vector3(x, y + 1.9, z + float(k % 2)), ArcadeLook.mat(Color(0.12, 0.35, 0.2), "paint"))
	for k in 5:
		ArcadeLook.deco(self, "cyl", Vector3(0.01, 40.0, 30.0), Vector3(takeoff.x + 160.0, -10.0, -80.0 + float(k) * 40.0), ArcadeLook.mat(Color(0.8, 0.85, 0.95), "stone", 2.0))
	# Torre de salida y cartel.
	ArcadeLook.deco(self, "box", Vector3(3.0, top_h - 0.5, 4.0), Vector3(-4.5, (top_h - 0.5) * 0.5, 0), ArcadeLook.mat(Color(0.55, 0.38, 0.25), "wood", 3.0))
	ArcadeLook.billboard(self, "SALTO DE ESQUÍ", Vector3(takeoff.x + 3.0, takeoff.y + 6.0, -6.0), 7.0, 1.2, Color(0.1, 0.2, 0.45), Color(1, 1, 1), -30.0)

func _ball_spot(_s: int) -> Vector3:
	return Vector3(-1.5, top_h + (ball.radius if ball != null else 0.11), 0)

func _aim_point(_s: int) -> Vector3:
	return Vector3(takeoff.x, takeoff.y, 0)

func camera_base_y() -> float:
	return top_h

func camera_defaults() -> Dictionary:
	# Mira hacia abajo, a la mesa de despegue (lift_aim con la mesa muy por debajo de la salida).
	return {"back": 6.5, "height": 4.0, "ahead": 12.0, "lift_aim": 0.45, "fov": 52.0, "follow": 0.45}

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(takeoff.x, Vector2(4.0, 20.0), false, WIDTH, 2.0, ball.radius)

func frame_points() -> Array:
	return [Vector3(takeoff.x, takeoff.y, 0)]

func _level_step(delta: float) -> void:
	if state != State.FLIGHT:
		return
	var p: Vector3 = ball.global_position
	if ball.is_grounded():
		# Nieve: frena SNOW_DECEL (se devuelve la rodadura de cesped que sobra; el giro de rodadura acompaña).
		var hv: Vector3 = ball.linear_velocity
		var spd: float = hv.length()
		if spd > 0.05 and p.x < takeoff.x + 0.5:
			var give: float = maxf(Ball.roll_decel(spd) - SNOW_DECEL, 0.0) * delta
			ball.linear_velocity += hv / spd * give
			# Desliza como un trineo (la nieve casi no la hace girar): sin el efecto de rodar, que al despegar la hundiria
			# por Magnus (medido: caia a 16 m/s2 con el giro de rodadura). Conserva el efecto vertical del gesto.
			var wy: float = ball.angular_velocity.y
			ball.angular_velocity = Vector3(0, wy, 0)
		_air_t = 0.0
		if _airborne and not landed and p.x > takeoff.x:
			landed = true
			distance = p.x - takeoff.x
			_mark_landing(p)
	else:
		# En vuelo de verdad: pasado el borde y sin apoyo al menos 0,15 s (no el instante en que deja la mesa).
		if p.x > takeoff.x:
			_air_t += delta
			if _air_t >= 0.15:
				_airborne = true
		if _airborne and wind != 0.0:
			ball.apply_central_impulse(Vector3(wind * ball.mass * delta, 0, 0))

func _mark_landing(p: Vector3) -> void:
	ArcadeLook.deco(self, "box", Vector3(0.12, 0.03, WIDTH * 0.6), Vector3(p.x, p.y - ball.radius + 0.02, 0), ArcadeLook.glow(Color(1.0, 0.85, 0.2), 1.0), Vector3(0, 0, -deg_to_rad(34.0)))

func _on_contact(entry: Dictionary) -> void:
	super._on_contact(entry)
	landed = false
	_airborne = false
	_air_t = 0.0
	distance = 0.0

func _flight_check(_delta: float) -> String:
	if landed and _t > 0.3:
		return "salto"
	var p: Vector3 = ball.global_position
	if _t > 1.0 and ball.linear_velocity.length() < SLOW_SPEED and not _airborne:
		return "frenada"
	if absf(p.z) > 30.0 or p.y < -60.0:
		return "afuera"
	return ""

func _flight_watchdog(_delta: float) -> String:
	return "frenada" if _t > 25.0 else ""

func _on_resolved(s: int, r: String) -> void:
	jumps.append(distance if r == "salto" else 0.0)
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if distance >= k_point else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)
	_refresh_score()

func best() -> float:
	var b: float = 0.0
	for d in jumps:
		b = maxf(b, float(d))
	return b

func _check_winner() -> int:
	return Side.USER if int(shots[0]) >= shots_max else -1

func final_score() -> int:
	var b: float = best()
	if b <= 0.0:
		return 0
	# Puntos de salto: 60 en el punto K, 2 por metro de mas o de menos.
	return maxi(int(round(60.0 + (b - k_point) * 2.0)), 1)

func reset_level() -> void:
	jumps.clear()
	super.reset_level()

func _result_text(r: String) -> Array:
	if r != "salto":
		return ["Sin salto", Color(1.0, 0.6, 0.4), "La pelota no llegó a la mesa: más fuerza y derecha"]
	var c: Color = Color(0.35, 1.0, 0.45) if distance >= k_point else Color(1.0, 0.85, 0.35)
	return ["%.1f m" % distance, c, "K %d · HS %d%s" % [int(k_point), int(hs), (" · viento %+.1f" % wind) if wind != 0.0 else ""]]

func _refresh_score() -> void:
	hud.set_score_text("Mejor %.1f m · salto %d / %d" % [best(), mini(int(shots[0]) + 1, shots_max), shots_max])
