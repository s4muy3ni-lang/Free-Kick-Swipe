class_name MeshUtil
extends RefCounted
## Utilidades para construir geometria ligera de forma procedural (sin nodos por celda ni por linea).

## Agrega un cuadrilatero (a,b,c,d en orden) a los arreglos. uv_u / uv_v son las dimensiones en metros.
static func add_quad(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var base: int = verts.size()
	var n: Vector3 = (b - a).cross(d - a).normalized()
	var u: float = (b - a).length()
	var v: float = (d - a).length()
	verts.append_array([a, b, c, d])
	normals.append_array([n, n, n, n])
	uvs.append_array([Vector2(0, 0), Vector2(u, 0), Vector2(u, v), Vector2(0, v)])
	indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

static func build_mesh(verts: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Crea un StaticBody3D con una caja de colision.
static func add_box_body(parent: Node3D, size: Vector3, pos: Vector3, layer: int,
		group_name: StringName = &"") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	if group_name != &"":
		body.add_to_group(group_name)
	parent.add_child(body)
	return body

static func flat_material(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

static func unshaded_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
