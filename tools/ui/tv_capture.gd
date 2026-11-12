extends Node
## Capturas de la camara de TV de los tiros libres (revision visual): patea y captura en vuelo.
## TV_OUT=<prefijo> xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --resolution 1600x720 \
##   --path . res://tools/ui/tv_capture.tscn
func _ready() -> void:
	GraphicsSettings.tv_camera = true
	SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK
	var g: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	add_child(g)
	for i in 30:
		await get_tree().physics_frame
	g.ball_spot = g.clamp_free_kick_spot(Vector3(g.gx - 26.0, 0, 6.0))
	g._setup_free_kick()
	for i in 20:
		await get_tree().physics_frame
	g.shoot(Vector3(g.gx, 1.9, -2.6), 0.75, -0.1)
	var shots := 0
	for i in 400:
		await get_tree().physics_frame
		if (g.phase == SetPieceGame.Phase.RUNUP and i == 25) or (g.phase == SetPieceGame.Phase.FLIGHT and shots < 3 and i % 18 == 0):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s_%d.png" % [OS.get_environment("TV_OUT"), shots])
			shots += 1
		if shots >= 3:
			break
	GraphicsSettings.tv_camera = false
	get_tree().quit()
