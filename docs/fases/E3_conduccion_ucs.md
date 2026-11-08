# E3 — Conducción como UCS: qué hay en los datos de UCS, qué faltaba conectar y qué cambió (2026-11-05)

Pedido (con el video `Screenrecorder-20261105-145139.mp4` de UCS y el paquete `paquete_recursos_analisis_movimiento`):
analizar la conducción cuadro por cuadro, entender por qué la nuestra no sale como la de UCS («el pie izquierdo toca para
doblar hacia la derecha; si voy a doblar a la izquierda, el pie derecho orienta la pelota… o con el exterior del pie»,
«en diagonal va dando toquecitos cada vez más a la izquierda», «hay animaciones que no están conectadas»), mirar el APK de
UCS, y achicar los pies y botines a las proporciones de UCS.

## 1. Dónde está y cómo lo encontré: `animdb.adb`

**Archivo:** `assets/data/anims/animdb.adb` del APK de Ultimate Clash 1.810 (el paquete lo trae en
`paquete_recursos_analisis_movimiento/animaciones/animdb.adb`, 865 188 bytes). No se modificó el APK ni se ejecutó el juego.

**Cómo:**

1. Cabecera: un entero de 32 bits = 4066 (la cantidad de animaciones de `anims.pak`, contando los espejos).
2. Después vienen 4066 registros fijos de **104 bytes** (52 enteros de 16 bits) y una cola de 442 320 bytes con datos por
   clip (claves de tiempo y trayectorias; no hizo falta descifrarla).
3. El orden de los registros es el de los `.sat` de `anims.pak` y el de los archivos JSON de nuestro banco (el número
   `NNNN_` de cada archivo). Comprobación: el campo 2 de cada registro es la cantidad de cuadros del clip y coincide con
   `frames` de **los 2022 de 2022** JSON. El registro `2k+1` es el espejo del `2k`: los campos laterales cambian de signo.
4. Cada campo se identificó comparándolo con los datos de nuestro banco: cantidad de cuadros, toques de pie medidos en el
   JSON, giro del cuerpo (`yaw_end`), velocidades `v_in`/`v_out` y posición de la punta del pie en cada toque.

**Qué guarda cada registro** (lo que importa para la conducción; tabla completa de los 78 clips de conducción en
[`E3_conduccion_ucs_animdb.csv`](E3_conduccion_ucs_animdb.csv)):

| campo (int16) | qué es | cómo se comprobó |
|---|---|---|
| 2 | cuadros del clip (60 por segundo) | igual a `frames` en 2022/2022 |
| 3 | **cuadro del toque de pelota** | cae en el toque de pie medido en el JSON (±1-3 cuadros) en los clips de conducción |
| 4 | **pie del toque**: bit 128 = izquierdo, bit 256 = derecho | coincide con el pie del toque del JSON en ese cuadro; se intercambia en el espejo |
| 5, 6 | velocidad de entrada y de salida (×10, unidades de UCS) | correlación 0.57 / 0.55 con `v_in` / `v_out` |
| 7, 8 | **ventana del joystick** en la que se elige el clip (grados respecto del frente, en pasos de 11.25°: 32 sectores) | avance: -67.5…+67.5; diagonales «45»: p. ej. -112.5…+22.5 |
| 9 | giro del clip redondeado al sector (grados; + = izquierda en nuestros datos) | 0, ±11, ±22, ±45, ±56, ±90, ±112, ±135, ±157… |
| 47 | giro medido del clip | correlación 0.71 con `yaw_end` del JSON |
| 25, 26, 27 | **destino de la pelota** (milímetros, en el marco del inicio del clip: -25 = adelante, 27 = lateral) | en las conducciones de avance cae junto a la punta del pie del toque siguiente (≈2.2-3.8 m adelante) |
| 28-39 | otros tres puntos con la misma forma (¿segundo y tercer toque?) | no confirmado |

