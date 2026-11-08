# Auditoría previa a la implementación — Fase 0 de la guía maestra de animaciones

- **Fecha:** 2026-11-07 · **Rama:** `integracion-openai` · **Commit base:** `04ed11050885e0dcffbd7820ee6ac1e94572c2bd`
  (`04ed110`). El código de juego y de pruebas es **idéntico** al del commit auditado `5fb4f27`: entre ambos solo cambió
  documentación (`git diff --stat 5fb4f27 04ed110 -- . ':!docs'` vacío).
- **Godot:** 4.7.2 oficial (`ed1daf0bf`). **Esta fase no modifica código, recursos ni pruebas del juego.** Solo añade
  documentación, la herramienta de medición (`docs/integration/fase0/medicion/`) y la evidencia.

## 0. Bloqueos y su estado

| Bloqueo inicial | Estado (actualizado 2026-11-07) |
|---|---|
| La guía llegó cortada en 3.3 | **Resuelto**: el usuario envió el resto (esquema del CSV, fases 2 a 12, sección 15.0). |
| No estaba el ZIP de los 2.022 JSON | **Resuelto**: el usuario subió `animaciones_futbol5_nombres_originales1.zip` (ver sección 1.1). |
| El tag `pre-audit-phase-0` no se pudo subir | **Sigue**: el proxy de la sesión corta el push de tags. El tag existe en la copia local sobre `04ed110`, que sí está en `origin/integracion-openai`. Para fijarlo en GitHub: `git tag -a pre-audit-phase-0 04ed11050885e0dcffbd7820ee6ac1e94572c2bd -m "Linea base Fase 0" && git push origin pre-audit-phase-0`. |

## 1. Identificación de los dos paquetes (por contenido, no por nombre)

| Paquete | Ubicación | Contenido verificado | Uso |
|---|---|---|---|
| ZIP de integración | `docs/integration/FUTBOL5_GODOT_4_7_2_INTEGRACION.zip` (sha256 `17c31729…c18aa8c`) | 358 entradas; 43 JSON, de los cuales **38 son `EJ_*`** (clips sintéticos) y 5 de catálogo/configuración | Solo referencia técnica. No se importa, no se cuenta, no mide cobertura |
| ZIP de los 2.022 JSON | `animaciones_futbol5_nombres_originales1.zip` (subido por el usuario; sha256 `3fa72c92…d8b374f`, 8.383.382 bytes; **no se versiona**) | 2.023 JSON: **2.022 clips** `NNNN_<CATEGORIA>_<NOMBRE>.json` + `index.json` (`count: 2022`, 17 categorías). Ningún `EJ_*` | Fuente de verdad del banco; inmutable |

### 1.1 Verificación del ZIP de los 2.022 JSON

- Extraído en un directorio de trabajo externo al repositorio (no se copia al proyecto ni se modifica).
- Los 2.022 índices `NNNN` coinciden **uno a uno** con los de `animdb.json` (0 sobrantes, 0 faltantes); los nombres
  coinciden salvo 3 nombres largos que el nombre de archivo trunca (`1944`, `1946`, `1948`).
- Estructura de cada clip: `name`, `index`, `mirrored`, `fps`, `frames`, `key_frame`, `length_frames`, 19
  `joint_names`, `times`, `joints` (posiciones por fotograma clave), `root` y `meta` (categoría, estado, tipo, potencia,
  duración, bucle, velocidad, rumbo inicial y final, raíz final).
- Hashes: [`fase0/hashes_json_originales.sha256`](fase0/hashes_json_originales.sha256) (2.022 clips + `index.json`).
  Comprobación: `cd <dir extraído> && sha256sum -c <repo>/docs/integration/fase0/hashes_json_originales.sha256`.
- Correspondencia con las librerías convertidas: en 1.899 de 2.022 fuentes la duración convertida (suma de sus tramos)
  coincide con la del original a ±0,06 s. En 123 difiere (−1,27 a +2,88 s), sobre todo cabezazos, atajadas, golpeos
  girando y regates: el conversor (`tools/json_anim/build_json_library.gd`) recorta ciclos entre apoyos y ventanas
  alrededor de los eventos. No es un fallo de integridad; queda como punto a revisar en la Fase 10 (que los recortes no
  desplacen eventos de contacto).
