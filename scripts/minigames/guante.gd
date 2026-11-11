class_name GuanteDuel
extends Minigame
## «Duelo del guante» (DUELOS, por turnos contra la IA), EN RELEVO (pedido del usuario): los dos jugadores en la MISMA
## plataforma. El que patea se para a la izquierda con la pelota; el otro, a la derecha, frente al guante (un piston con
## resorte montado detras de su lugar). Al frente, lejos, un panel con tres botones:
##  - grande: facil de acertar, carga poco (0,20 por defecto);
##  - mediano: (0,34);
##  - chico: dificil, carga mucho (0,55).
## Cada boton apretado por un golpe REAL de la pelota (impacto contra su cara mayor que PRESS_SPEED) suma carga a la barra
## del que pateo; la barra de cada uno persiste entre turnos y no pasa de 100 % (lo que sobra se pierde: el chico no
## siempre conviene). Con la carga el guante se retrae como un resorte que se comprime; al 100 % se suelta: el piston es
## una masa con resorte (x'' = w² (L - x) - c x') que viaja de verdad, choca con el cuerpo del que espera (consulta de
## forma barrida, sin tuneles) y le transmite el impulso del choque (masas y restitucion): sale despedido lejos, en vuelo
## balistico, y sale de escena. Si erra o no completa la barra, cambia el turno (relevo de lugares).
## La IA elige boton por valor esperado (probabilidad de acertar con su error x carga util + premio si completa) y patea
## con la misma fisica. Nunca carga sin apretar un boton. El boton marcado por el usuario solo se resalta.
##
## Niveles en minigames.json ("guante"): gap (distancia al panel), punches, buttons [{size, r, gain, z, y, move?}].

const SCENE := "res://scenes/minigames/guante.tscn"
const PRESS_SPEED := 2.5
const CAP_DEPTH := 0.12
## Lugar de la pelota del que patea (izquierda de la plataforma) y del que espera frente al guante (derecha).
const KICK_SPOT := Vector3(0.0, 0.0, -1.9)
const WAIT_SPOT := Vector3(-2.0, 0.0, 3.2)
## El piston esta PUNCH_REACH m detras del que espera, a la altura del pecho, y empuja hacia +X (lo tira lejos, hacia
## adelante de la plataforma).
const PUNCH_REACH := 2.4
const PUNCH_Y := 1.25
const GLOVE_R := 0.26
const RETRACT := 0.5
const SPRING_L := 2.6
const SPRING_W2 := 22.0
const SPRING_C := 0.6
## Piston pesado (pedido: «debe salir con mucha fuerza»): masas del guante y del jugador y restitucion; el que recibe
## sale con la velocidad del choque y un poco hacia arriba (lo levanta), y vuela con gravedad.
const GLOVE_MASS := 140.0
const BODY_MASS := 75.0
const RESTITUTION := 0.3
const LIFT := 0.45
const HURT_LAYER := 512
const CPU_ERROR := [1.8, 1.3, 1.0, 0.75, 0.55]
const DEFAULT_BUTTONS := [
	{"size": "grande", "r": 0.55, "gain": 0.2, "z": -1.4, "y": 1.6},
	{"size": "mediano", "r": 0.36, "gain": 0.34, "z": 0.0, "y": 1.6},
	{"size": "chico", "r": 0.2, "gain": 0.55, "z": 1.3, "y": 1.6}]

var panel_x: float = 16.0
## Botones del panel: {cap, mesh, r, gain, size, label, base, mover?}
var buttons: Array = []
## Piston: {glove, rod, coils, x, v, mode, dir, rest, back, hit_speed}
var glove: Dictionary = {}
var charge: Array = [0.0, 0.0]
var hurtbox: AnimatableBody3D
var selected: int = 0
var pressed_btn: int = -1
var landed: bool = false
var cpu_error_deg: float = -1.0
var last_choice: Dictionary = {}
## Vuelo del que recibio el golpe: velocidad (m/s) mientras vuela; oculto al salir de escena.
var _fly_v: Array = [Vector3.ZERO, Vector3.ZERO]
var _fly_t: Array = [-1.0, -1.0]
var _press_t: float = 0.0
var _bars: Array = []
var _bar_labels: Array = []

func shows_both_players() -> bool:
	return true

func has_player_deck() -> bool:
	return false

func uses_night_arena() -> bool:
	return true

