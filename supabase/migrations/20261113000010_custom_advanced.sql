-- Personalizacion avanzada (pedido del usuario: «peinados, barbas, bigotes, altura y complexion… botines con color
-- principal, secundario, suela y cordones… nombre en la camiseta… contenido desbloqueable por nivel, desafios, logros,
-- eventos, monedas y temporadas»). Mismas reglas que LocalBackend.
--  - Tipos nuevos de objeto: haircut (peinados) y beard (barbas); desbloqueo nuevo: achievement (se entrega al cobrar el
--    logro data.achievement con claim_reward('logro')).
--  - update_appearance: haircut y beard son objetos (la clave «beard» numerica de 20261113000008 no la usaba ningun
--    cliente); colores libres nuevos boots_color2, boots_sole y boots_laces (-1 = los del par).
--  - Arreglo: los objetos de progresion (por nivel) nunca llegaban al inventario, asi que no se podian equipar; ahora
--    valen desde su nivel (como los muestra la tienda).
-- La altura y la complexion son solo esteticas: el servidor no las usa en ninguna regla de juego.

alter table public.catalog_items drop constraint if exists catalog_items_kind_check;
alter table public.catalog_items add constraint catalog_items_kind_check check (kind in ('jersey','shorts','socks','boots','ball',
	'emote','celebration','number_style','consumable','name_change','accessory','haircut','beard'));
alter table public.catalog_items drop constraint if exists catalog_items_unlock_check;
alter table public.catalog_items add constraint catalog_items_unlock_check check (unlock in ('free','progression','season','event',
	'shop','premium','achievement'));

insert into public.catalog_items (id, kind, name, description, rarity, unlock, price_coins, min_level, data, sort) values
	('hair_natural', 'haircut', 'Natural', 'El pelo de siempre.', 'comun', 'free', null, 1, '{}', 1),
	('hair_rapado', 'haircut', 'Rapado', 'Bien cortito.', 'comun', 'free', null, 1, '{}', 2),
	('hair_rulos', 'haircut', 'Rulos', 'Rulos arriba.', 'comun', 'free', null, 1, '{}', 3),
	('hair_jopo', 'haircut', 'Jopo', 'Para arriba adelante.', 'raro', 'progression', null, 3, '{}', 4),
	('hair_rodete', 'haircut', 'Rodete', 'Atado atrás.', 'raro', 'shop', 350, 2, '{}', 5),
	('hair_melena', 'haircut', 'Melena', 'Pelo largo hasta el cuello.', 'epico', 'shop', 500, 5, '{}', 6),
	('hair_afro', 'haircut', 'Afro', 'Volumen para todos lados.', 'epico', 'shop', 650, 6, '{}', 7),
	('hair_cresta', 'haircut', 'Cresta', 'Se gana con el logro Goleador.', 'epico', 'achievement', null, 1, '{"achievement": "goles_10"}', 8),
	('hair_estrella', 'haircut', 'Cresta dorada', 'Premium: solo estética.', 'legendario', 'premium', null, 1, '{"premium": true}', 9),
	('beard_none', 'beard', 'Sin barba', 'Afeitado.', 'comun', 'free', null, 1, '{}', 1),
	('beard_bigote', 'beard', 'Bigote', 'Bigote clásico.', 'comun', 'free', null, 1, '{}', 2),
	('beard_corta', 'beard', 'Barba corta', 'Prolija.', 'comun', 'free', null, 1, '{}', 3),
	('beard_candado', 'beard', 'Candado', 'Bigote y mentón.', 'raro', 'progression', null, 4, '{}', 4),
	('beard_completa', 'beard', 'Barba completa', 'Tupida.', 'raro', 'shop', 300, 3, '{}', 5),
	('beard_vikinga', 'beard', 'Barba vikinga', 'Se gana con el logro Guantes firmes.', 'epico', 'achievement', null, 1, '{"achievement": "atajadas_10"}', 6)
	on conflict (id) do nothing;

-- Lo gratuito nuevo queda en el inventario de los perfiles que ya existian (como en create_profile).
insert into public.inventory (user_id, item_id, qty, source)
	select p.id, c.id, 1, 'inicio' from public.profiles p cross join public.catalog_items c
	where c.unlock = 'free' and c.active and c.kind in ('haircut', 'beard') on conflict do nothing;

