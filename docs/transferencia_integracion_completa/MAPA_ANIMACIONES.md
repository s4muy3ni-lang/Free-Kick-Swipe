# Mapa de animaciones: catálogo y conexión

La lista **completa, una fila por animación**, está en [`INVENTARIO_ANIMACIONES.csv`](INVENTARIO_ANIMACIONES.csv):
2024 filas, una por clip del banco (los 2022 JSON; el 0364 y otro archivo se parten en dos tramos) y 59 columnas. Este
documento explica cómo leerla, de dónde sale cada dato y cómo está cada familia. **No agrupa clips diferentes:** cada
clip se localiza por su `indice`, su `id_juego` o su `nombre_ucs` en el CSV.

Leyenda: **[C]** comprobado · **[D]** deducido · **[I]** inferido · **[?]** desconocido.

## 1. Cómo localizar un clip

| Si se tiene… | Buscar en la columna | Ejemplo |
|---|---|---|
| el número del JSON | `indice` | `0202` |
| el nombre de UCS | `nombre_ucs` | `ANM_CONTROL_ET0547_EX2024_TURNBALL_180L` |
| el id del juego | `id_juego` / `id_espejo` | `jn_ball_turn_0202` / `jn_ball_turn_0202_mirror` |
| la acción | `accion_rol` | `ball_turn` |

- **Archivo exacto:**
  - `ruta_json_paquete`: dentro del paquete `animaciones_futbol5_conectadas_y_sin_conectar/`, que clasifica los JSON
    según el estado de la APK 0.1.43. Es la carpeta del archivo, no su estado actual: el estado actual está en
    `estado_conexion` y `filtro_del_sistema`.
  - El zip original `animaciones_futbol5_JSON_limpios.zip` tiene los mismos archivos sin carpetas.
- **Recurso del juego:** `recurso_juego`, `res://assets/animations/<librería>.res :: <id>`:
  - `json_clips.res` (1131 clips de campo);
  - `json_scenes.res` (622 escenas, que se suman a las de campo);
  - `json_keeper.res` (271 del arquero).

  Lo indica el campo `library` de `tools/json_anim/selection.json`. Los espejos (`_mirror`, 1199 clips) están en la
  misma librería.
- **Los JSON no se versionan.** Para reconvertir: `JSON_SRC=<carpeta> godot --headless --path .
  res://tools/json_anim/build_json_library.tscn` (`tools/json_anim/README.md`).

## 2. Columnas del inventario

| Columna | Qué es | Fuente | Certeza |
|---|---|---|---|
| `indice`, `archivo_json_banco`, `nombre_ucs`, `categoria`, `cuadros_60fps`, `duracion_s`, `tramo` | identidad del clip en el banco | `index.json` del banco | [C] |
| `ruta_json_paquete`, `recurso_juego`, `id_juego`, `id_espejo`, `libreria`, `fuente_libreria` | dónde está | `INVENTARIO.csv` del paquete, `tools/json_anim/selection.json`, metadatos de la librería | [C] |
| `accion_rol`, `rol_antes_de_E2` | acción (rol) del clip en el juego | `docs/fases/E2_inventario_banco.csv` | [C] |
| `estado_conexion` | si el **rol** lo usa un sistema (`si` / `no` / `pendiente`) | `assets/animations/animdb.json` (tramos) | [C] |
| `filtro_del_sistema` | si **este clip** pasa el filtro del sistema que elige su rol: contacto limpio de los golpeos, perfil de recepción, toques medidos, situación en el sitio, etc. Es la diferencia entre «está en el banco» y «puede salir en el juego» | reglas del código, en `tools/transfer/make_inventory.py` (`system_filter`) | [C] para las reglas que nombra |
| `sistemas`, `motivo_estado` | sistema que lo usa y motivo del estado | inventario E2 | [C] |
| `sistema_que_selecciona`, `condicion_entrada`, `condicion_salida` | quién lo elige y con qué condición | código, por rol (`ROLE_RULES` del generador) | [C] |
| `movimiento_descripcion` | qué movimiento hace: giro (+ = izquierda), recorrido de la raíz, velocidades, toques y golpeo | metadatos medidos | [C] |
| `transicion_entrada_compatible`, `transicion_salida_compatible` | ciclos de marcha desde y hacia los que encaja, con la tolerancia de velocidad de su sistema | metadatos y constantes del código | [C] (regla del código) |
| `balon_en_contacto_m_adelante_arriba_derecha` | dónde planifica el juego la pelota en el contacto | `JsonBallMove.plan_ids` (punta + 0.12 m) y `BallHandler.plan_clip_kick` | [C] |
| `movimiento_heading_mode`, `bucle`, `giro_cuerpo_juego_grados`, `raiz_total_m_adelante_derecha`, `v_in_juego_m_s`, `v_out_juego_m_s` | metadatos del clip en el juego | `PackLibrary.meta` | [C] |
| `toques_pelota_juego` | toques de pelota: instante, pie y punta (adelante, arriba, derecha), en el marco del inicio del clip | `ball_touches` | [C] |
| `contacto_golpe_*` | golpeo: instante (s), pie, punta, velocidad del pie, limpio, giro de salida | `contact` | [C] |
| `json_toques_cuadro_pie`, `json_dir_out_grados`, `json_yaw_end_grados` | datos del JSON original | banco | [C] |
| `ucs_*` | campos del registro de `animdb.adb` (ver `DATOS_UCS.md`) | `animdb.adb` | según el campo |

