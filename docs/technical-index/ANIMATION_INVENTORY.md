# Inventario medido de animaciones (generado por `tests/test_animation_inventory.gd`)

Cada fila es una animación convertida (`assets/animations/pack_clips.res` / `pack_keeper.res`, 133 FBX de origen +
38 espejos `_mirror`). Medido sobre el esqueleto del futbolista a 60 Hz con `FootTrajectory`; posiciones en metros de
juego respecto al jugador. **Empuje** = punta del pie a menos de 0.15 m del suelo, más de 0.15 m por delante del
cuerpo y avanzando sobre el suelo 0.5 m/s más rápido que el cuerpo (puede impulsar la pelota hacia delante).

## Marchas y clips con pelota (detalle de empujes)

- `Dribble_2` (cuerpo a 2.32 m/s, 1.73 s): 3 empujes: 0.18 s izq.: 0.23 m delante, 0.19 m al costado izq., 0.07 m de alto, pie a 4.7 m/s, punta girada +27°; 0.60 s der.: 0.16 m delante, 0.15 m al costado der., 0.05 m de alto, pie a 3.0 m/s, punta girada +31°; 1.07 s izq.: 0.26 m delante, 0.11 m al costado izq., 0.06 m de alto, pie a 4.7 m/s, punta girada +30°; 4 apoyos; talón hasta 0.33 / 0.38 m (izq./der.).
- `Soccer_Idle` (cuerpo a 0.00 m/s, 6.20 s): 3 empujes: 0.47 s der.: 0.46 m delante, 0.15 m al costado der., 0.14 m de alto, pie a 2.9 m/s, punta girada +30°; 5.48 s der.: 0.21 m delante, 0.25 m al costado der., 0.14 m de alto, pie a 3.0 m/s, punta girada +39°; 5.60 s der.: 0.46 m delante, 0.14 m al costado der., 0.14 m de alto, pie a 2.4 m/s, punta girada +31°; 19 apoyos; talón hasta 0.35 / 0.20 m (izq./der.).
- `Running_inplace` (cuerpo a 2.14 m/s, 0.83 s): 2 empujes: 0.18 s izq.: 0.22 m delante, 0.12 m al costado izq., 0.06 m de alto, pie a 4.4 m/s, punta girada +15°; 0.58 s der.: 0.22 m delante, 0.13 m al costado der., 0.05 m de alto, pie a 3.9 m/s, punta girada +22°; 2 apoyos; talón hasta 0.31 / 0.32 m (izq./der.).
- `Two_Cycle_Sprint_inplace` (cuerpo a 5.29 m/s, 1.07 s): 4 empujes: 0.10 s izq.: 0.27 m delante, 0.12 m al costado izq., 0.13 m de alto, pie a 6.5 m/s, punta girada +18°; 0.37 s der.: 0.28 m delante, 0.12 m al costado der., 0.09 m de alto, pie a 8.5 m/s, punta girada +24°; 0.67 s izq.: 0.39 m delante, 0.18 m al costado izq., 0.06 m de alto, pie a 8.3 m/s, punta girada +25°; 0.92 s der.: 0.33 m delante, 0.09 m al costado der., 0.08 m de alto, pie a 8.8 m/s, punta girada +25°; 3 apoyos; talón hasta 0.62 / 0.62 m (izq./der.).
- `jog_forward_inplace` (cuerpo a 2.15 m/s, 0.83 s): 2 empujes: 0.17 s izq.: 0.17 m delante, 0.12 m al costado izq., 0.07 m de alto, pie a 2.9 m/s, punta girada +25°; 0.57 s der.: 0.24 m delante, 0.17 m al costado der., 0.07 m de alto, pie a 4.3 m/s, punta girada +23°; 1 apoyos; talón hasta 0.40 / 0.41 m (izq./der.).
- `Jogging_inplace` (cuerpo a 1.64 m/s, 2.57 s): 1 empujes: 1.87 s izq.: 0.17 m delante, 0.12 m al costado izq., 0.05 m de alto, pie a 2.5 m/s, punta girada +11°; 6 apoyos; talón hasta 0.34 / 0.34 m (izq./der.).
- `Sprint_inplace` (cuerpo a 5.13 m/s, 0.53 s): 2 empujes: 0.10 s izq.: 0.27 m delante, 0.10 m al costado izq., 0.14 m de alto, pie a 6.2 m/s, punta girada +13°; 0.37 s der.: 0.35 m delante, 0.15 m al costado der., 0.12 m de alto, pie a 8.6 m/s, punta girada +15°; 2 apoyos; talón hasta 0.55 / 0.53 m (izq./der.).
- `Soccer_Spin` (cuerpo a 2.48 m/s, 1.27 s): 1 empujes: 0.12 s izq.: 0.25 m delante, 0.10 m al costado izq., 0.03 m de alto, pie a 5.7 m/s, punta girada +55°; 2 apoyos; talón hasta 0.38 / 0.31 m (izq./der.).
- `receive_soccerball` (cuerpo a 0.46 m/s, 5.13 s): 8 empujes: 0.13 s izq.: 0.38 m delante, 0.19 m al costado izq., 0.10 m de alto, pie a 5.2 m/s, punta girada +2°; 0.40 s der.: 0.43 m delante, 0.15 m al costado der., 0.07 m de alto, pie a 4.9 m/s, punta girada +34°; 0.63 s izq.: 0.45 m delante, 0.23 m al costado izq., 0.04 m de alto, pie a 5.7 m/s, punta girada -5°; 0.75 s der.: 0.29 m delante, 0.11 m al costado der., 0.00 m de alto, pie a 2.5 m/s, punta girada +30°; 0.90 s izq.: 0.39 m delante, 0.15 m al costado izq., 0.10 m de alto, pie a 2.9 m/s, punta girada -5°; 1.77 s izq.: 0.32 m delante, 0.34 m al costado izq., 0.15 m de alto, pie a 2.2 m/s, punta girada -10°; 2.60 s izq.: 0.25 m delante, 0.00 m al costado der., 0.04 m de alto, pie a 2.3 m/s, punta girada -48°; 3.07 s izq.: 0.24 m delante, 0.05 m al costado der., 0.05 m de alto, pie a 1.0 m/s, punta girada -46°; 16 apoyos; talón hasta 0.28 / 0.31 m (izq./der.).
- `Receive` (cuerpo a 0.00 m/s, 1.40 s): 0 empujes; 13 apoyos; talón hasta 0.16 / 0.13 m (izq./der.).
- `stall_soccerball` (cuerpo a 0.00 m/s, 3.27 s): 0 empujes; 8 apoyos; talón hasta 0.56 / 0.02 m (izq./der.).
- `Idle_To_Sprint` (cuerpo a 1.73 m/s, 0.80 s): 1 empujes: 0.60 s der.: 0.32 m delante, 0.08 m al costado der., 0.11 m de alto, pie a 5.3 m/s, punta girada +19°; 0 apoyos; talón hasta 0.41 / 0.36 m (izq./der.).
- `Sprint_Turn` (cuerpo a 4.45 m/s, 1.00 s): 4 empujes: 0.15 s izq.: 0.34 m delante, 0.36 m al costado izq., 0.09 m de alto, pie a 10.3 m/s, punta girada +26°; 0.40 s der.: 0.44 m delante, 0.11 m al costado izq., 0.08 m de alto, pie a 10.0 m/s, punta girada +37°; 0.67 s izq.: 0.54 m delante, 0.11 m al costado izq., 0.13 m de alto, pie a 6.8 m/s, punta girada -21°; 0.92 s der.: 0.36 m delante, 0.08 m al costado der., 0.03 m de alto, pie a 9.7 m/s, punta girada +56°; 4 apoyos; talón hasta 0.53 / 0.47 m (izq./der.).

