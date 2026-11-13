class_name ShirtName
extends RefCounted
## Nombre en la camiseta (pedido del usuario: «validar los nombres para evitar contenido ofensivo o caracteres
## incompatibles»): hasta 12 letras (con acentos y ñ), numeros, espacio, punto, apostrofo o guion, y sin insultos. Las
## mismas reglas valida el servidor (update_appearance en SQL y LocalBackend).

const MAX := 12

static func valid_chars(t: String) -> bool:
	var re := RegEx.new()
	re.compile("^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9 .'-]*$")
	return re.search(t) != null

static func clean(t: String) -> bool:
	var low: String = t.to_lower()
	for w in ChatFilter.BAD:
		if low.contains(String(w)):
			return false
	return true

## Mensaje de error, o "" si el nombre sirve.
static func check(t: String) -> String:
	if t.length() > MAX:
		return "Hasta %d letras." % MAX
	if not valid_chars(t):
		return "Solo letras, números, espacio, punto o guion."
	if not clean(t):
		return "Ese nombre no se puede usar."
	return ""
