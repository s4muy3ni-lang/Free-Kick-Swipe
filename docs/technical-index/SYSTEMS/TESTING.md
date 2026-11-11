# TESTING — Marco de pruebas headless y suites

## Identificación

- **Responsabilidad exacta:** verificar la simulación (física de la pelota, locomoción, conducción, pases, tiros, presión, patada sincronizada, reglas de partido, controles táctiles, modelo) **sin pantalla ni dependencias externas**, con un marco propio de ~150 líneas. Cada método `test_*` de una subclase de `TestCase` es una prueba.
- **Estado:** operativo. **Última ejecución completa (2026-10-26):** headless con las librerías del pack: **121 pruebas, 0 fallidas, 2 omitidas (necesitan render), 686 comprobaciones, 0 `SCRIPT ERROR`, ~92 s**. Con render (`xvfb-run`, por filtro): `gameplay_feel` 10/33, `control_and_keeper` 7/26, `goalkeeper` 5/25, `pack_motion` 2/24, `player_actions` 4/13, `practice` 4/37, todas 0 fallidas y 0 omitidas. La suite completa con render **no se terminó**: *test_ai_match (eliminada en la reforma)* simula partidos de 120 s con 10 personajes animados y con `llvmpipe` tarda decenas de minutos. **Sin** las librerías del pack: las pruebas del pack, arquero, práctica, sensación de juego e IA se omiten.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-11
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes |
|---|---|---|
| `tools/run_tests.sh` | Punto de entrada: reimporta el proyecto, ejecuta la escena de pruebas con `--headless --fixed-fps 60`, quita colores ANSI y **falla si la salida contiene `SCRIPT ERROR`** | `GODOT_BIN` (por defecto `godot`), filtro opcional por nombre de archivo |
| `tests/run_tests.tscn` + `tests/run_tests.gd` | Escena y ejecutor: descubre `tests/test_*.gd`, ejecuta cada `test_*` (con `await`), cuenta comprobaciones y sale con código 1 si hay fallos | `--filter <subcadena>` |
| `tests/test_case.gd` | Clase base `TestCase` | `check`, `check_near`, `note`, `physics_frames`, `wait_seconds`, `spawn`, `cleanup`, `make_world`, `make_match`, `add_player` |

## Reglas del marco (verificadas en el código)

- **Pruebas omitidas** (`TestCase.skip(motivo)`): se muestran como `[SKIP]` y se cuentan aparte; **no cuentan como aprobadas ni como comprobaciones**. Se usan cuando falta un recurso restringido que no se versiona (la librería local del pack, ver [ANIMATION_PACK](ANIMATION_PACK.md)) o cuando hace falta render (`DisplayServer` = headless no anima el esqueleto). `TestCase.cleanup()` restaura los interruptores globales (`FootballerVisual.prefer_pack`, `BallHandler.clip_kicks_enabled`).
- **Con render:** `xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter <nombre>` (la suite completa tarda ~4 min por `llvmpipe`); `tests/test_pack_motion.gd` mide el esqueleto realmente animado.
- **Cancha de las pruebas** (desde 2026-11-05): el juego usa la de fútbol 7 (50 × 30, arcos de 5 m) pero las pruebas
  se escribieron con posiciones fijas para la de futsal (40 × 20, arcos de 3 m). `run_tests.gd` llama
  `TestCase.begin()` antes de cada prueba (pone `Tuning.pitch = PitchConfig.futsal()`) y `end()` después (devuelve la
  del juego); una prueba que quiere la cancha real llama `use_game_pitch()` (p. ej.
  *test_ai_match::test_ai_match_on_the_game_pitch (eliminada en la reforma)*).
