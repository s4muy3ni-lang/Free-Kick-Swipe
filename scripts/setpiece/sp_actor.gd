class_name SpActor
extends Node3D
## Tiros libres y penales: un futbolista animado (humano JSON + clips del banco JSON) con movimiento de raiz.
##
## - Clips de una vez (golpeos, atajadas, saltos, festejos): el cuerpo sigue la raiz del clip en el marco del clip
##   (origen `frame_origin` mirando a `frame_facing`), como el banco de pruebas y el partido (ActionMotion).
## - Bucles (reposo, trote, espera del arquero): en el sitio; el controlador mueve el cuerpo (move_to) y el bucle se
##   reproduce a la velocidad que corresponde al desplazamiento (sin patinar).
## - Colision opcional (barrera, jugadores sueltos): una capsula cinematica que sigue a la cadera (si salta, la pelota puede
##   pasar por debajo) en la capa de jugadores de la pelota (Ball.LAYER_PLAYERS): la pelota choca de verdad.
##
## Convencion: el cuerpo mira a +X local; la derecha es +Z local. rotation.y = SpClips.yaw_of(facing).

signal clip_finished(id: StringName)

const BODY := "res://assets/characters/json/json_human.scn"
## Escala del humano en el juego (los metadatos de los clips estan en metros de juego).
const BODY_SCALE := 1.75
const BLEND := 0.22
const HIPS := "mixamorig_Hips"
const HEAD := "mixamorig_Head"
const HAND_L := "mixamorig_LeftHand"
const HAND_R := "mixamorig_RightHand"
const TOE_L := "mixamorig_LeftToeBase"
const TOE_R := "mixamorig_RightToeBase"

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var model: Node3D
## Rol en la escena (tirador, arquero, barrera, atacante, defensor): solo informativo.
var role: StringName = &""
var team: int = 0

## Clip en curso y su marco.
var clip_id: StringName = &""
var clip_meta: Dictionary = {}
var clip_speed: float = 1.0
var looping: bool = false
var frame_origin := Vector3.ZERO
var frame_facing := Vector3(1, 0, 0)
var _clip_started_at: float = 0.0
var _clip_time: float = 0.0
var _finished_emitted: bool = true

## Desplazamiento procedural (bucles de marcha): destino, velocidad y mirada.
var _move_target := Vector3.ZERO
var _move_speed: float = 0.0
var _moving: bool = false
var _move_face := Vector3.ZERO
var _move_loop: StringName = &""
var _move_natural: float = 3.0
## Giro suave hacia una direccion (rad/s) cuando no hay clip con raiz.
var turn_rate: float = 6.0
var _face_target := Vector3.ZERO

## Reposo propio (bucle en el sitio): al llegar a destino o al terminar un clip de una vez sin que nadie le de otro, el
## actor vuelve aqui mezclando (antes quedaba trotando en el sitio despues de llegar, o congelado en la ultima pose de
## un festejo). Lo fija quien lo maneja (stance, barrera, arquero) o se elige uno al construirlo.
var rest_loop: StringName = &""
## Cuantas veces volvio solo al reposo (diagnostico y pruebas).
var rest_returns: int = 0
## Mantener la ultima pose al terminar un clip (el arquero con la pelota en las manos: un reposo le separaria las manos).
var freeze_on_finish: bool = false
## Altura del piso donde esta parado (0 en la cancha; los minijuegos con plataformas la cambian, y una caida la baja).
var ground_y: float = 0.0
## Numero en la espalda (personalizacion): Label3D que sigue la columna del esqueleto (no toca el modelo compartido).
var _number: Label3D = null

var _bones: Dictionary = {}
var collider: AnimatableBody3D = null
var _collider_height: float = 1.75

