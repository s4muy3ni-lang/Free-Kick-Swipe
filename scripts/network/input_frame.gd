class_name InputFrame
extends RefCounted
## Intencion de un jugador en un instante. Es el UNICO canal por el que un controlador
## (humano, IA o red) actua sobre un futbolista. Es serializable: en el futuro online,
## los clientes envian InputFrames y el servidor autoritativo valida y los aplica.

## Eje de movimiento relativo a la pantalla: x derecha, y abajo. Longitud <= 1.
var move: Vector2 = Vector2.ZERO
## Direccion YA en el mundo (la IA no pasa por la camara). Si use_world es true, tiene prioridad sobre `move`.
var use_world: bool = false
var move_world: Vector3 = Vector3.ZERO
var sprint: bool = false
## Pase: pressed = flanco de bajada, held = mantenido, released = flanco de subida.
var pass_pressed: bool = false
var pass_held: bool = false
var pass_released: bool = false
var shoot_pressed: bool = false
var shoot_held: bool = false
var shoot_released: bool = false
## Pase filtrado (al espacio, entre defensores): mismos flancos que el pase.
var through_pressed: bool = false
var through_held: bool = false
var through_released: bool = false
## Centro (desde la banda al area): mismos flancos que el pase.
var cross_pressed: bool = false
var cross_held: bool = false
var cross_released: bool = false
## Entrada defensiva (de pie o barrida segun distancia y velocidad): flanco de bajada.
var tackle_pressed: bool = false
## Modificador "alto": pase elevado / tiro elevado.
var lob_held: bool = false
var press_held: bool = false
var switch_pressed: bool = false
## Habilidad (regate con ruleta): flanco de bajada.
var skill_pressed: bool = false
var tick: int = 0

func move_length() -> float:
	return move_world.length() if use_world else move.length()

func to_dict() -> Dictionary:
	return {
		"t": tick, "mx": move.x, "my": move.y, "sp": sprint,
		"pp": pass_pressed, "ph": pass_held, "pr": pass_released,
		"sp_": shoot_pressed, "sh": shoot_held, "sr": shoot_released,
		"lob": lob_held, "press": press_held, "sw": switch_pressed, "sk": skill_pressed,
		"tp": through_pressed, "th": through_held, "tr": through_released,
		"cp": cross_pressed, "ch": cross_held, "cr": cross_released, "tk": tackle_pressed,
	}

static func from_dict(d: Dictionary) -> InputFrame:
	var f := InputFrame.new()
	f.tick = int(d.get("t", 0))
	f.move = Vector2(float(d.get("mx", 0.0)), float(d.get("my", 0.0)))
	if f.move.length() > 1.0:
		f.move = f.move.normalized()
	f.sprint = bool(d.get("sp", false))
	f.pass_pressed = bool(d.get("pp", false))
	f.pass_held = bool(d.get("ph", false))
	f.pass_released = bool(d.get("pr", false))
	f.shoot_pressed = bool(d.get("sp_", false))
	f.shoot_held = bool(d.get("sh", false))
	f.shoot_released = bool(d.get("sr", false))
	f.lob_held = bool(d.get("lob", false))
	f.press_held = bool(d.get("press", false))
	f.switch_pressed = bool(d.get("sw", false))
	f.skill_pressed = bool(d.get("sk", false))
	f.through_pressed = bool(d.get("tp", false))
	f.through_held = bool(d.get("th", false))
	f.through_released = bool(d.get("tr", false))
	f.cross_pressed = bool(d.get("cp", false))
	f.cross_held = bool(d.get("ch", false))
	f.cross_released = bool(d.get("cr", false))
	f.tackle_pressed = bool(d.get("tk", false))
	return f
