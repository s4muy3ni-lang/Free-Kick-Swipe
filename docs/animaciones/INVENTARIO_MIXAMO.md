# Inventario MIXAMO y correspondencias con ACTUAL (generado)

Generado por `tools/mixamo/make_inventory_doc.py` con los datos medidos por `export_mixamo_joints`, 
`build_json_library` y `dump_inventory` (2026-11-12). Fuente: `animaciones_mixamo.zip` (`mixamo_campo.glb` 110 clips, 
`mixamo_arquero.glb` 23). Explicacion de cada columna y decisiones: [`MIXAMO_INTEGRACION.md`](MIXAMO_INTEGRACION.md).

- ACTUAL: **2024 clips** (3223 con espejos) en 111 roles.
- MIXAMO: **133 clips** (196 con espejos) en 60 roles.

## 1. Clips de Mixamo (los 133)

Suelo = altura del tobillo apoyado respecto del esqueleto del juego (percentil 10; 0 = apoyado, - hundido, + en el aire). 
Raiz = desplazamiento total reconstruido (adelante, derecha) en m. Apoyo = fraccion de cuadros con un pie apoyado. 
Contacto = instante y pie del golpe medido sobre el cuerpo del juego.

| # | Clip original | GLB | Id | Rol | Biblioteca | Dur. (s) | Bucle | Suelo (cm) | Raiz (m) | Apoyo | Contacto | Espejo |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | Angry | campo | `mx_angry` | angry | scenes | 19.17 | no | -0.3 | (0.00, 0.00) | 0.00 | - | no |
| 1 | Angry_Gesture_2 | campo | `mx_angry_gesture_2` | angry | scenes | 3.27 | no | +0.1 | (0.00, 0.00) | 0.00 | - | no |
| 2 | Arm_Stretching | campo | `mx_arm_stretching` | warmup | scenes | 8.87 | no | +0.1 | (0.00, 0.00) | 0.00 | - | no |
| 3 | Cheering | campo | `mx_cheering` | celebrate_scorer | scenes | 2.90 | no | +0.5 | (0.00, 0.00) | 0.00 | - | no |
| 4 | Cheering_2 | campo | `mx_cheering_2` | celebrate | scenes | 1.90 | no | +1.3 | (0.00, 0.00) | 0.00 | - | no |
| 5 | Chip | campo | `mx_chip` | setpiece_lob | field | 1.67 | no | -0.9 | (4.43, -0.87) | 0.44 | 0.46 s, D | si |
| 6 | Clapping | campo | `mx_clapping` | clap | scenes | 1.17 | no | +0.9 | (0.00, 0.00) | 0.00 | - | no |
| 7 | Counting | campo | `mx_counting` | referee | scenes | 13.93 | no | -1.3 | (0.00, 0.00) | 0.00 | - | no |
| 8 | Crying | campo | `mx_crying` | dejected | scenes | 6.27 | no | -0.7 | (0.00, 0.00) | 0.00 | - | no |
| 9 | Defeat | campo | `mx_defeat` | defeat_end | scenes | 7.30 | no | +0.2 | (0.00, 0.00) | 0.00 | - | no |
| 10 | Defeat_Idle_2 | campo | `mx_defeat_idle_2` | dejected | scenes | 1.73 | no | -0.3 | (0.00, 0.00) | 0.00 | - | no |
| 11 | Defeated | campo | `mx_defeated` | dejected | scenes | 6.73 | no | -0.1 | (0.00, 0.00) | 0.00 | - | no |
| 12 | Defender | campo | `mx_defender` | defend | field | 3.60 | si | -7.3 | (0.74, -4.73) | 0.08 | - | no |
| 13 | Defender_2 | campo | `mx_defender_2` | defend | field | 5.00 | si | -1.1 | (4.86, 3.43) | 0.58 | - | no |
| 14 | Disappointed | campo | `mx_disappointed` | dejected | scenes | 4.20 | no | +0.4 | (0.00, 0.00) | 0.00 | - | no |
| 15 | Dribble_2 | campo | `mx_dribble_2` | ball_dribble | field | 1.70 | no | -1.0 | (3.88, 0.68) | 0.57 | - | si |
| 16 | Excited | campo | `mx_excited` | celebrate_scorer | scenes | 6.57 | no | -0.9 | (0.00, 0.00) | 0.00 | - | no |
| 17 | Fall_Flat | campo | `mx_fall_flat` | fall | field | 2.53 | no | +3.1 | (2.81, -0.01) | 0.11 | - | si |
| 18 | Falling_Down | campo | `mx_falling_down` | fall | field | 2.27 | no | -0.3 | (-0.67, 0.46) | 0.31 | - | si |
| 19 | Fist_Pump | campo | `mx_fist_pump` | celebrate | scenes | 3.80 | no | +0.0 | (0.00, 0.00) | 0.00 | - | no |
| 20 | Fist_Pump_3 | campo | `mx_fist_pump_3` | celebrate | scenes | 1.93 | no | -1.4 | (0.00, 0.00) | 0.00 | - | no |
| 21 | Flying_Bicycle_Kick | campo | `mx_flying_bicycle_kick` | volley | field | 0.67 | no | +56.0 | (0.57, 0.02) | 0.42 | 0.58 s, I | si |
| 22 | Getting_Up_3 | campo | `mx_getting_up_3` | getup | field | 2.70 | no | -0.3 | (0.00, 0.00) | 0.00 | - | no |
| 23 | Header | campo | `mx_header` | header | field | 1.43 | no | -2.3 | (-0.02, -0.01) | 1.00 | - | si |
| 24 | Idle_To_Sprint | campo | `mx_idle_to_sprint` | start | field | 0.80 | no | -0.7 | (1.37, -0.64) | 0.52 | - | si |
| 25 | Jogging | campo | `mx_jogging` | jog | field | 2.53 | si | -0.4 | (3.17, 0.56) | 0.49 | - | no |
| 26 | Jogging_Stumble | campo | `mx_jogging_stumble` | stumble | field | 1.17 | no | -1.8 | (3.25, 0.64) | 0.49 | - | si |
| 27 | Jogging_Stumble_inplace | campo | `mx_jogging_stumble_inplace` | stumble_light | field | 1.17 | no | -1.8 | (0.00, 0.00) | 0.00 | - | si |
| 28 | Jogging_inplace | campo | `mx_jogging_inplace` | jog | field | 2.53 | si | -0.4 | (0.00, 0.00) | 0.49 | - | no |
| 29 | Jump_2 | campo | `mx_jump_2` | jump | field | 1.00 | no | +0.8 | (0.00, 0.00) | 0.00 | - | no |
| 30 | Jump_4 | campo | `mx_jump_4` | jump | field | 2.60 | no | -1.7 | (0.00, 0.00) | 0.00 | - | no |
| 31 | Jumping_Up | campo | `mx_jumping_up` | jump | field | 0.83 | no | -1.0 | (0.00, 0.00) | 0.00 | - | no |
| 32 | Loser | campo | `mx_loser` | dejected | scenes | 3.27 | no | -2.5 | (0.00, 0.00) | 0.00 | - | no |
| 33 | Neck_Stretching | campo | `mx_neck_stretching` | warmup | scenes | 3.20 | no | +0.1 | (0.00, 0.00) | 0.00 | - | no |
| 34 | Pointing_2 | campo | `mx_pointing_2` | celebrate_team | scenes | 2.77 | no | +1.5 | (0.00, 0.00) | 0.00 | - | no |
| 35 | Pointing_Forward | campo | `mx_pointing_forward` | referee | scenes | 4.70 | no | -0.4 | (0.00, 0.00) | 0.00 | - | no |
| 36 | Receive | campo | `mx_receive` | receive_chest | field | 1.40 | no | -0.9 | (0.00, 0.00) | 0.00 | - | si |
| 37 | Running | campo | `mx_running` | run | field | 0.80 | si | -1.6 | (1.73, 0.02) | 0.56 | - | no |
| 38 | Running_Tired | campo | `mx_running_tired` | run | field | 7.00 | si | -2.3 | (2.56, -0.15) | 0.98 | - | no |
| 39 | Running_inplace | campo | `mx_running_inplace` | run | field | 0.80 | si | -1.6 | (0.00, 0.00) | 0.56 | - | no |
| 40 | Sad_Idle_3 | campo | `mx_sad_idle_3` | dejected | scenes | 4.00 | no | +0.4 | (0.00, 0.00) | 0.00 | - | no |
| 41 | Shoulder_Hit_And_Fall | campo | `mx_shoulder_hit_and_fall` | fall_hit | field | 3.10 | no | +0.7 | (-0.93, -0.13) | 0.28 | - | si |
| 42 | Shove_Reaction | campo | `mx_shove_reaction` | shove | field | 2.43 | no | -0.8 | (0.00, 0.00) | 0.00 | - | no |
| 43 | Shove_Reaction_2 | campo | `mx_shove_reaction_2` | shove | field | 3.00 | no | -2.0 | (0.00, 0.00) | 0.00 | - | no |
| 44 | Soccer_Header | campo | `mx_soccer_header` | header | field | 2.37 | no | -0.7 | (0.08, 0.01) | 0.80 | - | si |
| 45 | Soccer_Idle | campo | `mx_soccer_idle` | idle_ready | scenes | 6.17 | si | -0.6 | (0.00, 0.00) | 0.00 | - | no |
| 46 | Soccer_Pass | campo | `mx_soccer_pass` | kick_pass | field | 1.60 | no | -0.1 | (-0.00, -0.00) | 1.00 | 0.47 s, D | si |
| 47 | Soccer_Spin | campo | `mx_soccer_spin` | ball_turn | field | 1.27 | no | -1.9 | (3.35, 0.76) | 0.61 | - | si |
| 48 | Sprint | campo | `mx_sprint` | loco_sprint | field | 0.50 | si | -2.4 | (2.53, 0.12) | 0.20 | - | no |
| 49 | Sprint_To_Backslide | campo | `mx_sprint_to_backslide` | fall_hit | field | 2.07 | no | -2.0 | (1.70, -1.09) | 0.14 | - | si |
| 50 | Sprint_To_Backslide_inplace | campo | `mx_sprint_to_backslide_inplace` | fall_hit | field | 2.07 | no | -2.0 | (0.00, 0.00) | 0.00 | - | si |
| 51 | Sprint_Turn | campo | `mx_sprint_turn` | turn_run | field | 1.00 | no | -0.6 | (4.46, 0.63) | 0.20 | - | si |
| 52 | Sprint_inplace | campo | `mx_sprint_inplace` | loco_sprint | field | 0.50 | si | -2.4 | (0.00, 0.00) | 0.20 | - | no |
| 53 | Standing_Fist_Pump | campo | `mx_standing_fist_pump` | celebrate | scenes | 3.77 | no | -1.6 | (0.00, 0.00) | 0.00 | - | no |
| 54 | Standing_Thumbs_Up | campo | `mx_standing_thumbs_up` | thumbs_up | scenes | 4.17 | no | -3.2 | (0.00, 0.00) | 0.00 | - | no |
| 55 | Standing_Yell_2 | campo | `mx_standing_yell_2` | angry | scenes | 4.07 | no | -1.2 | (0.00, 0.00) | 0.00 | - | no |
| 56 | Strafe_3 | campo | `mx_strafe_3` | dir_side | field | 0.63 | si | -0.9 | (-0.04, 2.22) | 0.58 | - | si |
| 57 | Strafe_3_inplace | campo | `mx_strafe_3_inplace` | dir_side | field | 0.63 | si | -1.0 | (0.00, 0.00) | 0.55 | - | si |
| 58 | Sweep_Fall | campo | `mx_sweep_fall` | fall | field | 2.50 | no | -2.9 | (-0.57, 0.67) | 0.05 | - | si |
| 59 | Taunt | campo | `mx_taunt` | celebrate_scorer | scenes | 3.87 | no | -0.9 | (0.00, 0.00) | 0.00 | - | no |
| 60 | Two_Cycle_Sprint | campo | `mx_two_cycle_sprint` | sprint | field | 1.03 | si | -2.0 | (5.15, 0.42) | 0.16 | - | no |
| 61 | Two_Cycle_Sprint_inplace | campo | `mx_two_cycle_sprint_inplace` | sprint | field | 1.03 | si | -2.0 | (0.00, 0.00) | 0.19 | - | no |
| 62 | Victory | campo | `mx_victory` | celebrate_scorer | scenes | 8.53 | no | -0.8 | (0.00, 0.00) | 0.00 | - | no |
| 63 | Walking_7 | campo | `mx_walking_7` | walk | field | 1.20 | si | -0.6 | (1.20, 0.04) | 1.00 | - | no |
| 64 | Walking_7_inplace | campo | `mx_walking_7_inplace` | walk | field | 1.20 | si | -0.6 | (0.00, 0.00) | 1.00 | - | no |
| 65 | Waving | campo | `mx_waving` | celebrate_team | scenes | 0.53 | no | +0.2 | (0.00, 0.00) | 0.00 | - | no |
| 66 | Waving_3 | campo | `mx_waving_3` | celebrate_team | scenes | 3.17 | no | +0.4 | (0.00, 0.00) | 0.00 | - | no |
| 67 | Writhing_In_Pain | campo | `mx_writhing_in_pain` | lie | field | 5.63 | no | +0.9 | (0.00, 0.00) | 0.00 | - | no |
| 68 | Yelling_While_Standing | campo | `mx_yelling_while_standing` | angry | scenes | 4.03 | no | -3.4 | (0.00, 0.00) | 0.00 | - | no |
| 69 | fallen_idle | campo | `mx_fallen_idle` | lie | field | 1.47 | si | -2.6 | (0.00, 0.00) | 0.00 | - | no |
| 70 | header_soccerball | campo | `mx_header_soccerball` | header | field | 1.90 | no | -1.0 | (0.00, -0.00) | 1.00 | - | si |
| 71 | header_soccerball_2 | campo | `mx_header_soccerball_2` | header | field | 4.20 | no | -0.9 | (0.00, 0.00) | 1.00 | - | si |
| 72 | jog_backward | campo | `mx_jog_backward` | dir_back | field | 0.77 | si | -1.1 | (-1.42, -0.02) | 0.80 | - | no |
| 73 | jog_backward_diagonal | campo | `mx_jog_backward_diagonal` | dir_back_diag | field | 0.70 | si | +1.2 | (-0.97, 0.84) | 0.76 | - | si |
| 74 | jog_backward_diagonal_2 | campo | `mx_jog_backward_diagonal_2` | dir_back_diag | field | 0.80 | si | +1.3 | (-1.24, -1.31) | 0.58 | - | si |
| 75 | jog_backward_diagonal_2_inplace | campo | `mx_jog_backward_diagonal_2_inplace` | dir_back_diag | field | 0.80 | si | +1.3 | (0.00, 0.00) | 0.58 | - | si |
| 76 | jog_backward_diagonal_inplace | campo | `mx_jog_backward_diagonal_inplace` | dir_back_diag | field | 0.70 | si | +1.2 | (0.00, 0.00) | 0.74 | - | si |
| 77 | jog_backward_inplace | campo | `mx_jog_backward_inplace` | dir_back | field | 0.77 | si | -1.1 | (0.00, 0.00) | 0.80 | - | no |
| 78 | jog_forward | campo | `mx_jog_forward` | jog | field | 0.80 | si | -0.4 | (1.59, 0.08) | 0.60 | - | no |
| 79 | jog_forward_diagonal | campo | `mx_jog_forward_diagonal` | dir_fwd_diag | field | 0.77 | si | +0.3 | (1.19, 1.28) | 0.61 | - | si |
| 80 | jog_forward_diagonal_2 | campo | `mx_jog_forward_diagonal_2` | dir_fwd_diag | field | 0.80 | si | -0.3 | (1.34, -1.21) | 0.69 | - | si |
| 81 | jog_forward_diagonal_2_inplace | campo | `mx_jog_forward_diagonal_2_inplace` | dir_fwd_diag | field | 0.80 | si | -0.3 | (0.00, 0.00) | 0.69 | - | si |
| 82 | jog_forward_diagonal_inplace | campo | `mx_jog_forward_diagonal_inplace` | dir_fwd_diag | field | 0.77 | si | +0.3 | (0.00, 0.00) | 0.61 | - | si |
| 83 | jog_forward_inplace | campo | `mx_jog_forward_inplace` | jog | field | 0.80 | si | -0.4 | (0.00, 0.00) | 0.60 | - | no |
| 84 | jog_strafe_left | campo | `mx_jog_strafe_left` | dir_side | field | 0.67 | si | +0.9 | (0.06, -1.62) | 0.68 | - | no |
| 85 | jog_strafe_left_inplace | campo | `mx_jog_strafe_left_inplace` | dir_side | field | 0.67 | si | +1.1 | (0.00, 0.00) | 0.68 | - | no |
| 86 | jog_strafe_right | campo | `mx_jog_strafe_right` | dir_side | field | 0.70 | si | -1.4 | (-0.01, 1.44) | 0.71 | - | no |
| 87 | jog_strafe_right_inplace | campo | `mx_jog_strafe_right_inplace` | dir_side | field | 0.70 | si | -1.4 | (0.00, 0.00) | 0.71 | - | no |
| 88 | kick_soccerball | campo | `mx_kick_soccerball` | kick_shot | field | 0.57 | no | -0.7 | (-0.00, 0.00) | 1.00 | 0.17 s, I | si |
| 89 | kick_soccerball_2 | campo | `mx_kick_soccerball_2` | kick_shot_hard | field | 0.50 | no | -0.6 | (-0.18, -0.05) | 0.93 | 0.14 s, D | si |
| 90 | kick_up_soccerball | campo | `mx_kick_up_soccerball` | ball_skill | field | 1.33 | no | -1.3 | (0.00, 0.00) | 0.00 | - | si |
| 91 | kneeing_soccerball | campo | `mx_kneeing_soccerball` | ball_skill | field | 0.90 | no | -1.1 | (0.00, 0.00) | 0.00 | - | si |
| 92 | kneeing_soccerball_2 | campo | `mx_kneeing_soccerball_2` | ball_skill | field | 0.63 | no | +0.5 | (0.00, 0.00) | 0.00 | - | si |
| 93 | offensive_idle | campo | `mx_offensive_idle` | idle_ready | scenes | 10.53 | si | -0.5 | (0.00, 0.00) | 0.00 | - | no |
| 94 | receive_soccerball | campo | `mx_receive_soccerball` | receive_foot | field | 5.13 | no | -1.9 | (0.00, 0.00) | 0.00 | - | si |
| 95 | scissor_kick | campo | `mx_scissor_kick` | volley | field | 2.77 | no | +0.2 | (0.17, -0.37) | 0.40 | 0.65 s, D | si |
| 96 | soccer_penalty_kick | campo | `mx_soccer_penalty_kick` | setpiece_shot | field | 1.50 | no | -1.2 | (2.62, -0.35) | 0.73 | 0.73 s, D | si |
| 97 | soccer_tackle | campo | `mx_soccer_tackle` | slide | field | 2.73 | no | -6.4 | (2.97, 0.44) | 0.24 | - | si |
| 98 | soccer_tackle_2 | campo | `mx_soccer_tackle_2` | slide | field | 1.77 | no | -1.4 | (2.59, 0.89) | 0.25 | - | si |
| 99 | soccer_tackle_3 | campo | `mx_soccer_tackle_3` | slide | field | 2.30 | no | -4.1 | (0.57, -0.29) | 0.30 | - | si |
| 100 | soccer_trip | campo | `mx_soccer_trip` | trip | field | 1.60 | no | -10.2 | (2.15, 1.39) | 0.07 | - | si |
| 101 | stall_soccerball | campo | `mx_stall_soccerball` | ball_skill | field | 3.27 | no | -2.1 | (0.00, 0.00) | 0.00 | - | si |
| 102 | stall_soccerball_2 | campo | `mx_stall_soccerball_2` | ball_skill | field | 2.13 | no | +1.7 | (0.00, 0.00) | 0.00 | - | si |
| 103 | stall_soccerball_3 | campo | `mx_stall_soccerball_3` | ball_skill | field | 2.30 | no | -1.4 | (0.00, 0.00) | 0.00 | - | si |
| 104 | stall_soccerball_4 | campo | `mx_stall_soccerball_4` | ball_skill | field | 1.83 | no | +0.5 | (0.00, 0.00) | 0.00 | - | si |
| 105 | standing_up | campo | `mx_standing_up` | getup | field | 1.67 | no | -2.5 | (0.00, 0.00) | 0.00 | - | no |
| 106 | strike_foward_jog | campo | `mx_strike_foward_jog` | setpiece_pass | field | 1.30 | no | -0.7 | (2.45, -0.34) | 0.51 | 0.42 s, D | si |
| 107 | strike_foward_jog_inplace | campo | `mx_strike_foward_jog_inplace` | kick_shot | field | 1.30 | no | -0.7 | (0.00, 0.00) | 0.00 | 0.42 s, D | si |
| 108 | throw_in | campo | `mx_throw_in` | throw_in | field | 2.77 | no | -1.0 | (0.00, 0.00) | 0.00 | - | no |
| 109 | transition | campo | `mx_transition` | start | field | 0.77 | no | +0.9 | (-0.05, 0.09) | 1.00 | - | si |
| 110 | Goalie_Throw | arquero | `mx_goalie_throw` | gk_throw | keeper | 3.83 | no | -0.8 | (0.00, 0.00) | 0.00 | - | no |
| 111 | goalkeeper_body_block | arquero | `mx_goalkeeper_body_block` | gk_block | keeper | 2.63 | no | -3.1 | (-0.22, -0.56) | 0.39 | - | si |
| 112 | goalkeeper_body_block_2 | arquero | `mx_goalkeeper_body_block_2` | gk_block | keeper | 2.47 | no | -2.6 | (0.16, 0.47) | 0.36 | - | si |
| 113 | goalkeeper_body_block_3 | arquero | `mx_goalkeeper_body_block_3` | gk_block | keeper | 3.43 | no | -1.8 | (0.14, -0.45) | 0.46 | - | si |
| 114 | goalkeeper_catch | arquero | `mx_goalkeeper_catch` | gk_scoop | keeper | 2.10 | no | -3.1 | (0.01, 0.03) | 1.00 | - | si |
| 115 | goalkeeper_catch_2 | arquero | `mx_goalkeeper_catch_2` | gk_catch | keeper | 1.27 | no | -0.1 | (-0.04, 0.03) | 1.00 | - | si |
| 116 | goalkeeper_catch_3 | arquero | `mx_goalkeeper_catch_3` | gk_catch | keeper | 2.70 | no | -1.8 | (4.18, -1.32) | 0.57 | - | si |
| 117 | goalkeeper_catch_4 | arquero | `mx_goalkeeper_catch_4` | gk_catch | keeper | 2.73 | no | +0.5 | (0.41, -0.14) | 0.74 | - | si |
| 118 | goalkeeper_directing | arquero | `mx_goalkeeper_directing` | gk_direct | keeper | 7.17 | no | -1.6 | (0.00, 0.00) | 0.00 | - | no |
| 119 | goalkeeper_directing_2 | arquero | `mx_goalkeeper_directing_2` | gk_direct | keeper | 7.70 | no | -0.8 | (0.00, 0.00) | 0.00 | - | no |
| 120 | goalkeeper_diving_save | arquero | `mx_goalkeeper_diving_save` | gk_dive | keeper | 3.40 | no | -4.1 | (1.44, -1.47) | 0.39 | - | si |
| 121 | goalkeeper_diving_save_2 | arquero | `mx_goalkeeper_diving_save_2` | gk_dive | keeper | 3.23 | no | -3.7 | (1.47, 2.19) | 0.23 | - | si |
| 122 | goalkeeper_drop_kick | arquero | `mx_goalkeeper_drop_kick` | gk_kick | keeper | 3.90 | no | -1.3 | (0.00, 0.00) | 0.00 | 2.09 s, D | si |
| 123 | goalkeeper_idle | arquero | `mx_goalkeeper_idle` | gk_idle | keeper | 4.60 | si | -1.1 | (0.00, 0.00) | 0.00 | - | no |
| 124 | goalkeeper_idle_2 | arquero | `mx_goalkeeper_idle_2` | gk_idle_ball | keeper | 3.30 | si | +0.6 | (0.00, 0.00) | 0.00 | - | no |
| 125 | goalkeeper_miss | arquero | `mx_goalkeeper_miss` | gk_miss | keeper | 2.93 | no | -2.4 | (0.59, 0.24) | 0.78 | - | si |
| 126 | goalkeeper_overhand_throw | arquero | `mx_goalkeeper_overhand_throw` | gk_throw | keeper | 2.83 | no | -0.6 | (0.00, 0.00) | 0.00 | - | no |
| 127 | goalkeeper_pass | arquero | `mx_goalkeeper_pass` | gk_roll | keeper | 3.13 | no | -2.4 | (0.00, 0.00) | 0.00 | - | no |
| 128 | goalkeeper_placing_ball | arquero | `mx_goalkeeper_placing_ball` | gk_place | keeper | 3.53 | no | -1.9 | (0.00, 0.00) | 0.00 | - | no |
| 129 | goalkeeper_placing_ball_2 | arquero | `mx_goalkeeper_placing_ball_2` | gk_place | keeper | 7.97 | no | -3.2 | (0.00, 0.00) | 0.00 | - | no |
| 130 | goalkeeper_scoop | arquero | `mx_goalkeeper_scoop` | gk_scoop | keeper | 2.60 | no | -2.5 | (3.22, 0.67) | 0.79 | - | si |
| 131 | goalkeeper_sidestep | arquero | `mx_goalkeeper_sidestep` | gk_sidestep | keeper | 0.53 | si | -1.0 | (0.03, 0.47) | 0.06 | - | si |
| 132 | goalkeeper_sidestep_2 | arquero | `mx_goalkeeper_sidestep_2` | gk_sidestep | keeper | 0.50 | si | -1.0 | (0.18, 0.99) | 0.30 | - | si |

