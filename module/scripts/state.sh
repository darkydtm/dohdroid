#!/system/bin/sh

daemon_enabled() {
	[ -f "$MODDIR/config/daemon-enabled" ]
}

daemon_state() {
	if daemon_enabled; then
		printf '%s\n' enabled
	else
		printf '%s\n' disabled
	fi
}

daemon_enable() {
	touch "$MODDIR/config/daemon-enabled"
}

daemon_disable() {
	rm -f "$MODDIR/config/daemon-enabled"
}

tun_enabled() {
	[ -f "$MODDIR/config/tun-enabled" ]
}

tun_state() {
	if tun_enabled; then
		printf '%s\n' enabled
	else
		printf '%s\n' disabled
	fi
}

tun_enable() {
	touch "$MODDIR/config/tun-enabled"
}

tun_disable() {
	rm -f "$MODDIR/config/tun-enabled"
}

killswitch_enabled() {
	[ -f "$MODDIR/config/killswitch-enabled" ]
}

killswitch_state() {
	if killswitch_enabled; then
		printf '%s\n' enabled
	else
		printf '%s\n' disabled
	fi
}

killswitch_enable() {
	touch "$MODDIR/config/killswitch-enabled"
}

killswitch_disable() {
	rm -f "$MODDIR/config/killswitch-enabled"
}