class_name Rescate
extends Minigame
## Rescate de la pelota (etapa A5): una pelota dorada esta atrapada (en una jaula con compuerta, sobre una plataforma,
## detras de un domino...) y hay que llevarla a la ZONA LIBRE con tiros limitados. Todo es fisico: los botones se aprietan
## solo con un impacto real (como en Boton de caida), la compuerta es una traba que se quita y deja rodar, el empujon es
## transferencia de impulso real y el domino es una cadena de losas rigidas. Nada se mueve si la pelota no lo toco.
##
## Niveles ("rescate" en minigames.json): prisoner {pos}, zone [x0,z0,x1,z1], shots, buttons [{pos, latch: idx}],
## latches [{pos, size}], slopes (cajas inclinadas), walls, platforms, dominoes [{pos, n, step}].
##
## Rediseño (2026-11-13, pedido del usuario: «un minijuego de ingenio y habilidad, con mecanismos variados y acertijos
## reales»): los niveles nuevos traen "parts" y "mechs" (RescueMechs: palancas, botones de mantener y con tiempo,
## secuencias con cerradura, manivelas con engranajes, contrapesos con polea, plataformas moviles, puentes, rampas y
## compuertas). Se tocan sobre el mecanismo (un toque que cae sobre un mando no patea). La pelota sigue siendo un cuerpo
## fisico: sale solo cuando el mecanismo la suelta, y rueda o cae hasta la zona verde. Si cae al vacio es un intento
## perdido (vuelve todo al principio y el reloj sigue). "time": tiempo limite; "shots": 0 = sin patear. Se registran
## tiempo, acciones, errores e intentos (puntaje y online). Cada nivel trae "solution" (pasos verificados en la prueba).

const SCENE := "res://scenes/minigames/rescate.tscn"
const PRESS_SPEED := 2.5
const RESCUE_POINTS := 150
const SPARE_SHOT := 50

var prisoner: RigidBody3D
var zone := Rect2()
var shots_max: int = 3
var rescued: bool = false
## Botones: {body, mesh, latch (indice), pressed}; trabas: StaticBody3D que se quitan al apretar su boton.
var buttons: Array = []
var latches: Array = []
var dominoes: Array[RigidBody3D] = []
var _prisoner_home := Transform3D()
## Mecanismos tactiles del nivel (null en los niveles de solo patear).
var mechs: RescueMechs = null
var time_limit: float = 0.0
var timed_out: bool = false
var attempts: int = 1
var falls: int = 0
## Segundos que tardo en rescatarla (o -1).
var solve_time: float = -1.0
const FALL_Y := -1.5
## Pozos del nivel (rectangulos rojos en el piso, con borde): si la pelota cae ahi, intento perdido.
var pits: Array[Rect2] = []
const TIME_BONUS := 2
const ERROR_COST := 15

