# Integración y comparación: animaciones ACTUALES vs MIXAMO

Pedido del 2026-11-12 («FREE-KICK-SWIPE — INTEGRACIÓN Y COMPARACIÓN DE ANIMACIONES ACTUALES VS MIXAMO», con
`animaciones_mixamo.zip`). Las dos bibliotecas **conviven**: no se borró ni se reemplazó nada del banco actual, los
GLB originales están intactos y la elección se hace en el juego sin recompilar. Tabla clip por clip, correspondencias y
roles sin equivalente: [`INVENTARIO_MIXAMO.md`](INVENTARIO_MIXAMO.md) (generado con los datos medidos).

## 1. Resumen

| Tema | Estado |
|---|---|
| Conversión | Los **133 clips** del ZIP (110 de campo + 23 de arquero) convertidos al esqueleto del juego: 196 con espejos, en 3 bibliotecas derivadas (`mixamo_clips.res`, `mixamo_keeper.res`, `mixamo_scenes.res`). |
| Selector | `AnimBank` (ACTUAL / MIXAMO), guardado en `user://anim_bank.cfg`. Se cambia en el **Laboratorio de animaciones** («Juego: ACTUAL/MIXAMO»). Vale al entrar a un modo. |
| Integración | Por **rol**: con MIXAMO, cada rol que Mixamo tiene usa solo sus clips; los 53 roles que Mixamo no tiene siguen con los actuales (respaldo). Golpeos por **tipo de tiro** y arquero con **respaldo por pelota** (ver 5). |
| Conectadas | Las 196 animaciones las devuelve su rol (prueba `test_every_mixamo_clip_is_reachable_by_its_role`), es decir, las recibe todo sistema que pide ese rol; el laboratorio muestra las 133. |
| Laboratorio | `scenes/dev/anim_lab.tscn` (desarrollo, PC y Android; oculto en la build pública). ACTUAL, MIXAMO o COMPARAR lado a lado con el mismo reloj; 11 categorías; 10 situaciones; reproducir, pausa, reiniciar, bucle, velocidad 0,25/0,5/1/1,5, espejo, vistas; información del clip y mediciones en vivo. |
| Licencia | El repositorio es público: los GLB y las bibliotecas derivadas **no van en claro**. En git va `assets/animations/mixamo_pack.enc` (AES-256); CI lo descifra con el secret `MIXAMO_KEY`. |
| Teléfono | **No probado en el teléfono.** Ver 8. |

## 2. Auditoría del sistema actual (resumen)

- Esqueleto canónico `JsonRig` (23 huesos `mixamorig_*`, pose A, 1,0 = 1,75 m); un solo cuerpo (`json_human.scn`).
- Bibliotecas ACTUALES: `json_clips.res`, `json_keeper.res`, `json_scenes.res`: **2.024 clips** (3.223 con espejos) en
  111 roles, convertidos de JSON de 19 articulaciones con `tools/json_anim/build_json_library.gd`.
- Quién pide clips:
  - `SpClips.by_role`: tirador (espera, carrera), compañeros y defensores, barrera, arquero (espera, levantarse),
    festejos y reacciones, menú, minijuegos (Botón de caída: caídas).
  - `PackLibrary`: planificador del arquero (`KeeperPlanner`) y el modo partido (nombres del paquete de Mixamo viejo
    resueltos por alias).
  - `ShotCatalog`: el golpeo de cada tiro (catálogo medido `shot_clips.json`).

## 3. Esqueletos y retargeting

| | Tripo / Mixamo (ZIP) | Juego (`JsonRig`) |
|---|---|---|
| Huesos | 23, mismos nombres `mixamorig_*`, `Armature/Skeleton3D`, transformada identidad | 23 |
| Reposo | Pose T | Pose A |
| Pierna (cadera → tobillo) | 0,840 m | 0,759 m |
| Tobillo en reposo | 3,2 cm del piso | 9,5 cm |
| Punta del pie | Origen de `ToeBase` a ~5 cm del tobillo | 18 cm |
| Antebrazo | 0,214 m | 0,325 m |
| Pistas | Posición de `Hips` + 22 rotaciones, `loop_mode` 0 | — |
| Raíz | **Ningún clip trae desplazamiento** (la cadera queda fija en horizontal, aunque el LEEME dice lo contrario) | `root_path` medido |

