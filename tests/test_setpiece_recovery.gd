extends TestCase
## Recuperacion contextual de clips antes excluidos: se exige el contacto fisico, sin saques de respaldo.
class SpecifiedSetPiece extends SetPiece:
	var selected: StringName
	func _kick_clip(_act: StringName, _lb: bool) -> StringName:
		return selected

func test_originally_excluded_kicks_reach_the_ball_at_an_unobstructed_free_kick() -> void:
	for id in [&"jn_setpiece_pass_3330", &"jn_setpiece_pass_3342", &"jn_setpiece_pass_3346", &"jn_setpiece_shot_3354", &"jn_setpiece_shot_3856"]:
		var ctx: MatchContext = await make_match(Vector3(0, 0.11, 0))
		var taker: Footballer = add_player(ctx, 0, Vector3(-2, 0, 0), 60, ScriptedInput.new(), true)
		await physics_frames(3)
		var sp := SpecifiedSetPiece.new(SetPiece.Kind.FREE_KICK, 0, Vector3.ZERO, taker, ctx)
		sp.selected = id
		check(sp.recovered_free_kicks(&"shot" if String(id).contains("shot") else &"pass").has(id), "%s disponible en el selector real de tiros libres" % id)
		taker.set_piece = sp
		sp.execute(&"shot" if String(id).contains("shot") else &"pass", 0.5, false, Vector3.RIGHT)
		check(taker.actions.motion.clip == id, "%s invocado como tiro libre" % id)
		for frame in 240:
			await tree.physics_frame
			if sp.resolved:
				break
		note("%s: resultado %s, fallos %d, ejecutor %s" % [id, sp.result, sp.misses, taker.global_position])
		note(str(sp.last_setup))
		note(str(sp.last_contact))
		check(sp.result == &"contact" and sp.misses == 0, "%s llega al contacto sin correccion de respaldo" % id)
		cleanup()
		await physics_frames(2)