Los nombres de parámetros que el informe del paquete encontró en `libMPX.so` (`BallFrame`, `BallDestination`,
`BallNumberOfFrames`, `AnimStartFramePC`) encajan con estos campos. Pero **no se vio el código que los lee**: el binario está
despojado y no se descompiló. Lo que sí está claro en los datos es que UCS elige el clip por la dirección del joystick
(ventana de 32 sectores). En el cuadro del toque, el pie indicado manda la pelota a un destino guardado.

## 2. El video, cuadro por cuadro

Se extrajeron los 2099 cuadros (video de 90 s, ~23 cuadros por segundo variables) y se revisaron todos en hojas de
contacto. Las notas de cada tramo están en [`E3_video_conduccion_notas.md`](E3_video_conduccion_notas.md). Gran parte del
video son pases y tiros apuntados (línea punteada); los tramos de conducción con giro están en los cuadros 277, 558, 787,
900, 1149, 1361, 1414, 1526, 1575 y 1600. Se ampliaron x1.7: [`E3_giros_ucs_ampliados.jpg`](E3_giros_ucs_ampliados.jpg)
y [`E3_giro_derecha_pie_izquierdo_ucs.jpg`](E3_giro_derecha_pie_izquierdo_ucs.jpg).

- **El giro lo da un solo toque, en el momento de girar.** El cuerpo rota en 4-6 cuadros (0.2-0.25 s), inclinado hacia
  adentro.
- **Con la pelota al centro: interior del pie de afuera.** Cuadros 786-794: dobla a su derecha con el izquierdo.
  Cuadros 1413-1421: dobla a su izquierda con el derecho. Cuadros 1525-1533: dobla a su derecha con el izquierdo.
- **Con la pelota ya del lado del giro: exterior del pie de ese lado.** Cuadros 558-566 y 1360-1368: a la derecha con el
  exterior del derecho. Cuadros 899-907: a la izquierda con el exterior del izquierdo, con toques seguidos cada vez más
  a la izquierda (la diagonal progresiva).
- **Cadencia:** al trote, un toque cada 6-9 cuadros (0.26-0.39 s); en sprint, cada ~10 (0.43 s). La pelota va 0.5-1.0 m
  por delante.

Los datos de UCS tienen las dos técnicas. En los clips de giro, el toque del medio lo da casi siempre el pie del lado del
giro (exterior). Hay clips con el pie de afuera (interior), por ejemplo el `JOG_DRIBBLE_45_08`, `45_10`, `45_04`,
`SPRINT_DRIBBLE_FORWARD_02/04` y `JOG_DRIBBLE_45_09` (y sus espejos).

## 3. Qué faltaba conectar en nuestro juego

Todos los clips de conducción de UCS están en nuestro banco (78 de 78; ninguno es inexistente). Lo que fallaba era cuándo
se usaban:

| clips | antes | ahora |
|---|---|---|
| avance con giro chico (`JOG/SPRINT_DRIBBLE_FORWARD_*`, `DRIBBLE`, `CONTROL_DRIBBLE_00-08`, `EX2013/EX2018`; giros de ±2° a ±22°) | solo con el botón REGATE (`ball_skill`) | **toque orientado** con el joystick a 14-50° del frente |
| diagonales «45» y giros de 30-40° (`JOG_DRIBBLE_45_02…11`, `CONTROL_DRIBBLE_00/01 ANDY`) | solo con el joystick a ≥ 50° (`ball_turn`), y solo a velocidad parecida a la del clip | también en el toque orientado (cortados tras el toque que gira) |
| arranques (`STAND_TO_45_R…`, `DRIBBLE_00`) | `ball_start` (sin uso en la conducción) | toque orientado a baja velocidad (≥ 0.6 m/s) |

Antes, los cambios de rumbo de menos de 50° los daba el **toque de rumbo físico**: un impulso con el pie que estuviera más
cerca, con el ciclo de carrera de siempre. No había animación de giro ni se elegía el pie.

## 4. Qué cambió

**Toque orientado** (`JsonBallMove`, intención `steer`; solo el jugador que controla la persona; la IA sigue igual):

