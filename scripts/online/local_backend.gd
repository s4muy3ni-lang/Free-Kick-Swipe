class_name LocalBackend
extends RefCounted
## Backend SIN servidor (no hay proyecto de Supabase configurado, pruebas, PC de desarrollo): la misma API que el
## servidor (mismos nombres de funcion, mismos resultados) con los datos en user://local_backend/. Reproduce las reglas
## del SQL (supabase/migrations) para que el juego se pueda probar entero, pero NO es online: no hay otros humanos, las
## partidas son contra bots y la interfaz lo rotula «sin servidor». Las contraseñas se guardan con sal y hash iterado.

const DIR := "user://local_backend"
const HASH_ROUNDS := 4000

var dir: String = DIR
var seed_data: Dictionary = {}
var uid: String = ""
var _accounts: Dictionary = {}
var _db: Dictionary = {}
var rng := RandomNumberGenerator.new()
## Reloj (s): las pruebas lo adelantan para no esperar de verdad.
var clock_offset: float = 0.0
## Las pruebas simulan que no hay conexion (como un error de red de Supabase).
var simulate_offline: bool = false

func _init(p_dir: String = DIR) -> void:
	dir = p_dir
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open("res://resources/online/seed.json", FileAccess.READ)
	seed_data = JSON.parse_string(f.get_as_text()) if f != null else {}
	_accounts = _read("accounts")
	rng.randomize()

func now() -> float:
	return Time.get_unix_time_from_system() + clock_offset

func _read(name: String) -> Dictionary:
	var f := FileAccess.open("%s/%s.json" % [dir, name], FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

func _write(name: String, d: Dictionary) -> void:
	var f := FileAccess.open("%s/%s.json" % [dir, name], FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))

static func _ok(data: Variant) -> Dictionary:
	return {"ok": true, "data": data}

static func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "network": false}

static func hash_password(password: String, salt: String) -> String:
	var h: String = salt + password
	for i in HASH_ROUNDS:
		h = h.sha256_text()
	return h

# --- Auth ------------------------------------------------------------------------------------------------------------

func sign_up(email: String, password: String) -> Dictionary:
	email = email.strip_edges().to_lower()
	if not RegEx.create_from_string("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$").search(email):
		return _err("Ese correo no es válido.")
	if password.length() < 8:
		return _err("La contraseña es muy débil: usá al menos 8 caracteres.")
	if _accounts.has(email):
		return _err("Ya existe una cuenta con ese correo.")
	var salt: String = "%x%x" % [rng.randi(), rng.randi()]
	var id: String = _uuid()
	_accounts[email] = {"id": id, "salt": salt, "hash": hash_password(password, salt)}
	_write("accounts", _accounts)
	return sign_in(email, password)

func sign_in(email: String, password: String) -> Dictionary:
	email = email.strip_edges().to_lower()
	var a: Dictionary = _accounts.get(email, {})
	if a.is_empty() or hash_password(password, String(a["salt"])) != String(a["hash"]):
		return _err("Correo o contraseña incorrectos.")
	uid = String(a["id"])
	_db = _read(uid)
	return _ok({"access_token": "local-" + uid, "refresh_token": "local-" + uid, "expires_in": 3600 * 24 * 365,
		"user": {"id": uid, "email": email}})

func refresh(refresh_token: String) -> Dictionary:
	if not refresh_token.begins_with("local-"):
		return _err("Tu sesión venció. Volvé a iniciar sesión.")
	uid = refresh_token.trim_prefix("local-")
	for e in _accounts:
		if String(_accounts[e]["id"]) == uid:
			_db = _read(uid)
			return _ok({"access_token": refresh_token, "refresh_token": refresh_token, "expires_in": 3600 * 24 * 365,
				"user": {"id": uid, "email": e}})
	return _err("Tu sesión venció. Volvé a iniciar sesión.")

func recover(_email: String) -> Dictionary:
	return _err("Sin servidor configurado no se pueden enviar correos de recuperación.")

func sign_out() -> Dictionary:
	uid = ""
	_db = {}
	return _ok(null)

func _uuid() -> String:
	var b := PackedByteArray()
	for i in 16:
		b.append(rng.randi() % 256)
	var h: String = b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

# --- API (los mismos nombres que las funciones del servidor) ---------------------------------------------------------