Notas sobre las columnas de UCS:

- `ucs_campo3_byte_cabecera_sat` **no es el cuadro del toque**.
- El cuadro de contacto de UCS en los golpeos es `ucs_campo24_cuadro_evento_pelota` [D].
- `ucs_campo5_x10` y `ucs_campo6_x10` cambian de significado por familia.
- El giro de los TURN está en `ucs_giro_turn_campo46`.

**Lados:** los nombres de UCS (L/R) dicen casi siempre el lado contrario al de nuestros datos. Por ejemplo,
`jn_ball_turn_0202` (`TURNBALL_180L`) gira −164°, a la derecha. Nunca hay que elegir por el nombre (`DATOS_UCS.md`
§1.3).

## 3. Estado por categoría

«Pasa el filtro» = puede salir en el juego. «Rol conectado sin filtro comprobado» = su rol lo usa un sistema sin un
filtro estático que este inventario pueda evaluar: lo decide el planificador en cada jugada (ciclos de marcha, caídas,
levantarse, balón parado, giros sin pelota, cabezazos y voleas).

| categoría UCS (campo 0 de animdb.adb) | clips | pasa el filtro | no pasa | rol conectado sin filtro comprobado | no conectado o pendiente |
|---|---:|---:|---:|---:|---:|
| NIS | 603 | 174 | 148 | 30 | 251 |
| KICK | 494 | 202 | 133 | 155 | 4 |
| CONTROL | 269 | 216 | 12 | 8 | 33 |
| GKSAVE | 181 | 180 | 0 | 1 | 0 |
| TURN | 123 | 0 | 1 | 97 | 25 |
| STAND | 86 | 63 | 10 | 12 | 1 |
| GETUP | 60 | 0 | 0 | 60 | 0 |
| LOCO | 45 | 3 | 6 | 18 | 18 |
| KICKSETPIECE | 36 | 0 | 0 | 32 | 4 |
| FALL | 29 | 0 | 0 | 29 | 0 |
| STUMBLE | 28 | 0 | 0 | 28 | 0 |
| TACKLESLIDE | 18 | 0 | 0 | 18 | 0 |
| TACKLE | 16 | 4 | 12 | 0 | 0 |
| GKKICK | 12 | 0 | 0 | 12 | 0 |
| THROW | 12 | 0 | 0 | 10 | 2 |
| GKTHROW | 6 | 0 | 0 | 6 | 0 |
| SIDESTEP | 6 | 1 | 0 | 5 | 0 |
| **total** | **2024** | **843** | **322** | **521** | **338** |

## 4. Estado por acción (rol)

La columna «sistema» resume quién elige el clip. Las fichas de cada acción están en `ACCIONES_FUTBOLISTICAS.md`.

