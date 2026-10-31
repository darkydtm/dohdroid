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
EXPECTED_DNS='https://example.com/dns'
assert_description() {
	status=$1
	expected="description=DoH: $status | DNS: $EXPECTED_DNS"
	update_description "$status"
	grep -Fxq "$expected" "$MODDIR/module.prop"
}
assert_description ERROR
assert_description ON
