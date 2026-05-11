# Secrets Catalog

This document lists all secrets intentionally redacted from the backup repository.
Each section explains where the secret is used, how to source it, format requirements, and rotation procedures.

**Table of Contents:**
- [Plex Secrets](#plex-secrets)
- [Pi-hole Secrets](#pi-hole-secrets)
- [Homepage Widget Secrets](#homepage-widget-secrets)
- [Traefik TLS Certificates](#traefik-tls-certificates)
- [Tautulli Secrets](#tautulli-secrets)
- [Arr Stack Secrets](#arr-stack-secrets)
- [Immich Secrets](#immich-secrets)
- [Home Assistant Secrets](#home-assistant-secrets)
- [Authentik Secrets](#authentik-secrets)
- [Secret Injection Procedures](#secret-injection-procedures)

---

## Plex Secrets

### PlexOnlineToken

**Location:** `plex/config/Library/Application Support/Plex Media Server/Preferences.xml`  
**Attribute:** `PlexOnlineToken="..."`  
**Purpose:** Authenticate Plex server to Plex account; enables remote access, library sharing, and sync  
**Format:** URL-safe alphanumeric string, typically 20–50 characters  
**Example (masked):** `PlexOnlineToken="abc123def456ghi789jk..."`

**How to Source:**

1. **From existing Plex installation:**
   - Stop Plex container or service
   - Extract token from `Preferences.xml`:
     ```bash
     grep -oP 'PlexOnlineToken="\K[^"]*' /path/to/Preferences.xml
     ```
   - Add to backup repository and rehydrate on fresh install

2. **From Plex Web UI (fresh install):**
   - Log into Plex web interface (`http://plex.homelab`)
   - Go to Settings → Remote Access
   - The token is not directly visible in UI, but you can:
     - Go to Settings → Account, find the "Remote Access" section
     - Or regenerate in Settings → Remote Access → "Enable remote access"
   - Extract token from generated `Preferences.xml` after first login

3. **From Plex CLI (using official docs):**
   - See [Plex Preferences.xml reference](https://support.plex.tv/articles/203529193/)

**Format Validation:**
- Must be non-empty string
- Usually alphanumeric + hyphens
- Check: `grep -E 'PlexOnlineToken="[a-zA-Z0-9_-]{20,}"' Preferences.xml`

**Rotation/Renewal:**
- **When needed:** If compromised, if you want to revoke old sessions
- **How to regenerate:**
  1. Log into Plex account settings: https://app.plex.tv/desktop/settings/account
  2. Go to "Remote Access" section
  3. Click "Restart Remote Access" (generates new token)
  4. Extract new token from Preferences.xml (after Plex reads it)
  5. Update backup repo with new token

**Related Secrets:**
- `PlexOnlineUsername` — Account email (also redacted)
- `PlexOnlineMail` — Account email (also redacted)

---

### PlexOnlineUsername & PlexOnlineMail

**Locations:** `plex/config/Library/Application Support/Plex Media Server/Preferences.xml`  
**Attributes:** `PlexOnlineUsername="..."`, `PlexOnlineMail="..."`  
**Purpose:** Identity information for Plex account  
**Format:** Email address or username string  
**Example (masked):** `PlexOnlineUsername="user@example.com"`

**How to Source:**
- Use your Plex account email address
- Can be retrieved from https://app.plex.tv/desktop/settings/account
- Typically the same as your Plex login email

**Rotation/Renewal:**
- No routine rotation needed unless account is compromised
- If you change your Plex email, regenerate `Preferences.xml` by logging out/in via Plex UI

---

## Pi-hole Secrets

### Pi-hole API Token / Admin Password

**Location:** `pihole/etc-pihole/pihole.toml`  
**Keys:**
- `ADMIN_AUTH_SESSION` — Session token for web dashboard
- `WEBTHEME` — Not sensitive, but present
- Various other configs

**Purpose:** Admin access to Pi-hole dashboard and API  
**Format:** Session token (variable length, typically 32–64 hex chars)  
**Example (masked):** `ADMIN_AUTH_SESSION = "a1b2c3d4e5f6g7h8i9j0..."`

**How to Source:**

1. **First time setup (fresh Pi-hole):**
   - Pi-hole generates a random password on first run
   - Access web interface (`http://pihole.homelab/admin`)
   - Password is displayed in container logs:
     ```bash
     docker compose -f pihole/docker-compose.yml logs pihole | grep -i "password"
     ```

2. **From existing installation:**
   - Log into Pi-hole web admin console
   - Settings → Users → View password (if you have admin access)
   - Or extract session from browser localStorage (for restore):
     ```bash
     # In browser DevTools → Application → LocalStorage → pihole.homelab
     ```

3. **Using pihole.toml directly:**
   - Admin password is hashed; extract from web UI settings instead

**Format Validation:**
- Must be a valid session token or password string
- Check presence: `grep -E "ADMIN_AUTH" pihole/etc-pihole/pihole.toml`

**Rotation/Renewal:**
- **When needed:** Routine security practice (annually or after suspected compromise)
- **How to reset:**
  ```bash
  cd pihole
  docker compose exec pihole pihole -a -p <new-password>
  ```
- **Then update:** Extract new password and update backup if storing it

**Related Settings:**
- Refer to [Pi-hole official configuration docs](https://docs.pi-hole.net/)

---

## Homepage Widget Secrets

Homepage integrates with multiple services via API keys. Each widget requires credentials redacted from `homepage/config/services.yaml`.

### Traefik Widget

**Location:** `homepage/config/services.yaml` → `- Traefik` widget  
**Config key:** `api:` (contains API endpoint URL)  
**Purpose:** Display Traefik routing status and service health  
**Format:** API URL (e.g., `http://traefik.docker.internal:8080`)  
**Example (masked):** `api: "http://traefik.docker.internal:8080"`

**How to Source:**
- Traefik API is internal (exposed on port 8080 by default)
- URL should be `http://traefik:8080` or `http://traefik.docker.internal:8080` (if using Docker DNS)

**Validation:**
```bash
curl -s http://traefik:8080/api/overview | jq .
```

---

### Portainer Widget

**Location:** `homepage/config/services.yaml` → `- Portainer` widget  
**Config keys:** `key:`, `username:`, `password:`  
**Purpose:** Display container and image stats from Portainer  
**Format:** API token (key) + username + password  
**Example (masked):**
```yaml
- Portainer:
    icon: portainer.svg
    href: https://portainer.homelab
    key: "ptr_abc123def456...xyz"
    username: "REDACTED"
    password: "REDACTED"
```

**How to Source:**

1. **Generate Portainer API token:**
   - Log into Portainer web UI (`https://portainer.homelab`)
   - Settings → Users → Your Profile
   - Scroll to "API Token Generation" section
   - Click "Generate new token"
   - Copy token (format: `ptr_...`)

2. **Get username/password:**
   - Use your Portainer login credentials
   - Username is your Portainer account username
   - Password is your Portainer login password

**Format Validation:**
- API key must start with `ptr_` and be alphanumeric
- Username: non-empty string
- Password: non-empty string
- Check: `grep -E "key:.*ptr_" homepage/config/services.yaml`

**Rotation/Renewal:**
- **When needed:** Routine rotation (quarterly or after suspected compromise)
- **How to regenerate:**
  1. In Portainer UI → Settings → Users → Your Profile
  2. Click "Revoke" on existing token
  3. Click "Generate new token"
  4. Update `services.yaml` with new token

---

### Tautulli Widget

**Location:** `homepage/config/services.yaml` → `- Tautulli` widget  
**Config keys:** `key:`, `username:`, `password:`  
**Purpose:** Display Plex server stats (plays, library size, etc.)  
**Format:** API key + username + password  
**Example (masked):**
```yaml
- Tautulli:
    icon: tautulli.svg
    href: https://tautulli.homelab
    key: "REDACTED"
    username: "REDACTED"
    password: "REDACTED"
```

**How to Source:**

1. **Generate Tautulli API key:**
   - Log into Tautulli web UI (`http://tautulli.homelab`)
   - Settings → Web Interface → API Key
   - Click "Get API key" or use existing one
   - Copy key (typically 32+ hex chars)

2. **Get username/password:**
   - Use your Tautulli login credentials
   - Username: Tautulli admin username (usually "admin")
   - Password: Your Tautulli admin password

**Format Validation:**
- API key: 32+ hex characters
- Check: `grep -E "key:.*[a-f0-9]{32,}" homepage/config/services.yaml`

**Rotation/Renewal:**
- **When needed:** Routine rotation or after compromise
- **How to regenerate:**
  1. In Tautulli web UI → Settings → Web Interface
  2. Click "Reset API Key"
  3. Copy new key
  4. Update `services.yaml`

---

### Glances Widget

**Location:** `homepage/config/services.yaml` → `- Glances` widget  
**Config:** Usually API URL only (no auth if internal)  
**Purpose:** Display system metrics (CPU, memory, network)  
**Format:** URL to Glances WebUI  
**Example:** `http://glances:61208`

**How to Source:**
- Glances runs on host on port 61208
- Internal URL: `http://glances:61208` (no authentication required)
- External URL (if accessed from outside): `http://glances.homelab` (via Traefik)

**Validation:**
```bash
curl -s http://glances:61208/api/3/all | jq .
```

---

## Traefik TLS Certificates

### Wildcard Certificate (Local CA)

**Location:** `traefik/dynamic/tls.yaml` → `certificates:`  
**Files:**
- Private key: `/home/anas/traefik/certs/wildcard.key`
- Certificate: `/home/anas/traefik/certs/wildcard.crt`
- CA cert: `/home/anas/traefik/certs/ca.crt`

**Purpose:** Enable HTTPS for all `*.homelab` services  
**Format:** PEM-encoded certificate and private key  
**Example (masked):**
```
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...
(base64 content)
-----END PRIVATE KEY-----
```

**How to Source:**

1. **Use existing certificates (if available):**
   - If you have a local CA setup, keep the same CA and certificates
   - Copy `.key` and `.crt` files to `/home/anas/traefik/certs/`

2. **Generate new local CA and wildcard cert:**

   ```bash
   # Create local CA
   openssl genrsa -out ca.key 4096
   openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
     -subj "/CN=Homelab Local CA"
   
   # Generate wildcard certificate
   openssl genrsa -out wildcard.key 2048
   openssl req -new -key wildcard.key -out wildcard.csr \
     -subj "/CN=*.homelab"
   
   # Sign with CA
   openssl x509 -req -in wildcard.csr -CA ca.crt -CAkey ca.key \
     -CAcreateserial -out wildcard.crt -days 3650 \
     -extfile <(printf "subjectAltName=DNS:*.homelab,DNS:homelab")
   
   rm wildcard.csr
   mkdir -p /home/anas/traefik/certs
   mv ca.crt ca.key wildcard.crt wildcard.key /home/anas/traefik/certs/
   ```

3. **Validate generated certificates:**
   ```bash
   openssl x509 -in /home/anas/traefik/certs/wildcard.crt -text -noout
   ```

**Format Validation:**
- Private key: starts with `-----BEGIN PRIVATE KEY-----` or `-----BEGIN RSA PRIVATE KEY-----`
- Certificate: starts with `-----BEGIN CERTIFICATE-----`
- Check expiry: `openssl x509 -enddate -noout -in wildcard.crt`

**Rotation/Renewal:**
- **When needed:** Before expiry (check `openssl x509 -enddate -noout -in wildcard.crt`)
- **How to regenerate:** Follow generation steps above with new dates
- **Update:** Edit `traefik/dynamic/tls.yaml` with new cert/key content (base64-encoded or as file references)

**Reference:** [OpenSSL Certificate Generation Guide](https://www.openssl.org/docs/manmaster/man1/openssl-genrsa.html)

---

## Tautulli Secrets

### Tautulli Admin Password & API Key

**Location:** `tautulli/config/config.ini` → `[auth]` and `[api]` sections  
**Keys:**
- `http_password` (web UI admin password)
- `api_key` (API key for external access)

**Purpose:** Protect Tautulli admin panel; enable Plex stats API access  
**Format:** Password (alphanumeric) + API key (32+ hex chars)  
**Example (masked):**
```ini
http_password = REDACTED
api_key = REDACTED
```

**How to Source:**

1. **From existing Tautulli installation:**
   - Extract from `tautulli/config/config.ini`:
     ```bash
     grep -E "^(http_password|api_key)" tautulli/config/config.ini
     ```

2. **Generate new credentials:**
   - Tautulli generates API key on first run
   - Admin password is configured during setup
   - Web UI: Settings → General → API Key (if not set, click "Generate API Key")

3. **Set admin password:**
   - Web UI: Settings → Web Interface → Set new password
   - Or directly edit `config.ini` and restart Tautulli

**Format Validation:**
- Password: non-empty, typically 8+ chars
- API key: 32+ hex characters
- Check: `grep -E "^api_key = [a-f0-9]{32,}" tautulli/config/config.ini`

**Rotation/Renewal:**
- **When needed:** Routine security or after compromise
- **How to rotate:**
  1. Stop Tautulli: `docker compose -f tautulli/docker-compose.yaml down`
  2. Edit `config.ini` directly or via web UI (before stopping)
  3. Restart: `docker compose -f tautulli/docker-compose.yaml up -d`

---

## Arr Stack Secrets

### Prowlarr API Key

**Location:** `arrstack/prowlarr/config.xml` → `<ApiKey>`  
**Purpose:** Allow Radarr/Sonarr to query Prowlarr for indexers  
**Format:** Alphanumeric string, typically 20+ chars  
**Example (masked):** `<ApiKey>abc123def456ghi789jk...</ApiKey>`

**How to Source:**
- Prowlarr generates API key on first run
- Web UI: Settings → General → API Key
- Or extract from config.xml:
  ```bash
  grep -oP '<ApiKey>\K[^<]*' arrstack/prowlarr/config.xml
  ```

**Format Validation:**
- Non-empty alphanumeric string
- Check: `grep -E '<ApiKey>[a-zA-Z0-9]{20,}</ApiKey>' arrstack/prowlarr/config.xml`

---

### Radarr/Sonarr API Keys

**Location:**
- `arrstack/radarr/config.xml` → `<ApiKey>`
- `arrstack/sonarr/config.xml` → `<ApiKey>`

**Purpose:** Allow external services (Tautulli, Homepage, Overseerr) to access arr services  
**Format:** Same as Prowlarr  
**Example (masked):** `<ApiKey>xyz789abc456def...</ApiKey>`

**How to Source:**
- Generated on first run by each service
- Web UI: Settings → General → API Key
- Or extract from config.xml (same pattern as Prowlarr)

**Rotation/Renewal:**
- **When needed:** After suspected compromise
- **How to rotate:**
  1. Stop service: `docker compose -f arrstack/docker-compose.yml down radarr` (or sonarr/prowlarr)
  2. Edit config.xml: change `<ApiKey>` to new value (e.g., generate with `python -c "import secrets; print(secrets.token_hex(20))"`)
  3. Restart: `docker compose -f arrstack/docker-compose.yml up -d radarr`

---

### Gluetun WireGuard Private Key

**Location:** `arrstack/docker-compose.yml` → `WIREGUARD_PRIVATE_KEY` under `gluetun.environment`  
**Purpose:** Authenticates the Gluetun client to the VPN provider's WireGuard endpoint  
**Format:** Base64-encoded private key, typically 44 characters ending with `=`  
**Example (masked):** `WIREGUARD_PRIVATE_KEY: REDACTED`

**How to Source:**

1. **From existing working Gluetun deployment:**
   - Read from your non-backed-up runtime compose/env source:
     ```bash
     grep -E '^\s*WIREGUARD_PRIVATE_KEY:' /home/anas/arrstack/docker-compose.yml
     ```

2. **From VPN provider account (recommended after exposure):**
   - Re-generate or rotate the WireGuard key pair in provider dashboard
   - Use the new private key in `WIREGUARD_PRIVATE_KEY`
   - Update paired public key/config on provider side if required

3. **Gluetun provider setup docs:**
   - [Gluetun Wiki](https://github.com/qdm12/gluetun-wiki)

**Format Validation:**
- Must be base64-like and not empty
- Check: `grep -E 'WIREGUARD_PRIVATE_KEY:[[:space:]]*[A-Za-z0-9+/=]{40,}' arrstack/docker-compose.yml`

**Rotation/Renewal:**
- **When needed:** Immediately if exposed in git history, and then on periodic credential rotation
- **How to rotate:**
  1. Generate a new WireGuard key via VPN provider portal (or allowed client tools)
  2. Replace `WIREGUARD_PRIVATE_KEY` in runtime config (not in tracked sanitized backup)
  3. Restart stack: `docker compose -f arrstack/docker-compose.yml up -d --force-recreate gluetun`
  4. Validate tunnel: `docker logs gluetun | grep -Ei 'wireguard|public ip|connected'`

---

## Immich Secrets

### Immich Database Password

**Location:** `.env` file (not tracked in backup, must be created on restore)  
**Key:** `DB_PASSWORD=...`  
**Purpose:** PostgreSQL database authentication  
**Format:** Password string (typically 16+ chars, alphanumeric + special)  
**Example (masked):** `DB_PASSWORD="SecureP@ss123..."`

**How to Source:**
- Generate random password on fresh install:
  ```bash
  python3 -c "import secrets; print(secrets.token_urlsafe(16))"
  ```
- Or use existing password if restoring to same database

**Format Validation:**
- Non-empty string
- Recommended: 16+ characters, mix of upper/lower/digits/special chars

**Rotation/Renewal:**
- **When needed:** After suspected compromise or database migration
- **How to rotate:**
  1. Create new password
  2. Update `.env` with new `DB_PASSWORD`
  3. Drop and recreate PostgreSQL database
  4. Restart Immich: `docker compose -f immich/docker-compose.yml down && docker compose -f immich/docker-compose.yml up -d`

**Reference:** [Immich environment variables docs](https://immich.app/docs/install/environment-variables)

---

## Home Assistant Secrets

### Home Assistant API Token

**Location:** Not in backup (generated at runtime or stored in `.storage/auth_token.json`)  
**Purpose:** Allow external services to access Home Assistant API  
**Format:** Bearer token (JWT-like, typically 100+ chars)  
**Example (masked):** `Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

**How to Source:**

1. **Generate new token:**
   - Log into Home Assistant web UI (`http://homeassistant.homelab`)
   - User profile → Long-Lived Access Tokens → Create Token
   - Give it a name (e.g., "Backup Restore")
   - Copy token (starts with `eyJ...`)

2. **From existing installation:**
   - Extract from `homeassistant/config/.storage/auth_token.json` (if available)
   - Or regenerate via web UI

**Rotation/Renewal:**
- **When needed:** Routine rotation or after compromise
- **How to rotate:**
  1. Log into Home Assistant UI
  2. User profile → Long-Lived Access Tokens
  3. Click trash icon to revoke old token
  4. Create new token (same steps as above)

**Reference:** [Home Assistant API docs](https://developers.home-assistant.io/docs/api/rest)

---

## Authentik Secrets

Authentik (SSO identity provider) stores secrets in its `.env` file and generates OIDC client credentials at runtime.

### AUTHENTIK_SECRET_KEY

**Location:** `authentik/.env`
**Key:** `AUTHENTIK_SECRET_KEY=...`
**Purpose:** Django secret key used for signing sessions, tokens, and cryptographic operations
**Format:** Random alphanumeric string, 50+ characters recommended
**Example (masked):** `AUTHENTIK_SECRET_KEY=REDACTED`

**How to Source:**

1. **Generate new key:**
   ```bash
   openssl rand -base64 60 | tr -d '\n'
   ```

2. **From existing installation:**
   ```bash
   grep AUTHENTIK_SECRET_KEY ~/authentik/.env
   ```

**Format Validation:**
- Non-empty, 50+ characters
- Check: `grep -E 'AUTHENTIK_SECRET_KEY=.{50,}' authentik/.env`

**Rotation/Renewal:**
- **When needed:** After suspected compromise
- **Impact:** Rotating invalidates all existing sessions — users must re-authenticate
- **How to rotate:**
  1. Generate new key: `openssl rand -base64 60 | tr -d '\n'`
  2. Update `~/authentik/.env`
  3. Restart: `cd ~/authentik && docker compose up -d --force-recreate`

---

### PG_PASS (Authentik PostgreSQL Password)

**Location:** `authentik/.env`
**Key:** `PG_PASS=...`
**Purpose:** PostgreSQL database authentication for Authentik
**Format:** Password string
**Example (masked):** `PG_PASS=REDACTED`

**How to Source:**

1. **Generate new password:**
   ```bash
   openssl rand -base64 32 | tr -d '\n'
   ```

2. **From existing installation:**
   ```bash
   grep PG_PASS ~/authentik/.env
   ```

**Rotation/Renewal:**
- **When needed:** After suspected compromise
- **How to rotate:**
  1. Stop Authentik: `cd ~/authentik && docker compose down`
  2. Update `PG_PASS` in `.env`
  3. Update PostgreSQL password: `docker exec -it authentik-postgresql psql -U authentik -c "ALTER USER authentik PASSWORD 'new_password';"`
  4. Restart: `docker compose up -d`

---

### AUTHENTIK_BOOTSTRAP_PASSWORD

**Location:** `authentik/.env`
**Key:** `AUTHENTIK_BOOTSTRAP_PASSWORD=...`
**Purpose:** Initial admin (akadmin) password on first boot
**Format:** Password string
**Example (masked):** `AUTHENTIK_BOOTSTRAP_PASSWORD=REDACTED`

**How to Source:**
- Use your chosen admin password
- Only used on first deployment (Authentik ignores it after initial setup)
- If you've changed the admin password via the UI, this value is irrelevant

**Rotation/Renewal:**
- Change via Authentik admin UI: Directory → Users → akadmin → Set password
- The `.env` value only matters on fresh deployment

---

### AUTHENTIK_BOOTSTRAP_TOKEN

**Location:** `authentik/.env`
**Key:** `AUTHENTIK_BOOTSTRAP_TOKEN=...`
**Purpose:** Initial API token created on first boot for programmatic access
**Format:** Alphanumeric string, typically 60+ characters
**Example (masked):** `AUTHENTIK_BOOTSTRAP_TOKEN=REDACTED`

**How to Source:**

1. **Generate new token:**
   ```bash
   openssl rand -base64 45 | tr -d '\n'
   ```

2. **From existing installation:**
   ```bash
   grep AUTHENTIK_BOOTSTRAP_TOKEN ~/authentik/.env
   ```

**Rotation/Renewal:**
- Only used on first boot
- To create new API tokens: Authentik admin UI → Directory → Tokens → Create
- Or via `ak shell`: create a Token object with `intent=TokenIntents.INTENT_API`

---

### OIDC Client Credentials (Portainer, etc.)

**Location:** Authentik database (not in file backups)
**Purpose:** OAuth2/OIDC client ID and secret for apps using native OIDC (e.g., Portainer)
**Format:** Client ID (40 chars alphanumeric), Client Secret (128 chars alphanumeric)

**How to Source:**
- These are generated by Authentik when creating OAuth2 providers
- View in Authentik admin UI: Applications → Providers → portainer-oidc
- Or via API: `GET /api/v3/providers/oauth2/`

**Important:** After a fresh Authentik deployment, you must recreate OIDC providers and update the client credentials in each app (Portainer settings, etc.)

**Restoration Steps:**
1. Deploy Authentik (Step 5.5 in RESTORE.md)
2. Create proxy providers (homelab-forward-auth, semesmieh-forward-auth)
3. Create OAuth2 providers (portainer-oidc) — note the generated client ID/secret
4. Configure Portainer with new OIDC credentials via its API or UI

---

## Secret Injection Procedures

### Automated Injection (Using Restore Compose)

The restore compose stack can automatically rehydrate secrets if you prepare a `.env.secrets` file:

1. **Create `.env.secrets` in backup repository root:**
   ```bash
   cat > .env.secrets << 'EOF'
   # Plex
   PLEX_ONLINE_TOKEN=your_plex_token_here
   PLEX_ONLINE_USERNAME=your_plex_email@example.com
   
   # Tautulli
   TAUTULLI_API_KEY=your_tautulli_api_key
   TAUTULLI_PASSWORD=your_tautulli_password
   
   # Pi-hole
   PIHOLE_PASSWORD=your_pihole_password
   
   # Authentik
   AUTHENTIK_SECRET_KEY=your_authentik_secret_key
   AUTHENTIK_PG_PASS=your_pg_password
   AUTHENTIK_BOOTSTRAP_PASSWORD=your_bootstrap_password
   AUTHENTIK_BOOTSTRAP_TOKEN=your_bootstrap_token
   
   # (Add others as needed)
   EOF
   chmod 600 .env.secrets
   ```

2. **Source during restore:**
   ```bash
   source .env.secrets
   docker compose -f restore/docker-compose.restore.yml run --rm \
     -e PLEX_ONLINE_TOKEN="$PLEX_ONLINE_TOKEN" \
     -e TAUTULLI_API_KEY="$TAUTULLI_API_KEY" \
     restore-configs
   ```

3. **Inject secrets into configs:**
   - Use `sed` to replace `REDACTED` placeholders:
     ```bash
     sed -i "s/PlexOnlineToken=\"REDACTED\"/PlexOnlineToken=\"$PLEX_ONLINE_TOKEN\"/" \
       configs/plex/config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml
     ```

### Manual Injection (File Editing)

1. **List all redacted values:**
   ```bash
   grep -rn "REDACTED" configs/
   ```

2. **Edit files to inject secrets:**
   ```bash
   # Example: Edit Plex Preferences.xml
   vim configs/plex/config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml
   # Find: PlexOnlineToken="REDACTED" → Replace with actual token
   
   # Example: Edit services.yaml
   vim configs/homepage/config/services.yaml
   # Find all "key: REDACTED" and "password: REDACTED" → Replace with actual values
   ```

3. **Verify before restore:**
   ```bash
   grep -rn "REDACTED" configs/ && echo "ERROR: Still contains REDACTED values" || echo "OK: All secrets injected"
   ```

4. **Run restore:**
   ```bash
   docker compose -f restore/docker-compose.restore.yml run --rm \
     -e DRY_RUN=false -e OVERWRITE=true restore-configs
   ```

---

## Security Best Practices

1. **Never commit unredacted secrets to git**
   - Always run `./scripts/scan-secrets.sh` before committing
   - Use `.env.secrets` locally only (add to `.gitignore`)

2. **Rotate secrets periodically**
   - API keys: quarterly or biannually
   - Passwords: annually or after suspected compromise
   - TLS certs: before expiry (check with `openssl x509 -enddate`)

3. **Secure secret storage**
   - Store `.env.secrets` file locally only (never in git)
   - Use file permissions: `chmod 600 .env.secrets`
   - Consider encrypted secrets manager for production (e.g., Vault, 1Password)

4. **Validate secrets after injection**
   - Test service connectivity after rehydration
   - Check logs for authentication errors: `docker compose logs <service>`

---

## References

- [OpenSSL Certificate Management](https://www.openssl.org/docs/manmaster/man1/openssl-req.html)
- [Plex Server Remote Access](https://support.plex.tv/articles/200289496/)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Traefik SSL/TLS Configuration](https://doc.traefik.io/traefik/https/overview/)
- [Home Assistant API Authentication](https://developers.home-assistant.io/docs/auth_api_tutorial)
- [Authentik Configuration](https://docs.goauthentik.io/docs/installation/configuration)
