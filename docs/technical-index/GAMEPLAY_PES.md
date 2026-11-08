# Jugabilidad inspirada en eFootball PES 2021 — análisis, mecánicas y verificación

Implementación **original** (sin código, recursos ni marcas de Konami): los videos se usaron como referencia de
comportamiento. Todo lo nuevo se apoya en los sistemas que ya existían (física de la pelota, patada con contacto del
pie, arquero con trayectoria de manos, IA por roles) y en las animaciones del pack.

## 1. Videos analizados

Se extrajeron fotogramas de los tres videos completos (1.5 fps, 1 fps y 0.25 fps). No se analizó el audio.

| Video | Qué muestra realmente |
|---|---|
| `TIKI-TAKA_MASTERCLASS…_pes2021.mp4` (12.9 s, vertical) | Salida desde el arquero con pase corto, circulación por dentro (pase y apoyo constante), jugador marcado con su nombre, cámara de transmisión alta que sigue la pelota con el poseedor y sus opciones de pase en cuadro. |
| `Wonderful_football_tiki_taka…ps4.mp4` (24.3 s) | Cámara muy abierta: estructura de ambos equipos, defensas en bloque, triangulaciones por banda, aproximación al área y remate cerca del arco; los atacantes se ofrecen a distintas alturas y los defensores cierran líneas. |
| `La Jugabilidad de PES 2021 ENAMORABA` (139 s, en `.rar`) | Video de opinión con subtítulos («Inteligencia artificial constante, dinámica», «entrada», «enfrentamientos», «arqueros… se equivocaban», «precisión», «rápido»): conducción y regate, entradas y caídas, arqueros atajando y fallando, ritmo y precisión del pase. |

No se distingue en los videos: la botonera exacta (se adaptó al móvil), números de velocidades ni de efecto. Los
valores se fijaron con la física del juego y se midieron (sección 5).

## 2. Tabla de mecánicas

