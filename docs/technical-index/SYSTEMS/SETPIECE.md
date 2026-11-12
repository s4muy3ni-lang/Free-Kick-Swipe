# SETPIECE — Modos de penales y tiros libres (juego)

## Identificación

- **Qué es:** el juego de la reforma: menú principal y los dos modos, **PENALES** (tanda contra la CPU: un tiro y una
  atajada por ronda, serie de 5 y muerte súbita) y **TIRO LIBRE** (el usuario coloca la pelota donde quiere fuera del
  área; barrera, arquero y jugadores sueltos), en una cancha de fútbol 11 con dos tipos de arco (caja y fondo inclinado).
- **Banco de animación:** el JSON original (las 2.022 animaciones ya convertidas en `assets/animations/json_*.res`). No se
  crean ni modifican clips: el juego elige entre los existentes con sus metadatos medidos (contacto del pie, trayectoria
  de las manos, raíz, rumbo, rol).
- **Estado (2026-11-08):** jugable de punta a punta; la medición de tacto y rendimiento en el teléfono queda para el
  usuario. Informe y análisis: [`docs/reforma/MODOS_TIROS_PENALES.md`](../../reforma/MODOS_TIROS_PENALES.md). Plan
  maestro AAA 2.0 (auditoría, inventario, diagnósticos medidos, diseños y hoja de ruta):
  [`docs/AAA_ROADMAP.md`](../../AAA_ROADMAP.md).

## Piezas y conexiones

| Archivo | Clase | Qué hace | Reutiliza |
|---|---|---|---|
| `scripts/setpiece/main_menu.gd`, `scenes/setpiece/main_menu.tscn` | `MainMenu` | Escena principal: estadio de fondo, PENALES / TIRO LIBRE, pie hábil, dificultad, tipo de arco, acceso al banco de pruebas | `Stadium11`, `SpActor` |
| `scripts/setpiece/setpiece_game.gd`, `scenes/setpiece/setpiece_game.tscn` | `SetPieceGame` | Estados y turnos de los dos modos, trazo, vista previa, resultado, reacciones, cámara | todo lo de abajo |
| `scripts/setpiece/stadium11.gd` | `Stadium11` | Cancha de 105 × 68 m, líneas y áreas reglamentarias, arcos, carteles, tribunas con el público 2D animado de los minijuegos (`ArcadeLook.crowd`; `set_cheer`, `set_boo`, `set_tension`, densidad por perfil gráfico), luces | `Goal`, `GoalNet`, `Pitch.LineBuilder`, `MeshUtil`, `ArcadeLook` |
| `scripts/setpiece/crowd_banners.gd` | `CrowdBanners` | Pancartas de la hinchada colgadas del alambrado con el nombre del jugador del usuario (`player_name`: apodo, nombre o usuario del perfil; sin cuenta «EL <número>»): aliento en calma (y cargadas de un rincón rival), festejo con su gol, cargadas con su fallo; se enrollan y se despliegan al cambiar (`set_mood`); cantidad según el perfil gráfico | `Stadium11`, `Online`, `PlayerCustom`, `GraphicsSettings` |
| `scripts/pitch/goal_net.gd`, `scripts/pitch/cloth_net.gd` | `GoalNet`, `ClothNet` | `GoalNet`: membrana medida que frena la pelota (fondo inclinado, laterales trapezoidales). `ClothNet`: la red visible como tela de verdad (nodos con masa, hilos que solo tiran, gravedad, la pelota como sólido contra las caras de la malla; ~0,8 ms por paso en PC, solo con la pelota cerca) | (ampliada / nueva) |
| `scripts/setpiece/sp_clips.gd` | `SpClips` | Bibliotecas del banco JSON, id → biblioteca, meta, raíz y rumbo de cada clip | `ClipRolesOverlay`, `ActionMotion.heading_rel` |
| `scripts/setpiece/sp_actor.gd` | `SpActor` | Humano JSON animado con movimiento de raíz, bucles en el sitio, cápsula de colisión que sigue la cadera | `AnimBankCatalog.kit_material` |
| `scripts/setpiece/shot_catalog.gd`, `resources/setpiece/shot_clips.json` | `ShotCatalog` | Golpeos medidos (contacto, dirección del pie respecto de la carrera, velocidad del pie) y elección por pie, dirección, potencia, tipo | catálogo generado por `tools/setpiece/build_shot_catalog.gd` |
| `scripts/setpiece/sp_shooter.gd` | `SpShooter` | Carrera, golpeo con el pie medido en la pelota e impulso en el instante de contacto, reacción | `Ball.kick`, `Ball.set_knuckle` |
| `scripts/setpiece/shot_gesture.gd` | `ShotGesture` | Captura y análisis del trazo (filtro, normalización, velocidades, aceleración, curvatura, suavidad) | — |
| `scripts/setpiece/gesture_tuning.gd` | `GestureTuning` | Coeficientes del trazo, editables en el juego y guardados en `user://gesture_tuning.tres` | — |
| `scripts/setpiece/gesture_shot_model.gd`, `scripts/setpiece/shot_params.gd` | `GestureShotModel`, `ShotParams` | Gesto → parámetros del disparo → física | `ShotSolver` |
| `scripts/setpiece/shot_solver.gd` | `ShotSolver` | Velocidad inicial para llegar al objetivo con el mismo modelo de vuelo que la pelota | `BallPredictor.trajectory` |
| `scripts/setpiece/trajectory_preview.gd` | `TrajectoryPreview` | Trayectoria prevista (cinta discontinua, aro de llegada) mientras el dedo está apoyado | — |
| `scripts/setpiece/gesture_diagnostics.gd` | `GestureDiagnostics` | Panel «Diag.»: medidas del trazo, golpeo elegido, velocidad real de salida, coeficientes, comparador de trazos | — |
| `scripts/setpiece/sp_keeper.gd` | `SpKeeper` | Arquero (IA o usuario): plan de atajada (radio de plan `PLAN_RADIUS_SCALE` acorde al contacto real), en el penal sin anticiparse más de `PENALTY_ANTICIPATION` al golpe; contacto con el instante y la normal reales del choque (`contact_along`, `rebound`, guante `glove_normal`), atrapa o desvía, se levanta, recoge la pelota suelta (`collect`), reacciona al terminar lo que estaba haciendo. **Zona segura** (penales): si se jugó a una zona de `KeeperZones` y el tiro real cruza en esa zona (`sure_save_check`), replanifica con la trayectoria real entre todos sus clips y la sigue en la estirada (`_sure_steer`: ritmo del clip, corrimiento lateral, elevación, alcance extra del guante, palmas juntas) y la saca afuera con el manotazo (`sure_parry_normal`) | `KeeperPlanner.plan_save`, `BallPredictor`, `KeeperZones` |
| `scripts/setpiece/keeper_zones.gd` | `KeeperZones` | El arco en 6 zonas internas (3 columnas × 2 alturas; no se dibujan: el usuario solo ve la marca donde tocó): `zone_of`, `center`, `rect`, `name_of` (como las ve el usuario desde atrás del arco) | — |
| `scripts/setpiece/sp_wall.gd` | `SpWall` | Barrera a 9,15 m con colisión real y salto sincronizado con la llegada de la pelota | `SpActor.enable_collider` |
| `scripts/setpiece/sp_field_players.gd` | `SpFieldPlayers` | Compañeros y defensores sueltos; despeje de cabeza solo si llegan | — |
| `scripts/setpiece/sp_loose_ball.gd` | `SpLooseBall` | Pelota suelta después de la jugada: va el que llega antes; el arquero la recoge en su área (o la despeja con el pie), un defensor corre y la despeja con un golpeo del banco (impulso solo si el pie llega); si uno falla va otro: nunca queda muerta en el área | `SpShooter` (`require_touch`), `SpKeeper.collect`, `ShotCatalog.choose`, `BallPredictor` |
| `scripts/setpiece/sp_reactions.gd` | `SpReactions` | Festejos, lamentos, enojo, aplausos por rol | — |
| `scripts/setpiece/penalty_shootout.gd` | `PenaltyShootout` | Reglas de la tanda (estado puro; base del futuro 1 contra 1) | — |
| `scripts/setpiece/sp_camera.gd`, `scripts/setpiece/sp_hud.gd`, `scripts/setpiece/sp_settings.gd` | `SpCamera`, `SpHud`, `SpSettings` | Cámaras con transición, interfaz horizontal, preferencias y uniformes | `UiTheme` |

