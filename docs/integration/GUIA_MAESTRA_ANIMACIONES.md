<!-- Texto de la guía tal como la entregó el usuario el 2026-11-07, en dos mensajes (el primero se cortó en la
sección 3.3; el segundo empieza con el esquema fijo del CSV). Solo se quitó la ruta local del ZIP adjunto
(animaciones_futbol5_nombres_originales1.zip, sha256 3fa72c92ae35fe58540dd130d841534e0c73a2308a131f71a503ecd8ad8b374f).
Avance por fase: SEGUIMIENTO_ANIMACIONES.md. Cómo continuar: CONTINUAR_GUIA_ANIMACIONES.md. -->

# GUÍA MAESTRA DE INTEGRACIÓN Y CORRECCIÓN DEL SISTEMA DE ANIMACIONES
## Fútbol 5 — Godot 4.7.2

**Objetivo:** conectar y completar los sistemas que ya existen en el proyecto, corregir las limitaciones medidas en los partidos y aumentar el uso real y correcto del banco de animaciones. Esta guía es una orden de trabajo técnico para Claude.

## ACLARACIÓN CRÍTICA SOBRE LOS DOS ZIP Y EL BANCO REAL DE ANIMACIONES

**Las 38 animaciones `EJ_*` NO son el banco de animaciones del juego. Son clips sintéticos de ejemplo incluidos únicamente en el ZIP de integración de referencia.** Sirven para ilustrar o probar herramientas y patrones técnicos; no representan el contenido, la cantidad, la variedad ni la cobertura del banco real.

El banco real que Claude debe conservar, analizar e integrar es el conjunto independiente de **2.022 archivos JSON originales** entregado en el ZIP de animaciones. De esos archivos se derivan **2.024 segmentos lógicos y 3.223 variantes**, según el inventario y la auditoría del proyecto.

Reglas obligatorias para evitar cualquier confusión:

1. Usar el ZIP que contiene los **2.022 JSON originales** como fuente de verdad del banco de animaciones.
2. Usar el ZIP de integración que contiene los **38 clips `EJ_*` solamente como material de referencia y ejemplos sintéticos**.
3. No copiar los 38 ejemplos al banco real, no sustituir con ellos ningún JSON original y no contabilizarlos como parte de las 2.022 fuentes, los 2.024 segmentos ni las 3.223 variantes.
4. No concluir que el proyecto tiene solamente 38 animaciones ni que esas 38 son una muestra representativa del banco real.
5. No validar la cobertura funcional del banco real usando los 38 ejemplos. La cobertura debe medirse contra el inventario completo de 2.022 JSON y sus segmentos/variantes.
6. Antes de ejecutar cambios, identificar ambos ZIP por su contenido: contar los JSON originales del paquete de animaciones y comprobar que el paquete de integración contiene únicamente sus fixtures de ejemplo. No confiar solo en el nombre del archivo.
7. Si falta el ZIP de los 2.022 JSON en el entorno de trabajo de Claude, detener cualquier tarea que requiera inspeccionar el banco completo y solicitar ese archivo. No reemplazarlo por el ZIP de ejemplos.

**Prioridad de fuentes:** repositorio real del juego para el código; ZIP de 2.022 JSON para las animaciones originales; inventario y documentación técnica para clasificación y metadatos; ZIP de 38 `EJ_*` para ejemplos de herramientas únicamente.

---

# 0. ORDEN PRINCIPAL

Trabajá sobre el repositorio real del juego, en la rama de trabajo `integracion-openai`.

**No reconstruyas el sistema desde cero. No reemplaces los planificadores existentes. No crees un segundo predictor, un segundo árbitro de acciones ni otro motor de root motion.** El proyecto ya dispone de predicción de balón, planificadores especializados, metadatos de animación, ejecución de root motion, validación de contactos y arbitraje de acciones.

Tu trabajo consiste en:

1. verificar el estado actual de cada sistema en el código real;
2. corregir las conexiones y filtros que impiden que se usen clips válidos;
3. mejorar la precisión del contacto entre cuerpo y balón;
4. completar las situaciones que la IA nunca solicita, especialmente cabezazos y voleas;
5. ampliar y diversificar las recepciones y transiciones;
6. reparar alias y referencias de clips;
7. instrumentar las decisiones para saber por qué se eligió o rechazó cada clip;
8. validar el resultado con pruebas automatizadas, partidos completos y pruebas visuales;
9. mantener el rendimiento y la compatibilidad Android.

La auditoría técnica del 07/11/2026 es el punto de partida. Sus cifras describen una medición concreta, no una garantía de que el código no haya cambiado después. Antes de editar, comprobá el commit y repetí las pruebas relevantes. Además, verificá por separado los dos paquetes: el ZIP de 2.022 JSON es el banco real; el ZIP con 38 `EJ_*` contiene solo ejemplos sintéticos. Si Claude solo tiene disponible el segundo, no puede afirmar que inspeccionó o integró el banco completo.

## Reglas no negociables

- No borrar, renombrar, sobrescribir ni alterar los 2.022 JSON originales.
- No eliminar variantes espejo ni recursos importados.
- No tratar las etiquetas históricas como prueba definitiva de que un clip es correcto o incorrecto.
- No conectar clips solo por su nombre. Verificar función, trayectoria, parte corporal, frame de contacto, dirección y contexto.
- No cambiar masivamente tolerancias, escalas, velocidades o prioridades sin medición comparativa.
- No mover el balón mediante la animación del jugador. El balón conserva la autoridad física sobre su posición y velocidad.
- No aplicar un impulso por el mero hecho de que se haya iniciado una animación. Debe existir un contacto validado.
- No permitir que dos acciones físicas incompatibles controlen simultáneamente al mismo jugador.
- No hacer que las pruebas pasen relajando sus aserciones o desactivando validaciones.
- No introducir dependencias nuevas si el sistema actual puede resolverlo.
- Mantener los modos alternativos de animación y las herramientas existentes salvo que una prueba demuestre que deben cambiarse.
- No tocar la rama `respaldo-f3`.
- No incluir referencias a proyectos externos, investigaciones externas ni nombres de productos ajenos en el código, documentación o mensajes de implementación. La guía describe únicamente el sistema propio de Fútbol 5.
- No hacer merges a `main` durante las fases 0–8. La línea base debe permanecer inmutable mientras se instrumenta y corrige.
- No cerrar una fase si una métrica de la línea base empeora más allá del umbral de aborto definido en la sección 15.0.

## Criterios globales de aborto

Cada fase debe declarar explícitamente qué empeoraría lo suficiente como para revertir y reabrir diagnóstico. Como regla general:

- **Precisión de contacto (Fase 3):** si el p90 de distancia de contacto sube más del 10 %, o si el porcentaje de acciones abortadas sube más del 5 %, revertir la fase y reabrir diagnóstico de `BallPredictor`/sincronización antes de continuar.
- **Juego aéreo (Fase 4):** si la tasa de goles en propia o despejes hacia arco propio aumenta, o si el porcentaje de contactos fallidos en acciones aéreas supera al de acciones rasas, revertir la clasificación y reabrirla.
- **Recepciones (Fase 5):** si la tasa de pérdida de posesión tras recepción animada sube más del 5 % relativo, revertir.
- **Cualquier fase:** si un gate test (sección 15.0) deja de pasar, detener y resolver antes de continuar.

Estos umbrales son orientativos y deben ajustarse con los datos de la línea base de Fase 0, pero deben existir antes de empezar a editar.

---

# 1. ESTADO TÉCNICO QUE DEBE TOMARSE COMO BASE

La auditoría informa el siguiente estado:

| Elemento | Estado medido |
|---|---:|
| Fuentes JSON originales | 2.022 |
| Segmentos lógicos | 2.024 |
| Variantes importadas | 3.223 |
| Segmentos con conexión/disparador | 1.948 |
| Segmentos sin conexión verificada | 76 |
| Segmentos conectados pero que sus filtros dejan fuera | 322 |
| Segmentos observados en partidos | 702 (34,7 %) |
| Variantes observadas en partidos | 888 |
| Roles observados en partidos | 90 de 111 |
| Roles sin aparición en los seis partidos medidos | 21 |
| Partidos medidos | 6; cinco de 10 min y uno renderizado de 3 min |
| Pruebas headless informadas en el estado del proyecto | 310, 0 fallidas, 28 omitidas, 2.991 comprobaciones |
| Memoria estática de bibliotecas en escritorio | aproximadamente 207 MB |

