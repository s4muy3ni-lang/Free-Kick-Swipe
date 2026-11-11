class_name Enceste
extends Minigame
## «Enceste» (primera colección, etapa 7: desafios de habilidad; catalogo #42 «Enceste por rebote»). Un jugador, tiros
## limitados: hay que meter la pelota en el aro. El aro es fisico (esferas en anillo: la pelota pega en el aro y rebota)
## con tablero detras; un enceste cuenta SOLO si el centro de la pelota cruza el plano del aro de arriba hacia abajo
## dentro del anillo (una pelota que sube por el aro o lo roza por fuera no cuenta). Niveles con aro lejano, tapa al
## frente (obliga a usar el tablero), aro que se mueve y dos aros. Puntaje: 100 por enceste, +50 si entra limpio (sin
## tocar el aro), +40 por tiro de sobra al completar; sin encestes no hay puntos ni medalla.
## Básquet (2026-11-11): cada aro puede valer distinto ("value": multiplica los 100 del enceste; los aros mas altos
## valen mas) y con "repeat": true los aros se pueden volver a encestar en cada tiro (ronda de tiros por puntos, hasta
## agotar los tiros). Cancha de basquet (parquet, lineas, tribunas, cartel) como escenario.

const SCENE := "res://scenes/minigames/enceste.tscn"
const RIM_SPHERES := 16
const RIM_TUBE := 0.035
const BASKET_POINTS := 100
const SWISH := 50
const SPARE_SHOT := 40

## Por aro: {body (AnimatableBody3D), center (Vector3 actual), radius, base (Transform3D), move, scored}
var hoops: Array = []
var shots_max: int = 4
var need: int = 1
var baskets: int = 0
var swishes: int = 0
var _rim_touched: bool = false
var _prev_p := Vector3.ZERO
var _scored_now: bool = false
var repeat: bool = false
## Puntos de enceste acumulados (100 x valor del aro, + limpia).
var basket_pts: int = 0

## Plataforma del jugador elevada (estilo arcade comun).
func default_deck() -> float:
	return 3.0

func uses_night_arena() -> bool:
	return true

func game_id() -> String:
	return "enceste"

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 4))
	max_turns = shots_max
	var court := static_box(Vector3(80, 1, 40), Vector3(10, -0.5, 0), Color(0.55, 0.32, 0.18), Vector3.ZERO, 0.6)
	for c in court.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	_build_court()
	_build_tiers()
	for h in def.get("hoops", [{}]):
		_build_hoop(h)
	repeat = bool(def.get("repeat", false))
	need = int(def.get("need", hoops.size())) if not repeat else 999
	ball.body_entered.connect(func(b: Node) -> void:
		for hp in hoops:
			if b == hp["body"]:
				_rim_touched = true)

