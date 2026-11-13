-- Atajadas por 9 sectores (3 x 3) con alcance fisico del arquero (pedido del usuario: «la deteccion debe basarse en el
-- alcance real… si la pelota va demasiado pegada al angulo y supera el alcance fisico de la estirada, sera gol aunque
-- pertenezca al mismo sector»). Mismas constantes que KeeperReach y KeeperZones del juego (scripts/setpiece/) y que
-- LocalBackend.keeper_rule: un arquero parado en el centro del arco, que se jugo antes del golpe.

-- Sector (0..8) del punto (y = alto, z = ancho) en un arco de 7,32 x 2,44, o -1 si queda afuera.
create or replace function public.keeper_zone_of(p_y float8, p_z float8) returns int language sql immutable
		set search_path = public, pg_temp as $$
	select case when p_y is null or p_z is null or abs(p_z) > 3.66 or p_y > 2.44 or p_y < -0.05 then -1
		else least(greatest(floor(greatest(p_y, 0.0) / (2.44 / 3.0))::int, 0), 2) * 3
			+ least(greatest(floor((p_z + 3.66) / (7.32 / 3.0))::int, 0), 2) end
$$;

-- Alcance lateral (m) al centro de la pelota a la altura p_y con p_t segundos (KeeperReach.reach con atributos neutros):
-- 3,5 m hasta 1,2 m de alto, bajando en linea hasta 2,4 m a la altura del travesaño; el tiempo lo achica entre 0,12 s
-- (no arranca) y 0,65 s (estirado del todo), nunca por debajo de la mitad.
create or replace function public.keeper_reach(p_y float8, p_t float8) returns float8 language sql immutable
		set search_path = public, pg_temp as $$
	select (case when p_y <= 1.2 then 3.5 else greatest(3.5 + (2.4 - 3.5) * (p_y - 1.2) / (2.44 - 1.2), 0.0) end)
		* least(greatest((p_t - 0.12) / (0.65 - 0.12), 0.5), 1.0)
$$;

-- El cruce esta al alcance de un arquero parado en p_keeper_z (penal: el centro). p_flight = tiempo de vuelo informado,
-- acotado a lo posible (p_min_flight a 3 s: 0,3 s en el penal, 0,5 s en el tiro libre); se suma la anticipacion de un
-- arquero que se jugo antes del golpe (0,12 s).
create or replace function public.keeper_reachable(p_y float8, p_z float8, p_flight float8, p_keeper_z float8 default 0.0,
		p_min_flight float8 default 0.3) returns boolean language sql immutable set search_path = public, pg_temp as $$
	select p_y is not null and p_z is not null and p_y >= -0.05
		and abs(p_z - p_keeper_z) <= keeper_reach(p_y, least(greatest(coalesce(p_flight, p_min_flight), p_min_flight), 3.0) + 0.12)
$$;

-- Tiros libres por turnos: puntos de tiro {distancia, ancho} (FreeKickSpots del juego). En cada ronda (tiro / 2) los dos
-- patean desde el mismo punto; el orden empieza en el desplazamiento de la partida (spot_offset, sorteado al crearla).
create or replace function public.fk_spot(p_round int, p_offset int) returns float8[] language sql immutable
		set search_path = public, pg_temp as $$
	select (array[array[22.0, -7.0], array[25.0, 5.0], array[20.5, 10.0], array[27.0, -1.0], array[23.0, 12.0],
		array[21.0, -11.0], array[26.0, 8.0]]::float8[])[((p_round + p_offset) % 7 + 7) % 7 + 1:((p_round + p_offset) % 7 + 7) % 7 + 1][1:2]
$$;

-- Donde se para el arquero para un tiro libre desde el ancho p_z (FreeKickSpots.keeper_z): en la bisectriz, corrido
-- hacia el palo que no tapa la barrera.
create or replace function public.fk_keeper_z(p_z float8) returns float8 language sql immutable
		set search_path = public, pg_temp as $$
	select least(greatest(-(case when abs(p_z) < 2.0 then 0.0 else 3.66 * sign(p_z) * 0.75 end) * 0.35 + p_z * 0.06, -1.2), 1.2)
$$;

revoke execute on function public.keeper_zone_of(float8, float8), public.keeper_reach(float8, float8),
	public.keeper_reachable(float8, float8, float8, float8, float8), public.fk_spot(int, int), public.fk_keeper_z(float8)
	from public, anon, authenticated;

alter table public.matches add column if not exists spot_offset int not null default floor(random() * 7)::int;

update public.game_modes set rules = 'Alternan tirador y arquero. El arquero elige uno de los 9 sectores antes del tiro: ataja si el tiro va a ese sector y le llega (pegado al ángulo es gol). 20 s por tiro.'
	where id = 'penales';
update public.game_modes set description = 'Superá la barrera y al arquero; después atajás vos.',
	rules = 'Alternan tirador y arquero desde el mismo punto en cada ronda (lo fija el servidor). El arquero elige uno de los 9 sectores antes del tiro. 20 s por tiro.'
	where id = 'tiros_libres';

-- Turnos: el arquero elige un sector 0..8 (oculto hasta el tiro) y la regla de atajada usa el sector y el alcance.
create or replace function public.submit_turn(p_match uuid, p_kind text, p_payload jsonb, p_side int default null)
		returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
	u uuid := _uid(); m matches; gm game_modes; side int; late boolean; outcome text; cz int; kz int; pts int;
	caps jsonb := _caps(); bot_turn boolean := false; inserted int := 0; reachable boolean := true;
	kpos float8 := 0.0; min_flight float8 := 0.3; sp float8[];
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
			reachable := keeper_reachable((p_payload ->> 'cross_y')::float8, (p_payload ->> 'cross_z')::float8,
				coalesce((p_payload ->> 'flight')::float8, min_flight), kpos, min_flight);
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
