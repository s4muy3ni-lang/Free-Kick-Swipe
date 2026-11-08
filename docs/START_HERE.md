# START HERE — guía rápida para otro chat de Claude

> **Actualización 2026-11-07 — reforma a tiros libres y penales (prioridad):** rama `reforma-tiros-penales`; estado y próximos pasos en [`docs/reforma/ESTADO_REFORMA.md`](reforma/ESTADO_REFORMA.md).
>
> **Actualización 2026-11-07 — guía maestra de animaciones (en pausa):** el trabajo en curso está en la rama `integracion-openai` (no tocar `respaldo-f3`). Para continuar leer primero [`docs/integration/CONTINUAR_GUIA_ANIMACIONES.md`](integration/CONTINUAR_GUIA_ANIMACIONES.md).

> **Chat nuevo:** primero [`ESTADO_Y_METODOLOGIA.md`](ESTADO_Y_METODOLOGIA.md) (rama de trabajo `respaldo-f3`, fases, reglas y pendientes).

> Fútbol 5 / futsal para Android. **Godot 4.7.2**, GDScript, renderer GL Compatibility, física **Jolt a 60 Hz**.
> Repo `roldanhr98-byte/Futbol5`. Esta página es un atajo: dice **dónde está cada cosa** y **cómo trabajar sin leer todo**.
> El detalle vive en `docs/technical-index/` (se regenera con `tools/docs_index.py`; si el índice y el código no coinciden, **manda el código**).

## 0. Reglas que no se negocian (leer 30 s)

- **No inventar resultados.** No marcar como aprobada una prueba que no se ejecutó; si falla, decirlo con la salida real.
- **No cambiar la mecánica** salvo que se pida. El balance vive en los valores por defecto de las clases `*Tuning`.
- **Secretos:** nunca escribir la clave de Tripo3D ni claves de firma Android en el repo, el chat ni los registros.
- **Tripo3D (de pago):** pedir autorización antes de gastar créditos; comprobar coste, reserva ~200 créditos, anotar en `docs/tripo/ledger.jsonl`.
- **Git:** trabajar en la rama que indique la sesión; **no abrir PR** salvo que lo pidan. Mensajes de commit con las líneas de atribución de la sesión.
- **La pelota solo cambia de velocidad por impulsos** (`Ball.kick`) y su física; nunca se fija su posición para «conducirla».
- Texto de interfaz y comentarios `##` en **español**; identificadores en **inglés**; sangría con **tabuladores**; tipado explícito; `class_name` en clases reutilizables.
- Ejes: **X = largo (arcos en x = ±25: cancha de fútbol 7 de 50 × 30 con arcos de 5 × 2; las pruebas de mecánica usan la de futsal 40 × 20, arcos en ±20)**, Z = ancho, Y = arriba. Equipo 0 ataca +X. `yaw = 0` mira a −Z.

## 1. Flujo de trabajo en 6 pasos (ahorra tokens)

```bash
python3 tools/docs_index.py find <palabras de la petición>      # 1. dónde está (español o inglés)
python3 tools/docs_index.py where Clase.miembro                 # 2. confirmar símbolo y línea
# 3. abrir SOLO docs/technical-index/SYSTEMS/<SISTEMA>.md y el código inmediato
tools/run_tests.sh <filtro>                                     # 4. probar (suite completa: tools/run_tests.sh)
python3 tools/docs_index.py sync && python3 tools/docs_index.py check   # 5. docs (check debe dar 0 errores)
# 6. entrada en docs/technical-index/CHANGELOG.md si el cambio es funcional/estructural
```

## 2. «Quiero cambiar X» → archivo