func game_id() -> String:
	return "guante"

func _build_level() -> void:
	sides = 2
	max_turns = int(def.get("max_turns", 40))
	panel_x = float(def.get("gap", 16.0))
	var ground := static_box(Vector3(80, 1, 40), Vector3(panel_x * 0.5, -0.5, 0), Color(0.12, 0.2, 0.42), Vector3.ZERO, 0.5)
	for c in ground.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	_build_platform()
	_build_panel()
	_build_glove()
	hurtbox = AnimatableBody3D.new()
	hurtbox.sync_to_physics = false
	hurtbox.collision_layer = HURT_LAYER
	hurtbox.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	cs.shape = cap
	hurtbox.add_child(cs)
	add_child(hurtbox)
	hurtbox.global_position = WAIT_SPOT + Vector3.UP * 0.9
	ball.body_entered.connect(_on_ball_body)

## Plataforma compartida (estilo de las referencias): cubierta rosa, barandas doradas, flechas y el lugar de cada uno.
func _build_platform() -> void:
	var cx: float = -1.8
	ArcadeLook.deco(self, "box", Vector3(8.0, 0.04, 11.0), Vector3(cx, 0.02, 0.6), ArcadeLook.mat(ArcadeLook.DECK_PINK, "paint", 3.0))
	ArcadeLook.deco(self, "box", Vector3(0.12, 0.06, 11.0), Vector3(cx + 4.0, 0.05, 0.6), ArcadeLook.glow(ArcadeLook.RAIL_GOLD, 1.6))
	for sz in [-1.0, 1.0]:
		var z: float = 0.6 + sz * 5.4
		ArcadeLook.deco(self, "box", Vector3(7.4, 0.08, 0.08), Vector3(cx, 0.9, z), ArcadeLook.mat(ArcadeLook.RAIL_GOLD, "metal"))
		for k in 4:
			var x: float = cx - 3.5 + float(k) * 2.33
			ArcadeLook.deco(self, "box", Vector3(0.1, 0.9, 0.1), Vector3(x, 0.45, z), ArcadeLook.mat(ArcadeLook.RAIL_GOLD, "metal"))
			ArcadeLook.deco(self, "sphere", Vector3(0.08, 0, 0), Vector3(x, 0.98, z), ArcadeLook.glow(Color(1.0, 0.85, 0.45), 2.5))
	# Aro de luz en la pelota y circulo marcado frente al guante.
	for pz in [[KICK_SPOT, Color(0.35, 0.8, 1.0)], [WAIT_SPOT, Color(1.0, 0.35, 0.3)]]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.52
		tm.rings = 24
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = ArcadeLook.glow(pz[1], 2.5)
		ring.scale = Vector3(1, 0.2, 1)
		add_child(ring)
		ring.global_position = (pz[0] as Vector3) + Vector3.UP * 0.05
	for k in 2:
		for sgn in [-1.0, 1.0]:
			ArcadeLook.deco(self, "box", Vector3(0.14, 0.012, 0.7), Vector3(-0.6 + float(k) * 0.6, 0.05, 0.6 + sgn * 0.25), ArcadeLook.mat(Color(1.0, 0.8, 0.1), "paint"), Vector3(0, sgn * 0.7, 0))
	# Camino de luces hacia el panel.
	ArcadeLook.runway(self, 2.4, panel_x - 1.0, 5.0)

