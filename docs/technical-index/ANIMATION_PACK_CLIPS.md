# Pack de animaciones de fútbol — tabla de los 133 clips

> Generado por `tools/animation_pack/make_report.py` el 2026-10-26 (no editar a mano: editar `tools/animation_pack/evaluation_notes.json` y regenerar).
> Resumen, comparativa con Tripo, incompatibilidades y plan de migración: [SYSTEMS/ANIMATION_PACK.md](SYSTEMS/ANIMATION_PACK.md).

**Cómo leer la tabla**

- **Dur.**: duración del clip tal como la importa Godot, comprobada contra el FBX en bruto. Entre corchetes, la duración que declara `indice_futbol.json` cuando difiere en más de 0.06 s.
- **Pistas/huesos**: pistas de animación y huesos animados (el esqueleto del pack tiene 65 huesos; el de Tripo, 23, de los que 22 tienen equivalente).
- **Raíz**: desplazamiento horizontal de la cadera entre el primer y el último fotograma, en metros del Y Bot, y entre paréntesis la velocidad equivalente **en nuestro futbolista** (× 0.867, por altura de cadera). `0` = el clip no traslada al personaje.
- **Ciclo**: diferencia angular media y máxima entre el primer y el último fotograma (0 = el bucle cierra sin salto).
- **Visto**: `sí` = se reprodujo sobre nuestro futbolista de Tripo en Godot y se miró la hoja de contacto; `gemelo` = su versión con/sin raíz sí se vio y sus rotaciones coinciden (≤ 0.16°); `no` = solo métricas.
- **Rec.**: **USAR** = cubre una necesidad del núcleo y se vio bien; *candidato* = cubre una necesidad pero falta verla; *reservar* = útil más adelante o no necesario para el núcleo; **NO** = inadecuado para lo que sugiere su nombre.
- **Estado**: `integrado` = convertido a las librerías del juego y citado por el código de juego (disparador en partido, arquero o malabares); `galería` = convertido y reproducible en la sala de práctica (con su espejo si lo tiene) pero sin disparador en el partido; `no convertido` = solo evaluado. Ver [SYSTEMS/ANIMATION_PACK.md](SYSTEMS/ANIMATION_PACK.md).
- **Ola**: 1 locomoción y balón · 2 defensa/caídas/saltos · 3 portero · 4 festejos y reacciones · 5 modo práctica/otros · 0 no aplica (gemelo o descartado).

## Portero (`animaciones/01_portero/`, 23)

