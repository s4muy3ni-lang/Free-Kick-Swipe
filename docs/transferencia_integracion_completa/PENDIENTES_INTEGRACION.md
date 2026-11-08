# Estado real de la integración y qué falta

Leyenda: **[C]** comprobado · **[I]** inferido · **[?]** desconocido.

**Regla de lectura:** «en el banco» no es «funcionando». Un clip **funciona** si su rol lo usa un sistema **y** el clip
pasa el filtro de ese sistema (columna `filtro_del_sistema` de `INVENTARIO_ANIMACIONES.csv`). Un dato de UCS
**funciona** si alguna función del juego lo lee (`DATOS_UCS.md`).

## 1. Tabla de estado

| Área | Estado | Evidencia |
|---|---|---|
| Física de la pelota (impulsos, aire, Magnus, rodadura, red) | **Completo** (modelo propio) | `FISICAS_BALON.md` |
| Golpeo con clip (planificador, contacto medido, IK del pie, espera de primera) | **Completo** | `BallHandler.plan_clip_kick` / `_finish_clip_kick`; E4: 50/50 contactos con render |
| Velocidad de salida del golpeo frente al gesto del clip | **Desconectado**: la velocidad la fijan los asistentes, sin relación con la velocidad del pie del clip | `BallHandler.perform_*`; solo `plan_turn_kick` filtra pie ≥ 7 m/s en tiros |
| Golpeos del banco | **Parcial**: 202 de 494 KICK pasan el filtro; 121 golpeos a ras con contacto no limpio y 12 girando con la punta alta no pasan | inventario |
| Cabezazo y volea | **Conectado** por trayectoria (`paths`); sin contacto medido por clip en el inventario | `BallHandler.plan_aerial_kick` |
| Conducción: marcha con pelota + toques físicos | **Completo** | `BallHandler._try_dribble_touch`; E3 |
| Conducción: toque orientado y arranque con clips de UCS | **Parcial**: solo el jugador de la persona; usa la ventana del joystick de UCS, no su destino de pelota | `JsonBallMove._person`, `JsonBallMove.plan_ids` |
| Giros, regates y frenadas con pelota con clip | **Completo** con los datos medidos; 13 clips sin toques no pasan | `JsonBallMove.consider` |
| Giros con toques y pisada sin clip | **Completo** (respaldo) | `BallTurn`, `DragBack` |
| Recepción con pie, muslo, rodilla y pecho | **Parcial**: perfiles `usable` / `conditional`; 23 `pending` | `ReceiveProfiles`, `JsonReceive.plan` |
| Recepción con cabeza | **Desconectado** (ningún clip verificado; la cabeza no tiene respuesta física) | `json_receive.gd:28` |
| Giros sin pelota | **Conectado** (franjas de velocidad); 13 clips fuera de franja | `Footballer._json_turn_move` |
| Entradas, barridas, cargas, caídas, levantarse | **Conectado**; `tackle_stand` en el sitio: 12 de 16 no pasan | `PlayerActions` |
| Arquero (atajadas por clip, salidas, saques) | **Completo** con el planificador propio; 11 giros sin conectar | `KeeperPlanner.plan_save` |
| Reacciones y gestos | **Parcial**: solo los clips en el sitio (raíz ≤ 1 m, ≥ 0.6 s); 176 de roles conectados no pasan | `JsonCatalog.situation_clip` |
| Escenas de presentación y entorno (público, banco, técnicos) | **Desconectado por decisión** (250 clips) | inventario, motivo |
| Despeje de jugador de campo | **No existe** (ni clip ni sistema) | `ACCIONES_FUTBOLISTICAS.md` §9 |
| Intercepción como acción propia | **No existe**: se hace con recepción o control | §12 de ACCIONES |
| `animdb.json` en el juego | **Parcial**: solo la ventana del joystick, y la etiqueta `toque_cuadro` es incorrecta | `AnimDB.joystick_window` |
| Cuadro y pie del contacto de UCS (campos 24 y 4) | **Desconectado** | `DATOS_UCS.md` |
| Destino de la pelota de UCS (campos 25-27) | **Desconectado** | idem |
| Velocidades de UCS por familia (campos 5, 6, 40, 49) | **Desconectado**; unidad desconocida | idem |
| Parámetros de UCS | **5 implementados**, 3 probados y descartados, 6 definidos sin uso, 197 sin conectar | `PARAMETROS_UCS.md` §3 |
| Lógica de la IA de UCS | **Falta investigar** (no se descompiló) | `IA_UCS_Y_FUTBOL5.md` §0 |
| Cola de `animdb.adb` (442 320 bytes) y campos 10-17, 40-45, 48, 50 | **Falta investigar** | `DATOS_UCS.md` |
| Lados L/R de los nombres frente a los datos | **Falta investigar** la causa (el juego es coherente con sus datos) | `DATOS_UCS.md` §1.3 |
| Choques entre jugadores durante el fantasma | **Falta medir** | `FISICAS_BALON.md` §10 |
| Pie animado en las pruebas sin render | **Limitado**: headless sin `feet_live`; hace falta render (Xvfb) | `BallHandler._sample_feet` |

