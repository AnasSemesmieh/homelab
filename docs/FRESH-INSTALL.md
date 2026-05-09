# Fresh Install Guide

This document describes how to bootstrap a complete homelab from scratch using this backup repository.

**Table of Contents:**
- [1. Host OS Setup](#1-host-os-setup)
- [2. Docker Installation](#2-docker-installation)
- [3. Repository Setup](#3-repository-setup)
- [4. Secrets Rehydration](#4-secrets-rehydration)
- [5. Infrastructure Bring-up](#5-infrastructure-bring-up)
- [6. Application Bring-up](#6-application-bring-up)
- [7. Validation & Troubleshooting](#7-validation--troubleshooting)

---

## 1. Host OS Setup

### Prerequisites

- **Physical host or VM** running Linux (Ubuntu 20.04 LTS or newer recommended)
- **Network connectivity** (internet access for package downloads)
- **User account** with `sudo` privileges
- **Static IP address** (recommended for DNS/DHCP stability)
- **Storage:** Minimum 50 GB free space (adjust for media library size)

### 1.1 Install Ubuntu Linux

If starting from bare metal:

1. Download Ubuntu Server ISO: https://ubuntu.com/download/server
2. Boot from USB and install to disk
3. Choose server installation profile (minimal packages)
4. During install, set:
   - Hostname: `homelab` (or your preferred name)
   - Username: `anas` (or your preferred username; adjust paths in this guide accordingly)
   - Static IP: Configure with your preferred IP (e.g., `192.168.1.10`)

**Reference:** [Ubuntu Server Installation Guide](https://ubuntu.com/server/docs/installation)

### 1.2 Post-Install System Setup

```bash
# SSH into the host
ssh anas@homelab

# Update system packages
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

# Install essential tools
sudo apt install -y \
  curl \
  wget \
  git \
  jq \
  net-tools \
  htop \
  vim

# Set up system time (NTP)
sudo timedatectl set-timezone UTC
sudo systemctl restart systemd-timesyncd
timedatectl status
```

### 1.3 Configure Static IP and Hostname

If not set during installation:

```bash
# Check current network config
ip addr show

# Edit netplan config (Ubuntu 20.04+)
sudo vim /etc/netplan/00-installer-config.yaml
```

**Example netplan configuration:**
```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.10/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [192.168.1.1]
```

```bash
# Apply changes
sudo netplan apply

# Verify
ip addr show
ip route show
```

### 1.4 Configure Firewall (UFW)

```bash
# Enable UFW
sudo ufw enable

# Allow SSH (critical!)
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow DNS (if running Pi-hole)
sudo ufw allow 53/tcp
sudo ufw allow 53/udp

# Check rules
sudo ufw status
```

**Reference:** [Ubuntu UFW Firewall Guide](https://ubuntu.com/server/docs/security-firewall)

---

## 2. Docker Installation

### 2.1 Install Docker Engine

**Official Docker repository method (recommended):**

```bash
# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update and install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

**Reference:** [Docker Official Installation Guide](https://docs.docker.com/engine/install/ubuntu/)

### 2.2 Docker Group Setup

```bash
# Create docker group (usually already exists)
sudo groupadd docker 2>/dev/null || true

# Add current user to docker group (avoid sudo for docker commands)
sudo usermod -aG docker $USER

# Apply group membership (choose one):
# Option A: Log out and back in
# Option B: Activate group in current shell
newgrp docker

# Verify (should not require sudo)
docker ps
```

**Reference:** [Docker Post-Installation Steps](https://docs.docker.com/engine/install/linux-postinstall/)

### 2.3 Install Docker Compose

The plugin method above includes Docker Compose. Verify:

```bash
docker compose version
# Should output: Docker Compose version v2.x.x...
```

If you prefer the standalone binary:

```bash
# Download latest release
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
```

---

## 3. Repository Setup

### 3.1 Clone Backup Repository

```bash
# Clone to home directory
cd ~
git clone https://github.com/AnasSemesmieh/homelab.git homelab-backup
cd homelab-backup

# Verify structure
ls -la
# Should show: README.md, docs/, scripts/, restore/, configs/, inventory/
```

### 3.2 Inspect Inventory

```bash
# List all files that will be restored
cat inventory/include-paths.txt | head -20

# Count total files
wc -l inventory/include-paths.txt
```

---

## 4. Secrets Rehydration

### 4.1 Prepare Secrets File

Before restoring configs, you must rehydrate all redacted secrets.

**Reference:** See [docs/SECRETS.md](SECRETS.md) for detailed instructions on sourcing each secret.

Create a local secrets file (never commit to git):

```bash
# Create .env.secrets file in backup repo root
cat > ~/.homelab-secrets.env << 'EOF'
# Plex
export PLEX_ONLINE_TOKEN="<your-actual-plex-token>"
export PLEX_ONLINE_USERNAME="your-email@example.com"

# Pi-hole
export PIHOLE_PASSWORD="<your-pihole-admin-password>"

# Tautulli
export TAUTULLI_API_KEY="<your-tautulli-api-key>"
export TAUTULLI_PASSWORD="<your-tautulli-password>"

# Homepage Portainer
export PORTAINER_KEY="ptr_<your-portainer-api-token>"
export PORTAINER_USERNAME="admin"
export PORTAINER_PASSWORD="<your-portainer-password>"

# Homepage Traefik
export TRAEFIK_API_URL="http://traefik:8080"

# Immich
export IMMICH_DB_PASSWORD="<generate-strong-random-password>"

# Arr Stack APIs
export PROWLARR_API_KEY="<your-prowlarr-api-key>"
export RADARR_API_KEY="<your-radarr-api-key>"
export SONARR_API_KEY="<your-sonarr-api-key>"
EOF

# Secure permissions
chmod 600 ~/.homelab-secrets.env

# Source the file
source ~/.homelab-secrets.env
```

### 4.2 Inject Secrets into Config Files

```bash
# Navigate to backup repo
cd ~/homelab-backup

# List all redacted values to inject
echo "=== Scanning for REDACTED values ==="
grep -r "REDACTED" configs/ | head -20

# Inject Plex token
sed -i "s|PlexOnlineToken=\"REDACTED\"|PlexOnlineToken=\"$PLEX_ONLINE_TOKEN\"|g" \
  configs/plex/config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml

# Inject Plex username
sed -i "s|PlexOnlineUsername=\"REDACTED\"|PlexOnlineUsername=\"$PLEX_ONLINE_USERNAME\"|g" \
  configs/plex/config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml

# Inject Tautulli credentials into services.yaml
sed -i "s|key: REDACTED|key: $TAUTULLI_API_KEY|g" \
  configs/homepage/config/services.yaml
  
# Inject Pi-hole API into pihole.toml (if present)
sed -i "s|ADMIN_AUTH_SESSION = \"REDACTED\"|ADMIN_AUTH_SESSION = \"$PIHOLE_PASSWORD\"|g" \
  configs/pihole/etc-pihole/pihole.toml

# Verify all secrets injected
echo ""
echo "=== Verifying secrets injected ==="
if grep -r "REDACTED" configs/ | grep -v ".git"; then
  echo "[ERROR] Still has REDACTED values - check above"
  exit 1
else
  echo "[OK] All REDACTED placeholders replaced"
fi
```

**Security note:** Do NOT commit these injected files to git. The `.gitignore` should prevent this, but double-check:

```bash
git status
# Should show no staged changes to config files after injection
```

---

## 5. Infrastructure Bring-up

Bring up services in order of dependency (infrastructure first, then applications).

### 5.1 Restore Directory Structure

```bash
# The restore compose stack will copy files to ~/
docker compose -f restore/docker-compose.restore.yml run --rm \
  -e DRY_RUN=true restore-configs

# If output looks correct, apply for real
docker compose -f restore/docker-compose.restore.yml run --rm \
  -e DRY_RUN=false -e OVERWRITE=false restore-configs
```

This copies configs from `configs/` to the appropriate locations under `~/`:
- `~/traefik/docker-compose.yml`
- `~/pihole/docker-compose.yml`
- `~/plex/docker-compose.yml`
- etc.

### 5.2 Create Traefik Certificates

Before starting Traefik, ensure TLS certificates exist:

```bash
# Check if certs already copied
ls -la ~/traefik/certs/

# If missing, generate new local CA and wildcard cert
mkdir -p ~/traefik/certs
cd ~/traefik/certs

# Create CA
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
  -subj "/CN=Homelab Local CA"

# Create wildcard cert for *.homelab
openssl genrsa -out wildcard.key 2048
openssl req -new -key wildcard.key -out wildcard.csr \
  -subj "/CN=*.homelab"

# Self-sign with CA
openssl x509 -req -in wildcard.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out wildcard.crt -days 3650 \
  -extfile <(printf "subjectAltName=DNS:*.homelab,DNS:homelab")

# Cleanup
rm wildcard.csr ca.srl

# Verify
openssl x509 -in wildcard.crt -text -noout | grep -E "Subject:|Issuer:|Not After"
```

### 5.3 Start Traefik (Reverse Proxy)

```bash
cd ~/traefik

# Start Traefik
docker compose up -d

# Wait for startup
sleep 5

# Check logs
docker compose logs -f traefik | head -20
```

**Health check:**
```bash
# Should return HTTP 200
curl -k https://traefik.homelab/ping || curl -i http://localhost:8080/ping
```

### 5.4 Configure Local DNS (Pi-hole)

```bash
cd ~/pihole

# Create required directories
mkdir -p etc-dnsmasq.d
mkdir -p etc-pihole

# Start Pi-hole
docker compose up -d

# Wait for startup
sleep 10

# Check logs
docker compose logs pihole | grep -i "password\|listening"
```

**Initial setup:**
```bash
# Extract Pi-hole admin password from logs
docker compose logs pihole | grep -i "password"

# Access web UI (may fail if DNS not configured yet)
# Use direct IP: http://<host-ip>/admin
```

### 5.5 Configure Local DNS Resolution

On your local network, update DNS to point to Pi-hole host IP.

**Option A: On your router:**
- Router settings → DHCP/DNS
- Primary DNS: `<homelab-host-ip>`

**Option B: On individual machines (for testing):**

```bash
# On your client machine
# Edit /etc/hosts (Linux/Mac) or C:\Windows\System32\drivers\etc\hosts (Windows)
192.168.1.10 homelab traefik.homelab pihole.homelab plex.homelab homepage.homelab tautulli.homelab
```

**Verify DNS resolution:**
```bash
nslookup traefik.homelab 192.168.1.10
# Should resolve to 192.168.1.10
```

### 5.6 Health Check: Infrastructure

```bash
# Test Traefik
curl -k https://traefik.homelab/ping

# Test Pi-hole (may be HTTP only initially)
curl http://pihole.homelab/admin | head -20

# Docker status
docker ps | grep -E "traefik|pihole"
```

**Expected output:** Both containers running, status "healthy" or "up"

---

## 6. Application Bring-up

### 6.1 Start Homepage (Dashboard)

```bash
cd ~/homepage

# Create config directory
mkdir -p config

# Restore configs (already done by restore script, but verify)
ls -la config/

# Start Homepage
docker compose up -d

# Wait and check
sleep 5
docker compose logs homepage | head -15
```

**Verify:** Access https://homepage.homelab (or http://homepage.homelab if not using HTTPS yet)

### 6.2 Start Plex Media Server

```bash
cd ~/plex

# Create directories
mkdir -p config transcode
mkdir -p ~/plex/config/Library/Application\ Support/Plex\ Media\ Server

# Restore Plex config (already done by restore script, but verify)
ls -la config/Library/Application\ Support/Plex\ Media\ Server/

# Start Plex
docker compose up -d

# First start may take 1-2 minutes
sleep 10
docker compose logs plex | grep -E "listening|starting"

# Keep checking
docker ps | grep plex
```

**Note:** Plex may need to bind to your Plex account on first login. See [docs/SECRETS.md#PlexOnlineToken](SECRETS.md#plexonlinetoken).

### 6.3 Start Arr Stack (Media Acquisition Pipeline)

```bash
cd ~/arrstack

# Create directories (setup script may do this)
bash setup-folders.sh

# Restore compose file
ls -la docker-compose.yml

# Start stack
docker compose up -d

# Wait for all services
sleep 15
docker compose ps
```

**Services brought up:**
- qBittorrent (torrent client)
- Prowlarr (indexer aggregator)
- Radarr (movie automation)
- Sonarr (TV automation)

### 6.4 Start Tautulli (Plex Monitoring)

```bash
cd ~/tautulli

# Start service
docker compose up -d

# Wait
sleep 5

# Check logs
docker compose logs tautulli | head -15
```

**Access:** https://tautulli.homelab or http://tautulli.homelab:8181

### 6.5 Start Immich (Photo Backup)

```bash
cd ~/immich

# Create required directories
mkdir -p postgres

# Create .env file with database password (see docs/SECRETS.md)
cat > .env << 'EOF'
UPLOAD_LOCATION=./library
DB_PASSWORD=<generate-strong-password>
DB_USERNAME=postgres
DB_NAME=immich
DB_URL=postgresql://postgres:${DB_PASSWORD}@immich-db:5432/${DB_NAME}
EOF
chmod 600 .env

# Start stack
docker compose up -d

# Wait (Immich needs database initialization)
sleep 20
docker compose ps
```

**Note:** First startup takes longer due to database initialization.

### 6.6 Start Home Assistant (Automation Hub)

```bash
cd ~/homeassistant

# Create config directory
mkdir -p config

# Restore configs (already done by restore script, but verify)
ls -la config/

# Start Home Assistant
docker compose up -d

# Wait (first start is slow)
sleep 15
docker compose logs homeassistant | tail -20
```

**Access:** https://homeassistant.homelab or http://homeassistant.homelab:8123

---

## 7. Validation & Troubleshooting

### 7.1 Service Health Checks

**Simple checks:**
```bash
# All containers running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check for errors
docker compose logs --tail=5 traefik pihole homepage plex

# Verify network connectivity between services
docker exec traefik ping -c 2 pihole
docker exec homepage curl -s http://traefik:8080/ping
```

**Traefik routing:**
```bash
# List active routes
curl -s http://traefik:8080/api/http/routers | jq '.[] | {name: .name, service: .service}'

# Check service health
curl -s http://traefik:8080/api/http/services | jq '.[] | {name: .name, servers: .loadBalancer.servers}'
```

**DNS resolution:**
```bash
# From traefik container
docker exec traefik nslookup pihole
docker exec traefik nslookup homepage.homelab

# Check Pi-hole statistics
curl -s http://pihole:80/admin/api.php?getQueryTypes | jq .
```

### 7.2 Common Issues & Resolution

#### Issue: Services can't reach each other (DNS fails)

**Symptoms:**
- Traefik logs show "dial tcp: lookup servicename on x.x.x.x: no such host"
- Homepage widgets show "connection refused"

**Solutions:**
1. Verify Pi-hole is running: `docker ps | grep pihole`
2. Check Docker network: `docker network ls` and `docker network inspect homelab` (if using custom network)
3. Verify service names match routing config: `cat ~/traefik/dynamic/*.yaml | grep "serviceName"`
4. Try direct container names: `docker exec traefik ping pihole` (no `.homelab` suffix)

**Reference:** [Docker Networking Guide](https://docs.docker.com/network/)

#### Issue: HTTPS certificates not trusted

**Symptoms:**
- Browser shows "ERR_CERT_AUTHORITY_INVALID"
- curl fails: "certificate verify failed"

**Solutions:**
1. Verify certificate exists: `ls -la ~/traefik/certs/`
2. Check certificate expiry: `openssl x509 -enddate -noout -in ~/traefik/certs/wildcard.crt`
3. Trust certificate on client machine:
   - Linux: `sudo cp ~/traefik/certs/ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates`
   - Mac: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/traefik/certs/ca.crt`
   - Windows: Open certificate file → Install → Trusted Root Certification Authorities

#### Issue: Plex remote access not working

**Symptoms:**
- Plex app shows "Unavailable outside your network"
- Remote users can't connect

**Solutions:**
1. Verify Plex token: `grep PlexOnlineToken= ~/plex/config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml`
2. Check Plex logs: `docker compose -f ~/plex/docker-compose.yml logs plex | grep -i "remote\|token"`
3. Ensure router port forwarding is enabled for port 32400 (if needed)
4. Force remote access refresh: Plex web UI → Settings → Remote Access → Restart Remote Access

#### Issue: Arr services can't reach each other

**Symptoms:**
- Radarr can't find Prowlarr
- Sonarr shows "Cannot complete this task. Connection to Prowlarr failed."

**Solutions:**
1. Verify all containers running: `docker compose -f ~/arrstack/docker-compose.yml ps`
2. Check API keys: `grep -E "^<ApiKey>" ~/arrstack/{radarr,sonarr,prowlarr}/config.xml`
3. Verify service URLs are correct:
   - Radarr → Settings → Indexers → Prowlarr → URL should be `http://prowlarr:9696`
   - Sonarr → Settings → Indexers → Prowlarr → URL should be `http://prowlarr:9696`
4. Test connectivity: `docker exec radarr curl -s http://prowlarr:9696/api/v1/config/baseUrl`

#### Issue: Backup automation not running

**Symptoms:**
- Cron job doesn't execute
- `backup-cron.log` not updated

**Solutions:**
1. Check cron installation: `crontab -l`
2. Check system logs: `grep CRON /var/log/syslog | tail -10`
3. Ensure script is executable: `chmod +x ~/homelab-backup/scripts/backup-and-push.sh`
4. Run manually to check for errors: `cd ~/homelab-backup && ./scripts/backup-and-push.sh`
5. Check git credentials: `cd ~/homelab-backup && git status` (may fail if SSH key not configured)

### 7.3 Rollback Procedures

#### Rollback: Service Configuration

```bash
# If a config change breaks a service:

# 1. Stop affected service
docker compose -f ~/<service>/docker-compose.yml down

# 2. Restore config from backup repo
cp ~/homelab-backup/configs/<service>/config.file ~/
<service>/config.file

# 3. Restart service
docker compose -f ~/<service>/docker-compose.yml up -d

# 4. Verify
docker compose -f ~/<service>/docker-compose.yml logs
```

#### Rollback: Database State (for stateful services like Immich)

```bash
# If database becomes corrupted:

# 1. Stop Immich
docker compose -f ~/immich/docker-compose.yml down

# 2. Backup current database
docker run --rm -v immich_postgres_data:/data -v ~/backups:/backup \
  alpine tar czf /backup/immich-db-backup-$(date +%s).tar.gz /data

# 3. Drop and recreate database (WARNING: data loss!)
docker compose -f ~/immich/docker-compose.yml up -d immich-db
sleep 10
docker compose -f ~/immich/docker-compose.yml exec -T immich-db \
  psql -U postgres -c "DROP DATABASE immich;"

# 4. Restart Immich (will recreate database from scratch)
docker compose -f ~/immich/docker-compose.yml down
docker compose -f ~/immich/docker-compose.yml up -d
```

#### Rollback: Git Repository

```bash
# If you've made bad commits:

# View history
cd ~/homelab-backup
git log --oneline -n 10

# Revert specific commit
git revert <commit-hash>
git push origin main

# Or reset to previous state (WARNING: rewrites history!)
git reset --hard <commit-hash>
git push origin main --force
```

**Reference:** [Git Reset vs Revert](https://git-scm.com/book/en/v2/Git-Tools-Reset-Demystified)

---

## Next Steps

1. **Complete Setup:**
   - Set up user accounts in each service (Homepage, Plex, Arr stack, etc.)
   - Configure media library paths in Radarr/Sonarr
   - Add indexers to Prowlarr
   - Set up Immich galleries

2. **Enable Backup Automation:**
   - Install cron jobs: See [docs/BACKUP-AUTOMATION.md](BACKUP-AUTOMATION.md)
   - Verify first run: `tail -f ~/homelab-backup/backup-cron.log`

3. **Monitor System Health:**
   - Access Glances WebUI: http://glances.homelab
   - Monitor Plex usage in Tautulli: http://tautulli.homelab
   - Check Traefik dashboard: https://traefik.homelab/dashboard/

4. **Secure Your Setup:**
   - Enable UFW rules for each service
   - Rotate API keys quarterly (see [docs/SECRETS.md](SECRETS.md))
   - Backup TLS certificates separately
   - Store `.env.secrets` file securely (not in git!)

---

## Troubleshooting Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Traefik Documentation](https://doc.traefik.io/)
- [Ubuntu Server Documentation](https://ubuntu.com/server/docs)
- [Pi-hole Documentation](https://docs.pi-hole.net/)

For service-specific troubleshooting, see individual documentation links in each service's README.
