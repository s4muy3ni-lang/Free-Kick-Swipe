class_name SpCelebration
extends Node
## Festejos y lamentos despues de cada tiro (etapa 3 de las correcciones de jugabilidad). No reproduce nada propio: mueve
## jugadores (SpActor.move_to con un bucle de carrera del banco JSON) y les da reacciones de una vez (SpReactions, sin
## bucles); al terminar cada uno vuelve solo a su reposo (SpActor.rest_loop). Ningun festejo queda abierto: cada corredor
## tiene un tope de tiempo (MAX_RUN_T) y, si no llega, festeja donde esta.
##
## - Gol: los compañeros corren hacia el autor (se lo vuelve a buscar cada 0,25 s porque su festejo se desplaza) y, al
##   llegar a un aro alrededor de el, lo miran y festejan. En el penal los compañeros esperan en el circulo central (a ~40
##   m): salen a buscarlo y el autor, cuando termina su festejo, corre hacia ellos; se encuentran en el camino.
## - Atajada, palo, afuera, barrera, despeje: el equipo rival corre hacia donde termino la jugada (el arquero, la barrera,
##   el punto por donde salio la pelota) y festeja ahi; el equipo que pateo se lamenta en el sitio.

## Velocidad de carrera del festejo (m/s) y aro alrededor del centro (m).
const RUN_SPEED := 6.8
const RING := 1.5
## Tope de carrera (s): pasado esto festeja donde este (nadie queda corriendo para siempre).
const MAX_RUN_T := 6.0
## Distancia a la que el autor y sus compañeros se dan por encontrados (penal).
const MEET_DIST := 2.6
## Recorrido de raiz maximo de los festejos y lamentos (m) y su duracion minima (s).
const REACT_ROOT := 1.5
const REACT_MIN := 1.0

var rng := RandomNumberGenerator.new()
## Corredores: {actor, roles, center (Vector3 o null), node (SpActor que se sigue o null), slot, slots, t, meet}.
var _runners: Array = []
## Autor del gol que sale a buscar a sus compañeros despues de su festejo (penal).
var _scorer: SpActor = null
var _scorer_mates: Array[SpActor] = []
var _scorer_running: bool = false
var _retarget_t: float = 0.0
## Para las pruebas: cuantos corredores llegaron, cuantos festejaron donde estaban por el tope, cuantos se lamentaron.
var arrived: int = 0
var timed_out: int = 0
var reacted: int = 0

static func run_loop() -> StringName:
	for role in [&"loco_sprint", &"run", &"loco_jog", &"jog"]:
		var ids: Array[StringName] = SpClips.by_role(role, false)
		if not ids.is_empty():
			return ids[0]
	return &""

## Termina todo lo pendiente (jugada nueva, salto del festejo): nadie queda corriendo.
func clear() -> void:
	for r in _runners:
		var a: SpActor = r["actor"]
		if is_instance_valid(a) and a.is_moving():
			a.stop_moving()
	_runners.clear()
	_scorer = null
	_scorer_mates.clear()
	_scorer_running = false

func active() -> bool:
	return not _runners.is_empty() or _scorer != null

func runners() -> int:
	return _runners.size()

## Reaccion de una vez en el sitio (lamento o festejo sin carrera).
func react_here(a: SpActor, roles: Array, delay_free: bool = true) -> void:
	if a == null or not a.visible:
		return
	var id: StringName = SpReactions.pick(roles, rng, REACT_ROOT, REACT_MIN)
	if id == &"":
		return
	if delay_free and a.is_moving():
		a.stop_moving()
	a.play_here(id, 0.3)
	reacted += 1

## Corre hacia un punto fijo (o hacia un jugador, si follow no es null) y festeja al llegar, mirando al centro. slot/slots
## reparten el aro para que no se encimen.
func gather(a: SpActor, center: Vector3, roles: Array, slot: int, slots: int, follow: SpActor = null) -> void:
	if a == null or not a.visible:
		return
	var r := {"actor": a, "roles": roles, "center": center, "node": follow, "slot": slot, "slots": maxi(slots, 1), "t": 0.0,
		"meet": false}
	_runners.append(r)
	_send(r)

## Gol: los compañeros van al autor. scorer_runs (penal): el autor, al terminar su festejo, corre hacia ellos.
func goal(scorer: SpActor, mates: Array[SpActor], scorer_runs: bool) -> void:
	var list: Array[SpActor] = []
	for m in mates:
		if m != null and m.visible and m != scorer:
			list.append(m)
	for i in list.size():
		gather(list[i], _dest(scorer), SpReactions.GOAL_TEAM, i, list.size(), scorer)
		_runners[_runners.size() - 1]["meet"] = scorer_runs
	if scorer_runs and not list.is_empty():
		_scorer = scorer
		_scorer_mates = list
		_scorer_running = false

