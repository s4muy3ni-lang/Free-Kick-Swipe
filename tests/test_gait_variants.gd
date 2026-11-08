extends TestCase
## Todas las variantes antes descartadas entran en un espacio de mezcla compatible con su direccion real.

func test_previous_gait_variants_are_connected_to_their_real_blend_spaces() -> void:
	var gait: Array = JsonCatalog.gait_points(false)
	var carry: Array = JsonCatalog.gait_points(true)
	var direction: Array = JsonCatalog.dir_points(false)
	var keeper: Array = JsonCatalog.dir_points(true)
	var ids: Dictionary = {}
	for point in gait + carry + direction + keeper:
		ids[point[0]] = true
	var previous: Array[StringName] = []
	for role in [&"loco_sprint", &"loco_walk", &"loco_jog", &"loco_side", &"gk_loco", &"dribble_fast", &"dribble_jog", &"dribble_run", &"dribble_sprint"]:
		for id in AnimDB.candidates(role, {"mirrors": false}):
			previous.append(id)
			check(ids.has(id), "%s entra en la mezcla de su movimiento" % id)
	var visual := FootballerVisual.new()
	visual.keeper_mode = true
	spawn(visual)
	visual.build(FootballerVisual.keeper_kit())
	check(not visual.is_placeholder, "visual real construido con las variantes")
	var mounted: Dictionary = {}
	var root: AnimationNodeBlendTree = visual.anim_tree.tree_root
	for name in [&"Locomotion", &"Carry", &"Dir"]:
		var space: AnimationNode = root.get_node(name)
		for point in space.get_blend_point_count():
			var node: AnimationNodeAnimation = space.get_blend_point_node(point)
			mounted[node.animation] = true
	for id in previous:
		check(mounted.has(PackLibrary.anim_path(id)), "%s montado en el AnimationTree real" % id)
		check(visual.play_pack_clip(id) > 0.0 and visual.current_action == id, "%s invocable en el visual real" % id)
	var last_speed: float = -1.0
	for point in gait:
		check(float(point[1]) >= last_speed, "mezcla frontal ordenada por velocidad natural")
		last_speed = float(point[1])
