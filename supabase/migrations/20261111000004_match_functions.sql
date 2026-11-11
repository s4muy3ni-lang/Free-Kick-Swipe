-- Matchmaking, turnos, liquidacion, chat. Autoridad del servidor: orden de turnos, plazos, zona oculta del arquero,
-- regla de zonas (un tiro a la zona elegida por el arquero no puede ser gol), final de la partida, premios una sola vez.

-- Habilidad del bot por jugador y modo (dificultad adaptativa: cambia de a poco segun los resultados recientes).
create table public.bot_skill (
	user_id uuid not null references auth.users(id) on delete cascade,
	mode text not null,
	skill numeric not null,
	primary key (user_id, mode)
);
alter table public.bot_skill enable row level security;
revoke all on public.bot_skill from anon, authenticated;

create or replace function public._make_bot(p_uid uuid, p_mode text) returns jsonb language plpgsql security definer
		set search_path = public, pg_temp as $$
declare
	firsts text[] := array['Lucas','Mateo','Thiago','Benja','Santi','Joaco','Nico','Fede','Tomi','Lauti','Bruno','Facu',
		'Agus','Gonza','Valen','Juanma','Rami','Leo','Dani','Pablo','Ezequiel','Franco','Mauro','Ignacio','Sofi','Cami',
		'Mica','Lu','Juli','Vicky','Martina','Delfi','Ale','Seba','Iván','Emi','Kevin','Brian','Lean','Cristian'];
	tails text[] := array['', '', '', '10', '_9', 'Gol', 'FC', '_crack', '22', 'Tiki', '_7', 'Pibe', 'Zurdo', '99'];
	pers text[] := array['principiante','tranquilo','agresivo','tecnico','impredecible','competitivo','experto'];
	lvl int := level_for((select xp from profiles where id = p_uid));
	prev numeric;
	w numeric;
	target numeric;
	sk numeric;
	pi int;
	nm text;
begin
	select skill into prev from bot_skill where user_id = p_uid and mode = p_mode;
	prev := coalesce(prev, least(0.3 + lvl * 0.02, 0.6));
	-- Ultimas 10 partidas del jugador en este modo: si gana mucho, el rival sube; si pierde, baja. Cambios suaves.
	select avg(case when (m.winner = 0 and m.player_a = p_uid) or (m.winner = 1 and m.player_b = p_uid) then 1.0
		when m.winner is null then 0.5 else 0.0 end) into w
		from (select * from matches where status <> 'active' and mode = p_mode and p_uid in (player_a, player_b)
			order by finished_at desc nulls last limit 10) m;
	target := prev + (coalesce(w, 0.5) - 0.5) * 0.3;
	sk := least(greatest(target, prev - 0.1, 0.1), prev + 0.1, 0.95);
	insert into bot_skill (user_id, mode, skill) values (p_uid, p_mode, sk)
		on conflict (user_id, mode) do update set skill = excluded.skill;
	pi := case when sk < 0.25 then 1 when sk > 0.85 then 7 else 2 + floor(random() * 5)::int end;
	nm := firsts[1 + floor(random() * array_length(firsts, 1))::int] || tails[1 + floor(random() * array_length(tails, 1))::int];
	return jsonb_build_object('name', nm, 'personality', pers[pi], 'skill', round(sk, 3),
		'level', greatest(1, lvl + floor(random() * 5)::int - 2), 'seed', floor(random() * 2147483647)::bigint,
		'avatar', jsonb_build_object('jersey', floor(random() * 10)::int, 'shorts', floor(random() * 8)::int,
			'skin', floor(random() * 6)::int, 'hair', floor(random() * 6)::int, 'number', 1 + floor(random() * 99)::int),
		'record', jsonb_build_object('played', 20 + floor(random() * 300)::int, 'win_rate', round((0.3 + sk * 0.5)::numeric, 2)),
		'is_bot', true);
end $$;

