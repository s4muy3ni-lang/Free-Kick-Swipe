extends TestCase
## Medicion de rendimiento por momento (PerfSession) en una jugada real de penal: registra los momentos de la jugada, da
## un informe con tiempos de cuadro y sistemas, y deja Prof como estaba. Los perfiles graficos no cambian la fisica: la
## misma patada termina en el mismo lugar con el perfil mas bajo y el mas alto.

func test_a_penalty_is_measured_by_moment() -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	var prof_before: bool = Prof.enabled
	game._toggle_perf_session()
	check(game.perf_session.recording, "empieza a medir")
	await physics_frames(20)
	game.shoot(Vector3(game.gx, 0.6, 2.6), 0.7, 0.0)
	var n: int = 0
	while game.phase in [SetPieceGame.Phase.RUNUP, SetPieceGame.Phase.FLIGHT, SetPieceGame.Phase.RESULT] and n < 900:
		await tree.physics_frame
		n += 1
	game._toggle_perf_session()
	var s: Dictionary = game.perf_session.summary()
	note("momentos medidos: %s" % str(s.keys()))
	for m in ["apuntando", "carrera"]:
		check(s.has(m), "se midio «%s»" % m)
	# Con la pelota en el aire: «vuelo», o «estirada» mientras el arquero se tira (toda la llegada si se tiro al golpe).
	check(s.has("vuelo") or s.has("estirada"), "se midio la pelota en el aire (vuelo o estirada)")
	var any_sys: bool = false
	for m in s.keys():
		if not (s[m]["systems"] as Dictionary).is_empty():
			any_sys = true
	check(any_sys, "el informe trae el costo de los sistemas (Prof)")
	var rep: String = game.perf_session.report()
	check(rep.contains("AnimationPlayer") and rep.contains("[carrera]"), "el informe es texto legible con los momentos")
	note(rep.split("\n")[2])
	check(game.perf_session.count_animation_players() >= 4, "cuenta los AnimationPlayer de la escena (%d)" % game.perf_session.count_animation_players())
	check(Prof.enabled == prof_before, "al terminar deja Prof como estaba")
	cleanup()

func test_graphics_profiles_do_not_change_the_physics() -> void:
	var ends: Array = []
	var saved: int = GraphicsSettings.profile
	for prof in [GraphicsSettings.Profile.VERY_LOW, GraphicsSettings.Profile.HIGH]:
		GraphicsSettings.profile = prof
		GraphicsSettings.apply()
		var st := Stadium11.new()
		spawn(st)
		st.build(PitchConfig.football11(PitchConfig.GoalStyle.BOX))
		var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
		spawn(ball)
		st.set_ball(ball)
		ball.reset_at(Vector3(30.0, ball.radius, 1.0))
		await physics_frames(4)
		ball.kick(Vector3(20.0, 4.0, 1.5), Vector3(0, 12.0, -20.0), null)
		await physics_frames(150)
		ends.append(ball.global_position)
		cleanup()
	GraphicsSettings.profile = saved
	GraphicsSettings.apply()
	note("perfil muy bajo: %s · alto: %s" % [str(ends[0]), str(ends[1])])
	check((ends[0] as Vector3).distance_to(ends[1]) < 0.001, "la misma patada termina en el mismo lugar con cualquier perfil")
