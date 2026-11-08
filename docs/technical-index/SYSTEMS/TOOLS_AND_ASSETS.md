# TOOLS_AND_ASSETS — Herramientas, pipeline de assets y gasto de Tripo3D

## Identificación

- **Responsabilidad exacta:** todo lo que *produce o verifica* assets y documentación sin formar parte del juego: inspección y limpieza de GLB, texturas del kit, librería de animaciones, capturas renderizadas (Xvfb), mediciones de marcha, libro de gasto de créditos de Tripo3D y la herramienta del índice técnico.
- **Estado:** operativo. Las operaciones de pago de Tripo3D **no** forman parte de ninguna tarea de documentación o de mantenimiento: se registran en el libro y requieren decisión explícita.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-08
<!-- /AUTO -->

## Herramientas (`tools/`)

| Herramienta | Qué hace | Uso | Entrada → salida |
|---|---|---|---|
| `tools/run_tests.sh` | Ejecuta las pruebas headless | ver [TESTING](TESTING.md) | — |
| `tools/docs_index.py` | Índice técnico: `sync`, `check`, `find`, `where`, `stats` | `python3 tools/docs_index.py <comando>` | código → `docs/technical-index/` |
| `tools/build_animation_library.gd` | Reconstruye `assets/animations/footballer_clips.res` desde `assets/animations/source/*.glb` (renombra clips, centra la cadera, fija bucles) | `godot --headless --path . -s tools/build_animation_library.gd` | 3 GLB → `.res` |
| `tools/glb_inspect.py` | Informe de un GLB (triángulos, huesos, texturas, animaciones, caja) sin dependencias | `python3 tools/glb_inspect.py modelo.glb [--json]` | GLB → texto/JSON |
| `tools/strip_glb_textures.py` | Quita texturas (y opcionalmente animaciones) de un GLB | `python3 tools/strip_glb_textures.py in.glb out.glb [--no-anims]` | GLB → GLB |
| `tools/make_player_textures.py` | Genera albedo 1024², máscaras de regiones y luminancias medias desde la textura de Tripo | `python3 tools/make_player_textures.py Color.jpg carpeta` | JPG → `player_albedo.jpg`, `player_mask_a/b.png`, `player_regions.json` |
| `tools/inspect_model.gd` | Árbol de nodos, huesos, animaciones y triángulos de un modelo importado | `godot --headless --path . -s tools/inspect_model.gd -- res://ruta.glb` | — |
| `tools/measure_hips.gd`, `tools/measure_gait.gd` | Desplazamiento de cadera de cada clip y velocidad natural de marcha (origen de `NATURAL_SPEED`) | `godot --headless --path . -s tools/measure_hips.gd -- res://x.glb [1.75]` | GLB → texto |
| `tools/render_pose_sheet.gd`, `render_clip_sheet.gd`, `render_kick_sheet.gd` (+ `.tscn`) | Hojas de contacto PNG de poses, de un clip y de la patada procedural | `xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/render_*_sheet.tscn` con variables de entorno (ver la cabecera de cada script) | — → PNG |
| tools/animation_pack/ (borrado: Mixamo/Mocap) (varios `.gd`/`.tscn`/`.py`) | Evaluación del pack de 133 animaciones de Mixamo (compatibilidad, métricas, hojas de contacto, tabla por clip) y **conversor** `build_pack_library.tscn` (`selection.json` → assets/animations/pack_clips.res (borrado: Mixamo/Mocap) y `pack_keeper.res`, restringidos y no versionados) con `PackRetarget` | ver tools/animation_pack/README.md (borrado: Mixamo/Mocap) | pack en `pack/` (ignorado por git) → librerías locales e informes |
| `tools/shot_runner.gd` (+ `.tscn`) | Ejecuta una escena con entradas programadas y guarda capturas | variables `SHOT_SCENE`, `SHOT_INPUT`, `SHOT_TIMES`, `SHOT_OUT`, `FUTBOL5_TOUCH` | — → PNG |

Notas verificadas: `tools/screenshot_probe.gd.uid` está versionado pero el `.gd` correspondiente **no existe** (resto huérfano); `tools/shots/` está vacío y no se versiona; `__pycache__/` está ignorado.

## Assets del repositorio

