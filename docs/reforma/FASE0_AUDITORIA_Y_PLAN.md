# Reforma: tiros libres y penales — Fase 0 (auditoría y plan)

Fecha: 2026-11-07. Rama auditada: `integracion-openai` (`7d70291`). Solo lectura: esta fase no cambió código ni
recursos. Pedido del usuario: transformar el juego en dos modos (tiros libres y penales), comparar antes los bancos de
animación JSON, Mixamo y Mocap, y dejar preparada la arquitectura para 1 contra 1 en línea y progresión, sin conectar
Supabase.

## 1. Hallazgos principales

1. **Los tres bancos ya están en la rama actual, y son idénticos en las 4 ramas** (mismo hash de git en cada archivo).
   No hace falta traer nada de otra rama: Mixamo y Mocap se convirtieron a bibliotecas de Godot y se versionaron hace
   semanas; se usaban en los «modos de juego» 1 y 2, hoy ocultos (`Tuning.PLAYABLE_MODES = [4]`).
2. **Los tres bancos animan el mismo esqueleto de 23 huesos** (`Root` + 22 `mixamorig_*`). El futbolista
   `player_base.glb` y el humano del modo JSON `json_human.scn` tienen exactamente los mismos huesos, y ningún clip de
   ningún banco anima un hueso que no exista en ellos. **La comparación «mismo jugador, mismo esqueleto» que pide el §4.2
   es posible sin retargeting nuevo.** Riesgo a verificar: la pose de reposo del esqueleto JSON (`JsonRig`) no es la
   del futbolista (cabeza a 0,87 m frente a 0,84 m); hay que comprobar que cada banco se ve bien sobre el cuerpo elegido.
3. **Los FBX originales de Mixamo y Mocap no están en el repositorio** (nunca estuvieron en la historia de git; el
   directorio `pack/` está en `.gitignore`). Solo hacen falta para regenerar las bibliotecas; para jugar y comparar
   alcanzan las bibliotecas versionadas.
4. **El banco JSON tiene 2.022 archivos fuente, no 2.002** (verificados uno por uno con sus hashes contra el ZIP que
   subiste; 2.024 tramos y 3.223 variantes con espejos en el juego). No se perdió nada.
5. Ya existen, y se pueden reutilizar casi sin cambios: **red del arco con física de tela**, **efecto Magnus**,
   **predictor de la pelota**, **arquero que planifica la atajada** con la trayectoria real de las manos de cada clip y
   un tiempo de reacción, **tiro libre y penal** como balón parado, **árbitro de acciones** y **atributos de jugador**.
6. Faltan por completo: **disparo por trazo del dedo**, **barrera organizada que salte sincronizada** (hoy solo hay una
   reacción de «plantarse en barrera»), **cámaras detrás del tirador**, **cancha de fútbol 11** (las marcas actuales
   son de futsal), **menú de los dos modos**, **experiencia y niveles**, **estado de partida por turnos** para 1 contra 1.
7. Las referencias son verticales (1080 × 1920); **el usuario decidió orientación horizontal obligatoria** (§9).

## 2. Git y ramas

| Rama | Último commit | Contenido | Uso en la reforma |
|---|---|---|---|
| `integracion-openai` | `7d70291` (2026-11-07) | todo: código actual, 3 bancos, documentación | base de la reforma |
| `respaldo-f3` | `3d47a07` (2026-11-06) | igual que una versión anterior + `FUTBOL5_GODOT_4_7_2_INTEGRACION.zip` (358 archivos, 172 ejemplos sintéticos `EJ_*`, reglas y notas; no es un banco de animaciones) | **no se toca** |
| `ccr-7a7dba29-jfbum5` | `a86f623` (2026-10-30) | versión anterior; nada que no esté en la actual | ninguno |
| `ccr-a6c53cd2-uoxpk0` | `e18219f` (2026-10-29) | rama por defecto de GitHub, versión anterior sin el banco JSON | ninguno (no se hace merge) |

Árbol de trabajo limpio. Ninguna rama tiene archivos que falten en `integracion-openai`, salvo el ZIP de integración
de `respaldo-f3`.

## 3. Los tres bancos de animación

