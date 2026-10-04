# Project Context: server-backup

**Last Updated:** 2026-10-04
**Context confirmed by Justin:** 2026-10-04

## Systems

### Development System
- **Type:** Local administration and backup planning on the server.
- **OS:** Debian GNU/Linux 12.15 Bookworm, amd64; reverify before changes.
- **Path:** `/home/justin/puppy_workspace/projects/active/server-backup/`

### Production System
- **Server:** `mail.doonze.net`, Dell PowerEdge R710.
- **Hardware/storage:** Eight-disk RAID; exact controller and layout to document.
- **OS:** Debian 12.15 Bookworm at project start; recovery target is the
  Debian stable release available at recovery time.
- **Access:** Admin shell; physical console was previously confirmed. Reverify
  console/recovery access before a major recovery or OS upgrade.
- **Recovery model:** Reinstall Debian on the existing RAID, then restore files
  and service data from Restic. No block-image or PXE requirement currently.

## Important Paths

### Backup and Production Paths
- **Restic repository (approved, not initialized):**
  `/nfs/backups/debianr710-restic`
- **NAS automount:** `/nfs/backups`; autofs-backed NFS, idle expiry observed.
- **Protected home data:** `/home` and `/root`; include all home directories.
- **Minecraft server:** `/home/justin/Minecraft/running` (best-effort live-world
  capture accepted by Justin).
- **Minecraft update fallback:** `/home/justin/Minecraft/backup` (retain).
- **Other source paths:** `/etc` and all of `/opt` included; most of `/var`
  included, excluding Emby/Plex data and metadata, volatile paths, and raw live
  MariaDB files (logical dumps are planned). `/lib` omitted from file restore.
- **VM disk:** `/var/lib/libvirt/images/win10.qcow2`, 80 GiB virtual / about
  42 GiB allocated; no backing file reported. Require `win10` shut off.
- **Hard exclusions:** `/nfs` and `/smb`; never scan or follow these NAS routes.
- **Package inventory:** Versioned project baseline plus per-run inventory in
  `/var/backups/server-backup/staging`; included only after generation succeeds.
- **Database dump/staging path:** `/var/backups/server-backup/staging`, local
  root-only mode 0700; keep dumps until the same Restic run succeeds.

### Development Paths
- **Project:** `/home/justin/puppy_workspace/projects/active/server-backup/`
- **Test data:** No restore-test destination approved yet. Restore tests must
  target a separate, non-production path or isolated database.

## Tech Stack

- **OS/package manager:** Debian + APT/dpkg.
- **Backup:** Restic 0.14.0 installed; encrypted repository format 2 planned,
  compression mode `auto`.
- **Scheduling:** Daily systemd service/timer are installed but disabled; enable
  only after a successful initial backup and approved retention policy.
- **Orchestration:** `scripts/server-backup.sh` performs mount/VM checks,
  database dumps, package inventory, Plex export staging, then Restic; not yet
  run against the production repository.
- **Storage:** NAS NFS via autofs; do not alter existing autofs behavior.
- **Databases:** MariaDB 10.11.18; 14 application databases inventoried.
  Schema/data are backed up by default; `resource_monitor` is schema-only.
  `postfixadmin` and `servmon` need read locks for consistent MyISAM dumps.

## Conventions

- **Branch naming:** `main` initially; `feature/*` or `fix/*` if needed.
- **Commit style:** Conventional commits, small reviewed changes.
- **Repository:** Local Git initialized; no remote configured. If a remote is
  added later, push commits and tags for durability.
- **Secrets:** No Restic passwords, DB credentials, raw dumps, or backup payloads
  in Git. Keep the Restic password in an external password manager and a
  root-only runtime credential source.
- **Package inventory:** Record every installed package with version and
  architecture; also record manual/held package state. Refresh after package
  changes and through the scheduled backup workflow.

## Things to Always Remember

- Never pass `/` as a Restic source. Use explicit, reviewed source paths.
- Never scan `/nfs` or `/smb`; symlinks are stored as links, never followed.
- Add mount checks so a missing NAS cannot redirect writes to a local directory.
- Do not back up a live MariaDB data directory as a substitute for a dump.
- Minecraft `/running` is intentionally best-effort; retain `/backup` update
  copies as the fallback.
- Do not delete Déjà Dup or LuckyBackup repositories until Restic has a verified
  backup and a successful test restore.
- Restic encryption is mandatory; password loss means backup loss.
- A Restic file backup is not a disk image and does not recreate RAID, partition
  tables, or bootloader state.

## Project-Specific Notes

- Emby MBBackup exports to `/nfs/backups/apps/emby` (retention 5); do not scan
  or copy from that NAS path. Sonarr exports are in `/var/lib/sonarr/Backups`.
- Latest Plex library/blob DB backup copies were found under its `Databases`
  directory; stage those dated copies and exclude the rest of Plex state.
- Radarr/Lidarr/SABnzbd exports are covered by broad local source roots unless
  stored on an excluded NAS path. Large media metadata/covers are excluded.
- Storage assessment corrected by Justin: `/var` is the largest data area
  (about 63% of server space), mostly Emby/Plex; `/opt` itself is not large.
  Include all of `/opt` and most of `/var`, after confirming exact paths.
- Exclude Emby/Plex state and large metadata/covers; rely on the existing
  application backups. Keep small Plex settings only if useful.
- Back up MariaDB with logical schema/data exports, not a live datadir copy;
  see `DATABASE_BACKUP_POLICY.md`. Database inventory remains pending.
- Foundry is under a home directory and is reported to use about 20% of space;
  home directories remain in scope.
- Include `/var/lib/libvirt/images/win10.qcow2` (about 42 GiB allocated); it
  has no backing file reported. Require `win10` to be shut off for backup.
- The R710 has no spare removable backup disk available; network boot is
  unverified and not required for the current recovery plan.