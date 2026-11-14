class_name Rescate
extends Minigame
## Rescate de la pelota: una pelota dorada esta atrapada y hay que llevarla a la ZONA VERDE. Todo es fisico y TODO se
## activa con la pelota del jugador (pedido del usuario, 2026-11-14: «todo debe ser activado con el balón… la bola que
## liberó debe caer y desplazarse a la zona verde… debería poder girar el nivel: el jugador y el balón quedan fijos y yo
## muevo el escenario… palancas, botones, meter el balón en un hoyo o impactar»).
##
## Niveles ("rescate" en minigames.json): prisoner {pos}, zone [x0,z0,x1,z1], shots, buttons [{pos, latch: idx}],
## latches [{pos, size}], slopes (cajas inclinadas), walls, platforms, dominoes [{pos, n, step}], crates [{pos, size}],
## pits, y los mecanismos de RescueMechs ("parts" que se mueven y "mechs" que se activan a pelotazos: palancas, blancos,
## buzones, secuencias de colores, ruedas dentadas, contrapesos y placas que se apretan con una caja).
##
## ESCENARIO GIRATORIO: todo el nivel (menos el piso, el jugador y su pelota) cuelga de stage_pivot, en el centro del
## nivel ("pivot"); los botones «Girar» (o Q y E) lo giran de a 45 grados cuando nada se mueve, para ver los mandos de
## atras y buscar el angulo del tiro. Las posiciones del nivel son las del escenario sin girar (stage).
##
## La dorada sale solo cuando un mecanismo la suelta, rueda por su tobogan y se frena en la zona (con bordes). Si cae al
## vacio o a un pozo es un intento perdido. Se registran tiempo, acciones, errores, caidas e intentos (puntaje y online).
## Cada nivel trae "solution" (giro y blanco de cada tiro), verificada con la fisica del juego en tests/test_rescate_mechs.

const SCENE := "res://scenes/minigames/rescate.tscn"
const PRESS_SPEED := 2.5
const RESCUE_POINTS := 150
const SPARE_SHOT := 50
## Giro del escenario por toque (grados) y lo que tarda (s).
const ROT_STEP := 45.0
const ROT_TIME := 0.35
## Frenado de la dorada sobre la arena de la zona verde.
const ZONE_DAMP := 2.5

var prisoner: RigidBody3D
var zone := Rect2()
var shots_max: int = 3
var rescued: bool = false
## Botones de los niveles de patear: {body, mesh, latch (indice), pressed, normal (en el escenario), home}.
var buttons: Array = []
var latches: Array = []
var dominoes: Array[RigidBody3D] = []
var crates: Array[RigidBody3D] = []
## Posicion inicial (en el escenario) de cada cuerpo que se mueve: prisionera, dominos y cajas.
var _homes: Dictionary = {}
var _prisoner_home := Transform3D()
## Mecanismos del nivel (null en los niveles de solo patear).
var mechs: RescueMechs = null
var time_limit: float = 0.0
var timed_out: bool = false
var attempts: int = 1
var falls: int = 0
## Segundos que tardo en rescatarla (o -1).
var solve_time: float = -1.0
const FALL_Y := -1.5
## Pozos del nivel (rectangulos rojos en el piso del escenario): si la pelota cae ahi, intento perdido.
var pits: Array[Rect2] = []
const TIME_BONUS := 2
const ERROR_COST := 15
## Escenario: stage_pivot gira alrededor de pivot; stage (hijo, corrido -pivot) tiene las coordenadas del nivel.
var stage_pivot: Node3D
var stage: Node3D
var pivot := Vector3(12, 0, 0)
## Giro actual en pasos de ROT_STEP y animacion en curso.
var rot_k: int = 0
var _rot_from: float = 0.0
var _rot_to: float = 0.0
var _rot_t: float = -1.0

func game_id() -> String:
	return "rescate"

