# PERFORMANCE — Perfiles gráficos y diagnóstico

## Identificación

- **Responsabilidad exacta:** controlar el coste de renderizado según el dispositivo (escala 3D, MSAA, sombras, elementos ambientales) y mostrar en pantalla lo que **realmente se mide** (FPS, tiempos de fotograma/proceso/física, llamadas de dibujo, nodos, memoria, errores).
- **Estado:** implementado a nivel de código. **No hay ninguna medición en un dispositivo Android real**: los valores por perfil son heurísticos y no están validados contra FPS reales.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-11
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/diagnostics/graphics_settings.gd` | Autoload `GraphicsSettings`: perfiles, detección inicial, aplicación y persistencia (`user://graphics.cfg`) | `GraphicsSettings.PROFILES`, `GraphicsSettings.apply`, `GraphicsSettings.set_profile`, `GraphicsSettings.detect_default_profile` | `Viewport`, `RenderingServer`, grupo `sun_light` |
| `scripts/diagnostics/diagnostics_overlay.gd` | `DiagnosticsOverlay` (`Label`): informe cada 0.4 s y `Logger` propio que cuenta errores/avisos del motor | `DiagnosticsOverlay.build_report`, `DiagnosticsOverlay.frame_stats` | `Performance`, `OS.add_logger` |
| `scripts/pitch/pitch.gd` | Crea `Sun` (grupo `sun_light`), el entorno y los elementos ambientales (bancos, gradas, torres de luz) | `Pitch._build_lighting`, `Pitch._build_ambient` | `GraphicsSettings` |
| `project.godot` | Renderer `gl_compatibility` (también para móvil), MSAA 0, atlas de sombra direccional 2048, compresión de texturas ETC2/ASTC, física 60 Hz, como mucho 3 pasos de física por imagen | `[rendering]`, `[physics]` | — |
| `scripts/diagnostics/prof.gd` | `Prof`: costo de CPU por sistema (µs por etiqueta) mientras `enabled`; apagado cada llamada es una comprobación | `Prof.begin`, `Prof.end`, `Prof.reset`, `Prof.acc`, `Prof.frame` | `Time` |
| `tools/perf_probe.gd` / `.tscn` | Herramienta: partido IA contra IA headless, tiempo real de cada imagen, costo por sistema, imágenes lentas con su desglose y los sucesos del partido | `PERF_SECONDS`, `PERF_ABLATE=anim`, `PERF_ANIM_MANUAL=1` | `MatchScene`, `Prof` |

## Mapa de parámetros

### Perfiles (`GraphicsSettings.PROFILES`, valores exactos del código)

<!-- AUTO:constdef:scripts/diagnostics/graphics_settings.gd#PROFILES -->
`scripts/diagnostics/graphics_settings.gd:19`

```gdscript
const PROFILES: Dictionary = {
	Profile.VERY_LOW: {
		"scale_3d": 0.5, "msaa": Viewport.MSAA_DISABLED, "shadows": false,
		"shadow_size": 1024, "ambient_props": false, "target_fps": 60,
	},
	Profile.LOW: {
		"scale_3d": 0.6, "msaa": Viewport.MSAA_DISABLED, "shadows": false,
		"shadow_size": 1024, "ambient_props": true, "target_fps": 60,
	},
	Profile.MEDIUM: {
		"scale_3d": 0.72, "msaa": Viewport.MSAA_DISABLED, "shadows": true,
		"shadow_size": 1024, "ambient_props": true, "target_fps": 60,
	},
	Profile.HIGH: {
		"scale_3d": 0.9, "msaa": Viewport.MSAA_2X, "shadows": true,
		"shadow_size": 2048, "ambient_props": true, "target_fps": 60,
	},
}
```
<!-- /AUTO -->

| Perfil | Quién lo elige |
|---|---|
| Valor por defecto | `detect_default_profile`: en `android`/`ios` según núcleos (`≤ 4` → Muy bajo, `≤ 6` → Bajo, resto → Medio); en escritorio, Alto. Solo si no hay `user://graphics.cfg`. |
| Cambio manual | Menú de pausa → «Gráficos» (cicla los 4 perfiles y guarda). |

**60 imágenes por segundo (2026-11-05):** escalas 3D más bajas (muy bajo 0.5, bajo 0.6, medio 0.72, alto 0.9), todos
los perfiles con `target_fps` 60 y en el teléfono `Engine.max_fps` = 60 (en PC y en las pruebas, sin tope: el tope
cambiaba el reparto de imágenes por paso de física de la red de tela en las pruebas headless). El teléfono arranca en
**Bajo** salvo con ≤ 4 núcleos (Muy bajo). Botón **«Resolución: 100/85/70/55 %»** en la pausa
(`GraphicsSettings.cycle_resolution`, `RESOLUTION_STEPS`) que multiplica la escala del perfil. **No medido en un
teléfono real** (no hay dispositivo en el entorno).