- Con el joystick a 14-50° del frente, en cada paso de física se busca en los clips de conducción de UCS (y sus espejos)
  uno que cumpla todo esto:
  - gira hacia el mismo lado (nunca al contrario);
  - su giro, hasta el toque que orienta, está a ≤ 24° del pedido;
  - su velocidad de entrada está a ≤ 1.6 m/s de la del jugador;
  - la pelota llega a la punta del pie de su primer toque (la misma planificación de los giros con pelota).
- Se prefiere (0.06 de puntaje) el clip cuyo toque que orienta lo da el **pie de afuera del giro**: el interior del
  izquierdo para doblar a la derecha y del derecho para la izquierda. Si la pelota está del lado del giro, gana el clip con
  el exterior del pie de ese lado, como en el video.
- El clip mueve y gira el cuerpo con su raíz y su rumbo, y da los toques con su pie en su instante. **Se corta tras el
  segundo toque** (0.12 s después): ese toque deja la pelota hacia el joystick, a la distancia de conducción. La marcha
  sigue con la velocidad del clip.
- Si el joystick sigue en diagonal, hay otro toque orientado 0.15 s después (curva progresiva). Si ningún clip encaja,
  queda el toque de rumbo físico de siempre.

**Botines** (`tools/json_anim/build_json_human.gd` → `assets/characters/json/json_human.scn`):

- Antes iban de 8.8 cm detrás a 24.8 cm delante del tobillo, ~0.40 m con las tapas: 1.8 veces la pelota. Sobresalían
  ~10 cm de la punta del pie del esqueleto (que es el de UCS, 15.8 cm delante del tobillo).
- Ahora van de 6 cm detrás a 18.3 cm delante, ~0.26 m: el 15 % de la talla de 1.74 m, como un pie real y como los
  jugadores de UCS.
- Antes y después: [`E3_botines_antes_despues.png`](E3_botines_antes_despues.png).
- El esqueleto ya tenía las medidas de UCS: nuestros JSON salen de sus mismas animaciones (hombros a 1.39 m, cadera a
  0.84 m, talla ~1.74 m). Las mallas de `models.pak` (`player_regular_new.ftm`, etc.) no se decodificaron.

## 5. Medido (play_view, render Xvfb, joystick 0.8, 8.5 s; antes = commit anterior)

| escena | antes: pelota-cuerpo mediana / p90 / máx (m) · clips | ahora |
|---|---|---|
| `steps` (cambios bruscos de 35°) | — (la escena es nueva) | 0.52-0.55 / 0.98-1.00 / 1.10 · 3 toques orientados + 1 giro (a los dos lados), error del pie ≤ 0.07 m, 0 cortes |
| `zigzag` | 0.53 / 0.92 / 1.21 · 2 giros | 0.51 / 0.90 / 1.14 · 4 toques orientados, error ≤ 0.13 m, 0 cortes |
| `diag` (±25° cada 1.5 s) | 0.45 / 0.52 / 0.61 · 0 clips | 0.48 / 0.96 / 1.31 · 2 toques orientados + 1 giro, 0 cortes |
| `curve` (el joystick gira 30°/s) | 0.45 / 0.54 / 0.62 | 0.45 / 0.54 / 0.61 · 0 clips: el cuerpo sigue al joystick y el ángulo no llega a 14° |

- Imagen del toque orientado en el juego: [`E3_toque_orientado_juego.jpg`](E3_toque_orientado_juego.jpg).
- En `diag` la pelota queda más adelante tras el toque (p90 0.96 m contra 0.52 m antes): está dentro de los 0.5-1.0 m de
  UCS.
- En la curva en sprint de 8.5 s la pelota «se escapaba» en las dos versiones. No es un fallo del juego: el jugador
  llegaba a la banda (z = 14.7 m) y la pelota salía o rebotaba en los carteles.

## 6. Qué no se verificó

- La sensación con el joystick real en el teléfono (eso lo prueba la persona con el APK).
- La IA no usa el toque orientado.
- No se descifraron la cola de `animdb.adb`, los campos 28-39 ni las mallas de `models.pak`.