Flujo de un tiro del usuario: `ShotGesture` (muestras) → `GestureShotModel.build` (parámetros) → `GestureShotModel.solve`
(física; la vista previa usa la misma función) → `SetPieceGame._take_shot` (error de precisión, clase prevista, familia)
→ `ShotCatalog.choose` (golpeo) → `SpShooter.execute` (carrera y clip) → contacto del clip → `Ball.kick` → arquero,
barrera y sueltos reaccionan a la pelota real → resultado (la física decide; sale apenas ya no puede ser gol:
`SetPieceGame._goal_impossible`) → reacciones (pendientes si alguien todavía patea o se tira) y pelota suelta
(`SpLooseBall`).

## Academia de tiros y Arena de desafíos

Una sola arquitectura (sin un sistema por desafío): `SetPieceGame` en modo `CHALLENGE` juega una definición de datos de
`resources/challenges/challenges.json` con el mismo disparo, física, arquero y barrera.

| Archivo | Clase | Qué hace |
|---|---|---|
| `scripts/challenges/challenge_catalog.gd` | `ChallengeCatalog` | Carga, completa (medallas y recompensa por defecto) y valida las definiciones; niveles, categorías y la dificultad de la Arena (blancos, intentos, arquero, velocidad) |
| `scripts/challenges/challenge_targets.gd` | `ChallengeTargets` | Construye blancos, objetos y obstáculos y detecta aciertos con la pelota real (cruce entero de la línea dentro del recuadro, paso por el aro, señal del marco, gol, objetos caídos) |
| `scripts/challenges/challenge_runner.gd` | `ChallengeRunner` | Intentos, evaluación de cada uno, racha, fin (completo o sin intentos) y registro |
| `scripts/challenges/challenge_score.gd` | `ChallengeScore` | Puntos: precisión, distancia, potencia pedida, racha, especiales, dificultad, intentos de sobra; medallas |
| `scripts/challenges/player_progress.gd` | `PlayerProgress` | Récords, medallas, experiencia, nivel, desbloqueos y cosméticos (`user://progress.cfg`) |
| `scripts/challenges/challenge_menu.gd`, `scenes/challenges/challenge_menu.tscn` | `ChallengeMenu` | Selección de Academia y Arena, medallas, bloqueos, práctica libre |