| Archivo | Dur. s | Pistas/huesos | Raíz m (m/s en juego) | Ciclo (media/máx °) | Visto | Rec. | Ola | Estado | Nota |
|---|---|---|---|---|---|---|---|---|---|
| `Goalie_Throw.fbx` | 3.83 | 53/52 | 1.15 (0.26) | 13.2/81 | no | candidato | 3 | integrado | Distribucion del arquero; solo metricas (no visto). |
| `goalkeeper_body_block.fbx` | 2.63 | 53/52 | 0.70 (0.23) | 0.1/3 | sí | candidato | 3 | integrado | Bloqueo con el cuerpo; el primero se vio bien. |
| `goalkeeper_body_block_2.fbx` | 2.47 | 53/52 | 0.60 (0.21) | 0.0/0 | no | candidato | 3 | integrado | Bloqueo con el cuerpo; el primero se vio bien. |
| `goalkeeper_body_block_3.fbx` | 3.43 | 53/52 | 0.83 (0.21) | 12.1/68 | no | candidato | 3 | integrado | Bloqueo con el cuerpo; el primero se vio bien. |
| `goalkeeper_catch.fbx` | 2.10 | 53/52 | 1.17 (0.48) | 18.0/47 | sí | **USAR** | 3 | integrado | Atajada baja / media / en salto (corriendo) / en salto (parado). |
| `goalkeeper_catch_2.fbx` | 1.27 | 53/52 | 0.65 (0.44) | 14.6/49 | sí | **USAR** | 3 | integrado | Atajada baja / media / en salto (corriendo) / en salto (parado). |
| `goalkeeper_catch_3.fbx` | 2.70 | 53/52 | 4.14 (1.33) | 14.0/42 | sí | **USAR** | 3 | integrado | Atajada baja / media / en salto (corriendo) / en salto (parado). |
| `goalkeeper_catch_4.fbx` | 2.73 | 53/52 | 0.55 (0.17) | 14.0/42 | sí | **USAR** | 3 | integrado | Atajada baja / media / en salto (corriendo) / en salto (parado). |
| `goalkeeper_directing.fbx` | 7.17 | 53/52 | 1.77 (0.21) | 0.0/0 | no | reservar | 5 | integrado | Indicaciones al equipo (7 s). **Uso:** Arquero: indicaciones al equipo con la pelota en campo rival (Goalkeeper._maybe_direct_team). |
| `goalkeeper_directing_2.fbx` | 7.70 | 53/52 | 0.95 (0.11) | 0.0/0 | no | reservar | 5 | integrado | Indicaciones al equipo (7 s). **Uso:** Arquero: indicaciones defensivas con la jugada lejos (Goalkeeper._maybe_direct_team). |
| `goalkeeper_diving_save.fbx` | 3.40 | 53/52 | 2.82 (0.72) | 14.0/42 | sí | **USAR** | 3 | integrado | Estirada lateral izquierda/derecha con caida y recuperacion (3.2-3.4 s). La raiz (2.8 m) es el desplazamiento de la estirada: no quitarla sin impulsarla por codigo. |
| `goalkeeper_diving_save_2.fbx` | 3.23 | 53/52 | 2.88 (0.77) | 14.0/42 | sí | **USAR** | 3 | integrado | Estirada lateral izquierda/derecha con caida y recuperacion (3.2-3.4 s). La raiz (2.8 m) es el desplazamiento de la estirada: no quitarla sin impulsarla por codigo. |
| `goalkeeper_drop_kick.fbx` | 3.90 | 53/52 | 3.33 (0.74) | 14.1/42 | sí | **USAR** | 3 | integrado | Distribucion del arquero (saque a pie, con la mano, rodado, colocando). |
| `goalkeeper_idle.fbx` | 4.63 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 3 | integrado | Posicion base del arquero sin balon (4.6 s, ciclo sin costura). |
| `goalkeeper_idle_2.fbx` | 3.33 | 53/52 | 0 | 0.0/0 | no | candidato | 3 | integrado | Posicion base con balon; solo metricas. **Uso:** Arquero con la pelota en las manos: la pelota sigue la trayectoria de manos del clip (HOLD). |
| `goalkeeper_miss.fbx` | 2.93 | 53/52 | 0.76 (0.22) | 22.3/104 | sí | **USAR** | 3 | integrado | Salta y no llega. **Uso:** Estirada desesperada cuando ninguna atajada llega (y su espejo a la izquierda); contacto juzgado con las manos. |
| `goalkeeper_overhand_throw.fbx` | 2.83 | 53/52 | 3.79 (1.16) | 14.0/42 | sí | **USAR** | 3 | integrado | Distribucion del arquero (saque a pie, con la mano, rodado, colocando). |
| `goalkeeper_pass.fbx` | 3.13 | 53/52 | 0.79 (0.22) | 14.0/42 | sí | **USAR** | 3 | integrado | Distribucion del arquero (saque a pie, con la mano, rodado, colocando). |
| `goalkeeper_placing_ball.fbx` | 3.53 | 53/52 | 1.20 (0.29) | 14.1/42 | sí | **USAR** | 3 | integrado | Distribucion del arquero (saque a pie, con la mano, rodado, colocando). **Uso:** Saque de arco: coloca la pelota en el suelo en el instante de manos mas bajas (start_goal_kick). |
| `goalkeeper_placing_ball_2.fbx` | 7.97 | 53/52 | 3.28 (0.36) | 14.0/42 | no | candidato | 3 | integrado | Distribucion del arquero; solo metricas (no visto). **Uso:** Saque de arco (variante larga, recortada a 4.2 s). |
| `goalkeeper_scoop.fbx` | 2.60 | 53/52 | 3.93 (1.31) | 14.0/42 | sí | **USAR** | 3 | integrado | Levanta un balon rodado (2.6 s, raiz 3.9 m). |
| `goalkeeper_sidestep.fbx` | 0.53 | 53/52 | 1.20 (1.96) | 0.0/0 | sí | **USAR** | 3 | integrado | Paso lateral de 0.5 s: su sentido esta en la raiz (1.2-1.5 m); sin raiz casi no se mueve (verificado). |
| `goalkeeper_sidestep_2.fbx` | 0.50 | 53/52 | 1.50 (2.60) | 0.0/0 | no | candidato | 3 | integrado | Paso lateral derecho (raiz 1.5 m); solo metricas. |

