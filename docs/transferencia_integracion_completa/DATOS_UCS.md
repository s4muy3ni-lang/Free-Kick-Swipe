# Datos de UCS y datos propios de animación: todos los campos

Leyenda: **[C]** comprobado (contra datos o código) · **[D]** deducido de los datos (estadística o patrón, sin ver el
código de UCS) · **[I]** inferido (nombre, analogía) · **[?]** desconocido.

Complementa [`docs/fases/E3_conduccion_ucs.md`](../fases/E3_conduccion_ucs.md) (sección 1, dónde está `animdb.adb` y
cómo se identificaron los campos de la conducción) y [`docs/fases/E4_integracion_ucs.md`](../fases/E4_integracion_ucs.md).
Lo que esos documentos ya explican no se repite: aquí está **el mapa completo de cada campo** y lo nuevo de esta
investigación:

- **corrección del campo 3**: no es el cuadro del toque;
- campos que cambian de significado según la familia;
- campos 0, 1, 18, 20, 24 y 28-39;
- conflicto de lados con los nombres.

También incorpora y vuelve a medir lo que había anotado [`docs/fases/00_auditoria_modo_json.md`](../fases/00_auditoria_modo_json.md) (tabla de la sección de UCS).

Herramientas para regenerar todo lo que sigue (no tocan el juego):

| Herramienta | Qué produce |
|---|---|
| `tools/transfer/adb_field_stats.py <animdb.adb> <index.json>` | estadística de los 52 campos (anexo A) |
| `tools/json_anim/make_animdb.py <animdb.adb> <index.json>` | `assets/animations/animdb.json` |
| `tools/transfer/dump_library_meta.tscn` (Godot, `OUT=...`) | metadatos de los 3223 clips de la librería |
| `tools/transfer/make_inventory.py` | `INVENTARIO_ANIMACIONES.csv` |

Archivos de origen (no están en el repositorio):

- `animdb.adb`, 865 188 bytes. Está en `assets/data/anims/` del APK de Ultimate Clash Soccer 1.810 y en el paquete
  `paquete_recursos_analisis_movimiento/animaciones/animdb.adb`.
- El banco de 2022 JSON: `animaciones_futbol5_JSON_limpios.zip`, o la copia clasificada
  `animaciones_futbol5_conectadas_y_sin_conectar/`.

## 1. `animdb.adb` (UCS)

### 1.1 Estructura [C]

- Bytes 0-3: `uint32` = 4066 registros.
- 4066 registros fijos de 104 bytes = 52 enteros `int16` *little-endian*.
- Cola de 442 320 bytes, **no decodificada**. 442 320 / 4066 = 108.8, así que no son bloques iguales por registro.
  E3 la describió como «claves de tiempo y trayectorias» sin comprobarlo. **[?]**
- **Índice:** el registro `NNNN` corresponde al archivo JSON `NNNN_*.json` del banco. Comprobado: el campo 2 es igual a
  `frames` en los 2022 archivos, y todos los números de archivo son pares. **[C]**
- **Espejos:** el registro `2k+1` es el espejo del `2k` (campo 1, bit 0). Los 2022 JSON son los originales; hay 11
  originales de UCS sin JSON en el banco (registros 158, 258, 370, 456, 878, 880, 1086, 1088, 3834, 3976 y 3978).
  **[C]**

### 1.2 Campo por campo

Columnas (los 10 puntos pedidos):

1. nombre (nuestro: el archivo no trae nombres);
2. qué representa;
3. unidad y coordenadas;
4. cómo se obtuvo;
5. certeza;
6. dónde se guarda;
7. qué lo lee;
8. qué debería usarlo;
9. si está conectado;
10. qué falta.

En todos los campos, (6) es el registro `NNNN` de `animdb.adb` y, si se copió, `assets/animations/animdb.json` →
`clips.NNNN.ucs`.

