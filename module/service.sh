#!/system/bin/sh
set -eu
MODDIR=${0%/*}
PIDFILE="$MODDIR/run/dohd.pid"
SOCKET="$MODDIR/run/dohd.sock"
FIREWALL="$MODDIR/scripts/firewall.sh"
. "$MODDIR/scripts/private-dns.sh"
. "$MODDIR/scripts/process.sh"
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
"$FIREWALL" remove
for pid in $(daemon_pids); do
	state=
	kill "$pid" || exit 1
	for _ in 1 2 3 4 5; do
		kill -0 "$pid" 2>/dev/null || break
		state=$(awk '/^State:/ {print $2}' "/proc/$pid/status" 2>/dev/null || true)
		[ "$state" = Z ] && break
		sleep 1
	done
	if kill -0 "$pid" 2>/dev/null && [ "${state:-}" != Z ]; then
		echo "Daemon did not stop" >&2
		exit 1
	fi
done
rm -f "$SOCKET" "$PIDFILE"
private_dns_restore || exit 1
DOHD_CONFIG="$MODDIR/config/config.toml" DOHD_SOCKET="$SOCKET" "$BINARY" >"$MODDIR/run/dohd.log" 2>&1 &
pid=$!
echo "$pid" > "$PIDFILE"
for _ in 1 2 3 4 5 6 7 8 9 10; do
	[ -S "$SOCKET" ] && break
	kill -0 "$pid" 2>/dev/null || break
	sleep 1
done
if [ ! -S "$SOCKET" ]; then
	kill "$pid" 2>/dev/null || true
	rm -f "$PIDFILE"
	echo "Daemon failed to start; check $MODDIR/run/dohd.log" >&2
	exit 1
fi
if ! private_dns_disable || ! "$FIREWALL" install; then
	"$FIREWALL" remove || true
	private_dns_restore || true
	kill "$pid" 2>/dev/null || true
	exit 1
fi
