class_name FootballerVisual
extends Node3D
## Presentacion del futbolista: modelo de Tripo3D (malla + esqueleto de 23 huesos) con material de
## equipamiento recoloreable, AnimationTree (locomocion mezclada por velocidad + acciones puntuales)
## y una capa procedural (patadas, torso, mirada) aplicada despues de la animacion.
## Las animaciones vienen de una libreria compartida (assets/animations/footballer_clips.res):
## todos los jugadores y arqueros usan el MISMO esqueleto, asi cada clip sirve para todos.
## Si el modelo no se puede cargar, usa un maniqui provisional para no romper el juego.

const MODEL_PATH := "res://assets/characters/player/player_base.glb"
const CLIPS_PATH := "res://assets/animations/footballer_clips.res"
const KIT_SHADER := preload("res://assets/characters/player/player_kit.gdshader")
const ALBEDO_PATH := "res://assets/characters/player/player_albedo.jpg"
const MASK_A_PATH := "res://assets/characters/player/player_mask_a.png"
const MASK_B_PATH := "res://assets/characters/player/player_mask_b.png"
## El modelo de Tripo mide 1.0 unidad de alto; el jugador real mide ~1.75 m.
const MODEL_HEIGHT_SCALE := 1.75
## El modelo de Tripo mira hacia +X; el juego usa -Z como "adelante".
const MODEL_YAW := PI * 0.5

## Velocidad natural (m/s reales) de cada ciclo, medida con tools/measure_hips.gd.
const NATURAL_SPEED := {"walk": 0.97, "run": 2.50}
const MAX_TIME_SCALE := 2.9
const MIN_TIME_SCALE := 0.6
## Clips de accion (una sola vez) que se pueden disparar con play_action().
const ACTION_CLIPS: Array[StringName] = [&"celebrate_goal", &"dejected", &"frustrated", &"jump", &"turn",
	&"fall", &"dive", &"keeper_catch_high", &"keeper_scoop_low"]

## Si es true y existe la libreria local del pack de Mixamo (PackLibrary), la locomocion y las acciones usan sus
## clips y los de Tripo quedan de respaldo. Las pruebas del camino Tripo lo desactivan de forma explicita.
static var prefer_pack: bool = true
const PACK_LIB := &"pack"
## Marcha del pack: clips que se mezclan segun la velocidad. La posicion en el BlendSpace ES la velocidad natural
## medida de cada clip, asi que a esa velocidad se reproduce a ritmo 1.0 (sin patinar) y entre dos clips se mezclan.
const PACK_GAIT_CLIPS: Array[StringName] = [&"offensive_idle", &"Walking_7_inplace", &"Jogging_inplace", &"jog_forward_inplace", &"Sprint_inplace"]
## Puntos del BlendSpace de la marcha del pack: [clip, posicion (m/s)]. El trote se repite en una posicion mas alta:
## entre ambos se reproduce SOLO el trote (a mayor cadencia) y la mezcla con el sprint empieza despues, en vez de
## mezclar dos zancadas distintas durante todo el tramo intermedio.
## Entre la caminata y el trote va el trote lento (Jogging_inplace, 1.64 m/s): el paso de caminar a trotar ya no mezcla dos
## zancadas muy distintas.
const PACK_GAIT_POINTS := [[&"offensive_idle", 0.0], [&"Walking_7_inplace", -1.0], [&"Jogging_inplace", -1.0], [&"jog_forward_inplace", -1.0], [&"jog_forward_inplace", 3.4], [&"Sprint_inplace", -1.0]]

## Mezcla direccional de 8 sentidos (arquero y defensa: el cuerpo mira a un punto y se mueve en cualquier direccion).
## Posicion en el BlendSpace2D: x = derecha, y = adelante; los clips cardinales estan a distancia 1.
const DIR_POINTS := [
	[&"jog_forward_inplace", 0.0, 1.0], [&"jog_backward_inplace", 0.0, -1.0],
	[&"jog_strafe_left_inplace", -1.0, 0.0], [&"jog_strafe_right_inplace", 1.0, 0.0],
	[&"jog_forward_diagonal_inplace", 0.7, 0.7], [&"jog_forward_diagonal_2_inplace", -0.7, 0.7],
	[&"jog_backward_diagonal_inplace", 0.7, -0.7], [&"jog_backward_diagonal_2_inplace", -0.7, -0.7],
	# Desplazamiento lateral rapido (3.14 m/s natural) hacia la derecha: el marcaje lateral a la carrera.
	[&"Strafe_3_inplace", 1.36, 0.0],
]
## Limite de la mezcla direccional (el lateral rapido esta a 1.36).
const DIR_MAX := 1.4
const STRAFE_FAST_SPEED := 3.14
## Arbitro: usa los GEMELOS CON RAIZ de la marcha (misma pose que los _inplace; su desplazamiento de raiz medido es el
## que mueve al cuerpo, ver Referee). Marcha y mezcla direccional con esos clips.
const TWIN_GAIT_POINTS := [[&"offensive_idle", 0.0], [&"Walking_7", -1.0], [&"Jogging", -1.0], [&"Running", -1.0], [&"Sprint", -1.0], [&"Two_Cycle_Sprint", 6.2]]
const TWIN_DIR_POINTS := [
	[&"jog_forward", 0.0, 1.0], [&"jog_backward", 0.0, -1.0],
	[&"jog_strafe_left", -1.0, 0.0], [&"jog_strafe_right", 1.0, 0.0],
	[&"jog_forward_diagonal", 0.7, 0.7], [&"jog_forward_diagonal_2", -0.7, 0.7],
	[&"jog_backward_diagonal", 0.7, -0.7], [&"jog_backward_diagonal_2", -0.7, -0.7],
	[&"Strafe_3", 1.36, 0.0],
]

