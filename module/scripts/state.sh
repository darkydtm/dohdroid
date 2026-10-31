#!/system/bin/sh
# shellcheck shell=sh
set -eu
state_path() {
	printf '%s/config/%s-enabled\n' "$MODDIR" "$1"
}

flag_enabled() {
	[ -f "$(state_path "$1")" ]
}

flag_state() {
	if flag_enabled "$1"; then printf '%s\n' enabled; else printf '%s\n' disabled; fi
}

flag_enable() {
	touch "$(state_path "$1")"
}

flag_disable() {
	rm -f "$(state_path "$1")"
}

daemon_enabled() { flag_enabled daemon; }
daemon_state() { flag_state daemon; }
daemon_enable() { flag_enable daemon; }
daemon_disable() { flag_disable daemon; }
tun_enabled() { flag_enabled tun; }
tun_state() { flag_state tun; }
tun_enable() { flag_enable tun; }
tun_disable() { flag_disable tun; }
killswitch_enabled() { flag_enabled killswitch; }
killswitch_state() { flag_state killswitch; }
killswitch_enable() { flag_enable killswitch; }
killswitch_disable() { flag_disable killswitch; }
