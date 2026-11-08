class_name PlayerTuning
extends Resource
## Parametros de locomocion, conduccion y contacto del futbolista.
## Editables en resources/tuning/player_tuning.tres.

@export_group("Velocidades (m/s)")
@export var walk_speed: float = 1.8
@export var jog_speed: float = 3.6
@export var run_speed: float = 5.2
@export var sprint_speed: float = 6.8
@export var backpedal_factor: float = 0.72

@export_group("Aceleracion")
## Aceleracion al empujar el joystick (m/s^2).
@export var accel: float = 6.2
## Desaceleracion al soltar el joystick.
@export var decel: float = 9.5
## Desaceleracion cuando el joystick apunta contra el movimiento (frenada).
@export var brake: float = 14.0
## Agarre lateral: cuanto rapido se elimina la velocidad lateral respecto al cuerpo (1/s).
@export var lateral_grip: float = 9.0

@export_group("Giro")
## Velocidad de giro parado (grados/s).
@export var turn_rate_standing: float = 620.0
## Velocidad de giro a sprint maximo (grados/s).
@export var turn_rate_sprint: float = 165.0
## Si el angulo al objetivo supera esto a mas de 70 % de la velocidad maxima, hay que frenar antes de girar.
@export var sharp_turn_angle_deg: float = 115.0

@export_group("Resistencia")
@export var stamina_drain_sprint: float = 0.16
@export var stamina_regen: float = 0.07
@export var stamina_regen_standing: float = 0.14
## Fraccion de velocidad de sprint que aun se mantiene con la resistencia agotada.
@export var exhausted_speed_factor: float = 0.82

@export_group("Conduccion")
## Distancia maxima (m) a la que puede dar un toque.
@export var touch_reach: float = 0.95
## Segundos entre toques (trote).
@export var touch_interval_jog: float = 0.28
## Segundos entre toques (sprint, toques mas largos y espaciados).
@export var touch_interval_sprint: float = 0.38
## Distancia objetivo (m) de la pelota al pie PARADO: es la que define el control cercano.
@export var carry_gap_stand: float = 0.38
## Distancia objetivo (m) a la que se coloca la pelota delante del jugador al trotar / sprintar.
@export var touch_lead_jog: float = 0.70
@export var touch_lead_sprint: float = 1.20
## Distancia (m) a la que queda la pelota al parar (soltar el joystick): pisada / parada.
@export var settle_gap: float = 0.38
## Segundos que el cuerpo conserva su orientacion tras un control lateral.
@export var lateral_hold_seconds: float = 0.40
## Intensidad maxima del joystick para que un empuje de costado sea control lateral (mas fuerte = giro normal). 0.5:
## en el movil el joystick rara vez va a fondo y con 0.75 el jugador se desplazaba de lado en vez de girar.
@export var lateral_max_stick: float = 0.5
## Radio (m) dentro del cual un rival hace que el portador proteja la pelota con el cuerpo.
@export var shield_radius: float = 2.6
## Desviacion tipica (m) de los toques largos a sprint con control 0 (disminuye con la habilidad).
@export var touch_overshoot_sprint: float = 0.82
## Toque de recuperacion: se adelanta cuando la pelota va a quedar a mas de este multiplo del alcance en 0.14 s.
@export var touch_escape_factor: float = 1.05
## Error angular base de un toque (grados) con control de balon 50.
@export var touch_error_deg: float = 4.0
## Tope (grados) del error angular de un toque aunque se sumen sprint y giro.
@export var touch_error_max_deg: float = 8.0
## Error extra por sprint (multiplicador) y por giro brusco.
@export var touch_error_sprint: float = 2.0
@export var touch_error_turn: float = 1.9
## Giro maximo (grados) que un toque de conduccion le da a la pelota caminando, al trote y a sprint (BallHandler
## .touch_turn_max_deg): entre toques la pelota rueda recta y el jugador la sigue; un cambio de rumbo mayor lleva varios
## toques, como en FTS / Ultimate Clash.
@export var touch_turn_walk_deg: float = 150.0
@export var touch_turn_jog_deg: float = 110.0
@export var touch_turn_sprint_deg: float = 70.0
## Segundos de bloqueo despues de un pase/tiro antes de poder volver a tocar la pelota.
@export var kick_lockout: float = 0.35
@export var possession_radius: float = 1.1

