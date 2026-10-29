#!/system/bin/sh
MODDIR=${0%/*}
PIDFILE="$MODDIR/run/dohd.pid"
if [ -f "$PIDFILE" ]; then
	kill "$(cat "$PIDFILE")" 2>/dev/null || true
	rm -f "$PIDFILE"
fi
