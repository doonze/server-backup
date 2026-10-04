# Restic Deployment and Operations

**Status:** Script/configuration prepared and units installed but disabled; repository is not initialized.

## Scope

- Sources: `/etc`, `/home`, `/root`, `/opt`, and `/var`; never source `/`.
- `--one-file-system` is used. The NAS routes `/nfs` and `/smb` are explicitly
  excluded, and Restic stores symlinks as links rather than following targets.
- Exclusions are in `config/restic-excludes.txt`: Emby/Plex state, raw MariaDB
  files, caches, transient paths, package-manager database, cover art, and
  browser/build caches. The libvirt image is intentionally not excluded.
- Stage fresh package and SQL exports in root-only
  `/var/backups/server-backup/staging`; this is under `/var` and therefore part
  of the same Restic snapshot. On success, the run's staging directory is
  removed; on failure it is retained for diagnosis.
- Emby MBBackup already writes to `/nfs/backups/apps/emby`. That NAS path is not
  a source. The latest dated Plex library and blob database exports are copied
  into the local staging directory; the rest of Plex state is excluded.

## Consistency rules

- `win10` must be shut off. Its current qcow2 image is checked for format,
  symlinks, corruption, and backing-file changes before each run. If the VM is
  running or metadata differs from the reviewed single-file image, the run
  fails closed. Do not start the VM during the backup window.
- InnoDB databases use `mariadb-dump --single-transaction`. Databases containing
  non-InnoDB tables use table read-locks; the discovered affected databases are
  `postfixadmin` and `servmon`. These locks can briefly block writes.
- `resource_monitor` receives a schema-only dump. Other application databases
  receive schema and data. Portable MariaDB user/grant definitions are exported
  separately; generated system schemas and internal `mysql` tables are not
  restored blindly across versions.
- Dumps and account definitions are sensitive. Staging is mode 0700 and Restic
  encryption is mandatory. Never commit or print dump contents or credentials.

## First-time setup

1. A strong random Restic password is generated and stored root-only at
   `/etc/restic/server-backup-password`. From Justin's own server terminal, copy
   it into an external password manager. Never paste it into chat or Git.
2. Verify the external copy before initializing the repository. The project
   script reads the password through a systemd credential when run as a service.
3. Confirm `/nfs/backups` is the expected writable NFS mount. The script checks
   the filesystem type and performs a temporary write probe before Restic runs.
4. Initialize the new encrypted format-2 repository:
   `sudo scripts/server-backup.sh --init`
5. Run one manual backup and inspect the journal/output. Run `restic check`,
   then restore representative files, a database, and the VM image to a
   non-production location before enabling the timer.
6. The service and timer are already installed and systemd has reloaded them.
   Enable the timer only after the first successful backup, restore checks, and
   an approved retention policy.

## Limits

- The timer template is daily at 02:30 with a randomized delay. Retention/prune
  policy and external failure notifications remain unset.
- Old Déjà Dup/Duplicity and LuckyBackup data must remain until Restic checks and
  restore tests pass.
- A file backup cannot recreate RAID, partition tables, bootloader state, or
  guarantee consistency for live application files outside the scripted DB and
  shut-down-VM checks.