func build(kit: Dictionary) -> void:
	model = Node3D.new()
	model.name = "Rig"
	model.scale = Vector3.ONE * BODY_SCALE
	add_child(model)
	var inst: Node3D = (load(BODY) as PackedScene).instantiate()
	model.add_child(inst)
	skeleton = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	inst.add_child(anim_player)
	anim_player.root_node = anim_player.get_path_to(inst)
	anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	var libs: Dictionary = SpClips.libraries()
	for key in libs:
		anim_player.add_animation_library(key, libs[key])
	set_kit(kit)
	var idles: Array[StringName] = SpClips.by_role(&"idle_ready", false)
	if not idles.is_empty():
		rest_loop = idles[get_instance_id() % idles.size()]

## Numero en la espalda (0 lo quita). Se ubica cada paso detras de la columna, mirando hacia atras.
func set_back_number(n: int) -> void:
	if n <= 0:
		if _number != null:
			_number.queue_free()
			_number = null
		return
	if _number == null:
		_number = Label3D.new()
		_number.font_size = 150
		_number.pixel_size = 0.0016
		_number.outline_size = 24
		_number.modulate = Color(0.97, 0.97, 0.98)
		_number.outline_modulate = Color(0.05, 0.05, 0.1, 0.9)
		_number.top_level = true
		add_child(_number)
	_number.text = str(n)

func set_kit(kit: Dictionary) -> void:
	if model == null:
		return
	var mat: ShaderMaterial = AnimBankCatalog.kit_material(BODY, kit)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat

# --- Orientacion ----------------------------------------------------------------------------------------------------------

func facing() -> Vector3:
	return SpClips.dir_of(rotation.y)

func set_facing(f: Vector3) -> void:
	f.y = 0.0
	if f.length_squared() < 1e-6:
		return
	rotation.y = SpClips.yaw_of(f.normalized())
	_face_target = Vector3.ZERO

## Gira suavemente hacia f (mientras no haya un clip con raiz).
func face_towards(f: Vector3) -> void:
	f.y = 0.0
	if f.length_squared() > 1e-6:
		_face_target = f.normalized()

# --- Reproduccion ---------------------------------------------------------------------------------------------------------

## Bucle en el sitio (reposo, espera, trote cuando lo mueve move_to).
func play_loop(id: StringName, blend: float = BLEND, speed: float = 1.0) -> void:
	if not SpClips.has(id):
		return
	clip_id = id
	clip_meta = SpClips.meta(id)
	clip_speed = speed
	looping = true
	_finished_emitted = true
	anim_player.speed_scale = 1.0
	# El bucle lo maneja el actor (se vuelve a empezar al terminar): las Animation son compartidas por todos los jugadores y
	# no se modifican (cambiarlas obliga a cada reproductor conectado a reconstruir su cache).
	anim_player.play(SpClips.path(id), blend, speed)

## Clip de una vez con raiz. origin/facing: marco del clip (donde estaria la raiz en t = 0). start_at: instante del clip
## desde el que empieza (el cuerpo aparece en la raiz de ese instante).
func play_clip(id: StringName, origin: Vector3, face: Vector3, blend: float = BLEND, speed: float = 1.0, start_at: float = 0.0) -> void:
	if not SpClips.has(id):
		return
	_moving = false
	_face_target = Vector3.ZERO
	clip_id = id
	clip_meta = SpClips.meta(id)
	clip_speed = maxf(speed, 0.05)
	looping = false
	frame_origin = Vector3(origin.x, 0.0, origin.z)
	face.y = 0.0
	frame_facing = face.normalized()
	_clip_started_at = start_at
	_clip_time = start_at
	_finished_emitted = false
	anim_player.speed_scale = 1.0
	anim_player.play(SpClips.path(id), blend, clip_speed)
	if start_at > 0.0:
		anim_player.seek(start_at, true)
	_apply_root(_clip_time)

## Ritmo del clip en curso (multiplica su velocidad; 1 = la elegida al empezar). Lo usa el arquero para que las manos
## lleguen justo cuando pasa la pelota. Cada clip o bucle nuevo vuelve a 1.
func set_clip_rate(rate: float) -> void:
	anim_player.speed_scale = maxf(rate, 0.05)

