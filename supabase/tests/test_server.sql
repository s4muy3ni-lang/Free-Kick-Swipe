-- Pruebas del servidor sobre PostgreSQL local (ver run_local.sh). Cada bloque actua COMO un usuario (rol authenticated
-- con su claim) y verifica que RLS y las funciones hagan cumplir las reglas: nada de valor se escribe desde el cliente,
-- todo premio se cobra una sola vez, el arquero que eligio la zona ataja, los bots no entran en rankings.

\set ON_ERROR_STOP on
set client_min_messages = notice;

create function public.t_ok(cond boolean, msg text) returns void language plpgsql as $$
begin
	if cond is not true then raise exception 'FALLO: %', msg; end if;
	raise notice 'ok: %', msg;
end $$;
-- Ejecuta sql y espera un error cuyo mensaje contenga pat.
create function public.t_err(q text, pat text, msg text) returns void language plpgsql as $$
begin
	begin
		execute q;
	exception when others then
		if sqlerrm ilike '%' || pat || '%' then raise notice 'ok: %', msg; return; end if;
		raise exception 'FALLO: % (error inesperado: %)', msg, sqlerrm;
	end;
	raise exception 'FALLO: % (no hubo error)', msg;
end $$;
grant execute on function public.t_ok(boolean, text), public.t_err(text, text, text) to authenticated;

insert into auth.users (id, email) values
	('00000000-0000-0000-0000-000000000001', 'a@x'), ('00000000-0000-0000-0000-000000000002', 'b@x'),
	('00000000-0000-0000-0000-000000000003', 'c@x');

-- ---- Usuario 1: perfil, RLS, recompensas -------------------------------------------------------------------------
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
select t_ok((create_profile('Pibe10', 'Pibe Diez') -> 'profile' ->> 'coins')::int = 500, 'perfil nuevo con 500 monedas de bienvenida');
select t_ok((get_my_state() -> 'inventory') ? 'ball_clasico' and (get_my_state() -> 'inventory') ? 'ball_moderno'
	and not (get_my_state() -> 'inventory') ? 'ball_llamas', 'dos balones gratis desde el comienzo, los demas bloqueados');
select t_err($$select create_profile('Otro', 'Otro')$$, 'ya existe', 'no se crea un segundo perfil');
select t_err($$update profiles set coins = 999999$$, 'permission denied', 'el cliente no puede cambiar sus monedas');
select t_err($$insert into inventory (user_id, item_id, source) values (auth.uid(), 'ball_llamas', 'trampa')$$, 'permission denied', 'el cliente no puede agregarse objetos');
select t_err($$select _grant(auth.uid(), 100000, 0, 0, 'trampa', 'trampa-1')$$, 'permission denied', 'el cliente no puede llamar a _grant');
select t_err($$select grant_purchase(gen_random_uuid())$$, 'permission denied', 'el cliente no puede entregarse compras');
select t_ok((claim_reward('arcade-0001-xx', 'arcade', '{"medal": 3, "xp": 99999}') ->> 'xp')::int = 95, 'arcade oro: 95 XP calculados en el servidor (ignora el xp del cliente)');
select t_ok((claim_reward('arcade-0001-xx', 'arcade', '{"medal": 3}') ->> 'applied')::boolean = false, 'la misma recompensa no se cobra dos veces');
select t_err($$select claim_reward('x-cheat-0001', 'jackpot', '{}')$$, 'desconocido', 'origen de recompensa inventado: rechazado');
do $$ begin for i in 1..40 loop perform claim_reward('arcade-loop-' || lpad(i::text, 4, '0'), 'arcade', '{"medal": 3}'); end loop; end $$;
select t_ok((select sum(xp) from reward_ledger where source in ('arcade','academia','desafio_diario','desafio_semanal','logro','offline_match')) <= 1500, 'tope diario de XP offline (1500)');
select t_ok((select sum(coins) from reward_ledger where source = 'arcade') <= 800, 'tope diario de monedas offline (800)');
select t_ok((select sum(season_points) from reward_ledger where source = 'arcade') <= 300, 'tope diario de puntos de temporada offline (300)');

