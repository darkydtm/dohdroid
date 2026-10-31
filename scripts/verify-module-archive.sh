#!/bin/sh
set -eu
[ "$#" -eq 2 ] || { printf 'usage: %s ARCHIVE ABI\n' "$0" >&2; exit 2; }
archive=$1
abi=$2
expected_abis='arm64-v8a armeabi-v7a x86_64 x86'
case " $expected_abis " in *" $abi "*) ;; *) printf 'unsupported ABI: %s\n' "$abi" >&2; exit 2 ;; esac
sha256sum -c "$archive.sha256"
unzip -l "$archive"
entries=$(unzip -Z1 "$archive")
for entry in \
	scripts/firewall.sh scripts/webui.sh customize.sh boot-completed.sh \
	webroot/index.html webroot/styles.css webroot/js/api.js webroot/js/state.js \
	webroot/js/app.js webroot/build-info.js config/tun.json scripts/tun-firewall.sh \
	"system/bin/$abi/dohd" "system/bin/$abi/sing-box"; do
	printf '%s\n' "$entries" | grep -Fxq "$entry" || { printf 'missing archive entry: %s\n' "$entry" >&2; exit 1; }
done
for other_abi in $expected_abis; do
	[ "$other_abi" = "$abi" ] && continue
	for binary in dohd sing-box; do
		if printf '%s\n' "$entries" | grep -Fxq "system/bin/$other_abi/$binary"; then
			printf 'unexpected ABI binary: system/bin/%s/%s\n' "$other_abi" "$binary" >&2
			exit 1
		fi
	done
done
