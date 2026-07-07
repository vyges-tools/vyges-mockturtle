#!/usr/bin/env bash
# update-index.sh — prepend a build row to index.json (newest-first). The index
# is the commit → artifact lookup (same idiom as vyges-openroad), tarball-only.
# Args: <commit> <short> <version> <tarball_url> [channel]
set -euo pipefail
COMMIT="${1:?}"; SHORT="${2:?}"; VERSION="${3:?}"; TARBALL="${4:?}"; CHANNEL="${5:-release}"
DATE=$(date -u +%Y-%m-%d)

[ -f index.json ] || echo '{"schema":"vyges-mockturtle-index/1.0","builds":[]}' > index.json

row=$(jq -n \
  --arg commit "$COMMIT" --arg short "$SHORT" --arg version "$VERSION" \
  --arg date "$DATE" --arg tarball "$TARBALL" --arg channel "$CHANNEL" \
  '{commit:$commit, short:$short, version:$version, date:$date, channel:$channel,
    arch:"linux-x86_64", tarball_url:$tarball}')

jq --argjson row "$row" \
  '.builds |= ([$row] + (map(select(.commit != $row.commit))))' \
  index.json > index.json.tmp && mv index.json.tmp index.json
echo "index.json updated: $SHORT ($CHANNEL)"
