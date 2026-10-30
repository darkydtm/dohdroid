#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/module/scripts" "$TMP/module/config" "$TMP/bin"
cp "$ROOT/module/scripts/firewall.sh" "$TMP/module/scripts/firewall.sh"
cat > "$TMP/bin/iptables" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$*" >> "$TEST_LOG"
exit 0
SCRIPT
chmod +x "$TMP/bin/iptables"
export TEST_LOG="$TMP/log" DOHD_IPTABLES="$TMP/bin/iptables"
sh "$TMP/module/scripts/firewall.sh" install
grep -q -- '-p udp --dport 53 -j REDIRECT' "$TEST_LOG"
grep -q -- '-p tcp --dport 53 -j REDIRECT' "$TEST_LOG"
