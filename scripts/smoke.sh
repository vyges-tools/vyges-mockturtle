#!/usr/bin/env bash
# smoke.sh — prove a built bundle runs. `vyges-emap` with no args prints usage and
# exits 2, so that's the liveness check (run from a fresh path to prove relocation).
# Usage: scripts/smoke.sh <bundle-dir>
set -uo pipefail
TARGET="${1:?usage: smoke.sh <bundle-dir>}"
[ -d "$TARGET" ] || { echo "not a bundle dir: $TARGET" >&2; exit 1; }
tmp=$(mktemp -d); cp -a "$TARGET" "$tmp/b"
"$tmp/b/bin/vyges-emap" >/dev/null 2>&1; rc=$?
rm -rf "$tmp"
if [ "$rc" -eq 2 ]; then echo "SMOKE_OK"; else echo "SMOKE_FAIL (exit $rc)"; exit 1; fi
