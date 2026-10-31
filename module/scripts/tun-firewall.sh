#!/system/bin/sh
set -eu
SCRIPT_DIR=${0%/*}
TABLE=19053
TUN_FIREWALL_PRIORITY=10530
MARK=0x1000000/0x1000000
CHAIN=DOHD_TUN
IP=${DOHD_IP:-/system/bin/ip}
IPTABLES=${DOHD_IPTABLES:-/system/bin/iptables}
IP6TABLES=${DOHD_IP6TABLES:-/system/bin/ip6tables}
. "$SCRIPT_DIR/state.sh"
tun_enabled() { flag_enabled tun; }

cleanup_family() {
	family=$1
	firewall=$2
	if "$firewall" -t mangle -C OUTPUT -j "$CHAIN" 2>/dev/null; then "$firewall" -t mangle -D OUTPUT -j "$CHAIN"; fi
	if "$firewall" -t mangle -L "$CHAIN" >/dev/null 2>&1; then
		"$firewall" -t mangle -F "$CHAIN"
		"$firewall" -t mangle -X "$CHAIN"
	fi
	if "$IP" "$family" rule show | grep -F "lookup $TABLE" >/dev/null 2>&1; then "$IP" "$family" rule del priority "$TUN_FIREWALL_PRIORITY" fwmark "$MARK" lookup "$TABLE"; fi
	if "$IP" "$family" route show table "$TABLE" | grep -F 'default dev dohdtun0' >/dev/null 2>&1; then "$IP" "$family" route del default dev dohdtun0 table "$TABLE"; fi
}

install_one_family() {
	family=$1
	firewall=$2
	"$IP" "$family" route add default dev dohdtun0 table "$TABLE"
	"$IP" "$family" rule add priority "$TUN_FIREWALL_PRIORITY" fwmark "$MARK" lookup "$TABLE"
	"$firewall" -t mangle -N "$CHAIN"
	if [ "$family" = -4 ]; then "$firewall" -t mangle -A "$CHAIN" -d 127.0.0.0/8 -j RETURN; else "$firewall" -t mangle -A "$CHAIN" -d ::1/128 -j RETURN; fi
	"$firewall" -t mangle -A "$CHAIN" -p udp --dport 53 -j MARK --set-xmark "$MARK"
	"$firewall" -t mangle -A "$CHAIN" -p tcp --dport 53 -j MARK --set-xmark "$MARK"
	"$firewall" -t mangle -I OUTPUT 1 -j "$CHAIN"
}

rollback() {
	# Roll back both families in reverse install order, including partial installs.
	cleanup_family -6 "$IP6TABLES" || :
	cleanup_family -4 "$IPTABLES" || :
}

install_all_families() {
	cleanup_family -4 "$IPTABLES"
	cleanup_family -6 "$IP6TABLES"
	if install_one_family -4 "$IPTABLES" && install_one_family -6 "$IP6TABLES"; then return 0; fi
	rollback
	return 1
}

case "${1:-status}" in
	install)
		tun_enabled || exit 1
		install_all_families
		;;
	remove)
		cleanup_family -6 "$IP6TABLES"
		cleanup_family -4 "$IPTABLES"
		;;
	status)
		tun_enabled || exit 1
		"$IPTABLES" -t mangle -C OUTPUT -j "$CHAIN" >/dev/null 2>&1 && "$IP6TABLES" -t mangle -C OUTPUT -j "$CHAIN" >/dev/null 2>&1
		;;
	*) exit 2 ;;
esac