La auditoría también informa:

- Las 3.223 variantes se registran, importan, invocan en un `AnimationPlayer` sobre el esqueleto y producen poses finitas al inicio, mitad y final.
- Esto demuestra integridad técnica de importación y reproducción; no demuestra que cada clip sea visualmente correcto o útil durante un partido.
- La selección no está concentrada en un único selector universal. Hay varios planificadores especializados.
- `PackLibrary`/`AnimDB` centralizan el catálogo y los índices; `ActionArbiter` y `FootballerVisual` centralizan la autoridad de ejecución y presentación.
- La física del balón y su predictor ya están conectados a planificadores de golpeo, recepción, movimiento de balón y atajadas.
- El sistema de root motion ya dispone de trayectorias y orientación en metadatos.
- Las acciones se ejecutan mediante un único espacio de acción por jugador.

**No interpretar los 322 filtros como 322 clips defectuosos.** La auditoría separa causas diferentes: trayectoria/duración, evento de contacto no limpio, ausencia de toques medidos o altura de pie incompatible. Cada segmento necesita diagnóstico individual.

## 1.1 Sistemas existentes que deben reutilizarse

Confirmar en el repositorio real y mantener las responsabilidades:

| Sistema | Responsabilidad actual descrita por la auditoría |
|---|---|
| `PackLibrary` | Carga las bibliotecas de campo, escenas y arquero; combina escenas y construye índices por rol y alias |
| `AnimDB` | Catálogo de fuentes, acciones, sistemas y conexiones |
| `JsonCatalog` | Candidatos de golpeo y situaciones |
| `BallPredictor` | Predicción temporal de la trayectoria del balón |
| `BallHandler` | Planificación y ejecución de golpeos, giros y acciones con balón |
| `JsonReceive` | Selección y ejecución de recepciones |
| `JsonBallMove` | Toques sucesivos de conducción mediante eventos del clip |
| `KeeperPlanner` | Selección de atajadas usando trayectoria del balón y trayectorias de manos |
| `ActionArbiter` | Prioridades, aceptación, rechazo, interrupción y cancelación de acciones |
| `PlayerActions` | Transiciones de locomoción y selección de acciones corporales |
| `ActionMotion` | Aplicación de trayectoria de raíz y orientación al movimiento del jugador |
| `FootballerVisual` | Reproducción y presentación de animaciones |
| `TouchFootIK` | Corrección visual del pie durante el contacto con el balón |
| `AIInput` | Decisiones y solicitudes de acciones de la IA |
| `MatchPresentation` | Acciones contextuales y de presentación del partido |

La auditoría menciona además `AnimationTree`, `AnimationPlayer`, `JsonRig`, `JsonRetarget`, `ClipRolesOverlay`, `AnimationCatalog` y los recursos `json_clips.res`, `json_scenes.res`, `json_keeper.res`. Verificá las rutas exactas antes de editar: pueden haber cambiado.

**`BallPredictor` es dependencia crítica de Fases 3, 4 y 5.** Si durante Fase 3 se descubre que la fuente del error de contacto es la predicción y no la tolerancia, priorizarlo como sub-fase 3a antes de abrir Fases 4 y 5. No intentar compensar un predictor defectuoso bajando tolerancias ni moviendo al jugador por código.

## 1.2 Flujo de decisión y ejecución que debe preservarse

El flujo conceptual es:

1. La IA o el control humano identifica una intención: correr, girar, recibir, conducir, pasar, tirar, disputar, barrerse o atajar.
2. El sistema específico consulta el estado real del jugador, balón, rivales y contexto.
3. El planificador especializado solicita candidatos al catálogo por rol/contexto.
4. El candidato se evalúa por compatibilidad física, dirección, velocidad, parte corporal, frame de contacto, trayectoria y restricciones del jugador.
5. El `ActionArbiter` decide si la acción puede ocupar el único espacio de acción.
6. El ejecutor reproduce el clip y aplica su root motion/heading con correcciones acotadas.
7. En el instante previsto, se comprueba el contacto físico real.
8. Solo si el contacto es válido se aplica el efecto físico al balón o al objeto correspondiente.
9. La acción termina, se cancela o se interrumpe de acuerdo con su token y prioridad.
10. El jugador vuelve a la locomoción adecuada, usando velocidad y orientación de salida.

No introducir un selector global que sustituya a los diez selectores especializados. Si se necesita una capa común, debe ser una interfaz de diagnóstico y criterios compartidos, sin quitar a cada sistema su responsabilidad.

---

# 2. FASE CERO — AUDITORÍA DEL REPOSITORIO REAL ANTES DE MODIFICAR

Antes de programar:

1. Confirmar rama, commit y estado limpio del repositorio.
2. Confirmar que la rama activa es `integracion-openai`.
3. Confirmar que `respaldo-f3` no recibe commits, merges ni modificaciones.
4. Crear tag inmutable `pre-audit-phase-0` sobre el commit base de `integracion-openai` y snapshot (`.zip` o `git archive`) de los recursos `.res` de animaciones. Este snapshot es la referencia para comparar hashes y para poder volver si algo se desvía.
5. Declarar la línea base de pruebas: qué comandos, qué semillas y qué CSV/JSON de salida se usan como referencia.
6. Leer el documento de estado más reciente y el informe de auditoría completo.
7. Buscar los nombres de los sistemas de la sección 1.1 y localizar sus implementaciones reales.
8. Crear un mapa de llamadas: quién solicita, quién planifica, quién arbitra, quién ejecuta y quién valida cada familia de acción.
9. Identificar qué partes del informe siguen vigentes y cuáles cambiaron desde el commit auditado.
10. Ejecutar la suite base antes de tocar código y guardar logs completos.
11. Registrar métricas base en CSV/JSON para comparar después.
12. Confirmar que los archivos originales y recursos importados tienen hashes idénticos antes y después del trabajo.
13. **Inventariar los assets necesarios para los 47 clips contextuales de Fase 8** (`nis_misc`, `nis_sit`, `nis_walk`): banco, túnel, sala de prensa, camilla, árbitro, público, etc. Si faltan assets, marcar esos clips como *pendientes por assets* y no bloquear el resto de Fase 8.
14. **Declarar gate tests vs monitoring tests** (ver sección 15.0): qué pruebas deben pasar siempre para mergear y qué pruebas son informativas.
15. Confirmar que `test_ai_teams_play_a_real_match_without_getting_stuck` (jugador fuera de la cancha > 1 m) queda registrado como ticket explícito de Fase 9 (determinismo) y no como nota suelta de la auditoría.

No deduzcas que el código real es idéntico al ZIP de integración. **Los 38 clips `EJ_*` de ese paquete son fixtures sintéticos de ejemplo, no animaciones del banco real.** No los importes como contenido de producción, no los sumes al inventario y no los uses para medir cobertura. El banco real está en el ZIP independiente de 2.022 JSON originales. Las herramientas, clases de referencia y documentación del paquete de integración pueden servir para comprender patrones técnicos; no deben copiarse encima de los sistemas reales si estos ya tienen equivalentes.

**Entrega de esta fase:** `AUDITORIA_PRE_IMPLEMENTACION.md` con archivos reales, funciones, llamadas, estado, pruebas, hashes, inventario de assets y diferencias respecto de la auditoría previa. Incluye también la lista de gate tests y monitoring tests, y el tag `pre-audit-phase-0`.

---

# 3. FASE UNO — UNIFICAR CRITERIOS SIN REEMPLAZAR LOS PLANIFICADORES

El proyecto tiene varios planificadores especializados. El problema no es que falte un planificador genérico, sino que los filtros, umbrales y decisiones no siempre quedan trazados de forma comparable.

## 3.1 Contrato común de candidato

Definir o adaptar una estructura común de diagnóstico para cada candidato, sin obligar a reescribir el formato interno de cada planificador.

Debe permitir registrar:

