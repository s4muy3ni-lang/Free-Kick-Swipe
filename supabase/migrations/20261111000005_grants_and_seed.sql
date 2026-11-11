-- Permisos: nadie ejecuta funciones por defecto; el cliente autenticado solo la API publica. grant_purchase solo el
-- servicio (webhook de pagos con la service key, nunca la app).
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.level_for(bigint) to anon, authenticated;
grant execute on function public.create_profile(text, text), public.get_my_state(), public.change_username(text),
	public.update_identity(text, text, text, int), public.update_appearance(jsonb), public.spend_attribute_point(text),
	public.claim_reward(text, text, jsonb), public.buy_item(text, text), public.use_consumable(text),
	public.claim_season_tier(int, boolean), public.get_events(), public.heartbeat(), public.get_lobby(),
	public.get_leaderboard(text, text, int), public.get_match(uuid), public.find_match(text, int), public.cancel_search(),
	public.start_bot_match(text), public.submit_turn(uuid, text, jsonb, int), public.claim_timeout(uuid),
	public.leave_match(uuid), public.send_chat(uuid, text, text) to authenticated;
grant execute on function public.grant_purchase(uuid) to service_role;

-- Eventos: los vigentes y los que empiezan en la proxima semana (para anunciarlos).
create or replace function public.get_events() returns jsonb language sql stable security definer
		set search_path = public, pg_temp as $$
	select coalesce(jsonb_agg(to_jsonb(e) || jsonb_build_object('live', now() >= e.starts_at,
		'progress', coalesce(ep.points, 0), 'matches', coalesce(ep.matches, 0)) order by e.starts_at), '[]'::jsonb)
	from events e left join event_progress ep on ep.event_id = e.id and ep.user_id = auth.uid()
	where e.ends_at > now() and e.starts_at < now() + interval '7 days'
$$;

-- ---------------------------------------------------------------------------------------------------------------------
-- Datos iniciales (se pueden cambiar desde el backend sin actualizar la app)

insert into public.game_modes (id, name, description, rules, kind, scene_def, entry_fees, max_points_per_turn, rounds,
		turn_seconds, art, sort) values
	('penales', 'Penales', 'Uno patea, el otro ataja. Cinco cada uno y muerte súbita.',
		'Alternan tirador y arquero. El arquero elige dónde tirarse antes del tiro: si el tiro va a esa zona, ataja. 20 s por tiro.',
		'penales', '{"mode": "penalty"}', '{0,50,100,200}', 1, 5, 20, '{"icon": "penal", "color": "#2f6fe0"}', 1),
	('tiros_libres', 'Tiros libres', 'Elegí la distancia, superá la barrera y al arquero.',
		'Alternan tirador y arquero. Cada ronda se elige la distancia (más lejos, más difícil). 20 s por tiro.',
		'tiros_libres', '{"mode": "free_kick", "distances": [18, 22, 26, 30]}', '{0,50,100,200}', 1, 5, 20,
		'{"icon": "tiro_libre", "color": "#1f9d55"}', 2),
	('a_la_vista', 'A la vista', 'Plataformas enfrentadas: pegale al botón del rival y tiralo al vacío.',
		'Por turnos. Cada botón acertado es un punto; gana el primero a 3.', 'minijuego',
		'{"game": "boton_caida", "level": 1, "target": 3}', '{0,50,100}', 1, 10, 20, '{"icon": "vacio", "color": "#9b3fb8"}', 3),
	('guante', 'Guante', 'Cargá tu guante pegándole a los botones; al 100 % sale y vuela el rival.',
		'Por turnos. Cada guantazo es un punto; gana el primero a 2.', 'minijuego',
		'{"game": "guante", "level": 1, "target": 2}', '{0,50,100}', 1, 12, 20, '{"icon": "guante", "color": "#d33b3b"}', 4),
	('dardos', 'Dardos', 'Diana gigante: sectores, dobles, triples y centro.',
		'Por turnos, 5 tiros cada uno. Suma el punto real del impacto.', 'minijuego',
		'{"game": "dardos", "level": 1}', '{0,50,100}', 60, 5, 20, '{"icon": "dardos", "color": "#e0a12f"}', 5),
	('basket', 'Basket', 'Aros de 10, 15 y 20: la pelota tiene que entrar por arriba.',
		'Por turnos, 5 tiros cada uno. Tocar el aro no cuenta.', 'minijuego',
		'{"game": "enceste", "level": 1}', '{0,50,100}', 20, 5, 20, '{"icon": "basket", "color": "#e06a2f"}', 6),
	('diana', 'Diana de precisión', 'Diana gigante en el suelo, lejos: marca donde pica la pelota.',
		'Por turnos, 5 tiros cada uno. Cuenta el primer pique.', 'minijuego',
		'{"game": "dianas", "level": "Diana en el suelo"}', '{0,50,100}', 100, 5, 20, '{"icon": "diana", "color": "#2fb3c0"}', 7);

