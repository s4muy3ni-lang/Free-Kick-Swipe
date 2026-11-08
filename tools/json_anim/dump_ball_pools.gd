extends Node
## Escribe tools/json_anim/steer_pool.json y start_pool.json: los clips (sin espejos) que el juego usa para el toque
## orientado y el arranque con pelota (JsonBallMove.steer_pool / start_pool). Los lee make_animdb.py para marcar el
## estado de cada clip en el animdb. Uso: godot --headless --path . res://tools/json_anim/dump_ball_pools.tscn

func _ready() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()
	JsonBallMove.reset_caches()
	_write("res://tools/json_anim/steer_pool.json", JsonBallMove.steer_pool())
	_write("res://tools/json_anim/start_pool.json", JsonBallMove.start_pool())
	get_tree().quit()

func _write(path: String, ids: Array[StringName]) -> void:
	var base: Array = []
	for id in ids:
		var s: String = String(id)
		if not s.ends_with("_mirror") and not base.has(s):
			base.append(s)
	base.sort()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(base, " "))
	f.close()
	print("POOL %s: %d clips (%d con espejos)" % [path, base.size(), ids.size()])
