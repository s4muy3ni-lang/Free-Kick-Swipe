<!-- Texto de la instrucción de la reforma tal como la dio el usuario el 2026-11-07 (se quitó solo el aviso de las imágenes y
videos adjuntos). Las decisiones posteriores del usuario están al final y MANDAN sobre el texto original cuando lo
contradicen. Estado y siguientes pasos: ESTADO_REFORMA.md y CONTINUAR_REFORMA.md. -->

# REFORMA INTEGRAL DEL JUEGO: TIROS LIBRES Y PENALES

Godot 4.7.2 | Android | Preparación para multijugador 1 vs 1

## 1. OBJETIVO GENERAL

Transformar completamente el concepto del juego actual. Dejará de estar orientado a partidos tradicionales de fútbol 5 y
tendrá exclusivamente dos modalidades principales: **1. TIROS LIBRES** y **2. PENALES**.

No se empieza un proyecto desde cero: se modifica el juego existente, reutilizando todo lo posible (código, escenas,
modelos, jugadores, físicas, animaciones, IA, cámaras, sistemas de control y herramientas). El objetivo es conseguir dos
experiencias deportivas realistas, visualmente atractivas y con animaciones correctamente conectadas.

El resultado se ve **desde atrás del jugador**, con libertad para elegir posiciones, ejecutar disparos con el dedo,
controlar la trayectoria del balón, superar barreras y enfrentarse a arqueros que reaccionen de manera inteligente. La red
del arco debe tener una respuesta física muy realista. Se deja preparada la arquitectura para partidas online 1 contra 1 y
progresión de jugadores mediante experiencia, pero **todavía NO se conecta Supabase**.

**REGLA FUNDAMENTAL: REUTILIZAR, CONECTAR, ADAPTAR Y MEJORAR. NO BORRAR NI RECONSTRUIR EL PROYECTO.**

## 2. REGLAS DE PROTECCIÓN DEL PROYECTO

Antes de modificar: inspeccionar el repositorio real; comprobar la rama activa y el estado de Git; identificar las ramas con
recursos de animación; **no tocar `respaldo-f3`**; no eliminar recursos originales; no modificar destructivamente los JSON;
no sobrescribir bancos de animaciones; no borrar escenas o scripts sin comprobar sus dependencias; no duplicar sistemas que
ya funcionan; **no sustituir el predictor de balón, el sistema de root motion ni el árbitro de acciones si ya existen**;
mantener los cambios reversibles; documentar los sistemas que se reutilizan y los que se adaptan. Todo lo que deje de
utilizarse en los nuevos modos se conserva mientras no se compruebe que puede eliminarse sin consecuencias. No hacer merges
destructivos entre ramas.

## 3. AUDITORÍA DE TODAS LAS RAMAS Y RECURSOS

Localizar tres fuentes de animaciones: **1. banco JSON original, 2. banco Mixamo, 3. banco Mocap** (Mixamo y Mocap están en
otras ramas del proyecto, no en repositorios separados). Inspeccionar ramas; localizar los recursos; identificar archivos y
formatos; revisar esqueletos, articulaciones, escalas y orientaciones; herramientas de importación y retargeting; metadatos;
dependencias de cada banco; preparar una forma segura de probarlos sin modificar sus ramas originales; documentar qué se
reutiliza directamente y qué necesita adaptación. El banco JSON original contiene los archivos fuente (el usuario dijo
2.002; **se verificaron 2.022**) y deben conservarse intactos, con sus segmentos, espejos, metadatos y derivados. No confundir
los clips sintéticos de ejemplo (`EJ_*`) del ZIP de integración con el banco real. Si falta una rama o recurso, informar
antes de continuar. No inventar animaciones ni asumir que se importaron bien.

## 4. ETAPA PRIORITARIA: COMPARAR LOS TRES BANCOS

Obligatoria antes de decidir qué animaciones se usan. Tres configuraciones independientes seleccionables desde el juego:

- **Opción 1 — JSON original:** conservar archivos, segmentos, espejos, metadatos, trayectorias, eventos, contactos,
  clasificaciones, retargeting y sistemas de ejecución. Evaluar tiros libres, penales, barreras y atajadas.
- **Opción 2 — Mixamo:** evaluar carrera, aceleración, preparación, pasos de ajuste, golpeos, disparos, recuperación, saltos,
  caídas, movimientos de arquero, estiradas, atajadas altas y bajas; verificar esqueleto y retargeting.