## Con el balón (`animaciones/02_balon_pases_tiros/`, 28)

| Archivo | Dur. s | Pistas/huesos | Raíz m (m/s en juego) | Ciclo (media/máx °) | Visto | Rec. | Ola | Estado | Nota |
|---|---|---|---|---|---|---|---|---|---|
| `Chip.fbx` | 1.67 [1.33] | 53/52 | 5.03 (2.62) | 0.0/0 | sí | **USAR** | 1 | integrado | Pase elevado trotando (raiz 5.0 m); avance del pie 7.1 m/s a 0.47 s. Dura 1.67 s (el indice dice 1.33 s). **Uso:** Balon parado: centro elevado / pase alto con carrera real (SetPiece). |
| `Dribble_2.fbx` | 1.73 [1.67] | 53/52 | 4.64 (2.32) | 0.2/2 | sí | **USAR** | 1 | integrado | Trote con balon; SIN gemelo in place: raiz 4.64 m en 1.73 s (2.32 m/s en juego). El pie se adelanta solo 0.26 m: toques cerca del cuerpo. **Uso:** Marcha con pelota (CARRY_GAIT_POINTS). |
| `Flying_Bicycle_Kick.fbx` | 0.67 | 52/51 | 0.47 (0.61) | 0.0/0 | no | reservar | 5 | integrado | Remate acrobatico / cabezazo; no necesario para el nucleo. |
| `Header.fbx` | 1.43 [1.13] | 53/52 | 0 | 0.7/4 | sí | reservar | 5 | integrado | Cabezazo rapido; el juego aun no tiene cabeceo. Dura 1.43 s (el indice dice 1.13 s). |
| `Soccer_Header.fbx` | 2.37 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Remate acrobatico / cabezazo; no necesario para el nucleo. |
| `Soccer_Idle.fbx` | 6.20 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 1 | integrado | Idle con balon (6.2 s, ciclo sin costura): pies juegan con el balon. **Uso:** Reposo con pelota (CARRY_GAIT_POINTS). |
| `Soccer_Pass.fbx` | 1.60 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 1 | integrado | Pase parado; maxima velocidad de avance del pie 8.8 m/s a 0.47 s (latencia: hoy el juego golpea a 0.10 s). Alcance maximo 0.81 m. |
| `Soccer_Spin.fbx` | 1.27 | 53/52 | 3.62 (2.48) | 0.0/0 | sí | reservar | 5 | integrado | Ruleta de 360 grados con balon (habilidad). Raiz 3.6 m. |
| `Receive.fbx` | 1.40 [1.17] | 53/52 | 0 | 0.0/0 | sí | **USAR** | 1 | integrado | Control con el pecho (1.4 s; el indice dice 1.17 s). |
| `header_soccerball.fbx` | 1.90 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Remate acrobatico / cabezazo; no necesario para el nucleo. |
| `header_soccerball_2.fbx` | 4.20 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Remate acrobatico / cabezazo; no necesario para el nucleo. |
| `kick_soccerball.fbx` | 0.57 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Jueguito (modo practica). |
| `kick_soccerball_2.fbx` | 0.50 [0.57] | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Jueguito (modo practica). |
| `kick_up_soccerball.fbx` | 1.33 | 53/52 | 0.09 (0.06) | 3.2/23 | no | reservar | 5 | integrado | Jueguito (modo practica). |
| `kneeing_soccerball.fbx` | 0.90 | 53/52 | 0 | 0.3/7 | no | reservar | 5 | integrado | Jueguito (modo practica). |
| `kneeing_soccerball_2.fbx` | 0.63 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Jueguito (modo practica). |
| `offensive_idle.fbx` | 10.57 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 1 | integrado | Idle sin balon, postura ofensiva (10.6 s, ciclo sin costura). |
| `receive_soccerball.fbx` | 5.13 | 53/52 | 2.73 (0.46) | 20.7/64 | sí | candidato | 1 | integrado | Recepcion con el pie (5.1 s); el ciclo no cierra (20.7 grados) y trae 2.7 m de raiz: usar solo el primer tramo. **Uso:** Recepcion de pelota suave (situacion receive, pick 1). |
| `scissor_kick.fbx` | 2.77 | 53/52 | 0.30 (0.09) | 3.2/168 | sí | reservar | 5 | integrado | Remate acrobatico / cabezazo; no necesario para el nucleo. |
| `soccer_penalty_kick.fbx` | 1.50 [1.97] | 53/52 | 2.99 (1.73) | 17.2/63 | sí | **USAR** | 1 | integrado | Tiro parado con carrera (raiz 2.99 m); avance del pie 8.7 m/s a 0.77 s. Dura 1.5 s (el indice dice 1.97 s). **Uso:** Penal y tiro libre directo con carrera (SetPiece). |
| `stall_soccerball.fbx` | 3.27 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Jueguito (modo practica). |
| `stall_soccerball_2.fbx` | 2.13 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Jueguito (modo practica). |
| `stall_soccerball_3.fbx` | 2.30 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Jueguito (modo practica). |
| `stall_soccerball_4.fbx` | 1.83 | 53/52 | 0 | 1.0/3 | no | reservar | 5 | integrado | Jueguito (modo practica). |
| `strike_foward_jog.fbx` | 1.30 | 53/52 | 2.99 (1.99) | 0.5/11 | gemelo | reservar | 0 | integrado | Gemelo con raiz (2.99 m). **Uso:** Gemelo con raiz: pase o centro raso de balon parado con carrera (SetPiece). |
| `strike_foward_jog_inplace.fbx` | 1.30 | 53/52 | 0 | 0.5/11 | sí | **USAR** | 1 | integrado | Golpeo corriendo: velocidad de avance del pie 11.8 m/s a 0.43 s, alcance maximo 0.95 m; contacto estimado a 0.43 s. |
| `throw_in.fbx` | 2.77 | 53/52 | 3.17 (0.99) | 19.7/67 | no | reservar | 5 | integrado | Saque lateral: el partido aun no tiene reglas de banda. **Uso:** Saque de banda: la pelota va en las manos reales del esqueleto y sale a los 1.57 s (SetPiece). |
| `transition.fbx` | 0.77 | 53/52 | 0 | 3.3/23 | no | reservar | 0 | integrado | Transicion corta de patada a idle. |

