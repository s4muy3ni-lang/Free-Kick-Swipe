extends TestCase
## Progresion del jugador (pedido del usuario: «atributos con efecto real, medible y comprobable… no permitir que una
## estadistica alta haga ganar automaticamente… limites… especializacion… redistribuir bajo reglas… XP sin poder
## explotarla… pruebas para los valores minimos, intermedios y maximos de cada atributo… tabla de progresion probada con
## simulaciones»). Reglas: ProgressionRules; efectos: AttributeEffects; servidor: LocalBackend (las mismas reglas que el SQL).

const DIR := "user://test_progression"
const MIN := 1
const MID := 5
const MAX := 10

func _online() -> Node:
	var o: Node = tree.root.get_node("Online")
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/" + f))
	o.use_local(DIR)
	await o.sign_up("progreso@futbol.com", "golazo123")
	await o.call_state_fn("create_profile", {"p_username": "Progreso", "p_display_name": "Progreso"})
	return o

## Deja la cuenta de prueba sin atributos (los otros juegos de pruebas leen el perfil del autoload).
func _done(o: Node) -> void:
	await o.sign_out()

func _set_xp(o: Node, xp: int) -> void:
	o.local._db["profile"]["xp"] = xp
	o.local._save()
	await o.refresh_state()

func _attrs(v: int, keys: Array = ProgressionRules.all()) -> Dictionary:
	var a := {}
	for k in keys:
		a[k] = v
	return a

# --- Reglas -----------------------------------------------------------------------------------------------------------

func test_rules_costs_caps_and_style() -> void:
	check(ProgressionRules.cost_to(2) == 1 and ProgressionRules.cost_to(5) == 1 and ProgressionRules.cost_to(6) == 2
		and ProgressionRules.cost_to(8) == 2 and ProgressionRules.cost_to(9) == 3 and ProgressionRules.cost_to(10) == 3,
		"costo creciente: 1 hasta el 5, 2 del 6 al 8, 3 el 9 y el 10")
	check(ProgressionRules.cost_of(10) == 16, "llevar un atributo al maximo cuesta 16 puntos")
	check(ProgressionRules.earned(1) == 0 and ProgressionRules.earned(9) == 16 and ProgressionRules.earned(30) == 58
		and ProgressionRules.earned(80) == 58, "2 puntos por nivel hasta el nivel 30 (58), despues no mas")
	var all_max: int = ProgressionRules.spent(_attrs(MAX))
	note("todo al maximo costaria %d puntos; el tope es %d" % [all_max, ProgressionRules.earned(ProgressionRules.POINT_LEVEL_CAP)])
	check(all_max > ProgressionRules.earned(ProgressionRules.POINT_LEVEL_CAP) * 2, "no se puede tener todo: hay que elegir un estilo")
	check(ProgressionRules.can_raise(9, {"power": 10}, "power").contains("maximo"), "tope 10 por atributo")
	check(ProgressionRules.can_raise(1, {}, "power").contains("puntos"), "sin puntos no hay mejora")
	check(ProgressionRules.can_raise(9, {}, "velocidad").contains("invalido"), "atributo inventado")
	check(ProgressionRules.can_raise(2, {}, "power") == "", "nivel 2: 2 puntos, alcanza para una mejora")
	check(ProgressionRules.xp_in_level(0) == Vector2i(0, 150) and ProgressionRules.xp_in_level(200) == Vector2i(50, 300),
		"experiencia dentro del nivel (para la barra)")
	check(String(ProgressionRules.specialization({})["id"]) == "nuevo", "sin puntos: en formacion")
	check(String(ProgressionRules.specialization({"power": 8, "accuracy": 4})["id"]) == "power", "especialista en potencia")
	check(String(ProgressionRules.specialization({"curve": 7, "control": 4})["name"]).contains("efecto"), "especialista en efecto")
	check(String(ProgressionRules.specialization(_attrs(5, ProgressionRules.SHOOTER))["id"]) == "completo", "parejo: jugador completo")
	check(String(ProgressionRules.specialization({"keeper_reach": 8, "power": 2})["id"]) == "arquero", "puntos en el arco: arquero")
	var r0: Dictionary = ProgressionRules.respec_state(0, 0.0, 1000.0)
	var r1: Dictionary = ProgressionRules.respec_state(1, 1000.0, 1000.0 + 86400.0)
	var r2: Dictionary = ProgressionRules.respec_state(1, 1000.0, 1000.0 + 8 * 86400.0)
	check(bool(r0["free"]) and not bool(r1["free"]) and float(r1["wait"]) > 0.0 and float(r2["wait"]) == 0.0
		and int(r2["cost"]) == ProgressionRules.RESPEC_COINS, "redistribucion: gratis la primera, despues cada 7 dias y con costo")

