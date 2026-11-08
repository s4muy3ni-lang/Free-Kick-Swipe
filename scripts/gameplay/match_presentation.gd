class_name MatchPresentation
extends Node3D
## Actores ambientales del partido: seleccion contextual, una pose por actor y movimiento de raiz.
## Los actores no participan de colisiones ni de la posesion. Comparten los recursos del esqueleto canonico.

const ROUTES_PATH := "res://resources/animation/environment_routes.json"
var ctx: MatchContext
var routes: Dictionary = {}
var actors: Dictionary = {}
var cursors: Dictionary = {}
var invocations: Dictionary = {}
var _pools: Dictionary = {}
var rng := RandomNumberGenerator.new()

func setup(context: MatchContext) -> void:
	ctx = context
	rng.randomize()
	routes = AnimDB.presentation_routes()
	for id in routes:
		var route: Dictionary = routes[id]
		var key: String = route["actor"] + "/" + route["context"]
		if not _pools.has(key):
			_pools[key] = []
		_pools[key].append(StringName(id))
		var mirror := StringName(id + "_mirror")
		if PackLibrary.has_clip(mirror):
			_pools[key].append(mirror)
	ctx.event_emitted.connect(_on_event)

## Una solicitud individual pasa por las mismas condiciones que el selector de eventos. Sirve tambien para auditarlo.
func request(id: StringName, context: String, team: int) -> bool:
	var route: Dictionary = routes.get(String(id).trim_suffix("_mirror"), {})
	if route.is_empty() or route["context"] != context or not PackLibrary.has_clip(id):
		return false
	var actor: String = route["actor"]
	var key: String = actor + str(team)
	if not actors.has(key):
		var visual := FootballerVisual.new()
		visual.name = actor + str(team)
		add_child(visual)
		visual.build(FootballerVisual.default_kit(team))
		if visual.is_placeholder:
			visual.queue_free()
			return false
		actors[key] = {"visual": visual, "motion": ActionMotion.new(), "team": team, "actor": actor}
	var slot: Dictionary = actors[key]
	var visual: FootballerVisual = slot["visual"]
	var motion: ActionMotion = slot["motion"]
	visual.stop_current_action()
	if visual.play_pack_clip(id) <= 0.0 or not motion.start(id):
		return false
	# Se reserva fuera de la banda todo el recorrido del clip, no se recorta ni se acelera la animacion.
	var extent: float = 0.0
	for point in PackLibrary.meta(id).get("root_path", PackedVector2Array()):
		extent = maxf(extent, point.length())
	var side: float = 1.0 if team == 0 else -1.0
	visual.position = Vector3(-ctx.pitch.config.half_length() * 0.4 if actor == "manager" else 0.0, 0.0,
		side * (ctx.pitch.config.half_width() + 2.5 + extent))
	visual.rotation.y = 0.0 if team == 0 else PI
	if route.get("anchor", "") == "bench":
		visual.position = Vector3((-1.0 if team == 0 else 1.0) * ctx.pitch.config.half_length() * 0.5, 0.0, ctx.pitch.config.half_width() + 1.6)
	motion.yaw0 = visual.rotation.y
	slot["context"] = context
	visual.visible = true
	invocations[id] = int(invocations.get(id, 0)) + 1
	return visual.current_action == id

func _select(actor: String, context: String, team: int) -> void:
	var key: String = actor + "/" + context
	var pool: Array = _pools.get(key, [])
	if pool.is_empty():
		return
	var cursor_key: String = key + str(team)
	var cursor: int = int(cursors.get(cursor_key, rng.randi_range(0, pool.size() - 1)))
	if request(pool[cursor % pool.size()], context, team):
		cursors[cursor_key] = cursor + 1

func _on_event(event: GameEvent) -> void:
	match event.type:
		GameEvent.Type.MATCH_START, GameEvent.Type.KICKOFF, GameEvent.Type.RESTART:
			for team in [0, 1]:
				_select("crowd", "ambient", team)
				_select("manager", "ambient", team)
				_select("substitute", "intro" if bool(event.data.get("intro", false)) else "ambient", team)
		GameEvent.Type.GOAL:
			_select("crowd", "celebration", event.team)
			_select("crowd", "conceded", 1 - event.team)
			_select("mascot", "celebration", event.team)
			_select("substitute", "celebration", event.team)
			_select("substitute", "conceded", 1 - event.team)
		GameEvent.Type.FOUL:
			_select("manager", "protest", event.team)
			_select("crowd", "protest", event.team)
			_select("substitute", "protest", event.team)
		GameEvent.Type.MATCH_END:
			for slot in actors.values():
				(slot["motion"] as ActionMotion).stop()
				(slot["visual"] as FootballerVisual).visible = false

func _physics_process(delta: float) -> void:
	for slot in actors.values():
		var visual: FootballerVisual = slot["visual"]
		var motion: ActionMotion = slot["motion"]
		if slot.get("context", "") == "intro" and ctx.input_enabled:
			motion.stop()
			visual.stop_current_action()
			_select(slot["actor"], "ambient", slot["team"])
		if not motion.active:
			visual.visible = false
			continue
		var root_velocity: Vector2 = motion.step(delta)
		var fwd: Vector3 = Locomotion.dir_from_yaw(motion.yaw0)
		var right: Vector3 = Vector3(-fwd.z, 0.0, fwd.x)
		visual.position += (fwd * root_velocity.x + right * root_velocity.y) * delta
		if motion.heading_driven:
			visual.rotation.y = motion.yaw0 + motion.heading_at(motion.t)
		visual.drive_motion(0.0, 0.0, delta)
		# Terminada una variante ambiental, la siguiente queda disponible sin cargar otro personaje.
		if not motion.active and ctx != null and ctx.input_enabled:
			_select(slot["actor"], "ambient", slot["team"])