Reglas: `targets` (cualquier blanco del intento), `sequence` (en orden, uno por intento), `objects` (objetos caídos
acumulados). Un intento solo cuenta si la pelota sale a la velocidad pedida (`min_speed`). La Academia abre un nivel con
bronce en la mitad de los ejercicios del anterior; la Arena abre cada dificultad con bronce en la anterior. La práctica
libre abre todo y no registra.

## Ciclo de la jugada, festejos y lamentos

Todo resultado tiene salida y nadie queda en una pose: `SpActor.rest_loop` (bucle de reposo de cada jugador) se reproduce
solo al terminar un clip de una vez, al llegar de una carrera (`move_to`) o al frenarlo (`stop_moving`); el arquero con la
pelota en las manos pide `freeze_on_finish` (mantiene la pose hasta soltarla). `SpCelebration` arma los festejos:

| Resultado | Cámara | Equipo que pateó | Equipo que defendió |
|---|---|---|---|
| Gol | Vista de juego `GOAL_LIVE_T` (2,6 s) con temblor suave (`SpCamera.shake`), después primer plano del autor `GOAL_CINEMATIC_T` (2,8 s) | Compañeros corren al autor y festejan alrededor (penal: salen del círculo central y el autor va hacia ellos) | Lamento en el sitio |
| Atajada, palo, afuera, barrera, despeje | Vista de juego (sin cinemática) | Lamento en el sitio | Corren a festejar hacia donde terminó: el arquero, la barrera, el punto de salida o el que despejó (`SetPieceGame._celebration_center`); el que va por la pelota suelta no festeja |

«Saltar» (`SetPieceGame.skip_celebration`) pasa a la jugada siguiente una sola vez (el resultado ya se contó). Opciones
visuales (`GraphicsSettings`, se guardan): «Mostrar línea de destino de la pelota» (oculta `TrajectoryPreview`; la física y
el rastro del dedo no cambian) y «Temblor de cámara» (No / Suave / Normal).

## Minijuegos arcade

Base compartida `Minigame` (`scripts/minigames/minigame.gd`): estados INTRO → AIM → RUNUP → FLIGHT → RESOLVE → AIM/OVER con
topes (carrera 6 s, vuelo 7 s, pelota quieta 0,7 s, caída al vacío, tope de turnos), turnos de uno o dos lados, puntos,
reinicio, final con medalla y récord (`PlayerProgress`, grupo `arcade`), IA con `cpu_shot` (mismo `ShotSolver` que el
usuario, con error en grados) e intenciones serializables (`apply_intent`, lista `intents`, semilla del partido) para jugar
en línea más adelante (no implementado). Reutiliza el trazo, la vista previa, el tirador animado, la cámara y la interfaz
del juego. `MinigameCatalog` lee `resources/minigames/minigames.json` (niveles, objetivo breve, medallas, desbloqueo por
bronce); el menú de desafíos tiene la pestaña «Arcade».

`BotonCaida`: dos plataformas sobre el vacío; botón físico (pared o piso) que se aprieta solo con un impacto contra su cara
de al menos `PRESS_SPEED` (2,5 m/s); se abre la trampilla y el jugador cae. 8 niveles (a la vista, custodiado, detrás del
muro, móvil, chico, desnivel, obstáculos en movimiento, varios rebotes); los obstáculos se arman iguales en las dos
plataformas. IA: apunta al botón (o al truco del nivel, `ai.aim`), adelanta el botón móvil con el tiempo de vuelo previsto,
espera su momento con obstáculos móviles (mira dónde van a estar) y corrige parte de su fallo anterior (`CPU_LEARN`).

`Demolicion` (un jugador, tiros limitados): bloques `RigidBody3D` sobre una mesa (torre, pirámide, dominó en cadena,
precisión con bloques blancos que no hay que tocar, muro, torre inestable). Derribado = el centro quedó bajo la tapa de la
mesa o el bloque quedó volcado más de 50°; bajar un piso dentro de la torre no cuenta. El tiro termina cuando la pelota
se frena y los bloques se asientan (`Minigame._settling`). Puntaje: 100 por objetivo, −60 por blanco tirado, +60 por
tiro de sobra si se limpia; sin objetivos derribados no hay puntos ni medalla.

`Enceste` (un jugador, tiros limitados): aro físico (16 esferas en anillo, la pelota rebota en él) con tablero; cuenta
solo si el centro de la pelota cruza el plano del aro bajando y dentro del anillo. Niveles: primer aro, por el tablero
(tapa transparente al frente), aro lejano (18 m), aro móvil y doble aro. Puntaje: 100 por enceste, +50 limpio, +40 por
tiro de sobra al completar.

## Parámetros del trazo