## Velocidad (m/s) a la que la mezcla direccional esta en su radio 1 (velocidad natural media de esos clips).
const DIR_REF_SPEED := 2.3

## Marcha CON la pelota: mismos tramos que la marcha normal pero con los clips de conduccion (el jugador mira la
## pelota, da zancadas mas cortas y mueve los brazos distinto). Se mezcla con la marcha normal segun la posesion.
## Con la pelota la carrera usa Running_inplace (braceo distinto al trote sin pelota) y el sprint, Two_Cycle_Sprint_inplace
## (dos zancadas por ciclo: la conduccion larga a toda velocidad).
const CARRY_GAIT_POINTS := [[&"Soccer_Idle", 0.0], [&"Dribble_2", -1.0], [&"Running_inplace", 3.6], [&"Two_Cycle_Sprint_inplace", -1.0]]
## Velocidad (m/s) con la que la mezcla de conduccion llega a su peso maximo al recuperar la pelota.
const CARRY_BLEND_RATE := 4.0

signal action_finished(clip: StringName)

var rig: Node3D = null              # contiene el modelo (orientacion y escala)
var model_root: Node3D = null
var skeleton: Skeleton3D = null
var anim_player: AnimationPlayer = null
var anim_tree: AnimationTree = null
var pose_modifier: ProceduralPose = null
## IK del pie en los toques de conduccion (BallHandler le da la correccion); null sin el pack.
var touch_ik: TouchFootIK = null
var mesh_instances: Array[MeshInstance3D] = []
var kit_material: ShaderMaterial = null
var is_placeholder: bool = false
var current_action: StringName = &""
## Arbitro de acciones del futbolista (null en el arquero y el arbitro, que manejan su pose ellos mismos).
var arbiter: ActionArbiter = null
## true si este futbolista usa los clips del pack (si no, Tripo + patada procedural).
var uses_pack: bool = false
## true para el arquero: carga ademas la libreria de sus clips y usa su reposo como centro de la mezcla direccional.
var keeper_mode: bool = false
## Velocidad (m/s) de referencia de la mezcla direccional (DIR_REF_SPEED con el pack; la de los clips en el modo 4).
var _dir_ref: float = DIR_REF_SPEED
## El dueño pide la mezcla direccional (velocidad local (adelante, derecha) en m/s).
var directional: bool = false
## true mientras el futbolista lleva la pelota: mezcla los clips de conduccion sobre la marcha normal.
var carrying: bool = false
var _carry_weight: float = 0.0
var dir_velocity: Vector2 = Vector2.ZERO
var _dir_weight: float = 0.0
## true: rig del arbitro con los gemelos con raiz (ver TWIN_GAIT_POINTS). Se fija antes de build().
var twin_rig: bool = false
## > 0: posicion de la mezcla direccional y escala de tiempo fijadas por el dueno (el arbitro se mueve exactamente a la
## velocidad natural del gemelo que reproduce, asi que la escala es 1).
var dir_blend_override: Vector2 = Vector2.ZERO
var dir_scale_override: float = -1.0

var _pack_clip_node: AnimationNodeAnimation = null
var _has_carry: bool = false
## Capa de toque de conduccion por pierna (0 izquierda, 1 derecha): OneShot filtrado a los huesos de esa pierna encima de
## la marcha con pelota. El clip (TouchClipBuilder) se asigna al disparar (play_touch).
var _touch_nodes: Array = [null, null]
## Punto de la mezcla de marcha con pelota de cada clip (clip -> "cN"), para leer su fase (carry_phase).
var _carry_points: Dictionary = {}
const TOUCH_LEG_BONES := {
	0: [&"mixamorig_LeftUpLeg", &"mixamorig_LeftLeg", &"mixamorig_LeftFoot", &"mixamorig_LeftToeBase"],
	1: [&"mixamorig_RightUpLeg", &"mixamorig_RightLeg", &"mixamorig_RightFoot", &"mixamorig_RightToeBase"],
}
var _gait_max_natural: float = 1.0
var _active_tripo_clip: StringName = &""
## true si la accion del pack se recorta antes de acabar el clip (hay que fundirla al expirar el temporizador).
var _action_cut: bool = false

var _lean_pitch: float = 0.0
var _lean_roll: float = 0.0
var _lean_prev_speed: float = 0.0
var _lean_accel: float = 0.0
var _trunk_pitch: float = 0.0
var _trunk_roll: float = 0.0
## Inclinacion del tronco hacia dentro de la curva: fraccion de la fisica (tan = v * giro / g) y maximo (rad). La del
## cuerpo entero es ~1/20 de la fisica (2 grados a 6 m/s girando 1 rad/s): no se veia.
const LEAN_TURN_GAIN := 0.75
const LEAN_ROLL_MAX := 0.38
## Inclinacion maxima del tronco (rad) hacia delante al acelerar y hacia atras al frenar.
const LEAN_ACCEL_MAX := 0.18
const LEAN_BRAKE_MAX := 0.1
## Control cerrado: llevando la pelota despacio el tronco se encorva sobre ella (como en First Touch Soccer), hasta
## CARRY_CROUCH rad entre caminar y trotar; parado o a la carrera, nada.
const CARRY_CROUCH := 0.13
## Encorvado extra (rad) que pide una accion con la pelota (BallTurn: rodeando la pelota con toques).
var turn_crouch: float = 0.0
## Modo 4 (Json): modelo sobre el esqueleto JsonRig con la libreria de clips JSON (ver JsonCatalog). json_human: el humanoide
## propio (colores de equipo por zonas en COLOR.r); si no, el Tripo adaptado (misma textura y mascaras que el original).
var json_mode: bool = false
var json_human: bool = false
var _kit: Dictionary = {}
var _phase: float = 0.0
var _legs: Array[MeshInstance3D] = []
var _action_timer: float = 0.0

