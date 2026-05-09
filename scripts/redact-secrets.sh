#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${REPO_ROOT}/configs"

# Redact common key/value secret patterns in yaml/toml/xml/ini/env-like files.
find "${TARGET}" -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.toml' -o -name '*.xml' -o -name '*.ini' -o -name '*.env' \) -print0 |
while IFS= read -r -d '' file; do
  sed -Ei \
    -e 's#((password|passwd|api[_-]?key|private[_-]?key|token|secret|client_secret|passkey|wireguard_private_key|wgprivatekey)[[:space:]]*[:=][[:space:]]*).*$#\1REDACTED#gI' \
    -e 's#(tskey-api-)[A-Za-z0-9_-]+#\1REDACTED#g' \
    -e 's#(ptr_)[A-Za-z0-9=_-]+#\1REDACTED#g' \
    -e 's#(cfat_)[A-Za-z0-9_-]+#\1REDACTED#g' \
    "$file"
done

# Force-redact known sensitive files if present.
for f in \
  "${TARGET}/homepage/config/services.yaml" \
  "${TARGET}/tautulli/config/config.ini"; do
  if [[ -f "$f" ]]; then
    sed -Ei \
      -e 's#(key:[[:space:]]*).*$#\1REDACTED#' \
      -e 's#(username:[[:space:]]*).*$#\1REDACTED#' \
      -e 's#(password:[[:space:]]*).*$#\1REDACTED#' \
      "$f"
  fi
done

# Redact known sensitive Plex attributes if present.
plex_prefs="${TARGET}/plex/config/Library/Application Support/Plex Media Server/Preferences.xml"
if [[ -f "${plex_prefs}" ]]; then
  sed -Ei \
    -e 's#(PlexOnlineToken=")[^"]*(")#\1REDACTED\2#g' \
    -e 's#(PlexOnlineMail=")[^"]*(")#\1REDACTED\2#g' \
    -e 's#(PlexOnlineUsername=")[^"]*(")#\1REDACTED\2#g' \
    "$plex_prefs"
fi

echo "Redaction complete"
