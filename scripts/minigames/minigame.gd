class_name Minigame
extends Node3D
## Base compartida de los minijuegos arcade por turnos (etapa 6 de las correcciones; catalogo de 43 en
## docs/AAA_ROADMAP.md, «Arcade Football»). No trae fisica ni controles propios: reutiliza los del juego.
##  - El trazo del dedo: ShotGesture + GestureShotModel (potencia, altura, efecto, tipo de tiro), con el rastro del dedo y
##    la vista previa (TrajectoryPreview, respeta «Mostrar linea de destino de la pelota»).
##  - La pelota fisica (Ball: Jolt, arrastre, Magnus, rodadura) y el solucionador del tiro (ShotSolver/BallPredictor).
##  - El tirador animado del banco JSON (SpShooter + ShotCatalog): la pelota sale en el contacto real del pie.
##  - La camara (SpCamera, con temblor configurable) y la interfaz (SpHud).
## Cada minijuego (subclase) define su id, sus reglas, su geometria y su IA; la base garantiza:
##  - Estados con salida siempre: INTRO (objetivo breve) -> AIM -> RUNUP -> FLIGHT -> RESOLVE -> AIM/OVER. El vuelo tiene
##    tope de tiempo, la pelota que cae al vacio o se frena termina el tiro, la carrera tiene tope y el partido tiene tope de
##    turnos: nada queda en bucle.
##  - Turnos (uno o dos lados), puntos, reinicio del nivel (reset_level) y resultado final con medalla (PlayerProgress).
##  - IA con las mismas reglas y la misma fisica: patea con un ShotParams igual al del usuario (ShotSolver) con error de
##    precision por dificultad; no mueve la pelota ni sabe nada que el usuario no vea.
##  - Lista para jugar en linea MAS ADELANTE (no implementado, sin matchmaking): cada accion es una intencion serializable
##    (apply_intent: lado, velocidad, giro) registrada en `intents`, y el azar sale de una semilla del partido.

signal turn_started(side: int)
signal shot_resolved(side: int, result: String)
signal match_over(winner: int)

enum Side { USER, CPU }
enum State { INTRO, AIM, RUNUP, FLIGHT, RESOLVE, OVER }

const BALL_SCENE := preload("res://scenes/ball/ball.tscn")
const STANCE := Vector2(2.4, 2.3)
## Topes de cada etapa (s): ningun tiro queda abierto.
const MAX_RUNUP := 6.0
const MAX_FLIGHT := 7.0
const SLOW_SPEED := 0.35
const SLOW_TIME := 0.7
const KILL_Y := -3.0
const RESOLVE_T := 2.2
## Pensar de la IA antes de patear (s).
const CPU_THINK := 0.9
## Espera maxima de la IA buscando su momento (s); despues patea igual.
const CPU_MAX_WAIT := 3.0

## Nivel a cargar (lo pone el menu antes de cambiar de escena).
static var next_def: Dictionary = {}

var def: Dictionary = {}
var state: int = State.INTRO
var side: int = Side.USER
var sides: int = 2
var points := [0, 0]
var shots := [0, 0]
var turn_n: int = 0
var max_turns: int = 24
var winner: int = -1
var last_result: String = ""
var rng := RandomNumberGenerator.new()
var match_seed: int = 0
## Intenciones aplicadas (para repetir o jugar en linea mas adelante): [{side, v, w, turn}].
var intents: Array = []
## Pruebas y mediciones: sin pausas de presentacion.
var fast: bool = false
## Cuanto tardo la ultima carrera hasta el contacto (s): la IA lo usa para adelantar objetivos que se mueven.
var runup_time: float = 1.2
## La IA ya espero lo maximo: tiene que patear en este paso.
var cpu_force: bool = false
## true: el minijuego lleva su propio flujo por paso (_custom_step) en vez de la maquina AIM/RUNUP/FLIGHT.
var custom_flow: bool = false
## Tiempo del nivel (s) y objetos que van y vienen o giran (compartidos por los minijuegos): cada entrada es
## {body, base (Transform3D), axis, amp, speed, phase, spin_axis, spin} (+ lo que agregue el minijuego).
var level_time: float = 0.0
var movers: Array = []

var ball: Ball
var cam: SpCamera
var hud: SpHud
var preview: TrajectoryPreview
var gesture: ShotGesture
var shooters: Array[SpShooter] = []
var _swiping: bool = false
var _preview_t: float = 0.0
var _t: float = 0.0
var _slow_t: float = 0.0
var _ball_start := Vector3.ZERO
var _prev_v := Vector3.ZERO

