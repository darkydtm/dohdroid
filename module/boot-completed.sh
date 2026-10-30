#!/system/bin/sh
set -eu
MODDIR=${0%/*}
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/process.sh"
. "$MODDIR/scripts/description.sh"
if daemon_enabled && ! daemon_running; then
	update_description ERROR
	sh "$MODDIR/service.sh" boot
fi
