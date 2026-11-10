extends TestCase
## Arqueros por turnos (etapa A4): la variante «rafaga» juega bloques de 5 tiros seguidos por lado (con muerte subita
## alternada si empatan) y «contra reloj» pone al usuario a atajar una serie de la IA con puntaje, record y medalla.
## La tanda clasica no cambia (sus reglas ya se prueban en test_setpiece_modes).

func test_rafaga_blocks_then_sudden_death() -> void:
	var s := PenaltyShootout.new()
	s.block_size = 5
	var order: Array = []
	for g in [true, true, true, false, true, true, false, true, false, false]:
		order.append(s.next_team())
		s.record(s.next_team(), g)
	check(str(order) == str([0, 0, 0, 0, 0, 1, 1, 1, 1, 1]), "primero los 5 del usuario, despues los 5 de la IA (%s)" % str(order))
	# 4-3: el usuario gana al cerrar los bloques.
	check(s.finished() and s.winner() == PenaltyShootout.USER, "4-3 al final de los bloques: gana el usuario")
	# Empate 5-5: muerte subita alternada.
	s.reset()
	for i in 10:
		s.record(s.next_team(), true)
	check(not s.finished() and s.in_sudden_death(), "5-5: muerte subita")
	check(s.next_team() == PenaltyShootout.USER, "en muerte subita vuelve a alternar")
	s.record(PenaltyShootout.USER, true)
	check(s.next_team() == PenaltyShootout.CPU, "y la IA responde")
	s.record(PenaltyShootout.CPU, false)
	check(s.finished() and s.winner() == PenaltyShootout.USER, "el que convierte gana")
	# Corte temprano dentro del bloque de la IA: usuario 5/5, la IA erra 5 (no alcanza antes).
	s.reset()
	for i in 5:
		s.record(PenaltyShootout.USER, true)
	for i in 5:
		if s.finished():
			break
		s.record(PenaltyShootout.CPU, false)
	check(s.finished() and s.winner() == PenaltyShootout.USER and s.kicks(PenaltyShootout.CPU) == 1,
		"si la IA ya no alcanza, el bloque se corta (%d tiros de la IA)" % s.kicks(PenaltyShootout.CPU))

func test_reloj_only_keeps_and_records_score() -> void:
	PlayerProgress.use_path("user://test_duel_prog.cfg")
	Achievements.muted = true
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	SetPieceGame.next_shootout = {"id": "reloj", "shots": 3}
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	check(not game.user_shooting and game.phase == SetPieceGame.Phase.KEEPER_PICK, "el usuario arranca atajando")
	var n: int = 0
	while game.phase != SetPieceGame.Phase.OVER and n < 60 * 90:
		if game.phase == SetPieceGame.Phase.KEEPER_PICK:
			game._keeper_zone = Vector3(game.gx, 1.0, [2.5, -2.5, 0.0][game.shootout.kicks(1) % 3])
		await tree.physics_frame
		n += 1
	var saves: int = game.shootout.kicks(1) - game.shootout.goals(1)
	note("contra reloj: la IA pateo %d, el usuario atajo %d; %.1f s simulados" % [game.shootout.kicks(1), saves, n / 60.0])
	check(game.shootout.kicks(1) == 3 and game.shootout.kicks(0) == 0, "la IA patea la serie completa y el usuario nunca patea")
	check(game.phase == SetPieceGame.Phase.OVER, "la serie termina con el resumen")
	PlayerProgress.load_progress()
	check(PlayerProgress.records.has("arqueros_reloj"), "el resultado queda en el record (%s)" % str(PlayerProgress.records.get("arqueros_reloj", {})))
	Achievements.muted = false
	cleanup()
