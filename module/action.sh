#!/system/bin/sh
set -eu
MODDIR=${0%/*}
MODULE_PROP="$MODDIR/module.prop"
CONFIG="$MODDIR/config/config.toml"
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/description.sh"

if daemon_enabled; then
	daemon_disable
	sh "$MODDIR/service.sh"
	. "$MODDIR/scripts/private-dns.sh"
	update_description "OFF"
	echo "DoH DNS disabled"
else
	daemon_enable
	if ! sh "$MODDIR/service.sh"; then
		daemon_disable
		update_description "ERROR"
		echo "DoH DNS daemon failed to start" >&2
		exit 1
	fi
	echo "DoH DNS enabled"
fi
