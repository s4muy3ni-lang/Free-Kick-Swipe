# F1 — Auditoría y mapa de cobertura del catálogo JSON (modo 4)

Rama `ccr-7a7dba29-jfbum5` · HEAD `a86f623` · 2026-10-30. **Solo análisis.** Sin commits, push ni cambios en el proyecto.

Estado de Git comprobado al empezar y al terminar: 14 archivos modificados; el `git diff` da sha256 `fcbd3dd5…`, igual al
parche protegido; sin diferencias con `refs/backup/f0-pendiente`; sin archivos sin seguimiento.

Nota: el mapa se midió sobre el estado actual de la copia de trabajo, **con los 14 cambios pendientes**. Lo que depende de
ellos va marcado («solo con cambios pendientes»).

Archivos auxiliares (generados fuera del repositorio en una sesion anterior; no se conservan, el informe resume sus resultados):
- `mapa_cobertura.csv`: una fila por cada uno de los 2.024 clips seleccionados.
- `tablas.txt`: listas completas de clips sin conectar y de dudas.
- `libs.jsonl`: metadatos volcados de las librerías.
- `contacts.json`, `obs_ai.json`, `obs_human.json`, `sheet_jn_kick_pass_*.png`.
- Scripts de análisis.
- `proj/`: copia del proyecto para observar partidos sin tocar el repositorio.

Leyenda de evidencia: **[M]** medido, **[C]** leído en el código, **[O]** observado jugando (headless), **[I]** interpretación.

---

## 1. Resumen ejecutivo

- **Integridad [M]:** el zip, la selección y las librerías coinciden en los 2.022 índices. Los 2.024 ids de la selección
  existen en las librerías: los 2 extra son `0362` y `0364`, que se usan como árbitro y como arquero que ordena.
- **Las «162 duraciones distintas» no son ciclos recortados [M].** El campo `meta.duration` del zip es el instante del
  **último fotograma con datos**, y nuestra librería usa la duración nominal (`frames/fps`). En 1.943 clips la diferencia es
  ≤ 1 fotograma. En **81 clips la animación mantiene la última pose congelada** de 0,1 a 1,47 s; 37 son de juego (§3).
  Solo 12 clips (ciclos de conducción) se recortan a propósito.
- **Cobertura [C+O]** (2.024 clips):
  - **423 conectados y observados** sonando en 10 partidos (30 min de juego).
  - **742 con camino en el código pero no observados**. Incluye los 11 de la marcha, que suenan siempre; el observador no los
    registra porque mira las acciones (§5).
  - **859 convertidos sin conectar**, de ellos ~460 de presentación (público, mascota, técnicos, escenas).
  - **166 con dudas** de clasificación.
- **Recepción y control** [C+O]: de 124 clips (`receive` 57, `receive_turn` 29, `control_stand` 24, `ball_start` 7,
  `jostle_ball` 4, `receive_foot` 3), en el juego se usan **3**, y solo como gesto después del toque.
- **Contacto temprano [M+imagen]:** `jn_kick_pass_2590` empieza ya en el golpeo y es elegible para pases. Con la latencia de
  0,2 s, `clip_timing` lo reproduce a **~0,17×** hasta el impacto: un golpeo en cámara lenta. Hay otros 3 golpeos elegibles
  a 0,67–0,79×.
- **Huecos de transición [C]:** arranque explosivo, giro en sprint y parada por agotamiento **no tienen clip JSON** (el código
  pide alias del pack que no existen en el modo 4 y no hace nada). Hay clips de arranque y frenada en la librería, sin conectar.
- **No observados en 30 min de juego [O]:** ningún cabezazo (95 clips) ni volea (54); de 108 estiradas del arquero, 6.

## 2. Integridad del zip y correspondencia de índices

| Comprobación | Resultado |
|---|---|
| El prefijo del archivo coincide con el campo `index` | 2.022/2.022 [M] |
| Nombre interno = `ANM_` + nombre de archivo | 2.019/2.022: 3 nombres de archivo recortados (`1944`, `1946` y `1948`, `NIS_FT1028_INTRO___WALKING_INTO_A_LINEUP…`); el nombre interno es el correcto [M] |
| Índices del zip = archivos de `selection.json` | 2.022 = 2.022, sin sobrantes ni faltantes [M] |
| Ids de la selección presentes en las librerías | 2.024/2.024; 3.223 animaciones contando 1.199 espejos [M] |
| Archivo usado por dos ids | `0362` → `jn_referee_0362` y `jn_gk_direct_0362`; `0364` → `jn_referee_0364` y `jn_gk_direct_0364` [M] |
| Formato | las mismas claves que lee `JsonClipData.load_file` (`times`, `joints`, `root`, `fps`) [C] |
| `v_in` del zip frente a la librería | iguales (±0,3) en 2.022/2.022 (ya informado en F0; vuelto a calcular aquí) [M] |

