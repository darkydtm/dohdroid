# shellcheck shell=sh
# Source after setting MODDIR; state stores the original Android setting verbatim.
private_dns_state_path() { printf '%s/run/private-dns-mode\n' "$MODDIR"; }

private_dns_read_mode() {
	settings get global private_dns_mode
}

private_dns_valid_mode() {
	case "$1" in null|off|opportunistic|hostname) return 0 ;; *) return 1 ;; esac
}

private_dns_save_original() {
	state=$(private_dns_state_path)
	[ -f "$state" ] && return 0
	mode=$(private_dns_read_mode) || return 1
	private_dns_valid_mode "$mode" || return 1
	umask 077
	printf '%s\n' "$mode" > "$state.tmp" || return 1
	mv "$state.tmp" "$state"
}

private_dns_set_off() {
	settings put global private_dns_mode off || return 1
	[ "$(private_dns_read_mode)" = off ]
}

private_dns_restore_mode() {
	mode=$1
	case "$mode" in
		null) settings delete global private_dns_mode || return 1 ;;
		off|opportunistic|hostname) settings put global private_dns_mode "$mode" || return 1 ;;
		*) return 1 ;;
	esac
	[ "$(private_dns_read_mode)" = "$mode" ]
}

private_dns_disable() {
	private_dns_save_original || return 1
	private_dns_set_off
}

private_dns_restore() {
	state=$(private_dns_state_path)
	[ -f "$state" ] || return 0
	current=$(private_dns_read_mode) || return 1
	if [ "$current" != off ]; then rm -f "$state"; return 0; fi
	mode=$(cat "$state") || return 1
	private_dns_restore_mode "$mode" || return 1
	rm -f "$state"
}