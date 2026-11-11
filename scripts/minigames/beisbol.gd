class_name Beisbol
extends Minigame
## «Béisbol» con bate mecanico (HABILIDAD). El jugador patea la pelota desde el monticulo hacia el home; ahi una maquina
## bateadora tiene un bate que es una barra rigida con masa e inercia (m L^2 / 3) que gira sobre su pivote. El choque
## bate-pelota se resuelve con el impulso newtoniano (restitucion, masa de la pelota e inercia del bate en el punto de
## contacto) buscando el primer contacto en 16 subpasos de cada paso: a 24 rad/s el bate barre 23 grados por paso y el
## motor de fisica (deteccion continua solo lineal) dejaba pasar la pelota (medido). Un sensor ve pasar la pelota a SENSOR_D m del home, mide su
## velocidad y suelta el bate con el retraso justo para que llegue de frente al plato; el choque bate-pelota lo resuelve
## la fisica (impulso real: la velocidad de salida depende de donde pega en el bate, de la altura y de la velocidad de la
## pelota). La decision del jugador: altura (pelota un poco por encima del eje del bate = elevacion), lugar sobre el
## bate (el punto dulce) y fuerza. Si la pelota no pasa por la zona, el bate no la toca: «strike».
## Se mide la distancia del primer pique (o hasta la cerca); pasa la cerca por arriba en zona fair = JONRON.
## Reglas ("rule"): "distancia" (suma de metros), "jonrones" (cuantos), "duelo" (contra la IA, mas jonrones; desempata la
## distancia).

const SCENE := "res://scenes/minigames/beisbol.tscn"
const PLATE_X := 16.0
## Pivote del bate (mundo): a la derecha del home (+Z), a la altura de la cintura de la maquina.
const PIVOT := Vector3(PLATE_X + 0.15, 0.95, 1.05)
const BAT_L := 1.05
const BAT_R := 0.065
const BAT_MASS := 2.5
## Velocidad de giro del bate (rad/s) y angulo inicial (apunta hacia atras, +X) -> golpea apuntando a -Z (90 grados).
const BAT_W := 30.0
const SENSOR_D := 3.5
const FAIR_DEG := 45.0
const CPU_ERROR := [1.4, 1.0, 0.75, 0.55, 0.4]

var fence_r: float = 42.0
var fence_h: float = 2.6
var rule: String = "distancia"
var shots_each: int = 5
var bat: Node3D
var swing: String = "ready"
var _fire_in: float = -1.0
var hit: bool = false
var landed: bool = false
var homer: bool = false
var distance: float = 0.0
var exit_speed: float = 0.0
var results: Array = [[], []]
var cpu_error_deg: float = -1.0
var _airborne: bool = false

func game_id() -> String:
	return "beisbol"

func _build_level() -> void:
	rule = String(def.get("rule", "distancia"))
	sides = 2 if rule == "duelo" else 1
	shots_each = int(def.get("shots", 5))
	max_turns = shots_each * sides
	fence_r = float(def.get("fence", 42.0))
	var ground := static_box(Vector3(200, 1, 200), Vector3(0, -0.5, 0), Color(0.2, 0.5, 0.2), Vector3.ZERO, 0.45)
	for c in ground.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	_build_field()
	_build_bat()

