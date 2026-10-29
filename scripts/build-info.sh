#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf unknown)
branch=${BUILD_BRANCH:-$(git -C "$ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf unknown)}
branch=$(printf '%s' "$branch" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf 'window.buildInfo = {"branch":"%s","commit":"%s"};\n' "$branch" "$commit" > "$1/build-info.js"