## Caja estatica del nivel (en el escenario).
func _sbox(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, bounce: float = 0.45) -> StaticBody3D:
	var b: StaticBody3D = static_box(size, pos, color, rot, bounce)
	b.get_parent().remove_child(b)
	stage.add_child(b)
	b.position = pos
	b.rotation = rot
	return b

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 3))
	max_turns = maxi(shots_max, 1)
	var mech_level: bool = def.has("mechs") or def.has("parts")
	# Piso fijo (no gira): oscuro en los niveles de mecanismos (taller), para que resalten.
	static_box(Vector3(70, 1, 40), Vector3(8, -0.5, 0), Color(0.2, 0.22, 0.29) if mech_level else Color(0.45, 0.4, 0.5), Vector3.ZERO, 0.4)
	pivot = BotonCaida._vec(def.get("pivot", [12, 0, 0]))
	pivot.y = 0.0
	stage_pivot = Node3D.new()
	stage_pivot.name = "StagePivot"
	add_child(stage_pivot)
	stage_pivot.position = pivot
	stage = Node3D.new()
	stage.name = "Stage"
	stage_pivot.add_child(stage)
	stage.position = -pivot
	var z: Array = def.get("zone", [2, -2, 6, 2])
	zone = Rect2(float(z[0]), float(z[1]), float(z[2]) - float(z[0]), float(z[3]) - float(z[1]))
	var zm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(zone.size.x, zone.size.y)
	zm.mesh = pm
	zm.material_override = color_mat(Color(0.2, 0.95, 0.4), 0.4)
	stage.add_child(zm)
	zm.position = Vector3(zone.get_center().x, float(def.get("zone_y", 0.0)) + 0.015, zone.get_center().y)
	for w in def.get("walls", []):
		var wd: Dictionary = w
		_sbox(BotonCaida._vec(wd.get("size", [3, 1, 0.3])), BotonCaida._vec(wd.get("pos", [8, 0.5, 0])), Color.from_string(String(wd.get("color", "#d9d9e6")), Color(0.85, 0.85, 0.9)),
			Vector3(0, deg_to_rad(float(wd.get("yaw", 0.0))), 0), float(wd.get("bounce", 0.5)))
	for pl in def.get("platforms", []):
		var pd: Dictionary = pl
		_sbox(BotonCaida._vec(pd.get("size", [3, 1, 3])), BotonCaida._vec(pd.get("pos", [12, 0.5, 0])), Color.from_string(String(pd.get("color", "#80739a")), Color(0.5, 0.45, 0.6)), Vector3.ZERO, 0.3)
	for sl in def.get("slopes", []):
		var sd: Dictionary = sl
		_sbox(BotonCaida._vec(sd.get("size", [3, 0.2, 2])), BotonCaida._vec(sd.get("pos", [12, 1.0, 0])), Color.from_string(String(sd.get("color", "#8c80a6")), Color(0.55, 0.5, 0.65)),
			Vector3(deg_to_rad(float(sd.get("pitch", 0.0))), deg_to_rad(float(sd.get("yaw", 0.0))), deg_to_rad(float(sd.get("roll", 0.0)))), float(sd.get("bounce", 0.15)))
	for ld in def.get("latches", []):
		var l: Dictionary = ld
		var latch := _sbox(BotonCaida._vec(l.get("size", [0.1, 0.5, 1.2])), BotonCaida._vec(l.get("pos", [11, 1.2, 0])), Color(0.9, 0.3, 0.2), Vector3(0, deg_to_rad(float(l.get("yaw", 0.0))), 0), 0.2)
		latches.append(latch)
	for bd in def.get("buttons", []):
		_spawn_button(bd)
	for dd in def.get("dominoes", []):
		var d: Dictionary = dd
		var at: Vector3 = BotonCaida._vec(d.get("pos", [10, 1.0, 0]))
		var step: Vector3 = BotonCaida._vec(d.get("step", [0.5, 0, 0]))
		var size: Vector3 = BotonCaida._vec(d.get("size", [0.12, 0.9, 0.5]))
		for i in int(d.get("n", 5)):
			var slab := _rigid_box(size, 0.8, Color(0.95, 0.75, 0.2))
			slab.add_to_group("rescue_domino")
			slab.position = at + step * float(i) + Vector3.UP * size.y * 0.5
			dominoes.append(slab)
			_homes[slab] = slab.transform
	for cd in def.get("crates", []):
		var c: Dictionary = cd
		var cs: Vector3 = BotonCaida._vec(c.get("size", [0.55, 0.55, 0.55]))
		var crate := _rigid_box(cs, float(c.get("mass", 1.2)), Color(0.72, 0.5, 0.26))
		crate.add_to_group("rescue_crate")
		var cpm := PhysicsMaterial.new()
		cpm.friction = float(c.get("friction", 0.35))
		cpm.bounce = 0.05
		crate.physics_material_override = cpm
		crate.position = BotonCaida._vec(c.get("pos", [9, 0.3, 0]))
		crates.append(crate)
		_homes[crate] = crate.transform
	# La prisionera: pelota dorada, fisica real. Poco frenado: cuando la sueltan, rueda hasta la zona.
	prisoner = RigidBody3D.new()
	prisoner.mass = 0.42
	prisoner.linear_damp = float(def.get("prisoner_damp", 0.15))
	prisoner.angular_damp = 0.3
	# Abrir una traba no es un contacto: no despierta a un cuerpo dormido. La dorada nunca duerme.
	prisoner.can_sleep = false
	prisoner.collision_layer = Ball.LAYER_WORLD
	prisoner.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
	var pcs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.12
	pcs.shape = sph
	prisoner.add_child(pcs)
	var pmat := PhysicsMaterial.new()
	pmat.bounce = 0.25
	pmat.friction = 0.6
	prisoner.physics_material_override = pmat
	var pmi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	pmi.mesh = sm
	pmi.material_override = color_mat(Color(1.0, 0.82, 0.15), 0.5)
	prisoner.add_child(pmi)
	stage.add_child(prisoner)
	prisoner.position = BotonCaida._vec(def.get("prisoner", [12, 1.3, 0]))
	_prisoner_home = prisoner.transform
	ball.body_entered.connect(_on_ball_body)
	time_limit = float(def.get("time", 0.0))
	if mech_level:
		mechs = RescueMechs.new()
		mechs.name = "Mechs"
		mechs.fast = fast
		stage.add_child(mechs)
		mechs.build(def.get("parts", []), def.get("mechs", []))
		mechs.acted.connect(_on_mech_acted)
	for pd in def.get("pits", []):
		var r := Rect2(float(pd[0]), float(pd[1]), float(pd[2]) - float(pd[0]), float(pd[3]) - float(pd[1]))
		pits.append(r)
		var pmesh := MeshInstance3D.new()
		var pl2 := PlaneMesh.new()
		pl2.size = r.size
		pmesh.mesh = pl2
		pmesh.material_override = color_mat(Color(0.9, 0.12, 0.1), 0.5)
		stage.add_child(pmesh)
		pmesh.position = Vector3(r.get_center().x, 0.02, r.get_center().y)
	# Señal de la zona de rescate: un arco de llegada con un cartel (se entiende a donde tiene que llegar).
	_build_zone_sign()

