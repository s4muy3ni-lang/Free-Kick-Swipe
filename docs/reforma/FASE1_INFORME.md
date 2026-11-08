# Reforma: tiros libres y penales — Fase 1 (bancos de animación: selector y comparación)

Fecha: 2026-11-07. Rama: `reforma-tiros-penales` (creada desde `integracion-openai` en `9c6f82a`, árbol limpio;
`respaldo-f3` sin cambios en `3d47a07`). Alcance autorizado: banco de pruebas con selector JSON / Mixamo / Mocap, comparación
sobre el mismo jugador y en condiciones idénticas, «sin clip en este banco» sin rellenar con otro banco, catálogo por
procedencia, verificación de deformación, golpeo, contacto, arquero y transiciones, y una APK para que pruebes.
**No se eligió banco ganador, no se combinaron bancos y no se integró nada.** Ningún original se modificó.

## 1. Resultado principal: el cuerpo común no sirve hoy para Mixamo ni Mocap

Antes de comparar verifiqué reposo, retargeting y deformación, como pediste. Resultado:

- Los tres bancos animan los **mismos 23 huesos** (`Root` + 22 `mixamorig_*`) y solo la cadera tiene pista de posición:
  ningún clip estira huesos. Pero **la orientación de reposo de cada hueso es distinta** entre el humano JSON y el
  futbolista (`player_base.glb`), para el que se convirtieron Mixamo y Mocap: 17 de 23 huesos difieren más de 5°
  (pies 177°, muslos 124–131°, hombros 123–130°, cadera 85°; tabla en
  [`fase1/compatibilidad/reposo.csv`](fase1/compatibilidad/reposo.csv)). Las pistas de rotación guardan la rotación
  local absoluta, así que un clip pensado para un reposo **se deforma** sobre el otro.
- Medido clip por clip (herramienta `tools/reforma/bank_compat.gd`, 3.418 clips, sin render):

| | JSON sobre humano JSON | Mixamo sobre humano JSON | Mocap sobre humano JSON | Mixamo / Mocap sobre su cuerpo original |
|---|---|---|---|---|
| Pies (mínimo del clip, mediana) | −0,1 cm (apoyados) | **+27 cm, flotan** (138 de 171 clips > 8 cm) | **+28 cm, flotan** (22 de 24) | +0,5 cm / +0,8 cm (apoyados) |
| Punta del pie frente al contacto medido (mediana) | 0,006 m (p90 0,026) | **1,21 m** | **1,34 m** | 0,000 m / 0,000 m |
| Desvío de la pose frente al cuerpo original (mediana del máximo) | — | 0,79 m | 0,78 m | — |

  Control de la herramienta: cada banco sobre **su** cuerpo apoya los pies y acierta el contacto; el JSON sobre el
  futbolista también se rompe (1,2 m), lo que coincide con lo ya documentado en 2026-10-30 (el modelo de Tripo se descartó
  para el modo JSON porque se deformaba).
- Con render (banco de pruebas, prueba `test_reference_kick_happens_at_the_clip_contact`): en el instante del golpe, la
  punta del pie quedó a **0,095 m** del centro de la pelota con JSON, a **1,18 m** con Mixamo y a **1,14 m** con Mocap sobre el
  humano JSON; sobre su cuerpo original Mixamo queda a **0,035 m** y Mocap a **0,049 m**. Capturas:
  [`fase1/capturas/golpeo_balon_parado_3_bancos.jpg`](fase1/capturas/golpeo_balon_parado_3_bancos.jpg) y
  [`fase1/capturas/deformacion_en_cuerpo_comun.jpg`](fase1/capturas/deformacion_en_cuerpo_comun.jpg).

**No lo corregí** (pediste no hacerlo sin autorización). Para que puedas comparar igual, el banco de pruebas tiene el botón
**«Cuerpo: humano JSON (común)» / «Cuerpo: original del banco (diagnóstico)»**: en la vista común ves la deformación; en
la de diagnóstico ves cada banco sobre el cuerpo para el que se convirtió (Mixamo y Mocap sobre el futbolista), con la
misma cancha, pelota, posición y cámaras. Ver la decisión pendiente en §6.

