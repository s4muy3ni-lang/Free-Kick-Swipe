# ANIMATION_PACK — Pack de 133 animaciones de fútbol (Mixamo / Y Bot): evaluación e integración

> **BORRADO el 2026-11-08** por pedido del usuario junto con el banco Mocap: el juego usa solo el banco JSON original.
> Lista de lo quitado y cómo recuperarlo: [`docs/reforma/MIXAMO_MOCAP_QUITADOS.md`](../../reforma/MIXAMO_MOCAP_QUITADOS.md).
> El resto de esta ficha es historia (describe archivos que ya no están).

## Identificación

- **Qué es:** el pack propio (`futbol.zip`: `README.md`, `indice_futbol.json`, 133 FBX de animación y `personaje/ybot_tpose.fbx`) evaluado frente a los 13 clips de Tripo y **integrado parcialmente** en un único sistema de animación sobre el futbolista de Tripo (23 huesos, ~7 640 triángulos, sin cambios). Son FBX 7.7 a 30 fps, solo esqueleto `mixamorig` (sin malla) sobre el Y Bot; 63 clips son del Soccer Game Pack y 70 son sueltos/complementos.
- **Estado (2026-10-27):** **integrado por completo.** Los 133 clips están convertidos (134 en `pack_clips.res` con sus espejos, 37 en `pack_keeper.res`) y **los 133 tienen disparador en el juego**. Los 40 que antes solo estaban en la galería se conectaron así: marcha (`Jogging_inplace` en la marcha; `Running_inplace` y `Two_Cycle_Sprint_inplace` en la marcha con pelota; `Strafe_3_inplace` en la mezcla direccional), transiciones (`Idle_To_Sprint`, `Sprint_Turn`, parada agotado con `Running_Tired`), balón parado con raíz real (`throw_in`, `Chip`, `strike_foward_jog`, `soccer_penalty_kick`), arquero (`goalkeeper_idle_2`, `goalkeeper_miss`, `goalkeeper_directing(_2)`, `goalkeeper_placing_ball(_2)`), defensa y contacto (`Defender`, `Defender_2`, `Jogging_Stumble`, `Sprint_To_Backslide(_inplace)`, `fallen_idle`), recepción (`receive_soccerball`) y el árbitro, que se mueve con el desplazamiento de raíz medido de los **gemelos con raíz** (`Walking_7`, `Jogging`, `Running`, `Sprint`, `Two_Cycle_Sprint`, `Strafe_3`, `jog_*`). La prueba *test_pes_mechanics::test_every_former_gallery_clip_is_wired_into_gameplay (eliminada en la reforma)* lo comprueba. Detalle clip a clip: columna «Estado» y «Uso» de [ANIMATION_PACK_CLIPS.md](../ANIMATION_PACK_CLIPS.md).
- **Dónde están:** las animaciones van **dentro del juego** ya convertidas (assets/animations/pack_clips.res (borrado: Mixamo/Mocap) y `pack_keeper.res`, versionadas, y dentro de la APK). Los FBX originales (`pack/`) son solo la fuente para regenerar las librerías: están en `.gitignore` (no se suben al repositorio; cada copia local los pone en `pack/` si quiere reconvertir). Sin las librerías el juego funciona con Tripo + patada procedural y las pruebas del pack se **omiten** (no se dan por buenas).
- **Última verificación:** <!-- AUTO:verified -->
2026-11-12
<!-- /AUTO -->
- **Dónde está lo demás:** biblioteca y modelo de Tripo → [ANIMATIONS](ANIMATIONS.md); contacto con la pelota y conducción → [PLAYER](PLAYER.md).
- **Tabla de los 133 clips (una fila por clip, con recomendación y estado):** [ANIMATION_PACK_CLIPS.md](../ANIMATION_PACK_CLIPS.md).

## Qué dispara cada grupo de clips

| Rol (`meta["role"]`, grupos de la galería) | Clips | Disparador real |
|---|---|---|
| `marcha`, `direccional`, `marcha_con_balon` | reposo, caminar, trote y sprint (`BlendSpace1D` por velocidad natural) y 8 direcciones (`BlendSpace2D`) para marcar/retroceder | velocidad y dirección reales de `Locomotion` (`FootballerVisual.drive_motion`) |
| `pase_tiro` | `Soccer_Pass`, `strike_foward_jog_inplace` + espejos | `BallHandler.request_kick` (contacto del pie con la pelota) |
| `volea`, `cabezazo` | `scissor_kick`, `Flying_Bicycle_Kick`, `Jumping_Up`… | pelota alta a alcance: el planificador aéreo de `BallHandler` |
| `recepcion` | `Receive` | `FIRST_TOUCH` propio lento |
| `entrada`, `contacto_caida`, `suelo` | `soccer_tackle`(_2/_3), `soccer_trip`, `Shoulder_Hit_And_Fall`, `Falling_Down`, `Sweep_Fall`, `Shove_Reaction`(_2), `Writhing_In_Pain`, `standing_up`, `Getting_Up_3` | `PlayerActions` (barrida planificada con la punta del pie, caídas por contacto, levantarse) |
| `habilidad` | `Soccer_Spin` | botón REGATE / tecla U (`PlayerActions.try_skill`) |
| `salto` | `Jumping_Up`, `Jump_2`, `Jump_4` | cabezazos y celebración |
| `festejo`, `felicitar`, `lamento` | `Excited`, `Victory`, `Fist_Pump_3`, `Clapping`, `Waving_3`, `Defeat`, `Crying`… | `GOAL` (según rol: autor, compañeros, rivales) y fin del partido |
| `arbitro`, `calentamiento` | `Counting`, `Pointing_Forward`, `Waving`, `Arm_Stretching`, `Neck_Stretching` | `Referee` y presentación previa al saque |
| `arquero` (23 clips) | atajadas, estiradas, bloqueos, recogida, saques, reposo | `Goalkeeper` (ver [GOALKEEPER](GOALKEEPER.md)) |
| `malabares` (8) | `kick_up_soccerball`, `kneeing_soccerball`(_2), `kick_soccerball`(_2), `stall_soccerball`(_2…_4) | `JuggleController` en la sala de práctica |
| `practica`, `cansancio` y los gemelos con raíz (`gemelo_raiz`, 17) | `Chip`, `soccer_penalty_kick`, `throw_in`, `Running_Tired`, `Walking_7`… | solo galería (sin disparador en partido) |