func _build_field() -> void:
	ArcadeLook.light(self, Color(1.0, 0.95, 0.85), 1.1, Color(0.2, 0.4, 0.8), Color(0.75, 0.8, 0.9), 0.8, Vector3(-55, 150, 0))
	var plate := Vector3(PLATE_X, 0, 0)
	ArcadeLook.grass(self, Vector2(220, 220), Vector3(PLATE_X - 40.0, 0, 0), 30)
	# Diamante de tierra (rombo) con las bases y lineas de foul.
	var dirt := ArcadeLook.mat(Color(0.62, 0.42, 0.26), "stone", 6.0)
	# Caminos de tierra entre las bases (el pasto queda adentro), circulo del home y monticulo plano (decoracion sin
	# colision: nada visual se levanta del piso por donde rueda la pelota).
	var corners: Array = [Vector3.ZERO, Vector3(-14.14, 0, 14.14), Vector3(-28.28, 0, 0), Vector3(-14.14, 0, -14.14)]
	for k in 4:
		var a: Vector3 = plate + corners[k]
		var b: Vector3 = plate + corners[(k + 1) % 4]
		var mid: Vector3 = (a + b) * 0.5
		var yaw: float = atan2(-(b - a).z, (b - a).x)
		ArcadeLook.deco(self, "box", Vector3(20.0 + 1.6, 0.01, 1.6), mid + Vector3(0, 0.004, 0), dirt, Vector3(0, yaw, 0))
	ArcadeLook.deco(self, "cyl", Vector3(2.8, 0.012, 2.8), Vector3(0, 0.005, 0), dirt)
	ArcadeLook.deco(self, "cyl", Vector3(3.2, 0.012, 3.2), plate + Vector3(0, 0.005, 0), dirt)
	var white := ArcadeLook.mat(Color(0.97, 0.97, 0.97), "paint")
	for b in [Vector3(-19.4, 0, 19.4) * 0.73, Vector3(-27.4, 0, 0), Vector3(-19.4, 0, -19.4) * 0.73]:
		ArcadeLook.deco(self, "box", Vector3(0.38, 0.08, 0.38), plate + b + Vector3(0, 0.04, 0), white, Vector3(0, PI * 0.25, 0))
	ArcadeLook.deco(self, "box", Vector3(0.45, 0.03, 0.45), plate + Vector3(0, 0.015, 0), white, Vector3(0, PI * 0.25, 0))
	for sgn in [-1.0, 1.0]:
		var dir := Vector3(-1, 0, sgn).normalized()
		ArcadeLook.deco(self, "box", Vector3(fence_r, 0.012, 0.1), plate + dir * fence_r * 0.5 + Vector3(0, 0.008, 0), white, Vector3(0, atan2(dir.z, -dir.x) * -1.0 + PI, 0))
	# Cerca del jardin (arco de 90 grados, fisica) y tribunas detras.
	var segs: int = 12
	for k in segs:
		var a0: float = deg_to_rad(-FAIR_DEG - 5.0 + (2.0 * FAIR_DEG + 10.0) * (float(k) + 0.5) / float(segs))
		var dir2 := Vector3(-cos(a0), 0, sin(a0))
		var w: float = 2.0 * fence_r * tan(deg_to_rad((2.0 * FAIR_DEG + 10.0) / float(segs) * 0.5)) + 0.1
		var wall := static_box(Vector3(0.3, fence_h, w), plate + dir2 * fence_r + Vector3(0, fence_h * 0.5, 0), Color(0.1, 0.3, 0.15), Vector3(0, -a0, 0), 0.3)
		for c in wall.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.08, 0.3, 0.16), "paint")
		ArcadeLook.deco(self, "box", Vector3(0.32, 0.12, w), plate + dir2 * fence_r + Vector3(0, fence_h + 0.06, 0), ArcadeLook.mat(Color(0.95, 0.75, 0.15), "paint"), Vector3(0, -a0, 0))
		for row in 3:
			ArcadeLook.deco(self, "box", Vector3(3.0, 1.2, w), plate + dir2 * (fence_r + 4.0 + float(row) * 3.0) + Vector3(0, 0.6 + float(row) * 1.2, 0), ArcadeLook.mat(Color(0.2, 0.22, 0.3), "stone"), Vector3(0, -a0, 0))
			for q in 3:
				var cc: Color = [Color(0.9, 0.2, 0.2), Color(0.2, 0.45, 0.95), Color(0.95, 0.85, 0.2), Color(0.9, 0.9, 0.9)][(k + row + q) % 4]
				var side_dir := Vector3(sin(a0), 0, cos(a0))
				ArcadeLook.deco(self, "box", Vector3(0.4, 0.6, 0.4), plate + dir2 * (fence_r + 4.0 + float(row) * 3.0) + side_dir * (float(q) - 1.0) * w * 0.3 + Vector3(0, 1.5 + float(row) * 1.2, 0), ArcadeLook.mat(cc, "paint"))
	# Cartel de distancia sobre la cerca y marcador.
	var dl := Label3D.new()
	dl.text = "%d m" % int(fence_r)
	dl.font_size = 96
	dl.pixel_size = 0.012
	dl.modulate = Color(1, 1, 1)
	dl.rotation_degrees = Vector3(0, 90, 0)
	add_child(dl)
	dl.global_position = plate + Vector3(-fence_r + 0.3, fence_h * 0.55, 0)
	ArcadeLook.billboard(self, "JONRÓN", plate + Vector3(-fence_r - 14.0, 9.0, 0), 10.0, 2.0, Color(0.05, 0.1, 0.25), Color(1.0, 0.85, 0.3), 180.0)
	# Maquina bateadora: base, columna y motor del pivote.
	var mach := ArcadeLook.mat(Color(0.25, 0.27, 0.32), "metal")
	ArcadeLook.deco(self, "box", Vector3(0.8, 0.12, 0.8), Vector3(PIVOT.x + 0.3, 0.06, PIVOT.z + 0.35), mach)
	ArcadeLook.deco(self, "box", Vector3(0.18, PIVOT.y - 0.15, 0.18), Vector3(PIVOT.x + 0.3, (PIVOT.y - 0.15) * 0.5, PIVOT.z + 0.35), mach)
	ArcadeLook.deco(self, "cyl", Vector3(0.16, 0.22, 0.16), PIVOT + Vector3(0, 0.14, 0), ArcadeLook.mat(Color(0.85, 0.2, 0.15), "metal"))
	ArcadeLook.deco(self, "box", Vector3(0.6, 0.1, 0.1), Vector3(PIVOT.x + 0.15, PIVOT.y + 0.14, PIVOT.z + 0.18), mach, Vector3(0, -0.6, 0))
	# Zona de strike (marco translucido) donde conviene que pase la pelota.
	var zone := StandardMaterial3D.new()
	zone.albedo_color = Color(1.0, 0.9, 0.3, 0.25)
	zone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone.cull_mode = BaseMaterial3D.CULL_DISABLED
	ArcadeLook.deco(self, "box", Vector3(0.01, 0.3, 0.5), Vector3(PIVOT.x - 0.2, PIVOT.y + 0.08, sweet_z()), zone)