func game_id() -> String:
	return "rescate"

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 3))
	# Sin tiros (niveles solo de mecanismos) la partida igual tiene su turno: termina al rescatarla o con el reloj.
	max_turns = maxi(shots_max, 1)
	# Piso oscuro (taller): los mecanismos, con sus colores y franjas, resaltan.
	static_box(Vector3(70, 1, 40), Vector3(8, -0.5, 0), Color(0.2, 0.22, 0.29) if (def.has("mechs") or def.has("parts")) else Color(0.45, 0.4, 0.5), Vector3.ZERO, 0.4)
	var z: Array = def.get("zone", [2, -2, 6, 2])
	zone = Rect2(float(z[0]), float(z[1]), float(z[2]) - float(z[0]), float(z[3]) - float(z[1]))
	var zm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(zone.size.x, zone.size.y)
	zm.mesh = pm
	zm.material_override = color_mat(Color(0.2, 0.95, 0.4), 0.4)
	add_child(zm)
	zm.global_position = Vector3(zone.get_center().x, 0.015, zone.get_center().y)
	for w in def.get("walls", []):
		var wd: Dictionary = w
		static_box(BotonCaida._vec(wd.get("size", [3, 1, 0.3])), BotonCaida._vec(wd.get("pos", [8, 0.5, 0])), Color(0.85, 0.85, 0.9),
			Vector3(0, deg_to_rad(float(wd.get("yaw", 0.0))), 0), 0.5)
	for pl in def.get("platforms", []):
		var pd: Dictionary = pl
		static_box(BotonCaida._vec(pd.get("size", [3, 1, 3])), BotonCaida._vec(pd.get("pos", [12, 0.5, 0])), Color(0.5, 0.45, 0.6), Vector3.ZERO, 0.3)
	for sl in def.get("slopes", []):
		var sd: Dictionary = sl
		static_box(BotonCaida._vec(sd.get("size", [3, 0.2, 2])), BotonCaida._vec(sd.get("pos", [12, 1.0, 0])), Color(0.55, 0.5, 0.65),
			Vector3(deg_to_rad(float(sd.get("pitch", 0.0))), deg_to_rad(float(sd.get("yaw", 0.0))), deg_to_rad(float(sd.get("roll", 0.0)))), 0.15)
	for ld in def.get("latches", []):
		var l: Dictionary = ld
		var latch := static_box(BotonCaida._vec(l.get("size", [0.1, 0.5, 1.2])), BotonCaida._vec(l.get("pos", [11, 1.2, 0])), Color(0.9, 0.3, 0.2), Vector3(0, deg_to_rad(float(l.get("yaw", 0.0))), 0), 0.2)
		latches.append(latch)
	for bd in def.get("buttons", []):
		_spawn_button(bd)
	for dd in def.get("dominoes", []):
		var d: Dictionary = dd
		var at: Vector3 = BotonCaida._vec(d.get("pos", [10, 1.0, 0]))
		var step: Vector3 = BotonCaida._vec(d.get("step", [0.5, 0, 0]))
		var size: Vector3 = BotonCaida._vec(d.get("size", [0.12, 0.9, 0.5]))
		for i in int(d.get("n", 5)):
			var slab := RigidBody3D.new()
			slab.mass = 0.8
			slab.collision_layer = Ball.LAYER_WORLD
			slab.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = size
			cs.shape = bs
			slab.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
			mi.material_override = color_mat(Color(0.95, 0.75, 0.2))
			slab.add_child(mi)
			add_child(slab)
			slab.global_position = at + step * float(i) + Vector3.UP * size.y * 0.5
			dominoes.append(slab)
	# La prisionera: pelota dorada, fisica real.
	prisoner = RigidBody3D.new()
	prisoner.mass = 0.42
	# Resistencia a la rodadura en el pasto (la pelota del juego la modela Ball; esta es una esfera comun).
	prisoner.linear_damp = 0.8
	prisoner.angular_damp = 0.5
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
	pmat.bounce = 0.4
	pmat.friction = 0.6
	prisoner.physics_material_override = pmat
	var pmi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	pmi.mesh = sm
	pmi.material_override = color_mat(Color(1.0, 0.82, 0.15), 0.5)
	prisoner.add_child(pmi)
	add_child(prisoner)
	prisoner.global_position = BotonCaida._vec(def.get("prisoner", [12, 1.3, 0]))
	_prisoner_home = prisoner.global_transform
	ball.body_entered.connect(_on_ball_body)
	time_limit = float(def.get("time", 0.0))
	if def.has("parts") or def.has("mechs"):
		mechs = RescueMechs.new()
		mechs.name = "Mechs"
		mechs.fast = fast
		add_child(mechs)
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
		add_child(pmesh)
		pmesh.global_position = Vector3(r.get_center().x, 0.02, r.get_center().y)
	# Señal de la zona de rescate: un arco de llegada con banderines (se entiende a donde tiene que llegar).
	_build_zone_sign()

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
	add_child(cap)
	var facing_up: bool = bool(bd.get("up", false))
	cap.global_transform = Transform3D(Basis() if facing_up else Basis(Vector3(0, 0, 1), PI * 0.5), BotonCaida._vec(bd.get("pos", [10, 1.0, 0])))
	buttons.append({"body": cap, "mesh": mi, "latch": int(bd.get("latch", 0)), "pressed": false,
		"normal": Vector3.UP if facing_up else Vector3(-1, 0, 0), "home": cap.global_transform})

func _on_ball_body(body: Node) -> void:
	if state != State.FLIGHT:
		return
	if mechs != null and mechs.kick_hit(body, prev_velocity().length()):
		return
	for b in buttons:
		if body == b["body"] and not bool(b["pressed"]):
			var impact: float = -prev_velocity().dot(b["normal"])
			if impact >= PRESS_SPEED:
				_press(b)