## Panel de botones al fondo (mira hacia la plataforma) con las barras de los dos jugadores arriba.
func _build_panel() -> void:
	var cab := static_box(Vector3(0.6, 3.2, 5.0), Vector3(panel_x + 0.3, 1.6, 0), Color(0.2, 0.2, 0.24), Vector3.ZERO, 0.3)
	for c in cab.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.22, 0.23, 0.27), "metal")
	ArcadeLook.deco(self, "box", Vector3(0.04, 3.0, 4.8), Vector3(panel_x - 0.01, 1.6, 0), ArcadeLook.mat(Color(0.3, 0.1, 0.45), "paint"))
	for k in 12:
		ArcadeLook.deco(self, "sphere", Vector3(0.07, 0, 0), Vector3(panel_x - 0.05, 3.2, -2.3 + float(k) * 0.42), ArcadeLook.glow(Color(1.0, 0.85, 0.4), 2.5))
	var bdefs: Array = def.get("buttons", DEFAULT_BUTTONS)
	var colors: Array = [Color(0.2, 0.85, 0.35), Color(1.0, 0.75, 0.1), Color(0.95, 0.2, 0.15)]
	for i in bdefs.size():
		var bd: Dictionary = bdefs[i]
		var r: float = float(bd.get("r", 0.36))
		var pos := Vector3(panel_x - CAP_DEPTH * 0.5 - 0.02, float(bd.get("y", 1.6)), float(bd.get("z", 0.0)))
		var cap := AnimatableBody3D.new()
		cap.sync_to_physics = false
		cap.collision_layer = Ball.LAYER_WORLD
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.35
		cap.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = CAP_DEPTH
		cs.shape = cyl
		cap.add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = CAP_DEPTH
		cm.radial_segments = 24
		mi.mesh = cm
		mi.material_override = ArcadeLook.glow(colors[mini(i, 2)], 0.6)
		cap.add_child(mi)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r
		tm.outer_radius = r + 0.07
		tm.rings = 24
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = ArcadeLook.mat(Color(0.85, 0.86, 0.9), "metal")
		cap.add_child(ring)
		add_child(cap)
		cap.global_transform = Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), pos)
		var lab := Label3D.new()
		lab.text = "+%d%%" % int(round(float(bd.get("gain", 0.2)) * 100.0))
		lab.font_size = 64
		lab.pixel_size = 0.006
		lab.outline_size = 8
		lab.double_sided = false
		lab.rotation_degrees = Vector3(0, -90, 0)
		add_child(lab)
		lab.global_position = pos + Vector3(-0.06, -r - 0.22, 0)
		var b := {"cap": cap, "mesh": mi, "r": r, "gain": float(bd.get("gain", 0.2)), "size": String(bd.get("size", "")),
			"label": lab, "base": cap.global_transform}
		var mv: Dictionary = bd.get("move", {})
		if not mv.is_empty():
			b["mover"] = add_mover(cap, BotonCaida._vec(mv.get("axis", [0, 0, 1])), float(mv.get("amp", 0.4)), float(mv.get("speed", 1.2)), float(mv.get("phase", 0.0)))
			var lm: Dictionary = add_mover(lab, BotonCaida._vec(mv.get("axis", [0, 0, 1])), float(mv.get("amp", 0.4)), float(mv.get("speed", 1.2)), float(mv.get("phase", 0.0)))
			lm["base"] = lab.global_transform
		buttons.append(b)
	# Barras de carga de los dos jugadores sobre el panel (azul vos, rojo la CPU).
	for s in 2:
		var y: float = 2.75 - float(s) * 0.38
		ArcadeLook.deco(self, "box", Vector3(0.05, 0.26, 3.6), Vector3(panel_x - 0.04, y, 0.3), ArcadeLook.mat(Color(0.06, 0.06, 0.08), "paint"))
		var fill := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.06, 0.2, 3.5)
		fill.mesh = fm
		fill.material_override = ArcadeLook.glow(Color(0.3, 0.6, 1.0) if s == 0 else Color(1.0, 0.35, 0.3), 1.5)
		add_child(fill)
		_bars.append(fill)
		var l := Label3D.new()
		l.font_size = 56
		l.pixel_size = 0.005
		l.outline_size = 8
		l.double_sided = false
		l.rotation_degrees = Vector3(0, -90, 0)
		add_child(l)
		l.global_position = Vector3(panel_x - 0.08, y, -1.9)
		_bar_labels.append(l)