## Z del punto dulce del bate cuando golpea (apuntando a -Z).
func sweet_z() -> float:
	return PIVOT.z - BAT_L * 0.72

const RESTITUTION := 0.55
const SUBSTEPS := 16
## Momento de inercia del bate respecto del pivote (barra: m L^2 / 3).
const BAT_I := BAT_MASS * BAT_L * BAT_L / 3.0

var bat_theta: float = 0.0
var bat_omega: float = 0.0

func _build_bat() -> void:
	bat = Node3D.new()
	add_child(bat)
	ArcadeLook.part(bat, "cyl", Vector3(BAT_R, BAT_L * 0.65, BAT_R * 0.6), Vector3(BAT_L * 0.62, 0, 0), ArcadeLook.mat(Color(0.75, 0.55, 0.32), "wood"), Vector3(0, 0, PI * 0.5))
	ArcadeLook.part(bat, "cyl", Vector3(BAT_R * 0.5, BAT_L * 0.35, BAT_R * 0.5), Vector3(BAT_L * 0.18, 0, 0), ArcadeLook.mat(Color(0.15, 0.15, 0.17), "rubber"), Vector3(0, 0, PI * 0.5))
	ArcadeLook.part(bat, "sphere", Vector3(BAT_R * 1.05, 0, 0), Vector3(BAT_L, 0, 0), ArcadeLook.mat(Color(0.75, 0.55, 0.32), "wood"))
	_ready_bat()

## Bate quieto en su posicion de espera (apuntando hacia atras, +X).
func _ready_bat() -> void:
	bat_theta = 0.0
	bat_omega = 0.0
	_pose_bat()
	swing = "ready"
	_fire_in = -1.0

func _pose_bat() -> void:
	bat.global_transform = Transform3D(Basis(Vector3.UP, bat_theta), PIVOT)

## Angulo del bate (rad): 0 apunta a +X; PI/2 a -Z (golpe); PI a -X.
func bat_angle() -> float:
	return fposmod(bat_theta, TAU)

static func bat_dir(theta: float) -> Vector3:
	return Vector3(cos(theta), 0.0, -sin(theta))

