extends Node
## Verifica cada tramo y espejo contra el modelo real. Muestrea poses; no certifica contacto visual ni rendimiento Android.
## OUT=/ruta/informe.json godot --headless --path . res://tools/integration/audit_bank.tscn

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()
	var model: Node3D = (load(JsonCatalog.HUMAN_SCENE) as PackedScene).instantiate()
	add_child(model)
	var skeleton: Skeleton3D = model.get_node(JsonRig.SKELETON_PATH)
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.add_animation_library(&"pack", PackLibrary.field())
	player.add_animation_library(&"keeper", PackLibrary.keeper())
	var rows: Array = []
	var failures: int = 0
	var tested: int = 0
	var bank: Dictionary = AnimDB.catalog()
	for source in bank:
		var entry: Dictionary = bank[source]
		for segment in entry.get("tramos", []):
			for suffix in ["", "_mirror"]:
				var id := StringName(String(segment["id"]) + suffix)
				# No se exige inventar espejos: solo se prueban aquellos que existen.
				if suffix != "" and not PackLibrary.has_clip(id):
					continue
				var anim: Animation = PackLibrary.clip(id)
				var errors: Array[String] = []
				var row := {"source": source, "name": entry["nombre"], "id": String(id),
					"action": segment["accion"], "systems": segment["sistemas"],
					"historical_connection": segment["conectada"], "reason": segment["motivo"],
					"registered": anim != null, "invoked": false, "pose_sampled": false,
					"visual_verified": false, "android_verified": false}
				if anim == null:
					errors.append("recurso ausente")
				else:
					row["duration"] = anim.length
					row["tracks"] = anim.get_track_count()
					row["effective_role"] = PackLibrary.meta(id).get("role", "")
					row["role_indexed"] = AnimDB.candidates(StringName(row["effective_role"])).has(id)
					if anim.length <= 0 or anim.get_track_count() == 0:
						errors.append("clip vacio")
					for track in anim.get_track_count():
						var path: NodePath = anim.track_get_path(track)
						var node: Node = model.get_node_or_null(NodePath(String(path).get_slice(":", 0)))
						if node == null:
							errors.append("nodo ausente: %s" % path)
						elif path.get_subname_count() > 0 and node is Skeleton3D and (node as Skeleton3D).find_bone(path.get_subname(0)) < 0:
							errors.append("hueso ausente: %s" % path)
					if errors.is_empty():
						player.play(PackLibrary.anim_path(id))
						player.advance(0.0)
						row["invoked"] = player.current_animation == PackLibrary.anim_path(id)
						for fraction in [0.0, 0.5, 0.999]:
							player.seek(anim.length * fraction, true)
							skeleton.force_update_all_bone_transforms()
							for bone in skeleton.get_bone_count():
								if not skeleton.get_bone_global_pose(bone).is_finite():
									errors.append("pose no finita")
						row["pose_sampled"] = errors.is_empty() and row["invoked"]
						player.stop()
						skeleton.reset_bone_poses()
				row["errors"] = errors
				if not errors.is_empty() or not row["pose_sampled"]:
					failures += 1
				rows.append(row)
				tested += 1
		if rows.size() % 100 == 0:
			await get_tree().process_frame
	var report := {"engine": Engine.get_version_info()["string"], "sources": bank.size(), "tested": tested,
		"failures": failures, "method": "AnimationPlayer: invocacion y seek al inicio, mitad y final; pistas, huesos y poses finitas",
		"memory_static_bytes": OS.get_static_memory_usage(), "rows": rows}
	var out: String = OS.get_environment("OUT")
	if out.is_empty():
		out = "user://integration_audit.json"
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo escribir %s" % out)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("Auditoria: %d fuentes, %d variantes, %d fallos -> %s" % [bank.size(), tested, failures, out])
	get_tree().quit(1 if failures > 0 else 0)
