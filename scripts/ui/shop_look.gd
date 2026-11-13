class_name ShopLook
extends RefCounted
## Como se ve cada objeto de la tienda (pedido del usuario: «no quiero una tienda que parezca un listado de letras…
## mostrar como se verian en el jugador»). Lo usan la herramienta que dibuja las imagenes de la tienda
## (tools/ui/make_shop_images.gd, con el modelo real del jugador y el balon real) y la vista previa en vivo de la tienda.
##
## - Indumentaria (camiseta, short, medias, botines, estilo de numero): el uniforme de muestra con el objeto puesto
##   (kit_for), sobre el cuerpo del jugador;
## - balones: el diseño (BallSkins) sobre la pelota del juego;
## - consumibles y extras: un icono con su efecto exacto (effect_text).

const IMAGES := "res://assets/shop/items"

## Uniforme de muestra (celeste y blanco con botines negros; piel y pelo intermedios).
static func showcase_kit() -> Dictionary:
	return {"jersey": PlayerCustom.JERSEYS[0], "jersey2": PlayerCustom.JERSEYS[2], "shorts": PlayerCustom.SHORTS[0],
		"socks": PlayerCustom.SOCKS[0], "boots": PlayerCustom.BOOTS[1], "skin": PlayerCustom.SKINS[2], "hair": PlayerCustom.HAIRS[1],
		"jersey_pattern": 0, "shorts_pattern": 0, "socks_pattern": 0, "sock_height": 0}

## El uniforme base con el objeto it puesto.
static func kit_for(it: Dictionary, base: Dictionary) -> Dictionary:
	var k: Dictionary = base.duplicate()
	var d: Dictionary = it.get("data", {}) if it.get("data") is Dictionary else {}
	match String(it.get("kind", "")):
		"jersey":
			k["jersey_pattern"] = int(PlayerCustom.JERSEY_PATTERNS.get(String(d.get("pattern", "liso")), 0))
			if d.get("colors") is Array and (d["colors"] as Array).size() == 2:
				k["jersey"] = PlayerCustom.JERSEYS[int(d["colors"][0]) % PlayerCustom.JERSEYS.size()]
				k["jersey2"] = PlayerCustom.JERSEYS[int(d["colors"][1]) % PlayerCustom.JERSEYS.size()]
		"shorts":
			# Short azul de muestra: los ribetes y franjas blancos se ven.
			k["shorts"] = PlayerCustom.SHORTS[2]
			k["shorts_pattern"] = int(PlayerCustom.SHORTS_PATTERNS.get(String(d.get("pattern", "liso")), 0))
			if d.has("color"):
				k["shorts"] = PlayerCustom.SHORTS[int(d["color"]) % PlayerCustom.SHORTS.size()]
		"socks":
			k["socks_pattern"] = int(PlayerCustom.SOCKS_PATTERNS.get(String(d.get("pattern", "liso")), 0))
			if d.has("height"):
				k["sock_height"] = int(d["height"])
			if d.has("color"):
				k["socks"] = PlayerCustom.SOCKS[int(d["color"]) % PlayerCustom.SOCKS.size()]
		"boots":
			k.merge(BootsCatalog.style(String(it.get("id", "")), PlayerCustom.BOOTS[clampi(int(d.get("color", 1)), 0, PlayerCustom.BOOTS.size() - 1)]), true)
	return k

static func image_path(id: String) -> String:
	return "%s/%s.webp" % [IMAGES, id]

static func image(id: String) -> Texture2D:
	var p: String = image_path(id)
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

## Que hace el objeto, sin inventar: los consumibles dicen su efecto exacto; lo demas es solo estetico.
static func effect_text(it: Dictionary) -> String:
	var d: Dictionary = it.get("data", {}) if it.get("data") is Dictionary else {}
	match String(it.get("kind", "")):
		"consumable":
			match String(d.get("boost", "")):
				"xp_x2":
					return "Duplica la experiencia (XP) que ganás durante %d minutos." % int(d.get("minutes", 60))
				"coins_x2":
					return "Duplica las monedas de tus próximas %d partidas." % int(d.get("matches", 3))
				"streak_shield":
					return "Si perdés tu próxima partida online, tu racha de victorias no se corta (1 partida)."
			return "Se usa una vez."
		"name_change":
			return "Permite cambiar tu nombre de usuario una vez."
		"emote":
			return "Reacciones para el chat de las partidas online."
		"celebration":
			return "Festejo de gol de tu jugador. Solo estético."
	return "Solo estético: no cambia el tiro, la física ni tus atributos."

## Que parte del jugador muestra la imagen o la vista previa: [altura que se mira (m), distancia (m), angulo (grados;
## 0 = de frente, 180 = de espaldas)].
static func camera_for(kind: String) -> Array:
	match kind:
		"jersey":
			return [1.22, 1.45, 28.0]
		"shorts":
			return [0.74, 1.05, 30.0]
		"socks":
			return [0.32, 1.0, 35.0]
		"boots":
			return [0.1, 0.95, 55.0]
		"number_style":
			return [1.25, 1.35, 180.0]
		"celebration":
			return [0.95, 3.0, 20.0]
	return [1.0, 2.6, 25.0]