| | JSON original | Mixamo | Mocap |
|---|---|---|---|
| Bibliotecas | `json_clips.res` (25 MB), `json_keeper.res` (6,6 MB), `json_scenes.res` (7,4 MB) | `pack_clips.res` (6,5 MB), `pack_keeper.res` (2,3 MB), `touch_clips.res` (0,6 MB, toques derivados) | `mocap_clips.res` (2,6 MB) |
| Clips en el juego | 3.223 (2.024 tramos + 1.199 espejos), 4.910 s | 171 (133 tomas + espejos) + 33 toques | 24 (20 tomas + 4 espejos), 139 s |
| Origen | 2.022 JSON (posiciones de 19 articulaciones) | 133 FBX de Mixamo sobre Y Bot (`mixamorig`) | «Mocap Pack 05 Soccer», 20 tomas Rokoko de 76 huesos |
| Conversión | `tools/json_anim/build_json_library.gd` (posiciones → rotaciones, `JsonRig`) | `tools/animation_pack/build_pack_library.gd` (`PackRetarget`) | `tools/animation_pack/build_mocap_library.gd` (`ROKOKO_MAP`) |
| Fuente en el repo | no (ZIP del usuario; hashes en `docs/integration/fase0/`) | no (`pack/`, ignorado por git) | no (`pack/mocap05/`, ignorado) |
| Metadatos | rol (111), contacto medido, trayectorias de pies/manos/cabeza, raíz, `animdb.json` | rol, contacto medido, trayectorias (`selection.json`) | contacto medido (pase, tiro, penales) |
| Personaje con el que se usaba | `json_human.scn` (modo 4) | `player_base.glb` (modo 1) | `player_base.glb` (modo 2); hay además `mocap_player.scn` de 76 huesos |
| Esqueleto que animan | 23 huesos (18 con pista) | 23 huesos | 23 huesos |

### 3.1 Cobertura de las acciones que pediste (por nombre y rol; la calidad se juzga en la Fase 2)

| Acción | JSON | Mixamo | Mocap |
|---|---|---|---|
| Carrera / aproximación | carreras y arranques por rol (`run`, `sprint`, `start`, `loco_*`); los golpeos de balón parado traen su carrera | `Running`, `Sprint`, `Idle_To_Sprint`, `Jogging` | solo dentro de las tomas de penal y tiro |
| Golpeo de tiro libre | **27 `setpiece_shot`** (p. ej. `…CURLED_FREE_KICK…`, `…SPK_HARD`), 2 `setpiece_lob`, 7 `setpiece_miss`, 70 `kick_shot`, 43 `kick_shot_hard`, 8 `kick_lob` | `soccer_penalty_kick`, `Chip`, `strike_foward_jog`, `kick_soccerball` (×2) | `mc_power_kick` |
| Penal | los mismos golpeos de balón parado | `soccer_penalty_kick` | **`mc_penalty_kick`, `mc_penalty_kick_2`** (con su carrera) |
| Pase de interior / exterior | 64 `kick_pass`, 58 `kick_pass_soft` (pie y lado medidos) | `Soccer_Pass` | `mc_side_foot_pass` |
| Barrera: postura, salto, aterrizaje | **18 `wall`** (`STAND_IN_WALL`, `WALL_JUMP`, ambas manos cubriendo) | `Defender`, `Defender_2`, `Jump_2`, `Jump_4`, `Jumping_Up` (genéricos) | `mc_defending_1/2` (sin salto) |
| Arquero: estiradas | **108 `gk_dive`** (baja, lejos, cerca, izquierda y derecha) | `goalkeeper_diving_save` (×2) | `mc_keeper_save_1/2/3` |
| Arquero: atajada alta, baja, central, captura | 47 `gk_catch` (cintura, cara, sobre la cabeza, salto), 18 `gk_scoop` | `goalkeeper_catch` (×4), `goalkeeper_scoop` | dentro de las 3 tomas de atajada |
| Arquero: bloqueo, desvío | 7 `gk_block` | `goalkeeper_body_block` (×3) | — |
| Arquero: desplazamiento, idle, caída, levantarse | `gk_loco` 6, `gk_sidestep`, `gk_idle*`, 21 `gk_getup`, `gk_miss` | `goalkeeper_sidestep` (×2), `goalkeeper_idle` (×2), `goalkeeper_miss` | — |
| Festejo / lamento | 64 `celebrate`, 43 `celebrate_team`, 20 `celebrate_scorer`, 95 `dejected` | `Cheering`, `Victory`, `Fist_Pump`, `Defeat`… | `mc_celebration_1/2/3` |

Lectura: el banco JSON es el único que cubre todo lo pedido (incluidos salto de barrera y estiradas por zona); Mixamo
cubre casi todo con pocas variantes; **Mocap no tiene salto de barrera, ni bloqueos, ni carreras sueltas, ni
movimientos de arquero fuera de 3 atajadas**. Con Mocap la comparación quedará incompleta en barrera y arquero: lo que
falte se mostrará como «sin clip en este banco», sin rellenarlo con otro banco (pediste no mezclarlos).

