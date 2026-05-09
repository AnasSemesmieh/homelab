#!/bin/sh
set -eu

REPO_ROOT="/repo"
INCLUDE_FILE="${REPO_ROOT}/inventory/include-paths.txt"
SRC_ROOT="${REPO_ROOT}/configs"
TARGET_HOME="${TARGET_HOME:-/home/anas}"
DRY_RUN="${DRY_RUN:-true}"
OVERWRITE="${OVERWRITE:-false}"

if [ ! -f "${INCLUDE_FILE}" ]; then
  echo "[error] include file not found: ${INCLUDE_FILE}" >&2
  exit 1
fi

if [ ! -d "${SRC_ROOT}" ]; then
  echo "[error] source configs directory not found: ${SRC_ROOT}" >&2
  exit 1
fi

echo "[info] restore job starting"
echo "[info] target home: ${TARGET_HOME}"
echo "[info] dry run: ${DRY_RUN}"
echo "[info] overwrite existing files: ${OVERWRITE}"

while IFS= read -r rel; do
  [ -z "${rel}" ] && continue

  src="${SRC_ROOT}/${rel}"
  dest="/host${TARGET_HOME}/${rel}"
  dest_dir="$(dirname "${dest}")"

  if [ ! -f "${src}" ]; then
    echo "[warn] source missing, skipping: ${src}"
    continue
  fi

  if [ "${DRY_RUN}" = "true" ]; then
    echo "[dry-run] copy ${src} -> ${dest}"
    continue
  fi

  mkdir -p "${dest_dir}"

  if [ -f "${dest}" ] && [ "${OVERWRITE}" != "true" ]; then
    echo "[skip] exists (set OVERWRITE=true to replace): ${dest}"
    continue
  fi

  cp -f "${src}" "${dest}"
  echo "[ok] copied: ${dest}"
done < "${INCLUDE_FILE}"

echo "[info] restore job complete"
