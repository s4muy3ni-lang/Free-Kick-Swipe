# F3 — Verificación visual de los 70 clips pendientes

> Continuación de F3 (2026-10-30). Manda sobre la columna «PENDIENTE DE VERIFICACION» de [`F3_auditoria_124_clips.md`](F3_auditoria_124_clips.md) para estos 70 clips. Lo que aquí no está verificado sigue `pending`.

## Método

- Herramienta: `tools/json_anim/receive_view.tscn` con `CLIP=<id>` (nuevo): reproduce el clip sin pasar por la selección automática y lanza la pelota (física real, con tiros de calibración) para que llegue a la parte del cuerpo supuesta en el instante supuesto. Antes del clip el jugador no se mueve ni gira.
- Evidencia por clip: tira de 6 imágenes cada 6 pasos (0.1 s) centrada en el contacto (3 antes, contacto, 2 después), con la trayectoria prevista (puntos amarillos) y el punto de contacto supuesto (rojo); y por consola, la parte del esqueleto VIVO más cercana a la pelota en el contacto, el primer paso en que cada parte queda a menos de 0.12 m de la pelota, la geometría de la pierna en el instante (elevación del muslo y de la tibia, alturas) y el desvío del cuerpo respecto del previsto.
- Pasadas: (1) hipótesis del perfil (parte «leg» → muslo), todos los clips; (2) repetida tras corregir la herramienta (rumbo fijo antes del clip, pelota rasante con efecto, calibración); (3) hipótesis alternativas (pie, pie en el aire, rodilla, pecho) para los clips donde la (2) no mostraba gesto. Tiras regenerables con el comando del final.
- Criterio «verificado»: el contacto ocurre en el instante previsto, la parte viva más cercana es la supuesta, en la imagen la parte va a la pelota (muslo visiblemente levantado bajo ella, pecho presentado, pie que la para o amortigua) y la pelota queda controlada delante. «No verificado»: instante al final del clip o después, gesto ausente o contradictorio con el nombre, otra parte o ninguna. **Ninguno se marca verificado sin la tira de imágenes.**
- Lo que NO se comprobó: la dirección de llegada que indica el nombre en los clips sin `from_deg` (se lanzó de frente al cuerpo en el contacto); el comportamiento en Android; la respuesta de la pelota tras el contacto como criterio de calidad (solo como señal de control).

## Resultado

| | Clips |
|---|---|
| Verificados (pasan a `usable` o `conditional` según sus condiciones) | 45: muslo 19, pecho 15, pie en el aire 7, pie 4 |
| No verificados (siguen `pending`) | 25 |
| …de ellos, instante estimado al final del clip o después (la cinemática tomó la pose final) | 11 |
| Perfiles tras regenerar (124) | usable 50, conditional 45, pending 25, not_reception 4 (antes 23 / 27 / 70 / 4) |

Rodilla y cabeza siguen sin clip verificado (1326 como rodilla y 0590 como cabeza no se confirmaron).

## Tabla por clip

Orden de prioridad pedido. «Instante» = tiempo del clip del primer contacto usado en la prueba (el del perfil salvo en las hipótesis alternativas). Estado = el del perfil regenerado.

