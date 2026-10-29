#!/system/bin/sh
set -eu
MODDIR=${0%/*/*}
case "$(uname -m)" in
	aarch64) ABI=arm64-v8a ;;
	armv7l|armv8l|arm) ABI=armeabi-v7a ;;
	x86_64) ABI=x86_64 ;;
	i686|i386) ABI=x86 ;;
	*) exit 1 ;;
esac
printf '%s\n' "$1" | "$MODDIR/system/bin/$ABI/dohd" control "$MODDIR/run/dohd.sock"
