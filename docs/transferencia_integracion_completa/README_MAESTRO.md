# Transferencia de la integración: léeme primero

Esta carpeta está escrita para **otro desarrollador (o Claude) que no conoce el historial**. Con ella debería poder
saber:

- qué existe;
- dónde está cada dato;
- qué hace cada animación;
- dónde se produce cada contacto;
- cómo se mueve el balón;
- qué falta conectar para que todo funcione como un único sistema.

Rama de trabajo: `respaldo-f3`. La rama por defecto en GitHub, `ccr-a6c53cd2-uoxpk0`, solo se actualiza al terminar.
**No se modificó código de juego para escribir esta documentación.**

## 1. El proyecto en cinco líneas

- Juego de fútbol 5 para Android: Godot 4.7.2, GDScript, física Jolt a 60 Hz, renderer GL Compatibility.
- Cancha de 50 × 30. Cuatro jugadores de campo y un arquero por equipo. Ejes:
  - X = largo, Z = ancho, Y = arriba;
  - el equipo 0 ataca hacia +X;
  - `yaw = 0` mira a −Z, y un `yaw` creciente gira a la **izquierda**.
- Se usa solo el **modo de juego 4**: las animaciones vienen de un banco de 2022 clips JSON con nombres de Ultimate Clash
  Soccer (UCS), convertidos a las librerías `assets/animations/json_*.res`.
- **La pelota solo cambia por impulsos** (`Ball.kick`) y por su física. Nunca se fija su posición para «conducirla».
  Las animaciones dan el **cuándo** y el **dónde** del contacto; la física, el resultado.
- UCS sirve como **referencia de datos**:
  - `animdb.adb`: un registro de 104 bytes por clip;
  - `libMPX.so`: valores por defecto de 211 parámetros de juego.

  Su lógica **no se descompiló**.

## 2. Orden de lectura

| # | Documento | Para qué |
|---|---|---|
| 1 | este archivo | contexto, reglas, cómo verificar |
| 2 | [`PENDIENTES_INTEGRACION.md`](PENDIENTES_INTEGRACION.md) | **estado real** (tabla) y qué hacer, en orden |
| 3 | [`MAPA_CODIGO.md`](MAPA_CODIGO.md) | orden de ejecución por paso de física y ficha de cada sistema (responsabilidad, funciones, quién llama a quién, problemas); anexo con todas las funciones y sus líneas |
| 4 | [`FISICAS_BALON.md`](FISICAS_BALON.md) | cómo se mueve la pelota, quién la cambia y en qué orden, contactos, conflictos |
| 5 | [`FISICAS_JUGADOR.md`](FISICAS_JUGADOR.md) | velocidades, aceleración, giro, piernas, IK, raíz frente a física; valores del código frente a UCS |
| 6 | [`ACCIONES_FUTBOLISTICAS.md`](ACCIONES_FUTBOLISTICAS.md) | cada acción: inicio, selección, contacto, física, fin, con diagramas |
| 7 | [`MAPA_ANIMACIONES.md`](MAPA_ANIMACIONES.md) + [`INVENTARIO_ANIMACIONES.csv`](INVENTARIO_ANIMACIONES.csv) | las 2024 animaciones, una por fila: dónde están, qué hacen, si funcionan en el juego |
| 8 | [`DATOS_UCS.md`](DATOS_UCS.md) | los 52 campos de `animdb.adb`, nuestro `animdb.json` y los metadatos medidos |
| 9 | [`IA_UCS_Y_FUTBOL5.md`](IA_UCS_Y_FUTBOL5.md) | nuestra IA comportamiento por comportamiento, al lado de los parámetros de UCS |
| 10 | [`PARAMETROS_UCS.md`](PARAMETROS_UCS.md) + [`PARAMETROS_UCS.csv`](PARAMETROS_UCS.csv) | los 211 parámetros: valor, origen, campo, estado y correcciones respecto de E4 |

Documentos anteriores que esta carpeta **completa** (no los repite):

- [`docs/fases/E3_conduccion_ucs.md`](../fases/E3_conduccion_ucs.md): conducción y toque orientado;
- [`docs/fases/E4_integracion_ucs.md`](../fases/E4_integracion_ucs.md): integración, IA y pruebas;
- [`docs/fases/00_auditoria_modo_json.md`](../fases/00_auditoria_modo_json.md): auditoría del modo 4 y de los archivos de
  UCS;
- [`docs/ESTADO_Y_METODOLOGIA.md`](../ESTADO_Y_METODOLOGIA.md): estado general y forma de trabajo;
- [`docs/technical-index/INDEX.md`](../technical-index/INDEX.md): índice técnico del repositorio.

## 3. Cómo se marca la certeza

Todos los documentos separan:

- **[C] comprobado:** leído en el código (archivo, función, línea) o medido en los datos, con el método escrito.
- **[D] deducido:** una regularidad en los datos (correlación, patrón), sin ver el código de UCS.
- **[I] inferido:** solo por el nombre o por analogía.
- **[?] desconocido.**