func clip_rate() -> float:
	return anim_player.speed_scale

## Clip de una vez en el sitio actual (festejos, lamentos, reacciones): el marco es la posicion y mirada actuales.
func play_here(id: StringName, blend: float = BLEND, speed: float = 1.0) -> void:
	play_clip(id, global_position, facing(), blend, speed, 0.0)

## Marco (origen, mirada) de un clip para que en el instante t el cuerpo quede en body_pos mirando a body_face.
static func frame_for(id: StringName, t: float, body_pos: Vector3, body_face: Vector3) -> Array:
	var m: Dictionary = SpClips.meta(id)
	var h: float = SpClips.heading_at(m, t)
	var f: Vector3 = body_face.normalized().rotated(Vector3.UP, -h)
	var rt: Vector2 = SpClips.root_at(m, t)
	var o: Vector3 = body_pos - f * rt.x - SpClips.right_of(f) * rt.y
	o.y = 0.0
	return [o, f]

## Posicion y mirada del cuerpo en el instante t de un clip con marco (origin, face).
static func body_at(id: StringName, t: float, origin: Vector3, face: Vector3) -> Array:
	var m: Dictionary = SpClips.meta(id)
	var rt: Vector2 = SpClips.root_at(m, t)
	var p: Vector3 = origin + face * rt.x + SpClips.right_of(face) * rt.y
	var f: Vector3 = face.rotated(Vector3.UP, SpClips.heading_at(m, t))
	return [p, f]

func clip_time() -> float:
	return _clip_time

func clip_done() -> bool:
	return not looping and _finished_emitted

func is_playing_clip(id: StringName = &"") -> bool:
	return not looping and not _finished_emitted and (id == &"" or id == clip_id)

# --- Desplazamiento procedural ---------------------------------------------------------------------------------------------

## Camina/trota hacia target con un bucle de marcha (en el sitio) a `speed` m/s; face: mirada mientras avanza (cero =
## hacia donde va).
func move_to(target: Vector3, speed: float, loop_id: StringName, face: Vector3 = Vector3.ZERO) -> void:
	_move_target = Vector3(target.x, 0.0, target.z)
	_move_speed = speed
	_move_face = face
	_moving = true
	if loop_id != &"" and SpClips.has(loop_id):
		_move_natural = maxf(float(SpClips.meta(loop_id).get("natural_speed_json", 3.0)), 0.5)
		if clip_id != loop_id or not looping:
			play_loop(loop_id, BLEND, clampf(speed / _move_natural, 0.4, 1.8))
		_move_loop = loop_id

func stop_moving() -> void:
	_moving = false
	# Si lo frenan corriendo y nadie le da otro clip, no queda trotando en el sitio.
	if looping and clip_id == _move_loop and rest_loop != &"" and rest_loop != _move_loop:
		play_loop(rest_loop, 0.25)

func is_moving() -> bool:
	return _moving

# --- Huesos ----------------------------------------------------------------------------------------------------------------

func bone_world(bone_name: String) -> Vector3:
	if skeleton == null:
		return global_position
	var idx: int = _bones.get(bone_name, -2)
	if idx == -2:
		idx = skeleton.find_bone(bone_name)
		_bones[bone_name] = idx
	if idx < 0:
		return global_position
	return (skeleton.global_transform * skeleton.get_bone_global_pose(idx)).origin

func hands_mid() -> Vector3:
	return (bone_world(HAND_L) + bone_world(HAND_R)) * 0.5

# --- Colision ---------------------------------------------------------------------------------------------------------------