## ¿Hay conducción en carrera con toques integrados? (criterios de `FootTrajectory.dribble_verdict`)

Un toque de conducción lleva la punta del pie a ≥ 0.40 m por delante del cuerpo, a ≤ 0.12 m del suelo y 1.5 m/s más
rápida que el cuerpo (más allá de una zancada: 0.16–0.28 m al trote, 0.27–0.39 m a sprint), un toque cada 0.35–1.00 s y
como mucho 0.20 m al costado. Clips de marcha en bucle que cumplen: **ninguno**.

- `Dribble_2` (2.32 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.26 m < 0.40 m)
- `Jogging_inplace` (1.64 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.17 m < 0.40 m)
- `Jogging` (1.64 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.17 m < 0.40 m)
- `Running_inplace` (2.14 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.22 m < 0.40 m)
- `Running` (2.14 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.22 m < 0.40 m)
- `Sprint_inplace` (5.13 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.35 m < 0.40 m)
- `Sprint` (5.13 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.35 m < 0.40 m)
- `Strafe_3_inplace` (3.14 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.18 m < 0.40 m)
- `Strafe_3` (3.14 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.18 m < 0.40 m)
- `Two_Cycle_Sprint_inplace` (5.29 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.39 m < 0.40 m)
- `Two_Cycle_Sprint` (5.29 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.39 m < 0.40 m)
- `jog_backward_diagonal_2` (2.13 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.28 m < 0.40 m)
- `jog_backward_diagonal_inplace` (1.91 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.19 m < 0.40 m)
- `jog_backward_diagonal` (1.91 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.19 m < 0.40 m)
- `jog_backward_inplace` (1.98 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.28 m < 0.40 m)
- `jog_backward` (1.98 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.28 m < 0.40 m)
- `jog_forward_diagonal_2_inplace` (2.27 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.24 m < 0.40 m)
- `jog_forward_diagonal_2` (2.27 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.24 m < 0.40 m)
- `jog_forward_diagonal_inplace` (2.40 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.18 m < 0.40 m)
- `jog_forward_diagonal` (2.40 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.18 m < 0.40 m)
- `jog_forward_inplace` (2.15 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.24 m < 0.40 m)
- `jog_forward` (2.15 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.24 m < 0.40 m)
- `jog_strafe_left_inplace` (2.50 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.00 m < 0.40 m)
- `jog_strafe_left` (2.50 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.00 m < 0.40 m)
- `jog_strafe_right_inplace` (1.99 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.18 m < 0.40 m)
- `jog_strafe_right` (1.99 m/s): no sirve: ningun toque pasa de la zancada (alcance maximo del pie bajo 0.18 m < 0.40 m)

## Todas las animaciones

