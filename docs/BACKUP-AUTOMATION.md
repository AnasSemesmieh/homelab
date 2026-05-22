# Backup Automation

This document explains how the daily and weekly backup automation works, how to set it up, and how to troubleshoot failures.

**Table of Contents:**
- [Backup Process Overview](#backup-process-overview)
- [Setup Instructions](#setup-instructions)
- [Monitoring & Logs](#monitoring--logs)
- [Troubleshooting](#troubleshooting)
- [Restore Compose Stack](#restore-compose-stack)

---

## Backup Process Overview

The backup system captures configuration snapshots automatically via cron jobs.

### Daily Backup Workflow

**Time:** 03:25 UTC (daily)  
**Command:** `./scripts/backup-and-push.sh`  
**Actions:**

1. **Sync** — Copy allowlisted files from `~` into `configs/` via `sync-configs.sh`
   - Reads include-paths.txt to determine what to backup
   - Preserves directory structure
   - Skips runtime files (logs, databases, media)

2. **Redact** — Remove sensitive values via `redact-secrets.sh`
   - Replaces passwords, API keys, tokens with `REDACTED`
   - Uses regex patterns and specific service rules
   - See [docs/SECRETS.md](SECRETS.md) for full pattern list

3. **Scan** — Detect unredacted secrets via `scan-secrets.sh`
   - Searches for common secret patterns
   - Fails if high-risk values found (exits with error code 1)
   - Prevents accidental commit of unredacted secrets

4. **Commit** — Stage and commit changes
   - `git add .`
   - `git commit -m "backup: sync homelab configs"`
   - Only commits if there are changes

5. **Pull & Rebase** — Sync with remote before push
   - `git pull --rebase origin main`
   - Ensures linear history
   - Fails safely if conflicts exist (manual intervention needed)

6. **Push** — Upload to GitHub
   - `git push origin main`
   - Updates remote repository with new snapshot

### Weekly Backup Snapshot Tags

**Time:** Sunday 03:40 UTC (weekly)  
**Command:** `./scripts/weekly-tag.sh`  
**Actions:**

1. **Run daily backup** — Ensures latest configs are synced
2. **Create tag** — Generate dated tag: `backup-YYYY-MM-DD`
3. **Push tag** — Upload to remote: `git push origin backup-YYYY-MM-DD`

**Purpose:** Create restore points for significant moments (e.g., `backup-2026-05-09`)

### Script Details

#### sync-configs.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${REPO_ROOT}/configs"

# Copy files from ~ matching inventory/include-paths.txt
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  
  src="$HOME/$line"
  dst="$TARGET/$line"
  
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  fi
done < "${REPO_ROOT}/inventory/include-paths.txt"

echo "Sync complete"
```

**Inventory format:**
```
traefik/docker-compose.yml
pihole/docker-compose.yml
plex/config/Library/Application Support/Plex Media Server/Preferences.xml
# Comments are skipped
```

#### redact-secrets.sh

Uses `sed` to replace sensitive patterns in tracked files:

```bash
# Generic patterns (case-insensitive)
password, passwd, api_key, api-key, token, secret, client_secret, passkey

# Service-specific patterns
PlexOnlineToken, PlexOnlineUsername, PlexOnlineMail
tskey-api-* (Tailscale)
ptr_* (Portainer)
cfat_* (specific tokens)
```

All matches replaced with `REDACTED` placeholder.

#### scan-secrets.sh

Inverse pattern matching — searches for values that were NOT redacted:

```bash
grep -RInE '(password|api_?key|token|secret)[[:space:]]*[:=][[:space:]]*[^#[:space:]]+' configs/
```

If any matches found, exits with error code 1 (prevents push).

#### backup-and-push.sh

Orchestrates the entire daily backup:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Run pipeline
./scripts/sync-configs.sh
./scripts/redact-secrets.sh
./scripts/scan-secrets.sh

# Git operations
if git status --porcelain | grep -q .; then
  git add .
  git commit -m "backup: sync homelab configs"
fi

git pull --rebase origin main
git push origin main
```

---

## Vaultwarden Database Backup

In addition to the config-file backup pipeline above, Vaultwarden has its own dedicated backup job that safely syncs the live SQLite database and attachments to the NAS every night.

### Schedule

**Time:** 03:00 UTC (daily — runs before the config backup at 03:25)  
**Cron entry:**
```bash
0 3 * * * /home/anas/vaultwarden/backup-to-nas.sh >> /home/anas/vaultwarden/backup.log 2>&1
```

### How It Works

1. **Safe SQLite snapshot** — Calls `docker exec vaultwarden /vaultwarden backup` which uses SQLite's built-in backup API to produce a consistent `db_YYYYMMDD_HHMMSS.sqlite3` file (no WAL corruption risk).
2. **Clean NAS destination** — Removes any stale `-wal` / `-shm` files on the NAS mount to prevent SQLite from replaying an old journal.
3. **Copy database** — Places the clean backup as `db.sqlite3` on the NAS.
4. **Rsync attachments & config** — Syncs everything else (attachments, `config.json`, RSA keys) while excluding database files and the icon cache.
5. **Cleanup** — Removes the timestamped backup file from the local host.

### NAS Active Standby

The NAS holds a ready-to-run Vaultwarden instance (`docker-compose.nas-standby.yml`). To failover:

1. Start the container on the NAS: `docker compose -f docker-compose.nas-standby.yml up -d`
2. Update the Cloudflare Tunnel to route `vault.semesmieh.com` to the NAS IP.

Data is at most 24 hours stale (last nightly sync).

### Script Location

See [`configs/vaultwarden/backup-to-nas.sh`](../configs/vaultwarden/backup-to-nas.sh) for the full script.

---

## Setup Instructions

### 1. Install Cron Jobs on Host

Run this as the user who owns the homelab (e.g., `anas`):

```bash
# Edit crontab
crontab -e

# Add these lines:
# Daily backup at 03:25 UTC
25 3 * * * cd /home/anas/homelab-backup && ./scripts/backup-and-push.sh >> /home/anas/homelab-backup/backup-cron.log 2>&1

# Weekly snapshot tag at 03:40 UTC (Sunday)
40 3 * * 0 cd /home/anas/homelab-backup && ./scripts/weekly-tag.sh >> /home/anas/homelab-backup/backup-weekly.log 2>&1
```

**Verify installation:**
```bash
crontab -l
# Should show both entries

# Check next scheduled run
next-cron-run  # (if available on your system)
```

**Reference:** [Crontab Format Guide](https://www.man7.org/linux/man-pages/man5/crontab.5.html)

### 2. Ensure SSH Key for Git Push

The cron job needs to push to GitHub without password prompts.

```bash
# Generate SSH key (if not already done)
ssh-keygen -t ed25519 -C "anas@homelab" -f ~/.ssh/id_ed25519 -N ""

# Add public key to GitHub
cat ~/.ssh/id_ed25519.pub
# Copy output and paste into GitHub Settings → SSH Keys

# Test SSH connection
ssh -T git@github.com
# Should output: "Hi <your-username>! You've successfully authenticated..."

# Clone using SSH instead of HTTPS
cd /home/anas
rm -rf homelab-backup
git clone git@github.com:AnasSemesmieh/homelab.git homelab-backup
```

**Reference:** [GitHub SSH Setup](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)

### 3. Verify Scripts Are Executable

```bash
cd ~/homelab-backup
chmod +x scripts/*.sh
ls -la scripts/
# All .sh files should have 'x' permission
```

### 4. Test Manual Run

```bash
cd ~/homelab-backup

# Run entire backup pipeline
./scripts/backup-and-push.sh

# Monitor output
tail -f backup-cron.log
```

---

## Monitoring & Logs

### Log Locations

- **Daily backup log:** `~/homelab-backup/backup-cron.log`
- **Weekly tag log:** `~/homelab-backup/backup-weekly.log`
- **System cron log:** `/var/log/syslog` (search for CRON entries)

### Viewing Logs

```bash
# Last 50 lines of daily backup log
tail -50 ~/homelab-backup/backup-cron.log

# Follow log in real-time
tail -f ~/homelab-backup/backup-cron.log

# Search for errors
grep -i "error\|failed" ~/homelab-backup/backup-cron.log

# View all cron execution history
grep CRON /var/log/syslog | tail -20
```

### Log Format

**Successful daily backup:**
```
Syncing configs from /home/anas to /home/anas/homelab-backup/configs...
Sync complete
Redaction complete
No obvious secret patterns found.
[main abc1234] backup: sync homelab configs
 31 files changed, 5 insertions(+), 2 deletions(-)
Current branch main is up to date.
Sent successfully to origin/main
```

**Successful weekly tag:**
```
Running daily backup first...
[... daily backup output ...]
Created tag: backup-2026-05-09
Pushed tag to origin
Tag pushed successfully
```

### Health Check Script

Create a simple health check to monitor backup status:

```bash
#!/bin/bash
# Save as: ~/homelab-backup/check-backup-health.sh

BACKUP_DIR="$HOME/homelab-backup"
LOG_FILE="$BACKUP_DIR/backup-cron.log"
LAST_BACKUP_TIME=$(stat -c %Y "$LOG_FILE" 2>/dev/null || echo 0)
CURRENT_TIME=$(date +%s)
SECONDS_SINCE_BACKUP=$((CURRENT_TIME - LAST_BACKUP_TIME))
HOURS_SINCE_BACKUP=$((SECONDS_SINCE_BACKUP / 3600))

echo "=== Backup Health Check ==="
echo "Last backup: $HOURS_SINCE_BACKUP hours ago"

# Alert if no backup in last 30 hours (expected daily at 03:25)
if [[ $HOURS_SINCE_BACKUP -gt 30 ]]; then
  echo "[WARN] No backup in last 30 hours!"
  exit 1
else
  echo "[OK] Backup is current"
  exit 0
fi
```

---

## Troubleshooting

### Issue: Cron Job Not Running

**Symptoms:**
- `backup-cron.log` file not updated
- Cron not executing at scheduled time

**Diagnosis:**

```bash
# Check cron installation
crontab -l

# Check if cron service is running
sudo systemctl status cron
# or
sudo systemctl status crond

# Check system logs for cron errors
sudo grep CRON /var/log/syslog | tail -20

# Check if cron has permission to run scripts
ls -la ~/homelab-backup/scripts/backup-and-push.sh
# Should have 'x' permission
```

**Solutions:**

1. **Cron service not running:**
   ```bash
   sudo systemctl restart cron
   ```

2. **Script not executable:**
   ```bash
   chmod +x ~/homelab-backup/scripts/*.sh
   ```

3. **Time zone mismatch:**
   - Verify system time: `date`
   - Verify cron interprets times as UTC: `timedatectl | grep -i "time zone\|time\|utc"`

4. **User permissions:**
   - Cron runs as the user in crontab (use `crontab -u anas -l` to check)
   - User must have write permission to backup directory

---

### Issue: Git Push Fails in Cron

**Symptoms:**
- Log shows: `fatal: not a git repository` or `fatal: could not read Username`
- Backup runs manually fine but fails in cron

**Diagnosis:**

```bash
# Check git remote
cd ~/homelab-backup
git remote -v
# Should show: origin https://github.com/AnasSemesmieh/homelab.git

# Check SSH key
ls -la ~/.ssh/id_ed25519*
# Should exist

# Test SSH connection
ssh -T git@github.com
```

**Solutions:**

1. **Switch to SSH URL (if using HTTPS):**
   ```bash
   cd ~/homelab-backup
   git remote set-url origin git@github.com:AnasSemesmieh/homelab.git
   ```

2. **Add SSH key to cron environment:**
   ```bash
   # Edit crontab
   crontab -e
   
   # Add at top:
   SSH_AUTH_SOCK=
   SSH_AGENT_PID=
   PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
   ```

3. **Grant SSH key to cron by using ssh-agent:**
   ```bash
   # Start ssh-agent and add key
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   
   # Then run cron job or add wrapper script
   ```

**Reference:** [SSH Key Permissions for Cron](https://www.digitalocean.com/community/questions/how-to-use-ssh-keys-with-cron-jobs)

---

### Issue: Secret Pattern Detection Fails

**Symptoms:**
- Log shows: `[warn] Potential unredacted secret patterns found. Review before commit.`
- Backup stops at scan-secrets.sh step

**Diagnosis:**

```bash
# See what patterns were found
cd ~/homelab-backup
./scripts/scan-secrets.sh
```

**Solutions:**

1. **Redact the detected secrets manually:**
   ```bash
   # Edit the file and replace sensitive value with REDACTED
   vim configs/<service>/config-file
   
   # Then re-run scan
   ./scripts/scan-secrets.sh
   ```

2. **Add pattern to redact-secrets.sh (if false positive):**
   ```bash
   # Edit redact-secrets.sh
   vim scripts/redact-secrets.sh
   
   # Add pattern to sed commands for your specific case
   # Re-run sync
   ./scripts/sync-configs.sh
   ./scripts/redact-secrets.sh
   ./scripts/scan-secrets.sh
   ```

3. **Review detected values:**
   ```bash
   # Show context around detected patterns
   ./scripts/scan-secrets.sh | xargs -I {} sh -c 'echo "==="; grep -n "{}" configs/*; echo'
   ```

---

### Issue: Too Many Files Being Backed Up

**Symptoms:**
- `backup-cron.log` shows many more files than expected
- Git history growing too fast

**Diagnosis:**

```bash
# Check inventory
cat inventory/include-paths.txt | wc -l

# Check what's being synced
./scripts/sync-configs.sh

# See what files were added/changed
git status
git diff --name-only
```

**Solutions:**

1. **Trim include-paths.txt:**
   ```bash
   # Edit to remove unnecessary files
   vim inventory/include-paths.txt
   
   # Remove or comment out lines you don't need
   # Re-sync
   ./scripts/sync-configs.sh
   ```

2. **Add wildcard exclusions to .gitignore:**
   ```bash
   echo "*.log" >> .gitignore
   echo "*.tmp" >> .gitignore
   git add .gitignore
   git commit -m "ignore: exclude log/tmp files"
   ```

---

### Issue: Backup Runs But Nothing Commits

**Symptoms:**
- Log shows: `No changes to commit` or `nothing to commit`
- But configs actually changed on disk

**Diagnosis:**

```bash
# Check git status
cd ~/homelab-backup
git status

# Check if sync actually copied files
./scripts/sync-configs.sh
git diff --name-only

# Check if redact made any changes
./scripts/redact-secrets.sh
git diff --name-only
```

**Solutions:**

1. **Configs didn't actually change** — This is normal. No commit needed if nothing changed.

2. **Sync didn't find files** — Check paths in inventory:
   ```bash
   # Verify files exist at source
   while IFS= read -r line; do
     [[ -z "$line" || "$line" =~ ^# ]] && continue
     test -f "$HOME/$line" && echo "OK: $line" || echo "MISSING: $line"
   done < inventory/include-paths.txt
   ```

3. **File permissions preventing read** — Fix permissions:
   ```bash
   # Make all configs readable
   chmod -R u+r ~/*/config* ~/.env* 2>/dev/null || true
   ```

---

## Restore Compose Stack

The backup repo includes a Docker Compose stack for applying backed-up configs to a new host.

### Overview

**File:** `restore/docker-compose.restore.yml`

```yaml
version: '3.8'
services:
  restore-configs:
    image: alpine:latest
    volumes:
      - ./configs:/backup/configs:ro
      - /home/anas:/target
    environment:
      - DRY_RUN=false
      - OVERWRITE=false
      - TARGET_HOME=/home/anas
    entrypoint: /backup/apply-configs.sh
```

### Usage

```bash
cd ~/homelab-backup/restore

# Dry-run (preview what will be copied)
docker compose -f docker-compose.restore.yml run --rm \
  -e DRY_RUN=true restore-configs

# Apply without overwriting existing files
docker compose -f docker-compose.restore.yml run --rm \
  -e DRY_RUN=false -e OVERWRITE=false restore-configs

# Apply and overwrite existing files (use with caution!)
docker compose -f docker-compose.restore.yml run --rm \
  -e DRY_RUN=false -e OVERWRITE=true restore-configs
```

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DRY_RUN` | false | If true, show what would be copied without actually copying |
| `OVERWRITE` | false | If true, overwrite existing files; if false, skip existing files |
| `TARGET_HOME` | /home/anas | Target home directory to restore into |

### Restore Helper Script

**File:** `restore/apply-configs.sh`

Copies files from `/backup/configs/` to target home directory, respecting DRY_RUN and OVERWRITE flags.

**Manual restore (without Docker):**

```bash
# Copy files with backup
rsync -avh --backup ~/homelab-backup/configs/ ~/

# Or using cp with interactive prompt
cp -ri ~/homelab-backup/configs/* ~/
```

---

## Advanced: Custom Backup Retention

To keep only recent backups and delete old tags:

```bash
#!/bin/bash
# Save as: ~/homelab-backup/scripts/cleanup-old-tags.sh

# Keep backups from last 90 days only
CUTOFF_DATE=$(date -d "90 days ago" +%Y-%m-%d)

git tag -l "backup-*" | while read tag; do
  tag_date="${tag#backup-}"
  if [[ "$tag_date" < "$CUTOFF_DATE" ]]; then
    echo "Deleting old tag: $tag"
    git tag -d "$tag"
    git push origin :"$tag"
  fi
done
```

---

## References

- [Cron Tutorial](https://www.man7.org/linux/man-pages/man5/crontab.5.html)
- [Git Documentation](https://git-scm.com/doc)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [SSH & Git Integration](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
