# Los parámetros de juego de UCS (211 lecturas del cargador de configuración)

Completa [`docs/fases/E4_parametros_ucs.csv`](../fases/E4_parametros_ucs.csv) (210 filas). La tabla completa en datos está
en [`PARAMETROS_UCS.csv`](PARAMETROS_UCS.csv) y el documento se regenera así:

```
python3 tools/transfer/ucs_params_extract.py <libMPX.so> > docs/transferencia_integracion_completa/PARAMETROS_UCS.csv
python3 tools/transfer/make_params_doc.py   # tabla de la sección 4 (el texto de arriba se escribe a mano)
```

Leyenda: **[C]** comprobado · **[D]** deducido · **[I]** inferido · **[?]** desconocido.

## 1. De dónde salen los valores [C]

- **Archivo:** `libMPX.so`, en `lib/arm64-v8a/` de la división `config.arm64_v8a.apk` del APK de Ultimate Clash Soccer
  1.810. No se versiona en este repositorio.
- **Función:** el cargador de la configuración de juego. No tiene símbolo; su prólogo está en `0x5845b4` (marco de
  `0x600` bytes). Se recorrió el tramo `0x584800`-`0x586400` con capstone (`tools/transfer/ucs_params_extract.py`). No
  se ejecutó el juego ni se modificó el APK.
- **Patrón de cada lectura:**
  - `x1` = dirección de la cadena con el **nombre**;
  - `w2` = **valor por defecto**: `mov`, `mov` + `movk`, `wzr` (= 0) o `w19` + inmediato (`w19` = `0x14000`);
  - `x0` = objeto de una sección de configuración en la pila (6 distintos: `sp+0x108` 163 lecturas, `sp+0x118` 22,
    `sp+0x150` 13, `sp+0x190` 8, `sp+0x110` 3 y `sp+0x148` 2);
  - `bl 0x5e9030` = lectura de un **entero** (`0x5e86d8`: un texto, `NoActiveSeasonText`);
  - `str w0` (o una copia de `w0`) en un **campo** de una estructura.
- **Qué está comprobado:** el nombre, el valor por defecto escrito en el código, el campo y la dirección.
- **Qué no:** **[?]** si el servidor de UCS reemplaza el valor (la función recibe la configuración ya cargada; no se
  pudo comprobar sin conexión). **[I]** que `0x5e9030` devuelva el valor por defecto cuando falta el nombre: se deduce
  del patrón de llamada, no se desensambló su cuerpo.
- **Escala:** muchos valores parecen punto fijo con 4096 = 1.0 (Q12): 4096, 3891 ≈ 0.95, 2048 = 0.5… Eso es una
  **lectura posible [I]**, no una unidad establecida. Por eso la tabla da el valor entero y su lectura Q12 sin elegir
  entre las dos. Las unidades que aparecen («cuadros», «segundos», «por ciento») salen **solo del nombre** [I]. Que los
  cuadros sean de 60 Hz, como los de `animdb.adb`, también es una inferencia.

## 2. Correcciones respecto de E4 [C]

El extractor de E4 tomaba como valor por defecto el último `mov w2` **antes del `str`**. Cuando el compilador adelanta
la carga del valor del parámetro siguiente antes del `str` del anterior, ese valor era el del siguiente. Además, perdía
los valores armados con `mov` + `movk` separados y los calculados desde `w19`. Se verificó cada caso en el desensamblado:

| parámetro | E4 | correcto | instrucciones |
|---|---:|---:|---|
| `Version` | (no estaba) | 0 | `mov w2, wzr` · `bl` · `mov w19, w0` · `str w19, [x28, #0x18]` (`0x584860`) |
| `StrengthJump1` | 16384 | **8192** | `mov w2, #0x2000` · `bl 0x5e9030` (`0x584b60-64`); el `mov w2, #0x4000` siguiente es del parámetro siguiente |
| `StrengthSlideTackleRange0` | 65536 | **81920** | `mov w2, #0x4000` (`0x584b68`) … `movk w2, #1, lsl #16` (`0x584b7c`) |
| `StrengthSlideTackleRange1` | vacío | **147456** | `add w2, w19, #0x10, lsl #12` con `w19` = `0x14000` (`0x584b9c`) |
| `StrengthPressureTackleRange0` | 16384 | **49152** | `mov w2, #0xc000` (`0x584bb4`) |
| `StrengthPressureTackleRange1` | 65536 | **81920** | `mov w2, #0x4000` (`0x584bbc`) … `movk w2, #1, lsl #16` (`0x584bd0`) |
| `TechniqueGKMinSaveDist1` | 16384 | **58982** | `mov w2, #0xe666` (`0x584f4c`) |
| `TechniqueGKMaxSaveDist0` | 65536 | **81920** | `mov w2, #0x4000` (`0x584f54`) … `movk w2, #1, lsl #16` (`0x584f68`) |
| `InterceptClearanceSpace` | vacío | **163840** | `add w2, w19, #0x14, lsl #12` (`0x58510c`) |
| `DribbleMinDist` | vacío | **163840** | `add w2, w19, #0x14, lsl #12` (`0x58528c`) |
| `BotChatPercent` | campo 0x5f8 | campo **0x5dc** | `bl` · `mov w8, w0` · `str w8, [x26, #0x5dc]`; el `str` en 0x5f8 es de otra lectura (`bl 0x74beb8`) |
| 27 parámetros con valor vacío | vacío | **0** | `mov w2, wzr` (registro cero) |

Ninguno de los valores corregidos se usa en el juego (`scripts/ai/ucs_params.gd` no los define), así que la corrección
no cambia el comportamiento. **[C]**

## 3. Resumen del estado en Futbol5 [C]

| Estado | Parámetros | Dónde |
|---|---|---|
| Implementado | `MaxActivePresses`, `MaxActiveTackles` (implícito), `WidthOpenPlay`, `BotMinKickFrames`, `BotMaxKickFrames` | `scripts/ai/team_brain.gd:159, 348-350`; `scripts/ai/ai_input.gd:31, 539-541` |
| Probado y descartado (E4) | `PressureSpeedRate`, `ResponseGKSave0/1` | constantes sin uso en `scripts/ai/ucs_params.gd:17, 29`; comentario en `scripts/goalkeeper/goalkeeper.gd:375-377` |
| Definido sin uso | `InterceptUrgency`, `ResponsePlayerAction0/1`, `RunAutoMaxRunners`, `RunTimeout`, `UrgencyLooseBallOppoFrames` | `scripts/ai/ucs_params.gd:19, 27, 32, 33, 39` |
| Sin conectar | los 197 restantes | — |

Sobre `WidthOpenPlay` = 60: se aplicó como el 60 % del medio ancho (`TeamBrain._attack`, `team_brain.gd:159`). Que sea
un porcentaje es **[I]**: el nombre no lo dice.

## 4. Tabla completa

Columnas:

- **defecto**, **origen del valor**, **campo** y **STR en** (dirección de la instrucción que guarda el valor): [C].
- **Q12:** defecto / 4096, solo como lectura posible.
- **unidad / escala:** solo la que da el nombre [I], o «no establecida».
- **posible función:** [I], solo del nombre.
- **sistema de Futbol5:** el sistema candidato, con su archivo y línea (el código existe [C]; la correspondencia es
  [I]).
- **estado:** [C] en nuestro código.
- **corrección:** diferencia con `E4_parametros_ucs.csv`.

