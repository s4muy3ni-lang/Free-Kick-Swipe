# Auditoría y plan de mejora de jugabilidad — Fútbol 5, modo 4 (Json)

Fecha: 2026-10-30 · Rama `ccr-7a7dba29-jfbum5` · último commit `a86f623`

**Estado de la copia de trabajo:** hay cambios **sin commit**, hechos antes de esta petición para el mensaje anterior: los
jugadores que se deslizaban «como estatuas» y el alcance del golpeo. Están descritos en §A.0. No se commitea nada hasta que
lo autorices.

Convenciones de evidencia:

- **[C] Confirmada**: medida en archivos, en el código o con un script, con la cifra.
- **[I] Inferencia razonable**: deducida de nombres o de patrones, sin prueba directa.
- **[H] Hipótesis pendiente de prueba**.

Lo **visual** se marca aparte: en esta auditoría **no** se hizo revisión visual nueva. Las cifras salen de pruebas de código,
algunas con el esqueleto animado (Xvfb), que miden posiciones de huesos, no lo que se ve en pantalla.

---

## A. Diagnóstico del sistema actual

### A.0 Cambios pendientes sin commit (de la petición anterior)

| Cambio | Archivos | Medido |
|---|---|---|
| La mezcla direccional del modo 4 no tenía clips: buscaba los del pack de Mixamo. Al presionar o marcar mirando al rival (`Locomotion.jockeying` → `FootballerVisual.directional`), el cuerpo se deslizaba con la pose fija. | `JsonCatalog.dir_points/dir_ref_speed`, `FootballerVisual._setup_animation_tree/drive_motion` | [C] Imágenes con la punta del pie quieta y el cuerpo a > 2,5 m/s, en 60 s de partido de IA con render: **808 → 81** (presionando: 635 → 7). |
| Gestos «en el sitio» con el cuerpo corriendo | `Footballer._json_clip_slides`, `PlayerActions.GESTURE_MAX_SPEED` | [C] Incluido en la cifra anterior. |
| Alcance del golpeo 0,55 → 0,65 m, con IK del pie hasta 0,55 m | `PlayerTuning.json_kick_reach`, `BallHandler.JSON_KICK_IK_MAX` | [C] 4 de 4 partidos de IA sin golpeos en falso con clip (antes, 2–4 por partido, a 0,56–0,73 m). |

**Pendiente antes del commit:** la suite completa dio **216 pruebas / 1 fallo**. Falló
`test_ai_match::test_ai_teams_play_a_real_match_without_getting_stuck` (modo 1): «nadie se sale de la cancha más de 1 m, 2
muestras fuera». No está diagnosticado. Hay que averiguar si es azar o efecto de `AI_TACKLE_COMMIT` (que afecta a todos los
modos) antes de commitear (ver §H).

### A.1 Movimiento y respuesta al joystick — `scripts/player/locomotion.gd` (`Locomotion.step`)

- [C] Aceleración 6,2 m/s², deceleración 9,5, frenada 14 (`PlayerTuning`). El giro del cuerpo es **programático**: 620°/s
  parado y 165°/s en sprint (interpolación cuadrática). Por encima de 55° de diferencia, la velocidad objetivo cae hacia la de
  paso (`turn_penalty`).
- [C] Con un giro brusco a máxima velocidad, el cuerpo rota a ~165°/s mientras frena: un 180° tarda ~1 s. Durante ese tiempo
  la marcha sigue en el BlendSpace por velocidad y no hay clip de apoyo ni de pivote. `Footballer._json_turn_move` solo dispara
  clips de giro sin pelota (≥ 100°, lejos de la pelota, `turn_run` entre 2,2 y 5,6 m/s, solo para la persona). En sprint no
  hay ningún clip.
- [I] Sensación resultante: el cambio de rumbo es inmediato en el mando (bien), pero a alta velocidad el cuerpo «patina» en
  curva, sin la frenada ni el apoyo que ven los ojos.

### A.2 Selección de animaciones de marcha — `FootballerVisual._setup_animation_tree`, `JsonCatalog.GAIT/CARRY`

- [C] Marcha: BlendSpace1D con 5 escalones (reposo, paso, dos trotes, sprint) y una línea de tiempo común de un ciclo (fases
  sincronizadas). Con pelota, 6 escalones (`CARRY`). Funciona: cadera a 0,79–0,85 m en todo el rango (`test_model_builds_and_animates`).
- [C] Mezcla direccional: vacía en el modo 4 hasta el arreglo pendiente (§A.0).
- [C] Orientación: no hay variantes de marcha por inclinación o curva más allá de la inclinación procedural del tronco (`ProceduralPose`).

### A.3 Conducción — `BallHandler.update` (2 782 líneas) y `JsonBallMove` (433)

Orden de prioridad real en `BallHandler.update` [C]:

`golpeo en curso` → `golpeo pendiente` → `_shrug_resting_ball` → `bloqueo/lockout` → `json_move.consider` (giros/regates de
clip) → `drag_back.update` → `ball_turn.update` → `_try_first_touch` → `_clip_touch_update` → `_try_dribble_touch`.

A esos se suman los «steer» de `Footballer` (`carry_steer`, `settle_steer`, `kick_approach_steer`, `ball_turn.body_control`,
`press`), que cambian el rumbo del cuerpo fuera de `BallHandler`.

- [C] Conducción en línea recta, con esqueleto animado (`test_live_dribble_keeps_the_ball_with_foot_touches`): distancia
  pelota-cuerpo mediana 0,41 m al trote, 0,44 m en carrera, 0,61 m en sprint (máximo 0,92 m) y 0,53 m en zigzag. Toques con el
  pie: 20/20, 24/24, 16/23 y 32/34.
