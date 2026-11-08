# Integración de Fútbol 5 — ejecución del 2026-11-07

**Trabajo parcial; la integración total solicitada no está terminada.** Registro y reproducción técnica no equivalen
 a conexión correcta con situaciones de partido. La auditoría conserva esa diferencia por cada clip.

## Material y protección

- Trabajo en `integracion-openai`. `origin/respaldo-f3` se leyó en `3d47a07`; no se modificó esa rama.
- Nombre encontrado mediante el árbol Git: `FUTBOL5_GODOT_4_7_2_INTEGRACION.zip`, blob
  `9b839a10a3b14754b996a50bb8fa692a9226b99a`, 435.001 bytes. Copia original idéntica en esta carpeta.
- Extracción independiente: `/tmp/futbol5-integracion/extraido/`. CRC del ZIP correcto. `zip_manifest.json` contiene
  hashes SHA-256 de los 292 archivos efectivamente recibidos.
- El ZIP declara y contiene 38 animaciones **sintéticas de prueba**, no 2.022 animaciones nuevas. Su manifiesto original
  referencia `INFORME_MODIFICACIONES.md`, ausente en el ZIP. Los demás archivos listados pasaron SHA-256.
- El proyecto ya contiene las poses convertidas de 2.022 fuentes en `json_clips.res`, `json_scenes.res`, `json_keeper.res`.
  Las fuentes JSON originales completas no están en el repositorio ni en este ZIP; no se regeneraron ni sobrescribieron.

## Inventario individual y conexiones

- [estado_individual.csv](estado_individual.csv): 2.024 tramos de 2.022 fuentes; conserva función, acción, estado de conexión,
  consumidor, entrada/salida, transición, movimiento, duración, contactos y datos UCS del inventario previo; agrega evidencia
  nueva de invocación, muestreo de pose, índice por rol y espejos.
- [runtime_audit.json](runtime_audit.json): 3.223 variantes realmente presentes, incluidos los espejos disponibles.
- [conexiones_pendientes.csv](conexiones_pendientes.csv): 338 tramos con conexión histórica `no` o `pendiente`.
- Del inventario anterior: 1.686 tramos `si`, 315 `no`, 23 `pendiente`. Estos estados proceden del análisis anterior;
  **esta sesión no verificó individualmente los 1.686 disparadores de juego**.
- Todas las variantes auditadas existen, están indexadas por rol efectivo y pudieron invocarse en `AnimationPlayer`.
  Ninguna se marcó visualmente verificada ni probada en Android por ello.

## Cambios funcionales

- `scripts/animation/anim_db.gd`: catálogo completo y registros defensivos, lista de acciones y candidatos por rol/contexto.
  La consulta del catálogo no necesita cargar las librerías de pose. Sin filtros, el resolver retorna todos los candidatos
  del rol y evita cálculos de metadatos redundantes. Los filtros dependen del contexto solicitado.
- `scripts/animation/json_catalog.gd`: las situaciones reales de partido usan ese resolver; conserva límites de espacio
  y duración del consumidor y evita duplicados en el pool. No reproduce el catálogo simultáneamente.
- Se reutilizan `PackLibrary`, `ActionArbiter`, `ActionMotion`, `FootballerVisual` y los planificadores actuales.
  Prioridad, interrupción, velocidad, mezcla y recuperación continúan bajo sus contratos existentes.
- `tools/integration/audit_bank.gd` y su escena: validación exhaustiva de existencia, invocación, pistas, huesos y poses
  finitas al inicio, mitad y final, sobre `json_human.scn`. No compara la pose contra todas las fuentes originales ausentes.
- `tools/integration/report.py`: cruza la auditoría ejecutada con el inventario previo de forma reproducible.
- `tools/run_tests.sh`: los errores de importación/compilación ya no se ignoran.
- `.github/workflows/android.yml`: mantiene Godot 4.7.2 y sus plantillas oficiales; agrega auditoría e informe como artefacto;
  los fallos de render bloquean la compilación; resumen distingue inclusión de conexión. No se habilitó publicación de releases.