## 3. Las 162 diferencias de duración

[M] El `meta.duration` del zip vale `t_end/fps` (último instante con datos) en los 2.024 casos. La librería vale `frames/fps`
en 2.012 casos (`build_json_library.gd:245`, `m["duration"] = n60 / DATA_FPS`). Los 12 restantes son ciclos de conducción
recortados a un solo ciclo (`dribble_walk_0234`, `dribble_jog_1574/2106`, `dribble_run_1288/3184/3186`,
`dribble_fast_0194/0548/2092`, `dribble_sprint_1582/1584/3190`).

La hipótesis de F0 («ciclos recortados») se **descarta** para 150 de las 162: son golpeos, escenas, etc., sin ciclo.

**Consecuencia real [M]:** después del último fotograma con datos, el muestreo se queda en la última pose
(`json_clip_data.gd:59`, `clampf(f, times[0], times[-1])`). Clips de juego con más de 0,1 s de pose congelada:

| Índice | Id | Nombre original | Rol | Pose congelada | Estado |
|---|---|---|---|---|---|
| 1884 | jn_gk_kick_1884 | GKKICK_FT1016_GK_DROP_KICK_MAX_GKKICK | gk_kick | 0,40 s | A2 |
| 3348 | jn_setpiece_pass_3348 | KICKSETPIECE_FT1645_KICKSETPIECE__13_ADAM | setpiece_pass | 0,38 s | A2 |
| 0824 | jn_header_0824 | KICK_EXE538_STAND_BIG_JUMP_HEAD_FWD_SHOT_TO_STAND | header | 0,35 s | A2 |
| 1792 | jn_kick_turn_1792 | KICK_FT1005_JOG_SHOT_FWD_11_JOSH | kick_turn | 0,33 s | **A1** |
| 0972 | jn_gk_getup_0972 | GETUP_EXE755_GOALKEEPER_LYING_FACE_DOWN_WITH_BALL… | gk_getup | 0,33 s | **A1** |
| 0162 | jn_kick_turn_0162 | KICK_ET0339_NONAME_KICKFLICK | kick_turn | 0,32 s | **A1** |
| 0756 | jn_header_0756 | KICK_EXE431_STAND_TO_HEAD_FWD_TO_STAND___MED | header | 0,28 s | A2 |
| 1552 | jn_fall_1552 | FALL_FT0952_JOG_BACKWARDS_TURN_180_TO_SPRINT_3_MAX_FALL | fall | 0,27 s | A2 |
| 0720 | jn_kick_lob_0720 | KICK_EXE387_JOG_L_45_LOW_CHIP_TO_STAND | kick_lob | 0,25 s | **A1** |
| 2716 | jn_gk_getup_2716 | GETUP_FT1488_GK_GETUP_01_MAX_GKFRONTR90 | gk_getup | 0,22 s | **A1** |
| 3080 | jn_kick_pass_soft_3080 | KICK_FT1626_CONTROL_STAND_00_KICK02_ADAM | kick_pass_soft | 0,13 s | **A1** |
| 1622 | jn_kick_back_1622 | KICK_FT0967_STANDING_PASS_90_JOSH_KICK | kick_back | 0,12 s | **A1** |

Hay 25 casos más en `tablas.txt` y `mapa_cobertura.csv`, entre ellos `warmup_0332` (1,47 s, A1), `nis_idle_3688` (0,75 s) y
varios saques y atajadas del arquero.

[I] Se ve como una pausa con la pose fija al final de la acción. Que se note depende de si el juego corta el clip antes:
**no determinado** sin revisión visual. Los golpeos se cortan con `kick_follow_through`.

## 4. Mapa de cobertura por familia original

Estados: A1 = conectado y observado; A2 = con camino en el código, no observado; B = convertido sin conectar.

