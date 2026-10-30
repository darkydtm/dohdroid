#!/system/bin/sh
set -eu
MODDIR=${0%/*/*}
CHAIN=DOHD_KILL
IPTABLES=${DOHD_IPTABLES:-/system/bin/iptables}
IP6TABLES=${DOHD_IP6TABLES:-/system/bin/ip6tables}
install_family() {
	backend=$1
	"$backend" -t filter -N "$CHAIN" 2>/dev/null || true
	"$backend" -t filter -C OUTPUT -j "$CHAIN" 2>/dev/null && return 0
	"$backend" -t filter -F "$CHAIN"
	"$backend" -t filter -A "$CHAIN" -m mark --mark 0x1000000/0x1000000 -j RETURN
	"$backend" -t filter -A "$CHAIN" -p udp --dport 53 -j REJECT
	"$backend" -t filter -A "$CHAIN" -p tcp --dport 53 -j REJECT
	"$backend" -t filter -A "$CHAIN" -p udp --dport 853 -j REJECT
	"$backend" -t filter -A "$CHAIN" -p tcp --dport 853 -j REJECT
	"$backend" -t filter -I OUTPUT 1 -j "$CHAIN"
}
remove_family() {
	backend=$1
	"$backend" -t filter -C OUTPUT -j "$CHAIN" 2>/dev/null && "$backend" -t filter -D OUTPUT -j "$CHAIN" || true
	"$backend" -t filter -F "$CHAIN" 2>/dev/null || true
	"$backend" -t filter -X "$CHAIN" 2>/dev/null || true
}
case "${1:-status}" in
	install)
		install_family "$IPTABLES"
		install_family "$IP6TABLES"
		;;
	remove)
		remove_family "$IPTABLES"
		remove_family "$IP6TABLES"
		;;
	status)
		"$IPTABLES" -t filter -C OUTPUT -j "$CHAIN" >/dev/null 2>&1 &&
		"$IP6TABLES" -t filter -C OUTPUT -j "$CHAIN" >/dev/null 2>&1
		;;
	*) exit 2 ;;
esac