## 2. Qué implementar y cómo

En todos los pasos, las reglas del proyecto (`CLAUDE.md`) son:

- cambio mínimo;
- prueba del sistema (`tools/run_tests.sh <filtro>`, suite completa `tools/run_tests.sh`);
- `python3 tools/docs_index.py sync` + `check`;
- una entrada en `docs/technical-index/CHANGELOG.md`;
- no registrar como aprobada una prueba que no se ejecutó.

### 2.1 Datos de UCS (lo primero: corrige errores de etiqueta)

1. **Corregir `tools/json_anim/make_animdb.py`.** Cambiar `toque_cuadro` (campo 3) por el campo 24 (cuadro del evento
   de pelota). Dejar el 3 como `byte_cabecera_sat`. Etiquetar 5, 6, 40, 46 y 49 por familia. Copiar la altura del
   destino (campo 26). Después regenerar `assets/animations/animdb.json` y ajustar los comentarios de
   `scripts/animation/anim_db.gd` (cabecera) y de E3.
   - **Prueba:** `tools/run_tests.sh json_mode`, más una comprobación que vuelva a medir el campo 24 contra
     `contact.json_time` (±2 cuadros en ~69 % de los golpeos).
2. **Validar el campo 24 por familia:** recepciones (contra el instante `t` de `ReceiveProfiles.PROFILES`), arquero (contra el instante de las
   manos) y barridas. Herramienta de partida: `tools/transfer/adb_field_stats.py`.
3. **Destino de UCS (25-27) en los toques orientados:** en `JsonBallMove._touch`, comparar el destino de UCS con la
   punta del toque siguiente que se usa hoy. Si coinciden en los clips de `steer_pool`, usarlo como objetivo del último
   toque. **No usarlo en recepciones:** allí no es el punto de contacto (E4).

### 2.2 Unificar el golpeo con el gesto

4. **Que la velocidad de la pelota encaje con el clip.** En `BallHandler.plan_clip_kick`, sumar al puntaje la diferencia
   entre la velocidad que pedirá el asistente (pase o tiro) y la que permite el pie del clip (`contact.speed`). Así un
   tiro fuerte elige un clip de golpeo fuerte. Hay que estimar la velocidad pedida antes del plan; existe
   `BallHandler.estimated_kick_dir` (989).
   - **Prueba:** `tools/run_tests.sh pack_kick` y `test_live_kicks` con render.
5. **Golpeos no limpios (121):** revisar en el visor (`tools/json_anim/play_view.tscn`) si algunos sirven para pases de
   costado o de exterior. Sería un rol nuevo, no relajar el filtro de los demás.

### 2.3 Recepciones

