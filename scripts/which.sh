#!/usr/bin/env bash
# which.sh — resolve a commit / short / date / 'latest' to a tarball URL from
# index.json (prototype of a `vyges-mockturtle which`).
# Usage: scripts/which.sh <commit|short|date|latest>
set -euo pipefail
Q="${1:?usage: which.sh <commit|short|date|latest>}"
IDX="${IDX:-index.json}"
[ -f "$IDX" ] || { echo "no index.json" >&2; exit 1; }

if [ "$Q" = latest ]; then
  sel='[.builds[]|select(.channel=="release")][0]'
else
  sel="[.builds[]|select((.commit|startswith(\"$Q\")) or .short==\"$Q\" or .date==\"$Q\")][0]"
fi
row=$(jq -c "$sel" "$IDX")
[ "$row" != "null" ] || { echo "no build matches '$Q'" >&2; exit 1; }
echo "$row" | jq -r '"version: \(.version)\ncommit:  \(.commit)\ntarball: \(.tarball_url)"'