## Piston con guante detras del lugar del que espera, empujando hacia +X.
func _build_glove() -> void:
	var dir := Vector3(1, 0, 0)
	var rest: Vector3 = WAIT_SPOT + Vector3(-PUNCH_REACH, PUNCH_Y, 0)
	var box_x: float = rest.x - GLOVE_R - RETRACT - 0.38
	var post := static_box(Vector3(0.24, PUNCH_Y - 0.15, 0.24), Vector3(box_x, (PUNCH_Y - 0.15) * 0.5, rest.z), Color(0.3, 0.3, 0.34), Vector3.ZERO, 0.3)
	for c in post.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.25, 0.26, 0.3), "metal")
	var box := static_box(Vector3(0.75, 0.42, 0.42), Vector3(box_x, PUNCH_Y, rest.z), Color(0.3, 0.3, 0.34), Vector3.ZERO, 0.3)
	for c in box.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.6, 0.12, 0.15), "metal")
	var g := AnimatableBody3D.new()
	g.sync_to_physics = false
	g.collision_layer = Ball.LAYER_WORLD
	var gcs := CollisionShape3D.new()
	var gs := SphereShape3D.new()
	gs.radius = GLOVE_R
	gcs.shape = gs
	g.add_child(gcs)
	var red := ArcadeLook.mat(Color(0.85, 0.08, 0.08), "plastic")
	ArcadeLook.part(g, "sphere", Vector3(GLOVE_R, 0, 0), Vector3.ZERO, red).scale = Vector3(1.15, 1.0, 1.0)
	ArcadeLook.part(g, "sphere", Vector3(0.09, 0, 0), Vector3(-0.05, 0.06, 0.22), red)
	ArcadeLook.part(g, "cyl", Vector3(0.17, 0.16, 0.17), Vector3(-0.26, 0, 0), ArcadeLook.mat(Color(0.95, 0.95, 0.95), "plastic"), Vector3(0, 0, PI * 0.5))
	add_child(g)
	var rod := ArcadeLook.deco(self, "cyl", Vector3(0.04, 1.0, 0.04), rest, ArcadeLook.mat(Color(0.85, 0.86, 0.9), "metal"))
	var coils: Array = []
	for k in 7:
		var c := MeshInstance3D.new()
		var ct := TorusMesh.new()
		ct.inner_radius = 0.08
		ct.outer_radius = 0.11
		ct.rings = 12
		ct.ring_segments = 4
		c.mesh = ct
		c.material_override = ArcadeLook.mat(Color(0.95, 0.75, 0.15), "metal")
		add_child(c)
		coils.append(c)
	glove = {"glove": g, "rod": rod, "coils": coils, "x": 0.0, "v": 0.0, "mode": "idle", "dir": dir, "rest": rest,
		"back": Vector3(box_x + 0.38, PUNCH_Y, rest.z), "hit_speed": 0.0}
	_pose_glove()

func _pose_glove() -> void:
	var dir: Vector3 = glove["dir"]
	var gp: Vector3 = (glove["rest"] as Vector3) + dir * float(glove["x"])
	(glove["glove"] as Node3D).global_transform = Transform3D(Basis(), gp)
	var back: Vector3 = glove["back"]
	var span: float = maxf(gp.distance_to(back), 0.05)
	var rot := Basis(Vector3(0, 0, 1), PI * 0.5)
	var rod: MeshInstance3D = glove["rod"]
	rod.global_transform = Transform3D(rot, (back + gp) * 0.5)
	rod.scale = Vector3(1, span, 1)
	var coils: Array = glove["coils"]
	for k in coils.size():
		(coils[k] as MeshInstance3D).global_transform = Transform3D(rot, back.lerp(gp, float(k + 1) / float(coils.size() + 1)))

# --- Lugares y turnos ---------------------------------------------------------------------------------------------------

func _ball_spot(_s: int) -> Vector3:
	return KICK_SPOT + Vector3.UP * (ball.radius if ball != null else 0.11)

