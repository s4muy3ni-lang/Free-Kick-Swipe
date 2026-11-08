#!/usr/bin/env bash
# Ejecuta la suite de pruebas headless. Uso: tools/run_tests.sh [filtro]
# Requiere "godot" 4.7.2 en el PATH (o variable GODOT_BIN).
set -u
GODOT_BIN="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/.."
FILTER_ARGS=()
if [ "${1:-}" != "" ]; then FILTER_ARGS=(-- --filter "$1"); fi
# Reimporta siempre: registra clases globales nuevas (class_name) y recursos modificados.
IMPORT_OUT="$(mktemp)"
if ! "$GODOT_BIN" --headless --path . --import >"$IMPORT_OUT" 2>&1; then
  cat "$IMPORT_OUT"
  rm -f "$IMPORT_OUT"
  exit 1
fi
if grep -q "SCRIPT ERROR\|Parse Error\|Compile Error" "$IMPORT_OUT"; then
  cat "$IMPORT_OUT"
  rm -f "$IMPORT_OUT"
  exit 1
fi
rm -f "$IMPORT_OUT"
OUT="$(mktemp)"
"$GODOT_BIN" --headless --fixed-fps 60 --path . res://tests/run_tests.tscn "${FILTER_ARGS[@]}" 2>&1 \
  | sed -u 's/\x1b\[[0-9;]*m//g' | grep --line-buffered -v '^Picked up' | tee "$OUT"
STATUS="${PIPESTATUS[0]}"
# Un error de script aborta la prueba a medias pero el ejecutor podria darla por buena: se trata como fallo.
if grep -q "SCRIPT ERROR" "$OUT"; then
  echo "FALLO: se detectaron SCRIPT ERROR en la salida (ver arriba); la suite no se considera aprobada."
  STATUS=1
fi
rm -f "$OUT"
exit "$STATUS"
