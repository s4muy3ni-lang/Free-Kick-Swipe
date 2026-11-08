class_name TeamBrain
extends RefCounted
## Organizacion colectiva de un equipo (IA). Una sola decision por equipo cada DECISION_PERIOD s, en lugar de que cada
## jugador decida por su cuenta: asi nunca van dos al mismo sitio ni todos a la pelota.
##
## Fases (segun quien tiene la pelota, ver MatchContext.possessor):
##  - ATAQUE: el portador juega; los demas ocupan PUESTOS DISTINTOS respecto a la pelota: apoyo corto (linea de pase
##    segura a 4-7 m), amplitud (banda contraria, pegado a la linea), profundidad (a la altura del ultimo defensor,
##    atacando su espalda) y seguridad (por detras de la pelota, para el pase atras y el repliegue). Cada puesto se
##    corrige para que la linea de pase desde el portador quede libre, y se asignan con un reparto de coste minimo.
##  - DEFENSA: UN presionador (el que llega antes al portador; si la persona controla al que esta mas cerca, ella es la
##    presion y la IA no manda a otro), UNA cobertura (detras del presionador, entre la pelota y el arco) y el resto
##    en bloque: cierran la linea de pase al rival mas peligroso por el lado del arco, a la altura de una linea
##    defensiva que retrocede cuando la pelota se acerca al arco propio (repliegue).
##  - PELOTA SUELTA: va UNO por equipo (el que llega antes); los demas conservan su puesto de la ultima fase.
##
## Solo produce destinos e intenciones; el movimiento lo hace cada AIInput con la fisica del jugador.

const DECISION_PERIOD := 0.2
## Distancia minima (m) entre dos puestos del mismo equipo.
const MIN_SPACING := 6.0
## Distancia del apoyo corto al portador (m).
const SUPPORT_DIST := 6.5
## Distancia de la cobertura a la pelota, entre la pelota y el propio arco (m): detras del presionador, no a su lado.
const COVER_DIST := 6.5
## Distancia minima (m) a la pelota de todo jugador que no sea el portador, el presionador o el que va a por ella: con
## cuatro jugadores dentro de 4 m la jugada se convierte en un amontonamiento.
const CLEAR_OF_BALL := 5.0
## Segundo en presionar (UCS MaxActivePresses = 2): distancia al portador del lado del arco y tiempo maximo para llegar.
const PRESS2_DIST := 2.5
const PRESS2_MAX_TIME := 1.2

enum Phase { ATTACK, DEFEND, LOOSE }

var team: int = 0
var phase: Phase = Phase.LOOSE
## Footballer -> {"role": StringName, "target": Vector3, "press": bool, "sprint": bool}
var orders: Dictionary = {}
var presser: Footballer = null
var chaser: Footballer = null
var _next: float = 0.0
var _clock: float = 0.0
var _last_attack_slots: Dictionary = {}
## Puesto de ataque de cada jugador en la decision anterior: mantenerlo cuesta menos (histeresis) para que no
## intercambien puestos a cada instante y lleguen a ocuparlos.
var _last_roles: Dictionary = {}
var _side: float = 0.0
## Metros de ventaja que tiene conservar el puesto anterior en el reparto.
const KEEP_ROLE_BONUS := 4.0

func _init(t: int) -> void:
	team = t

static func for_team(ctx: MatchContext, t: int) -> TeamBrain:
	if ctx.brains[t] == null:
		ctx.brains[t] = TeamBrain.new(t)
	return ctx.brains[t]

## Orden actual para un jugador (recalcula si toca). {} si no hay orden.
func order_for(f: Footballer) -> Dictionary:
	var ctx: MatchContext = f.ctx
	var now: float = float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)
	if now >= _next or not orders.has(f):
		_next = now + DECISION_PERIOD
		_update(ctx)
	return orders.get(f, {})

func _atk() -> Vector3:
	return Vector3(1.0 if team == 0 else -1.0, 0.0, 0.0)

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func _mates(ctx: MatchContext) -> Array[Footballer]:
	var out: Array[Footballer] = []
	for f in ctx.footballers:
		if f.team == team:
			out.append(f)
	return out

func _opps(ctx: MatchContext) -> Array[Footballer]:
	var out: Array[Footballer] = []
	for f in ctx.footballers:
		if f.team != team:
			out.append(f)
	return out

