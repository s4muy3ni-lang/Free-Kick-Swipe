# Arquitectura — Fútbol 5

Visión transversal del proyecto Godot 4.7.2 (GDScript, renderer GL Compatibility, física Jolt a 60 Hz).
Para localizar algo concreto, usar primero [INDEX.md](INDEX.md). Última sincronización: <!-- AUTO:verified -->
2026-11-08
<!-- /AUTO -->

## 1. Capas y responsabilidades

| Capa | Responsabilidad | Código | Regla de diseño |
|---|---|---|---|
| **Contratos de datos** | Entradas, eventos y estado serializables (`to_dict`/`from_dict`) | `scripts/network/` | Sin dependencia de nodos ni de presentación. Es lo que replicará un servidor autoritativo. |
| **Parámetros** | Valores de balance, editables y centralizados | `scripts/gameplay/tuning.gd` (autoload `Tuning`) + clases `*Tuning`/`PitchConfig` | El código lee `Tuning.ball`, `Tuning.player`, `Tuning.assist`, `Tuning.keeper`, `Tuning.pitch`. |
| **Reglas de partido** | Saque, gol, marcador, reloj, reinicios | `scripts/gameplay/match_manager.gd` | No crea ni mueve entidades: emite `kickoff_requested`. |
| **Simulación** | Pelota, cancha, jugadores, asistencias | `scripts/ball/`, `scripts/pitch/`, `scripts/player/`, `scripts/assistance/` | La pelota solo cambia por impulsos; los atributos escalan parámetros, no sustituyen la física. |
| **Presentación** | Modelo, animación, cámara, HUD, diagnóstico | `scripts/player/footballer_visual.gd`, `scripts/animation/`, `scripts/camera/`, `scripts/ui/`, `scripts/diagnostics/` | La lógica nunca depende de la presentación (las pruebas desactivan el modelo con `Footballer.build_visual = false`). |
| **Herramientas y pruebas** | Verificación y pipeline de assets | `tests/`, `tools/` | Pruebas headless propias; herramientas de captura renderizada con Xvfb. |

## 2. Flujo de datos de una jugada

```
HumanInput.poll() / TouchControls (acciones de InputMap)
   └─► InputFrame (intención serializable)
        └─► Footballer._physics_process
             ├─ PressController.update   (si presión y no controla el balón)
             ├─ Locomotion.step          (velocidad, giro, agarre)
             ├─ move_and_slide           (colisión con paredes/jugadores)
             └─ BallHandler.update
                  ├─ toques de conducción / primer toque  → Ball.kick (impulso)
                  └─ pase/tiro: request_kick → (retardo de contacto) → PassAssist/ShotAssist.compute → Ball.kick
                                                 └─ FootballerVisual.start_kick → ProceduralPose (misma ventana de contacto)
Ball._integrate_forces (arrastre, Magnus, rodadura, red)
Goal._physics_process → Pitch.goal_scored → MatchManager._on_goal → score_changed / GameEvent.GOAL → Hud
```

## 3. Convenciones obligatorias

- **Unidades:** metros, segundos, radianes en código (los parámetros de giro de `PlayerTuning` y ángulos de asistencia están en grados; el nombre del parámetro lo indica: `*_deg`, `turn_rate_*`).
- **Ejes de la cancha:** X = largo (arcos en `x = ±length/2`), Z = ancho, Y = arriba (`scripts/pitch/pitch.gd`, cabecera).
- **Equipos:** el equipo 0 defiende el arco −X y **ataca +X**; el equipo 1 al revés (`MatchContext.attacking_goal`).
- **Orientación del jugador:** `yaw = 0` mira hacia **−Z** (`Locomotion.dir_from_yaw`). El modelo de Tripo mira a +X, por eso `FootballerVisual.MODEL_YAW = π/2`.
- **Pantalla → mundo:** `MatchContext.screen_to_world` usa la cámara (`MatchCamera.screen_to_world_dir`); arriba en pantalla = alejarse de la cámara.
- **Quien toca la pelota** se registra con `Ball.register_touch(actor)` (necesita propiedades `team` y `actor_id` en el actor).
- **Estilo:** `class_name` en cada clase reutilizable, tipado explícito, comentarios `##` (se usan como descripción en las fichas), indentación con tabuladores, identificadores en inglés y texto de interfaz/comentarios en español.

### Autoloads

<!-- AUTO:autoloads -->
| Autoload | Script | `project.godot` |
|---|---|---|
| `Tuning` | `scripts/gameplay/tuning.gd` | línea 17 |
| `GraphicsSettings` | `scripts/diagnostics/graphics_settings.gd` | línea 18 |
| `Sfx` | `scripts/audio/sfx.gd` | línea 19 |
<!-- /AUTO -->

