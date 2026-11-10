# AUDIO — Efectos de sonido del partido

## Identificación

- **Responsabilidad exacta:** los sonidos del partido. Golpes a la pelota (toque de conducción, pase, tiro, guantes del
  arquero) con la fuerza del impulso real, botes, poste, red, silbatos, festejo del gol, «ooh» de la tribuna y un
  murmullo de público en bucle. Todos los efectos se **sintetizan** con `tools/audio/make_sfx.py` (sin muestras de
  terceros) y se reproducen sin posición 3D (en el móvil no aporta).
- **Estado:** implementado desde el 2026-10-29 (prueba03: el juego no tenía ningún sonido). Interruptor «Sonido: Sí/No»
  en el menú de pausa (`Tuning.sound_on` → `Sfx.set_enabled`, se guarda).
- **Última verificación:** <!-- AUTO:verified -->
2026-11-10
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/audio/sfx.gd` | Autoload `Sfx` (`Node`, registrado en `project.godot`): carga los WAV, grupo de `VOICES` reproductores, público en bucle, conexión a la pelota y a los eventos del partido | `Sfx.play`, `Sfx.crowd`, `Sfx.watch_ball`, `Sfx.impulse_sound`, `Sfx.on_event` | `Ball` (señales), `GameEvent`, `Goalkeeper` |
| `tools/audio/make_sfx.py` | Síntesis determinista (numpy, semilla fija) de los 12 efectos: WAV mono de 16 bits a 22 050 Hz | `kick`, `touch`, `bounce`, `post`, `net`, `whistle`, `glove`, `crowd_loop`, `cheer`, `ooh` | numpy |
| `assets/audio/*.wav` | Los efectos generados (~0.8 MB en total) | — | — |
| `scripts/ball/ball.gd` | Señales `impulse(actor, dv, speed)` (cada `Ball.kick`) y `net_hit(speed)` (entra en la red) | `Ball.kick`, `Ball._integrate_forces` | — |
| `scripts/gameplay/match_scene.gd` | Conecta `Sfx` a la pelota y a `event_emitted`, enciende el público y lo apaga al salir | `MatchScene._ready`, `MatchScene._exit_tree` | `Sfx` |

## Mapa de constantes

<!-- AUTO:consts:scripts/audio/sfx.gd -->
| Constante / enum / uniform | Valor | Línea | Descripción |
|---|---|---|---|
| `Sfx.SOUNDS` | `[&"kick_hard", &"kick_soft", &"touch", &"bounce", &"post", &"net", &"whistle_...` | 7 | Autoload "Sfx": efectos de sonido del partido (sintetizados por tools/audio/make_sfx.py, en assets/audio/). Un grupo de reproductores sin posicion (en el movil el sonido 3D no aporta) y un ambiente de publico en bucle. Lo conecta MatchScene a la pelota y a los eventos del partido: los golpes (tambien los del arquero) suenan con la fuerza del impulso real (Ball.impulse), el poste, la red y los botes con su velocidad. |
| `Sfx.VOICES` | `10` | 9 |  |
| `Sfx.CROWD_DB_MIN` | `-38.0` | 58 | Intensidad del publico (0 silencio .. 1 estallido): el bucle sube y baja suave hacia ella (CROWD_DB_MIN..MAX). |
| `Sfx.CROWD_DB_MAX` | `-9.0` | 59 |  |
| `Sfx.CROWD_FADE_DB_S` | `18.0` | 60 |  |
<!-- /AUTO -->

## Mapa de funciones

<!-- AUTO:funcs:scripts/audio/sfx.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Sfx._ready()` | 21 |  |
| `Sfx.play(name: StringName, volume: float = 1.0, pitch: float = 1.0)` | 43 | Reproduce un efecto. volume: 0..1 (escala lineal), pitch: tono (1 = original). |
| `Sfx.set_crowd_level(level: float)` | 63 |  |
| `Sfx.crowd_db(level: float)` | 66 |  |
| `Sfx._process(delta: float)` | 69 |  |
| `Sfx.crowd(on: bool)` | 74 | Ambiente de publico (bucle) mientras hay partido. |
| `Sfx.set_enabled(on: bool)` | 84 | Enciende o apaga todo el sonido (el publico vuelve si hay partido). |
| `Sfx.watch_ball(ball: Ball)` | 94 | Conecta los sonidos de la pelota (golpes, botes, poste, red). |
| `Sfx._on_impulse(actor: Node, dv: float, speed: float)` | 104 | Golpe a la pelota: toque de conduccion, pase o tiro segun el cambio de velocidad (m/s) que le dio el impulso. |
| `Sfx.is_keeper(actor: Node)` | 111 | El que toco la pelota es un arquero: el del partido (Goalkeeper) o el de penales y tiros libres (SpActor con rol «keeper»; antes sus atajada |
| `Sfx.impulse_sound(keeper: bool, dv: float, speed: float)` | 116 | Sonido de un golpe: [nombre, volumen, tono] o [] si no suena (un apoyo de la suela, un roce). Guantes del arquero; toque de conduccion (camb |
| `Sfx._on_bounce(_pos: Vector3, speed: float)` | 127 |  |
| `Sfx._on_post(_pos: Vector3, speed: float)` | 131 |  |
| `Sfx._on_net(speed: float)` | 136 |  |
| `Sfx.on_event(e: GameEvent)` | 140 | Sonidos de los eventos del partido: silbatos, festejo del gol, atajadas. |
<!-- /AUTO -->

## Recorrido de ejecución

1. Arranque: el autoload carga `assets/audio/<nombre>.wav` de cada `SOUNDS`, crea `VOICES` reproductores y una copia
   de `crowd_loop.wav` con `LOOP_FORWARD` a −20 dB.
2. `MatchScene._ready` → `Sfx.watch_ball(ball)` (golpes, botes, poste, red), `ctx.event_emitted.connect(Sfx.on_event)`
   (silbatos, festejo, atajadas) y `Sfx.crowd(true)`; `_exit_tree` → `Sfx.crowd(false)`.
3. Cada `Ball.kick` emite `impulse`: `impulse_sound` elige guantes (arquero), nada (cambio < 0.6 m/s: apoyo de la suela),
   toque (< 4.5 m/s), golpe suave (sale a < 15 m/s) o golpe fuerte (volumen con la velocidad, hasta 1.3); tono ±6 %.
4. `play`: no repite el mismo sonido dentro de 30 ms; volumen lineal → dB; reproductores en rueda.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh audio` (`tests/test_audio.gd`): los 11 efectos existen y se cargan, el público está
  en bucle, cada golpe elige su sonido por el impulso real y `Ball.kick` emite `impulse`.
- **Alcance real:** en headless el servidor de audio es nulo: se prueba la elección y la carga, **no lo que se oye**.
  Volumen y mezcla se revisan en el teléfono.

## Riesgos al modificar

| Elemento | Efecto real y riesgo |
|---|---|
| Umbrales de `impulse_sound` (0.6 / 4.5 / 15 m/s) | Toques de conducción frecuentes (2–4 por segundo): si suenan como golpes, el partido se vuelve ruidoso. |
| `VOICES` (10) | Con menos, un tiro puede cortar el sonido del poste o del festejo. |
| Volumen del público (−20 dB) | Más alto tapa los golpes en el altavoz del móvil. |
| `make_sfx.py` | Es determinista: volver a generar da los mismos archivos; cambiar la semilla cambia todos los sonidos. |

## Limitaciones conocidas

- Sin control de volumen (solo encendido/apagado); sin música; sin voces de jugadores ni relator. La sala de práctica no
  tiene sonido (solo el partido conecta `Sfx`).
- Los efectos son sintéticos (no grabaciones): aproximados.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Giro con toques, tiro con potencia y sonido» (2026-10-29).