| Ruta | Contenido | Origen |
|---|---|---|
| `assets/characters/player/player_base.glb` | Modelo del futbolista (7640 triángulos, esqueleto v1.0 de 23 huesos) | Tripo3D (rig v1.0), texturas retiradas con `strip_glb_textures.py` |
| `assets/characters/player/player_albedo.jpg`, `player_mask_a.png`, `player_mask_b.png`, `player_regions.json`, `player_kit.gdshader` | Kit recoloreable | `make_player_textures.py` + shader propio |
| `assets/animations/source/v1_keeper.glb`, `v1_football.glb`, `v1_more.glb`, `v1_ball.glb` | Clips crudos de Tripo (preset retargeteado sobre el rig v1.0; `v1_ball` guardado sin usar) | Tripo3D |
| assets/animations/mocap_clips.res (borrado: Mixamo/Mocap) | «Mocap Pack 05 Soccer» convertido (modo 2 de jugabilidad, ver [ANIMATION_PACK](ANIMATION_PACK.md)) | pack aportado por la persona |
| assets/characters/mocap/mocap_player.scn (borrado: Mixamo/Mocap) + `mocap_kit.gdshader` | Modelo del modo 2: Newton del mismo pack en baja poligonización (6 778 triángulos, esqueleto Rokoko de 76 huesos, zona del kit en `COLOR.r`); tools/animation_pack/build_mocap_character.tscn (borrado: Mixamo/Mocap) | pack aportado por la persona |
| `assets/animations/footballer_clips.res` | Librería compartida de 13 clips | `build_animation_library.gd` |
| `assets/ball/ball.gdshader`, `assets/pitch/court.gdshader`, `assets/pitch/net.gdshader` | Shaders propios (pelota, cancha, red) | código |
| `assets/audio/` | Directorio **vacío** (sin audio en el juego) | — |

La pelota, la cancha, los arcos, las gradas y el HUD no usan modelos ni texturas externas: se construyen por código ([PITCH](PITCH.md), [BALL](BALL.md)).

## Libro de gasto de Tripo3D (`docs/tripo/ledger.jsonl`)

Una línea JSON por operación de pago: `ts`, `task`, `result`, `balance_before`, `balance_after`, `spent`, `notes`. **No contiene claves ni secretos.** Estado al 2026-10-29 (9 registros):

| Operación | Créditos |
|---|---|
| Texto → modelo del jugador (v3.1, 8000 caras) | 20 |
| Comprobación de rig (gratis) | 0 |
| Auto-rig v3.0 | 25 |
| Retarget v3.0 (idle, walk, run) | 30 |
| Auto-rig v1.0 (presets deportivos) | 25 |
| Retarget v1.0 (3 + 5 + 5 clips) | 30 + 50 + 50 |
| Retarget v1.0 (`dribble`, `crossover_dribble`, `front_kick_01`, `front_kick_02`, `shoot`), 2026-10-29, autorizado por la persona | 50 |
| **Gastado** | **280** |
| **Saldo** | **720 de 1000** (reserva mínima prevista: ~200) |

Los 5 presets del 2026-10-29 no son de fútbol (medidos sobre el futbolista: `dribble` y `crossover_dribble` botan una
pelota de básquet con la mano a 0.32 m del suelo y el pie nunca pasa de 0.30 m por delante; `front_kick_01/02` son
patadas de artes marciales con el pie a 0.8–0.9 m de altura; `shoot` es arrodillarse y apuntar con un arma). Quedan
guardados sin usar en `assets/animations/source/v1_ball.glb` (sin texturas, fuera de la APK). Tripo no tiene otros presets
de fútbol ni crea animaciones nuevas o combinadas.

Reglas del proyecto: comprobar coste antes (`tripo make --dry-run` existe para generación), registrar cada gasto en el libro, no superar el presupuesto, **nunca** imprimir ni versionar la clave de Tripo (`.gitignore` excluye `.tripo/`, `**/tripo_api_key*`, `**/config.json`, `.env*`).

Los resultados crudos de Tripo (GLB, JSON de resultado, scripts de generación) están **fuera del repositorio** (`/opt/tripo-work/` en la sesión) y se perderían con el contenedor; lo que importa para reconstruir el juego está en `assets/`.

## Pruebas

- **Ejecutar:** no hay pruebas de las herramientas; `tools/docs_index.py check` valida el índice y `tools/run_tests.sh player_model` valida los assets del jugador ([ANIMATIONS](ANIMATIONS.md)).
- **Qué podría romperse:** regenerar `footballer_clips.res` desde GLB con otro rig (huesos distintos); texturas con otro mapa de UV (las máscaras dejan de coincidir).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Futbolista con Tripo3D», «Esqueleto único v1.0».