- Las lambdas de GDScript capturan las variables **por valor**: para que una señal escriba en una variable local se usa un `Dictionary`/`Array`.
- Una prueba que ejecuta **0 comprobaciones se considera FALLIDA** (`run_tests.gd`).
- Un error de script **a mitad** de una prueba aborta su cuerpo pero el ejecutor la cuenta como correcta si ya hizo ≥ 1 comprobación. Por eso `tools/run_tests.sh` busca `SCRIPT ERROR` en la salida y devuelve 1. **Si se ejecuta Godot directamente (sin el script), esa protección no existe.** (Corrección del 2026-10-26: test_animation_tree_responds_to_speed (borrado: Mixamo/Mocap) lanzaba un `SCRIPT ERROR` por leer `parameters/TimeScale/scale` — el nodo real se llama `LocoScale` — y figuraba como correcta con 1 comprobación.)
- La ventana de pruebas se fija en 1280×720 (los controles táctiles se posicionan respecto a ella).
- Determinismo: `BallHandler.rng.seed` se fija en `TestCase.add_player` (`12345 + id`); la física de Jolt corre a 60 Hz con `--fixed-fps 60`.
- `TestCase.make_match` crea cancha + pelota + `MatchContext` **sin cámara ni `MatchManager`**; `add_player(..., with_visual=false)` crea el futbolista sin modelo.
- **El aislamiento no es total:** una misma prueba puede dar mediciones distintas ejecutada sola o dentro de la suite completa (verificado con los duelos de presión: 24 robos / 47 fallos solo con `press`, 22 / 48 en la suite completa; las cotas de aceptación son lo bastante amplias para pasar en ambos casos). Para comparar mediciones antes y después de un cambio, usar siempre el mismo modo de ejecución.
- Las pruebas escriben mediciones con `note()` (líneas `·` en la salida); esas cifras son las que citan las fichas.

## Suites (medido el 2026-10-26)

