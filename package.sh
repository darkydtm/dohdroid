#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT="$ROOT/package"
rm -rf "$OUT"
mkdir -p "$OUT/config" "$OUT/system/bin"
cp "$ROOT/module.prop" "$ROOT/service.sh" "$ROOT/uninstall.sh" "$ROOT/action.sh" "$OUT/"
cp "$ROOT/config/config.toml.example" "$OUT/config/"
for abi in arm64-v8a armeabi-v7a x86_64 x86; do
	binary="$ROOT/target/$abi/release/dohd"
	[ -x "$binary" ] || { echo "missing binary: $binary" >&2; exit 1; }
	mkdir -p "$OUT/system/bin/$abi"
	cp "$binary" "$OUT/system/bin/$abi/dohd"
	chmod 0755 "$OUT/system/bin/$abi/dohd"
done
chmod 0755 "$OUT"/*.sh
(cd "$OUT" && zip -qr "$ROOT/doh-dns.zip" .)
sha256sum "$ROOT/doh-dns.zip" > "$ROOT/doh-dns.zip.sha256"