| campo | 1 nombre | 2 qué es | 3 unidad / coordenadas | 4 cómo se obtuvo | 5 | 7 lo lee | 8 debería usarlo | 9 conectado | 10 falta |
|---:|---|---|---|---|---|---|---|---|---|
| 0 | `categoria` | categoría del clip: 0 STAND, 1 CONTROL, 2 SIDESTEP, 3 LOCO, 4 TURN, 5 STUMBLE, 6 THROW, 7 TACKLESLIDE, 8 TACKLE, 9 FALL, 10 GETUP, 11 KICK, 12 KICKSETPIECE, 13 NIS, 14 GKSAVE, 15 GKTHROW, 16 GKKICK, 17 REFEREE (según `00_auditoria_modo_json.md`; 16 registros, sin JSON en el banco) | entero | correspondencia 1:1 con la categoría del banco en los 2022 clips | [C] | `adb_field_stats.py` | nadie (el banco ya trae la categoría) | no (no hace falta) | — |
| 1 | `variante` | bit 0 = espejo (0 original, 1 espejo); bits 1-2 = 0, 2, 4 o 6 (pares: (4,5) 1803, (0,1) 218, (6,7) 11, (2,3) 1). La auditoría lo había anotado como 4 = base / 5 = espejo | bits | pares 2k/2k+1: 2033/2033 difieren solo en el bit 0 | bit 0 [C]; bits 1-2 [?] | — | — | no | identificar los bits 1-2 |
| 2 | `cuadros` | duración del clip | cuadros de 60 Hz | igual a `frames` del JSON (2022/2022) | [C] | `make_animdb.py` (`ucs.cuadros`) | nadie (la librería ya tiene `duration`) | no (no hace falta) | — |
| 3 | `byte_cabecera_sat` (**no** es el cuadro del toque) | igual al byte 2 de la cabecera de su `.sat` en **1832/1832** archivos (`paquete_recursos_analisis_movimiento/animaciones/NNNN.sat`); la auditoría lo relaciona con la cantidad de bloques de datos (r = 0.99 con el tamaño) | entero | comparación directa con los `.sat`; contra nuestro contacto medido de los golpeos solo ±2 cuadros en 162/447 | [C] (igual al byte del `.sat`); bloques [D] | `make_animdb.py` lo copia **mal etiquetado** como `toque_cuadro` (no se usa en el juego) | nadie | no | corregir la etiqueta en `make_animdb.py` / `animdb.json` / E3 (ver PENDIENTES) |
| 4 | `toque_pie` | pie del toque: bit 128 / bit 256 | bits | coincide con el pie del JSON del banco: conducción y control 53/59, golpeos 188/190 (toque del JSON más cercano); contra el pie de nuestro contacto medido, 426/444 | [C] respecto del JSON; ver 1.3 respecto de los nombres | `make_animdb.py` (`toque_pie`) | elegir el pie del golpeo o toque igual que UCS | no | — |
| 5 | `campo5` | **depende de la familia**: CONTROL = velocidad de entrada (r 0.90 con nuestro `v_in`); KICK = velocidad del pie en el contacto (r 0.86 con `contact.json_speed`; con `v_in` solo 0.49) | ×10, unidad de UCS no establecida | correlación por familia (esta tarea) | [D] | `make_animdb.py` (como `v_in_x10`) | `JsonReceive.plan` (CONTROL), golpeos (KICK) | no | unidad; la etiqueta `v_in_x10` solo vale para CONTROL |
| 6 | `campo6` | CONTROL = velocidad de salida (r 0.87 con `v_out`); KICK: sin relación con `v_out` (r −0.11) | ×10, unidad no establecida | idem | [D] | `make_animdb.py` (como `v_out_x10`) | `JsonReceive.plan` | no | idem |
| 7 | `ventana_min` | límite izquierdo/derecho de la dirección del joystick con que se elige el clip | grados respecto del frente, pasos de 11.25° (32 sectores); + = izquierda en los datos del banco | patrón: avance −67…+67, diagonales «45» −112…+22; en el espejo se intercambia con el 8 y cambia de signo | [D] | `AnimDB.joystick_window` (`scripts/animation/anim_db.gd:57`) | `JsonBallMove.plan_ids` | **sí, solo en el toque orientado** (`json_ball_move.gd:350-353`) | giros grandes: la ventana no está centrada en el giro (E4); falta saber cómo combina UCS ventana y giro |
| 8 | `ventana_max` | idem, el otro límite | idem | idem | [D] | idem | idem | idem | idem |
| 9 | `giro_sector` | giro del clip redondeado | grados en sectores (0, ±11, ±22, ±45, ±56, ±90…) | cambia de signo en el espejo (1023/1023); encaja con `yaw_end` | [D] | `make_animdb.py` | selección de giros (`JsonBallMove.plan_move`) | no (usamos el giro medido del clip) | — |
| 10 | `h10` | ? valores 64 (2942), 128 (1084), 40, 45, 12, 50 | ? | estadística | [?] | — | — | no | identificar |
| 11 | `h11` | ? 0 (2858), −10, −30, −8, −22… | ? | idem | [?] | — | — | no | idem |
| 12 | `h12` | ? 90, 30, 180, 16, 45, 22, 20 (¿ángulos?) | ? | idem | [?] | — | — | no | idem |
| 13 | `h13` | ? 45, 56, 90, 33, 4, 22 (¿ángulos?) | ? | idem | [?] | — | — | no | idem |
| 14 | `h14` | ? lateral: −16…16, cambia de signo en el espejo (311/311) | ? | idem | [?] | — | — | no | idem |
| 15 | `h15` | ? 0 en el 94 %; 1…27 | ? | idem | [?] | — | — | no | idem |
| 16 | `h16` | ? −1…63; el espejo suma o resta 32 (1552 +32, 481 −32) | ? (64 valores) | idem | [?] | — | — | no | idem |
| 17 | `h17` | ? 0 en el 94 %; 1…6; difiere en 62 pares | ? | idem | [?] | — | — | no | idem |
| 18 | `h18` | ≤ cuadros del clip en 4066/4066, ≥ campo 3 en 3628, ≤ campo 20 siempre | entero (¿cuadro?) | estadística; correlación 0.59 con los cuadros | [?] | — | — | no | identificar |
| 19 | `h19` | siempre 0 | — | estadística | [C] | — | — | — | — |
| 20 | `h20` | un cuadro: ≤ cuadros en 3816/4066; correlación 0.66 con los cuadros | cuadro | estadística | [D] cuadro; [?] significado | — | — | no | identificar |
| 21-23 | `h21`…`h23` | siempre 0 | — | estadística | [C] | — | — | — | — |
| 24 | `evento1_cuadro` | **cuadro del evento de pelota** (en los golpeos, el contacto): ≤ cuadros siempre; ≠ 0 en **todas** las categorías con pelota (KICK, CONTROL, GKSAVE, TACKLE…) y 0 en LOCO, TURN, GETUP, SIDESTEP. Contra nuestro contacto medido de los golpeos: mediana +1 cuadro, ±2 en 310/447 y ±4 en 366/447 | cuadro de 60 Hz desde el inicio | estadística y comparación con `contact.json_time` | golpeos [D]; otras familias [?] (con los toques del JSON en CONTROL solo 41/210 a ±2) | no se copia a `animdb.json` | `BallHandler.plan_clip_kick` como contraste del contacto | no | copiarlo a `animdb.json`; validar en recepciones y arquero |
| 25 | `destino_adelante` | posición de la pelota en el evento: **−h25** = adelante | mm, marco del inicio del clip | conducción: cae junto a la punta del pie del toque siguiente (E3) | conducción [C]; resto [D] | `make_animdb.py` → `destino_m[0]` | `JsonBallMove._touch` (destino de los toques), `BallHandler.plan_clip_kick` | no | validar en golpeos y recepciones (en recepciones **no** es el punto de contacto: 0.6 m de mediana, E4) |
| 26 | `destino_altura` | altura de esa posición | mm | vale 96 en casi todos los registros sin evento (1744/1886); mínimo 96 | [I] (¿radio de la pelota de UCS = 96 mm?) | — | — | no | comprobar |
| 27 | `destino_lateral` | lateral de esa posición: + = izquierda en los datos del banco | mm | cambia de signo en el espejo (1069/1069); conducción (E3) | [C] conducción | `make_animdb.py` → `destino_m[1]` | idem 25 | no | idem 25 |
| 28 | `evento2_cuadro` | segundo evento: cuadro ≤ cuadros (94 registros ≠ 0) | cuadro | analogía con 24 | [I] | — | — | no | identificar |
| 29-31 | `evento2_xyz` | posición del segundo evento (31 cambia de signo en el espejo) | mm [I] | analogía con 25-27 | [I] | — | — | no | identificar |
| 32 | `evento3_cuadro` | 0 en el 99 %; 6 valores | cuadro [I] | analogía | [I] | — | — | no | — |
| 33-35 | `evento3_xyz` | 35 cambia de signo en el espejo | mm [I] | analogía | [I] | — | — | no | — |
| 36 | `evento4_cuadro` | 0 en el 100 % menos 4 valores | cuadro [I] | analogía | [I] | — | — | no | — |
| 37-39 | `evento4_xyz` | 39 cambia de signo en el espejo | mm [I] | analogía | [I] | — | — | no | — |
| 40 | `campo40` | KICK: −velocidad de entrada (r −0.71 con nuestro `v_in`; ya lo había visto la auditoría) | ? | correlación | KICK [D]; resto [?] | — | golpeos | no | unidad |
| 41 | `h41` | siempre 0 | — | — | [C] | — | — | — | — |
| 42 | `h42` | ? 0/1/2 (93 % ceros) | ? | — | [?] | — | — | no | — |
| 43 | `h43` | ? −3928…14; difiere en 518 pares de espejo | ? | — | [?] | — | — | no | — |
| 44 | `h44` | ? −21846…0, igual en el espejo; correlación 0.51 con los cuadros | ? | — | [?] | — | — | no | — |
| 45 | `h45` | ? 0/1 | ? | — | [?] | — | — | no | — |
| 46 | `giro_turn` | TURN (giros sin pelota): −giro del clip (r −0.92 con nuestro giro medido; la auditoría: razón −1.0 en 122 clips). Cambia de signo en el espejo; 0 en el 92 % (otras familias) | grados | correlación | TURN [D] | — | `Footballer._json_turn_move` | no | — |
| 47 | `giro_medido` | giro del clip, + = izquierda en los datos del banco. **0 en todos los TURN** (su giro está en el 46) | grados | correlación con nuestro giro medido: CONTROL 0.91, KICK 0.67; con `yaw_end` del JSON 0.71 (todas); cambia de signo en el espejo (1412/1412) | [D] | `make_animdb.py` (`giro_medido`) | selección de giros con pelota | no | — |
| 48 | `h48` | ? 10…158 (no es un cuadro: ≤ cuadros solo en 1334) | ? | — | [?] | — | — | no | — |
| 49 | `campo49` | LOCO: proporcional a la velocidad natural del ciclo (r 0.93; ~12 por m/s según la auditoría). 0 en el 97 % (otras familias) | ? | correlación | LOCO [D] | — | — | no | unidad |
| 50 | `h50` | ? −31914…22995 | ? | — | [?] | — | — | no | — |
| 51 | `h51` | ? 0/1 | ? | — | [?] | — | — | no | — |

