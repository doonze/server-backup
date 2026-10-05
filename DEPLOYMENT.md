# Restic Deployment and Operations

**Status:** Repository initialized; first snapshot and selected restore tests passed. Service is installed; timer remains disabled pending retention and operations approval.

## Scope

- Sources: `/etc`, `/home`, `/root`, `/opt`, and `/var`; never source `/`.
- `--one-file-system` is used. `/nfs` and `/smb` are excluded as Restic
  sources, and symlinks into them are not followed. `/nfs/backups` is the
  approved repository destination; specific NAS paths may be administered when
  Justin requests it.
- Exclusions are in `config/restic-excludes.txt`: Emby/Plex state, raw MariaDB
  files, caches, transient paths, package-manager database, cover art, and
  browser/build caches. The libvirt image is intentionally not excluded.
- Stage SQL exports in a root-only per-run directory under
  `/var/backups/server-backup/staging`; remove it after successful capture and
  retain it on failure for diagnosis. Publish package records separately at
  the stable `staging/latest-package-inventory` path, replacing the prior
  runtime copy each run.
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
4. **Complete:** the encrypted format-2 repository was initialized at
   `/nfs/backups/debianr710-restic`; snapshot `29ab3833` completed.
5. **Complete for selected artifacts:** `restic check` found no errors; a
   package-inventory file and SQL dump files restored successfully; `vmdashboard`
   was imported into a temporary schema and passed `mariadb-check`; the restored
   qcow2 passed `qemu-img check`.
6. The service and timer are installed, but the timer is disabled. Define
   retention, monitoring, and failure notifications before enabling it.

## Limits

- The timer template is daily at 02:30 with a randomized delay. Retention/prune
  policy and external failure notifications remain unset.
- The Déjà Dup/Duplicity set `/nfs/backups/debianr710` was removed after the
  selected restore checks passed. The separate LuckyBackup data remains until
  Justin explicitly requests its removal after review.
- Planned Backrest UI: `https://server.doonze.net/backrest`, proxied by Apache
  with the SABnzbd password file applied only to `/backrest` and its subpaths.
  Backrest scheduling remains unused; systemd is the sole planned scheduler.
- A file backup cannot recreate RAID, partition tables, bootloader state, or
  guarantee consistency for live application files outside the scripted DB and
  shut-down-VM checks.