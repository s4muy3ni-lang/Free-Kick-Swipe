extends TestCase
## MEDICION (no es una prueba de la suite): balance del arquero del tiro libre en 16 tiros fijos (direcciones, alturas,
## potencias, con efecto, colocados, potentes y por encima de la barrera) con semillas fijas, para uno o varios radios de
## plan. Solo corre si se pide (tarda ~5 min con render):
##   xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn \
##     -- --filter test_fk_balance_measure medir scales=1.0,0.6
## Resultados y decision en docs/AAA_ROADMAP.md (segunda entrega).
const SHOTS := [
	[Vector3(-22, 0, 0), 1.9, -2.9, 0.75, -0.12], [Vector3(-22, 0, 0), 1.9, 2.9, 0.75, 0.12], [Vector3(-22, 0, 0), 0.4, -3.0, 0.85, 0.0],
	[Vector3(-22, 0, 0), 0.4, 3.0, 0.85, 0.0], [Vector3(-22, 0, 0), 1.2, 0.5, 1.0, 0.0], [Vector3(-22, 0, 0), 0.6, 2.5, 0.5, 0.1],
	[Vector3(-24, 0, -10), 2.0, 2.8, 0.7, 0.14], [Vector3(-24, 0, -10), 1.0, -3.2, 0.9, 0.0], [Vector3(-24, 0, -10), 0.5, 3.0, 0.8, -0.05],
	[Vector3(-24, 0, -10), 1.5, 0.0, 0.95, 0.0], [Vector3(-24, 0, -10), 2.1, -3.0, 0.7, -0.12], [Vector3(-28, 0, 6), 1.8, -3.0, 0.85, -0.14],
	[Vector3(-28, 0, 6), 0.5, 3.1, 1.0, 0.0], [Vector3(-28, 0, 6), 2.0, 2.9, 0.8, 0.1], [Vector3(-28, 0, 6), 1.0, 0.0, 0.6, 0.0],
	[Vector3(-28, 0, 6), 2.2, -1.5, 0.9, -0.08]]

func test_fk_balance() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("medir"):
		skip("medicion a pedido (argumento «medir», con render)")
		return
	var scales: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scales="):
			for x in a.substr(7).split(","):
				scales.append(float(x))
	if scales.is_empty():
		scales = [1.0, 0.6]
	for sc in scales:
		var tally := {}
		var lines: PackedStringArray = []
		for i in SHOTS.size():
			var c: Array = SHOTS[i]
			SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK
			var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
			game.fast = true
			spawn(game)
			await physics_frames(5)
			game.rng.seed = 700 + i
			game.cpu_keeper.rng.seed = 300 + i
			game.wall.rng.seed = 50 + i
			game.field.rng.seed = 90 + i
			game.cpu_keeper.watch_radius_scale = sc
			game.ball_spot = game.clamp_free_kick_spot(Vector3(game.gx, 0, 0) + c[0])
			game._setup_free_kick()
			await physics_frames(10)
			game.shoot(Vector3(game.gx, c[1], c[2]), c[3], c[4])
			var k: SpKeeper = game.cpu_keeper
			var min_hand: float = INF
			var cross_err: float = -1.0
			var n: int = 0
			var dove: bool = false
			var plan_ok: bool = false
			while game.phase in [SetPieceGame.Phase.RUNUP, SetPieceGame.Phase.FLIGHT] and n < 900:
				await tree.physics_frame
				n += 1
				if game.phase != SetPieceGame.Phase.FLIGHT:
					continue
				var bp: Vector3 = game.ball.global_position
				if k.state == SpKeeper.State.DIVE and not dove:
					dove = true
					plan_ok = float(k.plan.get("dist", 9.0)) <= float(k.plan.get("radius", 0.0))
				for h in ["mixamorig_LeftHand", "mixamorig_RightHand"]:
					min_hand = minf(min_hand, k.actor.bone_world(h).distance_to(bp))
				if cross_err < 0.0 and bp.x >= k.actor.global_position.x - 0.2:
					cross_err = absf(bp.z - k.actor.global_position.z)
			var cls: String = String(game.last_shot.get("class", "?"))
			var res: String = game.outcome
			tally[res] = int(tally.get(res, 0)) + 1
			if k.touch_kind != &"":
				tally["toques"] = int(tally.get("toques", 0)) + 1
			if dove:
				tally["estiradas"] = int(tally.get("estiradas", 0)) + 1
			if plan_ok:
				tally["planes que llegan"] = int(tally.get("planes que llegan", 0)) + 1
			if k.cancelled_dives > 0:
				tally["canceladas"] = int(tally.get("canceladas", 0)) + 1
			lines.append("  %2d: clase %s, resultado %s, toque «%s», se tiro %s (plan llega %s, canceladas %d), mano-pelota min %.2f m, desfase lateral %.2f m" % [i + 1, cls, res, k.touch_kind, str(dove), str(plan_ok), k.cancelled_dives, min_hand, cross_err])
			cleanup()
		note("escala %.2f: %s" % [sc, str(tally)])
		for l in lines:
			note(l)
