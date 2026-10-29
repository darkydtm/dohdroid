#!/system/bin/sh
set -eu
MODDIR=${0%/*}
PIDFILE="$MODDIR/run/dohd.pid"
mkdir -p "$MODDIR/run" "$MODDIR/config"
[ -f "$MODDIR/config/config.toml" ] || cp "$MODDIR/config/config.toml.example" "$MODDIR/config/config.toml"
case "$(uname -m)" in
	aarch64) ABI=arm64-v8a ;;
	armv7l|armv8l|arm) ABI=armeabi-v7a ;;
	x86_64) ABI=x86_64 ;;
	i686|i386) ABI=x86 ;;
	*) echo "Unsupported ABI: $(uname -m)" >&2; exit 1 ;;
esac
BINARY="$MODDIR/system/bin/$ABI/dohd"
[ -x "$BINARY" ] || { echo "Missing daemon for ABI: $ABI" >&2; exit 1; }
(
while [ ! -f "$MODDIR/disable" ] && [ ! -f "$MODDIR/remove" ]; do
	rm -f "$MODDIR/run/dohd.sock"
	DOHD_CONFIG="$MODDIR/config/config.toml" DOHD_SOCKET="$MODDIR/run/dohd.sock" "$BINARY" >>"$MODDIR/run/dohd.log" 2>&1 &
	pid=$!
	echo "$pid" > "$PIDFILE"
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		[ -S "$MODDIR/run/dohd.sock" ] && break
		kill -0 "$pid" 2>/dev/null || break
		sleep 1
	done
	if [ -S "$MODDIR/run/dohd.sock" ]; then
		"$MODDIR/scripts/firewall.sh" install || true
	fi
	wait "$pid" || true
	"$MODDIR/scripts/firewall.sh" remove || true
	rm -f "$PIDFILE" "$MODDIR/run/dohd.sock"
	sleep 5
done
) </dev/null >/dev/null 2>&1 &
