#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")"/.. && pwd)
mkdir -p "$ROOT/package/system/bin" "$ROOT/package/config"
cp "$ROOT/module.prop" "$ROOT/service.sh" "$ROOT/uninstall.sh" "$ROOT/action.sh" "$ROOT/package/"
cp "$ROOT/config/config.toml.example" "$ROOT/package/config/"
cp "$ROOT/target/aarch64-linux-android/release/dohd" "$ROOT/package/system/bin/dohd"
chmod 0755 "$ROOT/package"/*.sh "$ROOT/package/system/bin/dohd"
(cd "$ROOT/package" && zip -qr "$ROOT/doh-dns.zip" .)
sha256sum "$ROOT/doh-dns.zip" > "$ROOT/doh-dns.zip.sha256"
