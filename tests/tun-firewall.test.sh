#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
RULE_PRIORITY=10530
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/module/scripts" "$TMP/module/config" "$TMP/bin"
cp "$ROOT/module/scripts/tun-firewall.sh" "$TMP/module/scripts/tun-firewall.sh"
cp "$ROOT/module/scripts/state.sh" "$TMP/module/scripts/state.sh"
cat > "$TMP/bin/tool" <<'SCRIPT'
#!/bin/sh
printf '%s %s\n' "${0##*/}" "$*" >> "$TEST_LOG"
mode=${STUB_MODE:-success}
case "$mode:$*" in
	rollback:*'-D OUTPUT'*|rollback:*' rule del '*|rollback:*' route del '*) exit 1 ;;
	fail-tcp:*'-t mangle -A DOHD_TUN -p tcp'*) exit 1 ;;
esac
exit 0
SCRIPT
chmod +x "$TMP/bin/tool"
ln -s tool "$TMP/bin/ip"
ln -s tool "$TMP/bin/iptables"
ln -s tool "$TMP/bin/ip6tables"
export TEST_LOG="$TMP/log" DOHD_IP="$TMP/bin/ip" DOHD_IPTABLES="$TMP/bin/iptables" DOHD_IP6TABLES="$TMP/bin/ip6tables"
if sh "$TMP/module/scripts/tun-firewall.sh" install; then
	printf '%s\n' 'disabled TUN install unexpectedly succeeded' >&2
	exit 1
fi
touch "$TMP/module/config/tun-enabled"
sh "$TMP/module/scripts/tun-firewall.sh" install
if grep -q -- '--uid-owner 0' "$TEST_LOG"; then
	printf '%s\n' 'root-owned system DNS bypasses TUN' >&2
	exit 1
fi
EXPECTED_RULES="
ip -4 rule add priority $RULE_PRIORITY fwmark 0x1000000/0x1000000 lookup 19053
ip -6 rule add priority $RULE_PRIORITY fwmark 0x1000000/0x1000000 lookup 19053
iptables -t mangle -A DOHD_TUN -p udp --dport 53 -j MARK --set-xmark 0x1000000/0x1000000
ip6tables -t mangle -A DOHD_TUN -p tcp --dport 53 -j MARK --set-xmark 0x1000000/0x1000000
"
printf '%s\n' "$EXPECTED_RULES" | while IFS= read -r rule; do
	[ -n "$rule" ] || continue
	grep -Fxq "$rule" "$TEST_LOG"
done
: > "$TEST_LOG"
if STUB_MODE=fail-tcp sh "$TMP/module/scripts/tun-firewall.sh" install; then
	printf '%s\n' 'partial install unexpectedly succeeded' >&2
	exit 1
fi
grep -Fxq "ip -4 rule del priority $RULE_PRIORITY fwmark 0x1000000/0x1000000 lookup 19053" "$TEST_LOG"
grep -Fxq "ip -6 rule del priority $RULE_PRIORITY fwmark 0x1000000/0x1000000 lookup 19053" "$TEST_LOG"