-- Vista de una partida para un participante: la zona del arquero rival queda oculta hasta que llega el tiro.
create or replace function public._match_view(p_match uuid, p_uid uuid) returns jsonb language plpgsql stable
		security definer set search_path = public, pg_temp as $$
declare m matches; me int; opp uuid;
begin
	select * into m from matches where id = p_match;
	me := case when m.player_a = p_uid then 0 else 1 end;
	opp := case when me = 0 then m.player_b else m.player_a end;
	return jsonb_build_object('match', to_jsonb(m), 'my_side', me, 'server_time', now(),
		'opponent', case when m.bot is not null then m.bot else (select jsonb_build_object('username', p.username,
			'display_name', p.display_name, 'level', level_for(p.xp), 'number', p.shirt_number,
			'appearance', p.appearance, 'is_bot', false) from profiles p where p.id = opp) end,
		'turns', coalesce((select jsonb_agg(jsonb_build_object('shot_n', t.shot_n, 'side', t.side, 'kind', t.kind,
			'payload', case when t.revealed or t.side = me then t.payload else '{}'::jsonb end) order by t.id)
			from match_turns t where t.match_id = m.id), '[]'::jsonb),
		'chat', coalesce((select jsonb_agg(c order by c.id) from (select id, kind, body, from_bot,
			case when user_id = p_uid then 'yo' else 'rival' end as who from chat_messages
			where match_id = m.id order by id desc limit 30) c), '[]'::jsonb));
end $$;

create or replace function public.get_match(p_match uuid) returns jsonb language plpgsql stable security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid();
begin
	if not exists (select 1 from matches where id = p_match and u in (player_a, player_b)) then
		raise exception 'no es tu partida' using errcode = 'P0001';
	end if;
	return _match_view(p_match, u);
end $$;

create or replace function public.find_match(p_mode text, p_fee int default 0) returns jsonb language plpgsql
		security definer set search_path = public, pg_temp as $$
declare
	u uuid := _uid(); gm game_modes; me profiles; other matchmaking_queue; m matches; q matchmaking_queue;
	lvl int; rat int; caps jsonb := _caps();
