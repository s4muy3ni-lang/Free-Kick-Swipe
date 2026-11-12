# CAMERA — Cámara de partido

## Identificación

- **Responsabilidad exacta:** cámara de transmisión de costado, como la de PES (desde el 2026-10-28: 30° de inclinación, lente de 28° y 30–38 m; antes 52°, 42° y 16–27 m, casi cenital). Sigue una mezcla entre el jugador controlado y la pelota (con anticipación por velocidad de la pelota), amortigua posición y zoom de forma independiente de los FPS, mantiene un **yaw fijo** (el joystick siempre es relativo a la pantalla) y no baja de la altura de las paredes. También convierte vectores 2D de pantalla en direcciones de mundo (`screen_to_world_dir`). Desde el 2026-10-29: **zoom elegido por la persona** (`Tuning.camera_zoom`, botón «Zoom de cámara» del menú de pausa: Muy cerca 0.55 / Cerca 0.7 —por defecto— / Media 0.85 / Lejos 1.0, multiplica la distancia de todo el encuadre) y **golpe de cámara** en los tiros fuertes (`punch`: cierre de lente y sacudida breve que se desvanecen solos).
- **Estado:** implementado; **sin pruebas que comprueben su comportamiento**. *test_match_flow (eliminada en la reforma)* instancia `MatchScene` (que crea la cámara y la hace correr), pero ninguna aserción mira el encuadre ni `screen_to_world_dir`.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-12
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/camera/match_camera.gd` | Clase `MatchCamera` (`Camera3D`) | `MatchCamera._target_focus`, `MatchCamera._target_distance`, `MatchCamera._apply_transform`, `MatchCamera.screen_to_world_dir`, `MatchCamera.snap_to_target` | `PitchConfig` (límites y altura de paredes), `Tuning.pitch` |

**Quién la crea y la usa:** `MatchScene._ready` (la instancia, `camera.setup(ball, controlled, Tuning.pitch)`), `MatchContext.screen_to_world` (la consulta), `MatchScene._on_kickoff_requested` (`snap_to_target` en cada saque).

## Mapa de parámetros

<!-- AUTO:params:MatchCamera -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `pitch_deg` | `30.0` | float | `scripts/camera/match_camera.gd:13` | `scripts/camera/match_camera.gd:185` | Camara de transmision deportiva (de costado, como PES). Sigue una mezcla entre el jugador controlado y la pelota con amortiguacion exponencial (independiente de los FPS), ajusta el encuadre segun la separacion entre ambos y nunca entra en el volumen de las paredes. Mantiene un yaw fijo: el joystick siempre es relativo a la pantalla. Con el contexto del partido (ctx) el encuadre es dinamico: mas cerca que una vista general, se adelanta hacia donde ataca el equipo con la pelota y se abre lo justo para que las opciones de pase del poseedor sigan en cuadro. Encuadre de transmision como el de PES (video `videoplayback`): camara de costado, baja (30 grados) y lejos con lente cerrada; se ve el largo de la cancha de lado y el ancho entero, y los jugadores siguen grandes en el movil. Antes: 52 grados, 16 m y 42 grados de lente (casi cenital). |
| `view_fov` | `28.0` | float | `scripts/camera/match_camera.gd:14` | `scripts/camera/match_camera.gd:51`, `scripts/camera/match_camera.gd:110`, `scripts/camera/match_camera.gd:112` |  |
| `base_distance` | `30.0` | float | `scripts/camera/match_camera.gd:15` | `scripts/camera/match_camera.gd:58`, `scripts/camera/match_camera.gd:182` |  |
| `max_distance` | `38.0` | float | `scripts/camera/match_camera.gd:16` | `scripts/camera/match_camera.gd:182` |  |
| `attack_lead` | `2.5` | float | `scripts/camera/match_camera.gd:18` | `scripts/camera/match_camera.gd:133` | Metros que el foco se adelanta hacia el arco que ataca el equipo con la pelota (se ve el espacio por delante). |
| `button_bias` | `1.0` | float | `scripts/camera/match_camera.gd:20` | `scripts/camera/match_camera.gd:59`, `scripts/camera/match_camera.gd:177` | Desplazamiento lateral de la imagen (m): la jugada queda algo a la izquierda, lejos de los botones de accion. |
| `pass_options_in_frame` | `2` | int | `scripts/camera/match_camera.gd:22` | `scripts/camera/match_camera.gd:166` | Companeros del poseedor (los mas cercanos a la pelota) que el encuadre mantiene visibles como opciones de pase. |
| `pass_option_range` | `15.0` | float | `scripts/camera/match_camera.gd:24` | `scripts/camera/match_camera.gd:163` | Mas alla de esta distancia a la pelota (m) un companero no fuerza a abrir el plano. |
| `follow_halflife` | `0.22` | float | `scripts/camera/match_camera.gd:26` | `scripts/camera/match_camera.gd:89` | Semivida del suavizado de posicion (s). Mayor = camara mas lenta. |
| `zoom_halflife` | `0.55` | float | `scripts/camera/match_camera.gd:27` | `scripts/camera/match_camera.gd:90` |  |
| `ball_lead_time` | `0.28` | float | `scripts/camera/match_camera.gd:28` | `scripts/camera/match_camera.gd:124` |  |
| `focus_weight_with_ball` | `0.4` | float | `scripts/camera/match_camera.gd:29` | `scripts/camera/match_camera.gd:129` |  |
| `focus_weight_without_ball` | `0.72` | float | `scripts/camera/match_camera.gd:30` | `scripts/camera/match_camera.gd:129` |  |
| `zoom_scale` | `1.0` | float | `scripts/camera/match_camera.gd:32` | `scripts/camera/match_camera.gd:181` | Factor extra de distancia (lo usan las pruebas y herramientas; el de la persona es Tuning.camera_zoom). |
| `punch_fov_deg` | `2.2` | float | `scripts/camera/match_camera.gd:35` | `scripts/camera/match_camera.gd:112` | Golpe de camara en los tiros fuertes (punch): grados que se cierra la lente y metros de sacudida con punch = 1, y su semivida (s). Da peso al disparo en una pantalla de movil (prueba03: el tiro no se notaba). |
| `punch_shake_m` | `0.10` | float | `scripts/camera/match_camera.gd:36` | `scripts/camera/match_camera.gd:113` |  |
| `punch_halflife` | `0.09` | float | `scripts/camera/match_camera.gd:37` | `scripts/camera/match_camera.gd:115` |  |
| `ball` | `null` | Node3D | `scripts/camera/match_camera.gd:39` | `scripts/camera/match_camera.gd:62`, `scripts/camera/match_camera.gd:83`, `scripts/camera/match_camera.gd:120`, `scripts/camera/match_camera.gd:121` (+4) |  |
| `focus_actor` | `null` | Node3D | `scripts/camera/match_camera.gd:40` | `scripts/camera/match_camera.gd:63`, `scripts/camera/match_camera.gd:69`, `scripts/camera/match_camera.gd:126`, `scripts/camera/match_camera.gd:127` (+2) |  |
| `pitch_config` | `null` | PitchConfig | `scripts/camera/match_camera.gd:41` | `scripts/camera/match_camera.gd:56`, `scripts/camera/match_camera.gd:57`, `scripts/camera/match_camera.gd:65`, `scripts/camera/match_camera.gd:136` (+2) |  |
| `ctx` | `null` | MatchContext | `scripts/camera/match_camera.gd:43` | `scripts/gameplay/match_scene.gd:85`, `scripts/camera/match_camera.gd:143`, `scripts/camera/match_camera.gd:145`, `scripts/camera/match_camera.gd:160` | Contexto del partido (opcional): da el poseedor y sus companeros para el encuadre dinamico. |
| `_focus` | `Vector3.ZERO` | Vector3 | `scripts/camera/match_camera.gd:45` | `scripts/camera/match_camera.gd:72`, `scripts/camera/match_camera.gd:89`, `scripts/camera/match_camera.gd:187`, `scripts/camera/match_camera.gd:191` |  |
| `_distance` | `20.0` | float | `scripts/camera/match_camera.gd:46` | `scripts/camera/match_camera.gd:58`, `scripts/camera/match_camera.gd:73`, `scripts/camera/match_camera.gd:90`, `scripts/camera/match_camera.gd:186` |  |
| `_initialized` | `false` | bool | `scripts/camera/match_camera.gd:47` | `scripts/camera/match_camera.gd:75`, `scripts/camera/match_camera.gd:85` |  |
| `_punch` | `0.0` | float | `scripts/camera/match_camera.gd:48` | `scripts/camera/match_camera.gd:96`, `scripts/camera/match_camera.gd:108`, `scripts/camera/match_camera.gd:109`, `scripts/camera/match_camera.gd:112` (+2) |  |
<!-- /AUTO -->

Valores fijos (no son `@export`): `fov = view_fov` (28), `near = 0.5`, `far = 140`, `keep_aspect = KEEP_HEIGHT` (`_ready`); la cámara se mantiene a `pitch_cfg.wall_height + 2.0` de altura mínima; el foco se limita a `x ∈ ±(half_length − 8)` y `z ∈ ±0.55·half_width`; el zoom crece `0.55` por metro de separación jugador-pelota por encima de 7 m (`_target_distance`); «cerca de la pelota» = a menos de 3 m (`_target_focus`).

### Riesgos al modificar

| Parámetro | Efecto real y riesgo |
|---|---|
| `pitch_deg` (30°) / `view_fov` (28°) | Inclinación y lente. El joystick no cambia (`screen_to_world_dir` usa la dirección horizontal de la cámara, yaw fijo); con ángulos bajos la profundidad de la pantalla se comprime y el ancho entero de la cancha cabe. |
| `base_distance` (30) / `max_distance` (38) | Distancia al foco. Con la lente cerrada los jugadores miden ~70 px de alto a 720p (PES: ~45 px); más lejos = más pequeños (legibilidad en móvil). |
| `follow_halflife` (0.22 s) / `zoom_halflife` (0.55 s) | Semivida del suavizado. Menor = cámara más pegada (más movimiento); mayor = más retraso. |
| `ball_lead_time` (0.28 s) | Cuánto se adelanta el foco según la velocidad de la pelota. |
| `focus_weight_with_ball` (0.4) / `focus_weight_without_ball` (0.72) | `foco = jugador.lerp(pelota_adelantada, w)`: `w` es el peso de la **pelota** (0 = sigue solo al jugador, 1 = solo a la pelota). Con la pelota a menos de 3 m del jugador se usa 0.4; si no, 0.72. |
| `Tuning.camera_zoom` (0.7) / `zoom_scale` (1.0) | Factor de la distancia: el de la persona (se guarda en `user://settings.cfg`, sección `ui`, limitado a 0.4–1.2) por el de pruebas y herramientas. prueba03: con 1.0 los jugadores medían ~55 px de alto en el móvil (First Touch Soccer ~75 px); con 0.7 la distancia baja al 70 % y los jugadores se ven ~1.4 veces más grandes (proporción geométrica, no medido en el móvil). Menor = jugadores más grandes pero menos campo y opciones de pase a la vista. |
| `punch_fov_deg` (2.2°) / `punch_shake_m` (0.10 m) / `punch_halflife` (0.09 s) | Golpe de cámara con `punch = 1`: grados que se cierra la lente y metros de sacudida, que caen a la mitad cada semivida. Lo dispara `watch_shots` con cada golpe de un futbolista que deja la pelota a más de 16 m/s (fuerza `(v − 16)/14`, entre 0.3 y 1). Más grande marea en el móvil. |

