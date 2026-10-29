#!/system/bin/sh
set -eu
MODDIR=${0%/*}
SOCKET="$MODDIR/run/dohd.sock"
command -v nc >/dev/null 2>&1 || { echo "nc is required" >&2; exit 1; }
printf '%s\n' '{"api_version":1,"operation":"status"}' | nc -U "$SOCKET"