<!-- AUTO:params:GestureTuning -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `smoothing` | `0.35` | 0.0, 0.9 | `scripts/setpiece/gesture_tuning.gd:13` | `scripts/setpiece/gesture_tuning.gd:93`, `scripts/setpiece/shot_gesture.gd:48` | Suavizado exponencial de los puntos (0 = sin filtro, 1 = no se mueve): reduce el temblor del dedo. (Captura y filtro) |
| `min_step` | `0.004` | 0.0, 0.02 | `scripts/setpiece/gesture_tuning.gd:15` | `scripts/setpiece/shot_gesture.gd:45`, `scripts/setpiece/shot_gesture.gd:55` | Distancia minima entre muestras (alturas de pantalla): ignora micro movimientos involuntarios. (Captura y filtro) |
| `max_samples` | `96` | 16, 256 | `scripts/setpiece/gesture_tuning.gd:17` | `scripts/setpiece/shot_gesture.gd:25`, `scripts/setpiece/shot_gesture.gd:26`, `scripts/setpiece/shot_gesture.gd:31`, `scripts/setpiece/shot_gesture.gd:32` (+1) | Muestras como maximo (al llenarse se diezma de a dos). (Captura y filtro) |
| `min_length` | `0.07` | 0.02, 0.3 | `scripts/setpiece/gesture_tuning.gd:19` | `scripts/setpiece/gesture_shot_model.gd:65` | Largo minimo para que el trazo sea un tiro (alturas de pantalla). (Captura y filtro) |
| `speed_slow` | `0.9` | 0.2, 3.0 | `scripts/setpiece/gesture_tuning.gd:23` | `scripts/setpiece/gesture_shot_model.gd:24`, `scripts/setpiece/gesture_tuning.gd:93`, `scripts/setpiece/setpiece_game.gd:1571` | Velocidad del dedo para potencia minima y maxima (alturas de pantalla / s). (Potencia (velocidad del dedo)) |
| `speed_fast` | `4.4` | 1.0, 10.0 | `scripts/setpiece/gesture_tuning.gd:24` | `scripts/setpiece/gesture_shot_model.gd:24`, `scripts/setpiece/gesture_tuning.gd:93`, `scripts/setpiece/setpiece_game.gd:1571` |  (Potencia (velocidad del dedo)) |
| `peak_weight` | `0.35` | 0.0, 1.0 | `scripts/setpiece/gesture_tuning.gd:26` | `scripts/setpiece/gesture_shot_model.gd:23`, `scripts/setpiece/gesture_tuning.gd:94` | Peso de la velocidad maxima frente a la media (un latigazo final cuenta). (Potencia (velocidad del dedo)) |
| `power_curve` | `1.2` | 0.05, 4.0 | `scripts/setpiece/gesture_tuning.gd:28` | `scripts/setpiece/gesture_shot_model.gd:25`, `scripts/setpiece/gesture_tuning.gd:94` | Curva de respuesta: potencia = min + (max - min) * (1 - exp(-g x)) / (1 - exp(-g)); g > 0 satura los trazos muy rapidos. (Potencia (velocidad del dedo)) |
| `power_min` | `0.05` | 0.0, 0.5 | `scripts/setpiece/gesture_tuning.gd:29` | `scripts/setpiece/gesture_shot_model.gd:27` |  (Potencia (velocidad del dedo)) |
| `power_max` | `1.0` | 0.5, 1.0 | `scripts/setpiece/gesture_tuning.gd:30` | `scripts/setpiece/gesture_shot_model.gd:27` |  (Potencia (velocidad del dedo)) |
| `descend_drop` | `0.6` | 0.0, 1.5 | `scripts/setpiece/gesture_tuning.gd:34` | `scripts/setpiece/gesture_shot_model.gd:44`, `scripts/setpiece/gesture_tuning.gd:94` | Trazo que termina bajando: baja el punto de llegada (m) y agrega efecto hacia delante (la pelota cae). (Altura) |
| `ascend_lift` | `0.25` | 0.0, 1.0 | `scripts/setpiece/gesture_tuning.gd:36` | `scripts/setpiece/gesture_shot_model.gd:46` | Trazo que termina subiendo con fuerza: sube el punto de llegada (m). (Altura) |
| `curve_deadzone` | `0.025` | 0.0, 0.1 | `scripts/setpiece/gesture_tuning.gd:40` | `scripts/setpiece/gesture_shot_model.gd:50`, `scripts/setpiece/gesture_shot_model.gd:69`, `scripts/setpiece/gesture_tuning.gd:95`, `scripts/setpiece/setpiece_game.gd:1578` | Curvatura por debajo de la cual no hay efecto (zona muerta). (Efecto (curvatura)) |
| `spin_gain` | `280.0` | 50.0, 600.0 | `scripts/setpiece/gesture_tuning.gd:42` | `scripts/setpiece/gesture_shot_model.gd:52`, `scripts/setpiece/gesture_tuning.gd:95`, `scripts/setpiece/setpiece_game.gd:1580` | Giro (rad/s) por unidad de curvatura y giro maximo. (Efecto (curvatura)) |
| `spin_max` | `70.0` | 10.0, 150.0 | `scripts/setpiece/gesture_tuning.gd:43` | `scripts/setpiece/gesture_shot_model.gd:52`, `scripts/setpiece/gesture_tuning.gd:95`, `scripts/setpiece/setpiece_game.gd:1580` |  (Efecto (curvatura)) |
| `topspin` | `18.0` | 0.0, 40.0 | `scripts/setpiece/gesture_tuning.gd:45` | `scripts/setpiece/gesture_shot_model.gd:110`, `scripts/setpiece/gesture_shot_model.gd:111` | Efecto hacia delante (topspin, rad/s) de los tiros potentes y altos. (Efecto (curvatura)) |
| `error_base` | `0.35` | 0.0, 2.0 | `scripts/setpiece/gesture_tuning.gd:49` | `scripts/setpiece/gesture_shot_model.gd:56`, `scripts/setpiece/gesture_shot_model.gd:57`, `scripts/setpiece/gesture_shot_model.gd:58`, `scripts/setpiece/setpiece_game.gd:1582` | Error (grados) base, por potencia (x potencia^2), por trazo irregular (x (1 - suavidad)) y por trazo corto. (Precision) |
| `error_power` | `1.5` | 0.0, 4.0 | `scripts/setpiece/gesture_tuning.gd:50` | `scripts/setpiece/gesture_shot_model.gd:56`, `scripts/setpiece/gesture_shot_model.gd:57`, `scripts/setpiece/gesture_tuning.gd:96`, `scripts/setpiece/setpiece_game.gd:1582` |  (Precision) |
| `error_rough` | `1.6` | 0.0, 5.0 | `scripts/setpiece/gesture_tuning.gd:51` | `scripts/setpiece/gesture_shot_model.gd:56`, `scripts/setpiece/gesture_shot_model.gd:57`, `scripts/setpiece/gesture_tuning.gd:96` |  (Precision) |
| `error_short` | `0.8` | 0.0, 3.0 | `scripts/setpiece/gesture_tuning.gd:52` | `scripts/setpiece/gesture_shot_model.gd:56`, `scripts/setpiece/gesture_shot_model.gd:57` |  (Precision) |
| `length_full` | `0.45` | 0.1, 1.0 | `scripts/setpiece/gesture_tuning.gd:54` | `scripts/setpiece/gesture_shot_model.gd:55`, `scripts/setpiece/gesture_shot_model.gd:77`, `scripts/setpiece/gesture_tuning.gd:96`, `scripts/setpiece/setpiece_game.gd:1571` (+1) | Largo (alturas de pantalla) a partir del cual el trazo da el control completo de la direccion. (Precision) |
| `rough_ref` | `0.35` | 0.05, 1.0 | `scripts/setpiece/gesture_tuning.gd:56` | `scripts/setpiece/shot_gesture.gd:194` | Irregularidad de referencia (rad de cambio de direccion entre muestras, RMS) que deja la suavidad en 0. (Precision) |
| `lob_max_power` | `0.2` | 0.05, 0.5 | `scripts/setpiece/gesture_tuning.gd:60` | `scripts/setpiece/gesture_shot_model.gd:67`, `scripts/setpiece/gesture_shot_model.gd:92` | Potencia por debajo de la cual un trazo alto es un globo / vaselina. (Tipos de disparo) |
| `high_height` | `1.35` | 0.8, 2.4 | `scripts/setpiece/gesture_tuning.gd:62` | `scripts/setpiece/gesture_shot_model.gd:67`, `scripts/setpiece/gesture_shot_model.gd:75` | Altura de llegada (m) por encima de la cual el tiro es «elevado» o globo. (Tipos de disparo) |
| `curl_min` | `0.07` | 0.02, 0.3 | `scripts/setpiece/gesture_tuning.gd:64` | `scripts/setpiece/gesture_shot_model.gd:69` | Curvatura a partir de la cual el tiro es «con efecto». (Tipos de disparo) |
| `snap_max_length` | `0.2` | 0.05, 0.4 | `scripts/setpiece/gesture_tuning.gd:66` | `scripts/setpiece/gesture_shot_model.gd:71` | Largo maximo de un tiro «rapido de corta distancia» (alturas de pantalla). (Tipos de disparo) |
| `precision_smoothness` | `0.85` | 0.5, 1.0 | `scripts/setpiece/gesture_tuning.gd:68` | `scripts/setpiece/gesture_shot_model.gd:77` | Suavidad minima de un tiro «de precision». (Tipos de disparo) |
| `_current` | `null` | GestureTuning | `scripts/setpiece/gesture_tuning.gd:70` | `scripts/setpiece/gesture_tuning.gd:70`, `scripts/setpiece/gesture_tuning.gd:74`, `scripts/setpiece/gesture_tuning.gd:78`, `scripts/setpiece/gesture_tuning.gd:79` (+3) |  |
<!-- /AUTO -->

