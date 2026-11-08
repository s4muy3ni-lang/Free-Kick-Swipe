#!/usr/bin/env bash
# Crea la clave de firma de las APK de prueba (UNA sola vez) y deja listos los tres secretos de GitHub.
# La clave NO se guarda en el repositorio ni se muestra por pantalla. Si la pierdes, la proxima APK
# tendra otra firma y habra que desinstalar la anterior una vez.
#
# Uso:   tools/android/make_keystore.sh [ruta/del/futbol5.keystore]
# Luego: gh secret set ANDROID_KEYSTORE_BASE64   < <ruta>.base64.txt
#        gh secret set ANDROID_KEYSTORE_PASSWORD            (pega la contrasena)
#        gh secret set ANDROID_KEY_ALIAS --body futbol5
#        (o pegarlos a mano en Settings > Secrets and variables > Actions)
set -euo pipefail

OUT="${1:-$HOME/futbol5-release.keystore}"
ALIAS="futbol5"

if [ -e "$OUT" ]; then
	echo "Ya existe $OUT: no se sobrescribe (cambiarla invalidaria las actualizaciones)." >&2
	exit 1
fi
command -v keytool >/dev/null || { echo "Falta keytool (instala un JDK)." >&2; exit 1; }

read -rsp "Contrasena del keystore (8 caracteres o mas): " PW; echo
read -rsp "Repite la contrasena: " PW2; echo
[ "$PW" = "$PW2" ] && [ "${#PW}" -ge 8 ] || { echo "Las contrasenas no coinciden o son cortas." >&2; exit 1; }

# PKCS12: la contrasena del keystore y la de la clave son la misma (es lo que usa la exportacion de Godot).
keytool -genkeypair -keystore "$OUT" -storetype PKCS12 -alias "$ALIAS" -keyalg RSA -keysize 2048 \
	-validity 36500 -storepass "$PW" -dname "CN=Futbol 5, O=webmaletin" >/dev/null
chmod 600 "$OUT"
base64 -w0 "$OUT" > "$OUT.base64.txt"
chmod 600 "$OUT.base64.txt"

echo
echo "Keystore:   $OUT   (GUARDALO: sin el no se puede actualizar encima)"
echo "Base64:     $OUT.base64.txt  (contenido del secreto ANDROID_KEYSTORE_BASE64)"
echo "Alias:      $ALIAS            (secreto ANDROID_KEY_ALIAS)"
echo "Huella SHA-256 del certificado (no es secreta; debe repetirse en cada APK):"
keytool -list -keystore "$OUT" -storepass "$PW" 2>/dev/null | grep -i "SHA-256\|SHA256" || true
