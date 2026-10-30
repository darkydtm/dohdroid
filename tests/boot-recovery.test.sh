#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/module/scripts" "$TMP/module/config" "$TMP/module/run"
cp "$ROOT/module/boot-completed.sh" "$TMP/module/boot-completed.sh"
cat > "$TMP/module/scripts/state.sh" <<'SCRIPT'
daemon_enabled() { [ -f "$MODDIR/config/daemon-enabled" ]; }
SCRIPT
cat > "$TMP/module/scripts/process.sh" <<'SCRIPT'
daemon_running() { [ -f "$MODDIR/run/running" ]; }
SCRIPT
cat > "$TMP/module/scripts/description.sh" <<'SCRIPT'
update_description() { :; }
SCRIPT
cat > "$TMP/module/service.sh" <<'SCRIPT'
printf '%s\n' started >> "$TEST_LOG"
if [ -f "$MODDIR/run/fail-once" ]; then
	rm -f "$MODDIR/run/fail-once"
	exit 1
fi
touch "$MODDIR/run/running"
SCRIPT
cat > "$TMP/module/scripts/sleep" <<'SCRIPT'
#!/bin/sh
printf 'sleep:%s\n' "$1" >> "$TEST_LOG"
SCRIPT
chmod +x "$TMP/module/scripts/sleep"
export TEST_LOG="$TMP/log" MODDIR="$TMP/module" PATH="$TMP/module/scripts:$PATH"
sh "$TMP/module/boot-completed.sh"
[ ! -f "$TEST_LOG" ]
touch "$TMP/module/config/daemon-enabled"
touch "$TMP/module/run/fail-once"
sh "$TMP/module/boot-completed.sh"
[ "$(grep -c '^started$' "$TEST_LOG")" -eq 2 ]
grep -q '^sleep:5$' "$TEST_LOG"
sh "$TMP/module/boot-completed.sh"
[ "$(grep -c '^started$' "$TEST_LOG")" -eq 2 ]
