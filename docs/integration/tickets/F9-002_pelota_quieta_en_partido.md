# F9-002 — Pelota quieta 16,5 s en un partido de 3 minutos (intermitente)

- **Prueba:** `tests/test_full_match.gd::test_three_minute_match_is_played_to_the_final_whistle_with_goal_replays`
  (exige que la pelota no quede más de 12 s quieta en juego).
- **Dónde apareció:** suite headless completa en la rama `reforma-tiros-penales`, 2026-11-07
  (`docs/reforma/fase1/pruebas/suite_headless.log`: «la pelota no queda trabada (16.5 s)»; ese partido terminó 0-1 con
  1 saque de arco y 1 tiro libre).
- **Reproducción:** no se reprodujo. La misma prueba aislada pasó 6 de 6 en `reforma-tiros-penales` (pelota quieta máxima
  0,6–3,7 s) y 6 de 6 en `integracion-openai` (0,8–1,4 s).
- **Relación con el cambio:** la Fase 1 de la reforma no toca la lógica del partido (agrega un botón al menú de pausa y
  cambia la escena de entrada, que esta prueba no usa). Los partidos no son deterministas (ver
  `AUDITORIA_PRE_IMPLEMENTACION.md` §7 y F9-001).
- **Pendiente:** si vuelve a aparecer, registrar la situación de juego (posición de la pelota y de los jugadores, estado del
  balón parado) en el instante en que la pelota queda quieta. Es del partido de fútbol 5, que la reforma conserva pero no
  desarrolla; no bloquea la comparación de bancos.

## Otra prueba de partido intermitente (2026-11-07)

- `tests/test_json_mode.gd::test_ai_match_in_json_mode` falló en GitHub Actions (compilación 67, intento 1): «Humanoide: hay
  tiros (0)», un partido de IA de 90 s sin ningún tiro. En la suite local de la misma rama pasó (2 tiros).
- Repetida 10 veces en local: falla 1 de 10 en `reforma-tiros-penales` y 3 de 10 en `5511cfe` (antes del cambio de golpeos
  laterales de la Fase 2 de la guía anterior). Es intermitente y anterior; el cambio no la empeoró.
- Las dos fallas son de estadísticas de partidos de IA no deterministas (fútbol 5). Para que la CI no dependa del azar
  habría que fijar las semillas y el reloj del partido (Fase 9/11 de la guía anterior); no se relaja ni se desactiva la
  prueba.
