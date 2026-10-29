private_dns_disable() {
	state="$MODDIR/run/private-dns-mode"
	if [ ! -f "$state" ]; then
		mode=$(settings get global private_dns_mode) || return 1
		case "$mode" in
			off|opportunistic|hostname|null) ;;
			*) return 1 ;;
		esac
		umask 077
		printf '%s\n' "$mode" > "$state.tmp" || return 1
		mv "$state.tmp" "$state" || return 1
	fi
	settings put global private_dns_mode off || return 1
	[ "$(settings get global private_dns_mode)" = off ]
}

private_dns_restore() {
	state="$MODDIR/run/private-dns-mode"
	[ -f "$state" ] || return 0
	current=$(settings get global private_dns_mode) || return 1
	if [ "$current" != off ]; then
		rm -f "$state"
		return 0
	fi
	mode=$(cat "$state") || return 1
	case "$mode" in
		null) settings delete global private_dns_mode || return 1 ;;
		off|opportunistic|hostname) settings put global private_dns_mode "$mode" || return 1 ;;
		*) return 1 ;;
	esac
	[ "$(settings get global private_dns_mode)" = "$mode" ] || return 1
	rm -f "$state"
}
