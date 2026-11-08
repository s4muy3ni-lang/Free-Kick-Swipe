# Estado actual para Claude — Fútbol 5 (Godot 4.7.2)

> **Actualización 2026-11-07 — guía maestra de animaciones:** el trabajo en curso está en la rama `integracion-openai` (no tocar `respaldo-f3`). Para continuar leer primero [`docs/integration/CONTINUAR_GUIA_ANIMACIONES.md`](CONTINUAR_GUIA_ANIMACIONES.md).

Fecha: 2026-11-07. Rama de trabajo: `integracion-openai` (la rama `respaldo-f3` no se tocó). Este documento resume el
estado **verificado** del proyecto después del trabajo de Codex (commits hasta `ac92f42`) y de la continuación de Claude
(desde `65437db`). Toda cifra de pruebas sale de una ejecución real cuyo log está en
[`claude/pruebas/`](claude/pruebas/) o en los artefactos de GitHub Actions citados. Lo que no se ejecutó se dice.

## Resumen ejecutivo

- **Pruebas (código final):** suite headless **310 pruebas, 0 fallidas, 28 omitidas, 2.991 comprobaciones**, sin
  `SCRIPT ERROR` y **sin fugas al cerrar** (antes: 6.272 instancias de ObjectDB y 12 recursos). Las 8 baterías con render
  (Xvfb + OpenGL) pasan sin fallos ni fugas. 27 de las 28 omisiones headless son pruebas que exigen el esqueleto animado
  y se ejecutan en las baterías con render; la restante es la de malabares (no hay clips de malabares en el banco JSON).
- **Animaciones:** 2.022 fuentes / 3.223 variantes registradas, importadas, invocables y muestreadas sin fallos;
  1.948 de 2.024 tramos con disparador en el juego (1.686 históricos + 262 conectados por Codex con invocación probada);
  **76 pendientes** con motivo documentado. Ninguna animación se eliminó.
- **APK:** se genera en GitHub Actions como artefacto `futbol5-apk` (APK arm64-v8a firmada + `.sha256`). Verificada de
  forma independiente (firma v2/v3, ELF aarch64, minSdk 24 / targetSdk 36, sin permisos, zip íntegro y alineado).
  No se probó en un dispositivo ni emulador (sección 9).
- **Prueba de humo del juego real con render:** 60 s de partido grabados (1.800 fotogramas) y 3 partidos de 120 s con
  `--verbose`: sin errores de script ni de renderizado; gol detectado y repetición reproducida
  ([captura](claude/visual/partido_render_xvfb.jpg)).


