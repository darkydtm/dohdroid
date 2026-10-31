#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for script in "$ROOT"/module/service.sh "$ROOT"/module/boot-completed.sh "$ROOT"/module/uninstall.sh "$ROOT"/module/action.sh "$ROOT"/module/customize.sh "$ROOT"/module/scripts/*.sh "$ROOT"/scripts/*.sh; do
	bash -n "$script"
done
for test in "$ROOT"/tests/*.test.js; do
	node "$test"
done
for test in "$ROOT"/tests/*.test.sh; do
	sh "$test"
done