# --- Para las subclases ------------------------------------------------------------------------------------------------

## Identificador unico del minijuego (records: "mg_<id>_<nivel>").
func game_id() -> String:
	return "minigame"

## Arma la geometria del nivel (def).
func _build_level() -> void:
	pass

## Punto de la pelota de cada lado.
func _ball_spot(_s: int) -> Vector3:
	return Vector3.ZERO

## Hacia donde patea cada lado (centro del objetivo): orienta al tirador, la camara y el plano del trazo.
func _aim_point(_s: int) -> Vector3:
	return Vector3(10, 1, 0)

## Contexto del trazo: el «arco» es el plano del objetivo (x = plano), con su ancho y alto.
func _shot_ctx(s: int) -> Dictionary:
	var a: Vector3 = _aim_point(s)
	return GestureShotModel.context(a.x, Vector2(12.0, 30.0), false, 4.0, 4.0, ball.radius)

## Revisa el vuelo cada paso: "" sigue; cualquier otro texto termina el tiro con ese resultado.
func _flight_check(_delta: float) -> String:
	return ""

## Algo del nivel todavia se mueve despues del tiro (bloques cayendo): la pelota quieta no termina el tiro; sigue
## valiendo el tope de vuelo.
func _settling() -> bool:
	return false

## Resultado de un tiro terminado (puntos, mecanismos). La base ya conto el tiro.
func _on_resolved(_s: int, _result: String) -> void:
	pass

## Ganador si ya lo hay (-1 si sigue).
func _check_winner() -> int:
	return -1

## Intencion de la IA para su turno (misma forma que la del usuario).
func _cpu_intent() -> Dictionary:
	return {}

## Paso propio de los modos con flujo custom (custom_flow = true).
func _custom_step(_delta: float) -> void:
	pass

## Movimiento del nivel (mecanismos propios) en cada paso; los `movers` ya se movieron.
func _level_step(_delta: float) -> void:
	pass

## Registra un objeto que va y viene (axis/amp/speed/phase, en el mundo) o gira (spin_axis/spin rad/s).
func add_mover(body: Node3D, axis: Vector3, amp: float, speed: float, phase: float = 0.0,
		spin_axis: Vector3 = Vector3.RIGHT, spin: float = 0.0) -> Dictionary:
	var m := {"body": body, "base": body.global_transform, "axis": axis.normalized() if axis != Vector3.ZERO else Vector3.ZERO,
		"amp": amp, "speed": speed, "phase": phase, "spin_axis": spin_axis.normalized(), "spin": spin}
	movers.append(m)
	return m

## Donde esta (o va a estar) un objeto movil en el instante t: su vaiven es deterministico, la IA puede mirarlo.
func mover_at(m: Dictionary, t: float) -> Transform3D:
	var base: Transform3D = m["base"]
	var x := base
	if float(m["spin"]) != 0.0:
		x.basis = Basis(m["spin_axis"], t * float(m["spin"])) * base.basis
	if (m["axis"] as Vector3) != Vector3.ZERO:
		x.origin = base.origin + (m["axis"] as Vector3) * float(m["amp"]) * sin(t * float(m["speed"]) + float(m["phase"]))
	return x

## Puntaje final del usuario (para record y medalla).
func final_score() -> int:
	return points[0] * 100

## Textos del resultado de un tiro.
func _result_text(_result: String) -> Array:
	return ["", Color.WHITE]

# --- Armado ------------------------------------------------------------------------------------------------------------

func _ready() -> void:
	if def.is_empty():
		def = next_def
	match_seed = int(def.get("seed", 0)) if def.has("seed") else randi()
	rng.seed = match_seed
	ball = BALL_SCENE.instantiate()
	ball.name = "Ball"
	add_child(ball)
	cam = SpCamera.new()
	cam.name = "Camera"
	add_child(cam)
	cam.current = true
	hud = SpHud.new()
	add_child(hud)
	hud.menu_pressed.connect(_go_menu)
	hud.action_pressed.connect(_on_action)
	hud.hide_shootout()
	hud.set_zoom_visible(false)
	preview = TrajectoryPreview.new()
	add_child(preview)
	gesture = ShotGesture.new(GestureTuning.current(), 720.0)
	_build_world()
	_build_level()
	_dress_arcade()
	for s in sides:
		var sh := SpShooter.new()
		sh.name = "Shooter%d" % s
		add_child(sh)
		var a := SpActor.new()
		a.name = "Player%d" % s
		add_child(a)
		a.build(PlayerCustom.kit() if s == 0 else SpSettings.CPU_KIT)
		if s == 0:
			a.set_back_number(PlayerCustom.number)
		a.team = s
		a.enable_collider()
		sh.setup(a, ball)
		sh.foot = SpSettings.foot if s == 0 else 1
		sh.rng.seed = match_seed + 17 * s
		sh.contact.connect(_on_contact)
		shooters.append(sh)
	ShotCatalog.clips()
	GraphicsSettings.apply()
	hud.set_title(String(def.get("title", "MINIJUEGO")).to_upper())
	_refresh_score()
	if fast:
		start_match()
	else:
		_show_intro()