Escena principal: *scenes/main/match.tscn (eliminada en la reforma; en el historial de git)* (`project.godot`, `run/main_scene`).

### Capas de física 3D

<!-- AUTO:layers -->
| Capa | Valor (máscara) | Nombre | Uso |
|---|---|---|---|
| 1 | 1 | `world` | `Ball.LAYER_*` en `scripts/ball/ball.gd` |
| 2 | 2 | `ball` | `Ball.LAYER_*` en `scripts/ball/ball.gd` |
| 3 | 4 | `players` | `Ball.LAYER_*` en `scripts/ball/ball.gd` |
| 4 | 8 | `keepers` | `Ball.LAYER_*` en `scripts/ball/ball.gd` |
| 5 | 16 | `goal_frame` | `Ball.LAYER_*` en `scripts/ball/ball.gd` |
<!-- /AUTO -->

## 4. Dónde viven los parámetros

| Parámetro | Clase | Archivo |
|---|---|---|
| Pelota (física, pase, tiro) | `BallTuning` | `scripts/ball/ball_tuning.gd` |
| Jugador (locomoción, conducción) | `PlayerTuning` | `scripts/player/player_tuning.gd` |
| Asistencias | `AssistTuning` | `scripts/assistance/assist_tuning.gd` |
| Arquero (sin consumidor) | `KeeperTuning` | `scripts/goalkeeper/keeper_tuning.gd` |
| Cancha y arcos | `PitchConfig` | `scripts/pitch/pitch_config.gd` |
| Perfiles gráficos | constante `GraphicsSettings.PROFILES` | `scripts/diagnostics/graphics_settings.gd` |
| Preferencias de usuario (asistencias, diagnóstico, perfil gráfico) | `user://settings.cfg`, `user://graphics.cfg` | `Tuning.save_user_settings`, `GraphicsSettings.save_settings` |

`Tuning` intenta cargar `resources/tuning/*.tres` y, **como hoy no existe ningún `.tres`**, usa los valores por defecto de cada clase. Para ajustar balance basta editar el valor por defecto en la clase (o crear el `.tres` correspondiente; ver [TUNING](SYSTEMS/TUNING.md)).

### Valores fijos en el código (no centralizados)

Estos números afectan al comportamiento y **no** están en un recurso de parámetros; hay que buscarlos en el código:

| Valor | Dónde | Efecto |
|---|---|---|
| `0.8` s | `BallHandler._update_buttons` | tiempo de carga del pase hasta la fuerza máxima |
| `0.10` s / `0.12 + 0.06·carga` s | `BallHandler.contact_delay` | retardo entre soltar y golpear (pase / tiro) |
| `0.3` s | `BallHandler.update` (`_pending_age`) | ventana del buffer de pase/tiro si la pelota aún no está a alcance |
| `+0.3` / `+0.5` m | `BallHandler._try_execute_pending` / `_finish_kick` | margen de alcance para iniciar / completar la patada |
| `0.4` s | `BallHandler.request_kick` | bloqueo de toques de conducción durante y después de la patada |
| `0.9` | `BallHandler._after_kick` | pérdida de velocidad del jugador al patear |
| `0.86–0.97` | `Footballer._physics_process` | tope de velocidad conduciendo según `ball_carrying` |
| `0.12` / `0.2` s | `FootballerVisual._setup_animation_tree` | fundidos de entrada/salida de las acciones |

## 5. Preparación para online (qué existe y qué no)

Existe: `InputFrame` (entrada serializable), `InputSource` (humano/scriptado; futura red/IA), `GameEvent` (tipos y `to_dict`), `BallState` (snapshot), `Footballer.capture_state`, `MatchContext.input_enabled`, `MatchManager` sin dependencia de nodos de escena.
**No existe:** servidor, replicación, validación de acciones, reconexión ni identidad de jugador. Ver [NETWORK](SYSTEMS/NETWORK.md).

## 6. Herramientas del repositorio (resumen)

| Necesidad | Comando |
|---|---|
| Ejecutar todas las pruebas | `tools/run_tests.sh` (o con filtro: `tools/run_tests.sh ball_physics`) |
| Buscar en el índice | `python3 tools/docs_index.py find <términos>` |
| Localizar un símbolo | `python3 tools/docs_index.py where Clase.miembro` |
| Sincronizar / validar la documentación | `python3 tools/docs_index.py sync` / `check` |
| Capturas renderizadas (Xvfb) | `tools/shot_runner.gd` (ver [TOOLS_AND_ASSETS](SYSTEMS/TOOLS_AND_ASSETS.md)) |

Detalle de cada sistema: ver las fichas enlazadas desde [INDEX.md](INDEX.md).
