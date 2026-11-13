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
-- Con 1500 XP es nivel 5: 2 puntos por nivel ganado = 8 puntos. Desde 20261113000009 subir cuesta 1 punto hasta el 5
-- y 2 del 6 al 8 (ProgressionRules): con 8 puntos la potencia llega a 7 y la mejora siguiente (2 puntos) ya no entra.
do $$ begin for i in 1..6 loop perform spend_attribute_point('power'); end loop; end $$;
select t_ok((get_my_state() -> 'profile' -> 'attributes' ->> 'power')::int = 7, 'nivel 5: 8 puntos de atributo gastados (potencia 7)');
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

-- ---- Atajadas por 9 sectores con alcance fisico (migracion 20261113000006) -----------------------------------------
select t_ok(keeper_zone_of(0.3, -3.0) = 0 and keeper_zone_of(1.2, 0.0) = 4 and keeper_zone_of(2.3, 3.4) = 8,
	'9 sectores: abajo a un palo 0, centro 4, angulo del otro palo 8');
select t_ok(keeper_zone_of(2.6, 0.0) = -1 and keeper_zone_of(0.5, 3.9) = -1, 'afuera del arco no es sector');
select t_ok(keeper_reachable(0.4, 2.6, 0.6), 'abajo a 2,6 m del centro con tiempo: llega');
select t_ok(not keeper_reachable(2.3, 3.4, 0.5), 'pegado al angulo: no llega aunque elija el sector');
select t_ok(keeper_reachable(0.4, 3.4, 0.7) and not keeper_reachable(0.4, 3.4, 0.35), 'pegado al palo abajo: lento llega, muy rapido no');
select t_ok(keeper_reachable(0.4, 3.4, 0.01) = keeper_reachable(0.4, 3.4, 0.3), 'el tiempo de vuelo informado se acota a lo posible');
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000004', 'd@x'),
	('00000000-0000-0000-0000-000000000005', 'e@x');
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', false);
select create_profile('Cuarto', 'Cuarto');
select t_ok(find_match('penales', 0) ->> 'status' = 'searching', 'u4 busca rival');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000005', false);
select create_profile('Quinto', 'Quinto');
select set_config('t.m3', (find_match('penales', 0) -> 'match' ->> 'id'), false);
-- Tiro 0: patea u4. u5 se juega al angulo (sector 8) y el tiro va ahi, pegado al angulo: gol igual.
select submit_turn(current_setting('t.m3')::uuid, 'keeper_pick', '{"zone": 8}');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', false);
select t_ok((submit_turn(current_setting('t.m3')::uuid, 'shot',
	'{"cross_zone": 8, "outcome": "goal", "cross_y": 2.3, "cross_z": 3.4, "flight": 0.5}') -> 'match' ->> 'score_a')::int = 1,
	'sector correcto pero fuera del alcance (angulo): gol');
select t_ok((select (t -> 'payload' ->> 'reachable')::boolean from jsonb_array_elements(get_match(current_setting('t.m3')::uuid) -> 'turns') t
	where t ->> 'kind' = 'shot') = false, 'queda registrado que no llegaba');
-- Tiro 1: patea u5. u4 se juega arriba a la derecha (sector 6) y el tiro va ahi, a su alcance: atajada.
select submit_turn(current_setting('t.m3')::uuid, 'keeper_pick', '{"zone": 6}');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000005', false);
select t_ok((submit_turn(current_setting('t.m3')::uuid, 'shot',
	'{"cross_zone": 6, "outcome": "goal", "cross_y": 2.0, "cross_z": -2.0, "flight": 0.6}') -> 'match' ->> 'score_b')::int = 0,
	'sector correcto y al alcance: atajada');
-- Tiro 2: patea u4. u5 elige el centro; el tirador informa sector 4 pero el cruce es abajo a un palo: el servidor
-- recalcula el sector con el cruce (gol).
select t_err($$select submit_turn(current_setting('t.m3')::uuid, 'keeper_pick', '{"zone": 9}')$$, 'invalida', 'no hay sector 9');
select submit_turn(current_setting('t.m3')::uuid, 'keeper_pick', '{"zone": 4}');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', false);
select t_ok((submit_turn(current_setting('t.m3')::uuid, 'shot',
	'{"cross_zone": 4, "outcome": "goal", "cross_y": 0.4, "cross_z": -3.0, "flight": 0.6}') -> 'match' ->> 'score_a')::int = 2,
	'el sector informado no manda: vale el cruce');
