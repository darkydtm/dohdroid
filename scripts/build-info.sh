#!/bin/sh
set -eu
[ "$#" -ge 1 ] && [ -n "$1" ] || { printf 'usage: %s <webroot-directory>\n' "$0" >&2; exit 2; }
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf unknown)
branch=${BUILD_BRANCH:-$(git -C "$ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf unknown)}
BUILD_BRANCH_VALUE=$branch BUILD_COMMIT_VALUE=$commit node -e 'process.stdout.write("window.buildInfo = " + JSON.stringify({branch: process.env.BUILD_BRANCH_VALUE, commit: process.env.BUILD_COMMIT_VALUE}) + ";" + String.fromCharCode(10))' > "$1/build-info.js"
