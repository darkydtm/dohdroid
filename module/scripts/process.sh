#!/system/bin/sh
set -eu
# Source after setting MODDIR to the module root.
process_matches() {
	pid=$1
	process="${PROC_ROOT:-/proc}/$pid"
	[ -r "$process/cmdline" ] && [ -r "$process/environ" ] || return 1
	# Proc argv and environment entries are NUL-delimited; match executable and config exactly.
	command=$(tr '\000' '\n' < "$process/cmdline" | { IFS= read -r line; printf '%s' "$line"; })
	case "$command" in "$MODDIR"/system/bin/*/dohd) ;; *) return 1 ;; esac
	tr '\000' '\n' < "$process/environ" | grep -Fx "DOHD_CONFIG=$MODDIR/config/config.toml" >/dev/null
}

daemon_pids() {
	for pid in $(pidof dohd 2>/dev/null || :); do
		if process_matches "$pid"; then printf '%s\n' "$pid"; fi
	done
}

daemon_running() {
	[ -n "$(daemon_pids)" ] && [ -S "$MODDIR/run/dohd.sock" ]
}

stop_process() {
	pid=$1
	cleanup_loop_max=${CLEANUP_LOOP_MAX:-5} # Five one-second checks by default.
	[ "$pid" -gt 1 ] 2>/dev/null || return 2
	if ! kill -0 "$pid" 2>/dev/null; then return 0; fi
	kill "$pid" || return 1
	# Allow five one-second checks for process exit, matching service and uninstall.
	attempt=0
	while [ "$attempt" -lt "$cleanup_loop_max" ]; do
		kill -0 "$pid" 2>/dev/null || return 0
		state=$(awk '/^State:/ {print $2}' "${PROC_ROOT:-/proc}/$pid/status" 2>/dev/null || :)
		[ "$state" = Z ] && return 0
		sleep 1
		attempt=$((attempt + 1))
	done
	kill -0 "$pid" 2>/dev/null || return 0
	[ "${state:-}" = Z ]
}
