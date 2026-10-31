#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MODPATH="$TMP/module"
OLD_MODDIR="$TMP/old"
TEST_ABI=arm64-v8a
TEST_BINARY=dohd
export MODPATH DOHD_OLD_MODDIR="$OLD_MODDIR"
mkdir -p "$MODPATH/scripts" "$MODPATH/system/bin/$TEST_ABI"
cp "$ROOT"/module/scripts/*.sh "$MODPATH/scripts/"
printf '#!/bin/sh\nexit 0\n' > "$MODPATH/system/bin/$TEST_ABI/$TEST_BINARY"
chmod 0644 "$MODPATH"/scripts/*.sh "$MODPATH/system/bin/$TEST_ABI/$TEST_BINARY"
set_perm() {
	chmod "$4" "$1"
}
. "$ROOT/module/customize.sh"
for file in "$MODPATH"/scripts/*.sh "$MODPATH"/system/bin/$TEST_ABI/$TEST_BINARY; do
	[ -x "$file" ] || { printf 'not executable: %s\n' "$file" >&2; exit 1; }
done
[ -f "$MODPATH/config/daemon-enabled" ]
mkdir -p "$OLD_MODDIR/config"
touch "$OLD_MODDIR/config/config.toml"
rm -f "$MODPATH/config/daemon-enabled"
. "$ROOT/module/customize.sh"
[ ! -f "$MODPATH/config/daemon-enabled" ]

cat > "$MODPATH/config/config.toml" <<'CONFIG'
[[resolvers]]
name = "cloudflare"
url = "https://cloudflare-dns.com/dns-query"
bootstrap_ips = ["1.1.1.1"]
enabled = true

[[resolvers]]
name = "custom"
url = "https://dns.example.org/dns-query"
bootstrap_ips = []
enabled = true
CONFIG
export DOHD_OLD_MODDIR="$MODPATH"
. "$ROOT/module/customize.sh"
! grep -q 'cloudflare-dns.com' "$MODPATH/config/config.toml"
! grep -q '1.1.1.1' "$MODPATH/config/config.toml"
grep -q 'https://dns.example.org/dns-query' "$MODPATH/config/config.toml"