- identificador de fuente y segmento;
- nombre original exacto;
- variante utilizada y si es espejo;
- rol y sistema solicitante;
- contexto de la acción;
- frame de inicio;
- frame/evento de contacto;
- parte corporal de contacto;
- pie utilizado;
- velocidad de entrada y velocidad nominal del clip;
- orientación inicial y orientación objetivo;
- posición predicha del balón en el instante de contacto;
- posición mundial predicha del punto de contacto corporal;
- error espacial y angular;
- corrección de root motion requerida;
- tolerancia aplicada y motivo;
- coste total y desglose de penalizaciones;
- resultado: aceptado, rechazado, interrumpido, cancelado, expirado o contacto fallido;
- razón concreta del rechazo.

Los campos deben ser opcionales cuando el tipo de acción no los use. No fabricar `ball_local` si no existe en el recurso o no se puede recuperar de manera fiable.

## 3.2 Función de coste compartida

Si los planificadores ya tienen funciones de coste, conservarlas y exponer sus componentes para diagnóstico. No imponer una fórmula única que perjudique acciones distintas.

Como referencia conceptual, los costes pueden considerar:

- error de contacto espacial;
- error de orientación;
- diferencia de velocidad;
- distancia que debe corregir la raíz;
- incompatibilidad de pie;
- altura y dirección del balón;
- duración hasta el contacto;
- estabilidad del apoyo;
- penalización por giro excesivo;
- riesgo de colisión o interferencia;
- repetición reciente del mismo clip;
- interrupción o imposibilidad de completar la acción.

Las penalizaciones deben ponderarse por familia. Un cabezazo no se evalúa como un pase raso; una atajada no se evalúa como un toque de conducción.

## 3.3 Trazabilidad y esquema de exportación

Añadir un modo de depuración activable por configuración. No escribir un log enorme por frame en producción.

Por acción, registrar una muestra compacta:

- candidatos examinados;
- candidatos descartados por cada motivo;
- candidato elegido;
- puntuación;
- frame y parte de contacto;
- error final;
- si se validó el contacto;
- efecto físico aplicado.

**Esquema fijo del CSV de trazabilidad** (obligatorio para que las comparaciones entre fases sean automáticas):

<!-- Continuación (segundo mensaje) -->

**Esquema fijo del CSV de trazabilidad** (obligatorio para que las comparaciones entre fases sean automáticas):
 tick, player_id, action_family, system_requester, segment_id, source_id, variant, is_mirror, role_effective, context, frame_start, frame_contact, body_part, foot, v_in, v_clip, orient_start, orient_target, ball_pred_x, ball_pred_y, ball_pred_z, contact_point_x, contact_point_y, contact_point_z, spatial_error_m, angular_error_deg, root_correction_m, tolerance_applied, tolerance_reason, cost_total, cost_breakdown_json, result, rejection_reason, contact_validated, physics_applied

Permitir exportar este esquema a CSV/JSON en pruebas. Mantener el modo apagado en builds normales.

## 3.4 Overlay de debug en partido (entregable obligatorio de Fase 1)

Además del CSV, producir un overlay visual en partido (activable por tecla o flag) que muestre en pantalla, para el jugador controlado y opcionalmente para un jugador IA seleccionable:

- acción planificada actual y segment_id;
- frame de inicio y frame de contacto;
- punto corporal previsto en mundo (marcador);
- balón predicho en el frame de contacto (marcador distinto);
- línea entre ambos con la distancia en metros;
- lista de los N candidatos examinados con motivo de rechazo;
- candidato elegido y coste desglosado;
- estado de `ActionArbiter` (nivel actual, aceptado/rechazado).

Sin este overlay, Fases 3 (precisión) y 4 (aéreo) se vuelven arqueología de logs. Se puede implementar como `CanvasLayer` de debug sin coste en builds de producción.

**Aceptación:** ante un clip que no se reproduce, debe poder responderse con datos si no fue encontrado, no tenía rol, falló un filtro, perdió por coste, fue rechazado por el árbitro, fue cancelado o no alcanzó contacto. Y debe poder verificarse visualmente en partido con el overlay.

---

# 4. FASE DOS — CORREGIR LOS 322 SEGMENTOS CONECTADOS PERO NO SELECCIONABLES

La auditoría indica que 322 segmentos con conexión previa quedan excluidos por sus filtros. No habilitarlos todos indiscriminadamente.

## 4.1 Crear una tabla de diagnóstico por segmento

Cada uno de los 322 debe tener:

- ID de segmento;
- fuente JSON;
- nombre original;
- rol efectivo;
- sistema consumidor;
- filtro que lo rechaza;
- dato que provoca el rechazo;
- valor medido;
- umbral vigente;
- causa probable;
- acción recomendada;
- estado de revisión;
- prueba que demuestra la corrección.

Agrupar inicialmente por los motivos medidos:

| Motivo informado | Cantidad | Tratamiento |
|---|---:|---|
| Trayectoria de raíz/duración | 176 | Revisar desplazamiento, duración, continuidad, velocidad y compatibilidad con el tipo de acción |
| Evento de contacto no limpio | 121 | Revisar frame, parte corporal, trayectoria y calidad del evento; no inventar contacto |
| Sin toques medidos | 13 | Determinar si es un clip de golpeo, transición o animación sin contacto de balón |
| Pie demasiado alto | 12 | Comprobar altura del pie respecto al balón y la intención del clip |

## 4.2 Criterios de decisión

Clasificar cada segmento como:

- **Válido:** el evento y la trayectoria son adecuados; ajustar el filtro si estaba mal calibrado.
- **Válido con contexto:** solo puede usarse para cierta velocidad, dirección, superficie o estado.
- **Válido con evento alternativo:** requiere otro evento medido y verificable; no inventar el frame.
- **Solo presentación:** no debe participar en la física de partido.
- **Pendiente de inspección visual especializada:** falta evidencia visual para clasificar. El segmento queda fuera del catálogo activo, se documenta el motivo y **no bloquea el cierre de la fase**.
- **Incompatible:** conservarlo en el catálogo, pero no ofrecerlo al planificador de esa acción.

Un segmento incompatible con el pase raso puede ser perfectamente válido para una transición, una escena o una acción aérea. No reducir todo a conectado/no conectado.

## 4.3 Filtros de trayectoria

Para los 176 casos de raíz/duración:

1. Comparar trayectoria horizontal y heading durante todo el clip.
2. Verificar desplazamiento neto, picos de velocidad y aceleración.
3. Revisar si el clip es de locomoción cíclica, transición o acción puntual.
4. No aplicar el filtro de locomoción a un clip de caída, golpeo o giro.
5. Revisar discontinuidades, root motion invertido, orientación incorrecta y duración insuficiente.
6. Si un clip es válido con una velocidad de reproducción limitada, expresarlo como rango de compatibilidad.
7. No compensar una raíz defectuosa moviendo al jugador grandes distancias por código.

## 4.4 Eventos no limpios

Para los 121 casos:

1. Inspeccionar el evento original y el frame de la pose.
2. Comprobar si el evento está asociado al pie, cabeza, mano, pecho o muslo correctos.
3. Comprobar que el miembro se aproxima al balón, no que simplemente pasa cerca.
4. Comprobar continuidad del miembro antes y después del evento.
5. No asumir que la posición del pie equivale a la posición del centro del balón.
6. Si no se puede demostrar un contacto real, mantener el evento pendiente.
7. No cambiar automáticamente el evento al frame de mínima distancia sin validar la semántica de la acción.

## 4.5 Sin toques medidos y pie alto

Para los 13 sin toques medidos, determinar si el rol realmente requiere contacto con el balón. Para los 12 con pie demasiado alto, evaluar si se trata de una recepción aérea, una volea, una patada alta o un evento mal clasificado.

## 4.6 Salida para casos inclasificables

Si tras el diagnóstico individual un segmento no se puede clasificar con la evidencia disponible (evento ambiguo, falta inspección visual especializada, datos contradictorios), la fase **no se bloquea**: el segmento se marca como `pendiente_revision_visual_especializada`, se documenta el motivo, queda fuera del catálogo activo y se lista en la entrega de la fase. La fase cierra con ese subconjunto explícitamente diferido.

**Aceptación:** todos los 322 tienen una causa identificable y una decisión documentada, sea `válido`, `válido con contexto`, `válido con evento alternativo`, `solo presentación`, `pendiente de inspección visual especializada` o `incompatible`. Los que se habiliten deben tener una prueba del consumidor real y no solo una prueba de catálogo.

