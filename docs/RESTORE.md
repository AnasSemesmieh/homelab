# Restore Checklist

This document describes a practical restore flow for this homelab from this repository.

## 1. Base host preparation

- Install Docker and Docker Compose plugin.
- Ensure host networking, DNS, and firewall rules are in place.
- Clone this repository to `/home/anas/homelab-backup`.

## 2. Secret rehydration

- Populate required secrets that are intentionally redacted in `configs/`.
- Restore local certs/keys not stored in git.
- Recreate `.env` files required by stacks (for example Immich).

## 3. Restore configs to runtime paths

- Copy curated files from `configs/` into active homelab paths under `/home/anas`.
- Verify ownership/permissions for app config directories.

### Option A: Use restore compose stack (recommended)

From `/home/anas/homelab-backup/restore`:

1. Preview operations (no writes):
	- `docker compose -f docker-compose.restore.yml run --rm -e DRY_RUN=true restore-configs`
2. Apply without overwriting existing files:
	- `docker compose -f docker-compose.restore.yml run --rm -e DRY_RUN=false -e OVERWRITE=false restore-configs`
3. Apply and overwrite existing files:
	- `docker compose -f docker-compose.restore.yml run --rm -e DRY_RUN=false -e OVERWRITE=true restore-configs`

Optional: target a different home directory:

- `docker compose -f docker-compose.restore.yml run --rm -e TARGET_HOME=/home/otheruser -e DRY_RUN=true restore-configs`

### Option B: Manual file copy

- If you prefer manual restore, copy selected files from `configs/` to active runtime paths.

## 4. Bring up infrastructure first

- Start reverse proxy and DNS-related stacks first (Traefik/Pi-hole, etc.).
- Validate local DNS hostnames and HTTPS certificates.

## 5. Bring up application stacks

- Start homepage and core services.
- Start media pipeline and monitoring services.
- Check each service URL and widget/API integration.

## 6. Validate system health

- Confirm service containers are healthy.
- Confirm homepage loads expected groups/services.
- Confirm backup automation script runs cleanly.

## 7. Re-enable scheduled backups

- Install cron entry for `scripts/backup-and-push.sh`.
- Verify first cron run output in `backup-cron.log`.
