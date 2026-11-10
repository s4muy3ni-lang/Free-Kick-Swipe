# UI_HUD — HUD, menú de pausa y tema

## Identificación

- **Responsabilidad exacta:** capa de interfaz del partido (`CanvasLayer` en `layer = 10`): marcador «LOC x - y VIS», reloj `mm:ss`, mensajes grandes (saque, gol, fin), controles táctiles (ver [INPUTS](INPUTS.md)), superposición de diagnóstico (ver [PERFORMANCE](PERFORMANCE.md)) y menú de pausa con: continuar, reiniciar jugada, reiniciar partido, ciclo de perfil gráfico, ciclo de nivel de asistencia de pase/tiro/presión, interruptor de diagnóstico, «Práctica de animaciones» (abre la sala de práctica, señal `practice_requested`) y salir (cierra el juego cuando el partido es la escena actual). Los botones van en una cuadrícula de 2 columnas. Desde el 2026-10-29 también **«Zoom de cámara»** (`_cycle_camera_zoom`: Muy cerca / Cerca / Media / Lejos, `Tuning.camera_zoom`, ver [CAMERA](CAMERA.md)) y **«Sonido: Sí/No»** (`_toggle_sound`: `Tuning.sound_on` y `Sfx.set_enabled`, ver [AUDIO](AUDIO.md)) y **«Modo de juego»** (`_cycle_gameplay_mode`: recorre `Tuning.PLAYABLE_MODES`; **desde el 2026-10-30 solo el modo 4 es jugable y el botón no se muestra**, para no ofrecer los modos descartados; `Tuning.gameplay_mode`; emite `gameplay_mode_changed` y `MatchScene` recarga el partido porque el modelo cambia, ver [ANIMATION_PACK](ANIMATION_PACK.md#modo-2-de-jugabilidad-mocap-pack-05-soccer-2026-10-29)); se guardan en `user://settings.cfg`.
- **Estado:** implementado; el menú se construye por código y **solo se prueba el HUD táctil**, no el menú de pausa ni los textos.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-10
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/ui/hud.gd` | Clase `Hud` (`CanvasLayer`): marcador, mensajes, pausa, ajustes | `Hud.bind`, `Hud.show_message`, `Hud._build_pause_menu`, `Hud._cycle_assist`, `Hud._cycle_graphics`, `Hud.should_show_touch_controls` | `MatchManager`, `TouchControls`, `DiagnosticsOverlay`, `GraphicsSettings`, `Tuning`, `AssistTuning`, `UiTheme` |
| `scripts/ui/ui_theme.gd` | `UiTheme.make()`: tema sin texturas (paneles oscuros, botones grandes, fuentes 24/26) | `UiTheme.make` | — |
| `scripts/ui/touch_controls.gd` | Controles táctiles (ver INPUTS) | — | — |

**No modificar para cambiar el balance de asistencias:** `Hud._cycle_assist` solo cambia el nivel y lo guarda (`Tuning.save_user_settings`); los efectos están en `scripts/assistance/` (ver [ASSISTANCE](ASSISTANCE.md)).

## Mapa de parámetros

No hay recursos de parámetros. Constantes y valores fijos reales:

<!-- AUTO:consts:scripts/ui/hud.gd -->
| Constante / enum / uniform | Valor | Línea | Descripción |
|---|---|---|---|
| `Hud.LEVEL_NAMES` | `["Desactivada", "Baja", "Media", "Alta"]` | 15 |  |
| `Hud.TOUCH_SCALES` | `[0.85, 1.0, 1.2]` | 216 | Tamano de la botonera y sensibilidad del joystick (preferencias tactiles; se guardan con las demas). |
| `Hud.JOY_SENS` | `[0.8, 1.0, 1.3]` | 217 |  |
| `Hud.THREE_NAMES` | `["Bajo", "Normal", "Alto"]` | 218 |  |
<!-- /AUTO -->

- Tamaños de fuente: marcador y reloj 30, mensaje central 68 (color `(1, 0.95, 0.4)` con contorno), pista inferior 18 (`set_hint`), título de pausa 38; botones del menú de 56 px de alto mínimo y fuente 22; panel de pausa de 760 px de ancho (2 columnas). Desde el 2026-11-05 la cuadrícula va dentro de un `ScrollContainer` de 540 px de alto (se desplaza con el dedo): con «Imágenes por segundo» y «Sombras» (ver [PERFORMANCE](PERFORMANCE.md#tirones-de-cpu-y-opciones-de-rendimiento-2026-11-05)) los botones ya no cabían en 720 de alto.
- Visibilidad de los controles táctiles (`Hud.should_show_touch_controls`): variable de entorno `FUTBOL5_TOUCH=1`, o plataforma `android`/`ios`, o `DisplayServer.is_touchscreen_available()`.
- Etiquetas de nivel (`LEVEL_NAMES`): Desactivada, Baja, Media, Alta; valores en `AssistTuning.LEVEL_VALUES`.

### Riesgos al modificar

| Elemento | Efecto real y riesgo |
|---|---|
| Textos «LOC»/«VIS», mensajes («¡Saque!», «¡GOL!», «Fin del partido…») | Los emite `MatchManager` (`message`) y `Hud._on_score`. Cambiarlos no rompe pruebas (no se comprueban). |
| Nombres de botones del menú (`_pause_buttons`) | `_refresh_menu_labels` indexa por clave: `graphics`, `assist_pass`, `assist_shot`, `assist_press`, `diagnostics`, `camera_zoom`, `sound`, `gameplay_mode` (y las demás de ajustes); `practice` y `quit` no cambian de texto. Renombrar una clave sin tocar ambos sitios lanza un error en la apertura del menú. |
| `layer = 10`, `process_mode = ALWAYS` | Necesario para que el menú funcione con el árbol en pausa. |
| `_cycle_assist` | Usa nombres de propiedad dinámicos `"%s_assist" % kind`: una búsqueda de `pass_assist` por texto no encuentra este uso (ver ASSISTANCE). |

## Mapa de funciones

<!-- AUTO:funcs:scripts/ui/hud.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Hud._ready()` | 34 |  |
| `Hud.should_show_touch_controls()` | 69 |  |
| `Hud.bind(match_manager: MatchManager)` | 74 |  |
| `Hud._charges()` | 82 |  |
| `Hud._build_scoreboard(root: Control)` | 85 |  |
| `Hud._build_message(root: Control)` | 102 |  |
| `Hud._build_pause_menu(root: Control)` | 125 |  |
| `Hud._add_menu_button(parent: Container, key: String, text: String, action: Callable)` | 175 |  |
| `Hud._level_index(v: float)` | 186 |  |
| `Hud._refresh_menu_labels()` | 196 |  |
| `Hud._nearest_index(values: Array, v: float)` | 220 |  |
| `Hud._cycle_touch(kind: StringName)` | 227 |  |
| `Hud._cycle_camera_zoom()` | 238 | Zoom de la camara (se aplica en el acto, con el suavizado de la camara, y se guarda). |
| `Hud._cycle_gameplay_mode()` | 246 | Modo de jugabilidad entre los jugables (Tuning.PLAYABLE_MODES; hoy solo el 4, y el boton no se muestra): se guarda y el partido se vuelve a  |
| `Hud._toggle_sound()` | 254 | Sonido del partido: se apaga o enciende en el acto (publico incluido) y se guarda. |
| `Hud._cycle_minutes()` | 261 | Duracion del partido: se guarda y se aplica al reiniciar el partido (el reloj del partido en curso no cambia). |
| `Hud._cycle_graphics()` | 269 |  |
| `Hud._cycle_assist(kind: String)` | 273 |  |
| `Hud._toggle_diagnostics()` | 281 |  |
| `Hud._close_pause()` | 287 |  |
| `Hud._on_pause_pressed()` | 291 |  |
| `Hud.show_replay(on: bool)` | 295 |  |
| `Hud._input(event: InputEvent)` | 303 |  |
| `Hud._unhandled_input(event: InputEvent)` | 309 |  |
| `Hud._on_state_changed(s: int)` | 314 |  |
| `Hud._on_score(home: int, away: int)` | 320 |  |
| `Hud.show_message(text: String, seconds: float)` | 323 |  |
| `Hud.set_hint(text: String)` | 332 |  |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/ui/hud.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `Hud.restart_play_requested` | 6 | HUD del partido: marcador, reloj, mensajes, controles tactiles, menu de pausa y diagnostico. Esta separado de la camara 3D (CanvasLayer). Todos los botones ejecutan acciones reales. |
| `Hud.restart_match_requested` | 7 |  |
| `Hud.quit_requested` | 8 |  |
| `Hud.practice_requested` | 9 |  |
| `Hud.training_toggle_requested` | 11 | Cambiar entre partido normal y entrenamiento (tu equipo contra el arquero rival solo). |
| `Hud.gameplay_mode_changed` | 13 | Se eligio otro modo de jugabilidad: el partido se vuelve a montar con los modelos y clips del modo. |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/ui/ui_theme.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `UiTheme.make()` | 5 | Tema visual minimo y coherente (sin texturas): paneles oscuros, botones grandes aptos para tactil. |
| `UiTheme._box(bg: Color, border: Color, border_w: int, radius: int)` | 22 |  |
<!-- /AUTO -->

## Recorrido de ejecución

1. `MatchScene._ready` crea `Hud`, que en su `_ready` construye marcador, mensajes, `TouchControls`, `DiagnosticsOverlay` (visible según `Tuning.show_diagnostics`) y el menú de pausa.
2. `Hud.bind(manager)` conecta `score_changed`, `clock_changed`, `message` y `state_changed`. `PAUSED` muestra el panel, suelta todos los toques (`TouchControls.release_all`) y refresca las etiquetas.
3. `MatchScene` entrega `hud.charge_provider = _charge_state` (carga de pase/tiro del jugador controlado) para dibujar los anillos de carga.
4. Los botones del menú ejecutan: `toggle_pause`, `restart_play`/`restart_match` (a través de señales hacia `MatchScene`), `GraphicsSettings.set_profile((perfil + 1) % 4)`, cambio de nivel de asistencia + `save_user_settings`, alternar diagnóstico y `quit_requested`.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh touch_controls`.
- **Última ejecución (2026-10-26):** 4 pruebas / 20 comprobaciones sin fallos.
- **Alcance real:** estas pruebas crean un `Hud` y usan el panel táctil; **no existe prueba del menú de pausa, del marcador, de los mensajes ni de la persistencia de ajustes** (`user://settings.cfg`).

*Pruebas de test_touch_controls: eliminadas en la reforma (modo de fútbol 5 quitado; en el historial de git).*

- **Qué podría romperse:** el menú no abre al pausar (error de clave en `_pause_buttons`), botones fuera de pantalla en relaciones de aspecto distintas de 16:9 (`window/stretch/aspect="expand"`).

## Limitaciones conocidas

- **«Salir» no tiene efecto** y **no hay salida desde `FULL_TIME`** (ver [MATCH](MATCH.md)).
- Sin menú principal, selección de equipo/modo, pantalla de resultados, ajustes de sonido ni de control (sensibilidad).
- `Hud.set_hint` no tiene llamadores; la pista inferior está siempre vacía.
- Todo el texto está en español sin sistema de traducción.
- Sin pruebas visuales; no hay captura de referencia versionada.

## Indicadores de jugador (`PlayerMarker`)

Dos conos 3D que `MatchScene` coloca cada paso sobre la posición real del jugador (no son hijos suyos, así que no
heredan el giro ni la inclinación del cuerpo) y se dibujan sin prueba de profundidad para que no los tape nadie:

| Indicador | Forma y color | Sobre quién |
|---|---|---|
| Principal | cono cian lleno (radio 0.26 m, alto 0.44 m) | `MatchScene.human_actor()`: el jugador de campo controlado o el arquero si la persona lo ha tomado |
| Siguiente | cono ámbar translúcido, más pequeño | `MatchScene.switch_candidate()`: a quien pasaría el control CAMBIO |

Flotan a `PlayerMarker.HEIGHT` = 2.18 m con un balanceo de 5 cm. Al cambiar de jugador el indicador se va con el
nuevo en el mismo paso (comprobado en *tests/test_control_and_keeper.gd (eliminada en la reforma; en el historial de git)*).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Partido jugable».