- [C] Giros con clip en partido: primeros toques errados por interferencia de un rival (de ahí `MAX_LEAD` 0,4 s, ya en el commit `a86f623`).
- [C] Hay **tres controladores de giro con pelota** que se solapan en propósito: `JsonBallMove` (clips), `BallTurn` (procedural)
  y `DragBack`. Cada uno tiene sus propios `cancel`, enfriamiento y umbrales de ángulo (`JsonBallMove.TURN_MIN_ANGLE` 50°,
  `DragBack.MIN_ANGLE`, `STEER_TOUCH_DEG` 18°). Además conviven dos IK de pie: `_update_touch_ik` (corrección) y
  `_json_touch_ik_*` (objetivo absoluto).

### A.4 Recepción y primer toque — `BallHandler._try_first_touch`, `Footballer` (evento `FIRST_TOUCH`)

- [C] El control es **físico**: la pelota a menos de `possession_radius`, a ≤ 0,7 m de altura, con impulso de control.
  **Después** del toque, `Footballer` reproduce un gesto (`play_situation(&"receive")`) solo si el jugador va a ≤ 2 m/s
  (`RECEIVE_MAX_SPEED`), con **dos clips** posibles (alias `Receive` → `jn_receive_chest_0582`, `receive_soccerball` → `jn_receive_foot_0564`).
- [C] No se usan en el juego: `receive` (57 clips), `receive_turn` (29), `control_stand` (24), `ball_start` (7),
  `receive_foot` (3) ni `jostle_ball` (4). Son **124 clips de recepción y control**.
- [I] Consecuencias: la animación va detrás del contacto (no hay preparación). Corriendo no hay gesto de control. No hay
  control orientado (recibir y girar 45/90/135/180°) aunque los clips existen. Con balones a media altura (muslo, pecho) no se
  elige la parte del cuerpo: por encima de 0,7 m solo existe el planificador aéreo de cabezazo y volea.

### A.5 Pases y remates — `PassAssist`, `BallHandler.plan_clip_kick`, `plan_turn_kick`, `_finish_clip_kick`

- [C] Elección del clip por **geometría del contacto**: los 24 candidatos más cercanos (`JSON_KICK_EVAL`), con posición de
  la pelota prevista, ajuste de zancada, coste por velocidad de entrada (`v_in`) y solo golpeos «limpios». Golpeo girando a
  ≥ 50° (`TURN_KICK_MIN`); a ≥ 100° sin clip válido, primero giro con pelota (`turn_for_kick`).
- [C] Tras el golpeo, el cuerpo **recupera la velocidad que traía** (`_kick_v0`), sea cual sea el final del clip. Los nombres
  originales distinguen `..._TO_STAND` de `..._TO_JOG` (§C): hoy se puede elegir un clip que termina parado mientras el cuerpo
  sigue trotando. [I] Esa es una fuente de transición incorrecta.
- [C] La intensidad sale del rol (`kick_pass_soft`, `kick_pass`, `kick_shot`, `kick_shot_hard`), no del nombre (SOFT / MED /
  SHOT / HARD), y la carga del botón no elige el clip por intensidad.
- [C] Pase forzado bajo presión: solo sube el error (`PassAssist.pressure`); no hay un golpeo «de emergencia» (punterazo,
  pase de primera rápido, exterior).
- [C] Remate desequilibrado: el error crece con `KickModel.balance_state`, pero no hay clip propio (tropezar al patear).

### A.6 Contacto pie-balón

- [C] El golpeo cuenta si la pelota está a ≤ `kick_reach()` del punto de contacto medido del clip (modo 4: 0,65 m, pendiente
  de commit). El pie va a la pelota con IK en los últimos 0,12 s (`_json_kick_ik`). En las pruebas con render, la punta del pie
  queda a 1–7 cm de la pelota en el impulso (`json_mode`, `LIVE_KICKS_MODE=4 live_kicks`).
- [C] El guiado del cuerpo hacia la pelota se detiene 0,10 s antes del contacto (`KICK_PLANT_TIME`, pie de apoyo plantado).
  Los fallos restantes en jugadas disputadas coinciden con el cuerpo desplazado 0,4–1,1 m durante el balanceo (empujones
  entre cápsulas).
- [C] Pelota fuera de alcance: la orden espera en el buffer y caduca (`PENDING_KICK_MAX`) o se va a por la pelota
  (`kick_approach_steer`). Bien resuelto en la lógica, pero sin animación de «estirarse y no llegar».

### A.7 Tropiezos, caídas y levantadas — `PlayerActions._json_fall`, `_json_getup`

- [C] Caída: elegida **al azar** entre `fall`, `fall_hit` y `trip`, filtrando solo por recorrido de la raíz y por espacio
  libre. No mira la dirección del impacto ni el estado de entrada (parado, trote, sprint).
- [C] Levantada: según la postura final (`lie` = frente / espalda / lado). 20, 14 y 5 clips; bien planteado.
- [C] Tropiezo: `stumble` (13) sin dirección. `stumble_light` (1) y `avoid` (12) no se usan.

### A.8 Interrupciones, prioridades y transiciones

- [C] `FootballerVisual` tiene **una sola ranura** de acción (`PackShot`, un OneShot). `play_pack_clip` **siempre** corta la
  acción en curso; no hay prioridades. Cada llamador se protege con `is_action_playing()` por su cuenta: gestos de espera,
  barrera, recepción, entradas, forcejeo, fatiga, arranque de sprint, bloqueo, festejos…