Nombres de `libMPX.so` que podrían corresponder a estos campos: `BallFrame`, `BallDestination`, `BallNumberOfFrames` y
`AnimStartFramePC`. Los citó el informe del paquete (E3). **[I]**: no se vio el código que los lee.

### 1.3 Conflicto de lados entre los nombres de UCS y los datos [C, causa ?]

Los nombres de los clips de UCS dicen L/R (izquierda o derecha), pero en **nuestros datos** el lado es casi siempre el
contrario:

- **Giros:** en los clips cuyo nombre lleva `L` como lado, el giro medido en el juego (`giro_cuerpo_juego_grados`; +
  = izquierda, convención de `Locomotion.dir_from_yaw`) es negativo en 34 de 37. En los de `R`, es positivo en 39 de
  46. Ejemplo: `jn_ball_turn_0202` (`TURNBALL_180L`) gira −164° en el juego, a la derecha. Los campos 9 y 47 de UCS
  tienen el mismo signo que nuestros datos.
- **Pie:** las recepciones con `R_FOOT` en el nombre tienen el bit 128 en el campo 4. Es el bit que coincide con el pie
  **izquierdo** del JSON del banco.
- `JsonReceive` ya lo había anotado en su cabecera: «los datos están en espejo respecto de los nombres»
  (`scripts/player/json_receive.gd:9-11`).

