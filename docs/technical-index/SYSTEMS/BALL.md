# BALL — Pelota

## Identificación

- **Responsabilidad exacta:** física independiente de la pelota (`RigidBody3D` con Jolt): gravedad, masa, rebote, fricción, rodadura, resistencia del aire cuadrática, efecto Magnus, amortiguación en la red, límites de velocidad, golpes por **impulso**, retención por el arquero (`hold`/`release`) y teletransporte controlado (saques).
- **Principio de diseño:** la pelota nunca se coloca en el pie ni se anula su velocidad para simular control; los jugadores solo la cambian con `Ball.kick`/`Ball.push` en el instante del contacto.
- **Estado:** implementado.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-11
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos / nodos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/ball/ball.gd` | Clase `Ball` (`RigidBody3D`): construcción, física por paso, API de golpes | `Ball.apply_tuning`, `Ball._integrate_forces`, `Ball.kick`, `Ball.rolling_spin`, `Ball.reset_at`, `Ball.hold`, `Ball.set_knuckle`, `Ball._on_body_entered` | `Tuning.ball`, `BallState` |
| `scripts/ball/ball_tuning.gd` | Recurso `BallTuning` con todos los parámetros de la pelota, pase y tiro | ver «Mapa de parámetros» | — |
| `scenes/ball/ball.tscn` | Nodo raíz `Ball` (`RigidBody3D`) con el script; la colisión (`CollisionShape3D`) y la malla (`Visual`) se crean en `Ball._build` | nodo `Ball` | `scripts/ball/ball.gd` |
| `assets/ball/ball.gdshader` | Aspecto (parches sobre un icosaedro); **no** afecta a la física | uniforms `base_color`, `patch_color`, `patch_threshold` | — |
| `project.godot` | `physics/3d/physics_engine="Jolt Physics"`, `common/physics_ticks_per_second=60`, `3d/default_gravity=9.81`, `jolt_physics_3d/limits/max_angular_velocity=200.0`, nombres de capas | secciones `[physics]`, `[layer_names]` | Jolt |

**Archivos externos que alteran el rebote o el contacto (no editarlos para cambiar la pelota):**

| Archivo | Qué define | Valor actual |
|---|---|---|
| `scripts/pitch/pitch.gd` (`Pitch._build_floor`) | material del piso | `friction = 0.8`, `bounce = 0.0` |
| `scripts/pitch/pitch.gd` (`Pitch._build_walls`) | material de las paredes (`wall_pm`) | `friction = 0.4`, `bounce = 0.5` |
| `scripts/pitch/goal.gd` (`Goal._add_frame_piece`) | material de postes y travesaño | `bounce = 0.45`, `friction = 0.3` |
| `scripts/pitch/goal_net.gd` (`GoalNet`) | red de tela del arco | usa `BallTuning.net_*` y deja su aceleración en `Ball.net_accel` |

**No modificar para cambiar la física de la pelota:** `scripts/player/ball_handler.gd` (decide *cuándo* se golpea, no cómo rueda), `scripts/assistance/*` (calculan velocidades objetivo), `assets/ball/ball.gdshader` (solo visual).

## Mapa de parámetros

<!-- AUTO:params:BallTuning -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `radius` | `0.1` | float | `scripts/ball/ball_tuning.gd:8` | `scripts/ball/ball.gd:132`, `scripts/ball/ball_predictor.gd:34`, `scripts/ball/ball_predictor.gd:39`, `scripts/ball/ball_predictor.gd:40` (+16) | Radio real en metros (circunferencia ~63 cm). (Cuerpo) |
| `mass` | `0.42` | float | `scripts/ball/ball_tuning.gd:10` | `scripts/ball/ball.gd:133`, `scripts/ball/ball_predictor.gd:42`, `scripts/ball/ball_predictor.gd:57`, `scripts/assistance/kick_model.gd:68` (+1) | Masa en kg (futsal: 400-440 g). (Cuerpo) |
| `visual_scale` | `1.25` | float | `scripts/ball/ball_tuning.gd:12` | `scripts/ball/ball.gd:150`, `scripts/ball/ball.gd:151` | Escala solo visual para que se lea bien con camara alta (no afecta a la fisica). (Cuerpo) |
| `bounce` | `0.54` | 0.0, 1.0 | `scripts/ball/ball_tuning.gd:16` | `scripts/ball/ball.gd:141`, `scripts/ball/ball_predictor.gd:68`, `scripts/ball/ball_predictor.gd:71` | Coeficiente de restitucion. El balon de futsal rebota ~50-60 % de la altura de caida. (Contacto) |
| `friction` | `0.6` | 0.0, 2.0 | `scripts/ball/ball_tuning.gd:17` | `scripts/ball/ball.gd:142`, `scripts/ball/ball_predictor.gd:44` |  (Contacto) |
| `angular_damp` | `0.01` | float | `scripts/ball/ball_tuning.gd:18` | `scripts/ball/ball.gd:138` |  (Contacto) |
| `drag_coefficient` | `0.25` | float | `scripts/ball/ball_tuning.gd:22` | `scripts/ball/ball.gd:386`, `scripts/ball/ball_predictor.gd:57`, `scripts/assistance/kick_model.gd:117` | Cd del balon en el aire. (Resistencia) |
| `air_density` | `1.2` | float | `scripts/ball/ball_tuning.gd:23` | `scripts/ball/ball.gd:386`, `scripts/ball/ball_predictor.gd:57`, `scripts/assistance/kick_model.gd:117` |  (Resistencia) |
| `rolling_decel` | `0.3` | float | `scripts/ball/ball_tuning.gd:26` | `scripts/ball/ball.gd:451` | Rodadura sobre el piso: desaceleracion = rolling_decel + rolling_viscous * v. La parte constante (m/s^2) es la que detiene del todo una pelota lenta. (Resistencia) |
| `rolling_viscous` | `1.0` | float | `scripts/ball/ball_tuning.gd:31` | `scripts/ball/ball.gd:451` | Parte proporcional a la velocidad (1/s), como en First Touch Soccer: alli la pelota conserva 1006/1024 de su velocidad por imagen a 60 Hz (1.06/s; medido en su libreria, CBallProj::Iterate). Con ella cada toque de conduccion sale disparado, frena y espera al jugador (antes, con 0.55 m/s^2 constantes, la pelota rodaba a la par del jugador como atada a una cuerda), y los pases salen rapidos y se apagan. (Resistencia) |
| `rolling_viscous_knee` | `7.0` | float | `scripts/ball/ball_tuning.gd:35` | `scripts/ball/ball.gd:451` | Velocidad (m/s) por encima de la cual la parte proporcional deja de crecer (desaceleracion constante a + c vk): la conduccion (toques de hasta ~7 m/s) va como en FTS y un pase o tiro fuerte por el suelo pierde ~20 % en 15 m en vez de apagarse (con 1/s puro un tiro raso de 25 m/s llegaba a 10 m/s a 15 m). (Resistencia) |
| `spin_decel_ground` | `6.0` | float | `scripts/ball/ball_tuning.gd:37` | `scripts/ball/ball.gd:418`, `scripts/ball/ball.gd:420` | Perdida de giro sobre el piso (rad/s^2). (Resistencia) |
| `magnus_k` | `0.0018` | float | `scripts/ball/ball_tuning.gd:39` | `scripts/ball/ball.gd:392`, `scripts/ball/ball_predictor.gd:42`, `scripts/assistance/kick_model.gd:68` | Coeficiente tipo Magnus: F = k * (omega x v). (Resistencia) |
| `net_stiffness` | `1800.0` | float | `scripts/ball/ball_tuning.gd:42` | `scripts/pitch/goal_net.gd:244` | Red del arco (GoalNet): tela atada al marco que la pelota abomba. Rigidez (aceleracion por metro abombado, 1/s^2): un tiro de 27 m/s la abomba ~0.5 m y se frena en ~0.05 s. (Resistencia) |
| `net_damp_in` | `0.25` | 0.0, 2.0 | `scripts/ball/ball_tuning.gd:45` | `scripts/pitch/goal_net.gd:252` | Amortiguacion (fraccion de la critica) mientras la pelota empuja la red y mientras la red la devuelve (mayor: la tela se queda la energia y la pelota cae dentro en lugar de rebotar). (Resistencia) |
| `net_damp_out` | `1.2` | 0.0, 2.0 | `scripts/ball/ball_tuning.gd:46` | `scripts/pitch/goal_net.gd:252` |  (Resistencia) |
| `net_return` | `0.05` | 0.0, 1.0 | `scripts/ball/ball_tuning.gd:48` | `scripts/pitch/goal_net.gd:249` | Fraccion de la rigidez con la que la tela empuja de vuelta a la pelota (la red real casi no devuelve energia). (Resistencia) |
| `net_grip` | `7.0` | float | `scripts/ball/ball_tuning.gd:50` | `scripts/ball/ball.gd:430`, `scripts/pitch/goal_net.gd:266` | Frenado (1/s) del movimiento a lo largo de la tela y del giro mientras la pelota esta metida en ella. (Resistencia) |
| `net_max_bulge` | `0.6` | float | `scripts/ball/ball_tuning.gd:52` | `scripts/pitch/goal_net.gd:259`, `scripts/pitch/goal_net.gd:267`, `scripts/pitch/goal_net.gd:269` | Abombado maximo (m): a partir de ahi la tela ya no cede. (Resistencia) |
| `max_speed` | `38.0` | float | `scripts/ball/ball_tuning.gd:53` | `scripts/ball/ball.gd:433`, `scripts/ball/ball.gd:434` |  (Resistencia) |
| `max_spin` | `150.0` | float | `scripts/ball/ball_tuning.gd:54` | `scripts/ball/ball.gd:435`, `scripts/ball/ball.gd:436` |  (Resistencia) |
| `pass_speed_min` | `7.0` | float | `scripts/ball/ball_tuning.gd:58` | `scripts/assistance/cross_assist.gd:83`, `scripts/assistance/pass_assist.gd:117`, `scripts/assistance/pass_assist.gd:239` | Velocidad minima (m/s) de un pase raso a un companero (antes 4: los pases cortos se sentian flojos). (Pase) |
| `pass_speed_max` | `28.0` | float | `scripts/ball/ball_tuning.gd:59` | `scripts/assistance/cross_assist.gd:83`, `scripts/assistance/pass_assist.gd:76`, `scripts/assistance/pass_assist.gd:118`, `scripts/assistance/pass_assist.gd:239` |  (Pase) |
| `pass_arrival_speed` | `6.0` | float | `scripts/ball/ball_tuning.gd:62` | `scripts/assistance/pass_assist.gd:76`, `scripts/assistance/pass_assist.gd:113` | Velocidad a la que queremos que el pase raso llegue al receptor (antes 4.5: «los pases se sienten debiles»; en First Touch y Dream League el pase llega tenso al pie). (Pase) |
| `lob_angle_deg` | `38.0` | float | `scripts/ball/ball_tuning.gd:63` | `scripts/assistance/pass_assist.gd:105` |  (Pase) |
| `driven_pass_extra` | `1.25` | float | `scripts/ball/ball_tuning.gd:64` | `scripts/assistance/pass_assist.gd:116` |  (Pase) |
| `shot_speed_min` | `12.0` | float | `scripts/ball/ball_tuning.gd:68` | `scripts/assistance/shot_assist.gd:117`, `scripts/assistance/shot_assist.gd:119` | Tiro flojo / a carga maxima (m/s). prueba03: «shootar se siente horrible, necesita mas potencia» (antes 9 y 27). (Tiro) |
| `shot_speed_max` | `30.0` | float | `scripts/ball/ball_tuning.gd:69` | `scripts/assistance/shot_assist.gd:117`, `scripts/assistance/shot_assist.gd:119`, `scripts/assistance/shot_assist.gd:124` |  (Tiro) |
| `shot_charge_time` | `0.9` | float | `scripts/ball/ball_tuning.gd:71` | `scripts/ai/ai_input.gd:509`, `scripts/player/ball_handler.gd:489` | Segundos para cargar el tiro al maximo. (Tiro) |
| `shot_loft_low_deg` | `4.0` | float | `scripts/ball/ball_tuning.gd:72` | `scripts/assistance/shot_assist.gd:158`, `scripts/assistance/shot_assist.gd:163`, `scripts/assistance/shot_assist.gd:164`, `scripts/assistance/shot_assist.gd:224` |  (Tiro) |
| `shot_loft_high_deg` | `22.0` | float | `scripts/ball/ball_tuning.gd:73` | `scripts/assistance/shot_assist.gd:163`, `scripts/assistance/shot_assist.gd:164` |  (Tiro) |
| `shot_spin_factor` | `14.0` | float | `scripts/ball/ball_tuning.gd:75` | `scripts/assistance/shot_assist.gd:183` | Factor de efecto (spin) aplicado segun la desviacion lateral del golpeo. (Tiro) |
<!-- /AUTO -->

### Riesgos al modificar (verificados con las pruebas y mediciones de esta sesión)

| Parámetro | Efecto real y riesgo |
|---|---|
| `bounce` | Controla el rebote contra el piso (el piso tiene `bounce = 0.0`, y el resultado observado coincide con usar el valor de la pelota; la regla de combinación de Jolt **no se verificó en su documentación**, solo por medición). Sensibilidad medida desde 2 m (ver tabla abajo). `test_bounce_height_matches_futsal_spec` exige 0.45–0.70 m: bajar el valor por debajo de ~0.45 romperá esa prueba. También cambia el rebote contra postes y paredes (sus materiales tienen bounce propio, pero la pelota aporta el suyo) y los pases elevados al caer. |
| `friction` | Afecta al agarre contra el piso (acople rodadura/giro) y a los rebotes laterales. Al cambiarlo, revisar `test_rolling_decelerates_and_stops`. |
| `mass` | Escala el impulso de cada golpe (`kick` aplica `Δv · mass`) y entra en `k = ½·ρ·Cd·A/m` del arrastre; `KickModel.ground_speed_for_distance` usa la misma `mass`, así que los pases al espacio se recalculan solos, pero cambia el balance del Magnus y de las colisiones con cuerpos. |
| `radius` | Define la colisión, la altura de reposo, el área del arrastre, `rolling_spin = ω = (↑ × v)/r` y la regla de gol (`Goal.is_ball_in_goal` exige que el centro esté al menos un radio detrás de la línea). |
| `drag_coefficient`, `air_density`, `rolling_decel`, `rolling_viscous`, `rolling_viscous_knee` | La rodadura es **un solo modelo compartido** (`Ball.roll_decel` / `roll_speed` / `roll_distance` / `roll_speed_for` / `roll_time` / `roll_start_speed` / `roll_catch_time`): lo usan `_integrate_forces`, `BallPredictor` (arquero, IA), `KickModel.ground_speed_for_distance` (pases), `PassAssist`, `PressController`, la conducción (`BallHandler`: impulso de cada toque, plan de los toques de clip, golpeos sobre pelota en movimiento, pelota que llega) y `DragBack`. Cambiar un valor es coherente en todos; cambiar la física de `_integrate_forces` sin tocar esas funciones no. Con `rolling_viscous` alto la conducción empuja y alcanza (como FTS) pero los pases necesitan más fuerza (`pass_speed_max`) y una pelota lenta no llega al arco (`test_slow_shot_to_the_hands_is_caught_and_distributed` usa 13 m/s desde 12 m). |
| `angular_damp` | Se aplica con `angular_damp_mode = REPLACE`; si se vuelve a `COMBINE` se suma el amortiguamiento por defecto de Godot (`default_linear_damp`/`default_angular_damp`) y la pelota frena claramente más de lo modelado (defecto ya corregido, ver CHANGELOG). |
| `max_spin` y `jolt_physics_3d/limits/max_angular_velocity` | Jolt limita por defecto el giro a 47.1 rad/s; con ese límite `rolling_spin` se truncaba y la pelota resbalaba al inicio. El proyecto lo sube a 200. Si se baja, reaparece el deslizamiento. |
| `net_stiffness`, `net_damp_in`, `net_damp_out`, `net_return`, `net_grip`, `net_max_bulge` | Red de tela (`GoalNet`): cuánto se abomba con un tiro, cuánto lo frena y cuánto lo devuelve. Con `net_return` alto la pelota rebota fuera del arco tras el gol (`test_goal_net` lo vigila: vuelta < 20 % y la pelota queda dentro). |
| `max_speed` | Tope duro de velocidad lineal en `_integrate_forces`. Debe ser mayor que `BallTuning.shot_speed_max · 1.2` (tope de `ShotAssist`). |

### Sensibilidad de `bounce` (medida el 2026-10-26 con una prueba temporal, pelota soltada desde 2 m sobre el piso de la cancha)

| `BallTuning.bounce` | 0.25 | 0.35 | 0.45 | **0.54 (actual)** | 0.62 |
|---|---|---|---|---|---|
| Altura del primer rebote | 0.123 m | 0.236 m | 0.385 m | **0.550 m** | 0.719 m |

La referencia de 50–65 cm desde 2 m para un balón de futsal es la que usa el proyecto en comentarios y pruebas; **no se contrastó con la fuente oficial en esta sesión**.

## Mapa de funciones

<!-- AUTO:funcs:scripts/ball/ball.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Ball._ready()` | 81 |  |
| `Ball._build()` | 87 |  |
| `Ball.apply_tuning()` | 131 | Aplica los parametros de BallTuning (se puede llamar en caliente desde el laboratorio). |
| `Ball.kick(target_velocity: Vector3, spin: Vector3 = Vector3.ZERO, kicker: Node = null)` | 156 | Golpe: aplica el impulso necesario para que la pelota salga con la velocidad y el giro dados. |
| `Ball.set_knuckle(accel: float, freq: float, phase: float)` | 169 | Activa el "flotado" del tiro sin giro recien pateado: amplitud (m/s^2), frecuencia (Hz) y fase (rad) de la fuerza lateral. Se llama justo de |
| `Ball.rolling_spin(velocity: Vector3)` | 178 | Giro de rodadura sin deslizamiento para una velocidad horizontal dada (w = up x v / r). Un golpe raso real transmite este giro; sin el, la p |
| `Ball.push(impulse: Vector3, actor: Node = null)` | 182 | Impulso arbitrario (desvios, choques) sin cambiar el ultimo toque salvo que se indique actor. |
| `Ball.register_touch(actor: Node)` | 187 |  |
| `Ball.reset_at(pos: Vector3, vel: Vector3 = Vector3.ZERO)` | 201 | Teletransporte controlado (saques de centro, reinicios). No se usa durante el juego normal. |
| `Ball.hold(anchor: Node3D, by: Node)` | 213 |  |
| `Ball.release(by: Node, velocity: Vector3 = Vector3.ZERO)` | 223 |  |
| `Ball.is_held()` | 232 |  |
| `Ball.is_grounded()` | 235 |  |
| `Ball.speed()` | 238 |  |
| `Ball.ground_speed()` | 241 |  |
| `Ball.capture_state(tick: int = 0)` | 244 |  |
| `Ball.apply_state(s: BallState)` | 257 |  |
| `Ball._process(delta: float)` | 276 |  |
| `Ball._visual_step(delta: float)` | 281 |  |
| `Ball._physics_process(_delta: float)` | 305 |  |
| `Ball._ball_step(_delta: float)` | 310 |  |
| `Ball._update_trail(delta: float)` | 316 | Estela: se activa con un tiro rapido o con mucho efecto lateral en el aire y se desvanece al frenar o tocar el suelo. |
| `Ball._integrate_forces(state: PhysicsDirectBodyState3D)` | 352 |  |
| `Ball._integrate_step(state: PhysicsDirectBodyState3D)` | 357 |  |
| `Ball._roll_params()` | 449 | Desaceleracion sobre el piso: a + c * min(v, vk) (BallTuning rolling_decel, rolling_viscous, rolling_viscous_knee). Por debajo de vk la part |
| `Ball.roll_decel(v: float)` | 454 | Desaceleracion (m/s2) de la rodadura a la velocidad v. |
| `Ball._visc_speed(v0: float, t: float, p: Vector3)` | 459 | Tramo proporcional (v <= vk): velocidad y distancia exactas a los t s, hasta pararse. |
| `Ball._visc_stop_time(v0: float, p: Vector3)` | 463 |  |
| `Ball._visc_distance(v0: float, t: float, p: Vector3)` | 467 |  |
| `Ball._roll_step(v: float, dt: float)` | 473 | Velocidad tras rodar dt segundos sobre el piso partiendo de v (modelo exacto de _integrate_forces, sin el aire). |
| `Ball.roll_speed(v0: float, t: float)` | 477 | Velocidad (m/s) de una pelota que rueda t segundos partiendo de v0. |
| `Ball.roll_distance(v0: float, t: float)` | 488 | Distancia (m) que recorre en t segundos una pelota que rueda partiendo de v0 (hasta detenerse). |
| `Ball.roll_stop_time(v0: float)` | 499 | Tiempo (s) hasta que la pelota que sale a v0 se detiene. |
| `Ball.roll_speed_for(dist: float, t: float)` | 506 | Velocidad inicial (m/s) para recorrer dist metros en t segundos rodando (la mas baja que llega, hasta 60 m/s). |
| `Ball.roll_speed_to_stop(dist: float)` | 528 | Velocidad inicial (m/s) con la que la pelota rueda dist metros y se detiene ahi. |
| `Ball.roll_time(v0: float, dist: float)` | 542 | Tiempo (s) que tarda en recorrer dist metros una pelota que rueda partiendo de v0 (INF si se detiene antes). |
| `Ball.roll_start_speed(v_end: float, t: float)` | 559 | Velocidad (m/s) con la que tiene que salir la pelota para rodar a v_end dentro de t segundos. |
| `Ball.roll_catch_time(advance: float, vp: float)` | 573 | Tiempo (s) en que una pelota tocada desde un cuerpo que va a vp m/s queda `advance` metros mas adelantada que el y con su misma velocidad (e |
| `Ball._on_body_entered(body: Node)` | 587 |  |
<!-- /AUTO -->

### Constantes de capas y señales

<!-- AUTO:consts:scripts/ball/ball.gd -->
| Constante / enum / uniform | Valor | Línea | Descripción |
|---|---|---|---|
| `Ball.LAYER_WORLD` | `1` | 21 |  |
| `Ball.LAYER_BALL` | `2` | 22 |  |
| `Ball.LAYER_PLAYERS` | `4` | 23 |  |
| `Ball.LAYER_KEEPERS` | `8` | 24 |  |
| `Ball.LAYER_GOAL_FRAME` | `16` | 25 |  |
| `Ball.FLOOR_FRICTION` | `0.8` | 28 | Friccion del cesped (material del piso de Pitch y Stadium11). Jolt combina la de la pelota y la del piso tomando la menor (como Godot Physics): medido en la cancha, la pelota que desliza frena a mu*g con mu = 0,58-0,60 = min(0,6; 0,8). |
| `Ball.TRAIL_POINTS` | `18` | 60 | Estela de los tiros fuertes o con efecto (solo presentacion): cinta con las ultimas posiciones de la pelota. La forma de la curva que dibuja es la de la trayectoria real (no se inventa nada). |
| `Ball.TRAIL_MIN_SPEED` | `15.0` | 61 |  |
| `Ball.TRAIL_MIN_SPIN` | `14.0` | 62 |  |
| `Ball.KNUCKLE_MIN_SPEED` | `12.0` | 72 | Tiro sin giro que "flota" (knuckle, lo pone el tiro potente con set_knuckle): aceleracion lateral oscilante (m/s^2) mientras la pelota va rapida por el aire con poco giro, como la de las pelotas reales sin giro (la estela de aire se desprende de forma irregular). Cualquier golpe, bote o choque la apaga. |
| `Ball.KNUCKLE_MAX_SPIN` | `12.0` | 73 |  |
| `Ball.KNUCKLE_MAX_TIME` | `1.5` | 74 |  |
| `Ball.VISUAL_SPIN_DEG_PER_FRAME` | `20.0` | 267 | Grados maximos que gira el balon DIBUJADO por imagen. El patron (parches sobre los 12 vertices de un icosaedro) se repite cada ~63 grados: un pase a 6 m/s rueda a ~57 rad/s = 55 grados por imagen a 60 fps y se ve QUIETO; a 10 m/s, 92 grados por imagen, y parece girar despacio o al reves (efecto rueda de carro). El dibujo sigue el eje y el sentido reales pero sin pasar de este giro por imagen (legible tambien a 30 fps). La fisica (giro real, Magnus) no cambia. |
| `Ball.VISUAL_SHUTTER` | `0.5` | 270 | Fraccion de la imagen con el obturador abierto: el patron se desenfoca a lo largo del giro REAL de ese tiempo (el shader lo promedia alrededor del eje), como en la television: rapido quedan bandas y se ven los polos del eje. |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/ball/ball.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `Ball.touched(actor: Node)` | 11 | Pelota independiente con fisica 3D (RigidBody3D / Jolt).  Reglas del diseno: - Nunca se teletransporta al pie del jugador ni se anula su velocidad para simular control. - Los jugadores interactuan solo mediante impulsos (kick) en el instante del contacto. - Resistencia del aire, efecto Magnus y rodadura se calculan en _integrate_forces. - Excepcion explicita: el arquero puede sostenerla (hold/release) mientras la tiene en las manos. |
| `Ball.hit_goal_frame(position: Vector3, speed: float)` | 12 |  |
| `Ball.floor_bounce(position: Vector3, speed: float)` | 13 |  |
| `Ball.released(by: Node)` | 14 |  |
| `Ball.impulse(actor: Node, dv: float, speed: float)` | 17 | Cada golpe (Ball.kick): quien la toco (o null), cuanto cambio la velocidad (m/s) y la velocidad con la que sale. Lo usan los sonidos (Sfx) y la camara (sacudida del tiro). |
| `Ball.net_hit(speed: float)` | 19 | La pelota entra en contacto con la red de tela (con su velocidad en ese momento). |
<!-- /AUTO -->

## Recorrido de ejecución

1. **Creación:** `Ball._ready` → `Tuning.ball` → `Ball._build` (capas, `contact_monitor`, `continuous_cd`, `can_sleep = false`, colisión esférica, malla) → `Ball.apply_tuning` (radio, masa, **inercia de esfera hueca** `2/3·m·r²`, material físico con `bounce`/`friction`, modos de amortiguamiento `REPLACE`).
2. **Cada paso de física (60 Hz):** `Ball._integrate_forces`: (a) si hay teletransporte pendiente, lo aplica y sale; (b) detecta contacto con el piso (normal con `y > 0.6`); (c) emite `floor_bounce` al invertirse la velocidad vertical; (d) resta arrastre `½·ρ·Cd·A·v²/m`; (e) suma Magnus `k·(ω×v)/m` en el aire; (f) sobre el piso aplica la rodadura con su paso exacto (`Ball._roll_step`: desaceleración `rolling_decel + rolling_viscous · min(v, rolling_viscous_knee)`) y escala el giro para no pelear con la fricción; (e2) con `knuckle_accel > 0` (tiro potente sin giro, `Ball.set_knuckle`) suma una aceleración lateral oscilante (y 0.4 de ella arriba/abajo) mientras va por el aire a más de `KNUCKLE_MIN_SPEED` 12 m/s con menos de `KNUCKLE_MAX_SPIN` 12 rad/s, hasta `KNUCKLE_MAX_TIME` 1.5 s; cualquier golpe, bote, choque o teletransporte la apaga; (g) suma la aceleración de la red de tela (`net_accel`, `GoalNet`) y, en contacto con ella, frena el giro (`net_grip`); (h) recorta a `max_speed`/`max_spin`.
3. **Golpe (jugador, asistencia, arquero):** `Ball.kick(v_objetivo, spin, actor)` → `apply_central_impulse((v_objetivo − v)·mass)` + `apply_torque_impulse((spin − ω)·I)` → `register_touch` (guarda último y penúltimo en tocar; emite `touched`).
4. **Contactos especiales:** `Ball._on_body_entered` → poste/travesaño (grupo `goal_frame`): señal `hit_goal_frame`. La red es tela (`GoalNet`, ver [PITCH](PITCH.md#red-de-tela-2026-10-28)): deja su aceleración en `Ball.net_accel` y `net_contact` (frena también el giro con `net_grip`), que `_integrate_forces` aplica en el paso siguiente.
5. **Giro dibujado** (`Ball._process`, solo presentación): la malla gira con el eje y el sentido del giro real pero como mucho `VISUAL_SPIN_DEG_PER_FRAME` 20° por imagen (el patrón se repite cada ~63°: a 6 m/s el giro real de 55°/imagen se veía quieto y a 10 m/s, al revés); el shader (`assets/ball/ball.gdshader`, `spin_axis`/`spin_arc`) promedia el patrón a lo largo del giro real de medio fotograma (`VISUAL_SHUTTER` 0.5), como el obturador de una cámara: rápido quedan bandas y se ven los polos del eje.
6. **Giro de rodadura:** los golpes rasos usan `Ball.rolling_spin(v)` para que la pelota ruede sin deslizar; sin él la pelota resbala al inicio y pierde velocidad hasta empezar a rodar (fricción de deslizamiento; magnitud no aislada en una medición).

## Pruebas

- **Ejecutar:** `tools/run_tests.sh ball_physics` (9 pruebas, ~0.4 s). Para el efecto en pases: `tools/run_tests.sh passing`.
- **Última ejecución (2026-10-28, rodadura tipo FTS):** `ball_physics` 9 pruebas / 25 comprobaciones sin fallos; rebote 0.550 m desde 2 m; rodadura `v0 = 5.68 m/s`, `v(2 s) = 0.48 m/s` (`Ball.roll_speed` predice 0.51), recorrido hasta detenerse 5.0 m (antes, con 0.55 m/s² constantes: 5.96 → 4.45 m/s y 26.5 m).

<!-- AUTO:tests:tests/test_ball_physics.gd -->
| Prueba | Línea |
|---|---|
| `test_bounce_height_matches_futsal_spec` | 4 |
| `test_rolling_decelerates_and_stops` | 23 |
| `test_kick_applies_impulse_not_teleport` | 45 |
| `test_ball_stays_inside_walls` | 58 |
| `test_goal_detected_once_when_fully_across_line` | 69 |
| `test_ball_on_the_line_is_not_a_goal` | 84 |
| `test_post_deflects_ball_physically` | 96 |
| `test_crossbar_deflects_ball` | 113 |
| `test_state_roundtrip` | 130 |
<!-- /AUTO -->

- **Qué podría romperse al tocar este sistema:** altura de rebote fuera de 0.45–0.70 m; pases al espacio que no llegan a su distancia; la pelota atravesando paredes (`test_ball_stays_inside_walls`); gol detectado dos veces o con la pelota en la línea (`Goal.is_ball_in_goal`); rebote saliendo de la red.

## Limitaciones conocidas

- Durante pruebas headless con `--fixed-fps` Jolt puede imprimir `Jolt Physics job system exceeded the maximum number of jobs` (aviso del motor, visto en `test_ball_stays_inside_walls`); no se investigó su causa ni se midió en un dispositivo.
- No existe ningún `.tres` de la pelota en `resources/tuning/` (`Tuning.BALL_PATH` apunta a un archivo inexistente): los valores vigentes son los valores por defecto de `BallTuning`.
- El sonido de la pelota lo da `Sfx` (ver [AUDIO](AUDIO.md)) escuchando `impulse`, `floor_bounce`, `hit_goal_frame` y `net_hit`.

## Predicción aérea fiel a la física (E6, 2026-10-31)

`BallPredictor.trajectory(pos, vel, horizon, step, spin)` (nuevo argumento `spin`): arrastre en el aire completo
(`DRAG_SCALE_AIR` 1.0; rodando `DRAG_SCALE` 0.5), efecto Magnus en vuelo con el giro de la pelota, y bote con fricción por
deslizamiento (`BOUNCE_FRICTION` 0.63) que sigue el giro (tras el bote la pelota sale con efecto de rodadura). Antes: medio
arrastre en el aire, sin Magnus y bote aproximado; error de 1.4-5.3 m en vuelos con efecto, ahora 0.06-0.19 m
(`test_ball_prediction`, 7 casos). Todos los llamadores pasan el giro (arquero —con el giro percibido—, recepción,
conducción, golpeo, escena de partido, visor de recepciones).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Base física», «Control asistido» (corrección del límite angular de Jolt y del modo de amortiguamiento) y «Esqueleto único v1.0».

## Efecto pedido y estela (2026-10-27)

- El Magnus existente curva la pelota con el giro lateral de un tiro con chanfle (1.3 m en ~17 m, `test_ball_curl`).
- Estela (`Ball._update_trail`): cinta con las últimas posiciones en tiros rápidos o con mucho efecto (solo presentación; dibuja la trayectoria real).

## Efecto natural, flotado y giro dibujado (2026-10-28)

- Cada tiro sale con el giro de su golpeo (`ShotAssist.compute`, ver [ASSISTANCE](ASSISTANCE.md#tiros-dirigidos-al-arco-efecto-natural-del-golpeo-y-arquero-2026-10-28)):
  empeine con rosca hacia el lado del pie, colocado con más rosca, potente casi sin giro con **flotado**
  (`Ball.set_knuckle`), vaselina con contragiro. Los pases ya rodaban con su giro de rodadura (`rolling_spin`) y el
  elevado con retroceso; los centros con rosca hacia el arco.
- Flotado medido (`test_ball_curl`): potente de 18 m, 3 rad/s de giro, aceleración 4.6 m/s² a 2.3 Hz: 0.15 m de desvío
  en la línea respecto al mismo tiro sin flotado.
- Giro dibujado medido (`test_ball_curl::test_drawn_ball_spin_is_readable`, 60 fps): pase a 2 / 6 / 12 m/s gira 19 /
  57 / 114° por imagen; se dibuja 18.8 / 19.9 / 19.8° con el eje real y desenfoque en 9 / 29 / 57°. Revisión visual con
  `tools/ball_spin_view.tscn` (tiras de imágenes consecutivas: pase lento nítido, pase rápido con gajos arrastrados,
  chanfle arrastrado de lado, potente sin giro con los gajos quietos).

## Rodadura tipo First Touch Soccer (2026-10-28)

Origen: la libreria nativa de First Touch Soccer 27 (`libFTS15.so`, simbolos exportados; ver
[DRIBBLE_DIAGNOSIS](../DRIBBLE_DIAGNOSIS.md#octava-ronda-2026-10-28-first-touch-soccer-27-apk-y-videos-diferenciasfutbol)).
En `CBallProj::Iterate` la pelota en el suelo conserva **1006/1024 de su velocidad por imagen** a 60 Hz (rozamiento
proporcional a la velocidad, ~1.06/s), en el aire 2032/2048 y en cada bote 675/1024 de la vertical. Nuestra rodadura era
una desaceleracion constante (0.55 m/s², ~0.64 efectiva): tras cada toque la pelota rodaba a la velocidad del jugador,
la distancia pelota–pie casi no variaba y la conduccion se veia **atada a una cuerda**.

- Ahora: desaceleracion `rolling_decel` (0.3) `+ rolling_viscous` (1.0 /s) `· min(v, rolling_viscous_knee)` (7 m/s).
  Hasta 7 m/s (todos los toques de conduccion) manda la parte proporcional, como FTS: el toque sale disparado, frena y
  espera al jugador. Por encima la desaceleracion es constante (7.3 m/s²): un pase o tiro fuerte por el suelo pierde ~20 %
  en 15 m (con 1/s puro un tiro raso de 25 m/s llegaba a 10 m/s).
- Paso exacto por tramos (`Ball._roll_step`) y formulas cerradas para todo el que planifica con la pelota: velocidad y
  distancia a los t s, velocidad inicial para recorrer d en t, tiempo para recorrer d, velocidad de salida para llegar a
  v en t y el tiempo en que un cuerpo a vp alcanza una pelota tocada `advance` m por delante.
- Calibrado con la pelota real (Jolt) rodando de 1.5 a 16 m/s: hasta 8 m/s el mejor ajuste es 0.28 + 1.02 v (error
  < 2 cm a los 2 s), igual a los valores de `BallTuning`; por encima pesa el arrastre del aire, que estas formulas no
  incluyen (k efectivo ~0.5 de la formula, `BallPredictor.DRAG_SCALE`, confirmado: 0.006 frente a 0.0115).
- Efecto medido en la conduccion (prueba con render `dribble_reference`, pelota delante del cuerpo p5/media/p95):
  trote 0.40/0.48/0.51 → **0.27/0.42/0.50 m**, carrera 0.54/0.57/0.63 → **0.48/0.72/0.82 m**, sprint 0.27/0.66/0.75 →
  0.30/0.74/0.92 m: la pelota va y vuelve del pie 2–4 veces mas (en el video de FTS, 0.15–0.6 m cada ~0.6 s).
- Pases: `pass_speed_max` 21 → 28 m/s (un pase raso de 20 m que llega a 4 m/s sale a ~17 m/s).


## Tiro con más potencia, estela más ancha y señales de golpe (2026-10-29)

- prueba03: «shootar se siente horrible, necesita más potencia». `BallTuning.shot_speed_min` 9 → **12** m/s y
  `shot_speed_max` 27 → **30** m/s (tope de `ShotAssist` 36 m/s, por debajo de `max_speed` 38).
- La estela se ensancha con la velocidad: de 0.9 radios a 15 m/s hasta 1.8 radios a 29 m/s, y es algo más opaca (0.65):
  un tiro fuerte se lee en la pantalla del móvil.
- Señales nuevas: `impulse(actor, dv, speed)` en cada `Ball.kick` (quién, cuánto cambió la velocidad y con cuánta sale; la
  usan `Sfx` y el golpe de cámara `MatchCamera.watch_shots`) y `net_hit(speed)` cuando la pelota entra en contacto con la
  red de tela (transición, una vez por contacto). No cambian la física.
