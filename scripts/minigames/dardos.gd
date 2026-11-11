class_name Dardos
extends Minigame
## «Dardos» (HABILIDAD). Una diana de dardos gigante de pie frente al jugador: 20 sectores en el orden de siempre
## (20 arriba), anillo triple, anillo doble, bull de 25 y centro de 50. El puntaje sale del PUNTO DE IMPACTO REAL de la
## pelota sobre la cara (trayectoria de antes del choque cruzada con el plano de la diana, como en Dianas); la pelota
## rebota (no se clava) y solo cuenta el primer impacto de cada tiro.
## Reglas por nivel ("rule"):
##  - "puntos": sumar con los tiros;
##  - "sector": solo cuenta el sector del nivel ("sector": 20), con su multiplicador;
##  - "301": bajar de 301 a 0 exacto; si te pasas, ese tiro no cuenta (se «revienta»);
##  - "duelo": contra la IA, tiros alternados, gana el que mas suma (la IA apunta al triple 20 o al centro segun su error).
## Las medidas de los anillos son configurables ("rings": {bull, outer_bull, triple_in, triple_out, double_in}) y estan
## agrandadas respecto de una diana real para una pelota de 0,22 m.

const SCENE := "res://scenes/minigames/dardos.tscn"
const ORDER := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
const DEFAULT_RINGS := {"bull": 0.12, "outer_bull": 0.27, "triple_in": 0.92, "triple_out": 1.1, "double_in": 1.58}
const MIN_HIT := 3.0
const CPU_ERROR := [1.6, 1.15, 0.85, 0.6, 0.45]

var radius: float = 1.8
var center := Vector3(13.0, 2.0, 0.0)
var rings: Dictionary = DEFAULT_RINGS
var rule: String = "puntos"
var shots_each: int = 6
var remaining: Array = [301, 301]
var last_hit: Dictionary = {}
var hits_log: Array = []
var cpu_error_deg: float = -1.0
var _board: StaticBody3D
var _bp := Vector3.ZERO
var _bv := Vector3.ZERO
var _scored_shot: int = -1

func game_id() -> String:
	return "dardos"

func _build_level() -> void:
	rule = String(def.get("rule", "puntos"))
	sides = 2 if rule == "duelo" else 1
	shots_each = int(def.get("shots", 6))
	max_turns = shots_each * sides
	radius = float(def.get("radius", 1.8))
	center = Vector3(float(def.get("distance", 13.0)), float(def.get("height", 2.0)), 0.0)
	rings = DEFAULT_RINGS.duplicate()
	rings.merge(def.get("rings", {}), true)
	var start: int = int(def.get("start", 301))
	remaining = [start, start]
	var ground := static_box(Vector3(80, 1, 40), Vector3(10, -0.5, 0), Color(0.2, 0.2, 0.2), Vector3.ZERO, 0.45)
	for c in ground.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	_build_board()
	_build_stage()
	ball.body_entered.connect(_on_ball_body)

func _build_board() -> void:
	_board = StaticBody3D.new()
	_board.collision_layer = Ball.LAYER_WORLD
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.25
	pm.friction = 0.8
	_board.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius + 0.18
	cyl.height = 0.2
	cs.shape = cyl
	cs.rotation_degrees = Vector3(0, 0, 90)
	_board.add_child(cs)
	add_child(_board)
	_board.global_position = center + Vector3(0.1, 0, 0)
	# Cara: una sola malla con colores por vertice (sectores y anillos), en el plano x = -0.001 local del tablero.
	var mi := MeshInstance3D.new()
	mi.mesh = _face_mesh()
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.roughness = 0.8
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Sin sombreado: los colores de la diana se leen igual con cualquier luz (y cuesta menos).
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = fm
	_board.add_child(mi)
	mi.position = Vector3(-0.101, 0, 0)
	# Aro negro de los numeros y borde metalico.
	ArcadeLook.part(_board, "cyl", Vector3(radius + 0.18, 0.2, radius + 0.18), Vector3.ZERO, ArcadeLook.mat(Color(0.08, 0.08, 0.09), "paint"), Vector3(0, 0, PI * 0.5))
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius + 0.16
	tm.outer_radius = radius + 0.24
	tm.rings = 48
	tm.ring_segments = 6
	rim.mesh = tm
	rim.material_override = ArcadeLook.mat(Color(0.82, 0.83, 0.88), "metal")
	rim.rotation_degrees = Vector3(0, 0, 90)
	rim.position = Vector3(-0.05, 0, 0)
	_board.add_child(rim)
	for i in 20:
		var a: float = float(i) * TAU / 20.0
		var l := Label3D.new()
		l.text = str(ORDER[i])
		l.font_size = 72
		l.pixel_size = 0.0042
		l.modulate = Color(1, 1, 1)
		l.double_sided = false
		l.rotation_degrees = Vector3(0, -90, 0)
		l.position = Vector3(-0.12, cos(a) * (radius + 0.09), sin(a) * (radius + 0.09))
		_board.add_child(l)
	# Pie del tablero.
	for z in [-0.6, 0.6]:
		ArcadeLook.deco(self, "box", Vector3(0.14, center.y - radius * 0.4, 0.14), Vector3(center.x + 0.35, (center.y - radius * 0.4) * 0.5, z), ArcadeLook.mat(Color(0.3, 0.2, 0.12), "wood"), Vector3(0, 0, 0))
	ArcadeLook.deco(self, "box", Vector3(0.8, 0.12, 2.0), Vector3(center.x + 0.4, 0.06, 0), ArcadeLook.mat(Color(0.3, 0.2, 0.12), "wood"))

