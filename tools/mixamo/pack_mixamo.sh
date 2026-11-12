#!/usr/bin/env bash
# Paquete CIFRADO de la biblioteca MIXAMO para CI. El repositorio es publico y la licencia de Mixamo permite usar las
# animaciones en juegos pero no redistribuirlas sueltas: en git va solo assets/animations/mixamo_pack.enc (AES-256,
# PBKDF2). La clave es el secret MIXAMO_KEY de GitHub (nunca en el repositorio, el chat ni los registros).
#   tools/mixamo/pack_mixamo.sh encrypt   # despues de reconstruir las bibliotecas (MIXAMO_KEY o MIXAMO_KEY_FILE)
#   tools/mixamo/pack_mixamo.sh decrypt   # CI y PC nuevas: deja las bibliotecas en su lugar
set -euo pipefail
cd "$(dirname "$0")/../.."
FILES=(assets/animations/mixamo_clips.res assets/animations/mixamo_keeper.res assets/animations/mixamo_scenes.res
  resources/setpiece/shot_clips_mixamo.json)
PACK=assets/animations/mixamo_pack.enc
if [ -n "${MIXAMO_KEY_FILE:-}" ]; then PASS="file:${MIXAMO_KEY_FILE}"; elif [ -n "${MIXAMO_KEY:-}" ]; then PASS="env:MIXAMO_KEY"; else
  echo "Falta MIXAMO_KEY (o MIXAMO_KEY_FILE)" >&2; exit 2; fi
case "${1:-}" in
  encrypt)
    tar -czf - "${FILES[@]}" | openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -out "$PACK" -pass "$PASS"
    echo "cifrado: $PACK ($(stat -c %s "$PACK") bytes)";;
  decrypt)
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -in "$PACK" -pass "$PASS" | tar -xzf -
    for f in "${FILES[@]}"; do [ -f "$f" ] || { echo "falta $f tras descifrar" >&2; exit 1; }; done
    echo "biblioteca MIXAMO descifrada (${#FILES[@]} archivos)";;
  *) echo "uso: $0 encrypt|decrypt" >&2; exit 2;;
esac
