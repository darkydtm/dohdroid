#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/module/scripts" "$TMP/module/config" "$TMP/bin"
cp "$ROOT/module/scripts/tun-firewall.sh" "$TMP/module/scripts/tun-firewall.sh"
cp "$ROOT/module/scripts/state.sh" "$TMP/module/scripts/state.sh"
cat > "$TMP/bin/tool" <<'SCRIPT'
#!/bin/sh
printf '%s %s\n' "${0##*/}" "$*" >> "$TEST_LOG"
case "$*" in
	*'-D OUTPUT'*|*' rule del '*|*' route del '*) exit 1 ;;
	*'-t mangle -A DOHD_TUN -p tcp'* ) [ "${FAIL_TCP:-0}" = 0 ] || exit 1 ;;
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
grep -q 'ip -4 rule add priority 10530' "$TEST_LOG"
grep -q 'ip -6 rule add priority 10530' "$TEST_LOG"
grep -q 'iptables -t mangle -A DOHD_TUN -p udp --dport 53' "$TEST_LOG"
grep -q 'ip6tables -t mangle -A DOHD_TUN -p tcp --dport 53' "$TEST_LOG"
: > "$TEST_LOG"
if FAIL_TCP=1 sh "$TMP/module/scripts/tun-firewall.sh" install; then
	printf '%s\n' 'partial install unexpectedly succeeded' >&2
	exit 1
fi
grep -q 'ip -4 rule del priority 10530' "$TEST_LOG"
grep -q 'ip -6 rule del priority 10530' "$TEST_LOG"