## 2. Qué se entregó

> **Cambio posterior (mismo día, pedido del usuario):** el modo de fútbol 5 salió de esta rama, con su escena, su acceso
> desde el menú y sus pruebas de juego abierto ([`FUTBOL5_QUITADO.md`](FUTBOL5_QUITADO.md)). El menú de desarrollo solo
> abre el banco de pruebas. Suite después del cambio: 132 pruebas, 0 fallidas, 13 omitidas (necesitan render), 0 fugas; 5
> baterías con render 0 fallidas ([`pruebas_sin_futbol5/`](pruebas_sin_futbol5/)).

| Pieza | Archivo |
|---|---|
| Menú de desarrollo (entrada del juego): banco de pruebas y partido de fútbol 5 anterior; el menú de pausa del partido tiene «Menú de desarrollo» para volver | `scenes/dev/dev_menu.tscn`, `scripts/dev/dev_menu.gd` |
| Banco de pruebas, horizontal 16:9 | `scenes/dev/anim_bank_bench.tscn`, `scripts/dev/anim_bank_bench.gd` |
| Catálogo por procedencia (entra en la APK) y su lectura | `resources/animation/catalogo_bancos.json`, `scripts/dev/anim_bank_catalog.gd` |
| Generador del catálogo y CSV por banco | `tools/reforma/build_bank_catalog.gd` → `fase1/catalogo_json.csv`, `catalogo_mixamo.csv`, `catalogo_mocap.csv`, `catalogo_resumen.csv` |
| Medición de compatibilidad | `tools/reforma/bank_compat.gd` → `fase1/compatibilidad/` (`reposo.csv`, `clips.csv`, `resumen.json`) |
| Capturas y mediciones con render | `tools/reforma/bench_captures.tscn` → `fase1/capturas/` |
| Pruebas | `tests/test_anim_bank_bench.gd` |
| APK por GitHub Actions en la rama nueva | `.github/workflows/android.yml` (rama agregada a los disparadores) |

### 2.1 Cómo se usa el banco de pruebas (en la APK)

1. Al abrir el juego: **Menú de desarrollo → «Banco de pruebas de animaciones»**.
2. Arriba: **JSON original · Mixamo · Mocap** (carga solo el banco elegido) y el botón de cuerpo (común o diagnóstico).
3. Izquierda: acciones agrupadas en **Tirador**, **Barrera** y **Arquero**, con la cantidad de clips del banco elegido; las
   vacías dicen «— sin clip» y al elegirlas aparece **«Sin clip en este banco»**.
4. Abajo: clip anterior / siguiente (◀ ▶), repetir clip, repetición automática, velocidad (0,25× · 0,5× · 1×),
   **Secuencia** (reposo → clip → reposo del mismo banco, con mezcla de 0,2 s: muestra las transiciones; Mocap no tiene
   reposo, así que encadena sin transición), cámaras **Desde el tirador · Lateral · Opuesta** y zoom (− +).
5. Derecha: banco, cuerpo, clip, toma original, espejo, rol, duración, contacto medido y lo **medido en vivo** sobre el
   cuerpo mostrado: pies (hundidos si es negativo, flotando si pasa 0,08 m), salto de la cadera, alcance de las manos y,
   en los golpeos, la distancia punta del pie – pelota en el instante del golpe.

Condiciones idénticas para los tres bancos: misma cancha y arco, pelota siempre en el mismo punto (punto penal de la
cancha actual), el jugador se coloca para que el contacto medido de cada golpeo caiga sobre esa pelota, golpe de
referencia en el instante de contacto del clip (no es el disparo del juego: muestra la sincronización), arquero en el
centro de la línea de gol con un marcador donde quedan sus manos en el extremo de la atajada, barrera a 9,15 m de la
pelota, mismas tres cámaras fijas. Lo único que cambia es el banco (y, en diagnóstico, el cuerpo).

