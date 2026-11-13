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

const BODY := AnimBank.BODY_PATH
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

var _bones: Dictionary = {}
var collider: AnimatableBody3D = null
var _collider_height: float = 1.75

## Cuerpo con que se armo (AnimBank.body_path(): el modelo de Tripo del usuario, el unico cuerpo del juego).
var body_path: String = BODY

func build(kit: Dictionary) -> void:
	model = Node3D.new()
	model.name = "Rig"
	model.scale = Vector3.ONE * BODY_SCALE
	add_child(model)
	body_path = AnimBank.body_path()
	var inst: Node3D = (load(body_path) as PackedScene).instantiate()
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
	_measure_body()
	var idles: Array[StringName] = SpClips.by_role(&"idle_ready", false)
	if not idles.is_empty():
		rest_loop = idles[get_instance_id() % idles.size()]

## Numero en la espalda (0 lo quita): IMPRESO en la camiseta. El shader del uniforme lo proyecta sobre la espalda en la
## posicion de reposo (CUSTOM0 del cuerpo de Tripo): se dobla y se mueve con la tela.
var back_number: int = 0

func set_back_number(n: int) -> void:
	back_number = maxi(n, 0)
	_apply_printed_number()

## true si el numero va impreso en la tela (cuerpo con posicion de reposo en la malla).
func printed_number() -> bool:
	return body_path == AnimBankCatalog.PRINTED_NUMBER_BODY

## Material del uniforme en uso (null si no hay modelo).
func kit_material() -> ShaderMaterial:
	if model == null:
		return null
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		return (mi as MeshInstance3D).material_override as ShaderMaterial
	return null

## Accesorios puestos (AccessoryCatalog): nodos colgados de los huesos.
var accessories: Array = []
var _acc_nodes: Array[Node] = []

## Pone los accesorios ids (los demas se sacan). Cada pieza es un cilindro alrededor del hueso, entre dos fracciones de su
## largo (hasta el hueso hijo), en un BoneAttachment3D: sigue la animacion sin cambiar el esqueleto.
func set_accessories(ids: Array) -> void:
	for n in _acc_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_acc_nodes.clear()
	accessories = ids.duplicate()
	if skeleton == null:
		return
	for id in ids:
		var st: Dictionary = AccessoryCatalog.STYLES.get(String(id), {})
		if st.is_empty():
			continue
		for pc in AccessoryCatalog.pieces(String(st["slot"])):
			var bi: int = skeleton.find_bone(String(pc[0]))
			if bi < 0:
				continue
			var ci: int = skeleton.find_bone(String(pc[1]))
			# Direccion del hueso hacia su hijo en el espacio del hueso (en este esqueleto el eje Y no siempre apunta al hijo).
			var to_child := Vector3(0, 0.25, 0)
			if ci >= 0:
				to_child = skeleton.get_bone_rest(ci).origin
			var length: float = to_child.length()
			var axis: Vector3 = to_child.normalized() if length > 1e-4 else Vector3.UP
			var att := BoneAttachment3D.new()
			att.bone_name = String(pc[0])
			skeleton.add_child(att)
			_acc_nodes.append(att)
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			var r: float = float(pc[4])
			cm.top_radius = r
			cm.bottom_radius = r * 1.04
			cm.height = maxf((float(pc[3]) - float(pc[2])) * length, 0.01)
			var fixed: Dictionary = pc[5] if pc.size() > 5 else {}
			if not fixed.is_empty():
				# Pieza ubicada en el espacio del esqueleto en reposo (vincha): se pasa al espacio del hueso, vertical.
				var gr: Transform3D = skeleton.get_bone_global_rest(bi)
				to_child = gr.basis.inverse() * Vector3.UP
				axis = to_child.normalized()
				length = 0.0
				cm.height = float(fixed.get("height", 0.03))
			cm.radial_segments = 14
			cm.rings = 1
			mi.mesh = cm
			var m := StandardMaterial3D.new()
			m.albedo_color = st["color"]
			m.roughness = 0.7
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = axis * length * (float(pc[2]) + float(pc[3])) * 0.5
			if not fixed.is_empty():
				mi.position = skeleton.get_bone_global_rest(bi).affine_inverse() * (fixed["center"] as Vector3)
			var side: Vector3 = axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
			mi.basis = Basis(side, axis, side.cross(axis).normalized())
			att.add_child(mi)

