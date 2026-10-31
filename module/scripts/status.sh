#!/system/bin/sh
set -eu
SCRIPT_DIR=${0%/*}
MODDIR=${SCRIPT_DIR%/*}
PIDFILE="$MODDIR/run/dohd.pid"
. "$SCRIPT_DIR/process.sh"
[ -f "$PIDFILE" ] && pid=$(cat "$PIDFILE") && kill -0 "$pid" 2>/dev/null && process_matches "$pid"