- **Opción 3 — Mocap:** evaluar naturalidad, carrera, preparación corporal, apoyo del pie, contacto, seguimiento de la pierna,
  equilibrio, saltos, movimientos defensivos, desplazamientos del arquero, estiradas, atajadas, caídas y recuperación. No
  asumir que Mocap es mejor por ser captura: hay que probarlo en el juego.

**4.1 Selector:** interfaz temporal que permita elegir JSON / Mixamo / Mocap sin reconstruir el proyecto, cada fuente
claramente identificada. **No mezclar automáticamente los bancos. No crear una cuarta opción combinada.** Se comparan por
separado y el usuario decide.

**4.2 Pruebas equivalentes:** mismo jugador, esqueleto de destino, cámara, balón, posición inicial, velocidad, condiciones
físicas y tipo de acción; si hay distintos retargeters, documentar las diferencias. Probar: **tirador** (carrera, pasos de
ajuste, preparación, apoyo, golpeo, seguimiento, recuperación), **barrera** (postura, preparación, flexión, salto,
aterrizaje, recuperación), **arquero** (posición inicial, preparación, desplazamiento, atajada baja y alta, estiradas
izquierda y derecha, bloqueo, desvío, caída, recuperación) y **penales** (preparación, carrera, disparo, reacción del
arquero, estirada, contacto, aterrizaje).

**4.3 Informe comparativo:** tabla con fuente, cantidad disponible, cantidad realmente compatible, variedad de acciones,
naturalidad, calidad de carrera, de golpeo, sincronización del contacto, saltos, atajadas, transiciones, problemas de
retargeting, rendimiento Android y observaciones. **No elegir automáticamente un ganador**: el usuario prueba visualmente
las tres opciones y decide qué banco o combinación usar en la versión definitiva.

## 5. NUEVA ESTRUCTURA PRINCIPAL

Pantalla principal con dos modalidades independientes: **Modo 1 Tiros libres** (seleccionar posición del campo, colocar el
balón, modificar el ángulo, preparar el disparo, enfrentar barrera y arquero) y **Modo 2 Penales** (desde el punto penal,
cámara fija, enfrentamiento directo tirador–arquero). Comparten jugadores, animaciones, física, balón, arqueros, red,
efectos, sonido, estadísticas y progresión, pero cada uno con sus reglas, estados y secuencias.

## 6. CÁMARAS

Principal: **desde atrás del jugador que ejecuta el disparo**, según las referencias visuales del usuario.

- **Tiros libres:** detrás del tirador; muestra balón, barrera, arquero y arco; zoom (acercar y alejar); estudiar ángulos;
  composición deportiva; transiciones suaves, sin movimientos bruscos; el zoom permite ver al jugador, la trayectoria y el arco.
- **Penales:** **fija** durante la ejecución; detrás del tirador; muestra arco y arquero; no cambia de ángulo
  automáticamente; misma composición en preparación y disparo; debe funcionar también cuando el usuario es el arquero.

## 7. MODO TIROS LIBRES

**7.1 Posición del balón:** elegir libremente dónde colocarlo (mostrar posiciones, seleccionar el punto, colocar el balón
exactamente ahí, actualizar orientación del jugador, cámara y encuadre, recalcular barrera, arquero y opciones de disparo).
Sin posiciones rígidas: probar distintas distancias y ángulos.

**7.2 Disparo mediante trazo del dedo (mecánica principal):** dibujar o arrastrar un trazo. El sistema interpreta dirección,
curvatura, altura deseada, potencia, efecto y dirección final. **El balón sigue la trayectoria física resultante: no es una
animación visual independiente.** Relacionar: trazo → planificación del disparo → carrera del jugador → pasos de ajuste →
apoyo → contacto del pie → velocidad inicial → rotación → efecto Magnus → trayectoria real. El usuario debe sentir que dibuja
el recorrido. Adaptar la trayectoria al modelo físico sin teletransportar el balón ni garantizar recorridos imposibles.

**7.3 Animación del tirador:** conectar preparación, orientación corporal, carrera, aceleración, pasos de ajuste, apoyo,
golpeo, contacto físico, seguimiento de la pierna y recuperación; elegir animaciones según pie, potencia, orientación y tipo
de disparo.

## 8. BARRERA DEFENSIVA

Cada jugador con posición individual, orientación hacia el balón, postura defensiva, preparación, flexión, salto, aterrizaje
y recuperación. El salto se sincroniza con el tiro; **nada de figuras rígidas**: pequeñas variaciones naturales; la altura
del salto coherente con la trayectoria. El disparo puede superar la barrera, golpearla, pasar por un costado o ser desviado,
y la barrera **bloquea realmente el balón con colisiones**.

## 9. ARQUERO Y ATAJADAS