begin
	select * into gm from game_modes where id = p_mode and online;
	if not found then
		raise exception 'modo no disponible online' using errcode = 'P0001';
	end if;
	if not (p_fee = any(gm.entry_fees)) then
		raise exception 'entrada invalida para este modo' using errcode = 'P0001';
	end if;
	-- Partidas propias colgadas hace mucho (el cliente se fue sin cerrar): se dan por abandonadas.
	update matches set status = 'abandoned', winner = case when player_a = u then 1 else 0 end, finished_at = now()
		where status = 'active' and u in (player_a, player_b) and turn_deadline < now() - interval '10 minutes';
	perform _settle(id) from matches where status = 'abandoned' and not settled and u in (player_a, player_b);
	select * into m from matches where status = 'active' and u in (player_a, player_b) limit 1;
	if found then
		return jsonb_build_object('status', 'matched') || _match_view(m.id, u);
	end if;
	select * into me from profiles where id = u;
	if not found then
		raise exception 'primero crea tu perfil' using errcode = 'P0001';
	end if;
	if me.coins < p_fee then
		raise exception 'monedas insuficientes para la entrada' using errcode = 'P0001';
	end if;
	lvl := level_for(me.xp);
	rat := coalesce((select rating from player_stats where user_id = u and mode = p_mode and not vs_bots
		and season_id = coalesce(_current_season(), 'sin_temporada')), 1000);
	insert into presence (user_id, last_seen) values (u, now()) on conflict (user_id) do update set last_seen = now();
	-- Primero un humano: mismo modo y entrada, nivel parecido (o que ya espero 20 s), conectado hace poco.
	select q2.* into other from matchmaking_queue q2 where q2.mode = p_mode and q2.entry_fee = p_fee and q2.user_id <> u
		and (abs(q2.level - lvl) <= 5 or q2.joined_at < now() - interval '20 seconds')
		and exists (select 1 from presence pr where pr.user_id = q2.user_id and pr.last_seen > now() - interval '30 seconds')
		and (select coins from profiles where id = q2.user_id) >= p_fee
		order by q2.joined_at limit 1 for update skip locked;
	if found then
		delete from matchmaking_queue where user_id in (u, other.user_id);
		insert into matches (mode, player_a, player_b, entry_fee, rounds, turn_seconds, turn_deadline)
			values (p_mode, other.user_id, u, p_fee, gm.rounds, gm.turn_seconds,
				now() + make_interval(secs => gm.turn_seconds + (caps ->> 'grace_seconds')::int + (caps ->> 'result_seconds')::int))
			returning * into m;
		if p_fee > 0 then
			perform _grant(other.user_id, -p_fee, 0, 0, 'entrada', 'fee:' || m.id);
			perform _grant(u, -p_fee, 0, 0, 'entrada', 'fee:' || m.id);
		end if;
		return jsonb_build_object('status', 'matched') || _match_view(m.id, u);
	end if;
	insert into matchmaking_queue (user_id, mode, entry_fee, level, rating) values (u, p_mode, p_fee, lvl, rat)
		on conflict (user_id) do update set level = excluded.level, rating = excluded.rating,
			joined_at = case when matchmaking_queue.mode = excluded.mode and matchmaking_queue.entry_fee = excluded.entry_fee
				then matchmaking_queue.joined_at else now() end,
			mode = excluded.mode, entry_fee = excluded.entry_fee;
	select * into q from matchmaking_queue where user_id = u;
	return jsonb_build_object('status', 'searching', 'waited', extract(epoch from now() - q.joined_at),
		'bot_after', (caps ->> 'bot_wait_seconds')::int,
		'humans_searching', (select count(*) from matchmaking_queue where mode = p_mode));
end $$;

create or replace function public.cancel_search() returns void language sql security definer
		set search_path = public, pg_temp as $$
	delete from matchmaking_queue where user_id = _uid()
$$;

-- Sin humano despues de la espera: partida contra un bot que genera el servidor. Solo se puede pedir despues de haber
-- esperado bot_wait_seconds en la cola de ese modo.
create or replace function public.start_bot_match(p_mode text) returns jsonb language plpgsql security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid(); q matchmaking_queue; gm game_modes; m matches; caps jsonb := _caps();
begin
	select * into q from matchmaking_queue where user_id = u and mode = p_mode for update;
	if not found then
		raise exception 'primero busca rival' using errcode = 'P0001';
	end if;
	if q.joined_at > now() - make_interval(secs => (caps ->> 'bot_wait_seconds')::int) then
		raise exception 'todavia se esta buscando un rival humano' using errcode = 'P0001';
	end if;
	select * into gm from game_modes where id = p_mode;
	delete from matchmaking_queue where user_id = u;
	insert into matches (mode, player_a, bot, entry_fee, rounds, turn_seconds, turn_deadline)
		values (p_mode, u, _make_bot(u, p_mode), q.entry_fee, gm.rounds, gm.turn_seconds,
			now() + make_interval(secs => gm.turn_seconds + (caps ->> 'grace_seconds')::int + (caps ->> 'result_seconds')::int))
		returning * into m;
	if q.entry_fee > 0 then
		perform _grant(u, -q.entry_fee, 0, 0, 'entrada', 'fee:' || m.id);
	end if;
	return jsonb_build_object('status', 'matched') || _match_view(m.id, u);
end $$;

-- Avanza la partida despues de un tiro: final por rondas (con remontada imposible), muerte subita, tope de duelo.
create or replace function public._advance(p_match uuid) returns void language plpgsql security definer
		set search_path = public, pg_temp as $$
