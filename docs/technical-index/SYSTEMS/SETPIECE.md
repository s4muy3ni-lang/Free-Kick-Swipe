# SETPIECE — Modos de penales y tiros libres (juego)

## Identificación

- **Qué es:** el juego de la reforma: menú principal y los dos modos, **PENALES** (tanda contra la CPU: un tiro y una
  atajada por ronda, serie de 5 y muerte súbita) y **TIRO LIBRE** (el usuario coloca la pelota donde quiere fuera del
  área; barrera, arquero y jugadores sueltos), en una cancha de fútbol 11 con dos tipos de arco (caja y fondo inclinado).
- **Banco de animación:** el JSON original (las 2.022 animaciones ya convertidas en `assets/animations/json_*.res`). No se
  crean ni modifican clips: el juego elige entre los existentes con sus metadatos medidos (contacto del pie, trayectoria
  de las manos, raíz, rumbo, rol).
- **Estado (2026-11-08):** jugable de punta a punta; la medición de tacto y rendimiento en el teléfono queda para el
  usuario. Informe y análisis: [`docs/reforma/MODOS_TIROS_PENALES.md`](../../reforma/MODOS_TIROS_PENALES.md).

## Piezas y conexiones

| Archivo | Clase | Qué hace | Reutiliza |
|---|---|---|---|
| `scripts/setpiece/main_menu.gd`, `scenes/setpiece/main_menu.tscn` | `MainMenu` | Escena principal: estadio de fondo, PENALES / TIRO LIBRE, pie hábil, dificultad, tipo de arco, acceso al banco de pruebas | `Stadium11`, `SpActor` |
| `scripts/setpiece/setpiece_game.gd`, `scenes/setpiece/setpiece_game.tscn` | `SetPieceGame` | Estados y turnos de los dos modos, trazo, vista previa, resultado, reacciones, cámara | todo lo de abajo |
| `scripts/setpiece/stadium11.gd` | `Stadium11` | Cancha de 105 × 68 m, líneas y áreas reglamentarias, arcos, carteles, tribunas con público, luces | `Goal`, `GoalNet`, `Pitch.LineBuilder`, `MeshUtil` |
| `scripts/pitch/goal_net.gd` | `GoalNet` | Red de tela (membranas con ondas): ahora también con fondo inclinado, laterales trapezoidales y caída de reposo | (ampliada) |
| `scripts/setpiece/sp_clips.gd` | `SpClips` | Bibliotecas del banco JSON, id → biblioteca, meta, raíz y rumbo de cada clip | `ClipRolesOverlay`, `ActionMotion.heading_rel` |
| `scripts/setpiece/sp_actor.gd` | `SpActor` | Humano JSON animado con movimiento de raíz, bucles en el sitio, cápsula de colisión que sigue la cadera | `AnimBankCatalog.kit_material` |
| `scripts/setpiece/shot_catalog.gd`, `resources/setpiece/shot_clips.json` | `ShotCatalog` | Golpeos medidos (contacto, dirección del pie respecto de la carrera, velocidad del pie) y elección por pie, dirección, potencia, tipo | catálogo generado por `tools/setpiece/build_shot_catalog.gd` |
| `scripts/setpiece/sp_shooter.gd` | `SpShooter` | Carrera, golpeo con el pie medido en la pelota e impulso en el instante de contacto, reacción | `Ball.kick`, `Ball.set_knuckle` |
| `scripts/setpiece/shot_gesture.gd` | `ShotGesture` | Captura y análisis del trazo (filtro, normalización, velocidades, aceleración, curvatura, suavidad) | — |
| `scripts/setpiece/gesture_tuning.gd` | `GestureTuning` | Coeficientes del trazo, editables en el juego y guardados en `user://gesture_tuning.tres` | — |
| `scripts/setpiece/gesture_shot_model.gd`, `scripts/setpiece/shot_params.gd` | `GestureShotModel`, `ShotParams` | Gesto → parámetros del disparo → física | `ShotSolver` |
| `scripts/setpiece/shot_solver.gd` | `ShotSolver` | Velocidad inicial para llegar al objetivo con el mismo modelo de vuelo que la pelota | `BallPredictor.trajectory` |
| `scripts/setpiece/trajectory_preview.gd` | `TrajectoryPreview` | Trayectoria prevista (cinta discontinua, aro de llegada) mientras el dedo está apoyado | — |
| `scripts/setpiece/gesture_diagnostics.gd` | `GestureDiagnostics` | Panel «Diag.»: medidas del trazo, golpeo elegido, velocidad real de salida, coeficientes, comparador de trazos | — |
| `scripts/setpiece/sp_keeper.gd` | `SpKeeper` | Arquero (IA o usuario): plan de atajada, contacto físico con esferas en los huesos, atrapa o desvía, se levanta, reacciona | `KeeperPlanner.plan_save`, `BallPredictor` |
| `scripts/setpiece/sp_wall.gd` | `SpWall` | Barrera a 9,15 m con colisión real y salto sincronizado con la llegada de la pelota | `SpActor.enable_collider` |
| `scripts/setpiece/sp_field_players.gd` | `SpFieldPlayers` | Compañeros y defensores sueltos; despeje de cabeza solo si llegan | — |
| `scripts/setpiece/sp_reactions.gd` | `SpReactions` | Festejos, lamentos, enojo, aplausos por rol | — |
| `scripts/setpiece/penalty_shootout.gd` | `PenaltyShootout` | Reglas de la tanda (estado puro; base del futuro 1 contra 1) | — |
| `scripts/setpiece/sp_camera.gd`, `scripts/setpiece/sp_hud.gd`, `scripts/setpiece/sp_settings.gd` | `SpCamera`, `SpHud`, `SpSettings` | Cámaras con transición, interfaz horizontal, preferencias y uniformes | `UiTheme` |

