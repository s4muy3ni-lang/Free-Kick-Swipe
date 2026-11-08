extends TestCase
## Sonido (autoload Sfx): los efectos sintetizados existen y se cargan, el publico esta en bucle, cada golpe a la pelota
## elige su sonido por la fuerza real del impulso y la pelota avisa sus golpes con Ball.impulse. En headless el servidor de
## audio es nulo: se comprueba la eleccion y la carga, no lo que sale por el altavoz.

func test_all_sounds_are_loaded_and_the_crowd_loops() -> void:
	for n in Sfx.SOUNDS:
		check(ResourceLoader.exists("res://assets/audio/%s.wav" % n), "existe assets/audio/%s.wav" % n)
		check(Sfx._streams.has(n), "Sfx cargo %s" % n)
	check(Sfx._crowd != null and (Sfx._crowd.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "el publico suena en bucle")

func test_each_hit_picks_its_sound_by_the_real_impulse() -> void:
	check(Sfx.impulse_sound(false, 0.3, 1.0).is_empty(), "un apoyo de la suela (dv 0.3 m/s) no suena")
	check(Sfx.impulse_sound(false, 2.0, 3.0)[0] == &"touch", "un toque de conduccion suena como toque")
	check(Sfx.impulse_sound(false, 9.0, 10.0)[0] == &"kick_soft", "un pase (10 m/s) suena como golpe suave")
	var hard: Array = Sfx.impulse_sound(false, 25.0, 28.0)
	check(hard[0] == &"kick_hard" and float(hard[1]) > float(Sfx.impulse_sound(false, 15.0, 16.0)[1]), "un tiro fuerte suena fuerte, y mas cuanto mas rapido sale")
	check(Sfx.impulse_sound(true, 10.0, 2.0)[0] == &"glove", "el arquero suena a guantes")

func test_ball_reports_every_kick_with_its_impulse() -> void:
	var ctx: MatchContext = await make_match(Vector3(0.0, 0.11, 0.0))
	var got := []
	ctx.ball.impulse.connect(func(actor: Node, dv: float, speed: float) -> void: got.append([actor, dv, speed]))
	await physics_frames(2)
	ctx.ball.kick(Vector3(20.0, 0.0, 0.0), Vector3.ZERO, null)
	check(got.size() == 1 and absf(float(got[0][2]) - 20.0) < 0.01 and float(got[0][1]) > 19.0, "Ball.kick emite impulse con dv y velocidad de salida (%s)" % str(got))
	cleanup()
