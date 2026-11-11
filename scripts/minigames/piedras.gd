class_name Piedras
extends Minigame
## «Piedras saltarinas» (HABILIDAD). Desde la orilla de un lago se patea rasante: cuando la pelota toca el agua con un
## angulo de entrada chico (MAX_ANGLE) y suficiente velocidad horizontal (MIN_SPEED), el agua la devuelve hacia arriba
## (un IMPULSO sobre la pelota: invierte parte de la velocidad vertical y le quita velocidad horizontal); con mucho
## angulo o poca velocidad se clava: el agua la frena (arrastre) y la hace flotar (empuje), y ahi termina el tiro. Se
## cuentan los piques reales y la distancia desde la orilla. Cada pique deja una onda en el agua.
## Reglas ("rule"): "piques" (mejor tiro por cantidad de piques), "distancia" (mejor distancia), "suma" (suma de piques
## de todos los tiros).

const SCENE := "res://scenes/minigames/piedras.tscn"
const SHORE_X := 1.6
const MAX_ANGLE := 20.0
const MIN_SPEED := 5.0
## Rebote: la vertical vuelve con BOUNCE_Y de su valor y la horizontal conserva KEEP_H.
const BOUNCE_Y := 0.75
const KEEP_H := 0.85
## Sustentacion por velocidad: la vertical de salida no baja de LIFT x la horizontal (hidroplaneo).
const LIFT := 0.12
const WATER_DRAG := 4.0
## Tiempo minimo en el aire para que un contacto cuente como pique (si no, va rozando el agua).
const MIN_AIR := 0.12

var rule: String = "piques"
var shots_max: int = 5
var skips: int = 0
var distance: float = 0.0
var plunged: bool = false
var throws: Array = []
var _water_mat: StandardMaterial3D
var _was_above: bool = true
var _air_t: float = 1.0

func game_id() -> String:
	return "piedras"

func _build_level() -> void:
	sides = 1
	rule = String(def.get("rule", "piques"))
	shots_max = int(def.get("shots", 5))
	max_turns = shots_max
	# Orilla (piso hasta SHORE_X) y fondo del lago a 3 m: el agua no tiene colision, la maneja el juego.
	var beach := static_box(Vector3(12, 1, 60), Vector3(SHORE_X - 6.0, -0.5, 0), Color(0.85, 0.75, 0.55), Vector3.ZERO, 0.4)
	for c in beach.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.72, 0.62, 0.42), "stone", 6.0)
	static_box(Vector3(140, 1, 80), Vector3(SHORE_X + 70.0, -3.5, 0), Color(0.2, 0.25, 0.2), Vector3.ZERO, 0.2)
	_build_stage()

