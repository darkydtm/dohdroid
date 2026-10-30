for script in "$MODPATH"/scripts/*.sh; do
	set_perm "$script" 0 0 0755
done
for binary in "$MODPATH"/system/bin/*/dohd; do
	[ -f "$binary" ] || continue
	set_perm "$binary" 0 0 0755
done
for binary in "$MODPATH"/system/bin/*/sing-box; do
	[ -f "$binary" ] || continue
	set_perm "$binary" 0 0 0755
done
mkdir -p "$MODPATH/config"
old_moddir=${DOHD_OLD_MODDIR:-/data/adb/modules/doh-dns}
old_config="$old_moddir/config/config.toml"
if [ -f "$old_config" ] && [ "$MODPATH/config/config.toml" != "$old_config" ]; then
	cp "$old_config" "$MODPATH/config/config.toml"
	set_perm "$MODPATH/config/config.toml" 0 0 0600
fi

if [ ! -d "$old_moddir/config" ]; then
	touch "$MODPATH/config/daemon-enabled"
elif [ -f "$old_moddir/config/daemon-enabled" ]; then
	touch "$MODPATH/config/daemon-enabled"
fi
if [ -f "$old_moddir/config/tun-enabled" ] && [ "$MODPATH" != "$old_moddir" ]; then
	touch "$MODPATH/config/tun-enabled"
fi
if [ -f "$old_moddir/config/killswitch-enabled" ] && [ "$MODPATH" != "$old_moddir" ]; then
	touch "$MODPATH/config/killswitch-enabled"
fi
