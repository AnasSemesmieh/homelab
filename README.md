# Homelab Backup Repository

This repository stores source-of-truth homelab configuration files and restore docs.
It intentionally excludes runtime state, logs, media, databases, and raw secrets.

## Latest Updates

- Daily automated backup job is configured and active via cron.
- Weekly snapshot tag job is configured and active via cron.
- Weekly tags use format `backup-YYYY-MM-DD` and are pushed to `origin`.
- Runtime artifacts are ignored (`.backup.lock`, `.backup-tag.lock`, `backup-cron.log`, `backup-weekly.log`).
- Current remote repository: `https://github.com/AnasSemesmieh/homelab`.

## Layout

- `inventory/include-paths.txt`: allowlist of files copied from `/home/anas`
- `scripts/sync-configs.sh`: copies allowlisted files into `configs/`
- `scripts/redact-secrets.sh`: redacts obvious secrets in tracked config files
- `scripts/scan-secrets.sh`: scans tracked files for high-risk secret patterns
- `scripts/backup-and-push.sh`: end-to-end daily automation (sync, redact, scan, commit, pull-rebase, push)
- `scripts/weekly-tag.sh`: weekly snapshot tag automation (runs backup job, creates/pushes dated tag)
- `docs/RESTORE.md`: disaster recovery checklist
- `configs/`: sanitized snapshot for version control

## Workflow

1. Sync current files:
   - `./scripts/sync-configs.sh`
2. Redact secrets:
   - `./scripts/redact-secrets.sh`
3. Scan for leaks:
   - `./scripts/scan-secrets.sh`
4. Review and commit:
   - `git status`
   - `git add .`
   - `git commit -m "backup: update homelab configs"`

## Create New Homelab (Fresh Build)

Use this flow when provisioning a new host from scratch.

1. Prepare host OS and networking:
   - Install Linux updates.
   - Set static IP and hostname.
   - Configure DNS resolver to your local DNS strategy.

2. Install base dependencies:
   - Install Docker Engine and Docker Compose plugin.
   - Install `git`, `curl`, and any required CLI tools.

3. Clone this repository:
   - `git clone https://github.com/AnasSemesmieh/homelab /home/anas/homelab-backup`
   - `cd /home/anas/homelab-backup`

4. Recreate secrets and local-only assets:
   - Rebuild any `.env` files not tracked in git.
   - Restore certificates/keys that are intentionally excluded.
   - Re-issue or rotate API tokens as needed.

5. Materialize configs to runtime paths:
   - Copy from `configs/` into active stack paths under `/home/anas`.
   - Validate permissions/ownership for app config folders.

6. Bring up core infrastructure first:
   - Start reverse proxy and DNS-related services first.
   - Validate local DNS names and TLS cert behavior.

7. Bring up application stacks:
   - Start dashboard and monitoring.
   - Start media pipeline and remaining services.

8. Validate end-to-end:
   - Check service URLs and auth flows.
   - Verify homepage widgets and routes.
   - Verify `./scripts/backup-and-push.sh --dry-run` succeeds.

## Restore Existing Homelab (Recovery)

Use this flow when rebuilding after host failure or major corruption.

1. Rebuild base host and install Docker/tooling.
2. Clone repo to `/home/anas/homelab-backup`.
3. Restore configs from `configs/` to live paths.
4. Restore secrets, certs, and `.env` files.
5. Start services in dependency order (infra first, apps second).
6. Validate DNS, routing, TLS, and service health.
7. Run backup scripts to confirm automation health:
   - `./scripts/backup-and-push.sh --dry-run`
   - `./scripts/weekly-tag.sh --dry-run`
8. Re-enable schedules if needed:
   - `crontab -l`
   - Ensure both daily and weekly entries exist.

## Daily Automation

Run automation manually:

- `./scripts/backup-and-push.sh`

Dry run without committing/pushing:

- `./scripts/backup-and-push.sh --dry-run`

Suggested cron entry (daily at 03:25):

- `25 3 * * * /home/anas/homelab-backup/scripts/backup-and-push.sh >> /home/anas/homelab-backup/backup-cron.log 2>&1`

## Weekly Snapshot Tags

Run weekly tag job manually:

- `./scripts/weekly-tag.sh`

Dry run without creating/pushing tag:

- `./scripts/weekly-tag.sh --dry-run`

Suggested cron entry (Sunday at 03:40):

- `40 3 * * 0 /home/anas/homelab-backup/scripts/weekly-tag.sh >> /home/anas/homelab-backup/backup-weekly.log 2>&1`

## Restore Goal

This repo should be sufficient to rebuild services and routing with minimal manual steps once secrets are supplied.

For the step-by-step rebuild procedure, see `docs/RESTORE.md`.