## Colores por defecto del kit (camiseta, short, medias, botines, piel, pelo).
static func default_kit(team: int) -> Dictionary:
	if team == 0:
		return {"jersey": Color(0.78, 0.05, 0.06), "shorts": Color(0.05, 0.12, 0.62), "socks": Color(0.92, 0.92, 0.92),
			"boots": Color(0.03, 0.03, 0.035), "skin": Color(0.62, 0.40, 0.29), "hair": Color(0.12, 0.07, 0.04)}
	return {"jersey": Color(0.95, 0.80, 0.05), "shorts": Color(0.05, 0.05, 0.08), "socks": Color(0.95, 0.80, 0.05),
		"boots": Color(0.9, 0.9, 0.9), "skin": Color(0.62, 0.40, 0.29), "hair": Color(0.12, 0.07, 0.04)}

static func referee_kit() -> Dictionary:
	return {"jersey": Color(0.06, 0.06, 0.07), "shorts": Color(0.04, 0.04, 0.05), "socks": Color(0.06, 0.06, 0.07),
		"boots": Color(0.02, 0.02, 0.02), "skin": Color(0.62, 0.40, 0.29), "hair": Color(0.12, 0.07, 0.04)}

static func keeper_kit() -> Dictionary:
	return {"jersey": Color(0.10, 0.70, 0.25), "shorts": Color(0.04, 0.2, 0.08), "socks": Color(0.10, 0.70, 0.25),
		"boots": Color(0.95, 0.5, 0.05), "skin": Color(0.62, 0.40, 0.29), "hair": Color(0.12, 0.07, 0.04)}

## Carga el modelo y aplica el kit. Devuelve false si se uso el maniqui provisional.
func build(kit: Dictionary) -> bool:
	for c in get_children():
		c.queue_free()
	_legs.clear()
	mesh_instances.clear()
	json_mode = Tuning.gameplay_mode == 4 and JsonCatalog.active() and JsonCatalog.model_path() != ""
	var model_path: String = JsonCatalog.model_path() if json_mode else MODEL_PATH
	var scene: PackedScene = load(model_path) as PackedScene
	var clips: AnimationLibrary = null if json_mode else (load(CLIPS_PATH) as AnimationLibrary)
	if scene == null or (clips == null and not json_mode):
		push_warning("FootballerVisual: faltan recursos (%s / %s); se usa un maniqui." % [model_path, CLIPS_PATH])
		_build_placeholder(kit.get("jersey", Color.RED))
		return false
	json_human = json_mode and JsonCatalog.is_human_model(model_path)
	is_placeholder = false
	rig = Node3D.new()
	rig.name = "Rig"
	rig.rotation.y = MODEL_YAW
	rig.scale = Vector3.ONE * MODEL_HEIGHT_SCALE
	add_child(rig)
	model_root = scene.instantiate() as Node3D
	rig.add_child(model_root)
	skeleton = model_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for mi in model_root.find_children("*", "MeshInstance3D", true, false):
		mesh_instances.append(mi as MeshInstance3D)
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	model_root.add_child(anim_player)
	if clips != null:
		anim_player.add_animation_library("", clips)
	# Modo 3 de jugabilidad: solo Tripo (sus clips prefijados y la patada procedural), sin el pack. Modo 4: la libreria JSON.
	uses_pack = prefer_pack and PackLibrary.available() and Tuning.gameplay_mode != 3
	if uses_pack:
		anim_player.add_animation_library(PACK_LIB, PackLibrary.field())
		if keeper_mode and PackLibrary.keeper() != null:
			anim_player.add_animation_library(&"keeper", PackLibrary.keeper())
	_apply_kit(kit)
	_setup_animation_tree()
	pose_modifier = ProceduralPose.new()
	pose_modifier.name = "ProceduralPose"
	skeleton.add_child(pose_modifier)
	pose_modifier.setup(skeleton)
	# Correccion del pie en los toques de conduccion (despues de la pose procedural: corrige la pose final).
	if uses_pack:
		touch_ik = TouchFootIK.new()
		touch_ik.name = "TouchFootIK"
		skeleton.add_child(touch_ik)
	return true

func _apply_kit(kit: Dictionary) -> void:
	kit_material = ShaderMaterial.new()
	if json_human:
		kit_material.shader = load(JsonCatalog.KIT_SHADER_PATH) as Shader
	else:
		kit_material.shader = KIT_SHADER
		kit_material.set_shader_parameter("albedo_tex", load(ALBEDO_PATH))
		kit_material.set_shader_parameter("mask_a", load(MASK_A_PATH))
		kit_material.set_shader_parameter("mask_b", load(MASK_B_PATH))
	set_kit(kit)
	for mi in mesh_instances:
		mi.material_override = kit_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func set_kit(kit: Dictionary) -> void:
	_kit.merge(kit, true)
	if kit_material == null:
		return
	for key in ["jersey", "shorts", "socks", "boots", "skin", "hair"]:
		if kit.has(key):
			kit_material.set_shader_parameter("%s_color" % key, kit[key])
	# El ribete (cuello, mangas, borde de las medias) del humanoide lleva el color del short.
	if json_human and kit.has("shorts"):
		kit_material.set_shader_parameter("trim_color", kit["shorts"])

func _anim_node(clip: StringName) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	return n

## Modo 4: ciclo de marcha con una linea de tiempo comun de UN ciclo (todos empiezan en un apoyo del pie izquierdo), asi las
## fases de los clips que se mezclan coinciden; la cadencia la da el TimeScale (ciclos por segundo, ver JsonCatalog).
func _json_cycle_node(id: StringName) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = PackLibrary.anim_path(id)
	n.use_custom_timeline = true
	n.timeline_length = 1.0
	n.stretch_time_scale = true
	n.loop_mode = Animation.LOOP_LINEAR
	return n