func call_rpc(fn: String, a: Dictionary = {}) -> Dictionary:
	if simulate_offline:
		return {"ok": false, "network": true, "error": "Sin conexión con el servidor"}
	if uid == "":
		return _err("no autenticado")
	if fn != "create_profile" and fn not in ["get_my_state", "get_events", "get_lobby", "get_leaderboard", "heartbeat"] \
			and not _db.has("profile"):
		return _err("primero crea tu perfil")
	match fn:
		"create_profile": return _create_profile(String(a.get("p_username", "")), String(a.get("p_display_name", "")))
		"get_my_state": return _ok(_state())
		"change_username": return _change_username(String(a.get("p_new", "")))
		"update_identity": return _update_identity(a)
		"update_appearance": return _update_appearance(a.get("p_appearance", {}))
		"spend_attribute_point": return _spend_point(String(a.get("p_attribute", "")))
		"claim_reward": return _claim_reward(String(a.get("p_idem", "")), String(a.get("p_source", "")), a.get("p_payload", {}))
		"buy_item": return _buy_item(String(a.get("p_item", "")), String(a.get("p_idem", "")))
		"use_consumable": return _use_consumable(String(a.get("p_item", "")))
		"claim_season_tier": return _claim_tier(int(a.get("p_tier", 0)), bool(a.get("p_premium", false)))
		"get_events": return _ok(_events())
		"heartbeat": return _ok(null)
		"get_lobby": return _ok({"humans_online": 0, "matches_active": 1 if _active_match().size() > 0 else 0,
			"humans_searching": {}, "world_activity": int(_db.get("matches_played", 0)), "popular": [], "local": true})
		"get_leaderboard": return _ok([])
		"find_match": return _find_match(String(a.get("p_mode", "")), int(a.get("p_fee", 0)))
		"cancel_search": _db.erase("queue"); _save(); return _ok(null)
		"start_bot_match": return _start_bot_match(String(a.get("p_mode", "")))
		"get_match": return _ok(_match_view())
		"choose_minigame": return _choose_minigame(String(a.get("p_mode", "")), int(a.get("p_level", 0)), bool(a.get("p_random", false)))
		"rematch_bot": return _rematch_bot()
		"submit_turn": return _submit_turn(String(a.get("p_kind", "")), a.get("p_payload", {}), a.get("p_side", null))
		"claim_timeout": return _claim_timeout()
		"leave_match": return _leave_match()
		"send_chat": return _send_chat(String(a.get("p_kind", "")), String(a.get("p_body", "")))
	return _err("funcion desconocida: " + fn)

func select(table: String, _query: String = "") -> Dictionary:
	return _ok(seed_data.get(table, []))

func _save() -> void:
	_write(uid, _db)

func _caps() -> Dictionary:
	return seed_data.get("caps", {})

func _item(id: String) -> Dictionary:
	for it in seed_data.get("catalog_items", []):
		if String(it["id"]) == id:
			return it
	return {}

func _mode(id: String) -> Dictionary:
	for m in seed_data.get("game_modes", []):
		if String(m["id"]) == id:
			return m
	return {}

func _season() -> Dictionary:
	var t: float = now()
	for s in seed_data.get("seasons", []):
		if t >= _ts(String(s["starts_at"])) and t < _ts(String(s["ends_at"])):
			return s
	return {}

static func _ts(iso: String) -> float:
	var clean: String = iso.replace("T", " ").substr(0, 19)
	return Time.get_unix_time_from_datetime_string(clean.replace(" ", "T"))

func _day() -> int:
	return int(now() / 86400.0)

func _state() -> Dictionary:
	if not _db.has("profile"):
		return {"profile": null}
	var p: Dictionary = (_db["profile"] as Dictionary).duplicate()
	p["level"] = PlayerProgress.level_for(int(p["xp"]))
	var boosts: Array = []
	for b in _db.get("boosts", []):
		if int(b.get("remaining", 0)) > 0 or float(b.get("expires_at", 0.0)) > now():
			boosts.append(b)
	var s: Dictionary = _season()
	var sp: Dictionary = _db.get("season", {})
	return {"profile": p, "inventory": _db.get("inventory", {}), "boosts": boosts,
		"season": null if s.is_empty() else {"id": s["id"], "points": int(sp.get("points", 0)), "premium": false,
			"claimed_free": sp.get("claimed_free", []), "claimed_premium": []},
		"active_match": _active_match().get("id", null), "local": true}

func _grant(coins: int, xp: int, season_pts: int, source: String, idem: String, boostable: bool = false) -> Dictionary:
	var ledger: Dictionary = _db.get("ledger", {})
	var p: Dictionary = _db["profile"]
	if ledger.has(idem):
		return {"applied": false, "coins": 0, "xp": 0, "balance": p["coins"], "total_xp": p["xp"]}
	if boostable:
		for b in _db.get("boosts", []):
			if String(b["kind"]) == "coins_x2" and int(b.get("remaining", 0)) > 0 and coins > 0:
				coins *= 2
				b["remaining"] = int(b["remaining"]) - 1
			elif String(b["kind"]) == "xp_x2" and float(b.get("expires_at", 0.0)) > now() and xp > 0:
				xp *= 2
	if int(p["coins"]) + coins < 0:
		return {"error": "monedas insuficientes"}
	ledger[idem] = {"source": source, "coins": coins, "xp": xp, "season": season_pts, "day": _day()}
	_db["ledger"] = ledger
	p["coins"] = int(p["coins"]) + coins
	p["xp"] = int(p["xp"]) + xp
	var sp: Dictionary = _db.get("season", {"points": 0, "claimed_free": []})
	sp["points"] = int(sp.get("points", 0)) + season_pts
	_db["season"] = sp
	_save()
	return {"applied": true, "coins": coins, "xp": xp, "balance": p["coins"], "total_xp": p["xp"]}

