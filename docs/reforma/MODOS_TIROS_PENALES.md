# Modos de penales y tiros libres: análisis, conexiones e informe

Repositorio `s4muy3ni-lang/Free-Kick-Swipe` (importado de `roldanhr98-byte/Futbol5`, rama `reforma-tiros-penales`, commit
`a24630d`, sin historial). Rama de trabajo: `claude/init-repo-reforma-tiros-c7vapt`. Fecha: 2026-11-08.

## 1. Pedido del usuario (resumen)

1. Completar el juego: menú lindo con selección entre **penales** y **tiro libre**. Penales: **1 tiro y 1 atajada**. Tiro
   libre: **elegir dónde poner la pelota** en el campo.
2. Golpeos según la dirección del tiro (un diestro que tira a su derecha usa el **interior** y la coloca), usando **todas**
   las animaciones de tiro (`kick`, `shoot`, tiros libres sirven para penales y tiros libres; los golpeos «con error» para
   cuando se erra al arco). Después del tiro: si convierte **festeja**, si erra **se enoja**; el arquero y los demás
   jugadores también reaccionan.
3. Redes muy realistas; arquero con todas sus animaciones, fluido; la pelota conectada con todo.
4. (Mensaje posterior) Arco como en las fotos (red de caja) con **selector de tipo de arco** para probar ambos, y el
   **sistema avanzado de disparo por trazo táctil** (sección 4 de este documento).

## 2. Qué se reutiliza y qué es nuevo

**Banco de animación:** se usa el **banco JSON original** (las 2.022 animaciones convertidas en `assets/animations/json_*.res`,
ya conectadas por rol). Es el único que cubre las 25 acciones de tirador, barrera y arquero sobre el humano JSON (Mixamo
cubre 20 y Mocap 8, y los dos se deforman sobre el humano JSON: informe de la Fase 1). **No se crea ni se modifica ningún
clip**: el juego elige entre los existentes usando sus metadatos medidos. El banco de pruebas de la Fase 1 sigue en el menú
para comparar los tres bancos.

Reutilizado tal cual: `Ball` (física, Magnus, impulso por `Ball.kick`, flotado), `BallPredictor` (mismo modelo de vuelo),
`Goal` y `GoalNet` (red de tela, ampliada), `KeeperPlanner` (elige el clip de atajada cuyas manos medidas llegan a la
pelota), `ClipRolesOverlay` y los roles del banco, `ActionMotion.heading_rel`, `PoseSampler`, `AnimBankCatalog.kit_material`,
`Pitch.LineBuilder`, `MeshUtil`, `Sfx`, `UiTheme`, `GraphicsSettings`, el marco de pruebas.

Nuevo (carpeta `scripts/setpiece/`): el controlador de los dos modos y sus piezas. El código del partido de fútbol 5
(`Footballer`, `BallHandler`, `Goalkeeper`) depende de `MatchScene`/`MatchContext`, que ya no existen en esta rama: por eso
los modos tienen su propio actor animado (`SpActor`) en vez de reutilizar el futbolista del partido. Ficha técnica:
[`docs/technical-index/SYSTEMS/SETPIECE.md`](../technical-index/SYSTEMS/SETPIECE.md).

## 3. Cómo se conectan las animaciones (lo que hace el «catálogo de golpeos medidos»)

`tools/setpiece/build_shot_catalog.tscn` recorre los golpeos del banco JSON (tiros, tiros potentes, tiros de balón parado,
vaselinas, pases de interior y los golpeos que el análisis del banco marcó como fallados: 560 con espejos) y, sobre el
humano JSON, mide en cada uno: pie, instante de contacto, dónde está la punta del pie en ese instante, hacia dónde se mueve
el pie respecto de la carrera, la velocidad del pie y la carrera previa. Lo guarda en `resources/setpiece/shot_clips.json`.
Es un índice: no toca las bibliotecas.

Con ese índice (`ShotCatalog`):

- El tirador espera con la **carrera habitual de su pie** (el diestro desde su izquierda). La dirección del tiro respecto de
  esa carrera decide la técnica: al **lado abierto** (diestro a su derecha) y sin mucha potencia, **interior del pie,
  colocada**; cruzado, **empeine**; potente, golpeos potentes; trazo lento y alto, **vaselina**; si la física prevé que el
  tiro se va **fuera**, un golpeo **«de error»** (golpeos desesperados y fallados del banco).
