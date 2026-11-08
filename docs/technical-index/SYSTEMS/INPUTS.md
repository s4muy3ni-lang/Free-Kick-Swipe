# INPUTS — Entrada: InputFrame, fuentes y controles táctiles

## Identificación

- **Responsabilidad exacta:** todo lo que el jugador (o, en el futuro, una IA o la red) puede *pedir* a un futbolista. Una `InputSource` produce un `InputFrame` por paso de física; el futbolista solo conoce el `InputFrame`. Los controles táctiles **inyectan acciones reales de `InputMap`** (`Input.action_press`), de modo que teclado, táctil y pruebas comparten el mismo camino.
- **Estado:** implementado y probado (teclado, táctil multitoque con joystick flotante, entrada programada). No hay mapeo de gamepad (ver «Limitaciones»).
- **Última verificación:** <!-- AUTO:verified -->
2026-11-08
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/network/input_frame.gd` | `InputFrame`: intención serializable (`to_dict`/`from_dict`; el movimiento se recorta a longitud ≤ 1 al cargar) | `InputFrame.move`, `InputFrame.to_dict`, `InputFrame.from_dict` | — |
| `scripts/network/input_source.gd` | `InputSource`: clase base (`poll(footballer) -> InputFrame`) | `InputSource.poll` | `InputFrame` |
| `scripts/player/human_input.gd` | `HumanInput`: lee `Input.get_vector("move_left","move_right","move_up","move_down")` y las demás acciones | `HumanInput.poll` | `InputMap` |
| `scripts/network/scripted_input.gd` | `ScriptedInput`: entrada programable (pruebas, demostraciones); los flancos duran un `poll` | `ScriptedInput.hold_pass`, `release_pass`, `hold_shoot`, `release_shoot`, `request_switch` | `InputFrame` |
| `scripts/ui/touch_controls.gd` | `TouchControls` (`Control`): joystick flotante + botones circulares, multitoque, anillos de carga; dibujado por código | `TouchControls._input`, `_touch_down`, `_update_joystick`, `_apply_move` | `Input` (acciones), `Hud` |
| `project.godot` (`[input]`) | Definición de acciones y teclas | acciones abajo | — |

**No modificar para cambiar la sensibilidad del joystick:** `Locomotion` (cómo se acelera) ni `MatchCamera` (hacia dónde apunta la pantalla). La zona muerta y el radio están en `TouchControls`.

## Mapa de parámetros

### Acciones de entrada (real, `project.godot`)

<!-- AUTO:inputs -->
| Acción | Zona muerta | Teclas (código físico) | `project.godot` |
|---|---|---|---|
| `move_left` | 0.15 | A | línea 31 |
| `move_right` | 0.15 | D | línea 36 |
| `move_up` | 0.15 | W | línea 41 |
| `move_down` | 0.15 | S | línea 46 |
| `pass` | 0.5 | J | línea 51 |
| `shoot` | 0.5 | K | línea 56 |
| `sprint` | 0.5 | Shift | línea 61 |
| `lob` | 0.5 | I | línea 66 |
| `skill` | 0.5 | 85 | línea 71 |
| `press` | 0.5 | L | línea 76 |
| `switch_player` | 0.5 | Q | línea 81 |
| `pause_game` | 0.5 | Esc | línea 86 |
<!-- /AUTO -->

### Constantes del joystick y botones táctiles

<!-- AUTO:consts:scripts/ui/touch_controls.gd -->
| Constante / enum / uniform | Valor | Línea | Descripción |
|---|---|---|---|
| `TouchControls.JOY_RADIUS` | `95.0` | 10 |  |
| `TouchControls.JOY_DEADZONE` | `0.12` | 11 |  |
| `TouchControls.FONT_SIZE` | `22` | 12 |  |
<!-- /AUTO -->

Botones (en `TouchControls._build_buttons`; posición = desplazamiento desde la esquina inferior derecha del lienzo): `shoot` «TIRO» (−150,−150; radio 72), `pass` «PASE» (−300,−105; 64), `sprint` «SPRINT» (−110,−310; 54), `press` «PRESIÓN» (−270,−255; 54), `lob` «ALTO» (−410,−190; 44), `switch` «CAMBIO» (−420,−70; 42; visible solo si `show_switch`), `pause` «II» (−60 de la derecha, 52 px desde arriba; 28). El área táctil de cada botón es `radio × 1.2`. El joystick se activa con un toque en la mitad izquierda (`x < 55 %` del ancho y `y > 18 %` del alto); si el dedo se aleja más de `JOY_RADIUS × 1.6` el origen lo sigue.

### Riesgos al modificar

| Elemento | Efecto real y riesgo |
|---|---|
| `JOY_RADIUS` (95), `JOY_DEADZONE` (0.12) | Sensibilidad del movimiento: la intensidad `m` se reescala `(m − zona_muerta)/(1 − zona_muerta)` y define `walk/jog/run` en `Locomotion.speed_for_magnitude`. *test_floating_joystick_drives_move_actions_with_analog_strength (eliminada en la reforma)* y *test_touch_joystick_moves_a_real_footballer_end_to_end (eliminada en la reforma)* vigilan que el joystick produzca movimiento analógico y mueva a un futbolista real hacia +X. |
| Posición y radio de los botones | La prueba toca el **centro calculado** de cada botón (`get_button_center`); si se mueve un botón fuera del lienzo 1280×720 la prueba lo detecta. |
| Nombres de acciones | Los usa `HumanInput.poll`, `TouchControls` y las pruebas; renombrar una exige tocar los tres y `project.godot`. |
| `pointing/emulate_touch_from_mouse=true` | Permite probar el joystick con el ratón en escritorio. |

## Mapa de funciones

<!-- AUTO:funcs:scripts/ui/touch_controls.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `TouchControls._ready()` | 49 |  |
| `TouchControls._build_buttons()` | 56 |  |
| `TouchControls._add(id: StringName, text: String, action: StringName, anchor: Vector2, radius: float, color: Color, charge_key: StringName = &"")` | 79 |  |
| `TouchControls._button_center(b: TouchButton)` | 91 |  |
| `TouchControls._scale()` | 97 | Escala de la botonera (preferencia del usuario: botones pequenos, normales o grandes). |
| `TouchControls._radius(b: TouchButton)` | 100 |  |
| `TouchControls.joy_radius()` | 104 | Radio del joystick: con mas sensibilidad basta un recorrido menor del pulgar para llegar al maximo. |
| `TouchControls.get_button_center(id: StringName)` | 108 | Centro (en coordenadas del control) de un boton por id. Util para pruebas. |
| `TouchControls.is_button_pressed(id: StringName)` | 114 |  |
| `TouchControls._button_visible(b: TouchButton)` | 120 |  |
| `TouchControls._input(event: InputEvent)` | 127 |  |
| `TouchControls._local_pos(p: Vector2)` | 139 |  |
| `TouchControls._touch_down(index: int, pos: Vector2)` | 142 |  |
| `TouchControls._touch_drag(index: int, pos: Vector2)` | 162 |  |
| `TouchControls._touch_up(index: int)` | 168 |  |
| `TouchControls._update_joystick()` | 182 |  |
| `TouchControls._apply_move(v: Vector2)` | 200 | Traduce el vector analogico a las cuatro acciones de movimiento con su intensidad. |
| `TouchControls._set_axis(action: String, strength: float)` | 206 |  |
| `TouchControls.release_all()` | 213 |  |
| `TouchControls.joystick_vector()` | 225 | Vector del joystick actual (para pruebas y diagnostico). |
| `TouchControls._process(_delta: float)` | 230 |  |
| `TouchControls._draw()` | 237 |  |
| `TouchControls._default_joy_center_for_size()` | 263 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/player/human_input.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `HumanInput.poll(_footballer: Footballer)` | 7 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/network/scripted_input.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `ScriptedInput.hold_through()` | 26 |  |
| `ScriptedInput.release_through()` | 30 |  |
| `ScriptedInput.hold_cross()` | 34 |  |
| `ScriptedInput.release_cross()` | 38 |  |
| `ScriptedInput.tackle()` | 42 |  |
| `ScriptedInput.hold_pass()` | 45 |  |
| `ScriptedInput.release_pass()` | 49 |  |
| `ScriptedInput.hold_shoot()` | 53 |  |
| `ScriptedInput.release_shoot()` | 57 |  |
| `ScriptedInput.skill()` | 61 |  |
| `ScriptedInput.request_switch()` | 64 |  |
| `ScriptedInput.poll(_footballer: Footballer)` | 67 |  |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/ui/touch_controls.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `TouchControls.pause_pressed` | 8 | Controles tactiles: joystick flotante (mitad izquierda) y botones que inyectan acciones REALES de InputMap (move_*, pass, shoot, sprint, press, lob, skill, switch_player). Multitoque: cada dedo se asigna al joystick o a un boton. El pause solo emite una senal. Todo se dibuja por codigo (sin texturas) para mantener el HUD ligero. |
<!-- /AUTO -->

## Recorrido de ejecución

1. Toque en pantalla (`InputEventScreenTouch`/`Drag`; el ratón se emula como toque) → `TouchControls._input` → asigna cada dedo al joystick o a un botón.
2. Botón: `Input.action_press(action)` al pulsar y `action_release` al soltar (la pausa solo emite `pause_pressed`). Joystick: `_apply_move` fija la fuerza de `move_left/right/up/down` (los ejes de pantalla: x derecha, y abajo).
3. `Footballer._physics_process` → `InputSource.poll` → `InputFrame` (`HumanInput` usa `just_pressed`/`pressed`/`just_released` para los tres flancos de pase y tiro).
4. `MatchContext.screen_to_world(frame.move)` convierte el vector a dirección de mundo según la cámara.
5. `MatchContext.input_enabled = false` (saque, celebración, fin) hace que el futbolista use un `InputFrame` vacío.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh touch_controls`.
- **Última ejecución (2026-10-26):** suite completa 57 pruebas / 212 comprobaciones sin fallos.
- **Alcance real:** *test_touch_controls.gd (eliminada en la reforma)* envía eventos táctiles sintéticos (`Input.parse_input_event`) a un `Hud` real (ventana de pruebas de 1280×720) y a un futbolista creado con `TestCase.make_match` + `add_player`; esa configuración **no tiene cámara**, así que la conversión pantalla→mundo usada es el respaldo `Vector3(x, 0, y)`, no `MatchCamera`. **No se ha probado en un dispositivo Android real.**