func _valid_username(n: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z0-9_]{3,16}$").search(n) != null

func _create_profile(username: String, display: String) -> Dictionary:
	if _db.has("profile"):
		return _err("el perfil ya existe")
	if not _valid_username(username):
		return _err("nombre de usuario invalido: 3 a 16 letras, numeros o _")
	display = display.strip_edges().substr(0, 20)
	if display.length() < 2:
		return _err("el nombre visible tiene que tener entre 2 y 20 caracteres")
	_db["profile"] = {"id": uid, "username": username, "display_name": display, "nickname": "", "country": "",
		"shirt_number": 10, "xp": 0, "coins": 0, "season_points": 0, "appearance": {},
		"attributes": {"power": 1, "accuracy": 1, "curve": 1, "height": 1, "technique": 1, "control": 1},
		"username_changes": 0, "username_changed_at": 0.0}
	var inv: Dictionary = {}
	for it in seed_data.get("catalog_items", []):
		if String(it["unlock"]) == "free" and bool(it.get("active", true)):
			inv[String(it["id"])] = 1
	_db["inventory"] = inv
	_grant(500, 0, 0, "bienvenida", "bienvenida")
	return _ok(_state())

func _change_username(n: String) -> Dictionary:
	var p: Dictionary = _db["profile"]
	if int(p["username_changes"]) > 0 and float(p["username_changed_at"]) > now() - 30 * 86400:
		return _err("podes cambiar el nombre una vez cada 30 dias")
	if not _valid_username(n):
		return _err("nombre de usuario invalido: 3 a 16 letras, numeros o _")
	p["username"] = n
	p["username_changes"] = int(p["username_changes"]) + 1
	p["username_changed_at"] = now()
	_save()
	return _ok(_state())

func _update_identity(a: Dictionary) -> Dictionary:
	var d: String = String(a.get("p_display_name", "")).strip_edges()
	var nk: String = String(a.get("p_nickname", ""))
	var c: String = String(a.get("p_country", ""))
	var n: int = int(a.get("p_number", 10))
	if d.length() < 2 or d.length() > 20 or nk.length() > 16 or c.length() > 2 or n < 1 or n > 99:
		return _err("datos de identidad invalidos")
	var p: Dictionary = _db["profile"]
	p["display_name"] = d
	p["nickname"] = nk
	p["country"] = c.to_upper()
	p["shirt_number"] = n
	_save()
	return _ok(_state())

const ITEM_KEYS := ["jersey", "shorts", "socks", "boots", "ball", "celebration", "number_style", "emote"]
const FREE_KEYS := ["jersey_color", "jersey_color2", "shorts_color", "socks_color", "boots_color", "skin", "hair",
	"hair_style", "sock_height", "sock_style"]

func _update_appearance(ap: Dictionary) -> Dictionary:
	var inv: Dictionary = _db.get("inventory", {})
	for k in ap:
		if k in ITEM_KEYS:
			var it: Dictionary = _item(String(ap[k]))
			if it.is_empty() or (String(it["unlock"]) != "free" and int(inv.get(String(ap[k]), 0)) <= 0):
				return _err("no tenes ese objeto: %s" % ap[k])
		elif k in FREE_KEYS:
			if not (ap[k] is float or ap[k] is int) or float(ap[k]) < 0 or float(ap[k]) > 31:
				return _err("valor invalido para %s" % k)
		else:
			return _err("campo de apariencia desconocido: %s" % k)
	var cur: Dictionary = (_db["profile"] as Dictionary).get("appearance", {})
	cur.merge(ap, true)
	_db["profile"]["appearance"] = cur
	_save()
	return _ok(_state())

func _spend_point(attr: String) -> Dictionary:
	var p: Dictionary = _db["profile"]
	var at: Dictionary = p["attributes"]
	if not at.has(attr):
		return _err("atributo invalido")
	var spent: int = 0
	for k in at:
		spent += int(at[k]) - 1
	if spent >= (PlayerProgress.level_for(int(p["xp"])) - 1) * 2:
		return _err("no tenes puntos de atributo (se ganan 2 por nivel)")
	if int(at[attr]) >= 10:
		return _err("ese atributo ya esta al maximo")
	at[attr] = int(at[attr]) + 1
	_save()
	return _ok(_state())

const OFFLINE_SOURCES := ["arcade", "academia", "desafio_diario", "desafio_semanal", "logro", "offline_match"]