## Compatibilidad de los sistemas del ZIP

El ZIP es un proyecto base independiente, con física propia y ejes +Z adelante/+X izquierda. El juego usa Jolt y el
marco de clips +X adelante/+Z derecha. Copiar sus clases `Ball`, `Player` y gestores sobre los actuales rompería contratos
 y referencias. Se conservan los sistemas complejos existentes; **no se afirma que se haya trasladado toda regla del ZIP**.

| Sistema | Implementación existente conservada | Estado de integración del ZIP |
|---|---|---|
| Movimiento, aceleración, giros | `Locomotion`, `JsonBallMove`, `PlayerActions` | Sin reemplazo; no se verificó equivalencia total de parámetros |
| Balón, predictor, pases y tiros | `Ball`, `BallPredictor`, `BallHandler`, asistencias | Sin segunda simulación paralela |
| Contactos, prioridades, caídas | `ActionArbiter`, `ActionMotion`, `JsonReceive` | Se conservan contratos y condiciones físicas |
| IA individual y de equipo | `AIInput`, `TeamBrain`, `UCSParams` | Sin migración completa de reglas del ZIP |
| Arqueros | `Goalkeeper`, `KeeperPlanner` | Poses verificadas técnicamente; decisiones no verificadas clip por clip |
| Reglas y reinicios | `MatchManager`, `SetPiece`, `Referee` | Escenas existentes conservadas |
| Android | `TouchControls`, `HumanInput`, workflow Android | Sin medición en dispositivo |

## Pruebas ejecutadas

Godot usado: `4.7.2.stable.official.ed1daf0bf` (distribución oficial).

| Comprobación | Resultado ejecutado |
|---|---|
| CRC del ZIP | Sin errores |
| SHA-256 del manifiesto recibido | Un archivo listado ausente; resto correcto |
| Validador Python del ZIP | 38 clips, 0 con errores; avisos de metadatos documentados por su validador |
| Suite del proyecto independiente del ZIP | 22 OK, 0 fallas |
| Catálogo central nuevo | 2 pruebas, 0 fallidas, 78 comprobaciones |
| Integración previa del banco | 6 pruebas, 0 fallidas, 42 comprobaciones |
| Auditoría sobre esqueleto real | 2.022 fuentes, 3.223 variantes, 0 fallos |
| Android físico: CPU/GPU/memoria/contactos | No ejecutado |

La auditoría midió 202.997.246 bytes de memoria estática del proceso de escritorio con las librerías cargadas.
**No es una medición de Android ni del consumo durante un partido.** Las librerías de pose aún se cargan completas;
no se implementó todavía la carga individual con liberación por clip. Los recursos originales se conservan.

## Pendientes reales

- Completar y verificar los 338 tramos sin conexión histórica: escenas de público/técnicos/mascota, variantes de marcha,
  preparación, roles especiales, recepciones pendientes y golpeos cuyo contacto no sirve en el contexto actual.
- Una reproducción genérica no sustituye las condiciones de contacto, poses de entrada/salida ni personajes adecuados.
- Revisión visual individual, transiciones y contactos de todo el catálogo en partido.
- Incorporar las reglas del ZIP que difieran mediante adaptaciones medidas y pruebas de regresión.
- Streaming de poses por clip y medición de CPU/GPU/memoria en Android físico.
- Obtener las fuentes originales si se necesita analizar o regenerar los 2.022 JSON completos.

Resultado final de la suite ampliada y de GitHub Actions: secciones siguientes.

## GitHub Actions y APK

- Commit inicial subido: `a5edf7a`, rama `integracion-openai` (rama remota creada sin push forzado).
- Workflow consultado: `Android APK`, id `397788632`, activo.
- Se intentó `gh workflow run android.yml --ref integracion-openai` con `skip_tests=false`,
  `publish_release=false`, `allow_without_pack=false`.
- GitHub respondió **HTTP 403: Resource not accessible by integration** al endpoint de dispatch. La credencial disponible
  permite leer Actions y hacer push, pero no iniciar este workflow manualmente.