## Vacia los datos calculados con la libreria de clips (cambian al cambiar de modo).
static func reset_caches() -> void:
	_gait_cache = []
	_carry_cache = []

func _setup_animation_tree() -> void:
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = 7.5
	space.sync = true
	if json_mode:
		var jidx := 0
		for pt in JsonCatalog.gait_points(false):
			space.add_blend_point(_json_cycle_node(pt[0]), float(pt[1]), -1, StringName("g%d" % jidx))
			jidx += 1
			_gait_max_natural = maxf(_gait_max_natural, float(pt[1]))
	elif uses_pack:
		var idx := 0
		for pt in (TWIN_GAIT_POINTS if twin_rig else PACK_GAIT_POINTS):
			var clip: StringName = pt[0]
			var natural: float = 0.0 if clip == PACK_GAIT_CLIPS[0] else float(PackLibrary.meta(clip).get("natural_speed", 0.0))
			var pos: float = natural if float(pt[1]) < 0.0 else float(pt[1])
			space.add_blend_point(_anim_node(StringName("%s/%s" % [PACK_LIB, clip])), pos, -1, StringName("g%d" % idx))
			idx += 1
			_gait_max_natural = maxf(_gait_max_natural, natural)
	else:
		space.add_blend_point(_anim_node(&"idle"), 0.0, -1, &"idle")
		space.add_blend_point(_anim_node(&"walk"), NATURAL_SPEED["walk"] * 1.15, -1, &"walk")
		space.add_blend_point(_anim_node(&"run"), NATURAL_SPEED["run"] * 1.6, -1, &"run")
	var tree_root := AnimationNodeBlendTree.new()
	tree_root.add_node(&"Locomotion", space, Vector2(0, 0))
	tree_root.add_node(&"LocoScale", AnimationNodeTimeScale.new(), Vector2(260, 0))
	tree_root.connect_node(&"LocoScale", 0, &"Locomotion")
	var previous: StringName = &"LocoScale"
	if uses_pack:
		var dir := AnimationNodeBlendSpace2D.new()
		dir.min_space = Vector2(-DIR_MAX - 0.1, -DIR_MAX - 0.1)
		dir.max_space = Vector2(DIR_MAX + 0.1, DIR_MAX + 0.1)
		var center: StringName = PackLibrary.anim_path(&"goalkeeper_idle") if (keeper_mode and PackLibrary.has_clip(&"goalkeeper_idle")) else StringName("%s/%s" % [PACK_LIB, PACK_GAIT_CLIPS[0]])
		if json_mode and not (keeper_mode and PackLibrary.has_clip(&"goalkeeper_idle")):
			center = PackLibrary.anim_path(JsonCatalog.GAIT[0][0])
		dir.add_blend_point(_anim_node(center), Vector2.ZERO, -1, &"d_center")
		var di := 0
		_dir_ref = JsonCatalog.dir_ref_speed() if json_mode else DIR_REF_SPEED
		for pt in (JsonCatalog.dir_points(keeper_mode) if json_mode else (TWIN_DIR_POINTS if twin_rig else DIR_POINTS)):
			if PackLibrary.has_clip(pt[0]):
				dir.add_blend_point(_anim_node(PackLibrary.anim_path(pt[0])), Vector2(pt[1], pt[2]), -1, StringName("d%d" % di))
				di += 1
		tree_root.add_node(&"Dir", dir, Vector2(0, 600))
		tree_root.add_node(&"DirScale", AnimationNodeTimeScale.new(), Vector2(260, 600))
		tree_root.connect_node(&"DirScale", 0, &"Dir")
		tree_root.add_node(&"ModeMix", AnimationNodeBlend2.new(), Vector2(520, 300))
		tree_root.connect_node(&"ModeMix", 0, &"LocoScale")
		tree_root.connect_node(&"ModeMix", 1, &"DirScale")
		previous = &"ModeMix"
		# Marcha con la pelota (se mezcla encima de la marcha normal segun la posesion).
		var carry := AnimationNodeBlendSpace1D.new()
		carry.min_space = 0.0
		carry.max_space = 7.5
		carry.sync = true
		var ci := 0
		for pt in (JsonCatalog.gait_points(true) if json_mode else CARRY_GAIT_POINTS):
			var cclip: StringName = pt[0]
			if not PackLibrary.has_clip(cclip):
				continue
			var cnat: float = float(PackLibrary.meta(cclip).get("natural_speed", 0.0))
			var cpos: float = cnat if float(pt[1]) < 0.0 else float(pt[1])
			carry.add_blend_point(_json_cycle_node(cclip) if json_mode else _anim_node(PackLibrary.anim_path(cclip)), cpos, -1, StringName("c%d" % ci))
			_carry_points[cclip] = "c%d" % ci
			ci += 1
		if ci >= 2:
			tree_root.add_node(&"Carry", carry, Vector2(0, 900))
			tree_root.add_node(&"CarryScale", AnimationNodeTimeScale.new(), Vector2(260, 900))
			tree_root.connect_node(&"CarryScale", 0, &"Carry")
			tree_root.add_node(&"CarryMix", AnimationNodeBlend2.new(), Vector2(780, 300))
			tree_root.connect_node(&"CarryMix", 0, previous)
			tree_root.connect_node(&"CarryMix", 1, &"CarryScale")
			previous = &"CarryMix"
			_has_carry = true
			for f in 2:
				var tnode := AnimationNodeAnimation.new()
				tnode.animation = StringName("%s/%s" % [PACK_LIB, CARRY_GAIT_POINTS[1][0]])
				var tone := AnimationNodeOneShot.new()
				tone.fadein_time = 0.05
				tone.fadeout_time = 0.06
				tone.filter_enabled = true
				for b in TOUCH_LEG_BONES[f]:
					tone.set_filter_path(NodePath("Armature/Skeleton3D:%s" % b), true)
				tree_root.add_node(StringName("TouchClip%d" % f), tnode, Vector2(260, 1100 + 160 * f))
				tree_root.add_node(StringName("TouchScale%d" % f), AnimationNodeTimeScale.new(), Vector2(520, 1100 + 160 * f))
				tree_root.connect_node(StringName("TouchScale%d" % f), 0, StringName("TouchClip%d" % f))
				tree_root.add_node(StringName("TouchShot%d" % f), tone, Vector2(1040 + 260 * f, 300))
				tree_root.connect_node(StringName("TouchShot%d" % f), 0, previous)
				tree_root.connect_node(StringName("TouchShot%d" % f), 1, StringName("TouchScale%d" % f))
				previous = StringName("TouchShot%d" % f)
				_touch_nodes[f] = tnode
	var x: float = 520.0
	for clip in ([] if json_mode else ACTION_CLIPS):
		var shot_name := StringName("Shot_%s" % clip)
		var scale_name := StringName("Scale_%s" % clip)
		var one := AnimationNodeOneShot.new()
		one.fadein_time = 0.12
		one.fadeout_time = 0.2
		tree_root.add_node(StringName("Clip_%s" % clip), _anim_node(clip), Vector2(x - 260, 200))
		tree_root.add_node(scale_name, AnimationNodeTimeScale.new(), Vector2(x, 200))
		tree_root.connect_node(scale_name, 0, StringName("Clip_%s" % clip))
		tree_root.add_node(shot_name, one, Vector2(x, 0))
		tree_root.connect_node(shot_name, 0, previous)
		tree_root.connect_node(shot_name, 1, scale_name)
		previous = shot_name
		x += 260.0
	if uses_pack:
		# Capa de acciones del pack: UN solo OneShot cuyo clip se asigna al disparar (play_pack_clip).
		_pack_clip_node = AnimationNodeAnimation.new()
		_pack_clip_node.animation = StringName("%s/%s" % [PACK_LIB, PACK_GAIT_CLIPS[1]])
		var pack_one := AnimationNodeOneShot.new()
		pack_one.fadein_time = 0.12
		pack_one.fadeout_time = 0.2
		tree_root.add_node(&"PackClip", _pack_clip_node, Vector2(x - 260, 400))
		tree_root.add_node(&"PackScale", AnimationNodeTimeScale.new(), Vector2(x, 400))
		tree_root.connect_node(&"PackScale", 0, &"PackClip")
		tree_root.add_node(&"PackShot", pack_one, Vector2(x, 0))
		tree_root.connect_node(&"PackShot", 0, previous)
		tree_root.connect_node(&"PackShot", 1, &"PackScale")
		previous = &"PackShot"
	tree_root.connect_node(&"output", 0, previous)
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	_param_last = {}
	model_root.add_child(anim_tree)
	anim_tree.tree_root = tree_root
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	anim_tree.active = true