| acción (rol) | clips | estado del rol: si / no / pend. | pasa el filtro | no pasa | sin filtro comprobado | sistema que lo elige y ejecuta |
|---|---:|---|---:|---:|---:|---|
| `gk_dive` | 108 | 108 / 0 / 0 | 108 | 0 | 0 | Goalkeeper + KeeperPlanner.plan_save |
| `nis_misc` | 107 | 0 / 107 / 0 | 0 | 0 | 0 | - |
| `dejected` | 95 | 95 / 0 / 0 | 48 | 47 | 0 | reacciones de gol |
| `header` | 95 | 95 / 0 / 0 | 0 | 0 | 95 | BallHandler golpeo aereo (plan aereo, header/volley) |
| `kick_turn` | 71 | 71 / 0 / 0 | 65 | 6 | 0 | BallHandler.plan_turn_kick (golpeo girando) |
| `kick_shot` | 70 | 70 / 0 / 0 | 35 | 35 | 0 | BallHandler.plan_clip_kick con JsonCatalog.kick_candidates |
| `celebrate` | 64 | 64 / 0 / 0 | 34 | 30 | 0 | reacciones de gol |
| `kick_pass` | 64 | 64 / 0 / 0 | 41 | 23 | 0 | BallHandler.plan_clip_kick con JsonCatalog.kick_candidates (scripts/animation/json_catalog.gd) |
| `turn_start` | 63 | 63 / 0 / 0 | 0 | 0 | 63 | Footballer._json_turn_move (giro sin pelota) |
| `kick_pass_soft` | 58 | 58 / 0 / 0 | 29 | 29 | 0 | BallHandler.plan_clip_kick con JsonCatalog.kick_candidates |
| `receive` | 57 | 45 / 0 / 12 | 45 | 0 | 0 | JsonReceive (recepcion con clip) |
| `ball_skill` | 55 | 55 / 0 / 0 | 55 | 0 | 0 | JsonBallMove (intencion skill; y steer si es de control con dribble) |
| `volley` | 54 | 54 / 0 / 0 | 0 | 0 | 54 | BallHandler golpeo aereo (plan aereo, header/volley) |
| `ball_turn` | 51 | 51 / 0 / 0 | 47 | 4 | 0 | JsonBallMove (intencion turn; y steer si es de control con dribble) |
| `crowd` | 48 | 0 / 48 / 0 | 0 | 0 | 0 | - |
| `gk_catch` | 47 | 47 / 0 / 0 | 47 | 0 | 0 | Goalkeeper + KeeperPlanner |
| `kick_shot_hard` | 43 | 43 / 0 / 0 | 11 | 32 | 0 | BallHandler.plan_clip_kick con JsonCatalog.kick_candidates |
| `celebrate_team` | 43 | 43 / 0 / 0 | 12 | 31 | 0 | reacciones de gol |
| `idle_fidget` | 39 | 39 / 0 / 0 | 36 | 3 | 0 | locomocion (gestos de espera) |
| `getup` | 39 | 39 / 0 / 0 | 0 | 0 | 39 | PlayerActions._json_getup |
| `mascot` | 38 | 0 / 38 / 0 | 0 | 0 | 0 | - |
| `nis_idle` | 35 | 35 / 0 / 0 | 29 | 6 | 0 | reacciones (gestos de espera) |
| `receive_turn` | 29 | 20 / 0 / 9 | 20 | 0 | 0 | JsonReceive (recepcion con clip) |
| `nis_walk` | 28 | 0 / 28 / 0 | 0 | 0 | 0 | - |
| `warmup` | 28 | 28 / 0 / 0 | 21 | 7 | 0 | reacciones (gestos de espera) |
| `setpiece_shot` | 27 | 27 / 0 / 0 | 0 | 0 | 27 | balon parado |
| `fall` | 26 | 26 / 0 / 0 | 0 | 0 | 26 | PlayerActions._json_fall (caida) |
| `manager` | 25 | 0 / 25 / 0 | 0 | 0 | 0 | - |
| `control_stand` | 24 | 20 / 2 / 2 | 20 | 0 | 0 | JsonReceive (recepcion con clip) |
| `gk_gesture` | 22 | 22 / 0 / 0 | 0 | 0 | 22 | arquero |
| `turn_run` | 22 | 22 / 0 / 0 | 0 | 0 | 22 | Footballer._json_turn_move (giro sin pelota, solo persona) |
| `kick_back` | 21 | 21 / 0 / 0 | 15 | 6 | 0 | BallHandler.plan_turn_kick (golpeo girando) |
| `gk_getup` | 21 | 21 / 0 / 0 | 0 | 0 | 21 | arquero |
| `ball_turn_stop` | 20 | 20 / 0 / 0 | 13 | 7 | 0 | JsonBallMove (turn_for_kick, drag) |
| `celebrate_scorer` | 20 | 20 / 0 / 0 | 6 | 14 | 0 | reacciones de gol |
| `slide` | 18 | 18 / 0 / 0 | 0 | 0 | 18 | PlayerActions.try_slide_tackle (barrida) |
| `clap` | 18 | 18 / 0 / 0 | 8 | 10 | 0 | reacciones |
| `gk_scoop` | 18 | 18 / 0 / 0 | 18 | 0 | 0 | arquero |
| `wall` | 18 | 18 / 0 / 0 | 11 | 7 | 0 | balon parado |
| `jostle` | 17 | 17 / 0 / 0 | 11 | 6 | 0 | presion (PlayerActions) |
| `tackle_stand` | 16 | 16 / 0 / 0 | 4 | 12 | 0 | PlayerActions (entrada de pie) |
| `stumble` | 13 | 13 / 0 / 0 | 0 | 0 | 13 | caidas (PlayerActions) |
| `gk_kick` | 12 | 12 / 0 / 0 | 0 | 0 | 12 | arquero |
| `avoid` | 12 | 12 / 0 / 0 | 0 | 0 | 12 | esquivar barrida (PlayerActions.avoid_tackle) |
| `gesture` | 11 | 11 / 0 / 0 | 10 | 1 | 0 | reacciones |
| `stop` | 11 | 11 / 0 / 0 | 0 | 0 | 11 | locomocion |
| `gk_turn` | 11 | 0 / 11 / 0 | 0 | 0 | 0 | - |
| `throw_in` | 10 | 10 / 0 / 0 | 0 | 0 | 10 | balon parado |
| `setpiece_pass` | 9 | 9 / 0 / 0 | 0 | 0 | 9 | balon parado |
| `idle_ready` | 8 | 8 / 0 / 0 | 8 | 0 | 0 | locomocion |
| `kick_lob` | 8 | 8 / 0 / 0 | 6 | 2 | 0 | BallHandler.plan_clip_kick con JsonCatalog.kick_candidates |
| `gk_block` | 7 | 7 / 0 / 0 | 7 | 0 | 0 | arquero |
| `ball_start` | 7 | 7 / 0 / 0 | 6 | 1 | 0 | JsonBallMove (intencion start, si v_out >= 1) |
| `ball_stop` | 7 | 7 / 0 / 0 | 6 | 1 | 0 | JsonBallMove (intencion stop) |
| `setpiece_miss` | 7 | 0 / 7 / 0 | 0 | 0 | 0 | - |
| `angry` | 6 | 6 / 0 / 0 | 4 | 2 | 0 | reacciones |
| `start` | 6 | 1 / 5 / 0 | 0 | 0 | 1 | transiciones de marcha (Footballer) |
| `gk_loco` | 6 | 0 / 6 / 0 | 0 | 0 | 0 | - |
| `gk_idle_var` | 5 | 5 / 0 / 0 | 0 | 0 | 5 | arquero |
| `sprint` | 5 | 5 / 0 / 0 | 0 | 0 | 5 | Marcha (JsonCatalog.GAIT) |
| `loco_sprint` | 5 | 0 / 5 / 0 | 0 | 0 | 0 | - |
| `gk_throw` | 4 | 4 / 0 / 0 | 0 | 0 | 4 | arquero |
| `sidestep` | 4 | 4 / 0 / 0 | 0 | 0 | 4 | locomocion |
| `nis_sit` | 4 | 0 / 4 / 0 | 0 | 0 | 0 | - |
| `walk` | 4 | 4 / 0 / 0 | 0 | 0 | 4 | Marcha (JsonCatalog.GAIT) |
| `idle` | 4 | 4 / 0 / 0 | 0 | 0 | 4 | Marcha (JsonCatalog.GAIT, reposo) |
| `jostle_ball` | 4 | 4 / 0 / 0 | 4 | 0 | 0 | JsonReceive (recepcion con clip) |
| `loco_walk` | 4 | 0 / 4 / 0 | 0 | 0 | 0 | - |
| `turn_stop` | 4 | 0 / 4 / 0 | 0 | 0 | 0 | giros sin pelota (Footballer) |
| `dribble_fast` | 3 | 1 / 2 / 0 | 0 | 0 | 1 | Marcha con pelota (JsonCatalog.CARRY) |
| `referee` | 3 | 2 / 1 / 0 | 0 | 0 | 2 | arbitro |
| `step_stand` | 3 | 0 / 3 / 0 | 0 | 0 | 0 | giros sin pelota (Footballer) |
| `receive_foot` | 3 | 3 / 0 / 0 | 0 | 0 | 3 | JsonReceive (recepcion con clip) |
| `dribble_run` | 3 | 1 / 2 / 0 | 0 | 0 | 1 | Marcha con pelota (JsonCatalog.CARRY) |
| `dribble_sprint` | 3 | 1 / 2 / 0 | 0 | 0 | 1 | Marcha con pelota (JsonCatalog.CARRY) |
| `gk_roll` | 2 | 2 / 0 / 0 | 0 | 0 | 2 | arquero |
| `gk_place` | 2 | 2 / 0 / 0 | 0 | 0 | 2 | arquero |
| `run` | 2 | 2 / 0 / 0 | 0 | 0 | 2 | Marcha (JsonCatalog.GAIT) |
| `gk_direct` | 2 | 2 / 0 / 0 | 0 | 0 | 2 | arquero |
| `kick_cross` | 2 | 0 / 2 / 0 | 0 | 0 | 0 | BallHandler.plan_clip_kick con JsonCatalog.kick_candidates |
| `jog` | 2 | 2 / 0 / 0 | 0 | 0 | 2 | Marcha (JsonCatalog.GAIT) |
| `dribble_jog` | 2 | 1 / 1 / 0 | 0 | 0 | 1 | Marcha con pelota (JsonCatalog.CARRY) |
| `loco_jog` | 2 | 0 / 2 / 0 | 0 | 0 | 0 | - |
| `shove` | 2 | 2 / 0 / 0 | 0 | 0 | 2 | PlayerActions.shoulder_charge (carga) |
| `setpiece_lob` | 2 | 2 / 0 / 0 | 0 | 0 | 2 | balon parado |
| `gk_miss` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | arquero |
| `gk_sidestep` | 1 | 1 / 0 / 0 | 1 | 0 | 0 | arquero |
| `dir_side` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | locomocion direccional |
| `dribble_walk` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | Marcha con pelota (JsonCatalog.CARRY, FootballerVisual) |
| `idle_ball_var` | 1 | 0 / 1 / 0 | 0 | 0 | 0 | - |
| `jump` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | reacciones (Footballer) |
| `dir_fwd_diag` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | locomocion direccional |
| `dir_back_diag` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | locomocion direccional |
| `dir_back` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | locomocion direccional |
| `gk_idle_ball` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | arquero |
| `idle_ball` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | Marcha con pelota (JsonCatalog.CARRY, reposo) |
| `ball_sole` | 1 | 0 / 1 / 0 | 0 | 0 | 0 | - |
| `receive_chest` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | reacciones (Receive) |
| `lie` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | caidas (PlayerActions) |
| `trip` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | caidas (PlayerActions) |
| `gk_idle` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | arquero |
| `defeat_end` | 1 | 1 / 0 / 0 | 1 | 0 | 0 | reacciones |
| `kick_flick` | 1 | 0 / 1 / 0 | 0 | 0 | 0 | - |
| `stumble_light` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | caidas (PlayerActions) |
| `thumbs_up` | 1 | 1 / 0 / 0 | 1 | 0 | 0 | reacciones |
| `dir_fwd_diag_walk` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | locomocion direccional |
| `dir_back_walk` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | locomocion direccional |
| `fall_hit` | 1 | 1 / 0 / 0 | 0 | 0 | 1 | caidas (PlayerActions) |
| `run_change` | 1 | 0 / 1 / 0 | 0 | 0 | 0 | giros sin pelota (Footballer) |
| `throw_prep` | 1 | 0 / 1 / 0 | 0 | 0 | 0 | - |
| `loco_side` | 1 | 0 / 1 / 0 | 0 | 0 | 0 | - |


