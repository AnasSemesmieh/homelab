#!/bin/bash
# Vaultwarden backup script - syncs data from Optiplex to NAS
# Runs nightly at 3 AM via cron:
#   0 3 * * * /home/anas/vaultwarden/backup-to-nas.sh >> /home/anas/vaultwarden/backup.log 2>&1
#
# Usage: ./backup-to-nas.sh [--manual]

set -euo pipefail

BACKUP_DIR="/home/anas/vaultwarden/data"
NAS_DEST="/mnt/nas_docker/vaultwarden/data"
LOG_FILE="/home/anas/vaultwarden/backup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

log "Starting Vaultwarden backup..."

# Step 1: Create a consistent SQLite backup using Vaultwarden's built-in command
log "Creating consistent database backup..."
docker exec vaultwarden /vaultwarden backup

# The built-in backup creates db_YYYYMMDD_HHMMSS.sqlite3 in the data dir
BACKUP_FILE=$(ls -t "$BACKUP_DIR"/db_*.sqlite3 2>/dev/null | head -1)
if [ -z "$BACKUP_FILE" ]; then
    log "ERROR: Backup file not created. Aborting."
    exit 1
fi
log "Backup file created: $BACKUP_FILE"

# Step 2: Remove stale WAL/SHM on NAS to prevent corruption
log "Cleaning stale WAL/SHM on NAS..."
rm -f "$NAS_DEST/db.sqlite3-wal" "$NAS_DEST/db.sqlite3-shm"

# Step 3: Copy the clean backup as the main DB on NAS
log "Copying backup database to NAS..."
cp "$BACKUP_FILE" "$NAS_DEST/db.sqlite3"

# Step 4: Rsync everything else (attachments, config, keys)
log "Syncing remaining files to NAS..."
rsync -az --no-perms --no-owner --no-group \
          --exclude='db.sqlite3' \
          --exclude='db.sqlite3-wal' \
          --exclude='db.sqlite3-shm' \
          --exclude='db_*.sqlite3' \
          --exclude='icon_cache' \
          "$BACKUP_DIR/" "$NAS_DEST/"

# Step 5: Clean up local backup file
rm -f "$BACKUP_FILE"

log "Backup completed successfully."
