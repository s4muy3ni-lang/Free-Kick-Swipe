class_name SupabaseApi
extends Node
## Cliente HTTP de Supabase: Auth (GoTrue, /auth/v1) y base de datos (PostgREST, /rest/v1 y RPC). Usa SOLO la clave
## publica (anon/publishable); la service key nunca esta en el cliente. Cada llamada devuelve {ok, data, error, network}:
## network = true cuando no hubo respuesta del servidor (sin conexion), para que el juego siga offline.

var url: String = ""
var key: String = ""
var access_token: String = ""
var timeout_s: float = 12.0

func setup(base_url: String, anon_key: String) -> void:
	url = base_url.trim_suffix("/")
	key = anon_key

func request_json(method: int, path: String, body: Variant = null, use_session: bool = true) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout_s
	add_child(http)
	var headers := PackedStringArray(["apikey: " + key, "Content-Type: application/json", "Accept: application/json"])
	headers.append("Authorization: Bearer " + (access_token if use_session and access_token != "" else key))
	var payload: String = "" if body == null else JSON.stringify(body)
	if http.request(url + path, headers, method, payload) != OK:
		http.queue_free()
		return {"ok": false, "network": true, "error": "Sin conexión"}
	var res: Array = await http.request_completed
	http.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "network": true, "error": "Sin conexión con el servidor"}
	var code: int = int(res[1])
	var txt: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(txt) if txt.strip_edges() != "" else null
	if code >= 200 and code < 300:
		return {"ok": true, "data": parsed, "code": code}
	return {"ok": false, "code": code, "error": error_text(parsed, code), "network": false}

## Mensaje de error para el jugador (en español) a partir de la respuesta de Supabase.
static func error_text(body: Variant, code: int) -> String:
	var msg: String = ""
	if body is Dictionary:
		for k in ["error_description", "msg", "message", "error"]:
			if (body as Dictionary).has(k) and String((body as Dictionary)[k]) != "":
				msg = String((body as Dictionary)[k])
				break
	var low: String = msg.to_lower()
	if low.contains("invalid login credentials"):
		return "Correo o contraseña incorrectos."
	if low.contains("email not confirmed"):
		return "Confirmá tu correo: te mandamos un enlace de verificación."
	if low.contains("already registered") or low.contains("already been registered"):
		return "Ya existe una cuenta con ese correo."
	if low.contains("password should be") or low.contains("weak"):
		return "La contraseña es muy débil: usá al menos 8 caracteres."
	if low.contains("rate limit") or code == 429:
		return "Demasiados intentos. Esperá un momento."
	if low.contains("jwt expired") or code == 401:
		return "Tu sesión venció. Volvé a iniciar sesión."
	if low.contains("unable to validate email") or low.contains("invalid email"):
		return "Ese correo no es válido."
	return msg if msg != "" else "Error del servidor (%d)." % code

# --- Auth ------------------------------------------------------------------------------------------------------------

func sign_up(email: String, password: String) -> Dictionary:
	return await request_json(HTTPClient.METHOD_POST, "/auth/v1/signup", {"email": email, "password": password}, false)

func sign_in(email: String, password: String) -> Dictionary:
	return await request_json(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": email, "password": password}, false)

func refresh(refresh_token: String) -> Dictionary:
	return await request_json(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token}, false)

func recover(email: String) -> Dictionary:
	return await request_json(HTTPClient.METHOD_POST, "/auth/v1/recover", {"email": email}, false)

func sign_out() -> Dictionary:
	return await request_json(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, true)

# --- Base de datos -----------------------------------------------------------------------------------------------------

func call_rpc(fn: String, args: Dictionary = {}) -> Dictionary:
	return await request_json(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + fn, args, true)

func select(table: String, query: String = "select=*") -> Dictionary:
	return await request_json(HTTPClient.METHOD_GET, "/rest/v1/%s?%s" % [table, query], null, true)