func _rigid_box(size: Vector3, mass: float, col: Color) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.mass = mass
	rb.collision_layer = Ball.LAYER_WORLD
	rb.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = color_mat(col)
	rb.add_child(mi)
	stage.add_child(rb)
	return rb

func _spawn_button(bd: Dictionary) -> void:
	var cap := AnimatableBody3D.new()
	cap.sync_to_physics = false
	cap.collision_layer = Ball.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = float(bd.get("radius", 0.4))
	cyl.height = 0.14
	cs.shape = cyl
	cap.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = cyl.radius
	cm.bottom_radius = cyl.radius
	cm.height = 0.14
	mi.mesh = cm
	mi.material_override = color_mat(Color(0.95, 0.12, 0.1), 0.6)
	cap.add_child(mi)
	stage.add_child(cap)
	var facing_up: bool = bool(bd.get("up", false))
	cap.transform = Transform3D(Basis() if facing_up else Basis(Vector3(0, 0, 1), PI * 0.5), BotonCaida._vec(bd.get("pos", [10, 1.0, 0])))
	buttons.append({"body": cap, "mesh": mi, "latch": int(bd.get("latch", 0)), "pressed": false,
		"normal": Vector3.UP if facing_up else Vector3(-1, 0, 0), "home": cap.transform})

