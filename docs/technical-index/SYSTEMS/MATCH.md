# MATCH — Reglas y flujo del partido, contexto y composición de la escena

## Identificación

- **Responsabilidad exacta:**
  - `MatchManager`: máquina de estados del partido (saque → juego → gol → saque…, pausa, fin de tiempo), marcador, reloj, goles en contra y asistencias. **No crea ni mueve entidades**: pide la reposición con la señal `kickoff_requested`.
  - `MatchContext`: vista compartida (pelota, cancha, cámara, futbolistas, `tick`, `match_time`, `input_enabled`) y bus de eventos. **No contiene reglas.**
  - `MatchScene`: raíz de composición. Crea cancha, pelota, cámara, equipos, `MatchManager`, `Hud`, y reposiciona en cada saque.
- **Estado:** implementado y probado: **4 contra 4 con arquero** por equipo (`home_field_players = away_field_players = 4`, `with_keepers`), un humano local (el compañero más cercano a la pelota se controla con el cambio de jugador, `auto_switch`) y el resto con `AIInput`; árbitro y presentación previa (`intro_seconds`, `with_referee`). Las pruebas de flujo desactivan arqueros, árbitro y presentación para aislar el reloj.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-13
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/gameplay/match_manager.gd` | Estados, marcador, reloj, saque, gol (`_on_goal`), pausa | `MatchManager.State`, `MatchManager._on_goal`, `MatchManager._begin_kickoff`, `MatchManager.toggle_pause`, `MatchManager.restart_play`, `MatchManager.restart_match` | `MatchContext`, `Pitch.goal_scored`, `Ball.touched`, `GameEvent` |
| `scripts/gameplay/match_context.gd` | Contexto compartido | `MatchContext.emit_event`, `MatchContext.attacking_goal`, `MatchContext.teammates_of`, `MatchContext.screen_to_world`, `MatchContext.keeper_defending` | `Ball`, `Pitch`, `MatchCamera`, `Footballer` |
| `scripts/gameplay/match_scene.gd` | Composición y formación de saque | `MatchScene._ready`, `MatchScene._spawn_teams`, `MatchScene.kickoff_positions`, `MatchScene._on_kickoff_requested` | todo lo anterior + `Hud`, `HumanInput`, `PlayerAttributes` |
| *scenes/main/match.tscn (eliminada en la reforma; en el historial de git)* | Escena principal (`run/main_scene`): un `Node3D` con `match_scene.gd`; todo lo demás se crea por código | nodo `Match` | `MatchScene` |

**No modificar para cambiar el balance de juego:** `match_manager.gd` no tiene física; el gol lo decide `Goal` (ver [PITCH](PITCH.md)).

## Mapa de parámetros

<!-- AUTO:params:MatchManager -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `duration_seconds` | `300.0` | float | `scripts/gameplay/match_manager.gd:23` | `scripts/ui/hud.gd:267`, `scripts/gameplay/match_manager.gd:161`, `scripts/gameplay/match_scene.gd:95` | Duracion en segundos (0 = sin limite, util en el laboratorio). |
| `goal_celebration_seconds` | `3.0` | float | `scripts/gameplay/match_manager.gd:24` | `scripts/gameplay/match_manager.gd:168`, `scripts/gameplay/match_manager.gd:297`, `scripts/gameplay/match_manager.gd:301` |  |
| `replay_after_seconds` | `1.3` | float | `scripts/gameplay/match_manager.gd:26` | `scripts/gameplay/match_manager.gd:168` | Segundos de festejo en vivo antes de la repeticion del gol (0 o menos = sin repeticion). |
| `replay_active` | `false` | bool | `scripts/gameplay/match_manager.gd:28` | `scripts/gameplay/match_manager.gd:89`, `scripts/gameplay/match_scene.gd:272`, `scripts/gameplay/match_scene.gd:276` | true mientras se ve la repeticion (la pausa del juego no se puede abrir encima). |
| `_replay_done` | `false` | bool | `scripts/gameplay/match_manager.gd:29` | `scripts/gameplay/match_manager.gd:168`, `scripts/gameplay/match_manager.gd:169`, `scripts/gameplay/match_manager.gd:295` |  |
| `pre_kickoff_seconds` | `1.2` | float | `scripts/gameplay/match_manager.gd:30` | `scripts/gameplay/match_manager.gd:111` |  |
| `intro_seconds` | `0.0` | float | `scripts/gameplay/match_manager.gd:32` | `scripts/gameplay/match_manager.gd:110`, `scripts/gameplay/match_manager.gd:111`, `scripts/gameplay/match_scene.gd:97` | Presentacion antes del primer saque (calentamiento y arbitro). 0 = sin presentacion. |
| `assist_window_seconds` | `6.0` | float | `scripts/gameplay/match_manager.gd:34` | `scripts/gameplay/match_manager.gd:291` | Ventana para considerar asistencia el pase previo al gol. |
| `ctx` | `—` | MatchContext | `scripts/gameplay/match_manager.gd:36` | `scripts/gameplay/match_manager.gd:61`, `scripts/gameplay/match_manager.gd:62`, `scripts/gameplay/match_manager.gd:63`, `scripts/gameplay/match_manager.gd:64` (+38) |  |
| `state` | `State.PRE_KICKOFF` | State | `scripts/gameplay/match_manager.gd:37` | `scripts/ui/hud.gd:289`, `scripts/gameplay/match_manager.gd:79`, `scripts/gameplay/match_manager.gd:91`, `scripts/gameplay/match_manager.gd:94` (+10) |  |
| `score` | `[0, 0]` | Array[int] | `scripts/gameplay/match_manager.gd:38` | `scripts/ui/hud.gd:80`, `scripts/gameplay/match_manager.gd:68`, `scripts/gameplay/match_manager.gd:164`, `scripts/gameplay/match_manager.gd:165` (+4) |  |
| `kickoff_team` | `0` | int | `scripts/gameplay/match_manager.gd:39` | `scripts/gameplay/match_manager.gd:71`, `scripts/gameplay/match_manager.gd:81`, `scripts/gameplay/match_manager.gd:103` |  |
| `_state_timer` | `0.0` | float | `scripts/gameplay/match_manager.gd:41` | `scripts/gameplay/match_manager.gd:111`, `scripts/gameplay/match_manager.gd:114`, `scripts/gameplay/match_manager.gd:116`, `scripts/gameplay/match_manager.gd:134` (+11) |  |
| `active_set_piece` | `null` | SetPiece | `scripts/gameplay/match_manager.gd:44` | `scripts/gameplay/match_manager.gd:106`, `scripts/gameplay/match_manager.gd:146`, `scripts/gameplay/match_manager.gd:147`, `scripts/gameplay/match_manager.gd:151` (+6) | Balon parado en curso (lo crea la escena) o arquero que hace el saque de arco. El juego se reanuda cuando el saque se ejecuta de verdad (la pelota sale del pie o de las manos del ejecutor). |
| `goal_kick_keeper` | `null` | Node | `scripts/gameplay/match_manager.gd:45` | `scripts/gameplay/match_manager.gd:107`, `scripts/gameplay/match_manager.gd:237`, `scripts/gameplay/match_manager.gd:253`, `scripts/gameplay/match_manager.gd:254` (+2) |  |
| `set_piece_kind` | `""` | String | `scripts/gameplay/match_manager.gd:46` | `scripts/gameplay/match_manager.gd:233`, `scripts/gameplay/match_manager.gd:263` |  |
| `set_piece_team` | `-1` | int | `scripts/gameplay/match_manager.gd:47` | `scripts/gameplay/match_manager.gd:234` |  |
| `training` | `false` | bool | `scripts/gameplay/match_manager.gd:50` | `scripts/gameplay/match_manager.gd:172`, `scripts/gameplay/match_manager.gd:231`, `scripts/gameplay/match_scene.gd:96` | Entrenamiento (sin rivales de campo): los saques siempre los hace el equipo de la persona, salvo el saque de arco del arquero rival; tras un gol vuelve a sacar el equipo de la persona. |
| `set_piece_pos` | `Vector3.ZERO` | Vector3 | `scripts/gameplay/match_manager.gd:51` | `scripts/gameplay/match_manager.gd:235` |  |
| `set_piece_setup_seconds` | `0.9` | float | `scripts/gameplay/match_manager.gd:53` | `scripts/gameplay/match_manager.gd:242` | Segundos de pelota muerta antes de habilitar al ejecutor (la escena coloca a los jugadores). |
| `stats` | `{"throw_in": 0, "corner": 0, "goal_kick": 0, "free_kick": 0, "penalty": 0}` |  | `scripts/gameplay/match_manager.gd:56` | `scripts/gameplay/match_manager.gd:150`, `scripts/gameplay/match_manager.gd:238` |  |
| `_state_before_pause` | `State.PLAYING` | State | `scripts/gameplay/match_manager.gd:57` | `scripts/gameplay/match_manager.gd:80`, `scripts/gameplay/match_manager.gd:93`, `scripts/gameplay/match_manager.gd:95` |  |
| `_last_touch_time_by_actor` | `{}` | Dictionary | `scripts/gameplay/match_manager.gd:58` | `scripts/gameplay/match_manager.gd:273`, `scripts/gameplay/match_manager.gd:291` |  |
| `_last_scoring_team` | `0` | int | `scripts/gameplay/match_manager.gd:176` | `scripts/gameplay/match_manager.gd:172`, `scripts/gameplay/match_manager.gd:294` |  |
<!-- /AUTO -->

<!-- AUTO:params:MatchScene -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `duration_seconds` | `-1.0` | float | `scripts/gameplay/match_scene.gd:9` | `scripts/gameplay/match_scene.gd:61`, `scripts/gameplay/match_scene.gd:62`, `scripts/gameplay/match_scene.gd:65`, `scripts/gameplay/match_scene.gd:95` | Duracion del partido (s). Negativo = la que eligio la persona (3, 5, 7 o 10 minutos, ver Tuning.match_minutes). |
| `home_field_players` | `4` | int | `scripts/gameplay/match_scene.gd:11` | `scripts/gameplay/match_scene.gd:158` | Cantidad de futbolistas de campo por equipo en esta etapa (1 = etapa inicial). |
| `away_field_players` | `4` | int | `scripts/gameplay/match_scene.gd:12` | `scripts/gameplay/match_scene.gd:64`, `scripts/gameplay/match_scene.gd:165` |  |
| `auto_switch` | `true` | bool | `scripts/gameplay/match_scene.gd:14` | `scripts/gameplay/match_scene.gd:623` | Cambia solo al jugador del humano mas cercano a la pelota cuando el actual queda lejos. |
| `ai_skill` | `0.6` | float | `scripts/gameplay/match_scene.gd:16` | `scripts/gameplay/match_scene.gd:160`, `scripts/gameplay/match_scene.gd:167`, `scripts/gameplay/match_scene.gd:656`, `scripts/gameplay/match_scene.gd:678` (+1) | Calidad de decision de la IA (0..1). |
| `intro_seconds` | `4.5` | float | `scripts/gameplay/match_scene.gd:18` | `scripts/gameplay/match_scene.gd:66`, `scripts/gameplay/match_scene.gd:97` | Presentacion antes del primer saque (s): calentamiento de los jugadores y arbitro contando. 0 = sin presentacion. |
| `with_referee` | `true` | bool | `scripts/gameplay/match_scene.gd:19` | `scripts/gameplay/match_scene.gd:87` |  |
| `out_of_bounds` | `true` | bool | `scripts/gameplay/match_scene.gd:22` | `scripts/gameplay/match_scene.gd:72`, `scripts/gameplay/match_scene.gd:92` | Reglas de futbol con bandas: la pelota sale y se repone (saque de banda, corner, saque de arco). Con false, cancha cerrada con paredes (la pelota rebota y nunca sale). |
| `referee` | `null` | Referee | `scripts/gameplay/match_scene.gd:23` | `scripts/gameplay/match_scene.gd:88`, `scripts/gameplay/match_scene.gd:89`, `scripts/gameplay/match_scene.gd:90`, `scripts/gameplay/match_scene.gd:92` (+2) |  |
| `replay` | `null` | GoalReplay | `scripts/gameplay/match_scene.gd:25` | `scripts/gameplay/match_scene.gd:255`, `scripts/gameplay/match_scene.gd:256`, `scripts/gameplay/match_scene.gd:257`, `scripts/gameplay/match_scene.gd:265` (+7) | Repeticion de los goles (graba siempre; se muestra tras cada gol). |
| `goal_replays` | `true` | bool | `scripts/gameplay/match_scene.gd:26` | `scripts/gameplay/match_scene.gd:266`, `scripts/gameplay/match_scene.gd:285` |  |
| `training_mode` | `false` | bool | `scripts/gameplay/match_scene.gd:29` | `scripts/gameplay/match_scene.gd:29`, `scripts/gameplay/match_scene.gd:63`, `scripts/gameplay/match_scene.gd:96`, `scripts/gameplay/match_scene.gd:100` (+2) | Entrenamiento: tu equipo (con su arquero) contra el arquero rival SOLO, sin rivales de campo ni reloj, para probar conduccion, pases y tiros al arco. Se elige en el menu de pausa y se mantiene al reiniciar la escena. |
| `ctx` | `—` | MatchContext | `scripts/gameplay/match_scene.gd:31` | `scripts/gameplay/match_scene.gd:67`, `scripts/gameplay/match_scene.gd:78`, `scripts/gameplay/match_scene.gd:79`, `scripts/gameplay/match_scene.gd:84` (+28) |  |
| `pitch` | `—` | Pitch | `scripts/gameplay/match_scene.gd:32` | `scripts/gameplay/match_scene.gd:68`, `scripts/gameplay/match_scene.gd:69`, `scripts/gameplay/match_scene.gd:70`, `scripts/gameplay/match_scene.gd:73` (+10) |  |
| `ball` | `—` | Ball | `scripts/gameplay/match_scene.gd:33` | `scripts/gameplay/match_scene.gd:57`, `scripts/gameplay/match_scene.gd:74`, `scripts/gameplay/match_scene.gd:75`, `scripts/gameplay/match_scene.gd:76` (+20) |  |
| `camera` | `—` | MatchCamera | `scripts/gameplay/match_scene.gd:34` | `scripts/gameplay/match_scene.gd:81`, `scripts/gameplay/match_scene.gd:82`, `scripts/gameplay/match_scene.gd:83`, `scripts/gameplay/match_scene.gd:84` (+15) |  |
| `manager` | `—` | MatchManager | `scripts/gameplay/match_scene.gd:35` | `scripts/gameplay/match_scene.gd:93`, `scripts/gameplay/match_scene.gd:94`, `scripts/gameplay/match_scene.gd:95`, `scripts/gameplay/match_scene.gd:96` (+16) |  |
| `presentation` | `null` | MatchPresentation | `scripts/gameplay/match_scene.gd:36` | `scripts/gameplay/match_scene.gd:101`, `scripts/gameplay/match_scene.gd:102`, `scripts/gameplay/match_scene.gd:103`, `scripts/gameplay/match_scene.gd:104` |  |
| `hud` | `—` | Hud | `scripts/gameplay/match_scene.gd:37` | `scripts/gameplay/match_scene.gd:107`, `scripts/gameplay/match_scene.gd:108`, `scripts/gameplay/match_scene.gd:109`, `scripts/gameplay/match_scene.gd:110` (+17) |  |
| `controlled` | `null` | Footballer | `scripts/gameplay/match_scene.gd:38` | `scripts/gameplay/match_scene.gd:135`, `scripts/gameplay/match_scene.gd:173`, `scripts/gameplay/match_scene.gd:174`, `scripts/gameplay/match_scene.gd:358` (+42) |  |
| `home` | `[]` | Array[Footballer] | `scripts/gameplay/match_scene.gd:39` | `scripts/gameplay/match_scene.gd:163`, `scripts/gameplay/match_scene.gd:172`, `scripts/gameplay/match_scene.gd:173`, `scripts/gameplay/match_scene.gd:240` (+19) |  |
| `away` | `[]` | Array[Footballer] | `scripts/gameplay/match_scene.gd:40` | `scripts/gameplay/match_scene.gd:170`, `scripts/gameplay/match_scene.gd:240`, `scripts/gameplay/match_scene.gd:243`, `scripts/gameplay/match_scene.gd:259` (+6) |  |
| `keepers` | `[]` | Array[Goalkeeper] | `scripts/gameplay/match_scene.gd:41` | `scripts/gameplay/match_scene.gd:184`, `scripts/gameplay/match_scene.gd:261`, `scripts/gameplay/match_scene.gd:306`, `scripts/gameplay/match_scene.gd:431` |  |
| `marker` | `null` | PlayerMarker | `scripts/gameplay/match_scene.gd:43` | `scripts/gameplay/match_scene.gd:127`, `scripts/gameplay/match_scene.gd:128`, `scripts/gameplay/match_scene.gd:590`, `scripts/gameplay/match_scene.gd:591` | Indicadores sobre el jugador controlado y sobre el que recibiria el control con CAMBIO. |
| `next_marker` | `null` | PlayerMarker | `scripts/gameplay/match_scene.gd:44` | `scripts/gameplay/match_scene.gd:129`, `scripts/gameplay/match_scene.gd:130`, `scripts/gameplay/match_scene.gd:592` |  |
| `possession_ring` | `null` | GroundRing | `scripts/gameplay/match_scene.gd:46` | `scripts/gameplay/match_scene.gd:131`, `scripts/gameplay/match_scene.gd:132`, `scripts/gameplay/match_scene.gd:566`, `scripts/gameplay/match_scene.gd:570` (+1) | Aro de posesion (bajo el unico jugador con la pelota) y aro del companero que recibiria el pase ahora. |
| `pass_ring` | `null` | GroundRing | `scripts/gameplay/match_scene.gd:47` | `scripts/gameplay/match_scene.gd:133`, `scripts/gameplay/match_scene.gd:134`, `scripts/gameplay/match_scene.gd:582` |  |
| `controlled_keeper` | `null` | Goalkeeper | `scripts/gameplay/match_scene.gd:51` | `scripts/gameplay/match_scene.gd:358`, `scripts/gameplay/match_scene.gd:427`, `scripts/gameplay/match_scene.gd:437`, `scripts/gameplay/match_scene.gd:451` (+13) | Arquero propio bajo control de la persona (null = lo lleva la IA). Mientras lo maneja, el jugador de campo `controlled` queda en manos de la IA pero se recuerda para devolverle el control. |
| `debug_overlay` | `null` | AnimDebugOverlay | `scripts/gameplay/match_scene.gd:53` | `scripts/gameplay/match_scene.gd:114`, `scripts/gameplay/match_scene.gd:115`, `scripts/gameplay/match_scene.gd:116`, `scripts/gameplay/match_scene.gd:117` | Overlay de depuracion de animaciones (solo compilaciones de depuracion; null en la APK de produccion). |
| `with_keepers` | `true` | bool | `scripts/gameplay/match_scene.gd:55` | `scripts/gameplay/match_scene.gd:175` | Con false no se crean arqueros (algunas pruebas y la practica los omiten). |
| `_last_kick_actor` | `-1` | int | `scripts/gameplay/match_scene.gd:526` | `scripts/gameplay/match_scene.gd:449`, `scripts/gameplay/match_scene.gd:539` |  |
| `_last_kick_frame` | `-1000` | int | `scripts/gameplay/match_scene.gd:527` | `scripts/gameplay/match_scene.gd:450`, `scripts/gameplay/match_scene.gd:539` |  |
| `_switch_cooldown` | `0.0` | float | `scripts/gameplay/match_scene.gd:550` | `scripts/gameplay/match_scene.gd:468`, `scripts/gameplay/match_scene.gd:597`, `scripts/gameplay/match_scene.gd:623`, `scripts/gameplay/match_scene.gd:661` (+2) |  |
<!-- /AUTO -->

`MatchScene.duration_seconds` (300) se copia a `MatchManager.duration_seconds` en `_ready`; **el valor efectivo es el de la escena**. `0` = sin límite (lo usan las pruebas).

### Riesgos al modificar

| Elemento | Efecto real y riesgo |
|---|---|
| `duration_seconds` | *test_pause_and_full_time (eliminada en la reforma)* usa 3 s y espera `FULL_TIME` a los 3.5 s. |
| `goal_celebration_seconds` (3), `pre_kickoff_seconds` (1.2) | Tiempo con `input_enabled = false`. |
| `assist_window_seconds` (6) | Un pase solo cuenta como asistencia si el pasador tocó la pelota hace ≤ 6 s (`_last_touch_time_by_actor`). |
| `home_field_players` / `away_field_players` | 4 por defecto. Los jugadores que no controla el humano usan `AIInput` (roles cierre/alas/pivote); con `InputSource` vacío se quedarían quietos. Las pruebas de flujo los ponen a 1/0 y desactivan arqueros, árbitro y presentación. |
| `MatchScene.kickoff_positions` | Formación de saque de 4 jugadores por equipo (cierre, alas, pivote); los arqueros van a su arco. |
| Orden de señales `goal_scored` → `score_changed` → mensaje → evento `GOAL` | `Hud` se suscribe a `score_changed`, `clock_changed`, `message`, `state_changed`. |

## Mapa de funciones

<!-- AUTO:funcs:scripts/gameplay/match_manager.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `MatchManager.setup(context: MatchContext)` | 60 |  |
| `MatchManager.start_match()` | 67 |  |
| `MatchManager.restart_play()` | 78 | Reinicia la jugada actual (sin tocar el marcador): saque de centro del mismo equipo. |
| `MatchManager.restart_match()` | 84 |  |
| `MatchManager.toggle_pause()` | 88 |  |
| `MatchManager.is_playing()` | 99 |  |
| `MatchManager._begin_kickoff(team: int, intro: bool = false)` | 102 |  |
| `MatchManager._physics_process(delta: float)` | 118 |  |
| `MatchManager._manager_step(delta: float)` | 123 |  |
| `MatchManager._check_out_of_play()` | 183 | Con bandas (OUT_OF_BOUNDS): la pelota que cruza COMPLETAMENTE una linea queda fuera. Banda -> saque de banda para el rival del ultimo que la |
| `MatchManager._on_event(e: GameEvent)` | 210 | Falta: tiro libre para el equipo del jugador derribado, o penal si fue dentro del area del equipo infractor. |
| `MatchManager.in_penalty_area(p: Vector3, goal_x: float, cfg: PitchConfig)` | 224 | Area de penal de futsal: a menos de penalty_area_radius de la linea entre postes, del lado de la cancha. |
| `MatchManager._begin_set_piece(kind: String, team: int, pos: Vector3)` | 230 |  |
| `MatchManager._set_piece_taken()` | 250 |  |
| `MatchManager._end_set_piece()` | 258 |  |
| `MatchManager.is_set_piece()` | 267 |  |
| `MatchManager._on_ball_touched(actor: Node)` | 270 |  |
| `MatchManager._on_goal(goal: Goal, _ball_pos: Vector3)` | 275 |  |
| `MatchManager._set_state(s: State)` | 305 |  |
| `MatchManager.format_clock(seconds: float)` | 309 |  |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/gameplay/match_manager.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `MatchManager.state_changed(new_state: int)` | 8 | Reglas y flujo del partido: saque, juego, gol (la pelota cruza COMPLETAMENTE la linea), celebracion, reinicio de jugada / partido, pausa y fin de tiempo. No crea ni mueve entidades por si mismo: pide a la escena que las reposicione mediante la senal kickoff_requested. Pensado para que un servidor autoritativo pueda ejecutar este mismo codigo. |
| `MatchManager.score_changed(home: int, away: int)` | 9 |  |
| `MatchManager.goal_scored(team: int, scorer_id: int, assist_id: int, own_goal: bool)` | 10 |  |
| `MatchManager.kickoff_requested(kicking_team: int)` | 11 |  |
| `MatchManager.message(text: String, seconds: float)` | 12 |  |
| `MatchManager.clock_changed(seconds: float)` | 13 |  |
| `MatchManager.set_piece_requested(kind: String, team: int, pos: Vector3)` | 16 | Balon parado: la escena coloca al ejecutor y a los demas. kind: "throw_in", "corner", "goal_kick", "free_kick", "penalty"; team: equipo que saca; pos: punto del saque. |
| `MatchManager.replay_requested` | 18 | La escena muestra la repeticion del gol (pausa la simulacion mientras dura). |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/gameplay/match_scene.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `MatchScene._ready()` | 60 |  |
| `MatchScene._spawn_teams()` | 156 |  |
| `MatchScene._seed_ai(f: Footballer, id: int)` | 186 |  |
| `MatchScene._make_footballer(team: int, id: int, source: InputSource)` | 190 |  |
| `MatchScene._exit_tree()` | 199 |  |
| `MatchScene._on_quit_requested()` | 203 | Con el partido como escena actual, «Salir» cierra el juego; si lo aloja otro nodo (pruebas) solo avisa. |
| `MatchScene._on_training_toggle()` | 209 | Cambia entre partido normal y entrenamiento y vuelve a montar la escena. |
| `MatchScene._on_gameplay_mode_changed()` | 216 | Otro modo de jugabilidad: se vuelve a montar la escena (modelos y clips del modo). |
| `MatchScene._on_practice_requested()` | 222 | Abre la sala de practica (galeria de animaciones y malabares) y vuelve aqui con «Volver». |
| `MatchScene.kickoff_positions(team: int, kicking: bool = true)` | 230 | Formacion de saque: 4 jugadores de campo por equipo (cierre, alas, pivote); los arqueros van a su arco. El equipo que saca coloca a su pivot |
| `MatchScene._on_kickoff_requested(kicking_team: int)` | 239 |  |
| `MatchScene._setup_replay()` | 254 |  |
| `MatchScene.score_total_consistent()` | 281 | Comprobacion de coherencia (pruebas): el marcador suma los goles del partido. |
| `MatchScene._on_replay_requested()` | 284 |  |
| `MatchScene._on_set_piece_requested(kind: String, team: int, pos: Vector3)` | 296 | Prepara un balon parado: ejecutor (el mas cercano del equipo que saca; el arquero en el saque de arco), pelota en su sitio y rivales a dista |
| `MatchScene._focus_after_set_piece(taker: Footballer)` | 362 |  |
| `MatchScene._clear_zone(pos: Vector3, team: int, radius: float, except: Footballer = null)` | 370 | Aleja a los rivales del equipo que saca a `radius` metros de la pelota (direccion radial, dentro de la cancha). `except`: jugador que no se  |
| `MatchScene._arrange_box(kind: String, team: int, pos: Vector3, taker: Footballer)` | 385 | Jugada ensayada en el area rival: atacantes a primer palo, segundo palo, punto de penal y borde del area; cada defensor marca a uno por el l |
| `MatchScene.human_actor()` | 426 | Nodo que maneja la persona ahora mismo: el arquero si lo ha tomado, si no el jugador de campo. Lo usan la camara y los indicadores. |
| `MatchScene.own_keeper()` | 430 | Arquero propio (el que defiende el arco de este equipo). |
| `MatchScene._charge_state()` | 436 |  |
| `MatchScene._on_match_event(e: GameEvent)` | 447 | Con un pase de la persona el control pasa al RECEPTOR en el momento del pase (como en los juegos de futbol de consola): la persona maneja a  |
| `MatchScene.pass_receiver(passer: Footballer)` | 483 | Receptor de un pase propio sin destinatario: el companero (no el pasador) que llega antes a algun punto de la trayectoria predicha de la pel |
| `MatchScene._teammate_with_ball()` | 529 |  |
| `MatchScene.touch_context()` | 554 | Situacion para la botonera tactil: ataque (la pelota es del equipo de la persona o le llega un pase propio), defensa (la tiene el rival) o s |
| `MatchScene._update_rings()` | 565 | Aro de posesion bajo el poseedor (color de su equipo; sin aro = pelota suelta) y, con la pelota en los pies de la persona, aro bajo el compa |
| `MatchScene._physics_process(delta: float)` | 584 |  |
| `MatchScene._scene_step(delta: float)` | 589 |  |
| `MatchScene._person_plays()` | 628 | true si una persona maneja al equipo 0 (jugador de campo o arquero). Las pruebas que dejan al equipo 0 en manos de la IA le ponen un AIInput |
| `MatchScene._ball_in_own_third()` | 634 | true si la pelota esta en el tercio defensivo propio (zona donde tiene sentido manejar al arquero). |
| `MatchScene._keeper_is_best_candidate()` | 639 | true si al pulsar CAMBIO conviene pasar al arquero: la jugada esta en el area propia y el arquero es quien mejor puede intervenir (mas cerca |
| `MatchScene.take_keeper_control()` | 651 | Pasa el control de la persona al arquero propio: el jugador de campo que llevaba vuelve a la IA. |
| `MatchScene.release_keeper_control()` | 667 | Devuelve el control a un jugador de campo (el mas cercano a la pelota) y el arquero vuelve a la IA. |
| `MatchScene.switch_candidate()` | 689 | Companero que recibiria el control al pulsar CAMBIO: el mas cercano a la pelota, sin contar al actual. Lo usan tanto el cambio como el indic |
| `MatchScene.switch_to_nearest_to_ball()` | 702 | Pasa el control humano al companero mas cercano a la pelota (distinto del actual). |
| `MatchScene._auto_switch()` | 707 |  |
| `MatchScene._give_control(target: Footballer)` | 725 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/gameplay/match_context.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `MatchContext.update_possession()` | 37 | Actualiza el dueno de la pelota (una vez por paso de fisica, la llame quien la llame). |
| `MatchContext.ball_is_loose()` | 66 | Pelota sin dueno (rodando, en el aire, rebote): cualquiera puede ir a buscarla y tocarla. |
| `MatchContext.ball_locked_for(who: Node)` | 75 | true si `who` no puede tocar la pelota ahora (balon parado de otro). |
| `MatchContext.update_ball_stall(delta: float)` | 79 | Actualiza el contador de pelota muerta (lo llama MatchManager cada paso de fisica mientras se juega). |
| `MatchContext.emit_event(e: GameEvent)` | 85 |  |
| `MatchContext.register_footballer(f: Footballer)` | 90 |  |
| `MatchContext.unregister_footballer(f: Footballer)` | 94 |  |
| `MatchContext.teammates_of(p: Footballer)` | 97 |  |
| `MatchContext.opponents_of(p: Footballer)` | 104 |  |
| `MatchContext.opponents_of_team(team: int)` | 111 |  |
| `MatchContext.attacking_goal(team: int)` | 119 | Arco que ataca un equipo: el equipo 0 ataca +X. |
| `MatchContext.defending_goal(team: int)` | 122 |  |
| `MatchContext.register_keeper(k: Node)` | 125 |  |
| `MatchContext.unregister_keeper(k: Node)` | 129 |  |
| `MatchContext.keeper_defending(team: int)` | 132 |  |
| `MatchContext.nearest_footballer(pos: Vector3, team: int = -1, exclude: Footballer = null)` | 139 | Jugador (no arquero) del equipo dado mas cercano a un punto. |
| `MatchContext.screen_to_world(v: Vector2)` | 152 | Convierte un vector 2D de pantalla en direccion de mundo usando la camara si existe. |
<!-- /AUTO -->

## Recorrido de ejecución

**Arranque** (`MatchScene._ready`): `Pitch.build(Tuning.pitch)` → `Ball` en `(0, 0.2, 0)` → `MatchCamera` → equipos (`_spawn_teams`: atributos neutros `PlayerAttributes.reset_to(55)`, el primero de casa con `HumanInput`) → `MatchManager.setup(ctx)` (conecta `Pitch.goal_scored` y `Ball.touched`) → `Hud` (`bind`) → `camera.setup` → `GraphicsSettings.apply()` → `manager.start_match()`.

**Saque:** `_begin_kickoff(team)`: `input_enabled = false`, `Pitch.reset_goal_latches()`, estado `PRE_KICKOFF` durante `pre_kickoff_seconds`, señal `kickoff_requested` → `MatchScene._on_kickoff_requested`: `ball.reset_at((0, 0.11, 0))`, `place_at` de cada futbolista (equipo 0 mira a +X), `camera.snap_to_target()`. Al acabar el temporizador: `input_enabled = true`, estado `PLAYING`. El equipo que saca se registra en `kickoff_team` y en el evento, pero **las posiciones no dependen de quién saca**.

**Gol** (`_on_goal`, solo en `PLAYING`): el equipo anotador es el que ataca ese arco (arco `+X` → equipo 0). Gol en contra si el último toque fue de un equipo distinto del anotador. Asistencia: `previous_toucher` del equipo anotador, distinto del goleador y dentro de la ventana. Sube el marcador, `input_enabled = false`, estado `GOAL` durante `goal_celebration_seconds`, mensaje «¡GOL!», evento `GOAL`, y el siguiente saque lo hace el equipo que recibió el gol (`1 − _last_scoring_team`).

**Fin:** al llegar `match_time ≥ duration_seconds` (si > 0): estado `FULL_TIME`, `input_enabled = false`, mensaje con el marcador 6 s, evento `MATCH_END`.

**Pausa:** `toggle_pause` (tecla Esc, botón táctil «II», o `Hud`): `get_tree().paused`, estado `PAUSED`; restaura el estado anterior al reanudar. `MatchManager` es `PROCESS_MODE_PAUSABLE`; `Hud` y `TouchControls` son `ALWAYS`.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh match_flow`.
- **Última ejecución (2026-10-26):** 6 pruebas / 28 comprobaciones sin fallos (suite completa: 57 / 212).

