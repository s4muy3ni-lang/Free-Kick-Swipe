class_name PlayerMarker
extends MeshInstance3D
## Indicador 3D sobre la cabeza de un futbolista. Hay dos: el del jugador que maneja la persona (lleno y brillante)
## y el del jugador al que pasaria el control con CAMBIO (mas pequeno, hueco y de otro color).
##
## Se dibuja siempre encima del resto (sin prueba de profundidad y sin sombras) para que no lo tapen los cuerpos,
## y se coloca por encima de la cabeza del modelo sin taparla. No es hijo del futbolista: sigue su posicion real
## cada paso, asi no hereda el giro ni la inclinacion del cuerpo.

## Altura (m) a la que flota la punta del indicador sobre el suelo del jugador.
const HEIGHT := 2.18
## Amplitud y ritmo del balanceo vertical (para que se distinga de un elemento fijo del decorado).
const BOB := 0.05
const BOB_RATE := 3.4

var _phase: float = 0.0

## Crea el indicador. primary: el del jugador controlado (true) o el del siguiente (false).
static func make(primary: bool) -> PlayerMarker:
	var m := PlayerMarker.new()
	m.name = "PlayerMarker" if primary else "NextPlayerMarker"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.26 if primary else 0.19
	cone.bottom_radius = 0.0
	cone.height = 0.44 if primary else 0.34
	cone.radial_segments = 4
	cone.rings = 0
	m.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.25, 0.95, 1.0) if primary else Color(1.0, 0.86, 0.25, 0.65)
	if not primary:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.disable_receive_shadows = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.rotation.z = PI          # la punta mira hacia abajo, al jugador
	m.visible = false
	return m

## Coloca el indicador sobre `target` (o lo oculta si no hay jugador). delta anima el balanceo.
func follow(target: Node3D, delta: float) -> void:
	if target == null or not is_instance_valid(target):
		visible = false
		return
	visible = true
	_phase += delta * BOB_RATE
	global_position = target.global_position + Vector3(0.0, HEIGHT + sin(_phase) * BOB, 0.0)
