extends TestCase
## «Diana gigante» (pedido del usuario, 2026-11-12): reemplaza al Curling en el arcade. Una diana enorme pintada en el piso;
## la pelota se patea por el AIRE y suma el anillo donde PICA por primera vez (no rueda por el hielo). El Curling queda en
## el codigo pero oculto en el arcade.

func _game(level: int) -> Dianas:
	var d: Dictionary = MinigameCatalog.level("diana_gigante", level)
	d["seed"] = 5
	d["practice"] = true
	Minigame.next_def = d
	var g: Dianas = (load(String(d["scene"])) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(10)
	return g

func _fly(g: Minigame) -> void:
	var n: int = 0
	while g.state == Minigame.State.FLIGHT and n < 60 * 14:
		await tree.physics_frame
		n += 1
	if g.state == Minigame.State.RESOLVE:
		g._after_resolve()
		await physics_frames(2)

func test_replaces_curling_in_the_arcade() -> void:
	var listed: Array = []
	for c in MinigameCatalog.categories():
		for it in c.get("items", []):
			listed.append(String(it.get("game", "")))
	check(listed.has("diana_gigante"), "la Diana gigante esta en el arcade")
	check(not listed.has("curling"), "el Curling (pista de hielo) ya no esta en el arcade")
	check(bool(MinigameCatalog.game("curling").get("hidden", false)), "el Curling queda oculto (su codigo no se borro)")
	var lv: Array = MinigameCatalog.levels("diana_gigante")
	check(lv.size() == 5, "5 niveles (%d)" % lv.size())
	for d in lv:
		check((d as Dictionary).has("floor"), "%s: diana en el piso" % d["title"])

## Un tiro por el aire que pica en el centro suma 100; uno que pica en el anillo de afuera, 25. Cada nivel arma su diana.
func test_an_aerial_shot_scores_the_ring_where_it_bounces() -> void:
	for level in range(1, MinigameCatalog.levels("diana_gigante").size() + 1):
		var g: Dianas = await _game(level)
		check(not g.floor_t.is_empty() and g.floor_radius() > 3.0, "nivel %d: diana en el piso armada (radio %.1f m)" % [level, g.floor_radius()])
		cleanup()
	var g0: Dianas = await _game(1)
	var spot: Vector3 = g0._ball_spot(0)
	var c: Vector3 = g0.floor_center()
	var r: float = g0.floor_radius()
	cleanup()
	var results: Array = []
	for target in [c, c + Vector3(-r * 0.85, 0, 0)]:
		# Calibra la velocidad (28 grados) para picar en el punto pedido (un juego nuevo por intento, como las Dianas) y
		# mide lo que suma ese tiro.
		var dir := Vector3(target.x - spot.x, 0, target.z - spot.z).normalized()
		var want: float = Vector2(target.x - spot.x, target.z - spot.z).length()
		var a: float = deg_to_rad(28.0)
		var sp: float = 17.0
		var got_pts: int = 0
		var first := Vector3.INF
		for k in 7:
			var g: Dianas = await _game(1)
			var bounces: Array = []
			g.ball.floor_bounce.connect(func(q: Vector3, _s: float) -> void: bounces.append(q))
			var before: int = g.zone_points
			await g.launch(dir * cos(a) * sp + Vector3.UP * sin(a) * sp, Vector3.ZERO)
			await _fly(g)
			got_pts = g.zone_points - before
			cleanup()
			first = Vector3.INF
			for q in bounces:
				if (q as Vector3).x > spot.x + 3.0:
					first = q
					break
			if first == Vector3.INF:
				break
			var got: float = Vector2(first.x - spot.x, first.z - spot.z).length()
			if absf(got - want) < 0.4:
				break
			sp *= sqrt(want / got)
		var dist: float = Vector2(first.x - c.x, first.z - c.z).length() / r if first != Vector3.INF else INF
		var expect: int = 0
		for rg in Dianas.FLOOR_RINGS:
			if dist <= float(rg[0]):
				expect = int(rg[1])
				break
		results.append("pica a %.1f m del centro: +%d (esperado %d)" % [dist * r, got_pts, expect])
		check(first != Vector3.INF and first.y < 1.0, "la pelota va por el aire y pica en el piso")
		check(got_pts == expect and expect > 0, "suma el anillo del primer pique (+%d, esperado %d)" % [got_pts, expect])
	note(", ".join(results))
	check(results.size() == 2, "dos tiros medidos")