*Pruebas de test_match_flow: eliminadas en la reforma (modo de fútbol 5 quitado; en el historial de git).*

- **Qué podría romperse:** gol que se cuenta dos veces (se controla con `Pitch.reset_goal_latches` y el estado `PLAYING`), gol en contra mal atribuido, reloj que avanza en pausa, jugadores que no vuelven a su sitio tras un gol.

## Saque inicial y cambio de jugador

- **Saque:** `MatchScene.kickoff_positions(team, kicking)` coloca al pivote del equipo que saca a `KICKOFF_TAKER_X`
  = 0.62 m de la pelota (puede jugarla de inmediato) y al rival más adelantado a `KICKOFF_WAIT_X` = 3.4 m (fuera del
  círculo central). Medido: ejecutor a 0.62 m, rival más cercano a 3.40 m, y la pelota se pone en juego en los
  primeros 5 s (*tests/test_control_and_keeper.gd (eliminada en la reforma; en el historial de git)*).
- **Cambio:** `switch_candidate()` es el compañero más cercano a la pelota y lo usan tanto el botón CAMBIO como el
  indicador del siguiente jugador, así que ambos señalan siempre al mismo. Con la jugada en el tercio defensivo
  propio, CAMBIO pasa al **arquero** (`take_keeper_control`) si es quien mejor puede intervenir.
