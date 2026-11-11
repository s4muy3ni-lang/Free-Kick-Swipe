class_name BackendConfig
extends RefCounted
## Configuracion del servidor: res://config/backend.json = {"url": "https://<proyecto>.supabase.co", "anon_key": "..."}.
## Lo genera CI desde los GitHub Secrets SUPABASE_URL y SUPABASE_ANON_KEY (solo la clave PUBLICA: con RLS y las
## funciones del servidor no da acceso a nada que no corresponda). La service key NUNCA va aqui ni en la app.
## Sin archivo, el juego usa LocalBackend.

static var _seed: Dictionary = {}

static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	return d if d is Dictionary else {}

static func is_configured(cfg: Dictionary) -> bool:
	var url: String = String(cfg.get("url", ""))
	var key: String = String(cfg.get("anon_key", ""))
	# Una clave de servicio en el cliente seria un agujero de seguridad: se rechaza aunque alguien la ponga.
	if key.begins_with("sb_secret_") or key.contains("service_role"):
		push_warning("backend.json trae una clave de SERVICIO: se ignora (solo va la clave publica)")
		return false
	return url.begins_with("https://") and key.length() > 20

static func seed() -> Dictionary:
	if _seed.is_empty():
		var f := FileAccess.open("res://resources/online/seed.json", FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_seed = d if d is Dictionary else {}
	return _seed