| Archivo | Pruebas | Comprobaciones | Sistema | Ficha |
|---|---|---|---|---|
| `tests/test_ball_physics.gd` | 9 | 24 | Pelota (rebote, rodadura, arrastre, Magnus, red, estado serializable) | [BALL](BALL.md) |
| `tests/test_locomotion.gd` | 6 | 18 | Locomoción (aceleración, giro, frenada, sprint, paredes) | [PLAYER](PLAYER.md) |
| *tests/test_dribbling.gd (eliminada en la reforma; en el historial de git)* | 6 | 14 | Conducción y toques | [PLAYER](PLAYER.md) |
| `tests/test_kick_timing.gd` | 3 | 15 | Contacto sincronizado y curvas de la patada | [PLAYER](PLAYER.md), [ANIMATIONS](ANIMATIONS.md) |
| *tests/test_passing.gd (eliminada en la reforma; en el historial de git)* | 8 | 27 | Pase asistido y error por atributos | [ASSISTANCE](ASSISTANCE.md) |
| *tests/test_shooting.gd (eliminada en la reforma; en el historial de git)* | 6 | 16 | Tiro asistido | [ASSISTANCE](ASSISTANCE.md) |
| *tests/test_press.gd (eliminada en la reforma; en el historial de git)* | 5 | 14 | Presión y robo | [ASSISTANCE](ASSISTANCE.md) |
| *tests/test_match_flow.gd (eliminada en la reforma; en el historial de git)* | 7 | 31 | Reglas del partido (saque, gol, gol en contra, reinicio, pausa, fin) | [MATCH](MATCH.md) |
| *tests/test_touch_controls.gd (eliminada en la reforma; en el historial de git)* | 4 | 20 | Controles táctiles | [INPUTS](INPUTS.md), [UI_HUD](UI_HUD.md) |
| tests/test_player_model.gd (borrado: Mixamo/Mocap) | 4 | 36 | Modelo, esqueleto, clips, kit | [ANIMATIONS](ANIMATIONS.md) |
| tests/test_pack_retarget.gd (borrado: Mixamo/Mocap) | 6 | 100 | Retarget del pack: pistas limpias, orientación, pies en el suelo, velocidades naturales, contactos medidos | [ANIMATION_PACK](ANIMATION_PACK.md) |
| tests/test_pack_locomotion.gd (borrado: Mixamo/Mocap) | 4 | 71 | Marcha del pack, respaldo de Tripo, catálogo único, acciones sin solaparse | [ANIMATION_PACK](ANIMATION_PACK.md) |
| tests/test_pack_kick.gd (borrado: Mixamo/Mocap) | 8 | 105 | Contacto pie–pelota con clips: sincronía, fuera de alcance, patada en falso, ajuste de zancada, instante por trayectoria | [PLAYER](PLAYER.md) |
| *tests/test_pack_dribble_metrics.gd (eliminada en la reforma; en el historial de git)* | 2 | 23 | Métricas de conducción y ejecución de pase/tiro a trote/carrera/sprint (procedural vs clip) | [PLAYER](PLAYER.md) |
| *tests/test_pack_reactions.gd (eliminada en la reforma; en el historial de git)* | 6 | 18 | Celebrar/lamentarse en un gol y recepción, con respaldo de Tripo | [ANIMATION_PACK](ANIMATION_PACK.md) |
| `tests/test_pack_motion.gd` | 2 (render) | 24 (render) | Deslizamiento del pie de apoyo y punta del pie viva en el impulso (**solo con render**) | [ANIMATION_PACK](ANIMATION_PACK.md) |
| `tests/test_goalkeeper.gd` | 5 | 25 | Arquero: posición, planificador de manos, bloqueo y saque, contacto real, tasa de atajadas por velocidad | [GOALKEEPER](GOALKEEPER.md) |
| *tests/test_ai_match.gd (eliminada en la reforma; en el historial de git)* | 4 | 16 | Partido completo 4+arquero contra 4+arquero con IA (pases, tiros, robos, sin trabarse), pelota nunca bloqueada, tiros con ángulo útil, patadas al aire acotadas y colores de cada equipo | [MATCH](MATCH.md), [PLAYER](PLAYER.md) |
| `tests/test_aerial_kicks.gd` | 1 | 2 | Voleas y cabezazos: contacto de pie/cabeza con la pelota en vuelo | [PLAYER](PLAYER.md) |
| *tests/test_player_actions.gd (eliminada en la reforma; en el historial de git)* | 4 | 13 | Barrida planificada, caídas y levantarse, regate (ruleta), raíz de las acciones | [PLAYER](PLAYER.md) |
| *tests/test_gameplay_feel.gd (eliminada en la reforma; en el historial de git)* | 10 | 33 | Sensación de juego medida: conducción lenta, sprint, frenar con la pelota, giros de 90°/180°, control lateral, pase pulsado en carrera, recepción sin frenar, acciones que no bloquean | [PLAYER](PLAYER.md) |
| *tests/test_control_and_keeper.gd (eliminada en la reforma; en el historial de git)* | 7 | 26 | Cedida recibida con el pie vs disparo atajado, arquero manejado por la persona (joystick, atrapar, sacar), indicadores de jugador, cambio al arquero, saque inicial | [GOALKEEPER](GOALKEEPER.md), [UI_HUD](UI_HUD.md), [MATCH](MATCH.md) |
| *tests/test_pass_receiver_control.gd (eliminada en la reforma; en el historial de git)* | 4 | 16 | Control de la persona en los pases: receptor controlado al pasar (con y sin destinatario), sin cambio durante el vuelo de un pase largo, control al compañero que se queda con la pelota, la IA del equipo de la persona no pasa ni patea, la IA sigue jugando sin persona | [MATCH](MATCH.md) |
| tests/test_animation_inventory.gd (borrado: Mixamo/Mocap) | 2 | 5 | Inventario medido de las 171 animaciones (trayectoria de los pies, empujes, veredicto de conducción); `INVENTORY_OUT` escribe el informe, `DRIBBLE_CANDIDATE` valida un clip nuevo | [ANIMATION_PACK](ANIMATION_PACK.md) |
| `tests/test_kick_reach.gd` | 2 | 17 (render) / 10 | Golpeo pedido con la pelota propia fuera del alcance: el jugador ajusta la carrera y golpea con contacto o cancela con aviso | [PLAYER](PLAYER.md) |
| *tests/test_shared_ball_mechanics.gd (eliminada en la reforma; en el historial de git)* | 2 | 8 | La IA usa la misma mecánica de pelota que la persona (sin atajos) | [PLAYER](PLAYER.md) |
| *tests/test_dribble_reference.gd (eliminada en la reforma; en el historial de git)* | 1 (render) | 6 (render) | Conducción recta medida contra el video de referencia (intervalo, pie, alternancia, distancia, deriva) | [PLAYER](PLAYER.md) |
| *tests/test_drag_back.gd (eliminada en la reforma; en el historial de git)* | 4 | 34 (headless) | Vuelta atrás pisando la pelota con REGATE + joystick atrás: caminando, al trote y a la carrera en 6 momentos del ciclo (pisada o, con la pelota escapada, giro con toques), sprint sin pisada, la IA con el mismo botón; con render, la suela sobre la pelota | [PLAYER](PLAYER.md) |
| *tests/test_ball_turn.gd (eliminada en la reforma; en el historial de git)* | 4 | 49 (headless) / 53 (render) | Giro con toques (joystick atrás sin botón): caminando, trote, carrera en 6 momentos del ciclo, 135°, sprint, la IA; toques, tiempo de giro, separación, pelota delante al salir; con render, el pie en la pelota en cada toque | [PLAYER](PLAYER.md) |
| *tests/test_loose_ball_chase.gd (eliminada en la reforma; en el historial de git)* | 4 | 6 | El jugador de la persona va a la pelota suelta (joystick suelto o hacia ella), el joystick hacia otro lado manda, la IA no; pase pedido antes de llegar a una pelota suelta no se pierde | [PLAYER](PLAYER.md) |
| `tests/test_audio.gd` | 3 | 26 | Sonido: los efectos existen y se cargan, público en bucle, sonido de cada golpe por el impulso real, `Ball.impulse` | [AUDIO](AUDIO.md) |
| *tests/test_mocap_mode.gd (eliminada en la reforma; en el historial de git)* | 7 | 79 | Modos 2 y 3: librería con contactos medidos, selección de clips por modo, pase y tiro con el clip de la captura de parado a sprint con el pie en la pelota, penal con su carrera, saque de banda `mc_throw_in`, tarjeta del árbitro, modelo Newton (`MocapRig`: pies y manos a ≤ 0.08 m de los del futbolista) y modo 3 solo Tripo; con render, `LIVE_KICKS_MODE=2 … --filter live_kicks` mide los mismos golpeos con el esqueleto animado | [ANIMATION_PACK](ANIMATION_PACK.md) |
| `tests/test_json_mode.gd` | 10 | 192 (+24 con render) | Modo 4 (Json): librería con roles y contactos medidos (pase y tiro con las dos piernas), alias de los nombres del pack, error del retarget (tobillos y muñecas a 0 cm del dato), el humanoide (23 huesos, altura de cadera, marcha con y sin pelota), pases y tiros desde parado a sprint con el pie en la pelota, partido de IA (cuenta golpeos, giros de clip y movimientos con pelota), sala de práctica, coste de planificar con cientos de clips; con render conducción a trote/carrera/sprint/zigzag (la pelota nunca pasa de 1 m del cuerpo, toques con el pie). `TEST_GAMEPLAY_MODE=4` ejecuta cualquier prueba en el modo 4: `live_kicks` (49–50 de 50 golpeos, pie de apoyo ≤ 0.7 m/s) y `live_feet` | [JSON_MODE](JSON_MODE.md) |
| *tests/test_practice.gd (eliminada en la reforma; en el historial de git)* | 4 | 37 | Galería (133 clips, roles), reproducción de todos los clips, raíz y espejo, malabares por impulsos | [ANIMATIONS](ANIMATIONS.md) |
| **Total (headless)** | **121 + 2 omitidas** | **686** | | |

