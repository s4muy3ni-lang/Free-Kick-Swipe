# Cómo continuar la guía maestra de animaciones (traspaso entre chats)

> **2026-11-07, más tarde:** el usuario pidió una reforma del juego a **tiros libres y penales**, que pasa a ser la prioridad.
> Auditoría y plan: [`../reforma/FASE0_AUDITORIA_Y_PLAN.md`](../reforma/FASE0_AUDITORIA_Y_PLAN.md). Esta guía de animaciones del partido de fútbol 5 queda en pausa.

Última actualización: 2026-11-07. Escrito para que otro chat retome el trabajo sin el historial de la conversación.
**Leer entero antes de tocar nada.**

## 1. Qué leer y en qué orden

1. Este documento.
2. [`GUIA_MAESTRA_ANIMACIONES.md`](GUIA_MAESTRA_ANIMACIONES.md): el texto completo de la guía del usuario (fases 0–12,
   plan de pruebas §15, orden §16, formato de informe §17, orden final §18). Es la especificación; manda sobre este
   resumen.
3. [`SEGUIMIENTO_ANIMACIONES.md`](SEGUIMIENTO_ANIMACIONES.md): un registro por etapa con el formato de la §17 de la guía
   (estado inicial, problema, archivos, cambio, pruebas, comparación, aborto, pendientes, integridad, commit).
   **Cada etapa nueva se agrega ahí.**
4. [`AUDITORIA_PRE_IMPLEMENTACION.md`](AUDITORIA_PRE_IMPLEMENTACION.md) (Fase 0): mapa de sistemas, línea base,
   pruebas de bloqueo G1–G9 (§9), umbrales de aborto (§10), determinismo (§7), inventario de recursos (§8).
5. [`AUDITORIA_SISTEMA_ANIMACIONES.md`](AUDITORIA_SISTEMA_ANIMACIONES.md): auditoría técnica previa (cifras del banco).
6. Índice técnico: `docs/technical-index/INDEX.md`, ficha `SYSTEMS/JSON_MODE.md` (secciones «Fase 1» y «Fase 2» al final).

## 2. Rama, git y reglas que no se negocian

- **Rama de trabajo: `integracion-openai`.** El usuario lo pidió expresamente para esta guía. **No tocar `respaldo-f3`**
  (debe seguir en `3d47a07`; comprobar con `git ls-remote origin respaldo-f3`). `CLAUDE.md`, `START_HERE.md` y
  `ESTADO_Y_METODOLOGIA.md` todavía nombran `respaldo-f3` como rama de trabajo: eso es de una etapa anterior.
- No abrir PR; no hacer merge a la rama principal durante las fases 0–8; commit por etapa; push con
  `git push -u origin integracion-openai`. Mensajes de commit terminados con las líneas de atribución de la sesión.
- El tag `pre-audit-phase-0` (= `04ed110`) no se pudo subir (el proxy de la sesión corta los push de tags). Comando para
  el usuario: `git tag -a pre-audit-phase-0 04ed11050885e0dcffbd7820ee6ac1e94572c2bd -m "Linea base Fase 0" && git push origin pre-audit-phase-0`.
- Reglas de la guía (resumen; texto completo en la guía, «Reglas no negociables»): no borrar, renombrar ni alterar los
  2.022 JSON originales; no eliminar espejos ni recursos importados; no conectar clips solo por su nombre; no cambiar
  tolerancias en masa sin medición comparativa; no mover la pelota con la animación (solo `Ball.kick`); no aplicar
  impulso porque una animación empezó; no dejar dos acciones físicas incompatibles a la vez; no hacer pasar pruebas
  relajando aserciones; no crear un segundo predictor, árbitro ni motor de raíz; no reemplazar planificadores; traza
  apagada en compilaciones normales; los 38 clips `EJ_*` del ZIP de integración son ejemplos sintéticos: nunca se
  importan ni se cuentan; no citar proyectos, investigaciones ni productos ajenos en código, documentación o commits.
- **No cerrar una fase si una métrica de la línea base empeora más allá del umbral de aborto** (§10 de la auditoría).
- Prioridad (§18): física y contacto correctos antes que variedad; la presentación (festejos, público) no es prioritaria.
- No inventar resultados: lo no ejecutado se escribe «no ejecutado».