- **La persona controla todo con la pelota (2026-10-27, pedido del usuario):**
  - Todo pase propio (raso, elevado, filtrado, centro, saque de banda) pasa el control al **receptor en el momento
    del pase** (`MatchScene._on_match_event`). Sin destinatario asignado (pase al espacio), recibe el compañero que
    llega antes a la trayectoria predicha (`MatchScene.pass_receiver`, `BallPredictor`), y se le marca el pase entrante
    (`Footballer.expect_pass(..., from)`).
  - Mientras el pase va hacia el controlado no hay cambio automático (`_auto_switch` respeta `has_incoming_pass()`):
    antes, en un pase largo, el control volvía al pasador o a otro compañero más cerca de la pelota durante el vuelo y
    el receptor quedaba en manos de la IA (medido: 60 pasos de física con el control en otro jugador en un pase de 18 m;
    ahora 0).
  - Si un compañero se queda con la pelota (control, rebote, intercepción, pase del arquero) el control pasa a él en
    el acto (`_teammate_with_ball`, también con `auto_switch` apagado; no al pasador en los 45 pasos tras su propio
    golpeo ni con la pelota pasando rápido, `HANDOVER_MAX_REL_SPEED`).
  - La IA del equipo de la persona nunca pasa ni patea: `MatchContext.human_team` (0 si la persona maneja un
    jugador o al arquero, −1 si no; `MatchScene._person_plays` mira la entrada real, no `is_human_controlled`, porque
    las pruebas que dejan el equipo 0 a la IA ponen un `AIInput` al controlado y los saques lo pasan de jugador en
    jugador marcándolo como controlado: con la primera versión la pelota quedó quieta 311 s en el partido de 7 min de
    la CI) y `AIInput._decide` no decide con la pelota para ese equipo; `_give_control` cancela cualquier carga que la
    IA hubiera empezado en el receptor.
  - Pruebas: *tests/test_pass_receiver_control.gd (eliminada en la reforma; en el historial de git)* (las tres primeras fallan con el código anterior).