# --- Servidor local (mismas reglas que el SQL) --------------------------------------------------------------------------

func test_server_validates_upgrades_history_and_respec() -> void:
	var o: Node = await _online()
	var r: Dictionary = await o.call_state_fn("spend_attribute_point", {"p_attribute": "power"})
	check(not r["ok"] and String(r["error"]).contains("puntos"), "nivel 1: sin puntos, el servidor rechaza")
	await _set_xp(o, 5400)
	check(int(o.state["progression"]["points_available"]) == 16, "nivel 9: 16 puntos")
	for i in 9:
		await o.call_state_fn("spend_attribute_point", {"p_attribute": "accuracy"})
	var pr: Dictionary = o.state["progression"]
	check(int(o.profile()["attributes"]["accuracy"]) == 10 and int(pr["points_available"]) == 0 and int(pr["points_spent"]) == 16,
		"precision al maximo con 16 puntos")
	r = await o.call_state_fn("spend_attribute_point", {"p_attribute": "accuracy"})
	check(not r["ok"] and String(r["error"]).contains("maximo"), "no pasa de 10")
	r = await o.call_state_fn("spend_attribute_point", {"p_attribute": "power"})
	check(not r["ok"] and int(o.profile()["attributes"].get("power", 1)) == 1, "sin puntos no cambia nada")
	var hist: Array = o.state["progression"]["history"]
	check(hist.size() == 9 and int(hist[8]["cost"]) == 3 and int(hist[8]["to"]) == 10, "historial de mejoras con el costo de cada una")
	# Redistribucion: gratis la primera.
	var coins0: int = o.coins()
	r = await o.call_state_fn("respec_attributes", {"p_idem": "respec-test-0001"})
	check(r["ok"] and o.coins() == coins0 and int(o.profile()["attributes"]["accuracy"]) == 1
		and int(o.state["progression"]["points_available"]) == 16, "primera redistribucion gratis: puntos recuperados")
	await o.call_state_fn("spend_attribute_point", {"p_attribute": "keeper_reach"})
	r = await o.call_state_fn("respec_attributes", {"p_idem": "respec-test-0002"})
	check(not r["ok"] and String(r["error"]).contains("dias"), "la segunda espera 7 dias")
	o.local.clock_offset = 8 * 86400.0
	r = await o.call_state_fn("respec_attributes", {"p_idem": "respec-test-0003"})
	check(r["ok"] and o.coins() == coins0 - ProgressionRules.RESPEC_COINS, "pasados 7 dias cuesta %d monedas" % ProgressionRules.RESPEC_COINS)
	await o.call_state_fn("respec_attributes", {"p_idem": "respec-test-0003"})
	check(o.coins() == coins0 - ProgressionRules.RESPEC_COINS and int(o.profile()["respecs"]) == 2, "misma clave: no cobra dos veces")
	o.local.clock_offset = 16 * 86400.0
	o.local._db["profile"]["coins"] = 100
	await o.call_state_fn("spend_attribute_point", {"p_attribute": "power"})
	r = await o.call_state_fn("respec_attributes", {"p_idem": "respec-test-0004"})
	check(not r["ok"] and int(o.local._db["profile"]["attributes"]["power"]) == 2 and int(o.local._db["profile"]["coins"]) == 100,
		"sin monedas no se redistribuye ni se cobra")
	o.local.clock_offset = 0.0
	await _done(o)