## 3. Entorno y comandos

- Godot 4.7.2 oficial en `/usr/local/bin/godot` (`godot --version` → `4.7.2.stable.official.ed1daf0bf`).
- Suite headless: `tools/run_tests.sh` (≈ 17 min; filtro: `tools/run_tests.sh <nombre>`). Falla si hay `SCRIPT ERROR`.
  Revisar además fugas: `grep -c "ObjectDB instances were leaked\|resources still in use at exit" <log>` debe dar 0.
- Las 8 baterías con render (pie vivo; en headless se omiten):
  ```bash
  for f in live_feet live_kicks pack_motion json_mode physical_dribble directional_kicks dribble_reference test_receive; do
    xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn \
      -- --filter "$f" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > /tmp/render_$f.log; grep "Resumen" /tmp/render_$f.log; done
  ```
  (Antes de la primera ejecución en un árbol nuevo: `godot --headless --path . --import`.)
- Índice técnico tras cambiar código: `python3 tools/docs_index.py sync` y `python3 tools/docs_index.py check`
  (debe terminar con 0 errores) + entrada en `docs/technical-index/CHANGELOG.md`.
- **Medición de partidos** (`docs/integration/fase0/medicion/`):
  - `medir_linea_base.py --commit <commit> --work <dir temporal> --out <dir> --seeds 101,202,... --minutes 10 --jobs 2`
    crea un `git worktree` del commit, le aplica parches **que solo registran** (no cambian decisiones) y juega partidos
    IA contra IA de 10 min con todas las semillas fijadas. ≈ 3 min por partido; con 4 núcleos, dos mediciones en
    paralelo con `--jobs 2` cada una. Opciones: `--repeat-seed`, `--render-seed`, `--keep-meta`.
  - `medir_linea_base.py --recalcular <dir> --meta <_meta.json>` recalcula `metricas.json` de partidos ya jugados (sirve
    para agregar métricas nuevas sin rejugar y para rescatar una medición cortada). `_meta.json` (metadatos de clips) se
    borra al terminar salvo `--keep-meta`; si falta, generar uno con una medición corta y `--keep-meta`.
  - Los parches buscan **texto exacto** del código (lista `PATCHES`): en `footballer_visual.gd` (señal,
    `play_pack_clip`, `tree_root.connect_node(&"output"...)`) y en `ball_handler.gd` (`func _init(o: Footballer)`,
    `func dispose()`, `entry.merge(extra)\n\tkick_log.append(entry)`,
    `perform_action(...)\n\t_kick_event_info = {}`). Si una fase cambia esas líneas, actualizar `PATCHES` (la medición
    se detiene si no encuentra el texto). El registro por golpeo ya guarda `pred` (residuo planificado), `lat`, `adj`,
    `bv0`, `pv0`, `intf`, `turn`, `aer` y `ex` (= `info["exec"]` si el código lo agrega; ver §5.3).
  - `comparar_con_base.py <base.json>[,<otro.json>...] <etapa.json>[,...] --md salida.md`: umbrales de aborto del §10,
    estado `SUPERA`/`ok` y p de permutación por métrica (el p informa, no cambia el estado). Código de salida 1 si se
    supera algún umbral.
  - **Las mediciones en segundo plano mueren si la sesión se reinicia.** Lanzarlas con `nohup` y, si se cortan, rescatar
    los partidos terminados con `--recalcular`.
- El juego **no es determinista** entre ejecuciones con la misma semilla (diverge a los 4–6 s; fuentes en la auditoría
  §7 y ticket F9-001). Por eso las comparaciones son estadísticas: el ruido entre partidos es del orden de varios umbrales.

## 4. Estado por fase (al 2026-11-07, commit `c9b08e5` + el commit de este traspaso)

