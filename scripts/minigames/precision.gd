class_name Precision
extends Minigame
## «Fútbol de precisión» (DESAFIOS DE ARCO). Un arco gigante dividido en sectores con puntaje (por defecto: esquinas de
## arriba 10, arriba al medio 5, medio 3, abajo 1). Cuenta el sector por donde la pelota CRUZA la linea del arco (centro
## de la pelota pasando el plano entre postes y bajo el travesaño, yendo hacia adentro). Un arquero de carton (cuerpo
## cinematico con colision) va y viene sobre un riel: si la pelota lo toca, rebota de verdad y ese tiro no entra.
## Postes y travesaño son cuerpos estaticos redondos (la pelota puede pegar en el palo); una red estatica detras la frena.
##
## Niveles en minigames.json ("precision"): distance, width, height, grid (filas de arriba hacia abajo, puntos por
## columna), keeper {w, h, amp, speed} (opcional), shots.

const SCENE := "res://scenes/minigames/precision.tscn"
const POST_R := 0.08
const DEFAULT_GRID := [[10, 5, 3, 5, 10], [3, 2, 1, 2, 3], [1, 1, 0, 1, 1]]

var goal_x: float = 18.0
var width: float = 9.0
var height: float = 3.6
var grid: Array = DEFAULT_GRID
var shots_max: int = 5
var keeper: AnimatableBody3D = null
var keeper_mover: Dictionary = {}
var last_hit: Dictionary = {}
var hits_log: Array = []
var _crossed: bool = false
var _prev_p := Vector3.ZERO
var blocked: bool = false

func game_id() -> String:
	return "precision"

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 5))
	max_turns = shots_max
	goal_x = float(def.get("distance", 18.0))
	width = float(def.get("width", 9.0))
	height = float(def.get("height", 3.6))
	grid = def.get("grid", DEFAULT_GRID)
	var ground := static_box(Vector3(120, 1, 80), Vector3(goal_x * 0.5, -0.5, 0), Color(0.2, 0.5, 0.2), Vector3.ZERO, 0.45)
	for c in ground.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	ArcadeLook.light(self, Color(1.0, 0.95, 0.85), 1.1, Color(0.2, 0.4, 0.8), Color(0.7, 0.78, 0.9), 0.8)
	ArcadeLook.grass(self, Vector2(160, 120), Vector3(goal_x * 0.5, 0, 0), 26)
	_build_goal()
	var kd: Dictionary = def.get("keeper", {})
	if not kd.is_empty():
		_build_keeper(kd)
	_build_stage()

func _build_goal() -> void:
	var white := ArcadeLook.mat(Color(0.97, 0.97, 0.97), "paint")
	for z in [-width * 0.5 - POST_R, width * 0.5 + POST_R]:
		var post := StaticBody3D.new()
		post.collision_layer = Ball.LAYER_WORLD
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.6
		post.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = POST_R
		cy.height = height + POST_R
		cs.shape = cy
		post.add_child(cs)
		ArcadeLook.part(post, "cyl", Vector3(POST_R, height + POST_R, POST_R), Vector3.ZERO, white)
		add_child(post)
		post.global_position = Vector3(goal_x, (height + POST_R) * 0.5, z)
	var bar := StaticBody3D.new()
	bar.collision_layer = Ball.LAYER_WORLD
	var pm2 := PhysicsMaterial.new()
	pm2.bounce = 0.6
	bar.physics_material_override = pm2
	var cs2 := CollisionShape3D.new()
	var cy2 := CylinderShape3D.new()
	cy2.radius = POST_R
	cy2.height = width + POST_R * 4.0
	cs2.shape = cy2
	cs2.rotation_degrees = Vector3(90, 0, 0)
	bar.add_child(cs2)
	ArcadeLook.part(bar, "cyl", Vector3(POST_R, width + POST_R * 4.0, POST_R), Vector3.ZERO, white, Vector3(PI * 0.5, 0, 0))
	add_child(bar)
	bar.global_position = Vector3(goal_x, height + POST_R, 0)
	# Red: un panel estatico detras (frena la pelota) con trama clara, y techo/laterales visuales.
	var net := static_box(Vector3(0.1, height + 0.3, width + 0.6), Vector3(goal_x + 2.0, (height + 0.3) * 0.5, 0), Color(0.9, 0.9, 0.9), Vector3.ZERO, 0.05)
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(0.95, 0.95, 0.95, 0.35)
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nm.albedo_texture = ArcadeLook.noise_tex("fine")
	nm.uv1_scale = Vector3(12, 12, 12)
	for c in net.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = nm
	# Sectores: paneles translucidos de color en el plano del arco (solo visuales) con su puntaje.
	var rows: int = grid.size()
	for r in rows:
		var row: Array = grid[r]
		var cols: int = row.size()
		for c in cols:
			var pts: int = int(row[c])
			var cell_w: float = width / float(cols)
			var cell_h: float = height / float(rows)
			var center := Vector3(goal_x + 0.02, height - (float(r) + 0.5) * cell_h, -width * 0.5 + (float(c) + 0.5) * cell_w)
			var col: Color = Color(1.0, 0.8, 0.1, 0.45) if pts >= 10 else (Color(0.9, 0.2, 0.15, 0.4) if pts >= 5 else (Color(0.2, 0.5, 0.95, 0.35) if pts >= 2 else Color(1, 1, 1, 0.18)))
			var m := StandardMaterial3D.new()
			m.albedo_color = col
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			ArcadeLook.deco(self, "box", Vector3(0.01, cell_h - 0.06, cell_w - 0.06), center, m)
			var l := Label3D.new()
			l.text = str(pts)
			l.font_size = 96
			l.pixel_size = minf(cell_h, cell_w) * 0.004
			l.modulate = Color(1, 1, 1, 0.85)
			l.outline_size = 10
			l.rotation_degrees = Vector3(0, -90, 0)
			add_child(l)
			l.global_position = center + Vector3(0.05, 0, 0)