func _claim_reward(idem: String, source: String, payload: Dictionary) -> Dictionary:
	if idem.length() < 8 or idem.length() > 80:
		return _err("clave de idempotencia invalida")
	var medal: int = clampi(int(payload.get("medal", 0)), 0, 3)
	var won: bool = bool(payload.get("won", false))
	var x: int
	var c: int
	var sp: int
	match source:
		"arcade": x = 20 + medal * 25; c = 10 + medal * 15; sp = 5 + medal * 5
		"academia": x = 15 + medal * 20; c = 5 + medal * 10; sp = 3 + medal * 3
		"desafio_diario": x = 40; c = 30; sp = 10
		"desafio_semanal": x = 150; c = 100; sp = 40
		"logro": x = 100; c = 50; sp = 0
		"offline_match": x = 30 + (20 if won else 0); c = 15 + (15 if won else 0); sp = 5 + (5 if won else 0)
		_: return _err("origen de recompensa desconocido")
	var tx: int = 0
	var tc: int = 0
	var ts: int = 0
	var ledger: Dictionary = _db.get("ledger", {})
	for k in ledger:
		var e: Dictionary = ledger[k]
		if int(e.get("day", -1)) == _day() and String(e["source"]) in OFFLINE_SOURCES:
			tx += int(e["xp"])
			tc += int(e["coins"])
			ts += int(e.get("season", 0))
	var caps: Dictionary = _caps()
	x = maxi(mini(x, int(caps.get("offline_xp", 1500)) - tx), 0)
	c = maxi(mini(c, int(caps.get("offline_coins", 800)) - tc), 0)
	sp = maxi(mini(sp, int(caps.get("offline_season", 300)) - ts), 0)
	return _ok(_grant(c, x, sp, source, idem, source in ["arcade", "offline_match"]))

func _buy_item(id: String, idem: String) -> Dictionary:
	var it: Dictionary = _item(id)
	if it.is_empty() or String(it["unlock"]) != "shop" or it.get("price_coins") == null or not bool(it.get("active", true)):
		return _err("ese objeto no se vende en la tienda")
	var p: Dictionary = _db["profile"]
	if PlayerProgress.level_for(int(p["xp"])) < int(it.get("min_level", 1)):
		return _err("necesitas nivel %d para comprarlo" % int(it["min_level"]))
	var inv: Dictionary = _db.get("inventory", {})
	if String(it["kind"]) not in ["consumable", "name_change"] and int(inv.get(id, 0)) > 0:
		if (_db.get("ledger", {}) as Dictionary).has(idem):
			return _ok(_state())
		return _err("ya lo tenes")
	var r: Dictionary = _grant(-int(it["price_coins"]), 0, 0, "compra", idem)
	if r.has("error"):
		return _err(String(r["error"]))
	if bool(r["applied"]):
		inv[id] = int(inv.get(id, 0)) + 1
		_db["inventory"] = inv
		_save()
	return _ok(_state())

func _use_consumable(id: String) -> Dictionary:
	var it: Dictionary = _item(id)
	if it.is_empty() or String(it["kind"]) != "consumable":
		return _err("no es un consumible")
	var inv: Dictionary = _db.get("inventory", {})
	if int(inv.get(id, 0)) <= 0:
		return _err("no tenes ese consumible")
	var data: Dictionary = it.get("data", {})
	var k: String = String(data.get("boost", ""))
	var boosts: Array = _db.get("boosts", [])
	for b in boosts:
		if String(b["kind"]) == k and (int(b.get("remaining", 0)) > 0 or float(b.get("expires_at", 0.0)) > now()):
			return _err("ya tenes uno activo de ese tipo")
	inv[id] = int(inv[id]) - 1
	boosts = boosts.filter(func(b: Dictionary) -> bool: return String(b["kind"]) != k)
	boosts.append({"kind": k, "remaining": int(data.get("matches", 0)),
		"expires_at": now() + 60.0 * float(data.get("minutes", 0)) if data.has("minutes") else 0.0})
	_db["boosts"] = boosts
	_save()
	return _ok(_state())

func _claim_tier(tier: int, premium: bool) -> Dictionary:
	var s: Dictionary = _season()
	if s.is_empty():
		return _err("no hay temporada activa")
	if premium:
		return _err("esa recompensa es del pase premium")
	var t: Dictionary = {}
	for x in seed_data.get("season_tiers", []):
		if int(x["tier"]) == tier:
			t = x
	var sp: Dictionary = _db.get("season", {"points": 0, "claimed_free": []})
	if t.is_empty() or int(sp.get("points", 0)) < int(t["points_required"]):
		return _err("todavia no llegaste a ese nivel de la temporada")
	var claimed: Array = sp.get("claimed_free", [])
	if claimed.has(tier):
		return _ok(_state())
	var rw: Dictionary = t.get("free_reward", {})
	if rw.has("item"):
		var inv: Dictionary = _db.get("inventory", {})
		inv[String(rw["item"])] = int(inv.get(String(rw["item"]), 0)) + 1
		_db["inventory"] = inv
	claimed.append(tier)
	sp["claimed_free"] = claimed
	_db["season"] = sp
	_grant(int(rw.get("coins", 0)), int(rw.get("xp", 0)), 0, "temporada", "season:%s:%d:false" % [s["id"], tier])
	return _ok(_state())

