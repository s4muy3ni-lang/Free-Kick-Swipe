# Seguimiento de la guía maestra del sistema de animaciones

Documento único de seguimiento por etapa (formato de la sección 17 de la guía). Cada etapa: estado inicial, problema
confirmado, archivos, cambio, sistemas reutilizados, pruebas, comparación, criterios de aborto, pendientes, integridad y
commit. Niveles de evidencia que no se mezclan: registrado · importado · seleccionable · invocado · completado · contacto
validado · visualmente correcto en render · probado en Android.

Línea base: tag local `pre-audit-phase-0` = `04ed110`. Métricas base: [`fase0/linea_base/`](fase0/linea_base/).
Pruebas de bloqueo y umbrales: [`AUDITORIA_PRE_IMPLEMENTACION.md`](AUDITORIA_PRE_IMPLEMENTACION.md) §9 y §10.

---

## Etapa 0 — Auditoría del repositorio y línea base

1. **Estado inicial:** `integracion-openai` en `04ed110`, árbol limpio; código idéntico a `5fb4f27`.
2. **Problema confirmado:** ver la auditoría del 2026-11-07 (`AUDITORIA_SISTEMA_ANIMACIONES.md`); cifras re-medidas.
3. **Archivos involucrados:** ninguno de juego.
4. **Cambio realizado:** documentación, herramienta de medición, línea base, hashes, ticket F9-001.
5. **Sistemas reutilizados:** todos sin cambios.
6. **Pruebas:** suite headless 310/0 (28 omitidas, 2.992 comprobaciones); 8 baterías con render 0 fallidas; 0 fugas;
   6 partidos de 10 min + 1 de 3 min con render (`fase0/linea_base/`).
7. **Comparación:** es la base.
8. **Criterios de aborto:** definidos en `AUDITORIA_PRE_IMPLEMENTACION.md` §10.
9. **Pendientes:** subir el tag (bloqueado por el proxy de la sesión); determinismo (F9-001, Fase 9).
10. **Integridad:** 2.023/2.023 hashes de los JSON originales (ZIP subido, sha256 `3fa72c92…d8b374f`); 47/47 hashes
    de recursos; `respaldo-f3` = `3d47a07`.
11. **Commit:** `7c1e9da` (Fase 0) y el commit que agrega este documento y los hashes de los originales.

---

## Etapa 1 — Trazabilidad de candidatos y overlay de depuración

1. **Estado inicial:** `44ee432` (Fase 0 cerrada). No había forma de saber por qué un clip no salía en partido.
2. **Problema confirmado:** los planificadores descartan candidatos sin dejar el motivo; el árbitro solo guarda un
   registro de texto; no había vista en partido del punto del cuerpo previsto frente a la pelota.
3. **Archivos involucrados:** `scripts/diagnostics/anim_trace.gd`, `scripts/diagnostics/anim_debug_overlay.gd` (nuevos);
   enganches en `action_arbiter.gd`, `ball_handler.gd`, `json_receive.gd`, `json_ball_move.gd`, `keeper_planner.gd`,
   `goalkeeper.gd`, `player_actions.gd`, `footballer.gd`, `json_catalog.gd`, `match_scene.gd`; `tests/test_anim_trace.gd`.
4. **Cambio realizado:** `AnimTrace` con el esquema fijo de 35 columnas (exportación CSV/JSON, apagado por defecto y solo
   en depuración), `explain(id)` por categoría; overlay F3/F4 con árbitro, decisión, candidatos y marcadores 3D.
5. **Sistemas reutilizados:** todos los planificadores y `ActionArbiter` sin cambio de lógica; ningún predictor ni
   árbitro nuevo.
6. **Pruebas:** suite headless 318/0 (28 omitidas, 3.036 comprobaciones, 0 fugas); 8 baterías con render 0 fallidas
   (`fase1/pruebas/`); `test_anim_trace` 8/0 (incluye «la traza no cambia ninguna decisión» y un partido real de 90 s).
