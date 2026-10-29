#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
for abi in arm64-v8a armeabi-v7a x86_64 x86; do
	OUT="$ROOT/module/package-$abi"
	rm -rf "$OUT"
	mkdir -p "$OUT/config" "$OUT/system/bin/$abi"
	cp "$ROOT/module/module.prop" "$ROOT/module/service.sh" "$ROOT/module/uninstall.sh" "$ROOT/module/action.sh" "$ROOT/module/customize.sh" "$OUT/"
	cp "$ROOT/module/config/config.toml.example" "$ROOT/module/config/tun.json" "$OUT/config/"
	cp -R "$ROOT/module/scripts" "$OUT/scripts"
	cp -R "$ROOT/module/webroot" "$OUT/webroot"
	chmod 0755 "$OUT/scripts/"*.sh
	binary="$ROOT/daemon/target/$abi/release/dohd"
	[ -x "$binary" ] || { echo "missing binary: $binary" >&2; exit 1; }
	cp "$binary" "$OUT/system/bin/$abi/dohd"
	sing_box="$ROOT/daemon/target/$abi/release/sing-box"
	[ -x "$sing_box" ] || { echo "missing binary: $sing_box" >&2; exit 1; }
	cp "$sing_box" "$OUT/system/bin/$abi/sing-box"
	chmod 0755 "$OUT/system/bin/$abi/sing-box"
	chmod 0755 "$OUT/system/bin/$abi/dohd"
	chmod 0755 "$OUT"/*.sh
	(cd "$OUT" && zip -qr "$ROOT/dohd-$abi.zip" .)
	sha256sum "$ROOT/dohd-$abi.zip" > "$ROOT/dohd-$abi.zip.sha256"
	rm -rf "$OUT"
done