| Quiero… | Archivo / parámetro |
|---|---|
| Fuerza/rebote/rodadura de la pelota | `scripts/ball/ball_tuning.gd`, física en `ball.gd` |
| Velocidad del jugador, alcance de patada, wind-up de tiro | `scripts/player/player_tuning.gd` (`kick_contact_radius`, `shot_windup`…) |
| Cómo conduce / frena / gira con la pelota | `scripts/player/ball_handler.gd`, `locomotion.gd` |
| Giro hacia atrás con toques (joystick atrás) | `scripts/player/ball_turn.gd` |
| Vuelta atrás pisando la pelota (REGATE + atrás) | `scripts/player/drag_back.gd` |
| Pases, tiros, centros asistidos | `scripts/assistance/{pass,shot,cross}_assist.gd`, `assist_tuning.gd`, `kick_model.gd` |
| Presión / robo | `scripts/assistance/press_controller.gd`, `scripts/player/player_actions.gd` |
| Arquero (posición, atajadas) | `scripts/goalkeeper/goalkeeper.gd`, `keeper_planner.gd`, `keeper_tuning.gd` |
| IA de equipo | `scripts/ai/team_brain.gd`, `ai_input.gd` |
| Reglas: gol, fuera, córner, faltas, penal, reloj | `scripts/gameplay/match_manager.gd`, `set_piece.gd`, `referee.gd` |
| Composición del partido | `scripts/gameplay/match_scene.gd` → *scenes/main/match.tscn (eliminada en la reforma; en el historial de git)* |
| Cancha, arcos, red | `scripts/pitch/*`, `assets/pitch/*.gdshader` |
| Cámara (encuadre, zoom, golpe) | `scripts/camera/match_camera.gd` |
| Sonido | `scripts/audio/sfx.gd` (autoload `Sfx`) |
| HUD, menú de pausa, botones táctiles | `scripts/ui/hud.gd`, `touch_controls.gd`, `ui_theme.gd` |
| Ajustes del usuario (zoom, sonido, modo de juego) | `scripts/gameplay/tuning.gd` (autoload `Tuning`) |
| Qué clip suena en cada situación | `scripts/animation/animation_catalog.gd` (**único** que elige clips; en el modo 4 `json_catalog.gd` + alias de `pack_library.gd`) |
| Cargar librerías de clips | `scripts/animation/pack_library.gd` |
| Modelo del jugador, AnimationTree, kit de colores | `scripts/player/footballer_visual.gd` |
| IK del pie en toques/pisadas | `scripts/animation/touch_foot_ik.gd` |
| Patada procedural (modo 3) | `scripts/animation/procedural_pose.gd` |
| Atributos de jugador (31, escalan parámetros) | `scripts/progression/player_attributes.gd` |
| Repetición de goles | `scripts/gameplay/goal_replay.gd` |
| Galería de animaciones / malabares | `scripts/gameplay/practice_scene.gd`, *scenes/practice/practice.tscn (eliminada en la reforma; en el historial de git)* |
| Perfiles gráficos, FPS | `scripts/diagnostics/graphics_settings.gd`, `diagnostics_overlay.gd` |
| APK / CI / firma | `.github/workflows/android.yml`, `export_presets.cfg`, `tools/android/` |

## 3. Los 4 modos de jugabilidad (`Tuning.gameplay_mode`)

> **Desde el 2026-10-30 el juego arranca siempre en el modo 4 (Json)**, el único que se conserva: `Tuning.DEFAULT_GAMEPLAY_MODE = 4`, `PLAYABLE_MODES = [4]` (preferencias antiguas con 1-3 pasan al 4) y el menú de pausa ya no muestra «Modo de juego». Los modos 1-3 siguen en el código para las pruebas y los sistemas compartidos; no se usan ni se borran sin autorización.

| Modo | Qué es | Dónde |
|---|---|---|
| **1 · Pack actual** | Modelo de Tripo + 133 clips Mixamo (`pack_clips.res`, `pack_keeper.res`) + toques/IK | `AnimationCatalog.FIELD/KICKS` |
| **2 · Mocap fútbol** | Clips del «Mocap Pack 05 Soccer» (`mocap_clips.res`, 24 clips `mc_*`: pase, tiro, penal, saque de banda, tarjeta, festejos) + **modelo propio Newton** (`MocapRig`) que copia la pose del esqueleto del futbolista (que sigue haciendo todo pero no se dibuja) | `AnimationCatalog.MOCAP_*`, `scripts/animation/mocap_rig.gd`, `assets/characters/mocap/` |
| **3 · Tripo** | Solo modelo y presets de Tripo + patada procedural (`FootballerVisual.uses_pack = false`) | `footballer_visual.gd` |
| **4 · Json** | Las 2 022 animaciones de `animaciones_futbol5_JSON` (posiciones de 19 articulaciones → rotaciones sobre el esqueleto canónico `JsonRig`) sobre el humanoide propio, conectadas por rol: giros con pelota y vuelta pisando la pelota con los toques del clip (`json_ball_move.gd`), golpeo girando, toques con el pie, festejos, técnicos y público. Los clips sustituyen por alias a los nombres del pack de Mixamo | `scripts/animation/json_*.gd`, `tools/json_anim/`, `SYSTEMS/JSON_MODE.md` |

