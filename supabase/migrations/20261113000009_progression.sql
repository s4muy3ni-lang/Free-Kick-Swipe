-- Progresion del jugador (pedido del usuario: «nivel, experiencia, puntos de mejora… atributos con efecto real…
-- limites… especializacion sin clase permanente… redistribuir bajo reglas equilibradas… historial… atributos de
-- arquero que nunca atajen lo imposible… XP de todas las actividades sin poder explotarlas»). Mismas reglas que
-- ProgressionRules y AttributeEffects del juego (scripts/progression/) y que LocalBackend:
--  - 2 puntos por nivel hasta el nivel 30 (58 puntos); despues se sigue subiendo de nivel, sin mas puntos;
--  - atributos de 1 a 10 (6 de tirador y 3 de arquero); subir cuesta 1 punto hasta el 5, 2 del 6 al 8 y 3 el 9 y el 10;
--  - redistribuir: todo vuelve a 1; la primera vez gratis, despues una cada 7 dias por 300 monedas; nunca en partida;
--  - historial de mejoras (attribute_log) y de experiencia (reward_ledger) en get_my_state;
--  - premios de juego local: un poco por rendimiento (goles y atajadas, con tope), rendimiento decreciente si se
--    repite la misma fuente en el dia (8 enteros, hasta 16 a la mitad, despues un cuarto) y el tope diario, que el
--    doble de XP tampoco supera;
--  - online: el alcance del arquero usa los atributos del perfil del que ataja (no los que mande el cliente).

alter table public.profiles add column if not exists respecs int not null default 0;
alter table public.profiles add column if not exists respec_at timestamptz;

create table if not exists public.attribute_log (
	id bigserial primary key,
	user_id uuid not null references auth.users(id) on delete cascade,
	kind text not null check (kind in ('mejora', 'redistribucion')),
	attribute text not null default '',
	from_value int not null,
	to_value int not null,
	cost int not null default 0,
	created_at timestamptz not null default now()
);
create index if not exists attribute_log_user on public.attribute_log (user_id, created_at);
alter table public.attribute_log enable row level security;
drop policy if exists own_attribute_log on public.attribute_log;
create policy own_attribute_log on public.attribute_log for select to authenticated using (user_id = (select auth.uid()));

-- Valor (1..10) del atributo k (los que faltan valen 1).
create or replace function public.attr_value(a jsonb, k text) returns int language sql immutable
		set search_path = public, pg_temp as $$
	select least(greatest(coalesce((a ->> k)::int, 1), 1), 10)
$$;

-- Costo de pasar de v - 1 a v.
create or replace function public.attr_cost(v int) returns int language sql immutable set search_path = public, pg_temp as $$
	select case when v <= 5 then 1 when v <= 8 then 2 else 3 end
$$;

-- Puntos gastados en la distribucion a (suma de los costos de cada valor).
create or replace function public.attr_spent(a jsonb) returns int language sql immutable set search_path = public, pg_temp as $$
	select coalesce(sum((select coalesce(sum(attr_cost(i)), 0) from generate_series(2, attr_value(a, k)) i)), 0)::int
	from unnest(array['power','accuracy','curve','height','technique','control','keeper_reach','keeper_reflex','keeper_catch']) k
$$;

create or replace function public.attr_earned(p_level int) returns int language sql immutable set search_path = public, pg_temp as $$
	select (least(greatest(p_level, 1), 30) - 1) * 2
$$;

create or replace function public.spend_attribute_point(p_attribute text) returns jsonb language plpgsql
		security definer set search_path = public, pg_temp as $$
declare u uuid := _uid(); p profiles; cur int; c int;
begin
	if p_attribute not in ('power','accuracy','curve','height','technique','control','keeper_reach','keeper_reflex',
			'keeper_catch') then
		raise exception 'atributo invalido' using errcode = 'P0001';
	end if;
	select * into p from profiles where id = u for update;
	cur := attr_value(p.attributes, p_attribute);
	if cur >= 10 then
		raise exception 'ese atributo ya esta al maximo' using errcode = 'P0001';
	end if;
	c := attr_cost(cur + 1);
	if attr_earned(level_for(p.xp)) - attr_spent(p.attributes) < c then
		raise exception 'no tenes puntos suficientes (cuesta %)', c using errcode = 'P0001';
	end if;
	update profiles set attributes = jsonb_set(attributes, array[p_attribute], to_jsonb(cur + 1)), updated_at = now()
		where id = u;
	insert into attribute_log (user_id, kind, attribute, from_value, to_value, cost)
		values (u, 'mejora', p_attribute, cur, cur + 1, c);
	return get_my_state();