## Cielo, luz y entorno comunes (livianos: una luz, sin niebla; sombras segun el perfil grafico).
func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.18, 0.36, 0.78)
	mat.sky_horizon_color = Color(0.62, 0.74, 0.92)
	mat.ground_bottom_color = Color(0.05, 0.06, 0.12)
	mat.ground_horizon_color = Color(0.35, 0.4, 0.55)
	sky.sky_material = mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.1
	sun.add_to_group("sun_light")
	sun.shadow_enabled = GraphicsSettings.shadows_enabled()
	add_child(sun)

## Caja estatica con material de color (piso, paredes, obstaculos).
func static_box(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, bounce: float = 0.45) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = Ball.LAYER_WORLD
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = 0.7
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = color_mat(color)
	b.add_child(mi)
	add_child(b)
	b.global_position = pos
	b.rotation = rot
	return b

static func color_mat(c: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m

# --- Partido -----------------------------------------------------------------------------------------------------------

func _show_intro() -> void:
	state = State.INTRO
	var obj: String = String(def.get("objective", ""))
	hud.show_overlay(String(def.get("title", "")), obj, [[&"play", "Jugar"], [&"menu", "Menú"]])

func start_match() -> void:
	hud.hide_overlay()
	points = [0, 0]
	shots = [0, 0]
	turn_n = 0
	winner = -1
	intents = []
	level_time = 0.0
	side = Side.USER
	reset_level()
	_start_turn()

## Vuelve el nivel a su estado inicial (mecanismos, jugadores, pelota). Las subclases lo amplian.
func reset_level() -> void:
	for s in shooters.size():
		_place_shooter(s)

func _place_shooter(s: int) -> void:
	var sh: SpShooter = shooters[s]
	var spot: Vector3 = _ball_spot(s)
	var aim: Vector3 = Vector3(_aim_point(s).x - spot.x, 0.0, _aim_point(s).z - spot.z).normalized()
	sh.actor.visible = true
	if sh.actor.collider != null:
		sh.actor.collider.collision_layer = Ball.LAYER_PLAYERS
	sh.actor.ground_y = spot.y - ball.radius
	sh.stance(spot, aim, STANCE.x, STANCE.y)
	sh.actor.global_position.y = sh.actor.ground_y

# --- Estilo arcade comun (plataforma del jugador y estadio de noche) ----------------------------------------------------

## Altura de la plataforma del jugador en este minijuego (0 = a nivel del piso). Cada modo da la suya; el nivel la puede
## cambiar con "deck_h". Los modos que la usan suman deck_y() a su lugar de la pelota.
func default_deck() -> float:
	return 0.0

func deck_y() -> float:
	return float(def.get("deck_h", default_deck()))

## false en los modos que arman su propia plataforma (Boton de caida, Duelo del guante).
func has_player_deck() -> bool:
	return true

## true en los modos que usan el estadio de noche comun (tribunas, torres de luces, banderas).
func uses_night_arena() -> bool:
	return false

## false en los modos con vacio debajo (Boton de caida): el estadio sin piso.
func arena_floor() -> bool:
	return true

func _dress_arcade() -> void:
	if ball == null:
		return
	var spot: Vector3 = _ball_spot(0)
	if uses_night_arena():
		var aim: Vector3 = _aim_point(0)
		var c := Vector3((spot.x + aim.x) * 0.5, 0, (spot.z + aim.z) * 0.5)
		ArcadeLook.night_arena(self, c, absf(aim.x - spot.x) + 20.0, 18.0, arena_floor())
	if has_player_deck():
		ArcadeLook.player_deck(self, spot, spot.y - ball.radius, ball.radius)

## true en los modos donde los dos jugadores estan en escena a la vez (duelos cara a cara).
func shows_both_players() -> bool:
	return false

## Saca de escena al jugador s (relevo): invisible y sin colision con la pelota.
func _bench(s: int) -> void:
	var a: SpActor = shooters[s].actor
	a.visible = false
	if a.collider != null:
		a.collider.collision_layer = 0

## Donde espera cada jugador (su lugar al costado de la pelota).
func stance_point(s: int) -> Vector3:
	var spot: Vector3 = _ball_spot(s)
	var a: Vector3 = Vector3(_aim_point(s).x - spot.x, 0.0, _aim_point(s).z - spot.z).normalized()
	var foot: int = shooters[s].foot if s < shooters.size() else 1
	return Vector3(spot.x, spot.y - ball.radius, spot.z) - a * STANCE.x - SpClips.right_of(a) * STANCE.y * float(foot)

func _start_turn() -> void:
	if turn_n >= max_turns:
		_end_match(_tiebreak())
		return
	last_result = ""
	_place_shooter(side)
	# Por turnos, en escena solo el que patea (relevo): el otro sale y su cuerpo no choca con la pelota. Solo los duelos
	# cara a cara (Boton de caida, Duelo del guante) muestran a los dos.
	if not shows_both_players():
		for s in shooters.size():
			if s != side:
				_bench(s)
	var spot: Vector3 = _ball_spot(side)
	ball.reset_at(spot)
	_frame_camera(true)
	state = State.AIM
	_t = 0.0
	turn_started.emit(side)
	if side == Side.USER:
		hud.set_hint(String(def.get("hint", "Deslizá el dedo desde la pelota hacia el objetivo")))
		hud.set_actions([[&"camera", "Cámara"], [&"restart", "Reiniciar"]])
	else:
		hud.set_hint("Patea la CPU…")
		hud.set_actions([])

## Puntos que TIENEN que verse en el turno, ademas de la pelota, el jugador que patea y el objetivo (las subclases agregan
## los suyos: el rival, botones, bolos, aros, placas...).
func frame_points() -> Array:
	return []

## Camara recomendada del minijuego (valores de antes del cambio que la alejo, recuperados de Git, commit 05c100e:
## SpCamera.behind_ball de tiro libre: 10,5 m detras, 5,4 m de alto, mira 5,5 m por delante de la pelota, 44 grados).
## back/height/ahead en metros; lift_aim: cuanto de la altura del objetivo se suma a la mirada; follow: semivida (s).
func camera_defaults() -> Dictionary:
	return {"back": 10.5, "height": 5.4, "ahead": 5.5, "lift_aim": 0.0, "fov": 44.0, "follow": 0.45}

## Altura del piso desde el que se mide la camara (plataformas elevadas).
func camera_base_y() -> float:
	# La altura de la pelota (sobre la plataforma del jugador, si esta elevada).
	return _ball_spot(side).y - (ball.radius if ball != null else 0.11)

## Encuadre del turno: detras de la pelota mirando al objetivo, con los valores recomendados del minijuego y los ajustes
## que el usuario guardo para ESTE minijuego (CameraPrefs).
func _frame_camera(instant: bool) -> void:
	var f: Array = camera_frame()
	cam.frame(f[0], f[1], f[2], instant, f[3])

## [posicion, mirada, fov, seguimiento] de la camara del turno.
func camera_frame() -> Array:
	var spot: Vector3 = _ball_spot(side)
	var aim: Vector3 = _aim_point(side)
	var c: Dictionary = CameraPrefs.effective(game_id(), camera_defaults())
	var dir := Vector3(aim.x - spot.x, 0.0, aim.z - spot.z)
	dir = dir.normalized() if dir.length() > 0.05 else Vector3(1, 0, 0)
	var base := Vector3(spot.x, camera_base_y(), spot.z)
	var pos: Vector3 = base - dir * float(c["back"]) + Vector3.UP * float(c["height"])
	var look: Vector3 = base + dir * float(c["ahead"]) + Vector3.UP * (aim.y - camera_base_y()) * float(c["lift_aim"])
	return [pos, look, float(c["fov"]), float(c["follow"])]

## Aplica una intencion (usuario, IA o, mas adelante, la red): el tirador corre y patea con esa salida de la pelota.
func apply_intent(intent: Dictionary) -> void:
	if state != State.AIM or int(intent.get("side", -1)) != side:
		return
	var v: Vector3 = intent["v"]
	var w: Vector3 = intent.get("w", Vector3.ZERO)
	intents.append({"side": side, "v": v, "w": w, "turn": turn_n})
	var sh: SpShooter = shooters[side]
	var spot: Vector3 = _ball_spot(side)
	var e: Dictionary = kick_entry(sh.foot, spot, v, _aim_point(side), rng)
	var dir := Vector3(v.x, 0.0, v.z).normalized()
	preview.hide_path()
	hud.hide_gesture()
	hud.set_trail(PackedVector2Array())
	hud.set_hint("")
	hud.set_actions([])
	state = State.RUNUP
	_t = 0.0
	if e.is_empty():
		ball.kick(v, w, sh.actor)
		_on_contact({})
		return
	sh.execute(e, spot, dir, v, w)

## Pruebas y mediciones: patea sin la carrera del tirador (la pelota sale ya desde su punto con esa velocidad y giro).
## (Corrutina: la pelota se ubica en un paso de fisica y sale en el siguiente.)
func launch(v: Vector3, w: Vector3 = Vector3.ZERO) -> void:
	state = State.RUNUP
	_t = 0.0
	ball.reset_at(_ball_spot(side))
	await get_tree().physics_frame
	await get_tree().physics_frame
	ball.kick(v, w, shooters[side].actor if side < shooters.size() else null)
	intents.append({"side": side, "v": v, "w": w, "turn": turn_n})
	_on_contact({})

## Golpeo del banco para una salida v desde ball_pos (el mismo criterio que el tiro libre: pie, direccion y potencia).
static func kick_entry(foot: int, ball_pos: Vector3, v: Vector3, aim_center: Vector3, r: RandomNumberGenerator) -> Dictionary:
	var dir := Vector3(v.x, 0.0, v.z).normalized()
	var center := Vector3(aim_center.x - ball_pos.x, 0.0, aim_center.z - ball_pos.z).normalized()
	var app: Vector3 = ShotCatalog.approach_dir(center, foot)
	var rel: float = ShotCatalog.signed_deg(app, dir)
	var kind: int = ShotCatalog.Kind.POWER if v.length() > 25.0 else (ShotCatalog.Kind.CHIP if v.y > v.length() * 0.55 else ShotCatalog.Kind.NORMAL)
	var e: Dictionary = ShotCatalog.choose(foot, rel, kind, true, r, v.length())
	if e.is_empty():
		e = ShotCatalog.choose(foot, rel, ShotCatalog.Kind.NORMAL, false, r)
	return e

func _on_contact(_entry: Dictionary) -> void:
	if state != State.RUNUP:
		return
	runup_time = _t
	state = State.FLIGHT
	shots[side] += 1
	_t = 0.0
	_slow_t = 0.0
	_ball_start = ball.global_position

func _physics_process(delta: float) -> void:
	level_time += delta
	for m in movers:
		(m["body"] as Node3D).global_transform = mover_at(m, level_time)
	_level_step(delta)
	_t += delta
	if custom_flow:
		# Modos de peloteo: llevan su propio flujo (la base sigue dando movers, HUD, puntaje y final de partida).
		_custom_step(delta)
		_prev_v = ball.linear_velocity
		return
	match state:
		State.AIM:
			if side == Side.CPU and _t >= (0.05 if fast else CPU_THINK):
				# La IA puede esperar su momento (obstaculos que se mueven), con tope: CPU_MAX_WAIT.
				cpu_force = _t >= (0.05 if fast else CPU_THINK) + CPU_MAX_WAIT
				var it: Dictionary = _cpu_intent()
				if not it.is_empty():
					it["side"] = Side.CPU
					apply_intent(it)
			elif side == Side.USER and _swiping:
				_update_preview(delta)
		State.RUNUP:
			if _t > MAX_RUNUP:
				shooters[side].force_contact()
				if state == State.RUNUP:
					ball.kick(intents.back()["v"], intents.back()["w"], shooters[side].actor)
					_on_contact({})
		State.FLIGHT:
			var r: String = _flight_check(delta)
			if r == "":
				r = _flight_watchdog(delta)
			if r != "":
				_resolve(r)
		State.RESOLVE:
			if _t >= (0.1 if fast else RESOLVE_T):
				_after_resolve()
	_prev_v = ball.linear_velocity

## Topes comunes del vuelo: cayo al vacio, se freno o se paso de tiempo.
func _flight_watchdog(delta: float) -> String:
	if ball.global_position.y < KILL_Y:
		return "vacio"
	if _t > MAX_FLIGHT:
		return "tiempo"
	if _t > 0.5 and ball.linear_velocity.length() < SLOW_SPEED and not _settling():
		_slow_t += delta
		if _slow_t >= SLOW_TIME:
			return "quieta"
	else:
		_slow_t = 0.0
	return ""

## Velocidad de la pelota en el paso anterior (antes de un choque).
func prev_velocity() -> Vector3:
	return _prev_v

func _resolve(r: String) -> void:
	if state != State.FLIGHT:
		return
	state = State.RESOLVE
	last_result = r
	_t = 0.0
	_on_resolved(side, r)
	shot_resolved.emit(side, r)
	var txt: Array = _result_text(r)
	if String(txt[0]) != "":
		hud.show_banner(txt[0], txt[1], String(txt[2]) if txt.size() > 2 else "")
	var joy: float = crowd_cheer(r, txt)
	if joy > 0.0:
		ArcadeLook.cheer(self, joy)
	else:
		var anger: float = crowd_boo(r, txt)
		if anger > 0.0:
			ArcadeLook.boo(self, anger, 2.0)
	_refresh_score()

## Cuanto festeja el publico del estadio este resultado (0 nada .. 1 todos). Por defecto, por el color del cartel: verde
## (un buen tiro del usuario) festejan todos; amarillo (un avance) solo los mas animados y solo si pateo el usuario; rojo
## o naranja (error, o un buen tiro de la CPU), nada. Un modo puede decidirlo por su cuenta.
func crowd_cheer(_r: String, txt: Array) -> float:
	if String(txt[0]) == "" or txt.size() < 2:
		return 0.0
	var c: Color = txt[1]
	if c.g >= 0.95 and c.r < 0.6:
		return 1.0
	if c.g >= 0.8 and c.b < 0.5 and side == Side.USER:
		return 0.3
	return 0.0

## Cuanto abuchea el publico (0 nada .. 1 todos; manos a la cabeza y silbidos): un error del usuario (cartel rojo o
## naranja en su turno). Lo mismo que en penales y tiros libres (pedido 2026-11-12). Un modo puede decidirlo por su cuenta.
func crowd_boo(_r: String, txt: Array) -> float:
	if String(txt[0]) == "" or txt.size() < 2 or side != Side.USER:
		return 0.0
	var c: Color = txt[1]
	if c.r >= 0.9 and c.g < 0.7:
		return 0.6
	return 0.0

func _after_resolve() -> void:
	if state != State.RESOLVE:
		return
	hud.hide_banner()
	var w: int = _check_winner()
	if w >= 0:
		_end_match(w)
		return
	turn_n += 1
	if sides > 1:
		side = _next_side()
	_start_turn()

## Quien juega el proximo turno (el bowling repite el lado dentro del mismo cuadro).
func _next_side() -> int:
	return (side + 1) % sides

## Empate al llegar al tope de turnos: gana quien mas puntos tiene; si siguen iguales, el usuario no gana (sin premio por
## participar).
func _tiebreak() -> int:
	if points[0] > points[1]:
		return Side.USER
	if sides > 1 and points[1] > points[0]:
		return Side.CPU
	return Side.CPU if sides > 1 else -1

func _end_match(w: int) -> void:
	state = State.OVER
	winner = w
	match_over.emit(w)
	# La dificultad multiplica el puntaje (menos tiros o una IA mejor valen mas); los umbrales de medalla no cambian.
	var score: int = int(round(final_score() * (MinigameCatalog.DIFF_SCORE[int(def["difficulty"])] if def.has("difficulty") else 1.0)))
	var medal: int = medal_for(score) if w == Side.USER or sides == 1 else 0
	var rec: Dictionary = {}
	if not bool(def.get("practice", false)) and def.has("id"):
		rec = PlayerProgress.record(def, score, medal, int(def.get("difficulty", -1)))
		if not fast:
			_report_achievements(w, medal)
	var won: bool = w == Side.USER
	if (won and sides > 1) or (sides == 1 and medal > 0):
		ArcadeLook.cheer(self, 1.0, 4.0)
	var t: String = ("¡GANASTE!" if won else "PERDISTE") if sides > 1 else ("¡SUPERADO!" if medal > 0 else "SIN MEDALLA")
	var info: String = "Puntos: %d · %s" % [score, ChallengeScore.MEDAL_NAMES[medal]]
	if bool(rec.get("new_best", false)):
		info += " · ¡Nuevo récord!"
	# Online contra bot (OnlineDuel): el resultado del duelo y su premio.
	if OnlineDuel.is_active() and def.has("online_bot"):
		var od: Array = OnlineDuel.finish(final_score(), 1 if won else 0)
		t = String(od[0])
		info = String(od[1]) + " · " + info
	hud.set_hint("")
	hud.show_overlay(t, info, [[&"retry", "Otra vez"], [&"next", "Siguiente nivel"], [&"menu", "Menú"]])

## Logros y desafios diarios del resultado (las subclases agregan los suyos). Solo fuera de practica y de pruebas.
func _report_achievements(w: int, medal: int) -> void:
	if (sides > 1 and w == Side.USER) or (sides == 1 and medal > 0):
		Achievements.event(&"arcade")
	if medal >= 3:
		Achievements.event(&"oro")

## Medalla del puntaje con los umbrales del nivel ([bronce, plata, oro]).
func medal_for(score: int) -> int:
	return ChallengeScore.medal_for(score, def.get("medals", [100, 200, 300]))

func _refresh_score() -> void:
	if sides > 1:
		hud.set_score_text("Vos %d - %d %s" % [points[0], points[1], String(def.get("online_bot", "CPU"))])
	else:
		hud.set_score_text("Tiros %d" % shots[0])

# --- Entrada -----------------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Con el panel de camara abierto los toques son para el panel: no se patea.
	if camera_panel_open():
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_on_press(st.position, st.pressed)
	elif event is InputEventScreenDrag:
		_on_drag((event as InputEventScreenDrag).position)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _on_press(pos: Vector2, pressed: bool) -> void:
	if state != State.AIM or side != Side.USER:
		return
	if pressed:
		_swiping = true
		gesture.tuning = GestureTuning.current()
		var h: float = get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0
		gesture.begin(pos, _now(), h)
		_preview_t = 0.0
	elif _swiping:
		_swiping = false
		gesture.finish(pos, _now())
		hud.set_trail(PackedVector2Array())
		preview.hide_path()
		hud.hide_gesture()
		var p: ShotParams = _params_from_gesture()
		if p != null and p.velocity != Vector3.ZERO:
			apply_intent({"side": Side.USER, "v": ShotSolver.perturb(p.velocity, p.error_deg, rng), "w": p.spin})

func _on_drag(pos: Vector2) -> void:
	if state == State.AIM and _swiping and gesture.add(pos, _now()):
		hud.set_trail(gesture.points_px())

func _params_from_gesture() -> ShotParams:
	if gesture.count() < 3:
		return null
	var f: Dictionary = gesture.features()
	if float(f["length"]) < gesture.tuning.min_length:
		return null
	var spot: Vector3 = _ball_spot(Side.USER)
	var ctx: Dictionary = _shot_ctx(Side.USER)
	var p: ShotParams = GestureShotModel.build(f, gesture.last_px(), cam, spot, ctx, gesture.tuning)
	GestureShotModel.solve(p, spot, ctx, false)
	return p

func _update_preview(delta: float) -> void:
	_preview_t -= delta
	if _preview_t > 0.0 or gesture.count() < 3:
		return
	_preview_t = 1.0 / 15.0
	var f: Dictionary = gesture.features()
	if float(f["length"]) < gesture.tuning.min_length * 0.6:
		preview.hide_path()
		return
	var spot: Vector3 = _ball_spot(Side.USER)
	var ctx: Dictionary = _shot_ctx(Side.USER)
	var p: ShotParams = GestureShotModel.build(f, gesture.last_px(), cam, spot, ctx, gesture.tuning)
	GestureShotModel.solve(p, spot, ctx, true)
	if GraphicsSettings.show_aim_line:
		preview.show_path(p.trajectory, float(ctx["plane_x"]), p.power, cam.global_position, p.crossing)
	else:
		preview.hide_path()
	hud.show_gesture(p.power, clampf(p.target.y / 4.0, 0.0, 1.2), clampf(p.lateral_spin / gesture.tuning.spin_max, -1.0, 1.0), "")

## IA: tiro hacia `target` con la misma fisica y el mismo modelo que el usuario (ShotSolver), velocidad `speed`, efecto
## lateral `spin_y` y error de precision `error_deg` (grados).
func cpu_shot(target: Vector3, speed: float, spin_y: float, error_deg: float) -> Dictionary:
	var spot: Vector3 = _ball_spot(side)
	var spin := Vector3(0.0, spin_y, 0.0)
	var sol: Dictionary = ShotSolver.solve(spot, target, speed, spin, target.x)
	var v: Vector3 = sol.get("velocity", (target - spot).normalized() * speed)
	return {"v": ShotSolver.perturb(v, error_deg, rng), "w": spin, "aim": target, "solved": sol.get("crossing", Vector3.INF),
		"trajectory": sol.get("trajectory", PackedVector3Array())}

func _on_action(id: StringName) -> void:
	match id:
		&"play":
			start_match()
		&"camera":
			toggle_camera_panel()
		&"restart", &"retry":
			start_match()
		&"next":
			var nd: Dictionary = MinigameCatalog.next_level(def)
			if nd.is_empty():
				_go_menu()
			else:
				if def.has("difficulty"):
					nd = MinigameCatalog.at_difficulty(nd, int(def["difficulty"]))
				nd["practice"] = bool(def.get("practice", false))
				next_def = nd
				get_tree().reload_current_scene()
		&"menu":
			_go_menu()

# --- Ajustes de camara de este minijuego -------------------------------------------------------------------------------

var _cam_panel: PanelContainer = null
var _cam_labels: Dictionary = {}

func camera_panel_open() -> bool:
	return _cam_panel != null and _cam_panel.visible

## Panel «Camara»: distancia, altura, encuadre y seguimiento con − y +, «Restablecer» (vuelve a los valores recomendados
## de ESTE minijuego) y «Listo». Cada cambio se ve en el momento y se guarda solo para este minijuego.
func toggle_camera_panel() -> void:
	if _cam_panel == null:
		_build_camera_panel()
	_cam_panel.visible = not _cam_panel.visible
	_swiping = false
	hud.set_trail(PackedVector2Array())
	_refresh_camera_panel()

func _build_camera_panel() -> void:
	_cam_panel = PanelContainer.new()
	_cam_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_cam_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cam_panel.position.x = 16
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.92)
	sb.border_color = Color(1.0, 0.84, 0.28, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	_cam_panel.add_theme_stylebox_override("panel", sb)
	hud.root.add_child(_cam_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_cam_panel.add_child(vb)
	var t := Label.new()
	t.text = "Cámara de este minijuego"
	t.add_theme_font_size_override("font_size", 22)
	vb.add_child(t)
	for k in ["back", "height", "ahead", "follow"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(64, 52)
		minus.focus_mode = Control.FOCUS_NONE
		minus.pressed.connect(func() -> void: _nudge_camera(k, -1))
		row.add_child(minus)
		var l := Label.new()
		l.custom_minimum_size = Vector2(210, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 19)
		row.add_child(l)
		_cam_labels[k] = l
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(64, 52)
		plus.focus_mode = Control.FOCUS_NONE
		plus.pressed.connect(func() -> void: _nudge_camera(k, 1))
		row.add_child(plus)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	vb.add_child(bottom)
	var reset := Button.new()
	reset.text = "Restablecer"
	reset.focus_mode = Control.FOCUS_NONE
	reset.custom_minimum_size = Vector2(170, 52)
	reset.pressed.connect(func() -> void:
		CameraPrefs.reset(game_id())
		_frame_camera(false)
		_refresh_camera_panel())
	bottom.add_child(reset)
	var done := Button.new()
	done.text = "Listo"
	done.focus_mode = Control.FOCUS_NONE
	done.custom_minimum_size = Vector2(170, 52)
	done.pressed.connect(func() -> void: _cam_panel.visible = false)
	bottom.add_child(done)
	_cam_panel.visible = false

func _nudge_camera(key: String, dir: int) -> void:
	CameraPrefs.nudge(game_id(), key, dir)
	_frame_camera(false)
	_refresh_camera_panel()

func _refresh_camera_panel() -> void:
	if _cam_panel == null:
		return
	var o: Dictionary = CameraPrefs.offsets(game_id())
	var e: Dictionary = CameraPrefs.effective(game_id(), camera_defaults())
	var txt := {"back": "Distancia %.1f m", "height": "Altura %.1f m", "ahead": "Encuadre %.1f m", "follow": "Seguimiento %.2f s"}
	for k in _cam_labels:
		(_cam_labels[k] as Label).text = (txt[k] % float(e[k])) + ("" if absf(float(o[k])) < 0.001 else " *")

## Vuelve a MINIJUEGOS ARCADE (a la modalidad que se estaba jugando).
func _go_menu() -> void:
	SpSettings.override_difficulty = -1
	if is_inside_tree():
		ChallengeMenu.section = "arcade"
		get_tree().change_scene_to_file(ChallengeMenu.SCENE)
