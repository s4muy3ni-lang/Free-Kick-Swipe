extends TestCase
## Modelo del futbolista (Tripo3D): importacion, triangulos, esqueleto, animaciones y kit.

## Sistema del modo 1 (pack de Mixamo / Tripo), descartado como modo de juego pero todavia en el codigo: se prueba en su modo.
func gameplay_mode() -> int:
	return 1

const MAX_TRIANGLES := 10000

func _count_tris(root: Node) -> int:
	var tris: int = 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var idx: PackedInt32Array = m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3
	return tris

func test_model_imports_within_triangle_budget() -> void:
	var vis := FootballerVisual.new()
	spawn(vis)
	var ok: bool = vis.build(FootballerVisual.default_kit(0))
	check(ok and not vis.is_placeholder, "el modelo de Tripo se carga (no se usa el maniqui)")
	var tris: int = _count_tris(vis)
	note("triangulos del futbolista: %d (limite %d)" % [tris, MAX_TRIANGLES])
	check(tris > 3000 and tris <= MAX_TRIANGLES, "triangulos dentro del presupuesto (%d)" % tris)
	check(vis.skeleton != null and vis.skeleton.get_bone_count() == 23, "esqueleto humanoide de 23 huesos (rig v1.0 de Tripo)")
	check(vis.skeleton.find_bone("mixamorig_Hips") >= 0 and vis.skeleton.find_bone("mixamorig_LeftFoot") >= 0, "huesos clave presentes")
	check(vis.mesh_instances.size() >= 1, "hay malla skineada")

func test_animations_present_loop_and_are_centered() -> void:
	var vis := FootballerVisual.new()
	spawn(vis)
	vis.build(FootballerVisual.default_kit(0))
	var hips: int = vis.skeleton.find_bone("mixamorig_Hips")
	var rest: Vector3 = vis.skeleton.get_bone_rest(hips).origin
	# Clips de la libreria compartida; los de bucle se comprueban aparte.
	for an in FootballerVisual.ACTION_CLIPS + [&"idle", &"walk", &"run"]:
		check(vis.anim_player.has_animation(an), "animacion '%s' presente" % an)
	for an in ["idle", "walk", "run"]:
		var anim: Animation = vis.anim_player.get_animation(an)
		check(anim.loop_mode == Animation.LOOP_LINEAR, "'%s' en bucle" % an)
		var bm: Dictionary = PoseSampler.bind(anim, vis.skeleton)
		check(bm.size() >= 20, "'%s' anima el esqueleto (%d pistas enlazadas)" % [an, bm.size()])
		# En el esqueleto v1.0 los ejes horizontales de la cadera son X e Y (Z es "arriba").
		var sum := Vector2.ZERO
		var n: int = 30
		for tr in anim.get_track_count():
			if anim.track_get_type(tr) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(tr)).ends_with("mixamorig_Hips"):
				for i in n:
					var v: Vector3 = anim.position_track_interpolate(tr, anim.length * i / n)
					sum += Vector2(v.x, v.y)
				sum /= n
				check_near(sum.x, rest.x, 0.02, "'%s': cadera centrada en el eje horizontal X" % an)
				check_near(sum.y, rest.y, 0.02, "'%s': cadera centrada en el eje horizontal Y" % an)

func test_kit_recolors_the_material() -> void:
	var vis := FootballerVisual.new()
	spawn(vis)
	var kit: Dictionary = FootballerVisual.default_kit(0)
	vis.build(kit)
	check(vis.kit_material != null, "hay material de kit")
	vis.set_kit({"jersey": Color(0.1, 0.8, 0.2)})
	var c: Color = vis.kit_material.get_shader_parameter("jersey_color")
	check_near(c.g, 0.8, 0.001, "cambiar el color de la camiseta actualiza el shader")
	check(vis.kit_material.get_shader_parameter("mask_a") != null, "mascara de regiones cargada")

func test_animation_tree_responds_to_speed() -> void:
	var ctx: MatchContext = await make_match()
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-10, 0, 0), 50, src, true)
	await physics_frames(5)
	check(p.visual != null and not p.visual.is_placeholder, "el futbolista usa el modelo")
	var idle_pos: float = float(p.visual.anim_tree.get("parameters/Locomotion/blend_position"))
	src.move = Vector2(1, 0)
	src.sprint = true
	await wait_seconds(2.0)
	var run_pos: float = float(p.visual.anim_tree.get("parameters/Locomotion/blend_position"))
	var scale_v: float = float(p.visual.anim_tree.get("parameters/LocoScale/scale"))
	note("blend de locomocion: parado=%.2f, sprint=%.2f; escala de tiempo=%.2f" % [idle_pos, run_pos, scale_v])
	check(run_pos > idle_pos + 4.0, "la mezcla de locomocion sigue a la velocidad")
	check(scale_v > 1.0 and scale_v <= FootballerVisual.MAX_TIME_SCALE + 0.001, "la cadencia se acelera con la velocidad (%.2f)" % scale_v)
	check(p.visual.rig.rotation.x < -0.05, "el cuerpo se inclina hacia delante al correr")
