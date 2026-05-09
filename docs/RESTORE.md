# Disaster Recovery: Restore Procedure

This document describes how to restore the homelab from this backup repository after a catastrophic failure or on a fresh host.

**Table of Contents:**
- [Prerequisites](#prerequisites)
- [Step 1: Host Preparation](#step-1-host-preparation)
- [Step 2: Repository Setup](#step-2-repository-setup)
- [Step 3: Secret Rehydration](#step-3-secret-rehydration)
- [Step 4: Restore Configurations](#step-4-restore-configurations)
- [Step 5: Infrastructure Bring-up](#step-5-infrastructure-bring-up)
- [Step 6: Application Bring-up](#step-6-application-bring-up)
- [Step 7: System Validation](#step-7-system-validation)
- [Step 8: Enable Backup Automation](#step-8-enable-backup-automation)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting restore:

- **Host OS installed** with Docker and Docker Compose already installed (see [docs/FRESH-INSTALL.md](FRESH-INSTALL.md#2-docker-installation))
- **Network connectivity** to Internet (for pulling Docker images)
- **Backup repository cloned** to `~/homelab-backup`
- **Secrets catalog available** (see [docs/SECRETS.md](SECRETS.md))
- **Adequate storage** (minimum 50 GB free space, more if restoring media libraries)

---

## Step 1: Host Preparation

### 1.1 Install Docker & Docker Compose

If not already installed:

```bash
# Follow docs/FRESH-INSTALL.md section 2: Docker Installation
# or use official Docker docs: https://docs.docker.com/engine/install/
```

### 1.2 Configure Host Networking

```bash
# Verify network connectivity
ping -c 2 8.8.8.8  # Google DNS

# Set static IP (if not already done)
# Edit /etc/netplan/00-installer-config.yaml
# See docs/FRESH-INSTALL.md for details

# Set hostname
sudo hostnamectl set-hostname homelab

# Verify
hostname
```

### 1.3 Configure Firewall

```bash
# Enable UFW
sudo ufw enable

# Allow required ports
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP (Traefik)
sudo ufw allow 443/tcp     # HTTPS (Traefik)
sudo ufw allow 53/tcp      # DNS (Pi-hole)
sudo ufw allow 53/udp      # DNS (Pi-hole)

# Check rules
sudo ufw status
```

---

## Step 2: Repository Setup

### 2.1 Clone Repository

```bash
# Clone to home directory
cd ~
git clone https://github.com/AnasSemesmieh/homelab.git homelab-backup
cd homelab-backup

# Verify structure
ls -la
# Should contain: README.md, docs/, scripts/, restore/, configs/, inventory/

# View commit history
git log --oneline -n 5
```

### 2.2 Inspect Backup Contents

```bash
# List all backed-up files
cat inventory/include-paths.txt | head -20

# Count total files in backup
wc -l inventory/include-paths.txt

# View sample backed-up configs
find configs/ -name "docker-compose.*" | head -10
```

### 2.3 Restore from Specific Tag (Optional)

If you want to restore from a specific weekly snapshot rather than latest main:

```bash
# List available tags
git tag -l "backup-*"

# Checkout specific tag
git checkout tags/backup-2026-05-09

# Or restore to latest
git checkout main
```

---

## Step 3: Secret Rehydration

**Critical:** The backup repository contains `REDACTED` placeholders for all secrets. You must rehydrate them before bringing up services.

### 3.1 Gather All Required Secrets

**Reference:** See [docs/SECRETS.md](SECRETS.md) for detailed sourcing instructions for each secret.

Key secrets you'll need:

```
✓ Plex OnlineToken (from Plex account or existing installation)
✓ Plex OnlineUsername (your Plex email)
✓ Traefik TLS certificates (wildcard.crt, wildcard.key)
✓ Pi-hole admin password
✓ Tautulli API key
✓ Homepage widget API keys (Portainer, Traefik, etc.)
✓ Arr stack API keys (Prowlarr, Radarr, Sonarr)
✓ Immich database password
```

### 3.2 Create Local Secrets File

Create a local `.env.secrets` file (never commit to git):

```bash
# Create secrets file with all required values
cat > ~/.homelab-secrets.env << 'EOF'
# Plex
export PLEX_ONLINE_TOKEN="<paste-actual-token>"
export PLEX_ONLINE_USERNAME="your-email@example.com"

# Traefik TLS
export TRAEFIK_CERT_KEY="<paste-private-key-content>"
export TRAEFIK_CERT_CRT="<paste-certificate-content>"

# Pi-hole
export PIHOLE_PASSWORD="<your-admin-password>"

# Tautulli
export TAUTULLI_API_KEY="<your-api-key>"
export TAUTULLI_PASSWORD="<your-admin-password>"

# Portainer (Homepage widget)
export PORTAINER_KEY="ptr_<your-api-token>"
export PORTAINER_USERNAME="admin"
export PORTAINER_PASSWORD="<your-password>"

# Arr Stack
export PROWLARR_API_KEY="<your-key>"
export RADARR_API_KEY="<your-key>"
export SONARR_API_KEY="<your-key>"

# Immich
export IMMICH_DB_PASSWORD="<generate-strong-password>"
EOF

# Secure permissions
chmod 600 ~/.homelab-secrets.env
```

### 3.3 Inject Secrets into Backed-up Configs

```bash
# Source the secrets
source ~/.homelab-secrets.env

cd ~/homelab-backup

# Inject Plex token
sed -i "s|PlexOnlineToken=\"REDACTED\"|PlexOnlineToken=\"$PLEX_ONLINE_TOKEN\"|g" \
  configs/plex/config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml

# Inject Plex username
sed -i "s|PlexOnlineUsername=\"REDACTED\"|PlexOnlineUsername=\"$PLEX_ONLINE_USERNAME\"|g" \
  configs/plex/config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml

# Inject Tautulli credentials (use -i.bak to create backup)
sed -i.bak "s|key: REDACTED|key: $TAUTULLI_API_KEY|g" \
  configs/homepage/config/services.yaml

# Verify injections worked
echo "=== Verification ==="
grep "PlexOnlineToken=" configs/plex/config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml
grep "TAUTULLI_API_KEY\|key:" configs/homepage/config/services.yaml | head -3

# CRITICAL: Verify no REDACTED values remain (use grep, NOT redact script)
if grep -r "REDACTED" configs/ | grep -v ".git"; then
  echo "[ERROR] Still has REDACTED values!"
  exit 1
fi
```

### 3.4 Create Missing .env Files

Some services require `.env` files not stored in git:

```bash
# Immich .env
mkdir -p ~/immich
cat > ~/immich/.env << 'EOF'
UPLOAD_LOCATION=./library
DB_PASSWORD=$IMMICH_DB_PASSWORD
DB_USERNAME=postgres
DB_NAME=immich
DB_URL=postgresql://postgres:${DB_PASSWORD}@immich-db:5432/${DB_NAME}
EOF

# Home Assistant secrets.yaml (example)
mkdir -p ~/homeassistant/config
cat > ~/homeassistant/config/secrets.yaml << 'EOF'
# Home Assistant will auto-generate this on first run
EOF
```

---

## Step 4: Restore Configurations

### 4.1 Dry-run (Preview Without Changes)

```bash
cd ~/homelab-backup/restore

# Preview what will be copied
docker compose -f docker-compose.restore.yml run --rm \
  -e DRY_RUN=true restore-configs

# Review output carefully
# Should show files to be copied to ~/
```

**✓ Validation Checkpoint:** Review dry-run output. Should list files like:
```
Copying: traefik/docker-compose.yml → /home/anas/traefik/
Copying: pihole/docker-compose.yml → /home/anas/pihole/
Copying: plex/docker-compose.yml → /home/anas/plex/
...
```

### 4.2 Apply Restore (No Overwrite)

```bash
# Apply restore without overwriting existing files
docker compose -f docker-compose.restore.yml run --rm \
  -e DRY_RUN=false -e OVERWRITE=false restore-configs

# Monitor output for errors
```

**✓ Validation Checkpoint:** Should show:
```
Restore complete. X files copied, Y skipped.
```

### 4.3 Verify Restored Files

```bash
# Check critical files exist
ls -la ~/traefik/docker-compose.yml
ls -la ~/pihole/docker-compose.yml
ls -la ~/plex/docker-compose.yml
ls -la ~/homepage/config/services.yaml

# Check file ownership/permissions
ls -la ~/ | grep -E "traefik|pihole|plex"
```

---

## Step 5: Infrastructure Bring-up

Bring up infrastructure services first (Traefik, Pi-hole) before applications.

### 5.1 Prepare Traefik TLS Certificates

```bash
# Check if certs exist
ls -la ~/traefik/certs/

# If certs not in backup, create new CA and certificate
# (See docs/FRESH-INSTALL.md Step 5.2 for full instructions)
mkdir -p ~/traefik/certs
cd ~/traefik/certs

# Generate CA
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
  -subj "/CN=Homelab Local CA"

# Generate wildcard certificate
openssl genrsa -out wildcard.key 2048
openssl req -new -key wildcard.key -out wildcard.csr \
  -subj "/CN=*.homelab"

# Sign certificate
openssl x509 -req -in wildcard.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out wildcard.crt -days 3650 \
  -extfile <(printf "subjectAltName=DNS:*.homelab,DNS:homelab")

rm wildcard.csr ca.srl

# Verify certificate
openssl x509 -in wildcard.crt -text -noout | grep -E "Subject|Issuer|Not After"
```

### 5.2 Start Traefik

```bash
cd ~/traefik
docker compose up -d

# Wait for startup
sleep 5

# Check logs
docker compose logs traefik | head -20

# Verify health
curl -i http://localhost:8080/ping
```

**✓ Validation Checkpoint:** Should show HTTP 200 OK response.

### 5.3 Start Pi-hole

```bash
cd ~/pihole
docker compose up -d

# Wait for startup
sleep 10

# Check logs for admin password
docker compose logs pihole | grep -i "password"
```

**✓ Validation Checkpoint:** Should see "password" output in logs (if first run).

### 5.4 Configure Local DNS

```bash
# On your router or client machines, set primary DNS to homelab host IP
# Or test locally:
nslookup traefik.homelab 127.0.0.1

# Should resolve to home lab IP
```

**✓ Validation Checkpoint:** DNS queries should resolve to correct IP.

---

## Step 6: Application Bring-up

### 6.1 Homepage (Dashboard)

```bash
cd ~/homepage
docker compose up -d
sleep 5
docker compose ps
```

**Test:** Access http://homepage.homelab (or use localhost:3000)

### 6.2 Plex Media Server

```bash
cd ~/plex
docker compose up -d

# First start takes 1-2 minutes
sleep 30
docker compose logs plex | grep -E "listening|starting"
```

**Test:** Access http://plex.homelab:32400 or https://plex.homelab

**✓ Validation Checkpoint:** Plex should bind to your online account (check logs for token validation).

### 6.3 Arr Stack (Media Pipeline)

```bash
cd ~/arrstack
docker compose up -d

# Wait for all services
sleep 15
docker compose ps
```

**Test:** Access Radarr, Sonarr, Prowlarr at their respective URLs

### 6.4 Tautulli (Plex Monitoring)

```bash
cd ~/tautulli
docker compose up -d
sleep 5
docker compose ps
```

**Test:** Access http://tautulli.homelab:8181

### 6.5 Immich (Photo Backup)

```bash
cd ~/immich
docker compose up -d

# Wait (database initialization takes longer)
sleep 30
docker compose ps
```

**Test:** Access http://immich.homelab:3001

### 6.6 Home Assistant (Automation)

```bash
cd ~/homeassistant
docker compose up -d

# First start is slow
sleep 20
docker compose logs homeassistant | tail -5
```

**Test:** Access http://homeassistant.homelab:8123

---

## Step 7: System Validation

### 7.1 Container Health

```bash
# Check all containers running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Should show all expected services with "Up" status

# Check for any container errors
docker ps -a | grep -v "Up"
```

### 7.2 Service Connectivity

```bash
# Test inter-service communication
docker exec traefik nslookup pihole
docker exec traefik nslookup homepage
docker exec homepage curl -s http://traefik:8080/ping

# All should return success
```

### 7.3 Dashboard & Widgets

```bash
# Verify Homepage loads and widgets work
curl -s http://homepage.homelab | head -50

# Verify Glances metrics available
curl -s http://glances:61208/api/3/all | jq .

# Verify Traefik dashboard accessible
curl -i https://traefik.homelab/dashboard/
```

### 7.4 Backup Automation Test

```bash
# Test manual backup run
cd ~/homelab-backup
./scripts/sync-configs.sh
./scripts/redact-secrets.sh
./scripts/scan-secrets.sh

# Should complete without errors
# Verify no secrets leaked
echo "[✓] Backup scripts working"
```

---

## Step 8: Enable Backup Automation

### 8.1 Install Cron Jobs

```bash
# Edit crontab
crontab -e

# Add these lines:
# Daily backup at 03:25 UTC
25 3 * * * cd /home/anas/homelab-backup && ./scripts/backup-and-push.sh >> /home/anas/homelab-backup/backup-cron.log 2>&1

# Weekly snapshot tag at 03:40 UTC (Sunday)
40 3 * * 0 cd /home/anas/homelab-backup && ./scripts/weekly-tag.sh >> /home/anas/homelab-backup/backup-weekly.log 2>&1
```

### 8.2 Verify Cron Installation

```bash
# List installed cron jobs
crontab -l

# Should show both entries
```

### 8.3 Configure SSH for Git Push

```bash
# If using HTTPS URL, switch to SSH (for passwordless push from cron)
cd ~/homelab-backup
git remote set-url origin git@github.com:AnasSemesmieh/homelab.git

# Verify SSH connection
ssh -T git@github.com
# Should show: "Hi <username>! You've successfully authenticated..."
```

### 8.4 Test First Backup Run

```bash
# Run backup manually
cd ~/homelab-backup
./scripts/backup-and-push.sh

# Monitor logs
tail -20 backup-cron.log

# Verify changes pushed to GitHub
git log --oneline -n 3
```

**✓ Validation Checkpoint:** Should see "Sent successfully to origin/main" in logs.

---

## Troubleshooting

### Issue: Services Can't Reach Each Other (DNS Resolution Fails)

**Symptoms:**
- Traefik logs: "dial tcp: lookup servicename: no such host"
- Homepage widgets show connection errors

**Diagnosis:**
```bash
# Test DNS from Traefik container
docker exec traefik nslookup pihole
docker exec traefik cat /etc/resolv.conf
```

**Solutions:**
1. Verify Pi-hole is running: `docker ps | grep pihole`
2. Check Docker network: `docker network ls` and `docker network inspect <network-name>`
3. Restart Traefik: `docker compose -f ~/traefik/docker-compose.yml restart traefik`

**Reference:** [Docker Networking Guide](https://docs.docker.com/network/)

---

### Issue: Certificate Verification Errors (HTTPS)

**Symptoms:**
- Browser: "ERR_CERT_AUTHORITY_INVALID"
- curl: "certificate verify failed"

**Diagnosis:**
```bash
# Check certificate existence
ls -la ~/traefik/certs/

# Check certificate expiry
openssl x509 -enddate -noout -in ~/traefik/certs/wildcard.crt
```

**Solutions:**
1. Trust CA certificate on client:
   ```bash
   # Linux
   sudo cp ~/traefik/certs/ca.crt /usr/local/share/ca-certificates/
   sudo update-ca-certificates
   
   # Mac
   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/traefik/certs/ca.crt
   ```

2. Regenerate certificates if expired (see [docs/SECRETS.md#traefik-tls-certificates](SECRETS.md#traefik-tls-certificates))

---

### Issue: Plex Authentication Token Invalid

**Symptoms:**
- Plex logs: "PlexOnlineToken is invalid"
- Plex not accessible remotely

**Diagnosis:**
```bash
# Check token in Preferences.xml
grep PlexOnlineToken ~/plex/config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml
```

**Solutions:**
1. Regenerate token from Plex account: https://app.plex.tv/desktop/settings/account
2. Update Preferences.xml with new token
3. Restart Plex: `docker compose -f ~/plex/docker-compose.yml restart plex`

**Reference:** [docs/SECRETS.md#plexonlinetoken](SECRETS.md#plexonlinetoken)

---

### Issue: Arr Services Can't Connect to Prowlarr

**Symptoms:**
- Radarr/Sonarr: "Cannot complete this task. Connection to Prowlarr failed"
- Logs show connection timeouts

**Diagnosis:**
```bash
# Check all containers running
docker compose -f ~/arrstack/docker-compose.yml ps

# Test connectivity
docker exec radarr curl -s http://prowlarr:9696/api/v1/config/baseUrl
```

**Solutions:**
1. Verify API keys match in all services: `grep -E "<ApiKey>" ~/arrstack/*/config.xml`
2. Ensure Prowlarr URL is correct: `http://prowlarr:9696` (not localhost or IP)
3. Restart service: `docker compose -f ~/arrstack/docker-compose.yml restart radarr sonarr`

---

### Issue: Backup Automation Not Running

**Symptoms:**
- `backup-cron.log` not updated
- Cron doesn't execute at scheduled time

**Diagnosis:**
```bash
# Check cron installation
crontab -l

# Check system cron logs
sudo grep CRON /var/log/syslog | tail -10

# Check if scripts executable
ls -la ~/homelab-backup/scripts/*.sh
```

**Solutions:**
1. Make scripts executable: `chmod +x ~/homelab-backup/scripts/*.sh`
2. Restart cron service: `sudo systemctl restart cron`
3. Run manually to test: `cd ~/homelab-backup && ./scripts/backup-and-push.sh`

**Reference:** [docs/BACKUP-AUTOMATION.md#troubleshooting](BACKUP-AUTOMATION.md#troubleshooting)

---

### Issue: Git Push Fails ("fatal: not a git repository")

**Symptoms:**
- Cron backup fails with Git error
- Works manually but fails in cron job

**Diagnosis:**
```bash
# Check cron environment
env | grep -i path

# Check git remote
cd ~/homelab-backup && git remote -v
```

**Solutions:**
1. Use full path in crontab: `cd /home/anas/homelab-backup && ./scripts/backup-and-push.sh`
2. Switch to SSH URL: `git remote set-url origin git@github.com:AnasSemesmieh/homelab.git`
3. Ensure SSH key is available to cron (may need ssh-agent)

---

## Rollback & Recovery

### Rollback to Previous Commit

```bash
# View recent commits
cd ~/homelab-backup
git log --oneline -n 10

# Revert specific commit
git revert <commit-hash>
git push origin main

# Or reset to previous state (rewrites history!)
git reset --hard <commit-hash>
git push origin main --force
```

### Restore from Weekly Snapshot Tag

```bash
# List available snapshots
cd ~/homelab-backup
git tag -l "backup-*"

# Checkout specific snapshot
git checkout tags/backup-2026-05-09

# Restore configs from this snapshot
docker compose -f restore/docker-compose.restore.yml run --rm \
  -e DRY_RUN=false -e OVERWRITE=true restore-configs

# Return to main branch
git checkout main
```

---

## References

- [docs/SECRETS.md](SECRETS.md) — Secret sourcing and rotation
- [docs/BACKUP-AUTOMATION.md](BACKUP-AUTOMATION.md) — Backup process details
- [docs/FRESH-INSTALL.md](FRESH-INSTALL.md) — Full bootstrapping guide
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Git Recovery Guide](https://git-scm.com/book/en/v2/Git-Tools-Reset-Demystified)
