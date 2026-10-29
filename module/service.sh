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
		if [ -f "$MODDIR/config/tun-enabled" ]; then
			port=$(awk -F= '/^[[:space:]]*listen_port[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$MODDIR/config/config.toml")
			case "$port" in ''|*[!0-9]*) port=5353 ;; esac
			sed "s/\"server_port\": 5353/\"server_port\": $port/" "$MODDIR/config/tun.json" > "$MODDIR/run/tun.json"
			"$MODDIR/system/bin/$ABI/sing-box" run -c "$MODDIR/run/tun.json" >>"$MODDIR/run/tun.log" 2>&1 &
			tun_pid=$!
			echo "$tun_pid" > "$MODDIR/run/tun.pid"
			for _ in 1 2 3 4 5 6 7 8 9 10; do
				/system/bin/ip link show dohdtun0 >/dev/null 2>&1 && break
				kill -0 "$tun_pid" 2>/dev/null || break
				sleep 1
			done
			if ! kill -0 "$tun_pid" 2>/dev/null || ! /system/bin/ip link show dohdtun0 >/dev/null 2>&1 || ! "$MODDIR/scripts/tun-firewall.sh" install; then
				kill "$tun_pid" 2>/dev/null || true
				kill "$pid" 2>/dev/null || true
			fi
		else
			"$MODDIR/scripts/firewall.sh" install || true
		fi
	fi
	while kill -0 "$pid" 2>/dev/null; do
		if [ -n "${tun_pid:-}" ] && ! kill -0 "$tun_pid" 2>/dev/null; then
			kill "$pid" 2>/dev/null || true
			break
		fi
		sleep 2
	done
	wait "$pid" 2>/dev/null || true
	"$MODDIR/scripts/tun-firewall.sh" remove || true
	if [ -n "${tun_pid:-}" ]; then
		kill "$tun_pid" 2>/dev/null || true
		wait "$tun_pid" 2>/dev/null || true
		unset tun_pid
	fi
	"$MODDIR/scripts/firewall.sh" remove || true
	rm -f "$PIDFILE" "$MODDIR/run/dohd.sock" "$MODDIR/run/tun.pid"
	sleep 5
done
) </dev/null >/dev/null 2>&1 &