## Sector (1..20) y anillo de un angulo/radio. Angulo 0 = arriba, creciendo hacia la DERECHA de quien patea (+Z).
func _face_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bands: Array = [[float(rings["outer_bull"]), float(rings["triple_in"]), "single"], [float(rings["triple_in"]), float(rings["triple_out"]), "triple"],
		[float(rings["triple_out"]), float(rings["double_in"]), "single"], [float(rings["double_in"]), radius, "double"]]
	var steps: int = 4
	for i in 20:
		var a0: float = (float(i) - 0.5) * TAU / 20.0
		var dark: bool = i % 2 == 0
		for b in bands:
			var c: Color
			if String(b[2]) == "single":
				c = Color(0.08, 0.08, 0.08) if dark else Color(0.93, 0.88, 0.74)
			else:
				c = Color(0.85, 0.12, 0.12) if dark else Color(0.1, 0.55, 0.25)
			for k in steps:
				var t0: float = a0 + TAU / 20.0 * float(k) / float(steps)
				var t1: float = a0 + TAU / 20.0 * float(k + 1) / float(steps)
				_quad(st, float(b[0]), float(b[1]), t0, t1, c)
	# Bull de 25 (verde) y centro de 50 (rojo), un poco por delante.
	for k in 32:
		var t0b: float = TAU * float(k) / 32.0
		var t1b: float = TAU * float(k + 1) / 32.0
		_quad(st, float(rings["bull"]), float(rings["outer_bull"]), t0b, t1b, Color(0.1, 0.55, 0.25))
		_quad(st, 0.0, float(rings["bull"]), t0b, t1b, Color(0.85, 0.12, 0.12))
	return st.commit()

## Cuadrilatero del anillo [r0, r1] entre los angulos t0..t1, mirando a -X (quien patea).
func _quad(st: SurfaceTool, r0: float, r1: float, t0: float, t1: float, c: Color) -> void:
	var p := func(r: float, t: float) -> Vector3:
		return Vector3(0.0, cos(t) * r, sin(t) * r)
	var v0: Vector3 = p.call(r0, t0)
	var v1: Vector3 = p.call(r1, t0)
	var v2: Vector3 = p.call(r1, t1)
	var v3: Vector3 = p.call(r0, t1)
	for v in [v0, v2, v1, v0, v3, v2]:
		st.set_color(c)
		st.set_normal(Vector3(-1, 0, 0))
		st.add_vertex(v)