## Boton apretado: se hunde, se pone verde y su traba desaparece (la compuerta queda libre; lo que siga es gravedad).
func _press(b: Dictionary) -> void:
	b["pressed"] = true
	var cap: Node3D = b["body"]
	cap.global_position += (b["normal"] as Vector3) * -0.08
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
	prisoner.global_transform = _prisoner_home
	prisoner.linear_velocity = Vector3.ZERO
	prisoner.angular_velocity = Vector3.ZERO
	for b in buttons:
		b["pressed"] = false
		(b["body"] as Node3D).global_transform = b["home"]
		(b["mesh"] as MeshInstance3D).material_override = color_mat(Color(0.95, 0.12, 0.1), 0.6)
	for l in latches:
		if is_instance_valid(l):
			(l as Node3D).visible = true
			(l as StaticBody3D).process_mode = Node.PROCESS_MODE_INHERIT
			for c in (l as Node).get_children():
				if c is CollisionShape3D:
					(c as CollisionShape3D).disabled = false
	super.reset_level()

## Encuadre: la prisionera, la zona libre y los botones.
func frame_points() -> Array:
	var out: Array = [_prisoner_home.origin + Vector3.UP * 0.4, Vector3(zone.position.x, 0, zone.position.y), Vector3(zone.end.x, 0, zone.end.y)]
	for b in buttons:
		out.append((b["home"] as Transform3D).origin)
	# Mecanismos: todos los mandos tienen que verse (se tocan sobre la pantalla) y las piezas que mueven.
	if mechs != null:
		for m in mechs.mechs:
			out.append((m["root"] as Node3D).global_position + Vector3.UP * 0.6)
		for pp in mechs.parts:
			out.append((pp["base"] as Transform3D).origin)
	for r in pits:
		out.append(Vector3(r.get_center().x, 0, r.get_center().y))
	return out

## Camara de los niveles de mecanismos: de costado y desde arriba (como un acertijo de perfil), del lado de los mandos,
## con todo el aparato, los mandos, la zona y los pozos adentro del cuadro. Los niveles de patear usan la de siempre.
func camera_frame() -> Array:
	if mechs == null:
		return super.camera_frame()
	var pts: Array = frame_points()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in pts:
		lo = lo.min(p as Vector3)
		hi = hi.max(p as Vector3)
	var c: Vector3 = (lo + hi) * 0.5
	var fov: float = 50.0
	var span: float = maxf(maxf(hi.x - lo.x, hi.z - lo.z), (hi.y - lo.y) * 1.7) + 1.5
	# El cuadro es apaisado: el ancho manda (campo horizontal ~1,6 veces el vertical).
	var dist: float = span * 0.5 / tan(deg_to_rad(fov * 0.5)) * 0.9
	var dir := Vector3(-0.3, 0.62, -1.0).normalized()
	# Mirando un poco por debajo del centro: el aparato queda arriba de los botones del HUD.
	return [c + dir * dist, c + Vector3(0, -1.1, 0), fov, 0.0]

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0, ball.radius if ball != null else 0.11, 0) + BotonCaida._vec(def.get("tee", [0, 0, 0]))