insert into public.catalog_items (id, kind, name, description, rarity, unlock, price_coins, min_level, data, sort) values
	-- Camisetas (diseños originales; los colores los elige el jugador libremente)
	('jersey_liso', 'jersey', 'Lisa', 'Camiseta de un color.', 'comun', 'free', null, 1, '{"pattern": "liso"}', 1),
	('jersey_rayas', 'jersey', 'A rayas', 'Rayas verticales de dos colores.', 'comun', 'free', null, 1, '{"pattern": "rayas"}', 2),
	('jersey_banda', 'jersey', 'Banda', 'Banda diagonal.', 'comun', 'free', null, 1, '{"pattern": "banda"}', 3),
	('jersey_aros', 'jersey', 'Aros', 'Franjas horizontales.', 'raro', 'progression', null, 3, '{"pattern": "aros"}', 4),
	('jersey_mitad', 'jersey', 'Mitad y mitad', 'Dos mitades de color.', 'raro', 'progression', null, 6, '{"pattern": "mitad"}', 5),
	('jersey_degradado', 'jersey', 'Degradé', 'Degradé de un color al otro.', 'epico', 'shop', 800, 1, '{"pattern": "degradado"}', 6),
	('jersey_clasica_retro', 'jersey', 'Clásica retro', 'Equipación clásica (línea oficial del juego).', 'epico', 'shop', 1200, 2,
		'{"pattern": "rayas_finas", "official": true, "colors": [0, 2]}', 7),
	('jersey_moderna_26', 'jersey', 'Moderna 26', 'Equipación moderna (línea oficial del juego).', 'epico', 'shop', 1200, 2,
		'{"pattern": "banda", "official": true, "colors": [3, 5]}', 8),
	('jersey_noche_t1', 'jersey', 'Noche de Estadio', 'Edición de la Temporada 1.', 'legendario', 'season', null, 1,
		'{"pattern": "degradado", "official": true, "colors": [6, 3], "season": "t1"}', 9),
	('jersey_copa_penales', 'jersey', 'Copa de Penales', 'Edición limitada del evento.', 'legendario', 'event', null, 1,
		'{"pattern": "aros", "official": true, "colors": [5, 0], "limited": true}', 10),
	-- Shorts y medias
	('shorts_liso', 'shorts', 'Short liso', '', 'comun', 'free', null, 1, '{"pattern": "liso"}', 1),
	('shorts_franja', 'shorts', 'Short con franja', '', 'comun', 'free', null, 1, '{"pattern": "franja"}', 2),
	('shorts_ribete', 'shorts', 'Short con ribete', '', 'raro', 'shop', 300, 1, '{"pattern": "ribete"}', 3),
	('socks_lisas', 'socks', 'Medias lisas', '', 'comun', 'free', null, 1, '{"pattern": "liso"}', 1),
	('socks_rayas', 'socks', 'Medias a rayas', '', 'comun', 'free', null, 1, '{"pattern": "rayas"}', 2),
	('socks_ribete', 'socks', 'Medias con ribete', '', 'raro', 'progression', null, 4, '{"pattern": "ribete"}', 3),
	-- Botines
	('boots_clasicos', 'boots', 'Clásicos', 'Cuero negro de toda la vida.', 'comun', 'free', null, 1, '{"model": "clasico", "color": 1}', 1),
	('boots_modernos', 'boots', 'Modernos', 'Livianos y de color.', 'comun', 'free', null, 1, '{"model": "moderno", "color": 0}', 2),
	('boots_pro', 'boots', 'Profesionales', 'Para los que ya saben.', 'raro', 'progression', null, 5, '{"model": "pro", "color": 3}', 3),
	('boots_relampago', 'boots', 'Relámpago', 'Edición especial.', 'epico', 'shop', 900, 3, '{"model": "pro", "color": 5, "glow": true}', 4),
	('boots_dorados', 'boots', 'Dorados', 'Edición especial.', 'legendario', 'shop', 1500, 5, '{"model": "pro", "color": 6}', 5),
	('boots_cromados', 'boots', 'Cromados', 'Diseño exclusivo de evento.', 'legendario', 'event', null, 1, '{"model": "pro", "color": 7}', 6),
	-- Balones (dos desde el comienzo)
	('ball_clasico', 'ball', 'Balón clásico', 'Gajos blancos y negros.', 'comun', 'free', null, 1, '{"design": "clasico"}', 1),
	('ball_moderno', 'ball', 'Balón moderno', 'Diseño actual.', 'comun', 'free', null, 1, '{"design": "moderno"}', 2),
	('ball_competicion', 'ball', 'Balón de competición', '', 'raro', 'progression', null, 4, '{"design": "competicion"}', 3),
	('ball_noche', 'ball', 'Balón nocturno', 'Brilla en la noche.', 'epico', 'shop', 700, 2, '{"design": "noche", "glow": true}', 4),
	('ball_llamas', 'ball', 'Balón en llamas', 'Deja una estela de fuego.', 'legendario', 'shop', 2000, 6, '{"design": "llamas", "trail": "fuego"}', 5),
	('ball_t1', 'ball', 'Balón Temporada 1', 'Edición de temporada.', 'epico', 'season', null, 1, '{"design": "temporada_1"}', 6),
	('ball_estrellas', 'ball', 'Balón estrellado', 'Recompensa de evento.', 'epico', 'event', null, 1, '{"design": "estrellas", "trail": "estrellas"}', 7),
	-- Festejos, emotes y números
	('cel_1', 'celebration', 'Festejo 1', '', 'comun', 'free', null, 1, '{"index": 1}', 1),
	('cel_2', 'celebration', 'Festejo 2', '', 'comun', 'free', null, 1, '{"index": 2}', 2),
	('cel_3', 'celebration', 'Festejo 3', '', 'comun', 'free', null, 1, '{"index": 3}', 3),
	('cel_4', 'celebration', 'Festejo 4', '', 'comun', 'free', null, 1, '{"index": 4}', 4),
	('cel_5', 'celebration', 'Festejo 5', '', 'raro', 'progression', null, 8, '{"index": 5}', 5),
	('cel_6', 'celebration', 'Festejo 6', '', 'epico', 'progression', null, 12, '{"index": 6}', 6),
	('emote_basicos', 'emote', 'Emojis básicos', '', 'comun', 'free', null, 1, '{"set": ["😀","😂","😮","👏","⚽","🧤"]}', 1),
	('emote_fuego', 'emote', 'Emojis de fuego', '', 'raro', 'shop', 250, 1, '{"set": ["🔥","😎","💪","🙌"]}', 2),
	('num_clasico', 'number_style', 'Número clásico', '', 'comun', 'free', null, 1, '{"style": "clasico"}', 1),
	('num_oro', 'number_style', 'Número dorado', '', 'raro', 'shop', 600, 1, '{"style": "oro"}', 2),
	('num_mitico_10', 'number_style', 'El 10 mítico', 'Diseño especial para el 10.', 'legendario', 'progression', null, 10,
		'{"style": "mitico", "only": [10]}', 3),
	('num_mitico_7', 'number_style', 'El 7 mítico', 'Diseño especial para el 7.', 'legendario', 'season', null, 1,
		'{"style": "mitico", "only": [7]}', 4),
	-- Consumibles (no garantizan victorias ni tocan la fisica)
	('energizante_monedas', 'consumable', 'Energizante de monedas', 'Duplica las monedas de tus próximas 3 partidas.',
		'raro', 'shop', 300, 1, '{"boost": "coins_x2", "matches": 3}', 1),
	('energizante_xp', 'consumable', 'Energizante de experiencia', 'Duplica la XP ganada durante 60 minutos.',
		'raro', 'shop', 300, 1, '{"boost": "xp_x2", "minutes": 60}', 2),
	('escudo_racha', 'consumable', 'Escudo de racha', 'Protege tu racha de victorias de una derrota.',
		'raro', 'shop', 250, 3, '{"boost": "streak_shield", "matches": 1}', 3);