---

# 5. FASE TRES — PRECISIÓN DEL CONTACTO EN PARTIDOS

La auditoría mide que el umbral de alcance de golpeo en modo 4 es 0,65 m. En partidos:

- sin render: mediana 0,16 m, p90 0,35 m, máximo 0,64 m; 21 % de contactos superan 0,30 m;
- con render: mediana 0,24 m, p90 0,44 m, máximo 0,59 m; 29 % superan 0,30 m.

En escenarios controlados se observaron 50/50 golpes con el dedo del pie visualmente próximo al balón, alrededor de 0,125 m del centro visual. Esto no garantiza que los partidos completos tengan la misma precisión.

## 5.1 Objetivo

Reducir la distancia real entre el punto corporal de contacto y el balón sin provocar que el jugador falle acciones legítimas ni romper el ritmo del juego.

No cambiar 0,65 m por un número menor de forma global y sin pruebas. Ese valor es un límite de aceptación actual, no necesariamente el valor que debe aplicarse a todas las acciones.

**`BallPredictor` es dependencia crítica de esta fase.** Si el error de contacto tiene origen en la predicción y no en la tolerancia, resolver el predictor como sub-fase 3a antes de tocar tolerancias.

## 5.2 Separar tres distancias

Medir de forma independiente:

1. **Error de planificación:** diferencia entre la posición prevista del punto corporal y la del balón en el instante objetivo.
2. **Error de ejecución:** diferencia real en el frame de contacto, después del movimiento de raíz y de la fase de animación.
3. **Error visual:** diferencia entre el hueso/punto corporal que se muestra en el esqueleto renderizado y el balón visible en pantalla.

No mezclar centro de balón, superficie de balón, radio visual, pie/toe y punto de impacto. Definir las métricas en metros y dejar claro qué puntos se comparan.

## 5.3 Corrección progresiva

Revisar en este orden:

1. sincronización del reloj del planificador con el tick de física;
2. latencia entre solicitud y comienzo del clip;
3. selección del frame de inicio;
4. orientación del jugador y espacio local/mundial;
5. trayectoria real del root motion;
6. corrección de raíz permitida por tick;
7. fase exacta de contacto;
8. interpolación del esqueleto y momento de lectura del hueso;
9. `TouchFootIK` y cualquier ajuste visual;
10. validación final y momento de aplicación del impulso.

El ejecutor debe perseguir el punto futuro del balón mediante pequeñas correcciones limitadas. No debe teletransportar al jugador en el frame de contacto.

## 5.4 Validación física

- El golpeo debe validarse con el punto corporal que corresponde al evento.
- El balón solo recibe el impulso después de validar el contacto.
- Si el contacto falla, no aplicar el impulso; cancelar o replanificar según el estado de la acción.
- La tolerancia debe depender del tipo de contacto, la parte corporal y la fase del juego.
- Los cabezazos y voleas deben tener pruebas de distancia y altura; no basta con comprobar que la animación se ejecutó.
- No usar una tolerancia más amplia como solución a una desincronización.

## 5.5 Métricas objetivo iniciales

Tomar como metas de ingeniería, no como valores físicos universales:

- reducir progresivamente p90 y porcentaje de contactos por encima de 0,30 m;
- evitar contactos superiores al límite de validación de la acción;
- conservar un porcentaje alto de acciones completadas;
- no aumentar los fallos de pase, tiro y recepción;
- medir por separado render y headless.

La aceptación final debe comparar con la línea base y mostrar distribución p50/p90/p95/máximo, porcentaje ≤0,20 m, ≤0,30 m y >0,30 m, contactos fallidos y acciones abortadas.

## 5.6 Criterios de aborto de la fase

Revertir la fase y reabrir diagnóstico si respecto de la línea base:

- el p90 de distancia de contacto sube más del 10 %;
- el porcentaje de acciones abortadas sube más del 5 %;
- la tasa de goles o asistencias cae de forma estadísticamente significativa en los partidos de referencia;
- algún gate test de la sección 15.0 deja de pasar.

---

# 6. FASE CUATRO — ACTIVAR CABEZAZOS Y VOLEAS EN LA IA

La auditoría detectó la causa principal: `AIInput` solicita golpeo solo cuando `ball.y < 0.6`. Por eso la IA prácticamente nunca solicita acciones aéreas, aunque el catálogo contiene clips de cabezazo y volea. En los partidos medidos hubo cero cabezazos y cero voleas.

## 6.1 No confundir disponibilidad con selección

Hay clips aéreos importados, pero la IA no los utiliza si nunca solicita esa familia de acciones. La solución no es simplemente añadir más clips al catálogo.

## 6.2 Clasificación previa obligatoria: ofensiva vs defensiva vs neutra

Abrir la altura no es solo cambiar una línea. Sin clasificar la intención, la IA va a cabecear hacia arco propio o volear balones que debía despejar. La evaluación aérea debe devolver **una de estas cinco decisiones**, con motivo explícito:

- **Ofensiva — cabezazo/volea dirigido:** el balón cruza una zona alcanzable, hay ángulo hacia arco rival, el jugador llega con tiempo y espacio.
- **Defensiva — despeje:** balón en zona de riesgo, rival más cercano que el compañero, prioridad de alejar el balón (lateral o hacia arriba) aunque sea fuera del campo propio, no hacia arco propio.
- **Neutra — control aéreo:** objetivo es amortiguar o quedarse con la posesión (pecho, muslo, empeine amortiguado), sin despejar ni rematar.
- **No intervenir:** otro compañero mejor posicionado, o probabilidad baja de contacto válido, o riesgo de dejar al equipo descompensado.
- **Esperar el bote:** el balón es alcanzable pero la mejor jugada es dejar que caiga.

Sin esta clasificación explícita, Fase 4 debe considerarse no implementada, aunque la IA pida cabezazos.

## 6.3 Evaluación de balón aéreo

Crear o adaptar una evaluación previa al golpeo que consulte `BallPredictor`:

- altura futura del balón;
- velocidad vertical;
- velocidad horizontal;
- tiempo hasta el punto de intercepción;
- distancia horizontal del jugador;
- orientación del jugador;
- posibilidad real de llegar con carrera o salto;
- parte corporal viable;
- rivales cercanos;
- situación de juego y espacio disponible;
- relación espacial del punto de intercepción con arco propio y rival.

No decidir únicamente por la altura actual. Una pelota puede estar baja pero subiendo, o alta pero descendiendo y fuera del alcance.

## 6.4 Elegir el tipo de acción

- **Cabeza:** el balón previsto cruza una zona alcanzable por la cabeza y la acción es viable dentro del tiempo disponible.
- **Volea:** el balón se encuentra en una altura alcanzable por el pie y el clip tiene evento compatible.
- **Control aéreo:** el objetivo es amortiguar o orientar la posesión, no despejar ni tirar.
- **Despeje:** prioridad defensiva cuando la pelota está en zona peligrosa y el jugador llega antes que el rival.
- **No intervenir:** si la probabilidad de contacto válido es baja o existe un compañero mejor posicionado.

Los umbrales de altura deben extraerse de la geometría real de los clips y del esqueleto, no fijarse solo por intuición.

## 6.5 Planificación y ejecución

Reutilizar los planificadores actuales de golpeo/recepción y la misma predicción de balón. Añadir perfiles de candidatos aéreos, sin crear otro motor de contacto.

Para cada candidato comprobar:

- frame de contacto;
- parte corporal;
- altura del punto de contacto;
- posición predicha del balón;
- orientación de cabeza/cuerpo o pie;
- root motion y salto si existe;
- distancia máxima que puede corregir el jugador;
- riesgo de colisión con otro jugador;
- contacto real en el frame de ejecución;
- dirección del vector de salida respecto al arco propio (rechazar despejes hacia arco propio salvo situación desesperada).

Si no hay un clip que cumpla los requisitos, usar una salida física de emergencia solo si ya existe una mecánica válida para ello; no fingir un cabezazo reproduciendo cualquier animación.

## 6.6 Pruebas obligatorias

