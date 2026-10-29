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
old_config=/data/adb/modules/doh-dns/config/config.toml
if [ -f "$old_config" ] && [ "$MODPATH/config/config.toml" != "$old_config" ]; then
	mkdir -p "$MODPATH/config"
	cp "$old_config" "$MODPATH/config/config.toml"
	set_perm "$MODPATH/config/config.toml" 0 0 0600
fi
if [ -f /data/adb/modules/doh-dns/config/tun-enabled ] && [ "$MODPATH" != /data/adb/modules/doh-dns ]; then
	touch "$MODPATH/config/tun-enabled"
fi