Compatibilidad: mismos nombres de huesos, pero **proporciones distintas**: aplicar las rotaciones tal cual dejaba los
pies hundidos (~7 cm) y las rodillas estiradas. Retargeting, con recursos derivados (los GLB no se tocan):

1. `tools/mixamo/export_mixamo_joints.gd`: cinemática directa de cada clip a 60 fps sobre el esqueleto de Tripo y
   **transferencia de proporciones**: cada segmento conserva la DIRECCIÓN de Tripo con la LONGITUD del juego; la punta
   sale de la orientación del hueso `Foot`; la altura de la pelvis fija el tobillo más bajo a la altura del tobillo del
   juego (con la escala de la pierna, 0,903). Resultado: el pie apoyado queda entre −2,4 y +1,3 cm en casi todos los
   clips (antes −7 cm).
2. **Raíz reconstruida** (57 clips de desplazamiento): el pie de apoyo queda fijo en el suelo; al cambiar de apoyo, el pie
   nuevo solo se acepta si la velocidad que implica va hacia el mismo lado que la del cuerpo (menos de 75°), y en el aire
   se usa la velocidad media del último apoyo. Las variantes `_inplace` toman la velocidad de su gemela. Medido:
   caminata 1,0 m/s, trote 2,0, carrera 2,2, sprint 5,0–5,1, trote atrás 1,85, lateral 2,2–2,4; penal con 2,6 m de carrera.
3. **Contacto de los golpeos**: el pie que patea y el instante salen de la mayor velocidad de avance de la punta con la
   punta baja (en la chilena, la mayor rapidez en cualquier dirección).
4. El convertidor de siempre (`tools/json_anim/build_json_library.gd`, `JsonRetarget`) arma las bibliotecas y mide raíz,
   rumbo, contacto, trayectorias de manos y pies y velocidad natural con el mismo código que el banco actual.

## 4. Correspondencias (criterio)

Cada clip se asignó a un rol mirando el movimiento (no el nombre). La tabla completa, con los clips de cada rol y quién
los usa, está en [`INVENTARIO_MIXAMO.md`](INVENTARIO_MIXAMO.md), sección 2. Criterios por grupo:

- **Golpeos**:
  - `Soccer_Penalty_Kick` → `setpiece_shot`: carrera, apoyo y golpe a la pelota quieta.
  - `Chip` → `setpiece_lob`: pie por debajo de la pelota.
  - `strike_foward_jog` → `setpiece_pass` (con raíz) y `kick_shot` (en el sitio).
  - `Soccer_Pass` → `kick_pass` (interior).
  - `kick_soccerball` → `kick_shot`; `kick_soccerball_2` → `kick_shot_hard` (golpe seco sin carrera).
  - Chilena y tijera → `volley`.
- **Arquero**:
  - Estiradas → `gk_dive`; blocajes → `gk_catch`; recogidas → `gk_scoop`; achiques con el cuerpo → `gk_block`.
  - Pasos laterales → `gk_sidestep`; espera → `gk_idle`; espera con la pelota → `gk_idle_ball`; vencido → `gk_miss`.
  - Saques: con la mano → `gk_throw`, rodando → `gk_roll`, de volea → `gk_kick`, de piso → `gk_place`, indicando → `gk_direct`.
- **Locomoción**:
  - Caminar, trotar, correr y sprint, cada uno con su rol.
  - Marchas atrás, diagonales y laterales → `dir_*`.
  - Arranque → `start`; giro en carrera → `turn_run`.
- **Contacto**:
  - Barridas → `slide`; zancadilla → `trip`; tropiezos → `stumble` / `stumble_light`.
  - Caídas → `fall` / `fall_hit`; en el suelo → `lie`; levantarse → `getup`; empujones → `shove`.
