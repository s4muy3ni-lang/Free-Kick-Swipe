-- Rescate a pelotazos (pedido del usuario, 2026-11-14: «todo debe ser activado con el balón… girar el escenario…
-- acertijos y mecanismos buenos»): los niveles 5 a 14 son nuevos (los mandos se activan solo con la pelota y el escenario
-- gira). Online: los mismos niveles, con su tiempo limite y el minimo posible medido con la fisica del juego
-- (tests/test_rescate_mechs.gd); el turno se alarga a 150 s porque cada nivel pide varios tiros. La regla de puntaje de
-- finish_minigame no cambia (150 + 2 por segundo que sobra - 15 por error o caida).
update public.game_modes set
	description = 'Liberá la pelota dorada a pelotazos antes que el rival.',
	rules = 'Los dos resuelven el mismo nivel: palancas, botones, buzones y colores se activan pegándoles con la pelota, y el escenario gira. Gana el que la rescata con más puntos (tiros y tiempo que sobran; errores y caídas restan).',
	turn_seconds = 150,
	scene_def = '{"game": "rescate", "levels": [5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "time_limit": {"5": 90, "6": 90, "7": 90, "8": 100, "9": 110, "10": 120, "11": 110, "12": 110, "13": 110, "14": 140}, "min_time": {"5": 3.5, "6": 3.5, "7": 3.5, "8": 7.5, "9": 13.0, "10": 11.0, "11": 7.5, "12": 7.5, "13": 5.0, "14": 17.0}}'::jsonb
	where id = 'rescate';