| Familia | Clips | A1 | A2 | B | Dudas | Cobertura | Observaciones |
|---|---|---|---|---|---|---|---|
| NIS | 603 | 123 | 81 | 399 | 2 | parcial (presentación) | B: escenas que se desplazan (> 1 m) o duran < 0,6 s, público, mascota, técnicos |
| KICK | 494 | 98 | 260 | 136 | 71 | parcial | 129 sin «contacto limpio» excluidos a propósito; 95 cabezazos y 54 voleas no observados; contactos dudosos (§8) |
| CONTROL | 269 | 35 | 60 | 174 | 14 | **insuficiente** | recepción y control sin conectar (§6) |
| GKSAVE | 181 | 20 | 161 | 0 | 6 | parcial | casi todo con camino, pero 6 de 108 estiradas observadas |
| TURN | 123 | 20 | 32 | 71 | 76 | **insuficiente** | `turn_stand` (28), `stop` (11), `start` (8), `turn_stop` (6), `gk_turn` (11) sin conectar; muchas discrepancias nombre/medida porque el clip es un tramo de una toma |
| STAND | 86 | 22 | 48 | 16 | 0 | completa (presentación) | — |
| GETUP | 60 | 33 | 27 | 0 | 1 | completa | elegidos por postura |
| LOCO | 45 | 3 | 7 | 35 | 11 | parcial | marcha: 5 escalones; mezcla direccional (4 + espejos) **solo con cambios pendientes**; `loco_*`, `walk` y `sprint` alternativos sin uso |
| KICKSETPIECE | 36 | 8 | 28 | 0 | 3 | completa | por alias repartidos |
| FALL | 29 | 16 | 13 | 0 | 1 | parcial | se elige al azar por recorrido, sin dirección del impacto |
| STUMBLE | 28 | 13 | 3 | 12 | 3 | parcial | `avoid` (12) sin conectar |
| TACKLESLIDE | 18 | 15 | 3 | 0 | 0 | completa | — |
| TACKLE | 16 | 4 | 0 | 12 | 5 | **insuficiente** | 12 con raíz > 1 m quedan fuera del gesto en el sitio; no hay entrada en carrera |
| THROW | 12 | 4 | 8 | 0 | 0 | completa | — |
| GKKICK | 12 | 5 | 7 | 0 | 1 | completa | `gk_kick_1884` con 0,40 s de pose congelada |
| SIDESTEP | 6 | 0 | 2 | 4 | 1 | insuficiente | — |
| GKTHROW | 6 | 4 | 2 | 0 | 0 | completa | — |

La tabla por rol (112 roles) está al final de `tablas.txt` y en el CSV.

## 5. Clips conectados con disparador real

Clips A1 (observados) por sistema [O, 10 partidos]:

| Sistema | Clips A1 |
|---|---|
| `JsonCatalog.situation_clip` (festejos, lamentos, espera, gesto de entrada, barrera, calentamiento) | 118 |
| `BallHandler.plan_clip_kick` | 56 |
| `PackLibrary.vary_aliases` (barridas, saques, balones parados, tropiezos, saques del arquero) | 54 |
| `BallHandler.plan_turn_kick` | 40 |
| levantadas (`PlayerActions` / `Goalkeeper`) | 33 |
| `JsonBallMove.plan_move` | 33 |
| gestos del `Goalkeeper` | 29 |
| `KeeperPlanner` | 20 |
| `Footballer._json_turn_move` | 20 |
| `PlayerActions._json_fall` | 15 |
| `PlayerActions.press_gesture` (**solo cambios pendientes**) | 11 |
| alias fijos | 24 |

**Siempre en uso** (el observador no los registra): la marcha `jn_idle_0520`, `jn_walk_0460`, `jn_jog_1144`, `jn_jog_2390` y
`jn_sprint_3022`; la marcha con pelota `jn_idle_ball_0524`, `jn_dribble_walk_0234`, `jn_dribble_jog_1574`,
`jn_dribble_run_3186`, `jn_dribble_fast_0548` y `jn_dribble_sprint_1582`; y la mezcla direccional `dir_back_0486`,
`dir_back_diag_0480`, `dir_fwd_diag_0470` y `dir_side_0186`, **solo con cambios pendientes**.

Ejemplos con disparador, condición, entrada y salida (la lista completa está en el CSV, columnas `sistemas`, `observado`,
`entrada` y `salida`):