func _build_stage() -> void:
	ArcadeLook.light(self, Color(1.0, 0.9, 0.75), 0.95, Color(0.1, 0.08, 0.06), Color(0.4, 0.28, 0.18), 0.75, Vector3(-45, -25, 0))
	# Bar de dardos: piso de madera, linea de tiro, pared de ladrillo con la diana y carteles.
	ArcadeLook.ground(self, Vector2(160, 120), Vector3(10, 0, 0), Color(0.45, 0.3, 0.17), "wood", 60.0)
	ArcadeLook.deco(self, "box", Vector3(0.1, 0.012, 3.0), Vector3(-0.5, 0.007, 0), ArcadeLook.mat(Color(0.95, 0.75, 0.2), "metal"))
	ArcadeLook.deco(self, "box", Vector3(0.6, 8.0, 30.0), Vector3(center.x + 1.6, 4.0, 0), ArcadeLook.mat(Color(0.55, 0.26, 0.18), "stone", 8.0))
	for z in [-5.5, 5.5]:
		ArcadeLook.deco(self, "box", Vector3(0.1, 1.6, 2.4), Vector3(center.x + 1.25, 2.4, z), ArcadeLook.mat(Color(0.12, 0.12, 0.12), "paint"))
		var l := Label3D.new()
		l.text = "301" if z < 0.0 else "DARDOS"
		l.font_size = 96
		l.pixel_size = 0.008
		l.modulate = Color(1.0, 0.95, 0.85)
		l.rotation_degrees = Vector3(0, -90, 0)
		add_child(l)
		l.global_position = Vector3(center.x + 1.18, 2.4, z)
	# Lamparas de bar sobre la diana (brillan).
	for z in [-1.4, 1.4]:
		ArcadeLook.deco(self, "cyl", Vector3(0.02, 2.0, 0.02), Vector3(center.x - 0.8, 6.0, z), ArcadeLook.mat(Color(0.2, 0.2, 0.2), "metal"))
		ArcadeLook.deco(self, "cyl", Vector3(0.12, 0.25, 0.4), Vector3(center.x - 0.8, 4.9, z), ArcadeLook.mat(Color(0.1, 0.3, 0.15), "metal"))
		ArcadeLook.deco(self, "sphere", Vector3(0.12, 0, 0), Vector3(center.x - 0.8, 4.75, z), ArcadeLook.glow(Color(1.0, 0.92, 0.7), 3.0))
	# Barra y banquetas a un costado.
	ArcadeLook.deco(self, "box", Vector3(9.0, 1.1, 0.8), Vector3(6.0, 0.55, -7.5), ArcadeLook.mat(Color(0.35, 0.2, 0.1), "wood", 3.0))
	for k in 5:
		ArcadeLook.deco(self, "cyl", Vector3(0.22, 0.08, 0.22), Vector3(2.5 + float(k) * 1.8, 0.75, -6.6), ArcadeLook.mat(Color(0.6, 0.1, 0.1), "paint"))
		ArcadeLook.deco(self, "cyl", Vector3(0.04, 0.7, 0.04), Vector3(2.5 + float(k) * 1.8, 0.35, -6.6), ArcadeLook.mat(Color(0.7, 0.7, 0.72), "metal"))

# --- Puntaje ------------------------------------------------------------------------------------------------------------

## Punto de la cara (x a la derecha de quien patea, y arriba; metros desde el centro) -> {score, sector, mult, label}.
func score_at(pt: Vector2) -> Dictionary:
	var r: float = pt.length()
	if r <= float(rings["bull"]):
		return {"score": 50, "sector": 25, "mult": 2, "label": "CENTRO"}
	if r <= float(rings["outer_bull"]):
		return {"score": 25, "sector": 25, "mult": 1, "label": "BULL"}
	if r > radius:
		return {"score": 0, "sector": 0, "mult": 0, "label": "AFUERA"}
	# Angulo desde arriba, creciendo hacia la derecha (+x de la cara).
	var a: float = fposmod(atan2(pt.x, pt.y), TAU)
	var i: int = int(floor(a / (TAU / 20.0) + 0.5)) % 20
	var sector: int = int(ORDER[i])
	var mult: int = 1
	if r >= float(rings["triple_in"]) and r <= float(rings["triple_out"]):
		mult = 3
	elif r >= float(rings["double_in"]):
		mult = 2
	var label: String = ("TRIPLE " if mult == 3 else ("DOBLE " if mult == 2 else "")) + str(sector)
	return {"score": sector * mult, "sector": sector, "mult": mult, "label": label}

## Punto de la cara donde el sector s y el multiplicador m tienen su centro (para la IA y las pruebas).
func aim_face(sector: int, mult: int) -> Vector2:
	if sector == 25:
		return Vector2.ZERO
	var i: int = ORDER.find(sector)
	var a: float = float(i) * TAU / 20.0
	var r: float
	match mult:
		3:
			r = (float(rings["triple_in"]) + float(rings["triple_out"])) * 0.5
		2:
			r = (float(rings["double_in"]) + radius) * 0.5
		_:
			r = (float(rings["triple_out"]) + float(rings["double_in"])) * 0.5
	return Vector2(sin(a) * r, cos(a) * r)

## Punto del mundo para apuntar el centro de la pelota a un punto de la cara.
func face_world(pt: Vector2) -> Vector3:
	return Vector3(center.x - 0.001 - ball.radius, center.y + pt.y, center.z + pt.x)

func _on_ball_body(body: Node) -> void:
	if body != _board or state != State.FLIGHT or _scored_shot == int(shots[side]) + side * 1000:
		return
	if _bv.x < MIN_HIT:
		return
	# Cruce de la trayectoria de antes del choque con el plano de la cara (centro de la pelota un radio por delante).
	var face_x: float = center.x - 0.001 - ball.radius
	var t: float = (face_x - _bp.x) / _bv.x
	var hp: Vector3 = _bp + _bv * clampf(t, -0.05, 0.1)
	var pt := Vector2(hp.z - center.z, hp.y - center.y)
	_scored_shot = int(shots[side]) + side * 1000
	var s: Dictionary = score_at(pt)
	s["point"] = pt
	s["side"] = side
	last_hit = s
	hits_log.append(s)
	_apply(s)
	_popup(String(s["label"]) if int(s["score"]) > 0 else "AFUERA", Vector3(center.x - 0.3, center.y + pt.y, pt.x))