func _events() -> Array:
	var out: Array = []
	var t: float = now()
	var prog: Dictionary = _db.get("events", {})
	for e in seed_data.get("events", []):
		if _ts(String(e["ends_at"])) > t and _ts(String(e["starts_at"])) < t + 7 * 86400:
			var d: Dictionary = (e as Dictionary).duplicate()
			d["live"] = t >= _ts(String(e["starts_at"]))
			d["progress"] = int((prog.get(String(e["id"]), {}) as Dictionary).get("points", 0))
			d["matches"] = int((prog.get(String(e["id"]), {}) as Dictionary).get("matches", 0))
			out.append(d)
	return out

# --- Partidas (sin servidor solo hay bots) --------------------------------------------------------------------------

func _active_match() -> Dictionary:
	var m: Dictionary = _db.get("match", {})
	return m if String(m.get("status", "")) == "active" else {}

## Minijuegos online (pedido del usuario: «elegir minijuego + nivel, o aleatorio»): antes del primer turno el jugador elige
## (o sortea el servidor) la modalidad y el nivel; vale solo si la modalidad es un minijuego online y el nivel esta en su
## lista (scene_def.levels, la del contenido real). Queda guardado en la partida (minigame).
func _choose_minigame(mode: String, level: int, random: bool) -> Dictionary:
	var m: Dictionary = _active_match()
	if m.is_empty():
		return _err("no hay partida activa")
	if not (m.get("turns", []) as Array).is_empty() or int(m["shot_n"]) > 0:
		return _err("la partida ya empezo")
	var options: Array = []
	for gm in seed_data.get("game_modes", []):
		if String(gm.get("kind", "")) == "minijuego" and bool(gm.get("online", true)) and (gm.get("scene_def", {}) as Dictionary).has("levels"):
			options.append(gm)
	if random:
		var gm_r: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		var lv: Array = gm_r["scene_def"]["levels"]
		mode = String(gm_r["id"])
		level = int(lv[rng.randi_range(0, lv.size() - 1)])
	var gm: Dictionary = {}
	for o in options:
		if String(o["id"]) == mode:
			gm = o
	if gm.is_empty():
		return _err("minijuego invalido")
	if not (gm["scene_def"]["levels"] as Array).map(func(x: Variant) -> int: return int(x)).has(level):
		return _err("nivel invalido")
	m["mode"] = mode
	m["minigame"] = {"mode": mode, "game": String(gm["scene_def"].get("game", "")), "level": level, "random": random}
	_save()
	return _ok(_match_view())

## Revancha contra el mismo bot (sin volver a esperar un humano: la partida anterior ya era contra el bot), sin entrada.
func _rematch_bot() -> Dictionary:
	var old: Dictionary = _db.get("match", {})
	if old.is_empty() or String(old.get("status", "")) == "active" or not (old.get("bot") is Dictionary):
		return _err("no hay partida terminada contra un bot")
	var gm: Dictionary = _mode(String(old["mode"]))
	_db["match"] = {"id": _uuid(), "mode": old["mode"], "status": "active", "bot": old["bot"], "entry_fee": 0,
		"rounds": int(gm["rounds"]), "turn_seconds": int(gm["turn_seconds"]), "shot_n": 0, "shooter": 0,
		"turn_deadline": now() + _turn_window(gm), "score_a": 0, "score_b": 0, "timeouts_a": 0, "timeouts_b": 0,
		"winner": null, "settled": false, "turns": [], "chat": [],
		"spot_offset": rng.randi_range(0, FreeKickSpots.SPOTS.size() - 1)}
	_save()
	var v: Dictionary = _match_view()
	v["status"] = "matched"
	return _ok(v)

func _find_match(mode: String, fee: int) -> Dictionary:
	var gm: Dictionary = _mode(mode)
	if gm.is_empty():
		return _err("modo no disponible online")
	var fees: Array = (gm.get("entry_fees", [0]) as Array).map(func(x: Variant) -> int: return int(x))
	if not fees.has(fee):
		return _err("entrada invalida para este modo")
	if not _active_match().is_empty():
		var v: Dictionary = _match_view()
		v["status"] = "matched"
		return _ok(v)
	if int(_db["profile"]["coins"]) < fee:
		return _err("monedas insuficientes para la entrada")
	var q: Dictionary = _db.get("queue", {})
	if String(q.get("mode", "")) != mode or int(q.get("fee", -1)) != fee:
		q = {"mode": mode, "fee": fee, "joined_at": now()}
		_db["queue"] = q
		_save()
	return _ok({"status": "searching", "waited": now() - float(q["joined_at"]),
		"bot_after": int(_caps().get("bot_wait_seconds", 8)), "humans_searching": 0})