| Índice | Id | Nombre original | Sistema | Condición | Entrada → salida [nombre / medida] |
|---|---|---|---|---|---|
| 2412 | jn_turn_run_2412 | TURN_FT1424_TURN_JOG_00_ARMANI | `_json_turn_move` | giro ≥ 100° a 2,2–5,6 m/s, lejos de la pelota, **solo persona** | corriendo / 3,1 → 4,5 m/s, 174° |
| 0516 | jn_turn_start_0516 | TURN_EXE126_WALK_TURN_135_R | `_json_turn_move` | giro ≥ 100° parado | caminando / 0,2 → 1,2 m/s, 112° |
| 1424 | jn_jostle_1424 | STAND_FT0850_STAND_JOSTLE_1_ANDYD | `press_gesture` (pendiente) | presión pegado sin entrar, cuerpo ≤ 2,2 m/s | quieto |
| 0806 | jn_getup_0806 | GETUP_EXE505_GET_UP_FROM_BACK_TO_STAND_QUICKLY | alias `Getting_Up_3` + `_json_getup` | después de caer de espaldas | suelo → quieto |
| 0564 | jn_receive_foot_0564 | CONTROL_EXE189_STAND_RECEIVE_BALL | alias `receive_soccerball` | evento `FIRST_TOUCH` a ≤ 2 m/s, **después** del toque | quieto |
| 0582 | jn_receive_chest_0582 | CONTROL_EXE213_STAND_RECEIVE_BALL_CHEST | alias `Receive` | igual que el anterior, balón rápido | quieto |

## 6. Clips convertidos pero sin conectar (solo jugabilidad)

Lista completa con índices en `tablas.txt` («B por rol de juego»).

| Rol | Cantidad | Ejemplos (índice, nombre original) | Sistema que podría usarlo | Qué falta | ¿Útil? |
|---|---|---|---|---|---|
| receive | 57 | 0580 `STAND_RECEIVE_BALL_WAIST_HIGH___R_THIGH`; 0594 `JOG_TO_FWD_CONTROL_ON_THIGH_TO_JOG`; 0596 `…ON_CHEST_TO_JOG`; 1814 `MOVING_CONTROL_AIR_FWD_4_JOSH_CTRL_RFOOT` | planificador de recepción (F3) | planificar antes del contacto, por altura y velocidad | **sí** |
| receive_turn | 29 | 0566–0572 `STAND_RECEIVE_BALL_TURN_R_45/90/135/180` | idem: control orientado | idem + ángulo | **sí** |
| control_stand | 24 | 0540 `STAND_TO_WALKING_DRIBBLE_TO_STAND_D`; 0542 `STAND_TO_JOGGING_DRIBBLE_TO_STAND` | recepción → conducción | idem | sí |
| ball_dribble | 32 | 0531 `DRIBBLE_STRETCH`; 0600/0606 `CONTROL_LOW` (mal clasificados) | conducción o recepción | reclasificar | parcial |
| ball_start | 7 | 3102 `CONTROL_STAND_17_ADAM`; `STAND_TO_45_R_FORWARDS_JOGGING_DRIBBLE_CTRL` | arranque con pelota | disparador «parado con pelota → acelerar» | sí |
| turn_stand | 28 | 0514 `WALK_TURN_90_R`; 0518 `WALK_TURN_180_R`; `STAND_TURN_R_90/135` | `_json_turn_move` (hoy solo `turn_start` / `turn_run`) | añadir el rol | sí |
| stop | 11 | 0462/0464/0466 `TURN_EXE109_STOP`; 0490 `…BACKWARDS_STOP` | frenadas (F4/F7) | disparador de frenada | sí |
| start | 8 | 0468 `STAND_TO_JOG_TO_STAND_FORWARDS_JOGFW_START`; 3038 `TURN_JOG_02_2_DAVID` | arranque (sustituye `Idle_To_Sprint`) | conectar | **sí** |
| turn_stop | 6 | `TURN_FT1755/1756/1759_JOG_TURN_STOP_05/08/12` | frenar y girar | conectar | sí |
| run_change | 1 | 2402 `TURN_FT1420_TURN_JOG_01_ARMANI` | giro en carrera | conectar | sí |
| jostle_ball | 4 | 1294–1300 `CONTROL_FT0706…0712_CONTROL_JOSTLE` | protección de la pelota | no existe ese comportamiento | sí |
| avoid | 12 | `STUMBLE_FT1339_AVOID_BALL_LOW_2`; `EXE536_JOG_TO_FLINCH…` | esquivar una barrida o la pelota | disparador | parcial |
| gk_turn / gk_loco | 11 / 6 | `GKSAVE…TURN`, `SIDESTEP_LOW___EG_KEEPER` | arquero | conectar | parcial |
| sidestep / step_stand | 4 / 4 | `SIDESTEP_ET0502…0512` | marcaje | — | dudosa |
| `kick_*` sin contacto limpio | 129 | 35 de `kick_shot`, 32 de `kick_shot_hard`, 29 de `kick_pass_soft`, 23 de `kick_pass`… | planificador de golpeos | quedan **excluidos a propósito** (`clean=false`: apoyo que patina o contacto anómalo) | revisar caso por caso |
| situaciones con raíz > 1 m | 147 | `dejected` 45, `celebrate_team` 31, `celebrate` 26, `celebrate_scorer` 13, `tackle_stand` 12… | `situation_clip` | el filtro exige reproducirse en el sitio | festejos sí, si se mueve al cuerpo con la raíz |
| loco_* / walk / sprint / run alternativos | 19 | 1474 `WALK_FWD_JOSH`, 2024 `WALK_FWD_1_COLIN`… | marcha | variedad, no imprescindibles | redundantes |
| presentación sin uso | ~460 | `nis_misc` 107, `crowd` 48, `mascot` 38, `nis_walk` 28, `manager` 25 | — | — | no (el entorno se quitó) |