**Consecuencia:** el juego es coherente consigo mismo, porque usa los datos medidos y no los nombres. Pero **nunca** hay
que elegir un clip por el lado que dice su nombre. **[?]** La causa no se estableció; una hipótesis es un cambio de
sistema de coordenadas (mano izquierda/derecha) al exportar el banco, sin cambiar las etiquetas L/R.

## 2. `assets/animations/animdb.json` (nuestro)

- **Lo genera:** `tools/json_anim/make_animdb.py`.
- **Lo lee:** `AnimDB` (`scripts/animation/anim_db.gd`, ruta en la constante `AnimDB.PATH`, línea 8).
- **Estado en el juego:** **solo se usa la ventana del joystick** (`AnimDB.joystick_window`, línea 57). Su único
  llamador es `JsonBallMove.plan_ids` (`scripts/player/json_ball_move.gd:350`). `AnimDB.clips_for` y
  `AnimDB.summary` no tienen llamadores en `scripts/` (búsqueda). **[C]**

| campo | qué representa | unidad / coordenadas | origen | certeza | lo lee | debería usarlo | conectado | falta |
|---|---|---|---|---|---|---|---|---|
| `version`, `descripcion` | versión y texto | — | generador | [C] | — | — | — | — |
| `resumen.clips` / `tramos` / `conectados` / `acciones` | totales | conteo | generador | [C] | `AnimDB.summary` (sin llamador) | herramientas, pruebas | no | — |
| `acciones.<rol>` | TODOS los ids de cada acción, conectados o no | lista | `E2_inventario_banco.csv` y los ajustes del generador | [C] | `AnimDB.clips_for` (sin llamador) | quien busque clips por acción | no | usarlo en lugar de `PackLibrary.by_role` si se quieren incluir desconectados |
| `clips.NNNN.nombre` / `categoria` / `cuadros` | nombre UCS sin `ANM_`, categoría, cuadros | — | índice del banco | [C] | — | — | no | — |
| `clips.NNNN.tramos[].id` | id del clip en la librería (`jn_<rol>_NNNN`; espejo `_mirror`) | — | inventario E2 | [C] | — | — | — | — |
| `clips.NNNN.tramos[].accion` / `conectada` / `sistemas` / `motivo` | rol, estado (`si` / `no` / `pendiente`), sistema que lo usa y por qué | — | inventario E2 y los ajustes del generador | [C] | — | herramientas | no | se desactualiza si se conectan clips sin regenerar |
| `clips.NNNN.ucs.cuadros` | campo 2 | cuadros 60 Hz | `animdb.adb` | [C] | — | — | no | — |
| `ucs.toque_cuadro` | campo 3: **mal etiquetado**, es el byte de la cabecera del `.sat`, no el cuadro del toque | — | idem | [C] la etiqueta es incorrecta | `AnimDB.ucs` | nadie | **no** | cambiarlo por el campo 24 (cuadro del evento de pelota) en `make_animdb.py` |
| `ucs.toque_pie` | campo 4 (`izq` = bit 128, `der` = bit 256; el espejo los intercambia en `AnimDB.ucs`, línea 52) | — | idem | [C] respecto del JSON | `AnimDB.ucs` | elegir el pie | **no** | — |
| `ucs.giro_sector` / `giro_medido` | campos 9 y 47 (el espejo cambia el signo) | grados | idem | [D] | `AnimDB.ucs` | selección de giros | **no** | — |
| `ucs.ventana_joystick` | [campo 7, campo 8] (espejo: [−8, −7]) | grados, + = izquierda | idem | [D] | `AnimDB.joystick_window` | `JsonBallMove.plan_ids` | **sí (solo el toque orientado)** | giros grandes (E4) |
| `ucs.v_in_x10` / `v_out_x10` | campos 5 y 6: velocidades de entrada y salida **solo en CONTROL**; en KICK el 5 es la velocidad del pie | ×10, unidad desconocida | idem | [D] | — | — | **no** | unidad; etiqueta por familia |
| `ucs.destino_m` | [−campo 25 / 1000, campo 27 / 1000] = (adelante, izquierda) en metros; el espejo cambia el lateral | m, marco del inicio | idem | conducción [C] | `AnimDB.ucs` | `JsonBallMove._touch` | **no** | validar por familia; la altura (campo 26) no se copió |

