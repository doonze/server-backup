# Backup Plan

**Status:** Draft; no Restic repository or timer yet.

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
- Restic is installed as Debian package 0.14.0; repository is not initialized.
- Encryption is mandatory. Store the password in Justin's password manager and
  provide automation a root-only credential. Never put it in Git or chat.
- Use repository format 2 and compression `auto` (verify compatibility before
  initialization).
- A systemd timer will call one reviewed orchestrator script, not the desktop
  Backups application.
- Each run should verify the NAS mount, create database exports and package
  inventory, run Restic over explicit paths, and report failure clearly.
- Keep old Déjà Dup/Duplicity and LuckyBackup data until Restic restore tests
  succeed.

## Source scope

### Include

- `/etc`, `/home`, and `/root`.
- All of `/opt`; Justin reports it is not a major space consumer.
- Most of `/var`, with explicit exclusions for Emby/Plex state and metadata,
  volatile/cache paths, and live MariaDB files. Include logical DB exports.
- The reported ~44 GB qcow2 VM disk is approved in principle for inclusion;
  verify its path, backing chain, and a safe snapshot/offline method first.
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
- Never use `/` as a Restic source. Use explicit paths and mount-boundary
  safeguards; verify `/nfs` and `/smb` are never traversed.

### App-specific recovery data

Justin reports app-generated backups for Emby, Sonarr, Radarr, Lidarr, SABnzbd,
and the Plex database. Locate and verify those artifacts before defining final
Restic inputs. Select small Plex configuration files only if useful; omit large
Plex metadata/covers.

## Database policy

See `DATABASE_BACKUP_POLICY.md`. Dump schema for every MariaDB database; include
data by default. `resource-monitor` is a known schema-only exception. Inventory
all databases and approve any further schema-only exceptions before scripting.
No current MariaDB logical dumps exist.

## Package inventory

See `PACKAGE_INVENTORY.md`. Capture every installed package, version, and
architecture, plus manual/held package state. Refresh after APT package changes
and include the current snapshot in the Restic run.

## Orchestrator and timer requirements

- Fail closed if `/nfs/backups` is not a mounted/writable NAS path.
- Do not resolve/follow symlinks to NAS paths; never traverse `/nfs` or `/smb`.
- Do not overlap backup runs; log to the system journal and fail nonzero on any
  required DB dump or Restic error.
- Keep database exports restricted and retain them until Restic confirms capture.
- Define retention only after source size, NAS capacity, and restore needs are
  measured. NAS was last observed with about 4.8 TB free; recheck before setup.
- Add notification/monitoring for missed or failed runs; a timer alone is not
  proof of a successful backup.

## Readiness gates

1. Inventory the MariaDB databases and all app-export paths.
2. Confirm `/var` exclusions and exact Emby/Plex paths without broad scans.
3. Locate the qcow2 image/backing chain and choose offline or snapshot capture.
4. Define local DB-dump staging, secret handling, and package inventory format.
5. Confirm NAS mount validation and repository permissions.
6. Initialize the encrypted repository and run the first backup.
7. Check the repository and test restore files/database data to non-production.
8. Only then consider deleting obsolete backup sets or relying on Restic alone.