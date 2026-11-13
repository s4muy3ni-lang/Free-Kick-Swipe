-- Minijuegos online: elegir minijuego y nivel, o aleatorio (pedido del usuario: «no quiero que al terminar un nivel se
-- cambie automaticamente a otro minijuego… mostrar una pantalla donde los jugadores puedan elegir qué quieren jugar»).
--
-- Flujo: buscar rival -> elegir (choose_minigame, solo el que creo la sala; el servidor sortea si es aleatorio) -> el
-- rival humano confirma (confirm_minigame; contra un bot no hace falta) -> jugar -> resultado (finish_minigame: solo se
-- acepta del minijuego y nivel elegidos) -> revancha con el mismo bot (rematch_bot) y volver a elegir.
-- Los niveles validos de cada modalidad estan en game_modes.scene_def.levels (los del contenido real del juego:
-- resources/minigames/minigames.json; la prueba test_online_minigame_select los compara).

alter table public.matches add column if not exists minigame jsonb;

update public.game_modes set scene_def = scene_def || '{"game": "boton_caida", "levels": [1, 2, 3, 4, 5, 6, 7, 8]}'::jsonb
	where id = 'a_la_vista';
update public.game_modes set scene_def = scene_def || '{"game": "guante", "levels": [1, 2, 3, 4]}'::jsonb where id = 'guante';
update public.game_modes set scene_def = scene_def || '{"game": "dardos", "levels": [4]}'::jsonb where id = 'dardos';
update public.game_modes set scene_def = scene_def || '{"game": "enceste", "levels": [1, 2, 3, 4, 5, 6, 7, 8, 9]}'::jsonb
	where id = 'basket';
update public.game_modes set scene_def = scene_def || '{"game": "diana_gigante", "levels": [1, 2, 3, 4, 5]}'::jsonb
	where id = 'diana';

-- Elige (o sortea) el minijuego y el nivel antes de empezar. Solo el que creo la sala (lado 0), con la partida activa y
-- sin turnos jugados. El nivel tiene que estar en la lista de la modalidad.
create or replace function public.choose_minigame(p_match uuid, p_mode text, p_level int, p_random boolean default false)
		returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare u uuid := _uid(); m matches; gm game_modes; lvl int := p_level;
begin
	select * into m from matches where id = p_match for update;
	if not found or m.player_a <> u then
		raise exception 'solo el que creo la sala elige' using errcode = 'P0001';
	end if;
	if m.status <> 'active' or m.shot_n > 0 or exists (select 1 from match_turns where match_id = m.id) then
		raise exception 'la partida ya empezo' using errcode = 'P0001';
	end if;
	if coalesce(p_random, false) then
		select * into gm from game_modes where kind = 'minijuego' and online and scene_def ? 'levels' order by random() limit 1;
		select (e #>> '{}')::int into lvl from jsonb_array_elements(gm.scene_def -> 'levels') e order by random() limit 1;
	else
		select * into gm from game_modes where id = p_mode and kind = 'minijuego' and online and scene_def ? 'levels';
	end if;
	if gm.id is null then
		raise exception 'minijuego invalido' using errcode = 'P0001';
	end if;
	if lvl is null or not (gm.scene_def -> 'levels') @> to_jsonb(lvl) then
		raise exception 'nivel invalido' using errcode = 'P0001';
	end if;
	update matches set mode = gm.id, rounds = gm.rounds, turn_seconds = gm.turn_seconds,
		minigame = jsonb_build_object('mode', gm.id, 'game', gm.scene_def ->> 'game', 'level', lvl,
			'random', coalesce(p_random, false), 'confirmed_b', m.player_b is null)
		where id = m.id;
	return _match_view(m.id, u);
end $$;

-- El rival humano acepta la eleccion (no puede cambiarla).
create or replace function public.confirm_minigame(p_match uuid) returns jsonb language plpgsql security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid(); m matches;
begin
	select * into m from matches where id = p_match for update;
	if not found or m.player_b is distinct from u then
		raise exception 'solo el rival confirma' using errcode = 'P0001';
	end if;
	if m.minigame is null then
		raise exception 'todavia no se eligio' using errcode = 'P0001';
	end if;
	update matches set minigame = minigame || '{"confirmed_b": true}'::jsonb where id = m.id;
	return _match_view(m.id, u);
end $$;

-- Resultado de un minijuego contra el bot: solo del minijuego y nivel elegidos y confirmados. Guarda el marcador y cierra
-- la partida (el premio sigue por claim_reward, con sus topes diarios). Entre humanos todavia no se juega por aca.
create or replace function public.finish_minigame(p_match uuid, p_game text, p_level int, p_points int, p_bot_points int)
		returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare u uuid := _uid(); m matches; a int := least(greatest(coalesce(p_points, 0), 0), 100000);
	b int := least(greatest(coalesce(p_bot_points, 0), 0), 100000);
begin
	select * into m from matches where id = p_match for update;
	if not found or m.player_a <> u then
		raise exception 'no es tu partida' using errcode = 'P0001';
	end if;
	if m.bot is null then
		raise exception 'por ahora solo contra un bot' using errcode = 'P0001';
	end if;
	if m.status <> 'active' then
		return _match_view(m.id, u);
	end if;
	if m.minigame is null or not coalesce((m.minigame ->> 'confirmed_b')::boolean, false) then
		raise exception 'primero se elige el nivel' using errcode = 'P0001';
	end if;
	if m.minigame ->> 'game' <> p_game or (m.minigame ->> 'level')::int <> p_level then
		raise exception 'nivel distinto al elegido' using errcode = 'P0001';
	end if;
	update matches set score_a = a, score_b = b, status = 'finished', finished_at = now(),
		winner = case when a > b then 0 when b > a then 1 else null end where id = m.id;
	return _match_view(m.id, u);
end $$;

-- Revancha con el mismo bot, sin volver a esperar un humano (la partida anterior ya era contra ese bot) y sin entrada.
create or replace function public.rematch_bot(p_match uuid) returns jsonb language plpgsql security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid(); o matches; m matches; caps jsonb := _caps();
begin
	select * into o from matches where id = p_match;
	if not found or o.player_a <> u or o.bot is null or o.status = 'active' then
		raise exception 'no hay partida terminada contra un bot' using errcode = 'P0001';
	end if;
	insert into matches (mode, player_a, bot, entry_fee, rounds, turn_seconds, turn_deadline)
		values (o.mode, u, o.bot, 0, o.rounds, o.turn_seconds,
			now() + make_interval(secs => o.turn_seconds + (caps ->> 'grace_seconds')::int + (caps ->> 'result_seconds')::int))
		returning * into m;
	return jsonb_build_object('status', 'matched') || _match_view(m.id, u);
end $$;

revoke execute on function public.choose_minigame(uuid, text, int, boolean), public.confirm_minigame(uuid),
	public.finish_minigame(uuid, text, int, int, int), public.rematch_bot(uuid) from public, anon;
grant execute on function public.choose_minigame(uuid, text, int, boolean), public.confirm_minigame(uuid),
	public.finish_minigame(uuid, text, int, int, int), public.rematch_bot(uuid) to authenticated;
