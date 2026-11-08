# Fase 1 — Verificación de no regresión

Commit verificado: `5511cfe` (trazabilidad `AnimTrace` + overlay `AnimDebugOverlay`). Línea base: `04ed110`.

## 1. Pruebas

| Prueba | Resultado | Registro |
|---|---|---|
| Suite headless (`tools/run_tests.sh`) | 318 pruebas, 0 fallidas, 28 omitidas, 3.036 comprobaciones, 0 fugas | [`pruebas/suite_headless.log`](pruebas/suite_headless.log) |
| `test_anim_trace` (nueva) | 8/0 | dentro de la suite |
| Render: live_feet / live_kicks / pack_motion / json_mode | 7/0 · 6/0 · 2/0 · 10/0 | `pruebas/render_*.log` |
| Render: physical_dribble / directional_kicks / dribble_reference / test_receive | 5/0 · 3/0 · 2/0 · 30/0 | `pruebas/render_*.log` |

Ninguna batería informa fugas («ObjectDB instances were leaked» / «resources still in use at exit»: 0 líneas).

## 2. Equivalencia del código con la traza apagada

Todos los enganches nuevos están bajo `if AnimTrace.enabled` o `if not _trace_*.is_empty()` (diccionarios que solo se
llenan con la traza encendida). Revisión del diff de `5511cfe`, sistema por sistema:

- `ActionArbiter`, `KeeperPlanner`, `Goalkeeper`, `JsonBallMove`, `JsonReceive`, `BallHandler`: solo líneas añadidas
  dentro de esos condicionales; las llamadas que antes se usaban en un `if` (`_start`, `start_receive`,
  `_start_clip_kick`, `start_move`, `start`) se guardan en una variable y se usan igual.
- `PlayerActions.try_locomotion_transition`: el sorteo consume el mismo `rng.randf()` y pide el mismo candidato; antes
  devolvía dentro del bucle, ahora sale del bucle y pide una vez (mismo clip, misma llamada).
- `PlayerActions.transition_score`: cada `return INF` pasa por `_no(id, motivo)`, que devuelve `INF` y solo registra
  con la traza encendida.
- `JsonCatalog.kick_candidates`: el filtro se movió a `kick_clip_rejection` con la misma condición.
- `MatchScene`: crea el `AnimDebugOverlay` en compilaciones de depuración, inactivo (sin `_process`, sin entrada).
- Ningún enganche consume azar ni lee el reloj; el único uso de reloj de pared en el juego (`Ball.last_touch_msec`) no
  decide nada (solo informa «interferido» en el registro del golpeo).

`test_anim_trace::test_tracing_does_not_change_any_decision` comprueba además que las decisiones son idénticas
con la traza encendida y apagada en el mismo escenario.

## 3. Métricas de partido frente a la línea base

Herramienta: `fase0/medicion/medir_linea_base.py` (partidos IA contra IA de 10 min, semillas fijadas) y
`fase0/medicion/comparar_con_base.py` (umbrales del §10 de la auditoría y p de una prueba de permutación).

| Comparación | Resultado | Archivo |
|---|---|---|
| Fase 1 vs base, semillas 101–606 (6 + 6) | supera solo «% pérdida tras recepción animada»: 32,5 % frente a 28,1 % (límite 29,5 %) | [`comparacion_metricas.md`](comparacion_metricas.md) |
| Fase 1 vs base, semillas 101–1212 (12 + 12) | sigue superándolo: 30,8 % frente a 25,6 % (límite 26,9 %), p = 0,17; el resto dentro | [`comparacion_metricas_12.md`](comparacion_metricas_12.md) |
| Fase 1 vs base, semillas 101–1616 (16 + 16; la ampliación a 24 + 24 se cortó por un reinicio de la sesión tras 4 semillas más) | sigue superándolo: 30,0 % frente a 25,8 % (límite 27,1 %), p = 0,17; el resto dentro | [`comparacion_metricas_16.md`](comparacion_metricas_16.md) |
| **Base vs base** (mismo código `04ed110`, semillas 101–606 frente a 707–1212) | la misma métrica cambia −4,9 pp (28,1 → 23,2 %) sin ningún cambio de código; «% golpeos sin contacto» da p = 0,013 | [`../fase0/comparacion_base_vs_base_s707_1212.md`](../fase0/comparacion_base_vs_base_s707_1212.md) |

Dispersión por partido de la métrica: ±8,5 pp (base) y ±9,4 pp (Fase 1) con 12 partidos; el error típico de la
diferencia de medias es ≈ 3,7 pp, del orden del umbral (+5 % relativo ≈ 1,3 pp).

Estado: el umbral de la métrica está superado con 12 y con 16 partidos por lado (p = 0,17 en ambos casos: la diferencia
no se distingue del ruido entre partidos, pero el umbral se informa como superado). Siguiendo el §10 («antes de declarar
un aborto, repetir con más semillas») quedan por medir las semillas 1717–2424 en los dos commits para llegar a 24 + 24.
**La fase no está cerrada.** Instrucciones exactas: [`../CONTINUAR_GUIA_ANIMACIONES.md`](../CONTINUAR_GUIA_ANIMACIONES.md) §5.1.

## 4. Integridad

- 2.022 JSON originales + índice: 2.023/2.023 hashes iguales a `fase0/hashes_json_originales.sha256`.
- Recursos de animación (`fase0/hashes_recursos_animacion.sha256`): 46/47 iguales; difiere solo
  `scripts/animation/json_catalog.gd` (cambio de código intencional de las fases 1 y 2). `animdb.json`, bibliotecas y
  `.res` sin cambios.
- `respaldo-f3` sin cambios (`3d47a07`).
