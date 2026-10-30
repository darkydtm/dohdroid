#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat > "$TMP/bin/ping" <<'SCRIPT'
#!/bin/sh
printf '%s\n' 'PING dns.nextdns.io (45.90.28.78): 56 data bytes'
SCRIPT
chmod +x "$TMP/bin/ping"
cat > "$TMP/config.toml" <<'CONFIG'
url = "https://dns.nextdns.io/94f6c1"
bootstrap_ips = []
CONFIG
PATH="$TMP/bin:$PATH" sh "$ROOT/module/scripts/bootstrap.sh" "$TMP/config.toml"
grep -q 'bootstrap_ips = \["45.90.28.78"\]' "$TMP/config.toml"