@export_group("Patada con animacion del pack")
## Radio (m) entre el pie (posicion de contacto medida del clip) y el centro de la pelota para que el golpeo cuente.
@export var kick_contact_radius: float = 0.30
## Modo 4 (Json): alcance (m) con el que el golpeo de un clip sigue contando aunque la pelota se haya corrido del punto
## previsto; el pie se estira hasta ella (IK) en el ultimo tramo del balanceo. Con 0.30 una de cada cinco patadas del
## partido de IA se perdia en el aire con la pelota a 0.30-0.47 m («hace la animacion pero no le da al balon»); con 0.55
## seguian perdiendose 2-4 por partido a 0.56-0.73 m en jugadas disputadas (el cuerpo empujado 0.4-1.1 m en el balanceo).
@export var json_kick_reach: float = 0.65
## Altura maxima (m) de la punta del pie y velocidad minima de avance (m/s) para que un punto de la trayectoria del clip
## cuente como golpeo: el pie debe ir bajo y lanzado, no subiendo ni frenando.
@export var kick_foot_max_height: float = 0.25
@export var kick_foot_min_speed: float = 3.0
## Ajuste de zancada: desplazamiento maximo (m) del cuerpo hacia la pelota durante la latencia para que el pie llegue.
## Crece con la velocidad (a sprint la zancada es larga): kick_adjust_max + kick_adjust_sprint * ratio de sprint.
@export var kick_adjust_max: float = 0.30
@export var kick_adjust_sprint: float = 0.28
## Error maximo (m) que se acepta al INICIAR el balanceo, medido tras el ajuste con la pelota y el jugador predichos al contacto.
@export var kick_start_residual: float = 0.18
## Latencia objetivo (s) entre soltar el boton y el golpeo; el clip se acelera/recorta para llegar a ella.
@export var kick_latency: float = 0.20
## Preparacion extra (s) del TIRO sobre kick_latency (+ shot_windup_charge con la carga al maximo): el clip arranca antes y
## a velocidad casi natural, asi se ve el balanceo de la pierna hacia atras (prueba03: el tiro duraba 0.17 s en pantalla y
## no se notaba). Los pases conservan la latencia corta.
@export var shot_windup: float = 0.12
@export var shot_windup_charge: float = 0.06
## Aceleracion maxima del clip de patada (1 = velocidad original del clip).
@export var kick_clip_speed_max: float = 1.6
## Fraccion de la velocidad de giro que se conserva mientras el pie se prepara (el pie de apoyo fija la direccion).
@export var kick_turn_scale: float = 0.35
## Segundos de continuacion del clip tras el golpeo antes de devolver el cuerpo a la marcha.
@export var kick_follow_through: float = 0.30

@export_group("Contacto con balon")
## Fraccion de energia que absorbe el control orientado (0 = rebote total).
@export var first_touch_absorb: float = 0.65
## Recepcion con clip (modo 4, JsonReceive.contact_velocity), por parte del cuerpo: Vector3(restitucion, conservacion a lo
## largo de la superficie, empuje hacia delante en m/s). Los dos primeros se escalan con lo que el jugador no amortigua
## (first_touch_absorb): un buen control deja la pelota muerta. Valores iniciales para ajustar en el juego, no medidos.
@export var receive_contact: Dictionary = {
	"foot_air": Vector3(0.15, 0.25, 0.7),
	"thigh": Vector3(0.35, 0.3, 0.6),
	"knee": Vector3(0.3, 0.35, 0.8),
	"chest": Vector3(0.15, 0.15, 0.45),
}
@export var body_mass: float = 75.0
@export var capsule_radius: float = 0.3
@export var capsule_height: float = 1.75
