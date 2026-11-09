extends TestCase
## Ciclo de vida de la jugada sin estados bloqueados: ningun jugador queda congelado en la ultima pose de un clip,
## trotando en el sitio despues de llegar, ni repitiendo una reaccion; todo resultado tiene salida y la jugada siguiente
## se prepara sola (penal) o queda lista para el usuario (tiro libre).

## Jugadores trabados ahora: congelados (clip de una vez terminado sin bucle) o con un bucle de marcha sin moverse.
static func stuck_actors(game: SetPieceGame) -> Array:
	var out: Array = []
	var locomotion: Array = []
	for r in [&"jog", &"loco_jog", &"walk", &"run", &"sprint", &"loco_sprint", &"gk_sidestep", &"sidestep"]:
		locomotion.append_array(SpClips.by_role(r, false))
	for n in game.get_children():
		if not (n is SpActor) or not (n as SpActor).visible:
			continue
		var a: SpActor = n
		if a.global_position.y < -10.0:
			continue
		if a.clip_done() and not a.freeze_on_finish:
			out.append("%s congelado en %s" % [a.name, a.clip_id])
		elif a.looping and locomotion.has(a.clip_id) and not a.is_moving() and a.clip_id != &"jn_gk_sidestep_0184":
			out.append("%s trotando en el sitio (%s)" % [a.name, a.clip_id])
	return out

func test_actors_go_back_to_rest() -> void:
	var a := SpActor.new()
	spawn(a)
	a.build(SpSettings.USER_KIT)
	await physics_frames(2)
	var jog: StringName = SpShooter._loop_for(4.0)
	a.move_to(a.global_position + Vector3(2.0, 0, 0), 4.0, jog)
	await physics_frames(60)
	check(not a.is_moving() and a.clip_id == a.rest_loop, "al llegar deja de trotar y vuelve al reposo (%s)" % a.clip_id)
	a.move_to(a.global_position + Vector3(20.0, 0, 0), 4.0, jog)
	await physics_frames(10)
	a.stop_moving()
	check(a.clip_id == a.rest_loop, "si lo frenan corriendo vuelve al reposo")
	var react: StringName = SpReactions.pick(SpReactions.HAPPY_DEFENDER, null, 1.5, 0.5)
	a.play_here(react, 0.1)
	var n: int = 0
	while not a.looping and n < 400:
		await tree.physics_frame
		n += 1
	check(a.looping and a.clip_id == a.rest_loop, "despues del festejo vuelve solo al reposo (%.1f s)" % (n / 60.0))
	a.freeze_on_finish = true
	a.play_here(react, 0.1)
	await physics_frames(int(SpClips.length(react) * 60.0) + 20)
	check(not a.looping, "con la pose congelada pedida (arquero con la pelota) no vuelve al reposo")
	cleanup()

## Jugadas reales de penal y tiro libre (con distintos destinos): despues del resultado nadie queda trabado y la jugada
## siguiente llega (o queda lista).
func test_no_one_gets_stuck_after_any_result() -> void:
	var problems: Array = []
	var shots := [[SetPieceGame.Mode.PENALTY, Vector3(0, 0.6, 2.9), 0.8], [SetPieceGame.Mode.PENALTY, Vector3(0, 1.0, 0.2), 0.5],
		[SetPieceGame.Mode.PENALTY, Vector3(0, 3.2, 0.0), 0.9], [SetPieceGame.Mode.FREE_KICK, Vector3(0, 1.0, 0.0), 0.9],
		[SetPieceGame.Mode.FREE_KICK, Vector3(0, 2.0, -3.0), 0.8], [SetPieceGame.Mode.FREE_KICK, Vector3(0, 0.5, 6.0), 0.7]]
	for c in shots:
		SetPieceGame.next_mode = c[0]
		var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
		spawn(game)
		await physics_frames(10)
		if c[0] == SetPieceGame.Mode.FREE_KICK:
			game.ball_spot = game.clamp_free_kick_spot(Vector3(game.gx - 22.0, 0, 0))
			game._setup_free_kick()
			await physics_frames(10)
		game.shoot(Vector3(game.gx, 0, 0) + c[1], c[2], 0.0)
		var n: int = 0
		var outcome: String = ""
		var result_frames: int = 0
		while n < 60 * 14:
			await tree.physics_frame
			n += 1
			if game.phase == SetPieceGame.Phase.RESULT:
				outcome = game.outcome
				result_frames += 1
			if result_frames > 0 and game.phase in [SetPieceGame.Phase.OVER, SetPieceGame.Phase.KEEPER_PICK, SetPieceGame.Phase.AIM]:
				break
		# Despues de que termina la jugada se espera a que terminen los festejos.
		await physics_frames(60 * 5)
		var stuck: Array = stuck_actors(game)
		note("%s a %s: resultado %s, siguiente fase %s, trabados: %s" % ["penal" if c[0] == SetPieceGame.Mode.PENALTY else "tiro libre",
			str(c[1]), outcome, SetPieceGame.Phase.keys()[game.phase], str(stuck)])
		check(outcome != "", "hay resultado")
		check(game.phase in [SetPieceGame.Phase.OVER, SetPieceGame.Phase.KEEPER_PICK, SetPieceGame.Phase.AIM], "la jugada termina y la siguiente queda lista")
		problems.append_array(stuck)
		cleanup()
	check(problems.is_empty(), "nadie queda congelado ni trotando en el sitio (%s)" % str(problems))