### Riesgos al modificar

| Elemento | Efecto real y riesgo |
|---|---|
| `scale_3d` × `resolution_override` | `root.scaling_3d_scale = clamp(scale_3d · override, 0.4, 1.0)`. Principal palanca de coste en GPU móvil. `resolution_override` no tiene interfaz (solo `set_resolution_override`, sin llamadores). |
| `msaa` | Solo `HIGH` usa 2×. |
| `shadows` / `shadow_size` | Se aplican al grupo `sun_light` y al atlas direccional. Con sombras apagadas el jugador no proyecta sombra. |
| `ambient_props` | Se evalúa **al construir la cancha** (`Pitch._build_ambient`); cambiar el perfil en la pausa **no** muestra/oculta las gradas hasta el siguiente arranque. |
| `target_fps` / `fps_cap` | En el teléfono `Engine.max_fps = min(target_fps, fps_cap)` (60, o 30 con el botón «Imágenes por segundo»); en PC y en las pruebas, 0 (sin tope). |
| `shadows_mode` | Botón «Sombras»: −1 = las del perfil, 0 = no, 1 = sí (`shadows_enabled`). |
| `max_physics_steps_per_frame=3` | Una imagen lenta recupera como mucho 3 pasos de física: el juego se frena un instante en vez de encadenar imágenes cada vez más lentas (con el valor por defecto, 8, un tirón de 100 ms pedía 6 pasos en la imagen siguiente). |
| Física a 60 Hz (`physics_ticks_per_second`) | Los parámetros de la pelota (`Ball`, Jolt) están ajustados a 60 Hz; cambiarlo exige revisar [BALL](BALL.md). |

## Mapa de funciones

<!-- AUTO:funcs:scripts/diagnostics/graphics_settings.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `GraphicsSettings._ready()` | 67 |  |
| `GraphicsSettings._process(delta: float)` | 75 |  |
| `GraphicsSettings.menu_choice_name()` | 97 | Opciones del boton «Graficos» del menu: automatico y los perfiles fijos. |
| `GraphicsSettings.cycle_menu_choice()` | 101 | Automatico -> Muy bajo -> Bajo -> Medio -> Alto -> Automatico. |
| `GraphicsSettings.toggle_aim_line()` | 115 | Interruptor de la linea de destino (se guarda). |
| `GraphicsSettings.cycle_camera_shake()` | 120 | No -> Suave -> Normal -> No (se guarda). |
| `GraphicsSettings.shake_scale()` | 125 | Multiplicador del temblor de camara (0 = apagado). |
| `GraphicsSettings.detect_default_profile()` | 129 | Heuristica de perfil inicial segun la plataforma y el hardware. No sustituye a medir. |
| `GraphicsSettings.set_profile(new_profile: int)` | 138 |  |
| `GraphicsSettings.cycle_resolution()` | 146 | Pasa al siguiente escalon de RESOLUTION_STEPS (boton «Resolucion» del menu de pausa). |
| `GraphicsSettings.set_resolution_override(value: float)` | 153 |  |
| `GraphicsSettings.get_params()` | 158 |  |
| `GraphicsSettings.profile_name()` | 161 |  |
| `GraphicsSettings.shadows_enabled()` | 164 |  |
| `GraphicsSettings.cycle_fps_cap()` | 168 | Pasa al siguiente tope de FPS_CAPS. |
| `GraphicsSettings.cycle_shadows()` | 174 | Sombras: las del perfil -> no -> si -> las del perfil. |
| `GraphicsSettings.ambient_props_enabled()` | 179 |  |
| `GraphicsSettings.apply()` | 183 | Aplica el perfil al viewport principal y a las luces registradas en el grupo "sun_light". |
| `GraphicsSettings.save_settings()` | 197 |  |
| `GraphicsSettings.load_settings()` | 210 |  |
| `GraphicsSettings._has_saved_settings()` | 228 |  |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/diagnostics/graphics_settings.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `GraphicsSettings.profile_changed(profile: int)` | 5 | Autoload "GraphicsSettings": perfiles graficos (muy bajo, bajo, medio, alto) y persistencia. Los perfiles controlan resolucion 3D, MSAA, sombras y detalle de redes/ambiente. |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/diagnostics/diagnostics_overlay.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `DiagnosticsOverlay.CaptureLogger._log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace])` | 15 |  |
| `DiagnosticsOverlay.CaptureLogger.snapshot()` | 28 |  |
| `DiagnosticsOverlay._ready()` | 39 |  |
| `DiagnosticsOverlay._process(delta: float)` | 59 |  |
| `DiagnosticsOverlay._prof_report()` | 83 | Los sistemas que mas tardaron desde el ultimo informe (ms por paso de fisica) y se empieza de nuevo. |
| `DiagnosticsOverlay.build_report()` | 94 |  |
| `DiagnosticsOverlay.frame_stats()` | 117 | Estadisticas de fotograma para informes de rendimiento (usado por la herramienta de benchmark). |
<!-- /AUTO -->

