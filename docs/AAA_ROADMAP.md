# Free Kick Swipe — Plan maestro AAA 2.0: primera entrega

Fecha: 2026-11-08. Rama `claude/init-repo-reforma-tiros-c7vapt`. Responde a la sección 19 del «Plan maestro AAA 2.0»
(primera entrega) y a los errores que el usuario vio jugando (arquero que se tira antes, círculo de la zona que no se
borra, jugadores trabados esperando el resultado, pelota suelta sin despejar).

**Regla de esta entrega:** todo lo que dice «medido» se midió en esta sesión (PC Linux, Godot 4.7.2, render por software
llvmpipe para las pruebas con esqueleto animado). **Nada de lo que sigue se probó en un teléfono.** Los números de
Android que faltan están marcados como *pendiente de medir en el dispositivo*, con el procedimiento para medirlos.

Índice:
1. Auditoría de los sistemas actuales
2. Inventario de animaciones de tiro libre y penal
3. Clasificación de técnicas y variantes
4. Diagnóstico: el arquero toca la pelota pero no evita el gol
5. Plan de calibración del disparo táctil
6. Análisis de rendimiento en Android
7. Diseño de carga selectiva de animaciones (compatible con PackLibrary)
8. Propuesta de personalización de estilos de tiro
9. Hoja de ruta (prioridades y dependencias)
10. Primera mejora segura: qué se implementó y cómo se probó

---

## 1. Auditoría de los sistemas actuales

| Sistema | Archivos | Estado | Evidencia | Riesgos / pendientes |
|---|---|---|---|---|
| Flujo de modos (penales, tiro libre) | `scripts/setpiece/setpiece_game.gd` | Funciona | `test_penalty_turn_flow`, `test_entering_a_mode_does_not_freeze` | Archivo grande (≈950 líneas): conviene separar el flujo de penales y el de tiro libre cuando crezca |
| Disparo por trazo | `shot_gesture.gd`, `gesture_shot_model.gd`, `gesture_tuning.gd`, `shot_solver.gd` | Funciona; coeficientes de PC | `tests/test_shot_gesture.gd` (9 pruebas; predicción vs pelota real ≤ 0,45 m) | Calibración en teléfono pendiente (§5) |
| Elección del golpeo | `shot_catalog.gd`, `resources/setpiece/shot_clips.json` | Funciona: 560 golpeos medidos | `test_kick_choice_follows_the_direction_of_the_shot`, `test_foot_surface_follows_the_shot`, `test_the_foot_reaches_the_ball_at_the_impulse` (peor pie-pelota 0,27 m) | Pocos golpeos de «exterior» (38 de 560) |
| Tirador | `sp_shooter.gd` | Funciona | `test_a_kick_never_gets_stuck`, `test_shooters_wait_beside_the_ball_on_their_side` | — |
| Arquero (tiros libres y penales) | `sp_keeper.gd` + `scripts/goalkeeper/keeper_planner.gd` | Corregido en esta entrega (§4) | `test_keeper_contact_uses_the_real_impact_normal`, `test_keeper_deflection_decides_by_physics`, pruebas de render | El tiro libre todavía usa el radio de plan del partido (§9, fase 1) |
| Barrera y jugadores sueltos | `sp_wall.gd`, `sp_field_players.gd` | Funciona | `test_the_wall_really_blocks_the_ball` | — |
| Pelota suelta | `sp_loose_ball.gd` (nuevo) | Nuevo en esta entrega | `test_a_loose_ball_never_stays_dead_in_the_box` | Sin festejo del arquero cuando la recoge |
| Detección de gol | `scripts/pitch/goal.gd` | Correcta; un error latente corregido | `tests/test_goal_detection.gd` (6 pruebas nuevas), `test_side_netting_from_outside_is_not_a_goal` | — |
| Red física | `scripts/pitch/cloth_net.gd` (tela Verlet) + `goal_net.gd` (frenado medido) | Funciona (híbrido) | `test_both_goal_types_keep_the_ball_in_the_net` | Costo en teléfono sin medir (§6) |
| Pelota y predicción | `scripts/ball/ball.gd`, `BallPredictor` | Funciona | `test_shot_gesture` (vuelo) | **Nuevo hallazgo:** la predicción sobrestima cuánto rueda una pelota pateada SIN efecto (6,0 m previstos, 3,9 m reales): no modela el deslizamiento inicial (§9, fase 1) |
| Banco de animaciones JSON | `scripts/animation/pack_library.gd`, `sp_clips.gd`, `assets/animations/json_*.res` | Funciona (único banco) | `test_bank_integration`, `test_entering_a_mode_does_not_freeze` | Se carga entero: 25 + 6,6 + 7,4 MB (§7) |
| Diagnóstico y rendimiento | `scripts/diagnostics/prof.gd`, `diagnostics_overlay.gd` | Ahora también en penales y tiros libres (botón «Diag.») | — | Faltan las mediciones en el teléfono (§6) |

## 2. Inventario de animaciones de tiro libre y penal

Fuente: `resources/setpiece/shot_clips.json` (golpeos medidos por `tools/setpiece/build_shot_catalog.gd`) y
`resources/animation/catalogo_bancos.json` (1.248 clips con rol del banco JSON, de las 3.223 variantes que salen de
los 2.022 archivos fuente; ver `docs/reforma/FASE1_INFORME.md`). Ningún clip se borró ni se modificó.

**Golpeos medidos (560 = 280 originales + 280 espejos; 280 de pie derecho y 280 de pie izquierdo):**

| Rol | Total | Originales | Velocidad del pie (mediana) | Carrera medida (mediana) | Ángulo de salida (rango) |
|---|---|---|---|---|---|
| `kick_shot` | 140 | 70 | 13,9 m/s | 1,19 m | ±28° |
| `kick_pass` | 126 | 63 | 9,5 m/s | 1,04 m | ±45° |
| `kick_pass_soft` | 106 | 53 | 6,4 m/s | 0,68 m | ±70° |
| `kick_shot_hard` | 86 | 43 | 16,3 m/s | 1,26 m | ±25° |
| `setpiece_shot` | 54 | 27 | 16,8 m/s | 5,01 m | ±38° |
| `setpiece_pass` | 18 | 9 | 11,8 m/s | 1,34 m | ±34° |
| `kick_lob` | 16 | 8 | 9,3 m/s | 0,54 m | ±31° |
| `setpiece_miss` | 10 | 5 | 15,4 m/s | 4,95 m | ±28° |
| `setpiece_lob` | 4 | 2 | 10,3 m/s | 5,09 m | ±5° |

Superficie del pie (medida en 3D en el contacto): interior 321, empeine 201, exterior 38. Golpeo «limpio» (pie en la
pelota sin rozar el piso): 280 de 560.

**Arquero (`catalogo_bancos.json`, originales + espejos):** estiradas `gk_dive` 216, atajadas `gk_catch` 94, recogidas
`gk_scoop` 36, levantadas `gk_getup` 21, bloqueos `gk_block` 14, espera `gk_idle` 3 + `gk_idle_var` 3, desplazamiento
`gk_loco` 6, paso lateral `gk_sidestep` 2, fallo `gk_miss` 2.

**Reacciones y resto:** lamentos `dejected` 95, festejos `celebrate` 64, festejo de equipo `celebrate_team` 43, festejo del
goleador `celebrate_scorer` 20, barrera `wall` 18, reposo `idle_ready` 8 + `idle` 4, marcha (`jog`, `loco_jog`, `run`,
`sprint`, `loco_sprint`) 16.

## 3. Clasificación de técnicas y variantes

El golpeo se describe con cuatro ejes, todos medidos en el clip (no por el nombre):

1. **Familia** (rol): tiro (`kick_shot`, `kick_shot_hard`), pelota parada (`setpiece_*`, con carrera larga de ~5 m),
   pase (`kick_pass`, `kick_pass_soft`), globo (`kick_lob`, `setpiece_lob`) y error (`setpiece_miss`).
2. **Superficie:** interior (colocada, curva hacia adentro), empeine (potencia, sin efecto o con efecto liftado), exterior
   (curva hacia afuera).
3. **Potencia:** velocidad del pie en el contacto (6–17 m/s), que se compara con la velocidad pedida por el trazo.
4. **Dirección:** ángulo entre la carrera y la salida de la pelota («swing»), con signo según el pie.

