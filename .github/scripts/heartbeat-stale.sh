#!/usr/bin/env bash
# Open/close the update-stale issue. Needs skopeo, jq, gh (GH_TOKEN, GH_REPO).
set -euo pipefail
OURS=docker://ghcr.io/northeast-childrens-dentistry/necdos:stable
AURORA=docker://ghcr.io/ublue-os/aurora:stable
if ! BASE=$(skopeo inspect --no-creds "$OURS" | jq -er '.Labels["io.necdos.base-image"]'); then
  echo "No labeled stable yet; skipping staleness check."
  exit 0
fi
# Top-level digest of the tag (Aurora is a manifest list), as pinned in Containerfile.
LATEST="sha256:$(skopeo inspect --no-creds --raw "$AURORA" | sha256sum | cut -d' ' -f1)"
gh label create update-stale --color FBCA04 --description "stable is behind Aurora" 2>/dev/null || true
ISSUE=$(gh issue list --label update-stale --state open --json number --jq '.[0].number // empty')
if [[ "$BASE" == *"@$LATEST" ]]; then
  [[ -z "$ISSUE" ]] || gh issue close "$ISSUE" --comment "stable is on the current Aurora digest again."
  exit 0
fi
# Age of the Aurora digest stable is built on. A digest Aurora has already pruned counts as very old.
if CREATED=$(skopeo inspect --no-creds "docker://ghcr.io/ublue-os/aurora@${BASE#*@}" | jq -er .Created); then
  AGE_DAYS=$(( ($(date +%s) - $(date -d "$CREATED" +%s)) / 86400 ))
else
  AGE_DAYS=999
fi
# Normal lag is up to 12 days (5-day soak + ~weekly Aurora releases); alert 14 days past that.
if (( AGE_DAYS >= 26 )); then
  MSG="stable is built on Aurora ${BASE#*@}, which is ${AGE_DAYS} days old (current Aurora stable: ${LATEST}). Check the Renovate Dependency Dashboard and the last build run."
  if [[ -n "$ISSUE" ]]; then gh issue comment "$ISSUE" --body "$MSG"
  else gh issue create --label update-stale --title "NECD OS stable is behind Aurora" --body "$MSG"; fi
fi