## 3. Catálogo por procedencia

Cómo se clasificó: JSON por su rol medido al convertir (y el nombre original de la toma para penal, rosca, desvío y salto
de barrera); Mixamo y Mocap por el nombre de la toma (no tienen roles de golpeo). Las **atajadas se clasificaron midiendo**
sobre el cuerpo original de cada banco (punto medio de las manos + raíz del clip): estirada si llega a ≥ 0,9 m al costado,
alta si una mano llega a ≥ 2,0 m, baja si en el extremo las manos están a ≤ 0,6 m, si no central. Izquierda y derecha son
**las del arquero**. Las tomas JSON nombradas «…RIGHT» van hacia la izquierda del arquero (su nombre describe el lado
visto desde el tirador); el catálogo usa la medición.

| Grupo | Acción | JSON | Mixamo | Mocap |
|---|---|---:|---:|---:|
| Tirador | Reposo / preparación | 12 | 2 | **0** |
| | Carrera | 16 | 8 | **0** |
| | Arranque y pasos de ajuste | 34 | 3 | **0** |
| | Golpeo de balón parado (tiro libre) | 62 | 2 | 4 |
| | Penal (golpeo) | 2 | 2 | 4 |
| | Disparo potente | 86 | 4 | 2 |
| | Disparo colocado / con efecto | 144 | **0** | **0** |
| | Vaselina / picado | 20 | 2 | **0** |
| | Pase de interior | 244 | 2 | 2 |
| | Festejo | 127 | 7 | 3 |
| | Lamento | 95 | 7 | **0** |
| Barrera | Barrera: postura | 10 | **0** | **0** |
| | Barrera: salto | 8 | **0** | **0** |
| | Salto genérico (no de barrera) | 1 | 3 | **0** |
| Arquero | Posición inicial / espera | 6 | 2 | **0** |
| | Desplazamiento lateral | 8 | 2 | **0** |
| | Estirada a su izquierda | 81 | 1 | 1 |
| | Estirada a su derecha | 81 | 1 | **0** |
| | Atajada alta | 22 | 4 | **0** |
| | Atajada central / captura | 62 | 4 | 1 |
| | Atajada baja | 72 | 2 | 1 |
| | Bloqueo | 14 | 6 | **0** |
| | Desvío | 28 | **0** | **0** |
| | No llega | 2 | 2 | **0** |
| | Levantarse | 21 | **0** | **0** |

Las cifras cuentan variantes (los espejos son clips distintos). Detalle clip por clip, con duración, raíz, contacto,
alcance de las manos, salto y pies: `fase1/catalogo_<banco>.csv`.

## 4. Informe comparativo (tabla de tu §4.3)

Lo medido sale de las herramientas y pruebas citadas. Las columnas de juicio visual (naturalidad, calidad) **las decides
tú en la APK**: aquí solo pongo lo que se puede medir y lo que vi en las capturas, sin elegir.

