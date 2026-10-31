#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MODDIR="$TMP/module"
PROC_ROOT="$TMP/proc"
MATCHING_PID=123
UNRELATED_PID=456
export MODDIR PROC_ROOT
mkdir -p "$MODDIR/run" "$PROC_ROOT/$MATCHING_PID" "$PROC_ROOT/$UNRELATED_PID"
printf '%s\0' "$MODDIR/system/bin/arm64-v8a/dohd" > "$PROC_ROOT/$MATCHING_PID/cmdline"
printf '%s\0' "DOHD_CONFIG=$MODDIR/config/config.toml" > "$PROC_ROOT/$MATCHING_PID/environ"
printf '%s\0' "$MODDIR/system/bin/arm64-v8a/dohd" > "$PROC_ROOT/$UNRELATED_PID/cmdline"
printf '%s\0' 'DOHD_CONFIG=/elsewhere/config' > "$PROC_ROOT/$UNRELATED_PID/environ"
create_pidof_stub() { pidof() { printf '%s %s\n' "$MATCHING_PID" "$UNRELATED_PID"; }; }
create_pidof_stub
. "$ROOT/module/scripts/process.sh"
[ "$(daemon_pids)" = "$MATCHING_PID" ]