func _on_ball_body(body: Node) -> void:
	if state != State.FLIGHT:
		return
	if mechs != null and mechs.ball_hit(body, prev_velocity().length()):
		return
	for b in buttons:
		if body == b["body"] and not bool(b["pressed"]):
			# La normal del boton gira con el escenario.
			var n: Vector3 = stage.global_transform.basis * (b["normal"] as Vector3)
			var impact: float = -prev_velocity().dot(n)
			if impact >= PRESS_SPEED:
				_press(b)

## Boton apretado: se hunde, se pone verde y su traba desaparece (la compuerta queda libre; lo que siga es gravedad).
func _press(b: Dictionary) -> void:
	b["pressed"] = true
	var cap: Node3D = b["body"]
	cap.position += (b["normal"] as Vector3) * -0.08
	(b["mesh"] as MeshInstance3D).material_override = color_mat(Color(0.2, 0.95, 0.3), 0.8)
	var li: int = int(b["latch"])
	if li >= 0 and li < latches.size() and is_instance_valid(latches[li]):
		(latches[li] as Node3D).visible = false
		(latches[li] as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED
		for c in (latches[li] as Node).get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true
	if not fast:
		Sfx.play(&"cheer", 0.4)

func pressed_count() -> int:
	var n: int = 0
	for b in buttons:
		if bool(b["pressed"]):
			n += 1
	return n

## Vuelve los cuerpos que se mueven a su lugar (en el escenario, con el giro que tenga).
func _reset_bodies() -> void:
	prisoner.transform = _prisoner_home
	prisoner.linear_velocity = Vector3.ZERO
	prisoner.angular_velocity = Vector3.ZERO
	for rb in _homes:
		var b: RigidBody3D = rb
		b.transform = _homes[rb]
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO

func reset_level() -> void:
	rescued = false
	timed_out = false
	attempts = 1
	falls = 0
	solve_time = -1.0
	if mechs != null:
		mechs.actions = 0
		mechs.errors = 0
		mechs.reset()
	_reset_bodies()
	for b in buttons:
		b["pressed"] = false
		(b["body"] as Node3D).transform = b["home"]
		(b["mesh"] as MeshInstance3D).material_override = color_mat(Color(0.95, 0.12, 0.1), 0.6)
	for l in latches:
		if is_instance_valid(l):
			(l as Node3D).visible = true
			(l as StaticBody3D).process_mode = Node.PROCESS_MODE_INHERIT
			for c in (l as Node).get_children():
				if c is CollisionShape3D:
					(c as CollisionShape3D).disabled = false
	super.reset_level()

# --- Escenario giratorio -------------------------------------------------------------------------------------------------

## Se puede girar: apuntando, sin nada en movimiento y sin otro giro en curso.
func can_rotate() -> bool:
	return state == State.AIM and side == Side.USER and _rot_t < 0.0 and not _settling() and not _swiping

## Gira el escenario un paso (dir = +1 a la izquierda, -1 a la derecha), animado.
func rotate_stage(dir: int) -> bool:
	if not can_rotate():
		return false
	rot_k = posmod(rot_k + dir, int(round(360.0 / ROT_STEP)))
	_rot_from = stage_pivot.rotation.y
	_rot_to = _rot_from + deg_to_rad(ROT_STEP) * float(dir)
	_rot_t = 0.0
	_freeze_bodies(true)
	if not fast:
		Sfx.play(&"mech_click", 0.5)
	return true

## Giro al paso k sin animacion (pruebas): congela, gira y suelta en el paso de fisica siguiente.
func rotate_to(k: int) -> void:
	rot_k = posmod(k, int(round(360.0 / ROT_STEP)))
	_freeze_bodies(true)
	stage_pivot.rotation.y = deg_to_rad(ROT_STEP) * float(rot_k)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_freeze_bodies(false)

## Mientras gira, los cuerpos sueltos quedan congelados (se mueven con el escenario sin chocar entre si).
func _freeze_bodies(on: bool) -> void:
	var all: Array = [prisoner] + dominoes + crates
	for rb in all:
		var b: RigidBody3D = rb
		b.freeze = on
		if not on:
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity = Vector3.ZERO

func _step_rotation(delta: float) -> void:
	if _rot_t < 0.0:
		return
	_rot_t = minf(_rot_t + delta / ROT_TIME, 1.0)
	stage_pivot.rotation.y = lerpf(_rot_from, _rot_to, smoothstep(0.0, 1.0, _rot_t))
	if _rot_t >= 1.0:
		_rot_t = -1.0
		stage_pivot.rotation.y = wrapf(_rot_to, -PI, PI)
		_freeze_bodies(false)

## Punto del escenario (coordenadas del nivel) en el mundo, con el giro actual.
func stage_point(p: Vector3) -> Vector3:
	return stage.to_global(p)

## Encuadre: la prisionera, la zona libre, los botones y los mandos.
func frame_points() -> Array:
	var out: Array = [prisoner.global_position + Vector3.UP * 0.4, stage_point(Vector3(zone.position.x, 0, zone.position.y)),
		stage_point(Vector3(zone.end.x, 0, zone.end.y))]
	for b in buttons:
		out.append((b["body"] as Node3D).global_position)
	if mechs != null:
		for m in mechs.mechs:
			out.append((m["root"] as Node3D).global_position + Vector3.UP * 0.5)
	return out

## Camara de los niveles de mecanismos: detras del jugador y alta, mirando todo el escenario (que gira en su lugar).
func camera_defaults() -> Dictionary:
	if mechs == null:
		return super.camera_defaults()
	return {"back": 5.0, "height": 4.8, "ahead": 5.0, "lift_aim": 0.0, "fov": 55.0, "follow": 0.45}

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0, ball.radius if ball != null else 0.11, 0) + BotonCaida._vec(def.get("tee", [0, 0, 0]))

