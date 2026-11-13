class_name AttributeEffects
extends RefCounted
## Efecto real de cada atributo en el juego (pedido del usuario: «cada atributo debe tener un efecto real, medible y
## comprobable… conectado con los parametros reales… el gesto, la direccion, la potencia y la ejecucion manual deben
## seguir siendo fundamentales»). Los atributos no deciden el tiro: escalan, poco y con tope, los coeficientes con los
## que el modelo del gesto (GestureShotModel, GestureTuning) convierte el trazo en el tiro, y el alcance del arquero
## (KeeperReach). Con todos en 1 el juego es exactamente el de antes (sin cambios para un jugador nuevo); en 10, el tope:
##
##  - POTENCIA: la velocidad maxima de salida (el trazo mas rapido) sube hasta POWER_SPEED (6 %); la minima no cambia.
##    Mas velocidad = la pelota llega antes y el arquero tiene menos tiempo (KeeperReach.time_factor).
##  - PRECISION: el desvio involuntario base y el que crece con la potencia (error_base, error_power) bajan hasta 25 %.
##  - EFECTO: el efecto lateral maximo (spin_max) sube hasta 15 % y la ganancia de la curva del trazo hasta 10 %; el
##    efecto lo aplica la fisica de la pelota (Magnus), igual que siempre.
##  - ALTURA: el desvio vertical (la parte del error que sube o baja el tiro) baja hasta 35 % y el trazo que termina
##    subiendo levanta la pelota hasta 40 % mas (ascend_lift).
##  - TECNICA DE DISPARO: el error por trazo irregular (error_rough) baja hasta 35 % y los tiros tecnicos (con efecto,
##    globo, rapido y corto, elevado) se desvian hasta 15 % menos.
##  - CONTROL: el error por trazo corto (error_short) baja hasta 35 % y el control total se alcanza con un trazo hasta
##    15 % mas corto (length_full): se prepara el tiro mas rapido.
##  - Arquero: ALCANCE (la estirada llega hasta 6 % mas lejos: KeeperReach.SCALE_LIMITS), REFLEJOS (arranca hasta 0,04 s
##    antes: KeeperReach.REACT_LIMITS; reflejos y velocidad de reaccion son el mismo parametro y no se duplican) y
##    ATRAPADA (atrapa sin dar rebote pelotas hasta 15 % mas rapidas). Nunca ataja lo que no alcanza ni cambia la regla
##    del sector: hay que elegir el sector correcto.

const POWER_SPEED := 0.06
const AIM_ERROR := 0.25
const CURVE_SPIN := 0.15
const CURVE_GAIN := 0.10
const HEIGHT_PITCH := 0.35
const HEIGHT_LIFT := 0.4
const TECH_ROUGH := 0.35
const TECH_TYPES := 0.15
const CONTROL_SHORT := 0.35
const CONTROL_LENGTH := 0.15
const KEEPER_REACH := 0.06
const KEEPER_REFLEX := 0.04
const KEEPER_CATCH := 0.15
## Parte vertical del error del tiro (ShotSolver.perturb) sin el atributo de altura.
const BASE_PITCH := 0.7
const TECHNICAL_TYPES := ["con_efecto", "globo", "rapido_corto", "elevado"]

## 0 (valor 1) .. 1 (valor 10).
static func n(attrs: Dictionary, k: String) -> float:
	return float(ProgressionRules.value(attrs, k) - ProgressionRules.MIN_VALUE) / float(ProgressionRules.MAX_VALUE - ProgressionRules.MIN_VALUE)

static func neutral(attrs: Dictionary) -> bool:
	for k in ProgressionRules.SHOOTER:
		if ProgressionRules.value(attrs, k) != ProgressionRules.MIN_VALUE:
			return false
	return true

## Coeficientes del gesto con los atributos del tirador (una copia; con atributos neutros, la misma base).
static func tuning_for(base: GestureTuning, attrs: Dictionary) -> GestureTuning:
	if neutral(attrs):
		return base
	var t: GestureTuning = base.duplicate()
	var na: float = n(attrs, "accuracy")
	t.error_base *= 1.0 - AIM_ERROR * na
	t.error_power *= 1.0 - AIM_ERROR * na
	var nc: float = n(attrs, "curve")
	t.spin_max *= 1.0 + CURVE_SPIN * nc
	t.spin_gain *= 1.0 + CURVE_GAIN * nc
	t.ascend_lift *= 1.0 + HEIGHT_LIFT * n(attrs, "height")
	t.error_rough *= 1.0 - TECH_ROUGH * n(attrs, "technique")
	var nk: float = n(attrs, "control")
	t.error_short *= 1.0 - CONTROL_SHORT * nk
	t.length_full *= 1.0 - CONTROL_LENGTH * nk
	return t

## Velocidades de salida del modo (minima, maxima) con la potencia del tirador.
static func speed_range(base: Vector2, attrs: Dictionary) -> Vector2:
	return Vector2(base.x, base.y * (1.0 + POWER_SPEED * n(attrs, "power")))

## Parte vertical del error (ShotSolver.perturb) con la altura del tirador.
static func pitch_ratio(attrs: Dictionary) -> float:
	return BASE_PITCH * (1.0 - HEIGHT_PITCH * n(attrs, "height"))