## 7. Clasificaciones dudosas (166; lista completa en `tablas.txt`)

| Tipo | Cantidad | Ejemplos | Cómo resolverlo |
|---|---|---|---|
| El nombre describe la **toma entera** y el clip es un tramo [M]: el nombre dice «parado» y la medida «corriendo», o al revés | 73 | 0486 `STAND_TO_JOG_TO_STAND_BACKWARDS_JOG_180` (`v_in` 2,8); 2202 `STANDING_SHOT_FWD_1` (`v_in` 3,1) | **mandan las medidas**: etiquetar con las de `v_in`/`v_out` |
| El ángulo del nombre no coincide con el giro medido (> 45°) | 34 | 0616 `…GOES_OVERHEAD_TURN_L_180` (giro −24°); 0618 `R_90_2_TOUCH_CONTROL` (−18°); 0134 `JOGINTRO_TURN180_90` | ver si el giro está fuera del tramo; revisión visual |
| Golpeo girando que es acrobático o un taco | ~10 | 0162 `KICKFLICK`; 0984 `KICK_SCORPION` (pie a 0 m/s en el «contacto») | revisión visual; sacarlos del planificador de giro |
| Control o recepción clasificados como giro o conducción | 7 | 0208 `CONTROL_LOW` (`ball_turn`); 0600/0606 `CONTROL_LOW` (`ball_dribble`) | reclasificar a recepción |
| Movimiento clasificado como gesto en el sitio | 7 | 0192 `SPRINT_SJOSTLER` (`jostle`); 0818 `JOG_FWD_TO_TACKLE_TO_JOG_FWD` (`tackle_stand`) | rol aparte para el movimiento |
| Contacto que no coincide con ningún evento del JSON original | 80 (12 elegibles) | 1886 `FLICKS_SKILL_PASSES_SHOTS_2` (t 0,15; evento 0,98); 1634 `JOG_PASS_45_2_JOSH` | los eventos del JSON parecen **pisadas**, no contactos [I]: en las carreras de balón parado alternan R/L 5 veces. Revisión visual del instante |

## 8. Auditoría de tiempos de contacto (golpeos con contacto < 0,1 s o < 10 %)

[M] Datos de la meta `contact` de la librería. «Eventos JSON» = campo `touches` del archivo original, en segundos.

| Índice | Id | Nombre original | Duración | Contacto | % | Evidencia | Clasificación propuesta | Confianza |
|---|---|---|---|---|---|---|---|---|
| 2590 | jn_kick_pass_2590 | KICK_FT1463_KICK_SPECIAL_03_MAX | 1,03 | 0,033 | 3 % | punta a 7,2 m/s, 0,50 m delante, 0,20 m alto; en la imagen, a 0,033 s la pierna ya golpea y a ~0,77 s apoya (evento JSON 0,77 L); **elegible** (limpio) | **clip que empieza en el golpeo, sin preparación** | alta (imagen + datos) |
| 0670 | jn_kick_pass_soft_0670 | KICK_EXE348_JOG_KICK_SOFT_R_45_TO_JOG | 0,68 | 0,025 | 4 % | punta a 8,4 m/s; eventos 0,33/0,45/0,68; no limpio (excluido) | contacto mal elegido (pie lanzado al inicio) o tramo recortado | media |
| 0984 | jn_kick_back_0984 | KICK_FT0112_KICK_SCORPION | 0,90 | 0,033 | 4 % | **punta a 0 m/s**; sin eventos; no limpio, pero `plan_turn_kick` **no exige limpio** [C] | contacto inválido; acrobático | alta |
| 3316 | jn_kick_turn_3316 | KICK_FT1643_KICK_SPECIAL_07_DAVID | 1,38 | 0,042 | 3 % | 5,9 m/s; eventos 0,38/1,07; no limpio | contacto probablemente mal elegido | media |
| 3322 | jn_kick_back_3322 | KICK_FT1644_KICK_SPECIAL_10_ADAM | 1,15 | 0,050 | 4 % | 0 m/s; eventos 0,13/0,87 | contacto inválido | media-alta |
| 2592 | jn_kick_pass_soft_2592 | KICK_FT1463_KICK_SPECIAL_04_MAX | 1,00 | 0,050 | 5 % | 3,6 m/s; sin eventos; no limpio | como 2590 (misma toma) | media |
| 1212 | jn_kick_pass_1212 | KICK_FT0604_FT_KICK_8_ALEX | 2,68 | 0,242 | 9 % | coincide con el evento 0,23; elegible | **válido**; clip largo con 2,4 s detrás del golpeo | alta |

