-- Funciones del servidor (autoridad). Todas SECURITY DEFINER con search_path fijo; las internas (_*) no se exponen.
-- El cliente llama a las publicas por RPC (POST /rest/v1/rpc/<nombre>) con su JWT; auth.uid() identifica al jugador.

-- Tope diario de recompensas que no salen de una partida online contra humano (offline, arcade, academia, desafios,
-- partidas contra bots): evita granjear repitiendo acciones.
create or replace function public._caps() returns jsonb language sql immutable as $$
	select '{"offline_xp": 1500, "offline_coins": 800, "offline_season": 300, "bot_coins": 600, "grace_seconds": 5, "result_seconds": 8,
		"bot_wait_seconds": 8, "max_timeouts": 3, "chat_min_seconds": 2, "chat_max_per_match": 30}'::jsonb
$$;

create or replace function public._uid() returns uuid language plpgsql stable as $$
declare u uuid := auth.uid();
begin
	if u is null then
		raise exception 'no autenticado' using errcode = '28000';
	end if;
	return u;
end $$;

-- Nivel por experiencia (misma curva que PlayerProgress.level_for del cliente: cada nivel pide 150 XP mas).
create or replace function public.level_for(total bigint) returns int language plpgsql immutable as $$
declare lv int := 1; need bigint := 150; acc bigint := 0;
begin
	while total >= acc + need loop
		acc := acc + need;
		lv := lv + 1;
		need := need + 150;
	end loop;
	return lv;
end $$;

create or replace function public._current_season() returns text language sql stable as $$
	select id from public.seasons where now() >= starts_at and now() < ends_at order by starts_at desc limit 1
$$;

-- Otorga (o cobra, con coins negativas) UNA sola vez por idem_key. Aplica los consumibles activos a las ganancias de
-- partidas. Devuelve {applied, coins, xp, balance, total_xp}. Nunca deja el saldo negativo.
create or replace function public._grant(p_uid uuid, p_coins bigint, p_xp bigint, p_season bigint, p_source text,
		p_idem text, p_detail jsonb default '{}'::jsonb, p_boostable boolean default false)
		returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
	v_coins bigint := p_coins;
	v_xp bigint := p_xp;
	v_id bigint;
	v_bal bigint;
	v_txp bigint;
	b record;
begin
	if p_boostable then
		select * into b from boosts where user_id = p_uid and kind = 'coins_x2' and remaining > 0 for update;
		if found and v_coins > 0 then
			v_coins := v_coins * 2;
			update boosts set remaining = remaining - 1 where user_id = p_uid and kind = 'coins_x2';
		end if;
		select * into b from boosts where user_id = p_uid and kind = 'xp_x2' and expires_at > now();
		if found and v_xp > 0 then
			v_xp := v_xp * 2;
		end if;
	end if;
	insert into reward_ledger (user_id, idem_key, source, coins, xp, season_points, detail)
		values (p_uid, p_idem, p_source, v_coins, v_xp, p_season, p_detail)
		on conflict (user_id, idem_key) do nothing returning id into v_id;
	if v_id is null then
		select coins, xp into v_bal, v_txp from profiles where id = p_uid;
		return jsonb_build_object('applied', false, 'coins', 0, 'xp', 0, 'balance', v_bal, 'total_xp', v_txp);
	end if;
	update profiles set coins = coins + v_coins, xp = xp + v_xp, season_points = season_points + p_season,
		updated_at = now() where id = p_uid and coins + v_coins >= 0 returning coins, xp into v_bal, v_txp;
	if not found then
		raise exception 'monedas insuficientes' using errcode = 'P0001';
	end if;
	if p_season > 0 and _current_season() is not null then
		insert into season_progress (user_id, season_id, points) values (p_uid, _current_season(), p_season)
			on conflict (user_id, season_id) do update set points = season_progress.points + excluded.points;
	end if;
	return jsonb_build_object('applied', true, 'coins', v_coins, 'xp', v_xp, 'balance', v_bal, 'total_xp', v_txp);
end $$;

-- ---------------------------------------------------------------------------------------------------------------------
-- Perfil

create or replace function public.create_profile(p_username text, p_display_name text) returns jsonb
		language plpgsql security definer set search_path = public, pg_temp as $$
