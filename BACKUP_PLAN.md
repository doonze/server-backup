# Backup Plan

**Status:** Daily timer enabled for 05:00 America/Chicago. Each run keeps 7 daily, 4 weekly, and 12 monthly snapshots, then prunes. Alerting is a TODO; the updated stable inventory path awaits its first scheduled-run verification.

## Why

Provide versioned backups and a practical rebuild path if Debian, storage, or a
service fails. Justin has previously restored a filesystem-tree copy by
reinstalling Debian and restoring files; this project formalizes that approach
with Restic, explicit exclusions, package state, database exports, and a tested
runbook.

## Recovery target

Reinstall the Debian stable release current at recovery time on the existing
R710 RAID, install Restic, restore reviewed files and database/app backups, then
reinstall and verify services. No raw disk image or PXE setup is in scope yet.
Document RAID controller/layout, boot mode, network, and NAS access as discovery
items; Restic cannot recreate those.

## Approved design decisions

- Use Restic with a new repository at `/nfs/backups/debianr710-restic`.
- Restic 0.14.0 is installed; encrypted repository `/nfs/backups/debianr710-restic` is initialized with first snapshot `29ab3833`.
- Encryption is mandatory. Store the password in Justin's password manager and
  provide automation a root-only credential. Never put it in Git or chat.
- Use repository format 2 and compression `auto` (verify compatibility before
  initialization).
- A systemd timer will call one reviewed orchestrator script, not the desktop
  Backups application.
- Each run should verify the NAS mount, create database exports and package
  inventory, run Restic over explicit paths, and report failure clearly.
- Keep legacy backup sets until Restic restore tests succeed. After successful
  repository, file, database, and qcow2 checks, the Déjà Dup set
  `/nfs/backups/debianr710` was removed at Justin's request; the separate
  LuckyBackup set remains.

## Source scope

### Include

- `/etc`, `/home`, and `/root`.
- All of `/opt`; Justin reports it is not a major space consumer.
- Most of `/var`, with explicit exclusions for Emby/Plex state and metadata,
  volatile/cache paths, and live MariaDB files. Include logical DB exports.
- Include `/var/lib/libvirt/images/win10.qcow2` under `/var`: 80 GiB virtual,
  about 42 GiB allocated, no backing file reported. Require `win10` to be shut
  off; the orchestrator fails closed if it is running or image metadata changes.
- Foundry under `/home` remains in scope; its live-data consistency is not yet
  assessed.
- Minecraft `/home/justin/Minecraft/backup` update checkpoints and the live
  `/home/justin/Minecraft/running` tree as best-effort, without pausing it.

### Exclude / omit

- `/nfs` and `/smb` at all costs; these are NAS routes.
- Symlink targets: preserve links only, never traverse them.
- `/lib` from file restoration; rebuild packaged OS libraries via APT.
- Emby/Plex data and large media metadata/covers; app-generated backups remain
  the recovery source for those services.
- Caches, runtime/lock/temp data, and the live MariaDB datadir; use verified
  logical dumps instead.
- Use explicit sources from `config/backup-sources.txt` (`/etc`, `/home`,
  `/root`, `/opt`, `/var`), never `/`. Use `--one-file-system`, explicit
  exclusions from `config/restic-excludes.txt`, and verify `/nfs` and `/smb` are
  never traversed.

### App-specific recovery data

Justin reports app-generated backups for Emby, Sonarr, Radarr, Lidarr, SABnzbd,
and the Plex database. Emby's MBBackup export is on `/nfs/backups/apps/emby`
and is intentionally not used as a source. Sonarr exports are in
`/var/lib/sonarr/Backups`. Stage the latest dated Plex library/blob DB copies
from its database directory, then exclude the rest of `/var/lib/plexmediaserver`.
Other app exports are captured by `/home`, `/opt`, or `/var` unless stored on
an excluded NAS path. Do not include Plex metadata or cover art.

## Database policy

See `DATABASE_BACKUP_POLICY.md`. Dump schema for every MariaDB database; include
data by default. `resource_monitor` is the known schema-only exception. The current application
DB inventory and MyISAM consistency requirements are recorded in
`DATABASE_BACKUP_POLICY.md`; review the brief write-blocking read-lock window for
`postfixadmin` and `servmon` before enabling the scheduled dump. Justin approved
those brief locks; they were used in the first successful dump of all 14
application databases.

## Package inventory

See `PACKAGE_INVENTORY.md`. Capture every installed package, version, and
architecture, plus manual/held package state. The orchestrator publishes one
stable latest inventory at `/var/backups/server-backup/staging/latest-package-inventory`
for each Restic run; it does not create timestamped inventory paths.

## Orchestrator and timer requirements

- Fail closed if `/nfs/backups` is not a mounted/writable NAS path.
- Do not use `/nfs` or `/smb` as Restic sources; keep them excluded and do not
  follow symlinks into them. The approved NFS destination may be inspected or
  administered at a specific path when Justin requests it.
- Do not overlap backup runs; log to the system journal and fail nonzero on any
  required DB dump or Restic error.
- Keep database exports restricted and retain them until Restic confirms capture.
  The first snapshot included all 14 database exports.
- Retention approved: keep 7 daily, 4 weekly, and 12 monthly snapshots. The
  orchestrator runs `restic forget` and `--prune` after each backup. A dry run
  retained the existing snapshot `29ab3833`; about 4.9 TB was free at the last
  NAS check.
- Add notification/monitoring for missed or failed runs; a timer alone is not
  proof of a successful backup. This remains a TODO.

## Readiness gates

1. Inventory the MariaDB databases and all app-export paths.
2. Confirm `/var` exclusions and exact Emby/Plex paths without broad scans.
3. Locate the qcow2 image/backing chain and choose offline or snapshot capture.
4. Define local DB-dump staging, secret handling, and package inventory format.
5. Confirm NAS mount validation and repository permissions.
6. Initialize the encrypted repository and run the first backup. **Complete:**
   snapshot `29ab3833` created.
7. Check the repository and test restores to non-production. **Complete for
   selected artifacts:** `restic check` passed; package and SQL dump files
   restored; `vmdashboard` imported into a temporary schema and passed
   `mariadb-check`; restored qcow2 passed `qemu-img check`.
8. The Déjà Dup set was removed after those checks. Review the separate
   LuckyBackup set before any deletion or relying on Restic alone.