| Fase | Estado | Dónde |
|---|---|---|
| 0 Auditoría, línea base, hashes | **cerrada** (`7c1e9da`, `44ee432`) | `AUDITORIA_PRE_IMPLEMENTACION.md`, `fase0/` |
| 1 Trazabilidad + overlay | código hecho y probado (`5511cfe`, verificación `c9b08e5`); **no cerrada**: una métrica supera su umbral (ver §5.1) | `fase1/FASE1_VERIFICACION.md` |
| 2 Los 322 segmentos | tabla completa y 54 golpeos habilitados (commit de este traspaso); **abierta**: falta validación completa (§5.2) | `fase2/FASE2_DIAGNOSTICO_322.md` |
| 3 Precisión del contacto | **no empezada**; análisis previo y diseño en §5.3 | — |
| 4–12 | no empezadas; datos útiles en §5.4 | guía §6–§14 |

Línea base disponible (commit `04ed110`, partidos de 10 min): semillas 101–606 (`fase0/linea_base/`), 707–1212
(`fase0/linea_base_s707_1212/`), 1313–1616 (`fase0/linea_base_s1313_1616/`). Fase 1 (`5511cfe`) con las mismas semillas:
`fase1/metricas_s101_606/`, `fase1/metricas_s707_1212/`, `fase1/metricas_s1313_1616/`.

Medias de la base con 16 partidos (para las fases siguientes): p90 distancia pelota–contacto 0,389 m (p95 0,462,
mediana 0,142, máx. 0,597); contactos ≤ 0,20 m 62,5 %, ≤ 0,30 m 79,8 %; golpeos iniciados sin contacto 4,4 %;
movimientos con pelota cortados 33,2 %; recepciones con clip abortadas 32,3 %; pérdida tras recepción animada 25,8 %;
goles 5,75 por partido (mín. 4), en propia 1,0; golpeos aéreos 0.

## 5. Qué sigue, paso a paso

### 5.1 Cerrar (o no) la Fase 1

Situación: con 6, 12 y 16 partidos por lado, todas las métricas dentro salvo «% pérdida tras recepción animada»
(16 + 16: 30,0 % frente a 25,8 %; límite +5 % relativo = 27,1 %; p = 0,17). Revisión del código: todos los enganches de
la Fase 1 están bajo `AnimTrace.enabled`; ninguno consume azar ni lee el reloj (detalle en `fase1/FASE1_VERIFICACION.md`
§2). La base contra sí misma con otras semillas movió la misma métrica −4,9 pp. «recepciones_clip_iniciadas» da
p = 0,043 (32,0 frente a 35,1 por partido) entre 22 métricas comparadas (esperable por azar, pero vigilar).

Pasos:
1. Completar 24 + 24 (semillas 1717–2424) en los dos commits, en paralelo:
   ```bash
   S=<dir temporal>; SEEDS=1717,1818,1919,2020,2121,2222,2323,2424
   nohup python3 docs/integration/fase0/medicion/medir_linea_base.py --commit 04ed11050885e0dcffbd7820ee6ac1e94572c2bd \
     --work $S/w_base --out $S/base_s1717 --seeds $SEEDS --jobs 2 --keep-meta > $S/base.out 2>&1 &
   nohup python3 docs/integration/fase0/medicion/medir_linea_base.py --commit 5511cfe \
     --work $S/w_f1 --out $S/f1_s1717 --seeds $SEEDS --jobs 2 --keep-meta > $S/f1.out 2>&1 &
   ```
   (≈ 15 min). Guardar los resultados en `fase0/linea_base_s1717_2424/` y `fase1/metricas_s1717_2424/` (sin `_meta.json`).
2. Comparar con todas las listas separadas por comas (base: `linea_base`, `linea_base_s707_1212`, `linea_base_s1313_1616`,
   `linea_base_s1717_2424`; Fase 1: las cuatro de `fase1/`) → `fase1/comparacion_metricas_24.md`.
3. Si sigue superándolo: no cerrar por cuenta propia. Opciones a presentar al usuario con la evidencia: (a) aceptar que
   es ruido (equivalencia de código + prueba A/A: medir `04ed110` otra vez con las semillas 101–1616 y comparar base
   contra base con los mismos tamaños); (b) investigar un mecanismo (empezar por `JsonReceive.consider/plan` y la cuenta
   de `reception_outcome` del parche de medición). Si queda dentro: cerrar la etapa 1 en `SEGUIMIENTO_ANIMACIONES.md`.
