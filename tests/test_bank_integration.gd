extends TestCase
## Auditoria del banco completo (tools/json_anim/analyze_bank.py): el inventario cubre los 2 022 clips, las reasignaciones
## (ClipRolesOverlay) entran de verdad en la seleccion de su sistema, las transiciones que el codigo pide por nombre tienen
## clip y los clips integrados se reproducen (centros, esquivar una barrida, giros desde parado, arranque).

const INVENTORY := "res://docs/fases/E2_inventario_banco.csv"

func _mode4() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()

func _restore() -> void:
	Tuning.gameplay_mode = 1
	PackLibrary.reload()

func _skip_if_missing() -> bool:
	if not ResourceLoader.exists(PackLibrary.JSON_FIELD_PATH):
		skip("no existe assets/animations/json_clips.res")
		return true
	return false

func test_inventory_covers_the_whole_bank() -> void:
	var f := FileAccess.open(INVENTORY, FileAccess.READ)
	check(f != null, "existe el inventario %s" % INVENTORY)
	if f == null:
		return
	var header: PackedStringArray = f.get_csv_line()
	var rows: int = 0
	var files := {}
	var useful := {"si": 0, "no": 0, "pendiente": 0}
	var no_reason: int = 0
	while not f.eof_reached():
		var r: PackedStringArray = f.get_csv_line()
		if r.size() < header.size():
			continue
		rows += 1
		files[r[0]] = true
		useful[r[header.find("util")]] = int(useful.get(r[header.find("util")], 0)) + 1
		if r[header.find("motivo")].strip_edges() == "":
			no_reason += 1
	note("inventario: %d entradas, %d archivos; util %s" % [rows, files.size(), str(useful)])
	check(files.size() == 2022, "los 2 022 JSON del banco estan en el inventario (%d)" % files.size())
	check(rows == 2024, "una fila por clip del juego (2 024 entradas)")
	check(no_reason == 0, "cada clip tiene su motivo de inclusion o exclusion (%d sin motivo)" % no_reason)

func test_reassigned_clips_enter_their_system() -> void:
	if _skip_if_missing():
		return
	_mode4()
	var missing: Array[String] = []
	for id in ClipRolesOverlay.ROLE:
		var role: StringName = ClipRolesOverlay.ROLE[id]
		if not PackLibrary.by_role(role).has(id):
			missing.append(String(id))
		elif PackLibrary.has_clip(StringName(String(id) + "_mirror")) and not PackLibrary.by_role(role).has(StringName(String(id) + "_mirror")):
			missing.append(String(id) + "_mirror")
	note("reasignados %d; fuera de su rol: %s" % [ClipRolesOverlay.ROLE.size(), str(missing)])
	check(ClipRolesOverlay.ROLE.size() > 0 and missing.is_empty(), "cada clip reasignado (y su espejo) esta en la seleccion de su rol")
	_restore()

func test_transitions_requested_by_name_have_a_clip() -> void:
	if _skip_if_missing():
		return
	_mode4()
	var resolved: StringName = PackLibrary.resolve(Footballer.IDLE_TO_SPRINT)
	note("Idle_To_Sprint -> %s" % resolved)
	check(resolved != &"" and PackLibrary.has_clip(Footballer.IDLE_TO_SPRINT), "el arranque desde parado tiene clip (antes no hacia nada)")
	var turns: Array[StringName] = PackLibrary.by_role(&"turn_start")
	check(turns.size() > 0, "giros desde parado disponibles (%d)" % turns.size())
	_restore()

