# ASSISTANCE — Pase, tiro y presión asistidos

## Identificación

- **Responsabilidad exacta:** convertir la *intención* del jugador (joystick, carga del botón) en un golpe o un movimiento defensivo con ayuda **moderada y configurable**, sin garantizar el resultado:
  - **Pase** (`PassAssist.compute`): elige al compañero que mejor coincide con la dirección apuntada (ángulo, distancia, línea libre), corrige la dirección de forma acotada y calcula la fuerza.
  - **Tiro** (`ShotAssist.compute`): corrige hacia un punto del arco solo si se apunta al arco o cerca; la ayuda se desvanece al apuntar fuera.
  - **Presión** (`PressController.update`): botón mantenido; busca el punto de intercepción de la **pelota**, se contiene a distancia y deja que el joystick ajuste el ángulo sin cancelar la búsqueda.
  - **Modelo de error** (`KickModel`): ruido gaussiano acotado que depende de distancia, potencia, equilibrio, orientación, velocidad, pierna de golpeo y atributos.
- **Estado:** implementado y probado (sin compañeros reales en la escena de juego: las pruebas los crean).
- **Última verificación:** <!-- AUTO:verified -->
2026-11-11
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/assistance/assist_tuning.gd` | Recurso `AssistTuning` con niveles y límites de las tres asistencias | `AssistTuning.Level`, `AssistTuning.LEVEL_VALUES`, `AssistTuning.set_all_levels` | — |
| `scripts/assistance/pass_assist.gd` | Clase `PassAssist` (estática): candidato, dirección, fuerza y error del pase | `PassAssist.compute`, `PassAssist._lane_clearance` | `KickModel`, `MatchContext`, `BallTuning` |
| `scripts/assistance/shot_assist.gd` | Clase `ShotAssist` (estática): punto de mira, corrección, trayectoria y error del tiro | `ShotAssist.compute` | `Goal.aim_point`, `PitchConfig`, `BallTuning`, `MatchContext` |
| `scripts/assistance/press_controller.gd` | Clase `PressController` (`RefCounted` con estado): intercepción, contención y disputa | `PressController.update`, `PressController.PressOutput`, `PressController._project`, `PressController._find_carrier` | `KickModel`, `MatchContext`, `Tuning` |
| `scripts/assistance/kick_model.gd` | Clase `KickModel` (estática): ángulos en XZ, error, equilibrio, pierna débil, velocidad exacta para una distancia | `KickModel.KickResult`, `KickModel.balance_state`, `KickModel.ground_speed_for_distance`, `KickModel.lob_speed_for_distance` | `Footballer`, `BallTuning` |

**No modificar para cambiar la asistencia:** `ball_handler.gd` (solo llama a `compute` y aplica el resultado) ni `Ball`. **Quién llama:** `BallHandler.perform_pass` / `perform_shot` y `Footballer._physics_process` (presión).

## Mapa de parámetros

<!-- AUTO:params:AssistTuning -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `pass_assist` | `0.65` | 0.0, 1.0 | `scripts/assistance/assist_tuning.gd:16` | `scripts/ui/hud.gd:201`, `scripts/assistance/assist_tuning.gd:60`, `scripts/gameplay/tuning.gd:65`, `scripts/gameplay/tuning.gd:82` (+1) |  (Pase) |
| `pass_cone_deg` | `60.0` | float | `scripts/assistance/assist_tuning.gd:18` | `scripts/assistance/pass_assist.gd:15`, `scripts/assistance/pass_assist.gd:173` | Angulo maximo entre la direccion del joystick y un companero para considerarlo. (Pase) |
| `pass_fallback_cone_deg` | `85.0` | float | `scripts/assistance/assist_tuning.gd:20` | `scripts/assistance/pass_assist.gd:22` | Con asistencia media o alta, cono (grados) en el que se busca companero cuando ninguno cae en el normal. (Pase) |
| `pass_max_distance` | `24.0` | float | `scripts/assistance/assist_tuning.gd:22` | `scripts/assistance/pass_assist.gd:37`, `scripts/assistance/pass_assist.gd:177` | Alcance maximo de busqueda (m). (Pase) |
| `pass_max_correction_deg` | `30.0` | float | `scripts/assistance/assist_tuning.gd:25` | `scripts/assistance/pass_assist.gd:94`, `scripts/assistance/pass_assist.gd:221` | Correccion angular maxima (grados) por unidad de asistencia, con asistencia baja (con media o alta el pase va al companero elegido: PassAssist.FULL_AIM_LEVEL). (Pase) |
| `pass_weight_angle` | `1.0` | float | `scripts/assistance/assist_tuning.gd:26` | `scripts/assistance/pass_assist.gd:45` |  (Pase) |
| `pass_weight_distance` | `0.35` | float | `scripts/assistance/assist_tuning.gd:27` | `scripts/assistance/pass_assist.gd:45` |  (Pase) |
| `pass_weight_lane` | `0.8` | float | `scripts/assistance/assist_tuning.gd:28` | `scripts/assistance/pass_assist.gd:45` |  (Pase) |
| `pass_lane_block_radius` | `0.8` | float | `scripts/assistance/assist_tuning.gd:30` | `scripts/assistance/pass_assist.gd:44`, `scripts/assistance/pass_assist.gd:205` | Radio de un rival para bloquear la linea de pase. (Pase) |
| `pass_error_deg` | `2.6` | float | `scripts/assistance/assist_tuning.gd:32` | `scripts/assistance/pass_assist.gd:125`, `scripts/assistance/pass_assist.gd:264` | Error base de pase en grados (atributo de precision 50, 8 m). (Pase) |
| `shot_assist` | `0.55` | 0.0, 1.0 | `scripts/assistance/assist_tuning.gd:35` | `scripts/ui/hud.gd:202`, `scripts/assistance/assist_tuning.gd:61`, `scripts/gameplay/tuning.gd:66`, `scripts/gameplay/tuning.gd:83` (+1) |  (Tiro) |
| `shot_cone_deg` | `38.0` | float | `scripts/assistance/assist_tuning.gd:36` | **sin uso** |  (Tiro) |
| `shot_max_correction_deg` | `10.0` | float | `scripts/assistance/assist_tuning.gd:37` | **sin uso** |  (Tiro) |
| `shot_post_margin` | `0.28` | float | `scripts/assistance/assist_tuning.gd:39` | `scripts/assistance/shot_assist.gd:81`, `scripts/assistance/shot_assist.gd:105` | Margen (m) que se deja respecto a los postes al apuntar. (Tiro) |
| `shot_error_deg` | `2.2` | float | `scripts/assistance/assist_tuning.gd:40` | `scripts/assistance/shot_assist.gd:132` |  (Tiro) |
| `press_assist` | `0.7` | 0.0, 1.0 | `scripts/assistance/assist_tuning.gd:43` | `scripts/ui/hud.gd:203`, `scripts/assistance/assist_tuning.gd:62`, `scripts/assistance/press_controller.gd:113`, `scripts/gameplay/tuning.gd:67` (+1) |  (Presion defensiva) |
| `press_lookahead` | `0.55` | float | `scripts/assistance/assist_tuning.gd:45` | `scripts/assistance/press_controller.gd:67`, `scripts/assistance/press_controller.gd:68` | Segundos hacia delante para predecir la posicion de intercepcion. (Presion defensiva) |
| `press_standoff` | `1.4` | float | `scripts/assistance/assist_tuning.gd:47` | `scripts/assistance/press_controller.gd:79`, `scripts/assistance/press_controller.gd:108` | Distancia a la que el defensor se mantiene (m) antes de disputar. (Presion defensiva) |
| `press_tackle_range` | `0.90` | float | `scripts/assistance/assist_tuning.gd:49` | `scripts/assistance/press_controller.gd:121`, `scripts/assistance/press_controller.gd:122`, `scripts/player/player_actions.gd:425` | Distancia a la que se intenta quitar la pelota (m). (Presion defensiva) |
| `press_around_offset` | `0.30` | float | `scripts/assistance/assist_tuning.gd:51` | `scripts/assistance/press_controller.gd:87` | Cuanto rodea el defensor al portador para atacar la pelota por el lado libre (m mas alla de la pelota). (Presion defensiva) |
| `press_speed_factor` | `0.93` | float | `scripts/assistance/assist_tuning.gd:52` | `scripts/assistance/press_controller.gd:61` |  (Presion defensiva) |
| `press_stick_influence` | `0.55` | float | `scripts/assistance/assist_tuning.gd:54` | `scripts/assistance/press_controller.gd:96` | Cuanto influye el joystick (0..1) en el angulo de aproximacion. (Presion defensiva) |
| `press_tackle_cooldown` | `1.3` | float | `scripts/assistance/assist_tuning.gd:56` | `scripts/assistance/press_controller.gd:125` | Segundos de enfriamiento entre intentos de robo. (Presion defensiva) |
<!-- /AUTO -->

Niveles de la interfaz (`Hud._cycle_assist`): `AssistTuning.LEVEL_VALUES` = Desactivada 0.0, Baja 0.35, Media 0.65, Alta 0.95; se guardan en `user://settings.cfg` (`Tuning.save_user_settings`). `Footballer.assist_override_pass`/`assist_override_shot` (≥ 0) los sustituyen por jugador (usado por las pruebas).

