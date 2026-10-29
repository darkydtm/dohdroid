#!/system/bin/sh
set -eu
MODDIR=${0%/*}
PIDFILE="$MODDIR/run/dohd.pid"
mkdir -p "$MODDIR/run" "$MODDIR/config"
if [ -x "$MODDIR/system/bin/dohd" ]; then
	DOHD_CONFIG="$MODDIR/config/config.toml" DOHD_SOCKET="$MODDIR/run/dohd.sock" "$MODDIR/system/bin/dohd" >"$MODDIR/run/dohd.log" 2>&1 &
	echo $! > "$PIDFILE"
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		[ -S "$MODDIR/run/dohd.sock" ] && break
		sleep 1
	done
	[ -S "$MODDIR/run/dohd.sock" ] || exit 1
	"$MODDIR/scripts/firewall.sh" install
fi
