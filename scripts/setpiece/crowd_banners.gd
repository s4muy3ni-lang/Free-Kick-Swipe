class_name CrowdBanners
extends Node3D
## Pancartas («trapos») de la hinchada en las tribunas del estadio de penales y tiros libres (pedido del usuario
## 2026-11-12: «agregá pancartas con letreros con insultos y aliento según el nombre del jugador»). Cada pancarta es un
## trapo de color con su letrero (Label3D) colgado del alambrado, en el muro del frente de la tribuna (delante de todo el
## publico: no lo tapa nadie), mirando a la cancha, que flamea un poco. Cambian con el animo de la tribuna:
##  - calma: aliento con el nombre del jugador del usuario, y en un rincon la hinchada rival con sus cargadas;
##  - gol o atajada del usuario: festejo con su nombre;
##  - fallo del usuario o gol de la CPU: cargadas (de cancha, sin malas palabras).
## Al cambiar, cada trapo se enrolla, cambia el letrero y se vuelve a desplegar.

enum Mood { CALM, GOAL, BOO }

const ALIENTO := ["¡VAMOS {N}!", "¡DALE {N}!", "AGUANTE {N}", "{N} CORAZÓN", "¡{N} SOS DE OTRO PLANETA!",
	"¡{N} NUNCA TE DEJAREMOS!", "¡ARRIBA {N}!", "{N} TE QUEREMOS"]
const GOL := ["¡GOLAZO DE {N}!", "¡{N} SOS DIOS!", "¡{N} ETERNO!", "¡QUÉ GOL, {N}!", "¡{N} RESPETO!",
	"¡{N} CRACK!", "¡{N} DE OTRA GALAXIA!", "¡GRACIAS {N}!"]
const CARGADAS := ["¡{N} PECHO FRÍO!", "¡DEVOLVÉ LA PLATA, {N}!", "¡{N} PATADURA!", "¡{N}, COMPRATE UN ARCO!",
	"¡ANDÁ A LAVAR LOS PLATOS, {N}!", "{N}, LA PELOTA ES REDONDA", "¡{N} TRONCO!", "¡{N} AFLOJÁ CON LA PLAY!"]
## Colores [tela, letras] de cada grupo (hinchada propia en dos colores; la rival en amarillo y negro).
const COLORS_OWN := [[Color(0.08, 0.22, 0.62), Color(0.98, 0.98, 1.0)], [Color(0.96, 0.96, 0.98), Color(0.08, 0.22, 0.62)],
	[Color(0.75, 0.08, 0.1), Color(0.98, 0.98, 1.0)]]
const COLORS_RIVAL := [[Color(0.98, 0.8, 0.1), Color(0.06, 0.06, 0.08)], [Color(0.06, 0.06, 0.08), Color(0.98, 0.8, 0.1)]]
## Letras: alto de una linea (m) y ancho maximo de una linea antes de partir el texto en dos (m); tamaño de un pixel
## de la fuente en el mundo; alto maximo del trapo (el muro mide Stadium11.STAND_FRONT).
const LINE_H := 0.62
const MAX_W := 9.5
const PIXEL := 0.0095
const MAX_H := 2.0

var player: String = ""
var mood: int = Mood.CALM
var spots: Array = []   # [{node, cloth, label, rival, sway}]
var _t: float = 0.0
var _swap: Tween = null

## Nombre que lleva la hinchada en las pancartas: el apodo del perfil, si no el nombre visible o el de usuario; sin
## cuenta, «EL <numero de la camiseta>».
static func player_name() -> String:
	var p: Dictionary = Online.profile() if Online != null else {}
	for k in ["nickname", "display_name", "username"]:
		var v: String = String(p.get(k, "")).strip_edges()
		if v != "":
			return v.to_upper().left(14)
	return "EL %d" % PlayerCustom.number if PlayerCustom.number > 0 else "CAMPEÓN"

## Letreros de un grupo con el nombre puesto.
static func texts(list: Array, name: String) -> Array:
	var out: Array = []
	for t in list:
		out.append(fill(String(t), name))
	return out

## Pone el nombre en un letrero (con el nombre por defecto «EL 10»: «DE EL 10» -> «DEL 10», «¡VAMOS EL 10!» -> «¡VAMOS 10!»).
static func fill(t: String, name: String) -> String:
	var out: String = t.replace("{N}", name).replace("DE EL ", "DEL ")
	for w in ["¡VAMOS ", "¡DALE ", "¡GRACIAS "]:
		out = out.replace(w + "EL ", w)
	return out

## Cuantas pancartas segun el perfil grafico (cada una es tela + letrero: dos dibujos).
static func count_for_density(d: float) -> int:
	return 12 if d >= 0.85 else (8 if d >= 0.6 else 5)

