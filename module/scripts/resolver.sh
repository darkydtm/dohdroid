resolver_enabled() {
	awk '
		/^[[:space:]]*enabled[[:space:]]*=/ {
			value = $0
			sub(/^[^=]*=[[:space:]]*/, "", value)
			if (value == "true") found = 1
		}
		END { exit found ? 0 : 1 }
	' "$MODDIR/config/config.toml"
}