insert into public.catalog_items (id, kind, name, description, rarity, unlock, price_coins, min_level, data, active, sort) values
	('cambio_nombre', 'name_change', 'Cambio de nombre', 'Preparado; sin cobrar hasta definir la política.', 'comun', 'shop',
		null, 1, '{}', false, 1);

insert into public.seasons (id, name, theme, starts_at, ends_at) values
	('t1', 'Temporada 1: Noche de Estadio', '{"color": "#6a2fb8", "accent": "#ffc23a", "art": "estadio_noche"}',
		'2026-11-01 00:00+00', '2027-02-01 00:00+00');

insert into public.season_tiers (season_id, tier, points_required, free_reward, premium_reward)
select 't1', t, t * 100,
	case when t % 5 = 0 then jsonb_build_object('item', (array['ball_t1','jersey_noche_t1','num_mitico_7','boots_cromados','ball_estrellas','jersey_copa_penales'])[t / 5])
		else jsonb_build_object('coins', 50 + t * 5) end,
	case when t % 5 = 0 then jsonb_build_object('coins', 500) else jsonb_build_object('coins', 100 + t * 10, 'xp', 50) end
from generate_series(1, 30) t;

insert into public.events (id, title, subtitle, mode, starts_at, ends_at, rules, rewards, missions, art) values
	('copa_penales_1', 'Copa de Penales', 'Dos semanas de tandas', 'penales', '2026-11-08 00:00+00', '2026-11-23 00:00+00',
		'Cada partida suma puntos; ganar suma más.', '{"per_win_points": 30, "per_play_points": 10, "tiers": [[100, {"coins": 300}], [300, {"item": "jersey_copa_penales"}]]}',
		'[{"id": "g10", "text": "Meté 10 goles"}, {"id": "w5", "text": "Ganá 5 partidas"}]', '{"color": "#2f6fe0", "icon": "penal"}'),
	('festival_tl_1', 'Festival de Tiros Libres', 'Desde lejos vale más', 'tiros_libres', '2026-11-11 00:00+00', '2026-11-26 00:00+00',
		'Cada partida suma puntos.', '{"per_win_points": 30, "per_play_points": 10, "tiers": [[100, {"coins": 300}], [300, {"item": "ball_estrellas"}]]}',
		'[{"id": "fk30", "text": "Meté un gol desde 30 m"}]', '{"color": "#1f9d55", "icon": "tiro_libre"}'),
	('copa_arcade_1', 'Copa Arcade', 'Todos los minijuegos online suman', null, '2026-11-11 00:00+00', '2026-12-02 00:00+00',
		'Cualquier partida online suma.', '{"per_win_points": 20, "per_play_points": 8, "tiers": [[150, {"coins": 400}], [400, {"item": "boots_cromados"}]]}',
		'[]', '{"color": "#9b3fb8", "icon": "arcade"}'),
	('desafio_dianas_1', 'Desafío de Dianas', 'Precisión pura', 'diana', '2026-11-16 00:00+00', '2026-11-30 00:00+00',
		'Cada partida suma puntos.', '{"per_win_points": 30, "per_play_points": 10, "tiers": [[100, {"coins": 300}]]}',
		'[]', '{"color": "#2fb3c0", "icon": "diana"}');

-- Productos con dinero real: preparados e INACTIVOS (no se cobra nada hasta aprobar el proveedor).
insert into public.store_products (id, name, grants, price_usd_cents, prices, active) values
	('pase_t1', 'Pase premium Temporada 1', '{"items": ["pase_t1"], "coins": 0}', 499, '{"ARS": 499900}', false),
	('monedas_1000', '1000 monedas', '{"coins": 1000}', 199, '{"ARS": 199900}', false);
