# Estado de la reforma: tiros libres y penales

Leer primero en un chat nuevo (junto con [`CONTINUAR_REFORMA.md`](CONTINUAR_REFORMA.md), que trae el prompt para pegar, y
[`INSTRUCCION_REFORMA.md`](INSTRUCCION_REFORMA.md), la instrucción completa del usuario). Última actualización: 2026-11-08.

## Rama y reglas

- Rama de trabajo: **`reforma-tiros-penales`** (creada desde `integracion-openai` en `9c6f82a`, autorizada por el usuario).
  No modificar `integracion-openai` (rama original) ni `respaldo-f3` (`3d47a07`). Sin PR ni merges salvo pedido expreso.
- Orientación **horizontal obligatoria** (16:9; otras proporciones sin deformar el campo). Nunca vertical.
- Fases con autorización: al terminar cada una se entrega informe, archivos, pruebas y APK, y **se espera autorización**
  antes de la siguiente.
- Bancos de animación: no elegir ganador, no mezclar bancos, no rellenar huecos con otro banco, no modificar originales.
  La elección la hace el usuario después de probar la APK.
- Supabase: todavía no se conecta nada.
- **El modo de fútbol 5 se quitó de esta rama** (pedido del usuario): sin escena, sin acceso y sin pruebas de juego abierto.
  Se conservan animaciones, física y sistemas reutilizables; detalle en [`FUTBOL5_QUITADO.md`](FUTBOL5_QUITADO.md). El partido
  completo sigue en `integracion-openai`.
- Modo tiro libre (requisitos del usuario, §9.3 del plan): barrera real y jugadores sueltos de los dos equipos; nadie más
  remata; los defensores solo interrumpen o despejan si llegan a una pelota que va al arco; los compañeros se mueven como
  para un centro o un rebote; objetivo: gol de tiro libre directo.

## Fases

| Fase | Estado | Documento |
|---|---|---|
| 0 Auditoría y plan | entregada | [`FASE0_AUDITORIA_Y_PLAN.md`](FASE0_AUDITORIA_Y_PLAN.md) |
| 1 Bancos: selector y comparación | **entregada, esperando decisión del usuario** | [`FASE1_INFORME.md`](FASE1_INFORME.md) |
| 2 Comparación visual (escenas equivalentes) | no empezada (parte ya cubierta por el banco de pruebas de la Fase 1) | — |
| 3–11 | no empezadas | plan en la Fase 0 |

## Decisión pendiente (Fase 1, §6 del informe)

Mixamo y Mocap se convirtieron para el futbolista (`player_base.glb`) y se deforman sobre el humano JSON (reposos de hueso
distintos hasta 177°). Opciones presentadas: **A** retarget en memoria al humano JSON (sin tocar archivos), **B** comparar
cada banco sobre su cuerpo original (ya disponible en el banco de pruebas), **C** otra. No avanzar sin la respuesta.

## Dónde está cada cosa

- Banco de pruebas: `scenes/dev/anim_bank_bench.tscn` (`scripts/dev/anim_bank_bench.gd`); menú de desarrollo:
  `scenes/dev/dev_menu.tscn` (escena principal). Ficha técnica: `docs/technical-index/SYSTEMS/REFORMA.md`.
- Catálogo por procedencia: `resources/animation/catalogo_bancos.json` (generar con
  `godot --headless --path . --script res://tools/reforma/build_bank_catalog.gd`).
- Compatibilidad de bancos: `godot --headless --path . --script res://tools/reforma/bank_compat.gd -- --out docs/reforma/fase1/compatibilidad`.
- Capturas con render: `xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --resolution 1280x720 --path . res://tools/reforma/bench_captures.tscn -- --out <dir>`
  (escena y no `--script`: los scripts del juego usan el autoload `Tuning`).
- Pruebas: `tools/run_tests.sh test_anim_bank_bench` (y con render, ver `docs/START_HERE.md`).
- APK: GitHub Actions «Android APK» se dispara con cada push de código a `reforma-tiros-penales`; artefacto `futbol5-apk`.
  Última: compilación 68 (`ccc5592`), https://github.com/roldanhr98-byte/Futbol5/actions/runs/42380816763 (vence el 21-11-2026).

## Pendientes conocidos

- Ticket [`F9-002`](../integration/tickets/F9-002_pelota_quieta_en_partido.md): fallas intermitentes de pruebas de partido de
  fútbol 5; cerrado en esta rama al quitarse el modo (siguen en `integracion-openai`).
- Medición en Android (rendimiento de cada banco, tacto) depende de pruebas del usuario en su teléfono.
