# Homelab Backup Repository

This repository is the source of truth for homelab configuration backups and disaster recovery.
It tracks curated config files and automation scripts, while intentionally excluding runtime state, media, logs, databases, and raw credentials.

## What This Repo Does

- Backs up allowlisted config files from `/home/anas` into `configs/`
- Redacts secrets before commit
- Scans for potential secret leaks
- Automates daily backup commits and weekly restore-point tags
- Provides fresh-install and restore runbooks

## Quick Start

```bash
cd /home/anas/homelab-backup
./scripts/backup-and-push.sh
```

For restore preview:

```bash
cd /home/anas/homelab-backup/restore
docker compose -f docker-compose.restore.yml run --rm -e DRY_RUN=true restore-configs
```

## Documentation Index

Use this as the entry point to detailed runbooks.

### [docs/FRESH-INSTALL.md](docs/FRESH-INSTALL.md)

**Goal:** Build a complete homelab host from zero.

**High-level contents:**
- Host OS preparation (networking, firewall, base tooling)
- Docker and Docker Compose installation
- Repository bootstrap and inventory verification
- Secret rehydration and config injection
- Infrastructure-first bring-up (Traefik, DNS)
- Application stack bring-up and simple health checks
- Common failure scenarios and rollback guidance

### [docs/RESTORE.md](docs/RESTORE.md)

**Goal:** Recover services quickly after host failure or corruption.

**High-level contents:**
- Restore prerequisites and readiness checklist
- Restore from latest or from weekly snapshot tags
- Secret rehydration sequence and validation
- Compose-based config restore workflow (dry-run/apply)
- Ordered service recovery (infra first, then apps)
- Post-restore validation and automation re-enable steps
- Troubleshooting and recovery rollbacks

### [docs/SECRETS.md](docs/SECRETS.md)

**Goal:** Rehydrate all intentionally omitted credentials safely.

**High-level contents:**
- Full list of redacted secrets by service
- Where each secret is used in tracked configs
- Masked examples and format/length validations
- How to source/generate each secret
- Rotation/renewal playbooks and security practices
- Secret injection procedures before restore/apply

### [docs/BACKUP-AUTOMATION.md](docs/BACKUP-AUTOMATION.md)

**Goal:** Operate and troubleshoot unattended backups reliably.

**High-level contents:**
- Daily pipeline internals (sync, redact, scan, commit, push)
- Weekly snapshot tag flow (`backup-YYYY-MM-DD`)
- Cron setup and verification
- Log locations and health monitoring
- Common automation failures and fixes
- Restore helper stack behavior and options

## Repository Layout (High Level)

- `configs/`: sanitized backup snapshot used for restore
- `inventory/include-paths.txt`: allowlist of tracked source files
- `scripts/`: backup/redaction/scanning/tag automation
- `restore/`: compose-based restore helper
- `docs/`: operational runbooks

## Backup Scope

Tracked scope is controlled by `inventory/include-paths.txt`.
Only files listed there are synchronized into `configs/`.

Current services include (high level):
- Traefik, Pi-hole, Home Assistant
- Homepage, Arr stack, Plex, Tautulli, Immich
- Host bootstrap script(s)

## Automation Status

- Daily backup job: active via cron
- Weekly snapshot tag job: active via cron
- Weekly tag format: `backup-YYYY-MM-DD`

## Notes

- Do not commit unredacted secrets.
- Run `./scripts/scan-secrets.sh` before pushing manual changes.
- Use docs first: the README is intentionally concise.
