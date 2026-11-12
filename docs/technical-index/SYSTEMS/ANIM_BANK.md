# ANIM_BANK — Bibliotecas ACTUAL y MIXAMO, selector y laboratorio

## Identificación

- **Responsabilidad exacta:**
  - elegir la biblioteca de animaciones del juego (ACTUAL o MIXAMO, `AnimBank`);
  - convertir los 133 clips de `animaciones_mixamo.zip` al esqueleto del juego (`tools/mixamo/`);
  - integrarlos por rol con respaldo actual (`SpClips`, `PackLibrary`), por tipo de tiro (`ShotCatalog`) y por pelota
    en el arquero (`KeeperPlanner`);
  - el laboratorio de animaciones (`AnimLab`);
  - las bibliotecas derivadas y los GLB fuente en el repositorio (los GLB no entran en la APK).
- **Estado real:**
  - conviven las dos bibliotecas; el juego arranca en ACTUAL;
  - MIXAMO se elige en el laboratorio;
  - **no probado en el teléfono.**
  - Informe completo: [`docs/animaciones/MIXAMO_INTEGRACION.md`](../../animaciones/MIXAMO_INTEGRACION.md).
- **Última verificación:** <!-- AUTO:verified -->
2026-11-12
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función |
|---|---|
| `scripts/animation/anim_bank.gd` | `AnimBank`: biblioteca activa (`user://anim_bank.cfg`; `ANIM_BANK=mixamo|actual` para herramientas y pruebas), disponibilidad, cambio con vaciado de cachés |
| `scripts/setpiece/sp_clips.gd` | Carga por biblioteca; `by_role` con Mixamo primero; `fallback_roles()` |
| `scripts/animation/pack_library.gd` | `_add_mixamo`: copias de las bibliotecas, roles y nombres del paquete hacia Mixamo; `actual_by_role` |
| `scripts/setpiece/shot_catalog.gd` | `path()` según la biblioteca; `mixamo_filter` por tipo de tiro |
| `scripts/goalkeeper/keeper_planner.gd` | `plan_save`: Mixamo primero, respaldo actual si ninguna llega con holgura |
| `scripts/setpiece/sp_field_players.gd` | Defensores: `defend` (llegan marcando) y `dir_loop` (retroceden mirando la pelota) |
| `scripts/setpiece/sp_shooter.gd` | `_loop_for`: con MIXAMO, también carrera y sprint de Mixamo |
| `scripts/dev/anim_lab.gd`, `scenes/dev/anim_lab.tscn` | Laboratorio (desarrollo) |
| `tools/mixamo/inspect_mixamo.gd` | Inventario de los GLB (huesos, reposo, pistas) |
| `tools/mixamo/export_mixamo_joints.gd` | GLB → articulaciones del juego (proporciones, raíz reconstruida, contacto, velocidad sobre el suelo) |
| `tools/mixamo/selection_mixamo.json` | Los 133 clips: rol, biblioteca, espejo, opciones |
| `tools/mixamo/dump_inventory.gd`, `make_inventory_doc.py`, `lab_capture.gd` | Inventario por rol, documento generado, capturas con render |
| `tests/test_mixamo_bank.gd` | Pruebas de la integración |
| `tools/json_anim/build_tripo_body.gd` → `assets/characters/json/tripo_body.scn` | Cuerpo con el modelo de Tripo del usuario (marcos de reposo con polos, bind recalculado); es el único cuerpo del juego (`AnimBank.BODY_PATH`; el humanoide JSON se eliminó el 2026-11-12) |

## Funciones

