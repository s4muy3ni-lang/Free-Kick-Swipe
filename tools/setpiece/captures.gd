extends Node
## Capturas de los modos de tiros libres y penales (requiere render: xvfb-run ... --rendering-driver opengl3).
##   xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --resolution 1280x720 --path . \
##     res://tools/setpiece/captures.tscn -- --out <dir> [--case penalty|freekick|menu|keeper]
## Simula tiros (sin trazo: SetPieceGame.shoot) y guarda imagenes en momentos clave y un resumen de lo medido.

var out_dir: String = "user://capturas_setpiece"
var case_name: String = "all"
var game: SetPieceGame
var log_lines: PackedStringArray = []

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
		if args[i] == "--case" and i + 1 < args.size():
			case_name = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	log_lines.append("captura %s" % name)

var _t0: int = 0
func _touch(p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = p
	e.pressed = pressed
	game._unhandled_input(e)

func _drag(p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = p
	game._unhandled_input(e)

func _wait_phase(p: int, max_frames: int = 600) -> void:
	for i in max_frames:
		if game.phase == p:
			return
		await get_tree().physics_frame

func _load_game(m: int) -> void:
	if game != null:
		game.queue_free()
		await _frames(2)
	SetPieceGame.next_mode = m
	game = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(game)
	await _frames(20)

func _run() -> void:
	if case_name in ["all", "menu"]:
		var menu: Node = (load(MainMenu.SCENE) as PackedScene).instantiate()
		get_tree().root.add_child(menu)
		await _frames(40)
		await _shot("00_menu")
		menu.queue_free()
		await _frames(2)
	if case_name in ["all", "penalty"]:
		await _load_game(SetPieceGame.Mode.PENALTY)
		await _frames(30)
		await _shot("10_penal_apuntar")
		game.shoot(Vector3(game.gx, 0.6, 2.9), 0.75, 0.0)
		log_lines.append("penal: golpeo %s (%s) clase %s" % [game.last_shot.get("entry", {}).get("id", "?"), game.last_shot.get("entry", {}).get("role", "?"), game.last_shot.get("class", "?")])
		await _frames(25)
		await _shot("11_penal_carrera")
		await _wait_phase(SetPieceGame.Phase.FLIGHT)
		await _shot("12_penal_contacto")
		log_lines.append("penal: pie-pelota en el contacto %.3f m" % game.user_shooter.contact_gap)
		await _frames(12)
		await _shot("13_penal_vuelo")
		await _wait_phase(SetPieceGame.Phase.RESULT)
		log_lines.append("penal: resultado %s, arquero %s (plan %s)" % [game.outcome, game.cpu_keeper.touch_kind, str(game.cpu_keeper.plan.get("clip", "-"))])
		await _frames(30)
		await _shot("14_penal_resultado")
		await _frames(90)
		await _shot("15_penal_festejo")
	if case_name in ["all", "keeper"]:
		await _load_game(SetPieceGame.Mode.PENALTY)
		game.shootout.record(0, true)
		game._start_penalty_turn()
		await _frames(40)
		await _shot("20_arquero_elegir")
		game._keeper_zone = Vector3(game.gx, 0.6, -2.6)
		await _wait_phase(SetPieceGame.Phase.FLIGHT, 900)
		await _frames(14)
		await _shot("21_arquero_estirada")
		await _wait_phase(SetPieceGame.Phase.RESULT, 600)
		log_lines.append("arquero usuario: resultado %s, toque %s, plan %s" % [game.outcome, game.user_keeper.touch_kind, str(game.user_keeper.plan.get("clip", "-"))])
		await _frames(60)
		await _shot("22_arquero_resultado")
	if case_name in ["all", "gesture"]:
		# Trazo real con eventos: vista previa de la trayectoria e indicadores mientras el dedo esta apoyado.
		await _load_game(SetPieceGame.Mode.FREE_KICK)
		game.ball_spot = game.clamp_free_kick_spot(Vector3(game.gx - 22.0, 0, 5.0))
		game._setup_free_kick()
		game.diag.visible = true
		await _frames(50)
		var from: Vector2 = game.cam.unproject_position(game.ball_spot)
		var to: Vector2 = game.cam.unproject_position(Vector3(game.gx, 2.0, -2.8))
		var steps: int = 14
		_touch(from, true)
		for i in range(1, steps + 1):
			var u: float = float(i) / float(steps)
			var p: Vector2 = from.lerp(to, u) + Vector2(-90.0 * sin(u * PI), 0.0)
			_drag(p)
			await _frames(1)
			if i == 10:
				await _frames(6)
				await _shot("40_trazo_prevision")
		_touch(to + Vector2(-2, 0), false)
		await _frames(2)
		log_lines.append("trazo: tipo %s, potencia %.2f, efecto %.1f, golpeo %s" % [game.last_params.gesture_type if game.last_params else "-", game.last_params.power if game.last_params else 0.0, game.last_params.lateral_spin if game.last_params else 0.0, game.last_shot.get("entry", {}).get("id", "-")])
		await _wait_phase(SetPieceGame.Phase.FLIGHT, 900)
		await _frames(30)
		await _shot("41_trazo_vuelo_diag")
		await _wait_phase(SetPieceGame.Phase.RESULT, 600)
		log_lines.append("trazo: resultado %s, salida real %.1f m/s" % [game.outcome, game.last_launch_speed])
	if case_name in ["all", "goals"]:
		for style in [PitchConfig.GoalStyle.BOX, PitchConfig.GoalStyle.SLANTED]:
			SpSettings.goal_style = style
			await _load_game(SetPieceGame.Mode.PENALTY)
			game.cam.frame(Vector3(game.gx - 6.0, 1.6, 6.5), Vector3(game.gx + 0.8, 1.0, 0.0), 55.0, true)
			await _frames(20)
			await _shot("5%d_arco_%s" % [style, SpSettings.GOAL_STYLE_NAMES[style]])
			game.ball.kick(Vector3(26.0, 3.2, 2.2), Vector3.ZERO, null)
			await _frames(28)
			await _shot("5%d_arco_%s_impacto" % [style, SpSettings.GOAL_STYLE_NAMES[style]])
		SpSettings.goal_style = PitchConfig.GoalStyle.BOX
	if case_name in ["all", "freekick"]:
		await _load_game(SetPieceGame.Mode.FREE_KICK)
		await _frames(30)
		await _shot("30_libre_colocar")
		game.ball_spot = game.clamp_free_kick_spot(Vector3(game.gx - 23.0, 0, -7.0))
		game._setup_free_kick()
		await _frames(60)
		await _shot("31_libre_apuntar")
		game.shoot(Vector3(game.gx, 2.05, 2.6), 0.62, -0.18)
		log_lines.append("libre: golpeo %s (%s) clase %s" % [game.last_shot.get("entry", {}).get("id", "?"), game.last_shot.get("entry", {}).get("role", "?"), game.last_shot.get("class", "?")])
		await _wait_phase(SetPieceGame.Phase.FLIGHT, 900)
		await _shot("32_libre_contacto")
		log_lines.append("libre: pie-pelota en el contacto %.3f m" % game.user_shooter.contact_gap)
		await _frames(18)
		await _shot("33_libre_vuelo")
		await _frames(18)
		await _shot("34_libre_vuelo2")
		await _wait_phase(SetPieceGame.Phase.RESULT, 600)
		log_lines.append("libre: resultado %s" % game.outcome)
		await _frames(20)
		await _shot("35_libre_resultado")
		await _frames(100)
		await _shot("36_libre_reaccion")
	var f := FileAccess.open("%s/resumen.txt" % out_dir, FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	print("\n".join(log_lines))
	get_tree().quit()
