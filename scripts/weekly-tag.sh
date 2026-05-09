#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${REPO_ROOT}/.backup-tag.lock"
DRY_RUN="${1:-}"

if [[ -e "${LOCK_FILE}" ]]; then
  echo "[error] weekly tag job already running (lock file exists: ${LOCK_FILE})" >&2
  exit 1
fi

trap 'rm -f "${LOCK_FILE}"' EXIT
: > "${LOCK_FILE}"

cd "${REPO_ROOT}"

echo "[info] starting weekly tag job at $(date -u +'%Y-%m-%dT%H:%M:%SZ')"

if [[ "${DRY_RUN}" == "--dry-run" ]]; then
  ./scripts/backup-and-push.sh --dry-run
else
  ./scripts/backup-and-push.sh
fi

tag_name="backup-$(date -u +'%Y-%m-%d')"
tag_msg="Weekly homelab snapshot ${tag_name}"

if git rev-parse -q --verify "refs/tags/${tag_name}" >/dev/null; then
  echo "[info] tag already exists locally: ${tag_name}"
  exit 0
fi

if [[ "${DRY_RUN}" == "--dry-run" ]]; then
  echo "[info] dry run complete; would create and push tag: ${tag_name}"
  exit 0
fi

git fetch --tags origin

if git ls-remote --tags origin "refs/tags/${tag_name}" | grep -q "${tag_name}"; then
  echo "[info] tag already exists on remote: ${tag_name}"
  exit 0
fi

git tag -a "${tag_name}" -m "${tag_msg}"
git push origin "${tag_name}"

echo "[info] weekly tag job complete (${tag_name})"
