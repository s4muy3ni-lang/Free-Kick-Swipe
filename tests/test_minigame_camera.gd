extends TestCase
## Camara de los minijuegos (pedido del usuario: volver a la configuracion ANTERIOR al cambio que la alejo y agregar
## ajustes por minijuego). Comprueba:
##  - los valores recomendados son los recuperados de Git (05c100e): 10,5 / 5,4 / 5,5 / 44 grados en general y 6 / 6,5 /
##    6 / 50 grados en Boton de caida;
##  - con la camara recomendada se ve la pelota en todos los niveles (el jugador y lo propio de cada juego se informan);
##  - los ajustes se guardan POR minijuego (cambiar uno no toca a otro) y «Restablecer» vuelve al recomendado;
##  - con el panel de camara abierto el trazo no patea (no interfiere con el apuntado).

const VIEW := Vector2(1600, 720)

func _game(id: String, lv: int = 1) -> Minigame:
	var d: Dictionary = MinigameCatalog.level(id, lv)
	d["seed"] = 3
	d["practice"] = true
	Minigame.next_def = d
	var g: Minigame = (load(String(d["scene"])) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	return g

func test_defaults_are_the_recovered_values() -> void:
	CameraPrefs.use_path("user://test_camera.cfg")
	var g: Minigame = await _game("demolicion")
	var c: Dictionary = g.camera_defaults()
	check(is_equal_approx(c["back"], 10.5) and is_equal_approx(c["height"], 5.4) and is_equal_approx(c["ahead"], 5.5) and is_equal_approx(c["fov"], 44.0),
		"general: 10,5 m / 5,4 m / 5,5 m / 44 grados (SpCamera.behind_ball del tiro libre)")
	var f: Array = g.camera_frame()
	var b: Array = SpCamera.behind_ball(g._ball_spot(0), g._aim_point(0), 1.0, false)
	check((f[0] as Vector3).distance_to(b[0]) < 0.01 and (f[1] as Vector3).distance_to(b[1]) < 0.01, "misma posicion y mirada que antes del cambio")
	cleanup()
	var bc: Minigame = await _game("boton_caida")
	var c2: Dictionary = bc.camera_defaults()
	check(is_equal_approx(c2["back"], 6.0) and is_equal_approx(c2["height"], 6.5) and is_equal_approx(c2["ahead"], 6.0) and is_equal_approx(c2["fov"], 50.0),
		"Boton de caida: 6 / 6,5 / 6 / 50 grados (su camara anterior)")
	cleanup()

func test_ball_and_player_visible_in_every_level() -> void:
	CameraPrefs.use_path("user://test_camera.cfg")
	tree.root.size = Vector2i(int(VIEW.x), int(VIEW.y))
	var fails: Array = []
	var extras_out: Array = []
	var player_out: Array = []
	var mech_out: Array = []
	var n: int = 0
	for gm in MinigameCatalog.games():
		for d in MinigameCatalog.levels(String(gm["id"])):
			var g: Minigame = await _game(String(gm["id"]), int(d["level"]))
			g.start_match()
			g._frame_camera(true)
			await physics_frames(2)
			n += 1
			if g is Rescate and (g as Rescate).mechs != null and (g as Rescate).shots_max <= 0:
				# Rescate de mecanismos: no hay pelota para patear (se juega tocando los mandos): se tienen que ver todos los
				# mandos que se tocan.
				for m in (g as Rescate).mechs.mechs:
					if String(m["type"]) != "lock" and not _inside(g, (m["root"] as Node3D).global_position + Vector3.UP * 0.4):
						mech_out.append("%s/%s" % [gm["id"], d["title"]])
						break
				cleanup()
				continue
			if not _inside(g, g._ball_spot(g.side)):
				fails.append("%s/%s" % [gm["id"], d["title"]])
			if not _inside(g, g.stance_point(g.side) + Vector3.UP * 1.0):
				player_out.append("%s/%s" % [gm["id"], d["title"]])
			for p in g.frame_points():
				if not _inside(g, p):
					extras_out.append("%s/%s" % [gm["id"], d["title"]])
					break
			cleanup()
	note("%d niveles; con la camara recomendada (la recuperada de Git) el jugador queda cortado en: %s; algo del juego fuera de cuadro en: %s (se ajusta con el panel Cámara)" % [n, str(player_out), str(extras_out)])
	check(fails.is_empty(), "la pelota se ve en todos los niveles (%s)" % str(fails))
	check(mech_out.is_empty(), "en el Rescate de mecanismos se ven todos los mandos (%s)" % str(mech_out))

func _inside(g: Minigame, p: Vector3) -> bool:
	if g.cam.is_position_behind(p):
		return false
	var s: Vector2 = g.cam.unproject_position(p)
	var r: Vector2 = g.get_viewport().get_visible_rect().size
	return s.x >= 0.0 and s.y >= 0.0 and s.x <= r.x and s.y <= r.y

func test_prefs_are_per_game_and_reset() -> void:
	CameraPrefs.use_path("user://test_camera.cfg")
	var g: Minigame = await _game("minigolf")
	var before: Array = g.camera_frame()
	g.toggle_camera_panel()
	g._nudge_camera("back", -1)
	g._nudge_camera("height", 1)
	var after: Array = g.camera_frame()
	check((after[0] as Vector3).distance_to(before[0]) > 0.3, "acercar y subir mueve la camara de este minijuego")
	cleanup()
	var other: Minigame = await _game("bowling")
	check(CameraPrefs.offsets("bowling")["back"] == 0.0, "el bowling no cambio")
	cleanup()
	g = await _game("minigolf")
	check((g.camera_frame()[0] as Vector3).distance_to(after[0]) < 0.01, "el ajuste se guardo para el minigolf")
	CameraPrefs.reset("minigolf")
	check((g.camera_frame()[0] as Vector3).distance_to(before[0]) < 0.01, "«Restablecer» vuelve al recomendado")
	cleanup()

func test_open_panel_blocks_shots() -> void:
	CameraPrefs.use_path("user://test_camera.cfg")
	var g: Minigame = await _game("demolicion")
	g.toggle_camera_panel()
	check(g.camera_panel_open(), "el panel se abre")
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(800, 600)
	g._unhandled_input(ev)
	check(not g._swiping, "con el panel abierto un toque no empieza un tiro")
	g.toggle_camera_panel()
	g._unhandled_input(ev)
	check(g._swiping or g.state != Minigame.State.AIM, "cerrado, el trazo vuelve a funcionar")
	cleanup()
	CameraPrefs.use_path(CameraPrefs.PATH + ".test")
	CameraPrefs.path = CameraPrefs.PATH
