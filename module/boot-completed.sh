#!/system/bin/sh
set -eu
MODDIR=${0%/*}
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/process.sh"
. "$MODDIR/scripts/description.sh"
if daemon_enabled && ! daemon_running; then
	update_description ERROR
	attempt=0
	while daemon_enabled && [ "$attempt" -lt 24 ]; do
		if sh "$MODDIR/service.sh" boot; then exit 0; fi
		attempt=$((attempt + 1))
		[ "$attempt" -lt 24 ] || break
		sleep 5
	done
	exit 1
fi
