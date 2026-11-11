class_name ArosFuego
extends Minigame
## «Aros de fuego» (DESAFIOS DE ARCO). Aros verticales colgados de cadenas, de frente al jugador: el aro es fisico
## (anillo de esferas: la pelota puede pegar en el borde y rebotar). Pasar por un aro = el centro de la pelota cruza el
## plano del aro dentro del radio libre (radio - tubo - radio de la pelota... con el margen del tubo). Una "secuencia"
## es una fila de aros: vale solo si en el MISMO tiro pasa por todos, en orden. Cada aro vale "value" (100 por defecto),
## la secuencia completa duplica. Fuego liviano para Android: lenguas de llama (conos con material que brilla) que
## titilan por escala y brillo, sin particulas ni luces extra.
##
## Niveles en minigames.json ("aros_fuego"): rings [{pos, r, value?, move?}] o sequences [[{pos, r}, ...]], shots.

const SCENE := "res://scenes/minigames/aros_fuego.tscn"
const TUBE := 0.05
const SPHERES := 18

## {body, center, r, value, seq (indice de secuencia o -1), order, passed_shot, flames, base, move}
var rings: Array = []
var sequences: int = 0
var shots_max: int = 5
var passed_now: Array = []
var total_pts: int = 0
var seq_done: int = 0
var _prev_p := Vector3.ZERO
var _flames: Array = []

func game_id() -> String:
	return "aros_fuego"

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 5))
	max_turns = shots_max
	var ground := static_box(Vector3(80, 1, 40), Vector3(10, -0.5, 0), Color(0.2, 0.2, 0.2), Vector3.ZERO, 0.45)
	for c in ground.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	_build_stage()
	for rd in def.get("rings", []):
		_ring(rd, -1, 0)
	var si: int = 0
	for sq in def.get("sequences", []):
		var k: int = 0
		for rd in sq:
			_ring(rd, si, k)
			k += 1
		si += 1
	sequences = si

func _build_stage() -> void:
	ArcadeLook.light(self, Color(1.0, 0.75, 0.5), 0.75, Color(0.04, 0.03, 0.1), Color(0.35, 0.12, 0.08), 0.55, Vector3(-35, -30, 0))
	ArcadeLook.ground(self, Vector2(160, 120), Vector3(10, 0, 0), Color(0.45, 0.32, 0.22), "stone", 40.0)
	# Arena de circo: pista circular con borde rojo y blanco, carpa (postes y lonas) y tribunas.
	# (El borde de la pista queda detras del jugador: lo decorativo no tiene colision.)
	ArcadeLook.deco(self, "cyl", Vector3(16.5, 0.01, 16.5), Vector3(13.5, 0.004, 0), ArcadeLook.mat(Color(0.62, 0.45, 0.3), "stone", 4.0))
	for k in 28:
		var a: float = TAU * float(k) / 28.0
		ArcadeLook.deco(self, "box", Vector3(0.4, 0.45, 3.7), Vector3(13.5 + cos(a) * 16.7, 0.22, sin(a) * 16.7), ArcadeLook.mat(Color(0.85, 0.12, 0.12) if k % 2 == 0 else Color(0.97, 0.97, 0.97), "paint"), Vector3(0, -a, 0))
	for z in [-9.0, 9.0]:
		ArcadeLook.deco(self, "cyl", Vector3(0.18, 14.0, 0.22), Vector3(12, 7.0, z), ArcadeLook.mat(Color(0.85, 0.75, 0.3), "metal"))
	for k in 8:
		var a2: float = TAU * float(k) / 8.0
		ArcadeLook.deco(self, "box", Vector3(0.1, 0.1, 15.0), Vector3(12 + cos(a2) * 7.0, 13.5, sin(a2) * 7.0), ArcadeLook.mat(Color(0.9, 0.15, 0.15) if k % 2 == 0 else Color(0.97, 0.9, 0.3), "paint"), Vector3(0, -a2 + PI * 0.5, 0.9))
	ArcadeLook.billboard(self, "AROS DE FUEGO", Vector3(28.0, 5.0, 0), 8.0, 1.4, Color(0.3, 0.05, 0.02), Color(1.0, 0.7, 0.2))

