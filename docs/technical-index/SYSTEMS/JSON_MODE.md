# JSON_MODE — Modo 4 «Json»: las 2 022 animaciones JSON sobre un esqueleto canónico y el cuerpo del juego

## Identificación

- **Qué es:** el cuarto modo de jugabilidad (`Tuning.gameplay_mode = 4`, menú de pausa → «Modo de juego: 4 · Json»). Usa las
  animaciones de `animaciones_futbol5_JSON_limpios.zip` (2 022 clips; por clip **solo posiciones** de 19 articulaciones: `pelvis, chest,
  head, l/r_clavicle, l/r_shoulder, l/r_elbow, l/r_wrist, l/r_hip, l/r_knee, l/r_ankle, l/r_toe`, fotogramas clave irregulares a 60 fps,
  trayectoria de la pelvis `root` y meta con golpeo, toques, apoyos, dirección y velocidad) convertidas a **rotaciones** sobre un esqueleto
  canónico de 23 huesos con los nombres del futbolista (`mixamorig_*`).
- **Modelo (desde el 2026-11-12):** el cuerpo del juego, el modelo de Tripo del usuario adaptado al esqueleto
  (`assets/characters/json/tripo_body.scn`, `tools/json_anim/build_tripo_body.gd`), con `player_kit.gdshader` en la posición de
  reposo (número impreso, diseños pegados a la tela).
  - El humanoide propio (`json_human.scn`, `json_kit.gdshader`, `build_json_human.gd`) **se eliminó** del juego y de los
    archivos por pedido del usuario: «el humanoide no va más, queda el jugador 3D».
  - Historia: el 2026-10-30 el GLB de Tripo se había descartado porque se deformaba (piernas y codos rectos en reposo). Lo
    arregló `build_tripo_body` el 2026-11-12 con polos definidos. Botines de ~0.26 m desde el 2026-11-05: de 6 cm detrás a 18.3 cm delante del
  tobillo, un pie real de 1.74 m como en UCS. Antes medían ~0.40 m, 1.8 veces la pelota
  ([E3](../../fases/E3_conduccion_ucs.md#4-qué-cambió)).
- **Estado (2026-10-30):** las **2 022** animaciones convertidas (3 223 clips contando los espejos) y conectadas por rol; ver «Qué usa
  cada grupo». Conducción con toques dados con el pie, giros con pelota / vuelta pisando la pelota / regates con los clips y sus
  toques, golpeo girando hacia un destino al costado o detrás.

## Auditoría del banco completo (E2, 2026-10-31)

`tools/json_anim/analyze_bank.py` mide la cinemática de los 2 022 JSON originales (sin modificarlos) y genera el inventario
`docs/fases/E2_inventario_banco.csv` (una fila por clip con clase anterior/nueva, función, útil, sistema y motivo) y
`scripts/animation/clip_roles_overlay.gd` (`ClipRolesOverlay.ROLE` con 67 reclasificaciones y 7 exclusiones medidas de balón parado —rol `setpiece_miss`— y `ALIAS` para
`Idle_To_Sprint`, `Running_Tired`, `Defender_2`), que `PackLibrary` aplica al cargar el modo 4. Resultado: 1 682 útiles,
317 descartados con motivo, 25 pendientes (recepciones sin verificación visual). Detalle:
[`fases/E2_auditoria_banco.md`](../../fases/E2_auditoria_banco.md). Sin equivalente en el banco: `Sprint_Turn`,
`Soccer_Spin` (ruleta) y malabares (el botón de la práctica se oculta).


## Datos de origen y esqueleto canónico

- Las articulaciones vienen centradas en la pelvis (la trayectoria va aparte en `root`: adelante −Z del juego) y giran con el
  cuerpo (yaw). `JsonClipData` las pasa al espacio del modelo (X adelante, Y arriba, Z derecha), en metros, e interpola con una
  cúbica de Hermite entre claves.
- **Lado de los giros:** los nombres del zip («…_R_90», «…_L_135») no siempre coinciden con el lado real de los datos (p. ej.
  `STAND_TO_90_R` gira a la izquierda en las articulaciones). Todo se clasifica por lo **medido** (giro del cuerpo, hacia dónde sale la
  pelota), nunca por el nombre.
- **Longitudes** (`JsonRig`): muslo 0.339, pierna 0.420, pie 0.180, brazo 0.258, antebrazo 0.325, clavícula 0.160, cadera
  ±0.1075, pelvis a 0.853 m. En los datos la pierna y el antebrazo **no son rígidos** (la distancia rodilla–tobillo varía
  0.31–0.42 m, codo–muñeca 0.18–0.35): por eso el retarget **no copia posiciones de rodilla/codo**, resuelve una IK de dos
  huesos con las longitudes del esqueleto desde cadera/hombro hasta el tobillo/la muñeca de los datos.

## Retarget por marcos (`JsonRetarget`)

La orientación global de cada hueso es un **marco** (dirección del hueso + un vector secundario) calculado con la misma función
para el **reposo** del modelo y para cada instante de la animación. Medido (`retarget_check.gd`, 4 clips): tobillos, muñecas y puntas a
**0.0 cm** del dato (la IK los alcanza), pecho 1–3 cm, cabeza 4–5 cm.

| Hueso | Marco |
|---|---|
| Cadera | lateral = `l_hip→r_hip`; arriba = columna (`pelvis→chest`) |
| Columna, cuello | mezcla (slerp 0.34 / 0.67 / 0.45) entre los marcos de cadera y pecho / pecho y cabeza |
| Pecho | lateral = `l_clavicle→r_clavicle`; arriba = columna |
| Cabeza | arriba = `chest→head` (centro de la cabeza); lateral del pecho |
| Clavícula | hacia el hombro de los datos |
| Brazo, antebrazo / muslo, pierna | dirección del hueso + **eje de la bisagra** del codo / la rodilla (`u × polo`) |
| Pie | tobillo→punta; «arriba» de la pierna en el aire y vertical con la punta cerca del suelo |
| Mano, punta del pie | siguen a su padre (sin pista de animación) |

## Selección y conversión (`tools/json_anim/make_selection.py`, `build_json_library.gd`)

- `make_selection.py` deja las listas curadas (marcha, conducción, patadas medidas, festejos con alias, arquero...) y clasifica **todo lo
  demás** por categoría del zip, palabras del nombre y geometría medida en las articulaciones: giro total del cuerpo, hacia dónde sale la
  pelota en el golpeo (`kick_dir` del meta, relativo al frente del inicio), velocidad de entrada y salida, postura tendida al final de una
  caída y al principio de un levantarse (`lie`: boca arriba, boca abajo, de costado). 2 024 entradas (dos clips del árbitro valen también
  para el arquero).
- Tres librerías: `json_clips.res` (juego, 2 125 clips, 25 MB), `json_keeper.res` (arquero, 476 clips, 6.6 MB) y `json_scenes.res`
  (festejos, lamentos, gestos, esperas, barrera, escenas; 622 clips, 7.4 MB, se suma a la de campo al cargar). Una animación comprimida
  pesa ~10 KB casi sin importar su duración (sobrecarga fija por pista): por eso los espejos solo se generan donde hacen falta (patadas,
  giros, movimientos con pelota, arquero, caídas, barridas).
- **Rumbo**: bucles → se quita el rumbo medio; clips sueltos → media móvil de 0.25 s; clips que mueven el cuerpo con su raíz (caídas,
  barridas, saques) → solo el rumbo inicial; **clips «turn»** (giros, giros con pelota, regates, golpeos girando) → se quita un rumbo poco
  suavizado (σ 0.1 s) que el **juego aplica al jugador** (`heading_path`), y la raíz queda en el marco del inicio del clip.
- **Meta** (`Animation.get_meta("pack")`): duration, loop, natural_speed, root_total, `root_path` y `heading_path` a 30 Hz, `role`,
  `alias`, `touches`, `strides`, `release`, `natural_dir`, `heading_mode`, `move`, `lie`; trayectorias `paths` solo donde las usan los
  planificadores (patadas, cabezazos, voleas, barridas, saques, arquero); `ball_touches` (cada toque de pelota del clip: instante, pie,
  **dónde está la punta del pie** respecto al cuerpo al inicio del clip con su raíz y su giro, y hacia dónde va); en el `contact` de cada
  golpeo: `kick_turn` (hacia dónde sale la pelota respecto al frente inicial, + izquierda), `body_turn`, `root`, y `clean` (punta baja por
  delante, pie de apoyo en el suelo desde 0.1 s antes, sin patinar, pelota hacia delante).
- **Alias**: cada clip declara los nombres del pack de Mixamo que sustituye; `PackLibrary.resolve` los traduce (y los `_mirror`).
  `PackLibrary.vary_aliases` (en cada saque inicial y cada balón parado) reparte los alias de barridas, saques de banda, balones parados,
  tropiezos, empujones y saques del arquero entre **todos** los clips de su rol.

## Qué usa cada grupo de animaciones

| Grupo del zip (clips) | Rol(es) | Dónde se usa en el juego |
|---|---|---|
| CONTROL (269) | `ball_turn`, `ball_turn_stop`, `ball_skill`, `ball_stop`, `ball_sole`, `ball_start`, `ball_dribble`, `receive`, `receive_turn`, `control_stand`, `jostle_ball`, ciclos `dribble_*` | `JsonBallMove`: giros con pelota (joystick a ≥ 50° del frente), toque orientado con los clips de conducción de UCS (joystick a 14-50°, jugador de la persona), vuelta pisando la pelota (REGATE + atrás), regates (REGATE), frenada con pelota (soltar el joystick a 2.6–4.6 m/s), giro antes de golpear hacia atrás; ciclos de conducción en la marcha con pelota |
| TURN (123) | `turn_start`, `turn_run`, `turn_stand`, `turn_stop`, `start`, `stop`, `ball_turn` (con pelota) | `Footballer._json_turn_move`: giros sin pelota de ≥ 100° lejos de la pelota (la IA, solo desde parado) |
| KICK (494) | `kick_pass_soft`, `kick_pass`, `kick_shot`, `kick_shot_hard`, `kick_lob`, `kick_cross`, `kick_flick`, `kick_turn`, `kick_back`, `header`, `volley` | planificador de golpeos (`plan_clip_kick`, solo golpeos `clean`), golpeo girando (`plan_turn_kick`), planificador aéreo |
| KICKSETPIECE (36), THROW (12) | `setpiece_*`, `throw_in` | `SetPiece` (alias repartidos en cada balón parado) |
| LOCO (45), SIDESTEP (6) | `walk/jog/run/sprint`, `loco_*`, `dir_*`, `sidestep`, `jostle` | marcha y mezcla direccional (los escalones curados); el resto en la galería |
| TACKLESLIDE (18), TACKLE (16) | `slide`, `tackle_stand` | barridas (alias repartidos); gesto de la entrada de pie (`PlayerActions.tackle_gesture`); disputa al presionar pegado sin entrar (`PlayerActions.press_gesture`, con `jostle`) |
| FALL (29), STUMBLE (28), GETUP (60) | `fall`, `stumble`, `avoid`, `getup`, `gk_getup` | caídas por carrera y sitio libre; levantarse **desde la misma postura** (`lie`); el arquero se levanta tras una estirada (`Goalkeeper._json_getup`) |
| STAND (86) | `idle_fidget`, `idle_ready`, `idle_ball_var`, `wall`, `jostle`, `gk_idle_var` | gestos de espera tras 3.5 s quieto lejos de la pelota; barrera en un tiro libre en contra; gestos del arquero |
| NIS (601) | `celebrate*`, `clap`, `dejected`, `angry`, `warmup`, `gesture`, `nis_*`, `manager`, `mascot`, `crowd`, `referee`, `gk_gesture` | festejos, lamentos, calentamiento, fin del partido (`JsonCatalog.situation_clip`: todos los clips del rol que se pueden reproducir en el sitio); `manager`, `mascot` y `crowd` solo en la galería (los personajes alrededor de la cancha se quitaron: primero la jugabilidad) |
| GKSAVE (181), GKTHROW (6), GKKICK (12) | `gk_dive`, `gk_catch`, `gk_scoop`, `gk_block`, `gk_throw`, `gk_roll`, `gk_kick` | planificador de atajadas por rol (`KeeperPlanner`), saques del arquero |

Todo clip aparece además en la galería de la sala de práctica, agrupado por rol con su nombre en español
(`PracticeScene.ROLE_NAMES`). No tienen disparador propio en el juego (solo galería) los `nis_misc`, `nis_walk`, `nis_sit` (escenas que
caminan o se sientan), las variantes de marcha `loco_*` (los escalones de la marcha son los curados, con fases alineadas) y los
`control_stand` / `receive` que no sirven para recibir a ras de piso (desde F3 la recepción usa los que sí: ver «Recepción»).

## Mecánica del modo (qué cambia en el juego)

### Movimientos con pelota (`JsonBallMove`)

El clip mueve y gira al cuerpo (raíz + rumbo; `PlayerActions.start_move`, `ActionMotion.heading_rel`) y la pelota va **de un toque del
clip al siguiente**: en cada toque (instante y pie de `ball_touches`) recibe el impulso (`Ball.kick`) que la lleva hasta donde estará la
punta del pie en el toque siguiente; el último la deja delante del rumbo de salida (o quieta delante del pie si el giro es para golpear).
Solo empieza si la pelota llega al primer toque: se prueban clips, inicio (0–0.3 s) y un ajuste de paso de hasta 0.4 m; el resto lo cubre
el pie (`TouchFootIK`, hasta 0.32 m). La velocidad de entrada del clip debe estar a ≤ 1.5 m/s de la del jugador (≤ 3 m/s con el botón
REGATE): a más velocidad manda el giro con toques de siempre (`BallTurn`), que no se interrumpe. La IA gira con clip solo en giros de
≥ 110° y como mucho cada 3 s (mientras dura el clip no puede pasar).

### Recepción (`JsonReceive`, F3)

Una pelota que llega (rasante, con bote o por el aire) se recibe con el clip cuya parte del cuerpo del primer contacto real
(perfiles `ReceiveProfiles`: pie, pie en el aire, muslo, rodilla, pecho) encaja con la trayectoria 3D prevista; el contacto se
da cuando la pelota y esa parte del cuerpo animada se encuentran, con una respuesta física propia de cada parte, y la acción
pasa por el árbitro (`ball_move`). Detalle en [PLAYER](PLAYER.md#recepción-y-control-con-clips-jsonreceive-f3-corregido-2026-10-30).
Entran en la selección 50 de los 124 clips (23 utilizables y 27 con condiciones, y sus espejos); 70 esperan verificación visual
y 4 son arranques de conducción. Los nombres tienen el lado invertido respecto de los datos.

### Golpeo girando (`BallHandler.plan_turn_kick`)

`estimated_kick_dir` calcula, con la misma asistencia que el golpeo real (`PassAssist`, `ShotAssist`, `CrossAssist`, azar fijo), hacia
dónde saldrá la pelota. Si queda a ≥ 50° del frente se busca un clip `kick_turn` / `kick_back` cuya pelota sale hacia allí (±40°), con el
cuerpo siguiendo la raíz y el rumbo del clip hasta el contacto (`kick_body_velocity`, `kick_body_yaw`) y ajuste de paso en lazo cerrado.
Hasta 0.6 s de balanceo (0.4 s con un rival a menos de 2.2 m). Si ninguno llega y el destino queda a ≥ 100°, primero un giro con pelota
(`JsonBallMove.turn_for_kick`) y la orden de golpeo espera. Los datos no tienen tiros fuertes que salgan a más de ~110° del frente: los
tiros hacia atrás usan siempre giro y después golpeo.

### Conducción

- **El pie toca la pelota:** al darse el toque, el pie que toca se lleva hasta la superficie de la pelota y la acompaña 0.05 s
  (`_json_touch_ik_start/_step`, hasta 0.34 m de estiramiento). Sin pie justo en la pelota, el pie bajo más cercano a ≤ 0.48 m se estira.
- **Toque de rumbo:** en diagonal o zigzag (camino de la pelota a ≥ 18° del rumbo pedido) y con un pie junto a la pelota, el toque se da
  ya y empuja la pelota casi del todo hacia el rumbo nuevo (`_steer_touch_ready`), en vez de esperar al paso siguiente.
- **Toque orientado con clips de UCS (2026-11-05):** con el joystick a 14-50° del frente, el jugador de la persona sigue
  con un clip de conducción de UCS (`JsonBallMove`, intención `steer`; `steer_pool`: los clips de control con «dribble»
  en el nombre que siguen en carrera, 41 y sus espejos; lista en `tools/json_anim/steer_pool.json`) que gira hacia el mismo lado. El clip se corta tras su segundo
  toque, que deja la pelota hacia el joystick, y prefiere el interior del pie de afuera del giro. Se planifica en cada
  paso (si no, el toque de rumbo físico se adelantaba). Si ningún clip encaja, queda el toque de rumbo. Datos de UCS
  (`animdb.adb`: cuadro del toque, pie, destino, giro y ventana del joystick por clip), video y medidas:
  [E3](../../fases/E3_conduccion_ucs.md).
- Planificación de golpeos con cientos de clips: se evalúan a fondo los 24 cuyo contacto y carrera de entrada (`v_in`) encajan mejor
  (`JSON_KICK_EVAL`); listas de candidatos y cajas de trayectorias del planificador aéreo guardadas por clip.

### Resto

| Dónde | Cambio |
|---|---|
| `PackLibrary` | tres librerías, alias, `by_role`, `vary_aliases`, recarga al cambiar de modo |
| `JsonCatalog` | modelo, escalones de la marcha, candidatos de patada limpios, `situation_clip` (festejos, gestos, espera, barrera, entrada) |
| `PlayerActions` | `start_move` (clips con rumbo), caídas por carrera y sitio libre (`_json_fall`) con levantarse de la misma postura (`_json_getup`) |
| `Footballer` | giros sin pelota con clip, gestos de espera, barrera en tiros libres en contra, giro del cuerpo en golpeos girando |
| `Goalkeeper` | levantarse tras una estirada (con la pelota si la atrapó), gestos con la jugada lejos, estiradas JSON cuentan como estirada |
| `Pitch` | en el modo 4 sin gradas, bancos ni torres de luz (`_build_ambient`); `JsonSideline` (técnicos, mascota, público) se quitó |
| `SetPiece`, `MatchManager` | reparto de alias en cada balón parado y saque inicial |

## Pruebas y qué se midió (2026-10-30, Godot 4.7.2, Linux, Xvfb/llvmpipe)

| Qué | Resultado |
|---|---|
| Suite completa headless (`tools/run_tests.sh`) | pasada final: 215 pruebas / 1 416 comprobaciones / 0 fallos (16 omitidas: necesitan render). En una pasada anterior, a mitad del trabajo, falló una vez el partido de IA del modo 4 (0 tiros en 90 s, azar); en las 6 repeticiones siguientes, 1–4 tiros |
| `json_mode` con render | 10/10: conducción trote 20/20 toques con el pie, carrera 24/24, sprint 16/23, zigzag 32/34 |
| `LIVE_KICKS_MODE=4 live_kicks` (esqueleto animado) | 4/4 pruebas en dos pasadas; 48–49 de 50 golpeos con contacto |
| `TEST_GAMEPLAY_MODE=4 live_feet` | 6/7 (el séptimo, «encima de la pelota al acelerar» 5 % con límite < 5 %, ya fallaba antes y está calibrado para el modo 1) |
| Partido de IA 90 s | 10–14 pases, 16–19 golpeos, ~20 % en falso con rivales encima (en el modo 1 el partido de IA da 6 de 27); 12–14 movimientos con pelota y 21–28 giros sin pelota con clip |
| `play_view` (diagonal ±25°) | 26 de 27 toques con el pie; los del clip de giro a 0–6 cm del punto de toque |
| Vuelta pisando la pelota (REGATE + atrás) al paso, trote, carrera y sprint | siempre con clip (giro de 155–175°), toques a 0–5 cm |
| Tiro con el arco a 96° del frente | clip de girar y patear, punta del pie a 1.3 cm de la pelota en el impulso |
| Planificar un golpeo / un golpeo aéreo | 2.4 ms / 15–18 ms (la librería se carga una vez, ~0.6 s, al montar el partido) |

Revisión a ojo con `tools/json_anim/play_view.gd` (escenarios `diag`, `turn`, `turn90`, `dragback`, `turnshot`, `sideshot`, capturas en el
instante de cada toque con `ON_TOUCH=1`) y `tools/json_anim/match_shot.gd` (imagen de transmisión).

## Qué NO se verificó

- Nada en Android ni en un dispositivo físico. En especial el tiempo de carga (~39 MB de animaciones) y la memoria en el teléfono.
- No se vio cada uno de los 3 223 clips en movimiento: se revisaron por imágenes los giros con pelota, la vuelta pisando la pelota, el
  golpeo girando, la conducción en diagonal y el partido; la clasificación del resto es por reglas y medidas.
- Los zigzag muy bruscos (joystick que se invierte a ±48°) todavía dejan algún toque de rescate sin pie con la pelota a 0.5–0.7 m al costado.
- (Quitados el 2026-10-30, segunda tanda: técnicos, mascota y público alrededor de la cancha.)

## Segunda tanda (2026-10-30): pases, golpeo que no le daba al balón, presión y cancha despejada

Pedido (vídeo de la versión 0.1.34): «la conducción es mala, los pases se sienten débiles y no buscan a un compañero, la presión a veces
no tiene animación, al dar un pase el jugador hace la animación pero no le da al balón»; quitar el público y lo de alrededor de la cancha;
estudiar First Touch (xapk) y Dream League Soccer (vídeos).

**Lo que se vio en el vídeo** (cuadro a cuadro, 4 imágenes/s en los tramos de pase y presión): pase bajo presión que sale a ~15–20° del
compañero y despacio, el receptor (ya controlado por la persona, con el joystick del pase todavía apretado) se aleja de la pelota y la
recoge el rival; defensores pegados al portador 1–2 s sin ningún gesto.

**Lo que se aprendió de First Touch** (sin copiar código ni recursos: nombres de parámetros en `libMPX.so` y la tabla `anims.rcd.txt`
de `game.pak`, formato KPX con zstd): el golpeo se define por un **destino** (`BallDestination`), con potencia y error por atributo
(`KickPower0/1`, `TechniqueKickErrorFW/BW`, `TechniqueRotPowerScaleBW`: golpear girado cuesta potencia); la presión tiene un máximo de
presionantes y un **alcance de entrada al presionar** por fuerza (`MaxActivePresses`, `StrengthPressureTackleRange`,
`PressureSpeedRate`, `TackleSpeedRate`); la conducción tiene tolerancia de pelota suelta (`LooseBallDribbleTolerance`) y escala de
velocidad por técnica (`TechniqueDribbleSpeedScale`). Los nombres de `anims.rcd.txt` son los mismos que los de los clips JSON (de ahí
vienen); su tabla da el tramo de cada toma (fotograma inicial y final) y un ángulo, no el instante de contacto.

| Qué | Dónde | Antes → ahora |
|---|---|---|
| Pase al compañero elegido | `PassAssist.compute`, `FULL_AIM_LEVEL` | con asistencia media o alta el pase va al compañero elegido (antes corregía el 65 % del ángulo con tope de 11.7°); con baja solo se acerca (`pass_max_correction_deg` 30 por unidad) |
| Buscar compañero | `PassAssist.pick_target`, `AssistTuning.pass_cone_deg`, `pass_fallback_cone_deg` | cono 52 → 60°; si nadie cae en él, con asistencia media o alta, cono de respaldo de 85° (el pase al espacio queda para el filtrado) |
| Fuerza del pase | `BallTuning.pass_arrival_speed`, `pass_speed_min` | llegada 4.5 → 6 m/s, mínimo 4 → 7 m/s; pase al espacio 6–20 m (antes 4.5–19) llegando a 1.5 m/s |
| El receptor va a la pelota | `Footballer._recv_stick_lock` | el joystick que se traía del pase no aleja al receptor: corre al punto de encuentro hasta que se suelta una vez |
| Golpeo que no le daba al balón | `BallHandler._json_kick_ik`, `kick_reach`, `PlayerTuning.json_kick_reach` | el pie que patea va hasta la pelota real (IK) en los últimos 0.12 s y la acompaña al salir; el golpeo cuenta hasta 0.65 m, el pie se estira hasta 0.55 m (antes 0.30: 4–6 de ~22 patadas por partido se perdían en el aire con la pelota a 0.30–0.47 m) |
| Primer toque de un giro con pelota | `JsonBallMove.MAX_LEAD` | espera máxima de 0.4 s hasta el primer toque (con 0.6 s un rival tocaba la pelota antes y el toque se erraba) |
| Presión con animación | `PlayerActions.press_gesture`, `JsonCatalog.SITUATION_ROLES.press_duel` | quien presiona pegado sin entrar forcejea (clips `jostle` / entrada de pie), también la persona; la IA entra más (`AI_TACKLE_COMMIT` 0.3 → 0.45) |
| Cancha | `Pitch._build_ambient`, `MatchScene` | sin gradas, bancos, torres ni personajes alrededor en el modo 4 |

Medido (partido de IA de 90 s, modo 4, headless): golpeos en falso 5–6 → 0–4 de 16–22 con alcance 0.55 (los que quedaban, a 0.56–0.73 m en jugadas disputadas: el cuerpo empujado 0.4–1.1 m durante el balanceo) y 0 en 4 de 4 partidos con 0.65; pases 11–20 a 12–13 m/s de media;
los pases perdidos de la IA son casi todos bloqueos del defensor pegado al pasador (a 0.1–1.5 m de la salida), no pases mal dirigidos;
10–17 gestos de disputa al presionar. Giros con pelota al azar (36, con y sin sprint, esqueleto animado): ningún toque de clip errado;
las 3 «pérdidas» del ensayo eran el jugador llegando al fondo de la cancha tras 25 m de sprint.

Verificación: suite completa headless 216 pruebas / 1 425 comprobaciones / 0 fallos (16 omitidas: necesitan render); con render
`json_mode` 10/10 (1 omitida) y `LIVE_KICKS_MODE=4 live_kicks` 4/4 (golpeos con la punta del pie a 1–7 cm de la pelota en el impulso);
captura de transmisión con `match_shot` (cancha sin entorno). Sin prueba en Android.

No se cambió: la velocidad del juego ni la de las animaciones (no hay valores de First Touch a la vista: sus parámetros llegan del
servidor o están en el código nativo), el tiro, ni cuántos presionan a la vez en la IA (`TeamBrain`).

## Jugadores que se deslizaban «como estatuas» (2026-10-30, tercera tanda)

Pedido: «mis jugadores se desplazaban por la cancha como estatuas fijas sin animación, me pasó más cuando presionaba».

Medido con el esqueleto animado (partido de IA de 60 s, modo 4, imágenes en las que la punta del pie no se mueve respecto
al esqueleto con el cuerpo a más de 2.5 m/s): **808** imágenes (635 presionando), casi todas sin ninguna acción en curso.

| Causa | Arreglo |
|---|---|
| La mezcla direccional (marcaje y presión mirando al rival: `Locomotion.jockeying` → `FootballerVisual.directional`) buscaba los clips del pack de Mixamo (`DIR_POINTS`), que no existen en el modo 4: quedaba solo el punto central, y el cuerpo se deslizaba con la pose fija. Lo mismo el arquero al acomodarse y el árbitro. | `JsonCatalog.dir_points` / `dir_ref_speed`: trote al frente y los clips `dir_back`, `dir_back_diag`, `dir_fwd_diag`, `dir_side` (y espejos) a distancia 1 en su dirección medida (`natural_dir`); cadencia con su velocidad media; centro, el reposo de la marcha del modo. |
| Gestos en el sitio (entrada de pie, forcejeo, recepción) que seguían sonando con el cuerpo corriendo | `Footballer._json_clip_slides`: se cortan si el cuerpo va más de `SLIDE_CUT_SPEED` (1.8 m/s) por encima de la carrera del clip durante `SLIDE_CUT_TIME` (0.15 s); los gestos de presión y entrada solo empiezan si el cuerpo no corre más que el clip (+1.8 m/s; desde F2 lo decide `ActionArbiter.fits_in_place`, antes la constante PlayerActions.GESTURE_MAX_SPEED). |

Después: **81** imágenes (7 presionando). Prueba: `test_json_mode::test_model_builds_and_animates` comprueba que la mezcla
direccional del modo 4 tiene ≥ 6 clips y que todos existen.

## Árbitro de acciones (F2, 2026-10-30)

Una sola autoridad por futbolista decide qué acción controla el cuerpo y la pose (`ActionArbiter`, ver
[PLAYER](PLAYER.md#árbitro-de-acciones-actionarbiter-f2-2026-10-30)). En el modo 4: pose distinta de la raíz 237 → 0 imágenes
en 3 partidos de IA de 180 s; una falta derriba también a un jugador en un movimiento con pelota de clip; sin poses huérfanas
tras un reinicio. Las situaciones de presentación que no tienen clip JSON ya no recurren a clips de Tripo.

## Recepción con clips (F3 corregido, 2026-10-30)

La recepción deja de ser un gesto después del toque y ya no depende de `ball_touches[0]`: perfiles de contacto por clip,
trayectoria 3D, anticipación del receptor, contacto cuando la pelota llega a la parte del cuerpo animada y respuesta física por
parte (pie, pie en el aire, muslo, rodilla, pecho). Medido en *tests/test_receive.gd (eliminada en la reforma; en el historial de git)* y visto en
`tools/json_anim/receive_view.tscn` (tiras por familia). Verificación visual de los 70 clips pendientes con `CLIP=<id>`
(2026-10-30): 45 confirmados, 25 siguen pendientes ([`fases/F3_verificacion_visual_70.md`](../../fases/F3_verificacion_visual_70.md)).
Desde esa fecha el modo 4 es el predeterminado y el único que ofrece el menú (`Tuning.PLAYABLE_MODES`).

## Golpeos hacia cualquier dirección con el banco (2026-11-05)

Medido con render (`tests/test_directional_kicks.gd`, modo 4): el destino (compañero a 9 m, o el arco a 12 m girando la
orientación del tirador) a 0, 45, 90, 135 y 180 grados del frente, parado y al trote. Clip que ejecuta el golpeo:

| Destino | Pase parado | Pase al trote | Tiro parado | Tiro al trote |
|---|---|---|---|---|
| 0° | `kick_pass` | `kick_pass` | `kick_shot` | `kick_shot` |
| 45° | `kick_pass_soft` | `kick_pass` | `kick_shot` | `kick_shot` |
| 90° | `kick_turn` (golpeo girando) | `kick_turn` | `kick_turn` | `kick_shot` |
| 135° | `kick_turn` | `kick_turn` | giro con pelota `ball_turn` + `kick_turn` | giro con pelota + `kick_turn` |
| 180° | **`kick_back` (taco)** | giro con pelota + `kick_turn` | giro con pelota + `kick_turn` | a veces sin tiro en 4 s (ver abajo) |

- Pases: 10 de 10 salen hacia el compañero (error ≤ 5°) con el pie en la pelota; los de 180° parado son el taco
  `kick_back` (p. ej. `jn_kick_back_3308`, `jn_kick_back_1622`), sin girar antes. Tiros: 9 de 10.
- **Corregido:** tras `JsonBallMove.turn_for_kick` la orden de golpeo caducaba a los 0.5 s con el clip de giro todavía en
  curso (pase a 180° al trote, sin golpeo); ahora espera al final del giro (`BallHandler.update`, `turning_for_kick`).
- **Pendiente:** tiro a 180° al trote a veces encadena tres giros con pelota sin llegar a tirar en 4 s (en la línea base de
  `respaldo-f3` salió a los 3.08 s tras dos giros). No hay en el banco un tiro fuerte que salga a más de ~110° del frente
  (los `kick_turn` con pelota a ≥ 7 m/s no llegan): el tiro hacia atrás es giro + golpeo, no un taco.
- **Centros:** los dos clips `kick_cross` del banco (`JOG_TO_L_45_CROSS`, `…_CROSS_LOW`, y sus espejos) entran ahora en los
  candidatos del centro (`JsonCatalog.kick_candidates`) aunque no sean «limpios» (contacto a 0.59–0.68 m al costado): el
  planificador solo los usa si el pie llega a la pelota. En la prueba desde la banda (3 centros) se eligieron pases de empeine
  (`kick_pass`) y los 3 cayeron en el área: los `kick_cross` necesitan la pelota a 0.6 m del costado, que conduciendo no pasa.

## Recepción sin tirones: candidatos precalculados (2026-11-05)

`JsonReceive.consider` era el mayor tirón del partido (10-60 ms en una sola imagen en el contenedor, cada 2 pasos, en cada
jugador al que le llega la pelota: ~120-300 ms en un teléfono). Cambios exactos (`scripts/player/json_receive.gd`):

- `warm_cache` (al cargar el partido, `MatchScene._ready`; 51 ms) calcula una vez los 189 candidatos de `ROLES` con todo
  lo fijo: perfil (con el espejo ya aplicado), condiciones, `v_in`/`v_out`, punto y trayectoria del contacto, raíz y rumbo
  del clip en el contacto y en cada inicio de `START_OFFSETS`. Se recorren en el mismo orden que antes (el desempate
  aleatorio del puntaje consume el generador en ese orden). `reset_caches` (desde `PackLibrary._reset_caches`) los vacía.
- Cota del alcance (`_reach_bound`, `_approach_bound`): si la pelota prevista no pasa a esa distancia (más la corrección del
  paso y la holgura) en la ventana de contacto, ningún clip llega y `plan` / `_update_approach` no recorren nada.
- `_pose`: hueso de cada pista resuelto una vez por clip (`_track_map`); antes, una búsqueda de texto por pista en cada pose.
- `rejects` solo se llena con `record_rejects` (la vista `tools/json_anim/receive_view.gd` lo activa).
- Verificación: la salida completa de las 34 pruebas de *test_receive (eliminada en la reforma)* es idéntica con el código anterior y el nuevo (la
  única línea distinta, un partido IA contra el arquero, también cambia entre dos corridas del mismo código).

## Integración ZIP — 2026-11-07

`AnimDB.catalog/record/actions` permite consultar las 2.022 fuentes sin cargar poses y sin entregar el diccionario
compartido. `AnimDB.candidates` resuelve roles efectivos (con las correcciones de `ClipRolesOverlay`) y filtra solo
las condiciones solicitadas por el consumidor: espejos, recorrido de raíz, duración, contacto y librería del arquero.
Sin contexto entrega todas las variantes del rol, sin recorrer sus metadatos. `JsonCatalog.situation_clip` consume
este resolver y conserva sus condiciones físicas. `ActionArbiter` sigue siendo la autoridad sobre interrupciones y pose.

Auditoría reproducible: `OUT=/ruta/audit.json godot --headless --path . res://tools/integration/audit_bank.tscn`.
El informe distingue registro, índice por rol, invocación por `AnimationPlayer`, muestreo de poses, conexión histórica,
verificación visual y Android. Muestrear tres instantes **no certifica** contactos ni transiciones en partido.
Inventario cruzado: `python3 tools/integration/report.py`; resultados y limitaciones en `docs/integration/`.


## Continuación de integración (2026-11-07)

Catálogo central ampliado con rutas de presentación y consulta de estado de las 338 conexiones históricas. Estado parcial y evidencia individual: [continuación](../../integration/continuacion/README.md).

## Trazabilidad de la selección y overlay de depuración (Fase 1, 2026-11-07)

- `scripts/diagnostics/anim_trace.gd` (`AnimTrace`): cada planificador registra los candidatos que examinó (motivo de
  descarte o coste desglosado), el elegido, la decisión de `ActionArbiter`, interrupciones, cancelaciones, caducidades y
  la validación del contacto (punto del cuerpo, pelota, distancia, tolerancia y si se aplicó el impulso). Esquema fijo de
  35 columnas (`AnimTrace.COLUMNS`, sección 3.3 de la guía); `export_csv` / `export_json`. Decisiones sin elegido
  muestreadas (una cada 0,25 s por jugador y familia); máximo 200.000 filas.
- Enganches (todos bajo `if AnimTrace.enabled`, sin consumir azar ni cambiar decisiones): `ActionArbiter.request/_interrupt/_clear`,
  `BallHandler.plan_clip_kick/plan_turn_kick/plan_aerial_kick/_try_execute_pending/_finish_clip_kick/abort_kick`,
  `JsonReceive.consider/plan/_reject`, `JsonBallMove.consider/turn_for_kick/plan_ids/_touch/_received/finish/_abort/cancel`,
  `KeeperPlanner._plan_save` + `Goalkeeper._begin_action/_evaluate_contact`, `PlayerActions.transition_score/try_locomotion_transition/_json_fall/suffer_contact`,
  `Footballer._json_turn_move`.
- `AnimTrace.explain(id)`: por qué un clip no sale — `no_encontrado`, `sin_rol`, `sin_consumidor`, `filtro` (filtros
  estáticos del selector: `JsonCatalog.kick_clip_rejection`, filtro de situación, toques medidos, `JsonReceive.is_candidate`),
  `coste`, `arbitro`, `cancelado`, `sin_contacto`, `filtro_dinamico`, `reproducido` o `sin_evaluar`.
- `scripts/diagnostics/anim_debug_overlay.gd` (`AnimDebugOverlay`, `CanvasLayer`): lo crea `MatchScene` solo en
  compilaciones de depuración. F3 lo muestra y enciende la traza; F4 cambia de jugador. Panel con árbitro, decisión,
  elegido, fotogramas, coste, candidatos y descartes; en el mundo, punto del cuerpo (círculo), pelota prevista (cuadro) y
  línea con la distancia (roja si supera 0,30 m).
- Encender sin overlay: `FUTBOL5_ANIM_TRACE=1` o `-- --anim-trace`; overlay al iniciar: `FUTBOL5_ANIM_DEBUG=1` o `-- --anim-debug`.
- Prueba: `tests/test_anim_trace.gd` (apagado por defecto, esquema, no cambia decisiones, exportación, `explain` por
  categoría, overlay, partido real de 90 s con todas las familias).

## Golpeos recuperados por el costado (Fase 2, 2026-11-07)

- Diagnóstico de los 322 tramos conectados que ningún consumidor elegía: [`docs/integration/fase2/FASE2_DIAGNOSTICO_322.md`](../../integration/fase2/FASE2_DIAGNOSTICO_322.md)
  (tabla por segmento en `diagnostico_322.csv`). Solo se habilita lo que tiene consumidor real y prueba.
- `JsonCatalog.kick_clean_failures(contact)`: condiciones de golpeo limpio que no se cumplen (`pie_alto`, `detras`,
  `lejos_delante`, `costado`, `pie_lento`, `apoyo_alto`, `giro`, `apoyo_patina`, `apoyo_no_plantado`; mismos umbrales
  que el conversor).
- `JsonCatalog.KICK_LATERAL_MAX = 0.75`: `kick_clip_rejection` admite un golpeo no limpio solo si lo único que falla es
  el costado (contacto entre 0,50 y 0,72 m al lado) y está dentro de 0,75 m. 54 tramos (108 variantes):
  `kick_shot` 24, `kick_shot_hard` 17, `kick_pass` 9, `kick_pass_soft` 3, `kick_lob` 1. El resto de los no limpios
  sigue fuera; el motivo de `kick_clip_rejection` detalla la condición que falla.
- `BallHandler.plan_clip_kick` no cambió: sigue exigiendo que el pie llegue a la pelota, así que estos clips solo
  salen con la pelota a ese costado.
- Prueba: `tests/test_kick_recovery.gd` (conjunto exacto de 54; cada clip y espejo planificado por `plan_clip_kick`,
  aceptado por el árbitro, contacto validado e impulso aplicado: 108/108, peor distancia pie–pelota 0,151 m).
