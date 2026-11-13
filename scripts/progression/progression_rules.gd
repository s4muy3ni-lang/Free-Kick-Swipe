class_name ProgressionRules
extends RefCounted
## Reglas de la progresion del jugador (pedido del usuario: «nivel, experiencia, puntos de mejora… limites por atributo…
## evitar ventajas desproporcionadas… especializacion sin clase permanente… redistribuir bajo reglas equilibradas»).
## Las mismas reglas estan en el servidor (supabase/migrations/20261113000009_progression.sql) y en LocalBackend:
##  - nivel por experiencia: la curva de siempre (PlayerProgress.level_for: cada nivel pide 150 XP mas);
##  - puntos de mejora: 2 por nivel hasta el nivel POINT_LEVEL_CAP (58 puntos en total); despues se sigue subiendo de
##    nivel (y se ganan monedas y desbloqueos) pero no mas puntos: la ventaja deportiva tiene techo;
##  - atributos de 1 a 10; subir cuesta mas arriba (cost_to: 1 punto hasta el 5, 2 del 6 al 8, 3 el 9 y el 10): llevar
##    uno al maximo cuesta 16 puntos y todos (nueve) 144, asi que no se puede tener todo: hay que elegir un estilo;
##  - redistribuir (respec): todos los atributos vuelven a 1 y se recuperan los puntos; la primera es gratis, despues
##    una cada RESPEC_DAYS dias por RESPEC_COINS monedas del juego; nunca durante una partida online. No da puntos.

## Atributos del tirador y del arquero (los nombres del servidor).
const SHOOTER := ["power", "accuracy", "curve", "height", "technique", "control"]
const KEEPER := ["keeper_reach", "keeper_reflex", "keeper_catch"]
const MIN_VALUE := 1
const MAX_VALUE := 10
const POINTS_PER_LEVEL := 2
const POINT_LEVEL_CAP := 30
const RESPEC_COINS := 300
const RESPEC_DAYS := 7

static func all() -> Array:
	return SHOOTER + KEEPER

static func is_attribute(k: String) -> bool:
	return all().has(k)

static func value(attrs: Dictionary, k: String) -> int:
	return clampi(int(attrs.get(k, MIN_VALUE)), MIN_VALUE, MAX_VALUE)

## Costo (puntos) de pasar del valor v - 1 al valor v.
static func cost_to(v: int) -> int:
	if v <= 5:
		return 1
	if v <= 8:
		return 2
	return 3

## Costo de la proxima mejora desde el valor actual (0 si ya esta al maximo).
static func cost_next(cur: int) -> int:
	return 0 if cur >= MAX_VALUE else cost_to(cur + 1)

## Puntos que vale tener el atributo en v (desde 1).
static func cost_of(v: int) -> int:
	var c: int = 0
	for i in range(MIN_VALUE + 1, clampi(v, MIN_VALUE, MAX_VALUE) + 1):
		c += cost_to(i)
	return c

static func spent(attrs: Dictionary) -> int:
	var s: int = 0
	for k in attrs:
		if is_attribute(String(k)):
			s += cost_of(int(attrs[k]))
	return s

static func earned(level: int) -> int:
	return (clampi(level, 1, POINT_LEVEL_CAP) - 1) * POINTS_PER_LEVEL

static func available(level: int, attrs: Dictionary) -> int:
	return maxi(earned(level) - spent(attrs), 0)

## "" si se puede subir k; si no, el motivo (lo mismo que contesta el servidor).
static func can_raise(level: int, attrs: Dictionary, k: String) -> String:
	if not is_attribute(k):
		return "atributo invalido"
	var cur: int = value(attrs, k)
	if cur >= MAX_VALUE:
		return "ese atributo ya esta al maximo"
	if available(level, attrs) < cost_to(cur + 1):
		return "no tenes puntos suficientes (cuesta %d)" % cost_to(cur + 1)
	return ""

## Experiencia dentro del nivel actual: [ganada en el nivel, la que pide el nivel].
static func xp_in_level(total_xp: int) -> Vector2i:
	var need: int = 150
	var acc: int = 0
	while total_xp >= acc + need:
		acc += need
		need += 150
	return Vector2i(total_xp - acc, need)

## Estado de la redistribucion: {"free": la primera, "cost": monedas, "wait": segundos que faltan (0 = ya se puede)}.
static func respec_state(respecs: int, last_at: float, now_s: float) -> Dictionary:
	if respecs <= 0:
		return {"free": true, "cost": 0, "wait": 0.0}
	return {"free": false, "cost": RESPEC_COINS, "wait": maxf(last_at + RESPEC_DAYS * 86400.0 - now_s, 0.0)}

const NAMES := {"power": "Potencia", "accuracy": "Precisión", "curve": "Efecto", "height": "Altura",
	"technique": "Técnica de disparo", "control": "Control", "keeper_reach": "Alcance", "keeper_reflex": "Reflejos",
	"keeper_catch": "Atrapada"}
const SPECIALIST := {"power": "Especialista en potencia", "accuracy": "Especialista en precisión",
	"curve": "Especialista en efecto", "height": "Especialista en tiros elevados", "technique": "Especialista técnico",
	"control": "Especialista en control"}

## Estilo de juego que sale de la distribucion (no es una clase fija: cambia con los puntos).
static func specialization(attrs: Dictionary) -> Dictionary:
	var shooter_pts: int = 0
	var keeper_pts: int = 0
	for k in SHOOTER:
		shooter_pts += cost_of(value(attrs, k))
	for k in KEEPER:
		keeper_pts += cost_of(value(attrs, k))
	if shooter_pts + keeper_pts == 0:
		return {"id": "nuevo", "name": "En formación", "detail": "Repartí tus puntos para definir tu estilo."}
	if keeper_pts > shooter_pts:
		return {"id": "arquero", "name": "Especialista en el arco", "detail": "La mayoría de tus puntos están en el arquero."}
	var order: Array = SHOOTER.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return value(attrs, a) > value(attrs, b))
	var top: int = value(attrs, order[0])
	var second: int = value(attrs, order[1])
	if top - second >= 2:
		return {"id": order[0], "name": SPECIALIST[order[0]], "detail": "%s es tu punto fuerte." % NAMES[order[0]]}
	var lowest: int = value(attrs, order[order.size() - 1])
	if top - lowest <= 1 and top >= 4:
		return {"id": "completo", "name": "Jugador completo", "detail": "Atributos parejos."}
	return {"id": "mixto", "name": "Estilo mixto", "detail": "%s y %s." % [NAMES[order[0]], NAMES[order[1]]]}