## 2. Correspondencias por rol (Mixamo -> rol del juego -> sistemas)

Con la biblioteca MIXAMO, cada rol de esta tabla usa SOLO los clips de Mixamo. La equivalencia se decidio mirando 
cada clip (movimiento, raiz, contacto), no por el nombre; ver la justificacion por grupo en MIXAMO_INTEGRACION.md.

| Rol | Clips Mixamo | Clips ACTUAL del rol | Quien lo usa en el juego |
|---|---|---|---|
| angry | 4: Angry, Angry_Gesture_2, Standing_Yell_2, Yelling_While_Standing | 6 | Reacciones (tirador que erra, arquero vencido) |
| ball_dribble | 1: Dribble_2 | 0 | Modo partido (conduccion) |
| ball_skill | 7: kick_up_soccerball, kneeing_soccerball, kneeing_soccerball_2, stall_soccerball, stall_soccerball_2, stall_soccerball_3, stall_soccerball_4 | 55 | Modo partido (amagues) |
| ball_turn | 1: Soccer_Spin | 51 | Modo partido (giro con pelota) |
| celebrate | 4: Cheering_2, Fist_Pump, Fist_Pump_3, Standing_Fist_Pump | 64 | Reacciones (gol, arquero que ataja) |
| celebrate_scorer | 4: Cheering, Excited, Taunt, Victory | 20 | Festejo del goleador |
| celebrate_team | 3: Pointing_2, Waving, Waving_3 | 43 | Festejo de los compañeros |
| clap | 1: Clapping | 18 | Reacciones (aplauso) |
| defeat_end | 1: Defeat | 1 | Modo partido (final perdido) |
| defend | 2: Defender, Defender_2 | 0 | Tiro libre: defensores llegan marcando |
| dejected | 6: Crying, Defeat_Idle_2, Defeated, Disappointed, Loser, Sad_Idle_3 | 95 | Reacciones (lamento) |
| dir_back | 2: jog_backward, jog_backward_inplace | 1 | Tiro libre: defensores que retroceden |
| dir_back_diag | 4: jog_backward_diagonal, jog_backward_diagonal_2, jog_backward_diagonal_2_inplace, jog_backward_diagonal_inplace | 1 | Tiro libre: defensores (diagonal atras) |
| dir_fwd_diag | 4: jog_forward_diagonal, jog_forward_diagonal_2, jog_forward_diagonal_2_inplace, jog_forward_diagonal_inplace | 1 | Tiro libre: defensores (diagonal) |
| dir_side | 6: Strafe_3, Strafe_3_inplace, jog_strafe_left, jog_strafe_left_inplace, jog_strafe_right, jog_strafe_right_inplace | 1 | Tiro libre: defensores (de costado) |
| fall | 3: Fall_Flat, Falling_Down, Sweep_Fall | 26 | Boton de caida; modo partido |
| fall_hit | 3: Shoulder_Hit_And_Fall, Sprint_To_Backslide, Sprint_To_Backslide_inplace | 1 | Modo partido (caidas por choque) |
| getup | 2: Getting_Up_3, standing_up | 39 | Boton de caida; modo partido |
| gk_block | 3: goalkeeper_body_block, goalkeeper_body_block_2, goalkeeper_body_block_3 | 7 | Arquero: planificador (achique) |
| gk_catch | 3: goalkeeper_catch_2, goalkeeper_catch_3, goalkeeper_catch_4 | 47 | Arquero: planificador (blocaje/recogida) |
| gk_direct | 2: goalkeeper_directing, goalkeeper_directing_2 | 2 | Modo partido (saque directo) |
| gk_dive | 2: goalkeeper_diving_save, goalkeeper_diving_save_2 | 108 | Arquero: planificador de atajadas |
| gk_idle | 1: goalkeeper_idle | 1 | Arquero (espera), menu |
| gk_idle_ball | 1: goalkeeper_idle_2 | 1 | Modo partido (arquero con la pelota) |
| gk_kick | 1: goalkeeper_drop_kick | 12 | Modo partido (saque de volea) |
| gk_miss | 1: goalkeeper_miss | 1 | Modo partido (arquero vencido) |
| gk_place | 2: goalkeeper_placing_ball, goalkeeper_placing_ball_2 | 2 | Modo partido (saque de piso) |
| gk_roll | 1: goalkeeper_pass | 2 | Modo partido (saque rodando) |
| gk_scoop | 2: goalkeeper_catch, goalkeeper_scoop | 18 | Arquero: planificador (recogida) |
| gk_sidestep | 2: goalkeeper_sidestep, goalkeeper_sidestep_2 | 1 | Arquero: planificador de atajadas |
| gk_throw | 2: Goalie_Throw, goalkeeper_overhand_throw | 4 | Modo partido (saque con la mano) |
| header | 4: Header, Soccer_Header, header_soccerball, header_soccerball_2 | 95 | Tiro libre: despeje de cabeza del defensor |
| idle_ready | 2: Soccer_Idle, offensive_idle | 8 | Tirador, compañeros, menu, minijuegos (Guante) |
| jog | 4: Jogging, Jogging_inplace, jog_forward, jog_forward_inplace | 2 | Tirador (carrera), festejos, jugadores sueltos |
| jump | 3: Jump_2, Jump_4, Jumping_Up | 1 | Modo partido (salto) |
| kick_pass | 1: Soccer_Pass | 64 | ShotCatalog (colocado) |
| kick_shot | 2: kick_soccerball, strike_foward_jog_inplace | 70 | ShotCatalog; menu (fondo) |
| kick_shot_hard | 1: kick_soccerball_2 | 43 | ShotCatalog (potente) |
| lie | 2: Writhing_In_Pain, fallen_idle | 1 | Arquero (en el suelo); modo partido |
| loco_sprint | 2: Sprint, Sprint_inplace | 5 | Festejos (carrera) |
| receive_chest | 1: Receive | 1 | Modo partido (recepcion de pecho) |
| receive_foot | 1: receive_soccerball | 3 | Modo partido (recepcion) |
| referee | 2: Counting, Pointing_Forward | 3 | Laboratorio (sin situacion en el juego) |
| run | 3: Running, Running_Tired, Running_inplace | 2 | Festejos (carrera), tirador (MIXAMO) |
| setpiece_lob | 1: Chip | 2 | Penales y tiros libres (ShotCatalog, vaselina) |
| setpiece_pass | 1: strike_foward_jog | 9 | Penales y tiros libres (ShotCatalog, colocado) |
| setpiece_shot | 1: soccer_penalty_kick | 27 | Penales y tiros libres (ShotCatalog) |
| shove | 2: Shove_Reaction, Shove_Reaction_2 | 2 | Modo partido (empujon) |
| slide | 3: soccer_tackle, soccer_tackle_2, soccer_tackle_3 | 18 | Modo partido (barrida) |
| sprint | 2: Two_Cycle_Sprint, Two_Cycle_Sprint_inplace | 5 | Tirador (MIXAMO, carrera rapida) |
| start | 2: Idle_To_Sprint, transition | 6 | Modo partido (arranques) |
| stumble | 1: Jogging_Stumble | 13 | Boton de caida; modo partido |
| stumble_light | 1: Jogging_Stumble_inplace | 1 | Modo partido |
| throw_in | 1: throw_in | 10 | Modo partido (lateral) |
| thumbs_up | 1: Standing_Thumbs_Up | 1 | Reacciones (defensor contento) |
| trip | 1: soccer_trip | 1 | Modo partido (zancadilla) |
| turn_run | 1: Sprint_Turn | 22 | Modo partido (giros) |
| volley | 2: Flying_Bicycle_Kick, scissor_kick | 54 | Modo partido (BallHandler) |
| walk | 2: Walking_7, Walking_7_inplace | 4 | Tirador (camina a la pelota) |
| warmup | 2: Arm_Stretching, Neck_Stretching | 28 | Modo partido (previa) |

