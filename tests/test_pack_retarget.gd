extends TestCase
## Validacion de los clips del pack de Mixamo ya convertidos al esqueleto de Tripo (assets/animations/pack_clips.res).
## La libreria es un recurso restringido que se genera en local: sin ella estas pruebas se OMITEN (no se dan por buenas).

## Sistema del modo 1 (pack de Mixamo / Tripo), descartado como modo de juego pero todavia en el codigo: se prueba en su modo.
func gameplay_mode() -> int:
	return 1

const BONES := 23

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe assets/animations/pack_clips.res (generar con tools/animation_pack/build_pack_library.tscn)")
		return true
	return false

func _visual() -> FootballerVisual:
	var vis := FootballerVisual.new()
	spawn(vis)
	vis.build(FootballerVisual.default_kit(0))
	vis.anim_tree.active = false
	return vis

func _pose(vis: FootballerVisual, anim: Animation, t: float) -> void:
	PoseSampler.apply(anim, vis.skeleton, PoseSampler.bind(anim, vis.skeleton), t)

func _bone_pos(vis: FootballerVisual, bone: String) -> Vector3:
	return PoseSampler.bone_in_skeleton(vis.skeleton, vis.skeleton.find_bone("mixamorig_" + bone)).origin * FootballerVisual.MODEL_HEIGHT_SCALE

func test_library_has_expected_clips_and_metadata() -> void:
	if _skip_if_missing():
		return
	var lib: AnimationLibrary = PackLibrary.field()
	for id in ["offensive_idle", "Soccer_Idle", "Walking_7_inplace", "jog_forward_inplace", "Sprint_inplace", "Dribble_2", "Soccer_Pass", "Soccer_Pass_mirror", "strike_foward_jog_inplace", "strike_foward_jog_inplace_mirror", "soccer_penalty_kick", "Chip", "Receive", "soccer_tackle", "Falling_Down", "standing_up", "Victory", "Defeat"]:
		check(lib.has_animation(id), "el clip '%s' esta en la libreria" % id)
		check(not PackLibrary.meta(id).is_empty(), "'%s' trae metadatos medidos" % id)
	note("clips de campo: %d" % lib.get_animation_list().size())

func test_every_clip_has_clean_tracks() -> void:
	if _skip_if_missing():
		return
	var lib: AnimationLibrary = PackLibrary.field()
	var bad: Array[String] = []
	var worst_jump := 0.0
	var worst_name := ""
	for id in lib.get_animation_list():
		var a: Animation = lib.get_animation(id)
		var rot := 0
		var pos := 0
		for t in a.get_track_count():
			var ty: int = a.track_get_type(t)
			if ty == Animation.TYPE_ROTATION_3D:
				rot += 1
			elif ty == Animation.TYPE_POSITION_3D:
				pos += 1
			var prev: Quaternion = Quaternion.IDENTITY
			for k in a.track_get_key_count(t):
				var v: Variant = a.track_get_key_value(t, k)
				if ty == Animation.TYPE_ROTATION_3D:
					var q: Quaternion = v
					if not is_equal_approx(q.length(), 1.0) or is_nan(q.x):
						bad.append("%s: cuaternion no unitario" % id)
						break
					if k > 0:
						var jump: float = rad_to_deg(prev.angle_to(q))
						if jump > worst_jump:
							worst_jump = jump
							worst_name = id
					prev = q
				elif ty == Animation.TYPE_POSITION_3D:
					if is_nan((v as Vector3).x) or (v as Vector3).length() > 5.0:
						bad.append("%s: posicion de cadera invalida" % id)
						break
		if rot != BONES or pos != 1:
			bad.append("%s: %d rotaciones, %d posiciones (se esperaban %d y 1)" % [id, rot, pos, BONES])
	note("mayor salto de un hueso entre fotogramas consecutivos (30 fps): %.1f grados en '%s'" % [worst_jump, worst_name])
	check(bad.is_empty(), "pistas limpias en todos los clips: %s" % str(bad))
	check(worst_jump < 140.0, "ningun hueso da un vuelco entre fotogramas (max %.1f grados en %s)" % [worst_jump, worst_name])

func test_orientation_matches_the_tripo_rig() -> void:
	if _skip_if_missing():
		return
	var vis: FootballerVisual = _visual()
	var checked := 0
	for id in ["offensive_idle", "Walking_7_inplace", "jog_forward_inplace", "Sprint_inplace", "Dribble_2", "Soccer_Pass"]:
		var a: Animation = PackLibrary.clip(id)
		for k in 4:
			_pose(vis, a, a.length * float(k) / 4.0)
			var hips: Vector3 = _bone_pos(vis, "Hips")
			var head: Vector3 = _bone_pos(vis, "Head")
			var toe_l: Vector3 = _bone_pos(vis, "LeftToeBase")
			var toe_r: Vector3 = _bone_pos(vis, "RightToeBase")
			var foot_l: Vector3 = _bone_pos(vis, "LeftFoot")
			var foot_r: Vector3 = _bone_pos(vis, "RightFoot")
			var ok: bool = head.y > hips.y + 0.35 and toe_l.z < toe_r.z and (toe_l.x + toe_r.x) * 0.5 > (foot_l.x + foot_r.x) * 0.5 - 0.05
			check(ok, "'%s' fotograma %d: cabeza arriba, izquierda a -Z, derecha a +Z, pies mirando a +X" % [id, k])
			checked += 1
	note("poses de orientacion comprobadas: %d" % checked)