**Efecto en el juego [C]:** `BallHandler.clip_timing` (`ball_handler.gd:573`) reproduce hasta el contacto a la velocidad
contacto/latencia cuando el contacto es menor que la latencia (0,2 s en pases; 0,32–0,38 s en tiros). Golpeos elegibles
afectados:

| Clip | Velocidad hasta el contacto |
|---|---|
| 2590 | ~0,17× |
| 0992 `KICK_FT0124_KICK` | ~0,67× |
| 1886 `FLICKS_SKILL_PASSES_SHOTS_2` (tiro) | ~0,47× |
| 2180 `FREESTYLE_PASSING_STANDING_1_…` | ~0,79× |

En los 447 clips base con contacto, 331 de 411 con eventos coinciden (±0,1 s) con algún evento del JSON original. Por lo
dicho en §7, eso es una pista débil.

## 9. Huecos de transiciones

Casos: 1 = no existe clip; 2 = existe pero no está conectado; 3 = existe pero no es compatible; 4 = se resuelve de forma
procedural; 5 = sin evidencia suficiente.

| Transición | Hoy en el modo 4 [C] | Clips en la librería [M] | Caso |
|---|---|---|---|
| Arranque explosivo | `Footballer` pide `Idle_To_Sprint`: **sin alias JSON**, no hace nada | `start` 0468 (0,6 → 4,0 m/s), 3038/3042 (0,5–0,9 → 3,5 m/s); `STAND_TO_SPRINT_START` en la toma `EXE116` | **2** |
| Giro mientras se corre | `turn_run` solo para la persona y entre 2,2 y 5,6 m/s; `Sprint_Turn` sin alias | `turn_run` (20) hasta `v_in` ~3,1 m/s; `run_change` 2402; nada a > 5,6 m/s | **2** (trote), **1** (sprint) |
| Parada por agotamiento | `Running_Tired` sin alias | ningún nombre con TIRED / EXHAUST / BREATH | **1** |
| Quieto ↔ caminar ↔ correr | BlendSpace1D sincronizado | `start` / `stop` sin conectar | **4** (funciona); 2 para mejorarla |
| Correr → frenar | deceleración programática | `stop` (11), `turn_stop` (6) | **2** |
| Recepción → conducción | física + gesto después | `control_stand` 0540/0542, `receive` `…_TO_JOG`, `ball_start` | **2** |
| Conducción → giro | `JsonBallMove` + `BallTurn` + `DragBack` | `ball_turn` (51), `ball_turn_stop` (20) | conectada; la prueba de drag-back mide 1,07–1,23 s para encarar (objetivo 0,8) |
| Conducción → protección | no existe | `jostle_ball` (4) | **2** |
| Preparación → golpeo | el clip incluye la carrera previa | 2590 sin preparación; 4 en cámara lenta | **3** en esos casos |
| Caída → recuperación | `_json_fall` + `_json_getup` por postura | 20 levantadas de frente, 14 de espalda, 5 de lado | conectada; la caída no mira la dirección del impacto (**3** parcial) |
| Recuperación → locomoción | el final de la levantada da paso a la marcha | 2 levantadas del arquero con 0,22–0,33 s de pose congelada | **4**; revisar la pose congelada |
| Bloqueo de tiro (salto) | `Defender_2` sin alias, no hace nada | `jump` 0336 | **2** |
| Barrida larga y dolor | `Defender` y `Writhing_In_Pain` sin alias | — | **5** |

## 10. Galería de práctica

`dir_back` existe (1 clip, `jn_dir_back_0486`), está conectado solo con los cambios pendientes y **no tiene etiqueta** en
`PracticeScene.ROLE_NAMES` [C].

