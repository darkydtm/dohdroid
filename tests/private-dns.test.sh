#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MODE_HOSTNAME=hostname
MODE_NULL=null
MODE_OPPORTUNISTIC=opportunistic
MODE_OFF=off
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
. "$ROOT/module/scripts/private-dns.sh"
scenario_hostname_is_restored() {
	printf '%s' "$MODE_HOSTNAME" > "$TMP/mode"
	private_dns_disable
	[ "$(cat "$TMP/mode")" = "$MODE_OFF" ]
	private_dns_disable
	private_dns_restore
	[ "$(cat "$TMP/mode")" = "$MODE_HOSTNAME" ]
	[ ! -f "$MODDIR/run/private-dns-mode" ]
}
scenario_null_is_restored() {
	printf '%s' "$MODE_NULL" > "$TMP/mode"
	private_dns_disable
	private_dns_restore
	[ "$(cat "$TMP/mode")" = "$MODE_NULL" ]
}
scenario_original_mode_wins() {
	printf '%s' "$MODE_OPPORTUNISTIC" > "$TMP/mode"
	private_dns_disable
	printf '%s' "$MODE_HOSTNAME" > "$TMP/mode"
	private_dns_restore
	[ "$(cat "$TMP/mode")" = "$MODE_HOSTNAME" ]
}
scenario_hostname_is_restored
scenario_null_is_restored
scenario_original_mode_wins
