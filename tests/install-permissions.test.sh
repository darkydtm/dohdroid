#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MODPATH="$TMP/module"
OLD_MODDIR="$TMP/old"
export MODPATH DOHD_OLD_MODDIR="$OLD_MODDIR"
mkdir -p "$MODPATH/scripts" "$MODPATH/system/bin/arm64-v8a"
cp "$ROOT"/module/scripts/*.sh "$MODPATH/scripts/"
printf '#!/bin/sh\nexit 0\n' > "$MODPATH/system/bin/arm64-v8a/dohd"
chmod 0644 "$MODPATH"/scripts/*.sh "$MODPATH/system/bin/arm64-v8a/dohd"
set_perm() {
	chmod "$4" "$1"
}
. "$ROOT/module/customize.sh"
for file in "$MODPATH"/scripts/*.sh "$MODPATH"/system/bin/arm64-v8a/dohd; do
	[ -x "$file" ] || { printf 'not executable: %s\n' "$file" >&2; exit 1; }
done
[ -f "$MODPATH/config/daemon-enabled" ]
mkdir -p "$OLD_MODDIR/config"
touch "$OLD_MODDIR/config/config.toml"
rm -f "$MODPATH/config/daemon-enabled"
. "$ROOT/module/customize.sh"
[ ! -f "$MODPATH/config/daemon-enabled" ]