reset role;

-- ---- Tiros libres online por turnos (punto de tiro del servidor y arquero corrido) --------------------------------
select t_ok((fk_spot(0, 0))[1][1] = 22.0 and (fk_spot(0, 0))[1][2] = -7.0 and (fk_spot(8, 0))[1][1] = 25.0, 'puntos de tiro en orden y en ronda');
select t_ok(abs(fk_keeper_z(-7.0) - 0.5408) < 0.001 and fk_keeper_z(0.5) = 0.03, 'el arquero se corre al palo que no tapa la barrera');
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000006', 'f@x'),
	('00000000-0000-0000-0000-000000000007', 'g@x');
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000006', false);
select create_profile('Sexto', 'Sexto');
select t_ok(find_match('tiros_libres', 0) ->> 'status' = 'searching', 'u6 busca rival de tiros libres');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000007', false);
select create_profile('Septimo', 'Septimo');
select set_config('t.m4', (find_match('tiros_libres', 0) -> 'match' ->> 'id'), false);
select t_ok((get_match(current_setting('t.m4')::uuid) -> 'match' ->> 'spot_offset') is not null, 'la partida trae su orden de puntos de tiro');
reset role;
update matches set spot_offset = 0 where id = current_setting('t.m4')::uuid;
set role authenticated;
-- Tiro 0 (ronda 0, punto 22 m / -7): patea u6, u7 ataja al centro.
select submit_turn(current_setting('t.m4')::uuid, 'keeper_pick', '{"zone": 4}');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000006', false);
select t_err($$select submit_turn(current_setting('t.m4')::uuid, 'shot', '{"cross_zone": 4, "outcome": "goal", "cross_y": 1.2, "cross_z": 0.3, "flight": 0.9, "spot": [30, 0]}')$$,
	'punto de tiro', 'un tiro libre desde otro punto se rechaza');
select t_err($$select submit_turn(current_setting('t.m4')::uuid, 'shot', '{"cross_zone": 4, "outcome": "goal"}')$$,
	'punto de tiro', 'y uno sin punto tambien');
select t_ok((submit_turn(current_setting('t.m4')::uuid, 'shot',
	'{"cross_zone": 4, "outcome": "goal", "cross_y": 1.2, "cross_z": 0.3, "flight": 0.9, "spot": [22.0, -7.0]}') -> 'match' ->> 'score_a')::int = 0,
	'tiro libre al sector del arquero y a su alcance: atajada');
-- Tiro 1 (misma ronda y punto): patea u7, u6 se juega abajo a la derecha (0); el tiro va pegado a ese palo, lejos del
-- arquero corrido al otro palo: gol aunque eligio el sector.
select submit_turn(current_setting('t.m4')::uuid, 'keeper_pick', '{"zone": 0}');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000007', false);
select t_ok((submit_turn(current_setting('t.m4')::uuid, 'shot',
	'{"cross_zone": 0, "outcome": "goal", "cross_y": 0.4, "cross_z": -3.4, "flight": 0.9, "spot": [22.0, -7.0]}') -> 'match' ->> 'score_b')::int = 1,
	'el alcance se mide desde donde esta parado el arquero del tiro libre');
reset role;