Flujo de un tiro del usuario: `ShotGesture` (muestras) → `GestureShotModel.build` (parámetros) → `GestureShotModel.solve`
(física; la vista previa usa la misma función) → `SetPieceGame._take_shot` (error de precisión, clase prevista, familia)
→ `ShotCatalog.choose` (golpeo) → `SpShooter.execute` (carrera y clip) → contacto del clip → `Ball.kick` → arquero,
barrera y sueltos reaccionan a la pelota real → resultado (la física decide).

## Parámetros del trazo

<!-- AUTO:params:GestureTuning -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `smoothing` | `0.35` | 0.0, 0.9 | `scripts/setpiece/gesture_tuning.gd:13` | `scripts/setpiece/gesture_tuning.gd:93`, `scripts/setpiece/shot_gesture.gd:48` | Suavizado exponencial de los puntos (0 = sin filtro, 1 = no se mueve): reduce el temblor del dedo. (Captura y filtro) |
| `min_step` | `0.004` | 0.0, 0.02 | `scripts/setpiece/gesture_tuning.gd:15` | `scripts/setpiece/shot_gesture.gd:45`, `scripts/setpiece/shot_gesture.gd:55` | Distancia minima entre muestras (alturas de pantalla): ignora micro movimientos involuntarios. (Captura y filtro) |
| `max_samples` | `96` | 16, 256 | `scripts/setpiece/gesture_tuning.gd:17` | `scripts/setpiece/shot_gesture.gd:25`, `scripts/setpiece/shot_gesture.gd:26`, `scripts/setpiece/shot_gesture.gd:31`, `scripts/setpiece/shot_gesture.gd:32` (+1) | Muestras como maximo (al llenarse se diezma de a dos). (Captura y filtro) |
| `min_length` | `0.07` | 0.02, 0.3 | `scripts/setpiece/gesture_tuning.gd:19` | `scripts/setpiece/gesture_shot_model.gd:65` | Largo minimo para que el trazo sea un tiro (alturas de pantalla). (Captura y filtro) |
| `speed_slow` | `0.9` | 0.2, 3.0 | `scripts/setpiece/gesture_tuning.gd:23` | `scripts/setpiece/gesture_shot_model.gd:24`, `scripts/setpiece/gesture_tuning.gd:93`, `scripts/setpiece/setpiece_game.gd:789` | Velocidad del dedo para potencia minima y maxima (alturas de pantalla / s). (Potencia (velocidad del dedo)) |
| `speed_fast` | `4.4` | 1.0, 10.0 | `scripts/setpiece/gesture_tuning.gd:24` | `scripts/setpiece/gesture_shot_model.gd:24`, `scripts/setpiece/gesture_tuning.gd:93`, `scripts/setpiece/setpiece_game.gd:789` |  (Potencia (velocidad del dedo)) |
| `peak_weight` | `0.35` | 0.0, 1.0 | `scripts/setpiece/gesture_tuning.gd:26` | `scripts/setpiece/gesture_shot_model.gd:23`, `scripts/setpiece/gesture_tuning.gd:94` | Peso de la velocidad maxima frente a la media (un latigazo final cuenta). (Potencia (velocidad del dedo)) |
| `power_curve` | `1.2` | 0.05, 4.0 | `scripts/setpiece/gesture_tuning.gd:28` | `scripts/setpiece/gesture_shot_model.gd:25`, `scripts/setpiece/gesture_tuning.gd:94` | Curva de respuesta: potencia = min + (max - min) * (1 - exp(-g x)) / (1 - exp(-g)); g > 0 satura los trazos muy rapidos. (Potencia (velocidad del dedo)) |
| `power_min` | `0.05` | 0.0, 0.5 | `scripts/setpiece/gesture_tuning.gd:29` | `scripts/setpiece/gesture_shot_model.gd:27` |  (Potencia (velocidad del dedo)) |
| `power_max` | `1.0` | 0.5, 1.0 | `scripts/setpiece/gesture_tuning.gd:30` | `scripts/setpiece/gesture_shot_model.gd:27` |  (Potencia (velocidad del dedo)) |
| `descend_drop` | `0.6` | 0.0, 1.5 | `scripts/setpiece/gesture_tuning.gd:34` | `scripts/setpiece/gesture_shot_model.gd:44`, `scripts/setpiece/gesture_tuning.gd:94` | Trazo que termina bajando: baja el punto de llegada (m) y agrega efecto hacia delante (la pelota cae). (Altura) |
| `ascend_lift` | `0.25` | 0.0, 1.0 | `scripts/setpiece/gesture_tuning.gd:36` | `scripts/setpiece/gesture_shot_model.gd:46` | Trazo que termina subiendo con fuerza: sube el punto de llegada (m). (Altura) |
| `curve_deadzone` | `0.025` | 0.0, 0.1 | `scripts/setpiece/gesture_tuning.gd:40` | `scripts/setpiece/gesture_shot_model.gd:50`, `scripts/setpiece/gesture_shot_model.gd:69`, `scripts/setpiece/gesture_tuning.gd:95`, `scripts/setpiece/setpiece_game.gd:796` | Curvatura por debajo de la cual no hay efecto (zona muerta). (Efecto (curvatura)) |
| `spin_gain` | `280.0` | 50.0, 600.0 | `scripts/setpiece/gesture_tuning.gd:42` | `scripts/setpiece/gesture_shot_model.gd:52`, `scripts/setpiece/gesture_tuning.gd:95`, `scripts/setpiece/setpiece_game.gd:798` | Giro (rad/s) por unidad de curvatura y giro maximo. (Efecto (curvatura)) |
| `spin_max` | `70.0` | 10.0, 150.0 | `scripts/setpiece/gesture_tuning.gd:43` | `scripts/setpiece/gesture_shot_model.gd:52`, `scripts/setpiece/gesture_tuning.gd:95`, `scripts/setpiece/setpiece_game.gd:798` |  (Efecto (curvatura)) |
| `topspin` | `18.0` | 0.0, 40.0 | `scripts/setpiece/gesture_tuning.gd:45` | `scripts/setpiece/gesture_shot_model.gd:110`, `scripts/setpiece/gesture_shot_model.gd:111` | Efecto hacia delante (topspin, rad/s) de los tiros potentes y altos. (Efecto (curvatura)) |
| `error_base` | `0.35` | 0.0, 2.0 | `scripts/setpiece/gesture_tuning.gd:49` | `scripts/setpiece/gesture_shot_model.gd:56`, `scripts/setpiece/gesture_shot_model.gd:57`, `scripts/setpiece/gesture_shot_model.gd:58`, `scripts/setpiece/setpiece_game.gd:800` | Error (grados) base, por potencia (x potencia^2), por trazo irregular (x (1 - suavidad)) y por trazo corto. (Precision) |
| `error_power` | `1.5` | 0.0, 4.0 | `scripts/setpiece/gesture_tuning.gd:50` | `scripts/setpiece/gesture_shot_model.gd:56`, `scripts/setpiece/gesture_shot_model.gd:57`, `scripts/setpiece/gesture_tuning.gd:96`, `scripts/setpiece/setpiece_game.gd:800` |  (Precision) |
| `error_rough` | `1.6` | 0.0, 5.0 | `scripts/setpiece/gesture_tuning.gd:51` | `scripts/setpiece/gesture_shot_model.gd:56`, `scripts/setpiece/gesture_shot_model.gd:57`, `scripts/setpiece/gesture_tuning.gd:96` |  (Precision) |
| `error_short` | `0.8` | 0.0, 3.0 | `scripts/setpiece/gesture_tuning.gd:52` | `scripts/setpiece/gesture_shot_model.gd:56`, `scripts/setpiece/gesture_shot_model.gd:57` |  (Precision) |
| `length_full` | `0.45` | 0.1, 1.0 | `scripts/setpiece/gesture_tuning.gd:54` | `scripts/setpiece/gesture_shot_model.gd:55`, `scripts/setpiece/gesture_shot_model.gd:77`, `scripts/setpiece/gesture_tuning.gd:96`, `scripts/setpiece/setpiece_game.gd:789` (+1) | Largo (alturas de pantalla) a partir del cual el trazo da el control completo de la direccion. (Precision) |
| `rough_ref` | `0.35` | 0.05, 1.0 | `scripts/setpiece/gesture_tuning.gd:56` | `scripts/setpiece/shot_gesture.gd:194` | Irregularidad de referencia (rad de cambio de direccion entre muestras, RMS) que deja la suavidad en 0. (Precision) |
| `lob_max_power` | `0.2` | 0.05, 0.5 | `scripts/setpiece/gesture_tuning.gd:60` | `scripts/setpiece/gesture_shot_model.gd:67`, `scripts/setpiece/gesture_shot_model.gd:92` | Potencia por debajo de la cual un trazo alto es un globo / vaselina. (Tipos de disparo) |
| `high_height` | `1.35` | 0.8, 2.4 | `scripts/setpiece/gesture_tuning.gd:62` | `scripts/setpiece/gesture_shot_model.gd:67`, `scripts/setpiece/gesture_shot_model.gd:75` | Altura de llegada (m) por encima de la cual el tiro es «elevado» o globo. (Tipos de disparo) |
| `curl_min` | `0.07` | 0.02, 0.3 | `scripts/setpiece/gesture_tuning.gd:64` | `scripts/setpiece/gesture_shot_model.gd:69` | Curvatura a partir de la cual el tiro es «con efecto». (Tipos de disparo) |
| `snap_max_length` | `0.2` | 0.05, 0.4 | `scripts/setpiece/gesture_tuning.gd:66` | `scripts/setpiece/gesture_shot_model.gd:71` | Largo maximo de un tiro «rapido de corta distancia» (alturas de pantalla). (Tipos de disparo) |
| `precision_smoothness` | `0.85` | 0.5, 1.0 | `scripts/setpiece/gesture_tuning.gd:68` | `scripts/setpiece/gesture_shot_model.gd:77` | Suavidad minima de un tiro «de precision». (Tipos de disparo) |
| `_current` | `null` | GestureTuning | `scripts/setpiece/gesture_tuning.gd:70` | `scripts/setpiece/gesture_tuning.gd:70`, `scripts/setpiece/gesture_tuning.gd:74`, `scripts/setpiece/gesture_tuning.gd:78`, `scripts/setpiece/gesture_tuning.gd:79` (+3) |  |
<!-- /AUTO -->

