# GOALKEEPER — Arquero (implementado)

## Identificación

- **Responsabilidad:** un arquero por equipo (`Goalkeeper`, `CharacterBody3D` en `Ball.LAYER_KEEPERS`) que se posiciona sobre el arco, anticipa los disparos con la trayectoria predicha de la pelota, **planifica la atajada con la trayectoria de manos medida de cada clip** (`KeeperPlanner`), la ejecuta con el clip y el movimiento de raíz reales y solo cuenta el contacto si las manos llegan a la pelota. Después bloquea o desvía por impulso, sostiene la pelota (`Ball.hold`) y la saca con la mano o con el pie.
- **Estado real:** operativo en el partido (`MatchScene.with_keepers`, un arquero por equipo, registrado con `MatchContext.register_keeper`). Usa los 37 clips de `pack_keeper.res` (atajadas, estiradas, bloqueos, recogida, saques, reposo, festejos propios).
- **Última verificación:** <!-- AUTO:verified -->
2026-11-12
<!-- /AUTO -->

## Cómo funciona

| Estado (`Goalkeeper.State`) | Qué hace |
|---|---|
| `POSITION` | Se mueve sobre un arco de circunferencia delante de la línea de gol mirando la pelota; sale a achicar (`base_depth`..`max_depth`) según la distancia y la amenaza; evalúa cada disparo (`_assess_shot`: velocidad ≥ `shot_min_speed`, cruza el plano del arco dentro de `plan_horizon`). |
| `PREPARE` | Reacciona (`reaction_time` + anticipación por distancia, escalada por el atributo `reflexes`). Se **planta** y replanifica desde la posición real (`_origin_after_stop`); si la amenaza desaparece (rebote, otro jugador) cancela. |
| `ACTION` | Reproduce el clip elegido por `KeeperPlanner` (espejo incluido) con `ActionMotion` (raíz) y en el instante de contacto comprueba que las manos están dentro del radio del clip (`SAVE_CLIPS`) de la pelota real: **bloquea** si la velocidad lo permite (`catch_speed_max`, `dive_catch_factor`), **desvía** (`parry_speed_max`, `deflect_damping`) o queda **superado**. |
| `HOLD` | Sostiene la pelota (`Ball.hold`) entre `hold_time_min` y `hold_time_max`. |
| `DISTRIBUTE` | Elige lanzamiento con la mano, pase rodado o patada de despeje (`goalkeeper_drop_kick`, puntera medida) según el compañero libre; la pelota sale con `Ball.release`/`Ball.kick` en el instante de la mano/pie del clip. |

### Arquero propio manejado por la persona

`Goalkeeper.input_source` + `is_human_controlled`: cuando la persona lo lleva, **el mando manda**.

- Se mueve con el joystick (`manual_speed`) mirando siempre a la pelota; no se lanza por su cuenta mientras el
  joystick se mueve (vuelve a atajar solo tras `MANUAL_AUTO_SAVE_IDLE` = 0.3 s quieto).
- PASE / TIRO con la pelota al alcance: la atrapa si viene suave, la despeja con el pie si viene fuerte.
- Con la pelota en las manos espera la orden de saque (PASE = lanzamiento, TIRO = patada larga); si la persona
  suelta el mando saca solo tras `MANUAL_HOLD_MAX` = 8 s para no congelar la jugada.
- `MatchScene`: CAMBIO pasa al arquero cuando la jugada está en el tercio defensivo propio y él es quien mejor puede
  intervenir (`take_keeper_control`); el control vuelve al campo con otro CAMBIO o al alejarse la pelota
  (`release_keeper_control`). El indicador principal lo sigue.

### Una cedida no es un disparo

