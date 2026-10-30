#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MODDIR="$TMP/module"
export MODDIR
mkdir -p "$MODDIR/config"
. "$ROOT/module/scripts/state.sh"
[ "$(daemon_state)" = disabled ]
[ "$(tun_state)" = disabled ]
[ "$(killswitch_state)" = disabled ]
[ "$(daemon_enabled && printf enabled || printf disabled)" = disabled ]
[ "$(tun_enabled && printf enabled || printf disabled)" = disabled ]
daemon_enable
tun_enable
killswitch_enable
[ -f "$MODDIR/config/daemon-enabled" ]
[ -f "$MODDIR/config/tun-enabled" ]
[ -f "$MODDIR/config/killswitch-enabled" ]
[ "$(daemon_state)" = enabled ]
[ "$(tun_state)" = enabled ]
[ "$(killswitch_state)" = enabled ]
[ "$(daemon_enabled && printf enabled || printf disabled)" = enabled ]
[ "$(tun_enabled && printf enabled || printf disabled)" = enabled ]
daemon_disable
tun_disable
killswitch_disable
[ "$(daemon_state)" = disabled ]
[ "$(tun_state)" = disabled ]
[ "$(killswitch_state)" = disabled ]