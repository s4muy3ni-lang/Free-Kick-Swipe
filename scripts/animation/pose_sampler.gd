class_name PoseSampler
extends RefCounted
## Aplica una Animation a un Skeleton3D evaluando directamente sus pistas (sin AnimationPlayer).
## Util para herramientas (medicion de ciclos, capturas de poses) y para mezclar poses a mano.

## Cache: pista -> indice de hueso, para no resolver nombres cada vez.
static func bind(anim: Animation, skeleton: Skeleton3D) -> Dictionary:
	var bind_map: Dictionary = {}
	for t in anim.get_track_count():
		var path: String = str(anim.track_get_path(t))
		var colon: int = path.find(":")
		if colon < 0:
			continue
		var bone_name: String = path.substr(colon + 1)
		var idx: int = skeleton.find_bone(bone_name)
		if idx >= 0:
			bind_map[t] = idx
	return bind_map

static func apply(anim: Animation, skeleton: Skeleton3D, bind_map: Dictionary, time: float) -> void:
	for t in bind_map.keys():
		var bone: int = bind_map[t]
		match anim.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, anim.position_track_interpolate(t, time))
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(t, time))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone, anim.scale_track_interpolate(t, time))
	skeleton.force_update_all_bone_transforms()

## Transformacion de un hueso respecto al esqueleto, compuesta a mano desde las poses locales
## (no depende de la cache de poses globales del motor).
static func bone_in_skeleton(skeleton: Skeleton3D, bone: int) -> Transform3D:
	var chain: Array[int] = []
	var b: int = bone
	while b >= 0:
		chain.append(b)
		b = skeleton.get_bone_parent(b)
	var t := Transform3D.IDENTITY
	for i in range(chain.size() - 1, -1, -1):
		t = t * skeleton.get_bone_pose(chain[i])
	return t