- Entre los golpeos de esa familia se elige el que tiene el ángulo del pie más parecido al pedido y la velocidad del pie
  acorde a la de la pelota; entre los mejores se rota para que se vean todos.
- El clip se **gira** para que el pie salga exactamente hacia el tiro y se **coloca** para que la punta del pie llegue a
  la pelota; si hace falta, el tirador trota hasta el punto de la carrera del clip y entra al clip en marcha.
- El impulso a la pelota (`Ball.kick`) se da **en el instante de contacto del clip** (medido: punta del pie a 0,03–0,27 m
  del centro de la pelota en el impulso, prueba con render).
- Después: festejo (`celebrate_scorer`, `celebrate`) o enojo/lamento (`angry`, `dejected`); el arquero, la barrera, los
  sueltos y los compañeros del círculo central reaccionan al revés o igual según su equipo.
- Arquero: espera (`gk_idle`), estiradas, atajadas, bloqueos (`gk_dive`, `gk_catch`, `gk_block`, `gk_scoop`) elegidas por
  `KeeperPlanner` con la trayectoria medida de las manos, y se levanta con un `gk_getup` del mismo tipo de caída.
- Barrera: posturas `wall` en el sitio con variaciones y saltos `wall` sincronizados con la llegada de la pelota.

## 4. Sistema avanzado de disparo por trazo (pedido del 2026-11-08)

### 4.1 Análisis previo

- Arquitectura: el juego anterior disparaba con botones (TIRO + joystick, `ShotAssist`, `BallHandler`); no había disparo por
  gesto. El primer borrador de los modos convertía el final del trazo en un punto del arco, la curvatura en efecto y la
  rapidez en potencia (`SwipeShot`); **se reemplazó** por el sistema de abajo (no quedan dos sistemas).
- Física de la pelota: `Ball` (`Ball.kick` = impulso con velocidad y giro). Predicción: `BallPredictor.trajectory` (mismo
  modelo: gravedad, arrastre, Magnus, botes). Selección de golpeos: `ShotCatalog` (sección 3). Táctil: eventos de pantalla
  en `SetPieceGame._unhandled_input` (Godot emula el toque con el ratón en escritorio).

### 4.2 Componentes y conexiones

| Paso | Componente | Entrada → salida |
|---|---|---|
| Captura | `ShotGesture` | eventos táctiles → muestras filtradas (posición normalizada al alto de pantalla, tiempo) |
| Propiedades | `ShotGesture.features` | muestras → largo, duración, velocidad instantánea, media y máxima, aceleración, dirección inicial y final, desplazamiento vertical y horizontal, curvatura, giro, suavidad |
| Parámetros | `GestureShotModel.build` + `GestureTuning` | propiedades → `ShotParams` (power, direction, launch_angle, lateral_spin, accuracy, gesture_length, average_speed, peak_speed, gesture_type, objetivo, velocidad de salida) |
| Física | `GestureShotModel.solve` → `ShotSolver.solve` → `BallPredictor` | parámetros → velocidad inicial, ángulo de salida, trayectoria y cruce con el arco |
| Vista previa | `TrajectoryPreview`, `SpHud.show_gesture` | trayectoria (15 veces por segundo mientras el dedo está apoyado) |
| Tiro | `SetPieceGame._take_shot` → `ShotCatalog.choose` → `SpShooter` | parámetros + error de precisión → golpeo → impulso en el contacto |
| Diagnóstico | `GestureDiagnostics` | medidas, golpeo, velocidad real de salida, coeficientes editables, comparador |

### 4.3 Influencia de cada propiedad

- **Velocidad del dedo → potencia:** mezcla de la velocidad media y la máxima (la máxima medida en ventanas de ≥ 45 ms,
  para que un salto de una sola muestra no cuente), curva de respuesta saturada (`power_curve`) y límites
  (`power_min`, `power_max`); la velocidad de salida va del mínimo al máximo del modo.
- **Largo → control:** el largo no suma potencia (a igual velocidad del dedo, la misma potencia: medido); un trazo largo
  reduce el error de dirección (`length_full`, `error_short`).
- **Desplazamiento vertical → altura:** el punto del arco bajo el final del trazo (un trazo corto, raso); si el trazo
  termina bajando, baja la llegada y agrega efecto hacia delante (`descend_drop`); si termina subiendo con fuerza, la
  sube un poco (`ascend_lift`). La altura final la decide la física.