func _update(ctx: MatchContext) -> void:
	orders.clear()
	presser = null
	chaser = null
	ctx.update_possession()
	var owner: Footballer = ctx.possessor
	var ball: Ball = ctx.ball
	var mates: Array[Footballer] = _mates(ctx)
	if mates.is_empty():
		return
	# Un pase propio en camino cuenta como posesion (la jugada es nuestra aunque la pelota viaje suelta).
	var receiver: Footballer = null
	for m in mates:
		if m.has_incoming_pass():
			receiver = m
	if owner != null and owner.team == team:
		phase = Phase.ATTACK
		_attack(ctx, owner, mates)
	elif receiver != null and ball.last_touch_team == team:
		phase = Phase.ATTACK
		_attack(ctx, receiver, mates)
	elif owner == null and _team_still_has_it(ball, mates):
		# Toque largo o rebote propio: la jugada sigue siendo nuestra aunque nadie la tenga pegada al pie. Sin esto
		# la fase cambiaria a cada toque y nadie llegaria a su puesto.
		phase = Phase.ATTACK
		_attack(ctx, ball.last_toucher as Footballer, mates)
	elif owner != null:
		phase = Phase.DEFEND
		_defend(ctx, owner, mates)
	else:
		phase = Phase.LOOSE
		_loose(ctx, mates)

## Segundos durante los que la pelota suelta tocada por ultima vez por un companero cercano sigue siendo del equipo.
const TEAM_POSSESSION_GRACE := 1.0

func _team_still_has_it(ball: Ball, mates: Array[Footballer]) -> bool:
	var t: Footballer = ball.last_toucher as Footballer
	if t == null or not mates.has(t) or ball.is_held():
		return false
	if float(Engine.get_physics_frames() - ball.last_touch_frame) / float(Engine.physics_ticks_per_second) > TEAM_POSSESSION_GRACE:
		return false
	return _flat(t.global_position).distance_to(_flat(ball.global_position)) < 4.0 and ball.global_position.y < 1.0

# --- Ataque ----------------------------------------------------------------------------------------------------

