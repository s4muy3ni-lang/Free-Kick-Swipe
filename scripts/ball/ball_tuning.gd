class_name BallTuning
extends Resource
## Parametros fisicos y de impulsos de la pelota (balon de futsal talla 4).
## Todos los valores se pueden editar en resources/tuning/ball_tuning.tres.

@export_group("Cuerpo")
## Radio real en metros (circunferencia ~63 cm).
@export var radius: float = 0.1
## Masa en kg (futsal: 400-440 g).
@export var mass: float = 0.42
## Escala solo visual para que se lea bien con camara alta (no afecta a la fisica).
@export var visual_scale: float = 1.25

@export_group("Contacto")
## Coeficiente de restitucion. El balon de futsal rebota ~50-60 % de la altura de caida.
@export_range(0.0, 1.0) var bounce: float = 0.54
@export_range(0.0, 2.0) var friction: float = 0.6
@export var angular_damp: float = 0.01

@export_group("Resistencia")
## Cd del balon en el aire.
@export var drag_coefficient: float = 0.25
@export var air_density: float = 1.2
## Rodadura sobre el piso: desaceleracion = rolling_decel + rolling_viscous * v. La parte constante (m/s^2) es la que
## detiene del todo una pelota lenta.
@export var rolling_decel: float = 0.3
## Parte proporcional a la velocidad (1/s), como en First Touch Soccer: alli la pelota conserva 1006/1024 de su velocidad
## por imagen a 60 Hz (1.06/s; medido en su libreria, CBallProj::Iterate). Con ella cada toque de conduccion sale
## disparado, frena y espera al jugador (antes, con 0.55 m/s^2 constantes, la pelota rodaba a la par del jugador como
## atada a una cuerda), y los pases salen rapidos y se apagan.
@export var rolling_viscous: float = 1.0
## Velocidad (m/s) por encima de la cual la parte proporcional deja de crecer (desaceleracion constante a + c vk): la
## conduccion (toques de hasta ~7 m/s) va como en FTS y un pase o tiro fuerte por el suelo pierde ~20 % en 15 m en
## vez de apagarse (con 1/s puro un tiro raso de 25 m/s llegaba a 10 m/s a 15 m).
@export var rolling_viscous_knee: float = 7.0
## Perdida de giro sobre el piso (rad/s^2).
@export var spin_decel_ground: float = 6.0
## Coeficiente tipo Magnus: F = k * (omega x v).
@export var magnus_k: float = 0.0018
## Red del arco (GoalNet): tela atada al marco que la pelota abomba. Rigidez (aceleracion por metro abombado, 1/s^2):
## un tiro de 27 m/s la abomba ~0.5 m y se frena en ~0.05 s.
@export var net_stiffness: float = 1800.0
## Amortiguacion (fraccion de la critica) mientras la pelota empuja la red y mientras la red la devuelve (mayor: la tela
## se queda la energia y la pelota cae dentro en lugar de rebotar).
@export_range(0.0, 2.0) var net_damp_in: float = 0.25
@export_range(0.0, 2.0) var net_damp_out: float = 1.2
## Fraccion de la rigidez con la que la tela empuja de vuelta a la pelota (la red real casi no devuelve energia).
@export_range(0.0, 1.0) var net_return: float = 0.05
## Frenado (1/s) del movimiento a lo largo de la tela y del giro mientras la pelota esta metida en ella.
@export var net_grip: float = 7.0
## Abombado maximo (m): a partir de ahi la tela ya no cede.
@export var net_max_bulge: float = 0.6
@export var max_speed: float = 38.0
@export var max_spin: float = 150.0

@export_group("Pase")
## Velocidad minima (m/s) de un pase raso a un companero (antes 4: los pases cortos se sentian flojos).
@export var pass_speed_min: float = 7.0
@export var pass_speed_max: float = 28.0
## Velocidad a la que queremos que el pase raso llegue al receptor (antes 4.5: «los pases se sienten debiles»; en First
## Touch y Dream League el pase llega tenso al pie).
@export var pass_arrival_speed: float = 6.0
@export var lob_angle_deg: float = 38.0
@export var driven_pass_extra: float = 1.25

@export_group("Tiro")
## Tiro flojo / a carga maxima (m/s). prueba03: «shootar se siente horrible, necesita mas potencia» (antes 9 y 27).
@export var shot_speed_min: float = 12.0
@export var shot_speed_max: float = 30.0
## Segundos para cargar el tiro al maximo.
@export var shot_charge_time: float = 0.9
@export var shot_loft_low_deg: float = 4.0
@export var shot_loft_high_deg: float = 22.0
## Factor de efecto (spin) aplicado segun la desviacion lateral del golpeo.
@export var shot_spin_factor: float = 14.0