El tipo de tiro del gesto (`ShotCatalog.Kind`: POWER, NORMAL, PLACED, CHIP, MISS) elige la familia y la superficie; la
dirección y la potencia eligen el clip concreto dentro de la familia (`ShotCatalog.choose`: costo por ángulo, tipo,
superficie, velocidad del pie y largo de carrera, con rotación entre los mejores para no repetir). Ejemplo pedido por el
usuario: diestro, a su derecha, despacio → PLACED + interior → `setpiece_shot` o `kick_shot` de interior cuyo swing
coincide con el ángulo pedido.

Variantes del arquero: estirada (alta/baja según la altura de las manos en el contacto), atajada de frente, bloqueo con
el cuerpo, recogida baja, paso lateral; el plan (`KeeperPlanner.plan_save`) elige por la trayectoria medida de las
manos, no por el nombre.

## 4. Diagnóstico: el arquero toca la pelota pero no evita el gol

Medido con pruebas de render de 18 penales (6 zonas × 3 velocidades) con el arquero del usuario jugado a la zona
correcta y 18 con la IA:

| Causa | Evidencia (medida) | Arreglo | Resultado (medido) |
|---|---|---|---|
| **Normal del choque mal calculada.** Se tomaba el punto del recorrido de la pelota más cercano al centro de la esfera de la mano: ese punto es perpendicular al recorrido, así que TODO toque era un roce y la pelota seguía con el 80 % de su velocidad hacia el arco | Toques con 18,6 → 14,6 m/s, 23,1 → 18,4 m/s (siempre ×0,8), y gol | `SpKeeper.contact_along`: instante real del choque en el movimiento relativo pelota-esfera, normal de la esfera a la pelota en ese instante | Tiro al pecho: vuelve a −8,6 m/s (`test_keeper_deflection_decides_by_physics`) |
| **La pelota atravesaba la mano entre dos pasos** (a 25 m/s avanza 0,42 m por paso) | Contactos detectados ya pasada la mano | Se mira también el paso que viene: el impulso sale antes de atravesarla | — |
| **Guante modelado como esfera chica** | Toque lateral cerca de la línea: 18,3 → 13,2 m/s, sigue adentro | Palma orientada hacia la pelota que llega de frente (`glove_normal`, `PALM_BIAS` 0,8) y más agarre del guante (`GLOVE_GRIP` 0,6) | Toques que terminan en gol: de 4 a 2 de 18 |
| **El plan «llegaba» a 0,42 m de la pelota** (radio del partido) **pero el contacto físico pide ~0,24 m** | Mano a 0,39–0,48 m de la pelota con un plan «válido» | `KeeperPlanner.plan_save(..., radius_scale)`; los penales piden `PLAN_RADIUS_SCALE` 0,6 (el partido no cambia) | Toques con la zona correcta: de 7–8 a 10 de 18 |
| **Se tiraba antes** (pedido del usuario) | La estirada arrancaba 0,2–0,7 s antes del golpe (hasta 1,3 s) | `PENALTY_ANTICIPATION` 0,12 s como máximo; al ver salir la pelota ajusta el momento (no el lado) | Lo más temprano: 0,12 y 0,18 s antes del golpe en dos corridas (el tiempo de la carrera es una estimación); la prueba admite 0,22 s (`test_the_penalty_keeper_does_not_dive_before_the_kick`) |

Balance resultante (medido en PC, no en teléfono): el arquero del usuario jugado a la zona exacta ataja 6 de 18 (los
ángulos altos a 26 m/s son imposibles, como en la realidad); la IA, que adivina el lado, ataja 3 de 18 (≈17 %). El
arquero que se tira al otro lado nunca la toca. **No es invencible:** solo cambió cómo se resuelve un contacto que ocurre
de verdad.

Otros hallazgos de esta auditoría:
- **Gol fantasma al reiniciar** (`goal.gd`): después de `reset_latch` el arco tomaba la posición vieja de la pelota como
  si acabara de cruzar la línea desde un punto ficticio y emitía un gol en ese primer paso. No afectaba al resultado
  (el juego lo ignora fuera del vuelo), pero sí a cualquier otro oyente. Ahora el primer paso solo registra la posición.
- **El arquero nunca recogía una pelota suelta en el banco JSON:** `KeeperPlanner.PICKUP_CLIPS` tenía los nombres del
  banco viejo (Mixamo). Ahora los roles `gk_scoop` y `gk_catch` cuentan como recogida: 130 candidatos (antes 0). Afecta
  también al arquero del partido (ahora puede recoger).

## 5. Plan de calibración del disparo táctil

Los coeficientes de `GestureTuning` (`user://gesture_tuning.tres`) están ajustados en PC con trazos sintéticos. En el
teléfono cambian la resolución, la frecuencia de muestreo del táctil y el tamaño del dedo. Procedimiento (lo hace el
usuario en su teléfono, con el panel «Diag.»):

1. **Muestreo:** abrir «Diag.», hacer 10 trazos rápidos y anotar las muestras por trazo y la velocidad pico que muestra el
   panel. Si hay menos de ~12 muestras en un trazo rápido, bajar `min_step`.
2. **Potencia:** 10 trazos «suaves» y 10 «fuertes». Ajustar `speed_slow` y `speed_fast` para que los suaves den
   potencia 0,2–0,4 y los fuertes 0,85–1,0 (deslizadores del panel; se guardan solos).
3. **Curva:** 10 trazos rectos (la curvatura medida debe quedar bajo `curve_deadzone`) y 10 curvos (efecto lateral
   visible). Ajustar `curve_deadzone` y `spin_gain`.
4. **Altura:** trazos que terminan bajando (deben dar tiro raso con efecto liftado) y subiendo (tiro alto): ajustar
   `descend_drop` y `ascend_lift`.
5. **Precisión:** con el comparador del panel, comprobar que un trazo prolijo cae a menos de 0,5 m del objetivo y uno
   tembloroso se abre más (`error_rough`).

Criterios de aceptación (a verificar en el teléfono, no verificados todavía): 9 de cada 10 trazos fuertes clasificados
como potentes; ningún trazo recto con efecto visible; la vista previa coincide con la pelota real a menos de 0,45 m (ya
medido en PC).

## 6. Análisis de rendimiento en Android

**Lo que está medido (PC, no vale como medición de teléfono):**
- Entrar a un modo: la carga de PackLibrary con 12 jugadores conectados costaba 6,5 s; con la copia `duplicate(false)`,
  22–40 ms.
- Red de tela: 457 nodos y 657 hilos (arco de caja), 0,8 ms por paso de física mientras simula (solo con la pelota cerca).
- Primer plan de atajada: 652 ms (incluía la inicialización); ahora se calcula al cargar (`KeeperPlanner.warm_cache`).
- Bancos de animación cargados enteros: `json_clips.res` 25 MB, `json_keeper.res` 6,6 MB, `json_scenes.res` 7,4 MB.

**Lo que no está medido (pendiente de medir en el dispositivo):** FPS sostenidos, tiempo de física por paso, costo de la
tela, de los AnimationPlayer (hasta 12 en penales: 2 tiradores, 2 arqueros, 6 del banco y más en el tiro libre), memoria
y tiempo de carga del modo.

**Cómo medirlo ahora:** en penales o tiro libre, tocar «Diag.»: además del panel del trazo aparece el medidor del
juego (`DiagnosticsOverlay`): FPS, tiempo de cuadro medio y pico, tiempo de proceso y de física, llamadas de dibujo,
nodos, memoria y **el costo por sistema en ms por paso de física** (red de tela, arco, plan del arquero, contacto del
arquero, pelota suelta, predicción del resultado). Pedido al usuario: una captura del medidor en tres momentos (apuntando,
durante el vuelo con la pelota en la red, y en el festejo) en penales y en tiro libre.

**Presupuesto propuesto (a validar con esas capturas):** 16,6 ms por cuadro a 60 FPS (o 33 ms con tope de 30): física
total ≤ 4 ms por paso; red de tela ≤ 1,5 ms; arquero ≤ 1 ms; animación ≤ 4 ms.

**Riesgos y palancas si no llega:** menos iteraciones de la tela (`ClothNet.ITERATIONS` 3 → 2) o separación mayor; los
jugadores del banco con un `AnimationPlayer` que avanza a 30 Hz o detenido cuando no están en cámara; carga selectiva de
animaciones (§7); sombras y resolución 3D por perfil gráfico (`GraphicsSettings`).