func _attack(ctx: MatchContext, carrier: Footballer, mates: Array[Footballer]) -> void:
	var cfg: PitchConfig = ctx.pitch.config
	var atk: Vector3 = _atk()
	var hl: float = cfg.half_length()
	var hw: float = cfg.half_width()
	var cp: Vector3 = _flat(carrier.global_position)
	var progress: float = (cp.x * atk.x + hl) / (2.0 * hl)   # 0 = arco propio, 1 = arco rival
	var opps: Array[Footballer] = _opps(ctx)
	# Ultima linea rival (el defensor de campo mas retrasado): referencia de la profundidad.
	var last_line: float = -INF
	for o in opps:
		last_line = maxf(last_line, o.global_position.x * atk.x)
	if last_line == -INF:
		last_line = hl - 4.0
	# Lado de la pelota con histeresis: con la pelota por el centro no se cambia, para que la amplitud no cruce la
	# cancha cada vez que el portador pasa de un lado al otro.
	if absf(cp.z) > 2.0 or _side == 0.0:
		_side = signf(cp.z) if absf(cp.z) > 0.01 else 1.0
	var side: float = _side
	var slots: Dictionary = {}
	# Apoyo corto: al costado y algo por detras del portador, del lado del centro (linea de pase segura).
	var sup := cp + Vector3(-atk.x * 2.0, 0.0, -side * SUPPORT_DIST)
	slots[&"support"] = sup
	# Amplitud: banda contraria a la pelota, pegado a la linea, un poco por delante.
	# Amplitud: en juego abierto el equipo ocupa el 60 % del ancho (WidthOpenPlay de UCS), no pegado a la linea.
	slots[&"width"] = Vector3(cp.x + atk.x * 4.0, 0.0, -side * minf(hw - 1.6, hw * UcsParams.WIDTH_OPEN_PLAY))
	# Profundidad: a la altura del ultimo defensor (o un poco detras si la pelota esta lejos), en el carril del centro.
	var depth_x: float = clampf(last_line - 0.5, cp.x * atk.x + 5.0, hl - 3.0) * atk.x
	slots[&"depth"] = Vector3(depth_x, 0.0, clampf(-cp.z * 0.4, -3.0, 3.0))
	# Seguridad: por detras de la pelota, centrado (pase atras y primer defensor si se pierde).
	slots[&"safety"] = Vector3(cp.x - atk.x * lerpf(6.0, 9.0, progress), 0.0, clampf(cp.z * 0.3, -3.0, 3.0))
	# Con la pelota en zona de centro: los de dentro atacan el area (primer palo / segundo palo / punto de penal).
	if absf(cp.z) > hw - 4.5 and (hl - cp.x * atk.x) < 11.0:
		slots[&"depth"] = CrossAssist.zone_point(ctx, team, &"near_post", side)
		slots[&"width"] = CrossAssist.zone_point(ctx, team, &"far_post", side)
		slots[&"support"] = CrossAssist.zone_point(ctx, team, &"penalty_spot", side)
	# Correccion: cada puesto dentro de la cancha, con linea de pase libre desde el portador y separado de los demas.
	var keys: Array = [&"support", &"width", &"depth", &"safety"]
	for k in keys:
		var p: Vector3 = ctx.pitch.clamp_to_pitch(slots[k], 1.2)
		p = _open_lane(ctx, cp, p, opps, hw)
		slots[k] = p
	_spread(slots, keys, cp)
	_clear_carrier_corridor(ctx, slots, keys, carrier, hw)
	# Reparto: los jugadores sin pelota a los puestos (coste = distancia, con preferencia por su rol de formacion).
	var others: Array[Footballer] = []
	for m in mates:
		if m != carrier:
			others.append(m)
	var wanted: Array = keys.slice(0, others.size()) if others.size() < keys.size() else keys
	# Con 3 companeros: en campo propio seguridad en vez de profundidad; en campo rival, profundidad.
	if others.size() == 3:
		wanted = [&"support", &"width", &"safety" if progress < 0.45 else &"depth"]
	var assign: Dictionary = _assign(others, wanted, slots)
	for m in others:
		var role: StringName = assign.get(m, &"support")
		var target: Vector3 = slots[role]
		var d: float = _flat(m.global_position).distance_to(target)
		orders[m] = {"role": role, "target": target, "press": false, "sprint": d > 4.0}
		_last_roles[m] = role
	orders[carrier] = {"role": &"carrier", "target": cp, "press": false, "sprint": false}
	_last_attack_slots = slots

## Mueve el puesto hasta que la linea de pase desde el portador no la tape ningun rival (prueba desplazamientos laterales).
func _open_lane(ctx: MatchContext, from: Vector3, p: Vector3, opps: Array[Footballer], hw: float) -> Vector3:
	if _lane_clear(from, p, opps, 1.0):
		return p
	var dir: Vector3 = (p - from)
	var side := Vector3(-dir.z, 0.0, dir.x).normalized()
	for off in [1.8, -1.8, 3.4, -3.4]:
		var q: Vector3 = p + side * off
		q.z = clampf(q.z, -hw + 1.2, hw - 1.2)
		if _lane_clear(from, q, opps, 1.0):
			return q
	return p

static func _lane_clear(a: Vector3, b: Vector3, opps: Array[Footballer], width: float) -> bool:
	var ab: Vector3 = b - a
	var len2: float = ab.length_squared()
	if len2 < 0.01:
		return true
	for o in opps:
		var p: Vector3 = _flat(o.global_position)
		var u: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		if u > 0.08 and u < 0.95 and (a + ab * u).distance_to(p) < width:
			return false
	return true

## Pasillo del portador: ningun puesto queda delante de el en su carril (a menos de CORRIDOR_HALF_WIDTH de lado y
## CORRIDOR_LENGTH por delante, segun hacia donde corre). Si no, el companero que va a ese puesto (mas lento que el
## portador) acababa con el portador encima (medido: 24 % del tiempo a < 2 m conduciendo; visto en el video).
const CORRIDOR_HALF_WIDTH := 2.5
const CORRIDOR_LENGTH := 9.0

