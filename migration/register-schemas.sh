#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REGISTRY_URL=${SCHEMA_REGISTRY_URL:-http://127.0.0.1:8084/apis/registry/v3}

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }

for schema in "$ROOT"/schemas/*.json; do
  artifact=$(basename "$schema" .json)
  curl --fail --silent --show-error \
    -X POST "$REGISTRY_URL/groups/default/artifacts" \
    -H 'Content-Type: application/json' \
    -H 'X-Registry-ArtifactId: '"$artifact" \
    -H 'X-Registry-ArtifactType: JSON' \
    --data-binary "@$schema" >/dev/null || {
    curl --fail --silent --show-error \
      -X PUT "$REGISTRY_URL/groups/default/artifacts/$artifact" \
      -H 'Content-Type: application/json' \
      -H 'X-Registry-ArtifactType: JSON' \
      --data-binary "@$schema" >/dev/null
  }
  echo "registered $artifact"
done