declare m matches; gm game_modes; n int; a_sh int; b_sh int; rem_a int; rem_b int; done boolean := false;
	w int; caps jsonb := _caps(); target int;
begin
	select * into m from matches where id = p_match for update;
	select * into gm from game_modes where id = m.mode;
	n := m.shot_n + 1;
	a_sh := (n + 1) / 2;
	b_sh := n / 2;
	rem_a := greatest(m.rounds - a_sh, 0);
	rem_b := greatest(m.rounds - b_sh, 0);
	target := nullif((gm.scene_def ->> 'target')::int, 0);
	if target is not null and (m.score_a >= target or m.score_b >= target) and n % 2 = 0 then
		done := true;
	elsif n <= 2 * m.rounds and (m.score_a > m.score_b + rem_b or m.score_b > m.score_a + rem_a) then
		done := true;
	elsif n >= 2 * m.rounds and n % 2 = 0 and (m.score_a <> m.score_b or n >= 2 * m.rounds + 10) then
		done := true;
	end if;
	if done then
		w := case when m.score_a > m.score_b then 0 when m.score_b > m.score_a then 1 else null end;
		update matches set shot_n = n, status = 'finished', winner = w, finished_at = now() where id = m.id;
		perform _settle(m.id);
	else
		update matches set shot_n = n, shooter = n % 2,
			turn_deadline = now() + make_interval(secs => m.turn_seconds + (caps ->> 'grace_seconds')::int
				+ (caps ->> 'result_seconds')::int)
			where id = m.id;
	end if;
end $$;

create or replace function public.submit_turn(p_match uuid, p_kind text, p_payload jsonb, p_side int default null)
		returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
	u uuid := _uid(); m matches; gm game_modes; side int; late boolean; outcome text; cz int; kz int; pts int;
	caps jsonb := _caps(); bot_turn boolean := false; inserted int := 0;
