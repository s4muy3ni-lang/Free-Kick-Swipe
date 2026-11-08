extends TestCase
## Sistema de animacion unico: marcha y acciones con el pack de Mixamo si la libreria local existe, y Tripo como
## respaldo. Las pruebas del camino del pack se OMITEN sin la libreria (recurso restringido, no versionado).

## Sistema del modo 1 (pack de Mixamo / Tripo), descartado como modo de juego pero todavia en el codigo: se prueba en su modo.
func gameplay_mode() -> int:
	return 1

func _visual_player(use_pack: bool) -> Dictionary:
	FootballerVisual.prefer_pack = use_pack
	var ctx: MatchContext = await make_match(Vector3(30.0, 0.11, 5.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-10, 0, 0), 50, src, true)
	await physics_frames(5)
	return {"ctx": ctx, "src": src, "p": p}

func _restore() -> void:
	FootballerVisual.prefer_pack = true

func _skip_without_pack() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe assets/animations/pack_clips.res")
		return true
	return false

func test_fallback_to_tripo_gaits_when_pack_is_disabled() -> void:
	var d: Dictionary = await _visual_player(false)
	var p: Footballer = d["p"]
	check(not p.visual.uses_pack, "con prefer_pack = false el futbolista usa solo los clips de Tripo")
	var space: AnimationNodeBlendSpace1D = (p.visual.anim_tree.tree_root as AnimationNodeBlendTree).get_node(&"Locomotion")
	check(space.get_blend_point_count() == 3, "marcha de Tripo: idle, walk, run (%d puntos)" % space.get_blend_point_count())
	d["src"].move = Vector2(1, 0)
	d["src"].sprint = true
	await wait_seconds(2.0)
	var s: float = float(p.visual.anim_tree.get("parameters/LocoScale/scale"))
	check(s > 1.0 and s <= FootballerVisual.MAX_TIME_SCALE + 0.001, "la cadencia de Tripo se acelera con la velocidad (x%.2f)" % s)
	check(p.visual.play_pack_clip(&"Soccer_Pass") == 0.0, "sin pack, play_pack_clip no hace nada")
	var r: Dictionary = p.visual.play_situation(&"celebrate")
	check(r.get("source", &"") == &"tripo" and r.get("clip", &"") == &"celebrate_goal", "la celebracion cae al clip de Tripo: %s" % str(r))
	check(p.visual.play_situation(&"receive").is_empty(), "una situacion sin clip de Tripo no inventa nada")
	_restore()

func test_pack_gait_blend_points_are_the_measured_natural_speeds() -> void:
	if _skip_without_pack():
		return
	var d: Dictionary = await _visual_player(true)
	var p: Footballer = d["p"]
	check(p.visual.uses_pack, "con la libreria del pack el futbolista la usa")
	var space: AnimationNodeBlendSpace1D = (p.visual.anim_tree.tree_root as AnimationNodeBlendTree).get_node(&"Locomotion")
	check(space.get_blend_point_count() == FootballerVisual.PACK_GAIT_POINTS.size(), "marcha del pack: idle, caminar, trotar (x2), sprint (%d puntos)" % space.get_blend_point_count())
	for i in space.get_blend_point_count():
		var pt: Array = FootballerVisual.PACK_GAIT_POINTS[i]
		var clip: StringName = pt[0]
		var nat: float = 0.0 if clip == &"offensive_idle" else float(PackLibrary.meta(clip)["natural_speed"])
		var expected: float = nat if float(pt[1]) < 0.0 else float(pt[1])
		check_near(space.get_blend_point_position(i), expected, 0.001, "el punto %d (%s) esta en %.2f m/s" % [i, clip, expected])
	d["src"].move = Vector2(1, 0)
	d["src"].sprint = true
	await wait_seconds(2.5)
	var scale_v: float = float(p.visual.anim_tree.get("parameters/LocoScale/scale"))
	var spd: float = p.locomotion.speed
	note("sprint: velocidad %.2f m/s, escala de tiempo x%.2f, posicion de mezcla %.2f" % [spd, scale_v, float(p.visual.anim_tree.get("parameters/Locomotion/blend_position"))])
	check(scale_v > 1.0 and scale_v < 1.6, "por encima del sprint natural la cadencia sube de forma moderada (x%.2f)" % scale_v)
	for v in [0.9, 1.5, 2.15, 3.0, 3.4, 4.3, 5.13]:
		var sc: float = p.visual.gait_time_scale(v)
		check(sc >= 0.6 and sc <= 1.7, "escala de tiempo a %.2f m/s dentro de lo razonable (x%.2f)" % [v, sc])
	check_near(p.visual.gait_time_scale(0.9), 1.0, 0.01, "a la velocidad natural de caminar el ritmo es 1.0")
	check_near(p.visual.gait_time_scale(5.13), 1.0, 0.01, "a la velocidad natural del sprint el ritmo es 1.0")
	_restore()

