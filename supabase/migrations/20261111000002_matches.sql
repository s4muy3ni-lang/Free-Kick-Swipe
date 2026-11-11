-- Partidas online por turnos: cola de busqueda, partidas (humano contra humano o contra un bot generado por el servidor),
-- turnos con plazo, chat. El cliente solo LEE sus partidas; todo cambio pasa por funciones del servidor.

create table public.matchmaking_queue (
	user_id uuid primary key references auth.users(id) on delete cascade,
	mode text not null references public.game_modes(id),
	entry_fee int not null default 0,
	level int not null,
	rating int not null,
	joined_at timestamptz not null default now()
);

create table public.matches (
	id uuid primary key default gen_random_uuid(),
	mode text not null references public.game_modes(id),
	status text not null default 'active' check (status in ('active','finished','abandoned')),
	player_a uuid not null references auth.users(id),
	player_b uuid references auth.users(id),
	-- Partida contra la IA: el bot lo genera el servidor (nombre, personalidad, habilidad, semilla). No tiene usuario.
	bot jsonb,
	entry_fee int not null default 0,
	rounds int not null,
	turn_seconds int not null,
	-- Turno actual: numero de tiro (0..), lado que patea (0 = player_a), plazo del turno.
	shot_n int not null default 0,
	shooter int not null default 0,
	turn_deadline timestamptz not null,
	score_a int not null default 0,
	score_b int not null default 0,
	timeouts_a int not null default 0,
	timeouts_b int not null default 0,
	winner int,                       -- 0 = player_a, 1 = player_b (o el bot)
	settled boolean not null default false,
	created_at timestamptz not null default now(),
	finished_at timestamptz,
	check ((player_b is null) <> (bot is null))
);
create index matches_player_a on public.matches (player_a, status);
create index matches_player_b on public.matches (player_b, status);

-- Turnos: la eleccion del arquero queda oculta para el rival hasta que llega el tiro (revealed).
create table public.match_turns (
	id bigserial primary key,
	match_id uuid not null references public.matches(id) on delete cascade,
	shot_n int not null,
	side int not null check (side in (0, 1)),
	kind text not null check (kind in ('keeper_pick','shot','score','timeout')),
	payload jsonb not null default '{}'::jsonb,
	revealed boolean not null default true,
	created_at timestamptz not null default now(),
	unique (match_id, shot_n, kind)
);

create table public.chat_messages (
	id bigserial primary key,
	match_id uuid not null references public.matches(id) on delete cascade,
	user_id uuid references auth.users(id) on delete cascade,
	from_bot boolean not null default false,
	kind text not null check (kind in ('text','quick','emote')),
	body text not null,
	created_at timestamptz not null default now()
);
create index chat_messages_match on public.chat_messages (match_id, id);

alter table public.matchmaking_queue enable row level security;
alter table public.matches enable row level security;
alter table public.match_turns enable row level security;
alter table public.chat_messages enable row level security;

create policy own_queue on public.matchmaking_queue for select to authenticated using (user_id = (select auth.uid()));
create policy own_matches on public.matches for select to authenticated
	using ((select auth.uid()) in (player_a, player_b));
-- Un turno se ve si es de una partida propia y (ya se revelo o lo cargo el propio jugador).
create policy own_turns on public.match_turns for select to authenticated using (
	exists (select 1 from public.matches m where m.id = match_id and (select auth.uid()) in (m.player_a, m.player_b)
		and (revealed or (m.player_a = (select auth.uid()) and side = 0) or (m.player_b = (select auth.uid()) and side = 1))));
create policy own_chat on public.chat_messages for select to authenticated using (
	exists (select 1 from public.matches m where m.id = match_id and (select auth.uid()) in (m.player_a, m.player_b)));

revoke all on public.matchmaking_queue, public.matches, public.match_turns, public.chat_messages from anon, authenticated;
grant select on public.matchmaking_queue, public.matches, public.match_turns, public.chat_messages to authenticated;
