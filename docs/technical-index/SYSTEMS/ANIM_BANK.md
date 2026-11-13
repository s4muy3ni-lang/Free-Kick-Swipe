# ANIM_BANK — Cuerpo y banco de animaciones de los jugadores

## Identificación

- **Responsabilidad exacta:**
  - el cuerpo de los jugadores de penales, tiros libres y minijuegos: el modelo de Tripo del usuario adaptado al
    esqueleto del juego (`AnimBank.BODY_PATH`, `tools/json_anim/build_tripo_body.gd`);
  - es el único cuerpo: el humanoide JSON se eliminó del juego y de los archivos el 2026-11-12 (pedido del usuario);
  - las animaciones son las del banco JSON (`SpClips`, `PackLibrary`, `ShotCatalog`).
- **Historia (2026-11-12):**
  - la biblioteca de Mixamo (133 clips de `animaciones_mixamo.zip` convertidos al esqueleto, selector «Animaciones:
    ACTUAL/MIXAMO» y laboratorio de comparación) se sumó y se **eliminó el mismo día**: «son muy feas y básicas»;
  - se borraron sus bibliotecas, GLB fuente, catálogo de golpeos, herramientas («tools/mixamo»), laboratorio y
    pruebas;
  - el CI falla si vuelven a la APK.
- **Estado real:** un solo cuerpo y un solo banco; **no probado en el teléfono.**
- **Última verificación:** <!-- AUTO:verified -->
2026-11-13
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función |
|---|---|
| `scripts/animation/anim_bank.gd` | `AnimBank.BODY_PATH` / `body_path()`: el cuerpo de los jugadores |
| `tools/json_anim/build_tripo_body.gd` → `assets/characters/json/tripo_body.scn` | Cuerpo con el modelo de Tripo del usuario: marcos de reposo con polos, bind recalculado y la posición de reposo en CUSTOM0 (número impreso, diseños pegados a la tela) |
| `scripts/setpiece/sp_actor.gd` | Arma el actor con ese cuerpo; `arm_extra`, `hand_point`, `toe_tip` compensan sus proporciones |

## Funciones

<!-- AUTO:funcs:scripts/animation/anim_bank.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `AnimBank.body_path()` | 14 |  |
<!-- /AUTO -->

## Pruebas

- `tools/run_tests.sh back_number`: la malla trae la posición de reposo, el número va impreso y el humanoide no está.
- Con render: `test_setpiece_render`, `test_keeper_zones`, `test_keeper_in_position` (cuerpo de Tripo en juego).

## Riesgos al modificar

| Elemento | Efecto real y riesgo |
|---|---|
| Volver a generar `tripo_body.scn` | Cambia el reposo y la piel de todos los jugadores: correr las pruebas con render y mirar capturas (`tools/ui/number_capture.gd`). |
| Proporciones de Tripo | Brazos ~11 cm más cortos y punta del pie a mitad del pie: lo compensan `SpActor.arm_extra` / `toe_tip` y `BallHandler._sample_feet`. |
