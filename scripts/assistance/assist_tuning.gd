class_name AssistTuning
extends Resource
## Parametros de las asistencias (pase, tiro, presion). El nivel va de 0 (sin ayuda) a 1 (maximo).
## La asistencia corrige la DIRECCION y la fuerza dentro de limites; nunca garantiza el resultado.

enum Level { OFF, LOW, MEDIUM, HIGH }

const LEVEL_VALUES: Dictionary = {
	Level.OFF: 0.0,
	Level.LOW: 0.35,
	Level.MEDIUM: 0.65,
	Level.HIGH: 0.95,
}

@export_group("Pase")
@export_range(0.0, 1.0) var pass_assist: float = 0.65
## Angulo maximo entre la direccion del joystick y un companero para considerarlo.
@export var pass_cone_deg: float = 60.0
## Con asistencia media o alta, cono (grados) en el que se busca companero cuando ninguno cae en el normal.
@export var pass_fallback_cone_deg: float = 85.0
## Alcance maximo de busqueda (m).
@export var pass_max_distance: float = 24.0
## Correccion angular maxima (grados) por unidad de asistencia, con asistencia baja (con media o alta el pase va al
## companero elegido: PassAssist.FULL_AIM_LEVEL).
@export var pass_max_correction_deg: float = 30.0
@export var pass_weight_angle: float = 1.0
@export var pass_weight_distance: float = 0.35
@export var pass_weight_lane: float = 0.8
## Radio de un rival para bloquear la linea de pase.
@export var pass_lane_block_radius: float = 0.8
## Error base de pase en grados (atributo de precision 50, 8 m).
@export var pass_error_deg: float = 2.6

@export_group("Tiro")
@export_range(0.0, 1.0) var shot_assist: float = 0.55
@export var shot_cone_deg: float = 38.0
@export var shot_max_correction_deg: float = 10.0
## Margen (m) que se deja respecto a los postes al apuntar.
@export var shot_post_margin: float = 0.28
@export var shot_error_deg: float = 2.2

@export_group("Presion defensiva")
@export_range(0.0, 1.0) var press_assist: float = 0.7
## Segundos hacia delante para predecir la posicion de intercepcion.
@export var press_lookahead: float = 0.55
## Distancia a la que el defensor se mantiene (m) antes de disputar.
@export var press_standoff: float = 1.4
## Distancia a la que se intenta quitar la pelota (m).
@export var press_tackle_range: float = 0.90
## Cuanto rodea el defensor al portador para atacar la pelota por el lado libre (m mas alla de la pelota).
@export var press_around_offset: float = 0.30
@export var press_speed_factor: float = 0.93
## Cuanto influye el joystick (0..1) en el angulo de aproximacion.
@export var press_stick_influence: float = 0.55
## Segundos de enfriamiento entre intentos de robo.
@export var press_tackle_cooldown: float = 1.3

func set_all_levels(level: Level) -> void:
	var v: float = LEVEL_VALUES[level]
	pass_assist = v
	shot_assist = v
	press_assist = v