- **Balón**:
  - Conducción → `ball_dribble`; giro con pelota → `ball_turn`; jueguitos y dominio → `ball_skill`.
  - Recepciones → `receive_chest` / `receive_foot`; cabezazos → `header`; lateral → `throw_in`.
- **Reacciones y festejos**: según el gesto (enojo, lamento, derrota, festejo del goleador o del equipo, aplauso,
  pulgar, salto, precalentamiento).
- **Árbitro**: «Counting» y «Pointing_Forward» → `referee`.
- **Rol nuevo**: `defend` (Defender, Defender_2: marca con desplazamiento).

## 5. Integración por sistema

| Sistema | Con MIXAMO |
|---|---|
| `SpClips` (penales, tiros libres, arquero, festejos, reacciones, menú, minijuegos) | Carga las bibliotecas de Mixamo y las actuales; `by_role` devuelve solo Mixamo en los roles que Mixamo tiene; `fallback_roles()` lista los 53 que siguen con el actual. Con ACTUAL no carga nada de Mixamo. |
| `PackLibrary` (arquero, modo partido) | Mismo criterio por rol en copias de las bibliotecas (no en las compartidas). Los nombres del paquete que pide el código («goalkeeper_catch», «Soccer_Pass»...) van al clip de Mixamo de ese nombre; si no existe, a uno del mismo rol. |
| `ShotCatalog` (golpeo de cada tiro) | Catálogo medido aparte (`shot_clips_mixamo.json`, 14 golpeos de Mixamo). Por TIPO de tiro: potente, normal, colocado y vaselina usan solo Mixamo; el tiro errado (`setpiece_miss`) sigue con el actual (Mixamo no tiene). |
| `KeeperPlanner` (atajadas) | Primero las atajadas de Mixamo; si ninguna llega con holgura a esa pelota, la actual (respaldo). Sin el respaldo el arquero atajaba ~20 % menos (ver 7). |
| `SpFieldPlayers` (tiro libre) | Defensores: llegan a su puesto con el clip de marca `defend` (enmarcado para terminar en el puesto, sin patinar) y, al patear, retroceden mirando la pelota con la marcha direccional que corresponde (`dir_back`, diagonales, lateral). La marcha direccional vale en las dos bibliotecas (las dos tienen esos roles). |
| `SpShooter._loop_for` (marchas) | Con MIXAMO suma la carrera y el sprint de Mixamo y prefiere sus clips (el trote de Mixamo llega a 2 m/s). Con ACTUAL, igual que antes. |
| Menú | Botón «Laboratorio de animaciones» (solo con herramientas de desarrollo). |

Situaciones del juego que hoy no existen en penales y tiros libres (laterales, conducción, recepciones, barridas, árbitro,
saques del arquero): sus clips de Mixamo los usa el modo partido a través de `PackLibrary` y se ven en el laboratorio.

## 6. Laboratorio de animaciones

- **Dónde está**: `scripts/dev/anim_lab.gd` y `scenes/dev/anim_lab.tscn`. Entrada desde el menú, solo en builds con
  herramientas de desarrollo (`DevFlags`).
- **Modos**:
  - ACTUAL, MIXAMO o COMPARAR.
  - Cada estación carga solo las bibliotecas de su biblioteca de animaciones.
  - Al salir de COMPARAR se libera la otra.
- **Categorías**: Jugador, Arquero, Locomoción, Disparos, Pases, Conducción, Defensa, Caídas, Recuperación,
  Celebraciones y Reacciones (por rol).
- **Situaciones**: penal, tiro libre, atajada, disparo potente, pase, conducción, carrera, caída, recuperación y
  celebración.
  - Elige la misma acción en las dos bibliotecas.
  - Los golpeos se alinean para que las dos pelotas se golpeen en el mismo instante.
  - Igual en las dos: cuerpo, cámara, velocidad y pelota.
- **Controles**:
  - ◀/▶ por biblioteca, Pausa/Reproducir, Reiniciar, Bucle.
  - Velocidad 0,25 / 0,5 / 1 / 1,5, Espejo, Vista (diagonal, frente, atrás, lateral).
  - «Juego: ACTUAL/MIXAMO»: elige la biblioteca del juego.
  - «Penal en el juego» y «Tiro libre en el juego»: la situación real con esa biblioteca.