Un balón tocado por un **compañero** que llega a menos de `backpass_speed_max` (11 m/s) nunca se trata como disparo:
el arquero sale a su encuentro y lo **para con el pie** (`_receive_backpass` / `_foot_trap`), y después lo juega con
un pase de pie (`_choose_distribution` modo `foot`, clip `Soccer_Pass`). Mientras la pelota está en sus pies no la
recoge con la mano. Medido en *tests/test_control_and_keeper.gd (eliminada en la reforma; en el historial de git)*: cedida a 9 m/s → 0 estiradas; disparo rival a
16 m/s desde la misma zona → se lanza y ataja.

Recogida de pelota suelta y lenta dentro de su área (`pickup_*`): solo con clips bajos y nunca detrás de la línea de gol; si la pelota lleva ≥ 1.2 s parada en el área con rivales encima (barullo, `SCRUM_SECONDS`) la recoge igualmente. **Lectura del disparo:** si un rival cercano a la pelota está armando una patada, la reacción empieza hasta 0.22 s antes de que salga la pelota (`KICK_READ_MAX`, escalado por reflejos). Medido con tiradores reales (80 tiros desde 8–14 m a 0.5–1.2 m del centro, `ShotAssist` y clips): 74 a puerta, 22 % goles, 36 % atajadas con las manos y 42 % bloqueos con el cuerpo/desvío. Eventos: `SAVE`, `KEEPER_CATCH`, `KEEPER_DISTRIBUTE`. `stats`, `save_log` y la señal `saved(kind)` sirven para diagnóstico y pruebas.

## Piezas

| Ruta | Qué hay | Símbolos |
|---|---|---|
| `scripts/goalkeeper/goalkeeper.gd` | Entidad, máquina de estados, contacto y saque | `Goalkeeper.setup`, `Goalkeeper._assess_shot`, `Goalkeeper._evaluate_contact`, `Goalkeeper._choose_distribution` |
| `scripts/goalkeeper/keeper_planner.gd` | Planificador puro: elige clip/instante/velocidad para que las manos lleguen a la pelota; utilidades de trayectoria (`path_world`, `path_world_at_body`, `peak_speed_time`) | `KeeperPlanner.candidates`, `KeeperPlanner.plan_save`, `KeeperPlanner.hands_world` |
| `scripts/goalkeeper/keeper_tuning.gd` | Parámetros (ver tabla) | `KeeperTuning` |
| `scripts/ball/ball_predictor.gd` | Trayectoria predicha (gravedad, arrastre, rebote, rodadura), calibrada contra la física real | `BallPredictor.trajectory`, `BallPredictor.crossing_x` |
| `scripts/animation/action_motion.gd` | Movimiento de raíz del clip | `ActionMotion` |
| `scripts/assistance/shot_assist.gd` | El tiro asistido ya apunta al lado opuesto del arquero real | `ShotAssist.compute` |
| `scripts/progression/player_attributes.gd` | Atributos de arquero (`reflexes`, `positioning`, `catching`, `diving`, `aerial`, `throwing`, `kicking`, `rebound_control`) que escalan reacción, alcance y saque dentro de límites | `PlayerAttributes.KEEPER_ATTRIBUTES` |

## Mapa de parámetros (`KeeperTuning`)

