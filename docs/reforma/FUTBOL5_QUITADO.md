# Modo de fútbol 5 quitado de la rama de la reforma

Fecha: 2026-11-07. Pedido del usuario: «no vamos a hacer fútbol 5, eso debe salir; las animaciones, las conexiones físicas
y todo lo demás se conservan para usarse en penales y tiros libres; solo pruebas de penal y tiro libre, nada de fútbol 5».
Rama: `reforma-tiros-penales`. La rama `integracion-openai` conserva el partido completo y sus pruebas; también se puede
recuperar desde el historial de git (el último commit con el modo es `687d229`).

## Qué salió

- **Escenas:** `scenes/main/match.tscn` (el partido) y `scenes/practice/practice.tscn` (la sala de práctica, que solo se
  abría desde el partido).
- **Acceso:** el botón «Partido de fútbol 5» del menú de desarrollo. El menú solo abre el banco de pruebas hasta que
  existan los modos de tiros libres y penales.
- **Pruebas de juego abierto (35 archivos):** `test_ai_match`, `test_full_match`, `test_match_flow`, `test_goal_replay`,
  `test_team_shape_metrics`, `test_training_mode`, `test_control_and_keeper`, `test_pass_receiver_control`,
  `test_set_pieces` (reglas de bandas y faltas del partido), `test_dribbling`, `test_mode4_dribble`, `test_physical_dribble`,
  `test_dribble_reference`, `test_live_feet`, `test_pack_dribble_metrics`, `test_ball_turn`, `test_drag_back`,
  `test_passing`, `test_pes_mechanics`, `test_cross_connections`, `test_press`, `test_loose_ball_chase`,
  `test_shared_ball_mechanics`, `test_gameplay_feel`, `test_player_actions` (barridas y caídas), `test_falls_direction`,
  `test_receive`, `test_shooting` (tiro con joystick y asistencia), `test_throw_preparation`, `test_touch_controls`
  (joystick y botones), `test_practice`, `test_mocap_mode` (modos 2 y 3 del partido), `test_gameplay_mode_default`,
  `test_pack_reactions` (reacciones a eventos del partido), `test_environment_connections` (público, técnicos y árbitro del
  partido).
- **Pruebas sueltas dentro de archivos que se conservan:** `test_json_mode::test_ai_match_in_json_mode` (partido de 90 s),
  `test_json_mode::test_practice_scene_opens_in_json_mode`,
  `test_anim_trace::test_match_scene_creates_the_overlay_only_in_debug_and_f3_toggles_it` y
  `test_anim_trace::test_trace_in_a_real_match_covers_the_planners`.
- **CI:** las baterías con render de conducción y recepción (`live_feet`, `physical_dribble`, `dribble_reference`,
  `test_receive`); se agregó la del banco de pruebas.

## Qué se conserva (y por qué)

- **Animaciones:** los tres bancos completos (JSON, Mixamo, Mocap), catálogos, retargets y metadatos. Ninguna se borró.
- **Pruebas de los sistemas que usan tiros libres y penales:** pelota (física, efecto Magnus, predicción, red, arco y gol),
  golpeos y su contacto (clips, alcance, sincronía, direcciones, golpeos recuperados, balón parado con contacto), voleas y
  cabezazos (despejes), arquero (atajadas, lectura de tiros, giros, tiros contra el arquero), animaciones y bancos (pack,
  modo JSON, inventarios, retarget, catálogo, banco de pruebas, traza), locomoción y transiciones (los jugadores sueltos se
  mueven), árbitro de acciones, audio y limpieza de memoria.
- **El código del partido** (`MatchScene`, `MatchManager`, `TeamBrain`, `AIInput`, HUD, repetición, presentación, árbitro):
  queda **sin escena ni acceso**, pero no se borró, porque los sistemas que se reutilizan lo nombran (el arquero, el balón
  parado, las acciones del jugador, las recepciones y la traza consultan `MatchScene` o `MatchManager`). Se desacopla en la
  Fase 3, cuando los modos nuevos tengan su propia escena y estado de partida; entonces se podrá quitar sin romper nada.
- **Herramientas** que abrían el partido (`tools/perf_probe.gd`, `tools/shot_runner.gd`, `tools/json_anim/match_shot.gd`):
  quedan en el repositorio pero ya no tienen escena que abrir; no entran en la APK.