**30 roles JSON sin etiqueta:** defeat_end, dir_back, dir_back_diag, dir_back_walk, dir_fwd_diag, dir_fwd_diag_walk,
dir_side, fall_hit, gk_direct, gk_idle, gk_idle_ball, gk_idle_var, gk_miss, gk_place, gk_sidestep, idle_ball_var, jostle_ball,
jump, lie, loco_jog, loco_side, loco_sprint, loco_walk, receive_chest, receive_foot, shove, stumble_light, throw_prep,
thumbs_up, trip. La galería muestra entonces el nombre interno.

**24 etiquetas de roles que no existen en el modo 4:** marcha, marcha_con_balon, direccional, gemelo_raiz, pase_tiro, volea,
cabezazo, recepcion, habilidad, entrada, contacto_caida, suelo, cansancio, salto, festejo, felicitar, lamento, calentamiento,
arbitro, malabares, practica, arquero, toque, mocap. Son de los modos 1 y 2.

## 11. Clasificación de los fallos de la suite en modo 4 (F0: 35 fallos, 22 omitidas, 25 `SCRIPT ERROR`)

| Clase | Pruebas |
|---|---|
| **1. Verifican sistemas de los modos descartados** (≈ 25) | `test_pack_retarget` ×6, `test_pack_locomotion` ×4, `test_player_model` ×3, `test_pack_reactions` ×4, `test_animation_inventory` ×2 («existe Dribble_2»…), `test_pes_mechanics` ×2 (clips del pack con disparador; árbitro con gemelos del pack), `test_pack_kick` ×4 (exigen golpeos en el sitio, idea del pack; en el modo 4, 82 de 122 golpeos elegibles mueven la raíz > 1 m **a propósito**). Casi todos los `SCRIPT ERROR` vienen de aquí. |
| **2. Fallos reales del modo 4** | `test_shot_keeper` y `test_goalkeeper::test_save_rate…` (el arquero ataja casi todo); `test_animation_contact_audit` (detecta el contacto a 0,03 s de `jn_kick_pass_2590`, ver §8); `test_keeper_and_gait_clips` (sin arranque explosivo, giro en carrera ni parada por agotamiento, ver §9); `test_practice` (30 etiquetas faltantes, ver §10) |
| **3. Infraestructura o diseño de la prueba** | `test_json_mode::test_pack_names_resolve…`: comprueba «fuera del modo 4», imposible con `TEST_GAMEPLAY_MODE=4` forzado. El `SCRIPT ERROR` de `FootballerVisual.play_action:452` lo provoca la prueba al llamar directamente a un clip de Tripo; en partido no se llega ahí (F0: ninguna situación de campo cae en Tripo en el modo 4). |
| **4. Causa no determinada** | `test_drag_back` ×3: la vuelta procedural nunca arranca en el modo 4 (la hace `JsonBallMove`), pero además «mira al rumbo nuevo» tarda 1,07–1,23 s (objetivo 0,8), lo que podría ser un problema real de respuesta. `test_player_actions::test_skill_spin…` espera la ruleta del pack. |

## 12. Dependencias del modo 4 que deben conservarse [C]

- **Clases:** `PackLibrary` (carga de las 3 librerías JSON, alias, roles, `vary_aliases`), `JsonCatalog`, `AnimationCatalog`
  (resolución de situaciones; las tablas `FIELD` y `KEEPER` aportan los nombres que se resuelven por alias), `BallHandler`,
  `JsonBallMove`, `BallTurn`, `DragBack`, `Footballer`, `PlayerActions`, `ActionMotion`, `Locomotion`, `FootballerVisual`
  (rama `json_mode`), `TouchFootIK`, `KeeperPlanner`, `Goalkeeper`, `SetPiece`, `Referee` (usa la marcha y la mezcla
  direccional JSON), `JsonRig` y `JsonRetarget` (fuera de línea, también en `json_rig`).
- **Los 76 alias de la meta** de los clips. Ojo: varios nombres que el código pide no tienen alias en el modo 4
  (`Idle_To_Sprint`, `Sprint_Turn`, `Running_Tired`, `Defender`, `Defender_2`, `Writhing_In_Pain`) y hoy no hacen nada.
- **Recursos:** `json_clips.res`, `json_scenes.res`, `json_keeper.res`, `assets/characters/json/`, `json_kit.gdshader`.
- **Herramientas:** `tools/json_anim/*` (conversor, `selection.json`, `make_selection.py`).

## 13. Riesgos y prioridades recomendadas

