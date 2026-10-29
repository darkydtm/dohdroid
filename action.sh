#!/system/bin/sh
MODDIR=${0%/*}
SOCKET="$MODDIR/run/dohd.sock"
printf '%s\n' '{"api_version":1,"operation":"status"}' | "$MODDIR/system/bin/dohd" control "$SOCKET"