- [C] Los clips con raíz que mueven al cuerpo pasan por `PlayerActions` (`start_move`, `ActionMotion`), y los golpeos por
  `BallHandler`. Son tres dueños del cuerpo, coordinados con comprobaciones cruzadas (`actions.active()`,
  `is_kick_in_progress()`, `json_move.active`).
- [C] Consecuencia observada: las «estatuas» (§A.0) y los gestos que tapaban la carrera. Están corregidos con reglas de corte,
  pero el diseño sigue permitiendo que aparezcan casos nuevos.

### A.9 Biblioteca y clasificación — `tools/json_anim/make_selection.py`, `selection.json`, `JsonCatalog`, `JsonRetarget`

- [C] **Nuevo, de esta investigación:** el número de archivo de cada clip JSON (`jn_<rol>_<NNNN>`) es el índice SAT y la línea
  de `anims.rcd.txt`. Se puede **recuperar el nombre original** de las 2 022 animaciones. Hoy la clasificación usa listas
  curadas y reglas geométricas, sin esos nombres.
- [C] Errores de clasificación que se ven al cruzar con los nombres:
  - `jn_ball_turn_0208` es `CONTROL_ET0604_EX2029_CONTROL_LOW` (un control bajo, no un giro).
  - `jn_jostle_0192` es `LOCO_ET0520_EX2020_SPRINT_SJOSTLER` (forcejeo **en sprint**, no en el sitio).
  - `jn_tackle_stand_0818` es `TACKLE_EXE519_JOG_FWD_TO_TACKLE_TO_JOG_FWD` (entrada **en carrera**).
  - `jn_kick_turn_0162` es `KICK_ET0339_NONAME_KICKFLICK`.
  - `ball_dribble` incluye `CONTROL_LOW` y `DRIBBLE_STRETCH`.
- [C] Faltan 11 animaciones de las 2 033 del juego, todas de árbitro o técnico (sin efecto en la jugabilidad).
- [C] `JsonRetarget` trabaja solo fuera de línea (al construir la biblioteca y en `retarget_check`). Error de extremidades
  0,00 cm. No es un problema.
- [C] Guardamos los espejos como clips aparte (3 223 clips con espejos, ~39 MB).

### A.10 Código compartido con otros modos

- [C] `BallHandler`, `PassAssist`, `Footballer`, `Locomotion` y `PlayerActions` son comunes a los modos 1–4. El modo 4 se
  separa con `PackLibrary.json_mode()` o `visual.json_mode`, pero no siempre. Ejemplo: `AI_TACKLE_COMMIT` y la asistencia de
  pase afectan a todos los modos. El modo Mocap es otro modo y no se toca en este plan.

---

## B. Problemas reales y su gravedad

| # | Problema | Dónde | Gravedad | Evidencia |
|---|---|---|---|---|
| 1 | Mezcla direccional vacía: el jugador se desliza con pose fija al presionar o marcar | `FootballerVisual`, `JsonCatalog` | **Crítica** (arreglo pendiente de commit) | [C] 808 → 81 imágenes |
| 2 | Una sola ranura de acción sin prioridades; dueños del cuerpo repartidos | `FootballerVisual.play_pack_clip`, `PlayerActions`, `BallHandler`, `Footballer` | **Alta** | [C] código; las estatuas fueron un síntoma |
| 3 | Recepción sin clips previos al contacto: 124 clips de control sin usar; nada corriendo; sin control orientado | `_try_first_touch`, `Footballer.FIRST_TOUCH` | **Alta** | [C] código y conteo |
| 4 | Giro brusco a alta velocidad sin clip de frenada ni pivote (rotación programática ~165°/s) | `Locomotion.step`, `Footballer._json_turn_move` | **Alta** | [C] parámetros; [I] sensación |
| 5 | Final del golpeo ignorado (`TO_STAND` / `TO_JOG`): el cuerpo recupera `_kick_v0` | `_finish_clip_kick` | **Media-alta** | [C] código; [I] transición visible |
| 6 | Clasificación por geometría con nombres disponibles: roles con clips equivocados | `make_selection.py` | **Media-alta** | [C] ejemplos de A.9 |
| 7 | Tres controladores de giro con pelota y dos IK de pie con umbrales propios | `JsonBallMove`, `BallTurn`, `DragBack`, `BallHandler` | **Media** | [C] código |
| 8 | Caídas al azar, sin dirección de impacto ni estado de entrada | `_json_fall` | **Media** | [C] código |
| 9 | Golpeo desequilibrado o forzado sin clip propio (solo error numérico) | `PassAssist`, `ShotAssist` | **Media** | [C] código |
| 10 | Balón a media altura (0,7–1,5 m): sin control con muslo o pecho; solo cabezazo o volea | `_try_first_touch` (y ≤ 0,7), planificador aéreo | **Media** | [C] código |
| 11 | Cambios de modo 4 que alcanzan a otros modos (fallo nuevo en un partido de IA del modo 1) | `Footballer.AI_TACKLE_COMMIT` y otros | **Media** (riesgo) | [C] 1 fallo en la suite |
| 12 | Espejos guardados como clips aparte (memoria en Android) | `build_json_library.gd` | **Baja-media** | [C] 3 223 clips; [H] coste en el teléfono, sin medir |
| 13 | Rendimiento en Android sin medir (planificador aéreo 15–18 ms en escritorio) | `plan_aerial…`, carga de 39 MB | **Media** (desconocida) | [C] solo escritorio |

---

## C. Comparación con la organización de Ultimate Clash (First Touch)