## 3. Metadatos de la librería del juego (lo que de verdad usa el juego)

Cada `Animation` de `assets/animations/json_clips.res`, `json_scenes.res` y `json_keeper.res` lleva
`set_meta("pack", {...})`, medido al convertir los JSON. Lo escribe `tools/json_anim/build_json_library.gd`
(`_meta`, línea 239; `_ball_touches`, 390; `_contact`, 464) y lo lee `PackLibrary.meta` (`scripts/animation/pack_library.gd:194`).
**Estos datos sí están conectados.** Están medidos sobre nuestro esqueleto, no copiados de UCS.

| campo | qué es | unidad / marco | cómo se obtiene | quién lo usa |
|---|---|---|---|---|
| `duration`, `loop`, `mirrored`, `role`, `source`, `library`, `alias`, `tags` | identidad | s | conversor | `PackLibrary.by_role` (199), todos |
| `root_total`, `root_path` | recorrido de la raíz (adelante, derecha) | m; `root_path` acumulado a 30 Hz | cinemática del JSON | `ActionMotion.root_at` / `step` (`action_motion.gd:57, 63`) |
| `heading_path`, `heading_mode` | rumbo del cuerpo (+ = izquierda) y si el clip gira el cuerpo (`turn`) | grados a 30 Hz | idem | `ActionMotion.heading_rel` (49), `PlayerActions.tick` |
| `natural_speed`, `natural_dir`, `natural_speed_json`, `natural_speed_stance` | velocidad y dirección naturales | m/s, (adelante, derecha) | idem | `JsonCatalog.gait_points`, `JsonCatalog.dir_points` |
| `v_in`, `v_out`, `dir_in`, `dir_out` | carrera de entrada y salida | m/s, grados | conversor (del JSON) | `JsonBallMove.plan_ids`, `JsonReceive.plan`, `JsonCatalog.kick_candidates` |
| `touches`, `strides` | apoyos y toques de pie del JSON | s, pie | JSON | conversor, visual |
| `ball_touches` | toques de pelota: `[t, pie (−1 izq / 1 der), punta (adelante, arriba, derecha), velocidad del pie (adelante, derecha)]` | s, m, m/s; marco del inicio del clip | cinemática del esqueleto canónico | `JsonBallMove.plan_ids` / `_touch_point` / `_touch` |
| `contact` (golpeos: 894 clips) | `time` y `json_time` (instante), `foot`, `pos` (punta: adelante, arriba, derecha), `speed`, `json_speed`, `clean` (pie bajo, delante, apoyo en el suelo), `kick_turn`, `body_turn`, `reach`, `root`, `planted`, `plant_y`, `plant_slide`, `path` / `path_dt` / `path_t0` (trayectoria del pie) | s, m, m/s, grados | `_contact` del conversor | `JsonCatalog.kick_candidates`, `BallHandler.plan_clip_kick`, `BallHandler.foot_contact_world` (584), `BallHandler.contact_samples_cached` (778) |
| `paths` (no volcado: trayectorias de las articulaciones `head`, `toe_l`, `toe_r`, manos…) | trayectoria por articulación | m, marco del clip | conversor (`build_json_library.gd`, línea 335) | `BallHandler.plan_aerial_kick`, `KeeperPlanner.path_world` |
| `kick_kind`, `kind`, `power`, `state`, `move`, `lie`, `release` | clase del golpeo, postura de caída, suelta (saques) | — | conversor | golpeo, caídas (`PlayerActions._json_getup`), saques |
| `pelvis_h`, `foot_floor_cm`, `reach_err_cm` | altura de la pelvis, pie respecto del piso, error del retarget | m, cm | conversor | diagnóstico |