## Aro: anillo de esferas fisicas, tablero detras (salvo "board": false), tapa al frente opcional ("lid": alto en m) y
## red (solo visual).
func _build_hoop(h: Dictionary) -> void:
	var pos: Vector3 = BotonCaida._vec(h.get("pos", [14.0, 3.05, 0.0]))
	var r: float = float(h.get("radius", 0.34))
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = Ball.LAYER_WORLD
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.55
	pm.friction = 0.5
	body.physics_material_override = pm
	# Color del aro segun lo que vale (referencia: azul 10, rojo 15, amarillo 20).
	var pts: int = int(h.get("points", 100 * int(h.get("value", 1))))
	var rim_c: Color = Color(1.0, 0.45, 0.1)
	if h.has("points"):
		rim_c = Color(1.0, 0.82, 0.15) if pts >= 200 else (Color(0.95, 0.2, 0.2) if pts >= 150 else Color(0.2, 0.5, 1.0))
	var rim_mat := color_mat(rim_c, 0.5)
	for i in RIM_SPHERES:
		var a: float = TAU * float(i) / float(RIM_SPHERES)
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = RIM_TUBE
		cs.shape = sp
		cs.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		body.add_child(cs)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - RIM_TUBE
	tm.outer_radius = r + RIM_TUBE
	ring.mesh = tm
	ring.material_override = rim_mat
	body.add_child(ring)
	if bool(h.get("board", true)):
		var bcs := CollisionShape3D.new()
		var bb := BoxShape3D.new()
		bb.size = Vector3(0.06, 1.1, 1.8)
		bcs.shape = bb
		bcs.position = Vector3(r + 0.18, 0.45, 0.0)
		body.add_child(bcs)
		var bmi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bb.size
		bmi.mesh = bm
		bmi.position = bcs.position
		bmi.material_override = color_mat(Color(0.95, 0.95, 0.98))
		body.add_child(bmi)
		# Cuadro del tablero (referencia para el rebote).
		var sq := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.02, 0.45, 0.6)
		sq.mesh = sm
		sq.position = Vector3(r + 0.145, 0.3, 0.0)
		sq.material_override = color_mat(Color(0.9, 0.2, 0.15))
		body.add_child(sq)
	var lid: float = float(h.get("lid", 0.0))
	if lid > 0.0:
		var lcs := CollisionShape3D.new()
		var lb := BoxShape3D.new()
		lb.size = Vector3(0.06, lid, r * 2.6)
		lcs.shape = lb
		lcs.position = Vector3(-r - 0.06, lid * 0.5, 0.0)
		body.add_child(lcs)
		var lmi := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = lb.size
		lmi.mesh = lm
		lmi.position = lcs.position
		var lmat := color_mat(Color(0.4, 0.75, 1.0))
		lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lmat.albedo_color.a = 0.55
		lmi.material_override = lmat
		body.add_child(lmi)
	# Red (visual) y poste.
	var net := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = r
	nm.bottom_radius = r * 0.7
	nm.height = 0.45
	nm.cap_top = false
	nm.cap_bottom = false
	net.mesh = nm
	var nmat := color_mat(Color(1, 1, 1))
	nmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nmat.albedo_color.a = 0.35
	nmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	net.material_override = nmat
	net.position = Vector3(0, -0.23, 0)
	body.add_child(net)
	add_child(body)
	body.global_position = pos
	var post := MeshInstance3D.new()
	var pmh := CylinderMesh.new()
	pmh.top_radius = 0.08
	pmh.bottom_radius = 0.1
	pmh.height = pos.y + 0.4
	post.mesh = pmh
	post.material_override = color_mat(Color(0.3, 0.32, 0.38))
	add_child(post)
	post.global_position = Vector3(pos.x + r + 0.5, (pos.y + 0.4) * 0.5, pos.z)
	hoops.append({"body": body, "center": pos, "radius": r, "base": body.global_transform, "move": h.get("move", {}),
		"scored": false, "post": post, "value": int(h.get("value", 1)), "points": int(h.get("points", BASKET_POINTS * int(h.get("value", 1))))})
	if h.has("points") or int(h.get("value", 1)) > 1:
		var vl := Label3D.new()
		vl.text = (str(int(h["points"]) / 10)) if h.has("points") else ("x%d" % int(h.get("value", 1)))
		vl.font_size = 96
		vl.pixel_size = 0.006
		vl.modulate = Color(1.0, 0.85, 0.3)
		vl.outline_size = 10
		vl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(vl)
		vl.global_position = pos + Vector3(0.0, 0.85, 0)

## Encuadre: cada aro con su tablero.
func frame_points() -> Array:
	var out: Array = []
	for h in hoops:
		out.append((h["center"] as Vector3) + Vector3.UP * 1.0)
		out.append((h["center"] as Vector3) + Vector3.DOWN * 0.4)
	return out

func _ball_spot(_s: int) -> Vector3:
	return (Vector3(0.0, ball.radius if ball != null else 0.11, 0.0)) + Vector3.UP * deck_y()

func _aim_point(_s: int) -> Vector3:
	var c := Vector3.ZERO
	for h in hoops:
		c += h["center"]
	return c / float(maxi(hoops.size(), 1))

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(_aim_point(0).x, Vector2(9.0, 26.0), false, 4.0, 5.0, ball.radius)