Comando por sistema: `tools/run_tests.sh pack_kick`, `pack_dribble`, `pack_reactions`, `pack_locomotion`, `pack_retarget`, `ball_physics`, `locomotion`, `dribbling`, `kick_timing`, `passing`, `shooting`, `press`, `match_flow`, `touch_controls`, `player_model`. Todo: `tools/run_tests.sh`.

## Lo que NO cubren las pruebas (verificado)

| Área | Situación |
|---|---|
| Cámara (`MatchCamera`) | Sin aserciones; solo se instancia en *test_match_flow (eliminada en la reforma)* ([CAMERA](CAMERA.md)) |
| Gráficos y diagnóstico (`GraphicsSettings`, `DiagnosticsOverlay`) | Sin pruebas ([PERFORMANCE](PERFORMANCE.md)) |
| Menú de pausa y marcador del `Hud` | Sin pruebas ([UI_HUD](UI_HUD.md)) |
| `GameEvent`/`InputFrame` `to_dict`/`from_dict`, `PlayerAttributes` serialización | Sin pruebas directas ([NETWORK](NETWORK.md), [PROGRESSION](PROGRESSION.md)) |
| Persistencia en `user://` (`Tuning.save_user_settings`, `GraphicsSettings.save_settings`) | Sin pruebas |
| Audio, estadísticas, online | No existen |
| IA frente a humanos, arquero con el esqueleto vivo en un partido completo con render, sala de práctica con toques reales | Sin pruebas (la IA y el arquero se miden en simulación headless; la práctica se probó con render solo por filtro) |
| Android (dispositivo/emulador) y aspecto visual | No se prueba; solo capturas manuales con Xvfb. Las pruebas del pack miden el esqueleto animado con render por software, no un móvil |
| Pack de animaciones en un clon limpio | Sin las librerías del pack (`pack_clips.res`, `pack_keeper.res`) las pruebas que las necesitan se **omiten** |
| Un caso de prueba por atributo | No existe: los atributos se ejercitan solo a través de pase, tiro, conducción y locomoción (varios no se usan en el código: ver [PROGRESSION](PROGRESSION.md)) |