## Recorrido de ejecución

1. Arranque: `GraphicsSettings._ready` → carga `user://graphics.cfg` (o `detect_default_profile`) → `apply()`.
2. `MatchScene._ready` vuelve a llamar `GraphicsSettings.apply()` tras crear la cancha; `Pitch._build_lighting` también lo llama si está en el árbol.
3. `Hud` crea `DiagnosticsOverlay`; se muestra si `Tuning.show_diagnostics` (menú de pausa → «Diagnóstico», persistido en `user://settings.cfg`).
4. El informe incluye: FPS y ms (media y pico de los últimos 120 fotogramas), `TIME_PROCESS`/`TIME_PHYSICS_PROCESS`, llamadas y primitivas de dibujo, nodos, memoria estática, perfil, resolución 3D, y errores/avisos capturados con el `Logger` (últimos 3 mensajes).

## Pruebas

- **Ejecutar:** no hay pruebas de los perfiles. Costo de CPU por sistema: `PERF_SECONDS=90 godot --headless --fixed-fps 60 --path . res://tools/perf_probe.tscn` (tras `godot --headless --path . --import` si hay clases nuevas; usar `--log-file` para ver errores: con un error de script la escena no termina nunca).
- **Alcance real:** `grep -rn GraphicsSettings tests` no encuentra nada. Ni los perfiles, ni la persistencia, ni el informe del diagnóstico están cubiertos. Lo único medido es el coste de la simulación en las pruebas (la suite completa corre en ~10 s headless), que **no** es una medición de rendimiento gráfico.
- **Qué podría romperse:** `OS.add_logger` solo existe en versiones recientes de Godot (usado con 4.7.2); un perfil con clave faltante rompe `get_params()["…"]`.

## Limitaciones conocidas (pendientes)

- **Sin mediciones en Android:** no hay números de FPS reales en ningún dispositivo ni en el emulador. El objetivo de gama baja (30 FPS en perfil Muy bajo) es una intención, no un resultado.
- `DiagnosticsOverlay.frame_stats` (media, p95, máximo) está pensada para una herramienta de benchmark que **no existe**; `GraphicsSettings.profile_changed`, `shadows_enabled` y `set_resolution_override` no tienen consumidores.
- Sin pool de objetos, LOD ni oclusión: la cancha son pocas mallas, pero la cantidad de nodos y llamadas de dibujo no se ha perfilado.
- El jugador usa 7640 triángulos (límite impuesto por la prueba: 10 000); con 10 jugadores el presupuesto de geometría no se ha medido.

## Tirones de CPU y opciones de rendimiento (2026-11-05)

**Diagnóstico.** En el video del usuario (05-11 04:42:20) el partido iba a ~23 imágenes por segundo con la gráfica al
mínimo y resolución 3D al 50 %, con congelamientos de hasta 5 imágenes: el cuello de botella es la CPU, no la GPU. La
herramienta nueva `tools/perf_probe.tscn` (partido IA contra IA headless, `Prof` en cada sistema) lo mostró en el
contenedor (4 núcleos x86, bastante más rápido que un teléfono):

| Sistema | Antes (peor imagen) | Causa |
|---|---|---|
| `JsonReceive.consider` (recepción con clip) | 10-60 ms en una imagen, cada 2 pasos, en cada jugador al que le llega la pelota | por cada clip de recepción (189) buscaba perfil y meta y copiaba el perfil de los espejos en **cada** plan; la primera vez que se usaba un clip calculaba su pose (115 ms los 189) |
| `KeeperPlanner.plan_save` (arquero) | 25 ms de media por llamada en un partido de 40 s, picos de 41-47 ms; ~2 llamadas cada 0.08 s mientras llega un tiro | búsqueda exhaustiva clip × velocidad × muestra de manos × tramo de la trayectoria |
| `estimated_kick_dir` / `plan_clip_kick` (IA preparando un pase) | 8-20 ms en algunas imágenes | ayuda de pase/tiro y planificación del golpeo en cada imagen de la espera |
| `FootballerVisual.drive_motion` | 0.05-0.07 ms por jugador y paso | 6-9 parámetros del `AnimationTree` escritos por texto en cada imagen |