| # | ID | Nombre original | Categoría (rol) | Grupo | Parte observada | Instante (s) | Resultado | Confianza | Estado | Observaciones |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `jn_receive_0596` | EXE222_JOG_TO_FWD_CONTROL_ON_CHEST_TO_JOG | receive | 1 · en carrera / globo | — | 0.800 | NO VERIFICADO | — | pending | t estimado = final del clip (0.80 de 0.817 s): la pelota llega al pecho en el ultimo fotograma, sin gesto de control despues |
| 2 | `jn_receive_0604` | EXE235_STAND_BALL_IN_FROM_R_45_CONTROL_2 | receive | 1 · en carrera / globo | muslo | 0.333 | VERIFICADO | media-alta | conditional | muslo izquierdo levantado (76 grados) bajo la pelota de 45 grados; la pelota cae por el muslo y queda delante (0.41 m) |
| 3 | `jn_receive_0616` | EXE239_STAND_BALL_IN_FROM_FORWARD__GOES_OVERHEAD_TURN_L_180_JOG_DRIBBLE | receive | 1 · en carrera / globo | — | 0.300 | NO VERIFICADO | — | pending | la rodilla sube a la pelota en t pero el nombre dice que la pelota pasa por encima y gira 180 grados: el gesto supuesto contradice el clip |
| 4 | `jn_receive_0622` | EXE245_JOG_FORWARD_BALL_COMES_FROM_R_SHOULDER_HEIGHT_TO_FORWARD_JOG_DRIBBLE | receive | 1 · en carrera / globo | muslo | 0.367 | VERIFICADO | media | conditional | muslo izquierdo (56 grados) con salto corto; la pelota de costado cae delante (0.66 m) |
| 5 | `jn_receive_1830` | FT1009_MOVING_CONTROL_AIR_90_4_JOSH_CTRL | receive | 1 · en carrera / globo | muslo | 0.333 | VERIFICADO | media-alta | conditional | muslo derecho levantado (76 grados), brazos abiertos, pelota de frente amortiguada (0.32 m); la llegada a 90 grados del nombre no se comprobo |
| 6 | `jn_receive_1834` | FT1009_MOVING_CONTROL_AIR_90_6_JOSH_CTRL | receive | 1 · en carrera / globo | muslo | 0.300 | VERIFICADO | media-alta | conditional | muslo derecho (74 grados) en carrera (1.86 m/s), pelota amortiguada (0.29 m); llegada a 90 grados del nombre no comprobada |
| 7 | `jn_receive_1840` | FT1009_MOVING_CONTROL_AIR_90_JOSH_CTRL | receive | 1 · en carrera / globo | — | 0.233 | NO VERIFICADO | — | pending | muslo derecho poco levantado (56 grados) y la pelota da en la cadera: gesto de control no claro (criterio: muslo visiblemente levantado bajo la pelota) |
| 8 | `jn_receive_2158` | FT1214_CONTROL_CHEST_FWD_8_COLIN_D | receive | 1 · en carrera / globo | pecho | 0.333 | VERIFICADO | media-alta | conditional | pecho con brazos abiertos en carrera (2.34 m/s), la pelota cae delante; despues hay un golpeo (post_action) |
| 9 | `jn_receive_2482` | FT1443_CONTROL_HIGH_03_ARMANI | receive | 1 · en carrera / globo | pecho | 0.300 | VERIFICADO | alta | usable | tronco arqueado hacia atras y pecho a la pelota, cae delante (0.62 m) |
| 10 | `jn_receive_2486` | FT1443_CONTROL_HIGH_05_ARMANI | receive | 1 · en carrera / globo | pecho | 0.267 | VERIFICADO | alta | usable | pecho adelantado con rodillas flexionadas, la pelota cae delante (0.73 m) |
| 11 | `jn_receive_3168` | FT1630_CONTROL_HIGH_07_DAVID | receive | 1 · en carrera / globo | muslo | 0.333 | VERIFICADO | media | usable | pierna izquierda extendida (muslo 80 grados, tibia 50 grados) como en 0586 (verificado en F3); la pelota cae por la pierna (0.38 m) |
| 12 | `jn_receive_turn_2140` | FT1214_CONTROL_CHEST_FWD_3_NOEL | receive_turn | 1 · en carrera / globo | — | 0.233 | NO VERIFICADO | — | pending | la pelota llega al hombro/cabeza con el tronco girado; el pecho no se presenta a la pelota |
| 13 | `jn_receive_turn_2146` | FT1214_CONTROL_CHEST_FWD_5_NOEL | receive_turn | 1 · en carrera / globo | — | 0.800 | NO VERIFICADO | — | pending | t estimado = final del clip (0.80 de 0.80 s): el clip termina antes de la ventana de contacto |
| 14 | `jn_receive_turn_2150` | FT1214_CONTROL_CHEST_FWD_6_NOEL_D | receive_turn | 1 · en carrera / globo | pecho | 0.333 | VERIFICADO | media | conditional | la pelota da en el lado izquierdo del pecho con el tronco algo girado y sale hacia delante (1.28 m); el giro de 69 grados viene despues |
| 15 | `jn_receive_turn_2164` | FT1215_RUNNING_OVERHEAD_CONTROL_COLIN | receive_turn | 1 · en carrera / globo | pie en el aire | 0.300 | VERIFICADO | media-alta | conditional | hipotesis alternativa: pie levantado por encima de la rodilla (tibia 105 grados, punta a 0.81 m) recibe la pelota alta (nombre OVERHEAD) y la deja a sus pies (0.29 m) |
| 16 | `jn_receive_turn_3158` | FT1630_CONTROL_HIGH_01_DAVID | receive_turn | 1 · en carrera / globo | — | 0.800 | NO VERIFICADO | — | pending | t estimado = final del clip (0.80 de 0.817 s); el pie no esta en la pelota (punta a 0.23 m) |
| 17 | `jn_receive_turn_3170` | FT1630_CONTROL_HIGH_09_DAVID | receive_turn | 1 · en carrera / globo | — | 0.767 | NO VERIFICADO | — | pending | t estimado (0.767 s) posterior al final del clip (0.733 s) |
| 18 | `jn_receive_turn_3174` | FT1630_CONTROL_HIGH_11_DAVID | receive_turn | 1 · en carrera / globo | — | 1.233 | NO VERIFICADO | — | pending | t estimado = final del clip (1.233 de 1.233 s) |
| 19 | `jn_receive_turn_0608` | EXE236_STAND_BALL_IN_FROM_R_45_HIGH_TURN | receive_turn | 2 · receive_turn | muslo | 0.267 | VERIFICADO | media | conditional | pierna izquierda extendida (muslo 91 grados) bajo la pelota de 45 grados; cae por la pierna (0.65 m) y luego gira |
| 20 | `jn_receive_turn_2132` | FT1212_CONTROL_CHEST_FWD_NOEL_D | receive_turn | 2 · receive_turn | — | 0.800 | NO VERIFICADO | — | pending | t estimado = final del clip (0.80 de 0.817 s): la pelota pasa junto al pecho con el jugador erguido, sin gesto |
| 21 | `jn_receive_turn_2136` | FT1213_CONTROL_CHEST_FWD_2_COLIN_CTRL | receive_turn | 2 · receive_turn | pecho | 0.267 | VERIFICADO | alta | conditional | pecho adelantado con brazos abiertos, la pelota cae delante (0.82 m); el giro (-98 grados) viene despues |
| 22 | `jn_receive_turn_2144` | FT1214_CONTROL_CHEST_FWD_4_NOEL_D | receive_turn | 2 · receive_turn | pecho | 0.267 | VERIFICADO | alta | conditional | tronco muy echado atras con brazos abiertos: pecho a la pelota, cae delante (0.50 m) |
| 23 | `jn_receive_turn_2148` | FT1214_CONTROL_CHEST_FWD_6_NOEL | receive_turn | 2 · receive_turn | — | 1.033 | NO VERIFICADO | — | pending | t estimado = final del clip (1.033 de 1.05 s): la pelota llega cuando el jugador ya camina erguido |
| 24 | `jn_receive_turn_2152` | FT1214_CONTROL_CHEST_FWD_7_COLIN | receive_turn | 2 · receive_turn | pecho | 0.300 | VERIFICADO | alta | conditional | pecho con rodillas flexionadas, la pelota muere a sus pies (0.36 m) |
| 25 | `jn_receive_turn_2156` | FT1214_CONTROL_CHEST_FWD_8_COLIN | receive_turn | 2 · receive_turn | pecho | 0.367 | VERIFICADO | media | conditional | la pelota da en la parte alta del pecho mientras el cuerpo gira (96 grados); queda a 0.79 m |
| 26 | `jn_receive_turn_2160` | FT1214_CONTROL_CHEST_FWD_9_COLIN | receive_turn | 2 · receive_turn | pecho | 0.333 | VERIFICADO | alta | conditional | pecho con brazos abiertos, la pelota cae delante (0.66 m) y despues empieza el giro (-182 grados) |
| 27 | `jn_receive_turn_2162` | FT1214_CONTROL_CHEST_FWD_9_COLIN_D | receive_turn | 2 · receive_turn | pecho | 0.400 | VERIFICADO | alta | conditional | pecho con brazos abiertos, la pelota cae delante (1.08 m) |
| 28 | `jn_receive_turn_2476` | FT1442_CONTROL_MEDIUM_02_ARMANI | receive_turn | 2 · receive_turn | muslo | 0.333 | VERIFICADO | media | conditional | muslo izquierdo levantado (85 grados) con el pie adelantado; la pelota cae por la pierna (0.44 m) |
| 29 | `jn_receive_turn_3152` | FT1628_CONTROL_MEDIUM_05_DAVID | receive_turn | 2 · receive_turn | — | 0.133 | NO VERIFICADO | — | pending | en t la pierna esta casi vertical (muslo 32 grados): no hay gesto de control; la pelota solo choca con la cadera |
| 30 | `jn_receive_turn_3154` | FT1629_CONTROL_MEDIUM_07_DAVID | receive_turn | 2 · receive_turn | muslo | 0.167 | VERIFICADO | media-baja | conditional | muslo izquierdo levantado (51 grados) con brazos abiertos, la pelota cae (0.56 m) y gira |
| 31 | `jn_receive_turn_3156` | FT1629_CONTROL_MEDIUM_08_ADAM | receive_turn | 2 · receive_turn | — | 0.200 | NO VERIFICADO | — | pending | muslo poco levantado (41 grados): la pelota da en la parte alta del muslo sin gesto claro de control |
| 32 | `jn_receive_1822` | FT1008_MOVING_CONTROL_AIR_FWD_JOSH_CTRL_CHEST | receive | 3 · pecho | pecho | 0.233 | VERIFICADO | alta | usable | pecho con brazos abiertos, la pelota cae delante (1.02 m) |
| 33 | `jn_receive_2130` | FT1212_CONTROL_CHEST_FWD_NOEL | receive | 3 · pecho | pecho | 0.333 | VERIFICADO | media | usable | la pelota da en la parte alta del pecho con la rodilla izquierda levantada (salto corto) y brazos adelante; sale hacia delante (0.98 m) |
| 34 | `jn_receive_2134` | FT1213_CONTROL_CHEST_FWD_1_COLIN | receive | 3 · pecho | pecho | 0.333 | VERIFICADO | media-alta | usable | pecho con el tronco algo atras, la pelota cae delante (0.84 m) |
| 35 | `jn_receive_2142` | FT1214_CONTROL_CHEST_FWD_4_NOEL | receive | 3 · pecho | — | 0.900 | NO VERIFICADO | — | pending | t estimado = final del clip (0.90 de 0.917 s) |
| 36 | `jn_receive_2488` | FT1443_CONTROL_HIGH_08_MAX | receive | 3 · pecho | pecho | 0.333 | VERIFICADO | media-alta | usable | tronco atras y pecho a la pelota, rebota poco y cae delante (0.82 m) |
| 37 | `jn_ball_start_1800` | FT1007_MOVING_CONTROL_GROUND_FWD_3_MAX_CTRLA | ball_start | 4 · pierna | pie (a ras de piso) | 0.167 | VERIFICADO | media | usable | hipotesis alternativa (el nombre dice pelota rasante: GROUND): el pie izquierdo para la pelota rodando en marcha y queda a sus pies (0.32 m); con el muslo (pasada 2) no habia gesto |
| 38 | `jn_ball_start_3066` | FT1625_CONTROL_STAND_01_DAVID | ball_start | 4 · pierna | pie en el aire | 0.200 | VERIFICADO | media | usable | hipotesis alternativa: el pie derecho amortigua una pelota con bote bajo (0.22 m) y muere a sus pies (0.18 m); con el muslo no habia gesto |
| 39 | `jn_ball_start_3092` | FT1626_CONTROL_STAND_11_DAVID | ball_start | 4 · pierna | muslo | 0.267 | VERIFICADO | media-alta | usable | muslo izquierdo horizontal (87 grados) bajo la pelota, cae por la pierna (0.56 m) |
| 40 | `jn_control_stand_1326` | FT0738_CONTROL_STAND_5_ANDYS | control_stand | 4 · pierna | — | 0.367 | NO VERIFICADO | — | pending | pierna extendida muy alta (muslo 119 grados): con muslo o rodilla la pelota rebota lejos (1.42 m); parece mas un golpeo que un control |
| 41 | `jn_control_stand_2428` | FT1434_CONTROL_MOVE_00_ARMANI | control_stand | 4 · pierna | pie (a ras de piso) | 0.300 | VERIFICADO | media-alta | usable | hipotesis alternativa: el pie izquierdo adelantado para la pelota rodando (queda a 0.56 m, quieta); con el muslo no habia gesto |
| 42 | `jn_control_stand_2430` | FT1434_CONTROL_MOVE_03_ARMANI | control_stand | 4 · pierna | pie en el aire | 0.333 | VERIFICADO | media | usable | hipotesis alternativa: el pie izquierdo adelantado amortigua una pelota con bote bajo (0.22 m), queda quieta a 0.54 m |
| 43 | `jn_control_stand_2432` | FT1434_CONTROL_MOVE_04_ARMANI | control_stand | 4 · pierna | pie (a ras de piso) | 0.267 | VERIFICADO | media | usable | hipotesis alternativa: el pie derecho para la pelota rodando (0.75 m, casi quieta); con el muslo no habia gesto |
| 44 | `jn_control_stand_2442` | FT1435_CONTROL_STAND_03_MAX | control_stand | 4 · pierna | muslo | 0.267 | VERIFICADO | media-baja | usable | muslo izquierdo algo levantado (56 grados), la pelota da encima y cae a sus pies |
| 45 | `jn_control_stand_2448` | FT1435_CONTROL_STAND_06_ARMANI | control_stand | 4 · pierna | pie (a ras de piso) | 0.133 | VERIFICADO | media | usable | hipotesis alternativa: el pie derecho para la pelota rodando en marcha (0.37 m); con el muslo (39 grados) no habia gesto |
| 46 | `jn_control_stand_2450` | FT1435_CONTROL_STAND_07_MAX | control_stand | 4 · pierna | muslo | 0.167 | VERIFICADO | media | usable | muslo derecho levantado (66 grados), la pelota cae delante (0.38 m) |
| 47 | `jn_control_stand_3072` | FT1625_CONTROL_STAND_04_DAVID | control_stand | 4 · pierna | pie en el aire | 0.333 | VERIFICADO | media | usable | hipotesis alternativa: el pie derecho amortigua una pelota con bote bajo (0.24 m), queda a 0.42 m; con el muslo no habia gesto claro |
| 48 | `jn_control_stand_3090` | FT1626_CONTROL_STAND_09_ADAM | control_stand | 4 · pierna | muslo | 0.333 | VERIFICADO | media-alta | usable | muslo izquierdo horizontal (86 grados) bajo la pelota, cae a sus pies |
| 49 | `jn_control_stand_3094` | FT1626_CONTROL_STAND_12_ADAM | control_stand | 4 · pierna | pie en el aire | 0.400 | VERIFICADO | media | usable | hipotesis alternativa: el pie derecho levantado amortigua una pelota a 0.31 m, cae delante (0.71 m) |
| 50 | `jn_control_stand_3100` | FT1626_CONTROL_STAND_16_DAVID | control_stand | 4 · pierna | — | 0.067 | NO VERIFICADO | — | pending | t al empezar el clip (0.067 s): la pierna no ha subido y la pelota no toca el muslo (0.21 m) |
| 51 | `jn_receive_0614` | EXE238_STAND_BALL_IN_FROM_L_45_LOW_HEIGHT_CONTROL_TO_FORWARD_DRIBBLE | receive | 4 · pierna | pie en el aire | 0.333 | VERIFICADO | media | usable | hipotesis alternativa coherente con el nombre (LOW_HEIGHT): con el muslo levantado, el pie amortigua la pelota baja (0.37 m) y queda a sus pies (0.45 m) |
| 52 | `jn_receive_0618` | EXE240_STAND_BALL_IN_FROM_R_90_2_TOUCH_CONTROL_RUN_CTRL | receive | 4 · pierna | muslo | 0.433 | VERIFICADO | media-baja | conditional | pelota de costado (90 grados) al muslo izquierdo (58 grados) en marcha; la pelota queda a sus pies (0.70 m); vista en parte tapada |
| 53 | `jn_receive_0620` | EXE242_JOG_FORWARD_BALL_COMES_OVER_L_SHOULDER_CONTROL_LOW_TO_FORWARD_JOG_DRIBBLE | receive | 4 · pierna | — | 0.300 | NO VERIFICADO | — | pending | la pelota llega por detras (sobre el hombro): el contacto con el muslo no se distingue y el juego exige llegada por delante para el muslo |
| 54 | `jn_receive_1820` | FT1008_MOVING_CONTROL_AIR_FWD_7_JOSH_CTRL | receive | 4 · pierna | muslo | 0.333 | VERIFICADO | media-alta | usable | muslo derecho levantado (75 grados) con brazos abiertos, la pelota cae delante (0.53 m) |
| 55 | `jn_receive_2474` | FT1442_CONTROL_MEDIUM_01_ARMANI | receive | 4 · pierna | muslo | 0.400 | VERIFICADO | media | usable | muslo izquierdo (59 grados) bajo la pelota tras adelantar el pie; cae delante (0.42 m) |
| 56 | `jn_receive_2478` | FT1442_CONTROL_MEDIUM_03_MAX | receive | 4 · pierna | muslo | 0.300 | VERIFICADO | media-alta | usable | muslo izquierdo horizontal (90 grados), la pelota cae delante (0.31 m) |
| 57 | `jn_receive_2484` | FT1443_CONTROL_HIGH_04_MAX | receive | 4 · pierna | — | 0.300 | NO VERIFICADO | — | pending | salto con los brazos arriba antes del contacto: la pelota original parece ir a la cabeza; ni el muslo (pasada 2, 30 grados) ni el pecho son concluyentes |
| 58 | `jn_receive_3148` | FT1628_CONTROL_MEDIUM_02_DAVID | receive | 4 · pierna | muslo | 0.333 | VERIFICADO | media | usable | muslo izquierdo (66 grados), la pelota cae delante (0.17 m) |
| 59 | `jn_receive_3150` | FT1628_CONTROL_MEDIUM_03_ADAM | receive | 4 · pierna | pie en el aire | 0.333 | VERIFICADO | media | usable | hipotesis alternativa: el pie derecho amortigua una pelota con bote bajo (0.26 m), queda a 0.45 m |
| 60 | `jn_receive_3160` | FT1630_CONTROL_HIGH_03_DAVID | receive | 4 · pierna | — | 0.867 | NO VERIFICADO | — | pending | t estimado = final del clip (0.867 de 0.883 s) |
| 61 | `jn_receive_3162` | FT1630_CONTROL_HIGH_04_ADAM | receive | 4 · pierna | muslo | 0.400 | VERIFICADO | media-alta | usable | muslo izquierdo horizontal (89 grados), la pelota cae delante (0.26 m) |
| 62 | `jn_receive_3164` | FT1630_CONTROL_HIGH_05_DAVID | receive | 4 · pierna | muslo | 0.400 | VERIFICADO | media-alta | usable | muslo izquierdo horizontal (87 grados), la pelota cae delante (0.34 m) |
| 63 | `jn_receive_3166` | FT1630_CONTROL_HIGH_06_ADAM | receive | 4 · pierna | pecho | 0.333 | VERIFICADO | media-alta | conditional | hipotesis alternativa: tronco echado atras con brazos adelante (salto corto), la pelota da en el pecho y cae delante (0.71 m); con el muslo (20 grados) no habia gesto |
| 64 | `jn_receive_3178` | FT1630_CONTROL_HIGH_13_DAVID | receive | 4 · pierna | — | 0.700 | NO VERIFICADO | — | pending | t estimado = final del clip (0.70 de 0.717 s) |
| 65 | `jn_ball_start_2496` | FT1446_CONTROL_DRIBBLE_00_ARMANI | ball_start | 5 · resto | — | 0.767 | NO VERIFICADO | — | pending | arranque de conduccion en carrera: la pelota pasa bajo la zancada, no se ve un control |
| 66 | `jn_ball_start_3102` | FT1626_CONTROL_STAND_17_ADAM | ball_start | 5 · resto | — | 1.000 | NO VERIFICADO | — | pending | pico tardio (1.00 s, zancada): la recepcion se corta porque la pelota choca con el cuerpo antes de la ventana; no se ve un control |
| 67 | `jn_receive_0590` | EXE219_STAND_RECEIVE_HEAD__BALL_IN_FAST | receive | 5 · resto | — | 0.400 | NO VERIFICADO | — | pending | sin instante medible (cabeza sin senal); con t=0.40 elegido a mano la pelota da en la cara del jugador agachado; ademas la cabeza no tiene respuesta fisica en el juego |
| 68 | `jn_receive_2480` | FT1442_CONTROL_MEDIUM_04_MAX | receive | 5 · resto | — | 1.000 | NO VERIFICADO | — | pending | t estimado = final del clip (1.00 de 1.00 s) |
| 69 | `jn_receive_3146` | FT1628_CONTROL_MEDIUM_01_ADAM | receive | 5 · resto | — | 0.400 | NO VERIFICADO | — | pending | sin instante medido (ningun pie se levanta): con t=0.40 elegido a mano el pie toca la pelota en plena zancada; no se distingue de un paso |
| 70 | `jn_receive_3172` | FT1630_CONTROL_HIGH_10_ADAM | receive | 5 · resto | — | 1.133 | NO VERIFICADO | — | pending | el pie toca la pelota en plena zancada (pico tardio): no se distingue de un paso; el nombre dice pelota alta |

## Reproducir una tira

```bash
# hipótesis del perfil
CLIP=jn_receive_0604 W=360 H=270 COUNT=6 COLS=3 EVERY=6 OUT=/tmp/0604.png \
  xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/receive_view.tscn
# hipótesis alternativa: PART=foot|foot_air|thigh|knee|chest|head T=<s>  (ANGLE, SPEED, DIST, VIEW, DEBUG=1: ver cabecera del script)
```

Regenerar los perfiles (necesita el zip de JSON originales, fuera del repositorio): `python3 tools/json_anim/make_receive_profiles.py <carpeta_json>`; los veredictos están en `VISUAL` / `VISUAL_NOT` del generador.