func _build_keeper(kd: Dictionary) -> void:
	var w: float = float(kd.get("w", 1.3))
	var h: float = float(kd.get("h", 2.0))
	keeper = AnimatableBody3D.new()
	keeper.sync_to_physics = false
	keeper.collision_layer = Ball.LAYER_WORLD
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.4
	keeper.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.06, h, w)
	cs.shape = bs
	cs.position = Vector3(0, h * 0.5, 0)
	keeper.add_child(cs)
	# Carton recortado: cuerpo, camiseta, brazos abiertos, guantes y cara.
	var card := ArcadeLook.mat(Color(0.72, 0.56, 0.36), "wood")
	ArcadeLook.part(keeper, "box", Vector3(0.06, h, w), Vector3(0, h * 0.5, 0), card)
	ArcadeLook.part(keeper, "box", Vector3(0.065, h * 0.38, w * 0.55), Vector3(-0.005, h * 0.6, 0), ArcadeLook.mat(Color(0.95, 0.8, 0.1), "paint"))
	ArcadeLook.part(keeper, "box", Vector3(0.065, h * 0.3, w * 0.5), Vector3(-0.005, h * 0.27, 0), ArcadeLook.mat(Color(0.1, 0.1, 0.12), "paint"))
	ArcadeLook.part(keeper, "cyl", Vector3(w * 0.16, 0.07, w * 0.16), Vector3(-0.01, h * 0.88, 0), ArcadeLook.mat(Color(0.9, 0.72, 0.58), "paint"), Vector3(0, 0, PI * 0.5))
	for sz in [-1.0, 1.0]:
		ArcadeLook.part(keeper, "cyl", Vector3(0.09, 0.07, 0.09), Vector3(-0.01, h * 0.82, sz * w * 0.42), ArcadeLook.mat(Color(0.2, 0.8, 0.3), "plastic"), Vector3(0, 0, PI * 0.5))
	add_child(keeper)
	keeper.global_position = Vector3(goal_x - 0.5, 0, 0)
	keeper_mover = add_mover(keeper, Vector3(0, 0, 1), float(kd.get("amp", 2.5)), float(kd.get("speed", 0.9)), float(kd.get("phase", 0.0)))
	# Riel visual.
	ArcadeLook.deco(self, "box", Vector3(0.12, 0.05, (float(kd.get("amp", 2.5)) + w * 0.5) * 2.0), Vector3(goal_x - 0.5, 0.025, 0), ArcadeLook.mat(Color(0.3, 0.3, 0.34), "metal"))

func _build_stage() -> void:
	for z in [-16.0, 16.0]:
		for row in 4:
			ArcadeLook.deco(self, "box", Vector3(goal_x + 14.0, 0.5, 1.2), Vector3(goal_x * 0.5 + 2.0, 0.25 + float(row) * 0.5, z + signf(z) * float(row) * 1.2), ArcadeLook.mat(Color(0.22, 0.24, 0.3), "stone", 4.0))
			for k in 14:
				var cc: Color = [Color(0.9, 0.2, 0.2), Color(0.2, 0.45, 0.95), Color(0.95, 0.85, 0.2), Color(0.9, 0.9, 0.9)][(k + row) % 4]
				ArcadeLook.deco(self, "box", Vector3(0.35, 0.55, 0.3), Vector3(-4.0 + float(k) * (goal_x + 12.0) / 13.0 + float(row % 2) * 0.5, 0.78 + float(row) * 0.5, z + signf(z) * float(row) * 1.2), ArcadeLook.mat(cc, "paint"))
	for k in 6:
		ArcadeLook.deco(self, "box", Vector3(0.12, 0.9, 3.4), Vector3(goal_x + 4.5, 0.45, -8.5 + float(k) * 3.4), ArcadeLook.mat([Color(0.1, 0.3, 0.8), Color(0.95, 0.95, 0.95), Color(0.9, 0.15, 0.15)][k % 3], "paint"))
	ArcadeLook.billboard(self, "PRECISIÓN", Vector3(goal_x + 6.0, height + 1.2, 0), 6.0, 1.0)

