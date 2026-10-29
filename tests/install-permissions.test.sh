#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MODPATH="$TMP/module"
export MODPATH
mkdir -p "$MODPATH/scripts" "$MODPATH/system/bin/arm64-v8a"
cp "$ROOT"/module/scripts/*.sh "$MODPATH/scripts/"
printf '#!/bin/sh\nexit 0\n' > "$MODPATH/system/bin/arm64-v8a/dohd"
chmod 0644 "$MODPATH"/scripts/*.sh "$MODPATH/system/bin/arm64-v8a/dohd"
set_perm() {
	chmod "$4" "$1"
}
. "$ROOT/module/customize.sh"
for file in "$MODPATH"/scripts/*.sh "$MODPATH/system/bin/arm64-v8a/dohd"; do
	[ -x "$file" ] || { printf 'not executable: %s\n' "$file" >&2; exit 1; }
done