Material analizado: `UltimateClash_recuperado_completo.zip` (SAT principales, auxiliares, `animdb.adb`,
`indice_animaciones.csv`, `anims.pak_original`), `UltimateClash_01_inventario_nuevo.zip` (`ANIM_IDS.txt`,
`GAMEPLAY_SYMBOLS.txt`), la ampliación de texto, y lo extraído antes del xapk: `game.pak` → `anims.rcd.txt` y las cadenas de
`libMPX.so`. Todo se leyó en copias, sin modificar ni redistribuir nada. `models.pak` no se abrió más allá de su lista de nombres.

### C.1 Mapa de evidencia (formato y datos)

| Observación | Fuente | Interpretación | Confianza | Qué falta |
|---|---|---|---|---|
| El SAT `i` ↔ la línea `i` de `anims.rcd.txt` ↔ el nombre `ANM_*` | SAT, `anims.rcd.txt` | correspondencia nombre ↔ archivo | **[C]** 4 066/4 066; el número de fotogramas coincide en 3 794 | — |
| Los SAT impares son registros de 20 bytes: la misma cabecera que el SAT par anterior, el byte 3 = 1 y sin datos; su nombre es el del par + `_f` | auxiliares | los espejos **no se guardan**: se generan al reproducir | **[C]** 2 033/2 033 pares, con el valor del ángulo negado en todos | — |
| `anims.rcd.txt` = nombre, valor con signo, fotograma inicial y final de la toma | `game.pak` | recorte de una toma larga (p. ej. `…WALKING_DRIBBLE_TO_STAND_D` 484–546) | **[C]** | — |
| fotogramas = final − inicial + 1, salvo 136 clips con uno menos | SAT + rcd | los clips cíclicos omiten el fotograma repetido | **[I]** 46 LOCO, 45 NIS, 36 STAND, 6 SIDESTEP, 3 FALL; muchos se llaman `…LOOP` | revisar los 136 uno a uno |
| Columna de valor: con signo, negada en el espejo; el signo sigue al L/R del nombre; en giros del arquero R45/90/135/180 = −2048/−4096/−6144/−7918 | rcd | ángulo con 16384 = 360° | **[H]** exacto en los giros del arquero; en golpeos y recepciones no coincide con el giro, la raíz ni el ángulo de golpeo que medimos | correlación con más medidas (orientación inicial y final del torso) |
| Cabecera SAT: u16 fotogramas, u8 bloques, u8 bandera de espejo; u32 en el byte 20 | SAT | bloques de datos y tamaño de la sección principal | **[C]** fotogramas; **[H]** bloques (r = 0,99 con el tamaño; ~0,23 por fotograma → claves comprimidas) y tamaño (r = 1,00; ~1,9 KB fijos de cabecera o esqueleto) | decodificar una sección |
| `animdb.adb`: u32 4066 + 4 066 registros de 104 bytes + 442 KB extra | adb | base de metadatos por animación | **[C]** estructura | interpretar la sección extra |
| Registro adb, campo 0 = familia | adb | STAND 0, CONTROL 1, SIDESTEP 2, LOCO 3, TURN 4, STUMBLE 5, THROW 6, TACKLESLIDE 7, TACKLE 8, FALL 9, GETUP 10, KICK 11, KICKSETPIECE 12, NIS 13, GKSAVE 14, GKTHROW 15, GKKICK 16, REFEREE 17 | **[C]** correspondencia exacta | — |
| Registro adb, campo 1 = 4 (base) / 5 (espejo); campo 2 = fotogramas; campo 3 = bloques | adb | — | **[C]** | — |
| TURN: campo 46 = −(giro total en grados) | adb vs. nuestro giro medido | el juego guarda el giro de cada clip | **[C]** razón −1,0 en 122 clips | — |
| LOCO: campo 49 ∝ velocidad natural | adb vs. `natural_speed` | velocidad de cada ciclo | **[C]** r = 0,93; unidades desconocidas (~12 por m/s) | unidades |
| KICK: campo 5 ~ velocidad del pie (r = 0,71); campo 40 ~ −velocidad de entrada (r = −0,71); campos 25–27 con la lateral negada en el espejo | adb | metadatos del golpeo: potencia, carrera de entrada, posición del balón | **[H]** | buscar el fotograma de contacto (no está en esos campos: r ≤ 0,27) |
| Símbolos `BallFrame`, `BallPosition`, `BallNumberOfFrames`, `BallDestination` | binario | datos de balón por animación o golpeo dirigido a un destino | **[I]** nombres; sin enlace a campos | localizar referencias en el binario |
| `g_tAnim`, `g_tAnimData`, `g_tAnimPosition`, `ubuf_fAnimationTime`, `ubuf_vAnimExtents`, `ubuf_vAnimTexScale`, `ubuf_fAnimVariant` | binario | animación muestreada en el shader (texturas de animación en GPU) para móviles | **[I]** | — |
| `FreezeDribbleMaxBallHeight`, `FreezeMaxPlayerDist`, `FreezeOnIntercept`, `LooseBallDribbleTolerance`, `DribbleMinDist` | binario | ventana de «conducción congelada» o imantada y tolerancia de pelota suelta | **[I]** nombres; **[H]** semántica | — |
| `MaxActiveTackles`, `Strength{Pressure,Passive,Slide}TackleRange0/1`, `TackleMinStatusFrames`, `TackleSpeedRate` | binario | límite de entradas simultáneas; alcance de la entrada por fuerza y tipo | **[I]** | — |
| `KickPowerWrongFoot`, `TechniqueKickErrorFW/BW/Height`, `TechniqueRotPowerScaleBW` | binario | pierna mala; error hacia delante o atrás y en altura; potencia al golpear girado | **[I]** | — |
| `AnimSpeedPC`, `AnimStartFramePC`, `Blend`, `BlendMode` | binario | velocidad e inicio de reproducción variables; modos de mezcla | **[I]** | valores y algoritmo: **no disponibles** |