## Limitaciones conocidas

- **«Salir» no hace nada:** `Hud.quit_requested` → `MatchScene.quit_requested`, pero **nadie conecta esa señal** ni llama a `get_tree().quit()`. En un móvil no hay salida desde el menú.
- **Tras `FULL_TIME` no hay salida de la pantalla:** `toggle_pause` ignora el estado `FULL_TIME` (no se puede abrir el menú de pausa para «Reiniciar partido») y no existe pantalla de resultado. Verificado leyendo el código; la prueba *test_pause_and_full_time (eliminada en la reforma)* solo comprueba que el partido termina y la entrada se bloquea.
- Sin reglas de saque de banda, córner, tiro libre, falta, tarjetas ni sustituciones: la pelota rebota en las paredes (ver [PITCH](PITCH.md)).
- La IA (`AIInput`) es simple: decide cada 0.12 s con reglas (tiro solo con ángulo de arco ≥ 16° y sin rival a menos de 0.95 m de la pelota, pase por presión o a un compañero libre, barullo resuelto tras 0.9 s despejando, un único portador por equipo) y no se ha calibrado contra jugadores humanos. Medido con 3 partidos de 120 s: la pelota nunca queda quieta más de ~2 s en juego y ~29 % de sus patadas se pierden por un toque rival o de un compañero (*test_ai_match (eliminada en la reforma)*). Sin estadísticas por jugador: los eventos se emiten pero nadie los agrega.
- `MatchContext.keepers` nunca se rellena (no hay arquero; ver [GOALKEEPER](GOALKEEPER.md)).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Partido jugable».

