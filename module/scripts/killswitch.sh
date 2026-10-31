#!/system/bin/sh
set -eu
SCRIPT_DIR=${0%/*}
. "$SCRIPT_DIR/iptables-backend.sh"
CHAIN=DOHD_KILL
backend=$(select_iptables_backend) || exit 1

install_rules() {
	if ! "$backend" -t filter -N "$CHAIN" 2>/dev/null; then
		"$backend" -t filter -L "$CHAIN" >/dev/null 2>&1 || return 1
	fi
	"$backend" -t filter -F "$CHAIN"
	"$backend" -t filter -A "$CHAIN" -m owner --uid-owner 0 -j RETURN
	"$backend" -t filter -A "$CHAIN" -m mark --mark 0x1000000/0x1000000 -j RETURN
	"$backend" -t filter -A "$CHAIN" -p udp --dport 53 -j REJECT
	"$backend" -t filter -A "$CHAIN" -p tcp --dport 53 -j REJECT
	if ! "$backend" -t filter -C OUTPUT -j "$CHAIN" 2>/dev/null; then "$backend" -t filter -I OUTPUT 1 -j "$CHAIN"; fi
}

remove_rules() {
	if "$backend" -t filter -C OUTPUT -j "$CHAIN" 2>/dev/null; then "$backend" -t filter -D OUTPUT -j "$CHAIN"; fi
	if "$backend" -t filter -L "$CHAIN" >/dev/null 2>&1; then
		"$backend" -t filter -F "$CHAIN" || return 1
		"$backend" -t filter -X "$CHAIN"
	fi
}

case "${1:-status}" in
	install) install_rules ;;
	remove) remove_rules ;;
	status) "$backend" -t filter -C OUTPUT -j "$CHAIN" >/dev/null 2>&1 ;;
	*) exit 2 ;;
esac