Las recepciones tienen además un perfil por clip en `ReceiveProfiles.PROFILES` (`scripts/player/receive_profiles.gd`,
generado por `tools/json_anim/make_receive_profiles.py`). Campos: `part` (pie, pie en el aire, muslo, rodilla, pecho,
cabeza, pierna), `t` (instante del primer contacto), `status` (usable / conditional / pending / not_reception),
`confidence`, `conds`, `post_t` (pase posterior), `from_deg` (dirección de llegada, con el lado ya invertido respecto
del nombre), `v_in`, `v_out`, `turn`, `root`, `height`, `touches_after` y `note`.

## 4. Datos por familia: qué hay y qué se usa

| Familia | Dato de contacto que usa el juego | Dato de UCS disponible | ¿UCS conectado? |
|---|---|---|---|
| Golpeos (`kick_*`, 494 KICK) | `contact` medido (instante, pie, punta, limpieza) | pie (4), cuadro de contacto (24), velocidad del pie (5), −v_in (40), posición del evento (25-27) | no |
| Conducción y giros con pelota (`ball_*`) | `ball_touches` medidos | 4, 7-8, 9, 24-27, 47; v_in / v_out (5, 6) | **solo la ventana (7-8) en el toque orientado** |
| Recepciones (`receive*`, `control_stand`, `jostle_ball`) | `ReceiveProfiles` (parte, instante verificado o estimado) + cinemática directa (`JsonReceive.contact_point`, `json_receive.gd:176`) | 4, 5, 6, 24-27 (25-27 **no** son el punto de contacto: E4) | no |
| Arquero (`gk_*`) | trayectoria medida de las manos (`KeeperPlanner.hands_world`, `keeper_planner.gd:93`) | 24-27 (sin validar) | no |
| Golpeo aéreo (`header`, `volley`) | trayectorias medidas de la cabeza y de las puntas de los pies (meta `paths`, claves `head`, `toe_l`, `toe_r`; `BallHandler.AERIAL_SETS`, `ball_handler.gd:794`): el planificador busca el instante en que coinciden con la pelota prevista (`BallHandler.plan_aerial_kick`, 803). No se volcaron al inventario | 4, 24-27 | no |
| Barrida, entrada (`slide`, `tackle_stand`) | pie del clip en su instante (`PlayerActions._slide_candidate`, `player_actions.gd:263`) | 4, 24-27 | no |
| Giros sin pelota (`turn_*`) | `heading_path`, `v_in` | 9, **46** (el 47 vale 0 en TURN) | no |
| Marcha (`LOCO`) | `natural_speed` | 49 (∝ velocidad) | no |

