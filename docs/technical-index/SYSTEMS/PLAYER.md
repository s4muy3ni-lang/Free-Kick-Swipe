# PLAYER — Futbolista de campo

## Identificación

- **Responsabilidad exacta:** el futbolista de campo, controlado únicamente a través de `InputFrame`: movimiento con aceleración progresiva y giro dependiente de la velocidad (`Locomotion`), conducción por toques físicos, control de primer toque, posesión, robo (`BallHandler`), y la patada de pase/tiro cuyo impulso se aplica en el instante de contacto de la animación. La presión defensiva y las asistencias de pase/tiro viven en [ASSISTANCE](ASSISTANCE.md); el modelo y las animaciones en [ANIMATIONS](ANIMATIONS.md).
- **Estado:** implementado para **un** jugador humano por equipo. No hay IA ni cambio de jugador.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-11
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos / nodos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/player/footballer.gd` | Clase `Footballer` (`CharacterBody3D`): orquesta entrada → presión → locomoción → `move_and_slide` → manejo de pelota → visual. Crea la cápsula de colisión (`CollisionShape3D`) y el hijo `Visual` | `Footballer.setup`, `Footballer._physics_process`, `Footballer.place_at`, `Footballer.capture_state` | `MatchContext`, `Locomotion`, `BallHandler`, `PressController`, `FootballerVisual` |
| `scripts/player/locomotion.gd` | Clase `Locomotion` (`RefCounted`, pura): velocidad, giro, agarre lateral, frenada, sprint y resistencia | `Locomotion.step`, `Locomotion.speed_for_magnitude`, `Locomotion.max_run_speed`, `Locomotion.max_sprint_speed` | `PlayerTuning`, `PlayerAttributes` |
| `scripts/player/ball_handler.gd` | Clase `BallHandler` (`RefCounted`): toques, primer toque, posesión, robo, botones con carga, patada con contacto sincronizado | `BallHandler.update`, `BallHandler._try_dribble_touch`, `BallHandler._try_first_touch`, `BallHandler.request_kick`, `BallHandler.attempt_tackle` | `Ball`, `PassAssist`, `ShotAssist`, `KickModel` |
| `scripts/player/ball_turn.gd` | Clase `BallTurn` (`RefCounted`, la crea `BallHandler`): giro con toques (joystick hacia atrás conduciendo, como Dream League Soccer): frena, rodea la pelota con toques cortos del interior del pie de fuera y sale hacia el rumbo nuevo | `BallTurn.update`, `BallTurn.body_control`, `BallTurn.predict_body`, `BallTurn._try_start`, `BallTurn._touch`, `BallTurn._exit_touch` | `BallHandler`, `Ball.roll_speed_for`, `DragBack.reachable`, `Locomotion.step_scripted`, `TouchFootIK.set_target` |
| `scripts/player/drag_back.gd` | Clase `DragBack` (`RefCounted`, la crea `BallHandler`): vuelta atrás pisando la pelota con la suela (llegar, pisar, arrastrar, pivotar); regate con REGATE + joystick atrás (`request`) | `DragBack.update`, `DragBack.request`, `DragBack.body_control`, `DragBack._try_start`, `DragBack._pull`, `DragBack.reachable` | `BallHandler`, `Ball.roll_*`, `Locomotion.step_scripted`, `TouchFootIK.set_target` |
| `scripts/player/action_arbiter.gd` | Clase `ActionArbiter` (`RefCounted`, la crea `Footballer`): autoridad única sobre el cuerpo y la pose del futbolista. Niveles (gesto 10 < capa 20 < movimiento con pelota 40 < golpeo 50 < acción con raíz 60 < balón parado 70 < caída 80), testigos, interrupción completa, poses en el sitio solo con el cuerpo a la velocidad del clip, registro de decisiones | `ActionArbiter.request`, `ActionArbiter.play`, `ActionArbiter.play_situation`, `ActionArbiter.release`, `ActionArbiter.handover`, `ActionArbiter.relevel`, `ActionArbiter.cut_pose`, `ActionArbiter.reset`, `ActionArbiter.holds_pose`, `ActionArbiter.current_level` | `PlayerActions.interrupt`, `BallHandler.abort_kick`, `FootballerVisual.play_pack_clip`, `AnimationCatalog.resolve` |
| `scripts/player/json_receive.gd` | Clase `JsonReceive` (`RefCounted`, la crea `BallHandler`; modo 4): recepcion y control de una pelota que llega rodando con un clip elegido antes de que llegue, cuyo pie la toca en su instante de toque (meta `ball_touches[0]`). La ejecuta `JsonBallMove` (intencion `&"receive"`) | `JsonReceive.consider`, `JsonReceive.plan`, `JsonReceive.profile`, `JsonReceive.selectable`, `JsonReceive.contact_point`, `JsonReceive.path_point`, `JsonReceive.contact_velocity`, `JsonReceive.approach` | `ReceiveProfiles`, `JsonBallMove.start_receive`, `BallHandler.first_touch_absorb`, `BallPredictor.trajectory`, `ActionMotion`, `ActionArbiter` (via `PlayerActions.start_move`) |
| `scripts/player/receive_profiles.gd` | Clase `ReceiveProfiles`: perfiles de contacto de los 124 clips de recepción (GENERADO por `tools/json_anim/make_receive_profiles.py`, no editar a mano) | `ReceiveProfiles.PROFILES` | — |
| `scripts/player/player_tuning.gd` | Recurso `PlayerTuning`: todos los parámetros de locomoción y conducción | ver «Mapa de parámetros» | — |
| `scenes/player/footballer.tscn` | Nodo raíz `Footballer` (`CharacterBody3D`) con el script; el resto se crea en `_ready` | nodo `Footballer` | `scripts/player/footballer.gd` |
| `scripts/player/human_input.gd` | `InputSource` que lee `InputMap` (ver [INPUTS](INPUTS.md)) | `HumanInput.poll` | — |

**No modificar para cambiar la sensación de movimiento:** `ball_handler.gd` (la pelota no depende de cómo se acelera) ni `scripts/ui/touch_controls.gd`. **No modificar para cambiar la conducción:** `locomotion.gd`.

## Mapa de parámetros

<!-- AUTO:params:PlayerTuning -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `walk_speed` | `1.8` | float | `scripts/player/player_tuning.gd:7` | `scripts/player/ball_handler.gd:1604`, `scripts/player/ball_handler.gd:1611`, `scripts/player/ball_handler.gd:1621`, `scripts/player/ball_handler.gd:1622` (+9) |  (Velocidades (m/s)) |
| `jog_speed` | `3.6` | float | `scripts/player/player_tuning.gd:8` | `scripts/player/ball_handler.gd:377`, `scripts/player/ball_handler.gd:1623`, `scripts/player/ball_handler.gd:1624`, `scripts/player/ball_handler.gd:1626` (+13) |  (Velocidades (m/s)) |
| `run_speed` | `5.2` | float | `scripts/player/player_tuning.gd:9` | `scripts/player/locomotion.gd:57`, `scripts/player/locomotion.gd:199` |  (Velocidades (m/s)) |
| `sprint_speed` | `6.8` | float | `scripts/player/player_tuning.gd:10` | `scripts/player/ball_handler.gd:377`, `scripts/player/ball_handler.gd:1626`, `scripts/player/ball_handler.gd:1648`, `scripts/player/locomotion.gd:60` |  (Velocidades (m/s)) |
| `backpedal_factor` | `0.72` | float | `scripts/player/player_tuning.gd:11` | **sin uso** |  (Velocidades (m/s)) |
| `accel` | `6.2` | float | `scripts/player/player_tuning.gd:15` | `scripts/player/ball_handler.gd:2110`, `scripts/player/ball_handler.gd:2716`, `scripts/player/ball_turn.gd:190`, `scripts/player/ball_turn.gd:301` (+6) | Aceleracion al empujar el joystick (m/s^2). (Aceleracion) |
| `decel` | `9.5` | float | `scripts/player/player_tuning.gd:17` | `scripts/player/ball_handler.gd:2111`, `scripts/player/ball_handler.gd:2456`, `scripts/player/ball_handler.gd:2459`, `scripts/player/locomotion.gd:131` (+3) | Desaceleracion al soltar el joystick. (Aceleracion) |
| `brake` | `14.0` | float | `scripts/player/player_tuning.gd:19` | `scripts/player/ball_handler.gd:2550`, `scripts/player/locomotion.gd:133`, `scripts/player/locomotion.gd:144` | Desaceleracion cuando el joystick apunta contra el movimiento (frenada). (Aceleracion) |
| `lateral_grip` | `9.0` | float | `scripts/player/player_tuning.gd:21` | `scripts/player/locomotion.gd:148` | Agarre lateral: cuanto rapido se elimina la velocidad lateral respecto al cuerpo (1/s). (Aceleracion) |
| `turn_rate_standing` | `620.0` | float | `scripts/player/player_tuning.gd:25` | `scripts/player/ball_handler.gd:654`, `scripts/player/ball_handler.gd:2133`, `scripts/player/locomotion.gd:106`, `scripts/player/locomotion.gd:194` | Velocidad de giro parado (grados/s). (Giro) |
| `turn_rate_sprint` | `165.0` | float | `scripts/player/player_tuning.gd:27` | `scripts/player/ball_handler.gd:654`, `scripts/player/ball_handler.gd:2133`, `scripts/player/locomotion.gd:106` | Velocidad de giro a sprint maximo (grados/s). (Giro) |
| `sharp_turn_angle_deg` | `115.0` | float | `scripts/player/player_tuning.gd:29` | `scripts/player/locomotion.gd:112` | Si el angulo al objetivo supera esto a mas de 70 % de la velocidad maxima, hay que frenar antes de girar. (Giro) |
| `stamina_drain_sprint` | `0.16` | float | `scripts/player/player_tuning.gd:32` | `scripts/player/locomotion.gd:81` |  (Resistencia) |
| `stamina_regen` | `0.07` | float | `scripts/player/player_tuning.gd:33` | `scripts/player/locomotion.gd:85`, `scripts/player/locomotion.gd:164`, `scripts/player/locomotion.gd:191` |  (Resistencia) |
| `stamina_regen_standing` | `0.14` | float | `scripts/player/player_tuning.gd:34` | `scripts/player/locomotion.gd:85`, `scripts/player/locomotion.gd:164`, `scripts/player/locomotion.gd:191` |  (Resistencia) |
| `exhausted_speed_factor` | `0.82` | float | `scripts/player/player_tuning.gd:36` | `scripts/player/locomotion.gd:62` | Fraccion de velocidad de sprint que aun se mantiene con la resistencia agotada. (Resistencia) |
| `touch_reach` | `0.95` | float | `scripts/player/player_tuning.gd:40` | `scripts/ai/ai_input.gd:131`, `scripts/player/ball_handler.gd:373`, `scripts/player/ball_handler.gd:569`, `scripts/player/ball_handler.gd:1340` (+1) | Distancia maxima (m) a la que puede dar un toque. (Conduccion) |
| `touch_interval_jog` | `0.28` | float | `scripts/player/player_tuning.gd:42` | `scripts/player/ball_handler.gd:1658` | Segundos entre toques (trote). (Conduccion) |
| `touch_interval_sprint` | `0.38` | float | `scripts/player/player_tuning.gd:44` | `scripts/player/ball_handler.gd:1658` | Segundos entre toques (sprint, toques mas largos y espaciados). (Conduccion) |
| `carry_gap_stand` | `0.38` | float | `scripts/player/player_tuning.gd:46` | `scripts/player/ball_handler.gd:1646`, `scripts/player/ball_handler.gd:2468`, `scripts/player/ball_handler.gd:2475`, `scripts/player/ball_handler.gd:2511` | Distancia objetivo (m) de la pelota al pie PARADO: es la que define el control cercano. (Conduccion) |
| `touch_lead_jog` | `0.70` | float | `scripts/player/player_tuning.gd:48` | `scripts/player/ball_handler.gd:1646`, `scripts/player/ball_handler.gd:1648` | Distancia objetivo (m) a la que se coloca la pelota delante del jugador al trotar / sprintar. (Conduccion) |
| `touch_lead_sprint` | `1.20` | float | `scripts/player/player_tuning.gd:49` | `scripts/player/ball_handler.gd:1648` |  (Conduccion) |
| `settle_gap` | `0.38` | float | `scripts/player/player_tuning.gd:51` | `scripts/player/ball_handler.gd:2448`, `scripts/player/ball_handler.gd:2457`, `scripts/player/ball_handler.gd:2730`, `scripts/player/ball_handler.gd:2819` (+5) | Distancia (m) a la que queda la pelota al parar (soltar el joystick): pisada / parada. (Conduccion) |
| `lateral_hold_seconds` | `0.40` | float | `scripts/player/player_tuning.gd:53` | `scripts/player/ball_handler.gd:2767`, `scripts/player/ball_handler.gd:2768` | Segundos que el cuerpo conserva su orientacion tras un control lateral. (Conduccion) |
| `lateral_max_stick` | `0.5` | float | `scripts/player/player_tuning.gd:56` | `scripts/player/ball_handler.gd:2764` | Intensidad maxima del joystick para que un empuje de costado sea control lateral (mas fuerte = giro normal). 0.5: en el movil el joystick rara vez va a fondo y con 0.75 el jugador se desplazaba de lado en vez de girar. (Conduccion) |
| `shield_radius` | `2.6` | float | `scripts/player/player_tuning.gd:58` | `scripts/player/ball_handler.gd:2722`, `scripts/player/ball_handler.gd:2757` | Radio (m) dentro del cual un rival hace que el portador proteja la pelota con el cuerpo. (Conduccion) |
| `touch_overshoot_sprint` | `0.82` | float | `scripts/player/player_tuning.gd:60` | `scripts/player/ball_handler.gd:2282`, `scripts/player/ball_handler.gd:2494` | Desviacion tipica (m) de los toques largos a sprint con control 0 (disminuye con la habilidad). (Conduccion) |
| `touch_escape_factor` | `1.05` | float | `scripts/player/player_tuning.gd:62` | **sin uso** | Toque de recuperacion: se adelanta cuando la pelota va a quedar a mas de este multiplo del alcance en 0.14 s. (Conduccion) |
| `touch_error_deg` | `4.0` | float | `scripts/player/player_tuning.gd:64` | `scripts/player/ball_handler.gd:2306`, `scripts/player/ball_handler.gd:2590` | Error angular base de un toque (grados) con control de balon 50. (Conduccion) |
| `touch_error_max_deg` | `8.0` | float | `scripts/player/player_tuning.gd:66` | `scripts/player/ball_handler.gd:2597` | Tope (grados) del error angular de un toque aunque se sumen sprint y giro. (Conduccion) |
| `touch_error_sprint` | `2.0` | float | `scripts/player/player_tuning.gd:68` | `scripts/player/ball_handler.gd:2591` | Error extra por sprint (multiplicador) y por giro brusco. (Conduccion) |
| `touch_error_turn` | `1.9` | float | `scripts/player/player_tuning.gd:69` | `scripts/player/ball_handler.gd:2592` |  (Conduccion) |
| `touch_turn_walk_deg` | `150.0` | float | `scripts/player/player_tuning.gd:73` | `scripts/player/ball_handler.gd:1622`, `scripts/player/ball_handler.gd:1624` | Giro maximo (grados) que un toque de conduccion le da a la pelota caminando, al trote y a sprint (BallHandler .touch_turn_max_deg): entre toques la pelota rueda recta y el jugador la sigue; un cambio de rumbo mayor lleva varios toques, como en FTS / Ultimate Clash. (Conduccion) |
| `touch_turn_jog_deg` | `110.0` | float | `scripts/player/player_tuning.gd:74` | `scripts/player/ball_handler.gd:1624`, `scripts/player/ball_handler.gd:1626` |  (Conduccion) |
| `touch_turn_sprint_deg` | `70.0` | float | `scripts/player/player_tuning.gd:75` | `scripts/player/ball_handler.gd:1626` |  (Conduccion) |
| `kick_lockout` | `0.35` | float | `scripts/player/player_tuning.gd:77` | `scripts/player/ball_handler.gd:1431` | Segundos de bloqueo despues de un pase/tiro antes de poder volver a tocar la pelota. (Conduccion) |
| `possession_radius` | `1.1` | float | `scripts/player/player_tuning.gd:78` | `scripts/ai/ai_input.gd:627`, `scripts/assistance/press_controller.gd:44`, `scripts/assistance/press_controller.gd:49`, `scripts/assistance/press_controller.gd:51` (+3) |  (Conduccion) |
| `kick_contact_radius` | `0.30` | float | `scripts/player/player_tuning.gd:82` | `scripts/player/ball_handler.gd:2634` | Radio (m) entre el pie (posicion de contacto medida del clip) y el centro de la pelota para que el golpeo cuente. (Patada con animacion del pack) |
| `json_kick_reach` | `0.65` | float | `scripts/player/player_tuning.gd:87` | `scripts/player/ball_handler.gd:2634` | Modo 4 (Json): alcance (m) con el que el golpeo de un clip sigue contando aunque la pelota se haya corrido del punto previsto; el pie se estira hasta ella (IK) en el ultimo tramo del balanceo. Con 0.30 una de cada cinco patadas del partido de IA se perdia en el aire con la pelota a 0.30-0.47 m («hace la animacion pero no le da al balon»); con 0.55 seguian perdiendose 2-4 por partido a 0.56-0.73 m en jugadas disputadas (el cuerpo empujado 0.4-1.1 m en el balanceo). (Patada con animacion del pack) |
| `kick_foot_max_height` | `0.25` | float | `scripts/player/player_tuning.gd:90` | `scripts/player/ball_handler.gd:801` | Altura maxima (m) de la punta del pie y velocidad minima de avance (m/s) para que un punto de la trayectoria del clip cuente como golpeo: el pie debe ir bajo y lanzado, no subiendo ni frenando. (Patada con animacion del pack) |
| `kick_foot_min_speed` | `3.0` | float | `scripts/player/player_tuning.gd:91` | `scripts/player/ball_handler.gd:801` |  (Patada con animacion del pack) |
| `kick_adjust_max` | `0.30` | float | `scripts/player/player_tuning.gd:94` | `scripts/player/ball_handler.gd:839`, `scripts/player/ball_handler.gd:961` | Ajuste de zancada: desplazamiento maximo (m) del cuerpo hacia la pelota durante la latencia para que el pie llegue. Crece con la velocidad (a sprint la zancada es larga): kick_adjust_max + kick_adjust_sprint * ratio de sprint. (Patada con animacion del pack) |
| `kick_adjust_sprint` | `0.28` | float | `scripts/player/player_tuning.gd:95` | `scripts/player/ball_handler.gd:839`, `scripts/player/ball_handler.gd:961` |  (Patada con animacion del pack) |
| `kick_start_residual` | `0.18` | float | `scripts/player/player_tuning.gd:97` | `scripts/player/ball_handler.gd:855`, `scripts/player/ball_handler.gd:856`, `scripts/player/ball_handler.gd:857`, `scripts/player/ball_handler.gd:903` (+9) | Error maximo (m) que se acepta al INICIAR el balanceo, medido tras el ajuste con la pelota y el jugador predichos al contacto. (Patada con animacion del pack) |
| `kick_latency` | `0.20` | float | `scripts/player/player_tuning.gd:99` | `scripts/player/ball_handler.gd:629`, `scripts/player/ball_handler.gd:1000` | Latencia objetivo (s) entre soltar el boton y el golpeo; el clip se acelera/recorta para llegar a ella. (Patada con animacion del pack) |
| `shot_windup` | `0.12` | float | `scripts/player/player_tuning.gd:103` | `scripts/player/ball_handler.gd:629` | Preparacion extra (s) del TIRO sobre kick_latency (+ shot_windup_charge con la carga al maximo): el clip arranca antes y a velocidad casi natural, asi se ve el balanceo de la pierna hacia atras (prueba03: el tiro duraba 0.17 s en pantalla y no se notaba). Los pases conservan la latencia corta. (Patada con animacion del pack) |
| `shot_windup_charge` | `0.06` | float | `scripts/player/player_tuning.gd:104` | `scripts/player/ball_handler.gd:629` |  (Patada con animacion del pack) |
| `kick_clip_speed_max` | `1.6` | float | `scripts/player/player_tuning.gd:106` | `scripts/player/ball_handler.gd:634` | Aceleracion maxima del clip de patada (1 = velocidad original del clip). (Patada con animacion del pack) |
| `kick_turn_scale` | `0.35` | float | `scripts/player/player_tuning.gd:108` | `scripts/player/ball_handler.gd:651`, `scripts/player/ball_handler.gd:655`, `scripts/player/ball_handler.gd:1206` | Fraccion de la velocidad de giro que se conserva mientras el pie se prepara (el pie de apoyo fija la direccion). (Patada con animacion del pack) |
| `kick_follow_through` | `0.30` | float | `scripts/player/player_tuning.gd:110` | `scripts/player/ball_handler.gd:1188`, `scripts/player/ball_handler.gd:1217` | Segundos de continuacion del clip tras el golpeo antes de devolver el cuerpo a la marcha. (Patada con animacion del pack) |
| `first_touch_absorb` | `0.65` | float | `scripts/player/player_tuning.gd:114` | `scripts/player/ball_handler.gd:3180` | Fraccion de energia que absorbe el control orientado (0 = rebote total). (Contacto con balon) |
| `receive_contact` | `{` | Dictionary | `scripts/player/player_tuning.gd:118` | `scripts/player/json_receive.gd:707` | Recepcion con clip (modo 4, JsonReceive.contact_velocity), por parte del cuerpo: Vector3(restitucion, conservacion a lo largo de la superficie, empuje hacia delante en m/s). Los dos primeros se escalan con lo que el jugador no amortigua (first_touch_absorb): un buen control deja la pelota muerta. Valores iniciales para ajustar en el juego, no medidos. (Contacto con balon) |
| `body_mass` | `75.0` | float | `scripts/player/player_tuning.gd:124` | **sin uso** |  (Contacto con balon) |
| `capsule_radius` | `0.3` | float | `scripts/player/player_tuning.gd:125` | `scripts/player/ball_handler.gd:1716`, `scripts/player/ball_handler.gd:1726`, `scripts/player/footballer.gd:87` |  (Contacto con balon) |
| `capsule_height` | `1.75` | float | `scripts/player/player_tuning.gd:126` | `scripts/player/ball_handler.gd:1716`, `scripts/player/footballer.gd:88`, `scripts/player/footballer.gd:90` |  (Contacto con balon) |
<!-- /AUTO -->

### Riesgos al modificar (con las pruebas que los vigilan)

| Parámetro(s) | Efecto real y riesgo |
|---|---|
| `walk_speed`, `jog_speed`, `run_speed`, `sprint_speed` | `Locomotion.speed_for_magnitude` / `max_sprint_speed`. La animación acompaña hasta `FootballerVisual.MAX_TIME_SCALE (2.9) × NATURAL_SPEED["run"] (2.5) = 7.25 m/s`: **por encima de ~7.2 m/s los pies patinan** (la cadencia se satura). El `BlendSpace` de locomoción llega hasta 7.5. Los atributos escalan la velocidad con `PlayerAttributes.factor("speed", 0.12)`. |
| `accel`, `decel`, `brake` | `test_acceleration_is_progressive` (v(0.2 s) < 50 % de la velocidad de carrera; 90 % entre 0.9 y 2.2 s; medido 1.05 s) y `test_stops_without_sliding_like_ice` (frena en < 0.9 s y < 2 m; medido 0.55 s / 1.38 m). |
| `turn_rate_standing`, `turn_rate_sprint`, `sharp_turn_angle_deg` | `test_turning_rate_depends_on_speed` (giro de 90° parado entre 0.08 y 0.30 s; a sprint ≥ 0.25 s y > 1.5× el parado; medidos 0.15 s / 0.30 s) y `test_reversal_at_sprint_brakes_first_and_never_slides_sideways`. |
| `lateral_grip` | Es el «anti-hielo»: elimina la velocidad lateral respecto al cuerpo. Valores bajos = deslizamiento; la prueba exige desplazamiento lateral < 2.0 m al invertir a sprint (medido 0.67 m). |
| `touch_reach`, `touch_interval_*`, `touch_lead_*`, `touch_overshoot_sprint`, `touch_error_*` | Conducción: *test_dribble_at_jog_keeps_ball_close_with_physical_touches (eliminada en la reforma)* (pelota < 2 m el 85 % del tiempo y 8–40 toques en 6 s; medido 100 % y 21 toques), *test_sprint_dribble_is_less_precise_than_jog (eliminada en la reforma)*, *test_better_ball_carrying_means_tighter_control (eliminada en la reforma)*, *test_turning_with_ball_changes_ball_direction_physically (eliminada en la reforma)*. Subir `touch_lead_*` o `touch_overshoot_sprint` alarga los toques y pierde la pelota más seguido. |
| `possession_radius` | Define «tiene la pelota»: lo usan `BallHandler.has_possession`, el primer toque y `PressController._find_carrier`. Cambiarlo altera cuándo se activa la presión y el robo. |
| `kick_lockout` | Bloqueo de toques tras un pase/tiro (`BallHandler._after_kick`). Muy bajo: el jugador vuelve a empujar la pelota recién pateada. |
| `first_touch_absorb` | Fracción de energía absorbida en el control (`BallHandler._try_first_touch`, escalada por `ball_control`). |
| `capsule_radius`, `capsule_height` | Tamaño de la cápsula física (`Footballer._ready`). **No** escalan el modelo (que usa `FootballerVisual.MODEL_HEIGHT_SCALE = 1.75`): si se cambia uno, cambiar el otro a mano. |
| `stamina_*`, `exhausted_speed_factor` | Resistencia en `Locomotion.step` (el sprint la consume; agotado, la velocidad máxima cae). `test_sprint_is_faster_and_drains_stamina`. |
| `backpedal_factor`, `body_mass` | **Sin uso**: definidos pero ningún código los lee. |

### Valores fijos en el código de este sistema

Ver la tabla «Valores fijos» de [ARCHITECTURE.md](../ARCHITECTURE.md) (carga del pase 0.8 s, retardo de contacto, buffer 0.3 s, márgenes de alcance, bloqueo +0.4 s, pérdida 0.9 al patear, tope conduciendo 0.86–0.97).

## Mapa de funciones

<!-- AUTO:funcs:scripts/player/footballer.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Footballer._ready()` | 75 |  |
| `Footballer.setup(context: MatchContext, team_index: int, id: int, attrs: PlayerAttributes, source: InputSource)` | 108 | Configura el jugador dentro de un partido. |
| `Footballer.expect_pass(point: Vector3, kind: StringName, from: Node = null)` | 126 | Un companero (`from`) acaba de pasarle la pelota: guarda el punto de llegada para ir a buscarla. |
| `Footballer.has_incoming_pass()` | 134 | true mientras hay un pase en camino hacia este jugador (y la pelota no la tiene nadie todavia). |
| `Footballer.pass_meet_point()` | 139 | Punto donde salir a buscar el pase que viene: el primero de la trayectoria PREDICHA de la pelota al que el jugador llega antes que ella (a r |
| `Footballer.set_attributes(attrs: PlayerAttributes)` | 155 |  |
| `Footballer._notification(what: int)` | 161 | Al liberarse el nodo se rompe el ciclo BallHandler <-> submodulos (RefCounted): si no, quedan vivos en ObjectDB. |
| `Footballer._exit_tree()` | 165 |  |
| `Footballer.set_ball_ghost(on: bool)` | 173 | Durante un golpeo en el aire (cabezazo, volea) la pelota atraviesa el cuerpo hasta el contacto del clip: si no, rebota contra la capsula ant |
| `Footballer.has_ball()` | 176 |  |
| `Footballer.on_ball_impact(ball: Ball)` | 180 | Notificacion de una colision fisica real de Jolt; no se usa para fabricar un toque ni mover la pelota. |
| `Footballer.reset_motion()` | 184 |  |
| `Footballer.place_at(pos: Vector3, yaw: float)` | 195 |  |
| `Footballer._physics_process(delta: float)` | 208 |  |
| `Footballer._player_step(delta: float)` | 213 |  |
| `Footballer._json_idle(stick_mag: float, delta: float)` | 504 |  |
| `Footballer._json_turn_move(desired_dir: Vector3, desired_mag: float, delta: float, input_mag: float)` | 527 |  |
| `Footballer._keep_inside(dir: Vector3)` | 579 | Quita la componente que saca al jugador mas alla de las lineas (con medio metro de margen). |
| `Footballer._ai_commits_tackle(carrier: Footballer)` | 592 | La IA no disputa en cada ocasion: contiene (jockey) y entra cuando la pelota queda expuesta (toque largo del portador, pelota suelta) o, con |
| `Footballer._skill_is_drag_back(frame: InputFrame)` | 601 | El boton REGATE pide la vuelta pisando la pelota cuando el joystick apunta hacia atras (>= DragBack.MIN_ANGLE grados del frente) con la pelo |
| `Footballer._json_clip_slides(cur: StringName, delta: float)` | 614 |  |
| `Footballer._gait_overlays(desired_dir: Vector3, want_sprint: bool, stick_mag: float, speed_before: float, delta: float)` | 625 |  |
| `Footballer._cancel_reaction()` | 669 |  |
| `Footballer._on_match_event(e: GameEvent)` | 680 | Reacciones de presentacion a eventos del partido: - Gol: el goleador, el asistente, el resto del equipo y el rival reaccionan distinto (un a |
| `Footballer._try_block_jump(e: GameEvent)` | 722 |  |
| `Footballer.rng_delay()` | 737 |  |
| `Footballer._set_reaction(situation: StringName, wait: float, cut: float)` | 740 |  |
| `Footballer._update_reaction(delta: float)` | 747 | La reaccion a un gol arranca cuando el jugador casi se ha detenido (o tras REACTION_MAX_WAIT) para no animar un clip en el sitio sobre un cu |
| `Footballer._check_player_collisions()` | 761 | Un choque a velocidad con otro jugador provoca un tropiezo (presentacion) o, si es fuerte, un golpe de hombro y caida. |
| `Footballer.capture_state()` | 783 | Datos replicables del jugador (para snapshots de red / pruebas). |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/player/locomotion.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Locomotion._init(t: PlayerTuning = null, a: PlayerAttributes = null)` | 38 |  |
| `Locomotion.dir_from_yaw(y: float)` | 43 | Vector de direccion (unitario) para un yaw. yaw = 0 mira hacia -Z. |
| `Locomotion.yaw_from_dir(d: Vector3)` | 46 |  |
| `Locomotion.forward()` | 49 |  |
| `Locomotion.right()` | 52 |  |
| `Locomotion.max_run_speed()` | 56 |  |
| `Locomotion.max_sprint_speed()` | 59 |  |
| `Locomotion.step(desired_dir: Vector3, magnitude: float, want_sprint: bool, delta: float, speed_cap: float = -1.0)` | 68 | Avanza un paso de simulacion. desired_dir: direccion deseada en el mundo (unitaria o cero). magnitude: 0..1 (intensidad del joystick). speed |
| `Locomotion.step_scripted(face_dir: Vector3, rate_deg: float, turn_sign: float, target_vel: Vector3, accel: float, delta: float)` | 160 | Movimiento guiado por una accion del cuerpo con la pelota (DragBack): gira hacia face_dir a rate_deg grados/s por el lado turn_sign (+1 = ya |
| `Locomotion._step_jockey(desired_dir: Vector3, magnitude: float, delta: float, speed_cap: float)` | 184 |  |
| `Locomotion.speed_for_magnitude(m: float)` | 211 | Velocidad objetivo (m/s) para una intensidad de joystick 0..1 (sin sprint). |
| `Locomotion.turn_rate_blocks_speed(angle_diff: float)` | 221 |  |
| `Locomotion.face_towards(dir: Vector3, delta: float, rate_deg: float = 540.0)` | 225 | Orienta el cuerpo sin moverlo (por ejemplo, al encarar la pelota estando parado). |
| `Locomotion.stop()` | 232 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/player/ball_handler.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `BallHandler._init(o: Footballer)` | 192 |  |
| `BallHandler.dispose()` | 203 | Rompe el ciclo de referencias entre el BallHandler y sus submodulos (todos RefCounted y cada uno con `handler` apuntando de vuelta): sin est |
| `BallHandler.ball()` | 216 |  |
| `BallHandler.ball_offset()` | 219 |  |
| `BallHandler.ball_distance()` | 223 |  |
| `BallHandler.possession_radius()` | 228 | Radio (m) dentro del cual se considera que el jugador lleva la pelota. Crece con la velocidad: a sprint la pelota va mas adelantada y seguir |
| `BallHandler.has_possession()` | 231 |  |
| `BallHandler.is_dribbling()` | 247 | Conduce aunque el ultimo toque largo la haya alejado un poco: fue el ultimo en tocarla, no la pateo (pase/tiro) y sigue cerca. Sirve para no |
| `BallHandler.seconds_since_kick()` | 255 | Segundos de simulacion desde el ultimo pase o tiro de este jugador. |
| `BallHandler.incoming_ball_eta(radius: float = 2.5)` | 260 | Segundos hasta que una pelota que se ACERCA pase a menos de radius del jugador (INF si no viene hacia el, va alta o es de otro). Prediccion  |
| `BallHandler._ball_rolling(b: Ball)` | 283 | La pelota va rodando por el piso (no en el aire ni botando): su avance sigue el modelo de rodadura de Ball. |
| `BallHandler.ball_travel(b: Ball, t: float)` | 287 | Desplazamiento horizontal de la pelota en t segundos: rodando, con la rodadura de Ball; en el aire, recto. |
| `BallHandler.incoming_ball_point()` | 295 | Punto (en el suelo) de la trayectoria de la pelota que viene mas cercano al jugador: donde preparar el golpeo de primera. |
| `BallHandler.loose_ball_chase()` | 312 | Punto (en el suelo) donde el jugador alcanza una pelota suelta: el primero de su recorrido (rodadura de Ball) al que llega corriendo. Vector |
| `BallHandler.is_waiting_first_time()` | 335 | Hay una orden de pase/tiro esperando una pelota que llega (golpeo de primera, sin control previo). |
| `BallHandler.ball_owned_by_other()` | 341 | La pelota es de otro jugador (la conduce o la acaba de controlar): no se la puede conducir ni controlar, solo disputar. Un companero que la  |
| `BallHandler.controls_ball()` | 357 | El equipo del jugador controla la pelota: esta cerca Y fue tocada por ultima vez por su equipo. Una pelota suelta o ultimo tocada por el riv |
| `BallHandler.can_reach(reach: float)` | 361 |  |
| `BallHandler.dribble_speed_cap()` | 368 | Alcance efectivo de un toque: el jugador estira mas la pierna a mayor velocidad. Velocidad (m/s) maxima con la pelota al pie: algo menos que |
| `BallHandler.touch_reach()` | 371 |  |
| `BallHandler._sprint_ratio()` | 375 |  |
| `BallHandler.assist_pass_level()` | 379 |  |
| `BallHandler.assist_shot_level()` | 382 |  |
| `BallHandler.update(frame: InputFrame, stick_world: Vector3, stick_mag: float, desired_dir: Vector3, dt: float)` | 386 | Paso de simulacion. stick_world: direccion del joystick en el mundo; desired_dir: direccion deseada final. |
| `BallHandler._update_buttons(frame: InputFrame, stick_world: Vector3, dt: float)` | 467 |  |
| `BallHandler.curl_from(at_press: Vector3, at_release: Vector3)` | 523 | Efecto pedido con el joystick: angulo (con signo) entre la direccion al pulsar y al soltar. Un giro de 15-60 grados a la derecha del tiro cu |
| `BallHandler._queue(action: StringName, charge: float, lob: bool, stick_world: Vector3, curl: float = 0.0)` | 532 |  |
| `BallHandler._try_execute_pending()` | 540 |  |
| `BallHandler.contact_delay(action: StringName, charge: float)` | 578 | Segundos entre el inicio de la patada y el golpeo (la animacion y el impulso comparten este instante). |
| `BallHandler.request_kick(action: StringName, stick_world: Vector3, charge: float, lob: bool)` | 582 | Comienza una patada: arranca la animacion y programa el impulso para el instante de contacto. |
| `BallHandler.is_kick_in_progress()` | 599 |  |
| `BallHandler.uses_clip_kicks()` | 605 | true si este futbolista patea con los clips del pack (visual con libreria y clips de patada en el sitio). |
| `BallHandler.foot_contact_world(contact: Dictionary, pos: Vector3, yaw: float)` | 611 | Posicion MUNDIAL de la punta del pie en el golpeo de un clip, para un jugador en pos con orientacion yaw. contact.pos es (adelante, arriba,  |
| `BallHandler.clip_timing(contact_time: float, action: StringName, charge: float, mocap: bool = false)` | 625 | Velocidad de reproduccion, punto de inicio y latencia real para que el clip llegue a su contacto en kick_latency. La latencia se cuantiza a  |
| `BallHandler._predicted_yaw(latency: float)` | 647 | Vector (pelota - pie) en el plano, en metros, al instante de contacto del clip, PREDICHO desde el estado actual (jugador y pelota siguen su  |
| `BallHandler.abort_kick()` | 659 | Aborta una patada en curso y la accion pendiente (caida, barrida): no se aplica ningun impulso. |
| `BallHandler.cancel_charge()` | 677 | Cancela la carga de pase/tiro en curso sin ejecutar nada (la IA lo usa cuando la pelota se le fue). |
| `BallHandler.clip_plant_velocity(clip: StringName, contact_time: float, foot: int, playback: float)` | 690 | Velocidad (adelante, derecha) en m/s del cuerpo que deja QUIETO el pie de apoyo de un clip en el sitio en los KICK_PLANT_TIME previos al con |
| `BallHandler.plant_velocity(contact: Dictionary, yaw: float, v: Vector3)` | 708 | Velocidad del cuerpo (mundo) con el pie de apoyo plantado para un contacto, con orientacion yaw y velocidad previa v. La velocidad del clip  |
| `BallHandler.kick_body_travel(v: Vector3, latency: float, plant_v: Vector3)` | 718 | Recorrido del cuerpo en las proximas latency s de una patada que empieza (o sigue) con velocidad v: a velocidad constante hasta plantar el p |
| `BallHandler.kick_nudge_cap(v: Vector3)` | 723 | Ajuste de paso maximo (m/s) a la velocidad de cuerpo v. |
| `BallHandler.kick_adjust_capacity(v: Vector3, latency: float)` | 727 | Metros de ajuste de paso que caben antes de plantar el pie en una patada de latencia `latency`. |
| `BallHandler.is_clip_kick_in_progress()` | 731 | true durante una patada con clip (balanceo hasta el contacto). |
| `BallHandler.kick_body_velocity()` | 735 | Velocidad del cuerpo durante una patada con clip: la de partida, frenada con el pie de apoyo plantado. |
| `BallHandler._steer_clip_kick()` | 752 | Ajuste de paso en lazo cerrado: cada fotograma se vuelve a predecir donde estara el pie en el contacto y se corrige lo que falta con el cuer |
| `BallHandler._fast_prediction(latency: float)` | 765 | Lo comun a todos los clips de una accion en predicted_foot_to_ball (misma latencia): giro previsto, pelota prevista y velocidad. |
| `BallHandler._foot_to_ball_fast(contact: Dictionary, pre: Dictionary)` | 775 | predicted_foot_to_ball con lo precalculado por _fast_prediction (mismas cuentas, sin repetir las comunes). |
| `BallHandler.predicted_foot_to_ball(contact: Dictionary, latency: float, body_v: Variant = null)` | 780 |  |
| `BallHandler.contact_samples(contact: Dictionary)` | 792 | Puntos validos de golpeo de un clip: muestras de la trayectoria del pie (adelante, arriba, derecha) con la punta baja y lanzada hacia adelan |
| `BallHandler.contact_samples_cached(clip: StringName, contact: Dictionary)` | 808 | contact_samples de un clip, con a lo sumo MAX_SAMPLES instantes repartidos por la trayectoria (modo 4), guardado por clip. |
| `BallHandler.plan_aerial_kick(action: StringName, charge: float)` | 833 | Planifica un golpeo con la pelota en el aire: busca, entre los clips de cabezazo y volea, el instante en que la cabeza o la punta del pie (c |
| `BallHandler._path_bbox(clip: StringName, key: String, path: PackedVector3Array)` | 916 | Caja (min, max) de la trayectoria `key` de un clip en el marco del cuerpo, entre 0.1 y 1.1 s (lo que prueba el planificador aereo), guardada |
| `BallHandler._trace_kick_fields(clip: StringName, c: Dictionary, latency: float, offset: float, bp: Vector3, delta: Vector3, step: Vector3, score: float, breakdown: Dictionary, part: String = "foot")` | 933 | Campos de traza de un instante de contacto evaluado (pelota prevista, punto del pie, errores y coste desglosado). |
| `BallHandler.plan_clip_kick(action: StringName, charge: float, lob: bool, preferred_clip: StringName = &"")` | 950 | Elige el mejor clip, pierna E INSTANTE DE CONTACTO para la accion. El instante sale de la trayectoria real del pie del clip (contact_samples |
| `BallHandler.estimated_kick_dir(action: StringName, stick: Vector3, charge: float, lob: bool)` | 1063 | Direccion (plana) en la que saldria la pelota si se golpeara ahora: la misma asistencia que el golpeo real (receptor del pase, arco del tiro |
| `BallHandler.plan_turn_kick(action: StringName, alpha: float, adjust_max: float)` | 1087 | Modo 4: planifica un golpeo girando hacia un destino a `alpha` grados del frente (+ izquierda). El cuerpo sigue la raiz y el rumbo del clip  |
| `BallHandler._turn_kick_clip_t()` | 1154 | Golpeo girando en curso: instante del clip ahora. |
| `BallHandler.kick_body_yaw()` | 1159 | Orientacion del cuerpo durante un golpeo girando (NAN si no hay): la del clip. |
| `BallHandler._turn_kick_foot_to_ball()` | 1167 | Golpeo girando: donde quedara la punta del pie en el contacto respecto a la pelota prevista, con el cuerpo en su sitio de ahora siguiendo la |
| `BallHandler._start_clip_kick(action: StringName, plan: Dictionary, stick_world: Vector3, charge: float, lob: bool)` | 1184 |  |
| `BallHandler._log_kick(action: StringName, result: StringName, extra: Dictionary = {})` | 1221 |  |
| `BallHandler._contact_toe_now()` | 1240 | Punta del pie del golpeo en curso (esqueleto vivo), o ZERO. |
| `BallHandler._ball_still_arriving(dt: float, toe: Vector3)` | 1245 |  |
| `BallHandler._contact_reset()` | 1267 |  |
| `BallHandler._finish_clip_kick()` | 1274 | Resuelve el golpeo de una patada con clip: valido solo si la pelota esta a kick_contact_radius del pie REAL (posicion de contacto del clip,  |
| `BallHandler._finish_kick()` | 1333 |  |
| `BallHandler.perform_action(action: StringName, stick_world: Vector3, charge: float, lob: bool)` | 1348 | Ejecuta el golpeo de una accion (pase, filtrado, centro o tiro) en el instante de contacto. |
| `BallHandler.perform_through(stick_world: Vector3, charge: float, lob: bool)` | 1363 | Pase filtrado: al espacio por delante del desmarque del receptor. |
| `BallHandler.perform_cross(stick_world: Vector3, charge: float, low: bool)` | 1376 | Centro al area: con ALTO sale raso; con carga alta, tenso; si no, elevado. |
| `BallHandler.perform_pass(stick_world: Vector3, charge: float, lob: bool)` | 1390 | Ejecuta un pase ahora mismo (la pelota debe estar a alcance). Devuelve el resultado. |
| `BallHandler.perform_shot(stick_world: Vector3, charge: float, lob: bool)` | 1406 |  |
| `BallHandler._after_kick(action: StringName, res: KickModel.KickResult)` | 1425 |  |
| `BallHandler.get_dt()` | 1474 |  |
| `BallHandler._sample_feet(dt: float)` | 1479 | Lee las puntas de los pies del esqueleto animado. Si no se mueven (headless, maniqui) feet_live queda en false y la conduccion usa la cadenc |
| `BallHandler.foot_distance(i: int, ball_pos: Vector3)` | 1519 | Distancia (m) del centro de la pelota al pie i (segmento del tobillo a la punta). |
| `BallHandler._foot_strike(b: Ball, mode: StringName, close_in: bool = false)` | 1531 | Pie (0 izquierdo, 1 derecho) que puede tocar la pelota ahora: punta baja, a FOOT_CONTACT de la pelota, por detras de ella y yendo hacia dela |
| `BallHandler._ball_at_foot(off: Vector3, fwd: Vector3, mode: StringName)` | 1595 |  |
| `BallHandler.touch_turn_max_deg(speed: float)` | 1618 | Giro maximo (grados) que un toque puede dar a la pelota a esta velocidad: caminando casi cualquiera, a sprint poco (un cambio de rumbo mayor |
| `BallHandler.turn_toward(from: Vector3, to: Vector3, max_rad: float)` | 1630 | Gira `from` hacia `to` como mucho `max_rad` (en el plano). |
| `BallHandler.carry_gap(speed: float, skill: float)` | 1642 | Distancia (m) a la que el jugador quiere la pelota respecto al pie a una velocidad dada. Ley de tres tramos (parado / trote / sprint) con lo |
| `BallHandler._carry_skill()` | 1651 |  |
| `BallHandler._touch_interval(ratio: float)` | 1656 | Segundos entre toques. Con el pack, la cadencia sigue a la de los pasos de la animacion (uno por apoyo a trote, uno cada dos apoyos a carrer |
| `BallHandler.nearest_opponent(radius: float)` | 1670 | Rival mas cercano a este jugador dentro de `radius` (o null). Lo usan la proteccion y el calculo de presion. |
| `BallHandler._touch_mode(desired_dir: Vector3, stick_mag: float, turn_angle: float)` | 1686 | Modo del proximo toque segun la intencion del joystick y el estado del cuerpo. |
| `BallHandler._shrug_resting_ball()` | 1709 |  |
| `BallHandler._body_partner(b: Ball, radius: float)` | 1743 | Otro jugador (de cualquier equipo) con la pelota apoyada tambien en su cuerpo (a menos de radius en el plano), o null. |
| `BallHandler.reset_caches()` | 1816 | Vacia los datos calculados con la libreria de clips (cambian al cambiar de modo). |
| `BallHandler.touch_candidates(base: StringName)` | 1861 |  |
| `BallHandler.uses_clip_touches()` | 1922 |  |
| `BallHandler.is_clip_touch_in_progress()` | 1927 | true si hay un toque de clip en curso (entre el disparo y el contacto). |
| `BallHandler._body_coords(p: Vector3)` | 1931 | Punto p respecto al cuerpo: (adelante, altura, derecha) en metros. |
| `BallHandler._toe_body(i: int)` | 1936 | Punta del pie i respecto al cuerpo: (adelante, altura, derecha) en metros. |
| `BallHandler._clip_driving()` | 1941 | Conduccion por toques de clip en marcha: con esqueleto vivo y fuera de la arrancada. Fuera de esto la conduccion por pisadas funciona exacta |
| `BallHandler._launching()` | 1946 | Arrancada: SPRINT pedido lejos de la velocidad punta. Mandan los toques largos de arrancada de siempre (la pelota al espacio y el jugador ac |
| `BallHandler.clip_touch_gap(speed: float)` | 1952 | Distancia (m) por delante del cuerpo a la que los toques de clip dejan la pelota a esta velocidad (centro de la pelota en el punto al que ap |
| `BallHandler._tight()` | 1962 | Conduccion con la pelota pegada y toques de cualquier pie: en curva o en control cercano. |
| `BallHandler._clip_touch_update(desired_dir: Vector3, stick_mag: float)` | 1965 |  |
| `BallHandler._plan_clip_touch(c: Dictionary, scale: float, b: Ball, track: PackedVector3Array)` | 2068 | Recorre la punta del clip c (en el cuerpo) frente a la pelota prevista y devuelve el primer punto de la ventana en que la alcanza: {time (s  |
| `BallHandler._predict_body(base_period: float, max_time: float, keep_track: bool = false, braked_turn: bool = false)` | 2107 | Cuerpo previsto con la misma ley que Locomotion: la velocidad va hacia la pedida (_touch_target_speed) con su aceleracion y el rumbo gira ha |
| `BallHandler._body_point(pos: Vector3, yaw: float, fwd: float, side: float)` | 2148 | Punto del plano a `fwd` metros por delante y `side` a la derecha de un cuerpo en pos con rumbo yaw. |
| `BallHandler._foot_ik()` | 2152 |  |
| `BallHandler._ik_fwd()` | 2156 |  |
| `BallHandler._plan_lat_tol()` | 2161 | En recta la pelota va en el carril del pie que la toca (un toque por zancada con el mismo pie, como en el video de referencia); en curva el  |
| `BallHandler.toe_world(i: int)` | 2165 | Punta del pie i en el mundo tal como se dibuja (con la correccion del IK del toque). |
| `BallHandler._update_touch_ik(a: Dictionary, b: Ball)` | 2172 | Correccion del pie del toque en curso: del punto de contacto planeado del clip (sobre el cuerpo previsto en ese instante) al punto real de l |
| `BallHandler._fade_touch_ik()` | 2199 | Tras el toque la correccion se suelta en TOUCH_IK_OUT s (el pie vuelve al gesto del clip sin saltos). |
| `BallHandler._release_touch_ik(a: Dictionary)` | 2212 |  |
| `BallHandler._clip_touch_step()` | 2217 | Un paso del toque de clip en curso: contacto cuando la punta viva llega a la pelota dentro de la ventana. |
| `BallHandler.force_dribble_touch(dir: Vector3)` | 2324 | Un toque de conduccion en la direccion dada (lo usa una accion con raiz, que no pasa por update()). |
| `BallHandler._catching_ball(off: Vector3, fwd: Vector3, body_v: Vector3, ball_v: Vector3)` | 2332 | El cuerpo se acerca a la pelota que va delante (mas rapido que ella) y en CATCH_LEAD s la tendra al alcance del pie. |
| `BallHandler._try_dribble_touch(desired_dir: Vector3, stick_mag: float)` | 2337 |  |
| `BallHandler._json_kicks()` | 2629 | true si este jugador patea con los clips del modo 4 (Json). |
| `BallHandler.kick_reach()` | 2633 | Distancia (m) maxima entre el pie del clip y la pelota para que el golpeo cuente. |
| `BallHandler._json_kick_ik()` | 2636 |  |
| `BallHandler._json_touch_ik_start(foot: int, push: Vector3, max_reach: float = JSON_TOUCH_IK_MAX)` | 2654 |  |
| `BallHandler._json_touch_ik_step(dt: float)` | 2666 |  |
| `BallHandler._steer_angle(b: Ball, desired_dir: Vector3)` | 2691 | Angulo (grados) entre el camino de la pelota (su velocidad, o hacia donde esta si va quieta) y el rumbo pedido. |
| `BallHandler._steer_touch_ready(b: Ball, desired_dir: Vector3, stick_mag: float, interval: float)` | 2700 |  |
| `BallHandler._carry_speed_after_turn(stick_mag: float, turn_angle: float)` | 2710 | Velocidad a la que el jugador podra llevar la pelota tras el giro (en un giro cerrado el cuerpo frena antes de acelerar hacia el rumbo nuevo |
| `BallHandler._shield_dir(dist: float)` | 2721 | Direccion en la que conviene colocar la pelota al pararla: lejos del rival mas cercano (proteccion). Cero si no hay rival a quien proteger l |
| `BallHandler.plan_carry(desired_dir: Vector3, stick_mag: float, dt: float)` | 2741 | Decide, ANTES de que el cuerpo gire, hacia donde mira el jugador mientras lleva la pelota. Lo llama el futbolista al principio del paso de f |
| `BallHandler.settle_steer()` | 2777 | Frenar con la pelota: con el joystick suelto, si la pelota propia sigue rodando lejos del pie, el jugador la acompana hasta tenerla al alcan |
| `BallHandler._settle_close(b: Ball, off: Vector3, bv: Vector3)` | 2835 | settle_steer con la pelota al alcance: [direccion, magnitud, hacia donde mirar] para que el cuerpo quede de frente a la pelota con ella a se |
| `BallHandler._magnitude_for_speed(speed: float)` | 2870 | Inversa de Locomotion.speed_for_magnitude (magnitud del joystick para ir a `speed` m/s). |
| `BallHandler.kick_approach_steer()` | 2882 | Golpeo pedido (cargando o en espera) con la pelota PROPIA por delante (o suelta, para el jugador de la persona), fuera del alcance del pie y |
| `BallHandler.holding_for_kick()` | 2915 | Golpeo pedido que todavia no puede salir (bloqueo tras un movimiento con pelota o una recepcion) con la pelota propia al pie: el jugador se  |
| `BallHandler.is_approaching_for_kick()` | 2922 | true si hay un golpeo en espera y el jugador se esta acercando de verdad a su pelota (ver kick_approach_steer). |
| `BallHandler.carry_turn_scale(desired_dir: Vector3)` | 2935 | Escala del giro del cuerpo mientras conduce. Con la pelota al alcance pero NO hacia el rumbo pedido (un cambio de direccion grande), el cuer |
| `BallHandler._curve_turn_scale(want: Vector3, off: Vector3)` | 2964 |  |
| `BallHandler.carry_steer(desired_dir: Vector3)` | 3003 |  |
| `BallHandler.carry_catch_up_mag(desired_dir: Vector3)` | 3038 | Pelota propia por delante en el rumbo pedido pero mas lejos que la distancia de conduccion (un toque largo, frenar con la pelota rodando): i |
| `BallHandler.follow_steer(desired_dir: Vector3, stick_mag: float, sprint: bool)` | 3069 |  |
| `BallHandler.carry_face()` | 3122 | Direccion a la que debe mirar el cuerpo mientras conduce (control lateral o proteccion). Cero = libre. |
| `BallHandler._try_first_touch(desired_dir: Vector3)` | 3128 |  |
| `BallHandler.first_touch_absorb(off: Vector3)` | 3179 | Fraccion (0.15-0.93) de la velocidad de la pelota que amortigua el primer toque: control del jugador, pelota por detras (off: pelota respect |
| `BallHandler.attempt_tackle(carrier: Footballer)` | 3191 | Intenta quitar la pelota. No esta garantizado: depende de distancia, orientacion, equilibrio, velocidad relativa y atributos de ambos jugado |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/player/ball_handler.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `BallHandler.kicked(action: StringName, result: KickModel.KickResult)` | 11 | Interaccion del futbolista con la pelota. Todo ocurre mediante IMPULSOS en el instante del contacto: nunca se fija la posicion de la pelota ni se anula su velocidad. - Conduccion: toques periodicos cuya fuerza depende de la velocidad, el giro y los atributos. - Control de primer toque: absorbe parte de la energia de un balon que llega (con error). - Pase y tiro: se calculan con PassAssist / ShotAssist; se ejecutan al soltar el boton y se guardan en buffer 0.3 s si la pelota aun no esta a alcance. - Disputa: robo probabilistico dependiente de orientacion, atributos y velocidad relativa. |
| `BallHandler.touched_ball(kind: StringName)` | 12 |  |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/player/footballer.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `Footballer.kicked(action: StringName, result: KickModel.KickResult)` | 8 | Futbolista de campo. Orquesta: entrada (InputFrame) -> intencion -> locomocion -> contacto con la pelota. No importa si lo controla una persona, la IA o la red: todos pasan por InputFrame.  Estado replicable separado de la presentacion: la presentacion es FootballerVisual (hijo "Visual"). |
| `Footballer.tackled(won: bool)` | 9 |  |
<!-- /AUTO -->

## Recorrido de ejecución

**Cada paso de física** (`Footballer._physics_process`):
1. `InputSource.poll` → `InputFrame` (si `MatchContext.input_enabled` es falso, un `InputFrame` vacío).
2. `MatchContext.screen_to_world(frame.move)` → dirección deseada en el mundo (relativa a la cámara).
3. Si `press_held` y el equipo no controla el balón: `PressController.update` sustituye la dirección/intensidad (la presión intenta robar con `BallHandler.attempt_tackle`).
4. Con la pelota cerca (`BallHandler.has_possession`) se limita la velocidad (`0.86–0.97 × max_sprint_speed` según `ball_carrying`).
5. `Locomotion.step`: velocidad objetivo por intensidad del joystick (`walk/jog/run`) o `sprint`; giro limitado por velocidad; si el giro es muy cerrado a alta velocidad el objetivo baja a `walk_speed` (frenar antes de girar); aceleración con `accel/decel/brake`; el agarre elimina la componente lateral.
6. `move_and_slide` (la colisión con paredes/jugadores corrige la velocidad real) → `rotation.y = locomotion.yaw`.
7. `BallHandler.update` en este orden: botones con carga (`_update_buttons`) → si hay patada en curso, avanzar su temporizador y, al llegar el contacto, `_finish_kick` → ejecutar acción pendiente en buffer (`_try_execute_pending` → `request_kick`) → si hay `lockout`, nada más → `_try_first_touch` → `_try_dribble_touch`.
8. `FootballerVisual.update_motion` (animación y lean).

**Conducción** (`BallHandler._try_dribble_touch`; corregida en la integración del pack, ver [ANIMATION_PACK](ANIMATION_PACK.md) «ANTES y DESPUÉS»: error del toque sobre la velocidad relativa al jugador, hueco planificado acotado al alcance del siguiente toque, umbral de re-toque según ese hueco y, con el pack, cadencia = apoyos de la animación): cuando el temporizador de toque expira y la pelota está al alcance (`touch_reach`·0.85, o más en giros/lateral), se calcula una posición objetivo delante del jugador (`touch_lead_jog`/`touch_lead_sprint`), la velocidad necesaria para colocarla allí y se aplica con `Ball.kick` (error angular y de módulo según sprint, giro y atributos). Nunca se fija la posición de la pelota.

**Patada** (pase/tiro). Dos caminos; elige `BallHandler.uses_clip_kicks()`:

- **Con el pack** (visual con `PackLibrary` y clips de patada en el sitio): al soltar el botón (o por buffer de 0.3 s) `_try_execute_pending` llama a `plan_clip_kick`, que para cada clip candidato (`AnimationCatalog.kick_candidates`: pase → `Soccer_Pass` / `strike_foward_jog_inplace`, ambos pies; tiro y pase alto → `strike_foward_jog_inplace`) recorre los puntos válidos de la **trayectoria medida de la punta del pie** (`contact_samples`: punta a ≤ `kick_foot_max_height`, avanzando ≥ `kick_foot_min_speed`), predice jugador y pelota hasta ese instante (`predicted_foot_to_ball`: velocidades y giro reducido por `kick_turn_scale`) y calcula cuánto debería moverse el cuerpo (ajuste de zancada ≤ `kick_adjust_max` + `kick_adjust_sprint`·ratio de sprint). Solo si el residuo queda ≤ `kick_start_residual` empieza la patada (`_start_clip_kick`): reproduce el clip acelerado (≤ ×`kick_clip_speed_max`) y desde el punto necesario para llegar al contacto en `kick_latency` s (el **tiro** suma `shot_windup` 0.12 s + `shot_windup_charge` 0.06 s × carga y se reproduce casi a velocidad natural desde antes del balanceo: se ve la pierna atrás —prueba03: el tiro duraba 0.17 s en pantalla—; el pase conserva 0.2 s); mueve el cuerpo con `Footballer.nudge_velocity` (no entra en `Locomotion`) y baja el giro (`Locomotion.turn_scale`). **Si ningún pie llega, no hay patada**: tras el buffer se cuenta `kick_stats["out_of_reach"]` y se emite `KICK_WHIFF` con `reason = "out_of_reach"`. En el contacto `_finish_clip_kick` mide la distancia entre la pelota y el pie **real** (posición de contacto del clip con el jugador donde está ahora): ≤ `kick_contact_radius` → `perform_pass`/`perform_shot` (impulso con las asistencias, `PASS`/`SHOT` con `clip`, `foot_distance`, `latency`, `adjust_m`); si no, `KICK_WHIFF` con `reason = "missed"`, sin impulso ni teletransporte. Cada intento queda en `kick_log` y `kick_stats`.
- **Sin el pack** (o sin visual): el camino antiguo. `request_kick` fija `contact_delay` y arranca `ProceduralPose` con ese tiempo; en el contacto `_finish_kick`, si la pelota sigue a `touch_reach + 0.5`, `perform_pass`/`perform_shot`; si no, `KICK_WHIFF`.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh pack_kick` (contacto pie–pelota con clips; se omite sin la librería local), `tools/run_tests.sh pack_dribble` (métricas de conducción y ejecución de pase/tiro por régimen, ~15 s), `tools/run_tests.sh locomotion`, `tools/run_tests.sh dribbling`, `tools/run_tests.sh kick_timing`, `tools/run_tests.sh touch_controls` (extremo a extremo con joystick táctil). Todo: `tools/run_tests.sh`.
- **Última ejecución completa (2026-10-26):** headless con la librería local: 85 pruebas, 0 fallidas, 2 omitidas (necesitan render), 529 comprobaciones; con render (Xvfb): 85 pruebas, 0 fallidas, 553 comprobaciones; sin la librería local: 85 pruebas, 0 fallidas, 26 omitidas, 221 comprobaciones. `test_kick_timing` cubre solo el camino procedural (fuerza `prefer_pack = false`).

<!-- AUTO:tests:tests/test_locomotion.gd -->
| Prueba | Línea |
|---|---|
| `test_acceleration_is_progressive` | 15 |
| `test_sprint_is_faster_and_drains_stamina` | 35 |
| `test_stops_without_sliding_like_ice` | 46 |
| `test_turning_rate_depends_on_speed` | 61 |
| `test_reversal_at_sprint_brakes_first_and_never_slides_sideways` | 83 |
| `test_attributes_scale_speed_within_limits` | 107 |
<!-- /AUTO -->

*Pruebas de test_dribbling: eliminadas en la reforma (modo de fútbol 5 quitado; en el historial de git).*

<!-- AUTO:tests:tests/test_kick_timing.gd -->
| Prueba | Línea |
|---|---|
| `test_ball_impulse_happens_at_contact_not_at_button_release` | 9 |
| `test_kick_whiffs_if_the_ball_moves_away_during_the_swing` | 46 |
| `test_pose_curves_are_continuous_and_peak_at_contact` | 71 |
<!-- /AUTO -->

tests/test_pack_kick.gd (borrado: Mixamo/Mocap): bloque generado quitado.

*Pruebas de test_pack_dribble_metrics: eliminadas en la reforma (modo de fútbol 5 quitado; en el historial de git).*

*Pruebas de test_pack_reactions: eliminadas en la reforma (modo de fútbol 5 quitado; en el historial de git).*

- **Qué podría romperse:** deslizamiento tipo hielo o giros instantáneos; pelota que se escapa al trotar; patada que se aplica antes/después del gesto; jugador atravesando paredes (*test_player_collides_with_walls (eliminada en la reforma)*).

## Conducción física y golpeos en todas direcciones (2026-11-05)

La persona sentía que la pelota seguía al jugador «como con un hilo» al girar o tirar una diagonal tras un toque largo.
La sonda *tests/test_physical_dribble.gd (eliminada en la reforma; en el historial de git)* (con render) lo confirmó en el código de entonces: a sprint la mitad de los toques
eran **sin pie**, uno a **1.28 m** del cuerpo (toque `redirect` desde lejos), y el jugador corría hasta **71°** apartado de su
pelota. Como en FTS / Ultimate Clash (ver [`fases/00_auditoria_modo_json.md`](../../fases/00_auditoria_modo_json.md) §C), la
pelota cambia de rumbo solo en el toque del pie y el jugador la sigue:

- **Toque solo con el pie** (`BallHandler._try_dribble_touch`): sin la ventana de toques «de rescate» a 1.3–1.5 veces el
  alcance. Con pies vivos, toque cuando una punta llega a la pelota; sin punta medida, solo si la pelota está en la **zona del
  pie** (`_ball_at_foot`: `FOOT_ZONE_FWD` 0.62 m (+0.14 a sprint) por delante y `FOOT_ZONE_LAT` 0.34 m al costado; para parar,
  llevar de costado o girar, también el costado del cuerpo, y parado un paso más: hasta 0.95 alcances y 0.62 m al costado) y
  además se esté yendo de la zona o el cuerpo se le venga encima (`OVERRUN_FWD` 0.18 m). El toque de rumbo del modo 4
  (`_steer_touch_ready`) y el de alcance (`_catching_ball`) siguen, ahora con la pelota en la zona del pie.
- **Giro máximo por toque** (`touch_turn_max_deg`; `PlayerTuning.touch_turn_walk_deg` 150, `touch_turn_jog_deg` 110,
  `touch_turn_sprint_deg` 70; ×0.85–1.15 según conducción): un cambio mayor lo hacen varios toques o los giros con pelota del
  banco (`JsonBallMove`, sin cambio). La pelota sale recta (ya no se la coloca sobre la curva que iba a hacer el jugador).
- **El jugador sigue a la pelota** (`BallHandler.follow_steer`, en `Footballer` antes de `carry_catch_up_mag`): con la pelota
  fuera del pie corre al punto por detrás de ella (respecto del rumbo del próximo toque) donde estará cuando llegue; al pie
  puede encarar el rumbo del próximo toque. Intensidad: la del joystick, salvo que haga falta apurarse (la misma ley que
  `carry_catch_up_mag`: alcanzar en `CATCH_UP_TIME` 0.6 s lo que pasa de la distancia de conducción), así frenar con el
  joystick sigue frenando. No actúa con un golpeo pedido ni durante un movimiento con pelota (sus propios controles).
  Los límites de giro por toque son amplios a propósito (no recortan regates ni cambios de dirección): solo impiden que un
  toque a sprint dé vuelta la pelota 180°; para eso están los giros con pelota del banco.
- **Golpeo tras un giro con pelota**: con el destino detrás y sin golpeo girando que llegue, `JsonBallMove.turn_for_kick` gira
  con la pelota; la orden de golpeo ahora **espera a que termine el giro** y cuenta su tiempo desde ahí (antes caducaba a los
  0.5 s, con el clip aún girando).
- **Golpeo pedido con la pelota suelta justo por delante** (a menos de 1.5 alcances): el jugador camina hasta ella
  (`kick_approach_steer`); antes la traía un toque a distancia.
- **Golpeo pedido que espera el fin del bloqueo** tras un movimiento con pelota o una recepción (`PlayerActions` deja
  `lockout` ≥ 0.3 s): con la pelota propia a menos de 0.8 m el jugador se queda sobre ella a pasos cortos
  (`BallHandler.holding_for_kick`, intensidad ≤ 0.2 en `Footballer`); antes seguía hacia el joystick, llegaba a 2 m/s y
  dejaba la pelota 0.5 m detrás (pase tras recibir perdido, *test_receive::test_reception_then_pass (eliminada en la reforma)*).
- Medido (render, modo 4): sprint + diagonal 40° → pelota ≤ 1.0 m, jugador ≤ 25° de la pelota; trote + giro 90° → con un
  giro con pelota del banco (toques del clip a 0.01 m del pie); `live_feet` 7/7 (a sprint 4–7 de 9–10 toques con la punta
  medida: sin toques a distancia el cuerpo alcanza la pelota empujada; antes 8 de 9), `live_kicks` 4/4 (50 de 50 golpeos con
  contacto). Direcciones de golpeo: ver [JSON_MODE](JSON_MODE.md#golpeos-hacia-cualquier-dirección-con-el-banco-2026-11-05).

## Control cercano del balón: cómo se siente y por qué (medido)

La conducción es un modelo de **toques por impulso con una distancia objetivo que depende de la velocidad**
(`BallHandler.carry_gap`): parado la pelota queda pegada al pie y a sprint se empuja al espacio. No hay imán ni
posición forzada: cada toque es un `Ball.kick` calculado para que la pelota llegue a ese punto cuando el jugador
llegue allí.

| Modo de toque (`BallHandler.last_touch_mode`) | Cuándo | Qué hace |
|---|---|---|
| `settle` | joystick suelto | Para la pelota con el pie que llega (desde 2026-11-05: solo delante del cuerpo, sin toques sin pie salvo que el cuerpo se le venga encima; la deja quieta donde la para). Frenando desde carrera la amortigua hasta donde el cuerpo va a detenerse; con un rival cerca la coloca del lado protegido y el cuerpo se interpone. |
| `lateral` | empuje de costado (55°–125°) a poca velocidad y joystick suave | Desplaza la pelota al lado **sin girar el cuerpo** durante `lateral_hold_seconds`; el jugador se mueve de lado con la mezcla direccional. Después gira normalmente. |
| `redirect` | cambio de rumbo > 55° | Lleva la pelota al rumbo nuevo y más pegada al pie cuanto más cerrado es el giro. |
| `setup` | hay un pase o tiro pulsado esperando | Acerca la pelota al pie (60 % de la distancia normal) para poder ejecutar sin frenar. |
| `carry` | conducción normal | Coloca la pelota a `carry_gap(velocidad)` delante, con el toque largo aleatorio del sprint. |

**Parámetros** (`PlayerTuning`): `carry_gap_stand` 0.38 m, `touch_lead_jog` 0.70 m, `touch_lead_sprint` 1.20 m,
`settle_gap` 0.38 m, `touch_escape_factor` (toque de recuperación si la pelota va a salirse en 0.14 s),
`touch_error_max_deg` (tope del error del toque), `lateral_hold_seconds`, `lateral_max_stick`, `shield_radius`.

**Medidas** (*tests/test_gameplay_feel.gd (eliminada en la reforma; en el historial de git)*, con la librería del pack):

| Situación | Resultado |
|---|---|
| Conducción lenta (joystick 0.25 / 0.40 / 0.55) | pelota a 0.58 / 0.61 / 0.65 m de media, máximo 0.69 m |
| Trote vs sprint | 0.65 m vs 1.27 m de media; máximo a sprint 1.56 m |
| Frenar desde trote / sprint | la pelota queda a 0.37 / 0.35 m y se detiene (0.00 m/s) |
| Giro sobre la pelota parado (90° / 180° / 270°) | 0.36 / 0.39 / 0.29 m |
| Control lateral | 0.70 m de desplazamiento lateral en 0.5 s con el cuerpo fijo, pelota a 0.33 m |
| Giros conduciendo (60/90/135/−90°), 20 intentos por ritmo | pierde la pelota: trote 0/20, carrera 1/20, sprint 0/20 |
| Pase pulsado conduciendo | parado 12/12, trote 12/12, carrera 12/12, sprint 12/12 |
| Recepción en carrera | la controla sin bajar de 1.26 m/s, pelota a 0.76 m |
| Acción cancelada (pelota retirada) | sin patada colgada, sin bloqueo, el jugador sigue respondiendo |

**Orientación del cuerpo al conducir** (`BallHandler.plan_carry`, lo llama `Footballer` antes de mover el cuerpo):
decide si el jugador conserva su orientación (control lateral) o da la espalda al rival (proteger la pelota). Usa el
mismo `Locomotion.face_override` que el marcaje en jockey, así que la animación direccional ya lo acompaña.

## Limitaciones conocidas

- Proteger la pelota parado no es indefinido: `BallHandler.attempt_tackle` reduce el escudo del portador cuando está quieto, y el defensor rodea el cuerpo para atacar la pelota por el lado libre (`PressController`). Medido: un portador inmóvil la conserva 5–17 s ante un presionador.
- La IA (`AIInput`) y el cambio de jugador existen (ver [MATCH](MATCH.md)); `PlayerActions` añade barrida, caídas, levantarse y regate (`skill_pressed`, tecla U / botón REGATE) con movimiento de raíz. Límite: la IA no se ha calibrado contra humanos.
- Las señales `Footballer.tackled`/`Footballer.kicked` y `BallHandler.touched_ball` se emiten sin ningún consumidor.
- `Footballer.display_name`, `shirt_number` y `is_human_controlled` no los usa ninguna lógica o interfaz todavía.
- **Patada con clip (medido, *test_pack_dribble_metrics (eliminada en la reforma)*):** latencia 0.20 s frente a 0.10–0.18 s de la patada procedural; a sprint el pase/tiro se ejecuta el 88 % de las pulsaciones (el resto se descarta por no haber pie que llegue). El ajuste de zancada (media 0.26–0.47 m) mueve el cuerpo sin pasos animados y es sobre todo lateral: puede verse un deslizamiento leve (solo medido, no mirado en vídeo). `soccer_penalty_kick` y `Chip` no están conectados (llevan carrera de 2.5 / 4.4 m).
- **Cadencia de toques ≠ fase del paso:** con el pack el intervalo entre toques sigue a la frecuencia de apoyos de la animación, pero no se sincroniza con el pie que pisa.
- **Sin estado de caída/falta/salto:** `fall`, `getup`, `soccer_tackle`, `soccer_trip` y los saltos del catálogo no tienen disparador (no se inventó mecánica).
- El atributo `dribbling` (regate) no se usa; no hay amagues ni regates con ventanas de ejecución (solo toques de colocación).

## Árbitro de acciones (`ActionArbiter`, F2, 2026-10-30)

Antes, cinco puntos pedían clips sobre la misma ranura de pose (`FootballerVisual.play_pack_clip`, que siempre cortaba la
acción en curso) y cada uno se protegía por su cuenta (`is_action_playing`, `actions.active`). Conflictos demostrados
(prueba determinista y partidos de IA del modo 4, 3 × 180 s): una falta sobre un jugador en un movimiento con pelota de
clip no lo derribaba; un festejo pedido durante una caída sustituía la pose mientras la raíz seguía moviendo el cuerpo;
`PlayerActions.reset` dejaba la pose sonando sin dueño; la pose de las acciones con raíz se apagaba una imagen antes que la
raíz (237 imágenes en los partidos); gestos en el sitio empezaban con el cuerpo corriendo (242 imágenes).

- **Quién pide:** `PlayerActions.start/start_move` (raíz: caída, levantarse, barrida, giro, regate, tropiezo, balón parado,
  movimiento con pelota), `BallHandler._start_clip_kick` (golpeo), `Footballer` (espera, capas de la marcha, recepción,
  bloqueo, reacciones), `PlayerActions.tackle_gesture/press_gesture/stumble` (gestos). El arquero y el árbitro siguen con su
  propia pose (`FootballerVisual.arbiter == null`).
- **Regla:** solo un nivel estrictamente mayor interrumpe; con igual o menor nivel se rechaza y la acción en curso se
  completa. La interrumpida se corta del todo (`PlayerActions.interrupt`: raíz, encadenados, `JsonBallMove`; o
  `BallHandler.abort_kick`). Resuelto el contacto, el golpeo baja a capa (`relevel`): su continuación se ve, pero un giro o
  una caída ya pueden entrar, como antes.
- **Canales:** la marcha (`Locomotion` + BlendSpace) no se pide y convive con gestos, capas y golpeo; las acciones con raíz
  toman el cuerpo mientras duran. La pose de una acción con raíz se sostiene hasta que la raíz termina (`holds_pose`).
- **Liberación:** fin natural (`PlayerActions.tick`), corte (`PlayerActions.stop`), reinicio (`Footballer.place_at` →
  `ActionArbiter.reset`), caducidad (si el dueño ya no la sostiene, `current_level` la libera). Los testigos viejos no hacen
  nada (`release`/`handover`/`relevel` devuelven false y se cuentan como `obsoletas`).
- **Medido después:** pose distinta de la raíz 237 → 0 imágenes; pose en el sitio con el cuerpo corriendo 242 → 118 (son
  gestos que empezaron con el cuerpo casi quieto y quedan atrás al acelerar; el corte de `Footballer._json_clip_slides` los
  apaga en ≤ 8 imágenes). Pruebas: `tests/test_action_arbiter.gd` (9 pruebas, 44 comprobaciones).
- **Pendiente (otras fases):** nombres del pack sin clip JSON que el código pide y no hacen nada (`Idle_To_Sprint`,
  `Sprint_Turn`, `Running_Tired`, `Defender_2`, `Soccer_Spin`); las colisiones (`Footballer._check_player_collisions`)
  siguen sin aplicarse durante una acción con raíz.

## Recepción y control con clips (`JsonReceive`, F3 corregido, 2026-10-30)

La recepción es una acción con contacto real, elegida antes de que llegue la pelota (rasante, con bote, a media altura o
bajando de un globo). Corrige la primera versión de F3, que tomaba el primer `ball_touches` como primer contacto y descartaba
por nombre los controles aéreos (auditoría de los 124 clips).

- **Perfiles de contacto** (`ReceiveProfiles`, generado por `tools/json_anim/make_receive_profiles.py` desde los JSON
  originales): por clip, parte del cuerpo del primer contacto real (pie, pie en el aire, muslo, rodilla, pecho; `leg` si no se
  distingue), instante estimado (pico de la pierna o inclinación del tronco; no `ball_touches` ni `key_frame`), estado
  (auditoría: 23 `usable`, 27 `conditional`, 70 `pending`, 4 `not_reception`; tras la verificación visual de los 70 pendientes:
  **50 `usable`, 45 `conditional`, 25 `pending`, 4 `not_reception`**), condiciones (giro o salida con joystick, rival, pase
  posterior, salto), instante del pase o golpeo posterior, dirección de llegada del nombre y confianza (`estimated`,
  `verified`: contacto visto con la pelota en el visor: los 6 de F3 y los 45 confirmados en la verificación visual). Solo
  `usable` y `conditional` (con sus condiciones cumplidas) entran en la selección; los `pending` no.
- **Verificación visual** (2026-10-30, [`fases/F3_verificacion_visual_70.md`](../../fases/F3_verificacion_visual_70.md)):
  `receive_view.tscn` con `CLIP=<id>` reproduce un clip excluido de la selección y lanza la pelota (física real, calibrada) a
  la parte supuesta en el instante supuesto; tiras antes/durante/después del contacto y medida del esqueleto vivo. Resultado:
  45 confirmados (19 muslo, 15 pecho, 7 pie en el aire, 4 pie; 12 de ellos con otra parte que la supuesta por la cinemática: 7 pie en el aire, 4 pie, 1 pecho) y 25 sin
  confirmar (11 con el instante estimado al final del clip). Los veredictos viven en `VISUAL` / `VISUAL_NOT` del generador.
- **Lados:** los datos están en espejo respecto de los nombres (verificado en el modelo: «R_THIGH», «R_FOOT», «FROM_R_…»
  mueven la pierna izquierda del modelo). La geometría sale de los datos; la dirección de llegada del nombre se invierte
  («FROM_R_45» = +45°, por la izquierda) y el espejo cambia el signo.
- **Punto y trayectoria de contacto** (`JsonReceive.contact_point`): cinemática directa del clip sobre el esqueleto de
  `JsonRig` (reproduce `ball_touches` a ~3 mm y el pie animado a 4–8 cm) más la raíz del clip; el rumbo del clip solo cuando el
  juego lo aplica (`heading_mode` «turn», `ActionMotion`).
- **Plan** (`JsonReceive.plan`): trayectoria 3D (`BallPredictor`: gravedad, arrastre, bote, rodadura); para cada clip e inicio
  (0–0.3 s): distancia en el suelo (el paso corrige ≤ 0.4 m) y en altura (`PART_VTOL`) entre la parte del cuerpo y la pelota,
  carrera de entrada (y de salida con joystick), dirección de llegada (`DIR_TOL`), orientación de salida (joystick ≤ 50°; sin
  joystick sale casi parado y gira ≤ 60°), pelota que no cruza el cuerpo antes de la ventana de contacto. Cargando un pase o
  tiro solo entran los clips con pase posterior. Sin clip compatible: anticipación o control físico.
- **Anticipación** (`JsonReceive.approach`, usada por `Footballer`): dónde tendría que estar el cuerpo para que un clip
  compatible encaje con la pelota más adelante (≤ 2.5 m, alcanzable a tiempo, sin cambiar la carrera del jugador); el receptor
  va hacia allí (la persona solo con el joystick suelto) **conservando la orientación con la que se calculó el sitio**
  (`approach_face` → `Locomotion.face_override`: se desplaza de lado o hacia atrás). Antes se giraba hacia donde caminaba, el
  objetivo cambiaba en cada cálculo, al llegar ningún clip encajaba y la pelota quedaba para el control físico.
- **Contacto** (`JsonBallMove.step`, intención `receive`): cuando la pelota y la parte del cuerpo animada (posición y rumbo
  reales del cuerpo + su trayectoria en el clip) se encuentran dentro de la ventana (−0.12 / +0.25 s del instante estimado), no
  en un instante fijo; si no se encuentran, el toque se pierde y queda el control físico. Antes del contacto, si la pelota
  real se aparta de la trayectoria prevista (> 0.35 m o > 1 m/s: desviada, frenada, patinando), la recepción se corta enseguida
  para que actúe el control físico a tiempo. En la ventana el cuerpo es fantasma
  (la cápsula de 0.3 m es más ancha que las piernas); antes no.
- **Respuesta física** (`JsonReceive.contact_velocity`, ajustable en `PlayerTuning.receive_contact`): pie a ras de piso = la del
  clip más el rebote no amortiguado, **reflejado por la cara del pie** (que mira entre la llegada y la salida): de frente vuelve
  hacia donde vino, como antes; en un control orientado sigue hacia la salida (antes siempre volvía hacia el pasador y anulaba
  la salida: con el joystick a 120° la pelota salía a 0.37 m/s); pie en el aire, muslo, rodilla y pecho = choque con la normal de esa parte (restitución y
  conservación tangencial escaladas por lo que el jugador no amortigua, más un empuje hacia delante): el pie en el aire deja la
  pelota abajo, el muslo y la rodilla la levantan un poco, el pecho le quita casi toda la velocidad horizontal; la pelota cae
  delante del jugador.
- **Después:** toques de pie posteriores del clip solo si la pelota está ahí (si no, `segundo contacto no llega`: el clip se
  corta y el jugador va a por ella); un pase o golpeo del clip no se reproduce como impulso: el clip se corta antes y el golpeo
  lo da el sistema de pase/tiro (destino real) si hay orden. Árbitro: acción `ball_move`, nivel `BALL_MOVE` (sin cambios de F2).
- **Medido** (*tests/test_receive.gd (eliminada en la reforma; en el historial de git)*, modo 4, 2026-10-30 tras la verificación visual): 30 pruebas, 27 pasan (con render
  también *test_live_foot_meets_the_ball (eliminada en la reforma)*); parado, 42 de 42 pases rasos recibidos con clip y controlados; globo en carrera
  recibido con el pecho (el receptor frena hasta un clip casi parado); control orientado con el joystick a 120°: la pelota
  avanza 1.63 m hacia allí (antes 0.13 m).
- **Limitaciones:** 3 pruebas en rojo por la parte elegida (1.06 m → muslo de 3162 en vez de pecho; 0.91 m → rodilla de 0204
  en vez de muslo; pelota controlada en todos): decisión de diseño pendiente; sin clip de recepción aérea en carrera que se
  elija a esa velocidad; 25 clips siguen pendientes; rodilla y cabeza sin clip verificado; `BallPredictor` subestima el
  arrastre en el aire (vuelos de ~1 s llegan 10–20 cm más bajos).

## Programa maestro E1-E5 (2026-10-31)

- **Conducción, alcanzar la pelota** (`BallHandler.carry_catch_up_mag`, `CATCH_UP_TIME`, `CATCH_UP_MARGIN`; llamada en
  `Footballer` tras `carry_steer`): con la pelota propia demasiado adelantada en la dirección pedida, el joystick se eleva
  lo necesario para recuperarla en 0.6 s (al frenar quedaba a 1.79 m; ahora ~0.7 m). Prueba *test_mode4_dribble (eliminada en la reforma)*.
- **Toque al alcanzar la pelota** (`BallHandler._catching_ball`, `CATCH_LEAD`, `CATCH_CLOSING`): si el cuerpo acelera y
  alcanza la pelota del toque anterior (lanzada para la velocidad de antes), el toque no espera a la cadencia (de caminar a
  correr el cuerpo pasaba a 0.07 m de la pelota: «encima» 5 %; ahora 0 %). *test_live_feet (eliminada en la reforma)* (con render).
- **Esquivar una barrida** (`PlayerActions.avoid_tackle`, `AVOID_RADIUS`): la barrida fallida a menos de 1.2 m se salta
  con un clip `avoid` del banco (por velocidad de entrada y espejo por lado), a través del árbitro.
- **Caídas y trastabillones dirigidos** (`PlayerActions._directed_pick`, `push_dir_local`, `PUSH_WEIGHT`,
  `DIRECTED_MIN_COS`, `DIRECTED_IN_PLACE`, `LATERAL_CLEAR`): en el modo 4 la caída (y el trastabillón de `stumble_root`) se
  elige por el recorrido de su raíz frente a la inercia del cuerpo más el empujón del contacto: golpeado de frente y parado
  cae hacia atrás o en el sitio, por detrás a la carrera cae hacia adelante, de costado se desvía al lado contrario al
  rival. Antes era un clip al azar. Junto a una línea se descartan las caídas y esquives cuyo recorrido terminaría fuera
  de la cancha (`_lands_inside`, `LAND_MARGIN` 0.5 m; sin el filtro, 17 de 40 caídas elegidas junto a la banda terminaban
  fuera). *test_falls_direction (eliminada en la reforma)* (5).
- **Recepción**: penalización `JsonReceive.UNVERIFIED_PENALTY` a perfiles sin verificar; franjas de altura medidas
  (muslo 0.78-0.98 m, pecho desde 1.10 m) en *test_receive (eliminada en la reforma)*.

## Joystick suelto: el jugador va a la pelota (2026-11-05)

Video del usuario (05-11 04:42:20), fotograma a fotograma: parado o caminando con el joystick suelto, la pelota que
quedaba al costado o detras se iba acercando sola al frente del jugador, sin ningun toque visible («la pelota se acomoda
al jugador en vez del jugador a la pelota»). La prueba nueva `physical_dribble::released_stick` lo reprodujo con el codigo
anterior: en los cuatro casos (al costado quieta, al costado rodando hacia afuera, detras rodando hacia atras, delante
rodando despacio) **el jugador se movio 0.00 m** y la pelota termino a 0.38 m delante del cuerpo con toques sin pie (pie a
0.33-0.41 m del centro de la pelota o ninguno). Causa: con el joystick suelto el toque de parada (`settle`) aceptaba la
pelota hasta 0.62 m al costado y 0.35 m detras, se daba sin pie a los 0.06 s y la mandaba delante del cuerpo.

Ahora (`BallHandler`):

- `settle_steer` → `_settle_close`: con la pelota al alcance pero fuera de la zona comoda delante (`SETTLE_COMFY_*`) o
  rodando (`SETTLE_STILL_SPEED`), el jugador **se gira hacia la pelota y da los pasos** que faltan para dejarla a
  `settle_gap` delante (pasos cortos, `SETTLE_STEP_SPEED`), mirandola (`face_override`); pegada al cuerpo (a la espalda o
  al costado) **gira en el sitio** en vez de caminar encima. Quieta entre los pies delante (`SETTLE_UNDER`) ya esta
  controlada. Con histeresis (no tiembla en el borde de la zona). Mientras tanto no lo mueve `follow_steer` ni el control
  lateral (`Footballer`: `settling_close`). Con un rival encima manda la proteccion de siempre.
- El toque de parada solo se da con un pie que llega de verdad: zona del pie delante (`SETTLE_ZONE_BACK` −0.05 m,
  `SETTLE_ZONE_LAT` 0.40 m), radio del pie `FOOT_CONTACT × SETTLE_STRIKE_SCALE` (1.15; antes 1.4) y sin toque sin pie salvo
  que el cuerpo se le venga encima. El toque **deja la pelota quieta** donde la para (parado) o donde se detendra el
  cuerpo (caminando o corriendo): antes la mandaba con velocidad hacia delante y el jugador la perseguia toque tras toque.
- Resultado (render, modo 4): 0 toques sin pie en los cuatro casos; el jugador gira 59-110° o camina 0.25-0.47 m hasta
  ella y la pelota queda quieta delante en 0.08-0.62 s. Imágenes antes/después (pelota al costado y detrás):
  `docs/fases/joystick_suelto_antes_despues.jpg` (herramienta `tools/settle_view.tscn`).
- Con un golpeo pedido o cargándose (o un botón de golpeo apretado en ese paso, `kick_button_now`) el acomodo no actúa:
  manda la preparación del golpeo (ajuste de zancada, ir a por la pelota, giro para golpear).
- **Solo el jugador de la persona** (`owner.is_human_controlled`): el acomodo y las reglas nuevas del toque de parada
  (zona del pie delante, radio 1.15, sin toque sin pie, pelota quieta). La IA conserva el toque de parada de antes (en el
  instante en que su joystick queda suelto, tras recibir o al llegar a su sitio, la pelota todavía se coloca delante sin
  pie). Se acotó así mientras fallaban pruebas de partidos de IA en GitHub Actions #46-#48; después se midió que esas
  pruebas fallan igual con el código anterior (ver TESTING), así que el acote es prudencia, no la causa probada.
  Pendiente: darle a la IA una orden en ese instante y quitarle también el imán.
- Lo que no cambio: con el joystick, la conduccion (`carry`, `redirect`, `lateral`), la frenada desde carrera con los clips
  `ball_stop` del banco (2.6-4.6 m/s), la pisada con REGATE + atras y los giros con pelota.

## Ciclo de vida del manejo de pelota y transiciones con pelota muerta (2026-11-07)

- **Ciclo de referencias (fuga de ObjectDB).** `BallHandler` y sus submódulos `DragBack`, `BallTurn`, `JsonBallMove` y
  `JsonReceive` son `RefCounted` y se apuntan mutuamente (`handler`). Sin romper el ciclo, cada futbolista liberado dejaba
  vivos los cinco objetos y su `RandomNumberGenerator` hasta el cierre («ObjectDB instances were leaked», «resources still in
  use at exit»). `Footballer._notification(NOTIFICATION_PREDELETE)` llama a `BallHandler.dispose()`, que suelta los
  submódulos. No cambia el juego mientras el jugador existe. Prueba: `test_resource_cleanup`.
- **Transiciones con pelota muerta.** `PlayerActions._keeps_set_piece_clear` (desde `transition_score`): con
  `ctx.dead_ball`, la raíz de una transición de locomoción no puede llevar a un jugador que no es el ejecutor dentro de
  `SetPiece.CLEAR_RADIUS` (equipo que saca) o `MatchScene.SET_PIECE_DISTANCE` (rival; 2 m en saque de banda). La IA ya
  rodeaba esa zona (`AIInput._around_ball`), pero la raíz del clip va recta: medido, `jn_start_0468` llevaba a un rival a
  3,79 m de un tiro libre en 4 de 30 repeticiones. Se recorre toda la `root_path`; si ya está dentro, solo se permite lo
  que no lo acerca. Prueba: `test_transition_connections::test_dead_ball_transition_never_carries_a_player_into_the_set_piece_zone`.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Control asistido» (locomoción y conducción), «Esqueleto único v1.0» (patada sincronizada).

## Pies animados, entrada y transiciones (2026-10-27)

- **Conducción con el pie real:** `BallHandler._sample_feet` lee las puntas de los pies del esqueleto animado; con el esqueleto vivo (`feet_live`, nunca en headless) un toque solo ocurre si una punta baja está a `FOOT_CONTACT` (0.28 m) de la pelota y yendo hacia delante (`_foot_strike`), y la pelota se deja a `_foot_reach + FOOT_BALL_LEAD` (alcance real de la zancada). Si la pelota se escapa junto al cuerpo o el cuerpo la alcanza, se toca igual tras una espera corta. El primer toque espera a que la pelota llegue al pie o al cuerpo (~0.5 m). Medido con render en *test_live_feet (eliminada en la reforma)*.
- **Entrada con botón** (`PlayerActions.tackle_request`): de pie, carga con el hombro (`shoulder_charge`, pierde `Jogging_Stumble`), barrida forzada o entrada al aire. La persona no roba por mantener PRESIÓN; la IA sí disputa sola.
- **Caídas:** a sprint `Sprint_To_Backslide` (o su versión en el sitio sin espacio), `fallen_idle` antes de levantarse.
- **Transiciones** (`Footballer._gait_overlays`): `Idle_To_Sprint`, `Sprint_Turn`, parada agotado con `Running_Tired`. Bloqueo con `Defender_2`.
- **Recepción asistida:** con el joystick suelto el jugador de la persona sale al punto de encuentro del pase (`pass_meet_point`).

## Patadas sincronizadas, pie de apoyo y conducción en giros (2026-10-27, segunda ronda)

Diagnóstico con el esqueleto animado (render) y el video del usuario `prueba01` (8.0–9.9 s: con TIRO cargando, el
jugador gira hacia el arco y la pelota sigue sola hasta la banda).

- **Golpe en el instante del contacto** (`BallHandler.clip_timing`): la latencia se cuantiza a pasos de física y el
  inicio del clip se ajusta para que la pose de contacto caiga exactamente en el paso del impulso. El AnimationTree
  avanza en `_process` (después de la física): la imagen que se dibuja con el impulso es la del contacto (punta del pie
  a 0.05 m de la pelota); la anterior tiene el pie aún armado (~0.28 m). Una prueba que lea la pose dentro del paso del
  impulso ve la imagen anterior.
- **Pie de apoyo plantado** (`KICK_PLANT_TIME`, `clip_plant_velocity`, `kick_body_velocity`): en los 0.10 s previos al
  contacto el cuerpo se mueve a la velocidad que deja quieto el pie de apoyo del clip (los clips en el sitio mueven ese
  pie hacia atrás a la velocidad de carrera que representan). Desliz medido: 0.4–1.3 m/s (antes 1.4–7.4 m/s).
- **Compromiso durante el balanceo** (`Footballer._physics_process`, `kick_desired_dir`): el joystick no gira ni acelera
  al jugador mientras patea; el ajuste de paso se corrige en lazo cerrado (`_steer_clip_kick`) hasta plantar el pie.
  El plan solo acepta el ajuste que cabe antes de plantar el pie (`kick_adjust_capacity`: `KICK_NUDGE_MAX` +
  `KICK_NUDGE_PER_MS` × velocidad, durante latencia − `KICK_PLANT_TIME`); a sprint, sin esto, 7 de 8 pases fallaban el
  golpe (ajuste pedido 0.53 m, posible 0.32 m). Al terminar la patada el cuerpo recupera la velocidad que traía.
- **Clip según la velocidad del jugador** (`PLANT_MISMATCH_COST`, `PLANT_SPEED_GAIN_MAX`): se prefieren los clips cuya
  velocidad de apoyo encaja con la del jugador (parado: `Soccer_Pass`; corriendo: `strike_foward_jog_inplace`) y la
  velocidad de apoyo no supera la del cuerpo en más de 1.5 m/s (un jugador parado no sale disparado).
- **Golpeo de primera** (`is_waiting_first_time`, `PENDING_FIRST_TIME_MAX`): con la pelota viniendo hacia el jugador
  la orden espera hasta 1.4 s y el jugador va a la trayectoria (`incoming_ball_point`) sin controlarla antes.
- **Recuperar la pelota en un giro** (`carry_steer`): si la pelota propia queda fuera del alcance del toque y no está
  delante del rumbo pedido, el jugador va a un punto detrás de ella; el toque usa el rumbo del joystick. **Media vuelta**
  (`REVERSAL_TOUCH_GAP`): con más de 100° de giro el toque de arrastre no espera la cadencia de la carrera.
- **Curvas:** el toque coloca la pelota sobre el arco que va a recorrer el cuerpo (giro anticipado), no en la tangente.
- **Arrancada** (`ACCEL_TOUCH_PER_FRACTION`, `ACCEL_TOUCH_MAX`): con SPRINT, en línea recta y lejos de la punta, el
  toque se alarga hasta 0.3 m × (1 − control) (pelota a ~1.0 m con control medio); a velocidad punta vuelve el control
  cercano. En giros no se aplica (alargarlo en el giro perdía la pelota: 6 de 20 giros a sprint).
- **Pelota apoyada en el cuerpo** (`_shrug_resting_ball`, `RESTING_BALL_SECONDS`): si la pelota queda quieta sobre la
  cabeza / hombros (encajada entre dos jugadores pegados), el jugador se la quita con un toque. Hallado en un partido de
  10 min: 436.8 s trabada a 1.6 m de altura (nadie podía tocarla con el pie).
- **`has_possession()`**: pelota al pie Y no es de otro (`MatchContext.possessor`). Exigir ser ya el poseedor arbitrado
  cortaba la conducción en zigzag (8 de 16 toques con el pie frente a 18 de 21).

Medido con render (*test_live_feet (eliminada en la reforma)*, `test_live_kicks`): curva 100 % con la pelota cerca (antes 83 %), medias vueltas
100 % (antes 44 %), zigzag 18/21 toques con el pie; batería de 50 golpeos variados: 49 con contacto (punta del pie a
≤0.30 m en la imagen del golpe), 1 cancelado porque el rival tocó antes, 0 impulsos sin contacto, 0 jugadores bloqueados.

## Conducción tras el video `videofutbol` (2026-10-27, tercera ronda)

Fallos vistos fotograma a fotograma (con el joystick recortado en cada imagen) y su corrección:

- **Soltar el joystick y la pelota se iba sola (10.2 s del video)** → `BallHandler.settle_steer`: con el joystick
  suelto y la pelota propia fuera del alcance del pie, el jugador la acompaña; al alcance, frena y el toque de parada
  (que ya no espera a la zancada) la deja al pie. Medido con render: desde paso lento, trote, carrera y sprint queda
  parado con la pelota a 0.29–0.65 m en 0.55–1.18 s; una pelota que sale rodando a 1.6 m/s se para en 0.65–0.9 s.
- **Girar sin avanzar (67–70 s)** → `BallHandler.carry_turn_scale`: despacio, el cuerpo giraba 180° en <0.3 s y dejaba
  la pelota a la espalda; ahora gira a `BALL_TURN_SCALE` hasta que el toque de giro la lleva al rumbo nuevo. Media
  vuelta: toque por el costado del cuerpo y sin chocar con él (`REVERSAL_GHOST_SECONDS`); a sprint antes se perdía a
  6.5 m, ahora la conserva (separación máxima 1.1 m).
- **El cuerpo frenaba su propia pelota** (curvas) → mientras conduce, la cápsula del jugador no choca con la pelota que
  lleva (`DRIBBLE_GHOST_RANGE`; los demás jugadores sí). Curva continua de 10 s: antes pelota cerca 73 % y atrás 34 %,
  ahora 100 % y 0 %.
- **Desplazamiento lateral con el joystick a medias (45 s)** → `PlayerTuning.lateral_max_stick` 0.75 → 0.5.
- **Contacto con todo el pie** (`foot_distance`, tobillo–punta) en vez de solo la punta.
- **Reloj de simulación, no del sistema:** «no tocar ni perseguir el propio envío» (`OWN_KICK_SECONDS` 0.7 s) y «no
  controlar la pelota que acabo de tocar» (450 ms) se medían con `Time.get_ticks_msec()`, así que la regla cambiaba con
  la velocidad de la simulación (la suite lo detectó: tras un pase con el joystick suelto, `settle_steer` perseguía el
  propio pase a 0.96 m/s). Ahora cuentan pasos de física (`seconds_since_kick`, `Ball.last_touch_frame`) y
  `settle_steer` no persigue el propio pase. Medido: la prueba con render simula a ~2× tiempo real (602 pasos en
  5.0 s), de modo que los 450 ms equivalían a 54 pasos (0.9 s de juego) en las pruebas y a 27 en el móvil; con 0.45 s
  de simulación la curva bajaba a 10 de 18 toques con el pie. Se fija `OWN_TOUCH_NO_CONTROL_SECONDS` = 0.9 s, el valor
  con el que se midió la conducción (curva 11/18, zigzag 10/14, igual que antes).
- Limitación medida: en curvas cerradas continuas el 39 % de los toques son de rescate (ningún pie llega a tiempo);
  exigir un pie cerca para el rescate rompía el frenado y los giros (probado y revertido).

## Golpeo pedido con la pelota fuera del alcance y medición de la conducción (2026-10-27, cuarta ronda)

Diagnóstico completo con los videos A/B y el inventario medido: [DRIBBLE_DIAGNOSIS](../DRIBBLE_DIAGNOSIS.md).

- **Ajuste de la carrera para golpear** (`BallHandler.kick_approach_steer`, `is_approaching_for_kick`,
  `PENDING_APPROACH_MAX` 1.4 s, `APPROACH_MAX_DIST` 4 m, `APPROACH_MIN_CLOSING` 0.3 m/s): con un pase/tiro cargándose o
  pedido y la pelota **propia** por delante fuera del alcance del pie, el cuerpo corre hacia ella (sin el tope de
  velocidad de conducción, `Footballer`); la orden espera mientras se acerca y, si no llega, se cancela con
  `KICK_WHIFF out_of_reach`. Yendo a golpear no hay toques de preparación sin pie. Mientras se carga **en carrera** el toque
  es de preparación (`_touch_mode` → `setup`); parado y cargando no se toca la pelota. Antes: tiro a 3.6–4.2 m/s con la
  pelota a 1.7–2.6 m → sin golpeo (video A, 58.4 s); ahora 7/7 golpeos con el pie a 0.02–0.17 m (`test_kick_reach`).
- **Diagnóstico por toque:** `BallHandler.last_touch_foot` (0 izq., 1 der., −1 sin pie cerca) — lo usan
  *test_dribble_reference (eliminada en la reforma)* y la demo grabable `tools/dribble_demo/dribble_demo.tscn`.
- **Conducción sin cambios de mecánica en esta ronda:** el pack no tiene animación de carrera con toques
  (`FootTrajectory.dribble_verdict`: ningún clip cumple), así que no se tocaron distancias, cadencias ni toques.
  Medido con render frente al video B: carrera con un toque por paso alternando pies (0.27 s; B 0.60–0.66 s) y deriva
  lateral ±0.17 m; a sprint 3 de 8 toques sin pie cerca.


## Toques de clip: conducción con animación de toque e IK del pie (2026-10-28, quinta ronda)

Diagnóstico, antes/después y evidencia visual: [DRIBBLE_DIAGNOSIS](../DRIBBLE_DIAGNOSIS.md#sexta-ronda-2026-10-28-toques-de-clip-curvas-a-velocidad-e-ik-del-pie).
Con el esqueleto vivo (render) la conducción en carrera ya no es «un toque por pisada sin animación»: cada toque es una
animación de toque del pie que llega a la pelota, y el impulso solo se aplica en ese contacto.

- **Clips** (assets/animations/touch_clips.res (borrado: Mixamo/Mocap), 0 créditos, mismo esqueleto): `TouchClipBuilder` lleva la pierna del
  balanceo real de `Dribble_2`, `Running_inplace` y `Two_Cycle_Sprint_inplace` con IK de dos huesos hasta un punto de
  contacto (empeine abajo, acompañamiento 0.04 m). Un clip por **balanceo** (Dribble_2 y el sprint adelantan cada pie dos
  veces por ciclo, con cadera distinta) y variantes de alcance `_Close` / `_Near` / `_Far` (las que la pierna no alcanza
  se omiten): 33 clips. `FootballerVisual` los reproduce en una capa OneShot filtrada a la pierna, al ritmo de la marcha.
- **Disparo en fase** (`BallHandler._clip_touch_update`): `FootballerVisual.carry_phase` lee la fase real del ciclo base
  (`parameters/Carry/cN/current_position`); el toque se dispara en el paso cuya fase siguiente queda a medio proceso del
  inicio del clip (el OneShot arranca en 0 en el proceso siguiente). Sin esto se disparaba en el balanceo equivocado.
- **Plan** (`_plan_clip_touch`): recorre la punta medida del clip frente a la pelota prevista (velocidad, frenado y el
  paso de física que le falta) en los ejes del **cuerpo previsto** (`_predict_body`: misma ley de aceleración y giro que
  `Locomotion`, en curva sobre su arco, extrapolando el giro del joystick 0.3 s). Descarta: lejos, cerca, lado, alto
  (punta > 0.15 m) y atraviesa (la punta seguiría > 0.07 m tras el contacto). Elige la variante cuyo contacto queda más
  cerca de su contacto de diseño. En recta solo toca el pie del último toque (un toque por zancada, como el video B).
- **Contacto por evento** (`_clip_touch_step`): la punta viva prevista para la imagen que se dibuja (el esqueleto se lee
  un proceso tarde y **sin** los modificadores: se suma la corrección del IK) llega a la parte de atrás de la pelota; se
  toca en la imagen más cercana al contacto (a sprint la punta avanza 0.17 m por imagen). Si la ventana acaba o la punta
  pasa sin tocarla: fallo, sin impulso.
- **IK del pie en tiempo real** (`scripts/animation/touch_foot_ik.gd`, `SkeletonModifier3D` tras `ProceduralPose`):
  lleva la punta del contacto planeado al punto real de la pelota (hasta 0.06 m adelante, 0.15 m de lado en curva y
  0.05 m en recta), con peso que sube 0.12 s antes del contacto y se suelta en 0.12 s.
- **Impulso**: deja la pelota delante del cuerpo previsto (arco y rumbo de entonces) para un balanceo siguiente, con
  llegada a velocidad relativa ~0 (tiempo natural de la rodadura `T* = raíz(2·avance/a)`; en curva, el siguiente
  balanceo de cualquier pie y la pelota centrada). La pelota se integra un paso más que el cuerpo (`move_and_slide` va
  antes de `update`): se cuenta en el impulso. Apunta al contacto de la variante `_Near` (centro del rango que recogen).
- **Relevo desde la conducción por pisadas**: sus toques rectos con toques de clip a esa velocidad usan la misma llegada
  (pelota en `clip_touch_gap`, velocidad relativa ~0); antes la dejaban a 0.7–0.85 m con velocidad de más y no había
  toque de clip en segundos.
- **Curvas a velocidad** (`_curve_turn_scale` desde `carry_turn_scale`): el cuerpo no se adelanta más de 8° al rumbo de
  la pelota (ni la deja más de 12° hacia el exterior) hasta que el siguiente toque la lleva al rumbo nuevo. Antes el
  cuerpo giraba hasta 360°/s, completaba un cambio de 30° en 0.2 s y la pelota quedaba a 0.8 m al costado.
- `dribble_speed_cap()` reúne el tope de velocidad con la pelota al pie (lo usan `Footballer` y la predicción).
- **Quién manda en cada momento** (versión final):
  - **Arrancada** (`_launching`: SPRINT pedido a más de `ACCEL_TOUCH_KEEP_FRACTION` 0.2 de la velocidad punta): los
    toques largos de arrancada de siempre (`ACCEL_TOUCH_MAX` 0.3 m de colocación), sin toques de clip ni relevo hacia
    ellos. Con 0.6 m la pelota se escapaba en la arrancada.
  - **Giro brusco** (joystick a más de `TOUCH_MAX_TURN` 50° del cuerpo): la conducción de giro; el toque de clip pendiente
    se cancela. Con 80° los toques de clip entraban en giros que no pueden seguir.
  - **Recta**: un toque de clip por zancada con **el mismo pie** (como el video B).
  - **Curva** (rumbo pedido a más de `TOUCH_CURVE_DEG` 8° o giro de más de `TOUCH_CURVE_RATE` 0.25 rad/s, y
    `TOUCH_CURVE_HOLD` 0.5 s después): pelota centrada, toca el siguiente balanceo de cualquier pie; a más de
    `TOUCH_SHARP_DEG` 25° apunta a la variante `_Close` (pelota más cerca del cuerpo).
  - El **freno de giro en curva** solo actúa después de un toque de clip (antes interfería con los rescates de la
    conducción de giro en el zigzag) y la regla del pie (`foot_gap`) solo en recta (giro < 25°).
- Pruebas ajustadas: *test_live_feet (eliminada en la reforma)* mide el zigzag en 4 pasadas (al menos la mitad de los toques con un pie y la pelota
  conservada más del 90 %; una pasada sola variaba entre 7 y 9 de 12 por la semilla) y la arrancada admite que la pelota
  se adelante hasta 0.75 m (con los toques largos de arrancada se mide 0.73 m; la pelota sigue al alcance). Las demás
  comprobaciones no cambiaron.

Medido con render (*test_dribble_reference (eliminada en la reforma)*, versión final; curvas con 5 semillas del error del toque,
`DRIBBLE_SEEDS=5`; «antes» de las curvas: una pasada con los toques de clip en recta ya integrados, sin el trabajo de
curvas):

| Caso | Antes de esta ronda | Ahora |
|---|---|---|
| Recta al trote 2.8 m/s | toque por pisada sin animación | 9 toques, todos de clip, cada 0.68 s (B 0.63), pelota 0.48 m, deriva ±0.01 |
| Recta a la carrera 5.3 m/s | un toque por paso alternando pies (0.27 s), deriva ±0.17 | 11 toques con el mismo pie cada 0.55 s, pelota 0.57 m (B 0.66), deriva ±0.01 |
| Recta a sprint 6.0 m/s | 3 de 8 toques sin pie cerca | 12 toques (8 de clip), cada 0.45 s, pelota 0.65 m (B 0.66), 0 sin pie |
| Cambios de ritmo trote → carrera → sprint | — | 12 toques (10 de clip), pelota 0.59 m, deriva ±0.07 |
| Arrancada paso → sprint | — | 8 toques (6 de clip), pelota 0.60 m, 0 sin pie |
| Arco a la carrera (15°/s) | pelota al costado p95 0.64 m, 3 sin pie | p95 0.09 m (peor 0.10), 0 sin pie |
| Cambio de carril 30° a la carrera | p95 0.76 m | p95 0.13 m (peor 0.14), 0 sin pie |
| Eslalon ±25° a la carrera | p95 0.49 m, 2 sin pie | p95 0.33 m (peor 0.34), 1.2 sin pie |
| Eslalon ±20° a sprint | p95 0.74 m, 5 sin pie | p95 0.38 m (peor 0.50), 1.6 sin pie |
| Zigzag ±37° cada 0.83 s | — | p95 0.63 m (peor 0.76), 1.6 de clip y 6.4 sin pie de 9.8, pelota cerca 92 % |

La punta no entra en la pelota tras el toque de clip (máximo medido 0.000 m en todos los casos rectos). Limitación: el
zigzag cerrado sigue en manos de la conducción de giro (sus toques son rescates sin animación de toque) y en los eslalon
queda algún rescate sin pie cuando el joystick se invierte entre dos toques.

## Vuelta atrás pisando la pelota, giros y rodadura tipo FTS (2026-10-28, octava ronda)

Origen y comparación con First Touch Soccer 27: [DRIBBLE_DIAGNOSIS](../DRIBBLE_DIAGNOSIS.md#octava-ronda-2026-10-28-first-touch-soccer-27-apk-y-videos-diferenciasfutbol).
La rodadura nueva (proporcional a la velocidad, [BALL](BALL.md#rodadura-tipo-first-touch-soccer-2026-10-28)) cambia la
conducción: cada toque sale disparado, frena y espera al jugador. Todo lo que planifica con la pelota usa las mismas
fórmulas (`Ball.roll_*`): impulso de cada toque (`roll_speed_for`), plan del toque de clip (`roll_distance`), relevo y
llegada (`roll_catch_time`), golpeo sobre la pelota en movimiento (`BallHandler.ball_travel`) y la pelota que llega
para un golpeo de primera (`incoming_ball_eta`, `incoming_ball_point`). Antes los dos últimos suponían velocidad
constante: con la rodadura nueva el pase de primera no encontraba la pelota (`out_of_reach`).

### Pelota suelta: el jugador de la persona va a buscarla (2026-10-29)

prueba03: «el jugador siempre va al balón, el que está siendo controlado». Sin la pelota y sin pulsar PRESIÓN, si hay una
pelota suelta (nadie la lleva; `MatchContext.ball_is_loose`) que no es un pase a un compañero, ni va a más de
`LOOSE_CHASE_MAX_BALL_SPEED` 9 m/s, ni más alta que `LOOSE_CHASE_MAX_Y` 1.6 m, ni es balón parado ni la propia
conducción, `BallHandler.loose_ball_chase` busca el primer punto de su recorrido (rodadura de `Ball`) al que el jugador
llega corriendo; si está a ≤ `LOOSE_CHASE_RANGE` 9 m, `Footballer`:

- con el joystick suelto (< 0.2), corre solo a ese punto (más rápido cuanto más lejos; sprint a más de 4 m);
- con el joystick a menos de `LOOSE_SNAP_DEG` 40° de ese punto, ajusta el rumbo al punto (no se pasa ni llega tarde);
- apuntando a otro lado, manda el joystick. Solo el jugador de la persona (la IA decide sola). Medido
  (*tests/test_loose_ball_chase.gd (eliminada en la reforma; en el historial de git)*): pelota cruzada a 5 m, controlada a los 1.22 s sin tocar el joystick y a los
  1.30 s con el joystick hacia donde estaba la pelota.

### Giro con toques (`BallTurn`, 2026-10-29)

prueba03: «volver hacia atrás no me gusta… fíjate los giros en Dream League: gira para volver hacia atrás mientras da
toques al balón». Conduciendo, con el joystick hacia atrás o muy cruzado (≥ `MIN_ANGLE` 115° del frente, ≥ `MIN_STICK`
0.35) y la pelota propia delante (−0.05 a 1.4 m, ±0.6 m de costado), en los primeros `REQUEST_WINDOW` 0.15 s de
pedirlo y hasta `MAX_SPEED` 7.2 m/s (también a sprint):

1. **Llega** (`REACH`): el pie sale hacia la pelota (`FIRST_TOUCH_DELAY` 0.1 s, IK) y el cuerpo empieza a frenar a su
   ritmo; si la pelota quedó adelantada va a buscarla (hasta 0.8 m/s más rápido, sin pasar el sprint). El primer toque
   llega con la pelota a `REACH_AHEAD` 0.5 m + 0.08 m por m/s (hasta 0.95 m: zancada estirada a la carrera) del cuerpo;
   solo empieza si, simulando la llegada (`DragBack.reachable`), la alcanza en `REACH_MAX` 0.4 s.
2. **Gira** (`TURN`): el cuerpo frena (`BRAKE` 13 m/s²) hasta `TURN_SPEED` 1.35 m/s y rota hacia el rumbo nuevo por el
   lado pedido a `TURN_RATE` 210°/s (por la agilidad), más despacio cuanto más rápido va (`LATERAL_ACCEL` 10 m/s² /
   velocidad: primero frena, después rodea). Cada `TOUCH_INTERVAL` 0.28 s (con la pelota a ≤ `TOUCH_REACH` 0.8 m por
   delante) un toque con el interior del pie de fuera del giro manda la pelota adonde estará el pie en el toque
   siguiente: el cuerpo se predice con el mismo mando (`predict_body`) y la pelota queda `TOUCH_LEAD` 0.42 m por delante,
   con la rodadura de `Ball.roll_speed_for` (≤ 4 m/s). El tronco se encorva `CROUCH` 0.1 rad más
   (`FootballerVisual.turn_crouch`) y el pie que toca sube hacia la pelota antes de cada toque y baja después (IK).
3. **Sale**: mirando a menos de `EXIT_ANGLE` 28° del rumbo nuevo, un toque deja la pelota `EXIT_LEAD` 0.62 m delante
   del cuerpo que acelera a la velocidad pedida a los `EXIT_TIME` 0.42 s, y sigue la conducción normal.

El joystick puede corregir el rumbo durante el giro (hacia el mismo lado). Si la pelota se aleja más de `LOST_DIST`
1.25 m, la toca otro, se golpea o pasa `MAX_TIME` 1.8 s, el giro se suelta. Lo usan la persona y la IA (lo dispara el
rumbo pedido). Medido (*tests/test_ball_turn.gd (eliminada en la reforma; en el historial de git)*, giro de 180°; con render el pie queda a 0.05–0.14 m de la superficie
de la pelota en cada toque):

| Caso | Toques | Mira al rumbo nuevo | Giro completo | Sigue de largo | Separación máxima |
|---|---|---|---|---|---|
| Caminando (2.1 m/s) | 4 | 0.82 s | 0.87 s | 0.59 m | 0.84 m |
| Trote (3.6 m/s) | 4 | 0.80 s | 0.87 s | 0.89 m | 0.84 m |
| Carrera (5.3 m/s), 6 momentos del ciclo | 4 | 0.82–0.88 s | 0.87–0.90 s | 1.10–1.71 m | ≤ 1.07 m |
| Trote, giro de 135° | 3 | 0.60 s | 0.60 s | 0.47 m | 0.83 m |
| Sprint (6.4 m/s) | 4 | 0.88 s | 0.90 s | 1.81 m | 0.85 m |

### Vuelta atrás pisando la pelota (`DragBack`)

Es un **regate**: botón REGATE con el joystick hacia atrás (`Footballer._skill_is_drag_back` → `DragBack.request`, que
la deja pedida `REQUEST_HOLD` 0.3 s); sin el botón, el joystick atrás hace el giro con toques. REGATE sin joystick
atrás sigue siendo la ruleta. Con la pelota delante y el joystick hacia atrás (≥ `MIN_ANGLE` 135° del frente,
≥ `MIN_STICK` 0.45), a menos de `MAX_SPEED` 5.6 m/s **al pedirla** y solo en los primeros `REQUEST_WINDOW` 0.12 s de
pedirla. Manda sobre un giro con toques que aún no tocó la pelota (lo cancela); con la pelota escapada (no la alcanza)
hace el giro con toques:

1. **Llega** (`REACH`): sin girar, derecho a la pelota y hasta 0.8 m/s más rápido que ella si hace falta. Solo empieza
   si, simulando la llegada paso a paso (`_reachable`), la suela la alcanza en `REACH_MAX` 0.3 s; si la pelota se escapa
   (el último toque la lanzó) no hay vuelta y manda la media vuelta de siempre (ir tras ella para pisarla costaba ~0.9 s
   y ~4 m de más a la carrera).
2. **Pisa** (`HOLD`): la suela llega a la pelota a `SOLE_AHEAD` 0.36 m + 0.03 m por m/s (hasta 0.5 m) del cuerpo; el
   cuerpo se planta (`PLANT_BRAKE` 20 m/s²) y la suela frena la pelota con él: un impulso por paso que iguala la velocidad
   de la suela (un contacto, la pelota no se mueve de donde está; solo el primero cuenta como toque, con su evento).
3. **Arrastra** (`PULL`): con el cuerpo casi quieto (< 0.9 m/s) o a los `HOLD_MAX` 0.26 s, la suela tira la pelota hacia
   el rumbo nuevo, 0.1 m hacia el lado del pie (pasa junto al pie de apoyo), con la velocidad que la deja `PULL_LEAD`
   0.55 m delante del cuerpo a los `PULL_TIME` 0.6 s (pivote incluido).
4. **Pivota**: 180° hacia el lado del pie que arrastró (`Locomotion.step_scripted`, `TURN_RATE` 780°/s por la agilidad;
   pisa el pie del lado hacia el que se gira) y sale a 1.6 m/s; con el cuerpo mirando al rumbo nuevo sigue la conducción.

Visual: `TouchFootIK.set_target` lleva la punta del pie a lo alto de la pelota (sin el límite de 0.16 m de las
correcciones) mientras llega, pisa y acompaña el tirón, y la suelta en 0.16 s. Lo usan la persona y la IA (con el mismo
botón). Medido (*tests/test_drag_back.gd (eliminada en la reforma; en el historial de git)*; con render la suela queda a 0.04 m de lo alto de la pelota):

| Caso | Pisa a | Mira al rumbo nuevo | Sigue de largo | Separación máxima |
|---|---|---|---|---|
| Caminando (2.1 m/s) | 0.41 m, a los 0.02 s | 0.30 s | 0.10 m | 0.65 m |
| Trote (3.6 m/s) | 0.49 m, a los 0.23 s | 0.62 s | 1.42 m | 0.65 m |
| Carrera (5.3 m/s), 6 momentos del ciclo | 4 con pisada (mira al rumbo nuevo a 0.45–0.78 s) y 2 con el giro con toques (0.88 s) | | 0.75–2.58 m | ≤ 1.07 m |
| Sprint (6.4 m/s) | sin pisada: giro con toques | | | 0.81 m |

(2026-10-29, con REGATE + joystick atrás y render; caminando y al trote, igual que cuando la disparaba el joystick solo.)

### Giros con la pelota que se escapa

Tras un toque a la carrera la pelota sale más rápido que el cuerpo. Si en ese momento se pide un giro cerrado, el cuerpo
giraba y frenaba (castigo de giro de `Locomotion`) y la pelota se iba: a 135° a la carrera el jugador la perseguía 0.8 s
y avanzaba −3.2 m en 1.5 s; a 90° a sprint, 0.8 m con la pelota a 1.9 m. Ahora `carry_steer` también persigue la pelota
**al alcance** si se aleja del cuerpo a más de `ESCAPE_STEER_SPEED` 0.8 m/s: derecho a un punto detrás de ella respecto
al rumbo pedido, y el toque de giro la lleva hacia allí en cuanto el pie llega. Medido con render (*test_live_feet (eliminada en la reforma)*):
135° a la carrera +2.78 m (separación 0.62 m), 90° a sprint +5.47 m (0.85 m).

### Parar: amortiguar para que la pelota quede quieta junto al pie

Al soltar el joystick corriendo, el toque de parada (modo `settle`) dejaba la pelota en un punto al que llegaba
**rodando** y seguía de largo: con la rodadura nueva quedaba quieta a 0.90 m del cuerpo al trote. Ahora el toque la
amortigua para que se **detenga** en el punto donde se va a parar el cuerpo más `settle_gap` (`Ball.roll_speed_to_stop`,
en `_try_dribble_touch`); si la pelota ya lo pasó, la frena. (Hacer que el jugador camine
hasta una pelota quieta se probó y se descartó: también iba a por la pelota que quedaba detrás y golpeaba sin alcance,
test_reach_is_limited_by_the_leg_not_a_fixed_radius (borrado: Mixamo/Mocap).)

### Control cerrado (menos de 3.2 m/s)

Por debajo de `CLOSE_CONTROL_SPEED` 3.2 m/s pedidos (sin sprint) los toques de clip son de control cerrado: cualquier
pie, pelota centrada y variante `_Close` (como en las curvas, `_tight()`), y el tronco se encorva sobre la pelota
(`FootballerVisual.CARRY_CROUCH`, ver [ANIMATIONS](ANIMATIONS.md)).

### Pelota encajada a la altura de la cadera

En un partido de 5 minutos de IA contra IA la pelota quedó 169 s quieta a 0.73 m del suelo, encajada entre dos rivales
que empujaban uno contra otro: nadie la podía tocar con el pie (la posesión exige < 0.6 m) y la regla de la pelota
apoyada en el cuerpo (`_shrug_resting_ball`) solo actuaba desde 0.9 m (cabeza y hombros). Ahora actúa desde
`RESTING_BALL_MIN_Y` 0.45 m: el jugador se la quita con el muslo, algo hacia arriba y, si está encajada entre dos
cuerpos (`_body_partner`), **de lado** respecto a la línea entre ellos (hacia el otro rebotaba y volvía: 7.3 s en otro
partido). Medido en 13 partidos de 5 minutos con semillas distintas: pelota quieta como mucho 0.7–3.2 s.

## Golpeo de primera: el impulso sale cuando la pelota llega al pie animado (2026-11-06)

En el instante de contacto del clip, una pelota que llega rápido (pase o tiro de primera) todavía estaba lejos del pie. La
batería de golpeos (`test_live_kicks`) midió la punta del pie a 0.26-0.27 m del centro de la pelota en la imagen del
impulso, a 5-6 m/s: el pie golpeaba el aire.

`BallHandler._ball_still_arriving` corrige esto cuando la **pelota** va hacia el pie a más de 2 m/s:

- Espera paso a paso, como mucho 0.1 s, mientras baja la distancia entre la pelota y la punta del pie del cuadro que se
  dibuja. Esa punta es la leída ahora más su avance de un paso, porque el `AnimationTree` avanza después de la física.
- Al dejar de bajar la distancia, el impulso sale.
- La pelota no se toca ni se mueve: solo se elige el paso del impulso.

Medido (punta al centro, imagen del golpe): pase de primera a 5 m/s 0.264 → 0.172 m, a 6 m/s 0.268 → 0.162 m. El resto
de las 50 acciones no cambió (50/50 con contacto, 0 inválidos, 0 bloqueos).



## Continuación de integración (2026-11-07)

Se conectan variantes de marcha, transiciones sin posesión y reacción a colisión de balón en la cara. Carry comparte puntos y cadencias del catálogo JSON. Frenado radial de BallTurn evita atravesar la pelota; predictor usa el mismo cálculo. Evidencia y limitaciones: [continuación](../../integration/continuacion/README.md).
