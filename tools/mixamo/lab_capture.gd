extends Node
## Capturas del laboratorio de animaciones con render (revision visual de la comparacion ACTUAL vs MIXAMO):
##   SIT=<situacion> VIEW=<0..3> TIMES=<s,s,...> OUT=<prefijo> xvfb-run -a godot --display-driver x11 \
##     --rendering-driver opengl3 --resolution 1600x900 --path . res://tools/mixamo/lab_capture.tscn
func _ready() -> void:
	var lab: AnimLab = (load(AnimLab.SCENE) as PackedScene).instantiate()
	add_child(lab)
	await get_tree().process_frame
	var sit: String = OS.get_environment("SIT")
	if sit != "":
		lab.select_situation(sit)
	var v: String = OS.get_environment("VIEW")
	if v != "":
		lab.set_view(int(v))
	lab.playing = false
	var times: PackedStringArray = OS.get_environment("TIMES").split(",")
	var out: String = OS.get_environment("OUT")
	for i in times.size():
		lab.clock = float(times[i])
		for st in lab.stations:
			lab._pose(st, lab.clock - st.lead)
		for k in 4:
			await get_tree().process_frame
		lab._refresh_info()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, i])
	print("INFO_A ", lab.station_info(AnimBank.Bank.ACTUAL).replace("\n", " | "))
	print("INFO_M ", lab.station_info(AnimBank.Bank.MIXAMO).replace("\n", " | "))
	get_tree().quit()