| Criterio | JSON original | Mixamo | Mocap |
|---|---|---|---|
| Animaciones disponibles | 3.223 variantes (2.024 tramos de 2.022 tomas) | 171 (133 tomas) | 24 (20 tomas) |
| Usables para estos modos (catalogadas) | 1.248 | 64 | 14 |
| Compatibles con el cuerpo común (humano JSON) | todas (es su cuerpo) | **ninguna sin retarget** (pies flotan ~27 cm, contacto a 1,2 m) | **ninguna sin retarget** (~28 cm, 1,3 m) |
| Compatibles con su cuerpo original | todas | todas | todas |
| Variedad de acciones | 25 de 25 | 20 de 25 (sin colocado, postura y salto de barrera, desvío, levantarse) | 8 de 25 (solo balón parado, penal, potente, pase, festejo, estirada a la izquierda, atajada central y baja; falta carrera, reposo, arranques, colocado, vaselina, lamento, barrera, posición y desplazamiento del arquero, estirada a la derecha, alta, bloqueo, desvío, no llega y levantarse) |
| Naturalidad visual | a juzgar en la APK | a juzgar en la APK (vista de diagnóstico) | a juzgar en la APK (vista de diagnóstico) |
| Carrera | 16 ciclos y arranques; golpeos de balón parado con carrera propia (media 5,5 m de raíz, 2,6 s) | 8 ciclos; penal con carrera (2,6 m, 1,5 s) | sin carreras sueltas; los penales traen su carrera (2,2 m, 2,4 s) |
| Golpeo | 62 de balón parado (con rosca, fuertes, picados), pie medido a 13,7 m/s de media | 2 de balón parado (`soccer_penalty_kick` y espejo), pie a 8,9 m/s | 4 (dos penales y sus espejos), pie a 8,5 m/s; además tiro potente y pase de interior con espejo |
| Sincronización del contacto (punta del pie – contacto medido, en su cuerpo) | mediana 0,006 m, p90 0,026 m (548 golpeos catalogados) | 0,000 m (10) | 0,000 m (8) |
| Golpe en vivo: punta del pie – centro de la pelota (render, penal) | 0,095 m | 0,035 m (cuerpo original) / 1,18 m (común) | 0,049 m (cuerpo original) / 1,14 m (común) |
| Saltos | 8 saltos de barrera con las manos cubriendo; subida de cadera media 0,35 m | sin salto de barrera; 3 saltos genéricos (0,58 m) | ninguno |
| Atajadas | 162 estiradas medidas (alcance lateral medio 1,98 m, máx. 3,06 m, 1,4 s), 156 altas/centrales/bajas, 14 bloqueos, 28 desvíos, 21 levantarse | 2 estiradas (alcance 2,5–3,1 m, 3,3 s de clip), 10 atajadas, 6 bloqueos | 3 tomas de atajada sin espejo (estirada a la izquierda de 1,8 m, central, baja), tomas largas de 4,4 a 8,9 s con preparación y vuelta |
| Transiciones (salto de pose reposo ↔ clip, sin mezcla, golpeos del tirador, mediana) | 0,56 m | 0,29 m | no medible (sin reposo) |
| Problemas de retargeting | ninguno en su cuerpo; en el futbolista se deforma (1,2 m) | reposo distinto del humano JSON (hasta 177°): se deforma | igual que Mixamo |
| Rendimiento (escritorio; Android lo mides tú) | 39 MB en disco, carga en frío ~0,44 s, ~78 MB de memoria | 9,4 MB, ~32 ms, ~12 MB | 2,6 MB, ~5 ms, ~3,5 MB |
| Observaciones | Único banco con barrera, desvíos y estiradas a los dos lados en cantidad; los golpeos de balón parado son largos (carrera incluida) | Pocas variantes; buena sincronización en su cuerpo; necesita retarget para el cuerpo común | Captura de movimiento real, pero 20 tomas y muy incompletas para barrera y arquero; tomas largas sin recortar en atajadas |

Las mediciones de carga se tomaron con la suite de pruebas corriendo en paralelo: valen como orden de magnitud.

## 5. Pruebas ejecutadas

