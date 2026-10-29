#!/system/bin/sh
set -eu
MODDIR=${0%/*}
PIDFILE="$MODDIR/run/dohd.pid"
SOCKET="$MODDIR/run/dohd.sock"
if [ -f "$PIDFILE" ]; then
	kill "$(cat "$PIDFILE")" 2>/dev/null || true
	rm -f "$PIDFILE"
fi
"$MODDIR/scripts/firewall.sh" remove 2>/dev/null || true
. "$MODDIR/scripts/private-dns.sh"
private_dns_restore || true
rm -f "$SOCKET"