**Arreglos (mismo resultado, menos trabajo).**

- `JsonReceive`: candidatos con todo lo fijo precalculado (`warm_cache`, al cargar el partido, 51 ms), en el mismo orden
  (el desempate aleatorio del puntaje consume el generador igual), cota del alcance de todos los clips: si la pelota no
  pasa cerca en la ventana de contacto no se recorre ninguno; pose del clip con el hueso de cada pista ya resuelto; los
  motivos de descarte solo se guardan para la vista de depuración (`record_rejects`). Verificado: la salida de las 34
  pruebas de *test_receive (eliminada en la reforma)* (clips elegidos, contactos) es idéntica con el código anterior y el nuevo (la única línea
  distinta, un partido IA contra arquero, también cambia entre dos corridas del mismo código).
- `KeeperPlanner`: datos fijos de cada candidato en caché (`warm_cache`), tramos de la trayectoria y muestras de manos
  en grupos con su caja (se salta un grupo entero si no puede dar nada), cota inferior del puntaje cuando ya hay una
  atajada válida, comparaciones de caja sin `maxf` anidados. Verificado con **116 llamadas reales grabadas en partidos**
  (herramienta temporal): las 116 dan exactamente el mismo plan; media 2.9-4.7 → 1.5-1.8 ms, peor 26-47 → 16-20 ms.
- Golpeo: carrera de entrada y bandera `mocap` de cada candidato en la caché de `JsonCatalog.kick_candidates` (antes,
  una búsqueda de meta por candidato en cada plan).
- `FootballerVisual._set_param`: nombres ya convertidos (`P_LOCO`, …) y escritura solo si el valor cambió.

**Resultado (partido IA de 90 s, dos corridas de cada versión, misma herramienta):**

| | Antes (`0baf375`) | Después |
|---|---|---|
| Imágenes de más de 12 ms | 108 y 118 | 14 y 14 |
| Peor imagen | 87 y 42 ms | 24 y 18 ms |
| p95 | 8.4 y 8.9 ms | 7.4 y 6.8 ms |
| Media | 3.8 y 4.3 ms | 4.1 y 4.1 ms |

El costo medio no bajó: el lag sostenido en un teléfono lento depende de la suma de los ~8 jugadores (≈0.33 ms cada uno
por paso en el contenedor) y de dibujar; lo que bajó son los **tirones**. Sin medición en un teléfono.

**Opciones nuevas en la pausa** (persistidas en `user://graphics.cfg`): «Imágenes por segundo: 60 / 30 (estables)»
(`GraphicsSettings.cycle_fps_cap`), «Sombras: según gráficos / no / sí» (`cycle_shadows`), además de «Gráficos» y
«Resolución». La grilla del menú se desplaza con el dedo (ya no cabía en 720 de alto). **«Diagnóstico» muestra ahora el
costo de cada sistema en el teléfono** (ms por paso de física, los 7 más caros, con `Prof`): sirve para saber qué pesa en
el dispositivo real.

**Pendiente:** picos de la IA al preparar pases (`estimated_kick_dir` hasta 13 ms), el peor caso del arquero (16-20 ms en
tiros que no puede alcanzar: no hay atajada válida que acote la búsqueda), imágenes de 50-85 ms ocasionales con el árbol
en pausa (cerca de las repeticiones de gol; no instrumentadas), y bajar el costo medio de los jugadores.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Partido jugable».

## Medición del 2026-10-31 (programa maestro, modo 4)

Partido 4+1 contra 4+1 con IA, 60 s (3 600 pasos) headless en el contenedor de desarrollo (4 núcleos), con una prueba
temporal: media 3.1 ms por paso, p99 16.7 ms, 35 pasos por encima de 16.7 ms. Los picos coinciden con la planificación del
arquero durante un disparo (20-56 ms) y con acciones de giro, balón parado y movimiento con pelota (17-30 ms).
`KeeperPlanner.plan_save` bajó de 42 a 11 ms por llamada (ver GOALKEEPER). `BallPredictor.trajectory` (2 s, paso 1/30, con
giro): 0.2 ms. Sin medición en Android (la CPU de un teléfono es más lenta: los picos serían mayores).

