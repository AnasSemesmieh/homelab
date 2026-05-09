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