**Nada de UCS está marcado como comprobado salvo valores y estructura.** Su comportamiento no se pudo ver.

## 4. Lo más importante que hay que saber (resumen con referencias)

1. **Un paso del jugador** (`Footballer._player_step`, `scripts/player/footballer.gd:203`):
   1. entrada;
   2. clip con raíz (`PlayerActions.tick`) **o** locomoción;
   3. `move_and_slide`;
   4. `BallHandler.update`.

   Durante un clip con raíz no corre `BallHandler.update`.
2. **Los golpeos:** el planificador (`BallHandler.plan_clip_kick`) elige el clip y el instante para que la punta del pie
   llegue a la pelota prevista. El impulso sale en el contacto medido del clip si la pelota está a ≤ 0.65 m. **La
   velocidad la fijan los asistentes** (`PassAssist`, `ShotAssist`, `CrossAssist`), sin depender del gesto: es el
   principal punto sin unificar.
3. **La conducción y los giros con pelota** usan los toques medidos de cada clip (`ball_touches`). Cada toque lleva la
   pelota a la punta del toque siguiente (`JsonBallMove._touch`). El toque orientado usa la **ventana del joystick de
   UCS**: es el único dato de UCS que lee el juego (`AnimDB.joystick_window`).
4. **Las recepciones** eligen el clip antes de que llegue la pelota, por la cinemática de la parte del cuerpo
   (`JsonReceive.plan`). Funcionan pie, muslo, rodilla y pecho; la cabeza no.
5. **Correcciones de esta investigación** (no cambian el comportamiento del juego, porque esos datos no se usan):
   - el campo 3 de `animdb.adb` **no es el cuadro del toque**: es el byte de la cabecera del `.sat` (1832/1832). El
     contacto de los golpeos está en el campo 24 [D];
   - los campos 5, 6, 40, 46, 47 y 49 cambian de significado según la familia;
   - los nombres L/R de UCS dicen casi siempre el lado contrario al de los datos;
   - 9 valores por defecto del CSV de E4 estaban mal o vacíos, y faltaba `Version` (`PARAMETROS_UCS.md` §2).

## 5. Reglas del proyecto (de `CLAUDE.md`, resumidas)

- No inventar resultados: una prueba que no se ejecutó no se anota como aprobada.
- No cambiar la mecánica salvo que la tarea lo pida. El balance va en las clases `*Tuning`.
- Nunca escribir claves (Tripo3D, firma de Android) en el repositorio, el chat ni los registros.
- Tripo3D: comprobar el coste y pedir autorización antes de gastar créditos.
- Cada cambio de código: prueba del sistema, `python3 tools/docs_index.py sync` + `check` y una entrada en
  `docs/technical-index/CHANGELOG.md`.
- No reducir los límites de giro para adaptarlos a las animaciones conectadas (pedido de la persona).
- No confundir animaciones inexistentes con animaciones existentes sin conectar (`MAPA_ANIMACIONES.md` §7).

## 6. Archivos externos (no versionados)

| Qué | Dónde estaba | Para qué |
|---|---|---|
| Banco de 2022 JSON | `animaciones_futbol5_JSON_limpios.zip`, o el paquete clasificado `animaciones_futbol5_conectadas_y_sin_conectar/` | reconvertir las librerías (`tools/json_anim/build_json_library.gd`, variable `JSON_SRC`) y regenerar el inventario |
| `animdb.adb` y los `.sat` de UCS | `paquete_recursos_analisis_movimiento/animaciones/`; el APK de UCS 1.810 (`assets/data/anims/`) | `DATOS_UCS.md` |
| `libMPX.so` | `lib/arm64-v8a/` de la división `config.arm64_v8a.apk` del APK de UCS | `PARAMETROS_UCS.md` |

## 7. Herramientas de esta documentación (`tools/transfer/`)

No tocan el juego. Sirven para regenerar todo cuando cambie el código:

| Herramienta | Salida |
|---|---|
| `dump_library_meta.tscn` / `.gd` (Godot headless, `OUT=…`) | metadatos de los 3223 clips de la librería |
| `make_inventory.py` | `INVENTARIO_ANIMACIONES.csv` |
| `adb_field_stats.py` | estadística de los campos de `animdb.adb` |
| `ucs_params_extract.py` (capstone) | `PARAMETROS_UCS.csv` |
| `make_params_doc.py` | tabla de `PARAMETROS_UCS.md` |
| `make_symbol_index.py` | anexo de `MAPA_CODIGO.md` |
| `check_references.py` | verifica que existan todos los archivos y `Clase.función` citados en esta carpeta |

## 8. Cómo verificar esta carpeta

```
python3 tools/transfer/check_references.py     # rutas y símbolos citados
python3 tools/docs_index.py check              # índice técnico del repositorio
tools/run_tests.sh                             # suite headless (no hizo falta en esta tarea: no se cambió código)
```
