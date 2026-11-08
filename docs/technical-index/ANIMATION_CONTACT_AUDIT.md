# Auditoría de animaciones con pelota (generada por `tests/test_animation_contact_audit.gd`)

Datos medidos sobre el esqueleto al convertir el pack (`PackLibrary.meta`). Posición de la punta del pie en el
contacto: adelante / arriba / derecha (m) respecto al origen del jugador. «Usado por»: dónde aparece el nombre del
clip (o su base, sin `_mirror`) en el código.

## Clips con contacto medido

| Clip | Función | Pie | Contacto (s) / duración | Punta del pie (adel., arriba, der.) | Velocidad del pie (m/s) | Raíz (m) | Usado por |
|---|---|---|---|---|---|---|---|
| `Chip` | practica | derecho | 0.47 / 1.67 | 0.26, 0.32, 0.54 | 7.4 | 4.36 | sí |
| `Chip_mirror` | practica | izquierdo | 0.47 / 1.67 | 0.23, 0.33, -0.54 | 7.4 | 4.36 | sí |
| `Flying_Bicycle_Kick` | volea | derecho | 0.00 / 0.67 | 0.60, 0.77, 0.17 | 0.0 | 0.41 | sí |
| `Flying_Bicycle_Kick_mirror` | volea | derecho | 0.00 / 0.67 | 0.84, 0.76, 0.17 | 0.0 | 0.41 | sí |
| `Soccer_Pass` | pase_tiro | derecho | 0.47 / 1.60 | 0.17, 0.11, 0.21 | 8.9 | 0.00 | sí |
| `Soccer_Pass_mirror` | pase_tiro | izquierdo | 0.47 / 1.60 | 0.17, 0.12, -0.19 | 8.8 | 0.00 | sí |
| `kick_soccerball` | volea | izquierdo | 0.22 / 0.57 | 0.58, 0.20, -0.25 | 5.0 | 0.00 | sí |
| `kick_soccerball_2` | volea | derecho | 0.16 / 0.50 | 0.36, 0.09, 0.21 | 3.9 | 0.00 | sí |
| `kick_up_soccerball` | malabares | izquierdo | 0.66 / 1.33 | 0.39, 0.16, -0.16 | 2.2 | 0.08 | sí |
| `scissor_kick` | volea | derecho | 0.63 / 2.77 | 0.35, 0.38, 0.22 | 5.5 | 0.26 | sí |
| `scissor_kick_mirror` | volea | izquierdo | 0.63 / 2.77 | 0.33, 0.38, -0.20 | 5.4 | 0.26 | sí |
| `soccer_penalty_kick` | practica | derecho | 0.76 / 1.50 | 0.27, 0.05, 0.33 | 8.8 | 2.59 | sí |
| `soccer_penalty_kick_mirror` | practica | izquierdo | 0.76 / 1.50 | 0.28, 0.06, -0.32 | 8.9 | 2.59 | sí |
| `strike_foward_jog` | gemelo_raiz | derecho | 0.43 / 1.30 | 0.52, 0.14, 0.25 | 12.4 | 2.59 | sí |
| `strike_foward_jog_inplace` | pase_tiro | derecho | 0.43 / 1.30 | 0.52, 0.14, 0.25 | 12.4 | 0.00 | sí |
| `strike_foward_jog_inplace_mirror` | pase_tiro | izquierdo | 0.43 / 1.30 | 0.51, 0.15, -0.24 | 12.3 | 0.00 | sí |
| `strike_foward_jog_mirror` | gemelo_raiz | izquierdo | 0.43 / 1.30 | 0.51, 0.15, -0.24 | 12.3 | 2.59 | sí |

## Clips de pelota sin contacto de pie medido

| Función | Clips (duración s, raíz m) |
|---|---|
| entrada | `Defender` (3.60, 7.05), `soccer_tackle` (2.73, 3.35), `soccer_tackle_2` (1.77, 3.84), `soccer_tackle_2_mirror` (1.77, 3.84), `soccer_tackle_3` (2.30, 0.00), `soccer_tackle_3_mirror` (2.30, 0.00), `soccer_tackle_mirror` (2.73, 3.35) |
| marcha_con_balon | `Dribble_2` (1.73, 4.02), `Soccer_Idle` (6.20, 0.00) |
| cabezazo | `Header` (1.43, 0.00), `Header_mirror` (1.43, 0.00), `Soccer_Header` (2.37, 0.00), `Soccer_Header_mirror` (2.37, 0.00), `header_soccerball` (1.90, 0.00), `header_soccerball_2` (4.20, 0.00), `header_soccerball_2_mirror` (4.20, 0.00), `header_soccerball_mirror` (1.90, 0.00) |
| habilidad | `Idle_To_Sprint` (0.80, 1.39), `Soccer_Spin` (1.27, 3.14), `Sprint_To_Backslide_inplace` (2.07, 0.00), `Sprint_Turn` (1.00, 4.45) |
| recepcion | `Receive` (1.40, 0.00) |
| malabares | `kneeing_soccerball` (0.90, 0.00), `kneeing_soccerball_2` (0.63, 0.00), `stall_soccerball` (3.27, 0.00), `stall_soccerball_2` (2.13, 0.00), `stall_soccerball_3` (2.30, 0.00), `stall_soccerball_4` (1.83, 0.00), `transition` (0.77, 0.02) |
| practica | `receive_soccerball` (5.13, 2.36), `throw_in` (2.77, 2.75), `throw_in_mirror` (2.77, 2.75) |

No hay en el pack clips de pisada (parar la pelota con la suela), de toque de empuje aislado ni de despeje: la
parada y los toques de conducción los da el pie de la marcha (`BallHandler._foot_strike`) y el despeje usa los
clips de golpeo.

Nota: `Flying_Bicycle_Kick` registra el contacto en t = 0.00 con velocidad 0 (dato de conversión no fiable). Las voleas y
cabezazos no usan este campo: `BallHandler.plan_aerial_kick` recorre la trayectoria completa de la punta del pie / la
cabeza (`paths`) y busca el instante que coincide con la pelota predicha.