| # | parametro | defecto | origen del valor | Q12 | campo | STR en | unidad / escala | posible funcion (nombre) | sistema de Futbol5 | estado | correccion respecto de E4 |
|---:|---|---:|---|---:|---|---|---|---|---|---|---|
| 1 | `Version` | 0 | registro cero (wzr) | 0.0000 | 0x18 | 0x584860 | no establecida | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR | falta en E4_parametros_ucs.csv |
| 2 | `ScreenOrientation` | 0 | registro cero (wzr) | 0.0000 | 0x1c | 0x584868 | no establecida | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR | E4: vacio |
| 3 | `ReSignInTime` | 3600 | constante | 0.8789 | 0x20 | 0x584880 | tiempo (nombre; unidad no establecida) | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR |  |
| 4 | `PerformHousekeepingHours` | 168 | constante | 0.0410 | 0x24 | 0x584898 | horas (nombre) | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR |  |
| 5 | `ChatWaitSeconds` | 10 | constante | 0.0024 | 0x3c | 0x5848ec | segundos (nombre) | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR |  |
| 6 | `MatchSaveExtraHighlightsCount` | 0 | registro cero (wzr) | 0.0000 | 0x40 | 0x584904 | no establecida | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR | E4: vacio |
| 7 | `NoActiveSeasonText` | - | texto (lectura 0x5e86d8) | - | 0x2c | 0x584930 | no establecida | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR |  |
| 8 | `MatchesForLinkCode` | 5 | constante | 0.0012 | 0x48 | 0x584964 | no establecida | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR |  |
| 9 | `LeaderboardJoin` | 0 | registro cero (wzr) | 0.0000 | 0x50 | 0x584998 | no establecida | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR | E4: vacio |
| 10 | `MaxSquadSize` | 0 | registro cero (wzr) | 0.0000 | 0x58 | 0x5849cc | no establecida | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR | E4: vacio |
| 11 | `FriendLimit` | 0 | registro cero (wzr) | 0.0000 | 0x5c | 0x5849e4 | no establecida | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR | E4: vacio |
| 12 | `BoostsValue` | 0 | registro cero (wzr) | 0.0000 | 0x34 | 0x584ab8 | no establecida | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR | E4: vacio |
| 13 | `TokenValue` | 0 | registro cero (wzr) | 0.0000 | 0x2c | 0x584ad0 | no establecida | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR | E4: vacio |
| 14 | `WildcardValue` | 0 | registro cero (wzr) | 0.0000 | 0x30 | 0x584ae8 | no establecida | aplicacion / cuenta / tienda (no juego) | ninguno (no hay equivalente) | SIN CONECTAR | E4: vacio |
| 15 | `SpeedSprint0` | 3738 | constante | 0.9126 | 0x314 | 0x584b20 | no establecida | velocidad de sprint por atributo (0 = minimo, 1 = maximo) | Locomotion.max_sprint_speed (scripts/player/locomotion.gd:59): PlayerTuning.sprint_speed 6.8 x factor(speed, 0.12) | SIN CONECTAR |  |
| 16 | `SpeedSprint1` | 4539 | constante | 1.1082 | 0x318 | 0x584b38 | no establecida | velocidad de sprint por atributo (0 = minimo, 1 = maximo) | Locomotion.max_sprint_speed (scripts/player/locomotion.gd:59): PlayerTuning.sprint_speed 6.8 x factor(speed, 0.12) | SIN CONECTAR |  |
| 17 | `StrengthJump0` | 0 | registro cero (wzr) | 0.0000 | 0x31c | 0x584b50 | no establecida | salto por atributo de fuerza | sin sistema de salto propio; golpeo aereo en BallHandler.plan_aerial_kick (scripts/player/ball_handler.gd:803) | SIN CONECTAR | E4: vacio |
| 18 | `StrengthJump1` | 8192 | constante | 2.0000 | 0x320 | 0x584b6c | no establecida | salto por atributo de fuerza | sin sistema de salto propio; golpeo aereo en BallHandler.plan_aerial_kick (scripts/player/ball_handler.gd:803) | SIN CONECTAR | E4: 16384 |
| 19 | `StrengthSlideTackleRange0` | 81920 | constante (mov + movk) | 20.0000 | 0x324 | 0x584b8c | no establecida | alcance de la barrida por fuerza | PlayerActions.try_slide_tackle (scripts/player/player_actions.gd:211) | SIN CONECTAR | E4: 65536 |
| 20 | `StrengthSlideTackleRange1` | 147456 | calculado: w19 (0x14000) + 0x10000 | 36.0000 | 0x328 | 0x584ba4 | no establecida | alcance de la barrida por fuerza | PlayerActions.try_slide_tackle (scripts/player/player_actions.gd:211) | SIN CONECTAR | E4: vacio |
| 21 | `StrengthPressureTackleRange0` | 49152 | constante | 12.0000 | 0x32c | 0x584bc0 | no establecida | alcance de la entrada al presionar | BallHandler.attempt_tackle (scripts/player/ball_handler.gd:3083), PlayerActions.tackle_request (scripts/player/player_actions.gd:294) | SIN CONECTAR | E4: 16384 |
| 22 | `StrengthPressureTackleRange1` | 81920 | constante (mov + movk) | 20.0000 | 0x330 | 0x584bd8 | no establecida | alcance de la entrada al presionar | BallHandler.attempt_tackle (scripts/player/ball_handler.gd:3083), PlayerActions.tackle_request (scripts/player/player_actions.gd:294) | SIN CONECTAR | E4: 65536 |
| 23 | `StrengthPassiveTackleRange0` | 24576 | constante | 6.0000 | 0x334 | 0x584bf0 | no establecida | alcance de la entrada pasiva | BallHandler.attempt_tackle (scripts/player/ball_handler.gd:3083) | SIN CONECTAR |  |
| 24 | `StrengthPassiveTackleRange1` | 40960 | constante | 10.0000 | 0x338 | 0x584c08 | no establecida | alcance de la entrada pasiva | BallHandler.attempt_tackle (scripts/player/ball_handler.gd:3083) | SIN CONECTAR |  |
| 25 | `KickPower0` | 18382 | constante | 4.4878 | 0x33c | 0x584c20 | no establecida | potencia de golpeo por atributo | PassAssist.compute / ShotAssist.compute (scripts/assistance/pass_assist.gd:53, shot_assist.gd:54) | SIN CONECTAR |  |
| 26 | `KickPower1` | 21627 | constante | 5.2800 | 0x340 | 0x584c38 | no establecida | potencia de golpeo por atributo | PassAssist.compute / ShotAssist.compute (scripts/assistance/pass_assist.gd:53, shot_assist.gd:54) | SIN CONECTAR |  |
| 27 | `KickPowerWrongFoot` | 3891 | constante | 0.9500 | 0x344 | 0x584c50 | no establecida | potencia con el pie malo | KickModel.weak_foot_power_mult (scripts/assistance/kick_model.gd:108) | SIN CONECTAR |  |
| 28 | `TechniqueSpecialKickPercent0` | 0 | registro cero (wzr) | 0.0000 | 0x380 | 0x584c68 | por ciento (nombre) | probabilidad de golpeo especial | sin equivalente | SIN CONECTAR | E4: vacio |
| 29 | `TechniqueSpecialKickPercent1` | 100 | constante | 0.0244 | 0x384 | 0x584c84 | por ciento (nombre) | probabilidad de golpeo especial | sin equivalente | SIN CONECTAR |  |
| 30 | `TechniqueSpecialControlPercent0` | 0 | registro cero (wzr) | 0.0000 | 0x388 | 0x584c9c | por ciento (nombre) | probabilidad de control especial | JsonReceive (scripts/player/json_receive.gd) sin probabilidad | SIN CONECTAR | E4: vacio |
| 31 | `TechniqueSpecialControlPercent1` | 50 | constante | 0.0122 | 0x38c | 0x584cb4 | por ciento (nombre) | probabilidad de control especial | JsonReceive (scripts/player/json_receive.gd) sin probabilidad | SIN CONECTAR |  |
| 32 | `TechniqueDribbleSpeedScale0` | 820 | constante | 0.2002 | 0x390 | 0x584ccc | escala: lectura Q12 posible | escala de velocidad conduciendo | BallHandler.dribble_speed_cap (scripts/player/ball_handler.gd:352) | SIN CONECTAR |  |
| 33 | `TechniqueDribbleSpeedScale1` | 956 | constante | 0.2334 | 0x394 | 0x584ce4 | escala: lectura Q12 posible | escala de velocidad conduciendo | BallHandler.dribble_speed_cap (scripts/player/ball_handler.gd:352) | SIN CONECTAR |  |
| 34 | `TechniqueCurl0` | 500 | constante | 0.1221 | 0x398 | 0x584cfc | no establecida | efecto (comba) por tecnica | KickModel.curl_spin (scripts/assistance/kick_model.gd:61) | SIN CONECTAR |  |
| 35 | `TechniqueCurl1` | 8000 | constante | 1.9531 | 0x39c | 0x584d14 | no establecida | efecto (comba) por tecnica | KickModel.curl_spin (scripts/assistance/kick_model.gd:61) | SIN CONECTAR |  |
| 36 | `TechniqueTackleJumpPercent0` | 0 | registro cero (wzr) | 0.0000 | 0x3a0 | 0x584d2c | por ciento (nombre) | probabilidad de saltar una entrada | PlayerActions.avoid_tackle (scripts/player/player_actions.gd:456) | SIN CONECTAR | E4: vacio |
| 37 | `TechniqueTackleJumpPercent1` | 75 | constante | 0.0183 | 0x3a4 | 0x584d44 | por ciento (nombre) | probabilidad de saltar una entrada | PlayerActions.avoid_tackle (scripts/player/player_actions.gd:456) | SIN CONECTAR |  |
| 38 | `TechniqueKickErrorFW0` | 187 | constante | 0.0457 | 0x3a8 | 0x584d5c | no establecida | error del golpeo (adelante / atras / altura) | PassAssist._pass_sigma (scripts/assistance/pass_assist.gd:260), KickModel.gaussian_clipped (kick_model.gd:55) | SIN CONECTAR |  |
| 39 | `TechniqueKickErrorFW1` | 78 | constante | 0.0190 | 0x3ac | 0x584d74 | no establecida | error del golpeo (adelante / atras / altura) | PassAssist._pass_sigma (scripts/assistance/pass_assist.gd:260), KickModel.gaussian_clipped (kick_model.gd:55) | SIN CONECTAR |  |
| 40 | `TechniqueKickErrorBW0` | 533 | constante | 0.1301 | 0x3b0 | 0x584d8c | no establecida | error del golpeo (adelante / atras / altura) | PassAssist._pass_sigma (scripts/assistance/pass_assist.gd:260), KickModel.gaussian_clipped (kick_model.gd:55) | SIN CONECTAR |  |
| 41 | `TechniqueKickErrorBW1` | 270 | constante | 0.0659 | 0x3b4 | 0x584da4 | no establecida | error del golpeo (adelante / atras / altura) | PassAssist._pass_sigma (scripts/assistance/pass_assist.gd:260), KickModel.gaussian_clipped (kick_model.gd:55) | SIN CONECTAR |  |
| 42 | `TechniqueKickErrorHeight0` | 262 | constante | 0.0640 | 0x3b8 | 0x584dbc | no establecida | error del golpeo (adelante / atras / altura) | PassAssist._pass_sigma (scripts/assistance/pass_assist.gd:260), KickModel.gaussian_clipped (kick_model.gd:55) | SIN CONECTAR |  |
| 43 | `TechniqueKickErrorHeight1` | 135 | constante | 0.0330 | 0x3bc | 0x584dd4 | no establecida | error del golpeo (adelante / atras / altura) | PassAssist._pass_sigma (scripts/assistance/pass_assist.gd:260), KickModel.gaussian_clipped (kick_model.gd:55) | SIN CONECTAR |  |
| 44 | `TechniqueRotPowerScaleBW0` | 896 | constante | 0.2188 | 0x3c0 | 0x584dec | escala: lectura Q12 posible | escala de potencia al girar / en altura | ShotAssist.compute (scripts/assistance/shot_assist.gd:54) | SIN CONECTAR |  |
| 45 | `TechniqueRotPowerScaleBW1` | 960 | constante | 0.2344 | 0x3c4 | 0x584e04 | escala: lectura Q12 posible | escala de potencia al girar / en altura | ShotAssist.compute (scripts/assistance/shot_assist.gd:54) | SIN CONECTAR |  |
| 46 | `TechniqueHeightPowerScale0` | 896 | constante | 0.2188 | 0x3c8 | 0x584e1c | escala: lectura Q12 posible | escala de potencia al girar / en altura | ShotAssist.compute (scripts/assistance/shot_assist.gd:54) | SIN CONECTAR |  |
| 47 | `TechniqueHeightPowerScale1` | 960 | constante | 0.2344 | 0x3cc | 0x584e34 | escala: lectura Q12 posible | escala de potencia al girar / en altura | ShotAssist.compute (scripts/assistance/shot_assist.gd:54) | SIN CONECTAR |  |
| 48 | `ResponsePlayerAction0` | 40 | constante | 0.0098 | 0x3d8 | 0x584e4c | no establecida | respuesta del jugador (posicion / fuera de posesion / golpeo) | AIInput.DECISION_PERIOD 0.12 s (scripts/ai/ai_input.gd:9), TeamBrain.DECISION_PERIOD 0.2 s (team_brain.gd:19) | DEFINIDO SIN USO: `UcsParams.RESPONSE_ACTION_S` (scripts/ai/ucs_params.gd:27) |  |
| 49 | `ResponsePlayerAction1` | 20 | constante | 0.0049 | 0x3dc | 0x584e64 | no establecida | respuesta del jugador (posicion / fuera de posesion / golpeo) | AIInput.DECISION_PERIOD 0.12 s (scripts/ai/ai_input.gd:9), TeamBrain.DECISION_PERIOD 0.2 s (team_brain.gd:19) | DEFINIDO SIN USO: idem |  |
| 50 | `ResponsePlayerMovePos0` | 21 | constante | 0.0051 | 0x3e0 | 0x584e7c | no establecida | respuesta del jugador (posicion / fuera de posesion / golpeo) | AIInput.DECISION_PERIOD 0.12 s (scripts/ai/ai_input.gd:9), TeamBrain.DECISION_PERIOD 0.2 s (team_brain.gd:19) | SIN CONECTAR |  |
| 51 | `ResponsePlayerMovePos1` | 1 | constante | 0.0002 | 0x3e4 | 0x584e94 | no establecida | respuesta del jugador (posicion / fuera de posesion / golpeo) | AIInput.DECISION_PERIOD 0.12 s (scripts/ai/ai_input.gd:9), TeamBrain.DECISION_PERIOD 0.2 s (team_brain.gd:19) | SIN CONECTAR |  |
| 52 | `ResponsePlayerMoveOOP0` | 21 | constante | 0.0051 | 0x3e8 | 0x584eac | no establecida | respuesta del jugador (posicion / fuera de posesion / golpeo) | AIInput.DECISION_PERIOD 0.12 s (scripts/ai/ai_input.gd:9), TeamBrain.DECISION_PERIOD 0.2 s (team_brain.gd:19) | SIN CONECTAR |  |
| 53 | `ResponsePlayerMoveOOP1` | 1 | constante | 0.0002 | 0x3ec | 0x584ec4 | no establecida | respuesta del jugador (posicion / fuera de posesion / golpeo) | AIInput.DECISION_PERIOD 0.12 s (scripts/ai/ai_input.gd:9), TeamBrain.DECISION_PERIOD 0.2 s (team_brain.gd:19) | SIN CONECTAR |  |
| 54 | `ResponsePlayerKickPos0` | 21 | constante | 0.0051 | 0x3f0 | 0x584edc | no establecida | respuesta del jugador (posicion / fuera de posesion / golpeo) | AIInput.DECISION_PERIOD 0.12 s (scripts/ai/ai_input.gd:9), TeamBrain.DECISION_PERIOD 0.2 s (team_brain.gd:19) | SIN CONECTAR |  |
| 55 | `ResponsePlayerKickPos1` | 1 | constante | 0.0002 | 0x3f4 | 0x584ef4 | no establecida | respuesta del jugador (posicion / fuera de posesion / golpeo) | AIInput.DECISION_PERIOD 0.12 s (scripts/ai/ai_input.gd:9), TeamBrain.DECISION_PERIOD 0.2 s (team_brain.gd:19) | SIN CONECTAR |  |
| 56 | `ResponsePlayerKickOOP0` | 21 | constante | 0.0051 | 0x3f8 | 0x584f0c | no establecida | respuesta del jugador (posicion / fuera de posesion / golpeo) | AIInput.DECISION_PERIOD 0.12 s (scripts/ai/ai_input.gd:9), TeamBrain.DECISION_PERIOD 0.2 s (team_brain.gd:19) | SIN CONECTAR |  |
| 57 | `ResponsePlayerKickOOP1` | 1 | constante | 0.0002 | 0x3fc | 0x584f24 | no establecida | respuesta del jugador (posicion / fuera de posesion / golpeo) | AIInput.DECISION_PERIOD 0.12 s (scripts/ai/ai_input.gd:9), TeamBrain.DECISION_PERIOD 0.2 s (team_brain.gd:19) | SIN CONECTAR |  |
| 58 | `TechniqueGKMinSaveDist0` | 44892 | constante | 10.9600 | 0x348 | 0x584f3c | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 59 | `TechniqueGKMinSaveDist1` | 58982 | constante | 14.3999 | 0x34c | 0x584f58 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR | E4: 16384 |
| 60 | `TechniqueGKMaxSaveDist0` | 81920 | constante (mov + movk) | 20.0000 | 0x350 | 0x584f70 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR | E4: 65536 |
| 61 | `TechniqueGKMaxSaveDist1` | 98304 | constante | 24.0000 | 0x354 | 0x584f88 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 62 | `TechniqueGKSaveSpeed0` | 18690 | constante | 4.5630 | 0x358 | 0x584fa0 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 63 | `TechniqueGKSaveSpeed1` | 22428 | constante | 5.4756 | 0x35c | 0x584fbc | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 64 | `GKPresenceClaimPercent0` | 90 | constante | 0.0220 | 0x368 | 0x584ff0 | por ciento (nombre) | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 65 | `GKPresenceClaimPercent1` | 105 | constante | 0.0256 | 0x36c | 0x585008 | por ciento (nombre) | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 66 | `GKPresencePressureFrames0` | 60 | constante | 0.0146 | 0x370 | 0x585020 | cuadros (nombre) | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 67 | `GKPresencePressureFrames1` | 30 | constante | 0.0073 | 0x374 | 0x585038 | cuadros (nombre) | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 68 | `GKPresencePressureSpace0` | 196608 | constante | 48.0000 | 0x378 | 0x585050 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 69 | `GKPresencePressureSpace1` | 98304 | constante | 24.0000 | 0x37c | 0x585068 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 70 | `ResponseGKSave0` | 15 | constante | 0.0037 | 0x3d0 | 0x585080 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | PROBADO Y DESCARTADO (E4): `UcsParams.RESPONSE_GK_SAVE_S` (scripts/ai/ucs_params.gd:29) sin uso; ver comentario en `Goalkeeper._assess_shot` (scripts/goalkeeper/goalkeeper.gd:375-377) |  |
| 71 | `ResponseGKSave1` | 4 | constante | 0.0010 | 0x3d4 | 0x585098 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | PROBADO Y DESCARTADO (E4): idem ResponseGKSave0 |  |
| 72 | `FreezeMaxPlayerDist` | 32768 | constante | 8.0000 | 0x444 | 0x5850cc | no establecida | ventana de conduccion congelada (distancias / altura de pelota) | sin equivalente; posesion en MatchContext.update_possession (scripts/gameplay/match_context.gd:37) | SIN CONECTAR |  |
| 73 | `FreezeDribbleMaxBallHeight` | 8192 | constante | 2.0000 | 0x448 | 0x5850e4 | no establecida | ventana de conduccion congelada (distancias / altura de pelota) | sin equivalente; posesion en MatchContext.update_possession (scripts/gameplay/match_context.gd:37) | SIN CONECTAR |  |
| 74 | `FreezeMinOppoDist` | 32768 | constante | 8.0000 | 0x44c | 0x5850fc | no establecida | ventana de conduccion congelada (distancias / altura de pelota) | sin equivalente; posesion en MatchContext.update_possession (scripts/gameplay/match_context.gd:37) | SIN CONECTAR |  |
| 75 | `InterceptClearanceSpace` | 163840 | calculado: w19 (0x14000) + 0x14000 | 40.0000 | 0x450 | 0x585114 | no establecida | intercepcion / despeje (espacio, altura, urgencia) | TeamBrain._loose (scripts/ai/team_brain.gd:409), BallHandler.loose_ball_chase (ball_handler.gd:296) | SIN CONECTAR | E4: vacio |
| 76 | `InterceptClearanceHeight` | 49152 | constante | 12.0000 | 0x454 | 0x58512c | no establecida | intercepcion / despeje (espacio, altura, urgencia) | TeamBrain._loose (scripts/ai/team_brain.gd:409), BallHandler.loose_ball_chase (ball_handler.gd:296) | SIN CONECTAR |  |
| 77 | `MaxActiveTackles` | 1 | constante | 0.0002 | 0x400 | 0x585144 | no establecida | maximo de jugadores que presionan / entran | TeamBrain._defend (scripts/ai/team_brain.gd:317) | IMPLEMENTADO (implicito): el segundo presionador lleva `press: false` y no entra (scripts/ai/team_brain.gd:349); la constante `UcsParams.MAX_ACTIVE_TACKLES` (scripts/ai/ucs_params.gd:15) no se lee |  |
| 78 | `MaxActivePresses` | 2 | constante | 0.0005 | 0x404 | 0x58515c | no establecida | maximo de jugadores que presionan / entran | TeamBrain._defend (scripts/ai/team_brain.gd:317) | IMPLEMENTADO: `UcsParams.MAX_ACTIVE_PRESSES` (scripts/ai/ucs_params.gd:14) en `TeamBrain._defend` (scripts/ai/team_brain.gd:348): segundo presionador `press2` |  |
| 79 | `TacklingOpponentCircleSize` | 21845 | constante | 5.3333 | 0x408 | 0x585174 | no establecida | entrada: circulo del rival, distancia minima, cuadros, velocidad | BallHandler.attempt_tackle (scripts/player/ball_handler.gd:3083), Footballer._ai_commits_tackle (footballer.gd) | SIN CONECTAR |  |
| 80 | `TacklingMinDist` | 655360 | constante | 160.0000 | 0x40c | 0x58518c | no establecida | entrada: circulo del rival, distancia minima, cuadros, velocidad | BallHandler.attempt_tackle (scripts/player/ball_handler.gd:3083), Footballer._ai_commits_tackle (footballer.gd) | SIN CONECTAR |  |
| 81 | `TackleMinStatusFrames` | 15 | constante | 0.0037 | 0x410 | 0x5851a4 | cuadros (nombre) | entrada: circulo del rival, distancia minima, cuadros, velocidad | BallHandler.attempt_tackle (scripts/player/ball_handler.gd:3083), Footballer._ai_commits_tackle (footballer.gd) | SIN CONECTAR |  |
| 82 | `TackleSpeedRate` | 4096 | constante | 1.0000 | 0x414 | 0x5851bc | escala: lectura Q12 posible | entrada: circulo del rival, distancia minima, cuadros, velocidad | BallHandler.attempt_tackle (scripts/player/ball_handler.gd:3083), Footballer._ai_commits_tackle (footballer.gd) | SIN CONECTAR |  |
| 83 | `PressureSpeedRate` | 3891 | constante | 0.9500 | 0x418 | 0x5851d4 | escala: lectura Q12 posible | velocidad del que presiona | TeamBrain._defend (scripts/ai/team_brain.gd:317) | PROBADO Y DESCARTADO (E4): `UcsParams.PRESSURE_SPEED_RATE` (scripts/ai/ucs_params.gd:17) definido y sin uso; aplicado como velocidad rompio `test_shot_keeper` |  |
| 84 | `InterceptUrgency` | 5120 | constante | 1.2500 | 0x41c | 0x5851ec | no establecida | intercepcion / despeje (espacio, altura, urgencia) | TeamBrain._loose (scripts/ai/team_brain.gd:409), BallHandler.loose_ball_chase (ball_handler.gd:296) | DEFINIDO SIN USO: `UcsParams.INTERCEPT_URGENCY` (scripts/ai/ucs_params.gd:19) |  |
| 85 | `InterceptHeightBase` | 65156 | constante | 15.9072 | 0x420 | 0x585204 | no establecida | intercepcion / despeje (espacio, altura, urgencia) | TeamBrain._loose (scripts/ai/team_brain.gd:409), BallHandler.loose_ball_chase (ball_handler.gd:296) | SIN CONECTAR |  |
| 86 | `InterceptHeightBlendRate` | 2048 | constante | 0.5000 | 0x424 | 0x585224 | escala: lectura Q12 posible | intercepcion / despeje (espacio, altura, urgencia) | TeamBrain._loose (scripts/ai/team_brain.gd:409), BallHandler.loose_ball_chase (ball_handler.gd:296) | SIN CONECTAR |  |
| 87 | `KickErrorTrajScale` | 1024 | constante | 0.2500 | 0x438 | 0x585264 | escala: lectura Q12 posible | escala del error de trayectoria / potencia | KickModel (scripts/assistance/kick_model.gd) | SIN CONECTAR |  |
| 88 | `KickErrorPowerRate` | 2048 | constante | 0.5000 | 0x43c | 0x58527c | escala: lectura Q12 posible | escala del error de trayectoria / potencia | KickModel (scripts/assistance/kick_model.gd) | SIN CONECTAR |  |
| 89 | `DribbleMinDist` | 163840 | calculado: w19 (0x14000) + 0x14000 | 40.0000 | 0x458 | 0x585294 | no establecida | conduccion / pelota suelta | BallHandler (scripts/player/ball_handler.gd), MatchContext.update_possession (match_context.gd:37) | SIN CONECTAR | E4: vacio |
| 90 | `MarkingThreshold` | 1024 | constante | 0.2500 | 0x470 | 0x5852b0 | no establecida | marcaje (umbral, linea de fondo, zona, distancia) | AIInput._mark_spot (scripts/ai/ai_input.gd:673): MARK_GOAL_SIDE 2.6 m, MARK_RANGE 15 m | SIN CONECTAR |  |
| 91 | `MarkingBacklineExtra` | 32768 | constante | 8.0000 | 0x488 | 0x58531c | no establecida | marcaje (umbral, linea de fondo, zona, distancia) | AIInput._mark_spot (scripts/ai/ai_input.gd:673): MARK_GOAL_SIDE 2.6 m, MARK_RANGE 15 m | SIN CONECTAR |  |
| 92 | `MarkingZonePersistTolerance` | 98304 | constante | 24.0000 | 0x484 | 0x585334 | no establecida | marcaje (umbral, linea de fondo, zona, distancia) | AIInput._mark_spot (scripts/ai/ai_input.gd:673): MARK_GOAL_SIDE 2.6 m, MARK_RANGE 15 m | SIN CONECTAR |  |
| 93 | `MarkingDist0` | 49152 | constante | 12.0000 | 0x48c | 0x58534c | no establecida | marcaje (umbral, linea de fondo, zona, distancia) | AIInput._mark_spot (scripts/ai/ai_input.gd:673): MARK_GOAL_SIDE 2.6 m, MARK_RANGE 15 m | SIN CONECTAR |  |
| 94 | `MarkingDist1` | 49152 | constante | 12.0000 | 0x490 | 0x585364 | no establecida | marcaje (umbral, linea de fondo, zona, distancia) | AIInput._mark_spot (scripts/ai/ai_input.gd:673): MARK_GOAL_SIDE 2.6 m, MARK_RANGE 15 m | SIN CONECTAR |  |
| 95 | `RunTimeout` | 300 | constante | 0.0732 | 0x494 | 0x58537c | no establecida | desmarques (duracion, flecha, cantidad, fuera de juego, distancias, giro) | AIInput._run_behind_spot / _box_run_spot (scripts/ai/ai_input.gd:390, 371) | DEFINIDO SIN USO: `UcsParams.RUN_TIMEOUT_S` (scripts/ai/ucs_params.gd:33) |  |
| 96 | `RunArrowLength` | 10 | constante | 0.0024 | 0x498 | 0x585394 | no establecida | desmarques (duracion, flecha, cantidad, fuera de juego, distancias, giro) | AIInput._run_behind_spot / _box_run_spot (scripts/ai/ai_input.gd:390, 371) | SIN CONECTAR |  |
| 97 | `RunAutoMaxRunners` | 2 | constante | 0.0005 | 0x49c | 0x5853ac | no establecida | desmarques (duracion, flecha, cantidad, fuera de juego, distancias, giro) | AIInput._run_behind_spot / _box_run_spot (scripts/ai/ai_input.gd:390, 371) | DEFINIDO SIN USO: `UcsParams.RUN_AUTO_MAX_RUNNERS` (scripts/ai/ucs_params.gd:32) |  |
| 98 | `RunAutoRandomConsider` | 5 | constante | 0.0012 | 0x4a0 | 0x5853c4 | no establecida | desmarques (duracion, flecha, cantidad, fuera de juego, distancias, giro) | AIInput._run_behind_spot / _box_run_spot (scripts/ai/ai_input.gd:390, 371) | SIN CONECTAR |  |
| 99 | `RunAutoOnsideYards` | 15 | constante | 0.0037 | 0x4a4 | 0x5853dc | yardas (nombre) | desmarques (duracion, flecha, cantidad, fuera de juego, distancias, giro) | AIInput._run_behind_spot / _box_run_spot (scripts/ai/ai_input.gd:390, 371) | SIN CONECTAR |  |
| 100 | `RunAutoMinGoalDist` | 20 | constante | 0.0049 | 0x4a8 | 0x5853f4 | no establecida | desmarques (duracion, flecha, cantidad, fuera de juego, distancias, giro) | AIInput._run_behind_spot / _box_run_spot (scripts/ai/ai_input.gd:390, 371) | SIN CONECTAR |  |
| 101 | `RunAutoMinBallDist` | 15 | constante | 0.0037 | 0x4ac | 0x58540c | no establecida | desmarques (duracion, flecha, cantidad, fuera de juego, distancias, giro) | AIInput._run_behind_spot / _box_run_spot (scripts/ai/ai_input.gd:390, 371) | SIN CONECTAR |  |
| 102 | `RunAutoRotRange` | 1024 | constante | 0.2500 | 0x4b0 | 0x585428 | no establecida | desmarques (duracion, flecha, cantidad, fuera de juego, distancias, giro) | AIInput._run_behind_spot / _box_run_spot (scripts/ai/ai_input.gd:390, 371) | SIN CONECTAR |  |
| 103 | `LooseBallDribbleTolerance` | -30 | constante | -0.0073 | 0x4bc | 0x585464 | no establecida | conduccion / pelota suelta | BallHandler (scripts/player/ball_handler.gd), MatchContext.update_possession (match_context.gd:37) | SIN CONECTAR |  |
| 104 | `ShotDistMaxPower` | 32 | constante | 0.0078 | 0x4c0 | 0x58547c | no establecida | potencia del tiro segun la distancia | ShotAssist.compute (scripts/assistance/shot_assist.gd:54) | SIN CONECTAR |  |
| 105 | `ShotDistNoPower` | -68 | constante | -0.0166 | 0x4c4 | 0x585494 | no establecida | potencia del tiro segun la distancia | ShotAssist.compute (scripts/assistance/shot_assist.gd:54) | SIN CONECTAR |  |
| 106 | `CtrlBallScreenRadiusMin` | 48 | constante | 0.0117 | 0x4c8 | 0x5854ac | no establecida | radio en pantalla del control tactil (pelota / jugador) | TouchControls (scripts/ui/touch_controls.gd) | SIN CONECTAR |  |
| 107 | `CtrlBallScreenRadiusMax` | 112 | constante | 0.0273 | 0x4cc | 0x5854c4 | no establecida | radio en pantalla del control tactil (pelota / jugador) | TouchControls (scripts/ui/touch_controls.gd) | SIN CONECTAR |  |
| 108 | `CtrlPlayerScreenRadius` | 96 | constante | 0.0234 | 0x4d0 | 0x5854dc | no establecida | radio en pantalla del control tactil (pelota / jugador) | TouchControls (scripts/ui/touch_controls.gd) | SIN CONECTAR |  |
| 109 | `GKSafeDistScale0` | 256 | constante | 0.0625 | 0x4d4 | 0x5854f4 | escala: lectura Q12 posible | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 110 | `GKSafeDistScale1` | 128 | constante | 0.0312 | 0x4d8 | 0x58550c | escala: lectura Q12 posible | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 111 | `GKSweepDistScale` | 256 | constante | 0.0625 | 0x4dc | 0x585524 | escala: lectura Q12 posible | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 112 | `GKSweepDistMin` | 67 | constante | 0.0164 | 0x4e0 | 0x58553c | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 113 | `GKSweepDistMax` | 87 | constante | 0.0212 | 0x4e4 | 0x585554 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 114 | `GKChargeAlwaysTolerance` | 90 | constante | 0.0220 | 0x4e8 | 0x58556c | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 115 | `GKChargeAlwaysTeamTolerance` | 100 | constante | 0.0244 | 0x4ec | 0x585584 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 116 | `GKChargeAlwaysTmOpTolerance` | 10 | constante | 0.0024 | 0x4f0 | 0x58559c | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 117 | `GKChargeGenTeamTolerance0` | 0 | registro cero (wzr) | 0.0000 | 0x4f4 | 0x5855b4 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR | E4: vacio |
| 118 | `GKChargeGenTeamTolerance1` | 0 | registro cero (wzr) | 0.0000 | 0x4f8 | 0x5855cc | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR | E4: vacio |
| 119 | `GKChargeGenOppoTolerance0` | 1 | constante | 0.0002 | 0x4fc | 0x5855e4 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 120 | `GKChargeGenOppoTolerance1` | 25 | constante | 0.0061 | 0x500 | 0x585600 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 121 | `GKCloseDownDefenderRange` | 15 | constante | 0.0037 | 0x514 | 0x585668 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 122 | `GKCloseDownDefenderTolerance` | 8192 | constante | 2.0000 | 0x518 | 0x585680 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 123 | `GKCloseDownTeamMateGoalDist` | 6 | constante | 0.0015 | 0x51c | 0x585698 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 124 | `GKCloseDownTeamMateXDist` | 6 | constante | 0.0015 | 0x520 | 0x5856b0 | no establecida | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 125 | `GKCloseDown1V1Rate0` | 614 | constante | 0.1499 | 0x524 | 0x5856c8 | escala: lectura Q12 posible | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 126 | `GKCloseDown1V1Rate1` | 768 | constante | 0.1875 | 0x528 | 0x5856e0 | escala: lectura Q12 posible | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 127 | `GKCloseDown2V1Rate0` | 307 | constante | 0.0750 | 0x52c | 0x5856f8 | escala: lectura Q12 posible | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 128 | `GKCloseDown2V1Rate1` | 256 | constante | 0.0625 | 0x530 | 0x585710 | escala: lectura Q12 posible | arquero: distancias de atajada, velocidad, presencia, achique, salidas | Goalkeeper / KeeperTuning (scripts/goalkeeper/goalkeeper.gd, keeper_tuning.gd) | SIN CONECTAR |  |
| 129 | `PosChangeFrames` | 120 | constante | 0.0293 | 0x534 | 0x585728 | cuadros (nombre) | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 130 | `CentreXPercentPOS` | 20 | constante | 0.0049 | 0x538 | 0x585740 | por ciento (nombre) | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 131 | `CentreXPercentOOP` | 27 | constante | 0.0066 | 0x53c | 0x585758 | por ciento (nombre) | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 132 | `BackLinePOS` | 85 | constante | 0.0208 | 0x540 | 0x585770 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 133 | `BackLineOOP` | 60 | constante | 0.0146 | 0x544 | 0x585788 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 134 | `BackLineSetPiece` | 24 | constante | 0.0059 | 0x54c | 0x5857a0 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 135 | `BackLineKickOffAdjust` | -5 | constante | -0.0012 | 0x548 | 0x5857b8 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 136 | `MidLinePercentPOS` | 75 | constante | 0.0183 | 0x550 | 0x5857d0 | por ciento (nombre) | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 137 | `MidLinePercentOOP` | 25 | constante | 0.0061 | 0x554 | 0x5857e8 | por ciento (nombre) | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 138 | `WidthOpenPlay` | 60 | constante | 0.0146 | 0x558 | 0x585800 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | IMPLEMENTADO: `UcsParams.WIDTH_OPEN_PLAY` (scripts/ai/ucs_params.gd:36) en `TeamBrain._attack`, puesto `width` (scripts/ai/team_brain.gd:159) |  |
| 139 | `WidthFreeKick` | 50 | constante | 0.0122 | 0x55c | 0x585818 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 140 | `WidthFreeKickDirect` | 30 | constante | 0.0073 | 0x560 | 0x585830 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 141 | `WidthCorner` | 30 | constante | 0.0073 | 0x564 | 0x585848 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 142 | `WidthGoalKick` | 40 | constante | 0.0098 | 0x568 | 0x585860 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 143 | `WidthThrowIn` | 60 | constante | 0.0146 | 0x56c | 0x585878 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 144 | `WidthKickOff` | 45 | constante | 0.0110 | 0x570 | 0x585890 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 145 | `WidthOOPPercent` | 60 | constante | 0.0146 | 0x574 | 0x5858a8 | por ciento (nombre) | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 146 | `FocalFreeKickPercent` | 33 | constante | 0.0081 | 0x578 | 0x5858c0 | por ciento (nombre) | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 147 | `FocalFreeKickClampY` | 27 | constante | 0.0066 | 0x57c | 0x5858d8 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 148 | `FocalGoalKickY` | -10 | constante | -0.0024 | 0x580 | 0x5858f0 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 149 | `FocalGKBallY` | 0 | registro cero (wzr) | 0.0000 | 0x584 | 0x585908 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR | E4: vacio |
| 150 | `FocalKickOffY` | 5 | constante | 0.0012 | 0x588 | 0x585924 | no establecida | posicionamiento del equipo (lineas, ancho, punto focal en balon parado) | TeamBrain._attack / _defend (scripts/ai/team_brain.gd:134, 317), AIInput.ROLE_DEPTH (ai_input.gd:11) | SIN CONECTAR |  |
| 151 | `UrgencyLooseBallOppoFrames` | 30 | constante | 0.0073 | 0x5a4 | 0x5859b4 | cuadros (nombre) | urgencia ante pelota suelta con rival cerca | TeamBrain._loose (scripts/ai/team_brain.gd:409) | DEFINIDO SIN USO: `UcsParams.URGENCY_LOOSE_BALL_OPPO_S` (scripts/ai/ucs_params.gd:39) |  |
| 152 | `PossessionTimerLimit` | 1200 | constante | 0.2930 | 0x45c | 0x5859cc | no establecida | temporizador de posesion | sin equivalente | SIN CONECTAR |  |
| 153 | `PossessionTimerMinRank` | 2 | constante | 0.0005 | 0x460 | 0x5859e4 | no establecida | temporizador de posesion | sin equivalente | SIN CONECTAR |  |
| 154 | `PossessionTimerSetPieceReset` | 600 | constante | 0.1465 | 0x464 | 0x5859fc | no establecida | temporizador de posesion | sin equivalente | SIN CONECTAR |  |
| 155 | `PossessionTimerSetPieceResetMax` | 1 | constante | 0.0002 | 0x468 | 0x585a14 | no establecida | temporizador de posesion | sin equivalente | SIN CONECTAR |  |
| 156 | `PossessionTimerAdvantageLimit` | 150 | constante | 0.0366 | 0x46c | 0x585a30 | no establecida | temporizador de posesion | sin equivalente | SIN CONECTAR |  |
| 157 | `BotDifficultyWinRateScale` | 2048 | constante | 0.5000 | 0x5f0 | 0x585a84 | escala: lectura Q12 posible | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR |  |
| 158 | `BotDifficultyPenaltyKicks` | 2048 | constante | 0.5000 | 0x5f4 | 0x585a9c | no establecida | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR |  |
| 159 | `BotUserKickErrorScale0` | 1024 | constante | 0.2500 | 0x5a8 | 0x585ab4 | escala: lectura Q12 posible | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR |  |
| 160 | `BotUserKickErrorScale1` | 4096 | constante | 1.0000 | 0x5ac | 0x585acc | escala: lectura Q12 posible | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR |  |
| 161 | `BotStatScale0` | 3072 | constante | 0.7500 | 0x5b0 | 0x585ae4 | escala: lectura Q12 posible | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR |  |
| 162 | `BotStatScale1` | 4096 | constante | 1.0000 | 0x5b4 | 0x585afc | escala: lectura Q12 posible | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR |  |
| 163 | `BotPassAdjustGoalDist` | 50 | constante | 0.0122 | 0x5b8 | 0x585b14 | no establecida | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR |  |
| 164 | `BotPassAdjustMaxMoveDist` | 5 | constante | 0.0012 | 0x5bc | 0x585b2c | no establecida | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR |  |
| 165 | `BotPressureRate0` | 0 | registro cero (wzr) | 0.0000 | 0x5c8 | 0x585b44 | escala: lectura Q12 posible | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR | E4: vacio |
| 166 | `BotPressureRate1` | 34 | constante | 0.0083 | 0x5cc | 0x585b5c | escala: lectura Q12 posible | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR |  |
| 167 | `BotSlideRate0` | 0 | registro cero (wzr) | 0.0000 | 0x5c0 | 0x585b74 | escala: lectura Q12 posible | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR | E4: vacio |
| 168 | `BotSlideRate1` | 22 | constante | 0.0054 | 0x5c4 | 0x585b8c | escala: lectura Q12 posible | dificultad y comportamiento del bot (tasa de presion, barrida, error, pase) | AIInput (scripts/ai/ai_input.gd) | SIN CONECTAR |  |
| 169 | `BotMinKickFrames` | 30 | constante | 0.0073 | 0x5d0 | 0x585ba4 | cuadros (nombre) | tiempo del bot con la pelota antes de golpear | AIInput._decide_with_ball (scripts/ai/ai_input.gd:482) | IMPLEMENTADO: `UcsParams.BOT_MIN_KICK_S` (scripts/ai/ucs_params.gd:23) en `AIInput._decide_with_ball` (scripts/ai/ai_input.gd:539) |  |
| 170 | `BotMaxKickFrames` | 120 | constante | 0.0293 | 0x5d4 | 0x585bbc | cuadros (nombre) | tiempo del bot con la pelota antes de golpear | AIInput._decide_with_ball (scripts/ai/ai_input.gd:482) | IMPLEMENTADO: `UcsParams.BOT_MAX_KICK_S` (scripts/ai/ucs_params.gd:24) = `AIInput.CARRY_PATIENCE` (scripts/ai/ai_input.gd:31, usado en :541) |  |
| 171 | `BotUserChatPercent` | 20 | constante | 0.0049 | 0x5d8 | 0x585bd4 | por ciento (nombre) | chat del bot (no juego) | ninguno | SIN CONECTAR |  |
| 172 | `BotChatPercent` | 15 | constante | 0.0037 | 0x5dc | 0x585bfc | por ciento (nombre) | chat del bot (no juego) | ninguno | SIN CONECTAR | campo en E4: 0x5f8 |
| 173 | `AnalyticsPercentAnim` | 0 | registro cero (wzr) | 0.0000 | 0x6a4 | 0x585d94 | por ciento (nombre) | muestreo de analitica (no juego) | ninguno | SIN CONECTAR | E4: vacio |
| 174 | `AnalyticsPercentGoal` | 0 | registro cero (wzr) | 0.0000 | 0x6a8 | 0x585dac | por ciento (nombre) | muestreo de analitica (no juego) | ninguno | SIN CONECTAR | E4: vacio |
| 175 | `AnalyticsPercentRedundantTap` | 0 | registro cero (wzr) | 0.0000 | 0x6ac | 0x585dc4 | por ciento (nombre) | muestreo de analitica (no juego) | ninguno | SIN CONECTAR | E4: vacio |
| 176 | `AnalyticsPercentNIS` | 0 | registro cero (wzr) | 0.0000 | 0x6b0 | 0x585ddc | por ciento (nombre) | muestreo de analitica (no juego) | ninguno | SIN CONECTAR | E4: vacio |
| 177 | `AnalyticsPercentComm` | 0 | registro cero (wzr) | 0.0000 | 0x6b4 | 0x585df8 | por ciento (nombre) | muestreo de analitica (no juego) | ninguno | SIN CONECTAR | E4: vacio |
| 178 | `Goals` | 3 | constante | 0.0007 | 0x6dc | 0x585e78 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR |  |
| 179 | `Shots` | 1 | constante | 0.0002 | 0x6e0 | 0x585e90 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR |  |
| 180 | `Passes` | 0 | registro cero (wzr) | 0.0000 | 0x6e4 | 0x585ea8 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR | E4: vacio |
| 181 | `PassesComplete` | 1 | constante | 0.0002 | 0x6e8 | 0x585ec0 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR |  |
| 182 | `Interceptions` | 1 | constante | 0.0002 | 0x6ec | 0x585ed8 | no establecida | intercepcion / despeje (espacio, altura, urgencia) | TeamBrain._loose (scripts/ai/team_brain.gd:409), BallHandler.loose_ball_chase (ball_handler.gd:296) | SIN CONECTAR |  |
| 183 | `StandTacklesSuccess` | 1 | constante | 0.0002 | 0x6f0 | 0x585ef0 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR |  |
| 184 | `SlideTacklesSuccess` | 2 | constante | 0.0005 | 0x6f4 | 0x585f08 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR |  |
| 185 | `Kicks` | 0 | registro cero (wzr) | 0.0000 | 0x6f8 | 0x585f20 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR | E4: vacio |
| 186 | `Assists` | 2 | constante | 0.0005 | 0x6fc | 0x585f38 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR |  |
| 187 | `Fouled` | 0 | registro cero (wzr) | 0.0000 | 0x700 | 0x585f50 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR | E4: vacio |
| 188 | `Fouls` | 0 | registro cero (wzr) | 0.0000 | 0x704 | 0x585f68 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR | E4: vacio |
| 189 | `Offsides` | 0 | registro cero (wzr) | 0.0000 | 0x708 | 0x585f80 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR | E4: vacio |
| 190 | `KeeperSaves` | 1 | constante | 0.0002 | 0x70c | 0x585f98 | no establecida | puntos por estadistica del partido (inferido: lista de eventos) | ninguno (sin valoracion por estadisticas) | SIN CONECTAR |  |
| 191 | `DistDefault` | 35 | constante | 0.0085 | 0x71c | 0x58601c | no establecida | distancia de camara (inferido) | MatchCamera (scripts/camera/match_camera.gd) | SIN CONECTAR |  |
| 192 | `DistClose` | 25 | constante | 0.0061 | 0x720 | 0x586038 | no establecida | distancia de camara (inferido) | MatchCamera (scripts/camera/match_camera.gd) | SIN CONECTAR |  |
| 193 | `ReplayCameras` | 70 | constante | 0.0171 | 0x2c | 0x5860e4 | no establecida | camaras de repeticion | GoalReplay (scripts/gameplay/goal_replay.gd) | SIN CONECTAR |  |
| 194 | `MaxReconnects` | 2 | constante | 0.0005 | 0x3c | 0x5861d4 | no establecida | reconexion en linea (no juego) | ninguno | SIN CONECTAR |  |
| 195 | `LateReconnectLimit` | 10 | constante | 0.0024 | 0x40 | 0x5861ec | no establecida | reconexion en linea (no juego) | ninguno | SIN CONECTAR |  |
| 196 | `ReconnectWait` | 20 | constante | 0.0049 | 0x44 | 0x586204 | no establecida | reconexion en linea (no juego) | ninguno | SIN CONECTAR |  |
| 197 | `FriendMatchEnabled` | 1 | constante | 0.0002 | 0x48 | 0x58621c | no establecida | partidos amistosos (no juego) | ninguno | SIN CONECTAR |  |
| 198 | `FriendTimeout` | 120 | constante | 0.0293 | 0x4c | 0x586234 | no establecida | partidos amistosos (no juego) | ninguno | SIN CONECTAR |  |
| 199 | `FriendWinAmount` | 25 | constante | 0.0061 | 0x50 | 0x58624c | no establecida | partidos amistosos (no juego) | ninguno | SIN CONECTAR |  |
| 200 | `FriendConsolationAmount` | 5 | constante | 0.0012 | 0x54 | 0x586264 | no establecida | partidos amistosos (no juego) | ninguno | SIN CONECTAR |  |
| 201 | `FriendKickOffCost0` | 7 | constante | 0.0017 | 0x5c | 0x586298 | no establecida | partidos amistosos (no juego) | ninguno | SIN CONECTAR |  |
| 202 | `FriendKickOffCost1` | 12 | constante | 0.0029 | 0x60 | 0x5862b0 | no establecida | partidos amistosos (no juego) | ninguno | SIN CONECTAR |  |
| 203 | `FriendKickOffCost2` | 20 | constante | 0.0049 | 0x64 | 0x5862c8 | no establecida | partidos amistosos (no juego) | ninguno | SIN CONECTAR |  |
| 204 | `ShowAfterWins` | 1 | constante | 0.0002 | 0xac | 0x586328 | no establecida | progresion / economia (no juego) | ninguno | SIN CONECTAR |  |
| 205 | `BaseContracts` | 3 | constante | 0.0007 | 0xa4 | 0x586340 | no establecida | progresion / economia (no juego) | ninguno | SIN CONECTAR |  |
| 206 | `BaseCards` | 3 | constante | 0.0007 | 0xa8 | 0x586358 | no establecida | progresion / economia (no juego) | ninguno | SIN CONECTAR |  |
| 207 | `CardsPerPlayerClass` | 2 | constante | 0.0005 | 0xb0 | 0x586370 | no establecida | progresion / economia (no juego) | ninguno | SIN CONECTAR |  |
| 208 | `ContractsPerPlayerClass` | 2 | constante | 0.0005 | 0xb4 | 0x586388 | no establecida | progresion / economia (no juego) | ninguno | SIN CONECTAR |  |
| 209 | `CardsPerUserRank` | 2 | constante | 0.0005 | 0xb8 | 0x5863a0 | no establecida | progresion / economia (no juego) | ninguno | SIN CONECTAR |  |
| 210 | `ContractsPerUserRank` | 2 | constante | 0.0005 | 0xbc | 0x5863b8 | no establecida | progresion / economia (no juego) | ninguno | SIN CONECTAR |  |
| 211 | `MatchesDownTime` | 600 | constante | 0.1465 | 0xc4 | 0x5863d0 | tiempo (nombre; unidad no establecida) | progresion / economia (no juego) | ninguno | SIN CONECTAR |  |
