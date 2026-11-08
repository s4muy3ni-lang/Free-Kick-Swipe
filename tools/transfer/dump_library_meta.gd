extends Node
## Herramienta de DOCUMENTACION (no es codigo de juego): vuelca a JSON la metadata de cada clip del modo 4 tal como la usa
## el juego (librerias json_clips.res, json_keeper.res, json_scenes.res via PackLibrary): rol, duracion, velocidades,
## giro, toques de pelota (instante, pie, punta del pie en el marco del inicio del clip), contacto de las patadas, etc.
## La usa tools/transfer/make_inventory.py para docs/transferencia_integracion_completa/INVENTARIO_ANIMACIONES.csv.
## Uso: godot --headless --path . res://tools/transfer/dump_library_meta.tscn   (env OUT = ruta del JSON de salida)

const SKIP := ["paths", "root_path", "heading_path", "paths_root"]

func _ready() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()
	var out_path: String = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "user://library_meta.json"
	var rows: Dictionary = {}
	var roles: Dictionary = {}
	for lib in [PackLibrary.field(), PackLibrary.keeper()]:
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			var id := StringName(anim_name)
			var m: Dictionary = PackLibrary.meta(id)
			if m.is_empty():
				continue
			var d := {}
			for k in m.keys():
				if SKIP.has(String(k)):
					continue
				d[String(k)] = _plain(m[k])
			var hp: PackedFloat32Array = m.get("heading_path", PackedFloat32Array())
			d["turn_deg"] = rad_to_deg(ActionMotion.heading_rel(hp, float(m.get("duration", 1.0))))
			d["library"] = "keeper" if lib == PackLibrary.keeper() else "field"
			rows[String(id)] = d
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(rows))
	f.close()
	print("META clips: ", rows.size(), " -> ", out_path)
	get_tree().quit()

func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2:
			return [snappedf(v.x, 0.001), snappedf(v.y, 0.001)]
		TYPE_VECTOR3:
			return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
		TYPE_ARRAY:
			var a: Array = []
			for e in v:
				a.append(_plain(e))
			return a
		TYPE_DICTIONARY:
			var o := {}
			for k in v.keys():
				o[String(k)] = _plain(v[k])
			return o
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			return "(%d valores)" % v.size()
		TYPE_FLOAT:
			return snappedf(v, 0.001)
	return v