### Qué hace cada ajuste (verificado en el código)

| Ajuste | Comportamiento real |
|---|---|
| `pass_assist` (0–1) | Escala el cono de búsqueda (`pass_cone_deg × lerp(0.65, 1, nivel)`, ×0.75 sin joystick; con nivel ≥ `PassAssist.FULL_AIM_LEVEL` = 0.6 y joystick, cono de respaldo `pass_fallback_cone_deg` si nadie cae en el normal) y la corrección: con nivel ≥ 0.6 el pase va **al compañero elegido** (solo queda el error de ejecución); por debajo, `diff × nivel/0.6` con tope `pass_max_correction_deg × nivel`. Con nivel 0 no se busca compañero ni se corrige. |
| `pass_weight_*` | Puntaje del candidato = `w_ángulo·(1 − áng/cono) + w_distancia·cercanía_a_la_distancia_ideal + w_línea·línea_libre`; la distancia ideal crece con la carga (`4.5 + 13·carga` m). |
| `shot_assist` (0–1) | La corrección es `diff × nivel × peso`, con tope `shot_max_correction_deg × nivel`; `peso` cae a 0 cuando el punto de impacto proyectado en la línea de gol queda fuera de los postes más un margen que depende de `shot_cone_deg` y de la distancia. Con intención centrada y nivel ≥ 0.4 sugiere el lado opuesto al arquero (factor 0.62 del ancho útil). |
| `press_assist` | **Solo** escala la intensidad del movimiento de presión (`× lerp(0.9, 1.0, nivel)`); con nivel 0 la presión **sigue funcionando** (el botón es una acción del usuario). |
| `press_standoff`, `press_lookahead` | Distancia de contención ante un portador y horizonte (×2) de la intercepción. |
| `press_speed_factor` | Fracción de la velocidad máxima de sprint con que se calcula la intercepción (`chase_speed`, mínimo 2.5 m/s). |
| `press_stick_influence` | Peso de la componente lateral del joystick (×1.2) sobre la dirección de búsqueda. |
| `press_tackle_range`, `press_tackle_cooldown` | Alcance y enfriamiento del intento de robo (`BallHandler.attempt_tackle`, cuya probabilidad depende del atributo `marking`, orientación, equilibrio, velocidad relativa y, del portador, `strength`/`balance`). |
| `pass_error_deg`, `shot_error_deg` | Desviación típica base (grados) antes de multiplicadores. |

## Mapa de funciones