func _aim_point(_s: int) -> Vector3:
	return pivot + Vector3.UP * 1.0

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(pivot.x, Vector2(9.0, 27.0), false, 5.0, 4.5, ball.radius)

func _settling() -> bool:
	if prisoner.linear_velocity.length() > 0.25:
		return true
	for d in dominoes:
		if not d.sleeping and d.linear_velocity.length() > 0.2:
			return true
	for c in crates:
		if not c.sleeping and c.linear_velocity.length() > 0.2:
			return true
	return false

## La prisionera en coordenadas del escenario.
func prisoner_local() -> Vector3:
	return stage.to_local(prisoner.global_position)

func _in_zone() -> bool:
	var p: Vector3 = prisoner_local()
	return zone.has_point(Vector2(p.x, p.z)) and p.y < float(def.get("zone_y", 0.0)) + 0.5 and prisoner.linear_velocity.length() < 0.6

var _hud_t: float = 0.0
func _level_step(delta: float) -> void:
	_step_rotation(delta)
	# La zona verde es de arena: la dorada que entra se frena ahi (mas rozamiento) y no sigue de largo.
	if prisoner != null:
		var lp: Vector3 = prisoner_local()
		var in_sand: bool = zone.has_point(Vector2(lp.x, lp.z)) and lp.y < float(def.get("zone_y", 0.0)) + 0.5
		prisoner.linear_damp = ZONE_DAMP if in_sand else float(def.get("prisoner_damp", 0.15))
	if mechs != null:
		mechs.step(delta)
		_hud_t -= delta
		if _hud_t <= 0.0 and state != State.OVER:
			_hud_t = 0.25
			_refresh_score()
	if rescued or state == State.OVER or _rot_t >= 0.0:
		return
	if prisoner.global_position.y < FALL_Y or in_pit():
		# Se cayo al vacio: intento perdido, todo vuelve al principio (el reloj sigue).
		falls += 1
		new_attempt()
		hud.show_banner("¡SE CAYÓ!", Color(1.0, 0.55, 0.3), "Intento %d" % attempts)
		return
	if time_limit > 0.0 and level_time >= time_limit and not _in_zone():
		timed_out = true
		if state == State.AIM:
			state = State.FLIGHT
		_resolve("tiempo")
		return
	if _in_zone():
		rescued = true
		solve_time = level_time
		if state == State.AIM:
			# La prisionera llego rodando mientras se apuntaba (una cadena lenta): la jugada se resuelve igual.
			state = State.FLIGHT
			_resolve("rescatada")