func test_xp_rewards_cannot_be_farmed() -> void:
	var o: Node = await _online()
	var r: Dictionary = await o.call_fn("claim_reward", {"p_idem": "offmatch-t-0001", "p_source": "offline_match",
		"p_payload": {"won": true, "goals": 99, "saves": 99}})
	check(int(r["data"]["xp"]) == 100, "partida ganada: 50 + goles y atajadas con tope de 5 cada uno (100 XP)")
	var xps: Array = [int(r["data"]["xp"])]
	for i in range(2, 21):
		r = await o.call_fn("claim_reward", {"p_idem": "offmatch-t-%04d" % i, "p_source": "offline_match",
			"p_payload": {"won": true, "goals": 5, "saves": 5}})
		xps.append(int(r["data"]["xp"]))
	note("XP de 20 partidas offline seguidas: %s" % str(xps))
	check(xps[7] == 100 and xps[8] == 50 and xps[16] == 25, "rendimiento decreciente: 8 enteras, hasta 16 a la mitad, despues un cuarto")
	var dup: Dictionary = await o.call_fn("claim_reward", {"p_idem": "offmatch-t-0001", "p_source": "offline_match", "p_payload": {"won": true}})
	check(not bool(dup["data"]["applied"]), "la misma partida no se cobra dos veces")
	# Con el doble de XP activo, el tope diario tampoco se pasa.
	o.local._db["boosts"] = [{"kind": "xp_x2", "remaining": 0, "expires_at": o.local.now() + 3600.0}]
	for i in 30:
		await o.call_fn("claim_reward", {"p_idem": "arcade-t-%04d" % i, "p_source": "arcade", "p_payload": {"medal": 3}})
	var today: int = 0
	for k in o.local._db["ledger"]:
		var e: Dictionary = o.local._db["ledger"][k]
		if String(e["source"]) in LocalBackend.OFFLINE_SOURCES:
			today += int(e["xp"])
	note("XP del dia con el doble de XP: %d (tope 1500)" % today)
	check(today <= 1500, "el tope diario vale aun con el doble de XP")
	await _done(o)

# --- Efecto de cada atributo: minimo, intermedio y maximo -------------------------------------------------------------

func test_each_attribute_at_min_mid_max() -> void:
	var base := GestureTuning.new()
	check(AttributeEffects.tuning_for(base, _attrs(MIN)) == base, "todo en 1: el mismo modelo del gesto de siempre (sin cambios)")
	var rows: PackedStringArray = []
	var prev := {}
	for v in [MIN, MID, MAX]:
		var t: GestureTuning = AttributeEffects.tuning_for(base, _attrs(v))
		var fk: Vector2 = AttributeEffects.speed_range(SetPieceGame.FK_SPEED, _attrs(v))
		var row := {"speed": fk.y, "aim": t.error_base + t.error_power, "spin": t.spin_max, "pitch": AttributeEffects.pitch_ratio(_attrs(v)),
			"lift": t.ascend_lift, "rough": t.error_rough, "tech": AttributeEffects.type_error_factor(_attrs(v), "con_efecto"),
			"short": t.error_short, "length": t.length_full, "reach": AttributeEffects.keeper_reach_scale(_attrs(v)),
			"react": AttributeEffects.keeper_react_bias(_attrs(v)), "catch": AttributeEffects.keeper_catch_scale(_attrs(v))}
		rows.append("%2d: vel %.2f · desvio %.2f° · efecto %.1f · vertical %.2f · levantar %.2f · irregular %.2f · tecnico x%.2f · corto %.2f · trazo %.2f · alcance x%.3f · reaccion %+.3f s · atrapa x%.2f" % [
			v, row["speed"], row["aim"], row["spin"], row["pitch"], row["lift"], row["rough"], row["tech"], row["short"], row["length"],
			row["reach"], row["react"], row["catch"]])
		if not prev.is_empty():
			check(row["speed"] > prev["speed"] and row["aim"] < prev["aim"] and row["spin"] > prev["spin"] and row["pitch"] < prev["pitch"]
				and row["lift"] > prev["lift"] and row["rough"] < prev["rough"] and row["tech"] < prev["tech"] and row["short"] < prev["short"]
				and row["reach"] > prev["reach"] and row["react"] < prev["react"] and row["catch"] > prev["catch"],
				"de %d a %d todos los atributos mejoran su parametro" % [int(prev["v"]), v])
		row["v"] = v
		prev = row
	for r in rows:
		note(r)
	# Topes (el valor 10): cambios chicos.
	var top: Dictionary = _attrs(MAX)
	check(is_equal_approx(AttributeEffects.speed_range(SetPieceGame.FK_SPEED, top).y, SetPieceGame.FK_SPEED.y * 1.06), "potencia: a lo sumo +6 % de velocidad maxima")
	check(AttributeEffects.speed_range(SetPieceGame.FK_SPEED, top).x == SetPieceGame.FK_SPEED.x, "la velocidad minima no cambia")
	var tt: GestureTuning = AttributeEffects.tuning_for(base, top)
	check(is_equal_approx(tt.error_base, base.error_base * 0.75) and tt.error_base > 0.0, "precision: a lo sumo 25 % menos de desvio (nunca cero)")
	check(is_equal_approx(tt.spin_max, base.spin_max * 1.15), "efecto: a lo sumo +15 %")
	check(AttributeEffects.keeper_reach_scale(top) <= KeeperReach.SCALE_LIMITS.y and AttributeEffects.keeper_react_bias(top) >= KeeperReach.REACT_LIMITS.x,
		"arquero dentro de los limites de KeeperReach")
	# Cada atributo mueve solo lo suyo.
	var only_power: GestureTuning = AttributeEffects.tuning_for(base, {"power": MAX})
	check(only_power.error_base == base.error_base and only_power.spin_max == base.spin_max, "la potencia no toca la precision ni el efecto")
	check(AttributeEffects.speed_range(SetPieceGame.FK_SPEED, {"accuracy": MAX}).y == SetPieceGame.FK_SPEED.y, "la precision no toca la velocidad")
	check(AttributeEffects.type_error_factor(top, "potente_raso") == 1.0, "la tecnica solo cuenta en los tiros tecnicos")