-- ---- Minijuegos online: elegir minijuego y nivel, o aleatorio (migracion 20261113000007) -------------------------
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', false);
select t_ok(find_match('a_la_vista', 0) ->> 'status' = 'searching', 'u3 busca rival de A la vista');
reset role;
update matchmaking_queue set joined_at = now() - interval '10 seconds';
set role authenticated;
select set_config('t.g', (start_bot_match('a_la_vista') -> 'match' ->> 'id'), false);
select t_err($$select choose_minigame(current_setting('t.g')::uuid, 'a_la_vista', 9)$$, 'nivel invalido', 'A la vista no tiene nivel 9');
select t_err($$select choose_minigame(current_setting('t.g')::uuid, 'penales', 1)$$, 'minijuego invalido', 'los penales no son un minijuego');
select t_err($$select finish_minigame(current_setting('t.g')::uuid, 'boton_caida', 3, 3, 1)$$, 'primero se elige', 'sin elegir no hay resultado');
select t_ok((choose_minigame(current_setting('t.g')::uuid, 'a_la_vista', 3) -> 'match' -> 'minigame' ->> 'level')::int = 3, 'elige A la vista, nivel 3');
select t_ok((get_match(current_setting('t.g')::uuid) -> 'match' -> 'minigame' ->> 'game') = 'boton_caida', 'la sala sabe que minijuego y nivel se juegan');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', false);
select t_err($$select choose_minigame(current_setting('t.g')::uuid, 'guante', 1)$$, 'sala', 'otro jugador no puede cambiar la eleccion');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', false);
select t_err($$select finish_minigame(current_setting('t.g')::uuid, 'boton_caida', 4, 3, 1)$$, 'nivel distinto', 'un resultado de otro nivel se rechaza');
select t_ok((finish_minigame(current_setting('t.g')::uuid, 'boton_caida', 3, 3, 1) -> 'match' ->> 'status') = 'finished', 'resultado del nivel elegido: partida cerrada');
select t_ok((get_match(current_setting('t.g')::uuid) -> 'match' ->> 'winner')::int = 0, 'gana el que hizo mas puntos');
select set_config('t.g2', (rematch_bot(current_setting('t.g')::uuid) -> 'match' ->> 'id'), false);
select t_ok(current_setting('t.g2') <> current_setting('t.g') and (get_match(current_setting('t.g2')::uuid) -> 'match' ->> 'status') = 'active',
	'revancha con el mismo bot sin esperar');
select t_ok((select (choose_minigame(current_setting('t.g2')::uuid, '', 0, true) -> 'match' -> 'minigame') ->> 'random')::boolean, 'aleatorio: lo sortea el servidor');
select t_ok((select (gm.scene_def -> 'levels') @> to_jsonb(((m.minigame ->> 'level')::int)) from matches m join game_modes gm on gm.id = m.mode
	where m.id = current_setting('t.g2')::uuid), 'el sorteo cae en un nivel valido de un minijuego online');
reset role;

-- ---- Rescate online: puntaje y tiempos validados por el servidor -------------------------------------------------
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000008', 'h@x');
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000008', false);
select create_profile('Octavo', 'Octavo');
select t_ok(find_match('rescate', 0) ->> 'status' = 'searching', 'u8 busca rival de Rescate');
reset role;
update matchmaking_queue set joined_at = now() - interval '10 seconds';
set role authenticated;
select set_config('t.r', (start_bot_match('rescate') -> 'match' ->> 'id'), false);
select t_err($$select choose_minigame(current_setting('t.r')::uuid, 'rescate', 3)$$, 'nivel invalido', 'Rescate online: solo niveles de mecanismos');
select choose_minigame(current_setting('t.r')::uuid, 'rescate', 8);
select t_err($$select finish_minigame(current_setting('t.r')::uuid, 'rescate', 8, 9999, 100, '{"rescued": true, "time": 1.0}')$$,
	'tiempo invalido', 'un tiempo imposible se rechaza');
select t_ok((finish_minigame(current_setting('t.r')::uuid, 'rescate', 8, 9999, 100,
	'{"rescued": true, "time": 12.4, "actions": 4, "errors": 1, "falls": 0, "attempts": 1}') -> 'match' ->> 'score_a')::int = 150 + 47 * 2 - 15,
	'el servidor recalcula el puntaje (tiempo que sobra y errores)');
select t_ok((get_match(current_setting('t.r')::uuid) -> 'match' -> 'minigame' -> 'result' ->> 'errors')::int = 1, 'queda registrado el resultado');
reset role;

-- ---- Progresion: costo creciente, tope de puntos, historial, redistribucion, XP decreciente y arquero online ----------
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000009', 'i@x'),
	('00000000-0000-0000-0000-000000000010', 'j@x');
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000009', false);
select create_profile('Noveno', 'Noveno');
reset role;
-- Nivel 9 (5400 XP): 16 puntos, justo lo que cuesta llevar un atributo de 1 a 10 (4 x 1 + 3 x 2 + 2 x 3).
update profiles set xp = 5400 where id = '00000000-0000-0000-0000-000000000009';
set role authenticated;
select t_ok((get_my_state() -> 'progression' ->> 'points_available')::int = 16, 'nivel 9: 16 puntos de mejora');
do $$ begin for i in 1..9 loop perform spend_attribute_point('keeper_reach'); end loop; end $$;
select t_ok((get_my_state() -> 'profile' -> 'attributes' ->> 'keeper_reach')::int = 10
	and (get_my_state() -> 'progression' ->> 'points_spent')::int = 16, 'alcance del arquero al maximo: 16 puntos');