## Cómo añadir una prueba

1. Crear `tests/test_<tema>.gd` con `extends TestCase` y métodos `func test_...() -> void:` (pueden usar `await`).
2. Usar `make_match()` y `add_player(ctx, equipo, posición, atributos, ScriptedInput)` y avanzar con `await wait_seconds(s)` / `physics_frames(n)`; cada prueba debe hacer **al menos un** `check`.
3. Ejecutar `tools/run_tests.sh <tema>`, luego `python3 tools/docs_index.py sync` (añade la prueba a la ficha) y `check`.
4. No registrar una prueba como aprobada si no se ejecutó (regla del CHANGELOG).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): evolución 9/24 → 40/113 → 44/140 → 54/188 → 57/209 → 57/212 (reproducida commit a commit el 2026-10-26).

## Modo de cada prueba y suite en el modo 4 (2026-10-31)

- `TestCase.gameplay_mode()` (0 = el predeterminado, `TEST_GAMEPLAY_MODE` o `Tuning.DEFAULT_GAMEPLAY_MODE` = 4): el
  ejecutor (`run_tests.gd`) pone ese modo y recarga `PackLibrary` antes de cada prueba. Las pruebas del pack de Mixamo
  heredado fijan el modo 1 (test_animation_contact_audit (borrado: Mixamo/Mocap), test_animation_inventory (borrado: Mixamo/Mocap), test_pack_kick (borrado: Mixamo/Mocap),
  test_pack_locomotion (borrado: Mixamo/Mocap), *test_pack_reactions (eliminada en la reforma)*, test_pack_retarget (borrado: Mixamo/Mocap), test_player_model (borrado: Mixamo/Mocap), *test_pack_dribble_metrics (eliminada en la reforma)*,
  *test_drag_back (eliminada en la reforma)*).
- Nuevas: `test_bank_integration`, *test_mode4_dribble (eliminada en la reforma)*, `test_ball_prediction`, *test_falls_direction (eliminada en la reforma)*.
- Goles fantasma en `test_shot_keeper` y *test_shooting (eliminada en la reforma)*: `Ball.reset_at` se aplica en el paso físico siguiente y, con el
  cerrojo del arco ya reiniciado, la pelota del gol anterior aún en la red contaba otro gol para el tiro siguiente. Los
  contadores se toman ahora con la pelota ya recolocada (el partido no tiene el problema: `MatchManager._on_goal` solo cuenta
  en juego).
- Con render (xvfb, no en headless): `test_live_kicks` (batería de 50 golpeos: 49 con contacto, 0 inválidos),
  *test_live_feet (eliminada en la reforma)*, `test_pack_motion`, `test_json_mode`.

## Rendimiento y joystick suelto (2026-11-05)

- ***test_physical_dribble::test_released_stick_player_goes_to_the_ball (eliminada en la reforma)*** (render, nueva): joystick suelto con la pelota
  al costado (quieta o rodando hacia afuera), detrás rodando hacia atrás y delante rodando despacio; pide 0 toques sin pie,
  la pelota quieta delante al final y que el que se acomoda sea el jugador (pasos o giro). Con el código anterior fallaba
  en los cuatro casos (jugador 0.00 m, pelota llevada delante con toques sin pie).
