#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${REPO_ROOT}/.backup.lock"
DRY_RUN="${1:-}"

if [[ -e "${LOCK_FILE}" ]]; then
  echo "[error] backup job already running (lock file exists: ${LOCK_FILE})" >&2
  exit 1
fi

trap 'rm -f "${LOCK_FILE}"' EXIT
: > "${LOCK_FILE}"

cd "${REPO_ROOT}"

echo "[info] starting backup job at $(date -u +'%Y-%m-%dT%H:%M:%SZ')"

./scripts/sync-configs.sh
./scripts/redact-secrets.sh
./scripts/scan-secrets.sh

if [[ "${DRY_RUN}" == "--dry-run" ]]; then
  echo "[info] dry run complete"
  git status --short
  exit 0
fi

git add -A

if git diff --cached --quiet; then
  echo "[info] no changes to commit"
  exit 0
fi

commit_msg="backup: automated snapshot $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
git commit -m "${commit_msg}"

if ! git pull --rebase --autostash origin main; then
  echo "[error] git pull --rebase failed; manual resolution required" >&2
  git rebase --abort 2>/dev/null || true
  exit 1
fi

git push origin main

echo "[info] backup job complete"
