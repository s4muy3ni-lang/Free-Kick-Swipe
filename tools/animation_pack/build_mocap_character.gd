extends Node
## Conversor OFFLINE del modelo del modo 2: el personaje «Newton» que trae el «Mocap Pack 05 Soccer» (version Rokoko,
## 76 huesos, ~33 000 triangulos) a baja poligonizacion (~TARGET_TRIS, como el futbolista de Tripo) con su esqueleto
## propio. La zona del kit de cada vertice (camiseta, short, medias, botines, piel, pelo) se hornea en COLOR.r segun el
## hueso que mas lo mueve (assets/characters/mocap/mocap_kit.gdshader la colorea con los colores del equipo).
## Salida: assets/characters/mocap/mocap_player.scn (versionada). En el juego lo mueve MocapRig.
## Uso: godot --headless --path . res://tools/animation_pack/build_mocap_character.tscn

const SRC := "res://pack/mocap05/rokoko/01_Dribble_01.fbx"
const OUT := "res://assets/characters/mocap/mocap_player.scn"
## Triangulos objetivo del cuerpo y de la cabeza.
const TARGET_BODY := 6500
const TARGET_HEAD := 1300

enum Zone { JERSEY, SHORTS, SOCKS, BOOTS, SKIN, HAIR }

func _ready() -> void:
	var inst: Node3D = (load(SRC) as PackedScene).instantiate()
	add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	for ap in inst.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	var total := 0
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		var head: bool = String(mi.name).contains("HeadFace")
		mi.mesh = _simplify(mi.mesh, sk, mi.skin, TARGET_HEAD if head else TARGET_BODY, head)
		total += _tris(mi.mesh)
		mi.material_override = null
	_own(inst, inst)
	var ps := PackedScene.new()
	var err: int = ps.pack(inst)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
		err = ResourceSaver.save(ps, OUT)
	print("MOCAP_CHAR guardado %s (error=%d): %d triangulos, %d huesos" % [OUT, err, total, sk.get_bone_count()])
	get_tree().quit(0 if err == OK else 1)

func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)

static func _tris(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var n: int = mesh.surface_get_array_index_len(s)
		t += (n if n > 0 else mesh.surface_get_array_len(s)) / 3
	return t

## Zona del kit por el hueso que mas pesa en el vertice.
static func _zone(bone: String, head: bool) -> int:
	if head or bone.begins_with("Head"):
		return Zone.SKIN
	if bone.contains("Foot") or bone.contains("Toe"):
		return Zone.BOOTS
	if bone.contains("Shin"):
		return Zone.SOCKS
	if bone.contains("Thigh") or bone == "Hips":
		return Zone.SHORTS
	if bone.contains("ForeArm") or bone.contains("Hand") or bone.contains("Finger") or bone == "Neck":
		return Zone.SKIN
	return Zone.JERSEY

## Reduce una malla con piel a ~target triangulos (LOD de meshoptimizer de ImporterMesh: mismos vertices y pesos,
## menos indices) y hornea la zona del kit en COLOR.
func _simplify(mesh: Mesh, sk: Skeleton3D, skin: Skin, target: int, head: bool) -> ArrayMesh:
	var src_tris: int = _tris(mesh)
	var im := ImporterMesh.new()
	var arrays_by_surface: Array = []
	for s in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		arr[Mesh.ARRAY_COLOR] = _zone_colors(arr, sk, skin, head)
		arrays_by_surface.append(arr)
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	im.generate_lods(25.0, 60.0, [])
	var ratio: float = float(target) / float(maxi(src_tris, 1))
	var out := ArrayMesh.new()
	for s in im.get_surface_count():
		var arr: Array = arrays_by_surface[s]
		var full: int = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		var best: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		# El LOD mas cercano al objetivo.
		var want: int = int(full * ratio)
		for l in im.get_surface_lod_count(s):
			var idx: PackedInt32Array = im.get_surface_lod_indices(s, l)
			if absi(idx.size() - want) < absi(best.size() - want):
				best = idx
		arr[Mesh.ARRAY_INDEX] = best
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mesh.surface_get_format(s) & ~Mesh.ARRAY_FLAG_USES_EMPTY_VERTEX_ARRAY | Mesh.ARRAY_FORMAT_COLOR)
	print("MOCAP_CHAR malla %s: %d -> %d triangulos" % ["cabeza" if head else "cuerpo", src_tris, _tris(out)])
	return out

func _zone_colors(arr: Array, sk: Skeleton3D, skin: Skin, head: bool) -> PackedColorArray:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones = arr[Mesh.ARRAY_BONES]
	var weights = arr[Mesh.ARRAY_WEIGHTS]
	var per: int = (bones.size() / maxi(verts.size(), 1)) if bones != null else 0
	var cols := PackedColorArray()
	cols.resize(verts.size())
	var head_top := -INF
	var head_bot := INF
	if head:
		for v in verts:
			head_top = maxf(head_top, v.y)
			head_bot = minf(head_bot, v.y)
	for i in verts.size():
		var z: int = Zone.SKIN if head else Zone.JERSEY
		if per > 0:
			var bw := -1.0
			var bb := -1
			for k in per:
				if weights[i * per + k] > bw:
					bw = weights[i * per + k]
					bb = bones[i * per + k]
			# Los indices de la malla son de los «binds» de la piel, no del esqueleto.
			var bone: int = bb
			if skin != null and bb >= 0 and bb < skin.get_bind_count():
				bone = skin.get_bind_bone(bb)
				if bone < 0:
					bone = sk.find_bone(skin.get_bind_name(bb))
			if bone >= 0 and bone < sk.get_bone_count():
				z = _zone(sk.get_bone_name(bone), head)
				# Muslo: el short llega a mitad del muslo y la rodilla es piel; pierna: la media empieza bajo la rodilla.
				var bname: String = sk.get_bone_name(bone)
				if (bname.contains("Thigh") or bname.contains("Shin")) and skin != null:
					var a: Vector3 = skin.get_bind_pose(bb).affine_inverse().origin
					var child: int = _first_child(sk, bone)
					if child >= 0:
						var cb: int = _bind_of(skin, sk, child)
						if cb >= 0:
							var c: Vector3 = skin.get_bind_pose(cb).affine_inverse().origin
							var u: float = clampf((verts[i] - a).dot(c - a) / maxf((c - a).length_squared(), 1e-6), 0.0, 1.0)
							if bname.contains("Thigh") and u > 0.55:
								z = Zone.SKIN
							elif bname.contains("Shin") and u < 0.12:
								z = Zone.SKIN
		if head and verts[i].y > head_bot + (head_top - head_bot) * 0.72:
			z = Zone.HAIR
		cols[i] = Color(float(z) / 8.0, 0.0, 0.0, 1.0)
	return cols

static func _first_child(sk: Skeleton3D, b: int) -> int:
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) == b:
			return i
	return -1

static func _bind_of(skin: Skin, sk: Skeleton3D, bone: int) -> int:
	for k in skin.get_bind_count():
		if skin.get_bind_bone(k) == bone or (skin.get_bind_bone(k) < 0 and sk.find_bone(skin.get_bind_name(k)) == bone):
			return k
	return -1