func _aim_point(_s: int) -> Vector3:
	return Vector3(panel_x, 1.6, 0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(panel_x, Vector2(11.0, 30.0), false, 3.0, 4.0, ball.radius)

func frame_points() -> Array:
	return [button_center(selected), WAIT_SPOT + Vector3.UP * 1.8]

## El que espera se para frente al guante (mirandolo).
func _place_waiting(s: int) -> void:
	var a: SpActor = shooters[s].actor
	a.visible = true
	a.freeze_on_finish = false
	a.stop_moving()
	a.ground_y = 0.0
	a.global_position = WAIT_SPOT
	a.set_facing(Vector3(-1, 0, 0))
	if a.collider != null:
		a.collider.collision_layer = 0
	_fly_t[s] = -1.0
	var idles: Array[StringName] = SpClips.by_role(&"idle_ready", false)
	if not idles.is_empty():
		a.play_loop(idles[0], 0.2)

func button_center(i: int) -> Vector3:
	return (buttons[clampi(i, 0, buttons.size() - 1)]["cap"] as Node3D).global_position

func button_normal() -> Vector3:
	return Vector3(-1, 0, 0)

func button_velocity(i: int) -> Vector3:
	var b: Dictionary = buttons[i]
	if not b.has("mover"):
		return Vector3.ZERO
	var m: Dictionary = b["mover"]
	return (mover_at(m, level_time + 0.01).origin - mover_at(m, level_time).origin) / 0.01

func reset_level() -> void:
	charge = [0.0, 0.0]
	glove["x"] = 0.0
	glove["v"] = 0.0
	glove["mode"] = "idle"
	_pose_glove()
	_refresh_bars()
	super.reset_level()

func _start_turn() -> void:
	pressed_btn = -1
	landed = false
	for b in buttons:
		if b.has("mover"):
			(b["mover"] as Dictionary)["base"] = b["base"]
		else:
			(b["cap"] as Node3D).global_transform = b["base"]
	super._start_turn()
	# Relevo: el que no patea va frente al guante.
	_place_waiting(1 - side)
	if side == Side.USER:
		_set_user_actions()
	_highlight()

func _on_action(id: StringName) -> void:
	if id == &"select":
		selected = (selected + 1) % buttons.size()
		_highlight()
		_set_user_actions()
		return
	super._on_action(id)

func _set_user_actions() -> void:
	hud.set_actions([[&"select", "Apunto: %s" % String(buttons[selected]["size"]).capitalize()], [&"camera", "Cámara"], [&"restart", "Reiniciar"]])

func _highlight() -> void:
	for i in buttons.size():
		var on: bool = i == (selected if side == Side.USER else int(last_choice.get("button", -1)))
		var lab: Label3D = buttons[i]["label"]
		lab.modulate = Color(1.0, 0.95, 0.3) if on else Color(1, 1, 1)

func _on_ball_body(body: Node) -> void:
	if state != State.FLIGHT or pressed_btn >= 0:
		return
	for i in buttons.size():
		if body == buttons[i]["cap"]:
			var rel: Vector3 = prev_velocity() - button_velocity(i)
			if -rel.dot(button_normal()) >= PRESS_SPEED:
				press(side, i)

## El boton i quedo apretado por la pelota del que patea (s): se hunde, suma su carga (hasta 100 %) y, llena, suelta el
## guante contra el que espera.
func press(s: int, i: int) -> void:
	pressed_btn = i
	_press_t = 0.0
	var b: Dictionary = buttons[i]
	var cap: Node3D = b["cap"]
	cap.global_position -= button_normal() * CAP_DEPTH * 0.5
	if b.has("mover"):
		(b["mover"] as Dictionary)["base"] = Transform3D((b["base"] as Transform3D).basis, (b["base"] as Transform3D).origin - button_normal() * CAP_DEPTH * 0.5)
	charge[s] = minf(float(charge[s]) + float(b["gain"]), 1.0)
	if float(charge[s]) >= 0.999:
		fire()
	_refresh_bars()
	if not fast:
		Sfx.play(&"cheer", 0.4)

func fire() -> void:
	glove["mode"] = "fire"
	glove["v"] = 0.0

# --- Fisica del piston y del vuelo --------------------------------------------------------------------------------------

func _level_step(delta: float) -> void:
	_press_t += delta
	var target: int = 1 - side
	if target < shooters.size() and float(_fly_t[target]) < 0.0:
		var ta: SpActor = shooters[target].actor
		hurtbox.global_position = Vector3(ta.global_position.x, ta.global_position.y + 0.9, ta.global_position.z)
	# Vuelo balistico del que recibio el golpe (y sale de escena).
	for s in shooters.size():
		if float(_fly_t[s]) >= 0.0:
			var a: SpActor = shooters[s].actor
			_fly_t[s] = float(_fly_t[s]) + delta
			var v: Vector3 = _fly_v[s]
			v.y -= 9.8 * delta
			_fly_v[s] = v
			a.frame_origin += Vector3(v.x, 0, v.z) * delta
			a.global_position += Vector3(v.x, 0, v.z) * delta
			a.ground_y += v.y * delta
			a.global_position.y = a.ground_y
			if float(_fly_t[s]) > 1.6:
				a.visible = false
				_fly_t[s] = -1.0
	var x: float = float(glove["x"])
	var gv: float = float(glove["v"])
	match String(glove["mode"]):
		"idle":
			# La barra del que patea comprime el resorte: el guante va (resorte amortiguado) a -carga * RETRACT.
			var goal: float = -float(charge[side]) * RETRACT
			gv += (60.0 * (goal - x) - 14.0 * gv) * delta
			x += gv * delta
		"fire":
			var x0: float = x
			gv += (SPRING_W2 * (SPRING_L - x) - SPRING_C * gv) * delta
			x = minf(x + gv * delta, SPRING_L)
			# Barrido: se consulta cada 0,06 m del tramo para no atravesar el cuerpo.
			var n: int = maxi(int(ceil(absf(x - x0) / 0.06)), 1)
			for k in n:
				glove["x"] = lerpf(x0, x, float(k + 1) / float(n))
				glove["v"] = gv
				_pose_glove()
				_glove_query()
				if String(glove["mode"]) != "fire":
					break
			if String(glove["mode"]) != "fire":
				_refresh_bars()
				return
			if x >= SPRING_L or (x > 0.0 and gv <= 0.0):
				glove["mode"] = "return"
		"return":
			gv += (18.0 * (0.0 - x) - 8.0 * gv) * delta
			x += gv * delta
			if absf(x) < 0.02 and absf(gv) < 0.05:
				x = 0.0
				gv = 0.0
				glove["mode"] = "idle"
	glove["x"] = x
	glove["v"] = gv
	_pose_glove()
	_refresh_bars()

## Choque del guante: consulta fisica de su esfera contra el cuerpo del que espera (cinematico: un sensor de Jolt no lo
## ve, la consulta de forma si).
func _glove_query() -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = GLOVE_R + 0.02
	q.shape = sh
	q.transform = Transform3D(Basis(), (glove["glove"] as Node3D).global_position)
	q.collision_mask = HURT_LAYER
	q.collide_with_areas = false
	q.collide_with_bodies = true
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 4):
		if hit["collider"] == hurtbox:
			_on_glove_contact()

