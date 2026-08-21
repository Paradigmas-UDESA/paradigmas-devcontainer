#!/usr/bin/env bash
# Copies template/devcontainer.json into an activity repo's .devcontainer/.
#
# Run this against every existing activity repo whenever the course image
# tag is bumped, so all activities stay pointed at the same, already-pulled
# image instead of drifting to per-repo copies with stale tags.
#
# Usage:
#   scripts/sync-devcontainer.sh <path-to-activity-repo> [...more paths]
#
# Example:
#   scripts/sync-devcontainer.sh \
#     ../Clases/Clase\ 2 \
#     ../Clases/Clase-3---Memoria-Dinamica \
#     ../TP-Hive

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template="$script_dir/../template/devcontainer.json"

if [[ ! -f "$template" ]]; then
  echo "error: template not found at $template" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <path-to-activity-repo> [...more paths]" >&2
  exit 1
fi

for repo in "$@"; do
  if [[ ! -d "$repo" ]]; then
    echo "skip: $repo (not a directory)" >&2
    continue
  fi
  mkdir -p "$repo/.devcontainer"
  cp "$template" "$repo/.devcontainer/devcontainer.json"
  echo "synced -> $repo/.devcontainer/devcontainer.json"
done