<!-- AUTO:funcs:scripts/animation/anim_bank.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `AnimBank.notifier()` | 35 |  |
| `AnimBank._load()` | 40 |  |
| `AnimBank.mixamo_available()` | 57 | true si la build trae las bibliotecas de Mixamo. |
| `AnimBank.current()` | 63 | Biblioteca en uso (MIXAMO solo si esta disponible). |
| `AnimBank.is_mixamo()` | 69 |  |
| `AnimBank.current_name()` | 72 |  |
| `AnimBank.set_bank(b: int, save: bool = true)` | 77 | Cambia la biblioteca: guarda la preferencia (save = true), vacia los caches de clips de SpClips, PackLibrary y ShotCatalog y avisa. Los acto |
| `AnimBank.reset_for_tests()` | 94 | Pruebas: vuelve a leer la preferencia y la disponibilidad. |
| `AnimBank.is_mixamo_id(id: StringName)` | 98 |  |
| `AnimBank.body_path()` | 108 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/dev/anim_lab.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `AnimLab._ready()` | 116 |  |
| `AnimLab.bank_libraries(bank: int)` | 132 |  |
| `AnimLab.category_of(role: String)` | 135 |  |
| `AnimLab.catalog(bank: int)` | 144 | {categoria: [ids]} de una biblioteca (sin espejos), ordenados por rol y por id. |
| `AnimLab.clip_count(bank: int)` | 170 |  |
| `AnimLab._station(bank: int)` | 178 |  |
| `AnimLab._visible_stations()` | 223 |  |
| `AnimLab.set_mode(m: int)` | 230 |  |
| `AnimLab._cam_dir()` | 250 | Direccion (horizontal) desde el centro de las estaciones hacia la camara, segun la vista. |
| `AnimLab._layout()` | 260 |  |
| `AnimLab.select_category(c: String)` | 278 |  |
| `AnimLab.step(bank: int, d: int)` | 285 | Cambia de clip en una estacion (d = +1 / -1); con una sola visible, en esa. |
| `AnimLab.select_situation(name_: String)` | 295 | La misma accion en las dos bibliotecas. |
| `AnimLab.restart()` | 314 |  |
| `AnimLab._start(st: Station)` | 333 |  |
| `AnimLab._pose(st: Station, t: float)` | 373 | Instante t del clip en una estacion: pose (seek), raiz, rumbo, golpe de referencia en el contacto y mediciones. |
| `AnimLab._bone(st: Station, b: String)` | 391 |  |
| `AnimLab._measure(st: Station, delta: float)` | 394 |  |
| `AnimLab._process(delta: float)` | 406 |  |
| `AnimLab.toggle_play()` | 425 |  |
| `AnimLab.set_speed(v: float)` | 429 |  |
| `AnimLab.set_view(v: int)` | 435 |  |
| `AnimLab._aim_camera()` | 440 |  |
| `AnimLab.info_text(st: Station)` | 455 | Texto de informacion de una estacion (lo leen las pruebas). |
| `AnimLab._status_of(st: Station, role: String)` | 494 | En el juego: si este clip se usa con la biblioteca que este elegida. |
| `AnimLab._role_of(bank: int, id: StringName)` | 504 |  |
| `AnimLab.station_info(bank: int)` | 514 |  |
| `AnimLab._build_ui()` | 522 |  |
| `AnimLab._button(text: String, cb: Callable)` | 618 |  |
| `AnimLab._style(l: Label, size: int)` | 627 |  |
| `AnimLab._refresh_ui()` | 633 |  |
| `AnimLab._refresh_info()` | 658 |  |
| `AnimLab._toggle_game_bank()` | 668 | Biblioteca que usa el JUEGO (penales, tiros libres, arquero, festejos...). Se guarda y vale al entrar a un modo. |
| `AnimLab._play_in_game(m: int)` | 673 | Situacion real: el modo del juego con la biblioteca elegida en «Juego». |
| `AnimLab._go_back()` | 677 |  |
<!-- /AUTO -->

## Pruebas

<!-- AUTO:tests:tests/test_mixamo_bank.gd -->
| Prueba | Línea |
|---|---|
| `test_actual_is_the_default_and_loads_nothing_from_mixamo` | 33 |
| `test_every_mixamo_clip_loads_with_its_role` | 47 |
| `test_mixamo_uses_mixamo_per_role_and_actual_as_fallback` | 84 |
| `test_every_mixamo_clip_is_reachable_by_its_role` | 121 |
| `test_mixamo_shot_catalog_uses_mixamo_kicks` | 139 |
| `test_keeper_plans_with_mixamo_and_falls_back_only_when_needed` | 167 |
| `test_lab_loads_only_what_it_shows_and_compares_the_same_situation` | 204 |
| `test_switching_bank_at_runtime_plays_a_penalty` | 237 |
| `test_defenders_track_back_with_directional_loops` | 257 |
<!-- /AUTO -->

## Dependencias

- **Depende de:**
  - JSON_MODE: `JsonRig`, `JsonRetarget`, convertidor `build_json_library`;
  - SETPIECE: `SpClips`, `SpActor`, `ShotCatalog`;
  - GOALKEEPER: `KeeperPlanner`.
- **Lo usan:** todos los sistemas que piden clips por rol (penales, tiros libres, arquero, festejos, reacciones, menú,
  Botón de caída, modo partido).

## Riesgos

- Con MIXAMO se cargan las dos bibliotecas (las actuales son respaldo de 53 roles): +3,6 MB. Sin medir en el teléfono.
- La raíz de Mixamo es reconstruida. Los clips con poco apoyo detectado (barridas, zancadilla, Defender, algunas caídas)
  pueden deslizar.
- Mixamo tiene pocos golpeos:
  - sin exterior y con pocos ángulos;
  - con ANIM_BANK=mixamo fallan 2 pruebas de calidad de `test_setpiece_modes`.
- La APK trae MIXAMO (+3,6 MB) aunque el juego arranque en ACTUAL.