declare u uuid := _uid();
begin
	if exists (select 1 from profiles where id = u) then
		raise exception 'el perfil ya existe' using errcode = 'P0001';
	end if;
	if p_username !~ '^[A-Za-z0-9_]{3,16}$' then
		raise exception 'nombre de usuario invalido: 3 a 16 letras, numeros o _' using errcode = 'P0001';
	end if;
	if exists (select 1 from profiles where lower(username) = lower(p_username)) then
		raise exception 'ese nombre de usuario ya esta en uso' using errcode = 'P0001';
	end if;
	insert into profiles (id, username, display_name) values (u, p_username, left(trim(p_display_name), 20));
	-- Lo gratuito queda en el inventario desde el comienzo.
	insert into inventory (user_id, item_id, qty, source)
		select u, id, 1, 'inicio' from catalog_items where unlock = 'free' and active on conflict do nothing;
	perform _grant(u, 500, 0, 0, 'bienvenida', 'bienvenida');
	return get_my_state();
end $$;

create or replace function public.get_my_state() returns jsonb language plpgsql stable security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid(); p profiles; s text := _current_season();
begin
	select * into p from profiles where id = u;
	if not found then
		return jsonb_build_object('profile', null);
	end if;
	return jsonb_build_object(
		'profile', to_jsonb(p) || jsonb_build_object('level', level_for(p.xp)),
		'inventory', coalesce((select jsonb_object_agg(item_id, qty) from inventory where user_id = u and qty > 0), '{}'::jsonb),
		'boosts', coalesce((select jsonb_agg(to_jsonb(b) - 'user_id') from boosts b where user_id = u
			and (remaining > 0 or expires_at > now())), '[]'::jsonb),
		'season', case when s is null then null else (select jsonb_build_object('id', s, 'points', coalesce(sp.points, 0),
			'premium', coalesce(sp.premium, false), 'claimed_free', coalesce(sp.claimed_free, '{}'),
			'claimed_premium', coalesce(sp.claimed_premium, '{}'))
			from (select 1) one left join season_progress sp on sp.user_id = u and sp.season_id = s) end,
		'active_match', (select id from matches where status = 'active' and u in (player_a, player_b)
			order by created_at desc limit 1));
end $$;

-- Cambio de nombre de usuario: el primero es gratis; despues, uno cada 30 dias.
create or replace function public.change_username(p_new text) returns jsonb language plpgsql security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid(); p profiles;
begin
	select * into p from profiles where id = u for update;
	if p.username_changes > 0 and p.username_changed_at > now() - interval '30 days' then
		raise exception 'podes cambiar el nombre una vez cada 30 dias' using errcode = 'P0001';
	end if;
	if p_new !~ '^[A-Za-z0-9_]{3,16}$' then
		raise exception 'nombre de usuario invalido: 3 a 16 letras, numeros o _' using errcode = 'P0001';
	end if;
	if exists (select 1 from profiles where lower(username) = lower(p_new) and id <> u) then
		raise exception 'ese nombre de usuario ya esta en uso' using errcode = 'P0001';
	end if;
	update profiles set username = p_new, username_changes = username_changes + 1, username_changed_at = now(),
		updated_at = now() where id = u;
	return get_my_state();
end $$;

-- Identidad editable sin costo: nombre visible, apodo, pais y numero (1..99).
create or replace function public.update_identity(p_display_name text, p_nickname text, p_country text,
		p_number int) returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare u uuid := _uid();
begin
	if char_length(trim(p_display_name)) not between 2 and 20 or char_length(p_nickname) > 16
			or char_length(p_country) > 2 or p_number not between 1 and 99 then
		raise exception 'datos de identidad invalidos' using errcode = 'P0001';
	end if;
	update profiles set display_name = trim(p_display_name), nickname = p_nickname, country = upper(p_country),
		shirt_number = p_number, updated_at = now() where id = u;
	return get_my_state();
end $$;

-- Apariencia: los colores y estilos basicos son libres; cada objeto equipado (camiseta, botines, balon, festejo...)
-- tiene que estar en el inventario o ser gratuito.
create or replace function public.update_appearance(p_appearance jsonb) returns jsonb language plpgsql
		security definer set search_path = public, pg_temp as $$
declare
	u uuid := _uid();
	k text;
	v jsonb;
	item_keys text[] := array['jersey','shorts','socks','boots','ball','celebration','number_style','emote'];
	free_keys text[] := array['jersey_color','jersey_color2','shorts_color','socks_color','boots_color','skin',
		'hair','hair_style','sock_height','sock_style'];