- Para que la prueba de bloqueo «hashes de los 2.022 JSON» corra en CI haría falta versionar el ZIP o alojarlo en un
  sitio accesible por el workflow: decisión del propietario (8,4 MB). Mientras tanto la comprobación se ejecuta en
  local cuando el ZIP está presente.

El banco real se cuenta sobre sus derivados versionados: **2.022 fuentes** (índices de `animdb.json`), **2.024 tramos**,
**3.223 variantes** (1.199 espejos), 111 roles.

## 2. Protección de la línea base

- **Tag local** `pre-audit-phase-0` → `04ed110` (ver bloqueo en 0).
- **`respaldo-f3`:** `3d47a07bebeff620df7beee59e19329587963514` antes y después; sin commits, merges ni cambios.
- **Instantánea:** `git archive --format=zip pre-audit-phase-0 assets/animations resources/animation scripts/animation
  scripts/player/receive_profiles.gd` → 31.568.858 bytes, sha256 `b4925ef415af16ae02844d190a376ad21bcacf004bbec948479273c5b46db1b3`
  (reproducible desde el tag; no se versiona el ZIP para no duplicar 31 MB).
- **Hashes:** [`fase0/hashes_recursos_animacion.sha256`](fase0/hashes_recursos_animacion.sha256): 47 archivos (las 8
  librerías `.res`, `animdb.json`, rutas, scripts de animación, perfiles y el ZIP de integración). Comprobación al final
  de la fase: `sha256sum -c` sin diferencias (sección 11). Hashes de los JSON originales: ver 1.1.

## 3. Sistemas reales (tabla 1.1 de la guía, verificada en el código)