- balón alto que cae frente al jugador;
- balón alto que se aleja;
- balón que cruza lateralmente;
- balón que sube desde un centro;
- balón a altura de volea;
- balón demasiado alto;
- jugador de espaldas;
- dos jugadores que compiten por el mismo balón;
- defensa que despeja bajo presión;
- cabezazo/volea con contacto válido y con contacto fallido;
- **cabezazo en zona defensiva que no termine dirigiéndose a arco propio** (test específico);
- **balón alto con compañero mejor posicionado que el jugador decida no intervenir** (test específico).

**Aceptación:** en partidos de prueba preparados para producir centros y balones altos, la IA solicita y completa cabezazos/voleas de forma medible, clasifica la intención (ofensiva/defensiva/neutra/no intervenir/esperar) y no produce goles en propia por despeje mal orientado. No basta con que el rol tenga clips registrados.

---

# 7. FASE CINCO — MEJORAR RECEPCIONES Y PRIMER TOQUE

La auditoría informa 475 primeros contactos en cuatro partidos, 124 intentos de clip de recepción y 82 completados: aproximadamente 17 % de los primeros contactos terminaron en una recepción animada. El resto recurrió al control físico.

El control físico debe seguir existiendo como fallback; el objetivo es que la técnica animada se use cuando sea compatible.

**Esta fase también depende de `BallPredictor`.** Si el predictor tiene error sistemático en trayectorias descendentes o con efecto, resolverlo primero.

## 7.1 Revisar el conjunto de perfiles

La auditoría informa 25 perfiles pendientes y cuatro perfiles `not_reception`, además de siete clips distintos de recepción y un solo `receive_turn` observado.

Para cada perfil:

- revisar el gesto real;
- parte corporal;
- frame de contacto;
- velocidad y dirección de llegada;
- orientación inicial;
- orientación de salida;
- root motion;
- estado de apoyo;
- si el clip realmente recibe el balón o ejecuta otra acción;
- condiciones en que debe quedar excluido.

No convertir automáticamente todos los perfiles pendientes en recepciones.

## 7.2 Clasificar recepciones

Separar al menos:

- pie derecho e izquierdo;
- interior/exterior si la pose lo permite;
- recepción frontal;
- recepción lateral;
- recepción orientada;
- recepción frenando;
- recepción en carrera;
- recepción con pecho;
- recepción con muslo;
- recepción de cabeza;
- control aéreo;
- recepción con giro;
- control de emergencia.

El catálogo puede usar roles ya existentes y metadatos específicos. No crear roles duplicados si basta con tags/contexto.

## 7.3 Planificación de la recepción

La selección debe usar el balón futuro, no su posición actual:

1. predecir el punto y tiempo de llegada;
2. determinar la superficie corporal adecuada;
3. calcular orientación de entrada y salida;
4. evaluar clip y frame de contacto;
5. comprobar si el jugador puede alcanzar el punto con corrección limitada;
6. reservar la acción con el árbitro;
7. ejecutar root motion y fase;
8. validar el contacto;
9. aplicar el control físico y la velocidad de salida;
10. volver a locomoción o encadenar el siguiente toque.

El primer toque orientado debe cambiar de verdad la trayectoria del balón, no limitarse a reproducir una pose.

## 7.4 Evitar abortos innecesarios

La auditoría registró 124 recepciones iniciadas y 42 abortadas. Instrumentar cada aborto con causa:

- balón cambió de trayectoria;
- rival llegó antes;
- plan quedó obsoleto;
- acción de prioridad superior;
- contacto fuera de tolerancia;
- jugador no alcanzó el punto;
- se perdió la posesión;
- el clip ya no era compatible.

No impedir que el árbitro cancele una recepción cuando la situación cambia. Mejorar la predicción y la decisión para reducir cancelaciones evitables.

## 7.5 Criterios de aborto de la fase

Revertir si respecto de la línea base:

- la tasa de pérdida de posesión tras recepción animada sube más del 5 % relativo;
- la tasa de recepciones abortadas por error de planificación (no por interrupción válida) sube;
- algún gate test de la sección 15.0 deja de pasar.

**Aceptación:** aumentar la proporción de recepciones animadas completadas sin elevar pérdidas de balón, contactos falsos ni acciones abortadas por errores de planificación.

---

# 8. FASE SEIS — VARIEDAD DE LOCOMOCIÓN Y TRANSICIONES

La auditoría señala que `run_change` utiliza un único clip y se reprodujo 1.463 veces en aproximadamente 40 minutos. La transición `start` tiene seis clips y se reprodujo 1.762 veces.

También se observaron 88 usos de `turn_start` con 29 clips; `turn_run` no se utiliza por diseño de IA.

## 8.1 No confundir variedad con aleatoriedad

La selección debe ser contextual y determinista bajo una semilla conocida. No elegir clips al azar sin considerar velocidad, dirección y estado.

## 8.2 Diversificar `run_change`

1. Inventariar todos los clips de transición que puedan representar cambio de velocidad.
2. Verificar trayectoria de raíz, duración, heading, velocidad de entrada/salida y continuidad.
3. Separar aceleración, desaceleración, cambio de dirección y cambio de zancada.
4. Ampliar el conjunto elegible solo con clips validados.
5. Usar un coste que favorezca la continuidad de velocidad y orientación.
6. Penalizar repeticiones recientes del mismo clip, sin prohibirlo cuando sea el único compatible.
7. Evitar saltos de fase o cortes visibles.
8. Comprobar las transiciones tanto con balón como sin balón.

## 8.3 Completar los giros

Revisar `turn_start`, `turn_run`, `turn_stop`, `ball_turn`, `ball_skill` y sus perfiles.

La auditoría indica que `turn_run` está excluido de la IA por diseño. No activarlo globalmente: primero comprobar si hay clips, consumidores y condiciones correctas.

Distinguir:
- giro en el lugar;
- giro durante carrera;
- giro con balón;
- frenada y giro;
- cambio de sentido;
- giro de arquero;
- giro de preparación para patear.

## 8.4 Control de repetición por jugador y por ventana visible

Mantener historial corto **por jugador y familia**:

- últimos clips usados;
- tiempo desde la última reproducción;
- frecuencia por minuto;
- alternativas válidas disponibles.

Además, mantener un historial **global de pantalla** (ventana deslizante de ~5 s) con los últimos clips de transición reproducidos. Si un clip ya sonó N veces en esa ventana en cualquier jugador visible, aplicar una penalización adicional en el coste. Objetivo: evitar que `run_change` suene 0,6 veces por segundo aunque ningún jugador individual lo repita — el humano mirando el partido lo percibe como repetición, aunque el historial por jugador no lo detecte.

La penalización de repetición debe ser pequeña frente a la compatibilidad física. Nunca elegir un clip malo solo para evitar repetir. Nunca impedir la reproducción cuando el clip es el único compatible.

## 8.5 Criterios de aborto de la fase

Revertir si:

- aumenta el patinaje medido (deslizamiento de apoyo por encima de la tolerancia actual);
- aumentan cortes o discontinuidades de fase visibles en render;
- empeora el error de root motion respecto de la línea base;
- algún gate test deja de pasar.

**Aceptación:** disminuir la dominancia del clip único de `run_change`, conservar continuidad y no aumentar patinaje, cortes o errores de root motion.

---

# 9. FASE SIETE — REPARAR ALIASES Y RESOLUCIÓN DE CLIPS

La auditoría identifica estos problemas:

- `Soccer_Spin`, `Sprint_Turn`, `Defender`, `Writhing_In_Pain` no resuelven en modo 4.
- `Defender_2` resuelve a un clip de pared.
- `Running_Tired` resuelve a `jn_nis_idle_0954`.
- `Jumping_Up`, `Jump_2`, `Jump_4` resuelven todos a `jn_jump_0336`.
- `Sprint_To_Backslide` y `Shoulder_Hit_And_Fall` resuelven al mismo `jn_fall_hit_2352`.
- `Idle_To_Sprint` resuelve a `jn_start_0494`.
- Los alias de tackle fueron informados como correctos.

## 9.1 Proceso de reparación

Para cada alias:

1. buscar todas las referencias en código, overlay y datos;
2. identificar la intención del consumidor;
3. localizar candidatos por nombre original, categoría, metadatos y pose;
4. comprobar trayectoria, duración, root motion y parte corporal;
5. determinar si debe apuntar a un clip distinto o si el alias ya no se usa;
6. corregir el mapa sin renombrar el JSON original;
7. añadir prueba de resolución y prueba de compatibilidad del rol;
8. registrar alias obsoleto si no debe resolverse.

