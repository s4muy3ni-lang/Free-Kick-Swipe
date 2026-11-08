# Medir el rendimiento en el teléfono (Android)

Fecha: 2026-11-08. Para la APK que genera GitHub Actions (artefacto `futbol5-apk`). **Las mediciones de PC no valen como
mediciones de Android**: este documento explica cómo medir en el teléfono y dónde anotar los resultados. Hasta que no
haya un informe del teléfono, nada de este proyecto puede decirse «optimizado para Android».

## 1. Qué mide el juego

En penales o tiro libre, botón **«Diag.»** (arriba): se abren el panel del trazo y el medidor del juego
(`DiagnosticsOverlay`: FPS, tiempo de cuadro medio y pico, proceso, física, llamadas de dibujo, nodos, memoria, perfil).

En el panel, **«Medir rendimiento»** empieza una medición por momento de la jugada (`PerfSession`):

| Momento | Cuándo cuenta |
|---|---|
| `apuntando` | colocando la pelota, apuntando con el dedo o eligiendo dónde atajar |
| `carrera` | carrera del tirador hasta el golpe |
| `vuelo` | pelota en el aire |
| `red` | el segundo siguiente a que la pelota toca la red (la tela se deforma) |
| `estirada` | el arquero tirándose (o esperando el instante para tirarse) |
| `despeje` | pelota suelta: el arquero va a buscarla o un defensor la despeja |
| `festejo` | resultado en pantalla (festejos, lamentos, cámara del festejo) |

Por momento registra: cuadros, tiempo de cuadro medio, p95 y pico, tiempo de proceso y de física, llamadas de dibujo,
primitivas, tiempo de GPU (si el driver lo mide; en GL Compatibility muchos teléfonos no lo dan: el informe dice «no
medido») y el costo de cada sistema en ms por paso de física: red de tela, arco, pelota, plan del arquero, contacto del
arquero, pelota suelta, predicción del resultado. Una vez por informe: dispositivo, núcleos, GPU, memoria estática y de
video, nodos, cantidad de `AnimationPlayer`, perfil gráfico y tope de imágenes por segundo.

## 2. Procedimiento (5 minutos)

1. Instalar la APK de la última corrida verde de GitHub Actions (artefacto `futbol5-apk`).
2. Menú: dejar **Gráficos: Auto** (anotar qué perfil elige entre paréntesis).
3. **Penales:** entrar, tocar «Diag.», tocar «Medir rendimiento». Patear 3 penales (uno al ángulo para que toque la red,
   uno que ataje el arquero) y atajar 2. Tocar «Terminar medición» y luego **«Copiar informe»**. Pegar el texto en el chat.
4. **Tiro libre:** lo mismo con 3 tiros (uno que pegue en la barrera, para el despeje).
5. Repetir el paso 3 con **Gráficos: Bajo** y con **Gráficos: Alto** (para ver si el cuello de botella es la GPU: si al
   bajar la resolución 3D mejora mucho, es GPU; si no cambia, es CPU).

El informe también queda guardado en el teléfono (`user://perf_<fecha>.txt`, carpeta de datos de la app).

## 3. Cómo leer el informe

- **Tiempo de cuadro medio** ≤ 16,7 ms = 60 img/s; ≤ 33 ms = 30 img/s. El **p95** dice si hay tirones.
- **Física alta** (> 8 ms) con GPU baja → CPU: mirar los sistemas (red de tela, arquero, pelota suelta).
- **Medio alto que baja con el perfil Bajo** → GPU (resolución 3D, sombras, transparencias de la red y del público).
- **Memoria**: los bancos de animación cargados pesan ~39 MB en disco (`json_clips.res` 25 MB, `json_keeper.res` 6,6 MB,
  `json_scenes.res` 7,4 MB); si la memoria es el problema, aplicar la carga por prioridad (`docs/AAA_ROADMAP.md`, §7).

## 4. Comparación PC / Android

| Medida | PC (medido) | Android (pendiente) |
|---|---|---|
| Ver `docs/AAA_ROADMAP.md`, «Segunda entrega», tabla de rendimiento | PC Linux, render por software (llvmpipe): sirve para el costo de CPU de cada sistema, no para la GPU | **sin datos todavía** |

## 5. Optimizaciones previstas según el cuello de botella (no aplicadas sin datos)

- **CPU:** la red de tela simula solo con la pelota cerca (ya); bajar `ClothNet.ITERATIONS` 3 → 2 solo si su costo pasa
  de ~1,5 ms en el teléfono; jugadores del banco con animación a menor frecuencia fuera de cámara; predicciones del
  arquero cada 0,1 s (ya).
- **GPU:** perfil gráfico (resolución 3D, sombras, MSAA); el público de las tribunas es un sombreador (sin geometría por
  persona); transparencias de la red.
- **Memoria:** carga por prioridad de los bancos de animación.
- **La física y la jugabilidad no cambian con el perfil** (prueba `test_graphics_profiles_do_not_change_the_physics`).