func _build_stage() -> void:
	ArcadeLook.light(self, Color(1.0, 0.9, 0.75), 1.05, Color(0.25, 0.45, 0.85), Color(0.95, 0.75, 0.55), 0.8, Vector3(-25, 160, 0))
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(140, 80)
	water.mesh = pm
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(0.12, 0.38, 0.55, 0.85)
	_water_mat.albedo_texture = ArcadeLook.noise_tex("fine")
	_water_mat.uv1_scale = Vector3(30, 30, 30)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.metallic_specular = 1.0
	_water_mat.roughness = 0.08
	water.material_override = _water_mat
	add_child(water)
	water.global_position = Vector3(SHORE_X + 70.0, 0.0, 0)
	# Muelle de madera, boyas cada 10 m, arboles en la orilla y montañas al fondo.
	ArcadeLook.deco(self, "box", Vector3(4.0, 0.12, 2.0), Vector3(SHORE_X + 1.5, 0.25, -4.0), ArcadeLook.mat(Color(0.55, 0.38, 0.22), "wood", 2.0))
	for k in 4:
		ArcadeLook.deco(self, "cyl", Vector3(0.08, 1.2, 0.08), Vector3(SHORE_X + 0.2 + float(k) * 1.0, -0.3, -4.9), ArcadeLook.mat(Color(0.4, 0.28, 0.16), "wood"))
	for k in 6:
		var x: float = SHORE_X + 10.0 * float(k + 1)
		ArcadeLook.deco(self, "sphere", Vector3(0.22, 0, 0), Vector3(x, 0.1, 3.5), ArcadeLook.mat(Color(1.0, 0.45, 0.1) if k % 2 == 0 else Color(0.97, 0.97, 0.97), "plastic"))
		var l := Label3D.new()
		l.text = "%d m" % int(10 * (k + 1))
		l.font_size = 64
		l.pixel_size = 0.01
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(l)
		l.global_position = Vector3(x, 0.8, 3.5)
	for k in 12:
		var z: float = -20.0 + float(k) * 3.6
		# (A los costados: delante de la camara taparian la vista.)
		if absf(z) < 7.0:
			continue
		ArcadeLook.deco(self, "cyl", Vector3(0.15, 2.2, 0.2), Vector3(-5.0 - float(k % 3), 1.1, z), ArcadeLook.mat(Color(0.4, 0.27, 0.15), "wood"))
		ArcadeLook.deco(self, "sphere", Vector3(1.1, 0, 0), Vector3(-5.0 - float(k % 3), 2.8, z), ArcadeLook.mat(Color(0.18, 0.45, 0.2), "paint"))
	for k in 5:
		ArcadeLook.deco(self, "cyl", Vector3(0.01, 18.0 + float(k % 2) * 6.0, 16.0), Vector3(110.0, 9.0, -40.0 + float(k) * 20.0), ArcadeLook.mat(Color(0.35, 0.4, 0.5), "stone", 2.0))
	ArcadeLook.billboard(self, "PIEDRAS SALTARINAS", Vector3(SHORE_X + 1.5, 1.2, -5.2), 3.6, 0.5, Color(0.3, 0.2, 0.1), Color(1.0, 0.95, 0.8), 0.0)

func _level_step(delta: float) -> void:
	if _water_mat != null:
		_water_mat.uv1_offset = Vector3(level_time * 0.01, level_time * 0.006, 0)
	if state != State.FLIGHT:
		return
	var p: Vector3 = ball.global_position
	var v: Vector3 = ball.linear_velocity
	if p.x <= SHORE_X:
		_was_above = true
		return
	if plunged:
		# Clavada: el agua la frena y la hace flotar (impulsos de arrastre y de empuje).
		var drag: Vector3 = -v * clampf(WATER_DRAG * delta, 0.0, 0.9)
		var buoy: float = 0.0
		if p.y < 0.0:
			buoy = (9.8 * 1.6 + 6.0 * -p.y) * delta
		ball.apply_central_impulse((drag + Vector3.UP * buoy) * ball.mass)
		return
	# Toca el agua (el borde de abajo de la pelota llega a la superficie) bajando: cada contacto se evalua; el pique
	# cuenta si estuvo en el aire al menos MIN_AIR (si va rozando, cada contacto igual le saca velocidad).
	if p.y - ball.radius > 0.01:
		_air_t += delta
	if p.y - ball.radius <= 0.0 and v.y < 0.0:
		var vh: float = Vector2(v.x, v.z).length()
		var ang: float = rad_to_deg(atan2(-v.y, maxf(vh, 0.001)))
		if ang <= MAX_ANGLE and vh >= MIN_SPEED:
			# Sustentacion del agua: cuanto mas rapido roza, mas alto rebota (v_y de salida >= LIFT * v_h).
			var nv := Vector3(v.x * KEEP_H, maxf(-v.y * BOUNCE_Y, LIFT * vh), v.z * KEEP_H)
			ball.apply_central_impulse((nv - v) * ball.mass)
			if _air_t >= MIN_AIR:
				skips += 1
				distance = p.x - SHORE_X
				_ripple(Vector3(p.x, 0.02, p.z), 1.0)
			_air_t = 0.0
		else:
			plunged = true
			distance = p.x - SHORE_X
			_ripple(Vector3(p.x, 0.02, p.z), 1.8)

