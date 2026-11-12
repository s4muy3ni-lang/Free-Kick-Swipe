extends TestCase
## Pancartas de la hinchada (pedido del usuario 2026-11-12: «agregá pancartas con letreros con insultos y aliento según el
## nombre del jugador»): trapos colgados del alambrado con el nombre del jugador del usuario; aliento en calma, festejo con
## su gol, cargadas con su fallo; un rincon de hinchada rival con cargadas.

func _game() -> SetPieceGame:
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	return game

func _texts(b: CrowdBanners) -> Array:
	var out: Array = []
	for s in b.spots:
		out.append((s["label"] as Label3D).text)
	return out

func test_texts_carry_the_player_name() -> void:
	for list in [CrowdBanners.ALIENTO, CrowdBanners.GOL, CrowdBanners.CARGADAS]:
		for t in CrowdBanners.texts(list, "JUANCHO"):
			check(String(t).contains("JUANCHO"), "«%s» lleva el nombre" % t)
	check(CrowdBanners.fill("¡GOLAZO DE {N}!", "EL 10") == "¡GOLAZO DEL 10!", "«de el 10» se escribe «del 10»")
	var prev: int = PlayerCustom.number
	PlayerCustom.number = 7
	if String(Online.profile().get("nickname", "")) == "" and String(Online.profile().get("display_name", "")) == "" and String(Online.profile().get("username", "")) == "":
		check(CrowdBanners.player_name() == "EL 7", "sin cuenta: el numero de la camiseta (%s)" % CrowdBanners.player_name())
	PlayerCustom.number = prev
	check(CrowdBanners.count_for_density(1.0) > CrowdBanners.count_for_density(0.4), "menos pancartas en los perfiles bajos")

func test_banners_hang_on_the_fence_and_follow_the_mood() -> void:
	var game := _game()
	await physics_frames(5)
	var b: CrowdBanners = game.stadium.banners
	check(b != null and b.spots.size() >= 5, "hay pancartas en las tribunas (%d)" % (b.spots.size() if b != null else 0))
	var name: String = b.player
	var aliento: Array = CrowdBanners.texts(CrowdBanners.ALIENTO, name)
	var gol: Array = CrowdBanners.texts(CrowdBanners.GOL, name)
	var cargadas: Array = CrowdBanners.texts(CrowdBanners.CARGADAS, name)
	var own: int = 0
	var rival: int = 0
	for i in b.spots.size():
		var t: String = _texts(b)[i]
		if bool(b.spots[i]["rival"]):
			rival += 1 if cargadas.has(t) else 0
		else:
			own += 1 if aliento.has(t) else 0
		# Cuelgan del muro del frente y miran a la cancha.
		var node: Node3D = b.spots[i]["node"]
		var to_center: Vector3 = Vector3(-node.global_position.x, 0, -node.global_position.z).normalized()
		check(node.global_transform.basis.z.dot(to_center) > 0.3, "pancarta %d: mira a la cancha" % i)
		var cloth: MeshInstance3D = b.spots[i]["cloth"]
		var size: Vector3 = (cloth.mesh as BoxMesh).size
		check(size.y <= CrowdBanners.MAX_H + 0.01 and node.global_position.y <= Stadium11.STAND_FRONT, "pancarta %d: entra en el alambrado" % i)
	note("en calma: %s" % str(_texts(b)))
	check(own + rival == b.spots.size(), "en calma: aliento propio y cargadas de la hinchada rival")
	game.crowd_react(true, "goal")
	await wait_seconds(1.0)
	var goals: int = 0
	for t in _texts(b):
		goals += 1 if gol.has(t) else 0
	note("con el gol: %s" % str(_texts(b)))
	check(goals >= b.spots.size() - 2, "con el gol: festejo con su nombre")
	game.crowd_react(false, "miss")
	await wait_seconds(1.0)
	var taunts: int = 0
	for t in _texts(b):
		taunts += 1 if cargadas.has(t) else 0
	note("con el fallo: %s" % str(_texts(b)))
	check(taunts == b.spots.size(), "con el fallo: cargadas")
	for s in b.spots:
		check(is_equal_approx((s["node"] as Node3D).scale.y, 1.0), "los trapos vuelven a quedar desplegados")
		break
	cleanup()
