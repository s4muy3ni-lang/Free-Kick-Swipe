class_name PlayerAttributes
extends Resource
## Atributos deportivos de un jugador (escala 1-100). Estan separados de la identidad y de la apariencia.
## Los atributos NO sustituyen a la fisica: escalan parametros, tolerancias y errores dentro de
## limites razonables mediante factor(). Un valor de 50 es neutro (factor 1.0).

const MIN_VALUE: int = 1
const MAX_VALUE: int = 100
const DEFAULT_ROOKIE: int = 40

## Orden y nombres visibles (espanol) de los atributos de campo.
const FIELD_ATTRIBUTES: Dictionary = {
	"speed": "Velocidad",
	"acceleration": "Aceleración",
	"stamina": "Resistencia",
	"balance": "Equilibrio",
	"agility": "Agilidad",
	"ball_control": "Control de balón",
	"ball_carrying": "Conducción",
	"dribbling": "Regate",
	"short_pass": "Pase corto",
	"long_pass": "Pase largo",
	"pass_accuracy": "Precisión de pase",
	"shot_power": "Potencia de tiro",
	"shot_accuracy": "Precisión de tiro",
	"finishing": "Finalización",
	"weak_foot": "Pierna débil",
	"reaction": "Reacción",
	"marking": "Marcaje",
	"interception": "Intercepción",
	"strength": "Fuerza física",
	"jumping": "Salto",
	"heading": "Cabeceo",
	"composure": "Compostura",
	"decision": "Capacidad de decisión",
}

const KEEPER_ATTRIBUTES: Dictionary = {
	"reflexes": "Reflejos",
	"positioning": "Posicionamiento",
	"catching": "Blocaje",
	"diving": "Estirada",
	"aerial": "Juego aéreo",
	"throwing": "Saque con la mano",
	"kicking": "Juego con los pies",
	"rebound_control": "Reacción a rebotes",
}

## Valores actuales por clave. Solo se guardan claves conocidas.
@export var values: Dictionary = {}

func _init() -> void:
	reset_to(DEFAULT_ROOKIE)

func reset_to(base: int) -> void:
	values = {}
	for k in FIELD_ATTRIBUTES.keys():
		values[k] = clampi(base, MIN_VALUE, MAX_VALUE)
	for k in KEEPER_ATTRIBUTES.keys():
		values[k] = clampi(base, MIN_VALUE, MAX_VALUE)

static func is_known(key: String) -> bool:
	return FIELD_ATTRIBUTES.has(key) or KEEPER_ATTRIBUTES.has(key)

static func display_name(key: String) -> String:
	if FIELD_ATTRIBUTES.has(key):
		return FIELD_ATTRIBUTES[key]
	if KEEPER_ATTRIBUTES.has(key):
		return KEEPER_ATTRIBUTES[key]
	return key

func get_value(key: String) -> int:
	return int(values.get(key, DEFAULT_ROOKIE))

## Asigna un valor respetando el maximo. Devuelve el valor realmente asignado (o -1 si la clave no existe).
func set_value(key: String, v: int) -> int:
	if not is_known(key):
		return -1
	values[key] = clampi(v, MIN_VALUE, MAX_VALUE)
	return values[key]

## Factor multiplicador: 1.0 con valor 50; +-spread en los extremos.
func factor(key: String, spread: float) -> float:
	return 1.0 + (float(get_value(key)) - 50.0) / 50.0 * spread

## Valor 0..1 (1 = maximo), util para probabilidades y errores.
func norm(key: String) -> float:
	return float(get_value(key) - MIN_VALUE) / float(MAX_VALUE - MIN_VALUE)

func total_field() -> int:
	var t: int = 0
	for k in FIELD_ATTRIBUTES.keys():
		t += get_value(k)
	return t

func overall() -> int:
	return int(round(float(total_field()) / float(FIELD_ATTRIBUTES.size())))

func to_dict() -> Dictionary:
	return values.duplicate()

## Carga con validacion: ignora claves desconocidas, recorta rangos y rellena las faltantes.
static func from_dict(d: Dictionary) -> PlayerAttributes:
	var a := PlayerAttributes.new()
	for k in d.keys():
		if is_known(str(k)):
			var raw: Variant = d[k]
			if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
				a.values[str(k)] = clampi(int(raw), MIN_VALUE, MAX_VALUE)
	return a

func duplicate_attributes() -> PlayerAttributes:
	var a := PlayerAttributes.new()
	a.values = values.duplicate()
	return a
