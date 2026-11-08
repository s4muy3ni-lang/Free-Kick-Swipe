class_name TrajectoryPreview
extends MeshInstance3D
## Vista previa del disparo mientras el dedo esta apoyado: la trayectoria que calcula la fisica (GestureShotModel.solve,
## el mismo modelo que el tiro real) dibujada como una cinta discontinua orientada a la camara, del color de la potencia
## (verde suave -> amarillo -> rojo potente), y un aro en el punto probable de llegada al arco. Una sola malla inmediata
## (sin nodos por punto) que se rehace pocas veces por segundo.

const MAX_POINTS := 48

var _im := ImmediateMesh.new()
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D

func _ready() -> void:
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.render_priority = 2
	material_override = m
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.2
	tm.outer_radius = 0.28
	tm.rings = 16
	tm.ring_segments = 6
	_ring.mesh = tm
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.no_depth_test = true
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	add_child(_ring)
	visible = false

static func power_color(power: float) -> Color:
	if power < 0.5:
		return Color(0.35, 1.0, 0.45).lerp(Color(1.0, 0.92, 0.25), power / 0.5)
	return Color(1.0, 0.92, 0.25).lerp(Color(1.0, 0.3, 0.2), (power - 0.5) / 0.5)

## Dibuja la trayectoria hasta el plano del arco (plane_x) o hasta que se agota.
func show_path(traj: PackedVector3Array, plane_x: float, power: float, cam_pos: Vector3, crossing: Vector3) -> void:
	_im.clear_surfaces()
	var pts := PackedVector3Array()
	for p in traj:
		pts.append(p)
		if p.x >= plane_x:
			break
	if pts.size() < 2:
		visible = false
		return
	var stride: int = maxi(int(ceil(float(pts.size()) / float(MAX_POINTS))), 1)
	var sel := PackedVector3Array()
	for i in range(0, pts.size(), stride):
		sel.append(pts[i])
	if sel[sel.size() - 1] != pts[pts.size() - 1]:
		sel.append(pts[pts.size() - 1])
	var col: Color = power_color(power)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = sel.size()
	for i in range(n - 1):
		# Discontinua: un tramo si y otro no (se lee como «prevision»).
		if i % 2 == 1:
			continue
		var a: Vector3 = sel[i]
		var b: Vector3 = sel[i + 1]
		var t: Vector3 = (b - a).normalized()
		var wa: float = lerpf(0.05, 0.12, float(i) / float(n))
		var sa: Vector3 = t.cross(cam_pos - a).normalized() * wa
		var sb: Vector3 = t.cross(cam_pos - b).normalized() * wa
		var ca := Color(col.r, col.g, col.b, lerpf(0.35, 0.95, float(i) / float(n)))
		for v in [[a - sa, ca], [a + sa, ca], [b + sb, ca], [a - sa, ca], [b + sb, ca], [b - sb, ca]]:
			_im.surface_set_color(v[1])
			_im.surface_add_vertex(v[0])
	_im.surface_end()
	visible = true
	if crossing != Vector3.INF:
		_ring.visible = true
		_ring.global_position = crossing
		_ring.rotation = Vector3(0.0, 0.0, PI * 0.5)
		_ring_mat.albedo_color = Color(col.r, col.g, col.b, 0.9)
	else:
		_ring.visible = false

func hide_path() -> void:
	visible = false
	_ring.visible = false
	_im.clear_surfaces()