func _start_bot_match(mode: String) -> Dictionary:
	var q: Dictionary = _db.get("queue", {})
	if String(q.get("mode", "")) != mode:
		return _err("primero busca rival")
	if float(q["joined_at"]) > now() - float(_caps().get("bot_wait_seconds", 8)):
		return _err("todavia se esta buscando un rival humano")
	_db.erase("queue")
	var gm: Dictionary = _mode(mode)
	var fee: int = int(q["fee"])
	var level: int = PlayerProgress.level_for(int(_db["profile"]["xp"]))
	var skills: Dictionary = _db.get("bot_skill", {})
	var bot: Dictionary = BotFactory.make(rng, level, float(skills.get(mode, -1.0)), _recent_results(mode))
	skills[mode] = bot["skill"]
	_db["bot_skill"] = skills
	_db["match"] = {"id": _uuid(), "mode": mode, "status": "active", "bot": bot, "entry_fee": fee,
		"rounds": int(gm["rounds"]), "turn_seconds": int(gm["turn_seconds"]), "shot_n": 0, "shooter": 0,
		"turn_deadline": now() + _turn_window(gm), "score_a": 0, "score_b": 0, "timeouts_a": 0, "timeouts_b": 0,
		"winner": null, "settled": false, "turns": [], "chat": [],
		"spot_offset": rng.randi_range(0, FreeKickSpots.SPOTS.size() - 1)}
	if fee > 0:
		_grant(-fee, 0, 0, "entrada", "fee:" + String(_db["match"]["id"]))
	_save()
	var v: Dictionary = _match_view()
	v["status"] = "matched"
	return _ok(v)

func _turn_window(gm: Dictionary) -> float:
	return float(gm["turn_seconds"]) + float(_caps().get("grace_seconds", 5)) + float(_caps().get("result_seconds", 8))

func _recent_results(mode: String) -> Array:
	return (_db.get("recent", {}) as Dictionary).get(mode, [])

func _match_view() -> Dictionary:
	var m: Dictionary = _db.get("match", {})
	if m.is_empty():
		return {}
	var turns: Array = []
	for t in m.get("turns", []):
		turns.append({"shot_n": t["shot_n"], "side": t["side"], "kind": t["kind"],
			"payload": t["payload"] if bool(t.get("revealed", true)) or int(t["side"]) == 0 else {}})
	var mv: Dictionary = m.duplicate()
	mv.erase("turns")
	mv.erase("chat")
	return {"match": mv, "my_side": 0, "server_time": now(), "opponent": m["bot"], "turns": turns, "chat": m.get("chat", [])}