- **Información del clip**:
  - Nombre, nombre original, biblioteca, categoría y rol, duración, bucle.
  - Esqueleto y pistas válidas, retargeting, raíz, estado en el juego (en uso / respaldo / reemplazado).
- **Mediciones**: contacto (instante, pie, distancia punta–pelota), altura mínima de los pies y deslizamiento del pie
  apoyado.
- **Capturas con render**: `tools/mixamo/lab_capture.tscn`.

## 7. Problemas e incompatibilidades encontrados

1. **Sin raíz en el paquete**: reconstruida (sección 3). En clips con poco apoyo detectado la raíz es una estimación:
   - Defender: 8 % de apoyo.
   - soccer_tackle: 9 %.
   - soccer_trip: 1 %.
   - Fall_Flat, Sweep_Fall y Sprint_To_Backslide: 4–11 %.
   - Ahí puede verse algo de deslizamiento: el laboratorio lo mide.
2. **Pies**: −2,4 a +1,3 cm en casi todos los clips. Excepciones:
   - Barridas y zancadilla: −4 a −10 cm, con el pie de costado en el suelo.
   - Defender: −7,3 cm.
   - Chilena: todo en el aire (+56 cm).
3. **Variedad de golpeos**: Mixamo trae 7 golpeos (14 con espejos) en el catálogo, contra 280 (560 con espejos) del catálogo actual.
   - Sin golpeos de exterior.
   - Pocos ángulos y pocos golpeos potentes.
   - Con ANIM_BANK=mixamo fallan 2 pruebas de calidad de `test_setpiece_modes` (con ACTUAL pasan). Salida real:
     - `test_foot_surface_follows_the_shot`: «hay golpeos de exterior».
     - `test_kick_choice_follows_the_direction_of_the_shot`: «el tiro potente usa un golpeo potente», «el golpeo cruzado
       sale con el ángulo pedido», «familia POWER con golpeos», «familia CHIP con golpeos».
   - Es un límite del paquete, no de la integración.
4. **Arquero**: con solo las atajadas de Mixamo (12 clips) el arquero atajaba menos.
   - `test_shot_keeper`, 11 m centrado con el joystick al arquero: 88 % con ACTUAL y 68 % con Mixamo solo.
   - Con el respaldo por pelota vuelve a 86 %, y la batería del arquero pasa entera.
   - En la grilla de 28 penales de `test_mixamo_bank`, las dos llegan a 26: con MIXAMO, 16 con estiradas de Mixamo y 8 con
     respaldo actual.
5. **Velocidad natural**: el banco actual la trae del dato `ground_speed` de los JSON. Para Mixamo se calcula desde la
   raíz reconstruida; sin eso, la marcha de los jugadores en MIXAMO no tenía velocidad.
6. **Chilena**: el contacto es por arriba y hacia atrás; el refinado del convertidor no mide velocidad de avance (v = 0).
   Solo la usa el rol `volley` (modo partido) y el laboratorio.
7. **Clips largos de escena** (Angry 19 s, Counting 14 s, Arm_Stretching 9 s): se usan enteros en reacciones; el
   laboratorio los muestra completos.

## 8. Pruebas

Con las bibliotecas de Mixamo presentes.

**PC (este entorno, Godot 4.7.2 headless)**:
- `tests/test_mixamo_bank.gd`: 9 pruebas, 178 comprobaciones, todas OK.
  - ACTUAL no carga nada de Mixamo.
  - Los 196 clips cargan con rol, duración y pistas sobre los 23 huesos.
  - Mixamo por rol, con el respaldo actual.
  - Los 196 los devuelve su rol.
  - Catálogo de golpeos por tipo, con la punta baja en el contacto.
  - Arquero: Mixamo primero y respaldo.
  - El laboratorio carga solo lo que muestra; penal comparado, pausa y velocidad.
  - Cambio de biblioteca en tiempo de ejecución con un penal.
  - Marchas direccionales y de carrera de Mixamo.