func _ring(rd: Dictionary, seq: int, order: int) -> void:
	var pos: Vector3 = BotonCaida._vec(rd.get("pos", [12, 2.5, 0]))
	var r: float = float(rd.get("r", 0.6))
	var mv: Dictionary = rd.get("move", {})
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = Ball.LAYER_WORLD
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.5
	body.physics_material_override = pm
	# Anillo en el plano YZ (de frente a quien patea, que mira hacia +X).
	for i in SPHERES:
		var a: float = TAU * float(i) / float(SPHERES)
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = TUBE
		cs.shape = sp
		cs.position = Vector3(0, cos(a) * r, sin(a) * r)
		body.add_child(cs)
	var tm := TorusMesh.new()
	tm.inner_radius = r - TUBE
	tm.outer_radius = r + TUBE
	tm.rings = 32
	tm.ring_segments = 8
	var torus := MeshInstance3D.new()
	torus.mesh = tm
	torus.material_override = ArcadeLook.mat(Color(0.25, 0.22, 0.2), "metal")
	torus.rotation_degrees = Vector3(0, 0, 90)
	body.add_child(torus)
	# Llamas: conos que brillan alrededor del aro (titilan en _level_step).
	var flames: Array = []
	var n: int = 12
	for i in n:
		var a2: float = TAU * float(i) / float(n)
		var f := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.11
		cm.height = 0.42
		cm.radial_segments = 6
		cm.rings = 1
		f.mesh = cm
		f.material_override = ArcadeLook.glow(Color(1.0, 0.45, 0.08) if i % 2 == 0 else Color(1.0, 0.8, 0.2), 2.6)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var out := Vector3(0, cos(a2), sin(a2))
		f.position = out * (r + 0.16)
		f.basis = Basis(Vector3(1, 0, 0), -a2)
		body.add_child(f)
		flames.append(f)
		_flames.append(f)
	add_child(body)
	body.global_position = pos
	# Cadenas al techo de la carpa (visual).
	ArcadeLook.deco(self, "cyl", Vector3(0.015, 6.0, 0.015), pos + Vector3(0, r + 3.0, 0), ArcadeLook.mat(Color(0.4, 0.4, 0.42), "metal"))
	var e := {"body": body, "center": pos, "r": r, "value": int(rd.get("value", 100)), "seq": seq, "order": order,
		"passed_shot": -1, "base": body.global_transform, "move": mv}
	if not mv.is_empty():
		e["mover"] = add_mover(body, BotonCaida._vec(mv.get("axis", [0, 1, 0])), float(mv.get("amp", 0.8)), float(mv.get("speed", 1.0)), float(mv.get("phase", 0.0)))
	if seq >= 0:
		var l := Label3D.new()
		l.text = str(order + 1)
		l.font_size = 72
		l.pixel_size = 0.006
		l.modulate = Color(1.0, 0.9, 0.5)
		l.outline_size = 10
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		body.add_child(l)
		l.position = Vector3(0, r + 0.45, 0)
	rings.append(e)

## Centro actual de un aro (los que se mueven, donde estan ahora).
func ring_center(e: Dictionary) -> Vector3:
	return (e["body"] as Node3D).global_position

func _level_step(_delta: float) -> void:
	# Llamas: escala y brillo que titilan (barato).
	for i in _flames.size():
		var f: MeshInstance3D = _flames[i]
		var k: float = 0.75 + 0.35 * sin(level_time * (9.0 + float(i % 5)) + float(i) * 1.7)
		f.scale = Vector3(1.0, k, 1.0)
	var p: Vector3 = ball.global_position
	if state == State.FLIGHT:
		for e in rings:
			var c: Vector3 = ring_center(e)
			if _prev_p.x < c.x and p.x >= c.x and int(e["passed_shot"]) != int(shots[0]):
				var t: float = (c.x - _prev_p.x) / maxf(p.x - _prev_p.x, 0.0001)
				var q: Vector3 = _prev_p.lerp(p, t)
				if Vector2(q.y - c.y, q.z - c.z).length() <= float(e["r"]) - TUBE * 0.5:
					e["passed_shot"] = int(shots[0])
					passed_now.append(e)
	_prev_p = p

func _on_contact(entry: Dictionary) -> void:
	super._on_contact(entry)
	passed_now.clear()
	_prev_p = ball.global_position

func _flight_check(_delta: float) -> String:
	var far: float = 0.0
	for e in rings:
		far = maxf(far, ring_center(e).x)
	if ball.global_position.x > far + 3.0 or (_t > 0.8 and ball.linear_velocity.length() < SLOW_SPEED) or ball.global_position.x < -2.0:
		return "listo"
	return ""

func _on_resolved(s: int, _r: String) -> void:
	# Aros sueltos: su valor. Secuencias: valen si se paso por TODOS sus aros en orden en este tiro (x2).
	var gained: int = 0
	for e in passed_now:
		if int(e["seq"]) < 0:
			gained += int(e["value"])
	for si in sequences:
		var seq: Array = []
		for e in rings:
			if int(e["seq"]) == si:
				seq.append(e)
		var got: Array = []
		for e in passed_now:
			if int(e["seq"]) == si:
				got.append(int(e["order"]))
		if got.size() == seq.size():
			var ordered := true
			for k in got.size():
				if int(got[k]) != k:
					ordered = false
			if ordered:
				seq_done += 1
				for e in seq:
					gained += int(e["value"]) * 2
	total_pts += gained
	points[0] = total_pts
	last_gain = gained
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if gained > 0 else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)
	_refresh_score()

var last_gain: int = 0

func _check_winner() -> int:
	return Side.USER if int(shots[0]) >= shots_max else -1

func final_score() -> int:
	return total_pts

func reset_level() -> void:
	total_pts = 0
	seq_done = 0
	passed_now.clear()
	for e in rings:
		e["passed_shot"] = -1
	super.reset_level()

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0, ball.radius if ball != null else 0.11, 0)

func _aim_point(_s: int) -> Vector3:
	if rings.is_empty():
		return Vector3(12, 2.5, 0)
	return ring_center(rings[0])

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(_aim_point(0).x, Vector2(9.0, 28.0), false, 4.0, 5.0, ball.radius)

func frame_points() -> Array:
	var out: Array = []
	for e in rings:
		out.append((e["center"] as Vector3) + Vector3.UP * (float(e["r"]) + 0.3))
	return out

func _result_text(_r: String) -> Array:
	if last_gain > 0:
		return ["+%d" % last_gain, Color(1.0, 0.75, 0.25), "Aros %d en este tiro" % passed_now.size()]
	if not passed_now.is_empty():
		return ["Secuencia incompleta", Color(1.0, 0.6, 0.4), "Hay que pasar por todos, en orden, en el mismo tiro"]
	return ["Sin aro", Color(1.0, 0.6, 0.4), ""]

func _refresh_score() -> void:
	hud.set_score_text("Puntos %d · tiros %d / %d" % [total_pts, int(shots[0]), shots_max])
