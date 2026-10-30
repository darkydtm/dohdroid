#!/system/bin/sh
set -eu
MODDIR=${0%/*/*}
. "$MODDIR/scripts/state.sh"
case "${1:-}" in
	tun-status)
		if tun_enabled; then printf '%s\n' '{"ok":true,"result":true}'; else printf '%s\n' '{"ok":true,"result":false}'; fi
		exit 0
		;;
	tun-enable|tun-disable)
		if [ "$1" = tun-enable ]; then tun_enable; else tun_disable; fi
		if [ -f "$MODDIR/run/dohd.pid" ]; then kill "$(cat "$MODDIR/run/dohd.pid")" 2>/dev/null || true; fi
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
printf '%s\n' "$1" | "$MODDIR/system/bin/$ABI/dohd" control "$MODDIR/run/dohd.sock"
