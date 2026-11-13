-- Catalogo ampliado (pedido del usuario: «expansion de la personalizacion»): camisetas, shorts, medias, botines,
-- balones, accesorios (nuevo tipo) y objetos premium (nuevo desbloqueo). Los premium son solo esteticos y NO se venden:
-- buy_item solo vende unlock = 'shop' y los pagos reales no estan activados (pedido: «preparar categorias de articulos
-- premium sin activar pagos reales»). Ningun objeto cambia la fisica, el tiro ni los atributos.

alter table public.catalog_items drop constraint if exists catalog_items_kind_check;
alter table public.catalog_items add constraint catalog_items_kind_check check (kind in ('jersey','shorts','socks','boots','ball',
	'emote','celebration','number_style','consumable','name_change','accessory'));
alter table public.catalog_items drop constraint if exists catalog_items_unlock_check;
alter table public.catalog_items add constraint catalog_items_unlock_check check (unlock in ('free','progression','season','event',
	'shop','premium'));

insert into public.catalog_items (id, kind, name, description, rarity, unlock, price_coins, min_level, data, sort) values
	('jersey_diagonal', 'jersey', 'Diagonal', 'Franjas en diagonal de dos colores.', 'comun', 'free', null, 1, '{"pattern": "diagonal"}', 20),
	('jersey_mangas', 'jersey', 'Mangas de color', 'El cuerpo de un color y las mangas de otro.', 'comun', 'free', null, 1, '{"pattern": "mangas"}', 21),
	('jersey_cuello', 'jersey', 'Cuello y puños', 'Clásica, con cuello y puños de contraste.', 'raro', 'progression', null, 4, '{"pattern": "cuello"}', 22),
	('jersey_cuadros', 'jersey', 'Cuadros', 'Cuadros chicos de dos colores.', 'raro', 'shop', 500, 2, '{"pattern": "cuadros"}', 23),
	('jersey_geometrica', 'jersey', 'Geométrica', 'Chevrones modernos de dos colores.', 'epico', 'shop', 900, 3, '{"pattern": "geometrica"}', 24),
	('jersey_premium_oro', 'jersey', 'Edición Oro', 'Negra con detalles dorados. Premium: solo estética.', 'legendario', 'premium', null, 1, '{"pattern": "cuello", "colors": [3, 5], "premium": true}', 25),
	('shorts_doble', 'shorts', 'Doble franja', 'Dos franjas finas a los costados.', 'comun', 'free', null, 1, '{"pattern": "doble"}', 10),
	('shorts_bajo', 'shorts', 'Ruedo de color', 'Terminación de otro color abajo.', 'raro', 'shop', 250, 1, '{"pattern": "bajo"}', 11),
	('socks_dos_franjas', 'socks', 'Dos franjas', 'Dos franjas finas arriba.', 'comun', 'free', null, 1, '{"pattern": "dos_franjas"}', 10),
	('socks_verticales', 'socks', 'Rayas verticales', 'Rayas verticales de dos colores.', 'raro', 'shop', 250, 1, '{"pattern": "verticales"}', 11),
	('boots_blanco_minimal', 'boots', 'Blanco minimal', 'Blancos, sin detalles, suela roja.', 'comun', 'free', null, 1, '{"model": "moderno", "color": 2}', 10),
	('boots_neon_rosa', 'boots', 'Neón rosa', 'Rosa fluo con franja negra y suela amarilla.', 'raro', 'shop', 600, 2, '{"model": "pro", "color": 4}', 11),
	('boots_retro_cuero', 'boots', 'Retro de cuero', 'Cuero marrón con talón y cordones crema.', 'raro', 'progression', null, 7, '{"model": "clasico", "color": 1}', 12),
	('boots_tricolor', 'boots', 'Tricolor', 'Blancos con puntera azul y suela roja.', 'epico', 'shop', 1000, 4, '{"model": "moderno", "color": 2}', 13),
	('boots_premium_galaxia', 'boots', 'Galaxia', 'Violeta noche con franja que brilla. Premium: solo estética.', 'legendario', 'premium', null, 1, '{"model": "pro", "color": 1, "glow": true, "premium": true}', 14),
	('ball_premium_oro', 'ball', 'Balón de Oro', 'Dorado con triángulos negros. Premium: solo estética.', 'legendario', 'premium', null, 1, '{"design": "oro_premium", "premium": true}', 20),
	('acc_munequeras', 'accessory', 'Muñequeras', 'Un par de muñequeras.', 'comun', 'free', null, 1, '{"slot": "wrists", "color": 0}', 1),
	('acc_cinta', 'accessory', 'Cinta para el pelo', 'Vincha deportiva.', 'comun', 'free', null, 1, '{"slot": "head", "color": 2}', 2),
	('acc_vendas', 'accessory', 'Vendas', 'Vendaje en los tobillos.', 'raro', 'shop', 300, 1, '{"slot": "ankles", "color": 2}', 3),
	('acc_mangas', 'accessory', 'Mangas largas', 'Mangas térmicas bajo la camiseta.', 'raro', 'shop', 400, 2, '{"slot": "sleeves", "color": 3}', 4),
	('acc_capitan', 'accessory', 'Brazalete de capitán', 'El brazalete de los que mandan.', 'epico', 'progression', null, 10, '{"slot": "armband", "color": 5}', 5)
	on conflict (id) do nothing;

-- Apariencia ampliada: accesorios (lista de objetos propios o gratuitos, hasta 5), barba, altura y contextura (dentro de
-- limites que no rompen el esqueleto ni dan ventaja), y el nombre en la camiseta (hasta 12 letras, sin insultos).
create or replace function public.update_appearance(p_appearance jsonb) returns jsonb language plpgsql
		security definer set search_path = public, pg_temp as $$
declare
	u uuid := _uid();
	k text;
	v jsonb;
	e jsonb;
	item_keys text[] := array['jersey','shorts','socks','boots','ball','celebration','number_style','emote'];
	free_keys text[] := array['jersey_color','jersey_color2','shorts_color','socks_color','boots_color','skin',
		'hair','hair_style','sock_height','sock_style','beard','height','build'];
	bad text[] := array['puto','puta','pelotudo','boludo','forro','mierda','concha','idiota','imbecil','tarado'];
	w text;
begin
	for k, v in select * from jsonb_each(p_appearance) loop
		if k = any(item_keys) then
			if jsonb_typeof(v) <> 'string' or not exists (
					select 1 from catalog_items c where c.id = v #>> '{}' and (c.unlock = 'free'
						or exists (select 1 from inventory i where i.user_id = u and i.item_id = c.id and i.qty > 0))) then
				raise exception 'no tenes ese objeto: %', v #>> '{}' using errcode = 'P0001';
			end if;
		elsif k = 'accessories' then
			if jsonb_typeof(v) <> 'array' or jsonb_array_length(v) > 5 then
				raise exception 'accesorios invalidos' using errcode = 'P0001';
			end if;
			for e in select * from jsonb_array_elements(v) loop
				if jsonb_typeof(e) <> 'string' or not exists (
						select 1 from catalog_items c where c.id = e #>> '{}' and c.kind = 'accessory' and (c.unlock = 'free'
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
