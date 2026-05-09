#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${REPO_ROOT}/configs"

echo "Scanning ${TARGET} for potential secrets..."

matches="$(
  {
    grep -RInE '(password|passwd|api[_-]?key|token|secret|client_secret|passkey)[[:space:]]*[:=][[:space:]]*[^#[:space:]]+' "${TARGET}" || true
    grep -RInE '(tskey-api-|ptr_|cfat_)' "${TARGET}" || true
  } | grep -vE 'REDACTED|\{\{[[:space:]]*\.Config\.' || true
)"

if [[ -n "${matches}" ]]; then
  echo "${matches}"
  echo "[warn] Potential unredacted secret patterns found. Review before commit."
  exit 1
fi

echo "No obvious secret patterns found."