func test_actions_never_overlap_and_finish() -> void:
	if _skip_without_pack():
		return
	var d: Dictionary = await _visual_player(true)
	var v: FootballerVisual = (d["p"] as Footballer).visual
	var finished: Array[StringName] = []
	v.action_finished.connect(func(c: StringName) -> void: finished.append(c))
	var t1: float = v.play_action(&"celebrate_goal")
	check(t1 > 0.0 and v.current_action == &"celebrate_goal", "arranca una accion de Tripo")
	var t2: float = v.play_pack_clip(&"Fist_Pump_3")
	check(t2 > 1.0 and v.current_action == &"Fist_Pump_3", "al pedir otra accion se cancela la anterior (accion actual: %s)" % v.current_action)
	await physics_frames(30)
	check(not bool(v.anim_tree.get("parameters/Shot_celebrate_goal/active")), "la accion de Tripo cancelada ya no esta activa")
	check(bool(v.anim_tree.get("parameters/PackShot/active")), "la accion del pack esta activa")
	# arranque a mitad del clip y velocidad
	var t3: float = v.play_pack_clip(&"Soccer_Pass", 2.0, 0.4)
	check_near(t3, (PackLibrary.clip(&"Soccer_Pass").length - 0.4) / 2.0, 0.01, "duracion efectiva con inicio y velocidad: %.3f s" % t3)
	await wait_seconds(t3 + 0.3)
	check(finished.has(&"Soccer_Pass"), "se avisa al terminar la accion (action_finished)")
	check(v.current_action == &"", "sin accion pendiente tras terminar")
	check(v.play_pack_clip(&"no_existe") == 0.0, "un clip inexistente no se reproduce")
	_restore()

func test_situations_resolve_through_the_single_catalog() -> void:
	if _skip_without_pack():
		return
	for sit in [&"celebrate", &"dejected", &"frustrated", &"fall", &"getup", &"slide_tackle", &"trip", &"receive", &"jump", &"jump_running"]:
		var r: Dictionary = AnimationCatalog.resolve(sit, true, 0)
		check(r.get("source", &"") == &"pack" and PackLibrary.has_clip(r["clip"]), "la situacion '%s' se resuelve al pack: %s" % [sit, str(r.get("clip", ""))])
	for sit in [&"celebrate", &"dejected", &"frustrated", &"fall", &"jump"]:
		var r2: Dictionary = AnimationCatalog.resolve(sit, false, 0)
		check(r2.get("source", &"") == &"tripo", "'%s' tiene respaldo de Tripo: %s" % [sit, str(r2.get("clip", ""))])
	check(AnimationCatalog.step_interval(3.6) > 0.1 and AnimationCatalog.step_interval(3.6) < 0.4, "intervalo entre apoyos a 3.6 m/s: %.3f s" % AnimationCatalog.step_interval(3.6))
	check(AnimationCatalog.step_interval(6.8) < AnimationCatalog.step_interval(3.6), "a mas velocidad, apoyos mas seguidos")
	if PackLibrary.keeper() == null:
		note("sin pack_keeper.res (no se versiona): no se comprueba el mapa del arquero")
		return
	for k in AnimationCatalog.KEEPER:
		for clip in AnimationCatalog.KEEPER[k]:
			check(PackLibrary.keeper().has_animation(clip), "arquero preparado: '%s' -> %s" % [k, clip])
