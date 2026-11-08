extends TestCase
## Verificacion EN MOVIMIENTO: el futbolista corre con el AnimationTree activo y se mide el esqueleto realmente
## animado (posicion mundial de los tobillos). Mide el deslizamiento del pie de apoyo: mientras un pie esta apoyado
## su velocidad horizontal en el mundo deberia ser ~0. Necesita renderizado (xvfb-run --rendering-driver opengl3);
## en headless el esqueleto no se actualiza y la prueba se OMITE.

const SPEEDS := [["caminata", 0.3, false], ["paso vivo", 0.45, false], ["trote", 0.55, false], ["trote alto", 0.7, false], ["carrera", 1.0, false], ["sprint", 1.0, true]]

func _needs_render() -> bool:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return true
	return false

func _slide(use_pack: bool, stick: float, sprint: bool) -> Dictionary:
	FootballerVisual.prefer_pack = use_pack
	var ctx: MatchContext = await make_match(Vector3(30.0, 0.11, 5.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-18, 0, 0), 50, src, true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(5)
	src.move = Vector2(stick, 0)
	src.sprint = sprint
	await wait_seconds(2.2)    # alcanzar la velocidad de regimen
	var sk: Skeleton3D = p.visual.skeleton
	var feet: Array[int] = [sk.find_bone("mixamorig_LeftToeBase"), sk.find_bone("mixamorig_RightToeBase")]
	var series: Array = [[], []]
	var vsum := 0.0
	var n := 0
	for i in int(3.0 * 60.0):
		await tree.process_frame
		for f in 2:
			series[f].append(sk.global_transform * sk.get_bone_global_pose(feet[f]).origin)
		vsum += p.locomotion.speed
		n += 1
	# Suelo = punto mas bajo de las puntas en la ventana; apoyado = a menos de 2 cm de el.
	var floor_y: float = 1e9
	for f in 2:
		for w in series[f]:
			floor_y = minf(floor_y, (w as Vector3).y)
	var speeds: Array[float] = []
	for f in 2:
		for i in range(1, series[f].size()):
			var a1: Vector3 = series[f][i - 1]
			var b1: Vector3 = series[f][i]
			if a1.y < floor_y + 0.02 and b1.y < floor_y + 0.02:
				speeds.append(Vector2(b1.x - a1.x, b1.z - a1.z).length() * 60.0)
	speeds.sort()
	var mean := 0.0
	for s in speeds:
		mean += s
	mean /= maxf(speeds.size(), 1)
	var res := {"speed": vsum / maxf(n, 1), "planted_frames": speeds.size(), "mean": mean, "p90": speeds[int(speeds.size() * 0.9)] if speeds.size() > 0 else 0.0}
	FootballerVisual.prefer_pack = true
	return res

func test_planted_foot_slide_pack_vs_tripo() -> void:
	if _needs_render():
		return
	PackLibrary.reload()
	for cfg in SPEEDS:
		var tr: Dictionary = await _slide(false, cfg[1], cfg[2])
		note("%-8s v=%.2f m/s | Tripo: pie de apoyo desliza media %.2f m/s (p90 %.2f, %d fotogramas)" % [cfg[0], tr["speed"], tr["mean"], tr["p90"], tr["planted_frames"]])
		check(tr["planted_frames"] >= 8, "%s (Tripo): hay fotogramas con el pie apoyado" % cfg[0])
		if PackLibrary.available():
			var pk: Dictionary = await _slide(true, cfg[1], cfg[2])
			note("%-8s v=%.2f m/s | pack : pie de apoyo desliza media %.2f m/s (p90 %.2f, %d fotogramas)" % [cfg[0], pk["speed"], pk["mean"], pk["p90"], pk["planted_frames"]])
			check(pk["planted_frames"] >= 8, "%s (pack): hay fotogramas con el pie apoyado" % cfg[0])
			check(pk["mean"] < 1.0, "%s (pack): el deslizamiento medio del pie de apoyo es pequeno (%.2f m/s)" % [cfg[0], pk["mean"]])
			if pk["speed"] > 5.0:
				check(pk["mean"] < 0.5 * tr["mean"], "%s: a alta velocidad el pack desliza menos de la mitad que Tripo (%.2f vs %.2f m/s)" % [cfg[0], pk["mean"], tr["mean"]])

## La punta del pie del esqueleto REALMENTE animado pasa por la pelota en el instante del impulso. El modelo de contacto
## del juego usa los metadatos del clip (deterministas, iguales en headless); aqui se contrasta con el esqueleto vivo.
func test_live_foot_passes_through_the_ball_at_the_impulse() -> void:
	if _needs_render():
		return
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe la libreria del pack")
		return
	var yaw: float = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	for kind in [&"pass", &"shot"]:
		var ctx: MatchContext = await make_match(Vector3(0.0, 0.11, 0.0))
		var src := ScriptedInput.new()
		var p: Footballer = add_player(ctx, 0, Vector3(-10.0, 0.0, 0.0), 50, src, true)
		p.locomotion.yaw = yaw
		await physics_frames(10)
		# Pelota a 0.45 m delante y centrada: el planificador elige pierna y tiempo; el ajuste de zancada hace el resto.
		ctx.ball.reset_at(Vector3(-9.55, 0.11, 0.0))
		await physics_frames(10)
		var ev := {"frame": -1, "ball": Vector3.ZERO}   # las lambdas capturan por valor: se usa un diccionario
		ctx.event_emitted.connect(func(e: GameEvent) -> void:
			if e.type == GameEvent.Type.PASS or e.type == GameEvent.Type.SHOT:
				ev["frame"] = Engine.get_physics_frames()
				ev["ball"] = ctx.ball.global_position)
		var sk: Skeleton3D = p.visual.skeleton
		var feet: Array[int] = [sk.find_bone("mixamorig_LeftToeBase"), sk.find_bone("mixamorig_RightToeBase")]
		if kind == &"pass":
			src.hold_pass()
		else:
			src.hold_shoot()
		await physics_frames(2)
		if kind == &"pass":
			src.release_pass()
		else:
			src.release_shoot()
		var frames: Array[int] = []
		var toes: Array = [[], []]
		for i in 90:
			await tree.physics_frame
			frames.append(Engine.get_physics_frames())
			for f in 2:
				toes[f].append(sk.global_transform * sk.get_bone_global_pose(feet[f]).origin)
		var event_frame: int = ev["frame"]
		var event_ball: Vector3 = ev["ball"]
		check(event_frame > 0, "%s: hubo impulso" % kind)
		if event_frame < 0:
			cleanup()
			continue
		var best := 1e9
		var best_off := 0
		for i in frames.size():
			if absi(frames[i] - event_frame) <= 3:
				for f in 2:
					var d: float = (toes[f][i] as Vector3).distance_to(event_ball)
					if d < best:
						best = d
						best_off = frames[i] - event_frame
		note("%s: la punta del pie animada pasa a %.3f m del centro de la pelota (fotograma %+d respecto al impulso); radio de contacto %.2f m" % [kind, best, best_off, Tuning.player.kick_contact_radius])
		check(best <= Tuning.player.kick_contact_radius, "%s: el pie vivo pasa por la pelota en el impulso (%.3f m <= %.2f m)" % [kind, best, Tuning.player.kick_contact_radius])
		cleanup()