## Defensa, faltas y caídas (`animaciones/03_defensa_faltas_caidas/`, 18)

| Archivo | Dur. s | Pistas/huesos | Raíz m (m/s en juego) | Ciclo (media/máx °) | Visto | Rec. | Ola | Estado | Nota |
|---|---|---|---|---|---|---|---|---|---|
| `Fall_Flat.fbx` | 2.53 | 53/52 | 3.07 (1.05) | 54.1/133 | sí | **USAR** | 2 | integrado | Caidas; ninguna cierra el ciclo (es una accion unica). |
| `Falling_Down.fbx` | 2.27 | 43/42 | 1.02 (0.39) | 33.1/108 | sí | **USAR** | 2 | integrado | Caidas; ninguna cierra el ciclo (es una accion unica). |
| `Getting_Up_3.fbx` | 2.70 | 43/42 | 0 | 24.7/89 | no | candidato | 2 | integrado | Levantarse tras una caida/falta; solo metricas. |
| `Shoulder_Hit_And_Fall.fbx` | 3.10 | 43/42 | 1.50 (0.42) | 24.1/91 | no | candidato | 2 | integrado | Contacto/empujon; solo metricas. |
| `Sweep_Fall.fbx` | 2.50 [2.33] | 53/52 | 0.66 (0.23) | 62.7/120 | sí | **USAR** | 2 | integrado | Caidas; ninguna cierra el ciclo (es una accion unica). |
| `Defender.fbx` | 3.60 | 53/52 | 8.14 (1.96) | 35.5/108 | sí | reservar | 4 | integrado | Pese a la descripcion ('corre a marcar') termina en una barrida al piso: comparar con soccer_tackle. **Uso:** Carrera larga con barrida cuando el portador pasa por su izquierda (PlayerActions.try_slide_tackle). |
| `Jogging_Stumble.fbx` | 1.17 | 53/52 | 3.33 (2.47) | 0.0/0 | gemelo | reservar | 4 | integrado | Tropiezo con raiz / lesion. **Uso:** Gemelo con raiz: trastabilla al perder una carga con el hombro (PlayerActions.stumble_root). |
| `Jogging_Stumble_inplace.fbx` | 1.17 | 53/52 | 0 | 0.0/0 | sí | reservar | 4 | integrado | Tropiezo trotando (verificado). |
| `Shove_Reaction.fbx` | 2.43 | 53/52 | 2.66 (0.95) | 0.0/1 | no | candidato | 2 | integrado | Contacto/empujon; solo metricas. |
| `Shove_Reaction_2.fbx` | 3.00 | 53/52 | 0 | 0.0/0 | no | candidato | 2 | integrado | Contacto/empujon; solo metricas. |
| `Writhing_In_Pain.fbx` | 5.67 | 43/42 | 0 | 0.0/0 | no | reservar | 4 | integrado | Tropiezo con raiz / lesion. |
| `Defender_2.fbx` | 5.00 | 53/52 | 1.48 (0.26) | 19.6/126 | no | reservar | 4 | integrado | Salto para desviar el balon (barrera); solo metricas. **Uso:** Salto de bloqueo de un defensor en la linea de un disparo cercano (Footballer._try_block_jump). |
| `fallen_idle.fbx` | 1.50 | 52/51 | 0 | 0.0/0 | no | candidato | 2 | integrado | Levantarse tras una caida/falta; solo metricas. **Uso:** Tendido 0.8 s tras un golpe antes de levantarse (suffer_contact). |
| `soccer_tackle.fbx` | 2.73 | 53/52 | 3.86 (1.23) | 37.3/84 | sí | **USAR** | 2 | integrado | Barrida (2.73 s, raiz 3.9 m); termina en el piso. Avance del pie 9.3 m/s a 0.60 s. |
| `soccer_tackle_2.fbx` | 1.77 | 53/52 | 4.43 (2.17) | 37.1/84 | no | candidato | 2 | integrado | Variantes de barrida; solo metricas. |
| `soccer_tackle_3.fbx` | 2.30 | 53/52 | 0 | 0.0/0 | no | candidato | 2 | integrado | Variantes de barrida; solo metricas. |
| `soccer_trip.fbx` | 1.60 | 53/52 | 4.08 (2.21) | 48.2/103 | sí | **USAR** | 2 | integrado | Recibe una falta y cae (1.6 s). |
| `standing_up.fbx` | 1.67 | 53/52 | 0.89 (0.46) | 29.9/110 | no | candidato | 2 | integrado | Levantarse tras una caida/falta; solo metricas. |