## 3. Roles ACTUALES sin equivalente en Mixamo (siguen con el actual: respaldo)

| Rol | Clips ACTUAL |
|---|---|
| avoid | 12 |
| ball_sole | 1 |
| ball_start | 7 |
| ball_stop | 7 |
| ball_turn_stop | 20 |
| control_stand | 24 |
| crowd | 48 |
| dir_back_walk | 1 |
| dir_fwd_diag_walk | 1 |
| dribble_fast | 3 |
| dribble_jog | 2 |
| dribble_run | 3 |
| dribble_sprint | 3 |
| dribble_walk | 1 |
| gesture | 11 |
| gk_gesture | 22 |
| gk_getup | 21 |
| gk_idle_var | 5 |
| gk_loco | 6 |
| gk_turn | 11 |
| idle | 4 |
| idle_ball | 1 |
| idle_ball_var | 1 |
| idle_fidget | 39 |
| jostle | 17 |
| jostle_ball | 4 |
| kick_back | 21 |
| kick_cross | 2 |
| kick_flick | 1 |
| kick_lob | 8 |
| kick_pass_soft | 58 |
| kick_turn | 71 |
| loco_jog | 2 |
| loco_side | 1 |
| loco_walk | 4 |
| manager | 25 |
| mascot | 38 |
| nis_idle | 35 |
| nis_misc | 107 |
| nis_sit | 4 |
| nis_walk | 28 |
| receive | 57 |
| receive_turn | 29 |
| run_change | 1 |
| setpiece_miss | 7 |
| sidestep | 4 |
| step_stand | 3 |
| stop | 11 |
| tackle_stand | 16 |
| throw_prep | 1 |
| turn_start | 63 |
| turn_stop | 4 |
| wall | 18 |

