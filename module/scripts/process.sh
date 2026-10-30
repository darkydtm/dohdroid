daemon_pids() {
	for pid in $(pidof dohd 2>/dev/null || true); do
		process="${PROC_ROOT:-/proc}/$pid"
		[ -r "$process/cmdline" ] && [ -r "$process/environ" ] || continue
		command=$(tr '\000' '\n' < "$process/cmdline" | { IFS= read -r line; printf '%s' "$line"; })
		case "$command" in
			"$MODDIR"/system/bin/*/dohd) ;;
			*) continue ;;
		esac
		tr '\000' '\n' < "$process/environ" | grep -Fx "DOHD_CONFIG=$MODDIR/config/config.toml" >/dev/null || continue
		printf '%s\n' "${process##*/}"
	done
}

daemon_running() {
	[ -n "$(daemon_pids)" ] && [ -S "$MODDIR/run/dohd.sock" ]
}