## Mapa de funciones

<!-- AUTO:funcs:scripts/camera/match_camera.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `MatchCamera._ready()` | 50 |  |
| `MatchCamera.setup(ball_node: Node3D, actor: Node3D, cfg: PitchConfig = null)` | 61 |  |
| `MatchCamera.set_focus_actor(actor: Node3D)` | 68 |  |
| `MatchCamera.snap_to_target()` | 71 |  |
| `MatchCamera._process(delta: float)` | 77 |  |
| `MatchCamera._camera_step(delta: float)` | 82 |  |
| `MatchCamera.punch(strength: float)` | 95 | Golpe de camara (0..1): una sacudida breve y un cierre de lente que se desvanecen solos. Lo dispara un tiro fuerte. |
| `MatchCamera.watch_shots(b: Ball)` | 99 | Conecta el golpe de camara a los golpes de la pelota: solo los disparos de un jugador (no los rebotes ni el arquero). |
| `MatchCamera._on_ball_impulse(actor: Node, _dv: float, speed: float)` | 103 |  |
| `MatchCamera._apply_punch(delta: float)` | 107 |  |
| `MatchCamera._target_focus()` | 117 |  |
| `MatchCamera._possessor()` | 142 |  |
| `MatchCamera.frame_points()` | 149 | Puntos que deben quedar en cuadro: pelota, jugador enfocado y las opciones de pase mas cercanas del poseedor. |
| `MatchCamera._target_distance()` | 171 |  |
| `MatchCamera._apply_transform()` | 184 |  |
| `MatchCamera._damp_float(current_value: float, target: float, halflife: float, delta: float)` | 193 |  |
| `MatchCamera._damp_vec3(current_value: Vector3, target: Vector3, halflife: float, delta: float)` | 197 |  |
| `MatchCamera.screen_to_world_dir(v: Vector2)` | 202 | Convierte un vector 2D de pantalla (x derecha, y abajo) en direccion de mundo sobre el plano XZ. |
<!-- /AUTO -->