La sala de práctica (`PracticeScene`, *scenes/practice/practice.tscn (eliminada en la reforma; en el historial de git)*, botón «Práctica de animaciones» de la pausa) lista **todos** los clips por grupo con repetir, velocidad, raíz, espejo y cámara, y los malabares encadenan clips con impulsos hacia los puntos de contacto medidos (la pelota nunca se coloca a mano).

## Modo 2 de jugabilidad: «Mocap Pack 05 Soccer» (2026-10-29)

La persona aportó el pack de captura de movimiento de fútbol «Mocap Pack 05 Soccer» (21 tomas: 3 conducciones, 3
malabares, saque de banda, pase de interior, tiro potente, 2 penales, 3 festejos, 3 atajadas, 2 de defensa y 2 de
tarjetas; versiones Rokoko, UE5 e iClone) y declaró tener autorización para usarlo. El archivo no trae licencia; dos
tomas llegaron dañadas en el `.rar` (Rokoko `05_Juggling_02`, UE5 `12_Goal_Celebration_01`) y se usa la versión Rokoko de
las otras 20.

- **Conversión** (tools/animation_pack/build_mocap_library.tscn (borrado: Mixamo/Mocap), hereda de `build_pack_library.gd`): esqueleto Rokoko
  de 76 huesos (+Z adelante, pose T, cadera a 0.94 m) → futbolista, con `PackRetarget.bone_map` (`ROKOKO_MAP`: Hips,
  Spine1/3/4, Neck, Head, brazos, Thigh/Shin/Foot/Toe). Las tomas de golpeo traen la carrera previa y la vuelta: se mide el
  contacto en la toma completa, se gira para que el pie salga hacia adelante y se recorta alrededor del golpeo (pase
  1.33 s, tiro 1.43 s, penal 2.40 s con su carrera); los pases y tiros guardan la trayectoria de los pies sin la raíz
  (`paths_root = false`): durante el apoyo el cuerpo sigue al pie plantado. Espejo para la otra pierna. Salida
  assets/animations/mocap_clips.res (borrado: Mixamo/Mocap) (24 clips `mc_*`, 2.6 MB, versionada); `PackLibrary` la suma a la librería de
  campo. Los FBX quedan en `pack/mocap05/` (fuera del repositorio).
- **Contactos medidos**: pase de interior, pie derecho a 4.5 m/s, 0.33 m delante y 0.17 m al costado; tiro potente, pie
  izquierdo a 10.1 m/s (0.34 m delante, 0.32 m al costado); penales, pie derecho a 8.5–9.0 m/s.
- **Qué cambia en el modo 2** (`Tuning.gameplay_mode` = 2, botón «Modo de juego» del menú de pausa;
  AnimationCatalog.mocap_mode (borrado: Mixamo/Mocap)): pase, pase filtrado → `mc_side_foot_pass`; tiro, vaselina, centro → `mc_power_kick`
  (los dos con espejo), con `MOCAP_EXTRA_LATENCY` 0.08 s más para que se vea el balanceo; penal y tiro libre directo →
  `mc_penalty_kick` con su carrera (`SetPiece._kick_clip`); festejos del gol y victoria → `mc_celebration_1..3`. La IA
  usa los mismos clips. Saque de banda → `mc_throw_in` (parado; empieza a los 5.4 s con la pelota arriba y la suelta a
  los 6.68 s con las manos a 0.45 m delante y 1.52 m de alto: `SetPiece.MOCAP_THROW_*`); falta → el árbitro muestra la
  tarjeta amarilla (`mc_yellow_card`, situación `referee_foul`). Conducciones, malabares, atajadas, defensa y tarjeta roja
  están en la galería de la sala de práctica («Mocap fútbol (modo 2)») sin disparador en partido: las conducciones son
  tomas lentas (0.2–1.7 m/s) con giros propios de la raíz que no siguen al joystick, el pack no trae conducción en
  carrera, y las atajadas se desplazan hasta 1.4 m sin coincidir con la trayectoria de la pelota.
- **Modelo propio del modo 2** (Newton, el personaje del pack): tools/animation_pack/build_mocap_character.tscn (borrado: Mixamo/Mocap) lo
  baja de ~33 000 a 6 778 triángulos (LOD de `ImporterMesh`) con su esqueleto Rokoko de 76 huesos y hornea en `COLOR.r`
  la zona del kit de cada vértice según el hueso que más lo mueve (camiseta, short hasta media pierna, medias desde la
  rodilla, botines, piel, pelo) → assets/characters/mocap/mocap_player.scn (borrado: Mixamo/Mocap) + `mocap_kit.gdshader` (colores del
  equipo). En el juego `MocapRig` (scripts/animation/mocap_rig.gd (borrado: Mixamo/Mocap)) cuelga del visual de cada jugador, arquero y árbitro:
  el esqueleto del futbolista sigue haciendo todo (clips, toques, IK, contacto) pero no se dibuja; en cada
  `skeleton_updated` su pose se copia a Newton con el retarget inverso
  (`G_R = A⁻¹·(G_T·Reposo_T⁻¹)·A·Reposo_R`, cadera escalada por la altura de cadera) y piernas y brazos se cierran con
  IK de dos huesos hasta los pies y las manos del futbolista. Medido (*test_mocap_mode (eliminada en la reforma)*): pies y manos a ≤ 0.06 m de los
  del futbolista en un partido; cabeza ≤ 0.06 m.
- **Modo 3 · Tripo** (`Tuning.gameplay_mode` = 3): `FootballerVisual.uses_pack` falso → el modelo de Tripo con sus
  clips (presets) y la patada procedural (`ProceduralPose`), sin pack ni mocap. Tripo3D no genera animaciones a medida
  (su API solo ofrece rigging y retarget de presets de una biblioteca fija; se comprobó en la documentación oficial),
  así que el modo 3 es el modelo y los presets de Tripo. El cambio de modo recarga la escena del partido
  (`Hud.gameplay_mode_changed` → `MatchScene._on_gameplay_mode_changed`).