- No se generó una ejecución nueva ni un APK nuevo; no hay enlace de descarga nuevo. No se publicó ninguna release.
- Para iniciar desde una cuenta con permisos: [Android APK](https://github.com/roldanhr98-byte/Futbol5/actions/workflows/android.yml),
  **Run workflow**, rama **integracion-openai**, sin saltar pruebas y con **publish_release desactivado**.
  La ejecución debe superar las pruebas y exportación; recién entonces estará disponible el artefacto `futbol5-apk`.

## Verificación ampliada y defectos observados

- `live_feet`, con Xvfb/X11/OpenGL y el humanoide animado: **7 pruebas, 2 fallidas, 66 comprobaciones**.
  Fallos: el cuerpo coincide con la pelota durante el 12 % del escenario de giros; giro de sprint de 180° avanza
  1,40 m y no supera su condición de aceptación. Las otras cinco pruebas de esa suite pasaron.
- Comparación ejecutada en una copia temporal del commit anterior (`a5edf7a^`): el caso de giros también falla
  con **12 %**, mismos 33/10 toques en curva/aceleración. Ese defecto está comprobado como preexistente.
- La suite completa detectó además `test_ai_match::test_ai_teams_play_a_real_match_without_getting_stuck`:
  los arqueros no enfrentan disparos. Se conserva como fallo observado, sin ocultarlo ni modificar la prueba.
- Evidencia de las ejecuciones en [`pruebas/`](pruebas/). Los avisos de audio sin dispositivo y recursos retenidos
  al salir están conservados en los logs. Muestreo de poses no equivale a revisión visual de imágenes.
- Índice técnico: **58 entradas, 0 errores, 0 avisos**. `bash -n`, compilación Python y `git diff --check` sin errores.

Comparación adicional sobre el commit anterior: el giro de sprint de 180° también falla con **1,40 m**
(`pruebas/cambio_direccion_antes.log`): los dos fallos de `live_feet` son reproducibles antes de estos cambios.
La prueba aislada de IA pasó en el commit anterior (1/0, 5 comprobaciones); una sola corrida no establece una tasa de
fallo ni demuestra por sí sola una regresión o su ausencia. No se modificaron las pruebas ni las mecánicas para ocultar
estos resultados. Sintaxis del workflow validada mediante PyYAML.

Lista de archivos creados y modificados respecto del inicio: [`archivos_cambiados.txt`](archivos_cambiados.txt).
Se consultaron también referencias e historial Git de archivos ZIP/7z/RAR; no se encontró el banco original completo.

## Resultado final de la suite completa

`tools/run_tests.sh` terminó: **292 pruebas totales, 1 fallida, 32 omitidas, 1.800 comprobaciones**,
1.382,3 segundos. No se encontraron `SCRIPT ERROR`. La ejecución devolvió estado no cero y **no se declara aprobada**.
El único fallo fue `test_ai_match::test_ai_teams_play_a_real_match_without_getting_stuck`:
«los arqueros enfrentan disparos». Las otras 259 pruebas ejecutadas pasaron; 32 quedaron omitidas por sus condiciones.
Los cuatro partidos simulados de 3, 5, 7 y 10 minutos pasaron. También pasaron las series de tiros/atajadas y las pruebas
de reglas, balón, pases, recepciones, controles y entrenamiento que figuran en el log.

Log íntegro: [`pruebas/suite_completa.log`](pruebas/suite_completa.log).
La suite `live_feet` ejecutada aparte con render mantiene sus dos fallos preexistentes (7 totales, 2 fallidas).
El catálogo nuevo también se repitió sobre el código final: 2 pruebas, 0 fallidas, 78 comprobaciones.

**Estado de entrega: parcial.** No están completadas las 338 conexiones pendientes del inventario histórico,
la validación visual individual, el traslado completo de reglas del ZIP, el streaming por clip ni la prueba Android física.
GitHub rechazó el dispatch con HTTP 403; no existe APK nuevo ni enlace de descarga nuevo.