## Movimiento en la cancha (`animaciones/04_movimiento_en_cancha/`, 36)

| Archivo | Dur. s | Pistas/huesos | Raíz m (m/s en juego) | Ciclo (media/máx °) | Visto | Rec. | Ola | Estado | Nota |
|---|---|---|---|---|---|---|---|---|---|
| `Idle_To_Sprint.fbx` | 0.80 | 43/42 | 1.60 (1.73) | 37.0/89 | sí | **USAR** | 1 | integrado | Arranque explosivo (raiz 1.6 m). Verificado: transicion plausible; el final no cierra con idle (37 grados de media). **Uso:** Arranque explosivo desde parado con sprint (Footballer._gait_overlays). |
| `Jogging.fbx` | 2.57 | 53/52 | 4.87 (1.64) | 0.0/0 | gemelo | reservar | 0 | integrado | Gemelo con raiz del trote lento. **Uso:** Gemelo con raiz: el arbitro se desplaza con su raiz medida (Referee). |
| `Jogging_inplace.fbx` | 2.57 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 1 | integrado | Trote lento (1.64 m/s en juego), ciclo de 2.57 s sin costura. **Uso:** Trote lento en la marcha (1.64 m/s, PACK_GAIT_POINTS). |
| `Running.fbx` | 0.83 | 53/52 | 2.06 (2.14) | 0.1/1 | gemelo | reservar | 0 | integrado | Gemelo con raiz. **Uso:** Gemelo con raiz: carrera del arbitro (Referee). |
| `Running_Tired.fbx` | 7.00 | 43/42 | 2.07 (0.26) | 27.6/82 | no | reservar | 0 | integrado | Carrera cansado (7 s, la costura del ciclo no cierra: 27.6 grados de media). Para estamina baja mas adelante. **Uso:** Tramo final: se para agotado a recuperar el aliento (Footballer._gait_overlays). |
| `Running_inplace.fbx` | 0.83 | 53/52 | 0 | 0.1/1 | sí | reservar | 0 | integrado | Se ve bien, pero su velocidad natural (2.14 m/s en juego) es la del trote: no aporta una marcha mas rapida. **Uso:** Carrera con pelota (CARRY_GAIT_POINTS). |
| `Sprint.fbx` | 0.53 | 43/42 | 3.16 (5.13) | 0.0/0 | gemelo | reservar | 0 | integrado | Con raiz; ver Sprint_inplace. **Uso:** Gemelo con raiz: sprint del arbitro (Referee). |
| `Sprint_To_Backslide.fbx` | 2.07 | 53/52 | 8.11 (3.40) | 0.0/0 | sí | **NO** | 0 | integrado | Pese al nombre NO es un frenado: termina tumbado en el piso y rodando. Sirve como caida, no como freno. **Uso:** Caida a toda velocidad tras un golpe: resbala con su raiz (suffer_contact). |
| `Sprint_To_Backslide_inplace.fbx` | 2.07 | 53/52 | 0 | 0.0/0 | gemelo | **NO** | 0 | integrado | Igual que Sprint_To_Backslide: es una caida al piso, no un frenado. **Uso:** La misma caida sin sitio para resbalar (cerca del borde). |
| `Sprint_Turn.fbx` | 1.00 | 53/52 | 5.13 (4.45) | 2.7/60 | sí | **USAR** | 1 | integrado | Giro a velocidad (4.45 m/s en juego, 60 grados de costura maxima). Candidato para giros cerrados. **Uso:** Giro a la carrera hacia la derecha (Footballer._gait_overlays). |
| `Sprint_inplace.fbx` | 0.53 | 43/42 | 3.16 (5.13) | 0.0/0 | sí | **USAR** | 1 | integrado | Sprint: 5.13 m/s en juego. El indice lo marca 'in place' pero TIENE 3.16 m de raiz (identico a Sprint.fbx): quitar la raiz por codigo. |
| `Strafe_3.fbx` | 0.67 [1.67] | 53/52 | 2.41 (3.14) | 0.0/0 | gemelo | reservar | 0 | integrado | Gemelo con raiz. Dura 0.67 s, no 1.67 s. **Uso:** Gemelo con raiz: desplazamiento lateral rapido del arbitro (Referee). |
| `Strafe_3_inplace.fbx` | 0.67 [1.67] | 53/52 | 0 | 0.0/0 | sí | **USAR** | 1 | integrado | Desplazamiento lateral corriendo (3.14 m/s en juego), 0.67 s (el indice dice 1.67 s). **Uso:** Lateral rapido en la mezcla direccional (marcaje a la carrera). |
| `Two_Cycle_Sprint.fbx` | 1.07 [4.40] | 53/52 | 6.50 (5.29) | 0.2/10 | no | reservar | 0 | integrado | Gemelo con raiz. Dura 1.07 s, no 4.4 s. **Uso:** Gemelo con raiz: sprint largo del arbitro (Referee). |
| `Two_Cycle_Sprint_inplace.fbx` | 1.07 [4.40] | 53/52 | 0 | 0.2/10 | no | candidato | 1 | integrado | Sprint de 2 ciclos (5.29 m/s en juego). Dura 1.07 s, NO los 4.4 s del indice. No visto. **Uso:** Sprint con pelota (CARRY_GAIT_POINTS). |
| `Walking_7.fbx` | 1.23 | 53/52 | 1.29 (0.90) | 0.1/2 | gemelo | reservar | 0 | integrado | Usar el gemelo _inplace; este solo sirve para medir la velocidad natural. **Uso:** Gemelo con raiz: el arbitro camina (Referee). |
| `Walking_7_inplace.fbx` | 1.23 | 53/52 | 0 | 0.1/2 | sí | **USAR** | 1 | integrado | Caminata; 0.90 m/s en nuestro futbolista (el juego camina a 1.8: escala x2). |
| `Jump_2.fbx` | 1.00 | 53/52 | 4.01 (3.47) | 0.0/0 | sí | **USAR** | 2 | integrado | Salto corriendo (raiz 4 m). |
| `Jump_4.fbx` | 2.60 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 2 | integrado | Salto en el lugar (2.6 s con aterrizaje); cadera 0.59-1.41 x reposo. |
| `Jumping_Up.fbx` | 0.83 | 43/42 | 0.10 (0.10) | 18.4/97 | sí | **USAR** | 2 | integrado | Salto vertical (disputa de cabeza), 0.83 s; ciclo no cierra (18 grados). |
| `jog_backward.fbx` | 0.80 | 53/52 | 1.83 (1.98) | 0.0/0 | gemelo | reservar | 0 | integrado | Gemelo con raiz de jog_backward_inplace (mismas rotaciones); sirve para medir la velocidad natural. **Uso:** Gemelo con raiz: el arbitro retrocede (Referee). |
| `jog_backward_diagonal.fbx` | 0.73 | 53/52 | 1.61 (1.91) | 0.0/0 | no | reservar | 0 | integrado | Gemelo con raiz de jog_backward_diagonal_inplace (mismas rotaciones); sirve para medir la velocidad natural. **Uso:** Gemelo con raiz: arbitro, diagonal atras-derecha (Referee). |
| `jog_backward_diagonal_2.fbx` | 0.83 | 53/52 | 2.04 (2.13) | 0.0/0 | no | reservar | 0 | integrado | Gemelo con raiz de jog_backward_diagonal_2_inplace (mismas rotaciones); sirve para medir la velocidad natural. **Uso:** Gemelo con raiz: arbitro, diagonal atras-izquierda (Referee). |
| `jog_backward_diagonal_2_inplace.fbx` | 0.83 | 53/52 | 1.43 (1.49) | 0.0/0 | no | candidato | 1 | integrado | Diagonal atras-izquierda. El indice lo marca 'in place' pero TIENE 1.43 m de raiz lateral: quitar la raiz por codigo. No visto. |
| `jog_backward_diagonal_inplace.fbx` | 0.73 | 53/52 | 0 | 0.0/0 | no | candidato | 1 | integrado | Diagonal; solo metricas. |
| `jog_backward_inplace.fbx` | 0.80 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 1 | integrado | Trote hacia atras (1.98 m/s en juego). |
| `jog_forward.fbx` | 0.83 | 53/52 | 2.07 (2.15) | 0.0/0 | gemelo | reservar | 0 | integrado | Gemelo con raiz; sirve para medir la velocidad natural. **Uso:** Gemelo con raiz: arbitro, trote de frente (Referee). |
| `jog_forward_diagonal.fbx` | 0.80 | 53/52 | 2.22 (2.40) | 0.0/0 | gemelo | reservar | 0 | integrado | Gemelo con raiz de jog_forward_diagonal_inplace (mismas rotaciones); sirve para medir la velocidad natural. **Uso:** Gemelo con raiz: arbitro, diagonal adelante-derecha (Referee). |
| `jog_forward_diagonal_2.fbx` | 0.83 | 53/52 | 2.18 (2.27) | 0.0/0 | no | reservar | 0 | integrado | Gemelo con raiz de jog_forward_diagonal_2_inplace (mismas rotaciones); sirve para medir la velocidad natural. **Uso:** Gemelo con raiz: arbitro, diagonal adelante-izquierda (Referee). |
| `jog_forward_diagonal_2_inplace.fbx` | 0.83 | 53/52 | 0 | 0.0/0 | no | candidato | 1 | integrado | Diagonal; solo metricas. |
| `jog_forward_diagonal_inplace.fbx` | 0.80 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 1 | integrado | Diagonal adelante-derecha al trote (2.40 m/s en juego). |
| `jog_forward_inplace.fbx` | 0.83 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 1 | integrado | Trote de futbol (2.15 m/s en juego); ciclo de 0.83 s sin costura. |
| `jog_strafe_left.fbx` | 0.70 | 53/52 | 2.02 (2.50) | 0.0/0 | gemelo | reservar | 0 | integrado | Gemelo con raiz de jog_strafe_left_inplace (mismas rotaciones); sirve para medir la velocidad natural. **Uso:** Gemelo con raiz: arbitro, lateral izquierda (Referee). |
| `jog_strafe_left_inplace.fbx` | 0.70 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 1 | integrado | Lateral izquierda al trote (2.50 m/s en juego). Izquierda y derecha NO tienen la misma velocidad natural. |
| `jog_strafe_right.fbx` | 0.73 | 53/52 | 1.69 (1.99) | 1.1/5 | gemelo | reservar | 0 | integrado | Gemelo con raiz de jog_strafe_right_inplace (mismas rotaciones); sirve para medir la velocidad natural. **Uso:** Gemelo con raiz: arbitro, lateral derecha (Referee). |
| `jog_strafe_right_inplace.fbx` | 0.73 | 53/52 | 0 | 1.1/5 | sí | **USAR** | 1 | integrado | Lateral derecha al trote (1.99 m/s en juego); ver asimetria con la izquierda. |

