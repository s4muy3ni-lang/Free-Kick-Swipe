extends Node
## Capturas del publico de penales y tiros libres (revision visual): calma, festejo de gol y abucheo, con la camara del
## juego. CROWD_OUT=<prefijo> [CROWD_MODE=penal] xvfb-run -a godot --display-driver x11 --rendering-driver opengl3
##   --resolution 1280x720 --path . res://tools/ui/crowd_capture.tscn

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [OS.get_environment("CROWD_OUT"), name])
	print("captura: ", name)

func _ready() -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY if OS.get_environment("CROWD_MODE") == "penal" else SetPieceGame.Mode.FREE_KICK
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	add_child(game)
	for i in 60:
		await get_tree().process_frame
	await _shot("calma")
	game.crowd_react(true, "goal")
	for i in 40:
		await get_tree().process_frame
	await _shot("festejo")
	game.crowd_react(false, "miss")
	for i in 40:
		await get_tree().process_frame
	await _shot("abucheo")
	get_tree().quit()