## 1. Arquitectura actual

Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`), GDScript, renderer GL Compatibility, física Jolt a 60 Hz. Modo de juego
único en el APK: **modo 4 (Json)**, con las 2.022 animaciones convertidas a rotaciones sobre el humanoide propio
(`JsonRig`/`JsonRetarget`). Los modos 1-3 (pack de Mixamo, mocap, Tripo) siguen en el código como respaldo y para pruebas.

Capas (detalle en [`docs/technical-index/INDEX.md`](../technical-index/INDEX.md) y `ARCHITECTURE.md`):

| Capa | Archivos principales | Rol |
|---|---|---|
| Pelota | `scripts/ball/ball.gd`, `ball_predictor.gd`, `ball_tuning.gd` | Física por impulsos (`Ball.kick`), Magnus, rebotes, red; predictor usado por arquero e IA |
| Jugador | `scripts/player/footballer.gd`, `locomotion.gd`, `ball_handler.gd`, `player_actions.gd`, `action_arbiter.gd` | Locomoción, conducción con el pie animado, recepción (`json_receive.gd`), giros con pelota (`ball_turn.gd`, `json_ball_move.gd`, `drag_back.gd`), golpeos con contacto medido, caídas, transiciones |
| Arquero | `scripts/goalkeeper/goalkeeper.gd`, `keeper_planner.gd`, `keeper_tuning.gd` | Posicionamiento, lectura del disparo, atajada planificada con la trayectoria de manos de cada clip, giros de orientación, saque |
| IA | `scripts/ai/ai_input.gd`, `team_brain.gd`, `ucs_params.gd` | Roles, pases, tiros, presión, balón parado; misma entrada (`InputFrame`) que la persona |
| Reglas | `scripts/gameplay/match_manager.gd`, `set_piece.gd`, `referee.gd`, `match_scene.gd`, `match_presentation.gd`, `goal_replay.gd` | Gol, fuera, córner, saque de arco, faltas, penal, reloj, reinicios, repetición, presentación |
| Animación | `scripts/animation/anim_db.gd`, `json_catalog.gd`, `pack_library.gd`, `animation_catalog.gd`, `action_motion.gd`, `touch_foot_ik.gd`, `scripts/player/footballer_visual.gd` | Catálogo, selección por rol/contexto, raíz medida, IK del pie |
| Entrada / Android | `scripts/player/human_input.gd`, `scripts/ui/touch_controls.gd`, `scripts/ui/hud.gd` | Joystick flotante, botones táctiles multitáctiles, HUD y pausa |
| Pruebas | `tests/run_tests.gd`, `tests/test_case.gd`, `tools/run_tests.sh` | Marco headless propio + baterías con render (Xvfb) |
| CI | `.github/workflows/android.yml`, `export_presets.cfg` | Pruebas, auditoría de animaciones, exportación ARM64 firmada y artefacto |

## 2. Sistemas: operativos y parciales

**Operativos y cubiertos por pruebas ejecutadas** (suite headless + render): locomoción y transiciones; conducción con
toques del pie animado, cambios de dirección, zigzag y giros con pelota; recepción con clips (parado, caminando, con
pecho/muslo/pie, orientada a ambos lados, con ambos pies) y control físico cuando no hay clip compatible; pases cortos,
largos y de primera; tiros (potencia, ángulo, colocado, asistido, con efecto); centros; entradas/barridas y faltas;
rebotes, postes, red y trayectorias; arquero (lectura de disparo, atajadas, blocajes, despejes, giros, saque); IA de
equipos en partidos completos de 3, 5, 7 y 10 minutos; detección de gol, marcador, repetición y reinicio; balón parado
(banda, córner, saque de arco, tiro libre, penal); controles táctiles (joystick analógico, botones, multitáctil, pausa).

**Parciales o con límites conocidos**

- 76 tramos de animación sin conexión verificada (sección 3).
- Malabares en la sala de práctica: el banco JSON del modo 4 no tiene clips de malabares (la prueba se omite con ese motivo).
- Las pruebas de partido con `MatchScene` usan RNG sin semilla (`rng.randomize()` en `BallHandler` y `Goalkeeper`):
  sus resultados varían entre ejecuciones. Se corrigieron los dos casos que fallaban por azar; otros umbrales
  estadísticos pueden fallar ocasionalmente. Ver sección 7.
- Sin medición en dispositivo Android real (CPU/GPU/memoria, tacto real). Ver sección 9.
- Las librerías de pose se cargan completas (≈207 MB de memoria estática en escritorio medidos por la auditoría); no
  hay carga por clip.

## 3. Catálogo de animaciones y mecanismo de invocación

**Inventario** ([`estado_individual.csv`](estado_individual.csv), [`runtime_audit.json`](runtime_audit.json)): 2.022
fuentes JSON convertidas → 2.024 tramos → **3.223 variantes** (incluidos espejos) en `json_clips.res`,
`json_scenes.res` y `json_keeper.res`. Ninguna se eliminó.

**Auditoría individual ejecutada** (`tools/integration/audit_bank.tscn`, local y en cada run de Actions): 2.022 fuentes,
3.223 variantes, **0 fallos**; cada variante está registrada, se invoca en un `AnimationPlayer` sobre el esqueleto real,
se muestrea su pose al inicio, mitad y final con valores finitos, y está indexada por su rol efectivo.
Esto prueba registro, importación e invocación técnica; **no** prueba que cada clip se vea bien ni que su contacto sea
correcto en una jugada.

**Conexión con el juego**

| Estado | Tramos | Fuente |
|---|---|---|
| Conectados históricamente (inventario previo «sí»; disparador por rol) | 1.686 | `estado_individual.csv` (no reverificados uno por uno en esta etapa) |
| Pendientes históricos conectados por Codex con consumidor real e invocación probada | 262 | `resources/animation/connection_routes.json`, `continuacion/estado_338.csv` |
| Pendientes | **76** | `continuacion/pendientes_actuales.csv` |

Los 262: 204 rutas de presentación (`MatchPresentation.request`), 25 variantes de marcha (`FootballerVisual.AnimationTree`),
13 transiciones de locomoción (`PlayerActions.request_locomotion_transition`), 11 giros de arquero
(`Goalkeeper.start_orientation_turn`), 5 tiros libres (`SetPiece.recovered_free_kicks`), 2 centros
(`BallHandler.plan_clip_kick`), 1 preparación de saque de banda (`SetPiece._orient_throw`), 1 pelotazo en la cara
(`Ball._on_body_entered → Footballer.on_ball_impact`). Las pruebas `test_environment_connections`, `test_gait_variants`,
`test_transition_connections`, `test_keeper_turn_connections`, `test_setpiece_recovery`, `test_throw_preparation`,
`test_integration_catalog` los invocan por su consumidor real y pasaron en la suite final.

Los 76 pendientes, por motivo (no se conectaron porque hacerlo sin el sistema que falta sería inventar la conexión):

| Rol | Tramos | Qué falta |
|---|---|---|
| `nis_misc`, `nis_sit`, `nis_walk` | 47 | Escenas con objetos o participantes (túnel, himno, camilla, interacción, dolor): falta el objeto/participante y su sincronización |
| `receive`, `receive_turn`, `control_stand` | 25 | Recepciones cuyo instante y parte de contacto no se confirmaron (revisión visual F3) o cuyo gesto contradice el nombre; `JsonReceive` las excluye por su perfil `pending`/`not_reception` |
| `setpiece_miss` | 2 | Saques de banda cuya suelta medida ocurre en t = 0 sin velocidad: no hay evento de suelta real |
| `kick_flick` | 1 | Sombrero: falta la trayectoria aérea entre los dos toques |
| `ball_sole` | 1 | Rol sin sistema de juego |

**Cómo se invoca una animación en partido** (nunca se reproducen todas a la vez; cada actor tiene una sola acción):

1. El sistema de juego detecta la situación (p. ej. `BallHandler` quiere patear, `JsonReceive` ve una pelota que llega,
   `Goalkeeper` planifica una atajada, `SetPiece` prepara un saque, `MatchPresentation` recibe un `GameEvent`).
2. Pide candidatos por rol y contexto: `AnimDB.candidates(rol, contexto)` / `JsonCatalog.kick_candidates` /
   `PackLibrary.by_role`; los nombres del pack se resuelven por alias (`PackLibrary.resolve`).
3. Filtra por física: velocidad de entrada del clip (`v_in`), raíz medida (`root_path`/`root_total`) dentro de la cancha
   y, con pelota muerta, fuera de la zona del saque; punto e instante de contacto del pie/parte del cuerpo con la
   pelota predicha; rumbo medido.
4. Pasa por `ActionArbiter` (niveles de prioridad) y `PlayerActions`/`ActionMotion` aplican la raíz; `FootballerVisual`
   reproduce el clip; el impulso a la pelota ocurre solo en el contacto medido (`Ball.kick`).

## 4. Archivos principales tocados en esta continuación

- `scripts/player/ball_handler.gd`: `BallHandler.dispose()` (rompe el ciclo de referencias).
- `scripts/player/footballer.gd`: `_notification(NOTIFICATION_PREDELETE)` → `dispose()`.
- `scripts/player/player_actions.gd`: `_keeps_set_piece_clear()` usado por `transition_score()`.
- `tests/test_case.gd`: desconexión de señales de los contextos en `cleanup()`.
- `tests/test_resource_cleanup.gd` (nuevo), `tests/test_transition_connections.gd` (prueba nueva),
  `tests/test_shot_keeper.gd` (semilla del arquero), `tests/test_mocap_mode.gd` (modo declarado).
- `.github/workflows/android.yml`: más pruebas con render, verificación de integridad/arquitectura y SHA-256.
- Documentación: `docs/technical-index/` (sincronizado, `check` sin errores), `CHANGELOG.md`, este archivo.

## 5. Errores corregidos

| Error | Reproducción | Causa | Corrección | Regresión |
|---|---|---|---|---|
| «N ObjectDB instances were leaked» y «resources still in use at exit» | Suite completa en `ac92f42`: 6.272 instancias, 12 recursos; `test_action_arbiter` sola: 72 / 5 | Ciclo `BallHandler` ↔ submódulos `RefCounted`; en pruebas, lambdas en `ctx.event_emitted` que capturan `ctx` | `BallHandler.dispose()` al liberar el `Footballer`; `TestCase.cleanup()` desconecta | `test_resource_cleanup` (falla sin la corrección: 6 objetos vivos) |
| Rival dentro de la carrerilla de un tiro libre (3,79 m < 4 m) | `test_set_pieces` falló en la suite local; 4 de 30 repeticiones | La raíz recta de una transición de arranque (`jn_start_0468`) ignoraba el rodeo de la IA | `PlayerActions._keeps_set_piece_clear` | `test_dead_ball_transition_never_carries_a_player_into_the_set_piece_zone` (falla sin la corrección en 3 clips) |
| `test_shot_keeper` fallaba al azar («18 m potente: 0 goles») | Distintos resultados por ejecución; 10 semillas: 35 goles en 800 (1-5 por serie) | RNG del arquero aleatorizado; la prueba sembraba solo al tirador | Semilla fija por tiro también para el arquero (umbrales intactos) | La misma prueba, ahora reproducible |
| 6 pruebas del modo 2 (mocap) siempre omitidas | `[SKIP] … no existe mocap_clips.res` con el archivo presente | El runner las ejecutaba en modo 4 | `gameplay_mode() = 1` | 7/0, 79 comprobaciones |
| Workflow: `dribble_reference` y la recepción con pie vivo no se ejecutaban nunca (se omiten en headless) | Revisión del workflow | Faltaban en la lista de render | Añadidas | Ejecutadas localmente con render: 2/0 y 1/0 |

Fallos del run 59 (recepción con receptor en movimiento ×3 y distribución de atajadas al palo): **ya corregidos por
Codex en `ac92f42`** (montaje de la prueba de recepción con intercepción real; `_notice_real_shot` ya no pisa la
anticipación del arquero). Verificado: `test_receive` 30/0 y `test_shot_keeper` pasa en `ac92f42`; en la base anterior a
Codex (`7e99cb1`) `test_shot_keeper` también pasa (logs en `claude/pruebas/`).

## 6. Pruebas ejecutadas y resultados

Todas con Godot 4.7.2 oficial; logs en [`claude/pruebas/`](claude/pruebas/).

| Ejecución | Commit | Resultado |
|---|---|---|
| Suite headless de partida (local) | `ac92f42` | 306 pruebas, 1 fallida (`test_set_pieces`, invasión de carrerilla), 34 omitidas, 2.911 comprobaciones; 6.272 instancias filtradas, 12 recursos — `suite_base_ac92f42.log` |
| Run 59 de Actions (headless) | `9d004df` | 305 pruebas, 4 fallidas (3 de recepción, 1 de atajadas) — `actions_run59_headless.log` |
| `test_receive` aislada | `ac92f42` | 30 / 0 fallidas (2 omitidas) |
| `test_shot_keeper` | `7e99cb1` (base) / `ac92f42` | pasa / pasa — `shot_keeper_base_7e99cb1.log`, `shot_keeper_ac92f42.log` |
| Suite headless tras etapa 1 (local) | `65437db` sin semilla de arquero | 309 pruebas, 1 fallida (`test_shot_keeper`, azar del arquero), 28 omitidas, 0 fugas — `suite_correcciones_etapa1.log` |
| Run 62 de Actions | `65437db` | headless 309/0 (28 omitidas, 2.989 comprobaciones), 8 baterías con render 0 fallos, APK generada |
| **Suite headless final (local)** | código final | **310 pruebas, 0 fallidas, 28 omitidas, 2.991 comprobaciones, 0 fugas** — `suite_final.log` |
| Render final: `live_feet` | código final | 7 / 0, 66 comprobaciones |
| Render final: `live_kicks` | código final | 6 / 0, 50 comprobaciones (incluye la batería de 50 golpeos) |
| Render final: `pack_motion` | código final | 2 / 0, 24 comprobaciones |
| Render final: `json_mode` | código final | 10 / 0 (1 omitida: el partido de IA se mide en headless), 277 comprobaciones |
| Render final: `physical_dribble` | código final | 5 / 0, 34 comprobaciones |
| Render final: `directional_kicks` | código final | 3 / 0, 7 comprobaciones |
| Render final: `dribble_reference` | código final | 2 / 0, 15 comprobaciones |
| Render final: `test_receive` | código final | 30 / 0 (1 omitida: ninguna recepción de prueba eligió un clip con toques posteriores), 164 comprobaciones |
| Auditoría de animaciones | código final | 2.022 fuentes, 3.223 variantes, 0 fallos — `auditoria_animaciones*.{log,json}` |
| Partido real con render (`match.tscn`) | código final | 60 s y 3 × 120 s sin errores; sin fugas salvo con `--write-movie` (ver sección 7) |
| Exportación local ARM64 | `ac92f42` + etapa 1 | APK 59,4 MB firmada v2/v3, `arm64-v8a`, zip íntegro |

Cobertura de situaciones de partido de la suite (todas pasaron en la ejecución final): locomoción y arranques
(`test_locomotion`, `test_gameplay_feel`), conducción y cambios de dirección (`test_mode4_dribble`, `test_ball_turn`,
`test_drag_back`, render `live_feet`/`physical_dribble`/`dribble_reference`), recepciones con ambos pies y otras partes
(`test_receive`, `test_pass_receiver_control`), pases cortos/largos/de primera (`test_passing`, render `live_kicks`), tiros normales
y cruzados (`test_shooting`, `test_pes_mechanics`, render `directional_kicks`), centros (`test_cross_connections`, render `directional_kicks`), entradas y faltas
(`test_press`, `test_player_actions`, `test_action_arbiter`, `test_falls_direction`), rebotes y colisiones (`test_ball_physics`, `test_ball_curl`, `test_ball_prediction`, `test_ball_face_reaction`, `test_goal_net`),
arquero (`test_goalkeeper`, `test_shot_keeper`, `test_keeper_*`), equipos (`test_ai_match`, `test_team_shape_metrics`,
`test_full_match` de 3/5/7/10 min), gol y reinicio (`test_full_match`, `test_match_flow`, `test_set_pieces`, `test_goal_replay`), controles
táctiles (`test_touch_controls`). Nombres exactos y cifras en `suite_final.log`.


## 7. Errores y riesgos pendientes

- 76 tramos de animación sin conexión (sección 3).
- Pruebas estadísticas sobre `MatchScene` con RNG libre (partidos de IA, balón parado): pueden variar entre ejecuciones.
  Recomendación: sembrar los RNG de `BallHandler`, `Goalkeeper` y `AIInput` desde la prueba.
- Acciones de GitHub en Node 20 forzadas a Node 24 (aviso de deprecación de `actions/checkout@v4`, `setup-java@v4`,
  `cache@v4`, `upload-artifact@v4`): funcionan; conviene actualizar a las versiones mayores siguientes.
- `aapt2` avisa de `mipmap/themed_icon` ausente (plantilla de Godot; el preset no define iconos propios). No impide instalar.
- Prueba omitida aun con render: `test_receive::test_second_contact_that_does_not_arrive_cuts_the_clip` (ninguna
  recepción de prueba elige un clip con toques posteriores): ese comportamiento queda sin verificar.
- Con `--write-movie` (grabación de vídeo del editor) Godot informa al salir 2 instancias filtradas (`AudioStreamWAV` y su
  playback). No aparece sin grabación (3 partidos de 120 s con `--verbose`: 0) y detener los reproductores de `Sfx` al
  salir no lo cambia: es del modo de grabación, no del juego.
- Cada APK de prueba se firma con una clave de depuración efímera: hay que desinstalar la anterior antes de instalar otra.

## 8. GitHub Actions

Workflow único: `.github/workflows/android.yml` («Android APK», id 397788632).

- Disparadores: `push` a `integracion-openai` (y ramas principales listadas; ignora cambios solo de `docs/**` y `*.md`)
  y `workflow_dispatch` (entradas `allow_without_pack`, `skip_tests`).
- Permisos: `contents: read` (mínimo; la subida de artefactos usa el token de ejecución). Sin tokens personales ni secretos:
  la firma usa un keystore de depuración creado en cada ejecución. No publica Releases.
- Pasos: Java 21 (Temurin) → Godot 4.7.2 oficial y plantilla Android verificadas por SHA-512 (con caché) → Android SDK
  (cmdline-tools, build-tools 35.0.1, platform android-35) → importación → auditoría de las 2.022 animaciones (artefacto
  `animation-audit`) → suite headless (falla con `[FAIL]`, `SCRIPT ERROR` o `Parse Error`) → 8 baterías con render bajo
  Xvfb → exportación release firmada → verificación (firma v2, paquete y versión, `arm64-v8a` única, ELF aarch64, sin
  permisos, librerías de animación idénticas a las del repositorio, zip íntegro y alineado, tamaño) → artefacto
  `futbol5-apk` (APK + `.sha256`, 14 días).
- **Error 403 de Codex**: su credencial («Resource not accessible by integration») no tenía permiso `actions:write` para
  el despacho manual. El ajuste «Read and write permissions» del repositorio controla el `GITHUB_TOKEN` de los trabajos,
  no los permisos de una integración externa. Desde esta sesión el despacho funciona (HTTP 204, run 61, cancelado a
  propósito por ser un duplicado de `ac92f42` sin pruebas). No se tocaron credenciales.

Ejecuciones de esta etapa (rama `integracion-openai`):

| Run | Commit | Resultado |
|---|---|---|
| [60](https://github.com/roldanhr98-byte/Futbol5/actions/runs/42336476941) | `ac92f42` (Codex) | Éxito: primer APK de la rama (`futbol5-v0.1.60.apk`), verificada de forma independiente |
| [61](https://github.com/roldanhr98-byte/Futbol5/actions/runs/42338568267) | `ac92f42` | Despacho manual de prueba (204); cancelado a propósito |
| [62](https://github.com/roldanhr98-byte/Futbol5/actions/runs/42339679296) | `65437db` | Éxito: headless 309/0, render 8 baterías 0 fallos, APK `futbol5-v0.1.62.apk` |
| **[63](https://github.com/roldanhr98-byte/Futbol5/actions/runs/42342768439)** | **`9d4069c`** | **Éxito: headless 310 pruebas / 0 fallidas / 28 omitidas / 2.991 comprobaciones, 0 fugas; render live_feet 7/0, live_kicks 6/0, pack_motion 2/0, json_mode 10/0, physical_dribble 5/0, directional_kicks 3/0, dribble_reference 2/0, test_receive 30/0, 0 fugas; APK `futbol5-v0.1.63.apk`** |

Logs del run 63 copiados en [`claude/pruebas/actions_run63/`](claude/pruebas/actions_run63/).


## 9. Resultado de la compilación y APK

**APK generada y verificada: sí.**

- Artefacto: **`futbol5-apk`** del [run 63](https://github.com/roldanhr98-byte/Futbol5/actions/runs/42342768439)
  (sección «Artifacts» de esa página; requiere iniciar sesión en GitHub; caduca el 2026-11-21, 14 días). Contiene
  `futbol5-v0.1.63.apk` y `futbol5-v0.1.63.apk.sha256`.
- Paquete `com.webmaletin.futbol5`, versionCode 63, versionName 0.1.63; 59.382.290 bytes.
- SHA-256: `f03473d6cdb05f54bfca1cb16217039200e7fb13e62e2074720f3c368ebd576d`.
- Verificación independiente (descargada del artefacto y comprobada en este entorno con build-tools 35.0.1):
  `sha256sum -c` correcto; `apksigner verify`: firma v2 y v3 válidas, 1 firmante (clave de depuración efímera, CN=Android
  Debug); `aapt2`: `native-code: 'arm64-v8a'` (única ABI), minSdk 24, targetSdk 36, sin permisos; `unzip -t` sin errores;
  `zipalign -c -P 16 4` correcto; `libgodot_android.so` es ELF 64-bit ARM aarch64.
- También se exportó localmente con Godot 4.7.2 y la plantilla oficial (APK de 59,4 MB, mismas comprobaciones) para
  confirmar que la exportación no depende del runner.


Comprobaciones **no** realizadas: instalación y ejecución en un dispositivo Android o emulador. El contenedor no tiene
KVM y es x86_64; el emulador oficial no ejecuta imágenes ARM64 en hosts x86_64, y la APK solo trae `arm64-v8a`.
Para probarla: descargar el artefacto, desinstalar versiones anteriores (`adb uninstall com.webmaletin.futbol5`) y
`adb install futbol5-v0.1.N.apk`.

## 10. Commits de esta continuación (rama `integracion-openai`)

| Commit | Contenido |
|---|---|
| `65437db` | Fugas de ObjectDB (ciclo `BallHandler`), invasión de la zona de balón parado, semilla del arquero en `test_shot_keeper`, modo de `test_mocap_mode`, pruebas de regresión, workflow (render ampliado, integridad y SHA-256 de la APK), evidencia |
| `9d4069c` | Segundo ciclo de fugas (señales del `BallHandler`), control de fugas en CI, este documento y evidencia final |
| (este) | Resultados del run 63 y verificación de la APK descargada |

Los commits de Codex (`a5edf7a` … `ac92f42`) se conservan intactos debajo.
