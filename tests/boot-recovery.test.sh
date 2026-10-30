#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/module/scripts" "$TMP/module/config" "$TMP/module/run"
cp "$ROOT/module/boot-completed.sh" "$TMP/module/boot-completed.sh"
cat > "$TMP/module/scripts/state.sh" <<'SCRIPT'
daemon_enabled() { [ -f "$MODDIR/config/daemon-enabled" ]; }
killswitch_enabled() { [ -f "$MODDIR/config/killswitch-enabled" ]; }
SCRIPT
cat > "$TMP/module/scripts/process.sh" <<'SCRIPT'
daemon_running() { [ -f "$MODDIR/run/running" ]; }
SCRIPT
cat > "$TMP/module/scripts/description.sh" <<'SCRIPT'
update_description() { :; }
SCRIPT
cat > "$TMP/module/scripts/killswitch.sh" <<'SCRIPT'
printf '%s\n' "kill:$1" >> "$TEST_LOG"
SCRIPT
chmod +x "$TMP/module/scripts/killswitch.sh"
cat > "$TMP/module/scripts/resolver.sh" <<'SCRIPT'
resolver_enabled() { return 0; }
SCRIPT
cat > "$TMP/module/service.sh" <<'SCRIPT'
printf '%s\n' started >> "$TEST_LOG"
SCRIPT
export TEST_LOG="$TMP/log" DOHD_BOOT_RECOVERY_DELAY=0
sh "$TMP/module/boot-completed.sh"
[ ! -f "$TEST_LOG" ]
touch "$TMP/module/config/daemon-enabled"
touch "$TMP/module/config/killswitch-enabled"
sh "$TMP/module/boot-completed.sh"
grep -q '^kill:install$' "$TEST_LOG"
[ "$(grep -c '^started$' "$TEST_LOG")" -eq 1 ]
touch "$TMP/module/run/running"
sh "$TMP/module/boot-completed.sh"
[ "$(grep -c '^started$' "$TEST_LOG")" -eq 1 ]
