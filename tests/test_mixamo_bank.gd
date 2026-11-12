extends TestCase
## Integracion de la biblioteca MIXAMO (pedido «Integracion y comparacion de animaciones actuales vs Mixamo»,
## 2026-11-12): las dos bibliotecas conviven; ACTUAL es la de siempre y no carga nada de Mixamo; con MIXAMO cada rol que
## Mixamo tiene usa solo sus clips y el resto sigue con los actuales; los 133 clips (196 con espejos) cargan, tienen rol y
## los devuelve su rol (los pide cualquier sistema que pida ese rol); el arquero planifica con Mixamo y usa el actual solo
## cuando ninguna estirada de Mixamo llega; el laboratorio arma las dos estaciones y carga solo lo que muestra.
## Si la build no trae las bibliotecas de Mixamo (CI sin el secret), las pruebas que las necesitan se omiten.

const SELECTION := "res://tools/mixamo/selection_mixamo.json"

func _need_mixamo() -> bool:
	AnimBank.reset_for_tests()
	if not AnimBank.mixamo_available():
		skip("las bibliotecas de Mixamo no estan en esta build (assets/animations/mixamo_*.res)")
		return false
	return true

## Biblioteca con que arranco la prueba (la suite puede correr entera con ANIM_BANK=mixamo): _restore vuelve a esa.
static var _initial: int = -1

func _use(bank: int) -> void:
	if _initial < 0:
		_initial = AnimBank.current()
	AnimBank.set_bank(bank, false)
	SpClips.reload()
	PackLibrary.reload()
	ShotCatalog.reload()

func _restore() -> void:
	_use(_initial if _initial >= 0 else AnimBank.Bank.ACTUAL)

func test_actual_is_the_default_and_loads_nothing_from_mixamo() -> void:
	_use(AnimBank.Bank.ACTUAL)
	var keys: Array = SpClips.libraries().keys()
	keys.sort()
	check(keys == [&"f", &"k", &"s"], "ACTUAL carga solo las bibliotecas actuales (%s)" % [keys])
	var mx_seen: int = 0
	for r in SpClips.roles():
		for id in SpClips.by_role(r):
			if AnimBank.is_mixamo_id(id):
				mx_seen += 1
	check(mx_seen == 0, "ACTUAL no devuelve clips de Mixamo en ningun rol")
	check(SpClips.fallback_roles().is_empty(), "ACTUAL no tiene respaldos")
	check(ShotCatalog.path() == ShotCatalog.PATH, "ACTUAL usa el catalogo de golpeos actual")

func test_every_mixamo_clip_loads_with_its_role() -> void:
	if not _need_mixamo():
		return
	var sel: Array = JSON.parse_string(FileAccess.get_file_as_string(SELECTION))["clips"]
	check(sel.size() == 133, "la seleccion tiene los 133 clips del paquete (%d)" % sel.size())
	var all := {}
	for p in [AnimBank.MIXAMO_FIELD, AnimBank.MIXAMO_KEEPER, AnimBank.MIXAMO_SCENES]:
		var lib: AnimationLibrary = load(p) as AnimationLibrary
		check(lib != null, "carga %s" % p)
		for id in lib.get_animation_list():
			all[id] = lib.get_animation(id)
	check(all.size() == 196, "196 clips convertidos (133 + 63 espejos): %d" % all.size())
	var missing: Array = []
	var bad: Array = []
	var bones := {}
	for b in JsonRig.BONES:
		bones[b] = true
	for e in sel:
		var id := StringName(String(e["id"]))
		if not all.has(id):
			missing.append(id)
			continue
		if bool(e.get("mirror", false)) and not all.has(StringName(String(id) + "_mirror")):
			missing.append(StringName(String(id) + "_mirror"))
	for id in all:
		var a: Animation = all[id]
		var m: Dictionary = a.get_meta("pack", {})
		var tracks_ok: bool = a.get_track_count() > 0
		for i in a.get_track_count():
			var path: NodePath = a.track_get_path(i)
			if path.get_subname_count() > 0 and not bones.has(String(path.get_subname(0))):
				tracks_ok = false
		if String(m.get("role", "")) == "" or a.length <= 0.0 or not tracks_ok:
			bad.append(id)
	check(missing.is_empty(), "todos los clips de la seleccion (y sus espejos) estan: faltan %s" % [missing])
	check(bad.is_empty(), "todos tienen rol, duracion y pistas sobre los 23 huesos de JsonRig: fallan %s" % [bad])

