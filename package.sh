#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$ROOT/scripts/package-common.sh"

for abi in $ABI_LIST; do
	OUT="$ROOT/module/package-$abi"
	STAGING=$OUT
	trap 'exit 1' HUP INT TERM
	cleanup() {
		rm -rf "$STAGING"
	}
	trap cleanup EXIT

	rm -rf "$OUT"
	mkdir -p "$OUT/config" "$OUT/system/bin/$abi"

	stage_module "$ROOT" "$abi" "$OUT"

	(cd "$OUT" && zip -qr "$ROOT/dohd-$abi.zip" .)

	sha256sum "$ROOT/dohd-$abi.zip" > "$ROOT/dohd-$abi.zip.sha256"
	cleanup
	trap - EXIT
done
