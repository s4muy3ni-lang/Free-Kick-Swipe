class_name Achievements
extends RefCounted
## Logros permanentes y desafios diarios y semanales (etapa A2). Todo es local y deterministico: los diarios (3) y los
## semanales (2) rotan por el indice del dia/semana (hora del sistema), con progreso que se reinicia al cambiar el
## periodo. Cada evento del juego (gol, atajada, medalla, nivel arcade...) suma a los contadores; al llegar a la meta se
## otorga la experiencia UNA sola vez por periodo (anti-exploit: repetir no vuelve a premiar), se anota en el historial y
## se avisa con un cartel (autoload Toasts). Algunos logros abren cosmeticos (PlayerCustom). Sin tienda ni pagos.
## Los eventos NO se emiten en practica libre ni en partidas rapidas de prueba (los llamadores lo garantizan).

const PATH := "user://achievements.cfg"
static var path: String = PATH
static var _loaded: bool = false
## Para las pruebas: dia/semana fijos (-1 = reloj real) y silencio de carteles.
static var fake_day: int = -1
static var fake_week: int = -1
static var muted: bool = false

## [id, titulo, descripcion, estadistica, meta, xp, cosmetico]
const PERMANENT := [
	["goles_10", "Goleador", "Marcá 10 goles", &"gol", 10, 100, ""],
	["goles_50", "Artillero", "Marcá 50 goles", &"gol", 50, 250, "festejo_5"],
	["tl_10", "Especialista", "Marcá 10 goles de tiro libre", &"gol_tl", 10, 150, ""],
	["atajadas_10", "Guantes firmes", "Atajá 10 tiros", &"atajada", 10, 100, ""],
	["atajadas_25", "Muralla", "Atajá 25 tiros", &"atajada", 25, 200, "festejo_6"],
	["tanda_1", "Ganador de tandas", "Ganá una tanda de penales", &"tanda", 1, 80, ""],
	["tanda_5", "Rey de los penales", "Ganá 5 tandas de penales", &"tanda", 5, 200, "botines_oro"],
	["demol_1", "De una", "Derribá todos los objetivos de un nivel con un solo tiro", &"demolicion_un_tiro", 1, 120, ""],
	["arcade_5", "Arcade", "Ganá 5 niveles o partidas arcade", &"arcade", 5, 150, "botines_cromo"],
	["oro_5", "Alumno de oro", "Conseguí 5 medallas de oro", &"oro", 5, 150, ""],
	["limpias_5", "Sin tocar el aro", "Meté 5 encestes limpios", &"enceste_limpio", 5, 100, ""],
	["golf_par", "Birdie", "Terminá un hoyo de minigolf bajo el par", &"golf_bajo_par", 1, 80, ""],
	["strike_1", "Strike", "Tirá los 10 bolos de un solo golpe", &"strike", 1, 80, ""],
	["rescate_3", "Rescatista", "Completá 3 rescates", &"rescate", 3, 100, ""]]

## Desafios diarios (meta corta, 40 XP): rotan de a 3 por dia.
const DAILY := [
	["d_gol3", "Marcá 3 goles", &"gol", 3],
	["d_ataj2", "Atajá 2 tiros", &"atajada", 2],
	["d_desafio", "Completá un ejercicio o desafío con medalla", &"desafio", 1],
	["d_arcade", "Ganá un nivel arcade", &"arcade", 1],
	["d_tl", "Marcá un gol de tiro libre", &"gol_tl", 1],
	["d_bloques", "Derribá 8 bloques", &"derribo", 8],
	["d_enceste", "Meté 2 encestes", &"enceste", 2],
	["d_boton", "Hacé caer al rival en Botón de caída", &"boton", 1],
	["d_oro", "Ganá una medalla de oro", &"oro", 1],
	["d_penales", "Convertí 3 penales", &"gol_penal", 3]]
const DAILY_XP := 40

## Desafios semanales (150 XP): rotan de a 2 por semana.
const WEEKLY := [
	["s_gol15", "Marcá 15 goles", &"gol", 15],
	["s_ataj8", "Atajá 8 tiros", &"atajada", 8],
	["s_oro3", "Ganá 3 medallas de oro", &"oro", 3],
	["s_arcade5", "Ganá 5 niveles arcade", &"arcade", 5],
	["s_demol", "Limpiá 4 niveles de Demolición", &"demolicion_limpia", 4],
	["s_tanda2", "Ganá 2 tandas de penales", &"tanda", 2]]
const WEEKLY_XP := 150

## Contadores de toda la vida, del dia y de la semana; completados {clave: fecha} (la clave de un periodico lleva @indice).
static var life: Dictionary = {}
static var daily_stats: Dictionary = {}
static var weekly_stats: Dictionary = {}
static var done: Dictionary = {}
static var _day: int = -1
static var _week: int = -1

static func day_index() -> int:
	return fake_day if fake_day >= 0 else int(Time.get_unix_time_from_system() / 86400.0)

static func week_index() -> int:
	return fake_week if fake_week >= 0 else int(Time.get_unix_time_from_system() / 604800.0)