## 7. Diseño de carga selectiva de animaciones (compatible con PackLibrary)

**Restricciones:** no borrar ni modificar los 2.022 JSON originales ni los clips del catálogo; no deshacer la corrección
de PackLibrary (copia `duplicate(false)` de la biblioteca compartida); no crear sistemas duplicados.

**Prioridades:**
- **P0 (siempre, al entrar al modo):** reposo, espera del arquero, el golpeo del usuario según su pie, las estiradas
  (`gk_dive`, `gk_catch`, `gk_block`), levantadas y la marcha.
- **P1 (en segundo plano después de entrar):** el resto de los golpeos medidos (`shot_clips.json`), barrera, recogidas.
- **P2 (al terminar la primera jugada):** festejos, lamentos y reacciones.
- **P3 (bajo demanda):** banco de pruebas, escenas y clips sin rol en los modos.

**Metadatos por clip** (se agregan a `catalogo_bancos.json` sin tocar los existentes): `prioridad` (P0–P3), `estado`
(`medido` / `asignado` / `sin_revisar`), `evidencia` (prueba o herramienta que lo midió, p. ej.
`build_shot_catalog.gd`), `confianza` (0–1, p. ej. golpeo limpio con contacto medido = 1).

**Módulos pedidos y dónde viven (sin duplicar):**

| Pedido | Se implementa en | Por qué ahí |
|---|---|---|
| AnimationCatalog | `catalogo_bancos.json` + `SpClips` / `ShotCatalog` | Ya son el catálogo; se agregan los campos de prioridad y estado |
| AnimationLoadPlanner | función nueva en `SpClips` que arma la lista P0–P3 del modo | `SpClips` ya arma las bibliotecas de los actores |
| AnimationCacheManager | `PackLibrary` | Ya guarda la copia `duplicate(false)`; agregaría bibliotecas por prioridad |
| AnimationProfile | una lista de roles por modo en `SpClips` | Penales y tiro libre usan roles distintos (barrera solo en tiro libre) |
| AnimationPerformanceMonitor | `Prof` + `DiagnosticsOverlay` | Ya miden; se agrega el costo de carga |

**Paso técnico necesario:** hoy cada biblioteca es un único `.res` con todos sus clips; para cargar por prioridad hay que
generar bibliotecas derivadas por prioridad (herramienta de construcción, como `tools/build_animation_library.gd`)
**además** de las actuales, que quedan como fuente y respaldo. Agregar clips a una biblioteca ya conectada reconstruye la
caché de cada AnimationPlayer (la causa del congelamiento de 6,5 s): las bibliotecas P1/P2 se agregan como bibliotecas
nuevas (`add_animation_library`) antes de conectar o en un cuadro sin jugada, y se mide con `test_entering_a_mode_does_not_freeze`.
No se implementa en esta entrega: primero hay que medir en el teléfono si la carga entera es un problema (§6).

## 8. Propuesta de personalización de estilos de tiro

Un «estilo» es una preferencia sobre el catálogo medido, no una animación nueva: así la física no cambia (la pelota sale
del modelo del trazo y el impulso se da en el contacto medido de cada clip).

- **Familias de fases:** aproximación (carrera corta/larga, recta/en curva), golpeo (superficie, velocidad del pie),
  seguimiento (largo del seguimiento de la pierna) y recuperación (vuelta al reposo o salida corriendo). Todas se leen de
  los metadatos ya medidos (`run`, `foot_speed`, `surface`, `len`, `roots`).
- **Estilo = pesos en `ShotCatalog.choose`:** p. ej. «carrera larga de tiro libre» suma costo a los clips con `run` < 3 m;
  «potente» prefiere empeine con `foot_speed` alto. Se guarda en `SpSettings` como un perfil del jugador.
- **Compatibilidad física garantizada por prueba:** cada estilo pasa `test_the_foot_reaches_the_ball_at_the_impulse`
  (pie a menos de 0,4 m de la pelota en el impulso) y `test_kick_choice_follows_the_direction_of_the_shot`.
- **Sin compras reales:** si más adelante hay estilos desbloqueables, se desbloquean jugando; nada de tienda sin
  aprobación.

## 9. Hoja de ruta (prioridades y dependencias)

| Fase | Contenido | Depende de | Prioridad |
|---|---|---|---|
| 0 | **Jugabilidad inmediata** (esta entrega): arquero que no se adelanta, contacto físico corregido, pelota suelta, reacciones, detección de gol probada, medidor en «Diag.» | — | Hecha (falta la prueba en el teléfono) |
| 1 | Arquero del tiro libre con el mismo radio de plan que el penal (`PLAN_RADIUS_SCALE`), midiendo el balance de 16 tiros; predicción de rodadura con deslizamiento inicial en `BallPredictor` | 0 | Alta |
| 2 | Calibración del trazo en el teléfono (§5) | Capturas del usuario | Alta |
| 3 | Rendimiento medido en el teléfono (§6) y ajustes por perfil gráfico | Capturas del usuario | Alta |
| 4 | Carga selectiva de animaciones (§7) | 3 (solo si la carga o la memoria son un problema) | Media |
| 5 | Metadatos de evidencia y confianza en el catálogo (estado, evidencia, confianza) | — | Media |
| 6 | Estilos de tiro personalizables (§8) | 5 | Media |
| 7 | Arquero que festeja con la pelota en las manos; despeje del arquero con saque largo | 0 | Baja |
| 8 | Presentación: repeticiones del gol, cámaras de festejo, sonido del público por jugada | 3 | Baja |
| 9 | Contenido y progresión (desafíos de tiro libre, minijuegos) | 2, 3, 6 | Baja |
| 10 | En línea y tienda | **Aprobación expresa del usuario**; nada de compras reales ni jugadores reales sin derechos | No empezar |

## 10. Primera mejora segura: qué se implementó y cómo se probó

Cambios (todos con prueba):
- **El arquero ya no se tira antes** en los penales (`SpKeeper.PENALTY_ANTICIPATION`) y ajusta el momento al ver salir la
  pelota. Prueba de render `test_the_penalty_keeper_does_not_dive_before_the_kick`: lo más temprano, 0,18 s antes del golpe
  (límite de la prueba 0,22 s; antes, hasta 1,3 s).
- **El círculo de la zona elegida se borra** al salir la pelota y al empezar cada turno (misma prueba).
- **Contacto del arquero con física real** (normal del choque, sin atravesar la mano, guante): `test_keeper_contact_uses_the_real_impact_normal`,
  `test_keeper_deflection_decides_by_physics`, `test_the_keeper_touches_what_he_reaches_and_not_what_he_does_not`
  (con la zona correcta toca 3 de 6 tiros a 18 m/s; del otro lado, 0).
- **Nadie se queda en bucle esperando el resultado:** el resultado sale apenas ya no puede ser gol
  (`_goal_impossible`, `test_the_result_is_decided_only_when_a_goal_is_impossible`), el tirador mira la pelota mientras
  viaja, y la reacción que llega mientras todavía patea o se tira queda pendiente y sale al terminar
  (`test_shooter_and_keeper_react_after_finishing_their_move`).
- **La pelota nunca queda muerta en el área** (`SpLooseBall`): el defensor más cercano corre, se acomoda y la despeja con
  un golpeo del banco (el impulso solo sale si el pie llega de verdad a la pelota); el arquero la recoge con las manos
  dentro de su área o la despeja con el pie; si uno no llega, va otro. El tiro ya cuenta como fallido (barrera, palo,
  atajada o despeje): `test_a_loose_ball_never_stays_dead_in_the_box` (despejes en 1,1–2,0 s; recogida del arquero en 2,0 s).
- **Detección de gol** con la pelota y el arco reales: entera sobre la línea sí / a medias no, palo-adentro y palo-afuera,
  travesaño-adentro y travesaño-afuera, desde atrás o por encima no, desviada por el arquero, la que entra y vuelve a
  salir es un solo gol (`tests/test_goal_detection.gd`).
- **Medidor de rendimiento** en «Diag.» de penales y tiro libre (§6).

Lo que NO se hizo en esta entrega (a propósito): carga selectiva, estilos de tiro, cambios del arquero del tiro libre,
cambios de balance del trazo, nada en línea ni de tienda.

---

# Segunda entrega (2026-11-08): física pendiente, arquero, medición en Android