## Busca el primer contacto bate-pelota dentro de este paso (subpasos del giro del bate y del vuelo de la pelota) y aplica
## el impulso del choque a los dos. Devuelve true si hubo golpe.
func _bat_contact(delta: float) -> bool:
	var p0: Vector3 = ball.global_position
	var v0: Vector3 = ball.linear_velocity
	var g := Vector3(0, -9.8, 0)
	var rr: float = BAT_R + ball.radius
	for k in range(1, SUBSTEPS + 1):
		var t: float = delta * float(k) / float(SUBSTEPS)
		var th: float = bat_theta + bat_omega * t
		var d: Vector3 = bat_dir(th)
		var p: Vector3 = p0 + v0 * t + g * (0.5 * t * t)
		var s_along: float = clampf((p - PIVOT).dot(d), 0.0, BAT_L)
		var q: Vector3 = PIVOT + d * s_along
		var off: Vector3 = p - q
		if off.length() < rr:
			var n: Vector3 = off.normalized()
			var v: Vector3 = v0 + g * t
			var u: Vector3 = Vector3(0, bat_omega, 0).cross(q - PIVOT)
			var vrel: float = (v - u).dot(n)
			if vrel >= 0.0:
				return false
			var arm: Vector3 = q - PIVOT
			var lever: float = arm.cross(n).y
			var j: float = -(1.0 + RESTITUTION) * vrel / (1.0 / ball.mass + lever * lever / BAT_I)
			# Impulso sobre la pelota (y el bate pierde lo que da).
			ball.apply_central_impulse(n * j)
			exit_speed = (v + n * j / ball.mass).length()
			bat_omega -= j * lever / BAT_I
			bat_theta += bat_omega * t
			return true
	return false

func _level_step(delta: float) -> void:
	match swing:
		"ready":
			# Sensor: la pelota cruza SENSOR_D m antes del home yendo hacia el.
			if state == State.FLIGHT and ball.linear_velocity.x > 2.0 and ball.global_position.x >= PLATE_X - SENSOR_D and ball.global_position.x < PLATE_X:
				var vx: float = ball.linear_velocity.x
				# Llega al plano del bate cuando su centro esta a radio de pelota + radio de bate del pivote.
				var t_arrive: float = (PIVOT.x - BAT_R - ball.radius - ball.global_position.x) / vx
				var t_swing: float = (PI * 0.5) / BAT_W
				_fire_in = maxf(t_arrive - t_swing, 0.0)
				swing = "armed"
		"armed":
			_fire_in -= delta
			if _fire_in <= 0.0:
				# El motor suelta el bate (gira con BAT_W; el impulso es de la maquina sobre el bate, no sobre la pelota).
				bat_omega = BAT_W
				swing = "swing"
	if swing == "swing":
		if not hit and _bat_contact(delta):
			_on_bat_hit()
		bat_theta += bat_omega * delta
		if bat_angle() > PI * 1.25 or bat_theta > PI * 1.25:
			# Fin del recorrido: el freno lo para.
			bat_omega = move_toward(bat_omega, 0.0, 120.0 * delta)
			if absf(bat_omega) < 0.2:
				swing = "done"
		_pose_bat()
	# Vuelo despues del golpe: primer pique o cerca.
	if hit and not landed:
		var p: Vector3 = ball.global_position
		var flat: Vector2 = Vector2(p.x - PLATE_X, p.z)
		var r: float = flat.length()
		if p.y > ball.radius + 0.3:
			_airborne = true
		if r >= fence_r and not homer:
			var ang: float = rad_to_deg(atan2(absf(p.z), PLATE_X - p.x))
			if p.y > fence_h and ang <= FAIR_DEG and p.x < PLATE_X:
				homer = true
				landed = true
				distance = r
				_popup("¡JONRÓN!")
			elif p.y <= fence_h:
				landed = true
				distance = r
		elif _airborne and p.y < ball.radius + 0.05 and ball.linear_velocity.y <= 0.0:
			landed = true
			distance = r if fair(p) else 0.0

func fair(p: Vector3) -> bool:
	return p.x < PLATE_X and rad_to_deg(atan2(absf(p.z), PLATE_X - p.x)) <= FAIR_DEG

func _on_bat_hit() -> void:
	if not hit:
		hit = true
		if not fast:
			cam.shake(0.3, 0.3)
		# Camara: plano alto desde atras del home mirando el jardin.
		cam.frame(Vector3(PLATE_X + 7.0, 8.0, 0.0), Vector3(PLATE_X - 30.0, 2.0, 0.0), 55.0, false, 0.5)

