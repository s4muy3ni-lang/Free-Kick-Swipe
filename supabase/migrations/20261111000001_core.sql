-- Free-Kick-Swipe: esquema base (perfiles, catalogo, inventario, libro de recompensas, consumibles, temporadas, eventos,
-- estadisticas). Reglas: RLS en todas las tablas; el cliente (rol authenticated) solo LEE sus filas o datos publicos;
-- toda escritura con valor (monedas, XP, inventario, compras, resultados) pasa por funciones SECURITY DEFINER que validan
-- y recalculan en el servidor. Los bots no tienen fila de usuario: nunca entran en player_stats ni en rankings.

-- ---------------------------------------------------------------------------------------------------------------------
-- Perfiles
create table public.profiles (
	id uuid primary key references auth.users(id) on delete cascade,
	username text not null,
	display_name text not null,
	nickname text not null default '',
	country text not null default '',
	shirt_number int not null default 10 check (shirt_number between 1 and 99),
	xp bigint not null default 0 check (xp >= 0),
	coins bigint not null default 0 check (coins >= 0),
	season_points bigint not null default 0 check (season_points >= 0),
	appearance jsonb not null default '{}'::jsonb,
	attributes jsonb not null default '{"power":1,"accuracy":1,"curve":1,"height":1,"technique":1,"control":1}'::jsonb,
	attribute_points int not null default 0 check (attribute_points >= 0),
	username_changes int not null default 0,
	username_changed_at timestamptz,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now(),
	constraint username_format check (username ~ '^[A-Za-z0-9_]{3,16}$'),
	constraint display_name_len check (char_length(display_name) between 2 and 20)
);
create unique index profiles_username_lower on public.profiles (lower(username));

-- ---------------------------------------------------------------------------------------------------------------------
-- Catalogo de cosmeticos y consumibles (datos del backend: se cambian sin actualizar la app)
create table public.catalog_items (
	id text primary key,
	kind text not null check (kind in ('jersey','shorts','socks','boots','ball','emote','celebration','number_style',
		'consumable','name_change')),
	name text not null,
	description text not null default '',
	rarity text not null default 'comun' check (rarity in ('comun','raro','epico','legendario')),
	-- free: disponible desde el comienzo; progression: se abre con nivel; season/event: recompensa; shop: con monedas
	unlock text not null check (unlock in ('free','progression','season','event','shop')),
	price_coins int check (price_coins is null or price_coins > 0),
	min_level int not null default 1,
	data jsonb not null default '{}'::jsonb,
	active boolean not null default true,
	sort int not null default 0
);

-- Productos con dinero real (preparado; NO se cobra hasta aprobar el proveedor): lo que entrega cada producto
create table public.store_products (
	id text primary key,
	name text not null,
	grants jsonb not null,               -- {"items": ["pase_t1"], "coins": 0}
	price_usd_cents int not null check (price_usd_cents > 0),
	prices jsonb not null default '{}'::jsonb,   -- precios locales de referencia, p. ej. {"ARS": 1500000}
	active boolean not null default false
);

create table public.purchases (
	id uuid primary key default gen_random_uuid(),
	user_id uuid not null references auth.users(id) on delete cascade,
	product_id text not null references public.store_products(id),
	provider text not null,
	provider_ref text not null,
	status text not null default 'pending' check (status in ('pending','paid','granted','refunded','failed')),
	amount_cents int not null,
	currency text not null,
	created_at timestamptz not null default now(),
	verified_at timestamptz,
	unique (provider, provider_ref)
);

-- ---------------------------------------------------------------------------------------------------------------------
-- Inventario, libro de recompensas (idempotente) y consumibles activos
create table public.inventory (
	user_id uuid not null references auth.users(id) on delete cascade,
	item_id text not null references public.catalog_items(id),
	qty int not null default 1 check (qty >= 0),
	source text not null,
	acquired_at timestamptz not null default now(),
	primary key (user_id, item_id)
);

create table public.reward_ledger (
	id bigserial primary key,
	user_id uuid not null references auth.users(id) on delete cascade,
	idem_key text not null,
	source text not null,
	coins bigint not null default 0,
	xp bigint not null default 0,
	season_points bigint not null default 0,
	detail jsonb not null default '{}'::jsonb,
	created_at timestamptz not null default now(),
	unique (user_id, idem_key)
);
create index reward_ledger_user_day on public.reward_ledger (user_id, created_at);

create table public.boosts (
	user_id uuid not null references auth.users(id) on delete cascade,
	kind text not null check (kind in ('coins_x2','xp_x2','streak_shield')),
	remaining int not null default 0,
	expires_at timestamptz,
	primary key (user_id, kind)
);