## 7. Nuestro animdb y animaciones que faltaban conectar (segundo pedido, 2026-11-05)

Pedido: «conectá todas nuestras animaciones que tenemos desconectadas y fijate que tengamos un animdb, así tenemos todas
nuestras animaciones para cada acción».

**`assets/animations/animdb.json`** (generado por `tools/json_anim/make_animdb.py` con el `animdb.adb` de UCS, el
`index.json` del banco y el inventario E2) tiene:

- Una entrada por clip del banco (2022; indice `NNNN`) con nombre, cuadros y sus tramos. Cada tramo lleva id en la
  librería, acción, estado (si / no / pendiente), sistemas que lo usan y motivo.
- Los datos de UCS de cada clip: cuadro y pie del toque, destino de la pelota (m, adelante / izquierda), giro (sector y
  medido), ventana del joystick y velocidades.
- El índice `acciones`: para cada una de las 111 acciones, **todos** sus clips, conectados o no.

El juego lo lee con `AnimDB` (`scripts/animation/anim_db.gd`, con el lado de los espejos aplicado). El toque orientado
usa la **ventana del joystick de UCS** de cada clip: si el joystick no cae en la ventana en la que UCS elige ese clip, no
se usa. Se exporta en el APK (`include_filter` de `export_presets.cfg`).

**Conectados ahora** (estado en el animdb):

- Toque orientado: los clips de control con «dribble» en el nombre que siguen en carrera (lista en
  `tools/json_anim/steer_pool.json`).
- Arranque con pelota desde parado (`JsonBallMove`, intención `start`; jugador de la persona casi quieto, joystick ≥ 0.6
  a menos de 50°): los de conducción de UCS que entran casi quietos y el rol `ball_start` (antes sin sistema: «arranque de
  conducción, no recepción»). Los arranques de 50° o más ya los usaba el giro con pelota.

Los dos (toque orientado y arranque) son solo del jugador que lleva la persona **con su mando**. En las pruebas de
partidos de IA el control pasa al receptor con la entrada de la IA, y ahí sigue decidiendo la IA como antes. Con el
botón de sprint apretado, el arranque es el de siempre: los clips de arranque de UCS salen al trote y, en
`test_ball_turn::test_wide_turn_and_sprint`, dejaban la pelota lejos para el giro siguiente en sprint (falló en la suite
y se corrigió).

**Siguen sin conectar** (motivo en el animdb):

- 139 de presentación (túnel, himno, escenas): el juego no tiene presentación previa.
- 111 de personajes fuera de la cancha (público, bancos, técnicos): el entorno no tiene esos personajes con esqueleto.
- 25 recepciones sin contacto confirmado en la verificación visual.
- Variantes de marcha y de conducción: un ciclo por velocidad, medido.
- Giros del arquero.
- Giros sin pelota fuera de las franjas.
- Pelotas paradas en las que el pie no llega a la pelota.
- Saques de banda sin suelta.
- El sombrero (necesita la pelota en el aire).

## Corrección posterior (2026-11-06, documentación de transferencia)

Al comparar `animdb.adb` con los `.sat` del paquete, se vio que el **campo 3 no es el cuadro del toque**. Es igual al
byte 2 de la cabecera de su `.sat` en 1832/1832 archivos; la auditoría `00_auditoria_modo_json.md` lo relaciona con los
bloques de datos. La coincidencia con los toques de la conducción era aproximada (±1-3 cuadros en algunos clips).

- En los golpeos, el cuadro de contacto que mejor coincide con el nuestro es el **campo 24**: ±2 cuadros en 310 de
  447 [deducido].
- Los campos 5, 6, 40, 46, 47 y 49 cambian de significado según la familia.
- El juego no usa el campo 3, así que no cambia nada en la conducción. Solo es incorrecta la etiqueta `toque_cuadro`
  de `assets/animations/animdb.json`.

Detalle y pasos: [`docs/transferencia_integracion_completa/DATOS_UCS.md`](../transferencia_integracion_completa/DATOS_UCS.md)
y `PENDIENTES_INTEGRACION.md` §2.1.