| Sistema | Archivo | Responsabilidad real | Funciones de entrada |
|---|---|---|---|
| `PackLibrary` | `scripts/animation/pack_library.gd` | Carga `json_clips.res` + `json_scenes.res` (unidas) y `json_keeper.res`; aplica `ClipRolesOverlay.ROLE`; índices rol → ids y alias Mixamo → id | `_ensure`, `by_role`, `resolve`, `meta`, `clip`, `vary_aliases` |
| `AnimDB` | `scripts/animation/anim_db.gd` | Catálogo de fuentes, acciones, UCS, conexiones nuevas y rutas de presentación | `candidates`, `ucs`, `connection`, `presentation_routes`, `catalog` |
| `JsonCatalog` | `scripts/animation/json_catalog.gd` | Escalones de marcha y conducción, mezcla direccional, candidatos de golpeo por carga, clips de situación | `gait_points`, `dir_points`, `kick_candidates`, `situation_clip` |
| `AnimationCatalog` | `scripts/animation/animation_catalog.gd` | Situaciones de presentación; delega golpeos del modo 4 en `JsonCatalog` | `resolve`, `kick_candidates` |
| `BallPredictor` | `scripts/ball/ball_predictor.gd` | Trayectoria futura (gravedad, arrastre, bote, rodadura, Magnus) | `trajectory`, `crossing_x` |
| `BallHandler` | `scripts/player/ball_handler.gd` | Botones, golpeos (rasos, girando, aéreos), conducción, primer toque físico, orquesta `JsonReceive`/`JsonBallMove`/`BallTurn`/`DragBack` | `update`, `request_kick`, `plan_clip_kick`, `plan_turn_kick`, `plan_aerial_kick`, `_start_clip_kick`, `_finish_clip_kick`, `_try_dribble_touch`, `_try_first_touch` |
| `JsonReceive` | `scripts/player/json_receive.gd` | Recepción con clip elegido antes de que llegue la pelota | `consider`, `plan`, `_update_approach`, `contact_velocity`, `ended` |
| `JsonBallMove` | `scripts/player/json_ball_move.gd` | Movimientos con pelota por toques del clip (giros, regates, frenadas, toque orientado, arranque) y ejecución de la recepción | `consider`, `plan_move`, `plan_ids`, `start_receive`, `step`, `_touch`, `finish`, `_abort` |
| `KeeperPlanner` | `scripts/goalkeeper/keeper_planner.gd` | Atajada por trayectoria de manos de cada clip | `plan_save`, `candidates` |
| `Goalkeeper` | `scripts/goalkeeper/goalkeeper.gd` | Máquina de estados propia del arquero (**no usa `ActionArbiter`**) | `_assess_shot`, `_begin_action`, `_tick_action`, `_try_turn`, `_begin_distribution` |
| `ActionArbiter` | `scripts/player/action_arbiter.gd` | Prioridades por nivel, testigos, interrupción, caducidad, poses en el sitio | `request`, `play`, `handover`, `release`, `relevel`, `cut_pose` |
| `PlayerActions` | `scripts/player/player_actions.gd` | Acciones con raíz (caídas, barridas, giros, movimientos con pelota, saques), transiciones de locomoción | `start`, `start_move`, `tick`, `try_locomotion_transition`, `suffer_contact`, `try_slide_tackle` |
| `ActionMotion` | `scripts/animation/action_motion.gd` | Raíz (`root_path`) y rumbo (`heading_path`) del clip | `start`, `step`, `heading_at`, `offset_between` |
| `FootballerVisual` | `scripts/player/footballer_visual.gd` | `AnimationTree`: BlendSpaces de marcha, conducción y dirección; **una** ranura de acción (`PackShot`) | `_setup_animation_tree`, `play_pack_clip`, `play_situation`, `stop_current_action`, `drive_motion` |
| `TouchFootIK` | `scripts/animation/touch_foot_ik.gd` | IK de dos huesos del pie (corrección ≤ 0,16 m; también absoluta) | `set_target`, modificador del esqueleto |
| `AIInput` | `scripts/ai/ai_input.gd` | Decisiones de la IA; **solo pide golpeos en `_decide_with_ball`** (posesión a ras de suelo) | `_decide`, `_decide_with_ball`, `_start_button`, `_decide_dead_ball` |
| `MatchPresentation` | `scripts/gameplay/match_presentation.gd` | Un humanoide por actor (público, técnico, suplente, mascota) y equipo, que rota su grupo de clips por evento | `request`, `_select`, `_on_event` |
| `SetPiece` | `scripts/gameplay/set_piece.gd` | Saques con raíz real y contacto medido | `execute`, `ai_execute`, `_resolve`, `_track_contact` |
| `JsonRig` / `JsonRetarget` | `scripts/animation/json_rig.gd`, `json_retarget.gd` | Esqueleto canónico y conversión (herramienta fuera de juego) | — |

## 4. Mapa de llamadas por familia de acción