## Onda en el agua: un aro que se agranda y se apaga.
func _ripple(at: Vector3, size: float) -> void:
	var r := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.25
	tm.outer_radius = 0.32
	tm.rings = 24
	tm.ring_segments = 4
	r.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.97, 1.0, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r.material_override = m
	r.scale = Vector3(1, 0.1, 1)
	add_child(r)
	r.global_position = at
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(r, "scale", Vector3(5.0 * size, 0.1, 5.0 * size), 1.2)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 1.2)
	tw.tween_callback(r.queue_free)

func _on_contact(entry: Dictionary) -> void:
	super._on_contact(entry)
	skips = 0
	distance = 0.0
	plunged = false
	_was_above = true
	_air_t = 1.0

func _flight_check(_delta: float) -> String:
	var p: Vector3 = ball.global_position
	if plunged and _t > 0.4 and ball.linear_velocity.length() < 0.6:
		return "clavada"
	if p.x <= SHORE_X and _t > 0.8 and ball.linear_velocity.length() < SLOW_SPEED:
		return "orilla"
	if absf(p.z) > 35.0 or p.x > 130.0:
		return "clavada"
	return ""

func _flight_watchdog(_delta: float) -> String:
	return "clavada" if _t > 15.0 else ""

func _on_resolved(s: int, r: String) -> void:
	throws.append({"skips": skips if r == "clavada" else 0, "distance": distance if r == "clavada" else 0.0})
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if skips >= 3 else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)
	_refresh_score()

func best_skips() -> int:
	var b: int = 0
	for t in throws:
		b = maxi(b, int(t["skips"]))
	return b

func best_distance() -> float:
	var b: float = 0.0
	for t in throws:
		b = maxf(b, float(t["distance"]))
	return b

func total_skips() -> int:
	var n: int = 0
	for t in throws:
		n += int(t["skips"])
	return n

func _check_winner() -> int:
	return Side.USER if int(shots[0]) >= shots_max else -1

func final_score() -> int:
	match rule:
		"distancia":
			return int(round(best_distance() * 10.0))
		"suma":
			return total_skips() * 30
	return best_skips() * 50 + int(round(best_distance()))

func reset_level() -> void:
	throws.clear()
	super.reset_level()

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0, ball.radius if ball != null else 0.11, 0)

func _aim_point(_s: int) -> Vector3:
	return Vector3(20.0, 0.3, 0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(14.0, Vector2(10.0, 30.0), false, 6.0, 2.0, ball.radius)

func frame_points() -> Array:
	return [Vector3(SHORE_X + 15.0, 0, 0)]

func _result_text(r: String) -> Array:
	if r == "orilla":
		return ["No llegó al agua", Color(1.0, 0.6, 0.4), ""]
	if skips == 0:
		return ["¡Se clavó!", Color(1.0, 0.6, 0.4), "Entró con mucho ángulo: más rasante y más fuerte"]
	return ["%d pique%s" % [skips, "" if skips == 1 else "s"], Color(0.35, 1.0, 0.45) if skips >= 3 else Color(1.0, 0.85, 0.35), "%.1f m" % distance]

func _refresh_score() -> void:
	match rule:
		"distancia":
			hud.set_score_text("Mejor %.1f m · tiros %d / %d" % [best_distance(), int(shots[0]), shots_max])
		"suma":
			hud.set_score_text("Piques %d · tiros %d / %d" % [total_skips(), int(shots[0]), shots_max])
		_:
			hud.set_score_text("Mejor %d piques · tiros %d / %d" % [best_skips(), int(shots[0]), shots_max])

## Tiro rasante (para la IA de las pruebas): direccion +X, angulo y velocidad dados.
static func flat_kick(speed: float, angle_deg: float, yaw_deg: float = 0.0) -> Vector3:
	var a: float = deg_to_rad(angle_deg)
	return Vector3(cos(a) * speed, sin(a) * speed, 0).rotated(Vector3.UP, deg_to_rad(yaw_deg))
