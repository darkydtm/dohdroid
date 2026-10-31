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
case "$*" in *'-C OUTPUT'*) exit 1 ;; esac
exit 0
SCRIPT
chmod +x "$TMP/bin/iptables"
ln -s iptables "$TMP/bin/iptables-legacy"
export TEST_LOG="$TMP/log" DOHD_IPTABLES="$TMP/bin/iptables" PATH="$TMP/bin:$PATH"
EXPECTED_COMMANDS='
-t filter -A DOHD_KILL -m owner --uid-owner 0 -j RETURN
-t filter -A DOHD_KILL -m mark --mark 0x1000000/0x1000000 -j RETURN
-t filter -A DOHD_KILL -p udp --dport 53 -j REJECT
-t filter -A DOHD_KILL -p tcp --dport 53 -j REJECT
'
sh "$TMP/module/scripts/killswitch.sh" install
printf '%s\n' "$EXPECTED_COMMANDS" | while IFS= read -r command; do
	[ -n "$command" ] || continue
	grep -Fxq -- "$command" "$TEST_LOG"
done
sh "$TMP/module/scripts/killswitch.sh" remove
grep -Fxq -- '-t filter -X DOHD_KILL' "$TEST_LOG"