# --- Reglas -------------------------------------------------------------------------------------------------------------

## Puntos del sector en el punto (z, y) del plano del arco (-1 si esta afuera del arco).
func sector_points(z: float, y: float) -> int:
	if absf(z) > width * 0.5 or y > height or y < 0.0:
		return -1
	var rows: int = grid.size()
	var r: int = clampi(int((height - y) / (height / float(rows))), 0, rows - 1)
	var row: Array = grid[r]
	var c: int = clampi(int((z + width * 0.5) / (width / float(row.size()))), 0, row.size() - 1)
	return int(row[c])

## Centro del sector (fila, columna) en el plano del arco.
func sector_center(r: int, c: int) -> Vector3:
	var row: Array = grid[r]
	return Vector3(goal_x, height - (float(r) + 0.5) * height / float(grid.size()), -width * 0.5 + (float(c) + 0.5) * width / float(row.size()))

func _level_step(_delta: float) -> void:
	var p: Vector3 = ball.global_position
	if state == State.FLIGHT and not _crossed and _prev_p.x < goal_x and p.x >= goal_x and ball.linear_velocity.x > 0.0:
		# Punto exacto del cruce (interpolado entre los dos pasos).
		var t: float = (goal_x - _prev_p.x) / maxf(p.x - _prev_p.x, 0.0001)
		var q: Vector3 = _prev_p.lerp(p, t)
		_crossed = true
		var pts: int = sector_points(q.z, q.y)
		if pts >= 0 and absf(q.z) <= width * 0.5 - ball.radius * 0.5 and q.y <= height:
			last_hit = {"points": pts, "point": Vector2(q.z, q.y), "shot": int(shots[0])}
			hits_log.append(last_hit)
			points[0] += pts
			_refresh_score()
	_prev_p = p

func _on_contact(entry: Dictionary) -> void:
	super._on_contact(entry)
	_crossed = false
	blocked = false
	_prev_p = ball.global_position

func _flight_check(_delta: float) -> String:
	if _crossed:
		# Cruzo la linea: si fue adentro del arco es gol (se espera un instante a que la red la frene).
		if int(last_hit.get("shot", -1)) == int(shots[0]):
			return "gol" if _t > 0.25 else ""
		return "afuera"
	if ball.global_position.x < goal_x - 0.6 and ball.linear_velocity.x < 0.0 and _t > 0.4:
		return "atajada" if keeper != null and absf(ball.global_position.z - keeper.global_position.z) < 2.0 else "afuera"
	if _t > 0.8 and ball.linear_velocity.length() < SLOW_SPEED:
		return "afuera"
	return ""

func _check_winner() -> int:
	return Side.USER if int(shots[0]) >= shots_max else -1

func _on_resolved(s: int, r: String) -> void:
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if r == "gol" and int(last_hit.get("points", 0)) >= 3 else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)

func final_score() -> int:
	return int(points[0])

func reset_level() -> void:
	last_hit = {}
	hits_log.clear()
	_crossed = false
	super.reset_level()

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0, ball.radius if ball != null else 0.11, 0)

func _aim_point(_s: int) -> Vector3:
	return Vector3(goal_x, height * 0.5, 0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(goal_x, Vector2(9.0, 30.0), false, width * 0.5, height, ball.radius)

func frame_points() -> Array:
	return [Vector3(goal_x, height, width * 0.5), Vector3(goal_x, height, -width * 0.5)]

func _result_text(r: String) -> Array:
	match r:
		"gol":
			return ["+%d" % int(last_hit.get("points", 0)), Color(0.35, 1.0, 0.45) if int(last_hit.get("points", 0)) >= 5 else Color(1.0, 0.85, 0.35), "Total %d" % int(points[0])]
		"atajada":
			return ["¡ATAJÓ EL CARTÓN!", Color(1.0, 0.5, 0.4), ""]
	return ["Afuera", Color(1.0, 0.6, 0.4), ""]

func _refresh_score() -> void:
	hud.set_score_text("Puntos %d · tiros %d / %d" % [int(points[0]), int(shots[0]), shots_max])