## 5. Familias: cómo se eligen y qué falta

| Familia | Selección (archivo:línea) | Datos de contacto | Notas |
|---|---|---|---|
| Golpeos a ras (`kick_pass*`, `kick_shot*`, `kick_lob`, `kick_cross`) | `JsonCatalog.kick_candidates` (`json_catalog.gd:108`) + `BallHandler.plan_clip_kick` (`ball_handler.gd:895`) | `contact` medido | 121 golpeos no pasan por contacto no limpio (pie al costado, alto o sin apoyo) |
| Golpeos girando (`kick_turn`, `kick_back`) | `BallHandler.plan_turn_kick` (1013) | `contact.kick_turn` | 12 no pasan (punta a > 0.35 m de altura) |
| Golpeo aéreo (`header`, `volley`) | `BallHandler.plan_aerial_kick` (803) | trayectorias `paths` | el cabezazo no tiene `contact`; usa la trayectoria de la cabeza |
| Movimiento con pelota (`ball_turn`, `ball_skill`, `ball_turn_stop`, `ball_stop`, `ball_dribble`, `ball_start`) | `JsonBallMove.consider` (`json_ball_move.gd:204`) | `ball_touches` | 13 sin toques medidos no pasan; toque orientado: `tools/json_anim/steer_pool.json`; arranque: `start_pool.json` |
| Recepciones (`receive`, `receive_turn`, `control_stand`, `jostle_ball`) | `JsonReceive.plan` (`json_receive.gd:402`) | `ReceiveProfiles` | 23 `pendiente` (sin contacto confirmado a ojo, `docs/fases/F3_verificacion_visual_70.md`); cabeza sin conectar |
| Marcha (`idle`, `walk`, `jog`, `sprint`, `dribble_*`, `idle_ball`) | `JsonCatalog.GAIT` / `CARRY` | — | 25 variantes de marcha y conducción sin conectar (no hacen falta: un ciclo por escalón) |
| Mezcla direccional (`dir_*`) | `JsonCatalog.dir_points` | — | marcaje y arquero |
| Giros sin pelota (`turn_start`, `turn_run`) | `Footballer._json_turn_move` (`footballer.gd:513`) | — | 13 giros fuera de franja sin conectar |
| Arquero (`gk_*`) | `KeeperPlanner.plan_save` (`keeper_planner.gd:212`), `Goalkeeper` | trayectoria de las manos | 11 giros del arquero sin conectar |
| Entradas y caídas (`slide`, `tackle_stand`, `shove`, `fall`, `getup`, `stumble`, `avoid`) | `PlayerActions` (`player_actions.gd`) | pie del clip en su instante | `tackle_stand`: 12 de 16 no pasan el filtro en el sitio |
| Presentación (festejos, lamentos, gestos, esperas, barrera) | `JsonCatalog.situation_clip` (`json_catalog.gd:169`) | — | solo los de raíz ≤ 1 m y ≥ 0.6 s; 139 escenas y 111 personajes fuera de la cancha sin conectar (no hay escenas ni entorno en el modo 4) |
| Balón parado (`setpiece_*`, `throw_in`, `gk_kick`, `gk_throw`) | `SetPiece` (`scripts/gameplay/set_piece.gd`), `Goalkeeper` | `contact` / `release` | sin conectar: 5 balones parados en los que el pie no llega (córner y penal) y 2 saques de banda sin lanzamiento |