## 4. Sistemas existentes y qué se hace con cada uno

| Sistema | Archivo | Estado | En la reforma |
|---|---|---|---|
| Pelota: rebote, rodadura, aire, **Magnus**, red | `scripts/ball/ball.gd`, `ball_tuning.gd` | probado | se reutiliza tal cual; el trazo se traduce a velocidad + giro con `Ball.kick` |
| Efecto del golpeo | `scripts/assistance/kick_model.gd` (`curl_spin`) | probado | se reutiliza para traducir la curvatura del trazo en giro |
| **Predictor de la pelota** | `scripts/ball/ball_predictor.gd` | calibrado contra la física | arquero, barrera (altura del salto) y vista previa del trazo |
| **Red con física de tela** | `scripts/pitch/goal_net.gd` (4 paños, muelles amortiguados, ondas) | funciona en 5 × 2 m | se adapta al arco de 7,32 × 2,44 m; medir coste en Android (Fase 7) |
| Arco y detección de gol | `scripts/pitch/goal.gd` | probado | se reutiliza |
| Cancha | `scripts/pitch/pitch.gd`, `pitch_config.gd` | 50 × 30 (fútbol 7) y futsal | **nueva disposición de fútbol 11** (áreas rectangulares, área chica, punto penal a 11 m, semicírculo de 9,15 m); no se estira la actual |
| **Arquero** | `scripts/goalkeeper/goalkeeper.gd`, `keeper_planner.gd`, `keeper_tuning.gd` (`reaction_time` 0,2 s) | planifica con la trayectoria de las manos de cada clip y la pelota predicha | se reutiliza; se agrega la zona elegida antes del tiro (arquero humano en penales) y la dificultad |
| Balón parado | `scripts/gameplay/set_piece.gd` (`FREE_KICK`, `PENALTY`, golpe cuando el pie llega) | probado en partido | base del tirador; se separa del flujo de partido |
| Árbitro de acciones | `scripts/player/action_arbiter.gd` | probado | se reutiliza (no se duplica) |
| Raíz / root motion | `scripts/animation/action_motion.gd` | probado | carrera de aproximación del tirador |
| Golpeo con clip | `scripts/player/ball_handler.gd` (`plan_clip_kick`, contacto validado) | probado | el tirador elige el clip según pie, potencia y tipo de tiro |
| Barrera | reacción `wall` en `scripts/player/footballer.gd:706` | solo animación | **nueva**: cuerpos con colisión real, postura, salto sincronizado y con variación |
| Cámara | `scripts/camera/match_camera.gd` (transmisión lateral) | probado | **nuevas**: detrás del tirador con zoom (tiros libres) y fija (penales) |
| Controles | `scripts/ui/touch_controls.gd` (joystick y botones) | probado | **nuevo**: trazo del dedo; el joystick no se usa en estos modos |
| Atributos | `scripts/progression/player_attributes.gd` (1–100, factores acotados) | probado | se reutiliza; **nuevo**: experiencia, nivel y empezar en cero |
| Eventos y estado serializables | `scripts/network/` (`GameEvent`, `InputFrame`, `BallState`) | contratos | base de los contratos para el 1 contra 1 |
| Sala de práctica | `scripts/gameplay/practice_scene.gd` (galería de clips) | probado | base del **banco de pruebas** con el selector de bancos |
| Traza de decisiones | `scripts/diagnostics/anim_trace.gd`, overlay F3 | probado | diagnóstico de tirador, barrera y arquero |

El partido de fútbol 5 (`scenes/main/match.tscn`, escena principal hoy) **no se borra**: queda accesible hasta que se
compruebe que nada lo necesita.

## 5. Referencias visuales (3 videos verticales y 4 imágenes)

- Cámara **detrás y por encima del tirador** (estimado a ojo: unos 3–4 m detrás y 2,5–4 m de altura), mirando al arco: el arco ocupa el
  tercio superior; el tirador y la pelota, el centro o el tercio inferior; la barrera queda entre ambos.
- Tiros libres: el **trazo del dedo dibuja la curva** sobre la cancha (línea curva desde la pelota hasta el arco); la
  barrera es de 4–5 jugadores cubriéndose; la posición del balón cambia entre intentos; tras el gol, repetición corta.
- Penales: **cámara fija**, más alta, con el arco lejano arriba y el tirador abajo; el arquero se ve de frente.
- Se usan solo como guía de perspectiva, encuadre y secuencia. No se copia ningún recurso, marca, interfaz ni
  personaje de esos juegos.

## 6. Plan de la reforma por fases (tu §20, con entregables concretos)

