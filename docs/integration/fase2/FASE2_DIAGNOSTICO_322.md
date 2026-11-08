# Fase 2 — Diagnóstico de los 322 segmentos conectados pero no seleccionables

Fecha: 2026-11-07. Rama `integracion-openai`. Tabla completa (una fila por segmento):
[`diagnostico_322.csv`](diagnostico_322.csv), generada por [`generar_diagnostico_322.py`](generar_diagnostico_322.py).

## 1. Origen de los 322

`docs/integration/estado_individual.csv` marca 322 tramos con `estado_conexion = si` (tienen rol y un sistema que los
consume) y `filtro_del_sistema = no pasa …` (el consumidor los descarta siempre). Por filtro:

| Filtro del consumidor | Segmentos |
|---|---|
| `JsonCatalog.situation_clip` → `AnimDB.candidates(max_root=1.0, min_duration=0.6)` | 176 |
| `JsonCatalog.kick_candidates` → `contact.clean` (8 condiciones del conversor) | 121 |
| `JsonBallMove.plan_ids` → `ball_touches` no vacío | 13 |
| `BallHandler.plan_turn_kick` → punta ≤ 0,35 m en el contacto | 12 |

Los valores medidos salen de los metadatos que el juego carga (volcados con la escena de diagnóstico, no recalculados
a mano) y del inventario UCS de `animdb.json`. Ningún JSON original se modificó (2.022/2.022 hashes iguales a
`fase0/hashes_json_originales.sha256`).

## 2. Decisiones (sección 4.2 de la guía)

| Decisión | Segmentos | Estado |
|---|---|---|
| válido | 54 | **habilitados** en esta fase (golpeos con el contacto solo «al costado») |
| válido | 1 | `jn_ball_start_3066`: ya lo selecciona otro consumidor (`JsonReceive`, perfil de recepción) |
| válido con contexto | 149 | festejos, lamentos, aplausos, calentamiento y gestos con raíz > 1 m (mediana 3,1 m): falta un consumidor de situaciones que aplique la raíz |
| válido con contexto | 14 | ciclos cortos en bucle (barrera, forcejeo, espera): falta reproducirlos en bucle |
| válido con evento alternativo | 22 | 10 golpeos con la punta a media altura (> 0,30 m) y 12 golpeos girando con la punta a 0,36–0,45 m: son semivoleas o voleas cortas, requieren el planificador de media altura (Fase 4) |
| válido con evento alternativo | 11 | giros con pelota sin toque medido, pero con cuadro y pie del toque en el inventario UCS: convertir el evento desde la pose (Fase 10), no inventarlo |
| incompatible | 42 | golpeos con el pie de apoyo que patina, aterriza o no está plantado en los 0,1 s previos: con el golpeo raso (cuerpo plantado) el pie patinaría; se conservan |
| incompatible | 7 | fragmentos finales (sufijo END) de otro clip, de < 0,6 s |
| incompatible | 1 | `jn_ball_turn_1894`: gira con la pelota en las manos (saque de banda), no con el pie |
| pendiente_revision_visual_especializada | 21 | 15 golpeos con contacto detrás del cuerpo o pie lento (taconazo, toque suave), 6 clips de situación cortos sin bucle |

Total: 322. Ninguno se borró, renombró ni desconectó; los no habilitados siguen en el banco con su rol.

## 3. Lo habilitado: 54 golpeos «solo al costado»

Medición: de los 121 golpeos no limpios, 79 fallan la condición lateral (|z| > 0,50 m). 54 de ellos cumplen **las otras
7 condiciones** (punta baja, delante del cuerpo, pie rápido, apoyo plantado y quieto, salida a menos de 45°) con el
contacto entre 0,50 y 0,72 m al costado. Por rol: `kick_shot` 24, `kick_shot_hard` 17, `kick_pass` 9,
`kick_pass_soft` 3, `kick_lob` 1 (108 variantes con los espejos).

Cambio (`scripts/animation/json_catalog.gd`):

- `JsonCatalog.kick_clean_failures(contact)`: lista de las condiciones de golpeo limpio que no se cumplen (los mismos
  umbrales que el conversor, `tools/json_anim/build_json_library.gd`).
- `JsonCatalog.KICK_LATERAL_MAX = 0.75`: `kick_clip_rejection` admite un golpeo no limpio **solo** si la única condición
  que falla es el costado y el contacto está a ≤ 0,75 m. No se relajó ninguna otra condición ni el filtro de los
  golpeos limpios; el resto de los no limpios sigue fuera y su motivo detalla la condición que falla.
- El planificador (`BallHandler.plan_clip_kick`) no cambió: sigue exigiendo que el pie llegue a la pelota tras el ajuste
  de zancada, así que estos clips solo se eligen con la pelota a ese costado.

Prueba de consumidor real (`tests/test_kick_recovery.gd`, modo 4):

- `test_recovered_set_is_exactly_the_lateral_only_kicks`: el conjunto admitido ahora y antes no es exactamente de 54
  clips (sin espejos), todos fallan solo por el costado y dentro de 0,75 m; los que siguen fuera dan su motivo.
- `test_each_recovered_kick_reaches_the_ball_through_the_real_planner`: para cada clip y su espejo (108),
  `plan_clip_kick` con la variante pedida lo planifica con la pelota quieta en su costado, el árbitro lo acepta, el
  contacto se valida en el instante del clip y la pelota recibe el impulso (> 2 m/s). Resultado: 108/108, peor distancia
  pie–pelota 0,151 m (aceptación del modo 4: `json_kick_reach` = 0,65 m).

## 4. Lo que no se habilita y quién lo resolvería

| Grupo | Motivo de no habilitar | Fase |
|---|---|---|
| 149 situaciones con raíz | reproducirlas en el sitio desliza el cuerpo; relajar `max_root` no es aceptable | presentación (no prioritaria, §18) |
| 14 bucles | el selector los trata como pose de una vez | presentación (no prioritaria) |
| 22 media altura | no son golpeos rasos | 4 (planificador aéreo / semivolea) |
| 11 toques UCS | el evento de toque no se generó en la conversión | 10 (metadatos) |
| 21 pendientes | requieren revisión visual especializada (hoja de poses) | 8 / revisión |
| 50 incompatibles | física o tipo de clip incompatible con el consumidor | — (se conservan) |