Pedido: «FREE KICK SWIPE — SIGUIENTE ENTREGA» (fases 1–11). Se trabajó en orden y por fases; cada fase con pruebas y
commit. **Todo lo medido es de PC; en el teléfono no se midió nada todavía.**

## Fase 1.1 — Predicción de rodadura (hecha)

**Causa (medida):** `BallPredictor` suponía que una pelota que sale por el piso ya rueda. En Jolt, una pelota pateada sin
efecto desliza: la fricción del césped (mu = menor de pelota 0,6 y césped 0,8, medida 0,58–0,60) frena el centro y hace
girar la esfera hueca (I = 2/3 m r²: la velocidad de deslizamiento cae 2,5 veces más rápido que la del centro) hasta que
rueda. Entra en rodadura a 0,31–0,49 de su velocidad inicial (0,18–0,78 s).

**Modelo:** el predictor sigue la velocidad de la superficie (`spin_v`) y aplica la fricción de deslizamiento hasta
rodar, con efecto adelante o atrás (puede frenarla del todo y hacerla volver), y la rodadura de Ball. Sin coeficientes
nuevos: mu sale de los materiales (`Ball.FLOOR_FRICTION`) y los factores de la inercia de la pelota. Con el giro real
(`spin_is_state`) en penales y tiros libres; las llamadas del partido viejo no cambian.

**Tolerancia definida:** distancia final dentro de max(0,15 m; 3 %), tiempo hasta frenarse dentro de 0,12 s, posición a
1 s dentro de max(0,12 m; 3 %). Medido (`test_ball_roll_prediction`):

| Caso | Real | Predicho antes | Predicho ahora |
|---|---|---|---|
| 10 m/s sin giro | 6,10 m, 2,93 s | 9,25 m | 6,12 m, 2,95 s |
| 16 m/s sin giro | 11,98 m | 18,66 m | 12,02 m |
| 6 m/s efecto atrás | 2,01 m | 5,02 m | 2,02 m |
| 12 m/s ya rodando | 11,92 m | 12,2 m | 12,22 m (2,5 %) |
| 14 m/s, bote, efecto | 20,23 m | — | 19,71 m (2,6 %) |

## Fase 1.2 — Arquero del tiro libre (hecha)

Medición reproducible: 16 tiros fijos (centro, ángulos, con efecto, colocados, potentes, por encima de la barrera) con
semillas fijas (`tests/test_fk_balance_measure.gd`, a pedido con el argumento `medir`).

| Variante | Atajadas | Goles | Barrera | Palo/afuera | Estiradas | Canceladas |
|---|---|---|---|---|---|---|
| Antes, radio de plan 1,0 | 3 | 6 | 5 | 2 | 14 | — |
| Antes, radio 0,6 (el del penal) | 2 | 7 | 5 | 2 | 15 | — |
| **Ahora, radio 1,0** | **3** | **5** | **6** | **2** | **11** | **4** |
| Ahora, radio 0,6 | 2 | 7 | 5 | 2 | 12 | 1 |

- **No se copió el radio del penal:** en el tiro libre el arquero lee la pelota con error de percepción y un plan más
  justo tolera menos ese error (un tiro flojo al centro pasaba a ser gol). Se queda en 1,0.
- **Arreglos:** sigue leyendo la pelota mientras espera para tirarse; si la barrera la desvía, cancela (antes se tiraba a
  la nada en 3 de los 5 tiros a la barrera); la lectura más cercana (menos error) reemplaza al plan.
- **Comparación con el penal:** en el tiro libre ataja 3 de 8 tiros al arco que pasan la barrera (37 %); en el penal,
  jugado a la zona exacta, 6 de 18 (33 %); la IA del penal, que adivina el lado, 3 de 18 (17 %). Los ángulos bien
  pateados entran; los flojos o al cuerpo se atajan. Ni invencible ni regalado.
- **Errores de posicionamiento:** en los tiros al ángulo (desde 22–24 m) el arquero queda a 1,5–2,2 m de la pelota al
  cruzar la línea: los clips de estirada medidos no cubren esa distancia (límite físico, no de lectura).

## Fase 1.3 — Después de la atajada (hecha)

- Penal: el arquero **festeja primero** (después de levantarse) y después va por la pelota suelta; con la pelota en las
  manos la suelta a un costado y festeja.
- Tiro libre: con la pelota en las manos la suelta y **la saca lejos** con un golpeo del banco (mismo sistema que los
  despejes: el impulso solo sale si el pie llega a la pelota).
- Pelotas cerca del arquero, rebotes al área, desvíos a los costados: `SpLooseBall` (primera entrega) elige al que llega
  antes; si falla, va otro.

## Fase 2 — Android (preparada; sin mediciones de teléfono)

- `PerfSession` (Diag. > «Medir rendimiento» / «Copiar informe») y guía [`docs/ANDROID_MEDICION.md`](ANDROID_MEDICION.md).
- Gráficos: Auto / Muy bajo / Bajo / Medio / Alto en el menú. Auto baja un escalón en el teléfono si no llega (heurística
  a validar). La física no cambia con el perfil (prueba).

**PC (medido, Linux, 4 núcleos, render por software llvmpipe, 1280×720, perfil Alto):**

| Momento | Penal: cuadro medio / p95 | Penal: física | Tiro libre: cuadro medio / p95 | Tiro libre: física |
|---|---|---|---|---|
| apuntando | 66 / 93 ms | 6,3 ms | 86 / 97 ms | 1,1 ms |
| carrera | 45 / 48 ms | 6,8 ms | 88 / 98 ms | 2,6 ms |
| red | 51 / 59 ms | 8,3 ms | — | — |
| estirada | 49 / 58 ms | 1,1 ms | 87 / 101 ms | 7,2 ms |
| despeje | — | — | 82 / 95 ms | 4,4 ms |
| festejo | 57 / 67 ms | 4,1 ms | 79 / 92 ms | 7,1 ms |

- En esta PC manda la GPU por software (40–80 ms); **no sirve para predecir el teléfono**. Sí sirve el costo de CPU de
  cada sistema: red de tela 0,42 ms por paso con la pelota en la red, red del arco 0,36, pelota suelta 0,25, plan del
  arquero 0,16, contacto del arquero 0,10, predicción del resultado 0,08 (todo < 0,5 ms).
- Pista para el teléfono: el tiro libre dibuja ~178.000 primitivas contra ~35.000 del penal (barrera, sueltos): si el
  teléfono no llega en el tiro libre y sí en el penal, la geometría de los jugadores es la primera sospechosa.
- Memoria estática 213–215 MB, 10 AnimationPlayer en el penal y 13 en el tiro libre, 352–387 nodos.

**Pendiente del usuario:** el informe del teléfono (guía, §2). Con eso: comparación PC/Android y optimizaciones
justificadas (fase 2.1). Sin datos no se optimiza nada a ciegas.

## Fases 3–5 — Academia, Arena y puntuación (hechas, primera versión)

Una sola arquitectura configurable (ver `docs/technical-index/SYSTEMS/SETPIECE.md`, «Academia de tiros y Arena de
desafíos»): cada ejercicio o desafío es una definición de datos (punto de la pelota, arquero y su dificultad, barrera,
intentos, aciertos pedidos, velocidad mínima, racha, blancos, objetos, obstáculos, medallas, recompensa) que juega el
juego de siempre. No hay un sistema por desafío.

**Academia de tiros (8 niveles, 37 ejercicios):** 1 Fundamentos (apuntar, disparo recto, potencia, altura, objetivo
grande) · 2 Precisión (esquinas, ángulos, racha) · 3 Potencia (velocidad mínima, 25 y 30 m, potencia con blanco) ·
4 Efecto (curva adentro y afuera alrededor de un poste, comba sobre la barrera, efecto con colocación) · 5 Técnicas
avanzadas (vaselina por un aro alto, disparo seco, interior colocado, empeine potente, exterior, cruzado) · 6 Tiros libres
profesionales (barrera y arquero, 30 m, ángulo difícil, arquero difícil, solo ángulos) · 7 Penales (esquinas, alturas,
racha, potencia contra arquero difícil) · 8 Élite (arquero extremo, 3 intentos, ventana de 70 cm, 35 m). Cada uno con
objetivo, explicación, intentos, puntuación, medallas, récord, recompensa (experiencia; cosmético con el oro, definido
por ejercicio) y desbloqueo del nivel siguiente (bronce en la mitad de los ejercicios del anterior: no obliga a repetir
uno). **Práctica libre:** todo abierto, sin tocar el progreso.