<!-- AUTO:params:KeeperTuning -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `move_speed` | `4.2` | float | `scripts/goalkeeper/keeper_tuning.gd:6` | `scripts/goalkeeper/goalkeeper.gd:311`, `scripts/goalkeeper/goalkeeper.gd:505`, `scripts/goalkeeper/goalkeeper.gd:691` |  (Movimiento) |
| `accel` | `14.0` | float | `scripts/goalkeeper/keeper_tuning.gd:7` | `scripts/goalkeeper/goalkeeper.gd:314`, `scripts/goalkeeper/goalkeeper.gd:489`, `scripts/goalkeeper/goalkeeper.gd:496`, `scripts/goalkeeper/goalkeeper.gd:647` (+1) |  (Movimiento) |
| `base_depth` | `0.9` | float | `scripts/goalkeeper/keeper_tuning.gd:9` | `scripts/goalkeeper/goalkeeper.gd:198`, `scripts/goalkeeper/goalkeeper.gd:284` | Distancia a la linea de gol a la que se posiciona por defecto (m). (Movimiento) |
| `max_depth` | `4.2` | float | `scripts/goalkeeper/keeper_tuning.gd:11` | `scripts/goalkeeper/goalkeeper.gd:284`, `scripts/goalkeeper/goalkeeper.gd:285` | Profundidad maxima al salir a achicar (m). (Movimiento) |
| `rush_speed` | `5.6` | float | `scripts/goalkeeper/keeper_tuning.gd:12` | **sin uso** |  (Movimiento) |
| `reaction_time` | `0.2` | float | `scripts/goalkeeper/keeper_tuning.gd:16` | `scripts/goalkeeper/goalkeeper.gd:383` | Segundos de reaccion con reflejos 50 (un arquero real tarda ~0.2 s en empezar a moverse tras ver salir la pelota). (Reaccion) |
| `perception_error_ratio` | `0.05` | float | `scripts/goalkeeper/keeper_tuning.gd:20` | `scripts/goalkeeper/goalkeeper.gd:443` | Error con que el arquero estima la velocidad lateral (y la vertical si va por el aire) del disparo al verlo salir, como fraccion de la velocidad de la pelota (0.05 ~ 2.9 grados; reflejos 50); se reduce a cero mientras sigue la pelota durante perception_time s. El error del punto de llegada crece con el tiempo que falta. Planifica y se lanza con esa estimacion. (Reaccion) |
| `perception_time` | `0.25` | float | `scripts/goalkeeper/keeper_tuning.gd:21` | `scripts/goalkeeper/goalkeeper.gd:393`, `scripts/goalkeeper/goalkeeper.gd:443`, `scripts/goalkeeper/goalkeeper.gd:456`, `scripts/goalkeeper/goalkeeper.gd:484` |  (Reaccion) |
| `spin_read_time` | `0.3` | float | `scripts/goalkeeper/keeper_tuning.gd:24` | `scripts/goalkeeper/goalkeeper.gd:479` | Segundos (reflejos 50) que tarda en leer el efecto del disparo: la curva se percibe al verla desviarse, no al salir (antes preve la pelota casi recta y corrige al replanificar). (Reaccion) |
| `dive_speed_max` | `1.15` | float | `scripts/goalkeeper/keeper_tuning.gd:27` | `scripts/goalkeeper/goalkeeper.gd:471` | Velocidad maxima (reflejos 50) a la que reproduce un clip de atajada respecto a la captura humana (antes 1.4: estiradas un 40 % mas rapidas que una persona, que llegaban al palo antes que cualquier tiro de 11 m). (Reaccion) |
| `contact_scale` | `1.0` | float | `scripts/goalkeeper/keeper_tuning.gd:29` | `scripts/goalkeeper/keeper_planner.gd:52`, `scripts/goalkeeper/keeper_planner.gd:168`, `scripts/goalkeeper/keeper_planner.gd:308` | Escala del radio de contacto de las manos de cada clip (KeeperPlanner.radius_of) para planificar y resolver la atajada. (Reaccion) |
| `hand_latency` | `0.12` | float | `scripts/goalkeeper/keeper_tuning.gd:32` | `scripts/goalkeeper/goalkeeper.gd:468`, `scripts/setpiece/sp_keeper.gd:260`, `scripts/setpiece/sp_keeper.gd:589` | Limite humano de las manos (reflejos 50): desde que puede moverse, las manos no llegan a un punto antes de hand_latency + distancia desde la posicion de espera / hand_speed (estirada al palo de futsal, ~1.5 m: ~0.45 s). (Reaccion) |
| `hand_speed` | `4.5` | float | `scripts/goalkeeper/keeper_tuning.gd:33` | `scripts/goalkeeper/goalkeeper.gd:468`, `scripts/setpiece/sp_keeper.gd:260`, `scripts/setpiece/sp_keeper.gd:589` |  (Reaccion) |
| `anticipation_gain` | `0.05` | float | `scripts/goalkeeper/keeper_tuning.gd:35` | `scripts/goalkeeper/goalkeeper.gd:383` | Segundos adicionales por cada 10 m de distancia al disparo (el arquero lee antes los tiros lejanos). (Reaccion) |
| `shot_min_speed` | `5.5` | float | `scripts/goalkeeper/keeper_tuning.gd:37` | `scripts/goalkeeper/goalkeeper.gd:337`, `scripts/goalkeeper/goalkeeper.gd:348`, `scripts/goalkeeper/goalkeeper.gd:536`, `scripts/goalkeeper/goalkeeper.gd:1359` (+3) | Velocidad minima de la pelota (m/s) para considerarla un disparo. (Reaccion) |
| `backpass_speed_max` | `11.0` | float | `scripts/goalkeeper/keeper_tuning.gd:39` | `scripts/goalkeeper/goalkeeper.gd:353`, `scripts/goalkeeper/goalkeeper.gd:653`, `scripts/goalkeeper/goalkeeper.gd:683` | Velocidad maxima (m/s) de un balon del propio equipo que se recibe en vez de atajarse (pase atras). (Reaccion) |
| `manual_speed` | `5.0` | float | `scripts/goalkeeper/keeper_tuning.gd:41` | `scripts/goalkeeper/goalkeeper.gd:645` | Velocidad (m/s) del arquero controlado por la persona con el joystick a fondo. (Reaccion) |
| `prediction_horizon` | `1.6` | float | `scripts/goalkeeper/keeper_tuning.gd:42` | **sin uso** |  (Reaccion) |
| `reach` | `1.05` | float | `scripts/goalkeeper/keeper_tuning.gd:46` | `scripts/goalkeeper/goalkeeper.gd:616` | Alcance de las manos desde el centro del cuerpo (m). (Atajada) |
| `dive_reach` | `1.9` | float | `scripts/goalkeeper/keeper_tuning.gd:47` | **sin uso** |  (Atajada) |
| `dive_speed` | `5.8` | float | `scripts/goalkeeper/keeper_tuning.gd:48` | **sin uso** |  (Atajada) |
| `dive_duration` | `0.55` | float | `scripts/goalkeeper/keeper_tuning.gd:49` | **sin uso** |  (Atajada) |
| `recover_duration` | `0.9` | float | `scripts/goalkeeper/keeper_tuning.gd:50` | **sin uso** |  (Atajada) |
| `catch_speed_max` | `15.0` | float | `scripts/goalkeeper/keeper_tuning.gd:52` | `scripts/goalkeeper/goalkeeper.gd:798` | Velocidad maxima de la pelota (m/s) que puede blocar con seguridad con estirada 50. (Atajada) |
| `deflect_speed_min` | `9.0` | float | `scripts/goalkeeper/keeper_tuning.gd:54` | **sin uso** | Velocidad a partir de la cual solo puede desviar. (Atajada) |
| `deflect_damping` | `0.42` | float | `scripts/goalkeeper/keeper_tuning.gd:55` | `scripts/goalkeeper/goalkeeper.gd:814` |  (Atajada) |
| `hold_time_min` | `1.1` | float | `scripts/goalkeeper/keeper_tuning.gd:56` | `scripts/goalkeeper/goalkeeper.gd:854` |  (Atajada) |
| `hold_time_max` | `2.4` | float | `scripts/goalkeeper/keeper_tuning.gd:57` | `scripts/goalkeeper/goalkeeper.gd:854` |  (Atajada) |
| `throw_speed` | `12.5` | float | `scripts/goalkeeper/keeper_tuning.gd:60` | `scripts/goalkeeper/goalkeeper.gd:1038` |  (Distribucion) |
| `kick_speed` | `17.0` | float | `scripts/goalkeeper/keeper_tuning.gd:61` | `scripts/goalkeeper/goalkeeper.gd:1038`, `scripts/goalkeeper/goalkeeper.gd:1040` |  (Distribucion) |
| `clearance_speed` | `21.0` | float | `scripts/goalkeeper/keeper_tuning.gd:62` | `scripts/goalkeeper/goalkeeper.gd:636`, `scripts/goalkeeper/goalkeeper.gd:1040` |  (Distribucion) |
| `plan_horizon` | `2.5` | float | `scripts/goalkeeper/keeper_tuning.gd:66` | `scripts/goalkeeper/goalkeeper.gd:360`, `scripts/goalkeeper/goalkeeper.gd:387`, `scripts/goalkeeper/goalkeeper.gd:539` | Segundos hacia adelante que predice la trayectoria de la pelota para anticipar los disparos. (Estirada y contacto con clips) |
| `effort_radius` | `1.5` | float | `scripts/goalkeeper/keeper_tuning.gd:68` | `scripts/goalkeeper/goalkeeper.gd:399`, `scripts/goalkeeper/goalkeeper.gd:541` | Maxima distancia (m) entre manos y pelota prevista para intentar la atajada (mas lejos: no se lanza). (Estirada y contacto con clips) |
| `dive_catch_factor` | `0.8` | float | `scripts/goalkeeper/keeper_tuning.gd:70` | `scripts/goalkeeper/goalkeeper.gd:798` | Factor de velocidad de la pelota que vuelve imposible blocar el balon con ese tipo de clip (estirada = menos). (Estirada y contacto con clips) |
| `parry_speed_max` | `30.0` | float | `scripts/goalkeeper/keeper_tuning.gd:72` | `scripts/goalkeeper/goalkeeper.gd:809` | Velocidad maxima (m/s) de un balon que aun se puede desviar con las manos. (Estirada y contacto con clips) |
| `pickup_distance` | `5.0` | float | `scripts/goalkeeper/keeper_tuning.gd:74` | `scripts/goalkeeper/goalkeeper.gd:565`, `scripts/goalkeeper/goalkeeper.gd:683` | Distancia (m) a la que sale a recoger una pelota suelta y lenta dentro de su area. (Estirada y contacto con clips) |
| `pickup_ball_speed_max` | `3.0` | float | `scripts/goalkeeper/keeper_tuning.gd:75` | `scripts/goalkeeper/goalkeeper.gd:555`, `scripts/goalkeeper/goalkeeper.gd:618` |  (Estirada y contacto con clips) |
| `pickup_opponent_clearance` | `2.2` | float | `scripts/goalkeeper/keeper_tuning.gd:77` | `scripts/goalkeeper/goalkeeper.gd:571` | Distancia maxima (m) a la que un jugador rival puede estar de la pelota suelta para que salga a recogerla. (Estirada y contacto con clips) |
| `carry_height` | `1.15` | float | `scripts/goalkeeper/keeper_tuning.gd:79` | `scripts/goalkeeper/goalkeeper.gd:149`, `scripts/goalkeeper/goalkeeper.gd:855`, `scripts/goalkeeper/goalkeeper.gd:856`, `scripts/goalkeeper/goalkeeper.gd:871` (+2) | Altura del ancla (m) donde sostiene la pelota parado. (Estirada y contacto con clips) |
| `carry_forward` | `0.35` | float | `scripts/goalkeeper/keeper_tuning.gd:80` | `scripts/goalkeeper/goalkeeper.gd:855`, `scripts/goalkeeper/goalkeeper.gd:871`, `scripts/goalkeeper/goalkeeper.gd:972`, `scripts/goalkeeper/goalkeeper.gd:1078` |  (Estirada y contacto con clips) |
<!-- /AUTO -->

