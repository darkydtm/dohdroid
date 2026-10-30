#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MODDIR="$TMP/module"
mkdir -p "$MODDIR/config" "$MODDIR/run" "$MODDIR/scripts" "$MODDIR/system/bin/x86_64" "$TMP/bin"
cp "$ROOT/module/service.sh" "$MODDIR/service.sh"
cat > "$MODDIR/scripts/firewall.sh" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$*" >> "$TEST_LOG"
SCRIPT
cat > "$MODDIR/scripts/tun-firewall.sh" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$*" >> "$TEST_LOG"
SCRIPT
cat > "$MODDIR/scripts/killswitch.sh" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$*" >> "$TEST_LOG"
SCRIPT
cat > "$MODDIR/scripts/private-dns.sh" <<'SCRIPT'
#!/bin/sh
private_dns_restore() { return 0; }
private_dns_disable() { return 0; }
SCRIPT
cat > "$MODDIR/scripts/process.sh" <<'SCRIPT'
#!/bin/sh
daemon_pids() { :; }
SCRIPT
cat > "$MODDIR/scripts/state.sh" <<'SCRIPT'
#!/bin/sh
daemon_enabled() { [ -f "$MODDIR/config/daemon-enabled" ]; }
tun_enabled() { [ -f "$MODDIR/config/tun-enabled" ]; }
killswitch_enabled() { [ -f "$MODDIR/config/killswitch-enabled" ]; }
SCRIPT
cat > "$MODDIR/scripts/description.sh" <<'SCRIPT'
update_description() { :; }
SCRIPT
cp "$ROOT/module/scripts/resolver.sh" "$MODDIR/scripts/resolver.sh"
chmod +x "$MODDIR/scripts/"*.sh
cp "$ROOT/module/config/config.toml.example" "$MODDIR/config/config.toml"
touch "$MODDIR/config/daemon-enabled"
cat > "$MODDIR/system/bin/x86_64/dohd" <<'SCRIPT'
#!/usr/bin/env python3
import os
import socket
import time

server = socket.socket(socket.AF_UNIX)
server.bind(os.environ["DOHD_SOCKET"])
server.listen()
print("daemon-started", file=open(os.environ["TEST_LOG"], "a"))
while True:
	time.sleep(1)
SCRIPT
chmod +x "$MODDIR/system/bin/x86_64/dohd"
cat > "$TMP/bin/uname" <<'SCRIPT'
#!/bin/sh
printf '%s\n' x86_64
SCRIPT
chmod +x "$TMP/bin/uname"
export MODDIR TEST_LOG="$TMP/log" PATH="$TMP/bin:$PATH"

sh "$MODDIR/service.sh"

! grep -q daemon-started "$TEST_LOG"
! grep -q install "$TEST_LOG"
[ -f "$MODDIR/config/daemon-enabled" ]
[ ! -f "$MODDIR/run/dohd.pid" ]