## El guante conecto: choque con masas reales; el que espera sale despedido (vuelo con gravedad) y el golpe es del que
## pateo.
func _on_glove_contact() -> void:
	if String(glove["mode"]) != "fire" or landed:
		return
	var v: float = float(glove["v"])
	if v < 1.0:
		return
	landed = true
	var t: int = 1 - side
	var vb: float = (1.0 + RESTITUTION) * GLOVE_MASS * v / (GLOVE_MASS + BODY_MASS)
	glove["v"] = v * (GLOVE_MASS - RESTITUTION * BODY_MASS) / (GLOVE_MASS + BODY_MASS)
	glove["mode"] = "return"
	glove["hit_speed"] = v
	_fly_v[t] = (glove["dir"] as Vector3) * vb + Vector3.UP * vb * LIFT
	_fly_t[t] = 0.0
	points[side] += 1
	charge[side] = 0.0
	var a: SpActor = shooters[t].actor
	a.stop_moving()
	var pool: Array[StringName] = BotonCaida.fall_clips()
	if not pool.is_empty():
		a.freeze_on_finish = true
		a.play_here(pool[rng.randi() % pool.size()], 0.06)
	if not fast:
		cam.shake(0.6, 0.7)
		Sfx.play(&"cheer", 0.8)

func _refresh_bars() -> void:
	for s in _bars.size():
		var c: float = float(charge[s])
		var w: float = maxf(3.5 * c, 0.001)
		var fill: MeshInstance3D = _bars[s]
		fill.global_transform = Transform3D(Basis(), Vector3(panel_x - 0.06, 2.75 - float(s) * 0.38, 0.3 - 1.75 + w * 0.5))
		fill.scale = Vector3(1, 1, w / 3.5)
		(_bar_labels[s] as Label3D).text = "%s %d%%" % ["VOS" if s == 0 else "CPU", int(round(c * 100.0))]

func _settling() -> bool:
	return String(glove["mode"]) != "idle" or float(_fly_t[0]) >= 0.0 or float(_fly_t[1]) >= 0.0

func _flight_check(_delta: float) -> String:
	if pressed_btn >= 0:
		if _press_t > 0.35 and not _settling():
			return "golpe" if landed else "carga"
		return ""
	var p: Vector3 = ball.global_position
	if absf(p.z) > 30.0 or p.x > panel_x + 10.0 or p.x < -10.0:
		return "afuera"
	return ""

