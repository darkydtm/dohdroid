for script in "$MODPATH"/scripts/*.sh; do
	set_perm "$script" 0 0 0755
done
for binary in "$MODPATH"/system/bin/*/dohd; do
	[ -f "$binary" ] || continue
	set_perm "$binary" 0 0 0755
done
