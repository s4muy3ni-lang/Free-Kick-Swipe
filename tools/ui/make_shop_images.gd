extends Node3D
## Imagenes de la tienda (pedido del usuario: «cada producto debe tener una representacion visual propia… botines:
## mostrar el botin; balones: mostrar el balon; camisetas: el diseño de la camiseta»). Dibuja cada objeto del catalogo
## con el modelo real del jugador (el uniforme de muestra con el objeto puesto, ShopLook.kit_for) o con la pelota real
## (BallSkins), con la camara en la parte que corresponde (ShopLook.camera_for), y guarda assets/shop/items/<id>.webp
## (256 x 256). Los consumibles y extras llevan un icono con su efecto.
## Uso: xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --resolution 512x512 --path . \
##   res://tools/ui/make_shop_images.tscn   [SHOP_ONLY=id1,id2]

const OUT := "res://assets/shop/items"
const SIZE := 256

var cam: Camera3D
var _tmp: Array[Node] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.11, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.68)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 35, 0)
	key.light_energy = 1.25
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.7, 0.8, 1.0)
	add_child(rim)
	cam = Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	cam.current = true
	var only: PackedStringArray = OS.get_environment("SHOP_ONLY").split(",", false)
	var seed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/online/seed.json"))
	for it in seed["catalog_items"]:
		if not only.is_empty() and not only.has(String(it["id"])):
			continue
		await _render(it)
	get_tree().quit()

func _clear() -> void:
	for n in _tmp:
		if is_instance_valid(n):
			n.queue_free()
	_tmp.clear()

func _render(it: Dictionary) -> void:
	_clear()
	await get_tree().process_frame
	var kind: String = String(it["kind"])
	match kind:
		"ball":
			var b: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
			b.freeze = true
			add_child(b)
			_tmp.append(b)
			b.global_position = Vector3(0, 0.11, 0)
			b.rotation_degrees = Vector3(15, 30, 10)
			b.set_skin(BallSkins.design_of(String(it["id"]), [it]))
			cam.global_position = Vector3(0.32, 0.26, 0.42)
			cam.look_at(Vector3(0, 0.11, 0))
		"consumable", "emote", "name_change":
			_icon_card(it)
		_:
			var a := SpActor.new()
			add_child(a)
			_tmp.append(a)
			a.build(ShopLook.kit_for(it, ShopLook.showcase_kit()))
			a.global_position = Vector3.ZERO
			a.set_facing(Vector3(0, 0, 1))
			if kind == "number_style":
				a.number_style = String(it["id"])
				a.set_back_number(int((it.get("data", {}) as Dictionary).get("only", [10])[0]) if (it.get("data", {}) as Dictionary).has("only") else 10)
			if kind == "accessory":
				a.set_accessories([String(it["id"])])
			var clip: StringName = &""
			if kind == "celebration":
				var cs: Array[StringName] = PlayerCustom.celebrations()
				var idx: int = int((it.get("data", {}) as Dictionary).get("index", 1)) - 1
				if idx >= 0 and idx < cs.size():
					clip = cs[idx]
			if clip != &"":
				a.play_here(clip, 0.0)
			else:
				var idles: Array[StringName] = SpClips.by_role(&"idle_ready", false)
				if not idles.is_empty():
					a.play_loop(idles[0], 0.0)
			var c: Array = ShopLook.camera_for(kind)
			var target := Vector3(0, float(c[0]), 0)
			var ang: float = deg_to_rad(float(c[2]))
			cam.global_position = target + Vector3(sin(ang), 0.18, cos(ang)).normalized() * float(c[1])
			cam.look_at(target)
	for i in (40 if kind == "celebration" else 8):
		await get_tree().process_frame
	if kind == "celebration" and not _tmp.is_empty() and _tmp[0] is SpActor:
		# El festejo se mueve (movimiento de raiz): la camara lo sigue hasta donde quedo.
		var who: SpActor = _tmp[0]
		var tgt: Vector3 = who.global_position + Vector3(0, 0.95, 0)
		cam.global_position = tgt + Vector3(0.9, 0.35, 2.8)
		cam.look_at(tgt)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var side: int = mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	img.save_webp(ProjectSettings.globalize_path("%s/%s.webp" % [OUT, String(it["id"])]), true, 0.86)
	print("imagen: ", it["id"])

## Icono para lo que no se viste: fondo del color de la rareza, simbolo grande y el efecto en pocas palabras.
func _icon_card(it: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_tmp.append(layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = {"comun": Color(0.18, 0.22, 0.3), "raro": Color(0.1, 0.25, 0.5), "epico": Color(0.32, 0.12, 0.45),
		"legendario": Color(0.45, 0.3, 0.05)}.get(String(it.get("rarity", "comun")), Color(0.18, 0.22, 0.3))
	layer.add_child(bg)
	var d: Dictionary = it.get("data", {}) if it.get("data") is Dictionary else {}
	var big: String = "?"
	var small: String = String(it["name"])
	var icon: String = "tienda"
	match String(it["kind"]):
		"consumable":
			match String(d.get("boost", "")):
				"xp_x2":
					big = "XP ×2"
					small = "%d minutos" % int(d.get("minutes", 60))
					icon = "temporada"
				"coins_x2":
					big = "×2"
					small = "monedas · %d partidas" % int(d.get("matches", 3))
					icon = "tienda"
				"streak_shield":
					big = "RACHA"
					small = "escudo · 1 partida"
					icon = "desafios"
		"emote":
			big = "JAJA · GG"
			small = "%d reacciones" % (d.get("set", []) as Array).size()
			icon = "online"
		"name_change":
			big = "ABC → XYZ"
			small = "cambio de nombre"
			icon = "perfil"
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	layer.add_child(box)
	# El lienzo de la interfaz se escala a la ventana (base 1280 x 720): medidas grandes para una imagen de 512.
	var ic := MenuIcon.new(icon, Color(1, 0.86, 0.35), 340)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	for t in [[big, 150, Color(1, 0.9, 0.5)], [small, 80, Color(0.92, 0.94, 1.0)]]:
		var l := Label.new()
		l.text = String(t[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", int(t[1]))
		l.add_theme_color_override("font_color", t[2])
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 22)
		box.add_child(l)
