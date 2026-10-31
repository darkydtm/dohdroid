#!/system/bin/sh
# shellcheck shell=sh
# Source after setting MODDIR; DOHD_IPTABLES may override backend discovery.
select_iptables_backend() {
	backend=${DOHD_IPTABLES:-}
	if [ -n "$backend" ]; then
		[ -x "$backend" ] || return 1
		printf '%s\n' "$backend"
		return 0
	fi
	for candidate in /system/bin/iptables /system/bin/iptables-legacy; do
		if [ -x "$candidate" ]; then printf '%s\n' "$candidate"; return 0; fi
	done
	return 1
}