## Toque de conduccion: reproduce el clip de toque `id` en la capa de la pierna `foot` a `speed` (la escala de la
## marcha con pelota). Devuelve false si no hay capa o clip.
func play_touch(id: StringName, foot: int, speed: float) -> bool:
	if anim_tree == null or not uses_pack or foot < 0 or foot > 1 or _touch_nodes[foot] == null or not PackLibrary.has_clip(id):
		return false
	(_touch_nodes[foot] as AnimationNodeAnimation).animation = PackLibrary.anim_path(id)
	_set_param(P_TOUCH_SCALE[foot], maxf(speed, 0.05))
	anim_tree.set("parameters/TouchShot%d/request" % foot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return true

## Fase (s) del clip de marcha con pelota `clip` tras el ultimo proceso del AnimationTree; -1 si no esta en la mezcla.
## Todos los puntos de la mezcla avanzan a la vez (sync), asi que la fase vale aunque ese clip pese poco.
func carry_phase(clip: StringName) -> float:
	if anim_tree == null or not _carry_points.has(clip):
		return -1.0
	return float(anim_tree.get("parameters/Carry/%s/current_position" % _carry_points[clip]))

## Clip de la marcha con pelota que domina a una velocidad (el punto de la mezcla mas cercano, sin el reposo).
static func carry_clip_for(speed: float) -> StringName:
	if PackLibrary.json_mode():
		return &""   # la conduccion del modo 4 no usa clips de toque sueltos (ver JsonDribble)
	var best: StringName = &""
	var best_d: float = INF
	for i in range(1, CARRY_GAIT_POINTS.size()):
		var clip: StringName = CARRY_GAIT_POINTS[i][0]
		if not PackLibrary.has_clip(clip):
			continue
		var pos: float = float(CARRY_GAIT_POINTS[i][1])
		if pos < 0.0:
			pos = float(PackLibrary.meta(clip).get("natural_speed", 0.0))
		if absf(speed - pos) < best_d:
			best_d = absf(speed - pos)
			best = clip
	return best

## Dispara un clip de accion una sola vez. Devuelve su duracion efectiva en segundos.
func play_action(clip: StringName, speed: float = 1.0) -> float:
	if is_placeholder or anim_tree == null or not ACTION_CLIPS.has(clip):
		return 0.0
	stop_current_action()
	var length: float = anim_player.get_animation(clip).length / maxf(speed, 0.05)
	anim_tree.set("parameters/Scale_%s/scale" % clip, speed)
	anim_tree.set("parameters/Shot_%s/request" % clip, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	current_action = clip
	_active_tripo_clip = clip
	_action_timer = length
	return length

## Ciclos de zancada (dos apoyos) que contiene cada clip de marcha. Casi todos son de un ciclo; el trote lento
## (Jogging_inplace, 2.57 s) trae tres y Two_Cycle_Sprint dos (contados en las punta de pie del clip).
const GAIT_CYCLES := {&"Jogging_inplace": 3, &"Jogging": 3, &"Two_Cycle_Sprint_inplace": 2, &"Two_Cycle_Sprint": 2}

## Duracion (s) de UN ciclo de zancada del clip.
static func cycle_seconds(clip: StringName) -> float:
	return float(PackLibrary.meta(clip).get("duration", 1.0)) / float(GAIT_CYCLES.get(clip, 1))

## Tabla de la marcha del pack: [posicion en el BlendSpace (m/s), velocidad natural del clip (m/s), duracion del ciclo (s)].
static var _gait_cache: Array[Vector3] = []

static func gait_table() -> Array[Vector3]:
	if _gait_cache.is_empty() and PackLibrary.available():
		for pt in PACK_GAIT_POINTS:
			var clip: StringName = pt[0]
			var m: Dictionary = PackLibrary.meta(clip)
			var natural: float = 0.0 if clip == PACK_GAIT_CLIPS[0] else float(m.get("natural_speed", 0.0))
			_gait_cache.append(Vector3(natural if float(pt[1]) < 0.0 else float(pt[1]), natural, cycle_seconds(clip)))
	return _gait_cache

## Escala de tiempo de la marcha del pack a una velocidad: velocidad / velocidad natural de lo que se esta mezclando.
static func gait_scale_for(speed: float) -> float:
	if PackLibrary.json_mode():
		return JsonCatalog.cycles_per_second(speed, false)
	var table: Array[Vector3] = gait_table()
	if table.size() < 2 or speed <= 0.15:
		return 1.0
	var natural: float = table[table.size() - 1].y
	if speed < table[table.size() - 1].x:
		for i in range(1, table.size()):
			var a: Vector3 = table[i - 1]
			var b: Vector3 = table[i]
			if speed <= b.x:
				natural = lerpf(a.y, b.y, (speed - a.x) / maxf(b.x - a.x, 0.001))
				break
	return clampf(speed / maxf(natural, 0.2), 0.6, 2.2)

func gait_time_scale(speed: float) -> float:
	return gait_scale_for(speed)

static var _carry_cache: Array[Vector3] = []

## Tabla de la marcha CON balon, igual que gait_table pero con los clips de conduccion.
static func carry_gait_table() -> Array[Vector3]:
	if _carry_cache.is_empty() and PackLibrary.available():
		for pt in CARRY_GAIT_POINTS:
			var clip: StringName = pt[0]
			if not PackLibrary.has_clip(clip):
				continue
			var m: Dictionary = PackLibrary.meta(clip)
			var natural: float = float(m.get("natural_speed", 0.0))
			_carry_cache.append(Vector3(natural if float(pt[1]) < 0.0 else float(pt[1]), natural, cycle_seconds(clip)))
	return _carry_cache

static func carry_scale_for(speed: float) -> float:
	if PackLibrary.json_mode():
		return JsonCatalog.cycles_per_second(speed, true)
	var table: Array[Vector3] = carry_gait_table()
	if table.size() < 2 or speed <= 0.15:
		return 1.0
	var natural: float = table[table.size() - 1].y
	if speed < table[table.size() - 1].x:
		for i in range(1, table.size()):
			var a: Vector3 = table[i - 1]
			var b: Vector3 = table[i]
			if speed <= b.x:
				natural = lerpf(a.y, b.y, (speed - a.x) / maxf(b.x - a.x, 0.001))
				break
	return clampf(speed / maxf(natural, 0.2), 0.6, 2.2)

## Segundos entre apoyos consecutivos (un pie tras otro) de la marcha del pack a una velocidad, ya con la escala de
## tiempo con la que se reproduce. -1 si no hay libreria del pack o el jugador esta parado.
static func step_interval_for(speed: float, carry: bool = false) -> float:
	if PackLibrary.json_mode():
		if speed < 0.3 or not PackLibrary.available():
			return -1.0
		# Un ciclo son dos apoyos (un pie y el otro).
		return 0.5 / JsonCatalog.cycles_per_second(speed, carry)
	var table: Array[Vector3] = gait_table()
	if table.size() < 3 or speed < 0.3:
		return -1.0
	var cycle: float = table[1].z   # por debajo de la marcha lenta se usa el ciclo de la caminata
	if speed >= table[table.size() - 1].x:
		cycle = table[table.size() - 1].z
	elif speed > table[1].x:
		for i in range(2, table.size()):
			var a: Vector3 = table[i - 1]
			var b: Vector3 = table[i]
			if speed <= b.x:
				cycle = lerpf(a.z, b.z, (speed - a.x) / maxf(b.x - a.x, 0.001))
				break
	return cycle * 0.5 / gait_scale_for(speed)

## Dispara un clip del pack una sola vez, con velocidad de reproduccion y punto de inicio (s). Devuelve su duracion
## efectiva en segundos (0 si no hay libreria del pack). Cancela antes la accion en curso: nunca hay dos a la vez.
## play_for > 0 recorta la accion a esos segundos (con fundido de salida): p. ej. una patada solo necesita el golpeo y su continuacion.
func play_pack_clip(id: StringName, speed: float = 1.0, start: float = 0.0, play_for: float = -1.0) -> float:
	if not uses_pack or anim_tree == null or not PackLibrary.has_clip(id):
		return 0.0
	stop_current_action()
	var anim: Animation = PackLibrary.clip(id)
	var from: float = clampf(start, 0.0, maxf(anim.length - 0.1, 0.0))
	_pack_clip_node.animation = PackLibrary.anim_path(id)
	_pack_clip_node.use_custom_timeline = from > 0.0
	if from > 0.0:
		_pack_clip_node.start_offset = from
		_pack_clip_node.timeline_length = anim.length - from
		_pack_clip_node.stretch_time_scale = false
	anim_tree.set("parameters/PackScale/scale", maxf(speed, 0.05))
	anim_tree.set("parameters/PackShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	current_action = id
	_action_timer = (anim.length - from) / maxf(speed, 0.05)
	_action_cut = play_for > 0.0 and play_for < _action_timer
	if _action_cut:
		_action_timer = play_for
	return _action_timer

## Reproduce la situacion de juego pedida (AnimationCatalog): clip del pack si existe, si no el de Tripo.
## Devuelve {"source", "clip", "duration"} o {} si no hay clip para esa situacion.
## play_for > 0 recorta la accion a esos segundos (con fundido) para que no se alargue mas que la situacion que la causa.
func play_situation(situation: StringName, pick: int = 0, speed: float = 1.0, play_for: float = -1.0) -> Dictionary:
	var r: Dictionary = AnimationCatalog.resolve(situation, uses_pack, pick)
	if r.is_empty() or is_placeholder:
		return {}
	var d: float = play_pack_clip(r["clip"], speed, 0.0, play_for) if r["source"] == &"pack" else play_action(r["clip"], speed)
	if d <= 0.0:
		return {}
	r["duration"] = d
	return r

## Corta con un fundido la accion en curso (de Tripo o del pack).
func stop_current_action() -> void:
	if anim_tree == null or current_action == &"":
		return
	if _active_tripo_clip != &"":
		anim_tree.set("parameters/Shot_%s/request" % _active_tripo_clip, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		_active_tripo_clip = &""
	elif uses_pack:
		anim_tree.set("parameters/PackShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	current_action = &""
	_action_cut = false
	_action_timer = 0.0

func stop_action(clip: StringName) -> void:
	if anim_tree != null and ACTION_CLIPS.has(clip):
		anim_tree.set("parameters/Shot_%s/request" % clip, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	if current_action == clip:
		current_action = &""
		_active_tripo_clip = &""
		_action_timer = 0.0

## Inicia la patada procedural: el golpeo ocurre a los contact_time segundos. side: +1 derecha, -1 izquierda.
func start_kick(contact_time: float, power: float, side: int) -> void:
	if pose_modifier != null:
		pose_modifier.start_kick(contact_time, power, side)

func is_action_playing() -> bool:
	return current_action != &""

## Llamado cada paso de fisica por el futbolista.
## Parametros del AnimationTree que se fijan en cada imagen (drive_motion): nombres ya convertidos y valor escrito por ultima
## vez. Escribir un parametro por su texto en cada imagen costaba ~0.05 ms por jugador (tools/perf_probe); ahora solo se
## escribe cuando cambia (el AnimationTree conserva el ultimo valor).
const P_LOCO := &"parameters/Locomotion/blend_position"
const P_LOCO_SCALE := &"parameters/LocoScale/scale"
const P_CARRY_MIX := &"parameters/CarryMix/blend_amount"
const P_CARRY := &"parameters/Carry/blend_position"
const P_CARRY_SCALE := &"parameters/CarryScale/scale"
const P_TOUCH_SCALE: Array[StringName] = [&"parameters/TouchScale0/scale", &"parameters/TouchScale1/scale"]
const P_MODE_MIX := &"parameters/ModeMix/blend_amount"
const P_DIR := &"parameters/Dir/blend_position"
const P_DIR_SCALE := &"parameters/DirScale/scale"
var _param_last: Dictionary = {}

func _set_param(path: StringName, value: Variant) -> void:
	if _param_last.get(path) == value:
		return
	_param_last[path] = value
	anim_tree.set(path, value)

func update_motion(f: Footballer, delta: float) -> void:
	drive_motion(f.locomotion.speed, f.locomotion.turn_rate, delta)

## Version por valores (la usan el futbolista y el arquero): velocidad horizontal y velocidad de giro (rad/s).
func drive_motion(speed: float, turn_rate: float, delta: float) -> void:
	if is_placeholder:
		_update_placeholder(speed, delta)
		return
	if anim_tree == null:
		return
	if _action_timer > 0.0:
		_action_timer -= delta
		# La pose de una accion con raiz termina con la raiz (la libera PlayerActions): antes se apagaba un paso antes y en
		# esa imagen el cuerpo seguia moviendose con la raiz sin su pose.
		if _action_timer <= 0.0 and arbiter != null and arbiter.holds_pose(current_action):
			_action_timer = 0.0001
		elif _action_timer <= 0.0:
			var finished: StringName = current_action
			if _action_cut and uses_pack:
				anim_tree.set("parameters/PackShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
			_action_cut = false
			current_action = &""
			_active_tripo_clip = &""
			action_finished.emit(finished)
	_set_param(P_LOCO, speed)
	# Evita que los pies patinen: la cadencia sigue a la velocidad real respecto al ciclo dominante.
	var scale_factor: float = 1.0
	if uses_pack:
		# Con el pack cada clip se reproduce a su ritmo natural; solo se acelera por encima del sprint natural.
		scale_factor = gait_time_scale(speed)
	elif speed > 0.15:
		var natural: float = lerpf(NATURAL_SPEED["walk"], NATURAL_SPEED["run"], clampf((speed - 0.9) / 1.5, 0.0, 1.0))
		scale_factor = clampf(speed / natural, MIN_TIME_SCALE, MAX_TIME_SCALE)
	_set_param(P_LOCO_SCALE, scale_factor)
	if _has_carry:
		_carry_weight = move_toward(_carry_weight, 1.0 if carrying else 0.0, CARRY_BLEND_RATE * delta)
		_set_param(P_CARRY_MIX, _carry_weight)
		if _carry_weight > 0.0:
			_set_param(P_CARRY, speed)
			_set_param(P_CARRY_SCALE, carry_scale_for(speed))
			# El toque en curso avanza al mismo ritmo que la marcha con pelota (sigue en fase con su ciclo base).
			for f in 2:
				if _touch_nodes[f] != null:
					_set_param(P_TOUCH_SCALE[f], maxf(carry_scale_for(speed), 0.05))
	if uses_pack:
		_dir_weight = move_toward(_dir_weight, 1.0 if directional else 0.0, 7.0 * delta)
		_set_param(P_MODE_MIX, _dir_weight)
		if _dir_weight > 0.0:
			var ds: float = dir_velocity.length()
			var p := Vector2(dir_velocity.y, dir_velocity.x) / _dir_ref
			# Solo el lateral hacia la derecha tiene un clip rapido (Strafe_3); el resto se limita al radio 1.
			var lim: float = DIR_MAX if p.x > 0.8 and absf(p.y) < 0.5 and not json_mode else 1.0
			if p.length() > lim:
				p = p.normalized() * lim
			var ref: float = _dir_ref if json_mode else lerpf(DIR_REF_SPEED, STRAFE_FAST_SPEED, clampf((p.x - 1.0) / (DIR_MAX - 1.0), 0.0, 1.0))
			if dir_scale_override > 0.0:
				p = dir_blend_override
			_set_param(P_DIR, p)
			_set_param(P_DIR_SCALE, dir_scale_override if dir_scale_override > 0.0 else (clampf(ds / ref, 0.6, 2.2) if ds > 0.2 else 1.0))
	# Inclinacion del cuerpo (como en el video de referencia de conduccion): hacia delante con la velocidad y al
	# acelerar, hacia atras al frenar, y hacia dentro en las curvas como pide la fisica (tan = v * giro / g), algo menos.
	var accel: float = 0.0
	if delta > 0.0:
		accel = (speed - _lean_prev_speed) / delta
	_lean_prev_speed = speed
	_lean_accel = lerpf(_lean_accel, accel, 1.0 - exp(-6.0 * delta))
	# El cuerpo entero (rig) se inclina poco, como antes, para no mover los pies que tocan la pelota; la inclinacion
	# grande la lleva el tronco (ProceduralPose: columna, sin tocar caderas ni piernas).
	var target_pitch: float = clampf(speed / 7.0, 0.0, 1.0) * 0.12
	if json_mode:
		target_pitch *= 0.2   # los clips JSON ya traen la inclinacion de la carrera
	var target_roll: float = clampf(turn_rate * speed * 0.0042, -0.28, 0.28)
	var trunk_pitch: float = clampf(_lean_accel / 9.81, -LEAN_BRAKE_MAX, LEAN_ACCEL_MAX)
	if _has_carry and _carry_weight > 0.0 and not json_mode:
		trunk_pitch += CARRY_CROUCH * _carry_weight * smoothstep(0.3, 1.4, speed) * (1.0 - smoothstep(3.2, 5.0, speed))
	trunk_pitch += turn_crouch
	var trunk_roll: float = clampf(atan(turn_rate * speed / 9.81) * LEAN_TURN_GAIN, -LEAN_ROLL_MAX, LEAN_ROLL_MAX)
	var k: float = 1.0 - exp(-10.0 * delta)
	_lean_pitch = lerpf(_lean_pitch, target_pitch, k)
	_lean_roll = lerpf(_lean_roll, target_roll, k)
	_trunk_pitch = lerpf(_trunk_pitch, trunk_pitch, k)
	_trunk_roll = lerpf(_trunk_roll, trunk_roll, k)
	rig.rotation.x = -_lean_pitch
	rig.rotation.z = _lean_roll
	if pose_modifier != null:
		pose_modifier.lean_pitch = _trunk_pitch
		pose_modifier.lean_roll = _trunk_roll

# --- Maniqui provisional (solo si falta el modelo) --------------------------

func _build_placeholder(shirt_color: Color) -> void:
	is_placeholder = true
	var skin := MeshUtil.flat_material(Color(0.87, 0.67, 0.52), 0.8)
	var shirt := MeshUtil.flat_material(shirt_color, 0.8)
	var shorts := MeshUtil.flat_material(Color(0.1, 0.1, 0.15), 0.8)
	_add_mesh(_capsule(0.26, 0.7), shirt, Vector3(0, 1.2, 0))
	_add_mesh(_sphere(0.14), skin, Vector3(0, 1.68, 0))
	_add_mesh(_capsule(0.28, 0.38), shorts, Vector3(0, 0.82, 0))
	for x in [-0.12, 0.12]:
		_legs.append(_add_mesh(_capsule(0.09, 0.62), skin, Vector3(x, 0.4, 0)))
	_add_mesh(_box(Vector3(0.1, 0.1, 0.22)), MeshUtil.flat_material(Color(1, 1, 0.3), 0.5), Vector3(0, 1.45, -0.28))

func _update_placeholder(speed: float, delta: float) -> void:
	_phase += delta * (4.0 + speed * 1.6)
	var swing: float = clampf(speed / 6.0, 0.0, 1.0) * 0.55
	if _legs.size() == 2:
		_legs[0].rotation.x = sin(_phase) * swing
		_legs[1].rotation.x = -sin(_phase) * swing

func _add_mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 3
	return m

func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	return m

func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