begin
	for k, v in select * from jsonb_each(p_appearance) loop
		if k = any(item_keys) then
			if jsonb_typeof(v) <> 'string' or not exists (
					select 1 from catalog_items c where c.id = v #>> '{}' and (c.unlock = 'free'
						or exists (select 1 from inventory i where i.user_id = u and i.item_id = c.id and i.qty > 0))) then
				raise exception 'no tenes ese objeto: %', v #>> '{}' using errcode = 'P0001';
			end if;
		elsif k = any(free_keys) then
			if jsonb_typeof(v) <> 'number' or (v::text)::numeric < 0 or (v::text)::numeric > 31 then
				raise exception 'valor invalido para %', k using errcode = 'P0001';
			end if;
		else
			raise exception 'campo de apariencia desconocido: %', k using errcode = 'P0001';
		end if;
	end loop;
	update profiles set appearance = appearance || p_appearance, updated_at = now() where id = u;
	return get_my_state();
end $$;

-- Atributos de disparo: los puntos salen del nivel (2 por nivel); cada atributo de 1 a 10. El efecto en el juego es
-- moderado (el cliente los escala con limites: PlayerAttributes.factor).
create or replace function public.spend_attribute_point(p_attribute text) returns jsonb language plpgsql
		security definer set search_path = public, pg_temp as $$
declare u uuid := _uid(); p profiles; spent int; cur int;
begin
	if p_attribute not in ('power','accuracy','curve','height','technique','control') then
		raise exception 'atributo invalido' using errcode = 'P0001';
	end if;
	select * into p from profiles where id = u for update;
	select coalesce(sum((value::text)::int - 1), 0) into spent from jsonb_each(p.attributes);
	cur := coalesce((p.attributes ->> p_attribute)::int, 1);
	if spent >= (level_for(p.xp) - 1) * 2 then
		raise exception 'no tenes puntos de atributo (se ganan 2 por nivel)' using errcode = 'P0001';
	end if;
	if cur >= 10 then
		raise exception 'ese atributo ya esta al maximo' using errcode = 'P0001';
	end if;
	update profiles set attributes = jsonb_set(attributes, array[p_attribute], to_jsonb(cur + 1)), updated_at = now()
		where id = u;
	return get_my_state();
end $$;

-- ---------------------------------------------------------------------------------------------------------------------
-- Recompensas de juego local (offline, arcade, academia, desafios): el SERVIDOR calcula el monto con su tabla; del
-- cliente solo toma que paso (medalla 0..3, si gano). Idempotente por p_idem y con tope diario.
create or replace function public.claim_reward(p_idem text, p_source text, p_payload jsonb) returns jsonb
		language plpgsql security definer set search_path = public, pg_temp as $$
declare
	u uuid := _uid();
	medal int := least(greatest(coalesce((p_payload ->> 'medal')::int, 0), 0), 3);
	won boolean := coalesce((p_payload ->> 'won')::boolean, false);
	x bigint := 0; c bigint := 0; sp bigint := 0;
	today_x bigint; today_c bigint; today_sp bigint; caps jsonb := _caps();
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
		when 'offline_match' then x := 30 + case when won then 20 else 0 end; c := 15 + case when won then 15 else 0 end;
			sp := 5 + case when won then 5 else 0 end;
		else raise exception 'origen de recompensa desconocido' using errcode = 'P0001';
	end case;
	select coalesce(sum(xp), 0), coalesce(sum(coins), 0), coalesce(sum(season_points), 0)
		into today_x, today_c, today_sp from reward_ledger
		where user_id = u and created_at >= date_trunc('day', now())
		and source in ('arcade','academia','desafio_diario','desafio_semanal','logro','offline_match');
	x := greatest(least(x, (caps ->> 'offline_xp')::bigint - today_x), 0);
	c := greatest(least(c, (caps ->> 'offline_coins')::bigint - today_c), 0);
	sp := greatest(least(sp, (caps ->> 'offline_season')::bigint - today_sp), 0);
	return _grant(u, c, x, sp, p_source, p_idem, p_payload, p_source in ('arcade','offline_match'));
end $$;

-- ---------------------------------------------------------------------------------------------------------------------
-- Tienda con monedas virtuales (no hay dinero real aqui) y consumibles

