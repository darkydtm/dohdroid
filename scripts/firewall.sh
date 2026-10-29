#!/system/bin/sh
set -eu
MODDIR=${0%/*}
CHAIN=DOHD_DNS
backend=""
for candidate in /system/bin/iptables /system/bin/iptables-legacy /system/bin/nft; do
	if [ -x "$candidate" ]; then backend="$candidate"; break; fi
done
[ -n "$backend" ] || exit 1
case "${1:-status}" in
	status) printf '%s\n' "$backend" ;;
	install|remove) exit 0 ;;
	*) exit 2 ;;
esac
