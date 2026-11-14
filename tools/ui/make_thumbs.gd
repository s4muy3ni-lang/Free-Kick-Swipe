extends Node
## Miniaturas de cada modo para los menus (pedido del usuario: «cada modo y cada desafio debe tener una imagen de como
## es; esta pelado, pura letra»). Abre cada juego con su camara real, oculta el HUD, captura y guarda un JPG chico en
## assets/ui/thumbs/<id>.jpg (400 x 225): los minijuegos del arcade (su primer nivel), los grupos de desafios de arco
## (su primer desafio), el penal, el tiro libre y los ejercicios de la academia por tipo.
## Uso: xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --resolution 1280x720 --path . \
##   res://tools/ui/make_thumbs.tscn   [THUMBS_ONLY=id1,id2]

const OUT := "res://assets/ui/thumbs"
const SIZE := Vector2i(400, 225)
## Nivel que muestra la miniatura cuando el primero no representa el juego (Rescate: los niveles de mecanismos a
## pelotazos empiezan en el 5).
const THUMB_LEVEL := {"rescate": 10}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only: PackedStringArray = OS.get_environment("THUMBS_ONLY").split(",", false)
	var jobs: Array = []
	for c in MinigameCatalog.categories():
		for it in c.get("items", []):
			if String(it.get("type", "")) == "game":
				jobs.append(["game", String(it["game"])])
			else:
				jobs.append(["arena", String(it["id"])])
	jobs.append(["setpiece", "penales"])
	jobs.append(["setpiece", "tiro_libre"])
	for j in jobs:
		if not only.is_empty() and not only.has(String(j[1])):
			continue
		await _shoot(j)
	get_tree().quit()

func _shoot(j: Array) -> void:
	var kind: String = j[0]
	var id: String = j[1]
	var node: Node
	if kind == "game":
		var d: Dictionary = MinigameCatalog.level(id, int(THUMB_LEVEL.get(id, 1)))
		d["seed"] = 3
		d["practice"] = true
		Minigame.next_def = d
		var g: Minigame = (load(String(d["scene"])) as PackedScene).instantiate()
		g.fast = true
		add_child(g)
		node = g
		for i in 30:
			await get_tree().process_frame
		g._frame_camera(true)
	else:
		if kind == "arena":
			var group: Dictionary = {}
			for c in MinigameCatalog.categories():
				for it in c.get("items", []):
					if String(it.get("id", "")) == id:
						group = it
			if group.is_empty() or (group["ids"] as Array).is_empty():
				return
			SetPieceGame.next_mode = SetPieceGame.Mode.CHALLENGE
			SetPieceGame.next_challenge = ChallengeCatalog.at_difficulty(ChallengeCatalog.by_id(String(group["ids"][0])), 1)
			SetPieceGame.next_practice = true
		else:
			SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY if id == "penales" else SetPieceGame.Mode.FREE_KICK
		var sg: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
		sg.fast = true
		add_child(sg)
		node = sg
		for i in 40:
			await get_tree().process_frame
		if id == "tiro_libre":
			sg._setup_free_kick()
			for i in 30:
				await get_tree().process_frame
	# Sin HUD: solo la escena.
	for cl in node.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	for i in 25:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	var path: String = ProjectSettings.globalize_path("%s/%s.jpg" % [OUT, id])
	img.save_jpg(path, 0.82)
	print("miniatura: ", path)
	node.queue_free()
	for i in 3:
		await get_tree().process_frame
