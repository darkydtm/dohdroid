#!/system/bin/sh
set -eu
MODDIR=${0%/*/*}
. "$MODDIR/scripts/state.sh"
. "$MODDIR/scripts/process.sh"
CONFIG="$MODDIR/config/config.toml"
EXAMPLE_CONFIG="$MODDIR/config/config.toml.example"

if [ ! -f "$CONFIG" ]; then
	mkdir -p "$MODDIR/config"
	cp "$EXAMPLE_CONFIG" "$CONFIG"
fi

case "${1:-}" in
	daemon-status)
		if daemon_enabled; then enabled=true; else enabled=false; fi
		if daemon_running; then running=true; else running=false; fi
		printf '{"ok":true,"result":{"enabled":%s,"running":%s}}\n' "$enabled" "$running"
		exit 0
		;;
	killswitch-status)
		if killswitch_enabled; then printf '%s\n' '{"ok":true,"result":true}'; else printf '%s\n' '{"ok":true,"result":false}'; fi
		exit 0
		;;
	killswitch-enable|killswitch-disable)
		if [ "$1" = killswitch-enable ]; then killswitch_enable; else killswitch_disable; fi
		printf '%s\n' '{"ok":true,"result":true}'
		exit 0
		;;
	tun-status)
		if tun_enabled; then printf '%s\n' '{"ok":true,"result":true}'; else printf '%s\n' '{"ok":true,"result":false}'; fi
		exit 0
		;;
	tun-enable|tun-disable)
		if [ "$1" = tun-enable ]; then tun_enable; else tun_disable; fi
		printf '%s\n' '{"ok":true,"result":true}'
		exit 0
		;;
esac
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