**Arena de desafíos (17, en 5 dificultades):** Precisión (poste izquierdo y derecho, travesaño, aro, ventana chica, blanco
que se mueve, secuencia) · Objetos (conos, botellas, bloques, torre: cuerpos con física que la pelota voltea) · Distancia
(40 m, aro suspendido, por encima de una fila de maniquíes) · Especiales (blancos que desaparecen, solo con rebote, tres
blancos en orden). Dificultad Fácil → Extremo: blancos 1,3× → 0,55×, intentos +2 → −2, arquero desde Difícil (Normal,
Difícil, Profesional según el nivel), movimiento más rápido; cada dificultad se abre con bronce en la anterior.

**Puntuación (habilidad, no azar):** por acierto 100 + precisión (hasta 60, medida donde cruzó la pelota) + distancia
(3 por metro desde 16 m, hasta 60) + potencia si el desafío la pide (6 por m/s sobre el mínimo, hasta 60) + racha (25 por
acierto seguido, hasta 100) + especiales (palo, travesaño, rebote: 50); todo por la dificultad (×1 a ×2); intentos de
sobra al completarlo: 40 cada uno. Un fallo suma 0. Medallas por umbral (escalan con la dificultad). Se muestran puntos,
récord, medalla, comparación con la marca anterior y experiencia ganada.

**Pruebas:** `tests/test_challenges.gd` (catálogo válido en todas las dificultades, puntuación, progreso y desbloqueos,
blancos detectados con la pelota real, ejercicio jugado de punta a punta, pantalla de selección).

**Límites de esta primera versión:** no hay «dos arqueros», «arquero impredecible» ni «barrera móvil» (necesitan un
segundo arquero o mover la barrera con física: siguiente iteración); la «torre» es una pila de 3×3 bloques; los
cosméticos se registran pero todavía no se pueden usar (fase 7).

## Fases 6–12 — Diseño (sin implementar en esta entrega)

**6. Presentación (en desarrollo: público que acompaña la jugada y guantes del arquero hechos el 2026-11-08):** cámaras ya existentes (preparación, detrás de la pelota con zoom, seguimiento en el tiro libre,
festejo, atajada); faltan: cámara lenta en el gol especial (escala de tiempo solo de la presentación, la física se repite
desde el registro de la jugada, ver 9), sonido de guantes y pasos, silencio previo al penal (bajar `Sfx.crowd` al apuntar)
y reacción del público según el resultado (ya: `Stadium11.set_cheer`). Efectos sin tapar la pelota: polvo de césped en el
apoyo (partículas chicas, solo en el contacto).

**7. Personalización:** estilos de golpeo como preferencias sobre el catálogo medido (ver §8 de la primera entrega);
pierna, carrera, seguimiento y celebración elegidos de los clips existentes con su contacto medido; botines, camiseta y
número por `SpSettings` y `kit_material` (ya usado para los colores); los cosméticos ganados en la Academia
(`PlayerProgress.cosmetics`) se aplican ahí. Compatibilidad: cada estilo pasa la prueba del pie en la pelota.

**8. Contenido y recompensas:** ya hay experiencia, niveles, récords y medallas; faltan logros (contadores sobre
`PlayerProgress`), desafíos diarios y semanales (un desafío de la Arena elegido por fecha con una semilla, sin servidor),
celebraciones desbloqueables. Sin tienda ni pagos reales.

**9. Repeticiones (implementada la base, 2026-11-08: `PlayRecording` + botón «Repetición», cámara lenta, tres cámaras;
faltan guardar los mejores momentos, favoritos y estadísticas):** registro por estados: cada paso guarda posición, rotación y velocidad de la pelota (`Ball.capture_state`
ya existe) y, de cada actor, clip, instante y marco (`SpActor.clip_id`, `clip_time`, `frame_origin`, `frame_facing`).
Una jugada de 5 s a 60 Hz son ~300 estados de pelota + ~10 actores × 300 (clip y tiempo): decenas de KB, no un video.
Reproducción: los actores reproducen sus clips en el instante guardado y la pelota se coloca desde el registro (en la
repetición la pelota no tiene física). Cámara lenta y otros ángulos, favoritos y estadísticas sobre el mismo registro.

**10. Modos futuros (solo diseño):** 1 penales por eliminación, 2 torneo de tiros libres, 3 duelo de precisión,
4 batalla de potencia, 5 dos arqueros, 6 competencia de poste y travesaño, 12 muerte súbita: todos son configuraciones
de las definiciones de desafío (mismo juego, reglas y puntuación distintas). 7 último en pie sobre plataformas, 8 caída
al agua, 9 batalla de obstáculos, 10 golpear al rival con la pelota, 11 cooperativo: necesitan reglas y física propias
(plataformas, empujones, contrajuego), separadas de los modos de tiro y fuera de la clasificación. En línea,
emparejamiento, tienda y monetización: fase posterior con aprobación expresa.

**11. Documentación y pruebas:** cada fase con su prueba (`test_ball_roll_prediction`, `test_fk_balance_measure`,
`test_perf_session`, `test_challenges`, render de `test_setpiece_render`); ningún umbral se bajó sin medición (los que
cambiaron están en el CHANGELOG con la razón física).

---

# Tercera entrega (2026-11-09): correcciones de jugabilidad, festejos y primer minijuego

Pedido: «PROMPT MAESTRO — correcciones de jugabilidad, celebraciones y expansión arcade», a partir de pruebas en el
teléfono. Todo lo de abajo se probó **en PC** (Linux, render por software llvmpipe); **nada se probó en Android** en esta
entrega.

## Etapa 1 — Arquero del tiro libre (hecha; pendiente de balance en el teléfono)

- **Problema:** demasiado fácil incluso en Difícil; se tiraba antes; la pelota seguía entrando.
- **Causa técnica (medida):** cuando ningún clip llegaba, `_watch_step` adoptaba igual el plan «forzado» con demora 0 y se
  tiraba en la primera lectura (con la pelota a ~20 m). En la medición de referencia 8 de 13 (Fácil), 8 de 15 (Normal) y 7
  de 15 (Difícil) estiradas fueron a pelotas que no alcanzaba. Además, una vez corregido eso, un diagnóstico cuadro a
  cuadro mostró que esperar a «falta poco» empeoraba el alcance: la mejor estirada pasaba a 0,57 → 0,73 → 0,96 m de la
  pelota en tres lecturas seguidas.
- **Cambio:** sin plan que llegue no se tira; se acomoda con pasos laterales (`SpSettings.keeper_step_speed`) y relee
  cada 0,1 s. Se tira «desesperado» solo si casi llega (`DESPERATE_REACH` 1,3 × radio) **y** es el momento de arrancar
  esa estirada (su demora ≤ 0,15 s) o la pelota está encima (≤ 0,55 s). Prefiere la estirada rápida
  (`KeeperPlanner.plan_save` con `tau_cost` 0,25) y lee mejor el efecto en dificultades altas (`keeper_spin_read`). No usa
  el radio de planificación de los penales. Las dificultades bajas conservan los errores de percepción y reacción.
- **Sistemas reutilizados:** `KeeperPlanner` (planes por trayectorias medidas de las manos), `BallPredictor`, el contacto
  real del guante (sin tocar la pelota por código).
- **Medición** (`tests/test_fk_balance_measure.gd medir difs=0,1,2`, con render, semillas fijas; 18 tiros por
  dificultad: centro fuerte y débil, los dos ángulos, rasantes, altos, efecto hacia adentro y hacia afuera, cerca del
  poste, débil colocado, al cuerpo, fuera de alcance alto y bajo, desde 4 puntos con barrera):

| Dificultad | Versión | Goles | Atajadas | Palo | Afuera | Barrera | Estiradas | Sin llegar | Anticipación media |
|---|---|---|---|---|---|---|---|---|---|
| Fácil | antes | 10 | 1 | 0 | 2 | 5 | 13 | 8 | 0,41 s |
| Fácil | ahora | 9 | 1 | 1 | 2 | 5 | 6 | 1 | 0,34 s |
| Normal | antes | 7 | 4 | 0 | 2 | 5 | 15 | 8 | 0,53 s |
| Normal | ahora | 5 | 5 | 0 | 2 | 6 | 9 | 3 | 0,57 s* |
| Difícil | antes | 7 | 3 | 0 | 2 | 6 | 15 | 7 | 0,54 s |
| Difícil | ahora | 5 | 5 | 0 | 2 | 6 | 10 | 1 | 0,38 s |

  *Incluye una lectura de 2,35 s en un tiro que desvió la barrera. «Antes» se midió con el código anterior en una copia
  aparte (mismo conjunto, mismas semillas). En Difícil ataja la mitad de los tiros que van al arco (5 de 10, antes 3 de
  10) y ya no se tira a pelotas imposibles; sigue sin alcanzar los ángulos lejanos (es justo: ver «fuera de alcance»).