Cada fase termina con informe, archivos tocados, pruebas ejecutadas y resultados; **no empiezo la siguiente sin tu
autorización**.

| Fase | Qué se hace | Se reutiliza | Entrega y prueba |
|---|---|---|---|
| 1 Bancos | Escena «Banco de pruebas de animaciones» con un selector **JSON / Mixamo / Mocap** (sin mezclar, sin 4.ª opción): las tres bibliotecas cargadas por separado sobre **el mismo jugador**; catálogo por procedencia (CSV: banco, clip, acción, duración, bucle, espejo, contacto). Sin tocar las bibliotecas originales. | `PackLibrary`, galería de la sala de práctica, `PoseSampler` | prueba: cada clip de cada banco se reproduce sobre el esqueleto elegido sin pistas faltantes; APK por Actions para que la pruebes |
| 2 Comparación | Escenas equivalentes (mismo jugador, cámara, pelota, posición, velocidad): tirador (carrera, apoyo, golpeo, seguimiento), barrera (postura, salto, aterrizaje), arquero (estiradas, alta, baja, bloqueo, desvío, caída) y penal. Métricas medidas (distancia pie–pelota en el contacto, patinaje del pie de apoyo, saltos de pose) y capturas. | `BallHandler` contacto, `KeeperPlanner`, `AnimTrace` | informe comparativo con la tabla de tu §4.3 (lo visual lo juzgas tú) y APK; **espero tu decisión** |
| 3 Estructura | Menú principal (Tiros libres, Penales, Entrenamiento, Estadísticas, Progreso; menú temporal de bancos), estado de partida por turnos compartido, cámaras nuevas, cancha de fútbol 11 | `Pitch`, `PitchConfig`, `Goal` | pruebas de navegación, medidas reglamentarias, encuadre |
| 4 Tiros libres | Elegir punto del balón, barrera reglamentaria (9,15 m), zoom, **trazo → dirección, altura, potencia, curva**, carrera y golpeo sincronizados, barrera con colisión y salto, arquero | `Ball`, `KickModel`, `BallPredictor`, `SetPiece`, `Goalkeeper` | pruebas de tu §21 (posiciones, ambos pies, potencias, efecto, barrera) |
| 5 Penales | Cámara fija, tirador (dirección, potencia, altura, efecto, tipo), arquero que elige zona antes del tiro, resultado y turnos | ídem | pruebas de tu §21 (penales) |
| 6 Animaciones | Integración del banco o bancos que elijas: carrera → golpeo → recuperación, barrera, arquero | árbitro, raíz, catálogo | contacto, transiciones, sin cortes |
| 7 Red | Adaptar la red de tela al arco de fútbol 11, impactos por zona y velocidad, retención; medir coste | `GoalNet` | pruebas de impacto y coste |
| 8 IA | Tirador IA (elige trayectoria sin conocer el resultado) y arquero IA (reacción, anticipación y alcance por dificultad), con componentes compartidos | `KeeperPlanner`, `ShotAssist` | pruebas de dificultad |
| 9 Progresión | Perfil local, nivel, experiencia, atributos desde cero con efecto real, historial | `PlayerAttributes` | pruebas de efecto de cada atributo |
| 10 Online (preparación) | Reglas 1 contra 1 (3 + 3 tiros libres con muerte súbita; tanda de penales), contratos de datos (`PlayerProfile`, `Match`, `ShotAttempt`, `KeeperDecision`…), validación de turnos, simulación local; **sin Supabase** | `scripts/network/` | pruebas de reglas y de trampas (fuera de turno, cambiar la zona tarde) |
| 11 Optimización | Android: física, red, animaciones, cámaras | perfiles existentes | **medición en tu dispositivo** (yo no tengo uno) |

## 7. Riesgos

- **Prueba en Android:** genero la APK en GitHub Actions, pero no tengo un dispositivo; las mediciones en el teléfono
  (rendimiento, red, tacto) dependen de que las hagas tú o de un informe que te pida en cada fase.
- **Memoria:** cargar los tres bancos a la vez suma unos 51 MB de bibliotecas; el selector debe cargar solo el elegido.
- **Reposo distinto del esqueleto JSON** (§1.2): puede deformar los clips de un banco sobre el cuerpo del otro; se mide
  en la Fase 1 antes de comparar.
- **Mocap incompleto** (§3.1): la comparación en barrera y arquero será parcial.
- **Trabajo anterior en curso:** las fases 1 y 2 de la guía de animaciones del partido de fútbol 5 quedaron abiertas
  (`docs/integration/CONTINUAR_GUIA_ANIMACIONES.md`). Con la reforma quedan en pausa; su código no se pierde.