func _level_step(_delta: float) -> void:
	for h in hoops:
		var mv: Dictionary = h["move"]
		if mv.is_empty():
			continue
		var base: Transform3D = h["base"]
		var axis: Vector3 = BotonCaida._vec(mv.get("axis", [0, 0, 1])).normalized()
		var off: Vector3 = axis * float(mv.get("amp", 1.5)) * sin(level_time * float(mv.get("speed", 1.0)))
		(h["body"] as Node3D).global_position = base.origin + off
		var post: Node3D = h["post"]
		post.global_position = Vector3(base.origin.x + off.x + float(h["radius"]) + 0.5, post.global_position.y, base.origin.z + off.z)
		h["center"] = base.origin + off

func reset_level() -> void:
	baskets = 0
	swishes = 0
	basket_pts = 0
	for h in hoops:
		h["scored"] = false
		(h["body"] as Node3D).global_transform = h["base"]
		h["center"] = (h["base"] as Transform3D).origin
	super.reset_level()

func _start_turn() -> void:
	_rim_touched = false
	_scored_now = false
	if repeat:
		for h in hoops:
			h["scored"] = false
	super._start_turn()
	_prev_p = _ball_spot(0)

## Enceste: el centro de la pelota cruza el plano del aro bajando, dentro del anillo (con el margen del tubo del aro).
func _flight_check(_delta: float) -> String:
	var p: Vector3 = ball.global_position
	for h in hoops:
		if bool(h["scored"]):
			continue
		var c: Vector3 = h["center"]
		if _prev_p.y > c.y and p.y <= c.y:
			var u: float = (_prev_p.y - c.y) / maxf(_prev_p.y - p.y, 1e-6)
			var q: Vector3 = _prev_p.lerp(p, u)
			if Vector2(q.x - c.x, q.z - c.z).length() <= float(h["radius"]) - RIM_TUBE:
				h["scored"] = true
				_scored_now = true
				baskets += 1
				basket_pts += int(h.get("points", BASKET_POINTS * int(h.get("value", 1))))
				if not _rim_touched:
					swishes += 1
					basket_pts += SWISH
	_prev_p = p
	if _scored_now and (baskets >= need or _t > 0.4):
		return "canasta"
	if p.x > _aim_point(0).x + 8.0:
		return "afuera"
	return ""

func _on_resolved(s: int, r: String) -> void:
	points[0] = baskets
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if r == "canasta" else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)
	if r == "canasta" and not fast:
		cam.shake(0.3, 0.5)

func _check_winner() -> int:
	return Side.USER if baskets >= need or int(shots[0]) >= shots_max else -1

func final_score() -> int:
	if baskets == 0:
		return 0
	var s: int = basket_pts
	if baskets >= need:
		s += maxi(shots_max - int(shots[0]), 0) * SPARE_SHOT
	return s

func _report_achievements(w: int, medal: int) -> void:
	super._report_achievements(w, medal)
	if baskets > 0:
		Achievements.event(&"enceste", baskets)
	if swishes > 0:
		Achievements.event(&"enceste_limpio", swishes)

func _result_text(r: String) -> Array:
	var sub: String = ("Encestes %d · %d puntos · tiros %d de %d" % [baskets, basket_pts, int(shots[0]), shots_max]) if repeat else ("Encestes %d de %d · tiros %d de %d" % [baskets, need, int(shots[0]), shots_max])
	if r == "canasta":
		return ["¡LIMPIA!" if not _rim_touched else "¡ADENTRO!", Color(0.35, 1.0, 0.45), sub]
	return ["Afuera" if not _rim_touched else "Tocó el aro", Color(1.0, 0.75, 0.4), sub]

func _refresh_score() -> void:
	if repeat:
		hud.set_score_text("Puntos %d · encestes %d · tiros %d / %d" % [basket_pts, baskets, int(shots[0]), shots_max])
	else:
		hud.set_score_text("Encestes %d / %d · tiros %d / %d" % [baskets, need, int(shots[0]), shots_max])