**Problemas reales confirmados**, por impacto:
1. Recepción y control sin clips antes del contacto (124 clips sin usar). Es el mayor hueco de jugabilidad.
2. Huecos de transición: arranque, frenada y giros en carrera tienen clips sin conectar; la parada por agotamiento no tiene
   clip; los alias inexistentes no hacen nada.
3. Golpeos en cámara lenta (2590 a 0,17× y otros 3) y contactos inválidos alcanzables por `plan_turn_kick` (0984 escorpión,
   3322), porque ese planificador no filtra `clean`.
4. Pose congelada al final en 37 clips de juego (6 observados en partido).
5. Clasificaciones erróneas (control como giro, movimiento como gesto).
6. Galería: 30 etiquetas faltantes y 24 sobrantes.
7. El arquero ataja casi todo. Queda fuera de F1; posible relación [I]: los radios de manos de `KeeperPlanner.JSON_ROLE_RADIUS`
   (0,40–0,60 m) con 161 clips de atajada. **No determinado.**

**Dudas que necesitan prueba:** si las poses congeladas se ven en partido (revisión visual); el significado de los eventos
`touches` del JSON; las 34 discrepancias de ángulo; por qué no hay cabezazos ni voleas en 30 min (falta de juego aéreo de la
IA o planificador demasiado estricto).

**Orden de intervención recomendado:**
1. Commit de lo pendiente (con tu autorización).
2. F2, árbitro de acciones (base para el resto).
3. F3, recepción.
4. F4 + F7, transiciones de locomoción con los clips `start`, `stop`, `turn_stop` y `turn_stand`.
5. F5, golpeos: cámara lenta, filtro limpio en `plan_turn_kick` y pose congelada.
6. F6, caídas por dirección.

La reclasificación de roles (§7) y las etiquetas de la galería pueden ir en la propia F2 o F3, con regeneración de la
librería autorizada.

**Riesgos:** regenerar `json_clips.res` cambia metadatos que usan los planificadores y obliga a repetir las pruebas con render.
Conectar clips con raíz larga (festejos, entradas en carrera) exige mover el cuerpo con la raíz (`ActionMotion`), no
reproducirlos en el sitio.

## 14. Archivos y métodos inspeccionados

- **Código:** `scripts/animation/{pack_library, json_catalog, animation_catalog, action_motion}.gd`;
  `scripts/player/{ball_handler, json_ball_move, footballer, footballer_visual, player_actions}.gd`;
  `scripts/goalkeeper/{goalkeeper, keeper_planner}.gd`; `scripts/gameplay/{set_piece, practice_scene, referee}.gd`;
  `tools/json_anim/{build_json_library.gd, json_clip_data.gd, make_selection.py, selection.json}`; `tests/test_practice.gd`.
- **Datos:** los 2.022 JSON del zip y su `index.json`; meta `pack` de las 3.223 animaciones de las tres librerías, volcada con
  un script de solo lectura; `anims.rcd.txt` (de F0) para los nombres.
- **Métodos:**
  - Correspondencias y diferencias calculadas en Python.
  - Etiquetado semántico por expresiones regulares sobre los nombres, contrastado con `v_in`, `v_out` y el giro medido
    (`ActionMotion.heading_rel`).
  - Modelo de alcanzabilidad que replica los filtros del código de cada sistema.
  - **Observación de 10 partidos** de 180 s en una copia del proyecto (6 de IA y 4 con el jugador marcado como persona pero
    manejado por la IA), registrando las acciones visuales y las acciones con raíz. Validación: 0 clips observados que el
    modelo dé por desconectados.
  - Hoja de poses de `jn_kick_pass_2590` y `jn_kick_pass_1212` con `model_preview` (render).

## 15. Limitaciones

- El **observador no registra la marcha** (BlendSpace) ni la mezcla direccional; se dan por conectadas por el código.
- **«A2» no significa que funcione**: hay camino en el código, pero no se vio sonar en 30 min. Las rutas exclusivas de la
  persona se ejercitaron con la IA; no hubo control humano real (joystick ni botones de regate o presión de una persona).
- **No se hizo revisión visual** de las poses congeladas, ni de las discrepancias de ángulo, ni de los clips sin conectar.
  Solo hay hoja de poses de 2 golpeos.
- El significado de `touches` del JSON original y de `key_frame` / `length_frames` (= fotograma inicial y final de la toma,
  coincide con `anims.rcd.txt`) **no está determinado más allá de esa coincidencia**.
- Sin pruebas con render del partido completo en F1, sin Android y sin medir rendimiento.
- La copia del proyecto incluye los 14 cambios pendientes; el mapa refleja ese estado.