Reacciona a la **trayectoria física** del balón: no se lanza al azar ni conoce el resultado. Secuencia: posición inicial →
observar → prepararse → interpretar la información disponible → predecir una zona de intercepción → elegir respuesta →
ejecutar la animación adecuada → intentar alcanzar el balón → resolver el contacto físico → aterrizar y recuperarse.
Reutilizar estirada izquierda y derecha, atajada alta, baja y central, bloqueo, desvío con una y dos manos, captura, caída y
recuperación. La decisión ocurre con anticipación suficiente. **No mover el balón hacia las manos del arquero; si no llega,
falla; la física decide si hubo contacto.**

## 10. RED DEL ARCO: FÍSICA REALISTA (prioritaria)

No es una textura estática ni una animación predeterminada. Debe tener deformación por impacto, propagación de movimiento,
ondulación, recuperación progresiva, respuesta según velocidad y lugar del impacto, retención del balón e interacción
posterior. Probar centro, esquinas, parte superior, laterales e inferior. Un disparo potente deforma más que uno suave; el
balón queda retenido y no atraviesa la red. Evaluar malla deformable, nodos y restricciones, simulación simplificada o
híbrido; priorizar realismo visual y estabilidad en Android; **medir el coste real**.

## 11. MODO PENALES

Reglas y secuencias independientes; cámara fija detrás del tirador. Secuencia: tirador frente al balón → arquero se
posiciona → tirador prepara → decide dirección y potencia → carrera → contacto → el balón sigue la trayectoria física →
el arquero ejecuta su decisión → gol, atajada o fallo → se registra → siguiente turno. Misma física del balón. El arquero
elige dónde lanzarse y ejecuta la animación adecuada. El tirador elige dirección, potencia, altura, efecto y tipo de disparo,
y la animación corresponde a lo elegido (**carrera y golpeo natural, interno y externo del pie; se usan todas las
animaciones según el tipo de disparo**).

## 12. CANCHA Y ARCO DE FÚTBOL 11

Adaptar el entorno a una cancha de fútbol 11: dimensiones proporcionales, arcos de fútbol 11, área grande y chica, punto
penal, semicírculo, línea de gol, líneas laterales y de fondo, césped de buena calidad, iluminación deportiva, tribunas y
entorno si los recursos lo permiten. Tiros libres desde distintas posiciones y distancias. **No estirar la cancha actual**;
revisar los modelos y recursos existentes antes de importar o crear otros.

## 13. CONEXIÓN DE ANIMACIONES

Se hace **después** de que el usuario pruebe los tres bancos y decida; no decidir por él. Prioridad: conectar la mayor
cantidad posible de animaciones válidas para ambos modos.

- **Tirador:** idle, preparación, carrera, aceleración, desaceleración, cambios de dirección, pasos de ajuste, giro, apoyo,
  golpeo, disparo potente, colocado, con efecto, alto, bajo, recuperación, celebración.
- **Barrera:** posición defensiva, preparación, flexión, salto, variantes de salto, aterrizaje, recuperación, reacción al impacto.
- **Arquero:** idle, posición inicial, preparación, desplazamiento lateral, paso de ajuste, salto, estirada, atajada baja y
  alta, bloqueo, captura, desvío, caída, recuperación.

Reglas: retargeting y orientación correctos, root motion cuando corresponda, eventos de contacto, sincronización temporal,
transiciones naturales, mezclas adecuadas, control de interrupciones. La carrera conecta con el golpeo y este con la
recuperación; el arquero conecta posición inicial → preparación → decisión → estirada → recuperación; la barrera conecta
postura → salto → aterrizaje. No reproducir animaciones incompatibles a la vez; no forzar clips que no correspondan; no
eliminar clips que no se usen en estos modos.

## 14. IA PARA UN JUGADOR

Comparte la lógica de los futuros modos online. Si el usuario es **tirador**, la IA controla al arquero (analiza la
trayectoria, elige dónde lanzarse, calcula su tiempo de reacción, ejecuta la animación, resuelve el contacto físicamente). Si
es **arquero**, la IA ejecuta el disparo (elige trayectoria, calcula potencia y efecto, ejecuta la carrera, golpea; el usuario
decide dónde lanzarse). **La IA no conoce el resultado de antemano.** La dificultad modifica tiempo de reacción, precisión,
potencia, efecto, anticipación y alcance de atajada. No crear dos sistemas de IA si pueden compartir componentes.

## 15. MULTIJUGADOR 1 VS 1: PREPARACIÓN FUTURA (sin conectar Supabase)

