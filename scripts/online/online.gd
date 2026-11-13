extends Node
## Autoload «Online»: cuenta, sesion, estado del jugador y sincronizacion con el servidor.
##  - Servidor: Supabase si res://config/backend.json trae url y clave publica (CI lo genera desde los GitHub Secrets);
##    si no, LocalBackend (misma API en el dispositivo, rotulado «sin servidor»).
##  - Sesion: se recuerda cifrada en user:// (si el jugador lo elige). Al abrir, se renueva el token; sin conexion se entra
##    igual con la sesion y el ultimo estado guardados (modo offline) y el progreso queda en la cola.
##  - Cola de sincronizacion: cada premio local (arcade, academia, desafios, partidas offline) se guarda con una clave de
##    idempotencia; se envia cuando hay conexion. El servidor recalcula el monto y nunca cobra dos veces la misma clave,
##    asi que reintentar es seguro (desconexiones, cierres de la app, doble envio).

signal auth_changed
signal state_changed

const CONFIG_PATH := "res://config/backend.json"
const SESSION_PATH := "user://session.dat"
const STATE_PATH := "user://state_cache.json"
const QUEUE_PATH := "user://sync_queue.json"
const HEARTBEAT_S := 45.0

var api: SupabaseApi = null
var local: LocalBackend = null
var session: Dictionary = {}
var state: Dictionary = {}
var offline: bool = false
var remember: bool = true
var queue: Array = []
var last_error: String = ""
var _heartbeat_t: float = 0.0
var _flushing: bool = false
var _session_path: String = SESSION_PATH
var _state_path: String = STATE_PATH
var _queue_path: String = QUEUE_PATH

func _ready() -> void:
	var cfg: Dictionary = BackendConfig.load_config(CONFIG_PATH)
	if BackendConfig.is_configured(cfg):
		api = SupabaseApi.new()
		api.name = "SupabaseApi"
		add_child(api)
		api.setup(String(cfg["url"]), String(cfg["anon_key"]))
	else:
		local = LocalBackend.new()
	_load_files()

## Para las pruebas: backend local aislado en otra carpeta, sin sesion ni cola previas.
func use_local(dir: String) -> void:
	if api != null:
		api.queue_free()
		api = null
	for f in ["session.dat", "state_cache.json", "sync_queue.json"]:
		if FileAccess.file_exists(dir + "/" + f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "/" + f))
	DirAccess.make_dir_recursive_absolute(dir)
	local = LocalBackend.new(dir)
	_session_path = dir + "/session.dat"
	_state_path = dir + "/state_cache.json"
	_queue_path = dir + "/sync_queue.json"
	session = {}
	state = {}
	queue = []
	offline = false

func has_server() -> bool:
	return api != null

func backend_label() -> String:
	if api == null:
		return "Sin servidor configurado: cuenta local de prueba"
	return "Sin conexión: jugando offline" if offline else "Conectado"

func signed_in() -> bool:
	return not session.is_empty()

func has_profile() -> bool:
	return state.get("profile") is Dictionary

func profile() -> Dictionary:
	return state.get("profile", {}) if state.get("profile") is Dictionary else {}

func coins() -> int:
	return int(profile().get("coins", 0))

func level() -> int:
	return int(profile().get("level", PlayerProgress.level_for(int(profile().get("xp", 0)))))

func inventory() -> Dictionary:
	return state.get("inventory", {}) if state.get("inventory") is Dictionary else {}

func owns(item_id: String) -> bool:
	return int(inventory().get(item_id, 0)) > 0

# --- Auth ------------------------------------------------------------------------------------------------------------

func _auth_call(fn: String, a: String, b: String = "") -> Dictionary:
	if api != null:
		match fn:
			"sign_up": return await api.sign_up(a, b)
			"sign_in": return await api.sign_in(a, b)
			"refresh": return await api.refresh(a)
			"recover": return await api.recover(a)
			"sign_out": return await api.sign_out()
	match fn:
		"sign_up": return local.sign_up(a, b)
		"sign_in": return local.sign_in(a, b)
		"refresh": return local.refresh(a)
		"recover": return local.recover(a)
	return local.sign_out()

## Registro. Con verificacion de correo activa en Supabase no hay sesion hasta confirmar: needs_verification = true.
func sign_up(email: String, password: String, keep: bool = true) -> Dictionary:
	if password.length() < 8:
		return {"ok": false, "error": "La contraseña es muy débil: usá al menos 8 caracteres."}
	var r: Dictionary = await _auth_call("sign_up", email.strip_edges(), password)
	if not r.get("ok", false):
		return r
	var d: Dictionary = r.get("data", {}) if r.get("data") is Dictionary else {}
	if not d.has("access_token"):
		return {"ok": true, "needs_verification": true}
	_take_session(d, keep)
	await refresh_state()
	return {"ok": true}

func sign_in(email: String, password: String, keep: bool = true) -> Dictionary:
	var r: Dictionary = await _auth_call("sign_in", email.strip_edges(), password)
	if not r.get("ok", false):
		return r
	_take_session(r["data"], keep)
	await refresh_state()
	flush()
	return {"ok": true}

func recover(email: String) -> Dictionary:
	return await _auth_call("recover", email.strip_edges())