- Penales y tiros libres (`setpiece`):
  - ACTUAL: 15/15.
  - MIXAMO: 13/15; las 2 fallas son las del punto 7.3.
- Arquero (`keeper`): 17 pruebas en ACTUAL y en MIXAMO, 0 fallidas, 3 omitidas en headless.

**PC con render (xvfb + opengl3)**:
- `test_keeper_zones` en ACTUAL: 4/4. Las demás corridas con render están en el CHANGELOG.

**CI**: corre la suite completa.
- Sin el secret `MIXAMO_KEY`, las pruebas que necesitan Mixamo se omiten.
- Con el secret, se descifra la biblioteca y se prueban.

**Android físico**: **no probado.** Falta probar en el ZTE V60:
- el laboratorio;
- el cambio de biblioteca;
- penales y tiros libres con MIXAMO.

## 9. Rendimiento (Android: ZTE V60 / Mali-G57)

- Peso: las bibliotecas de Mixamo pesan 3,6 MB (`.res`); el paquete cifrado, 2,4 MB.
- Carga:
  - Con ACTUAL (por defecto) no se cargan.
  - Con MIXAMO se cargan además de las actuales, que hacen falta como respaldo de 53 roles.
  - El laboratorio carga solo lo que muestra.
- Medición: **no se midió en el teléfono** (memoria, tiempo de carga y FPS con MIXAMO). Queda como pendiente.

## 10. Entrega a CI (licencia)

- `tools/mixamo/pack_mixamo.sh encrypt|decrypt`: tar + AES-256-CBC con PBKDF2 (200.000 iteraciones). Clave en
  `MIXAMO_KEY` o `MIXAMO_KEY_FILE`; nunca en el repositorio, el chat ni los registros.
- Workflow, paso «Biblioteca MIXAMO (paquete cifrado, opcional)»:
  - Con el secret, descifra.
  - Sin el secret, avisa y la APK sale sin MIXAMO.
  - La verificación de la APK exige las cuatro piezas cuando se descifraron y prohíbe el `.enc` y las fuentes.
- **Para activarlo**: crear el secret `MIXAMO_KEY` en GitHub (Settings → Secrets and variables → Actions) con la clave
  que se entregó aparte.

## 11. Decisiones pendientes (del usuario)

1. Si se reemplaza el banco actual, por rol o por sistema. Hoy conviven y el juego arranca en ACTUAL.
2. Si la build pública debe traer MIXAMO (hoy la trae si CI tiene el secret, pero el selector solo está en el laboratorio).
3. Cifrado en el repositorio público, o volverlo privado.
4. Si se quieren más golpeos o atajadas de Mixamo para cubrir lo que falta: exterior, ángulos, potentes, tiros errados.
5. Revisar en el teléfono los clips con raíz estimada (punto 7.1).

## 12. Reconstrucción (comandos)

```
J=<carpeta temporal>; R=<carpeta de informe>
MIXAMO_JSON=$J godot --headless --path . res://tools/mixamo/export_mixamo_joints.tscn
JSON_SRC=$J SELECTION=res://tools/mixamo/selection_mixamo.json OUT_FIELD=res://assets/animations/mixamo_clips.res \
  OUT_KEEPER=res://assets/animations/mixamo_keeper.res OUT_SCENES=res://assets/animations/mixamo_scenes.res OUT=$R \
  godot --headless --path . res://tools/json_anim/build_json_library.tscn
ANIM_BANK=mixamo godot --headless --path . res://tools/setpiece/build_shot_catalog.tscn
MIXAMO_KEY_FILE=<clave> tools/mixamo/pack_mixamo.sh encrypt
INV_BANK=mixamo INV_OUT=$R/inv_mixamo.json godot --headless --path . res://tools/mixamo/dump_inventory.tscn   # (y actual)
python3 tools/mixamo/make_inventory_doc.py --sel tools/mixamo/selection_mixamo.json --index $J/index.json \
  --build $R/build.log --actual $R/inv_actual.json --mixamo $R/inv_mixamo.json --out docs/animaciones/INVENTARIO_MIXAMO.md
```
