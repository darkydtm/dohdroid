#!/system/bin/sh
set -eu
MODDIR=${0%/*/*}
CHAIN=DOHD_KILL
backend=${DOHD_IPTABLES:-}
if [ -z "$backend" ]; then
	for candidate in /system/bin/iptables /system/bin/iptables-legacy; do
		if [ -x "$candidate" ]; then backend="$candidate"; break; fi
	done
fi
[ -n "$backend" ] || exit 1
case "${1:-status}" in
	install)
		"$backend" -t filter -N "$CHAIN" 2>/dev/null || true
		"$backend" -t filter -F "$CHAIN"
		"$backend" -t filter -A "$CHAIN" -m owner --uid-owner 0 -j RETURN
		"$backend" -t filter -A "$CHAIN" -p udp --dport 53 -j REJECT
		"$backend" -t filter -A "$CHAIN" -p tcp --dport 53 -j REJECT
		"$backend" -t filter -C OUTPUT -j "$CHAIN" 2>/dev/null || "$backend" -t filter -I OUTPUT 1 -j "$CHAIN"
		;;
	remove)
		"$backend" -t filter -C OUTPUT -j "$CHAIN" 2>/dev/null && "$backend" -t filter -D OUTPUT -j "$CHAIN" || true
		"$backend" -t filter -F "$CHAIN" 2>/dev/null || true
		"$backend" -t filter -X "$CHAIN" 2>/dev/null || true
		;;
	status)
		"$backend" -t filter -C OUTPUT -j "$CHAIN" >/dev/null 2>&1
		;;
	*) exit 2 ;;
esac
