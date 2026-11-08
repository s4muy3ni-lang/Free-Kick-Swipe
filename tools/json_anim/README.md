# tools/json_anim — animaciones JSON → modo 4 «Json»

Convierte las 2 022 animaciones de `animaciones_futbol5_JSON_limpios.zip` (por clip: 19 articulaciones en posiciones, fotogramas
clave irregulares a 60 fps, raíz y metadatos de patada/toques/apoyos) a clips con rotaciones sobre un esqueleto canónico, y construye el
humanoide del modo (el GLB de Tripo adaptado se descartó el 2026-10-30). Detalle del sistema: [`docs/technical-index/SYSTEMS/JSON_MODE.md`](../../docs/technical-index/SYSTEMS/JSON_MODE.md).

Los JSON originales **no se versionan** (26 MB; descomprimir el zip en una carpeta cualquiera y pasarla en `JSON_SRC`). Lo que se
versiona es el resultado: `assets/animations/json_clips.res`, `json_scenes.res`, `json_keeper.res` y `assets/characters/json/json_human.scn`.

| Paso | Comando |
|---|---|
| Elegir clips (listas curadas + clasificacion de TODOS los demas) | `python3 tools/json_anim/make_selection.py <carpeta_JSON>` → `selection.json` |
| Convertir (campo y arquero) | `JSON_SRC=<carpeta_JSON> godot --headless --path . res://tools/json_anim/build_json_library.tscn` |
| Humanoide realista | `godot --headless --path . res://tools/json_anim/build_json_human.tscn` |
| Error del retarget frente a los datos | `JSON_SRC=<carpeta_JSON> godot --headless --path . --script res://tools/json_anim/retarget_check.gd -- 0072_ 1582_` |
| Ver un modelo / clip | `MODEL=res://assets/characters/json/json_human.scn CLIP=jn_sprint_3022 TIMES=0,0.1,0.2 VIEWS=side OUT=/tmp/x.png xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/json_anim/model_preview.tscn` |
| Ver conducción / giros / golpeos en juego | `SCENARIO=dribble OUT=/tmp/x.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/play_view.tscn` (escenarios `dribble`, `diag`, `zigzag`, `turn`, `turn90`, `dragback`, `turnshot`, `sideshot`, `pass`, `shot`; `VIEW=close`; `ON_TOUCH=1` guarda solo el instante de cada toque) |
| Capturas del partido completo (cámara de transmisión) | `SHOTS=14,22 OUT=/tmp/m xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/match_shot.tscn` |
| Ver una recepción (selección automática) | `ANGLE=0 SPEED=12 [ARRIVE_Y=0.6] [PASS=1] OUT=/tmp/r.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/receive_view.tscn` |
| Auditar un clip de recepción excluido (p. ej. `pending`) | `CLIP=jn_receive_0604 [PART=thigh] [T=0.333] W=360 H=270 COUNT=6 COLS=3 EVERY=6 OUT=/tmp/c.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/receive_view.tscn` (pelota calibrada a la parte supuesta; tira antes/durante/después del contacto y medida del esqueleto vivo; `DEBUG=1` desvío frente a la trayectoria prevista) |
| Perfiles de contacto de recepción | `python3 tools/json_anim/make_receive_profiles.py <carpeta_JSON_nombres_originales>` → `scripts/player/receive_profiles.gd` (veredictos visuales en `VISUAL` / `VISUAL_NOT`) |
| Ver una atajada | `TARGET=1.0,0.6 SPEED=15 OUT=/tmp/k.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/keeper_view.tscn` |

Después de convertir o cambiar un modelo: `godot --headless --path . --import` y `tools/run_tests.sh json_mode`.
