#!/usr/bin/env bash
set -euo pipefail

SRC_ROOT="/home/anas"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INCLUDE_FILE="${REPO_ROOT}/inventory/include-paths.txt"
DEST_ROOT="${REPO_ROOT}/configs"

mkdir -p "${DEST_ROOT}"

while IFS= read -r rel; do
  [[ -z "${rel}" ]] && continue
  src="${SRC_ROOT}/${rel}"
  dest="${DEST_ROOT}/${rel}"

  if [[ -f "${src}" ]]; then
    mkdir -p "$(dirname "${dest}")"
    cp "${src}" "${dest}"
  else
    echo "[warn] missing: ${rel}" >&2
  fi
done < "${INCLUDE_FILE}"

echo "Sync complete: ${DEST_ROOT}"