func _flight_check(_delta: float) -> String:
	if timed_out:
		return "tiempo"
	if rescued or _in_zone():
		rescued = true
		if solve_time < 0.0:
			solve_time = level_time
		return "rescatada"
	if _t > 0.8 and not _settling() and ball.linear_velocity.length() < SLOW_SPEED:
		return "listo"
	# Una pelota que quedo trabada (adentro de un buzon, sobre una plataforma) no traba el turno.
	if _t > 6.0 and not _settling():
		return "listo"
	return ""

func _on_resolved(s: int, r: String) -> void:
	points[0] = 1 if rescued else 0
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if r == "rescatada" else SpReactions.MISS_SHOOTER, rng, 1.5, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)
	if r == "rescatada" and not fast:
		cam.shake(0.4, 0.7)

func _check_winner() -> int:
	if rescued or timed_out:
		return Side.USER
	if int(shots[0]) >= shots_max:
		return Side.USER
	return -1

## Puntaje: rescate + tiros que sobraron + segundos que sobraron, menos los errores (secuencias equivocadas, caidas).
## Sin rescate, 0. Lo recalcula igual el servidor online con las mismas estadisticas (finish_minigame).
func final_score() -> int:
	if not rescued:
		return 0
	return score_for(stats())

static func score_for(st: Dictionary) -> int:
	if not bool(st.get("rescued", false)):
		return 0
	var spare_shots: int = maxi(int(st.get("shots_max", 0)) - int(st.get("shots", 0)), 0)
	var spare_time: int = maxi(int(floor(float(st.get("time_limit", 0.0)) - float(st.get("time", 0.0)))), 0)
	var errs: int = int(st.get("errors", 0)) + int(st.get("falls", 0))
	return maxi(RESCUE_POINTS + spare_shots * SPARE_SHOT + spare_time * TIME_BONUS - errs * ERROR_COST, 50)

## Lo que se registra del intento (pantalla final y online): tiempo, acciones, errores, intentos, tiempo restante.
func stats() -> Dictionary:
	var acts: int = (mechs.actions if mechs != null else 0) + int(shots[0])
	return {"rescued": rescued, "time": snappedf(solve_time if solve_time >= 0.0 else level_time, 0.01), "time_limit": time_limit,
		"remaining": snappedf(maxf(time_limit - (solve_time if solve_time >= 0.0 else level_time), 0.0), 0.01) if time_limit > 0.0 else 0.0,
		"actions": acts, "errors": mechs.errors if mechs != null else 0, "falls": falls, "attempts": attempts,
		"shots": int(shots[0]), "shots_max": shots_max}

## La pelota cayo en un pozo (rectangulo rojo, a ras del piso del escenario).
func in_pit() -> bool:
	var p: Vector3 = prisoner_local()
	if p.y > 0.5:
		return false
	for r in pits:
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false

func online_stats() -> Dictionary:
	return stats()

## Otro intento sin cortar la partida: el prisionero, las cajas, los dominos y los mecanismos al principio; el reloj y los
## contadores siguen.
func new_attempt() -> void:
	attempts += 1
	_reset_bodies()
	if mechs != null:
		mechs.reset()

