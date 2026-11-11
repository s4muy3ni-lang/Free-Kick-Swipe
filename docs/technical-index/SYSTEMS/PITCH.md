# PITCH — Cancha, paredes y arcos

## Identificación

- **Responsabilidad exacta:** construir por código la cancha (por defecto, desde 2026-11-05, fútbol 7 de 50 × 30 m con arcos de 5 × 2 m, círculo central de 6 m, área y penal a 8 m; `PitchConfig.futsal()` da la de futsal de 40 × 20 con arcos de 3 × 2 que usan las pruebas de mecánica): superficie, líneas reglamentarias en **una sola malla**, paredes de contención con colisión, baranda visible, iluminación, elementos ambientales; y los **arcos** (postes y travesaño con colisión física, red visible de una malla, red absorbente, detección de gol).
- **Estado:** implementado. La opción `PitchConfig.boundary_mode` está **declarada pero ningún código la usa**: las paredes siempre se construyen (`OUT_OF_BOUNDS` no existe).
- **Última verificación:** <!-- AUTO:verified -->
2026-11-11
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos / nodos | Dependencias directas |
|---|---|---|---|
| `scripts/pitch/pitch.gd` | Clase `Pitch` (`Node3D`): `build(cfg)` crea piso, líneas, paredes, arcos, luz y ambiente | `Pitch.build`, `Pitch._build_floor`, `Pitch._build_lines`, `Pitch._build_walls`, `Pitch._build_goals`, `Pitch._build_lighting`, `Pitch._build_ambient`, clase interna `Pitch.LineBuilder` | `PitchConfig`, `Goal`, `MeshUtil`, `GraphicsSettings` |
| `scripts/pitch/goal.gd` | Clase `Goal`: marco, red de tela, colisiones de la red para jugadores, detección de gol | `Goal.setup`, `Goal._build_frame`, `Goal._build_net`, `Goal._physics_process`, `Goal.is_ball_in_goal`, `Goal.aim_point` | `PitchConfig`, `Ball`, `MeshUtil`, `GoalNet` |
| `scripts/pitch/goal_net.gd` | Clase `GoalNet`: red de tela (cuatro paños atados al marco) que la pelota abomba; la frena y vuelve con ondas | `GoalNet.setup`, `GoalNet._ball_contact`, `GoalNet._press`, `GoalNet._step`, `GoalNet.displacement_at` | `Ball` (`net_accel`, `net_contact`), `BallTuning` (`net_*`) |
| `scripts/pitch/pitch_config.gd` | Recurso `PitchConfig` con todas las medidas | ver «Mapa de parámetros» | — |
| `scripts/pitch/mesh_util.gd` | Utilidades de malla/cuerpos estáticos/materiales | `MeshUtil.add_box_body`, `MeshUtil.add_quad`, `MeshUtil.build_mesh` | — |
| `assets/pitch/court.gdshader` | Superficie de juego (franjas y ruido, sin texturas) | uniforms `color_a`, `color_b`, `stripe_width` | — |
| `assets/pitch/net.gdshader` | Rejilla de la red con antialiasing por derivadas | uniforms `net_color`, `cell`, `line_width` | — |

**No modificar para cambiar medidas:** las posiciones de saque (`MatchScene.kickoff_positions`) y el área de colisión del piso se derivan de la configuración, salvo los números fijos indicados abajo.

## Mapa de parámetros