| Animación | FBX de origen | Rol | Dur. (s) | Bucle | Raíz (m) | Cuerpo (m/s) | Pistas enlazadas | Empujes izq./der. | Alcance bajo izq./der. (m) | Altura mín. punta izq./der. (m) | En el código |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `Angry` | `Angry.fbx` | lamento | 19.17 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.05 / -0.05 | 0.03 / 0.03 | sí |
| `Angry_Gesture_2` | `Angry_Gesture_2.fbx` | lamento | 3.27 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.06 / -0.06 | 0.03 / 0.03 | sí |
| `Arm_Stretching` | `Arm_Stretching.fbx` | calentamiento | 8.87 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.06 / -0.07 | 0.03 / 0.03 | sí |
| `Cheering` | `Cheering.fbx` | festejo | 2.90 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | -0.09 / -0.09 | 0.04 / 0.03 | sí |
| `Cheering_2` | `Cheering_2.fbx` | festejo | 1.90 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.05 / -0.11 | 0.04 / 0.03 | sí |
| `Chip` | `Chip.fbx` | practica | 1.67 | no | 4.36 | 2.62 | 24/24 | 2 / 2 | 0.42 / 0.59 | 0.01 / -0.00 | sí |
| `Chip_mirror` | `Chip.fbx` | practica | 1.67 | no | 4.36 | 2.62 | 24/24 | 2 / 2 | 0.57 / 0.42 | 0.01 / -0.01 | sí |
| `Clapping` | `Clapping.fbx` | felicitar | 1.17 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | -0.10 / -0.12 | 0.04 / 0.04 | sí |
| `Counting` | `Counting.fbx` | arbitro | 13.93 | no | 0.00 | 0.00 | 24/24 | 1 / 0 | 0.40 / 0.00 | 0.02 / 0.01 | sí |
| `Crying` | `Crying.fbx` | lamento | 6.27 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.04 / -0.04 | 0.03 / 0.03 | sí |
| `Defeat` | `Defeat.fbx` | lamento | 7.30 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | -0.02 / -0.04 | 0.04 / 0.02 | sí |
| `Defeat_Idle_2` | `Defeat_Idle_2.fbx` | lamento | 1.73 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.01 / 0.05 | 0.02 / 0.02 | sí |
| `Defeated` | `Defeated.fbx` | lamento | 6.73 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.03 / -0.01 | 0.03 / 0.02 | sí |
| `Defender` | `Defender.fbx` | entrada | 3.60 | no | 7.05 | 1.96 | 24/24 | 0 / 2 | 0.77 / 0.53 | -0.08 / 0.01 | sí |
| `Defender_2` | `Defender_2.fbx` | contacto_caida | 5.00 | no | 1.28 | 0.26 | 24/24 | 3 / 3 | 0.45 / 0.49 | 0.03 / 0.00 | sí |
| `Disappointed` | `Disappointed.fbx` | lamento | 4.20 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | -0.05 / -0.07 | 0.04 / 0.03 | sí |
| `Dribble_2` | `Dribble_2.fbx` | marcha_con_balon | 1.73 | sí | 4.02 | 2.32 | 24/24 | 2 / 1 | 0.26 / 0.17 | 0.01 / 0.01 | sí |
| `Excited` | `Excited.fbx` | festejo | 6.57 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.10 / 0.01 | 0.02 / 0.01 | sí |
| `Fall_Flat` | `Fall_Flat.fbx` | contacto_caida | 2.53 | no | 2.67 | 1.05 | 24/24 | 1 / 0 | 0.53 / -0.09 | 0.00 / 0.02 | sí |
| `Fall_Flat_mirror` | `Fall_Flat.fbx` | contacto_caida | 2.53 | no | 2.67 | 1.05 | 24/24 | 0 / 1 | -0.09 / 0.54 | 0.04 / -0.01 | sí |
| `Falling_Down` | `Falling_Down.fbx` | contacto_caida | 2.27 | no | 0.88 | 0.39 | 24/24 | 2 / 2 | 0.48 / 0.68 | 0.01 / 0.02 | sí |
| `Falling_Down_mirror` | `Falling_Down.fbx` | contacto_caida | 2.27 | no | 0.88 | 0.39 | 24/24 | 2 / 2 | 0.66 / 0.48 | 0.02 / 0.00 | sí |
| `Fist_Pump` | `Fist_Pump.fbx` | festejo | 3.80 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.04 / -0.09 | 0.03 / 0.03 | sí |
| `Fist_Pump_3` | `Fist_Pump_3.fbx` | festejo | 1.93 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.43 / 0.45 | 0.02 / 0.01 | sí |
| `Flying_Bicycle_Kick` | `Flying_Bicycle_Kick.fbx` | volea | 0.67 | no | 0.41 | 0.61 | 24/24 | 0 / 0 | -1.00 / -1.00 | 0.69 / 0.69 | sí |
| `Flying_Bicycle_Kick_mirror` | `Flying_Bicycle_Kick.fbx` | volea | 0.67 | no | 0.41 | 0.61 | 24/24 | 0 / 0 | -1.00 / -1.00 | 0.68 / 0.70 | sí |
| `Getting_Up_3` | `Getting_Up_3.fbx` | suelo | 2.70 | no | 0.04 | 0.02 | 24/24 | 0 / 0 | 0.69 / 0.80 | 0.01 / 0.03 | sí |
| `Header` | `Header.fbx` | cabezazo | 1.43 | no | 0.00 | 0.00 | 24/24 | 0 / 2 | -0.05 / 0.37 | 0.04 / 0.00 | sí |
| `Header_mirror` | `Header.fbx` | cabezazo | 1.43 | no | 0.00 | 0.00 | 24/24 | 2 / 0 | 0.37 / -0.06 | 0.02 / 0.03 | sí |
| `Idle_To_Sprint` | `Idle_To_Sprint.fbx` | habilidad | 0.80 | no | 1.39 | 1.73 | 24/24 | 0 / 1 | 0.31 / 0.32 | 0.02 / 0.00 | sí |
| `Jogging` | `Jogging.fbx` | gemelo_raiz | 2.57 | sí | 4.22 | 1.64 | 24/24 | 1 / 0 | 0.18 / 0.08 | 0.02 / 0.01 | sí |
| `Jogging_Stumble` | `Jogging_Stumble.fbx` | gemelo_raiz | 1.17 | no | 2.88 | 2.47 | 24/24 | 2 / 1 | 0.40 / 0.34 | 0.03 / -0.01 | sí |
| `Jogging_Stumble_inplace` | `Jogging_Stumble_inplace.fbx` | contacto_caida | 1.17 | no | 0.00 | 0.00 | 24/24 | 2 / 1 | 0.40 / 0.34 | 0.03 / -0.01 | sí |
| `Jogging_Stumble_inplace_mirror` | `Jogging_Stumble_inplace.fbx` | contacto_caida | 1.17 | no | 0.00 | 0.00 | 24/24 | 1 / 2 | 0.34 / 0.40 | 0.01 / 0.01 | sí |
| `Jogging_Stumble_mirror` | `Jogging_Stumble.fbx` | gemelo_raiz | 1.17 | no | 2.88 | 2.47 | 24/24 | 1 / 2 | 0.34 / 0.40 | 0.01 / 0.01 | sí |
| `Jogging_inplace` | `Jogging_inplace.fbx` | marcha | 2.57 | sí | 0.00 | 1.64 | 24/24 | 1 / 0 | 0.18 / 0.08 | 0.02 / 0.01 | sí |
| `Jump_2` | `Jump_2.fbx` | salto | 1.00 | no | 3.47 | 3.47 | 24/24 | 0 / 0 | 0.56 / 0.17 | 0.02 / 0.04 | sí |
| `Jump_4` | `Jump_4.fbx` | salto | 2.60 | no | 0.00 | 0.00 | 24/24 | 1 / 0 | 0.24 / 0.13 | 0.01 / 0.01 | sí |
| `Jumping_Up` | `Jumping_Up.fbx` | salto | 0.83 | no | 0.08 | 0.10 | 24/24 | 2 / 0 | 0.37 / -0.32 | 0.02 / 0.04 | sí |
| `Loser` | `Loser.fbx` | lamento | 3.27 | no | 0.00 | 0.00 | 24/24 | 2 / 1 | 0.21 / 0.21 | 0.01 / -0.01 | sí |
| `Neck_Stretching` | `Neck_Stretching.fbx` | calentamiento | 3.20 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.02 / -0.05 | 0.03 / 0.03 | sí |
| `Pointing_2` | `Pointing_2.fbx` | festejo | 2.77 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | -0.01 / -0.08 | 0.05 / 0.04 | sí |
| `Pointing_Forward` | `Pointing_Forward.fbx` | arbitro | 4.70 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.05 / -0.02 | 0.03 / 0.02 | sí |
| `Receive` | `Receive.fbx` | recepcion | 1.40 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.07 / -0.05 | 0.04 / 0.02 | sí |
| `Running` | `Running.fbx` | gemelo_raiz | 0.83 | sí | 1.78 | 2.14 | 24/24 | 1 / 1 | 0.23 / 0.23 | 0.02 / 0.00 | sí |
| `Running_Tired` | `Running_Tired.fbx` | cansancio | 7.00 | no | 1.79 | 0.26 | 24/24 | 2 / 2 | 0.30 / 0.42 | 0.02 / -0.00 | sí |
| `Running_inplace` | `Running_inplace.fbx` | marcha | 0.83 | sí | 0.00 | 2.14 | 24/24 | 1 / 1 | 0.23 / 0.23 | 0.02 / 0.00 | sí |
| `Sad_Idle_3` | `Sad_Idle_3.fbx` | lamento | 4.00 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | -0.02 / -0.00 | 0.04 / 0.03 | sí |
| `Shoulder_Hit_And_Fall` | `Shoulder_Hit_And_Fall.fbx` | contacto_caida | 3.10 | no | 1.30 | 0.42 | 24/24 | 3 / 3 | 0.79 / 0.81 | -0.00 / 0.03 | sí |
| `Shoulder_Hit_And_Fall_mirror` | `Shoulder_Hit_And_Fall.fbx` | contacto_caida | 3.10 | no | 1.30 | 0.42 | 24/24 | 3 / 3 | 0.80 / 0.80 | 0.03 / -0.01 | sí |
| `Shove_Reaction` | `Shove_Reaction.fbx` | contacto_caida | 2.43 | no | 2.31 | 0.95 | 24/24 | 2 / 2 | 0.32 / 0.27 | 0.03 / 0.02 | sí |
| `Shove_Reaction_2` | `Shove_Reaction_2.fbx` | contacto_caida | 3.00 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.03 / 0.01 | 0.03 / 0.00 | sí |
| `Shove_Reaction_2_mirror` | `Shove_Reaction_2.fbx` | contacto_caida | 3.00 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.02 / 0.03 | 0.01 / 0.02 | sí |
| `Shove_Reaction_mirror` | `Shove_Reaction.fbx` | contacto_caida | 2.43 | no | 2.31 | 0.95 | 24/24 | 2 / 2 | 0.28 / 0.32 | 0.03 / 0.02 | sí |
| `Soccer_Header` | `Soccer_Header.fbx` | cabezazo | 2.37 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.03 / 0.03 | 0.02 / 0.01 | sí |
| `Soccer_Header_mirror` | `Soccer_Header.fbx` | cabezazo | 2.37 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.03 / 0.03 | 0.02 / 0.01 | sí |
| `Soccer_Idle` | `Soccer_Idle.fbx` | marcha_con_balon | 6.20 | sí | 0.00 | 0.00 | 24/24 | 0 / 3 | 0.10 / 0.46 | 0.02 / 0.02 | sí |
| `Soccer_Pass` | `Soccer_Pass.fbx` | pase_tiro | 1.60 | no | 0.00 | 0.00 | 24/24 | 1 / 1 | 0.16 / 0.30 | 0.02 / 0.04 | sí |
| `Soccer_Pass_mirror` | `Soccer_Pass.fbx` | pase_tiro | 1.60 | no | 0.00 | 0.00 | 24/24 | 1 / 0 | 0.27 / 0.16 | 0.05 / 0.01 | sí |
| `Soccer_Spin` | `Soccer_Spin.fbx` | habilidad | 1.27 | no | 3.14 | 2.48 | 24/24 | 1 / 0 | 0.33 / 0.35 | 0.01 / -0.00 | sí |
| `Sprint` | `Sprint.fbx` | gemelo_raiz | 0.53 | sí | 2.74 | 5.13 | 24/24 | 1 / 1 | 0.27 / 0.36 | 0.01 / -0.01 | sí |
| `Sprint_To_Backslide` | `Sprint_To_Backslide.fbx` | gemelo_raiz | 2.07 | no | 7.03 | 3.40 | 24/24 | 0 / 0 | 0.65 / 0.34 | -0.00 / -0.02 | sí |
| `Sprint_To_Backslide_inplace` | `Sprint_To_Backslide_inplace.fbx` | habilidad | 2.07 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.65 / 0.34 | -0.00 / -0.01 | sí |
| `Sprint_Turn` | `Sprint_Turn.fbx` | habilidad | 1.00 | no | 4.45 | 4.45 | 24/24 | 2 / 2 | 0.54 / 0.44 | 0.03 / 0.00 | sí |
| `Sprint_inplace` | `Sprint_inplace.fbx` | marcha | 0.53 | sí | 2.74 | 5.13 | 24/24 | 1 / 1 | 0.27 / 0.36 | 0.01 / -0.01 | sí |
| `Standing_Fist_Pump` | `Standing_Fist_Pump.fbx` | festejo | 3.77 | no | 0.00 | 0.00 | 24/24 | 1 / 1 | 0.42 / 0.45 | 0.01 / 0.00 | sí |
| `Standing_Thumbs_Up` | `Standing_Thumbs_Up.fbx` | felicitar | 4.17 | no | 0.00 | 0.00 | 24/24 | 0 / 2 | -0.09 / 0.56 | 0.04 / -0.01 | sí |
| `Standing_Yell_2` | `Standing_Yell_2.fbx` | lamento | 4.07 | no | 0.00 | 0.00 | 24/24 | 1 / 1 | 0.43 / 0.46 | 0.01 / 0.01 | sí |
| `Strafe_3` | `Strafe_3.fbx` | gemelo_raiz | 0.67 | sí | 2.09 | 3.14 | 24/24 | 1 / 0 | 0.20 / -0.15 | 0.02 / 0.01 | sí |
| `Strafe_3_inplace` | `Strafe_3_inplace.fbx` | direccional | 0.67 | sí | 0.00 | 3.14 | 24/24 | 1 / 0 | 0.20 / -0.15 | 0.02 / 0.01 | sí |
| `Sweep_Fall` | `Sweep_Fall.fbx` | contacto_caida | 2.50 | no | 0.57 | 0.23 | 24/24 | 2 / 2 | 0.85 / 0.55 | -0.07 / -0.01 | sí |
| `Sweep_Fall_mirror` | `Sweep_Fall.fbx` | contacto_caida | 2.50 | no | 0.57 | 0.23 | 24/24 | 2 / 2 | 0.54 / 0.86 | -0.01 / -0.07 | sí |
| `Taunt` | `Taunt.fbx` | festejo | 3.87 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.37 / -0.28 | 0.01 / 0.04 | sí |
| `Two_Cycle_Sprint` | `Two_Cycle_Sprint.fbx` | gemelo_raiz | 1.07 | sí | 5.64 | 5.29 | 24/24 | 2 / 2 | 0.39 / 0.35 | 0.01 / -0.02 | sí |
| `Two_Cycle_Sprint_inplace` | `Two_Cycle_Sprint_inplace.fbx` | marcha | 1.07 | sí | 0.00 | 5.29 | 24/24 | 2 / 2 | 0.39 / 0.35 | 0.01 / -0.02 | sí |
| `Victory` | `Victory.fbx` | festejo | 8.53 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | -0.02 / -0.03 | 0.03 / 0.01 | sí |
| `Walking_7` | `Walking_7.fbx` | gemelo_raiz | 1.23 | sí | 1.12 | 0.90 | 24/24 | 1 / 1 | 0.30 / 0.29 | 0.04 / 0.02 | sí |
| `Walking_7_inplace` | `Walking_7_inplace.fbx` | marcha | 1.23 | sí | 0.00 | 0.90 | 24/24 | 1 / 1 | 0.30 / 0.29 | 0.04 / 0.02 | sí |
| `Waving` | `Waving.fbx` | festejo | 0.53 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | -0.02 / -0.01 | 0.04 / 0.03 | sí |
| `Waving_3` | `Waving_3.fbx` | festejo | 3.17 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | -0.06 / -0.04 | 0.05 / 0.03 | sí |
| `Writhing_In_Pain` | `Writhing_In_Pain.fbx` | suelo | 5.67 | sí | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.75 / 0.87 | 0.05 / 0.06 | sí |
| `Yelling_While_Standing` | `Yelling_While_Standing.fbx` | lamento | 4.03 | no | 0.00 | 0.00 | 24/24 | 1 / 1 | 0.44 / 0.47 | 0.01 / -0.01 | sí |
| `fallen_idle` | `fallen_idle.fbx` | suelo | 1.50 | sí | 0.00 | 0.00 | 24/24 | 0 / 0 | -1.00 / -0.10 | 0.18 / -0.01 | sí |
| `header_soccerball` | `header_soccerball.fbx` | cabezazo | 1.90 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.08 / -0.01 | 0.03 / 0.01 | sí |
| `header_soccerball_2` | `header_soccerball_2.fbx` | cabezazo | 4.20 | no | 0.00 | 0.00 | 24/24 | 1 / 0 | 0.25 / 0.00 | 0.02 / 0.01 | sí |
| `header_soccerball_2_mirror` | `header_soccerball_2.fbx` | cabezazo | 4.20 | no | 0.00 | 0.00 | 24/24 | 0 / 1 | -0.00 / 0.26 | 0.03 / 0.01 | sí |
| `header_soccerball_mirror` | `header_soccerball.fbx` | cabezazo | 1.90 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | -0.00 / 0.08 | 0.02 / 0.02 | sí |
| `jog_backward` | `jog_backward.fbx` | gemelo_raiz | 0.80 | sí | 1.58 | 1.98 | 24/24 | 1 / 1 | 0.30 / 0.28 | 0.03 / 0.01 | sí |
| `jog_backward_diagonal` | `jog_backward_diagonal.fbx` | gemelo_raiz | 0.73 | sí | 1.40 | 1.91 | 24/24 | 1 / 1 | 0.18 / 0.20 | 0.05 / 0.03 | sí |
| `jog_backward_diagonal_2` | `jog_backward_diagonal_2.fbx` | gemelo_raiz | 0.83 | sí | 1.77 | 2.13 | 24/24 | 1 / 0 | 0.29 / 0.15 | 0.03 / 0.02 | sí |
| `jog_backward_diagonal_2_inplace` | `jog_backward_diagonal_2_inplace.fbx` | direccional | 0.83 | sí | 1.24 | 1.49 | 24/24 | 1 / 0 | 0.29 / 0.15 | 0.03 / 0.02 | sí |
| `jog_backward_diagonal_inplace` | `jog_backward_diagonal_inplace.fbx` | direccional | 0.73 | sí | 0.00 | 1.91 | 24/24 | 1 / 1 | 0.18 / 0.20 | 0.05 / 0.03 | sí |
| `jog_backward_inplace` | `jog_backward_inplace.fbx` | direccional | 0.80 | sí | 0.00 | 1.98 | 24/24 | 1 / 1 | 0.30 / 0.28 | 0.03 / 0.01 | sí |
| `jog_forward` | `jog_forward.fbx` | gemelo_raiz | 0.83 | sí | 1.79 | 2.15 | 24/24 | 1 / 1 | 0.17 / 0.24 | 0.04 / 0.01 | sí |
| `jog_forward_diagonal` | `jog_forward_diagonal.fbx` | gemelo_raiz | 0.80 | sí | 1.92 | 2.40 | 24/24 | 1 / 1 | 0.19 / 0.17 | 0.03 / 0.02 | sí |
| `jog_forward_diagonal_2` | `jog_forward_diagonal_2.fbx` | gemelo_raiz | 0.83 | sí | 1.89 | 2.27 | 24/24 | 0 / 1 | 0.14 / 0.25 | 0.03 / 0.01 | sí |
| `jog_forward_diagonal_2_inplace` | `jog_forward_diagonal_2_inplace.fbx` | direccional | 0.83 | sí | 0.00 | 2.27 | 24/24 | 0 / 1 | 0.14 / 0.25 | 0.03 / 0.01 | sí |
| `jog_forward_diagonal_inplace` | `jog_forward_diagonal_inplace.fbx` | direccional | 0.80 | sí | 0.00 | 2.40 | 24/24 | 1 / 1 | 0.19 / 0.17 | 0.03 / 0.02 | sí |
| `jog_forward_inplace` | `jog_forward_inplace.fbx` | direccional | 0.83 | sí | 0.00 | 2.15 | 24/24 | 1 / 1 | 0.17 / 0.24 | 0.04 / 0.01 | sí |
| `jog_strafe_left` | `jog_strafe_left.fbx` | gemelo_raiz | 0.70 | sí | 1.75 | 2.50 | 24/24 | 0 / 0 | 0.11 / -0.13 | 0.04 / 0.03 | sí |
| `jog_strafe_left_inplace` | `jog_strafe_left_inplace.fbx` | direccional | 0.70 | sí | 0.00 | 2.50 | 24/24 | 0 / 0 | 0.11 / -0.13 | 0.03 / 0.03 | sí |
| `jog_strafe_right` | `jog_strafe_right.fbx` | gemelo_raiz | 0.73 | sí | 1.46 | 1.99 | 24/24 | 0 / 1 | -0.20 / 0.20 | 0.06 / 0.01 | sí |
| `jog_strafe_right_inplace` | `jog_strafe_right_inplace.fbx` | direccional | 0.73 | sí | 0.00 | 1.99 | 24/24 | 0 / 1 | -0.20 / 0.20 | 0.06 / 0.01 | sí |
| `kick_soccerball` | `kick_soccerball.fbx` | volea | 0.57 | no | 0.00 | 0.00 | 24/24 | 1 / 0 | 0.50 / -0.05 | 0.05 / 0.02 | sí |
| `kick_soccerball_2` | `kick_soccerball_2.fbx` | volea | 0.50 | no | 0.00 | 0.00 | 24/24 | 0 / 1 | -0.08 / 0.43 | 0.04 / 0.02 | sí |
| `kick_up_soccerball` | `kick_up_soccerball.fbx` | malabares | 1.33 | no | 0.08 | 0.06 | 24/24 | 2 / 0 | 0.46 / 0.02 | 0.04 / 0.01 | sí |
| `kneeing_soccerball` | `kneeing_soccerball.fbx` | malabares | 0.90 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.07 / 0.01 | 0.04 / 0.02 | sí |
| `kneeing_soccerball_2` | `kneeing_soccerball_2.fbx` | malabares | 0.63 | no | 0.00 | 0.00 | 24/24 | 0 / 1 | 0.02 / 0.16 | 0.03 / 0.02 | sí |
| `offensive_idle` | `offensive_idle.fbx` | marcha | 10.57 | sí | 0.00 | 0.00 | 24/24 | 3 / 0 | 0.23 / 0.14 | 0.03 / 0.02 | sí |
| `receive_soccerball` | `receive_soccerball.fbx` | practica | 5.13 | no | 2.36 | 0.46 | 24/24 | 6 / 2 | 0.45 / 0.43 | 0.02 / -0.00 | sí |
| `scissor_kick` | `scissor_kick.fbx` | volea | 2.77 | no | 0.26 | 0.09 | 24/24 | 1 / 0 | 0.21 / 0.26 | 0.02 / 0.02 | sí |
| `scissor_kick_mirror` | `scissor_kick.fbx` | volea | 2.77 | no | 0.26 | 0.09 | 24/24 | 0 / 1 | 0.27 / 0.23 | 0.02 / -0.00 | sí |
| `soccer_penalty_kick` | `soccer_penalty_kick.fbx` | practica | 1.50 | no | 2.59 | 1.73 | 24/24 | 1 / 1 | 0.41 / 0.49 | 0.03 / 0.01 | sí |
| `soccer_penalty_kick_mirror` | `soccer_penalty_kick.fbx` | practica | 1.50 | no | 2.59 | 1.73 | 24/24 | 1 / 1 | 0.49 / 0.42 | 0.02 / 0.01 | sí |
| `soccer_tackle` | `soccer_tackle.fbx` | entrada | 2.73 | no | 3.35 | 1.23 | 24/24 | 1 / 3 | 0.48 / 0.55 | 0.00 / -0.06 | sí |
| `soccer_tackle_2` | `soccer_tackle_2.fbx` | entrada | 1.77 | no | 3.84 | 2.17 | 24/24 | 2 / 0 | 0.49 / 0.67 | -0.02 / 0.01 | sí |
| `soccer_tackle_2_mirror` | `soccer_tackle_2.fbx` | entrada | 1.77 | no | 3.84 | 2.17 | 24/24 | 0 / 2 | 0.65 / 0.50 | 0.02 / -0.04 | sí |
| `soccer_tackle_3` | `soccer_tackle_3.fbx` | entrada | 2.30 | no | 0.00 | 0.00 | 24/24 | 1 / 1 | 0.20 / 0.22 | 0.03 / -0.04 | sí |
| `soccer_tackle_3_mirror` | `soccer_tackle_3.fbx` | entrada | 2.30 | no | 0.00 | 0.00 | 24/24 | 1 / 1 | 0.20 / 0.20 | -0.02 / 0.03 | sí |
| `soccer_tackle_mirror` | `soccer_tackle.fbx` | entrada | 2.73 | no | 3.35 | 1.23 | 24/24 | 3 / 1 | 0.53 / 0.48 | -0.05 / -0.01 | sí |
| `soccer_trip` | `soccer_trip.fbx` | contacto_caida | 1.60 | no | 3.54 | 2.21 | 24/24 | 0 / 1 | 0.80 / 0.89 | 0.06 / -0.10 | sí |
| `soccer_trip_mirror` | `soccer_trip.fbx` | contacto_caida | 1.60 | no | 3.54 | 2.21 | 24/24 | 1 / 0 | 0.87 / 0.80 | -0.09 / 0.04 | sí |
| `stall_soccerball` | `stall_soccerball.fbx` | malabares | 3.27 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.15 / 0.01 | 0.05 / 0.00 | sí |
| `stall_soccerball_2` | `stall_soccerball_2.fbx` | malabares | 2.13 | no | 0.00 | 0.00 | 24/24 | 0 / 1 | -0.07 / 0.35 | 0.04 / 0.02 | sí |
| `stall_soccerball_3` | `stall_soccerball_3.fbx` | malabares | 2.30 | no | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.12 / 0.02 | 0.04 / 0.01 | sí |
| `stall_soccerball_4` | `stall_soccerball_4.fbx` | malabares | 1.83 | no | 0.00 | 0.00 | 24/24 | 0 / 1 | 0.04 / 0.17 | 0.03 / 0.02 | sí |
| `standing_up` | `standing_up.fbx` | suelo | 1.67 | no | 0.77 | 0.46 | 24/24 | 0 / 0 | 0.12 / 0.05 | -0.01 / -0.01 | sí |
| `strike_foward_jog` | `strike_foward_jog.fbx` | gemelo_raiz | 1.30 | no | 2.59 | 1.99 | 24/24 | 1 / 1 | 0.50 / 0.52 | 0.01 / 0.02 | sí |
| `strike_foward_jog_inplace` | `strike_foward_jog_inplace.fbx` | pase_tiro | 1.30 | no | 0.00 | 0.00 | 24/24 | 1 / 1 | 0.50 / 0.52 | 0.01 / 0.02 | sí |
| `strike_foward_jog_inplace_mirror` | `strike_foward_jog_inplace.fbx` | pase_tiro | 1.30 | no | 0.00 | 0.00 | 24/24 | 1 / 1 | 0.51 / 0.50 | 0.03 / -0.00 | sí |
| `strike_foward_jog_mirror` | `strike_foward_jog.fbx` | gemelo_raiz | 1.30 | no | 2.59 | 1.99 | 24/24 | 1 / 1 | 0.51 / 0.50 | 0.03 / -0.00 | sí |
| `throw_in` | `throw_in.fbx` | practica | 2.77 | no | 2.75 | 0.99 | 24/24 | 1 / 2 | 0.55 / 0.57 | 0.01 / 0.01 | sí |
| `throw_in_mirror` | `throw_in.fbx` | practica | 2.77 | no | 2.75 | 0.99 | 24/24 | 2 / 1 | 0.56 / 0.56 | 0.02 / -0.00 | sí |
| `transition` | `transition.fbx` | malabares | 0.77 | no | 0.02 | 0.03 | 24/24 | 0 / 0 | -0.05 / -0.02 | 0.05 / 0.02 | sí |
| `Goalie_Throw` | `Goalie_Throw.fbx` | arquero | 3.83 | no | 0.99 | 0.26 | 24/24 | 3 / 0 | 0.60 / 0.06 | 0.02 / 0.02 | sí |
| `Goalie_Throw_mirror` | `Goalie_Throw.fbx` | arquero | 3.83 | no | 0.99 | 0.26 | 24/24 | 0 / 3 | 0.06 / 0.62 | 0.03 / 0.01 | sí |
| `goalkeeper_body_block` | `goalkeeper_body_block.fbx` | arquero | 2.63 | no | 0.61 | 0.23 | 24/24 | 1 / 0 | 0.27 / 0.09 | -0.06 / 0.03 | sí |
| `goalkeeper_body_block_2` | `goalkeeper_body_block_2.fbx` | arquero | 2.47 | no | 0.52 | 0.21 | 24/24 | 0 / 1 | 0.05 / 0.21 | 0.04 / -0.05 | sí |
| `goalkeeper_body_block_2_mirror` | `goalkeeper_body_block_2.fbx` | arquero | 2.47 | no | 0.52 | 0.21 | 24/24 | 1 / 0 | 0.19 / 0.06 | -0.02 / 0.03 | sí |
| `goalkeeper_body_block_3` | `goalkeeper_body_block_3.fbx` | arquero | 3.43 | no | 0.72 | 0.21 | 24/24 | 1 / 1 | 0.24 / 0.40 | -0.02 / 0.03 | sí |
| `goalkeeper_body_block_3_mirror` | `goalkeeper_body_block_3.fbx` | arquero | 3.43 | no | 0.72 | 0.21 | 24/24 | 1 / 1 | 0.39 / 0.27 | 0.03 / -0.04 | sí |
| `goalkeeper_body_block_mirror` | `goalkeeper_body_block.fbx` | arquero | 2.63 | no | 0.61 | 0.23 | 24/24 | 0 / 1 | 0.10 / 0.28 | 0.04 / -0.07 | sí |
| `goalkeeper_catch` | `goalkeeper_catch.fbx` | arquero | 2.10 | no | 1.02 | 0.48 | 24/24 | 1 / 2 | 0.24 / 0.23 | 0.00 / -0.01 | sí |
| `goalkeeper_catch_2` | `goalkeeper_catch_2.fbx` | arquero | 1.27 | no | 0.56 | 0.44 | 24/24 | 0 / 1 | 0.15 / 0.17 | 0.03 / 0.03 | sí |
| `goalkeeper_catch_2_mirror` | `goalkeeper_catch_2.fbx` | arquero | 1.27 | no | 0.56 | 0.44 | 24/24 | 1 / 0 | 0.17 / 0.15 | 0.04 / 0.02 | sí |
| `goalkeeper_catch_3` | `goalkeeper_catch_3.fbx` | arquero | 2.70 | no | 3.59 | 1.33 | 24/24 | 1 / 3 | 0.55 / 0.38 | 0.00 / 0.00 | sí |
| `goalkeeper_catch_3_mirror` | `goalkeeper_catch_3.fbx` | arquero | 2.70 | no | 3.59 | 1.33 | 24/24 | 3 / 1 | 0.37 / 0.55 | 0.01 / -0.01 | sí |
| `goalkeeper_catch_4` | `goalkeeper_catch_4.fbx` | arquero | 2.73 | no | 0.48 | 0.17 | 24/24 | 0 / 0 | 0.11 / 0.07 | 0.04 / 0.02 | sí |
| `goalkeeper_catch_4_mirror` | `goalkeeper_catch_4.fbx` | arquero | 2.73 | no | 0.48 | 0.17 | 24/24 | 0 / 0 | 0.06 / 0.11 | 0.03 / 0.03 | sí |
| `goalkeeper_catch_mirror` | `goalkeeper_catch.fbx` | arquero | 2.10 | no | 1.02 | 0.48 | 24/24 | 2 / 1 | 0.23 / 0.24 | 0.00 / -0.01 | sí |
| `goalkeeper_directing` | `goalkeeper_directing.fbx` | arquero | 7.17 | no | 1.53 | 0.21 | 24/24 | 7 / 1 | 0.64 / 0.20 | 0.02 / -0.01 | sí |
| `goalkeeper_directing_2` | `goalkeeper_directing_2.fbx` | arquero | 7.70 | no | 0.82 | 0.11 | 24/24 | 7 / 8 | 0.43 / 0.39 | 0.01 / 0.01 | sí |
| `goalkeeper_diving_save` | `goalkeeper_diving_save.fbx` | arquero | 3.40 | no | 2.44 | 0.72 | 24/24 | 1 / 0 | 0.28 / 0.03 | -0.06 / 0.03 | sí |
| `goalkeeper_diving_save_2` | `goalkeeper_diving_save_2.fbx` | arquero | 3.23 | no | 2.49 | 0.77 | 24/24 | 0 / 3 | 0.08 / 0.50 | 0.04 / -0.04 | sí |
| `goalkeeper_drop_kick` | `goalkeeper_drop_kick.fbx` | arquero | 3.90 | no | 2.89 | 0.74 | 24/24 | 2 / 1 | 0.49 / 0.34 | -0.00 / 0.01 | sí |
| `goalkeeper_drop_kick_mirror` | `goalkeeper_drop_kick.fbx` | arquero | 3.90 | no | 2.89 | 0.74 | 24/24 | 1 / 2 | 0.32 / 0.50 | 0.02 / -0.01 | sí |
| `goalkeeper_idle` | `goalkeeper_idle.fbx` | arquero | 4.63 | sí | 0.00 | 0.00 | 24/24 | 0 / 0 | 0.11 / 0.07 | 0.03 / 0.01 | sí |
| `goalkeeper_idle_2` | `goalkeeper_idle_2.fbx` | arquero | 3.33 | sí | 0.00 | 0.00 | 24/24 | 0 / 0 | -0.01 / -0.02 | 0.04 / 0.03 | sí |
| `goalkeeper_miss` | `goalkeeper_miss.fbx` | arquero | 2.93 | no | 0.66 | 0.22 | 24/24 | 0 / 0 | 0.05 / 0.49 | 0.02 / -0.00 | sí |
| `goalkeeper_miss_mirror` | `goalkeeper_miss.fbx` | arquero | 2.93 | no | 0.66 | 0.22 | 24/24 | 0 / 0 | 0.47 / 0.05 | 0.01 / 0.01 | sí |
| `goalkeeper_overhand_throw` | `goalkeeper_overhand_throw.fbx` | arquero | 2.83 | no | 3.28 | 1.16 | 24/24 | 3 / 2 | 0.69 / 0.40 | 0.02 / 0.01 | sí |
| `goalkeeper_overhand_throw_mirror` | `goalkeeper_overhand_throw.fbx` | arquero | 2.83 | no | 3.28 | 1.16 | 24/24 | 2 / 3 | 0.39 / 0.70 | 0.02 / 0.00 | sí |
| `goalkeeper_pass` | `goalkeeper_pass.fbx` | arquero | 3.13 | no | 0.69 | 0.22 | 24/24 | 1 / 2 | 0.64 / 0.30 | -0.00 / -0.00 | sí |
| `goalkeeper_pass_mirror` | `goalkeeper_pass.fbx` | arquero | 3.13 | no | 0.69 | 0.22 | 24/24 | 2 / 1 | 0.29 / 0.66 | 0.01 / -0.02 | sí |
| `goalkeeper_placing_ball` | `goalkeeper_placing_ball.fbx` | arquero | 3.53 | no | 1.04 | 0.29 | 24/24 | 1 / 3 | 0.45 / 0.48 | 0.02 / 0.00 | sí |
| `goalkeeper_placing_ball_2` | `goalkeeper_placing_ball_2.fbx` | arquero | 7.97 | no | 2.84 | 0.36 | 24/24 | 4 / 4 | 0.52 / 0.42 | -0.01 / -0.01 | sí |
| `goalkeeper_placing_ball_mirror` | `goalkeeper_placing_ball.fbx` | arquero | 3.53 | no | 1.04 | 0.29 | 24/24 | 3 / 1 | 0.48 / 0.46 | 0.01 / 0.00 | sí |
| `goalkeeper_scoop` | `goalkeeper_scoop.fbx` | arquero | 2.60 | no | 3.41 | 1.31 | 24/24 | 3 / 3 | 0.43 / 0.47 | -0.02 / -0.01 | sí |
| `goalkeeper_scoop_mirror` | `goalkeeper_scoop.fbx` | arquero | 2.60 | no | 3.41 | 1.31 | 24/24 | 3 / 3 | 0.47 / 0.43 | -0.00 / -0.03 | sí |
| `goalkeeper_sidestep` | `goalkeeper_sidestep.fbx` | arquero | 0.53 | no | 1.04 | 1.96 | 24/24 | 0 / 1 | -0.03 / 0.20 | 0.04 / 0.01 | sí |
| `goalkeeper_sidestep_2` | `goalkeeper_sidestep_2.fbx` | arquero | 0.50 | no | 1.30 | 2.60 | 24/24 | 0 / 0 | 0.03 / 0.11 | 0.04 / -0.01 | sí |
