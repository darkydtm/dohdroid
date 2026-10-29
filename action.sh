#!/system/bin/sh
set -eu
MODDIR=${0%/*}
SOCKET="$MODDIR/run/dohd.sock"
"$MODDIR/system/bin/dohd" control "$SOCKET"