**No demostrado** (y no se afirma): umbrales de disparo, prioridades entre acciones, tiempos de mezcla, fotograma exacto de
contacto y fórmula de selección en tiempo de ejecución.

### C.2 Patrones de organización (de los nombres; [I] salvo indicación)

1. **Taxonomía multidimensional**: estado de entrada (STAND / WALK / JOG / SPRINT) × dirección relativa (FWD, R/L 45/90/135/180)
   × intensidad (SOFT / MED / SHOT / HARD, CHIP) × estado de salida (TO_STAND / TO_JOG / CTRL / DRIB). Ejemplos literales:
   `KICK_EXE302…306_STAND_KICK_{FWD,R_45,R_90,R_135,R_180}_TO_STAND_SOFT`, `KICK_EXE347_JOG_KICK_SOFT_FWD_TO_JOG`.
2. **Transiciones como clips**: `STAND_TO_JOG_TO_STAND_…_START / …_STOP`, `JOG_FORWARDS_TO_JOG_BACKWARDS_SAME_FACE`,
   `JOG_TURN_STOP_05/08/12`. Los giros son arranques y frenadas de la locomoción, no rotaciones aisladas.
3. **Recepción por altura y parte del cuerpo × ángulo de salida × velocidad de llegada × continuidad**:
   `RECEIVE_BALL_{LOW,KNEE_HIGH,WAIST_HIGH,CHEST,HEAD}`, `…_TURN_R_45…180`, `…_FAST_BALL_IN`, `JOG_TO_FWD_CONTROL_…_TO_JOG`.
4. **Caídas por estado y apoyo; levantadas por postura** (FRONT / BACK / R_SIDE).
5. **Espejo en tiempo de ejecución** **[C]**: un solo clip físico por animación.
6. **Metadatos por clip en una base aparte** **[C]** (`animdb.adb`): familia, fotogramas, giro (TURN), velocidad (LOCO) y
   campos propios de cada familia. Es decir, la decisión se apoya en **datos medidos fuera de línea**, no en heurísticas en
   tiempo real. [I]

### C.3 Comparación con nuestro sistema

| Aspecto | Ultimate Clash (evidencia) | Nuestro modo Json | Brecha |
|---|---|---|---|
| Identidad de clips | nombre descriptivo + base de metadatos [C] | `jn_<rol>_<n>` + metadatos medidos (contacto, `v_in/v_out`, rumbo, `lie`…) [C] | no usamos los nombres: **recuperables** |
| Espejos | en tiempo de ejecución [C] | clips duplicados [C] | memoria (×~1,6) |
| Giros con el mismo clip en varios ángulos | familias completas R/L 45–180 [I] | `ball_turn` / `kick_turn` / `turn_*` por giro medido [C] | equivalente en idea; nos falta el estado de entrada y salida |
| Recepción | muchas variantes por altura, ángulo y continuidad [I] | física + 2 gestos después del toque [C] | **la mayor brecha** |
| Transiciones de locomoción | arranque, frenada y giro de trote como clips [I] | BlendSpace + rotación programática [C] | brecha en giros bruscos, arranques y frenadas |
| Selección | [H] por datos medidos | por geometría del contacto (bueno) + rol | añadir etiquetas de entrada, salida e intensidad |
| Animación en el móvil | [I] muestreo en GPU | AnimationTree en CPU, 11 jugadores | medir en Android |

---

## D. Animaciones JSON disponibles que no se aprovechan

Conteo de clips base (sin espejos). «Sin uso» = el rol no aparece en el código de juego; se ve solo en la galería.

| Rol | Clips | Estado | Qué aportarían |
|---|---|---|---|
| `receive` | 57 | solo 2 por alias, después del contacto | control por altura y pie (40 parado, 17 al trote) |
| `receive_turn` | 29 | sin uso | control orientado 45/90/135/180 |
| `control_stand` | 24 | sin uso | control y arranque con pelota |
| `ball_start` | 7 | sin uso | arrancar conduciendo desde parado (`STAND_TO_JOGGING_DRIBBLE_CTRL`, 45° R) |
| `ball_dribble` | 32 | sin uso (incluye controles mal clasificados) | revisar con los nombres |
| `jostle_ball` | 4 | sin uso | proteger la pelota con el cuerpo |
| `turn_stand` | 28 | sin uso | giro parado 45/90/135 |
| `turn_stop` | 6 | sin uso | `JOG_TURN_STOP`: frenar y girar |
| `start` | 8 | sin uso | `STAND_TO_SPRINT_START`, `JOG_FORWARDS_TO_JOG_BACKWARDS_SAME_FACE` |
| `stop` | 11 | 1 referencia | frenadas, también hacia atrás o en diagonal |
| `run_change` | 1 | sin uso | cambio de rumbo en carrera |
| `avoid` | 12 | sin uso | saltar o esquivar una pelota o una entrada |
| `stumble_light` | 1 | sin uso | tropiezo leve |
| `sidestep` | 4 | sin uso | paso lateral corto |
| `dir_back_walk`, `dir_fwd_diag_walk` | 2 | sin uso | mezcla direccional al paso |
| `kick_cross` (2), `kick_flick` (1) | 3 | sin uso directo | centro y toque de taco o empeine |
| `nis_misc` / `nis_walk` / `nis_sit` | 139 | presentación | — (no es jugabilidad) |
| `crowd`, `manager`, `mascot` | 111 | sin uso (entorno quitado) | — |