func _popup(text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 128
	l.pixel_size = 0.02
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1.0, 0.85, 0.2)
	l.outline_size = 16
	l.no_depth_test = true
	add_child(l)
	l.global_position = ball.global_position + Vector3.UP * 2.0
	var tw := create_tween()
	tw.tween_property(l, "global_position", l.global_position + Vector3.UP * 3.0, 1.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.tween_callback(l.queue_free)

func _settling() -> bool:
	return swing == "armed" or swing == "swing"

func _flight_check(_delta: float) -> String:
	if hit:
		if landed:
			return "jonron" if homer else ("hit" if distance > 0.0 else "foul")
		if _t > 9.0:
			landed = true
			distance = Vector2(ball.global_position.x - PLATE_X, ball.global_position.z).length() if fair(ball.global_position) else 0.0
			return "hit"
		return ""
	# Sin golpe: la pelota paso el home o se freno.
	if ball.global_position.x > PLATE_X + 1.5 or (_t > 0.8 and ball.linear_velocity.length() < SLOW_SPEED):
		return "strike"
	return ""

func _on_resolved(s: int, r: String) -> void:
	(results[s] as Array).append({"result": r, "distance": distance if r != "strike" and r != "foul" else 0.0, "homer": homer, "exit": exit_speed})
	match rule:
		"jonrones":
			points[s] += 1 if homer else 0
		"duelo":
			points[s] += 1 if homer else 0
		_:
			points[s] += int(round(distance)) if r == "hit" or r == "jonron" else 0
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if r == "jonron" or (r == "hit" and distance > fence_r * 0.6) else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)
	_refresh_score()

func _start_turn() -> void:
	hit = false
	landed = false
	homer = false
	distance = 0.0
	exit_speed = 0.0
	_airborne = false
	_ready_bat()
	super._start_turn()

func reset_level() -> void:
	results = [[], []]
	_ready_bat()
	super.reset_level()

func homers(s: int) -> int:
	var n: int = 0
	for r in results[s]:
		if bool(r["homer"]):
			n += 1
	return n

func total_distance(s: int) -> float:
	var d: float = 0.0
	for r in results[s]:
		d += float(r["distance"])
	return d

func _check_winner() -> int:
	if int(shots[sides - 1]) < shots_each:
		return -1
	if sides == 1:
		return Side.USER
	if homers(0) != homers(1):
		return Side.USER if homers(0) > homers(1) else Side.CPU
	return Side.USER if total_distance(0) >= total_distance(1) else Side.CPU

func final_score() -> int:
	return int(round(total_distance(0))) + 50 * homers(0) + (100 if rule == "duelo" and winner == Side.USER else 0)

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0, ball.radius if ball != null else 0.11, 0)

func _aim_point(_s: int) -> Vector3:
	return Vector3(PLATE_X, PIVOT.y, sweet_z())

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(PLATE_X - 0.4, Vector2(9.0, 28.0), false, 3.0, 3.0, ball.radius)

func frame_points() -> Array:
	return [PIVOT + Vector3(0, 0.6, 0), Vector3(PLATE_X, 0, 0)]

func _result_text(r: String) -> Array:
	match r:
		"jonron":
			return ["¡JONRÓN!", Color(0.35, 1.0, 0.45), "%.0f m · salió a %.0f km/h" % [distance, exit_speed * 3.6]]
		"hit":
			return ["%.0f m" % distance, Color(1.0, 0.85, 0.35), "Salió a %.0f km/h" % (exit_speed * 3.6)]
		"foul":
			return ["Foul", Color(1.0, 0.7, 0.4), "Fuera de las líneas"]
	return ["Strike", Color(1.0, 0.5, 0.4), "La pelota tiene que pasar por la zona amarilla"]

func _refresh_score() -> void:
	match rule:
		"jonrones":
			hud.set_score_text("Jonrones %d · tiros %d / %d" % [homers(0), int(shots[0]), shots_each])
		"duelo":
			hud.set_score_text("Jonrones: vos %d - %d CPU · tiros %d / %d" % [homers(0), homers(1), int(shots[0]), shots_each])
		_:
			hud.set_score_text("Distancia %.0f m · tiros %d / %d" % [total_distance(0), int(shots[0]), shots_each])

## Punto de la zona para apuntar: un poco por encima del eje del bate (elevacion) en el punto dulce.
func ideal_target() -> Vector3:
	# En el plano donde la pelota toca al bate (pivote - radio del bate - radio de la pelota), un poco POR ENCIMA del eje
	# del bate: el bate le pega en la mitad de abajo y la levanta (por debajo del eje sale un rodado contra el piso).
	return Vector3(PIVOT.x - BAT_R - (ball.radius if ball != null else 0.11), PIVOT.y + 0.12, sweet_z())

func _cpu_intent() -> Dictionary:
	var err: float = cpu_error_deg if cpu_error_deg >= 0.0 else float(CPU_ERROR[clampi(SpSettings.level(), 0, CPU_ERROR.size() - 1)])
	return cpu_shot(ideal_target(), 19.0, 0.0, err)
