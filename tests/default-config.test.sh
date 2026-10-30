#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

! grep -Fq 'cloudflare-dns.com' "$ROOT/module/config/config.toml.example"
! grep -Fq '1.1.1.1' "$ROOT/module/config/config.toml.example"
grep -Fxq 'resolvers = []' "$ROOT/module/config/config.toml.example"
grep -Fq 'Empty - use system DNS' "$ROOT/module/webroot/index.html"