func test_mixamo_uses_mixamo_per_role_and_actual_as_fallback() -> void:
	if not _need_mixamo():
		return
	_use(AnimBank.Bank.MIXAMO)
	var keys: Array = SpClips.libraries().keys()
	check(keys.has(&"mf") and keys.has(&"mk") and keys.has(&"ms") and keys.has(&"f"), "MIXAMO carga Mixamo y las actuales de respaldo")
	var mixed: Array = []
	var mx_roles := {}
	for r in SpClips.roles():
		var ids: Array[StringName] = SpClips.by_role(r)
		var n_mx: int = ids.filter(func(i: StringName) -> bool: return AnimBank.is_mixamo_id(i)).size()
		if n_mx > 0:
			mx_roles[r] = true
			if n_mx != ids.size():
				mixed.append(r)
	check(mixed.is_empty(), "un rol con clips de Mixamo usa SOLO los de Mixamo (mezclados: %s)" % [mixed])
	var fb: Array[StringName] = SpClips.fallback_roles()
	check(fb.has(&"wall") and fb.has(&"gk_getup"), "barrera y levantarse del arquero siguen con los actuales")
	for r in fb:
		check(not mx_roles.has(r), "el respaldo %s no tiene clips de Mixamo" % r)
		check(not SpClips.by_role(r).is_empty(), "el respaldo %s tiene clips actuales" % r)
	note("roles con Mixamo: %d · respaldos actuales: %d %s" % [mx_roles.size(), fb.size(), fb])
	# El mismo criterio en PackLibrary (arquero, modo partido) y los nombres del paquete van a su clip de Mixamo.
	var pk_mixed: Array = []
	for r in mx_roles:
		var ids: Array[StringName] = PackLibrary.by_role(r)
		if ids.any(func(i: StringName) -> bool: return not AnimBank.is_mixamo_id(i)):
			pk_mixed.append(r)
	check(pk_mixed.is_empty(), "PackLibrary: roles de Mixamo sin clips actuales mezclados (%s)" % [pk_mixed])
	if PackLibrary.json_mode():
		check(PackLibrary.resolve(&"goalkeeper_catch") == &"mx_goalkeeper_catch", "el nombre del paquete «goalkeeper_catch» es el clip de Mixamo")
		check(PackLibrary.resolve(&"Soccer_Pass_mirror") == &"mx_soccer_pass_mirror", "y su espejo")
	_restore()

## «Todas las animaciones de mixamo deben estar conectadas»: con MIXAMO, cada clip (y su espejo) lo devuelve su rol, es
## decir, lo recibe cualquier sistema que pida ese rol (penales, tiros libres, arquero, festejos, reacciones, minijuegos y
## modo partido); el laboratorio los muestra todos.
func test_every_mixamo_clip_is_reachable_by_its_role() -> void:
	if not _need_mixamo():
		return
	_use(AnimBank.Bank.MIXAMO)
	var unreachable: Array = []
	var total: int = 0
	for p in [AnimBank.MIXAMO_FIELD, AnimBank.MIXAMO_KEEPER, AnimBank.MIXAMO_SCENES]:
		var lib: AnimationLibrary = load(p) as AnimationLibrary
		for id in lib.get_animation_list():
			total += 1
			var role := StringName(String(lib.get_animation(id).get_meta("pack", {}).get("role", "")))
			if not SpClips.by_role(role).has(id) or not SpClips.has(id):
				unreachable.append(id)
	check(total == 196 and unreachable.is_empty(), "los %d clips de Mixamo los devuelve su rol (fuera: %s)" % [total, unreachable])
	var lab_total: int = AnimLab.clip_count(AnimBank.Bank.MIXAMO)
	check(lab_total == 133, "el laboratorio lista los 133 clips de Mixamo (sin espejos): %d" % lab_total)
	_restore()