static func load_state(force: bool = false) -> void:
	if _loaded and not force:
		return
	_loaded = true
	life = {}
	daily_stats = {}
	weekly_stats = {}
	done = {}
	_day = -1
	_week = -1
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		life = cfg.get_value("ach", "life", {})
		daily_stats = cfg.get_value("ach", "daily", {})
		weekly_stats = cfg.get_value("ach", "weekly", {})
		done = cfg.get_value("ach", "done", {})
		_day = int(cfg.get_value("ach", "day", -1))
		_week = int(cfg.get_value("ach", "week", -1))
	_roll_periods()

static func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ach", "life", life)
	cfg.set_value("ach", "daily", daily_stats)
	cfg.set_value("ach", "weekly", weekly_stats)
	cfg.set_value("ach", "done", done)
	cfg.set_value("ach", "day", _day)
	cfg.set_value("ach", "week", _week)
	cfg.save(path)

static func use_path(p: String) -> void:
	path = p
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	load_state(true)

## Al cambiar el dia o la semana, el progreso periodico vuelve a cero (los completados quedan en el historial).
static func _roll_periods() -> void:
	if _day != day_index():
		_day = day_index()
		daily_stats = {}
	if _week != week_index():
		_week = week_index()
		weekly_stats = {}

## Los 3 diarios de hoy y los 2 semanales de esta semana (rotacion deterministica; pasos coprimos: sin repetidos).
static func todays_daily() -> Array:
	var out: Array = []
	var n: int = DAILY.size()
	for i in 3:
		out.append(DAILY[(day_index() + i * 3) % n])
	return out

static func this_weeks() -> Array:
	var n: int = WEEKLY.size()
	return [WEEKLY[week_index() % n], WEEKLY[(week_index() + 3) % n]]

## Progreso actual de una estadistica hacia una meta, en el alcance dado ("vida", "dia" o "semana"). Se consulta DESPUES
## de pasar al periodo vigente (los diccionarios periodicos se reemplazan al cambiar el dia o la semana).
static func progress_of(stat: StringName, goal: int, scope: String = "vida") -> int:
	load_state()
	_roll_periods()
	var stats: Dictionary = {"vida": life, "dia": daily_stats, "semana": weekly_stats}[scope]
	return mini(int(stats.get(stat, 0)), goal)

static func is_done(key: String) -> bool:
	load_state()
	return done.has(key)

static func done_date(key: String) -> String:
	return String(done.get(key, ""))

## Evento del juego: suma n a la estadistica y resuelve logros y desafios. Devuelve los titulos completados ahora.
static func event(stat: StringName, n: int = 1) -> Array:
	load_state()
	_roll_periods()
	var completed: Array = []
	life[stat] = int(life.get(stat, 0)) + n
	daily_stats[stat] = int(daily_stats.get(stat, 0)) + n
	weekly_stats[stat] = int(weekly_stats.get(stat, 0)) + n
	var today: String = Time.get_date_string_from_system()
	for d in PERMANENT:
		if StringName(d[3]) == stat and not done.has(String(d[0])) and int(life.get(stat, 0)) >= int(d[4]):
			done[String(d[0])] = today
			_grant(int(d[5]), String(d[6]))
			OnlineHooks.reward("logro", {"id": String(d[0])})
			_toast("🏆 Logro: %s" % d[1], "%s · +%d XP" % [d[2], int(d[5])])
			completed.append(String(d[1]))
	for d in todays_daily():
		var key: String = "%s@%d" % [d[0], _day]
		if StringName(d[2]) == stat and not done.has(key) and int(daily_stats.get(stat, 0)) >= int(d[3]):
			done[key] = today
			_grant(DAILY_XP, "")
			OnlineHooks.reward("desafio_diario", {"id": key})
			_toast("✅ Desafío diario", "%s · +%d XP" % [d[1], DAILY_XP])
			completed.append(String(d[1]))
	for d in this_weeks():
		var key2: String = "%s@s%d" % [d[0], _week]
		if StringName(d[2]) == stat and not done.has(key2) and int(weekly_stats.get(stat, 0)) >= int(d[3]):
			done[key2] = today
			_grant(WEEKLY_XP, "")
			OnlineHooks.reward("desafio_semanal", {"id": key2})
			_toast("📅 Desafío semanal", "%s · +%d XP" % [d[1], WEEKLY_XP])
			completed.append(String(d[1]))
	save_state()
	return completed

static func _grant(xp: int, cosmetic: String) -> void:
	PlayerProgress.load_progress()
	PlayerProgress.xp += xp
	if cosmetic != "" and not PlayerProgress.cosmetics.has(cosmetic):
		PlayerProgress.cosmetics.append(cosmetic)
	PlayerProgress.save_progress()

static func _toast(title: String, sub: String) -> void:
	if muted:
		return
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var t: Node = (loop as SceneTree).root.get_node_or_null("Toasts")
		if t != null:
			t.call("push", title, sub)

## Historial: completados ordenados del mas nuevo al mas viejo, con titulo y fecha.
static func history() -> Array:
	load_state()
	var titles: Dictionary = {}
	for d in PERMANENT:
		titles[d[0]] = d[1]
	for d in DAILY:
		titles[d[0]] = d[1]
	for d in WEEKLY:
		titles[d[0]] = d[1]
	var out: Array = []
	for key in done:
		var id: String = String(key).split("@")[0]
		out.append({"title": titles.get(id, id), "date": done[key], "periodic": String(key).contains("@")})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["date"]) > String(b["date"]))
	return out