create or replace function public.buy_item(p_item text, p_idem text) returns jsonb language plpgsql security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid(); it catalog_items; r jsonb; owned int;
begin
	select * into it from catalog_items where id = p_item and active;
	if not found or it.unlock <> 'shop' or it.price_coins is null then
		raise exception 'ese objeto no se vende en la tienda' using errcode = 'P0001';
	end if;
	if level_for((select xp from profiles where id = u)) < it.min_level then
		raise exception 'necesitas nivel % para comprarlo', it.min_level using errcode = 'P0001';
	end if;
	select qty into owned from inventory where user_id = u and item_id = p_item;
	if it.kind not in ('consumable','name_change') and coalesce(owned, 0) > 0 then
		if exists (select 1 from reward_ledger where user_id = u and idem_key = p_idem) then
			return get_my_state();
		end if;
		raise exception 'ya lo tenes' using errcode = 'P0001';
	end if;
	r := _grant(u, -it.price_coins, 0, 0, 'compra', p_idem, jsonb_build_object('item', p_item));
	if (r ->> 'applied')::boolean then
		insert into inventory (user_id, item_id, qty, source) values (u, p_item, 1, 'tienda')
			on conflict (user_id, item_id) do update set qty = inventory.qty + 1;
	end if;
	return get_my_state();
end $$;

-- Activa un consumible: no se acumula con otro del mismo tipo activo (no duplica premios de forma acumulativa).
create or replace function public.use_consumable(p_item text) returns jsonb language plpgsql security definer
		set search_path = public, pg_temp as $$
declare u uuid := _uid(); it catalog_items; k text; b boosts;
begin
	select * into it from catalog_items where id = p_item and kind = 'consumable';
	if not found then
		raise exception 'no es un consumible' using errcode = 'P0001';
	end if;
	update inventory set qty = qty - 1 where user_id = u and item_id = p_item and qty > 0;
	if not found then
		raise exception 'no tenes ese consumible' using errcode = 'P0001';
	end if;
	k := it.data ->> 'boost';
	select * into b from boosts where user_id = u and kind = k;
	if found and (b.remaining > 0 or b.expires_at > now()) then
		raise exception 'ya tenes uno activo de ese tipo' using errcode = 'P0001';
	end if;
	insert into boosts (user_id, kind, remaining, expires_at)
		values (u, k, coalesce((it.data ->> 'matches')::int, 0),
			case when it.data ? 'minutes' then now() + make_interval(mins => (it.data ->> 'minutes')::int) end)
		on conflict (user_id, kind) do update set remaining = excluded.remaining, expires_at = excluded.expires_at;
	return get_my_state();
end $$;

-- Pago real verificado (lo llama SOLO el webhook del proveedor con la service key, nunca el cliente).
create or replace function public.grant_purchase(p_purchase uuid) returns jsonb language plpgsql security definer
		set search_path = public, pg_temp as $$
declare pu purchases; pr store_products; it text;
begin
	select * into pu from purchases where id = p_purchase for update;
	if not found or pu.status <> 'paid' then
		return jsonb_build_object('granted', false, 'status', coalesce(pu.status, 'missing'));
	end if;
	select * into pr from store_products where id = pu.product_id;
	for it in select jsonb_array_elements_text(coalesce(pr.grants -> 'items', '[]'::jsonb)) loop
		if it like 'pase_%' then
			-- El pase premium no es un objeto: activa la pista premium de la temporada vigente.
			if _current_season() is not null then
				insert into season_progress (user_id, season_id, premium) values (pu.user_id, _current_season(), true)
					on conflict (user_id, season_id) do update set premium = true;
			end if;
		else
			insert into inventory (user_id, item_id, qty, source) values (pu.user_id, it, 1, 'compra_real')
				on conflict (user_id, item_id) do update set qty = inventory.qty + 1;
		end if;
	end loop;
	perform _grant(pu.user_id, coalesce((pr.grants ->> 'coins')::bigint, 0), 0, 0, 'compra_real', 'purchase:' || pu.id);
	update purchases set status = 'granted', verified_at = now() where id = pu.id;
	return jsonb_build_object('granted', true);
end $$;

-- ---------------------------------------------------------------------------------------------------------------------
-- Temporada y eventos

create or replace function public.claim_season_tier(p_tier int, p_premium boolean) returns jsonb language plpgsql
		security definer set search_path = public, pg_temp as $$
