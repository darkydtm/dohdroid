#!/system/bin/sh
set -eu

# Resolve the first enabled resolver that needs bootstrap addresses.
select_resolver() {
	awk '
		function select_resolver() {
			if (!found && url != "" && empty && enabled != "false") { print url; found = 1 }
			url = ""; empty = 0; enabled = "true"
		}
		/^\[/ { select_resolver(); next }
		/^url = / { url = $0; sub(/^url = "/, "", url); sub(/"$/, "", url) }
		/^bootstrap_ips = / { value = $0; gsub(/[[:space:]]/, "", value); empty = value == "bootstrap_ips=[]" }
		/^enabled = / { enabled = $3 }
		END { select_resolver() }
	' "$1"
}

# Return the parsed ping address for a resolver hostname.
resolve_host() {
	ping -c "$BOOTSTRAP_COUNT" -W 1 "$1" 2>/dev/null | sed -n 's/^PING [^(]*(\([^)]*\)).*/\1/p' | head -n 1
}

# Retry name resolution at a bounded interval before failing startup.
wait_for_bootstrap() {
	host=$1
	attempt=1
	while [ "$attempt" -le "$BOOTSTRAP_RETRY_MAX" ]; do
		address=$(resolve_host "$host")
		case "$address" in ''|*[!0-9.]*) sleep "$BOOTSTRAP_DELAY" ;; *) printf '%s\n' "$address"; return 0 ;; esac
		attempt=$((attempt + 1))
	done
	return 1
}

replace_bootstrap_ips() {
	config=$1
	target=$2
	address=$3
	tmp="$config.bootstrap.tmp"
	awk -v target="$target" -v ip="$address" '
		/^url = / { line = $0; sub(/^url = "/, "", line); sub(/"$/, "", line); replace = line == target }
		/^bootstrap_ips = / && replace { print "bootstrap_ips = [\"" ip "\"]"; replace = 0; next }
		{ print }
	' "$config" > "$tmp"
	chmod 0600 "$tmp"
	mv "$tmp" "$config"
}

main() {
	# Override defaults with DOHD_BOOTSTRAP_ATTEMPTS and DOHD_BOOTSTRAP_DELAY.
	BOOTSTRAP_RETRY_MAX=${DOHD_BOOTSTRAP_ATTEMPTS:-60} # Number of hostname lookups.
	BOOTSTRAP_DELAY=${DOHD_BOOTSTRAP_DELAY:-2} # Seconds between failed lookups.
	BOOTSTRAP_COUNT=1 # ICMP packets per hostname lookup.
	case "$BOOTSTRAP_RETRY_MAX" in ''|*[!0-9]*) BOOTSTRAP_RETRY_MAX=60 ;; esac
	case "$BOOTSTRAP_DELAY" in ''|*[!0-9]*) BOOTSTRAP_DELAY=2 ;; esac
	config=$1
	url=$(select_resolver "$config")
	[ -n "$url" ] || return 0
	case "$url" in https://*) ;; *) return 0 ;; esac
	host=${url#https://}; host=${host%%/*}; host=${host%%:*}
	address=$(wait_for_bootstrap "$host") || return 1
	replace_bootstrap_ips "$config" "$url" "$address"
	exec sh "$0" "$config"
}

if [ "${0##*/}" = bootstrap.sh ]; then main "$@"; fi