| Familia | Solicita | Planifica | Arbitra | Ejecuta | Valida el contacto |
|---|---|---|---|---|---|
| Locomoción | `Footballer._player_step` (entrada humana o `AIInput`) | `Locomotion.step` | — (capa base) | `FootballerVisual.drive_motion` (BlendSpaces) | — |
| Transición de locomoción | `Footballer._json_turn_move` | `PlayerActions.transition_score` | `ActionArbiter` (BODY) | `PlayerActions.tick` + `ActionMotion` | — |
| Giro sin pelota | `Footballer._json_turn_move` | selección en la misma función (rumbo y `v_in`) | `ActionArbiter` (BODY) | `PlayerActions.start_move` | — |
| Pase / tiro / centro raso | botones → `BallHandler._update_buttons` → `request_kick` | `plan_clip_kick` (`JsonCatalog.kick_candidates`) | `ActionArbiter` (KICK) | `_start_clip_kick` → `play_pack_clip` | `_finish_clip_kick`: pelota a ≤ `kick_reach()` (0,65 m) del punto de contacto del clip |
| Golpeo girando | idem | `plan_turn_kick` (`kick_turn`, `kick_back`) | idem | idem + `kick_body_yaw` | idem |
| Cabezazo / volea | idem con pelota > 0,5 m | `plan_aerial_kick` (`header`, `volley`) | idem | idem | idem (sin exigencia de distancia en `test_aerial_kicks`) |
| Recepción | `BallHandler.update` → `JsonReceive.consider` | `JsonReceive.plan` (`ReceiveProfiles`) | `ActionArbiter` (BALL_MOVE) | `JsonBallMove.start_receive` → `PlayerActions.start_move` | `JsonBallMove._receive_step` (parte del cuerpo a su radio + `PART_REACH`) |
| Movimiento con pelota | `BallHandler.update` → `JsonBallMove.consider` | `plan_move` / `plan_ids` | `ActionArbiter` (BALL_MOVE) | `PlayerActions.tick` → `JsonBallMove.step` | `JsonBallMove._touch` (`MISS_DIST` 0,5 m) |
| Conducción | `BallHandler._try_dribble_touch` | intervalos y `_foot_strike` | — | marcha con pelota (BlendSpace) | punta animada (render) o de datos (headless) |
| Barrida | `Footballer` (presión IA o botón) → `try_slide_tackle` | `_slide_candidate` | `ActionArbiter` (BODY) | `PlayerActions.start` | `_resolve_slide` (pie a ≤ 0,65 m) |
| Caída / levantarse | `_check_player_collisions`, faltas → `suffer_contact` | `_json_fall`, `_directed_pick`, `_json_getup` | `ActionArbiter` (FALL) | `PlayerActions` (cadena) | — |
| Atajada | `Goalkeeper._assess_shot` | `KeeperPlanner.plan_save` | máquina de estados del arquero | `Goalkeeper._begin_action` → `play_pack_clip` + `_motion` | manos reales en `_tick_action` |
| Saque | `MatchScene` / `MatchManager` → `SetPiece` | `SetPiece.execute` (raíz hasta el contacto) | `ActionArbiter` (SET_PIECE) | `PlayerActions.start` | `_track_contact` (`CONTACT_RADIUS` 0,45 m) |
| Gestos y capas | `Footballer._gait_overlays`, `_json_idle`, reacciones a eventos | `JsonCatalog.situation_clip`, nombres fijos | `ActionArbiter` (GESTURE/OVERLAY, en el sitio) | `play_pack_clip` | corte si el cuerpo corre (`_json_clip_slides`) |
| Presentación | `MatchPresentation._on_event` | cursor por grupo actor/contexto | — | humanoide propio + `ActionMotion` | — |

## 5. Vigencia de la auditoría del 2026-11-07

El código es idéntico, así que la descripción de arquitectura sigue vigente. Las cifras se **volvieron a medir** con la
herramienta de esta fase; difieren algo de las de la auditoría porque los partidos no son deterministas (sección 7) y
porque esta vez se sembraron más RNG.

| Métrica | Auditoría (6 partidos) | Línea base Fase 0 (6 × 10 min + 1 × 3 min con render) |
|---|---|---|
| Tramos observados en partido | 702 | 700 |
| Variantes observadas | 888 | 904 |
| Roles observados | 90 de 111 | 88 de 111 |
| Cabezazos y voleas | 0 | 0 |
| Clip más repetido | `jn_start_0494` / `jn_run_change_2402_mirror` | `jn_start_0494` (2.117 reproducciones; 8,7–13,6 % de todas las de cada partido) |

Roles nunca observados en la línea base (23): `angry`, `ball_sole`, `ball_stop`, `defeat_end`, `dir_back_walk`,
`dir_fwd_diag_walk`, `fall_hit`, `gk_idle`, `gk_sidestep`, `header`, `idle_fidget`, `idle_ready`, `jump`, `kick_cross`,
`kick_flick`, `run`, `sidestep`, `stop`, `throw_prep`, `thumbs_up`, `turn_run`, `volley`, `warmup`.

## 6. Línea base de pruebas y métricas

### 6.1 Comandos, semillas y salidas declarados

