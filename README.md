# Homelab Backup Repository

This repository stores source-of-truth homelab configuration files and restore docs.
It intentionally excludes runtime state, logs, media, databases, and raw secrets.

## Layout

- `inventory/include-paths.txt`: allowlist of files copied from `/home/anas`
- `scripts/sync-configs.sh`: copies allowlisted files into `configs/`
- `scripts/redact-secrets.sh`: redacts obvious secrets in tracked config files
- `scripts/scan-secrets.sh`: scans tracked files for high-risk secret patterns
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

## Restore Goal

This repo should be sufficient to rebuild services and routing with minimal manual steps once secrets are supplied.