## Recorrido de ejecución

1. `MatchScene._ready` → `camera.setup(ball, controlled, Tuning.pitch)` → `snap_to_target`; `camera.watch_shots(ball)` conecta `Ball.impulse` al golpe de cámara.
2. Cada `_process`: `_target_focus` (pelota + velocidad XZ × `ball_lead_time`; si hay jugador, mezcla `a.lerp(lead_ball, w)`; `y = 0`; límites del campo) → `_damp_vec3` (suavizado exponencial por semivida) → `_target_distance` (× `Tuning.camera_zoom · zoom_scale`) → `_apply_transform` (`look_at_from_position` desde `foco + (0, sin p, cos p)·distancia`, con `y ≥ wall_height + 2`) → `_apply_punch` (lente `view_fov − punch·punch_fov_deg` y sacudida aleatoria en los ejes X/Y de la cámara; el siguiente `_apply_transform` la borra).
3. `screen_to_world_dir(v)`: `right·v.x + back·v.y` con los ejes X y Z de la cámara proyectados sobre el plano XZ y normalizados.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh match_flow` (instancia `MatchScene` y, con ella, la cámara; solo comprueba reglas de partido).
- **Última ejecución (2026-10-26):** suite completa 57 pruebas / 212 comprobaciones sin fallos.
- **Alcance real:** **no hay ninguna prueba del encuadre, del zoom, de los límites del foco ni de `screen_to_world_dir`**. Las demás suites usan `TestCase.make_match`, que **no crea cámara**: `MatchContext.screen_to_world` cae entonces a `Vector3(v.x, 0, v.y)`. El encuadre se valida solo visualmente con `tools/shot_runner.gd` (Xvfb).
- **Qué podría romperse (y ninguna prueba lo detectaría):** joystick que «no va hacia donde apunta» tras tocar `pitch_deg`/orientación; cámara que atraviesa paredes si cambian `PitchConfig.wall_height` o las luces. Tras cualquier cambio de cámara hay que mirar una captura (`tools/shot_runner.gd`).

## Limitaciones conocidas

- `MatchCamera.set_focus_actor` no tiene llamadores (preparado para el cambio de jugador, que no existe).
- El zoom es un factor fijo elegido en el menú (4 niveles), no un pellizco en pantalla.
- No hay un perfil de cámara para pantallas verticales (el juego está fijado a horizontal: `display/window/handheld/orientation=0`).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Base del juego».

## Encuadre de transmisión como PES (2026-10-28)

Del video `videoplayback` (partido de PES 2021 con la cámara «amplia» de transmisión, revisado entero): cámara de costado
y baja, lente cerrada, el largo de la cancha de lado y el ancho entero en pantalla, sigue a la pelota sin girar. Se
probaron tres encuadres renderizados en el partido (52°/42°/16 m —el anterior—, 34°/32°/24 m y 30°/28°/30 m) y se dejó
el último, el más parecido, con los jugadores aún grandes para el móvil.

## Zoom de la persona y golpe de cámara (2026-10-29)

prueba03 (video de la persona en el móvil): los jugadores medían ~55 px de alto, la pelota apenas se veía y el tiro «no
se notaba». Se añadió el zoom del menú de pausa (`Tuning.camera_zoom`, por defecto 0.7: la cámara a 21–27 m en vez de
30–38 m) y el golpe de cámara de los tiros fuertes (`MatchCamera.punch`, `watch_shots`). La estela más ancha de la
pelota y el sonido completan el tiro (ver BALL y AUDIO).
