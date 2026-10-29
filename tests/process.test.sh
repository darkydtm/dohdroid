#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MODDIR="$TMP/module"
PROC_ROOT="$TMP/proc"
export MODDIR PROC_ROOT
mkdir -p "$MODDIR/run" "$PROC_ROOT/123" "$PROC_ROOT/456"
printf '%s\0' "$MODDIR/system/bin/arm64-v8a/dohd" > "$PROC_ROOT/123/cmdline"
printf '%s\0' "DOHD_CONFIG=$MODDIR/config/config.toml" > "$PROC_ROOT/123/environ"
printf '%s\0' "$MODDIR/system/bin/arm64-v8a/dohd" > "$PROC_ROOT/456/cmdline"
printf '%s\0' 'DOHD_CONFIG=/elsewhere/config' > "$PROC_ROOT/456/environ"
pidof() { printf '123 456\n'; }
. "$ROOT/module/scripts/process.sh"
[ "$(daemon_pids)" = 123 ]