Los valores son el punto de partida de la calibración (ver «Pruebas»); `Tuning.keeper` los carga y se ajustan aquí, no en el código.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh goalkeeper` (y `ai_match`, que juega partidos completos con arqueros).
- `tests/test_goalkeeper.gd`: posición sobre el arco y seguimiento; el planificador encuentra un clip cuyas manos alcanzan la pelota prevista; un tiro lento a las manos se bloquea y se saca; **el contacto es real** (si la pelota está fuera del alcance de las manos no hay atajada); tasa de atajadas según velocidad y colocación. `test_save_rate_depends_on_speed_and_placement` (12 tiros al arco por velocidad, con semilla): 9 m/s → 9 de 12 (75 %), 15 m/s → 8 de 12 (67 %), 24 m/s → 5 de 12 (42 %); un tiro más fuerte es más difícil de detener.
- **No probado:** el arquero con el esqueleto vivo (render) más allá de las pruebas del pack; sin dispositivo Android.

## Dependencias

[BALL](BALL.md) (`Ball.hold/release/kick`, predictor), [ANIMATIONS](ANIMATIONS.md) y [ANIMATION_PACK](ANIMATION_PACK.md) (clips y trayectorias de manos), [PITCH](PITCH.md) (`Goal`), [MATCH](MATCH.md) (`MatchContext.keepers`), [ASSISTANCE](ASSISTANCE.md), [PROGRESSION](PROGRESSION.md).

## Tasa de atajada realista con solo la información de cada momento (E5, 2026-10-31)

Medido con `test_shot_keeper` (80 tiros por caso): el arquero atajaba el 91-94 % de los tiros colocados desde 11 m una
vez quitados los goles fantasma de la prueba (ver TESTING). Causas y arreglos, en `goalkeeper.gd` / `keeper_planner.gd`:

- **Percepción** (`_perceived`, `perception_error_ratio`, `perception_time`): error lateral proporcional a la velocidad
  del tiro que se reduce mientras lo mira; `_perceived_spin` + `spin_read_time`: el efecto se lee a medida que la pelota se
  desvía (antes la trayectoria usaba el giro exacto en el instante del disparo). La curva real de estos tiros es pequeña
  (0.05-0.17 m en 11 m), así que su efecto en la tasa es menor que el ruido.
- **Quedarse firme** (`CENTER_HOLD`, `CENTER_HOLD_TIME`): con la pelota hacia su cuerpo espera a terminar de leerla solo
  si después le quedan 0.4 s; si no, se juega ya (esperando, las bajas a 0.7 m le entraban).
- **Contacto continuo** (`CONTACT_WINDOW`, `_prev_hands/_prev_ball`): la atajada se resuelve con la menor distancia entre
  el recorrido de las manos y el de la pelota en una ventana de ±0.05 s de clip alrededor del contacto planeado. Antes se
  medía en un instante y llegaba 1-2 pasos tarde (a 19 m/s, 0.3-0.6 m): fallaba pelotas a las que había llegado.
- **Velocidad humana**: `dive_speed_max` (1.15 con reflejos 50, `_clip_speeds`) en lugar de reproducir las estiradas a
  1.4×; **límite humano de las manos** (`hand_latency` 0.12 s + distancia desde `KeeperPlanner.READY_HANDS` /
  `hand_speed` 4.5 m/s, `_hand_limits`): varios clips empiezan con la estirada ya lanzada y ponían las manos a 1.4 m en
  0.2 s. `KeeperPlanner.plan_save(..., speeds, human)` descarta los contactos más tempranos que ese límite.
- `contact_scale` (1.0): escala del radio de contacto de cada clip (medido: con el contacto continuo, bajarlo a 0.55 cambia
  poco; el límite real es el tiempo).

- **Coste** (medido headless, 362 clips candidatos del modo 4): `plan_save` bajó de 42 a 11 ms por llamada (cajas por
  muestra de manos y por segmento de la pelota que descartan sin proyectar; mismo plan en los casos medidos) y el rol de
  cada clip queda en caché (`_role_cache`). Mientras lee el disparo sin plan, el arquero reintenta cada `PLAN_RETRY`
  (0.08 s) en vez de en cada paso (eran dos planificaciones por paso).

Resultado (arquero de 60, tirador de 60 salvo indicación): al palo derecho ataja 69 %, al izquierdo 76 %, al arquero 84 %,
de lado 70 %; con un rival encima 100 % (0 goles); 18 m potente 96 %; tirador de 85: ataja 32-36 %. `test_goalkeeper`
(tasa por velocidad) en la suite.

## Planificador de atajadas mas rapido, mismo plan (2026-11-05)

`plan_save` seguia siendo el mayor tiron del partido con tiros (25 ms de media por llamada en un partido de 40 s del
contenedor, picos de 41-47 ms; el arquero replanifica cada 0.08 s mientras llega el tiro, hasta 2 llamadas por vez).
Cambios, todos exactos (mismo recorrido, mismo orden, mismas comparaciones):

- Datos fijos de los 362 candidatos en cache (`_candidate_data`, `warm_cache` al cargar el partido: manos, raiz, radio sin
  escalar, caja, estilo, duracion, recorrido de la raiz y distancia a la posicion de espera por muestra). Antes, meta, rol,
  radio y nombres por clip en cada llamada.
- Grupos de `SEG_BLOCK` tramos de la trayectoria y de `K_BLOCK` muestras de manos con su caja: un grupo se salta entero si
  su caja queda fuera del radio y no puede mejorar la mejor distancia (el mismo criterio que tramo a tramo).
- Cota inferior del puntaje por clip y velocidad (y por muestra con el recorrido): con una atajada valida ya elegida
  (puntaje < 5) que no se puede mejorar, no se mira. Los planes no validos (puntaje 5 + distancia) nunca le ganan a uno
  valido, asi que el resultado no cambia.
- Verificacion: 116 llamadas reales grabadas en dos partidos (herramienta temporal) dan **exactamente** el mismo plan con
  el codigo anterior y el nuevo; media 2.9-4.7 → 1.5-1.8 ms, peor 26-47 → 16-20 ms (tres corridas intercaladas).
- Pendiente: el peor caso (tiros que no alcanza: sin atajada valida no hay cota de puntaje) sigue en 16-20 ms en el
  contenedor.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Arquero, IA de equipos y acciones».

## Saque de arco, mano a mano y centros (2026-10-27)

- `start_goal_kick`: toma la pelota, la coloca con `goalkeeper_placing_ball(_2)` en el instante de manos más bajas y la juega con el pie (corto o largo; la persona elige con PASE/TIRO).
- **Achique** (`_lone_attacker`, `rushing`): con un rival solo hacia el arco sale a `RUSH_GAP` de la pelota; `_try_smother` se lanza a los pies si el portador se adelanta la pelota.
- **Centros** (`_cross_landing`, `_assess_cross`): va al punto de caída y sale si la alcanza antes que nadie; en la preparación ajusta los pasos para que las manos del clip coincidan con la pelota.
- `goalkeeper_miss(_mirror)` para la estirada que no llega; `goalkeeper_idle_2` con la pelota en las manos (la pelota sigue sus manos); `goalkeeper_directing(_2)` como indicaciones. En penal espera en la línea.

## Reacción del arquero de UCS (2026-11-06)

Probado y **no aplicado**: la reacción del arquero de UCS, `ResponseGKSave0/1` = 15/4 cuadros (0.25 a 0.07 s según
reflejos; `UcsParams.RESPONSE_GK_SAVE_S`). Sobre nuestro modelo de estirada atajaba el 87-97 % de los tiros a 8-11 m y
`test_shot_keeper` ya no distinguía el tiro con un rival encima. Queda la reacción calibrada propia (0.30 a 0.13 s). Ver
[MATCH](MATCH.md#ia-con-los-parámetros-de-ucs-2026-11-06).



## Continuación de integración (2026-11-07)

SHOT valida golpeador y dirección reales antes de activar lectura; shots_seen se separa de amenazas shots_faced. Giros de orientación se interrumpen ante peligro. Prueba física independiente de disparo al arco: test_keeper_shot_read. [Evidencia](../../integration/continuacion/README.md).