6. **Verificar los 23 pendientes** en `tools/json_anim/receive_view.tscn` y actualizar su perfil en
   `tools/json_anim/make_receive_profiles.py`. **No editar `receive_profiles.gd` a mano: es generado.**
7. **Recepción con cabeza:** agregar `head` a `JsonReceive.PARTS` (`json_receive.gd:29`) con su normal en
   `JsonReceive._part_normal` (687) y su alcance en `PART_REACH`. Hace falta al menos un clip verificado: hoy
   `jn_receive_0590` está en `pending`.
   - **Prueba:** `tools/run_tests.sh receive`.

### 2.4 Conducción y giros

8. **Toque orientado para la IA** (hoy solo la persona, `JsonBallMove._person`). Activarlo con un enfriamiento propio y
   medir en `test_ai_match` que la IA no pierda la pelota más.
9. **Ventana del joystick en giros grandes:** la ventana no está centrada en el giro (E4). Investigar si UCS combina la
   ventana con el giro (campos 7-9 y 47) antes de aplicarla. **No achicar los límites de giro para adaptarlos a los
   clips conectados** (pedido de la persona).

### 2.5 Reacciones y presentación

10. **Reacciones que se desplazan:** reproducirlas como acción con raíz (`PlayerActions.start_move`) en vez de en el
    sitio. Así podrían salir los 176 clips que hoy no pasan el filtro de `JsonCatalog.situation_clip`.

### 2.6 IA (cada parámetro, una hipótesis con su prueba)

11. **Por orden de impacto previsto [I]:**
    - `ResponsePlayerAction0/1` como retardo de reacción al cambio de jugada (`AIInput`);
    - `RunAutoMaxRunners` y `RunTimeout` (desmarques; las constantes ya están en `UcsParams`);
    - `BackLine*` y `MidLinePercent*` (líneas);
    - `Width*` de balón parado (`SetPiece`);
    - `UrgencyLooseBallOppoFrames` (`TeamBrain._loose`).

    Para cada uno:
    - aplicarlo detrás de una constante de `UcsParams`;
    - correr `tools/run_tests.sh ai_match` (3 corridas), `full_match`, `goalkeeper` y `shot_keeper`;
    - si no mejora o rompe, anotarlo como «probado y descartado» con su medida, como en E4.
12. **Descompilar la lógica que lee la estructura de configuración.** Buscar en `libMPX.so` las cargas
    `ldr w*, [x*, #campo]` con los campos de `PARAMETROS_UCS.csv` (por ejemplo `0x404` = `MaxActivePresses`) para ver
    qué función usa cada parámetro. Con eso, los significados pasarían de [I] a [C]. Herramienta de partida:
    `tools/transfer/ucs_params_extract.py`, capstone.

### 2.7 A investigar

13. **Cola de `animdb.adb`** y campos 10-17, 40-45, 48 y 50.
14. **Causa del espejo** entre nombres y datos: comparar la orientación del esqueleto de un JSON con el clip original
    de UCS.
15. **Efecto del fantasma en los choques entre jugadores:** medir en una prueba de partido si dos jugadores se
    atraviesan durante un movimiento con pelota.

## 3. Pruebas por área

| Área | Filtro de `tools/run_tests.sh` | Render (Xvfb) |
|---|---|---|
| Golpeos | `pack_kick`, `live_kicks` | `test_live_kicks` necesita render |
| Conducción y giros | `mode4_dribble`, `ball_turn`, `physical_dribble` | `test_physical_dribble` necesita render |
| Recepciones | `receive`, `pass_receiver_control` | — |
| Modo 4 en general | `json_mode` | — |
| IA y partido | `ai_match`, `full_match` | — |
| Arquero | `goalkeeper`, `shot_keeper` | — |

Las últimas cifras reales (E4, 2026-11-06): suite headless de 290 pruebas con 0 fallos, 32 omitidas y 1725
comprobaciones. En **esta** tarea de documentación no se ejecutaron pruebas, porque no se cambió código de juego.
