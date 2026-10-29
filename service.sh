#!/system/bin/sh
MODDIR=${0%/*}
PIDFILE="$MODDIR/run/dohd.pid"
mkdir -p "$MODDIR/run" "$MODDIR/config"
if [ -x "$MODDIR/system/bin/dohd" ]; then
	"$MODDIR/system/bin/dohd" >"$MODDIR/run/dohd.log" 2>&1 &
	echo $! > "$PIDFILE"
fi