## Con la pelota y el tirador reales: la potencia sube la velocidad con que sale la pelota.
func test_power_changes_the_real_ball_speed() -> void:
	var speeds: Array = []
	for v in [MIN, MAX]:
		SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
		SetPieceGame.next_vs = SetPieceGame.Vs.CPU
		var g: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
		g.fast = true
		g.user_attrs = {"power": v}
		spawn(g)
		await physics_frames(10)
		g.shoot(Vector3(g.gx, 1.0, 1.5), 1.0, 0.0)
		var n: int = 0
		while g.phase != SetPieceGame.Phase.FLIGHT and n < 600:
			await tree.physics_frame
			n += 1
		await physics_frames(2)
		speeds.append(g.ball.linear_velocity.length())
		cleanup()
	note("velocidad de la pelota a potencia maxima: atributo 1 %.2f m/s, atributo 10 %.2f m/s" % [speeds[0], speeds[1]])
	check(speeds[1] > speeds[0] * 1.03 and speeds[1] < speeds[0] * 1.08, "la potencia 10 sale entre 3 % y 8 % mas rapido")

## Mismo gesto, mismos sorteos: la precision, la altura y la tecnica achican el desvio; el efecto curva mas. Se usa el mismo
## camino que el tiro del juego (GestureShotModel -> ShotSolver.perturb -> BallPredictor).
func test_aim_height_technique_and_curve_on_the_shot_pipeline() -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK
	SetPieceGame.next_vs = SetPieceGame.Vs.PRACTICE
	var g: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	g.fast = true
	g.user_attrs = {"power": 1}
	spawn(g)
	await physics_frames(10)
	var target := Vector3(g.gx, 1.3, 1.8)
	var spread := func(attrs: Dictionary, curvature: float, smooth: float) -> Dictionary:
		var t: GestureTuning = AttributeEffects.tuning_for(GestureTuning.current(), attrs)
		var f := {"length": 0.3, "avg_speed": 3.2, "peak_speed": 3.6, "smoothness": smooth, "vertical": 0.3,
			"end_dir": Vector2(0, -1), "end_accel": 0.0, "curvature": curvature}
		var ctx: Dictionary = g.shot_context(attrs)
		var p: ShotParams = GestureShotModel.build(f, g.cam.unproject_position(target), g.cam, g.ball_spot, ctx, t)
		GestureShotModel.solve(p, g.ball_spot, ctx, false)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var zs: Array = []
		var ys: Array = []
		for i in 160:
			var v: Vector3 = ShotSolver.perturb(p.velocity, p.error_deg * AttributeEffects.type_error_factor(attrs, p.gesture_type), rng,
				AttributeEffects.pitch_ratio(attrs))
			var c: Vector3 = ShotSolver.crossing(BallPredictor.trajectory(g.ball_spot, v, 3.0, 1.0 / 60.0, p.spin, true), g.gx)
			if c != Vector3.INF:
				zs.append(c.z)
				ys.append(c.y)
		var bend: float = 0.0
		for q in p.trajectory:
			# Separacion de la recta pelota -> cruce (cuanto se curva).
			var a: Vector3 = g.ball_spot
			var b: Vector3 = p.crossing if p.crossing != Vector3.INF else target
			var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
			var rel := Vector3(q.x - a.x, 0.0, q.z - a.z)
			bend = maxf(bend, (rel - dir * rel.dot(dir)).length())
		return {"z": _std(zs), "y": _std(ys), "err": p.error_deg, "type": p.gesture_type, "spin": p.lateral_spin, "bend": bend}
	var s1: Dictionary = spread.call({}, 0.0, 0.8)
	var acc: Dictionary = spread.call({"accuracy": MAX}, 0.0, 0.8)
	var hgt: Dictionary = spread.call({"height": MAX}, 0.0, 0.8)
	var tec: Dictionary = spread.call({"technique": MAX}, 0.0, 0.6)
	var tec0: Dictionary = spread.call({}, 0.0, 0.6)
	var cur0: Dictionary = spread.call({}, 0.2, 0.9)
	var cur: Dictionary = spread.call({"curve": MAX}, 0.2, 0.9)
	note("desvio en el arco (m, desviacion tipica lateral / vertical): base %.2f/%.2f · precision 10 %.2f/%.2f · altura 10 %.2f/%.2f" % [
		s1["z"], s1["y"], acc["z"], acc["y"], hgt["z"], hgt["y"]])
	note("trazo irregular: base %.2f° · tecnica 10 %.2f° · efecto: base %.1f rad/s (curva %.2f m) · efecto 10 %.1f rad/s (curva %.2f m)" % [
		tec0["err"], tec["err"], cur0["spin"], cur0["bend"], cur["spin"], cur["bend"]])
	check(acc["z"] < s1["z"] * 0.85 and acc["z"] > s1["z"] * 0.6, "precision 10: el desvio lateral baja (sin desaparecer)")
	check(hgt["y"] < s1["y"] * 0.8 and absf(hgt["z"] - s1["z"]) < s1["z"] * 0.05, "altura 10: baja el desvio vertical y no el lateral")
	check(tec["err"] < tec0["err"], "tecnica 10: el trazo irregular se desvia menos")
	check(absf(cur["spin"]) > absf(cur0["spin"]) and cur["bend"] > cur0["bend"], "efecto 10: el mismo trazo curvo da mas efecto y curva mas")
	cleanup()