- ***test_physical_dribble::test_pass_to_a_mate_behind_uses_a_back_kick_or_turns (eliminada en la reforma)*, medida corregida (dicho, no ocultado):**
  la dirección al compañero se medía desde la posición **final** de los dos jugadores (el que pasa sigue corriendo con el
  joystick y, con el cambio de arriba, el compañero va a buscar la pelota que le llega). Ahora: dirección de la pelota al
  salir frente a la de la pelota al compañero en ese momento. Con el código anterior y el nuevo la pelota sale
  exactamente igual (comprobado imprimiendo su velocidad); medido así, 5° (antes 11-25° según dónde terminaran).
- **`tools/perf_probe.tscn`** (herramienta, no prueba): costo de CPU por sistema en un partido IA contra IA. Ver
  [PERFORMANCE](PERFORMANCE.md#tirones-de-cpu-y-opciones-de-rendimiento-2026-11-05).
- `test_live_kicks::test_kick_battery_fifty_varied_actions` no es determinista y falla a veces en «pase bajo presión en
  carrera» (punta del pie a 0.42-0.43 m en la imagen del golpe). Medido repitiendo ese caso 16 veces con cada versión: el
  pie queda a más de 0.3 m en **9 de 16 con el código anterior y 9 de 16 con el nuevo**. Defecto previo (el golpeo bajo
  presión a la carrera), no causado por este cambio; pendiente.
- *test_full_match::test_three_minute_match_is_played_to_the_final_whistle_with_goal_replays (eliminada en la reforma)* pide ≥ 2 tiros en un partido
  de IA de 3 min: con mucho azar (5 corridas: 3-10 tiros con `0baf375`, 4-8 con el código nuevo; casos aislados de 1-2).
  Falló una vez en GitHub Actions #47 con 1 tiro.
- **Pruebas de partidos de IA inestables, medido con el código anterior (`0baf375`, 4 corridas cada una):**
  *test_json_mode::test_ai_match_in_json_mode (eliminada en la reforma)* falla 1 de 4 («Humanoide: nadie se sale de la cancha»; tiros 1, 1, 2, 1) y
  *test_training_mode::test_teammates_do_not_crowd_the_dribbler (eliminada en la reforma)* falla 1 de 4 (34 de 399 muestras a < 2 m). Con el código
  nuevo, 1 de 4 cada una (tiros 2, 2, 7, 3). Junto con *test_ai_match (eliminada en la reforma)* (arqueros que enfrentan tiros, jugador fuera de la
  cancha) y el partido de 3 min (≥ 2 tiros), la suite completa falla a menudo por azar de la IA aunque nada cambie:
  GitHub Actions #47 (reintento) y #48 fallaron así. Pendiente: semillas fijas para la IA en esas pruebas.

## Toque orientado con clips de UCS y botines (2026-11-05)

- ***test_mode4_dribble::test_oriented_touch_with_ucs_dribble_clips (eliminada en la reforma)*** (nueva): al trote, con el joystick cambiando 35° a
  cada lado (cuatro casos), cuenta los toques orientados (`JsonBallMove`, intención `steer`). Pide que el clip gire hacia
  el lado del joystick, que el error de cada toque del pie sea < 0.2 m, que no se corte por un toque perdido, que la
  pelota no se escape (< 2.2 m), que no salte de posición, que salga a < 45° del joystick y que siga la posesión. Pide
  también que al menos 3 de los 4 cambios usen un clip.
- **`tools/json_anim/play_view.tscn`** (herramienta): escenas nuevas `steps` (cambios bruscos de ±35°) y `curve` (el
  joystick gira 30°/s, `CURVE_SIGN`). Imprime cada movimiento con pelota (`MOV`: intención, clip, giro, pie del toque que
  orienta, error de cada toque y cuadro) y la posición del jugador. Medidas antes y después en
  [E3](../../fases/E3_conduccion_ucs.md#5-medido-play_view-render-xvfb-joystick-08-85-s-antes--commit-anterior).
- La curva en sprint de 8.5 s de `play_view` llega a la banda (z = 14.7 m): la pelota «perdida» ahí es el borde de la
  cancha, en las dos versiones. Las corridas en sprint se acortan a 6.5 s.