## 6. Clips pendientes (23)

Recepciones sin contacto confirmado en la verificación visual:

`jn_receive_0590`, `jn_receive_0596`, `jn_receive_0616`, `jn_receive_0620`, `jn_control_stand_1326`, `jn_receive_1840`, `jn_receive_turn_2132`, `jn_receive_turn_2140`, `jn_receive_2142`, `jn_receive_turn_2146`, `jn_receive_turn_2148`, `jn_receive_2480`, `jn_receive_2484`, `jn_control_stand_3100`, `jn_receive_3146`, `jn_receive_turn_3152`, `jn_receive_turn_3156`, `jn_receive_turn_3158`, `jn_receive_3160`, `jn_receive_turn_3170`, `jn_receive_3172`, `jn_receive_turn_3174`, `jn_receive_3178`.

El motivo de cada una está en su perfil (`ReceiveProfiles.PROFILES`, campo `note`).

## 7. Animaciones que no existen en el banco

No confundir con las desconectadas. El banco **no trae**:

- ruleta (`Soccer_Spin`);
- giro en sprint (`Sprint_Turn`);
- malabares;
- un despeje propio de jugador de campo.

Fuente: `LEEME.md` del paquete. **[C]** En la librería no hay clips con esos roles.

## 8. Cómo regenerar

```
godot --headless --path . res://tools/transfer/dump_library_meta.tscn        # OUT=<salida>/library_meta.json
python3 tools/transfer/make_inventory.py <index.json> <animdb.adb> <library_meta.json>
```

