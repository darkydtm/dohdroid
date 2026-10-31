#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MODULE="$TMP/module"
BIN="$TMP/bin"
LOG="$TMP/iptables.log"
mkdir -p "$MODULE/scripts" "$MODULE/config" "$BIN"
cp "$ROOT/module/scripts/firewall.sh" "$MODULE/scripts/firewall.sh"
create_iptables_stub() {
	cat > "$BIN/iptables" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$*" >> "$TEST_LOG"
exit 0
SCRIPT
	chmod +x "$BIN/iptables"
}
create_iptables_stub
export TEST_LOG="$LOG" DOHD_IPTABLES="$BIN/iptables"
sh "$MODULE/scripts/firewall.sh" install
EXPECTED_UDP='-p udp --dport 53 -j REDIRECT'
EXPECTED_TCP='-p tcp --dport 53 -j REDIRECT'
grep -Fq -- "$EXPECTED_UDP" "$LOG"
grep -Fq -- "$EXPECTED_TCP" "$LOG"