7. **Comparación:** [`fase1/FASE1_VERIFICACION.md`](fase1/FASE1_VERIFICACION.md). Con 6, 12 y 16 partidos por lado,
   todo dentro de los umbrales salvo «% pérdida tras recepción animada» (16 + 16: 30,0 % frente a 25,8 %, límite
   27,1 %, p = 0,17). La base contra sí misma (mismo código, otras semillas) mueve esa métrica −4,9 pp.
8. **Criterios de aborto:** umbral superado en una métrica → la fase **no se cierra** todavía; falta completar 24 + 24
   (semillas 1717–2424; la medición se cortó por un reinicio de la sesión tras 1313–1616). Herramientas nuevas: `comparar_con_base.py` (umbrales + p de
   permutación, varios archivos por lado) y `medir_linea_base.py --recalcular` (métricas nuevas de contacto p95,
   ≤ 0,20 m, ≤ 0,30 m recalculadas sobre los mismos partidos de la base; las métricas existentes no cambian).
9. **Pendientes:** semillas 1717–2424 en `04ed110` y `5511cfe` y decisión de cierre (ver `CONTINUAR_GUIA_ANIMACIONES.md` §5.1); subir el tag `pre-audit-phase-0` (proxy).
10. **Integridad:** originales 2.023/2.023; recursos 46/47 (solo `json_catalog.gd`, cambio de código); `respaldo-f3` = `3d47a07`.
11. **Commit:** `5511cfe` (código) y el commit de esta verificación.

---

## Etapa 2 — Los 322 segmentos conectados pero no seleccionables (ABIERTA)

1. **Estado inicial:** `5511cfe` (Fase 1, verificación pendiente de cierre).
2. **Problema confirmado:** 322 tramos con rol y consumidor que el filtro del consumidor descarta siempre: 176 por raíz o
   duración (situaciones), 121 por contacto no limpio, 13 sin toques medidos, 12 golpeos girando con el pie alto.
3. **Archivos involucrados:** `scripts/animation/json_catalog.gd`; `tests/test_kick_recovery.gd` (nuevo);
   `docs/integration/fase2/` (tabla, generador, informe).
4. **Cambio realizado:** tabla por segmento con dato, valor, umbral, causa, acción, decisión y estado
   ([`fase2/FASE2_DIAGNOSTICO_322.md`](fase2/FASE2_DIAGNOSTICO_322.md), `fase2/diagnostico_322.csv`). Habilitados 54
   golpeos (108 variantes) que solo fallaban por el costado (contacto 0,50–0,72 m): `JsonCatalog.KICK_LATERAL_MAX = 0.75`
   solo para ellos; `kick_clean_failures` detalla la condición que falla. Resto: 1 válido por otro consumidor,
   163 válidos con contexto (149 raíz, 14 bucles), 33 con evento alternativo, 50 incompatibles, 21 pendientes de
   revisión visual. Ninguno borrado ni desconectado.
5. **Sistemas reutilizados:** `BallHandler.plan_clip_kick` sin cambios (sigue exigiendo que el pie llegue).
6. **Pruebas ejecutadas:** `test_kick_recovery` headless 2/0 (54 exactos; 108/108 planificados, aceptados, contacto
   validado e impulso; peor distancia 0,151 m); `test_anim_trace` 8/0 con el cambio. **No ejecutadas todavía:** suite
   completa, 8 baterías con render, `test_kick_recovery` con render (pie vivo), métricas de partido.
7. **Comparación:** pendiente (partidos con el commit de la Fase 2 contra la base de 16 o 24 partidos).
8. **Criterios de aborto:** los del §10; especialmente p90 de contacto y % golpeos sin contacto (habilita golpeos).
9. **Pendientes:** todo el punto 6 «no ejecutadas» y el punto 7; ver `CONTINUAR_GUIA_ANIMACIONES.md` §5.2.
10. **Integridad:** originales 2.023/2.023 (comprobado en esta etapa); recursos 46/47 (solo `json_catalog.gd`).
11. **Commit:** el commit «Phase 2 (open)…» que agrega este registro.
