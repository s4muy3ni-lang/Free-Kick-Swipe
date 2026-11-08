# Herramientas de evaluación del pack de animaciones (Mixamo / Y Bot)

Evaluación del pack de 133 animaciones de fútbol frente a la biblioteca de Tripo y **conversor** que genera las librerías del pack que el juego usa si existen (`build_pack_library.tscn`; el resto de herramientas son de solo lectura).
Resultados y conclusiones: `docs/technical-index/SYSTEMS/ANIMATION_PACK.md` y `docs/technical-index/ANIMATION_PACK_CLIPS.md`.

## Preparación

Las librerías ya generadas (`assets/animations/pack_*.res`) están en el repositorio y el juego las usa tal cual. Los FBX originales no se suben (`/pack/` en `.gitignore`): para reconvertir hay que copiarlos a `pack/` (`animaciones/`, `personaje/`, `indice_futbol.json`) y dejar que Godot los importe.

```
python3 tools/animation_pack/make_selection.py                                   # 133 clips, roles, trayectorias, estado
godot --headless --path . res://tools/animation_pack/build_pack_library.tscn     # pack_clips.res + pack_keeper.res
tools/run_tests.sh pack ; tools/run_tests.sh practice
```

## Herramientas

| Herramienta | Qué hace | Cómo se ejecuta |
|---|---|---|
| `pack_checks.tscn` | Reposo idéntico al Y Bot, cobertura de los 22 huesos, gemelos `_inplace` | `godot --headless --path . res://tools/animation_pack/pack_checks.tscn` |
| `pack_metrics.tscn` | Métricas de cada clip (pack y Tripo) → `metrics.json` | `ANA_OUT=<dir> godot --headless --path . res://tools/animation_pack/pack_metrics.tscn` |
| `pack_rest.tscn` | Reposo y proporciones de Tripo frente al Y Bot | `godot --headless --path . res://tools/animation_pack/pack_rest.tscn` |
| `fbx_times.py` | Duración real leída del FBX en bruto | `python3 tools/animation_pack/fbx_times.py pack <dir>/fbx_times.json` |
| `analyze_metrics.py` | Resume `metrics.json` → `rows.json` | `python3 tools/animation_pack/analyze_metrics.py <dir>` |
| `pack_sheet.tscn` | Hojas de contacto sobre nuestro futbolista (render) | `SRC=pack CLIPS=02_balon_pases_tiros/Soccer_Pass.fbx FRAMES=6 OUT=<dir> xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/animation_pack/pack_sheet.tscn` (`SRC=tripo CLIPS=idle,walk` para los clips de Tripo) |
| `pack_foot.tscn` | Velocidad/alcance del pie en pases, tiros y conducción (render) | `OUT=<dir> CLIPS=defensive_stance,02_balon_pases_tiros/Soccer_Pass.fbx xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/animation_pack/pack_foot.tscn` |
| `pack_library_probe.tscn` | Genera librerías de prueba en `<dir>` para medir su tamaño | `OUT=<dir> CORE=Soccer_Pass,Dribble_2 godot --headless --path . res://tools/animation_pack/pack_library_probe.tscn` |
| `make_report.py` | Regenera `docs/technical-index/ANIMATION_PACK_CLIPS.md` | `python3 tools/animation_pack/make_report.py <dir>` |
| `evaluation_notes.json` | **Curado a mano**: recomendación, ola y verificación visual de cada clip | editar y volver a ejecutar `make_report.py` |
| `pack_retarget.gd` | `PackRetarget`: retarget Y Bot → Tripo respecto al reposo (espejo, calibración de cadera, raíz) | lo usan el conversor, `pack_sheet`, `pack_foot` y `pack_library_probe` |
| `build_pack_library.tscn` + `selection.json` | **Conversor:** genera `assets/animations/pack_clips.res` y `pack_keeper.res` (ignorados por git) con metadatos medidos; `selection.json` (curado a mano) elige los clips y su `state` | `godot --headless --path . res://tools/animation_pack/build_pack_library.tscn` (opcional `OUT=<dir>` escribe `pack_report.json`) |

`<dir>` es un directorio de salida cualquiera fuera del repositorio.