- **Medido** (*tests/test_mocap_mode.gd (eliminada en la reforma; en el historial de git)*, 7 pruebas: además saque de banda con `mc_throw_in` que sale a 1.55 m, tarjeta
  del árbitro, modelo Newton y modo 3; con render `LIVE_KICKS_MODE=2` en `test_live_kicks`): 12 de 12 pases y tiros
  ejecutados con el clip de la captura de parado a sprint, pie a 0.008–0.057 m de la pelota; con el esqueleto animado,
  48 de 50 golpeos variados con contacto (los otros 2, pelota tocada antes por el rival), pie a 0.01–0.14 m; penal con
  `mc_penalty_kick`. Pendiente: en el pase de primera con el pase de interior el pie de apoyo patina 1.69 m/s (límite de
  la prueba 1.6; en el modo 1, 1.2).

- **Modo 4 · Json** (2026-10-29, ampliado el 2026-10-30): las 2 022 animaciones de `animaciones_futbol5_JSON` sobre un esqueleto
  canónico propio y el humanoide propio; `PackLibrary` en el modo 4 carga `json_clips.res` + `json_scenes.res` / `json_keeper.res`,
  traduce los nombres del pack de Mixamo a clips JSON por alias y los reparte entre los clips de su rol. Ficha completa: [JSON_MODE](JSON_MODE.md).

## Cómo funciona (un solo sistema)

1. **Offline:** tools/animation_pack/build_pack_library.tscn (borrado: Mixamo/Mocap) convierte los clips de `selection.json` con `PackRetarget` (retarget respecto al reposo, no copia de rotaciones locales) a assets/animations/pack_clips.res (borrado: Mixamo/Mocap) (campo) y `pack_keeper.res` (arquero). Mide por clip: velocidad natural, raíz acumulada (**separada** de la cadera, que queda centrada), altura del tobillo, y en patadas el **contacto** (instante, pie, posición) y la **trayectoria de la punta del pie** en la ventana del golpeo.
2. **Catálogo único** (`AnimationCatalog`): situación → clip del pack si la librería existe, si no clip de Tripo; nadie más elige clips.
3. **Visual** (`FootballerVisual`): marcha por mezcla de velocidad con escala de tiempo = velocidad / velocidad natural interpolada; **una sola** acción puntual a la vez (`play_pack_clip` y `play_action` cancelan la anterior con fundido); acciones recortables (`play_for`).
4. **Contacto pie–pelota** (`BallHandler`): el impulso se aplica **cuando el pie del clip llega a la pelota**, no a un tiempo fijo. Ver [PLAYER](PLAYER.md).

## Trayectoria real de los pies e inventario medido (2026-10-27)

`scripts/animation/foot_trajectory.gd` (`FootTrajectory`) recorre cualquier clip convertido a 60 Hz con `PoseSampler`
(sin render) y mide la punta y el tobillo de cada pie en metros de juego (adelante, arriba, derecha), los **empujes**
(pie bajo, delante del cuerpo y más rápido que él), los apoyos, el alcance, la altura del talón y el giro de la punta;
`dribble_verdict` decide si un clip sirve como conducción en carrera con toques integrados. Coordenadas comprobadas: el
contacto de `Soccer_Pass` medido coincide con el del conversor a 0.000 m. Resultado: **ningún clip del pack cumple**
(`Dribble_2` mueve los pies como un trote). Informe: [ANIMATION_INVENTORY](../ANIMATION_INVENTORY.md) y
[DRIBBLE_DIAGNOSIS](../DRIBBLE_DIAGNOSIS.md). Hoja de un clip convertido sobre nuestro jugador con la trayectoria de los
pies: `CLIP=Dribble_2 VIEW=side OUT=/ruta.png xvfb-run -a godot --rendering-driver opengl3 --path .
res://tools/animation_pack/pack_clip_sheet.tscn`.

## Regenerar las librerías desde los FBX

Las librerías ya están generadas y versionadas. Solo hace falta regenerar si se cambia tools/animation_pack/selection.json (borrado: Mixamo/Mocap) o el conversor, y entonces los FBX originales deben estar en `pack/` (copia local, no versionada):

1. `godot --headless --path . --import` (importa también los FBX de `pack/`, necesarios para el conversor).
2. `python3 tools/animation_pack/make_selection.py` (regenera `selection.json`: 133 clips, roles, trayectorias a medir y estado) y `godot --headless --path . res://tools/animation_pack/build_pack_library.tscn` genera `pack_clips.res` y `pack_keeper.res`. Los mensajes `ERROR: ... still in use at exit` del conversor son avisos del cierre en headless, no del resultado (`error=0` en la línea «CONVERSOR guardado»).
3. Comprobar con `tools/run_tests.sh pack` y `tools/run_tests.sh practice`.

## Archivos responsables

