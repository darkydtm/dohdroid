#!/system/bin/sh
set -eu
MODDIR=${0%/*}
PIDFILE="$MODDIR/run/dohd.pid"
SOCKET="$MODDIR/run/dohd.sock"
FIREWALL="$MODDIR/scripts/firewall.sh"
TUN_FIREWALL="$MODDIR/scripts/tun-firewall.sh"
KILLSWITCH="$MODDIR/scripts/killswitch.sh"
WAIT_SOCKET_TIMEOUT=10 # Maximum seconds to wait for daemon socket readiness.
CLEANUP_LOOP_MAX=5 # One-second process-stop checks before reporting failure.
export CLEANUP_LOOP_MAX
. "$MODDIR/scripts/private-dns.sh"
. "$MODDIR/scripts/process.sh"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/description.sh"

initialize() {
	mkdir -p "$MODDIR/run" "$MODDIR/config"
	exec 9>"$MODDIR/run/service.lock"
	flock -x 9
	[ -f "$MODDIR/config/config.toml" ] || cp "$MODDIR/config/config.toml.example" "$MODDIR/config/config.toml"
	if daemon_enabled && resolver_enabled; then
		update_description LOADING
		trap 'update_description ERROR' EXIT
	else
		update_description OFF
	fi
}

resolver_enabled() {
	awk '/^[[:space:]]*enabled[[:space:]]*=/ { value = $0; sub(/^[^=]*=[[:space:]]*/, "", value); if (value == "true") found = 1 } END { exit found ? 0 : 1 }' "$MODDIR/config/config.toml"
}

select_abi() {
	case "$(uname -m)" in
		aarch64) ABI=arm64-v8a ;;
		armv7l|armv8l|arm) ABI=armeabi-v7a ;;
		x86_64) ABI=x86_64 ;;
		i686|i386) ABI=x86 ;;
		*) echo "Unsupported ABI: $(uname -m)" >&2; return 1 ;;
	esac
	BINARY="$MODDIR/system/bin/$ABI/dohd"
	[ -x "$BINARY" ] || { echo "Missing daemon for ABI: $ABI" >&2; return 1; }
}

stop_daemon() {
	for pid in $(daemon_pids); do
		stop_managed_process "$pid" || { echo "Daemon did not stop: $pid" >&2; return 1; }
	done
	"$TUN_FIREWALL" remove || return 1
	if [ -f "$MODDIR/run/tun.pid" ]; then
		tun_pid=$(cat "$MODDIR/run/tun.pid")
		stop_managed_process "$tun_pid" || { echo "TUN process did not stop: $tun_pid" >&2; return 1; }
		rm -f "$MODDIR/run/tun.pid"
	fi
	rm -f "$SOCKET" "$PIDFILE"
}

# Continue cleanup when removing absent firewall rules or rolling back failure.
cleanup_optional() { "$1" remove || :; }

stop_managed_process() { stop_process "$1"; }

wait_for_socket() {
	pid=$1
	elapsed=0
	while [ "$elapsed" -lt "$WAIT_SOCKET_TIMEOUT" ]; do
		[ -S "$SOCKET" ] && return 0
		kill -0 "$pid" 2>/dev/null || return 1
		sleep 1
		elapsed=$((elapsed + 1))
	done
	[ -S "$SOCKET" ]
}

start_tun_mode() {
	port=$(awk -F= '/^[[:space:]]*listen_port[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$MODDIR/config/config.toml")
	case "$port" in ''|*[!0-9]*) port=5353 ;; esac
	sed "s/\"server_port\": 5353/\"server_port\": $port/" "$MODDIR/config/tun.json" > "$MODDIR/run/tun.json"
	"$MODDIR/system/bin/$ABI/sing-box" run -c "$MODDIR/run/tun.json" 9>&- >>"$MODDIR/run/tun.log" 2>&1 &
	tun_pid=$!
	echo "$tun_pid" > "$MODDIR/run/tun.pid"
	elapsed=0
	while [ "$elapsed" -lt "$WAIT_SOCKET_TIMEOUT" ]; do
		/system/bin/ip link show dohdtun0 >/dev/null 2>&1 && break
		kill -0 "$tun_pid" 2>/dev/null || break
		sleep 1
		elapsed=$((elapsed + 1))
	done
	if ! kill -0 "$tun_pid" 2>/dev/null || ! /system/bin/ip link show dohdtun0 >/dev/null 2>&1 || ! "$TUN_FIREWALL" install; then
		cleanup_optional "$TUN_FIREWALL"
		stop_managed_process "$tun_pid" || :
		rm -f "$MODDIR/run/tun.pid"
		stop_managed_process "$pid" || :
		private_dns_restore || :
		return 1
	fi
	if killswitch_enabled; then "$KILLSWITCH" install || return 1; fi
}

start_standard_mode() {
	if ! "$FIREWALL" install; then
		private_dns_restore || :
		stop_managed_process "$pid" || :
		if killswitch_enabled; then "$KILLSWITCH" install || :; fi
		return 1
	fi
	if killswitch_enabled; then "$KILLSWITCH" install || return 1; fi
}

enable_daemon() {
	daemon_enable || return 1
	if ! sh "$MODDIR/service.sh"; then daemon_disable || :; return 1; fi
}

disable_daemon() {
	daemon_disable || return 1
	sh "$MODDIR/service.sh" || return 1
}

main() {
	initialize
	if [ "${1:-}" = boot ] && daemon_running; then return 0; fi
	select_abi || return 1
	if tun_enabled; then FIREWALL="$TUN_FIREWALL"; fi
	cleanup_optional "$FIREWALL"
	cleanup_optional "$KILLSWITCH"
	stop_daemon || return 1
	if ! resolver_enabled || ! daemon_enabled; then
		cleanup_optional "$FIREWALL"
		cleanup_optional "$TUN_FIREWALL"
		cleanup_optional "$KILLSWITCH"
		private_dns_restore || :
		return 0
	fi
	private_dns_restore || return 1
	if ! "$MODDIR/scripts/bootstrap.sh" "$MODDIR/config/config.toml"; then
		if killswitch_enabled; then "$KILLSWITCH" install || :; fi
		echo "DoH resolver bootstrap lookup failed" >&2
		return 1
	fi
	DOHD_CONFIG="$MODDIR/config/config.toml" DOHD_SOCKET="$SOCKET" DOHD_WEB_ROOT="$MODDIR/webroot" "$BINARY" 9>&- >"$MODDIR/run/dohd.log" 2>&1 &
	pid=$!
	echo "$pid" > "$PIDFILE"
	if ! wait_for_socket "$pid"; then
		stop_managed_process "$pid" || :
		rm -f "$PIDFILE"
		if killswitch_enabled; then "$KILLSWITCH" install || :; fi
		echo "Daemon failed to start; check $MODDIR/run/dohd.log" >&2
		return 1
	fi
	if ! private_dns_disable; then
		cleanup_optional "$FIREWALL"
		private_dns_restore || :
		stop_managed_process "$pid" || :
		if killswitch_enabled; then "$KILLSWITCH" install || :; fi
		return 1
	fi
	if tun_enabled; then start_tun_mode || return 1; else start_standard_mode || return 1; fi
	update_description ON
	trap - EXIT
}

main "$@"