4. Usar la base de 24 partidos como referencia de las fases siguientes (documentarlo en la auditoría §10).

### 5.2 Terminar la Fase 2

Hecho: tabla de los 322 (`fase2/diagnostico_322.csv`, generador `fase2/generar_diagnostico_322.py`), 54 golpeos
laterales habilitados (`JsonCatalog.KICK_LATERAL_MAX`), `tests/test_kick_recovery.gd` 2/0 headless, `test_anim_trace`
8/0. Falta, en este orden:
1. Suite completa headless (`tools/run_tests.sh`, guardar log en `fase2/pruebas/`). Ojo: pruebas que cuentan candidatos
   de golpeo o motivos de rechazo pueden cambiar con 54 golpeos más; si una falla, ver si la prueba fija un número del
   catálogo viejo (corregir solo si estaba mal planteada y decirlo) o si es una regresión real.
2. Las 8 baterías con render (§3) → `fase2/pruebas/render_*.log`.
3. `test_kick_recovery` con render y medición del pie **vivo**: la prueba actual valida con el punto de contacto de los
   metadatos (`foot_contact_world`). Agregar, cuando `bh.feet_live` sea verdadero, la distancia mínima entre
   `bh.toe_world(pie del contacto)` y la pelota durante la ventana del golpeo (como `tests/test_live_kicks.gd`, que usa
   `TouchFootIK.rendered_toe_world`) y anotarla; decidir el umbral solo después de ver la distribución (referencia de la
   auditoría: ≈ 0,125 m del centro visual en escenarios controlados). Así el nivel de evidencia llega a «visualmente
   correcto en render».
4. Métricas de partido con el commit de la Fase 2 (mismas semillas que la base disponible) y comparación. Vigilar p90 de
   contacto y % golpeos sin contacto (los clips nuevos golpean al costado).
5. Actualizar la etapa 2 en `SEGUIMIENTO_ANIMACIONES.md`, commit y push.

Decisiones ya tomadas para los no habilitados (no rehacer): 149 situaciones con raíz > 1 m y 14 bucles necesitan un
consumidor de presentación (no prioritario); 22 golpeos a media altura → Fase 4; 11 giros con toque solo en UCS →
Fase 10 (convertir el evento desde la pose, no inventarlo); 50 incompatibles se conservan; 21 pendientes de revisión
visual quedan fuera del catálogo activo (la guía §4.6 permite cerrar con ellos diferidos).

### 5.3 Fase 3 — precisión del contacto (diseño preparado, sin código todavía)

Qué mide hoy la métrica de contacto: en `BallHandler._finish_clip_kick` (`scripts/player/ball_handler.gd:1274`),
`d = |centro de la pelota − foot_contact_world(plan.contact, posición y yaw actuales)|`, es decir, el punto del pie
**según los metadatos del clip** con el cuerpo donde está en el paso del impulso (no el hueso renderizado). Se acepta si
`d ≤ Tuning.player.json_kick_reach` (0,65 m, `kick_reach()` línea 2633). El residuo planificado es `plan.residual`
(`plan_clip_kick`, línea 950; incluye la altura: `delta.y` = altura de la pelota − altura de la punta).

Análisis previo (base, 6 partidos, 596 contactos): 114 superan 0,30 m (19 %). Por rol: `kick_shot` 26 de 63 (41 %),
`kick_pass` 43/219, `kick_turn` 29/188, `kick_pass_soft` 11/92, `kick_back` 5/28. Todos con la pelota en el suelo
(altura < 0,12 m): el problema no es aéreo.

Plan (orden de la guía §5.3):
1. Instrumentar, sin cambiar decisiones: guardar en el diccionario del plan la pelota prevista y el pie previsto
   (`plan_clip_kick`: `fast["bp"]` y `bp − delta + step`; `plan_turn_kick` línea 1087: `bp` y
   `foot_contact_world(ct, body_c, yaw_c) + step`; `plan_aerial_kick` línea 833: `bp` de `BallPredictor.trajectory`).
   En `_finish_clip_kick`, agregar `info["exec"]` **solo con números**: error de la pelota prevista (horizontal y
   vertical), error del pie previsto, residuo, tiempo esperando la pelota (`_ball_still_arriving`, línea 1245),
   velocidad de la pelota, si el pie estaba vivo y, con `feet_live`, la distancia del pie renderizado
   (`toe_world`, línea 2165). La medición ya copia `info["exec"]` al registro (`"ex"`).