Mal clasificados (ver A.9): al menos `ball_turn_0208`, `jostle_0192`, `tackle_stand_0818` y `kick_turn_0162`. La lista completa
sale de cruzar los 2 022 nombres (Fase 1).

---

## Etapa 3 — Diseño de jugabilidad: 10 escenarios

Notación: **Entrada** = condiciones. **Candidatas** = roles o etiquetas (con las etiquetas de nombre de la Fase 1).
**Prioridad** = nivel en el árbitro de acciones de la Fase 2.

**1. Corre hacia delante, recibe un pase lateral y controla sin detenerse.**
- Entrada: pase anunciado (`expect_pass`); receptor a ≥ 2 m/s; pelota llegando desde 45–110° del frente, rasa.
- Candidatas: `receive` / `control_stand` etiquetados `JOG_…_TO_JOG` (p. ej. `JOG_TO_FWD_CONTROL_ON_INSIDE_OF_R_FOOT_TO_JOG`),
  con el pie del lado de la pelota y su espejo.
- Selección: planificada **antes** del contacto, desde la trayectoria predicha (`pass_meet_point`). Se elige el clip cuyo
  punto de contacto medido cae en la trayectoria con el menor ajuste de zancada, como hoy `plan_clip_kick`.
- Movimiento: marcha que entra en el clip sin bajar de velocidad (`v_in` ≈ velocidad), con un ajuste de ≤ 0,3 m.
- Balón: el toque del clip es un impulso hacia la salida (estado `TO_JOG`), por delante del rumbo del joystick.
- Salida: marcha con pelota (`CARRY`) a la misma velocidad.
- Fallos: pase desviado → replanificar hasta ~0,25 s antes; si ningún clip llega, control físico actual sin gesto (nunca un
  gesto en el sitio con el cuerpo corriendo, que es la regla del corte).

**2. Corre a máxima velocidad y gira bruscamente 180°.**
- Entrada: joystick a ≥ 135° del rumbo a ≥ 5 m/s, sin pelota.
- Candidatas: `turn_run` / `turn_stop` (`JOG_TURN_STOP_*`), y si no, frenada (`stop`) más `turn_stand`.
- Selección: dos fases. Frenar con un clip de frenada o pivote, con el cuerpo siguiendo la raíz (`start_move`), y luego girar.
  Prioridad de locomoción especial: la corta cualquier acción de balón o de defensa.
- Movimiento: deceleración real de la raíz del clip, no `brake` programático; rumbo del clip (`heading_driven`).
- Salida: arranque en la nueva dirección (`start`, `STAND_TO_SPRINT_START`) o marcha si el clip termina `TO_JOG`.
- Fallos: si el joystick vuelve al rumbo original durante la frenada, se corta solo en una ventana de apoyo, para no partir la
  pierna en el aire.

**3. Está de espaldas al arco y el usuario pulsa rematar.**
- Entrada: arco a ≥ 135° del frente, pelota al pie.
- Candidatas: `kick_turn` (R/L 135–180), `kick_back` (taco, `JOG_BACK_HEEL__TURN_180`), o giro con pelota y después remate (ya existe).
- Selección: igual que hoy (`plan_turn_kick` → `turn_for_kick`), sumando la etiqueta de salida y la intensidad: un `…_SHOT`
  para tiro, `SOFT` para pase. Con presión cerca, preferir el taco o un remate rápido antes que el giro largo.
- Balón: impulso en el contacto medido; error mayor por golpear girado (equivalente propio a `RotPowerScaleBW`).
- Salida: según la etiqueta (`TO_STAND` → frenar; `TO_JOG` → seguir).
- Fallos: clip de giro largo con un rival a < 1,5 m → elegir el taco o un pase de seguridad.

**4. Recibe bajo presión y ejecuta un pase forzado.**
- Entrada: rival a < 1,2 m al recibir y orden de pase pendiente (primer toque o buffer).
- Candidatas: golpeo de primera con `receive` + `kick_pass_soft` corto; o `kick_flick` / pase con el exterior.
- Selección: priorizar la latencia más corta (≤ 0,2 s) aunque el contacto sea menos limpio. La asistencia apunta al
  compañero; el error crece con la presión (ya está) y con el apoyo.
- Balón: velocidad algo menor y error mayor; el pase sale aunque el cuerpo esté de lado.
- Fallos: si la pelota se va, no forzar un gesto de pase al aire: dejar que el rival la dispute (es lo correcto).

**5. Remata mientras pierde el equilibrio.**
- Entrada: `KickModel.balance_state` bajo (carrera lateral, después de un choque o a máxima velocidad girando).
- Candidatas: golpeo normal + capa de tropiezo después (`stumble_light`, `stumble` `…_TO_JOG`) en lugar de un clip
  inventado; los nombres no muestran «golpeo desequilibrado» como familia [C: no aparece].
- Selección: golpeo primero (prioridad de balón) y tropiezo de salida en la transición.
- Balón: error y altura mayores (ya existen en el modelo de error).
- Fallos: tropiezo encadenado varias veces → enfriamiento.

**6. Intenta rematar con el balón fuera de alcance.**
- Entrada: orden de remate; ningún candidato llega (residuo > alcance) y ningún ajuste de zancada lo resuelve.
- Comportamiento: la orden queda en el buffer mientras el jugador va a la pelota (ya existe). Si caduca, no se reproduce
  ningún golpeo. Opcional: un gesto corto de «estirarse» si la pelota pasa a ≤ 1 m (`avoid` o `tackle_stand` corto), sin
  impulso.
- Fallos: no reproducir nunca el clip de remate sin contacto (es la queja «hace la animación pero no le da al balón»).