| Línea base | Comando | Salida |
|---|---|---|
| Suite headless | `tools/run_tests.sh` sobre el tag | [`fase0/pruebas/suite_headless_base.log`](fase0/pruebas/suite_headless_base.log) |
| Baterías con render | `xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter <f>` para `live_feet live_kicks pack_motion json_mode physical_dribble directional_kicks dribble_reference test_receive` | `fase0/pruebas/render_<f>.log` |
| Métricas de partido | `python3 docs/integration/fase0/medicion/medir_linea_base.py --commit pre-audit-phase-0 --work <dir externo> --out docs/integration/fase0/linea_base --seeds 101,202,303,404,505,606 --minutes 10 --repeat-seed 101 --render-seed 707 --render-minutes 3 --jobs 3` | [`fase0/linea_base/`](fase0/linea_base/): `metricas.json`, `metricas_por_partido.csv`, `resumen_linea_base.json`, `reproducciones_por_clip.csv`, datos crudos por partido |

La herramienta crea un `git worktree` externo, aplica una instrumentación que **solo registra** (descrita en su
cabecera), siembra `AIInput`, `BallHandler`, `PlayerActions`, `Goalkeeper`, `SetPiece`, `MatchPresentation` y
`PackLibrary._vary_rng`, y borra la copia al terminar. Si el código cambia y un parche ya no coincide, se detiene: hay
que actualizarla en la misma fase que cambie el código.

### 6.2 Resultados de pruebas (línea base)

| Prueba | Resultado |
|---|---|
| Suite headless | **310 pruebas, 0 fallidas, 28 omitidas, 2.992 comprobaciones**; sin `SCRIPT ERROR`; sin fugas |
| `live_feet` / `live_kicks` / `pack_motion` / `json_mode` | 7/0 · 6/0 · 2/0 · 10/0 (1 omitida) |
| `physical_dribble` / `directional_kicks` / `dribble_reference` / `test_receive` | 5/0 · 3/0 · 2/0 · 30/0 (1 omitida) |
| Fugas al cerrar (todas las ejecuciones con render) | 0 |
| F9-001 (`test_ai_match`, salida de la cancha) aislada | 8 de 8 pasan ([log](fase0/pruebas/f9_001_test_ai_match_8_ejecuciones.log)) |

### 6.3 Métricas de partido (6 partidos de 10 min; media y rango por partido)

| Métrica | Media | Mín.–máx. | Partido con render (3 min) |
|---|---|---|---|
| Goles / goles «en propia» (último toque del equipo que recibe, incluye rechaces del arquero) | 4,5 / 1,0 | 4–5 / 0–2 | 3 / 1 |
| Pases / tiros | 89,5 / 13,5 | 77–98 / 9–19 | 36 / 3 |
| Tramos distintos reproducidos | 387 | 354–406 | 278 |
| Golpeos iniciados | 104,8 | 91–115 | 37 |
| % golpeos iniciados sin contacto | 5,23 % | 4,30–6,31 | 0,0 |
| Distancia pelota–punto de contacto del clip (golpeos aceptados): mediana | 0,137 m | 0,116–0,158 | 0,148 |
| Ídem p90 | **0,401 m** | 0,326–0,465 | 0,379 |
| Ídem máximo | 0,618 m | 0,577–0,647 | 0,471 |
| % contactos aceptados a más de 0,30 m | 19,1 % | 15,1–24,0 | 27,0 |
| Golpeos aéreos | **0** | 0–0 | 0 |
| % golpeos rasos fallidos | 4,17 % | 2,2–5,5 | 0,0 |
| Golpeos que salen hacia el arco propio (> 8 m/s, en campo propio; heurística) | 7,3 | 5–10 | 0 |
| Recepciones con clip iniciadas / % abortadas | 30,3 / 34,6 % | 24–35 / 25,7–52,9 | 7 / 42,9 |
| % primeros toques con clip de recepción | 18,1 % | 15,0–23,0 | 20,0 |
| % pérdida de posesión 2 s después de una recepción animada | **28,1 %** | 19,2–38,9 | 50,0 |
| % movimientos con pelota cortados | **32,9 %** | 26,3–40,0 | 27,8 |
| % solicitudes rechazadas por el árbitro | 22,8 % | 21,1–24,5 | 30,7 |
| % reproducciones del clip más repetido (`jn_start_0494`) | 10,9 % | 8,7–13,6 | 10,6 |
| `SCRIPT ERROR` | 0 | 0 | 0 |

## 7. Determinismo (entrada para la Fase 9)