create or replace function public.update_appearance(p_appearance jsonb) returns jsonb language plpgsql
		security definer set search_path = public, pg_temp as $$
declare
	u uuid := _uid();
	k text;
	v jsonb;
	e jsonb;
	item_keys text[] := array['jersey','shorts','socks','boots','ball','celebration','number_style','emote','haircut','beard'];
	free_keys text[] := array['jersey_color','jersey_color2','shorts_color','socks_color','boots_color','skin',
		'hair','hair_style','sock_height','sock_style','height','build','boots_color2','boots_sole','boots_laces'];
	lv int := level_for((select xp from profiles where id = _uid()));
	bad text[] := array['puto','puta','pelotudo','boludo','forro','mierda','concha','idiota','imbecil','tarado'];
	w text;
begin
	for k, v in select * from jsonb_each(p_appearance) loop
		if k = any(item_keys) then
			if jsonb_typeof(v) <> 'string' or not exists (
					select 1 from catalog_items c where c.id = v #>> '{}' and (c.unlock = 'free'
						or (c.unlock = 'progression' and lv >= c.min_level)
						or exists (select 1 from inventory i where i.user_id = u and i.item_id = c.id and i.qty > 0))
						and (k not in ('haircut', 'beard') or c.kind = k)) then
				raise exception 'no tenes ese objeto: %', v #>> '{}' using errcode = 'P0001';
			end if;
		elsif k = 'accessories' then
			if jsonb_typeof(v) <> 'array' or jsonb_array_length(v) > 5 then
				raise exception 'accesorios invalidos' using errcode = 'P0001';
			end if;
			for e in select * from jsonb_array_elements(v) loop
				if jsonb_typeof(e) <> 'string' or not exists (
						select 1 from catalog_items c where c.id = e #>> '{}' and c.kind = 'accessory' and (c.unlock = 'free'
							or (c.unlock = 'progression' and lv >= c.min_level)
							or exists (select 1 from inventory i where i.user_id = u and i.item_id = c.id and i.qty > 0))) then
					raise exception 'no tenes ese accesorio: %', e #>> '{}' using errcode = 'P0001';
				end if;
			end loop;
		elsif k = 'shirt_name' then
			if jsonb_typeof(v) <> 'string' or char_length(v #>> '{}') > 12
					or (v #>> '{}') !~ '^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9 .''-]*$' then
				raise exception 'nombre invalido (hasta 12 letras o numeros)' using errcode = 'P0001';
			end if;
			foreach w in array bad loop
				if lower(v #>> '{}') like '%' || w || '%' then
					raise exception 'ese nombre no se puede usar' using errcode = 'P0001';
				end if;
			end loop;
		elsif k = any(free_keys) then
			if jsonb_typeof(v) <> 'number' or (v::text)::numeric > 31 or (v::text)::numeric
					< (case when k in ('boots_color2', 'boots_sole', 'boots_laces') then -1 else 0 end) then
				raise exception 'valor invalido para %', k using errcode = 'P0001';
			end if;
		else
			raise exception 'campo de apariencia desconocido: %', k using errcode = 'P0001';
		end if;
	end loop;
	update profiles set appearance = appearance || p_appearance, updated_at = now() where id = u;
	return get_my_state();
end $$;

-- Premios de juego local (igual que 20261113000009) con la entrega de los objetos de logro.
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
	boostable boolean := p_source in ('arcade', 'offline_match'); r jsonb;
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
	r := _grant(u, c, x, sp, p_source, p_idem, p_payload, boostable);
	-- Logro: los objetos que se ganan con ese logro quedan en el inventario (una vez: la misma clave no vuelve a entrar).
	if p_source = 'logro' and (r ->> 'applied')::boolean then
		insert into inventory (user_id, item_id, qty, source)
			select u, c2.id, 1, 'logro' from catalog_items c2
			where c2.unlock = 'achievement' and c2.active and c2.data ->> 'achievement' = p_payload ->> 'id'
			on conflict do nothing;
	end if;
	return r;
end $$;

grant execute on function public.update_appearance(jsonb), public.claim_reward(text, text, jsonb) to authenticated;
