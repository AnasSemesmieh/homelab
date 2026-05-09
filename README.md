# Homelab Backup Repository

This repository stores source-of-truth homelab configuration files and restore docs.
It intentionally excludes runtime state, logs, media, databases, and raw secrets.

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
