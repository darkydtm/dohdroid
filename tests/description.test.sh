#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MODDIR="$TMP/module"
mkdir -p "$MODDIR/config" "$MODDIR/scripts"
cp "$ROOT/module/scripts/description.sh" "$MODDIR/scripts/description.sh"
printf 'id=test\ndescription=DoH: ON\n' > "$MODDIR/module.prop"
printf 'url = "https://example.com/dns"\n' > "$MODDIR/config/config.toml"
. "$MODDIR/scripts/description.sh"
update_description ERROR
grep -q '^description=DoH: ERROR | DNS: https://example.com/dns$' "$MODDIR/module.prop"
update_description ON
grep -q '^description=DoH: ON | DNS: https://example.com/dns$' "$MODDIR/module.prop"
