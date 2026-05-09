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
- `restore/docker-compose.restore.yml`: one-shot restore compose stack for applying tracked configs to a new machine
- `restore/apply-configs.sh`: restore helper used by the restore compose stack
- `docs/RESTORE.md`: disaster recovery checklist
- `configs/`: sanitized snapshot for version control

## Sample Backup Snapshot

Example of what an automated snapshot looks like in this repository:

```text
homelab-backup/
   configs/
      arrstack/
         docker-compose.yml
         setup-folders.sh
         gluetun/servers.json
      homeassistant/
         docker-compose.yml
         config/
            configuration.yaml
            automations.yaml
            scenes.yaml
            scripts.yaml
      homepage/
         docker-compose.yaml
         config/
            services.yaml
            bookmarks.yaml
            settings.yaml
            widgets.yaml
            custom.css
            custom.js
      immich/
         docker-compose.yml
         hwaccel.ml.yml
         hwaccel.transcoding.yml
      pihole/
         docker-compose.yml
         etc-pihole/pihole.toml
      tautulli/
         docker-compose.yaml
         config/config.ini
      plex/
         config/
            Library/Application Support/Plex Media Server/Preferences.xml
      traefik/
         docker-compose.yml
         dynamic/
            cockpit.yaml
            homelab-services.yaml
            nas.yaml
            plex.yaml
            tls.yaml
```

## Backup Apps and Folders

The backup automation currently captures these source-of-truth areas:

- Host bootstrap
   - `setup-repo.sh`
- Arr stack
   - `arrstack/docker-compose.yml`
   - `arrstack/setup-folders.sh`
   - `arrstack/gluetun/servers.json`
- Home Assistant
   - `homeassistant/docker-compose.yml`
   - `homeassistant/config/configuration.yaml`
   - `homeassistant/config/automations.yaml`
   - `homeassistant/config/scenes.yaml`
   - `homeassistant/config/scripts.yaml`
- Homepage
   - `homepage/docker-compose.yaml`
   - `homepage/config/services.yaml`
   - `homepage/config/bookmarks.yaml`
   - `homepage/config/settings.yaml`
   - `homepage/config/widgets.yaml`
   - `homepage/config/custom.css`
   - `homepage/config/custom.js`
   - `homepage/config/docker.yaml`
   - `homepage/config/kubernetes.yaml`
   - `homepage/config/proxmox.yaml`
- Immich
   - `immich/docker-compose.yml`
   - `immich/hwaccel.ml.yml`
   - `immich/hwaccel.transcoding.yml`
- Pi-hole
   - `pihole/docker-compose.yml`
   - `pihole/etc-pihole/pihole.toml`
- Tautulli
   - `tautulli/docker-compose.yaml`
   - `tautulli/config/config.ini`
- Plex
   - `plex/config/Library/Application Support/Plex Media Server/Preferences.xml`
- Traefik
   - `traefik/docker-compose.yml`
   - `traefik/dynamic/cockpit.yaml`
   - `traefik/dynamic/homelab-services.yaml`
   - `traefik/dynamic/nas.yaml`
   - `traefik/dynamic/plex.yaml`
   - `traefik/dynamic/tls.yaml`

Anything not in `inventory/include-paths.txt` is not synced into the backup snapshot.

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

### Compose-Based Restore Helper

From a new machine after cloning this repository:

1. Dry run (recommended first):
   - `cd /home/anas/homelab-backup/restore`
   - `docker compose -f docker-compose.restore.yml run --rm -e DRY_RUN=true restore-configs`

2. Apply restore without overwriting existing files:
   - `docker compose -f docker-compose.restore.yml run --rm -e DRY_RUN=false -e OVERWRITE=false restore-configs`

3. Apply restore and overwrite existing files:
   - `docker compose -f docker-compose.restore.yml run --rm -e DRY_RUN=false -e OVERWRITE=true restore-configs`

Optional target home override:

- `docker compose -f docker-compose.restore.yml run --rm -e TARGET_HOME=/home/otheruser -e DRY_RUN=true restore-configs`

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