declare u uuid := _uid(); s text := _current_season(); t season_tiers; sp season_progress; rw jsonb;
begin
	if s is null then
		raise exception 'no hay temporada activa' using errcode = 'P0001';
	end if;
	select * into t from season_tiers where season_id = s and tier = p_tier;
	insert into season_progress (user_id, season_id) values (u, s) on conflict do nothing;
	select * into sp from season_progress where user_id = u and season_id = s for update;
	if t is null or sp.points < t.points_required then
		raise exception 'todavia no llegaste a ese nivel de la temporada' using errcode = 'P0001';
	end if;
	if p_premium and not sp.premium then
		raise exception 'esa recompensa es del pase premium' using errcode = 'P0001';
	end if;
	if (p_premium and p_tier = any(sp.claimed_premium)) or (not p_premium and p_tier = any(sp.claimed_free)) then
		return get_my_state();
	end if;
	rw := case when p_premium then t.premium_reward else t.free_reward end;
	if rw ? 'item' then
		insert into inventory (user_id, item_id, qty, source) values (u, rw ->> 'item', 1, 'temporada')
			on conflict (user_id, item_id) do update set qty = inventory.qty + 1;
	end if;
	perform _grant(u, coalesce((rw ->> 'coins')::bigint, 0), coalesce((rw ->> 'xp')::bigint, 0), 0, 'temporada',
		'season:' || s || ':' || p_tier || ':' || p_premium::text, rw);
	if p_premium then
		update season_progress set claimed_premium = claimed_premium || p_tier where user_id = u and season_id = s;
	else
		update season_progress set claimed_free = claimed_free || p_tier where user_id = u and season_id = s;
	end if;
	return get_my_state();
end $$;

create or replace function public.get_events() returns jsonb language sql stable security definer
		set search_path = public, pg_temp as $$
	select coalesce(jsonb_agg(to_jsonb(e) || jsonb_build_object('progress', coalesce(ep.points, 0),
		'matches', coalesce(ep.matches, 0)) order by e.ends_at), '[]'::jsonb)
	from events e left join event_progress ep on ep.event_id = e.id and ep.user_id = auth.uid()
	where now() between e.starts_at and e.ends_at
$$;

-- ---------------------------------------------------------------------------------------------------------------------
-- Presencia, lobby y rankings

create or replace function public.heartbeat() returns void language sql security definer
		set search_path = public, pg_temp as $$
	insert into presence (user_id, last_seen) values (_uid(), now())
		on conflict (user_id) do update set last_seen = now()
$$;

-- Lobby: los HUMANOS conectados son sesiones reales (latido de los ultimos 90 s). La actividad del mundo (partidas de
-- las ultimas 2 h, con bots incluidos) va aparte y se rotula asi en la interfaz.
create or replace function public.get_lobby() returns jsonb language sql stable security definer
		set search_path = public, pg_temp as $$
	select jsonb_build_object(
		'humans_online', (select count(*) from presence where last_seen > now() - interval '90 seconds'),
		'matches_active', (select count(*) from matches where status = 'active'),
		'humans_searching', (select coalesce(jsonb_object_agg(mode, n), '{}'::jsonb) from
			(select mode, count(*) n from matchmaking_queue group by mode) q),
		'world_activity', (select count(*) from matches where created_at > now() - interval '2 hours'),
		'popular', (select coalesce(jsonb_agg(mode order by n desc), '[]'::jsonb) from
			(select mode, count(*) n from matches where created_at > now() - interval '24 hours' group by mode) p))
$$;

-- Rankings: solo partidas entre humanos (vs_bots = false) de la temporada actual. Los bots nunca aparecen.
-- p_mode = 'todos' suma todos los modos por jugador.
create or replace function public.get_leaderboard(p_mode text, p_metric text, p_limit int default 50) returns jsonb
		language plpgsql stable security definer set search_path = public, pg_temp as $$
declare s text := coalesce(_current_season(), 'sin_temporada'); col text; out jsonb;
begin
	col := case p_metric when 'rating' then 'st.rating' when 'wins' then 'st.wins' when 'goals' then 'st.goals'
		when 'saves' then 'st.saves' when 'points' then 'st.points'
		when 'accuracy' then 'case when st.shots >= 10 then round(100.0 * st.on_target / st.shots) else 0 end'
		else null end;
	if col is null then
		raise exception 'metrica invalida' using errcode = 'P0001';
	end if;
	execute format('select coalesce(jsonb_agg(x), ''[]''::jsonb) from (select p.username, p.display_name,
		(%s)::bigint as value, st.played, st.wins from (select user_id, sum(played) played, sum(wins) wins,
		sum(goals) goals, sum(saves) saves, sum(shots) shots, sum(on_target) on_target, sum(points) points,
		max(rating) rating from player_stats where season_id = $1 and vs_bots = false and ($2 = ''todos'' or mode = $2)
		group by user_id) st join profiles p on p.id = st.user_id where st.played > 0
		order by 3 desc, st.wins desc limit $3) x', col) into out using s, p_mode, least(greatest(p_limit, 1), 100);
	return out;
end $$;