**7. Tropieza, cae y se levanta según su postura final.**
- Entrada: entrada recibida, choque fuerte o barrida.
- Candidatas: `fall` / `trip` / `stumble` elegidos por **dirección del impacto** (delante, detrás, lado) y **estado de
  entrada** (STAND / JOG / SPRINT), con las etiquetas de los nombres; espacio libre como hoy.
- Levantada: por `lie` (ya está), y si es posible con giro hacia el juego (`GET_UP_FROM_FRONT_TURN_L_90`).
- Fallos: ningún clip con esa dirección → el de recorrido más parecido, como hoy.

**8. Cambia de dirección mientras conduce.**
- Entrada: rumbo pedido a ≥ 30° del de la pelota, con pelota.
- Candidatas: < 50°: toque de rumbo (`STEER_TOUCH_DEG`, ya existe); 50–135°: `ball_turn` según el estado de entrada (trote o
  parado); > 135°: `DragBack` o `ball_turn` de 180°.
- Selección: **un solo** planificador de giros con pelota (unificar `JsonBallMove`, `BallTurn` y `DragBack` bajo una
  decisión, ver E). El procedural queda como respaldo.
- Fallos: interferencia de un rival antes del primer toque (ya se limita con `MAX_LEAD`).

**9. Recibe un balón elevado y elige la parte del cuerpo.**
- Entrada: altura prevista del balón en el punto de encuentro: ≤ 0,35 m pie; 0,35–0,7 m rodilla o empeine; 0,7–1,1 m
  muslo; 1,1–1,5 m pecho; > 1,5 m cabeza. Son umbrales **nuestros**, a calibrar con el punto de contacto medido de cada clip.
- Candidatas: `receive` etiquetado `LOW` / `KNEE_HIGH` / `WAIST_HIGH_THIGH` / `CHEST` / `HEAD` (y `FAST_BALL_IN` si llega rápido).
- Selección: por la altura del contacto medido del clip frente a la altura prevista, como hoy los cabezazos y voleas.
- Balón: impulso de amortiguación hacia el pie de salida.
- Fallos: si no llega ninguno, el control físico de siempre.

**10. Remate lateral sin girar artificialmente todo el cuerpo.**
- Entrada: destino a 45–100° del frente.
- Candidatas: `KICK_…_R_45` / `R_90` (`kick_turn` con giro pequeño), golpeos con el interior o el exterior y su espejo.
- Selección: preferir el clip cuyo **ángulo de golpeo** (`kick_turn` medido) cubra el ángulo con el **menor giro del cuerpo**
  (premiar el giro bajo). Hoy el cuerpo sigue el rumbo del clip; con un clip de 45° gira 45°, no 90°.
- Fallos: un ángulo que solo cubre un clip de giro grande, con presión → pase de seguridad.

---

## E. Arquitectura recomendada

**Conservar** (funciona y está medido):
- `JsonRig` / `JsonRetarget` (fuera de línea, 0,00 cm de error).
- `PackLibrary` + `JsonCatalog` (librerías, alias, roles).
- El planificador de golpeos por geometría del contacto: `plan_clip_kick`, `plan_turn_kick` y el aéreo.
- `JsonBallMove` (la pelota de toque a toque con impulsos).
- `TouchFootIK`, `ActionMotion` (clips con raíz y rumbo), `PassAssist`.
- La marcha sincronizada (`GAIT` / `CARRY`).

**Modificar:**
1. `make_selection.py` / `build_json_library.gd`: incorporar el **nombre original** (de `anims.rcd.txt`, que ya teníamos
   extraído; solo lectura) y derivar **etiquetas**: `entry` (stand / walk / jog / sprint), `exit` (stand / jog / ctrl / drib),
   `angle` (±45…180), `side` (L/R), `intensity` (soft / med / shot / hard / chip), `body_part` (foot / knee / thigh / chest /
   head), `height`, `ball_speed_in` (fast). Las medidas geométricas actuales siguen mandando cuando contradicen al nombre.
   Corregir los roles mal clasificados.
2. `_finish_clip_kick` y la selección: respetar el estado de salida del clip (velocidad del cuerpo después del golpeo).
3. `PlayerActions._json_fall`: elegir por dirección de impacto y estado de entrada.

**Añadir:**
1. **`ActionArbiter`** (no un Animation Director completo): una sola autoridad por jugador sobre «quién mueve el cuerpo y qué
   acción suena», con prioridades (balón crítico > locomoción especial > defensa > gesto) y reglas de corte (velocidad, giro,
   pérdida de balón). La auditoría lo justifica (§A.8, problema 2): hoy hay tres dueños y una ranura sin prioridad, y los fallos
   reales («estatuas», gestos encima de la carrera) salieron de ahí. Se introduce **envolviendo** las llamadas existentes
   (`play_pack_clip`, `start_move`, golpeos), sin reescribirlas.
2. **`ReceivePlanner`** (modo 4): planifica la recepción antes del contacto con los clips etiquetados, con el mismo patrón que
   `plan_clip_kick` (contacto medido + ajuste de zancada + latencia). El control físico queda como respaldo.
3. **Transiciones de locomoción con clips** (modo 4): frenadas, giros de 135–180° a velocidad, arranques; con raíz (`start_move`).
4. **Decisor único de giro con pelota**: una función que elige entre toque de rumbo, `JsonBallMove`, `DragBack` o `BallTurn`.
   Los cuatro se conservan como ejecutores.

**Aislamiento del modo 4:** todo lo nuevo, solo con `PackLibrary.json_mode()`. Los cambios de balance que afecten a otros modos
se separan en valores del modo 4 (`*Tuning`). Sin tocar Mocap.

---

## F. Plan de implementación por fases (por impacto)