-- ---------------------------------------------------------------------------------------------------------------------
-- Modos online, temporadas, eventos, estadisticas
create table public.game_modes (
	id text primary key,
	name text not null,
	description text not null,
	rules text not null,
	kind text not null check (kind in ('penales','tiros_libres','minijuego')),
	scene_def jsonb not null default '{}'::jsonb,     -- juego/nivel del cliente que se usa
	entry_fees int[] not null default '{0,50,100}',
	max_points_per_turn int not null default 1,
	rounds int not null default 5,
	turn_seconds int not null default 20,
	art jsonb not null default '{}'::jsonb,
	online boolean not null default true,
	sort int not null default 0
);

create table public.seasons (
	id text primary key,
	name text not null,
	theme jsonb not null default '{}'::jsonb,
	starts_at timestamptz not null,
	ends_at timestamptz not null,
	check (ends_at > starts_at)
);

create table public.season_tiers (
	season_id text not null references public.seasons(id) on delete cascade,
	tier int not null check (tier >= 1),
	points_required bigint not null,
	free_reward jsonb not null default '{}'::jsonb,      -- {"coins": 100} o {"item": "balon_llamas"}
	premium_reward jsonb not null default '{}'::jsonb,
	primary key (season_id, tier)
);

create table public.season_progress (
	user_id uuid not null references auth.users(id) on delete cascade,
	season_id text not null references public.seasons(id) on delete cascade,
	points bigint not null default 0,
	premium boolean not null default false,
	claimed_free int[] not null default '{}',
	claimed_premium int[] not null default '{}',
	primary key (user_id, season_id)
);

create table public.events (
	id text primary key,
	title text not null,
	subtitle text not null default '',
	mode text references public.game_modes(id),
	starts_at timestamptz not null,
	ends_at timestamptz not null,
	rules text not null default '',
	rewards jsonb not null default '{}'::jsonb,     -- {"per_win_points": 10, "tiers": [[50, {"coins": 200}], ...]}
	missions jsonb not null default '[]'::jsonb,
	art jsonb not null default '{}'::jsonb,
	check (ends_at > starts_at)
);

create table public.event_progress (
	user_id uuid not null references auth.users(id) on delete cascade,
	event_id text not null references public.events(id) on delete cascade,
	points bigint not null default 0,
	matches int not null default 0,
	claimed int[] not null default '{}',
	primary key (user_id, event_id)
);

-- Estadisticas por modo y temporada. vs_bots separa lo jugado contra la IA: los rankings solo leen vs_bots = false.
create table public.player_stats (
	user_id uuid not null references auth.users(id) on delete cascade,
	season_id text not null,
	mode text not null,
	vs_bots boolean not null,
	played int not null default 0,
	wins int not null default 0,
	losses int not null default 0,
	goals int not null default 0,
	saves int not null default 0,
	shots int not null default 0,
	on_target int not null default 0,
	points bigint not null default 0,
	rating int not null default 1000,
	primary key (user_id, season_id, mode, vs_bots)
);

create table public.presence (
	user_id uuid primary key references auth.users(id) on delete cascade,
	last_seen timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------------------------------------
-- RLS: activado en todo; el cliente solo lee lo suyo o lo publico. Ninguna politica de escritura para el cliente.
alter table public.profiles enable row level security;
alter table public.catalog_items enable row level security;
alter table public.store_products enable row level security;
alter table public.purchases enable row level security;
alter table public.inventory enable row level security;
alter table public.reward_ledger enable row level security;
alter table public.boosts enable row level security;
alter table public.game_modes enable row level security;
alter table public.seasons enable row level security;
alter table public.season_tiers enable row level security;
alter table public.season_progress enable row level security;
alter table public.events enable row level security;
alter table public.event_progress enable row level security;
alter table public.player_stats enable row level security;
alter table public.presence enable row level security;

create policy own_profile on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy own_purchases on public.purchases for select to authenticated using (user_id = (select auth.uid()));
create policy own_inventory on public.inventory for select to authenticated using (user_id = (select auth.uid()));
create policy own_ledger on public.reward_ledger for select to authenticated using (user_id = (select auth.uid()));
create policy own_boosts on public.boosts for select to authenticated using (user_id = (select auth.uid()));
create policy own_season on public.season_progress for select to authenticated using (user_id = (select auth.uid()));
create policy own_event on public.event_progress for select to authenticated using (user_id = (select auth.uid()));
create policy own_stats on public.player_stats for select to authenticated using (user_id = (select auth.uid()));
create policy public_catalog on public.catalog_items for select to anon, authenticated using (active);
create policy public_products on public.store_products for select to anon, authenticated using (active);
create policy public_modes on public.game_modes for select to anon, authenticated using (online);
create policy public_seasons on public.seasons for select to anon, authenticated using (true);
create policy public_tiers on public.season_tiers for select to anon, authenticated using (true);
create policy public_events on public.events for select to anon, authenticated using (true);

revoke all on all tables in schema public from anon, authenticated;
grant select on public.profiles, public.purchases, public.inventory, public.reward_ledger, public.boosts,
	public.season_progress, public.event_progress, public.player_stats to authenticated;
grant select on public.catalog_items, public.store_products, public.game_modes, public.seasons, public.season_tiers,
	public.events to anon, authenticated;