func test_mixamo_shot_catalog_uses_mixamo_kicks() -> void:
	if not _need_mixamo():
		return
	_use(AnimBank.Bank.MIXAMO)
	check(ShotCatalog.path() == AnimBank.MIXAMO_SHOTS, "MIXAMO usa su catalogo de golpeos")
	var by_kind := {}
	for c in ShotCatalog.clips():
		var k: int = ShotCatalog.kind_of(c)
		if not by_kind.has(k):
			by_kind[k] = {"mx": 0, "act": 0}
		by_kind[k]["mx" if AnimBank.is_mixamo_id(StringName(String(c["id"]))) else "act"] += 1
	for k in [ShotCatalog.Kind.POWER, ShotCatalog.Kind.NORMAL, ShotCatalog.Kind.PLACED, ShotCatalog.Kind.CHIP]:
		check(by_kind.has(k) and int(by_kind[k]["mx"]) > 0 and int(by_kind[k]["act"]) == 0,
			"tipo %d: solo golpeos de Mixamo (%s)" % [k, by_kind.get(k, {})])
	check(by_kind.has(ShotCatalog.Kind.MISS) and int(by_kind[ShotCatalog.Kind.MISS]["act"]) > 0,
		"los tiros errados siguen con los actuales (Mixamo no tiene)")
	for foot in [1, -1]:
		for kind in [ShotCatalog.Kind.POWER, ShotCatalog.Kind.NORMAL, ShotCatalog.Kind.PLACED, ShotCatalog.Kind.CHIP]:
			var c: Dictionary = ShotCatalog.choose(foot, 0.0, kind, true)
			check(not c.is_empty() and AnimBank.is_mixamo_id(StringName(String(c.get("id", "")))),
				"pie %d, tipo %d: el golpeo elegido es de Mixamo (%s)" % [foot, kind, c.get("id", "")])
			if not c.is_empty():
				check(float(c["toe_y"]) <= 0.35, "pie %d, tipo %d: la punta llega baja a la pelota (%.2f m)" % [foot, kind, float(c["toe_y"])])
	note("golpeos por tipo: %s" % [by_kind])
	_restore()

## Arquero: con MIXAMO planifica con las estiradas de Mixamo y solo usa la actual cuando ninguna de Mixamo llega con
## holgura. Se compara con ACTUAL en una grilla de penales (misma trayectoria, mismo arquero).
func test_keeper_plans_with_mixamo_and_falls_back_only_when_needed() -> void:
	if not _need_mixamo() or not PackLibrary.json_mode():
		if PackLibrary.json_mode() == false:
			skip("el planificador de atajadas usa el modo JSON")
		return
	var results := {}
	for bank in [AnimBank.Bank.ACTUAL, AnimBank.Bank.MIXAMO]:
		_use(bank)
		var reach: int = 0
		var mx: int = 0
		var fb: int = 0
		var n: int = 0
		for zi in 7:
			for yi in 4:
				var target := Vector3(0.0, 0.25 + 0.6 * float(yi), -3.0 + 1.0 * float(zi))
				var start := Vector3(11.0, 0.11, 0.0)
				var traj := PackedVector3Array()
				for k in 40:
					traj.append(start.lerp(target, float(k) / 30.0))
				var pl: Dictionary = KeeperPlanner.plan_save(Vector3.ZERO, -PI * 0.5, traj, 1.0 / 30.0, 0.0, 20.0, false, [1.0, 1.25])
				n += 1
				if pl.is_empty():
					continue
				if float(pl["dist"]) <= float(pl["radius"]) * 0.85:
					reach += 1
				if AnimBank.is_mixamo_id(StringName(String(pl["clip"]))):
					mx += 1
				elif bool(pl.get("fallback", false)):
					fb += 1
		results[bank] = {"llega": reach, "mixamo": mx, "respaldo": fb, "tiros": n}
	note("ACTUAL %s · MIXAMO %s" % [results[AnimBank.Bank.ACTUAL], results[AnimBank.Bank.MIXAMO]])
	check(int(results[AnimBank.Bank.MIXAMO]["llega"]) >= int(results[AnimBank.Bank.ACTUAL]["llega"]),
		"con MIXAMO el arquero llega al menos a las mismas pelotas que con ACTUAL")
	check(int(results[AnimBank.Bank.MIXAMO]["mixamo"]) > 0, "con MIXAMO hay atajadas planificadas con clips de Mixamo")
	check(int(results[AnimBank.Bank.ACTUAL]["mixamo"]) == 0, "con ACTUAL ninguna atajada usa Mixamo")
	_restore()