## Festejos y reacciones (`animaciones/05_festejos_y_reacciones/`, 24)

| Archivo | Dur. s | Pistas/huesos | Raíz m (m/s en juego) | Ciclo (media/máx °) | Visto | Rec. | Ola | Estado | Nota |
|---|---|---|---|---|---|---|---|---|---|
| `Taunt.fbx` | 3.87 [3.97] | 53/52 | 0 | 0.1/3 | sí | reservar | 5 | integrado | Provocacion. |
| `Angry.fbx` | 19.17 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Angry_Gesture_2.fbx` | 3.27 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 4 | integrado | Derrota/decepcion/enojo. |
| `Cheering.fbx` | 2.90 | 52/51 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Cheering_2.fbx` | 1.90 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 4 | integrado | Festejo de gol. |
| `Crying.fbx` | 6.27 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Defeat.fbx` | 7.30 [5.00] | 53/52 | 0 | 0.0/0 | sí | **USAR** | 4 | integrado | Se tapa la cara (7.3 s; el indice dice 5.0 s). |
| `Defeat_Idle_2.fbx` | 1.73 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 4 | integrado | Derrota/decepcion/enojo. |
| `Defeated.fbx` | 6.73 [6.83] | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Disappointed.fbx` | 4.20 [4.03] | 53/52 | 0 | 0.0/0 | sí | **USAR** | 4 | integrado | Derrota/decepcion/enojo. |
| `Excited.fbx` | 6.57 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Fist_Pump.fbx` | 3.80 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 4 | integrado | Festejo de gol. |
| `Fist_Pump_3.fbx` | 1.93 | 53/52 | 0 | 0.0/0 | no | candidato | 4 | integrado | Festejo con mucha euforia (1.9 s); solo metricas. |
| `Loser.fbx` | 3.27 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Sad_Idle_3.fbx` | 4.00 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 4 | integrado | Derrota/decepcion/enojo. |
| `Standing_Fist_Pump.fbx` | 3.77 | 53/52 | 0 | 0.0/0 | sí | **USAR** | 4 | integrado | Festejo de gol. |
| `Victory.fbx` | 8.53 [6.67] | 53/52 | 0 | 0.0/0 | sí | **USAR** | 4 | integrado | Festejo de victoria (8.5 s; el indice dice 6.67 s). |
| `Clapping.fbx` | 1.17 | 35/34 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Pointing_2.fbx` | 2.77 | 51/50 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Standing_Thumbs_Up.fbx` | 4.17 [4.07] | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Standing_Yell_2.fbx` | 4.07 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Yelling_While_Standing.fbx` | 4.03 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Waving.fbx` | 0.53 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |
| `Waving_3.fbx` | 3.17 | 43/42 | 0 | 0.0/0 | no | reservar | 5 | integrado | Reaccion adicional; solo metricas. |

## Árbitro y calentamiento (`animaciones/06_arbitro_y_calentamiento/`, 4)

| Archivo | Dur. s | Pistas/huesos | Raíz m (m/s en juego) | Ciclo (media/máx °) | Visto | Rec. | Ola | Estado | Nota |
|---|---|---|---|---|---|---|---|---|---|
| `Arm_Stretching.fbx` | 8.87 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Arbitro / calentamiento. |
| `Neck_Stretching.fbx` | 3.20 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Arbitro / calentamiento. |
| `Counting.fbx` | 13.93 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Arbitro / calentamiento. |
| `Pointing_Forward.fbx` | 4.70 | 53/52 | 0 | 0.0/0 | no | reservar | 5 | integrado | Arbitro / calentamiento. |

## Totales

- Estado de integración: integrado 133; galería 0; no convertido 0 (los espejos izquierdos se generan al convertir y no cuentan aparte). Las 133 animaciones están en las librerías del juego y se pueden ver todas en la sala de práctica.
- Clips: 133; vistos sobre nuestro futbolista: 60; USAR: 50; candidato: 21; reservar: 60; NO: 2.