func _clear_carrier_corridor(ctx: MatchContext, slots: Dictionary, keys: Array, carrier: Footballer, hw: float) -> void:
	var cp: Vector3 = _flat(carrier.global_position)
	var v: Vector3 = _flat(carrier.velocity)
	# Hacia donde corre y hacia el arco rival: los dos pasillos quedan libres (conduciendo en zigzag el rumbo cambia).
	for dir in [v.normalized() if v.length() > 1.0 else _atk(), _atk()]:
		_clear_corridor(ctx, slots, keys, cp, dir, hw)

func _clear_corridor(ctx: MatchContext, slots: Dictionary, keys: Array, cp: Vector3, dir: Vector3, hw: float) -> void:
	var side_axis := Vector3(-dir.z, 0.0, dir.x)
	for k in keys:
		var p: Vector3 = slots[k]
		var rel: Vector3 = p - cp
		var ahead: float = rel.dot(dir)
		var lat: float = rel.dot(side_axis)
		if ahead > -1.0 and ahead < CORRIDOR_LENGTH and absf(lat) < CORRIDOR_HALF_WIDTH:
			# Al lado con mas sitio (lejos de la banda) y a la altura que tenia.
			var sgn: float = signf(lat) if absf(lat) > 0.2 else (-signf(cp.z) if absf(cp.z) > 0.5 else 1.0)
			var q: Vector3 = cp + dir * ahead + side_axis * sgn * (CORRIDOR_HALF_WIDTH + 1.0)
			if absf(q.z) > hw - 1.2:
				q = cp + dir * ahead - side_axis * sgn * (CORRIDOR_HALF_WIDTH + 1.0)
			slots[k] = ctx.pitch.clamp_to_pitch(q, 1.2)

## Separa los puestos entre si (y del portador) al menos MIN_SPACING.
func _spread(slots: Dictionary, keys: Array, carrier_pos: Vector3) -> void:
	for it in 3:
		for i in keys.size():
			var a: Vector3 = slots[keys[i]]
			var push := Vector3.ZERO
			var dc: Vector3 = a - carrier_pos
			if dc.length() < CLEAR_OF_BALL and dc.length() > 0.01:
				push += dc.normalized() * (CLEAR_OF_BALL - dc.length())
			for j in keys.size():
				if i == j:
					continue
				var d: Vector3 = a - (slots[keys[j]] as Vector3)
				if d.length() < MIN_SPACING and d.length() > 0.01:
					push += d.normalized() * (MIN_SPACING - d.length()) * 0.5
			slots[keys[i]] = a + push

