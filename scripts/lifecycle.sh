#!/system/bin/sh
set -eu
MODDIR=${0%/*}
exec "$MODDIR/scripts/firewall.sh" "${1:-status}"
