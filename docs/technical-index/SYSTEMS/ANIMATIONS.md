# ANIMATIONS — Modelo, esqueleto, clips, kit y patada procedural

## Identificación

- **Responsabilidad exacta:** presentar al futbolista: cargar el modelo de Tripo3D (`player_base.glb`, esqueleto único v1.0 de 23 huesos `mixamorig_*`), recolorearlo por regiones (camiseta, short, medias, botines, piel, pelo), animarlo con un `AnimationTree` (locomoción mezclada por velocidad + acciones de una sola vez) y superponer la patada **procedural** (los clips de Tripo no traen patadas).
- **Estado:** modelo, locomoción (idle/walk/run), kit y patada procedural **implementados y probados**. **Desde la integración del pack** (ver [ANIMATION_PACK](ANIMATION_PACK.md)) el visual usa, si existe la librería local `pack_clips.res`, los clips de Mixamo para la marcha, la patada con contacto por pie, la recepción y las reacciones de gol; los clips de Tripo y la patada procedural son el **respaldo** (sin la librería, o con `FootballerVisual.prefer_pack = false`). Las 9 acciones (`celebrate_goal`, `dejected`, `frustrated`, `jump`, `turn`, `fall`, `dive`, `keeper_catch_high`, `keeper_scoop_low`) **existen en el árbol pero nada en el juego las dispara todavía** (no hay ningún llamador de `FootballerVisual.play_action` en `scripts/`). El clip `defensive_stance` está en la librería pero **no está conectado** al árbol.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-10
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/player/footballer_visual.gd` | Clase `FootballerVisual` (`Node3D`): carga el modelo, aplica el kit, construye el `AnimationTree`, `play_action`, `update_motion` (cadencia + inclinación), maniquí provisional si falta el modelo | `FootballerVisual.build`, `FootballerVisual._setup_animation_tree`, `FootballerVisual.update_motion`, `FootballerVisual.play_action`, `FootballerVisual.default_kit`, `FootballerVisual.keeper_kit` | `ProceduralPose`, `Footballer` (recibe `locomotion`) |
| `scripts/animation/animation_catalog.gd`, `scripts/animation/pack_library.gd` | Catálogo único situación → clip (pack o Tripo) y carga de la librería local del pack | `AnimationCatalog.resolve`, `AnimationCatalog.kick_candidates`, `PackLibrary.clip`, `PackLibrary.meta` | assets/animations/pack_clips.res (borrado: Mixamo/Mocap) (local, restringida) |
| `scripts/animation/procedural_pose.gd` | `ProceduralPose` (`SkeletonModifier3D`): patada con fases (balanceo → golpeo en `contact_time` → continuación → recuperación) e inclinación del tronco (`lean_pitch`, `lean_roll`, repartida por la columna) aplicadas **después** del árbol | `ProceduralPose.start_kick`, `ProceduralPose.kick_angles`, `ProceduralPose.envelope`, `ProceduralPose.apply_at`, `ProceduralPose._apply_lean` | `Skeleton3D` (huesos `mixamorig_*`) |
| `scripts/animation/pose_sampler.gd` | `PoseSampler`: evalúa una `Animation` sobre un esqueleto sin `AnimationPlayer` (herramientas y pruebas) | `PoseSampler.bind`, `PoseSampler.apply`, `PoseSampler.bone_in_skeleton` | — |
| `assets/characters/player/player_base.glb` | Malla (7640 triángulos medidos) + esqueleto v1.0 | — | — |
| `assets/characters/player/player_kit.gdshader` | Shader de recoloreado por regiones (conserva el sombreado por luminancia relativa) | uniforms `jersey_color`, `shorts_color`, `socks_color`, `boots_color`, `skin_color`, `hair_color`, `mask_a`, `mask_b` | máscaras `player_mask_a.png`, `player_mask_b.png`, `player_albedo.jpg`, `player_regions.json` |
| `assets/animations/footballer_clips.res` | `AnimationLibrary` compartida con 13 clips (binario, generado) | — | generada por `tools/build_animation_library.gd` desde `assets/animations/source/*.glb` |
| `tools/build_animation_library.gd` | Reconstruye la librería: renombra clips, **centra la cadera** (los clips traen desfases de hasta ~0.9 m), fija bucles | `SOURCES`, `LOOPING`, `HIPS_BONE`, `HORIZONTAL_AXES` | `assets/animations/source/` |

**No modificar para cambiar la animación:** la lógica de gameplay (`BallHandler`, `Locomotion`); solo comunican velocidad y tiempo de contacto. **Quién llama:** `Footballer._physics_process` (→ `update_motion`) y `BallHandler.request_kick` (→ `start_kick`).

## Mapa de parámetros

Esta capa **no usa recursos de parámetros**: todo son constantes del código (ver «Valores fijos»). `Tuning` no contiene valores de animación.

<!-- AUTO:consts:scripts/player/footballer_visual.gd -->
| Constante / enum / uniform | Valor | Línea | Descripción |
|---|---|---|---|
| `FootballerVisual.MODEL_PATH` | `"res://assets/characters/player/player_base.glb"` | 10 | Presentacion del futbolista: modelo de Tripo3D (malla + esqueleto de 23 huesos) con material de equipamiento recoloreable, AnimationTree (locomocion mezclada por velocidad + acciones puntuales) y una capa procedural (patadas, torso, mirada) aplicada despues de la animacion. Las animaciones vienen de una libreria compartida (assets/animations/footballer_clips.res): todos los jugadores y arqueros usan el MISMO esqueleto, asi cada clip sirve para todos. Si el modelo no se puede cargar, usa un maniqui provisional para no romper el juego. |
| `FootballerVisual.CLIPS_PATH` | `"res://assets/animations/footballer_clips.res"` | 11 |  |
| `FootballerVisual.KIT_SHADER` | `preload("res://assets/characters/player/player_kit.gdshader")` | 12 |  |
| `FootballerVisual.ALBEDO_PATH` | `"res://assets/characters/player/player_albedo.jpg"` | 13 |  |
| `FootballerVisual.MASK_A_PATH` | `"res://assets/characters/player/player_mask_a.png"` | 14 |  |
| `FootballerVisual.MASK_B_PATH` | `"res://assets/characters/player/player_mask_b.png"` | 15 |  |
| `FootballerVisual.MODEL_HEIGHT_SCALE` | `1.75` | 17 | El modelo de Tripo mide 1.0 unidad de alto; el jugador real mide ~1.75 m. |
| `FootballerVisual.MODEL_YAW` | `PI * 0.5` | 19 | El modelo de Tripo mira hacia +X; el juego usa -Z como "adelante". |
| `FootballerVisual.NATURAL_SPEED` | `{"walk": 0.97, "run": 2.50}` | 22 | Velocidad natural (m/s reales) de cada ciclo, medida con tools/measure_hips.gd. |
| `FootballerVisual.MAX_TIME_SCALE` | `2.9` | 23 |  |
| `FootballerVisual.MIN_TIME_SCALE` | `0.6` | 24 |  |
| `FootballerVisual.ACTION_CLIPS` | `[&"celebrate_goal", &"dejected", &"frustrated", &"jump", &"turn", &"fall", &"...` | 26 | Clips de accion (una sola vez) que se pueden disparar con play_action(). |
| `FootballerVisual.PACK_LIB` | `&"pack"` | 32 |  |
| `FootballerVisual.PACK_GAIT_CLIPS` | `[&"offensive_idle", &"Walking_7_inplace", &"Jogging_inplace", &"jog_forward_i...` | 35 | Marcha del pack: clips que se mezclan segun la velocidad. La posicion en el BlendSpace ES la velocidad natural medida de cada clip, asi que a esa velocidad se reproduce a ritmo 1.0 (sin patinar) y entre dos clips se mezclan. |
| `FootballerVisual.PACK_GAIT_POINTS` | `[[&"offensive_idle", 0.0], [&"Walking_7_inplace", -1.0], [&"Jogging_inplace",...` | 41 | Puntos del BlendSpace de la marcha del pack: [clip, posicion (m/s)]. El trote se repite en una posicion mas alta: entre ambos se reproduce SOLO el trote (a mayor cadencia) y la mezcla con el sprint empieza despues, en vez de mezclar dos zancadas distintas durante todo el tramo intermedio. Entre la caminata y el trote va el trote lento (Jogging_inplace, 1.64 m/s): el paso de caminar a trotar ya no mezcla dos zancadas muy distintas. |
| `FootballerVisual.DIR_POINTS` | `[ [&"jog_forward_inplace", 0.0, 1.0], [&"jog_backward_inplace", 0.0, -1.0], [...` | 45 | Mezcla direccional de 8 sentidos (arquero y defensa: el cuerpo mira a un punto y se mueve en cualquier direccion). Posicion en el BlendSpace2D: x = derecha, y = adelante; los clips cardinales estan a distancia 1. |
| `FootballerVisual.DIR_MAX` | `1.4` | 54 | Limite de la mezcla direccional (el lateral rapido esta a 1.36). |
| `FootballerVisual.STRAFE_FAST_SPEED` | `3.14` | 55 |  |
| `FootballerVisual.TWIN_GAIT_POINTS` | `[[&"offensive_idle", 0.0], [&"Walking_7", -1.0], [&"Jogging", -1.0], [&"Runni...` | 58 | Arbitro: usa los GEMELOS CON RAIZ de la marcha (misma pose que los _inplace; su desplazamiento de raiz medido es el que mueve al cuerpo, ver Referee). Marcha y mezcla direccional con esos clips. |
| `FootballerVisual.TWIN_DIR_POINTS` | `[ [&"jog_forward", 0.0, 1.0], [&"jog_backward", 0.0, -1.0], [&"jog_strafe_lef...` | 59 |  |
| `FootballerVisual.DIR_REF_SPEED` | `2.3` | 68 | Velocidad (m/s) a la que la mezcla direccional esta en su radio 1 (velocidad natural media de esos clips). |
| `FootballerVisual.CARRY_GAIT_POINTS` | `[[&"Soccer_Idle", 0.0], [&"Dribble_2", -1.0], [&"Running_inplace", 3.6], [&"T...` | 74 | Marcha CON la pelota: mismos tramos que la marcha normal pero con los clips de conduccion (el jugador mira la pelota, da zancadas mas cortas y mueve los brazos distinto). Se mezcla con la marcha normal segun la posesion. Con la pelota la carrera usa Running_inplace (braceo distinto al trote sin pelota) y el sprint, Two_Cycle_Sprint_inplace (dos zancadas por ciclo: la conduccion larga a toda velocidad). |
| `FootballerVisual.CARRY_BLEND_RATE` | `4.0` | 76 | Velocidad (m/s) con la que la mezcla de conduccion llega a su peso maximo al recuperar la pelota. |
| `FootballerVisual.TOUCH_LEG_BONES` | `{ 0: [&"mixamorig_LeftUpLeg", &"mixamorig_LeftLeg", &"mixamorig_LeftFoot", &"...` | 121 |  |
| `FootballerVisual.LEAN_TURN_GAIN` | `0.75` | 138 | Inclinacion del tronco hacia dentro de la curva: fraccion de la fisica (tan = v * giro / g) y maximo (rad). La del cuerpo entero es ~1/20 de la fisica (2 grados a 6 m/s girando 1 rad/s): no se veia. |
| `FootballerVisual.LEAN_ROLL_MAX` | `0.38` | 139 |  |
| `FootballerVisual.LEAN_ACCEL_MAX` | `0.18` | 141 | Inclinacion maxima del tronco (rad) hacia delante al acelerar y hacia atras al frenar. |
| `FootballerVisual.LEAN_BRAKE_MAX` | `0.1` | 142 |  |
| `FootballerVisual.CARRY_CROUCH` | `0.13` | 145 | Control cerrado: llevando la pelota despacio el tronco se encorva sobre ella (como en First Touch Soccer), hasta CARRY_CROUCH rad entre caminar y trotar; parado o a la carrera, nada. |
| `FootballerVisual.GAIT_CYCLES` | `{&"Jogging_inplace": 3, &"Jogging": 3, &"Two_Cycle_Sprint_inplace": 2, &"Two_...` | 448 | Ciclos de zancada (dos apoyos) que contiene cada clip de marcha. Casi todos son de un ciclo; el trote lento (Jogging_inplace, 2.57 s) trae tres y Two_Cycle_Sprint dos (contados en las punta de pie del clip). |
| `FootballerVisual.P_LOCO` | `&"parameters/Locomotion/blend_position"` | 609 | Llamado cada paso de fisica por el futbolista. Parametros del AnimationTree que se fijan en cada imagen (drive_motion): nombres ya convertidos y valor escrito por ultima vez. Escribir un parametro por su texto en cada imagen costaba ~0.05 ms por jugador (tools/perf_probe); ahora solo se escribe cuando cambia (el AnimationTree conserva el ultimo valor). |
| `FootballerVisual.P_LOCO_SCALE` | `&"parameters/LocoScale/scale"` | 610 |  |
| `FootballerVisual.P_CARRY_MIX` | `&"parameters/CarryMix/blend_amount"` | 611 |  |
| `FootballerVisual.P_CARRY` | `&"parameters/Carry/blend_position"` | 612 |  |
| `FootballerVisual.P_CARRY_SCALE` | `&"parameters/CarryScale/scale"` | 613 |  |
| `FootballerVisual.P_TOUCH_SCALE` | `[&"parameters/TouchScale0/scale", &"parameters/TouchScale1/scale"]` | 614 |  |
| `FootballerVisual.P_MODE_MIX` | `&"parameters/ModeMix/blend_amount"` | 615 |  |
| `FootballerVisual.P_DIR` | `&"parameters/Dir/blend_position"` | 616 |  |
| `FootballerVisual.P_DIR_SCALE` | `&"parameters/DirScale/scale"` | 617 |  |
<!-- /AUTO -->

<!-- AUTO:consts:scripts/animation/procedural_pose.gd -->
| Constante / enum / uniform | Valor | Línea | Descripción |
|---|---|---|---|
| `ProceduralPose.LATERAL` | `Vector3(0, 0, 1)` | 11 | Capa de animacion PROCEDURAL aplicada despues del AnimationTree (los clips de Tripo no incluyen patadas). Hoy implementa la patada (pase / tiro) con fases: balanceo hacia atras -> golpeo en el instante de contacto -> continuacion -> recuperacion. El contacto ocurre exactamente en contact_time desde start_kick(), y es el momento en el que BallHandler aplica el impulso a la pelota (sincronia cuerpo-pelota).  Convencion del esqueleto (espacio del Skeleton3D, sin rotacion en el GLB): adelante = +X, arriba = +Y, lateral = Z. Una rotacion POSITIVA alrededor de +Z balancea una pierna hacia ADELANTE. |
| `ProceduralPose.FOLLOW_THROUGH` | `0.16` | 12 |  |
| `ProceduralPose.RECOVERY` | `0.32` | 13 |  |
| `ProceduralPose.LEAN_SHARE` | `[0.4, 0.3, 0.3]` | 29 |  |
| `ProceduralPose.FORWARD` | `Vector3(1, 0, 0)` | 30 |  |
<!-- /AUTO -->

### Riesgos al modificar

| Valor | Efecto real y riesgo |
|---|---|
| `NATURAL_SPEED` (`walk` 0.97, `run` 2.50 m/s) | Medidos con `tools/measure_hips.gd`. Determinan la cadencia (`update_motion`). Si se cambia el clip o la escala del modelo hay que volver a medirlos o los pies patinan. |
| `MAX_TIME_SCALE` 2.9 / `MIN_TIME_SCALE` 0.6 | Tope de cadencia. `2.9 × 2.50 = 7.25 m/s`: por encima de esa velocidad real los pies patinan (la velocidad de sprint por defecto es 6.8 m/s; los atributos pueden subirla). test_animation_tree_responds_to_speed (borrado: Mixamo/Mocap) exige escala > 1 y ≤ `MAX_TIME_SCALE`. |
| `MODEL_HEIGHT_SCALE` 1.75, `MODEL_YAW` π/2 | El GLB mide 1.0 de alto y mira a +X. Cambiarlos desalinea modelo, cápsula (`PlayerTuning.capsule_*`) y orientación; no hay prueba que mida la altura del modelo. |
| Puntos del `BlendSpace1D` | Se calculan en `_setup_animation_tree`: `idle` 0, `walk` 0.97·1.15, `run` 2.5·1.6, rango 0–7.5. |
| `ProceduralPose.FOLLOW_THROUGH` 0.16 s, `RECOVERY` 0.32 s | Duración total de la patada = `contact_time + 0.48 s`. `test_pose_curves_are_continuous_and_peak_at_contact` vigila que las curvas sean continuas (salto por muestra < 0.06 rad, velocidad angular < 60 rad/s; medido 49.9 rad/s). |
| Amplitudes en `kick_angles` | `back = 0.55 + 0.45·potencia`, `knee_bend = 0.95 + 0.6·potencia`, `follow = 0.42 + 0.3·potencia`; el tramo previo al golpe dura `0.62·contact`. Más amplitud = pierna que atraviesa el cuerpo. |
| Fundidos `fadein_time 0.12 s` / `fadeout_time 0.2 s` | Solo en `_setup_animation_tree` (acciones `OneShot`). |
| Inclinación (`speed/7 · 0.12` rad hacia delante; alabeo `turn_rate·speed·0.0042` limitado a ±0.28; suavizado `1 − e^(−10Δt)`) | Solo cosmético; test_animation_tree_responds_to_speed (borrado: Mixamo/Mocap) exige inclinación hacia delante al correr (`rig.rotation.x < −0.05`). |

## Mapa de funciones

<!-- AUTO:funcs:scripts/player/footballer_visual.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `FootballerVisual.default_kit(team: int)` | 158 | Colores por defecto del kit (camiseta, short, medias, botines, piel, pelo). |
| `FootballerVisual.referee_kit()` | 165 |  |
| `FootballerVisual.keeper_kit()` | 169 |  |
| `FootballerVisual.build(kit: Dictionary)` | 174 | Carga el modelo y aplica el kit. Devuelve false si se uso el maniqui provisional. |
| `FootballerVisual._apply_kit(kit: Dictionary)` | 223 |  |
| `FootballerVisual.set_kit(kit: Dictionary)` | 237 |  |
| `FootballerVisual._anim_node(clip: StringName)` | 248 |  |
| `FootballerVisual._json_cycle_node(id: StringName)` | 255 | Modo 4: ciclo de marcha con una linea de tiempo comun de UN ciclo (todos empiezan en un apoyo del pie izquierdo), asi las fases de los clips |
| `FootballerVisual.reset_caches()` | 265 | Vacia los datos calculados con la libreria de clips (cambian al cambiar de modo). |
| `FootballerVisual._setup_animation_tree()` | 269 |  |
| `FootballerVisual.play_touch(id: StringName, foot: int, speed: float)` | 400 | Toque de conduccion: reproduce el clip de toque `id` en la capa de la pierna `foot` a `speed` (la escala de la marcha con pelota). Devuelve  |
| `FootballerVisual.carry_phase(clip: StringName)` | 410 | Fase (s) del clip de marcha con pelota `clip` tras el ultimo proceso del AnimationTree; -1 si no esta en la mezcla. Todos los puntos de la m |
| `FootballerVisual.carry_clip_for(speed: float)` | 416 | Clip de la marcha con pelota que domina a una velocidad (el punto de la mezcla mas cercano, sin el reposo). |
| `FootballerVisual.play_action(clip: StringName, speed: float = 1.0)` | 434 | Dispara un clip de accion una sola vez. Devuelve su duracion efectiva en segundos. |
| `FootballerVisual.cycle_seconds(clip: StringName)` | 451 | Duracion (s) de UN ciclo de zancada del clip. |
| `FootballerVisual.gait_table()` | 457 |  |
| `FootballerVisual.gait_scale_for(speed: float)` | 467 | Escala de tiempo de la marcha del pack a una velocidad: velocidad / velocidad natural de lo que se esta mezclando. |
| `FootballerVisual.gait_time_scale(speed: float)` | 483 |  |
| `FootballerVisual.carry_gait_table()` | 489 | Tabla de la marcha CON balon, igual que gait_table pero con los clips de conduccion. |
| `FootballerVisual.carry_scale_for(speed: float)` | 500 |  |
| `FootballerVisual.step_interval_for(speed: float, carry: bool = false)` | 518 | Segundos entre apoyos consecutivos (un pie tras otro) de la marcha del pack a una velocidad, ya con la escala de tiempo con la que se reprod |
| `FootballerVisual.play_pack_clip(id: StringName, speed: float = 1.0, start: float = 0.0, play_for: float = -1.0)` | 542 | Dispara un clip del pack una sola vez, con velocidad de reproduccion y punto de inicio (s). Devuelve su duracion efectiva en segundos (0 si  |
| `FootballerVisual.play_situation(situation: StringName, pick: int = 0, speed: float = 1.0, play_for: float = -1.0)` | 566 | Reproduce la situacion de juego pedida (AnimationCatalog): clip del pack si existe, si no el de Tripo. Devuelve {"source", "clip", "duration |
| `FootballerVisual.stop_current_action()` | 577 | Corta con un fundido la accion en curso (de Tripo o del pack). |
| `FootballerVisual.stop_action(clip: StringName)` | 589 |  |
| `FootballerVisual.start_kick(contact_time: float, power: float, side: int)` | 598 | Inicia la patada procedural: el golpeo ocurre a los contact_time segundos. side: +1 derecha, -1 izquierda. |
| `FootballerVisual.is_action_playing()` | 602 |  |
| `FootballerVisual._set_param(path: StringName, value: Variant)` | 620 |  |
| `FootballerVisual.update_motion(f: Footballer, delta: float)` | 626 |  |
| `FootballerVisual.drive_motion(speed: float, turn_rate: float, delta: float)` | 630 | Version por valores (la usan el futbolista y el arquero): velocidad horizontal y velocidad de giro (rad/s). |
| `FootballerVisual._build_placeholder(shirt_color: Color)` | 716 |  |
| `FootballerVisual._update_placeholder(speed: float, delta: float)` | 728 |  |
| `FootballerVisual._add_mesh(mesh: Mesh, mat: Material, pos: Vector3)` | 735 |  |
| `FootballerVisual._capsule(r: float, h: float)` | 743 |  |
| `FootballerVisual._sphere(r: float)` | 751 |  |
| `FootballerVisual._box(size: Vector3)` | 759 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/animation/procedural_pose.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `ProceduralPose.setup(skel: Skeleton3D)` | 32 |  |
| `ProceduralPose.start_kick(contact_time: float, power: float, side: int)` | 38 | Inicia una patada. contact_time = segundos hasta el golpeo; power 0..1; side +1 derecha / -1 izquierda. |
| `ProceduralPose.is_kicking()` | 45 |  |
| `ProceduralPose.kick_time()` | 48 |  |
| `ProceduralPose.cancel()` | 51 |  |
| `ProceduralPose.total_duration()` | 54 |  |
| `ProceduralPose._process_modification_with_delta(delta: float)` | 57 |  |
| `ProceduralPose._pose_step(delta: float)` | 62 |  |
| `ProceduralPose.apply_at(t: float)` | 75 | Aplica la pose de patada correspondiente al instante t (sin avanzar el tiempo). Util para herramientas. |
| `ProceduralPose._apply_lean()` | 89 | Inclinacion del tronco: en el espacio del esqueleto adelante = +X, derecha = +Z; girar la columna sobre +Z en negativo la lleva hacia delant |
| `ProceduralPose._rotate(bone: int, axis: Vector3, angle: float)` | 98 |  |
| `ProceduralPose.kick_angles(t: float, contact: float, power: float)` | 105 | Curvas de la patada (radianes) en funcion del tiempo. Pura: se puede probar sin esqueleto. |
| `ProceduralPose.envelope(t: float, contact: float)` | 142 | Peso de mezcla con la animacion base: entra rapido, sale al final de la recuperacion. |
| `ProceduralPose._ease_out(x: float)` | 148 |  |
| `ProceduralPose._ease_in(x: float)` | 152 |  |
| `ProceduralPose._smooth(x: float)` | 156 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/animation/pose_sampler.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `PoseSampler.bind(anim: Animation, skeleton: Skeleton3D)` | 7 | Aplica una Animation a un Skeleton3D evaluando directamente sus pistas (sin AnimationPlayer). Util para herramientas (medicion de ciclos, ca |
| `PoseSampler.apply(anim: Animation, skeleton: Skeleton3D, bind_map: Dictionary, time: float)` | 20 |  |
| `PoseSampler.bone_in_skeleton(skeleton: Skeleton3D, bone: int)` | 34 | Transformacion de un hueso respecto al esqueleto, compuesta a mano desde las poses locales (no depende de la cache de poses globales del mot |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/player/footballer_visual.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `FootballerVisual.action_finished(clip: StringName)` | 78 |  |
<!-- /AUTO -->

## Clips de la librería (13) y su origen

Todos son presets de Tripo3D retargeteados sobre nuestro rig v1.0 (`docs/tripo/ledger.jsonl` registra cada operación de pago). Nombre final ← nombre de origen (`tools/build_animation_library.gd`):

| Clip final | Origen (GLB → clip) | Bucle | Conectado al árbol |
|---|---|---|---|
| `idle`, `walk` | `v1_keeper.glb` → `idle`, `walk` | sí | sí, `BlendSpace1D` |
| `run` | `v1_more.glb` → `run` | sí | sí, `BlendSpace1D` |
| `dive`, `jump`, `fall` | `v1_keeper.glb` | no | sí, `OneShot` (**sin disparador**) |
| `turn`, `celebrate_goal` (← `victory_celebration`), `dejected` (← `defeat_02`), `frustrated` (← `frustrated_01`) | `v1_more.glb` | no | sí, `OneShot` (**sin disparador**) |
| `keeper_catch_high` (← `football_catch`), `keeper_scoop_low` (← `football_save`) | `v1_football.glb` | no | sí, `OneShot` (**sin disparador**) |
| `defensive_stance` (← `football_pass`) | `v1_football.glb` | sí | **no** |

> **Corrección (2026-10-26):** pese a su nombre, `defensive_stance` **no es una postura defensiva**: viene del preset `football_pass` y, reproducido sobre nuestro futbolista, muestra a un jugador de pie con cambios de peso y un gesto de pase lento (velocidad de avance del pie máx. 2.4 m/s; alcance 0.74 m). No sirve como pase ni como postura. Evaluación completa de la biblioteca de 133 clips del pack de Mixamo frente a estos 13: [ANIMATION_PACK](ANIMATION_PACK.md) (no integrado todavía).

## Recorrido de ejecución

1. `Footballer._ready` crea `FootballerVisual` y llama `build(default_kit(team))` (salvo `Footballer.build_visual = false`, que usan las pruebas). Si falta el GLB o la librería: aviso + maniquí de cápsulas (`is_placeholder`).
2. `build`: `Rig` (yaw `MODEL_YAW`, escala `MODEL_HEIGHT_SCALE`) → modelo → `AnimationPlayer` con la librería → material de kit en todas las mallas → `AnimationTree` → `ProceduralPose` como hijo del esqueleto.
3. Cada paso de física: `update_motion(f, delta)`: `Locomotion/blend_position = f.locomotion.speed`; cadencia `LocoScale/scale = clamp(v / natural, 0.6, 2.9)` con `natural = lerp(0.97, 2.50, clamp((v − 0.9)/1.5, 0, 1))` (solo si `v > 0.15`); inclinación del cuerpo; temporizador de la acción en curso (`action_finished`).
4. Patada: `BallHandler.request_kick` → `FootballerVisual.start_kick(contact_time, power, side)` → `ProceduralPose` rota muslo, rodilla, rodilla de apoyo y `Spine1` alrededor de +Z del esqueleto según `kick_angles(t)` × `envelope(t)`. El impulso a la pelota lo aplica `BallHandler._finish_kick` en el mismo `contact_time`.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh player_model` y `tools/run_tests.sh kick_timing`.
- **Última ejecución (2026-10-26):** `player_model` 4 pruebas / 36 comprobaciones sin fallos (modelo dentro del presupuesto de 10 000 triángulos: 7640; 23 huesos; clips presentes, en bucle y con la cadera centrada a ±0.02; kit recolorea; el árbol sigue la velocidad: sprint → mezcla 6.80, escala de tiempo 2.72).
- **Alcance real:** las pruebas son sin pantalla. Que la patada o la marcha *se vean bien* solo se comprueba con las hojas de contacto de `tools/render_*_sheet.gd` (requieren Xvfb) y **no hay una prueba automática de aspecto**.

tests/test_player_model.gd (borrado: Mixamo/Mocap): bloque generado quitado.

<!-- AUTO:tests:tests/test_kick_timing.gd -->
| Prueba | Línea |
|---|---|
| `test_ball_impulse_happens_at_contact_not_at_button_release` | 9 |
| `test_kick_whiffs_if_the_ball_moves_away_during_the_swing` | 46 |
| `test_pose_curves_are_continuous_and_peak_at_contact` | 71 |
<!-- /AUTO -->

- **Qué podría romperse:** otro rig (v3.0) incompatible con la librería v1.0 (huesos distintos); un GLB nuevo que cambie el número de huesos (la prueba exige 23); animaciones sin centrar (pies/cuerpo se desplazan del jugador).

## Limitaciones conocidas

- **Respaldo de Tripo:** con las librerías del pack presentes, los 13 clips de Tripo solo se usan como respaldo (los disparadores de partido piden la situación a `AnimationCatalog`, que elige el clip del pack). Los clips `keeper_*` y `dive` de Tripo ya no tienen uso: el arquero usa `pack_keeper.res` (ver [GOALKEEPER](GOALKEEPER.md)).
- **Un solo esqueleto/modelo:** el rig v3.0 que se generó al inicio no es compatible y no está en el repositorio (los resultados crudos están fuera de él).
- **Sin animaciones de cabeceo, regate/amague, entrada deslizante ni giro con balón** más allá del clip `turn` sin conectar.
- **Cadencia saturada:** por encima de ~7.2 m/s los pies patinan.
- **Golpeo muy rápido:** la fase de golpeo de la patada dura ~46 ms (unos 3 fotogramas a 60 Hz) y su velocidad angular máxima de cadera medida es ~49.9 rad/s; la prueba solo impone una cota anti-salto (< 60 rad/s, salto por muestra < 0.06 rad), **no un objetivo de calidad visual**. Suavizarla implicaría alargar `contact_time` (cambio de mecánica) o rediseñar `kick_angles`.
- **Sin IK.** Con el pack, el pie coincide con la pelota por el **contacto medido del clip + ajuste de zancada** (distancia pie–pelota en el impulso ≤ 0.16 m en las pruebas), no por IK de pies. Con la patada procedural (respaldo) solo coinciden por el retardo de contacto.

## Pack de Mixamo: integrado

Un pack propio de 133 animaciones de Mixamo (esqueleto Y Bot de 65 huesos) cubre idle, caminar, trotar, sprint, desplazamientos laterales, conducción, pase, recepción, tiro y el arquero completo. Se evaluó clip por clip y se convirtió (retarget respecto al reposo) una selección a una librería local restringida: **los 133 clips están convertidos**: 93 con disparador en partido (marcha, pase/tiro con contacto, voleas, cabezazos, entradas, caídas, regate, arquero, festejos, árbitro, malabares) y 40 en la galería de la **sala de práctica** (`PracticeScene`, botón «Práctica de animaciones» de la pausa: repetir, velocidad, raíz, espejo, cámara y malabares); los clips de Tripo quedan de respaldo. Estado, hallazgos, incompatibilidades y límites: [ANIMATION_PACK](ANIMATION_PACK.md) y la tabla [ANIMATION_PACK_CLIPS](../ANIMATION_PACK_CLIPS.md).

## Marcha con la pelota

`FootballerVisual` mezcla una segunda marcha sobre la normal cuando el futbolista lleva el balón (`carrying`, que
`Footballer` pone con `ball_handler.has_possession()`): `CARRY_GAIT_POINTS` = `Soccer_Idle` (parado con la pelota),
`Dribble_2` (conducción, 2.32 m/s natural), `jog_forward_inplace` y `Sprint_inplace`, con su propia escala de tiempo
(`carry_scale_for`). El peso sube y baja con `CARRY_BLEND_RATE`, así que al perder la pelota el cuerpo vuelve a la
marcha normal sin salto. El control lateral y la protección reutilizan la mezcla direccional (`Dir`) a través de
`Locomotion.face_override`.

## Clips de recepción del modo 4 (F3, 2026-10-30)

Los 124 clips de recepción y control tienen un perfil de contacto (`ReceiveProfiles`, generado desde los JSON originales con la
auditoría de F3): 23 utilizables, 27 con condiciones, 70 pendientes de verificación visual (fuera de la selección automática) y
4 arranques de conducción (no son recepciones). El primer contacto real puede ser pecho, muslo, rodilla o pie en el aire, y no
coincide necesariamente con el primer `ball_touches` (toques de pie registrados). Los nombres tienen el lado invertido respecto
de los datos. Los clips no se modificaron.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Futbolista con Tripo3D», «Esqueleto único v1.0».

## Inclinación del tronco en curvas y cambios de ritmo (2026-10-28)

Del video de referencia de conducción (`referencia_conduccion_recortada`, revisado imagen por imagen): al doblar con
la pelota el jugador se inclina hacia dentro de la curva, al arrancar se echa hacia delante y al frenar hacia atrás.
Antes el cuerpo entero se inclinaba ~1/20 de lo que pide la física (2° a 6 m/s girando 1 rad/s): no se veía.

- `FootballerVisual.drive_motion` calcula la inclinación física hacia dentro, `atan(v·giro/g)·LEAN_TURN_GAIN` (0.75,
  máximo `LEAN_ROLL_MAX` 0.38 rad ≈ 22°), y la de la aceleración (`a/g`, hasta `LEAN_ACCEL_MAX` 0.18 rad delante y
  `LEAN_BRAKE_MAX` 0.1 rad atrás), y se la pasa a `ProceduralPose.lean_roll` / `lean_pitch`.
- `ProceduralPose._apply_lean` la reparte por la columna (`Spine` 40 %, `Spine1` 30 %, `Spine2` 30 %) sin tocar caderas
  ni piernas. Se probó primero inclinando el cuerpo entero (`rig`): movía los pies y la conducción en curva empeoró
  (eslalon a la carrera p95 0.33 → 0.54 m, cambio de carril 0.13 → 0.59 m, 5 semillas). Con el tronco las cifras quedan
  exactamente igual que sin inclinación (0.33 / 0.38 / 0.09 / 0.13 / 0.63 m).

## Control cerrado encorvado y suela sobre la pelota (2026-10-28)

- **Encorvado sobre la pelota** (`FootballerVisual.CARRY_CROUCH` 0.13 rad): llevando la pelota entre caminar y trotar
  (sube de 0.3 a 1.4 m/s y se va de 3.2 a 5.0 m/s) el tronco se inclina hacia delante sobre ella, como los jugadores de
  First Touch Soccer en control cerrado. Va en la columna (`ProceduralPose`), sin mover caderas ni piernas.
- **Suela sobre la pelota** (`TouchFootIK.set_target`): además de la corrección limitada de los toques de clip
  (`set_correction`, hasta 0.16 m) el IK lleva la punta del pie a un punto del mundo (lo alto de la pelota en la vuelta
  atrás, `DragBack`) con un giro del pie y un peso; manda sobre la corrección y se suelta sola sin refresco.
  `abs_toe_world` guarda la punta tras el IK (lo mide *test_drag_back (eliminada en la reforma)* con render: 0.04 m de lo alto de la pelota).
  Imágenes: `tools/drag_back_view.tscn`.
  Rodilla en la pisada (2026-10-29): con el objetivo absoluto el polo de la rodilla se inclina hacia el frente del cuerpo
  (`_body_forward`: cadera izquierda − derecha × arriba, parámetro `knee_fwd` de `ik_toe`); antes, al pisar la pelota en
  el giro (`BallTurn`) la rodilla podía quedar hacia atrás y la pierna se doblaba en Z. Revisado con imágenes del giro.

