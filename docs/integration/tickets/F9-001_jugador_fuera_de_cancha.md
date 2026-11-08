# F9-001 — Jugador fuera de la cancha más de 1 m en partido de IA (intermitente)

- **Fase asignada:** 9 (determinismo). **Estado:** abierto. **Tipo:** fallo intermitente de una prueba de partido.
- **Prueba:** `tests/test_ai_match.gd::test_ai_teams_play_a_real_match_without_getting_stuck`, comprobación
  «nadie se sale de la cancha más de 1 m».
- **Línea base:** tag local `pre-audit-phase-0` = `04ed110` (código idéntico a `5fb4f27`).

## Evidencia

| Ejecución | Resultado |
|---|---|
| Suite final local (`9d4069c`, misma lógica de juego) y GitHub Actions run 63 | pasa |
| Suite instrumentada sin galería durante la auditoría del 2026-11-07 (copia aislada) | **falla**: 4 muestras fuera de la cancha |
| Misma prueba aislada en la copia limpia de `5fb4f27`, 4 ejecuciones | pasa 4 de 4 |
| Fase 0: misma prueba aislada en el tag `pre-audit-phase-0`, 8 ejecuciones | pasa 8 de 8 (`fase0/pruebas/f9_001_test_ai_match_8_ejecuciones.log`). Sumadas, 0 fallos en 12 ejecuciones aisladas: el único fallo observado ocurrió dentro de la suite completa |
| Fase 0: misma semilla de partido repetida (10 min) | diverge a los 4–6 s de juego (diferencias de 1–2 cm), ver `AUDITORIA_PRE_IMPLEMENTACION.md` §7 |

## Causa probable (sin confirmar)

1. **Azar no sembrado** en el partido: `BallHandler`, `PlayerActions`, `Goalkeeper`, `SetPiece`, `MatchPresentation` y
   `PackLibrary._vary_rng` llaman a `randomize()`; la prueba solo siembra `AIInput`. Cada ejecución es un partido distinto.
2. **Dependencia del reloj real**: `Ball.last_touch_msec` usa `Time.get_ticks_msec()` y `BallHandler._finish_clip_kick`
   lo compara para detectar interferencias; en una simulación más rápida que el tiempo real, varios pasos de física caen
   en el mismo milisegundo y el resultado depende de la velocidad de la máquina.
3. Hipótesis a comprobar: la raíz de un clip (caída, barrida, transición) o un empujón lleva a un jugador más allá del
   margen. `PlayerActions.tick` limita la raíz a `half_length/half_width + 0.8 m` solo en modo 4 y solo para el eje que
   se aleja.

## Para cerrarlo (Fase 9)

- Sembrar todos los RNG del partido desde una semilla de prueba y sustituir `last_touch_msec` por un contador de pasos de
  física; con eso, reproducir el fallo de forma determinista.
- Registrar, en el instante de la muestra fuera, el jugador, su acción (`PlayerActions.kind`, clip) y el nivel del
  árbitro; corregir la causa, no la tolerancia de la prueba.
