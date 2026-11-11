#!/usr/bin/env bash
# Aplica las migraciones sobre una base local nueva (con la simulacion minima de Supabase) y corre las pruebas SQL.
# Uso: PGHOST=/var/tmp/fks_pg PGPORT=54329 supabase/tests/run_local.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
DB=fks_test
psql -U postgres -d postgres -q -c "drop database if exists $DB" -c "create database $DB"
P="psql -U postgres -d $DB -q -v ON_ERROR_STOP=1"
$P -f supabase/tests/00_supabase_stub.sql
for f in supabase/migrations/*.sql; do
	echo "migracion: $f"
	$P -f "$f"
done
$P -t -f supabase/tests/test_server.sql 2>&1 | grep -E "NOTICE:  ok|FALLO|ERROR" | sed "s/^.*NOTICE:  //"; test "${PIPESTATUS[0]}" = 0
echo "PRUEBAS SQL: OK"