func build(stadium: Stadium11, who: String) -> void:
	player = who
	var hl: float = stadium.half_length() + Stadium11.STAND_GAP
	var hw: float = stadium.half_width() + Stadium11.STAND_GAP
	# Lugares en el alambrado: detras del arco que ataca el usuario (+X) y los costados de esa mitad. [base, afuera]
	var places: Array = []
	for z in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		places.append([Vector3(hl, 0, z), Vector3(1, 0, 0)])
	for x in [12.0, 25.0, 38.0]:
		places.append([Vector3(x, 0, -hw), Vector3(0, 0, -1)])
		places.append([Vector3(x + 4.0, 0, hw), Vector3(0, 0, 1)])
	places.append([Vector3(hl, 0, -36.0), Vector3(1, 0, 0)])
	var n: int = count_for_density(GraphicsSettings.crowd_density() if is_inside_tree() else 1.0)
	# Con menos pancartas, primero las de detras del arco (las que mas se ven).
	places = places.slice(0, n)
	for i in places.size():
		var base: Vector3 = places[i][0]
		var out: Vector3 = places[i][1]
		var node := Node3D.new()
		node.name = "Pancarta%d" % i
		add_child(node)
		# Colgada del muro del frente (su cara da a la cancha a 0,6 m de la linea de la tribuna), arriba en el alambrado.
		var top: Vector3 = base - out * 0.68 + Vector3.UP * (Stadium11.STAND_FRONT - 0.05)
		# Mira a la cancha: el +Z del letrero apunta hacia adentro.
		node.global_transform = Transform3D(Basis.looking_at(out, Vector3.UP), top)
		var cloth := MeshInstance3D.new()
		cloth.name = "Tela"
		cloth.mesh = BoxMesh.new()
		cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cloth.material_override = mat
		node.add_child(cloth)
		var label := Label3D.new()
		label.name = "Letrero"
		label.font_size = int(round(LINE_H / PIXEL))
		label.pixel_size = PIXEL
		label.outline_size = 0
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.double_sided = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector3(0, 0, 0.03)
		cloth.add_child(label)
		# La hinchada rival: un rincon del costado (con pocas pancartas, la ultima; con muy pocas, ninguna).
		var rival: bool = (places.size() >= 12 and (i == 7 or i == 9)) or (places.size() >= 8 and places.size() < 12 and i == places.size() - 1)
		spots.append({"node": node, "cloth": cloth, "label": label, "rival": rival, "sway": float(i) * 1.7})
	_apply_all()

## Cambia el animo: las pancartas bajan, cambian el letrero y vuelven a subir (no hace nada si ya estaba).
func set_mood(m: int) -> void:
	if m == mood:
		return
	mood = m
	if _swap != null and _swap.is_valid():
		_swap.kill()
	if not is_inside_tree():
		_apply_all()
		return
	_swap = create_tween()
	_swap.set_parallel(true)
	for sp in spots:
		_swap.tween_property(sp["node"], "scale:y", 0.04, 0.22)
	_swap.chain().tween_callback(_apply_all)
	_swap.set_parallel(true)
	for sp in spots:
		_swap.tween_property(sp["node"], "scale:y", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Letrero de la pancarta i segun el animo actual.
func text_for(i: int) -> String:
	var s: Dictionary = spots[i]
	var list: Array = ALIENTO
	if mood == Mood.GOAL:
		list = CARGADAS if bool(s["rival"]) else GOL
	elif mood == Mood.BOO:
		list = CARGADAS
	elif bool(s["rival"]):
		list = CARGADAS
	return fill(String(list[(i * 3 + mood * 5) % list.size()]), player)

func _apply_all() -> void:
	for i in spots.size():
		var s: Dictionary = spots[i]
		var txt: String = text_for(i)
		var rival_colors: bool = bool(s["rival"]) or mood == Mood.BOO
		var pal: Array = COLORS_RIVAL[i % COLORS_RIVAL.size()] if rival_colors else COLORS_OWN[i % COLORS_OWN.size()]
		var label: Label3D = s["label"]
		var size: Vector2 = text_size(label, txt)
		var w: float = size.x + 0.8
		var h: float = minf(size.y + 0.35, MAX_H)
		((s["cloth"] as MeshInstance3D).mesh as BoxMesh).size = Vector3(w, h, 0.04)
		# Cuelga desde arriba (el nodo esta en el borde de arriba del muro).
		(s["cloth"] as MeshInstance3D).position = Vector3(0, -h * 0.5, 0)
		((s["cloth"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = pal[0]
		label.text = txt
		label.modulate = pal[1]

## Tamaño del letrero (m) con la fuente real; si no entra en MAX_W lo parte en dos lineas (fija el ancho del Label3D).
func text_size(label: Label3D, txt: String) -> Vector2:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var one: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
	if one.x * PIXEL <= MAX_W:
		label.width = one.x + 8.0
		return one * PIXEL
	var wrap: float = one.x * 0.5 + float(label.font_size) * 1.2
	label.width = wrap
	return font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, wrap, label.font_size) * PIXEL

func _process(delta: float) -> void:
	_t += delta
	# Se mecen: los que las sostienen las mueven un poco.
	for s in spots:
		var ph: float = float(s["sway"])
		# Flamea: el trapo colgado se mueve un poco con el viento (gira sobre su borde de arriba).
		(s["node"] as Node3D).rotation.x = sin(_t * 1.9 + ph) * 0.035
