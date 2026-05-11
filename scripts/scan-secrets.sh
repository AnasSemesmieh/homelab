#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${REPO_ROOT}/configs"

echo "Scanning ${TARGET} for potential secrets..."

matches="$(
  {
    grep -RInE '(password|passwd|api[_-]?key|private[_-]?key|token|secret|client_secret|passkey|wireguard_private_key|wgprivatekey)[[:space:]]*[:=][[:space:]]*[^#[:space:]]+' "${TARGET}" || true
    grep -RInE '(tskey-api-|ptr_|cfat_)' "${TARGET}" || true
    grep -RInE '(PlexOnlineToken|PlexOnlineMail|PlexOnlineUsername)="[^"]+"' "${TARGET}" || true
    grep -RInE 'WIREGUARD_PRIVATE_KEY:[[:space:]]*[A-Za-z0-9+/=]{20,}' "${TARGET}" || true
    grep -RInE '^(AUTHENTIK_SECRET_KEY|PG_PASS|AUTHENTIK_BOOTSTRAP_PASSWORD|AUTHENTIK_BOOTSTRAP_TOKEN)=.+' "${TARGET}" || true
  } | grep -vE 'REDACTED|\{\{[[:space:]]*\.Config\.' || true
)"

if [[ -n "${matches}" ]]; then
  echo "${matches}"
  echo "[warn] Potential unredacted secret patterns found. Review before commit."
  exit 1
fi

echo "No obvious secret patterns found."