<!-- AUTO:params:PitchConfig -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `length` | `50.0` | float | `scripts/pitch/pitch_config.gd:11` | `scripts/ai/ai_input.gd:663`, `scripts/ai/ai_input.gd:666`, `scripts/setpiece/stadium11.gd:79`, `scripts/setpiece/stadium11.gd:87` (+9) |  (Dimensiones) |
| `width` | `30.0` | float | `scripts/pitch/pitch_config.gd:12` | `scripts/ai/ai_input.gd:668`, `scripts/gameplay/match_scene.gd:92`, `scripts/setpiece/stadium11.gd:79`, `scripts/setpiece/stadium11.gd:87` (+10) |  (Dimensiones) |
| `goal_width` | `5.0` | float | `scripts/pitch/pitch_config.gd:15` | `scripts/pitch/goal.gd:57`, `scripts/pitch/goal.gd:113`, `scripts/pitch/goal.gd:116`, `scripts/pitch/pitch_config.gd:98` |  (Arco) |
| `goal_height` | `2.0` | float | `scripts/pitch/pitch_config.gd:16` | `scripts/assistance/shot_assist.gd:229`, `scripts/gameplay/match_manager.gd:200`, `scripts/goalkeeper/goalkeeper.gd:367`, `scripts/pitch/goal.gd:52` (+6) |  (Arco) |
| `goal_depth` | `1.0` | float | `scripts/pitch/pitch_config.gd:17` | `scripts/pitch/goal.gd:89`, `scripts/pitch/pitch.gd:259`, `scripts/pitch/pitch.gd:260` |  (Arco) |
| `goal_top_depth` | `-1.0` | float | `scripts/pitch/pitch_config.gd:20` | `scripts/pitch/goal.gd:99`, `scripts/pitch/goal.gd:104`, `scripts/pitch/goal.gd:105`, `scripts/pitch/goal.gd:106` | Profundidad del techo de la red (m). < 0: red en forma de caja (fondo vertical a goal_depth). Entre 0 y goal_depth: red de futbol 11 (fondo inclinado desde el techo hasta el piso, con soportes detras del arco). (Arco) |
| `goal_net_sag` | `0.0` | float | `scripts/pitch/pitch_config.gd:22` | `scripts/pitch/goal.gd:99` | Caida de reposo de la red (0 = tensa, la de siempre; 1 = cuelga como una red real de futbol 11). (Arco) |
| `goal_supports` | `0` | int | `scripts/pitch/pitch_config.gd:25` | `scripts/pitch/goal.gd:105`, `scripts/pitch/goal.gd:107` | Estructura detras del arco: 0 ninguna, 1 soportes de la red inclinada (barra superior y tirantes), 2 caños en el piso (red de caja, como la de los estadios). (Arco) |
| `goal_net_cloth` | `false` | bool | `scripts/pitch/pitch_config.gd:27` | `scripts/pitch/goal.gd:97`, `scripts/pitch/goal.gd:100` | Red de tela (ClothNet: nodos, hilos y gravedad) como red visible; la membrana (GoalNet) sigue frenando la pelota. (Arco) |
| `post_radius` | `0.04` | float | `scripts/pitch/pitch_config.gd:28` | `scripts/gameplay/match_manager.gd:200`, `scripts/pitch/goal.gd:51`, `scripts/pitch/goal.gd:133`, `scripts/pitch/pitch.gd:242` (+2) |  (Arco) |
| `line_width` | `0.08` | float | `scripts/pitch/pitch_config.gd:31` | `scripts/setpiece/stadium11.gd:112`, `scripts/pitch/pitch.gd:172`, `scripts/pitch/pitch.gd:173`, `scripts/pitch/pitch.gd:174` (+6) |  (Marcas) |
| `center_circle_radius` | `6.0` | float | `scripts/pitch/pitch_config.gd:32` | `scripts/pitch/pitch.gd:182` |  (Marcas) |
| `penalty_area_radius` | `8.0` | float | `scripts/pitch/pitch_config.gd:34` | `scripts/ai/ai_input.gd:387`, `scripts/gameplay/match_manager.gd:228`, `scripts/gameplay/match_scene.gd:410`, `scripts/goalkeeper/goalkeeper.gd:563` (+1) | Radio de los cuartos de circulo del area de penal (desde cada poste). (Marcas) |
| `penalty_mark_distance` | `8.0` | float | `scripts/pitch/pitch_config.gd:35` | `scripts/dev/anim_bank_bench.gd:250`, `scripts/assistance/cross_assist.gd:30`, `scripts/gameplay/match_manager.gd:219`, `scripts/gameplay/match_scene.gd:398` (+1) |  (Marcas) |
| `second_penalty_mark_distance` | `12.0` | float | `scripts/pitch/pitch_config.gd:37` | `scripts/pitch/pitch.gd:199` | Segundo punto penal (reglamento futsal, falta acumulada; en la cancha de futbol 7 solo se dibuja). (Marcas) |
| `corner_arc_radius` | `0.25` | float | `scripts/pitch/pitch_config.gd:38` | `scripts/pitch/pitch.gd:205` |  (Marcas) |
| `substitution_zone_length` | `5.0` | float | `scripts/pitch/pitch_config.gd:39` | `scripts/pitch/pitch.gd:203` |  (Marcas) |
| `boundary_mode` | `BoundaryMode.WALLS` | BoundaryMode | `scripts/pitch/pitch_config.gd:42` | `scripts/gameplay/match_manager.gd:185`, `scripts/gameplay/match_scene.gd:72`, `scripts/player/player_actions.gd:806`, `scripts/pitch/pitch.gd:226` |  (Entorno) |
| `wall_height` | `3.0` | float | `scripts/pitch/pitch_config.gd:44` | `scripts/camera/match_camera.gd:189`, `scripts/pitch/pitch.gd:223` | Altura de las paredes que mantienen la pelota en juego. (Entorno) |
| `barrier_visible_height` | `1.0` | float | `scripts/pitch/pitch_config.gd:46` | `scripts/pitch/pitch.gd:264` | Altura visible de la valla/baranda (el resto es colision invisible). (Entorno) |
| `run_off` | `2.5` | float | `scripts/pitch/pitch_config.gd:47` | `scripts/player/player_actions.gd:806`, `scripts/pitch/pitch.gd:73`, `scripts/pitch/pitch.gd:74`, `scripts/pitch/pitch.gd:227` |  (Entorno) |
<!-- /AUTO -->