## Anexo A. Estadística de los 52 campos (salida de `tools/transfer/adb_field_stats.py`)

| campo | min | max | distintos | % ceros | espejo (2k+1 frente a 2k) | correlación con nuestro banco (r > 0.5) |
|---:|---:|---:|---:|---:|---|---|
| 0 | 0 | 17 | 18 | 4 | igual en los dos | - |
| 1 | 0 | 7 | 8 | 5 | igual 0, signo cambiado 0, otro 2033 (de 2033) | - |
| 2 | 3 | 456 | 293 | 0 | igual en los dos | cuadros 1.00 |
| 3 | 2 | 69 | 60 | 0 | igual en los dos | cuadros 0.78 |
| 4 | 0 | 2058 | 57 | 34 | igual 1139, signo cambiado 0, otro 894 (de 2033) | - |
| 5 | -16 | 70 | 65 | 12 | igual en los dos | v_in 0.57 |
| 6 | -1 | 68 | 64 | 35 | igual en los dos | v_out 0.56 |
| 7 | -180 | 177 | 167 | 8 | igual 1347, signo cambiado 65, otro 621 (de 2033) | - |
| 8 | -177 | 180 | 167 | 8 | igual 1347, signo cambiado 65, otro 621 (de 2033) | - |
| 9 | -180 | 180 | 255 | 50 | cambia de signo (1023/1023) | - |
| 10 | 12 | 128 | 6 | 0 | igual en los dos | - |
| 11 | -90 | 8 | 11 | 70 | igual en los dos | - |
| 12 | 16 | 180 | 7 | 0 | igual en los dos | - |
| 13 | 4 | 90 | 6 | 0 | igual en los dos | - |
| 14 | -16 | 16 | 11 | 85 | cambia de signo (311/311) | - |
| 15 | 0 | 27 | 10 | 94 | igual en los dos | - |
| 16 | -1 | 63 | 63 | 25 | igual 0, signo cambiado 0, otro 2033 (de 2033) | - |
| 17 | 0 | 6 | 7 | 94 | igual 1971, signo cambiado 0, otro 62 (de 2033) | - |
| 18 | 0 | 69 | 58 | 11 | igual en los dos | cuadros 0.59 |
| 19 | 0 | 0 | 1 | 100 | siempre 0 | - |
| 20 | 2 | 207 | 84 | 0 | igual en los dos | cuadros 0.66 |
| 21 | 0 | 0 | 1 | 100 | siempre 0 | - |
| 22 | 0 | 0 | 1 | 100 | siempre 0 | - |
| 23 | 0 | 0 | 1 | 100 | siempre 0 | - |
| 24 | 0 | 196 | 69 | 46 | igual en los dos | - |
| 25 | -8370 | 1810 | 927 | 47 | igual en los dos | - |
| 26 | 96 | 3947 | 426 | 0 | igual en los dos | - |
| 27 | -4734 | 4734 | 1385 | 47 | cambia de signo (1069/1069) | - |
| 28 | 0 | 309 | 26 | 98 | igual en los dos | - |
| 29 | -7184 | 2784 | 333 | 83 | igual en los dos | - |
| 30 | 0 | 3152 | 47 | 79 | igual en los dos | - |
| 31 | -5233 | 5233 | 583 | 83 | cambia de signo (355/355) | - |
| 32 | 0 | 136 | 6 | 99 | igual en los dos | - |
| 33 | -2324 | 479 | 141 | 92 | igual en los dos | - |
| 34 | 0 | 2400 | 17 | 87 | igual en los dos | - |
| 35 | -1610 | 1610 | 235 | 92 | cambia de signo (155/155) | - |
| 36 | 0 | 305 | 4 | 100 | igual en los dos | - |
| 37 | -2159 | 479 | 131 | 93 | igual en los dos | - |
| 38 | 0 | 896 | 10 | 88 | igual en los dos | - |
| 39 | -1244 | 1244 | 219 | 93 | cambia de signo (145/145) | - |
| 40 | -18889 | 11486 | 1520 | 8 | igual en los dos | - |
| 41 | 0 | 0 | 1 | 100 | siempre 0 | - |
| 42 | 0 | 2 | 3 | 93 | igual en los dos | - |
| 43 | -3928 | 14 | 102 | 65 | igual 1515, signo cambiado 0, otro 518 (de 2033) | - |
| 44 | -21846 | 0 | 356 | 29 | igual en los dos | cuadros 0.51 |
| 45 | 0 | 1 | 2 | 71 | igual en los dos | - |
| 46 | -180 | 180 | 147 | 92 | cambia de signo (162/162) | - |
| 47 | -180 | 180 | 275 | 31 | cambia de signo (1412/1412) | yaw_end 0.71 |
| 48 | 10 | 158 | 62 | 0 | igual en los dos | - |
| 49 | 0 | 60 | 9 | 97 | igual en los dos | - |
| 50 | -31914 | 22995 | 383 | 42 | igual en los dos | - |
| 51 | 0 | 1 | 2 | 72 | igual en los dos | - |