| Ruta | Función |
|---|---|
| tools/animation_pack/pack_retarget.gd (borrado: Mixamo/Mocap) | `PackRetarget`: retarget Y Bot → Tripo respecto al reposo (con espejo izquierdo, calibración de cadera y raíz); lo usa el conversor |
| tools/animation_pack/build_pack_library.gd (borrado: Mixamo/Mocap) / `.tscn` | **Conversor offline** `selection.json` → `pack_clips.res` / `pack_keeper.res` con metadatos medidos (`Animation.get_meta("pack")`) |
| tools/animation_pack/selection.json (borrado: Mixamo/Mocap) / `make_selection.py` | Generado por `make_selection.py`: los 133 clips, bucle/espejo/contacto, trayectorias a medir (`paths`), `role` y `state` (`integrated` = citado por el código de juego / `gallery`) |
| `scripts/animation/pack_library.gd` | `PackLibrary`: carga (opcional) de las librerías locales y acceso a clips y metadatos |
| `scripts/animation/animation_catalog.gd` | `AnimationCatalog`: situación → clip (pack o Tripo), candidatos de patada, mapa del arquero, `step_interval` |
| `scripts/player/footballer_visual.gd` | Marcha por mezcla, acción única, `play_pack_clip`, `play_situation`, tabla de marcha estática |
| tests/test_pack_retarget.gd (borrado: Mixamo/Mocap), test_pack_locomotion.gd (borrado: Mixamo/Mocap), test_pack_kick.gd (borrado: Mixamo/Mocap), *test_pack_dribble_metrics.gd (eliminada en la reforma)*, *test_pack_reactions.gd (eliminada en la reforma)*, `test_pack_motion.gd` | Pruebas del pack (se omiten sin la librería local; `test_pack_motion` además necesita render) |
| tools/animation_pack/pack_metrics.gd (borrado: Mixamo/Mocap) | Métricas de cada clip (pistas, huesos, duración, raíz, cierre de ciclo) del pack y de la biblioteca de Tripo |
| tools/animation_pack/pack_checks.gd (borrado: Mixamo/Mocap) | Compatibilidad: reposo idéntico al del Y Bot, cobertura de los 22 huesos, gemelos `_inplace` |
| tools/animation_pack/pack_rest.gd (borrado: Mixamo/Mocap) | Compara reposo, proporciones y orientación de los dos esqueletos |
| tools/animation_pack/pack_sheet.gd (borrado: Mixamo/Mocap) | Hojas de contacto del clip (pack retargeteado o Tripo) sobre nuestro futbolista (requiere render) |
| tools/animation_pack/pack_foot.gd (borrado: Mixamo/Mocap) | Velocidad, alcance y toques bajos del pie en pases, tiros y conducción (requiere render) |
| tools/animation_pack/pack_library_probe.gd (borrado: Mixamo/Mocap) | Genera librerías de prueba (en un directorio temporal) para medir su tamaño |
| tools/animation_pack/fbx_times.py (borrado: Mixamo/Mocap), `analyze_metrics.py`, `make_report.py` | Duración leída del FBX en bruto; resumen de métricas; genera la tabla de 133 clips |
| tools/animation_pack/evaluation_notes.json (borrado: Mixamo/Mocap) | **Curado a mano:** recomendación, ola y verificación visual de cada clip |
| tools/animation_pack/README.md (borrado: Mixamo/Mocap) | Cómo reproducir (el pack está en `pack/`) |

## Funciones del retarget

tools/animation_pack/pack_retarget.gd (borrado: Mixamo/Mocap): bloque generado quitado.

## Hallazgos verificados (2026-10-26, Godot 4.7.2 en Linux; nada se probó en Android)

| # | Hallazgo | Cómo se comprobó |
|---|---|---|
| 1 | Los 134 FBX importan sin errores con el importador FBX de Godot (≈ 6–9 s en headless). Cada clip trae una animación `mixamo_com`; los huesos se llaman `mixamorig_*`, igual que en Tripo. | `godot --import` + `pack_metrics` |
| 2 | **Esqueleto:** Y Bot = 65 huesos; Tripo = 23. Coinciden por nombre **22** (todos los de Tripo salvo `Root`, que es el padre de `Hips`). Sin equivalente en Tripo: 43 huesos del Y Bot (40 de dedos, `HeadTop_End`, `LeftToe_End`, `RightToe_End`). | `pack_metrics` |
| 3 | **Los 133 clips comparten exactamente el reposo del Y Bot** (peor diferencia 0.04° y 0 m): basta **un solo mapeo**. | `pack_checks` |
| 4 | **Cobertura:** 129 de 133 clips animan los 22 huesos; 4 carecen de pista de los dedos del pie (`Flying_Bicycle_Kick`, `Cheering`, `Clapping`, `Pointing_2`). Pistas por clip (rotaciones + 1 posición de cadera): 118 clips con 53, 10 con 43, 3 con 52, 1 con 51 y 1 con 35 (los que tienen menos pistas omiten dedos); Tripo trae 24 (23 + 1). No hay pistas de escala ni posiciones fuera de la cadera. | `pack_checks`, `pack_metrics` |
| 5 | **Los marcos locales no coinciden:** el Y Bot mira a +Z con brazos en T; Tripo mira a +X con brazos ≈ 11.6° hacia abajo. Giro medio del marco local entre ambos: 21.5° (cadera 85°, hombro derecho 180°); diferencia media de dirección de hueso: 10.1°. **Copiar las rotaciones locales no sirve**; hace falta un retarget respecto al reposo (`PackRetarget`, abajo). | `pack_rest` |
| 6 | **Proporciones (sobre la altura del hueso `Head`):** cadera 0.590 (Tripo) vs 0.623 (Y Bot); pierna 0.566 vs 0.517; brazo 0.457 vs 0.423. Altura de cadera: 0.494 (Tripo, antes de la escala 1.75 del visual) vs 0.998 m (Y Bot): factor de posición 0.495; en velocidades, una carrera del Y Bot equivale a **× 0.867** en nuestro futbolista. | `pack_rest` |
| 7 | **El retarget experimental funciona:** con `D = Pose_Y · Reposo_Y⁻¹`, `Pose_T = A · D · A⁻¹ · Reposo_T` (A = giro de +90° en Y) y la cadera escalada por 0.495, **60 clips** se vieron sobre nuestro futbolista (hojas de contacto de 6 fotogramas) sin torsiones ni colapsos visibles. Defectos observados: el tobillo queda 1.4–6 cm (en juego) por debajo de su reposo en los clips de pie (compensable con un desfase de cadera o IK de pies) y las manos no tienen dedos (la malla de Tripo no los tiene). | `pack_sheet` + mirada de las imágenes |
| 8 | **Las duraciones del índice del pack fallan en 17 de 133 clips** (Godot = FBX en bruto; el índice se equivoca): p. ej. `Two_Cycle_Sprint` dura 1.07 s (índice: 4.4 s), `Strafe_3` 0.67 s (1.67 s), `Defeat` 7.3 s (5.0 s), `Victory` 8.53 s (6.67 s), `soccer_penalty_kick` 1.5 s (1.97 s), `Chip` 1.67 s (1.33 s). Lista completa: las celdas con corchetes en la tabla de 133 clips. | `fbx_times.py` (lee `AnimationCurve/KeyTime` del FBX) |
| 9 | **Raíz:** el índice marca 17 pares «con raíz / `_inplace`» y sus rotaciones coinciden (≤ 0.16°). Pero **`Sprint_inplace.fbx` NO está en el sitio** (3.16 m de raíz, idéntico a `Sprint.fbx`) y **`jog_backward_diagonal_2_inplace.fbx` tampoco** (1.43 m lateral). 43 de los 116 clips que no son `_inplace` tienen más de 0.3 m de raíz y **no tienen gemelo in place** (entre ellos `Dribble_2`, `Chip`, `Soccer_Spin`, `soccer_penalty_kick`, `Idle_To_Sprint`): su raíz hay que quitarla por código. | `pack_metrics`, `pack_checks` |
| 10 | **Los bucles de locomoción cierran sin costura** (0–0.2° de media): `Walking_7`, `Jogging`, `jog_*`, `Running`, `Sprint`, `Strafe_3`, `Two_Cycle_Sprint` (10° máx.). Los de Tripo: `run` 8.7°/28°, `walk` e `idle` 0°. Ninguna acción puntual (caídas, atajadas, giros) cierra, como es esperable. | `pack_metrics` |
| 11 | **Tamaño** (22 huesos + cadera, claves a 30 fps, `.res`): los 133 clips (373 s) = 6.8 MB (5.6 MB con `Animation.optimize`); el conjunto del núcleo propuesto, 68 clips (181 s) = 3.3 MB (2.85 MB optimizado); los 13 de Tripo (66 s) = 0.84 MB. | `pack_library_probe` |
| 12 | **Licencia (README del pack):** las animaciones de Mixamo se pueden usar gratis en juegos, comerciales o no, pero **no se pueden redistribuir sueltas** como pack. Los clips se usan dentro del juego; los FBX sueltos no se suben al repositorio. | README del pack (no se contrastó con los términos de Adobe) |