| Prueba | Resultado |
|---|---|
| `test_anim_bank_bench` sin render | 7 pruebas, 0 fallidas, 1 omitida (la que necesita esqueleto animado), 88 comprobaciones |
| `test_anim_bank_bench` con render (Xvfb + OpenGL) | 7 pruebas, 0 fallidas, 0 omitidas, 104 comprobaciones, sin fugas (`fase1/pruebas/render_test_anim_bank_bench.log`) |
| Suite headless completa | 327 pruebas, **1 fallida**, 29 omitidas, 3.361 comprobaciones, 0 fugas (`fase1/pruebas/suite_headless.log`). La fallida es `test_full_match::test_three_minute_match…`: pelota quieta 16,5 s en un partido de fútbol 5 (límite 12 s). Aislada pasó 6 de 6 en esta rama y 6 de 6 en `integracion-openai`; intermitente, del partido anterior (no tocado en esta fase). Ticket [`F9-002`](../integration/tickets/F9-002_pelota_quieta_en_partido.md) |
| GitHub Actions, compilación 67 (intento 1) | 327 pruebas, **1 fallida**: `test_json_mode::test_ai_match_in_json_mode` («hay tiros (0)»: un partido de IA de 90 s sin tiros). Repetida 10 veces en local: falla 1 de 10 en esta rama y 3 de 10 en `5511cfe` (antes del cambio de golpeos de la Fase 2 de la guía anterior): intermitente y anterior a esta fase. Como el workflow no exporta la APK si falla una prueba, se relanzó el mismo commit con todas las pruebas (sin saltear ni desactivar ninguna) |
| Las 8 baterías con render (live_feet, live_kicks, pack_motion, json_mode, physical_dribble, directional_kicks, dribble_reference, test_receive) | 0 fallidas, 0 fugas, 0 errores de script (`fase1/pruebas/render_*.log`) |
| Capturas del banco con render (16 casos: golpeo, estirada, barrera y penal en los tres bancos y los dos cuerpos) | sin errores de script; `fase1/capturas/` |
| APK | GitHub Actions, compilación 68 (`ccc5592`, sin el fútbol 5): todas las pruebas de CI en verde, artefacto `futbol5-apk` (58 MB, disponible hasta el 21-11-2026): https://github.com/roldanhr98-byte/Futbol5/actions/runs/42380816763 . La compilación 67 (`a9e5e7b`, todavía con el acceso al fútbol 5) también dejó su APK |

Qué comprueban las pruebas: el catálogo está separado por procedencia (ningún clip en dos bancos, cada clip existe en sus
propias bibliotecas); el selector carga solo las bibliotecas del banco elegido; una categoría vacía muestra «sin clip en
este banco» y no toma clips de otro banco; cada pista de cada clip catalogado encuentra su hueso en el cuerpo común; las
53 combinaciones banco × acción con clip se reproducen; el golpe de referencia sale en el instante de contacto del clip y,
sobre el cuerpo original de cada banco, la punta del pie está a ≤ 0,25 m del centro de la pelota; la entrada del juego es
el menú de desarrollo y el partido anterior sigue disponible.

## 6. Limitaciones y decisión que necesito

Limitaciones:

1. **Mixamo y Mocap no se pueden ver bien sobre el humano JSON sin un retarget.** La comparación «mismo cuerpo» que
   pediste solo es justa hoy para JSON; para los otros dos uso la vista de diagnóstico.
2. **Mocap es muy incompleto** para estos modos (8 de 25 acciones, sin barrera ni movimientos de arquero salvo 3 tomas).
3. La medición de rendimiento es de escritorio; la de Android depende de que pruebes la APK (o de que me pases tiempos y
   memoria de tu teléfono).
4. Las clasificaciones de atajadas usan umbrales medidos (están en el catálogo); algún clip límite puede caer en la
   categoría vecina.
5. La naturalidad visual no se puede medir: la juzgas tú.
6. Proporciones de pantalla: el banco se probó en 16:9 (1280 × 720), 4:3 (1024 × 768) y 20:9 (2400 × 1080) con render; el
   campo no se deforma (cámara con altura fija: en 4:3 se ve menos a los costados). En 4:3 los paneles laterales tapan más
   campo; es una herramienta de comparación, la interfaz definitiva de los modos se diseña en la Fase 3.

**Decisión que necesito antes de seguir** (no avanzo sin ella):

- **A — Retarget en memoria al humano JSON** para Mixamo y Mocap: al cargar el banco se convierten sus rotaciones del
  reposo del futbolista al del humano JSON, solo en memoria (sin tocar ningún archivo) y como opción separada en el banco
  de pruebas. Es lo que permite la comparación sobre el mismo cuerpo que pediste. Es una corrección, por eso pido tu
  autorización.
- **B — Comparar sobre el cuerpo original de cada banco** (lo que ya permite la vista de diagnóstico) y decidir con eso.
- **C — Otra opción** que prefieras.
