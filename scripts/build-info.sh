#!/bin/sh
set -eu
[ "$#" -eq 1 ] || { printf 'usage: %s OUTPUT_DIRECTORY\n' "$0" >&2; exit 2; }
[ -d "$1" ] || { printf 'output directory does not exist: %s\n' "$1" >&2; exit 2; }
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf unknown)
branch=${BUILD_BRANCH:-$(git -C "$ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf unknown)}
python3 - "$1/build-info.js" "$branch" "$commit" <<'PYTHON'
import json
import sys
from pathlib import Path
output, branch, commit = sys.argv[1:]
Path(output).write_text("window.buildInfo = " + json.dumps({"branch": branch, "commit": commit}) + ";\n", encoding="utf-8")
PYTHON
