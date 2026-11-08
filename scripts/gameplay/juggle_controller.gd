class_name JuggleController
extends RefCounted
## Malabares (jueguitos) con los clips del pack. Cada clip (golpe de pie, rodilla, parada de pie o rodilla) tiene medida la
## trayectoria del punto de contacto. Entre un contacto y el siguiente la pelota vuela con un IMPULSO calculado para
## llegar al punto de contacto del siguiente clip justo cuando el clip lo alcanza (tiro parabolico). La pelota nunca se
## coloca a mano durante la secuencia: solo se la golpea; en las "paradas" se sostiene en el pie/rodilla como en el clip.

const FLIGHT_MIN := 0.85
## Vuelo maximo (s): si el clip tarda mas en llegar al contacto se salta su inicio (asi los jueguitos no suben demasiado).
const FLIGHT_MAX := 1.05
const STALL_HOLD := 0.9
const BALL_RADIUS := 0.1
## Clips que se encadenan (el primero es la elevacion desde el suelo). Todos con trayectoria de contacto medida.
const FIRST := &"kick_up_soccerball"
const POOL := [&"kneeing_soccerball", &"kneeing_soccerball_2", &"kick_soccerball", &"kick_soccerball_2",
	&"stall_soccerball", &"stall_soccerball_2", &"stall_soccerball_3", &"stall_soccerball_4"]

var stage: Node3D
var visual: FootballerVisual
var ball: Ball
var running: bool = false
var count: int = 0
var rng := RandomNumberGenerator.new()

enum Phase { WAIT_START, WAIT_ARRIVE, WAIT_RELEASE }
var _phase: Phase = Phase.WAIT_START
var _now: float = 0.0
var _step: Dictionary = {}
var _start_at: float = 0.0
var _arrive_at: float = 0.0
var _release_at: float = 0.0
var _anchor: Node3D = null
var _last_clip: StringName = &""

func _init(s: Node3D, v: FootballerVisual, b: Ball) -> void:
	stage = s
	visual = v
	ball = b
	rng.randomize()
	_anchor = Node3D.new()
	stage.add_child(_anchor)

## Datos de un clip: instante y punto de llegada de la pelota, y de salida si es una parada.
func _describe(clip: StringName) -> Dictionary:
	var paths: Dictionary = PackLibrary.meta(clip).get("paths", {})
	var stall: bool = String(clip).begins_with("stall")
	var best_key: String = ""
	var best_v: float = -1.0
	for key in paths:
		var hp: PackedVector3Array = paths[key]
		for i in range(1, hp.size() - 1):
			var v: float = (hp[i + 1] - hp[i - 1]).length()
			if v > best_v:
				best_v = v
				best_key = key
	var hp2: PackedVector3Array = paths.get(best_key, PackedVector3Array())
	var arrive: float = KeeperPlanner.peak_speed_time(clip, best_key)
	if stall:
		# La pelota llega a la parte mas alta del pie/rodilla (primer 70 % del clip) y se queda un instante.
		var top_i: int = 0
		for i in int(float(hp2.size()) * 0.7):
			if hp2[i].y > hp2[top_i].y:
				top_i = i
		arrive = float(top_i) / 30.0
	return {"clip": clip, "key": best_key, "arrive": arrive, "stall": stall, "knee": best_key.begins_with("knee")}

## Punto del mundo donde debe estar la pelota cuando el clip llega a `tau` (encima del pie / rodilla).
func _point_at(d: Dictionary, tau: float) -> Vector3:
	var p: Vector3 = KeeperPlanner.path_world(d["clip"], d["key"], int(tau * 30.0), stage.global_position, stage.rotation.y)
	var f: Vector3 = Locomotion.dir_from_yaw(stage.rotation.y)
	return p + f * (0.08 if d["knee"] else 0.03) + Vector3.UP * (BALL_RADIUS + 0.04)

## Hay clips de malabares en la libreria actual (el pack de Mixamo los trae; el banco JSON del modo 4 no tiene malabares).
static func available() -> bool:
	for c in POOL:
		if PackLibrary.has_clip(c):
			return true
	return false

func start() -> void:
	if not PackLibrary.has_clip(FIRST) or not available():
		running = false
		return
	running = true
	count = 0
	_now = 0.0
	_last_clip = &""
	_step = _describe(FIRST)
	var p0: Vector3 = _point_at(_step, float(_step["arrive"]))
	ball.reset_at(Vector3(p0.x, BALL_RADIUS, p0.z))
	_phase = Phase.WAIT_START
	_start_at = 0.4
	_arrive_at = _start_at + float(_step["arrive"])

func stop() -> void:
	running = false
	if ball.is_held():
		ball.release(visual, Vector3(0.6, 1.2, 0.0))
	if PackLibrary.has_clip(&"transition"):
		visual.play_pack_clip(&"transition")

func tick(delta: float) -> void:
	if not running:
		return
	_now += delta
	match _phase:
		Phase.WAIT_START:
			if _now >= _start_at:
				visual.play_pack_clip(_step["clip"], 1.0, float(_step.get("skip", 0.0)))
				_phase = Phase.WAIT_ARRIVE
		Phase.WAIT_ARRIVE:
			if _now >= _arrive_at:
				if _step["stall"]:
					_anchor.global_position = ball.global_position
					ball.hold(_anchor, visual)
					_release_at = _arrive_at + STALL_HOLD
					_phase = Phase.WAIT_RELEASE
				else:
					_release_at = _arrive_at
					_release()
		Phase.WAIT_RELEASE:
			var k: int = int((_now - _start_at + float(_step.get("skip", 0.0))) * 30.0)
			_anchor.global_position = KeeperPlanner.path_world(_step["clip"], _step["key"], k, stage.global_position, stage.rotation.y) \
				+ Vector3.UP * (BALL_RADIUS + 0.04) + Locomotion.dir_from_yaw(stage.rotation.y) * (0.08 if _step["knee"] else 0.03)
			if _now >= _release_at:
				_release()

## Golpea (o suelta) la pelota hacia el punto de llegada del siguiente clip.
func _release() -> void:
	var next: StringName = _choose_next()
	if next == &"":
		stop()
		return
	var nd: Dictionary = _describe(next)
	var flight: float = clampf(float(nd["arrive"]) + 0.1, FLIGHT_MIN, FLIGHT_MAX)
	nd["skip"] = maxf(0.0, float(nd["arrive"]) + 0.1 - flight)
	var target: Vector3 = _point_at(nd, float(nd["arrive"]))
	var from: Vector3 = ball.global_position
	var g: float = BallPredictor.GRAVITY
	var v := Vector3((target.x - from.x) / flight, (target.y - from.y) / flight + 0.5 * g * flight, (target.z - from.z) / flight)
	if ball.is_held():
		ball.release(visual, v)
	else:
		ball.kick(v, Vector3.ZERO, null)
	count += 1
	_last_clip = _step["clip"]
	_step = nd
	_arrive_at = _now + flight
	_start_at = _arrive_at - (float(nd["arrive"]) - float(nd["skip"]))
	_phase = Phase.WAIT_START

func _choose_next() -> StringName:
	var options: Array = POOL.filter(func(c: StringName) -> bool: return PackLibrary.has_clip(c) and c != _last_clip and c != _step["clip"])
	return options[rng.randi() % options.size()] if not options.is_empty() else &""