## Reparto de coste minimo (permutaciones: como mucho 4 jugadores y 4 puestos).
func _assign(players: Array[Footballer], roles: Array, slots: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_cost: float = INF
	var perms: Array = _perms(roles.slice(0, mini(roles.size(), players.size())))
	for perm in perms:
		var cost: float = 0.0
		for i in perm.size():
			var f: Footballer = players[i]
			cost += _flat(f.global_position).distance_to(slots[perm[i]]) + _role_bias(f, perm[i])
			if _last_roles.get(f, &"") == perm[i]:
				cost -= KEEP_ROLE_BONUS
		if cost < best_cost:
			best_cost = cost
			best = {}
			for i in perm.size():
				best[players[i]] = perm[i]
	return best

## Preferencia por el rol de formacion (cierre = seguridad, pivote = profundidad, alas = amplitud/apoyo): no obliga,
## solo desempata, para que la estructura sea estable y no cambien de puesto a cada instante.
static func _role_bias(f: Footballer, slot: StringName) -> float:
	var r: int = int(f.get_meta("ai_role", -1))
	if f.input_source is AIInput:
		r = (f.input_source as AIInput).role
	match slot:
		&"safety":
			return 0.0 if r == 0 else 3.0
		&"depth":
			return 0.0 if r == 3 else 2.5
		_:
			return 0.0 if (r == 1 or r == 2) else 1.5

static func _perms(arr: Array) -> Array:
	if arr.size() <= 1:
		return [arr.duplicate()]
	var out: Array = []
	for i in arr.size():
		var rest: Array = arr.duplicate()
		var x = rest.pop_at(i)
		for p in _perms(rest):
			p.push_front(x)
			out.append(p)
	return out

# --- Defensa ---------------------------------------------------------------------------------------------------

func _time_to(f: Footballer, p: Vector3) -> float:
	return _flat(f.global_position).distance_to(p) / maxf(f.locomotion.max_sprint_speed(), 1.0)

func _defend(ctx: MatchContext, carrier: Footballer, mates: Array[Footballer]) -> void:
	var cfg: PitchConfig = ctx.pitch.config
	var atk: Vector3 = _atk()
	var hl: float = cfg.half_length()
	var own_goal := Vector3(-atk.x * hl, 0.0, 0.0)
	var cp: Vector3 = _flat(carrier.global_position)
	var cv: Vector3 = _flat(carrier.velocity)
	var intercept: Vector3 = cp + cv * 0.4
	# Presionador: el que llega antes. Si es el que maneja la persona, la presion es suya: la IA no manda a otro.
	var by_time: Array[Footballer] = mates.duplicate()
	by_time.sort_custom(func(a: Footballer, b: Footballer) -> bool: return _time_to(a, intercept) < _time_to(b, intercept))
	var human_first: bool = person_drives(by_time[0])
	presser = by_time[0]
	# Cobertura: no el segundo mas cercano al portador (estaria a su lado y amontonaria), sino el que llega antes al
	# punto de cobertura, entre la pelota y el arco propio.
	var cover_point: Vector3 = ctx.pitch.clamp_to_pitch(cp + (own_goal - cp).normalized() * COVER_DIST, 1.0)
	var cover: Footballer = null
	for i in range(1, by_time.size()):
		if cover == null or _time_to(by_time[i], cover_point) < _time_to(cover, cover_point):
			cover = by_time[i]
	var rest: Array[Footballer] = []
	for i in range(1, by_time.size()):
		if by_time[i] != cover:
			rest.append(by_time[i])
	if not human_first:
		var d: float = _flat(presser.global_position).distance_to(cp)
		orders[presser] = {"role": &"press", "target": intercept, "press": true, "sprint": d > 4.0}
	# Cobertura: entre el portador y el arco, detras del presionador. Como en UCS (MaxActivePresses = 2), si llega pronto
	# es el segundo en presionar: cierra el camino al arco a 2.5 m del portador, sin entrar (MaxActiveTackles = 1).
	if cover != null:
		var tight: Vector3 = ctx.pitch.clamp_to_pitch(cp + (own_goal - cp).normalized() * PRESS2_DIST, 1.0)
		if UcsParams.MAX_ACTIVE_PRESSES >= 2 and not human_first and _time_to(cover, tight) <= PRESS2_MAX_TIME:
			orders[cover] = {"role": &"press2", "target": tight, "press": false, "sprint": _flat(cover.global_position).distance_to(tight) > 4.0}
		else:
			orders[cover] = {"role": &"cover", "target": cover_point, "press": false, "sprint": _flat(cover.global_position).distance_to(cover_point) > 4.0}
	# Bloque: linea defensiva que retrocede con la pelota (repliegue) y cierra la linea de pase al rival mas peligroso.
	var ball_depth: float = (cp.x - own_goal.x) * atk.x          # metros desde el arco propio
	var line_depth: float = clampf(ball_depth - 7.0, 2.5, 13.0)
	var dangers: Array[Footballer] = []
	for o in _opps(ctx):
		if o != carrier:
			dangers.append(o)
	dangers.sort_custom(func(a: Footballer, b: Footballer) -> bool: return _flat(a.global_position).distance_to(own_goal) < _flat(b.global_position).distance_to(own_goal))
	var used: Array = []
	for f in rest:
		var target := Vector3.ZERO
		for o in dangers:
			if used.has(o):
				continue
			used.append(o)
			var op: Vector3 = _flat(o.global_position)
			# Entre el rival y el arco, desplazado hacia la linea de pase desde el portador.
			var goal_side: Vector3 = op + (own_goal - op).normalized() * 1.8
			var lane: Vector3 = cp.lerp(op, 0.7)
			target = goal_side.lerp(lane, 0.35)
			break
		if target == Vector3.ZERO:
			target = Vector3(own_goal.x + atk.x * line_depth, 0.0, clampf(cp.z * 0.5, -4.0, 4.0))
		# Nunca por detras de la propia linea defensiva sin motivo ni encima de la pelota.
		var depth_t: float = (target.x - own_goal.x) * atk.x
		if depth_t > line_depth + 4.0 and _flat(target).distance_to(cp) > 6.0:
			target.x = own_goal.x + atk.x * (line_depth + 4.0)
		if target.distance_to(cp) < CLEAR_OF_BALL:
			target = cp + (target - cp).normalized() * CLEAR_OF_BALL
		target = ctx.pitch.clamp_to_pitch(target, 1.0)
		orders[f] = {"role": &"block", "target": target, "press": false, "sprint": _flat(f.global_position).distance_to(target) > 4.0}
	_spread_defense(ctx, cp)

## Separacion minima entre defensores sin presion (no dos marcando el mismo sitio).
func _spread_defense(ctx: MatchContext, cp: Vector3) -> void:
	var keys: Array = orders.keys().filter(func(k: Footballer) -> bool: return orders[k]["role"] != &"press")
	for it in 2:
		for a in keys:
			var pa: Vector3 = orders[a]["target"]
			for b in keys:
				if a == b:
					continue
				var d: Vector3 = pa - (orders[b]["target"] as Vector3)
				if d.length() < 4.5 and d.length() > 0.01:
					pa += d.normalized() * (4.5 - d.length()) * 0.5
			var dc: Vector3 = pa - cp
			if dc.length() < CLEAR_OF_BALL and dc.length() > 0.01:
				pa = cp + dc.normalized() * CLEAR_OF_BALL
			orders[a]["target"] = ctx.pitch.clamp_to_pitch(pa, 1.0)

# --- Pelota suelta ---------------------------------------------------------------------------------------------

## El jugador lo maneja una persona (no basta con ser el «controlado»: sin persona, el control lo lleva un AIInput y la IA
## tiene que darle ordenes; si no, una pelota suelta junto a el se quedaba quieta: medido 7.3 s en entrenamiento).
static func person_drives(f: Footballer) -> bool:
	return f.is_human_controlled and not (f.input_source is AIInput)

func _loose(ctx: MatchContext, mates: Array[Footballer]) -> void:
	var ball: Ball = ctx.ball
	# Dentro de la cancha: una pelota que sale no arrastra al perseguidor detras del arco.
	var bp: Vector3 = ctx.pitch.clamp_to_pitch(_flat(ball.global_position + ball.linear_velocity * 0.35), 0.3)
	var by_time: Array[Footballer] = mates.duplicate()
	by_time.sort_custom(func(a: Footballer, b: Footballer) -> bool: return _time_to(a, bp) < _time_to(b, bp))
	chaser = by_time[0]
	# Si la toco por ultimo un companero que sigue cerca (toque largo, rebote propio), es el quien va: otro companero
	# no se le mete encima.
	var lt: Footballer = ball.last_toucher as Footballer
	if lt != null and mates.has(lt) and _flat(lt.global_position).distance_to(_flat(ball.global_position)) < 3.0:
		chaser = lt
	if not person_drives(chaser):
		orders[chaser] = {"role": &"chase", "target": bp, "press": true, "sprint": _flat(chaser.global_position).distance_to(bp) > 3.0}
	# Los demas: si la ultima fase fue nuestra, mantienen sus puestos de ataque; si no, se ordenan en defensa respecto a
	# la pelota (un rival la tomara enseguida).
	var atk: Vector3 = _atk()
	var hl: float = ctx.pitch.config.half_length()
	var own_goal := Vector3(-atk.x * hl, 0.0, 0.0)
	var i: int = 0
	for f in by_time:
		if f == chaser:
			continue
		var target: Vector3
		if ctx.phase_team == team and not _last_attack_slots.is_empty():
			var keys: Array = _last_attack_slots.keys()
			target = _last_attack_slots[keys[i % keys.size()]]
		else:
			var ball_depth: float = (bp.x - own_goal.x) * atk.x
			var line: float = clampf(ball_depth - 6.0, 2.5, 13.0)
			target = Vector3(own_goal.x + atk.x * line, 0.0, [-4.0, 4.0, 0.0][i % 3] + clampf(bp.z * 0.3, -3.0, 3.0))
		i += 1
		if target.distance_to(bp) < CLEAR_OF_BALL + 1.0:
			target = bp + (target - bp).normalized() * (CLEAR_OF_BALL + 1.0)
		orders[f] = {"role": &"hold", "target": ctx.pitch.clamp_to_pitch(target, 1.0), "press": false, "sprint": _flat(f.global_position).distance_to(target) > 5.0}