> Las velocidades naturales de Tripo (`walk` 0.97 m/s, `run` 2.50 m/s) son las documentadas en [ANIMATIONS](ANIMATIONS.md) (medidas con `tools/measure_hips.gd`); **no se volvieron a medir** hoy con el mismo método que el pack. Un estimador alternativo basado en el pie de apoyo dio resultados entre 0.47× y 0.9× la velocidad de raíz real en los pares del pack, por lo que **las velocidades del pack salen de la raíz (distancia/duración), no del pie**.

## Comparativa: los 13 clips de Tripo frente al pack

«Función real» = lo que se vio al reproducirlo sobre nuestro futbolista (6 fotogramas), no lo que sugiere el nombre.

| Clip de Tripo (preset de origen) | Dur. / bucle / costura | Función real observada | Equivalente(s) en el pack (dur., raíz en juego) | Diferencias | Decisión |
|---|---|---|---|---|---|
| `idle` (`idle`) | 15.37 s · bucle · 0° | De pie, casi inmóvil | `offensive_idle` 10.57 s (sin balón), `Soccer_Idle` 6.2 s (con balón); ambos bucle 0° | Postura de fútbol vs neutra | **Pack** (conservar Tripo como respaldo) |
| `walk` (`walk`) | 2.37 s · bucle · 0° · ≈ 1.0 m/s | Caminata natural | `Walking_7_inplace` 1.23 s · bucle · 0.1° · 0.90 m/s | Ciclo más corto | **Pack** |
| `run` (`run`) | 1.27 s · bucle · 8.7°/28° · 2.50 m/s doc. | Carrera inclinada, brazos flexionados | `jog_forward_inplace` 0.83 s (2.15 m/s), `Sprint_inplace` 0.53 s (5.13 m/s), `Two_Cycle_Sprint_inplace` 1.07 s (5.29 m/s) | A 6.8 m/s de sprint: Tripo × 2.7 de cadencia, pack × 1.33 | **Pack** (Tripo `run` se reserva para comparar) |
| `turn` (`turn`) | 3.87 s · una vez · 177° | Giro lento de 180° en el sitio; nada lo dispara | `Sprint_Turn` 1.0 s (giro corriendo), `Soccer_Spin` 1.27 s (ruleta de 360° con balón) | Funciones distintas; el giro lo hace `Locomotion` por código | **Reservar** (sin equivalente directo ni necesidad) |
| `jump` (`jump`) | 2.23 s · una vez | Salto desde agachado | `Jump_4` 2.6 s (en el sitio), `Jumping_Up` 0.83 s, `Jump_2` 1.0 s (corriendo, raíz 3.47 m/s) | El pack trae variantes | **Pack** |
| `fall` (`fall`) | 3.03 s · una vez | Cae hacia delante y queda en el suelo | `Falling_Down` 2.27 s, `Fall_Flat` 2.53 s, `Sweep_Fall` 2.5 s, `soccer_trip` 1.6 s | Más variedad y con `standing_up`/`Getting_Up_3` para levantarse | **Pack** |
| `dive` (`dive`) | 2.73 s · una vez | Plancha **hacia delante** con rodada | `goalkeeper_diving_save` y `_2` (estirada **lateral** izq./der., 3.4/3.23 s; raíz de la estirada 2.8 m) | Dirección distinta: el arquero necesita la lateral | **Pack** para el arquero; Tripo se reserva |
| `celebrate_goal` (`victory_celebration`) | 5.70 s · una vez | De pie, brazos en alto | `Victory` 8.53 s, `Fist_Pump` 3.8 s, `Cheering_2` 1.9 s, `Standing_Fist_Pump` 3.7 s | Más variedad | **Pack** |
| `dejected` (`defeat_02`) | 8.47 s · una vez | Hundido, cabeza atrás | `Defeat` 7.3 s, `Defeat_Idle_2` 1.73 s, `Sad_Idle_3` 4.0 s | Equivalente funcional | **Pack** |
| `frustrated` (`frustrated_01`) | 3.57 s · una vez | Cabeza gacha, gesto de queja | `Angry_Gesture_2` 3.27 s, `Disappointed` 4.2 s | Aproximado (gestos distintos) | **Pack** (verificar el gesto elegido) |
| `keeper_catch_high` (`football_catch`) | 3.47 s · una vez | Salta con los brazos arriba | `goalkeeper_catch_3` (salto corriendo, 2.7 s), `goalkeeper_catch_4` (salto parado, 2.73 s), `goalkeeper_catch_2` (media, 1.27 s) | Más alturas | **Pack** |
| `keeper_scoop_low` (`football_save`) | 3.30 s · una vez | Se agacha y recoge | `goalkeeper_scoop` 2.6 s (raíz 1.31 m/s), `goalkeeper_catch` baja 2.1 s | Equivalente funcional | **Pack** |
| `defensive_stance` (**`football_pass`**) | 11.03 s · bucle · 15°/48° | **No es una postura defensiva ni un pase útil:** de pie con cambios de peso y un gesto de pase lento (velocidad de avance del pie máx. 2.4 m/s; alcance 0.74 m) | Para el pase: `Soccer_Pass` (8.8 m/s), `strike_foward_jog_inplace` (11.8 m/s). Para postura defensiva: **sin equivalente** (`offensive_idle` es ofensivo) | El nombre de nuestra librería es engañoso | **Pase → pack.** Tripo se descarta/renombra |