- **Pendiente:** Normal y Difícil atajan lo mismo en este conjunto (18 tiros es poco para separarlos); ajustar con el
  informe del teléfono. Probado en Android: **no**.

## Etapa 2 — Ciclo de la jugada sin bucles (hecha)

- **Problema:** jugadores en bucle después de cada tiro. **Causa:** un clip de una vez terminado dejaba al jugador
  congelado en la última pose, y un bucle de carrera seguía al llegar (trotaba en el sitio).
- **Cambio:** `SpActor.rest_loop` (cada jugador tiene su reposo: tirador, arquero, barrera, sueltos) que vuelve solo al
  terminar un clip, al llegar o al frenarlo; `freeze_on_finish` para las poses que deben mantenerse (arquero con la
  pelota). Todos los resultados tienen salida: preparación → ejecución → vuelo → contacto → resultado → reacciones →
  festejo o lamento → recuperación de la pelota → jugada siguiente (topes ya existentes: carrera 6 s, vuelo 5,5 s,
  resultado 3,6–6 s).
- **Pruebas:** `test_play_lifecycle` (penal: gol, atajada, afuera; tiro libre: barrera, gol, afuera): nadie queda
  congelado ni trotando en el sitio 5 s después y la jugada siguiente llega.

## Etapa 3 — Festejos y lamentos (hecha)

- **Gol:** la cámara se queda en la vista de juego `GOAL_LIVE_T` = 2,6 s con temblor suave; los compañeros corren al
  autor (medido en tiro libre: de 16,0 / 12,8 / 15,6 m a 1,9 / 1,8 / 1,8 m, los tres llegan) y festejan alrededor; la
  pelota sigue su física. Después, si no se salta, el primer plano del autor (2,8 s). «Saltar» pasa a la jugada siguiente
  una sola vez (el gol se cuenta una vez: probado).
- **Contradicción informada (penal):** en una tanda los compañeros esperan en el círculo central, a ~40 m del punto
  penal; correr esa distancia lleva ~6 s. Decisión (no destructiva): salen a buscarlo y el autor, al terminar su
  festejo, corre hacia ellos; se encuentran en el camino (medido: a 2,0 m en 5,4 s). En el turno siguiente vuelven a su
  lugar (fuera de cámara).
- **Sin gol:** sin cinemática; el equipo que defendió corre a festejar hacia donde terminó la jugada (arquero si atajó,
  barrera si la paró, punto de salida si fue al palo o afuera, el que despejó) y el que pateó se lamenta. El que va por
  la pelota suelta sigue jugando.
- **Pruebas:** `test_celebrations` (5 pruebas). Probado en Android: **no**.

## Etapa 4 — Temblor de cámara y línea de destino (hecha)

- `SpCamera.shake` corre la imagen (`h_offset`/`v_offset`) sin mover la cámara ni el encuadre; máximo 0,11 m, medido
  0,057 m de pico en «Normal»; se apaga solo. Ajuste «Temblor de cámara: No / Suave / Normal».
- «Mostrar línea de destino de la pelota»: oculta la trayectoria prevista y el aro de llegada; no cambia la física ni el
  tiro; el rastro del dedo y los medidores siguen. Ambas en el panel «Visual» del menú y se guardan
  (`user://graphics.cfg`).

## Etapa 5 — «Botón de caída» (hecho; pendiente de balance)

- Dos plataformas sobre el vacío; botón físico en la plataforma rival (pared o piso) que se aprieta solo si la pelota lo
  golpea contra su cara a ≥ 2,5 m/s (un roce o una pelota lenta no: probado); se abre la trampilla y el rival cae. Turnos
  alternados contra la IA; gana el primero que hace caer 2 veces al otro; tope de 24 turnos.
- 8 niveles: a la vista, custodiado (postes y bloque), detrás del muro (botón en el piso), botón móvil, botón chico,
  desnivel (alturas y giros distintos), obstáculos en movimiento, varios rebotes (techo y muro bajo). Cada uno tiene
  solución hallada **con la física real** (búsqueda en una grilla de puntos y velocidades; se anota el tiro encontrado).
- IA con las mismas reglas y la misma física: apunta al botón (o al truco del nivel), adelanta el botón móvil con el
  tiempo de vuelo previsto y su carrera, espera su momento con obstáculos móviles y corrige parte de su fallo anterior.
  Balance medido (12 tiros por dificultad, Fácil / Normal / Difícil): nivel 1: 4 / 5 / 8; nivel 4 (móvil): 6 / 8 / 8;
  nivel 5 (chico): 3 / 3 / 4; nivel 7 (obstáculos móviles): 1 / 2 / 2.
- Cámara alta detrás del que patea; en su turno sus propios obstáculos se ven translúcidos (no tapan la pelota; la
  colisión no cambia) y una señal sobre el botón rival indica dónde está aunque lo tape un muro.
- Pruebas: `test_boton_caida` (6). Probado en Android: **no**.

## Etapa 6 — Arquitectura compartida de minijuegos (hecha)

`Minigame` (id único, reglas propias por subclase, ganar/perder, turnos, puntaje, reinicio, estados con topes, IA con
`cpu_shot`, intenciones serializables y semilla para en línea más adelante — sin implementar en línea ni emparejamiento),
`MinigameCatalog` (datos, desbloqueo por bronce, récords y medallas en `PlayerProgress`), pestaña «Arcade» y tarjeta
ARCADE en el menú. Reutiliza el trazo, la vista previa, el tirador animado, la cámara y la interfaz.

## Etapa 7 — Primera colección (en curso)

| Minijuego | Tipo | Niveles | Estado | Pruebas |
|---|---|---|---|---|
| Botón de caída | Versus por turnos contra la IA | 8 | Implementado · Pendiente de balance | `test_boton_caida` |
| Demolición | Física y destrucción (un jugador, tiros limitados) | 6: torre, pirámide, reacción en cadena, precisión, muro, torre inestable | Implementado · Pendiente de balance | `test_demolicion` |
| Enceste | Desafío de habilidad (aro físico, rebote en tablero) | 5: primer aro, por el tablero, aro lejano, aro móvil, doble aro | Implementado · Pendiente de balance | `test_enceste` |
| Minigolf | Golpes, par, penalizaciones | — | Pendiente (necesita apuntar a ras del piso: el trazo actual apunta a un plano vertical) | — |
| Arqueros por turnos | A patea, B ataja, rondas, desempate, muerte súbita | — | Pendiente (la tanda de penales ya alterna; faltan variantes) | — |
| Mecanismos y rescate, explosiva, dianas colgantes, circuito de aros | — | — | Pendiente | — |

Cada nivel jugable tiene solución comprobada con la física real (búsqueda automática de un tiro que lo resuelve) y
puntaje sin premio por participar. Error encontrado y corregido con render en Demolición: un bloque que solo bajaba un piso
en la torre contaba como derribado. Probado en Android: **no**.

## APK de la tercera entrega

Corrida 15 de GitHub Actions, verde (pruebas headless y con render, APK firmada de depuración y verificación de que los
JSON de la Academia, la Arena y los minijuegos estén dentro):
https://github.com/s4muy3ni-lang/Free-Kick-Swipe/actions/runs/42581243230 — artefacto `futbol5-apk` (vence el
2026-11-23). La corrida 14 (commit anterior, sin Demolición ni Enceste) también salió verde.

**Probado en PC:** suite headless 175 / 0 fallos; render de tiros libres y penales 7 / 0; medición del arquero con render.
**Probado en Android:** nada (falta que se pruebe en el teléfono: arquero del tiro libre, festejos, opciones visuales y
minijuegos).

# Cuarta entrega (2026-11-10/11): finalización del arcade y modos de fútbol físico

Probado en PC y en CI. **Nada se probó en Android.** Todos los modos son 3D en tercera persona y usan el mismo trazo del
dedo (ningún modo tiene joystick, botones de dirección ni cañón automático).

