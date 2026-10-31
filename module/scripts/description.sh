# shellcheck shell=sh
# Source after setting MODDIR to the module root.
update_module_description() {
	status=$1
	url=$(awk -F'"' '/^[[:space:]]*url[[:space:]]*=/ { print $2; exit }' "$MODDIR/config/config.toml" 2>/dev/null || :)
	[ -n "$url" ] || url="not configured"
	tmp="$MODDIR/module.prop.tmp"
	awk -v description="DoH: $status | DNS: $url" '
		BEGIN { replaced = 0 }
		/^description=/ { print "description=" description; replaced = 1; next }
		{ print }
		END { if (!replaced) print "description=" description }
	' "$MODDIR/module.prop" > "$tmp"
	chmod 0644 "$tmp"
	mv "$tmp" "$MODDIR/module.prop"
}
update_description() { update_module_description "$@"; }