func _aim_point(_s: int) -> Vector3:
	return prisoner.global_position if prisoner != null else Vector3(12, 1, 0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(_aim_point(0).x, Vector2(9.0, 27.0), false, 5.0, 4.5, ball.radius)

func _settling() -> bool:
	if prisoner.linear_velocity.length() > 0.25:
		return true
	for d in dominoes:
		if not d.sleeping and d.linear_velocity.length() > 0.2:
			return true
	return false

func _in_zone() -> bool:
	var p: Vector3 = prisoner.global_position
	return zone.has_point(Vector2(p.x, p.z)) and p.y < 0.5 and prisoner.linear_velocity.length() < 0.6

var _hud_t: float = 0.0
func _level_step(delta: float) -> void:
	if mechs != null:
		mechs.step(delta)
		_hud_t -= delta
		if _hud_t <= 0.0 and state != State.OVER:
			_hud_t = 0.25
			_refresh_score()
	if rescued or state == State.OVER:
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
	# En los niveles de solo patear, sin tiros no queda nada que hacer; con mecanismos sigue el reloj.
	if mechs == null and int(shots[0]) >= shots_max:
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

## La pelota cayo en un pozo (rectangulo rojo, a ras del piso).
func in_pit() -> bool:
	var p: Vector3 = prisoner.global_position
	if p.y > 0.5:
		return false
	for r in pits:
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false

func online_stats() -> Dictionary:
	return stats()

## En los niveles sin patear no hay jugador ni pelota del jugador (se resuelven tocando los mecanismos).
func has_player_deck() -> bool:
	return int(def.get("shots", 3)) > 0

func _place_shooter(s: int) -> void:
	super._place_shooter(s)
	if shots_max <= 0 and def.has("mechs"):
		shooters[s].actor.visible = false
		ball.visible = false

## Otro intento sin cortar la partida: el prisionero y los mecanismos al principio; el reloj y los contadores siguen.
func new_attempt() -> void:
	attempts += 1
	prisoner.global_transform = _prisoner_home
	prisoner.linear_velocity = Vector3.ZERO
	prisoner.angular_velocity = Vector3.ZERO
	if mechs != null:
		mechs.reset()

## Toque sobre la pantalla: si cae sobre un mecanismo es para el (no patea); si no, el trazo de siempre.
func _on_press(pos: Vector2, pressed: bool) -> void:
	if mechs != null and state != State.OVER:
		if not pressed and mechs.held >= 0:
			mechs.touch(mechs.held, false)
			return
		if pressed:
			var i: int = pick_mech(pos)
			if i >= 0:
				mechs.touch(i, true)
				return
	if shots_max <= 0:
		return
	super._on_press(pos, pressed)

## Mando que esta bajo el punto de la pantalla (rayo desde la camara contra las areas de toque), o -1.
func pick_mech(screen: Vector2) -> int:
	if mechs == null or cam == null or not is_inside_tree():
		return -1
	var from: Vector3 = cam.project_ray_origin(screen)
	var to: Vector3 = from + cam.project_ray_normal(screen) * 300.0
	var q := PhysicsRayQueryParameters3D.create(from, to, RescueMechs.PICK_LAYER)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return RescueMechs.mech_of(hit.get("collider")) if not hit.is_empty() else -1

func _on_action(id: StringName) -> void:
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
			hud.show_banner("ORDEN EQUIVOCADO", Color(1.0, 0.45, 0.35), "Mirá las luces de la cerradura")

## Zona de rescate bien señalizada: dos postes con un cartel RESCATE y banderines alrededor.
func _build_zone_sign() -> void:
	var c: Vector2 = zone.get_center()
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.05
		cm.height = 1.6
		post.mesh = cm
		post.material_override = color_mat(Color(0.9, 0.9, 0.95))
		add_child(post)
		post.global_position = Vector3(zone.end.x + 0.15, 0.8, c.y + side * zone.size.y * 0.5)
	var sign := Label3D.new()
	sign.text = "RESCATE"
	sign.font_size = 96
	sign.outline_size = 16
	sign.modulate = Color(0.4, 1.0, 0.5)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)
	sign.global_position = Vector3(zone.end.x + 0.15, 1.75, c.y)

func _report_achievements(w: int, medal: int) -> void:
	super._report_achievements(w, medal)
	if rescued:
		Achievements.event(&"rescate")

func _result_text(r: String) -> Array:
	if r == "rescatada":
		if mechs != null:
			var st: Dictionary = stats()
			return ["¡RESCATADA!", Color(0.35, 1.0, 0.45), "%.1f s · %d acciones · %d errores · %d intentos" % [float(st["time"]),
				int(st["actions"]), int(st["errors"]) + int(st["falls"]), int(st["attempts"])]]
		return ["¡RESCATADA!", Color(0.35, 1.0, 0.45), "En %d tiros" % int(shots[0])]
	if r == "tiempo":
		return ["SE ACABÓ EL TIEMPO", Color(1.0, 0.45, 0.35), "Sigue atrapada"]
	if mechs != null:
		return ["", Color.WHITE, ""]
	return ["Sigue atrapada", Color(1.0, 0.75, 0.4), "Tiros %d de %d" % [int(shots[0]), shots_max]]

func _refresh_score() -> void:
	if mechs != null:
		var left: String = ("%d s" % int(ceil(maxf(time_limit - level_time, 0.0)))) if time_limit > 0.0 else "%d s" % int(level_time)
		hud.set_score_text("Rescate · %s · acciones %d · errores %d" % [left, mechs.actions + int(shots[0]), mechs.errors + falls])
		return
	hud.set_score_text("Rescate · tiros %d / %d" % [int(shots[0]), shots_max])
