class_name GroundRing
extends MeshInstance3D
## Aro plano en el suelo bajo un futbolista. Dos usos en el partido:
##  - POSESION: bajo el unico jugador que tiene la pelota (MatchContext.possessor), con el color de su equipo; asi se
##    sabe en todo momento quien la tiene y si la pelota esta suelta (sin aro).
##  - OBJETIVO DEL PASE: bajo el companero que recibiria el pase si la persona pulsara PASE ahora (la misma eleccion que
##    PassAssist.pick_target), mas fino y blanco.
## No es hijo del jugador (no hereda su giro) y se dibuja sin sombras, apenas por encima del cesped.

const LIFT := 0.035

## Crea el aro. radius: radio medio (m); thickness: ancho del trazo (m).
static func make(ring_name: String, color: Color, radius: float, thickness: float) -> GroundRing:
	var r := GroundRing.new()
	r.name = ring_name
	var torus := TorusMesh.new()
	torus.inner_radius = radius - thickness * 0.5
	torus.outer_radius = radius + thickness * 0.5
	torus.rings = 32
	torus.ring_segments = 4
	r.mesh = torus
	r.scale = Vector3(1.0, 0.08, 1.0)   # aplastado: un trazo en el suelo, no un anillo con volumen
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_receive_shadows = true
	r.material_override = mat
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.visible = false
	return r

## Coloca el aro bajo target (o lo oculta si es null).
func follow(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		visible = false
		return
	visible = true
	global_position = Vector3(target.global_position.x, LIFT, target.global_position.z)

func set_color(c: Color) -> void:
	(material_override as StandardMaterial3D).albedo_color = c