-- Tienda con monedas virtuales y consumibles
select t_err($$select buy_item('jersey_liso', 'buy-0000-01')$$, 'no se vende', 'lo gratuito no se compra');
select t_ok((buy_item('energizante_monedas', 'buy-0000-02') -> 'inventory' ->> 'energizante_monedas')::int = 1, 'compra de un consumible');
select t_ok((get_my_state() -> 'inventory' ->> 'energizante_monedas')::int = 1
	and (select count(*) from reward_ledger where idem_key = 'buy-0000-02') = 1, 'la misma compra repetida no cobra dos veces');
select buy_item('energizante_monedas', 'buy-0000-02');
select t_ok((get_my_state() -> 'inventory' ->> 'energizante_monedas')::int = 1, 'reintento con la misma clave: sin doble entrega');
select t_err($$select buy_item('ball_llamas', 'buy-0000-03')$$, 'nivel', 'el balon en llamas pide nivel 6');
select t_err($$select update_appearance('{"ball": "ball_llamas"}')$$, 'no tenes', 'no se equipa lo que no se tiene');
select t_err($$select update_appearance('{"monedas": 5}')$$, 'desconocido', 'campo de apariencia inventado: rechazado');
select t_ok((update_appearance('{"ball": "ball_moderno", "jersey": "jersey_rayas", "jersey_color": 3, "jersey_color2": 5}')
	-> 'profile' -> 'appearance' ->> 'jersey') = 'jersey_rayas', 'colores libres y diseño gratuito equipados');
select t_ok(jsonb_array_length(use_consumable('energizante_monedas') -> 'boosts') = 1, 'energizante activado');
select buy_item('energizante_monedas', 'buy-0000-04');
select t_err($$select use_consumable('energizante_monedas')$$, 'activo', 'no se acumulan dos energizantes iguales');
-- Con 1500 XP es nivel 5: 2 puntos por nivel ganado = 8 puntos; el noveno no.
do $$ begin for i in 1..8 loop perform spend_attribute_point('power'); end loop; end $$;
select t_ok((get_my_state() -> 'profile' -> 'attributes' ->> 'power')::int = 9, 'nivel 5: 8 puntos de atributo gastados');
select t_err($$select spend_attribute_point('accuracy')$$, 'puntos', 'no hay mas puntos que los del nivel');
select t_err($$select claim_season_tier(4, false)$$, 'llegaste', 'temporada: no se reclama un nivel no alcanzado (300 de 400 puntos)');
select t_err($$select claim_season_tier(1, true)$$, 'premium', 'temporada: el premio premium pide el pase');

-- ---- Usuario 2 y 3 -----------------------------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
select t_err($$select create_profile('PIBE10', 'Copia')$$, 'en uso', 'nombre de usuario unico sin importar mayusculas');
select create_profile('Arquerito', 'Arquerito');
select t_ok((select count(*) from profiles) = 1, 'RLS: cada uno ve solo su perfil');
select t_ok((select count(*) from reward_ledger where user_id <> auth.uid()) = 0, 'RLS: no ve el libro de otro');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', false);
select create_profile('Solito', 'Solito');

-- ---- Partida humana de penales --------------------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
select t_ok(find_match('penales', 50) ->> 'status' = 'searching', 'u1 busca rival');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
select set_config('t.m', (find_match('penales', 50) -> 'match' ->> 'id'), false);
select t_ok(current_setting('t.m') <> '', 'u2 encuentra a u1: partida humana');
select t_ok((get_my_state() -> 'profile' ->> 'coins')::int = 450, 'entrada de 50 cobrada');
-- Tiro 0: patea u1 (lado 0). u2 ataja: elige la zona 2.
select submit_turn(current_setting('t.m')::uuid, 'keeper_pick', '{"zone": 2}');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
select t_ok((select count(*) from jsonb_array_elements(get_match(current_setting('t.m')::uuid) -> 'turns') t
	where t -> 'payload' ? 'zone') = 0, 'el que patea NO ve la zona del arquero');
