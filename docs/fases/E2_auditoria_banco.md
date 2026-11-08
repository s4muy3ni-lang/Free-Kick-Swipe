# E2 — Auditoría y reclasificación del banco completo de animaciones JSON

Herramienta: `tools/json_anim/analyze_bank.py <carpeta con los 2 022 JSON originales>`. No modifica los JSON originales:
lee los JSON, `selection.json`, `receive_profiles.gd` y el uso de roles en el código, y genera:

- `docs/fases/E2_inventario_banco.csv`: una fila por clip del juego (2 024 filas: los 2 022 archivos, dos de ellos
  partidos en dos clips). Columnas: archivo original, nombre, id del juego, clase anterior, clase nueva, función
  futbolística, útil (si / no / pendiente), sistema que lo usa, motivo, y las medidas cinemáticas en las que se basa la
  decisión (giro, v_in, v_out, toques, rodilla, punta del pie, pelvis inicial/mínima, tiempo en el aire, brazos arriba,
  inclinación, aplausos).
- `scripts/animation/clip_roles_overlay.gd` (`ClipRolesOverlay`): las reclasificaciones (`ROLE`) y los alias de nombres
  del pack que el código pide (`ALIAS`). `PackLibrary` los aplica al cargar el modo 4 (el rol de la meta del clip y su
  espejo se sustituyen; los alias solo se añaden si el nombre no existía). Las anotaciones quedan separadas de los JSON.

## Resultado

| útil | clips |
| --- | ---: |
| sí (integrado en un sistema del juego) | 1 682 |
| no (descartado con motivo) | 317 |
| pendiente (recepciones sin verificación visual, F3) | 25 |

Reclasificados: 67 clips (`ball_dribble → ball_skill` 32, `turn_stand/start/step_stand → turn_start` 31,
`turn_stop → turn_run` 2, `gk_idle → gk_idle_var` 2). Excluidos de su rol por medición en el juego: 7 clips de balón
parado (`setpiece_miss`, ver abajo).

Uso por sistema (clips útiles): arquero 254, golpeo 243, reacciones de gol 222, golpeo aéreo 149, movimiento con pelota
133, recepción 95, golpeo girando 92, giros sin pelota 85, caídas 82, balón parado 66, gestos de espera 102, locomoción 46,
entrada 36, presión 17, esquivar barrida 12, conducción 6, árbitro 2, transiciones de marcha 1.

### Criterios de reclasificación (medidos, no por nombre)

- Movimientos con pelota (`ball_dribble`) con toques medidos: `ball_turn` si el rumbo gira ≥ 40°, `ball_stop` si entra a
  más de 1 m/s y sale a menos de 0.6 m/s, si no `ball_skill` (regate). Así entraron 32 regates nuevos al botón de regate.
- Giros sin pelota (`turn_stand`, `step_stand`, `start`, `turn_stop`, `run_change`): `turn_start` (giro ≥ 40° desde
  parado, v_in < 1.3 m/s) o `turn_run` (giro en carrera, 2–5.6 m/s). Los que no entran en ninguna franja se descartan con
  el giro y la velocidad medidos en el motivo.
- `gk_idle` con movimiento propio → `gk_idle_var` (variantes de espera del arquero).

### Alias para nombres del pack que el código pedía y no existían en el modo 4

- `Idle_To_Sprint` → `jn_start_0494` (mejor arranque medido).
- `Running_Tired` → `jn_nis_idle_0954` (manos en la cintura mirando arriba: alternativa a la parada agotado).
- `Defender_2` → `jn_wall_0538` (salto de barrera).
- Sin equivalente en el banco (siguen sin clip y el árbitro los rechaza sin dejar nada tomado): `Sprint_Turn`,
  `Soccer_Spin` (la ruleta no existe en el banco; el botón de regate usa los `ball_skill`).
- Malabares: no hay clips en el banco; el botón se oculta en la práctica (`JuggleController.available()`).

### Descartes principales (motivo en cada fila)

- 139 secuencias de presentación (`nis_*`: túnel, himno, escenas): el juego no tiene escenas de presentación.
- 111 personajes fuera de la cancha (`crowd`, `mascot`, `manager`): el entorno se quitó del modo 4 por decisión del
  usuario.
- 11 giros del arquero (`gk_turn`): se orienta con su locomoción y su planificador de atajadas.
- Variantes de marcha y conducción (`loco_*`, `gk_loco`, `dribble_*`): la locomoción usa ciclos ya elegidos y medidos.
- 2 centros (`kick_cross`): golpeo no limpio, contacto a 0.59–0.68 m al costado del cuerpo.
- 7 clips de balón parado medidos en el juego (forzando cada clip del rol en un corner o un penal, 2 intentos): el
  pie de `jn_setpiece_pass_3330`, `3342`, `3346` y `jn_setpiece_shot_3354`, `3856` nunca llega a la pelota (los demás de su
  rol conectan siempre); `jn_throw_in_2280` y `2506` no tienen lanzamiento (suelta medida en t = 0 s a < 0.5 m/s: la
  pelota salía de las manos a 0.87 m). Pasan al rol `setpiece_miss`, que nadie usa; el alias `soccer_penalty_kick`
  (era 3856) pasa a otro clip del rol (`PackLibrary`). Con ellos el corner fallaba ~1 de 9 veces y el saque de banda
  ~2 de 6 (`test_set_pieces`, aparecía como «no determinista»).
- Giros fuera de franja (14) con su medida; `kick_flick` (el sombrero necesita vuelo); `throw_prep`, `referee`,
  `idle_ball_var`, `ball_sole` sin toques.

## Integración comprobada (pruebas)

- `tests/test_bank_integration.gd`: el inventario cubre los 2 022 archivos con motivo en cada fila; cada clip
  reasignado y su espejo está en la selección de su rol; las transiciones pedidas por nombre tienen clip; la barrida
  fallida se salta con un clip `avoid` (nuevo `PlayerActions.avoid_tackle`, a través del árbitro); arranque y parada
  agotado se ven en el juego.
- `tests/test_falls_direction.gd`: caídas y trastabillones del banco elegidos por la dirección del contacto y la
  inercia (nuevo `PlayerActions._directed_pick`).