## Arquero: el alcance amplia la estirada poco (6 %) y nunca hasta el angulo; la atrapada sube la velocidad que atrapa.
func test_keeper_attributes_never_allow_impossible_saves() -> void:
	var top: Dictionary = _attrs(MAX, ProgressionRules.KEEPER)
	var near_post := Vector3(0.0, 0.5, 3.6)
	check(not KeeperReach.reachable(near_post, 0.0, 1.0, AttributeEffects.keeper_reach_scale({}), AttributeEffects.keeper_react_bias({}))
		and KeeperReach.reachable(near_post, 0.0, 1.0, AttributeEffects.keeper_reach_scale(top), AttributeEffects.keeper_react_bias(top)),
		"a 3,6 m: sin atributos no llega, con alcance 10 si")
	var bad: int = 0
	for y in [2.0, 2.2, 2.35]:
		for z in [3.3, 3.45, 3.6]:
			if KeeperReach.reachable(Vector3(0, y, z), 0.0, 3.0, AttributeEffects.keeper_reach_scale(top), AttributeEffects.keeper_react_bias(top)):
				bad += 1
	check(bad == 0, "ni al maximo llega al angulo (arriba y pegado al palo)")
	# Con 0,45 s (tiro rapido) el alcance todavia esta creciendo: ahi cuenta arrancar antes (por debajo de ~0,39 s ya
	# esta en el minimo F_MIN para cualquiera, y por encima de 0,65 s estirado del todo).
	var fast_ok: bool = KeeperReach.reachable(Vector3(0, 0.6, 2.22), 0.0, 0.45, 1.0, AttributeEffects.keeper_react_bias(top))
	var fast_no: bool = KeeperReach.reachable(Vector3(0, 0.6, 2.22), 0.0, 0.45, 1.0, 0.0)
	check(fast_ok and not fast_no, "reflejos 10: llega a un tiro rapido a media distancia que sin reflejos no alcanza")
	var k := SpKeeper.new()
	AttributeEffects.apply_keeper(k, top)
	check(is_equal_approx(k.catch_scale, 1.15) and is_equal_approx(k.reach_scale, 1.06), "el arquero del usuario recibe sus atributos")
	k.free()
	# En la partida: el arquero del usuario los tiene; en el duelo local, nadie.
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	SetPieceGame.next_vs = SetPieceGame.Vs.CPU
	var g: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	g.fast = true
	g.user_attrs = top
	spawn(g)
	await physics_frames(5)
	check(is_equal_approx(g.user_keeper.reach_scale, 1.06) and g.cpu_keeper.reach_scale == 1.0, "contra la CPU: solo el arquero del usuario")
	cleanup()
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	SetPieceGame.next_vs = SetPieceGame.Vs.LOCAL
	g = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	g.fast = true
	g.user_attrs = top
	spawn(g)
	await physics_frames(5)
	check(g.user_keeper.reach_scale == 1.0 and g._user_tuning() == GestureTuning.current(), "duelo local (dos personas): atributos neutros")
	cleanup()