## Auditoría inicial (qué faltaba) y estado real ahora

| Elemento | Antes de esta entrega | Ahora | Pruebas |
|---|---|---|---|
| Personalización (fase 7) | Diseñada | **Hecha**: uniforme, piel, pelo, número, estilo de golpeo y carrera (pesos sobre el catálogo), tras el tiro, festejo; cosméticos bloqueados por logros | `test_customization` |
| Logros y desafíos diarios/semanales (fase 8) | Diseñados | **Hechos**: 14 logros, 3 diarios, 2 semanales, historial, carteles, anti-exploit | `test_achievements` |
| Minigolf | Pendiente (faltaba apuntar a ras) | **Hecho**: 6 hoyos, gesto a ras del piso, hoyo que captura solo la pelota lenta, arena, rampa, túnel, móviles | `test_minigolf` |
| Arqueros por turnos | Parcial (tanda) | **Eliminado** (2026-11-11, pedido del usuario) | — |
| Mecanismos, rescate, dianas colgantes (#43) | Pendientes | **Hechos**: Dianas (5) con articulaciones reales; Rescate (4) con botones, trabas, empujón y dominó | `test_dianas_rescate` |
| Que no caiga | Nuevo | **Eliminado** (2026-11-11, pedido del usuario) | — |
| Fútbol-tenis | Nuevo | **Eliminado** (2026-11-11, pedido del usuario) | — |
| Bowling | Nuevo | **Hecho**: 4 niveles, cuadros con strike y spare, contra la IA | `test_bowling` |
| FootPool | Nuevo | **Eliminado** (2026-11-11, pedido del usuario) | — |
| Rebotes de ingenio | Nuevo | **Eliminado** (2026-11-11, pedido del usuario) | — |
| Demolición ampliada | 6 niveles | **8 niveles** (barriles, soportes) | `test_demolicion` |
| Cámara de minijuegos | Fija por juego | Se volvió a la anterior (recuperada de Git) + ajustes por minijuego (ver «Reorganización del arcade») | `test_minigame_camera` |

## Pendiente (próxima etapa, después del análisis en el teléfono)

- Pantallas de presentación con identidad propia por modo (hoy: objetivo breve + escenario propio de cada juego).
- Balance de todos los minijuegos con partidas reales en el teléfono.
- En línea, emparejamiento, tienda y pagos: no implementados (requieren aprobación).

## Reorganización del arcade (2026-11-11, en curso por etapas)

Pedido «REORGANIZACIÓN, ELIMINACIÓN Y EXPANSIÓN DE MINIJUEGOS ARCADE». Estado por etapa (se actualiza con cada entrega):

| Etapa | Contenido | Estado | Pruebas |
|---|---|---|---|
| 1 | Auditoría; eliminar Arqueros por turnos, FootPool, Rebotes de ingenio, Que no caiga y Fútbol-tenis; tres secciones (Academia, Desafíos, Minijuegos arcade) con «Volver»; categorías y dificultades Fácil/Normal/Difícil/Experto | **Hecha** | `test_challenges`, `test_bowling` |
| 2 | Cámara anterior recuperada de Git (`05c100e`) + panel por minijuego (distancia, altura, encuadre, seguimiento, restablecer) | **Hecha** | `test_minigame_camera` |
| 3 | Desafíos de arco: dianas de frente, 3D, puntaje por zona por impacto real, más configuraciones | **Hecha**: 8 niveles (colgantes, resistentes, carrusel, en cadena, tras el muro, tablero de arco 10/5/1, tiro con arco, móviles); zonas configurables; dificultad cambia tamaño y velocidad | `test_dianas_rescate` |
| 4 | Demolición: escenarios, materiales, estructuras complejas | **Hecha**: 13 niveles; materiales con física (vidrio que se rompe); jenga, casita, columnata; obra, castillo y almacén | `test_demolicion` |
| 5 | Botón de caída: el jugador que cae atraviesa la base | Pendiente | — |
| 6 | Duelo del guante | Pendiente | — |
| 7 | Doce modos nuevos (Royal Flush, Dardos, Curling, Béisbol, Bowling a 10 cuadros, Fútbol de precisión, Básquet, Salto en alto, Salto de esquí, Piedras saltarinas, Aros de fuego, Field Goal) | Pendiente | — |
| 8 | Integración, CI, APK | Pendiente | — |

**Navegación.** El menú principal tiene tres tarjetas; cada sección muestra solo lo suyo y se sale con «‹ Volver»:
- ACADEMIA: práctica de tiros (Penales y Tiro libre) y los 8 niveles de enseñanza.
- DESAFÍOS: diarios, semanales, logros, medallas, récords por minijuego, experiencia e historial.
- MINIJUEGOS ARCADE: categorías → modalidades → niveles → dificultad. Las categorías son datos
  (`resources/minigames/minigames.json`, clave `categories`): DESAFÍOS DE ARCO (Dianas y los 17 desafíos de la Arena
  agrupados en postes, aros, ventanas, derribar, pique y distancia), DESTRUCCIÓN Y MECANISMOS (Demolición, Bowling,
  Rescate), DUELOS (Botón de caída) y HABILIDAD (Minigolf, Enceste).

**Dificultad en arcade.** Cada nivel se juega en Fácil, Normal, Difícil o Experto; una dificultad se abre con bronce en la
anterior (o siempre en modo práctica). Juegos de un jugador: Fácil +1 tiro, Experto −1 (mínimo 1); multiplicador del
puntaje 1 / 1,2 / 1,4 / 1,7. Duelos: la dificultad es la de la IA. Récords y medallas se guardan por dificultad.

**Cámara (valores recomendados, recuperados de Git).** General: 10,5 m detrás de la pelota, 5,4 m de alto, mira 5,5 m
por delante, 44°, seguimiento 0,45 s. Botón de caída: 6 / 6,5 / 6 m, 50°, sube 0,4 hacia el botón. El usuario ajusta
por minijuego en el botón «Cámara» (pasos: distancia 0,75 m, altura 0,5 m, encuadre 0,75 m, seguimiento 0,1 s; con
límites); «Restablecer» vuelve al recomendado de ese minijuego. Aviso: con la cámara recuperada, en Botón de caída el
jugador queda cortado abajo (igual que antes del cambio).

**Idea futura (no implementada, por pedido):** puntos de atributos que el jugador reparte al subir de nivel.

# Complemento «Arcade Football»: catálogo de 43 minijuegos (2026-11-08)

Incorporado al plan **sin interrumpir las prioridades técnicas vigentes** (medición en el teléfono, presentación,
personalización, repeticiones). No se empezó ningún minijuego por iniciativa propia: este capítulo fija estados,
dependencias y sistemas compartidos para desarrollarlos de a poco.

**Estados:** Idea · Diseñado · En desarrollo · Implementado · Probado · Pendiente de balance. «Implementado (individual)»
= existe como ejercicio o desafío de un jugador contra el marcador (Academia/Arena), sin versus ni turnos todavía.

## Sistemas compartidos (se construyen una vez y los usan muchos modos)

| Sistema | Qué es | Estado | Base que ya existe |
|---|---|---|---|
| S1 Competición | Definición común (id, objetivo, jugadores, individual/versus/cooperativo, IA, en línea, duración, rondas, puntuación, condición de victoria, dificultad, escenario, recompensas, récord, estadísticas) y un orquestador de rondas y turnos (alternancia justa, simultáneo con eventos validados) | Implementado (por turnos: `Minigame`) | `ChallengeCatalog`/`ChallengeRunner` (un jugador, intentos), `PenaltyShootout` (alternancia y muerte súbita) |
| S2 IA rival que patea | La IA usa el MISMO modelo del tiro (`ShotParams` + `GestureShotModel.solve`) con error por dificultad (fácil, normal, difícil, experto); nunca toca la pelota fuera de su golpe | Implementado (`Minigame.cpu_shot`) | `SetPieceGame._cpu_penalty` (ya lo hace en los penales) |
| S3 Blancos físicos | Paneles con puntaje, dianas colgantes con articulación y resistencia (caen por impulso real, varios impactos), botones físicos, giratorios, que cambian de lugar | Diseñado | `ChallengeTargets` (recuadros, aros, marco, objetos con física) |
| S4 Plataformas y caídas | Plataformas sobre vacío o agua, pisos que se abren, empujes por impacto (física propia, separada de los modos de tiro) | Implementado (vacío y trampilla; falta agua y empuje) | `BotonCaida` |
| S5 Control de la pelota | Conducción, recepción, dominadas, primer toque | Idea (auditar) | Conducción del partido viejo (`scripts/gameplay/`, `ai_input.gd`, `touch_foot_ik.gd`); clips de volea y «control y golpe» (48 con rol), golpeos FREESTYLE/FLICKS a revisar |
| S6 Básquet | Canasta (aro horizontal: enceste = paso físico de la pelota por el aro, de arriba hacia abajo), tableros y planos inclinados | Implementado (aro y tablero: `Enceste`; falta plano inclinado) | detección de aro de `ChallengeTargets` |
| S7 Escenarios | Variantes reutilizables (estadio, barrio, entrenamiento, arena de precisión, vacío, agua, urbano, nocturno, futurista, fútbol-básquet, arco con dianas) con distancia, tamaño de blancos, velocidad, obstáculos, tiempo, balones y superficie configurables | Idea | `Stadium11`, `PitchConfig` |
| S8 En línea | Partida rápida y privada, código, revancha, torneos, historial, clasificación por minijuego; un solo emparejamiento para todos; el servidor valida resultados y recompensas (repite el tiro desde sus parámetros) | Idea (fase posterior, con aprobación) | — |
| S9 Repeticiones | Registro por estados (ver fase 9) | Diseñado | `Ball.capture_state` |

## Catálogo

| # | Modo | Estado | Existe / falta | Usa |
|---|---|---|---|---|
| 1 | Duelo de precisión | Diseñado | Blancos y puntaje existen; falta versus por turnos | S1, S2, S3 |
| 2 | Botón de caída | Implementado · Pendiente de balance | 8 niveles contra la IA (tercera entrega); falta en línea | S1, S2, S3, S4 |
| 3 | Caída al vacío por impactos | Idea | Empuje por impacto real | S1, S2, S4 |
| 4 | Caída al agua | Idea | Escenario sobre agua | S1, S2, S4, S7 |
| 5 | Rey del travesaño | Implementado (individual) | Arena «Travesaño»; falta puntos acumulados por sesión y versus | S1, S3 |
| 6 | Desafío de los tres postes | Diseñado | Secuencia de marco (datos de la Arena: palo izq., palo der., travesaño) | S1, S3 |
| 7 | Ventanas de precisión | Implementado (individual) | Ventanas y esquinas; faltan ventanas con distinto puntaje (ver #43) | S3 |
| 8 | Tiro de larga distancia | Implementado (individual) | 25/30/35/40 m; falta la escalera progresiva en una sesión | S1 |
| 9 | Tiros con efecto | Implementado (individual) | Academia nivel 4 (postes), Arena (maniquíes) | S3 |
| 10 | Objetivo sorpresa | Implementado (individual, parcial) | Blancos que desaparecen; falta cambiar de lugar entre tiros | S3 |
| 11 | Bolos de fútbol | Implementado (individual) | Conos, botellas, bloques con física | S1, S3 |
| 12 | Derribar la torre | Implementado (individual) | Torre de la Arena y «Demolición» (6 niveles: torre, pirámide, dominó, precisión, muro, torre inestable) | S3 |
| 13 | Billar futbolístico | Eliminado (FootPool, 2026-11-11) | Varias pelotas con física | S3, S7 |
| 14 | Rebote obligatorio | Implementado (parcial) | Rebote en el piso; faltan paredes | S3, S7 |
| 15 | Circuito de aros | Diseñado | Un aro existe; falta «todos en un mismo tiro» | S3 |
| 16 | Carrera de obstáculos | Idea | Conducción | S5, S7 |
| 17 | Torre de precisión | Implementado (individual) | Secuencia de blancos | S3 |
| 18 | Objetivos móviles | Implementado (individual) | Blanco que se mueve | S3 |
| 19 | Arena de obstáculos | Implementado (individual, parcial) | Postes y maniquíes | S3, S7 |
| 20 | Dominadas | Idea (investigar) | Clips de dominadas: no hay uno completo con rol; revisar FREESTYLE/FLICKS sin modificar originales | S5 |
| 21 | Desafío de control | Idea | Recepción | S5 |
| 22 | Slalom | Idea | Conducción entre conos | S5, S3 |
| 23 | Carrera de conducción | Idea | Conducción | S5, S7 |
| 24 | Pases de precisión | Diseñado | 232 golpeos de pase medidos; blancos en el piso y compañeros | S3, S1 |
| 25 | Pared y definición | Idea | Recepción y remate | S5 |
| 26 | Primer toque | Idea | Recepción dirigida | S5 |
| 27 | Golpeo por zonas | Diseñado | Zonas en el piso y zonas prohibidas | S3 |
| 28 | Dos arqueros | Diseñado | Segundo `SpKeeper` con su propio plan y contacto | S1 |
| 29 | Duelo de atajadas | Implementado (parcial) | La tanda alterna tirador y arquero contra la IA | S1, S2 |
| 30 | Arquero contra reloj | Diseñado | Arquero del usuario + serie de tiros de la IA con tiempo | S1, S2 |
| 31 | Penales por eliminación | Implementado (parcial) | Tanda con muerte súbita contra la IA; falta eliminación entre varios | S1, S8 |
| 32 | Tiro libre profesional | Implementado (individual) | Modo tiro libre + Academia nivel 6 | S1 |
| 33 | Arquero sorpresa | Diseñado | Perfiles de arquero (se adelanta, se queda, lee el cuerpo) con la misma física | S1 |
| 34 | Muerte súbita | Implementado (parcial) | En la tanda | S1 |
| 35 | Batalla de obstáculos | Idea | — | S1, S4, S7 |
| 36 | Cooperativo | Idea | — | S1, S8 |
| 37 | Torneo de amigos | Idea | — | S1, S8 |
| 38 | Último en pie | Idea | — | S1, S4 |
| 39 | Plataformas destructibles | Idea | — | S4 |
| 40 | Duelo de rebotes | Idea | — | S1, S3 |
| 41 | Dominadas y enceste | Idea (investigar) | Necesita dominadas (#20) y canasta | S5, S6 |
| 42 | Enceste por rebote | Implementado · Pendiente de balance | «Enceste» (5 niveles, aro físico y tablero; tercera entrega); falta plano inclinado | S6, S3 |
| 43 | Dianas y blancos desmontables | Diseñado | Paneles con puntaje, dianas colgantes con articulación y resistencia, móviles y giratorias; solo colisiones reales | S3, S1 |

## Primera colección (orden propuesto por dependencias, cuando terminen las prioridades técnicas)

1. **S1 + S2** (competición por turnos contra la IA): habilita Duelo de precisión (#1), Rey del travesaño (#5), Tres postes
   (#6) y Duelo de atajadas (#29) con lo que ya existe.
2. **S3 ampliado**: Dianas y blancos desmontables (#43) y Bolos en versus (#11).
3. **S6**: Enceste por rebote (#42).
4. **S4**: Botón de caída (#2) y Caída al vacío (#3).
5. **S5** (con la investigación de animaciones): Slalom (#22), Pases de precisión (#24), Dominadas y enceste (#41).

Reglas para todos: la pelota es el centro; la IA respeta la física y las reglas del jugador (sin ventajas ocultas ni
pelota alterada); nada se da por terminado con solo una escena; cada modo con pruebas de colisiones, rebotes, blancos y
resultados; recompensas sin repetición explotable (la experiencia ya solo se gana al mejorar el récord o con la primera
medalla); sin pagos reales sin autorización expresa.

## APK de esta entrega

Corrida 13 de GitHub Actions, verde (pruebas headless y con render, APK firmada de depuración):
https://github.com/s4muy3ni-lang/Free-Kick-Swipe/actions/runs/42509748274 — artefacto `futbol5-apk` (vence el
2026-11-22). Incluye: rodadura real en la predicción, arquero del tiro libre, después de la atajada, medición en el
teléfono (Diag. > Medir rendimiento), gráficos Auto, Academia, Arena, público que acompaña la jugada, repeticiones y el
arreglo de las reacciones en bucle.

**Probado en PC:** todo lo anterior (suite headless 157 / 0 fallos; render 7/0 y 7/0 sin fugas, localmente y en CI).
**Probado en Android:** nada todavía (pendiente del informe del teléfono, `docs/ANDROID_MEDICION.md`).