begin
	select * into m from matches where id = p_match for update;
	if not found or u not in (m.player_a, coalesce(m.player_b, m.player_a)) then
		raise exception 'no es tu partida' using errcode = 'P0001';
	end if;
	if m.status <> 'active' then
		return _match_view(m.id, u);
	end if;
	side := case when u = m.player_a then 0 else 1 end;
	if p_side is not null and p_side <> side then
		if m.bot is null then
			raise exception 'no podes jugar por el rival' using errcode = 'P0001';
		end if;
		side := p_side;
		bot_turn := true;
	end if;
	select * into gm from game_modes where id = m.mode;
	late := not bot_turn and now() > m.turn_deadline + make_interval(secs => (caps ->> 'grace_seconds')::int);
	if p_kind = 'keeper_pick' then
		if gm.kind = 'minijuego' or side = m.shooter then
			raise exception 'ahora no te toca atajar' using errcode = 'P0001';
		end if;
		kz := (p_payload ->> 'zone')::int;
		if kz is null or kz not between -1 and 5 then
			raise exception 'zona invalida' using errcode = 'P0001';
		end if;
		insert into match_turns (match_id, shot_n, side, kind, payload, revealed)
			values (m.id, m.shot_n, side, 'keeper_pick', jsonb_build_object('zone', kz), false) on conflict do nothing;
		return _match_view(m.id, u);
	end if;
	if p_kind not in ('shot','score') then
		raise exception 'tipo de turno invalido' using errcode = 'P0001';
	end if;
	if side <> m.shooter then
		raise exception 'no es tu turno' using errcode = 'P0001';
	end if;
	if gm.kind <> 'minijuego' then
		outcome := coalesce(p_payload ->> 'outcome', 'miss');
		if outcome not in ('goal','save','miss','post') then
			raise exception 'resultado invalido' using errcode = 'P0001';
		end if;
		cz := coalesce((p_payload ->> 'cross_zone')::int, -1);
		select (payload ->> 'zone')::int into kz from match_turns where match_id = m.id and shot_n = m.shot_n
			and kind = 'keeper_pick';
		-- Coherencia: un gol tiene que entrar en el arco, y un tiro a la zona que eligio el arquero es atajada.
		if outcome = 'goal' and cz not between 0 and 5 then
			outcome := 'miss';
		end if;
		if outcome = 'goal' and kz is not null and kz = cz then
			outcome := 'save';
		end if;
		if late or coalesce((p_payload ->> 'timed_out')::boolean, false) then
			outcome := 'miss';
		end if;
		pts := case when outcome = 'goal' then 1 else 0 end;
		insert into match_turns (match_id, shot_n, side, kind, payload)
			values (m.id, m.shot_n, side, 'shot', p_payload || jsonb_build_object('outcome', outcome, 'keeper_zone', kz,
				'late', late)) on conflict do nothing;
		get diagnostics inserted = row_count;
		update match_turns set revealed = true where match_id = m.id and shot_n = m.shot_n and kind = 'keeper_pick';
	else
		pts := least(greatest(coalesce((p_payload ->> 'points')::int, 0), 0), gm.max_points_per_turn);
		if late or coalesce((p_payload ->> 'timed_out')::boolean, false) then
			pts := 0;
		end if;
		insert into match_turns (match_id, shot_n, side, kind, payload)
			values (m.id, m.shot_n, side, 'score', p_payload || jsonb_build_object('points', pts, 'late', late))
			on conflict do nothing;
		get diagnostics inserted = row_count;
	end if;
	if inserted = 0 then
		return _match_view(m.id, u);
	end if;
	update matches set score_a = score_a + case when side = 0 then pts else 0 end,
		score_b = score_b + case when side = 1 then pts else 0 end,
		timeouts_a = timeouts_a + case when side = 0 and late then 1 else 0 end,
		timeouts_b = timeouts_b + case when side = 1 and late then 1 else 0 end
		where id = m.id returning * into m;
	if (side = 0 and m.timeouts_a >= (caps ->> 'max_timeouts')::int) or (side = 1 and m.timeouts_b >= (caps ->> 'max_timeouts')::int) then
		update matches set status = 'abandoned', winner = 1 - side, finished_at = now() where id = m.id;
		perform _settle(m.id);
	else
		perform _advance(m.id);
	end if;
	return _match_view(m.id, u);
end $$;

-- El que debia patear no lo hizo a tiempo (se cerro la app, se corto la conexion): cualquiera de los dos lo reclama
-- pasado el plazo y el servidor anota el tiro de penalizacion (fallado). Tres veces seguidas = abandono.
create or replace function public.claim_timeout(p_match uuid) returns jsonb language plpgsql security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid(); m matches; caps jsonb := _caps(); side int;
begin
	select * into m from matches where id = p_match for update;
	if not found or u not in (m.player_a, coalesce(m.player_b, m.player_a)) then
		raise exception 'no es tu partida' using errcode = 'P0001';
	end if;
	if m.status <> 'active' or now() <= m.turn_deadline + make_interval(secs => (caps ->> 'grace_seconds')::int) then
		return _match_view(m.id, u);
	end if;
	side := m.shooter;
	if m.bot is not null and side = 1 then
		return _match_view(m.id, u);
	end if;
	insert into match_turns (match_id, shot_n, side, kind, payload)
		values (m.id, m.shot_n, side, 'timeout', '{"outcome": "miss", "auto": true}'::jsonb) on conflict do nothing;
	update matches set timeouts_a = timeouts_a + case when side = 0 then 1 else 0 end,
		timeouts_b = timeouts_b + case when side = 1 then 1 else 0 end where id = m.id returning * into m;
	if (side = 0 and m.timeouts_a >= (caps ->> 'max_timeouts')::int) or (side = 1 and m.timeouts_b >= (caps ->> 'max_timeouts')::int) then
		update matches set status = 'abandoned', winner = 1 - side, finished_at = now() where id = m.id;
		perform _settle(m.id);
	else
		perform _advance(m.id);
	end if;
	return _match_view(m.id, u);