select t_ok((select count(*) from match_turns where kind = 'keeper_pick') = 0, 'RLS: tampoco leyendo la tabla');
select t_err($$select submit_turn(current_setting('t.m')::uuid, 'keeper_pick', '{"zone": 1}')$$, 'no te toca', 'el que patea no puede atajar');
select t_ok((submit_turn(current_setting('t.m')::uuid, 'shot', '{"cross_zone": 2, "outcome": "goal"}') -> 'match' ->> 'score_a')::int = 0,
	'tiro a la zona del arquero informado como gol: el servidor lo cuenta atajada');
select t_ok((select t -> 'payload' ->> 'outcome' from jsonb_array_elements(get_match(current_setting('t.m')::uuid) -> 'turns') t
	where t ->> 'kind' = 'shot') = 'save', 'queda registrado como atajada');
select t_err($$select submit_turn(current_setting('t.m')::uuid, 'shot', '{"cross_zone": 0, "outcome": "goal"}')$$, 'no es tu turno', 'no patea dos veces seguidas');
-- Tiro 1: patea u2; u1 ataja la zona 0 y el tiro va a la 4: gol.
select submit_turn(current_setting('t.m')::uuid, 'keeper_pick', '{"zone": 0}');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
select t_err($$select submit_turn(current_setting('t.m')::uuid, 'shot', '{"cross_zone": 0, "outcome": "goal"}', 0)$$, 'rival', 'en una partida humana nadie juega por el otro');
select t_ok((submit_turn(current_setting('t.m')::uuid, 'shot', '{"cross_zone": 4, "outcome": "goal"}') -> 'match' ->> 'score_b')::int = 1, 'gol a otra zona');
select t_err($$select submit_turn(current_setting('t.m')::uuid, 'shot', '{"cross_zone": 1, "outcome": "goal"}')$$, 'no es tu turno', 'tras patear, el turno pasa al rival');
-- Se juega hasta el final: u2 mete todos, u1 erra todos.
do $$
declare st jsonb; n int := 0;
begin
	loop
		perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
		st := get_match(current_setting('t.m')::uuid);
		exit when st -> 'match' ->> 'status' <> 'active' or n > 30;
		if (st -> 'match' ->> 'shooter')::int = 0 then
			perform submit_turn(current_setting('t.m')::uuid, 'shot', '{"cross_zone": -1, "outcome": "goal"}');
		else
			perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
			perform submit_turn(current_setting('t.m')::uuid, 'shot', '{"cross_zone": 3, "outcome": "goal"}');
		end if;
		n := n + 1;
	end loop;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
select t_ok((get_match(current_setting('t.m')::uuid) -> 'match' ->> 'status') = 'finished'
	and (get_match(current_setting('t.m')::uuid) -> 'match' ->> 'winner')::int = 1, 'la partida termina antes si no hay remontada posible y gana u2');
select t_ok((select count(*) from jsonb_array_elements(get_match(current_setting('t.m')::uuid) -> 'turns') t
	where t ->> 'kind' = 'shot' and t -> 'payload' ->> 'outcome' = 'goal' and (t ->> 'side')::int = 0) = 0,
	'un tiro fuera del arco nunca es gol');
select t_ok((select count(*) from reward_ledger where idem_key like 'match:%') = 1, 'u2 cobro el premio de la partida una sola vez');
select t_ok((get_my_state() -> 'profile' ->> 'coins')::int = 450 + 10 + 2 * 50 + 20, 'premio del ganador: base + pozo de entradas');
select t_ok((select rating from player_stats where mode = 'penales' and not vs_bots) > 1000, 'Elo sube al ganar a un humano');