No asignar un alias a un clip solo porque el nombre parece parecido. `Defender_2` no puede seguir resolviendo a una pared si el consumidor espera una acción defensiva. No hacer que cuatro nombres de salto apunten al mismo clip salvo que se demuestre que son intencionalmente equivalentes.

## 9.2 Validación del índice

Comprobar:

- unicidad y estabilidad de IDs;
- ausencia de referencias a nombres inexistentes;
- alias duplicados;
- alias que apuntan a categoría incorrecta;
- overlays que sustituyen roles válidos;
- diferencias entre biblioteca importada y `AnimDB`;
- espejos y pares;
- precedencia entre nombre original, alias y rol.

**Aceptación:** cero alias rotos sin documentar; cero alias conocidos que resuelvan a una familia incompatible.

---

# 10. FASE OCHO — CONECTAR LOS 76 SEGMENTOS PENDIENTES CON CRITERIO

La auditoría documenta:

| Grupo | Segmentos | Requisito real |
|---|---:|---|
| `nis_misc`, `nis_sit`, `nis_walk` | 47 | Requieren objeto, participante o sincronización contextual |
| `receive`, `receive_turn`, `control_stand` | 25 | Revisión visual y verificación del instante/parte de contacto |
| `setpiece_miss` | 2 | La suelta ocurre en t=0 sin velocidad; falta un evento real de suelta |
| `kick_flick` | 1 | Sombrero: falta trayectoria aérea entre toques |
| `ball_sole` | 1 | No hay sistema consumidor |

## 10.0 Prerrequisito: inventario de assets contextuales

Los 47 `nis_*` asumen la existencia de assets de escena: banco, túnel, sala de prensa, camilla, árbitro, público, mascota. Antes de abrir esta fase, usar el inventario de Fase 0. Si faltan assets, los clips correspondientes se marcan como *pendientes por assets* y no bloquean la fase. Conectar el código sin assets produce clips que nunca saldrán en partido y da una falsa sensación de cobertura.

## 10.1 Escenas contextuales

Los 47 clips contextuales no deben entrar en el selector de acciones físicas normales. Crear o reutilizar un consumidor contextual que gestione participantes, objetos, sincronización, posiciones y salida de escena.

No reproducir una animación de camilla, túnel, himno o interacción como si fuera un movimiento de partido.

## 10.2 Recepciones

Revisar los 25 uno por uno. Un clip que no representa una recepción debe permanecer fuera de `JsonReceive`, pero no ser eliminado ni excluido del resto del catálogo.

## 10.3 Saque de banda

Los dos `setpiece_miss` necesitan un evento de liberación real. No aplicar un impulso al balón al iniciar el clip si la animación no contiene un punto de liberación medible. Si no se puede verificar, mantener pendiente.

## 10.4 Sombrero

Para `kick_flick`, diseñar la secuencia como dos contactos físicos diferenciados:

1. contacto inicial que eleva el balón;
2. trayectoria aérea intermedia;
3. segundo contacto que redirige el balón.

El sistema debe predecir el balón entre contactos y validar ambos. No representar el sombrero como un único impulso inventado.

## 10.5 Planta del pie

`ball_sole` requiere un consumidor de juego claro: pisar/frenar/proteger balón. Antes de conectarlo, definir:

- cuándo puede solicitarse;
- cómo se aproxima el jugador;
- qué parte de la planta toca;
- cómo se reduce o mantiene la velocidad del balón;
- cómo se sale de la acción;
- qué ocurre si un rival disputa la pelota.

No crear un rol que no tenga una mecánica funcional.

---

# 11. FASE NUEVE — ARBITRAJE, CANCELACIONES Y CADENA DE ACCIONES

El árbitro actual tiene prioridades medidas:

| Familia | Prioridad |
|---|---:|
| GESTURE | 10 |
| OVERLAY | 20 |
| BALL_MOVE | 40 |
| KICK | 50 |
| BODY | 60 |
| SET_PIECE | 70 |
| FALL | 80 |

Solo una prioridad estrictamente superior interrumpe una acción activa; acciones de prioridad igual o inferior se rechazan. El sistema utiliza tokens de cancelación y una única ranura de acción.

La auditoría registró 6.847 acciones aceptadas, 2.244 rechazadas por prioridad, 207 interrupciones y 2.696 expiraciones automáticas en cuatro partidos.

## 11.1 Mantener la autoridad del árbitro

No permitir que cada planificador reproduzca directamente una acción saltándose `ActionArbiter`.

Todas las solicitudes deben pasar por el árbitro, salvo overlays que estén expresamente diseñados para coexistir y no controlen el cuerpo o la física.

## 11.2 Revisar prioridades por conflicto real

No cambiar números porque una acción se vea mejor. Preparar pruebas de:

- caída durante tiro;
- caída durante recepción;
- entrada durante conducción;
- tiro durante control;
- balón parado durante locomoción;
- acción de arquero ante disparo;
- interrupción por pérdida de posesión;
- acción nueva de igual prioridad;
- token viejo que intenta finalizar una acción ya cancelada.

## 11.3 Medir rechazos por familia de acción

Los 2.244 rechazos de 6.847 solicitudes (~33 %) no son equivalentes. Antes de tocar prioridades, medir la distribución:

- si la mayoría son `GESTURE 10` rechazados contra `KICK 50`, es correcto;
- si hay muchos `BALL_MOVE 40` rechazados contra `KICK 50`, puede indicar que la conducción se cancela demasiado y el jugador "no corre con la pelota";
- si hay muchos `KICK 50` rechazados contra `BALL_MOVE 40`, puede indicar tirones por oscilación entre planificadores.

Medir por familia y por par origen/destino de rechazo antes de cambiar cualquier número. Añadir esta tabla a la entrega de la fase.

## 11.4 Caso borde: interrupción en el frame de contacto

Un golpeo está a punto de validar contacto y una acción de mayor prioridad (caída, barrida) lo interrumpe en ese mismo frame. Hay dos políticas posibles:

- **Política A (contacto manda):** si el contacto físico ocurrió antes de la interrupción, el impulso se aplica aunque la acción se cancele inmediatamente después.
- **Política B (acción manda):** si la acción se interrumpe antes de aplicar el efecto, el impulso no se aplica.

Elegir una política explícita (recomendado: A, porque el pie tocó el balón físicamente) y documentarla. Añadir test específico: interrumpir un golpeo en el frame de contacto desde cada una de las familias `BODY` y `FALL`, y verificar que la política elegida se cumple sin goles "fantasma" ni tiros que se ven pero no impactan.

## 11.5 Reducir expiraciones y abortos evitables

Registrar duración esperada, duración real y motivo de finalización. Una acción no debe expirar silenciosamente si quedó esperando un contacto. Tampoco debe mantenerse activa después de perder su validez.

La auditoría informa 548 inicios de acciones de movimiento de balón, 183 cortes y 99 pérdidas de toque; en recepciones, 124 inicios y 42 abortos. Desglosar esas causas antes de cambiar el comportamiento.

## 11.6 Encadenar acciones

Cuando una acción tiene varios contactos, como conducción o sombrero, el siguiente objetivo debe calcularse con el predictor y los eventos del clip. El siguiente toque no puede depender de que el balón quede pegado al jugador.

## 11.7 Ticket explícito de fallo intermitente

Registrar como ticket de esta fase: `test_ai_teams_play_a_real_match_without_getting_stuck` (jugador fuera de la cancha > 1 m, intermitente). Investigar en el marco de determinismo (sección 13) y no dejarlo como nota de auditoría. No cerrar la fase sin haberlo abordado o justificado por escrito por qué se difiere.

---

# 12. FASE DIEZ — CATÁLOGO, METADATOS Y DATOS DE ANIMACIÓN

## 12.1 Conservar la fuente original

Los 2.022 JSON originales son inmutables. Las correcciones deben vivir en overlays, índices, perfiles o metadatos derivados versionados. Nunca editar el archivo fuente para que un test pase.

## 12.2 Metadatos que deben estar disponibles cuando existan

