# shellcheck shell=sh
set_file_permissions() {
	for target in "$@"; do
		[ -f "$target" ] || continue
		set_perm "$target" 0 0 0755
	done
}

remove_legacy_resolver_blocks() {
	input=$1
	output=$2
	awk '
		function flush() {
			if (block !~ /url = "https:\/\/cloudflare-dns\.com\/dns-query"/) printf "%s", block
			block = ""
		}
		/^\[\[resolvers\]\]$/ {
			if (in_resolver) flush()
			in_resolver = 1
			block = $0 "\n"
			next
		}
		/^\[/ {
			if (in_resolver) flush()
			in_resolver = 0
			print
			next
		}
		in_resolver { block = block $0 "\n"; next }
		{ print }
		END { if (in_resolver) flush() }
	' "$input" > "$output"
}

migrate_config() {
	old_moddir=${DOHD_OLD_MODDIR:-/data/adb/modules/doh-dns}
	old_config="$old_moddir/config/config.toml"
	if [ -f "$old_config" ] && [ "$MODPATH/config/config.toml" != "$old_config" ]; then
		cp "$old_config" "$MODPATH/config/config.toml"
		set_perm "$MODPATH/config/config.toml" 0 0 0600
	fi
	if [ -f "$MODPATH/config/config.toml" ] && grep -Fq 'url = "https://cloudflare-dns.com/dns-query"' "$MODPATH/config/config.toml"; then
		tmp="$MODPATH/config/config.toml.migrate"
		remove_legacy_resolver_blocks "$MODPATH/config/config.toml" "$tmp"
		mv "$tmp" "$MODPATH/config/config.toml"
		set_perm "$MODPATH/config/config.toml" 0 0 0600
	fi
	if [ ! -d "$old_moddir/config" ] || [ -f "$old_moddir/config/daemon-enabled" ]; then touch "$MODPATH/config/daemon-enabled"; fi
	if [ -f "$old_moddir/config/tun-enabled" ] && [ "$MODPATH" != "$old_moddir" ]; then touch "$MODPATH/config/tun-enabled"; fi
	if [ -f "$old_moddir/config/killswitch-enabled" ] && [ "$MODPATH" != "$old_moddir" ]; then touch "$MODPATH/config/killswitch-enabled"; fi
}

set_file_permissions "$MODPATH"/scripts/*.sh
set_file_permissions "$MODPATH"/system/bin/*/dohd "$MODPATH"/system/bin/*/sing-box
mkdir -p "$MODPATH/config"
migrate_config