## Donde va a QUEDAR un jugador: si esta en un clip de una vez con recorrido (un festejo que se desplaza), el final de
## ese recorrido (dato del clip, no adivinanza); si no, donde esta. Los compañeros van ahi y no quedan atras.
static func _dest(a: SpActor) -> Vector3:
	if not a.looping and a.is_playing_clip():
		var b: Array = SpActor.body_at(a.clip_id, SpClips.length(a.clip_id), a.frame_origin, a.frame_facing)
		var p: Vector3 = b[0]
		return Vector3(p.x, 0.0, p.z)
	return _pos(a)

static func _pos(a: SpActor) -> Vector3:
	var h: Vector3 = a.bone_world(SpActor.HIPS)
	return Vector3(h.x, 0.0, h.z)

## Punto del aro para el corredor: del lado por el que viene, repartido entre los que llegan.
func _slot_point(r: Dictionary) -> Vector3:
	var a: SpActor = r["actor"]
	var c: Vector3 = r["center"]
	var from: Vector3 = Vector3(a.global_position.x, 0.0, a.global_position.z) - c
	var base: float = atan2(from.z, from.x) if from.length() > 0.1 else 0.0
	var n: int = r["slots"]
	var spread: float = 0.75
	var ang: float = base + (float(r["slot"]) - float(n - 1) * 0.5) * spread
	return c + Vector3(cos(ang), 0.0, sin(ang)) * RING

func _send(r: Dictionary) -> void:
	var a: SpActor = r["actor"]
	var target: Vector3 = _slot_point(r)
	var loop: StringName = run_loop()
	if Vector3(a.global_position.x, 0.0, a.global_position.z).distance_to(target) < 0.4:
		return
	a.move_to(target, RUN_SPEED, loop)

func _physics_process(delta: float) -> void:
	if _runners.is_empty() and _scorer == null:
		return
	_retarget_t -= delta
	var retarget: bool = _retarget_t <= 0.0
	if retarget:
		_retarget_t = 0.25
	# Penal: el autor sale hacia sus compañeros cuando termina su festejo (y no lo esta haciendo otro clip).
	if _scorer != null and is_instance_valid(_scorer):
		if not _scorer_running and _scorer.looping:
			_scorer_running = true
		if _scorer_running and retarget:
			var mid := Vector3.ZERO
			for m in _scorer_mates:
				mid += _pos(m)
			mid /= float(maxi(_scorer_mates.size(), 1))
			_scorer.move_to(mid, RUN_SPEED * 0.9, run_loop())
	var done: Array = []
	for r in _runners:
		var a: SpActor = r["actor"]
		if not is_instance_valid(a) or not a.visible:
			done.append(r)
			continue
		r["t"] = float(r["t"]) + delta
		var node: SpActor = r["node"]
		if node != null and is_instance_valid(node):
			r["center"] = _dest(node)
		var c: Vector3 = r["center"]
		var here := Vector3(a.global_position.x, 0.0, a.global_position.z)
		var met: bool = bool(r["meet"]) and here.distance_to(c) <= MEET_DIST
		var reached: bool = not a.is_moving() or met or here.distance_to(c) <= RING + 0.3
		if reached or float(r["t"]) >= MAX_RUN_T:
			if float(r["t"]) >= MAX_RUN_T and not reached:
				timed_out += 1
			else:
				arrived += 1
			a.stop_moving()
			a.set_facing(c - here)
			react_here(a, r["roles"], false)
			done.append(r)
		elif retarget and node != null:
			_send(r)
	for r in done:
		_runners.erase(r)
	# Penal: cuando el primer compañero lo alcanza, el autor se frena y festeja con ellos.
	if _scorer != null and is_instance_valid(_scorer) and _scorer_running:
		var close: bool = _runners.is_empty()
		for m in _scorer_mates:
			if _pos(m).distance_to(_pos(_scorer)) <= MEET_DIST + 0.4:
				close = true
		if close:
			_scorer.stop_moving()
			if not _scorer_mates.is_empty():
				_scorer.set_facing(_pos(_scorer_mates[0]) - _pos(_scorer))
			react_here(_scorer, SpReactions.GOAL_TEAM, false)
			_scorer = null
			_scorer_mates.clear()
			_scorer_running = false
