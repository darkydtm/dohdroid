#!/system/bin/sh
set -eu
MODDIR=${0%/*}
PIDFILE="$MODDIR/run/dohd.pid"
mkdir -p "$MODDIR/run" "$MODDIR/config"
case "$(uname -m)" in
	aarch64) ABI=arm64-v8a ;;
	armv7l|armv8l|arm) ABI=armeabi-v7a ;;
	x86_64) ABI=x86_64 ;;
	i686|i386) ABI=x86 ;;
	*) echo "Unsupported ABI: $(uname -m)" >&2; exit 1 ;;
esac
BINARY="$MODDIR/system/bin/$ABI/dohd"
[ -x "$BINARY" ] || { echo "Missing daemon for ABI: $ABI" >&2; exit 1; }
DOHD_CONFIG="$MODDIR/config/config.toml" DOHD_SOCKET="$MODDIR/run/dohd.sock" "$BINARY" >"$MODDIR/run/dohd.log" 2>&1 &
echo $! > "$PIDFILE"
for _ in 1 2 3 4 5 6 7 8 9 10; do
	[ -S "$MODDIR/run/dohd.sock" ] && break
	sleep 1
done
[ -S "$MODDIR/run/dohd.sock" ] || exit 1
"$MODDIR/scripts/firewall.sh" install