func _submit_turn(kind: String, payload: Dictionary, p_side: Variant) -> Dictionary:
	var m: Dictionary = _active_match()
	if m.is_empty():
		return _ok(_match_view())
	var side: int = 0 if p_side == null else int(p_side)
	var bot_turn: bool = side == 1
	var gm: Dictionary = _mode(String(m["mode"]))
	var late: bool = not bot_turn and now() > float(m["turn_deadline"]) + float(_caps().get("grace_seconds", 5))
	if kind == "keeper_pick":
		if String(gm["kind"]) == "minijuego" or side == int(m["shooter"]):
			return _err("ahora no te toca atajar")
		var kz: int = int(payload.get("zone", -9))
		if kz < -1 or kz >= KeeperZones.COUNT:
			return _err("zona invalida")
		for t in m["turns"]:
			if int(t["shot_n"]) == int(m["shot_n"]) and String(t["kind"]) == "keeper_pick":
				return _ok(_match_view())
		m["turns"].append({"shot_n": m["shot_n"], "side": side, "kind": "keeper_pick", "payload": {"zone": kz}, "revealed": false})
		_save()
		return _ok(_match_view())
	if kind not in ["shot", "score"]:
		return _err("tipo de turno invalido")
	if side != int(m["shooter"]):
		return _err("no es tu turno")
	var pts: int = 0
	if String(gm["kind"]) != "minijuego":
		var outcome: String = String(payload.get("outcome", "miss"))
		if outcome not in ["goal", "save", "miss", "post"]:
			return _err("resultado invalido")
		var cz: int = int(payload.get("cross_zone", -1))
		var keeper_z: float = 0.0
		var min_flight: float = REACH_FLIGHT.x
		if String(gm["kind"]) == "tiros_libres" and not bool(payload.get("timed_out", false)):
			# Tiro libre: el punto de tiro lo fija el servidor (ronda = tiro / 2); el informado tiene que coincidir. El arquero
			# se para donde corresponde a ese punto (FreeKickSpots.keeper_z) y la pelota tarda al menos FK_MIN_FLIGHT.
			var want: Vector2 = FreeKickSpots.at(int(m["shot_n"]) / 2, int(m.get("spot_offset", 0)))
			var got: Array = payload.get("spot", [])
			if got.size() < 2 or absf(float(got[0]) - want.x) > 0.6 or absf(float(got[1]) - want.y) > 0.6:
				return _err("punto de tiro invalido")
			keeper_z = FreeKickSpots.keeper_z(want.y, REACH_HALF)
			min_flight = FK_MIN_FLIGHT
		var kz: Variant = null
		for t in m["turns"]:
			if int(t["shot_n"]) == int(m["shot_n"]) and String(t["kind"]) == "keeper_pick":
				kz = int(t["payload"]["zone"])
				t["revealed"] = true
		var reach: Dictionary = keeper_rule(payload, keeper_z, min_flight)
		if reach.has("zone"):
			cz = int(reach["zone"])
		if outcome == "goal" and (cz < 0 or cz >= KeeperZones.COUNT):
			outcome = "miss"
		# Regla de atajada (la misma que el juego): sector elegido por el arquero Y punto a su alcance fisico. Pegado al
		# angulo o muy rapido para la distancia, es gol aunque haya elegido bien el sector.
		if outcome == "goal" and kz != null and int(kz) == cz and bool(reach.get("reachable", true)):
			outcome = "save"
		if late or bool(payload.get("timed_out", false)):
			outcome = "miss"
		pts = 1 if outcome == "goal" else 0
		var pl: Dictionary = payload.duplicate()
		pl.merge({"outcome": outcome, "keeper_zone": kz, "late": late, "cross_zone": cz,
			"reachable": bool(reach.get("reachable", true))}, true)
		m["turns"].append({"shot_n": m["shot_n"], "side": side, "kind": "shot", "payload": pl})
	else:
		pts = clampi(int(payload.get("points", 0)), 0, int(gm["max_points_per_turn"]))
		if late or bool(payload.get("timed_out", false)):
			pts = 0
		var pl2: Dictionary = payload.duplicate()
		pl2.merge({"points": pts, "late": late}, true)
		m["turns"].append({"shot_n": m["shot_n"], "side": side, "kind": "score", "payload": pl2})
	if side == 0:
		m["score_a"] = int(m["score_a"]) + pts
		if late:
			m["timeouts_a"] = int(m["timeouts_a"]) + 1
	else:
		m["score_b"] = int(m["score_b"]) + pts
	if int(m["timeouts_a"]) >= int(_caps().get("max_timeouts", 3)):
		_finish(m, 1, "abandoned")
	else:
		_advance(m, gm)
	_save()
	return _ok(_match_view())

## Alcance del arquero para la regla del servidor (como la funcion SQL keeper_reach_check): con el cruce informado
## (alto y ancho) recalcula el sector (el informado no manda) y, con el tiempo de vuelo acotado a lo posible
## (REACH_FLIGHT), si el punto esta al alcance de un arquero parado en el centro que se jugo antes del golpe (anticipa
## SpKeeper.PENALTY_ANTICIPATION). Sin cruce (clientes viejos) no hay chequeo de alcance: vale el sector informado.
## En los tiros libres el arquero no esta en el centro (keeper_z) y la pelota tarda mas (min_flight).
const REACH_FLIGHT := Vector2(0.3, 3.0)
const FK_MIN_FLIGHT := 0.5
const REACH_HALF := 3.66
const REACH_H := 2.44
static func keeper_rule(payload: Dictionary, keeper_z: float = 0.0, min_flight: float = REACH_FLIGHT.x) -> Dictionary:
	if not payload.has("cross_y") or not payload.has("cross_z"):
		return {}
	var p := Vector3(0.0, float(payload["cross_y"]), float(payload["cross_z"]))
	var t: float = clampf(float(payload.get("flight", min_flight)), min_flight, REACH_FLIGHT.y)
	return {"zone": KeeperZones.zone_of(p, REACH_HALF, REACH_H),
		"reachable": KeeperReach.reachable(p, keeper_z, t + SpKeeper.PENALTY_ANTICIPATION)}

func _advance(m: Dictionary, gm: Dictionary) -> void:
	var n: int = int(m["shot_n"]) + 1
	var rounds: int = int(m["rounds"])
	var rem_a: int = maxi(rounds - (n + 1) / 2, 0)
	var rem_b: int = maxi(rounds - n / 2, 0)
	var a: int = int(m["score_a"])
	var b: int = int(m["score_b"])
	var target: int = int((gm.get("scene_def", {}) as Dictionary).get("target", 0))
	var done: bool = false
	if target > 0 and (a >= target or b >= target) and n % 2 == 0:
		done = true
	elif n <= 2 * rounds and (a > b + rem_b or b > a + rem_a):
		done = true
	elif n >= 2 * rounds and n % 2 == 0 and (a != b or n >= 2 * rounds + 10):
		done = true
	m["shot_n"] = n
	if done:
		_finish(m, 0 if a > b else (1 if b > a else null), "finished")
	else:
		m["shooter"] = n % 2
		m["turn_deadline"] = now() + _turn_window(gm)

