extends TestCase
## Camara de los minijuegos (etapa D, pedido del usuario: «que se vean todos los elementos de cada minijuego; no me sirve
## un jugador alto que la camara no enfoca»). En CADA nivel de CADA minijuego, al empezar el turno del usuario y con la
## camara ya asentada: la pelota, el jugador (pies y cabeza), el objetivo y los puntos propios del juego (rival, boton,
## bolos, aros, placas, zona...) se proyectan DENTRO de la pantalla, y la camara sigue en tercera persona (detras de la
## pelota y por encima, no una vista lateral).

const VIEW := Vector2(1600, 720)

func test_every_level_frames_everything() -> void:
	tree.root.size = Vector2i(int(VIEW.x), int(VIEW.y))
	var worst: float = 0.0
	var fails: Array = []
	var levels: int = 0
	for g in MinigameCatalog.games():
		for d in MinigameCatalog.levels(String(g["id"])):
			var dd: Dictionary = (d as Dictionary).duplicate(true)
			dd["seed"] = 3
			dd["practice"] = true
			Minigame.next_def = dd
			var game: Minigame = (load(String(dd["scene"])) as PackedScene).instantiate()
			game.fast = true
			spawn(game)
			await physics_frames(5)
			game.start_match()
			# Turno del usuario y camara asentada (las transiciones son amortiguadas).
			game._frame_camera(true)
			await physics_frames(3)
			var pts: Array = [game._ball_spot(game.side), game._aim_point(game.side), game.stance_point(game.side),
				game.stance_point(game.side) + Vector3.UP * 1.9]
			pts.append_array(game.frame_points())
			var outside: int = 0
			for p in pts:
				var v: Vector3 = p
				if game.cam.is_position_behind(v):
					outside += 1
					continue
				var s: Vector2 = game.cam.unproject_position(v)
				var r: Vector2 = game.get_viewport().get_visible_rect().size
				var m: float = maxf(absf(s.x / r.x - 0.5), absf(s.y / r.y - 0.5)) * 2.0
				worst = maxf(worst, m)
				if m > 1.0:
					outside += 1
			levels += 1
			# Tercera persona: la camara esta detras de la pelota respecto del objetivo y por encima de ella.
			var to_aim: Vector3 = (game._aim_point(game.side) - game._ball_spot(game.side)) * Vector3(1, 0, 1)
			var cam_rel: Vector3 = (game.cam.global_position - game._ball_spot(game.side)) * Vector3(1, 0, 1)
			var third: bool = cam_rel.dot(to_aim) < 0.0 and game.cam.global_position.y > game._ball_spot(game.side).y + 2.0
			if outside > 0 or not third:
				fails.append("%s/%s: %d fuera%s" % [g["id"], dd["title"], outside, "" if third else ", no es tercera persona"])
			cleanup()
	note("%d niveles revisados; punto mas cerca del borde: %.0f %% de la mitad de la pantalla" % [levels, worst * 100.0])
	check(fails.is_empty(), "en todos los niveles se ve todo (%s)" % str(fails))