## Capsula cinematica que sigue a la cadera (barrera y jugadores sueltos): la pelota rebota en el cuerpo.
func enable_collider(radius: float = 0.24, height: float = 1.78) -> void:
	if collider != null:
		return
	collider = AnimatableBody3D.new()
	collider.name = "BodyCollider"
	collider.sync_to_physics = false
	collider.collision_layer = Ball.LAYER_PLAYERS
	collider.collision_mask = 0
	collider.top_level = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.6
	collider.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	_collider_height = height
	cs.shape = cap
	collider.add_child(cs)
	add_child(collider)
	collider.global_position = global_position + Vector3.UP * height * 0.5

# --- Paso -------------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if anim_player == null:
		return
	if looping and clip_id != &"" and not anim_player.is_playing():
		anim_player.play(SpClips.path(clip_id), 0.12, clip_speed)
	if not looping and not _finished_emitted:
		var cur: StringName = SpClips.path(clip_id)
		var running: bool = anim_player.current_animation == String(cur) and anim_player.is_playing()
		var pos: float = anim_player.current_animation_position if running else SpClips.length(clip_id)
		# Un clip en bucle reproducido una vez: al dar la vuelta (la posicion vuelve atras) termino su ciclo. Sin esto el
		# jugador quedaba repitiendolo para siempre esperando un final que no llega. La animacion compartida no se toca.
		var wrapped: bool = running and pos + 0.05 < _clip_time
		_clip_time = SpClips.length(clip_id) if wrapped else pos
		_apply_root(_clip_time)
		if not running or wrapped or _clip_time >= SpClips.length(clip_id) - 0.001:
			_finished_emitted = true
			var done_id: StringName = clip_id
			clip_finished.emit(done_id)
			# Nadie le dio otro clip ni un bucle: vuelve a su reposo (transicion natural, no se congela).
			if not looping and _finished_emitted and clip_id == done_id and rest_loop != &"" and not freeze_on_finish:
				rest_returns += 1
				play_loop(rest_loop, 0.35)
	elif _moving:
		var to: Vector3 = _move_target - Vector3(global_position.x, 0.0, global_position.z)
		var d: float = to.length()
		var step: float = _move_speed * delta
		if d <= step or d < 0.02:
			global_position = Vector3(_move_target.x, global_position.y, _move_target.z)
			_moving = false
			# Llego: deja de trotar en el sitio y vuelve a su reposo.
			if looping and clip_id == _move_loop and rest_loop != &"" and rest_loop != _move_loop:
				rest_returns += 1
				play_loop(rest_loop, 0.3)
		else:
			global_position += to / d * step
			var want: Vector3 = _move_face if _move_face != Vector3.ZERO else to / d
			_turn_towards(want, delta)
	if _face_target != Vector3.ZERO and looping and not _moving:
		_turn_towards(_face_target, delta)
	if _number != null and visible:
		var sp: Vector3 = bone_world("mixamorig_Spine1")
		var f: Vector3 = facing()
		_number.global_position = sp - f * 0.17 + Vector3.UP * 0.10
		_number.look_at(_number.global_position + f, Vector3.UP)
	if collider != null:
		var hips: Vector3 = bone_world(HIPS)
		var feet: float = minf(bone_world(TOE_L).y, bone_world(TOE_R).y)
		# La capsula va de los pies a la cabeza siguiendo la cadera (si salta, sube entera).
		collider.global_position = Vector3(hips.x, maxf(feet, 0.0) + _collider_height * 0.5 - 0.02, hips.z)

func _turn_towards(want: Vector3, delta: float) -> void:
	var cur: float = rotation.y
	var target: float = SpClips.yaw_of(want)
	var diff: float = wrapf(target - cur, -PI, PI)
	var mx: float = turn_rate * delta
	rotation.y = cur + clampf(diff, -mx, mx)

func _apply_root(t: float) -> void:
	var r: Array = body_at(clip_id, t, frame_origin, frame_facing)
	global_position = Vector3((r[0] as Vector3).x, ground_y, (r[0] as Vector3).z)
	rotation.y = SpClips.yaw_of(r[1])