### Receta: «quiero cambiar el tamaño del arco» (consumidores verificados con búsqueda en el código)

Cambiar `PitchConfig.goal_width`, `goal_height`, `goal_depth` o `post_radius` (en `scripts/pitch/pitch_config.gd`) afecta a, y **solo** a:

| Consumidor | Qué usa |
|---|---|
| `Goal._build_frame` | posición/altura de postes y longitud del travesaño |
| `Goal._build_net` | malla de la red, colisiones `net_surface` y `Area3D` del volumen de red |
| `Goal.is_ball_in_goal` | regla de gol: `|z| ≤ half_goal`, `y ≤ goal_height` |
| `Goal.aim_point` | punto de mira dentro del arco (lo usa `ShotAssist`) |
| `Pitch._build_walls` | hueco de la pared de fondo (`half_goal + 2·post_radius`) y dintel sobre el arco (usa `goal_height`, `goal_depth`) |
| `Pitch._build_lines` | arcos del área de penal centrados en los postes (usa `half_goal`) |
| `ShotAssist.compute` | zona útil del arco y predicción de «a puerta» |

Quedan **fijos en el código** (no derivan del tamaño): `MatchScene.kickoff_positions` (±1.4, ±6, ±11 m), `Goal.is_ball_in_goal` exige además que el centro esté ≥ un radio de pelota tras la línea. Verificar con `tools/run_tests.sh ball_physics`, `tools/run_tests.sh shooting` y `tools/run_tests.sh match_flow`; las pruebas leen `Tuning.pitch`, así que se adaptan a medidas nuevas.

## Mapa de funciones