Arquitectura modular que separe lógica de partida, estado de turnos, tirador, arquero, resultado, estadísticas, progresión y
comunicación futura; contratos de datos y simulaciones locales.

- **Tiros libres online:** cada jugador elige **tres posiciones** y dispone de **tres disparos**, turnos alternados. Se
  registra posición, dirección, potencia, efecto y resultado (gol, atajada, fallo). Gana quien más goles haga. Empate →
  **muerte súbita**: un disparo por jugador, turnos alternados; si uno marca y el otro falla termina; si ambos tienen el mismo
  resultado, otra ronda. Uno tira mientras el otro controla al arquero.
- **Penales online:** reglas de tanda reales (turnos alternados, cada uno tira y ataja, se registran goles y fallos, serie
  inicial, muerte súbita en empate, termina con ventaja definitiva).
- **Decisión del arquero:** elige una zona del arco **antes del disparo**, queda registrada; luego el rival ejecuta, el
  arquero se lanza hacia su zona, el balón sigue su trayectoria y se resuelve el contacto. **No se puede modificar la decisión
  después de conocer la trayectoria.** Validaciones contra acciones fuera de turno y trampas.

## 16. ESTADÍSTICAS Y PROGRESIÓN

Todos empiezan con atributos en cero; las victorias dan EXP, que permite mejorar atributos. Atributos: potencia de disparo,
precisión, efecto del balón, control de trayectoria, velocidad de carrera, aceleración, equilibrio, tiempo de reacción,
capacidad de atajada, alcance del arquero, velocidad de desplazamiento del arquero, recuperación tras una caída (revisar
redundancias). **Las mejoras deben tener efectos reales** (potencia → velocidad del disparo, efecto → trayectoria física,
precisión → control del disparo, reacción → tiempo de respuesta del arquero, alcance → zona cubierta, velocidad →
desplazamiento). Preparar perfil local, nivel, EXP total y disponible, atributos, historial, victorias, derrotas, goles,
atajadas, fallos, tiros libres y penales convertidos. Sin Supabase todavía.

## 17. ARQUITECTURA PARA SUPABASE (preparación)

Modelos y contratos intercambiables. Entidades: PlayerProfile, PlayerStats, PlayerProgression, Match, MatchPlayer, MatchRound,
ShotAttempt, ShotResult, KeeperDecision, FreeKickPosition, PenaltyAttempt, ExperienceTransaction. Identificadores únicos de
partida, turno y disparo. Separar estado autoritativo de presentación visual. La integración futura permitirá auth,
perfiles, estadísticas, experiencia, historial, salas online, resultados y matchmaking. **No conectar Supabase ni crear
dependencias productivas todavía.**

## 18. INTERFAZ

Pantalla principal: Tiros libres, Penales, Entrenamiento, Estadísticas, Progreso. En tiros libres: posición, zoom, trazo,
potencia, efecto, dirección, preparación, resultado. En penales: turno, marcador, tirador, arquero, zona elegida, resultado.
Menú temporal de pruebas para elegir los tres bancos. No llenar la pantalla de controles innecesarios: priorizar la cancha y
la ejecución.

## 19. VIDEOS E IMÁGENES DE REFERENCIA

Estudiar perspectiva, distancia de cámara, encuadre del arco, posición de la barrera, ubicación del arquero, carrera de
aproximación, movimiento de golpeo, secuencia de penales y composición. Sirven para entender cómo debe verse y sentirse el
juego. **No copiar recursos protegidos ni sustituir modelos existentes sin necesidad.** (Los archivos de esas referencias no
están en el repositorio.)

## 20. PLAN POR FASES

**No modificar todo de golpe. Al finalizar cada fase: informe, archivos modificados, pruebas y resultados, y esperar
autorización antes de la siguiente.**

0 Auditoría · 1 Bancos de animaciones (selector funcional y catálogo por procedencia) · 2 Comparación visual (escenas
equivalentes de tirador, barrera y arquero; informe comparativo; **esperar la decisión del usuario sobre el banco**) · 3
Nueva estructura (menú y modos independientes, cámaras y estados) · 4 Tiros libres · 5 Penales · 6 Integración definitiva de
animaciones (con los bancos elegidos) · 7 Red y física · 8 IA · 9 Progresión · 10 Preparación online · 11 Optimización y
pruebas (Android).

## 21. PRUEBAS OBLIGATORIAS

- **Tiros libres:** distintas posiciones y ángulos, ambos pies, potencia baja y alta, efecto, por encima de la barrera,
  impactos contra la barrera, laterales, al arquero, goles en distintas zonas.