## Bandas, balón parado y repetición (2026-10-27)

- **Bandas:** `MatchScene.out_of_bounds` (por defecto `true`) construye la cancha con `PitchConfig.BoundaryMode.OUT_OF_BOUNDS`: las paredes se retiran `run_off` m y `MatchManager._check_out_of_play` detecta la pelota que cruza COMPLETAMENTE una línea (un gol nunca cuenta como fuera). Banda → saque de banda para el rival del último que la tocó; fondo → córner si la tocó el defensor, saque de arco si fue el atacante.
- **Faltas:** el evento `FOUL` (barrida al cuerpo, entrada por detrás) da tiro libre o penal (`MatchManager.in_penalty_area`).
- **Balón parado:** estado `SET_PIECE`; la escena elige ejecutor, aleja a los rivales 5 m (`_clear_zone`) y ordena el área en córner, penal y tiro libre cercano (`_arrange_box`). `SetPiece` ejecuta con clips de raíz real y el juego se reanuda cuando la pelota sale del pie o de las manos. Salvaguardas: al segundo golpe fallido se saca sin carrera y, si en 20 s no se sacó, `SetPiece.force`.
- **Pelota muerta:** `MatchContext.dead_ball` / `restart_taker`: solo el ejecutor puede tocarla; la IA se ofrece o marca a distancia (`AIInput._decide_dead_ball`).
- **Repetición:** `GoalReplay` graba 7 s a 30 Hz (pelota, jugadores, arqueros, árbitro y la pose de cada hueso). `MatchManager.replay_requested` se emite `replay_after_seconds` tras el gol; la escena pausa el árbol, reproduce 4.5 s antes del gol + 0.7 s después a 0.6x con su cámara y restaura el estado exacto. Cualquier botón o toque la salta.
- **Duración:** `MatchScene.duration_seconds < 0` usa `Tuning.match_minutes` (3, 5, 7 o 10; menú de pausa).
- Pruebas: *test_set_pieces (eliminada en la reforma)*, *test_goal_replay (eliminada en la reforma)*, *test_full_match (eliminada en la reforma)* (partidos completos de 3, 5, 7 y 10 minutos).