end $$;

create or replace function public.leave_match(p_match uuid) returns jsonb language plpgsql security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid(); m matches;
begin
	select * into m from matches where id = p_match and status = 'active' and u in (player_a, coalesce(player_b, player_a))
		for update;
	if found then
		update matches set status = 'abandoned', winner = case when u = m.player_a then 1 else 0 end, finished_at = now()
			where id = m.id;
		perform _settle(m.id);
	end if;
	return get_my_state();
end $$;

-- Premios, estadisticas, ranking y eventos: UNA vez por partida. Contra bots: premios reducidos con tope diario, sin
-- ranking, estadisticas en vs_bots = true.
create or replace function public._settle(p_match uuid) returns void language plpgsql security definer
		set search_path = public, pg_temp as $$
declare
	m matches; s int; uid uuid; is_bot boolean; res text; x bigint; c bigint; sp bigint; caps jsonb := _caps();
	today_c bigint; season text := coalesce(_current_season(), 'sin_temporada'); my_score int; opp_score int;
	ra int; rb int; ea numeric; k int := 24; saves int; shots int; on_t int; ev events;
begin
	select * into m from matches where id = p_match for update;
	if m.settled then
		return;
	end if;
	update matches set settled = true where id = m.id;
	is_bot := m.bot is not null;
	for s in 0..1 loop
		uid := case when s = 0 then m.player_a else m.player_b end;
		continue when uid is null;
		res := case when m.winner is null then 'draw' when m.winner = s then 'win' else 'loss' end;
		my_score := case when s = 0 then m.score_a else m.score_b end;
		opp_score := case when s = 0 then m.score_b else m.score_a end;
		if is_bot then
			x := 25 + case res when 'win' then 25 when 'draw' then 10 else 0 end;
			c := 5 + case res when 'win' then m.entry_fee + m.entry_fee / 2 + 20 when 'draw' then m.entry_fee else 0 end;
			sp := 5 + case when res = 'win' then 10 else 0 end;
			select coalesce(sum(coins), 0) into today_c from reward_ledger where user_id = uid and source = 'partida_bot'
				and created_at >= date_trunc('day', now());
			c := least(c, greatest((caps ->> 'bot_coins')::bigint - today_c, 0)
				+ case when res in ('win','draw') then m.entry_fee else 0 end);
		else
			x := 40 + case res when 'win' then 40 when 'draw' then 20 else 0 end;
			c := 10 + case res when 'win' then 2 * m.entry_fee + 20 when 'draw' then m.entry_fee + 5 else 0 end;
			sp := 10 + case when res = 'win' then 20 else 0 end;
		end if;
		perform _grant(uid, c, x, sp, case when is_bot then 'partida_bot' else 'partida_humana' end,
			'match:' || m.id || ':' || s, jsonb_build_object('mode', m.mode, 'result', res), true);
		select count(*) filter (where kind = 'shot' and side <> s and payload ->> 'outcome' = 'save'),
			count(*) filter (where kind in ('shot','timeout') and side = s),
			count(*) filter (where kind = 'shot' and side = s and payload ->> 'outcome' in ('goal','save','post'))
			into saves, shots, on_t from match_turns where match_id = m.id;
		insert into player_stats as st (user_id, season_id, mode, vs_bots, played, wins, losses, goals, saves, shots,
				on_target, points)
			values (uid, season, m.mode, is_bot, 1, (res = 'win')::int, (res = 'loss')::int, my_score, saves, shots,
				on_t, my_score)
			on conflict (user_id, season_id, mode, vs_bots) do update set played = st.played + 1,
				wins = st.wins + excluded.wins, losses = st.losses + excluded.losses, goals = st.goals + excluded.goals,
				saves = st.saves + excluded.saves, shots = st.shots + excluded.shots,
				on_target = st.on_target + excluded.on_target, points = st.points + excluded.points;
		for ev in select * from events where now() between starts_at and ends_at and (mode is null or mode = m.mode) loop
			insert into event_progress (user_id, event_id, points, matches)
				values (uid, ev.id, coalesce((ev.rewards ->> case when res = 'win' then 'per_win_points'
					else 'per_play_points' end)::bigint, 0), 1)
				on conflict (user_id, event_id) do update set points = event_progress.points + excluded.points,
					matches = event_progress.matches + 1;
		end loop;
	end loop;
	-- Elo solo entre humanos.
	if not is_bot and m.player_b is not null then
		select rating into ra from player_stats where user_id = m.player_a and season_id = season and mode = m.mode and not vs_bots;
		select rating into rb from player_stats where user_id = m.player_b and season_id = season and mode = m.mode and not vs_bots;
		ea := 1.0 / (1.0 + power(10.0, (rb - ra) / 400.0));
		update player_stats set rating = greatest(100, rating + round(k * ((case m.winner when 0 then 1.0 when 1 then 0.0
			else 0.5 end) - ea))::int) where user_id = m.player_a and season_id = season and mode = m.mode and not vs_bots;
		update player_stats set rating = greatest(100, rating + round(k * ((case m.winner when 1 then 1.0 when 0 then 0.0
			else 0.5 end) - (1 - ea)))::int) where user_id = m.player_b and season_id = season and mode = m.mode and not vs_bots;
	end if;
