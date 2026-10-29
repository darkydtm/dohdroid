#!/system/bin/sh
set -eu
MODDIR=${0%/*}
FIREWALL="$MODDIR/scripts/firewall.sh"
SOCKET="$MODDIR/run/dohd.sock"

if "$FIREWALL" status >/dev/null 2>&1; then
	"$FIREWALL" remove
	echo "DoH DNS disabled"
else
	[ -S "$SOCKET" ] || {
		echo "DoH DNS daemon is not ready" >&2
		exit 1
	}
	"$FIREWALL" install
	echo "DoH DNS enabled"
fi
