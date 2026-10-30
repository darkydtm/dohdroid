#!/system/bin/sh
set -eu
MODDIR=${0%/*}
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/process.sh"
. "$MODDIR/scripts/description.sh"
. "$MODDIR/scripts/resolver.sh"
if daemon_enabled && resolver_enabled && ! daemon_running; then
	update_description ERROR
	if killswitch_enabled; then "$MODDIR/scripts/killswitch.sh" install || true; fi
fi
sleep "${DOHD_BOOT_RECOVERY_DELAY:-10}"
if daemon_enabled && ! daemon_running; then
	sh "$MODDIR/service.sh"
fi