## Posesión única y organización colectiva (2026-10-27)

- **`MatchContext.possessor`** (`update_possession`, una vez por paso de física): el último que la tocó la conserva
  mientras nadie más la toque y siga a ≤1.45 × su radio de posesión; si no, es suya solo si la tiene al pie y va con
  ella. `BallHandler.ball_owned_by_other` impide conducir o controlar la pelota de otro (solo disputarla o cortar un
  toque largo); `PressController` presiona al poseedor.
- **`TeamBrain`** (`scripts/ai/team_brain.gd`): una decisión por equipo cada 0.2 s. Ataque: apoyo (6.5 m, línea de pase
  libre), amplitud (banda contraria, lado con histéresis), profundidad (altura del último rival) y seguridad; en zona de
  centro, primer palo / segundo palo / penal. Defensa: un presionador (si es el de la persona, la IA no manda otro),
  una cobertura (el que llega antes al punto entre la pelota y el arco, a 6.5 m) y el bloque a ≥5 m de la pelota con la
  línea que retrocede. Pelota suelta: va uno por equipo. Reparto de puestos por coste mínimo con ventaja para conservar
  el puesto anterior (`KEEP_ROLE_BONUS`). La fase de ataque se mantiene durante un toque largo propio
  (`TEAM_POSSESSION_GRACE`). `AIInput._follow_order` ejecuta la orden (los desmarques de ruptura y las llegadas al
  área siguen siendo individuales); `AIInput.use_team_brain = false` vuelve a la lógica individual.
