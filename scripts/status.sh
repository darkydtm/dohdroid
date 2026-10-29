#!/system/bin/sh
MODDIR=${0%/*}
PIDFILE="$MODDIR/run/dohd.pid"
[ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
