#!/system/bin/sh
set -eu
SCRIPT_DIR=${0%/*}
MODDIR=${SCRIPT_DIR%/*}
. "$SCRIPT_DIR/state.sh"
. "$SCRIPT_DIR/process.sh"
CONFIG="$MODDIR/config/config.toml"

ensure_user_config() {
	# Create the config only for config/control commands, never status requests.
	if [ ! -f "$CONFIG" ]; then mkdir -p "$MODDIR/config"; cp "$MODDIR/config/config.toml.example" "$CONFIG"; fi
}

respond_boolean() {
	if "$1"; then printf '%s\n' '{"ok":true,"result":true}'; else printf '%s\n' '{"ok":true,"result":false}'; fi
}

set_flag_from_command() {
	case "$1" in *-enable) "$2" enable ;; *-disable) "$2" disable ;; *) return 2 ;; esac
}

case "${1:-}" in
	daemon-status)
		if daemon_enabled; then enabled=true; else enabled=false; fi
		if daemon_running; then running=true; else running=false; fi
		printf '{"ok":true,"result":{"enabled":%s,"running":%s}}\n' "$enabled" "$running"
		exit 0
		;;
	killswitch-status) respond_boolean killswitch_enabled; exit 0 ;;
	killswitch-enable|killswitch-disable)
		case "$1" in *-enable) killswitch_enable ;; *) killswitch_disable ;; esac
		respond_boolean true
		exit 0
		;;
	tun-status) respond_boolean tun_enabled; exit 0 ;;
	tun-enable|tun-disable)
		case "$1" in *-enable) tun_enable ;; *) tun_disable ;; esac
		respond_boolean true
		exit 0
		;;
esac

ensure_user_config
case "$(uname -m)" in
	aarch64) ABI=arm64-v8a ;;
	armv7l|armv8l|arm) ABI=armeabi-v7a ;;
	x86_64) ABI=x86_64 ;;
	i686|i386) ABI=x86 ;;
	*) exit 1 ;;
esac
if daemon_running; then
	printf '%s\n' "$1" | "$MODDIR/system/bin/$ABI/dohd" control "$MODDIR/run/dohd.sock"
else
	printf '%s\n' "$1" | "$MODDIR/system/bin/$ABI/dohd" config "$CONFIG"
fi