## Factor del error de un tiro del tipo gesture_type (la tecnica solo cuenta en los tiros tecnicos).
static func type_error_factor(attrs: Dictionary, gesture_type: String) -> float:
	if gesture_type in TECHNICAL_TYPES:
		return 1.0 - TECH_TYPES * n(attrs, "technique")
	return 1.0

static func keeper_reach_scale(attrs: Dictionary) -> float:
	return clampf(1.0 + KEEPER_REACH * n(attrs, "keeper_reach"), KeeperReach.SCALE_LIMITS.x, KeeperReach.SCALE_LIMITS.y)

static func keeper_react_bias(attrs: Dictionary) -> float:
	return clampf(-KEEPER_REFLEX * n(attrs, "keeper_reflex"), KeeperReach.REACT_LIMITS.x, KeeperReach.REACT_LIMITS.y)

static func keeper_catch_scale(attrs: Dictionary) -> float:
	return 1.0 + KEEPER_CATCH * n(attrs, "keeper_catch")

## Aplica los atributos de arquero a un SpKeeper.
static func apply_keeper(k: SpKeeper, attrs: Dictionary) -> void:
	if k == null:
		return
	k.reach_scale = keeper_reach_scale(attrs)
	k.react_bias = keeper_react_bias(attrs)
	k.catch_scale = keeper_catch_scale(attrs)

## Atributos del usuario (perfil del servidor o del servidor local); sin perfil, neutros.
static func user_attrs() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return {}
	var online: Node = tree.root.get_node_or_null("Online")
	if online == null or not online.has_method("profile"):
		return {}
	var p: Variant = online.call("profile")
	if p is Dictionary and (p as Dictionary).get("attributes") is Dictionary:
		return (p as Dictionary)["attributes"]
	return {}

## Efecto en numeros del atributo k con el valor v (para la pantalla de mejoras: antes / despues).
static func effect(k: String, v: int) -> Array:
	var a := {k: v}
	var t := GestureTuning.new()
	match k:
		"power":
			var fk: Vector2 = speed_range(SetPieceGame.FK_SPEED, a)
			var pen: Vector2 = speed_range(SetPieceGame.PEN_SPEED, a)
			return ["Velocidad máxima: %.1f m/s en tiro libre, %.1f m/s en penal" % [fk.y, pen.y],
				"%+.1f %% sobre la base" % (100.0 * POWER_SPEED * n(a, k))]
		"accuracy":
			var e: float = (t.error_base + t.error_power) * (1.0 - AIM_ERROR * n(a, k))
			return ["Desvío típico a máxima potencia: %.2f°" % e, "%d %% menos desvío involuntario" % roundi(100.0 * AIM_ERROR * n(a, k))]
		"curve":
			return ["Efecto máximo: %.0f rad/s" % (t.spin_max * (1.0 + CURVE_SPIN * n(a, k))),
				"Curva del trazo %+d %%" % roundi(100.0 * CURVE_GAIN * n(a, k))]
		"height":
			return ["Desvío vertical: %d %% del lateral" % roundi(100.0 * pitch_ratio(a)),
				"Levantar la pelota al subir el trazo %+d %%" % roundi(100.0 * HEIGHT_LIFT * n(a, k))]
		"technique":
			return ["Error por trazo irregular %d %% menos" % roundi(100.0 * TECH_ROUGH * n(a, k)),
				"Tiros técnicos (efecto, globo, rápido, elevado): %d %% menos desvío" % roundi(100.0 * TECH_TYPES * n(a, k))]
		"control":
			return ["Error por trazo corto %d %% menos" % roundi(100.0 * CONTROL_SHORT * n(a, k)),
				"Control total con un trazo de %.0f %% de la pantalla" % (100.0 * t.length_full * (1.0 - CONTROL_LENGTH * n(a, k)))]
		"keeper_reach":
			return ["Estirada: hasta %.2f m al costado" % (KeeperReach.LOW * keeper_reach_scale(a)),
				"%+d %% de alcance (pegado al ángulo sigue siendo gol)" % roundi(100.0 * (keeper_reach_scale(a) - 1.0))]
		"keeper_reflex":
			return ["Arranca %.2f s antes" % -keeper_react_bias(a), "Más alcance contra tiros muy rápidos"]
		"keeper_catch":
			return ["Atrapa sin rebote hasta %.0f km/h" % (SpSettings.keeper_catch_speed() * keeper_catch_scale(a) * 3.6),
				"%+d %% sobre la base" % roundi(100.0 * KEEPER_CATCH * n(a, k))]
	return []

const DESCRIPTIONS := {"power": "La fuerza con la que sale la pelota: velocidad, distancia y tiros potentes.",
	"accuracy": "Estabilidad de la dirección: menos desvío involuntario para apuntar a zonas chicas.",
	"curve": "Cuánto efecto (rosca) le podés dar a la pelota con la curva del trazo.",
	"height": "Control de la elevación: tiros rasos y altos más precisos, más facilidad para levantarla.",
	"technique": "Calidad de la ejecución: perdona el trazo irregular y mejora los tiros técnicos.",
	"control": "Dominio de la pelota: preparás el tiro con un trazo más corto y con menos error.",
	"keeper_reach": "Hasta dónde llega la estirada. Nunca ataja una pelota que no alcanza.",
	"keeper_reflex": "Qué tan rápido reacciona al tiro (reflejos y velocidad de reacción).",
	"keeper_catch": "Atrapa la pelota en vez de dar rebote en tiros más fuertes."}
