# Maintenance Log

## 2026-10-04 — Project created

- Created the separate `server-backup` project for backup and disaster-recovery
  planning, distinct from the ongoing `debian-update` project.
- Installed Restic 0.14.0-1+b5 from Debian Bookworm after an APT simulation showed
  one new package and no upgrades/removals.
- Confirmed Restic is encrypted by design and supports compression `auto` with
  repository format 2.
- Approved repository path: `/nfs/backups/debianr710-restic`; repository,
  orchestrator, and systemd timer are not yet created.
- Restic password, source whitelist, `/var`/`/opt` policy, database inventory,
  and restore test remain open.
- Captured a full inventory of 3,791 installed packages after Restic
  installation, split into nine TSV chunks, with manual and held package lists.
- Existing Deja Dup and LuckyBackup data were not deleted. No backup payload was
  copied or restored during project setup.