## Estilo del numero de la espalda (catalogo «number_style»: num_clasico, num_oro, num_mitico_10, num_mitico_7).
var number_style: String = "num_clasico"

func set_number_style(st: String) -> void:
	number_style = st
	if back_number > 0:
		_apply_printed_number()

func _apply_printed_number() -> void:
	var mat: ShaderMaterial = kit_material()
	if mat == null:
		return
	mat.set_shader_parameter("back_number", back_number)
	# Contraste con la camiseta: cifras oscuras sobre una camiseta clara, blancas sobre una oscura.
	var j: Variant = mat.get_shader_parameter("jersey_color")
	var light: bool = j is Color and (j as Color).get_luminance() > 0.62
	mat.set_shader_parameter("number_color", Color(0.06, 0.07, 0.16) if light else Color(0.97, 0.97, 0.98))
	mat.set_shader_parameter("number_edge", Color(0.97, 0.97, 0.98) if light else Color(0.05, 0.05, 0.1))
	# Estilo del numero (tienda): dorado, o «mitico» (dorado con borde rojo oscuro).
	if number_style == "num_oro":
		mat.set_shader_parameter("number_color", Color(0.98, 0.78, 0.22))
		mat.set_shader_parameter("number_edge", Color(0.12, 0.08, 0.02))
	elif number_style.begins_with("num_mitico"):
		mat.set_shader_parameter("number_color", Color(1.0, 0.86, 0.35))
		mat.set_shader_parameter("number_edge", Color(0.55, 0.05, 0.08))

func set_kit(kit: Dictionary) -> void:
	if model == null:
		return
	var mat: ShaderMaterial = AnimBankCatalog.kit_material(body_path, kit)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	if back_number > 0:
		_apply_printed_number()

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
	return (hand_point(true) + hand_point(false)) * 0.5

## Modelo de Tripo: sus brazos son mas cortos que los del esqueleto del juego (antebrazo 0,21 m contra 0,33 m) y el hueso
## de la punta del pie esta a mitad del pie. Las animaciones y sus mediciones (manos de las atajadas, punta del pie en el
## golpe) son las del esqueleto del juego: arm_extra prolonga la mano hasta el largo de brazo del juego (alcance del guante)
## y toe_tip() da la punta del pie al largo del pie del juego.
var arm_extra: float = 0.0
var _tripo: bool = false

func _measure_body() -> void:
	_tripo = body_path == AnimBank.BODY_PATH
	arm_extra = 0.0
	if not _tripo or skeleton == null:
		return
	var tot: float = 0.0
	for side in ["Left", "Right"]:
		var a: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("mixamorig_%sArm" % side)).origin
		var f: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("mixamorig_%sForeArm" % side)).origin
		var h: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("mixamorig_%sHand" % side)).origin
		tot += (a.distance_to(f) + f.distance_to(h)) * BODY_SCALE
	arm_extra = maxf((JsonRig.UPPER_ARM + JsonRig.FOREARM) - tot * 0.5, 0.0)

## Mano (centro de la palma al largo de brazo del juego).
func hand_point(left: bool) -> Vector3:
	var h: Vector3 = bone_world(HAND_L if left else HAND_R)
	if arm_extra <= 0.0:
		return h
	var d: Vector3 = h - bone_world("mixamorig_LeftForeArm" if left else "mixamorig_RightForeArm")
	return h + d.normalized() * arm_extra if d.length() > 1e-4 else h

## Punta del pie (lo que toca la pelota).
func toe_tip(left: bool) -> Vector3:
	var toe: Vector3 = bone_world(TOE_L if left else TOE_R)
	if not _tripo:
		return toe
	var ank: Vector3 = bone_world("mixamorig_LeftFoot" if left else "mixamorig_RightFoot")
	var d: Vector3 = toe - ank
	return ank + d.normalized() * JsonRig.FOOT if d.length() > 1e-4 else toe

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
