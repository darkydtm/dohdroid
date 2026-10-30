#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/module/scripts" "$TMP/module/config" "$TMP/bin"
cp "$ROOT/module/scripts/killswitch.sh" "$TMP/module/scripts/killswitch.sh"
cat > "$TMP/bin/iptables" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$*" >> "$TEST_LOG"
case "$*" in
	*'-C OUTPUT'*) exit 1 ;;
esac
exit 0
SCRIPT
chmod +x "$TMP/bin/iptables"
ln -s iptables "$TMP/bin/ip6tables"
export TEST_LOG="$TMP/log" DOHD_IPTABLES="$TMP/bin/iptables" DOHD_IP6TABLES="$TMP/bin/ip6tables"
mkdir -p "$TMP/bin"
ln -s iptables "$TMP/bin/iptables-legacy"
export PATH="$TMP/bin:$PATH"
sh "$TMP/module/scripts/killswitch.sh" install
if grep -q -- '--uid-owner 0' "$TEST_LOG"; then exit 1; fi
grep -q -- '-t filter -A DOHD_KILL -m mark --mark 0x1000000/0x1000000 -j RETURN' "$TEST_LOG"
grep -q -- '-t filter -A DOHD_KILL -p udp --dport 53 -j REJECT' "$TEST_LOG"
grep -q -- '-t filter -A DOHD_KILL -p tcp --dport 53 -j REJECT' "$TEST_LOG"
[ "$(grep -c -- '-t filter -A DOHD_KILL -p udp --dport 53 -j REJECT' "$TEST_LOG")" -eq 2 ]
[ "$(grep -c -- '-t filter -A DOHD_KILL -p tcp --dport 853 -j REJECT' "$TEST_LOG")" -eq 2 ]
sh "$TMP/module/scripts/killswitch.sh" remove
grep -q -- '-t filter -X DOHD_KILL' "$TEST_LOG"
