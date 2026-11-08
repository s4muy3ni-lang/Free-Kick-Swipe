# Bancos Mixamo y Mocap: quitados del juego

Fecha: 2026-11-08. Pedido del usuario: «Vamos a usar las 2.022 animaciones de JSON nomás; las otras, Mocap y Mixamo, borralas:
no las quiero más» (el usuario dijo 2.002; el banco verificado tiene **2.022** archivos). Rama:
`claude/init-repo-reforma-tiros-c7vapt` de `s4muy3ni-lang/Free-Kick-Swipe`.

**Qué queda:** el banco **JSON original** (`assets/animations/json_clips.res`, `json_keeper.res`, `json_scenes.res`, el
humano `assets/characters/json/json_human.scn` y `assets/animations/animdb.json`) es el único banco de animación. Los modos
de penales y tiros libres ya usaban solo este banco. Los clips de **Tripo** (`assets/animations/footballer_clips.res`, el
modelo `assets/characters/player/player_base.glb` y sus fuentes `assets/animations/source/`) **no se tocaron**: no son uno
de los tres bancos comparados; son el respaldo del código heredado del partido. Quitarlos es una decisión aparte.

**Dónde recuperar lo quitado:** en el historial de este repositorio (commit anterior a este cambio) y en el repositorio
viejo `roldanhr98-byte/Futbol5`, que se conserva sin cambios.

## Archivos quitados (45 más sus `.uid`)

- **Animaciones de Mixamo** (pack convertido): `assets/animations/pack_clips.res` (campo, 133 clips),
  `assets/animations/pack_keeper.res` (arquero) y `assets/animations/touch_clips.res` (toques de conducción derivados).
- **Animaciones de Mocap** («Mocap Pack 05 Soccer»): `assets/animations/mocap_clips.res` y el personaje propio
  `assets/characters/mocap/` (`mocap_player.scn`, `mocap_kit.gdshader`).
- **Código del modo Mocap:** `scripts/animation/mocap_rig.gd` (`MocapRig`).
- **Herramientas de conversión y evaluación de esos bancos:** la carpeta `tools/animation_pack/` completa (conversores del
  pack y del mocap, retarget, toques, hojas de clips, métricas y su `README.md`) y `tools/reforma/bank_compat.gd`
  (comparación de compatibilidad de los tres bancos).
- **Pruebas de los modos 1 (Mixamo) y 2 (Mocap):** `tests/test_pack_kick.gd`, `tests/test_pack_locomotion.gd`,
  `tests/test_pack_retarget.gd`, `tests/test_player_model.gd`, `tests/test_animation_contact_audit.gd`,
  `tests/test_animation_inventory.gd` y la prueba de transiciones de marcha del pack de `tests/test_keeper_and_gait_clips.gd`.
  Las mismas funciones del banco JSON siguen probadas (`test_bank_integration`, `test_json_mode`, `test_setpiece_*`).

## Cambios para que el resto funcione sin ellos

- `PackLibrary`: ya no carga ni nombra las bibliotecas de Mixamo, toques ni Mocap; en el modo 4 carga el banco JSON (como
  antes) y en el modo 3 no carga nada (Tripo).
- `Tuning`: los modos de jugabilidad son 3 (Tripo, respaldo heredado) y 4 (Json, el del juego); una preferencia guardada
  con el modo 1 o 2 pasa al 4.
- `FootballerVisual`, `AnimationCatalog`, `SetPiece`, `Referee`, `PracticeScene`: sin las ramas del modo Mocap.
- Banco de pruebas de animaciones (`AnimBankBench`, `AnimBankCatalog`): solo el banco JSON; `resources/animation/catalogo_bancos.json`
  conserva únicamente la sección `json` (idéntica a la anterior).
- Workflow de la APK: ya no exige las bibliotecas de Mixamo; exige el banco JSON y el catálogo de golpeos y **falla si una
  biblioteca de Mixamo o Mocap vuelve** al repositorio o aparece dentro de la APK.
- Pruebas: `test_anim_bank_bench` verifica que el catálogo y el reproductor tienen solo el banco JSON y que los archivos de
  Mixamo y Mocap no existen; las preguntas de las pruebas del arquero y los golpeos ahora nombran las bibliotecas JSON
  (antes, mensajes heredados del pack).

## Documentos históricos

Los informes de la Fase 0 y la Fase 1 (`docs/reforma/FASE0_AUDITORIA_Y_PLAN.md`, `docs/reforma/FASE1_INFORME.md`,
`docs/reforma/fase1/`) y las fichas viejas que describen el pack quedan como historia de la comparación: describen archivos
que ya no están en el repositorio.