func _start_turn() -> void:
	super._start_turn()
	if side == Side.USER and state == State.AIM:
		hud.set_actions([[&"rot_l", "‹ Girar"], [&"rot_r", "Girar ›"], [&"camera", "Cámara"], [&"restart", "Reiniciar"]])
		if rot_k == 0 and mechs != null and turn_n == 0:
			hud.set_hint(String(def.get("hint", "Girá el escenario con «Girar» y pateá a los mecanismos")))

## Mientras gira el escenario no se patea.
func _on_press(pos: Vector2, pressed: bool) -> void:
	if _rot_t >= 0.0:
		return
	super._on_press(pos, pressed)

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_Q:
			rotate_stage(1)
		elif k.keycode == KEY_E:
			rotate_stage(-1)

func _on_action(id: StringName) -> void:
	match id:
		&"rot_l":
			rotate_stage(1)
			return
		&"rot_r":
			rotate_stage(-1)
			return
	# «Reiniciar» en un nivel de mecanismos: otro intento (el reloj sigue). Al final, «Otra vez» empieza de cero.
	if id == &"restart" and mechs != null and state != State.OVER:
		new_attempt()
		return
	super._on_action(id)

func _on_mech_acted(kind: String) -> void:
	if fast:
		return
	match kind:
		"click":
			Sfx.play(&"mech_click", 0.7)
		"gate":
			Sfx.play(&"mech_gate", 0.6)
		"release":
			Sfx.play(&"mech_release", 0.8)
		"error":
			Sfx.play(&"mech_error", 0.7)
			hud.show_banner("ORDEN EQUIVOCADO", Color(1.0, 0.45, 0.35), "Mirá las luces del panel")

## Zona de rescate bien señalizada: dos postes con un cartel RESCATE (en el escenario: gira con el).
func _build_zone_sign() -> void:
	var c: Vector2 = zone.get_center()
	var sy: float = float(def.get("zone_y", 0.0))
	var sign := Label3D.new()
	sign.text = "RESCATE"
	sign.font_size = 96
	sign.outline_size = 16
	sign.modulate = Color(0.4, 1.0, 0.5)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stage.add_child(sign)
	sign.position = Vector3(c.x, sy + 1.3, c.y)
	for side_z in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.04
		cm.height = 1.1
		post.mesh = cm
		post.material_override = color_mat(Color(0.9, 0.9, 0.95))
		stage.add_child(post)
		post.position = Vector3(c.x, sy + 0.55, c.y + side_z * zone.size.y * 0.5)

func _report_achievements(w: int, medal: int) -> void:
	super._report_achievements(w, medal)
	if rescued:
		Achievements.event(&"rescate")

func _result_text(r: String) -> Array:
	if r == "rescatada":
		if mechs != null:
			var st: Dictionary = stats()
			return ["¡RESCATADA!", Color(0.35, 1.0, 0.45), "%d tiros · %.1f s · %d errores" % [int(st["shots"]), float(st["time"]),
				int(st["errors"]) + int(st["falls"])]]
		return ["¡RESCATADA!", Color(0.35, 1.0, 0.45), "En %d tiros" % int(shots[0])]
	if r == "tiempo":
		return ["SE ACABÓ EL TIEMPO", Color(1.0, 0.45, 0.35), "Sigue atrapada"]
	if mechs != null:
		return ["", Color.WHITE, ""]
	return ["Sigue atrapada", Color(1.0, 0.75, 0.4), "Tiros %d de %d" % [int(shots[0]), shots_max]]

func _refresh_score() -> void:
	if mechs != null:
		var left: String = ("%d s" % int(ceil(maxf(time_limit - level_time, 0.0)))) if time_limit > 0.0 else "%d s" % int(level_time)
		hud.set_score_text("Rescate · tiros %d / %d · %s · errores %d" % [int(shots[0]), shots_max, left, mechs.errors + falls])
		return
	hud.set_score_text("Rescate · tiros %d / %d" % [int(shots[0]), shots_max])
