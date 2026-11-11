#!/usr/bin/env bash
# Exporta los datos iniciales del servidor (catalogo, modos, temporada, eventos) a resources/online/seed.json desde una
# base construida con las migraciones (supabase/tests/run_local.sh). La fuente unica es el SQL; el JSON lo usa el
# cliente sin servidor (LocalBackend) y como respaldo de presentacion.
set -euo pipefail
cd "$(dirname "$0")/../.."
psql -U postgres -d fks_test -At -c "select jsonb_pretty(jsonb_build_object(
	'game_modes', (select jsonb_agg(to_jsonb(g) order by sort) from game_modes g),
	'catalog_items', (select jsonb_agg(to_jsonb(c) order by kind, sort) from catalog_items c),
	'seasons', (select jsonb_agg(to_jsonb(s)) from seasons s),
	'season_tiers', (select jsonb_agg(to_jsonb(t) order by tier) from season_tiers t),
	'events', (select jsonb_agg(to_jsonb(e) order by starts_at) from events e),
	'caps', _caps()))" > resources/online/seed.json
echo "escrito resources/online/seed.json"