<!-- AUTO:funcs:scripts/pitch/pitch.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Pitch._ready()` | 19 |  |
| `Pitch.build(cfg: PitchConfig)` | 23 |  |
| `Pitch._clear()` | 33 |  |
| `Pitch.set_ball(ball: Ball)` | 38 |  |
| `Pitch.get_goal(side: int)` | 42 |  |
| `Pitch.reset_goal_latches()` | 45 |  |
| `Pitch.contains_xz(p: Vector3, margin: float = 0.0)` | 50 | Devuelve true si un punto XZ esta dentro de la superficie de juego (con margen opcional). |
| `Pitch.clamp_to_pitch(p: Vector3, margin: float = 0.3)` | 53 |  |
| `Pitch._build_floor()` | 61 |  |
| `Pitch.LineBuilder._p(x: float, z: float)` | 115 |  |
| `Pitch.LineBuilder.segment(x0: float, z0: float, x1: float, z1: float)` | 118 |  |
| `Pitch.LineBuilder._quad(a: Vector3, b: Vector3, c: Vector3, e: Vector3)` | 131 |  |
| `Pitch.LineBuilder.arc(cx: float, cz: float, r: float, a0: float, a1: float, segments: int)` | 145 | Arco de circunferencia (angulos en radianes, medidos desde +X hacia +Z). |
| `Pitch.LineBuilder.disc(cx: float, cz: float, r: float, segments: int = 14)` | 156 |  |
| `Pitch._build_lines()` | 169 |  |
| `Pitch._build_walls()` | 220 |  |
| `Pitch._add_visual_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material)` | 280 |  |
| `Pitch._build_goals()` | 292 |  |
| `Pitch._build_lighting()` | 302 |  |
| `Pitch._build_ambient()` | 332 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/pitch/goal.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Goal.setup(cfg: PitchConfig, goal_side: int)` | 23 |  |
| `Goal.set_ball(b: Ball)` | 33 |  |
| `Goal.reset_latch()` | 43 |  |
| `Goal._build_frame()` | 50 |  |
| `Goal._add_frame_piece(pos: Vector3, shape: CylinderShape3D, r: float, h: float, horizontal: bool)` | 59 |  |
| `Goal._build_net()` | 88 |  |
| `Goal._build_net_supports(d: float, top: float, h: float, hw: float)` | 121 | Soportes de la red de futbol 11 (solo visuales): barra superior trasera, brazos desde el travesano y tirantes inclinados hasta el piso, en g |
| `Goal._build_ground_frame(d: float, hw: float)` | 132 | Arco de caja (como los de estadio): caños blancos en el piso a los costados y al fondo, donde se ata la red. |
| `Goal._support_bar(a: Vector3, b: Vector3, r: float, mat: Material)` | 138 |  |
| `Goal._physics_process(_delta: float)` | 161 |  |
| `Goal._goal_step(_delta: float)` | 166 |  |
| `Goal._track_mouth(lp: Vector3)` | 189 |  |
| `Goal.is_goal_now()` | 204 | Gol ahora mismo: la pelota esta dentro del arco y entro por la boca del arco. |
| `Goal.is_ball_in_goal(local_ball_pos: Vector3)` | 212 | La pelota cuenta como gol cuando su centro esta al menos un radio detras de la linea (cruzo completamente) y dentro del marco (entre postes  |
| `Goal.goal_center_world()` | 220 |  |
| `Goal.aim_point(lateral: float, height_ratio: float, margin: float)` | 225 | Punto objetivo dentro del arco. lateral: -1..1 (a lo largo de la linea, en el eje mundial Z), height: 0..1 de la altura util. |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/pitch/pitch.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `Pitch.goal_scored(goal: Goal, ball_position: Vector3)` | 9 | Cancha de futsal / futbol 5. Se construye proceduralmente a partir de PitchConfig: superficie, lineas reglamentarias (una sola malla), paredes de contencion, arcos con redes, iluminacion deportiva y elementos ambientales opcionales.  Ejes: X = largo (arcos en x = +-length/2), Z = ancho, Y = arriba. |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/pitch/goal.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `Goal.goal_scored(goal: Goal, ball_position: Vector3)` | 8 | Arco: postes y travesano con colision fisica (rebotes reales), red de tela que frena la pelota (GoalNet), colisiones simples de la red para los jugadores y deteccion de gol cuando la pelota cruza COMPLETAMENTE la linea.  Marco local: +X apunta hacia afuera del campo (detras del arco), +Y arriba, Z lateral. |
<!-- /AUTO -->

## Recorrido de ejecución

1. `MatchScene._ready` crea `Pitch` y llama `Pitch.build(Tuning.pitch)` (también lo hace `Pitch._ready` si no se construyó antes).
2. `Pitch.build`: `_build_floor` (cuerpo estático con material `friction 0.8 / bounce 0.0`, plano con `court.gdshader`, zona exterior) → `_build_lines` (todos los trazos en una `ArrayMesh`, elevada 2.5 cm) → `_build_walls` (paredes laterales, fondos con hueco para el arco, dintel, baranda visible) → `_build_goals` (un `Goal` por lado, `side = ±1`) → `_build_lighting` (sol direccional en el grupo `sun_light`, `Environment`) → `_build_ambient` (bancos, gradas, torres de luz; se oculta según `GraphicsSettings.ambient_props_enabled`).
3. `Pitch.set_ball(ball)` entrega la pelota a cada `Goal`.
4. Cada paso de física `Goal._physics_process` convierte la posición de la pelota al marco local del arco y, si `is_ball_in_goal`, emite `goal_scored` una vez (cerrojo `_latched`, que se libera cuando la pelota vuelve a estar más de 0.5 m delante de la línea o con `reset_latch`). `Pitch` reenvía la señal; `MatchManager._on_goal` la consume.
5. La red (`GoalNet`, desde el 2026-10-28): cuatro paños (fondo, techo y laterales) con los bordes atados al marco, cada uno una membrana de nodos cada 0.2 m. En su `_physics_process` (antes del paso de física) mira si la pelota llega a un paño (por dentro o por fuera, también si llega durante el paso), abomba la tela con su forma (campana de 0.28 m) y deja en `Ball.net_accel` la aceleración de la tela: muelle amortiguado integrado de forma implícita (`BallTuning.net_stiffness`, más rígido junto al marco), que mientras la pelota entra como mucho la para; al devolverla empuja con `net_return` (5 %) de la rigidez, y apoyada con el 30 % (el techo cede ~5 cm). La pelota que tocó la red por dentro y sigue en el arco se frena (la tela la enreda). Las cajas `net_surface` siguen para jugadores y arqueros; la pelota no las ve (excepción de colisión en `Goal.set_ball`). Sin pelota en la tela y con la red quieta no calcula nada (0.09 ms por paso de tela y 0.17 ms de malla mientras se mueve, escritorio).
6. Gol: centro de la pelota un radio detrás de la línea, entre postes y **entera bajo el travesaño** (`y ≤ alto − radio`): una pelota sobre el techo, que cede con su peso, no es gol.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh ball_physics` (gol, línea, postes, travesaño, paredes), `tools/run_tests.sh goal_net` (red de tela) y `tools/run_tests.sh match_flow` (gol → marcador).
- **Red de tela medida (`test_goal_net`):** raso a 15 m/s: llega a 1.12 m detrás de la línea (fondo a 1.0), red abombada 0.26 m, vuelve a 1.8 m/s (11 %); a media altura a 25 m/s: 1.44 m, 0.68 m, 2.3 m/s (9 %); potente al ángulo a 30 m/s: 1.46 m, 0.58 m, 2.6 m/s (8 %); en los tres queda dentro del arco y la red vuelve al reposo. Red lateral por fuera: se hunde 0.11 m y la pelota queda fuera; pelota sobre el techo: cede 0.15 m y la sostiene. Revisión visual: `tools/net_view.tscn` (`NET_CAM=lado`).
- **Comprobación visual (renderizado por software):** `tools/shot_runner.gd` (ver [TOOLS_AND_ASSETS](TOOLS_AND_ASSETS.md)); la cancha se vio correcta en capturas del 2026-10-26 (círculo central, áreas, arcos con red, baranda, gradas).
- **Qué podría romperse:** colisiones de paredes (la pelota saldría del campo), gol doble (cerrojo), hueco de pared de fondo desalineado con los postes, altura del dintel.

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

## Limitaciones conocidas

- `PitchConfig.boundary_mode` sin efecto (ver arriba); no hay saques de banda/esquina/falta: la pelota rebota siempre en las paredes.
- Sin bancos/gradas con colisión; son meramente visuales.
- Rendimiento de la cancha no medido en un dispositivo (solo renderizado por software en el entorno de desarrollo).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Base física» (cancha, arcos, red absorbente).

## Red de tela (2026-10-28)

Pedido: «física a la red para que los tiros se sientan más satisfactorios y realistas: tela que frena la pelota y se
mueve». Antes la red era una malla fija: al tocar una caja `net_surface` la pelota perdía el 88 % de la velocidad de golpe
y dentro del volumen del arco se amortiguaba (7/s) aunque no tocara nada. Ahora la red es tela (`GoalNet`, arriba): se
abomba con la pelota hasta ~0.6 m, la frena en ~0.05–0.1 s, casi no la devuelve y vuelve con ondas. Parámetros de juego en
`BallTuning` (`net_stiffness`, `net_damp_in`, `net_damp_out`, `net_return`, `net_grip`, `net_max_bulge`); de la tela visual,
constantes de `GoalNet`.
