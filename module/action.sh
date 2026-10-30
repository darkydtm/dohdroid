#!/system/bin/sh
set -eu
MODDIR=${0%/*}
MODULE_PROP="$MODDIR/module.prop"
CONFIG="$MODDIR/config/config.toml"
. "$MODDIR/scripts/state.sh"

read_resolver_url() {
	awk -F'"' '/^[[:space:]]*url[[:space:]]*=/ { print $2; exit }' "$CONFIG" 2>/dev/null || true
}

update_description() {
	status="$1"
	url=$(read_resolver_url)
	[ -n "$url" ] || url="not configured"
	new_description="DoH: $status | DNS: $url"
	tmp="$MODULE_PROP.tmp"
	awk -v description="$new_description" '
		BEGIN { replaced = 0 }
		/^description=/ { print "description=" description; replaced = 1; next }
		{ print }
		END { if (!replaced) print "description=" description }
	' "$MODULE_PROP" > "$tmp"
	chmod 0644 "$tmp"
	mv "$tmp" "$MODULE_PROP"
}

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
	update_description "ON"
	echo "DoH DNS enabled"
fi
