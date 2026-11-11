extends TestCase
## Personalizacion del jugador (etapa A1): paletas, guardado, cosmeticos bloqueados hasta ganarlos, estilo de golpeo como
## sesgo de la ELECCION del clip (la fisica no cambia), festejo elegido y aplicacion real en el juego (uniforme y numero).

func test_palettes_save_and_locked_cosmetics() -> void:
	PlayerProgress.use_path("user://test_custom_prog.cfg")
	PlayerCustom.use_path("user://test_custom.cfg")
	PlayerCustom.jersey = 4
	PlayerCustom.shorts = 1
	PlayerCustom.number = 7
	PlayerCustom.boots = 6
	check(PlayerCustom.kit()["jersey"] == PlayerCustom.JERSEYS[4], "la camiseta elegida esta en el uniforme")
	check(PlayerCustom.kit()["boots"] == PlayerCustom.BOOTS[0], "los botines dorados bloqueados vuelven a los normales")
	PlayerProgress.cosmetics.append("botines_oro")
	check(PlayerCustom.kit()["boots"] == PlayerCustom.BOOTS[6], "ganado el logro, los dorados se aplican")
	check(PlayerCustom.keeper_kit()["boots"] == PlayerCustom.BOOTS[6], "el arquero del usuario usa los mismos botines")
	check(PlayerCustom.keeper_kit()["jersey"] == SpSettings.USER_KEEPER_KIT["jersey"], "pero conserva la camiseta de arquero")
	PlayerCustom.save_custom()
	PlayerCustom.jersey = 0
	PlayerCustom.number = 10
	PlayerCustom.load_custom(true)
	check(PlayerCustom.jersey == 4 and PlayerCustom.number == 7, "la personalizacion se guarda y se recupera")
	PlayerCustom.restore_after_tests()

func test_style_biases_clip_choice_only() -> void:
	PlayerCustom.use_path("user://test_custom.cfg")
	var p := ShotParams.new()
	p.kind = ShotCatalog.Kind.NORMAL
	p.power = 0.7
	p.velocity = Vector3(20, 3, 1)
	var v0: Vector3 = p.velocity
	PlayerCustom.style = PlayerCustom.Style.POTENTE
	PlayerCustom.bias(p)
	check(p.kind == ShotCatalog.Kind.POWER and p.velocity == v0, "estilo potente: golpeo potente, la salida no cambia")
	p.kind = ShotCatalog.Kind.NORMAL
	PlayerCustom.style = PlayerCustom.Style.COLOCADO
	PlayerCustom.bias(p)
	check(p.kind == ShotCatalog.Kind.PLACED, "estilo colocado: interior")
	PlayerCustom.style = PlayerCustom.Style.CON_EFECTO
	PlayerCustom.bias(p)
	check(p.curled, "estilo con efecto: prefiere los golpeos con comba")
	PlayerCustom.style = PlayerCustom.Style.NATURAL
	PlayerCustom.run_style = 1
	PlayerCustom.bias(p)
	check(p.prefer_short, "carrera corta: prefiere golpeos casi sin carrera")
	PlayerCustom.run_style = 0
	PlayerCustom.restore_after_tests()

func test_celebrations_are_valid_clips() -> void:
	var list: Array[StringName] = PlayerCustom.celebrations()
	check(list.size() >= 4, "hay al menos 4 festejos para elegir (%d)" % list.size())
	for id in list:
		var a: Animation = SpClips.anim(id)
		check(a != null and a.loop_mode == Animation.LOOP_NONE, "%s no es un bucle" % id)
	PlayerCustom.use_path("user://test_custom.cfg")
	PlayerCustom.celebration = 5
	check(PlayerCustom.celebration_clip() == &"", "el festejo 5 bloqueado cae en aleatorio")
	PlayerProgress.use_path("user://test_custom_prog.cfg")
	PlayerProgress.cosmetics.append("festejo_5")
	check(PlayerCustom.celebration_clip() == list[4], "ganado el logro, el festejo 5 se aplica")
	PlayerCustom.celebration = 1
	check(PlayerCustom.celebration_clip() == list[0], "el festejo 1 esta abierto")
	PlayerCustom.restore_after_tests()

func test_customization_shows_up_in_the_game() -> void:
	PlayerProgress.use_path("user://test_custom_prog.cfg")
	PlayerCustom.use_path("user://test_custom.cfg")
	PlayerCustom.jersey = 6
	PlayerCustom.number = 23
	PlayerCustom.celebration = 1
	PlayerCustom.follow_style = 1
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	spawn(game)
	await physics_frames(5)
	var mat: ShaderMaterial = null
	for mi in game.user_shooter.actor.model.find_children("*", "MeshInstance3D", true, false):
		mat = (mi as MeshInstance3D).material_override
		break
	var want: Color = PlayerCustom.JERSEYS[6]
	var got: Variant = mat.get_shader_parameter("jersey_color") if mat != null else null
	var same: bool = got != null and Vector3(Color(got).r - want.r, Color(got).g - want.g, Color(got).b - want.b).length() < 0.01
	check(same, "el tirador del usuario viste la camiseta elegida")
	check(game.user_shooter.actor._number != null and game.user_shooter.actor._number.text == "23", "lleva el numero elegido en la espalda")
	check(game.user_keeper.actor._number != null and game.user_keeper.actor._number.text == "23", "el arquero del usuario tambien")
	check(game.user_shooter.celebration == PlayerCustom.celebrations()[0], "el festejo elegido queda cargado")
	check(game.user_shooter.follow_run, "y la opcion de acompañar el tiro")
	await physics_frames(10)
	var lbl: Label3D = game.user_shooter.actor._number
	var sp: Vector3 = game.user_shooter.actor.bone_world("mixamorig_Spine1")
	var behind: float = (lbl.global_position - sp).dot(-game.user_shooter.actor.facing())
	note("numero: %.2f m detras de la columna" % behind)
	check(behind > 0.1, "el numero queda en la espalda (detras de la columna)")
	# El festejo elegido se usa al gritar el gol.
	game.user_shooter.state = SpShooter.State.AFTER
	game.user_shooter.react(true)
	check(game.user_shooter.actor.clip_id == PlayerCustom.celebrations()[0], "festeja con el clip elegido")
	cleanup()
	PlayerCustom.restore_after_tests()
