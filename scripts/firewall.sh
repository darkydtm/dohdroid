#!/system/bin/sh
set -eu
MODDIR=${0%/*}
CHAIN=DOHD_DNS
PORT=${DOHD_PORT:-5353}
backend=""
for candidate in /system/bin/iptables /system/bin/iptables-legacy /system/bin/nft; do
	if [ -x "$candidate" ]; then backend="$candidate"; break; fi
done
[ -n "$backend" ] || exit 1
iptables_mode() {
	case "${1:-status}" in
		install)
			"$backend" -t nat -N "$CHAIN" 2>/dev/null || true
			"$backend" -t nat -F "$CHAIN"
			"$backend" -t nat -A "$CHAIN" -m owner --uid-owner "$(id -u)" -j RETURN 2>/dev/null || true
			"$backend" -t nat -A "$CHAIN" -p udp --dport 53 -j REDIRECT --to-ports "$PORT"
			"$backend" -t nat -A "$CHAIN" -p tcp --dport 53 -j REDIRECT --to-ports "$PORT"
			"$backend" -t nat -C OUTPUT -j "$CHAIN" 2>/dev/null || "$backend" -t nat -A OUTPUT -j "$CHAIN"
			;;
		remove)
			"$backend" -t nat -C OUTPUT -j "$CHAIN" 2>/dev/null && "$backend" -t nat -D OUTPUT -j "$CHAIN" || true
			"$backend" -t nat -F "$CHAIN" 2>/dev/null || true
			"$backend" -t nat -X "$CHAIN" 2>/dev/null || true
			;;
		status)
			"$backend" -t nat -L "$CHAIN" >/dev/null 2>&1
			;;
		*) exit 2 ;;
	esac
}
case "$backend" in
	*/nft) exit 1 ;;
	*) iptables_mode "${1:-status}" ;;
esac