- **Penales:** centrales, laterales, altos, bajos, atajadas, fallos del arquero y del tirador, rebotes.
- **Animaciones:** carrera y golpeo conectados, contacto correcto, seguimiento natural, salto y aterrizaje, estirada y
  contacto, recuperación, ausencia de cortes bruscos.
- **Red:** distintas zonas y velocidades, deformación, ondulación, recuperación, retención.
- **Android:** medir en el dispositivo real; una prueba de escritorio no basta.

## 22. CRITERIOS DE ACEPTACIÓN

La reforma está terminada cuando: existen dos modos independientes; se elige la posición del tiro libre; el balón se coloca
libremente; el trazo genera una trayectoria física; el tirador tiene carrera y golpeo sincronizados; la barrera salta de forma
realista; el arquero decide y puede atajar; la red se deforma físicamente; penales funciona con cámara fija; la IA puede tirar
y atajar; las animaciones están conectadas; los tres bancos fueron comparados y el usuario pudo probarlos; hay progresión
local; la arquitectura online está preparada; no se perdieron recursos originales; el rendimiento es adecuado en Android.

## 23. INSTRUCCIÓN FINAL

Trabajar sobre el proyecto real, no una propuesta teórica. Primero auditar ramas y sistemas; después habilitar los tres
bancos y preparar la comparación visual. **No elegir por el usuario entre JSON, Mixamo y Mocap**: los prueba él
personalmente en tiros libres, penales, barrera y atajadas; después se decide cuáles integrar. No conectar Supabase. No
borrar trabajo anterior. No duplicar sistemas. No modificar destructivamente los originales. No avanzar de fase sin entregar
resultados y esperar autorización.

Prioridad: **TIROS LIBRES** con cámara trasera ajustable, libertad de posición, trazo del dedo, trayectoria física, barrera
realista, arquero inteligente y red deformable; **PENALES** con cámara trasera fija, carrera y golpeo natural (interno y
externo del pie), decisión del arquero, atajadas sincronizadas y física real. Todo preparado para partidas online 1 vs 1 y
progresión con Supabase más adelante. **REUTILIZAR, CONECTAR, ADAPTAR Y MEJORAR. NUNCA EMPEZAR DE CERO.**

---

# DECISIONES POSTERIORES DEL USUARIO (mandan sobre el texto de arriba)

1. **Orientación (2026-11-07):** HORIZONTAL (apaisada), 16:9, definitiva para tiros libres y penales. Cámaras, interfaz y
   control por trazos adaptados al formato horizontal, con soporte para otras proporciones **sin deformar el campo**. Los
   videos verticales son solo referencias de encuadre y comportamiento de cámara. **No usar nunca orientación vertical.**
2. **Rama:** `reforma-tiros-penales`, creada desde `integracion-openai` (commit `9c6f82a`). No modificar `respaldo-f3` ni
   alterar la rama original.
3. **Jugador común:** el **humano del modo JSON** (`json_human.scn`) es el modelo para comparar JSON, Mixamo y Mocap. Verificar
   pose de reposo, deformaciones, retargeting y compatibilidad; si hay diferencias, **documentarlas, no corregirlas mezclando
   bancos ni modificando los originales sin autorización**.
4. **Fase 1 (autorizada y entregada):** banco de pruebas con selector JSON / Mixamo / Mocap, mismo jugador y condiciones
   idénticas, «sin clip en este banco» cuando falte una animación (**no completar huecos con clips de otro banco**), catálogo
   separado por procedencia, verificación de deformación, golpeo, contacto, arquero y transiciones, y una APK. Fase de
   comparación y evaluación: **no elegir banco ganador, no combinar bancos, no integrar todavía.** La elección la toma el
   usuario después de probar la APK.
5. **Fútbol 5 (2026-11-07, reemplaza la decisión anterior de conservarlo accesible):** el modo **sale de esta rama**. Se
   conservan animaciones, conexiones físicas y todo lo reutilizable para penales y tiros libres. Solo debe haber pruebas de
   penal y tiro libre, nada de fútbol 5. (Hecho: ver `FUTBOL5_QUITADO.md`.)
6. **Modo tiro libre (requisitos, para la Fase 4):** el objetivo es **hacer el gol de tiro libre directo**. En la cancha están
   **todos los jugadores**: la **barrera real** y además **jugadores sueltos**. Nadie remata ni cabecea salvo el tirador; los
   jugadores sueltos solo se mueven. Los **defensores** interrumpen o despejan un balón que va al arco **si llegan a
   alcanzarlo**. Los **compañeros del tirador no hacen nada con la pelota: se mueven como si fueran a recibir un centro o
   esperan un rebote.**