## 8. Decisiones que necesito de ti antes de la Fase 1

1. ~~Orientación~~ — **decidido: horizontal obligatoria** (ver §9).
2. **Rama:** propongo crear `reforma-tiros-penales` a partir de `integracion-openai` para que la reforma sea
   reversible y el partido actual quede intacto en `integracion-openai`. ¿La creo, o sigo en `integracion-openai`?
3. **Jugador de la comparación:** propongo el humano del modo JSON (`json_human.scn`, el cuerpo que el juego usa hoy) y
   comprobar sobre él los otros dos bancos; la alternativa es el futbolista `player_base.glb`, sobre el que se
   retargetearon Mixamo y Mocap.
4. ~~Partido de fútbol 5~~ — **decidido: se quita de esta rama** (ver §9.2; antes se había decidido conservarlo accesible).

## 9. Decisiones tomadas

### 9.1 Orientación horizontal obligatoria (usuario, 2026-11-07)

Tiros libres y penales se desarrollan **solo en horizontal**. Interfaz, cámaras y controles se diseñan para **16:9** y
deben funcionar en otras relaciones de aspecto **sin deformar el campo**. No se usa orientación vertical. Las
referencias verticales se usan solo como guía de perspectiva y secuencia, recompuestas para horizontal.

Estado actual del proyecto frente a esta decisión (comprobado en `project.godot` y `match_camera.gd`):

| Aspecto | Hoy | Qué cumple | Qué falta (fases 3–5) |
|---|---|---|---|
| Orientación | `window/handheld/orientation=0` (horizontal fija) | horizontal | opcional: horizontal con sensor (las dos rotaciones horizontales, valor 4), sin permitir vertical |
| Tamaño base | 1280 × 720 (16:9) | 16:9 | — |
| Interfaz | `stretch/mode="canvas_items"`, `aspect="expand"` | no se deforma: en pantallas más anchas o más altas se agrega espacio | anclar los controles a los bordes y a la zona segura (muescas en 19,5:9 y 20:9); controles del trazo sin tapar balón, barrera ni arco |
| Cámaras 3D | `keep_aspect = KEEP_HEIGHT` | el campo nunca se estira: en pantallas más anchas que 16:9 se ve más a los costados | en pantallas más angostas que 16:9 (16:10, 4:3) se pierde campo a los costados: las cámaras nuevas deben corregir la distancia o el campo de visión para que **arco, barrera, pelota y tirador** queden siempre dentro del cuadro |
| Trazo del dedo | no existe | — | se mide en coordenadas de pantalla normalizadas por la altura (igual en cualquier relación de aspecto) y se proyecta a la cancha con la cámara |

Pruebas a agregar en las fases de cámaras e interfaz: encuadre de tiro libre y de penal en 4:3, 16:10, 16:9, 19,5:9 y
21:9 (arco, barrera y pelota visibles, sin estiramiento: la relación entre ancho y alto de los postes se mantiene) y
controles dentro de la pantalla en cada una.


### 9.2 Fútbol 5 quitado de la rama de la reforma (usuario, 2026-11-07)

Reemplaza la decisión 4 de la §8 («conservar el modo anterior accesible»). En `reforma-tiros-penales` el modo de fútbol 5
**sale**: no hay escena de partido, ni acceso desde el menú, ni pruebas de juego abierto. Se conserva todo lo que sirve para
tiros libres y penales: las animaciones de los tres bancos, la física (pelota, efecto, red, arco), el contacto de los
golpeos, el arquero, la locomoción y el árbitro de acciones. Detalle de lo quitado y lo conservado:
[`FUTBOL5_QUITADO.md`](FUTBOL5_QUITADO.md). La rama `integracion-openai` conserva el partido completo.

### 9.3 Requisitos del modo tiro libre (usuario, 2026-11-07)

Para la Fase 4 (tiros libres). El objetivo del modo es **hacer el gol de tiro libre directo**.

- En la cancha están **todos los jugadores**: la **barrera real** y además **jugadores sueltos** de los dos equipos.
- Nadie fuera del tirador remata: los jugadores sueltos **no tiran ni cabecean al arco**; solo se mueven.
- **Defensores:** si llegan a alcanzar una pelota que va al arco, la **interrumpen o la despejan**; si no llegan, no la tocan.
- **Compañeros del tirador:** no hacen nada con la pelota; **se mueven como si fueran a recibir un centro o esperan un
  rebote**, para que la jugada se vea real.
- La barrera y el arquero siguen las reglas de las §8 y §9 de la instrucción de la reforma (salto sincronizado con colisión
  real; arquero que lee la trayectoria y no conoce el resultado).