**Consecuencia para los créditos:** el pack cubre pase, tiro, conducción, desplazamientos y arquero. **No conviene comprar en Tripo** `front_kick_01/02`, `dribble`, `crossover_dribble` ni `shoot` (40–50 créditos de duplicados). Los 13 clips de Tripo ya están pagados; se conservan como respaldo hasta que la migración los reemplace con pruebas en verde.

## Cobertura de las necesidades del núcleo

| Necesidad | Tripo hoy | Pack (clips verificados sobre nuestro futbolista en **negrita**) | Observaciones |
|---|---|---|---|
| Idle | `idle` | **`offensive_idle`**, **`Soccer_Idle`** (con balón), `goalkeeper_idle` | Bucles sin costura |
| Caminar | `walk` | **`Walking_7_inplace`** | 0.90 m/s en juego (el juego camina a 1.8: escala × 2) |
| Trotar | — (solo `run`) | **`jog_forward_inplace`** (2.15 m/s), **`Jogging_inplace`** (1.64 m/s) | |
| Correr | `run` | **`Running_inplace`** (2.14 m/s: igual que el trote) | No aporta una marcha más rápida |
| Sprint | — | **`Sprint_inplace`** (5.13 m/s; **trae raíz**), `Two_Cycle_Sprint_inplace` (5.29 m/s, no visto) | Cubre 5.2–6.8 m/s con × 1.0–1.33 |
| Lateral | — | **`jog_strafe_left_inplace`** (2.50 m/s), **`jog_strafe_right_inplace`** (1.99 m/s), **`Strafe_3_inplace`** (3.14 m/s) | Izquierda y derecha no tienen la misma velocidad natural |
| Atrás y diagonales | — | **`jog_backward_inplace`** (1.98), **`jog_forward_diagonal_inplace`** (2.40) + 3 diagonales no vistas | `jog_backward_diagonal_2_inplace` trae raíz |
| Arranque y giro | — | **`Idle_To_Sprint`**, **`Sprint_Turn`** | No cierran con idle (37° y 60° de costura) |
| Conducción (dribble) | — | **`Dribble_2`** (raíz 2.32 m/s en juego; sin gemelo in place) | El pie se adelanta solo 0.26 m |
| Pase | `defensive_stance` (no útil) | **`Soccer_Pass`** (parado), **`strike_foward_jog_inplace`** (corriendo), **`Chip`** (elevado) | Ver latencia |
| Recepción | — | **`Receive`** (pecho), **`receive_soccerball`** (pie, 5.1 s) | La segunda trae 2.7 m de raíz |
| Tiro | — | **`soccer_penalty_kick`**, **`strike_foward_jog_inplace`** | |
| Arquero | `dive`, `keeper_catch_high`, `keeper_scoop_low` | 23 clips: **estiradas, atajadas, `scoop`, `sidestep`, `body_block`, `drop_kick`, `overhand_throw`, `pass`, `placing_ball`** | Las estiradas y el `sidestep` necesitan su raíz |

## Pie y golpeo: lo que cambia respecto a la patada procedural

> **Integrado** (ver «ANTES y DESPUÉS»): la latencia del clip se **ajusta** acelerándolo hasta ×1.6 y arrancando dentro del clip para llegar al contacto en `kick_latency` = 0.20 s (antes 0.10–0.18 s de la patada procedural): se pierden ≈ 0.05–0.1 s a cambio de un pie que de verdad llega a la pelota. El instante de contacto **no es fijo**: se elige, dentro de la trayectoria medida de la punta del pie (punta a ≤ 0.25 m del suelo y avanzando ≥ 3 m/s), el punto que mejor encaja con la pelota predicha. `soccer_penalty_kick` y `Chip` no se conectan (carrera de 2.5 / 4.4 m). La tabla de abajo es la **evaluación previa** (estimación por velocidad máxima del pie).

El golpeo estimado es el instante de **máxima velocidad de avance del pie** (heurístico: el contacto real habría que marcarlo clip a clip). Medido sobre nuestro esqueleto, en metros de juego:

| Clip | Golpeo (velocidad de avance, instante) | Pie adelante en ese instante | Alcance máximo | Latencia respecto a hoy |
|---|---|---|---|---|
| Patada procedural actual (base idle) | contacto a 0.10 s (pase) / 0.12–0.18 s (tiro) | 0.12 m | 0.43–0.57 m (a +0.16 s del contacto) | — |
| `Soccer_Pass` | 8.8 m/s a 0.47 s | 0.17 m | 0.81 m | +0.37 s |
| `strike_foward_jog_inplace` | 11.8 m/s a 0.43 s | 0.52 m | 0.95 m | +0.25 a +0.33 s |
| `soccer_penalty_kick` | 8.7 m/s a 0.77 s | 0.34 m | 0.65 m | +0.6 s |
| `Chip` | 7.1 m/s a 0.47 s | 0.26 m | 0.59 m | +0.37 s (pase) |
| Tripo `defensive_stance` | 2.4 m/s | 0.29 m | 0.74 m | — (no es un golpeo) |

La patada actual contacta con el pie casi bajo el cuerpo (0.12 m) mientras la pelota está a 0.5–1.2 m (mediciones de línea base abajo). Los clips del pack extienden el pie hasta 0.8–0.95 m, mucho más cerca de esas distancias, pero **tardan 0.43–0.77 s en llegar al golpeo**, frente a 0.10–0.18 s hoy: usarlos tal cual añade 0.25–0.6 s de latencia a pases y tiros. Opciones: acelerar el clip (× 1.5–2), empezar en mitad de la preparación o recortarla; cualquiera exige mezclar desde el clip de locomoción.