end $$;

-- Chat: mensajes cortos, frases rapidas y emojis de una lista; limite de frecuencia y de cantidad; filtro de palabras.
create or replace function public.send_chat(p_match uuid, p_kind text, p_body text) returns jsonb language plpgsql
		security definer set search_path = public, pg_temp as $$
declare
	u uuid := _uid(); m matches; caps jsonb := _caps(); last_at timestamptz; n int; body text := trim(p_body);
	quick text[] := array['buen_tiro','que_atajada','suerte','casi','revancha','bien_jugado','uy','vamos'];
	emotes text[] := array['😀','😂','😮','😎','🔥','👏','😅','😤','🙌','⚽','🧤','💪'];
	bad text[] := array['puto','puta','pelotudo','boludo','forro','mierda','concha','idiota','imbecil','tarado','negro de mierda'];
	w text;
begin
	select * into m from matches where id = p_match and u in (player_a, coalesce(player_b, player_a));
	if not found then
		raise exception 'no es tu partida' using errcode = 'P0001';
	end if;
	select max(created_at), count(*) into last_at, n from chat_messages where match_id = p_match and user_id = u;
	if last_at > now() - make_interval(secs => (caps ->> 'chat_min_seconds')::int) then
		raise exception 'espera un momento antes de mandar otro mensaje' using errcode = 'P0001';
	end if;
	if n >= (caps ->> 'chat_max_per_match')::int then
		raise exception 'llegaste al limite de mensajes de esta partida' using errcode = 'P0001';
	end if;
	if p_kind = 'quick' and not body = any(quick) then
		raise exception 'frase rapida invalida' using errcode = 'P0001';
	elsif p_kind = 'emote' and not body = any(emotes) then
		raise exception 'emoji invalido' using errcode = 'P0001';
	elsif p_kind = 'text' then
		if char_length(body) not between 1 and 60 then
			raise exception 'el mensaje tiene que tener entre 1 y 60 caracteres' using errcode = 'P0001';
		end if;
		foreach w in array bad loop
			body := regexp_replace(body, w, repeat('*', char_length(w)), 'gi');
		end loop;
	elsif p_kind not in ('quick','emote','text') then
		raise exception 'tipo de mensaje invalido' using errcode = 'P0001';
	end if;
	insert into chat_messages (match_id, user_id, kind, body) values (p_match, u, p_kind, body);
	return _match_view(p_match, u);
end $$;