## Cancha: parquet, lineas, tribunas y cartel (decoracion sin colision).
## Gradas (nivel "tiers": [[x0, x1, alto], ...]): escalones fisicos rosas con borde dorado y flechas, donde se apoyan
## los aros (referencia del usuario).
func _build_tiers() -> void:
	for t in def.get("tiers", []):
		var x0: float = float(t[0])
		var x1: float = float(t[1])
		var top: float = float(t[2])
		var w: float = float(def.get("tier_w", 9.0))
		var b := static_box(Vector3(x1 - x0, top, w), Vector3((x0 + x1) * 0.5, top * 0.5, 0), Color(0.8, 0.3, 0.5), Vector3.ZERO, 0.4)
		for c in b.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.72, 0.26, 0.46), "paint", 2.0)
		ArcadeLook.deco(self, "box", Vector3(0.12, 0.08, w + 0.05), Vector3(x0 + 0.02, top + 0.01, 0), ArcadeLook.glow(ArcadeLook.RAIL_GOLD, 1.6))
		for sz in [-1.0, 1.0]:
			ArcadeLook.deco(self, "sphere", Vector3(0.12, 0, 0), Vector3(x0 + 0.1, top + 0.15, sz * (w * 0.5 - 0.2)), ArcadeLook.glow(Color(1.0, 0.8, 0.4), 3.0))
			for k in 2:
				ArcadeLook.deco(self, "box", Vector3(0.1, 0.012, 0.6), Vector3(x0 - 0.05, top * (0.35 + float(k) * 0.3), sz * (w * 0.5 - 0.6)), ArcadeLook.mat(Color(1.0, 0.8, 0.1), "paint"), Vector3(0, 0, PI * 0.5))

func _build_court() -> void:
	ArcadeLook.light(self, Color(1.0, 0.95, 0.88), 1.0, Color(0.12, 0.12, 0.2), Color(0.45, 0.4, 0.45), 0.8, Vector3(-62, -30, 0))
	ArcadeLook.ground(self, Vector2(160, 120), Vector3(10, -0.002, 0), Color(0.2, 0.2, 0.26), "stone", 40.0)
	ArcadeLook.ground(self, Vector2(32, 17), Vector3(10, 0, 0), Color(0.86, 0.6, 0.34), "wood", 8.0)
	var line := ArcadeLook.mat(Color(0.97, 0.97, 0.97), "paint")
	for z in [-8.4, 8.4]:
		ArcadeLook.deco(self, "box", Vector3(32, 0.004, 0.08), Vector3(10, 0.006, z), line)
	ArcadeLook.deco(self, "box", Vector3(0.08, 0.004, 16.8), Vector3(10, 0.006, 0), line)
	ArcadeLook.deco(self, "cyl", Vector3(1.8, 0.004, 1.8), Vector3(10, 0.005, 0), ArcadeLook.mat(Color(0.75, 0.2, 0.15), "paint"))
	for z in [-12.0, 12.0]:
		for row in 4:
			ArcadeLook.deco(self, "box", Vector3(34, 0.5, 1.2), Vector3(10, 0.25 + float(row) * 0.5, z + signf(z) * float(row) * 1.2), ArcadeLook.mat(Color(0.2, 0.22, 0.3), "stone", 4.0))
			for k in 16:
				var cc: Color = [Color(0.9, 0.2, 0.2), Color(0.2, 0.45, 0.95), Color(0.95, 0.85, 0.2), Color(0.9, 0.9, 0.9)][(k + row) % 4]
				ArcadeLook.deco(self, "box", Vector3(0.35, 0.55, 0.3), Vector3(-5.0 + float(k) * 2.0 + float(row % 2) * 0.6, 0.78 + float(row) * 0.5, z + signf(z) * float(row) * 1.2), ArcadeLook.mat(cc, "paint"))
	ArcadeLook.billboard(self, "BÁSQUET", Vector3(28.0, 7.2, 0), 6.0, 1.1, Color(0.35, 0.12, 0.05), Color(1.0, 0.85, 0.3))
