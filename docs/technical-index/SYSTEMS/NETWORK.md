# NETWORK — Contratos de datos para el modo online (sin red real)

## Identificación

- **Responsabilidad exacta:** los datos puros y serializables que un servidor autoritativo y los clientes intercambiarían: `InputFrame` (intención del jugador, ver [INPUTS](INPUTS.md)), `GameEvent` (hechos del partido) y `BallState` (instantánea de la pelota). Son clases `RefCounted` sin dependencia de nodos ni de la presentación.
- **Estado:** **parcial / solo contratos.** No existe servidor, transporte, replicación, predicción, reconciliación, validación de acciones, reconexión, emparejamiento ni identidad de jugador. No hay `MultiplayerAPI`, `ENet` ni `WebSocket` en el código.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-14
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/network/game_event.gd` | `GameEvent`: tipo, tick, tiempo, actor, equipo y datos; `to_dict`/`from_dict` | `GameEvent.Type`, `GameEvent.make`, `GameEvent.to_dict`, `GameEvent.from_dict` | — |
| `scripts/network/ball_state.gd` | `BallState`: posición, velocidades, orientación, poseedor y último toque | `BallState.to_dict`, `BallState.from_dict` | — |
| `scripts/network/input_frame.gd` | `InputFrame` (ver INPUTS) | `InputFrame.to_dict`, `InputFrame.from_dict` | — |
| `scripts/ball/ball.gd` | Produce `BallState` | `Ball.capture_state` | `BallState` |
| `scripts/player/footballer.gd` | Produce un diccionario de estado del jugador | `Footballer.capture_state` | — |
| `scripts/gameplay/match_context.gd` | Bus de eventos (`event_emitted`) y `tick`/`match_time` | `MatchContext.emit_event` | `GameEvent` |

## Mapa de parámetros

No hay parámetros. Tipos de evento definidos (`GameEvent.Type`), con su **emisor real** hoy:

| Tipo | ¿Se emite? | Quién |
|---|---|---|
| `KICKOFF`, `MATCH_START`, `MATCH_END`, `RESTART`, `GOAL` | sí | `MatchManager` (`scripts/gameplay/match_manager.gd`) |
| `PASS`, `SHOT`, `KICK_WHIFF`, `FIRST_TOUCH`, `TACKLE_WON`, `TACKLE_FAILED` | sí | `BallHandler` (`scripts/player/ball_handler.gd`) |
| `SAVE`, `INTERCEPTION`, `TURNOVER`, `DRIBBLE_ATTEMPT`, `DRIBBLE_COMPLETED`, `FRAME_HIT`, `KEEPER_CATCH`, `KEEPER_DISTRIBUTE` | **definidos, nadie los emite** (verificado con `grep -rn "GameEvent.Type\." scripts`) | — |

## Mapa de funciones

<!-- AUTO:funcs:scripts/network/game_event.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `GameEvent.make(t: Type, actor: int, team_index: int, payload: Dictionary = {})` | 22 |  |
| `GameEvent.type_name()` | 30 |  |
| `GameEvent.to_dict()` | 33 |  |
| `GameEvent.from_dict(d: Dictionary)` | 36 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/network/ball_state.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `BallState.to_dict()` | 15 |  |
| `BallState.from_dict(d: Dictionary)` | 26 |  |
| `BallState._v3(a: Array)` | 38 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/network/input_frame.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `InputFrame.move_length()` | 38 |  |
| `InputFrame.to_dict()` | 41 |  |
| `InputFrame.from_dict(d: Dictionary)` | 51 |  |
<!-- /AUTO -->

## Recorrido de ejecución

- **Eventos:** quien genera un hecho llama `ctx.emit_event(GameEvent.make(Type, actor_id, team, datos))`; `MatchContext.emit_event` rellena `tick` y `match_time` y emite `event_emitted`. **No hay ningún suscriptor** de `event_emitted` en el código del juego (solo lo conectan las pruebas `match_flow`, `passing`, `press` y `kick_timing`; no hay estadísticas ni UI que consuman eventos).
- **Instantánea de la pelota:** `Ball.capture_state(tick)` → `BallState`; ida y vuelta `to_dict`/`from_dict` comprobada en `test_ball_physics`.
- **Entrada:** ver [INPUTS](INPUTS.md).

## Pruebas

- **Ejecutar:** `tools/run_tests.sh ball_physics` (cubre `BallState`) y `tools/run_tests.sh match_flow` (eventos de gol/saque).
- **Última ejecución (2026-10-26):** suite completa 57 pruebas / 212 comprobaciones sin fallos.
- **Alcance real:** solo la ida y vuelta de `BallState` (`BallState.from_dict` en `tests/test_ball_physics.gd`) y la emisión de eventos en el flujo de partido. **`GameEvent.from_dict`/`to_dict` e `InputFrame.from_dict`/`to_dict` no tienen ninguna prueba** (`grep -rn from_dict tests` solo encuentra `BallState`).

## Limitaciones conocidas

- Todo lo de red está **pendiente**: servidor autoritativo, snapshots periódicos, interpolación, predicción del cliente, validación de `InputFrame`, identidad de jugador, reconexión, anti-trampa. La arquitectura lo permite (la lógica de reglas `MatchManager` no depende de nodos de escena), pero no hay nada ejecutable.
- `Footballer.capture_state` devuelve un `Dictionary` sin clase propia (no existe `PlayerState`).
- `BallState.holder_id` refleja quién sostiene la pelota (el arquero la sostiene con `Ball.hold`).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Base del juego».