func test_feet_stay_on_the_ground_and_hips_do_not_travel() -> void:
	if _skip_if_missing():
		return
	var vis: FootballerVisual = _visual()
	for id in ["Walking_7_inplace", "jog_forward_inplace", "Sprint_inplace", "Dribble_2"]:
		var a: Animation = PackLibrary.clip(id)
		var m: Dictionary = PackLibrary.meta(id)
		var floor_cm: float = m["foot_floor_cm"]
		check(absf(floor_cm) <= 4.0, "'%s': el tobillo mas bajo queda a %+.1f cm del reposo (|x| <= 4 cm)" % [id, floor_cm])
		var hip0: Vector3 = Vector3.ZERO
		var worst := 0.0
		for k in 12:
			_pose(vis, a, a.length * float(k) / 12.0)
			var hp: Vector3 = _bone_pos(vis, "Hips")
			if k == 0:
				hip0 = hp
			worst = maxf(worst, Vector2(hp.x - hip0.x, hp.z - hip0.z).length())
		check(worst < 0.12, "'%s': la cadera no se desplaza por el suelo (desvio horizontal max %.2f m)" % [id, worst])

func test_measured_natural_speeds_match_the_clips() -> void:
	if _skip_if_missing():
		return
	var expected := {"Walking_7_inplace": [0.8, 1.0], "Jogging_inplace": [1.5, 1.8], "jog_forward_inplace": [2.0, 2.3], "Sprint_inplace": [4.5, 5.3], "Dribble_2": [2.1, 2.5]}
	for id in expected:
		var v: float = PackLibrary.meta(id)["natural_speed"]
		check_range(v, expected[id][0], expected[id][1], "velocidad natural de '%s' (m/s en juego)" % id)
	# La cadencia necesaria a las velocidades del juego queda en un rango razonable.
	var t: PlayerTuning = Tuning.player
	var sprint_scale: float = t.sprint_speed / float(PackLibrary.meta("Sprint_inplace")["natural_speed"])
	note("escala de tiempo del sprint (%.1f m/s) con el clip del pack: x%.2f" % [t.sprint_speed, sprint_scale])
	check(sprint_scale < 1.6, "el sprint del juego exige una cadencia razonable (x%.2f)" % sprint_scale)

func test_kick_contacts_are_measured_and_mirrors_are_symmetric() -> void:
	if _skip_if_missing():
		return
	var vis: FootballerVisual = _visual()
	for id in ["Soccer_Pass", "strike_foward_jog_inplace", "soccer_penalty_kick", "Chip"]:
		var c: Dictionary = PackLibrary.meta(id)["contact"]
		var cm: Dictionary = PackLibrary.meta(id + "_mirror")["contact"]
		check_range(float(c["time"]), 0.2, 1.0, "'%s': instante de contacto medido (s)" % id)
		check(c["foot"] == 1 and cm["foot"] == -1, "'%s': original con pie derecho, espejo con el izquierdo" % id)
		check((c["pos"] as Vector3).z > 0.0 and (cm["pos"] as Vector3).z < 0.0, "'%s': el pie de golpeo queda de su lado" % id)
		check(absf((c["pos"] as Vector3).z + (cm["pos"] as Vector3).z) < 0.08 and absf((c["pos"] as Vector3).x - (cm["pos"] as Vector3).x) < 0.08, "'%s': el espejo es simetrico (%s vs %s)" % [id, str(c["pos"]), str(cm["pos"])])
		check((c["pos"] as Vector3).y < 0.45, "'%s': la punta del pie esta baja en el contacto (%.2f m)" % [id, (c["pos"] as Vector3).y])
		# El esqueleto realmente animado coincide con el metadato: la punta del pie esta donde dice el contacto.
		var a: Animation = PackLibrary.clip(id)
		_pose(vis, a, float(c["time"]))
		var toe: Vector3 = _bone_pos(vis, "RightToeBase")
		var meta_pos: Vector3 = c["pos"]
		check(toe.distance_to(meta_pos) < 0.06, "'%s': el esqueleto en t=%.2f s pone la punta a %.3f m del contacto registrado" % [id, c["time"], toe.distance_to(meta_pos)])