| Mecánica observada | Qué hace el jugador | Cómo responde el juego | Animaciones y física | Cómo se prueba |
|---|---|---|---|---|
| Circulación al pie (tiki-taka) | PASE apuntando con el joystick (mantener = más fuerte) | Elige compañero por intención, distancia y línea libre; el control pasa al receptor; error por precisión, postura y **presión rival** | Clip de pase con contacto real del pie (8 mm medidos); impulso único | *test_passing (eliminada en la reforma)*, *test_pes_mechanics::test_receiver_runs… (eliminada en la reforma)*, `test_pack_motion` (render) |
| Receptor que sale al pase | Nada (o joystick) | El receptor corre al punto de la trayectoria PREDICHA al que llega antes que la pelota | Recepción con el pie (`receive_soccerball`) o el cuerpo (`Receive`) cuando la pelota llega a ~0.5 m, no a 1 m | *test_pes_mechanics (eliminada en la reforma)*, *test_pack_reactions (eliminada en la reforma)* |
| Pase filtrado | FILTRADO (+ ALTO = por arriba) | Pelota al espacio por delante del desmarque, en el hueco de mayor línea libre | Mismo golpeo; llega a velocidad de carrera | *test_pes_mechanics::test_through_pass… (eliminada en la reforma)* |
| Pared | Pasar con espacio por delante | El pasador (ya IA) sigue la jugada al espacio 1.8 s | Locomoción normal | `test_receiver_runs…` (control al receptor) |
| Centro desde la banda | CENTRO (carga alta = tenso; + ALTO = raso) | Zona: primer palo, segundo palo o punto de penal según joystick y compañeros llegando; trayectoria resuelta con la física real | Altura de remate 1.7 m en la zona; efecto natural hacia el arco | *test_pes_mechanics::test_crosses… (eliminada en la reforma)* |
| Llegada al área | — | Con el portador en zona de centro: pivote al primer palo, alas al segundo palo / penal, cierre a la frontal | — | *test_full_match (eliminada en la reforma)* (partidos) |
| Conducción cercana | Joystick | Cada toque lo da **el pie animado** que llega a la pelota; la pelota se deja al alcance de la zancada | Esqueleto vivo: punta del pie a 0.21–0.27 m del centro de la pelota (radio 0.11) | *test_live_feet (eliminada en la reforma)* (render) |
| Tiro normal / potente / colocado | TIRO (corto cerca del arco = colocado; carga alta = potente) | Colocado: al palo lejano, más lento y preciso, con rosca; potente: más rápido y menos preciso | Clip de tiro con contacto del pie | *test_shooting (eliminada en la reforma)*, *test_pes_mechanics::test_placed_shot… (eliminada en la reforma)* |
| Chanfle / comba | Pulsar TIRO apuntando y, al soltar, girar el joystick hacia un lado | La salida se abre y la curva la cierra al objetivo | Giro lateral → efecto Magnus real (1.3 m de curva en 17 m) | `test_ball_curl` |
| Presión y contención | PRESIÓN mantenido | Cierra distancia y contiene (jockey); **no roba solo** | Mezcla direccional + lateral rápido (`Strafe_3`) | *test_pes_mechanics::test_human_press… (eliminada en la reforma)* |
| Entrada | ENTRADA | Al alcance: de pie (probabilística); a la carrera: barrida; a la par: carga con el hombro; lejos: entrada al aire (penaliza) | `soccer_tackle*`, `Defender`, `Jogging_Stumble` (pierde la carga) | *test_pes_mechanics::test_tackle… (eliminada en la reforma)*, `test_shoulder…` |
| Faltas | Entrar por detrás / barrer al cuerpo | Tiro libre o penal según el área | Caída, `fallen_idle`/dolor y levantarse | *test_set_pieces (eliminada en la reforma)* |
| Bloqueo de tiro | — | El defensor en la línea salta | `Defender_2`; el bloqueo real es su cuerpo | partidos |
| Arquero: atajadas | — | Plan con la trayectoria real de las manos; reacción con retraso por atributos | Estiradas, bloqueos, `goalkeeper_miss` cuando no llega | `test_goalkeeper`, `test_keeper_and_gait_clips` |
| Arquero: mano a mano | — | Sale a cerrar el ángulo si el atacante va solo; se lanza a los pies si se adelanta la pelota | Bloqueo/recogida con el plan de manos | `test_keeper_and_gait_clips::test_keeper_rushes…` |
| Arquero: centros | — | Sale si la pelota cae en su zona y llega antes; ajusta los pasos para que las manos coincidan | `goalkeeper_catch_4` | `test_keeper_and_gait_clips::test_keeper_claims…` |
| Saque de banda, córner, saque de arco | Botones de pase / centro / tiro con el ejecutor | Reglas con bandas; rivales a 5 m; jugada ensayada en córner y penal | `throw_in` (manos reales), `Chip`, `strike_foward_jog`, `soccer_penalty_kick`, `goalkeeper_placing_ball` | *test_set_pieces (eliminada en la reforma)* |
| Repetición de goles | Cualquier botón la salta | Cámara lenta 4.5 s antes del gol, con cámara propia; el partido queda exactamente como estaba | Poses de hueso grabadas | *test_goal_replay (eliminada en la reforma)*, *test_full_match (eliminada en la reforma)* |
| Árbitro que sigue la jugada | — | Por la banda, de lado o de frente | Gemelos con raíz (sin patinar) | *test_pes_mechanics::test_referee… (eliminada en la reforma)* |

## 3. Diagnóstico inicial (antes de este cambio)

- Godot 4.7.2, GDScript, física Jolt 60 Hz, Android arm64. Arquitectura ya separada: `Footballer` (orquesta),
  `Locomotion`, `BallHandler` (conducción, pase, tiro, disputa), asistencias puras, `AIInput` (mismo `InputFrame` que la
  persona), `Goalkeeper` + `KeeperPlanner`, `MatchManager`, `MatchCamera`, HUD táctil. 121 pruebas pasaban.
- Funcionaba de verdad: física de pelota (arrastre, Magnus, rodadura), patada con contacto medido del pie, atajadas
  por trayectoria de manos, IA que pasa y tira, barridas y caídas.
- Débil o faltante: **la conducción tocaba la pelota con el pie a 0.8–1.5 m** (medido con render) y la recepción a
  1.05 m («imán»); mantener PRESIÓN robaba solo; no había filtrado, centros, entrada con botón, reglas de bandas, faltas
  sancionadas, mano a mano, salida a centros, repetición ni efecto pedido; ningún mando configurado; 40 clips del pack
  solo en la galería.

## 4. Archivos

