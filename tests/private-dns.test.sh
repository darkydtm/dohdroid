#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/module/run"
cat > "$TMP/bin/settings" <<'SCRIPT'
#!/bin/sh
case "$1:$3" in
	get:private_dns_mode) cat "$TEST_DIR/mode" ;;
	put:private_dns_mode) printf '%s' "$4" > "$TEST_DIR/mode" ;;
	delete:private_dns_mode) printf null > "$TEST_DIR/mode" ;;
	*) exit 1 ;;
esac
SCRIPT
chmod +x "$TMP/bin/settings"
export TEST_DIR="$TMP" PATH="$TMP/bin:$PATH" MODDIR="$TMP/module"
printf hostname > "$TMP/mode"
. "$ROOT/module/scripts/private-dns.sh"
private_dns_disable
[ "$(cat "$TMP/mode")" = off ]
private_dns_disable
private_dns_restore
[ "$(cat "$TMP/mode")" = hostname ]
[ ! -f "$MODDIR/run/private-dns-mode" ]
printf null > "$TMP/mode"
private_dns_disable
private_dns_restore
[ "$(cat "$TMP/mode")" = null ]
printf opportunistic > "$TMP/mode"
private_dns_disable
printf hostname > "$TMP/mode"
private_dns_restore
[ "$(cat "$TMP/mode")" = hostname ]