*Pruebas de test_touch_controls: eliminadas en la reforma (modo de fútbol 5 quitado; en el historial de git).*

- **Qué podría romperse:** botones que no reciben el toque (por posición o por la ventana de pruebas), joystick que se queda «pegado» al pausar (`release_all` se llama al entrar en pausa), flancos duplicados.

## Limitaciones conocidas

- **Gamepad:** `HumanInput` menciona gamepad en su comentario, pero `project.godot` solo define eventos de **teclado** (A/D/W/S, J, K, Shift, I, L, Q, Esc): no hay mapeo de joypad.
- `InputFrame.switch_pressed` (acción `switch_player`) cambia al compañero más cercano a la pelota (`MatchScene`); `InputFrame.skill_pressed` (acción `skill`, tecla U, botón REGATE) lanza la ruleta; `use_world/move_world` permiten a la IA dar la dirección en coordenadas del mundo.
- El campo `InputFrame.tick` lo rellena cada fuente con su propio contador, no con el tick del partido.
- No existe una validación de `InputFrame` para el servidor (sin red); `from_dict` solo recorta el módulo del movimiento.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Control asistido».

## Acciones nuevas y mando (2026-10-27)

- `InputFrame`: `through_*` (FILTRADO), `cross_*` (CENTRO), `tackle_pressed` (ENTRADA). `InputBindings.ensure` crea las acciones `through_pass` (O), `cross` (H), `tackle` (N) y el mapeo de mando contextual (A pase/presión, X tiro/entrada, Y filtrado, B centro, RB sprint, LB alto, LT cambio, RT regate, Start pausa).
- `TouchControls`: botones FILTRADO, CENTRO y ENTRADA; escala de botones y sensibilidad del joystick (`Tuning.touch_scale`, `Tuning.joystick_sensitivity`, menú de pausa).
- Chanfle: `BallHandler.curl_from` compara la dirección al pulsar y al soltar TIRO/CENTRO.
