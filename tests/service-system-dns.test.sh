#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MODDIR="$TMP/module"
LOG="$TMP/log"
mkdir -p "$MODDIR/config" "$MODDIR/run" "$MODDIR/scripts" "$MODDIR/system/bin/x86_64" "$TMP/bin"
cp "$ROOT/module/service.sh" "$MODDIR/service.sh"
create_log_stub() {
	name=$1
	cat > "$MODDIR/scripts/$name.sh" <<'SCRIPT'
#!/bin/sh
printf '%s %s\n' "${0##*/}" "$*" >> "$TEST_LOG"
SCRIPT
}
create_state_stub() {
	cat > "$MODDIR/scripts/state.sh" <<'SCRIPT'
#!/bin/sh
daemon_enabled() { [ -f "$MODDIR/config/daemon-enabled" ]; }
tun_enabled() { [ -f "$MODDIR/config/tun-enabled" ]; }
killswitch_enabled() { [ -f "$MODDIR/config/killswitch-enabled" ]; }
SCRIPT
}
create_private_dns_stub() {
	cat > "$MODDIR/scripts/private-dns.sh" <<'SCRIPT'
#!/bin/sh
private_dns_restore() { return 0; }
private_dns_disable() { return 0; }
SCRIPT
}
create_process_stub() {
	cat > "$MODDIR/scripts/process.sh" <<'SCRIPT'
#!/bin/sh
daemon_pids() { :; }
SCRIPT
}
for script in firewall tun-firewall killswitch; do create_log_stub "$script"; done
printf 'update_description() { :; }\n' > "$MODDIR/scripts/description.sh"
create_state_stub
create_private_dns_stub
create_process_stub
chmod +x "$MODDIR/scripts/"*.sh
cp "$ROOT/module/config/config.toml.example" "$MODDIR/config/config.toml"
touch "$MODDIR/config/daemon-enabled"
printf '#!/bin/sh\nexit 0\n' > "$MODDIR/system/bin/x86_64/dohd"
chmod +x "$MODDIR/system/bin/x86_64/dohd"
printf '#!/bin/sh\nprintf "%%s\\n" x86_64\n' > "$TMP/bin/uname"
chmod +x "$TMP/bin/uname"
export MODDIR TEST_LOG="$LOG" PATH="$TMP/bin:$PATH"
scenario_daemon_not_running() {
	sh "$MODDIR/service.sh"
	if grep -Fq 'install' "$LOG"; then exit 1; fi
	[ ! -f "$MODDIR/run/dohd.pid" ]
}
scenario_config_is_saved() {
	[ -f "$MODDIR/config/config.toml" ]
	[ -f "$MODDIR/config/daemon-enabled" ]
}
scenario_daemon_not_running
scenario_config_is_saved