- **Decisiones de la IA:** el defensor contiene y entra cuando la pelota queda expuesta (toque largo) o con
  probabilidad `Footballer.AI_TACKLE_COMMIT`; el portador presionado pasa con el cuerpo a medio orientar (≤75°);
  la IA no sale de la cancha (`Footballer._keep_inside`) y rodea el arco si queda detrás de la línea
  (`AIInput._around_goal`).
- **Medido** (*test_team_shape_metrics (eliminada en la reforma)*, `tests/match_metrics.gd`): con la fase asentada (>2 s) cada jugador está a
  2.7–4.6 m de su puesto, pero la posesión cambia cada ~1.9 s y el amontonamiento (≥4 jugadores a <4 m de la pelota)
  no bajó de forma clara (headless 41–49 %; versión anterior con render 33–55 %). Pendiente: reducir las pérdidas.

## Modo entrenamiento (2026-10-27)

Menú de pausa → «Entrenamiento sin rivales» (`MatchScene.training_mode`, se mantiene al reiniciar la escena; «Volver
al partido» lo quita). Tu equipo (4 + arquero) contra el arquero rival solo: sin rivales de campo, sin reloj que
termine, saques siempre para tu equipo salvo el saque de arco del arquero rival (`MatchManager.training`), y tras un
gol vuelve a sacar tu equipo. Sirve para probar conducción, pases y tiros al arco/arquero. Prueba:
*test_training_mode (eliminada en la reforma)* (150 s con la IA: pases, llegadas al arco, atajadas, sin atascos).