func test_missed_slide_is_jumped_with_an_avoid_clip() -> void:
	if _skip_if_missing():
		return
	_mode4()
	var ctx: MatchContext = await make_match(Vector3(5, 0.12, 0))
	var p: Footballer = add_player(ctx, 0, Vector3.ZERO, 60, ScriptedInput.new(), true)
	await physics_frames(3)
	var start_pos: Vector3 = p.global_position
	var ok: bool = p.actions.avoid_tackle(Vector3(0, 0, 1))
	var clip: StringName = p.actions.motion.clip
	var role: String = String(PackLibrary.meta(clip).get("role", ""))
	await physics_frames(20)
	note("esquivar: %s (rol %s), nivel del arbitro %d" % [clip, role, p.arbiter.level])
	check(ok and role == "avoid", "la barrida fallida se salta con un clip de esquivar")
	check(p.arbiter.level == ActionArbiter.Level.BODY, "esquivar pasa por el arbitro (nivel de cuerpo)")
	await physics_frames(120)
	check(not p.actions.active(), "termina y vuelve la marcha")
	note("recorrido %.2f m" % KickModel.flat(p.global_position - start_pos).length())
	cleanup()
	_restore()

## Las transiciones de la marcha que el codigo pide por su nombre del pack se ven en el juego del modo 4: arranque desde
## parado a sprint (Idle_To_Sprint) y parada agotado (Running_Tired, alternativa con las manos en la cintura).
func test_gait_transitions_play_in_mode_4() -> void:
	if _skip_if_missing():
		return
	_mode4()
	var ctx: MatchContext = await make_match(Vector3(15.0, 0.11, 9.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-10.0, 0.0, 0.0), 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(10)
	var seen := {}
	var start_ids: Array = [Footballer.IDLE_TO_SPRINT, PackLibrary.resolve(Footballer.IDLE_TO_SPRINT)]
	var tired_ids: Array = [Footballer.TIRED_STOP, PackLibrary.resolve(Footballer.TIRED_STOP)]
	src.move = Vector2(1, 0)
	src.sprint = true
	for i in 60:
		await tree.physics_frame
		if p.visual.current_action != &"":
			seen[p.visual.current_action] = true
	src.move = Vector2.ZERO
	src.sprint = false
	for i in 150:
		p.locomotion.exhausted = true
		p.locomotion.stamina = 0.05
		await tree.physics_frame
		if p.visual.current_action != &"":
			seen[p.visual.current_action] = true
	note("poses vistas: %s" % str(seen.keys()))
	check(start_ids.any(func(c: StringName) -> bool: return seen.has(c)), "arranque a sprint desde parado con su clip")
	check(tired_ids.any(func(c: StringName) -> bool: return seen.has(c)), "parada agotado con su clip")
	check(PackLibrary.has_clip(Footballer.BLOCK_CLIP), "el salto de bloqueo (Defender_2) tiene clip")
	cleanup()
	_restore()

## Los clips de balon parado cuyo pie no llega a la pelota o sin lanzamiento (medido) quedan fuera de la seleccion del saque, y ningun nombre
## del pack (ni el de su alias original, ni los repartos de vary_aliases) los elige.
func test_set_piece_clips_that_miss_the_ball_are_never_chosen() -> void:
	if _skip_if_missing():
		return
	_mode4()
	var missing: Array = []
	for id in ClipRolesOverlay.ROLE:
		if ClipRolesOverlay.ROLE[id] != &"setpiece_miss":
			continue
		missing.append(id)
		for role in [&"setpiece_pass", &"setpiece_shot", &"setpiece_lob", &"throw_in"]:
			check(not PackLibrary.by_role(role).has(id), "%s fuera de %s" % [id, role])
	var chosen := {}
	# Antes de cualquier reparto: el alias original (soccer_penalty_kick era un clip excluido) ya apunta a otro del rol.
	for a in [&"strike_foward_jog", &"soccer_penalty_kick", &"Chip", &"throw_in"]:
		chosen[PackLibrary.resolve(a)] = true
	for i in 30:
		PackLibrary.vary_aliases()
		for a in [&"strike_foward_jog", &"soccer_penalty_kick", &"Chip", &"throw_in"]:
			chosen[PackLibrary.resolve(a)] = true
	var bad: Array = chosen.keys().filter(func(c: StringName) -> bool: return missing.has(c))
	note("excluidos %s; elegidos en 30 repartos: %d clips" % [str(missing), chosen.size()])
	check(missing.size() == 7 and bad.is_empty(), "ningun saque usa un clip excluido (%s)" % str(bad))
	_restore()