- Con todas las semillas fijadas, una repetición de 30 s coincidió en todas las métricas de juego; la de 10 min
  (`s101_repeticion`) **no**: 40 métricas distintas (p. ej. marcador 1–3 frente a 2–5).
- La primera divergencia aparece a los **4–6 s de juego** como diferencias de 1–2 cm en posiciones (mismo clip, mismo
  instante) que después se amplifican. No la causan las semillas.
- Fuentes candidatas: (a) la simulación física multihilo; (b) `Ball.last_touch_msec` (`Time.get_ticks_msec()`), que
  `BallHandler._finish_clip_kick` compara para detectar interferencias y depende de la velocidad de la máquina;
  (c) los RNG que se usan antes de poder sembrarlos desde fuera (presentación al inicio y el primer uso de cada
  `SetPiece`).
- **Consecuencia:** las comparaciones entre fases deben ser **estadísticas** (medias sobre las mismas 6 semillas y la
  misma duración), no partido a partido. Con 6 partidos, el ruido entre partidos es grande (p. ej. recepciones
  abortadas 25,7–52,9 %); para detectar cambios del 5 % relativo hacen falta más partidos o un juego determinista.

## 8. Inventario de recursos para los 47 clips contextuales (Fase 8)

Recursos que existen en el proyecto: pelota, cancha y arcos (con travesaño), el humanoide propio (sirve como segundo
participante, árbitro o cuarto árbitro), un árbitro de partido (`Referee` con `FootballerVisual`), el actor de
presentación y el audio de público. **No existen**: banco, túnel, sala de prensa, camilla, botellas, tablero de cambios ni
gradas. La clasificación sale del **nombre** y del motivo de bloqueo de cada clip; antes de conectarlos hay que
confirmarla con sus hojas de poses (`continuacion/visual/`).

| Grupo | Clips | Recurso necesario | Estado |
|---|---|---|---|
| Objeto pelota (recoger, colocar, atrapar, lanzar para voleas) | `0176`, `0310`, `0314`, `0316` (sit), `0318`, `2284`, `2286` | pelota (existe) | sincronización por implementar |
| Travesaño | `0350` (JUMP_TOUCH_BAR) | arco (existe) | sincronización por implementar |
| Botellas de agua | `0302`, `0304` | botella | **pendiente por assets** |
| Tablero del cuarto árbitro | `0442`, `0444` | tablero de cambios (+ humanoide) | **pendiente por assets** |
| Interacción de dos jugadores (P0/P1) | `0394/0396`, `0398/0400`, `0402/0404`, `0410/0412`, `0422/0424`, `0436/0438` | segundo humanoide (existe) | alineación por implementar |
| Lesión / dolor / cojera | `0434` (walk), `0960`, `0962` (sit), `0968`, `1378`, `1380`, `1382`, `1384` | ninguno obligatorio (camilla opcional: no existe) | estado de lesión por implementar |
| Deslizamiento (`SLIDE`, `SLIDE_END`) | `0446`, `0448` | ninguno | postura de entrada/salida por definir |
| Escenas sin nombre descriptivo | `0168`, `0170`, `1046`, `1048`, `1078`, `1080`, `1106`, `1110`, `1114`, `1116`, `1118`, `1264`, `1266` | desconocido | función por confirmar con las hojas de poses |

Total: 7 + 1 + 2 + 2 + 12 + 8 + 2 + 13 = 47. Solo 4 clips quedan **pendientes por assets**; el resto no está bloqueado
por recursos.

## 9. Pruebas de bloqueo (gate) y de seguimiento (monitoring)

Lista adoptada a partir de la sección 15.0 de la guía, ajustada a lo que existe hoy. Una prueba de bloqueo no se relaja
para que pase; si la línea base estaba mal se corrige en un commit separado y justificado.

**Gate** (bloquean el cierre de cada etapa):