-- ---- Partida contra bot ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', false);
select t_ok(find_match('dardos', 0) ->> 'status' = 'searching', 'u3 busca rival de dardos');
select t_err($$select start_bot_match('dardos')$$, 'humano', 'el bot no aparece antes de esperar a un humano');
reset role;
update matchmaking_queue set joined_at = now() - interval '10 seconds';
set role authenticated;
select set_config('t.b', (start_bot_match('dardos') -> 'match' ->> 'id'), false);
select t_ok((get_match(current_setting('t.b')::uuid) -> 'opponent' ->> 'is_bot')::boolean, 'rival bot con perfil');
select t_ok((get_match(current_setting('t.b')::uuid) -> 'opponent' ->> 'personality') is not null, 'el bot tiene personalidad');
select t_ok((submit_turn(current_setting('t.b')::uuid, 'score', '{"points": 999}') -> 'match' ->> 'score_a')::int = 60, 'puntaje por turno con tope del modo (60)');
do $$
declare st jsonb; n int := 0;
begin
	loop
		st := get_match(current_setting('t.b')::uuid);
		exit when st -> 'match' ->> 'status' <> 'active' or n > 30;
		if (st -> 'match' ->> 'shooter')::int = 0 then
			perform submit_turn(current_setting('t.b')::uuid, 'score', '{"points": 40}');
		else
			perform submit_turn(current_setting('t.b')::uuid, 'score', '{"points": 20}', 1);
		end if;
		n := n + 1;
	end loop;
end $$;
select t_ok((get_match(current_setting('t.b')::uuid) -> 'match' ->> 'status') = 'finished', 'partida contra bot terminada');
select t_ok((select vs_bots from player_stats where mode = 'dardos'), 'estadisticas contra bots separadas');
select t_ok(jsonb_array_length(get_leaderboard('todos', 'wins', 50)) = 2
	and not (get_leaderboard('todos', 'wins', 50))::text ilike '%Solito%', 'ranking: solo humanos que jugaron contra humanos (u3 solo jugo contra un bot)');
select t_ok((get_leaderboard('todos', 'wins', 50) -> 0 ->> 'username') = 'Arquerito', 'el ranking ordena: primero el que gano');
select t_ok((get_lobby() ->> 'humans_online')::int >= 1, 'lobby: humanos conectados reales');
select t_ok(jsonb_array_length(get_events()) >= 2, 'eventos vigentes desde datos del backend');

-- ---- Chat ----------------------------------------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
select set_config('t.c', (find_match('penales', 0) ->> 'status'), false);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
select set_config('t.m2', (find_match('penales', 0) -> 'match' ->> 'id'), false);
select t_ok(jsonb_array_length(send_chat(current_setting('t.m2')::uuid, 'quick', 'buen_tiro') -> 'chat') = 1, 'frase rapida enviada');
select t_err($$select send_chat(current_setting('t.m2')::uuid, 'emote', '😀')$$, 'espera', 'limite de frecuencia del chat');
reset role;
update chat_messages set created_at = now() - interval '5 seconds';
set role authenticated;
select t_ok((send_chat(current_setting('t.m2')::uuid, 'text', 'sos un pelotudo') -> 'chat' -> -1 ->> 'body') not ilike '%pelotudo%', 'insulto filtrado');
reset role;
update chat_messages set created_at = now() - interval '5 seconds';
set role authenticated;
select t_err($$select send_chat(current_setting('t.m2')::uuid, 'quick', 'te voy a romper')$$, 'invalida', 'frase rapida fuera de la lista: rechazada');

-- ---- Tiempo de turno ---------------------------------------------------------------------------------------------
reset role;
update matches set turn_deadline = now() - interval '1 minute' where id = current_setting('t.m2')::uuid;
set role authenticated;
select t_ok((claim_timeout(current_setting('t.m2')::uuid) -> 'match' ->> 'shot_n')::int = 1, 'turno vencido: tiro de penalizacion fallado y pasa el turno');
select t_ok((select count(*) from jsonb_array_elements(get_match(current_setting('t.m2')::uuid) -> 'turns') t where t ->> 'kind' = 'timeout') = 1, 'queda registrado el tiro automatico');

-- ---- Temporada ------------------------------------------------------------------------------------------------------
reset role;
update season_progress set points = 250 where user_id = '00000000-0000-0000-0000-000000000002';
set role authenticated;
select set_config('t.coins', (get_my_state() -> 'profile' ->> 'coins'), false);
select claim_season_tier(1, false);
select claim_season_tier(1, false);
select t_ok((get_my_state() -> 'profile' ->> 'coins')::int = current_setting('t.coins')::int + 55, 'nivel 1 de temporada cobrado una sola vez (55)');
select t_err($$select claim_season_tier(2, true)$$, 'premium', 'el premio premium pide el pase');
reset role;
