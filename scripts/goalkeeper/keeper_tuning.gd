class_name KeeperTuning
extends Resource
## Parametros del arquero. Los atributos del jugador escalan estos valores dentro de limites.

@export_group("Movimiento")
@export var move_speed: float = 4.2
@export var accel: float = 14.0
## Distancia a la linea de gol a la que se posiciona por defecto (m).
@export var base_depth: float = 0.9
## Profundidad maxima al salir a achicar (m).
@export var max_depth: float = 4.2
@export var rush_speed: float = 5.6

@export_group("Reaccion")
## Segundos de reaccion con reflejos 50 (un arquero real tarda ~0.2 s en empezar a moverse tras ver salir la pelota).
@export var reaction_time: float = 0.2
## Error con que el arquero estima la velocidad lateral (y la vertical si va por el aire) del disparo al verlo salir, como
## fraccion de la velocidad de la pelota (0.05 ~ 2.9 grados; reflejos 50); se reduce a cero mientras sigue la pelota durante
## perception_time s. El error del punto de llegada crece con el tiempo que falta. Planifica y se lanza con esa estimacion.
@export var perception_error_ratio: float = 0.05
@export var perception_time: float = 0.25
## Segundos (reflejos 50) que tarda en leer el efecto del disparo: la curva se percibe al verla desviarse, no al salir
## (antes preve la pelota casi recta y corrige al replanificar).
@export var spin_read_time: float = 0.3
## Velocidad maxima (reflejos 50) a la que reproduce un clip de atajada respecto a la captura humana (antes 1.4: estiradas
## un 40 % mas rapidas que una persona, que llegaban al palo antes que cualquier tiro de 11 m).
@export var dive_speed_max: float = 1.15
## Escala del radio de contacto de las manos de cada clip (KeeperPlanner.radius_of) para planificar y resolver la atajada.
@export var contact_scale: float = 1.0
## Limite humano de las manos (reflejos 50): desde que puede moverse, las manos no llegan a un punto antes de
## hand_latency + distancia desde la posicion de espera / hand_speed (estirada al palo de futsal, ~1.5 m: ~0.45 s).
@export var hand_latency: float = 0.12
@export var hand_speed: float = 4.5
## Segundos adicionales por cada 10 m de distancia al disparo (el arquero lee antes los tiros lejanos).
@export var anticipation_gain: float = 0.05
## Velocidad minima de la pelota (m/s) para considerarla un disparo.
@export var shot_min_speed: float = 5.5
## Velocidad maxima (m/s) de un balon del propio equipo que se recibe en vez de atajarse (pase atras).
@export var backpass_speed_max: float = 11.0
## Velocidad (m/s) del arquero controlado por la persona con el joystick a fondo.
@export var manual_speed: float = 5.0
@export var prediction_horizon: float = 1.6

@export_group("Atajada")
## Alcance de las manos desde el centro del cuerpo (m).
@export var reach: float = 1.05
@export var dive_reach: float = 1.9
@export var dive_speed: float = 5.8
@export var dive_duration: float = 0.55
@export var recover_duration: float = 0.9
## Velocidad maxima de la pelota (m/s) que puede blocar con seguridad con estirada 50.
@export var catch_speed_max: float = 15.0
## Velocidad a partir de la cual solo puede desviar.
@export var deflect_speed_min: float = 9.0
@export var deflect_damping: float = 0.42
@export var hold_time_min: float = 1.1
@export var hold_time_max: float = 2.4

@export_group("Distribucion")
@export var throw_speed: float = 12.5
@export var kick_speed: float = 17.0
@export var clearance_speed: float = 21.0

@export_group("Estirada y contacto con clips")
## Segundos hacia adelante que predice la trayectoria de la pelota para anticipar los disparos.
@export var plan_horizon: float = 2.5
## Maxima distancia (m) entre manos y pelota prevista para intentar la atajada (mas lejos: no se lanza).
@export var effort_radius: float = 1.5
## Factor de velocidad de la pelota que vuelve imposible blocar el balon con ese tipo de clip (estirada = menos).
@export var dive_catch_factor: float = 0.8
## Velocidad maxima (m/s) de un balon que aun se puede desviar con las manos.
@export var parry_speed_max: float = 30.0
## Distancia (m) a la que sale a recoger una pelota suelta y lenta dentro de su area.
@export var pickup_distance: float = 5.0
@export var pickup_ball_speed_max: float = 3.0
## Distancia maxima (m) a la que un jugador rival puede estar de la pelota suelta para que salga a recogerla.
@export var pickup_opponent_clearance: float = 2.2
## Altura del ancla (m) donde sostiene la pelota parado.
@export var carry_height: float = 1.15
@export var carry_forward: float = 0.35