select t_err($$select spend_attribute_point('keeper_reach')$$, 'maximo', 'ningun atributo pasa de 10');
select t_err($$select spend_attribute_point('power')$$, 'puntos', 'sin puntos no hay mejora');
select t_err($$select spend_attribute_point('velocidad_extra')$$, 'invalido', 'atributo inventado: rechazado');
select t_ok(jsonb_array_length(get_my_state() -> 'progression' -> 'history') = 9
	and (get_my_state() -> 'progression' -> 'history' -> 8 ->> 'cost')::int = 3, 'historial de mejoras con su costo');
reset role;
update profiles set xp = 500000 where id = '00000000-0000-0000-0000-000000000009';
set role authenticated;
select t_ok((get_my_state() -> 'progression' ->> 'points_earned')::int = 58, 'los puntos se ganan hasta el nivel 30 (58)');
-- Redistribucion: la primera gratis; la segunda espera 7 dias y cuesta 300 monedas; la misma clave no cobra dos veces.
select set_config('t.rs', respec_attributes('respec-0001')::text, false);
select t_ok((current_setting('t.rs')::jsonb -> 'profile' ->> 'coins')::int = 500
	and (current_setting('t.rs')::jsonb -> 'progression' ->> 'points_spent')::int = 0
	and (current_setting('t.rs')::jsonb -> 'profile' -> 'attributes' ->> 'keeper_reach')::int = 1, 'primera redistribucion gratis: todo a 1');
select spend_attribute_point('power');
select t_err($$select respec_attributes('respec-0002')$$, 'se habilita', 'la segunda redistribucion espera 7 dias');
reset role;
update profiles set respec_at = now() - interval '8 days' where id = '00000000-0000-0000-0000-000000000009';
set role authenticated;
select t_ok((respec_attributes('respec-0003') -> 'profile' ->> 'coins')::int = 200, 'pasados 7 dias: cuesta 300 monedas');
select respec_attributes('respec-0003');
select t_ok((get_my_state() -> 'profile' ->> 'coins')::int = 200 and (get_my_state() -> 'profile' ->> 'respecs')::int = 2,
	'reintento con la misma clave: no cobra ni redistribuye dos veces');
reset role;
update profiles set respec_at = now() - interval '8 days' where id = '00000000-0000-0000-0000-000000000009';
set role authenticated;
select spend_attribute_point('power');
select t_err($$select respec_attributes('respec-0004')$$, 'monedas', 'sin monedas no se redistribuye');
select t_ok((get_my_state() -> 'profile' -> 'attributes' ->> 'power')::int = 2, 'y no cambia nada');
-- XP de partidas offline: un poco por rendimiento (goles y atajadas hasta 5) y rendimiento decreciente al repetir.
select t_ok((claim_reward('offmatch-0001', 'offline_match', '{"won": true, "goals": 99, "saves": 99}') ->> 'xp')::int = 100,
	'partida offline ganada: 50 + goles y atajadas con tope (100 XP)');
do $$ begin for i in 2..8 loop perform claim_reward('offmatch-' || lpad(i::text, 4, '0'), 'offline_match', '{"won": true, "goals": 5, "saves": 5}'); end loop; end $$;
select t_ok((claim_reward('offmatch-0009', 'offline_match', '{"won": true, "goals": 5, "saves": 5}') ->> 'xp')::int = 50,
	'la novena del dia vale la mitad');
-- Online: el alcance del arquero sale de SU perfil (alcance 10: 6 % mas) y nunca del cliente.
do $$ begin for i in 1..9 loop perform spend_attribute_point('keeper_reach'); end loop; end $$;
-- El emparejamiento busca niveles parecidos: para el cruce con u10 (nivel 1) se le baja la experiencia a u9 (los puntos
-- ya gastados quedan).
reset role;
update profiles set xp = 0 where id = '00000000-0000-0000-0000-000000000009';
set role authenticated;
select t_ok(find_match('penales', 0) ->> 'status' = 'searching', 'u9 busca rival');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000010', false);
select create_profile('Decimo', 'Decimo');
select set_config('t.m9', (find_match('penales', 0) -> 'match' ->> 'id'), false);
-- Tiro 0: patea u9; ataja u10 (atributos neutros) en el sector 2: a 3,6 m del centro no llega (alcance 3,5 m).
select submit_turn(current_setting('t.m9')::uuid, 'keeper_pick', '{"zone": 2}');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000009', false);
select t_err($$select respec_attributes('respec-0006')$$, 'partida', 'no se redistribuye con una partida en juego');
select t_ok((submit_turn(current_setting('t.m9')::uuid, 'shot',
	'{"cross_zone": 2, "outcome": "goal", "cross_y": 0.5, "cross_z": 3.6, "flight": 1.0, "keeper_reach": 10}') -> 'match' ->> 'score_a')::int = 1,
	'arquero sin atributos: a 3,6 m no llega (gol)');