2. Medir 16–24 partidos y descomponer: `d ≈ |residuo + error_pelota − error_pie|`. Si domina el error de la pelota
   prevista (pelotas en movimiento; `ball_travel` usa el modelo de rodadura y fija `bp.y` a la altura actual), resolver
   la predicción primero (**sub-fase 3a: `BallPredictor`**, la guía lo exige antes de tocar tolerancias). Si domina el
   del pie: revisar latencia cuantizada (`clip_timing`), ajuste de paso (`_steer_clip_kick` línea 752, tope
   `kick_nudge_cap`), orientación prevista (`_predicted_yaw`) y colisiones.
3. Corregir la causa dominante con correcciones pequeñas y acotadas (nunca teletransportar, nunca impulso sin
   contacto validado); **no** bajar 0,65 m globalmente; tolerancia por tipo de contacto solo con medición.
4. Aceptación (§5.5–5.6 de la guía): distribución p50/p90/p95/máx., % ≤ 0,20 / ≤ 0,30 / > 0,30, contactos fallidos y
   acciones abortadas, en headless y con render por separado; abortar si p90 sube > 10 %, abortadas > 5 %, goles caen
   de forma significativa o falla una prueba de bloqueo.

### 5.4 Datos útiles para las fases siguientes

- Fase 4 (aéreo): 0 golpeos aéreos en todos los partidos medidos; `plan_aerial_kick` existe (cabezazos y voleas por
  rol); falta la clasificación previa de intención (5 vías, guía §6.2) y las pruebas obligatorias §6.6. 22 golpeos de
  la Fase 2 a media altura esperan aquí.
- Fase 7 (alias): la traza de 90 s mostró filas `no_encontrado` para `sprint_turn`; alias sin resolver de la auditoría:
  Soccer_Spin, Sprint_Turn, Defender, Writhing_In_Pain, Sprint_To_Backslide_inplace; propuestas Defender_2 → `wall`,
  Running_Tired → `nis_idle`.
- Fase 9 (árbitro): ticket [`tickets/F9-001_jugador_fuera_de_cancha.md`](tickets/F9-001_jugador_fuera_de_cancha.md);
  política de interrupción en el fotograma de contacto (opción A de la guía) con prueba; distribución de rechazos por
  familia con `AnimTrace`.
- Fase 10: 123 duraciones del ZIP difieren del juego por el recorte del conversor (auditoría §1.1).
- Fase 11 (determinismo): RNG sin semilla en `BallHandler`, `PlayerActions`, `Goalkeeper`, `SetPiece`,
  `MatchPresentation`, `PackLibrary._vary_rng`; `Ball.last_touch_msec` usa el reloj de pared.
- Prueba de bloqueo pendiente de crear (§15 de la guía, G8): pie animado == pie informado en originales y espejos.
- Diagnóstico de cualquier clip: `AnimTrace.explain(id)`; traza en partido: `FUTBOL5_ANIM_TRACE=1` o
  `-- --anim-trace`; overlay: F3 (F4 cambia de jugador) o `FUTBOL5_ANIM_DEBUG=1`.

## 6. Integridad (comprobar al cerrar cada fase)

- Banco original: los 2.022 JSON + `index.json` están solo en el ZIP que subió el usuario
  (`animaciones_futbol5_nombres_originales1.zip`, sha256 `3fa72c92…d8b374f`), no en el repositorio. Si se vuelve a
  subir: extraer en un directorio vacío y `sha256sum -c` contra `fase0/hashes_json_originales.sha256` (esperado
  2.023/2.023).
- Recursos: `grep -v '^#' docs/integration/fase0/hashes_recursos_animacion.sha256 | sha256sum -c` (esperado: solo
  difieren los scripts cambiados a propósito; hoy `scripts/animation/json_catalog.gd`).
- `git ls-remote origin respaldo-f3` → `3d47a07…`.