end $$;

-- Redistribucion: todos los atributos a 1. La primera gratis; despues una cada 7 dias por 300 monedas (con clave de
-- idempotencia: una repeticion no cobra ni redistribuye dos veces). Nunca durante una partida online.
create or replace function public.respec_attributes(p_idem text) returns jsonb language plpgsql security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid(); p profiles; spent int; cost int := 0;
begin
	if char_length(p_idem) not between 8 and 80 then
		raise exception 'clave de idempotencia invalida' using errcode = 'P0001';
	end if;
	if exists (select 1 from reward_ledger where user_id = u and idem_key = 'respec:' || p_idem) then
		return get_my_state();
	end if;
	if exists (select 1 from matches where status = 'active' and u in (player_a, player_b)) then
		raise exception 'no se puede redistribuir durante una partida' using errcode = 'P0001';
	end if;
	select * into p from profiles where id = u for update;
	spent := attr_spent(p.attributes);
	if spent = 0 then
		raise exception 'no hay puntos para redistribuir' using errcode = 'P0001';
	end if;
	if p.respecs > 0 then
		if p.respec_at > now() - interval '7 days' then
			raise exception 'la proxima redistribucion se habilita en % dias',
				ceil(extract(epoch from (p.respec_at + interval '7 days' - now())) / 86400.0)::int using errcode = 'P0001';
		end if;
		cost := 300;
	end if;
	-- Cobra (o registra gratis) una sola vez por clave; sin saldo, _grant falla y no cambia nada.
	perform _grant(u, -cost, 0, 0, 'redistribucion', 'respec:' || p_idem);
	insert into attribute_log (user_id, kind, attribute, from_value, to_value, cost)
		values (u, 'redistribucion', '', spent, 0, cost);
	update profiles set attributes = '{"power":1,"accuracy":1,"curve":1,"height":1,"technique":1,"control":1,
		"keeper_reach":1,"keeper_reflex":1,"keeper_catch":1}'::jsonb, respecs = respecs + 1, respec_at = now(),
		updated_at = now() where id = u;
	return get_my_state();
end $$;

create or replace function public.get_my_state() returns jsonb language plpgsql stable security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid(); p profiles; s text := _current_season(); lv int;
begin
	select * into p from profiles where id = u;
	if not found then
		return jsonb_build_object('profile', null);
	end if;
	lv := level_for(p.xp);
	return jsonb_build_object(
		'profile', to_jsonb(p) || jsonb_build_object('level', lv),
		'inventory', coalesce((select jsonb_object_agg(item_id, qty) from inventory where user_id = u and qty > 0), '{}'::jsonb),
		'boosts', coalesce((select jsonb_agg(to_jsonb(b) - 'user_id') from boosts b where user_id = u
			and (remaining > 0 or expires_at > now())), '[]'::jsonb),
		'season', case when s is null then null else (select jsonb_build_object('id', s, 'points', coalesce(sp.points, 0),
			'premium', coalesce(sp.premium, false), 'claimed_free', coalesce(sp.claimed_free, '{}'),
			'claimed_premium', coalesce(sp.claimed_premium, '{}'))
			from (select 1) one left join season_progress sp on sp.user_id = u and sp.season_id = s) end,
		'active_match', (select id from matches where status = 'active' and u in (player_a, player_b)
			order by created_at desc limit 1),
		'progression', jsonb_build_object('points_earned', attr_earned(lv), 'points_spent', attr_spent(p.attributes),
			'points_available', greatest(attr_earned(lv) - attr_spent(p.attributes), 0), 'point_level_cap', 30,
			'respecs', p.respecs, 'respec_at', extract(epoch from p.respec_at), 'now', extract(epoch from now()),
			'history', coalesce((select jsonb_agg(jsonb_build_object('kind', kind, 'attribute', attribute, 'from', from_value,
				'to', to_value, 'cost', cost, 'at', extract(epoch from created_at)) order by id)
				from (select * from attribute_log where user_id = u order by id desc limit 20) h), '[]'::jsonb),
			'xp_history', coalesce((select jsonb_agg(jsonb_build_object('source', source, 'xp', xp,
				'at', extract(epoch from created_at)) order by id desc)
				from (select * from reward_ledger where user_id = u and xp > 0 order by id desc limit 10) x), '[]'::jsonb)));
