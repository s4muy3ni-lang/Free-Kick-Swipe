extends Node
## Captura de niveles de minijuego con la camara del juego, para revisar escenarios a ojo.
## SNAP_PRESS=N: en Boton de caida aprieta el boton del que espera y captura N fotogramas despues.
## Uso: SNAP_GAME=dianas SNAP_LEVELS=1,4,6 SNAP_OUT=/tmp/capturas [SNAP_DIFF=1] xvfb-run -a godot --display-driver x11 \
##   --rendering-driver opengl3 --fixed-fps 60 --resolution 1600x720 --path . res://tools/minigame_snap.tscn

func _ready() -> void:
	var game: String = OS.get_environment("SNAP_GAME")
	var out: String = OS.get_environment("SNAP_OUT") if OS.get_environment("SNAP_OUT") != "" else "/tmp/capturas"
	DirAccess.make_dir_recursive_absolute(out)
	var lvs: PackedStringArray = OS.get_environment("SNAP_LEVELS").split(",", false)
	if lvs.is_empty():
		for i in MinigameCatalog.levels(game).size():
			lvs.append(str(i + 1))
	for s in lvs:
		var d: Dictionary = MinigameCatalog.level(game, int(s))
		if OS.get_environment("SNAP_DIFF") != "":
			d = MinigameCatalog.at_difficulty(d, int(OS.get_environment("SNAP_DIFF")))
		d["seed"] = 3
		d["practice"] = true
		Minigame.next_def = d
		var g: Minigame = (load(String(d["scene"])) as PackedScene).instantiate()
		g.fast = true
		add_child(g)
		for i in 30:
			await get_tree().process_frame
		g._frame_camera(true)
		for i in 20:
			await get_tree().process_frame
		# SNAP_PRESS=N (solo Boton de caida): aprieta el boton del que espera y captura N fotogramas despues.
		# SNAP_FIRE=N (solo Duelo del guante): suelta el guante contra el que espera y captura N fotogramas despues.
		if OS.get_environment("SNAP_FIRE") != "" and g is GuanteDuel:
			(g as GuanteDuel).charge[g.side] = 1.0
			(g as GuanteDuel).fire()
			for i in int(OS.get_environment("SNAP_FIRE")):
				await get_tree().physics_frame
		if OS.get_environment("SNAP_PRESS") != "" and g is BotonCaida:
			(g as BotonCaida).press(1 - g.side)
			g.state = Minigame.State.OVER
			for i in int(OS.get_environment("SNAP_PRESS")):
				await get_tree().physics_frame
		var path: String = "%s/%s_%s.png" % [out, game, s]
		get_viewport().get_texture().get_image().save_png(path)
		print("captura: ", path)
		g.queue_free()
		await get_tree().process_frame
	get_tree().quit()