-- Tiro 1: patea u10 al mismo lugar; ataja u9 con alcance 10 (3,71 m): atajada.
select submit_turn(current_setting('t.m9')::uuid, 'keeper_pick', '{"zone": 2}');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000010', false);
select t_ok((submit_turn(current_setting('t.m9')::uuid, 'shot',
	'{"cross_zone": 2, "outcome": "goal", "cross_y": 0.5, "cross_z": 3.6, "flight": 1.0}') -> 'match' ->> 'score_b')::int = 0,
	'arquero con alcance 10: el mismo tiro es atajada');
reset role;
select t_ok(not keeper_reachable_attr(2.3, 3.4, 1.0, 0.0, 0.3, 9.0, -9.0), 'ni con atributos al maximo (y valores truchos, acotados) se llega al angulo');

-- ---- Personalizacion avanzada: peinados, barbas, detalles de botines, progresion y logros ----------------------------
insert into auth.users (id, email) values ('00000000-0000-0000-0000-000000000011', 'k@x');
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000011', false);
select create_profile('Once', 'Once');
select t_ok((update_appearance('{"haircut": "hair_rulos", "beard": "beard_bigote", "height": 4, "build": 3, "boots_sole": -1, "boots_laces": 5}')
	-> 'profile' -> 'appearance' ->> 'haircut') = 'hair_rulos', 'peinado y barba gratis, altura, complexion y detalles de botines');
select t_err($$select update_appearance('{"haircut": "hair_afro"}')$$, 'no tenes', 'el afro de la tienda no se equipa sin comprarlo');
select t_err($$select update_appearance('{"haircut": "beard_bigote"}')$$, 'no tenes', 'una barba no va como peinado');
select t_err($$select update_appearance('{"beard": 3}')$$, 'no tenes', 'la barba ya no es un numero: es un objeto');
select t_err($$select update_appearance('{"boots_sole": -2}')$$, 'invalido', 'color de suela fuera de rango');
select t_err($$select update_appearance('{"haircut": "hair_jopo"}')$$, 'no tenes', 'el jopo pide nivel 3');
reset role;
update profiles set xp = 450 where id = '00000000-0000-0000-0000-000000000011';
set role authenticated;
select t_ok((update_appearance('{"haircut": "hair_jopo"}') -> 'profile' -> 'appearance' ->> 'haircut') = 'hair_jopo',
	'con nivel 3 el jopo (de progresion) se equipa sin comprarlo');
select t_err($$select update_appearance('{"haircut": "hair_cresta"}')$$, 'no tenes', 'la cresta pide el logro');
select t_ok((get_my_state() -> 'inventory') ? 'hair_natural' and (get_my_state() -> 'inventory') ? 'beard_none', 'lo gratuito nuevo esta en el inventario');
select claim_reward('logro-goles10-0001', 'logro', '{"id": "goles_10"}');
select t_ok((get_my_state() -> 'inventory' ->> 'hair_cresta')::int = 1, 'el logro Goleador entrega la cresta');
select claim_reward('logro-goles10-0001', 'logro', '{"id": "goles_10"}');
select t_ok((get_my_state() -> 'inventory' ->> 'hair_cresta')::int = 1 and (select count(*) from reward_ledger where idem_key = 'logro-goles10-0001') = 1,
	'cobrar el mismo logro otra vez no duplica nada');
select t_ok((update_appearance('{"haircut": "hair_cresta"}') -> 'profile' -> 'appearance' ->> 'haircut') = 'hair_cresta', 'y se equipa');
select t_err($$select buy_item('hair_estrella', 'buy-hair-0001')$$, 'no se vende', 'el peinado premium no se vende (pagos no activados)');
reset role;