end $$;

-- Premios de juego local (offline, arcade, academia, desafios, logros). El servidor calcula el monto; del cliente toma
-- que paso (medalla, si gano, goles y atajadas hasta 5). Rendimiento decreciente por repeticion de la misma fuente en el
-- dia y tope diario (el doble de XP tampoco lo pasa). Idempotente por p_idem.
create or replace function public.claim_reward(p_idem text, p_source text, p_payload jsonb) returns jsonb
		language plpgsql security definer set search_path = public, pg_temp as $$
declare
	u uuid := _uid();
	medal int := least(greatest(coalesce((p_payload ->> 'medal')::int, 0), 0), 3);
	won boolean := coalesce((p_payload ->> 'won')::boolean, false);
	goals int := least(greatest(coalesce((p_payload ->> 'goals')::int, 0), 0), 5);
	saves int := least(greatest(coalesce((p_payload ->> 'saves')::int, 0), 0), 5);
	x bigint := 0; c bigint := 0; sp bigint := 0; same int; f float8;
	today_x bigint; today_c bigint; today_sp bigint; caps jsonb := _caps(); room_x bigint;
	boostable boolean := p_source in ('arcade', 'offline_match');
begin
	if char_length(p_idem) not between 8 and 80 then
		raise exception 'clave de idempotencia invalida' using errcode = 'P0001';
	end if;
	case p_source
		when 'arcade' then x := 20 + medal * 25; c := 10 + medal * 15; sp := 5 + medal * 5;
		when 'academia' then x := 15 + medal * 20; c := 5 + medal * 10; sp := 3 + medal * 3;
		when 'desafio_diario' then x := 40; c := 30; sp := 10;
		when 'desafio_semanal' then x := 150; c := 100; sp := 40;
		when 'logro' then x := 100; c := 50; sp := 0;
		when 'offline_match' then x := 30 + case when won then 20 else 0 end + goals * 4 + saves * 6;
			c := 15 + case when won then 15 else 0 end; sp := 5 + case when won then 5 else 0 end;
		else raise exception 'origen de recompensa desconocido' using errcode = 'P0001';
	end case;
	if exists (select 1 from reward_ledger where user_id = u and idem_key = p_idem) then
		return _grant(u, 0, 0, 0, p_source, p_idem);
	end if;
	select coalesce(sum(xp), 0), coalesce(sum(coins), 0), coalesce(sum(season_points), 0),
			count(*) filter (where source = p_source)
		into today_x, today_c, today_sp, same from reward_ledger
		where user_id = u and created_at >= date_trunc('day', now())
		and source in ('arcade','academia','desafio_diario','desafio_semanal','logro','offline_match');
	f := case when same < 8 then 1.0 when same < 16 then 0.5 else 0.25 end;
	x := round(x * f); c := round(c * f); sp := round(sp * f);
	room_x := greatest((caps ->> 'offline_xp')::bigint - today_x, 0);
	x := least(x, room_x);
	c := greatest(least(c, (caps ->> 'offline_coins')::bigint - today_c), 0);
	sp := greatest(least(sp, (caps ->> 'offline_season')::bigint - today_sp), 0);
	if boostable and x > 0 and exists (select 1 from boosts where user_id = u and kind = 'xp_x2' and expires_at > now()) then
		x := least(x, room_x / 2);
	end if;
	return _grant(u, c, x, sp, p_source, p_idem, p_payload, boostable);
end $$;

-- Alcance con atributos (KeeperReach.reach con scale y react, dentro de sus limites: 0,94..1,06 y -0,04..0,04 s).
create or replace function public.keeper_reachable_attr(p_y float8, p_z float8, p_flight float8, p_keeper_z float8,
		p_min_flight float8, p_scale float8, p_react float8) returns boolean language sql immutable
		set search_path = public, pg_temp as $$
	select p_y is not null and p_z is not null and p_y >= -0.05
		and abs(p_z - p_keeper_z) <= (case when p_y <= 1.2 then 3.5 else greatest(3.5 + (2.4 - 3.5) * (p_y - 1.2) / (2.44 - 1.2), 0.0) end)
			* least(greatest((least(greatest(coalesce(p_flight, p_min_flight), p_min_flight), 3.0) + 0.12
				- (0.12 + least(greatest(p_react, -0.04), 0.04))) / (0.65 - (0.12 + least(greatest(p_react, -0.04), 0.04))), 0.5), 1.0)
			* least(greatest(p_scale, 0.94), 1.06)