func _apply(s: Dictionary) -> void:
	var sc: int = int(s["score"])
	match rule:
		"301":
			var left: int = int(remaining[side]) - sc
			if left < 0:
				s["bust"] = true
			else:
				remaining[side] = left
				points[side] = int(def.get("start", 301)) - left
		"sector":
			if int(s["sector"]) == int(def.get("sector", 20)):
				points[side] += sc
			else:
				s["off"] = true
		_:
			points[side] += sc
	_refresh_score()

func _popup(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.007
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1.0, 0.85, 0.2)
	l.outline_size = 14
	l.no_depth_test = true
	add_child(l)
	l.global_position = at
	var tw := create_tween()
	tw.tween_property(l, "global_position", at + Vector3.UP * 0.9, 1.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.tween_callback(l.queue_free)

func _level_step(_delta: float) -> void:
	_bp = ball.global_position
	_bv = ball.linear_velocity

func reset_level() -> void:
	var start: int = int(def.get("start", 301))
	remaining = [start, start]
	last_hit = {}
	hits_log.clear()
	_scored_shot = -1
	super.reset_level()

func _ball_spot(s: int) -> Vector3:
	return Vector3(0.0, ball.radius if ball != null else 0.11, 0.0)

func _aim_point(_s: int) -> Vector3:
	return center

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(center.x - 0.5, Vector2(9.0, 28.0), false, 4.0, 4.0, ball.radius)

func frame_points() -> Array:
	return [center + Vector3.UP * (radius + 0.2), center + Vector3.DOWN * (radius + 0.2)]

func _flight_check(_delta: float) -> String:
	if _t > 0.8 and (ball.linear_velocity.length() < SLOW_SPEED or ball.global_position.x < -2.0 or absf(ball.global_position.z) > 12.0 or ball.global_position.x > center.x + 3.0):
		return "listo"
	if _t > 0.5 and int(last_hit.get("side", -1)) == side and _scored_shot == int(shots[side]) + side * 1000 and ball.linear_velocity.x < 0.0:
		return "listo"
	return ""

func _check_winner() -> int:
	if rule == "301":
		if int(remaining[0]) == 0:
			return Side.USER
		return Side.USER if int(shots[0]) >= shots_each else -1
	if int(shots[sides - 1]) < shots_each:
		return -1
	if sides == 1:
		return Side.USER
	return Side.USER if int(points[0]) >= int(points[1]) else Side.CPU

func _on_resolved(s: int, _r: String) -> void:
	var good: bool = int(last_hit.get("side", -1)) == s and int(last_hit.get("score", 0)) >= 20 and not last_hit.has("bust") and not last_hit.has("off")
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if good else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)

func final_score() -> int:
	match rule:
		"301":
			var left: int = int(remaining[0])
			return 600 - left + (maxi(shots_each - int(shots[0]), 0) * 40 if left == 0 else 0)
		"duelo":
			return int(points[0]) + (60 if winner == Side.USER else 0)
	return int(points[0])

func _result_text(_r: String) -> Array:
	if last_hit.is_empty() or int(last_hit.get("side", -1)) != side or (int(last_hit.get("score", 0)) == 0 and _scored_shot != int(shots[side]) + side * 1000):
		return ["Sin tocar la diana", Color(1.0, 0.6, 0.4), ""]
	var t: String = String(last_hit["label"])
	if last_hit.has("bust"):
		return ["¡TE PASASTE!", Color(1.0, 0.5, 0.3), "%s: el tiro no cuenta (quedan %d)" % [t, int(remaining[side])]]
	if last_hit.has("off"):
		return [t, Color(1.0, 0.75, 0.4), "Solo cuenta el %d" % int(def.get("sector", 20))]
	return [t, Color(1.0, 0.85, 0.35), "+%d" % int(last_hit["score"])]

func _refresh_score() -> void:
	match rule:
		"301":
			hud.set_score_text("Quedan %d · tiros %d / %d" % [int(remaining[0]), int(shots[0]), shots_each])
		"duelo":
			hud.set_score_text("Vos %d - %d CPU · tiros %d / %d" % [int(points[0]), int(points[1]), int(shots[0]), shots_each])
		_:
			hud.set_score_text("Puntos %d · tiros %d / %d" % [int(points[0]), int(shots[0]), shots_each])

## IA: con poco error va al triple 20; con mucho, al centro (lo mas seguro); patea con la misma fisica y su error.
func _cpu_intent() -> Dictionary:
	var err: float = cpu_error_deg if cpu_error_deg >= 0.0 else float(CPU_ERROR[clampi(SpSettings.level(), 0, CPU_ERROR.size() - 1)])
	var pt: Vector2 = aim_face(20, 3) if err <= 0.9 else Vector2.ZERO
	return cpu_shot(face_world(pt), 16.0, 0.0, err)