## Funciones principales

<!-- AUTO:funcs:scripts/setpiece/gesture_shot_model.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `GestureShotModel.context(plane_x: float, speed_range: Vector2, penalty: bool, half_goal: float, goal_h: float, radius: float)` | 18 | Convierte las propiedades del gesto (ShotGesture.features) en los parametros del disparo (ShotParams) y los resuelve con la fisica de la pel |
| `GestureShotModel.power_from(f: Dictionary, t: GestureTuning)` | 22 |  |
| `GestureShotModel.build(f: Dictionary, end_px: Vector2, cam: Camera3D, ball: Vector3, ctx: Dictionary, t: GestureTuning)` | 30 | Parametros del disparo a partir del gesto. end_px: final del trazo en pantalla. |
| `GestureShotModel.classify(p: ShotParams, t: GestureTuning, goal_h: float)` | 64 | Tipo de disparo que resulta del gesto (sin botones: sale de la combinacion de propiedades). |
| `GestureShotModel._apply_type(p: ShotParams, ctx: Dictionary, t: GestureTuning, descending: float)` | 83 |  |
| `GestureShotModel.solve(p: ShotParams, ball: Vector3, ctx: Dictionary, preview: bool = false)` | 117 | Resuelve con la fisica (preview: menos iteraciones y paso mas grueso, el mismo modelo). |
| `GestureShotModel.target_on_goal(cam: Camera3D, screen_point: Vector2, ball: Vector3, plane_x: float)` | 131 | Punto del plano del arco (x = plane_x) que queda bajo `screen_point`. Si el rayo toca el piso antes (trazo corto), se sigue la direccion del |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/setpiece/shot_catalog.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `ShotCatalog.path()` | 31 | Catalogo de la biblioteca activa (AnimBank): con MIXAMO, el medido sobre los golpeos de Mixamo (con los actuales de respaldo en los roles qu |
| `ShotCatalog.reload()` | 37 | Fuerza una nueva lectura (cambio de biblioteca, pruebas). |
| `ShotCatalog.clips()` | 41 |  |
| `ShotCatalog.mixamo_filter(all: Array)` | 57 | MIXAMO: por TIPO de tiro (potente, normal, colocado, vaselina, error), si hay golpeos de Mixamo de ese tipo se usan solo esos; los actuales  |
| `ShotCatalog.entry(id: StringName)` | 65 |  |
| `ShotCatalog.rel_angle(c: Dictionary)` | 72 | Angulo (grados, + derecha) entre la carrera y el pie al golpear. |
| `ShotCatalog.surface_of(c: Dictionary)` | 76 | Superficie del pie con que golpea: "interior", "empeine" o "exterior". |
| `ShotCatalog.surface_for(kind: int, foot: int, open_side: bool, curled: bool, lateral_spin: float)` | 82 | Superficie que corresponde a un tiro: colocar = interior; potente = empeine; normal = interior al lado abierto y empeine al cruzado; con efe |
| `ShotCatalog.is_desperate(c: Dictionary)` | 94 |  |
| `ShotCatalog.kind_of(c: Dictionary)` | 98 | Familia a la que pertenece un golpeo medido. |
| `ShotCatalog._kind_cost(want: int, have: int)` | 111 | Familias aceptables para un tipo de tiro (la primera es la ideal) y su costo extra. |
| `ShotCatalog.choose(foot: int, shot_rel_deg: float, kind: int, set_piece: bool, rng: RandomNumberGenerator = null, ball_speed: float = -1.0, prefer_short: bool = false, curled: bool = false, surface: String = "")` | 132 | Elige el golpeo. foot: 1 derecho, -1 izquierdo. shot_rel_deg: angulo (+ derecha) del tiro respecto de la carrera habitual del pie (ver appro |
| `ShotCatalog.approach_dir(aim: Vector3, foot: int)` | 184 | Direccion de la carrera habitual del pie para tirar hacia `aim` (unit. horizontal): el diestro llega desde su izquierda. |
| `ShotCatalog.signed_deg(approach: Vector3, shot: Vector3)` | 189 | Angulo (grados, + derecha) de `shot` respecto de `approach` (direcciones horizontales). |
| `ShotCatalog.frame_for_shot(c: Dictionary, ball: Vector3, shot: Vector3)` | 195 | Marco del clip (origen, mirada) para que el pie llegue a la pelota en `ball` y salga hacia `shot` (horizontal). |
| `ShotCatalog.start_time_near(c: Dictionary, frame: Array, pos: Vector3, min_lead: float = 0.55)` | 206 | Instante del clip (antes del contacto, con al menos min_lead s de carrera) en que la raiz pasa mas cerca de `pos` (donde espera el tirador): |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/setpiece/sp_keeper.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `SpKeeper.setup(a: SpActor, b: Ball, gx: float, half: float, height: float)` | 101 |  |
| `SpKeeper.reset(home_pos: Vector3)` | 116 | Coloca al arquero en su sitio, mirando al campo, en espera. |
| `SpKeeper.shuffle_to(p: Vector3, speed: float = 1.4)` | 154 | Paso lateral hacia una posicion (antes del tiro): sigue a la pelota sin dejar el arco. |
| `SpKeeper._yaw()` | 163 |  |
| `SpKeeper.read_shot(_ball_pos: Vector3, _velocity: Vector3, _spin: Vector3)` | 203 |  |
| `SpKeeper._watch_step(delta: float)` | 215 |  |
| `SpKeeper.wall_blocks(bp: Vector3, bv: Vector3)` | 313 | true si la pelota (en bp con velocidad bv) va contra un jugador de la barrera que todavia no paso: su camino cruza el cuerpo de alguno (a me |
| `SpKeeper.in_position_lat()` | 340 |  |
| `SpKeeper._in_position_save(bp: Vector3, bv: Vector3)` | 343 |  |
| `SpKeeper._cancel_dive()` | 380 | Estirada agendada que ya no tiene sentido (la pelota no viene): vuelve a la espera mirando la pelota. |
| `SpKeeper.commit_to(point: Vector3, ball_pos: Vector3, lead: float, speed_guess: float = 22.0)` | 430 |  |
| `SpKeeper.on_kick(ball_pos: Vector3, velocity: Vector3)` | 445 | La pelota salio y ya habia elegido zona sin anticipar: planifica hacia esa zona con la velocidad que ve. |
| `SpKeeper.sure_save_check(traj: PackedVector3Array, step: float)` | 473 | Al salir la pelota (penal): si el tiro REAL (traj, muestras cada `step` s desde el golpe) cruza la linea en la zona a la que se jugo, la ata |
| `SpKeeper._sure_steer(delta: float)` | 507 | Estirada asegurada (cada paso, mientras se tira): toma donde estaran las manos en la muestra _sure_k del clip (con la diferencia medida entr |
| `SpKeeper._line_traj(ball_pos: Vector3, point: Vector3, speed: float, wait: float)` | 548 | Trayectoria supuesta: la pelota quieta `wait` segundos y despues en linea (con un poco de comba) hasta el punto. |
| `SpKeeper.guess_penalty(cue_point: Vector3, ball_pos: Vector3, lead: float, speed_guess: float = 22.0)` | 564 | IA en un penal: elige donde lanzarse con la lectura del cuerpo del tirador. cue_point: hacia donde apuntan la carrera y la cadera del tirado |
| `SpKeeper._plan_with(traj: PackedVector3Array, min_delay: float)` | 582 |  |
| `SpKeeper._make_plan(traj: PackedVector3Array, min_delay: float)` | 588 |  |
| `SpKeeper._adopt(pl: Dictionary)` | 593 | Toma el plan: espera su demora y se tira (o se tira ya). |
| `SpKeeper._start_dive()` | 600 |  |
| `SpKeeper._physics_process(delta: float)` | 609 |  |
| `SpKeeper._check_contact(delta: float)` | 640 |  |
| `SpKeeper.contact_along(b0: Vector3, b1: Vector3, c0: Vector3, c1: Vector3, r: float)` | 689 | Primer contacto entre la pelota (de b0 a b1) y una esfera que se mueve (de c0 a c1) en un paso, con radio sumado r. Devuelve [s en 0..1, cen |
| `SpKeeper._resolve(part: Array, c: Vector3, q: Vector3, parts_now: Dictionary, delta: float)` | 710 | c: centro de la esfera en el contacto; q: centro de la pelota en el contacto. La normal del choque va de c a q. |
| `SpKeeper.rebound(v: Vector3, part_v: Vector3, n: Vector3, e: float, grip: float = BODY_GRIP)` | 768 | Velocidad de la pelota despues del choque con una parte del cuerpo que se mueve a part_v, con normal n (de la parte a la pelota) y restituci |
| `SpKeeper.body_normal(n: Vector3, vr: Vector3, keeper_facing: Vector3)` | 780 |  |
| `SpKeeper.glove_normal(n: Vector3, vr: Vector3, keeper_facing: Vector3)` | 792 | Guante: no es una esfera sino una superficie ancha que el arquero pone con la palma hacia la pelota. Si la pelota llega de frente (desde el  |
| `SpKeeper.sure_parry_normal(vr: Vector3, side: float)` | 802 | Normal del manotazo de una atajada segura: contra la pelota que llega (vr: velocidad relativa), hacia el costado de la pelota (side: z de la |
| `SpKeeper._pick_up()` | 807 |  |
| `SpKeeper._can_catch(q: Vector3, vr: Vector3, parts_now: Dictionary)` | 818 | Atrapa si la pelota llega a las dos manos, no va demasiado rapida y viene de frente a una altura atrapable. |
| `SpKeeper._on_clip_finished(_id: StringName)` | 829 |  |
| `SpKeeper.idle()` | 854 | Vuelve a la espera en su sitio actual (despues de que otro sistema lo manejo). |
| `SpKeeper._back_to_idle(blend: float)` | 859 | De pie y libre: juega la reaccion pendiente o vuelve a la espera (o sigue buscando la pelota suelta). |
| `SpKeeper._getup()` | 875 |  |
| `SpKeeper.react(happy: bool)` | 891 | Festejo (atajo) o lamento (le hicieron gol) en el sitio, cuando ya esta de pie. Si todavia se esta tirando o levantando, queda pendiente y s |
| `SpKeeper.collect(keep_reaction: bool = false)` | 914 | Va a buscar la pelota suelta (rebote, tiro flojo que se frena) y la recoge con las manos: arranca en cuanto esta de pie (despues de la estir |
| `SpKeeper.drop_ball(v: Vector3)` | 931 | De pie con la pelota en las manos (despues de atraparla o recogerla): la suelta delante con velocidad v (cae de las manos) y vuelve a la esp |
| `SpKeeper.is_collecting()` | 942 |  |
| `SpKeeper._collect_step(delta: float)` | 945 |  |
| `SpKeeper.reaction_pending()` | 978 | Tiene una reaccion pendiente: todavia se tira o se levanta y la juega al terminar. |
| `SpKeeper.is_busy()` | 981 |  |
<!-- /AUTO -->

## Pruebas

<!-- AUTO:tests:tests/test_shot_gesture.gd -->
| Prueba | Línea |
|---|---|
| `test_fast_swipe_gives_more_power_than_slow_and_stays_in_limits` | 38 |
| `test_length_is_control_not_power` | 49 |
| `test_upward_swipe_raises_the_ball` | 61 |
| `test_curved_swipe_gives_lateral_spin_on_its_side` | 71 |
| `test_stable_gesture_is_more_precise` | 92 |
| `test_descending_end_keeps_it_low_with_topspin` | 102 |
| `test_gestures_produce_the_shot_types_naturally` | 111 |
| `test_features_do_not_depend_on_screen_resolution_and_samples_are_bounded` | 128 |
| `test_prediction_matches_the_real_ball` | 151 |
<!-- /AUTO -->

<!-- AUTO:tests:tests/test_setpiece_modes.gd -->
| Prueba | Línea |
|---|---|
| `test_penalty_shootout_rules` | 6 |
| `test_kick_choice_follows_the_direction_of_the_shot` | 23 |
| `test_chosen_kicks_put_the_foot_on_the_ball` | 57 |
| `test_wall_size_distance_and_free_kick_zone` | 93 |
| `test_the_wall_really_blocks_the_ball` | 120 |
| `test_both_goal_types_keep_the_ball_in_the_net` | 159 |
| `test_penalty_turn_flow` | 195 |
| `test_side_netting_from_outside_is_not_a_goal` | 223 |
| `test_a_kick_never_gets_stuck` | 254 |
| `test_shooters_wait_beside_the_ball_on_their_side` | 273 |
| `test_foot_surface_follows_the_shot` | 297 |
| `test_entering_a_mode_does_not_freeze` | 315 |
| `test_keeper_contact_uses_the_real_impact_normal` | 350 |
| `test_the_result_is_decided_only_when_a_goal_is_impossible` | 376 |
<!-- /AUTO -->

<!-- AUTO:tests:tests/test_setpiece_render.gd -->
| Prueba | Línea |
|---|---|
| `test_the_foot_reaches_the_ball_at_the_impulse` | 27 |
| `test_the_keeper_touches_what_he_reaches_and_not_what_he_does_not` | 45 |
| `test_the_penalty_keeper_does_not_dive_before_the_kick` | 96 |
| `test_a_loose_ball_never_stays_dead_in_the_box` | 152 |
| `test_shooter_and_keeper_react_after_finishing_their_move` | 197 |
| `test_free_kick_keeper_reads_deflections_and_is_beatable` | 231 |
| `test_keeper_with_the_ball_celebrates_or_kicks_it_out` | 271 |
<!-- /AUTO -->

Con render (esqueleto animado): `xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter test_setpiece_render`.
Capturas: `xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --resolution 1280x720 --path . res://tools/setpiece/captures.tscn -- --out <dir> --case all`.

## Riesgos y límites

- El tacto y el rendimiento en Android no se midieron (no hay teléfono en la sesión). Los coeficientes de `GestureTuning`
  son un punto de partida calibrado con trazos sintéticos y hay que ajustarlos en el teléfono (panel «Diag.»).
- Los golpeos potentes del banco salen hasta ~24° de la carrera; un tiro potente más cruzado usa un golpeo normal con ese
  ángulo (alternativa válida, no bloquea).
- El arquero en un penal elige una ZONA antes del golpe (6 zonas de `KeeperZones`; adivina la IA o elige el usuario) y no
  arranca la estirada más de 0,12 s antes del golpe. Si el tiro va a esa zona, la ataja seguro (pedido del usuario,
  2026-11-11). Para lograrlo se le da algo de ayuda: corrimiento lateral de hasta 1,3 m, elevación de hasta 0,5 m,
  alcance extra del guante de hasta 0,7 m y palmas juntas. Medido en PC: 48 de 48 tiros a los rincones de las 6 zonas a
  19 y 27 m/s. Si el tiro va a otra zona, decide la física de la estirada (antes, con la zona exacta atajaba 6 de 18).
  Sin probar en el teléfono.
- El arquero del tiro libre planifica con el radio del partido (no con el de los penales): no se tira mientras ningún clip
  llegue (se acomoda con pasos laterales) y solo se tira «desesperado» si casi llega (`DESPERATE_REACH`) y es el momento de
  arrancar. Medido en PC con 18 tiros fijos por dificultad (`docs/AAA_ROADMAP.md`, tercera entrega); en el teléfono no se
  probó.
- Minijuegos: el balance de la IA de «Botón de caída» está medido en PC (12 tiros por nivel y dificultad) y queda
  pendiente de ajuste con partidas reales.
- `BallPredictor` sobrestima la rodadura de una pelota pateada sin efecto (no modela el deslizamiento inicial): para la
  decisión anticipada del resultado es conservador; la pelota suelta se vuelve a predecir en cada paso.
- En el tiro libre el arquero vuelve a leer la pelota real cada 0,05 s y se tira en el último instante útil; aun con un plan
  que llega (manos a pocos centímetros según la trayectoria medida de las manos), a veces la pelota pasa a centímetros de
  las esferas de contacto: lo decide la física, no se corrige moviendo la pelota.
- El catálogo de golpeos es un archivo generado: si cambian las bibliotecas hay que regenerarlo
  (`godot --headless --path . res://tools/setpiece/build_shot_catalog.tscn`); la APK falla en CI si no está dentro.