# --- Balance: simulaciones ------------------------------------------------------------------------------------------

## Tanda de penales simulada (Monte Carlo) con el modelo del juego: el tirador apunta a un punto del arco (mas a los
## costados), con potencia y prolijidad variables; el error sale de los coeficientes del gesto con sus atributos; el
## arquero de la CPU elige sector (lee bien el tiro un 30 %) y ataja si es su sector y lo alcanza (KeeperReach).
func _penalty_rate(attrs: Dictionary, n: int, seed_v: int, keeper_attrs: Dictionary = {}, cpu_error: float = -1.0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var t: GestureTuning = AttributeEffects.tuning_for(GestureTuning.new(), attrs)
	var sr: Vector2 = AttributeEffects.speed_range(SetPieceGame.PEN_SPEED, attrs)
	var goals: int = 0
	var saves: int = 0
	var outside: int = 0
	var dist: float = 11.0
	for i in n:
		var z: float = rng.randf_range(1.2, 3.4) * (1.0 if rng.randf() < 0.5 else -1.0) if rng.randf() < 0.75 else rng.randf_range(-1.2, 1.2)
		var y: float = rng.randf_range(0.2, 2.2)
		var pw: float = rng.randf_range(0.45, 1.0)
		var smooth: float = rng.randf_range(0.6, 1.0)
		var lf: float = clampf(rng.randf_range(0.18, 0.5) / t.length_full, 0.0, 1.0)
		var err: float = cpu_error if cpu_error >= 0.0 else t.error_base + t.error_power * pw * pw + t.error_rough * (1.0 - smooth) + t.error_short * (1.0 - lf)
		var speed: float = lerpf(sr.x, sr.y, pw)
		var cz: float = z + dist * tan(deg_to_rad(rng.randfn(0.0, err)))
		var cy: float = y + dist * tan(deg_to_rad(rng.randfn(0.0, err * AttributeEffects.pitch_ratio(attrs))))
		var p := Vector3(0.0, cy, cz)
		if absf(cz) > 3.66 - 0.11 or cy > 2.44 - 0.11 or cy < 0.0:
			outside += 1
			continue
		var zone: int = KeeperZones.zone_of(p, 3.66, 2.44)
		var pick: int = zone if rng.randf() < 0.3 else rng.randi_range(0, KeeperZones.COUNT - 1)
		var flight: float = dist / (speed * 0.97)
		if pick == zone and KeeperReach.reachable(p, 0.0, flight + SpKeeper.PENALTY_ANTICIPATION,
				AttributeEffects.keeper_reach_scale(keeper_attrs), AttributeEffects.keeper_react_bias(keeper_attrs)):
			saves += 1
		else:
			goals += 1
	return {"goal": float(goals) / n, "save": float(saves) / n, "out": float(outside) / n}

func _std(a: Array) -> float:
	if a.size() < 2:
		return 0.0
	var m: float = 0.0
	for x in a:
		m += float(x)
	m /= a.size()
	var s: float = 0.0
	for x in a:
		s += (float(x) - m) * (float(x) - m)
	return sqrt(s / (a.size() - 1))

func test_balance_new_players_can_compete() -> void:
	var profiles := [["nuevo (todo 1)", {}],
		["intermedio (nivel 12: 22 puntos parejos)", {"power": 4, "accuracy": 5, "curve": 4, "height": 4, "technique": 4, "control": 4}],
		["especialista en precision (nivel 30)", {"accuracy": 10, "power": 8, "height": 8, "control": 5}],
		["todo al maximo (imposible con los puntos)", _attrs(MAX, ProgressionRules.SHOOTER)]]
	var rates: Array = []
	for pf in profiles:
		var r: Dictionary = _penalty_rate(pf[1], 6000, 11)
		rates.append(r)
		note("%s: gol %.1f %% · atajado %.1f %% · afuera %.1f %%" % [pf[0], 100.0 * r["goal"], 100.0 * r["save"], 100.0 * r["out"]])
	var new_rate: float = rates[0]["goal"]
	var max_rate: float = rates[3]["goal"]
	check(max_rate < 0.9, "ni con todo al maximo el gol es seguro (%.0f %%)" % (100.0 * max_rate))
	check(max_rate - new_rate <= 0.12, "la diferencia nuevo / maximo es acotada (%.1f puntos)" % (100.0 * (max_rate - new_rate)))
	check(new_rate >= max_rate * 0.8, "un jugador nuevo convierte al menos el 80 % de lo que convierte uno al maximo")
	check(rates[1]["goal"] >= new_rate and rates[2]["goal"] >= rates[1]["goal"] - 0.01, "mejorar sirve (la progresion se nota)")
	# La habilidad manual pesa mas que los atributos: apuntar mal con todo al maximo sigue siendo peor que apuntar bien
	# sin atributos.
	var sloppy_max: Dictionary = _penalty_rate(_attrs(MAX, ProgressionRules.SHOOTER), 4000, 5, {}, 3.5)
	var clean_new: Dictionary = _penalty_rate({}, 4000, 5, {}, 0.6)
	note("trazo descuidado con todo al maximo: gol %.1f %% · trazo prolijo sin atributos: %.1f %%" % [100.0 * sloppy_max["goal"], 100.0 * clean_new["goal"]])
	check(clean_new["goal"] > sloppy_max["goal"], "el gesto manda: prolijo sin atributos > descuidado con todo al maximo")
	# Arquero: con alcance y reflejos al maximo ataja algo mas, nunca mucho mas.
	var k0: Dictionary = _penalty_rate({}, 6000, 21, {})
	var k10: Dictionary = _penalty_rate({}, 6000, 21, _attrs(MAX, ProgressionRules.KEEPER))
	note("arquero del usuario contra los mismos tiros: atajadas %.1f %% (todo 1) · %.1f %% (todo 10)" % [100.0 * k0["save"], 100.0 * k10["save"]])
	check(k10["save"] >= k0["save"] and k10["save"] - k0["save"] <= 0.06, "el arquero al maximo ataja apenas mas (y sigue dependiendo del sector)")

## Tabla de progresion: XP por dia de tres tipos de jugador con las reglas reales del servidor (topes y repeticion) y
## cuantos dias tardan en llegar a cada nivel.
func test_progression_table() -> void:
	var o: Node = await _online()
	var players := {"casual": [["offline_match", {"won": true, "goals": 3, "saves": 2}], ["offline_match", {"won": false, "goals": 2, "saves": 1}],
			["arcade", {"medal": 1}], ["arcade", {"medal": 2}], ["desafio_diario", {}]],
		"regular": [], "intenso": []}
	for i in 6:
		players["regular"].append(["offline_match", {"won": i % 2 == 0, "goals": 3, "saves": 2}])
		players["regular"].append(["arcade", {"medal": 2}])
	players["regular"].append(["desafio_diario", {}])
	players["regular"].append(["desafio_diario", {}])
	for i in 40:
		players["intenso"].append(["offline_match", {"won": true, "goals": 5, "saves": 5}])
		players["intenso"].append(["arcade", {"medal": 3}])
	var per_day := {}
	var day: int = 0
	for who in ["casual", "regular", "intenso"]:
		day += 1
		o.local.clock_offset = day * 86400.0
		var xp0: int = int(o.profile()["xp"])
		var i: int = 0
		for c in players[who]:
			i += 1
			await o.call_fn("claim_reward", {"p_idem": "tabla-%s-%04d" % [who, i], "p_source": c[0], "p_payload": c[1]})
		await o.refresh_state()
		per_day[who] = int(o.profile()["xp"]) - xp0
	o.local.clock_offset = 0.0
	var lines: PackedStringArray = []
	for who in per_day:
		var cols: PackedStringArray = []
		for lv in [5, 10, 20, 30]:
			var need: int = 150 * (lv - 1) * lv / 2
			cols.append("nivel %d: %d dias" % [lv, ceili(float(need) / maxf(per_day[who], 1.0))])
		lines.append("%s (%d XP por dia sin online): %s" % [who, per_day[who], ", ".join(cols)])
	for l in lines:
		note(l)
	check(per_day["intenso"] <= 1500, "el tope diario frena al que juega todo el dia (%d)" % per_day["intenso"])
	check(ceili(150.0 * 29 * 30 / 2 / per_day["intenso"]) >= 30, "ni jugando todo el dia se llega al tope de puntos en menos de un mes")
	check(ceili(150.0 * 4 * 5 / 2 / per_day["casual"]) <= 10, "un jugador casual llega al nivel 5 en menos de dos semanas")
	await _done(o)

# --- Pantalla MI JUGADOR — PROGRESION -------------------------------------------------------------------------------

func test_progression_screen() -> void:
	var o: Node = await _online()
	await _set_xp(o, 450)
	var screens := MenuScreens.new()
	spawn(screens)
	await physics_frames(2)
	screens.open_progression()
	await physics_frames(3)
	check(screens._title.text == "MI JUGADOR — PROGRESIÓN", "titulo de la seccion")
	var pts: Label = screens._content.find_child("Puntos", true, false)
	check(pts != null and pts.text.contains("4"), "nivel 3: 4 puntos de mejora a la vista")
	check(screens._content.find_child("BarraXP", true, false) != null, "barra de experiencia")
	for k in ProgressionRules.SHOOTER:
		var card: Control = screens._content.find_child("Atributo_" + k, true, false)
		check(card != null and card.find_children("*", "MenuIcon", true, false).size() == 1, "tarjeta con icono: %s" % k)
	var b: Button = screens._content.find_child("Mejorar_power", true, false)
	check(b != null and not b.disabled, "MEJORAR habilitado con puntos")
	b.pressed.emit()
	await physics_frames(2)
	var modal: Control = screens._prog_modal
	check(is_instance_valid(modal) and modal.find_child("Antes", true, false) != null and modal.find_child("Despues", true, false) != null,
		"confirmacion con la comparacion antes / despues")
	var before: Label = (modal.find_child("Antes", true, false) as Control).get_child(1)
	var after: Label = (modal.find_child("Despues", true, false) as Control).get_child(1)
	note("antes: %s · despues: %s" % [before.text, after.text])
	check(before.text != after.text, "muestra cuanto cambia")
	check(int(o.profile()["attributes"].get("power", 1)) == 1, "sin confirmar no se gasta nada")
	await screens.upgrade("power")
	await physics_frames(2)
	check(int(o.profile()["attributes"]["power"]) == 2, "confirmado: potencia 2 (validado por el servidor)")
	for i in 3:
		await screens.upgrade("power")
	await physics_frames(2)
	var b2: Button = screens._content.find_child("Mejorar_accuracy", true, false)
	check(b2 != null and b2.disabled, "sin puntos el boton queda deshabilitado")
	screens._prog_tab = "arquero"
	screens._fill_progression()
	await physics_frames(2)
	check(screens._content.find_child("Atributo_keeper_reach", true, false) != null, "pestaña del arquero")
	screens._prog_tab = "historial"
	screens._fill_progression()
	await physics_frames(2)
	var txt: String = ""
	for l in screens._content.find_children("*", "Label", true, false):
		txt += (l as Label).text + "\n"
	check(txt.contains("Potencia 1 → 2"), "historial de mejoras en pantalla")
	screens._prog_tab = "tirador"
	screens.close()
	await _done(o)
	PlayerCustom.restore_after_tests()
	cleanup()
