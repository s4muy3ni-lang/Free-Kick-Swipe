class_name ShopPreview
extends SubViewportContainer
## Vista previa 3D de la tienda (pedido del usuario: «al seleccionar un objeto, permitir visualizarlo antes de comprarlo;
## para los objetos equipables, mostrar como se verian en el jugador»): un mundo propio y chico (SubViewport) con el
## jugador del usuario vistiendo el objeto (ShopLook.kit_for sobre su uniforme actual) o el balon girando con su diseño.
## Se gira arrastrando el dedo. Un solo visor (no uno por tarjeta): liviano para Android.

const SIZE := Vector2i(440, 440)

var viewport: SubViewport
var cam: Camera3D
var actor: SpActor = null
var ball: Ball = null
var yaw: float = 0.0
var _target := Vector3(0, 1.0, 0)
var _dist: float = 2.6
var _drag: bool = false
## Angulo de la camara del tipo de objeto (ShopLook.camera_for); el arrastre le suma yaw.
var _angle: float = 25.0

func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(SIZE)
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.07, 0.09, 0.17)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.68)
	e.ambient_light_energy = 0.7
	env.environment = e
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 35, 0)
	key.light_energy = 1.2
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.55
	viewport.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 35.0
	viewport.add_child(cam)
	cam.current = true

## Muestra el objeto it sobre el uniforme base (el del usuario) con sus accesorios puestos.
func show_item(it: Dictionary, base_kit: Dictionary, accessories: Array = [], number: int = 10) -> void:
	if is_instance_valid(actor):
		actor.queue_free()
	if is_instance_valid(ball):
		ball.queue_free()
	actor = null
	ball = null
	var kind: String = String(it.get("kind", ""))
	yaw = 0.0
	if kind == "ball":
		ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
		ball.freeze = true
		viewport.add_child(ball)
		ball.global_position = Vector3(0, 0.11, 0)
		ball.set_skin(BallSkins.design_of(String(it.get("id", "")), [it]))
		_target = Vector3(0, 0.11, 0)
		_dist = 0.55
		_angle = 25.0
		_place_cam()
		return
	actor = SpActor.new()
	viewport.add_child(actor)
	actor.build(ShopLook.kit_for(it, base_kit))
	actor.set_facing(Vector3(0, 0, 1))
	var acc: Array = accessories.duplicate()
	if kind == "accessory" and not acc.has(String(it["id"])):
		acc.append(String(it["id"]))
	actor.set_accessories(acc)
	if kind == "number_style":
		actor.number_style = String(it["id"])
	actor.set_back_number(number)
	var idles: Array[StringName] = SpClips.by_role(&"idle_ready", false)
	if kind == "celebration":
		var cs: Array[StringName] = PlayerCustom.celebrations()
		var idx: int = int((it.get("data", {}) as Dictionary).get("index", 1)) - 1
		if idx >= 0 and idx < cs.size():
			actor.play_loop(cs[idx], 0.0)
	elif not idles.is_empty():
		actor.play_loop(idles[0], 0.0)
	var c: Array = ShopLook.camera_for(kind)
	_target = Vector3(0, float(c[0]), 0)
	_dist = float(c[1])
	_angle = float(c[2])
	_place_cam()

func _place_cam() -> void:
	var a: float = deg_to_rad(_angle) + yaw
	cam.global_position = _target + Vector3(sin(a), 0.18, cos(a)).normalized() * _dist
	cam.look_at(_target)

func _process(delta: float) -> void:
	if ball != null:
		ball.rotate_y(delta * 0.8)

## Arrastrar gira la vista alrededor del jugador (o del balon).
func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		_drag = e.pressed if e is InputEventScreenTouch else ((e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
		accept_event()
	elif (e is InputEventScreenDrag) or (e is InputEventMouseMotion and _drag):
		var dx: float = (e as InputEventScreenDrag).relative.x if e is InputEventScreenDrag else (e as InputEventMouseMotion).relative.x
		yaw -= dx * 0.012
		_place_cam()
		accept_event()
