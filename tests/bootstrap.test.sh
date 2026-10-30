#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat > "$TMP/bin/ping" <<'SCRIPT'
#!/bin/sh
count=0
[ -f "$PING_COUNT" ] && count=$(cat "$PING_COUNT")
count=$((count + 1))
printf '%s\n' "$count" > "$PING_COUNT"
[ "$count" -gt 12 ] || exit 1
printf '%s\n' 'PING dns.nextdns.io (45.90.28.78): 56 data bytes'
SCRIPT
chmod +x "$TMP/bin/ping"
export PING_COUNT="$TMP/ping-count" DOHD_BOOTSTRAP_DELAY=0
cat > "$TMP/config.toml" <<'CONFIG'
url = "https://dns.nextdns.io/94f6c1"
bootstrap_ips = []
CONFIG
PATH="$TMP/bin:$PATH" sh "$ROOT/module/scripts/bootstrap.sh" "$TMP/config.toml"
grep -q 'bootstrap_ips = \["45.90.28.78"\]' "$TMP/config.toml"

cat > "$TMP/config-with-bootstrap.toml" <<'CONFIG'
url = "https://dns.nextdns.io/94f6c1"
bootstrap_ips = ["45.90.28.78"]
CONFIG
cat > "$TMP/bin/ping" <<'SCRIPT'
#!/bin/sh
exit 1
SCRIPT
PATH="$TMP/bin:$PATH" sh "$ROOT/module/scripts/bootstrap.sh" "$TMP/config-with-bootstrap.toml"
grep -q 'bootstrap_ips = \["45.90.28.78"\]' "$TMP/config-with-bootstrap.toml"