| # | Prueba | Cómo se ejecuta | Base Fase 0 |
|---|---|---|---|
| G1 | Hashes de los 2.022 JSON originales | `sha256sum -c docs/integration/fase0/hashes_json_originales.sha256` en el directorio extraído (local; el ZIP no está versionado) | 2.023/2.023 OK |
| G2 | Hashes de los recursos derivados | `sha256sum -c docs/integration/fase0/hashes_recursos_animacion.sha256` (salvo cambios declarados en la etapa) | 47/47 OK |
| G3 | Importación de las 3.223 variantes (poses finitas al inicio, mitad y final) | `tools/integration/audit_bank.tscn` | 2.022 / 3.223 / 0 fallos |
| G4 | Suite headless completa (incluye `test_action_arbiter` 9/9, `test_receive` 30, `test_pack_locomotion`) | `tools/run_tests.sh` sin instrumentación | 310 / 0 fallidas |
| G5 | Baterías con render: `live_kicks` (50/50 con contacto), `live_feet` y las otras 6 | `xvfb-run …` (sección 6.1) | 8 / 0 fallidas |
| G6 | 0 fugas al cerrar | salida de G4 y G5 | 0 |
| G7 | Ningún alias pasa de «roto documentado» a «roto no documentado»; 0 referencias a nombres inexistentes en índices | prueba de la Fase 7 (mientras tanto: lista de 5 alias sin clip de la auditoría) | 5 documentados |
| G8 | Pie animado = pie informado en golpeos originales y espejos | prueba a crear (sección 15.2) | — |
| G9 | Exportación ARM64 y verificación de la APK | workflow de Android | run 63 verde |

**Monitoring** (informativas): partidos IA largos con varias semillas (`medir_linea_base.py`), distribución de uso por
rol y clip, variantes por partido, repeticiones por ventana visible, abortos por familia, tiempo de carga y memoria.
`test_ai_match` con semilla fija pasa a gate cuando la Fase 9 garantice el determinismo; hasta entonces sus fallos
(F9-001) se investigan pero se tratan como intermitencia conocida. Los otros 12 archivos de prueba con `MatchScene`
siguen en G4.

## 10. Umbrales de aborto propuestos (con los valores de la línea base)

Se comparan **medias de los 6 partidos de 10 min con las semillas 101–606**.

| Fase | Métrica | Base | Abortar si |
|---|---|---|---|
| 3 (contacto) | p90 distancia pelota–contacto | 0,401 m | > 0,441 m (+10 %) |
| 3 | % golpeos iniciados sin contacto | 5,23 % | > 10,23 % (+5 pp) |
| 3 | % movimientos con pelota cortados | 32,9 % | > 37,9 % (+5 pp) |
| 3 | % recepciones con clip abortadas | 34,6 % | > 39,6 % (+5 pp) |
| 3 | goles por partido | 4,5 (4–5) | caída significativa (por debajo del mínimo de la base en la media de 6 partidos) |
| 4 (aéreo) | goles en propia por partido | 1,0 | > 1,5 |
| 4 | % golpeos aéreos fallidos | sin datos (0 aéreos) | > % rasos fallidos de la misma medición (base 4,17 %) |
| 5 (recepciones) | % pérdida tras recepción animada | 28,1 % | > 29,5 % (+5 % relativo); con el ruido actual, confirmar con 12 partidos |
| todas | pruebas de bloqueo | verdes | cualquier fallo |

Advertencia: el ruido entre partidos es del mismo orden que varios de estos umbrales (sección 7). Antes de declarar un
aborto por una métrica de seguimiento, repetir con más semillas; mientras el juego no sea determinista no conviene
apretar más los umbrales.

## 11. Comprobación de integridad al cerrar la fase

- `git status`: solo archivos nuevos en `docs/` (este documento, `fase0/`, `tickets/`).
- `sha256sum -c docs/integration/fase0/hashes_recursos_animacion.sha256`: todo `OK` (resultado en el commit de cierre).
- `respaldo-f3` sin cambios (`3d47a07`).
- Ticket de la Fase 9: [`tickets/F9-001_jugador_fuera_de_cancha.md`](tickets/F9-001_jugador_fuera_de_cancha.md).

## 12. Siguiente paso

Con la guía completa y el banco original disponibles, la siguiente etapa es la Fase 1 (trazabilidad de candidatos y
overlay de depuración). El seguimiento por etapas está en [`SEGUIMIENTO_ANIMACIONES.md`](SEGUIMIENTO_ANIMACIONES.md).
