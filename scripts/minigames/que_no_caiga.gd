class_name QueNoCaiga
extends RallyBase
## «Que no caiga» (etapa B1): pases aereos entre los dos jugadores sin dejar que la pelota toque el piso. PIERDE EL
## ULTIMO QUE LA TOCO cuando pica. Cada uno puede amortiguarla una vez (control con pecho, muslo, cabeza o pie, segun la
## altura real) y despues tiene que pasarla: un tercer toque seguido es falta. El usuario dibuja el pase con el dedo
## (en cualquier momento mientras la pelota viene); la IA corre a la caida prevista con error y retardo por dificultad y
## devuelve con punteria imperfecta. 1 contra 1 hoy; la arquitectura (intenciones + RallyPlayer por jugador) queda lista
## para equipos de hasta 5 y, mas adelante, en linea.

const SCENE := "res://scenes/minigames/que_no_caiga.tscn"

func game_id() -> String:
	return "que_no_caiga"

func _build_level() -> void:
	sides = 2
	max_turns = 99
	static_box(Vector3(40, 1, 26), Vector3(3.5, -0.5, 0), Color(0.18, 0.5, 0.24), Vector3.ZERO, 0.45)
	# Un circulo pintado como referencia del juego.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 5.2
	tm.outer_radius = 5.3
	ring.mesh = tm
	ring.material_override = Minigame.color_mat(Color(0.95, 0.95, 0.98, 0.5))
	add_child(ring)
	ring.global_position = Vector3(3.5, 0.02, 0)

func home(s: int) -> Vector3:
	var gap: float = float(def.get("gap", 7.0))
	return Vector3(0.0 if s == Side.USER else gap, 0, 0)

func _ball_spot(s: int) -> Vector3:
	# Adelante y al costado del jugador (que no la tape el cuerpo desde la camara).
	return home(s) + Vector3(0.55 if s == Side.USER else -0.55, ball.radius, 0.55 if s == Side.USER else -0.55)

func _aim_point(s: int) -> Vector3:
	return home(1 - s) + Vector3.UP * 1.2

func _serve_spot() -> Vector3:
	return _ball_spot(serve_side)

## Toque hecho (o saque): la caida prevista define quien la juega: si cae cerca del que la toco, la sigue jugando el
## (control); si va hacia el otro, la juega el otro.
func _after_ball_sent(toucher: int, v: Vector3) -> void:
	var l: Array = RallyBase.landing_of(ball.global_position, v, Vector3.ZERO)
	if l.is_empty():
		return
	var landing: Vector3 = l[0]
	var receiver: int = toucher
	var d_self: float = Vector3(landing.x - home(toucher).x, 0, landing.z - home(toucher).z).length()
	var d_other: float = Vector3(landing.x - home(1 - toucher).x, 0, landing.z - home(1 - toucher).z).length()
	if d_other < d_self:
		receiver = 1 - toucher
	_marker.visible = true
	_marker.global_position = Vector3(landing.x, 0.03, landing.z)
	var rp: RallyPlayer = players[receiver]
	rp.expect(landing, float(l[1]))
	if receiver == Side.CPU:
		# La IA decide: si viene comoda devuelve de una; si no, controla primero. Tercer toque nunca (seria falta).
		if touches[Side.CPU] >= 1 or rng.randf() < 0.65:
			rp.order = {"target": home(Side.USER) + Vector3(rng.randf_range(-1.0, 1.0), 0.15, rng.randf_range(-1.0, 1.0)) * [1.6, 1.2, 0.8, 0.6, 0.45][SpSettings.level()],
				"speed": rng.randf_range(8.0, 10.5)}
		else:
			rp.order = {}
	else:
		rp.order = user_intent
		if touches[Side.USER] >= 1 and user_intent.is_empty():
			hud.set_hint("¡Pasala! (ya la controlaste: el tercer toque es falta)")

func _on_touch(kind: StringName, s: int) -> void:
	super._on_touch(kind, s)
	if kind == &"miss":
		return
	# Falta: tercer toque seguido del mismo jugador.
	if touches[s] > 2:
		give_point(1 - s, "Tres toques seguidos: falta")

func _on_ground(_pos: Vector3) -> void:
	# Pico: pierde el ultimo que la toco (si nadie la toco despues del saque, pierde el que saco).
	var loser: int = last_toucher if last_toucher >= 0 else serve_side
	give_point(1 - loser, "La dejó caer %s" % ("el rival" if loser == Side.CPU else "tu equipo"))

func _rally_step(_delta: float) -> void:
	# Seguro: la pelota rodando sin que nadie la juegue (toque desviado al vacio) tambien es caida.
	if rally_age > 0.5 and ball.is_grounded() and ball.linear_velocity.length() < 1.0:
		_on_ground(ball.global_position)

func _report_achievements(w: int, medal: int) -> void:
	super._report_achievements(w, medal)
	if rally_hits >= 8:
		Achievements.event(&"peloteo_largo")
