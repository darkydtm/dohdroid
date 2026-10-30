#!/system/bin/sh
set -eu
MODDIR=${0%/*}
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/process.sh"
. "$MODDIR/scripts/description.sh"
if daemon_enabled && ! daemon_running; then update_description ERROR; fi
sleep "${DOHD_BOOT_RECOVERY_DELAY:-180}"
if daemon_enabled && ! daemon_running; then
	sh "$MODDIR/service.sh"
fi
