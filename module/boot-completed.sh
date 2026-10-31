#!/system/bin/sh
set -eu
MODDIR=${0%/*}
BOOT_COMPLETED_RETRY_MAX=24 # Maximum service start attempts.
BOOT_COMPLETED_INTERVAL=5 # Seconds between service start attempts.
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/process.sh"
. "$MODDIR/scripts/description.sh"

# Keep retries isolated because startup depends on modules and network timing.
retry_startup() {
	attempt=0
	while daemon_enabled && [ "$attempt" -lt "$BOOT_COMPLETED_RETRY_MAX" ]; do
		if sh "$MODDIR/service.sh" boot; then return 0; fi
		attempt=$((attempt + 1))
		[ "$attempt" -lt "$BOOT_COMPLETED_RETRY_MAX" ] || break
		sleep "$BOOT_COMPLETED_INTERVAL"
	done
	return 1
}

if daemon_enabled && ! daemon_running; then
	update_description ERROR
	retry_startup
fi