## Conducción y pase/tiro: ANTES y DESPUÉS (medido)

Protocolo (*tests/test_pack_dribble_metrics.gd (eliminada en la reforma; en el historial de git)*, permanente): 4 semillas, jugador desde x = −19 m con 50 de atributos, 0.8 s de arranque y 2.7 s de ventana, pelota inicial a 0.7 m. Pase/tiro: 4 semillas × 2 instantes de pulsación (8 intentos por celda).

**Antes** (código original de conducción y patada procedural; medido con el mismo protocolo antes de tocar nada):

| Régimen | Pelota a 0.35–1.5 m | Lejos (> 1.5 m) | Adelante p10 / med / p90 | Lateral med. | Pase/tiro ejecutado (patada procedural) |
|---|---|---|---|---|---|
| Trote 3.6 m/s | 100 % | 0 % | 0.64 / 0.67 / 0.72 m | 0.03 m | 100 % |
| Carrera 5.2 m/s | **36 %** | **64 %** | 0.92 / 1.74 / 2.06 m | 0.24 m | 50 % |
| Sprint 6.8 m/s | **31 %** | **69 %** | 1.02 / 2.82 / 4.85 m | 0.29 m | 25 % |

**Después** (conducción corregida + patada con clip del pack; `PACK`):

| Régimen | Pelota a 0.35–1.5 m | Lejos (> 1.5 m) | Adelante p10 / med / p90 | Lateral med. | Pase / tiro ejecutado | Pie–pelota al golpear (máx / media) | Ajuste de zancada medio | Latencia media |
|---|---|---|---|---|---|---|---|---|
| Trote | 100 % | 0 % | 0.66 / 0.67 / 0.98 m | 0.00 m | 100 % / 100 % | 0.061 / 0.030 m | 0.26 m | 0.20 s |
| Carrera | 100 % | 0 % | 0.90 / 0.99 / 1.12 m | 0.01 m | 100 % / 100 % | 0.119 / 0.060 m | 0.39 m | 0.20 s |
| Sprint | 94 % | 6 % | 1.11 / 1.28 / 1.47 m | 0.02 m | 88 % / 88 % | 0.160 / 0.116 m | 0.47 m | 0.20 s |

- «Ejecutado» = hay evento `PASS`/`SHOT`, que solo se emite con **golpeo válido** (pie del clip a ≤ 0.30 m de la pelota). El resto de las pulsaciones se descartan como `out_of_reach` (no hay ningún pie que llegue) y **no hay pase automático ni teletransporte**. En la fila antigua «ejecutado» incluía patadas cuyo pie quedaba a 0.5–1.2 m de la pelota (el impulso se aplicaba igual).
- **Qué cambió en la conducción** (`BallHandler._try_dribble_touch`; los valores de `PlayerTuning` no se tocaron): (1) el error angular/de módulo del toque se aplica a la velocidad **relativa al jugador** (antes, a la absoluta: 10° a 6.7 m/s mandaban la pelota >2 m al costado); (2) el «toque largo» aleatorio se acota a lo que el siguiente toque alcanza con la pierna estirada (una cola de 2.7 m dejaba la pelota a 6 m); (3) el umbral de re-toque se adapta al hueco planificado; (4) con el pack, la cadencia de toques sigue a los apoyos de la animación (`FootballerVisual.step_interval_for`: uno por apoyo a trote, uno cada dos a carrera/sprint). La fila TRIPO de la prueba ya incluye (1)–(3).
- **Limitación:** la cadencia sigue a la frecuencia de los apoyos pero **no está fijada en fase** al pie que pisa (no se lee la fase del `AnimationTree`). Nunca hubo toques detrás del jugador ni pegados a él (0 % en todas las filas).
- **Limitación:** el ajuste de zancada mueve el cuerpo hasta 0.30 m (+ 0.20 m × ratio de sprint) en la latencia sin pasos animados; es sobre todo **lateral** (el pie de golpeo queda a ≈ 0.25 m del eje) y puede verse como un deslizamiento leve. No se miró en movimiento más allá de un fotograma.

## Incompatibilidades y riesgos

1. **Retarget obligatorio:** marcos locales distintos (hallazgo 5). Sin `PackRetarget` (o un conversor equivalente) los clips salen retorcidos.
2. **Raíz:** 43 clips con raíz y sin gemelo; `Sprint_inplace` y `jog_backward_diagonal_2_inplace` mal etiquetados; las estiradas y el `sidestep` del arquero **pierden su sentido sin su raíz** (hay que impulsar al personaje por código con la distancia medida).
3. **Latencia de los golpeos** (tabla anterior) frente a un control táctil que exige respuesta rápida.
4. **Velocidades naturales vs velocidades del juego:** caminar 0.90 vs 1.8 m/s y trote 2.15 vs 3.6 m/s requieren escalar la cadencia × 1.7–2.0 (el sprint solo × 1.33).
5. **Proporciones:** piernas relativamente más largas y brazos más largos en Tripo → deslizamiento de pies si se conserva la raíz y 1.4–6 cm de penetración de tobillo; conviene bloqueo de pies (IK) o desfase de cadera.
6. **Descripciones del índice poco fiables:** 17 duraciones erróneas, 2 etiquetas «in place» falsas y nombres engañosos (`Sprint_To_Backslide` es una caída, no un frenado; `Defender` termina en una barrida). Las descripciones en español son traducción automática (lo dice el README).
7. **Licencia** (hallazgo 12): uso dentro del juego; los FBX sueltos no se redistribuyen.
8. **Peso:** 2.9–3.3 MB para 68 clips (4× el de Tripo): aceptable, pero hay que medir el tiempo de carga en un móvil real (no se midió).
9. **Dedos:** el pack anima 40 huesos de dedos que la malla de Tripo no tiene (se descartan).

## Propuesta de migración gradual — estado real

Fase 1 (conversor y librería local): **hecha** (`build_pack_library`). Fase 2 (locomoción con respaldo de Tripo): **hecha**. Fase 3 (balón): **hecha en la física** de la conducción; `Dribble_2` como capa de conducción **no** se usa (preparado). Fase 4 (pase/tiro): **hecha** con 2 clips + espejos; penalti y `Chip` pendientes por su raíz. Fase 5 (defensa y caídas): **no conectada** (no hay estado de falta/caída; ver arriba). Fase 6 (arquero): clips **preparados**, sin entidad. Fase 7 (festejos): **hecha** para gol; falta limpiar los clips de Tripo que no tienen disparador. Plan original, conservado como referencia:

Cada fase es independiente, se cierra con pruebas en verde y no cambia la física de la pelota.

| Fase | Contenido | Criterio de aceptación |
|---|---|---|
| 0 (hecha) | Evaluación, herramientas y esta documentación | Hallazgos reproducibles con tools/animation_pack/ (borrado: Mixamo/Mocap) |
| 1 | **Conversor offline** `tools/…/retarget_pack.gd` (a partir de `PackRetarget`): genera una librería nueva en `assets/animations/` (nombre propuesto `pack_clips.res`, aún inexistente) con solo los clips elegidos (núcleo, 22 huesos), cadera calibrada y raíz **separada** (curva de avance guardada aparte, no en la cadera). Decidir la licencia antes de versionar la librería | La librería carga; prueba nueva de pistas y duraciones; tamaño ≤ 3.5 MB |
| 2 | **Locomoción** detrás de un interruptor: `BlendSpace` con idle / caminar / trote / sprint del pack y los laterales; velocidades naturales medidas por clip; los clips de Tripo quedan como respaldo | Error de deslizamiento de pies medido y menor que el de Tripo; cadencia ≤ × 1.7; pruebas `player_model`/`locomotion` en verde |
| 3 | **Balón** (primero física): ver abajo; después `Dribble_2` como capa de conducción con toques en los puntos de apoyo del clip | Criterios de conducción de abajo |
| 4 | **Pase y tiro:** `Soccer_Pass`, `strike_foward_jog_inplace`, `soccer_penalty_kick`, `Chip` con instante de contacto **marcado por clip**; `contact_delay` y el alcance de `BallHandler` leen esos datos; mezcla desde la locomoción; IK ligero solo si el pie queda a más de ≈ 0.2 m de la pelota | Distancia dedos–pelota ≤ 0.20 m en el contacto parado y al trote; latencia ≤ 0.2 s; `kick_timing` y `passing` en verde |
| 5 | **Defensa y caídas** (`soccer_tackle`, `soccer_trip`, caídas, levantarse) conectadas a `TACKLE_WON/TACKLE_FAILED` | Cada clip tiene disparador y prueba |
| 6 | **Arquero** cuando exista la entidad (23 clips; raíz de estiradas por código) | Atajadas con tiros de varias velocidades y esquinas |
| 7 | **Festejos y reacciones** ligados a `GOAL`; limpieza de los clips de Tripo que ya no se usen | Ningún clip sin disparador |

### Conducción: criterios para la fase 3 (física y control, no solo animación)

- **Regla de balón:** tras cada toque, la pelota sale con una velocidad en el sentido del avance **mayor que la del jugador** (nunca vuelve hacia él por el toque) y apunta a un punto objetivo **delante o al costado** según la acción (conducción recta: delante; protección: lateral), entre 0.45 m (no pegada) y ≈ 1.2 m al trote / 1.6 m al sprint.
- **Sincronía:** los toques ocurren en los puntos de apoyo del clip (el pie en su máximo avance con la altura baja); el impulso lo sigue calculando la física con el atributo de control del balón (error angular y de módulo). La animación **no** mueve la pelota.
- **Medidas a mejorar (línea base de arriba):** conducción al sprint de 37 % → ≥ 90 % de las muestras entre 0.35 y 1.5 m; pases y tiros al sprint ejecutados de 19 % → ≥ 85 %; sin muestras detrás ni pegadas en ningún régimen.
- **Cómo:** pruebas permanentes por régimen (trote, carrera, sprint) que midan lo mismo que la tabla; ajustar en `PlayerTuning` (toques de sprint) y en `BallHandler` (ventana de pase/tiro, alcance) con una sola variable cada vez.

## Qué NO se verificó

- **Nada en Android ni en un dispositivo físico:** solo Godot 4.7.2 en Linux (headless y Xvfb con render por software `llvmpipe`). Rendimiento, tiempo de carga y consumo de la librería (`pack_clips.res` 1.9 MB y `pack_keeper.res` 1.5 MB en disco; el del arquero no se carga si nadie lo pide) en móvil: **sin medir**.
- **Movimiento visual:** la verificación en movimiento es **numérica** con el esqueleto vivo (deslizamiento del pie de apoyo y distancia punta-pie↔pelota en el fotograma del impulso, `test_pack_motion`). No se hizo una revisión visual en vídeo; solo hojas de contacto de poses y un fotograma de partido con cámara cenital. Torsiones o transiciones entre clips que no se vean en esas medidas **no se detectaron ni se descartaron**.
- Las transiciones idle ↔ trote ↔ sprint se comprobaron por mezcla y deslizamiento medido, no por mirada; `Idle_To_Sprint` y `Sprint_Turn` no están conectados.
- La posición del pie de contacto sale de los metadatos medidos al convertir (deterministas, iguales en headless y con render); se contrastó con el esqueleto vivo en Xvfb (punta a 0.008 m y 0.026 m del centro de la pelota en el impulso), no en un móvil.
- Los 72 clips no convertidos están evaluados solo por métricas (ver «Visto» en la tabla). Las velocidades de Tripo no se remidieron con el método del pack.
- Arquero: clips convertidos pero **sin probar en juego** (no hay entidad).

## Reproducción

```
unzip futbol.zip -d <dir>; mkdir pack; cp -r <dir>/animaciones <dir>/personaje <dir>/indice_futbol.json pack/
godot --headless --path . --import
godot --headless --path . res://tools/animation_pack/pack_checks.tscn
ANA_OUT=<salida> godot --headless --path . res://tools/animation_pack/pack_metrics.tscn
python3 tools/animation_pack/fbx_times.py pack <salida>/fbx_times.json
python3 tools/animation_pack/analyze_metrics.py <salida>
python3 tools/animation_pack/make_report.py <salida>
```
Las hojas de contacto y las mediciones del pie necesitan render: ver tools/animation_pack/README.md (borrado: Mixamo/Mocap).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Evaluación del pack de animaciones».