| Fase | Contenido | Impacto | Riesgo | Tamaño |
|---|---|---|---|---|
| **F0** | Cerrar lo pendiente: diagnosticar el fallo del partido del modo 1; dejar `AI_TACKLE_COMMIT` solo para el modo 4 si hace falta; commit del arreglo de «estatuas» y del alcance | Alto (las estatuas son lo más visible) | Bajo | S |
| **F1** | Etiquetas desde los nombres originales; corregir roles mal clasificados; informe de diferencias rol ↔ nombre | Alto (base de todo) | Bajo (fuera de línea) | M |
| **F2** | `ActionArbiter`: prioridades, dueño único, reglas de corte; las llamadas actuales pasan por él | Alto (transiciones, nada «se cuelga») | Medio | M |
| **F3** | `ReceivePlanner`: recepción planificada (parado, trote, orientada, por altura) con los 124 clips | **Muy alto** (escenarios 1, 4, 9) | Medio-alto | L |
| **F4** | Locomoción: giro brusco a velocidad, frenadas y arranques con clips | Alto (escenario 2) | Medio | M |
| **F5** | Golpeos: estado de salida, preferir el menor giro del cuerpo (escenario 10), pase forzado (4), tropiezo de salida (5) | Medio-alto | Medio | M |
| **F6** | Decisor único de giro con pelota (escenario 8) | Medio | Medio (la conducción ya funciona) | M |
| **F7** | Caídas por dirección y entrada (escenario 7) | Medio | Bajo | S |
| **F8** | Android: medir carga, memoria y ms por jugador; espejos en tiempo de ejecución si hace falta | Medio (desconocido) | Medio | M |

Cada fase va en su propio commit, con pruebas y docs (`docs_index sync/check`, CHANGELOG), y con autorización previa.

---

## G. Pruebas necesarias

Las automáticas miden datos. Las visuales son capturas o vídeos que **alguien tiene que mirar**; no cuentan como aprobadas sin
esa revisión.

| Fase | Automáticas (headless o con esqueleto animado) | Visuales |
|---|---|---|
| F0 | `test_json_mode` (mezcla direccional ≥ 6 clips, ya añadida); partido de 60 s con render: imágenes de pies quietos corriendo < 100; suite completa sin fallos; partidos de IA del modo 1 repetidos ×5 | captura de un defensor en jockey (play_view) |
| F1 | cada clip con nombre original; etiquetas coherentes con las medidas (`entry` vs `v_in`, `angle` vs giro medido ±25°, `exit` vs `v_out`); roles corregidos | galería por etiqueta |
| F2 | ninguna acción en el sitio con el cuerpo a > 2 m/s más de 0,15 s; ningún golpeo cortado por un gesto; conteo de cortes por prioridad en un partido | vídeo de presión y entradas |
| F3 | recepciones a 0, 3 y 5 m/s y a 45/90/135/180°: contacto del pie a ≤ 0,1 m en el instante del clip; velocidad del cuerpo antes y después (sin parón); % de recepciones con clip en el partido de IA | capturas en el instante del toque (`ON_TOUCH=1`) |
| F4 | 180° a 6 m/s: tiempo hasta 3 m/s en la nueva dirección; pie de apoyo sin patinar (< 0,7 m/s) | secuencia de imágenes del giro |
| F5 | golpeos laterales: giro del cuerpo ≤ ángulo + 15°; velocidad después del golpeo igual a la de salida del clip ±0,5 m/s; golpeos en falso sin rival ≤ 2 por partido | capturas del contacto |
| F6 | la batería de giros con pelota (36 al azar) sin toques errados; pelota < 1,6 m | — |
| F7 | caída hacia delante → clip de caída hacia delante; levantada con la misma postura (ya existe) | secuencia caída → levantada |
| F8 | ms por imagen con 11 jugadores; memoria de la biblioteca | prueba en un teléfono real (la hace el usuario) |

---

## H. Riesgos de regresión y protección del modo Json

1. **Código compartido entre modos**: cada cambio, detrás de `json_mode()`, y la suite completa más los partidos de IA del modo
   1 en cada fase. Hay un antecedente: el fallo pendiente de F0.
2. **Conducción ya medida y buena en línea recta**: `test_live_dribble…` (mediana, máximo y toques con el pie) actúa como
   barrera. No tocar `CARRY` ni el toque normal en F3–F6.
3. **Pie de apoyo patinando** al añadir clips de recepción o giro: el umbral existente (≤ 0,7 m/s) se aplica a las nuevas familias.
4. **Coste del planificador** en Android (el aéreo ya va por 15–18 ms en escritorio): limitar candidatos por etiqueta antes de
   evaluar, como `JSON_KICK_EVAL`, y medir.
5. **Azar en los partidos de IA**: las comprobaciones deben ser robustas (repetir semillas y contar fallos «limpios», como el
   cambio hecho hoy en `test_ai_match_in_json_mode`).
6. **Material de terceros**: los nombres de `anims.rcd.txt` se usan como **datos de etiquetado** (no se copian código ni
   clips); las SAT, `animdb.adb` y `models.pak` no entran en el repositorio ni en el APK. Recomendación: generar las etiquetas en
   la herramienta de construcción y guardar solo las etiquetas propias (no el texto de los nombres ajenos), si eso te preocupa.
7. **Mocap**: fuera de alcance; ninguna fase toca sus archivos.

---

### Respuesta a la pregunta sobre el «mismo jugador» del xapk

No se extrae ni se usa el modelo de `models.pak`: es un recurso propietario y el APK se publica. La alternativa es mejorar
nuestro humanoide (proporciones, equipación, peinado) con un estilo parecido, como trabajo propio.
