# REFORMA — Tiros libres y penales: menú de desarrollo y banco de pruebas de animaciones

## Identificación

- **Qué es:** la herramienta de la Fase 1 de la reforma del juego a tiros libres y penales (rama `reforma-tiros-penales`):
  un banco de pruebas que compara los tres bancos de animación (**JSON original**, **Mixamo**, **Mocap**) por separado y bajo
  las mismas condiciones, y el menú de desarrollo que es la entrada del juego durante la reforma.
- **Estado (2026-11-07):** Fase 1 entregada para que el usuario pruebe la APK y elija banco. No es el juego final: no elige
  banco, no mezcla bancos y no integra nada en tiros libres ni penales.
- **Informe y plan:** [`docs/reforma/FASE0_AUDITORIA_Y_PLAN.md`](../../reforma/FASE0_AUDITORIA_Y_PLAN.md),
  [`docs/reforma/FASE1_INFORME.md`](../../reforma/FASE1_INFORME.md).

## Piezas

| Archivo | Qué hace |
|---|---|
| `scripts/dev/dev_menu.gd`, `scenes/dev/dev_menu.tscn` | `DevMenu`: menú de desarrollo (abre el banco de pruebas). Desde 2026-11-08 la escena principal es el menú del juego (`scenes/setpiece/main_menu.tscn`, ficha [SETPIECE](SETPIECE.md)), que también abre el banco de pruebas. El modo de fútbol 5 se quitó de esta rama: ver `docs/reforma/FUTBOL5_QUITADO.md`. |
| `scripts/dev/anim_bank_bench.gd`, `scenes/dev/anim_bank_bench.tscn` | `AnimBankBench`: selector de banco (carga solo sus bibliotecas), cuerpo común (humano JSON) o cuerpo original del banco (diagnóstico), categorías de tirador, barrera y arquero, «sin clip en este banco», golpe de referencia en el instante de contacto del clip, marcador de las manos en atajadas, mediciones en vivo, secuencia reposo → clip → reposo del mismo banco, tres cámaras fijas y zoom. |
| `scripts/dev/anim_bank_catalog.gd` | `AnimBankCatalog`: lectura del catálogo por procedencia y material del uniforme de cada cuerpo. |
| `resources/animation/catalogo_bancos.json` | Catálogo generado (entra en la APK). |
| `tools/reforma/build_bank_catalog.gd` | Genera el catálogo y los CSV por banco (`docs/reforma/fase1/catalogo_*.csv`) sin tocar las bibliotecas. |
| tools/reforma/bank_compat.gd (borrado: Mixamo/Mocap) | Mide la compatibilidad de los bancos con los dos cuerpos (reposo, pies, desvío de la pose, error de contacto, saltos de pose). |
| `tools/reforma/bench_captures.gd`, `tools/reforma/bench_captures.tscn` | Capturas y mediciones del banco con render. |
| `tests/test_anim_bank_bench.gd` | Pruebas del banco (procedencia, selector, categoría vacía, pistas, golpe en el contacto con render, menú). |

## Reglas

- Ningún banco se modifica ni se mezcla con otro; una categoría vacía no se rellena con clips de otro banco.
- Mixamo y Mocap se convirtieron para el futbolista (`player_base.glb`) y el JSON para el humano JSON: sus reposos de hueso
  difieren hasta 177°, así que sobre el cuerpo ajeno la pose se deforma (medido; ver el informe). No se corrige sin
  autorización del usuario.

- Modo de fútbol 5 quitado de la rama (sin escena, acceso ni pruebas de juego abierto); su código queda como librería sin
  acceso porque los sistemas reutilizados lo nombran (se desacopla en la Fase 3).

## Riesgos

- El banco JSON ocupa ~78 MB de memoria al cargarlo (escritorio); cargar solo el banco elegido es obligatorio en Android.
- Las clasificaciones de atajadas por medición usan umbrales (0,9 m al costado, 2,0 m de altura, 0,6 m baja); están en el
  catálogo (`criterios`).