func test_lab_loads_only_what_it_shows_and_compares_the_same_situation() -> void:
	var lab: AnimLab = (load(AnimLab.SCENE) as PackedScene).instantiate()
	spawn(lab)
	await physics_frames(3)
	if not AnimBank.mixamo_available():
		check(lab.mode == AnimLab.Mode.ACTUAL and lab.stations.size() == 1, "sin Mixamo en la build, el laboratorio muestra ACTUAL")
		return
	check(lab.mode == AnimLab.Mode.COMPARE and lab.stations.size() == 2, "arranca comparando las dos bibliotecas")
	lab.select_situation("Penal")
	await physics_frames(2)
	for st in lab.stations:
		check(String((st as AnimLab.Station).meta.get("role", "")) == "setpiece_shot", "%s: el penal es un golpeo de balon parado (%s)" % [AnimBank.NAMES[(st as AnimLab.Station).bank], (st as AnimLab.Station).id])
	var info: String = lab.station_info(AnimBank.Bank.MIXAMO)
	for k in ["MIXAMO", "Clip:", "Original:", "Rol:", "Esqueleto:", "Retargeting:", "Estado:", "Contacto:"]:
		check(info.contains(k), "la informacion del clip muestra «%s»" % k)
	# Mismo reloj: las dos estaciones estan en el mismo instante.
	lab.set_speed(0.5)
	await physics_frames(20)
	check(lab.speed == 0.5 and lab.playing, "velocidad x0.5 reproduciendo")
	lab.toggle_play()
	var c0: float = lab.clock
	await physics_frames(5)
	check(is_equal_approx(lab.clock, c0), "pausa: el reloj comun no avanza")
	lab.set_mode(AnimLab.Mode.ACTUAL)
	await physics_frames(2)
	check(lab.stations.size() == 1 and (lab.stations[0] as AnimLab.Station).bank == AnimBank.Bank.ACTUAL, "ACTUAL: una estacion, sin las bibliotecas de Mixamo")
	var libs: Array = (lab.stations[0] as AnimLab.Station).player.get_animation_library_list()
	check(not libs.has(&"mf") and not libs.has(&"mk"), "el reproductor de ACTUAL no tiene las bibliotecas de Mixamo")
	for c in AnimLab.CATEGORIES:
		lab.select_category(c)
	check(true, "las 11 categorias se recorren sin errores")
	lab.queue_free()

func test_switching_bank_at_runtime_plays_a_penalty() -> void:
	if not _need_mixamo():
		return
	_use(AnimBank.Bank.MIXAMO)
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(30)
	var mx_actor: bool = false
	for a in game.find_children("*", "SpActor", true, false):
		if AnimBank.is_mixamo_id((a as SpActor).clip_id):
			mx_actor = true
	check(mx_actor, "con MIXAMO hay jugadores usando clips de Mixamo en el penal")
	game.queue_free()
	await physics_frames(2)
	_restore()

## Tiro libre: los defensores retroceden mirando la pelota con la marcha direccional que corresponde (hacia atras, de
## costado o en diagonal); con MIXAMO, la de Mixamo.
func test_defenders_track_back_with_directional_loops() -> void:
	var face := Vector3(-1, 0, 0)
	for bank in ([AnimBank.Bank.ACTUAL, AnimBank.Bank.MIXAMO] if AnimBank.mixamo_available() else [AnimBank.Bank.ACTUAL]):
		_use(bank)
		var back: StringName = SpFieldPlayers.dir_loop(Vector3(1, 0, 0), face, 3.5)
		var side: StringName = SpFieldPlayers.dir_loop(Vector3(0, 0, 1), face, 3.5)
		var fwd: StringName = SpFieldPlayers.dir_loop(Vector3(-1, 0, 0), face, 3.5)
		note("%s: atras %s · costado %s · adelante %s" % [AnimBank.NAMES[bank], back, side, fwd])
		check(String(SpClips.meta(back).get("role", "")) in ["dir_back", "dir_back_diag"], "%s: hacia atras usa una marcha hacia atras" % AnimBank.NAMES[bank])
		check(String(SpClips.meta(side).get("role", "")) in ["dir_side", "dir_back_diag", "dir_fwd_diag"], "%s: de costado usa una marcha lateral" % AnimBank.NAMES[bank])
		check(not SpFieldPlayers._is_dir(fwd), "%s: hacia adelante, el trote de siempre" % AnimBank.NAMES[bank])
		if bank == AnimBank.Bank.MIXAMO:
			check(AnimBank.is_mixamo_id(back) and AnimBank.is_mixamo_id(side), "MIXAMO: las marchas direccionales son de Mixamo")
			for v in [1.0, 2.0, 3.5, 5.0]:
				var lp: StringName = SpShooter._loop_for(v)
				check(AnimBank.is_mixamo_id(lp), "MIXAMO: la marcha a %.1f m/s es de Mixamo (%s, %.2f m/s)" % [v, lp, float(SpClips.meta(lp).get("natural_speed_json", 0.0))])
	_restore()