**Nuevos:** `scripts/gameplay/set_piece.gd`, `scripts/gameplay/goal_replay.gd`, `scripts/assistance/cross_assist.gd`,
`scripts/input/input_bindings.gd`; pruebas *tests/test_set_pieces.gd (eliminada en la reforma; en el historial de git)*, *test_pes_mechanics.gd (eliminada en la reforma)*, `test_keeper_and_gait_clips.gd`,
*test_live_feet.gd (eliminada en la reforma)*, `test_ball_curl.gd`, *test_goal_replay.gd (eliminada en la reforma)*, *test_full_match.gd (eliminada en la reforma)*.

**Modificados:** `ball_handler.gd` (pies vivos, filtrado, centro, chanfle, toques de preparación), `footballer.gd`
(entrada, recepción asistida, transiciones de marcha, bloqueo), `player_actions.gd` (entrada/carga/barrida larga,
caídas nuevas), `footballer_visual.gd` (marcha, conducción, lateral rápido, rig del árbitro), `ai_input.gd`
(balón parado, centros, filtrados, desmarques, cobertura, cortes de línea, chanfle), `goalkeeper.gd` (saque de arco,
achique, centros, estirada desesperada, indicaciones, pelota en las manos), `match_manager.gd` / `match_scene.gd` /
`match_context.gd` (bandas, faltas, balón parado, repetición, duración), `pitch.gd` (paredes retiradas con bandas),
`pass_assist.gd` / `shot_assist.gd` / `kick_model.gd` (filtrado, presión, colocado/potente, efecto), `referee.gd`,
`press_controller.gd`, `touch_controls.gd`, `hud.gd`, `tuning.gd`, `input_frame.gd`, `human_input.gd`,
`scripted_input.gd`, `game_event.gd`, `animation_catalog.gd`, `ball.gd` (estela).

## 5. Pruebas ejecutadas (resultados reales)

Ver la entrada de este cambio en [CHANGELOG.md](CHANGELOG.md) (suite headless completa y pruebas con render).
Mediciones destacadas:

- Conducción con el pie animado (render, *test_live_feet (eliminada en la reforma)*): trote 3.3 m/s, carrera 5.3 m/s y sprint 6.4 m/s con el
  100 % de la pelota a menos de 1.6 m y mediana punta del pie–centro de pelota 0.21–0.27 m; zigzag 18 de 21 toques con
  el pie.
- Partidos de IA con reloj (*test_full_match (eliminada en la reforma)*): 3, 5, 7 y 10 minutos jugados hasta el pitazo final, con una repetición
  por gol, balón parado de todos los tipos y la pelota nunca trabada más de 1.6 s.
- Chanfle: 1.3 m de curva en ~17 m; un tiro escorado con chanfle entra en el arco.

## 6. Limitaciones

- No se ejecutó en un teléfono real: no se afirma un número de FPS. Las pruebas con render corren con `xvfb-run` en PC.
- En headless (servidores, CI) la pose del esqueleto no se usa: la conducción usa la cadencia de la marcha. En el
  juego real (con render) los toques salen del pie.
- El gesto de chanfle es propio (pulsar → apuntar → girar al soltar); PES usa otra combinación de mando.
- La repetición reproduce lo grabado (poses y posiciones); la capa procedural de patada sin pack no se graba.
- No hay sonido (el proyecto aún no tiene audio), ni fuera de juego (no existe en fútbol 5), ni tarjetas.
- Algunos clips de transición solo existen hacia un lado (`Sprint_Turn` gira a la derecha).

## 7. Cómo probarlo

- PC: abrir con Godot 4.7.2 y ejecutar *scenes/main/match.tscn (eliminada en la reforma; en el historial de git)*. Teclado: WASD, J pase, K tiro, O filtrado, H centro,
  I alto, L presión, N entrada, U regate, Q cambio, Shift sprint, Esc pausa. Mando: A pase/presión, X tiro/entrada,
  Y filtrado, B centro, RB sprint, LB alto, LT cambio, RT regate, Start pausa.
- Móvil: el APK del workflow (ver `README.md`). La duración (3/5/7/10 min), el tamaño de los botones y la sensibilidad
  del joystick están en el menú de pausa.
- Pruebas: `tools/run_tests.sh` (headless) y, para las de pies vivos,
  `xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter live_feet`.