## IA sin persona: el «controlado» también recibe órdenes (2026-10-31)

`TeamBrain.person_drives(f)`: un jugador lo maneja una persona solo si es el controlado **y** su entrada no es un
`AIInput`. Sin persona (`ctx.human_team == -1`), el control lo lleva un `AIInput` y el cerebro ahora le da órdenes de pelota
suelta y de presión (`TeamBrain._loose`, `_defend`) y `AIInput` lo cuenta como candidato a ir a buscarla. Antes, si el más
cercano a una pelota suelta era el controlado, nadie iba: medido en el entrenamiento sin persona, 1 de cada 14 partidos de
25 s con la pelota quieta 7.3 s (*test_pass_receiver_control::test_ai_teams_still_play_without_a_human (eliminada en la reforma)* falló así en
GitHub Actions); tras el arreglo, 0 de 20.

## Zona libre del saque: nadie salvo el ejecutor en la carrerilla (2026-10-31)

Regla: mientras dura un saque con el pie (tiro libre, corner, penal), nadie salvo el ejecutor entra a menos de
`SetPiece.CLEAR_RADIUS` (4 m: carrerilla máxima `RUNUP_MAX` 2.6 m + contacto a un costado ~0.7 m + medio cuerpo) de la
pelota; los rivales, además, a la distancia reglamentaria (5 m).

Qué fallaba (medido): un compañero se acercaba a 1.8-1.9 m de la pelota y se metía en la carrera del ejecutor, que se
desviaba y no llegaba a la pelota (tiro libre, 2 de 38 clips; falló en GitHub Actions). Tres causas:
1. `AIInput._decide_dead_ball`: los rivales se quedaban a 5.2 m, pero los compañeros iban al apoyo corto
   (`_support_spot`) sin distancia mínima a la pelota.
2. Al pedir el saque solo se despejaba a los rivales; los compañeros que venían a la carrera seguían con la inercia (y con
   un giro de clip a medias) durante la preparación, con la entrada desactivada.
3. La IA comprobaba el destino, no el camino: un rival cruzaba la zona de la pelota (a 2.7 m) camino de su marca.

Arreglos: compañeros con destino fuera de `CLEAR_RADIUS` y, si ya están cerca, salida en línea recta; rivales que están
dentro salen en línea recta; `AIInput._around_ball`: con la pelota muerta nadie atraviesa la zona, la rodea;
`MatchScene._on_set_piece_requested` para a todos salvo el ejecutor y despeja también a los compañeros
(`_clear_zone(..., except)`); el apoyo corto del tiro libre cercano se coloca a `CLEAR_RADIUS + 0.5`. Prueba:
*test_set_pieces::test_nobody_but_the_taker_enters_the_run_up_zone (eliminada en la reforma)* (tiro libre en el medio, cerca del área y corner:
el más cercano queda a 4.2-4.8 m). Los 38 clips de balón parado conectan en el tiro libre sin ningún atajo de colisiones.

## IA con los parámetros de UCS (2026-11-06)

`UcsParams` (`scripts/ai/ucs_params.gd`) lee los valores de la función de `libMPX.so` (UCS 1.810) que carga la
configuración de juego. Cada parámetro se pide por nombre, con un valor por defecto entero; las escalas van en punto fijo
4096 = 1.0. Tabla completa (210): [`E4_parametros_ucs.csv`](../../fases/E4_parametros_ucs.csv).

- **Comprobado:** el valor.
- **Inferido:** el significado y la unidad, por el nombre y por cómo encaja en el juego.
- **Sin comprobar:** el servidor de UCS podría cambiar algún valor; sin conexión no se puede verificar.

| UCS | valor | en nuestra IA |
|---|---|---|
| `MaxActivePresses` / `MaxActiveTackles` | 2 / 1 | La cobertura pasa a segundo presionador si llega en ≤ 1.2 s (`TeamBrain`, rol `press2`). Se coloca a 2.5 m del portador, del lado del arco, y no entra: solo el primer presionador entra. |
| `PressureSpeedRate` | 3891/4096 = 0.95 | **No aplicado.** Probado como velocidad de carrera del que presiona; cambiaba los tiros con un defensor encima (`test_shot_keeper` falló) y su significado es inferido. |
| `WidthOpenPlay` | 60 | La amplitud usa el 60 % del ancho, no pegada a la línea. |
| `BotMinKickFrames` / `BotMaxKickFrames` | 30 / 120 cuadros | El portador de la IA pasa sin presión entre 0.5 y 2 s con la pelota (`CARRY_PATIENCE` 2.2 → 2.0 s; pase de progreso desde 0.5 s, antes 0.6 s). |
| `ResponseGKSave0/1` | 15 / 4 cuadros | **No aplicado.** Probado: sobre nuestro modelo de estirada el arquero atajaba el 87-97 % a 8-11 m y `test_shot_keeper` falló. Sigue la reacción calibrada propia (0.30 a 0.13 s). |