$$;

-- Turnos: igual que en 20261113000006, con el alcance del arquero segun los atributos de su perfil.
create or replace function public.submit_turn(p_match uuid, p_kind text, p_payload jsonb, p_side int default null)
		returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
	u uuid := _uid(); m matches; gm game_modes; side int; late boolean; outcome text; cz int; kz int; pts int;
	caps jsonb := _caps(); bot_turn boolean := false; inserted int := 0; reachable boolean := true;
	kpos float8 := 0.0; min_flight float8 := 0.3; sp float8[]; katt jsonb;
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
		if kz is null or kz not between -1 and 8 then
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
		-- Tiro libre: el punto de tiro lo fija el servidor (ronda = tiro / 2) y el informado tiene que coincidir; el
		-- arquero se para donde corresponde a ese punto y la pelota tarda al menos 0,5 s.
		if gm.kind = 'tiros_libres' and not coalesce((p_payload ->> 'timed_out')::boolean, false) then
			sp := fk_spot(m.shot_n / 2, m.spot_offset);
			if not (p_payload ? 'spot') or jsonb_typeof(p_payload -> 'spot') <> 'array'
					or abs((p_payload -> 'spot' ->> 0)::float8 - sp[1][1]) > 0.6
					or abs((p_payload -> 'spot' ->> 1)::float8 - sp[1][2]) > 0.6 then
				raise exception 'punto de tiro invalido' using errcode = 'P0001';
			end if;
			kpos := fk_keeper_z(sp[1][2]);
			min_flight := 0.5;
		end if;
		-- Con el cruce informado (alto y ancho) el sector se recalcula (el informado no manda) y se mira el alcance.
		if p_payload ? 'cross_y' and p_payload ? 'cross_z' then
			cz := keeper_zone_of((p_payload ->> 'cross_y')::float8, (p_payload ->> 'cross_z')::float8);
			-- Alcance con los atributos del que ataja (alcance y reflejos de su perfil; el bot, neutros).
			katt := coalesce((select attributes from profiles where id = case when m.shooter = 0 then m.player_b
				else m.player_a end), '{}'::jsonb);
			reachable := keeper_reachable_attr((p_payload ->> 'cross_y')::float8, (p_payload ->> 'cross_z')::float8,
				coalesce((p_payload ->> 'flight')::float8, min_flight), kpos, min_flight,
				1.0 + 0.06 * (attr_value(katt, 'keeper_reach') - 1) / 9.0, -0.04 * (attr_value(katt, 'keeper_reflex') - 1) / 9.0);
		end if;
		select (payload ->> 'zone')::int into kz from match_turns where match_id = m.id and shot_n = m.shot_n
			and kind = 'keeper_pick';
		-- Coherencia: un gol tiene que entrar en el arco. Un tiro al sector que eligio el arquero y a su alcance fisico
		-- es atajada; pegado al angulo (fuera del alcance) sigue siendo gol.
		if outcome = 'goal' and cz not between 0 and 8 then
			outcome := 'miss';
		end if;
		if outcome = 'goal' and kz is not null and kz = cz and reachable then
			outcome := 'save';
		end if;
		if late or coalesce((p_payload ->> 'timed_out')::boolean, false) then
			outcome := 'miss';
		end if;
		pts := case when outcome = 'goal' then 1 else 0 end;
		insert into match_turns (match_id, shot_n, side, kind, payload)
			values (m.id, m.shot_n, side, 'shot', p_payload || jsonb_build_object('outcome', outcome, 'keeper_zone', kz,
				'late', late, 'cross_zone', cz, 'reachable', reachable)) on conflict do nothing;
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

revoke execute on function public.attr_value(jsonb, text), public.attr_cost(int), public.attr_spent(jsonb),
	public.attr_earned(int), public.keeper_reachable_attr(float8, float8, float8, float8, float8, float8, float8)
	from public, anon, authenticated;
grant execute on function public.respec_attributes(text), public.spend_attribute_point(text), public.get_my_state(),
	public.claim_reward(text, text, jsonb), public.submit_turn(uuid, text, jsonb, int) to authenticated;
