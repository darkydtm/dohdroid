#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
for abi in arm64-v8a armeabi-v7a x86_64 x86; do
	OUT="$ROOT/package-$abi"
	rm -rf "$OUT"
	mkdir -p "$OUT/config" "$OUT/system/bin/$abi"
	cp "$ROOT/module.prop" "$ROOT/service.sh" "$ROOT/uninstall.sh" "$ROOT/action.sh" "$OUT/"
	cp "$ROOT/config/config.toml.example" "$OUT/config/"
	binary="$ROOT/target/$abi/release/dohd"
	[ -x "$binary" ] || { echo "missing binary: $binary" >&2; exit 1; }
	cp "$binary" "$OUT/system/bin/$abi/dohd"
	chmod 0755 "$OUT/system/bin/$abi/dohd"
	chmod 0755 "$OUT"/*.sh
	(cd "$OUT" && zip -qr "$ROOT/dohd-$abi.zip" .)
	sha256sum "$ROOT/dohd-$abi.zip" > "$ROOT/dohd-$abi.zip.sha256"
	rm -rf "$OUT"
done