La auditoría informa metadatos de runtime como:

- `root_path`;
- `heading_path`;
- `v_in` / `v_out`;
- `natural_speed`;
- muestras de contacto;
- trayectorias de pie, cabeza y manos;
- datos de liberación de balón parado;
- postura de caída.

La cobertura informada varía por campo: contactos medidos en 447 clips; trayectorias de pie/cabeza/manos en 887; liberación para 18 clips de balón parado; postura de caída en 269.

No exigir que todos los clips tengan todos los campos. El consumidor debe declarar los requisitos mínimos de su acción.

## 12.3 `ball_local` y datos que no estén presentes

El CSV derivado de los JSON no contiene necesariamente `ball_local`, `f0a`, `f0e`, `f10`, `f16` ni `f18`. La extracción técnica indica que esos campos no están disponibles en los ZIP JSON examinados.

Esto **no demuestra que falten en el runtime del juego**: la auditoría informa que `BallHandler` ya compara muestras de contacto almacenadas con el balón predicho. Comprobar el formato real de los recursos y el origen de esas muestras antes de añadir campos.

Reglas:

- no inferir que la posición del pie es la posición del centro del balón;
- no reconstruir `ball_local` con conversiones no verificadas;
- no añadir conversiones de un binario sin verificar estructura, orden, unidades y ejes;
- si el runtime ya tiene la información necesaria, reutilizarla;
- si falta para una familia concreta, añadir un metadato derivado con procedencia y validación, sin modificar originales;
- si en el futuro se quiere incorporar `ball_local` para una mejora concreta, debe venir de un runtime verificado (no de un CSV externo, no de un `.adb` sin layout confirmado, no de una conversión heurística).

## 12.4 Validación de metadatos

Crear pruebas para:

- campos finitos;
- frames dentro del rango;
- parte corporal existente;
- velocidad y unidades válidas;
- orientación coherente;
- trayectorias sin saltos imposibles;
- eventos ordenados;
- contacto único o múltiple según la acción;
- espejos consistentes;
- roles y categorías compatibles.

---

# 13. FASE ONCE — DETERMINISMO Y REPRODUCIBILIDAD

El documento de estado informa RNG sin semilla en `BallHandler` y `Goalkeeper`, con resultados variables en pruebas de partido. La auditoría posterior debe verificar también `AIInput` y otros generadores.

## 13.1 Semillas

- permitir inyectar una semilla desde el partido de prueba;
- usar generadores separados por subsistema cuando corresponda;
- no usar `randomize()` dentro de una ruta que debe ser reproducible;
- mantener aleatoriedad en juego normal si forma parte del diseño, pero registrar la semilla;
- guardar la semilla en cada log de partido.

## 13.2 Reproducción de errores

Toda incidencia de selección debe poder reproducirse con:

- semilla;
- tiempo/tick;
- jugador;
- estado del balón;
- acción solicitada;
- candidatos evaluados;
- acción aceptada;
- resultado del contacto.

## 13.3 Ticket de fallo intermitente

`test_ai_teams_play_a_real_match_without_getting_stuck` se aborda en esta fase. Con semilla fija, ejecutar el partido N veces y verificar si el fallo "jugador fuera de la cancha > 1 m" reaparece. Si aparece con semilla fija, es un bug real que hay que aislar. Si solo aparece sin semilla, es una variante de comportamiento que debe documentarse con sus condiciones y, si es aceptable, ajustar la aserción con justificación (no relajarla sin más).

**Aceptación:** una misma semilla y configuración producen el mismo resultado lógico en las pruebas headless, salvo componentes expresamente no deterministas que estén identificados.

---

# 14. FASE DOCE — RENDIMIENTO Y ANDROID

El estado informa aproximadamente 207 MB de bibliotecas de pose cargadas en escritorio y que no existe medición suficiente en dispositivo Android real. El objetivo es mejorar la utilización del catálogo sin exceder memoria o CPU.

Dispositivo objetivo conocido: Android con GPU Mali-G57, pantalla 2400×1080 y CPU de 8 núcleos. No asumir que los resultados de escritorio representan el móvil.

## 14.1 Medición antes de optimizar

Registrar:

- memoria de recursos y picos;
- tiempo de carga de bibliotecas;
- coste de evaluación de candidatos por acción;
- número de clips evaluados por tick;
- tiempo de `AnimationTree`/`AnimationPlayer`;
- coste de retargeting;
- tiempo de física y predictor;
- FPS, frame time p50/p95;
- GC/allocations si aplica;
- temperatura y throttling durante sesiones largas.

## 14.2 Optimizaciones seguras

Priorizar:

- caché de muestras de contacto y trayectorias;
- evitar recalcular transformaciones invariantes;
- limitar candidatos por filtros baratos antes de evaluación cara;
- cachear índices por rol/contexto;
- evitar asignaciones temporales por frame;
- escalonar decisiones de IA;
- cargar recursos según necesidad solo si no rompe el acceso inmediato a acciones;
- reducir detalle visual según distancia, sin degradar al jugador controlado;
- mantener el mismo resultado de selección al optimizar.

No eliminar clips ni reducir el catálogo para ahorrar memoria sin un análisis de uso y un plan de carga seguro.

## 14.3 Criterios numéricos de validación en Android

"Sesión prolongada" no es criterio. Reemplazar por métricas medibles:

- 20 min de partido con jugador controlado, sin errores de script;
- memoria estable: Δ memoria entre minuto 5 y minuto 20 < 20 MB;
- frame time p95 < 33 ms (equivalente a ~30 FPS sostenidos);
- frame time p50 < 20 ms;
- sin throttling térmico durante los primeros 10 min (comparar p95 en min 1–2 vs min 8–9; si sube más del 50 %, hay throttling);
- FPS ≥ 30 sostenidos en partido normal;
- sin crashes ni ANRs durante la sesión;
- tacto del jugador controlado responde en < 100 ms percibidos.

Estas métricas se miden en el dispositivo Android objetivo, no en emulador ni en escritorio.

## 14.4 Criterios de aborto de la fase

Revertir cualquier optimización si:

- cambia la selección de clips en partidos de referencia (comparar distribución vs línea base);
- empeora el error de contacto medido en Fase 3;
- introduce errores de física del balón;
- algún gate test deja de pasar.

**Aceptación:** Android validado por métricas numéricas del dispositivo real, no por generación de APK.

---

# 15. PLAN DE PRUEBAS Y CRITERIOS DE ACEPTACIÓN

Cada fase debe incluir pruebas unitarias, pruebas de integración y pruebas visuales. No cerrar una fase solo porque compila.

## 15.0 Gate tests vs monitoring tests

Declarar antes de empezar qué pruebas son **gate** (bloquean merge si fallan) y cuáles son **monitoring** (informativas, no bloquean). Esto evita que la suite crezca hasta volverse impracticable.

**Gate tests mínimos sugeridos (ajustar en Fase 0):**

- hashes de los 2.022 JSON originales idénticos al snapshot de Fase 0;
- importación de las 3.223 variantes sin errores (poses finitas al inicio, mitad y final);
- `test_action_arbiter` 9/9;
- `test_receive` suite completa;
- `test_pack_locomotion` (en copia limpia, sin instrumentación);
- `test_ai_match` con semilla fija (una vez que Fase 9 garantice determinismo);
- `live_kicks` 50/50 con contacto;
- `live_feet` sin regresiones;
- ningún alias roto documentado pasa a roto no documentado;
- cero referencias a nombres inexistentes en índices.

**Monitoring tests sugeridos:**

- partidos IA largos con varias semillas;
- distribución de uso por rol y clip;
- variantes observadas por partido;
- repeticiones por ventana visible;
- abortos por familia de acción;
- tiempo de carga y memoria.

Los gate tests no se relajan para pasar. Si un gate test falla legítimamente porque la línea base estaba mal, se actualiza la línea base en un commit separado, con justificación, y no dentro del mismo commit que la corrección que lo hace fallar.

## 15.1 Catálogo e índices

- todos los JSON originales siguen presentes;
- mismo SHA-256 de fuentes;
- 3.223 variantes o cifra actual explicada;
- roles e índices válidos;
- alias reparados;
- espejos íntegros;
- ningún recurso con pose NaN/Inf;
- importación y muestreo de inicio/mitad/final.

