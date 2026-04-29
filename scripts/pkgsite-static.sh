#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${1:-8097}"
OUT_DIR="$ROOT_DIR/ofm-docs/godoc"
BASE_URL="http://127.0.0.1:${PORT}"
PKGSITE_LOG="/tmp/ofm-pkgsite.log"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "Starting pkgsite on ${BASE_URL}..."
"$ROOT_DIR/ofm-infra/scripts/pkgsite-serve.sh" "$PORT" >"$PKGSITE_LOG" 2>&1 &
SERVER_PID=$!

for _ in {1..60}; do
  if wget -qO- "$BASE_URL" >/dev/null 2>&1; then
    echo "pkgsite is ready."
    break
  fi
  sleep 1
done

if ! wget -qO- "$BASE_URL" >/dev/null 2>&1; then
  echo "pkgsite did not become ready. Recent log output:"
  tail -n 40 "$PKGSITE_LOG" || true
  exit 1
fi

echo "Mirroring docs into $OUT_DIR ..."
wget \
  --mirror \
  --page-requisites \
  --convert-links \
  --adjust-extension \
  --no-host-directories \
  --no-verbose \
  --directory-prefix "$OUT_DIR" \
  "$BASE_URL/"

echo "Static docs written to $OUT_DIR"