- **Curvatura → efecto:** con zona muerta (`curve_deadzone`), ganancia (`spin_gain`) y máximo (`spin_max`); la pelota sale
  hacia el lado de la curva y se cierra hacia el objetivo (Magnus real).
- **Dirección → orientación:** hacia el punto bajo el final del trazo o la prolongación de su dirección.
- **Suavidad → precisión:** irregularidad del rumbo entre muestras y del ritmo; un trazo irregular suma un error pequeño
  (`error_rough`), sin castigar de más (medido: < 2,3° con temblor fuerte).
- Filtro: zona muerta entre muestras (`min_step`), suavizado exponencial (`smoothing`), máximo de muestras (`max_samples`,
  se diezma); sin reservar memoria mientras el dedo se mueve.

### 4.4 Tipos de disparo (sin botones)

`GestureShotModel.classify`: **globo** (lento y alto), **con efecto** (curvo), **rápido de corta distancia** (corto y rápido),
**potente y raso** (rápido y bajo), **elevado** (rápido y alto), **de precisión** (largo, suave, potencia media), **colocado**
(potencia baja o media), **normal**. Cada tipo pide su familia de golpeo (potente, colocado de interior, vaselina, con
efecto, golpeo seco) y la vista previa muestra el tipo detectado.

## 5. Arco y red

Selector «Arco» en el menú (se guarda): **Caja** (como las fotos del usuario: techo largo, fondo vertical a 2 m, caños
blancos en el piso) e **Inclinado** (techo de 0,9 m y fondo que baja hasta el piso a 2 m, con soportes). Los dos usan la
misma red de tela (`GoalNet`): se abomba con la forma de la pelota, la frena casi sin devolverla, propaga ondas y vuelve al
reposo; ahora además cuelga por su peso (caída de reposo) y admite laterales trapezoidales. Medido: tiro de 29 m/s al
ángulo, gol, la red se abomba 0,79 m (caja) / 0,56 m (inclinado) y la pelota queda dentro.

## 6. Pruebas (ejecutadas)

- `tests/test_shot_gesture.gd` (9 pruebas, sin render): potencia por velocidad y límites, el largo no es potencia, el trazo
  ascendente eleva, la curva da efecto a su lado (y la pelota se cierra al objetivo), el trazo estable es más preciso, el
  final hacia abajo baja la llegada con efecto hacia delante, los 6 tipos de disparo salen del gesto, independencia de la
  resolución, muestras acotadas y zona muerta, y **la previsión coincide con el vuelo real de la pelota** (error ≤ 0,05 m
  en los casos medidos).
- `tests/test_setpiece_modes.gd` (7 pruebas, sin render): reglas de la tanda, elección del golpeo por dirección (diestro y
  zurdo), que el pie de los golpeos elegidos llegue a la pelota (30 casos, ≤ 0,11 m en horizontal), barrera (cantidad,
  9,15 m), zona válida del tiro libre, que la barrera bloquee de verdad, los dos arcos retienen la pelota, flujo completo
  de un penal.
- `tests/test_setpiece_render.gd` (2 pruebas, con render en CI): punta del pie en la pelota en el impulso (≤ 0,27 m) y el
  arquero toca lo que alcanza cuando elige la zona (2 de 3; el rincón bajo a 2,4 m no llega, como en la realidad) y nunca
  toca cuando se tira al otro lado.
- Suite headless completa y `python3 tools/docs_index.py check`: ver `docs/technical-index/CHANGELOG.md`.

## 7. Limitaciones pendientes

- **Android real:** no hay teléfono en la sesión; tacto, coeficientes del trazo y rendimiento hay que medirlos en el
  dispositivo (panel «Diag.»: guardar los coeficientes que se sientan bien).
- Los golpeos potentes del banco salen hasta ~24° de la carrera: más cruzado usa un golpeo normal de ese ángulo.
- Los jugadores sueltos no rematan (pedido del usuario); los defensores solo despejan de cabeza si llegan.
- Progresión, estadísticas y modo en línea: no empezados (la tanda ya es un estado puro reutilizable).
- La red sigue siendo una membrana por paño (deformación a lo largo de la normal): barata y estable en Android; no simula
  la tela como hilos sueltos.