func sign_out() -> void:
	await _auth_call("sign_out", "")
	session = {}
	state = {}
	if api != null:
		api.access_token = ""
	for p in [_session_path, _state_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	auth_changed.emit()

## Al abrir el juego: renueva la sesion guardada. Sin conexion entra igual (offline) con el estado guardado.
func restore_session() -> bool:
	if session.is_empty():
		return false
	var r: Dictionary = await _auth_call("refresh", String(session.get("refresh_token", "")))
	if r.get("ok", false):
		_take_session(r["data"], remember)
		offline = false
		await refresh_state()
		flush()
		return true
	if r.get("network", false):
		offline = true
		if api != null:
			api.access_token = String(session.get("access_token", ""))
		auth_changed.emit()
		return true
	session = {}
	_save_session()
	return false

func _take_session(d: Dictionary, keep: bool) -> void:
	remember = keep
	session = {"access_token": d.get("access_token", ""), "refresh_token": d.get("refresh_token", ""),
		"expires_at": Time.get_unix_time_from_system() + float(d.get("expires_in", 3600)), "user": d.get("user", {})}
	if api != null:
		api.access_token = String(session["access_token"])
	offline = false
	_save_session()
	auth_changed.emit()

# --- Llamadas al servidor -------------------------------------------------------------------------------------------

## Llama a una funcion del servidor (o del backend local). Devuelve {ok, data, error, network}.
func call_fn(fn: String, args: Dictionary = {}) -> Dictionary:
	var r: Dictionary
	if api != null:
		if Time.get_unix_time_from_system() > float(session.get("expires_at", 0.0)) - 60.0 and session.has("refresh_token"):
			var rr: Dictionary = await api.refresh(String(session["refresh_token"]))
			if rr.get("ok", false):
				_take_session(rr["data"], remember)
		r = await api.call_rpc(fn, args)
		offline = bool(r.get("network", false))
	else:
		r = local.call_rpc(fn, args)
	if not r.get("ok", false):
		last_error = String(r.get("error", ""))
	return r

## Las funciones que devuelven el estado del jugador lo actualizan aqui.
func call_state_fn(fn: String, args: Dictionary = {}) -> Dictionary:
	var r: Dictionary = await call_fn(fn, args)
	if r.get("ok", false) and r.get("data") is Dictionary and (r["data"] as Dictionary).has("profile"):
		_set_state(r["data"])
	return r

func refresh_state() -> Dictionary:
	return await call_state_fn("get_my_state")

func _set_state(s: Dictionary) -> void:
	state = s
	var f := FileAccess.open(_state_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(state))
	state_changed.emit()

## Datos publicos (catalogo, modos, temporada, eventos). Sin servidor o sin conexion: los del juego (seed.json).
func catalog(table: String) -> Array:
	if api != null and not offline:
		var r: Dictionary = await api.select(table, "select=*")
		if r.get("ok", false) and r.get("data") is Array:
			return r["data"]
	var seed: Dictionary = local.seed_data if local != null else BackendConfig.seed()
	return seed.get(table, [])

# --- Cola de sincronizacion -----------------------------------------------------------------------------------------

## Encola un premio de juego local; el servidor decide el monto. Devuelve la clave de idempotencia.
func queue_reward(source: String, payload: Dictionary) -> String:
	if not signed_in():
		return ""
	var key: String = "%s-%d-%08x%08x" % [source, int(Time.get_unix_time_from_system()), randi(), randi()]
	queue.append({"fn": "claim_reward", "args": {"p_idem": key, "p_source": source, "p_payload": payload}, "tries": 0})
	_save_queue()
	flush()
	return key

## Apariencia elegida sin conexion: se encola UNA operacion update_appearance (las elecciones siguientes se mezclan en
## ella, gana la ultima de cada campo), asi al volver se manda una vez y no se duplica nada.
func queue_appearance(ap: Dictionary) -> void:
	if not signed_in() or ap.is_empty():
		return
	for op in queue:
		if String(op["fn"]) == "update_appearance":
			(op["args"]["p_appearance"] as Dictionary).merge(ap, true)
			_save_queue()
			flush()
			return
	queue.append({"fn": "update_appearance", "args": {"p_appearance": ap.duplicate()}, "tries": 0})
	_save_queue()
	flush()

## Envia la cola. Un error de red la deja para despues; un rechazo del servidor (regla, tope, duplicado) la descarta.
func flush() -> void:
	if _flushing or not signed_in() or queue.is_empty():
		return
	_flushing = true
	while not queue.is_empty():
		var op: Dictionary = queue[0]
		var r: Dictionary = await call_fn(String(op["fn"]), op["args"])
		if r.get("network", false):
			op["tries"] = int(op.get("tries", 0)) + 1
			break
		queue.pop_front()
		_save_queue()
	_flushing = false
	if not offline:
		await refresh_state()

func _process(delta: float) -> void:
	if not signed_in() or not has_profile():
		return
	_heartbeat_t += delta
	if _heartbeat_t >= HEARTBEAT_S:
		_heartbeat_t = 0.0
		call_fn("heartbeat")
		if not queue.is_empty():
			flush()

# --- Archivos locales -------------------------------------------------------------------------------------------------

func _key() -> String:
	return ("fks-" + OS.get_unique_id()).sha256_text()

func _save_session() -> void:
	if session.is_empty() or not remember:
		if FileAccess.file_exists(_session_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_session_path))
		return
	var f := FileAccess.open_encrypted_with_pass(_session_path, FileAccess.WRITE, _key())
	if f != null:
		f.store_string(JSON.stringify(session))

func _save_queue() -> void:
	var f := FileAccess.open(_queue_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(queue))

func _load_files() -> void:
	if FileAccess.file_exists(_session_path):
		var f := FileAccess.open_encrypted_with_pass(_session_path, FileAccess.READ, _key())
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			session = d if d is Dictionary else {}
	var s := FileAccess.open(_state_path, FileAccess.READ)
	if s != null:
		var d2: Variant = JSON.parse_string(s.get_as_text())
		state = d2 if d2 is Dictionary else {}
	var q := FileAccess.open(_queue_path, FileAccess.READ)
	if q != null:
		var d3: Variant = JSON.parse_string(q.get_as_text())
		queue = d3 if d3 is Array else []
