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
export TEST_LOG="$TMP/log" DOHD_IPTABLES="$TMP/bin/iptables"
mkdir -p "$TMP/bin"
ln -s iptables "$TMP/bin/iptables-legacy"
export PATH="$TMP/bin:$PATH"
sh "$TMP/module/scripts/killswitch.sh" install
grep -q -- '-t filter -A DOHD_KILL -m owner --uid-owner 0 -j RETURN' "$TEST_LOG"
grep -q -- '-t filter -A DOHD_KILL -p udp --dport 53 -j REJECT' "$TEST_LOG"
grep -q -- '-t filter -A DOHD_KILL -p tcp --dport 53 -j REJECT' "$TEST_LOG"
sh "$TMP/module/scripts/killswitch.sh" remove
grep -q -- '-t filter -X DOHD_KILL' "$TEST_LOG"