func _finish(m: Dictionary, winner: Variant, status: String) -> void:
	m["status"] = status
	m["winner"] = winner
	if bool(m["settled"]):
		return
	m["settled"] = true
	var res: String = "draw" if winner == null else ("win" if int(winner) == 0 else "loss")
	var fee: int = int(m["entry_fee"])
	var x: int = 25 + {"win": 25, "draw": 10, "loss": 0}[res]
	var c: int = 5 + {"win": fee + fee / 2 + 20, "draw": fee, "loss": 0}[res]
	var today: int = 0
	var ledger: Dictionary = _db.get("ledger", {})
	for k in ledger:
		if String(ledger[k]["source"]) == "partida_bot" and int(ledger[k].get("day", -1)) == _day():
			today += int(ledger[k]["coins"])
	c = mini(c, maxi(int(_caps().get("bot_coins", 600)) - today, 0) + (fee if res != "loss" else 0))
	_grant(c, x, 5 + (10 if res == "win" else 0), "partida_bot", "match:%s:0" % m["id"], true)
	var recent: Dictionary = _db.get("recent", {})
	var lst: Array = recent.get(String(m["mode"]), [])
	lst.append({"win": 1.0, "draw": 0.5, "loss": 0.0}[res])
	recent[String(m["mode"])] = lst.slice(maxi(lst.size() - 10, 0))
	_db["recent"] = recent
	_db["matches_played"] = int(_db.get("matches_played", 0)) + 1
	var prog: Dictionary = _db.get("events", {})
	for e in _events():
		if e["live"] and (e.get("mode") == null or String(e["mode"]) == String(m["mode"])):
			var ep: Dictionary = prog.get(String(e["id"]), {"points": 0, "matches": 0})
			ep["points"] = int(ep["points"]) + int((e.get("rewards", {}) as Dictionary).get("per_win_points" if res == "win" else "per_play_points", 0))
			ep["matches"] = int(ep["matches"]) + 1
			prog[String(e["id"])] = ep
	_db["events"] = prog

func _claim_timeout() -> Dictionary:
	var m: Dictionary = _active_match()
	if m.is_empty() or now() <= float(m["turn_deadline"]) + float(_caps().get("grace_seconds", 5)) or int(m["shooter"]) == 1:
		return _ok(_match_view())
	m["turns"].append({"shot_n": m["shot_n"], "side": 0, "kind": "timeout", "payload": {"outcome": "miss", "auto": true}})
	m["timeouts_a"] = int(m["timeouts_a"]) + 1
	if int(m["timeouts_a"]) >= int(_caps().get("max_timeouts", 3)):
		_finish(m, 1, "abandoned")
	else:
		_advance(m, _mode(String(m["mode"])))
	_save()
	return _ok(_match_view())

func _leave_match() -> Dictionary:
	var m: Dictionary = _active_match()
	if not m.is_empty():
		_finish(m, 1, "abandoned")
		_save()
	return _ok(_state())

const QUICK := ["buen_tiro", "que_atajada", "suerte", "casi", "revancha", "bien_jugado", "uy", "vamos"]
const EMOTES := ["😀", "😂", "😮", "😎", "🔥", "👏", "😅", "😤", "🙌", "⚽", "🧤", "💪"]

func _send_chat(kind: String, body: String) -> Dictionary:
	var m: Dictionary = _db.get("match", {})
	if m.is_empty():
		return _err("no es tu partida")
	var mine: Array = (m.get("chat", []) as Array).filter(func(c: Dictionary) -> bool: return String(c["who"]) == "yo")
	if not mine.is_empty() and float(mine[-1]["at"]) > now() - float(_caps().get("chat_min_seconds", 2)):
		return _err("espera un momento antes de mandar otro mensaje")
	if mine.size() >= int(_caps().get("chat_max_per_match", 30)):
		return _err("llegaste al limite de mensajes de esta partida")
	if kind == "quick" and body not in QUICK:
		return _err("frase rapida invalida")
	if kind == "emote" and body not in EMOTES:
		return _err("emoji invalido")
	if kind == "text":
		body = ChatFilter.clean(body)
		if body.length() < 1 or body.length() > 60:
			return _err("el mensaje tiene que tener entre 1 y 60 caracteres")
	m["chat"].append({"kind": kind, "body": body, "who": "yo", "from_bot": false, "at": now()})
	_save()
	return _ok(_match_view())