## Funciones principales

<!-- AUTO:funcs:scripts/setpiece/gesture_shot_model.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `GestureShotModel.context(plane_x: float, speed_range: Vector2, penalty: bool, half_goal: float, goal_h: float, radius: float)` | 18 | Convierte las propiedades del gesto (ShotGesture.features) en los parametros del disparo (ShotParams) y los resuelve con la fisica de la pel |
| `GestureShotModel.power_from(f: Dictionary, t: GestureTuning)` | 22 |  |
| `GestureShotModel.build(f: Dictionary, end_px: Vector2, cam: Camera3D, ball: Vector3, ctx: Dictionary, t: GestureTuning)` | 30 | Parametros del disparo a partir del gesto. end_px: final del trazo en pantalla. |
| `GestureShotModel.classify(p: ShotParams, t: GestureTuning, goal_h: float)` | 64 | Tipo de disparo que resulta del gesto (sin botones: sale de la combinacion de propiedades). |
| `GestureShotModel._apply_type(p: ShotParams, ctx: Dictionary, t: GestureTuning, descending: float)` | 83 |  |
| `GestureShotModel.solve(p: ShotParams, ball: Vector3, ctx: Dictionary, preview: bool = false)` | 117 | Resuelve con la fisica (preview: menos iteraciones y paso mas grueso, el mismo modelo). |
| `GestureShotModel.target_on_goal(cam: Camera3D, screen_point: Vector2, ball: Vector3, plane_x: float)` | 131 | Punto del plano del arco (x = plane_x) que queda bajo `screen_point`. Si el rayo toca el piso antes (trazo corto), se sigue la direccion del |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/setpiece/shot_catalog.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `ShotCatalog.clips()` | 27 |  |
| `ShotCatalog.entry(id: StringName)` | 38 |  |
| `ShotCatalog.rel_angle(c: Dictionary)` | 45 | Angulo (grados, + derecha) entre la carrera y el pie al golpear. |
| `ShotCatalog.is_desperate(c: Dictionary)` | 48 |  |
| `ShotCatalog.kind_of(c: Dictionary)` | 52 | Familia a la que pertenece un golpeo medido. |
| `ShotCatalog._kind_cost(want: int, have: int)` | 65 | Familias aceptables para un tipo de tiro (la primera es la ideal) y su costo extra. |
| `ShotCatalog.choose(foot: int, shot_rel_deg: float, kind: int, set_piece: bool, rng: RandomNumberGenerator = null, ball_speed: float = -1.0, prefer_short: bool = false, curled: bool = false)` | 84 | Elige el golpeo. foot: 1 derecho, -1 izquierdo. shot_rel_deg: angulo (+ derecha) del tiro respecto de la carrera habitual del pie (ver appro |
| `ShotCatalog.approach_dir(aim: Vector3, foot: int)` | 129 | Direccion de la carrera habitual del pie para tirar hacia `aim` (unit. horizontal): el diestro llega desde su izquierda. |
| `ShotCatalog.signed_deg(approach: Vector3, shot: Vector3)` | 134 | Angulo (grados, + derecha) de `shot` respecto de `approach` (direcciones horizontales). |
| `ShotCatalog.frame_for_shot(c: Dictionary, ball: Vector3, shot: Vector3)` | 140 | Marco del clip (origen, mirada) para que el pie llegue a la pelota en `ball` y salga hacia `shot` (horizontal). |
| `ShotCatalog.start_time(c: Dictionary, stance_dist: float, min_lead: float = 0.55)` | 151 | Instante desde el que conviene empezar el clip para que la carrera arranque a `stance_dist` de la pelota (o antes del contacto lo minimo par |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/setpiece/sp_keeper.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `SpKeeper.setup(a: SpActor, b: Ball, gx: float, half: float, height: float)` | 49 |  |
| `SpKeeper.reset(home_pos: Vector3)` | 64 | Coloca al arquero en su sitio, mirando al campo, en espera. |
| `SpKeeper.shuffle_to(p: Vector3)` | 84 | Paso lateral hacia una posicion (antes del tiro): sigue a la pelota sin dejar el arco. |
| `SpKeeper._yaw()` | 93 |  |
| `SpKeeper.read_shot(ball_pos: Vector3, velocity: Vector3, spin: Vector3)` | 97 | IA, despues del golpe (tiro libre): lee la trayectoria con su error de percepcion y planifica la atajada. |
| `SpKeeper.commit_to(point: Vector3, ball_pos: Vector3, lead: float, speed_guess: float = 22.0)` | 116 |  |
| `SpKeeper.on_kick(ball_pos: Vector3, velocity: Vector3)` | 126 | La pelota salio y ya habia elegido zona sin anticipar: planifica hacia esa zona con la velocidad que ve. |
| `SpKeeper._line_traj(ball_pos: Vector3, point: Vector3, speed: float, wait: float)` | 135 | Trayectoria supuesta: la pelota quieta `wait` segundos y despues en linea (con un poco de comba) hasta el punto. |
| `SpKeeper.guess_penalty(cue_point: Vector3, ball_pos: Vector3, lead: float, speed_guess: float = 22.0)` | 151 | IA en un penal: elige donde lanzarse con la lectura del cuerpo del tirador. cue_point: hacia donde apuntan la carrera y la cadera del tirado |
| `SpKeeper._plan_with(traj: PackedVector3Array, min_delay: float)` | 166 |  |
| `SpKeeper._start_dive()` | 176 |  |
| `SpKeeper._physics_process(delta: float)` | 184 |  |
| `SpKeeper._check_contact(delta: float)` | 197 |  |
| `SpKeeper._resolve(part: Array, c: Vector3, q: Vector3, parts_now: Dictionary, delta: float)` | 223 |  |
| `SpKeeper._can_catch(q: Vector3, vr: Vector3, parts_now: Dictionary)` | 249 | Atrapa si la pelota llega a las dos manos, no va demasiado rapida y viene de frente a una altura atrapable. |
| `SpKeeper._on_clip_finished(_id: StringName)` | 260 |  |
| `SpKeeper._getup()` | 277 |  |
| `SpKeeper.react(happy: bool)` | 292 | Festejo (atajo) o lamento (le hicieron gol) en el sitio, cuando ya esta de pie. |
| `SpKeeper.is_busy()` | 304 |  |
<!-- /AUTO -->

## Pruebas

<!-- AUTO:tests:tests/test_shot_gesture.gd -->
| Prueba | Línea |
|---|---|
| `test_fast_swipe_gives_more_power_than_slow_and_stays_in_limits` | 38 |
| `test_length_is_control_not_power` | 49 |
| `test_upward_swipe_raises_the_ball` | 61 |
| `test_curved_swipe_gives_lateral_spin_on_its_side` | 71 |
| `test_stable_gesture_is_more_precise` | 92 |
| `test_descending_end_keeps_it_low_with_topspin` | 102 |
| `test_gestures_produce_the_shot_types_naturally` | 111 |
| `test_features_do_not_depend_on_screen_resolution_and_samples_are_bounded` | 128 |
| `test_prediction_matches_the_real_ball` | 151 |
<!-- /AUTO -->

<!-- AUTO:tests:tests/test_setpiece_modes.gd -->
| Prueba | Línea |
|---|---|
| `test_penalty_shootout_rules` | 6 |
| `test_kick_choice_follows_the_direction_of_the_shot` | 23 |
| `test_chosen_kicks_put_the_foot_on_the_ball` | 57 |
| `test_wall_size_distance_and_free_kick_zone` | 93 |
| `test_the_wall_really_blocks_the_ball` | 120 |
| `test_both_goal_types_keep_the_ball_in_the_net` | 148 |
| `test_penalty_turn_flow` | 178 |
<!-- /AUTO -->

<!-- AUTO:tests:tests/test_setpiece_render.gd -->
| Prueba | Línea |
|---|---|
| `test_the_foot_reaches_the_ball_at_the_impulse` | 27 |
| `test_the_keeper_touches_what_he_reaches_and_not_what_he_does_not` | 45 |
<!-- /AUTO -->

Con render (esqueleto animado): `xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter test_setpiece_render`.
Capturas: `xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --resolution 1280x720 --path . res://tools/setpiece/captures.tscn -- --out <dir> --case all`.

## Riesgos y límites

- El tacto y el rendimiento en Android no se midieron (no hay teléfono en la sesión). Los coeficientes de `GestureTuning`
  son un punto de partida calibrado con trazos sintéticos y hay que ajustarlos en el teléfono (panel «Diag.»).
- Los golpeos potentes del banco salen hasta ~24° de la carrera; un tiro potente más cruzado usa un golpeo normal con ese
  ángulo (alternativa válida, no bloquea).
- El arquero en un penal elige el lado antes del golpe (adivina o elige el usuario): si acierta el lado puede atajar; un
  rincón bajo a más de ~2,2 m del centro suele ser inalcanzable con los clips de estirada medidos.
- El catálogo de golpeos es un archivo generado: si cambian las bibliotecas hay que regenerarlo
  (`godot --headless --path . res://tools/setpiece/build_shot_catalog.tscn`); la APK falla en CI si no está dentro.
