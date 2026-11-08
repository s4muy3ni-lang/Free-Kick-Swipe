# E4 — Integración al nivel de UCS: datos de animación, golpeo sincronizado e IA con los parámetros de UCS (2026-11-06)

Pedido: integrar todo el sistema como UCS, sin auditorías ni recomendaciones. Eso incluye:

- usar en el juego real los datos de `animdb.adb`;
- que la física y las animaciones coincidan (sin pelota pegada al pie ni teletransportada);
- integrar todas las acciones;
- estudiar la IA de UCS y llevarla a la nuestra;
- probar, compilar el APK y entregar el enlace.

## Qué se encontró en UCS (comprobado)

1. **Configuración de juego** (`libMPX.so`, una función que carga 210 parámetros):
   - cada parámetro se pide por nombre con un valor por defecto entero, en punto fijo 4096 = 1.0 si es una escala;
   - tabla completa en [`E4_parametros_ucs.csv`](E4_parametros_ucs.csv), extraída leyendo el código ARM64 con capstone;
   - el **valor** está comprobado; el **significado** se infiere del nombre;
   - el servidor de UCS podría cambiar algún valor (no se pudo comprobar sin conexión).
2. **`animdb.adb`** ([E3](E3_conduccion_ucs.md)):
   - por clip: cuadro del toque, pie, destino de la pelota tras el toque, giro, ventana del joystick y velocidades;
   - en las recepciones, los vectores de pelota **no** son el punto de contacto: a 0.6 m de mediana de la parte del cuerpo
     en ese cuadro, en 92 recepciones verificadas. Son el destino tras el toque, como en la conducción, y así se usan.

## Qué quedó implementado

| Área | Cambio | Dónde |
|---|---|---|
| Conducción | Toque orientado con 41 clips de UCS (82 con espejos), elegido por la ventana del joystick de UCS, cortado tras el toque que gira, al trote y en carrera (hasta 5 m/s; en sprint, el toque de rumbo físico). La salida se orienta menos cuanto más rápido (60° al trote, 22° en sprint). Arranque con pelota con los clips de arranque de UCS | `JsonBallMove` (E3) |
| Golpeo de primera | El impulso sale en el paso en que la pelota que llega y la punta del pie **animado** están más cerca (espera ≤ 0.1 s; la pelota no se mueve a mano) | `BallHandler._ball_still_arriving` |
| Tras un golpe propio | Sin toque orientado ni arranque durante 1.2 s (el que pasaba alcanzaba su propio pase filtrado y empezaba un movimiento) | `JsonBallMove.STEER_AFTER_KICK_S` |
| Presión | Hasta 2 presionan y 1 entra (`MaxActivePresses`/`MaxActiveTackles`); la cobertura pasa a segundo presionador si llega en ≤ 1.2 s | `TeamBrain`, `AIInput` |
| Ataque | Amplitud al 60 % del ancho (`WidthOpenPlay`); el portador pasa sin presión entre 0.5 y 2 s (`BotMin/MaxKickFrames`) | `TeamBrain`, `AIInput` |
| Arquero | Sin cambios: la reacción de UCS (`ResponseGKSave` 15/4 cuadros) atajaba el 87-97 % con nuestro modelo y se probó y descartó | `Goalkeeper` |
| Botines | ~0.26 m (antes ~0.40 m) | `json_human.scn` (E3) |
| animdb | Base de datos propia con todas las animaciones por acción y los datos de UCS; la lee el juego (`AnimDB`) | `assets/animations/animdb.json` |

## Resultados (corridas reales, Godot 4.7.2, Linux; render con Xvfb)

- **Suite headless completa:** 290 pruebas, **0 fallidas**, 32 omitidas (las de render), 1725 comprobaciones, 869 s.
  Corrida con el código de `3ff0b3f`; el ajuste posterior de las esperas del toque orientado se probó por grupos (abajo).
- **Batería de 50 golpeos con render** (`test_live_kicks`): 50/50 con contacto, 0 inválidos, 0 bloqueos; 4 pruebas, 0
  fallidas. Punta del pie al centro de la pelota en la imagen del golpe: pase de primera a 5 m/s 0.264 → 0.172 m, a
  6 m/s 0.268 → 0.162 m.
- **Conducción con render** (`test_physical_dribble`): 5/0. El jugador se aparta de su pelota hasta 16° (trote + giro
  90), 25° (sprint + diagonal 40) y 16° (curva suave).
- **Grupos con el código final:** `mode4_dribble` 9/0 (toque orientado 4/4 con clip de UCS), `ball_turn` 4/0,
  `gameplay_feel` 10/0, `receive` 30/0, `json_mode` 10/0, `pack_kick` 8/0, `player_actions` 4/0.
- **Con la IA de UCS:** `ai_match` 3 de 3 corridas sin fallos, `goalkeeper` 5/0, `control_and_keeper` 7/0,
  `full_match` 4/0, `shot_keeper` 1/0.

### Probado y descartado (con su medida)

| Qué | Por qué no quedó |
|---|---|
| Reacción del arquero de UCS (`ResponseGKSave` 15/4 cuadros) | Con nuestro modelo de estirada atajaba el 87-97 % a 8-11 m y `test_shot_keeper` falló |
| Presión al 95 % (`PressureSpeedRate` como velocidad) | Cambió los tiros con un defensor encima (`test_shot_keeper` falló); el significado es inferido |
| Ventana del joystick de UCS en los giros grandes | En 839 clips la ventana no está centrada en el giro; los clips de 180° no se elegirían nunca para un giro de 180° |
| Toque orientado en sprint | El cuerpo seguía la raíz del clip y se apartaba 35° de su pelota |
| Espera de 0.1 s del golpeo sin mirar el pie animado | El pie seguía de largo (de 0.268 a 0.316 m); se pasó a buscar el paso con el pie animado más cerca |

### Qué no se pudo verificar

- La sensación en el teléfono con el mando real (la verifica la persona con el APK).
- Si el servidor de UCS cambia algún parámetro.
- Lo que hace exactamente el código de UCS con cada campo: se leyeron los valores, no se descompiló la lógica.

## Corrección posterior (2026-11-06, documentación de transferencia)

Al rehacer la extracción de `E4_parametros_ucs.csv` se corrigió el extractor. Tomaba el `mov w2` del parámetro
siguiente cuando el compilador lo adelantaba, y no armaba los valores `mov` + `movk` separados ni los calculados desde
`w19`. Cada caso se comprobó en el desensamblado. Resultado:

- el cargador lee **211** parámetros: faltaba `Version`;
- 9 valores estaban mal o vacíos: `StrengthJump1`, `StrengthSlideTackleRange0/1`, `StrengthPressureTackleRange0/1`,
  `TechniqueGKMinSaveDist1`, `TechniqueGKMaxSaveDist0`, `InterceptClearanceSpace` y `DribbleMinDist`;
- el campo de `BotChatPercent` era otro;
- 27 vacíos son 0.

**Ninguno de esos parámetros se usa en el juego**, así que los resultados de este informe no cambian. Tabla corregida:
[`docs/transferencia_integracion_completa/PARAMETROS_UCS.md`](../transferencia_integracion_completa/PARAMETROS_UCS.md)
(y `PARAMETROS_UCS.csv`). Este CSV de E4 se conserva sin cambios.
