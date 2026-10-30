update_description() {
	status="$1"
	url=$(awk -F'"' '/^[[:space:]]*url[[:space:]]*=/ { print $2; exit }' "$MODDIR/config/config.toml" 2>/dev/null || true)
	[ -n "$url" ] || url="not configured"
	new_description="DoH: $status | DNS: $url"
	tmp="$MODDIR/module.prop.tmp"
	awk -v description="$new_description" '
		BEGIN { replaced = 0 }
		/^description=/ { print "description=" description; replaced = 1; next }
		{ print }
		END { if (!replaced) print "description=" description }
	' "$MODDIR/module.prop" > "$tmp"
	chmod 0644 "$tmp"
	mv "$tmp" "$MODDIR/module.prop"
}
