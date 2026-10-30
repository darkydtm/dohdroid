#!/system/bin/sh
set -eu
MODDIR=${0%/*/*}
. "$MODDIR/scripts/state.sh"
TABLE=19053
PRIORITY=10530
MARK=0x1000000/0x1000000
CHAIN=DOHD_TUN
IP=${DOHD_IP:-/system/bin/ip}
IPTABLES=${DOHD_IPTABLES:-/system/bin/iptables}
IP6TABLES=${DOHD_IP6TABLES:-/system/bin/ip6tables}

remove_family() {
	family=$1
	firewall=$2
	"$firewall" -t mangle -D OUTPUT -j "$CHAIN" 2>/dev/null || true
	"$firewall" -t mangle -F "$CHAIN" 2>/dev/null || true
	"$firewall" -t mangle -X "$CHAIN" 2>/dev/null || true
	"$IP" "$family" rule del priority "$PRIORITY" fwmark "$MARK" lookup "$TABLE" 2>/dev/null || true
	"$IP" "$family" route del default dev dohdtun0 table "$TABLE" 2>/dev/null || true
}

install_family() {
	family=$1
	firewall=$2
	"$IP" "$family" route add default dev dohdtun0 table "$TABLE" || return 1
	"$IP" "$family" rule add priority "$PRIORITY" fwmark "$MARK" lookup "$TABLE" || return 1
	"$firewall" -t mangle -N "$CHAIN" || return 1

	if [ "$family" = -4 ]; then
		"$firewall" -t mangle -A "$CHAIN" -d 127.0.0.0/8 -j RETURN || return 1
	else
		"$firewall" -t mangle -A "$CHAIN" -d ::1/128 -j RETURN || return 1
	fi
	"$firewall" -t mangle -A "$CHAIN" -p udp --dport 53 -j MARK --set-xmark "$MARK" || return 1
	"$firewall" -t mangle -A "$CHAIN" -p tcp --dport 53 -j MARK --set-xmark "$MARK" || return 1
	"$firewall" -t mangle -I OUTPUT 1 -j "$CHAIN" || return 1
}

case "${1:-status}" in
	install)
		tun_enabled || exit 1
		remove_family -4 "$IPTABLES"
		remove_family -6 "$IP6TABLES"
		if ! (install_family -4 "$IPTABLES" && install_family -6 "$IP6TABLES"); then
			remove_family -4 "$IPTABLES"
			remove_family -6 "$IP6TABLES"
			exit 1
		fi
		;;
	remove)
		remove_family -4 "$IPTABLES"
		remove_family -6 "$IP6TABLES"
		;;
	status)
		tun_enabled || exit 1
		"$IPTABLES" -t mangle -C OUTPUT -j "$CHAIN" >/dev/null 2>&1 &&
		"$IP6TABLES" -t mangle -C OUTPUT -j "$CHAIN" >/dev/null 2>&1
		;;
	*) exit 2 ;;
esac