<!-- AUTO:funcs:scripts/assistance/pass_assist.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `PassAssist.pick_target(kicker: Footballer, ctx: MatchContext, intent: Vector3, has_stick: bool, charge: float, assist_level: float)` | 11 | Pase asistido. El jugador apunta con el joystick; el sistema elige el companero que mejor coincide con esa INTENCION (direccion, distancia,  |
| `PassAssist._pick_in_cone(kicker: Footballer, ctx: MatchContext, intent: Vector3, charge: float, cone: float)` | 28 |  |
| `PassAssist.compute(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool, rng: RandomNumberGenerator, assist_level: float)` | 53 | Calcula un pase. stick_dir: direccion deseada en el mundo (o cero), charge: 0..1, lob: pase elevado. assist_level: 0 = sin ayuda ... 1 = max |
| `PassAssist.compute_through(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool, rng: RandomNumberGenerator, assist_level: float)` | 157 | Pase filtrado: la pelota va al ESPACIO por delante del desmarque del receptor (hacia el arco rival), buscando el hueco entre defensores. El  |
| `PassAssist._pass_sigma(kicker: Footballer, dir: Vector3, dist: float, charge: float)` | 260 | Desviacion tipica (grados) del error de un pase: precision, distancia, equilibrio, orientacion, velocidad, potencia y compostura. La compart |
| `PassAssist.pressure(kicker: Footballer)` | 275 | Presion rival sobre un jugador (0 = nadie cerca, 1 = rival encima): sube el error de pases, centros y tiros. |
| `PassAssist._space_ahead(p: Footballer, atk: Vector3, opponents: Array[Footballer])` | 285 | Metros libres por delante de un jugador (hacia el arco rival) antes del rival mas cercano a su carril. |
| `PassAssist._lane_clearance(from_pos: Vector3, to_pos: Vector3, opponents: Array[Footballer], block_radius: float)` | 295 | 1.0 = linea totalmente libre; baja cuanto mas cerca de la linea de pase este un rival. |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/assistance/shot_assist.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `ShotAssist.compute(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool, rng: RandomNumberGenerator, assist_level: float, curl: float = 0.0)` | 54 |  |
| `ShotAssist.aim_edge(kicker: Footballer)` | 233 | Fraccion del ancho util a la que apunta el joystick hacia un palo para este tirador (ver AIM_EDGE). |
| `ShotAssist._stick_lateral(intent: Vector3, origin: Vector3, goal: Goal, usable: float)` | 239 | Punto lateral del arco (-1..1 del ancho util) que elige el joystick: donde su direccion cruza la linea de gol; si no la cruza dentro del arc |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/assistance/press_controller.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `PressController.reset()` | 29 |  |
| `PressController.update(defender: Footballer, ctx: MatchContext, stick_world: Vector3, stick_mag: float, dt: float)` | 32 |  |
| `PressController._project(vel: Vector3, t: float, decelerates: bool)` | 128 |  |
| `PressController.defender_pitch_clamp(ctx: MatchContext, p: Vector3)` | 136 |  |
| `PressController._find_carrier(ctx: MatchContext, ball: Ball, team: int, radius: float)` | 141 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/assistance/kick_model.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `KickModel.flat(v: Vector3)` | 32 |  |
| `KickModel.angle_between_deg(a: Vector3, b: Vector3)` | 35 |  |
| `KickModel.signed_angle_deg(from_dir: Vector3, to_dir: Vector3)` | 42 |  |
| `KickModel.rotate_toward(dir: Vector3, target_dir: Vector3, max_deg: float)` | 50 | Gira "dir" hacia "target_dir" como maximo max_deg grados (plano XZ). |
| `KickModel.gaussian_clipped(rng: RandomNumberGenerator, sigma: float, clip: float = 2.2)` | 55 |  |
| `KickModel.curl_spin(dir: Vector3, curl: float, spin_rad: float)` | 61 | Efecto lateral (chanfle): giro sobre el eje vertical que curva la pelota a la derecha (curl > 0) o a la izquierda del golpeo por el efecto M |
| `KickModel.curl_offset(dist: float, vh: float, curl: float, spin_rad: float)` | 66 | Desvio lateral (m) acumulado por el efecto al recorrer `dist` m a velocidad horizontal `vh` (con algo de arrastre). |
| `KickModel.curl_preaim_deg(dist: float, vh: float, curl: float, spin_rad: float)` | 73 | Angulo (grados, con signo para KickModel: positivo = izquierda) para abrir la salida y que la curva cierre sobre el objetivo. |
| `KickModel.balance_state(f: Footballer)` | 78 | 1.0 = totalmente equilibrado. Baja con giros bruscos, frenadas y cansancio. |
| `KickModel.misalignment(f: Footballer, dir: Vector3)` | 89 | Proporcion de desalineacion entre el cuerpo y la direccion del golpe (0..1). |
| `KickModel.kicks_with_right(f: Footballer, ball_pos: Vector3)` | 94 | True si golpea con el pie derecho: el del lado del cuerpo en el que esta la pelota. Con la pelota por delante del centro del cuerpo (a menos |
| `KickModel.is_weak_foot(f: Footballer, ball_pos: Vector3)` | 101 | True si el balon queda del lado del pie no dominante. |
| `KickModel.weak_foot_error_mult(f: Footballer)` | 105 | Penalizacion de la pierna debil segun el atributo (1.0 = sin penalizacion). |
| `KickModel.weak_foot_power_mult(f: Footballer)` | 108 |  |
| `KickModel.ground_speed_for_distance(d: float, arrival: float)` | 115 | Velocidad inicial (m/s) para recorrer d metros por el suelo y llegar con "arrival" m/s. Modelo de la pelota: desaceleracion = rodadura (Ball |
| `KickModel.lob_speed_for_distance(d: float, angle_deg: float)` | 133 | Velocidad de lanzamiento para un pase elevado que cubre d metros con el angulo dado (grados). |
<!-- /AUTO -->

## Recorrido de ejecución

Fórmulas tal como están en el código (2026-10-26). `asistencia` = nivel 0–1 (`Tuning.assist` o `Footballer.assist_override_*`); `carga` = 0–1.

**Pase** (`PassAssist.compute`, llamado por `BallHandler.perform_pass` en el instante de contacto):
1. Dirección de intención = joystick, o la orientación del cuerpo si el joystick está neutro.
2. Si `asistencia > 0`: cada compañero (`MatchContext.teammates_of`) a entre 1.2 m y `pass_max_distance`, dentro del cono (`pass_cone_deg × lerp(0.65, 1, asistencia)`, ×0.75 sin joystick), se puntúa: `w_ángulo·(1 − áng/cono) + w_distancia·clamp(1 − |dist − ideal|/(ideal + 6), 0, 1) + w_línea·línea_libre`, con `ideal = 4.5 + 13·carga` m. Gana el mayor (`PassAssist._lane_clearance` penaliza rivales a menos de `2·pass_lane_block_radius` de la línea).
3. Con compañero: punto de mira = posición + `velocidad × tiempo_de_vuelo × 0.85`; la dirección va al compañero con asistencia ≥ 0.6 (`PassAssist.FULL_AIM_LEVEL`; como en First Touch y Dream League) y, por debajo, se corrige `clamp(diff·asistencia/0.6, ±pass_max_correction_deg·asistencia)`. Sin compañero (**pase al espacio**): distancia = `lerp(6.0, 20.0, carga)` a lo largo de la intención, llegando a 1.5 m/s (mínimo 4 m/s), y **sin corrección**.
4. Fuerza: `power_mult = factor("long_pass" si dist > 11 m, si no "short_pass"; 0.12)`. Pase raso: `v0 = KickModel.ground_speed_for_distance(dist, llegada)` con `llegada = pass_arrival_speed` hacia un compañero o 0.8 m/s al espacio, `× lerp(1, driven_pass_extra, carga)` con compañero, limitado a `[pass_speed_min (1.6 al espacio), pass_speed_max·power_mult]`. Pase elevado (`lob`): `KickModel.lob_speed_for_distance(dist, lob_angle_deg)` limitado a `[6, 20·power_mult]`. Tipos resultantes: `driven` (carga > 0.45), `short`, `space`, `lob`.
5. Error: `σ = pass_error_deg·(1.45 − 0.9·precisión)·(0.6 + 0.4·√(dist/8))·(1 + 0.9·(1 − equilibrio))·(1 + 0.6·desalineación)·(1 + 0.5·(v/vmax)²)·(1 + 0.45·carga²)·lerp(1.1, 0.88, compostura)·(pierna débil)`; la desviación es gaussiana recortada (`KickModel.gaussian_clipped`) y la potencia lleva un ruido gaussiano de σ 2.5–5 % recortado a ±10 %.
6. Devuelve `KickModel.KickResult` (velocidad, giro de rodadura —o retroceso de 18 rad/s en el elevado—, objetivo, error aplicado, `sigma_deg`, `weak_foot`). `BallHandler` lo aplica con `Ball.kick`.

**Tiro** (`ShotAssist.compute`, desde `BallHandler.perform_shot`; rehecho el 2026-10-28 como el tiro asistido de PES/FIFA):
1. Tipo por la carga: **colocado** (carga < 0.3 a menos de 14 m), **potente** (carga > 0.8), **vaselina** (`lob`), **chanfle** (con `curl` ≠ 0, gesto del joystick) o normal.
2. Punto de mira **siempre dentro del arco**: el joystick elige el punto lateral (`ShotAssist._stick_lateral`: donde su dirección cruza la línea de gol; apuntando fuera, de lado o hacia atrás, el palo de ese lado) escalado por `ShotAssist.aim_edge` = `lerp(AIM_EDGE 0.85, 1.0, (precisión + definición)/2)` del ancho útil (`mitad_arco − shot_post_margin`): el buen tirador apunta más cerca del palo. Sin lado pedido: el colocado va al palo lejano (0.8), el resto al lado contrario al arquero (0.62). Altura: `0.88` en vaselina, si no `lerp(0.08, 0.5, carga·0.75)` (máx. 0.3 a menos de 4 m).
3. Dirección: la del joystick girada hacia el punto de mira por `peso = clamp(asistencia/ASSIST_FULL 0.4, 0, 1)` (asistencia 0 = manual, exactamente el joystick).
4. Potencia: `lerp(shot_speed_min, shot_speed_max, carga^SHOT_POWER_CURVE 1.5) × factor("shot_power", 0.14)` (colocado: al menos la de carga 0.25; × pierna débil; × `1 − SHOT_PRESSURE_POWER 0.12·presión`: con un rival encima no se arma bien el tiro), tope `shot_speed_max·1.2`. Desde el 2026-10-29 el tiro flojo sale a 12 m/s y el de carga completa a 30 (antes 9 y 27, lineal); el de media carga queda casi igual (~20 m/s a 0.6) para que el arquero siga atajando lo que va a su cuerpo.
5. Error horizontal: `σ = shot_error_deg·(1.5 − 0.9·precisión)·(1 + 0.9·carga²)·(1 + 0.8·(1 − equilibrio))·(1 + 0.7·desalineación)·(1 + 0.5·(v/vmax)²)·[dist < 10 m: lerp(1.15, 0.85, definición)]·lerp(1.1, 0.88, compostura)·(1 + SHOT_PRESSURE_ERROR 0.8·presión)·(colocado 0.72)·(pierna débil)`; vertical `σ·0.6`. Apuntar no es acertar: decide la ejecución.
6. Trayectoria: velocidad vertical = `lerp(por defecto, la necesaria para el punto de mira, asistencia·peso·0.9)`, limitada a `speed·sin(40°)`, más el error vertical (chanfle: al menos 3.4 m/s).
7. **Giro** (la física de la pelota hace la curva con su Magnus; ver «Efecto natural del golpeo» más abajo): vaselina con contragiro `LOB_BACKSPIN` 20; chanfle pedido `curl_spin` 38–58 rad/s con la salida abierta (`curl_preaim_deg`); potente sin giro (3 rad/s) con **flotado** (`KickResult.knuckle_*` → `Ball.set_knuckle`); el resto con **rosca natural hacia el lado del pie que golpea** (`KickModel.kicks_with_right`): empeine `NATURAL_CURL_MIN..MAX` 8–16 rad/s según cuánto cruza el tiro por delante del cuerpo, colocado `PLACED_CURL_SPIN` 26; por el aire (`vy ≥ CURL_AIR_VY` 2 m/s) la salida se abre lo justo para que la curva cierre en el punto de mira. A todo se suma el giro del golpe imperfecto (`−error·shot_spin_factor·0.25` sobre el eje vertical). `KickResult.on_target` es una predicción **sin arrastre** sobre la línea antes de abrir la salida.

**Presión** (`PressController.update`): botón mantenido; busca el punto de intercepción de la **pelota**, se contiene a distancia y deja que el joystick ajuste el ángulo sin cancelar la búsqueda.
  - **Modelo de error** (`KickModel`): ruido gaussiano acotado que depende de distancia, potencia, equilibrio, orientación, velocidad, pierna de golpeo y atributos.
- **Estado:** implementado y probado (sin compañeros reales en la escena de juego: las pruebas los crean).
- **Última verificación:** <!-- AUTO:verified -->
2026-11-11
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/assistance/assist_tuning.gd` | Recurso `AssistTuning` con niveles y límites de las tres asistencias | `AssistTuning.Level`, `AssistTuning.LEVEL_VALUES`, `AssistTuning.set_all_levels` | — |
| `scripts/assistance/pass_assist.gd` | Clase `PassAssist` (estática): candidato, dirección, fuerza y error del pase | `PassAssist.compute`, `PassAssist._lane_clearance` | `KickModel`, `MatchContext`, `BallTuning` |
| `scripts/assistance/shot_assist.gd` | Clase `ShotAssist` (estática): punto de mira, corrección, trayectoria y error del tiro | `ShotAssist.compute` | `Goal.aim_point`, `PitchConfig`, `BallTuning`, `MatchContext` |
| `scripts/assistance/press_controller.gd` | Clase `PressController` (`RefCounted` con estado): intercepción, contención y disputa | `PressController.update`, `PressController.PressOutput`, `PressController._project`, `PressController._find_carrier` | `KickModel`, `MatchContext`, `Tuning` |
| `scripts/assistance/kick_model.gd` | Clase `KickModel` (estática): ángulos en XZ, error, equilibrio, pierna débil, velocidad exacta para una distancia | `KickModel.KickResult`, `KickModel.balance_state`, `KickModel.ground_speed_for_distance`, `KickModel.lob_speed_for_distance` | `Footballer`, `BallTuning` |

**No modificar para cambiar la asistencia:** `ball_handler.gd` (solo llama a `compute` y aplica el resultado) ni `Ball`. **Quién llama:** `BallHandler.perform_pass` / `perform_shot` y `Footballer._physics_process` (presión).

## Mapa de parámetros

<!-- AUTO:params:AssistTuning -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `pass_assist` | `0.65` | 0.0, 1.0 | `scripts/assistance/assist_tuning.gd:16` | `scripts/ui/hud.gd:201`, `scripts/assistance/assist_tuning.gd:60`, `scripts/gameplay/tuning.gd:65`, `scripts/gameplay/tuning.gd:82` (+1) |  (Pase) |
| `pass_cone_deg` | `60.0` | float | `scripts/assistance/assist_tuning.gd:18` | `scripts/assistance/pass_assist.gd:15`, `scripts/assistance/pass_assist.gd:173` | Angulo maximo entre la direccion del joystick y un companero para considerarlo. (Pase) |
| `pass_fallback_cone_deg` | `85.0` | float | `scripts/assistance/assist_tuning.gd:20` | `scripts/assistance/pass_assist.gd:22` | Con asistencia media o alta, cono (grados) en el que se busca companero cuando ninguno cae en el normal. (Pase) |
| `pass_max_distance` | `24.0` | float | `scripts/assistance/assist_tuning.gd:22` | `scripts/assistance/pass_assist.gd:37`, `scripts/assistance/pass_assist.gd:177` | Alcance maximo de busqueda (m). (Pase) |
| `pass_max_correction_deg` | `30.0` | float | `scripts/assistance/assist_tuning.gd:25` | `scripts/assistance/pass_assist.gd:94`, `scripts/assistance/pass_assist.gd:221` | Correccion angular maxima (grados) por unidad de asistencia, con asistencia baja (con media o alta el pase va al companero elegido: PassAssist.FULL_AIM_LEVEL). (Pase) |
| `pass_weight_angle` | `1.0` | float | `scripts/assistance/assist_tuning.gd:26` | `scripts/assistance/pass_assist.gd:45` |  (Pase) |
| `pass_weight_distance` | `0.35` | float | `scripts/assistance/assist_tuning.gd:27` | `scripts/assistance/pass_assist.gd:45` |  (Pase) |
| `pass_weight_lane` | `0.8` | float | `scripts/assistance/assist_tuning.gd:28` | `scripts/assistance/pass_assist.gd:45` |  (Pase) |
| `pass_lane_block_radius` | `0.8` | float | `scripts/assistance/assist_tuning.gd:30` | `scripts/assistance/pass_assist.gd:44`, `scripts/assistance/pass_assist.gd:205` | Radio de un rival para bloquear la linea de pase. (Pase) |
| `pass_error_deg` | `2.6` | float | `scripts/assistance/assist_tuning.gd:32` | `scripts/assistance/pass_assist.gd:125`, `scripts/assistance/pass_assist.gd:264` | Error base de pase en grados (atributo de precision 50, 8 m). (Pase) |
| `shot_assist` | `0.55` | 0.0, 1.0 | `scripts/assistance/assist_tuning.gd:35` | `scripts/ui/hud.gd:202`, `scripts/assistance/assist_tuning.gd:61`, `scripts/gameplay/tuning.gd:66`, `scripts/gameplay/tuning.gd:83` (+1) |  (Tiro) |
| `shot_cone_deg` | `38.0` | float | `scripts/assistance/assist_tuning.gd:36` | **sin uso** |  (Tiro) |
| `shot_max_correction_deg` | `10.0` | float | `scripts/assistance/assist_tuning.gd:37` | **sin uso** |  (Tiro) |
| `shot_post_margin` | `0.28` | float | `scripts/assistance/assist_tuning.gd:39` | `scripts/assistance/shot_assist.gd:81`, `scripts/assistance/shot_assist.gd:105` | Margen (m) que se deja respecto a los postes al apuntar. (Tiro) |
| `shot_error_deg` | `2.2` | float | `scripts/assistance/assist_tuning.gd:40` | `scripts/assistance/shot_assist.gd:132` |  (Tiro) |
| `press_assist` | `0.7` | 0.0, 1.0 | `scripts/assistance/assist_tuning.gd:43` | `scripts/ui/hud.gd:203`, `scripts/assistance/assist_tuning.gd:62`, `scripts/assistance/press_controller.gd:113`, `scripts/gameplay/tuning.gd:67` (+1) |  (Presion defensiva) |
| `press_lookahead` | `0.55` | float | `scripts/assistance/assist_tuning.gd:45` | `scripts/assistance/press_controller.gd:67`, `scripts/assistance/press_controller.gd:68` | Segundos hacia delante para predecir la posicion de intercepcion. (Presion defensiva) |
| `press_standoff` | `1.4` | float | `scripts/assistance/assist_tuning.gd:47` | `scripts/assistance/press_controller.gd:79`, `scripts/assistance/press_controller.gd:108` | Distancia a la que el defensor se mantiene (m) antes de disputar. (Presion defensiva) |
| `press_tackle_range` | `0.90` | float | `scripts/assistance/assist_tuning.gd:49` | `scripts/assistance/press_controller.gd:121`, `scripts/assistance/press_controller.gd:122`, `scripts/player/player_actions.gd:425` | Distancia a la que se intenta quitar la pelota (m). (Presion defensiva) |
| `press_around_offset` | `0.30` | float | `scripts/assistance/assist_tuning.gd:51` | `scripts/assistance/press_controller.gd:87` | Cuanto rodea el defensor al portador para atacar la pelota por el lado libre (m mas alla de la pelota). (Presion defensiva) |
| `press_speed_factor` | `0.93` | float | `scripts/assistance/assist_tuning.gd:52` | `scripts/assistance/press_controller.gd:61` |  (Presion defensiva) |
| `press_stick_influence` | `0.55` | float | `scripts/assistance/assist_tuning.gd:54` | `scripts/assistance/press_controller.gd:96` | Cuanto influye el joystick (0..1) en el angulo de aproximacion. (Presion defensiva) |
| `press_tackle_cooldown` | `1.3` | float | `scripts/assistance/assist_tuning.gd:56` | `scripts/assistance/press_controller.gd:125` | Segundos de enfriamiento entre intentos de robo. (Presion defensiva) |
<!-- /AUTO -->

Niveles de la interfaz (`Hud._cycle_assist`): `AssistTuning.LEVEL_VALUES` = Desactivada 0.0, Baja 0.35, Media 0.65, Alta 0.95; se guardan en `user://settings.cfg` (`Tuning.save_user_settings`). `Footballer.assist_override_pass`/`assist_override_shot` (≥ 0) los sustituyen por jugador (usado por las pruebas).

### Qué hace cada ajuste (verificado en el código)

| Ajuste | Comportamiento real |
|---|---|
| `pass_assist` (0–1) | Escala el cono de búsqueda (`pass_cone_deg × lerp(0.65, 1, nivel)`, ×0.75 sin joystick; con nivel ≥ `PassAssist.FULL_AIM_LEVEL` = 0.6 y joystick, cono de respaldo `pass_fallback_cone_deg` si nadie cae en el normal) y la corrección: con nivel ≥ 0.6 el pase va **al compañero elegido** (solo queda el error de ejecución); por debajo, `diff × nivel/0.6` con tope `pass_max_correction_deg × nivel`. Con nivel 0 no se busca compañero ni se corrige. |
| `pass_weight_*` | Puntaje del candidato = `w_ángulo·(1 − áng/cono) + w_distancia·cercanía_a_la_distancia_ideal + w_línea·línea_libre`; la distancia ideal crece con la carga (`4.5 + 13·carga` m). |
| `shot_assist` (0–1) | La corrección es `diff × nivel × peso`, con tope `shot_max_correction_deg × nivel`; `peso` cae a 0 cuando el punto de impacto proyectado en la línea de gol queda fuera de los postes más un margen que depende de `shot_cone_deg` y de la distancia. Con intención centrada y nivel ≥ 0.4 sugiere el lado opuesto al arquero (factor 0.62 del ancho útil). |
| `press_assist` | **Solo** escala la intensidad del movimiento de presión (`× lerp(0.9, 1.0, nivel)`); con nivel 0 la presión **sigue funcionando** (el botón es una acción del usuario). |
| `press_standoff`, `press_lookahead` | Distancia de contención ante un portador y horizonte (×2) de la intercepción. |
| `press_speed_factor` | Fracción de la velocidad máxima de sprint con que se calcula la intercepción (`chase_speed`, mínimo 2.5 m/s). |
| `press_stick_influence` | Peso de la componente lateral del joystick (×1.2) sobre la dirección de búsqueda. |
| `press_tackle_range`, `press_tackle_cooldown` | Alcance y enfriamiento del intento de robo (`BallHandler.attempt_tackle`, cuya probabilidad depende del atributo `marking`, orientación, equilibrio, velocidad relativa y, del portador, `strength`/`balance`). |
| `pass_error_deg`, `shot_error_deg` | Desviación típica base (grados) antes de multiplicadores. |

## Mapa de funciones

<!-- AUTO:funcs:scripts/assistance/pass_assist.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `PassAssist.pick_target(kicker: Footballer, ctx: MatchContext, intent: Vector3, has_stick: bool, charge: float, assist_level: float)` | 11 | Pase asistido. El jugador apunta con el joystick; el sistema elige el companero que mejor coincide con esa INTENCION (direccion, distancia,  |
| `PassAssist._pick_in_cone(kicker: Footballer, ctx: MatchContext, intent: Vector3, charge: float, cone: float)` | 28 |  |
| `PassAssist.compute(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool, rng: RandomNumberGenerator, assist_level: float)` | 53 | Calcula un pase. stick_dir: direccion deseada en el mundo (o cero), charge: 0..1, lob: pase elevado. assist_level: 0 = sin ayuda ... 1 = max |
| `PassAssist.compute_through(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool, rng: RandomNumberGenerator, assist_level: float)` | 157 | Pase filtrado: la pelota va al ESPACIO por delante del desmarque del receptor (hacia el arco rival), buscando el hueco entre defensores. El  |
| `PassAssist._pass_sigma(kicker: Footballer, dir: Vector3, dist: float, charge: float)` | 260 | Desviacion tipica (grados) del error de un pase: precision, distancia, equilibrio, orientacion, velocidad, potencia y compostura. La compart |
| `PassAssist.pressure(kicker: Footballer)` | 275 | Presion rival sobre un jugador (0 = nadie cerca, 1 = rival encima): sube el error de pases, centros y tiros. |
| `PassAssist._space_ahead(p: Footballer, atk: Vector3, opponents: Array[Footballer])` | 285 | Metros libres por delante de un jugador (hacia el arco rival) antes del rival mas cercano a su carril. |
| `PassAssist._lane_clearance(from_pos: Vector3, to_pos: Vector3, opponents: Array[Footballer], block_radius: float)` | 295 | 1.0 = linea totalmente libre; baja cuanto mas cerca de la linea de pase este un rival. |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/assistance/shot_assist.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `ShotAssist.compute(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool, rng: RandomNumberGenerator, assist_level: float, curl: float = 0.0)` | 54 |  |
| `ShotAssist.aim_edge(kicker: Footballer)` | 233 | Fraccion del ancho util a la que apunta el joystick hacia un palo para este tirador (ver AIM_EDGE). |
| `ShotAssist._stick_lateral(intent: Vector3, origin: Vector3, goal: Goal, usable: float)` | 239 | Punto lateral del arco (-1..1 del ancho util) que elige el joystick: donde su direccion cruza la linea de gol; si no la cruza dentro del arc |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/assistance/press_controller.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `PressController.reset()` | 29 |  |
| `PressController.update(defender: Footballer, ctx: MatchContext, stick_world: Vector3, stick_mag: float, dt: float)` | 32 |  |
| `PressController._project(vel: Vector3, t: float, decelerates: bool)` | 128 |  |
| `PressController.defender_pitch_clamp(ctx: MatchContext, p: Vector3)` | 136 |  |
| `PressController._find_carrier(ctx: MatchContext, ball: Ball, team: int, radius: float)` | 141 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/assistance/kick_model.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `KickModel.flat(v: Vector3)` | 32 |  |
| `KickModel.angle_between_deg(a: Vector3, b: Vector3)` | 35 |  |
| `KickModel.signed_angle_deg(from_dir: Vector3, to_dir: Vector3)` | 42 |  |
| `KickModel.rotate_toward(dir: Vector3, target_dir: Vector3, max_deg: float)` | 50 | Gira "dir" hacia "target_dir" como maximo max_deg grados (plano XZ). |
| `KickModel.gaussian_clipped(rng: RandomNumberGenerator, sigma: float, clip: float = 2.2)` | 55 |  |
| `KickModel.curl_spin(dir: Vector3, curl: float, spin_rad: float)` | 61 | Efecto lateral (chanfle): giro sobre el eje vertical que curva la pelota a la derecha (curl > 0) o a la izquierda del golpeo por el efecto M |
| `KickModel.curl_offset(dist: float, vh: float, curl: float, spin_rad: float)` | 66 | Desvio lateral (m) acumulado por el efecto al recorrer `dist` m a velocidad horizontal `vh` (con algo de arrastre). |
| `KickModel.curl_preaim_deg(dist: float, vh: float, curl: float, spin_rad: float)` | 73 | Angulo (grados, con signo para KickModel: positivo = izquierda) para abrir la salida y que la curva cierre sobre el objetivo. |
| `KickModel.balance_state(f: Footballer)` | 78 | 1.0 = totalmente equilibrado. Baja con giros bruscos, frenadas y cansancio. |
| `KickModel.misalignment(f: Footballer, dir: Vector3)` | 89 | Proporcion de desalineacion entre el cuerpo y la direccion del golpe (0..1). |
| `KickModel.kicks_with_right(f: Footballer, ball_pos: Vector3)` | 94 | True si golpea con el pie derecho: el del lado del cuerpo en el que esta la pelota. Con la pelota por delante del centro del cuerpo (a menos |
| `KickModel.is_weak_foot(f: Footballer, ball_pos: Vector3)` | 101 | True si el balon queda del lado del pie no dominante. |
| `KickModel.weak_foot_error_mult(f: Footballer)` | 105 | Penalizacion de la pierna debil segun el atributo (1.0 = sin penalizacion). |
| `KickModel.weak_foot_power_mult(f: Footballer)` | 108 |  |
| `KickModel.ground_speed_for_distance(d: float, arrival: float)` | 115 | Velocidad inicial (m/s) para recorrer d metros por el suelo y llegar con "arrival" m/s. Modelo de la pelota: desaceleracion = rodadura (Ball |
| `KickModel.lob_speed_for_distance(d: float, angle_deg: float)` | 133 | Velocidad de lanzamiento para un pase elevado que cubre d metros con el angulo dado (grados). |
<!-- /AUTO -->

## Recorrido de ejecución

Fórmulas tal como están en el código (2026-10-26). `asistencia` = nivel 0–1 (`Tuning.assist` o `Footballer.assist_override_*`); `carga` = 0–1.

**Pase** (`PassAssist.compute`, llamado por `BallHandler.perform_pass` en el instante de contacto):
1. Dirección de intención = joystick, o la orientación del cuerpo si el joystick está neutro.
2. Si `asistencia > 0`: cada compañero (`MatchContext.teammates_of`) a entre 1.2 m y `pass_max_distance`, dentro del cono (`pass_cone_deg × lerp(0.65, 1, asistencia)`, ×0.75 sin joystick), se puntúa: `w_ángulo·(1 − áng/cono) + w_distancia·clamp(1 − |dist − ideal|/(ideal + 6), 0, 1) + w_línea·línea_libre`, con `ideal = 4.5 + 13·carga` m. Gana el mayor (`PassAssist._lane_clearance` penaliza rivales a menos de `2·pass_lane_block_radius` de la línea).
3. Con compañero: punto de mira = posición + `velocidad × tiempo_de_vuelo × 0.85`; la dirección va al compañero con asistencia ≥ 0.6 (`PassAssist.FULL_AIM_LEVEL`; como en First Touch y Dream League) y, por debajo, se corrige `clamp(diff·asistencia/0.6, ±pass_max_correction_deg·asistencia)`. Sin compañero (**pase al espacio**): distancia = `lerp(6.0, 20.0, carga)` a lo largo de la intención, llegando a 1.5 m/s (mínimo 4 m/s), y **sin corrección**.
4. Fuerza: `power_mult = factor("long_pass" si dist > 11 m, si no "short_pass"; 0.12)`. Pase raso: `v0 = KickModel.ground_speed_for_distance(dist, llegada)` con `llegada = pass_arrival_speed` hacia un compañero o 0.8 m/s al espacio, `× lerp(1, driven_pass_extra, carga)` con compañero, limitado a `[pass_speed_min (1.6 al espacio), pass_speed_max·power_mult]`. Pase elevado (`lob`): `KickModel.lob_speed_for_distance(dist, lob_angle_deg)` limitado a `[6, 20·power_mult]`. Tipos resultantes: `driven` (carga > 0.45), `short`, `space`, `lob`.
5. Error: `σ = pass_error_deg·(1.45 − 0.9·precisión)·(0.6 + 0.4·√(dist/8))·(1 + 0.9·(1 − equilibrio))·(1 + 0.6·desalineación)·(1 + 0.5·(v/vmax)²)·(1 + 0.45·carga²)·lerp(1.1, 0.88, compostura)·(pierna débil)`; la desviación es gaussiana recortada (`KickModel.gaussian_clipped`) y la potencia lleva un ruido gaussiano de σ 2.5–5 % recortado a ±10 %.
6. Devuelve `KickModel.KickResult` (velocidad, giro de rodadura —o retroceso de 18 rad/s en el elevado—, objetivo, error aplicado, `sigma_deg`, `weak_foot`). `BallHandler` lo aplica con `Ball.kick`.

**Tiro** (`ShotAssist.compute`, desde `BallHandler.perform_shot`):
1. Intención hacia el arco rival (`ctx.attacking_goal`). Se proyecta la intención sobre la línea de gol (`z_hit`); `peso = clamp(1 − exceso/max(extra, 0.2), 0, 1)` con `exceso = max(|z_hit| − (mitad_arco − shot_post_margin), 0)` y `extra = dist·tan(shot_cone_deg/2)·0.55`. Apuntar fuera del arco y de ese margen deja el peso en 0 (sin ayuda).
2. Punto de mira: `Goal.aim_point(lateral, altura, shot_post_margin)`. Con intención centrada (`|lateral| < 0.22`), `peso > 0` y asistencia ≥ 0.4, se sugiere el lado contrario al arquero (`lateral = ±0.62`); **hoy no hay arquero, así que el lado es aleatorio** (`rng`). Altura: `0.88` si es elevado, si no `lerp(0.08, 0.5, carga·0.75)` (máx. 0.3 a menos de 4 m).
3. Corrección: `clamp(diff·asistencia·peso, ±shot_max_correction_deg·asistencia)`.
4. Potencia: `lerp(shot_speed_min, shot_speed_max, carga) × factor("shot_power", 0.14)` (× pierna débil), tope `shot_speed_max·1.2` (versión antigua; la vigente, con `carga^1.5` y la presión, está en la sección de arriba).
5. Error horizontal: `σ = shot_error_deg·(1.5 − 0.9·precisión)·(1 + 0.9·carga²)·(1 + 0.8·(1 − equilibrio))·(1 + 0.7·desalineación)·(1 + 0.5·(v/vmax)²)·[si dist < 10 m: lerp(1.15, 0.85, finalización)]·lerp(1.1, 0.88, compostura)·(pierna débil)`; el error vertical usa `σ·0.6`.
6. Trayectoria: velocidad vertical = `lerp(por defecto, la necesaria para llegar al punto de mira, asistencia·peso·0.9)`, limitada a `speed·sin(40°)`, más el error vertical; `KickResult.on_target` es una predicción **sin arrastre**.

**Presión** (`PressController.update`, desde `Footballer._physics_process` mientras `press_held` y el equipo no tiene la pelota):
1. No hace nada si la pelota está sostenida (`Ball.is_held`) o si un compañero la controla.
2. Portador rival = el rival más cercano a la pelota dentro de `possession_radius` (se conserva el anterior mientras esté a < 1.5× ese radio).
3. Punto de intercepción: 3 iteraciones con `chase_speed = max(max_sprint_speed·press_speed_factor, 2.5)`, tiempo acotado a `2·press_lookahead`; la pelota suelta se proyecta con una deceleración fija de 1.1 m/s² (`PressController._project`).
4. Aproximación: contra un portador el punto se retrasa `0.6·press_standoff` a lo largo de la dirección del portador; a menos de `1.2·press_standoff` de la pelota va directo al punto de intercepción.
5. Joystick: añade solo la componente lateral (`press_stick_influence·1.2`); si la mezcla se desviara más de lo que permite (`dot < 0.35`) se atenúa a 0.8/0.2.
6. Velocidad: 1.0 si `dist > 5 m`, si no `clamp(0.4 + dist/6, 0.4, 1)`; 0.55 como máximo en contención (portador y pelota a < `1.2·press_standoff`); `× lerp(0.9, 1, press_assist)`; sprint si `dist > 6 m` y no agotado.
7. Intento de robo (`attempt_tackle`): pelota a ≤ `press_tackle_range`, sin enfriamiento, pelota a menos de 0.6 m de altura y el defensor mirándola (< 85°); luego `BallHandler.attempt_tackle` decide con probabilidad según `marking`, orientación, equilibrio, velocidad relativa y los atributos del portador.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh passing`, `tools/run_tests.sh shooting`, `tools/run_tests.sh press`.
- **Resultados medidos (2026-10-26, semillas fijas):** pase de 11 m con asistencia 0.65: 17/24 llegan frente a 0/24 sin asistencia; pase largo con precisión 15 y asistencia 0.95: 16/30 (la asistencia no garantiza); σ de pase 4.64° (atributos 10) vs 1.52° (atributos 100); pase al espacio por carga 0 / 0.5 / 1: 4.8 / 11.9 / 19.3 m (previstos 4.5 / 11.75 / 19); tiro con asistencia 0.55 desde 8.5 m sin arquero: 27/40 goles y 3 impactos en poste/travesaño; 40 duelos de presión con marcaje 50: 24 robos ganados / 47 intentos fallidos ejecutando solo `press` (repetido 3 veces, idéntico) y 22 / 48 dentro de la suite completa (ver «Reglas del marco» en [TESTING](TESTING.md)).

*Pruebas de test_passing: eliminadas en la reforma (modo de fútbol 5 quitado; en el historial de git).*

*Pruebas de test_shooting: eliminadas en la reforma (modo de fútbol 5 quitado; en el historial de git).*

<!-- AUTO:tests:tests/test_shot_keeper.gd -->
| Prueba | Línea |
|---|---|
| `test_shots_go_at_goal_and_the_keeper_saves_what_he_reaches` | 93 |
<!-- /AUTO -->

*Pruebas de test_press: eliminadas en la reforma (modo de fútbol 5 quitado; en el historial de git).*

- **Qué podría romperse:** asistencia que garantice el resultado (todas las pruebas de «no garantizada» fallarían); pases que no llegan a su distancia si se cambia la física de la pelota sin revisar `KickModel.ground_speed_for_distance`; presión que abandona la pelota al mover el joystick.

## Limitaciones conocidas

- La asistencia de pase solo se ejercita con compañeros creados en pruebas; en la escena de partido hay un único jugador por equipo.
- `Hud._cycle_assist` asigna los niveles con nombres de propiedad dinámicos (`"%s_assist" % kind`): una búsqueda por `pass_assist` no los encuentra.
- No hay amagues/regates ni pase filtrado diferenciado; el «pase al espacio» solo existe cuando no hay candidato.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Control asistido».

## Filtrado, centros, presión y efecto (2026-10-27)

- `PassAssist.compute_through`: receptor por intención, avance y espacio por delante; punto al espacio en la dirección de su carrera, en el hueco de mejor línea libre; llega a velocidad de carrera.
- `CrossAssist.compute`: zonas primer palo / segundo palo / punto de penal; elevado (34°, pasa a 1.7 m), tenso (15°, carga > 0.7) o raso (con ALTO). `launch_speed` resuelve la velocidad con la trayectoria predicha (con arrastre).
- `PassAssist.pressure`: un rival encima sube el error de pases, centros y tiros.
- `ShotAssist`: tiro **colocado** (carga < 0.3 cerca del arco: palo lejano, más lento y preciso) y **potente** (carga > 0.8). Con `curl` ≠ 0 tiro con **chanfle**: abre la salida `KickModel.curl_preaim_deg` y da giro lateral `KickModel.curl_spin`.

## Tiros dirigidos al arco, efecto natural del golpeo y arquero (2026-10-28)

Como en PES y FIFA con asistencia, el tiro va **siempre al arco**: el joystick solo elige el punto (palo derecho,
izquierdo o lejos del arquero) y la situación decide la calidad: carga, equilibrio, cuerpo de cara o de espaldas
(desalineación), velocidad, rival encima (×1.8 de error con presión 1), pierna débil, compostura y definición.

**Efecto natural del golpeo** (`ShotAssist.compute`, paso 7): con el empeine la pelota rosca hacia el lado del pie
(diestro: se cierra a la izquierda) y más cuanto más cruza el tiro por delante del cuerpo; el colocado (interior) rosca
más; el potente sale casi sin giro y «flota»; la vaselina lleva contragiro. Con la pelota justo delante del cuerpo
(< 5 cm del eje) golpea con el pie bueno (`KickModel.kicks_with_right`; antes decidía el ruido numérico y podía cargar la
penalización de pierna débil). Medido (`test_ball_curl`): 6/6 tiros de empeine roscan hacia el lado del pie en cada
pierna (curva media 0.09–0.11 m en 11 m, a 0.15–0.23 m del punto de mira); colocado: 0.49 m de curva, llega a 0.11 m del
punto; potente de 18 m: 3 rad/s y el flotado lo mueve 0.15 m.

**Arquero** (`test_shot_keeper`, 40 tiros físicos por caso —80 desde el 2026-10-29, ver el final de la sección— con su golpe, vuelo y clips; arquero y tirador de 60, las
paradas con el cuerpo cuentan como atajadas):

| Caso | Al arco | Goles | Ataja |
|---|---|---|---|
| 11 m, al palo derecho (el empeine derecho la cierra hacia el arquero) | 72 % | 6 | 79 % |
| 11 m, al palo izquierdo (el empeine derecho la aleja del arquero) | 90 % | 21 | 41 % |
| 11 m, al arquero | 95 % | 4 | 89 % |
| 11 m, rival encima | 65 % | 0 | 100 % |
| 18 m, potente (flotado) | 78 % | 9 | 70 % |
| 8 m, ángulo cerrado | 70 % | 4 | 85 % |
| 11 m, tirador de 85 al palo derecho | 82 % | 8 | 75 % |

Antes del efecto natural (giro del tiro anterior, mismo arquero): al palo 58 % de atajadas en los dos palos casi por
igual y el potente de 18 m siempre despejado. El arquero no lee el efecto (su predicción `BallPredictor` no tiene
Magnus) y replanifica cada 0.08 s: la curva que se aleja de él es la que le gana, como en el fútbol real.

Con el tiro más fuerte del 2026-10-29 (12–30 m/s con `carga^1.5`, presión que resta potencia) y **80 tiros por caso**
(con 40 la diferencia entre dos casos parecidos quedaba dentro del ruido):

| Caso | Al arco | Goles | Ataja |
|---|---|---|---|
| 11 m, al palo derecho | 79 % | 12 | 80 % |
| 11 m, al palo izquierdo | 90 % | 33 | 54 % |
| 11 m, al arquero | 98 % | 16 | 79 % |
| 11 m, rival encima | 70 % | 4 | 92 % |
| 18 m, potente (flotado) | 66 % | 4 | 92 % |
| 8 m, ángulo cerrado | 79 % | 8 | 87 % |
| 11 m, tirador de 85 al palo derecho | 78 % | 20 | 67 % |
| 11 m, tirador de 85 al palo izquierdo | 91 % | 45 | 38 % |

Con la potencia lineal 12–30 (probada antes de dejar la curva) el arquero atajaba solo el 63 % de los tiros a su cuerpo
desde 11 m y con un rival encima entraban más goles que sin él (16 frente a 12): por eso la curva y la presión.
