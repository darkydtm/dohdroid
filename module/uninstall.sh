#!/system/bin/sh
set -eu
MODDIR=${0%/*}
SOCKET="$MODDIR/run/dohd.sock"
. "$MODDIR/scripts/process.sh"
stop_managed_process() { stop_process "$1"; }
. "$MODDIR/scripts/private-dns.sh"

remove_daemon() {
	if [ -f "$MODDIR/run/dohd.pid" ]; then
		pid=$(cat "$MODDIR/run/dohd.pid")
		stop_managed_process "$pid" || :
		rm -f "$MODDIR/run/dohd.pid"
	fi
}

remove_tun() {
	"$MODDIR/scripts/tun-firewall.sh" remove 2>/dev/null || :
	if [ -f "$MODDIR/run/tun.pid" ]; then
		pid=$(cat "$MODDIR/run/tun.pid")
		stop_managed_process "$pid" || :
		rm -f "$MODDIR/run/tun.pid"
	fi
}

remove_network_rules() {
	"$MODDIR/scripts/firewall.sh" remove 2>/dev/null || :
	"$MODDIR/scripts/killswitch.sh" remove 2>/dev/null || :
}

remove_state() {
	private_dns_restore || :
	rm -f "$MODDIR/config/daemon-enabled" "$MODDIR/config/tun-enabled" "$MODDIR/config/killswitch-enabled"
	rm -f "$SOCKET"
}

remove_daemon
remove_tun
remove_network_rules
remove_state