func _on_resolved(s: int, result: String) -> void:
	var good: bool = result == "golpe" or result == "carga"
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if good else SpReactions.MISS_SHOOTER, rng, 1.3, 1.0)
	if id != &"" and s < shooters.size() and shooters[s].actor.visible:
		shooters[s].actor.play_here(id, 0.3)

func _check_winner() -> int:
	var need: int = int(def.get("punches", 2))
	if int(points[0]) >= need:
		return Side.USER
	if int(points[1]) >= need:
		return Side.CPU
	return -1

func final_score() -> int:
	var s: int = 100 * int(points[0])
	if winner == Side.USER:
		s += 200 + maxi(120 - 10 * int(shots[0]), 0)
	return s

func _result_text(r: String) -> Array:
	match r:
		"golpe":
			return ["¡GUANTAZO!" if side == Side.USER else "¡TE VOLÓ!", Color(0.35, 1.0, 0.45) if side == Side.USER else Color(1.0, 0.4, 0.4),
				"Golpes %d - %d" % [int(points[0]), int(points[1])]]
		"carga":
			var b: Dictionary = buttons[pressed_btn]
			return ["+%d %%" % int(round(float(b["gain"]) * 100.0)), Color(1.0, 0.85, 0.35), "Botón %s · carga %d %%" % [String(b["size"]), int(round(float(charge[side]) * 100.0))]]
	return ["Sin carga", Color(1.0, 0.6, 0.4), "La pelota tiene que apretar un botón · cambia el turno"]

func _refresh_score() -> void:
	hud.set_score_text("Vos %d %% · golpes %d - %d · CPU %d %%" % [int(round(float(charge[0]) * 100.0)), int(points[0]), int(points[1]), int(round(float(charge[1]) * 100.0))])

# --- IA -----------------------------------------------------------------------------------------------------------------

func _cpu_err() -> float:
	return cpu_error_deg if cpu_error_deg >= 0.0 else float(CPU_ERROR[clampi(SpSettings.level(), 0, CPU_ERROR.size() - 1)])

## Valor esperado del boton i para s: probabilidad de acertar con su error (dispersion gaussiana a esa distancia, dentro
## del radio util) por la carga que entra en la barra, mas un premio si la completa.
func button_value(s: int, i: int, err_deg: float) -> Dictionary:
	var b: Dictionary = buttons[i]
	var dist: float = _ball_spot(s).distance_to(button_center(i))
	var sigma: float = maxf(dist * tan(deg_to_rad(err_deg)), 0.01)
	var r: float = float(b["r"]) * 0.85
	var p: float = 1.0 - exp(-(r * r) / (2.0 * sigma * sigma))
	if b.has("mover"):
		p *= 0.7
	var room: float = 1.0 - float(charge[s])
	var useful: float = minf(float(b["gain"]), room)
	var v: float = p * useful
	if float(b["gain"]) >= room - 0.001:
		v += p * 0.35
	return {"p": p, "value": v, "useful": useful}

func choose_button(s: int, err_deg: float) -> int:
	var best: int = 0
	var best_v: float = -1.0
	for i in buttons.size():
		var bv: Dictionary = button_value(s, i, err_deg)
		if float(bv["value"]) > best_v:
			best_v = float(bv["value"])
			best = i
	return best

## Punto al que apuntar para apretar el boton i (la cara del boton; el que se mueve, adelantado).
func button_target(i: int, speed: float) -> Vector3:
	var target: Vector3 = button_center(i)
	var b: Dictionary = buttons[i]
	if b.has("mover"):
		var first: Dictionary = cpu_shot(target, speed, 0.0, 0.0)
		var tc: float = ShotSolver.crossing_time(first["trajectory"], target.x)
		var spot: Vector3 = _ball_spot(side)
		var t_fly: float = runup_time + (tc if tc > 0.0 else spot.distance_to(target) / speed)
		target = mover_at(b["mover"], level_time + t_fly).origin
	return target + button_normal() * (ball.radius + CAP_DEPTH * 0.5)

func _cpu_intent() -> Dictionary:
	var err: float = _cpu_err()
	var i: int = choose_button(Side.CPU, err)
	last_choice = {"button": i, "value": button_value(Side.CPU, i, err)}
	_highlight()
	var speed: float = clampf(_ball_spot(Side.CPU).distance_to(button_center(i)) * 0.9 + 5.0, 14.0, 24.0)
	return cpu_shot(button_target(i, speed), speed, 0.0, err)