- Modo 4: ficha [`SYSTEMS/JSON_MODE.md`](technical-index/SYSTEMS/JSON_MODE.md); regenerar clips/modelos y revisar a ojo: [`tools/json_anim/README.md`](../tools/json_anim/README.md). Pruebas: `tools/run_tests.sh json_mode`; con render `TEST_GAMEPLAY_MODE=4 xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter live_feet` (y `live_kicks`).
- Tripo **no crea animaciones a medida** (solo rigging y presets de biblioteca fija).
- Conducción, malabares, atajadas, defensa y tarjeta roja de mocap están en la galería pero **sin disparador** en partido (motivos en `SYSTEMS/ANIMATION_PACK.md`).
- Pendiente conocido: pase de primera en modo 2, el pie de apoyo patina 1.67 m/s (límite de prueba 1.6).

## 4. Pruebas

- Headless (propio, no GUT): `tools/run_tests.sh [filtro]` — falla si hay `SCRIPT ERROR`. ~205 pruebas, ~8 min completa.
- Con render (pies animados): `xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter <nombre>`
  - Modo 2 en patadas: `LIVE_KICKS_MODE=2 … --filter live_kicks`.
- Imágenes de una acción: `tools/drag_back_view.tscn` (`DRAG_OUT`, `DRAG_ACTION`, `DRAG_MODE`, `DRAG_FRAMES`, ver cabecera del script).
- **Pruebas estadísticas que pueden variar entre corridas** (no son necesariamente regresiones; repetir): *test_full_match (eliminada en la reforma)* (tiros ≥ 2), *test_ai_match (eliminada en la reforma)* (arqueros enfrentan tiros / nadie sale de la cancha), `test_shot_keeper`.
- Una prueba nueva = `tests/test_<tema>.gd` (`extends TestCase`; helpers `make_match`, `add_player`, `wait_seconds`, `physics_frames`, `check`, `note`, `cleanup`).

## 5. APK de prueba (CI)

1. Commit + push a la rama de la sesión.
2. GitHub Actions → **Android APK** (`android.yml`) → *Run workflow* en esa rama con `publish_release: true` (vía MCP: `actions_run_trigger` `run_workflow`, `inputs {"publish_release":"true"}`).
3. ~10 min: pre-release `apk-prueba-N` con `futbol5-v0.1.N.apk` (firma de depuración; desinstalar la anterior).
4. Un fallo de prueba estadística en CI → `rerun_failed_jobs` tras confirmar que pasa en local; si es real, corregirlo.
5. **No publicar una versión como terminada hasta comprobar que lo pedido mejoró de verdad.**

## 6. Assets y herramientas

- `assets/animations/`: `pack_clips.res`, `pack_keeper.res` (Mixamo), `mocap_clips.res` (mocap), `footballer_clips.res` (Tripo), `touch_clips.res`. **Se regeneran offline**, no a mano:
  `tools/animation_pack/build_pack_library.tscn`, `build_mocap_library.tscn` (clips), `build_mocap_character.tscn` (modelo Newton). Uso: `godot --headless --path . res://tools/animation_pack/<x>.tscn`.
- `pack/` (FBX originales del mocap) **no está en el repo** (`.gitignore`); solo se necesita para regenerar.
- `assets/characters/player/` modelo de Tripo; `assets/characters/mocap/` modelo Newton + `mocap_kit.gdshader`; `assets/characters/json/` modelo del modo 4 (`json_human.scn`, `json_kit.gdshader`) y `assets/animations/json_clips.res` / `json_scenes.res` / `json_keeper.res`.
- `tools/docs_index.py` (índice), `tools/measure_*.gd`, `render_clip_sheet.gd`, `glb_inspect.py` (medición/inspección).

## 7. Mapa de la documentación (leer solo lo que toque)

- `docs/technical-index/INDEX.md` — tabla de sistemas → archivos, símbolos, parámetros, fichas.
- `docs/technical-index/SYSTEMS/*.md` — una ficha por sistema (BALL, PLAYER, ANIMATIONS, ANIMATION_PACK, GOALKEEPER, MATCH, CAMERA, AUDIO, UI_HUD, TUNING, TESTING, ANDROID, TOOLS_AND_ASSETS…).
- `docs/technical-index/ARCHITECTURE.md` — capas, convenciones, números fijos del código.
- `docs/technical-index/CHANGELOG.md` — historial con lo realmente verificado.
- `docs/technical-index/GAMEPLAY_PES.md` — referencia de jugabilidad PES 2021 y diagnóstico.
- `CLAUDE.md` — reglas del proyecto (se carga solo).

## 8. Plantilla para pedirle cambios a otro chat

> «Lee `docs/START_HERE.md`. Quiero [cambio]. Busca con `docs_index.py find`, cambia lo mínimo, corre la prueba del sistema, sincroniza docs y haz commit en la rama de la sesión. No abras PR.»