## 15.2 Contacto

- pase raso;
- pase elevado;
- tiro;
- tiro de primera;
- centro;
- control de pie;
- recepción de pecho;
- recepción de muslo;
- cabezazo;
- volea;
- atajada de mano;
- despeje del arquero;
- entrada y disputa.

En cada caso registrar distancia, altura, error de dirección, frame, miembro y resultado físico.

**Verificación de espejo — pie animado vs pie efectivo.** Para cada golpeo (original o espejo), verificar que el pie que anima el clip coincide con el pie que el planificador reportó como pie de contacto. Un espejo mal aplicado produce patadas con pierna equivocada y no se detecta desde logs. Añadir como gate test: `assert foot_animated == foot_reported` para cada golpeo. Casos mínimos: golpeo con pierna derecha original, golpeo con pierna derecha espejado, golpeo con pierna izquierda original, golpeo con pierna izquierda espejado.

## 15.3 Juego aéreo

Preparar escenarios reproducibles para centros, despejes, cabezazos y voleas. Comprobar que la IA realmente solicita esas acciones y no solo que el catálogo tiene clips. Incluir los tests de clasificación de Fase 6.6 (cabezazo defensivo no hacia arco propio; no intervenir con compañero mejor posicionado).

## 15.4 Recepción

Ejecutar pases desde varias direcciones, velocidades y alturas. Medir:

- intentos;
- clips seleccionados;
- contactos válidos;
- fallos;
- abortos;
- uso del fallback físico;
- posesión retenida;
- orientación de salida.

## 15.5 Locomoción

Medir:

- arranque;
- aceleración;
- carrera;
- sprint;
- frenada;
- giro;
- cambio de dirección;
- locomoción con balón;
- transición después de acción.

Detectar patinaje, cambios bruscos de velocidad, deslizamiento del root y repeticiones excesivas. Comparar con línea base.

## 15.6 Partido completo

Ejecutar múltiples partidos con semillas distintas y con semilla fija. Registrar:

- goles;
- pases;
- tiros;
- centros;
- recepciones;
- cabezazos;
- voleas;
- entradas;
- atajadas;
- contactos fallidos;
- acciones abortadas;
- uso por rol y clip;
- errores de script;
- rendimiento.

## 15.7 Render — checklist de QA visual con criterios numéricos

Las pruebas headless no sustituyen la inspección visual. "Revisión visual" no es criterio medible. Crear escenarios renderizados con criterios numéricos por familia:

| Familia | Criterio numérico |
|---|---|
| Golpeo pie | Punta del pie dentro del radio visual del balón (~0,125 m del centro) en el frame de contacto |
| Cabezazo | Sin interpenetración del esqueleto con el balón, contacto único, cabeza por encima del centro del balón |
| Volea | Pie por debajo del centro del balón, no lateral, sin atravesar el balón |
| Atajada | Manos dentro del radio del balón, no atravesándolo, sin clipping |
| Recepción de pecho/muslo | Contacto único, sin interpenetración, dirección de salida coherente con la pose |
| Transición de locomoción | Sin discontinuidad de fase (si hay salto de frame de ciclo, rechazar); sin patinaje medible |
| Root motion en acción | El jugador termina donde el clip indica ±tolerancia; no hay teletransporte en el frame de contacto |
| Giro | Sin saltos de heading; orientación final dentro de tolerancia |
| Sincronía de balón | El balón no cambia de posición por la animación; solo por impulso validado |

Cada criterio debe ser evaluable desde log, no solo desde inspección humana. Los clips que no cumplan se marcan para revisión y no se consideran "visualmente correctos".

## 15.8 Android real

Instalar APK en el dispositivo objetivo y medir según los criterios numéricos de la sección 14.3. No declarar Android validado por el mero hecho de que GitHub Actions haya generado un APK firmado.

---

# 16. ORDEN DE IMPLEMENTACIÓN

No implementar todo en un único cambio. Trabajar por etapas pequeñas, cada una con commit y pruebas.

| Etapa | Trabajo | Resultado esperado |
|---|---|---|
| 0 | Auditoría del repositorio y línea base | Mapa real de código, métricas, snapshot, gate tests, inventario de assets |
| 1 | Trazabilidad de candidatos y acciones | Diagnóstico de selección y rechazos + overlay de debug |
| 2 | Clasificación de los 322 filtrados | Tabla completa de causas y decisiones, con casos inclasificables explícitamente diferidos |
| 3 | Precisión de contacto | Menor error sin perder acciones válidas, con BallPredictor resuelto si es la causa |
| 4 | Solicitud de cabezazos/voleas por IA | Juego aéreo activo, clasificado ofensivo/defensivo/neutro/no intervenir/esperar, sin goles en propia por despeje |
| 5 | Recepciones | Más clips completados y menos abortos evitables |
| 6 | Transiciones/variedad | Menos repetición (por jugador y por ventana visible) y continuidad mejor |
| 7 | Alias | Resolución correcta por intención |
| 8 | 76 pendientes | Conexiones contextuales y físicas justificadas; assets inventariados |
| 9 | Determinismo | Reproducción estable de pruebas; fallo intermitente abordado |
| 10 | Rendimiento Android | Medición real con criterios numéricos y optimización segura |

Cada etapa debe cerrar con:

- archivos modificados;
- motivo de cada cambio;
- pruebas ejecutadas;
- resultados antes/después;
- riesgos conocidos;
- commit;
- confirmación de que los JSON originales y la rama de respaldo permanecen intactos;
- confirmación de gate tests pasan;
- comparación con criterios de aborto de la fase.

---

# 17. FORMATO DE INFORME QUE CLAUDE DEBE ENTREGAR

Al terminar cada etapa, actualizar un único documento de seguimiento con esta estructura:

1. **Estado inicial:** commit, rama, pruebas y métricas.
2. **Problema confirmado:** evidencia del código y del log.
3. **Archivos involucrados:** ruta y funciones concretas.
4. **Cambio realizado:** qué se modificó y por qué.
5. **Sistemas reutilizados:** qué componentes existentes se mantuvieron.
6. **Pruebas:** comando, resultado y artefacto/log.
7. **Comparación:** métricas antes/después.
8. **Criterios de aborto:** verificación de que no se superó ningún umbral.
9. **Pendientes:** lo que no se resolvió y por qué.
10. **Integridad:** verificación de JSON, recursos y ramas.
11. **Commit:** hash y resumen.

No declarar resuelto algo solo porque el código compila. Diferenciar:

- registrado;
- importado;
- seleccionable;
- invocado;
- completado;
- contacto validado;
- visualmente correcto en render;
- probado en Android.

---

# 18. ORDEN FINAL PARA CLAUDE

Primero inspeccioná el repositorio real y confirmá qué partes de esta guía ya están implementadas. No reescribas lo existente. Después ejecutá las fases en el orden indicado.

La prioridad funcional es:

1. mejorar precisión del contacto real;
2. conseguir que la IA solicite y complete cabezazos y voleas cuando la trayectoria lo permita;
3. revisar y recuperar los 322 segmentos que están conectados pero bloqueados por filtros;
4. elevar la tasa de recepciones animadas correctas;
5. reducir la repetición de transiciones sin introducir aleatoriedad incorrecta;
6. reparar alias;
7. resolver los 76 segmentos pendientes según su consumidor real;
8. instrumentar y hacer reproducibles los resultados;
9. validar el rendimiento en Android.

**No sacrifiques física, control del balón, estabilidad ni rendimiento para aumentar artificialmente el número de animaciones utilizadas.** El objetivo no es reproducir más clips por minuto: es que cada clip correcto se active en la situación correcta, alcance el contacto correcto, produzca el efecto físico correcto y continúe con una transición coherente.

El resultado final debe ser un sistema integrado donde IA, control humano, predicción, catálogo, planificadores, árbitro, ejecución de animación y física del balón compartan el mismo estado del partido y puedan verificarse con métricas reproducibles.

**La presentación ambiental** (`MatchPresentation` — público, técnico, suplente, mascota) se trata en Fase 8 como *no prioridad*. Aunque la auditoría registra 204 conexiones ambientales, no participan en la física de partido y pueden diferirse hasta después de la validación en Android. No cuentan como cobertura funcional del banco real.
