#!/system/bin/sh
set -eu
SCRIPT_DIR=${0%/*}
. "$SCRIPT_DIR/iptables-backend.sh"
CHAIN=DOHD_DNS
PORT=${DOHD_PORT:-5353}
backend=$(select_iptables_backend) || exit 1

install_rules() {
	if ! "$backend" -t nat -N "$CHAIN" 2>/dev/null; then
		"$backend" -t nat -L "$CHAIN" >/dev/null 2>&1 || return 1
	fi
	"$backend" -t nat -F "$CHAIN"
	"$backend" -t nat -A "$CHAIN" -p udp --dport 53 -j REDIRECT --to-ports "$PORT"
	"$backend" -t nat -A "$CHAIN" -p tcp --dport 53 -j REDIRECT --to-ports "$PORT"
	if ! "$backend" -t nat -C OUTPUT -j "$CHAIN" 2>/dev/null; then "$backend" -t nat -A OUTPUT -j "$CHAIN"; fi
}

remove_rules() {
	if "$backend" -t nat -C OUTPUT -j "$CHAIN" 2>/dev/null; then "$backend" -t nat -D OUTPUT -j "$CHAIN"; fi
	if "$backend" -t nat -L "$CHAIN" >/dev/null 2>&1; then
		"$backend" -t nat -F "$CHAIN" || return 1
		"$backend" -t nat -X "$CHAIN"
	fi
}

case "${1:-status}" in
	install) install_rules ;;
	remove) remove_rules ;;
	status) "$backend" -t nat -L "$CHAIN" >/dev/null 2>&1 ;;
	*) exit 2 ;;
esac
